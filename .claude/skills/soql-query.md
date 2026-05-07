---
name: soql-query
description: Build and execute SOQL queries against a Salesforce org. Use when the user wants to inspect data, count records, or test query performance.
---

# soql-query

Run SOQL queries against an org and return formatted results.

## Usage

```bash
sf data query --query "SELECT Id, Name FROM Account LIMIT 10" --target-org <alias>
```

For tooling API queries (metadata):
```bash
sf data query --query "SELECT Id, Name FROM ApexClass" --use-tooling-api --target-org <alias>
```

## Common Patterns

- **Aggregate**: `SELECT COUNT(Id), StageName FROM Opportunity GROUP BY StageName`
- **Parent-to-child**: `SELECT Id, Name, (SELECT Id FROM Contacts) FROM Account`
- **Child-to-parent**: `SELECT Id, Account.Name, Account.Owner.Email FROM Contact`
- **Date literals**: `WHERE CreatedDate = LAST_N_DAYS:30`

## Performance Tips

- Always include a selective `WHERE` clause on indexed fields (Id, Name, custom indexed).
- Avoid `LIKE '%foo%'` (leading wildcard) — non-selective.
- Use `LIMIT` during exploration.
- Check the Query Plan tool in Developer Console for large queries.

## Output

Format results as a markdown table when ≤ 20 rows; otherwise summarize counts and show first 10.
