---
description: Run a full Salesforce org audit — event logs, login history, SetupAuditTrail, metadata permissions, user access review, and org health. Produces a comprehensive compliance report.
argument-hint: [--target-org <alias>] [--days <n>] [--output-dir <path>]
---

Perform a comprehensive org audit. This orchestrates all audit skills and the org-auditor agent.

## Steps

1. Parse arguments:
   - `--target-org`: defaults to `prod-org`
   - `--days`: defaults to `30` (audit lookback window)
   - `--output-dir`: defaults to `reports/audit-$(date +%Y%m%d)`

2. Create output directory:
   ```bash
   mkdir -p reports/audit-$(date +%Y%m%d)
   ```

3. Run all audit dimensions **in parallel** via the **org-auditor** agent:

   **A. Org health check** — use `org-health-check` skill:
   - Governor limit consumption
   - Storage usage
   - Test coverage
   - Failed batch jobs and flow errors
   - Inactive users (license waste)

   **B. User access review** — use `user-access-audit` skill:
   - All active users with profile and last login
   - Over-privileged users (ModifyAllData, ViewAllData)
   - Stale accounts (90+ days inactive)
   - Service account inventory

   **C. Metadata permissions** — use `metadata-audit` skill:
   - Profiles with dangerous permissions
   - Permission sets with ModifyAllData/ViewAllData
   - OWD Public Read/Write objects
   - Guest user accessible objects
   - Connected App OAuth grants

   **D. SetupAuditTrail** — use `setup-audit-trail` skill:
   - All Setup changes in `--days` window
   - Code changes in production (should be zero)
   - Security setting changes
   - New user/admin grants

   **E. Login history** — use `login-history-query` skill:
   - Failed login summary
   - Off-hours and weekend access
   - API logins by non-integration users
   - MFA verification failures

   **F. Event log analysis** (if Event Monitoring enabled) — use `event-log-query` skill:
   - ReportExport anomalies
   - DataExport events
   - PermissionSetAssignment events
   - ConnectedApp token grants

4. Retrieve key metadata for offline inspection:
   ```bash
   sf project retrieve start \
     --metadata "Profile" "PermissionSet" "SharingRules" "ConnectedApp" \
     --target-org <target-org> \
     --output-dir reports/audit-$(date +%Y%m%d)/metadata
   ```

5. Run security scanner on force-app:
   ```bash
   sf scanner run \
     --target force-app \
     --engine pmd,eslint,eslint-lwc,retire-js \
     --format sarif \
     --outfile reports/audit-$(date +%Y%m%d)/scanner.sarif
   ```

## Output

Produce a master audit report at `reports/audit-<date>/audit-report.md`:

```markdown
# Org Audit Report
**Org**: <alias> (<org ID>)
**Period**: <date range>
**Auditor**: Claude Code Audit
**Date**: <today>

## Executive Summary
Overall risk: 🔴 Critical / 🟡 High / 🟢 Acceptable

| Domain | Risk | Key Findings |
|--------|------|-------------|
| Org Health | | |
| User Access | | |
| Metadata Permissions | | |
| Admin Changes | | |
| Authentication | | |
| Event Activity | | |
| Code Quality | | |

## Critical Findings (immediate action required)
...

## High Findings
...

## Medium Findings
...

## Recommendations (prioritized)
1. ...

## Appendices
- A: User access detail
- B: Permission set grants
- C: Setup changes log
- D: Login anomalies
- E: Scanner findings (SARIF)
```

## Scheduling

This command can be run monthly as a compliance routine:
```bash
# Add to CI cron (monthly)
sf claude run /audit-org --target-org prod-org --days 30
```
