---
name: delegate-implementation
description: Hand code changes to cheap Haiku and Sonnet subagents while Opus plans, reviews and runs the single final fmt/lint/test pass. Use whenever a task writes or changes any code in any language — Nix modules, hosts and flakes, Rust, shell, Go, Erlang, JS/TS, SQL, CI and build files, config — or docs, for features, fixes, refactors, migrations and multi-file changes. This is the user's standing instruction to spawn subagents for implementation.
---

# Delegate implementation

The user wants implementation done by cheap subagents and verification done
once, by you (Opus). This skill is their explicit request to spawn subagents for
that, so the usual "don't spawn unless asked" default does not apply to
implementation work.

## Roles

| Who | Model | Does | Never does |
| --- | --- | --- | --- |
| You | Opus | read the task, explore just enough, split it, write briefs, review diffs, run the final pass, commit if asked | bulk typing that a brief could cover |
| Implementer | `haiku` | mechanical work: renames, boilerplate, following a pattern you spelled out, config/doc edits, adding a field through layers | design decisions |
| Implementer | `sonnet` | real logic: new functions or modules, non-obvious bug fixes, multi-file features, anything needing judgement | — |

Pick Haiku whenever the brief can name the exact edits; Sonnet when the
subagent has to work out what the code should be. When unsure, Sonnet.

This covers every language and file type the same way: Nix (modules, hosts,
flakes, packages, overlays) as much as Rust, shell, Go, Erlang, JS/TS, SQL, CI
workflows, justfiles and config. Nix is not "just config" — delegate it.

Do it yourself, without subagents, only when the whole change is one or two
lines.

## Steps

1. **Understand.** Read the relevant code and the directory's `AGENTS.md`
   yourself. Decide the design. Subagents get decisions, not open questions.
2. **Split.** Cut the work into slices that touch disjoint files. Independent
   slices run in parallel (several Agent calls in one message); a slice that
   needs another's output runs after it. Never give two running subagents the
   same file.
3. **Dispatch.** One Agent call per slice: `subagent_type: "general-purpose"`,
   `model: "haiku"` or `"sonnet"`, and a self-contained brief (template below).
4. **Review.** When each returns, read its `git diff` for the files it touched
   — not its prose summary alone. Check it did what the brief said, nothing
   more, and matches the surrounding code. Send a correction back with
   SendMessage to the same agent (it keeps its context), or fix small things
   yourself.
5. **Final pass (you, once, after all slices are in).**
   - Format: the project's formatter (`cargo fmt`, `alejandra`, `just fmt`,
     the `<prefix>-fmt` recipe …).
   - Lint: clippy / the project's lint recipe, warnings denied as the project
     configures.
   - Test: the project's test or CI recipe (e.g. `just <prefix>-ci`, which
     includes the DB tests via `-with-db`). For Nix changes, evaluate only the
     hosts you touched (never a bare `nix flake check`).
   - Fix failures yourself if small; otherwise hand the error output to the
     implementer that wrote the code (SendMessage) and re-run the pass. Repeat
     until green.
6. **Report** what changed and the exact gate results. If something stays red,
   say so with the output — do not call it done.

## Brief template

```
Goal: <one sentence, the outcome>

Context: <the facts it needs that it cannot cheaply find: design decision,
types/functions to use, conventions, the pattern to copy (file:line)>

Edit only: <exact files; create these new files: …>
Out of scope: <anything nearby it must not touch>

Steps: <for Haiku, the concrete edits; for Sonnet, the behaviour wanted and
any constraints>

Rules:
- Do NOT run tests, linters, formatters, type-checks or builds (no cargo
  test/check/clippy/fmt, no nix build/eval, no just recipes, no alejandra,
  no npm/go/etc. equivalents). The orchestrator runs them once at the end.
- Do NOT stage, commit, or touch git state.
- Match the surrounding code's style, naming and comment density; write it as
  formatted as you can by eye.
- If the brief is wrong or something blocks you, stop and say so instead of
  improvising a different design.

Reply with: files changed, a two-line summary per file, and any doubts or
places you were unsure (with file:line).
```

## Notes

- Keep briefs short but complete: the subagent starts cold and sees only the
  brief plus what it reads.
- Do not re-read whole files a subagent wrote; the diff is enough.
- Cost is the point: no Opus subagents for implementation, and no gates run
  inside subagents.
