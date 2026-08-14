import Foundation

/// The data-driven half of the site-rule corpus: every rule here is a plain
/// host gate + selector + action (+ optional guard), registered in
/// `SiteRuleRegistry` at the same pipeline position a bespoke type would be.
///
/// Entry conventions match bespoke rules: stable `id`, apex `hosts`.
/// A rule that outgrows this vocabulary moves back to a bespoke `SiteRule`
/// type in `Rules/` — do not extend `DeclarativeSiteRule` with one-off
/// actions to keep a rule in the table.
enum DeclarativeSiteRules {

  // MARK: - Unwanted-elements phase

  static let antirezDisqusFooter = DeclarativeSiteRule(
    id: "antirez-disqus-footer",
    hosts: ["antirez.com"],
    steps: [
      .init("p:has(a[href*='disqus.com'])", .remove, guards: [.textEquals("blog comments powered by disqus")]),
      .init("a.dsq-brlink[href*='disqus.com']", .remove),
      .init("div#disqus_thread_outdiv, div#disqus_thread", .remove)
    ]
  )

  static let yahooSlideshowModal = DeclarativeSiteRule(
    id: "yahoo-slideshow-modal",
    hosts: ["yahoo.com"],
    steps: [.init("div[id^=modal-slideshow-]", .remove)]
  )

  static let bbcVideoPlaceholder = DeclarativeSiteRule(
    id: "bbc-video-placeholder",
    hosts: ["bbc.com", "bbc.co.uk"],
    steps: [
      .init("div.media-placeholder[data-media-type=video], div[data-media-type=video][class*=media-placeholder]", .remove)
    ]
  )

  static let aktualneTwitterEmbed = DeclarativeSiteRule(
    id: "aktualne-twitter-embed",
    hosts: ["aktualne.cz"],
    steps: [.init("div[id^=twttr_], div.codefragment--twitter", .remove)]
  )

  static let aktualneInlinePhoto = DeclarativeSiteRule(
    id: "aktualne-inline-photo",
    hosts: ["aktualne.cz"],
    steps: [.init("div.article__photo", .remove)]
  )

  static let qqSharePanel = DeclarativeSiteRule(
    id: "qq-share-panel",
    hosts: ["qq.com"],
    steps: [
      .init("div#shareBtn", .remove),
      .init("#rv-player div.mbArticleSharePic", .unwrapElements),
      .init("#rv-player div.rv-player-adjust-img", .unwrapElements),
      .init("#rv-player .rv-top, #rv-player .rv-player-wrap, #rv-player .rv-playlist", .remove),
      .init(".correlation-Article-QQ > :not(#vote)", .remove)
    ]
  )

  static let heraldSunReadMoreLink = DeclarativeSiteRule(
    id: "herald-sun-read-more-link",
    hosts: ["heraldsun.com.au"],
    steps: [.init("div#read-more-link", .remove)]
  )

  static let liberationRelatedAside = DeclarativeSiteRule(
    id: "liberation-related-aside",
    hosts: ["liberation.fr"],
    steps: [.init("aside#related-content", .remove)]
  )

  static let liberationAuthorsContainer = DeclarativeSiteRule(
    id: "liberation-authors-container",
    hosts: ["liberation.fr"],
    steps: [.init("#article-body > div.authors-container", .remove)]
  )

  static let nytimesLivePanels = DeclarativeSiteRule(
    id: "nytimes-live-panels",
    hosts: ["nytimes.com"],
    steps: [
      .init("div", .remove, guards: [
        .minMatches("> ol[aria-live=off]", count: 1),
        .minMatches("> ol > li", count: 3)
      ])
    ]
  )

  static let cnnLegacyStoryTop = DeclarativeSiteRule(
    id: "cnn-legacy-storytop",
    hosts: ["cnn.com"],
    steps: [
      .init("div#js-ie-storytop, div.ie--storytop, div#ie_column", .remove),
      .init("div", .remove, guards: [.textEquals("advertising inread invented by teads")])
    ]
  )

  static let medicalNewsTodayRelatedInline = DeclarativeSiteRule(
    id: "medicalnewstoday-related-inline",
    hosts: ["medicalnewstoday.com"],
    steps: [
      .init("div.related_inline, h2.suggested_reading, h2.internal_related, div.suggested_reading_container, div.suggested_reading_inner", .remove)
    ]
  )

  static let cityLabPromoSignup = DeclarativeSiteRule(
    id: "citylab-promo-signup",
    hosts: ["citylab.com"],
    precondition: "meta[itemprop=name][content=\"CityLab\"], meta[itemprop=mainEntityOfPage][content*=citylab.com]",
    steps: [.init("form#promo-email, form[name=promo-email]", .remove)]
  )

  static let wikipediaLeadMetaNoise = DeclarativeSiteRule(
    id: "wikipedia-lead-meta-noise",
    hosts: ["wikipedia.org"],
    steps: [
      .init(".mw-parser-output > div.shortdescription", .remove),
      .init(".mw-parser-output > div.hatnote[role='note']", .remove)
    ]
  )

  static let firefoxNightlyCommentForm = DeclarativeSiteRule(
    id: "firefox-nightly-comment-form",
    hosts: ["nightly.mozilla.org"],
    steps: [
      .init(
        "div#comments form, div#comments div#respond, div#comments p.comment-form-comment, "
          + "div#comments p.comment-form-author, div#comments p.comment-form-email, "
          + "div#comments p.form-allowed-tags, div#comments p.form-submit",
        .remove
      ),
      // Some layouts flatten comment form wrappers and drop their original IDs;
      // fall back to stable WordPress endpoint markers.
      .init("form#comment-form, form[action*=\"wp-comments-post.php\"], input#comment_post_ID, textarea#comment", .remove),
      .init("div#respond, h3#reply-title, p#cancel-comment-reply", .remove)
    ]
  )

  static let simplyFoundMediaContainer = DeclarativeSiteRule(
    id: "simplyfound-media-container",
    hosts: ["simplyfound.com"],
    precondition: "div[id^=snippet-][id$=-image-carousel]",
    steps: [.init("div.media-container", .remove)]
  )

  static let pixnetArticleKeyword = DeclarativeSiteRule(
    id: "pixnet-article-keyword",
    hosts: ["pixnet.net"],
    steps: [.init("div.article-keyword", .remove)]
  )

  // MARK: - Post-process phase

  static let nytimesPhotoViewerWrapper = DeclarativeSiteRule(
    id: "nytimes-photoviewer-wrapper",
    hosts: ["nytimes.com"],
    steps: [.init("div[data-testid=photoviewer-wrapper] > div[data-testid=photoviewer-children]", .unwrap)]
  )

  static let engadgetBuyLink = DeclarativeSiteRule(
    id: "engadget-buy-link",
    hosts: ["engadget.com"],
    steps: [.init("a[href*=/buylink/]", .remove)]
  )

  static let liberationArticleBodyWrapper = DeclarativeSiteRule(
    id: "liberation-article-body-wrapper",
    hosts: ["liberation.fr"],
    steps: [
      .init("section#news-article article #article-body > div", .unwrapElements, guards: [
        .minMatches("p", count: 2)
      ])
    ]
  )

  static let mercurialExampleSection = DeclarativeSiteRule(
    id: "mercurial-example-1-section",
    hosts: ["mercurial-scm.org"],
    precondition: "#evolve-shared-mutable-history",
    steps: [.init("#example-1-amend-a-shared-changeset", .remove)]
  )

  static let ebbPreviousLink = DeclarativeSiteRule(
    id: "ebb-previous-link",
    hosts: ["ebb.org"],
    steps: [.init("div#prevlink", .remove, guards: [.textContains("previous")])]
  )
}
