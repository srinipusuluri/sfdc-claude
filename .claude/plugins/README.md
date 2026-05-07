# .claude/plugins/ — Claude Code plugins

Plugins bundle agents, skills, commands, and hooks together so they can be installed as a unit. Each plugin lives in its own subfolder with a `plugin.json` manifest.

## Layout

```
.claude/plugins/
├── README.md              # this file
├── salesforce-quality/    # security, PMD, lint, format bundle
│   └── plugin.json
└── salesforce-devops/     # scratch orgs, packaging, release bundle
    └── plugin.json
```

## Manifest format

```json
{
  "name": "salesforce-quality",
  "version": "0.1.0",
  "description": "Static analysis, lint, format, and security review for Salesforce projects",
  "agents": ["security-reviewer", "pmd-analyst", "test-engineer"],
  "skills": ["pmd-scan", "code-analyzer", "eslint-lint", "prettier-format"],
  "commands": ["security-review", "pmd-scan", "code-analyzer", "lint-fix"],
  "hooks": ["pre-deploy-pmd", "post-edit-pmd-quick", "post-edit-format"]
}
```

The names reference files in the sibling `agents/`, `skills/`, `commands/`, `hooks/` folders. A plugin doesn't duplicate content — it groups references for sharing.

## Installing a plugin from elsewhere

1. Drop the plugin folder under `.claude/plugins/`.
2. Copy the referenced `.md` files into the matching top-level folders (or symlink them).
3. Restart Claude Code so it picks up the new agents/skills/commands.
4. For hooks, append the wiring blocks from each hook file into `.claude/settings.json`.

## Sharing a plugin

Push the plugin folder + the referenced `.md` files to a git repo. Consumers clone it under their `.claude/plugins/` and follow the install steps above.
