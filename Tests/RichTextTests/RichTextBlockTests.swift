import Foundation
@testable import RichText
import Testing

@Suite("RichText blocks")
struct RichTextBlockTests {
  private func blocks(_ html: String) throws -> [ArticleBlock] {
    try RichText(html: html, baseURL: URL(string: "https://example.com")).blocks()
  }

  @Test
  func `paragraph becomes a paragraph block`() throws {
    let result = try blocks("<p>Hello world</p>")
    #expect(result == [.paragraph(AttributedString("Hello world"))])
  }

  @Test(arguments: [("h1", 1), ("h2", 2), ("h3", 3), ("h4", 4), ("h5", 5), ("h6", 6)])
  func `heading tag maps to its level`(tag: String, level: Int) throws {
    let result = try blocks("<\(tag)>Title</\(tag)>")
    #expect(result == [.heading(level: level, AttributedString("Title"))])
  }

  @Test
  func `wrapper divs are flattened into their block children in order`() throws {
    let result = try blocks("<div><div><p>One</p><p>Two</p></div></div>")
    #expect(result == [.paragraph(AttributedString("One")), .paragraph(AttributedString("Two"))])
  }

  @Test
  func `loose inline text is wrapped as a paragraph`() throws {
    let result = try blocks("<div>Just text</div>")
    #expect(result == [.paragraph(AttributedString("Just text"))])
  }

  @Test
  func `empty paragraphs are skipped and real content survives`() throws {
    let result = try blocks("<p>   </p><p>Real</p>")
    #expect(result == [.paragraph(AttributedString("Real"))])
  }

  @Test
  func `hr becomes a thematic break`() throws {
    #expect(try blocks("<hr>") == [.thematicBreak])
  }

  @Test(arguments: [("ul", false), ("ol", true)])
  func `list tag maps to its ordered flag`(tag: String, ordered: Bool) throws {
    let result = try blocks("<\(tag)><li>One</li><li>Two</li></\(tag)>")
    guard case let .list(isOrdered, items) = result.first else { Issue.record("not a list")
      return
    }
    #expect(isOrdered == ordered)
    #expect(items.count == 2)
    let firstItem = try #require(items.first)
    #expect(firstItem == [.paragraph(AttributedString("One"))])
  }

  @Test
  func `nested list is preserved inside its parent item`() throws {
    let result = try blocks("<ul><li>Outer<ul><li>Inner</li></ul></li></ul>")
    guard case let .list(_, items) = result.first else { Issue.record("no list")
      return
    }
    let firstItem = try #require(items.first)
    let hasNestedList = firstItem.contains {
      if case .list = $0 {
        true
      } else {
        false
      }
    }
    #expect(hasNestedList)
  }

  @Test
  func `blockquote wraps its child blocks`() throws {
    let result = try blocks("<blockquote><p>Quoted</p></blockquote>")
    #expect(result == [.blockquote([.paragraph(AttributedString("Quoted"))])])
  }

  @Test
  func `blockquote with only text wraps it as a paragraph`() throws {
    let result = try blocks("<blockquote>Bare quote</blockquote>")
    #expect(result == [.blockquote([.paragraph(AttributedString("Bare quote"))])])
  }

  @Test
  func `pre becomes a code block preserving text`() throws {
    let result = try blocks("<pre><code>let x = 1\nlet y = 2</code></pre>")
    guard case let .codeBlock(code, _) = result.first else { Issue.record("not code")
      return
    }
    #expect(code == "let x = 1\nlet y = 2")
  }

  @Test
  func `img becomes an image block with absolute url`() throws {
    let result = try blocks(#"<img src="https://example.com/a.png" alt="Alt">"#)
    guard case let .image(image) = result.first else { Issue.record("not an image")
      return
    }
    #expect(image.url.absoluteString == "https://example.com/a.png")
    #expect(image.alt == "Alt")
  }

  @Test
  func `relative img src resolves against the base url`() throws {
    let result = try blocks(#"<img src="/a.png">"#)
    guard case let .image(image) = result.first else { Issue.record("not an image")
      return
    }
    #expect(image.url.absoluteString == "https://example.com/a.png")
  }

  @Test
  func `figure yields an image with its figcaption`() throws {
    let result = try blocks("""
    <figure><img src="https://example.com/b.png"><figcaption>A caption</figcaption></figure>
    """)
    guard case let .image(image) = result.first else { Issue.record("not an image")
      return
    }
    #expect(image.url.absoluteString == "https://example.com/b.png")
    #expect(image.caption == "A caption")
  }

  @Test
  func `img without a resolvable src is dropped`() throws {
    let result = try blocks(#"<img alt="no src">"#)
    #expect(result.isEmpty)
  }

  @Test
  func `picture yields an image block from its inner img`() throws {
    let result = try blocks(#"""
    <picture><source srcset="https://example.com/p.webp"><img src="https://example.com/p.jpg" alt="Pic"></picture>
    """#)
    guard case let .image(image) = result.first else { Issue.record("not an image")
      return
    }
    #expect(image.url.absoluteString == "https://example.com/p.jpg")
    #expect(image.alt == "Pic")
  }

  @Test
  func `picture nested in a div still yields an image block`() throws {
    let result = try blocks(#"<div><picture><img src="https://example.com/q.png"></picture></div>"#)
    let hasImage = result.contains {
      if case .image = $0 {
        true
      } else {
        false
      }
    }
    #expect(hasImage)
  }

  @Test
  func `table yields rows and cells`() throws {
    let result = try blocks("""
    <table><thead><tr><th>H1</th><th>H2</th></tr></thead>
    <tbody><tr><td>a</td><td>b</td></tr></tbody></table>
    """)
    guard case let .table(table) = result.first else { Issue.record("not a table")
      return
    }
    #expect(table.hasHeaderRow == true)
    #expect(table.rows.count == 2)
    #expect(table.rows[0].map { String($0.characters) } == ["H1", "H2"])
    #expect(table.rows[1].map { String($0.characters) } == ["a", "b"])
  }

  @Test
  func `table without th has no header row`() throws {
    let result = try blocks("<table><tr><td>x</td></tr></table>")
    guard case let .table(table) = result.first else { Issue.record("not a table")
      return
    }
    #expect(table.hasHeaderRow == false)
    #expect(table.rows.count == 1)
  }
}
