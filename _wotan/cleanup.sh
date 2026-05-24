#!/bin/sh

set -uo pipefail

clear

chara say -t round -r cleaning up ...
echo ''

# ===== NIX OPERATIONS (sequential — same store) =====

echo ''
echo 'Deleting old system generations (keeping last 5)...'
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +5

echo ''
echo 'Deleting old home-manager generations (keeping last 5)...'
nix-env -p /home/amadeus/.local/state/nix/profiles/home-manager --delete-generations +5

echo ''
echo 'Deleting old user profile generations (keeping last 5)...'
nix-env --delete-generations +5

echo ''
echo 'Running garbage collection...'
nix-collect-garbage

echo ''
echo 'Optimise store...'
nix store optimise

# ===== PARALLEL CLEANUP TASKS =====
# Each task runs in a subshell with stdin from /dev/null so terminal
# escape-sequence responses (e.g. cursor position reports) do not leak
# into the parent shell.  Output is collected in temp files and printed
# after all jobs finish to avoid interleaving.

cleanup_task() {
  name="$1"
  shift
  (
    "$@"
  ) </dev/null >"/tmp/cleanup_${name}.log" 2>&1
}

if command -v docker >/dev/null 2>&1; then
  cleanup_task docker docker system prune -f --volumes &
fi

if command -v podman >/dev/null 2>&1; then
  (
    cleanup_task podman sh -c 'podman system prune -f && podman volume prune -f'
  ) &
fi

if command -v flatpak >/dev/null 2>&1; then
  cleanup_task flatpak sh -c 'flatpak uninstall --unused -y || true' &
fi

cleanup_task journal sudo journalctl --vacuum-time=30d &

cleanup_task tmp sh -c '
  sudo find /tmp -mindepth 1 -maxdepth 1 -type f -atime +7 -delete 2>/dev/null || true
  sudo find /tmp -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
' &

# Wait for all background jobs to finish
wait

# Print collected output sequentially
for log in /tmp/cleanup_*.log; do
  if [ -f "$log" ] && [ -s "$log" ]; then
    echo ''
    cat "$log"
  fi
  rm -f "$log"
done

echo ''
echo 'Disk usage after cleanup:'
df -h /

exit 0
