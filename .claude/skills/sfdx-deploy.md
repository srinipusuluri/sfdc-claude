---
name: sfdx-deploy
description: Deploy metadata to a Salesforce org using SFDX. Use when the user asks to push, deploy, or release changes. Validates first, runs tests, then deploys.
---

# sfdx-deploy

Deploy source-format metadata to a target org with safety checks.

## Steps

1. Confirm the target org alias with the user (`sfdx force:org:list`).
2. Run validation deploy first:
   ```bash
   sf project deploy validate --target-org <alias> --test-level RunLocalTests
   ```
3. Review test results — abort if coverage < 75% or any test fails.
4. Run actual deploy:
   ```bash
   sf project deploy start --target-org <alias> --test-level RunLocalTests
   ```
5. If deploying to production, require explicit user confirmation before step 4.

## Common Flags

- `--dry-run` — validate without deploying
- `--ignore-conflicts` — overwrite remote changes (use with caution)
- `--manifest package.xml` — deploy a specific manifest
- `--source-dir force-app/main/default/classes` — partial deploy

## Rollback

SFDX has no automatic rollback. To revert:
1. Check out the previous git commit of the metadata.
2. Re-deploy from that state.
3. Manually undo any destructive changes (deleted fields, etc.).
