#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readerkit-consumers.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

swift build \
  --package-path "$PROJECT_DIR/CompileFixtures/Consumer" \
  --scratch-path "$TEMP_DIR/build" \
  -Xswiftc -warnings-as-errors

for consumer in ReaderKitConsumer ReadabilityConsumer RichTextConsumer; do
  swift run \
    --package-path "$PROJECT_DIR/CompileFixtures/Consumer" \
    --scratch-path "$TEMP_DIR/build" \
    "$consumer"
done

printf '%s\n' "Consumer fixtures passed."
