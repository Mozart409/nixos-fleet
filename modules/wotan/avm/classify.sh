#!/usr/bin/env bash
# Risk classifier over `git diff --raw -z` output (stdin).
#
# Records: ":oldmode newmode oldsha newsha status\0path\0", and for status
# R*/C* a second "path\0". Prints one line per finding, in input order:
#   class<TAB>status<TAB>path
# Paths are attacker-controlled: anything outside [A-Za-z0-9._/@+-] is printed
# with printf %q. Malformed input: message on stderr, exit 1, no stdout.
set -euo pipefail
export LC_ALL=C

# Pattern table: class|kind|glob, matched case-insensitively (lowercased).
#   b  glob against the basename
#   c  glob against any single path component
# Add a row here to add a class or a pattern; every row is independent.
PATTERNS=(
  'envrc|b|.envrc'
  'nix|b|*.nix'
  'nix|b|flake.lock'
  'just|b|justfile'
  'just|b|.justfile'
  'just|b|*.just'
  'lefthook|b|lefthook.*'
  'lefthook|b|.lefthook.*'
  'lefthook|b|lefthook-local.*'
  'lefthook|b|.lefthook-local.*'
  'cargo|b|build.rs'
  'cargo|c|.cargo'
  'cargo|b|rust-toolchain.toml'
  'cargo|b|rust-toolchain'
  'package|b|package.json'
  'shell|b|*.sh'
  'agent-config|c|.claude'
  'agent-config|c|.opencode'
  'agent-config|b|autolith.org'
  'git|b|.gitattributes'
  'git|b|.gitmodules'
)

header_re='^:([0-7]{6}) ([0-7]{6}) ([0-9a-f]{4,64}) ([0-9a-f]{4,64}) ([A-Z])([0-9]*)$'

out=''
status=''

die() {
  printf 'classify: %s\n' "$*" >&2
  exit 1
}

# emit <class> <path>: buffer one finding line (stdout only after full parse).
emit() {
  local p=$2
  case $p in
    '' | *[!A-Za-z0-9._/@+-]*) printf -v p '%q' "$p" ;;
  esac
  out+=$1$'\t'"$status"$'\t'"$p"$'\n'
}

# path_classes <path>
path_classes() {
  local p=$1 lp b e cls rest kind glob
  lp=${p,,}
  b=${lp##*/}
  for e in "${PATTERNS[@]}"; do
    cls=${e%%|*}
    rest=${e#*|}
    kind=${rest%%|*}
    glob=${rest#*|}
    case $kind in
      b)
        # shellcheck disable=SC2254
        case $b in
          $glob) emit "$cls" "$p" ;;
        esac
        ;;
      c)
        case "/$lp/" in
          */$glob/*) emit "$cls" "$p" ;;
        esac
        ;;
    esac
  done
}

# mode_classes <oldmode> <newmode> <path>
mode_classes() {
  case $2 in
    120000) emit symlink "$3" ;;
    160000) emit submodule "$3" ;;
  esac
  if [[ $2 == 100755 && $1 != 100755 ]]; then
    emit executable "$3"
  fi
  if [[ $1 != 000000 && $2 != 000000 && $1 != "$2" ]]; then
    emit mode-change "$3"
  fi
}

while :; do
  hdr=''
  if ! IFS= read -r -d '' hdr; then
    if [[ -z $hdr ]]; then
      break
    fi
    die 'truncated record header'
  fi
  [[ $hdr =~ $header_re ]] || die 'bad record header'
  old=${BASH_REMATCH[1]}
  new=${BASH_REMATCH[2]}
  letter=${BASH_REMATCH[5]}
  status=$letter${BASH_REMATCH[6]}

  p1=''
  p2=''
  IFS= read -r -d '' p1 || die 'truncated record: missing path'
  [[ -n $p1 ]] || die 'empty path'
  case $letter in
    R | C)
      IFS= read -r -d '' p2 || die 'truncated record: missing second path'
      [[ -n $p2 ]] || die 'empty second path'
      ;;
  esac

  path_classes "$p1"
  if [[ -n $p2 ]]; then
    path_classes "$p2"
  fi
  mode_classes "$old" "$new" "${p2:-$p1}"
done

printf '%s' "$out"
