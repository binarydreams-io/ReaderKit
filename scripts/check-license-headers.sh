#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_READABILITY_FILES="$PROJECT_DIR/Licenses/Readability-Original-Files.txt"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readerkit-headers.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

REPOSITORY_FILES="$TEMP_DIR/repository-files"
git -C "$PROJECT_DIR" ls-files -z --cached --others --exclude-standard > "$REPOSITORY_FILES"
[[ -s "$REPOSITORY_FILES" ]] || {
  printf '%s\n' 'License error: Git returned no repository files' >&2
  exit 1
}

check_header() {
  local relative_path="$1"
  local license="$2"
  local provenance="$3"
  local path="$PROJECT_DIR/$relative_path"

  grep -Fqx "// SPDX-License-Identifier: $license" "$path" || {
    printf 'License error: missing %s SPDX header: %s\n' "$license" "$relative_path" >&2
    exit 1
  }

  case "$provenance" in
    adapted)
      if ! grep -Fqx "// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability." "$path" \
        || ! grep -Fqx '// Modified by Binary Dreams, LLC.' "$path"; then
        printf 'License error: adapted file lacks provenance notices: %s\n' "$relative_path" >&2
        exit 1
      fi
      ;;
    original)
      grep -Fqx '// Copyright 2026 Binary Dreams, LLC.' "$path" || {
        printf 'License error: original file lacks copyright notice: %s\n' "$relative_path" >&2
        exit 1
      }
      ;;
    *)
      printf 'License error: unknown provenance class: %s\n' "$provenance" >&2
      exit 1
      ;;
  esac
}

while IFS= read -r -d '' relative_path; do
  [[ "$relative_path" == *.swift ]] || continue

  case "$relative_path" in
    Package.swift)
      check_header "$relative_path" Apache-2.0 original
      ;;
    scripts/*.swift)
      check_header "$relative_path" Apache-2.0 original
      ;;
    Sources/Readability/*|Tests/ReadabilityTests/*)
      if grep -Fqx "$relative_path" "$ORIGINAL_READABILITY_FILES"; then
        check_header "$relative_path" Apache-2.0 original
      else
        check_header "$relative_path" Apache-2.0 adapted
      fi
      ;;
    Sources/ReaderKit/*|Sources/RichText/*|Tests/ReaderKitTests/*|Tests/RichTextTests/*|CompileFixtures/*|Examples/ReaderKitDemo/ReaderKitDemo/*)
      check_header "$relative_path" MIT original
      ;;
    *)
      printf 'License error: Swift file is outside the license map: %s\n' "$relative_path" >&2
      exit 1
      ;;
  esac
done < "$REPOSITORY_FILES"

while IFS= read -r relative_path; do
  [[ -z "$relative_path" || "$relative_path" == \#* ]] && continue
  git -C "$PROJECT_DIR" ls-files --error-unmatch "$relative_path" >/dev/null || {
    printf 'License error: original-file inventory entry is not tracked: %s\n' "$relative_path" >&2
    exit 1
  }
done < "$ORIGINAL_READABILITY_FILES"
