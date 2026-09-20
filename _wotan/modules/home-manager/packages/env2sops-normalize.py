#!/usr/bin/env python3
"""Normalize a dotenv file to the strict KEY=value form sops' dotenv store uses.

sops stores dotenv lines literally: quotes stay in the value, `export ` becomes
part of the key, inline comments become part of the value, and multi-line
values are rejected. `just`'s dotenv-load (dotenvy) is lenient about all of
that, so a .env that worked with dotenv-load must be rewritten before it is
encrypted or the values exported by `sops exec-env` silently differ.

Usage: env2sops-normalize.py SRC OUT
Writes the normalized file to OUT and prints a summary of changes to stderr
(key names only -- values are never printed). Exits 2 on unsupported input.
"""

import re
import sys

KV = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$")


def unquote(raw):
    """Return (value, note) for a raw right-hand side."""
    v = raw.rstrip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        inner = v[1:-1]
        if v[0] == '"':
            # dotenvy interprets escapes inside double quotes
            inner = (
                inner.replace('\\"', '"')
                .replace("\\n", "\n")
                .replace("\\t", "\t")
                .replace("\\\\", "\\")
            )
        return inner, "quotes stripped"
    # unquoted: ` #` starts a comment
    m = re.search(r"\s#", v)
    if m:
        return v[: m.start()].rstrip(), "inline comment removed"
    return v, None


def main(src, out):
    lines = open(src, encoding="utf-8").read().split("\n")
    result, notes, keys = [], [], set()
    for n, line in enumerate(lines, 1):
        line = line.rstrip("\r")
        if not line.strip():
            continue  # sops drops blank lines anyway
        if line.lstrip().startswith("#"):
            result.append(line)
            continue
        m = KV.match(line)
        if not m:
            print(f"env2sops: line {n}: not KEY=value, unsupported by sops", file=sys.stderr)
            return 2
        key, raw = m.group(1), m.group(2)
        value, note = unquote(raw)
        if "\n" in value:
            print(f"env2sops: {key}: multi-line value, unsupported by sops dotenv", file=sys.stderr)
            return 2
        if key in keys:
            notes.append(f"{key}: duplicate key, last one wins")
        keys.add(key)
        if note:
            notes.append(f"{key}: {note}")
        if line.lstrip().startswith("export "):
            notes.append(f"{key}: 'export' prefix removed")
        if "${" in value or re.search(r"\$[A-Za-z_]", value):
            notes.append(f"{key}: contains $VAR -- dotenv-load expanded this, sops will NOT")
        result.append(f"{key}={value}")

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(result) + "\n")

    if notes:
        print("env2sops: normalized for sops (values not shown):", file=sys.stderr)
        for note in notes:
            print(f"  - {note}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
