---
name: pre-deploy-check
event: PreToolUse
matcher: Bash
description: Block production deploys without explicit confirmation. Runs before any Bash tool call that looks like a Salesforce deployment.
---

# pre-deploy-check (PreToolUse Hook)

This hook intercepts `Bash` tool calls and inspects the command for deploy patterns.

## Match patterns

- `sf project deploy start`
- `sfdx force:source:deploy`
- `sf project deploy validate` (allow — validation only)

## Logic

If the command targets the production alias (`--target-org prod-org` or default org is prod):

1. **Block** the tool call.
2. Emit a message: `"Production deploy detected. Confirm with the user before proceeding and re-issue the command with PROD_DEPLOY_CONFIRMED=1 in the environment."`
3. If `PROD_DEPLOY_CONFIRMED=1` is present in the environment, allow.

Otherwise: allow.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/pre-deploy-check.sh" }
        ]
      }
    ]
  }
}
```

## Implementation reference

The companion shell script reads the tool input from stdin (JSON), greps for deploy commands targeting prod, and exits with code 2 to block.
