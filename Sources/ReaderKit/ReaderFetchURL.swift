// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation

/// Picks the URL to download for a link whose own page does not carry the
/// readable content.
enum ReaderFetchURL {
  /// A Telegram post page (`t.me/<channel>/<id>`) ships an empty shell and
  /// injects the message with a script; the `?embed=1` variant of the same
  /// path is the server-rendered post. Channel pages, private (`/c/…`) and
  /// invite links, and everything off Telegram come back unchanged.
  static func fetchURL(for link: URL) -> URL {
    guard let host = link.host()?.lowercased(), host == "t.me" || host == "telegram.me" else {
      return link
    }
    var segments = link.pathComponents.filter { $0 != "/" }
    if segments.first == "s" {
      segments.removeFirst()
    }
    guard segments.count == 2,
          let channel = segments.first, !channel.isEmpty,
          channel != "c", channel != "joinchat", !channel.hasPrefix("+"),
          Int(segments[1]) != nil
    else {
      return link
    }

    var components = URLComponents()
    components.scheme = "https"
    components.host = "t.me"
    components.path = "/\(channel)/\(segments[1])"
    components.queryItems = [URLQueryItem(name: "embed", value: "1")]
    return components.url ?? link
  }
}
