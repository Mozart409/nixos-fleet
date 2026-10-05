"""Report which of a flake's direct inputs have meaningfully moved upstream.

Emits JSON on stdout:

    {"ok": true, "graceDays": 3,
     "inputs": [{"name": ..., "behind": true/false/null, "stale": bool,
                 "lockedAge": <days>, "unreachable": bool}, ...]}

"behind" is `locked rev != upstream HEAD`, which is the only honest definition
of drift. Lock *age* alone is not: an input can sit at upstream HEAD for a year
because the project is finished or dormant, and a board that paints that red
is one you stop reading.

But drift alone is not *actionable* either, and that is a different failure of
the same board. `nixos-unstable` lands a new channel commit several times a
day, so nixpkgs is "behind" within hours of every single update -- a permanent
amber that no amount of updating can clear, which is the same "stop reading it"
outcome by the other road.

So drift is the gate and age is the threshold: an input is `stale` -- the thing
worth showing -- only when it has moved upstream AND your lock is older than
graceDays. Drifted-but-fresh inputs are still reported (`behind` stays true),
just demoted, so nothing is ever claimed current that isn't.
"""

import argparse
import json
import os
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor

DEFAULT_GRACE_DAYS = 3.0


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


def parse_args():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("flake", nargs="?", default="/etc/nixos",
                    help="path to the flake whose lock is inspected")
    ap.add_argument(
        "--grace-days", type=float,
        default=float(os.environ.get("FLAKE_DRIFT_GRACE_DAYS", DEFAULT_GRACE_DAYS)),
        help="how old a drifted lock must be before it counts as stale",
    )
    return ap.parse_args()


def main():
    args = parse_args()
    grace = max(args.grace_days, 0.0)

    try:
        with open(f"{args.flake}/flake.lock") as fh:
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

        result = {"name": name, "behind": None, "stale": False,
                  "lockedAge": age, "unreachable": False}

        if not url or not rev:
            return result

        head = head_of(url, locked.get("ref"))
        if head is None:
            # Offline or a private remote: report unknown rather than guessing.
            # Claiming "up to date" when we could not check is the one answer
            # that would make this widget actively misleading.
            result["unreachable"] = True
            return result

        result["behind"] = head != rev
        # An age we could not compute is treated as stale-on-drift: falling
        # silent about a drifted input is worse than one extra amber row.
        result["stale"] = result["behind"] and (age is None or age >= grace)
        return result

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(check, sorted(direct.items())))

    results.sort(key=lambda r: (not r["stale"], r["behind"] is not True, r["name"]))
    print(json.dumps({"ok": True, "graceDays": grace, "inputs": results}))


main()
