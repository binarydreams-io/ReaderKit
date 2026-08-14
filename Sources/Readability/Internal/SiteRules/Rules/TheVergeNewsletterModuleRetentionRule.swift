import Foundation
import SwiftSoup

/// Keeps The Verge's inline paid-newsletter module from being stripped as an
/// "unlikely candidate" — its wrapper class collides with the generic
/// "newsletter" pattern, but Mozilla's reference output keeps it when it
/// carries real checkout links (i.e. it's the paid-plan upsell, not chrome).
///
/// SiteRule Metadata:
/// - Scope: The Verge inline newsletter/subscription module
/// - Phase: unlikely-candidate stripping
/// - Trigger: `.newsletter-wrapper` with ≥2 links to
///   `subs.theverge.com/checkout?plan=`
/// - Evidence: `realworld/theverge`
/// - Risk if misplaced: low; requires the checkout-link count, not just the class
enum TheVergeNewsletterModuleRetentionRule: UnlikelyCandidateRetentionSiteRule {
  static let id = "theverge-newsletter-module-retention"
  static let hosts: [String]? = ["theverge.com"]

  static func shouldKeepUnlikelyCandidate(_ element: Element) -> Bool {
    let className = ((try? element.className()) ?? "").lowercased()
    guard className.contains("newsletter-wrapper") else {
      return false
    }

    // Avoid broad newsletter exceptions by requiring The Verge's checkout links.
    let checkoutLinks = (try? element.select("a[href*=\"subs.theverge.com/checkout?plan=\"]").count) ?? 0
    return checkoutLinks >= 2
  }
}
