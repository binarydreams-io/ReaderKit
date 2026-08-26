#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/toolchain.env"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readerkit-quality.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

resolved_hash() {
  shasum -a 256 "$PROJECT_DIR/Package.resolved" | cut -d ' ' -f 1
}

ACTUAL_SWIFT="$(swift --version | sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p')"
[[ "$ACTUAL_SWIFT" == "$SWIFT_VERSION" ]] || {
  printf 'Quality error: expected Swift %s, found %s\n' "$SWIFT_VERSION" "$ACTUAL_SWIFT" >&2
  exit 1
}

if git -C "$PROJECT_DIR" ls-files | grep -E '(^|/)\.DS_Store$'; then
  printf '%s\n' "Quality error: tracked .DS_Store found" >&2
  exit 1
fi

SECRET_PATTERN='AK''IA[0-9A-Z]{16}|AS''IA[0-9A-Z]{16}|AI''za[0-9A-Za-z_-]{35}|gh[pousr]''_[A-Za-z0-9_]{20,}|github_pat''_[A-Za-z0-9_]{20,}|xox[baprs]''-[A-Za-z0-9-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
if git -C "$PROJECT_DIR" grep -I -n -E "$SECRET_PATTERN" -- . \
  || git -C "$PROJECT_DIR" grep --untracked -I -n -E "$SECRET_PATTERN" -- .; then
  printf '%s\n' "Quality error: repository credential pattern found" >&2
  exit 1
fi

PACKAGE_RESOLVED_HASH="$(resolved_hash)"
swift package --package-path "$PROJECT_DIR" resolve
[[ "$(resolved_hash)" == "$PACKAGE_RESOLVED_HASH" ]] || {
  printf '%s\n' 'Quality error: dependency resolution changed Package.resolved' >&2
  exit 1
}
"$SCRIPT_DIR/check-package-notices.sh"

LICENSE_FILES=(
  "LICENSE"
  "LICENSE-MIT"
  "NOTICE.md"
  "Licenses/Package-Notices.tsv"
  "Licenses/Readability-Original-Files.txt"
  "Licenses/SwiftReadability-MIT.txt"
)
while IFS=$'\t' read -r package license_file; do
  [[ -z "$package" || "$package" == \#* ]] && continue
  LICENSE_FILES+=("Licenses/$license_file")
done < "$PROJECT_DIR/Licenses/Package-Notices.tsv"
for license_file in "${LICENSE_FILES[@]}"; do
  [[ -f "$PROJECT_DIR/$license_file" ]] || {
    printf 'Quality error: required license file missing: %s\n' "$license_file" >&2
    exit 1
  }
done

"$SCRIPT_DIR/copy-license-notices.sh" "$TEMP_DIR/license-notices"
for license_file in "${LICENSE_FILES[@]}"; do
  cmp -s "$PROJECT_DIR/$license_file" "$TEMP_DIR/license-notices/$license_file" || {
    printf 'Quality error: packaged license file differs: %s\n' "$license_file" >&2
    exit 1
  }
done
"$SCRIPT_DIR/check-license-headers.sh"

command -v swiftformat >/dev/null
command -v swiftlint >/dev/null
command -v actionlint >/dev/null
[[ "$(swiftformat --version)" == "$SWIFTFORMAT_VERSION" ]]
[[ "$(swiftlint version)" == "$SWIFTLINT_VERSION" ]]

swiftformat \
  "$PROJECT_DIR/Package.swift" \
  "$PROJECT_DIR/scripts/check-package-notices.swift" \
  "$PROJECT_DIR/Sources" \
  "$PROJECT_DIR/Tests" \
  "$PROJECT_DIR/CompileFixtures" \
  "$PROJECT_DIR/Examples/ReaderKitDemo/ReaderKitDemo" \
  --lint
swiftlint lint --strict --no-cache --config "$PROJECT_DIR/.swiftlint.yml"
actionlint "$PROJECT_DIR"/.github/workflows/*.yml

swift build \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$TEMP_DIR/debug" \
  -Xswiftc -warnings-as-errors
swift build \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$TEMP_DIR/release" \
  -c release \
  -Xswiftc -warnings-as-errors
swift test \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$TEMP_DIR/tests" \
  -Xswiftc -warnings-as-errors

(cd "$PROJECT_DIR" && xcodebuild \
  -scheme ReaderKit \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$TEMP_DIR/package-ios" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build)

xcodebuild \
  -project "$PROJECT_DIR/Examples/ReaderKitDemo/ReaderKitDemo.xcodeproj" \
  -scheme ReaderKitDemo \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$TEMP_DIR/demo-macos" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
xcodebuild \
  -project "$PROJECT_DIR/Examples/ReaderKitDemo/ReaderKitDemo.xcodeproj" \
  -scheme ReaderKitDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TEMP_DIR/demo-ios" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

"$SCRIPT_DIR/verify-consumers.sh"
[[ "$(resolved_hash)" == "$PACKAGE_RESOLVED_HASH" ]] || {
  printf '%s\n' 'Quality error: a build changed Package.resolved' >&2
  exit 1
}
"$SCRIPT_DIR/check-package-notices.sh"

printf '%s\n' "Quality gate passed."
