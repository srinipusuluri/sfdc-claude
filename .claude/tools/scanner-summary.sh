#!/usr/bin/env bash
# Parse a SARIF file from sf scanner and emit a human-readable summary grouped by engine.
# Usage:
#   ./scanner-summary.sh reports/scanner.sarif
# Requires: jq
set -euo pipefail

SARIF="${1:-reports/scanner.sarif}"

if [[ ! -f "$SARIF" ]]; then
  echo "error: $SARIF not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq required" >&2
  exit 1
fi

echo "Scanner summary — $SARIF"
echo

# Header
printf "%-15s %-10s %-8s %-8s %-8s\n" "Engine" "Critical" "High" "Medium" "Low"
printf "%-15s %-10s %-8s %-8s %-8s\n" "------" "--------" "----" "------" "---"

jq -r '
  .runs[] |
  {
    engine: (.tool.driver.name // "unknown"),
    results: (.results // [])
  } |
  {
    engine: .engine,
    crit: ([.results[] | select(.level == "error" and (.properties.severity // 0) <= 1)] | length),
    high: ([.results[] | select(.level == "error" and (.properties.severity // 0) == 2)] | length),
    med:  ([.results[] | select(.level == "warning")] | length),
    low:  ([.results[] | select(.level == "note" or .level == "info")] | length)
  } |
  [.engine, .crit, .high, .med, .low] | @tsv
' "$SARIF" | while IFS=$'\t' read -r engine crit high med low; do
  printf "%-15s %-10s %-8s %-8s %-8s\n" "$engine" "$crit" "$high" "$med" "$low"
done

echo
echo "Top 10 findings:"
jq -r '
  [.runs[] | .results[]? |
    {
      rule: (.ruleId // "unknown"),
      level: (.level // "info"),
      file: (.locations[0].physicalLocation.artifactLocation.uri // "?"),
      line: (.locations[0].physicalLocation.region.startLine // 0),
      message: (.message.text // "")
    }
  ] |
  sort_by(.level) |
  .[0:10] |
  .[] |
  "\(.level)\t\(.rule)\t\(.file):\(.line)\t\(.message)"
' "$SARIF"
