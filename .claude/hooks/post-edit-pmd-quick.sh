#!/usr/bin/env bash
# PostToolUse — quick PMD scan on a single edited Apex file; surfaces issues inline
set -euo pipefail

PAYLOAD=$(cat)
FILE_PATH=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only act on Apex files inside force-app/
if ! echo "$FILE_PATH" | grep -qE "force-app/.*\.(cls|trigger)$"; then
  exit 0
fi

# Skip if scanner not installed (fail silently — don't disrupt the edit flow)
if ! sf scanner --version >/dev/null 2>&1; then
  exit 0
fi

RULESET_FLAG=""
[[ -f ".pmdruleset.xml" ]] && RULESET_FLAG="--pmdconfig .pmdruleset.xml"

SCAN_OUT=$(sf scanner run \
  --target "$FILE_PATH" \
  --engine pmd \
  $RULESET_FLAG \
  --severity-threshold 3 \
  --format table 2>&1 || true)

# Only print if there are findings (scanner exits non-zero when findings exist)
if [[ $? -ne 0 ]] || echo "$SCAN_OUT" | grep -qE "^[0-9]|\bviolation\b|\bError\b" 2>/dev/null; then
  FILENAME=$(basename "$FILE_PATH")
  echo ""
  echo "⚡ PMD quick-scan — ${FILENAME}"
  echo "$SCAN_OUT" | head -30
  echo "  (Run /pmd-scan for full report | set PMD_OVERRIDE=1 to skip gate at deploy)"
fi

exit 0  # Never block — surface only; pre-deploy-pmd is the gate
