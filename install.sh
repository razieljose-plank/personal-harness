#!/usr/bin/env bash
# Install the harness into ~/.claude.
#
# Skills and agents are symlinked, not copied, so editing them in this repo takes
# effect in the next session with no reinstall step. That matters more than it
# sounds: a harness you have to reinstall to tweak is a harness you stop tweaking.
#
# Settings are merged, never overwritten, and the previous file is backed up.
set -euo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

echo "Installing harness from $HARNESS into $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

link() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  ! $dest exists and is not a symlink — skipping (move it aside to install)"
    return
  fi
  ln -sfn "$src" "$dest"
  echo "  → $(basename "$dest")"
}

echo
echo "Skills:"
for dir in "$HARNESS"/skills/*/; do
  link "${dir%/}" "$CLAUDE_DIR/skills/$(basename "${dir%/}")"
done

echo
echo "Agents:"
for file in "$HARNESS"/agents/*.md; do
  link "$file" "$CLAUDE_DIR/agents/$(basename "$file")"
done

echo
echo "Settings:"
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.backup.$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  echo "  backed up existing settings to $(basename "$BACKUP")"
fi

python3 - "$HARNESS" "$SETTINGS" <<'PY'
import json, os, sys

harness, settings_path = sys.argv[1], sys.argv[2]

with open(os.path.join(harness, "settings", "settings.template.json")) as f:
    incoming = json.loads(f.read().replace("__HARNESS__", harness))

current = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        text = f.read().strip()
        if text:
            current = json.loads(text)

# Permissions merge as de-duplicated unions so a rule you added by hand or via
# /permissions survives a reinstall.
perms = current.setdefault("permissions", {})
for key, rules in incoming.get("permissions", {}).items():
    existing = perms.get(key, [])
    perms[key] = existing + [r for r in rules if r not in existing]

# Hooks are replaced per event, matched on the command path, so reinstalling
# updates this harness's hooks without duplicating them and without touching
# hooks from anywhere else.
hooks = current.setdefault("hooks", {})
for event, entries in incoming.get("hooks", {}).items():
    kept = []
    for entry in hooks.get(event, []):
        cmds = [h.get("command", "") for h in entry.get("hooks", [])]
        if not any(harness in c for c in cmds):
            kept.append(entry)
    hooks[event] = kept + entries

with open(settings_path, "w") as f:
    json.dump(current, f, indent=2)
    f.write("\n")

print("  merged permissions (%d allow, %d ask, %d deny) and %d hook events"
      % (len(perms.get("allow", [])), len(perms.get("ask", [])),
         len(perms.get("deny", [])), len(hooks)))
PY

echo
echo "Done. MCP servers are a separate step — see: ./setup-mcp.sh"
