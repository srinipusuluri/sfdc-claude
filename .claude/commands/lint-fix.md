---
description: Run ESLint and Prettier across force-app, auto-fixing what can be fixed.
argument-hint: [--check] [--path <glob>]
---

Lint and format the project.

## Default (auto-fix)

```bash
npx eslint "${PATH:-force-app}" --ext .js --fix
npx prettier --write "${PATH:-force-app}/**/*.{cls,trigger,html,js,css,xml,json}"
```

## `--check` (CI mode, no writes)

```bash
npx eslint "${PATH:-force-app}" --ext .js --max-warnings 0
npx prettier --check "${PATH:-force-app}/**/*.{cls,trigger,html,js,css}"
```

## Output

- Files modified by `--fix` / `--write` (when not in `--check` mode).
- Remaining ESLint findings grouped by rule.
- Prettier diff summary (file count, line count).

## Exit code

`--check` exits non-zero on any unresolved finding. Default mode exits zero unless ESLint hits an error it couldn't fix.
