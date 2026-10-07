#!/usr/bin/env bash

set -euo pipefail

# Before the cd below, which would break a relative $0.
# shellcheck source=infra/hosts/wotan/banner.sh
source "$(dirname "${BASH_SOURCE[0]}")/banner.sh"

# The flake lives at the yggdrasil root, two levels above infra/hosts/wotan.
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

clear

banner 'switching ...'

# -r stages the new configuration as the boot default instead of switching the
# live system. Needed after flake updates that bump the NVIDIA driver: a live
# switch runs the container CDI generator against the new userspace libs while
# the old kernel module is still loaded (NVML mismatch) and the unit fails
# (see AGENTS.md pitfall #8). Rebooting is left to the user.
mode=switch
while (($#)); do
  case "$1" in
  -r) mode=boot ;;
  *)
    echo "usage: $0 [-r]" >&2
    exit 2
    ;;
  esac
  shift
done

# A substituter that is down hard-fails the whole build rather than being
# skipped: nix treats a 5xx on a narinfo query as a transport error and aborts,
# and `fallback = true` in infra/modules/wotan/basics.nix does not rescue it — that
# only covers a substitution that fails to *copy*, not one that fails to
# *answer*. cache.garnix.io served 502s across entire outages and has since been
# dropped from basics.nix, as has the homelab attic, but a cachix can go down
# just as easily.
#
# So probe each configured cache and hand nix only the ones that respond. An
# outage then degrades to "build those paths locally" instead of killing the
# switch. The list is read back out of the live nix config rather than
# duplicated here, so it stays in sync with basics.nix automatically.
echo 'Checking substituters...'
healthy=()
unhealthy=()
for url in $(nix config show substituters); do
  case "$url" in
  http://* | https://*) ;;
  # Non-HTTP substituters (local dirs, ssh://) have no narinfo endpoint to
  # probe; assume they are fine and let nix deal with them.
  *)
    healthy+=("$url")
    continue
    ;;
  esac
  if curl -sf -o /dev/null --connect-timeout 3 --max-time 6 "${url%/}/nix-cache-info"; then
    healthy+=("$url")
  else
    unhealthy+=("$url")
  fi
done

nh_args=()
if ((${#unhealthy[@]})); then
  echo "  ! unreachable, skipping: ${unhealthy[*]}"
  if ((${#healthy[@]} == 0)); then
    echo '  ! NO substituters reachable — everything will be built from source.' >&2
    echo '    Ctrl-C now if that is not what you want.' >&2
    sleep 5
  fi
  # `--option substituters` is only honoured because this user is in
  # nix.settings.trusted-users; the daemon ignores it from untrusted users.
  nh_args=(-- --option substituters "${healthy[*]}")
else
  echo "  ✓ all ${#healthy[@]} reachable"
fi
echo ''
if [[ $mode == boot ]]; then
  echo 'Building NixOS configuration (boot)...'
  nh os boot .#nixosConfigurations.wotan "${nh_args[@]}"
  echo ''
  printf '\033[33m%s\033[0m\n' \
    '! WARNING: boot mode — the new configuration is staged as the default for the next boot.' \
    '  The running system is unchanged. Reboot to activate it.' | fold -s -w "$(tput cols)"
else
  echo 'Switching NixOS configuration...'
  nh os switch .#nixosConfigurations.wotan "${nh_args[@]}"
fi

echo ''
echo 'Pushing to all remotes'
for remote in $(git remote); do
  echo "  -> pushing to $remote"
  if git push "$remote"; then
    echo "     ✓ $remote"
  else
    echo "     ✗ failed to push to $remote (continuing)" >&2
  fi
done

# Publishes the exports.toml prefixes (infra/ and the public Rust projects) to
# their GitHub repos. The monorepo itself has no GitHub remote: adding one
# would push the vault through the loop above.
echo ''
echo 'Exporting public subtrees to GitHub'
if ! infra/scripts/export-github.sh; then
  echo "  ✗ warning: GitHub export failed (continuing)" >&2
fi

echo ''
echo 'Pushing system closure to ventara-attic cache'
if command -v attic &>/dev/null; then
  if attic push ventara /nix/var/nix/profiles/system; then
    echo "  ✓ ventara-attic push succeeded"
  else
    echo "  ✗ warning: attic push failed (continuing)" >&2
  fi
else
  echo "  ! attic not found or not logged in (skipping)" >&2
fi
