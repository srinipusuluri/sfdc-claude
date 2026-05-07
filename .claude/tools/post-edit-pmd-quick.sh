#!/usr/bin/env bash
# PostToolUse hook companion for post-edit-pmd-quick.md.
# Reads the tool-call payload from stdin (JSON), runs PMD on a single file
# if it's an Apex source, and prints findings to the transcript.
set -euo pipefail

PAYLOAD="$(cat)"

# Get the file path from Edit/Write tool input.
FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // ""')"

# Skip non-Apex or non-force-app files.
case "$FILE" in
  */force-app/*.cls|*/force-app/*.trigger) ;;
  *) exit 0 ;;
esac

if ! command -v sf >/dev/null 2>&1; then
  exit 0
fi

set +e
OUT="$(sf scanner run \
  --target "$FILE" \
  --engine pmd \
  --pmdconfig .pmdruleset.xml \
  --severity-threshold 3 \
  --format table 2>&1)"
RC=$?
set -e

if [[ "$RC" -ne 0 ]]; then
  echo "─── PMD (post-edit) ──────────────────────────────────"
  echo "$OUT"
  echo "──────────────────────────────────────────────────────"
fi

# Always exit 0 — surface, don't gate.
exit 0
