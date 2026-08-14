# ``Readability``

Extract readable article content and metadata from HTML.

This module is a Swift port of the original JavaScript Mozilla Readability implementation.
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

## Topics

### Extraction

- ``Readability``
- ``ReadabilityResult``
- ``ReadabilityOptions``
- ``ReadabilityError``

### Diagnostics

- ``InspectionReport``
