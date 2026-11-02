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
  # Rerun with the files of the refs the push-refs job saved (lefthook runs
  # the gates in parallel, and its stdin cache cannot feed two jobs at once).
  exec infra/scripts/pushed-files.sh --exec "${BASH_SOURCE[0]}"
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

# The crane checks of rust/<dir> (the root flake's rustChecksFor): what its
# `just <prefix>-ci` compiles, as Nix builds, so a project whose source the
# store has already checked costs an evaluation, not a compile. The suites
# that need Postgres get one inside the build (rust/test-postgres.nix).
#
# One evaluation for every touched project, then each builds its derivation:
# parallel `nix build .#…` calls would each evaluate the flake again and
# contend for the eval cache's SQLite lock.
declare -A drv=()
names=$(printf '"%s" ' "${!projects[@]}")
drvs=$(nix eval --json .#legacyPackages.x86_64-linux.rust-ci --apply \
  "c: builtins.mapAttrs (_: d: d.drvPath) (builtins.intersectAttrs (builtins.listToAttrs (map (name: {inherit name; value = null;}) [ $names ])) c)")
while read -r p d; do
  drv[$p]=$d
done < <(jq -r 'to_entries[] | "\(.key) \(.value)"' <<<"$drvs")

nix_ci() {
  nix build --no-link -L "${drv[$1]}^*"
}

# What each project's CI runs, as close as a local run gets. The steps left to
# just compile nothing: cargo deny/audit fetch the advisory database (a build
# has no network), keep-sorted lints files.
ci() {
  case "$1" in
    axon-gateway) nix_ci axon-gateway && just axon-deny axon-audit ;;
    countdown-rs) nix_ci countdown-rs && just countdown-audit countdown-deny ;;
    fafnir) nix_ci fafnir ;;
    homelab-dashboard) nix_ci homelab-dashboard && just hdash-deny ;;
    internal-dashboard) nix_ci internal-dashboard && just dashboard-sorted-check ;;
    lanternd) nix_ci lanternd ;;
    pglab) nix_ci pglab ;;
    services) nix_ci services && just services-rust-audit services-rust-deny ;;
    # Its checks also cover lint-ci's toolchain-pin, and actionlint.
    homelab-mcp-servers) nix_ci homelab-mcp-servers && just -f rust/homelab-mcp-servers/justfile deny ;;
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
