"""Report which of a flake's direct inputs have moved upstream.

Emits JSON on stdout:

    {"ok": true, "inputs": [{"name": ..., "behind": true/false/null,
                             "lockedAge": <days>, "unreachable": bool}, ...]}

"behind" is `locked rev != upstream HEAD`, which is the only honest definition
of drift. Lock *age* is not: an input can sit at upstream HEAD for a year
because the project is finished or dormant, and a board that paints that red
is one you stop reading.
"""

import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

FLAKE = sys.argv[1] if len(sys.argv) > 1 else "/etc/nixos"


def remote_url(locked):
    kind = locked.get("type")
    if kind == "github":
        return f"https://github.com/{locked['owner']}/{locked['repo']}"
    if kind == "gitlab":
        return f"https://gitlab.com/{locked['owner']}/{locked['repo']}"
    if kind == "git":
        return locked.get("url", "")
    # tarball/path/indirect inputs have no ref to compare against
    return ""


def head_of(url, ref):
    # `ls-remote <url> HEAD` follows the remote's default branch, which is what
    # an unpinned input tracks. An input with an explicit ref must be asked
    # about that ref instead, or every branch input reads as permanently behind.
    target = ref if ref else "HEAD"
    try:
        out = subprocess.run(
            ["git", "ls-remote", url, target],
            capture_output=True, text=True, timeout=20,
        )
    except subprocess.TimeoutExpired:
        return None
    if out.returncode != 0 or not out.stdout.strip():
        return None
    return out.stdout.split()[0]


def main():
    try:
        with open(f"{FLAKE}/flake.lock") as fh:
            lock = json.load(fh)
    except (OSError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return

    nodes = lock["nodes"]
    # Only the root's own inputs. Transitive nodes (`systems`, `flake-utils`)
    # are pinned by other flakes, are years old by design, and are not
    # something this machine can act on.
    direct = nodes["root"]["inputs"]
    now = time.time()

    def check(item):
        name, ref = item
        node = nodes[ref if isinstance(ref, str) else ref[0]]
        locked = node.get("locked", {})
        rev = locked.get("rev", "")
        url = remote_url(locked)
        age = None
        if locked.get("lastModified"):
            age = round((now - locked["lastModified"]) / 86400, 1)

        if not url or not rev:
            return {"name": name, "behind": None, "lockedAge": age, "unreachable": False}

        head = head_of(url, locked.get("ref"))
        if head is None:
            # Offline or a private remote: report unknown rather than guessing.
            # Claiming "up to date" when we could not check is the one answer
            # that would make this widget actively misleading.
            return {"name": name, "behind": None, "lockedAge": age, "unreachable": True}
        return {"name": name, "behind": head != rev, "lockedAge": age, "unreachable": False}

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(check, sorted(direct.items())))

    results.sort(key=lambda r: (r["behind"] is not True, r["name"]))
    print(json.dumps({"ok": True, "inputs": results}))


main()
