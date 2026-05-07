---
name: user-access-audit
description: Audit Salesforce user access — active users, license consumption, profile assignments, permission set grants, role hierarchy, and over-privileged accounts. Produces a user access review (UAR) report.
argument-hint: [--target-org <alias>] [--format table|csv]
---

# user-access-audit

A structured User Access Review (UAR) covering identity, privilege, and activity for all active users.

## User inventory

```bash
# All active users with key fields
sf data query \
  --query "SELECT Id, Name, Username, Email, IsActive, UserType, Profile.Name, UserRole.Name, LastLoginDate, CreatedDate FROM User WHERE IsActive = TRUE ORDER BY Profile.Name, Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# User count by profile
sf data query \
  --query "SELECT Profile.Name, COUNT(Id) UserCount FROM User WHERE IsActive = TRUE GROUP BY Profile.Name ORDER BY UserCount DESC" \
  --target-org "${TARGET_ORG:-prod-org}"

# User count by license type
sf data query \
  --query "SELECT UserType, COUNT(Id) Count FROM User WHERE IsActive = TRUE GROUP BY UserType ORDER BY Count DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Over-privileged users

```bash
# Sys Admin profile users
sf data query \
  --query "SELECT Id, Name, Username, LastLoginDate FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Users with Modify All Data permission (any source)
sf data query \
  --query "SELECT Assignee.Name, Assignee.Username, PermissionSet.Name, PermissionSet.PermissionsModifyAllData FROM PermissionSetAssignment WHERE (PermissionSet.PermissionsModifyAllData = TRUE OR PermissionSet.PermissionsViewAllData = TRUE) AND Assignee.IsActive = TRUE ORDER BY Assignee.Username" \
  --target-org "${TARGET_ORG:-prod-org}"

# API-enabled non-integration users
sf data query \
  --query "SELECT Name, Username, Profile.Name, LastLoginDate FROM User WHERE IsActive = TRUE AND Profile.PermissionsApiEnabled = TRUE AND Profile.Name NOT LIKE '%Integration%' AND Profile.Name NOT LIKE '%API%' AND Profile.Name != 'System Administrator' ORDER BY Profile.Name, Name" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Inactive & stale accounts

```bash
# Active users not logged in for 90+ days
sf data query \
  --query "SELECT Name, Username, Profile.Name, LastLoginDate FROM User WHERE IsActive = TRUE AND LastLoginDate < LAST_N_DAYS:90 AND UserType = 'Standard' ORDER BY LastLoginDate ASC NULLS FIRST" \
  --target-org "${TARGET_ORG:-prod-org}"

# Users never logged in
sf data query \
  --query "SELECT Name, Username, Profile.Name, CreatedDate FROM User WHERE IsActive = TRUE AND LastLoginDate = NULL AND UserType = 'Standard' ORDER BY CreatedDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"

# Deactivated users (for offboarding verification)
sf data query \
  --query "SELECT Name, Username, Profile.Name, LastLoginDate FROM User WHERE IsActive = FALSE AND LastLoginDate = LAST_N_DAYS:30 ORDER BY LastLoginDate DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Permission set assignments

```bash
# All permission set assignments with user details
sf data query \
  --query "SELECT Assignee.Name, Assignee.Username, Assignee.IsActive, PermissionSet.Name, PermissionSet.Label, ExpirationDate FROM PermissionSetAssignment WHERE PermissionSet.IsOwnedByProfile = FALSE ORDER BY Assignee.Username, PermissionSet.Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Permission set group memberships
sf data query \
  --query "SELECT Assignee.Name, Assignee.Username, PermissionSetGroup.DeveloperName FROM PermissionSetGroupComponent WHERE Assignee.IsActive = TRUE ORDER BY Assignee.Username" \
  --target-org "${TARGET_ORG:-prod-org}"

# Permission sets with > 50 users (wide blast-radius grants)
sf data query \
  --query "SELECT PermissionSet.Name, COUNT(Id) AssigneeCount FROM PermissionSetAssignment WHERE PermissionSet.IsOwnedByProfile = FALSE GROUP BY PermissionSet.Name HAVING COUNT(Id) > 50 ORDER BY AssigneeCount DESC" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Role hierarchy analysis

```bash
# Full role hierarchy with user counts
sf data query \
  --query "SELECT Name, DeveloperName, ParentRole.Name, PortalType FROM UserRole ORDER BY ParentRole.Name NULLS FIRST, Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Users in top-level roles (broadest data access via hierarchy)
sf data query \
  --query "SELECT Name, Username, UserRole.Name FROM User WHERE IsActive = TRUE AND UserRole.ParentRoleId = NULL AND UserRole.Name != NULL ORDER BY UserRole.Name, Name" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Integration / service accounts

```bash
# Non-human accounts (integration users)
sf data query \
  --query "SELECT Name, Username, Profile.Name, LastLoginDate, CreatedDate FROM User WHERE IsActive = TRUE AND UserType IN ('AutomatedProcess', 'Integration') ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Standard users with name suggesting service accounts
sf data query \
  --query "SELECT Name, Username, Profile.Name, LastLoginDate FROM User WHERE IsActive = TRUE AND (Username LIKE '%integration%' OR Username LIKE '%service%' OR Username LIKE '%api%' OR Username LIKE '%system%') AND UserType = 'Standard' ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## UAR report format

Produce a User Access Review document:

```
## User Access Review — <org alias> — <date>
**Review period**: <start> to <end>
**Reviewer**: <name>

### Summary
| Category | Count |
|----------|-------|
| Active users | |
| System Administrators | |
| Users inactive 90+ days | |
| Users with ModifyAllData | |
| Unique permission sets assigned | |

### Findings
| Severity | User | Issue | Recommended Action |
|----------|------|-------|-------------------|

### Certifications
| Profile/PermSet | Owner | Status (Approve/Revoke) |
|----------------|-------|------------------------|
```
