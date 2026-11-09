# numtide's llm-agents.nix: autolith lags (and a possible harness switch)

**Status 2026-11-09: observation only, nothing to deploy.** Looked at while
picking a source for the autolith harness
(`infra/modules/home/packages/autolith.nix`, commit `57b59f7c`).

## What the repo is

`github:numtide/llm-agents.nix` — Nix packages for AI coding agents and
development tools, ~200 entries (claude-code, pi, opencode and opencode2,
crush, codex, gemini-cli, autolith, …), an overlay and its own binary cache.
It **is** the old `numtide/nix-ai-tools`: that name 404s on the API now while
its git URL still resolves through GitHub's rename redirect. Updates run four
times a day (00/04/18/21 UTC) on a workflow that auto-merges, so most entries
track upstream releases within hours.

## How current it is (master @ 2026-11-09 vs upstream latest)

| package           | llm-agents.nix | upstream        |                    |
| ----------------- | -------------- | --------------- | ------------------ |
| `autolith`        | 0.41.2         | v0.67.28        | **stale**          |
| `pi`              | 1.5.0          | 1.5.0 (npm)     | current            |
| `claude-code`     | 2.1.319        | 2.1.319         | current            |
| `crush`           | 0.100.0        | v0.100.0        | current            |
| `codex`           | 0.167.0        | rust-v0.167.0   | current            |
| `gemini-cli`      | 0.67.0         | v0.67.0         | current            |
| `opencode` (1.x)  | 1.19.5         | v1.19.5         | current            |
| `opencode2` (2.x) | 2.2.6          | 2.2.6 (npm)     | current, and a patch ahead of our nixpkgs (2.2.5) |

## Why autolith is stuck

`packages/autolith/update.py` does not just bump a hash: at every new tag it
re-vendors upstream's `nix/package.nix` and rewrites it with regexes (it
inlines `native/fff/commit`, deletes `expectedSbclVersion` /
`expectedSbclSourceHash` and their assertion, turns `stdenv.isLinux` into
`stdenv.hostPlatform.isLinux`, and patches `sbcl.withPackages` around the empty
`--prefix` that `makeBinaryWrapper` rejects). Upstream's package.nix has
changed a lot between 0.41 and 0.67, so the transform no longer matches: the
last bump was 0.41.2 (PR #8488), the only later touch of that directory is a
manual `sbcl.withPackages` fix (#10195, 2026-10-01), and there is no open
update PR or issue about it.

A bumped llm-agents autolith also would not be the artifact
`nix run github:lambda-symbolics/autolith` produces: they build the vendored
package.nix against **their** nixpkgs and nixpkgs' SBCL, which is exactly what
upstream's SBCL/Quicklisp pin exists to prevent. That is why our harness keeps
upstream's own flake input (`flake.nix`, rev `173148ab`, 0.67.28) instead.

## Tasks

- [ ] **Update autolith in llm-agents.nix and open a PR.** Clone the repo, run
  `./packages/autolith/update.py` (it rewrites `hashes.json` and
  `upstream-package.nix`), repair `vendor_upstream_nix` where upstream's
  package.nix no longer matches the regexes, then `nix build .#autolith` and
  `nix run .#autolith` on x86_64-linux. PR title
  `autolith: 0.41.2 -> 0.67.28`; the body should say what the vendoring does and
  that dropping upstream's SBCL pin is deliberate. If the transform stays
  brittle, the alternative for them is to consume upstream's flake input
  directly, at the cost of a second nixpkgs — their call, not ours.
- [ ] **Consider their `opencode2` for our harness.** It ships the prebuilt
  npm/Bun binary (2.2.6, rpath-patched) instead of nixpkgs' `node_modules`
  build, so switching would retire `overlays.opencode` (the `prx9…` hash
  workaround and its "Temporary workarounds" row) and take `pi`/`claude-code`
  from the same input. Needs a decision on binary vs source packaging first,
  then a build.
