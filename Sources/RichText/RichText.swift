// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftSoup

/// Converts Readability's cleaned article DOM into a native `[ArticleBlock]`.
///
/// Organized like `Readability`: a small main type plus focused extensions
/// (`RichText+Blocks`, `RichText+Inline`, `RichText+Embed`). Prefer the
/// `init(content:baseURL:)` path fed by `Readability.extractContent()` so the
/// HTML is parsed once; `init(html:baseURL:)` exists for standalone use and tests.
public struct RichText {
  let root: Element
  let baseURL: URL?

  /// Creates a converter that parses `html` once for block extraction.
  ///
  /// - Parameters:
  ///   - html: The HTML to convert.
  ///   - baseURL: The URL that resolves relative image and link URLs.
  /// - Throws: A SwiftSoup parsing error if the HTML cannot be parsed.
  public init(html: String, baseURL: URL? = nil) throws {
    if let baseURL {
      self.root = try SwiftSoup.parse(html, baseURL.absoluteString).body() ?? SwiftSoup.parse(html)
    } else {
      self.root = try SwiftSoup.parse(html).body() ?? SwiftSoup.parse(html)
    }
    self.baseURL = baseURL
  }

  /// Use an already-cleaned Readability content element (no re-parse).
  package init(content: Element, baseURL: URL?) {
    self.root = content
    self.baseURL = baseURL
  }

  /// The element whose children are the article's block-level content.
  /// Readability wraps content in `#readability-page-1`; descend into it when present.
  var contentRoot: Element {
    (try? root.select("#readability-page-1").first()) ?? root
  }

  /// Returns the block-level content of the article.
  ///
  /// - Throws: `CancellationError` if the current task is cancelled,
  ///   or a SwiftSoup error if a DOM query fails.
  public func blocks() throws -> [ArticleBlock] {
    try Task.checkCancellation()
    return try parseBlocks(in: contentRoot)
  }
}
