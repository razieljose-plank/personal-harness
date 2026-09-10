---
name: sdlc
description: Run the full SDLC cycle on a ticket — plan, implement, adversarial review, ship, distill — carrying state between phases so nothing is re-derived. Use this whenever the user points at a Linear issue or a piece of work and wants it taken from ticket to merged PR ("pick up ENG-142", "let's do this ticket", "run the cycle on this", "take this from issue to PR"). Also use it when the user asks to resume work already in flight, since it knows how to read the cycle state on disk and continue from the right phase.
---

# SDLC Cycle

This is the spine of the harness. Five phases, run in order, with state on disk between
them so each phase starts from what the previous one actually did rather than from a
summary of it.

The reason state lives in files and not in the conversation: context gets compacted,
sessions end, and you may run phases days apart. A plan that only exists in the
transcript is a plan that evaporates. A plan on disk is one the review phase can hold
the diff against.

## Cycle state

All state lives in `.harness/current-cycle/` in the target repo:

| File | Written by | Read by |
|---|---|---|
| `plan.md` | plan | implement, ship, distill |
| `notes.md` | implement | review, ship, distill |
| `review.md` | review | ship, distill |

`.harness/` is gitignored. When a cycle finishes, `distill` archives the directory to
`.harness/cycles/<YYYY-MM-DD>-<slug>/` and clears `current-cycle`.

## Phases

Run them with the dedicated skills — each one is loaded only when its phase starts, which
keeps the other four phases out of context:

1. **`sdlc-plan`** — Linear issue → `plan.md`
2. **`sdlc-implement`** — `plan.md` → working code + `notes.md`
3. **`sdlc-review`** — diff → parallel adversarial subagents → `review.md`
4. **`sdlc-ship`** — conventional commit + PR body from plan and diff
5. **`sdlc-distill`** — what was learned → `CLAUDE.md`, skills, memory

## Gates between phases

The value of a harness is not that it runs five steps. It's that it refuses to run step
N+1 when step N did not actually land. Check these before advancing:

- **plan → implement**: the plan has acceptance criteria that can be checked, and no
  open question that would change the approach. If there is one, ask the user — a wrong
  assumption here costs the whole cycle.
- **implement → review**: the change is complete and the test suite passes. Reviewing a
  half-finished diff generates findings about code that was about to be written anyway.
- **review → ship**: every blocking finding is fixed or explicitly waived by the user.
  Non-blocking findings can ship as follow-ups, but say so in the PR.
- **ship → distill**: the PR exists. Distilling a cycle that never shipped records
  lessons from an unfinished experiment.

## Starting a cycle

Check `.harness/current-cycle/` first. If it has files, a cycle is already in flight —
report which phase it reached and ask whether to resume or start fresh, rather than
silently overwriting someone's plan.

If the user names a phase directly ("just review this"), run that phase alone. The cycle
is a default, not a cage.

## Running phases in one sitting vs. across sessions

Both work. Across sessions, the state files are the handoff, so read them at the start of
each phase instead of assuming you remember. In one sitting, still write the files — the
review phase reads `plan.md` from disk on purpose, so that it is judging the diff against
what was agreed rather than against your own memory of writing it.
