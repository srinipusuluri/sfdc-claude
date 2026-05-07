#!/usr/bin/env bash
# Run Salesforce Code Analyzer (PMD engine) and emit SARIF + a table summary.
# Inputs (env):
#   TARGET           — glob or path to scan (default: force-app)
#   RULESET          — PMD ruleset XML (default: .pmdruleset.xml)
#   SEVERITY_THRESHOLD — 1..5, exit non-zero at or above (default: 3)
#   OUT_SARIF        — output path (default: reports/pmd.sarif)
# Output:
#   SARIF file at $OUT_SARIF, table to stdout.
# Exit codes:
#   0 — clean (or all findings below threshold)
#   1 — scanner / tooling error
#   2 — findings at or above threshold
set -euo pipefail

TARGET="${TARGET:-force-app/**/*.cls,force-app/**/*.trigger}"
RULESET="${RULESET:-.pmdruleset.xml}"
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-3}"
OUT_SARIF="${OUT_SARIF:-reports/pmd.sarif}"

mkdir -p "$(dirname "$OUT_SARIF")"

if ! command -v sf >/dev/null 2>&1; then
  echo "error: sf CLI not found in PATH" >&2
  exit 1
fi

if ! sf scanner --help >/dev/null 2>&1; then
  echo "error: @salesforce/sfdx-scanner not installed. Run: sf plugins install @salesforce/sfdx-scanner" >&2
  exit 1
fi

if [[ ! -f "$RULESET" ]]; then
  echo "warn: $RULESET not found — scanner will use built-in defaults" >&2
  RULESET_ARG=""
else
  RULESET_ARG="--pmdconfig $RULESET"
fi

set +e
sf scanner run \
  --target "$TARGET" \
  --engine pmd \
  $RULESET_ARG \
  --severity-threshold "$SEVERITY_THRESHOLD" \
  --format sarif \
  --outfile "$OUT_SARIF"
SCAN_EXIT=$?
set -e

# Always print a table summary too.
sf scanner run \
  --target "$TARGET" \
  --engine pmd \
  $RULESET_ARG \
  --format table || true

exit "$SCAN_EXIT"
