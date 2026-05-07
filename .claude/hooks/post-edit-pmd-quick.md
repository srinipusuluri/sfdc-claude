---
name: post-edit-pmd-quick
event: PostToolUse
matcher: Edit|Write
description: Run a fast PMD check on a single Apex file after every Edit/Write so issues surface immediately, not at deploy time.
---

# post-edit-pmd-quick (PostToolUse Hook)

After Claude edits or writes a `.cls` or `.trigger` file under `force-app/`, run PMD just on that file. Surface High/Critical findings immediately.

## Behavior

1. Read the modified path from the hook payload.
2. Skip unless the path matches `force-app/**/*.{cls,trigger}`.
3. Run:
   ```bash
   sf scanner run \
     --target "<path>" \
     --engine pmd \
     --pmdconfig .pmdruleset.xml \
     --severity-threshold 3 \
     --format table
   ```
4. If findings: append the table to the transcript as a system message so Claude (and the user) sees them in-line. Do not block the edit — surface, don't gate. The `pre-deploy-pmd` hook is the gate.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit-pmd-quick.sh" }
        ]
      }
    ]
  }
}
```

## Performance

PMD on a single file is sub-second; the Code Analyzer wrapper adds ~2 s of plugin warm-up. If that's too slow, fall back to invoking PMD's CLI directly:

```bash
pmd check -d "<path>" -R .pmdruleset.xml -f text --no-progress
```

## Failure mode

If the scanner errors (missing ruleset, plugin not installed), exit 0 with a warning. Don't block the user's flow on tooling problems.
