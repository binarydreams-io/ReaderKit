# ReaderKit

[![CI](https://github.com/binarydreams-io/ReaderKit/actions/workflows/ci.yml/badge.svg)](https://github.com/binarydreams-io/ReaderKit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/binarydreams-io/ReaderKit)](https://github.com/binarydreams-io/ReaderKit/releases)

ReaderKit is a Swift SDK for native reading apps on Apple platforms.
It downloads a web page, extracts the article, converts HTML into typed blocks, and renders those blocks with SwiftUI.
The complete pipeline uses no `WKWebView`, JavaScript runtime, CSS, or HTML-backed attributed string.

The extraction engine is a Swift port of the original JavaScript
[Mozilla Readability](https://github.com/mozilla/readability).
ReaderKit adds host-gated site rules, structured inspection reports, and a native `RichText` renderer.

Version `0.1.0` uses Swift tools 6.2.
It supports iOS 17 or later and macOS 14 or later.

## Three Products

ReaderKit exposes three library products from one package:

| Product | Use it when you need |
| --- | --- |
| `ReaderKit` | A complete URL-to-SwiftUI reader through `ReaderView` |
| `Readability` | Article extraction, metadata, cleaned HTML, or inspection data |
| `RichText` | Typed article blocks or native rendering for HTML you already have |

Applications can use each product independently.
The umbrella `ReaderKit` product publicly imports the other two products.

## Installation

Add ReaderKit to your package:

```swift
.package(
  url: "https://github.com/binarydreams-io/ReaderKit",
  from: "0.1.0"
)
```

Add only the product that your target needs:

```swift
.product(name: "ReaderKit", package: "ReaderKit")
.product(name: "Readability", package: "ReaderKit")
.product(name: "RichText", package: "ReaderKit")
```

## Native Reader SDK

Use `ReaderView` for the complete pipeline:

```swift
import ReaderKit
import SwiftUI

struct ArticleScreen: View {
  let url: URL

  var body: some View {
    ScrollView {
      ReaderView(
        link: url,
        style: ReaderStyle(
          textColor: .primary,
          secondaryTextColor: .secondary,
          linkColor: .green,
          fontDesign: .serif,
          baseFontSize: 18,
          lineSpacing: 9
        )
      )
      .padding(24)
    }
  }
}
```

`ReaderView` fetches the URL with `URLSession.shared`.
It detects common legacy character encodings before extraction.
It then passes a cleaned DOM directly from Readability to RichText without an HTML serialization round trip.

The view sizes to its content.
Place it in your application's `ScrollView` and supply the surrounding navigation, title, and controls.
Changing `ReaderStyle` updates the SwiftUI view without another network request or extraction pass.

Read the [ReaderKit API guide](Documentation/ReaderKit.md) for integration details.

## Readability Port

Use `Readability` when your app controls networking or stores article HTML:

```swift
import Readability

let extractor = try Readability(
  html: html,
  baseURL: articleURL,
  options: .default
)
let article = try extractor.parse()

print(article.title)
print(article.byline ?? "Unknown author")
print(article.content)
```

The port includes:

- Main-content scoring and sibling merging.
- Metadata from JSON-LD, Open Graph, Twitter Cards, Dublin Core, and document titles.
- Relative URL resolution for links, images, source sets, and posters.
- Cleanup for navigation, social controls, ads, related content, and malformed article markup.
- Host-gated rules for sites that need behavior beyond the generic algorithm.
- Retry passes for short or unusual documents.
- A structured `InspectionReport` for candidate scores, rule decisions, retries, and cleanup stages.
- A `~Copyable` single-use parser that keeps the mutable DOM inside the extraction boundary.

Pass `baseURL` when you know it.
Readability uses this URL for relative links and host-gated rules.

Read the complete [Readability API guide](Documentation/Readability.md).

## Native RichText

Use `RichText` when your app already has HTML and only needs a native article model or view:

```swift
import RichText
import SwiftUI

let blocks = try RichText(
  html: cleanedHTML,
  baseURL: articleURL
).blocks()

RichTextView(
  blocks: blocks,
  style: ReaderStyle(fontDesign: .serif)
)
```

RichText converts HTML into `[ArticleBlock]` values:

- Headings and paragraphs with native `AttributedString` runs.
- Images with alternative text and captions.
- Block quotes and nested ordered or unordered lists.
- Code blocks with optional language hints.
- Tables with optional header rows.
- Video and link embeds.
- Thematic breaks.

The block model is `Sendable` and independent of presentation settings.
`RichTextView` renders it as a native, lazy SwiftUI view tree.
NukeUI loads and caches remote images.

Read the complete [RichText API guide](Documentation/RichText.md).

## Architecture

```text
URL or HTML
    |
    v
Readability
    |  ReadabilityResult: metadata, text, cleaned HTML
    |  package-internal DOM handoff
    v
RichText
    |  [ArticleBlock]
    v
RichTextView / ReaderView
    |  native SwiftUI
    v
iOS or macOS reading surface
```

The targets keep each layer usable on its own:

- `Readability` depends only on SwiftSoup.
- `RichText` depends on SwiftSoup and NukeUI.
- `ReaderKit` composes the two layers and owns URL loading and localized states.

## ReaderKit Demo

The complete SwiftUI demo is in `Examples/ReaderKitDemo`.

1. Open `ReaderKitDemo.xcodeproj`.
2. Select the shared `ReaderKitDemo` scheme.
3. Run the iOS or macOS destination.
4. Enter an HTTPS article URL and select **Read**.

The iOS app presents the reader with `fullScreenCover`.
The macOS app opens each article in a new window.
The demo includes Nuwleef-style themes, font selection, text sizing, Liquid Glass controls, and the Binary Dreams green tint.

The demo requires iOS 26 or macOS 26 because Liquid Glass is part of the example design.
This requirement does not increase the package deployment targets.

## Networking

The host app owns its network permissions and App Transport Security policy.
The macOS demo includes the outgoing-network sandbox entitlement.

`ReaderView` accepts any URL that `URLSession` can load.
Applications should validate schemes, credentials, redirects, and private-network access for their threat model.
See [Limitations](LIMITATIONS.md) for the current network and rendering boundaries.

## Verification

Run the package build and tests:

```bash
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
```

Run the full repository check:

```bash
./scripts/quality-gate.sh
```

## License And Attribution

ReaderKit is available under the [Apache License 2.0](LICENSE).
ReaderKit is not an official Mozilla product.

See [Notices](NOTICE.md), [Credits](CREDITS.md), and [Provenance](PROVENANCE.md) for upstream attribution.
See [Changelog](CHANGELOG.md), [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md), and [Code of Conduct](CODE_OF_CONDUCT.md) for project policies.
