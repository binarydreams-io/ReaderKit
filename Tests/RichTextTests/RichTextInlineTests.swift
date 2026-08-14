import Foundation
@testable import RichText
import SwiftSoup
import Testing

@Suite("RichText inline")
struct RichTextInlineTests {
  private func inline(_ html: String, baseURL: String = "") throws -> AttributedString {
    let body = try #require(SwiftSoup.parseBodyFragment(html, baseURL).body())
    return try RichText(html: "<p></p>").inlineText(of: body)
  }

  @Test
  func `plain text passes through`() throws {
    let s = try inline("Hello world")
    #expect(String(s.characters) == "Hello world")
  }

  @Test
  func `bold sets stronglyEmphasized intent`() throws {
    let s = try inline("a <strong>b</strong> c")
    let boldRun = try #require(s.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    #expect(String(s[boldRun.range].characters) == "b")
  }

  @Test
  func `italic sets emphasized intent`() throws {
    let s = try inline("<em>x</em>")
    #expect(s.runs.first?.inlinePresentationIntent?.contains(.emphasized) == true)
  }

  @Test
  func `inline code sets code intent`() throws {
    let s = try inline("<code>x</code>")
    #expect(s.runs.first?.inlinePresentationIntent?.contains(.code) == true)
  }

  @Test
  func `nested strong and em combine both intents on one run`() throws {
    let s = try inline("<strong><em>x</em></strong>")
    let intent = s.runs.first?.inlinePresentationIntent
    #expect(intent?.contains(.stronglyEmphasized) == true)
    #expect(intent?.contains(.emphasized) == true)
  }

  @Test
  func `anchor carries an absolute link attribute`() throws {
    let s = try inline(#"<a href="https://example.com/a">link</a>"#)
    let linked = try #require(s.runs.first { $0.link != nil })
    #expect(linked.link?.absoluteString == "https://example.com/a")
  }

  @Test
  func `relative anchor href resolves against the base url`() throws {
    let s = try inline(#"<a href="/foo">link</a>"#, baseURL: "https://example.com/")
    let linked = try #require(s.runs.first { $0.link != nil })
    #expect(linked.link?.absoluteString == "https://example.com/foo")
  }

  @Test
  func `br becomes a newline`() throws {
    let s = try inline("a<br>b")
    #expect(String(s.characters) == "a\nb")
  }

  @Test
  func `collapses runs of whitespace to a single space`() throws {
    let s = try inline("a   \n  b")
    #expect(String(s.characters) == "a b")
  }
}
