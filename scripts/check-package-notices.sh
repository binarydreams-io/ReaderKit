#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

swift "$SCRIPT_DIR/check-package-notices.swift" \
  "$PROJECT_DIR/Package.resolved" \
  "$PROJECT_DIR/Licenses/Package-Notices.tsv" \
  "$PROJECT_DIR/Licenses" \
  "$PROJECT_DIR/.build/checkouts"
