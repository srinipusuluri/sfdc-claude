---
name: stop-summary
event: Stop
description: After Claude finishes a turn, append a one-line entry to a session log noting what was changed. Useful for retroactive PR descriptions.
---

# stop-summary (Stop Hook)

Runs once when Claude finishes responding (the `Stop` event).

## Behavior

1. Read the latest transcript turn from `$CLAUDE_TRANSCRIPT_PATH`.
2. Extract:
   - Files modified (from Edit/Write tool calls)
   - Tests run (from Bash calls matching `sf apex run test`)
   - Deploys attempted (from Bash calls matching `sf project deploy`)
3. Append one line per turn to `.claude/session.log`:
   ```
   2026-05-07T14:32:11Z | edited: AccountTriggerHandler.cls, AccountTriggerHandler_Test.cls | tests: 12 passed | deploy: validated against uat-org
   ```

## Why a hook (not memory)

This is per-session ephemeral state, not something that should persist across conversations. Memory would be wrong; a session log is right.

## Wiring (settings.json)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/stop-summary.sh" }
        ]
      }
    ]
  }
}
```
