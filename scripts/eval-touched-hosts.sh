#!/usr/bin/env bash
# Pre-push gate: evaluate only the NixOS configurations the pushed files can
# affect. Never a full `nix flake check` -- that evaluates every host and gets
# OOM-killed. Logic carried over from the archived Woodpecker pipeline
# (docs/archive/woodpecker/pve/nix.yml).
#
# Usage: eval-touched-hosts.sh --push              (pre-push: git's refs on stdin)
#        eval-touched-hosts.sh <changed file>...   (evaluate for these files)
#        eval-touched-hosts.sh --hosts <host>...   (evaluate these hosts directly)
# Skip once: LEFTHOOK_EXCLUDE=host-eval git push
#
# Not lefthook's {push_files}: for a branch without an upstream (every agent
# branch) it is `git diff HEAD origin/main`, a two-dot diff that also counts
# everything merged to main since the branch was cut, so a vault-only push
# evaluated wotan and the fleet (~8 min).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Files the pushed refs change: <local ref> <local sha> <remote ref> <remote
# sha> per line. An update diffs against what the remote has; a new branch
# against its merge-base with main, so only the branch's own commits count.
pushed_files() {
  local zero=0000000000000000000000000000000000000000
  local _lref lsha _rref rsha base
  while read -r _lref lsha _rref rsha; do
    [[ $lsha == "$zero" ]] && continue # branch deletion
    if [[ $rsha != "$zero" ]] && git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      base=$rsha
    else
      base=$(git merge-base "$lsha" origin/main 2>/dev/null) || base=$(git hash-object -t tree /dev/null)
    fi
    git diff --name-only "$base" "$lsha" --
  done
}

if [[ ${1:-} == --push ]]; then
  mapfile -t files < <(pushed_files | sort -u)
  set -- "${files[@]}"
fi

# Representative fleet hosts for changes to shared fleet code: dns is a plain
# mkHost node (common.nix + the home-manager/nixvim layer), agents is the agent
# platform host (multica-daemon, and the coding harness once its zones land).
#
# The second slot used to be `development`, then `zeroclaw`; all three harness
# hosts (development, hermes, zeroclaw) were decommissioned on 2026-10-06 and
# `agents` (2026-10-07) took the slot.
fleet=(dns agents)

declare -A hosts=()
add() { for h in "$@"; do hosts[$h]=1; done; }

if [[ ${1:-} == --hosts ]]; then
  shift
  add "$@"
else
  for f in "$@"; do
    case "$f" in
      # aarch64 SD images; this x86_64 machine does not evaluate them.
      infra/hosts/rpi*) ;;
      # The directory name differs from the flake attribute.
      infra/hosts/mcp_vm/*) add mcp ;;
      infra/hosts/*/*)
        d=${f#infra/hosts/}
        add "${d%%/*}"
        ;;
      # Desktop-only code: no fleet host imports these.
      infra/modules/wotan/* | infra/modules/desktop/* | infra/modules/home/* | infra/lib/*) add wotan ;;
      infra/modules/* | infra/pkgs/*) add "${fleet[@]}" ;;
      # Read at eval time by modules/coding-harness.nix, which no live host
      # imports (see the fleet note above) -- dns is the catch-all so the push
      # is not silently ungated.
      .opencode/*) add "${fleet[@]}" ;;
      flake.nix | flake.lock) add wotan "${fleet[@]}" ;;
    esac
  done
fi

if ((${#hosts[@]} == 0)); then
  echo "host-eval: no NixOS config touched, nothing to evaluate"
  exit 0
fi

attrs=$(nix eval --json .#nixosConfigurations --apply builtins.attrNames)
failed=()
for h in $(printf '%s\n' "${!hosts[@]}" | sort); do
  # A hosts/<dir> can exist without a flake attribute (commented out or
  # retired, e.g. k3s-cntrl-1). A name lookup, not an evaluation.
  if [[ $attrs != *"\"$h\""* ]]; then
    echo "host-eval: $h has no nixosConfigurations attribute, skipping"
    continue
  fi
  echo "host-eval: $h"
  if ! nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" >/dev/null; then
    failed+=("$h")
  fi
done

if ((${#failed[@]})); then
  echo "host-eval: FAILED: ${failed[*]}" >&2
  exit 1
fi
