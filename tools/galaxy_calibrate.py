# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""TIME-G's loading costs fitted to every recorded level session of a game at once (coordinate descent).

Each session opens with the level's loading under its name box, the box fading, the play loop's first
frames drawn in the black and the fade in (tools/galaxy_load_fit.py). The objective is the number of
those opening pictures matched, refresh for refresh, summed over the sessions; one cost at a time is
moved over a ladder of factors and the best kept, until no move helps. The result is printed as the
costs string for the episode's timing_defaults (and checked against the boot recording by TIME-G4).

    python tools/galaxy_calibrate.py keen4 [--costs grbyte=3500,...] [--params grbyte,grexp,...]
"""
import argparse
import concurrent.futures
import sys
import time
from pathlib import Path

import common
import galaxy_case
import timing_score

WORK = Path("F:/KeenReworkWork/port_runs")
FACTORS = (0.5, 0.7, 0.85, 1.15, 1.4, 2.0)
SECONDS = 2.2


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


PHASES = list(range(0, 17040000, 17040000 // 12))    # the 70 Hz clock's phase, in twelfths


def one(game, case, costs, tag, phase=0):
    out = WORK / f"gcal_{game}_{case}_{tag}_{phase}"
    galaxy_case.run_port(game, case, [], out, seconds=SECONDS, extra=[f"--costs={costs}"], timer_offset=phase)
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    try:
        k, note, port, orc, start = timing_score.score(out, oracle, transient=True)
    except Exception:
        return -1000, 1
    t, n = 0, 0
    while n < len(orc) and t < SECONDS * 70.086 - 30:
        t += orc[n][1]
        n += 1
    # the score: minus the refreshes by which the opening's pictures are held wrong (a picture that
    # differs costs 10), so a better black counts even where an earlier picture is still off
    err = 0
    for i in range(n):
        if i >= len(port) or port[i][0] != orc[i][0]:
            err += 10 * (n - i)
            break
        if i < n - 1:
            err += abs(port[i][1] - orc[i][1])
    return -err, (1 if err == 0 else 0)


def objective(pool, game, cases, costs, tag, phases):
    spec = ",".join(f"{k}={int(v)}" for k, v in costs.items())
    res = list(pool.map(lambda c: one(game, c, spec, tag, phases.get(c, 0)), cases))
    return sum(r[0] for r in res), len(res), sum(r[1] for r in res)


def fit_phases(pool, game, cases, costs):
    """Each session's best phase with the costs as they are (the recording's clock: where DOSBox's
    start-up key fell)."""
    spec = ",".join(f"{k}={int(v)}" for k, v in costs.items())
    jobs = {(c, ph): pool.submit(one, game, c, spec, "ph", ph) for c in cases for ph in PHASES}
    best = {}
    for c in cases:
        scored = [(jobs[(c, ph)].result()[0], -ph, ph) for ph in PHASES]
        best[c] = max(scored)[2]
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("--costs", default="grbyte=4025,grexp=700,sprchunk=155000,levelload=20000000,tile16=68000,tile16m=120000,blockcopy=1,mapword=1,grchunk=1,sprpixel=1")
    ap.add_argument("--params", default="")
    ap.add_argument("--workers", type=int, default=10)
    ap.add_argument("--sweeps", type=int, default=4)
    a = ap.parse_args()
    costs = {kv.split("=")[0]: float(kv.split("=")[1]) for kv in a.costs.split(",")}
    params = a.params.split(",") if a.params else list(costs)
    root = Path(common.config()["oracle_runs"])
    cases = sorted(p.name[len(a.game) + 1:-2] for p in root.glob(f"{a.game}_level??_a") if (p / "frames" / "frames.json").exists())
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    phases = {}
    best, total, whole = objective(pool, a.game, cases, costs, "base", phases)
    say(f"{len(cases)} sessions; start: error {-best}, {whole} openings whole")
    for sweep in range(a.sweeps):
        phases = fit_phases(pool, a.game, cases, costs)
        best, total, whole = objective(pool, a.game, cases, costs, "base", phases)
        say(f"sweep {sweep + 1}: phases fitted: error {-best}, {whole} whole")
        improved = False
        for p in params:
            trials = []
            for f in FACTORS:
                c = dict(costs)
                # a cost at its floor (1, i.e. off) is tried at a ladder of real values
                c[p] = round(costs[p] * f) if costs[p] > 1 else int({0.5: 2000, 0.7: 8000, 0.85: 30000, 1.15: 100000, 1.4: 300000, 2.0: 1000000}[f])
                trials.append((f, c))
            scored = [(objective(pool, a.game, cases, c, f"{p}{f}", phases), f, c) for f, c in trials]
            (s, tot, wh), f, c = max(scored, key=lambda r: r[0][0])
            if s > best:
                best, whole, costs, improved = s, wh, c, True
                say(f"  {p} x{f} -> {int(c[p])}: error {-best}, {whole} whole")
            else:
                say(f"  {p}: no factor helps (best error {-s})")
        if not improved:
            break
    say("costs: " + ",".join(f"{k}={int(v)}" for k, v in costs.items()) + f"  (error {-best}, {whole} whole)")
    say("phases: " + ",".join(f"{c}={ph}" for c, ph in sorted(phases.items())))


if __name__ == "__main__":
    sys.exit(main())
