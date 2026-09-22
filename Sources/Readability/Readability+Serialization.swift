// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

extension Readability {

  // MARK: - Content Serialization

  func cleanAndSerialize(_ element: Element, sourceURL: URL?) throws -> String {
    let cleaned = try cleanForOutput(element, sourceURL: sourceURL)
    return try serializeCleaned(cleaned)
  }

  /// Clone `element` and apply every Mozilla post-processing step (relative-URL
  /// resolution, wrapper simplification, class stripping, whitespace trimming),
  /// returning the cleaned subtree without serializing it. Shared by the string
  /// serializer and the structured `extractContent()` path.
  func cleanForOutput(_ element: Element, sourceURL: URL?) throws -> Element {
    let cleaned = try DOMHelpers.cloneElement(element, in: doc)

    // Match Mozilla post-processing order:
    // 1) fix relative links/media URLs
    // 2) simplify nested wrappers
    // 3) optionally strip classes
    try fixRelativeURIs(cleaned)
    try simplifyNestedElements(cleaned)
    try SiteRuleRegistry.applySerializationRules(to: cleaned, sourceURL: sourceURL)
    if !options.preservesClasses {
      try cleanClasses(cleaned)
    }
    try trimParagraphBoundaryWhitespace(cleaned)
    try wrapOrphanRootCellContentIfNeeded(cleaned)

    return cleaned
  }

  func serializeCleaned(_ cleaned: Element) throws -> String {
    try serializeWithDocumentSettings(cleaned)
  }

  private func serializeWithDocumentSettings(_ element: Element) throws -> String {
    doc.outputSettings().prettyPrint(pretty: false)

    // SwiftSoup uses default pretty-print settings for detached nodes.
    // Attach the serialization clone temporarily so pre/code whitespace is
    // emitted with the document's output settings.
    let host = try doc.createElement("div")
    try host.appendChild(element)
    if let body = doc.body() {
      try body.appendChild(host)
    } else {
      try doc.appendChild(host)
    }
    defer {
      try? host.remove()
    }

    return try element.html()
  }

  /// A single `<td>`/`<th>` can end up as the page wrapper's only content
  /// (e.g. after `handleSingleCellTables` flattens a root-level single-cell
  /// table). A bare table cell can't stand outside a `<table>`, so Mozilla
  /// wraps the page wrapper's content in an extra `<div>` before output.
  /// Done here on the DOM — pre-serialization — rather than by pattern-matching
  /// the serialized HTML string and splicing a `<div>` into it with regex.
  private func wrapOrphanRootCellContentIfNeeded(_ articleContent: Element) throws {
    guard let pageWrapper = try articleContent.select("#readability-page-1").first(),
          let firstChild = pageWrapper.children().first,
          ["td", "th"].contains(firstChild.tagName().lowercased())
    else {
      return
    }

    let wrapper = try doc.createElement("div")
    while let child = pageWrapper.getChildNodes().first {
      try wrapper.appendChild(child)
    }
    try pageWrapper.appendChild(wrapper)
  }

  private func cleanClasses(_ element: Element) throws {
    let preservedClasses = Set(Configuration.classesToPreserve + options.classesToPreserve)
    let className = (try? element.className()) ?? ""
    let newClasses = className
      .split(separator: " ")
      .map(String.init)
      .filter { preservedClasses.contains($0) }
      .joined(separator: " ")

    if newClasses.isEmpty {
      try element.removeAttr("class")
    } else {
      try element.attr("class", newClasses)
    }

    for child in element.children() {
      try cleanClasses(child)
    }
  }

  private func fixRelativeURIs(_ articleContent: Element) throws {
    let documentURL = URL(string: doc.location())
    let effectiveBaseURL: URL? = {
      guard let baseElement = try? doc.select("base[href]").first(),
            let rawBaseHref = try? baseElement.attr("href")
      else {
        return documentURL
      }

      let trimmedBaseHref = rawBaseHref.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedBaseHref.isEmpty else { return documentURL }

      if let docURL = documentURL,
         let resolved = URL(string: trimmedBaseHref, relativeTo: docURL)?.absoluteURL
      {
        return resolved
      }

      return URL(string: trimmedBaseHref) ?? documentURL
    }()
    let baseMatchesDocument = effectiveBaseURL?.absoluteString == documentURL?.absoluteString

    func toAbsoluteURI(_ rawURI: String) -> String {
      let uri = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !uri.isEmpty else { return rawURI }

      // Keep data URLs verbatim to match Mozilla/jsdom behavior.
      if uri.lowercased().hasPrefix("data:") {
        return uri
      }

      if uri.hasPrefix("#"), baseMatchesDocument {
        return uri
      }

      if let base = effectiveBaseURL,
         let resolved = URL(string: uri, relativeTo: base)?.absoluteURL
      {
        if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
           components.path.isEmpty
        {
          components.path = "/"
          return components.string ?? resolved.absoluteString
        }
        return resolved.absoluteString
      }

      if let parsed = URL(string: uri),
         parsed.scheme != nil
      {
        let resolved = parsed.absoluteURL
        if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
           components.path.isEmpty
        {
          components.path = "/"
          return components.string ?? resolved.absoluteString
        }
        return resolved.absoluteString
      }

      // Fallback for malformed relative URLs (for example strings prefixed
      // by zero-width characters before an absolute-looking URL).
      if let base = effectiveBaseURL {
        let encoded = uri.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? uri
        if let resolved = URL(string: encoded, relativeTo: base)?.absoluteURL {
          if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
             components.path.isEmpty
          {
            components.path = "/"
            return components.string ?? resolved.absoluteString
          }
          return resolved.absoluteString
        }
      }

      let hasExplicitScheme = uri.range(
        of: "^[a-zA-Z][a-zA-Z0-9+.-]*:",
        options: .regularExpression
      ) != nil
      if let base = effectiveBaseURL,
         !hasExplicitScheme,
         !uri.hasPrefix("//"),
         !uri.hasPrefix("/"),
         !uri.hasPrefix("#")
      {
        var baseString = base.absoluteString
        if !baseString.hasSuffix("/") {
          if let slashIndex = baseString.lastIndex(of: "/") {
            baseString = String(baseString[...slashIndex])
          } else {
            baseString += "/"
          }
        }
        return baseString + uri
      }

      return uri
    }

    let links = try articleContent.select("a[href]")
    for link in links {
      let href = (try? link.attr("href")) ?? ""
      guard !href.isEmpty else { continue }
      let normalizedHref = href.trimmingCharacters(in: .whitespacesAndNewlines)

      if normalizedHref.lowercased().hasPrefix("javascript:") {
        if link.getChildNodes().count == 1, link.getChildNodes().first is TextNode {
          let text: String = if let textNode = link.getChildNodes().first as? TextNode {
            // Preserve original whitespace around inline links.
            textNode.getWholeText()
          } else {
            try link.text()
          }
          let replacement = TextNode(text, doc.location())
          try link.replaceWith(replacement)
        } else {
          let span = try doc.createElement("span")
          for child in link.getChildNodes() {
            try span.appendChild(child)
          }
          try link.replaceWith(span)
        }
        continue
      }

      try link.attr("href", toAbsoluteURI(normalizedHref))
    }

    let mediaElements = try articleContent.select("img, picture, figure, video, audio, source")
    let srcsetPattern = "(\\S+)(\\s+[\\d.]+[xw])?(\\s*(?:,|$))"
    let srcsetRegex = try? NSRegularExpression(pattern: srcsetPattern)
    for media in mediaElements {
      let src = (try? media.attr("src")) ?? ""
      if !src.isEmpty {
        try media.attr("src", toAbsoluteURI(src))
      }

      let poster = (try? media.attr("poster")) ?? ""
      if !poster.isEmpty {
        try media.attr("poster", toAbsoluteURI(poster))
      }

      let srcset = (try? media.attr("srcset")) ?? ""
      if !srcset.isEmpty {
        if let regex = srcsetRegex {
          let nsRange = NSRange(srcset.startIndex ..< srcset.endIndex, in: srcset)
          let matches = regex.matches(in: srcset, options: [], range: nsRange)
          var rewritten = srcset
          for match in matches.reversed() {
            guard match.numberOfRanges >= 4,
                  let totalRange = Range(match.range(at: 0), in: rewritten),
                  let r1 = Range(match.range(at: 1), in: srcset),
                  let r2 = Range(match.range(at: 2), in: srcset),
                  let r3 = Range(match.range(at: 3), in: srcset)
            else {
              continue
            }
            let rawURL = String(srcset[r1])
            let descriptor = String(srcset[r2])
            let trailing = String(srcset[r3])
            let replacement = toAbsoluteURI(rawURL) + descriptor + trailing
            rewritten.replaceSubrange(totalRange, with: replacement)
          }
          try media.attr("srcset", rewritten)
        }
      }
    }
  }

  private func simplifyNestedElements(_ articleContent: Element) throws {
    let cleaner = ArticleCleaner(options: options)
    var node: Element? = articleContent

    while let current = node {
      let next = DOMTraversal.getNextNode(current)
      let tagName = current.tagName().uppercased()

      if let _ = current.parent(),
         tagName == "DIV" || tagName == "SECTION",
         !current.id().hasPrefix("readability")
      {
        if tagName == "DIV",
           let parent = current.parent(),
           parent.tagName().lowercased() == "div",
           parent.parent()?.tagName().lowercased() == "article"
        {
          let children = current.children().array()
          if children.count >= 3,
             children.allSatisfy({ $0.tagName().lowercased() == "p" })
          {
            if DOMHelpers.looksLikeFragmentedParagraphs(children, requireProseStart: false) {
              let merged = try doc.createElement("p")
              for paragraph in children {
                while let first = paragraph.getChildNodes().first {
                  try merged.appendChild(first)
                }
              }
              try current.replaceWith(merged)
              node = merged
              continue
            }
          }
        }

        if DOMTraversal.isElementWithoutContent(current) {
          try current.remove()
        } else if cleaner.hasSingleTagInsideElement(current, tag: "DIV") ||
          cleaner.hasSingleTagInsideElement(current, tag: "SECTION"),
          let child = current.children().first
        {
          if let attributes = current.getAttributes() {
            for attr in attributes {
              let key = attr.getKey().lowercased()
              if child.tagName().lowercased() == "p", key == "dir" {
                continue
              }
              try child.attr(attr.getKey(), attr.getValue())
            }
          }
          try current.replaceWith(child)
        }
      }

      node = next
    }
  }

  /// Remove pure-whitespace boundary text nodes from paragraphs to match jsdom output shape.
  private func trimParagraphBoundaryWhitespace(_ articleContent: Element) throws {
    let paragraphs = try articleContent.select("p")
    for paragraph in paragraphs {
      while let first = paragraph.getChildNodes().first as? TextNode,
            first.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        try first.remove()
      }

      while let last = paragraph.getChildNodes().last as? TextNode,
            last.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        try last.remove()
      }
    }
  }
}
