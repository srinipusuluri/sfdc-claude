---
description: Diff metadata between two Salesforce orgs
argument-hint: <source-alias> <target-alias>
---

Compare metadata between two orgs and produce a deployment-ready report.

## Steps

1. Retrieve metadata from both orgs:
   ```bash
   sf project retrieve start --target-org <source-alias> --output-dir tmp/source
   sf project retrieve start --target-org <target-alias> --output-dir tmp/target
   ```

2. Run diff:
   ```bash
   diff -r tmp/source tmp/target
   ```

3. Summarize results in three buckets:
   - **Additions** — present in source, missing in target
   - **Deletions** — present in target, missing in source
   - **Modifications** — present in both, content differs

4. For each modification, show a unified diff truncated to 20 lines.

5. Generate a `package.xml` containing only the changed components, suitable for deploy.

6. Flag risky changes:
   - Deleted custom fields (data loss)
   - Profile/PermissionSet changes (access risk)
   - Validation rule changes (could block existing automations)
