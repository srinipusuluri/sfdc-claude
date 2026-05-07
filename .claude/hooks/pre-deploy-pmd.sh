#!/usr/bin/env bash
# PreToolUse — runs PMD before any deploy; blocks on Critical/High findings
set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only intercept deploy commands
if ! echo "$COMMAND" | grep -qE "sf project deploy start|sf project deploy validate|sfdx force:source:deploy"; then
  exit 0
fi

# Skip if PMD_OVERRIDE=1
if [[ "${PMD_OVERRIDE:-}" == "1" ]]; then
  echo "[pre-deploy-pmd] PMD_OVERRIDE=1 — skipping PMD gate (override noted in transcript)" >&2
  exit 0
fi

# Skip if no force-app directory
if [[ ! -d "force-app" ]]; then
  exit 0
fi

# Skip if scanner plugin not installed
if ! sf scanner --version >/dev/null 2>&1; then
  echo "[pre-deploy-pmd] sf scanner not installed — skipping PMD gate" >&2
  exit 0
fi

echo "[pre-deploy-pmd] Running PMD scan before deploy..." >&2

RULESET_FLAG=""
[[ -f ".pmdruleset.xml" ]] && RULESET_FLAG="--pmdconfig .pmdruleset.xml"

SCAN_OUT=$(sf scanner run \
  --target "force-app/**/*.cls,force-app/**/*.trigger" \
  --engine pmd \
  $RULESET_FLAG \
  --severity-threshold 3 \
  --format table 2>&1 || true)

EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "🚫 PMD GATE: Deploy blocked — High/Critical findings present"
  echo ""
  echo "$SCAN_OUT"
  echo ""
  echo "  Fix the findings above, or set PMD_OVERRIDE=1 to bypass (creates an audit trail)."
  echo "  Rules that always block (cannot be overridden by PMD_OVERRIDE):"
  echo "    ApexCRUDViolation · ApexSOQLInjection · ApexSharingViolations"
  echo ""
  # Hard block on security rules regardless of override
  if echo "$SCAN_OUT" | grep -qE "ApexCRUDViolation|ApexSOQLInjection|ApexSharingViolations"; then
    echo "🔴 SECURITY RULE VIOLATION — deploy cannot proceed. Fix required."
    exit 2
  fi
  exit 2
fi

echo "[pre-deploy-pmd] PMD scan passed — no High/Critical findings." >&2
exit 0
