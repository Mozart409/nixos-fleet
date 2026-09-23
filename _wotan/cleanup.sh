#!/usr/bin/env bash

set -euo pipefail

clear

chara say -t round -r cleaning up ...
echo ''

echo '=== Disk usage before cleanup ==='
df -h /
echo ''

# ===== NIX OPERATIONS =====

echo 'Cleaning Nix generations and store...'
if command -v nh >/dev/null 2>&1; then
  nh clean all --keep 2
else
  sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +2
  nix-env --profile "$HOME/.local/state/nix/profiles/home-manager" --delete-generations +2 2>/dev/null || true
  nix-env --delete-generations +2 2>/dev/null || true
  nix-collect-garbage
fi

echo ''
echo 'Optimising Nix store...'
nix store optimise

# ===== PARALLEL CLEANUP TASKS =====
# Each task runs in a subshell with stdin from /dev/null so terminal
# escape-sequence responses do not leak into the parent shell.

cleanup_task() {
  local name="$1"
  shift
  (
    "$@"
  ) </dev/null >"/tmp/cleanup_${name}.log" 2>&1
}

# Rust build artifacts (huge space hogs) - only purge targets over 5 GiB
echo 'Cleaning Rust build artifacts...'
# shellcheck disable=SC2016 # expansion is intentional in the inner shell
cleanup_task rust bash -c '
  find ~/code/rust -type d -name target -prune -print0 2>/dev/null |
    while IFS= read -r -d "" dir; do
      size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
      [ -n "$size_kb" ] || continue
      if [ "$size_kb" -gt 5242880 ]; then
        echo "Removing $dir ($((size_kb / 1024)) MiB)"
        rm -rf "$dir"
      fi
    done
' 2>/dev/null || true

# Container cleanup
if command -v podman >/dev/null 2>&1; then
  cleanup_task podman sh -c 'podman system prune -f && podman volume prune -f' 2>/dev/null || true
fi

if command -v docker >/dev/null 2>&1; then
  cleanup_task docker docker system prune -f --volumes 2>/dev/null || true
fi

# Journal cleanup
cleanup_task journal sudo journalctl --vacuum-time=30d 2>/dev/null || true

# /tmp cleanup
cleanup_task tmp sh -c '
  sudo find /tmp -mindepth 1 -maxdepth 1 -type f -atime +7 -delete 2>/dev/null || true
  sudo find /tmp -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
' 2>/dev/null || true

# Wait for all background jobs
wait

# Print collected output
for log in /tmp/cleanup_*.log; do
  if [ -f "$log" ] && [ -s "$log" ]; then
    echo ''
    cat "$log"
  fi
  rm -f "$log"
done

echo ''
echo '=== Disk usage after cleanup ==='
df -h /

echo ''
echo 'Cleanup complete!'

exit 0
