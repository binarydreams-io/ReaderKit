import Foundation
import SwiftSoup

/// Internal mutable accumulator for per-pass extraction diagnostics.
/// Accumulates the public `InspectionReport` value types directly as
/// extraction proceeds; only the in-progress pass needs a mutable builder.
final class InspectionContext {
  /// Mutable staging area for the pass currently being recorded; frozen into
  /// an immutable `InspectionReport.PassAttempt` by `endPass`.
  private struct PassBuilder {
    var passNumber: Int
    var flagBits: UInt32
    var topCandidates: [InspectionReport.CandidateInfo] = []
    var initialWinner: InspectionReport.CandidateInfo?
    var promotionTrace: [InspectionReport.PromotionStep] = []
    var finalCandidate: InspectionReport.CandidateInfo?
    var candidateContext: InspectionReport.CandidateContext?
    var siblingDecisions: [InspectionReport.SiblingDecision] = []
    var siteRuleDecisions: [InspectionReport.SiteRuleDecision] = []
    var contentSnapshot: InspectionReport.ContentSnapshotSummary?
  }

  // MARK: - State

  private let charThreshold: Int
  private var passes: [InspectionReport.PassAttempt] = []
  private var currentPass: PassBuilder?
  private var cleanupSnapshots: [InspectionReport.CleanupSnapshotSummary] = []

  init(charThreshold: Int) {
    self.charThreshold = charThreshold
  }

  /// Flag bits of the currently active pass (used by CandidateSelector to branch on flag state).
  var currentPassFlagBits: UInt32 {
    currentPass?.flagBits ?? 0
  }

  // MARK: - Pass Lifecycle

  func beginPass(number: Int, flagBits: UInt32) {
    currentPass = PassBuilder(passNumber: number, flagBits: flagBits)
  }

  func recordTopCandidates(_ candidates: [InspectionReport.CandidateInfo]) {
    currentPass?.topCandidates = candidates
  }

  func recordInitialWinner(_ info: InspectionReport.CandidateInfo?) {
    currentPass?.initialWinner = info
  }

  func recordPromotionStep(descriptor: String, path: String, score: Double, action: String) {
    currentPass?.promotionTrace.append(
      InspectionReport.PromotionStep(descriptor: descriptor, path: path, score: score, action: action)
    )
  }

  func recordFinalCandidate(_ info: InspectionReport.CandidateInfo?) {
    currentPass?.finalCandidate = info
  }

  func recordCandidateContext(candidate: Element) {
    let parent = candidate.parent()
    currentPass?.candidateContext = InspectionReport.CandidateContext(
      candidateDescriptor: DOMDebugFormatting.conciseElementDescriptor(candidate),
      candidatePath: InspectionDOMHelpers.nodePath(candidate),
      parentDescriptor: parent.map(DOMDebugFormatting.conciseElementDescriptor),
      parentPath: parent.map(InspectionDOMHelpers.nodePath),
      ancestorChain: candidate.ancestors().map {
        "\(DOMDebugFormatting.conciseElementDescriptor($0)) @ \(InspectionDOMHelpers.nodePath($0))"
      },
      siblingDescriptors: parent.map {
        $0.children().map {
          "\(DOMDebugFormatting.conciseElementDescriptor($0)) @ \(InspectionDOMHelpers.nodePath($0))"
        }
      } ?? []
    )
  }

  func recordSiblingDecision(
    sibling: Element,
    score: Double,
    bonus: Double,
    threshold: Double,
    visible: Bool,
    decision: String,
    reason: String,
    siteRuleDecisionID: String? = nil
  ) {
    currentPass?.siblingDecisions.append(
      InspectionReport.SiblingDecision(
        descriptor: DOMDebugFormatting.conciseElementDescriptor(sibling),
        path: InspectionDOMHelpers.nodePath(sibling),
        tagName: sibling.tagName().lowercased(),
        className: (try? sibling.className()) ?? "",
        score: score,
        bonus: bonus,
        threshold: threshold,
        visible: visible,
        decision: decision,
        reason: reason,
        siteRuleDecisionID: siteRuleDecisionID
      )
    )
  }

  func recordSiteRuleDecision(
    phase: String,
    ruleID: String,
    target: Element,
    action: String,
    result: Element? = nil,
    reason: String
  ) {
    currentPass?.siteRuleDecisions.append(
      InspectionReport.SiteRuleDecision(
        phase: phase,
        ruleID: ruleID,
        targetDescriptor: DOMDebugFormatting.conciseElementDescriptor(target),
        targetPath: InspectionDOMHelpers.nodePath(target),
        action: action,
        resultDescriptor: result.map(DOMDebugFormatting.conciseElementDescriptor),
        resultPath: result.flatMap { $0.parent() != nil ? InspectionDOMHelpers.nodePath($0) : nil },
        reason: reason
      )
    )
  }

  func recordContentSnapshot(articleContent: Element, selectedCandidate: Element, contentLength: Int) {
    let articleChildren = articleContent.children().map(DOMDebugFormatting.conciseElementDescriptor)
    let leadingSource: Elements
    let usesSingleWrapper: Bool
    let wrapperDescriptor: String?
    let wrapperPath: String?
    if articleContent.children().count == 1,
       let onlyChild = articleContent.children().first,
       onlyChild.tagName().uppercased() == "DIV"
    {
      leadingSource = onlyChild.children()
      usesSingleWrapper = true
      wrapperDescriptor = DOMDebugFormatting.conciseElementDescriptor(onlyChild)
      wrapperPath = InspectionDOMHelpers.nodePath(onlyChild)
    } else {
      leadingSource = articleContent.children()
      usesSingleWrapper = false
      wrapperDescriptor = nil
      wrapperPath = nil
    }
    currentPass?.contentSnapshot = InspectionReport.ContentSnapshotSummary(
      selectedCandidateDescriptor: DOMDebugFormatting.conciseElementDescriptor(selectedCandidate),
      selectedCandidatePath: InspectionDOMHelpers.nodePath(selectedCandidate),
      articleChildCount: articleContent.children().count,
      articleChildDescriptors: articleChildren,
      usesSingleWrapper: usesSingleWrapper,
      wrapperDescriptor: wrapperDescriptor,
      wrapperPath: wrapperPath,
      leadingBlocks: Array(leadingSource.prefix(8)).map {
        InspectionReport.ContentSnapshotSummary.BlockSummary(
          descriptor: DOMDebugFormatting.conciseElementDescriptor($0),
          path: InspectionDOMHelpers.nodePath($0),
          childCount: $0.children().count,
          textPreview: previewText(for: $0, limit: 80)
        )
      },
      contentLength: contentLength
    )
  }

  private func previewText(for element: Element, limit: Int) -> String {
    let raw = ((try? element.text()) ?? "")
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard raw.count > limit else { return raw }
    return String(raw.prefix(limit)) + "..."
  }

  func endPass(contentLength: Int, accepted: Bool) {
    guard let pass = currentPass else { return }
    passes.append(
      InspectionReport.PassAttempt(
        passNumber: pass.passNumber,
        activeFlags: flagNames(pass.flagBits),
        topCandidates: pass.topCandidates,
        initialWinner: pass.initialWinner,
        promotionTrace: pass.promotionTrace,
        finalCandidate: pass.finalCandidate,
        candidateContext: pass.candidateContext,
        siblingDecisions: pass.siblingDecisions,
        siteRuleDecisions: pass.siteRuleDecisions,
        contentSnapshot: pass.contentSnapshot,
        contentLength: contentLength,
        charThreshold: charThreshold,
        accepted: accepted
      )
    )
    currentPass = nil
  }

  func recordCleanupSnapshot(stage: String, articleContent: Element) {
    cleanupSnapshots.append(
      InspectionReport.CleanupSnapshotSummary(
        stage: stage,
        contentLength: ((try? articleContent.text()) ?? "").count,
        articleChildCount: articleContent.children().count,
        articleChildDescriptors: articleContent.children().map(DOMDebugFormatting.conciseElementDescriptor),
        leadingBlocks: Array(articleContent.children().prefix(8)).map {
          InspectionReport.FinalContentSnapshotSummary.BlockSummary(
            descriptor: DOMDebugFormatting.conciseElementDescriptor($0),
            path: InspectionDOMHelpers.nodePath($0),
            childCount: $0.children().count,
            textPreview: previewText(for: $0, limit: 80)
          )
        }
      )
    )
  }

  // MARK: - Report Construction

  func buildReport() -> InspectionReport {
    InspectionReport(
      passes: passes,
      finalContentSnapshot: cleanupSnapshots.last.map {
        InspectionReport.FinalContentSnapshotSummary(
          contentLength: $0.contentLength,
          articleChildCount: $0.articleChildCount,
          articleChildDescriptors: $0.articleChildDescriptors,
          leadingBlocks: $0.leadingBlocks
        )
      },
      cleanupSnapshots: cleanupSnapshots
    )
  }

  private func flagNames(_ bits: UInt32) -> [String] {
    var names: [String] = []
    if bits & Configuration.flagStripUnlikelies != 0 {
      names.append("STRIP")
    }
    if bits & Configuration.flagWeightClasses != 0 {
      names.append("WEIGHT")
    }
    if bits & Configuration.flagCleanConditionally != 0 {
      names.append("CLEAN")
    }
    return names
  }
}
