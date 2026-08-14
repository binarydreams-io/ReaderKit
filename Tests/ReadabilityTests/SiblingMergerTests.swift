@testable import Readability
import SwiftSoup
import Testing

/// Tests for SiblingMerger functionality
@Suite("Sibling Merger Tests")
struct SiblingMergerTests {

  // MARK: - mergeSiblings Tests

  @Test
  func `mergeSiblings includes top candidate`() throws {
    let html = """
    <div id="parent">
        <p id="top">This is the main content with enough text and commas, to be considered the top candidate</p>
        <p id="sibling">Sibling content</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Should include top candidate
    let paragraphs = try article.select("p")
    #expect(paragraphs.count >= 1)
  }

  @Test
  func `mergeSiblings includes siblings with same class`() throws {
    let html = """
    <div id="parent">
        <p class="content" id="top">Main content with enough text and commas, for scoring</p>
        <p class="content" id="sibling">Sibling with same class</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())
    let sibling = try #require(doc.select("#sibling").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    // Sibling has lower score but same class
    scoringManager.initializeNode(sibling)
    scoringManager.addToScore(10, for: sibling)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Should include both due to class name bonus
    let paragraphs = try article.select("p")
    #expect(paragraphs.count >= 2)
  }

  @Test
  func `mergeSiblings includes high scoring siblings`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring purposes</p>
        <p id="sibling">Sibling with high score</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())
    let sibling = try #require(doc.select("#sibling").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    // Sibling has score above threshold (20% of 100 = 20)
    scoringManager.initializeNode(sibling)
    scoringManager.addToScore(30, for: sibling)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Should include both
    let paragraphs = try article.select("p")
    #expect(paragraphs.count >= 2)
  }

  @Test
  func `mergeSiblings excludes low scoring siblings`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring</p>
        <p id="low">Low score sibling</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())
    let low = try #require(doc.select("#low").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    // Low score sibling (below 20% threshold)
    scoringManager.initializeNode(low)
    scoringManager.addToScore(5, for: low)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Should only include top
    let lowParagraphs = try article.select("#low")
    #expect(lowParagraphs.isEmpty())
  }

  // MARK: - P Tag Special Handling Tests

  @Test
  func `mergeSiblings includes long P with low link density`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring</p>
        <p id="long">This is a long paragraph with many words and no links so it should be included in the merged content</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    let longParagraphs = try article.select("#long")
    #expect(!longParagraphs.isEmpty())
  }

  @Test
  func `mergeSiblings includes short P ending with period`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring</p>
        <p id="short">Short sentence.</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    let shortParagraphs = try article.select("#short")
    #expect(!shortParagraphs.isEmpty())
  }

  @Test
  func `mergeSiblings excludes P with high link density`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring</p>
        <p id="linky"><a href="http://example.com">Link text link text link text</a> small text</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Should exclude due to high link density
    let linkyParagraphs = try article.select("#linky")
    #expect(linkyParagraphs.isEmpty())
  }

  // MARK: - DIV Alteration Tests

  @Test
  func `mergeSiblings alters non-exception tags to DIV`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring</p>
        <span id="spanner" class="test">Span content</span>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    // Give span a score to be included
    let span = try #require(doc.select("#spanner").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    scoringManager.initializeNode(span)
    scoringManager.addToScore(30, for: span)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Span should be converted to DIV
    let spans = try article.select("span")
    #expect(spans.isEmpty())

    let divs = try article.select("div.test")
    #expect(!divs.isEmpty())
  }

  @Test
  func `mergeSiblings keeps exception tags unchanged`() throws {
    let html = """
    <div id="parent">
        <article id="top">Main content with enough text and commas, for scoring</article>
        <section id="section">Section content</section>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())
    let section = try #require(doc.select("#section").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    scoringManager.initializeNode(section)
    scoringManager.addToScore(30, for: section)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Section should remain as section (in exception list)
    let sections = try article.select("section")
    #expect(!sections.isEmpty())
  }

  // MARK: - Score Threshold Tests

  @Test
  func `calculateSiblingScoreThreshold uses minimum`() throws {
    let html = "<p id='top'>Test</p>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(5, for: top) // Low score

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let threshold = merger.calculateSiblingScoreThreshold(for: top)

    // Should use minimum of 10
    #expect(threshold == 10)
  }

  @Test
  func `calculateSiblingScoreThreshold uses ratio`() throws {
    let html = "<p id='top'>Test</p>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let threshold = merger.calculateSiblingScoreThreshold(for: top)

    // Should use 20% of 100 = 20
    #expect(threshold == 20)
  }

  // MARK: - Edge Cases

  @Test
  func `mergeSiblings handles no parent`() throws {
    let html = "<p id='top'>Orphan content</p>"
    let doc = try SwiftSoup.parse(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Should still include top candidate
    let paragraphs = try article.select("p")
    #expect(!paragraphs.isEmpty())
  }

  @Test
  func `mergeSiblings preserves attributes when altering`() throws {
    let html = """
    <div id="parent">
        <p id="top">Main content with enough text and commas, for scoring</p>
        <span id="spanner" class="test-class" data-foo="bar">Span</span>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())
    let span = try #require(doc.select("#spanner").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    scoringManager.initializeNode(span)
    scoringManager.addToScore(30, for: span)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    // Attributes should be preserved on converted div
    let divs = try article.select("div.test-class")
    #expect(!divs.isEmpty())

    let div = try #require(divs.first())
    #expect(div.hasAttr("data-foo"))
    #expect(try div.attr("data-foo") == "bar")
  }

  @Test
  func `mergeSiblings extracts leading associated content before generic sibling merge`() throws {
    let html = """
    <div id="parent">
        <div id="lead-wrapper">
            <figure class="wp-block-post-featured-image"><img src="hero.jpg" alt="hero"></figure>
            <p class="meta">metadata that should not be merged</p>
        </div>
        <div class="entry-content" id="top">
            <p>Main content with enough text and commas, for scoring purposes and extraction stability.</p>
        </div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let top = try #require(doc.select("#top").first())

    let scoringManager = NodeScoringManager()
    scoringManager.initializeNode(top)
    scoringManager.addToScore(100, for: top)

    let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
    let article = try merger.mergeSiblings(topCandidate: top, in: doc)

    let extractedFigure = try article.select("figure.wp-block-post-featured-image")
    #expect(extractedFigure.count == 1)

    let metadataParagraph = try article.select("p.meta")
    #expect(metadataParagraph.isEmpty())

    let leadWrapper = try article.select("#lead-wrapper")
    #expect(leadWrapper.isEmpty())
  }
}
