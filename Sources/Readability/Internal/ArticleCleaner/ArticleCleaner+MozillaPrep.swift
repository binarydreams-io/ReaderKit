import Foundation
import SwiftSoup

/// Cleanup passes ported from Mozilla Readability.js `_prepArticle` and its
/// helpers. Faithful-to-upstream by design; behavioral deviations belong in
/// `ArticleCleaner+Heuristics` or a site rule, not here.
extension ArticleCleaner {
  /// Convert DIV elements to P elements where appropriate
  /// This implements Mozilla's div-to-p conversion logic
  func convertDivsToParagraphs(_ element: Element) throws {
    let divs = try DOMHelpers.selectExcludingRoot("div", in: element)

    for div in divs {
      // Skip if already converted
      guard div.tagName().lowercased() == "div" else { continue }
      // Skip detached top-level container created after extraction.
      guard div.parent() != nil else { continue }

      // Put consecutive phrasing content into paragraphs.
      var childNode = div.getChildNodes().first
      while let current = childNode {
        var nextSibling = current.nextSibling()

        if isPhrasingContent(current) {
          var fragment: [Node] = []
          var cursor: Node? = current

          // Collect consecutive phrasing nodes.
          while let phrasingNode = cursor, isPhrasingContent(phrasingNode) {
            nextSibling = phrasingNode.nextSibling()
            fragment.append(phrasingNode)
            cursor = nextSibling
          }

          // Trim surrounding whitespace / <br> from the fragment.
          while let first = fragment.first, DOMTraversal.isWhitespace(first) {
            try first.remove()
            fragment.removeFirst()
          }
          while let last = fragment.last, DOMTraversal.isWhitespace(last) {
            try last.remove()
            fragment.removeLast()
          }

          // Wrap non-empty fragment with a <p>.
          if !fragment.isEmpty {
            let doc = div.ownerDocument() ?? Document("")
            let p = try doc.createElement("p")

            if let next = nextSibling {
              try next.before(p)
            } else {
              try div.appendChild(p)
            }

            for node in fragment where node.parent() != nil {
              try p.appendChild(node)
            }
          }
        }

        childNode = nextSibling
      }

      // If DIV has exactly one P child and low link density, unwrap to that P.
      if hasSingleTagInsideElement(div, tag: "P"),
         try getLinkDensity(div) < 0.25,
         !shouldPreserveFigureImageWrapper(div),
         !shouldPreserveMathFormulaWrapper(div),
         let parent = div.parent(),
         parent.children().count == 1
      {
        if let onlyChild = div.children().first {
          try div.replaceWith(onlyChild)
        }
        continue
      }

      // If no block children remain, convert DIV to P.
      if try !hasChildBlockElement(div) {
        if shouldPreserveFigureImageWrapper(div) {
          continue
        }
        _ = try setNodeTag(div, newTag: "p")
      }
    }
  }

  /// Check if element has a single tag inside it
  func hasSingleTagInsideElement(_ element: Element, tag: String) -> Bool {
    let children = element.children()

    // Should have exactly 1 element child with given tag
    guard children.count == 1,
          children.first?.tagName().uppercased() == tag.uppercased()
    else {
      return false
    }

    // And should have no text nodes with real content
    let textNodes = element.textNodes()
    for textNode in textNodes {
      let trimmed = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        return false
      }
    }

    return true
  }

  /// Check if element has any block-level children
  func hasChildBlockElement(_ element: Element) throws -> Bool {
    let blockElements = Set(Configuration.divToPElements.map { $0.lowercased() })

    for childNode in element.getChildNodes() {
      guard let child = childNode as? Element else { continue }
      if blockElements.contains(child.tagName().lowercased()) {
        return true
      }
      if try hasChildBlockElement(child) {
        return true
      }
    }

    return false
  }

  private func shouldPreserveFootnoteSection(_ element: Element) -> Bool {
    let className = ((try? element.className()) ?? "").lowercased()
    let id = element.id().lowercased()
    let dataType = ((try? element.attr("data-type")) ?? "").lowercased()
    let identity = className + " " + id + " " + dataType
    guard identity.contains("footnote") else {
      return false
    }

    if (try? element.select("li[id^='fn']").isEmpty()) == false {
      return true
    }

    if (try? element.select("a[href^='#fnref']").isEmpty()) == false {
      return true
    }

    return false
  }

  /// Remove style attributes and presentational attributes
  func cleanStyles(_ element: Element) throws {
    // Match Mozilla: keep SVG subtree untouched.
    if element.tagName().lowercased() == "svg" {
      return
    }

    // Mozilla only removes presentational attributes here.
    for attr in Configuration.presentationalAttributes {
      try element.removeAttr(attr)
    }

    // Match Mozilla's deprecated width/height stripping for specific tags.
    if Configuration.deprecatedSizeAttributeElems.contains(element.tagName().uppercased()) {
      try element.removeAttr("width")
      try element.removeAttr("height")
    }

    // Recursively clean children
    for child in element.children() {
      try cleanStyles(child)
    }
  }

  // MARK: - Lazy Image Fixing

  /// Fix lazy-loaded images by converting data-src to src
  func fixLazyImages(_ element: Element) throws {
    let images = try element.select("img, picture, figure")

    for img in images {
      // Remove tiny non-SVG base64 placeholders when alternate image
      // sources exist on other attributes.
      let currentSrc = (try? img.attr("src")) ?? ""
      if let prefix = currentSrc.range(of: "^data:([^;,]+);base64,", options: [.regularExpression, .caseInsensitive]) {
        let mimePrefix = String(currentSrc[prefix]).lowercased()
        if !mimePrefix.contains("image/svg+xml") {
          var srcCouldBeRemoved = false
          if let attributes = img.getAttributes() {
            for attr in attributes {
              if attr.getKey().lowercased() == "src" {
                continue
              }
              if attr.getValue().range(of: "\\.(jpg|jpeg|png|webp)", options: [.regularExpression, .caseInsensitive]) != nil {
                srcCouldBeRemoved = true
                break
              }
            }
          }

          if srcCouldBeRemoved {
            let prefixLength = currentSrc.distance(from: currentSrc.startIndex, to: prefix.upperBound)
            let payloadLength = currentSrc.count - prefixLength
            if payloadLength < 133 {
              try img.removeAttr("src")
            }
          }
        }
      }

      // If src/srcset already present and not lazy-marked, keep as-is.
      let src = (try? img.attr("src")) ?? ""
      let srcset = (try? img.attr("srcset")) ?? ""
      let className = ((try? img.className()) ?? "").lowercased()
      if !src.isEmpty || (!srcset.isEmpty && srcset != "null"), !className.contains("lazy") {
        continue
      }

      var pendingSrc: String?
      var pendingSrcset: String?

      if let attributes = img.getAttributes() {
        for attr in attributes {
          let key = attr.getKey().lowercased()
          let value = attr.getValue().trimmingCharacters(in: .whitespacesAndNewlines)
          if key == "src" || key == "srcset" || key == "alt" || value.isEmpty {
            continue
          }

          // srcset-like: "...jpg 1x, ...webp 2x" or "...jpg 480w"
          if value.range(of: "\\.(jpg|jpeg|png|webp)(\\S*)\\s+\\d", options: [.regularExpression, .caseInsensitive]) != nil {
            pendingSrcset = pendingSrcset ?? value
            continue
          }

          // src-like: single image URL/token
          if value.range(of: "^\\s*\\S+\\.(jpg|jpeg|png|webp)\\S*\\s*$", options: [.regularExpression, .caseInsensitive]) != nil {
            pendingSrc = pendingSrc ?? value
          }
        }
      }

      if let pendingSrcset {
        if img.tagName().uppercased() == "IMG" || img.tagName().uppercased() == "PICTURE" {
          try img.attr("srcset", pendingSrcset)
        }
      }

      if let pendingSrc {
        if img.tagName().uppercased() == "IMG" || img.tagName().uppercased() == "PICTURE" {
          try img.attr("src", pendingSrc)
        } else if img.tagName().uppercased() == "FIGURE" {
          let hasInnerMedia = (try? img.select("img, picture").isEmpty()) == false
          if !hasInnerMedia {
            let doc = img.ownerDocument() ?? Document("")
            let child = try doc.createElement("img")
            try child.attr("src", pendingSrc)
            try img.appendChild(child)
          }
        }
      }

      // Figure can also carry srcset-style attributes without src.
      if let pendingSrcset, img.tagName().uppercased() == "FIGURE" {
        let hasInnerMedia = (try? img.select("img, picture").isEmpty()) == false
        if !hasInnerMedia {
          let doc = img.ownerDocument() ?? Document("")
          let child = try doc.createElement("img")
          try child.attr("srcset", pendingSrcset)
          try img.appendChild(child)
        }
      }
    }
  }

  // MARK: - Unwanted Element Removal

  func cleanElementsByTag(_ element: Element, tags: [String]) throws {
    let selector = tags.joined(separator: ", ")
    try element.select(selector).remove()
  }

  func removeShortShareElements(_ articleContent: Element) throws {
    let shareElementThreshold = options.charThreshold

    for topCandidate in articleContent.children() {
      let candidates = try topCandidate.select("[class*=share], [id*=share], [class*=sharedaddy], [id*=sharedaddy]")
      for node in candidates.reversed() {
        if node === topCandidate {
          continue
        }

        let matchString = (((try? node.className()) ?? "") + " " + node.id())
          .lowercased()
        guard hasShareElementMarker(matchString) else {
          continue
        }

        let textLength = try DOMHelpers.getInnerText(node).count
        if textLength < shareElementThreshold {
          try node.remove()
        }
      }
    }
  }

  private func hasShareElementMarker(_ matchString: String) -> Bool {
    matchString.range(
      of: "(^|[\\s_-])(share|sharedaddy)([\\s_-]|$)",
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }

  func cleanConditionally(_ root: Element, tag: String) throws {
    let nodes = try DOMHelpers.selectExcludingRoot(tag, in: root)
    for node in nodes.reversed() {
      guard node.parent() != nil else { continue }

      let dataType = ((try? node.attr("data-type")) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      if dataType == "footnotes" || dataType == "footnote" {
        continue
      }

      if shouldPreserveFootnoteSection(node) {
        continue
      }

      let innerText = try DOMHelpers.getInnerText(node)
      var isList = tag == "ul" || tag == "ol"
      if !isList && !innerText.isEmpty {
        var listLength = 0
        for list in try node.select("ul, ol") {
          listLength += try DOMHelpers.getInnerText(list).count
        }
        isList = Double(listLength) / Double(innerText.count) > 0.9
      }

      if tag == "table" && isDataTable(node) {
        continue
      }

      if hasAncestorTag(node, tag: "table", predicate: isDataTable) {
        continue
      }

      if hasAncestorTag(node, tag: "code") {
        continue
      }

      var containsDataTable = false
      for table in try node.select("table") {
        if isDataTable(table) {
          containsDataTable = true
          break
        }
      }
      if containsDataTable {
        continue
      }

      let weight = getClassWeight(node)
      if weight < 0 {
        try node.remove()
        continue
      }

      if getCommaCount(node) >= 10 {
        continue
      }

      let p = try node.select("p").count
      let img = try node.select("img").count
      let li = try node.select("li").count - 100
      let input = try node.select("input").count
      let headingDensity = try getTextDensity(node, tags: ["h1", "h2", "h3", "h4", "h5", "h6"])

      var embedCount = 0
      for embed in try node.select("object, embed, iframe") {
        if isAllowedVideoEmbed(embed) {
          embedCount = -1
          break
        }
        embedCount += 1
      }
      if embedCount == -1 {
        continue
      }

      if isAdvertisementWord(innerText) || isLoadingWord(innerText) {
        try node.remove()
        continue
      }

      let contentLength = innerText.count
      let linkDensity = try getLinkDensity(node)
      let textDensity = try getTextDensity(
        node,
        tags: ["span", "li", "td"] + Configuration.divToPElements.map { $0.lowercased() }
      )
      let isFigureChild = hasAncestorTag(node, tag: "figure")

      var shouldRemove = false
      if !isFigureChild && img > 1 && Double(p) / Double(img) < 0.5 {
        shouldRemove = true
      } else if !isList && li > p {
        shouldRemove = true
      } else if input > p / 3 {
        shouldRemove = true
      } else if !isList && !isFigureChild && headingDensity < 0.9 && contentLength < 25 && (img == 0 || img > 2) && linkDensity > 0 {
        shouldRemove = true
      } else if !isList && weight < 25 && linkDensity > (0.2 + options.linkDensityModifier) {
        shouldRemove = true
      } else if weight >= 25 && linkDensity > (0.5 + options.linkDensityModifier) {
        shouldRemove = true
      } else if (embedCount == 1 && contentLength < 75) || embedCount > 1 {
        shouldRemove = true
      } else if img == 0, textDensity == 0 {
        shouldRemove = true
      }

      if isList, shouldRemove {
        var hasComplexListItems = false
        for child in node.children() {
          if child.children().count > 1 {
            hasComplexListItems = true
            break
          }
        }

        if !hasComplexListItems {
          let liCount = try node.select("li").count
          if img == liCount {
            shouldRemove = false
          }
        }
      }

      if shouldRemove {
        try node.remove()
      }
    }
  }

  private func getCommaCount(_ element: Element) -> Int {
    let text = (try? DOMHelpers.getInnerText(element)) ?? ""
    let commaScalars = CharacterSet(charactersIn: ",\u{060C}\u{FE50}\u{FE10}\u{FE11}\u{2E41}\u{2E34}\u{2E32}\u{FF0C}")
    return text.unicodeScalars.reduce(into: 0) { count, scalar in
      if commaScalars.contains(scalar) {
        count += 1
      }
    }
  }

  private func getTextDensity(_ element: Element, tags: [String]) throws -> Double {
    let textLength = try DOMHelpers.getInnerText(element).count
    if textLength == 0 {
      return 0
    }

    var childrenLength = 0
    let selector = tags.joined(separator: ", ")
    for child in try element.select(selector) {
      childrenLength += try DOMHelpers.getInnerText(child).count
    }
    return Double(childrenLength) / Double(textLength)
  }

  func markDataTables(_ root: Element) throws {
    for table in try DOMHelpers.selectExcludingRoot("table", in: root) {
      if ((try? table.attr("role")) ?? "") == "presentation" {
        continue
      }

      if ((try? table.attr("datatable")) ?? "") == "0" {
        continue
      }

      if !((try? table.attr("summary")) ?? "").isEmpty {
        dataTableNodeIDs.insert(ObjectIdentifier(table))
        continue
      }

      if let caption = try table.select("caption").first(),
         !caption.getChildNodes().isEmpty
      {
        dataTableNodeIDs.insert(ObjectIdentifier(table))
        continue
      }

      if (try? table.select("col, colgroup, tfoot, thead, th").isEmpty()) == false {
        dataTableNodeIDs.insert(ObjectIdentifier(table))
        continue
      }

      var hasNestedTable = false
      for nestedTable in try table.select("table") {
        if ObjectIdentifier(nestedTable) != ObjectIdentifier(table) {
          hasNestedTable = true
          break
        }
      }
      if hasNestedTable {
        continue
      }

      let size = try getRowAndColumnCount(table)
      if size.columns == 1 || size.rows == 1 {
        continue
      }

      if size.rows >= 10 || size.columns > 4 || size.rows * size.columns > 10 {
        dataTableNodeIDs.insert(ObjectIdentifier(table))
      }
    }
  }

  private func getRowAndColumnCount(_ table: Element) throws -> (rows: Int, columns: Int) {
    var rows = 0
    var columns = 0

    for row in try table.select("tr") {
      let rowspan = Int((try? row.attr("rowspan")) ?? "") ?? 0
      rows += max(rowspan, 1)

      var columnsInThisRow = 0
      for cell in try row.select("td") {
        let colspan = Int((try? cell.attr("colspan")) ?? "") ?? 0
        columnsInThisRow += max(colspan, 1)
      }
      columns = max(columns, columnsInThisRow)
    }

    return (rows, columns)
  }

  private func isDataTable(_ element: Element) -> Bool {
    dataTableNodeIDs.contains(ObjectIdentifier(element))
  }

  private func shouldPreserveFigureImageWrapper(_ element: Element) -> Bool {
    DOMHelpers.shouldPreserveFigureImageWrapper(
      element,
      hasFigureAncestor: hasAncestorTag(element, tag: "figure")
    )
  }

  /// Preserve wrappers for math-render image blocks (for example Wikimedia math formulas),
  /// where Mozilla keeps `div > p > img` structure.
  private func shouldPreserveMathFormulaWrapper(_ element: Element) -> Bool {
    guard hasSingleTagInsideElement(element, tag: "P") else { return false }
    return (try? element.select("p > img[src*='/media/math/render/']")).map { !$0.isEmpty() } ?? false
  }

  private func isAdvertisementWord(_ text: String) -> Bool {
    let pattern = "^(ad(vertising|vertisement)?|pub(licité)?|werb(ung)?|广告|Реклама|Anuncio)$"
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
      .range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
  }

  private func isLoadingWord(_ text: String) -> Bool {
    let pattern = "^((loading|正在加载|Загрузка|chargement|cargando)(…|\\.\\.\\.)?)$"
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
      .range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
  }

  /// Remove iframe/object/embed nodes unless they match allowed video patterns.
  func removeDisallowedEmbeds(_ element: Element) throws {
    let embeds = try element.select("iframe, object, embed")
    for embed in embeds where !isAllowedVideoEmbed(embed) {
      try embed.remove()
    }
  }

  private func isAllowedVideoEmbed(_ element: Element) -> Bool {
    let pattern = options.allowedVideoRegex

    if let attrs = element.getAttributes() {
      for attr in attrs {
        if attr.getValue().range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
          return true
        }
      }
    }

    if element.tagName().lowercased() == "object",
       let html = try? element.html(),
       html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    {
      return true
    }

    return false
  }

  /// Clean headers that are likely not part of the content
  func cleanHeaders(_ element: Element) throws {
    let headers = try element.select("h1, h2")

    for header in headers {
      let classWeight = getClassWeight(header)
      if classWeight < 0 {
        try header.remove()
      }
    }
  }

  /// Get class/id weight for an element
  private func getClassWeight(_ element: Element) -> Double {
    guard allowWeightClasses else { return 0 }
    var weight: Double = 0
    let classAndId = DOMHelpers.getClassAndId(element)

    if Configuration.matchesNegativePattern(classAndId) {
      weight -= 25
    }
    if Configuration.positivePatterns.contains(where: { classAndId.contains($0) }) {
      weight += 25
    }

    return weight
  }

  // MARK: - Single Cell Table Handling

  /// Convert single-cell tables to divs or ps
  func handleSingleCellTables(_ element: Element) throws {
    let tables = try element.select("table")

    for table in tables {
      let tbody: Element = if hasSingleTagInsideElement(table, tag: "TBODY"), let firstChild = table.children().first {
        firstChild
      } else {
        table
      }

      guard hasSingleTagInsideElement(tbody, tag: "TR"), let row = tbody.children().first else {
        continue
      }

      let cellTag: String
      if hasSingleTagInsideElement(row, tag: "TD") {
        cellTag = "TD"
      } else if hasSingleTagInsideElement(row, tag: "TH") {
        cellTag = "TH"
      } else {
        continue
      }

      guard row.children().count == 1,
            let cell = row.children().first,
            cell.tagName().uppercased() == cellTag
      else {
        continue
      }

      // Determine new tag based on content
      let allPhrasing = cell.getChildNodes().allSatisfy { isPhrasingContent($0) }
      let newTag = allPhrasing ? "p" : "div"

      let newElement = try setNodeTag(cell, newTag: newTag)
      if newTag == "p" {
        try newElement.removeAttr("dir")
      }
      try table.replaceWith(newElement)
    }
  }

  // MARK: - Post-Processing (_prepArticle functionality)

  /// Remove BR tags that appear before P tags or at the end of containers
  func removeExtraBRs(_ element: Element) throws {
    let brs = try element.select("br")

    for br in brs {
      if shouldRemoveBRBeforeParagraph(br) {
        try br.remove()
      }
    }
  }

  /// Remove BR only when it is part of a BR chain that leads into a paragraph.
  /// Keep trailing BRs that are not followed by paragraph content.
  private func shouldRemoveBRBeforeParagraph(_ br: Element) -> Bool {
    var cursor = br.nextSibling()

    while let node = cursor {
      if let text = node as? TextNode {
        if text.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          cursor = node.nextSibling()
          continue
        }
        return false
      }

      if let el = node as? Element {
        let tag = el.tagName().lowercased()
        if tag == "br" {
          cursor = node.nextSibling()
          continue
        }
        return tag == "p"
      }

      cursor = node.nextSibling()
    }

    return false
  }

  /// Remove empty paragraph elements
  func removeEmptyParagraphs(_ element: Element) throws {
    let paragraphs = try element.select("p")

    for p in paragraphs {
      // Check if paragraph has no meaningful content
      let text = try p.text().trimmingCharacters(in: .whitespaces)

      // Match Mozilla: treat only img/embed/object/iframe as paragraph content elements.
      let contentElements = try p.select("img, embed, object, iframe").count

      if text.isEmpty, contentElements == 0 {
        try p.remove()
      }
    }
  }

  /// Replace H1 elements with H2 (H1 should be reserved for article title)
  func replaceH1WithH2(_ element: Element) throws {
    let h1s = try element.select("h1")

    for h1 in h1s {
      _ = try setNodeTag(h1, newTag: "h2")
    }
  }
}
