// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

enum ReadingFont: String, CaseIterable, Identifiable {
  case newYork
  case sfPro

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .newYork: "New York"
    case .sfPro: "SF Pro"
    }
  }

  var design: Font.Design {
    switch self {
    case .newYork: .serif
    case .sfPro: .default
    }
  }
}
