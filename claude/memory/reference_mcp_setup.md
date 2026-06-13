---
name: reference-mcp-setup
description: "MCP servers for Claude Code: github + trello via 1Password wrappers, fetch via npx; troubleshooting notes"
metadata:
  type: reference
---

All MCP servers are defined in user-scope `claude/settings.json` (symlinked to `~/.claude/settings.json`); the utility-scripts repo `.mcp.json` reuses the same github wrapper.

- **github** — `~/.claude/mcp-wrappers/github.sh`: verifies `op account get`, injects PAT from `op://HomeLab/Github/Personal Access Tokens/Claude Code`, then `npx -y @modelcontextprotocol/server-github`. (The old `op://Personal/GitHub PAT/credential` path is dead — standardized on HomeLab 2026-06-13.)
- **trello** — `~/.claude/mcp-wrappers/trello.sh`: injects `op://HomeLab/Atlassian/api_key` and `.../token`, runs `npx -y trello-mcp`.
- **fetch** — `npx -y @modelcontextprotocol/server-fetch`, no auth; inline doc lookups.

Troubleshooting: if a wrapper-based server fails to start, 1Password must be authenticated (`eval $(op signin)` or desktop app running). Write/mutation ops stay in Bash (kubectl, ansible-playbook, op, hcloud) — MCP is for reads.
