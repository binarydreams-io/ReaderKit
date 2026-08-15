# Provenance

## ReaderKit Source

- Owner: Binary Dreams, LLC
- Public repository: `https://github.com/binarydreams-io/ReaderKit`
- Role: native reader SDK, RichText renderer, and adapted Readability implementation
- License: Apache-2.0 and MIT by file path
- First public release: 1.0.0

The [license section of the README](README.md#license-and-attribution) defines
the applicable license for each path.

Binary Dreams extracted ReaderKit from the private Nuwleef application into
a fresh public history. The extraction excludes private repository metadata
and private application fixtures. The repository separately includes selected
Mozilla Readability fixtures described below.

## Mozilla Readability

- Repository: `https://github.com/mozilla/readability`
- Role: original JavaScript algorithm and official test fixtures
- License: Apache-2.0
- Included source: adapted algorithm behavior and selected official fixtures
- Fixture verification revision: `ab4027a8b37669745016869a37a504727992b2ba`

ReaderKit contains an adapted, non-line-for-line Swift implementation.
It is not an official Mozilla product.
The fixture manifest is in `Tests/ReadabilityTests/Resources/test-pages/PROVENANCE.md`.

## Neo Lee Swift Implementation

- Repository: `https://github.com/neolee/swift-readability`
- Role: Swift implementation reference and selected site-rule work
- License: MIT
- Included source: selected implementation changes adapted before the public extraction

The private application history did not retain one upstream base revision.
ReaderKit preserves the upstream MIT notice in `Licenses/SwiftReadability-MIT.txt`.

## Historical Swift Implementation

- Repository: `https://github.com/lake-of-fire/swift-readability`
- Role: initial Nuwleef implementation, later replaced
- License: BSD-3-Clause
- Included source: none identified in the current ReaderKit tree

An earlier private Nuwleef revision used this implementation. A provenance
audit found no attributable code from it after the Neo Lee replacement.

## Dependencies

| Package | Requirement | Role | License |
| --- | --- | --- | --- |
| SwiftSoup | `2.11.2..<3.0.0` | HTML parsing and DOM operations | MIT |
| Nuke | `13.0.4..<14.0.0` | Native image loading and caching | MIT |

Swift Package Manager fetches these dependencies. ReaderKit does not copy their source into this repository.
ReaderKit preserves their MIT notices in `Licenses/SwiftSoup-MIT.txt` and
`Licenses/Nuke-MIT.txt` for binary distributions.
