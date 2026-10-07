#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=infra/hosts/wotan/banner.sh
source "$(dirname "${BASH_SOURCE[0]}")/banner.sh"

clear

banner 'cleaning up ...'

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
  ) </dev/null >"/tmp/cleanup_${name}.log" 2>&1 &
}

# Refresh the sudo timestamp up front so the backgrounded sudo tasks don't
# race each other for a password prompt.
sudo -v

# Remove cargo target/ dirs of every crate or workspace below $1. Only dirs
# holding cargo's CACHEDIR.TAG are touched, so a plain "target" folder that
# merely sits next to a Cargo.toml survives.
# shellcheck disable=SC2329 # invoked indirectly via cleanup_task
clean_rust_targets() {
  local root="$1"
  [ -d "$root" ] || return 0
  find "$root" \( -name target -o -name node_modules -o -name .git -o -name .direnv \) -prune \
    -o -type f -name Cargo.toml -print0 2>/dev/null |
    while IFS= read -r -d '' manifest; do
      local target="${manifest%/Cargo.toml}/target"
      if [ -f "$target/CACHEDIR.TAG" ]; then
        echo "Removing $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
        rm -rf "$target"
      fi
    done
}

# Rust build artifacts
echo 'Cleaning Rust build artifacts...'
cleanup_task rust clean_rust_targets "$HOME/code" || true

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
