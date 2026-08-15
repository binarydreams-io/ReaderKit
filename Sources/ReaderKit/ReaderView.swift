// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

//
//  ReaderView.swift
//  ReaderKit
//
//  Created by Leonid Frolov on 02.12.2025.
//

import OSLog
import Readability
import RichText
import SwiftUI

/// Loads the article at `link`, extracts its readable content with Readability,
/// and renders it natively (no WebKit). Pass `style` to apply the reading theme,
/// font, and size — changing it re-renders without re-fetching or re-parsing.
public struct ReaderView: View {
  let link: URL
  let style: ReaderStyle
  @State private var blocks: [ArticleBlock] = []
  @State private var isLoading = true

  public init(link: URL, style: ReaderStyle = .init()) {
    self.link = link
    self.style = style
  }

  public var body: some View {
    Group {
      if !blocks.isEmpty {
        RichTextView(blocks: blocks, style: style)
      } else if isLoading {
        VStack {
          ProgressView()
          Text("Article is loading...", bundle: .module)
        }
        .foregroundStyle(style.secondaryTextColor)
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical)
      } else {
        ContentUnavailableView {
          Label {
            Text("Article not found", bundle: .module)
          } icon: {
            Image(systemName: "doc.questionmark")
          }
        }
        .foregroundStyle(style.secondaryTextColor)
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical)
      }
    }
    .task(id: link) {
      isLoading = true
      blocks = []
      do {
        blocks = try await Self.fetchAndParse(from: link)
        isLoading = false
      } catch is CancellationError {
        // Superseded by a newer task (the link changed); leave the loading
        // state for that task so the reader doesn't flash "not found".
      } catch {
        Logger.parser.error("Failed to parse content from \(link): \(error)")
        isLoading = false
      }
    }
  }
}

extension ReaderView {
  @concurrent
  fileprivate nonisolated static func fetchAndParse(from url: URL) async throws -> [ArticleBlock] {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let html = decodeHTML(data: data, response: response) else {
      throw ReadabilityError.invalidHTML
    }

    let readability = try Readability(html: html, baseURL: url)
    let readable = try readability.extractContent()
    return try RichText(content: readable.content, baseURL: url).blocks()
  }

  /// Decodes fetched page bytes to text, since legacy sites still ship
  /// windows-1251/shift_jis/gb2312/etc. rather than UTF-8. Tries, in order:
  /// the server-declared `Content-Type` charset, a sniffed `<meta charset>`
  /// (safe to look for in a Latin-1 decode of a prefix, since the meta tag
  /// itself is always ASCII regardless of the document's real encoding),
  /// then UTF-8, then Latin-1 as a last-resort decode that never fails.
  fileprivate nonisolated static func decodeHTML(data: Data, response: URLResponse) -> String? {
    if let name = (response as? HTTPURLResponse)?.textEncodingName,
       let encoding = stringEncoding(fromIANACharSetName: name),
       let html = String(data: data, encoding: encoding)
    {
      return html
    }

    if let prefix = String(data: data.prefix(4096), encoding: .isoLatin1),
       let sniffedName = sniffedMetaCharset(in: prefix),
       let encoding = stringEncoding(fromIANACharSetName: sniffedName),
       let html = String(data: data, encoding: encoding)
    {
      return html
    }

    return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
  }

  fileprivate nonisolated static func stringEncoding(fromIANACharSetName name: String) -> String.Encoding? {
    let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
    guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
    return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
  }

  fileprivate nonisolated static func sniffedMetaCharset(in headPrefix: String) -> String? {
    let pattern = "<meta[^>]+charset\\s*=\\s*[\"']?\\s*([a-zA-Z0-9_\\-]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
    let range = NSRange(headPrefix.startIndex..., in: headPrefix)
    guard let match = regex.firstMatch(in: headPrefix, options: [], range: range),
          match.numberOfRanges > 1,
          let charsetRange = Range(match.range(at: 1), in: headPrefix)
    else {
      return nil
    }
    return String(headPrefix[charsetRange])
  }
}
