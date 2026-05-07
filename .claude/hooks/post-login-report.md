---
name: post-login-report
event: PostToolUse
matcher: Bash
description: After login-history-report.sh or a LoginHistory SOQL query completes, generate an HTML anomaly report highlighting failed logins, new countries, off-hours access, and MFA failures.
---

# post-login-report (PostToolUse Hook)

## Trigger

Fires after any `Bash` tool call whose command contains `login-history-report.sh` or a SOQL query against `LoginHistory`.

## Behavior

1. Read the hook payload from stdin (JSON).
2. If command does not match the trigger patterns, exit 0.
3. Parse tool output for login records (JSON lines or CSV).
4. Generate `reports/login-anomaly-<timestamp>.html` with:
   - Summary card: total logins, failure rate, unique IPs, unique users
   - 🔴 Anomaly table: failed attempts, new countries, MFA failures
   - 🟡 Watch list: >5 sessions/day/user, off-hours logins
   - 🟢 Clean: no anomalies found in lookback window
   - Top-10 source IPs by failure count
5. Print the report path to the transcript.

## Wiring (settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/post-login-report.sh" }
        ]
      }
    ]
  }
}
```
