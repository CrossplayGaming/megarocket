#!/usr/bin/env python3
# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Solve the port's refresh period and timer phase from an oracle recording.

A tic-paced frame's picture appears at the first retrace after its start
address is written. Each port frame that starts a new picture therefore
bounds how far the original's timer led the port's at that moment: from the
frame's margin to the next retrace, and from whether the recording showed the
picture at the same refresh, one earlier or one later. A constant period and
phase make that lead a straight line in time; this finds the lines that pass
through every bound and converts the middle one into the engine's
`dosbox_timing` values (A17).

Frames that begin right at a retrace (after a WaitVBL) say nothing about the
timer and are left out. When no line fits, the bounds listed show where the
model breaks (a step between two screens is an unmodelled processor cost).

Usage:
  python tools/fit_timing.py <game> <case> [--seconds N] [--show]
The run uses the engine's current timing; the result is the correction.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import common
import frames
import timing_score

UNITS_PER_S = 1193182 * 1000


def trace_run(game, case, seconds, out):
    import os
    from fit_option import run_args
    extra, seconds = run_args(game, case, seconds)    # a case's fitted keys and length, if it has them
    env = dict(os.environ, MR_TRACE="1")
    r = subprocess.run([sys.executable, "tools/gdtest.py", "simv01_boot", "--", f"--game={game}", f"--seconds={seconds}",
                        f"--out={out}"] + extra, capture_output=True, text=True, env=env)
    return [l for l in r.stdout.splitlines() if l.startswith("TRACE")]


def current_timing(game):
    src = (Path(__file__).parent.parent / "godot/games/vorticons/vort_main.gd").read_text(encoding="utf-8")
    m = re.search(r'var dosbox_timing: Dictionary = (\{[^}]*\})', src)
    return json.loads(m.group(1))


def bounds(trace, port_dir, oracle_dir, period_units):
    P = period_units / UNITS_PER_S
    frames_ = []
    start = None
    for line in trace:
        parts = line.split()
        d = dict(p.split("=") for p in parts[2:])
        if parts[1] == "start":
            start = (float(d["t"]), float(d["last_vbl"]))
        elif parts[1] == "refresh":
            if start and start[0] - start[1] < 0.00005:
                continue        # began on a wait, not on a tic
            frames_.append((float(d["t"]), float(d["next_vbl"]), int(d["vbl"])))
    ps = timing_score.pictures(frames.Sequence(Path(port_dir)), False)
    os_ = timing_score.pictures(frames.Sequence(Path(oracle_dir) / "frames"), True)
    # picture start refreshes
    def starts(pics):
        out, r = [], 0
        for d, n in pics:
            out.append((d, r))
            r += n
        return out
    ps, os_ = starts(ps), starts(os_)
    k0 = next(k for k, p in enumerate(ps) if p[0] == os_[0][0])
    ps = ps[k0:]
    c = ps[0][1] - os_[0][1]
    start_to_k = {}
    for k in range(min(len(ps), len(os_) - 1)):
        if ps[k][0] != os_[k][0]:
            break
        start_to_k[ps[k][1]] = k
    # a frame written when vbl_count was v shows after retrace v + 1: display index v
    # (the runner writes its first display after the first retrace)
    out = []
    for t, nv, v in frames_:
        if v not in start_to_k:
            continue
        k = start_to_k[v]
        delta = (os_[k][1] + c) - v
        m = nv - t
        out.append((t, k, m, m + (delta - 1) * P, m + delta * P))
    return out


def fit_line(cons):
    """Lines lead = a + b t (seconds) inside every (lo, hi]; returns (b, a_lo, a_hi) per feasible slope."""
    feasible = []
    for i in range(-3000, 3001):
        b = i * 2e-9           # seconds of lead per second
        lo = max(c[3] - b * c[0] for c in cons)
        hi = min(c[4] - b * c[0] for c in cons)
        if lo < hi:
            feasible.append((b, lo, hi))
    return feasible


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("cases", help="one case or several, comma-separated: their bounds are solved together")
    ap.add_argument("--seconds", type=float, default=None)
    ap.add_argument("--show", action="store_true", help="list every tight bound")
    args = ap.parse_args()
    cfg = common.config()
    cons, tm = [], None
    for case_name in args.cases.split(","):
        case = json.loads((Path(__file__).parent / "cases" / args.game / f"{case_name}.json").read_text())
        seconds = args.seconds or case.get("seconds", 30) + 3
        oracle = Path(cfg["oracle_runs"]) / f"{args.game}_{case_name}_a"
        out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"fit_timing_{args.game}_{case_name}"
        trace = trace_run(args.game, case_name, seconds, out)
        used = [l for l in trace if l.startswith("TRACE timing ")]
        tm = json.loads(used[0][len("TRACE timing "):]) if used else current_timing(args.game)
        tm = {k: int(v) for k, v in tm.items()}
        trace = [l for l in trace if not l.startswith("TRACE timing ")]
        these = bounds(trace, out, oracle, tm["vbl_period"])
        k, note, *_ = timing_score.score(out, oracle)
        print(f"{case_name}: timing score {k} ({note}); {len(these)} picture-starting tic frames")
        if args.show:
            for t, kk, m, lo, hi in these:
                if lo > -0.001 or hi < 0.0005:
                    print("  t %7.3f  picture %4d  margin %6.3f ms  lead in (%7.3f, %7.3f] ms" % (t, kk, m * 1e3, lo * 1e3, hi * 1e3))
        cons += these
    print(f"current timing {tm}")
    feasible = fit_line(cons)
    if not feasible:
        print("no constant phase and rate fits every bound: list them with --show to find the step")
        return 1
    W = sum(h - l for _, l, h in feasible)
    b = sum(b * (h - l) for b, l, h in feasible) / W
    a = sum((l + h) / 2 * (h - l) for _, l, h in feasible) / W
    print("feasible slopes %.2f..%.2f us/s; centre: lead %.2f us at t=0, %.3f us/s"
          % (feasible[0][0] * 1e6, feasible[-1][0] * 1e6, a * 1e6, b * 1e6))
    new = {"cycles": tm["cycles"], "vbl_period": round(tm["vbl_period"] * (1 - b)),
           "timer_offset": round(tm["timer_offset"] + a * UNITS_PER_S)}
    print("dosbox_timing:", json.dumps(new))
    return 0


if __name__ == "__main__":
    sys.exit(main())
