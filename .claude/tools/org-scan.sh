#!/usr/bin/env bash
# Salesforce org-scan.sh — 14-domain health, security, and compliance scan.
#
# Usage: org-scan.sh [--target-org <alias>] [--days <n>] [--run-tests]
#                    [--threshold <pct>] [--output <file>]
#
# Exit codes: 0 = healthy/warning  |  1 = critical finding

set -euo pipefail

TARGET_ORG="dev"
DAYS=7
RUN_TESTS=false
THRESHOLD=75
OUTPUT=""
REPORT_DIR="reports/org-scan-$(date +%Y%m%d-%H%M)"
START_TS=$(date +%s)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org)  TARGET_ORG="$2";  shift 2 ;;
    --days)        DAYS="$2";        shift 2 ;;
    --threshold)   THRESHOLD="$2";   shift 2 ;;
    --output)      OUTPUT="$2";      shift 2 ;;
    --run-tests)   RUN_TESTS=true;   shift   ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$REPORT_DIR"
[[ -z "$OUTPUT" ]] && OUTPUT="$REPORT_DIR/org-scan-report.md"
CRITICAL=0; WARNING=0; CLEAN=0

# ── helpers ──────────────────────────────────────────────────────────────────

q() {   # q <key> <soql>  — run SOQL, save to $REPORT_DIR/<key>.json, echo record count
  local key="$1" query="$2"
  local out="$REPORT_DIR/${key}.json"
  sf data query --query "$query" --target-org "$TARGET_ORG" --json 2>/dev/null > "$out" \
    || printf '{"result":{"records":[],"totalSize":0}}' > "$out"
  python3 -c "import json; d=json.load(open('$out')); print(d.get('result',{}).get('totalSize', len(d.get('result',{}).get('records',[]))))" 2>/dev/null || echo 0
}

qt() {  # qt <key> <soql>  — same but uses Tooling API
  local key="$1" query="$2"
  local out="$REPORT_DIR/${key}.json"
  sf data query --query "$query" --target-org "$TARGET_ORG" --use-tooling-api --json 2>/dev/null > "$out" \
    || printf '{"result":{"records":[],"totalSize":0}}' > "$out"
  python3 -c "import json; d=json.load(open('$out')); print(d.get('result',{}).get('totalSize', len(d.get('result',{}).get('records',[]))))" 2>/dev/null || echo 0
}

rest() { # rest <key> <path>  — REST API call, save JSON
  sf api request rest "$2" --target-org "$TARGET_ORG" 2>/dev/null \
    > "$REPORT_DIR/${1}.json" || echo '{}' > "$REPORT_DIR/${1}.json"
}

hdr() { printf '\n\e[1;36m════════════════════════════════════════════════════════════════\e[0m\n'; printf '\e[1;36m  %s\e[0m\n' "$1"; printf '\e[1;36m════════════════════════════════════════════════════════════════\e[0m\n'; }
ok()   { printf '  \e[32m✅ %s\e[0m\n' "$*";  CLEAN=$((CLEAN+1)); }
warn() { printf '  \e[33m🟡 %s\e[0m\n' "$*";  WARNING=$((WARNING+1)); }
crit() { printf '  \e[31m🔴 %s\e[0m\n' "$*";  CRITICAL=$((CRITICAL+1)); }
info() { printf '  \e[34mℹ️  %s\e[0m\n' "$*"; }
row()  { printf '     \e[90m%-22s\e[0m %s\n' "$1" "$2"; }

records() { python3 -c "import json; d=json.load(open('$REPORT_DIR/$1.json')); print(d.get('result',{}).get('records',[]))" 2>/dev/null; }

# ── banner ────────────────────────────────────────────────────────────────────

printf '\n\e[1;35m╔══════════════════════════════════════════════════════════════╗\e[0m\n'
printf '\e[1;35m║           SALESFORCE ORG SCAN  —  14 DOMAINS                ║\e[0m\n'
printf '\e[1;35m║  Org: %-54s║\e[0m\n' "$TARGET_ORG"
printf '\e[1;35m║  Date: %-53s║\e[0m\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
printf '\e[1;35m║  Lookback: %-48s║\e[0m\n' "$DAYS days"
printf '\e[1;35m╚══════════════════════════════════════════════════════════════╝\e[0m\n'

# ── 1. GOVERNOR LIMITS ────────────────────────────────────────────────────────

hdr "1 / 14  GOVERNOR LIMITS"
rest limits "/services/data/v66.0/limits"

python3 - <<PYEOF
import json
with open("$REPORT_DIR/limits.json") as f: d = json.load(f)

crit_n, warn_n = 0, 0
rows = []
for k, v in sorted(d.items()):
    if not isinstance(v, dict) or 'Remaining' not in v: continue
    mx = v.get('Max', 0); rm = v.get('Remaining', mx); used = mx - rm
    pct = (used/mx*100) if mx else 0
    if pct >= 80: crit_n += 1; icon = '🔴'
    elif pct >= 40: warn_n += 1; icon = '🟡'
    elif used > 0: icon = '🟢'
    else: continue
    bar = '█'*int(pct/5) + '░'*(20-int(pct/5))
    rows.append((icon, bar, pct, k, used, mx))

for icon, bar, pct, k, used, mx in rows:
    print(f"  {icon} [{bar}] {pct:5.1f}%  {k:<45}  {used:>10,} / {mx:>10,}")

zero = sum(1 for k,v in d.items() if isinstance(v,dict) and (v.get('Max',0)-v.get('Remaining',v.get('Max',0)))==0)
print(f"\n  ⬜ {zero} limits at zero  |  🔴 {crit_n}  🟡 {warn_n}  🟢 {len(rows)-crit_n-warn_n}")
with open("$REPORT_DIR/_lim.txt","w") as f: f.write(f"{crit_n} {warn_n}")
PYEOF

read -r _lc _lw < "$REPORT_DIR/_lim.txt" || _lc=0; _lw=0
[[ "$_lc" -gt 0 ]] && CRITICAL=$((CRITICAL+_lc)) || true
[[ "$_lw" -gt 0 ]] && WARNING=$((WARNING+_lw))   || true

# ── 2. APEX EXCEPTIONS ────────────────────────────────────────────────────────

hdr "2 / 14  APEX EXCEPTIONS"

ef=$(q apex_evlog "SELECT Id, EventType, LogDate FROM EventLogFile WHERE EventType IN ('ApexUnexpectedException') AND CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY LogDate DESC")
aj=$(q apex_async "SELECT ApexClass.Name, Status, NumberOfErrors, ExtendedStatus, CreatedDate FROM AsyncApexJob WHERE Status IN ('Failed','Aborted') AND CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY CreatedDate DESC LIMIT 20")
al=$(q apex_log   "SELECT StartTime, Status, LogLength, Operation FROM ApexLog WHERE Status != 'Success' ORDER BY StartTime DESC LIMIT 20")
at=$(q apex_test  "SELECT ApexClass.Name, MethodName, Outcome, Message, StackTrace, CreatedDate FROM ApexTestResult WHERE Outcome = 'Fail' ORDER BY CreatedDate DESC LIMIT 20")

total_ex=$((aj + al + at))
if [[ "$total_ex" -gt 0 ]]; then
  crit "$total_ex Apex exception source(s) found"
  [[ "$aj" -gt 0 ]] && row "Async job failures:" "$aj"
  [[ "$al" -gt 0 ]] && row "ApexLog errors:" "$al"
  [[ "$at" -gt 0 ]] && row "Test failures:" "$at"
  python3 -c "
import json
for key in ['apex_async','apex_test']:
    try:
        recs = json.load(open('$REPORT_DIR/'+key+'.json')).get('result',{}).get('records',[])
        for r in recs[:3]:
            cls = (r.get('ApexClass') or {}).get('Name','?')
            msg = r.get('ExtendedStatus') or r.get('Message') or r.get('Status','')
            print(f'     [{cls}] {str(msg)[:80]}')
    except: pass
"
else
  ok "No Apex exceptions (last ${DAYS}d)"
fi
[[ "$ef" -eq 0 ]] && info "Event Monitoring not available — EventLogFile empty"

# ── 3. APEX TEST COVERAGE ─────────────────────────────────────────────────────

hdr "3 / 14  APEX TEST COVERAGE"

if [[ "$RUN_TESTS" == "true" ]]; then
  info "Running local tests (this may take a few minutes)..."
  sf apex run test --target-org "$TARGET_ORG" --test-level RunLocalTests \
    --code-coverage --result-format human --wait 20 2>&1 | tail -20
fi

cov_pct=$(qt apex_cov "SELECT PercentCovered FROM ApexOrgWideCoverage" \
  && python3 -c "import json; r=json.load(open('$REPORT_DIR/apex_cov.json')).get('result',{}).get('records',[]); print(r[0]['PercentCovered'] if r else 0)" 2>/dev/null || echo 0)

qt apex_low "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate WHERE NumLinesCovered + NumLinesUncovered > 0 ORDER BY NumLinesCovered ASC LIMIT 20" >/dev/null

if python3 -c "import sys; sys.exit(0 if float('${cov_pct:-0}') >= $THRESHOLD else 1)" 2>/dev/null; then
  ok "Org-wide coverage: ${cov_pct}% (threshold: ${THRESHOLD}%)"
else
  crit "Org-wide coverage: ${cov_pct}% — below ${THRESHOLD}% threshold"
fi

# Static quality checks
no_assert=$(grep -rl "@isTest\|testMethod" force-app --include="*.cls" 2>/dev/null | \
  xargs grep -L "System\.assert\|Assert\." 2>/dev/null | wc -l | tr -d ' ')
see_all=$(grep -rl "SeeAllData\s*=\s*true" force-app --include="*.cls" 2>/dev/null | wc -l | tr -d ' ')
hardcoded=$(grep -rn "'001\|'003\|'005" force-app --include="*.cls" 2>/dev/null | grep -i "test" | wc -l | tr -d ' ')

[[ "$no_assert" -gt 0 ]] && warn "$no_assert test class(es) with no assertions (empty coverage)" || true
[[ "$see_all"   -gt 0 ]] && warn "$see_all test class(es) using SeeAllData=true (anti-pattern)" || true
[[ "$hardcoded" -gt 0 ]] && warn "$hardcoded hard-coded ID(s) in test classes" || true
[[ "$no_assert" -eq 0 && "$see_all" -eq 0 && "$hardcoded" -eq 0 ]] && ok "Test quality checks: no anti-patterns found"

# ── 4. CONNECTED APPS ─────────────────────────────────────────────────────────

hdr "4 / 14  CONNECTED APPS"

total_apps=$(q conn_apps "SELECT Id, Name, ContactEmail, OptionsIsConsumerSecretOptional, OptionsAllowAdminApprovedUsersOnly FROM ConnectedApplication ORDER BY Name")
total_grants=$(q conn_grants "SELECT ConnectedApplication.Name, UserId, User.Username, User.IsActive, Scopes, UseCount, LastUsedDate FROM OAuth2 ORDER BY LastUsedDate DESC NULLS LAST LIMIT 100")

# Grants to inactive users — Critical
inactive_grants=$(python3 - <<PYEOF
import json
try:
    recs = json.load(open("$REPORT_DIR/conn_grants.json")).get("result",{}).get("records",[])
    bad = [r for r in recs if not (r.get("User") or {}).get("IsActive", True)]
    for r in bad:
        u = (r.get("User") or {}).get("Username","?")
        a = (r.get("ConnectedApplication") or {}).get("Name","?")
        print(f"     {u}  →  {a}  scopes:{r.get('Scopes','?')}")
    print(len(bad))
except: print(0)
PYEOF
)
ig_count=$(echo "$inactive_grants" | tail -1)
[[ "$ig_count" -gt 0 ]] && crit "$ig_count OAuth grant(s) to DEACTIVATED users — revoke immediately" \
                         && echo "$inactive_grants" | head -$((ig_count)) || true

# Stale grants (90+ days)
stale_grants=$(q conn_stale "SELECT ConnectedApplication.Name, User.Username, Scopes, LastUsedDate FROM OAuth2 WHERE LastUsedDate < LAST_N_DAYS:90 ORDER BY LastUsedDate ASC NULLS FIRST LIMIT 20")
[[ "$stale_grants" -gt 0 ]] && warn "$stale_grants OAuth grant(s) unused for 90+ days" || true

# Full/api scope
broad_grants=$(q conn_broad "SELECT ConnectedApplication.Name, User.Username, Scopes FROM OAuth2 WHERE Scopes LIKE '%full%' ORDER BY ConnectedApplication.Name")
[[ "$broad_grants" -gt 0 ]] && warn "$broad_grants 'full' scope OAuth grant(s) — least-privilege violation" || true

info "Total Connected Apps: $total_apps  |  Total OAuth grants: $total_grants"
[[ "$ig_count" -eq 0 && "$stale_grants" -eq 0 && "$broad_grants" -eq 0 ]] && ok "Connected Apps: no critical findings"

# ── 5. USER SECURITY ──────────────────────────────────────────────────────────

hdr "5 / 14  USER SECURITY"

# Frozen users
frozen=$(q user_frozen "SELECT UserId, User.Username, User.Name, User.Profile.Name, IsFrozen, IsPasswordLocked FROM UserLogin WHERE IsFrozen = TRUE ORDER BY UserId")
[[ "$frozen" -gt 0 ]] && crit "$frozen frozen user(s) — still accessible via active API sessions!" \
  && python3 -c "
import json
recs = json.load(open('$REPORT_DIR/user_frozen.json')).get('result',{}).get('records',[])
for r in recs[:5]:
    u = (r.get('User') or {})
    print(f'     {u.get(\"Username\",\"?\")}  profile:{(u.get(\"Profile\") or {}).get(\"Name\",\"?\")}')
" || ok "No frozen users"

# Password-locked accounts
locked=$(q user_locked "SELECT UserId, User.Username, User.Name, IsPasswordLocked FROM UserLogin WHERE IsPasswordLocked = TRUE")
[[ "$locked" -gt 0 ]] && warn "$locked password-locked account(s) — possible brute-force attempt" || true

# ModifyAllData via profile
mad_profiles=$(q user_mad_profile "SELECT Name FROM Profile WHERE PermissionsModifyAllData = TRUE ORDER BY Name")
[[ "$mad_profiles" -gt 1 ]] && crit "$mad_profiles profile(s) with ModifyAllData (expected: System Admin only)" || true

# ModifyAllData via permset
mad_ps=$(q user_mad_ps "SELECT Assignee.Username, Assignee.IsActive, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.PermissionsModifyAllData = TRUE AND Assignee.IsActive = TRUE ORDER BY Assignee.Username")
[[ "$mad_ps" -gt 0 ]] && warn "$mad_ps active user(s) granted ModifyAllData via permission set" || true

# API-enabled non-integration users
api_users=$(q user_api "SELECT Name, Username, Profile.Name FROM User WHERE IsActive = TRUE AND Profile.PermissionsApiEnabled = TRUE AND Profile.Name NOT LIKE '%Admin%' AND Profile.Name NOT LIKE '%Integration%' AND Profile.Name NOT LIKE '%API%' AND UserType = 'Standard' ORDER BY Profile.Name LIMIT 20")
[[ "$api_users" -gt 0 ]] && warn "$api_users non-integration user(s) with API access enabled" || true

# New users in window
new_users=$(q user_new "SELECT Name, Username, Profile.Name, CreatedBy.Username, CreatedDate FROM User WHERE CreatedDate = LAST_N_DAYS:${DAYS} AND IsActive = TRUE ORDER BY CreatedDate DESC")
[[ "$new_users" -gt 0 ]] && info "$new_users new active user(s) created in last ${DAYS} days" \
  && python3 -c "
import json
recs = json.load(open('$REPORT_DIR/user_new.json')).get('result',{}).get('records',[])
for r in recs[:5]:
    by = (r.get('CreatedBy') or {}).get('Username','?')
    p  = (r.get('Profile') or {}).get('Name','?')
    print(f'     {r[\"CreatedDate\"][:10]}  {r[\"Username\"]}  [{p}]  created-by:{by}')
" || true

[[ "$frozen" -eq 0 && "$locked" -eq 0 && "$mad_ps" -eq 0 ]] && ok "User security: no critical findings"

# ── 6. DEACTIVATED USERS + ORPHANED ACCESS ────────────────────────────────────

hdr "6 / 14  DEACTIVATED USERS + ORPHANED ACCESS"

deact=$(q user_deact "SELECT Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = FALSE AND LastModifiedDate = LAST_N_DAYS:${DAYS} ORDER BY LastModifiedDate DESC LIMIT 20")
[[ "$deact" -gt 0 ]] && info "$deact user(s) deactivated in last ${DAYS} days" \
  && python3 -c "
import json
recs = json.load(open('$REPORT_DIR/user_deact.json')).get('result',{}).get('records',[])
for r in recs[:5]:
    last = (r.get('LastLoginDate') or 'never')[:10]
    p    = (r.get('Profile') or {}).get('Name','?')
    print(f'     {r[\"Username\"]}  last-login:{last}  [{p}]')
" || ok "No recently deactivated users"

# Orphaned OAuth grants (deactivated user still has token)
orphan=$(q user_orphan_oauth "SELECT ConnectedApplication.Name, User.Username, Scopes, LastUsedDate FROM OAuth2 WHERE User.IsActive = FALSE ORDER BY LastUsedDate DESC NULLS LAST LIMIT 20")
[[ "$orphan" -gt 0 ]] && crit "$orphan orphaned OAuth grant(s) — deactivated users with live tokens" \
  && python3 -c "
import json
recs = json.load(open('$REPORT_DIR/user_orphan_oauth.json')).get('result',{}).get('records',[])
for r in recs[:5]:
    u = (r.get('User') or {}).get('Username','?')
    a = (r.get('ConnectedApplication') or {}).get('Name','?')
    last = (r.get('LastUsedDate') or 'never')[:10]
    print(f'     {u}  →  {a}  last-used:{last}')
" || ok "No orphaned OAuth grants from deactivated users"

# Stale permset assignments for inactive users
stale_ps=$(q user_stale_ps "SELECT Assignee.Username, PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.IsActive = FALSE AND PermissionSet.IsOwnedByProfile = FALSE ORDER BY Assignee.Username LIMIT 20")
[[ "$stale_ps" -gt 0 ]] && warn "$stale_ps permission set assignment(s) on inactive users — cleanup needed" || true

# ── 7. FLOW ERRORS + LEGACY AUTOMATION ───────────────────────────────────────

hdr "7 / 14  FLOW ERRORS + LEGACY AUTOMATION"

flow_err=$(q flow_errors "SELECT InterviewLabel, CurrentElement, ErrorMessage, CreatedDate FROM FlowInterviewLog WHERE CreatedDate = LAST_N_DAYS:${DAYS} AND InterviewStatus = 'Error' ORDER BY CreatedDate DESC LIMIT 20")
if [[ "$flow_err" -gt 0 ]]; then
  warn "$flow_err Flow interview error(s) in last ${DAYS} days"
  python3 -c "
import json
recs = json.load(open('$REPORT_DIR/flow_errors.json')).get('result',{}).get('records',[])
for r in recs[:5]:
    print(f'     {r[\"CreatedDate\"][:19]}  [{r[\"InterviewLabel\"]}]  at:{r[\"CurrentElement\"]}')
    print(f'       {str(r[\"ErrorMessage\"])[:90]}')
"
else
  ok "No Flow interview errors (last ${DAYS}d)"
fi

# Legacy Process Builder
pb=$(q flow_pb "SELECT DeveloperName, ProcessType FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','InvocableProcess','CustomEvent') ORDER BY DeveloperName")
[[ "$pb" -gt 0 ]] && warn "$pb active Process Builder flow(s) — migrate to record-triggered Flow" || ok "No active Process Builder flows"

# Active Workflow Rules (legacy)
wfr=$(q flow_wfr "SELECT TableEnumOrId, COUNT(Id) Count FROM WorkflowRule WHERE IsActive = TRUE GROUP BY TableEnumOrId ORDER BY COUNT(Id) DESC")
[[ "$wfr" -gt 0 ]] && info "$wfr object(s) with active Workflow Rules (legacy — consider Flow migration)" || true

# Automation stacking: objects with >3 active flows
stacked=$(q flow_stack "SELECT TriggerObjectOrEvent.QualifiedApiName, COUNT(Id) FlowCount FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType = 'AutoLaunchedFlow' GROUP BY TriggerObjectOrEvent.QualifiedApiName HAVING COUNT(Id) > 3 ORDER BY FlowCount DESC")
[[ "$stacked" -gt 0 ]] && warn "$stacked object(s) with >3 active record-triggered flows (execution order unpredictable)" || true

# ── 8. STORAGE ────────────────────────────────────────────────────────────────

hdr "8 / 14  STORAGE"

python3 -c "
import json
with open('$REPORT_DIR/limits.json') as f: d = json.load(f)
for key in ['DataStorageMB','FileStorageMB']:
    v = d.get(key, {})
    mx = v.get('Max', 0); rm = v.get('Remaining', mx); used = mx - rm
    pct = (used/mx*100) if mx else 0
    bar = '█'*int(pct/5) + '░'*(20-int(pct/5))
    icon = '🔴' if pct>=80 else ('🟡' if pct>=40 else '🟢')
    print(f'  {icon} [{bar}] {pct:5.1f}%  {key:<20}  {used} MB / {mx} MB')
"

q stor_files "SELECT Title, ContentSize, FileType, Owner.Name, CreatedDate FROM ContentVersion WHERE IsLatest = TRUE ORDER BY ContentSize DESC LIMIT 10" >/dev/null
python3 -c "
import json
recs = json.load(open('$REPORT_DIR/stor_files.json')).get('result',{}).get('records',[])
if recs:
    print('  Top 5 files:')
    for r in recs[:5]:
        sz = r.get('ContentSize',0)/1024
        print(f'    {sz:>8.1f} KB  {r.get(\"FileType\",\"\"):8}  {r.get(\"Title\",\"\")[:55]}')
"

# ── 9. LOGIN ANOMALIES ────────────────────────────────────────────────────────

hdr "9 / 14  LOGIN ANOMALIES"

q login_hist "SELECT UserId, LoginTime, LoginType, Status, SourceIp, Browser, Application, CountryIso FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:${DAYS} ORDER BY LoginTime DESC LIMIT 200" >/dev/null

python3 - <<PYEOF
import json
from collections import Counter
recs = json.load(open("$REPORT_DIR/login_hist.json")).get("result",{}).get("records",[])
total = len(recs)
fails = [r for r in recs if r["Status"] != "Success"]
countries = Counter(r.get("CountryIso","?") for r in recs)
types = Counter(r.get("LoginType","?") for r in recs)
apps  = Counter(r.get("Application","?") for r in recs)

print(f"  Logins ({$DAYS}d): {total} total  ✅ {total-len(fails)} success  {'🚨' if fails else '✅'} {len(fails)} failures")
print(f"  Countries: {dict(countries.most_common(5))}")
print(f"  Types: {dict(types.most_common(4))}")

if fails:
    print(f"  🔴 Failed logins:")
    for r in fails[:5]:
        print(f"     {r['LoginTime'][:19]}  {r['UserId']}  {r['Status']}  IP:{r.get('SourceIp','?')}")

with open("$REPORT_DIR/_login.txt","w") as f: f.write(str(len(fails)))
PYEOF

_lf=$(cat "$REPORT_DIR/_login.txt" 2>/dev/null || echo 0)
[[ "$_lf" -gt 5 ]] && WARNING=$((WARNING+1)) || true
[[ "$_lf" -eq 0 ]] && ok "No login failures (last ${DAYS}d)"

# MFA failures
mfa=$(q login_mfa "SELECT Username, Activity, Status, SourceIp, Timestamp FROM VerificationHistory WHERE Timestamp = LAST_N_DAYS:${DAYS} AND Status != 'Success' ORDER BY Timestamp DESC LIMIT 20")
[[ "$mfa" -gt 0 ]] && warn "$mfa MFA verification failure(s)" || ok "No MFA failures"

# ── 10. EVENT LOG FILES ───────────────────────────────────────────────────────

hdr "10 / 14  EVENT LOG FILES"
elf_avail=$(q elf_types "SELECT EventType, COUNT(Id) Count FROM EventLogFile WHERE CreatedDate = LAST_N_DAYS:${DAYS} GROUP BY EventType ORDER BY COUNT(Id) DESC")
if [[ "$elf_avail" -gt 0 ]]; then
  ok "Event Monitoring available — $elf_avail event type(s)"
  python3 -c "
import json
recs = json.load(open('$REPORT_DIR/elf_types.json')).get('result',{}).get('records',[])
for r in recs: print(f'     {r[\"EventType\"]:<40} {r[\"expr0\"]} file(s)')
"
  # High-value event checks
  rpt_exp=$(q elf_rpt "SELECT EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType = 'ReportExport' AND CreatedDate = LAST_N_DAYS:${DAYS}")
  [[ "$rpt_exp" -gt 0 ]] && warn "$rpt_exp ReportExport log(s) — download and inspect row counts" || true
  data_exp=$(q elf_data "SELECT EventType, LogDate FROM EventLogFile WHERE EventType = 'DataExport' AND CreatedDate = LAST_N_DAYS:${DAYS}")
  [[ "$data_exp" -gt 0 ]] && crit "$data_exp DataExport event(s) — full org data export occurred" || true
else
  info "Event Monitoring not available (requires Performance/Unlimited)"
  info "Enable at: Setup → Event Manager → Enable log files"
fi

# ── 11. SETUP AUDIT TRAIL ─────────────────────────────────────────────────────

hdr "11 / 14  SETUP AUDIT TRAIL"
q setup_audit "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:${DAYS} ORDER BY CreatedDate DESC LIMIT 100" >/dev/null

python3 - <<PYEOF
import json
recs = json.load(open("$REPORT_DIR/setup_audit.json")).get("result",{}).get("records",[])

HIGH_RISK = {'Apex Class','Apex Trigger','Lightning Component','Visualforce Page',
             'Named Credentials','Password Policies','Session Settings',
             'Certificate and Key Management','Remote Access'}
MEDIUM_RISK = {'Manage Users','Permission Set','Permission Set Group','Profile',
               'Connected App','OAuth','Single Sign-On'}

risky = [r for r in recs if (r.get('Section') or '') in HIGH_RISK]
medium = [r for r in recs if (r.get('Section') or '') in MEDIUM_RISK]

print(f"  Total changes ({$DAYS}d): {len(recs)}  🔴 High-risk: {len(risky)}  🟡 Medium: {len(medium)}")

if risky:
    print(f"  🔴 High-risk changes:")
    for r in risky[:5]:
        u = (r.get('CreatedBy') or {}).get('Username','?')
        print(f"     {r['CreatedDate'][:19]}  {u:<35}  [{r.get('Section','')}]  {r.get('Display','')[:60]}")

if medium and not risky:
    print(f"  🟡 User/access changes:")
    for r in medium[:5]:
        u = (r.get('CreatedBy') or {}).get('Username','?')
        print(f"     {r['CreatedDate'][:19]}  {u:<35}  [{r.get('Section','')}]  {r.get('Display','')[:55]}")

with open("$REPORT_DIR/_audit.txt","w") as f: f.write(f"{len(risky)} {len(medium)}")
PYEOF

read -r _ar _am < "$REPORT_DIR/_audit.txt" || _ar=0; _am=0
[[ "$_ar" -gt 0 ]] && CRITICAL=$((CRITICAL+1)) || true
[[ "$_am" -gt 0 && "$_ar" -eq 0 ]] && WARNING=$((WARNING+1)) || true
[[ "$_ar" -eq 0 && "$_am" -eq 0 ]] && ok "No risky setup changes (last ${DAYS}d)"

# ── 12. SECURITY POSTURE ──────────────────────────────────────────────────────

hdr "12 / 14  SECURITY POSTURE"

# CORS whitelist
cors=$(q sec_cors "SELECT Id, UrlPattern FROM CorsWhitelistEntry ORDER BY UrlPattern")
python3 -c "
import json
recs = json.load(open('$REPORT_DIR/sec_cors.json')).get('result',{}).get('records',[])
wilds = [r for r in recs if '*' in r.get('UrlPattern','')]
http  = [r for r in recs if r.get('UrlPattern','').startswith('http://')]
if wilds: print(f'  🟡 CORS wildcard entries: {len(wilds)} — {[r[\"UrlPattern\"] for r in wilds]}')
if http:  print(f'  🟡 CORS http:// (non-HTTPS) entries: {len(http)}')
if not wilds and not http: print(f'  ✅ CORS: {len(recs)} entries, all clean')
"

# Certificates expiring soon
certs=$(q sec_certs "SELECT DeveloperName, ExpirationDate, KeySize FROM Certificate WHERE ExpirationDate < NEXT_N_DAYS:90 ORDER BY ExpirationDate ASC")
if [[ "$certs" -gt 0 ]]; then
  warn "$certs certificate(s) expiring within 90 days"
  python3 -c "
import json
from datetime import datetime, timezone
recs = json.load(open('$REPORT_DIR/sec_certs.json')).get('result',{}).get('records',[])
now = datetime.now(timezone.utc)
for r in recs:
    exp = r.get('ExpirationDate','?')
    name = r.get('DeveloperName','?')
    print(f'     {name:<40}  expires: {exp[:10]}')
"
else
  ok "Certificates: none expiring within 90 days"
fi

# Installed packages
pkgs=$(q sec_pkgs "SELECT SubscriberPackage.Name, SubscriberPackage.NamespacePrefix, SubscriberPackageVersion.Name, SubscriberPackageVersion.MajorVersion FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name")
info "Installed managed packages: $pkgs"
if [[ "$pkgs" -gt 0 ]]; then
  python3 -c "
import json
recs = json.load(open('$REPORT_DIR/sec_pkgs.json')).get('result',{}).get('records',[])
for r in recs:
    pkg  = (r.get('SubscriberPackage') or {}).get('Name','?')
    ns   = (r.get('SubscriberPackage') or {}).get('NamespacePrefix','')
    ver  = (r.get('SubscriberPackageVersion') or {}).get('Name','?')
    print(f'     {pkg:<45}  ns:{ns:<15}  v:{ver}')
"
fi

# Guest user access (Critical if Contact/Account/Case exposed)
guest=$(q sec_guest "SELECT SobjectType, PermissionsRead, PermissionsCreate FROM ObjectPermissions WHERE Parent.Profile.UserType = 'Guest' AND PermissionsRead = TRUE ORDER BY SobjectType")
if [[ "$guest" -gt 0 ]]; then
  python3 - <<PYEOF
import json
recs = json.load(open("$REPORT_DIR/sec_guest.json")).get("result",{}).get("records",[])
sensitive = {'Contact','Account','Case','Lead','User','Order','Contract'}
exposed = [r['SobjectType'] for r in recs if r['SobjectType'] in sensitive]
if exposed:
    print(f"  🔴 CRITICAL: Guest user can read sensitive objects: {exposed}")
else:
    print(f"  🟢 Guest user: {len(recs)} object(s) accessible, none sensitive")
with open("$REPORT_DIR/_guest.txt","w") as f: f.write(str(len(exposed)))
PYEOF
  _gg=$(cat "$REPORT_DIR/_guest.txt" 2>/dev/null || echo 0)
  [[ "$_gg" -gt 0 ]] && CRITICAL=$((CRITICAL+1)) || true
else
  ok "Guest user: no object access granted"
fi

# ── 13. SCHEDULED JOBS ────────────────────────────────────────────────────────

hdr "13 / 14  SCHEDULED JOBS"
q sched_jobs "SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered FROM CronTrigger ORDER BY State, NextFireTime ASC" >/dev/null

python3 - <<PYEOF
import json
recs = json.load(open("$REPORT_DIR/sched_jobs.json")).get("result",{}).get("records",[])
errors = [r for r in recs if r.get("State") in ("ERROR","DELETED")]
active = [r for r in recs if r.get("State") not in ("ERROR","DELETED")]
print(f"  Scheduled jobs: {len(recs)} total  ✅ {len(active)} running  {'🟡' if errors else '✅'} {len(errors)} errors")
if errors:
    for r in errors:
        name = (r.get("CronJobDetail") or {}).get("Name","?")
        print(f"     🟡 {name}  State:{r['State']}")
else:
    for r in active[:3]:
        name = (r.get("CronJobDetail") or {}).get("Name","?")
        nxt  = (r.get("NextFireTime") or "N/A")[:19]
        print(f"     ✅ {name:<50}  next:{nxt}")
with open("$REPORT_DIR/_jobs.txt","w") as f: f.write(str(len(errors)))
PYEOF

_je=$(cat "$REPORT_DIR/_jobs.txt" 2>/dev/null || echo 0)
[[ "$_je" -gt 0 ]] && WARNING=$((WARNING+1)) || true

# ── 14. ORG HEALTH INDICATORS ─────────────────────────────────────────────────

hdr "14 / 14  ORG HEALTH INDICATORS"

# Auth providers (SSO)
sso=$(q health_sso "SELECT DeveloperName, ProviderType, FriendlyName FROM AuthProvider ORDER BY ProviderType")
[[ "$sso" -gt 0 ]] && ok "SSO configured: $sso auth provider(s)" || info "No SSO / Auth Providers configured"

# Platform Cache
cache=$(q health_cache "SELECT DeveloperName, MasterLabel, OrganizationCacheAllocation, SessionCacheAllocation FROM PlatformCachePartition ORDER BY DeveloperName")
[[ "$cache" -gt 0 ]] && ok "Platform Cache: $cache partition(s) defined" || info "No Platform Cache partitions — consider adding for performance"

# Sharing recalc jobs stuck
sharing_stuck=$(q health_sharing "SELECT Id, Status, CreatedDate FROM AsyncApexJob WHERE JobType = 'SharingRecalculation' AND Status IN ('Processing','Queued','Preparing') AND CreatedDate < LAST_N_HOURS:24")
[[ "$sharing_stuck" -gt 0 ]] && warn "$sharing_stuck sharing recalculation job(s) running > 24h (sharing complexity issue)" || ok "No stuck sharing recalculation jobs"

# Duplicate rules
dup=$(q health_dup "SELECT DeveloperName, IsActive, SobjectType FROM DuplicateRule WHERE IsActive = TRUE ORDER BY SobjectType")
[[ "$dup" -gt 0 ]] && ok "Duplicate rules active: $dup" || info "No active duplicate rules"

# Data classification coverage
unclassified=$(qt health_pii "SELECT COUNT() FROM FieldDefinition WHERE SecurityClassification = NULL AND EntityDefinition.QualifiedApiName IN ('Contact','Lead','Case')")
[[ "$unclassified" -gt 0 ]] && warn "$unclassified unclassified field(s) on Contact/Lead/Case — GDPR/CCPA tagging needed" || ok "Data classification: Contact/Lead/Case fields are tagged"

# Long-running batch jobs
long_batch=$(q health_batch "SELECT ApexClass.Name, Status, CreatedDate, JobItemsProcessed, TotalJobItems FROM AsyncApexJob WHERE Status = 'Processing' AND JobType = 'BatchApex' AND CreatedDate < LAST_N_HOURS:2")
[[ "$long_batch" -gt 0 ]] && warn "$long_batch batch job(s) running > 2 hours" || ok "No long-running batch jobs"

# ── FINAL REPORT ──────────────────────────────────────────────────────────────

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

printf '\n'
printf '\e[1;35m╔══════════════════════════════════════════════════════════════╗\e[0m\n'
if   [[ "$CRITICAL" -gt 0 ]]; then
  printf '\e[1;31m║  OVERALL RESULT: 🔴 CRITICAL %-30s║\e[0m\n' ""
elif [[ "$WARNING"  -gt 0 ]]; then
  printf '\e[1;33m║  OVERALL RESULT: 🟡 WARNING  %-30s║\e[0m\n' ""
else
  printf '\e[1;32m║  OVERALL RESULT: 🟢 HEALTHY  %-30s║\e[0m\n' ""
fi
printf '\e[1;35m║  🔴 Critical: %-45s║\e[0m\n' "$CRITICAL"
printf '\e[1;35m║  🟡 Warnings: %-45s║\e[0m\n' "$WARNING"
printf '\e[1;35m║  ✅ Clean domains (no findings): %-28s║\e[0m\n' "$CLEAN"
printf '\e[1;35m║  Duration: %-49s║\e[0m\n' "${DURATION}s"
printf '\e[1;35m║  Report: %-51s║\e[0m\n' "$OUTPUT"
printf '\e[1;35m╚══════════════════════════════════════════════════════════════╝\e[0m\n'

# Write markdown report
cat > "$OUTPUT" <<MDEOF
# Org Scan Report — 14 Domains
**Org:** \`$TARGET_ORG\`  |  **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')  |  **Lookback:** ${DAYS}d  |  **Duration:** ${DURATION}s

## Overall: $([ "$CRITICAL" -gt 0 ] && echo "🔴 CRITICAL" || ([ "$WARNING" -gt 0 ] && echo "🟡 WARNING" || echo "🟢 HEALTHY"))

| # | Domain | Status |
|---|--------|--------|
| 1 | Governor Limits | $([ "${_lc:-0}" -gt 0 ] && echo "🔴 ${_lc} critical" || ([ "${_lw:-0}" -gt 0 ] && echo "🟡 ${_lw} warning" || echo "🟢")) |
| 2 | Apex Exceptions | $([ "$total_ex" -gt 0 ] && echo "🔴 $total_ex" || echo "🟢") |
| 3 | Test Coverage | ${cov_pct:-?}% |
| 4 | Connected Apps | $([ "${ig_count:-0}" -gt 0 ] && echo "🔴 inactive user grants" || echo "🟢") |
| 5 | User Security | $([ "$frozen" -gt 0 ] && echo "🔴 $frozen frozen" || echo "🟢") |
| 6 | Deactivated Users | $([ "$orphan" -gt 0 ] && echo "🔴 $orphan orphan grants" || echo "🟢") |
| 7 | Flow + Automation | $([ "$flow_err" -gt 0 ] && echo "🟡 $flow_err errors" || echo "🟢") |
| 8 | Storage | See limits |
| 9 | Login Anomalies | $([ "${_lf:-0}" -gt 0 ] && echo "🟡 ${_lf} failures" || echo "🟢") |
| 10 | Event Logs | $([ "$elf_avail" -gt 0 ] && echo "✅ available" || echo "ℹ️ not enabled") |
| 11 | Setup Audit Trail | $([ "${_ar:-0}" -gt 0 ] && echo "🔴 ${_ar} high-risk" || echo "🟢") |
| 12 | Security Posture | $([ "$certs" -gt 0 ] && echo "🟡 certs expiring" || echo "🟢") |
| 13 | Scheduled Jobs | $([ "${_je:-0}" -gt 0 ] && echo "🟡 ${_je} errors" || echo "🟢") |
| 14 | Org Health | See details |

*Full data: $REPORT_DIR/*
MDEOF

echo ""
echo "  Data: $REPORT_DIR/"
echo "  Report: $OUTPUT"
echo ""

[[ "$CRITICAL" -gt 0 ]] && exit 1 || exit 0
