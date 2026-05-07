---
name: event-log-query
description: Query Salesforce Event Monitoring logs (EventLogFile) via the REST API and SOQL. Requires Event Monitoring add-on. Use to investigate data exfiltration, API abuse, unexpected logins, or unusual activity in an org.
argument-hint: [--target-org <alias>] [--event-type <type>] [--days <n>]
---

# event-log-query

Query and analyze Salesforce Event Monitoring log files for security and operational investigation.

## Prerequisites

```bash
# Verify Event Monitoring is enabled
sf data query \
  --query "SELECT Id FROM EventLogFile LIMIT 1" \
  --target-org prod-org
# If this errors with INVALID_TYPE, the add-on is not enabled
```

## List available log files

```bash
# All event types available in last N days
sf data query \
  --query "SELECT EventType, LogDate, LogFileLength, LogFile FROM EventLogFile WHERE CreatedDate = LAST_N_DAYS:${DAYS:-1} ORDER BY EventType, LogDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Download and parse a log file

```bash
# Step 1: Get the log file record ID
sf data query \
  --query "SELECT Id, EventType, LogDate FROM EventLogFile WHERE EventType = '${EVENT_TYPE:-ReportExport}' AND LogDate = TODAY" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --json

# Step 2: Download the CSV using the REST endpoint
# The LogFile field contains the relative URL:
# /services/data/v66.0/sobjects/EventLogFile/<Id>/LogFile
sf api request rest \
  "/services/data/v66.0/sobjects/EventLogFile/<ID>/LogFile" \
  --target-org "${TARGET_ORG:-prod-org}" \
  > reports/event_${EVENT_TYPE}_$(date +%Y%m%d).csv

# Step 3: Parse and summarize
column -t -s ',' reports/event_${EVENT_TYPE}_$(date +%Y%m%d).csv | head -50
```

## High-value queries by investigation type

### Data exfiltration signals
```bash
# ReportExport: who exported how many rows
sf data query \
  --query "SELECT EventType, LogDate FROM EventLogFile WHERE EventType IN ('ReportExport', 'ListViewExport', 'DataExport', 'ContentDistribution') AND CreatedDate = LAST_N_DAYS:7" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Unusual API access
```bash
# API event: high-volume callers or unexpected user agents
sf data query \
  --query "SELECT EventType, LogDate FROM EventLogFile WHERE EventType = 'API' AND CreatedDate = LAST_N_DAYS:1" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Authentication anomalies
```bash
# Login events (failed + unusual IPs)
sf data query \
  --query "SELECT EventType, LogDate FROM EventLogFile WHERE EventType = 'Login' AND CreatedDate = LAST_N_DAYS:7" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Apex exceptions
```bash
# Unexpected exceptions in production
sf data query \
  --query "SELECT EventType, LogDate FROM EventLogFile WHERE EventType = 'ApexUnexpectedException' AND CreatedDate = LAST_N_DAYS:7" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Permission changes
```bash
# Permission set assignments
sf data query \
  --query "SELECT EventType, LogDate FROM EventLogFile WHERE EventType = 'PermissionSetAssignment' AND CreatedDate = LAST_N_DAYS:30" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## CSV field reference (Login event)

| Field | Description |
|-------|-------------|
| `LOGIN_STATUS` | `Success` or failure code |
| `USER_ID_DERIVED` | 15-char User ID |
| `SOURCE_IP` | Client IP address |
| `LOGIN_TYPE` | `Username-Password`, `OAuth 2.0`, `SAML`, etc. |
| `BROWSER_TYPE` | Browser or API client identifier |
| `OS_NAME` | Client OS |
| `TIMESTAMP_DERIVED` | UTC timestamp |
| `SESSION_KEY` | Session identifier |

## CSV field reference (ReportExport event)

| Field | Description |
|-------|-------------|
| `USER_ID_DERIVED` | Who ran the export |
| `REPORT_ID_DERIVED` | Report being exported |
| `ROWS_PROCESSED` | Number of rows exported |
| `TIMESTAMP_DERIVED` | When |
| `SOURCE_IP` | From where |

## Output

Summarize findings as:
- Event type and date range covered
- Top users by activity
- Anomalous entries (high row counts, off-hours access, unknown IPs)
- Recommended follow-up actions
