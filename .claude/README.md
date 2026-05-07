# .claude/ — Salesforce Workspace Configuration

This folder configures Claude Code for Salesforce development in the `cl2` project.

## Structure

```
.claude/
├── README.md              # this file
├── agents/                # specialized subagents
│   ├── apex-developer.md
│   ├── lwc-developer.md
│   ├── flow-architect.md
│   └── integration-specialist.md
├── skills/                # invocable skills (/skill-name)
│   ├── sfdx-deploy.md
│   ├── soql-query.md
│   └── anonymous-apex.md
├── commands/              # custom slash commands
│   ├── create-apex-class.md
│   ├── org-diff.md
│   └── run-tests.md
└── hooks/                 # lifecycle hook definitions
    ├── pre-deploy-check.md
    ├── post-edit-format.md
    └── stop-summary.md
```

## How each piece is invoked

| Piece | Invocation |
|-------|-----------|
| Agent | `Use the apex-developer agent to refactor X` (Claude routes via the Agent tool) |
| Skill | `/sfdx-deploy` typed by the user, or Claude calls `Skill(skill="sfdx-deploy")` |
| Command | `/create-apex-class AccountService` typed by the user |
| Hook | Fires automatically on the configured event — no manual trigger |

## Activating hooks

The `.md` files under `hooks/` are documentation. To actually wire them up, add entries to `.claude/settings.json` (or `~/.claude/settings.json` for user-level). See each hook file for an example settings block.

## Extending

- Add a new agent: drop a `.md` file in `agents/` with frontmatter (`name`, `description`, `tools`, `model`).
- Add a new skill: drop a `.md` file in `skills/` with frontmatter (`name`, `description`).
- Add a new command: drop a `.md` file in `commands/` with frontmatter (`description`, `argument-hint`). The body is the prompt template.
