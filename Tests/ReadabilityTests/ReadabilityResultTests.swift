// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Readability
import Testing

@Suite("ReadabilityResult")
struct ReadabilityResultTests {
  private func result(publishedTime: String?) -> ReadabilityResult {
    ReadabilityResult(title: "T", content: "<p>ab</p>", textContent: "ab", publishedTime: publishedTime)
  }

  @Test
  func `textLength counts characters of textContent`() {
    let result = ReadabilityResult(title: "T", content: "", textContent: "héllo 👋")
    #expect(result.textLength == 7)
  }

  @Test
  func `publishedDate parses ISO 8601 date-time`() throws {
    let date = try #require(result(publishedTime: "2024-03-05T10:20:30Z").publishedDate)
    #expect(date == Date(timeIntervalSince1970: 1_709_634_030))
  }

  @Test
  func `publishedDate parses fractional seconds and offsets`() throws {
    let date = try #require(result(publishedTime: " 2024-03-05T12:20:30.500+02:00 ").publishedDate)
    #expect(date == Date(timeIntervalSince1970: 1_709_634_030.5))
  }

  @Test
  func `publishedDate parses a date without time`() throws {
    let date = try #require(result(publishedTime: "2024-03-05").publishedDate)
    #expect(date == Date(timeIntervalSince1970: 1_709_596_800))
  }

  @Test(arguments: [nil, "", "March 5, 2024", "yesterday"])
  func `publishedDate is nil for absent or non-ISO values`(value: String?) {
    #expect(result(publishedTime: value).publishedDate == nil)
  }
}
