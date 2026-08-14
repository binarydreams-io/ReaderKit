import Foundation
import SwiftSoup

/// Merges split NYTimes print-info paragraph fragments to match Mozilla output.
///
/// SiteRule Metadata:
/// - Scope: NYTimes print-info tail block normalization
/// - Phase: `postParagraph` cleanup
/// - Trigger: container text containing "a version of this article appears in print on"
/// - Evidence: NYTimes real-world fixtures (`nytimes-1`, `nytimes-2`)
/// - Risk if misplaced: fragmented print-info paragraphs remain split in output
enum NYTimesSplitPrintInfoRule: ArticleCleanerSiteRule {
  static let id = "nytimes-split-print-info"
  static let hosts: [String]? = ["nytimes.com"]

  static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
    let candidates = try articleContent.select("div > div")
    for container in candidates.reversed() {
      guard container.parent() != nil else { continue }
      let text = try DOMHelpers.getInnerText(container).lowercased()
      guard text.contains("a version of this article appears in print on") else { continue }

      let paragraphs = container.children().array().filter { $0.tagName().lowercased() == "p" }
      guard paragraphs.count >= 3 else { continue }

      let doc = container.ownerDocument() ?? Document("")
      let merged = try doc.createElement("p")

      for paragraph in paragraphs {
        while let first = paragraph.getChildNodes().first {
          try merged.appendChild(first)
        }
        try paragraph.remove()
      }

      if let firstChild = container.getChildNodes().first {
        try firstChild.before(merged)
      } else {
        try container.appendChild(merged)
      }
    }
  }
}

/// Catches the residual `article > div > div` print-info shape that survives
/// into final serialization — a companion to `NYTimesSplitPrintInfoRule`,
/// which runs earlier (`postParagraph`, on `div > div`) and only acts once
/// there are already 3+ fragment paragraphs. By serialization time some
/// print-info tails have simplified down to a single wrapped `<p>`, which
/// this rule unwraps; multi-paragraph tails that weren't merged upstream are
/// merged here too, as a safety net.
///
/// SiteRule Metadata:
/// - Scope: NYTimes print-info tail block normalization (serialization pass)
/// - Phase: `serialization` cleanup
/// - Trigger: `article > div > div` containing "a version of this article appears in print on"
/// - Evidence: `realworld/nytimes-3`, `realworld/nytimes-4`
enum NYTimesSplitPrintInfoSerializationRule: SerializationSiteRule {
  static let id = "nytimes-split-print-info-serialization"
  static let hosts: [String]? = ["nytimes.com"]

  static func apply(to articleContent: Element) throws {
    let candidates = try articleContent.select("article > div > div")
    for container in candidates.reversed() {
      let text = try DOMHelpers.getInnerText(container).lowercased()
      guard text.contains("a version of this article appears in print on") else { continue }

      let children = container.children().array()
      let paragraphs = children.filter { $0.tagName().lowercased() == "p" }

      if paragraphs.count == 1, children.count == 1, let onlyParagraph = paragraphs.first {
        try container.replaceWith(onlyParagraph)
        continue
      }

      guard paragraphs.count >= 3 else { continue }

      let doc = container.ownerDocument() ?? Document("")
      let merged = try doc.createElement("p")
      for paragraph in paragraphs {
        while let first = paragraph.getChildNodes().first {
          try merged.appendChild(first)
        }
        try paragraph.remove()
      }
      try container.replaceWith(merged)
    }
  }
}
