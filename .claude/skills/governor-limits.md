---
name: governor-limits
description: Query all Salesforce governor limits via the REST Limits API and produce a colour-coded consumption report. Flags Critical (>=80%), Warning (40-79%), and Healthy (<40%) limits. No SOQL required — uses the /limits REST endpoint directly.
argument-hint: [--target-org <alias>]
---

# governor-limits

Fetch live governor limit consumption for every limit the org exposes.

## Query

```bash
sf api request rest "/services/data/v66.0/limits" \
  --target-org "${TARGET_ORG:-dev}" 2>/dev/null
```

## Parse and report

```python
import json, sys
from collections import defaultdict

d = json.load(sys.stdin)

critical, warning, healthy, zero = [], [], [], []

for k, v in sorted(d.items()):
    if not isinstance(v, dict) or 'Remaining' not in v:
        continue
    mx   = v.get('Max', 0)
    rm   = v.get('Remaining', mx)
    used = mx - rm
    pct  = (used / mx * 100) if mx else 0

    entry = (k, used, mx, rm, pct)
    if used == 0:
        zero.append(entry)
    elif pct >= 80:
        critical.append(entry)
    elif pct >= 40:
        warning.append(entry)
    else:
        healthy.append(entry)
```

## Key limits reference

| Limit key | Dev Edition | Enterprise | Unlimited | Action when >80% |
|-----------|-------------|-----------|-----------|-----------------|
| `DataStorageMB` | 5 MB | 1 GB/user | 120 GB | Archive records, purge logs |
| `FileStorageMB` | 20 MB | 2 GB/user | 10 GB/user | Delete old ContentVersions |
| `DailyApiRequests` | 15,000 | 1,000/user | 1,000/user | Rate-limit integrations |
| `DailyBulkApiBatches` | 15,000 | 15,000 | 15,000 | Use larger batch sizes |
| `DailyAsyncApexExecutions` | 250,000 | 250,000 | 250,000 | Throttle queueable chains |
| `HourlyPublishedPlatformEvents` | 50,000 | 50,000 | 50,000 | Buffer at publisher side |
| `DailyStreamingApiEvents` | 10,000 | 50,000 | 50,000 | Review subscriber counts |
| `DailyWorkflowEmails` | 6,330 | varies | varies | Batch email sends |
| `Package2VersionCreates` | 6/day | 6/day | 6/day | Stagger CI package builds |

## Transaction-level limits (runtime, not in REST API)

These can only be measured via Apex `Limits.*` calls or debug logs — not via the REST endpoint. Flag these for developers to check in code:

| Limit | Per-transaction cap | Common cause |
|-------|-------------------|-------------|
| SOQL queries | 100 | Missing query consolidation |
| DML statements | 150 | Missing unit-of-work pattern |
| CPU time | 10,000 ms | Heavy loops, string ops |
| Heap size | 6 MB (12 MB async) | Large List<SObject> in memory |
| Callouts | 100 | Fan-out integrations |
| Future calls | 50 | Uncontrolled future chains |

## Output format

```
=== GOVERNOR LIMITS — <org> — <timestamp> ===

🔴 CRITICAL (>= 80%)
  [████████████████████]  92.0%  DataStorageMB          46 / 50

🟡 WARNING (40–79%)
  [████████............]  60.0%  FileStorageMB           3 / 5

🟢 HEALTHY (< 40%, non-zero)
  [█...................]   0.6%  DailyApiRequests       88 / 15,000

⬜ ZERO USAGE (72 limits)
  (collapsed — expand if needed)

SUMMARY: 🔴 0 Critical  🟡 1 Warning  🟢 3 Active  ⬜ 72 Idle
```
