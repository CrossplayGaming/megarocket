# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""TIME-G's loading costs against the level sessions: each recorded session's first seconds are the level
being loaded under its name box, then the box fading and the level appearing, before any key. For each
recorded session of a game this runs the port for a few seconds (no keys) with the given costs and
reports how far its pictures and their durations follow the recording, and the first durations side by side.

    python tools/galaxy_load_fit.py keen4 [--costs name=units,...] [--seconds 2.2] [--workers 9]
"""
import argparse
import concurrent.futures
import sys
from pathlib import Path

import common
import galaxy_case
import timing_score

WORK = Path("F:/KeenReworkWork/port_runs")


def one(game, case, costs, seconds, tag):
    out = WORK / f"gload_{game}_{case}_{tag}"
    extra = [f"--costs={costs}"] if costs else []
    galaxy_case.run_port(game, case, [], out, seconds=seconds, extra=extra)
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    try:
        k, note, port, orc, start = timing_score.score(out, oracle, transient=True)
    except Exception as err:
        return case, -1, str(err)[-60:], [], []
    # the pictures up to the first key's moment (2 s): the load, the box, the fade
    t, n = 0, 0
    while n < len(orc) and t < seconds * 70.086 - 30:
        t += orc[n][1]
        n += 1
    return case, k, note, [d for _, d in port[:min(n, 12)]], [d for _, d in orc[:min(n, 12)]], n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("--costs", default="")
    ap.add_argument("--seconds", type=float, default=2.2)
    ap.add_argument("--workers", type=int, default=9)
    ap.add_argument("--tag", default="x")
    a = ap.parse_args()
    root = Path(common.config()["oracle_runs"])
    cases = sorted(p.name[len(a.game) + 1:-2] for p in root.glob(f"{a.game}_level??_a") if (p / "frames" / "frames.json").exists())
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    futs = [pool.submit(one, a.game, c, a.costs, a.seconds, a.tag) for c in cases]
    whole = 0
    for f in futs:
        r = f.result()
        case, k = r[0], r[1]
        if k < 0:
            print(f"{case}: no run ({r[2]})")
            continue
        port, orc, n = r[3], r[4], r[5]
        ok = k >= n
        whole += ok
        print(f"{case}: {'OK ' if ok else 'off'} {k:3d} of {n:3d}  port {port}\n{'':22s}rec  {orc}")
    print(f"{whole} of {len(cases)} loads match through the first {a.seconds} s")


if __name__ == "__main__":
    sys.exit(main())
