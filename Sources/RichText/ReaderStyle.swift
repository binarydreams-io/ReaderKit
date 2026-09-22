// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Native styling values for the reader, replacing the old CSS override string.
/// The block model is style-independent, so changing a `ReaderStyle` is a pure
/// SwiftUI re-render (no re-parse).
public struct ReaderStyle: Sendable, Equatable {
  /// The color of body text.
  public var textColor: Color
  /// The color of captions, status text, and other secondary text.
  public var secondaryTextColor: Color
  /// The color of links.
  public var linkColor: Color
  /// The design of the body font.
  public var fontDesign: Font.Design
  /// The size of body text in points. Headings and spacing scale from this value.
  public var baseFontSize: CGFloat
  /// The space between lines of text, in points.
  public var lineSpacing: CGFloat

  /// Creates a style. Each omitted value uses its default.
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
