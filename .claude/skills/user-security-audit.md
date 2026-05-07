---
name: user-security-audit
description: Deep Salesforce user security audit — frozen users, recently deactivated accounts, password health, delegated admins, never-expiring passwords, suspicious service accounts, and API-enabled non-integration users. Goes beyond basic UAR to surface active threats.
argument-hint: [--target-org <alias>] [--days <n>]
---

# user-security-audit

User account security is the most common attack surface in Salesforce. This skill surfaces misconfigurations that a basic user list won't show.

## 1. Frozen users (active but locked out)

```bash
sf data query \
  --query "SELECT UserId, User.Username, User.Name, User.Profile.Name, IsFrozen, IsPasswordLocked, CreatedDate FROM UserLogin WHERE IsFrozen = TRUE ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Why it matters:** Frozen accounts are active for API access — an attacker with a valid session token can still make API calls to a frozen account. Frozen ≠ deactivated.

## 2. Recently deactivated users (offboarding verification)

```bash
sf data query \
  --query "SELECT Id, Name, Username, LastLoginDate, Profile.Name, IsActive FROM User WHERE IsActive = FALSE AND LastModifiedDate = LAST_N_DAYS:${DAYS:-30} ORDER BY LastModifiedDate DESC LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Cross-check:** For each recently deactivated user, verify their OAuth grants were also revoked (check `OAuth2` object).

```bash
sf data query \
  --query "SELECT ConnectedApplication.Name, User.Username, Scopes, LastUsedDate FROM OAuth2 WHERE User.IsActive = FALSE ORDER BY LastUsedDate DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 3. Password-locked accounts

```bash
sf data query \
  --query "SELECT UserId, User.Username, User.Name, IsPasswordLocked, IsFrozen FROM UserLogin WHERE IsPasswordLocked = TRUE ORDER BY UserId" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

Persistent lockouts on service accounts indicate brute-force attempts against integration credentials.

## 4. Users with never-expiring passwords

```bash
# Profile-level: check if password policies have expiry set to 'Never'
sf project retrieve start \
  --metadata "Profile" \
  --target-org "${TARGET_ORG:-dev}" \
  --output-dir /tmp/user-security-audit 2>/dev/null

grep -rn "never\|Never\|passwordExpiration" \
  /tmp/user-security-audit/profiles/ 2>/dev/null | head -20
```

## 5. Delegated administrators

```bash
# Groups with admin delegation
sf data query \
  --query "SELECT Id, DeveloperName, Name FROM DelegateGroup ORDER BY Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Members of delegated admin groups
sf data query \
  --query "SELECT DelegateGroupId, UserId, User.Username, User.Profile.Name FROM UserDelegatedApprover ORDER BY DelegateGroupId" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 6. Users with login hours restrictions (who does NOT have them)

```bash
# Profiles without login hour restrictions on admin-level users
# Flag System Administrator profile with 24/7 login access
sf data query \
  --query "SELECT Name, COUNT(Id) Users FROM Profile WHERE UserType = 'Standard' GROUP BY Name ORDER BY Users DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 7. API-enabled non-integration users (insider threat vector)

```bash
sf data query \
  --query "SELECT Id, Name, Username, LastLoginDate, Profile.Name FROM User WHERE IsActive = TRUE AND Profile.PermissionsApiEnabled = TRUE AND Profile.Name NOT IN ('System Administrator','Integration User','API Only User') AND UserType = 'Standard' ORDER BY Profile.Name, Name LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 8. Users without MFA (where MFA is not enforced at profile level)

```bash
# Users with MFA not required via permission set
sf data query \
  --query "SELECT Assignee.Username, Assignee.IsActive FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Salesforce_MFA_Required' ORDER BY Assignee.Username" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Check if High Assurance sessions are required
sf data query \
  --query "SELECT CreatedDate, CreatedBy.Username, Action, Display FROM SetupAuditTrail WHERE Section = 'Session Settings' AND Display LIKE '%MFA%' ORDER BY CreatedDate DESC LIMIT 10" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 9. Super users: ModifyAllData via any path

```bash
# Via profile
sf data query \
  --query "SELECT Name, UserType FROM Profile WHERE PermissionsModifyAllData = TRUE ORDER BY Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Via permission set
sf data query \
  --query "SELECT Assignee.Username, Assignee.IsActive, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.PermissionsModifyAllData = TRUE ORDER BY Assignee.Username" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 10. Inactive users still consuming licenses

```bash
sf data query \
  --query "SELECT UserType, COUNT(Id) Count FROM User WHERE IsActive = FALSE AND LastLoginDate != NULL GROUP BY UserType ORDER BY Count DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 11. Users created in last N days (insider threat onboarding watch)

```bash
sf data query \
  --query "SELECT Id, Name, Username, Profile.Name, CreatedBy.Username, CreatedDate FROM User WHERE CreatedDate = LAST_N_DAYS:${DAYS:-30} AND IsActive = TRUE ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## Risk matrix

| Finding | Severity | Action |
|---------|----------|--------|
| OAuth grant surviving deactivation | 🔴 Critical | Revoke token immediately |
| Frozen account with active API session | 🔴 Critical | Deactivate fully |
| `ModifyAllData` on non-admin profile/permset | 🔴 Critical | Remove immediately |
| Locked password on service account (repeated) | 🟡 High | Rotate credential, check for brute force |
| API-enabled on non-integration user | 🟡 Medium | Review; add MFA requirement |
| Never-expiring password on admin account | 🟡 Medium | Set rotation policy |
| New admin user created outside change window | 🟡 Medium | Verify authorization |
| Delegated admin group with broad membership | 🟡 Medium | Audit scope |
