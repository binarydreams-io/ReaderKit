// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

struct HeadingView: View {
  let level: Int
  let text: AttributedString
  let style: ReaderStyle

  private var size: CGFloat {
    switch level {
    case 1: style.baseFontSize * 1.8
    case 2: style.baseFontSize * 1.5
    case 3: style.baseFontSize * 1.3
    default: style.baseFontSize * 1.15
    }
  }

  private var accessibilityHeadingLevel: AccessibilityHeadingLevel {
    switch level {
    case 1: .h1
    case 2: .h2
    case 3: .h3
    case 4: .h4
    case 5: .h5
    default: .h6
    }
  }

  var body: some View {
    Text(text)
      .font(.system(size: size, weight: .semibold, design: style.fontDesign))
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, style.baseFontSize / 2)
      .accessibilityAddTraits(.isHeader)
      .accessibilityHeading(accessibilityHeadingLevel)
  }
}
