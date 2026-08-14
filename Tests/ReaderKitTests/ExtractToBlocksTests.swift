import Foundation
@testable import ReaderKit
import Testing

@Suite("Readability.extractContent → RichText.blocks")
struct ExtractToBlocksTests {
  @Test
  func `extractContent preserves a content image through the block pipeline`() throws {
    let html = """
    <html><head><title>My Post — Example</title></head><body>
      <article>
        <h1>My Post</h1>
        <p>First paragraph with enough words to be considered real article content here.</p>
        <figure><img src="https://example.com/photo.jpg" alt="A photo"><figcaption>Cap</figcaption></figure>
        <p>Second paragraph with additional words so the extractor keeps this block intact.</p>
      </article>
    </body></html>
    """
    let url = URL(string: "https://example.com/post")
    let readable = try Readability(html: html, baseURL: url).extractContent()
    let renderBlocks = try RichText(content: readable.content, baseURL: url).blocks()
    let hasImage = renderBlocks.contains {
      if case .image = $0 {
        true
      } else {
        false
      }
    }
    #expect(hasImage, "expected an .image block via extractContent path; got \(renderBlocks)")
  }
}
