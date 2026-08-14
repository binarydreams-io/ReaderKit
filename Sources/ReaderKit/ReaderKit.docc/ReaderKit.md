# ``ReaderKit``

Build a native SwiftUI reading surface from a web URL.

ReaderKit combines the ``Readability`` extraction engine and the ``RichText`` native renderer.
The stack uses `URLSession`, SwiftSoup, `AttributedString`, and SwiftUI without WebKit.

## Overview

Use ``ReaderView`` inside the scroll view that owns your reading screen:

```swift
ScrollView {
  ReaderView(
    link: articleURL,
    style: ReaderStyle(fontDesign: .serif)
  )
  .padding(24)
}
```

The view fetches and extracts content when its URL changes.
Style changes only update native rendering.

Use the standalone `Readability` or `RichText` product when your app controls networking or stores article content.

## Topics

### Reading A URL

- ``ReaderView``
