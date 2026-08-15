// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Recovers very short 1A23 gallery pages that Mozilla rejects as unreadable.
///
/// These pages intentionally contain only a featured image and a brief credit/caption
/// paragraph. They fall below Mozilla's global `charThreshold`, but for curated ex-pages
/// we still want the visible reading content.
enum OneA23GalleryShortArticleRule: ShortContentFallbackSiteRule {
  static let id = "1a23-gallery-short-article"
  static let hosts: [String]? = ["1a23.com"]

  static func fallbackArticleContent(in document: Document, sourceURL: URL?) throws -> Element? {
    // `hosts` above already restricts dispatch to 1a23.com (and subdomains); only
    // the path shape still needs checking here.
    guard isOneA23GalleryPath(sourceURL) else {
      return nil
    }

    guard let entryContent = try document.select("div.entry-content").first(),
          let featuredImage = try document.select("figure.wp-block-post-featured-image").first(),
          let leadingParagraph = firstMeaningfulParagraph(in: entryContent)
    else {
      return nil
    }

    let container = try document.createElement("div")
    try container.appendChild(DOMHelpers.cloneElement(featuredImage, in: document))
    try container.appendChild(DOMHelpers.cloneElement(leadingParagraph, in: document))
    return container
  }

  private static func isOneA23GalleryPath(_ sourceURL: URL?) -> Bool {
    let path = sourceURL?.path.lowercased() ?? ""
    return path.contains("/works/gallery/")
  }

  private static func firstMeaningfulParagraph(in entryContent: Element) -> Element? {
    for child in entryContent.children() where child.tagName().lowercased() == "p" {
      let text = ((try? DOMHelpers.getInnerText(child)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty {
        return child
      }
    }
    return nil
  }
}
