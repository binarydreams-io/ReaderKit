import Foundation
@testable import Readability
import Testing

extension Tag {
  @Tag static var slow: Self
  @Tag static var compatibility: Self
}

/// Strict Mozilla Readability compatibility tests
/// These tests replicate Mozilla's official test suite behavior exactly
@Suite("Mozilla Compatibility Tests", .tags(.slow, .compatibility))
struct MozillaCompatibilityTests {

  // MARK: - Test Configuration

  /// Default options matching Mozilla's test setup
  private let defaultOptions = ReadabilityOptions(
    charThreshold: 500,
    classesToPreserve: ["caption"]
  )

  private let testBaseURL = URL(string: "http://fakehost/test/index.html")!

  enum TestCaseField: String, CustomStringConvertible {
    case title, byline, dir, lang, excerpt, siteName, publishedTime
    var description: String {
      rawValue
    }
  }

  struct MetadataCase: CustomStringConvertible {
    let fixture: String
    let field: TestCaseField

    init(_ fixture: String, _ field: TestCaseField) {
      self.fixture = fixture
      self.field = field
    }

    var description: String {
      "\(fixture).\(field)"
    }
  }

  // MARK: - Fixture Manifest

  static let contentCases: [String] = [
    "001", "002",
    // Phase 6.2: Content Post-Processing
    "remove-extra-brs", "remove-extra-paragraphs", "reordering-paragraphs",
    "missing-paragraphs", "ol",
    // Basic / preprocessing
    "basic-tags-cleaning", "remove-script-tags", "replace-brs",
    "replace-font-tags", "remove-aria-hidden", "style-tags-removal", "normalize-spaces",
    // Phase 6.3: Conditional Cleaning
    "clean-links", "links-in-tables", "social-buttons", "article-author-tag",
    "table-style-attributes", "invalid-attributes",
    // Phase 6.4: Hidden Node & Visibility Handling
    "hidden-nodes", "visibility-hidden",
    // Stage 3-F: URL/Base Handling
    "base-url", "base-url-base-element", "base-url-base-element-relative", "js-link-replacement",
    // Stage 3-F: I18N and Entity Handling
    "005-unescape-html-entities", "rtl-1", "rtl-2", "rtl-3", "rtl-4", "mathjax",
    // Stage 3-F: Media and SVG Handling
    "data-url-image", "lazy-image-1", "lazy-image-2", "lazy-image-3",
    "embedded-videos", "videos-1", "videos-2", "svg-parsing",
    // Stage 3-F: Edge Cases
    "comment-inside-script-parsing", "toc-missing", "metadata-content-missing", "bug-1255978"
  ]

  static let metadataCases: [MetadataCase] = [
    // 001
    .init("001", .title), .init("001", .byline), .init("001", .excerpt),
    // 002
    .init("002", .title), .init("002", .byline), .init("002", .siteName), .init("002", .lang),
    // Basic / preprocessing
    .init("basic-tags-cleaning", .title),
    .init("remove-script-tags", .title),
    .init("replace-brs", .title),
    .init("replace-font-tags", .title),
    .init("remove-aria-hidden", .title),
    .init("style-tags-removal", .title),
    .init("normalize-spaces", .title),
    // Phase 3: Metadata Extraction
    .init("parsely-metadata", .title),
    .init("parsely-metadata", .byline),
    .init("parsely-metadata", .publishedTime),
    .init("schema-org-context-object", .title),
    .init("schema-org-context-object", .byline),
    .init("schema-org-context-object", .excerpt),
    .init("schema-org-context-object", .publishedTime),
    .init("schema-org-context-object", .siteName),
    .init("003-metadata-preferred", .title),
    .init("003-metadata-preferred", .byline),
    .init("004-metadata-space-separated-properties", .title),
    // Phase 4: Core Scoring
    .init("title-en-dash", .title),
    .init("title-and-h1-discrepancy", .title),
    .init("keep-images", .title),
    .init("keep-images", .byline),
    .init("keep-images", .publishedTime),
    .init("keep-images", .siteName),
    .init("keep-tabular-data", .title),
    .init("keep-tabular-data", .siteName),
    // Phase 6.3: Conditional Cleaning
    .init("links-in-tables", .dir),
    .init("article-author-tag", .byline),
    .init("article-author-tag", .publishedTime),
    .init("article-author-tag", .siteName),
    // Phase 6.4: Hidden / visibility
    .init("hidden-nodes", .title),
    // Stage 3-F: URL/Base Handling
    .init("base-url", .title),
    .init("base-url-base-element", .title),
    .init("base-url-base-element-relative", .title),
    .init("js-link-replacement", .title),
    // Stage 3-F: I18N and Entity Handling
    .init("005-unescape-html-entities", .title),
    .init("rtl-1", .title), .init("rtl-1", .dir),
    .init("rtl-2", .title), .init("rtl-2", .dir),
    .init("rtl-3", .title), .init("rtl-3", .dir),
    .init("rtl-4", .title),
    .init("mathjax", .title),
    // Stage 3-F: Media and SVG Handling
    .init("data-url-image", .title),
    .init("lazy-image-1", .title),
    .init("lazy-image-1", .byline),
    .init("lazy-image-1", .siteName),
    .init("lazy-image-1", .publishedTime),
    .init("lazy-image-2", .title),
    .init("lazy-image-2", .byline),
    .init("lazy-image-2", .siteName),
    .init("lazy-image-2", .publishedTime),
    .init("lazy-image-3", .title),
    .init("embedded-videos", .title),
    .init("videos-1", .title),
    .init("videos-1", .byline),
    .init("videos-1", .siteName),
    .init("videos-1", .publishedTime),
    .init("videos-2", .title),
    .init("videos-2", .byline),
    .init("videos-2", .siteName),
    .init("videos-2", .publishedTime),
    .init("svg-parsing", .title),
    // Stage 3-F: Edge Cases
    .init("comment-inside-script-parsing", .title),
    .init("toc-missing", .title),
    .init("metadata-content-missing", .title),
    .init("bug-1255978", .title)
  ]

  // MARK: - Helpers

  private func parseResult(for fixture: String) throws -> (testCase: TestLoader.TestCase, result: ReadabilityResult) {
    let testCase = try #require(
      TestLoader.loadTestCase(named: fixture),
      "Failed to load test case '\(fixture)'"
    )
    let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
    let result = try readability.parse()
    return (testCase, result)
  }

  // MARK: - Parameterized Tests

  @Test(arguments: Self.contentCases)
  func `Mozilla content matches`(fixture: String) throws {
    let (testCase, result) = try parseResult(for: fixture)
    let comparison = DOMComparator.compare(result.content, testCase.expectedHTML)
    #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
  }

  @Test(arguments: Self.metadataCases)
  func `Mozilla metadata matches`(testCase: MetadataCase) throws {
    let (fixtureCase, result) = try parseResult(for: testCase.fixture)

    switch testCase.field {
    case .title:
      #expect(result.title == (fixtureCase.expectedMetadata.title ?? ""))
    case .byline:
      #expect(result.byline == fixtureCase.expectedMetadata.byline)
    case .dir:
      #expect(result.dir == fixtureCase.expectedMetadata.dir)
    case .lang:
      #expect(result.lang == fixtureCase.expectedMetadata.lang)
    case .excerpt:
      #expect(result.excerpt == fixtureCase.expectedMetadata.excerpt)
    case .siteName:
      #expect(result.siteName == fixtureCase.expectedMetadata.siteName)
    case .publishedTime:
      #expect(result.publishedTime == fixtureCase.expectedMetadata.publishedTime)
    }
  }
}
