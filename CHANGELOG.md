# Changelog

ReaderKit follows [Semantic Versioning](https://semver.org/).

## 2.0.0 - 2026-09-23

ReaderKit 2.0 renames public API to follow the Swift API Design Guidelines.
The old names are removed. Use the migration table below to update your code.

### Added

- `ReadabilityResult.publishedDate` parses `publishedTime` as an ISO 8601 date or date-time.
- Doc comments for the public RichText model types, `ReaderStyle`, `ReadabilityResult`, and `InspectionReport`.

### Changed

- **Breaking:** Renamed public API. Replace each 1.x name with its 2.0 name:

  | 1.x | 2.0 |
  | --- | --- |
  | `ReadabilityResult.length` | `ReadabilityResult.textLength` |
  | `ReadabilityOptions.charThreshold` | `ReadabilityOptions.minimumCharacterCount` |
  | `ReadabilityOptions.keepClasses` | `ReadabilityOptions.preservesClasses` |
  | `ReadabilityOptions.allowedVideoRegex` | `ReadabilityOptions.allowedVideoURLPattern` |
  | `ReadabilityError.contentTooShort(actualLength:threshold:)` | `ReadabilityError.contentTooShort(length:minimumLength:)` |
  | `ReadabilityError.elementNotFound(_:)` | `ReadabilityError.elementNotFound(selector:)` |
  | `ReadabilityError.tooManyElements(actual:limit:)` | `ReadabilityError.tooManyElements(count:limit:)` |
  | `ArticleImage.alt`, `ArticleImage.init(url:alt:caption:)` | `ArticleImage.altText`, `ArticleImage.init(url:altText:caption:)` |
  | `InspectionReport.CandidateInfo` | `InspectionReport.Candidate` |
  | `InspectionReport.ContentSnapshotSummary` | `InspectionReport.ContentSnapshot` |
  | `InspectionReport.FinalContentSnapshotSummary` | `InspectionReport.FinalContentSnapshot` |
  | `InspectionReport.CleanupSnapshotSummary` | `InspectionReport.CleanupSnapshot` |
  | `ContentSnapshotSummary.BlockSummary`, `FinalContentSnapshotSummary.BlockSummary` | `InspectionReport.BlockSummary` |
  | `InspectionReport.SiblingDecision.visible` | `InspectionReport.SiblingDecision.isVisible` |
  | `InspectionReport.PassAttempt.accepted` | `InspectionReport.PassAttempt.isAccepted` |
  | `InspectionReport.PassAttempt.charThreshold` | `InspectionReport.PassAttempt.minimumCharacterCount` |

  Patterns that match `ReadabilityError` cases without argument labels continue to work.

- `RichTextView.init(blocks:style:)` uses the default `ReaderStyle` when you omit `style`.
- `ImageBlockView` and `EmbedBlockView` use `scaledToFit()` for images. The layout does not change.
- Resolved SwiftSoup 2.13.9 in the package's own `Package.resolved`. The minimum version stays 2.11.2.
- The release toolchain is now Swift 6.4 with SwiftFormat 0.63.0 and SwiftLint 0.65.1. CI runs on the `xcode-27` GitHub runner. The package still requires Swift tools 6.2.
- The package-notice check no longer pins dependency versions in `Licenses/Package-Notices.tsv`. It verifies that every resolved package has a notice and that each notice matches the license shipped in the resolved checkout, so a dependency bump passes the quality gate without a manifest edit and a license change still fails it.

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
