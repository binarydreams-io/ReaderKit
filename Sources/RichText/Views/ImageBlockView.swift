// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import NukeUI
import SwiftUI

struct ImageBlockView: View {
  let image: ArticleImage
  let style: ReaderStyle

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyImage(url: image.url) { state in
        if let img = state.image {
          img.resizable().aspectRatio(contentMode: .fit)
        } else if state.error != nil {
          Color.clear.frame(height: 0)
        } else {
          Rectangle().fill(.quaternary).aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
      }
      .frame(maxWidth: .infinity)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .accessibilityLabel(image.alt ?? image.caption ?? "")
      .accessibilityHidden(image.alt == nil && image.caption == nil)

      if let caption = image.caption {
        Text(caption)
          .font(.system(size: style.baseFontSize * 0.85, design: style.fontDesign))
          .foregroundStyle(style.secondaryTextColor)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
