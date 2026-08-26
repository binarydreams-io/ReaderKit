// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

enum SiteRuleRegistry {
  /// One position in an article-cleaner phase list: either a bespoke rule
  /// type or a data-driven `DeclarativeSiteRule`. Both kinds are interleaved
  /// in the same ordered table because phase order is significant.
  enum ArticleCleanerRuleEntry {
    case bespoke(ArticleCleanerSiteRule.Type)
    case declarative(DeclarativeSiteRule)

    func appliesTo(host: String?) -> Bool {
      switch self {
      case let .bespoke(type): type.appliesTo(host: host)
      case let .declarative(rule): rule.appliesTo(host: host)
      }
    }

    func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
      switch self {
      case let .bespoke(type): try type.apply(to: articleContent, context: context)
      case let .declarative(rule): try rule.apply(to: articleContent)
      }
    }
  }

  struct SiblingInclusionDecision {
    let ruleID: String
    let include: Bool
  }

  struct SiblingExtractionResult {
    let ruleID: String
    let element: Element
    let preserveAsIs: Bool
  }

  /// Resolves the best-effort source host used for rule host-gating: prefers
  /// the caller-supplied `sourceURL`, then falls back — in order — to
  /// SwiftSoup's own `document.location()` (the base URI a document was
  /// parsed with), `<link rel=canonical>`, and `<meta property=og:url>`.
  ///
  /// Callers commonly parse HTML without a real fetch URL (e.g. from a cache),
  /// and several rules already replicated exactly these fallbacks internally
  /// as their own ad hoc host check (`document.location()` in particular is
  /// already how `XeiasoArticleRule`/`BreitbartArticleCandidatePromotionRule`
  /// self-gate). Doing it once here lets host-gating see the same host those
  /// rules would have found anyway.
  static func resolveHost(sourceURL: URL?, document: Document?) -> String? {
    if let host = sourceURL?.host, !host.isEmpty {
      return host
    }
    guard let document else { return nil }
    if let host = URL(string: document.location())?.host, !host.isEmpty {
      return host
    }
    if let canonical = try? document.select("link[rel=canonical]").first()?.attr("href"),
       let host = URL(string: canonical)?.host, !host.isEmpty
    {
      return host
    }
    if let ogURL = try? document.select("meta[property=og:url]").first()?.attr("content"),
       let host = URL(string: ogURL)?.host, !host.isEmpty
    {
      return host
    }
    return nil
  }

  static func applyArticleCleanerRules(
    _ rules: [ArticleCleanerRuleEntry],
    to articleContent: Element,
    context: ArticleCleanerSiteRuleContext,
    host: String?
  ) throws {
    for rule in rules where rule.appliesTo(host: host) {
      try rule.apply(to: articleContent, context: context)
    }
  }

  static func applyPreExtractionDocumentRules(
    to document: Document,
    sourceURL: URL?
  ) throws {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [PreExtractionDocumentRule.Type] = [
      StandardDiscussionModuleRule.self,
      XeiasoArticleRule.self,
      TelegramPostRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      try rule.apply(to: document, sourceURL: sourceURL)
    }
  }

  static func applySerializationRules(to articleContent: Element, sourceURL: URL?) throws {
    let host = resolveHost(sourceURL: sourceURL, document: articleContent.ownerDocument())
    let rules: [SerializationSiteRule.Type] = [
      AntirezProsePreRule.self,
      OneA23GalleryWrapperRule.self,
      MksiteLeadImageFigureRule.self,
      TelegraphCaptionOnlyFigureRule.self,
      CityLabHeadlineTimestampRule.self,
      BuzzFeedLeadImageSuperlistRule.self,
      ArsIntroHeaderWrapperRule.self,
      FirefoxNightlyHeaderPlaceholderRule.self,
      WikipediaGovernmentPortraitCaptionRule.self,
      WikipediaMathDisplayBlockRule.self,
      EHowFoundHelpfulHeaderRule.self,
      QQVoteContainerRule.self,
      BreitbartHeaderMediaRule.self,
      QuantaTopReactIDRule.self,
      HukumusumeLegacyFileURLRule.self,
      XkcdComicImageSourceRule.self,
      XeiasoArticleRule.self,
      NYTimesSplitPrintInfoSerializationRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      try rule.apply(to: articleContent)
    }
  }

  static func applyBylineRules(
    _ byline: String?,
    sourceURL: URL?,
    document: Document
  ) throws -> String? {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [BylineSiteRule.Type] = [
      WebMDBylineRule.self,
      QuantaBylineDateRule.self,
      HeraldSunUppercaseBylineRule.self,
      YahooBylineTimeRule.self,
      RoyalRoadFollowAuthorBylineRule.self,
      TumblrBlogHandleBylineRule.self,
      WikiaBylineTimeSuffixRule.self,
      XkcdBylineRule.self
    ]
    var current = byline
    for rule in rules where rule.appliesTo(host: host) {
      current = try rule.apply(byline: current, sourceURL: sourceURL, document: document)
    }
    return current
  }

  static func applyMetadataBylineRules(
    _ byline: String?,
    sourceURL: URL?,
    document: Document
  ) throws -> String? {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [MetadataBylineSiteRule.Type] = [
      AntirezBylineRule.self,
      FirefoxNightlyBylineRule.self,
      TelegramPostRule.self
    ]
    var current = byline
    for rule in rules where rule.appliesTo(host: host) {
      current = try rule.apply(currentByline: current, sourceURL: sourceURL, document: document)
    }
    return current
  }

  static func applyExcerptRules(
    _ excerpt: String?,
    articleContent: Element,
    sourceURL: URL?,
    document: Document
  ) throws -> String? {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [ExcerptSiteRule.Type] = [
      AntirezExcerptRule.self,
      XkcdComicExcerptRule.self
    ]
    var current = excerpt
    for rule in rules where rule.appliesTo(host: host) {
      current = try rule.apply(
        currentExcerpt: current,
        articleContent: articleContent,
        sourceURL: sourceURL,
        document: document
      )
    }
    return current
  }

  static func shouldKeepTextlessArticleContent(
    _ articleContent: Element,
    sourceURL: URL?,
    document: Document
  ) throws -> Bool {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [TextlessArticleContentSiteRule.Type] = [
      XkcdTextlessComicContentRule.self,
      TelegramPostRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if try rule.shouldKeepTextlessArticleContent(articleContent, sourceURL: sourceURL, document: document) {
        return true
      }
    }
    return false
  }

  static func shortContentFallbackArticle(
    in document: Document,
    sourceURL: URL?,
    inspectionContext: InspectionContext? = nil
  ) throws -> Element? {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [ShortContentFallbackSiteRule.Type] = [
      OneA23GalleryShortArticleRule.self,
      XeiasoArticleRule.self,
      TelegramPostRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if let fallback = try rule.fallbackArticleContent(in: document, sourceURL: sourceURL) {
        inspectionContext?.recordSiteRuleDecision(
          phase: "short-content-fallback",
          ruleID: rule.id,
          target: fallback,
          action: "recover",
          reason: "site-specific-short-article"
        )
        return fallback
      }
    }
    return nil
  }

  static func promotedCandidate(from candidate: Element, sourceURL: URL?) -> Element? {
    let host = resolveHost(sourceURL: sourceURL, document: candidate.ownerDocument())
    let rules: [CandidatePromotionSiteRule.Type] = [
      XkcdComicCandidateRule.self,
      QuantaLeadCandidatePromotionRule.self,
      BreitbartArticleCandidatePromotionRule.self,
      FirefoxNightlyContainerCandidatePromotionRule.self,
      CityLabArticleContainerCandidateRule.self,
      XeiasoArticleRule.self,
      SimonWillisonBeatCandidatePromotionRule.self,
      DevBlogsArticleCandidateRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if let promoted = rule.promotedCandidate(from: candidate) {
        return promoted
      }
    }
    return nil
  }

  static func shouldKeepCandidate(_ current: Element, sourceURL: URL?) -> Bool {
    let host = resolveHost(sourceURL: sourceURL, document: current.ownerDocument())
    let rules: [CandidateProtectionSiteRule.Type] = [
      CityLabArticleContainerCandidateRule.self,
      MacRumorsMainContentCandidateRule.self,
      XeiasoArticleRule.self,
      NYTimesArticleStoryCandidateProtectionRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) && rule.shouldKeepCandidate(current) {
      return true
    }
    return false
  }

  static func shouldKeepBylineContainer(
    _ node: Element,
    sourceURL: URL?,
    document: Document
  ) throws -> Bool {
    let host = resolveHost(sourceURL: sourceURL, document: document)
    let rules: [BylineContainerRetentionSiteRule.Type] = [
      EHowAuthorProfileBylineRetentionRule.self,
      WebMDAuthorBylineRetentionRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if try rule.shouldKeepBylineContainer(node, sourceURL: sourceURL, document: document) {
        return true
      }
    }
    return false
  }

  static func shouldKeepUnlikelyCandidate(_ element: Element, sourceURL: URL?) -> Bool {
    let host = resolveHost(sourceURL: sourceURL, document: element.ownerDocument())
    let rules: [UnlikelyCandidateRetentionSiteRule.Type] = [
      FirefoxNightlyLayoutRetentionRule.self,
      TheVergeNewsletterModuleRetentionRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if rule.shouldKeepUnlikelyCandidate(element) {
        return true
      }
    }
    return false
  }

  static func shouldPreserveHeadlineTimestampBlock(_ header: Element, sourceURL: URL?) -> Bool {
    let host = resolveHost(sourceURL: sourceURL, document: header.ownerDocument())
    let rules: [HeadlineTimestampRetentionSiteRule.Type] = [
      CityLabHeadlineTimestampRetentionRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if rule.shouldPreserveHeadlineTimestampBlock(header) {
        return true
      }
    }
    return false
  }

  static func rescueFromNoContentContainer(_ container: Element, sourceURL: URL?) throws {
    let host = resolveHost(sourceURL: sourceURL, document: container.ownerDocument())
    let rules: [NoContentContainerRescueSiteRule.Type] = [
      NYTimesStoryContinueLinkRescueRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      try rule.rescue(from: container)
    }
  }

  static func applyUnwantedElementRules(
    to articleContent: Element,
    context: ArticleCleanerSiteRuleContext,
    sourceURL: URL?
  ) throws {
    try applyArticleCleanerRules(phase: .unwantedElements, to: articleContent, context: context, sourceURL: sourceURL)
  }

  static func applyArticleCleanerRules(
    phase: ArticleCleanerSiteRulePhase,
    to articleContent: Element,
    context: ArticleCleanerSiteRuleContext,
    sourceURL: URL?
  ) throws {
    let host = resolveHost(sourceURL: sourceURL, document: articleContent.ownerDocument())
    try applyArticleCleanerRules(
      articleCleanerRules(for: phase),
      to: articleContent,
      context: context,
      host: host
    )
  }

  private static func articleCleanerRules(for phase: ArticleCleanerSiteRulePhase) -> [ArticleCleanerRuleEntry] {
    switch phase {
    case .unwantedElements:
      [
        .declarative(DeclarativeSiteRules.antirezDisqusFooter),
        .bespoke(AntirezLeadingInfoRule.self),
        .bespoke(WashingtonPostGalleryEmbedRule.self),
        .declarative(DeclarativeSiteRules.yahooSlideshowModal),
        .bespoke(YahooBreakingNewsModuleRule.self),
        .declarative(DeclarativeSiteRules.bbcVideoPlaceholder),
        .declarative(DeclarativeSiteRules.aktualneTwitterEmbed),
        .declarative(DeclarativeSiteRules.aktualneInlinePhoto),
        .declarative(DeclarativeSiteRules.qqSharePanel),
        .declarative(DeclarativeSiteRules.heraldSunReadMoreLink),
        .declarative(DeclarativeSiteRules.liberationRelatedAside),
        .declarative(DeclarativeSiteRules.liberationAuthorsContainer),
        .declarative(DeclarativeSiteRules.nytimesLivePanels),
        .bespoke(SeattleTimesSectionRailRule.self),
        .bespoke(NYTimesContinueReadingWrapperRule.self),
        .bespoke(WashingtonPostViewGraphicPromoRule.self),
        .declarative(DeclarativeSiteRules.cnnLegacyStoryTop),
        .declarative(DeclarativeSiteRules.medicalNewsTodayRelatedInline),
        .bespoke(CNETPlaylistOverlayRule.self),
        .declarative(DeclarativeSiteRules.cityLabPromoSignup),
        .bespoke(MacRumorsArticleChromeRule.self),
        .bespoke(BerthubNavigationChromeRule.self),
        .bespoke(EngadgetSlideshowIconRule.self),
        .declarative(DeclarativeSiteRules.wikipediaLeadMetaNoise),
        .bespoke(MksiteLeadingPublicationRule.self),
        .declarative(DeclarativeSiteRules.firefoxNightlyCommentForm),
        .bespoke(SubstackDiscussionFooterRule.self),
        .bespoke(MozillaCustomizeSyncSectionRule.self),
        .bespoke(EHowAuthorProfileRule.self),
        .bespoke(FabienSanglardLeadingChromeRule.self),
        .declarative(DeclarativeSiteRules.simplyFoundMediaContainer),
        .bespoke(FolhaGalleryWidgetRule.self),
        .declarative(DeclarativeSiteRules.pixnetArticleKeyword),
        .bespoke(WebMDReviewedByRule.self)
      ]
    case .preConversion:
      [
        .bespoke(NYTimesRelatedLinkCardsRule.self),
        .bespoke(SubstackInlineButtonCTARule.self)
      ]
    case .shareCleanup:
      [
        .bespoke(GuardianShareElementsRule.self)
      ]
    case .postParagraph:
      [
        .bespoke(NYTimesSplitPrintInfoRule.self)
      ]
    case .postProcess:
      [
        .bespoke(NYTimesCollectionHighlightsRule.self),
        .bespoke(NYTimesSpanishCardSummaryRule.self),
        .declarative(DeclarativeSiteRules.nytimesPhotoViewerWrapper),
        .declarative(DeclarativeSiteRules.engadgetBuyLink),
        .bespoke(EngadgetBreakoutTypeRule.self),
        .bespoke(EngadgetReviewSummaryWrapperRule.self),
        .bespoke(YahooStoryContainerRule.self),
        .bespoke(CityLabPromoSummarySectionRule.self),
        .bespoke(TheVergeZoomWrapperAccessibilityRule.self),
        .declarative(DeclarativeSiteRules.liberationArticleBodyWrapper),
        .bespoke(DFarqShareAuthorTailRule.self),
        .bespoke(SubstackTwitterEmbedRule.self),
        .bespoke(XeiasoArticleRule.self),
        .bespoke(WordPressPrevNextNavigationRule.self),
        .bespoke(JohnDCookRelatedPostsRule.self),
        .declarative(DeclarativeSiteRules.mercurialExampleSection),
        .bespoke(SimonWillisonRecentArticlesRule.self),
        .bespoke(TomRennerTagListRule.self),
        .bespoke(WikipediaHermitianListPruneRule.self),
        .declarative(DeclarativeSiteRules.ebbPreviousLink),
        .bespoke(XkcdComicChromeCleanupRule.self)
      ]
    }
  }

  /// Returns the explicit sibling inclusion decision, if any site rule produced one.
  static func siblingInclusionDecision(
    _ sibling: Element,
    topCandidate: Element,
    sourceURL: URL?,
    inspectionContext: InspectionContext? = nil
  ) throws -> SiblingInclusionDecision? {
    let host = resolveHost(sourceURL: sourceURL, document: topCandidate.ownerDocument() ?? sibling.ownerDocument())
    let rules: [SiblingInclusionSiteRule.Type] = [
      XkcdFooterSiblingRule.self,
      WordPressFeaturedImageRule.self,
      SeanGoedeckePostFooterRule.self,
      GhostArticleChromeRule.self,
      DevBlogsPostFooterRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if let decision = try rule.shouldIncludeSibling(sibling, topCandidate: topCandidate) {
        inspectionContext?.recordSiteRuleDecision(
          phase: SiblingMergeSiteRulePhase.siblingInclude.rawValue,
          ruleID: rule.id,
          target: sibling,
          action: decision ? "include" : "exclude",
          reason: "explicit-decision"
        )
        return SiblingInclusionDecision(ruleID: rule.id, include: decision)
      }
    }
    return nil
  }

  /// Returns an extracted sub-element from the sibling if any site rule wants to extract one.
  /// When non-nil is returned, the caller should append the returned element and skip the original sibling.
  static func siblingExtraction(
    _ sibling: Element,
    topCandidate: Element,
    sourceURL: URL?,
    inspectionContext: InspectionContext? = nil
  ) throws -> SiblingExtractionResult? {
    let host = resolveHost(sourceURL: sourceURL, document: topCandidate.ownerDocument() ?? sibling.ownerDocument())
    let rules: [SiblingExtractSiteRule.Type] = [
      WordPressFeaturedImageExtractRule.self
    ]
    for rule in rules where rule.appliesTo(host: host) {
      if let extracted = try rule.extractFromSibling(sibling, topCandidate: topCandidate) {
        inspectionContext?.recordSiteRuleDecision(
          phase: SiblingMergeSiteRulePhase.leadingAssociatedContent.rawValue,
          ruleID: rule.id,
          target: sibling,
          action: "extract",
          result: extracted.element,
          reason: "sub-element-extracted"
        )
        return SiblingExtractionResult(ruleID: rule.id, element: extracted.element, preserveAsIs: extracted.preserveAsIs)
      }
    }
    return nil
  }
}
