---
name: sdlc-implement
description: Execute an implementation plan step by step, keeping verification green and recording every deviation from the plan and why. Use after a plan exists (`.harness/current-cycle/plan.md`) and the user says "implement it", "go ahead", "execute the plan", or names the ticket again to start coding. Also use when resuming a partially implemented cycle, since it reads which steps are already done from the plan and notes on disk.
---

# Implement

Execute the plan. The interesting part of this phase is not writing code — it's what you
do when the plan turns out to be wrong, which happens often and is not a failure.

## Start from disk, not from memory

Read `.harness/current-cycle/plan.md`. If it's missing, there is no plan; run
`sdlc-plan` first or ask the user whether to proceed without one.

Check what is already done — `git status`, `git diff`, and the plan's Status field — before
writing anything. Resuming a cycle by redoing finished steps is the most common way this
phase wastes an hour.

## Work one step at a time

Take the Approach steps in order. After each one, verify before moving on: run the
relevant tests, or the type checker, or the thing that would actually catch a mistake in
that step. Batching five steps and then running the suite means a failure tells you
something broke, not what broke it.

Follow the repo's existing conventions over your own preferences. Read the neighbouring
code first — naming, error handling, test structure, comment density. Code that reads
like it was written by a different person is a review finding even when it is correct.

## Write the tests from the plan's test strategy

Write the test that would have caught the bug, then the fix. When the plan named a
failure a test should catch, the test should fail before your change and pass after. If
it passes before, it is not testing what you think.

### When there is no test runner

Sometimes there genuinely isn't one, and there cannot be — no runner in the project, or a
constraint that rules one out. Verify anyway, by whatever means the thing allows: drive
the real interface, exercise the function directly, check the output by hand.

Then write down, in `notes.md`, three things: what you verified, how, and **what you could
not verify**. That third item is the one that gets dropped, and it is the one that
matters. "Installable ✓" and "installable, except the part the sandbox blocked me from
reaching" look identical on a checklist, and the difference only surfaces in production.

Be clear with yourself that this is weaker than a suite. A green suite is a durable
artifact that anyone can re-run next month. A hundred assertions you ran in a session are
gone when the session ends, and the next cycle has no way to tell whether the thing was
ever checked. Where a runner is possible, that is the reason to prefer it; where it isn't,
that is the reason to be precise about what your evidence actually covers.

## Record deviations as they happen

Keep `.harness/current-cycle/notes.md` as you go:

```markdown
# Implementation notes

## Deviations from plan
- **Step 3** — plan said to extend `parseConfig`; it turned out to be called from the
  worker path too, so extending it there would change behavior for a caller the plan
  did not account for. Added a separate `parseWorkerConfig` instead.

## Surprises
- The retry wrapper swallows `AbortError`, which is why the timeout test never failed.

## Deferred
- `legacyAdapter.ts` has the same bug. Out of scope here; worth a follow-up ticket.
```

This file is the raw material for two later phases: the PR body explains *why* the diff
does not match the plan, and `sdlc-distill` mines Surprises for things worth keeping.
Written after the fact, from memory, it is worth much less — the surprising detail is
exactly the one you forget once it stops being surprising.

## When the plan is wrong

Small deviation — a different function name, an extra helper — take it and note it.

Deviation that changes the approach or the acceptance criteria: stop and tell the user
what you found and what it implies. Do not quietly redesign. The plan was agreed; a new
one needs the same agreement.

## Finish the whole step

Before declaring the phase done: the verification named in the plan passes — the full test
suite where one exists, the recorded evidence where one cannot — no debugging leftovers,
no commented-out code, and every acceptance criterion in the plan is actually met. If one
is not, say which and why — a criterion silently dropped is the failure that survives all
the way to production.
