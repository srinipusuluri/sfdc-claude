---
name: code-analyzer
description: Run Salesforce Code Analyzer (sf scanner) — multi-engine static analysis covering Apex, LWC, dependencies, and CRUD/FLS data flow. Use when the user wants a full code-quality scan.
---

# code-analyzer

Salesforce Code Analyzer wraps PMD, ESLint (with `@salesforce/eslint-plugin-lwc`), RetireJS, and CPD into one CLI plus a graph-based DFA engine for Apex.

## Install

```bash
sf plugins install @salesforce/sfdx-scanner
sf scanner --version
```

## Common runs

**Full scan, all engines:**
```bash
sf scanner run \
  --target force-app \
  --engine pmd,eslint,eslint-lwc,retire-js,cpd \
  --format sarif \
  --outfile reports/scanner.sarif
```

**DFA scan (Apex CRUD/FLS data flow — slower, deeper):**
```bash
sf scanner run dfa \
  --target force-app \
  --projectdir . \
  --rule-thread-count 4 \
  --format sarif \
  --outfile reports/scanner-dfa.sarif
```

**Apex-only quick scan during development:**
```bash
sf scanner run \
  --target "force-app/**/*.cls,force-app/**/*.trigger" \
  --engine pmd \
  --severity-threshold 3
```

## Severity thresholds

`--severity-threshold` exits non-zero when findings ≥ N exist. Use `3` (High) for CI gating.

## Engines

| Engine | Covers | Notes |
|--------|--------|-------|
| `pmd` | Apex `.cls`/`.trigger`, Visualforce | Tune via `.pmdruleset.xml` |
| `eslint` | JS in `force-app` (LWC, Aura controllers) | |
| `eslint-lwc` | LWC-specific rules (`@lwc/lwc/no-deprecated-...`) | |
| `retire-js` | Vulnerable JS libraries in static resources | |
| `cpd` | Copy-paste detection | Useful for refactor candidates |
| `sfge` (DFA) | Apex graph data-flow | Catches CRUD/FLS across method boundaries |

## Output

SARIF can be uploaded to GitHub code scanning. For a human read, also produce `--format table`.
