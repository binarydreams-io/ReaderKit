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
