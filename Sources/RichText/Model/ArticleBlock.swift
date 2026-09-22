// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation

/// One rendered unit of an article. Built once (off-main) from Readability's
/// cleaned DOM and rendered by the native SwiftUI layer. `Sendable` so it can
/// cross back to the main actor; style is applied at render time, not here.
public enum ArticleBlock: Sendable, Equatable {
  /// A heading with a level from 1 through 6.
  case heading(level: Int, AttributedString)
  /// A paragraph of styled inline text.
  case paragraph(AttributedString)
  /// An image with optional alternative text and caption.
  case image(ArticleImage)
  /// A quotation that contains its own blocks.
  indirect case blockquote([ArticleBlock])
  /// A list. Each item contains its own blocks.
  indirect case list(ordered: Bool, items: [[ArticleBlock]])
  /// Preformatted code with an optional language name.
  case codeBlock(code: String, language: String?)
  /// A table of styled text cells.
  case table(ArticleTable)
  /// An embedded video or external link.
  case embed(ArticleEmbed)
  /// A horizontal rule between sections.
  case thematicBreak
}
