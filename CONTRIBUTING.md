# Contributing

ReaderKit uses Swift tools 6.2 and the Swift 6 language mode.
The release toolchain is Swift 6.4.

## Development

1. Make a focused change in the applicable target.
2. Add Swift Testing coverage in the matching test target.
3. Use small, synthetic HTML fixtures when possible.
4. Run the focused tests, then run the full package suite.
5. Build the demo when the change affects `ReaderView` or RichText presentation.

```bash
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
xcodebuild \
  -project Examples/ReaderKitDemo/ReaderKitDemo.xcodeproj \
  -scheme ReaderKitDemo \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Do not commit captured web pages without clear redistribution rights.
Remove credentials, cookies, identifiers, and personal data from every fixture.

Update public documentation when a change affects behavior or API.
Update notices and provenance when a change incorporates third-party work.

## Licensing Contributions

By submitting a contribution, you license each changed file under the license
assigned to its destination path in the
[license section of the README](README.md#license-and-attribution).
This path assignment applies only to material that you have the right to license.

Do not submit third-party material unless you have the right to redistribute it.
Preserve all required copyright, license, attribution, and modification notices.

Use conventional commit messages.
Follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Report vulnerabilities through [SECURITY.md](SECURITY.md), not through a public issue.
