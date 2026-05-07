---
description: Run a Salesforce security review on the current branch — Apex CRUD/FLS, SOQL injection, sharing, LWC XSS, and metadata exposure.
argument-hint: [--target-org <alias>] [--diff-against main]
---

Perform a security review of the pending changes.

## Steps

1. Determine the changeset:
   - If `--diff-against <branch>` is provided, diff `force-app/` against that branch.
   - Otherwise, diff against `git merge-base HEAD main`.
2. Hand the changed files off to the `security-reviewer` agent (Use the security-reviewer agent).
3. Run scanners on the changed paths:
   ```bash
   sf scanner run --target "<changed-files>" --engine pmd,eslint,eslint-lwc,retire-js --severity-threshold 3
   sf scanner run dfa --target "<changed-files>" --projectdir . --severity-threshold 3
   ```
4. For metadata changes (profiles, permission sets, sharing rules), inspect XML for new permissions granted to non-admin profiles.
5. For LWC bundles, grep for `lwc:dom="manual"`, `innerHTML`, `eval(`, `Function(`.

## Output

A single report:

1. **Risk summary** — Critical / High / Medium / Low counts.
2. **Findings table** — File:Line, Category, Finding, Recommendation.
3. **Ship recommendation** — green / yellow / red, with the one or two findings that drive that call.

## Exit code

Non-zero if any **Critical** or **High** finding is present, so this can be wired into CI as a required check.
