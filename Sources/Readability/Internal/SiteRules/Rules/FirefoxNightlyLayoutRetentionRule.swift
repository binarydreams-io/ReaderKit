// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Keeps the Firefox Nightly blog's adjacent-posts/comments containers from
/// being stripped as "unlikely candidates" — they sit inside `#comments` or
/// `#adjacent-posts`, ids that collide with the generic unlikely-candidate
/// class/id patterns, but the blog's own `#content` still nests real post
/// links (`article[id^=post-]` linking to bugzilla.mozilla.org or the blog
/// itself) inside them that Mozilla's reference output keeps.
///
/// SiteRule Metadata:
/// - Scope: Firefox Nightly blog adjacent-posts/comments layout
/// - Phase: unlikely-candidate stripping
/// - Trigger: `#comments`/`#adjacent-posts` ancestor with a `#content` container
///   holding `article[id^=post-]` links to bugzilla.mozilla.org/blog.nightly.mozilla.org
/// - Evidence: `realworld/firefox-nightly-blog`
/// - Risk if misplaced: low; narrowly gated by container id chain and link targets
enum FirefoxNightlyLayoutRetentionRule: UnlikelyCandidateRetentionSiteRule {
  static let id = "firefox-nightly-layout-retention"
  static let hosts: [String]? = ["nightly.mozilla.org"]

  static func shouldKeepUnlikelyCandidate(_ element: Element) -> Bool {
    let id = element.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let containerIDs = ["comments", "adjacent-posts"]

    var cursor: Element? = element
    var mainContent: Element?
    var inProtectedContainer = containerIDs.contains(id)

    while let current = cursor {
      let currentID = current.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      if containerIDs.contains(currentID) {
        inProtectedContainer = true
      }
      if currentID == "content",
         ["MAIN", "DIV"].contains(current.tagName().uppercased())
      {
        mainContent = current
        break
      }
      cursor = current.parent()
    }

    guard inProtectedContainer, let mainContent else {
      return false
    }

    return (try? mainContent.select("article[id^=post-] a[href*=\"bugzilla.mozilla.org\"], article[id^=post-] a[href*=\"blog.nightly.mozilla.org\"]").isEmpty()) == false
  }
}
