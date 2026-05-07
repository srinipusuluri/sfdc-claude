---
description: Full Salesforce org scan — 14 domains including governor limits, Apex exceptions, test coverage, connected apps, user security, deactivated users, flow errors, storage, login anomalies, event logs, setup audit trail, security posture, scheduled jobs, and org health indicators. Produces a single prioritised report.
argument-hint: [--target-org <alias>] [--days <n>] [--run-tests] [--output <file>]
---

Run a complete org health and security scan using the **org-scanner** agent.

## Parse arguments

- `--target-org`: defaults to `dev`
- `--days`: lookback window for events/logins/audit trail, defaults to `7`
- `--run-tests`: if present, execute Apex tests before measuring coverage (slower)
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
Priority limits: `DataStorageMB`, `FileStorageMB`, `DailyApiRequests`, `DailyAsyncApexExecutions`, `DailyBulkApiBatches`, `HourlyPublishedPlatformEvents`.

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

### 3. Apex Test Coverage
```bash
# Org-wide coverage (Tooling API)
sf data query --query "SELECT PercentCovered FROM ApexOrgWideCoverage" --target-org <target-org> --use-tooling-api --json 2>/dev/null

# Per-class coverage — worst first
sf data query --query "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate WHERE NumLinesCovered + NumLinesUncovered > 0 ORDER BY NumLinesCovered ASC LIMIT 30" --target-org <target-org> --use-tooling-api --json 2>/dev/null
```
Flag: org-wide < 75% is 🔴 Critical. If `--run-tests` present, execute `sf apex run test --test-level RunLocalTests --code-coverage` first.

### 4. Connected Apps
```bash
# Connected App inventory
sf data query --query "SELECT Id, Name, ContactEmail, OptionsAllowAdminApprovedUsersOnly FROM ConnectedApplication ORDER BY Name" --target-org <target-org> --json 2>/dev/null

# OAuth grants to inactive users — Critical
sf data query --query "SELECT ConnectedApplication.Name, User.Username, User.IsActive, Scopes, LastUsedDate FROM OAuth2 WHERE User.IsActive = FALSE ORDER BY LastUsedDate DESC" --target-org <target-org> --json 2>/dev/null

# Stale OAuth grants (90+ days unused)
sf data query --query "SELECT ConnectedApplication.Name, User.Username, Scopes, LastUsedDate FROM OAuth2 WHERE LastUsedDate < LAST_N_DAYS:90 ORDER BY LastUsedDate ASC LIMIT 20" --target-org <target-org> --json 2>/dev/null
```

### 5. User Security
```bash
# Frozen accounts (still API-accessible!)
sf data query --query "SELECT UserId, User.Username, User.Name, User.Profile.Name, IsFrozen, IsPasswordLocked FROM UserLogin WHERE IsFrozen = TRUE ORDER BY UserId" --target-org <target-org> --json 2>/dev/null

# Password-locked accounts (brute force signal)
sf data query --query "SELECT UserId, User.Username, User.Name, IsPasswordLocked FROM UserLogin WHERE IsPasswordLocked = TRUE ORDER BY UserId" --target-org <target-org> --json 2>/dev/null

# ModifyAllData via profile or permission set
sf data query --query "SELECT Name FROM Profile WHERE PermissionsModifyAllData = TRUE ORDER BY Name" --target-org <target-org> --json 2>/dev/null
sf data query --query "SELECT Assignee.Username, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.PermissionsModifyAllData = TRUE ORDER BY Assignee.Username" --target-org <target-org> --json 2>/dev/null

# API-enabled non-integration users
sf data query --query "SELECT Name, Username, Profile.Name FROM User WHERE IsActive = TRUE AND Profile.PermissionsApiEnabled = TRUE AND Profile.Name NOT IN ('System Administrator','Integration User','API Only User') AND UserType = 'Standard' ORDER BY Profile.Name LIMIT 30" --target-org <target-org> --json 2>/dev/null
```

### 6. Deactivated Users + Orphaned Access
```bash
# Recently deactivated
sf data query --query "SELECT Id, Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = FALSE AND LastModifiedDate = LAST_N_DAYS:<days> ORDER BY LastModifiedDate DESC LIMIT 30" --target-org <target-org> --json 2>/dev/null

# Surviving OAuth grants for inactive users
sf data query --query "SELECT ConnectedApplication.Name, User.Username, Scopes, LastUsedDate FROM OAuth2 WHERE User.IsActive = FALSE ORDER BY LastUsedDate DESC" --target-org <target-org> --json 2>/dev/null

# Stale permission set assignments for inactive users
sf data query --query "SELECT Assignee.Username, PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.IsActive = FALSE ORDER BY Assignee.Username LIMIT 20" --target-org <target-org> --json 2>/dev/null
```

### 7. Flow Errors + Legacy Automation
```bash
# Flow interview errors
sf data query --query "SELECT InterviewLabel, CurrentElement, ErrorMessage, CreatedDate FROM FlowInterviewLog WHERE CreatedDate = LAST_N_DAYS:<days> AND InterviewStatus = 'Error' ORDER BY CreatedDate DESC LIMIT 20" --target-org <target-org> --json 2>/dev/null

# Active Process Builder (should migrate to Flow)
sf data query --query "SELECT DeveloperName, ProcessType FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','CustomEvent','InvocableProcess') ORDER BY DeveloperName" --target-org <target-org> --json 2>/dev/null

# Active Workflow Rules
sf data query --query "SELECT TableEnumOrId, COUNT(Id) Count FROM WorkflowRule WHERE IsActive = TRUE GROUP BY TableEnumOrId ORDER BY Count DESC" --target-org <target-org> --json 2>/dev/null

# Automation stacking (>1 active flow per object)
sf data query --query "SELECT TriggerObjectOrEvent.QualifiedApiName, COUNT(Id) FlowCount FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType = 'AutoLaunchedFlow' GROUP BY TriggerObjectOrEvent.QualifiedApiName HAVING COUNT(Id) > 1 ORDER BY FlowCount DESC" --target-org <target-org> --json 2>/dev/null
```

### 8. Storage
```bash
# DataStorageMB and FileStorageMB come from Domain 1 (limits API)

# Top 10 largest files
sf data query --query "SELECT Title, ContentSize, FileType, Owner.Name, CreatedDate FROM ContentVersion WHERE IsLatest = TRUE ORDER BY ContentSize DESC LIMIT 10" --target-org <target-org> --json 2>/dev/null
```

### 9. Login Anomalies
```bash
sf data query --query "SELECT UserId, LoginTime, LoginType, Status, SourceIp, Browser, Platform, Application, CountryIso FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:<days> ORDER BY LoginTime DESC LIMIT 200" --target-org <target-org> --json 2>/dev/null

# MFA failures
sf data query --query "SELECT UserId, EventDate, Activity, Status FROM VerificationHistory WHERE Status != 'Success' AND EventDate = LAST_N_DAYS:<days> ORDER BY EventDate DESC LIMIT 20" --target-org <target-org> --json 2>/dev/null
```
Flag: failures, off-hours, new countries, >5 sessions/day/user, MFA bypasses.

### 10. Event Logs
```bash
sf data query --query "SELECT EventType, LogDate, LogFileLength FROM EventLogFile WHERE EventType IN ('ReportExport','DataExport','PermissionSetAssignment','Login','UserCreation','ConnectedApp') AND CreatedDate = LAST_N_DAYS:<days> ORDER BY LogDate DESC" --target-org <target-org> --json 2>/dev/null
```
If no records: report Event Monitoring not enabled with upgrade path.

### 11. Setup Audit Trail
```bash
sf data query --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:<days> ORDER BY CreatedDate DESC LIMIT 100" --target-org <target-org> --json 2>/dev/null
```
🔴 Immediate flags: Apex/Flow changes by non-CI users, `ModifyAllData` granted, session timeout extended, Named Credential endpoint changed.

### 12. Security Posture
```bash
# CORS whitelist — flag wildcards and http://
sf data query --query "SELECT Id, UrlPattern FROM CorsWhitelistEntry ORDER BY UrlPattern" --target-org <target-org> --json 2>/dev/null

# CSP Trusted Sites
sf data query --query "SELECT Id, EndpointUrl, Context, IsActive FROM ContentSecurityPolicy ORDER BY EndpointUrl" --target-org <target-org> --json 2>/dev/null

# Certificates nearing expiry
sf data query --query "SELECT DeveloperName, ExpirationDate, KeySize FROM Certificate WHERE ExpirationDate < NEXT_N_DAYS:90 ORDER BY ExpirationDate ASC" --target-org <target-org> --json 2>/dev/null

# Guest user object access — Critical if Contact/Account/Case
sf data query --query "SELECT SobjectType, PermissionsRead, PermissionsCreate FROM ObjectPermissions WHERE Parent.Profile.UserType = 'Guest' AND PermissionsRead = TRUE ORDER BY SobjectType" --target-org <target-org> --json 2>/dev/null

# Installed packages
sf data query --query "SELECT SubscriberPackage.Name, SubscriberPackage.NamespacePrefix, SubscriberPackageVersion.Name FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name" --target-org <target-org> --json 2>/dev/null

# Data Classification — unclassified PII fields
sf data query --query "SELECT QualifiedApiName, EntityDefinition.QualifiedApiName FROM FieldDefinition WHERE SecurityClassification = NULL AND EntityDefinition.QualifiedApiName IN ('Contact','Lead','Case','Account') ORDER BY EntityDefinition.QualifiedApiName LIMIT 30" --target-org <target-org> --use-tooling-api --json 2>/dev/null
```

### 13. Scheduled Jobs
```bash
# CronTrigger state
sf data query --query "SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered FROM CronTrigger ORDER BY NextFireTime ASC" --target-org <target-org> --json 2>/dev/null

# Failed scheduled Apex
sf data query --query "SELECT ApexClass.Name, Status, NumberOfErrors, CreatedDate FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND Status = 'Failed' AND CreatedDate = LAST_N_DAYS:<days> ORDER BY CreatedDate DESC LIMIT 10" --target-org <target-org> --json 2>/dev/null

# Long-running batch jobs (> 2 hours)
sf data query --query "SELECT ApexClass.Name, Status, JobType, CreatedDate, TotalJobItems, NumberOfErrors FROM AsyncApexJob WHERE Status IN ('Processing','Queued') AND JobType = 'BatchApex' AND CreatedDate < LAST_N_HOURS:2 ORDER BY CreatedDate ASC LIMIT 10" --target-org <target-org> --json 2>/dev/null
```

### 14. Org Health Indicators
```bash
# Sharing recalculation jobs stuck > 24h
sf data query --query "SELECT Id, Status, CreatedDate FROM AsyncApexJob WHERE JobType = 'SharingRecalculation' AND Status IN ('Queued','Processing') ORDER BY CreatedDate ASC LIMIT 5" --target-org <target-org> --json 2>/dev/null

# Active duplicate rules (complexity signal)
sf data query --query "SELECT MasterLabel, SobjectType, IsActive FROM DuplicateRule WHERE IsActive = TRUE ORDER BY SobjectType" --target-org <target-org> --json 2>/dev/null

# Platform Cache partitions
sf data query --query "SELECT DeveloperName, OrganizationCacheAllocation, SessionCacheAllocation FROM PlatformCachePartition ORDER BY DeveloperName" --target-org <target-org> --json 2>/dev/null

# Auth providers (SSO configured)
sf data query --query "SELECT DeveloperName, ProviderType, FriendlyName FROM AuthProvider ORDER BY ProviderType" --target-org <target-org> --json 2>/dev/null

# Legacy Workflow Rule count
sf data query --query "SELECT COUNT(Id) FROM WorkflowRule WHERE IsActive = TRUE" --target-org <target-org> --json 2>/dev/null

# Active Process Builder count
sf data query --query "SELECT COUNT(Id) FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','InvocableProcess','CustomEvent')" --target-org <target-org> --json 2>/dev/null
```

## Severity rules

| Finding | Severity |
|---------|----------|
| OAuth grant to deactivated user | 🔴 Critical |
| Any limit ≥ 80% | 🔴 Critical |
| Apex exception or async job failure | 🔴 Critical |
| Guest user reading Contact/Account/Case | 🔴 Critical |
| Code change in prod by non-CI user | 🔴 Critical |
| `ModifyAllData` granted to non-admin | 🔴 Critical |
| Certificate expiring < 30 days | 🔴 Critical |
| Test coverage < 75% org-wide | 🔴 Critical |
| Frozen account with active OAuth session | 🔴 Critical |
| CORS wildcard `*` entry | 🟡 High |
| Stale OAuth grant (90+ days unused) | 🟡 High |
| API-enabled non-integration user | 🟡 Medium |
| Flow interview error | 🟡 Medium |
| Login failures > 5 in window | 🟡 Medium |
| Active Process Builder (migrate to Flow) | 🟡 Medium |
| Certificate expiring 30–90 days | 🟡 Medium |
| Unclassified PII fields | 🟡 Medium |
| Scheduled job in ERROR state | 🟡 Medium |
| No Platform Cache in complex org | ℹ️ Info |

## Output

Produce the full scan report in the `org-scanner` agent's output format (14-domain report card with overall severity, immediate actions table, warnings table, clean domains list, domain detail sections, and prioritised recommendations).

If `--output` was provided, also write the report to that file:
```bash
mkdir -p reports
# write markdown to reports/org-scan-<date>.md
```

## Exit behaviour

Return exit code 1 if any 🔴 Critical finding was raised, so `/org-scan` can be wired into CI as a required pre-deploy health check.
