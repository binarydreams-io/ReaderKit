// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

struct CodeBlockView: View {
  let code: String
  let style: ReaderStyle

  var body: some View {
    ScrollView(.horizontal) {
      Text(code)
        .font(.system(size: style.baseFontSize * 0.9, design: .monospaced))
        .textSelection(.enabled)
        .padding(12)
    }
    .scrollIndicators(.hidden)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
  }
}
