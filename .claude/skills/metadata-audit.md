---
name: metadata-audit
description: Audit Salesforce metadata for security and compliance — profiles, permission sets, field-level security on PII fields, sharing rules, public groups, object permissions, and Connected App scopes.
argument-hint: [--target-org <alias>] [--format table|json]
---

# metadata-audit

Audit metadata configuration for over-permissioned users, exposed PII fields, and misconfigured sharing.

## Retrieve metadata for audit

```bash
# Pull all profiles, permission sets, sharing rules, and connected apps
sf project retrieve start \
  --metadata "Profile" "PermissionSet" "SharingRules" "ConnectedApp" "CustomObject" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --output-dir /tmp/metadata-audit-$(date +%Y%m%d)
```

## Dangerous permissions audit

```bash
# Profiles with admin-level permissions
sf data query \
  --query "SELECT Name, PermissionsModifyAllData, PermissionsViewAllData, PermissionsAuthorApex, PermissionsCustomizeApplication, PermissionsManageUsers FROM Profile WHERE PermissionsModifyAllData = TRUE OR PermissionsViewAllData = TRUE ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Permission sets granting system-wide access
sf data query \
  --query "SELECT Name, Label, PermissionsModifyAllData, PermissionsViewAllData, PermissionsAuthorApex FROM PermissionSet WHERE IsOwnedByProfile = FALSE AND (PermissionsModifyAllData = TRUE OR PermissionsViewAllData = TRUE) ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# Users assigned dangerous permission sets
sf data query \
  --query "SELECT Assignee.Username, Assignee.IsActive, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.PermissionsModifyAllData = TRUE OR PermissionSet.PermissionsViewAllData = TRUE ORDER BY Assignee.Username" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Field-level security on sensitive fields

```bash
# Fields marked as sensitive via Data Classification
sf data query \
  --query "SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, ComplianceGroup, SecurityClassification FROM FieldDefinition WHERE SecurityClassification IN ('Restricted', 'Confidential', 'MissionCritical') ORDER BY EntityDefinition.QualifiedApiName, QualifiedApiName" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --use-tooling-api

# Check FLS on sensitive fields for non-admin profiles via Tooling API
# Requires iterating FieldPermissions for each PermissionSet
sf data query \
  --query "SELECT Parent.Name, SobjectType, Field, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE SobjectType = 'Contact' AND Field IN ('Contact.SSN__c', 'Contact.DateofBirth__c', 'Contact.BankAccount__c') ORDER BY Parent.Name" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Sharing rules review

```bash
# All sharing rules by object
sf data query \
  --query "SELECT Name, SobjectType, AccessLevel, ShareWith FROM SharingRules ORDER BY SobjectType, Name" \
  --target-org "${TARGET_ORG:-prod-org}" || \
# Alternative: inspect retrieved XML files
grep -r "accessLevel>ReadWrite" /tmp/metadata-audit-*/sharingRules/ 2>/dev/null | head -20
grep -r "sharingCriteriaRules\|sharingOwnerRules" /tmp/metadata-audit-*/sharingRules/*.sharingRules 2>/dev/null | wc -l
```

## OWD (Organization-Wide Defaults)

```bash
# Check OWD for all objects — Public Read/Write on sensitive objects is a finding
sf data query \
  --query "SELECT QualifiedApiName, InternalSharingModel, ExternalSharingModel FROM EntityDefinition WHERE IsCustomizable = TRUE AND (InternalSharingModel = 'ReadWrite' OR ExternalSharingModel != 'Private') ORDER BY QualifiedApiName" \
  --target-org "${TARGET_ORG:-prod-org}" \
  --use-tooling-api
```

## Connected Apps and OAuth

```bash
# All connected apps
sf data query \
  --query "SELECT Name, ContactEmail, OptionsIsAdminApproved, OptionsIsConsumerSecretOptional FROM ConnectedApplication ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# OAuth token grants (who has authorized which app)
sf data query \
  --query "SELECT ConnectedApplication.Name, UserId, Scopes, UseCount, LastUsedDate FROM OAuth2 ORDER BY LastUsedDate DESC LIMIT 50" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Guest user access (Experience Cloud / Sites)

```bash
# Objects accessible to guest user profile
sf data query \
  --query "SELECT SobjectType, PermissionsRead, PermissionsEdit, PermissionsCreate, PermissionsDelete FROM ObjectPermissions WHERE Parent.Profile.UserType = 'Guest' AND PermissionsRead = TRUE ORDER BY SobjectType" \
  --target-org "${TARGET_ORG:-prod-org}"
```

## Apex / code permissions

```bash
# Profiles with AuthorApex (can write code in org)
sf data query \
  --query "SELECT Name FROM Profile WHERE PermissionsAuthorApex = TRUE ORDER BY Name" \
  --target-org "${TARGET_ORG:-prod-org}"

# RemoteSite settings (all external endpoints approved for callout)
sf data query \
  --query "SELECT EndpointUrl, IsActive, Description FROM SiteIframeWhiteListUrl ORDER BY EndpointUrl" \
  --target-org "${TARGET_ORG:-prod-org}" || \
grep -r "RemoteSiteSetting" /tmp/metadata-audit-*/remoteSiteSettings/ 2>/dev/null
```

## Metadata XML inspection

```bash
# Permission sets granting all-object access
grep -r "modifyAllData.*true\|viewAllData.*true" /tmp/metadata-audit-*/permissionsets/*.permissionset 2>/dev/null

# Profiles with excessive object Create/Edit/Delete on custom objects
grep -rA3 "<objectPermissions>" /tmp/metadata-audit-*/profiles/*.profile 2>/dev/null | grep -B1 "true"

# Named Credential endpoints
grep -r "<endpoint>" /tmp/metadata-audit-*/namedCredentials/*.namedCredential 2>/dev/null
```

## Findings format

Report by category:

| Severity | Category | Object/Component | Finding | Remediation |
|----------|----------|-----------------|---------|-------------|

**Categories**: Profile/PermSet · FLS · Sharing · OWD · Connected App · Guest User · Code Permissions

Flag anything that is:
- **Critical**: Guest user reading internal objects; `ModifyAllData` on non-admin profiles; exposed payment/health fields
- **High**: Unused profiles with admin perms; Public Read/Write OWD on custom objects holding PII
- **Medium**: Stale connected app OAuth grants; `AuthorApex` on developer profiles in prod
- **Low**: Inactive sharing rules; orphan permission sets
