#!/usr/bin/env bash
# Unit test for ../classify.sh. Plain bash, TAP-like output.
set -u
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLASSIFY=$here/../classify.sh

# Lower bound on assertions; a silently skipped section drops below it.
MIN_ASSERTIONS=70

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ERR=$TMP/stderr

SHA1=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SHA2=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
tab=$'\t'
nl=$'\n'

count=0
bad=0
out=''
rc=0

assert_eq() { # desc want got
  count=$((count + 1))
  if [[ $2 == "$3" ]]; then
    printf 'ok %d - %s\n' "$count" "$1"
  else
    bad=$((bad + 1))
    printf 'not ok %d - %s\n' "$count" "$1"
    printf '#   want: %q\n#   got:  %q\n' "$2" "$3"
  fi
}

# rec <old> <new> <status> <path> [path2]: one raw record on stdout.
rec() {
  printf ':%s %s %s %s %s\0%s\0' "$1" "$2" "$SHA1" "$SHA2" "$3" "$4"
  if (($# >= 5)); then
    printf '%s\0' "$5"
  fi
}

# L <class> <status> <path>: expected output line, no trailing newline.
L() {
  printf '%s\t%s\t%s' "$1" "$2" "$3"
}

# run <cmd...>: pipe the command's stdout into classify.sh.
run() {
  out=$("$@" | bash "$CLASSIFY" 2>"$ERR"; exit "${PIPESTATUS[1]}")
  rc=$?
}

check() { # desc want cmd...
  local desc=$1 want=$2
  shift 2
  run "$@"
  assert_eq "$desc" "0|$want" "$rc|$out"
}

check_fail() { # desc cmd...
  local desc=$1 err=none
  shift
  run "$@"
  if [[ -s $ERR ]]; then
    err=msg
  fi
  assert_eq "$desc" "1||msg" "$rc|$out|$err"
}

pos() { # class path
  check "$1: $2" "$(L "$1" M "$2")" rec 100644 100644 M "$2"
}

neg() { # path
  check "no finding: $1" "" rec 100644 100644 M "$1"
}

assert_eq 'classify.sh is executable' yes "$([[ -x $CLASSIFY ]] && echo yes || echo no)"

# One positive fixture per pattern, case variants, nested depth.
POS=(
  'envrc .envrc'
  'nix default.nix'
  'nix flake.lock'
  'just justfile'
  'just .justfile'
  'just tasks.just'
  'lefthook lefthook.yml'
  'lefthook .lefthook.yml'
  'lefthook lefthook-local.yml'
  'lefthook .lefthook-local.yml'
  'cargo build.rs'
  'cargo .cargo/config.toml'
  'cargo rust-toolchain.toml'
  'cargo rust-toolchain'
  'package package.json'
  'shell run.sh'
  'agent-config .claude/settings.json'
  'agent-config .opencode/skills/x.md'
  'agent-config AUTOLITH.org'
  'git .gitattributes'
  'git .gitmodules'
  'just Justfile'
  'just JUSTFILE'
  'nix FLAKE.NIX'
  'nix Flake.Lock'
  'agent-config .Claude/x.md'
  'agent-config autolith.org'
  'cargo Build.RS'
  'shell Run.SH'
  'envrc .ENVRC'
  'envrc a/b/c/.envrc'
  'just a/b/c/d/justfile'
  'cargo x/y/.cargo/z/config'
  'agent-config x/.claude/a/b/c.md'
  'package apps/web/package.json'
  'lefthook ci/lefthook-local.yaml'
)
for e in "${POS[@]}"; do
  pos "${e%% *}" "${e#* }"
done

# Near-misses that must not be flagged.
NEG=(
  src/main.rs
  docs/flake.lock.md
  nix/readme.md
  my.cargo/x
  .claudette/x
  package.json.bak
  justfile.md
  .envrc.bak
  build.rsx
  rust-toolchain.md
  foo.shx
  x/lefthook
)
for p in "${NEG[@]}"; do
  neg "$p"
done

# Deletion: path classes still apply, mode classes do not.
check 'deleted justfile' "$(L just D justfile)" rec 100644 000000 D justfile
check 'deleted .envrc' "$(L envrc D .envrc)" rec 100644 000000 D .envrc
check 'deleted executable is quiet' '' rec 100755 000000 D tool
check 'deleted symlink is quiet' '' rec 120000 000000 D link

# Renames and copies: both paths classified, matching path printed.
check 'rename into .envrc' "$(L envrc R100 .envrc)" rec 100644 100644 R100 doc.txt .envrc
check 'rename out of flake.lock' "$(L nix R090 flake.lock)" rec 100644 100644 R090 flake.lock moved.txt
check 'rename between two sensitive paths' "$(L nix R100 a.nix)$nl$(L shell R100 scripts/b.sh)" \
  rec 100644 100644 R100 a.nix scripts/b.sh
check 'copy into a shell script' "$(L shell C075 tools/x.sh)" rec 100644 100644 C075 src.txt tools/x.sh
check 'copy out of .envrc' "$(L envrc C100 .envrc)" rec 100644 100644 C100 .envrc copy.txt
check 'benign rename' '' rec 100644 100644 R100 a.txt b.txt
check 'rename with chmod +x reports the new path' \
  "$(L executable R095 bin/b.txt)$nl$(L mode-change R095 bin/b.txt)" \
  rec 100644 100755 R095 a.txt bin/b.txt

# Modes.
check 'new symlink' "$(L symlink A link)" rec 000000 120000 A link
check 'new symlink with sensitive name' "$(L shell A ln.sh)$nl$(L symlink A ln.sh)" rec 000000 120000 A ln.sh
check 'new submodule' "$(L submodule A vendor/mod)" rec 000000 160000 A vendor/mod
check 'new executable file' "$(L executable A tool)" rec 000000 100755 A tool
check 'chmod +x' "$(L executable M tool)$nl$(L mode-change M tool)" rec 100644 100755 M tool
check 'chmod -x' "$(L mode-change M tool)" rec 100755 100644 M tool
check 'executable unchanged' '' rec 100755 100755 M tool
check 'type change to symlink' "$(L symlink T f)$nl$(L mode-change T f)" rec 100644 120000 T f

# Several records keep input order.
s_multi() {
  rec 100644 100644 M a.nix
  rec 100644 100644 M README.md
  rec 000000 100644 A b.sh
}
check 'input order across records' "$(L nix M a.nix)$nl$(L shell A b.sh)" s_multi

# Hostile paths stay on one line with no raw control bytes.
weird=$'dir/a\nb\033c\td e.sh'
printf -v q '%q' "$weird"
run rec 100644 100644 M "$weird"
assert_eq 'weird path: quoted output' "0|$(L shell M "$q")" "$rc|$out"
assert_eq 'weird path: one line' '' "${out//[!$nl]/}"
assert_eq 'weird path: exactly two tabs' "$tab$tab" "${out//[!"$tab"]/}"
rest=${out//"$tab"/}
ctl=clean
case $rest in
  *[[:cntrl:]]*) ctl=control-byte ;;
esac
assert_eq 'weird path: no control byte' clean "$ctl"
printf -v q '%q' 'my dir/run.sh'
check 'path with spaces is quoted' "$(L shell M "$q")" rec 100644 100644 M 'my dir/run.sh'

# Malformed and truncated input fails closed.
s_garbage() { printf 'garbage\0x\0'; }
s_badmode() { printf ':10064 100644 %s %s M\0f.nix\0' "$SHA1" "$SHA2"; }
s_missing_field() { printf ':100644 100644 %s M\0f.nix\0' "$SHA1"; }
s_lower_status() { printf ':100644 100644 %s %s m\0f.nix\0' "$SHA1" "$SHA2"; }
s_no_path() { printf ':100644 100644 %s %s M\0' "$SHA1" "$SHA2"; }
s_unterminated_path() { printf ':100644 100644 %s %s M\0f.nix' "$SHA1" "$SHA2"; }
s_unterminated_header() { printf ':100644 100644 %s %s M' "$SHA1" "$SHA2"; }
s_rename_one_path() { printf ':100644 100644 %s %s R100\0a.txt\0' "$SHA1" "$SHA2"; }
s_empty_path() { printf ':100644 100644 %s %s M\0\0' "$SHA1" "$SHA2"; }
s_trailing_newline() {
  rec 100644 100644 M a.nix
  printf '\n'
}
s_late_garbage() {
  rec 100644 100644 M a.nix
  printf 'junk\0'
}
check_fail 'garbage header' s_garbage
check_fail 'bad mode in header' s_badmode
check_fail 'missing sha field' s_missing_field
check_fail 'lowercase status' s_lower_status
check_fail 'header without path' s_no_path
check_fail 'unterminated path' s_unterminated_path
check_fail 'unterminated header' s_unterminated_header
check_fail 'rename without second path' s_rename_one_path
check_fail 'empty path' s_empty_path
check_fail 'trailing newline after last record' s_trailing_newline
check_fail 'garbage after a valid record prints nothing' s_late_garbage

# Empty input.
check 'empty input' '' printf ''

# End to end against a real throwaway repository.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
repo=$TMP/repo
g() { git -C "$repo" -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git_diff() { g diff-tree -r -z --raw --full-index "$@"; }

if git init -q "$repo" 2>/dev/null; then
  printf 'hello\n' >"$repo/README.md"
  printf 'task\n' >"$repo/Justfile"
  printf 'moved content\n' >"$repo/doc.txt"
  g add -A && g commit -q -m base

  printf 'hello again\n' >"$repo/README.md"
  g rm -q Justfile
  printf '{ }\n' >"$repo/flake.nix"
  printf '#!/bin/sh\n' >"$repo/run.sh"
  ln -s README.md "$repo/link"
  g add -A && g update-index --chmod=+x run.sh && g commit -q -m second

  g mv doc.txt .envrc && g commit -q -m rename
else
  printf '# git init failed\n'
fi

want="$(L just D Justfile)$nl$(L nix A flake.nix)$nl$(L symlink A link)$nl$(L shell A run.sh)$nl$(L executable A run.sh)"
check 'git diff-tree --no-renames end to end' "$want" git_diff --no-renames HEAD~2 HEAD~1
check 'git diff-tree -M rename into .envrc' "$(L envrc R100 .envrc)" git_diff -M HEAD~1 HEAD

# Summary.
printf '1..%d\n' "$count"
if ((count < MIN_ASSERTIONS)); then
  printf 'not ok - only %d assertions ran, expected at least %d\n' "$count" "$MIN_ASSERTIONS"
  exit 1
fi
if ((bad > 0)); then
  printf '# %d of %d failed\n' "$bad" "$count"
  exit 1
fi
printf '# all %d passed\n' "$count"
