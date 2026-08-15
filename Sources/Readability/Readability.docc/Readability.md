# ``Readability``

Extract readable article content and metadata from HTML.

This module is an adapted, non-line-for-line Swift implementation of Mozilla Readability.
It adds host-gated site rules and structured inspection reports.

## Overview

```swift
let extractor = try Readability(
  html: html,
  baseURL: sourceURL
)
let article = try extractor.parse()
```

Each parser instance is single-use.
Pass the source URL to resolve links and enable host-gated rules.

## License

Source files in this module use the Apache License 2.0.
The implementation includes material adapted from Mozilla Readability and
Neo Lee's `swift-readability`. The repository preserves both upstream notices.

## Topics

### Extraction

- ``Readability``
- ``ReadabilityResult``
- ``ReadabilityOptions``
- ``ReadabilityError``

### Diagnostics

- ``InspectionReport``
