import Foundation

/// Configuration options for Readability parsing
public struct ReadabilityOptions: Sendable {
  /// Maximum number of elements to parse (0 = no limit). Mirrors upstream's DoS
  /// guard: extraction aborts with `ReadabilityError.tooManyElements` before
  /// scoring if the document has more elements than this.
  public var maxElementsToParse: Int

  /// Number of top candidates to consider for article extraction.
  public var topCandidateCount: Int

  /// Minimum character count for valid content.
  public var charThreshold: Int

  /// Preserve CSS classes in output HTML.
  public var keepClasses: Bool

  /// Parse JSON-LD metadata when present.
  public var parsesJSONLD: Bool

  /// Classes to preserve in the output (in addition to defaults).
  public var classesToPreserve: [String]

  /// Regex pattern for allowed video URLs.
  public var allowedVideoRegex: String

  /// Modifier for link density calculation.
  public var linkDensityModifier: Double

  /// Enable debug logging.
  public var isDebugLoggingEnabled: Bool

  /// Creates a new ReadabilityOptions instance with default values.
  public init(
    maxElementsToParse: Int = 0,
    topCandidateCount: Int = 5,
    charThreshold: Int = 500,
    keepClasses: Bool = false,
    parsesJSONLD: Bool = true,
    classesToPreserve: [String] = [],
    allowedVideoRegex: String = "",
    linkDensityModifier: Double = 0.0,
    isDebugLoggingEnabled: Bool = false
  ) {
    self.maxElementsToParse = maxElementsToParse
    self.topCandidateCount = topCandidateCount
    self.charThreshold = charThreshold
    self.keepClasses = keepClasses
    self.parsesJSONLD = parsesJSONLD
    self.classesToPreserve = classesToPreserve
    self.allowedVideoRegex = allowedVideoRegex.isEmpty
      ? Configuration.defaultVideoRegex
      : allowedVideoRegex
    self.linkDensityModifier = linkDensityModifier
    self.isDebugLoggingEnabled = isDebugLoggingEnabled
  }

  /// Default options instance
  public static let `default` = ReadabilityOptions()
}
