# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Fits a Galaxy session's keys to the moments the original's keyboard saw them (REPLAY-G4/5/6).

DOSBox receives the runner's posted keys a little late, by a different amount each time (seen
0.13-0.5 s). The recording is a fact all the same, so, as tools/fit_keys.py does for Keen 1-3,
this moves keys until the port's pictures and their durations follow the recording further:

  at each first mismatch, the key events (presses and releases) in the second before it are
  tried, newest first, moved one refresh at a time up to SPAN refreshes in the direction the
  pictures point to (the port showing the recording's picture later means a key came too
  late, and the other way round; both ways when neither), all of one event's moves at once
  in parallel, each run only a little past the mismatch; the best move that takes the match
  further is kept. When no single event helps, the newest one is moved with every key after
  it (the "tail"). It stops when the whole recording matches or nothing helps.

The fitted keys go to tools/cases/<game>/<case>.port.json (tools/galaxy_case.py uses them).

    python tools/fit_galaxy.py keen4 level05 [--delay 0.47] [--start case|port] [--workers 10]
"""
import argparse
import concurrent.futures
import json
import sys
import time
from pathlib import Path

import common
import frames
import galaxy_case
import timing_score

REFRESH = 1 / 70.086
SPAN = 10                  # refreshes each way an event is tried
WINDOW = 1.0               # seconds before a mismatch whose events are tried
WORK = Path("F:/KeenReworkWork/port_runs")
PERIOD = 17040000          # one tick of the game's 70 Hz clock, in machine units


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


OFFSET = [0]    # the timer phase in use (machine units)


def trial(game, case, keys, tag, seconds=None, offset=None):
    out = WORK / f"fitg_{game}_{case}_{tag}"
    galaxy_case.run_port(game, case, keys, out, seconds=seconds, timer_offset=OFFSET[0] if offset is None else offset)
    try:
        k, note, n = galaxy_case.score(game, case, out)
    except Exception as err:          # a run that wrote nothing scores nothing
        return -1, str(err)[-80:], 0, out
    return k, note, n, out


def mismatch(game, case, out, k):
    """(port seconds at the mismatch, direction): +1 the port is early (keys later), -1 late, 0 unknown."""
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    _, _, port, orc, start = timing_score.score(Path(out), oracle, transient=True)
    full = timing_score.pictures(frames.Sequence(Path(out)), False)
    t = sum(n for _, n in full[:start + k]) * REFRESH
    if k < len(port) and k < len(orc) and port[k][0] == orc[k][0]:
        # the same picture, held a different time: what ends it is near the earlier end; either way
        return t + min(port[k][1], orc[k][1]) * REFRESH, 0, orc[k][1] - port[k][1]
    ahead = any(k + j < len(orc) and orc[k + j][0] == port[k][0] for j in range(1, 6)) if k < len(port) else False
    behind = any(k + j < len(port) and port[k + j][0] == orc[k][0] for j in range(1, 6)) if k < len(orc) else False
    return t, (1 if ahead and not behind else -1 if behind and not ahead else 0), 0


def moved(keys, i, field, d):
    """keys with event i moved d refreshes: field 0 the press (the release stays), 2 the release, 3 the tail."""
    out = [k[:] for k in keys]
    s = d * REFRESH
    if field == 0:
        out[i][0] = round(out[i][0] + s, 4)
        out[i][2] = round(out[i][2] - s, 4)
    elif field == 2:
        out[i][2] = round(out[i][2] + s, 4)
    else:
        t0 = keys[i][0]
        for k in out:
            if k[0] >= t0:
                k[0] = round(k[0] + s, 4)
    return out if all(k[2] > 0.02 for k in out) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--delay", type=float, default=0.47, help="--start case: seconds the posted keys land late at first")
    ap.add_argument("--start", default="case", choices=["case", "port"])
    ap.add_argument("--workers", type=int, default=10)
    ap.add_argument("--rounds", type=int, default=80)
    a = ap.parse_args()
    target = Path(__file__).parent / "cases" / a.game / f"{a.case}.port.json"
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    if a.start == "port" and target.exists():
        keys = galaxy_case.case_keys(a.game, a.case, "port")
        OFFSET[0] = galaxy_case.case_timer_offset(a.game, a.case)
    else:
        # stage 0: the timer's phase and the keys' common delay, together, over the first key
        script = galaxy_case.case_keys(a.game, a.case, "case")
        limit = script[0][0] + 8.0
        grid = [(off, d) for off in range(0, PERIOD, PERIOD // 12) for d in (0.36, 0.40, 0.44, 0.48, 0.52, 0.56)]
        futs = {pool.submit(trial, a.game, a.case, [[round(t + d, 4), k, h] for t, k, h in script], f"g{off}_{d}", limit, off): (off, d)
                for off, d in grid}
        scored = []
        for fu in concurrent.futures.as_completed(futs):
            scored.append((fu.result()[0], futs[fu]))
        scored.sort(key=lambda r: r[0], reverse=True)
        k0, (OFFSET[0], d0) = scored[0]
        say(f"stage 0: timer phase {OFFSET[0]}, delay {d0}: {k0} pictures (next best {scored[1][0]})")
        keys = [[round(t + d0, 4), k, h] for t, k, h in script]
    best, note, n, out = trial(a.game, a.case, keys, "base")
    say(f"{a.game} {a.case}: start {best} of {n} ({note})")
    rounds = 0
    while best < n - 1 and rounds < a.rounds:
        rounds += 1
        t_mis, way, gap = mismatch(a.game, a.case, out, best)
        events = []
        for i, (t, key, h) in enumerate(keys):
            for field, at in ((0, t), (2, t + h)):
                if t_mis - WINDOW <= at <= t_mis + 0.15:    # mismatch times count from the first picture, ~0.05 s in
                    events.append((at, i, field))
        events.sort(reverse=True)
        dirs = [way] if way else [1, -1]
        say(f"round {rounds}: mismatch at picture {best}, port {t_mis:.3f} s, direction {way}; events {[(i, f) for _, i, f in events]}")
        found = None
        for field_set in ((0, 2), (3,)):
            for _, i, field in (events if field_set != (3,) else events[:1]):
                f = field if field_set != (3,) else 3
                tries = []
                shifts = [sgn * d for sgn in dirs for d in range(1, SPAN + 1)]
                if abs(gap) > SPAN // 2:
                    # a picture held a different time: the gap says how far its ending key is off
                    shifts = list(range(gap - 4, gap + 5)) + [s for s in shifts if abs(s) <= 3]
                for d in dict.fromkeys(shifts):
                    if d == 0:
                        continue
                    cand = moved(keys, i, f, d)
                    if cand is not None:
                        tries.append((d, cand))
                futs = {pool.submit(trial, a.game, a.case, c, f"r{rounds}_{i}_{f}_{d}", t_mis + 3.0): (d, c) for d, c in tries}
                results = []
                for fu in concurrent.futures.as_completed(futs):
                    d, c = futs[fu]
                    k2, n2, _, _ = fu.result()
                    results.append((k2, -abs(d), d, c))
                if not results:
                    continue
                results.sort(key=lambda r: (r[0], r[1]), reverse=True)
                k2, _, d, c = results[0]
                if k2 > best:
                    found = (k2, d, c, i, f)
                    break
            if found:
                break
        if not found:
            say("  no move helps")
            break
        k2, d, c, i, f = found
        keys = c
        best, note, n, out = trial(a.game, a.case, keys, "best")
        say(f"  kept event {i} ({keys[i][1]}) {['press', '', 'release', 'tail'][f]} {d:+d} refreshes: {best} of {n} ({note})")
    result = "PASS" if n > 0 and best >= n - 1 else f"first difference at picture {best}"
    target.write_text(json.dumps({"keys": keys, "timer_offset": OFFSET[0], "result": result}, indent=1), encoding="utf-8")
    say(f"wrote {target.name}: {result}")
    return 0 if result == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
