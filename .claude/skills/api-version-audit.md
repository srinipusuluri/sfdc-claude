---
name: api-version-audit
description: Audit Salesforce API versions across all metadata — Apex classes, triggers, LWC, Aura, Flows, and Visualforce. Flags components pinned to outdated API versions that miss security patches or deprecated behavior, and produces a migration priority list.
argument-hint: [--target-org <alias>] [--min-version <n>]
---

# api-version-audit

API version drift is one of the most common forms of technical debt in mature Salesforce orgs. Components pinned to old versions silently use deprecated behavior, miss governor limit improvements, and may break when Salesforce retires old APIs.

## 1. Org API version baseline

```bash
# Current org API version (latest supported)
sf api request rest "/services/data/" \
  --target-org "${TARGET_ORG:-dev}" 2>/dev/null | \
  python3 -c "import sys,json; vs=[v['version'] for v in json.load(sys.stdin)]; print('Latest:', vs[-1], '| Oldest supported:', vs[0])"
```

## 2. Apex classes — API version inventory (Tooling API)

```bash
sf data query \
  --query "SELECT Name, ApiVersion, NamespacePrefix, LastModifiedDate, LastModifiedBy.Username FROM ApexClass WHERE NamespacePrefix = '' ORDER BY ApiVersion ASC, Name ASC LIMIT 200" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

**Flag:** Any class with `ApiVersion < ${MIN_VERSION:-57}` (v57 = Winter '23; adjust `--min-version` as needed).

## 3. Apex triggers — API version inventory

```bash
sf data query \
  --query "SELECT Name, ApiVersion, TableEnumOrId, LastModifiedDate, LastModifiedBy.Username FROM ApexTrigger WHERE NamespacePrefix = '' ORDER BY ApiVersion ASC, Name ASC LIMIT 100" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

## 4. Flows — API version inventory

```bash
sf data query \
  --query "SELECT DeveloperName, VersionNumber, ApiVersion, ProcessType, Status, LastModifiedDate FROM Flow WHERE Status = 'Active' AND ManageableState = 'unmanaged' ORDER BY ApiVersion ASC, DeveloperName ASC LIMIT 100" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

## 5. LWC components — meta.xml API version check (local source)

```bash
# Find all LWC meta files and extract apiVersion
grep -rn "apiVersion" force-app --include="*.js-meta.xml" | \
  awk -F'[<>]' '{print $3, FILENAME}' | \
  sort -n | head -30
```

```bash
# Flag any LWC below threshold
MIN_VER="${MIN_VERSION:-57}"
grep -rn "apiVersion" force-app --include="*.js-meta.xml" | \
  awk -F'[<>]' -v min="$MIN_VER" '$3 < min {print "OLD API " $3 ": " FILENAME}'
```

## 6. Aura components — meta.xml API version check

```bash
grep -rn "apiVersion" force-app --include="*-meta.xml" | \
  grep -i "aura\|app\|cmp\|evt" | \
  awk -F'[<>]' '{print $3, FILENAME}' | sort -n | head -20
```

## 7. Visualforce pages and components

```bash
sf data query \
  --query "SELECT Name, ApiVersion, LastModifiedDate, LastModifiedBy.Username FROM ApexPage WHERE NamespacePrefix = '' ORDER BY ApiVersion ASC LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null

sf data query \
  --query "SELECT Name, ApiVersion, LastModifiedDate, LastModifiedBy.Username FROM ApexComponent WHERE NamespacePrefix = '' ORDER BY ApiVersion ASC LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

## 8. Static Resources and Permission Sets — meta.xml check

```bash
grep -rn "apiVersion" force-app --include="*.permissionset-meta.xml" --include="*.resource-meta.xml" | \
  awk -F'[<>]' '{print $3, FILENAME}' | sort -n | head -20
```

## 9. Installed packages — API version support matrix

```bash
sf data query \
  --query "SELECT SubscriberPackage.Name, SubscriberPackageVersion.Name, SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion, SubscriberPackageVersion.BuildNumber FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

Cross-reference each package version against the publisher's release notes to flag outdated versions.

## 10. Bulk update via source format (local)

After identifying stale components, update API versions in source:

```bash
# Update all LWC meta files to current API version (e.g., 62.0)
find force-app -name "*.js-meta.xml" -exec \
  sed -i '' 's|<apiVersion>[0-9.]*</apiVersion>|<apiVersion>62.0</apiVersion>|g' {} \;

# Same for Aura
find force-app -name "*-meta.xml" -path "*/aura/*" -exec \
  sed -i '' 's|<apiVersion>[0-9.]*</apiVersion>|<apiVersion>62.0</apiVersion>|g' {} \;
```

**Important:** After bumping API versions, run full org tests (`sf apex run test --test-level RunLocalTests`) — API version bumps occasionally change behavior.

## Risk matrix

| API Version Range | Era | Risk |
|---|---|---|
| ≤ 29.0 | Pre-Spring '14 | 🔴 Critical — likely broken behavior |
| 30–44 | Spring '14 – Summer '18 | 🔴 Critical — many deprecated APIs retired |
| 45–52 | Spring '19 – Summer '21 | 🟡 High — missing security model improvements |
| 53–56 | Winter '22 – Summer '22 | 🟡 Medium — missing governor limit increases |
| 57–60 | Winter '23 – Summer '23 | 🟡 Low — 1–2 versions behind |
| 61+ | Winter '24+ | 🟢 Current |

## Output format

```
=== API VERSION AUDIT ===
Org current API version: 62.0
Minimum acceptable version: 57.0

🔴 Critical (< v45):
  AccountTrigger          v32   → update immediately
  LeadConversionHelper    v29   → update immediately

🟡 Outdated (v45–v56):
  OpportunityService      v52
  ContactMergeController  v48

🟢 Current (v57+):
  43 of 47 Apex classes  ✅
  12 of 12 LWC components ✅

LWC below threshold:   2 components
Flows below threshold: 1 active flow
VF pages below:        0

Recommendation: Bump 6 Apex components and 2 LWCs to v62.0, run full test suite.
```
