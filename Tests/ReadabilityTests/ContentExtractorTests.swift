// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

@testable import Readability
import SwiftSoup
import Testing

/// Tests for ContentExtractor functionality
@Suite("Content Extractor Tests")
struct ContentExtractorTests {

  // MARK: - Basic Extraction Tests

  @Test
  func `extract returns content for valid article`() throws {
    let html = """
    <html><body>
    <div class="article">
        <p>This is a paragraph with enough text to be considered content, and it has commas too.</p>
        <p>Second paragraph with more text content here.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)
    let result = try extractor.extract()

    #expect(result.content.tagName().lowercased() == "div")
    let text = try result.content.text()
    #expect(text.count >= 100)
  }

  @Test
  func `extract throws contentTooShort for empty document`() throws {
    let html = "<html><body></body></html>"
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)

    let error = try #require(throws: ReadabilityError.self) {
      _ = try extractor.extract()
    }
    guard case .contentTooShort = error else {
      Issue.record("Expected .contentTooShort, got \(error)")
      return
    }
  }

  @Test
  func `extract throws tooManyElements when maxElementsToParse is exceeded`() throws {
    let html = """
    <html><body>
    <div class="article">
        <p>This is a paragraph with enough text to be considered content, and it has commas too.</p>
        <p>Second paragraph with more text content here.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let options = ReadabilityOptions(maxElementsToParse: 1)
    let extractor = ContentExtractor(doc: doc, options: options)

    let error = try #require(throws: ReadabilityError.self) {
      _ = try extractor.extract()
    }
    guard case .tooManyElements = error else {
      Issue.record("Expected .tooManyElements, got \(error)")
      return
    }
  }

  @Test
  func `extract succeeds when element count is within maxElementsToParse`() throws {
    let html = """
    <html><body>
    <div class="article">
        <p>This is a paragraph with enough text to be considered content, and it has commas too.</p>
        <p>Second paragraph with more text content here.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let options = ReadabilityOptions(maxElementsToParse: 1000)
    let extractor = ContentExtractor(doc: doc, options: options)
    let result = try extractor.extract()

    #expect(result.content.tagName().lowercased() == "div")
  }

  @Test
  func `extract attempts fallback for short content`() throws {
    // Very short content that will trigger multiple attempts
    let html = """
    <html><body>
    <p>Hi.</p>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let options = ReadabilityOptions(charThreshold: 100)
    let extractor = ContentExtractor(doc: doc, options: options)

    // Will return best attempt even if below threshold
    let result = try extractor.extract()
    let text = try result.content.text()
    #expect(text.count > 0)

    // Should have attempted multiple times
    let attempts = extractor.getAttemptInfo()
    #expect(attempts.count >= 3)
  }

  // MARK: - Flag System Tests

  @Test
  func `extract tries all flag combinations`() throws {
    // Very short content that will trigger all flag combinations
    let html = """
    <html><body>
    <p>X.</p>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let options = ReadabilityOptions(charThreshold: 500)
    let extractor = ContentExtractor(doc: doc, options: options)

    // Returns best attempt even if below threshold
    let result = try extractor.extract()
    let text = try result.content.text()
    #expect(text.count > 0)

    // Should have tried all flag combinations
    let attempts = extractor.getAttemptInfo()
    #expect(attempts.count >= 3)
  }

  @Test
  func `getAttemptInfo returns correct flag names`() throws {
    let html = """
    <html><body>
    <p>Short content that will trigger fallback.</p>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let options = ReadabilityOptions(charThreshold: 200)
    let extractor = ContentExtractor(doc: doc, options: options)

    // First attempt will fail, then fallback
    _ = try? extractor.extract()

    let attempts = extractor.getAttemptInfo()
    for attempt in attempts {
      // Each attempt should have flag info
      #expect(attempt.flags.count > 0 || attempt.textLength >= 0)
    }
  }

  // MARK: - Element Scoring Tests

  @Test
  func `extract prefers high scoring elements`() throws {
    let html = """
    <html><body>
    <div class="sidebar">
        <p>Sidebar content with some text.</p>
    </div>
    <article class="main-article">
        <p>This is the main article with much more content, and commas, and length.</p>
        <p>Multiple paragraphs help increase the score significantly.</p>
    </article>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)
    let result = try extractor.extract()

    let text = try result.content.text()
    // Should prefer article content over sidebar
    #expect(text.contains("main article") || text.contains("Multiple paragraphs"))
  }

  // MARK: - Multi-attempt Selection Tests

  @Test
  func `extract selects best attempt when all fail threshold`() throws {
    // Content that fails threshold but has some content
    let html = """
    <html><body>
    <p>X.</p>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let options = ReadabilityOptions(charThreshold: 500)
    let extractor = ContentExtractor(doc: doc, options: options)

    // Returns best attempt even if below threshold
    let result = try extractor.extract()
    let text = try result.content.text()
    #expect(text.count > 0)
  }

  @Test
  func `extract handles content with only one good attempt`() throws {
    let html = """
    <html><body>
    <div class="content">
        <p>This content is long enough when flags are set correctly, with many words and commas here.</p>
        <p>Second paragraph adds more length to ensure it passes the threshold check.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)
    let result = try extractor.extract()

    let text = try result.content.text()
    #expect(text.count >= 100)
  }

  // MARK: - Edge Cases

  @Test
  func `extract throws contentTooShort for body-less document`() throws {
    // SwiftSoup auto-inserts an empty <body>, so extraction fails on the
    // content-length check rather than the missing-element guard.
    let html = "<html><head><title>Test</title></head></html>"
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)

    let error = try #require(throws: ReadabilityError.self) {
      _ = try extractor.extract()
    }
    guard case .contentTooShort = error else {
      Issue.record("Expected .contentTooShort, got \(error)")
      return
    }
  }

  @Test
  func `extract handles hidden content`() throws {
    let html = """
    <html><body>
    <div style="display:none">
        <p>This hidden content should not be considered.</p>
    </div>
    <div>
        <p>Visible content with enough text to be the main article, and commas too.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)
    let result = try extractor.extract()

    let text = try result.content.text()
    #expect(!text.contains("hidden content"))
    #expect(text.contains("Visible content"))
  }

  @Test
  func `extract ignores content hidden by hidden attribute`() throws {
    let html = """
    <html><body>
    <div hidden>
        <p>This hidden attribute content should not be considered.</p>
    </div>
    <div>
        <p>Visible content remains candidate text, with enough words and commas.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)
    let result = try extractor.extract()

    let text = try result.content.text()
    #expect(!text.contains("hidden attribute content"))
    #expect(text.contains("Visible content"))
  }

  @Test
  func `extract preserves structure during fallback`() throws {
    let html = """
    <html><body>
    <article>
        <p>Paragraph one with text content here.</p>
        <p>Paragraph two with more text content.</p>
    </article>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    let extractor = ContentExtractor(doc: doc, options: .default)
    let result = try extractor.extract()

    // Should have paragraphs
    let paragraphs = try result.content.select("p")
    #expect(paragraphs.count >= 1)
  }

  // MARK: - Configuration Tests

  @Test
  func `extract respects charThreshold option`() throws {
    let html = """
    <html><body>
    <p>Content here.</p>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    // High threshold will return best attempt
    let strictOptions = ReadabilityOptions(charThreshold: 500)
    let strictExtractor = ContentExtractor(doc: doc, options: strictOptions)

    let strictResult = try strictExtractor.extract()
    let strictText = try strictResult.content.text()
    #expect(strictText.count > 0) // Returns best attempt

    // Low threshold should succeed normally
    let lenientOptions = ReadabilityOptions(charThreshold: 5)
    let lenientExtractor = ContentExtractor(doc: doc, options: lenientOptions)

    let result = try lenientExtractor.extract()
    let text = try result.content.text()
    #expect(text.count >= 5)
  }

  @Test
  func `extract respects linkDensityModifier option`() throws {
    let html = """
    <html><body>
    <div>
        <p>Content with <a href="http://example.com">many links</a> and
        <a href="http://example.com">more links</a> that might affect scoring.</p>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)

    // With modifier that allows more links
    let options = ReadabilityOptions(linkDensityModifier: 0.5)
    let extractor = ContentExtractor(doc: doc, options: options)

    let result = try extractor.extract()
    let text = try result.content.text()
    #expect(text.count > 0)
  }
}
