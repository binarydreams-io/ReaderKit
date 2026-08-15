// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

extension Readability {

  // MARK: - Title Extraction

  func extractTitle() throws -> String {
    var curTitle = ""
    var origTitle = ""

    origTitle = try doc.title().trimmingCharacters(in: .whitespaces)
    curTitle = origTitle

    if curTitle.isEmpty {
      if let h1 = try doc.select("h1").first() {
        return try h1.text().trimmingCharacters(in: .whitespaces)
      }
      return ""
    }

    var titleHadHierarchicalSeparators = false
    let titleSeparators = "|\\-–—\\/»"
    let separatorPattern = "\\s[\(titleSeparators)]\\s"

    if let _ = origTitle.range(of: separatorPattern, options: .regularExpression) {
      titleHadHierarchicalSeparators = origTitle.range(of: "\\s[\\/>»]\\s", options: .regularExpression) != nil

      let regex = try NSRegularExpression(pattern: separatorPattern, options: [.caseInsensitive])
      let matches = regex.matches(in: origTitle, options: [], range: NSRange(location: 0, length: origTitle.utf16.count))

      // NSRegularExpression reports UTF-16 offsets; `Range(_:in:)` converts them to
      // Character-based String.Index safely (String.index(_:offsetBy:) would
      // misplace the split — or trap past endIndex — on titles with non-BMP
      // characters such as emoji, since those take two UTF-16 units but one Character).
      if let lastMatch = matches.last, let lastRange = Range(lastMatch.range, in: origTitle) {
        curTitle = String(origTitle[..<lastRange.lowerBound])
      }

      if wordCount(curTitle) < 3 {
        if let firstMatch = matches.first, let firstRange = Range(firstMatch.range, in: origTitle) {
          curTitle = String(origTitle[firstRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
      }
    } else if curTitle.contains(": ") {
      let headings = try doc.select("h1, h2")
      let trimmedTitle = curTitle.trimmingCharacters(in: .whitespaces)

      var hasExactMatch = false
      for heading in headings {
        let headingText = try heading.text().trimmingCharacters(in: .whitespaces)
        if headingText == trimmedTitle {
          hasExactMatch = true
          break
        }
      }

      if !hasExactMatch {
        if let lastColon = origTitle.lastIndex(of: ":") {
          let afterColon = origTitle.index(after: lastColon)
          curTitle = String(origTitle[afterColon...]).trimmingCharacters(in: .whitespaces)

          if wordCount(curTitle) < 3 {
            if let firstColon = origTitle.firstIndex(of: ":") {
              let afterFirstColon = origTitle.index(after: firstColon)
              curTitle = String(origTitle[afterFirstColon...]).trimmingCharacters(in: .whitespaces)
            }
          } else if let firstColon = origTitle.firstIndex(of: ":"),
                    wordCount(String(origTitle[..<firstColon])) > 5
          {
            curTitle = origTitle
          }
        }
      }
    } else if curTitle.count > 150 || curTitle.count < 15 {
      let hOnes = try doc.select("h1")
      if hOnes.count == 1, let onlyH1 = hOnes.first() {
        curTitle = try onlyH1.text()
      }
    }

    curTitle = curTitle.trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    let curTitleWordCount = wordCount(curTitle)
    if curTitleWordCount <= 4 {
      if !titleHadHierarchicalSeparators {
        curTitle = origTitle
      } else {
        let origWordCount = wordCount(origTitle.replacingOccurrences(of: separatorPattern, with: "", options: .regularExpression, range: nil))
        if curTitleWordCount != origWordCount - 1 {
          curTitle = origTitle
        }
      }
    }

    return curTitle.isEmpty ? origTitle : curTitle
  }

  private func wordCount(_ str: String) -> Int {
    str.components(separatedBy: .whitespacesAndNewlines)
      .count(where: { !$0.isEmpty })
  }
}
