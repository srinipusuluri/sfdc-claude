#!/usr/bin/env bash
# PreToolUse — blocks production deploys without explicit confirmation
set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only intercept deploy commands
if ! echo "$COMMAND" | grep -qE "sf project deploy start|sfdx force:source:deploy"; then
  exit 0
fi

# Validations are safe — allow
if echo "$COMMAND" | grep -q "validate"; then
  exit 0
fi

# Check if targeting production
TARGETS_PROD=0
if echo "$COMMAND" | grep -qE "\-\-target-org\s+prod-org|--target-org\s+production"; then
  TARGETS_PROD=1
fi

# Allow if env override is set (explicit human decision)
if [[ "${PROD_DEPLOY_CONFIRMED:-}" == "1" ]]; then
  echo "[pre-deploy-check] PROD_DEPLOY_CONFIRMED=1 — allowing deploy with override" >&2
  exit 0
fi

if [[ "$TARGETS_PROD" -eq 1 ]]; then
  echo "🚫 PRODUCTION DEPLOY BLOCKED"
  echo ""
  echo "  Command detected: sf project deploy start targeting prod-org"
  echo "  This is a production org. Automated deploys require explicit confirmation."
  echo ""
  echo "  To proceed, re-run with:"
  echo "    PROD_DEPLOY_CONFIRMED=1 bash -c '<your deploy command>'"
  echo ""
  echo "  Or use the validate-only flag first:"
  echo "    sf project deploy validate --target-org prod-org"
  echo ""
  echo "  Checklist before prod deploy:"
  echo "    □ /org-scan --target-org uat-org passed with no Critical findings"
  echo "    □ Test coverage ≥ 75%"
  echo "    □ PMD scan clean (no High/Critical)"
  echo "    □ Change management ticket approved"
  exit 2  # code 2 = block in Claude Code hooks
fi

exit 0
