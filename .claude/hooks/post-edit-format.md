---
name: post-edit-format
event: PostToolUse
matcher: Edit|Write
description: Auto-format Apex and LWC files after every Edit/Write. Keeps the codebase consistent without relying on Claude to remember.
---

# post-edit-format (PostToolUse Hook)

Runs after every successful Edit or Write tool call.

## Behavior

Inspect the file path that was written:

| Extension | Formatter |
|-----------|-----------|
| `.cls`, `.trigger` | `prettier --plugin=prettier-plugin-apex --write` |
| `.html`, `.js`, `.css` (under LWC bundle) | `prettier --write` |
| `.xml` (metadata) | `xmllint --format --output` |

Skip files outside `force-app/`.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit-format.sh" }
        ]
      }
    ]
  }
}
```

## Failure mode

If the formatter errors (syntax error in the file), the hook exits 0 and prints a warning. Do not block the edit — the user should see the syntax error and fix it.
