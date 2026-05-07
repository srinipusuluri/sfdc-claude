---
name: post-test-report
event: PostToolUse
matcher: Bash
description: After sf apex run test completes, generate a colour-coded HTML coverage report in reports/ showing per-class pass/fail and coverage bars.
---

# post-test-report (PostToolUse Hook)

## Trigger

Fires after any `Bash` tool call whose command contains `sf apex run test`.

## Behavior

1. Read the hook payload from stdin (JSON).
2. If command does not match `sf apex run test`, exit 0 immediately.
3. Locate JSON output files under `/tmp/apex-test-results/`.
4. Parse test outcomes and per-class coverage percentages.
5. Generate `reports/test-coverage-<timestamp>.html` with:
   - Summary card: total tests, pass rate, org-wide coverage %
   - Per-class coverage table with visual percentage bars
   - Failed test list with method name, error message, and stack trace
   - Quality flags: SeeAllData, no assertions, hard-coded IDs
6. Print the report path to the transcript.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/post-test-report.sh" }
        ]
      }
    ]
  }
}
```
