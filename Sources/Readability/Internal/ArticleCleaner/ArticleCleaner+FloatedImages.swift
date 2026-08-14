import Foundation
import SwiftSoup

/// Promotion of float-styled inline images into standalone `<figure>`
/// blocks, including the host-splitting machinery it requires.
extension ArticleCleaner {
  /// Promote inline images that rely on explicit float styles into standalone
  /// `<figure>` blocks so they do not collapse into paragraph-leading inline
  /// images once presentational styles are removed.
  ///
  /// Worklist-based: candidates are collected once, and each promotion only
  /// enqueues candidates found inside its newly inserted split fragments
  /// (promotion clones the host's remaining content, so a second floated
  /// image in the same host reappears as a clone that still needs promoting)
  /// instead of re-scanning the whole subtree after every promotion.
  func promoteFloatedInlineImagesToFigures(_ root: Element) throws {
    var queue = try floatedInlineImages(in: root)
    var index = 0

    while index < queue.count {
      let image = queue[index]
      index += 1

      // A promotion may have detached this candidate (its host was split
      // and removed); the surviving clone was enqueued separately.
      guard isAttached(image, to: root),
            isFloatedInlineImage(image),
            !hasAncestorTag(image, tag: "figure")
      else {
        continue
      }

      guard let host = nearestFloatedImageHost(for: image) else { continue }
      guard host.parent() != nil else {
        // Host is detached (e.g. the article root itself) — cannot promote;
        // strip the float style so the image renders as a plain block.
        try stripFloatFromStyle(image)
        continue
      }

      let insertedFragments = try promoteFloatedInlineImage(image, from: host)
      for fragment in insertedFragments {
        try queue.append(contentsOf: floatedInlineImages(in: fragment))
      }
    }
  }

  private func floatedInlineImages(in root: Element) throws -> [Element] {
    try root.select("img[style]").array().filter { image in
      isFloatedInlineImage(image) && !hasAncestorTag(image, tag: "figure")
    }
  }

  private func isAttached(_ node: Element, to root: Element) -> Bool {
    var current: Element? = node
    while let element = current {
      if element === root {
        return true
      }
      current = element.parent()
    }
    return false
  }

  /// Removes `float:left|right` from the element's inline `style` attribute.
  /// If the style attribute becomes empty after removal, it is removed entirely.
  private func stripFloatFromStyle(_ element: Element) throws {
    let style = (try? element.attr("style")) ?? ""
    guard !style.isEmpty else { return }

    let declarations = style
      .split(separator: ";", omittingEmptySubsequences: true)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { declaration in
        guard let colon = declaration.firstIndex(of: ":") else {
          return true
        }
        let property = declaration[..<colon]
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
        guard property == "float" else {
          return true
        }
        let value = declaration[declaration.index(after: colon)...]
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
        return !value.hasPrefix("left") && !value.hasPrefix("right")
      }

    let cleanedStyle = declarations.joined(separator: "; ")
    if cleanedStyle.isEmpty {
      try element.removeAttr("style")
    } else {
      try element.attr("style", cleanedStyle)
    }
  }

  private func isFloatedInlineImage(_ image: Element) -> Bool {
    let style = ((try? image.attr("style")) ?? "")
    return style.range(
      of: "(^|;)\\s*float\\s*:\\s*(left|right)\\b",
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }

  private func nearestFloatedImageHost(for image: Element) -> Element? {
    let supportedHosts: Set = ["p", "div", "li", "blockquote"]
    var current = image.parent()

    while let node = current {
      let tagName = node.tagName().lowercased()
      if supportedHosts.contains(tagName) {
        return node
      }
      if ["article", "section", "main", "body"].contains(tagName) {
        return nil
      }
      current = node.parent()
    }

    return nil
  }

  /// Returns the split fragments inserted in place of the host (its content
  /// before/after the promoted image), so callers can scan them for cloned
  /// floated-image candidates.
  private func promoteFloatedInlineImage(_ image: Element, from host: Element) throws -> [Element] {
    guard let parent = host.parent() else { return [] }

    let doc = host.ownerDocument() ?? Document("")
    let path = buildAncestorPath(from: host, to: image)
    guard !path.isEmpty else { return [] }

    let split = try splitElement(host, along: path, at: 0)
    let figure = try doc.createElement("figure")
    let promotedImage: Element = if let copiedImage = image.copy() as? Element {
      copiedImage
    } else {
      try DOMHelpers.cloneElement(image, in: doc)
    }
    try figure.appendChild(promotedImage)

    if let before = split.before {
      try host.before(before)
    }
    try host.before(figure)
    if let after = split.after {
      try host.before(after)
    }

    if parent === host.parent() {
      try host.remove()
    }

    return [split.before, split.after].compactMap(\.self)
  }

  private func buildAncestorPath(from host: Element, to target: Element) -> [Element] {
    var path: [Element] = [target]
    var current = target.parent()

    while let node = current {
      path.append(node)
      if node === host {
        return path.reversed()
      }
      current = node.parent()
    }

    return []
  }

  private func splitElement(
    _ element: Element,
    along path: [Element],
    at index: Int
  ) throws -> (before: Element?, after: Element?) {
    let beforeClone = try clonedElementShell(for: element)
    let afterClone = try clonedElementShell(for: element)
    let nextOnPath = index + 1 < path.count ? path[index + 1] : nil
    var hasCrossedTarget = false

    for child in element.getChildNodes() {
      if let nextOnPath, child === nextOnPath {
        if index + 1 == path.count - 1 {
          hasCrossedTarget = true
          continue
        }

        if let childElement = child as? Element {
          let splitChild = try splitElement(childElement, along: path, at: index + 1)
          if let beforeChild = splitChild.before {
            try beforeClone.appendChild(beforeChild)
          }
          if let afterChild = splitChild.after {
            try afterClone.appendChild(afterChild)
          }
          hasCrossedTarget = true
          continue
        }
      }

      guard let clonedChild = child.copy() as? Node else { continue }
      if hasCrossedTarget {
        try afterClone.appendChild(clonedChild)
      } else {
        try beforeClone.appendChild(clonedChild)
      }
    }

    try pruneEmptyDescendants(in: beforeClone)
    try pruneEmptyDescendants(in: afterClone)

    return (
      before: hasMeaningfulContent(beforeClone) ? beforeClone : nil,
      after: hasMeaningfulContent(afterClone) ? afterClone : nil
    )
  }

  private func clonedElementShell(for element: Element) throws -> Element {
    let doc = element.ownerDocument() ?? Document("")
    let clone = try doc.createElement(element.tagName())
    try DOMHelpers.copyAttributes(from: element, to: clone)
    return clone
  }

  private func pruneEmptyDescendants(in element: Element) throws {
    for child in element.children().reversed() {
      try pruneEmptyDescendants(in: child)
      if !hasMeaningfulContent(child) {
        try child.remove()
      }
    }
  }

  private func hasMeaningfulContent(_ node: Node) -> Bool {
    switch node {
    case let textNode as TextNode:
      return !textNode.getWholeText()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty
    case let dataNode as DataNode:
      return !dataNode.getWholeData()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty
    case _ as Comment:
      return false
    case let element as Element:
      if ["img", "picture", "video", "audio", "svg"].contains(element.tagName().lowercased()) {
        return true
      }
      return element.getChildNodes().contains { hasMeaningfulContent($0) }
    default:
      return !node.nodeName().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
}
