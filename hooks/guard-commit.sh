#!/usr/bin/env bash
# PreToolUse hook (Bash, filtered to `git commit` via the hook's `if` field):
# refuse commits that should not happen, and warn about ones that merely smell.
#
# The severity split is deliberate. A secret or a commit straight to main is
# blocked, because both are expensive to undo — a pushed secret has to be treated
# as leaked. A stray console.log is surfaced as context instead, because blocking
# on it would train you to work around the hook, and a hook that gets worked
# around protects nothing.
#
# Exit 2 blocks the tool call. Exit 0 lets it proceed.
set -uo pipefail

INPUT=$(cat)

# Re-check the command ourselves rather than trusting the hook's `if` filter.
# Measured behavior: `if` over-fires on long compound commands — a multi-line
# script with a heredoc and no git invocation at all was matched as `git commit`
# and blocked. A guard that randomly refuses unrelated commands is one you turn
# off within a day, so the filter is treated as a cheap pre-filter and this is
# the real check.
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
printf '%s' "$COMMAND" | grep -qE '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+([^;&|]*[[:space:]])?commit([[:space:]]|$)' || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 2
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# --- Block: committing straight to the default branch -----------------------
# `git branch --show-current` is used rather than `rev-parse --abbrev-ref HEAD`
# because rev-parse fails on an unborn branch (a repo with no commits yet),
# which silently skipped this guard on exactly the first commit.
BRANCH=$(git branch --show-current 2>/dev/null)
# The initial commit of a repository is exempt: there is no other branch to
# move to yet, and refusing it just leaves you stuck.
if git rev-parse --verify HEAD >/dev/null 2>&1; then
case "$BRANCH" in
  main|master|develop)
    deny "Refusing to commit directly to '$BRANCH'. Create a feature branch first: git checkout -b <type>/<ISSUE-ID>-<slug>"
    ;;
esac
fi

STAGED=$(git diff --cached --name-only 2>/dev/null)
[ -z "$STAGED" ] && exit 0
ADDED=$(git diff --cached -U0 2>/dev/null | grep '^+' | grep -v '^+++' || true)

# --- Block: obvious secrets in the staged diff ------------------------------
SECRETS=$(printf '%s\n' "$ADDED" | grep -nEi \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY' \
  -e 'gh[pousr]_[A-Za-z0-9]{20,}' \
  -e 'sk-[A-Za-z0-9]{32,}' \
  -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
  -e '(api[_-]?key|secret[_-]?key|access[_-]?token|password)["'"'"']?\s*[:=]\s*["'"'"'][^"'"'"']{12,}' \
  || true)
if [ -n "$SECRETS" ]; then
  deny "Possible secret in the staged diff:

$(printf '%s' "$SECRETS" | head -5)

If this is a real credential, treat it as leaked: rotate it, then unstage the file. If it is a placeholder or test fixture, commit with --no-verify or move it to an example file."
fi

# --- Block: files that should never be committed ----------------------------
BADFILES=$(printf '%s\n' "$STAGED" | grep -E '(^|/)(\.env(\.|$)|\.harness/|id_rsa|\.pem$|\.p12$)' | grep -v '\.env\.example' || true)
if [ -n "$BADFILES" ]; then
  deny "These staged files should not be committed:

$BADFILES

Add them to .gitignore and unstage with: git restore --staged <file>"
fi

# --- Warn (non-blocking): debugging leftovers -------------------------------
LEFTOVERS=$(printf '%s\n' "$ADDED" | grep -nE \
  -e 'console\.(log|debug|dir)\(' \
  -e '\bdebugger\b' \
  -e 'pdb\.set_trace|breakpoint\(\)' \
  -e '\b(it|describe|test)\.only\(' \
  -e '\b(it|describe|test)\.skip\(' \
  || true)
if [ -n "$LEFTOVERS" ]; then
  jq -n --arg c "Debugging leftovers in the staged diff — check whether these are intentional before the commit lands:

$(printf '%s' "$LEFTOVERS" | head -8)" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: $c
    }
  }'
fi

exit 0
