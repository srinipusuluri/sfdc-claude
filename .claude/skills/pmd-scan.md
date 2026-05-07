---
name: pmd-scan
description: Run PMD against Apex source and report findings. Use when the user asks to lint, static-analyze, or PMD-scan Apex code.
---

# pmd-scan

Run PMD via the Salesforce Code Analyzer (preferred) or standalone PMD CLI.

## Preferred: via Salesforce Code Analyzer

```bash
sf scanner run \
  --target "force-app/**/*.cls,force-app/**/*.trigger" \
  --engine pmd \
  --pmdconfig .pmdruleset.xml \
  --format sarif \
  --outfile reports/pmd.sarif
```

For deep cross-method analysis (CRUD/FLS leaks):
```bash
sf scanner run dfa \
  --target force-app \
  --projectdir . \
  --format sarif \
  --outfile reports/pmd-dfa.sarif
```

## Standalone PMD CLI

```bash
pmd check \
  -d force-app \
  -R .pmdruleset.xml \
  -f sarif \
  -r reports/pmd.sarif
```

## Output processing

After the scan, summarize:

1. **Total findings** by severity (Critical / High / Medium / Low).
2. **Top 5 rules** by count.
3. **Files with the most findings** (top 10).
4. **New findings since the last run** (diff against `reports/pmd.sarif.previous`).

## Failure thresholds

- Exit non-zero if any **Critical** or **High** finding exists.
- Always fail on `ApexCRUDViolation`, `ApexSOQLInjection`, `ApexSharingViolations`, regardless of severity tag.

## Ruleset

The project ruleset lives at `.pmdruleset.xml`. If missing, scaffold it from `apex-best-practices`, `apex-security`, `apex-performance`, `apex-design`. See the `pmd-analyst` agent for tuning guidance.
