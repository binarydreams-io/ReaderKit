// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation
@testable import ReaderKit
import Testing

@Suite("ReaderFetchURL")
struct ReaderFetchURLTests {
  private func rewritten(_ link: String) throws -> String {
    try ReaderFetchURL.fetchURL(for: #require(URL(string: link))).absoluteString
  }

  @Test
  func `A Telegram post link fetches the server-rendered embed`() throws {
    #expect(try rewritten("https://t.me/funky_theresa/1121") == "https://t.me/funky_theresa/1121?embed=1")
  }

  @Test
  func `Preview and telegram.me post links fetch the same embed`() throws {
    #expect(try rewritten("https://t.me/s/funky_theresa/1121") == "https://t.me/funky_theresa/1121?embed=1")
    #expect(try rewritten("https://telegram.me/funky_theresa/1121?single") == "https://t.me/funky_theresa/1121?embed=1")
  }

  @Test
  func `An embed link is already final`() throws {
    #expect(try rewritten("https://t.me/funky_theresa/1121?embed=1") == "https://t.me/funky_theresa/1121?embed=1")
  }

  @Test
  func `Channel, private, invite, and non-Telegram links are untouched`() throws {
    for link in [
      "https://t.me/funky_theresa",
      "https://t.me/s/funky_theresa",
      "https://t.me/c/1072100419/1121",
      "https://t.me/+AbCdEf123",
      "https://t.me/joinchat/AbCdEf123",
      "https://example.com/funky_theresa/1121"
    ] {
      #expect(try rewritten(link) == link)
    }
  }
}
