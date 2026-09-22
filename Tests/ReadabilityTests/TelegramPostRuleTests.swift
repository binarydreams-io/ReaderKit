// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Readability
import Testing

@Suite("Telegram post rule")
struct TelegramPostRuleTests {
  private let options = ReadabilityOptions(minimumCharacterCount: 500, classesToPreserve: ["caption"])

  @Test(arguments: ["telegram-post-photo", "telegram-post-text"])
  func `A Telegram embed page reads as the post's media and text`(fixture: String) throws {
    let testCase = try #require(TestLoader.loadTestCase(named: fixture))

    let readable = try Readability(html: testCase.sourceHTML, baseURL: testCase.sourceURL, options: options).parse()

    let comparison = DOMComparator.compare(readable.content, testCase.expectedHTML)
    #expect(comparison.isEqual, "\(fixture): \(comparison.diff)")
    #expect(readable.byline == testCase.expectedMetadata.byline)
  }

  @Test
  func `A video post keeps the video with its poster, and photo-only posts keep the photo`() throws {
    let html = """
    <html><head><title>Telegram Widget</title></head><body class="tgme_widget">
    <div class="tgme_widget_message" data-post="channel/7">
      <div class="tgme_widget_message_author"><a class="tgme_widget_message_owner_name" href="https://t.me/channel"><span>Channel</span></a></div>
      <a class="tgme_widget_message_video_player" href="https://t.me/channel/7">
        <i class="tgme_widget_message_video_thumb" style="background-image:url('https://cdn.example/poster.jpg')"></i>
        <div class="tgme_widget_message_video_wrap"><video src="https://cdn.example/clip.mp4" class="tgme_widget_message_video js-message_video"></video></div>
      </a>
      <a class="tgme_widget_message_photo_wrap" href="https://t.me/channel/7" style="width:800px;background-image:url('https://cdn.example/photo.jpg')"><div class="tgme_widget_message_photo"></div></a>
      <div class="tgme_widget_message_footer"><span class="tgme_widget_message_views">12</span><a href="https://t.me/channel/7">Copy</a></div>
    </div>
    </body></html>
    """

    let readable = try Readability(html: html, baseURL: URL(string: "https://t.me/channel/7?embed=1"), options: options).parse()

    #expect(readable.content.contains("<video src=\"https://cdn.example/clip.mp4\" poster=\"https://cdn.example/poster.jpg\""))
    #expect(readable.content.contains("<img src=\"https://cdn.example/photo.jpg\""))
    #expect(!readable.content.contains("Copy"))
    #expect(readable.byline == "Channel")
  }

  @Test
  func `Runs of line breaks become paragraphs, a single break stays inline`() throws {
    let html = """
    <html><body class="tgme_widget">
    <div class="tgme_widget_message" data-post="channel/8">
      <div class="tgme_widget_message_text js-message_text" dir="auto">First line<br/>still first<br/><br/>Second paragraph <b>bold</b><br><br><br>Third</div>
    </div>
    </body></html>
    """

    let readable = try Readability(html: html, baseURL: URL(string: "https://t.me/channel/8?embed=1"), options: options).parse()

    let content = readable.content.replacingOccurrences(of: "\\s*\\n\\s*", with: "", options: .regularExpression)
    #expect(content.contains("<p>First line<br />still first</p><p>Second paragraph <b>bold</b></p><p>Third</p>"), "\(content)")
  }

  @Test
  func `A Telegram page without a post widget is left to the generic pipeline`() throws {
    let html = """
    <html><body><article><h1>Telegram FAQ</h1>
    <p>\(String(repeating: "Telegram is a messaging app with a focus on speed and security. ", count: 12))</p>
    </article></body></html>
    """

    let readable = try Readability(html: html, baseURL: URL(string: "https://telegram.org/faq"), options: options).parse()

    #expect(readable.content.contains("Telegram is a messaging app"))
  }
}
