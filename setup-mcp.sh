#!/usr/bin/env bash
# Register the MCP servers the harness consumes, at user scope so they are
# available in every project.
#
# Server NAMES matter: the permission rules in settings/settings.template.json
# are written as mcp__linear__* and mcp__github__*, so renaming a server here
# silently drops its pre-approvals and you get prompted for every call.
#
# This script fails loudly. An earlier version ended each command with
# `|| echo "(already registered, or the CLI is unavailable)"`, which reported
# something reassuring while registering nothing — the `claude` CLI was simply
# not on PATH. A setup script that can't tell success from failure is worse than
# no setup script, because you stop checking.
set -uo pipefail

# The CLI is often installed outside the PATH of a non-login shell.
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
if [ -z "$CLAUDE_BIN" ]; then
  for candidate in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" \
                   /usr/local/bin/claude /opt/homebrew/bin/claude; do
    [ -x "$candidate" ] && { CLAUDE_BIN="$candidate"; break; }
  done
fi

if [ -z "$CLAUDE_BIN" ]; then
  echo "ERROR: the 'claude' CLI was not found." >&2
  echo "Looked on PATH and in ~/.local/bin, ~/.claude/local, /usr/local/bin, /opt/homebrew/bin." >&2
  echo "Install it, or add its directory to PATH, then run this again." >&2
  exit 1
fi

echo "Using CLI: $CLAUDE_BIN"
echo

FAILED=0

register() {
  local name="$1" url="$2"
  printf '→ %-8s ' "$name"

  local output status
  output=$("$CLAUDE_BIN" mcp add --transport http --scope user "$name" "$url" 2>&1)
  status=$?

  if [ $status -eq 0 ]; then
    echo "registered"
  elif printf '%s' "$output" | grep -qi 'already exists'; then
    echo "already registered"
  else
    echo "FAILED"
    printf '%s\n' "$output" | sed 's/^/    /'
    FAILED=1
  fi
}

register linear https://mcp.linear.app/mcp
register github https://api.githubcopilot.com/mcp/

echo
echo "Registered servers:"
"$CLAUDE_BIN" mcp list 2>&1 | sed 's/^/  /'

if [ $FAILED -ne 0 ]; then
  echo
  echo "At least one server failed to register. Nothing above is authenticated yet." >&2
  exit 1
fi

cat <<'EOF'

Both servers use browser OAuth, and registering them is not the same as being
signed in. Start a session and run:

  /mcp

then authenticate each one. Until you do, every Linear and GitHub MCP call fails.

Note on GitHub: the `gh` CLI covers most of what this harness needs from GitHub
(PR create, view, diff, checks) and costs far less context than the MCP server's
tool definitions. The MCP server earns its place when you want richer GitHub
queries; if you find you never use it, removing it is a real context saving:

  claude mcp remove github --scope user
EOF
