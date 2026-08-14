import Foundation
import SwiftSoup

/// Removes compact `role="note"` callouts that are metadata/navigation
/// (e.g. "Main article: ..."), which Mozilla typically drops during
/// conditional cleanup.
///
/// The "Main article:"/"See also:" prefixes are literal English-Wikipedia
/// hatnote copy (MediaWiki's `{{Main}}`/`{{See also}}` templates render this
/// exact text) — genuinely tied to this one site/language edition, not a
/// generalizable pattern, so this stays a Wikipedia site rule rather than
/// living in the generic cleaner.
///
/// SiteRule Metadata:
/// - Scope: Wikipedia hatnote-style `role="note"` callouts
/// - Phase: `prepArticle` (after related-link/empty-container cleanup, before
///   div-to-p conversion)
/// - Trigger: `div[role=note]`/`aside[role=note]` under 80 chars, no media,
///   text starting with "Main article:" or "See also:"
/// - Evidence: `realworld/wikipedia`, `realworld/wikipedia-2`, `realworld/wikipedia-3`
enum WikipediaShortRoleNoteCalloutRule: ArticleCleanerSiteRule {
  static let id = "wikipedia-short-role-note-callout"
  static let hosts: [String]? = ["wikipedia.org"]

  static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
    let notes = try articleContent.select("div[role=note], aside[role=note]")
    for note in notes.reversed() {
      guard note.parent() != nil else { continue }
      if (try? note.select("img, picture, figure, video, iframe, object, embed, table").isEmpty()) == false {
        continue
      }

      let text = try DOMHelpers.getInnerText(note).trimmingCharacters(in: .whitespacesAndNewlines)
      if text.isEmpty || text.count > 80 {
        continue
      }
      if text.lowercased().hasPrefix("main article:") || text.lowercased().hasPrefix("see also:") {
        try note.remove()
      }
    }
  }
}
