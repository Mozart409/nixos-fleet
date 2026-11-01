#!/usr/bin/env bash
# Pre-commit: rustfmt the staged .rs files with their own project's settings.
#
# Only the root lefthook.yml runs in the monorepo; the projects' own
# lefthook.yml (with their `cargo fmt` jobs) only run in their public repos.
# Each project keeps its own Cargo workspace, so this runs one `cargo fmt` per
# workspace the staged files belong to, found with `cargo locate-project`: a
# new project needs no hook change. Files outside a parsable Cargo project
# (e.g. the cargo-generate templates' placeholders) are skipped. Lefthook's
# stage_fixed re-stages the rewritten files.
#
# Usage: rust-fmt-staged.sh <file.rs>...   (paths relative to the repo root)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

declare -A roots=()
for f in "$@"; do
  manifest=$(cd "$(dirname "$f")" && cargo locate-project --workspace --message-format plain 2>/dev/null) || continue
  roots[${manifest%/Cargo.toml}]=1
done

for root in "${!roots[@]}"; do
  echo "rust-fmt: ${root#"$PWD"/}"
  (cd "$root" && cargo fmt --all)
done
