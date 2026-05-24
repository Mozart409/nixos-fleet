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

run_docker_cleanup() {
  if command -v docker >/dev/null 2>&1; then
    echo ''
    echo 'Pruning Docker system...'
    docker system prune -f --volumes
  fi
}

run_podman_cleanup() {
  if command -v podman >/dev/null 2>&1; then
    echo ''
    echo 'Pruning Podman system...'
    podman system prune -f
    podman volume prune -f
  fi
}

run_flatpak_cleanup() {
  if command -v flatpak >/dev/null 2>&1; then
    echo ''
    echo 'Removing unused Flatpak runtimes...'
    flatpak uninstall --unused -y || true
  fi
}

run_journal_cleanup() {
  echo ''
  echo 'Vacuuming journal logs (keeping 30 days)...'
  sudo journalctl --vacuum-time=30d
}

run_tmp_cleanup() {
  echo ''
  echo 'Cleaning up old files in /tmp...'
  sudo find /tmp -mindepth 1 -maxdepth 1 -type f -atime +7 -delete 2>/dev/null || true
  sudo find /tmp -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
}

# Start all cleanup tasks in parallel
run_docker_cleanup &
run_podman_cleanup &
run_flatpak_cleanup &
run_journal_cleanup &
run_tmp_cleanup &

# Wait for all background jobs to finish
wait

echo ''
echo 'Disk usage after cleanup:'
df -h /

exit 0
