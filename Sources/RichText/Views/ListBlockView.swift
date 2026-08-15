// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

struct ListBlockView: View {
  let ordered: Bool
  let items: [[ArticleBlock]]
  let style: ReaderStyle

  var body: some View {
    VStack(alignment: .leading, spacing: style.baseFontSize / 2) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, itemBlocks in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(ordered ? "\(index + 1)." : "•")
            .font(.system(size: style.baseFontSize, design: style.fontDesign))
            .foregroundStyle(style.secondaryTextColor)
          VStack(alignment: .leading, spacing: style.baseFontSize / 2) {
            ForEach(Array(itemBlocks.enumerated()), id: \.offset) { _, block in
              BlockView(block: block, style: style)
            }
          }
        }
      }
    }
    .padding(.leading, 4)
  }
}
