// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

protocol SiteRule {
  static var id: String { get }

  /// Apex host(s) this rule targets, matched against a document's source host via
  /// `host == apex || host.hasSuffix("." + apex)`. `nil` means the rule is
  /// host-independent by design and should run against every document.
  ///
  /// Every rule declares this explicitly — including `nil` for genuinely generic
  /// rules — so `SiteRuleRegistry` can skip non-matching rules before invoking
  /// them, instead of running all rules against every page and relying on each
  /// rule's own internal content fingerprinting to no-op on the wrong site.
  static var hosts: [String]? { get }
}

enum SiteRuleHostMatching {
  /// `nil` hosts means host-independent; otherwise the document host must
  /// equal an apex or be one of its subdomains.
  static func matches(_ hosts: [String]?, _ host: String?) -> Bool {
    guard let hosts else { return true }
    guard let host = host?.lowercased(), !host.isEmpty else { return false }
    return hosts.contains { apex in
      let apex = apex.lowercased()
      return host == apex || host.hasSuffix(".\(apex)")
    }
  }
}

extension SiteRule {
  /// Whether this rule applies to a document with the given source host.
  /// `host` is typically `sourceURL?.host`, already free of scheme/path/port.
  static func appliesTo(host: String?) -> Bool {
    SiteRuleHostMatching.matches(hosts, host)
  }
}

enum ArticleCleanerSiteRulePhase: String {
  case unwantedElements = "unwanted-elements"
  case preConversion = "pre-conversion"
  case shareCleanup = "share-cleanup"
  case postParagraph = "post-paragraph"
  case postProcess = "post-process"
}

enum SiblingMergeSiteRulePhase: String {
  case leadingAssociatedContent = "leading-associated-content"
  case siblingInclude = "sibling-include"
}

protocol ArticleCleanerSiteRule: SiteRule {
  static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws
}

struct ArticleCleanerSiteRuleContext {
  let getLinkDensity: (Element) throws -> Double
  let setNodeTag: ((Element, String) throws -> Element)?

  init(
    getLinkDensity: @escaping (Element) throws -> Double,
    setNodeTag: ((Element, String) throws -> Element)? = nil
  ) {
    self.getLinkDensity = getLinkDensity
    self.setNodeTag = setNodeTag
  }
}

protocol SerializationSiteRule: SiteRule {
  static func apply(to articleContent: Element) throws
}

protocol BylineSiteRule: SiteRule {
  static func apply(byline: String?, sourceURL: URL?, document: Document) throws -> String?
}

protocol MetadataBylineSiteRule: SiteRule {
  static func apply(currentByline: String?, sourceURL: URL?, document: Document) throws -> String?
}

protocol ExcerptSiteRule: SiteRule {
  static func apply(currentExcerpt: String?, articleContent: Element, sourceURL: URL?, document: Document) throws -> String?
}

/// Allows narrow site rules to accept intentionally image-only article content
/// after cleanup instead of retrying into unrelated surrounding chrome.
protocol TextlessArticleContentSiteRule: SiteRule {
  static func shouldKeepTextlessArticleContent(_ articleContent: Element, sourceURL: URL?, document: Document) throws -> Bool
}

protocol ShortContentFallbackSiteRule: SiteRule {
  static func fallbackArticleContent(in document: Document, sourceURL: URL?) throws -> Element?
}

protocol CandidatePromotionSiteRule: SiteRule {
  static func promotedCandidate(from candidate: Element) -> Element?
}

protocol CandidateProtectionSiteRule: SiteRule {
  static func shouldKeepCandidate(_ current: Element) -> Bool
}

protocol BylineContainerRetentionSiteRule: SiteRule {
  static func shouldKeepBylineContainer(_ node: Element, sourceURL: URL?, document: Document) throws -> Bool
}

/// Protects a node from removal as an "unlikely candidate" during early
/// stripping, based on structural/content signals beyond the generic
/// class/id pattern matching that `NodeCleaner` applies to every element.
protocol UnlikelyCandidateRetentionSiteRule: SiteRule {
  static func shouldKeepUnlikelyCandidate(_ element: Element) -> Bool
}

/// Keeps a heading that would otherwise be removed as a duplicate of the
/// article title, when a site's compact headline+timestamp header structure
/// needs a stronger, site-specific signal than the generic itemprop/time checks.
protocol HeadlineTimestampRetentionSiteRule: SiteRule {
  static func shouldPreserveHeadlineTimestampBlock(_ header: Element) -> Bool
}

/// Rescues content out of a container just before it's removed as an explicit
/// no-content wrapper (see `ArticleCleaner.removeExplicitNoContentContainers`),
/// when a site's markup nests something worth keeping inside such a wrapper.
protocol NoContentContainerRescueSiteRule: SiteRule {
  static func rescue(from container: Element) throws
}

/// Allows a site rule to force-include a sibling of the top candidate.
/// Return `true` to include, `false` to exclude, `nil` to defer to default logic.
protocol SiblingInclusionSiteRule: SiteRule {
  static func shouldIncludeSibling(_ sibling: Element, topCandidate: Element) throws -> Bool?
}

/// Allows a site rule to extract a sub-element from a sibling and include only that sub-element.
/// If a rule returns a non-nil element, the full sibling is skipped and the extracted element is
/// appended to article content instead. Return `nil` to defer to default logic.
protocol SiblingExtractSiteRule: SiteRule {
  static func extractFromSibling(_ sibling: Element, topCandidate: Element) throws -> SiblingExtractionElement?
}

/// Result of extracting a sub-element from a sibling.
///
/// `preserveAsIs` tells `SiblingMerger` to keep the element's tag as returned
/// (skipping the usual DIV normalization applied to appended siblings) instead
/// of the rule having to signal that by writing a throwaway CSS class into the
/// DOM for `SiblingMerger` to sniff and strip back out later.
struct SiblingExtractionElement {
  let element: Element
  let preserveAsIs: Bool

  init(_ element: Element, preserveAsIs: Bool = false) {
    self.element = element
    self.preserveAsIs = preserveAsIs
  }
}

/// Runs before candidate scoring to prune known noise containers from the document.
///
/// Use this when a platform-specific comment or discussion module must be removed
/// before any extraction pass runs. Unlike `ArticleCleanerSiteRule` (which operates
/// on already-extracted content), rules of this type modify the document in place
/// so the noise never enters the candidate pool.
protocol PreExtractionDocumentRule: SiteRule {
  static func apply(to document: Document, sourceURL: URL?) throws
}
