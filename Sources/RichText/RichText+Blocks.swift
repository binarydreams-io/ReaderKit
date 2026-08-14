import Foundation
import SwiftSoup

extension RichText {
  private static let blockTags: Set<String> = [
    "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "blockquote",
    "pre", "figure", "picture", "img", "table", "hr", "iframe", "video",
    "div", "section", "article", "main", "header", "footer", "aside", "figcaption"
  ]

  func parseBlocks(in element: Element) throws -> [ArticleBlock] {
    var blocks: [ArticleBlock] = []
    for node in element.getChildNodes() {
      if let textNode = node as? TextNode {
        let text = collapseWhitespace(textNode.getWholeText())
          .trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
          blocks.append(.paragraph(AttributedString(text)))
        }
        continue
      }
      guard let child = node as? Element else { continue }
      try blocks.append(contentsOf: parseElement(child))
    }
    return blocks
  }

  private func parseElement(_ element: Element) throws -> [ArticleBlock] {
    switch element.tagName().lowercased() {
    case "h1", "h2", "h3", "h4", "h5", "h6":
      let level = Int(element.tagName().dropFirst()) ?? 1
      let text = try inlineText(of: element)
      return text.characters.isEmpty ? [] : [.heading(level: level, text)]

    case "p":
      let text = try inlineText(of: element)
      return text.characters.isEmpty ? [] : [.paragraph(text)]

    case "hr":
      return [.thematicBreak]

    case "ul", "ol":
      let items = try parseListItems(element)
      return items.isEmpty ? [] : [.list(ordered: element.tagName().lowercased() == "ol", items: items)]

    case "blockquote":
      let inner: [ArticleBlock]
      if try hasBlockLevelChild(element) {
        inner = try parseBlocks(in: element)
      } else {
        let text = try inlineText(of: element)
        inner = text.characters.isEmpty ? [] : [.paragraph(text)]
      }
      return inner.isEmpty ? [] : [.blockquote(inner)]

    case "pre":
      let code = try element.text()
      return code.isEmpty ? [] : [.codeBlock(code: code, language: nil)]

    case "img", "picture":
      // `<picture>` wraps responsive `<source>`s plus a fallback `<img>`; pull
      // the inner image out rather than dropping the whole element.
      return try imageBlock(from: element).map { [$0] } ?? []

    case "figure":
      if let image = try imageBlock(from: element) {
        return [image]
      }
      return try hasBlockLevelChild(element) ? parseBlocks(in: element) : []

    case "figcaption":
      return []

    case "table":
      return try parseTable(element).map { [$0] } ?? []

    case "iframe", "video":
      return try embedBlock(from: element).map { [$0] } ?? []

    case "div", "section", "article", "main", "header", "footer", "aside":
      if try hasBlockLevelChild(element) {
        return try parseBlocks(in: element)
      }
      let text = try inlineText(of: element)
      return text.characters.isEmpty ? [] : [.paragraph(text)]

    default:
      let text = try inlineText(of: element)
      return text.characters.isEmpty ? [] : [.paragraph(text)]
    }
  }

  private func parseTable(_ table: Element) throws -> ArticleBlock? {
    let rowElements = try table.select("tr").array()
    guard !rowElements.isEmpty else { return nil }

    var rows: [[AttributedString]] = []
    var hasHeaderRow = false
    for (index, tr) in rowElements.enumerated() {
      let cells = tr.children().filter {
        let tag = $0.tagName().lowercased()
        return tag == "td" || tag == "th"
      }
      guard !cells.isEmpty else { continue }
      if index == 0, cells.allSatisfy({ $0.tagName().lowercased() == "th" }) {
        hasHeaderRow = true
      }
      try rows.append(cells.map { try inlineText(of: $0) })
    }

    guard !rows.isEmpty else { return nil }
    return .table(ArticleTable(rows: rows, hasHeaderRow: hasHeaderRow))
  }

  private func imageBlock(from element: Element) throws -> ArticleBlock? {
    let imgElement: Element? = element.tagName().lowercased() == "img"
      ? element
      : try element.select("img").first()
    guard let img = imgElement else { return nil }

    // absUrl resolves relative sources against the base URL; already-absolute
    // sources (e.g. Readability's cleaned output) pass through unchanged.
    let src = ((try? img.absUrl("src")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !src.isEmpty, let url = URL(string: src) else { return nil }

    let alt = try? img.attr("alt")
    let caption = try element.select("figcaption").first()?.text()

    return .image(ArticleImage(
      url: url,
      alt: (alt?.isEmpty == false) ? alt : nil,
      caption: (caption?.isEmpty == false) ? caption : nil
    ))
  }

  private func parseListItems(_ list: Element) throws -> [[ArticleBlock]] {
    var items: [[ArticleBlock]] = []
    for li in list.children() where li.tagName().lowercased() == "li" {
      var itemBlocks: [ArticleBlock] = []
      if try hasBlockLevelChild(li) {
        itemBlocks = try parseBlocks(in: li)
      } else {
        let text = try inlineText(of: li)
        if !text.characters.isEmpty {
          itemBlocks = [.paragraph(text)]
        }
      }
      if !itemBlocks.isEmpty {
        items.append(itemBlocks)
      }
    }
    return items
  }

  func hasBlockLevelChild(_ element: Element) throws -> Bool {
    element.children().contains { Self.blockTags.contains($0.tagName().lowercased()) }
  }
}
