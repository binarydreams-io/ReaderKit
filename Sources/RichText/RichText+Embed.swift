// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftSoup

extension RichText {
  func embedBlock(from element: Element) throws -> ArticleBlock? {
    var src = ((try? element.absUrl("src")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if src.isEmpty, element.tagName().lowercased() == "video" {
      src = ((try? element.select("source").first()?.absUrl("src")) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard !src.isEmpty, let url = URL(string: src) else { return nil }

    let title = (try? element.attr("title")).flatMap { $0.isEmpty ? nil : $0 }

    if element.tagName().lowercased() == "video" || isVideoURL(src) {
      let poster = youTubePosterURL(from: url)
        ?? ((try? element.absUrl("poster")).flatMap { $0.isEmpty ? nil : URL(string: $0) })
      return .embed(ArticleEmbed(url: url, kind: .video(posterURL: poster), title: title))
    }
    return .embed(ArticleEmbed(url: url, kind: .link, title: title))
  }

  func isVideoURL(_ src: String) -> Bool {
    src.range(of: Self.defaultVideoRegex, options: .regularExpression) != nil
  }

  /// Mirrors `Readability`'s `Configuration.defaultVideoRegex`. Duplicated rather
  /// than imported so `RichText` stays independent of the `Readability` target.
  fileprivate static let defaultVideoRegex = "\\/\\/(www\\.)?((dailymotion|youtube|youtube-nocookie|player\\.vimeo|v\\.qq|bilibili|live.bilibili)\\.com|youtu\\.be|(archive|upload\\.wikimedia)\\.org|player\\.twitch\\.tv)"

  func youTubePosterURL(from url: URL) -> URL? {
    guard let host = url.host?.lowercased() else { return nil }
    var videoID: String?
    if host.contains("youtu.be") {
      videoID = url.pathComponents.dropFirst().first
    } else if host.contains("youtube") {
      if url.path.contains("/embed/") {
        videoID = url.pathComponents.last
      } else if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "v" })?.value
      {
        videoID = query
      }
    }
    guard let id = videoID, !id.isEmpty else { return nil }
    return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
  }
}
