#!/usr/bin/env bash
# Publish the prefixes listed in exports.toml to their GitHub repos. Each
# prefix becomes its own history via `git subtree split` (same hashes as
# splitsh-lite, so pushes stay fast-forwards) and is pushed to the repo's
# `main`. Runs from wotan's switch.sh; only wotan pushes to GitHub.
#
# Before anything is pushed:
#   - guard: no path under an exported prefix mentions knowledge-base, and no
#     note (*.md) under it is a byte-for-byte copy of one in knowledge-base/;
#   - gitleaks over the prefix's whole history (.gitleaksignore applies).
#
# An export whose tree has not changed since its last successful push is
# skipped (state in .git/exports/), so a switch that touches nothing public
# costs nothing. Pushes never force, except the names given to --force.
#
# Usage: export-github.sh                  guard, scan, split and push all
#        export-github.sh <name>...        only these exports
#        export-github.sh --check          guard only (lefthook pre-push)
#        export-github.sh --dry-run        guard, scan and split, no push
#        export-github.sh --force <name>   one-time force-push (history rewrite)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ref=refs/heads/main
mode=push
declare -A only=() force=()
while (($#)); do
  case "$1" in
    --check) mode=check ;;
    --dry-run) mode=dry-run ;;
    --force)
      shift
      force[${1:?--force needs an export name}]=1
      only[$1]=1
      ;;
    -*)
      echo "unknown flag: $1" >&2
      exit 2
      ;;
    *) only[$1]=1 ;;
  esac
  shift
done

# exports.toml -> "name<TAB>prefix<TAB>remote" lines. Deliberately narrow:
# [[export]] tables with `key = "string"` pairs, nothing else.
mapfile -t exports < <(awk '
  function flush() {
    if (!seen) return
    if (name == "" || prefix == "" || remote == "") {
      print "exports.toml: incomplete [[export]] before line " NR > "/dev/stderr"
      exit 1
    }
    print name "\t" prefix "\t" remote
  }
  /^[[:space:]]*(#|$)/ { next }
  /^\[\[export\]\][[:space:]]*$/ { flush(); seen = 1; name = prefix = remote = ""; next }
  match($0, /^[[:space:]]*(name|prefix|remote)[[:space:]]*=[[:space:]]*"[^"]*"[[:space:]]*$/) {
    key = $0; sub(/[[:space:]]*=.*/, "", key); gsub(/[[:space:]]/, "", key)
    val = $0; sub(/^[^"]*"/, "", val); sub(/"[[:space:]]*$/, "", val)
    if (key == "name") name = val; else if (key == "prefix") prefix = val; else remote = val
    next
  }
  { print "exports.toml: cannot parse line " NR ": " $0 > "/dev/stderr"; exit 1 }
  END { flush() }
' exports.toml)
((${#exports[@]})) || {
  echo 'exports.toml: no exports parsed' >&2
  exit 1
}

for n in "${!only[@]}"; do
  printf '%s\n' "${exports[@]}" | cut -f1 | grep -qxF "$n" || {
    echo "no export named '$n' in exports.toml" >&2
    exit 2
  }
done

# Guard: runs on the commit being published (main, or HEAD for --check).
rev=$ref
[[ $mode == check ]] && rev=HEAD
declare -A kb_notes=()
while read -r _ _ blob _; do
  kb_notes[$blob]=1
done < <(git ls-tree -r "$rev" -- knowledge-base | grep -E '\.md$' || true)

guard_failed=0
for line in "${exports[@]}"; do
  IFS=$'\t' read -r name prefix _ <<<"$line"
  case "$prefix" in
    knowledge-base | knowledge-base/*)
      echo "  ✗ $name: knowledge-base/ is never exported" >&2
      guard_failed=1
      ;;
  esac
  while IFS=$'\t' read -r meta path; do
    read -r _ _ blob <<<"$meta"
    if [[ $path == *knowledge-base* ]]; then
      echo "  ✗ $name: $path looks like vault content" >&2
      guard_failed=1
    elif [[ $path == *.md && -n ${kb_notes[$blob]:-} ]]; then
      echo "  ✗ $name: $path is a copy of a knowledge-base/ note" >&2
      guard_failed=1
    fi
  done < <(git ls-tree -r "$rev" -- "$prefix")
done
if ((guard_failed)); then
  echo 'export guard failed: move that content out of the exported prefix' >&2
  exit 1
fi
[[ $mode == check ]] && exit 0

state_dir=$(git rev-parse --git-path exports)
mkdir -p "$state_dir"

failed=()
for line in "${exports[@]}"; do
  IFS=$'\t' read -r name prefix remote <<<"$line"
  ((${#only[@]})) && [[ -z ${only[$name]:-} ]] && continue

  tree=$(git rev-parse "$ref:$prefix")
  if [[ -z ${force[$name]:-} && -f $state_dir/$name && $(<"$state_dir/$name") == "$tree" ]]; then
    echo "  = $name unchanged"
    continue
  fi

  if ! gitleaks git --redact --no-banner --log-level warn --log-opts="$ref -- $prefix" .; then
    echo "  ✗ $name: gitleaks found something, not pushed (run: just leaks -v)" >&2
    failed+=("$name")
    continue
  fi

  split=$(git subtree split --quiet --prefix="$prefix" "$ref")
  if [[ $mode == dry-run ]]; then
    echo "  ~ $name -> $split ($(git rev-list --count "$split") commits), not pushed"
    continue
  fi

  push_args=()
  [[ -n ${force[$name]:-} ]] && push_args=(--force)
  if git push "${push_args[@]}" "$remote" "$split:refs/heads/main"; then
    echo "$tree" >"$state_dir/$name"
    echo "  ✓ $name"
  else
    echo "  ✗ $name: push to $remote failed" >&2
    failed+=("$name")
  fi
done

if ((${#failed[@]})); then
  echo "export failed for: ${failed[*]}" >&2
  exit 1
fi
