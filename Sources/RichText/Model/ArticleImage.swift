// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation

/// An image in an article.
public struct ArticleImage: Sendable, Equatable {
  /// The absolute URL of the image file.
  public let url: URL
  /// The alternative text of the image, from the HTML `alt` attribute.
  public let altText: String?
  /// The text of the `<figcaption>` in the image's `<figure>`, if there is one.
  public let caption: String?

  /// Creates an image with an optional alternative text and caption.
  public init(url: URL, altText: String? = nil, caption: String? = nil) {
    self.url = url
    self.altText = altText
    self.caption = caption
  }
}

extension ArticleImage {
  @available(*, deprecated, renamed: "init(url:altText:caption:)")
  public init(url: URL, alt: String?, caption: String? = nil) {
    self.init(url: url, altText: alt, caption: caption)
  }

  @available(*, deprecated, renamed: "altText")
  public var alt: String? {
    altText
  }
}
