#!/usr/bin/env bash
# Pre-push gate: run the CI checks of every Rust project the pushed files
# touch. wotan's switch exports the public projects to GitHub without checking
# them (export-github.sh), so this is the last place a fmt, clippy or test
# failure is caught before GitHub CI reports it.
#
# The touched projects run in parallel (each has its own Cargo workspace and
# target/), each into its own log, printed whole when that project finishes so
# the output does not interleave. RUST_CI_JOBS=<n> caps how many run at once
# (default: all of them), e.g. for a `just update` push that touches every
# project and would otherwise compile all of them together.
#
# Usage: rust-ci-touched.sh --push                 (pre-push: the saved refs)
#        rust-ci-touched.sh <changed file>...      (check for these files)
#        rust-ci-touched.sh --projects <name>...   (check these rust/<name> directly)
# Skip once: LEFTHOOK_EXCLUDE=rust-ci git push
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ ${1:-} == --push ]]; then
  # --saved: lefthook runs the gates in parallel, so the push-refs job saved
  # git's refs first (its stdin cache cannot feed two jobs at once).
  files=()
  pushed=$(infra/scripts/pushed-files.sh --saved) || exit 1
  [[ -z $pushed ]] || mapfile -t files <<<"$pushed"
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
    # Brings up its own Postgres for the run and stops it again.
    internal-dashboard) just dashboard-ci ;;
    lanternd) just lanternd-ci ;;
    pglab) just pglab-ci ;;
    services) just services-ci ;;
    # Its own justfile. The Nix test check is what nix-checks.yml runs; it runs
    # the real-Postgres suite against a throwaway tmpfs cluster (scripts/test-pg.sh,
    # a unix socket, no port), the same one `just test` uses.
    homelab-mcp-servers)
      just -f rust/homelab-mcp-servers/justfile lint-ci &&
        (cd rust/homelab-mcp-servers && nix build --no-link -L .#checks.x86_64-linux.test)
      ;;
    # Its pinned nightly, as its ci.yml runs it: fmt, clippy and the tests, the
    # tests against a test Postgres (5435) that lives only for the run.
    hofvarpnir)
      (cd rust/hofvarpnir && nix develop .#default -c just with-db ci-gate)
      ;;
    *) echo "rust-ci: no CI mapped for rust/$1, skipping" ;;
  esac
}

logs=$(mktemp -d)
trap 'rm -rf "$logs"' EXIT

max=${RUST_CI_JOBS:-0}
declare -A running=() started=()
failed=()

# Wait for whichever project finishes next and print its log.
reap() {
  local pid p status=0
  wait -n -p pid "${!running[@]}" || status=$?
  p=${running[$pid]}
  unset "running[$pid]"
  echo "rust-ci: --- $p ($((SECONDS - started[$p])) s) ---"
  cat "$logs/$p.log"
  if ((status)); then
    echo "rust-ci: $p FAILED"
    failed+=("$p")
  fi
}

for p in $(printf '%s\n' "${!projects[@]}" | sort); do
  if ((max > 0 && ${#running[@]} >= max)); then
    reap
  fi
  echo "rust-ci: $p started"
  started[$p]=$SECONDS
  ci "$p" >"$logs/$p.log" 2>&1 &
  running[$!]=$p
done

while ((${#running[@]})); do
  reap
done

if ((${#failed[@]})); then
  echo "rust-ci: FAILED: ${failed[*]}" >&2
  exit 1
fi
