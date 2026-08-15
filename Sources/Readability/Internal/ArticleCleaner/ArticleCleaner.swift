// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Cleans and prepares article content after extraction
/// Implements Mozilla Readability.js _prepArticle and related methods
final class ArticleCleaner {
  let options: ReadabilityOptions
  private let allowConditionalCleaning: Bool
  let allowWeightClasses: Bool
  private let debugSnapshot: ((String, Element) -> Void)?
  let sourceURL: URL?
  var dataTableNodeIDs: Set<ObjectIdentifier> = []

  init(
    options: ReadabilityOptions,
    allowConditionalCleaning: Bool = true,
    allowWeightClasses: Bool = true,
    sourceURL: URL? = nil,
    debugSnapshot: ((String, Element) -> Void)? = nil
  ) {
    self.options = options
    self.allowConditionalCleaning = allowConditionalCleaning
    self.allowWeightClasses = allowWeightClasses
    self.sourceURL = sourceURL
    self.debugSnapshot = debugSnapshot
  }

  var siteRuleContext: ArticleCleanerSiteRuleContext {
    ArticleCleanerSiteRuleContext(
      getLinkDensity: getLinkDensity,
      setNodeTag: { [self] element, tag in
        try setNodeTag(element, newTag: tag)
      }
    )
  }

  // MARK: - Main Article Preparation

  /// Prepare article content for output
  /// This is the main entry point for article cleaning
  func prepArticle(_ articleContent: Element) throws {
    dataTableNodeIDs.removeAll(keepingCapacity: true)

    // Remove unwanted elements FIRST (before cleanStyles removes class attributes)
    try removeUnwantedElements(articleContent)
    debugSnapshot?("prep.removeUnwantedElements", articleContent)

    // Preserve floated inline images as standalone blocks before styles are stripped.
    try promoteFloatedInlineImagesToFigures(articleContent)
    debugSnapshot?("prep.promoteFloatedInlineImages", articleContent)

    // Clean styles
    try cleanStyles(articleContent)
    debugSnapshot?("prep.cleanStyles", articleContent)

    // Match Mozilla _prepArticle data-table protection before conditional cleanup.
    try markDataTables(articleContent)
    debugSnapshot?("prep.markDataTables", articleContent)

    // Fix lazy images
    try fixLazyImages(articleContent)
    debugSnapshot?("prep.fixLazyImages", articleContent)

    // Match Mozilla _prepArticle conditional cleanup only when
    // FLAG_CLEAN_CONDITIONALLY is still active for the accepted pass.
    if allowConditionalCleaning {
      try cleanConditionally(articleContent, tag: "form")
      try cleanConditionally(articleContent, tag: "fieldset")
    }
    debugSnapshot?("prep.cleanConditionally.formFieldset", articleContent)

    // Match Mozilla prep for form controls.
    try removeShortShareElements(articleContent)
    debugSnapshot?("prep.removeShortShareElements", articleContent)
    try cleanElementsByTag(articleContent, tags: ["input", "textarea", "select", "button"])
    debugSnapshot?("prep.cleanFormControls", articleContent)
    try removeLinkHeavyChromeDivs(articleContent)
    debugSnapshot?("prep.removeLinkHeavyChromeDivs", articleContent)
    try SiteRuleRegistry.applyArticleCleanerRules(phase: .preConversion, to: articleContent, context: siteRuleContext, sourceURL: sourceURL)
    debugSnapshot?("prep.preConversionSiteRules", articleContent)
    try removeSingleItemPromoLists(articleContent)
    debugSnapshot?("prep.removeSingleItemPromoLists", articleContent)
    try removeEmptyContainerDivs(articleContent)
    debugSnapshot?("prep.removeEmptyContainerDivs", articleContent)
    try removeShortRoleNoteCallouts(articleContent)
    debugSnapshot?("prep.removeShortRoleNoteCallouts", articleContent)
    if allowConditionalCleaning {
      try cleanConditionally(articleContent, tag: "table")
      try cleanConditionally(articleContent, tag: "ul")
      try cleanConditionally(articleContent, tag: "div")
    }
    debugSnapshot?("prep.cleanConditionally.tableUlDiv", articleContent)

    // Convert DIVs to Ps where appropriate
    try convertDivsToParagraphs(articleContent)
    debugSnapshot?("prep.convertDivsToParagraphs", articleContent)
    try collapseSingleDivWrappers(articleContent)
    debugSnapshot?("prep.collapseSingleDivWrappers", articleContent)
  }

  // MARK: - DIV to P Conversion

  func getLinkDensity(_ element: Element) throws -> Double {
    try DOMHelpers.getLinkDensity(element)
  }

  /// Check if node is phrasing content (inline content)
  func isPhrasingContent(_ node: Node) -> Bool {
    DOMTraversal.isPhrasingContent(node)
  }

  // MARK: - Tag Name Change

  /// Change the tag name of an element
  /// Creates a new element with the given tag and moves all content
  /// Preserves the original order of child nodes (elements and text)
  func setNodeTag(_ element: Element, newTag: String) throws -> Element {
    try DOMHelpers.setNodeTag(element, newTag: newTag)
  }

  // MARK: - Style Cleaning

  func hasAncestorTag(
    _ element: Element,
    tag: String,
    predicate: ((Element) -> Bool)? = nil
  ) -> Bool {
    var current = element.parent()
    let target = tag.lowercased()
    while let node = current {
      if node.tagName().lowercased() == target,
         predicate?(node) ?? true
      {
        return true
      }
      current = node.parent()
    }
    return false
  }

  /// Post-process article content (equivalent to Mozilla's _prepArticle)
  /// This should be called after the main content extraction is complete
  func postProcessArticle(_ articleContent: Element) throws {
    // Remove BR tags that should not remain in final output.
    try removeExtraBRs(articleContent)

    // Remove empty paragraphs
    try removeEmptyParagraphs(articleContent)
    try SiteRuleRegistry.applyArticleCleanerRules(phase: .postParagraph, to: articleContent, context: siteRuleContext, sourceURL: sourceURL)
    try mergeFragmentedParagraphDivs(articleContent)

    // Remove ad placeholders that survived extraction.
    try removeAdvertisementPlaceholders(articleContent)

    // Replace H1 with H2 (H1 should only be the article title)
    try replaceH1WithH2(articleContent)

    // Keep parity with Mozilla on known NYTimes wrapper tag normalization.
    try SiteRuleRegistry.applyArticleCleanerRules(phase: .postProcess, to: articleContent, context: siteRuleContext, sourceURL: sourceURL)

    // Flatten single-cell tables
    try handleSingleCellTables(articleContent)
  }
}
