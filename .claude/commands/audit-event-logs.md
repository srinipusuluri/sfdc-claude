---
description: Query and analyze Salesforce Event Monitoring logs for a specified event type and date range. Surfaces anomalies and produces a security findings report.
argument-hint: [--target-org <alias>] [--event-type <type>] [--days <n>]
---

Analyze Salesforce event logs for the requested event type and period.

## Steps

1. Parse arguments:
   - `--target-org`: defaults to `prod-org`
   - `--event-type`: defaults to `ReportExport,Login,DataExport,PermissionSetAssignment` (comma-separated)
   - `--days`: defaults to `7`

2. Verify Event Monitoring is enabled:
   ```bash
   sf data query \
     --query "SELECT Id FROM EventLogFile LIMIT 1" \
     --target-org <target-org>
   ```
   If this fails, report that Event Monitoring is not enabled and stop.

3. For each event type, list available log files for the period:
   ```bash
   sf data query \
     --query "SELECT Id, EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType = '<TYPE>' AND CreatedDate = LAST_N_DAYS:<days> ORDER BY LogDate DESC" \
     --target-org <target-org>
   ```

4. Use the **org-auditor** agent to:
   - Download each log file via REST (`/services/data/v66.0/sobjects/EventLogFile/<Id>/LogFile`)
   - Parse the CSV content
   - Identify anomalies: high row counts, off-hours access, unusual source IPs, unexpected users

5. Cross-reference findings with LoginHistory:
   ```bash
   sf data query \
     --query "SELECT Username, SourceIp, LoginTime, Status FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:<days> AND Status != 'Success' ORDER BY LoginTime DESC LIMIT 100" \
     --target-org <target-org>
   ```

## Output

Produce a single report:

1. **Period covered** and **event types analyzed**
2. **Summary table** — event counts by type and user
3. **Anomalies** — high-volume exports, off-hours access, new IPs, unauthorized API calls
4. **Top users by activity** per event type
5. **Recommended actions** — account review, IP blocks, alerting rules

## Exit behavior

Exit non-zero if any finding is severity High or Critical, so this can be wired into a scheduled CI check.
