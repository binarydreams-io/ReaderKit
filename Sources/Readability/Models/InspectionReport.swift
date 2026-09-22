// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation

/// Detailed extraction process report returned by `Readability.parseWithInspection()`.
///
/// Shows exactly which elements were considered as candidates, their score breakdown,
/// which multi-pass attempts were made, and how the final candidate was selected
/// and/or promoted through the ancestor chain.
///
/// Use this to diagnose incorrect content extraction without inserting temporary debug code.
public struct InspectionReport: Sendable {

  // MARK: - Nested Types

  /// A compact description of one top-level block in the article content.
  public struct BlockSummary: Sendable {
    /// CSS-like descriptor of the block element.
    public let descriptor: String
    /// DOM path for the block element.
    public let path: String
    /// Number of child elements.
    public let childCount: Int
    /// The first characters of the block text.
    public let textPreview: String
  }

  /// One group of class/id patterns that fired a weight adjustment.
  /// All matching patterns within a group collectively contribute `points` (not per-pattern).
  public struct ClassWeightComponent: Sendable {
    /// The attribute that was checked: "class" or "id".
    public let attribute: String
    /// Whether the match was positive or negative: "positive" or "negative".
    public let side: String
    /// All pattern strings from the configuration that matched within this attribute.
    public let matchedPatterns: [String]
    /// Points contributed: +25.0 (positive) or -25.0 (negative).
    public let points: Double
  }

  /// Snapshot of a scored candidate element captured during extraction.
  public struct Candidate: Sendable {
    /// CSS-like descriptor, e.g. "div.entry-content" or "div#main".
    public let descriptor: String
    /// DOM path for this element.
    public let path: String
    /// DOM depth: number of ancestor elements above this node.
    public let depth: Int
    /// Final content score (after link-density scaling).
    public let score: Double
    /// Tag-based score component only (before class weight and child propagation).
    public let baseScore: Double
    /// Total class/id weight applied. Zero when WEIGHT flag was inactive.
    public let classWeightTotal: Double
    /// Matched pattern groups that make up classWeightTotal, by attribute and side.
    public let classWeightComponents: [ClassWeightComponent]
    /// Approximate score from child propagation: score - baseScore - classWeightTotal.
    public let childrenScore: Double
  }

  /// One step captured during the `findBetterParentCandidate` traversal.
  public struct PromotionStep: Sendable {
    /// CSS-like descriptor of the element checked at this step.
    public let descriptor: String
    /// DOM path for this element.
    public let path: String
    /// Content score of this element.
    public let score: Double
    /// Human-readable outcome, e.g. "initial winner", "fell, continue", "rose → PROMOTED".
    public let action: String
  }

  /// Summary of the selected candidate's immediate DOM context.
  public struct CandidateContext: Sendable {
    /// CSS-like descriptor of the selected candidate.
    public let candidateDescriptor: String
    /// DOM path for the selected candidate.
    public let candidatePath: String
    /// CSS-like descriptor of the candidate's parent element.
    public let parentDescriptor: String?
    /// DOM path for the candidate's parent element.
    public let parentPath: String?
    /// Descriptors of the candidate's ancestors, from the nearest ancestor outward.
    public let ancestorChain: [String]
    /// Descriptors of the candidate's sibling elements.
    public let siblingDescriptors: [String]
  }

  /// One explicit sibling-merge decision recorded during content assembly.
  public struct SiblingDecision: Sendable {
    /// CSS-like descriptor of the sibling element.
    public let descriptor: String
    /// DOM path for the sibling element.
    public let path: String
    /// Lowercase tag name of the sibling element.
    public let tagName: String
    /// Value of the sibling's `class` attribute.
    public let className: String
    /// Content score of the sibling element.
    public let score: Double
    /// Score bonus that the sibling gets from a class name shared with the candidate.
    public let bonus: Double
    /// Score that the sibling must reach for the merge.
    public let threshold: Double
    /// Whether the sibling element is visible.
    public let isVisible: Bool
    /// The merge decision: "append", "skip", or "extract".
    public let decision: String
    /// Human-readable reason for the decision.
    public let reason: String
    /// ID of the site rule that made the decision, if a site rule made it.
    public let siteRuleDecisionID: String?
  }

  /// One explicit site-rule decision recorded during extraction.
  public struct SiteRuleDecision: Sendable {
    /// Extraction phase in which the rule ran.
    public let phase: String
    /// Identifier of the site rule.
    public let ruleID: String
    /// CSS-like descriptor of the element that the rule examined.
    public let targetDescriptor: String
    /// DOM path for the element that the rule examined.
    public let targetPath: String
    /// The action that the rule took.
    public let action: String
    /// CSS-like descriptor of the element that the action produced, if any.
    public let resultDescriptor: String?
    /// DOM path for the element that the action produced, if any.
    public let resultPath: String?
    /// Human-readable reason for the decision.
    public let reason: String
  }

  /// Compact summary of the merged article content produced by one pass.
  public struct ContentSnapshot: Sendable {
    /// CSS-like descriptor of the selected candidate.
    public let selectedCandidateDescriptor: String
    /// DOM path for the selected candidate.
    public let selectedCandidatePath: String
    /// Number of top-level children in the article content.
    public let articleChildCount: Int
    /// Descriptors of the top-level children in the article content.
    public let articleChildDescriptors: [String]
    /// Whether the article content is one wrapper element around all blocks.
    public let usesSingleWrapper: Bool
    /// CSS-like descriptor of the single wrapper, if there is one.
    public let wrapperDescriptor: String?
    /// DOM path for the single wrapper, if there is one.
    public let wrapperPath: String?
    /// The first blocks of the article content.
    public let leadingBlocks: [InspectionReport.BlockSummary]
    /// Character count of the article text.
    public let contentLength: Int
  }

  /// Final snapshot after article cleanup and title-header removal.
  public struct FinalContentSnapshot: Sendable {
    /// Character count of the article text.
    public let contentLength: Int
    /// Number of top-level children in the article content.
    public let articleChildCount: Int
    /// Descriptors of the top-level children in the article content.
    public let articleChildDescriptors: [String]
    /// The first blocks of the article content.
    public let leadingBlocks: [InspectionReport.BlockSummary]
  }

  /// Snapshot captured at a named cleanup stage.
  public struct CleanupSnapshot: Sendable {
    /// Name of the cleanup stage.
    public let stage: String
    /// Character count of the article text.
    public let contentLength: Int
    /// Number of top-level children in the article content.
    public let articleChildCount: Int
    /// Descriptors of the top-level children in the article content.
    public let articleChildDescriptors: [String]
    /// The first blocks of the article content.
    public let leadingBlocks: [BlockSummary]
  }

  /// Data captured during one complete pass of the multi-pass extraction loop.
  public struct PassAttempt: Sendable {
    /// 1-indexed pass number.
    public let passNumber: Int
    /// Flag names active during this pass, e.g. ["STRIP", "WEIGHT", "CLEAN"].
    public let activeFlags: [String]
    /// Top-N candidates sorted by final score descending.
    public let topCandidates: [Candidate]
    /// The best candidate immediately after scoring, before any promotion logic runs.
    public let initialWinner: Candidate?
    /// Steps taken by `findBetterParentCandidate`, including the starting element.
    public let promotionTrace: [PromotionStep]
    /// Candidate actually selected after all promotion passes completed.
    public let finalCandidate: Candidate?
    /// Candidate ancestry and sibling context for the selected candidate.
    public let candidateContext: CandidateContext?
    /// Explicit sibling decisions recorded while assembling article content.
    public let siblingDecisions: [SiblingDecision]
    /// Explicit site-rule decisions recorded during extraction.
    public let siteRuleDecisions: [SiteRuleDecision]
    /// Compact content-shape summary for this pass.
    public let contentSnapshot: ContentSnapshot?
    /// Character count of extracted text content for this attempt.
    public let contentLength: Int
    /// The configured `ReadabilityOptions.minimumCharacterCount` for comparison.
    public let minimumCharacterCount: Int
    /// Whether this pass met `minimumCharacterCount` and became the accepted final result.
    public let isAccepted: Bool
  }

  // MARK: - Properties

  /// One entry per pass of the extraction loop, in ascending order.
  public let passes: [PassAttempt]

  /// Final article snapshot after cleanup, before serialization.
  public let finalContentSnapshot: FinalContentSnapshot?

  /// Intermediate snapshots captured during cleanup.
  public let cleanupSnapshots: [CleanupSnapshot]
}

// MARK: - Deprecated Names

extension InspectionReport {
  @available(*, deprecated, renamed: "InspectionReport.Candidate")
  public typealias CandidateInfo = Candidate

  @available(*, deprecated, renamed: "InspectionReport.ContentSnapshot")
  public typealias ContentSnapshotSummary = ContentSnapshot

  @available(*, deprecated, renamed: "InspectionReport.FinalContentSnapshot")
  public typealias FinalContentSnapshotSummary = FinalContentSnapshot

  @available(*, deprecated, renamed: "InspectionReport.CleanupSnapshot")
  public typealias CleanupSnapshotSummary = CleanupSnapshot
}

extension InspectionReport.ContentSnapshot {
  @available(*, deprecated, renamed: "InspectionReport.BlockSummary")
  public typealias BlockSummary = InspectionReport.BlockSummary
}

extension InspectionReport.FinalContentSnapshot {
  @available(*, deprecated, renamed: "InspectionReport.BlockSummary")
  public typealias BlockSummary = InspectionReport.BlockSummary
}

extension InspectionReport.SiblingDecision {
  @available(*, deprecated, renamed: "isVisible")
  public var visible: Bool {
    isVisible
  }
}

extension InspectionReport.PassAttempt {
  @available(*, deprecated, renamed: "minimumCharacterCount")
  public var charThreshold: Int {
    minimumCharacterCount
  }

  @available(*, deprecated, renamed: "isAccepted")
  public var accepted: Bool {
    isAccepted
  }
}
