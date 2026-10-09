#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=infra/hosts/wotan/banner.sh
source "$(dirname "${BASH_SOURCE[0]}")/banner.sh"

# -n / --dry-run lists what would be removed (with sizes where cheap to get)
# and changes nothing.
dry=0
while (($#)); do
  case "$1" in
  -n | --dry-run) dry=1 ;;
  *)
    echo "usage: $0 [-n|--dry-run]" >&2
    exit 2
    ;;
  esac
  shift
done
export dry

# Run from the yggdrasil root, two levels above infra/hosts/wotan.
repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$repo"

clear

if ((dry)); then
  banner 'cleaning up (dry run) ...'
  printf '\033[33m%s\033[0m\n\n' '! DRY RUN: nothing is removed, only listed.'
else
  banner 'cleaning up ...'
fi

echo '=== Disk usage before cleanup ==='
df -h /
echo ''

# ===== NIX OPERATIONS =====

# `nix build` leaves result* links all over the monorepo (one flake, many
# outputs), and each is a GC root that keeps its whole closure alive. Drop the
# ones pointing into the store before collecting. .direnv is skipped here;
# `nh clean all --keep-one` below prunes direnv roots but keeps the newest per
# project, so the current dev shells survive.
if ((dry)); then
  echo 'Would remove nix build result links:'
else
  echo 'Removing nix build result links...'
fi
find "$repo" \( -name .git -o -name .direnv -o -name target -o -name node_modules \) -prune \
  -o -type l -name 'result*' -print0 2>/dev/null |
  while IFS= read -r -d '' link; do
    if [[ $(readlink "$link") == /nix/store/* ]]; then
      echo "  ${link#"$repo"/} -> $(readlink "$link")"
      ((dry)) || rm -f "$link"
    fi
  done
echo ''

echo 'Cleaning Nix generations and store...'
if command -v nh >/dev/null 2>&1; then
  if ((dry)); then
    nh clean all --keep 2 --keep-one --dry
  else
    nh clean all --keep 2 --keep-one
  fi
elif ((dry)); then
  sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +2 --dry-run
  nix-env --profile "$HOME/.local/state/nix/profiles/home-manager" --delete-generations +2 --dry-run 2>/dev/null || true
  nix-env --delete-generations +2 --dry-run 2>/dev/null || true
  echo 'Store paths garbage collection would delete:'
  nix-store --gc --print-dead 2>/dev/null | wc -l
else
  sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +2
  nix-env --profile "$HOME/.local/state/nix/profiles/home-manager" --delete-generations +2 2>/dev/null || true
  nix-env --delete-generations +2 2>/dev/null || true
  nix-collect-garbage
fi

echo ''
if ((dry)); then
  echo 'Would optimise Nix store (nix store optimise)'
else
  echo 'Optimising Nix store...'
  nix store optimise
fi

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
        if ((dry)); then
          echo "Would remove $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
        else
          echo "Removing $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
          rm -rf "$target"
        fi
      fi
    done
}

# Rust build artifacts: every project's own Cargo workspace in the monorepo
# (rust/*, services/, nested ones like hofvarpnir's patches), plus the
# standalone repos still under ~/code. The monorepo usually sits in ~/code
# itself; scan it separately only when it does not.
echo 'Cleaning Rust build artifacts...'
cleanup_task rust clean_rust_targets "$HOME/code" || true
case "$repo/" in
"$HOME/code/"*) ;;
*) cleanup_task rust_repo clean_rust_targets "$repo" || true ;;
esac

# Container cleanup. Neither prune has a dry run, so show reclaimable space.
if command -v podman >/dev/null 2>&1; then
  if ((dry)); then
    cleanup_task podman sh -c 'echo "podman (RECLAIMABLE is what a prune would free):"; podman system df' 2>/dev/null || true
  else
    cleanup_task podman sh -c 'podman system prune -f && podman volume prune -f' 2>/dev/null || true
  fi
fi

if command -v docker >/dev/null 2>&1; then
  if ((dry)); then
    cleanup_task docker sh -c 'echo "docker (RECLAIMABLE is what a prune would free):"; docker system df' 2>/dev/null || true
  else
    cleanup_task docker docker system prune -f --volumes 2>/dev/null || true
  fi
fi

# Journal cleanup. --vacuum-* has no dry run; show the current size instead.
if ((dry)); then
  cleanup_task journal sh -c 'echo "journal (would vacuum entries older than 30d):"; sudo journalctl --disk-usage' 2>/dev/null || true
else
  cleanup_task journal sudo journalctl --vacuum-time=30d 2>/dev/null || true
fi

# /tmp cleanup
if ((dry)); then
  cleanup_task tmp sh -c '
    echo "Would remove from /tmp:"
    sudo find /tmp -mindepth 1 -maxdepth 1 \( -type f -atime +7 -o -type d -empty \) -print 2>/dev/null || true
  ' 2>/dev/null || true
else
  cleanup_task tmp sh -c '
    sudo find /tmp -mindepth 1 -maxdepth 1 -type f -atime +7 -delete 2>/dev/null || true
    sudo find /tmp -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
  ' 2>/dev/null || true
fi

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

if ((dry)); then
  echo ''
  echo 'Dry run complete, nothing was removed.'
  exit 0
fi

echo ''
echo '=== Disk usage after cleanup ==='
df -h /

echo ''
echo 'Cleanup complete!'

exit 0
