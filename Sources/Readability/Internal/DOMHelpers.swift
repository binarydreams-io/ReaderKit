import Foundation
import SwiftSoup

/// Helper functions for DOM manipulation
enum DOMHelpers {
  /// Get inner text of an element (similar to textContent in JS)
  static func getInnerText(_ element: Element, normalizeSpaces: Bool = true) throws -> String {
    let text = try element.text()
    if normalizeSpaces {
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    return text
  }

  /// Determine if a node should be considered for content extraction
  static func isProbablyVisible(_ element: Element) -> Bool {
    VisibilityRules.isProbablyVisibleForScoring(element)
  }

  /// Get the class name and id as a single string for pattern matching
  static func getClassAndId(_ element: Element) -> String {
    let className = (try? element.className()) ?? ""
    let id = element.id()
    return "\(className) \(id)".lowercased()
  }

  /// Change an element's tag name, preserving attributes and child order.
  /// Retagging into `<p>` strips Mozilla-noise attributes that shouldn't
  /// survive into readable output: purely-numeric auto-generated ids, and
  /// `data-media-type`/`data-media-meta` left over from media placeholders.
  /// Canonical implementation shared by `ArticleCleaner` and `ContentExtractor`
  /// (distinct from the simpler, generic `setTagName` above, which has none
  /// of this `<p>`-specific stripping).
  static func setNodeTag(_ element: Element, newTag: String) throws -> Element {
    let doc = element.ownerDocument() ?? Document("")
    let normalizedTag = newTag.lowercased()
    let newElement = try doc.createElement(normalizedTag)

    try copyAttributes(from: element, to: newElement)
    if normalizedTag == "p" {
      let idValue = element.id().trimmingCharacters(in: .whitespacesAndNewlines)
      if idValue.range(of: "^[0-9]{6,}$", options: [.regularExpression]) != nil {
        try newElement.removeAttr("id")
      }

      // Media placeholders can be retagged into paragraphs.
      // Strip non-content media metadata attributes to match Mozilla output.
      let hasMediaType = element.hasAttr("data-media-type")
      let hasMediaMeta = element.hasAttr("data-media-meta")
      if hasMediaType || hasMediaMeta {
        try newElement.removeAttr("data-media-type")
        try newElement.removeAttr("data-media-meta")
      }
    }
    // Match Mozilla semantics: move nodes instead of cloning to avoid any
    // possibility of duplicate/reordered child content during retagging.
    while let firstChild = element.getChildNodes().first {
      try newElement.appendChild(firstChild)
    }

    try element.replaceWith(newElement)
    return newElement
  }

  /// Link density = length of link text / total text length.
  /// Hash URLs (`#...`) count at a reduced 0.3 weight, matching upstream's
  /// treatment of in-page anchor links as less "linky" than real navigation.
  /// Canonical implementation shared by `ArticleCleaner`, `ContentExtractor`,
  /// `Readability.prepDocument`, and `NodeScoringManager`.
  static func getLinkDensity(_ element: Element) throws -> Double {
    let textLength = try getInnerText(element).count
    if textLength == 0 {
      return 0
    }

    let links = try element.select("a")
    var linkLength = 0.0
    for link in links {
      let href = (try? link.attr("href")) ?? ""
      let coefficient = href.hasPrefix("#") ? 0.3 : 1.0
      try linkLength += Double(getInnerText(link).count) * coefficient
    }

    return linkLength / Double(textLength)
  }

  /// Preserve a figure's inner wrapper div rather than letting later cleanup
  /// collapse it into a bare `<p>`. `hasFigureAncestor` is computed by the
  /// caller since `ArticleCleaner` and `ContentExtractor` each run at a
  /// different pipeline stage with their own (deliberately unlimited-depth)
  /// ancestor search.
  ///
  /// Canonical implementation shared by `ArticleCleaner` and `ContentExtractor`,
  /// which had quietly diverged: only `ContentExtractor` recognized the
  /// `aspectRatioPlaceholder` class used by some lazy-loading layouts to
  /// reserve image space. That check is a real, site-independent signal, so
  /// it now applies at both pipeline stages.
  static func shouldPreserveFigureImageWrapper(_ element: Element, hasFigureAncestor: Bool) -> Bool {
    guard hasFigureAncestor else { return false }
    let hasImageMedia = ((try? element.select("img, picture").isEmpty()) == false)
    guard hasImageMedia else { return false }

    let className = ((try? element.className()) ?? "").lowercased()
    if className.contains("aspectratioplaceholder") {
      return true
    }

    // Preserve single-child figure wrappers to avoid collapsing image-only
    // figure structure into a bare <p> in late cleanup.
    if let parent = element.parent(),
       parent.tagName().lowercased() == "figure",
       parent.children().count == 1
    {
      return true
    }

    // Preserve wrappers that carry explicit syndicated-media metadata.
    let contenteditable = ((try? element.attr("contenteditable")) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let syndicationRights = ((try? element.attr("data-syndicationrights")) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if !contenteditable.isEmpty || !syndicationRights.isEmpty {
      return true
    }

    // Also preserve wrappers when parent figure declares syndicated media metadata.
    if let parent = element.parent(), parent.tagName().lowercased() == "figure" {
      let figureContentEditable = ((try? parent.attr("contenteditable")) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      let figureSyndicationRights = ((try? parent.attr("data-syndicationrights")) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if figureContentEditable == "false" || !figureSyndicationRights.isEmpty {
        return true
      }
    }

    return false
  }

  /// Detects a `<p>` sequence that looks like one paragraph split into many
  /// short fragments — commonly seen in print-info tails where inline spans
  /// get broken into consecutive short paragraphs. Looks at the leading
  /// `paragraphs.prefix(6)` and requires at least 3 of them to be short.
  ///
  /// `requireProseStart` additionally requires a short fragment to start with
  /// a letter, so formula-like content (e.g. "(1 + cos(x))/2") isn't
  /// mistaken for fragmented prose. `ArticleCleaner.mergeFragmentedParagraphDivs`
  /// (broad, any `<div>` of only-`<p>` children) and
  /// `Readability.simplifyNestedElements` (narrow, one specific NYTimes
  /// `div > div > article` shape) both use this detector but keep their own,
  /// deliberately different, trigger/threshold and merge-output shape.
  static func looksLikeFragmentedParagraphs(_ paragraphs: [Element], requireProseStart: Bool) -> Bool {
    let prefix = Array(paragraphs.prefix(min(6, paragraphs.count)))
    let shortPrefixCount = prefix.count(where: { paragraph in
      let text = ((try? getInnerText(paragraph)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard text.count <= 24 else { return false }
      guard requireProseStart else { return true }
      guard let first = text.unicodeScalars.first else { return false }
      return CharacterSet.letters.contains(first)
    })
    return shortPrefixCount >= 3
  }

  /// Runs a CSS selector under `root` and excludes `root` itself from the
  /// results (by reference identity), since SwiftSoup's `select` includes the
  /// context element itself when it matches the selector — unlike a browser's
  /// `querySelectorAll`, which only searches descendants.
  static func selectExcludingRoot(_ selector: String, in root: Element) throws -> [Element] {
    try root.select(selector).array().filter { $0 !== root }
  }

  /// Set element tag name by replacing the element
  static func setTagName(_ element: Element, newTag: String) throws -> Element {
    let doc = element.ownerDocument() ?? Document("")
    let replacement = try doc.createElement(newTag.lowercased())
    try copyAttributes(from: element, to: replacement)
    while let firstChild = element.getChildNodes().first {
      try replacement.appendChild(firstChild)
    }
    try element.replaceWith(replacement)
    return replacement
  }

  /// Copy all attributes from source to target.
  static func copyAttributes(from source: Element, to target: Element) throws {
    if let attributes = source.getAttributes() {
      for attr in attributes {
        try target.attr(attr.getKey(), attr.getValue())
      }
    }
  }

  /// Clone all child nodes from source into target preserving node order.
  static func cloneChildNodes(from source: Element, to target: Element, in doc: Document) throws {
    for node in source.getChildNodes() {
      if let childElement = node as? Element {
        let childClone = try cloneElement(childElement, in: doc)
        try target.appendChild(childClone)
      } else if let textNode = node as? TextNode {
        // Preserve original whitespace; TextNode.text() normalizes spaces.
        let textClone = TextNode(textNode.getWholeText(), doc.location())
        try target.appendChild(textClone)
      }
    }
  }

  /// Clone an element into document context
  /// Preserves the original order of child nodes (elements and text)
  /// - Parameters:
  ///   - element: Element to clone
  ///   - doc: Document for creating the clone
  /// - Returns: Cloned element with proper document ownership
  static func cloneElement(_ element: Element, in doc: Document) throws -> Element {
    let clone = try doc.createElement(element.tagName())
    try copyAttributes(from: element, to: clone)
    try cloneChildNodes(from: element, to: clone, in: doc)

    return clone
  }
}
