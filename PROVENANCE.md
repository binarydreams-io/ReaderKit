# Provenance

## ReaderKit Source

- Owner: Binary Dreams, LLC
- Public repository: `https://github.com/binarydreams-io/ReaderKit`
- Role: native reader SDK, RichText renderer, and maintained Swift port
- License: Apache-2.0
- First public release: 0.1.0

Binary Dreams extracted ReaderKit from the private Nuwleef application into a fresh public history.
The extraction excludes private repository metadata and captured third-party web pages.

## Mozilla Readability

- Repository: `https://github.com/mozilla/readability`
- Role: original JavaScript algorithm and official test fixtures
- License: Apache-2.0
- Included source: algorithm behavior ported to Swift and selected official fixtures

ReaderKit is a port, not an official Mozilla product.

## Neo Lee Swift Port

- Repository: `https://github.com/neolee/swift-readability`
- Role: Swift implementation reference and selected site-rule work
- License: MIT
- Included source: selected implementation changes adapted before the public extraction

The private application history did not retain one upstream base revision.
ReaderKit preserves the upstream MIT notice in `Licenses/SwiftReadability-MIT.txt`.

## Dependencies

| Package | Requirement | Role | License |
| --- | --- | --- | --- |
| SwiftSoup | `2.11.2..<3.0.0` | HTML parsing and DOM operations | MIT |
| Nuke | `13.0.4..<14.0.0` | Native image loading and caching | MIT |

Swift Package Manager fetches these dependencies. ReaderKit does not copy their source into this repository.
