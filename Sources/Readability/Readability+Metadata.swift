// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

import Foundation
import SwiftSoup

extension Readability {

  // MARK: - Metadata Extraction

  /// Extract metadata from various sources (meta tags, JSON-LD, etc.)
  func extractMetadata() throws -> Metadata {
    var metadata = Metadata()

    func nonEmpty(_ value: String?) -> String? {
      guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
      else {
        return nil
      }
      return trimmed
    }

    if options.parsesJSONLD {
      let jsonldMetadata = try extractJSONLDMetadata()
      metadata.title = jsonldMetadata.title
      metadata.byline = jsonldMetadata.byline
      metadata.excerpt = jsonldMetadata.excerpt
      metadata.siteName = jsonldMetadata.siteName
      metadata.publishedTime = jsonldMetadata.publishedTime
    }

    // Extract from meta tags
    let metaMetadata = try extractMetaMetadata()
    metadata.title = nonEmpty(metadata.title) ?? nonEmpty(metaMetadata.title)
    metadata.byline = nonEmpty(metadata.byline) ?? nonEmpty(metaMetadata.byline)
    metadata.excerpt = nonEmpty(metadata.excerpt) ?? nonEmpty(metaMetadata.excerpt)
    metadata.siteName = nonEmpty(metadata.siteName) ?? nonEmpty(metaMetadata.siteName)
    metadata.publishedTime = nonEmpty(metadata.publishedTime) ?? nonEmpty(metaMetadata.publishedTime)

    return metadata
  }

  /// Recognized meta name/property keys (bare or namespaced, e.g. `og:title`).
  /// Compiled once — this previously recompiled on every meta tag encountered.
  private static let metaPropertyKeyRegex: NSRegularExpression = {
    let pattern = "^\\s*(?:(dc|dcterm|og|twitter|parsely|weibo:(article|webpage))\\s*[-\\.:]\\s*)?(author|creator|pub-date|description|title|site_name)\\s*$"
    // Safe to force-try: fixed literal pattern known to compile.
    return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
  }()

  private func extractMetaMetadata() throws -> Metadata {
    var metadata = Metadata()
    let sourceURL = detectSourceURL()

    var values: [String: String] = [:]
    let metas = try doc.select("meta")

    for meta in metas {
      let property = (try? meta.attr("property"))?.lowercased() ?? ""
      let name = (try? meta.attr("name"))?.lowercased() ?? ""
      let content = (try? meta.attr("content")) ?? ""

      func shouldStore(key: String, fromProperty: Bool) -> Bool {
        // Keep `author` from `name=author`, but ignore bare `property=author`
        // which is noisy on several real-world pages.
        if key == "author", fromProperty {
          return false
        }
        return true
      }

      let propertyKeys = property.isEmpty ? [] : property.split(separator: " ").map(String.init)
      let nameKeys = name.isEmpty ? [] : [name]

      for key in propertyKeys {
        let normalizedKey = canonicalMetaKey(key)
        guard shouldStore(key: normalizedKey, fromProperty: true) else { continue }
        // Check if key matches the pattern OR is article:published_time
        let isArticlePublishedTime = normalizedKey == "article:published_time"
        let isArticleAuthor = normalizedKey == "article:author" || normalizedKey == "og:article:author"
        let range = NSRange(location: 0, length: normalizedKey.utf16.count)
        if Self.metaPropertyKeyRegex.firstMatch(in: normalizedKey, options: [], range: range) != nil || isArticlePublishedTime || isArticleAuthor,
           !content.isEmpty
        {
          values[normalizedKey] = content
        }
      }

      for key in nameKeys {
        let normalizedKey = canonicalMetaKey(key)
        guard shouldStore(key: normalizedKey, fromProperty: false) else { continue }
        let isArticlePublishedTime = normalizedKey == "article:published_time"
        let isArticleAuthor = normalizedKey == "article:author" || normalizedKey == "og:article:author"
        let range = NSRange(location: 0, length: normalizedKey.utf16.count)
        if Self.metaPropertyKeyRegex.firstMatch(in: normalizedKey, options: [], range: range) != nil || isArticlePublishedTime || isArticleAuthor,
           !content.isEmpty
        {
          values[normalizedKey] = content
        }
      }
    }

    // Extract title
    metadata.title = values["dc:title"] ??
      values["dcterm:title"] ??
      values["og:title"] ??
      values["twitter:title"] ??
      values["parsely-title"] ??
      values["title"]
    if let title = metadata.title {
      metadata.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract byline
    let metaByline = values["dc:creator"] ??
      values["dcterm:creator"] ??
      values["author"]
    let socialByline = values["parsely-author"] ??
      values["weibo:article:author"] ??
      values["weibo:webpage:author"]
    let ogByline = values["article:author"] ??
      values["og:article:author"] ??
      values["twitter:creator"] ??
      values["og:author"]
    metadata.byline = metaByline ?? socialByline ?? ogByline
    metadata.byline = try SiteRuleRegistry.applyMetadataBylineRules(
      metadata.byline,
      sourceURL: sourceURL,
      document: doc
    )

    if var byline = metadata.byline {
      byline = byline.trimmingCharacters(in: .whitespaces)
      if byline.lowercased().hasPrefix("by ") {
        byline = String(byline.dropFirst(3)).trimmingCharacters(in: .whitespaces)
      }
      metadata.byline = byline
    }

    // Extract excerpt
    metadata.excerpt = values["dc:description"] ??
      values["dcterm:description"] ??
      values["og:description"] ??
      values["weibo:article:description"] ??
      values["weibo:webpage:description"] ??
      values["description"] ??
      values["twitter:description"]

    // Extract site name
    metadata.siteName = values["og:site_name"] ??
      values["twitter:site"] ??
      values["dc:publisher"] ??
      values["dcterm:publisher"]

    // Extract published time
    metadata.publishedTime = values["article:published_time"] ??
      values["parsely-pub-date"]

    // Clean up excerpt
    if var excerpt = metadata.excerpt {
      excerpt = excerpt.trimmingCharacters(in: .whitespaces)
      excerpt = excerpt.replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&apos;", with: "'")
      metadata.excerpt = excerpt
    }

    return metadata
  }

  private func canonicalMetaKey(_ raw: String) -> String {
    var key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if key.hasPrefix("dc.") {
      key = "dc:" + key.dropFirst(3)
    } else if key.hasPrefix("dcterm.") {
      key = "dcterm:" + key.dropFirst(7)
    } else if key.hasPrefix("dcterms.") {
      key = "dcterm:" + key.dropFirst(8)
    }
    return key
  }

  private func extractJSONLDMetadata() throws -> Metadata {
    var metadata = Metadata()

    var scripts = try doc.select("script[type=\"application/ld+json\"]")
    if scripts.isEmpty {
      scripts = try doc.select("script[type='application/ld+json']")
    }

    var jsonldObjects: [[String: Any]] = []

    for script in scripts {
      guard let jsonText = try? script.html() else { continue }

      let cleanedText = jsonText
        .replacingOccurrences(of: "<![CDATA[", with: "")
        .replacingOccurrences(of: "]]>", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      guard !cleanedText.isEmpty,
            let data = cleanedText.data(using: .utf8) else { continue }

      do {
        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
          jsonldObjects.append(jsonObject)
        } else if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
          jsonldObjects.append(contentsOf: jsonArray)
        }
      } catch {
        continue
      }
    }

    let preferredTypes = ["NewsArticle", "Article", "WebPage", "BlogPosting"]
    var selectedObject: [String: Any]?

    for type in preferredTypes {
      if let match = jsonldObjects.first(where: { ($0["@type"] as? String)?.lowercased() == type.lowercased() }) {
        selectedObject = match
        break
      }
    }

    if selectedObject == nil, !jsonldObjects.isEmpty {
      selectedObject = jsonldObjects.first
    }

    guard let jsonld = selectedObject else {
      return metadata
    }

    let publisherName = ((jsonld["publisher"] as? [String: Any])?["name"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let jsonldName = (jsonld["name"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let jsonldHeadline = (jsonld["headline"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if let name = jsonldName, !name.isEmpty,
       let publisherName, publisherName.lowercased().contains("wikimedia foundation")
    {
      // Wikimedia pages often store shortdescription in `headline`.
      // Prefer the page `name` to align with Mozilla parity fixtures.
      metadata.title = name
    } else if let headline = jsonldHeadline, !headline.isEmpty {
      metadata.title = headline
    }

    if let description = jsonld["description"] as? String {
      metadata.excerpt = description
    }

    if let datePublished = jsonld["datePublished"] as? String {
      metadata.publishedTime = datePublished
    }

    metadata.byline = extractAuthorFromJSONLD(jsonld["author"])

    if let publisherName, !publisherName.isEmpty {
      metadata.siteName = publisherName
    }

    return metadata
  }

  func isLowQualityMetadataByline(_ byline: String) -> Bool {
    let trimmed = byline.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("@"), trimmed.count > 1 {
      return true
    }

    let lower = trimmed.lowercased()
    if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
      return true
    }
    if lower.contains("facebook.com/") || lower.contains("twitter.com/") {
      return true
    }
    return false
  }

  private func extractAuthorFromJSONLD(_ author: Any?) -> String? {
    guard let author else { return nil }

    if let authorArray = author as? [Any] {
      let names = authorArray.compactMap { extractAuthorFromJSONLD($0) }
      return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    if let authorString = author as? String {
      return authorString
    }

    if let authorObject = author as? [String: Any],
       let name = authorObject["name"] as? String
    {
      return name
    }

    return nil
  }

  func detectSourceURL() -> URL? {
    if let canonicalHref = try? doc.select("link[rel=canonical]").first()?.attr("href"),
       let canonical = canonicalHref.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
       !canonical.isEmpty,
       let url = URL(string: canonical)
    {
      return url
    }

    if let ogURL = try? doc.select("meta[property=og:url]").first()?.attr("content"),
       let ogURLTrimmed = ogURL.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
       !ogURLTrimmed.isEmpty,
       let url = URL(string: ogURLTrimmed)
    {
      return url
    }

    let location = doc.location().trimmingCharacters(in: .whitespacesAndNewlines)
    if !location.isEmpty, let url = URL(string: location) {
      return url
    }
    return nil
  }
}
