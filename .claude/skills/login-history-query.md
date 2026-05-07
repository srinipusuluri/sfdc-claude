---
name: login-history-query
description: Query Salesforce LoginHistory and AuthSession to analyze authentication patterns, detect anomalies, and produce access reports. No add-on required — data is retained for 6 months.
argument-hint: [--target-org <alias>] [--days <n>] [--user <username>]
---

# login-history-query

Analyze login patterns, failed attempts, and session data directly from standard Salesforce objects.

## Key objects

| Object | Description | Retention |
|--------|-------------|-----------|
| `LoginHistory` | Every login attempt (success and failure) | 6 months |
| `AuthSession` | Active and recent sessions | Current + recent |
| `VerificationHistory` | MFA/identity verification events | 6 months |

## Common queries

### Failed login attempts (brute force detection)
```bash
sf data query \
  --query "SELECT Username, LoginType, Status, SourceIp, LoginTime, Browser, Platform FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:${DAYS:-7} AND Status != 'Success' ORDER BY LoginTime DESC LIMIT 200" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Failed logins by source IP (top attackers)
```bash
sf data query \
  --query "SELECT SourceIp, COUNT(Id) Attempts FROM LoginHistory WHERE Status != 'Success' AND LoginTime = LAST_N_DAYS:${DAYS:-7} GROUP BY SourceIp ORDER BY Attempts DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Successful logins outside business hours
```bash
# Proxy: filter on weekends or outside 06:00–20:00 UTC
# Note: LoginTime is UTC; adjust for local timezone
sf data query \
  --query "SELECT Username, SourceIp, LoginTime, LoginType FROM LoginHistory WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:${DAYS:-30} AND (DAY_ONLY(LoginTime) = SUNDAY OR DAY_ONLY(LoginTime) = SATURDAY) ORDER BY LoginTime DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Logins for a specific user
```bash
sf data query \
  --query "SELECT LoginTime, Status, LoginType, SourceIp, Browser, Platform FROM LoginHistory WHERE Username = '${USER}' AND LoginTime = LAST_N_DAYS:${DAYS:-30} ORDER BY LoginTime DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### API-only logins (service accounts / integrations)
```bash
sf data query \
  --query "SELECT Username, LoginType, SourceIp, COUNT(Id) Count FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:${DAYS:-30} AND LoginType IN ('OAuth 2.0', 'Partner Product', 'Connected App') GROUP BY Username, LoginType, SourceIp ORDER BY Count DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Users with concurrent sessions (credential sharing signal)
```bash
sf data query \
  --query "SELECT Username, COUNT(Id) Sessions FROM LoginHistory WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:1 GROUP BY Username HAVING COUNT(Id) > 5 ORDER BY Sessions DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Active sessions right now
```bash
sf data query \
  --query "SELECT UsersId, UserType, SessionType, LoginType, SourceIp, LastModifiedDate, LoginHistoryId FROM AuthSession WHERE SessionType != 'SubstituteUser' ORDER BY LastModifiedDate DESC LIMIT 100" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### MFA verification failures
```bash
sf data query \
  --query "SELECT Username, Activity, Status, SourceIp, Timestamp FROM VerificationHistory WHERE Timestamp = LAST_N_DAYS:${DAYS:-7} AND Status != 'Success' ORDER BY Timestamp DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

### Geographic anomaly (logins from new countries)
```bash
# CountryIso field available on LoginHistory
sf data query \
  --query "SELECT Username, CountryIso, SourceIp, COUNT(Id) Logins FROM LoginHistory WHERE Status = 'Success' AND LoginTime = LAST_N_DAYS:${DAYS:-30} GROUP BY Username, CountryIso, SourceIp ORDER BY Username, Logins DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## LoginHistory status codes

| Status | Meaning |
|--------|---------|
| `Success` | Authenticated successfully |
| `Failed: Wrong Password` | Bad credential |
| `Failed: No access to this organization` | Org access restricted |
| `Failed: IP restricted` | IP not in trusted range |
| `Failed: Too many login failures` | Account locked |
| `Failed: MFA required but not satisfied` | MFA bypass attempt |
| `Failed: SSO not configured` | SSO misconfiguration |

## Output

Report:
1. **Summary statistics** — total attempts, success rate, unique IPs, unique users
2. **Anomalies** — failed spikes, off-hours access, new IPs for existing users, MFA failures
3. **Watchlist** — specific users or IPs warranting investigation
4. **Recommendations** — IP whitelist, MFA enforcement, inactive session timeout
