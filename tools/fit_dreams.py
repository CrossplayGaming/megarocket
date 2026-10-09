# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Fits a Keen Dreams session's keys to the moments the original's keyboard saw them (REPLAY-D), as
tools/fit_galaxy.py does for Keen 4-6: DOSBox receives the runner's posted keys a little late, by a
different amount each time, and the recording is the fact.

Stage 0 takes the case's keys all a common delay later (the best of a grid, by how far the session
matches). Then, at each first mismatch (tools/dreams_case.py's score), the key events (presses and
releases) in the second before it are tried, newest first, moved one refresh at a time up to SPAN
refreshes in the direction the pictures point to (both ways when they do not), each trial run only a
little past the mismatch, in parallel; the best move that takes the match further is kept. When no
single event helps the newest one is moved with every key after it (the tail), also by the drift: the
port's loads take no time yet (TIME-D), so after each one its game runs ahead of the original's by the
load's time, and every later key the original saw comes that much earlier in the port's timeline (the
recording's time at the mismatch less the port's, both from the first picture). Then the DOS clock
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
from fit_galaxy import moved as _moved_galaxy


def moved(keys, i, field, d):
    """fit_galaxy's moves, but the tail (field 3) moves every press and release at or after event i's
    press, a release included when its key went down earlier (a load's drift moves them all)."""
    if field != 3:
        return _moved_galaxy(keys, i, field, d)
    out = [k[:] for k in keys]
    s = d * REFRESH
    t0 = keys[i][0]
    for k in out:
        if k[0] >= t0:
            k[0] = round(k[0] + s, 4)
        elif k[0] + k[2] >= t0:
            k[2] = round(k[2] + s, 4)    # down before, up after: only its release moves
    return out if all(k[2] > 0.02 for k in out) else None

REFRESH = 1 / dreams_case.REFRESH_HZ
SPAN = 20                  # refreshes each way an event is tried (DOSBox delays a press more than its release: holds come out shorter by up to ~0.25 s)
WINDOW = 1.0               # seconds before a mismatch whose events are tried
WORK = Path("F:/KeenReworkWork/port_runs")
BOOT = 3.2                 # port seconds before the first EGA picture (the start-up screens), and a margin
CLOCKS = list(range(0, 1000000, 27000))
AHEAD = 60                 # pictures after the first mismatch that a trial's score also counts
PAIR = 10                  # refreshes each way two events are moved together (in steps of two)   # a BIOS tick is 54.9 ms: two tries a tick


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


START = [dreams_case.DEFAULT_START]
CLOCK = [-1]
TC_ADDS = [[]]    # HARN-21: [[seconds from the first EGA picture, tics], ...]


def trial(game, case, keys, tag, until=None, clock=None, tc_adds=None):
    """(j, note, n, out, extra): a run of the port with `keys`, to `until` seconds of the recording."""
    out = WORK / f"fitd_{game}_{case}_{tag}"
    secs = None if until is None else BOOT + START[0] + until
    dreams_case.run_port(game, case, keys, out, seconds=secs, start=START[0],
                         clock=CLOCK[0] if clock is None else clock,
                         tc_adds=TC_ADDS[0] if tc_adds is None else tc_adds)
    try:
        j, note, n, port, orc, k = dreams_case.score(game, case, out)
    except Exception as err:          # a run that wrote nothing scores nothing
        return -1, str(err)[-80:], 0, out, None
    # the score: the first mismatch, then (as a fraction) how many of the next AHEAD pictures match, so a
    # move that leaves the first mismatch where it is but makes more of what follows agree counts (keys
    # that only together take the match further)
    ahead = sum(1 for x in range(AHEAD) if k + x < len(port) and j + x < len(orc) and port[k + x][0] == orc[j + x][0])
    return j + ahead / 1000.0, note, n, out, (port, orc, k, list(dreams_case.score.skips))


def mismatch(game, case, j, extra):
    """(recording seconds at the mismatch, direction, gap, drift): direction +1 the port is early (keys
    later), -1 late, 0 unknown; gap the recording's duration less the port's for the same picture; drift
    the recording's time at the mismatch less the port's, refreshes."""
    port, orc, k, _skips = extra
    oseq = frames.Sequence(Path(common.config()["oracle_runs"]) / f"{game}_{case}_a" / "frames")
    t = (oseq.repeats(0) + sum(r for _, r in orc[:j])) * REFRESH
    drift = sum(r for _, r in orc[:j]) - sum(r for _, r in port[:k])
    # the lag: how much later the port first shows the recording's next picture (a key that came too
    # late shows as that picture coming late), refreshes; 0 when it does not show it soon
    lag = 0
    want = orc[j + 1][0] if j + 1 < len(orc) and k < len(port) and port[k][0] == orc[j][0] else (orc[j][0] if j < len(orc) else None)
    for x in range(k, min(k + 40, len(port))):
        if port[x][0] == want:
            lag = sum(r for _, r in port[:x]) - sum(r for _, r in orc[:j + (1 if want != orc[j][0] else 0)])
            break
    if k < len(port) and j < len(orc) and port[k][0] == orc[j][0]:
        return t + min(port[k][1], orc[j][1]) * REFRESH, 0, orc[j][1] - port[k][1], drift, lag
    ahead = k < len(port) and any(j + x < len(orc) and orc[j + x][0] == port[k][0] for x in range(1, 6))
    behind = j < len(orc) and any(k + x < len(port) and port[k + x][0] == orc[j][0] for x in range(1, 6))
    return t, (1 if ahead and not behind else -1 if behind and not ahead else 0), 0, drift, lag


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--start", default="case", choices=["case", "port"])
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--rounds", type=int, default=80)
    ap.add_argument("--tc", default="", help="HARN-21 game clock adds to start from, at:tics,...")
    a = ap.parse_args()
    g, c = a.game, a.case
    target = dreams_case.CASES / g / f"{c}.port.json"
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    START[0] = dreams_case.case_start(g, c)
    CLOCK[0] = dreams_case.case_clock(g, c)
    TC_ADDS[0] = dreams_case.case_tc_adds(g, c) if a.start == "port" else []
    if a.tc:
        TC_ADDS[0] = [[float(x.split(":")[0]), int(x.split(":")[1])] for x in a.tc.split(",")]
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
        t_mis, way, gap, drift, lag = mismatch(g, c, int(best), extra)
        events = []
        for i, (t, _key, h) in enumerate(keys):
            for field, at in ((0, t), (2, t + h)):
                if t_mis - WINDOW <= at <= t_mis + 0.15:
                    events.append((at, i, field))
        events.sort(reverse=True)
        dirs = [way] if way else [1, -1]
        say(f"round {rounds}: mismatch at picture {int(best)} (+{round((best % 1) * 1000)} after), {t_mis:.3f} s, direction {way}, gap {gap}, drift {drift}, lag {lag}; "
            f"events {[(i, f) for _, i, f in events]}")
        found = None
        # a large drift is a load's time: the tail first, before single keys take part of it each
        for field_set in (((3,), (0, 2)) if max(abs(drift), abs(lag)) > SPAN // 2 else ((0, 2), (3,))):
            for _, i, field in (events if field_set != (3,) else events[:2]):
                f = field if field_set != (3,) else 3
                shifts = [sgn * d for sgn in dirs for d in range(1, SPAN + 1)]
                if abs(gap) > SPAN // 2:
                    shifts = list(range(gap - 4, gap + 5)) + [s for s in shifts if abs(s) <= 3]
                if max(abs(drift), abs(lag)) > SPAN // 2:
                    # the drift and the lag bracket the move (the lag can lock onto a blinking
                    # picture early): the whole range between them, with a margin
                    lo, hi = sorted((-drift, -lag))
                    shifts = list(range(lo - 14, hi + 5)) + shifts
                elif abs(lag) > SPAN // 2:
                    shifts = list(range(-lag - 4, -lag + 5)) + shifts
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
        if not found and len(events) >= 2:
            # keys that only together take the match further (a throw as an enemy arrives, the
            # direction key with it): every pair of the window's events moved together, coarsely
            pairs = [(events[x], events[y]) for x in range(len(events)) for y in range(x + 1, len(events))][:6]
            futs = {}
            for (_, i1, f1), (_, i2, f2) in pairs:
                for d1 in range(-PAIR, PAIR + 1, 2):
                    for d2 in range(-PAIR, PAIR + 1, 2):
                        if not d1 or not d2:
                            continue
                        c1 = moved(keys, i1, f1, d1)
                        cand = moved(c1, i2, f2, d2) if c1 is not None else None
                        if cand is not None:
                            futs[pool.submit(trial, g, c, cand, f"p{rounds}_{i1}{f1}_{i2}{f2}_{d1}_{d2}", t_mis + 3.0)] = (cand, i1, f1, d1, i2, f2, d2)
            res = sorted(((fu.result()[0], futs[fu]) for fu in futs), key=lambda r: r[0], reverse=True)
            if res and res[0][0] > best:
                cand, i1, f1, d1, i2, f2, d2 = res[0][1]
                keys = cand
                best, note, n, out, extra = trial(g, c, keys, "best")
                say(f"  kept events {i1}/{f1} {d1:+d} and {i2}/{f2} {d2:+d} together: {best} of {n} ({note})")
                continue
        if not found and extra is not None:
            # the game clock's parity in play (HARN-21): the frames accelerate and fall on its odd tics,
            # and a load's first frame clamps the clock, so the parity in play is the one carried
            # through the loads, which the original's slower loads can leave a tic apart. One tic
            # added just before each load before the mismatch, one at a time.
            port, orc, _k, skips = extra
            oseq = frames.Sequence(Path(common.config()["oracle_runs"]) / f"{g}_{c}_a" / "frames")
            tries = {}
            for j0, _a0, _b0, k0 in [sk for sk in skips if sk[0] <= int(best)]:
                at = round(START[0] + (oseq.repeats(0) + sum(r for _, r in port[:k0])) / dreams_case.REFRESH_HZ - 0.04, 4)
                if any(abs(x[0] - at) < 0.05 for x in TC_ADDS[0]):
                    continue
                cand = sorted(TC_ADDS[0] + [[at, 1]])
                tries[pool.submit(trial, g, c, keys, f"tc{rounds}_{j0}", t_mis + 3.0, None, cand)] = cand
            res = sorted(((fu.result()[0], tries[fu]) for fu in tries), key=lambda r: r[0], reverse=True)
            if res and res[0][0] > best:
                TC_ADDS[0] = res[0][1]
                best, note, n, out, extra = trial(g, c, keys, "best")
                say(f"  game clock +1 tic at {[x[0] for x in TC_ADDS[0]]} s: {best} of {n} ({note})")
                continue
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
    result = "PASS" if n > 0 and best >= n else f"first difference at picture {int(best)}"
    spec = dreams_case._port_spec(g, c)
    spec.update({"keys": keys, "start": START[0], "clock": CLOCK[0], "tc_adds": TC_ADDS[0], "result": result})
    target.write_text(json.dumps(spec, indent=1) + "\n", encoding="utf-8")
    say(f"wrote {target.name}: {result}")
    return 0 if result == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
