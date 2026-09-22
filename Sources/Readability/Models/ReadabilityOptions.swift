// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation

/// Configuration options for Readability parsing.
public struct ReadabilityOptions: Sendable {
  /// Maximum number of elements to parse (0 = no limit). Mirrors upstream's DoS
  /// guard: extraction aborts with `ReadabilityError.tooManyElements` before
  /// scoring if the document has more elements than this.
  public var maxElementsToParse: Int

  /// Number of top candidates to consider for article extraction.
  public var topCandidateCount: Int

  /// Minimum character count for valid content.
  public var minimumCharacterCount: Int

  /// Whether the output HTML keeps its CSS classes.
  public var preservesClasses: Bool

  /// Parse JSON-LD metadata when present.
  public var parsesJSONLD: Bool

  /// Classes to preserve in the output (in addition to defaults).
  public var classesToPreserve: [String]

  /// A regular expression that matches the URLs of allowed video embeds.
  ///
  /// An empty string selects the built-in pattern.
  public var allowedVideoURLPattern: String

  /// Modifier for link density calculation.
  public var linkDensityModifier: Double

  /// Enable debug logging.
  public var isDebugLoggingEnabled: Bool

  /// Creates options with the given values. Each omitted value uses its default.
  public init(
    maxElementsToParse: Int = 0,
    topCandidateCount: Int = 5,
    minimumCharacterCount: Int = 500,
    preservesClasses: Bool = false,
    parsesJSONLD: Bool = true,
    classesToPreserve: [String] = [],
    allowedVideoURLPattern: String = "",
    linkDensityModifier: Double = 0.0,
    isDebugLoggingEnabled: Bool = false
  ) {
    self.maxElementsToParse = maxElementsToParse
    self.topCandidateCount = topCandidateCount
    self.minimumCharacterCount = minimumCharacterCount
    self.preservesClasses = preservesClasses
    self.parsesJSONLD = parsesJSONLD
    self.classesToPreserve = classesToPreserve
    self.allowedVideoURLPattern = allowedVideoURLPattern.isEmpty
      ? Configuration.defaultVideoRegex
      : allowedVideoURLPattern
    self.linkDensityModifier = linkDensityModifier
    self.isDebugLoggingEnabled = isDebugLoggingEnabled
  }

  /// The options with all default values.
  public static let `default` = ReadabilityOptions()
}

extension ReadabilityOptions {
  @_disfavoredOverload
  @available(
    *,
    deprecated,
    renamed: "init(maxElementsToParse:topCandidateCount:minimumCharacterCount:preservesClasses:parsesJSONLD:classesToPreserve:allowedVideoURLPattern:linkDensityModifier:isDebugLoggingEnabled:)"
  )
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
    self.init(
      maxElementsToParse: maxElementsToParse,
      topCandidateCount: topCandidateCount,
      minimumCharacterCount: charThreshold,
      preservesClasses: keepClasses,
      parsesJSONLD: parsesJSONLD,
      classesToPreserve: classesToPreserve,
      allowedVideoURLPattern: allowedVideoRegex,
      linkDensityModifier: linkDensityModifier,
      isDebugLoggingEnabled: isDebugLoggingEnabled
    )
  }

  @available(*, deprecated, renamed: "minimumCharacterCount")
  public var charThreshold: Int {
    get { minimumCharacterCount }
    set { minimumCharacterCount = newValue }
  }

  @available(*, deprecated, renamed: "preservesClasses")
  public var keepClasses: Bool {
    get { preservesClasses }
    set { preservesClasses = newValue }
  }

  @available(*, deprecated, renamed: "allowedVideoURLPattern")
  public var allowedVideoRegex: String {
    get { allowedVideoURLPattern }
    set { allowedVideoURLPattern = newValue }
  }
}
