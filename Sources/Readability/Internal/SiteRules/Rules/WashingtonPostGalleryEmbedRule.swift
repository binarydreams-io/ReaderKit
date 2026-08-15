// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Removes gallery/chrome blocks that are not article body content.
///
/// Named for its original evidence fixture, but genuinely host-independent:
/// `[data-scald-gallery]` is a Drupal Scald-module attribute (not WaPo-specific,
/// Scald is used by multiple news CMSes), and Mozilla's own `test-pages/bug-1255978`
/// fixture — an unrelated, non-WaPo page — needs this exact rule to pass too.
///
/// SiteRule Metadata:
/// - Scope: gallery embed and scald gallery containers
/// - Phase: `unwanted` cleanup
/// - Trigger: `[data-scald-gallery]` and `div[id^=gallery-embed_]`
/// - Evidence: `realworld/wapo-1`, `realworld/wapo-2`, `test-pages/bug-1255978`
/// - Risk if misplaced: interactive gallery chrome remains in extracted content
enum WashingtonPostGalleryEmbedRule: ArticleCleanerSiteRule {
  static let id = "washingtonpost-gallery-embed"
  static let hosts: [String]? = nil

  static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
    // Scald gallery widgets (and companion heading wrappers) are non-article chrome.
    for gallery in try articleContent.select("[data-scald-gallery]") {
      if let parent = gallery.parent(), parent.tagName().lowercased() == "div" {
        try parent.remove()
      } else {
        try gallery.remove()
      }
    }

    // Washington Post gallery embeds are interactive chrome; Mozilla output drops them.
    try articleContent.select("div[id^=gallery-embed_]").remove()
  }
}
