#!/usr/bin/env bash
# Every rust/*/rust-toolchain.toml must be byte-identical to the root's
# rust-toolchain.toml: the file is the monorepo's single Rust version literal,
# and every flake derives its toolchain from its own copy via fenix's
# fromToolchainName. rust-toolchain-sync proves agreement only when someone
# runs the eval, so this check catches a lone edited copy at commit time
# (pure cmp, no evaluation; same split as subflake-locks.sh).
#
# Usage: toolchain-files.sh check
set -euo pipefail

[[ ${1:-} == check ]] || {
  echo "usage: $0 check" >&2
  exit 2
}

cd "$(git rev-parse --show-toplevel)"

[[ -f rust-toolchain.toml ]] || {
  echo "error: rust-toolchain.toml does not exist at the repo root" >&2
  exit 1
}

status=0
shopt -s nullglob
for f in rust/*/rust-toolchain.toml; do
  if ! cmp -s rust-toolchain.toml "$f"; then
    echo "$f differs from the root rust-toolchain.toml" >&2
    status=1
  fi
done
if [[ $status != 0 ]]; then
  echo "Copy the root file over it (cp, never hand-edit a copy) and rerun." >&2
fi
exit $status
