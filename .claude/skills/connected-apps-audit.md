---
name: connected-apps-audit
description: Audit Salesforce Connected Apps — OAuth token grants, scope violations, unused apps, consumer secret exposure, IP restrictions, session policies, and refresh token age. Surfaces over-permissioned and zombie Connected Apps.
argument-hint: [--target-org <alias>] [--days <n>]
---

# connected-apps-audit

Connected Apps are OAuth entry points into your org. Every misconfigured app is a potential lateral-movement vector.

## 1. Installed Connected Apps inventory

```bash
sf data query \
  --query "SELECT Id, Name, ContactEmail, OptionsIsAdminApproved, OptionsIsConsumerSecretOptional, OptionsAllowAdminApprovedUsersOnly, MobileSessionTimeout, PinLength FROM ConnectedApplication ORDER BY Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:**
- `OptionsIsConsumerSecretOptional = true` — allows public clients (no secret) — only acceptable for mobile/SPA
- `OptionsAllowAdminApprovedUsersOnly = false` — any user can authorize
- No `ContactEmail` — orphaned app, no owner

## 2. Active OAuth token grants (who authorized what)

```bash
sf data query \
  --query "SELECT ConnectedApplication.Name, UserId, User.Username, User.IsActive, Scopes, UseCount, LastUsedDate, CreatedDate FROM OAuth2 ORDER BY LastUsedDate DESC NULLS LAST LIMIT 100" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:**
- Grants to **inactive users** (active token, deactivated account — revoke immediately)
- Grants with `full` or `api` scope on non-integration users
- Grants unused for > 90 days (`LastUsedDate < LAST_N_DAYS:90`)
- Grants with `refresh_token` scope (long-lived access)

## 3. Zombie grants (never used / inactive user)

```bash
sf data query \
  --query "SELECT ConnectedApplication.Name, User.Username, User.IsActive, Scopes, LastUsedDate, CreatedDate FROM OAuth2 WHERE User.IsActive = FALSE OR LastUsedDate < LAST_N_DAYS:90 ORDER BY LastUsedDate ASC NULLS FIRST LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 4. Broad-scope grants

```bash
sf data query \
  --query "SELECT ConnectedApplication.Name, User.Username, Scopes, LastUsedDate FROM OAuth2 WHERE Scopes LIKE '%full%' OR Scopes LIKE '%api%' ORDER BY ConnectedApplication.Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 5. Connected Apps with no IP restriction

```bash
# Retrieve Connected App metadata for IP range inspection
sf project retrieve start \
  --metadata "ConnectedApp" \
  --target-org "${TARGET_ORG:-dev}" \
  --output-dir /tmp/connected-apps-audit 2>/dev/null

# Check for missing IP restrictions
grep -rL "ipRanges\|ipRange" /tmp/connected-apps-audit/connectedApps/ 2>/dev/null \
  | grep "\.connectedApp$"
```

## 6. Session-level policies

```bash
# Apps with session timeout shorter than org default are stricter (good)
# Apps with no session policy inherit org default (check if that's acceptable)
sf project retrieve start \
  --metadata "ConnectedApp" \
  --target-org "${TARGET_ORG:-dev}" \
  --output-dir /tmp/connected-apps-audit 2>/dev/null

grep -rn "mobileSessionTimeout\|sessionTimeout\|sessionLevel" \
  /tmp/connected-apps-audit/connectedApps/ 2>/dev/null
```

## 7. SetupAuditTrail — recent Connected App changes

```bash
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Display FROM SetupAuditTrail WHERE Section = 'Connected App' AND CreatedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## Risk matrix

| Finding | Severity | Action |
|---------|----------|--------|
| OAuth grant to deactivated user | 🔴 Critical | Revoke immediately via Setup → OAuth |
| `full` scope on non-service account | 🔴 Critical | Restrict scope to minimum needed |
| App with no IP restriction + `api` scope | 🟡 High | Add trusted IP range |
| Token unused for 90+ days | 🟡 Medium | Revoke; re-authorize when needed |
| No owner email on app | 🟡 Medium | Assign owner |
| Public client (no secret) on internal app | 🟡 Medium | Enforce secret requirement |

## Output

```
=== CONNECTED APPS AUDIT ===
Total apps: N  |  Total OAuth grants: N  |  🔴 Critical: N  |  🟡 Warning: N

🔴 OAuth grants to inactive users:
  <user>  <app>  <scopes>  last used: <date>

🟡 Stale grants (90+ days unused):
  <user>  <app>  last used: <date>

🟡 Broad-scope grants (full/api):
  <user>  <app>  scopes: <list>

✅ Clean: <N> apps with no findings
```
