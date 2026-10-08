# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""The DOS clock of a recorded level session: US_InitRndT(true) takes the clock's seconds (time(0) & 0xFF)
when the level starts. The runner sets the clock to 00:00:00 before the game (tools/oracle_run.py), so
time(0) is the recording's day in Borland's zone plus the seconds since (galaxy_case.recording_clock). This
runs the port's opening with the clock moved by each candidate number of seconds (0-255 covers every seed)
and reports how far its pictures follow the recording (the first differing picture, later is better).

    python tools/galaxy_seed_scan.py keen4 level06 [--deltas 0-255 | --deltas -1,0,1] [--seconds 2.2]
"""
import argparse
import concurrent.futures
import sys
from pathlib import Path

import common
import galaxy_case
import timing_score

WORK = Path("F:/KeenReworkWork/port_runs")


def first_difference(game, case, delta, seconds, costs, phase):
    out = WORK / f"gseed_{game}_{case}_{delta}"
    extra = [f"--costs={costs}"] if costs else []
    galaxy_case.run_port(game, case, [], out, seconds=seconds, extra=extra, clock=galaxy_case.recording_clock(game, case) + delta, timer_offset=phase)
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    try:
        k, note, port, orc, start = timing_score.score(out, oracle, transient=True)
    except Exception:
        return -1
    t, n = 0, 0
    while n < len(orc) and t < seconds * 70.086 - 30:
        t += orc[n][1]
        n += 1
    for i in range(n):
        if i >= len(port) or port[i][0] != orc[i][0]:
            return i
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--deltas", default="0-255")
    ap.add_argument("--seconds", type=float, default=2.2)
    ap.add_argument("--costs", default="")
    ap.add_argument("--phase", type=int, default=None)
    ap.add_argument("--workers", type=int, default=8)
    a = ap.parse_args()
    if "," not in a.deltas and "-" in a.deltas[1:]:
        lo, hi = map(int, a.deltas.rsplit("-", 1))
        seeds = list(range(lo, hi + 1))
    else:
        seeds = [int(s) for s in a.deltas.split(",")]
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    res = dict(zip(seeds, pool.map(lambda s: first_difference(a.game, a.case, s, a.seconds, a.costs, a.phase), seeds)))
    best = max(res.values())
    print(f"{a.game} {a.case}: best first difference at picture {best}, clock moved by " +
          ",".join(str(s) for s in seeds if res[s] == best))
    print("  " + " ".join(f"{s}:{v}" for s, v in res.items()))


if __name__ == "__main__":
    sys.exit(main())
