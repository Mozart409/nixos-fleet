#!/usr/bin/env bash
# The files a push changes, for the pre-push gates (eval-touched-hosts.sh,
# rust-ci-touched.sh). Reads git's pre-push refs on stdin and prints each
# changed path once.
#
# Usage: pushed-files.sh < <git pre-push stdin>
#        pushed-files.sh --save    (save git's refs, print nothing)
#        pushed-files.sh --saved   (read the refs --save saved)
#
# The pre-push gates run in parallel (lefthook group), and lefthook hands every
# use_stdin job the same cached reader: two of them reading it at once would
# split the refs between them. So one job saves them, the gates read the file.
#
# Not lefthook's {push_files}: for a branch without an upstream (every agent
# branch) it is `git diff HEAD origin/main`, a two-dot diff that also counts
# everything merged to main since the branch was cut, so a vault-only push
# evaluated wotan and the fleet (~8 min).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

refs_file=$(git rev-parse --git-path lefthook-push-refs)

case "${1:-}" in
  --save)
    cat >"$refs_file"
    exit 0
    ;;
  --saved)
    [[ -e $refs_file ]] || {
      echo "pushed-files: $refs_file missing, not a pre-push run" >&2
      exit 1
    }
    exec <"$refs_file"
    ;;
esac

# Files the pushed refs change: <local ref> <local sha> <remote ref> <remote
# sha> per line. An update diffs against what the remote has; a new branch
# against its merge-base with main, so only the branch's own commits count.
pushed_files() {
  local zero=0000000000000000000000000000000000000000
  local _lref lsha _rref rsha base
  while read -r _lref lsha _rref rsha; do
    [[ $lsha == "$zero" ]] && continue # branch deletion
    if [[ $rsha != "$zero" ]] && git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      base=$rsha
    else
      base=$(git merge-base "$lsha" origin/main 2>/dev/null) || base=$(git hash-object -t tree /dev/null)
    fi
    git diff --name-only "$base" "$lsha" --
  done
}

pushed_files | sort -u
