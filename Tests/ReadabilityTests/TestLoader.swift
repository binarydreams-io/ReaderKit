// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation

/// Utility for loading Mozilla test cases
enum TestLoader {
  private struct CaseMetadata: Decodable {
    let url: String
  }

  private static let expectedHTMLModificationNotices = [
    "<!-- ReaderKit notice: Neo Lee's swift-readability commit 9f11fbea21c8c1f930b76964da8fa919faa17d08 removed <br id=\"br2\" /> from this Mozilla fixture. ReaderKit preserves that change. -->",
    "<!-- ReaderKit notice: Neo Lee's swift-readability commit 9f11fbea21c8c1f930b76964da8fa919faa17d08 removed <hr /> from this Mozilla fixture. ReaderKit preserves that change. -->"
  ]

  struct TestCase {
    let name: String
    let sourceHTML: String
    let expectedHTML: String
    let expectedMetadata: TestMetadata
    let sourceURL: URL?
  }

  struct TestMetadata: Codable {
    let title: String?
    let byline: String?
    let dir: String?
    let lang: String?
    let excerpt: String?
    let siteName: String?
    let publishedTime: String?
    let readerable: Bool?

    enum CodingKeys: String, CodingKey {
      case title
      case byline
      case dir
      case lang
      case excerpt
      case siteName
      case publishedTime
      case readerable
    }
  }

  /// Get the resources directory for a specific test group.
  private static func resourcesDirectory(for group: String) -> URL? {
    // Try to find resources relative to the test executable
    let fileManager = FileManager.default

    // Get the directory of this source file
    let thisFile = #file
    let thisDir = URL(fileURLWithPath: thisFile).deletingLastPathComponent()

    // Navigate to the selected Resources subdirectory.
    let resourcesURL = thisDir
      .appendingPathComponent("Resources")
      .appendingPathComponent(group)

    if fileManager.fileExists(atPath: resourcesURL.path) {
      return resourcesURL
    }

    // Fallback: try to find in current working directory
    let cwd = fileManager.currentDirectoryPath
    let cwdResources = URL(fileURLWithPath: cwd)
      .appendingPathComponent("Tests")
      .appendingPathComponent("ReadabilityTests")
      .appendingPathComponent("Resources")
      .appendingPathComponent(group)

    if fileManager.fileExists(atPath: cwdResources.path) {
      return cwdResources
    }

    return nil
  }

  /// Load all available test cases
  static func loadAllTestCases() -> [TestCase] {
    let testNames = [
      "001",
      "basic-tags-cleaning",
      "remove-script-tags",
      "replace-brs",
      "replace-font-tags",
      "remove-aria-hidden",
      "style-tags-removal",
      "normalize-spaces",
      // Phase 3: Metadata extraction
      "003-metadata-preferred",
      "004-metadata-space-separated-properties",
      "parsely-metadata",
      "schema-org-context-object",
      // Phase 4: Core scoring
      "title-en-dash",
      "title-and-h1-discrepancy",
      "keep-images",
      "keep-tabular-data",
      // Phase 6.3: Conditional Cleaning
      "clean-links",
      "links-in-tables",
      "social-buttons",
      "article-author-tag",
      "table-style-attributes",
      "invalid-attributes",
      // Phase 6.4: Hidden Node & Visibility Handling
      "hidden-nodes",
      "visibility-hidden"
    ]
    return testNames.compactMap { loadTestCase(named: $0) }
  }

  /// Load a specific test case
  static func loadTestCase(named name: String, in group: String = "test-pages") -> TestCase? {
    guard let resourcesURL = resourcesDirectory(for: group) else {
      print("Failed to locate resources directory for group '\(group)'")
      return nil
    }

    let testPageURL = resourcesURL.appendingPathComponent(name)

    guard FileManager.default.fileExists(atPath: testPageURL.path) else {
      print("Test case directory not found: \(testPageURL.path)")
      return nil
    }

    do {
      let sourceURL = testPageURL.appendingPathComponent("source.html")
      let expectedURL = testPageURL.appendingPathComponent("expected.html")
      let metadataURL = testPageURL.appendingPathComponent("expected-metadata.json")

      let sourceHTML = try String(contentsOf: sourceURL, encoding: .utf8)
      let expectedHTML = removingExpectedHTMLModificationNotice(
        from: try String(contentsOf: expectedURL, encoding: .utf8)
      )
      let metadataData = try Data(contentsOf: metadataURL)
      let metadata = try JSONDecoder().decode(TestMetadata.self, from: metadataData)
      let caseMetaURL = testPageURL.appendingPathComponent("meta.json")
      let sourcePageURL: URL? = if FileManager.default.fileExists(atPath: caseMetaURL.path),
                                   let caseMetaData = try? Data(contentsOf: caseMetaURL),
                                   let caseMetadata = try? JSONDecoder().decode(CaseMetadata.self, from: caseMetaData)
      {
        URL(string: caseMetadata.url.trimmingCharacters(in: .whitespacesAndNewlines))
      } else {
        nil
      }

      return TestCase(
        name: name,
        sourceHTML: sourceHTML,
        expectedHTML: expectedHTML,
        expectedMetadata: metadata,
        sourceURL: sourcePageURL
      )
    } catch {
      print("Failed to load test case '\(name)': \(error)")
      return nil
    }
  }

  private static func removingExpectedHTMLModificationNotice(from html: String) -> String {
    for notice in expectedHTMLModificationNotices {
      let sentinel = notice + "\n"
      if html.hasPrefix(sentinel) {
        return String(html.dropFirst(sentinel.count))
      }
    }
    return html
  }
}
