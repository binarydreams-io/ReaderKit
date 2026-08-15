// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Preserves NYTimes-style "Continue reading the main story" jump links that
/// are nested inside an ad/nocontent wrapper about to be removed by
/// `ArticleCleaner.removeExplicitNoContentContainers`.
///
/// SiteRule Metadata:
/// - Scope: NYTimes article "story-continues" jump links
/// - Phase: unwanted-container removal (rescue-before-delete)
/// - Trigger: `a[href^=#story-continues-]` inside a container about to be
///   dropped as explicit no-content, gated by the container's own/parent id
/// - Evidence: NYTimes real-world fixtures
enum NYTimesStoryContinueLinkRescueRule: NoContentContainerRescueSiteRule {
  static let id = "nytimes-story-continue-link-rescue"
  static let hosts: [String]? = ["nytimes.com"]

  static func rescue(from container: Element) throws {
    guard let parent = container.parent() else { return }
    let doc = parent.ownerDocument() ?? Document("")
    let parentID = parent.id().lowercased()
    let parentClass = ((try? parent.className()) ?? "").lowercased()
    let parentSignature = "\(parentID) \(parentClass)"
    let hasInterrupter = (try? doc.select("div#story-continues-1").isEmpty()) == false

    let links = try container.select("a[href^=#story-continues-]")
    guard !links.isEmpty() else { return }

    for link in links {
      let href = (try? link.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
      let shouldRescue: Bool = if parentID == "story-continues-1" {
        href == "#story-continues-2"
      } else if hasInterrupter, parentSignature.contains("story-body") {
        href == "#story-continues-1"
      } else {
        false
      }
      guard shouldRescue else { continue }
      let text = ((try? DOMHelpers.getInnerText(link)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { continue }

      let p = try doc.createElement("p")
      let a = try doc.createElement("a")
      try a.attr("href", href)
      try a.text(text)
      try p.appendChild(a)
      try container.before(p)
      return
    }
  }
}
