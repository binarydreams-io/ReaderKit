# Mozilla Fixture Provenance

This directory contains 52 selected fixture directories with 156 test files.
The fixtures entered ReaderKit through Neo Lee's `swift-readability` project.
Their upstream origin is the Mozilla Readability test suite.

- Mozilla repository: `https://github.com/mozilla/readability`
- Verified revision: `ab4027a8b37669745016869a37a504727992b2ba`
- Upstream path: `test/test-pages`
- Neo Lee repository: `https://github.com/neolee/swift-readability`
- Local path: `Tests/ReadabilityTests/Resources/test-pages`

An August 2026 audit found that 154 files matched the verified Mozilla
revision byte for byte. Neo Lee changed two expected-output files in commit
`9f11fbea21c8c1f930b76964da8fa919faa17d08`. ReaderKit preserves those changes:

| File | Preserved change |
| --- | --- |
| `reordering-paragraphs/expected.html` | Removes the trailing `<br id="br2" />` element. |
| `toc-missing/expected.html` | Removes the leading `<hr />` element from the article. |

Each changed file contains its own provenance notice. The test loader
removes only those notices before it compares the expected DOM.

Some `source.html` files capture pages from third-party websites. ReaderKit
did not capture these pages from live websites. It copied them from the
upstream fixture suite for compatibility testing. Copyright statements,
license statements, trademarks, and other notices in those pages remain with
their respective owners. The ReaderKit licenses do not replace those terms.
