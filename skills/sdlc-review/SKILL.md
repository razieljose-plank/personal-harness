---
name: sdlc-review
description: Adversarially review a change with parallel subagents attacking it from different angles — correctness and edge cases, performance, security — then verify each finding and aggregate into one ranked report. Use whenever the user asks to review a diff, a branch, or a PR, says "review this", "attack this change", "what did I miss", "is this safe to merge", or finishes implementing something before shipping it. Prefer this over reading the diff yourself, because one reader with one mental model misses the classes of bug the other angles are looking for.
---

# Adversarial Review

Three reviewers attack the change from angles that do not overlap, then every finding
has to survive a verification pass before it reaches the user.

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

If the diff is empty, stop and say so rather than reviewing the working tree by accident.

## 2. Launch three reviewers in parallel

Spawn all three in a single message so they run concurrently. Use the dedicated agents —
`review-bugs`, `review-perf`, `review-security` — which are read-only by construction so
a reviewer cannot "helpfully" fix what it found and invalidate the diff underneath the
other two.

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
Brief: what the reviewers looked at and found nothing wrong with. This is what
makes the empty sections trustworthy.
```

Deduplicate across angles — the same missing null check found by bugs and by security is
one finding with two reasons, not two findings.

Rank by severity, and within severity by blast radius. The reader fixes from the top.

## 5. Report

Give the user the counts and the blocking findings inline. Do not paste the whole file
into chat — it's on disk, and the point of the summary is that they can decide what to do
in ten seconds.

If there are zero findings, say that plainly and say what was checked. A review that
never finds nothing is a review that is inventing things.
