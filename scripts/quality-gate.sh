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

command -v swiftformat >/dev/null
command -v swiftlint >/dev/null
command -v actionlint >/dev/null
[[ "$(swiftformat --version)" == "$SWIFTFORMAT_VERSION" ]]
[[ "$(swiftlint version)" == "$SWIFTLINT_VERSION" ]]

swiftformat \
  "$PROJECT_DIR/Package.swift" \
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

printf '%s\n' "Quality gate passed."
