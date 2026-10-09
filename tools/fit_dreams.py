# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Fits a Keen Dreams session's keys to the moments the original's keyboard saw them (REPLAY-D), as
tools/fit_galaxy.py does for Keen 4-6: DOSBox receives the runner's posted keys a little late, by a
different amount each time, and the recording is the fact.

Stage 0 takes the case's keys all a common delay later (the best of a grid, by how far the session
matches). Then, at each first mismatch (tools/dreams_case.py's score), the key events (presses and
releases) in the second before it are tried, newest first, moved one refresh at a time up to SPAN
refreshes in the direction the pictures point to (both ways when they do not), each trial run only a
little past the mismatch, in parallel; the best move that takes the match further is kept. When no
single event helps the newest one is moved with every key after it (the tail), and then the DOS clock
at the start (the random table's seed is its hundredths at US_Startup) is tried over a second. It stops
when the whole recording matches or nothing helps. The keys, the start and the clock go to
tools/cases/<game>/<case>.port.json (tools/dreams_case.py uses them).

    python tools/fit_dreams.py kdreams level01 [--workers 8] [--start case|port]
"""
import argparse
import concurrent.futures
import json
import sys
import time
from pathlib import Path

import common
import dreams_case
import frames
from fit_galaxy import moved

REFRESH = 1 / dreams_case.REFRESH_HZ
SPAN = 10                  # refreshes each way an event is tried
WINDOW = 1.0               # seconds before a mismatch whose events are tried
WORK = Path("F:/KeenReworkWork/port_runs")
BOOT = 3.2                 # port seconds before the first EGA picture (the start-up screens), and a margin
CLOCKS = list(range(0, 1000000, 27000))   # a BIOS tick is 54.9 ms: two tries a tick


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


START = [dreams_case.DEFAULT_START]
CLOCK = [-1]


def trial(game, case, keys, tag, until=None, clock=None):
    """(j, note, n, out, extra): a run of the port with `keys`, to `until` seconds of the recording."""
    out = WORK / f"fitd_{game}_{case}_{tag}"
    secs = None if until is None else BOOT + START[0] + until
    dreams_case.run_port(game, case, keys, out, seconds=secs, start=START[0],
                         clock=CLOCK[0] if clock is None else clock)
    try:
        j, note, n, port, orc, k = dreams_case.score(game, case, out)
    except Exception as err:          # a run that wrote nothing scores nothing
        return -1, str(err)[-80:], 0, out, None
    return j, note, n, out, (port, orc, k)


def mismatch(game, case, j, extra):
    """(recording seconds at the mismatch, direction, gap): direction +1 the port is early (keys later),
    -1 late, 0 unknown; gap the recording's duration less the port's for the same picture."""
    port, orc, k = extra
    oseq = frames.Sequence(Path(common.config()["oracle_runs"]) / f"{game}_{case}_a" / "frames")
    t = (oseq.repeats(0) + sum(r for _, r in orc[:j])) * REFRESH
    if k < len(port) and j < len(orc) and port[k][0] == orc[j][0]:
        return t + min(port[k][1], orc[j][1]) * REFRESH, 0, orc[j][1] - port[k][1]
    ahead = k < len(port) and any(j + x < len(orc) and orc[j + x][0] == port[k][0] for x in range(1, 6))
    behind = j < len(orc) and any(k + x < len(port) and port[k + x][0] == orc[j][0] for x in range(1, 6))
    return t, (1 if ahead and not behind else -1 if behind and not ahead else 0), 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--start", default="case", choices=["case", "port"])
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--rounds", type=int, default=80)
    a = ap.parse_args()
    g, c = a.game, a.case
    target = dreams_case.CASES / g / f"{c}.port.json"
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    START[0] = dreams_case.case_start(g, c)
    CLOCK[0] = dreams_case.case_clock(g, c)
    # the recording's start: measured from a run with no keys at all
    _j, _note, _n, out, _extra = trial(g, c, [], "start", 2.0)
    got = dreams_case.measured_start(g, c, out)
    if got is not None:
        START[0] = round(got, 4)
    say(f"the recording starts {START[0]:.3f} s after the port's first EGA picture")
    if a.start == "port" and dreams_case.case_keys(g, c, "port") != dreams_case.case_keys(g, c, "case"):
        keys = dreams_case.case_keys(g, c, "port")
    else:
        script = dreams_case.case_keys(g, c, "case")
        delays = [round(0.03 * i, 2) for i in range(0, 17)]
        futs = {pool.submit(trial, g, c, [[round(t + d, 4), k, h] for t, k, h in script], f"d{d}"): d for d in delays}
        scored = sorted(((fu.result()[0], -futs[fu], futs[fu]) for fu in futs), reverse=True)
        d0 = scored[0][2]
        say(f"stage 0: delay {d0} s: {scored[0][0]} pictures (by delay: {sorted((d, s) for s, _, d in scored)})")
        keys = [[round(t + d0, 4), k, h] for t, k, h in script]
    best, note, n, out, extra = trial(g, c, keys, "base")
    say(f"{g} {c}: start {best} of {n} ({note})")
    rounds = 0
    clock_tried = False
    while best < n and rounds < a.rounds and extra is not None:
        rounds += 1
        t_mis, way, gap = mismatch(g, c, best, extra)
        events = []
        for i, (t, _key, h) in enumerate(keys):
            for field, at in ((0, t), (2, t + h)):
                if t_mis - WINDOW <= at <= t_mis + 0.15:
                    events.append((at, i, field))
        events.sort(reverse=True)
        dirs = [way] if way else [1, -1]
        say(f"round {rounds}: mismatch at picture {best}, {t_mis:.3f} s, direction {way}, gap {gap}; "
            f"events {[(i, f) for _, i, f in events]}")
        found = None
        for field_set in ((0, 2), (3,)):
            for _, i, field in (events if field_set != (3,) else events[:1]):
                f = field if field_set != (3,) else 3
                shifts = [sgn * d for sgn in dirs for d in range(1, SPAN + 1)]
                if abs(gap) > SPAN // 2:
                    shifts = list(range(gap - 4, gap + 5)) + [s for s in shifts if abs(s) <= 3]
                tries = []
                for d in dict.fromkeys(shifts):
                    cand = moved(keys, i, f, d) if d != 0 else None
                    if cand is not None:
                        tries.append((d, cand))
                futs = {pool.submit(trial, g, c, cand, f"r{rounds}_{i}_{f}_{d}", t_mis + 3.0): (d, cand)
                        for d, cand in tries}
                results = sorted(((fu.result()[0], -abs(futs[fu][0]), futs[fu][0], futs[fu][1]) for fu in futs),
                                 key=lambda r: (r[0], r[1]), reverse=True)
                if results and results[0][0] > best:
                    found = (results[0][0], results[0][2], results[0][3], i, f)
                    break
            if found:
                break
        if not found:
            if not clock_tried:
                clock_tried = True
                futs = {pool.submit(trial, g, c, keys, f"c{rounds}_{ck}", t_mis + 3.0, ck): ck for ck in CLOCKS}
                ks = {futs[fu]: fu.result()[0] for fu in futs}
                top = max(ks.values())
                if top > best:
                    tops = sorted(ck for ck, k in ks.items() if k == top)
                    CLOCK[0] = tops[len(tops) // 2]
                    best, note, n, out, extra = trial(g, c, keys, "best")
                    say(f"  clock {CLOCK[0]} us: {best} of {n} ({note})")
                    continue
            say("  no move helps")
            break
        _k2, d, cand, i, f = found
        keys = cand
        clock_tried = False
        best, note, n, out, extra = trial(g, c, keys, "best")
        say(f"  kept event {i} ({keys[i][1]}) {['press', '', 'release', 'tail'][f]} {d:+d} refreshes: "
            f"{best} of {n} ({note})")
    result = "PASS" if n > 0 and best >= n else f"first difference at picture {best}"
    spec = dreams_case._port_spec(g, c)
    spec.update({"keys": keys, "start": START[0], "clock": CLOCK[0], "result": result})
    target.write_text(json.dumps(spec, indent=1) + "\n", encoding="utf-8")
    say(f"wrote {target.name}: {result}")
    return 0 if result == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
