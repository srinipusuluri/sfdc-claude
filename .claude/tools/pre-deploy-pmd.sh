#!/usr/bin/env bash
# PreToolUse hook companion for pre-deploy-pmd.md.
# Reads the tool-call payload from stdin (JSON), checks if the Bash command is a deploy,
# runs PMD on force-app, and exits 2 to block on High/Critical findings.
set -euo pipefail

# Allow override
if [[ "${PMD_OVERRIDE:-0}" == "1" ]]; then
  echo "pre-deploy-pmd: PMD_OVERRIDE=1 — skipping scan." >&2
  exit 0
fi

PAYLOAD="$(cat)"

# Extract the Bash command from the hook payload.
CMD="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""')"

# Only act on deploy-like commands.
if ! printf '%s' "$CMD" | grep -Eq 'sf project deploy (start|validate)|sfdx force:source:deploy'; then
  exit 0
fi

# Validation-only deploys still get scanned — they signal intent to ship.
echo "pre-deploy-pmd: deploy detected, running PMD…" >&2

if ! command -v sf >/dev/null 2>&1; then
  echo "pre-deploy-pmd: sf CLI not found, allowing deploy (cannot scan)." >&2
  exit 0
fi

set +e
sf scanner run \
  --target "force-app/**/*.cls,force-app/**/*.trigger" \
  --engine pmd \
  --pmdconfig .pmdruleset.xml \
  --severity-threshold 3 \
  --format table
RC=$?
set -e

if [[ "$RC" -ne 0 ]]; then
  echo "pre-deploy-pmd: PMD found High/Critical issues. Run /pmd-scan to triage. Re-issue with PMD_OVERRIDE=1 to bypass deliberately." >&2
  exit 2
fi

exit 0
