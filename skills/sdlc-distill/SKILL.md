---
name: sdlc-distill
description: Close a cycle by extracting what was actually learned and writing it back into CLAUDE.md, a skill, or memory so the next cycle starts with it. Use at the end of a shipped cycle, or when the user says "what did we learn", "write this down", "update CLAUDE.md", "distill this". Also use after a session where you repeatedly rediscovered the same non-obvious fact about a codebase, since that is exactly the thing that should not need rediscovering.
---

# Distill

This is the phase that makes the harness compound. Without it every cycle starts from
zero and you re-learn that the test suite needs a running Postgres, every time, forever.

It is also the phase most likely to do damage, because the failure mode is writing lots
of things down. A `CLAUDE.md` that has absorbed every cycle's notes is 600 lines of
lukewarm advice that gets skimmed and then ignored, and it costs context in every single
session. Write less than feels right.

## 1. Gather the raw material

Read `.harness/current-cycle/plan.md`, `notes.md`, `review.md`, and the final diff. The
Surprises section of the notes is the highest-yield input — surprise is the signal that
something was not derivable from the code.

Also look back over the session itself: where did you go down a wrong path, what did the
user correct, what took three attempts.

## 2. Apply the two filters

Ask both questions of each candidate. Most candidates fail at least one.

**Is it durable?** Will it still be true in a month, across other tickets? "The retry
wrapper swallows AbortError" is durable. "ENG-142 needed a rebase" is not.

**Is it non-derivable?** Would the next session figure it out just by reading the code?
If yes, do not write it down — the code is already the documentation, and a note that
restates it becomes a lie the first time the code changes without the note. What survives
this filter is usually a *why*, a constraint, or a landmine: the reason a thing is
structured oddly, an invariant the types don't encode, an ordering that matters.

A useful third check: would knowing this at the start have changed how this cycle went?
If not, it is trivia.

## 3. Route each survivor to the right home

| Kind of thing | Where |
|---|---|
| Fact about *this* codebase — conventions, gotchas, how to run things | Project `CLAUDE.md` |
| A repeatable procedure worth doing the same way every time | A skill |
| How the user wants to be worked with; a correction they made | Memory (`feedback`) |
| Ongoing goal or constraint not visible in the repo | Memory (`project`) |
| A link that will be needed again — dashboard, doc, ticket | Memory (`reference`) |

Wrong routing is why these files rot. A one-off preference in `CLAUDE.md` costs every
future session context; a codebase gotcha in memory is invisible to anyone else on the
repo.

## 4. Write it, edit-in-place

When updating `CLAUDE.md`, look for an existing section that covers the topic and sharpen
it rather than appending a new one. Growth by appending is how these files become
unreadable. If the file has grown past ~100 lines of things nobody reads, propose cutting
as part of this step — deleting a stale instruction is as valuable as adding a true one.

Show the user each proposed change before writing it. They know which lessons are real
and which were an artifact of this one ticket, and this is a cheap place to catch that.

## 5. Improve the harness itself

If a phase of the cycle went badly — a review full of false positives, a plan that missed
an obvious risk, a hook that fired constantly for nothing — that is a finding about the
harness, not about the ticket. Propose the edit to the skill.

This is the part people skip, and it is the difference between a harness that gets better
every cycle and one that stays as good as the day it was written.

## 6. Archive the cycle

Move `.harness/current-cycle/` to `.harness/cycles/<YYYY-MM-DD>-<issue-id>/`. The archive
is worth keeping: when a bug shows up later in this code, the plan and review from the
cycle that wrote it are the fastest explanation of why it looks the way it does.
