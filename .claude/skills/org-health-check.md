---
name: org-health-check
description: Run a comprehensive Salesforce org health check — governor limit consumption, storage, inactive users, test coverage, flow errors, scheduled job status, and stale metadata. Produces a prioritized remediation report.
argument-hint: [--target-org <alias>]
---

# org-health-check

A holistic snapshot of org health across usage, performance, and hygiene dimensions.

## Governor limits (Tooling API)

```bash
# Fetch all current limits
sf api request rest \
  "/services/data/v66.0/limits" \
  --target-org "${TARGET_ORG:-prod-org}" \
  | python3 -c "
import json, sys
limits = json.load(sys.stdin)
print(f'{'Limit':<40} {'Used':>10} {'Max':>10} {'Pct':>6}')
print('-'*70)
for name, vals in sorted(limits.items()):
    if isinstance(vals, dict) and 'Remaining' in vals and 'Max' in vals:
        used = vals['Max'] - vals['Remaining']
        pct = (used / vals['Max'] * 100) if vals['Max'] > 0 else 0
        flag = ' ⚠️' if pct > 75 else ''
        print(f'{name:<40} {used:>10} {vals[\"Max\"]:>10} {pct:>5.1f}%{flag}')
"
```

**Key limits to watch:**
| Limit key | Threshold | Action if over 80% |
|-----------|-----------|-------------------|
| `DataStorageMB` | 80% | Archive old records, purge audit logs |
| `FileStorageMB` | 80% | Review ContentDocument, delete old files |
| `DailyApiRequests` | 80% | Rate-limit integrations, use Bulk API |
| `DailyBulkApiBatches` | 80% | Review batch sizes |
| `ActiveScratchOrgs` | 80% | Delete expired scratch orgs |
| `HourlyLongTermIdMapping` | 80% | Review Lightning URL usage |

## Storage breakdown

```bash
# Data storage by object (top 20)
sf data query \
  --query "SELECT SobjectType, COUNT(Id) RecordCount FROM EntityParticle WHERE (SobjectType != 'ContentBodyRevision') GROUP BY SobjectType ORDER BY RecordCount DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-prod-org}" || \
sf data query \
  --query "SELECT TableEnumOrId, COUNT(Id) RecordCount FROM RecordType GROUP BY TableEnumOrId ORDER BY RecordCount DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-prod-org}"

# File storage: large files
sf data query \
  --query "SELECT Title, ContentSize, FileType, Owner.Name, CreatedDate FROM ContentVersion WHERE IsLatest = TRUE ORDER BY ContentSize DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## User health

```bash
# Inactive users still licensed
sf data query \
  --query "SELECT Id, Name, Username, LastLoginDate, Profile.Name, UserType FROM User WHERE IsActive = FALSE AND LastLoginDate != NULL ORDER BY LastLoginDate DESC LIMIT 50" \
  --target-org "${TARGET_ORG:-prod-org}"

# Active users not logged in for 90+ days (license waste)
sf data query \
  --query "SELECT Id, Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = TRUE AND LastLoginDate < LAST_N_DAYS:90 AND UserType = 'Standard' ORDER BY LastLoginDate ASC NULLS FIRST LIMIT 50" \
  --target-org "${TARGET_ORG:-prod-org}"

# User count by license type
sf data query \
  --query "SELECT UserType, COUNT(Id) Count FROM User WHERE IsActive = TRUE GROUP BY UserType ORDER BY Count DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Test coverage

```bash
# Classes below 75% coverage
sf data query \
  --query "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate WHERE (NumLinesCovered + NumLinesUncovered) > 0 ORDER BY (NumLinesCovered / (NumLinesCovered + NumLinesUncovered)) ASC LIMIT 30" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --use-tooling-api

# Org-wide coverage
sf data query \
  --query "SELECT PercentCovered FROM ApexOrgWideCoverage" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --use-tooling-api
```

## Flow health

```bash
# Flows with error elements or no error handling
sf data query \
  --query "SELECT DeveloperName, ProcessType, ActiveVersionId, LatestVersionId FROM FlowDefinition WHERE IsActive = TRUE ORDER BY DeveloperName" \
  --target-org "${TARGET_ORG:-prod-org}"

# Recent Flow interview errors
sf data query \
  --query "SELECT InterviewLabel, ErrorMessage, CreatedDate, CurrentElement FROM FlowInterviewLog WHERE CreatedDate = LAST_N_DAYS:7 AND InterviewStatus = 'Error' ORDER BY CreatedDate DESC LIMIT 50" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Scheduled jobs

```bash
# All scheduled Apex jobs
sf data query \
  --query "SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered, JobType FROM CronTrigger ORDER BY NextFireTime ASC" \
  --target-org "${TARGET_ORG:-prod-org}"

# Failed batch jobs in last 7 days
sf data query \
  --query "SELECT ApexClass.Name, Status, JobType, NumberOfErrors, TotalJobItems, CompletedDate FROM AsyncApexJob WHERE Status = 'Failed' AND CreatedDate = LAST_N_DAYS:7 ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Metadata hygiene

```bash
# Unused permission sets (assigned to 0 users)
sf data query \
  --query "SELECT Name, Label FROM PermissionSet WHERE IsOwnedByProfile = FALSE AND Id NOT IN (SELECT PermissionSetId FROM PermissionSetAssignment) ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Inactive flows (not active but still exist)
sf data query \
  --query "SELECT DeveloperName, ProcessType, LatestVersionId FROM FlowDefinition WHERE IsActive = FALSE ORDER BY DeveloperName" \
  --target-org "${TARGET_ORG:-prod-org}"

# Validation rules that are inactive
sf data query \
  --query "SELECT EntityDefinition.QualifiedApiName, ValidationName, Active FROM ValidationRule WHERE Active = FALSE ORDER BY EntityDefinition.QualifiedApiName" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --use-tooling-api
```

## Output format

Produce a dashboard:

```
## Org Health Report — <org alias> — <date>

### 🔴 Critical (action required)
- ...

### 🟡 Warning (monitor closely)
- ...

### 🟢 Healthy
- ...

### Storage: X MB / Y MB (Z%)
### Coverage: X%
### Active users without recent login: N
### Failed jobs (7d): N
### Flow errors (7d): N
```
