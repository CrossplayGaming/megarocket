# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""MM-01's measure: the original's memory manager, modelled in the port, against the original's own
picture of its memory (the debug key F10-M under DOSBox: one pixel a paragraph, red locked, blue in
use, purple purgeable, black free, a white pixel at each block's start).

A mem case (tools/cases/<game>/memNN.json) turns the debug keys on and shows the picture once or
twice in a session; the recording <game>_<case>_a holds them. This runs the port with the case's keys
(late by the runner's usual delay) and holds every memory picture the port shows against the
recording's, block by block: each block's start, length and kind must agree.

    python tools/mm_oracle.py keen4 mem08 [--delay 0.45]
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

import common
import frames
import galaxy_case

WORK = Path("F:/KeenReworkWork/port_runs")


def blocks(img):
    """The block list drawn in a memory picture: (start paragraph, length, kind L/N/P)."""
    r, g, b = [img[:, :, c].astype(int) for c in range(3)]
    cls = np.full(img.shape[:2], "k", dtype="<U1")
    cls[(r > 200) & (g < 120) & (b < 120)] = "L"
    cls[(b > 200) & (r < 120) & (g < 120)] = "N"
    cls[(r > 120) & (b > 120) & (g < 80) & (r < 200)] = "P"
    cls[(r > 200) & (g > 200) & (b > 200)] = "W"
    flat = cls.reshape(-1)
    out = []
    i = 0
    n = len(flat)
    while i < n:
        if flat[i] == "W":
            j = i + 1
            kind = flat[j] if j < n else "k"
            while j < n and flat[j] == kind and flat[j] != "W":
                j += 1
            out.append((i, j - i, kind))
            i = j
        else:
            i += 1
    return out


def memory_pictures(folder):
    """The distinct memory pictures of a frame store, in order: (block list, held refreshes)."""
    seq = frames.Sequence(folder)
    out = []
    last = None
    run = False
    for i in range(len(seq)):
        d = seq.digest(i)
        if d == last:
            continue
        last = d
        img = np.asarray(seq.frame(i))
        red = ((img[:, :, 0] > 200) & (img[:, :, 1] < 120) & (img[:, :, 2] < 120)).sum()
        if red > 20000:
            # of a run of memory pictures (the first may be mixed with the game's rows, the beam
            # having passed them before the picture was drawn), the one held longest
            if run and seq.repeats(i) <= out[-1][1]:
                continue
            if run:
                out.pop()
            out.append((blocks(img), seq.repeats(i)))
            run = True
        else:
            run = False
    return out


def compare(port, orc):
    """The first block that differs, or None."""
    for n, (a, b) in enumerate(zip(port, orc)):
        if a != b:
            return n, a, b
    if len(port) != len(orc):
        return min(len(port), len(orc)), port[len(orc):len(orc) + 1], orc[len(port):len(port) + 1]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--delay", type=float, default=0.45, help="seconds the recording's keys landed late")
    a = ap.parse_args()
    spec = json.loads((Path(__file__).parent / "cases" / a.game / f"{a.case}.json").read_text(encoding="utf-8"))
    keys = [[round(t + a.delay, 4), k, h] for t, k, h in spec["held"]]
    out = WORK / f"mmo_{a.game}_{a.case}"
    galaxy_case.run_port(a.game, a.case, keys, out)
    oracle = Path(common.config()["oracle_runs"]) / f"{a.game}_{a.case}_a" / "frames"
    po = memory_pictures(out)
    oo = memory_pictures(oracle)
    print(f"{a.game} {a.case}: {len(po)} memory pictures in the port, {len(oo)} in the recording")
    ok = True
    for i, ob in enumerate(oo):
        if i >= len(po):
            print(f"  picture {i}: missing in the port")
            ok = False
            continue
        d = compare(po[i][0], ob[0])
        if d is None:
            print(f"  picture {i}: all {len(ob[0])} blocks agree")
        else:
            n, pa, pb = d
            print(f"  picture {i}: block {n} of {len(ob[0])} differs: port {pa if isinstance(pa, list) else (hex(pa[0]), hex(pa[1]), pa[2])}"
                  f" recording {pb if isinstance(pb, list) else (hex(pb[0]), hex(pb[1]), pb[2])}")
            ok = False
    print("PASS" if ok and po else "FAIL")
    return 0 if ok and po else 1


if __name__ == "__main__":
    sys.exit(main())
