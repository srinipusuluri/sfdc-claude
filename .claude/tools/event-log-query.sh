#!/usr/bin/env bash
# Query Salesforce EventLogFile and download log CSVs for analysis.
# Usage: event-log-query.sh --target-org <alias> --event-type <type> --days <n> [--output-dir <dir>]

set -euo pipefail

TARGET_ORG="prod-org"
EVENT_TYPE="ReportExport,Login,DataExport,PermissionSetAssignment"
DAYS=7
OUTPUT_DIR="reports/event-logs-$(date +%Y%m%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org)  TARGET_ORG="$2";  shift 2 ;;
    --event-type)  EVENT_TYPE="$2";  shift 2 ;;
    --days)        DAYS="$2";        shift 2 ;;
    --output-dir)  OUTPUT_DIR="$2";  shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

echo "=== Event Log Query ==="
echo "Org:        $TARGET_ORG"
echo "Event types: $EVENT_TYPE"
echo "Days back:  $DAYS"
echo "Output:     $OUTPUT_DIR"
echo ""

# Build IN clause for event types
IFS=',' read -ra TYPES <<< "$EVENT_TYPE"
IN_CLAUSE=$(printf "'%s'," "${TYPES[@]}")
IN_CLAUSE="${IN_CLAUSE%,}"

# List available log files
echo "--- Available log files ---"
sf data query \
  --query "SELECT Id, EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType IN (${IN_CLAUSE}) AND CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY EventType, LogDate DESC" \
  --target-org "$TARGET_ORG" \
  --json > "$OUTPUT_DIR/log-index.json" 2>&1 || {
    echo "ERROR: Could not query EventLogFile. Is Event Monitoring enabled on this org?"
    exit 1
  }

# Parse IDs and download each log file
python3 - <<EOF
import json, os, subprocess

with open("$OUTPUT_DIR/log-index.json") as f:
    result = json.load(f)

records = result.get("result", {}).get("records", [])
if not records:
    print("No event log files found for the specified types and date range.")
    exit(0)

print(f"Found {len(records)} log files:")
for rec in records:
    print(f"  {rec['EventType']:30s}  {rec['LogDate']}  ({rec['LogFileLength']:,} bytes)")

print()
print("Downloading log files...")
for rec in records:
    fname = f"{rec['EventType']}_{rec['LogDate'][:10]}.csv"
    fpath = os.path.join("$OUTPUT_DIR", fname)
    if os.path.exists(fpath):
        print(f"  Skipping (exists): {fname}")
        continue
    print(f"  Downloading: {fname}")
    try:
        result = subprocess.run(
            ["sf", "api", "request", "rest",
             f"/services/data/v66.0/sobjects/EventLogFile/{rec['Id']}/LogFile",
             "--target-org", "$TARGET_ORG"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0:
            with open(fpath, "w") as out:
                out.write(result.stdout)
            print(f"  Saved: {fpath}")
        else:
            print(f"  FAILED: {result.stderr[:100]}")
    except Exception as e:
        print(f"  ERROR: {e}")

print()
print("Done. Log files saved to: $OUTPUT_DIR")
EOF

echo ""
echo "--- Summary of downloaded files ---"
ls -lh "$OUTPUT_DIR"/*.csv 2>/dev/null || echo "No CSV files downloaded."

echo ""
echo "To analyze a specific file:"
echo "  column -t -s ',' $OUTPUT_DIR/<EventType>_<date>.csv | head -50"
