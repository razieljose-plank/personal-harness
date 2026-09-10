# personal-harness

This repo is a Claude Code harness: skills, subagents, hooks, and settings that run an
SDLC cycle. It contains almost no application code — the "code" here is instructions that
another Claude session will read and act on.

## What that means for changes here

**Skills are prompts, not programs.** They are read by a model with judgment, not executed
by an interpreter. Write them to explain *why* something matters, so the reading session
can generalize to the case you didn't anticipate. A wall of MUST/NEVER produces rigid
behavior that breaks the moment reality differs from the example.

**Every line costs context.** A skill's body loads whenever it triggers, and the
description loads in *every* session. Length is a real cost paid on every run, so cut
anything that isn't pulling its weight.

**The description field is the trigger.** It decides whether the skill fires at all, so it
has to name concrete situations and phrasings a user would actually type — not just what
the skill does. Under-triggering is the common failure.

## Testing changes

Hooks are shell scripts and can be tested directly by piping the event JSON they expect:

```bash
echo '{"tool_input":{"file_path":"/tmp/x.ts"},"cwd":"/tmp"}' | ./hooks/post-edit-format.sh
```

Check the exit code — `2` blocks the tool call, anything else lets it through. Verify a
hook actually fires before trusting it; a misconfigured hook fails silently, which is the
worst possible failure mode for a guard.

Skills are tested by using them on a real ticket. If a phase produced a bad result, fix
the skill rather than working around it in the session — that feedback loop is the whole
point of `sdlc-distill`.

## Conventions

- All documentation, comments, skills, and commit messages in **English**.
- Conventional commits.
- Hook scripts: `set -uo pipefail`, exit `0` unless deliberately blocking, and never
  depend on a globally installed tool — detect the project's own toolchain and no-op when
  it is absent.
