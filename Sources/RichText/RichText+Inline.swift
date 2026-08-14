import Foundation
import SwiftSoup

extension RichText {
  /// Build an `AttributedString` from an element's inline children, applying
  /// bold/italic/code intents and link attributes. Never uses NSAttributedString(html:).
  func inlineText(of element: Element) throws -> AttributedString {
    var result = AttributedString()
    for node in element.getChildNodes() {
      try appendInline(node, into: &result, intent: [], link: nil)
    }
    return trimmingWhitespace(result)
  }

  private func appendInline(
    _ node: Node,
    into result: inout AttributedString,
    intent: InlinePresentationIntent,
    link: URL?
  ) throws {
    if let textNode = node as? TextNode {
      let text = collapseWhitespace(textNode.getWholeText())
      guard !text.isEmpty else { return }
      var container = AttributeContainer()
      if !intent.isEmpty {
        container.inlinePresentationIntent = intent
      }
      if let link {
        container.link = link
      }
      result.append(AttributedString(text, attributes: container))
      return
    }

    guard let element = node as? Element else { return }

    switch element.tagName().lowercased() {
    case "br":
      result.append(AttributedString("\n"))
    case "strong", "b":
      try appendChildren(of: element, into: &result, intent: intent.union(.stronglyEmphasized), link: link)
    case "em", "i", "cite", "dfn", "var":
      try appendChildren(of: element, into: &result, intent: intent.union(.emphasized), link: link)
    case "code", "kbd", "samp", "tt":
      try appendChildren(of: element, into: &result, intent: intent.union(.code), link: link)
    case "a":
      let href = ((try? element.absUrl("href")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let resolved = URL(string: href) ?? link
      try appendChildren(of: element, into: &result, intent: intent, link: resolved)
    default:
      try appendChildren(of: element, into: &result, intent: intent, link: link)
    }
  }

  private func appendChildren(
    of element: Element,
    into result: inout AttributedString,
    intent: InlinePresentationIntent,
    link: URL?
  ) throws {
    for child in element.getChildNodes() {
      try appendInline(child, into: &result, intent: intent, link: link)
    }
  }

  func collapseWhitespace(_ string: String) -> String {
    string.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
  }

  private func trimmingWhitespace(_ input: AttributedString) -> AttributedString {
    var s = input
    while let first = s.characters.first, first.isWhitespace {
      s.removeSubrange(s.startIndex ..< s.characters.index(after: s.startIndex))
    }
    while let last = s.characters.last, last.isWhitespace {
      s.removeSubrange(s.characters.index(before: s.endIndex) ..< s.endIndex)
    }
    return s
  }
}
