// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

extension Readability {

  // MARK: - Document Preparation

  func unwrapNoscriptImages() throws {
    let imgs = try doc.select("img")
    for img in imgs {
      var keep = false
      if let attrs = img.getAttributes() {
        for attr in attrs {
          let key = attr.getKey().lowercased()
          if key == "src" || key == "srcset" || key == "data-src" || key == "data-srcset" {
            keep = true
            break
          }
          if attr.getValue().range(of: "\\.(jpg|jpeg|png|webp)", options: [.regularExpression, .caseInsensitive]) != nil {
            keep = true
            break
          }
        }
      }

      if !keep {
        try img.remove()
      }
    }

    let noscripts = try doc.select("noscript")
    for noscript in noscripts {
      guard let extractedImage = try extractSingleImage(fromNoscript: noscript) else {
        continue
      }

      guard let prevElement = try? noscript.previousElementSibling(),
            isSingleImage(prevElement)
      else {
        continue
      }

      let prevImg: Element? = if prevElement.tagName().uppercased() == "IMG" {
        prevElement
      } else {
        try prevElement.select("img").first()
      }

      guard let oldImg = prevImg else { continue }
      try copyLegacyImageAttributes(from: oldImg, to: extractedImage)
      try prevElement.replaceWith(extractedImage)
    }
  }

  /// Promote semantic full-article `<noscript>` fallbacks into the live DOM.
  ///
  /// Mozilla removes all remaining `<noscript>` nodes after its image-only
  /// upgrade path. Some modern app-shell pages, however, keep the entire
  /// server-rendered article inside `<noscript>` as an accessibility or
  /// no-JS fallback. We intentionally recover only those high-confidence
  /// article fallbacks instead of broadly preserving all `<noscript>` nodes.
  func promoteReadableNoscriptFallbacks() throws {
    let noscripts = try doc.select("noscript")
    for noscript in noscripts {
      guard let promoted = try promotedReadableNoscriptElement(from: noscript) else {
        continue
      }
      try noscript.replaceWith(promoted)
    }
  }

  private func promotedReadableNoscriptElement(from noscript: Element) throws -> Element? {
    guard try extractSingleImage(fromNoscript: noscript) == nil else {
      return nil
    }

    let html = try noscript.html().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !html.isEmpty else {
      return nil
    }

    let fragment = try SwiftSoup.parseBodyFragment(html)
    guard let fragmentBody = fragment.body() else {
      return nil
    }

    let warningText = try DOMHelpers.getInnerText(fragmentBody).lowercased()
    guard !warningText.isEmpty,
          !looksLikeNoscriptWarning(warningText)
    else {
      return nil
    }

    guard let semanticRoot = try readableNoscriptSemanticRoot(in: fragmentBody) else {
      return nil
    }

    let threshold = max(options.minimumCharacterCount, Configuration.defaultCharThreshold)
    let textLength = try DOMHelpers.getInnerText(semanticRoot).count
    let paragraphCount = try semanticRoot.select("p").count
    let linkDensity = try getLinkDensity(semanticRoot)

    guard textLength >= threshold,
          paragraphCount >= 5,
          linkDensity < 0.35
    else {
      return nil
    }

    let promotedRoot: Element = if fragmentBody.children().count == 1, let onlyChild = fragmentBody.children().first {
      onlyChild
    } else {
      semanticRoot
    }

    return try DOMHelpers.cloneElement(promotedRoot, in: doc)
  }

  private func readableNoscriptSemanticRoot(in fragmentBody: Element) throws -> Element? {
    if let article = try fragmentBody.select("article").first() {
      return article
    }
    if let main = try fragmentBody.select("main").first() {
      return main
    }

    var node: Element? = fragmentBody
    while let current = node {
      let itemProp = (try? current.attr("itemprop").lowercased()) ?? ""
      if itemProp.contains("articlebody") {
        return current
      }
      node = DOMTraversal.getNextNode(current)
    }

    return nil
  }

  private func looksLikeNoscriptWarning(_ text: String) -> Bool {
    let warningPhrases = [
      "enable javascript",
      "javascript enabled",
      "without javascript",
      "full functionality",
      "modern browser"
    ]
    return warningPhrases.contains { text.contains($0) }
  }

  private func getLinkDensity(_ element: Element) throws -> Double {
    try DOMHelpers.getLinkDensity(element)
  }

  private func extractSingleImage(fromNoscript noscript: Element) throws -> Element? {
    let html = try noscript.html()
    let fragment = try SwiftSoup.parseBodyFragment(html)
    guard let body = fragment.body(),
          isSingleImage(body),
          let img = try body.select("img").first()
    else {
      return nil
    }
    return try DOMHelpers.cloneElement(img, in: doc)
  }

  private func isSingleImage(_ element: Element?) -> Bool {
    var current = element
    while let node = current {
      if node.tagName().uppercased() == "IMG" {
        return true
      }
      if node.children().count != 1 {
        return false
      }
      let text = (try? node.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !text.isEmpty {
        return false
      }
      current = node.children().first
    }
    return false
  }

  private func copyLegacyImageAttributes(from oldImg: Element, to newImg: Element) throws {
    guard let attrs = oldImg.getAttributes() else { return }
    for attr in attrs {
      let key = attr.getKey()
      let value = attr.getValue()
      if value.isEmpty {
        continue
      }

      let lowerKey = key.lowercased()
      let looksLikeImageURL = value.range(
        of: "\\.(jpg|jpeg|png|webp)",
        options: [.regularExpression, .caseInsensitive]
      ) != nil
      guard lowerKey == "src" || lowerKey == "srcset" || looksLikeImageURL else {
        continue
      }

      let existing = (try? newImg.attr(key)) ?? ""
      if existing == value {
        continue
      }

      let targetKey = newImg.hasAttr(key) ? "data-old-\(key)" : key
      try newImg.attr(targetKey, value)
    }
  }

  func prepDocument() throws {
    // Keep media/embed nodes for later scoring/cleaning. Mozilla only strips
    // style tags at prep stage and defers iframe/embed pruning to article cleaning.
    let elementsToRemove = try doc.select("script, style, noscript, object, embed, template")
    try elementsToRemove.remove()

    try removeHiddenElements()
    try replaceBrs()
    try replaceFontTags()
  }

  /// Remove hidden elements from the document
  /// Handles aria-hidden, hidden attribute, display:none, and visibility:hidden
  private func removeHiddenElements() throws {
    try VisibilityRules.removeHiddenElements(from: doc)
  }

  /// Replaces 2 or more successive <br> elements with a single <p>.
  /// Whitespace between <br> elements are ignored.
  /// Based on Mozilla Readability.js _replaceBrs()
  private func replaceBrs() throws {
    let brs = try doc.select("br")

    for br in brs {
      // Get the next non-whitespace sibling
      var next = nextNode(br.nextSibling())
      var replaced = false

      // If we find a <br> chain, remove the <br>s until we hit another element
      // or non-whitespace. This leaves behind the first <br> in the chain.
      while let current = next,
            current.nodeName().lowercased() == "br"
      {
        replaced = true
        let brSibling = current.nextSibling()
        try current.remove()
        next = nextNode(brSibling)
      }

      // If we removed a <br> chain, replace the remaining <br> with a <p>
      if replaced {
        let p = try doc.createElement("p")
        try br.replaceWith(p)

        // Add all sibling nodes as children of the <p> until we hit another <br> chain
        next = p.nextSibling()
        while let current = next {
          // If we've hit another <br><br>, we're done adding children to this <p>
          if current.nodeName().lowercased() == "br" {
            if let nextElem = nextNode(current.nextSibling()),
               nextElem.nodeName().lowercased() == "br"
            {
              break
            }
          }

          // Only add phrasing content
          if !isPhrasingContent(current) {
            break
          }

          // Otherwise, make this node a child of the new <p>
          let sibling = current.nextSibling()
          try p.appendChild(current)
          next = sibling
        }

        // Remove trailing whitespace from the paragraph.
        // Use all child nodes to include trailing text nodes.
        while let lastChild = p.getChildNodes().last {
          if DOMTraversal.isWhitespace(lastChild) {
            try lastChild.remove()
          } else {
            break
          }
        }

        // If the parent is a <p>, convert it to a <div>
        if let parent = p.parent(),
           parent.tagName().lowercased() == "p"
        {
          _ = try DOMHelpers.setTagName(parent, newTag: "div")
        }
      }
    }
  }

  /// Get the next non-whitespace node, skipping text nodes that only contain whitespace
  /// Similar to Mozilla's _nextNode()
  private func nextNode(_ node: Node?) -> Node? {
    var current = node
    while let n = current {
      // If it's an element node, return it
      if n is Element {
        return n
      }
      // If it's a text node with non-whitespace content, return it
      if let textNode = n as? TextNode {
        if !textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return n
        }
      }
      // Skip whitespace text nodes and move to next sibling
      current = n.nextSibling()
    }
    return nil
  }

  /// Check if node is phrasing content (inline content)
  private func isPhrasingContent(_ node: Node) -> Bool {
    DOMTraversal.isPhrasingContent(node)
  }

  private func replaceFontTags() throws {
    let fonts = try doc.select("font")
    for font in fonts {
      let span = try doc.createElement("span")

      // Copy attributes from font to span
      if let attributes = font.getAttributes() {
        for attr in attributes {
          try span.attr(attr.getKey(), attr.getValue())
        }
      }

      // Move all child nodes (including text nodes) to span in original order
      // We move rather than clone since we're replacing the parent
      let childNodes = font.getChildNodes()
      for node in childNodes {
        try span.appendChild(node)
      }

      try font.replaceWith(span)
    }
  }
}
