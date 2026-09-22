// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation

/// The readable article and the metadata that `Readability.parse()` extracts from a page.
public struct ReadabilityResult: Sendable {
  /// The article title.
  public let title: String
  /// The author or byline text.
  public let byline: String?
  /// The text direction of the document, as the HTML `dir` attribute gives it.
  public let dir: String?
  /// The language of the document, as the HTML `lang` attribute gives it.
  public let lang: String?
  /// The cleaned article HTML.
  public let content: String
  /// The plain text of the article.
  public let textContent: String
  /// A short summary of the article.
  public let excerpt: String?
  /// The number of `Character` values in `textContent`.
  public let textLength: Int
  /// The name of the publication.
  public let siteName: String?
  /// The publication time exactly as the page metadata gives it.
  ///
  /// The format changes from site to site. Use `publishedDate` for a parsed value.
  public let publishedTime: String?

  /// Creates a result from extracted article values.
  ///
  /// The initializer calculates `textLength` from `textContent`.
  public init(
    title: String,
    byline: String? = nil,
    dir: String? = nil,
    lang: String? = nil,
    content: String,
    textContent: String,
    excerpt: String? = nil,
    siteName: String? = nil,
    publishedTime: String? = nil
  ) {
    self.title = title
    self.byline = byline
    self.dir = dir
    self.lang = lang
    self.content = content
    self.textContent = textContent
    self.excerpt = excerpt
    self.textLength = textContent.count
    self.siteName = siteName
    self.publishedTime = publishedTime
  }
}

extension ReadabilityResult {
  /// The publication time parsed as an ISO 8601 date or date-time.
  ///
  /// The value is `nil` when `publishedTime` is absent or uses a different format.
  public var publishedDate: Date? {
    guard let publishedTime = publishedTime?.trimmingCharacters(in: .whitespacesAndNewlines) else {
      return nil
    }
    let styles: [Date.ISO8601FormatStyle] = [
      .iso8601,
      Date.ISO8601FormatStyle(includingFractionalSeconds: true),
      Date.ISO8601FormatStyle().year().month().day()
    ]
    for style in styles {
      if let date = try? style.parse(publishedTime) {
        return date
      }
    }
    return nil
  }

  @available(*, deprecated, renamed: "textLength")
  public var length: Int {
    textLength
  }
}
