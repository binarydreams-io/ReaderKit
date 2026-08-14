import Foundation
import SwiftSoup

extension Readability {
  /// Everything the extraction pipeline produces, before the cleaned DOM is
  /// serialized. `parse()` serializes `cleaned`; `extractContent()` returns it.
  struct ExtractedCore {
    var metadata: Metadata
    var title: String
    var byline: String?
    var dir: String?
    var lang: String?
    var textContent: String
    var excerpt: String?
    var cleaned: Element
  }

  /// Orchestrates the full extraction pipeline: metadata → document prep → candidate extraction →
  /// cleanup. Shared by `parse()`/`parseWithInspection()` (which serialize the result)
  /// and `extractContent()` (which returns the cleaned DOM directly).
  func extractCore(inspectionContext: InspectionContext?) throws -> ExtractedCore {
    let sourceURL = detectSourceURL()

    try Task.checkCancellation()

    // Match Mozilla: upgrade lazy/placeholder images from <noscript> first.
    try unwrapNoscriptImages()

    // Intentional Mozilla deviation: some script-heavy pages ship the full
    // readable article only inside a semantic <noscript> fallback.
    // Promote those narrowly-scoped fallbacks before prepDocument()
    // removes remaining <noscript> nodes.
    try promoteReadableNoscriptFallbacks()

    try Task.checkCancellation()

    // Extract metadata BEFORE prepDocument() to preserve JSON-LD scripts
    let metadata = try extractMetadata()

    // Prepare document (remove scripts, styles, etc.)
    try prepDocument()

    // Prune known comment/discussion platform containers before extraction.
    // Must run before candidate scoring so noise never enters the pool.
    try SiteRuleRegistry.applyPreExtractionDocumentRules(to: doc, sourceURL: sourceURL)

    try Task.checkCancellation()

    // Use metadata title if available, otherwise extract from document
    let title: String = if let metaTitle = metadata.title {
      metaTitle
    } else {
      try extractTitle()
    }

    // Prepared copies from the acceptance evaluator, keyed by the raw
    // extraction element's identity. The accepted attempt reuses its copy in
    // `cleanArticleContent` instead of running the whole prepArticle pipeline
    // a second time on the original.
    var preparedContentCache: [ObjectIdentifier: (flags: UInt32, element: Element)] = [:]

    // Capture by value into the escaping evaluator closure — `Readability` is ~Copyable
    // and borrowed `self` cannot be captured by escaping closures.
    let evaluatorOptions = options
    let measurePreparedTextLength: (Element, UInt32) throws -> Int = { articleContent, flags in
      guard let preparedCopy = articleContent.copy() as? Element else {
        return try articleContent.text().count
      }

      let cleaner = ArticleCleaner(
        options: evaluatorOptions,
        allowConditionalCleaning: flags & Configuration.flagCleanConditionally != 0,
        allowWeightClasses: flags & Configuration.flagWeightClasses != 0,
        sourceURL: sourceURL
      )
      try cleaner.prepArticle(preparedCopy)
      preparedContentCache[ObjectIdentifier(articleContent)] = (flags, preparedCopy)
      return try preparedCopy.text().count
    }

    // Extract article content using new ContentExtractor
    let extractor = ContentExtractor(
      doc: doc,
      options: options,
      articleTitle: title,
      sourceURL: sourceURL,
      acceptanceTextLengthEvaluator: measurePreparedTextLength,
      inspectionContext: inspectionContext
    )
    let initialExtraction: (content: Element, byline: String?, neededToCreate: Bool, dir: String?, lang: String?, flags: UInt32)
    do {
      initialExtraction = try extractor.extract()
    } catch let ReadabilityError.contentTooShort(actualLength, threshold) {
      guard let recoveredContent = try SiteRuleRegistry.shortContentFallbackArticle(
        in: doc,
        sourceURL: sourceURL,
        inspectionContext: inspectionContext
      ) else {
        throw ReadabilityError.contentTooShort(
          actualLength: actualLength,
          threshold: threshold
        )
      }

      let documentLanguage = (try? doc.select("html").first()?.attr("lang"))
        ?? nil
      initialExtraction = (
        content: recoveredContent,
        byline: nil,
        neededToCreate: false,
        dir: nil,
        lang: documentLanguage?.trimmingCharacters(in: .whitespacesAndNewlines),
        flags: Configuration.flagStripUnlikelies |
          Configuration.flagWeightClasses |
          Configuration.flagCleanConditionally
      )
    }

    func cleanArticleContent(
      _ rawContent: Element,
      flags: UInt32,
      snapshotPrefix: String? = nil
    ) throws -> (content: Element, text: String) {
      // Reuse the acceptance evaluator's prepared copy when possible. Skipped
      // under inspection so the per-stage prep snapshots are still recorded.
      let articleContent: Element
      let needsPrep: Bool
      if inspectionContext == nil,
         let cached = preparedContentCache[ObjectIdentifier(rawContent)],
         cached.flags == flags
      {
        articleContent = cached.element
        needsPrep = false
      } else {
        articleContent = rawContent
        needsPrep = true
      }

      let cleaner = ArticleCleaner(
        options: options,
        allowConditionalCleaning: flags & Configuration.flagCleanConditionally != 0,
        allowWeightClasses: flags & Configuration.flagWeightClasses != 0,
        sourceURL: sourceURL
      ) { stage, element in
        let stageName: String = if let snapshotPrefix {
          "\(snapshotPrefix).\(stage)"
        } else {
          stage
        }
        inspectionContext?.recordCleanupSnapshot(stage: stageName, articleContent: element)
      }
      if needsPrep {
        try cleaner.prepArticle(articleContent)
      }
      inspectionContext?.recordCleanupSnapshot(
        stage: snapshotPrefix.map { "\($0).after-prepArticle" } ?? "after-prepArticle",
        articleContent: articleContent
      )
      try cleaner.postProcessArticle(articleContent)
      inspectionContext?.recordCleanupSnapshot(
        stage: snapshotPrefix.map { "\($0).after-postProcessArticle" } ?? "after-postProcessArticle",
        articleContent: articleContent
      )
      try removeTitleMatchedHeaders(from: articleContent, title: title)
      inspectionContext?.recordCleanupSnapshot(
        stage: snapshotPrefix.map { "\($0).after-removeTitleMatchedHeaders" } ?? "after-removeTitleMatchedHeaders",
        articleContent: articleContent
      )
      try cleaner.trimBoundaryNonContent(articleContent)
      inspectionContext?.recordCleanupSnapshot(
        stage: snapshotPrefix.map { "\($0).after-trimBoundaryNonContent" } ?? "after-trimBoundaryNonContent",
        articleContent: articleContent
      )
      return try (articleContent, articleContent.text())
    }

    try Task.checkCancellation()

    var rawArticleContent = initialExtraction.content
    var extractedByline = initialExtraction.byline
    var articleDir = initialExtraction.dir
    var articleLang = initialExtraction.lang
    let extractionFlags = initialExtraction.flags
    var (articleContent, textContent) = try cleanArticleContent(rawArticleContent, flags: extractionFlags)

    let shouldKeepTextlessContent = try SiteRuleRegistry.shouldKeepTextlessArticleContent(
      articleContent,
      sourceURL: sourceURL,
      document: doc
    )
    if textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !shouldKeepTextlessContent {
      for (index, attempt) in extractor.getAttemptsSortedByTextLength().enumerated() {
        if attempt.articleContent === rawArticleContent {
          continue
        }

        try Task.checkCancellation()

        let (candidateContent, candidateTextContent) = try cleanArticleContent(
          attempt.articleContent,
          flags: attempt.flags,
          snapshotPrefix: "retry\(index + 1)"
        )
        if candidateTextContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          continue
        }

        rawArticleContent = attempt.articleContent
        articleContent = candidateContent
        extractedByline = attempt.byline
        articleDir = attempt.dir
        articleLang = attempt.lang
        textContent = candidateTextContent
        break
      }
    }

    // Extract excerpt: use metadata if available, otherwise from article
    let excerpt: String?
    if let metaExcerpt = metadata.excerpt {
      excerpt = metaExcerpt
    } else {
      let extractedExcerpt = try extractExcerpt(from: articleContent)
      excerpt = try SiteRuleRegistry.applyExcerptRules(
        extractedExcerpt,
        articleContent: articleContent,
        sourceURL: sourceURL,
        document: doc
      )
    }

    // Keep Mozilla-compatible page wrapper shape under the article container.
    // This guarantees the exported content starts with a page DIV wrapper.
    let pageWrapper = try doc.createElement("div")
    try pageWrapper.attr("id", "readability-page-1")
    try pageWrapper.attr("class", "page")

    while let firstChild = articleContent.getChildNodes().first {
      try pageWrapper.appendChild(firstChild)
    }
    try articleContent.appendChild(pageWrapper)

    try Task.checkCancellation()

    // Produce the cleaned DOM subtree once; both parse() and extractContent() use it.
    let cleaned = try cleanForOutput(articleContent, sourceURL: sourceURL)

    // Byline site rules extract text from `doc`, and their output depends on the
    // document's non-pretty output settings. Serialization used to set this as a
    // side effect before the byline pass ran; now that the byline pass can run
    // without serializing (extractContent), set it explicitly so parse() output
    // stays byte-identical and extractContent() sees the same document state.
    doc.outputSettings().prettyPrint(pretty: false)

    // Prefer metadata byline by default (Mozilla behavior), but avoid
    // low-quality metadata values when richer extracted byline exists.
    let byline: String? = if let metadataByline = metadata.byline {
      if isLowQualityMetadataByline(metadataByline) {
        if let extractedByline,
           !extractedByline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
          extractedByline
        } else {
          nil
        }
      } else {
        metadataByline
      }
    } else {
      extractedByline
    }
    let finalByline = try SiteRuleRegistry.applyBylineRules(
      byline,
      sourceURL: sourceURL,
      document: doc
    )

    return ExtractedCore(
      metadata: metadata,
      title: title,
      byline: finalByline,
      dir: articleDir,
      lang: articleLang,
      textContent: textContent,
      excerpt: excerpt,
      cleaned: cleaned
    )
  }

  /// Run extraction and serialize the cleaned DOM to an HTML string.
  /// Used by `parse()` and `parseWithInspection()`.
  func executeParse(inspectionContext: InspectionContext?) throws -> ReadabilityResult {
    let core = try extractCore(inspectionContext: inspectionContext)
    let content = try serializeCleaned(core.cleaned)
    return ReadabilityResult(
      title: core.title,
      byline: core.byline,
      dir: core.dir,
      lang: core.lang,
      content: content,
      textContent: core.textContent,
      excerpt: core.excerpt,
      siteName: core.metadata.siteName,
      publishedTime: core.metadata.publishedTime
    )
  }
}
