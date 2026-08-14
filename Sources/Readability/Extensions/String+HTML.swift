//
//  String+HTML.swift
//  ReaderKit
//
//  Created by Leonid Frolov on 30.11.2025.
//

import Foundation
import SwiftSoup

extension String {
  /// The visible body text of this string parsed as an HTML document.
  /// - Throws: A SwiftSoup parsing error if the HTML cannot be parsed.
  public func htmlText() throws -> String {
    let document = try SwiftSoup.parse(self)
    return try document.body()?.text() ?? ""
  }

  /// The absolute URLs of every `<img>` in this string parsed as an HTML document.
  /// - Throws: A SwiftSoup parsing error if the HTML cannot be parsed.
  public func htmlImageURLs() throws -> [URL] {
    let document = try SwiftSoup.parse(self)
    let elements = try document.select("img").array()

    return elements.compactMap { element in
      guard let urlString = try? element.absUrl("src"), !urlString.isEmpty else {
        return nil
      }
      return URL(string: urlString)
    }
  }
}
