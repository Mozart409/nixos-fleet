#!/usr/bin/env bash
# Pre-push gate: run the CI checks of every Rust project the pushed files
# touch. wotan's switch exports the public projects to GitHub without checking
# them (export-github.sh), so this is the last place a fmt, clippy or test
# failure is caught before GitHub CI reports it.
#
# Usage: rust-ci-touched.sh --push                 (pre-push: git's refs on stdin)
#        rust-ci-touched.sh <changed file>...      (check for these files)
#        rust-ci-touched.sh --projects <name>...   (check these rust/<name> directly)
# Skip once: LEFTHOOK_EXCLUDE=rust-ci git push
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ ${1:-} == --push ]]; then
  mapfile -t files < <(infra/scripts/pushed-files.sh)
  set -- "${files[@]}"
fi

declare -A projects=()
add() { for p in "$@"; do projects[$p]=1; done; }

if [[ ${1:-} == --projects ]]; then
  shift
  add "$@"
else
  for f in "$@"; do
    case "$f" in
      # The one toolchain every project builds with.
      rust/toolchain.nix)
        for d in rust/*/; do
          d=${d%/}
          add "${d#rust/}"
        done
        ;;
      rust/*/*)
        d=${f#rust/}
        add "${d%%/*}"
        ;;
    esac
  done
fi

if ((${#projects[@]} == 0)); then
  echo "rust-ci: no Rust project touched, nothing to check"
  exit 0
fi

# What each project's CI runs, as close as a local run gets.
ci() {
  case "$1" in
    axon-gateway) just axon-ci ;;
    countdown-rs) just countdown-ci ;;
    fafnir) just fafnir-ci ;;
    homelab-dashboard) just hdash-ci ;;
    internal-dashboard) just dashboard-ci ;;
    lanternd) just lanternd-ci ;;
    pglab) just pglab-ci ;;
    services) just services-ci ;;
    # Its own justfile. The Nix test check is what nix-checks.yml runs; the
    # real-Postgres suite stays `just test`.
    homelab-mcp-servers)
      just -f rust/homelab-mcp-servers/justfile lint-ci &&
        (cd rust/homelab-mcp-servers && nix build --no-link -L .#checks.x86_64-linux.test)
      ;;
    # Its pinned nightly, as its ci.yml runs it. The tests need Postgres.
    hofvarpnir)
      (cd rust/hofvarpnir && nix develop .#default -c sh -c \
        'cargo fmt --all -- --check && SQLX_OFFLINE=true cargo clippy --workspace --all-targets --all-features -- -D warnings')
      ;;
    *) echo "rust-ci: no CI mapped for rust/$1, skipping" ;;
  esac
}

failed=()
for p in $(printf '%s\n' "${!projects[@]}" | sort); do
  echo "rust-ci: $p"
  if ! ci "$p"; then
    failed+=("$p")
  fi
done

if ((${#failed[@]})); then
  echo "rust-ci: FAILED: ${failed[*]}" >&2
  exit 1
fi
