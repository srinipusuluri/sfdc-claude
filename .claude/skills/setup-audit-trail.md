---
name: setup-audit-trail
description: Query Salesforce SetupAuditTrail to track admin configuration changes — who changed what setup, when, and from where. Retained for 180 days. Essential for incident response and compliance audits.
argument-hint: [--target-org <alias>] [--days <n>] [--section <section>]
---

# setup-audit-trail

SetupAuditTrail records every change made in Setup. Each row captures the action, section, display text, created-by user, and IP/delegate info.

## All recent changes

```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display, DelegateUser FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:${DAYS:-7} ORDER BY CreatedDate DESC LIMIT 200" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## By category

### User & access management
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE Section IN ('Manage Users', 'Permission Set', 'Permission Set Group', 'Profile', 'Role', 'Public Groups', 'Territory') AND CreatedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Code changes in production (should be zero in locked orgs)
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE Section IN ('Apex Class', 'Apex Trigger', 'Lightning Component', 'Visualforce Page', 'Aura Component') AND CreatedDate = LAST_N_DAYS:${DAYS:-90} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Security settings
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE Section IN ('Security', 'Session Settings', 'Password Policies', 'Certificate and Key Management', 'Named Credentials', 'Remote Access', 'Auth. Provider', 'Single Sign-On') AND CreatedDate = LAST_N_DAYS:${DAYS:-90} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Connected apps and OAuth
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE Section IN ('Connected App', 'OAuth', 'API') AND CreatedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Field and object changes (schema drift)
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE Section IN ('Custom Field', 'Custom Object', 'Field Accessibility', 'Validation Rule', 'Sharing', 'Organization-Wide Defaults') AND CreatedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Data management (exports, bulk ops)
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Section, Display FROM SetupAuditTrail WHERE Section IN ('Data Management', 'Data Import', 'Data Loader', 'Data Export', 'Mass Transfer', 'Mass Delete') AND CreatedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Changes by a specific user
```bash
sf data query \
  --query "SELECT CreatedDate, Action, Section, Display, DelegateUser FROM SetupAuditTrail WHERE CreatedBy.Username = '${USER}' AND CreatedDate = LAST_N_DAYS:${DAYS:-90} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Delegated actions (someone acting as another user)
```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, DelegateUser, Action, Section, Display FROM SetupAuditTrail WHERE DelegateUser != NULL AND CreatedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## High-risk indicators

Flag these immediately:

| Pattern | Risk |
|---------|------|
| Code changes in production by non-CI users | Unauthorized code deployment |
| `ModifyAllData` granted via profile/permset | Privilege escalation |
| Session settings weakened (timeout extended, MFA disabled) | Security control bypass |
| New admin user created | Unauthorized access |
| Named Credential endpoint changed | Supply chain / SSRF risk |
| Trust IP ranges modified | IP restriction bypass |
| Data Export triggered | Exfiltration risk |
| Delegated admin performing bulk changes | Insider threat signal |

## Section name reference

Common `Section` values: `Apex Class` · `Apex Trigger` · `API` · `Auth. Provider` · `Certificate and Key Management` · `Connected App` · `Custom Field` · `Custom Object` · `Data Export` · `Data Management` · `Lightning Component` · `Manage Users` · `Named Credentials` · `OAuth` · `Password Policies` · `Permission Set` · `Profile` · `Remote Access` · `Role` · `Security` · `Session Settings` · `Single Sign-On` · `Sharing` · `Territory`

## Output

Provide:
1. **Change volume** — total changes by section and by user for the period
2. **High-risk events** — table of flagged entries with severity
3. **Unexpected actors** — users making changes outside expected job function
4. **Recommendations** — specific remediation steps
