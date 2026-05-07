---
description: Run the full Salesforce Code Analyzer (sf scanner) — PMD, ESLint, LWC rules, retire-js, CPD, and Apex DFA.
argument-hint: [--dfa] [--target <path>] [--severity-threshold <1-5>]
---

Run a full multi-engine static analysis over `force-app/`.

## Default

```bash
sf scanner run \
  --target "${TARGET:-force-app}" \
  --engine pmd,eslint,eslint-lwc,retire-js,cpd \
  --severity-threshold "${SEVERITY:-3}" \
  --format sarif \
  --outfile reports/scanner.sarif
```

Then summarize the SARIF as a table grouped by engine.

## With `--dfa`

Add a second pass with the Apex Graph engine (slower, deeper):
```bash
sf scanner run dfa \
  --target "${TARGET:-force-app}" \
  --projectdir . \
  --rule-thread-count 4 \
  --severity-threshold "${SEVERITY:-3}" \
  --format sarif \
  --outfile reports/scanner-dfa.sarif
```

## Pre-flight

If `sf scanner` is not installed:
```bash
sf plugins install @salesforce/sfdx-scanner
```

## Output

| Engine | Critical | High | Medium | Low |
|--------|----------|------|--------|-----|

Followed by the top 10 findings across all engines.

## Exit code

Non-zero if any engine returns ≥ severity threshold. Wire into CI as a required check.
