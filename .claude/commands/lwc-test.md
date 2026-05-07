---
description: Run LWC Jest tests with coverage.
argument-hint: [--watch] [--coverage] [--testPathPattern <regex>]
---

Run Jest unit tests for LWC bundles.

## Default

```bash
npm run test:unit -- --coverage --ci
```

## With arguments

- `--watch` — interactive watch mode (`npm run test:unit:watch`).
- `--coverage` — emit coverage to `coverage/lcov-report/`.
- `--testPathPattern <regex>` — run only matching test files.
- `--debug` — attach the Node inspector for breakpoint debugging.

## Output

1. **Pass/fail counts** — total / passed / failed / skipped.
2. **Failed tests** — file, suite, message, stack snippet.
3. **Coverage** — overall %, plus per-bundle % for any bundle below 80%.

## Exit code

Non-zero on any test failure or coverage drop below 80% per-component (configurable via `jest.config.js`).

## Common issues

- Missing virtual mock for a `@salesforce/...` import → see `.claude/skills/lwc-jest.md` for mock patterns.
- `refreshApex` import error → ensure `@salesforce/sfdx-lwc-jest` is installed and `jest.config.js` extends `@lwc/jest-preset`.
