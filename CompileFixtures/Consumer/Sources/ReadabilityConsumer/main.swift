// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Readability

let html = """
<html>
  <head><title>Fixture Article</title></head>
  <body><article><p>A small local article fixture.</p></article></body>
</html>
"""
let result = try Readability(
  html: html,
  options: ReadabilityOptions(minimumCharacterCount: 0)
).parse()

print("Readability consumer: \(result.title)")
