---
name: org-security-posture
description: Comprehensive Salesforce org security posture check — Named Credentials, Remote Site Settings, CORS, CSP Trusted Sites, certificates, installed packages, legacy automation (Workflow Rules, Process Builder), Platform Cache, sharing model health, and encryption status. Designed for complex orgs with multiple integrations and long histories.
argument-hint: [--target-org <alias>]
---

# org-security-posture

Deep security configuration audit for orgs with complex integration landscapes and accumulated technical debt.

## 1. Remote Site Settings (approved callout endpoints)

```bash
sf data query \
  --query "SELECT Id, EndpointUrl, IsActive, Description FROM SiteIframeWhiteListUrl WHERE IsActive = TRUE ORDER BY EndpointUrl" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Via metadata (more complete)
sf project retrieve start \
  --metadata "RemoteSiteSetting" \
  --target-org "${TARGET_ORG:-dev}" \
  --output-dir /tmp/security-posture 2>/dev/null

grep -rn "url\|isActive\|description" /tmp/security-posture/remoteSiteSettings/ 2>/dev/null | head -30
```

**Flag:** `http://` endpoints (not HTTPS), wildcard domains, internal IP ranges, inactive entries never cleaned up.

## 2. CORS Whitelist

```bash
sf data query \
  --query "SELECT Id, UrlPattern FROM CorsWhitelistEntry ORDER BY UrlPattern" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Wildcard `*` entries, `http://` origins, localhost entries left from development.

## 3. CSP Trusted Sites

```bash
sf data query \
  --query "SELECT Id, EndpointUrl, Context, IsActive, Description FROM ContentSecurityPolicy ORDER BY EndpointUrl" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** `unsafe-inline`, `unsafe-eval`, wildcard `*` sources, `http://` sites.

## 4. Named Credentials inventory

```bash
sf project retrieve start \
  --metadata "NamedCredential" \
  --target-org "${TARGET_ORG:-dev}" \
  --output-dir /tmp/security-posture 2>/dev/null

# List endpoints and auth types
grep -rn "endpoint\|authProtocol\|authProvider\|label" \
  /tmp/security-posture/namedCredentials/ 2>/dev/null | head -30
```

**Flag:** Named Credentials using `Anonymous` auth (no credentials), `http://` endpoints, credentials pointing to internal RFC-1918 addresses (SSRF risk).

## 5. Client certificates nearing expiry

```bash
sf data query \
  --query "SELECT Id, DeveloperName, ExpirationDate, KeySize FROM Certificate WHERE ExpirationDate < NEXT_N_DAYS:90 ORDER BY ExpirationDate ASC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Any cert expiring within 30 days is Critical; 90 days is Warning.

## 6. Installed managed packages (supply chain)

```bash
sf data query \
  --query "SELECT Id, SubscriberPackage.Name, SubscriberPackage.NamespacePrefix, SubscriberPackageVersion.Name, SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Packages with old versions (check against publisher's latest), packages from unknown publishers, packages with `ModifyAllData` permission sets.

## 7. Legacy automation still active (technical debt + blast radius)

```bash
# Active Workflow Rules (should be migrated to Flow)
sf data query \
  --query "SELECT TableEnumOrId, COUNT(Id) Count FROM WorkflowRule WHERE IsActive = TRUE GROUP BY TableEnumOrId ORDER BY Count DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Active Process Builder flows (ProcessType = Workflow)
sf data query \
  --query "SELECT DeveloperName, ProcessType, ActiveVersionId FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','CustomEvent','InvocableProcess') ORDER BY DeveloperName" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Active record-triggered flows by object (to spot automation stacking)
sf data query \
  --query "SELECT TriggerObjectOrEvent.QualifiedApiName, COUNT(Id) FlowCount FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType = 'AutoLaunchedFlow' GROUP BY TriggerObjectOrEvent.QualifiedApiName HAVING COUNT(Id) > 1 ORDER BY FlowCount DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Objects with >3 active flows (automation stacking = unpredictable order), active Process Builder on objects also covered by record-triggered flows (double-fire risk), Workflow Rules that email external addresses.

## 8. Sharing model anomalies

```bash
# Objects with Public Read/Write OWD (broadest sharing)
sf data query \
  --query "SELECT QualifiedApiName, InternalSharingModel, ExternalSharingModel FROM EntityDefinition WHERE IsCustomizable = TRUE AND (InternalSharingModel = 'ReadWrite' OR ExternalSharingModel = 'ReadWrite') ORDER BY QualifiedApiName" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null

# Criteria-based sharing rules count per object
sf data query \
  --query "SELECT SobjectType, AccessLevel, COUNT(Id) RuleCount FROM GroupMember GROUP BY SobjectType, AccessLevel ORDER BY RuleCount DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 9. Platform Cache partitions

```bash
sf data query \
  --query "SELECT DeveloperName, MasterLabel, OrganizationCacheAllocation, SessionCacheAllocation FROM PlatformCachePartition ORDER BY DeveloperName" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** No platform cache defined in a complex org (performance risk), single partition with all allocation (no isolation between domains).

## 10. Shield Platform Encryption status

```bash
sf data query \
  --query "SELECT Id, DeveloperName, MasterLabel, Type FROM EncryptionKey ORDER BY DeveloperName" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Encrypted fields
sf data query \
  --query "SELECT QualifiedApiName, EntityDefinition.QualifiedApiName, IsEncrypted FROM FieldDefinition WHERE IsEncrypted = TRUE ORDER BY EntityDefinition.QualifiedApiName" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

## 11. Data Classification health (PII tagging)

```bash
# Unclassified custom fields on objects that likely hold PII
sf data query \
  --query "SELECT QualifiedApiName, EntityDefinition.QualifiedApiName, ComplianceGroup, SecurityClassification FROM FieldDefinition WHERE SecurityClassification = NULL AND EntityDefinition.QualifiedApiName IN ('Contact','Lead','Case','Account') ORDER BY EntityDefinition.QualifiedApiName, QualifiedApiName LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

**Flag:** `Contact`, `Lead`, `Case` with unclassified custom fields — these likely hold PII and need GDPR/CCPA tagging.

## 12. Apex sharing recalculation jobs

```bash
sf data query \
  --query "SELECT Id, Status, JobType, NumberOfErrors, TotalJobItems, CreatedDate FROM AsyncApexJob WHERE JobType = 'SharingRecalculation' AND Status IN ('Queued','Processing','Preparing') ORDER BY CreatedDate DESC LIMIT 10" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Sharing recalc jobs stuck in `Processing` for > 24 hours indicate sharing rule complexity problems.

## 13. Auth providers (SSO configuration)

```bash
sf data query \
  --query "SELECT Id, DeveloperName, ProviderType, FriendlyName FROM AuthProvider ORDER BY ProviderType, DeveloperName" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 14. Guest user access (Experience Cloud surface)

```bash
# Objects the guest profile can read
sf data query \
  --query "SELECT SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete FROM ObjectPermissions WHERE Parent.Profile.UserType = 'Guest' AND PermissionsRead = TRUE ORDER BY SobjectType" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Guest user accessing `Contact`, `Account`, `User`, `Case`, `Order` — these are critical findings.

## Output format

```
=== ORG SECURITY POSTURE ===
Complex-org checks: 14 domains

🔴 Critical:
  Certificate expiring in 14 days: MyAPIClientCert
  Guest user can read: Contact, Case

🟡 Warning:
  CORS entry with http:// origin
  3 active Process Builder flows (migrate to Flow)
  DataStorage at 60%

🟢 Clean:
  Named Credentials: all HTTPS, all authenticated
  Remote Site Settings: all active, all HTTPS
  CORS: no wildcards
  Installed packages: 2 packages, current versions
```
