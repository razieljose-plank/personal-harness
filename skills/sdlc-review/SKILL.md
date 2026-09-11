---
name: sdlc-review
description: Adversarially review a change with parallel subagents attacking it from different angles — correctness and edge cases, performance, security, and the contract between both sides of any interface it touches — then verify each finding and aggregate into one ranked report. Use whenever the user asks to review a diff, a branch, or a PR, says "review this", "attack this change", "what did I miss", "is this safe to merge", or finishes implementing something before shipping it. Prefer this over reading the diff yourself, because one reader with one mental model misses the classes of bug the other angles are looking for.
---

# Adversarial Review

Three reviewers attack the change from angles that do not overlap — four when it touches
an interface — then every finding has to survive a verification pass before it reaches
the user.

The reason for the structure: a single reviewer reading a diff top to bottom finds the
bugs that look like bugs. Splitting by angle forces coverage of the classes that don't
look like anything — the N+1 that only shows up under load, the input that is only
attacker-controlled two callers up. And the verification pass exists because adversarial
prompts produce confident nonsense; a review full of false positives gets skimmed and
then ignored, which is worse than no review.

## 1. Assemble the change

Get the actual diff — `git diff <base>...HEAD`, or the PR diff. Read
`.harness/current-cycle/plan.md` and `notes.md` if they exist: the plan says what this
change was supposed to do, which is what makes "the diff does not meet acceptance
criterion 3" a possible finding. The notes say where the implementation already knows
it deviated.

Then check the diff against the plan's **Architecture decisions** yourself. This is not a
job for the reviewers — they hunt defects, and this is about who decided what. Look
for choices that shape the system but were never approved: a new dependency, a new module
or boundary, a changed data model, a pattern other code will be expected to copy. Each
one is a **blocking** finding until the engineer either approves it, recorded in
`plan.md`, or it is reverted. Correct code does not make it approved — the point of the
gate is that the engineer knows their own system.

If the diff is empty, stop and say so rather than reviewing the working tree by accident.

## 2. Launch the reviewers in parallel

Three always run: `review-bugs`, `review-perf`, `review-security`. A fourth,
`review-contracts`, runs when the diff touches an interface — anything one component
produces and another consumes across a boundary the compiler does not check: an API and
its client, routes and the links to them, a schema and the fields read from it, a state
machine and the code that moves it, event payloads, config keys, stored data. List the
ones you see and hand them to it as a starting point; it will look for more. If the diff
touches none, skip it and write why in the review — a skipped angle has to be visible, or
it reads exactly like a clean one.

Spawn them all in a single message so they run concurrently. They are read-only by
construction, so a reviewer cannot "helpfully" fix what it found and invalidate the diff
underneath the others.

Give each one the same context: the base ref, the changed files, and the plan's
acceptance criteria. Tell each to report findings in this shape, because the aggregation
step depends on it:

```
- **[file:line]** <one-line claim>
  Severity: blocking | should-fix | nit
  Failure scenario: <concrete inputs or state → wrong behavior>
```

The failure scenario is the load-bearing field. "This could cause a race condition" is a
vibe. "Two requests with the same `userId` arriving within the cache TTL both see
`undefined` and both write, so the second overwrites the first's `credits`" is a finding.
Require the concrete version — it is also what makes the verification step possible.

### When a reviewer fails

A reviewer that errors, times out, or returns something that is not in the finding format
gets one retry with the same input. If it fails again, carry on with the others and record
the angle as not covered.

Never let that pass quietly. "No security findings" and "the security reviewer crashed"
look identical in a report unless you say which one happened — and the second is the one
that ships a vulnerability with a green review attached. A missing angle goes at the top of
the review and blocks shipping until it is rerun or the user explicitly waives it.

## 3. Verify before reporting

For each finding, check it against the actual code. The cheap checks catch most of it:

- Does the file:line say what the finding claims it says?
- Is the code path reachable, or is it guarded upstream by something the reviewer did
  not read?
- Is it already covered by an existing test?
- Is it pre-existing rather than introduced by this diff? Pre-existing issues are worth
  mentioning but are not blockers for this change.

Drop what doesn't survive. Do not soften it to "possible issue" and keep it — a review
where half the items are hedged teaches the reader to skim.

For anything genuinely uncertain, keep it and label it clearly as unverified with what
would settle it.

## 4. Write the aggregated review

Write `.harness/current-cycle/review.md`:

```markdown
# Review: <ISSUE-ID>

**Base:** <ref> · **Files:** N · **Findings:** N blocking, N should-fix, N nits
**Coverage:** bugs ✓ · perf ✓ · security ✓ · contracts ✓ | skipped — <why>
<!-- an angle that failed twice: "security ✗ NOT COVERED — <what happened>" -->

## Blocking
### 1. <claim> — `file.ts:42`
**Angle:** correctness
**Failure scenario:** <concrete>
**Fix:** <what to change>

## Should fix
...

## Nits
...

## Acceptance criteria
- [x] Criterion 1 — met by `file.ts:88`
- [ ] Criterion 3 — not met: <why>

## Checked and clear
Brief: what the reviewers looked at and found nothing wrong with, including the
interfaces compared. This is what makes the empty sections trustworthy.
```

Deduplicate across angles — the same missing null check found by bugs and by security is
one finding with two reasons, not two findings.

Rank by severity, and within severity by blast radius. The reader fixes from the top.

## 5. Report

If an angle was not covered, say so first, before the counts. Then give the user the
counts and the blocking findings inline. Do not paste the whole file
into chat — it's on disk, and the point of the summary is that they can decide what to do
in ten seconds.

If there are zero findings, say that plainly and say what was checked. A review that
never finds nothing is a review that is inventing things.
