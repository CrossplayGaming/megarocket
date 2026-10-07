# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Produce Keen 6 v1.4 from the user's v1.0 files with the official 6KEEN14 patch.

The patch program is a DOS executable, so it runs in DOSBox on a scratch copy
of game_data/keen6; whatever it writes is copied back as the v1.4 set. Nothing
is downloaded and nothing but the user's own files and the patch are used.

Usage: python tools/keen6_patch.py
"""

import hashlib
import shutil
import subprocess
import sys
import time
from pathlib import Path

import common

CONF = """[sdl]
fullscreen = false
windowresolution = 640x400
[dosbox]
machine = vga
[cpu]
core = normal
cycles = 20000
[mixer]
nosound = true
[midi]
mididevice = none
[autoexec]
mount c "{game}"
c:
6KEEN14.EXE > PATCH.LOG
exit
"""


def main():
    cfg = common.config()
    src = cfg["game_data"] / "keen6"
    if not (src / "6KEEN14.EXE").exists():
        print("COULD-NOT-RUN: game_data/keen6/6KEEN14.EXE (the official patch) is missing")
        return common.COULD_NOT_RUN
    work = cfg["oracle_runs"].parent / "keen6_patch"
    if work.exists():
        shutil.rmtree(work)
    game = work / "game"
    game.mkdir(parents=True)
    before = {}
    for f in src.iterdir():
        if f.is_file():
            shutil.copy2(f, game / f.name.upper())
            before[f.name.upper()] = hashlib.sha256(f.read_bytes()).hexdigest()
    conf = work / "patch.conf"
    conf.write_text(CONF.format(game=str(game)), encoding="ascii")
    proc = subprocess.Popen([str(cfg["dosbox"]), "-noprimaryconf", "-nolocalconf", "-conf", str(conf), "-noconsole"],
                            cwd=str(work), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        proc.wait(timeout=120)
    except subprocess.TimeoutExpired:
        proc.kill()
        print("FAIL: the patch program did not finish in 120 s (it may be waiting for a key)")
        return common.FAIL
    log = game / "PATCH.LOG"
    if log.exists():
        print(log.read_text(encoding="ascii", errors="replace").strip())
    changed = []
    for f in game.iterdir():
        if not f.is_file() or f.name in ("PATCH.LOG",):
            continue
        digest = hashlib.sha256(f.read_bytes()).hexdigest()
        if before.get(f.name) != digest:
            changed.append((f.name, f.stat().st_size, digest[:16]))
    if not changed:
        print("FAIL: the patch changed no file")
        return common.FAIL
    for name, size, digest in changed:
        print(f"  {name:14s} {size:8d} bytes  sha256 {digest}")
        shutil.copy2(game / name, src / name)
    print(f"copied {len(changed)} patched file(s) into {src}")
    return common.PASS


if __name__ == "__main__":
    sys.exit(main())
