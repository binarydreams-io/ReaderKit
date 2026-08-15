// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

struct TableBlockView: View {
  let table: ArticleTable
  let style: ReaderStyle

  var body: some View {
    ScrollView(.horizontal) {
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
        ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
          GridRow {
            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
              Text(cell).font(cellFont(isHeader: table.hasHeaderRow && rowIndex == 0))
            }
          }
          if rowIndex == 0, table.hasHeaderRow {
            Divider()
          }
        }
      }
      .padding(8)
    }
    .scrollIndicators(.hidden)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  }

  private func cellFont(isHeader: Bool) -> Font {
    .system(size: style.baseFontSize * 0.9, weight: isHeader ? .semibold : .regular, design: style.fontDesign)
  }
}
