# Credits

ReaderKit is published by [Binary Dreams, LLC](https://binarydreams.io).

The extraction engine contains an adapted, non-line-for-line Swift
implementation of the original JavaScript
[Mozilla Readability](https://github.com/mozilla/readability) project.
Mozilla and the Readability contributors established the algorithm and official fixture suite.

The Swift implementation incorporates selected work from
[Neo Lee's swift-readability](https://github.com/neolee/swift-readability).

[SwiftSoup](https://github.com/scinfu/SwiftSoup) provides HTML parsing.
[Nuke](https://github.com/kean/Nuke) provides image loading and caching.

Binary Dreams developed the native `RichText` block model, SwiftUI renderer,
`ReaderView` integration layer, extraction architecture, diagnostics, and
subsequent extraction changes.

See [NOTICE.md](NOTICE.md) for license notices and [PROVENANCE.md](PROVENANCE.md) for source history.
