---
description: Run Apex tests in a target org and report coverage
argument-hint: [--target-org <alias>] [--class-names <Class1,Class2>]
---

Execute Apex tests and produce a coverage report.

## Default behavior

Run all local tests in the default org:
```bash
sf apex run test --result-format human --code-coverage --wait 20
```

## With arguments

- `--target-org <alias>` — run against a specific org
- `--class-names <Class1,Class2>` — run only specified test classes
- `--test-level RunLocalTests|RunAllTestsInOrg|RunSpecifiedTests`

## Report format

After tests complete, output:

1. **Pass/fail summary** — total, passed, failed, time
2. **Failed tests** — class, method, message, stack trace
3. **Coverage** — overall % and per-class % for any class < 75%
4. **Slowest tests** — top 5 by duration

If any test fails or coverage is < 75%, exit non-zero so this can be wired into CI.
