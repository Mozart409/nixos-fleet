#!/usr/bin/env bash
# Keep the subflake locks (rust/*/flake.lock, the standalone flakes of the
# GitHub exports and the private ones) on the root flake.lock's revisions, so an
# export builds with the monorepo's nixpkgs and toolchain.
#
# An input is shared when the root flake has an input of the same name with the
# same origin (type/owner/repo/ref). Shared inputs are pinned to the root's
# locked rev; every other input of a subflake is left alone. The check is pure
# jq over the lock files, no evaluation (the root's `follows` hide this drift
# from `rust-toolchain-sync`).
#
# Usage: subflake-locks.sh sync  [<dir>...]   re-lock (default: every subflake)
#        subflake-locks.sh check [<dir>...]   fail if a shared rev differs
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

mode=${1:-}
shift || true
case $mode in
  sync | check) ;;
  *)
    echo "usage: $0 sync|check [<subflake dir>...]" >&2
    exit 2
    ;;
esac

if (($# == 0)); then
  set -- rust/*/flake.lock
  set -- "${@%/flake.lock}"
fi

# One TSV row per shared input: name, subflake rev, root rev, root locked type,
# owner, repo.
shared() {
  jq -r --slurpfile root flake.lock '
    $root[0] as $r
    | .nodes as $n
    | .nodes.root.inputs | to_entries[]
    | select(.value | type == "string")
    | .key as $name
    | $n[.value] as $sub
    | $r.nodes.root.inputs[$name] as $rid
    | select($rid | type == "string")
    | $r.nodes[$rid] as $rn
    | select(($rn.original | {type, owner, repo, ref})
          == ($sub.original | {type, owner, repo, ref}))
    | [$name, $sub.locked.rev, $rn.locked.rev, $rn.locked.type,
       $rn.locked.owner, $rn.locked.repo]
    | @tsv' "$1/flake.lock"
}

status=0
for dir in "$@"; do
  dir=${dir%/}
  if [[ ! -f $dir/flake.lock ]]; then
    echo "error: $dir/flake.lock does not exist" >&2
    exit 1
  fi
  if [[ $mode == check ]]; then
    while IFS=$'\t' read -r name sub_rev root_rev _ _ _; do
      if [[ $sub_rev != "$root_rev" ]]; then
        echo "$dir: $name is ${sub_rev:0:8}, root has ${root_rev:0:8}" >&2
        status=1
      fi
    done < <(shared "$dir")
    continue
  fi
  overrides=()
  while IFS=$'\t' read -r name _ root_rev type owner repo; do
    if [[ $type != github ]]; then
      echo "error: $dir: $name is a $type input, only github is supported" >&2
      exit 1
    fi
    overrides+=(--override-input "$name" "github:$owner/$repo/$root_rev")
  done < <(shared "$dir")
  if ((${#overrides[@]} == 0)); then
    echo "$dir: no inputs shared with the root"
    continue
  fi
  echo "$dir: pinning $((${#overrides[@]} / 3)) shared input(s) to the root's revs"
  nix flake lock "./$dir" "${overrides[@]}"
done

if [[ $mode == check && $status != 0 ]]; then
  echo "Subflake locks drifted from the root flake.lock; run \`just lock-subs\`." >&2
fi
exit "$status"
