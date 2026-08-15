// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

struct BlockquoteView: View {
  let blocks: [ArticleBlock]
  let style: ReaderStyle

  var body: some View {
    HStack(spacing: 12) {
      Capsule()
        .fill(style.secondaryTextColor)
        .frame(width: 4)
      VStack(alignment: .leading, spacing: style.baseFontSize / 2) {
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
          BlockView(block: block, style: style)
        }
      }
    }
    .foregroundStyle(style.secondaryTextColor)
  }
}
