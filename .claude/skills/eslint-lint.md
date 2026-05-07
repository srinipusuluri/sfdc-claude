---
name: eslint-lint
description: Run ESLint over LWC and Aura JS in the project. Use when the user wants to lint, fix style issues, or check LWC code quality.
---

# eslint-lint

Lint JS/TS in `force-app` using ESLint with the Salesforce LWC plugin.

## Config

The project uses flat config at `eslint.config.js` (already present). It pulls in:
- `@salesforce/eslint-config-lwc/recommended`
- `@salesforce/eslint-plugin-lwc`
- `@salesforce/eslint-plugin-aura` (if any Aura components remain)

## Run

```bash
npx eslint force-app --ext .js
```

With auto-fix:
```bash
npx eslint force-app --ext .js --fix
```

CI-friendly with SARIF:
```bash
npx eslint force-app --ext .js --format @microsoft/eslint-formatter-sarif --output-file reports/eslint.sarif
```

## Important rules to keep on

- `@lwc/lwc/no-document-query` — forces `template.querySelector`.
- `@lwc/lwc/no-async-await` — async handling has gotchas in Salesforce; the rule warns; allow with comment when needed.
- `@lwc/lwc/no-inner-html` — XSS risk. **Never disable globally.**
- `no-eval`, `no-implied-eval` — non-negotiable.

## Pre-commit / hook integration

Pair with the `post-edit-format` hook to lint+fix on every Edit/Write under `force-app/**/*.js`. See `.claude/hooks/post-edit-format.md`.

## Failure handling

If lint fails, prefer `--fix` first. For findings that can't be auto-fixed, output a list grouped by rule with file:line. Don't suppress with `// eslint-disable-next-line` unless the alternative is clearly worse — and add a comment explaining why.
