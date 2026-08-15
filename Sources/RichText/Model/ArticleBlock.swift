// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation

/// One rendered unit of an article. Built once (off-main) from Readability's
/// cleaned DOM and rendered by the native SwiftUI layer. `Sendable` so it can
/// cross back to the main actor; style is applied at render time, not here.
public enum ArticleBlock: Sendable, Equatable {
  case heading(level: Int, AttributedString)
  case paragraph(AttributedString)
  case image(ArticleImage)
  indirect case blockquote([ArticleBlock])
  indirect case list(ordered: Bool, items: [[ArticleBlock]])
  case codeBlock(code: String, language: String?)
  case table(ArticleTable)
  case embed(ArticleEmbed)
  case thematicBreak
}
