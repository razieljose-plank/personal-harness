# personal-harness

A personal SDLC harness for Claude Code: five skills that take a ticket from Linear to a
merged PR, three adversarial review subagents, three hooks, and a permission set tuned to
stop asking about things that are always fine.

## Why this exists

A model on its own generates text. A harness is what turns it into something that does
work: tools, context, a loop, limits, and — the part that matters most — **a source of
truth at every step that isn't the model's own opinion.** Tests that fail, a review that
finds a real bug, a hook that refuses a bad commit. Without those signals the agent
decides for itself that it's finished, and it is usually wrong.

This repo is that scaffolding, applied to the whole development cycle instead of just the
"write the code" step.

## The cycle

```
Linear issue ──▶ plan ──▶ implement ──▶ review ──▶ ship ──▶ distill ──┐
                  ▲                                                     │
                  └──────────── next cycle starts smarter ◀─────────────┘
```

| Phase | Skill | In | Out |
|---|---|---|---|
| Plan | `sdlc-plan` | Linear issue | `.harness/current-cycle/plan.md` |
| Implement | `sdlc-implement` | the plan | code + `notes.md` |
| Review | `sdlc-review` | the diff | `review.md` |
| Ship | `sdlc-ship` | plan + diff | conventional commit + PR |
| Distill | `sdlc-distill` | everything | `CLAUDE.md`, skills, memory |

`sdlc` runs the whole thing and enforces the gates between phases. Each phase also works
standalone — `/sdlc-review` on any diff is useful on its own.

### State lives on disk, not in the conversation

Every phase reads its input from `.harness/current-cycle/` and writes its output back
there. Context gets compacted and sessions end; a plan that exists only in a transcript
evaporates, and a plan on disk is something the review phase can hold the diff against.
It's also what lets a `SessionStart` hook tell a brand-new session that there's work in
flight.

`.harness/` is gitignored. Finished cycles are archived to `.harness/cycles/<date>-<id>/`.

## Adversarial review

Three subagents read the same diff from angles that don't overlap — correctness,
performance, security — and run in parallel. They're read-only by construction, so no
reviewer can "fix" the code out from under the other two.

Every finding then goes through a verification pass before it reaches you: does the line
say what the finding claims, is the path reachable, is it already tested, was it already
broken before this diff. Adversarial prompts produce confident nonsense, and a review
that's half false positives gets skimmed once and ignored forever. Findings must carry a
concrete failure scenario — inputs → wrong behavior — because that's the field that makes
verification possible at all.

## Hooks

| Hook | Event | What it does |
|---|---|---|
| `post-edit-format.sh` | `PostToolUse` on `Edit\|Write` | Formats the edited file using the **project's own** toolchain. Silent no-op if the project has none. |
| `guard-commit.sh` | `PreToolUse` on `Bash`, filtered to `git commit` | **Blocks** secrets, `.env`/key files, and commits to `main`. **Warns** about `console.log`, `debugger`, `.only(`. |
| `session-start-cycle.sh` | `SessionStart` | Announces an in-flight cycle so a new session resumes instead of re-planning. |

The severity split in `guard-commit` is deliberate: a leaked secret is expensive to undo,
so it blocks; a stray `console.log` is not, so it warns. Blocking on small things trains
you to route around the hook, and a hook you route around protects nothing.

The initial commit of a repository is exempt from the `main` block — there is no other
branch to move to yet.

**On the `if` filter.** Measured behavior: `if: "Bash(git commit *)"` over-fires on long
compound commands — a multi-line script containing a heredoc and no git invocation at all
was matched and blocked. So `guard-commit.sh` re-parses `tool_input.command` itself and
exits immediately unless the command really is a `git commit`. The `if` field is treated
as a cheap pre-filter, not as the check. Verified against 11 cases, including
`git commit-tree` (correctly ignored) and `git -c user.name=x commit` (correctly caught).

The general lesson, and the reason it's written up here: **a guard that occasionally
refuses unrelated work gets switched off**, and then it protects nothing. False positives
are not a cosmetic problem in a harness — they are the failure mode.

**Known limitation:** the guard inspects the repository at the **session's** working
directory, not the one the command targets, so `git -C ../other-repo commit` is checked
against the wrong repo. In normal use they're the same directory.

The `console.log` warning also matches documentation that *mentions* `console.log` — this
README triggers it. It's a warning rather than a block, so the noise is survivable.

## Install

```bash
./install.sh      # symlinks skills + agents into ~/.claude, merges settings (backs up first)
./setup-mcp.sh    # registers the Linear MCP server at user scope
gh auth login     # GitHub goes through the CLI, not through MCP
```

Then run `/mcp` in a session to complete Linear's browser OAuth. Registering a server
is not the same as being signed in to it.

**GitHub is deliberately not an MCP server here.** Its endpoint rejects Claude Code's
OAuth flow (`does not support dynamic client registration`) and wants a hand-made PAT in
a header. The `gh` CLI covers everything the harness asks of GitHub — PR create, view,
diff, checks — with no credential sitting in a config file and a fraction of the context
cost of the MCP server's tool definitions.

Skills and agents are symlinked, so edits in this repo take effect in the next session
with no reinstall.

Settings are **merged**: permission rules are unioned, and this harness's hooks are
replaced by command path so reinstalling never duplicates them or disturbs anything else
in your `settings.json`.

## Permissions

The allow-list pre-approves things that are always fine — read-only git, test and lint
runners, read-only `gh`, and read-only Linear MCP tools. Writes to external systems still
prompt, because "stop asking me" and "post to my team's tracker without asking" are
different requests.

Three syntax rules that cost real debugging time if you get them wrong:

- Path rules are only consulted for `Read()` and `Edit()`. A `Write(docs/**)` rule is
  accepted and then **never used** — write `Edit(docs/**)` instead.
- In *user* settings, `/path` anchors to `~/.claude`, not to your project. Use a bare
  filename (`Read(.env)`, gitignore semantics, matches at any depth), `~/`, or `//`.
- Allow rules for MCP tools need a literal `mcp__<server>__` prefix before any glob.
  `mcp__*` in an allow list is skipped with a warning.

Optional, not enabled by default: setting `permissions.defaultMode` to `acceptEdits` stops
the per-edit prompts entirely. It's a real change in posture, so turn it on deliberately
rather than inheriting it from this repo.

## Layout

```
skills/     five SDLC phase skills + the sdlc orchestrator
agents/     three read-only adversarial reviewers
hooks/      three shell hooks
settings/   settings.template.json, merged by install.sh
```
