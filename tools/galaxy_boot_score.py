# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""TIME-G4's measure: how far the Galaxy port's boot matches a boot recording.

Runs godot/tests/simg_boot.gd for the case's length, then holds the port's pictures (with their
durations in refreshes) against the recording's:
- `exact`: the pictures from the start that match picture for picture and refresh for refresh
  (timing_score's first difference, one-refresh slips that recover allowed);
- after a picture the recording and the port both show (`--from`, the first picture after the
  title fizzle by default), the pictures that match in order, resynchronising past extra pictures,
  with every duration that differs listed.

    python tools/galaxy_boot_score.py keen4 keen4_boot_a
"""
import argparse
import sys
from pathlib import Path

import common
import gdtest
import timing_score

WORK = Path("F:/KeenReworkWork/port_runs")


def align(port, orc, k):
    """Match orc[k:] against port in order; returns (matched, events)."""
    where = {}
    for i, (d, _n) in enumerate(port):
        where.setdefault(d, []).append(i)

    def nxt(d, j):
        for i in where.get(d, []):
            if i >= j:
                return i
        return None

    j = nxt(orc[k][0], 0)
    matched, events = 0, []
    while k < len(orc) - 1 and j is not None and j < len(port):
        if port[j][0] == orc[k][0]:
            matched += 1
            if port[j][1] != orc[k][1]:
                events.append(("duration", k, orc[k][1], port[j][1]))
            k += 1
            j += 1
        else:
            kk = k
            while kk < len(orc) and nxt(orc[kk][0], j) is None:
                kk += 1
            if kk >= len(orc):
                events.append(("lost", k))
                break
            nj = nxt(orc[kk][0], j)
            events.append(("skip", k, kk - k, nj - j))
            k, j = kk, nj
    return matched, events


def run(game, case, seconds, frm, costs="", tag=""):
    out = WORK / f"bootscore_{game}_{case}{('_' + tag) if tag else ''}"
    extra = [f"--game={game}", f"--seconds={seconds}", f"--out={out.as_posix()}"]
    if costs:
        extra.append(f"--costs={costs}")
    code, text = gdtest.run("simg_boot", extra, timeout=1800.0, quiet=True)
    if code != 0:
        return None
    k, note, port, orc, start = timing_score.score(out, Path(common.config()["oracle_runs"]) / case, transient=True)
    port = [tuple(x) for x in port]
    orc = [tuple(x) for x in orc]
    matched, events = align(port, orc, frm)
    return {"exact": k, "note": note, "matched": matched, "events": events, "pictures": len(orc)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--seconds", type=float, default=75)
    ap.add_argument("--from", dest="frm", type=int, default=1317)
    ap.add_argument("--costs", default="")
    ap.add_argument("--tag", default="", help="a name for this run's output folder (parallel runs)")
    a = ap.parse_args()
    r = run(a.game, a.case, a.seconds, a.frm, a.costs, a.tag)
    if r is None:
        print("COULD-NOT-RUN")
        return 2
    print(f"exact to picture {r['exact']} ({r['note']}); from {a.frm}: {r['matched']} matched of {r['pictures'] - a.frm}")
    for e in r["events"]:
        print("  ", e)
    return 0


if __name__ == "__main__":
    sys.exit(main())
