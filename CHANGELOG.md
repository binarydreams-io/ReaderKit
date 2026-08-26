# Changelog

ReaderKit follows [Semantic Versioning](https://semver.org/).

## Unreleased

## 1.1.1 - 2026-08-26

### Changed

- Resolved Nuke 13.2.0 in the package's own `Package.resolved`; the minimum version stays 13.0.4.

## 1.1.0 - 2026-08-26

### Added

- Telegram posts read in `ReaderView`: a `t.me/<channel>/<id>` link now fetches the server-rendered `?embed=1` page, and a `t.me` site rule rebuilds the post from it — text as paragraphs, photos and videos as media, the "Forwarded from" line, and the channel name as the byline. The public post page carries no message text, so the reader used to show only the widget's "Copy" link.

### Changed

- Defined Apache-2.0 and MIT license scopes by component and added distribution notices.

## 1.0.0 - 2026-08-15

### Added

- Published `ReaderKit`, `Readability`, and `RichText` as separate library products.
- Added the native SwiftUI `ReaderView` SDK surface.
- Added the Readability extraction engine and inspection reports.
- Added the RichText block model, HTML parser, and native SwiftUI renderer.
- Added a cross-platform ReaderKit demo for iOS and macOS.
- Added DocC and repository documentation for all three products.
