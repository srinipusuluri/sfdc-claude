#!/usr/bin/env bash
# Complete Salesforce org scan: limits, Apex exceptions, event logs,
# login anomalies, storage, flow errors, scheduled jobs, setup audit trail.
#
# Usage: org-scan.sh [--target-org <alias>] [--days <n>] [--output <file>]

set -euo pipefail

TARGET_ORG="dev"
DAYS=7
OUTPUT=""
REPORT_DIR="reports/org-scan-$(date +%Y%m%d-%H%M)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org) TARGET_ORG="$2"; shift 2 ;;
    --days)       DAYS="$2";       shift 2 ;;
    --output)     OUTPUT="$2";     shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$REPORT_DIR"
[[ -z "$OUTPUT" ]] && OUTPUT="$REPORT_DIR/org-scan-report.md"

CRITICAL=0
WARNING=0

# ── helpers ──────────────────────────────────────────────────────────────────

run_soql() {
  local label="$1" query="$2" key="$3"
  local out="$REPORT_DIR/${key}.json"
  sf data query --query "$query" --target-org "$TARGET_ORG" --json 2>/dev/null > "$out" \
    || echo '{"result":{"records":[],"totalSize":0}}' > "$out"
  local count
  count=$(python3 -c "import json; d=json.load(open('$out')); print(d.get('result',{}).get('totalSize', len(d.get('result',{}).get('records',[]))))" 2>/dev/null || echo 0)
  echo "  + $label: $count records" >&2
  printf '%s' "$count"
}

section() { echo ""; echo "════════════════════════════════════════════════════════════════"; echo "  $1"; echo "════════════════════════════════════════════════════════════════"; }

# ── start ─────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SALESFORCE ORG SCAN                               ║"
printf "║  Org: %-54s║\n" "$TARGET_ORG"
printf "║  Date: %-53s║\n" "$(date -u '+%Y-%m-%d %H:%M UTC')"
printf "║  Lookback: %-48s║\n" "$DAYS days"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Governor Limits ────────────────────────────────────────────────────────

section "1 / 9  GOVERNOR LIMITS"
sf api request rest "/services/data/v66.0/limits" --target-org "$TARGET_ORG" 2>/dev/null \
  > "$REPORT_DIR/limits.json" || echo '{}' > "$REPORT_DIR/limits.json"

python3 - <<PYEOF
import json
from datetime import datetime

with open("$REPORT_DIR/limits.json") as f:
    d = json.load(f)

critical_lim, warning_lim, healthy_lim = [], [], []

for k, v in sorted(d.items()):
    if not isinstance(v, dict) or 'Remaining' not in v:
        continue
    mx   = v.get('Max', 0)
    rm   = v.get('Remaining', mx)
    used = mx - rm
    pct  = (used / mx * 100) if mx else 0
    if pct >= 80:
        critical_lim.append((k, used, mx, pct))
    elif pct >= 40:
        warning_lim.append((k, used, mx, pct))
    elif used > 0:
        healthy_lim.append((k, used, mx, pct))

def show(entries, icon):
    for k, used, mx, pct in entries:
        bar = '█' * int(pct/5) + '░' * (20 - int(pct/5))
        print(f"  {icon} [{bar}] {pct:5.1f}%  {k:<45}  {used:>10,} / {mx:>10,}")

if critical_lim:
    print("  🔴 CRITICAL (≥ 80%)")
    show(critical_lim, "🔴")
if warning_lim:
    print("  🟡 WARNING (40–79%)")
    show(warning_lim, "🟡")
if healthy_lim:
    print("  🟢 ACTIVE (< 40%)")
    show(healthy_lim, "🟢")

zero = sum(1 for k,v in d.items() if isinstance(v,dict) and v.get('Max',0)-v.get('Remaining',v.get('Max',0))==0)
print(f"\n  ⬜ {zero} limits at zero usage (idle)")
print(f"\n  LIMITS SUMMARY: 🔴 {len(critical_lim)}  🟡 {len(warning_lim)}  🟢 {len(healthy_lim)}  ⬜ {zero}")

# write counts for bash to pick up
with open("$REPORT_DIR/limits_counts.txt","w") as f:
    f.write(f"{len(critical_lim)} {len(warning_lim)}")
PYEOF

read -r lim_crit lim_warn < "$REPORT_DIR/limits_counts.txt" || lim_crit=0 lim_warn=0
[[ "$lim_crit" -gt 0 ]] && CRITICAL=$((CRITICAL + lim_crit))
[[ "$lim_warn" -gt 0 ]] && WARNING=$((WARNING + lim_warn))

# ── 2. Apex Exceptions ────────────────────────────────────────────────────────

section "2 / 9  APEX EXCEPTIONS"

# 2a. EventLogFile
ef_count=$(run_soql "EventLogFile (ApexUnexpectedException)" \
  "SELECT Id, EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType IN ('ApexUnexpectedException','ApexExecution') AND CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY LogDate DESC" \
  "apex_eventlog")

# 2b. Async job failures
async_count=$(run_soql "AsyncApexJob failures" \
  "SELECT Id, ApexClass.Name, Status, NumberOfErrors, ExtendedStatus, CreatedDate FROM AsyncApexJob WHERE Status IN ('Failed','Aborted') AND CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY CreatedDate DESC LIMIT 20" \
  "apex_async_fail")

# 2c. ApexLog errors
log_count=$(run_soql "ApexLog (non-Success)" \
  "SELECT Id, StartTime, Status, LogLength, Operation, Application FROM ApexLog WHERE Status != 'Success' ORDER BY StartTime DESC LIMIT 20" \
  "apex_log_errors")

# 2d. Failed tests
test_count=$(run_soql "ApexTestResult failures" \
  "SELECT ApexClass.Name, MethodName, Outcome, Message, StackTrace, CreatedDate FROM ApexTestResult WHERE Outcome = 'Fail' ORDER BY CreatedDate DESC LIMIT 20" \
  "apex_test_fail")

total_apex=$((async_count + log_count + test_count))
if [[ "$total_apex" -gt 0 ]]; then
  echo "  🔴 $total_apex Apex exception(s) found"
  CRITICAL=$((CRITICAL + 1))
else
  echo "  ✅ No Apex exceptions found"
fi

# ── 3. Flow Errors ────────────────────────────────────────────────────────────

section "3 / 9  FLOW ERRORS"
flow_count=$(run_soql "FlowInterviewLog errors" \
  "SELECT InterviewLabel, CurrentElement, ErrorMessage, CreatedDate FROM FlowInterviewLog WHERE CreatedDate = LAST_N_DAYS:${DAYS} AND InterviewStatus = 'Error' ORDER BY CreatedDate DESC LIMIT 20" \
  "flow_errors")

if [[ "$flow_count" -gt 0 ]]; then
  echo "  🟡 $flow_count Flow error(s) in last ${DAYS} days"
  WARNING=$((WARNING + 1))
  python3 -c "
import json
with open('$REPORT_DIR/flow_errors.json') as f: d=json.load(f)
for r in d.get('result',{}).get('records',[]):
    print(f'     {r[\"CreatedDate\"][:19]}  {r[\"InterviewLabel\"]}')
    print(f'       at: {r[\"CurrentElement\"]}')
    print(f'       ⚠️  {r[\"ErrorMessage\"][:100]}')
"
else
  echo "  ✅ No Flow errors"
fi

# ── 4. Storage ────────────────────────────────────────────────────────────────

section "4 / 9  STORAGE"
python3 -c "
import json
with open('$REPORT_DIR/limits.json') as f: d=json.load(f)

for key in ['DataStorageMB','FileStorageMB']:
    v = d.get(key, {})
    mx = v.get('Max', 0)
    rm = v.get('Remaining', mx)
    used = mx - rm
    pct  = (used/mx*100) if mx else 0
    bar  = '█' * int(pct/5) + '░' * (20-int(pct/5))
    icon = '🔴' if pct>=80 else ('🟡' if pct>=40 else '🟢')
    print(f'  {icon} [{bar}] {pct:5.1f}%  {key:<20}  {used} MB / {mx} MB')
"

run_soql "Large ContentVersion files" \
  "SELECT Title, ContentSize, FileType, Owner.Name, CreatedDate FROM ContentVersion WHERE IsLatest = TRUE ORDER BY ContentSize DESC LIMIT 10" \
  "storage_files" >/dev/null 2>&1 || true

python3 -c "
import json
with open('$REPORT_DIR/storage_files.json') as f: d=json.load(f)
records = d.get('result',{}).get('records',[])
if records:
    print('  Top files by size:')
    for r in records[:5]:
        sz = r.get('ContentSize',0)
        sz_kb = sz/1024
        print(f'    {sz_kb:>8.1f} KB  {r.get(\"FileType\",\"\"):8}  {r.get(\"Title\",\"\")[:50]}')
"

# ── 5. Login Anomalies ────────────────────────────────────────────────────────

section "5 / 9  LOGIN ANOMALIES"
run_soql "LoginHistory" \
  "SELECT UserId, LoginTime, LoginType, Status, SourceIp, Browser, Platform, Application, CountryIso FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:${DAYS} ORDER BY LoginTime DESC LIMIT 200" \
  "login_history" >/dev/null 2>&1 || true

python3 - <<PYEOF
import json
from collections import Counter

with open("$REPORT_DIR/login_history.json") as f:
    d = json.load(f)
records = d.get('result', {}).get('records', [])

total   = len(records)
success = sum(1 for r in records if r['Status'] == 'Success')
fails   = [r for r in records if r['Status'] != 'Success']
countries = Counter(r.get('CountryIso','?') for r in records)
types     = Counter(r.get('LoginType','?') for r in records)

print(f"  Total logins ({$DAYS}d): {total}  ✅ {success} success  {'🚨' if fails else '✅'} {len(fails)} failures")
print(f"  Countries: {dict(countries)}")
print(f"  Login types: {dict(types.most_common(4))}")

if fails:
    print(f"\n  🚨 FAILED LOGINS ({len(fails)}):")
    for r in fails[:10]:
        print(f"    {r['LoginTime'][:19]}  {r['UserId']}  {r['Status']}  IP:{r.get('SourceIp','?')}")
    with open("$REPORT_DIR/login_anomaly_count.txt","w") as f:
        f.write(str(len(fails)))
else:
    print("  ✅ No login failures")
    with open("$REPORT_DIR/login_anomaly_count.txt","w") as f:
        f.write("0")
PYEOF

login_fails=$(cat "$REPORT_DIR/login_anomaly_count.txt" 2>/dev/null || echo 0)
[[ "$login_fails" -gt 5 ]] && WARNING=$((WARNING + 1))

# ── 6. Event Logs ─────────────────────────────────────────────────────────────

section "6 / 9  EVENT LOG FILES"
ef_available=$(run_soql "EventLogFile availability check" \
  "SELECT EventType, COUNT(Id) Count FROM EventLogFile WHERE CreatedDate = LAST_N_DAYS:${DAYS} GROUP BY EventType ORDER BY COUNT(Id) DESC" \
  "event_log_types")

if [[ "$ef_available" -eq 0 ]]; then
  echo "  ℹ️  Event Monitoring not enabled on this org (requires Performance/Unlimited edition)"
  echo "     To enable: Setup → Event Monitoring, or contact Salesforce support"
else
  echo "  ✅ Event Monitoring available — $ef_available event type(s) found"
  python3 -c "
import json
with open('$REPORT_DIR/event_log_types.json') as f: d=json.load(f)
for r in d.get('result',{}).get('records',[]):
    print(f'    {r[\"EventType\"]:<40} {r[\"expr0\"]} file(s)')
"
fi

# ── 7. Setup Audit Trail ──────────────────────────────────────────────────────

section "7 / 9  SETUP AUDIT TRAIL"
audit_count=$(run_soql "SetupAuditTrail changes" \
  "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY CreatedDate DESC LIMIT 50" \
  "setup_audit")

python3 - <<PYEOF
import json

with open("$REPORT_DIR/setup_audit.json") as f:
    d = json.load(f)
records = d.get('result', {}).get('records', [])

HIGH_RISK = ['Apex Class','Apex Trigger','Lightning Component','Manage Users',
             'Permission Set','Password Policies','Session Settings','Named Credentials']

risky = [r for r in records if any(s in (r.get('Section') or '') for s in HIGH_RISK)]
normal = [r for r in records if r not in risky]

print(f"  Total setup changes ({$DAYS}d): {len(records)}  🚨 High-risk: {len(risky)}  ℹ️  Routine: {len(normal)}")

if risky:
    print(f"\n  🚨 HIGH-RISK CHANGES:")
    for r in risky[:10]:
        user = (r.get('CreatedBy') or {}).get('Username', 'Unknown')
        print(f"    {r['CreatedDate'][:19]}  {user:<35}  [{r.get('Section','')}]  {r.get('Display','')[:60]}")
    with open("$REPORT_DIR/audit_risk_count.txt","w") as f:
        f.write(str(len(risky)))
elif records:
    print("  Recent routine changes:")
    for r in records[:5]:
        user = (r.get('CreatedBy') or {}).get('Username', 'Unknown')
        print(f"    {r['CreatedDate'][:19]}  {user:<35}  [{r.get('Section','')}]")
    with open("$REPORT_DIR/audit_risk_count.txt","w") as f:
        f.write("0")
else:
    print("  ✅ No setup changes in this period")
    with open("$REPORT_DIR/audit_risk_count.txt","w") as f:
        f.write("0")
PYEOF

audit_risk=$(cat "$REPORT_DIR/audit_risk_count.txt" 2>/dev/null || echo 0)
[[ "$audit_risk" -gt 0 ]] && CRITICAL=$((CRITICAL + 1))

# ── 8. Stale Users ────────────────────────────────────────────────────────────

section "8 / 9  STALE USERS"
stale_count=$(run_soql "Active users inactive 90+ days" \
  "SELECT Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = TRUE AND LastLoginDate < LAST_N_DAYS:90 AND UserType = 'Standard' ORDER BY LastLoginDate ASC NULLS FIRST LIMIT 20" \
  "stale_users")

if [[ "$stale_count" -gt 10 ]]; then
  echo "  🟡 $stale_count active users haven't logged in for 90+ days"
  WARNING=$((WARNING + 1))
  python3 -c "
import json
with open('$REPORT_DIR/stale_users.json') as f: d=json.load(f)
for r in d.get('result',{}).get('records',[])[:5]:
    profile = (r.get('Profile') or {}).get('Name','Unknown')
    last = r.get('LastLoginDate','Never')[:10] if r.get('LastLoginDate') else 'Never'
    print(f'    {last}  {r[\"Username\"]:<40}  {profile}')
print(f'    ... and {int(\"$stale_count\")-5} more' if int('$stale_count')>5 else '')
"
elif [[ "$stale_count" -gt 0 ]]; then
  echo "  ℹ️  $stale_count stale user(s) — review recommended"
else
  echo "  ✅ All active users have logged in within 90 days"
fi

# ── 9. Scheduled Jobs ─────────────────────────────────────────────────────────

section "9 / 9  SCHEDULED JOBS"
run_soql "CronTrigger jobs" \
  "SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered FROM CronTrigger ORDER BY NextFireTime ASC" \
  "scheduled_jobs" >/dev/null 2>&1 || true

python3 - <<PYEOF
import json

with open("$REPORT_DIR/scheduled_jobs.json") as f:
    d = json.load(f)
records = d.get('result', {}).get('records', [])

error_jobs = [r for r in records if r.get('State') in ('ERROR','DELETED')]
active_jobs = [r for r in records if r.get('State') not in ('ERROR','DELETED')]

print(f"  Scheduled jobs: {len(records)} total  ✅ {len(active_jobs)} active  {'🟡' if error_jobs else '✅'} {len(error_jobs)} errors")

if error_jobs:
    print("  🟡 Jobs in error state:")
    for r in error_jobs:
        name = (r.get('CronJobDetail') or {}).get('Name','Unknown')
        print(f"    {name:<50}  State:{r['State']}")

if active_jobs:
    print("  Upcoming jobs:")
    for r in active_jobs[:5]:
        name = (r.get('CronJobDetail') or {}).get('Name','Unknown')
        nxt  = (r.get('NextFireTime') or 'N/A')[:19]
        print(f"    {nxt}  {name}")

with open("$REPORT_DIR/job_error_count.txt","w") as f:
    f.write(str(len(error_jobs)))
PYEOF

job_errors=$(cat "$REPORT_DIR/job_error_count.txt" 2>/dev/null || echo 0)
[[ "$job_errors" -gt 0 ]] && WARNING=$((WARNING + 1))

# ── Final Report ──────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
if [[ "$CRITICAL" -gt 0 ]]; then
  printf "║  OVERALL: 🔴 CRITICAL %-38s║\n" ""
elif [[ "$WARNING" -gt 0 ]]; then
  printf "║  OVERALL: 🟡 WARNING  %-38s║\n" ""
else
  printf "║  OVERALL: 🟢 HEALTHY  %-38s║\n" ""
fi
printf "║  🔴 Critical findings: %-36s║\n" "$CRITICAL"
printf "║  🟡 Warnings:          %-36s║\n" "$WARNING"
printf "║  Report saved to: %-40s║\n" "$OUTPUT"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Write markdown summary
cat > "$OUTPUT" <<MDEOF
# Org Scan Report
**Org:** \`$TARGET_ORG\`
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Lookback:** $DAYS days
**Overall:** $([ "$CRITICAL" -gt 0 ] && echo "🔴 CRITICAL" || ([ "$WARNING" -gt 0 ] && echo "🟡 WARNING" || echo "🟢 HEALTHY"))

| Domain | Status |
|--------|--------|
| Governor Limits | $([ "$lim_crit" -gt 0 ] && echo "🔴 $lim_crit critical" || ([ "$lim_warn" -gt 0 ] && echo "🟡 $lim_warn warning" || echo "🟢 Healthy")) |
| Apex Exceptions | $([ "$total_apex" -gt 0 ] && echo "🔴 $total_apex found" || echo "🟢 None") |
| Flow Errors | $([ "$flow_count" -gt 0 ] && echo "🟡 $flow_count found" || echo "🟢 None") |
| Storage | See details |
| Login Anomalies | $([ "$login_fails" -gt 0 ] && echo "🟡 $login_fails failures" || echo "🟢 Clean") |
| Event Logs | $([ "$ef_available" -gt 0 ] && echo "✅ Available" || echo "ℹ️ Not enabled") |
| Setup Audit Trail | $([ "$audit_risk" -gt 0 ] && echo "🔴 $audit_risk high-risk change(s)" || echo "🟢 No risky changes") |
| Stale Users | $([ "$stale_count" -gt 10 ] && echo "🟡 $stale_count inactive" || echo "🟢 OK") |
| Scheduled Jobs | $([ "$job_errors" -gt 0 ] && echo "🟡 $job_errors in error" || echo "🟢 All running") |

*Full data in: $REPORT_DIR/*
MDEOF

echo "Data files: $REPORT_DIR/"
echo "Report:     $OUTPUT"
echo ""

# Exit non-zero on critical for CI integration
[[ "$CRITICAL" -gt 0 ]] && exit 1 || exit 0
