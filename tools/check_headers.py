# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""DIST-02: every source file carries the GPL notice, and every script ported from a reference names it.

Checks every tracked .gd / .py / .c / .h / .ps1 / .sh file of the project (the reference copies kept for
reading, keen13/ omnispeak/ omnispeak-ref/ refkeen/ keendreams/ keen6/ keen6patch/, are not the project's
and are skipped):
- the first fifteen lines carry the GPL notice ("GPL v2 or later" or "GNU General Public License");
- a game script (godot/games/**) names the reference it follows within its first 20 lines.

    python tools/check_headers.py        # lists the files that fail; exit 1 if any
"""
import subprocess
import sys

import common

SKIP_DIRS = ("keen13/", "omnispeak/", "omnispeak-ref/", "refkeen/", "keendreams/", "keen6/", "keen6patch/")
EXTS = (".gd", ".py", ".c", ".h", ".ps1", ".sh")
GPL = ("GPL v2 or later", "GNU General Public License", "GPL-2.0")
REFERENCES = ("omnispeak", "Reconstructed Commander Keen", "K1n9_Duk3", "ReflectionHLE", "Keen Dreams",
              "id Software", "ModdingWiki", "keenwiki")


def main():
    files = subprocess.run(["git", "ls-files"], cwd=common.ROOT, capture_output=True, text=True).stdout.splitlines()
    bad = []
    n = 0
    for f in files:
        if not f.endswith(EXTS) or f.startswith(SKIP_DIRS):
            continue
        n += 1
        lines = (common.ROOT / f).read_text(encoding="utf-8", errors="replace").splitlines()
        # comment markers stripped and lines joined, so a notice wrapped across lines still reads
        head = " ".join(line.strip(" */#") for line in lines[:15])
        if not any(g in head for g in GPL):
            bad.append(f"{f}: no GPL notice in the first fifteen lines")
        if f.startswith("godot/games/"):
            head20 = "\n".join(lines[:20])
            if not any(r.lower() in head20.lower() for r in REFERENCES):
                bad.append(f"{f}: names no reference in its first 20 lines")
    for b in bad:
        print(b)
    print(f"{n} files checked, {len(bad)} problems")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
