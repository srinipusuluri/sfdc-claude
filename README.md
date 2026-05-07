# ⚡ Salesforce × Claude Code

> **AI-assisted Salesforce development for every team** — developers, architects, designers, testers, deployers, security, and audit.

[![Salesforce API](https://img.shields.io/badge/Salesforce_API-v66.0-00A1E0?logo=salesforce&logoColor=white)](https://developer.salesforce.com)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Sonnet_4-8A2BE2?logo=anthropic&logoColor=white)](https://claude.ai/code)
[![SFDX](https://img.shields.io/badge/SFDX-source_format-00A1E0)](https://developer.salesforce.com/tools/sfdxcli)
[![PMD](https://img.shields.io/badge/PMD-static_analysis-orange)](https://pmd.github.io)
[![ESLint](https://img.shields.io/badge/ESLint-LWC_rules-4B32C3)](https://eslint.org)

---

## 📋 Table of Contents

- [What is this?](#what-is-this)
- [Quick Start by Team](#quick-start-by-team)
- [🤖 Agents — AI Specialists](#-agents--ai-specialists)
- [⚡ Skills — Reusable Capabilities](#-skills--reusable-capabilities)
- [🎯 Commands — Slash Commands](#-commands--slash-commands)
- [🔍 Audit & Compliance](#-audit--compliance)
- [🚀 DevOps & Deployment](#-devops--deployment)
- [🎨 Design & Architecture](#-design--architecture)
- [🛡️ Security Review](#️-security-review)
- [🧪 Testing](#-testing)
- [🔁 Hooks & Automation](#-hooks--automation)
- [🔌 Plugins](#-plugins)
- [🔧 MCP Integrations](#-mcp-integrations)
- [📁 Project Structure](#-project-structure)
- [🏁 Getting Started](#-getting-started)

---

## What is this?

This project combines a **Salesforce DX workspace** (API v66, SFDX source format) with a fully configured **Claude Code AI assistant** tuned for every Salesforce team role.

Claude Code is Anthropic's AI CLI tool that understands your codebase, runs commands, and delegates work to specialized agents — all within your terminal or IDE. This configuration adds **12 Salesforce-specific agents**, **15 skills**, **13 slash commands**, **4 plugins**, and **automated quality hooks** out of the box.

```
Force App
└── force-app/main/default/
    ├── classes/      → Apex classes + tests
    ├── triggers/     → Apex triggers (handler pattern)
    └── lwc/          → Lightning Web Components

Claude Config (.claude/)
├── agents/           → 12 AI specialist personas
├── skills/           → 15 reusable capabilities
├── commands/         → 13 slash commands
├── hooks/            → 5 automated quality gates
├── plugins/          → 4 plugin bundles
├── tools/            → Shell utility scripts
└── mcp/              → MCP server configurations
```

---

## Quick Start by Team

Jump to your team's section for the most useful starting points.

| Team | Start here |
|------|-----------|
| 👩‍💻 **Developer** | [Apex Developer](#apex-developer) · [LWC Developer](#lwc-developer) · `/create-apex-class` · `/run-tests` |
| 🏛️ **Architect** | [Solution Architect](#solution-architect) · `/architect-review` |
| 🎨 **Designer** | [UX Designer](#ux-designer) · `/designer-review` |
| 🧪 **Tester / QA** | [Test Engineer](#test-engineer) · `/run-tests` · `/pmd-scan` |
| 🚢 **Deployer / Release** | [Release Manager](#release-manager) · [DevOps Engineer](#devops-engineer) · `/org-diff` |
| 🔒 **Security** | [Security Reviewer](#security-reviewer) · `/security-review` · `/code-analyzer` |
| 📊 **Audit / Compliance** | [Org Auditor](#org-auditor) · `/audit-org` · `/audit-event-logs` · `/audit-login-history` |
| 🔗 **Integration** | [Integration Specialist](#integration-specialist) · [Flow Architect](#flow-architect) |

---

## 🤖 Agents — AI Specialists

Agents are domain-expert AI personas that Claude spawns for specific tasks. You can invoke them explicitly or Claude routes to them automatically based on context.

```bash
# Invoke an agent explicitly in Claude Code
Use the apex-developer agent to review AccountService.cls for bulk safety
```

---

### 👩‍💻 Apex Developer

**File:** `.claude/agents/apex-developer.md`

The Apex specialist. Knows governor limits, trigger frameworks, bulk-safe patterns, and test class design.

**Capabilities:**
- Write and review Apex classes, triggers, and test classes
- Enforce bulk-safe patterns (no SOQL/DML in loops)
- Apply the trigger handler framework (`TriggerHandler` base class)
- Ensure `WITH USER_MODE` / FLS enforcement on queries
- Review `@AuraEnabled` and `@RestResource` methods for security

**Example prompts:**
```
Write a bulk-safe Apex service that upserts Contact records from an integration payload
Review AccountService.cls for governor limit exposure
Add test coverage for the edge case where Account.Name is null
```

---

### 🎨 UX Designer

**File:** `.claude/agents/ux-designer.md`

The front-end design specialist. SLDS-first, accessibility-mandatory, mobile-responsive.

**Capabilities:**
- SLDS utility class compliance (flag hardcoded CSS colors/margins)
- WCAG 2.1 AA accessibility audit (focus management, ARIA, contrast ratios)
- Experience Cloud page design (Branding Sets, target configs, guest user safety)
- LWC component design patterns (loading states, error states, empty states)
- Design token management (`--slds-*` variables)

**Example prompts:**
```
Review the account-card LWC component for SLDS violations and accessibility issues
Add a WCAG-compliant error state to the contact-form component
Generate the targetConfigs XML for an Experience Cloud property panel
```

---

### 🏛️ Solution Architect

**File:** `.claude/agents/solution-architect.md`

The structural decision-maker. Data models, integration patterns, org strategy, and governor limit planning.

**Capabilities:**
- Object and field design review (relationship types, field density, EAV anti-patterns)
- Integration pattern selection (sync REST, async Platform Events, CDC, Bulk API 2.0)
- Governor limit exposure analysis and mitigation strategies
- Org strategy advice (single-org vs multi-org, unlocked packages, 2GP design)
- Architecture decision records (ADRs)

**Example prompts:**
```
Review the data model for the new Claims object — should it use Master-Detail or Lookup?
We need to sync 500k records nightly from an ERP. What's the right integration pattern?
Produce an architecture decision record for moving to unlocked packages
```

---

### 🔗 Integration Specialist

**File:** `.claude/agents/integration-specialist.md`

REST/SOAP callouts, Named Credentials, Platform Events, CDC, Connected Apps, and OAuth flows.

**Capabilities:**
- Named Credential design and callout implementation
- Platform Event schema and subscriber patterns
- Change Data Capture setup and consumer architecture
- OAuth 2.0 flows (JWT Bearer, Web Server, Username-Password — for service accounts only)
- Inbound REST webhook validation (signature verification, rate limiting, schema validation)

**Example prompts:**
```
Write an Apex callout to the Payments API using Named Credentials with retry logic
Design a Platform Event topology for order status updates from the ERP
Review the Connected App OAuth scopes for least-privilege compliance
```

---

### 🌊 Flow Architect

**File:** `.claude/agents/flow-architect.md`

Record-triggered flows, screen flows, scheduled flows, subflows, and Flow vs. Apex decisions.

**Capabilities:**
- Flow design for record-triggered automation (Before Save vs After Save decisions)
- Screen Flow UX patterns and component selection
- Subflow composition and input/output variable design
- Flow debugging (Interview logs, fault paths, rollback behavior)
- "Flow vs. Apex" guidance — when each is appropriate

**Example prompts:**
```
Design a record-triggered flow to set Case SLA deadlines based on Priority and Account tier
Should this automation be a Flow or Apex trigger? The requirement is to update a parent record
Debug this Flow Interview log — why is the fault path triggering on every save?
```

---

### ⚙️ DevOps Engineer

**File:** `.claude/agents/devops-engineer.md`

Scratch orgs, source tracking, unlocked packages, CI/CD pipelines, and release management.

**Capabilities:**
- Scratch org lifecycle management (create, deploy, test, delete)
- Unlocked package versioning and promotion
- CI/CD pipeline design (PR validation → sandbox → UAT → production)
- Source tracking and metadata retrieval strategies
- Branching strategy (`main` = prod, `release/*` = UAT, feature → scratch org)

**Example prompts:**
```
Set up a scratch org, deploy force-app, and run all local tests
Create a new unlocked package version for the Billing bounded context
Design the GitHub Actions workflow for PR validation with PMD gating
```

---

### 🚢 Release Manager

**File:** `.claude/agents/release-manager.md`

Deployment planning, pre-release checklists, rollback procedures, and sandbox management.

**Capabilities:**
- Pre-release checklist generation (code quality, metadata readiness, data/config)
- Deployment command orchestration (`validate → quick deploy`)
- Rollback strategy by change type (Apex, Flow, profiles, data migrations)
- Sandbox lifecycle management (create, refresh, delete)
- Release notes generation and stakeholder communication templates

**Example prompts:**
```
Create a deployment plan for the March release — here's the package.xml
What's the rollback plan if the Flow changes cause issues in production?
Generate release notes for stakeholders from these git commits
```

---

### 🧪 Test Engineer

**File:** `.claude/agents/test-engineer.md`

Test data factories, mocking patterns, coverage analysis, and meaningful assertions.

**Capabilities:**
- Test data factory design (`@TestSetup`, `TestDataFactory` pattern)
- Mock patterns for callouts (`HttpCalloutMock`, `StaticResourceCalloutMock`)
- Coverage gap analysis (identify untested paths)
- Bulk test scenarios (200-record batches)
- LWC Jest test design (wire adapter mocking, Apex call mocking)

**Example prompts:**
```
The AccountService class has 60% coverage — generate tests for the missing branches
Write a TestDataFactory method for the Claims object with all required fields
Add a Jest test for the account-card LWC that mocks the getAccountData wire adapter
```

---

### 📐 PMD Analyst

**File:** `.claude/agents/pmd-analyst.md`

PMD/Code Analyzer static analysis, ruleset tuning, and false-positive suppression.

**Capabilities:**
- PMD finding triage (true positive vs false positive)
- Correct `@SuppressWarnings` annotation usage
- Custom ruleset configuration (`.pmdruleset.xml`)
- Code Analyzer DFA (data-flow analysis) interpretation
- CI gating threshold recommendations

**Example prompts:**
```
PMD is flagging ApexCRUDViolation on this method — is it a false positive?
Tune the PMD ruleset to exclude NcssMethodCount for test classes
Interpret these DFA findings and prioritize which ones to fix first
```

---

### 🔒 Security Reviewer

**File:** `.claude/agents/security-reviewer.md`

CRUD/FLS enforcement, SOQL injection prevention, LWC XSS, sharing rules, and AppExchange ISV checks.

**Capabilities:**
- CRUD/FLS audit (`WITH USER_MODE`, `Security.stripInaccessible`, explicit schema checks)
- SOQL/SOSL injection detection (dynamic queries, string concatenation)
- LWC XSS vectors (`lwc:dom="manual"`, `innerHTML`, `eval`)
- Metadata security (profile permissions, OWD, sharing rules, Connected App scopes)
- AppExchange ISV security review preparation

**Example prompts:**
```
Security review the AccountController class — flag any CRUD/FLS bypasses
Is this dynamic SOQL query vulnerable to injection?
Review the Guest User profile permissions for the Experience Cloud site
```

---

### 📊 Org Auditor

**File:** `.claude/agents/org-auditor.md`

Event log analysis, login history, SetupAuditTrail, field history, user access review, and compliance reporting.

**Capabilities:**
- Event Monitoring log analysis (ReportExport, Login, DataExport, API, PermissionSetAssignment)
- Login history anomaly detection (brute force, off-hours access, credential sharing)
- SetupAuditTrail investigation (code changes in prod, security setting changes, privilege escalation)
- User Access Review (UAR) reporting
- Compliance report generation (SOX, GDPR, HIPAA contexts)

**Example prompts:**
```
Who exported data in the last 30 days and how many rows did they export?
Run a User Access Review — flag stale accounts and over-privileged users
Was there any unauthorized code deployment in production this quarter?
```

---

## ⚡ Skills — Reusable Capabilities

Skills are parameterized workflows invoked as slash commands. They run shell commands, SOQL queries, and tool integrations on your behalf.

### Development Skills

| Skill | Command | What it does |
|-------|---------|-------------|
| `anonymous-apex` | `/anonymous-apex` | Execute anonymous Apex for data fixes and debugging |
| `soql-query` | `/soql-query` | Build and run SOQL with relationship traversal hints |
| `debug-log` | `/debug-log` | Pull, tail, and parse Apex debug logs from an org |
| `sfdx-deploy` | `/sfdx-deploy` | Deploy with validation, test gating, and production confirmation |

### Quality Skills

| Skill | Command | What it does |
|-------|---------|-------------|
| `pmd-scan` | `/pmd-scan` | PMD-only static analysis with severity threshold |
| `code-analyzer` | `/code-analyzer` | Full multi-engine scan: PMD + ESLint + RetireJS + CPD + DFA |
| `eslint-lint` | `/lint-fix` | LWC/Aura JS linting with `@salesforce/eslint-plugin-lwc` |
| `prettier-format` | `/lint-fix` | Apex, LWC, and metadata formatting |
| `lwc-jest` | `/lwc-test` | LWC Jest test runner with coverage |

### Audit Skills

| Skill | Command | What it does |
|-------|---------|-------------|
| `event-log-query` | `/audit-event-logs` | Query and download EventLogFile CSVs for analysis |
| `login-history-query` | `/audit-login-history` | Analyze LoginHistory, AuthSession, VerificationHistory |
| `org-health-check` | `/audit-org` | Governor limits, storage, coverage, jobs, flow errors |
| `metadata-audit` | `/audit-org` | Profiles, permission sets, FLS, OWD, Connected Apps |
| `setup-audit-trail` | `/audit-org` | 180-day admin change log analysis |
| `user-access-audit` | `/audit-org` | UAR: stale accounts, over-privileged users, service accounts |

---

## 🎯 Commands — Slash Commands

Type any `/command` in Claude Code to invoke it directly.

### Development Commands

```bash
/create-apex-class MyController          # Scaffold class + test + optional trigger handler
/run-tests --target-org uat-org          # Run Apex tests, report coverage
/org-diff --source dev-org --target uat-org  # Diff metadata between two orgs
```

### Quality Commands

```bash
/pmd-scan                                # PMD static analysis (fails on High/Critical)
/code-analyzer                           # Full scan: PMD + ESLint + RetireJS + DFA
/lint-fix                                # Auto-fix ESLint + Prettier across force-app
/lwc-test                                # Jest tests with coverage report
```

### Security Commands

```bash
/security-review                         # Security audit of current branch changes
/security-review --diff-against main     # Audit only what changed vs main
```

### Audit Commands

```bash
/audit-org --target-org prod-org --days 30      # Full org compliance audit
/audit-event-logs --event-type ReportExport --days 7   # Event monitoring analysis
/audit-login-history --days 30                  # Login anomaly report
```

### Architecture & Design Commands

```bash
/architect-review --scope all            # Full architecture review
/architect-review --scope data-model     # Data model review only
/designer-review                         # SLDS + accessibility review of all LWC
/designer-review --target lwc/myComponent --wcag   # WCAG 2.1 AA strict check
```

---

## 🔍 Audit & Compliance

This workspace ships with a complete **org audit toolkit** powered by the `org-auditor` agent and the `salesforce-audit` plugin.

### Event Monitoring

Query Salesforce Event Log Files for security investigations. Requires the **Event Monitoring add-on** (included in Performance/Unlimited editions).

```bash
# Run full event log analysis (last 7 days, high-risk event types)
/audit-event-logs --target-org prod-org --days 7

# Target a specific event type
/audit-event-logs --event-type ReportExport --days 30

# Use the tool script directly
.claude/tools/event-log-query.sh --target-org prod-org --event-type "ReportExport,DataExport" --days 7
```

**High-priority event types monitored:**

| Event Type | Risk Signal |
|-----------|-------------|
| `ReportExport` | Data exfiltration — who exported what and how many rows |
| `DataExport` | Full org data exports |
| `ListViewExport` | Bulk list view exports |
| `Login` | Authentication anomalies, failed attempts, unusual IPs |
| `PermissionSetAssignment` | Privilege escalation |
| `UserCreation` | Unauthorized admin/integration user creation |
| `ConnectedApp` | OAuth token issuance |
| `ApexUnexpectedException` | Production errors |

### Login History Analysis

No add-on required. 6 months of data available via SOQL.

```bash
/audit-login-history --target-org prod-org --days 30

# Per-user investigation
/audit-login-history --user suspicious.user@company.com --days 90

# Shell script for bulk export
.claude/tools/login-history-report.sh --target-org prod-org --days 30
```

**Anomalies detected:**
- Failed login spikes (brute force)
- Off-hours and weekend logins
- Concurrent sessions >5 (credential sharing signal)
- API/OAuth logins by non-integration accounts
- MFA verification failures
- Logins from new countries (geographic anomaly)

### SetupAuditTrail

180 days of admin change history, queried automatically in `/audit-org`.

```
🚨 Immediate red flags:
  • Apex/Flow changes in production by non-CI users
  • ModifyAllData granted via profile or permission set
  • Session timeout extended / MFA disabled
  • New System Administrator created
  • Named Credential endpoint changed
  • Data Export triggered outside scheduled window
```

### User Access Review (UAR)

```bash
/audit-org --target-org prod-org --days 30
```

Produces a full UAR covering:
- All active users with profile, role, and last login
- Users inactive for 90+ days (license reclamation)
- Users with `ModifyAllData` or `ViewAllData` (any source)
- Service account inventory
- Permission set assignments with blast-radius analysis

### Org Health Dashboard

```bash
.claude/tools/org-health-report.sh --target-org prod-org
# Output: reports/org-health-YYYYMMDD/health-report.md
```

Checks: governor limit consumption, storage, Apex coverage, failed batch jobs, Flow interview errors, stale users, unused permission sets.

---

## 🚀 DevOps & Deployment

### Pipeline

```
Feature branch → Scratch org (dev + CI tests)
                      ↓ PR merge
              Developer Sandbox
                      ↓
              UAT Sandbox (uat-org)
                      ↓ Release approval
              Production (prod-org)
```

### Common Deployment Commands

```bash
# Validate without deploying (produces Job ID for quick deploy)
sf project deploy validate \
  --manifest manifest/package.xml \
  --target-org uat-org \
  --test-level RunLocalTests \
  --wait 30

# Quick deploy to production (reuses validation job)
sf project deploy quick --job-id <JOB_ID> --target-org prod-org

# Diff metadata between orgs before deploying
/org-diff --source dev-org --target uat-org
```

### Scratch Org Workflow

```bash
# Create, deploy, test, and tear down a scratch org
sf org create scratch -f config/project-scratch-def.json -a my-scratch -y 7
sf project deploy start -o my-scratch
sf apex run test -o my-scratch -c -r human
sf org delete scratch -o my-scratch -p

# Or let the tool script manage rotation
.claude/tools/scratch-org-rotate.sh
```

### Pre-Deploy Safety Gates

Two hooks run automatically before every deployment:

1. **`pre-deploy-check`** — blocks production deploys unless `PROD_DEPLOY_CONFIRMED=1` is set
2. **`pre-deploy-pmd`** — blocks deploys on any PMD High/Critical finding (override: `PMD_OVERRIDE=1`)

```bash
# Confirm production deploy
PROD_DEPLOY_CONFIRMED=1 sf project deploy start --manifest manifest/package.xml --target-org prod-org
```

### Release Manager Checklist

Use the `/release-manager` agent or `/architect-review` for structured release planning. Every release should produce:

```
Release Notes — YYYY-MM-DD
  Deployment window: <UTC range>
  Changes: <user-facing bullet list>
  Technical changes: <components>
  Rollback plan: <steps by change type>
  Testing sign-off: <UAT approver>
  Go/no-go: <name + time>
```

---

## 🎨 Design & Architecture

### UX Design Review

```bash
# Full SLDS + accessibility review
/designer-review

# Strict WCAG 2.1 AA mode
/designer-review --wcag

# Single component
/designer-review --target force-app/main/default/lwc/accountCard
```

The `ux-designer` agent checks:
- SLDS utility class usage (flag raw hex colors, hardcoded margins)
- WCAG 2.1 AA: color contrast, focus rings, keyboard navigation, ARIA labels
- Experience Cloud property panel `targetConfigs` design
- LWC loading / error / empty state patterns
- Mobile responsiveness (SLDS grid, no fixed pixel widths)

### Architecture Review

```bash
# Full architecture review
/architect-review --scope all --target-org prod-org

# Specific scope
/architect-review --scope integrations
/architect-review --scope data-model
/architect-review --scope org-strategy
```

The `solution-architect` agent checks:
- Object field density (flag >500 fields, warn at >400)
- Governor limit exposure (SOQL in loops, missing bulkification)
- Integration pattern fit (sync vs async, Bulk API 2.0 for large datasets)
- Named Credential coverage (hardcoded endpoints are a blocker)
- Platform Event idempotency
- Package architecture alignment

**Architecture decision records** are produced automatically for structural recommendations.

---

## 🛡️ Security Review

Run a security audit on any branch or set of changed files:

```bash
# Audit current branch changes vs main
/security-review

# Audit specific diff
/security-review --diff-against release/2025-Q2

# Full org metadata security audit
/audit-org --target-org prod-org
```

### What gets checked

**Apex:**
| Check | Tool |
|-------|------|
| CRUD/FLS bypass | PMD DFA + `security-reviewer` agent |
| SOQL/SOSL injection | PMD + manual review |
| Hardcoded IDs / endpoints | PMD + grep |
| `@AuraEnabled` entry points | Static analysis |
| `without sharing` justification | Code review |

**LWC:**
| Check | Tool |
|-------|------|
| `lwc:dom="manual"` / `innerHTML` | ESLint + grep |
| Unvalidated `@api` HTML | Code review |
| Direct `fetch()` to external origins | ESLint |

**Metadata:**
| Check | Tool |
|-------|------|
| `ModifyAllData` / `ViewAllData` on non-admin profiles | `metadata-audit` skill |
| Public R/W OWD on custom objects | Tooling API |
| Guest user object access | SOQL + metadata |
| Connected App OAuth scopes | Metadata XML |

**Output format:**

| Severity | File:Line | Category | Finding | Recommendation |
|----------|-----------|----------|---------|----------------|
| Critical | ... | CRUD/FLS | ... | ... |

Exit code is non-zero on any **Critical** or **High** finding — wire directly into CI.

---

## 🧪 Testing

### Run Apex Tests

```bash
# Run all local tests and report coverage
/run-tests --target-org uat-org

# Run specific class
sf apex run test --class-names AccountService_Test --target-org uat-org -c -r human

# Run via CLI
sf apex run test -o uat-org --test-level RunLocalTests --code-coverage -r human
```

### LWC Jest Tests

```bash
# Run Jest with coverage
/lwc-test

# Run with coverage threshold
npm run test:unit -- --coverage --coverageThreshold='{"global":{"lines":80}}'
```

### Test Data Factories

The `test-engineer` agent generates `@TestSetup`-based factories:

```apex
// Generated pattern
@TestSetup
static void makeData() {
    Account acc = TestDataFactory.createAccount('Acme Corp');
    Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
}
```

### Coverage Gate

CI pipeline fails at < 75% org-wide coverage. PMD High/Critical findings also fail the pipeline.

```yaml
# Example CI gate
- name: Run Apex Tests
  run: sf apex run test -o ${{ env.SF_USERNAME }} --test-level RunLocalTests --code-coverage -r tap
  env:
    SFDX_DISABLE_TELEMETRY: true
```

---

## 🔁 Hooks & Automation

Hooks run automatically in response to Claude Code events. No manual invocation needed.

| Hook | Trigger | What it does |
|------|---------|-------------|
| `post-edit-format` | After every Edit/Write | Auto-formats Apex, LWC, and XML via Prettier |
| `post-edit-pmd-quick` | After editing `.cls`/`.trigger` | Single-file PMD check, surfaces High/Critical inline |
| `pre-deploy-check` | Before any `sf project deploy` | Blocks production deploys without confirmation env var |
| `pre-deploy-pmd` | Before any `sf project deploy` | Blocks deploys on PMD High/Critical findings |
| `stop-summary` | At end of each Claude session | Appends session log (files edited, tests run, deploys) |

### Session Log

Every Claude Code session appends to `.claude/session.log`:

```
2026-05-07 14:32 — Files: AccountService.cls, AccountService_Test.cls
  Tests run: RunLocalTests → PASSED (82% coverage)
  Deploy: validate → uat-org → SUCCESS
```

---

## 🔌 Plugins

Plugins bundle related agents, skills, commands, hooks, and tools into cohesive team packages.

### `salesforce-devops`
**For:** DevOps engineers, release managers, CI/CD pipelines

Includes: `devops-engineer`, `integration-specialist`, `release-manager` agents · `sfdx-deploy`, `anonymous-apex`, `soql-query`, `debug-log` skills · `org-diff`, `create-apex-class` commands · `pre-deploy-check` hook · `scratch-org-rotate.sh` tool

### `salesforce-quality`
**For:** Developers, testers, PMD analysts, security reviewers

Includes: `security-reviewer`, `pmd-analyst`, `test-engineer`, `org-auditor` agents · `pmd-scan`, `code-analyzer`, `eslint-lint`, `prettier-format`, `lwc-jest` skills · `security-review`, `pmd-scan`, `code-analyzer`, `lint-fix`, `lwc-test`, `run-tests` commands · `pre-deploy-pmd`, `post-edit-pmd-quick`, `post-edit-format` hooks

### `salesforce-design`
**For:** UX designers, front-end developers, solution architects

Includes: `ux-designer`, `solution-architect`, `lwc-developer`, `flow-architect` agents · `designer-review`, `architect-review` commands · `post-edit-format` hook

### `salesforce-audit`
**For:** Security teams, compliance, internal audit, InfoSec

Includes: `org-auditor`, `security-reviewer` agents · all 6 audit skills · `audit-org`, `audit-event-logs`, `audit-login-history`, `security-review` commands · `event-log-query.sh`, `login-history-report.sh`, `org-health-report.sh` tools

---

## 🔧 MCP Integrations

MCP (Model Context Protocol) servers extend Claude Code with external tool access. Configuration templates are in `.claude/mcp/`.

| Server | File | Purpose |
|--------|------|---------|
| Salesforce MCP | `sfdc.json.example` | Direct SOQL queries, org describe, metadata deploys |
| GitHub MCP | `github.json.example` | Issues, PRs, code search without leaving Claude |
| Filesystem MCP | `filesystem.json.example` | Sandboxed read access to design docs folder |
| Postgres MCP | `postgres.json.example` | Query reporting databases (analytics, data warehouse) |

To activate an MCP server, copy the `.example` file, fill in credentials, and add to `~/.claude/mcp_servers.json`.

---

## 📁 Project Structure

```
sfdc2/
├── force-app/
│   └── main/default/
│       ├── classes/
│       │   ├── TriggerHandler.cls          # Base trigger handler (virtual, 7 event methods)
│       │   ├── AccountService.cls          # Service layer — bulk-safe, with sharing
│       │   ├── AccountService_Test.cls
│       │   └── AccountTriggerHandler.cls   # Extends TriggerHandler
│       └── triggers/
│           └── AccountTrigger.trigger      # Thin trigger — delegates to handler
│
├── manifest/
│   └── package.xml                         # Release manifest
│
├── config/
│   └── project-scratch-def.json            # Scratch org definition
│
├── .claude/
│   ├── agents/           # 12 AI specialist personas
│   │   ├── apex-developer.md
│   │   ├── devops-engineer.md
│   │   ├── flow-architect.md
│   │   ├── integration-specialist.md
│   │   ├── lwc-developer.md
│   │   ├── org-auditor.md         ← NEW
│   │   ├── pmd-analyst.md
│   │   ├── release-manager.md     ← NEW
│   │   ├── security-reviewer.md
│   │   ├── solution-architect.md  ← NEW
│   │   ├── test-engineer.md
│   │   └── ux-designer.md         ← NEW
│   │
│   ├── skills/           # 15 parameterized capabilities
│   │   ├── anonymous-apex.md
│   │   ├── code-analyzer.md
│   │   ├── debug-log.md
│   │   ├── eslint-lint.md
│   │   ├── event-log-query.md     ← NEW
│   │   ├── login-history-query.md ← NEW
│   │   ├── lwc-jest.md
│   │   ├── metadata-audit.md      ← NEW
│   │   ├── org-health-check.md    ← NEW
│   │   ├── pmd-scan.md
│   │   ├── prettier-format.md
│   │   ├── setup-audit-trail.md   ← NEW
│   │   ├── sfdx-deploy.md
│   │   ├── soql-query.md
│   │   └── user-access-audit.md   ← NEW
│   │
│   ├── commands/         # 13 slash commands
│   │   ├── architect-review.md    ← NEW
│   │   ├── audit-event-logs.md    ← NEW
│   │   ├── audit-login-history.md ← NEW
│   │   ├── audit-org.md           ← NEW
│   │   ├── code-analyzer.md
│   │   ├── create-apex-class.md
│   │   ├── designer-review.md     ← NEW
│   │   ├── lint-fix.md
│   │   ├── lwc-test.md
│   │   ├── org-diff.md
│   │   ├── pmd-scan.md
│   │   ├── run-tests.md
│   │   └── security-review.md
│   │
│   ├── hooks/            # 5 automated quality gates
│   │   ├── post-edit-format.md
│   │   ├── post-edit-pmd-quick.md
│   │   ├── pre-deploy-check.md
│   │   ├── pre-deploy-pmd.md
│   │   └── stop-summary.md
│   │
│   ├── plugins/          # 4 team bundles
│   │   ├── salesforce-audit/      ← NEW
│   │   ├── salesforce-design/     ← NEW
│   │   ├── salesforce-devops/
│   │   └── salesforce-quality/
│   │
│   ├── tools/            # Shell utility scripts
│   │   ├── event-log-query.sh     ← NEW
│   │   ├── login-history-report.sh ← NEW
│   │   ├── org-health-report.sh   ← NEW
│   │   ├── pmd-run.sh
│   │   ├── post-edit-format.sh
│   │   ├── post-edit-pmd-quick.sh
│   │   ├── pre-deploy-check.sh
│   │   ├── pre-deploy-pmd.sh
│   │   ├── scanner-summary.sh
│   │   └── scratch-org-rotate.sh
│   │
│   ├── mcp/              # MCP server config templates
│   │   ├── sfdc.json.example
│   │   ├── github.json.example
│   │   ├── filesystem.json.example
│   │   └── postgres.json.example
│   │
│   └── settings.local.json   # Project-scoped permissions
│
├── sfdx-project.json
├── package.json
├── eslint.config.js
└── jest.config.js
```

---

## 🏁 Getting Started

### Prerequisites

```bash
# Salesforce CLI
npm install -g @salesforce/cli

# Salesforce Code Analyzer (for /security-review and /pmd-scan)
sf plugins install @salesforce/sfdx-scanner

# Node deps (ESLint, Jest, Prettier)
npm install

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
```

### Authenticate to orgs

```bash
sf org login web --alias prod-org --instance-url https://login.salesforce.com
sf org login web --alias uat-org  --instance-url https://test.salesforce.com
```

### Launch Claude Code

```bash
# In this project directory
claude

# Or with a specific task
claude "Review the AccountService class for security issues"
```

### First commands to try

```bash
# See what you've got
/org-diff --source dev-org --target uat-org

# Check org health
/audit-org --target-org prod-org --days 30

# Quality gate
/code-analyzer

# Security scan
/security-review
```

---

## 💡 Pro Tips

- **Let Claude route**: describe what you need naturally — "review this Apex class for security issues" will automatically engage the `security-reviewer` agent without you needing to specify it.
- **Chain commands**: `/security-review` → `/run-tests` → `/org-diff` forms a complete pre-deploy validation pipeline.
- **Audit before releases**: always run `/audit-event-logs` and `/audit-login-history` after a production deployment window to verify no unexpected activity occurred during the change window.
- **Hooks are silent guardrails**: `post-edit-pmd-quick` catches High/Critical findings immediately on save so you don't find them at CI time.
- **PROD_DEPLOY_CONFIRMED=1** is required for production deploys — this is intentional. Set it explicitly, never in `.env` files committed to git.

---

## 📚 References

| Resource | Link |
|----------|------|
| Salesforce CLI Reference | [developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/) |
| Salesforce Secure Coding Guide | [developer.salesforce.com/docs/.../secure_coding_guide](https://developer.salesforce.com/docs/atlas.en-us.secure_coding_guide.meta/secure_coding_guide/) |
| Lightning Design System | [lightningdesignsystem.com](https://www.lightningdesignsystem.com) |
| WCAG 2.1 AA | [w3.org/WAI/WCAG21/quickref](https://www.w3.org/WAI/WCAG21/quickref/) |
| Salesforce Code Analyzer | [forcedotcom.github.io/sfdx-scanner](https://forcedotcom.github.io/sfdx-scanner/) |
| Event Monitoring | [trailhead.salesforce.com/content/learn/modules/event_monitoring](https://trailhead.salesforce.com/content/learn/modules/event_monitoring) |
| Claude Code Docs | [docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code) |

---

<div align="center">

**Built with ⚡ Claude Code × Salesforce**

*12 agents · 15 skills · 13 commands · 4 plugins · 5 hooks*

</div>
