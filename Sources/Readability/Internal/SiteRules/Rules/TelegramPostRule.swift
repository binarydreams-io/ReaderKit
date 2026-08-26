// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftSoup

/// Rebuilds a Telegram post embed (`t.me/<channel>/<id>?embed=1`) into a plain
/// article: the "Forwarded from" line, each photo and video, and the message
/// text as paragraphs.
///
/// The public post page carries no message text at all — a script injects the
/// widget — so Readability finds nothing but the widget's "Copy" link there;
/// `ReaderView` fetches the embed variant instead. Even the embed keeps photos
/// as CSS background images inside chrome (avatar, reactions, view counts,
/// deep links) that outweighs a one-line post in scoring, and a typical post
/// sits far below `charThreshold`.
///
/// SiteRule Metadata:
/// - Scope: t.me / telegram.me pages containing `div.tgme_widget_message`
/// - Phase: pre-extraction rebuild, short-content fallback, textless content
///   retention, metadata byline
/// - Trigger: `div.tgme_widget_message` on a Telegram host
/// - Evidence: `Tests/ReadabilityTests/Resources/test-pages/telegram-post-*`
/// - Risk if misplaced: every Telegram post reads as "Copy" or as not found
enum TelegramPostRule: PreExtractionDocumentRule, ShortContentFallbackSiteRule, TextlessArticleContentSiteRule, MetadataBylineSiteRule {
  static let id = "telegram-post"
  static let hosts: [String]? = ["t.me", "telegram.me"]

  /// Marks the rebuilt article so the short-content fallback can hand it back.
  static let articleID = "readerkit-telegram-post"

  // MARK: - PreExtractionDocumentRule

  static func apply(to document: Document, sourceURL: URL?) throws {
    let messages = try document.select("div.tgme_widget_message").array()
    guard !messages.isEmpty, let body = document.body() else {
      return
    }

    let article = try document.createElement("div")
    try article.attr("id", articleID)
    for (index, message) in messages.enumerated() {
      if index > 0 {
        try article.appendChild(document.createElement("hr"))
      }
      try appendForwardedFrom(of: message, to: article, in: document)
      try appendMedia(of: message, to: article, in: document)
      try appendText(of: message, to: article, in: document)
    }
    _ = body.empty()
    try body.appendChild(article)
  }

  // MARK: - ShortContentFallbackSiteRule

  static func fallbackArticleContent(in document: Document, sourceURL: URL?) throws -> Element? {
    try document.getElementById(articleID)
  }

  // MARK: - TextlessArticleContentSiteRule

  static func shouldKeepTextlessArticleContent(_ articleContent: Element, sourceURL: URL?, document: Document) throws -> Bool {
    try !articleContent.select("img, video").isEmpty()
  }

  // MARK: - MetadataBylineSiteRule

  /// Metadata runs before the rebuild, while the widget's owner name is still
  /// in the DOM.
  static func apply(currentByline: String?, sourceURL: URL?, document: Document) throws -> String? {
    guard let owner = try document.select("div.tgme_widget_message .tgme_widget_message_owner_name").first() else {
      return currentByline
    }
    let name = try owner.text().trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? currentByline : name
  }

  // MARK: - Rebuild

  private static func appendForwardedFrom(of message: Element, to article: Element, in document: Document) throws {
    guard let forwarded = try message.select("div.tgme_widget_message_forwarded_from").first() else {
      return
    }
    let paragraph = try document.createElement("p")
    if let source = try forwarded.select("a.tgme_widget_message_forwarded_from_name[href]").first() {
      let name = try source.text().trimmingCharacters(in: .whitespacesAndNewlines)
      let label = try forwarded.text()
        .replacingOccurrences(of: name, with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      try paragraph.appendText("\(label) ")
      let anchor = try document.createElement("a")
      try anchor.attr("href", source.attr("href"))
      try anchor.text(name)
      try paragraph.appendChild(anchor)
    } else {
      try paragraph.text(forwarded.text().trimmingCharacters(in: .whitespacesAndNewlines))
    }
    try article.appendChild(paragraph)
  }

  private static func appendMedia(of message: Element, to article: Element, in document: Document) throws {
    for photo in try message.select("a.tgme_widget_message_photo_wrap[style]").array() {
      guard let source = backgroundImageURL(in: try photo.attr("style")) else {
        continue
      }
      let figure = try document.createElement("figure")
      let image = try document.createElement("img")
      try image.attr("src", source)
      try figure.appendChild(image)
      try article.appendChild(figure)
    }

    let posters = try message.select("i.tgme_widget_message_video_thumb[style]").array()
    for (index, player) in try message.select("video.tgme_widget_message_video[src]").array().enumerated() {
      let video = try document.createElement("video")
      try video.attr("src", player.attr("src"))
      if index < posters.count, let poster = backgroundImageURL(in: try posters[index].attr("style")) {
        try video.attr("poster", poster)
      }
      try article.appendChild(video)
    }
  }

  /// Groups the message's inline runs into paragraphs and keeps the block
  /// children `prepDocument` already made out of `<br><br>` runs as they are;
  /// a lone `<br>` stays a line break inside its paragraph.
  private static func appendText(of message: Element, to article: Element, in document: Document) throws {
    guard let text = try message.select("div.tgme_widget_message_text").first() else {
      return
    }
    var paragraph: Element?
    func flushParagraph() throws {
      if let paragraph, try !paragraph.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try article.appendChild(paragraph)
      }
      paragraph = nil
    }
    for node in text.getChildNodes() {
      if let element = node as? Element, element.isBlock() {
        try flushParagraph()
        try article.appendChild(DOMHelpers.cloneElement(element, in: document))
      } else if let element = node as? Element {
        let target = try paragraph ?? document.createElement("p")
        try target.appendChild(DOMHelpers.cloneElement(element, in: document))
        paragraph = target
      } else if let textNode = node as? TextNode {
        let target = try paragraph ?? document.createElement("p")
        try target.appendChild(TextNode(textNode.getWholeText(), document.location()))
        paragraph = target
      }
    }
    try flushParagraph()
  }

  private static func backgroundImageURL(in style: String) -> String? {
    guard let match = backgroundImage.firstMatch(in: style, range: NSRange(style.startIndex..., in: style)),
          let range = Range(match.range(at: 1), in: style)
    else {
      return nil
    }
    return String(style[range])
  }

  private static let backgroundImage = try! NSRegularExpression(pattern: "background-image\\s*:\\s*url\\(\\s*['\"]?([^'\")]+)['\"]?\\s*\\)", options: .caseInsensitive)
}
