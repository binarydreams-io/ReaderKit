// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation

/// Embedded media in an article. The reader shows it as a card that opens `url`.
public struct ArticleEmbed: Sendable, Equatable {
  /// The type of embedded media.
  public enum Kind: Sendable, Equatable {
    /// A video with an optional poster image.
    case video(posterURL: URL?)
    /// A link to external content.
    case link
  }

  /// The URL that the card opens.
  public let url: URL
  /// The type of embedded media.
  public let kind: Kind
  /// The title that the card shows, if there is one.
  public let title: String?

  /// Creates an embed with an optional title.
  public init(url: URL, kind: Kind, title: String? = nil) {
    self.url = url
    self.kind = kind
    self.title = title
  }
}
