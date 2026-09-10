#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): format the file that was just edited.
#
# Uses the PROJECT's own toolchain only — never a global install and never a
# network fetch. A formatter that isn't in the project isn't the project's
# formatter, and `npx`-ing one would reformat the file to a config nobody agreed
# to. If nothing is found, this exits silently: a hook that complains on every
# edit in a repo without formatters is a hook you disable within a day.
#
# Always exits 0. Formatting is a convenience, not a gate.
set -uo pipefail

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

# Walk up from the file to find the project root (nearest dir with a manifest).
find_root() {
  local dir; dir=$(dirname "$FILE")
  while [ "$dir" != "/" ]; do
    for marker in package.json pyproject.toml .git; do
      [ -e "$dir/$marker" ] && { printf '%s' "$dir"; return; }
    done
    dir=$(dirname "$dir")
  done
}
ROOT_DIR=$(find_root)
[ -z "$ROOT_DIR" ] && exit 0

run() { "$@" >/dev/null 2>&1 || true; }

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.yaml|*.yml)
    BIN="$ROOT_DIR/node_modules/.bin"
    [ -x "$BIN/biome" ]    && { run "$BIN/biome" format --write "$FILE"; exit 0; }
    [ -x "$BIN/prettier" ] && { run "$BIN/prettier" --write "$FILE"
                                [ -x "$BIN/eslint" ] && run "$BIN/eslint" --fix "$FILE"
                                exit 0; }
    ;;
  *.py)
    for VENV in "$ROOT_DIR/.venv/bin" "$ROOT_DIR/venv/bin"; do
      [ -x "$VENV/ruff" ]  && { run "$VENV/ruff" format "$FILE"
                                run "$VENV/ruff" check --fix "$FILE"; exit 0; }
      [ -x "$VENV/black" ] && { run "$VENV/black" -q "$FILE"; exit 0; }
    done
    command -v ruff  >/dev/null 2>&1 && { run ruff format "$FILE"; exit 0; }
    command -v black >/dev/null 2>&1 && { run black -q "$FILE"; exit 0; }
    ;;
esac

exit 0
