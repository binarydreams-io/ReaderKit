// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Readability
import Testing

@Suite("String+HTML Extraction")
struct StringHTMLTests {

  // MARK: - htmlText

  @Test
  func `htmlText strips tags and returns visible body text`() throws {
    let html = "<html><body><p>Hello <strong>world</strong>!</p></body></html>"
    let text = try html.htmlText()
    #expect(text == "Hello world!")
  }

  @Test
  func `htmlText returns the empty string on an empty input`() throws {
    #expect(try "".htmlText() == "")
  }

  @Test
  func `htmlText wraps loose text in body and returns it`() throws {
    #expect(try "Just some text".htmlText() == "Just some text")
  }

  @Test
  func `htmlText normalises whitespace`() throws {
    let html = "<p>Hello   \n\n  world</p>"
    let text = try html.htmlText()
    #expect(text == "Hello world")
  }

  @Test
  func `htmlText still parses unclosed tags (SwiftSoup is forgiving)`() throws {
    let text = try "<p>Hello <b>world".htmlText()
    #expect(text == "Hello world")
  }

  // MARK: - htmlImageURLs

  @Test
  func `htmlImageURLs returns absolute URLs in document order`() throws {
    let html = """
    <html><body>
      <img src="https://example.com/a.png">
      <p>Inline content</p>
      <img src="https://example.com/b.png">
    </body></html>
    """
    let images = try html.htmlImageURLs()
    #expect(images.map(\.absoluteString) == [
      "https://example.com/a.png",
      "https://example.com/b.png"
    ])
  }

  @Test
  func `htmlImageURLs returns an empty array when no img tags exist`() throws {
    let images = try "<p>Just text</p>".htmlImageURLs()
    #expect(images.isEmpty)
  }

  @Test
  func `htmlImageURLs skips img elements with an empty src attribute`() throws {
    let html = """
    <body>
      <img src="">
      <img src="https://example.com/keep.png">
    </body>
    """
    let images = try html.htmlImageURLs()
    #expect(images.map(\.absoluteString) == ["https://example.com/keep.png"])
  }

  @Test
  func `htmlImageURLs skips img elements without a src attribute`() throws {
    let html = "<body><img alt=\"no src\"><img src=\"https://example.com/keep.png\"></body>"
    let images = try html.htmlImageURLs()
    #expect(images.map(\.absoluteString) == ["https://example.com/keep.png"])
  }

  @Test
  func `htmlImageURLs preserves data: URIs as-is`() throws {
    let html = "<body><img src=\"data:image/png;base64,iVBORw0KGgo=\"></body>"
    let images = try html.htmlImageURLs()
    #expect(images.count == 1)
    #expect(images.first?.scheme == "data")
  }

  @Test
  func `htmlImageURLs returns an empty array on an empty document`() throws {
    #expect(try "".htmlImageURLs().isEmpty)
  }

  @Test
  func `htmlImageURLs drops relative src when no base href is set`() throws {
    // SwiftSoup's `absUrl("src")` returns "" when it cannot resolve the URL,
    // so relative sources should be filtered out.
    let html = "<body><img src=\"images/relative.png\"></body>"
    let images = try html.htmlImageURLs()
    #expect(images.isEmpty, "Relative src must be dropped when no base href is available")
  }

  @Test
  func `htmlImageURLs resolves relative src against a <base href>`() throws {
    let html = """
    <html>
      <head><base href="https://example.com/blog/"></head>
      <body><img src="images/cover.png"></body>
    </html>
    """
    let images = try html.htmlImageURLs()
    #expect(images.map(\.absoluteString) == ["https://example.com/blog/images/cover.png"])
  }
}
