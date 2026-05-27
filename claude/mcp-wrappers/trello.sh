#!/usr/bin/env bash
set -euo pipefail

# Verify 1Password CLI is authenticated
if ! op account get &>/dev/null; then
  echo "ERROR: 1Password CLI is not authenticated. Run 'eval \$(op signin)' first." >&2
  exit 1
fi

# Inject secrets from 1Password
export TRELLO_API_KEY="$(op read 'op://HomeLab/Atlassian/api_key')"
export TRELLO_TOKEN="$(op read 'op://HomeLab/Atlassian/token')"

# Launch the MCP server
exec npx -y trello-mcp
