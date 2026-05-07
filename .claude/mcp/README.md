# .claude/mcp/ — Model Context Protocol servers

MCP servers extend Claude Code with extra tools (databases, APIs, dashboards). Files here are **configuration templates**; the actual server registration happens in `.claude/settings.json` or `~/.claude/settings.json` under the `mcpServers` key.

## How MCP plugs into Claude Code

```json
{
  "mcpServers": {
    "<name>": {
      "command": "<binary>",
      "args": ["..."],
      "env": { "KEY": "value" }
    }
  }
}
```

Each server starts when Claude Code launches and exposes its tools to the model.

## Useful MCP servers for Salesforce work

| Server | What it gives you | Status |
|--------|-------------------|--------|
| `sfdc-mcp` (community) | SOQL query, describe, deploy from Claude | Template in `sfdc.json.example` |
| `github` (Anthropic) | Issues, PRs, code search across repos | Template in `github.json.example` |
| `filesystem` (Anthropic) | Sandboxed file reads beyond the project dir | Template in `filesystem.json.example` |
| `postgres` / `bigquery` | Query reporting databases that mirror SF data | Template in `postgres.json.example` |

See each `*.json.example` file for the exact `mcpServers` block to copy into `.claude/settings.json`. Never commit real secrets — use `${ENV_VAR}` substitution and put credentials in `~/.claude/settings.json` (user-level) or a `.env` outside the repo.

## Adding a new server

1. Drop a `<name>.json.example` here documenting the config.
2. Append the block to your local `.claude/settings.json` (gitignored if it contains secrets).
3. Update this README's table.
