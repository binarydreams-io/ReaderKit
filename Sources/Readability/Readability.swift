import Foundation
import SwiftSoup

/// Swift implementation of Mozilla's Readability.js
/// Extracts readable content from web pages
public struct Readability: ~Copyable {
  let doc: Document
  let options: ReadabilityOptions

  /// Initialize with HTML string and optional configuration
  public init(html: String, baseURL: URL? = nil, options: ReadabilityOptions = .default) throws {
    if let baseURL {
      self.doc = try SwiftSoup.parse(html, baseURL.absoluteString)
    } else {
      self.doc = try SwiftSoup.parse(html)
    }
    self.options = options
  }

  /// Parse the document and extract readable content.
  /// Consumes the instance — `Readability` mutates its internal `Document` during extraction
  /// and is not reusable.
  public consuming func parse() throws -> ReadabilityResult {
    try executeParse(inspectionContext: nil)
  }

  /// Parse the document and return the result together with a full extraction trace.
  /// Consumes the instance — see `parse()`.
  public consuming func parseWithInspection() throws -> (result: ReadabilityResult, report: InspectionReport) {
    let ctx = InspectionContext(charThreshold: options.charThreshold)
    let result = try executeParse(inspectionContext: ctx)
    return (result, ctx.buildReport())
  }

  /// Extract readable content and return the cleaned DOM subtree together with
  /// metadata, instead of a serialized HTML string. Consumes the instance — see `parse()`.
  package consuming func extractContent() throws -> ReadableContent {
    let core = try extractCore(inspectionContext: nil)
    return ReadableContent(
      title: core.title,
      byline: core.byline,
      dir: core.dir,
      lang: core.lang,
      siteName: core.metadata.siteName,
      publishedTime: core.metadata.publishedTime,
      content: core.cleaned
    )
  }
}

extension Readability {
  /// Aggregated metadata pulled from `<meta>` tags and JSON-LD scripts before
  /// the document is mutated by `prepDocument()`.
  struct Metadata {
    var title: String?
    var byline: String?
    var excerpt: String?
    var siteName: String?
    var publishedTime: String?
  }

  /// Cleaned article structure handed to the native renderer. `package` by
  /// design — it carries a non-Sendable SwiftSoup `Element`, so it must be
  /// consumed within the same off-main call and never leaks into the public API.
  package struct ReadableContent {
    package var title: String
    package var byline: String?
    package var dir: String?
    package var lang: String?
    package var siteName: String?
    package var publishedTime: String?
    package var content: Element
  }
}
