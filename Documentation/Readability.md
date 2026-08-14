# Readability API

The `Readability` product extracts an article and its metadata from an HTML document.
It is a Swift port of the original JavaScript Mozilla Readability implementation.
The target depends on SwiftSoup and does not depend on SwiftUI or Nuke.

## Parse An Article

```swift
import Readability

let extractor = try Readability(
  html: html,
  baseURL: sourceURL,
  options: .default
)
let result = try extractor.parse()
```

`Readability` is `~Copyable` and each instance is single-use.
The consuming parse methods enforce this ownership because extraction mutates the internal DOM.

```swift
public struct Readability: ~Copyable {
  public init(
    html: String,
    baseURL: URL? = nil,
    options: ReadabilityOptions = .default
  ) throws

  public consuming func parse() throws -> ReadabilityResult

  public consuming func parseWithInspection() throws -> (
    result: ReadabilityResult,
    report: InspectionReport
  )
}
```

Pass `baseURL` when the source URL is available.
The parser uses it to resolve relative URLs and select host-gated site rules.

## ReadabilityResult

`ReadabilityResult` is a `Sendable` value.
Its public initializer accepts all fields listed below.

| Property | Type | Meaning |
| --- | --- | --- |
| `title` | `String` | Extracted article title |
| `byline` | `String?` | Author or byline text |
| `dir` | `String?` | Document text direction |
| `lang` | `String?` | Document language |
| `content` | `String` | Cleaned article HTML |
| `textContent` | `String` | Plain article text |
| `excerpt` | `String?` | Extracted summary |
| `length` | `Int` | Character count of `textContent` |
| `siteName` | `String?` | Extracted publication name |
| `publishedTime` | `String?` | Extracted publication time string |

## ReadabilityOptions

Use `ReadabilityOptions.default` for standard behavior.
The public initializer also accepts each option below.

| Property | Default | Meaning |
| --- | --- | --- |
| `maxElementsToParse` | `0` | Maximum element count. Zero disables the limit. |
| `topCandidateCount` | `5` | Number of high-scoring candidates to inspect. |
| `charThreshold` | `500` | Minimum accepted article length before retry passes. |
| `keepClasses` | `false` | Preserves CSS class attributes in output. |
| `parsesJSONLD` | `true` | Enables JSON-LD metadata extraction. |
| `classesToPreserve` | `[]` | Preserves selected classes when other classes are removed. |
| `allowedVideoRegex` | Built-in expression | Keeps embeds from recognized video hosts. |
| `linkDensityModifier` | `0.0` | Adjusts conditional-cleaning link-density thresholds. |
| `isDebugLoggingEnabled` | `false` | Enables parser diagnostics in OSLog. |

Set a finite `maxElementsToParse` when the application accepts untrusted or unbounded HTML.

```swift
let options = ReadabilityOptions(
  maxElementsToParse: 40_000,
  charThreshold: 300,
  classesToPreserve: ["caption"]
)
```

## InspectionReport

`parseWithInspection()` returns the normal result and an `InspectionReport`.
Use the report to debug extraction without changing the parser.

The report contains:

- `passes`: retry attempts and their acceptance decisions.
- Candidate scores and class-weight components.
- Candidate-promotion steps.
- Sibling merge decisions.
- Applied or skipped site-rule decisions.
- Content-shape summaries for extraction passes.
- `finalContentSnapshot`: the selected content before cleanup.
- `cleanupSnapshots`: content summaries after named cleanup stages.

All report values are read-only and `Sendable`.

## Errors

`ReadabilityError` conforms to `Error`, `CustomStringConvertible`, and `Sendable`.

| Case | Meaning |
| --- | --- |
| `.noContent` | The parser did not find readable content. |
| `.contentTooShort(actualLength:threshold:)` | Extracted text did not reach the configured threshold. |
| `.parsingFailed(underlying:)` | An underlying parser operation failed. |
| `.invalidHTML` | The input could not be interpreted as HTML. |
| `.elementNotFound(_:)` | A required DOM element was absent. |
| `.tooManyElements(actual:limit:)` | The document exceeded `maxElementsToParse`. |

## HTML String Helpers

Importing `Readability` adds two public methods to `String`:

```swift
let plainText = try html.htmlText()
let imageURLs = try html.htmlImageURLs()
```

`htmlText()` removes markup and returns normalized text.
`htmlImageURLs()` returns valid image source URLs that exist in the fragment.

## Concurrency

The result, options, errors, and inspection values are `Sendable`.
The parser itself is not `Sendable` because it owns a mutable SwiftSoup DOM.

Parsing is synchronous and can process a large document.
Call it away from the main actor when document size can affect interaction latency.
The extraction pipeline checks task cancellation at major stages.
