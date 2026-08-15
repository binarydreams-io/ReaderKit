// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import ReaderKit
import SwiftUI

struct ReaderScreen: View {
  let request: ReaderRequest

  @AppStorage("demo.reader.theme") private var theme = ReadingTheme.light
  @AppStorage("demo.reader.font") private var readerFont = ReadingFont.newYork
  @AppStorage("demo.reader.textScale") private var textScale = 1.0
  @State private var showsSettings = false
#if os(iOS)
  @Environment(\.dismiss) private var dismiss
#endif

  var body: some View {
    NavigationStack {
      ScrollView {
        ReaderView(link: request.url, style: readerStyle)
          .frame(maxWidth: 760, alignment: .leading)
          .padding(.horizontal, horizontalPadding)
          .padding(.vertical, 28)
          .frame(maxWidth: .infinity)
      }
      .background(theme.backgroundColor)
      .navigationTitle(request.url.host() ?? "Reader")
      .toolbar { toolbar }
    }
    .tint(.readerGreen)
    .preferredColorScheme(theme.isDark ? .dark : .light)
  }

  private var readerStyle: ReaderStyle {
    ReaderStyle(
      textColor: theme.textColor,
      secondaryTextColor: theme.secondaryTextColor,
      linkColor: .readerGreen,
      fontDesign: readerFont.design,
      baseFontSize: 18 * textScale,
      lineSpacing: 9 * textScale
    )
  }

  private var horizontalPadding: CGFloat {
#if os(iOS)
    20
#else
    32
#endif
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
#if os(iOS)
    ToolbarItem(placement: .cancellationAction) {
      Button("Close", systemImage: "xmark") {
        dismiss()
      }
    }
#endif

    ToolbarItemGroup(placement: .primaryAction) {
      Button("Reading Settings", systemImage: "textformat.size") {
        showsSettings.toggle()
      }
      .popover(isPresented: $showsSettings, arrowEdge: .bottom) {
        ReaderSettingsView(
          theme: $theme,
          readerFont: $readerFont,
          textScale: $textScale
        )
        .presentationCompactAdaptation(.popover)
      }

      ShareLink(item: request.url)
    }
  }
}
