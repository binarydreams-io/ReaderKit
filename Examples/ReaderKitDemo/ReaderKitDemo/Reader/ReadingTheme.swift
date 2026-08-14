import SwiftUI

enum ReadingTheme: String, CaseIterable, Identifiable {
  case light
  case sepia
  case gray
  case dark

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .light: "Light"
    case .sepia: "Sepia"
    case .gray: "Gray"
    case .dark: "Dark"
    }
  }

  var isDark: Bool {
    switch self {
    case .light, .sepia: false
    case .gray, .dark: true
    }
  }

  var backgroundColor: Color {
    switch self {
    case .light: Color(hex: 0xFBFAF7)
    case .sepia: Color(hex: 0xF3E8D0)
    case .gray: Color(hex: 0x3A3A3C)
    case .dark: Color(hex: 0x0E0E0D)
    }
  }

  var textColor: Color {
    switch self {
    case .light: Color(hex: 0x1C1B19)
    case .sepia: Color(hex: 0x5B4636)
    case .gray: Color(hex: 0xECECEC)
    case .dark: Color(hex: 0xE8E8E2)
    }
  }

  var secondaryTextColor: Color {
    textColor.opacity(0.6)
  }
}
