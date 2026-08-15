// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Native styling values for the reader, replacing the old CSS override string.
/// The block model is style-independent, so changing a `ReaderStyle` is a pure
/// SwiftUI re-render (no re-parse).
public struct ReaderStyle: Sendable, Equatable {
  public var textColor: Color
  public var secondaryTextColor: Color
  public var linkColor: Color
  public var fontDesign: Font.Design
  public var baseFontSize: CGFloat
  public var lineSpacing: CGFloat

  public init(
    textColor: Color = .primary,
    secondaryTextColor: Color = .secondary,
    linkColor: Color = .accentColor,
    fontDesign: Font.Design = .serif,
    baseFontSize: CGFloat = 18,
    lineSpacing: CGFloat = 9
  ) {
    self.textColor = textColor
    self.secondaryTextColor = secondaryTextColor
    self.linkColor = linkColor
    self.fontDesign = fontDesign
    self.baseFontSize = baseFontSize
    self.lineSpacing = lineSpacing
  }
}
