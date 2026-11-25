#!/usr/bin/env bash
# VM-free tests for avm.sh: real git repos in one sandbox, fake-ssh.sh as the transport.
# Prints "ok|not ok <id> <text>" per check; exits non-zero on any failure.
# shellcheck disable=SC2317,SC2329
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
avm=$here/../avm.sh
# shellcheck source-path=SCRIPTDIR source=hostile.sh
source "$here/hostile.sh"

for v in "${!GIT_@}"; do unset "$v"; done
ROOT=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$ROOT"' EXIT

TESTS=()
reg() { TESTS+=("$1:$2"); }

# --- harness ---
sandbox() { # <name>: fresh directory tree and environment for one test
  SB=$ROOT/$1 CODE=$ROOT/$1/code GUEST=$ROOT/$1/guest
  mkdir -p "$SB/home" "$SB/canaries" "$SB/bin" "$CODE" "$GUEST"
  printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n[init]\n\tdefaultBranch = main\n' >"$SB/gitconfig"
  export HOME=$SB/home XDG_CONFIG_HOME=$SB/home/.config LC_ALL=C.UTF-8 GIT_TERMINAL_PROMPT=0
  export GIT_CONFIG_GLOBAL=$SB/gitconfig GIT_CONFIG_SYSTEM=/dev/null
  export AVM_CODE_ROOT=$CODE AVM_REPOS=$SB/repos AVM_SSH=$here/fake-ssh.sh
  export AVM_FAKE_ROOT=$GUEST AVM_FAKE_LOG=$SB/ssh.log
  unset AVM_FAKE_HOSTILE AVM_FAKE_DOWN
  CWD=$SB
  : >"$AVM_REPOS"
}
av() { # run avm.sh from $CWD; sets rc, leaves $SB/out and $SB/err
  rc=0
  (cd "$CWD" && exec bash "$avm" "$@") >"$SB/out" 2>"$SB/err" || rc=$?
}
dump() {
  local f
  printf '# rc=%s\n' "${rc:-?}"
  for f in out err; do
    if [[ -f $SB/$f ]]; then
      printf '# %s:\n' "$f"
      sed 's/^/#   /' "$SB/$f" | cat -v
    fi
  done
}
pass() { printf 'ok %s %s\n' "$ID" "$1"; }
fail() {
  printf 'not ok %s %s\n' "$ID" "$1"
  : >"$SB/.failed"
  dump
}
ck() { # <text> <command...>: ok when the command succeeds
  local d=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
not() { ! "$@"; }
succeeded() { [ "$rc" -eq 0 ]; }
refused_for() { [ "$rc" -ne 0 ] && grep -qaF -- "$1" "$SB/err"; } # <reason: fixed string from avm.sh>
refused_re() { [ "$rc" -ne 0 ] && grep -qaE -- "$1" "$SB/err"; }      # <reason: ERE, for git's own wording>
quiet_ssh() { [ ! -s "$AVM_FAKE_LOG" ]; }
has() { grep -qaF -- "$1" "$SB/out"; }
anyre() { grep -qaiE -- "$1" "$SB/out" "$SB/err"; }
no_raw() { ! grep -qaF -- "$1" "$SB/out" "$SB/err"; }
lastline_has() { [[ $(tail -n1 "$SB/out") == *"$1"* ]]; }
no_canary() { [ -z "$(find "$SB" -name canary -print -quit)" ]; }
nothing_ran() { [ -z "$(ls -A "$SB/canaries")" ]; }
section() { awk '/^== execution-sensitive paths/{s=1;next} /^== /{s=0} s && NF' "$SB/out"; }
listed() { section | awk -F'\t' -v p="$1" '$NF==p{f=1} END{exit !f}'; }
bad_sync() { : >"$AVM_FAKE_LOG"; av sync "$@"; }
refuse() { ck "$1 is refused" refused_for "$2"; ck "$1: no ssh call" quiet_ssh; } # <text> <reason>

# --- T-GIT-1: sync ---
t_git_1() {
  local HOST G b d before after
  mk_host x/demo && mk_host x/second && mk_host x/extra
  HOST=$CODE/x/demo G=$(gdir home x/demo)
  map x/demo home && map x/second other

  bad_sync x/extra main
  refuse "unmapped repo" "x/extra is not mapped to a VM"
  map x/extra home
  av sync x/extra main
  ck "the same repo syncs once mapped" succeeded

  bad_sync --vm other x/demo main
  refuse "--vm other for a repo mapped to home" "x/demo is mapped to home, not other"
  av sync --vm home x/demo main
  ck "--vm home (the mapping) syncs" succeeded
  ck "first sync creates the guest clone" test -d "$G/.git"
  ck "first sync pushes refs/remotes/wotan/main" [ "$(rev "$G" refs/remotes/wotan/main)" = "$(rev "$HOST" main)" ]
  ck "first sync checks out an unborn guest HEAD" [ "$(rev "$G" HEAD)" = "$(rev "$HOST" main)" ]
  ck "first sync leaves a working tree" test -f "$G/a.txt"
  ck "first sync adds no git remote" [ -z "$(git -C "$G" remote -v)" ]

  git -C "$G" switch -q -c own && put "$G" own.txt own && mk_commit "$G" own
  printf 'dirty\n' >>"$G/a.txt"
  put "$G" staged.txt staged && git -C "$G" add staged.txt
  before=$(guest_state "$G")
  put "$HOST" a.txt moved-on && mk_commit "$HOST" next
  av sync x/demo main
  ck "second sync succeeds" succeeded
  ck "second sync moves refs/remotes/wotan/main" [ "$(rev "$G" refs/remotes/wotan/main)" = "$(rev "$HOST" main)" ]
  after=$(guest_state "$G")
  ck "second sync leaves guest branches, HEAD, index and dirty tree alone" [ "$before" = "$after" ]
  ck "second sync adds no git remote" [ -z "$(git -C "$G" remote -v)" ]

  cp "$AVM_REPOS" "$SB/repos.ok"
  for d in 'x/demo other' 'x/demo home'; do
    cp "$SB/repos.ok" "$AVM_REPOS" && printf '%s\n' "$d" >>"$AVM_REPOS"
    bad_sync x/demo main
    refuse "repo listed twice ($d)" "x/demo listed twice"
  done
  cp "$SB/repos.ok" "$AVM_REPOS"
  av sync x/demo main
  ck "a single mapping syncs again" succeeded

  for d in second "$CODE/x/second"; do
    mv "$CODE/x/demo" "$CODE/x/demo.real" && ln -s "$d" "$CODE/x/demo"
    bad_sync x/demo main
    refuse "symlink x/demo -> $d" "x/demo resolves outside its own path"
    rm "$CODE/x/demo" && mv "$CODE/x/demo.real" "$CODE/x/demo"
  done
  av sync x/demo main
  ck "the real directory syncs again" succeeded

  bad_sync x/demo nosuch
  refuse "unknown branch" "no branch nosuch in x/demo"
  # shellcheck disable=SC2016
  for b in 'a;touch${IFS}canary' '$(touch${IFS}canary)' '`touch${IFS}canary`' 'a|b' 'a&b' "a'b" 'a>b'; do
    git -C "$HOST" branch "$b" main
    bad_sync x/demo "$b"
    refuse "branch name $b" "bad branch name: $b"
  done
  ck "no injected command ran" no_canary
  git -C "$HOST" branch feat main
  av sync x/demo feat
  ck "a plain branch name syncs" succeeded
  ck "the plain branch lands in refs/remotes/wotan" [ "$(rev "$G" refs/remotes/wotan/feat)" = "$(rev "$HOST" feat)" ]
}
reg T-GIT-1 t_git_1

# --- T-GIT-2: fetch leaves the host alone ---
t_git_2() {
  local HOST G GW W before after old b0 b1
  mk_host x/demo
  HOST=$CODE/x/demo W=$CODE/x/wt
  map x/demo home && map x/wt home
  git -C "$HOST" tag -a v0 -m v0 && git -C "$HOST" branch hostbranch
  git -C "$HOST" update-ref refs/remotes/origin/keep "$(rev "$HOST" main)"
  printf '#!/bin/sh\nexit 0\n' >"$HOST/.git/hooks/pre-commit"
  put "$HOST" staged.txt s && git -C "$HOST" add staged.txt
  git -C "$HOST" worktree add -q "$W" -b wtbranch
  mk_guest home x/demo && G=$(gdir home x/demo)
  git -C "$G" switch -q -c feat1 && put "$G" f1.txt f1 && mk_commit "$G" f1
  git -C "$G" tag -a rel -m rel && git -C "$G" tag lw
  git -C "$G" switch -q -c feat2 main
  put "$G" .gitmodules '[submodule "mod"]' $'\tpath = mod' $'\turl = https://example.invalid/mod.git'
  commit_gitlink "$G" mod "$(rev "$G" main)" mod
  git -C "$G" switch -q main && printf 'stash me\n' >>"$G/a.txt" && git -C "$G" stash -q

  before=$(snap "$HOST")
  av fetch x/demo
  ck "fetch succeeds" succeeded
  ck "fetch prints new home/feat1" grep -qE '^new home/feat1( |$)' "$SB/out"
  ck "fetch prints new home/feat2" grep -qE '^new home/feat2( |$)' "$SB/out"
  after=$(snap "$HOST")
  ck "heads, tags, remotes, HEAD, config, hooks, index byte-identical" [ "$before" = "$after" ]
  ck "only refs/agents/home/{feat1,feat2,main} appear" \
    [ "$(git -C "$HOST" for-each-ref --format='%(refname)' refs/agents)" = $'refs/agents/home/feat1\nrefs/agents/home/feat2\nrefs/agents/home/main' ]
  ck "no refs/tags/rel or lw, no stash" [ -z "$(git -C "$HOST" for-each-ref refs/tags/rel refs/tags/lw refs/stash)" ]
  ck "no FETCH_HEAD" test ! -e "$HOST/.git/FETCH_HEAD"
  ck "no submodule state" test ! -e "$HOST/.git/modules"

  old=$(rev "$HOST" refs/agents/home/feat1)
  git -C "$G" switch -q feat1 && git -C "$G" commit -q --amend -m amended
  git -C "$G" switch -q feat2 && put "$G" f2.txt f2 && mk_commit "$G" f2
  av fetch x/demo
  ck "second fetch succeeds" succeeded
  ck "amended guest branch prints forced with the old sha" grep -qE "^forced home/feat1 .*${old:0:7}" "$SB/out"
  ck "fast-forwarded guest branch prints updated" grep -qE '^updated home/feat2( |$)' "$SB/out"
  av fetch x/demo
  ck "an unchanged guest prints nothing new" grep -q 'nothing new' "$SB/out"

  git -C "$G" switch -q main && git -C "$G" branch -q -D feat2
  av fetch x/demo
  ck "fetch after a guest branch deletion succeeds" succeeded
  ck "the deleted guest branch stays in refs/agents (no prune)" git -C "$HOST" rev-parse -q --verify refs/agents/home/feat2
  after=$(snap "$HOST")
  ck "still byte-identical after three fetches" [ "$before" = "$after" ]

  mk_guest home x/wt && GW=$(gdir home x/wt)
  git -C "$GW" switch -q -c wtfeat && put "$GW" w.txt w && mk_commit "$GW" w
  put "$W" wtstaged.txt w && git -C "$W" add wtstaged.txt
  b0=$(snap "$W") b1=$(snap "$HOST")
  av fetch x/wt
  ck "fetch into a linked worktree checkout succeeds" succeeded
  ck "the worktree fetch creates refs/agents/home/wtfeat" git -C "$HOST" rev-parse -q --verify refs/agents/home/wtfeat
  ck "linked worktree snapshot unchanged" [ "$b0" = "$(snap "$W")" ]
  ck "main checkout snapshot unchanged" [ "$b1" = "$(snap "$HOST")" ]
}
reg T-GIT-2 t_git_2

# --- T-GIT-3: malformed objects never reach the host ---
t_git_3() {
  local HOST G kind o before why
  mk_host x/demo && mk_guest home x/demo && map x/demo home
  HOST=$CODE/x/demo G=$(gdir home x/demo)
  av fetch x/demo
  ck "a well-formed guest fetches" succeeded
  for kind in author tree-unsorted tree-dotgit; do
    case $kind in
      author) why='fsck error|missingEmail|invalid author' ;;
      tree-unsorted) why='fsck error|treeNotSorted|not properly sorted' ;;
      tree-dotgit) why='fsck error|hasDotgit|contains .\.git' ;;
    esac
    hs_bad "$G" "$kind"
    before=$(agents "$HOST")
    av fetch x/demo
    ck "$kind: fetch fails" refused_re "fetch from home failed"
    ck "$kind: fetch fails on git's fsck, not on transport" refused_re "$why"
    ck "$kind: no refs/agents/home/evil" not git -C "$HOST" rev-parse -q --verify refs/agents/home/evil
    ck "$kind: refs/agents unchanged" [ "$(agents "$HOST")" = "$before" ]
    for o in $BAD; do ck "$kind: bad object $o is not in the host store" not git -C "$HOST" cat-file -e "$o"; done
    av fetch x/demo
    ck "$kind: a second fetch fails too" refused_re "fetch from home failed"
    ck "$kind: the second fetch fails on git's fsck again" refused_re "$why"
    for o in $BAD; do ck "$kind: still not in the host store after the second fetch" not git -C "$HOST" cat-file -e "$o"; done
    git -C "$G" update-ref -d refs/heads/evil
    av fetch x/demo
    ck "$kind: the same guest without the bad branch fetches" succeeded
  done
}
reg T-GIT-3 t_git_3

# --- T-GIT-4: hostile ref names from the peer, odd but legal names from a guest ---
t_git_4() {
  local HOST G X n before
  local -a names
  mk_host x/demo && mk_guest home x/demo && map x/demo home
  HOST=$CODE/x/demo G=$(gdir home x/demo)
  av fetch x/demo
  ck "initial fetch succeeds" succeeded
  X=$(rev "$HOST" refs/agents/home/main)

  hs_adv "$SB/adv.ok" "$X" refs/heads/ok && hs_prog "$SB/prog.ok" "$SB/adv.ok"
  AVM_FAKE_HOSTILE=$SB/prog.ok av fetch x/demo
  ck "control: a well-formed advertisement fetches" succeeded
  ck "control: refs/agents/home/ok points at the advertised sha" [ "$(rev "$HOST" refs/agents/home/ok)" = "$X" ]

  hs_adv "$SB/adv.bad" "$X" refs/heads/ok 'refs/heads/../../heads/main' refs/heads/.lock \
    refs/agents/other/x 'refs/heads/a..b' $'refs/heads/e\esc' refs/heads/ok2
  hs_prog "$SB/prog.bad" "$SB/adv.bad"
  before=$(refs_outside "$HOST")
  AVM_FAKE_HOSTILE=$SB/prog.bad av fetch x/demo || true
  ck "refs outside refs/agents/home/ unchanged" [ "$(refs_outside "$HOST")" = "$before" ]
  ck "refs/agents/other does not appear" [ -z "$(git -C "$HOST" for-each-ref refs/agents/other)" ]
  ck "no lock file left behind" [ -z "$(find "$HOST/.git" -name '*.lock' -print -quit)" ]

  # shellcheck disable=SC2016
  names=(-x 'a;touch${IFS}canary' '$(touch${IFS}canary)' '`touch${IFS}canary`' $'ev\xe2\x80\xaeil')
  for n in "${names[@]}"; do git -C "$G" update-ref "refs/heads/$n" HEAD; done
  av fetch x/demo || true
  ck "odd guest branch names executed nothing" no_canary
  ck "the host repo is still sane after odd names" git -C "$HOST" fsck --no-dangling
}
reg T-GIT-4 t_git_4

# --- T-GIT-5 / T-GIT-10: execution-sensitive classes ---
t_git_5() {
  local HOST G p sha
  mk_host x/demo && mk_guest home x/demo && map x/demo home
  HOST=$CODE/x/demo G=$(gdir home x/demo)
  git -C "$G" switch -q -c all
  for p in .envrc flake.nix flake.lock other.nix justfile Justfile lefthook.yml build.rs .cargo/config.toml \
    rust-toolchain.toml package.json x.sh .claude/settings.json .opencode/x AUTOLITH.org; do
    put "$G" "$p" "content of $p"
  done
  put "$G" .gitattributes '*.txt text'
  put "$G" .gitmodules '[submodule "mod"]' $'\tpath = mod' $'\turl = https://example.invalid/mod.git'
  ln -s harmless.txt "$G/link"
  commit_gitlink "$G" all "$(rev "$G" main)" mod
  git -C "$G" switch -q main && git -C "$G" switch -q -c mode && chmod +x "$G/harmless.txt" && mk_commit "$G" mode
  git -C "$G" switch -q main && git -C "$G" switch -q -c ren && git -C "$G" mv moved.txt .envrc && mk_commit "$G" ren
  git -C "$G" switch -q main && git -C "$G" switch -q -c clean && put "$G" harmless.txt 'only prose changed' && mk_commit "$G" clean
  av fetch x/demo
  ck "fetch succeeds" succeeded

  CWD=$HOST
  sha=$(rev "$HOST" refs/agents/home/all)
  av review home/all
  ck "review of the all-classes branch succeeds" succeeded
  ck "header has the full sha" has "$sha"
  ck "last line is the merge command" lastline_has "git merge $sha"
  for p in .envrc flake.nix flake.lock other.nix justfile Justfile lefthook.yml build.rs .cargo/config.toml \
    rust-toolchain.toml package.json x.sh .claude/settings.json .opencode/x AUTOLITH.org .gitattributes \
    .gitmodules link mod; do
    ck "class listed: $p" listed "$p"
  done
  ck "a harmless path is not listed" not listed a.txt
  av review home/mode
  ck "changed mode is listed" listed harmless.txt
  av review home/ren
  ck "rename into .envrc is listed" listed .envrc
  av review home/clean
  ck "clean branch review succeeds" succeeded
  ck "clean branch prints none" [ "$(section)" = none ]
}
reg T-GIT-5 t_git_5

t_git_10() {
  local HOST p before
  mk_host x/demo && map x/demo home
  HOST=$CODE/x/demo
  git -C "$HOST" switch -q -c tmp
  for p in .envrc flake.nix x.sh; do put "$HOST" "$p" "content of $p"; done
  mk_commit "$HOST" foo
  git -C "$HOST" update-ref refs/remotes/origin/foo tmp
  git -C "$HOST" switch -q main && git -C "$HOST" branch -q -D tmp
  CWD=$HOST
  av review origin/foo
  ck "control: origin/foo reviews" succeeded
  for p in .envrc flake.nix x.sh; do ck "control: class listed: $p" listed "$p"; done

  printf 'dirty\n' >>"$HOST/a.txt"
  hs_arm "$HOST"
  before=$(snap "$HOST")
  av review origin/foo
  ck "origin/foo reviews in an armed repo" succeeded
  for p in .envrc flake.nix x.sh; do ck "armed: class listed: $p" listed "$p"; done
  ck "origin/foo review ran nothing" nothing_ran
  ck "origin/foo review left the repo alone" [ "$before" = "$(snap "$HOST")" ]
  git -C "$HOST" diff --ext-diff --textconv >/dev/null 2>&1 || true
  ck "control: plain git diff does touch a canary" not nothing_ran
}
reg T-GIT-10 t_git_10

# --- T-GIT-6: hostile repo runs nothing ---
t_git_6() {
  local HOST G before
  mk_host x/demo && mk_guest home x/demo && map x/demo home
  HOST=$CODE/x/demo G=$(gdir home x/demo)
  git -C "$G" switch -q -c evil
  put "$G" .gitattributes '* filter=evil diff=evil'
  put "$G" .gitmodules '[submodule "x"]' $'\tpath = x' $'\turl = ext::sh -c touch% '"$SB/canaries/ext"
  put "$G" Justfile just-upper && put "$G" justfile just-lower && put "$G" .ENVRC upper-envrc
  put "$G" flake.nix '{ }' && put "$G" a.txt 'evil change'
  commit_gitlink "$G" evil "$(rev "$G" main)" x
  printf 'dirty\n' >>"$HOST/a.txt"
  hs_arm "$HOST"
  before=$(snap "$HOST")

  av fetch x/demo
  ck "fetch of a hostile repo succeeds" succeeded
  ck "fetch ran nothing" nothing_ran
  CWD=$HOST
  av review home/evil
  ck "review of a hostile repo succeeds" succeeded
  ck "review lists flake.nix" listed flake.nix
  ck "review lists Justfile and justfile" listed Justfile
  ck "review lists justfile" listed justfile
  ck "review ran nothing" nothing_ran
  ck "fetch and review left the repo alone" [ "$before" = "$(snap "$HOST")" ]

  git -C "$HOST" diff --ext-diff --textconv >/dev/null 2>&1 || true
  ck "control: plain git diff touches a canary" not nothing_ran
  git -C "$HOST" update-ref refs/heads/zz HEAD
  ck "control: plain update-ref runs the reference-transaction hook" test -e "$SB/canaries/hook-reference-transaction"
}
reg T-GIT-6 t_git_6

# --- T-REVIEW ---
t_review() {
  local HOST G H CG F C0 C1 Z1 A1 B1 B2 sha
  mk_host x/demo && HOST=$CODE/x/demo
  C0=$(rev "$HOST" main) && git -C "$HOST" branch old
  put "$HOST" c1.txt c1 && mk_commit "$HOST" c1 && C1=$(rev "$HOST" main)
  mk_guest home x/demo && G=$(gdir home x/demo) && map x/demo home
  git -C "$G" switch -q -c foo && put "$G" a.txt 'changed line' && put "$G" foo.txt foo && mk_commit "$G" foo
  git -C "$G" switch -q main && git -C "$G" switch -q -c cfg && put "$G" a.txt cfgline && put "$G" sub/in.txt in
  commit_gitlink "$G" cfg "$(rev "$G" main)" mod
  git -C "$G" switch -q main && git -C "$G" switch -q -c chars
  put "$G" $'pa\e\xe2\x80\xaeth.txt' $'a\e[31mred' $'b\rc' $'d\xe2\x80\xaee'
  put "$G" $'cr\rname.txt' x
  put "$G" text.txt $'k\xc3\xa4se'
  mk_commit "$G" $'subj \e[31mred \xe2\x80\xae end'
  git -C "$G" switch -q main && git -C "$G" switch -q --orphan unrelated && put "$G" u.txt u && mk_commit "$G" unrelated
  av fetch x/demo
  ck "fetch succeeds" succeeded
  F=$(rev "$HOST" refs/agents/home/foo)

  CWD=$HOST
  av review home/foo
  ck "review succeeds" succeeded
  ck "header has the full commit sha" has "$F"
  ck "header has the base sha" has "$C1"
  ck "has the paths section" has '== execution-sensitive paths'
  ck "has the diff section" has '== diff'
  ck "diff shows the change" has '+changed line'
  ck "last line is the merge command" lastline_has "git merge $F"
  av review refs/agents/home/foo
  ck "a full ref is accepted" succeeded
  av review "$F"
  ck "a sha is accepted" succeeded
  av review home/foo
  cp "$SB/out" "$SB/out.plain"

  av review -x
  ck "ref starting with - is refused" refused_for "unknown option: -x"
  av review -- -x
  ck "ref starting with - after -- is refused" refused_for "refusing ref starting with -"
  av review "--output=$SB/pwn"
  ck "an option-looking ref is refused" refused_for "unknown option: --output="
  ck "and writes no file" test ! -e "$SB/pwn"
  av review home/nosuch
  ck "unknown ref is refused" refused_for "no such ref: home/nosuch"

  # attributes in the host checkout must not hide the diff
  put "$HOST" .gitattributes '* -diff' '*.txt binary'
  printf '* -diff\n' >"$HOST/.git/info/attributes"
  av review home/foo
  ck "-diff/binary attributes: review succeeds" succeeded
  ck "-diff/binary attributes do not hide the diff" has '+changed line'
  ck "no Binary files placeholder" not has 'Binary files'
  rm "$HOST/.gitattributes" "$HOST/.git/info/attributes"

  # user config that would hide or run things, from a subdirectory
  CWD=$HOST/sub
  av review home/cfg
  ck "control: cfg review from sub/ shows everything" succeeded
  ck "control: top-level change" has '+cfgline'
  ck "control: submodule entry" has 'Subproject commit'
  ck "control: file under sub/" has 'sub/in.txt'
  cp "$GIT_CONFIG_GLOBAL" "$SB/gitconfig.bak"
  printf '#!/bin/sh\ntouch "%s/canaries/diffext"\n' "$SB" >"$SB/bin/diffext" && chmod +x "$SB/bin/diffext"
  printf '[diff]\n\trelative = true\n\tignoreSubmodules = all\n\texternal = %s\n' "$SB/bin/diffext" >>"$GIT_CONFIG_GLOBAL"
  av review home/cfg
  ck "diff.relative/ignoreSubmodules/external: review succeeds" succeeded
  ck "diff.relative does not hide the top-level change" has '+cfgline'
  ck "diff.ignoreSubmodules does not hide the submodule" has 'Subproject commit'
  ck "diff.relative does not hide sub/in.txt" has 'sub/in.txt'
  ck "diff.external ran nothing" nothing_ran
  cp "$SB/gitconfig.bak" "$GIT_CONFIG_GLOBAL"
  CWD=$HOST

  # control characters and bidi
  av review home/chars
  ck "chars: review succeeds" succeeded
  ck "chars: no raw ESC" no_raw $'\e'
  ck "chars: no raw CR" no_raw $'\r'
  ck "chars: no raw U+202E" no_raw $'\xe2\x80\xae'
  ck "chars: ESC shown as ^[" has '^['
  ck "chars: U+202E shown as <U+202E>" has '<U+202E>'
  ck "chars: ä passes unchanged" has $'k\xc3\xa4se'

  # criss-cross merge with a silently reverted change
  H=$CODE/x/cross
  mk_host x/cross
  git -C "$H" switch -q -c side && put "$H" z.txt z && mk_commit "$H" z1
  git -C "$H" switch -q main && put "$H" a.txt base feature && mk_commit "$H" a1
  git -C "$H" merge -q --no-ff -m m1 side
  Z1=$(rev "$H" side) A1=$(rev "$H" main^1)
  mk_guest home x/cross && CG=$(gdir home x/cross) && map x/cross home
  git -C "$CG" switch -q -c topic "$Z1"
  git -C "$CG" merge -q --no-commit --no-ff "$A1"
  put "$CG" a.txt base && mk_commit "$CG" m2
  git -C "$CG" switch -q -c simple main && put "$CG" s.txt s && mk_commit "$CG" simple
  av fetch x/cross
  ck "criss-cross fetch succeeds" succeeded
  CWD=$H
  av review home/simple
  ck "control: one merge base reviews without a warning" succeeded
  ck "control: no warning" not anyre 'warn'
  av review home/topic
  ck "criss-cross review succeeds" succeeded
  ck "criss-cross warns about the merge bases" anyre 'warn'
  ck "criss-cross shows the silently reverted line" has '-feature'
  CWD=$HOST

  # unrelated history
  av review home/unrelated
  ck "unrelated history still reviews" succeeded
  ck "unrelated history warns" anyre 'warn'
  ck "unrelated history shows the diff" has 'u.txt'

  # --target
  av review --target old home/foo
  ck "--target old succeeds" succeeded
  ck "--target old: base is the old commit" has "$C0"
  ck "--target old: diff includes c1.txt" has 'c1.txt'
  ck "control: default target diff has no c1.txt" not grep -qaF c1.txt "$SB/out.plain"
  av review --target nosuch home/foo
  ck "unknown --target is refused" refused_for "no branch nosuch"

  # ambiguity with a local branch
  git -C "$HOST" branch home/foo main
  av review home/foo
  ck "home/foo is refused when a local branch home/foo exists" refused_for "home/foo is ambiguous"
  git -C "$HOST" branch -q -D home/foo
  av review home/foo
  ck "control: home/foo reviews once the local branch is gone" succeeded

  # HEAD, index and working tree untouched
  printf 'wt\n' >>"$HOST/a.txt" && put "$HOST" staged.txt s && git -C "$HOST" add staged.txt && put "$HOST" u.txt u
  before=$(snapwt "$HOST")
  av review home/foo
  av review home/cfg
  av review --target old home/foo
  ck "review leaves HEAD, index and working tree alone" [ "$before" = "$(snapwt "$HOST")" ]

  # refs/replace in the host repo
  av review home/foo
  cp "$SB/out" "$SB/out.a"
  B1=$(git -C "$HOST" rev-parse "$F:a.txt")
  B2=$(printf 'tampered\n' | git -C "$HOST" hash-object -w --stdin)
  git -C "$HOST" replace -f "$B1" "$B2" && git -C "$HOST" replace -f "$F" "$C1"
  av review home/foo
  ck "refs/replace does not alter the review" cmp -s "$SB/out" "$SB/out.a"
}
reg T-REVIEW t_review

# --- T-OPS-2: wipe-check ---
t_ops_2() {
  local HOST G W c name
  mk_host x/demo && mk_host x/second && map x/demo home && map x/second other
  HOST=$CODE/x/demo
  mk_guest home x/demo && G=$(gdir home x/demo) && W=$(dirname "$G")

  av wipe-check other
  ck "a mapped repo that was never synced passes" succeeded
  av fetch x/demo
  av wipe-check home
  ck "control: a fetched guest passes" succeeded

  git -C "$G" switch -q -c wip && put "$G" work.txt w && mk_commit "$G" work
  av wipe-check home
  ck "an unfetched commit is refused" refused_for "lost x/demo refs/heads/wip "
  av fetch x/demo
  av wipe-check home
  ck "the same guest passes after fetch" succeeded

  git -C "$G" switch -q -c wip2 && put "$G" work2.txt w2 && mk_commit "$G" work2
  git -C "$HOST" fetch -q "$G" wip2:refs/agents/other/x
  av wipe-check home
  ck "another VM's refs/agents/other do not count" refused_for "lost x/demo refs/heads/wip2 "
  av fetch x/demo
  av wipe-check home
  ck "control: passes once it is in refs/agents/home" succeeded

  printf 'stash me\n' >>"$G/a.txt" && git -C "$G" stash -q
  av wipe-check home
  ck "a stash is refused" refused_for "lost x/demo refs/stash "
  git -C "$G" stash drop -q
  av wipe-check home
  ck "control: passes without the stash" succeeded

  c=$(git -C "$G" commit-tree -p HEAD -m guest-only 'HEAD^{tree}')
  git -C "$G" update-ref refs/remotes/wotan/x "$c"
  av wipe-check home
  ck "refs/remotes/wotan is ignored" succeeded
  git -C "$G" update-ref refs/heads/x "$c"
  av wipe-check home
  ck "the same commit on a real branch is refused" refused_for "lost x/demo refs/heads/x "
  git -C "$G" update-ref -d refs/heads/x && git -C "$G" update-ref -d refs/remotes/wotan/x

  git clone -q "$HOST" "$W/extra"
  av wipe-check home
  ck "an unmapped extra clone is refused" refused_for "clone extra is not mapped to home"
  rm -rf "$W/extra"
  av wipe-check home
  ck "control: passes without the extra clone" succeeded

  name=$'ev\eil\nname'
  git clone -q "$HOST" "$W/$name"
  av wipe-check home
  ck "a hostile clone name is refused" refused_for "unexpected clone path"
  ck "the hostile name is not printed raw" no_raw $'\e'
  ck "the hostile name cannot forge an output line" not grep -qa '^name' "$SB/out" "$SB/err"
  rm -rf -- "${W:?}/$name"
  av wipe-check home
  ck "control: passes without the hostile clone" succeeded

  AVM_FAKE_DOWN=1 av wipe-check home
  ck "ssh down is refused" refused_for "cannot list clones on home"
  av wipe-check home
  ck "control: passes with ssh up" succeeded
}
reg T-OPS-2 t_ops_2

# --- T-ISO: ssh hardening options on every call ---
t_iso() {
  local o
  mk_host x/demo && map x/demo home
  av sync x/demo main
  ck "sync succeeds" succeeded
  av fetch x/demo
  ck "fetch succeeds" succeeded
  av wipe-check home
  ck "wipe-check succeeds" succeeded
  ck "ssh was called at least three times" [ "$(wc -l <"$AVM_FAKE_LOG")" -ge 3 ]
  for o in ForwardAgent=no ForwardX11=no PermitLocalCommand=no StrictHostKeyChecking=yes; do
    ck "every ssh call has $o" not grep -vqF -e "$o" "$AVM_FAKE_LOG"
  done
}
reg T-ISO t_iso

# --- runner ---
failed=0 ran=0
for e in "${TESTS[@]}"; do
  ID=${e%%:*}
  sandbox "${e#*:}"
  st=0
  set +e
  (
    set -e
    "${e#*:}"
    : >"$SB/.done"
  )
  st=$?
  set -e
  if [[ -e $SB/.done ]]; then
    ran=$((ran + 1))
  else
    printf 'not ok %s test aborted (exit %s)\n' "$ID" "$st"
    : >"$SB/.failed"
    dump
  fi
  if [[ -e $SB/.failed ]]; then failed=$((failed + 1)); fi
done
if ((ran != ${#TESTS[@]})); then
  printf 'not ok count: %d of %d tests completed\n' "$ran" "${#TESTS[@]}"
  failed=$((failed + 1))
fi
printf '# %d of %d tests completed, %d failed\n' "$ran" "${#TESTS[@]}" "$failed"
exit $((failed > 0))
