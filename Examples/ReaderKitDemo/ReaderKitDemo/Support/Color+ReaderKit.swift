// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
  static let readerGreen = Color(red: 35 / 255, green: 139 / 255, blue: 69 / 255)
  static let readerCanvas = Color(
    light: Color(red: 238 / 255, green: 244 / 255, blue: 239 / 255),
    dark: Color(red: 9 / 255, green: 18 / 255, blue: 12 / 255)
  )

  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }

  private init(light: Color, dark: Color) {
#if os(macOS)
    self.init(nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(dark)
        : NSColor(light)
    })
#else
    self.init(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
#endif
  }
}
