---
name: post-org-scan-report
event: PostToolUse
matcher: Bash
description: After org-scan.sh completes, generate a colour-coded HTML audit report in reports/ and print the file path to the transcript.
---

# post-org-scan-report (PostToolUse Hook)

## Trigger

Fires after any `Bash` tool call whose command contains `org-scan.sh`.

## Behavior

1. Read the hook payload from stdin (JSON).
2. If command does not match `org-scan.sh`, exit 0 immediately.
3. Locate the most recent report directory under `/tmp/org-scan-*`.
4. Read all domain JSON files from that directory.
5. Generate a self-contained HTML report at `reports/org-scan-<timestamp>.html`.
6. Print the report path so it appears in the transcript.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/post-org-scan-report.sh" }
        ]
      }
    ]
  }
}
```
