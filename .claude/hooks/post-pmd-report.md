---
name: post-pmd-report
event: PostToolUse
matcher: Bash
description: After sf scanner run completes, convert the SARIF output into a readable HTML findings report in reports/ grouped by severity and rule.
---

# post-pmd-report (PostToolUse Hook)

## Trigger

Fires after any `Bash` tool call whose command contains `sf scanner run`.

## Behavior

1. Read the hook payload from stdin (JSON).
2. If command does not match `sf scanner run`, exit 0 immediately.
3. Locate the most recent SARIF file in `reports/` (`pmd.sarif` or `scanner.sarif`).
4. Parse SARIF `runs[].results[]` entries.
5. Generate `reports/pmd-findings-<timestamp>.html` with:
   - Summary card: total findings by severity (Critical / High / Medium / Low)
   - Findings table grouped by rule, showing file, line, message
   - Colour-coded severity rows
   - Direct link to Salesforce PMD rule documentation where available
6. Print the report path to the transcript.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/post-pmd-report.sh" }
        ]
      }
    ]
  }
}
```
