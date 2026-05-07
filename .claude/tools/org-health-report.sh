#!/usr/bin/env bash
# Run a comprehensive Salesforce org health check.
# Usage: org-health-report.sh --target-org <alias> [--output-dir <dir>]

set -euo pipefail

TARGET_ORG="prod-org"
OUTPUT_DIR="reports/org-health-$(date +%Y%m%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org)  TARGET_ORG="$2"; shift 2 ;;
    --output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/health-report.md"

echo "=== Org Health Check ==="
echo "Org:    $TARGET_ORG"
echo "Output: $OUTPUT_DIR"
echo ""

# Helper: run a SOQL query and save JSON
run_soql() {
  local label="$1"
  local query="$2"
  local key="$3"
  local tooling="${4:-}"
  local flag=""
  [[ "$tooling" == "tooling" ]] && flag="--use-tooling-api"
  echo "Checking: $label..."
  sf data query --query "$query" --target-org "$TARGET_ORG" $flag --json \
    > "$OUTPUT_DIR/${key}.json" 2>&1 || true
}

# 1. Governor limits via REST
echo "Fetching org limits..."
sf api request rest "/services/data/v66.0/limits" \
  --target-org "$TARGET_ORG" \
  > "$OUTPUT_DIR/limits.json" 2>&1 || echo "  Could not fetch limits"

# 2. Test coverage
run_soql "Apex code coverage" \
  "SELECT PercentCovered FROM ApexOrgWideCoverage" \
  "coverage" "tooling"

run_soql "Classes below 75% coverage" \
  "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate WHERE NumLinesCovered + NumLinesUncovered > 0 ORDER BY NumLinesCovered ASC LIMIT 30" \
  "low-coverage" "tooling"

# 3. Users
run_soql "Inactive users with login history" \
  "SELECT Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = TRUE AND LastLoginDate < LAST_N_DAYS:90 AND UserType = 'Standard' ORDER BY LastLoginDate ASC NULLS FIRST LIMIT 50" \
  "stale-users"

run_soql "User count by profile" \
  "SELECT Profile.Name, COUNT(Id) Count FROM User WHERE IsActive = TRUE GROUP BY Profile.Name ORDER BY Count DESC" \
  "users-by-profile"

# 4. Scheduled jobs
run_soql "Scheduled Apex jobs" \
  "SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered FROM CronTrigger ORDER BY NextFireTime ASC" \
  "scheduled-jobs"

run_soql "Failed async jobs (last 7d)" \
  "SELECT ApexClass.Name, Status, NumberOfErrors, TotalJobItems, CompletedDate FROM AsyncApexJob WHERE Status = 'Failed' AND CreatedDate = LAST_N_DAYS:7 ORDER BY CompletedDate DESC LIMIT 20" \
  "failed-jobs"

# 5. Flow health
run_soql "Flow interview errors (last 7d)" \
  "SELECT InterviewLabel, ErrorMessage, CreatedDate, CurrentElement FROM FlowInterviewLog WHERE CreatedDate = LAST_N_DAYS:7 AND InterviewStatus = 'Error' ORDER BY CreatedDate DESC LIMIT 50" \
  "flow-errors"

run_soql "Active flows" \
  "SELECT DeveloperName, ProcessType, ActiveVersionId, LatestVersionId FROM FlowDefinition WHERE IsActive = TRUE ORDER BY DeveloperName" \
  "active-flows"

# 6. Storage
run_soql "Large ContentVersions" \
  "SELECT Title, ContentSize, FileType, Owner.Name, CreatedDate FROM ContentVersion WHERE IsLatest = TRUE ORDER BY ContentSize DESC LIMIT 20" \
  "large-files"

# 7. Metadata hygiene
run_soql "Unused permission sets (0 assignments)" \
  "SELECT Name, Label FROM PermissionSet WHERE IsOwnedByProfile = FALSE AND Id NOT IN (SELECT PermissionSetId FROM PermissionSetAssignment) ORDER BY Name" \
  "unused-permsets"

# Build markdown report
echo "Generating report..."
python3 - <<PYEOF
import json, os
from datetime import datetime

def load(name):
    path = "$OUTPUT_DIR/" + name + ".json"
    try:
        with open(path) as f:
            d = json.load(f)
        return d.get("result", {}).get("records", [])
    except:
        return []

def load_raw(name):
    path = "$OUTPUT_DIR/" + name + ".json"
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return {}

issues = {"critical": [], "warning": [], "healthy": []}

# Limits check
limits = load_raw("limits")
if limits and not limits.get("message"):  # not an error
    for name, vals in limits.items():
        if not isinstance(vals, dict) or "Remaining" not in vals or not vals.get("Max"):
            continue
        pct = (vals["Max"] - vals["Remaining"]) / vals["Max"] * 100
        if pct > 90:
            issues["critical"].append(f"**{name}** at {pct:.0f}% ({vals['Max']-vals['Remaining']:,}/{vals['Max']:,})")
        elif pct > 75:
            issues["warning"].append(f"**{name}** at {pct:.0f}% ({vals['Max']-vals['Remaining']:,}/{vals['Max']:,})")

# Coverage
cov_records = load("coverage")
if cov_records:
    pct = cov_records[0].get("PercentCovered", 0)
    if pct < 75:
        issues["critical"].append(f"Org-wide Apex coverage: **{pct}%** (minimum is 75%)")
    elif pct < 85:
        issues["warning"].append(f"Org-wide Apex coverage: **{pct}%** — consider improving")
    else:
        issues["healthy"].append(f"Apex coverage: {pct}%")

# Stale users
stale = load("stale-users")
if len(stale) > 20:
    issues["critical"].append(f"**{len(stale)}** active users not logged in for 90+ days")
elif len(stale) > 5:
    issues["warning"].append(f"**{len(stale)}** active users not logged in for 90+ days")
else:
    issues["healthy"].append(f"User staleness: {len(stale)} stale accounts")

# Failed jobs
failed = load("failed-jobs")
if len(failed) > 5:
    issues["critical"].append(f"**{len(failed)}** failed async Apex jobs in last 7 days")
elif len(failed) > 0:
    issues["warning"].append(f"**{len(failed)}** failed async Apex jobs in last 7 days")
else:
    issues["healthy"].append("No failed async Apex jobs in last 7 days")

# Flow errors
flow_errs = load("flow-errors")
if len(flow_errs) > 10:
    issues["critical"].append(f"**{len(flow_errs)}** Flow interview errors in last 7 days")
elif len(flow_errs) > 0:
    issues["warning"].append(f"**{len(flow_errs)}** Flow interview errors in last 7 days")
else:
    issues["healthy"].append("No Flow interview errors in last 7 days")

# Unused permsets
unused = load("unused-permsets")
if len(unused) > 0:
    issues["warning"].append(f"**{len(unused)}** permission sets with no assignments (cleanup candidates)")

# Write report
with open("$REPORT", "w") as f:
    f.write(f"# Org Health Report\\n")
    f.write(f"**Org**: $TARGET_ORG  \\n")
    f.write(f"**Date**: {datetime.now().strftime('%Y-%m-%d %H:%M UTC')}\\n\\n")

    total = sum(len(v) for v in issues.values())
    if issues["critical"]:
        f.write(f"## Overall: 🔴 Critical\\n\\n")
    elif issues["warning"]:
        f.write(f"## Overall: 🟡 Warning\\n\\n")
    else:
        f.write(f"## Overall: 🟢 Healthy\\n\\n")

    if issues["critical"]:
        f.write("## 🔴 Critical (immediate action required)\\n\\n")
        for i in issues["critical"]:
            f.write(f"- {i}\\n")
        f.write("\\n")

    if issues["warning"]:
        f.write("## 🟡 Warnings\\n\\n")
        for i in issues["warning"]:
            f.write(f"- {i}\\n")
        f.write("\\n")

    if issues["healthy"]:
        f.write("## 🟢 Healthy\\n\\n")
        for i in issues["healthy"]:
            f.write(f"- {i}\\n")
        f.write("\\n")

    f.write("---\\n")
    f.write(f"*Full data in: $OUTPUT_DIR/*\\n")

print(f"Report written to: $REPORT")

# Print to console
for sev, label in [("critical","CRITICAL"), ("warning","WARNING"), ("healthy","HEALTHY")]:
    if issues[sev]:
        print(f"\\n[{label}]")
        for i in issues[sev]:
            print(f"  {i}")
PYEOF

echo ""
echo "=== Health check complete ==="
echo "Report: $REPORT"
