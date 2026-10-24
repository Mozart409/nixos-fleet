#!/usr/bin/env bash
# Print one export's "prefix<TAB>remote<TAB>tag_prefix" from exports.toml, or
# exit 1 if there is no export by that name. tag_prefix defaults to "v".
# Shared by release-bump.sh and release-github.sh.
#
# Usage: export-lookup.sh <name>
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

awk -v want="${1:?usage: export-lookup.sh <name>}" '
  function flush() { if (seen && name == want) { print prefix "\t" remote "\t" tp; found = 1 } }
  /^\[\[export\]\][[:space:]]*$/ { flush(); seen = 1; name = prefix = remote = ""; tp = "v"; next }
  match($0, /^[[:space:]]*[a-z_]+[[:space:]]*=[[:space:]]*"[^"]*"/) {
    key = $0; sub(/[[:space:]]*=.*/, "", key); gsub(/[[:space:]]/, "", key)
    val = $0; sub(/^[^"]*"/, "", val); sub(/".*$/, "", val)
    if (key == "name") name = val; else if (key == "prefix") prefix = val
    else if (key == "remote") remote = val; else if (key == "tag_prefix") tp = val
  }
  END { flush(); exit !found }
' exports.toml
