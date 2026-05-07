---
description: Analyze Salesforce login history for authentication anomalies — failed attempts, unusual IPs, off-hours access, and credential-sharing signals.
argument-hint: [--target-org <alias>] [--days <n>] [--user <username>]
---

Perform a login history audit for the target org.

## Steps

1. Parse arguments:
   - `--target-org`: defaults to `prod-org`
   - `--days`: defaults to `30`
   - `--user`: optional — if provided, scope analysis to that user

2. Run the **login-history-query** skill queries in sequence:
   - Failed login attempts grouped by username and IP
   - Weekend/after-hours successful logins
   - Concurrent session signals (>5 logins in 24h per user)
   - API/OAuth logins by non-integration accounts
   - MFA verification failures (VerificationHistory)
   - Geographic distribution of logins (CountryIso)

3. Query active sessions:
   ```bash
   sf data query \
     --query "SELECT UsersId, SessionType, LoginType, SourceIp, LastModifiedDate FROM AuthSession ORDER BY LastModifiedDate DESC LIMIT 50" \
     --target-org <target-org>
   ```

4. If `--user` is provided, produce a per-user timeline:
   ```bash
   sf data query \
     --query "SELECT LoginTime, Status, LoginType, SourceIp, Browser, Platform FROM LoginHistory WHERE Username = '<user>' AND LoginTime = LAST_N_DAYS:<days> ORDER BY LoginTime DESC" \
     --target-org <target-org>
   ```

5. Check SetupAuditTrail for any password resets or account unlocks in the same period:
   ```bash
   sf data query \
     --query "SELECT CreatedDate, CreatedBy.Username, Action, Display FROM SetupAuditTrail WHERE Section = 'Manage Users' AND (Action LIKE '%password%' OR Action LIKE '%unlock%') AND CreatedDate = LAST_N_DAYS:<days> ORDER BY CreatedDate DESC" \
     --target-org <target-org>
   ```

## Output

1. **Authentication health score** — ratio of success to failure
2. **Anomaly table**:

| Severity | Username | IP | Time | Anomaly type | Recommendation |
|----------|----------|----|------|-------------|----------------|

3. **IP reputation summary** — list unique source IPs for manual geo-IP review
4. **Accounts requiring action** — lock, force password reset, or MFA enforcement
5. **Policy gaps** — missing IP restrictions, no MFA on admin accounts, weak session timeout

## Integration

Can be combined with `audit-event-logs` for a complete picture: event logs show *what* was accessed after login; this command shows *how* access was obtained.
