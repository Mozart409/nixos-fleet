#!/usr/bin/env bash
# Release one export from exports.toml on GitHub: publish it, then push a
# signed tag on the exported commit, which starts the repo's release workflow.
# The tag must name the split commit on GitHub's main, not the monorepo commit,
# so it is created in a throwaway bare repo that borrows this repo's objects.
# A copy is kept here as refs/tags/<name>/<tag>.
#
# Every step is checked and the first failure stops the release:
#   1. the export exists and the version is plain semver;
#   2. local main is origin/main (only what Forgejo has is released);
#   3. CHANGELOG.md has the version heading, Cargo.toml (if any) the version;
#   4. the tag is new on GitHub and newer than its highest release tag;
#   5. export-github.sh publishes the prefix, and GitHub's main then holds
#      exactly main's tree for it;
#   6. the tag is signed, verified, pushed, and GitHub resolves it to the
#      exported commit.
#
# Usage: release-github.sh <name> <version>            e.g. hofvarpnir 0.18.2
#        release-github.sh --dry-run <name> <version>  checks 1-4 only
set -Eeuo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then green=$'\e[32m' reset=$'\e[0m'; else green='' reset=''; fi
if [[ -t 2 && -z ${NO_COLOR:-} ]]; then red=$'\e[31m' rreset=$'\e[0m'; else red='' rreset=''; fi
ok() { printf '%s✓ %s%s\n' "$green" "$*" "$reset"; }
die() {
  printf '%s✗ %s%s\n' "$red" "$*" "$rreset" >&2
  exit 1
}
step='startup'
trap 'die "$step: command failed at line $LINENO"' ERR

dry_run=
args=()
for a in "$@"; do
  case "$a" in
    --dry-run) dry_run=1 ;;
    -*) die "unknown flag: $a" ;;
    *) args+=("$a") ;;
  esac
done
((${#args[@]} == 2)) || die "usage: just release-github [--dry-run] <name> <version>"
name=${args[0]} version=${args[1]#v}

step='exports.toml'
# The [[export]] table for $name -> "prefix<TAB>remote<TAB>tag_prefix".
# tag_prefix defaults to "v" (homelab-mcp-servers tags bare semver).
entry=$(awk -v want="$name" '
  function flush() { if (seen && name == want) { print prefix "\t" remote "\t" tp; found = 1 } }
  /^\[\[export\]\][[:space:]]*$/ { flush(); seen = 1; name = prefix = remote = ""; tp = "v"; next }
  match($0, /^[[:space:]]*[a-z_]+[[:space:]]*=[[:space:]]*"[^"]*"/) {
    key = $0; sub(/[[:space:]]*=.*/, "", key); gsub(/[[:space:]]/, "", key)
    val = $0; sub(/^[^"]*"/, "", val); sub(/".*$/, "", val)
    if (key == "name") name = val; else if (key == "prefix") prefix = val
    else if (key == "remote") remote = val; else if (key == "tag_prefix") tp = val
  }
  END { flush(); exit !found }
' exports.toml) || die "no export named '$name' in exports.toml"
IFS=$'\t' read -r prefix remote tag_prefix <<<"$entry"
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version '$version' is not MAJOR.MINOR.PATCH"
tag=$tag_prefix$version
local_tag=refs/tags/$name/$tag
ok "$name: $prefix -> $remote, tag $tag"

step='forgejo sync'
git fetch --quiet origin main
[[ $(git rev-parse main) == $(git rev-parse origin/main) ]] ||
  die "local main ($(git rev-parse --short main)) is not origin/main ($(git rev-parse --short origin/main)): pull or push first"
ok "main is origin/main ($(git rev-parse --short main))"

step='version check'
if git cat-file -e "main:$prefix/CHANGELOG.md" 2>/dev/null; then
  git show "main:$prefix/CHANGELOG.md" | grep -qE "^## \[?v?${version//./\\.}\]?( |$)" ||
    die "$prefix/CHANGELOG.md on main has no '## $tag' heading"
  ok "CHANGELOG.md has $tag"
else
  ok "no CHANGELOG.md under $prefix, skipped"
fi
if [[ -f $prefix/Cargo.toml ]]; then
  cargo metadata --quiet --offline --no-deps --format-version 1 --manifest-path "$prefix/Cargo.toml" |
    jq -e --arg v "$version" 'any(.packages[]; .version == $v)' >/dev/null ||
    die "no package in $prefix/Cargo.toml has version $version (bump it first)"
  ok "Cargo.toml has version $version"
fi

step='github tags'
remote_tags=$(git ls-remote --tags --refs "$remote") || die "cannot list tags on $remote"
grep -qxF "refs/tags/$tag" <(cut -f2 <<<"$remote_tags") && die "$tag already exists on $remote"
latest=$(cut -f2 <<<"$remote_tags" | sed -n "s#^refs/tags/${tag_prefix}\([0-9]*\.[0-9]*\.[0-9]*\)\$#\1#p" | sort -V | tail -1)
if [[ -n $latest ]]; then
  [[ $(printf '%s\n%s\n' "$latest" "$version" | sort -V | tail -1) == "$version" ]] ||
    die "$tag is not newer than the latest release ${tag_prefix}$latest"
  ok "$tag is new (latest on GitHub: ${tag_prefix}$latest)"
else
  ok "$tag is new (no release tags on GitHub yet)"
fi
git rev-parse --quiet --verify "$local_tag" >/dev/null && die "${local_tag#refs/tags/} already exists locally"

if [[ -n $dry_run ]]; then
  ok "dry run: all checks passed, nothing exported or tagged"
  exit 0
fi

step='export'
infra/scripts/export-github.sh "$name"
git fetch --quiet --no-tags "$remote" main
split=$(git rev-parse FETCH_HEAD)
[[ $(git rev-parse "$split^{tree}") == $(git rev-parse "main:$prefix") ]] ||
  die "GitHub main ($split) does not hold main:$prefix; not tagging"
ok "GitHub main is the export of main: $(git log -1 --format='%h %s' "$split")"

step='tag'
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
git init --quiet --bare "$scratch"
git rev-parse --path-format=absolute --git-path objects >"$scratch/objects/info/alternates"
git -C "$scratch" tag -s -m "$name $tag" "$tag" "$split"
git -C "$scratch" tag -v "$tag" >/dev/null 2>&1 || die "signature on $tag does not verify (gpg.ssh.allowedSignersFile?)"
ok "signed and verified $tag on $(git rev-parse --short "$split")"

step='push'
git -C "$scratch" push --quiet "$remote" "refs/tags/$tag:refs/tags/$tag"
peeled=$(git ls-remote "$remote" "refs/tags/$tag^{}" | cut -f1)
[[ $peeled == "$split" ]] || die "GitHub resolves $tag to '${peeled:-nothing}', expected $split"
ok "pushed $tag to $remote"

step='local copy'
git fetch --quiet "$scratch" "refs/tags/$tag:$local_tag"
ok "kept ${local_tag#refs/tags/} locally"

repo=${remote#git@github.com:}
ok "released $name $tag: https://github.com/${repo%.git}/actions"
