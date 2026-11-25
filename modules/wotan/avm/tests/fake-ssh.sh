#!/usr/bin/env bash
# Stand-in for ssh in the avm tests: runs the remote command locally with
# /srv/work mapped to $AVM_FAKE_ROOT/<host>/srv/work.
# Env: AVM_FAKE_ROOT, AVM_FAKE_LOG (append argv), AVM_FAKE_HOSTILE (program run
# instead of git-upload-pack), AVM_FAKE_DOWN (exit 255 like an unreachable host).
set -u

if [[ -n ${AVM_FAKE_LOG:-} ]]; then
  { printf '%q ' "$@"; printf '\n'; } >>"$AVM_FAKE_LOG"
fi
if [[ -n ${AVM_FAKE_DOWN:-} ]]; then
  exit 255
fi

while (($#)); do
  case $1 in
    -[bcDEeFIiJLlmOopQRSWw]) shift 2 ;; # option with a separate argument (-o among them)
    -*) shift ;;
    *) break ;;
  esac
done
host=${1:?fake-ssh: no host}
shift
cmd=$*

case $cmd in
  *git-upload-pack* | *"git upload-pack"*)
    if [[ -n ${AVM_FAKE_HOSTILE:-} ]]; then
      exec "$AVM_FAKE_HOSTILE" "$host" "$cmd"
    fi
    ;;
esac

home=${AVM_FAKE_ROOT:?fake-ssh: AVM_FAKE_ROOT unset}/$host
mkdir -p "$home/srv/work"
cmd=${cmd//\/srv\/work/$home/srv/work}
cd "$home" || exit 255
# clean guest-side git: no host GIT_* leaks, no global config
exec env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  -u GIT_ALTERNATE_OBJECT_DIRECTORIES -u GIT_NAMESPACE -u GIT_COMMON_DIR \
  -u GIT_PREFIX -u GIT_QUARANTINE_PATH -u GIT_CEILING_DIRECTORIES \
  -u GIT_CONFIG_PARAMETERS -u GIT_CONFIG_COUNT "GIT_CONFIG_GLOBAL=/dev/null" \
  bash -c "$cmd"
