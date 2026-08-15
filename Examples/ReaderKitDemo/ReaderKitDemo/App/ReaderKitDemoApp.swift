// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

@main
@MainActor
struct ReaderKitDemoApp: App {
  var body: some Scene {
#if os(macOS)
    WindowGroup {
      HomeView()
    }
    .defaultSize(width: 680, height: 440)

    WindowGroup("Reader", id: "reader", for: ReaderRequest.self) { $request in
      if let request {
        ReaderScreen(request: request)
      } else {
        ContentUnavailableView("Article not found", systemImage: "doc.questionmark")
      }
    }
    .defaultSize(width: 860, height: 720)
#else
    WindowGroup {
      HomeView()
    }
#endif
  }
}
