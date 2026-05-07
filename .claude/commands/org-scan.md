---
description: Full Salesforce org scan — governor limits, Apex exceptions, event logs, login anomalies, storage, flow errors, scheduled jobs, setup audit trail, and stale users. Produces a single prioritised report.
argument-hint: [--target-org <alias>] [--days <n>] [--output <file>]
---

Run a complete org health and security scan using the **org-scanner** agent.

## Parse arguments

- `--target-org`: defaults to `dev`
- `--days`: lookback window for events/logins/audit trail, defaults to `7`
- `--output`: optional path to save the markdown report

## Execution

Hand off to the **org-scanner** agent with these instructions:

> Run a complete org scan against `<target-org>` with a `<days>`-day lookback.
> Execute every domain check in sequence. For each domain, capture both the raw
> data and any findings. Produce the full report in the format specified in the
> agent definition. Save to `<output>` if provided.

## Domain checklist (run in this order)

### 1. Governor Limits
```bash
sf api request rest "/services/data/v66.0/limits" \
  --target-org <target-org> 2>/dev/null
```
Categorise every limit: 🔴 ≥80% / 🟡 40–79% / 🟢 <40%.

### 2. Apex Exceptions
```bash
# EventLogFile (if Event Monitoring available)
sf data query --query "SELECT Id, EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType IN ('ApexUnexpectedException','ApexExecution') AND CreatedDate = LAST_N_DAYS:<days> ORDER BY LogDate DESC" --target-org <target-org> --json 2>/dev/null

# Async job failures
sf data query --query "SELECT ApexClass.Name, Status, NumberOfErrors, ExtendedStatus, CreatedDate FROM AsyncApexJob WHERE Status IN ('Failed','Aborted') AND CreatedDate = LAST_N_DAYS:<days> ORDER BY CreatedDate DESC LIMIT 20" --target-org <target-org> --json 2>/dev/null

# Debug logs with errors
sf data query --query "SELECT StartTime, Status, LogLength, Operation, Application FROM ApexLog WHERE Status != 'Success' ORDER BY StartTime DESC LIMIT 20" --target-org <target-org> --json 2>/dev/null

# Failed test results
sf data query --query "SELECT ApexClass.Name, MethodName, Outcome, Message, StackTrace, CreatedDate FROM ApexTestResult WHERE Outcome = 'Fail' ORDER BY CreatedDate DESC LIMIT 20" --target-org <target-org> --json 2>/dev/null
```

### 3. Flow Errors
```bash
sf data query --query "SELECT InterviewLabel, CurrentElement, ErrorMessage, CreatedDate FROM FlowInterviewLog WHERE CreatedDate = LAST_N_DAYS:<days> AND InterviewStatus = 'Error' ORDER BY CreatedDate DESC LIMIT 20" --target-org <target-org> --json 2>/dev/null
```

### 4. Storage
```bash
# Large ContentVersion files
sf data query --query "SELECT Title, ContentSize, FileType, Owner.Name, CreatedDate FROM ContentVersion WHERE IsLatest = TRUE ORDER BY ContentSize DESC LIMIT 10" --target-org <target-org> --json 2>/dev/null
```

### 5. Login Anomalies
```bash
sf data query --query "SELECT UserId, LoginTime, LoginType, Status, SourceIp, Browser, Platform, Application, CountryIso FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:<days> ORDER BY LoginTime DESC LIMIT 200" --target-org <target-org> --json 2>/dev/null
```
Flag: failures, off-hours, new countries, >5 sessions/day/user, password flow on SSO orgs.

### 6. Event Logs
```bash
sf data query --query "SELECT EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType IN ('ReportExport','DataExport','PermissionSetAssignment','Login','UserCreation') AND CreatedDate = LAST_N_DAYS:<days> ORDER BY LogDate DESC" --target-org <target-org> --json 2>/dev/null
```
If no records: note that Event Monitoring is not enabled.

### 7. Setup Audit Trail
```bash
sf data query --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:<days> ORDER BY CreatedDate DESC LIMIT 50" --target-org <target-org> --json 2>/dev/null
```

### 8. Stale Users
```bash
sf data query --query "SELECT Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = TRUE AND LastLoginDate < LAST_N_DAYS:90 AND UserType = 'Standard' ORDER BY LastLoginDate ASC NULLS FIRST LIMIT 20" --target-org <target-org> --json 2>/dev/null
```

### 9. Scheduled Jobs
```bash
sf data query --query "SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered FROM CronTrigger ORDER BY NextFireTime ASC" --target-org <target-org> --json 2>/dev/null
```

## Severity rules

| Finding | Severity |
|---------|----------|
| Any limit ≥ 80% | 🔴 Critical |
| Any limit 40–79% | 🟡 Warning |
| Any Apex exception or async job failure | 🔴 Critical |
| Any Flow interview error | 🟡 Warning |
| Login failures > 5 in lookback window | 🟡 Warning |
| `Username-Password Flow Disabled` on SSO org | 🟢 Info (expected) |
| Stale users > 10 | 🟡 Warning |
| Code change in production via SetupAuditTrail | 🔴 Critical |
| `ModifyAllData` granted via SetupAuditTrail | 🔴 Critical |
| Scheduled job in ERROR state | 🟡 Warning |

## Output

Produce the full scan report in the `org-scanner` agent's output format.

If `--output` was provided, also write the report to that file:
```bash
mkdir -p reports
# write markdown to reports/org-scan-<date>.md
```

## Exit behaviour

Return exit code 1 if any 🔴 Critical finding was raised, so `/org-scan` can be wired into CI as a required pre-deploy health check.
