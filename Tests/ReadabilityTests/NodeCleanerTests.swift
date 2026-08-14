@testable import Readability
import SwiftSoup
import Testing

/// Tests for NodeCleaner functionality
/// These tests verify noise removal and content cleaning
@Suite("Node Cleaner Tests")
struct NodeCleanerTests {

  // MARK: - Unlikely Candidate Removal Tests

  @Test
  func `removeUnlikelyCandidates removes supplemental modules`() throws {
    let html = """
    <main>
      <article id="story">A local article fixture with readable text.</article>
      <aside id="supplemental-1" class="supplemental">Related stories</aside>
    </main>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else {
      Issue.record("Missing body in local source")
      return
    }

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: body, stripUnlikelyCandidates: true)

    let supplemental = try doc.select("#supplemental-1")
    #expect(supplemental.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates removes banner elements`() throws {
    let html = """
    <div>
        <div class="article-content">Real content here</div>
        <div class="banner-ad">Advertisement</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

    let banner = try doc.select(".banner-ad")
    #expect(banner.isEmpty())
    let content = try doc.select(".article-content")
    #expect(!content.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates removes comment sections`() throws {
    let html = """
    <div>
        <article>Article content</article>
        <div class="comments">User comments</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

    let comments = try doc.select(".comments")
    #expect(comments.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates keeps content elements`() throws {
    let html = """
    <div>
        <article class="main-content">Article</article>
        <div class="article-body">Body</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

    let article = try doc.select("article")
    #expect(!article.isEmpty())
    let body = try doc.select(".article-body")
    #expect(!body.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates removes by ARIA role`() throws {
    let html = """
    <div>
        <article>Content</article>
        <nav role="navigation">Menu</nav>
        <div role="complementary">Sidebar</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

    let nav = try doc.select("nav")
    #expect(nav.isEmpty())
    let complementary = try doc.select("[role=complementary]")
    #expect(complementary.isEmpty())
    let article = try doc.select("article")
    #expect(!article.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates removes empty containers`() throws {
    let html = """
    <div>
        <section></section>
        <div>Content</div>
        <header>   </header>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

    let sections = try doc.select("section")
    #expect(sections.isEmpty())
    let headers = try doc.select("header")
    #expect(headers.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates skips when flag disabled`() throws {
    let html = """
    <div>
        <div class="banner-ad">Ad</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: false)

    let banner = try doc.select(".banner-ad")
    #expect(!banner.isEmpty())
  }

  @Test
  func `removeUnlikelyCandidates protects table contents`() throws {
    let html = """
    <table>
        <tr>
            <td class="comment">Cell in table</td>
        </tr>
    </table>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("table").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

    let cell = try doc.select("td")
    #expect(!cell.isEmpty())
  }

  // MARK: - Byline Extraction Tests

  @Test
  func `checkAndExtractByline extracts author from rel attribute`() throws {
    let html = "<span rel='author'>John Doe</span>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let span = try #require(doc.select("span").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

    #expect(shouldRemove == true)
    #expect(cleaner.getExtractedByline() == "John Doe")
  }

  @Test
  func `checkAndExtractByline extracts author from itemprop`() throws {
    let html = "<span itemprop='author'>Jane Smith</span>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let span = try #require(doc.select("span").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

    #expect(shouldRemove == true)
    #expect(cleaner.getExtractedByline() == "Jane Smith")
  }

  @Test
  func `checkAndExtractByline extracts from byline class`() throws {
    let html = "<div class='byline'>Written by Bob</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(div, matchString: "byline")

    #expect(shouldRemove == true)
    #expect(cleaner.getExtractedByline() == "Written by Bob")
  }

  @Test
  func `checkAndExtractByline prefers itemprop name child`() throws {
    let html = """
    <div itemprop="author">
        <span itemprop="name">Actual Author</span>
        <span>Other text</span>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(div, matchString: "")

    #expect(shouldRemove == true)
    #expect(cleaner.getExtractedByline() == "Actual Author")
  }

  @Test
  func `checkAndExtractByline prefers author-link text over title suffix`() throws {
    let html = """
    <div class="author">
        <a class="author-link" href="/author/ben-silverman">Ben Silverman</a>
        <div class="author-title">Games Editor</div>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div.author").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(div, matchString: "author")

    #expect(shouldRemove == true)
    #expect(cleaner.getExtractedByline() == "Ben Silverman")
  }

  @Test
  func `checkAndExtractByline skips if too long`() throws {
    let longName = String(repeating: "A", count: 101)
    let html = "<span rel='author'>\(longName)</span>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let span = try #require(doc.select("span").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

    #expect(shouldRemove == false)
    #expect(cleaner.getExtractedByline() == nil)
  }

  @Test
  func `checkAndExtractByline skips if already have byline`() throws {
    let html = "<span rel='author'>Second Author</span>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let span = try #require(doc.select("span").first())

    let cleaner = NodeCleaner(options: .default)
    cleaner.setArticleByline("First Author")
    let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

    #expect(shouldRemove == false)
    #expect(cleaner.getExtractedByline() == "First Author")
  }

  // MARK: - Header Duplicate Title Tests

  @Test
  func `headerDuplicatesTitle detects matching H1`() throws {
    let html = "<h1>Article Title Here</h1>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let h1 = try #require(doc.select("h1").first())

    let cleaner = NodeCleaner(options: .default)
    cleaner.setArticleTitle("Article Title Here")

    #expect(cleaner.headerDuplicatesTitle(h1) == true)
  }

  @Test
  func `headerDuplicatesTitle detects similar H2`() throws {
    let html = "<h2>The Article Title</h2>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let h2 = try #require(doc.select("h2").first())

    let cleaner = NodeCleaner(options: .default)
    cleaner.setArticleTitle("Article Title")

    #expect(cleaner.headerDuplicatesTitle(h2) == true)
  }

  @Test
  func `headerDuplicatesTitle skips different content`() throws {
    let html = "<h1>Completely Different Title</h1>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let h1 = try #require(doc.select("h1").first())

    let cleaner = NodeCleaner(options: .default)
    cleaner.setArticleTitle("Article Title")

    #expect(cleaner.headerDuplicatesTitle(h1) == false)
  }

  @Test
  func `headerDuplicatesTitle skips non-heading elements`() throws {
    let html = "<div>Article Title</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    cleaner.setArticleTitle("Article Title")

    #expect(cleaner.headerDuplicatesTitle(div) == false)
  }

  // MARK: - Visibility Check Tests

  @Test
  func `isProbablyVisible returns false for display:none`() throws {
    let html = "<div style='display:none'>Hidden</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isProbablyVisible(div) == false)
  }

  @Test
  func `isProbablyVisible returns false for visibility:hidden`() throws {
    let html = "<div style='visibility:hidden'>Hidden</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isProbablyVisible(div) == false)
  }

  @Test
  func `isProbablyVisible returns false for hidden attribute`() throws {
    let html = "<div hidden>Hidden</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isProbablyVisible(div) == false)
  }

  @Test
  func `isProbablyVisible returns false for aria-hidden`() throws {
    let html = "<div aria-hidden='true'>Hidden</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isProbablyVisible(div) == false)
  }

  @Test
  func `isProbablyVisible allows fallback-image with aria-hidden`() throws {
    let html = "<div aria-hidden='true' class='fallback-image'>Math</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isProbablyVisible(div) == true)
  }

  @Test
  func `isProbablyVisible returns true for normal elements`() throws {
    let html = "<div>Visible content</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isProbablyVisible(div) == true)
  }

  // MARK: - Modal Dialog Check Tests

  @Test
  func `isModalDialog detects modal dialog`() throws {
    let html = "<div aria-modal='true' role='dialog'>Modal</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isModalDialog(div) == true)
  }

  @Test
  func `isModalDialog returns false for non-modal`() throws {
    let html = "<div role='dialog'>Regular dialog</div>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let div = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)

    #expect(cleaner.isModalDialog(div) == false)
  }

  // MARK: - Text Similarity Tests

  @Test
  func `textSimilarity returns 1 for identical strings`() {
    let cleaner = NodeCleaner(options: .default)
    let similarity = cleaner.textSimilarity("Hello World", "Hello World")

    #expect(similarity == 1.0)
  }

  @Test
  func `textSimilarity returns 0 for completely different strings`() {
    let cleaner = NodeCleaner(options: .default)
    let similarity = cleaner.textSimilarity("Hello World", "Completely Different")

    #expect(similarity == 0.0)
  }

  @Test
  func `textSimilarity returns high value for similar strings`() {
    let cleaner = NodeCleaner(options: .default)
    let similarity = cleaner.textSimilarity("Article Title Here", "The Article Title")

    #expect(similarity > 0.75)
  }

  @Test
  func `textSimilarity handles case insensitivity`() {
    let cleaner = NodeCleaner(options: .default)
    let similarity = cleaner.textSimilarity("HELLO WORLD", "hello world")

    #expect(similarity == 1.0)
  }

  @Test
  func `textSimilarity handles empty strings`() {
    let cleaner = NodeCleaner(options: .default)
    let similarity = cleaner.textSimilarity("", "Hello")

    #expect(similarity == 0.0)
  }

  // MARK: - Remove Matching Elements Tests

  @Test
  func `removeMatchingElements removes based on filter`() throws {
    let html = """
    <div>
        <p class="keep">Keep</p>
        <p class="remove">Remove</p>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let root = try #require(doc.select("div").first())

    let cleaner = NodeCleaner(options: .default)
    try cleaner.removeMatchingElements(from: root) { _, matchString in
      matchString.contains("remove")
    }

    let keep = try doc.select(".keep")
    let remove = try doc.select(".remove")

    #expect(!keep.isEmpty())
    #expect(remove.isEmpty())
  }

  // MARK: - Edge Cases

  @Test
  func `checkAndExtractByline skips empty elements`() throws {
    let html = "<span rel='author'>   </span>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let span = try #require(doc.select("span").first())

    let cleaner = NodeCleaner(options: .default)
    let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

    #expect(shouldRemove == false)
  }

  @Test
  func `textSimilarity handles partial overlap`() {
    let cleaner = NodeCleaner(options: .default)
    let similarity = cleaner.textSimilarity("Hello World Test", "Hello World Example")

    // Should be between 0 and 1
    #expect(similarity > 0.0)
    #expect(similarity < 1.0)
  }
}
