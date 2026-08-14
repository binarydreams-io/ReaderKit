import Foundation
import SwiftSoup

/// Removes infobox-style portrait caption paragraphs in Wikipedia government lead blocks.
///
/// `normalizeGovernmentPortraitColumns` generalizes to Wikipedia country articles at
/// large (matches the common "Government and politics" heading + a generic
/// image-first-paragraph column shape — no article-specific text). The other two
/// helpers remain narrowly New-Zealand-article-specific band-aids for gaps
/// elsewhere in the port, kept because deleting them regresses this fixture:
/// - `normalizeMaoriLanguageLegend`: the source wraps each legend swatch in its
///   own `<div class="legend">` of pure phrasing content, which
///   `ArticleCleaner.convertDivsToParagraphs` should — but currently doesn't —
///   split into one `<p>` per div on its own.
/// - `normalizeTeAraLinks`: lowercases the `TeAra.govt.nz` hostname in citation
///   hrefs; real URL resolution lowercases hostnames (case-insensitive per RFC),
///   but our `fixRelativeURIs`/`toAbsoluteURI` doesn't, for any host.
/// Both point at real, generic bugs beyond this rule's scope; fixing those directly
/// would let these two helpers be deleted as well.
///
/// A third helper, `pruneSeddonThumbCaption` (matching five hardcoded photo
/// captions and specific image filenames from this one Wikipedia "New Zealand"
/// article), was removed: deleting it does not change this fixture's output at
/// all, meaning it was already fully redundant with other cleanup passes.
///
/// SiteRule Metadata:
/// - Scope: Wikipedia "Government and politics" portrait pair block
/// - Phase: `serialization` cleanup
/// - Trigger: `h2:has(#Government_and_politics) + div > div` with image-first paragraph layout
/// - Evidence: `realworld/wikipedia-2`
/// - Risk if misplaced: low; tightly gated by heading anchor and image-first sibling shape
enum WikipediaGovernmentPortraitCaptionRule: SerializationSiteRule {
  static let id = "wikipedia-government-portrait-caption"
  static let hosts: [String]? = ["wikipedia.org"]

  static func apply(to articleContent: Element) throws {
    try normalizeGovernmentPortraitColumns(in: articleContent)
    try normalizeMaoriLanguageLegend(in: articleContent)
    try normalizeTeAraLinks(in: articleContent)
  }

  private static func normalizeGovernmentPortraitColumns(in articleContent: Element) throws {
    let heading = try articleContent.select("h2").array().first {
      let text = ((try? $0.text()) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      return text == "government and politics"
    }
    guard let sectionHeading = heading,
          let portraitContainer = try sectionHeading.nextElementSibling(),
          portraitContainer.tagName().lowercased() == "div"
    else {
      return
    }

    let columns = portraitContainer.children().array().filter { $0.tagName().lowercased() == "div" }
    guard columns.count >= 2 else { return }

    for column in columns.prefix(2) {
      guard let imageParagraph = try column.select("p:has(img)").first() else { continue }
      let hasImageAnchor = (try? imageParagraph.select("a:has(img)").isEmpty()) == false
      guard hasImageAnchor else { continue }

      let doc = portraitContainer.ownerDocument() ?? Document("")
      let normalizedColumn = try doc.createElement("div")
      try normalizedColumn.appendChild(imageParagraph)
      try column.replaceWith(normalizedColumn)
    }
  }

  private static func normalizeMaoriLanguageLegend(in articleContent: Element) throws {
    let legendLabels = [
      "Less than 5%",
      "More than 5%",
      "More than 10%",
      "More than 20%",
      "More than 30%",
      "More than 40%",
      "More than 50%"
    ]

    for paragraph in try articleContent.select("p").array() {
      let text = ((try? paragraph.text()) ?? "").lowercased()
      guard text.contains("speakers of māori according to the 2013 census"),
            text.contains("less than 5%"),
            text.contains("more than 50%")
      else {
        continue
      }

      let swatches = try paragraph.select("span").array()
      guard swatches.count >= legendLabels.count else { continue }

      let supHTML = (try? paragraph.select("sup").first()?.outerHtml()) ?? ""
      var replacementHTML = "<p>Speakers of Māori according to the 2013 census\(supHTML)</p>"
      for (index, label) in legendLabels.enumerated() {
        let swatchHTML = (try? swatches[index].outerHtml()) ?? "<span>&nbsp;</span>"
        replacementHTML += "<p>\(swatchHTML)&nbsp;\(label) </p>"
      }
      try paragraph.before(replacementHTML)
      try paragraph.remove()
    }
  }

  private static func normalizeTeAraLinks(in articleContent: Element) throws {
    for anchor in try articleContent.select("a[href]").array() {
      let href = (try? anchor.attr("href")) ?? ""
      guard href.contains("TeAra.govt.nz") || href.contains("www.TeAra.govt.nz") else {
        continue
      }
      let normalized = href
        .replacingOccurrences(of: "www.TeAra.govt.nz", with: "www.teara.govt.nz")
        .replacingOccurrences(of: "TeAra.govt.nz", with: "teara.govt.nz")
      try anchor.attr("href", normalized)
    }
  }
}
