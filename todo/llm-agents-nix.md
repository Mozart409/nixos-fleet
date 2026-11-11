# numtide's llm-agents.nix: a possible source for opencode2

**Status 2026-11-09: observation only, nothing to deploy.** Looked at while
choosing sources for the agent harnesses.

## What the repo is

`github:numtide/llm-agents.nix` — Nix packages for AI coding agents and
development tools, ~200 entries (claude-code, pi, opencode and opencode2,
crush, codex, gemini-cli, …), an overlay and its own binary cache.
It **is** the old `numtide/nix-ai-tools`: that name 404s on the API now while
its git URL still resolves through GitHub's rename redirect. Updates run four
times a day (00/04/18/21 UTC) on a workflow that auto-merges, so most entries
track upstream releases within hours.

## How current it is (master @ 2026-11-09 vs upstream latest)

| package           | llm-agents.nix | upstream        |                    |
| ----------------- | -------------- | --------------- | ------------------ |
| `pi`              | 1.5.0          | 1.5.0 (npm)     | current            |
| `claude-code`     | 2.1.319        | 2.1.319         | current            |
| `crush`           | 0.100.0        | v0.100.0        | current            |
| `codex`           | 0.167.0        | rust-v0.167.0   | current            |
| `gemini-cli`      | 0.67.0         | v0.67.0         | current            |
| `opencode` (1.x)  | 1.19.5         | v1.19.5         | current            |
| `opencode2` (2.x) | 2.2.6          | 2.2.6 (npm)     | current, and a patch ahead of our nixpkgs (2.2.5) |

## Tasks

- [ ] **Consider their `opencode2` for our harness.** It ships the prebuilt
  npm/Bun binary (2.2.6, rpath-patched) instead of nixpkgs' `node_modules`
  build, so switching would retire `overlays.opencode` (the `prx9…` hash
  workaround and its "Temporary workarounds" row) and take `pi`/`claude-code`
  from the same input. Needs a decision on binary vs source packaging first,
  then a build.
