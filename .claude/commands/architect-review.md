---
description: Perform a Salesforce architecture review — data model, integration patterns, governor limit exposure, org strategy, and scalability. Produces a decision record and findings report.
argument-hint: [--scope <data-model|integrations|org-strategy|all>] [--target-org <alias>]
---

Perform an architecture review using the **solution-architect** agent.

## Steps

1. Parse arguments:
   - `--scope`: defaults to `all`
   - `--target-org`: optional — provide for live org analysis

2. Analyze the force-app metadata for structural concerns:

   **Data model review:**
   ```bash
   # Count fields per object (flag > 500)
   find force-app -name "*.object-meta.xml" | while read f; do
     count=$(grep -c "<fields>" "$f" 2>/dev/null || echo 0)
     echo "$f: $count fields"
   done | sort -t: -k2 -rn | head -20

   # Find cross-object formulas (flag > 5 hops)
   grep -r "getSObjectType\|__r\." force-app --include="*.cls" | grep -v "_Test\|test" | head -20

   # Master-Detail relationships
   grep -rl "type>MasterDetail" force-app --include="*.field-meta.xml"
   ```

   **Integration review:**
   ```bash
   # Find hardcoded endpoints (should use Named Credentials)
   grep -rn "https://\|http://" force-app --include="*.cls" | grep -v "//\s" | grep -v "_Test"

   # Named Credential usage
   grep -rn "Named_Credential\|callout:" force-app --include="*.cls"

   # Platform Event definitions
   find force-app -name "*.event-meta.xml" | head -20
   ```

   **Governor limit exposure:**
   ```bash
   # SOQL in loops (anti-pattern)
   grep -n "for\s*(" force-app --include="*.cls" -r -A5 | grep -B3 "\[SELECT"

   # DML in loops
   grep -n "for\s*(" force-app --include="*.cls" -r -A5 | grep -B3 "insert\|update\|delete\|upsert"

   # Missing bulkification (trigger without bulk pattern)
   grep -n "Trigger\." force-app --include="*.cls" -r | grep "\[0\]"
   ```

   **Async pattern review:**
   ```bash
   # Queueable usage
   grep -rl "Queueable" force-app --include="*.cls"

   # Batch Apex — check Stateful usage
   grep -n "Database.Stateful" force-app --include="*.cls" -r

   # Schedulable classes
   grep -rl "Schedulable" force-app --include="*.cls"
   ```

3. If `--target-org` provided, run live checks:
   ```bash
   # Object count and field density via Tooling API
   sf data query \
     --query "SELECT QualifiedApiName, COUNT_DISTINCT(QualifiedApiName) FROM FieldDefinition GROUP BY EntityDefinition.QualifiedApiName ORDER BY COUNT_DISTINCT(QualifiedApiName) DESC LIMIT 20" \
     --target-org <target-org> \
     --use-tooling-api

   # Active integrations via Platform Events
   sf data query \
     --query "SELECT DeveloperName, IsActive FROM PlatformEventChannel ORDER BY DeveloperName" \
     --target-org <target-org>
   ```

4. Hand all findings to the **solution-architect** agent for:
   - Pattern identification and anti-pattern flagging
   - Scalability risk scoring
   - Decision record drafting for any recommended structural changes

## Output

Produce an architecture review document:

```markdown
# Architecture Review — <date>

## Scope
<what was reviewed>

## Data Model
| Object | Fields | Relationships | Risk | Notes |
|--------|--------|--------------|------|-------|

## Integration Patterns
| Integration | Pattern | Risk | Recommendation |
|------------|---------|------|---------------|

## Governor Limit Exposure
| Location | Issue | Severity | Fix |
|----------|-------|----------|-----|

## Org Strategy
<org design assessment>

## Decision Records
<any structural decisions recommended>

## Blocker / Concern / Note summary
| Type | Area | Finding | Owner |
|------|------|---------|-------|
```
