#!/usr/bin/env bash

set -euo pipefail

clear

chara say -t round -r switching ...
echo ''

# A substituter that is down hard-fails the whole build rather than being
# skipped: nix treats a 5xx on a narinfo query as a transport error and aborts,
# and `fallback = true` in modules/nixos/basics.nix does not rescue it — that
# only covers a substitution that fails to *copy*, not one that fails to
# *answer*. cache.garnix.io has served 502s across entire outages.
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

echo 'Switching NixOS configuration...'
nh os switch .#nixosConfigurations.wotan "${nh_args[@]}"

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
