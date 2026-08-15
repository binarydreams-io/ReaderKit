// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
@testable import Readability
import SwiftSoup
import Testing

/// Tests for CandidateSelector functionality
/// These tests verify Top N candidate selection logic
@Suite("Candidate Selector Tests")
struct CandidateSelectorTests {

  // MARK: - selectTopCandidate Tests

  @Test
  func `selectTopCandidate selects highest scored element`() throws {
    let html = """
    <div>
        <p id="low">Short text</p>
        <article id="high">This is a much longer article with more content and commas, and more words here</article>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let elements = try doc.body()?.select("p, article").array() ?? []

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(topCandidateCount: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Score elements
    for element in elements {
      _ = try scoringManager.scoreElement(element, options: options)
    }

    let (candidate, neededToCreate) = try selector.selectTopCandidate(from: elements, in: doc)

    #expect(candidate.id() == "high")
    #expect(neededToCreate == false)
  }

  @Test
  func `selectTopCandidate creates fallback when no good candidates`() throws {
    let html = "<body><p>Short</p></body>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let body = try #require(doc.body())

    // Only short elements that won't score
    let elements = try body.select("p").array()

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(topCandidateCount: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Score elements (they'll all return 0 due to short text)
    for element in elements {
      _ = try scoringManager.scoreElement(element, options: options)
    }

    let (candidate, neededToCreate) = try selector.selectTopCandidate(from: elements, in: doc)

    #expect(neededToCreate == true)
    #expect(candidate.tagName().lowercased() == "div")
  }

  @Test
  func `selectTopCandidate handles body as candidate`() throws {
    let html = "<body><div>This is long enough content with commas, and words to be scored properly</div></body>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let body = try #require(doc.body())

    let elements = [body]

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(topCandidateCount: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Initialize and score body
    scoringManager.initializeNode(body)
    scoringManager.addToScore(100, for: body)

    let (_, neededToCreate) = try selector.selectTopCandidate(from: elements, in: doc)

    // Should create fallback since BODY isn't a good candidate
    #expect(neededToCreate == true)
  }

  @Test
  func `selectTopCandidate uses improved top candidate for promotion`() throws {
    let html = """
    <html><body>
    <div id="common">
        <section id="sec1"><p>Content one with enough text, and commas, and words</p></section>
        <section id="sec2"><p>Content two with enough text, and commas, and words</p></section>
        <section id="sec3"><p>Content three with enough text, and commas, and words</p></section>
        <section id="sec4"><p>Content four with enough text, and commas, and words</p></section>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)
    let body = try #require(doc.body())
    let sections = try body.select("section").array()
    #expect(sections.count == 4)

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(topCandidateCount: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    for (index, section) in sections.enumerated() {
      scoringManager.initializeNode(section)
      scoringManager.addToScore(Double(100 - index * 5), for: section) // 100, 95, 90, 85
    }

    let (candidate, neededToCreate) = try selector.selectTopCandidate(from: sections, in: doc)

    #expect(neededToCreate == false)
    #expect(candidate.id() == "common")
  }

  @Test
  func `selectTopCandidate promotes CityLab article container via site rule`() throws {
    let html = """
    <html>
    <head>
        <meta property="og:site_name" content="CityLab">
        <link rel="canonical" href="https://www.citylab.com/article/example">
    </head>
    <body>
        <article id="story" itemtype="https://schema.org/NewsArticle">
            <section id="article-section-1">This is a CityLab article section with enough text, commas, and words to be chosen as the best candidate.</section>
        </article>
    </body>
    </html>
    """
    let doc = try SwiftSoup.parse(html)
    let section = try #require(doc.select("section#article-section-1").first())
    let article = try #require(doc.select("article#story").first())

    let scoringManager = NodeScoringManager()
    let selector = CandidateSelector(options: .default, scoringManager: scoringManager)
    scoringManager.initializeNode(section)
    scoringManager.addToScore(100, for: section)

    let (candidate, neededToCreate) = try selector.selectTopCandidate(from: [section], in: doc)

    #expect(neededToCreate == false)
    #expect(candidate === article)
  }

  // MARK: - Alternative Ancestor Analysis Tests

  @Test
  func `findBetterTopCandidate finds common ancestor`() throws {
    // Use parse instead of parseBodyFragment to have more control
    // Need at least 4 sections: 1 best + 3 alternatives (MINIMUM_TOPCANDIDATES = 3)
    let html = """
    <html><body>
    <div id="common">
        <section id="sec1"><p>Content one with enough text, and commas, and words</p></section>
        <section id="sec2"><p>Content two with enough text, and commas, and words</p></section>
        <section id="sec3"><p>Content three with enough text, and commas, and words</p></section>
        <section id="sec4"><p>Content four with enough text, and commas, and words</p></section>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)
    let body = try #require(doc.body())

    let sections = try body.select("section").array()
    #expect(sections.count == 4)

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(topCandidateCount: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Score sections with high scores (all above 75% of best)
    for (index, section) in sections.enumerated() {
      scoringManager.initializeNode(section)
      scoringManager.addToScore(Double(100 - index * 5), for: section) // 100, 95, 90, 85
    }

    let topCandidates = TopCandidates(maxCount: 5)
    for section in sections {
      topCandidates.add(Candidate(element: section, score: scoringManager.getContentScore(for: section)))
    }

    // Verify we have 4 candidates with scores above threshold
    #expect(topCandidates.count == 4)

    let first = sections[0]
    let better = try selector.findBetterTopCandidate(from: first, topCandidates: topCandidates)

    // Should find the common ancestor div (sec1 -> div#common)
    // div#common should be in the ancestor lists of sec2, sec3, and sec4
    #expect(better.id() == "common")
  }

  @Test
  func `findBetterTopCandidate keeps original when no common ancestor`() throws {
    let html = """
    <div>
        <section id="sec1"><p>Content one with enough text, and commas</p></section>
    </div>
    <div>
        <section id="sec2"><p>Content two with enough text, and commas</p></section>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let body = try #require(doc.body())

    let sections = try body.select("section").array()

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(topCandidateCount: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Score sections
    for section in sections {
      scoringManager.initializeNode(section)
      scoringManager.addToScore(100, for: section)
    }

    let topCandidates = TopCandidates(maxCount: 5)
    for section in sections {
      topCandidates.add(Candidate(element: section, score: scoringManager.getContentScore(for: section)))
    }

    let first = sections[0]
    let better = try selector.findBetterTopCandidate(from: first, topCandidates: topCandidates)

    // Should keep original since no common ancestor found with 3+ candidates
    #expect(better.id() == "sec1")
  }

  // MARK: - Single Child Promotion Tests

  @Test
  func `promoteSingleChildCandidate promotes single children`() throws {
    let html = """
    <div id="grandparent">
        <div id="parent">
            <div id="child">Content here with enough text for scoring purposes</div>
        </div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let child = try #require(doc.select("#child").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    scoringManager.initializeNode(child)

    let promoted = try selector.promoteSingleChildCandidate(child)

    // Should promote to grandparent since all are single children
    #expect(promoted.id() == "grandparent")
  }

  @Test
  func `promoteSingleChildCandidate stops at body`() throws {
    let html = "<div id='parent'><div id='child'>Content with enough text for scoring</div></div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let child = try #require(doc.select("#child").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    scoringManager.initializeNode(child)

    let promoted = try selector.promoteSingleChildCandidate(child)

    // Should stop at body level
    #expect(promoted.id() == "parent")
  }

  @Test
  func `promoteSingleChildCandidate keeps NYTimes story article in core`() throws {
    let html = """
    <html><body>
    <div id="site-content">
        <article id="story">Content with enough text, commas, and words for scoring purposes in the protected article.</article>
    </div>
    </body></html>
    """
    let doc = try SwiftSoup.parse(html)
    let article = try #require(doc.select("article#story").first())

    let scoringManager = NodeScoringManager()
    let selector = CandidateSelector(
      options: .default,
      scoringManager: scoringManager,
      sourceURL: URL(string: "https://www.nytimes.com/2026/01/01/example.html")
    )
    scoringManager.initializeNode(article)

    let promoted = try selector.promoteSingleChildCandidate(article)

    #expect(promoted === article)
  }

  // MARK: - Parent Score Traversal Tests

  @Test
  func `findBetterParentCandidate finds parent with higher score`() throws {
    let html = """
    <div id="parent">
        <div id="child">Content with enough text for scoring purposes</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let parent = try #require(doc.select("#parent").first())
    let child = try #require(doc.select("#child").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Parent has higher score
    scoringManager.initializeNode(parent)
    scoringManager.addToScore(100, for: parent)

    scoringManager.initializeNode(child)
    scoringManager.addToScore(50, for: child)

    let better = selector.findBetterParentCandidate(child)

    #expect(better.id() == "parent")
  }

  @Test
  func `findBetterParentCandidate respects threshold`() throws {
    let html = """
    <div id="parent">
        <div id="child">Content with enough text for scoring purposes</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let parent = try #require(doc.select("#parent").first())
    let child = try #require(doc.select("#child").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Parent score is too low (below 1/3 of child score)
    scoringManager.initializeNode(parent)
    scoringManager.addToScore(10, for: parent) // Below 100/3

    scoringManager.initializeNode(child)
    scoringManager.addToScore(100, for: child)

    let better = selector.findBetterParentCandidate(child)

    // Should keep child since parent score is below threshold
    #expect(better.id() == "child")
  }

  // MARK: - Sibling Score Threshold Tests

  @Test
  func `calculateSiblingScoreThreshold uses minimum`() throws {
    let html = "<div id='candidate'>Content</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let candidate = try #require(doc.select("#candidate").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Low score
    scoringManager.initializeNode(candidate)
    scoringManager.addToScore(5, for: candidate)

    let threshold = selector.calculateSiblingScoreThreshold(for: candidate)

    // Should use minimum of 10
    #expect(threshold == 10)
  }

  @Test
  func `calculateSiblingScoreThreshold uses ratio for high scores`() throws {
    let html = "<div id='candidate'>Content</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let candidate = try #require(doc.select("#candidate").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // High score
    scoringManager.initializeNode(candidate)
    scoringManager.addToScore(100, for: candidate)

    let threshold = selector.calculateSiblingScoreThreshold(for: candidate)

    // Should use 20% of 105 = 21 (including DIV base score of 5)
    #expect(threshold == 21)
  }

  // MARK: - Ancestor Score Propagation Tests

  @Test
  func `propagateScoreToAncestors adds scores at different levels`() throws {
    let html = """
    <div id="grandparent">
        <div id="parent">
            <p id="child">Content with enough text for scoring</p>
        </div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let child = try #require(doc.select("#child").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    scoringManager.initializeNode(child)
    selector.propagateScoreToAncestors(child, score: 60)

    let parent = try #require(doc.select("#parent").first())
    let grandparent = try #require(doc.select("#grandparent").first())

    // Parent (level 0): 60/1 + 5 (DIV base) = 65
    #expect(scoringManager.getContentScore(for: parent) == 65)

    // Grandparent (level 1): 60/2 + 5 (DIV base) = 35
    #expect(scoringManager.getContentScore(for: grandparent) == 35)
  }

  @Test
  func `propagateScoreToAncestors initializes ancestors`() throws {
    let html = "<div><p>Content with enough text for scoring</p></div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let p = try #require(doc.select("p").first())
    let div = try #require(doc.select("div").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    // Div not initialized yet
    #expect(scoringManager.isInitialized(div) == false)

    scoringManager.initializeNode(p)
    selector.propagateScoreToAncestors(p, score: 10)

    // Div should now be initialized
    #expect(scoringManager.isInitialized(div) == true)
  }

  // MARK: - Edge Cases

  @Test
  func `selectTopCandidate handles empty elements array`() throws {
    let html = "<body></body>"
    let doc = try SwiftSoup.parseBodyFragment(html)

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    let (_, neededToCreate) = try selector.selectTopCandidate(from: [], in: doc)

    // Should create fallback
    #expect(neededToCreate == true)
  }

  @Test
  func `fallback candidate preserves body-level non-element nodes`() throws {
    let html = "<html><body>Lead<span>inline</span>Tail<!--note--></body></html>"
    let doc = try SwiftSoup.parse(html)

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    let (candidate, neededToCreate) = try selector.selectTopCandidate(from: [], in: doc)

    #expect(neededToCreate == true)
    #expect(candidate.tagName().lowercased() == "div")
    #expect(candidate.getChildNodes().map { $0.nodeName() } == ["#text", "span", "#text", "#comment"])
    #expect(try candidate.text() == "LeadinlineTail")
  }

  @Test
  func `findBetterTopCandidate handles insufficient alternatives`() throws {
    let html = """
    <div>
        <section id="sec1"><p>Content one</p></section>
        <section id="sec2"><p>Content two</p></section>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let sections = try doc.select("section").array()

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    let topCandidates = TopCandidates(maxCount: 5)
    for section in sections {
      scoringManager.initializeNode(section)
      scoringManager.addToScore(100, for: section)
      topCandidates.add(Candidate(element: section, score: 100))
    }

    let first = sections[0]
    let better = try selector.findBetterTopCandidate(from: first, topCandidates: topCandidates)

    // Only 2 alternatives, need 3 minimum
    #expect(better.id() == "sec1")
  }

  @Test
  func `propagateScoreToAncestors respects maxDepth`() throws {
    let html = """
    <div id="level3">
        <div id="level2">
            <div id="level1">
                <div id="level0">
                    <p id="child">Content</p>
                </div>
            </div>
        </div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let child = try #require(doc.select("#child").first())

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions()
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    scoringManager.initializeNode(child)
    selector.propagateScoreToAncestors(child, score: 60)

    // Level 0 (parent): 60/1 + 5 = 65
    let level0 = try #require(doc.select("#level0").first())
    #expect(scoringManager.getContentScore(for: level0) == 65)

    // Level 1 (grandparent): 60/2 + 5 = 35
    let level1 = try #require(doc.select("#level1").first())
    #expect(scoringManager.getContentScore(for: level1) == 35)

    // Level 2: 60/(2*3) + 5 = 15
    let level2 = try #require(doc.select("#level2").first())
    #expect(scoringManager.getContentScore(for: level2) == 15)

    // Level 3: 60/(3*3) + 5 = 11.67
    let level3 = try #require(doc.select("#level3").first())
    let level3Score = scoringManager.getContentScore(for: level3)
    #expect(level3Score > 11 && level3Score < 12)
  }
}
