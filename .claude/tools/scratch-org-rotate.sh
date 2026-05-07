#!/usr/bin/env bash
# Delete expired/old scratch orgs and create a fresh one.
# Inputs (env):
#   SCRATCH_DEF  — definition file (default: config/project-scratch-def.json)
#   ALIAS        — new org alias (default: dev-scratch)
#   DURATION     — days until expiration (default: 7)
#   KEEP_ALIAS   — comma-separated aliases never to delete
# Exit codes:
#   0 — success
#   1 — failure
set -euo pipefail

SCRATCH_DEF="${SCRATCH_DEF:-config/project-scratch-def.json}"
ALIAS="${ALIAS:-dev-scratch}"
DURATION="${DURATION:-7}"
KEEP_ALIAS="${KEEP_ALIAS:-prod-org,uat-org}"

if ! command -v sf >/dev/null 2>&1; then
  echo "error: sf CLI not found" >&2
  exit 1
fi

echo "Rotating scratch orgs — keeping: $KEEP_ALIAS"

# Find expired or old scratch orgs.
sf org list --json | jq -r '
  .result.scratchOrgs[] |
  select(.isExpired == true or (.alias // "") | test("^scratch-"))
  | .alias // .username
' | while read -r alias; do
  if [[ -z "$alias" ]]; then continue; fi
  if [[ ",$KEEP_ALIAS," == *",$alias,"* ]]; then
    echo "  keep: $alias"
    continue
  fi
  echo "  delete: $alias"
  sf org delete scratch -o "$alias" -p || echo "    (skipped — couldn't delete $alias)"
done

echo "Creating new scratch org with alias=$ALIAS, duration=$DURATION days"
sf org create scratch -f "$SCRATCH_DEF" -a "$ALIAS" -y "$DURATION"

echo "Pushing source to $ALIAS"
sf project deploy start -o "$ALIAS"

echo "Done. New scratch org: $ALIAS"
