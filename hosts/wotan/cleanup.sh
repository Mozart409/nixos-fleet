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

# Remove every cargo target dir below $1: any directory holding cargo's
# CACHEDIR.TAG, whatever it is called and wherever it sits (workspace roots,
# members built on their own, --target-dir builds), so a plain "target" folder
# that is not a cargo cache survives. A matched dir is pruned, not descended.
# shellcheck disable=SC2329 # invoked indirectly via cleanup_task
clean_rust_targets() {
  local root="$1"
  [ -d "$root" ] || return 0
  find "$root" \( -name node_modules -o -name .git -o -name .direnv \) -prune \
    -o -type d -exec test -f '{}/CACHEDIR.TAG' \; -prune -print0 2>/dev/null |
    while IFS= read -r -d '' target; do
      grep -qs 'cargo' "$target/CACHEDIR.TAG" || continue
      if ((dry)); then
        echo "Would remove $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
      else
        echo "Removing $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
        rm -rf "$target"
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
if [ -n "${CARGO_TARGET_DIR:-}" ]; then
  cleanup_task rust_shared clean_rust_targets "$CARGO_TARGET_DIR" || true
fi

# JS package caches. npm's _cacache is a pure download cache; pnpm's
# content-addressed store is pruned of packages no project links any more
# (run from $HOME so a project's local store setting doesn't redirect it),
# and its metadata cache is dropped outright.
# shellcheck disable=SC2329 # invoked indirectly via cleanup_task
clean_npm() {
  if ((dry)); then
    echo "Would clear npm cache ($(du -sh "$HOME/.npm/_cacache" 2>/dev/null | cut -f1))"
  else
    npm cache clean --force
  fi
}

# shellcheck disable=SC2329 # invoked indirectly via cleanup_task
clean_pnpm() {
  cd "$HOME" || return 0
  if ((dry)); then
    local store
    store="$(pnpm store path)"
    echo "Would prune pnpm store $store ($(du -sh "$store" 2>/dev/null | cut -f1) before pruning)"
    echo "Would remove pnpm metadata cache ($(du -sh "$HOME/.cache/pnpm" 2>/dev/null | cut -f1))"
  else
    pnpm store prune
    rm -rf "$HOME/.cache/pnpm"
  fi
}

if command -v npm >/dev/null 2>&1; then
  cleanup_task npm clean_npm || true
fi
if command -v pnpm >/dev/null 2>&1; then
  cleanup_task pnpm clean_pnpm || true
fi

# Container cleanup. Neither prune has a dry run, so show reclaimable space.
# Rootless and rootful podman keep separate stores (~/.local/share/containers
# vs /var/lib/containers); the rootful one holds the oci-containers images and
# drops every image no container uses, since those re-pull on start.
if command -v podman >/dev/null 2>&1; then
  if ((dry)); then
    cleanup_task podman sh -c 'echo "podman (RECLAIMABLE is what a prune would free):"; podman system df' 2>/dev/null || true
    cleanup_task podman_root sh -c 'echo "rootful podman (RECLAIMABLE is what a prune would free):"; sudo podman system df' 2>/dev/null || true
  else
    cleanup_task podman sh -c 'podman system prune -f && podman volume prune -f' 2>/dev/null || true
    cleanup_task podman_root sudo podman system prune -af 2>/dev/null || true
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

# /tmp cleanup. Dot-dirs are skipped: .X11-unix, .ICE-unix, .font-unix and
# .XIM-unix are often empty but X/ICE clients expect them, and only
# systemd-tmpfiles recreates them, at boot.
if ((dry)); then
  cleanup_task tmp sh -c '
    echo "Would remove from /tmp:"
    sudo find /tmp -mindepth 1 -maxdepth 1 \( -type f -atime +7 -o -type d -empty ! -name ".*" \) -print 2>/dev/null || true
  ' 2>/dev/null || true
else
  cleanup_task tmp sh -c '
    sudo find /tmp -mindepth 1 -maxdepth 1 -type f -atime +7 -delete 2>/dev/null || true
    sudo find /tmp -mindepth 1 -maxdepth 1 -type d -empty ! -name ".*" -delete 2>/dev/null || true
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
