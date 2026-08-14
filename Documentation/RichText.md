# RichText API

The `RichText` product converts article HTML into typed, native content.
You can use the block model without `ReaderView` or the Readability extraction engine.

## Parse HTML Into Blocks

```swift
import RichText

let blocks = try RichText(
  html: articleHTML,
  baseURL: sourceURL
).blocks()
```

```swift
public struct RichText {
  public init(html: String, baseURL: URL? = nil) throws
  public func blocks() throws -> [ArticleBlock]
}
```

Pass `baseURL` to resolve relative image, link, poster, and embed URLs.

## ArticleBlock

`ArticleBlock` is a `Sendable` and `Equatable` enum.

```swift
public enum ArticleBlock: Sendable, Equatable {
  case heading(level: Int, AttributedString)
  case paragraph(AttributedString)
  case image(ArticleImage)
  case blockquote([ArticleBlock])
  case list(ordered: Bool, items: [[ArticleBlock]])
  case codeBlock(code: String, language: String?)
  case table(ArticleTable)
  case embed(ArticleEmbed)
  case thematicBreak
}
```

Inline text uses Swift `AttributedString` values.
RichText maps emphasis, strong text, inline code, deletion, and links to native attributes.

## Payload Types

### ArticleImage

```swift
public struct ArticleImage: Sendable, Equatable {
  public let url: URL
  public let alt: String?
  public let caption: String?

  public init(url: URL, alt: String? = nil, caption: String? = nil)
}
```

### ArticleEmbed

```swift
public struct ArticleEmbed: Sendable, Equatable {
  public enum Kind: Sendable, Equatable {
    case video(posterURL: URL?)
    case link
  }

  public let url: URL
  public let kind: Kind
  public let title: String?

  public init(url: URL, kind: Kind, title: String? = nil)
}
```

### ArticleTable

```swift
public struct ArticleTable: Sendable, Equatable {
  public let rows: [[AttributedString]]
  public let hasHeaderRow: Bool

  public init(rows: [[AttributedString]], hasHeaderRow: Bool)
}
```

## ReaderStyle

`ReaderStyle` contains values that affect native rendering.
It does not affect parsing or the block model.

```swift
public struct ReaderStyle: Sendable, Equatable {
  public var textColor: Color
  public var secondaryTextColor: Color
  public var linkColor: Color
  public var fontDesign: Font.Design
  public var baseFontSize: CGFloat
  public var lineSpacing: CGFloat

  public init(
    textColor: Color = .primary,
    secondaryTextColor: Color = .secondary,
    linkColor: Color = .accentColor,
    fontDesign: Font.Design = .serif,
    baseFontSize: CGFloat = 18,
    lineSpacing: CGFloat = 9
  )
}
```

The host view supplies the page background.
This separation lets a reading app change themes without rebuilding `[ArticleBlock]`.

## RichTextView

```swift
public struct RichTextView: View {
  public init(blocks: [ArticleBlock], style: ReaderStyle)
}
```

`RichTextView` renders blocks in a leading-aligned `LazyVStack`.
It sizes to its content and does not create a root scroll view.

```swift
ScrollView {
  RichTextView(blocks: blocks, style: style)
    .padding(.horizontal, 24)
}
```

NukeUI loads article images.
Links use SwiftUI's `openURL` environment action.

## Supported HTML

RichText maps common article markup into native blocks:

- `h1` through `h6`.
- Paragraphs and compatible wrapper elements.
- `figure`, `img`, and `figcaption`.
- `blockquote`.
- Ordered and unordered lists, including nested blocks.
- `pre` and `code`.
- Tables and header rows.
- Allowed video embeds and ordinary embed links.
- Horizontal rules.

RichText is an article renderer, not a browser layout engine.
It does not apply site CSS or execute scripts.
