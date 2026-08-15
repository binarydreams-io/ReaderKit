// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

extension Readability {

  // MARK: - Excerpt Extraction

  func extractExcerpt(from element: Element) throws -> String? {
    let paragraphs = try element.select("p")
    for p in paragraphs {
      let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty {
        let rawText = excerptTextPreservingWhitespace(from: p)
          .trimmingCharacters(in: .whitespacesAndNewlines)
        // Prefer whitespace-preserving text when paragraph contains
        // semantic line breaks that should survive excerpt fallback.
        if rawText.contains("\n") {
          return rawText
        }
        // Match Mozilla fallback behavior: use first non-empty paragraph text.
        return text
      }
    }

    return nil
  }

  private func excerptTextPreservingWhitespace(from element: Element) -> String {
    func collect(from node: Node, into output: inout String) {
      if let textNode = node as? TextNode {
        output.append(textNode.getWholeText())
        return
      }
      if let childElement = node as? Element {
        for child in childElement.getChildNodes() {
          collect(from: child, into: &output)
        }
      }
    }

    var raw = ""
    for node in element.getChildNodes() {
      collect(from: node, into: &raw)
    }
    return raw
  }

  func removeTitleMatchedHeaders(from element: Element, title: String) throws {
    func normalize(_ input: String) -> String {
      input
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .lowercased()
    }

    let normalizedTitle = normalize(title)

    guard !normalizedTitle.isEmpty else { return }

    let headers = try element.select("h1, h2")
    for header in headers {
      let text = (try? header.text()) ?? ""
      let normalizedHeader = normalize(text)

      if normalizedHeader == normalizedTitle {
        try header.remove()
        continue
      }

      // Some pages split the visual title into stacked headings like:
      // "Topic:" + "Actual headline". Mozilla drops the prefix heading
      // when the concatenation still matches the extracted title.
      let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmedText.hasSuffix(":"),
            let next = try? header.nextElementSibling(),
            ["H1", "H2", "H3", "H4", "H5", "H6"].contains(next.tagName().uppercased())
      else {
        continue
      }

      let nextText = (try? next.text()) ?? ""
      let combined = normalize("\(trimmedText) \(nextText)")
      if !combined.isEmpty,
         combined == normalizedTitle || normalizedTitle.hasSuffix(combined)
      {
        try header.remove()
      }
    }
  }
}
