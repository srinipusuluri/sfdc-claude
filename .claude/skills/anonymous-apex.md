---
name: anonymous-apex
description: Execute anonymous Apex against an org for one-off data fixes, debugging, or admin tasks. Use when the user needs to run ad-hoc Apex code.
---

# anonymous-apex

Run anonymous Apex blocks for ad-hoc operations.

## Usage

```bash
sf apex run --file scripts/apex/fix-data.apex --target-org <alias>
```

Or inline:
```bash
echo "System.debug([SELECT COUNT() FROM Account]);" | sf apex run --target-org <alias>
```

## Safety Rules

- **Never run destructive anonymous Apex against production without:**
  1. A dry-run that prints affected record IDs.
  2. Explicit user confirmation showing the count.
  3. A backup query exported via `sf data export`.
- Wrap DML in `Database.SaveResult[]` and check failures.
- Use `System.Savepoint` for multi-step changes:
  ```apex
  Savepoint sp = Database.setSavepoint();
  try {
      // changes
  } catch (Exception e) {
      Database.rollback(sp);
      throw e;
  }
  ```

## Common Tasks

- Backfill a new field on existing records.
- Recalculate roll-up summaries.
- Reassign ownership in bulk.
- Trigger a batch class manually: `Database.executeBatch(new MyBatch(), 200);`
