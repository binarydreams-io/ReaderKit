// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Home-grown cleanup passes with no upstream counterpart: chrome/widget
/// removal heuristics that run alongside the Mozilla-port passes.
/// Each is an intentional divergence; the doc comments explain the signal
/// each one keys on.
extension ArticleCleaner {
  private func hasContainerIdentity(_ element: Element) -> Bool {
    if !element.id().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return true
    }
    let className = ((try? element.className()) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return !className.isEmpty
  }

  /// Remove unwanted elements from article content
  func removeUnwantedElements(_ element: Element) throws {
    // Remove script and style tags
    try element.select("script, style, noscript").remove()
    // Match Mozilla _clean() defaults for obvious non-article containers.
    try element.select("footer, aside, link").remove()
    try removeExplicitNoContentContainers(element)
    try removeKnownWidgetElements(element)
    try removeDisallowedEmbeds(element)

    // Remove elements with hidden attribute
    try VisibilityRules.removeHiddenElements(from: element)

    // Remove share/social elements
    try removeShareElements(element)
  }

  /// Remove explicit non-article wrappers frequently used for
  /// "what's next"/navigation modules that should not remain in readable output.
  ///
  /// Matched against `id`/`class` tokens ("nocontent", "whats-next",
  /// "supplemental"), not rendered text — developer-facing markup identifiers
  /// are conventionally ASCII/English regardless of a page's content
  /// language, so unlike rendered-text heuristics this is already
  /// locale-independent and needs no further generalization.
  private func removeExplicitNoContentContainers(_ element: Element) throws {
    let containers = try element.select("section, div")
    for container in containers {
      let id = container.id().lowercased()
      let className = ((try? container.className()) ?? "").lowercased()
      let signature = "\(id) \(className)"

      let isExplicitNoContent = signature.contains("nocontent") ||
        signature.contains("robots-nocontent") ||
        signature.contains("whats-next")
      let isSupplementalContainer = signature.contains("supplemental")
      guard isExplicitNoContent || isSupplementalContainer else { continue }

      // Keep safety guard to avoid removing legitimate long-form sections.
      let text = ((try? DOMHelpers.getInnerText(container)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let threshold = isSupplementalContainer ? 1200 : 500
      let linkDensity = (try? getLinkDensity(container)) ?? 0

      if isSupplementalContainer {
        // Supplemental modules are usually related-link rails.
        if text.count <= threshold || linkDensity >= 0.2 {
          try container.remove()
        }
        continue
      }

      if text.count <= threshold {
        try SiteRuleRegistry.rescueFromNoContentContainer(container, sourceURL: sourceURL)
        try container.remove()
      }
    }
  }

  /// Remove known non-article UI widgets that leak into extracted content on some pages.
  ///
  /// The video-control-panel matches below key on fixed English UI vocabulary
  /// ("Stream Type", "Foreground"/"Background"/"Font Size") rather than a
  /// site-specific pattern: they match the default closed-caption/subtitle
  /// settings panel of a common web video-player library, which ships
  /// English-only labels regardless of the embedding page's own language.
  /// Evidence spans unrelated hosts (Mozilla's own `test-pages/bug-1255978`,
  /// `realworld/webmd-1`, `realworld/webmd-2`, `realworld/royal-road`), so
  /// this is a genuine cross-site generic signal, not a per-site hack; kept
  /// as English-only by design since translating a third-party widget's own
  /// UI copy isn't something this cleanup pass can generalize.
  private func removeKnownWidgetElements(_ element: Element) throws {
    // Video control label block that Mozilla output drops.
    for label in try element.select("span:matchesOwn(^\\s*Stream\\s+Type\\s*$)") {
      var current = label.parent()
      while let node = current {
        if node.tagName().lowercased() == "div" {
          let text = (try? DOMHelpers.getInnerText(node)) ?? ""
          if text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix("Stream Type")
          {
            try node.remove()
            break
          }
        }
        current = node.parent()
      }
    }

    // Remove video caption/settings control panes.
    for candidate in try element.select("div").reversed() {
      let labels = (try? candidate.select("label")) ?? Elements()
      if labels.isEmpty() {
        continue
      }
      let labelTexts = labels.array().map {
        ((try? DOMHelpers.getInnerText($0)) ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
      }
      let hasForeground = labelTexts.contains("foreground")
      let hasBackground = labelTexts.contains("background")
      let hasFontSize = labelTexts.contains("font size")
      if hasForeground, hasBackground, hasFontSize {
        try candidate.remove()
      }
    }

    try SiteRuleRegistry.applyUnwantedElementRules(to: element, context: siteRuleContext, sourceURL: sourceURL)
    // Keep tab navigation shell, but drop embedded search forms.
    for nav in try element.select("nav") {
      let hasTablist = (try? nav.select("ul[role=tablist]").isEmpty()) == false
      guard hasTablist else { continue }
      try nav.select("form").remove()
    }
    // One subtree traversal for two disjoint widget shapes: interactive
    // editor promos (direct SVG + markdown children) and standalone ad
    // label blocks ("<div><p>Advertising</p></div>").
    for candidate in try element.select("div").reversed() {
      if isEditorPromoWidget(candidate) || isAdLabelBlock(candidate) {
        try candidate.remove()
      }
    }

    // Reader feedback prompts are engagement UI, not article content.
    for prompt in try element.select(
      "div[class*=reader-satisfaction-survey], div[class*=feedback-prompt], div[class*=feedback]"
    ) {
      let cls = ((try? prompt.className()) ?? "").lowercased()
      if cls.contains("feedback-prompt") || cls.contains("reader-satisfaction-survey") {
        try prompt.remove()
      }
    }
  }

  private func isEditorPromoWidget(_ candidate: Element) -> Bool {
    let children = candidate.children()
    let hasDirectSVG = children.contains { $0.tagName().lowercased() == "svg" }
    let hasDirectMarkdown = children.contains { ((try? $0.attr("markdown")) ?? "").isEmpty == false }
    return hasDirectSVG && hasDirectMarkdown
  }

  private func isAdLabelBlock(_ candidate: Element) -> Bool {
    let text = ((try? DOMHelpers.getInnerText(candidate)) ?? "")
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard text == "advertising" || text == "advertisement" else { return false }
    return (try? candidate.select("img, picture, video, iframe, object, embed, figure").isEmpty()) != false
  }

  /// Remove compact, link-heavy metadata/action blocks that commonly appear
  /// near hero images (e.g. author/date/follow controls) and are not article body.
  /// Remove compact link-heavy chrome divs in one subtree traversal:
  /// short metadata/action blocks near hero images (author/date/follow
  /// controls) and "Related"/"Most Read" link-collection sidecars. The two
  /// branches are disjoint — the first rejects any div containing a list,
  /// the second requires one — so evaluating them in a single pass is
  /// equivalent to two sequential whole-subtree passes.
  ///
  /// The related-heading text gate ("related"/"more on"/"most read") is
  /// English-only by construction: it's a precision guard on top of already
  /// generic structural signals (no media, several links, a list, short
  /// text, high link density), used to avoid misclassifying legitimate
  /// short link-heavy content (e.g. citation lists) as a related-articles
  /// rail. Evidence spans unrelated hosts (Mozilla's own `test-pages/videos-1`
  /// and `keep-images`, plus `realworld/wapo-1`, `salon-1`, `wikipedia`,
  /// `wordpress`, `yahoo-1`, `nytimes-2`), confirming this is a genuine
  /// cross-site heuristic rather than a per-site hack. Kept English-only:
  /// there's no reliable locale-independent replacement for "this heading
  /// says this is a related-content module" short of full translation.
  func removeLinkHeavyChromeDivs(_ root: Element) throws {
    let divs = try root.select("div")
    for div in divs.reversed() {
      guard div.parent() != nil else { continue }

      if try isShortLinkHeavyDiv(div) || isRelatedLinkCollectionDiv(div) {
        try div.remove()
      }
    }
  }

  private func isShortLinkHeavyDiv(_ div: Element) throws -> Bool {
    if hasAncestorTag(div, tag: "table") {
      return false
    }
    if (try? div.select("img, picture, figure, video, iframe, object, embed, table, pre, code, ul, ol, blockquote").isEmpty()) == false {
      return false
    }

    let text = try DOMHelpers.getInnerText(div).trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty || text.count > 90 {
      return false
    }

    let paragraphCount = try div.select("p").count
    if paragraphCount > 4 {
      return false
    }

    let linkCount = try div.select("a").count
    if linkCount < 2 {
      return false
    }

    let linkDensity = try getLinkDensity(div)
    return linkDensity >= 0.2
  }

  func removeEmptyContainerDivs(_ root: Element) throws {
    let divs = try root.select("div")
    for div in divs.reversed() {
      guard div.parent() != nil else { continue }

      let text = try DOMHelpers.getInnerText(div).trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty {
        continue
      }

      if (try? div.select("img, picture, figure, video, iframe, object, embed, table").isEmpty()) == false {
        continue
      }

      try div.remove()
    }
  }

  private func isRelatedLinkCollectionDiv(_ div: Element) throws -> Bool {
    if hasAncestorTag(div, tag: "figure") || hasAncestorTag(div, tag: "table") {
      return false
    }
    if (try? div.select("img, picture, figure, video, iframe, object, embed").isEmpty()) == false {
      return false
    }

    let headingText = (
      try? div.select("h1, h2, h3, h4, h5, h6, strong, b").first()?.text()
    )?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased() ?? ""
    if headingText.isEmpty {
      return false
    }

    let isRelatedHeading =
      headingText == "related" ||
      headingText == "more" ||
      headingText.hasPrefix("related ") ||
      headingText.hasPrefix("more on ") ||
      headingText.hasPrefix("most read")
    if !isRelatedHeading {
      return false
    }

    let linkCount = try div.select("a").count
    let listCount = try div.select("ul, ol").count
    let paragraphCount = try div.select("p").count
    let textLength = try DOMHelpers.getInnerText(div).count
    let linkDensity = try getLinkDensity(div)

    return linkCount >= 3 &&
      listCount >= 1 &&
      paragraphCount <= 3 &&
      textLength <= 1200 &&
      linkDensity >= 0.2
  }

  /// Remove short single-item promo lists embedded between article paragraphs.
  func removeSingleItemPromoLists(_ root: Element) throws {
    let lists = try root.select("ul, ol")
    for list in lists.reversed() {
      guard list.parent() != nil else { continue }
      if hasAncestorTag(list, tag: "figure") || hasAncestorTag(list, tag: "table") {
        continue
      }

      let items = list.children()
      guard items.count == 1,
            items.first?.tagName().lowercased() == "li"
      else {
        continue
      }

      let linkCount = try list.select("a").count
      if linkCount != 1 {
        continue
      }

      let text = try DOMHelpers.getInnerText(list)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if text.isEmpty || text.count > 90 {
        continue
      }

      // Only drop if list is sandwiched by paragraphs, which strongly
      // suggests a promo/related link insert rather than core list content.
      let previous = ((try? list.previousElementSibling()?.tagName().lowercased()) ?? "") == "p"
      let next = ((try? list.nextElementSibling()?.tagName().lowercased()) ?? "") == "p"
      if previous, next {
        try list.remove()
      }
    }
  }

  /// See `WikipediaShortRoleNoteCalloutRule` — the "Main article:"/"See also:"
  /// hatnote text this matches is English-Wikipedia-specific.
  func removeShortRoleNoteCallouts(_ root: Element) throws {
    let host = SiteRuleRegistry.resolveHost(sourceURL: sourceURL, document: root.ownerDocument())
    guard WikipediaShortRoleNoteCalloutRule.appliesTo(host: host) else { return }
    try WikipediaShortRoleNoteCalloutRule.apply(to: root, context: siteRuleContext)
  }

  /// Remove share/social elements from article content
  func removeShareElements(_ element: Element) throws {
    try SiteRuleRegistry.applyArticleCleanerRules(phase: .shareCleanup, to: element, context: siteRuleContext, sourceURL: sourceURL)
  }

  func collapseSingleDivWrappers(_ root: Element) throws {
    let divs = try DOMHelpers.selectExcludingRoot("div", in: root)
    for div in divs.reversed() {
      guard div.parent() != nil else { continue }
      if div.hasAttr("data-testid") {
        continue
      }
      if div.hasAttr("data-load-playlist") ||
        ((try? div.select("[data-load-playlist]").isEmpty()) == false)
      {
        continue
      }
      if hasContainerIdentity(div) {
        continue
      }
      guard hasSingleTagInsideElement(div, tag: "DIV"),
            try getLinkDensity(div) < 0.25,
            let child = div.children().first
      else {
        continue
      }
      if let attributes = div.getAttributes() {
        for attr in attributes {
          let key = attr.getKey().lowercased()
          if child.tagName().lowercased() == "p", key == "dir" {
            continue
          }
          try child.attr(attr.getKey(), attr.getValue())
        }
      }
      try div.replaceWith(child)
    }
  }

  // MARK: - Header Cleaning

  /// Merge div blocks whose direct paragraph children were split into many tiny fragments.
  /// This commonly happens in print-info tails where inline spans are broken into
  /// consecutive short paragraphs.
  func mergeFragmentedParagraphDivs(_ element: Element) throws {
    let divs = try element.select("div")
    for div in divs.reversed() {
      guard div.parent() != nil else { continue }
      if (try? div.select("h1, h2, h3, h4, h5, h6, img, picture, figure, video, iframe, table, ul, ol").isEmpty()) == false {
        continue
      }

      let children = div.children().array()
      guard !children.isEmpty else { continue }
      guard children.allSatisfy({ $0.tagName().lowercased() == "p" }) else { continue }

      let paragraphs = children
      guard paragraphs.count >= 4 else { continue }
      guard DOMHelpers.looksLikeFragmentedParagraphs(paragraphs, requireProseStart: true) else { continue }

      let doc = div.ownerDocument() ?? Document("")
      let merged = try doc.createElement("p")
      for paragraph in paragraphs {
        while let first = paragraph.getChildNodes().first {
          try merged.appendChild(first)
        }
        try paragraph.remove()
      }
      try div.appendChild(merged)
    }
  }

  func removeAdvertisementPlaceholders(_ element: Element) throws {
    let candidates = try element.select("div, p")
    for node in candidates {
      let text = (try? node.text())?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() ?? ""
      if text == "advertisement" {
        try node.remove()
        continue
      }

      let id = node.id().lowercased()
      let className = ((try? node.className()) ?? "").lowercased()
      let identity = "\(id) \(className)"
      let isAdContainer = identity.range(
        of: "(^|\\s|[-_])(ad|ads|advert|advertisement)(\\s|[-_]|\\d|$)",
        options: [.regularExpression]
      ) != nil

      if isAdContainer,
         text.count <= 120,
         (try? node.select("img, video, picture, figure, table, blockquote").isEmpty()) == true
      {
        try node.remove()
      }
    }
  }

  // MARK: - Boundary Residue Cleanup
}
