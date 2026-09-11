---
name: sdlc-plan
description: Turn a Linear issue into an implementation plan grounded in the actual codebase — acceptance criteria, how the change fits the system, the architecture decisions it needs (proposed for the engineer to make, never made silently), files to touch, approach, test strategy, risks. Use whenever the user references a ticket by ID or URL (ENG-142, LIN-7, a linear.app link) and wants to work on it, or says "plan this", "how would you approach this ticket", "what's the plan for X". Use it before writing code for any non-trivial ticket, since a plan on disk is what the review and PR phases hold the change against later.
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
the acceptance criteria and the architecture decisions to judge the diff:

```markdown
# <ISSUE-ID>: <title>

**Link:** <linear url>
**Status:** planned
**Approval:** _pending_ — who approved the architecture decisions, and when

## Problem
What is broken or missing, in terms of what a user or caller experiences.
Not the proposed solution.

## Acceptance criteria
- [ ] Checkable statements. A reviewer must be able to say yes or no to each
      by looking at the diff or running something.

## How this fits the system
The modules this touches, how data flows through them before and after the change,
and what depends on what. Written so the engineer can check it against the picture
in their head — if anything here surprises them, that is the most important finding
in the plan.

## Architecture decisions
Choices that shape the system beyond this ticket. Proposed here, never decided here.

### AD-1: <the decision to be made>
- **Options:** <A> / <B>
- **Trade-offs:** <what each one costs>
- **Recommendation:** <which, and why>
- **Decision:** _pending_

Or: "None — <why this change stays inside existing boundaries>".

## Files to touch
| Path | Change |
|---|---|
| `src/...` | what happens here and why |

## Approach
Numbered steps, in the order they should be done. Each step small enough to verify
before the next one starts. Every step follows from an approved decision above; a
step that needs a new one means the plan is not finished.

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

## 4. Separate the decisions that are not yours to make

A plan contains two kinds of decision, and they get different treatment.

**Architecture decisions belong to the engineer.** Module boundaries, how data flows
between parts of the system, the data model, new dependencies, patterns other code will
be expected to follow. The engineer has to hold the whole system in their head — that
picture is what lets them debug it, review someone else's change, and design the next
feature. Every architecture decision made for them is a part of their own system they no
longer fully understand, and a harness that does this is quietly spending the one asset
it cannot replace.

So never decide these. Put each one in the Architecture decisions section as a choice:
the real options, the trade-offs, and your recommendation. The recommendation is useful —
you have read the code — but it is input to their decision, not a substitute for it.

**Implementation details are yours.** Names, helper functions, the internal structure of
a module, the order of steps. Decide them, write any assumption under Risks, and do not
ask. Asking about these is how a harness becomes something the user routes around.

**Telling them apart.** Would someone working on a different part of the system next
month need to know this? Would undoing it later touch more than this change? If either
answer is yes, it is architecture. If you cannot tell, treat it as architecture — asking
costs a minute, and a silently made decision costs the engineer their picture of the
system.

Open questions about the ticket itself — what it means, what it needs — still go to the
user when the answer would change the plan.

## 5. Get the plan approved

Present the plan to the user, leading with How this fits the system and the Architecture
decisions, since those are the parts only they can judge. Wait for an explicit choice on
each architecture decision and record it in `plan.md`: fill in each **Decision** with what
they chose, and set **Approval** to who approved and when.

If the plan has no architecture decisions, say so and say why. "None" is itself a claim
you can get wrong, and it is the one that matters most — the user confirms it like
anything else.

Do not start implementing before this. The implement phase treats the recorded decisions
as its contract, and the review phase checks the diff against them; without a recorded
approval, both of those checks are measuring against nothing.

## 6. Offer the ticket update

Offer to post the plan summary as a Linear comment and move the issue to In Progress.
Both write to a system other people read, so ask first and do it only on a yes.

## Scaling down

A one-line fix does not need every section. Keep Problem, Acceptance criteria, Approach,
and Architecture decisions — even when the entry is "none, because it only changes X" —
and drop the rest. Ceremony on a typo fix teaches the user to skip the phase, but a
skipped architecture check is exactly how a "small" change ends up moving a module
boundary.
