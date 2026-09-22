// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation

/// Errors that Readability parsing can throw.
public enum ReadabilityError: Error, CustomStringConvertible, Sendable {
  /// Could not find article content in the document
  case noContent

  /// Extracted content is below the minimum character count
  case contentTooShort(length: Int, minimumLength: Int)

  /// HTML parsing failed
  case parsingFailed(underlying: Error)

  /// Invalid HTML input
  case invalidHTML

  /// A required element was not found
  case elementNotFound(selector: String)

  /// The document exceeds `ReadabilityOptions.maxElementsToParse` and was
  /// aborted before scoring, mirroring upstream's DoS guard.
  case tooManyElements(count: Int, limit: Int)

  public var description: String {
    switch self {
    case .noContent:
      "Could not find article content in the document"
    case let .contentTooShort(length, minimumLength):
      "Extracted content is too short (\(length) characters, minimum \(minimumLength))"
    case let .parsingFailed(error):
      "HTML parsing failed: \(error.localizedDescription)"
    case .invalidHTML:
      "Invalid HTML input"
    case let .elementNotFound(selector):
      "Required element not found: \(selector)"
    case let .tooManyElements(count, limit):
      "Aborting parsing document: \(count) elements found, exceeding limit of \(limit)"
    }
  }
}

extension ReadabilityError {
  @available(*, deprecated, renamed: "contentTooShort(length:minimumLength:)")
  public static func contentTooShort(actualLength: Int, threshold: Int) -> Self {
    .contentTooShort(length: actualLength, minimumLength: threshold)
  }

  @available(*, deprecated, renamed: "elementNotFound(selector:)")
  public static func elementNotFound(_ selector: String) -> Self {
    .elementNotFound(selector: selector)
  }

  @available(*, deprecated, renamed: "tooManyElements(count:limit:)")
  public static func tooManyElements(actual: Int, limit: Int) -> Self {
    .tooManyElements(count: actual, limit: limit)
  }
}
