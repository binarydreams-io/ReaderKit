import Readability

let html = """
<html>
  <head><title>Fixture Article</title></head>
  <body><article><p>A small local article fixture.</p></article></body>
</html>
"""
let result = try Readability(
  html: html,
  options: ReadabilityOptions(charThreshold: 0)
).parse()

print("Readability consumer: \(result.title)")
