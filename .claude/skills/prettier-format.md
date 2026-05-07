---
name: prettier-format
description: Format Apex, LWC, and metadata XML with Prettier. Use when the user wants to format, beautify, or normalize whitespace in source files.
---

# prettier-format

Format source under `force-app/` with Prettier and `prettier-plugin-apex`.

## One-time setup

```bash
npm install --save-dev prettier prettier-plugin-apex
```

`.prettierrc` (project default):
```json
{
  "trailingComma": "none",
  "overrides": [
    {
      "files": "*.{cls,trigger,apex}",
      "options": { "parser": "apex", "printWidth": 120, "tabWidth": 4 }
    },
    {
      "files": "*.{cmp,page,component,evt,html}",
      "options": { "parser": "html" }
    }
  ]
}
```

## Run

Format everything:
```bash
npx prettier --write 'force-app/**/*.{cls,trigger,html,js,css,xml,json}'
```

Check only (CI):
```bash
npx prettier --check 'force-app/**/*.{cls,trigger,html,js,css}'
```

Format a single file (typical hook use):
```bash
npx prettier --write force-app/main/default/classes/AccountService.cls
```

## What it covers

| Pattern | Parser |
|---------|--------|
| `*.cls`, `*.trigger`, `*.apex` | `prettier-plugin-apex` |
| `*.html` (LWC, Aura, VF) | built-in HTML |
| `*.js`, `*.css` | built-in |
| `*.xml` (metadata) | `@prettier/plugin-xml` (install if you want metadata formatted) |

## Hook integration

The `post-edit-format` hook calls Prettier on every Edit/Write under `force-app/`. See `.claude/hooks/post-edit-format.md`.

## When to skip

Generated files (`*-meta.xml` from `sf` retrievals can have ordering quirks) — the hook should skip these or run with `--ignore-path .prettierignore`.
