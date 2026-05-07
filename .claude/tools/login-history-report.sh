#!/usr/bin/env bash
# Pull and summarize Salesforce login history for security analysis.
# Usage: login-history-report.sh --target-org <alias> --days <n> [--user <username>] [--output-dir <dir>]

set -euo pipefail

TARGET_ORG="prod-org"
DAYS=30
USER_FILTER=""
OUTPUT_DIR="reports/login-history-$(date +%Y%m%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org)  TARGET_ORG="$2";  shift 2 ;;
    --days)        DAYS="$2";        shift 2 ;;
    --user)        USER_FILTER="$2"; shift 2 ;;
    --output-dir)  OUTPUT_DIR="$2";  shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

echo "=== Login History Report ==="
echo "Org:       $TARGET_ORG"
echo "Days back: $DAYS"
[[ -n "$USER_FILTER" ]] && echo "User:      $USER_FILTER"
echo "Output:    $OUTPUT_DIR"
echo ""

run_query() {
  local label="$1"
  local query="$2"
  local outfile="$OUTPUT_DIR/${3}.json"
  echo "--- $label ---"
  sf data query \
    --query "$query" \
    --target-org "$TARGET_ORG" \
    --json > "$outfile" 2>&1 && \
    python3 -c "
import json, sys
with open('$outfile') as f: d = json.load(f)
records = d.get('result', {}).get('records', [])
print(f'  {len(records)} records')
if records:
    keys = [k for k in records[0].keys() if k != 'attributes']
    print('  ' + '  '.join(str(k)[:20] for k in keys[:6]))
    for r in records[:10]:
        vals = [str(r.get(k, ''))[:20] for k in keys[:6]]
        print('  ' + '  '.join(vals))
    if len(records) > 10:
        print(f'  ... ({len(records) - 10} more)')
" || echo "  Query failed — check $outfile"
  echo ""
}

# Failed logins
run_query "Failed Login Attempts (last ${DAYS}d)" \
  "SELECT Username, LoginType, Status, SourceIp, LoginTime, Browser FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:${DAYS} AND Status != 'Success' ORDER BY LoginTime DESC LIMIT 200" \
  "failed-logins"

# Failed logins by IP
run_query "Failed Logins by Source IP" \
  "SELECT SourceIp, COUNT(Id) Attempts FROM LoginHistory WHERE Status != 'Success' AND LoginTime = LAST_N_DAYS:${DAYS} GROUP BY SourceIp ORDER BY Attempts DESC LIMIT 20" \
  "failed-by-ip"

# Weekend logins
run_query "Weekend Logins (last ${DAYS}d)" \
  "SELECT Username, SourceIp, LoginTime, LoginType FROM LoginHistory WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:${DAYS} AND (DAY_ONLY(LoginTime) = SUNDAY OR DAY_ONLY(LoginTime) = SATURDAY) ORDER BY LoginTime DESC LIMIT 100" \
  "weekend-logins"

# High-session users (credential sharing signal)
run_query "Users with >5 Logins in Last 24h" \
  "SELECT Username, COUNT(Id) Sessions FROM LoginHistory WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:1 GROUP BY Username HAVING COUNT(Id) > 5 ORDER BY Sessions DESC" \
  "concurrent-sessions"

# API / OAuth logins
run_query "OAuth/API Logins (last ${DAYS}d)" \
  "SELECT Username, LoginType, SourceIp, COUNT(Id) Count FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:${DAYS} AND LoginType IN ('OAuth 2.0', 'Partner Product', 'Connected App') GROUP BY Username, LoginType, SourceIp ORDER BY Count DESC LIMIT 50" \
  "oauth-logins"

# Country distribution
run_query "Login Countries (last ${DAYS}d)" \
  "SELECT CountryIso, COUNT(Id) Logins FROM LoginHistory WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:${DAYS} GROUP BY CountryIso ORDER BY Logins DESC" \
  "country-distribution"

# Per-user drill-down if --user provided
if [[ -n "$USER_FILTER" ]]; then
  run_query "Login History for ${USER_FILTER}" \
    "SELECT LoginTime, Status, LoginType, SourceIp, Browser, Platform FROM LoginHistory WHERE Username = '${USER_FILTER}' AND LoginTime = LAST_N_DAYS:${DAYS} ORDER BY LoginTime DESC" \
    "user-detail"
fi

# MFA failures
run_query "MFA Verification Failures (last ${DAYS}d)" \
  "SELECT Username, Activity, Status, SourceIp, Timestamp FROM VerificationHistory WHERE Timestamp = LAST_N_DAYS:${DAYS} AND Status != 'Success' ORDER BY Timestamp DESC LIMIT 100" \
  "mfa-failures"

echo "=== Report complete. Files in: $OUTPUT_DIR ==="
echo ""
echo "Files:"
ls -lh "$OUTPUT_DIR"/*.json 2>/dev/null | awk '{print "  " $NF, $5}'
