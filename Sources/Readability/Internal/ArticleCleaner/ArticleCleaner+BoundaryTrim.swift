// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

/// Trimming of non-content residue from the leading and trailing edges of
/// the extracted article after all other cleanup stages have run.
extension ArticleCleaner {
  /// Content-bearing element tags that always stop boundary trimming,
  /// even if they appear empty (e.g. an empty `<figure>` or `<ul>` at
  /// the edge of the article is preserved).
  private static let meaningfulContentTags: Set<String> = [
    "img", "picture", "video", "audio", "svg",
    "figure", "table", "ul", "ol", "blockquote", "pre", "code", "iframe",
    "object", "embed", "canvas", "math",
    "article"
  ]

  /// Container tags that boundary trimming may recurse into.
  /// These are structural wrappers that can harbour trailing/leading
  /// residue *inside* themselves even when the wrapper itself is not
  /// removable.
  private static let boundaryContainerTags: Set<String> = [
    "div", "section", "aside", "header", "footer",
    "article", "main"
  ]

  /// Structural wrapper tags that may be removed entirely when all
  /// their descendants are boundary residue. This is a subset of
  /// `boundaryContainerTags` — tags such as `article` and `main` are
  /// recursed into but never deleted as empty husks.
  private static let removableWrapperTags: Set<String> = [
    "div", "section", "aside", "header", "footer"
  ]

  /// Trims non-content residue from the leading and trailing boundaries
  /// of the extracted article. This pass runs after all other cleanup
  /// stages because residue often appears only once surrounding content
  /// blocks (ads, nav, subscribe) have been removed.
  ///
  /// The pass only touches the article edges and stops as soon as it
  /// encounters meaningful content. Internal separators are preserved.
  func trimBoundaryNonContent(_ root: Element) throws {
    var changed = true
    while changed {
      changed = false
      if try trimLeadingBoundary(from: root) {
        changed = true
      }
      if try trimTrailingBoundary(from: root) {
        changed = true
      }
    }
  }

  /// Trims removable residue nodes from the start of `element`'s children.
  private func trimLeadingBoundary(from element: Element) throws -> Bool {
    var removed = false
    while let first = element.getChildNodes().first {
      if let wrapper = first as? Element,
         Self.boundaryContainerTags.contains(wrapper.tagName().lowercased())
      {
        // Only recurse in the leading direction — wrapper is at the
        // parent's leading edge, so only its own leading edge is a
        // continuation of the article boundary.
        if try trimLeadingBoundary(from: wrapper) {
          removed = true
        }
        if try isWrapperOnlyResidue(wrapper) {
          try wrapper.remove()
          removed = true
          continue
        }
        break
      }
      if try removeIfDirectResidue(first) {
        removed = true
        continue
      }
      break
    }
    return removed
  }

  /// Trims removable residue nodes from the end of `element`'s children.
  private func trimTrailingBoundary(from element: Element) throws -> Bool {
    var removed = false
    while let last = element.getChildNodes().last {
      if let wrapper = last as? Element,
         Self.boundaryContainerTags.contains(wrapper.tagName().lowercased())
      {
        // Only recurse in the trailing direction — wrapper is at the
        // parent's trailing edge, so only its own trailing edge is a
        // continuation of the article boundary.
        if try trimTrailingBoundary(from: wrapper) {
          removed = true
        }
        if try isWrapperOnlyResidue(wrapper) {
          try wrapper.remove()
          removed = true
          continue
        }
        break
      }
      if try removeIfDirectResidue(last) {
        removed = true
        continue
      }
      break
    }
    return removed
  }

  /// Returns `true` when a node is directly removable boundary residue
  /// (whitespace text, comments, `<hr>`, `<br>`, or empty `<p>`/headings).
  private func isDirectResidue(_ node: Node) -> Bool {
    switch node {
    case let textNode as TextNode:
      return textNode.getWholeText()
        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case _ as Comment:
      return true
    case let element as Element:
      let tag = element.tagName().lowercased()
      switch tag {
      case "hr", "br":
        return true
      case "p", "h1", "h2", "h3", "h4", "h5", "h6":
        return !hasMeaningfulBoundaryContent(element)
      default:
        return false
      }
    default:
      return false
    }
  }

  private func removeIfDirectResidue(_ node: Node) throws -> Bool {
    guard isDirectResidue(node) else { return false }
    try node.remove()
    return true
  }

  /// Returns `true` when a structural wrapper element contains only
  /// boundary-residue descendants and can be removed.
  private func isWrapperOnlyResidue(_ wrapper: Element) throws -> Bool {
    guard Self.removableWrapperTags.contains(wrapper.tagName().lowercased()) else {
      return false
    }
    let children = wrapper.getChildNodes()
    return try children.allSatisfy { try isNodeBoundaryResidue($0) }
  }

  /// Returns `true` when a node (at any depth) is boundary residue.
  /// Structural wrappers recurse into children; content tags return false.
  private func isNodeBoundaryResidue(_ node: Node) throws -> Bool {
    switch node {
    case let textNode as TextNode:
      return textNode.getWholeText()
        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case _ as Comment:
      return true
    case let element as Element:
      let tag = element.tagName().lowercased()
      if Self.meaningfulContentTags.contains(tag) {
        return false
      }
      if Self.boundaryContainerTags.contains(tag) {
        return try element.getChildNodes().allSatisfy { try isNodeBoundaryResidue($0) }
      }
      return !hasMeaningfulBoundaryContent(element)
    default:
      return false
    }
  }

  /// Returns `true` when an element contains meaningful article content
  /// that should stop boundary trimming. Content-bearing tags are always
  /// meaningful; text-bearing elements are checked recursively.
  private func hasMeaningfulBoundaryContent(_ element: Element) -> Bool {
    let tag = element.tagName().lowercased()
    if Self.meaningfulContentTags.contains(tag) {
      return true
    }
    return element.getChildNodes().contains { node in
      switch node {
      case let textNode as TextNode:
        !textNode.getWholeText()
          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case let child as Element:
        hasMeaningfulBoundaryContent(child)
      default:
        false
      }
    }
  }
}
