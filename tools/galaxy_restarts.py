# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""The first restart of each recorded Keen 4-6 level session, the port against the recording (TIME-G).

When Keen dies the original loads the level again while the last picture stays up, draws the level's
box if anything is left to load, fades out, and in the black waits for the death sound, starts the
song and draws the first frames. This finds the first all-black picture after a session's opening in
both (the restart's black) and prints the pictures' durations leading into it and out of it, with the
map's size: the loading costs are fitted on these as well as on the openings.

    python tools/galaxy_restarts.py keen4 [--costs name=units,...] [--levels 02,05]
"""
import argparse
import concurrent.futures
import sys
from pathlib import Path

import numpy as np

import common
import frames
import galaxy_case
import timing_score

WORK = Path("F:/KeenReworkWork/port_runs")


def black_after(seq, lst, start):
    seen = {}
    for i in range(len(seq)):
        seen.setdefault(seq.digest(i), i)
    for n in range(start, len(lst)):
        if not np.asarray(seq.frame(seen[lst[n][0]])).any():
            return n
    return None


def first_picture_time(game, case, costs, tag):
    """Seconds from the program's start to the port's picture that the recording starts with."""
    out = WORK / f"grest_{game}_{case}_{tag}_open"
    extra = [f"--costs={costs}"] if costs else []
    galaxy_case.run_port(game, case, [], out, seconds=1.5, extra=extra)
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    _k, _n, _port, _orc, start = timing_score.score(out, oracle, transient=True)
    full = timing_score.pictures(frames.Sequence(out), False)
    return sum(r for _, r in full[:start]) / 70.086


def one(game, case, costs, rebase=None):
    out = WORK / f"grest_{game}_{case}"
    extra = [f"--costs={costs}"] if costs else []
    keys = galaxy_case.case_keys(game, case, "port")
    clock = None
    if rebase is not None:
        # the session's keys were fitted with other costs: move them, and the DOS clock the other
        # way, by how far the new costs move the recording's first picture in the port
        shift = first_picture_time(game, case, costs, "new") - first_picture_time(game, case, rebase, "old")
        keys = [[round(t + shift, 4), k, h] for t, k, h in keys]
        clock = galaxy_case.case_clock(game, case) - int(round(shift * 1e6))
    galaxy_case.run_port(game, case, keys, out, extra=extra, clock=clock)
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    _k, _n, port, orc, _s = timing_score.score(out, oracle, transient=True)
    o0 = galaxy_case.opening_end(oracle) + 8
    bo = black_after(frames.Sequence(oracle / "frames"), orc, o0)
    bp = black_after(frames.Sequence(out), port, o0)
    if bo is None or bp is None:
        return case, None
    return case, ([d for _, d in port[bp - 5:bp + 3]], [d for _, d in orc[bo - 5:bo + 3]])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("--costs", default="")
    ap.add_argument("--levels", default="")
    ap.add_argument("--rebase", default=None, help="the costs the sessions' keys were fitted with")
    a = ap.parse_args()
    root = Path(common.config()["oracle_runs"])
    cases = [f"level{x}" for x in a.levels.split(",")] if a.levels else \
        sorted(p.name[len(a.game) + 1:-2] for p in root.glob(f"{a.game}_level??_a") if (p / "frames" / "frames.json").exists())
    pool = concurrent.futures.ThreadPoolExecutor(8)
    for case, r in pool.map(lambda c: one(a.game, c, a.costs, a.rebase), cases):
        if r is None:
            print(f"{case}: no restart in both")
            continue
        p, o = r
        print(f"{case}: port {p}\n{'':9s}rec  {o}   diff {[x - y for x, y in zip(p, o)]}")


if __name__ == "__main__":
    sys.exit(main())
