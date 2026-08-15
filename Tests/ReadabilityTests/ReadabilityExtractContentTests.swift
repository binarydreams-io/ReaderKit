// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Readability
import SwiftSoup
import Testing

@Suite("Readability.extractContent")
struct ReadabilityExtractContentTests {
  private static let html = """
  <html><head><title>My Post — Example</title></head><body>
    <article>
      <h1>My Post</h1>
      <p>First paragraph with enough words to be considered real article content here.</p>
      <p>Second paragraph with additional words so the extractor keeps this block intact.</p>
    </article>
  </body></html>
  """

  @Test
  func `extractContent returns a non-empty cleaned element`() throws {
    let readability = try Readability(html: Self.html, baseURL: URL(string: "https://example.com/post"))
    let readable = try readability.extractContent()
    #expect(readable.title.isEmpty == false)
    let text = try readable.content.text()
    #expect(text.contains("First paragraph"))
    #expect(text.contains("Second paragraph"))
  }

  @Test
  func `extractCore cleaned element serializes to the same html as parse`() throws {
    let viaParse = try Readability(html: Self.html, baseURL: URL(string: "https://example.com/post")).parse().content

    // `extractCore` and `serializeCleaned` are both non-consuming, so the same
    // instance can be borrowed twice — unlike `parse()`/`extractContent()`.
    let readability = try Readability(html: Self.html, baseURL: URL(string: "https://example.com/post"))
    let core = try readability.extractCore(inspectionContext: nil)
    let viaExtract = try readability.serializeCleaned(core.cleaned)

    #expect(viaExtract == viaParse)
  }
}
