# ``RichText``

Convert article HTML into typed blocks and native SwiftUI views.

## Overview

```swift
let blocks = try RichText(
  html: articleHTML,
  baseURL: sourceURL
).blocks()

RichTextView(blocks: blocks, style: ReaderStyle())
```

The block model is independent of rendering settings.
Theme and typography changes do not require another HTML parse.

## License

Source files in this module use the MIT License.
Distributions must also preserve the notices for linked package dependencies.

## Topics

### Parsing

- ``RichText``
- ``ArticleBlock``
- ``ArticleImage``
- ``ArticleEmbed``
- ``ArticleTable``

### Native Rendering

- ``RichTextView``
- ``ReaderStyle``
