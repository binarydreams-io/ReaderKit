import Foundation

/// Errors that can occur during Readability parsing
public enum ReadabilityError: Error, CustomStringConvertible, Sendable {
  /// Could not find article content in the document
  case noContent

  /// Extracted content is below the minimum character threshold
  case contentTooShort(actualLength: Int, threshold: Int)

  /// HTML parsing failed
  case parsingFailed(underlying: Error)

  /// Invalid HTML input
  case invalidHTML

  /// A required element was not found
  case elementNotFound(String)

  /// The document exceeds `ReadabilityOptions.maxElementsToParse` and was
  /// aborted before scoring, mirroring upstream's DoS guard.
  case tooManyElements(actual: Int, limit: Int)

  public var description: String {
    switch self {
    case .noContent:
      "Could not find article content in the document"
    case let .contentTooShort(actual, threshold):
      "Extracted content is too short (\(actual) characters, minimum \(threshold))"
    case let .parsingFailed(error):
      "HTML parsing failed: \(error.localizedDescription)"
    case .invalidHTML:
      "Invalid HTML input"
    case let .elementNotFound(selector):
      "Required element not found: \(selector)"
    case let .tooManyElements(actual, limit):
      "Aborting parsing document: \(actual) elements found, exceeding limit of \(limit)"
    }
  }
}
