---
name: sdlc-plan
description: Turn a Linear issue into an implementation plan grounded in the actual codebase — acceptance criteria, files to touch, approach, test strategy, risks. Use whenever the user references a ticket by ID or URL (ENG-142, LIN-7, a linear.app link) and wants to work on it, or says "plan this", "how would you approach this ticket", "what's the plan for X". Use it before writing code for any non-trivial ticket, since a plan on disk is what the review and PR phases hold the change against later.
---

# Plan

Turn a ticket into a plan someone could hand to a different engineer.

The failure mode this phase exists to prevent: reading a ticket, feeling like you
understand it, and starting to type. Half of what a ticket means lives in the codebase,
not in the ticket. The plan is where those two meet.

## 1. Read the ticket

If the Linear MCP server is connected, fetch the issue by ID: title, description,
comments, labels, current state, linked issues. Comments matter more than they look —
they are usually where the requirement actually got decided.

If Linear is unavailable, ask the user to paste the ticket. Do not invent the
requirement from the ID.

If the ticket has attached designs, images, or a Figma link, look at them. A ticket that
says "match the design" is not specified by its text.

## 2. Explore the codebase before deciding anything

Exploration is worth doing in proportion to how much existing code the change has to fit
into. On a mature repo that is most of the planning work. On an empty one there is
nothing to fit into, and spawning agents to discover that wastes minutes and teaches you
that this skill's instructions are decorative — which then costs you on the steps that
matter. Look at what is actually there first, and if the answer is "almost nothing", write
one line in the plan saying so and move to step 3.

When there is code to explore, spawn `Explore` subagents to answer concrete questions in
parallel — where does this behavior live now, what tests cover it, what patterns does
this repo already use for this kind of change, who calls the thing you are about to
change.

Ask for the questions you actually need answered, not "explore the auth code". Vague
delegation returns a file tour; a question returns an answer.

The output you want from this step is: the change fits the repo's existing shape, or you
know exactly why it can't and what that costs.

## 3. Write the plan

Write `.harness/current-cycle/plan.md`, creating the directory if needed. Use this
structure — the ship phase parses it to build the PR body, and the review phase reads
the acceptance criteria to judge the diff:

```markdown
# <ISSUE-ID>: <title>

**Link:** <linear url>
**Status:** planned

## Problem
What is broken or missing, in terms of what a user or caller experiences.
Not the proposed solution.

## Acceptance criteria
- [ ] Checkable statements. A reviewer must be able to say yes or no to each
      by looking at the diff or running something.

## Files to touch
| Path | Change |
|---|---|
| `src/...` | what happens here and why |

## Approach
Numbered steps, in the order they should be done. Each step small enough to
verify before the next one starts.

## Test strategy
Which tests to add or change, and what failure each one would actually catch.
"Add unit tests" is not a strategy.

## Risks
What could break that is not obviously in scope — callers you found in step 2,
migrations, data shape changes, anything with a rollback question.

## Out of scope
Named explicitly, so review does not flag it and the PR does not sprawl.

## Open questions
Only genuine blockers. Empty is the healthy case.
```

## 4. Handle open questions honestly

If an open question would change the approach, stop and ask the user. That is the one
place in this cycle where blocking is correct — proceeding on a wrong assumption means
implementing, reviewing, and shipping the wrong thing.

If it would not change the approach, do not ask. Write the assumption down under Risks
and continue. Most questions are this kind, and treating them as blockers is how a
harness becomes something the user routes around.

## 5. Offer the ticket update

Offer to post the plan summary as a Linear comment and move the issue to In Progress.
Both write to a system other people read, so ask first and do it only on a yes.

## Scaling down

A one-line fix does not need eight sections. Keep Problem, Acceptance criteria, and
Approach; drop the rest. The point is a plan proportional to the risk, and ceremony on a
typo fix teaches the user to skip the phase entirely.
