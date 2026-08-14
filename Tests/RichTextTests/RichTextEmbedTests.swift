import Foundation
@testable import RichText
import Testing

@Suite("RichText embeds")
struct RichTextEmbedTests {
  private func blocks(_ html: String) throws -> [ArticleBlock] {
    try RichText(html: html, baseURL: URL(string: "https://example.com")).blocks()
  }

  @Test
  func `youtube iframe becomes a video embed with a poster`() throws {
    let result = try blocks(#"<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>"#)
    guard case let .embed(embed) = result.first else { Issue.record("not an embed")
      return
    }
    guard case let .video(poster) = embed.kind else { Issue.record("not a video")
      return
    }
    #expect(poster?.absoluteString == "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
  }

  @Test
  func `youtu dot be short link derives a poster`() throws {
    let result = try blocks(#"<iframe src="https://youtu.be/dQw4w9WgXcQ"></iframe>"#)
    guard case let .embed(embed) = result.first, case let .video(poster) = embed.kind else {
      Issue.record("not a video embed")
      return
    }
    #expect(poster?.absoluteString == "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
  }

  @Test
  func `video element with a source becomes a video embed`() throws {
    let result = try blocks(#"<video poster="https://example.com/p.jpg"><source src="https://example.com/v.mp4"></video>"#)
    guard case let .embed(embed) = result.first else { Issue.record("not an embed")
      return
    }
    #expect(embed.url.absoluteString == "https://example.com/v.mp4")
    guard case let .video(poster) = embed.kind else { Issue.record("not a video")
      return
    }
    #expect(poster?.absoluteString == "https://example.com/p.jpg")
  }

  @Test
  func `non-video iframe becomes a link embed`() throws {
    let result = try blocks(#"<iframe src="https://example.com/widget"></iframe>"#)
    guard case let .embed(embed) = result.first else { Issue.record("not an embed")
      return
    }
    #expect(embed.kind == .link)
    #expect(embed.url.absoluteString == "https://example.com/widget")
  }

  @Test
  func `iframe without a src is dropped`() throws {
    let result = try blocks("<iframe></iframe>")
    #expect(result.isEmpty)
  }
}
