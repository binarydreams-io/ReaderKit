# Limitations

- ReaderKit supports iOS 17 or later and macOS 14 or later.
- ReaderKit does not support Linux, Windows, watchOS, tvOS, or visionOS.
- `ReaderView` loads public URLs through `URLSession.shared`.
- `ReaderView` does not expose custom headers, cookies, sessions, or offline HTML.
- The host app controls App Transport Security and network entitlements.
- Extraction quality depends on the source HTML and can change when a site changes its markup.
- JavaScript-only content might not exist in the downloaded HTML.
- `ReaderView` loads each response into memory before extraction.
- The default `ReadabilityOptions.maxElementsToParse` value does not limit element count.
- Video embeds open as native links. ReaderKit does not include a video player.
- RichText supports common article blocks. It does not implement arbitrary CSS layout.
