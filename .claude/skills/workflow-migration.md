---
name: workflow-migration
description: Audit and migrate legacy Salesforce automation (Workflow Rules and Process Builder flows) to record-triggered Flows. Inventories all active legacy automation, identifies migration complexity, detects automation stacking, and produces a prioritised migration plan.
argument-hint: [--target-org <alias>] [--object <SObjectType>]
---

# workflow-migration

Salesforce sunset Workflow Rules and Process Builder automation in favor of Flow. This skill audits your legacy automation inventory, scores migration complexity, identifies risks (double-fire, execution-order conflicts), and generates a structured migration plan.

## 1. Workflow Rule inventory

```bash
# All active workflow rules grouped by object
sf data query \
  --query "SELECT Id, TableEnumOrId, Name, TriggerType, WorkflowTimeTriggers, Actions FROM WorkflowRule WHERE IsActive = TRUE ORDER BY TableEnumOrId, Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Count by object — identify migration hotspots
sf data query \
  --query "SELECT TableEnumOrId, COUNT(Id) RuleCount FROM WorkflowRule WHERE IsActive = TRUE GROUP BY TableEnumOrId ORDER BY RuleCount DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 2. Workflow Rule action types (determines migration complexity)

```bash
# Field updates (simple — map to Flow Update Records)
sf data query \
  --query "SELECT WorkflowRule.Name, WorkflowRule.TableEnumOrId, Field, NewValue, LiteralValue FROM WorkflowFieldUpdate ORDER BY WorkflowRule.TableEnumOrId, WorkflowRule.Name" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Email alerts (moderate — map to Flow Send Email action)
sf data query \
  --query "SELECT WorkflowRule.Name, WorkflowRule.TableEnumOrId, Template.Name, Description FROM WorkflowAlert ORDER BY WorkflowRule.TableEnumOrId" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Time-based actions (complex — requires scheduled paths in Flow)
sf data query \
  --query "SELECT WorkflowRule.Name, WorkflowRule.TableEnumOrId, TimeLength, WorkflowTimeTriggerUnit FROM WorkflowTimeTrigger ORDER BY WorkflowRule.TableEnumOrId" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Outbound messages (complex — replace with Platform Events or callout Flow)
sf data query \
  --query "SELECT WorkflowRule.Name, WorkflowRule.TableEnumOrId, EndpointUrl, Fields FROM WorkflowOutboundMessage ORDER BY WorkflowRule.TableEnumOrId" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Apex triggers called from WF (complex — evaluate if Apex handles it directly)
sf data query \
  --query "SELECT WorkflowRule.Name, WorkflowRule.TableEnumOrId, ApexClass.Name FROM WorkflowApexAction ORDER BY WorkflowRule.TableEnumOrId" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 3. Process Builder inventory

```bash
# All active Process Builder flows
sf data query \
  --query "SELECT DeveloperName, MasterLabel, ProcessType, TriggerObjectOrEventLabel, ActiveVersionId, LastModifiedDate, LastModifiedBy.Username FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','InvocableProcess','CustomEvent') ORDER BY TriggerObjectOrEventLabel, DeveloperName" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Count by object
sf data query \
  --query "SELECT TriggerObjectOrEvent.QualifiedApiName, COUNT(Id) PBCount FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','InvocableProcess') GROUP BY TriggerObjectOrEvent.QualifiedApiName ORDER BY PBCount DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 4. Automation stacking detection (execution-order risk)

```bash
# Objects with both Workflow Rules AND Process Builder (double-fire risk)
sf data query \
  --query "SELECT TriggerObjectOrEvent.QualifiedApiName, COUNT(Id) FlowCount FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType IN ('Workflow','InvocableProcess','AutoLaunchedFlow') GROUP BY TriggerObjectOrEvent.QualifiedApiName HAVING COUNT(Id) > 1 ORDER BY FlowCount DESC" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Objects with active record-triggered Flows (potential triple-fire when mixing legacy + Flow)
sf data query \
  --query "SELECT TriggerObjectOrEvent.QualifiedApiName, TriggerType, COUNT(Id) FlowCount FROM FlowDefinition WHERE IsActive = TRUE AND ProcessType = 'AutoLaunchedFlow' AND TriggerObjectOrEventLabel != '' GROUP BY TriggerObjectOrEvent.QualifiedApiName, TriggerType ORDER BY FlowCount DESC LIMIT 20" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

**Flag:** Any object with Workflow Rule + Process Builder + record-triggered Flow = 🔴 Critical — unpredictable execution order, recursion risk.

## 5. Inactive legacy automation (safe to delete)

```bash
# Inactive Workflow Rules — candidates for deletion rather than migration
sf data query \
  --query "SELECT TableEnumOrId, Name, LastModifiedDate FROM WorkflowRule WHERE IsActive = FALSE ORDER BY TableEnumOrId, Name LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null

# Inactive Process Builder versions
sf data query \
  --query "SELECT DeveloperName, MasterLabel, ProcessType, LastModifiedDate FROM FlowDefinition WHERE IsActive = FALSE AND ProcessType IN ('Workflow','InvocableProcess') ORDER BY DeveloperName LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --json 2>/dev/null
```

## 6. Migration complexity scoring

Score each rule/process on these factors:

| Factor | Weight | Notes |
|--------|--------|-------|
| Time-based actions | +3 | Scheduled paths needed in Flow |
| Outbound messages | +3 | Requires Platform Event or external callout |
| Apex invocation | +2 | May be able to inline or call Apex action |
| Multiple action types | +2 | More Flow elements needed |
| Cross-object field updates | +2 | Related-record updates in Flow |
| Email alerts | +1 | Direct equivalent in Flow |
| Simple field update (1 field) | +0 | Easiest migration |
| Inactive (no migration needed) | -5 | Delete instead |

```
Total score: 0–2 = 🟢 Easy, 3–5 = 🟡 Moderate, 6+ = 🔴 Complex
```

## 7. Migration pattern reference

| Legacy Element | Flow Equivalent | Notes |
|---|---|---|
| Workflow Rule (on create/update) | Record-Triggered Flow | Use `BEFORE_SAVE` for field updates, `AFTER_SAVE` for related records |
| Workflow Field Update | Update Records element | Map criteria → entry conditions |
| Workflow Email Alert | Send Email element or Email Alert action | |
| Time-based action | Scheduled Path | Set relative start `RecordTriggerType` |
| Outbound Message | HTTP Callout action (Flow) or Platform Event | |
| Process Builder (invocable) | Screen Flow or Auto-launched Flow | |
| Cross-object update | Related record `Update Records` with related-path filter | |
| Apex action | Apex Action element in Flow | |

## 8. Decommission checklist (per migrated rule)

```
□ Build equivalent Flow in sandbox — match all criteria and actions exactly
□ Run regression tests (sf apex run test --test-level RunLocalTests)
□ Verify Flow fires correctly on all trigger types (insert, update, specific fields)
□ Deactivate Workflow Rule / Process Builder version (do NOT delete yet)
□ Monitor for 1 release cycle (2 weeks minimum)
□ Delete deactivated legacy automation
□ Update SetupAuditTrail or change log for compliance
```

## Output format

```
=== WORKFLOW MIGRATION AUDIT ===
Org: <alias>  |  Object filter: <all | SObjectType>

LEGACY AUTOMATION INVENTORY
Active Workflow Rules:   18  (across 7 objects)
Active Process Builder:  12  (across 5 objects)
Inactive (delete-only):  24

STACKING RISKS 🔴
  Account: 3 Workflow Rules + 2 Process Builder + 1 record-triggered Flow
  Contact: 2 Workflow Rules + 1 Process Builder

MIGRATION PLAN (priority order)
🔴 Complex (score 6+):
  1. AccountAutoAssign_WR  — time-based + outbound message + Apex  [Account]
  2. LeadRouting_PB        — cross-object + time-based              [Lead]

🟡 Moderate (score 3–5):
  3. CaseEscalation_WR     — time-based + email alert               [Case]
  4. OpptyStageEmail_WR    — multiple field updates + email          [Opportunity]

🟢 Easy (score 0–2):
  5–18. Field-update-only rules   → bulk migrate by object

ACTIONS
1. IMMEDIATE: Deactivate duplicate automations on Account (stacking risk)
2. Delete 24 inactive rules/processes — no migration needed
3. Start migration with easy rules (14 rules) to reduce inventory
4. Plan 2 complex migrations (AccountAutoAssign, LeadRouting) as separate stories

Estimated effort: ~40 hours (14 easy × 1h + 2 moderate × 3h + 2 complex × 8h)
```
