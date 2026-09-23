// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import NukeUI
import SwiftUI

struct EmbedBlockView: View {
  let embed: ArticleEmbed
  let style: ReaderStyle
  @Environment(\.openURL) private var openURL

  var body: some View {
    Button { openURL(embed.url) } label: {
      switch embed.kind {
      case let .video(posterURL):
        ZStack {
          if let posterURL {
            LazyImage(url: posterURL) { state in
              if let img = state.image {
                img.resizable().scaledToFit()
              } else {
                Rectangle().fill(.quaternary).aspectRatio(16.0 / 9.0, contentMode: .fit)
              }
            }
          } else {
            Rectangle().fill(.quaternary).aspectRatio(16.0 / 9.0, contentMode: .fit)
          }
          Image(systemName: "play.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(.white, .black.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
      case .link:
        HStack(spacing: 10) {
          Image(systemName: "link")
          Text(embed.title ?? embed.url.host() ?? embed.url.absoluteString)
            .lineLimit(1)
          Spacer()
          Image(systemName: "arrow.up.forward.square")
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    switch embed.kind {
    case .video: embed.title ?? "Play video"
    case .link: embed.title ?? embed.url.host() ?? embed.url.absoluteString
    }
  }
}
