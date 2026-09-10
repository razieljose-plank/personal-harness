---
name: sdlc-ship
description: Turn finished work into a conventional commit and a pull request whose body is written from the plan and the actual diff. Use when the user says "commit this", "ship it", "open the PR", "push it up", or when a cycle has passed review and is ready to leave the machine. Handles branch creation, commit splitting, and PR body composition, and always confirms before anything is pushed.
---

# Ship

Commit and open the PR. Everything here writes somewhere other people see, so the last
step is always a confirmation.

## 1. Check the state before writing anything

Run `git status` and `git diff` (and `git diff --staged`). Look at what is actually there
rather than what you think you changed. Specifically check for:

- Files you did not intend to include — `.env`, credentials, large binaries, scratch
  files, `.harness/` (it should be gitignored; if it is not, add it now).
- Debugging leftovers: stray logs, commented-out code, a skipped test.

If review found blocking issues that are still open, stop. Shipping past an open blocker
is the one thing this phase exists to prevent.

## 2. Branch

If on the default branch, create a branch first — never commit directly to `main`.

Name it from the ticket: `<type>/<ISSUE-ID>-<short-slug>`, e.g.
`feat/ENG-142-retry-webhook-delivery`.

## 3. Commit

Conventional commits, because the format is what lets tooling derive changelogs and
what makes `git log` readable a year later:

```
<type>(<scope>): <subject>

<body>

Refs: <ISSUE-ID>
```

Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`.

The subject is imperative and under ~72 chars: "add retry to webhook delivery", not
"added" or "adds". The body explains *why* — the diff already shows what. If the plan
recorded a constraint that forced this approach, that belongs here; it is the thing a
reader six months from now cannot reconstruct.

Split into multiple commits when the change contains genuinely separate concerns — a
refactor and a behavior change in one commit is the diff nobody can review. Don't split
mechanically; two commits that must land together are one commit.

End the message with the attribution line this repo's CLAUDE.md specifies.

## 4. PR body from plan + diff

Read `.harness/current-cycle/plan.md`, `notes.md`, and `review.md`. The PR body is
where they get reconciled: the plan says what was intended, the diff says what happened,
the notes say why they differ.

```markdown
## What
One paragraph: what changes for a user or a caller.

## Why
The problem from the plan, and the ticket link.

## Approach
How it was done, and any deviation from the plan with the reason.
This is the section reviewers actually need.

## Testing
What was added or changed, and how to verify by hand if that applies.

## Review notes
Findings that were fixed, and anything deliberately deferred with a reason.

## Risk
Blast radius, rollback story, anything needing attention at deploy.

Closes <ISSUE-ID>
```

Write it from what the diff actually does. A PR body generated from the plan alone
describes the change that was intended, which is the one thing a reviewer cannot use.

## 5. Confirm, then push

Show the user the commit message and the PR body, and say which branch and which remote.
Push and open the PR only on an explicit yes — this is the point where the work becomes
visible to other people, and an unwanted PR is annoying to retract.

Use `gh pr create` with the body from a file rather than inline, so formatting survives.

After it exists, offer to link the PR back on the Linear issue.
