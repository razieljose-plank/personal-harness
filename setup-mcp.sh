#!/usr/bin/env bash
# Register the MCP servers the harness consumes, at user scope so they are
# available in every project.
#
# Server NAMES matter: the permission rules in settings/settings.template.json
# are written as mcp__linear__* and mcp__github__*, so renaming a server here
# silently drops its pre-approvals and you get prompted for every call.
set -euo pipefail

echo "Registering MCP servers at user scope..."
echo

echo "→ linear"
claude mcp add --transport http --scope user linear https://mcp.linear.app/mcp \
  || echo "  (already registered, or the CLI is unavailable)"

echo "→ github"
claude mcp add --transport http --scope user github https://api.githubcopilot.com/mcp/ \
  || echo "  (already registered, or the CLI is unavailable)"

cat <<'EOF'

Both servers use browser OAuth. Start a session and run:

  /mcp

then authenticate each one. Verify with `claude mcp list`.

Note on GitHub: the `gh` CLI covers most of what this harness needs from GitHub
(PR create, view, diff, checks) and costs far less context than the MCP server's
tool definitions. The MCP server earns its place when you want richer GitHub
queries; if you find you never use it, removing it is a real context saving:

  claude mcp remove github --scope user
EOF
