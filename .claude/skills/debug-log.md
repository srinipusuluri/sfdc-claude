---
name: debug-log
description: Pull, tail, and analyze Apex debug logs from a Salesforce org. Use when the user is debugging an error, callout, or governor-limit issue.
---

# debug-log

Capture and inspect Apex debug logs.

## Set a trace flag (so logs are generated)

```bash
sf apex log get --target-org <alias> --debug-level SFDC_DevConsole --duration 30
```

Or via SOQL/API: insert a `TraceFlag` record for the target user with a `DebugLevel` that has `ApexCode=FINEST`.

## Tail logs in real time

```bash
sf apex tail log --target-org <alias> --color
```

Filter while tailing:
```bash
sf apex tail log -o <alias> | grep -E 'USER_DEBUG|FATAL_ERROR|LIMIT_USAGE'
```

## Pull a specific log

```bash
sf apex list log -o <alias>             # find the ID
sf apex get log -o <alias> -i 07L...    # download to stdout
sf apex get log -o <alias> -n 5         # last 5 logs
```

## What to look for

| Marker | Meaning |
|--------|---------|
| `USER_DEBUG` | `System.debug(...)` output |
| `FATAL_ERROR` | uncaught exception with stack trace |
| `LIMIT_USAGE_FOR_NS` | governor consumption per namespace |
| `SOQL_EXECUTE_BEGIN/END` | each query — count for N+1 |
| `DML_BEGIN/END` | DML — count for in-loop violations |
| `CALLOUT_REQUEST/RESPONSE` | outbound HTTP |
| `WF_RULE_EVAL_BEGIN` | workflow rules firing |
| `FLOW_*` | Flow execution events |

## Common diagnostics

**SOQL in a loop:** count `SOQL_EXECUTE_BEGIN` lines within a single trigger event boundary. If > query count expected, investigate.

**CPU timeout:** look for `LIMIT_USAGE_FOR_NS` near the end; CPU should be < 10000 ms sync, < 60000 ms async.

**Heap blowout:** `LIMIT_USAGE_FOR_NS` heap > 6 MB sync / 12 MB async indicates oversized SOQL or deserialization.

## Quieting noisy logs

Drop `WORKFLOW`, `VALIDATION`, `VISUALFORCE` levels to NONE in the DebugLevel for performance investigations — they bloat the log file.
