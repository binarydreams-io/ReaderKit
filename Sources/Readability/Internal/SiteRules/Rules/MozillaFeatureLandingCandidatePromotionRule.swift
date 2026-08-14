import Foundation
import SwiftSoup

/// Promotes tiny inner candidates to the semantic `<main>` ancestor on Mozilla's
/// Firefox feature-landing pages, where generic scoring finds a small fragment
/// of a much larger `<main>` that holds multiple substantial content blocks
/// (the real page content).
///
/// SiteRule Metadata:
/// - Scope: mozilla.org Firefox feature-landing pages
/// - Phase: candidate promotion
/// - Trigger: `<main>` ancestor containing a "features and tools" h2, or an
///   "important: sync your new profile" h4 — both first-run/upsell headings
///   unique to these landing pages
/// - Evidence: `realworld/mozilla-2`
/// - Risk if misplaced: low; gated by exact heading text plus a text-share and
///   sibling-count shape check
enum MozillaFeatureLandingCandidatePromotionRule: CandidatePromotionSiteRule {
  static let id = "mozilla-feature-landing-candidate"
  static let hosts: [String]? = ["mozilla.org"]

  static func promotedCandidate(from candidate: Element) -> Element? {
    guard let semanticMain = nearestMainAncestor(of: candidate),
          hasQualifyingHeading(in: semanticMain)
    else {
      return nil
    }

    let candidateTextLength = (try? DOMHelpers.getInnerText(candidate).count) ?? 0
    let mainTextLength = (try? DOMHelpers.getInnerText(semanticMain).count) ?? 0
    guard candidateTextLength > 0,
          mainTextLength > candidateTextLength,
          Double(candidateTextLength) / Double(mainTextLength) < 0.7
    else {
      return nil
    }

    let meaningfulChildCount = semanticMain.children().array().reduce(into: 0) { count, child in
      let tag = child.tagName().uppercased()
      guard ["ARTICLE", "SECTION", "DIV"].contains(tag) else { return }
      let textLength = (try? DOMHelpers.getInnerText(child).count) ?? 0
      if textLength >= 140 {
        count += 1
      }
    }
    guard meaningfulChildCount >= 2 else { return nil }

    return semanticMain
  }

  private static func nearestMainAncestor(of element: Element) -> Element? {
    element.ancestors().first { $0.tagName().uppercased() == "MAIN" }
  }

  private static func hasQualifyingHeading(in main: Element) -> Bool {
    let hasFeatureHeading = (try? main.select("h2").array().contains {
      let text = ((try? $0.text()) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      return text == "features and tools"
    }) == true
    let hasSyncNoticeHeading = (try? main.select("h4").array().contains {
      let text = ((try? $0.text()) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      return text == "important: sync your new profile"
    }) == true
    return hasFeatureHeading || hasSyncNoticeHeading
  }
}
