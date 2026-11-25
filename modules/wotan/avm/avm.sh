#!/usr/bin/env bash
# avm: host-side git transport and review gate between wotan (trusted) and
# microVMs running AI agents (hostile). Code moves only as git objects, only
# when the host asks, and nothing from a VM is ever executed on the host.
set -euo pipefail
export LC_ALL=C
umask 077

# Repo-local and ambient git state must not steer any call below. GIT_CONFIG_GLOBAL
# and GIT_CONFIG_SYSTEM stay: the tests point them at fixtures.
while IFS= read -r v; do unset "$v"; done < <(git rev-parse --local-env-vars)
for v in "${!GIT_CONFIG_KEY_@}" "${!GIT_CONFIG_VALUE_@}"; do unset "$v"; done
unset GIT_EXTERNAL_DIFF GIT_SSH GIT_SSH_COMMAND GIT_ASKPASS GIT_PROXY_COMMAND GIT_TEMPLATE_DIR
export GIT_NO_REPLACE_OBJECTS=1 GIT_TERMINAL_PROMPT=0 GIT_ATTR_NOSYSTEM=1

here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

AVM_REPOS=${AVM_REPOS:-${XDG_CONFIG_HOME:-$HOME/.config}/avm/repos}
AVM_CODE_ROOT=${AVM_CODE_ROOT:-$HOME/code}
AVM_SSH=${AVM_SSH:-ssh}

REPO_RE='^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$'
BASE_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
VM_RE='^[a-z][a-z0-9-]{0,31}$'
BRANCH_RE='^[A-Za-z0-9][A-Za-z0-9._/-]*$'
HEX_RE='^([0-9a-f]{40}|[0-9a-f]{64})$'

# ---------------------------------------------------------------- sanitize
# Everything that originates in a VM or an agent branch passes through this
# before it reaches a terminal: escapes, CR, DEL, C1 controls and Trojan-Source
# characters become visible text.
SAN=(-e 's/\x00//g')
for ((c = 1; c < 32; c++)); do
  if [[ $c -eq 9 || $c -eq 10 ]]; then continue; fi
  printf -v hex '%02x' "$c"
  printf -v car '\\%03o' $((c + 64))
  printf -v car '%b' "$car"
  # shellcheck disable=SC1003
  if [[ $car == '\' ]]; then car='\\'; fi
  SAN+=(-e "s/\\x$hex/^$car/g")
done
SAN+=(-e 's/\x7f/^?/g')
for ((c = 128; c < 160; c++)); do
  printf -v hex '%02x' "$c"
  printf -v u '%04X' "$c"
  SAN+=(-e "s/\\xc2\\x$hex/<U+$u>/g")
done
for b in 8b 8c 8d 8e 8f aa ab ac ad ae; do
  printf -v u '%04X' $((0x2000 + 0x$b - 0x80))
  SAN+=(-e "s/\\xe2\\x80\\x$b/<U+$u>/g")
done
for b in a6 a7 a8 a9; do
  printf -v u '%04X' $((0x2040 + 0x$b - 0x80))
  SAN+=(-e "s/\\xe2\\x81\\x$b/<U+$u>/g")
done
SAN+=(-e 's/\xef\xbb\xbf/<U+FEFF>/g')

sanitize() { sed "${SAN[@]}"; }

# ----------------------------------------------------------------- helpers
die() {
  printf 'avm: %s\n' "$*" | sanitize >&2
  exit 1
}

usage() {
  cat <<'EOF'
usage:
  avm sync [--vm VM] <repo> [branch]   push a branch to refs/remotes/wotan/ in the VM clone
  avm fetch [--vm VM] <repo>           quarantine-fetch VM branches into refs/agents/<vm>/
  avm review [--target BR] <ref>       show what an agent ref changes relative to the target
  avm wipe-check <vm>                  exit 0 when wiping the VM loses no committed work
EOF
}

usage_err() {
  printf 'avm: %s\n' "$*" >&2
  usage >&2
  exit 2
}

WORK=
cleanup() {
  if [[ -n $WORK ]]; then rm -rf -- "$WORK"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkwork() { WORK=$(mktemp -d "${TMPDIR:-/tmp}/avm.XXXXXX"); }

[[ -n $AVM_SSH ]] || die "AVM_SSH is empty"
SSH_OPTS=(-o ForwardAgent=no -o ForwardX11=no -o PermitLocalCommand=no
  -o StrictHostKeyChecking=yes -o BatchMode=yes -o ClearAllForwardings=yes)
printf -v SSH_CMD '%q' "$AVM_SSH"
for o in "${SSH_OPTS[@]}"; do
  printf -v q '%q' "$o"
  SSH_CMD+=" $q"
done

# Plain ssh to a VM. Guest stderr is sanitized; callers redirect guest stdout.
vm_ssh() {
  local vm=$1 rc=0
  shift
  "$AVM_SSH" "${SSH_OPTS[@]}" "avm-$vm" "$@" </dev/null 2> >(sanitize >&2) || rc=$?
  wait $! 2>/dev/null || true
  return "$rc"
}

HARDEN=(-c core.hooksPath=/dev/null -c core.fsmonitor=false
  -c core.attributesFile=/dev/null -c core.quotePath=true
  -c submodule.recurse=false -c gc.auto=0 -c maintenance.auto=false
  -c fetch.writeCommitGraph=false -c transfer.bundleURI=false
  -c protocol.allow=never)

# A repo may be sha256, so the empty tree id is asked of the repo itself.
declare -A ET=()
empty_tree() {
  git -c core.hooksPath=/dev/null -c core.fsmonitor=false -C "$1" hash-object -t tree /dev/null
}

# Every git call in a host repo goes through here. The attribute source is the
# empty tree, so no .gitattributes (worktree or branch) can attach filters,
# textconv or external drivers, or hide a diff.
g() {
  local repo=$1 rc=0 et
  shift
  et=${ET[$repo]:-}
  if [[ -z $et ]]; then
    et=$(empty_tree "$repo") || die "not a git repository: $repo"
    ET[$repo]=$et
  fi
  git --no-pager --attr-source="$et" -C "$repo" "${HARDEN[@]}" "$@" \
    </dev/null 2> >(sanitize >&2) || rc=$?
  wait $! 2>/dev/null || true
  return "$rc"
}

# The only form of g allowed to talk to a VM.
vmgit() {
  local repo=$1
  shift
  GIT_SSH_COMMAND=$SSH_CMD g "$repo" -c protocol.ssh.allow=always -c ssh.variant=ssh "$@"
}

# Empty bare repo <dir> that borrows the objects of <repo> but none of its
# config, refs, hooks or info/attributes.
scratch_repo() {
  local repo=$1 dir=$2 fmt objdir
  fmt=$(g "$repo" rev-parse --show-object-format) || die "cannot read object format"
  objdir=$(g "$repo" rev-parse --path-format=absolute --git-path objects) ||
    die "cannot find object dir"
  git -c core.hooksPath=/dev/null -c init.defaultBranch=main init -q --bare \
    --template= --object-format="$fmt" "$dir"
  mkdir -p "$dir/objects/info"
  printf '%s\n' "$objdir" >"$dir/objects/info/alternates"
}

# ------------------------------------------------------------------ config
declare -A MAP_VM=()
MAP_LOADED=0
load_map() {
  if [[ $MAP_LOADED == 1 ]]; then return 0; fi
  [[ -r $AVM_REPOS ]] || die "cannot read $AVM_REPOS"
  local n=0 line id vm extra key
  declare -A seen=()
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    id='' vm='' extra=''
    read -r id vm extra <<<"$line" || true
    if [[ -z $id || $id == \#* ]]; then continue; fi
    [[ -n $vm && -z $extra && $id =~ $REPO_RE && $vm =~ $VM_RE &&
      $vm != origin && $vm != upstream ]] || die "$AVM_REPOS:$n: malformed line"
    [[ -z ${MAP_VM[$id]+x} ]] || die "$AVM_REPOS:$n: $id listed twice"
    key=$vm/${id##*/}
    [[ -z ${seen[$key]+x} ]] || die "$AVM_REPOS:$n: basename ${id##*/} used twice for $vm"
    seen[$key]=1
    MAP_VM[$id]=$vm
  done <"$AVM_REPOS"
  MAP_LOADED=1
}

REPO_ID='' REPO_VM='' REPO_BASE='' REPO_PATH='' REPO_URL=''
resolve_repo() {
  local arg=$1 m n=0 id='' root real top
  load_map
  [[ $arg =~ $REPO_RE ]] || die "$arg is not mapped to a VM"
  if [[ -n ${MAP_VM[$arg]+x} ]]; then
    id=$arg
  else
    for m in "${!MAP_VM[@]}"; do
      if [[ ${m##*/} == "$arg" ]]; then
        id=$m
        n=$((n + 1))
      fi
    done
    [[ $n -le 1 ]] || die "$arg is ambiguous, use the full repo id"
    [[ -n $id ]] || die "$arg is not mapped to a VM"
  fi
  root=$(realpath -e -- "$AVM_CODE_ROOT") || die "AVM_CODE_ROOT does not exist"
  real=$(realpath -e -- "$AVM_CODE_ROOT/$id") || die "no checkout for $id under $AVM_CODE_ROOT"
  # A symlink must not point one VM's repo id at another VM's checkout.
  [[ $real == "$root/$id" ]] || die "$id resolves outside its own path: $real"
  g "$real" rev-parse --git-dir >/dev/null || die "$id is not a git repository"
  top=$(g "$real" rev-parse --show-toplevel) || die "$id is not a git repository"
  [[ $(realpath -e -- "$top") == "$real" ]] || die "$id is not the toplevel of a git repository"
  REPO_ID=$id
  REPO_VM=${MAP_VM[$id]}
  REPO_BASE=${id##*/}
  REPO_PATH=$real
  REPO_URL="avm-$REPO_VM:/srv/work/$REPO_BASE"
}

OPT_VM='' OPT_TARGET='' ARGS=()
parse_args() {
  local allow=$1
  shift
  OPT_VM='' OPT_TARGET='' ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --vm)
        [[ $allow == vm && $# -ge 2 ]] || usage_err "bad option: $1"
        OPT_VM=$2
        shift 2
        ;;
      --vm=*)
        [[ $allow == vm ]] || usage_err "bad option: $1"
        OPT_VM=${1#--vm=}
        shift
        ;;
      --target)
        [[ $allow == target && $# -ge 2 ]] || usage_err "bad option: $1"
        OPT_TARGET=$2
        shift 2
        ;;
      --target=*)
        [[ $allow == target ]] || usage_err "bad option: $1"
        OPT_TARGET=${1#--target=}
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        ARGS+=("$@")
        break
        ;;
      -*) usage_err "unknown option: $1" ;;
      *)
        ARGS+=("$1")
        shift
        ;;
    esac
  done
  if [[ $allow == vm && -n $OPT_VM ]]; then
    [[ $OPT_VM =~ $VM_RE ]] || usage_err "bad vm name: $OPT_VM"
  fi
}

assert_vm() {
  if [[ -n $OPT_VM && $OPT_VM != "$REPO_VM" ]]; then
    die "$REPO_ID is mapped to $REPO_VM, not $OPT_VM"
  fi
}

# -------------------------------------------------------------------- sync
cmd_sync() {
  parse_args vm "$@"
  [[ ${#ARGS[@]} -ge 1 && ${#ARGS[@]} -le 2 ]] || usage_err "sync takes <repo> [branch]"
  resolve_repo "${ARGS[0]}"
  assert_vm
  local branch=${ARGS[1]:-}
  if [[ -z $branch ]]; then
    branch=$(g "$REPO_PATH" symbolic-ref -q --short HEAD) ||
      die "HEAD of $REPO_ID is detached, name a branch"
  fi
  [[ $branch =~ $BRANCH_RE ]] || die "bad branch name: $branch"
  g "$REPO_PATH" check-ref-format --branch "$branch" >/dev/null || die "bad branch name: $branch"
  g "$REPO_PATH" show-ref --verify --quiet "refs/heads/$branch" ||
    die "no branch $branch in $REPO_ID"

  # base and branch are validated above, so no further shell quoting is needed.
  local dir=/srv/work/$REPO_BASE
  vm_ssh "$REPO_VM" git init -q "$dir" >/dev/null || die "cannot init $dir on $REPO_VM"
  # Pushing to refs/remotes/wotan/ never touches the agent's branches or
  # working tree, and receive.denyCurrentBranch never applies.
  vmgit "$REPO_PATH" -c push.followTags=false push --no-verify \
    --no-recurse-submodules --no-signed "$REPO_URL" \
    "+refs/heads/$branch:refs/remotes/wotan/$branch" >/dev/null ||
    die "push to $REPO_VM failed"
  vm_ssh "$REPO_VM" "cd $dir && { git rev-parse -q --verify HEAD >/dev/null || git checkout -q -b $branch refs/remotes/wotan/$branch; }" >/dev/null ||
    die "initial checkout on $REPO_VM failed"
  printf 'synced %s %s -> %s\n' "$REPO_ID" "$branch" "$REPO_URL" | sanitize
}

# ------------------------------------------------------------------- fetch
cmd_fetch() {
  parse_args vm "$@"
  [[ ${#ARGS[@]} -eq 1 ]] || usage_err "fetch takes <repo>"
  resolve_repo "${ARGS[0]}"
  assert_vm
  mkwork
  local q=$WORK/q ref prefix=refs/agents/$REPO_VM/

  # Stage 1 runs in a throwaway repo so a failed fetch leaves nothing behind
  # in the real object store (fetch-side fsck does not quarantine, and a second
  # fetch would skip objects it already has). The repo's own config is not read.
  scratch_repo "$REPO_PATH" "$q"
  vmgit "$q" -c transfer.fsckObjects=true -c fetch.fsckObjects=true fetch \
    --no-tags --no-recurse-submodules --no-write-fetch-head --no-auto-maintenance \
    --refmap= --no-prune "$REPO_URL" '+refs/heads/*:refs/heads/*' >/dev/null ||
    die "fetch from $REPO_VM failed"
  g "$q" for-each-ref --format='%(refname)' >"$WORK/qrefs"
  while IFS= read -r ref; do
    [[ $ref == refs/heads/?* ]] || die "unexpected ref from VM: $ref"
    g "$q" check-ref-format "$ref" || die "bad ref name from VM: $ref"
    g "$q" rev-parse --verify --quiet --end-of-options "$ref^{commit}" >/dev/null ||
      die "ref from VM is not a commit: $ref"
  done <"$WORK/qrefs"

  g "$REPO_PATH" for-each-ref --format='%(refname) %(objectname)' >"$WORK/before"
  g "$REPO_PATH" -c protocol.file.allow=always -c transfer.fsckObjects=true \
    -c fetch.fsckObjects=true fetch --no-tags --no-recurse-submodules \
    --no-write-fetch-head --no-auto-maintenance --refmap= --no-prune \
    "$q" "+refs/heads/*:refs/agents/$REPO_VM/*" >/dev/null ||
    die "import from quarantine failed"
  g "$REPO_PATH" for-each-ref --format='%(refname) %(objectname)' >"$WORK/after"

  if ! cmp -s <(awk -v p="$prefix" 'index($1, p) != 1' "$WORK/before") \
    <(awk -v p="$prefix" 'index($1, p) != 1' "$WORK/after"); then
    die "refs outside $prefix changed during fetch, investigate before continuing"
  fi

  local name old new kind
  awk -v p="$prefix" '
    NR == FNR { if (index($1, p) == 1) o[$1] = $2; next }
    index($1, p) == 1 {
      if (!($1 in o)) print $1, "-", $2
      else if (o[$1] != $2) print $1, o[$1], $2
    }' "$WORK/before" "$WORK/after" >"$WORK/changed"
  if [[ ! -s $WORK/changed ]]; then
    echo "nothing new"
    return 0
  fi
  while read -r name old new; do
    if [[ $old == - ]]; then
      printf 'new %s %s\n' "${name#refs/agents/}" "${new:0:12}"
    else
      if g "$REPO_PATH" merge-base --is-ancestor "$old" "$new"; then kind=updated; else kind=forced; fi
      printf '%s %s %s (was %s)\n' "$kind" "${name#refs/agents/}" "${new:0:12}" "$old"
    fi
  done <"$WORK/changed" | sanitize
}

# ------------------------------------------------------------------ review
colorize() {
  sed -E \
    -e $'s/^(diff --git .*)$/\033[1m\\1\033[0m/' \
    -e $'s/^(@@.*)$/\033[36m\\1\033[0m/' \
    -e $'/^(\\+\\+\\+|---) /!{s/^(\\+.*)$/\033[32m\\1\033[0m/;s/^(-.*)$/\033[31m\\1\033[0m/}'
}

R_TOP='' R_DIFF='' R_DISPLAY='' R_SHA='' R_TREF='' R_TSHA='' R_BASE='' R_WARN='' R_COUNT='' R_CLS='' R_COLOR=0
render_review() {
  {
    printf 'ref: %s\n' "$R_DISPLAY"
    printf 'commit: %s\n' "$R_SHA"
    printf 'target: %s %s\n' "$R_TREF" "$R_TSHA"
    printf 'base: %s\n' "$R_BASE"
    if [[ -n $R_WARN ]]; then printf 'warning: %s\n' "$R_WARN"; fi
    printf 'commits: %s\n' "$R_COUNT"
  } | sanitize
  g "$R_TOP" log --oneline --no-decorate --no-show-signature --no-notes --no-color \
    -n 50 "$R_TSHA..$R_SHA" | sanitize
  if [[ $R_COUNT -eq 0 ]]; then
    echo "(no commits)"
  elif [[ $R_COUNT -gt 50 ]]; then
    printf '(truncated: showing 50 of %s commits)\n' "$R_COUNT"
  fi
  echo "== execution-sensitive paths"
  if [[ -n $R_CLS ]]; then printf '%s\n' "$R_CLS" | sanitize; else echo none; fi
  echo "== diff"
  if [[ $R_COLOR -eq 1 ]]; then
    g "$R_DIFF" diff-tree -r -p --no-renames --full-index --no-ext-diff --no-textconv \
      --no-color --no-relative --ignore-submodules=none --submodule=short \
      --src-prefix=a/ --dst-prefix=b/ "$R_BASE" "$R_SHA" | sanitize | colorize
  else
    g "$R_DIFF" diff-tree -r -p --no-renames --full-index --no-ext-diff --no-textconv \
      --no-color --no-relative --ignore-submodules=none --submodule=short \
      --src-prefix=a/ --dst-prefix=b/ "$R_BASE" "$R_SHA" | sanitize
  fi
  printf 'merge exactly what you reviewed: git merge %s\n' "$R_SHA"
}

cmd_review() {
  parse_args target "$@"
  [[ ${#ARGS[@]} -eq 1 ]] || usage_err "review takes <ref>"
  local ref=${ARGS[0]} a b t tname='' nb=0 bases
  [[ $ref != -* ]] || die "refusing ref starting with -"
  R_TOP=$(git -c core.hooksPath=/dev/null -c core.fsmonitor=false rev-parse --show-toplevel) ||
    die "not inside a git work tree"

  a=$(g "$R_TOP" rev-parse --verify --quiet --end-of-options "refs/agents/$ref^{commit}") || a=''
  b=$(g "$R_TOP" rev-parse --verify --quiet --end-of-options "$ref^{commit}") || b=''
  if [[ -n $a && -n $b && $a != "$b" ]]; then
    die "$ref is ambiguous (refs/agents/$ref and $ref differ), give the full ref name"
  fi
  if [[ -n $a ]]; then
    R_SHA=$a
    R_DISPLAY=refs/agents/$ref
  elif [[ -n $b ]]; then
    R_SHA=$b
    R_DISPLAY=$ref
  else
    die "no such ref: $ref"
  fi

  if [[ -n $OPT_TARGET ]]; then
    [[ $OPT_TARGET =~ $BRANCH_RE ]] || die "bad target branch: $OPT_TARGET"
    g "$R_TOP" check-ref-format --branch "$OPT_TARGET" >/dev/null || die "bad target branch: $OPT_TARGET"
    tname=$OPT_TARGET
    g "$R_TOP" show-ref --verify --quiet "refs/heads/$tname" || die "no branch $tname"
  else
    for t in main master; do
      if g "$R_TOP" show-ref --verify --quiet "refs/heads/$t"; then
        tname=$t
        break
      fi
    done
    [[ -n $tname ]] || die "neither main nor master exists, pass --target"
  fi
  R_TREF=refs/heads/$tname
  R_TSHA=$(g "$R_TOP" rev-parse --verify --quiet --end-of-options "$R_TREF^{commit}") ||
    die "target $R_TREF is not a commit"

  bases=$(g "$R_TOP" merge-base --all "$R_TSHA" "$R_SHA" || true)
  if [[ -n $bases ]]; then nb=$(printf '%s\n' "$bases" | wc -l); fi
  if [[ $nb -eq 1 ]]; then
    R_BASE=$bases
  else
    # Several merge bases can hide a silent revert behind a three-dot diff.
    R_BASE=$R_TSHA
    R_WARN="$nb merge bases, diffing against the target itself"
  fi
  R_COUNT=$(g "$R_TOP" rev-list --count "$R_TSHA..$R_SHA") || die "rev-list failed"

  # --attr-source does not cover .git/info/attributes, which could mark a file
  # binary and hide its diff, so both diffs run in a scratch repo.
  mkwork
  R_DIFF=$WORK/r
  scratch_repo "$R_TOP" "$R_DIFF"

  # Assigned on its own so a classifier failure aborts instead of vanishing in a pipe.
  R_CLS=$(g "$R_DIFF" diff-tree -r -z --raw --no-renames --full-index \
    --ignore-submodules=none "$R_BASE" "$R_SHA" | "$here/classify.sh") ||
    die "classifier failed"

  if [[ -t 1 && -z ${NO_COLOR:-} ]]; then R_COLOR=1; fi
  render_review >"$WORK/review"
  if [[ -t 1 ]] && command -v less >/dev/null; then
    env -u LESSOPEN -u LESS -u LESSCLOSE -u LESSKEY -u LESSKEYIN \
      LESSSECURE=1 LESSHISTFILE=- less -RFX <"$WORK/review"
  else
    cat -- "$WORK/review"
  fi
}

# -------------------------------------------------------------- wipe-check
cmd_wipe_check() {
  parse_args none "$@"
  [[ ${#ARGS[@]} -eq 1 ]] || usage_err "wipe-check takes <vm>"
  local vm=${ARGS[0]} id base e sha name commit found bad=0
  [[ $vm =~ $VM_RE ]] || usage_err "bad vm name: $vm"
  load_map
  declare -A mine=() have=()
  for id in "${!MAP_VM[@]}"; do
    if [[ ${MAP_VM[$id]} == "$vm" ]]; then mine[${id##*/}]=$id; fi
  done
  [[ ${#mine[@]} -gt 0 ]] || die "$vm does not occur in $AVM_REPOS"
  mkwork

  # Clones have a .git directory; linked worktrees have a .git file. The volume's
  # own lost+found is unreadable for the agent and would fail the find; only a
  # root-owned one is skipped, so the agent cannot hide a clone there.
  if ! vm_ssh "$vm" "cd /srv/work && find . -maxdepth 2 -path ./lost+found -user 0 -prune -o -path './*/.git' -type d -print0" \
    >"$WORK/clones"; then
    echo "refuse: cannot list clones on $vm" >&2
    exit 1
  fi
  local -a entries
  mapfile -d '' -t entries <"$WORK/clones"
  for e in "${entries[@]}"; do
    base=${e#./}
    base=${base%/.git}
    if [[ $e != ./*/.git || ! $base =~ $BASE_RE ]]; then
      # %q: a newline in the name must not forge a line of our own output.
      printf 'refuse: unexpected clone path from VM: %q\n' "$e" | sanitize >&2
      bad=1
    elif [[ -z ${mine[$base]+x} ]]; then
      printf 'refuse: clone %s is not mapped to %s\n' "$base" "$vm" | sanitize >&2
      bad=1
    else
      have[$base]=1
    fi
  done

  for base in $(printf '%s\n' "${!have[@]}" | sort); do
    resolve_repo "${mine[$base]}"
    if ! vmgit "$REPO_PATH" ls-remote "$REPO_URL" >"$WORK/ls"; then
      printf 'refuse: cannot list refs of %s\n' "$REPO_URL" | sanitize >&2
      bad=1
      continue
    fi
    while IFS=$'\t' read -r sha name; do
      if [[ $name == *'^{}' || $name == refs/remotes/wotan/* ]]; then continue; fi
      if [[ ! $sha =~ $HEX_RE ]]; then
        printf 'refuse: malformed ref line from %s: %s\n' "$REPO_URL" "$name" | sanitize >&2
        bad=1
        continue
      fi
      commit=$(g "$REPO_PATH" rev-parse --verify --quiet --end-of-options "$sha^{commit}") || commit=''
      found=''
      if [[ -n $commit ]]; then
        found=$(g "$REPO_PATH" for-each-ref --count=1 --format=x --contains "$commit" \
          "refs/agents/$vm" refs/heads refs/remotes) || found=''
      fi
      if [[ -z $found ]]; then
        printf 'lost %s %s %s\n' "$REPO_ID" "$name" "${sha:0:12}" | sanitize >&2
        bad=1
      fi
    done <"$WORK/ls"
  done

  if [[ $bad -eq 0 ]]; then echo "ok: wiping $vm loses no committed work"; fi
  echo "note: uncommitted changes, detached HEADs of linked worktrees, and clones outside /srv/work are not covered"
  exit "$bad"
}

# -------------------------------------------------------------------- main
case ${1:-} in
  sync)
    shift
    cmd_sync "$@"
    ;;
  fetch)
    shift
    cmd_fetch "$@"
    ;;
  review)
    shift
    cmd_review "$@"
    ;;
  wipe-check)
    shift
    cmd_wipe_check "$@"
    ;;
  '' | -h | --help | help) usage ;;
  *) usage_err "unknown command: $1" ;;
esac
