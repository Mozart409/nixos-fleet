#!/usr/bin/env bash
# Refuse to publish vault content. Read-only: it inspects git objects and never
# pushes. Runs as the lefthook pre-push `export-guard` job (on HEAD) and from
# export-github.sh before anything is split or pushed (on main).
#
# `git subtree split` publishes the whole history of an exported prefix, not
# just its tip, so both checks cover every blob that was ever under it:
#   - no path in the tip tree of an exported prefix mentions knowledge-base,
#     and no prefix is knowledge-base/ itself;
#   - no blob ever committed under an exported prefix (any commit reachable
#     from <rev>, merges and side branches included) is a byte-for-byte copy
#     of a blob ever committed to the vault (knowledge-base/, or vault/ from
#     before the 2026-10 move). So a note copied in and deleted again is still
#     refused, as are copied attachments, not only *.md.
# Vault content means notes and attachments (the extensions in note_ext),
# outside dot-directories such as .obsidian/. The vault's tooling (flake.nix,
# lefthook.yml, .envrc, the public homelab CA in nix/) is shared with the
# exported projects on purpose and is not matched.
#
# Usage: export-guard.sh [<rev>]    (default HEAD)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
rev=${1:-HEAD}
vault_paths=(knowledge-base vault)
note_ext='md|canvas|base|drawio|excalidraw|pdf|png|jpg|jpeg|gif|webp|svg|txt|csv'
empty_blob=$(git hash-object -t blob /dev/null)

# exports.toml -> prefix per line (name<TAB>prefix). Same narrow format as
# export-github.sh parses: [[export]] tables of `key = "string"` pairs.
mapfile -t exports < <(awk '
  /^\[\[export\]\]/ { name = ""; next }
  match($0, /^[[:space:]]*(name|prefix)[[:space:]]*=[[:space:]]*"[^"]*"/) {
    key = $0; sub(/[[:space:]]*=.*/, "", key); gsub(/[[:space:]]/, "", key)
    val = $0; sub(/^[^"]*"/, "", val); sub(/".*/, "", val)
    if (key == "name") name = val; else print name "\t" val
  }
' exports.toml)
((${#exports[@]})) || {
  echo 'exports.toml: no exports parsed' >&2
  exit 1
}

# Every blob ever added or modified under the given paths in the history of
# $rev, as "blob<TAB>path". -m with --full-history diffs each merge against
# every parent and keeps side branches that net to no change.
history_blobs() {
  git -c core.quotePath=false log --full-history -m --raw --no-abbrev --no-renames --format= "$rev" -- "$@" |
    awk -F'\t' '{ n = split($1, m, " "); if (m[4] !~ /^0+$/) print m[4] "\t" $2 }'
}

declare -A vault=()
while IFS=$'\t' read -r blob path; do
  [[ $blob == "$empty_blob" || $path == .* || $path == */.* ]] && continue
  [[ ${path,,} =~ \.($note_ext)$ ]] || continue
  vault[$blob]=$path
done < <(history_blobs "${vault_paths[@]}")

failed=0
for line in "${exports[@]}"; do
  IFS=$'\t' read -r name prefix <<<"$line"
  case "$prefix" in
    knowledge-base | knowledge-base/*)
      echo "  ✗ $name: knowledge-base/ is never exported" >&2
      failed=1
      continue
      ;;
  esac
  while IFS= read -r path; do
    echo "  ✗ $name: $path looks like vault content" >&2
    failed=1
  done < <(git ls-tree -r --name-only "$rev" -- "$prefix" | grep -F knowledge-base || true)
  declare -A seen=()
  while IFS=$'\t' read -r blob path; do
    [[ -n ${vault[$blob]:-} && -z ${seen[$blob$path]:-} ]] || continue
    seen[$blob$path]=1
    echo "  ✗ $name: $path (blob ${blob:0:12}, in history) is a copy of vault ${vault[$blob]}" >&2
    failed=1
  done < <(history_blobs "$prefix")
  unset seen
done

if ((failed)); then
  echo 'export guard failed: move that content out of the exported prefix (a deleted copy needs a history rewrite)' >&2
  exit 1
fi
