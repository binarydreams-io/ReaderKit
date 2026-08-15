// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Renders a parsed article as native SwiftUI. Sizes to its content, so it
/// composes inside a parent `ScrollView` (no nested scroll, no fixed height).
public struct RichTextView: View {
  private let blocks: [ArticleBlock]
  private let style: ReaderStyle

  public init(blocks: [ArticleBlock], style: ReaderStyle) {
    self.blocks = blocks
    self.style = style
  }

  public var body: some View {
    LazyVStack(alignment: .leading, spacing: style.baseFontSize) {
      ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
        BlockView(block: block, style: style)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .tint(style.linkColor)
    .foregroundStyle(style.textColor)
  }
}
