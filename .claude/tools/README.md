# .claude/tools/ — utility scripts

Wrappers, helpers, and CI-glue scripts that the agents, skills, commands, and hooks call. Keeping them in one folder makes the wiring (paths in settings.json hook blocks, command bodies) consistent.

## Conventions

- Scripts are POSIX-shell compatible (`#!/usr/bin/env bash`, `set -euo pipefail`).
- All scripts read input from environment variables or stdin (JSON, for hook payloads), never positional args alone.
- Scripts are idempotent and safe to re-run.
- Exit codes:
  - `0` — success / allow
  - `1` — generic failure
  - `2` — block (used by PreToolUse hooks)

## Index

| Script | Used by | Purpose |
|--------|---------|---------|
| `pmd-run.sh` | `pmd-scan` skill, `pre-deploy-pmd` hook, `post-edit-pmd-quick` hook | Run Code Analyzer / PMD with the project ruleset, return SARIF |
| `scanner-summary.sh` | `code-analyzer` command | Parse a SARIF file into a human-readable table grouped by engine |
| `pre-deploy-pmd.sh` | `pre-deploy-pmd` hook | Reads tool-input JSON from stdin, runs PMD if a deploy is detected, exits 2 to block on findings |
| `post-edit-format.sh` | `post-edit-format` hook | Routes by extension to Prettier / xmllint |
| `post-edit-pmd-quick.sh` | `post-edit-pmd-quick` hook | Runs a one-file PMD scan and surfaces findings inline |
| `pre-deploy-check.sh` | `pre-deploy-check` hook | Blocks production deploys lacking explicit confirmation |
| `stop-summary.sh` | `stop-summary` hook | Appends a one-line session log on Stop |
| `scratch-org-rotate.sh` | `devops-engineer` agent | Deletes expired scratch orgs and creates a fresh one |

## Adding a new script

1. Create the script with `chmod +x`.
2. Reference it from the relevant skill/command/hook `.md` body.
3. Update the index above.
