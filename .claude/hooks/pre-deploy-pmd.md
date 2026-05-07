---
name: pre-deploy-pmd
event: PreToolUse
matcher: Bash
description: Block deploys when PMD/Code Analyzer reports High or Critical findings on the source being deployed.
---

# pre-deploy-pmd (PreToolUse Hook)

Intercepts `Bash` tool calls and runs PMD before any deploy command is allowed through.

## Match patterns

- `sf project deploy start`
- `sf project deploy validate`
- `sfdx force:source:deploy`

## Logic

1. On match, run:
   ```bash
   sf scanner run \
     --target "force-app/**/*.cls,force-app/**/*.trigger" \
     --engine pmd \
     --pmdconfig .pmdruleset.xml \
     --severity-threshold 3
   ```
2. If exit code ≠ 0:
   - **Block** the deploy.
   - Emit: `"PMD found High/Critical issues. Run /pmd-scan, fix or document the findings, then re-issue the deploy with PMD_OVERRIDE=1 if a deliberate exception is required."`
3. If exit code = 0, allow.
4. If `PMD_OVERRIDE=1` is set in the environment, allow but emit a warning into the transcript.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/pre-deploy-pmd.sh" }
        ]
      }
    ]
  }
}
```

## Companion script

`.claude/hooks/pre-deploy-pmd.sh` reads the tool input from stdin (JSON), greps for deploy commands, runs the scanner only when matched, and exits with code 2 to block.

## Why a hook (not just trust the human)

Deploys are easy to fire reflexively. A hook makes the safety check unbypassable except by an explicit override env var, which leaves an audit trail in the transcript.
