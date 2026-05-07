# Salesforce Audit Plugin — Complete Guide

The `salesforce-audit` plugin is a collection of 14 skills, 3 agents, and a unified `/org-scan` command that gives ops, security, and release teams a complete picture of a Salesforce org's health, security, and technical debt — all from the Claude Code CLI.

---

## How It Works

Every skill runs SOQL queries, Tooling API queries, REST API calls, or local source analysis against a target org using the Salesforce CLI (`sf`). Results are colour-coded by severity and rolled into a single prioritised report.

```
┌─────────────────────────────────────────────────────────────────────┐
│  /org-scan --target-org prod-org --days 14                          │
│                                                                     │
│  org-scanner agent                                                  │
│   ├── governor-limits          ├── user-security-audit              │
│   ├── event-log-query          ├── apex-test-coverage               │
│   ├── login-history-query      ├── org-security-posture             │
│   ├── setup-audit-trail        ├── api-version-audit                │
│   ├── metadata-audit           ├── workflow-migration               │
│   ├── connected-apps-audit     ├── pmd-scan                         │
│   └── user-access-audit        └── org-health-check                 │
│                                                                     │
│  OUTPUT: prioritised report with 🔴 Critical / 🟡 Warning / 🟢 Clean│
└─────────────────────────────────────────────────────────────────────┘
```

Run the full scan:

```bash
/org-scan --target-org prod-org --days 7
/org-scan --target-org prod-org --days 30 --run-tests --output reports/audit.md
```

Run an individual skill at any time:

```bash
/governor-limits --target-org prod-org
/workflow-migration --target-org prod-org --object Account
/pmd-scan
```

---

## Severity Scale

| Indicator | Meaning | Expected Response |
|-----------|---------|-------------------|
| 🔴 Critical | Active security risk or governor breach — fix now | Same business day |
| 🟡 Warning | Technical debt or elevated risk — plan remediation | Within the sprint |
| ℹ️ Info | Improvement opportunity — no immediate risk | Backlog |
| ✅ Clean | Domain checked, no findings | No action needed |

---

## Skill Reference

---

### 1. Governor Limits

**Skill:** `governor-limits`

**The problem it solves**

Salesforce enforces hard caps on storage, API calls, async jobs, and platform events. When an org approaches these limits, integrations start failing silently, batch jobs abort, and users see generic errors. Most teams don't know they're close until something breaks in production.

**What it scans**

Calls the REST Limits API at `/services/data/v66.0/limits` — a single endpoint that returns every org-level limit and its current remaining capacity. No SOQL required, no impact on query limits.

```bash
sf api request rest "/services/data/v66.0/limits" --target-org prod-org
```

**Thresholds**

- 🔴 Critical: ≥ 80% consumed
- 🟡 Warning: 40–79% consumed
- 🟢 Healthy: < 40% consumed

**Priority limits checked**

| Limit | What breaks when it's exhausted |
|-------|-------------------------------|
| `DataStorageMB` | Record creates fail; bulk loads error out |
| `FileStorageMB` | File/attachment uploads fail |
| `DailyApiRequests` | All REST/SOAP API calls fail for the rest of the day |
| `DailyAsyncApexExecutions` | Queueables and future methods stop running |
| `DailyBulkApiBatches` | Bulk API data loads fail |
| `HourlyPublishedPlatformEvents` | Platform Events are dropped; subscribers miss data |

**How to resolve**

- `DataStorageMB`: Archive old records, purge `ApexLog` and `Task` bloat, enable Big Objects for history
- `FileStorageMB`: Delete stale `ContentVersion` files (scan top-10 largest via the Storage domain)
- `DailyApiRequests`: Add request caching in integrations, use Bulk API for large data volumes, negotiate higher limits with Salesforce

---

### 2. Event Log Files

**Skill:** `event-log-query`

**The problem it solves**

Standard SOQL objects like `LoginHistory` only capture authentication events. To detect data exfiltration (mass report exports), API abuse, or suspicious permission changes, you need Event Monitoring — the full audit log of every user action. Most security incidents leave a trail here that isn't visible anywhere else.

**What it scans**

Queries `EventLogFile` via SOQL to list available log files, then downloads and parses them via the REST API. Each event type is a separate CSV file with dozens of contextual fields.

```bash
# Discover available logs
sf data query --query "SELECT EventType, LogDate, LogFileLength FROM EventLogFile
  WHERE EventType IN ('ReportExport','DataExport','PermissionSetAssignment',
  'Login','UserCreation','ApexUnexpectedException')
  AND CreatedDate = LAST_N_DAYS:7" --target-org prod-org

# Download a log file
sf api request rest "/services/data/v66.0/sobjects/EventLogFile/<ID>/LogFile" \
  --target-org prod-org > reports/event_ReportExport.csv
```

**Event types prioritised**

| Event Type | Security Signal |
|------------|----------------|
| `ReportExport` | User exported a report — flag rows > 10,000 |
| `DataExport` | Full data export triggered |
| `PermissionSetAssignment` | Permission escalation event |
| `Login` | Failed logins, unusual IPs, new countries |
| `UserCreation` | New user added (insider threat onboarding watch) |
| `ApexUnexpectedException` | Apex runtime errors — correlates with code defects |
| `ConnectedApp` | OAuth token grants and revocations |

**Requires:** Event Monitoring add-on (Performance/Unlimited edition). If not enabled, the skill reports unavailability and provides the upgrade path.

**How to resolve**

- Large `ReportExport` entries: review the report, notify the data owner, consider enabling Report Subscription restrictions
- `DataExport` by non-admin: investigate immediately; check if triggered intentionally
- Off-hours `Login` failures: cross-reference with `LoginHistory` and consider IP allow-listing

---

### 3. Login History & Authentication Anomalies

**Skill:** `login-history-query`

**The problem it solves**

Failed logins, credential sharing, off-hours access, and logins from new countries are early indicators of account compromise or insider threats. `LoginHistory` retains 6 months of data and requires no add-on — it's available in every Salesforce edition.

**What it scans**

Four categories of queries against `LoginHistory`, `AuthSession`, and `VerificationHistory`:

```bash
# Failed login attempts — brute force detection
sf data query --query "SELECT UserId, LoginType, Status, SourceIp, LoginTime,
  CountryIso FROM LoginHistory WHERE Status != 'Success'
  AND LoginTime = LAST_N_DAYS:7 ORDER BY LoginTime DESC LIMIT 200"

# Credential sharing signal — >5 logins in one day per user
sf data query --query "SELECT Username, COUNT(Id) Sessions FROM LoginHistory
  WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:1
  GROUP BY Username HAVING COUNT(Id) > 5 ORDER BY Sessions DESC"

# MFA bypass attempts
sf data query --query "SELECT UserId, Activity, Status, SourceIp FROM
  VerificationHistory WHERE Status != 'Success'
  AND EventDate = LAST_N_DAYS:7 ORDER BY EventDate DESC"

# Active sessions right now
sf data query --query "SELECT UsersId, SessionType, LoginType, SourceIp,
  LastModifiedDate FROM AuthSession ORDER BY LastModifiedDate DESC LIMIT 100"
```

**Flags raised**

| Pattern | Severity | What it means |
|---------|----------|--------------|
| >5 failed logins from same IP | 🔴 | Brute force in progress |
| Login from new country | 🟡 | Possible account takeover |
| >5 sessions same user same day | 🟡 | Credential sharing |
| MFA verification failure | 🟡 | MFA bypass attempt |
| Weekend/off-hours login by admin | 🟡 | Insider threat signal |
| `Username-Password Flow Disabled` on SSO org | ℹ️ | Expected — SSO working correctly |

**How to resolve**

- Block the source IP via trusted IP ranges (Setup → Network Access)
- Lock the affected user account and require password reset
- Enable MFA enforcement at the profile level for all Standard users
- Set idle session timeout to 2 hours or less (Setup → Session Settings)

---

### 4. Connected Apps & OAuth Grants

**Skill:** `connected-apps-audit`

**The problem it solves**

Every Connected App is an OAuth entry point into your org. Tokens granted to deactivated users remain valid for API access even after the user is deactivated. Apps with `full` scope and no IP restriction give an attacker complete access to all org data. Most orgs accumulate zombie tokens over years.

**What it scans**

```bash
# Full OAuth grant inventory
sf data query --query "SELECT ConnectedApplication.Name, User.Username,
  User.IsActive, Scopes, LastUsedDate, CreatedDate FROM OAuth2
  ORDER BY LastUsedDate DESC NULLS LAST LIMIT 100"

# Critical: grants to inactive users — still valid for API calls
sf data query --query "SELECT ConnectedApplication.Name, User.Username,
  Scopes, LastUsedDate FROM OAuth2
  WHERE User.IsActive = FALSE ORDER BY LastUsedDate DESC"

# Stale grants (90+ days unused)
sf data query --query "SELECT ConnectedApplication.Name, User.Username,
  Scopes, LastUsedDate FROM OAuth2
  WHERE LastUsedDate < LAST_N_DAYS:90 ORDER BY LastUsedDate ASC LIMIT 50"
```

It also retrieves Connected App metadata files to check for missing IP restrictions and inspects `SetupAuditTrail` for recent Connected App changes.

**Flags raised**

| Finding | Severity | Why It Matters |
|---------|----------|---------------|
| OAuth grant to deactivated user | 🔴 Critical | Active API access despite offboarding |
| `full` scope on non-service account | 🔴 Critical | Complete data access via single token |
| App with no IP restriction + `api` scope | 🟡 High | No network-level control on token use |
| Token unused for 90+ days | 🟡 Medium | Unnecessary attack surface |
| No `ContactEmail` on app | 🟡 Medium | Orphaned app — no owner to notify |
| Public client (no secret) on internal app | 🟡 Medium | Anyone can impersonate the app |

**How to resolve**

- Revoke tokens for inactive users: Setup → Connected Apps OAuth Usage → Revoke
- Restrict scopes to the minimum required (`refresh_token`, specific resource scopes instead of `full`)
- Add trusted IP ranges to Connected App definitions
- Set refresh token expiry policies on high-risk apps

---

### 5. User Security

**Skill:** `user-security-audit`

**The problem it solves**

`IsActive = FALSE` on a User record does not revoke API sessions. Frozen accounts (`UserLogin.IsFrozen = TRUE`) still accept API calls. Password-locked service accounts may indicate an active brute-force attack. Standard permission queries miss the full `ModifyAllData` surface because it can be granted via profile, permission set, or permission set group.

**What it scans**

```bash
# Frozen accounts — active for API despite being "frozen"
sf data query --query "SELECT UserId, User.Username, User.Profile.Name,
  IsFrozen, IsPasswordLocked FROM UserLogin WHERE IsFrozen = TRUE"

# Password-locked accounts — brute force signal
sf data query --query "SELECT UserId, User.Username, IsPasswordLocked
  FROM UserLogin WHERE IsPasswordLocked = TRUE"

# ModifyAllData via profile
sf data query --query "SELECT Name FROM Profile
  WHERE PermissionsModifyAllData = TRUE ORDER BY Name"

# ModifyAllData via permission set — catches what profile query misses
sf data query --query "SELECT Assignee.Username, PermissionSet.Name
  FROM PermissionSetAssignment
  WHERE PermissionSet.PermissionsModifyAllData = TRUE"

# API-enabled non-integration users — insider threat vector
sf data query --query "SELECT Name, Username, Profile.Name FROM User
  WHERE IsActive = TRUE AND Profile.PermissionsApiEnabled = TRUE
  AND Profile.Name NOT IN ('System Administrator','Integration User')
  AND UserType = 'Standard' ORDER BY Profile.Name LIMIT 50"
```

**Key insight: Frozen ≠ Deactivated**

A frozen user cannot log in via the UI but their existing API sessions and OAuth tokens remain active. An attacker with a stolen session token for a frozen account can still read and write data. The fix is full deactivation, not freezing.

**How to resolve**

- Deactivate frozen accounts that should be fully offboarded
- Rotate credentials on password-locked service accounts; check the source IP for brute force
- Remove `ModifyAllData` from permission sets assigned to non-admins
- Remove API access from profiles where it isn't needed; add IP restrictions on profiles that do need it

---

### 6. Deactivated Users & Orphaned Access

**Skill:** `user-security-audit` (combined with Domain 6 in org-scan)

**The problem it solves**

When a user is offboarded, their OAuth tokens, permission set assignments, and group memberships often persist. These orphaned access paths let a former employee (or attacker with their credentials) retain access through indirect channels long after the account is nominally deactivated.

**What it scans**

```bash
# Recently deactivated users
sf data query --query "SELECT Name, Username, LastLoginDate, Profile.Name
  FROM User WHERE IsActive = FALSE
  AND LastModifiedDate = LAST_N_DAYS:30 ORDER BY LastModifiedDate DESC"

# Their surviving OAuth grants
sf data query --query "SELECT ConnectedApplication.Name, User.Username,
  Scopes, LastUsedDate FROM OAuth2
  WHERE User.IsActive = FALSE ORDER BY LastUsedDate DESC"

# Stale permission set assignments for inactive users
sf data query --query "SELECT Assignee.Username, PermissionSet.Name
  FROM PermissionSetAssignment
  WHERE Assignee.IsActive = FALSE LIMIT 20"
```

**How to resolve**

- For each deactivated user: revoke OAuth tokens, remove permission set assignments, remove from public groups
- Automate offboarding via a Flow or Process that triggers on `User.IsActive` changing to `false`
- Review orphaned grants monthly using this skill as a recurring check

---

### 7. Apex Test Coverage & Quality

**Skill:** `apex-test-coverage`

**The problem it solves**

Salesforce requires 75% test coverage to deploy, but coverage alone is not quality. Tests with no assertions, `SeeAllData=true`, or hard-coded IDs pass the coverage threshold while providing zero protection against regressions. This skill catches both the quantity problem (below threshold) and the quality problem (bad test patterns).

**What it scans**

**Coverage (Tooling API):**

```bash
# Org-wide coverage percentage
sf data query --query "SELECT PercentCovered FROM ApexOrgWideCoverage"
  --use-tooling-api

# Per-class breakdown — worst first
sf data query --query "SELECT ApexClassOrTrigger.Name, NumLinesCovered,
  NumLinesUncovered FROM ApexCodeCoverageAggregate
  WHERE NumLinesCovered + NumLinesUncovered > 0
  ORDER BY NumLinesCovered ASC LIMIT 30" --use-tooling-api
```

**Static quality checks (local source):**

```bash
# Tests with no assertions — meaningless coverage
grep -rl "testMethod\|@isTest" force-app --include="*.cls" | \
  xargs grep -L "System\.assert\|Assert\."

# Tests using SeeAllData=true — data-dependent, brittle
grep -rn "SeeAllData\s*=\s*true" force-app --include="*.cls"

# Hard-coded record IDs (break across orgs)
grep -rn "'001\|'003\|'005" force-app --include="*.cls" | grep -i "test"

# Unbalanced Test.startTest / Test.stopTest
for f in $(grep -rl "Test\.startTest" force-app --include="*.cls"); do
  starts=$(grep -c "Test\.startTest" "$f"); stops=$(grep -c "Test\.stopTest" "$f")
  [[ "$starts" != "$stops" ]] && echo "UNBALANCED: $f"
done
```

**Severity**

| Finding | Severity |
|---------|----------|
| Org-wide coverage < 75% | 🔴 Critical — blocks deployments |
| Any class at 0% coverage | 🔴 Critical |
| `SeeAllData=true` in test class | 🟡 Warning — tests break in scratch orgs |
| No assertions in test class | 🟡 Warning — coverage is false |
| Hard-coded IDs | 🟡 Warning — breaks in any other org |
| Unbalanced `startTest/stopTest` | 🟡 Warning — limits not reset correctly |

**How to resolve**

- Write `@testSetup` methods with `TestDataFactory` to create test data without `SeeAllData`
- Replace hard-coded IDs with SOQL lookups by `Name` or `DeveloperName`
- Add `System.assertEquals` / `System.assertNotEquals` assertions to every test method
- Wrap async code (callouts, future, queueable) between `Test.startTest()` and `Test.stopTest()`

---

### 8. Org Security Posture

**Skill:** `org-security-posture`

**The problem it solves**

Security configuration in Salesforce is spread across a dozen screens — CORS, CSP, Named Credentials, Remote Site Settings, certificates, guest user profiles. No single admin page shows the full picture. Complex orgs accumulate insecure entries over years — `http://` endpoints, wildcard CORS, expired certificates — that create real attack surface.

**What it scans**

```bash
# CORS — wildcards let any website call your org APIs
sf data query --query "SELECT UrlPattern FROM CorsWhitelistEntry ORDER BY UrlPattern"

# CSP Trusted Sites — unsafe-inline enables XSS
sf data query --query "SELECT EndpointUrl, Context FROM ContentSecurityPolicy ORDER BY EndpointUrl"

# Certificates expiring soon
sf data query --query "SELECT DeveloperName, ExpirationDate FROM Certificate
  WHERE ExpirationDate < NEXT_N_DAYS:90 ORDER BY ExpirationDate ASC"

# Guest user object access — Experience Cloud surface
sf data query --query "SELECT SobjectType, PermissionsRead, PermissionsCreate
  FROM ObjectPermissions WHERE Parent.Profile.UserType = 'Guest'
  AND PermissionsRead = TRUE ORDER BY SobjectType"

# Data Classification — unclassified PII fields on key objects
sf data query --query "SELECT QualifiedApiName, EntityDefinition.QualifiedApiName
  FROM FieldDefinition WHERE SecurityClassification = NULL
  AND EntityDefinition.QualifiedApiName IN ('Contact','Lead','Case','Account')
  LIMIT 30" --use-tooling-api
```

It also retrieves Named Credential and Remote Site Setting metadata to check for `Anonymous` auth, `http://` endpoints, and inactive entries.

**Flags raised**

| Finding | Severity | Risk |
|---------|----------|------|
| Guest user can read Contact / Account / Case | 🔴 Critical | Public data exposure |
| Certificate expiring < 30 days | 🔴 Critical | Integration outage |
| CORS wildcard `*` | 🟡 High | Any website can call your org |
| CSP `unsafe-inline` or `unsafe-eval` | 🟡 High | XSS enablement |
| Named Credential with `Anonymous` auth | 🟡 High | Unauthenticated external callout |
| `http://` Remote Site or Named Credential | 🟡 Medium | Plaintext credential exposure |
| Unclassified PII fields | 🟡 Medium | GDPR/CCPA compliance gap |
| Certificate expiring 30–90 days | 🟡 Medium | Plan renewal now |
| Inactive Remote Site entries | ℹ️ Info | Cleanup opportunity |

**How to resolve**

- Remove or restrict CORS entries to specific `https://` origins
- Renew certificates before expiry; set calendar reminders 90 days ahead
- Remove guest user object access — use public Community pages that enforce FLS instead
- Tag unclassified fields with `SecurityClassification` (Restricted / Confidential) and `ComplianceGroup` (PII / PCI / HIPAA)

---

### 9. Setup Audit Trail

**Skill:** `setup-audit-trail`

**The problem it solves**

In a production org, every admin configuration change should be traceable to an authorized person and a change ticket. `SetupAuditTrail` retains 180 days of every Setup screen change. Without querying it regularly, unauthorized privilege escalation, code deployments by non-CI users, and security control weakening go unnoticed until an incident occurs.

**What it scans**

```bash
# All recent changes — full picture
sf data query --query "SELECT CreatedDate, CreatedBy.Username, Action,
  Section, Display, DelegateUser FROM SetupAuditTrail
  WHERE CreatedDate = LAST_N_DAYS:7 ORDER BY CreatedDate DESC LIMIT 200"

# Code changes in production — should come only from CI pipeline
sf data query --query "SELECT CreatedDate, CreatedBy.Username, Action, Display
  FROM SetupAuditTrail WHERE Section IN ('Apex Class', 'Apex Trigger',
  'Lightning Component', 'Visualforce Page')
  AND CreatedDate = LAST_N_DAYS:90 ORDER BY CreatedDate DESC"

# Security control changes — session settings, password policy, MFA
sf data query --query "SELECT CreatedDate, CreatedBy.Username, Action, Display
  FROM SetupAuditTrail WHERE Section IN ('Security', 'Session Settings',
  'Password Policies', 'Named Credentials', 'Auth. Provider')
  AND CreatedDate = LAST_N_DAYS:90 ORDER BY CreatedDate DESC"
```

**Immediate escalation flags**

| Pattern | Severity | Action |
|---------|----------|--------|
| Apex/Flow/LWC deployed by non-CI user | 🔴 Critical | Verify authorization, review the change |
| `ModifyAllData` granted via profile/permset | 🔴 Critical | Revoke and audit data access since grant |
| Session timeout extended or MFA disabled | 🔴 Critical | Revert; investigate who authorized it |
| Named Credential endpoint changed | 🔴 Critical | Verify target URL isn't attacker-controlled |
| New admin user created | 🟡 High | Confirm authorization with HR/manager |
| Trust IP range modified | 🟡 High | Verify change aligns with network changes |
| Data Export triggered | 🟡 High | Confirm it was authorized and where data went |
| Delegated admin bulk changes | 🟡 Medium | Review scope of delegated authority |

**How to resolve**

- Configure an automated alert: schedule `/setup-audit-trail` daily via the `/schedule` skill and pipe Critical flags to a Slack channel
- Lock production code deployment to CI service users only — remove `AuthorApex` from all human profiles in production
- Require change management tickets for all permission escalations; verify via this audit trail

---

### 10. Metadata Audit (Profiles, Permission Sets, OWD)

**Skill:** `metadata-audit`

**The problem it solves**

Over-permissioned profiles and permission sets are the most common access control failure in Salesforce. `ViewAllData` on a standard user profile lets them export every record in the org. `Public Read/Write` OWD on a custom object means every user can overwrite every record. These misconfigurations are invisible in day-to-day admin work but immediately obvious in a breach post-mortem.

**What it scans**

```bash
# Profiles with system-wide permissions
sf data query --query "SELECT Name, PermissionsModifyAllData, PermissionsViewAllData,
  PermissionsAuthorApex, PermissionsManageUsers FROM Profile
  WHERE PermissionsModifyAllData = TRUE OR PermissionsViewAllData = TRUE"

# OWD — Public Read/Write on any object is a finding
sf data query --query "SELECT QualifiedApiName, InternalSharingModel, ExternalSharingModel
  FROM EntityDefinition WHERE IsCustomizable = TRUE
  AND (InternalSharingModel = 'ReadWrite' OR ExternalSharingModel = 'ReadWrite')"
  --use-tooling-api

# Guest user access (Experience Cloud)
sf data query --query "SELECT SobjectType, PermissionsRead, PermissionsEdit
  FROM ObjectPermissions WHERE Parent.Profile.UserType = 'Guest'
  AND PermissionsRead = TRUE ORDER BY SobjectType"

# Field-level security on PII/sensitive fields
sf data query --query "SELECT EntityDefinition.QualifiedApiName, QualifiedApiName,
  ComplianceGroup, SecurityClassification FROM FieldDefinition
  WHERE SecurityClassification IN ('Restricted','Confidential','MissionCritical')"
  --use-tooling-api
```

**How to resolve**

- Move permissions from profiles to permission sets — profiles become a baseline, permission sets add specific access
- Change OWD for sensitive objects from `Public Read/Write` to `Private` and use sharing rules for legitimate access
- Remove `ViewAllData` and `ModifyAllData` from all non-administrator profiles; use object permissions instead
- Audit field permissions on sensitive fields quarterly using this skill

---

### 11. User Access Review

**Skill:** `user-access-audit`

**The problem it solves**

Users accumulate permissions over time that were granted for specific projects or roles that have since changed. A yearly user access review (UAR) is a compliance requirement under SOC 2, ISO 27001, and HIPAA. This skill automates the data collection that makes a UAR possible.

**What it scans**

```bash
# Stale standard users (active but never logged in, or 90+ days idle)
sf data query --query "SELECT Name, Username, LastLoginDate, Profile.Name
  FROM User WHERE IsActive = TRUE AND UserType = 'Standard'
  AND (LastLoginDate = NULL OR LastLoginDate < LAST_N_DAYS:90)
  ORDER BY LastLoginDate ASC NULLS FIRST LIMIT 50"

# Service accounts (integration users) and their last activity
sf data query --query "SELECT Name, Username, LastLoginDate, Profile.Name
  FROM User WHERE IsActive = TRUE
  AND Profile.Name LIKE '%Integration%'
  ORDER BY LastLoginDate ASC NULLS FIRST"

# Role hierarchy — identify users with broad visibility
sf data query --query "SELECT Name, ParentRole.Name, MayForecastManagerShare
  FROM UserRole ORDER BY ParentRole.Name NULLS FIRST, Name"
```

**How to resolve**

- Deactivate users who haven't logged in for 90+ days after confirming with their manager
- Review integration user permissions annually — remove object access that integrations no longer use
- Flatten over-complex role hierarchies that grant unintended visibility

---

### 12. Flow Errors & Legacy Automation

**Skill:** `org-security-posture` + `workflow-migration`

**The problem it solves**

Two distinct but related problems:

1. **Flow interview errors** silently fail in production, causing data not to be updated, emails not to be sent, and records to enter invalid states. Most Flow errors appear in `FlowInterviewLog` — not in any user-visible error message.

2. **Legacy automation stacking** — having Workflow Rules, Process Builder, and record-triggered Flows all active on the same object creates unpredictable execution order and recursion risk. Salesforce has end-of-life'd Workflow Rules and Process Builder; they should be migrated to Flow.

**What it scans**

```bash
# Flow interview errors in the last N days
sf data query --query "SELECT InterviewLabel, CurrentElement, ErrorMessage, CreatedDate
  FROM FlowInterviewLog WHERE InterviewStatus = 'Error'
  AND CreatedDate = LAST_N_DAYS:7 ORDER BY CreatedDate DESC"

# Active Process Builder flows (end-of-life)
sf data query --query "SELECT DeveloperName, ProcessType, ActiveVersionId
  FROM FlowDefinition WHERE IsActive = TRUE
  AND ProcessType IN ('Workflow','InvocableProcess','CustomEvent')"

# Active Workflow Rules by object
sf data query --query "SELECT TableEnumOrId, COUNT(Id) Count FROM WorkflowRule
  WHERE IsActive = TRUE GROUP BY TableEnumOrId ORDER BY Count DESC"

# Automation stacking — objects with multiple active flows
sf data query --query "SELECT TriggerObjectOrEvent.QualifiedApiName, COUNT(Id) FlowCount
  FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType = 'AutoLaunchedFlow'
  GROUP BY TriggerObjectOrEvent.QualifiedApiName HAVING COUNT(Id) > 1
  ORDER BY FlowCount DESC"
```

**How to resolve**

- For each Flow interview error: open Flow Builder → Debug → trace to the failing element → add fault paths with error logging
- Use the `workflow-migration` skill to generate a complexity-scored migration plan for all Workflow Rules and Process Builder automations
- Prioritise deactivating legacy automation on objects that also have record-triggered Flows to eliminate stacking

---

### 13. Workflow Migration

**Skill:** `workflow-migration`

**The problem it solves**

Salesforce announced retirement of Workflow Rules and Process Builder. Orgs that haven't migrated face eventual breakage. But migration isn't trivial — time-based actions, outbound messages, and cross-object field updates have different complexity levels, and migrating in the wrong order can cause double-fire bugs.

**What it scans**

Inventories every active Workflow Rule and Process Builder flow and breaks down their action types:

```bash
# Workflow field updates (easy — map to Flow Update Records)
sf data query --query "SELECT WorkflowRule.Name, Field, NewValue
  FROM WorkflowFieldUpdate ORDER BY WorkflowRule.TableEnumOrId"

# Time-based actions (complex — requires scheduled paths in Flow)
sf data query --query "SELECT WorkflowRule.Name, TimeLength, WorkflowTimeTriggerUnit
  FROM WorkflowTimeTrigger ORDER BY WorkflowRule.TableEnumOrId"

# Outbound messages (complex — replace with Platform Events or callout Flow)
sf data query --query "SELECT WorkflowRule.Name, EndpointUrl, Fields
  FROM WorkflowOutboundMessage ORDER BY WorkflowRule.TableEnumOrId"
```

**Complexity scoring**

Each rule is scored so migration effort can be estimated:

| Factor | Complexity Added |
|--------|----------------|
| Time-based actions | +3 (needs scheduled paths) |
| Outbound messages | +3 (needs Platform Event or HTTP callout) |
| Apex invocation | +2 |
| Cross-object field updates | +2 |
| Simple single-field update | +0 (direct Flow equivalent) |

Score 0–2 = 🟢 Easy (< 1 hour), 3–5 = 🟡 Moderate (2–4 hours), 6+ = 🔴 Complex (1+ days).

**How to resolve**

1. Delete inactive rules and inactive Process Builder versions — no migration needed
2. Migrate easy rules first to reduce inventory quickly
3. For complex rules (outbound messages): design a Platform Event-based replacement before deactivating the Workflow Rule
4. After migrating each rule: deactivate (don't delete), run full test suite, monitor for one release cycle, then delete

---

### 14. API Version Audit

**Skill:** `api-version-audit`

**The problem it solves**

Salesforce releases three API versions per year. Apex classes, LWC components, Flows, and Visualforce pages each carry an `apiVersion` that controls which platform behaviors and governor limits apply to them. Components pinned to very old versions miss security improvements, governor limit increases, and deprecated APIs that now behave differently — and some old behaviors are eventually removed entirely.

**What it scans**

Queries Apex classes, triggers, Flows, and VF pages via the Tooling API for their `ApiVersion` field, and greps local source for `<apiVersion>` in LWC/Aura meta.xml files:

```bash
# Apex classes — Tooling API
sf data query --query "SELECT Name, ApiVersion, LastModifiedDate
  FROM ApexClass WHERE NamespacePrefix = '' ORDER BY ApiVersion ASC LIMIT 200"
  --use-tooling-api

# LWC components — local source
grep -rn "apiVersion" force-app --include="*.js-meta.xml" | \
  awk -F'[<>]' '{print $3, FILENAME}' | sort -n

# Flag all components below minimum version
MIN_VER=57
grep -rn "apiVersion" force-app --include="*.js-meta.xml" | \
  awk -F'[<>]' -v min="$MIN_VER" '$3 < min {print "OLD: " $3 " — " FILENAME}'
```

**Risk matrix**

| API Version Range | Era | Risk |
|-------------------|-----|------|
| ≤ 29.0 | Pre-Spring '14 | 🔴 Critical — likely using retired behaviors |
| 30–44 | Spring '14 – Summer '18 | 🔴 Critical — many deprecated APIs retired |
| 45–52 | Spring '19 – Summer '21 | 🟡 High — missing security model improvements |
| 53–56 | Winter '22 – Summer '22 | 🟡 Medium — missing governor limit increases |
| 57–60 | Winter '23 – Summer '23 | 🟡 Low — 1–2 versions behind |
| 61+ | Winter '24+ | 🟢 Current |

**How to resolve**

- For LWC/Aura: bulk-update meta.xml files via `sed` to the current version, then run `sf apex run test --test-level RunLocalTests` to verify no behavioral regressions
- For Apex classes: update `apiVersion` in the Tooling API or redeploy via source — API version changes to Apex are low-risk
- For Flows: open in Flow Builder and save — Salesforce upgrades the API version on save

---

### 15. PMD Static Analysis

**Skill:** `pmd-scan`

**The problem it solves**

Code review catches many issues, but consistent static analysis catches whole categories of bugs that reviewers miss under time pressure — SOQL injection, missing CRUD/FLS checks, empty catch blocks, deeply nested logic, and copy-paste duplication. PMD rules enforce these checks on every file, every time.

**What it scans**

Runs via the Salesforce Code Analyzer, which wraps PMD, ESLint, RetireJS, and a graph-based data-flow engine:

```bash
# Full PMD scan on all Apex
sf scanner run \
  --target "force-app/**/*.cls,force-app/**/*.trigger" \
  --engine pmd \
  --pmdconfig .pmdruleset.xml \
  --format sarif \
  --outfile reports/pmd.sarif

# DFA scan — catches CRUD/FLS violations across method boundaries
sf scanner run dfa \
  --target force-app \
  --projectdir . \
  --format sarif \
  --outfile reports/pmd-dfa.sarif
```

**Rules that always fail CI regardless of severity tag**

| Rule | What it catches |
|------|----------------|
| `ApexCRUDViolation` | SOQL/DML without CRUD check — data exposure |
| `ApexSOQLInjection` | Dynamic SOQL built from user input — injection risk |
| `ApexSharingViolations` | Class missing `with sharing` — sharing bypass |

**How to resolve**

- `ApexSOQLInjection`: replace string concatenation in SOQL with bind variables (`WHERE Name = :inputVar`) or `String.escapeSingleQuotes()`
- `ApexCRUDViolation`: use `WITH USER_MODE` on queries, or `Security.stripInaccessible()` before DML
- `ApexSharingViolations`: add `with sharing` keyword to all service and controller classes; use `without sharing` only in explicitly documented inner classes
- Tune `.pmdruleset.xml` with the `pmd-analyst` agent to suppress false positives with justification comments (`@SuppressWarnings`)

---

## Running the Full Scan

```bash
# Quick scan — last 7 days, no test run
/org-scan --target-org prod-org

# Deep scan — last 30 days, run Apex tests, save report
/org-scan --target-org prod-org --days 30 --run-tests --output reports/audit-$(date +%Y%m%d).md

# CI pre-deploy gate (exits 1 if any Critical finding)
/org-scan --target-org uat-org && sf project deploy start --target-org prod-org
```

## Scan Output Structure

```
╔══════════════════════════════════════════════════════════════════════╗
║  ORG SCAN REPORT  —  prod-org  —  2026-05-07                        ║
║  Overall: 🔴 CRITICAL  |  14 domains checked  |  Lookback: 7 days   ║
╚══════════════════════════════════════════════════════════════════════╝

## 🔴 Immediate Action Required
| # | Domain | Finding | Action |

## 🟡 Warnings
| # | Domain | Finding | Recommendation |

## ✅ Clean Domains

## Domain Detail
### 1. Governor Limits       ### 8.  Storage
### 2. Apex Exceptions       ### 9.  Login Anomalies
### 3. Test Coverage         ### 10. Event Logs
### 4. Connected Apps        ### 11. Setup Audit Trail
### 5. User Security         ### 12. Security Posture
### 6. Deactivated Users     ### 13. Scheduled Jobs
### 7. Flow + Automation     ### 14. Org Health Indicators

## Recommendations (prioritised)
```

## Skill Quick-Reference

| Skill | Invoke | Key Query Object | Edition Required |
|-------|--------|-----------------|-----------------|
| `governor-limits` | `/governor-limits` | REST `/limits` | All |
| `event-log-query` | `/event-log-query` | `EventLogFile` | Performance/Unlimited |
| `login-history-query` | `/login-history-query` | `LoginHistory`, `VerificationHistory` | All |
| `connected-apps-audit` | `/connected-apps-audit` | `OAuth2`, `ConnectedApplication` | All |
| `user-security-audit` | `/user-security-audit` | `UserLogin`, `User` | All |
| `apex-test-coverage` | `/apex-test-coverage` | `ApexOrgWideCoverage`, `ApexCodeCoverageAggregate` | All |
| `org-security-posture` | `/org-security-posture` | `CorsWhitelistEntry`, `Certificate`, `ObjectPermissions` | All |
| `setup-audit-trail` | `/setup-audit-trail` | `SetupAuditTrail` | All (180-day retention) |
| `metadata-audit` | `/metadata-audit` | `Profile`, `PermissionSet`, `FieldDefinition` | All |
| `user-access-audit` | `/user-access-audit` | `User`, `PermissionSetAssignment` | All |
| `api-version-audit` | `/api-version-audit` | `ApexClass`, `Flow` (Tooling API) + local meta.xml | All |
| `workflow-migration` | `/workflow-migration` | `WorkflowRule`, `FlowDefinition` | All |
| `pmd-scan` | `/pmd-scan` | Local Apex source | All (CLI tool) |
| `org-health-check` | `/org-health-check` | Multiple | All |
