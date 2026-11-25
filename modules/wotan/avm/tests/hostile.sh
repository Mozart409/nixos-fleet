# shellcheck shell=bash disable=SC2154,SC2034
# Fixture builders for git.sh (sourced, not run).
# Globals from the sandbox: SB, CODE, GUEST, AVM_REPOS. Only fake names here.

put() { # <repo> <path> [line...]: write a file, creating parent directories
  mkdir -p "$(dirname "$1/$2")" && printf '%s\n' "${@:3}" >"$1/$2"
}
mk_commit() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }
commit_gitlink() { # <repo> <msg> <sha> <path>: commit everything plus a gitlink entry
  git -C "$1" add -A && git -C "$1" update-index --add --cacheinfo "160000,$3,$4" &&
    git -C "$1" commit -qm "$2"
}
rev() { git -C "$1" rev-parse "$2"; }
map() { printf '%s %s\n' "$1" "$2" >>"$AVM_REPOS"; }
gdir() { printf '%s/avm-%s/srv/work/%s\n' "$GUEST" "$1" "$(basename "$2")"; }

mk_host() { # <rel>: repo under the code root with one commit on main
  local r=$CODE/$1
  git init -q "$r" && put "$r" a.txt base && put "$r" harmless.txt harmless &&
    put "$r" moved.txt moved && put "$r" sub/keep.txt keep && mk_commit "$r" init
}
mk_guest() { # <vm> <rel>: clone of the host repo in the VM's /srv/work, origin removed
  local g
  g=$(gdir "$1" "$2")
  mkdir -p "$(dirname "$g")" && git clone -q --no-hardlinks "$CODE/$2" "$g" &&
    git -C "$g" remote remove origin
}

refs_outside() { git -C "$1" for-each-ref --format='%(objectname) %(refname)' | grep -v ' refs/agents/home/' || true; }
agents() { git -C "$1" for-each-ref --format='%(objectname) %(refname)' refs/agents; }

snap() { # <repo>: everything a fetch or review must leave alone
  local r=$1 gd cd
  gd=$(git -C "$r" rev-parse --absolute-git-dir)
  cd=$(git -C "$r" rev-parse --path-format=absolute --git-common-dir)
  git -C "$r" for-each-ref --format='%(objectname) %(refname)' | grep -v ' refs/agents/' || true
  git -C "$r" symbolic-ref -q HEAD || true
  git -C "$r" rev-parse -q --verify HEAD || true
  (cd "$cd" && find config hooks info -type f -exec sha256sum {} + 2>/dev/null | sort -k2) || true
  if [[ -e $gd/index ]]; then sha256sum "$gd/index"; else echo no-index; fi
  if [[ -e $cd/FETCH_HEAD || -e $gd/FETCH_HEAD ]]; then echo FETCH_HEAD; else echo no-FETCH_HEAD; fi
}
snapwt() { # <repo>: snap plus every working tree file
  snap "$1"
  (cd "$1" && find . -path ./.git -prune -o -type f -exec sha256sum {} + | sort -k2)
}
guest_state() { # <guest>: refs except wotan, HEAD, index and working tree
  git -C "$1" for-each-ref --format='%(objectname) %(refname)' | grep -v ' refs/remotes/wotan/' || true
  git -C "$1" symbolic-ref -q HEAD || true
  git -C "$1" ls-files -s
  sha256sum "$1/.git/index"
  (cd "$1" && find . -path ./.git -prune -o -type f -exec sha256sum {} + | sort -k2)
}

# --- hostile ssh peer: a git-upload-pack that prints a hand-made v0 advertisement ---
hs_pkt() { local p=$1 LC_ALL=C; printf '%04x%s' $((${#p} + 4)) "$p"; }
hs_adv() { # <out> <sha> <refname>...: advertisement; the first ref carries the capabilities
  local out=$1 sha=$2 n p first=1 caps='multi_ack side-band-64k ofs-delta agent=git/hostile' LC_ALL=C
  shift 2
  : >"$out"
  for n in "$@"; do
    if ((first)); then
      p="$sha $n"
      printf '%04x%s\0%s\n' $((${#p} + ${#caps} + 6)) "$p" "$caps" >>"$out"
      first=0
    else
      hs_pkt "$sha $n"$'\n' >>"$out"
    fi
  done
  printf '0000' >>"$out"
}
hs_prog() { # <prog> <data>: program for AVM_FAKE_HOSTILE that prints the data and stderr noise
  printf '#!/bin/sh\ncat "%s"\nprintf "fatal: hostile\\n" >&2\ntimeout 3 cat >/dev/null\n' "$2" >"$1" &&
    chmod +x "$1"
}

# --- malformed objects: refs/heads/evil in <guest>; BAD lists shas that must never reach the host ---
hs_ent() { # <mode> <name> <blobsha>: one raw tree entry
  printf '%s %s\0' "$1" "$2"
  # shellcheck disable=SC2059
  printf "$(printf '%s' "$3" | sed 's/../\\x&/g')"
}
hs_bad() { # <guest> <author|tree-unsorted|tree-dotgit>
  local g=$1 t blob c
  blob=$(printf 'x\n' | git -C "$g" hash-object -w --stdin)
  case $2 in
    author)
      t=$(git -C "$g" rev-parse 'HEAD^{tree}')
      c=$(printf 'tree %s\nauthor no email here\ncommitter T <t@example.invalid> 1700000000 +0000\n\nbad author\n' "$t" |
        git -C "$g" hash-object -t commit -w --literally --stdin)
      BAD=$c
      ;;
    tree-*)
      if [[ $2 == tree-unsorted ]]; then
        t=$({ hs_ent 100644 b "$blob"; hs_ent 100644 a "$blob"; } | git -C "$g" hash-object -t tree -w --literally --stdin)
      else
        t=$(hs_ent 100644 .git "$blob" | git -C "$g" hash-object -t tree -w --literally --stdin)
      fi
      c=$(printf 'tree %s\nauthor T <t@example.invalid> 1700000000 +0000\ncommitter T <t@example.invalid> 1700000000 +0000\n\nbad tree\n' "$t" |
        git -C "$g" hash-object -t commit -w --literally --stdin)
      BAD="$t $c"
      ;;
  esac
  git -C "$g" update-ref refs/heads/evil "$c"
}

# --- booby-trapped host repo: every helper, hook and filter touches $SB/canaries/<name> ---
hs_arm() { # <repo>: call last, after the repo's own setup commits
  local r=$1 b=$SB/bin c=$SB/canaries n hooks
  mkdir -p "$b" "$c"
  for n in textconv smudge clean pager; do
    printf '#!/bin/sh\ntouch "%s/%s"\ncat "$@"\n' "$c" "$n" >"$b/$n"
  done
  for n in diffcmd diffext fsmon process; do
    printf '#!/bin/sh\ntouch "%s/%s"\n' "$c" "$n" >"$b/$n"
  done
  chmod +x "$b"/*
  git -C "$r" config diff.evil.textconv "$b/textconv"
  git -C "$r" config diff.evil.command "$b/diffcmd"
  git -C "$r" config filter.evil.smudge "$b/smudge"
  git -C "$r" config filter.evil.clean "$b/clean"
  git -C "$r" config filter.evil.process "$b/process"
  git -C "$r" config core.fsmonitor "$b/fsmon"
  git -C "$r" config diff.external "$b/diffext"
  git -C "$r" config core.pager "$b/pager"
  hooks=$(git -C "$r" rev-parse --path-format=absolute --git-path hooks)
  mkdir -p "$hooks"
  for n in reference-transaction post-checkout post-merge pre-push post-rewrite; do
    printf '#!/bin/sh\ntouch "%s/hook-%s"\n' "$c" "$n" >"$hooks/$n"
    chmod +x "$hooks/$n"
  done
  printf '* filter=evil diff=evil\n' >"$r/.gitattributes"
}
