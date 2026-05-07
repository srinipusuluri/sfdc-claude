---
description: Run PMD against Apex source and report findings.
argument-hint: [--target <path>] [--ruleset <file>] [--severity-threshold <1-5>]
---

Run PMD via Salesforce Code Analyzer.

## Default

```bash
sf scanner run \
  --target "force-app/**/*.cls,force-app/**/*.trigger" \
  --engine pmd \
  --pmdconfig "${RULESET:-.pmdruleset.xml}" \
  --severity-threshold 3 \
  --format table
```

If `.pmdruleset.xml` is missing, scaffold it from `apex-best-practices`, `apex-security`, `apex-performance`, `apex-design` and warn the user.

## With arguments

- `--target <path>` — scan a specific file or glob.
- `--ruleset <file>` — use an alternate ruleset.
- `--severity-threshold <N>` — exit non-zero when findings ≥ N (1=Critical … 5=Low). Default 3.

## Output

1. **Total findings** by severity.
2. **Top 5 rules** triggered, with counts.
3. **Files with most findings** (top 10).
4. Full list grouped by file.

## Exit code

Non-zero when findings at the threshold exist or any of these rules fire (always blocking, regardless of threshold):
- `ApexCRUDViolation`
- `ApexSOQLInjection`
- `ApexSharingViolations`
- `ApexBadCrypto`
- `ApexInsecureEndpoint`
