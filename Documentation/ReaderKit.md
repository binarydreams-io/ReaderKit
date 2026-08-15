# ReaderKit API

The `ReaderKit` product provides the complete network-to-SwiftUI integration.
It also publicly imports the `Readability` and `RichText` modules.

## ReaderView

```swift
public struct ReaderView: View {
  public init(link: URL, style: ReaderStyle = .init())
}
```

`ReaderView` performs these operations when `link` changes:

1. It downloads the response with `URLSession.shared`.
2. It decodes the HTML from the response charset, an HTML meta charset, UTF-8, or Latin-1.
3. It extracts the readable DOM with the `Readability` target.
4. It converts the DOM into `[ArticleBlock]` with the `RichText` target.
5. It renders the blocks with `RichTextView`.

`ReaderView` shows localized loading and unavailable states.
The view logs load or extraction failures through the `io.binarydreams.ReaderKit` logging subsystem.

## Layout Contract

`ReaderView` does not create a root scroll view.
It grows to the height of the rendered article.
Place it inside the scroll container that owns the reading screen.

```swift
ScrollView {
  ReaderView(link: url, style: style)
    .frame(maxWidth: 760)
    .padding(.horizontal, 24)
}
```

The host application owns the title, metadata, toolbar, reading progress, and navigation.

## Styling

`ReaderStyle` remains separate from the extracted block state.
Changing the style does not start another network request.

```swift
let style = ReaderStyle(
  textColor: .primary,
  secondaryTextColor: .secondary,
  linkColor: .green,
  fontDesign: .serif,
  baseFontSize: 18,
  lineSpacing: 9
)
```

## Network Policy

`ReaderView` uses `URLSession.shared` and does not expose request configuration.
Use the standalone `Readability` and `RichText` products when you need custom headers, cookies, caching, or offline HTML.

The host app owns these controls:

- URL scheme and credential validation.
- App Transport Security exceptions.
- macOS App Sandbox network entitlements.
- Redirect and private-network policy.
- Response-size limits and caching.

## License

Source files in `Sources/ReaderKit` use the MIT License.
The complete `ReaderKit` product also contains the Apache-licensed `Readability` target.
Distributions must include both project licenses and the applicable third-party notices.

## Related APIs

- [Readability API](Readability.md)
- [RichText API](RichText.md)
- [Limitations](../LIMITATIONS.md)
