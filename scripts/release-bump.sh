#!/usr/bin/env bash
# Prepare a release of one export from exports.toml: bump its Cargo version,
# prepend a CHANGELOG.md section built from the conventional commits under its
# prefix since the last `chore(version)` commit, and commit both on main as
# `chore(version): <name> <tag>`. Nothing is pushed; `just release-github`
# publishes and tags it afterwards.
#
# Every step is checked and the first failure stops the bump:
#   1. the export exists, the version is plain semver and newer than the
#      current one;
#   2. main is checked out, matches origin/main, and nothing under the prefix
#      is modified or staged;
#   3. there is at least one releasable commit since the last release;
#   4. cargo set-version, a lockfile refresh and `cargo check` succeed;
#   5. the commit holds the bumped version and the new CHANGELOG heading.
#
# Usage: release-bump.sh <name> <version>            e.g. hofvarpnir 0.18.2
#        release-bump.sh --dry-run <name> <version>  checks 1-3, prints the section
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
((${#args[@]} == 2)) || die "usage: just release-bump [--dry-run] <name> <version>"
name=${args[0]} version=${args[1]#v}

step='exports.toml'
entry=$(infra/scripts/export-lookup.sh "$name") || die "no export named '$name' in exports.toml"
IFS=$'\t' read -r prefix _ tag_prefix <<<"$entry"
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version '$version' is not MAJOR.MINOR.PATCH"
tag=$tag_prefix$version
changelog=$prefix/CHANGELOG.md
[[ -f $changelog ]] || die "$changelog does not exist"

manifest=
if [[ -f $prefix/Cargo.toml ]]; then
  manifest=$prefix/Cargo.toml
  # The first workspace member: bumping it cascades through
  # [workspace.package].version, and path-linked patches/* are not members.
  read -r package current < <(
    cargo metadata --quiet --offline --no-deps --format-version 1 --manifest-path "$manifest" |
      jq -r '.workspace_members as $m | [.packages[] | select(.id as $i | $m | index($i))][0] | "\(.name) \(.version)"'
  )
  [[ $(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -1) == "$version" && $current != "$version" ]] ||
    die "$version is not newer than the current version $current"
  ok "$name: $prefix, $package $current -> $version"
else
  ok "$name: $prefix, no Cargo.toml, CHANGELOG only"
fi

step='git state'
[[ $(git branch --show-current) == main ]] || die "check out main first (on '$(git branch --show-current)')"
git fetch --quiet origin main
[[ $(git rev-parse main) == $(git rev-parse origin/main) ]] ||
  die "local main ($(git rev-parse --short main)) is not origin/main ($(git rev-parse --short origin/main)): pull or push first"
if ! git diff --quiet -- "$prefix" || ! git diff --cached --quiet; then
  die "uncommitted changes under $prefix or in the index: commit or stash them first"
fi
ok "main is origin/main ($(git rev-parse --short main)), $prefix is clean"

step='changelog'
last=$(git log -1 --format=%H -E --grep='^chore\(version\): ' main -- "$changelog")
[[ -n $last ]] || die "no previous chore(version) commit touches $changelog"
# Conventional commits under the prefix since $last, grouped in cog's
# changelog layout: "- (**scope**) summary - (hash) - author".
section=$(git log --no-merges --abbrev=7 --format='%h%x09%an%x09%s' "$last..main" -- "$prefix" | awk -F'\t' '
  BEGIN {
    n = split("feat fix perf revert refactor docs test build ci style chore", order, " ")
    title["feat"] = "Features"; title["fix"] = "Bug Fixes"
    title["perf"] = "Performance Improvements"; title["revert"] = "Revert"
    title["refactor"] = "Refactoring"; title["docs"] = "Documentation"
    title["test"] = "Tests"; title["build"] = "Build system"
    title["ci"] = "Continuous Integration"; title["style"] = "Style"
    title["chore"] = "Miscellaneous Chores"
  }
  {
    hash = $1; author = $2; subject = $3
    if (!match(subject, /^[a-z]+(\([^)]*\))?!?: /)) next
    head = substr(subject, 1, RLENGTH - 2); summary = substr(subject, RLENGTH + 1)
    sub(/!$/, "", head)
    type = head; sub(/\(.*/, "", type)
    scope = ""; if (head ~ /\(/) { scope = head; sub(/^[^(]*\(/, "", scope); sub(/\)$/, "", scope) }
    if (!(type in title) || (type == "chore" && scope == "version")) next
    line = "- " (scope != "" ? "(**" scope "**) " : "") summary " - (" hash ") - " author
    lines[type] = lines[type] line "\n"
  }
  END {
    for (i = 1; i <= n; i++) if (order[i] in lines) printf "#### %s\n%s", title[order[i]], lines[order[i]]
  }
')
[[ -n $section ]] || die "no releasable commits under $prefix since $(git log -1 --format='%h %s' "$last")"
heading="## $tag - $(date +%F)"
ok "changelog since $(git log -1 --format='%h %s' "$last"):"
printf '%s\n%s\n' "$heading" "$section"

if [[ -n $dry_run ]]; then
  ok "dry run: all checks passed, nothing changed"
  exit 0
fi

step='changelog write'
# Insert after the first "- - -" separator, keeping cog's layout.
BLOCK="$heading"$'\n'"$section"$'\n\n- - -' awk '
  !done && $0 == "- - -" { print; print ENVIRON["BLOCK"]; done = 1; next }
  { print }
  END { if (!done) exit 1 }
' "$changelog" >"$changelog.new" || {
  rm -f "$changelog.new"
  die "$changelog has no '- - -' separator to insert after"
}
mv "$changelog.new" "$changelog"
ok "wrote $heading to $changelog"

if [[ -n $manifest ]]; then
  step='cargo'
  # One && chain: set -e does not apply inside the left side of ||.
  (cd "$prefix" &&
    cargo set-version -p "$package" "$version" &&
    cargo update --workspace --offline &&
    SQLX_OFFLINE=true cargo check --quiet) ||
    die "cargo bump or check failed; revert with: git checkout -- $prefix"
  got=$(cargo metadata --quiet --offline --no-deps --format-version 1 --manifest-path "$manifest" |
    jq -r --arg p "$package" '.packages[] | select(.name == $p) | .version')
  [[ $got == "$version" ]] || die "$package is at $got after set-version, expected $version"
  ok "bumped $package to $version, Cargo.lock refreshed, cargo check passed"
fi

step='commit'
git add -u -- "$prefix"
git commit --quiet -m "chore(version): $name $tag"
git show HEAD:"$changelog" | grep -qxF "$heading" || die "commit is missing the CHANGELOG heading"
ok "committed $(git log -1 --format='%h %s')"
ok "next: git push origin main && just release-github $name $version"
