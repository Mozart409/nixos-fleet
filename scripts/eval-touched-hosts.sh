#!/usr/bin/env bash
# Pre-push gate: evaluate only the NixOS configurations the pushed files can
# affect. Never a full `nix flake check` -- that evaluates every host and gets
# OOM-killed. Logic carried over from the archived Woodpecker pipeline
# (docs/archive/woodpecker/pve/nix.yml).
#
# Usage: eval-touched-hosts.sh <changed file>...   (lefthook passes {push_files})
#        eval-touched-hosts.sh --hosts <host>...   (evaluate these hosts directly)
# Skip once: LEFTHOOK_EXCLUDE=host-eval git push
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Representative fleet hosts for changes to shared fleet code: dns is a plain
# mkHost node (common.nix + the home-manager/nixvim layer), development carries
# the coding harness (claude/opencode/herdr modules, .opencode skills).
fleet=(dns development)

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
      # Read at eval time by modules/coding-harness.nix.
      .opencode/*) add development ;;
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
