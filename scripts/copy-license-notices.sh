#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -ne 1 || -z "$1" ]]; then
  printf 'Usage: %s DESTINATION\n' "$(basename "$0")" >&2
  exit 64
fi

case "$1" in
  /*) DESTINATION="$1" ;;
  *) DESTINATION="$PWD/$1" ;;
esac
LICENSES_DESTINATION="$DESTINATION/Licenses"
PACKAGE_NOTICE_MANIFEST="$PROJECT_DIR/Licenses/Package-Notices.tsv"

mkdir -p "$LICENSES_DESTINATION"
cp "$PROJECT_DIR/LICENSE" "$DESTINATION/LICENSE"
cp "$PROJECT_DIR/LICENSE-MIT" "$DESTINATION/LICENSE-MIT"
cp "$PROJECT_DIR/NOTICE.md" "$DESTINATION/NOTICE.md"
cp "$PACKAGE_NOTICE_MANIFEST" "$LICENSES_DESTINATION/Package-Notices.tsv"
cp "$PROJECT_DIR/Licenses/Readability-Original-Files.txt" "$LICENSES_DESTINATION/Readability-Original-Files.txt"
cp "$PROJECT_DIR/Licenses/SwiftReadability-MIT.txt" "$LICENSES_DESTINATION/SwiftReadability-MIT.txt"

while IFS=$'\t' read -r package _version license_file; do
  [[ -z "$package" || "$package" == \#* ]] && continue
  cp "$PROJECT_DIR/Licenses/$license_file" "$LICENSES_DESTINATION/$license_file"
done < "$PACKAGE_NOTICE_MANIFEST"
