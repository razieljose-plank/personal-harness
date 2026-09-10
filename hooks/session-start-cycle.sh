#!/usr/bin/env bash
# SessionStart hook: if an SDLC cycle is in flight in this repo, say so.
#
# The point is continuity across sessions. Without this, a new session opens with
# no idea that there is a plan on disk waiting to be implemented, and the first
# thing it does is re-derive the plan.
set -uo pipefail

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

CYCLE=".harness/current-cycle"
[ -d "$CYCLE" ] || exit 0

PHASE="plan written"
[ -f "$CYCLE/notes.md" ]  && PHASE="implementation in progress"
[ -f "$CYCLE/review.md" ] && PHASE="reviewed, ready to ship"

TITLE=$(head -1 "$CYCLE/plan.md" 2>/dev/null | sed 's/^# *//')
[ -z "$TITLE" ] && TITLE="(untitled)"

jq -n --arg c "An SDLC cycle is already in flight in this repo.

  Ticket: $TITLE
  Phase:  $PHASE
  State:  $CYCLE/

Read the state files before starting work — do not re-plan what is already planned. Use the 'sdlc' skill to resume from the right phase." '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
exit 0
