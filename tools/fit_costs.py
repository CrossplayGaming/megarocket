#!/usr/bin/env python3
# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Fit one of the port's processor-time costs against an oracle recording.

The originals ran on a processor of a definite speed (DOSBox at a fixed cycle
count, as they are sold), and where they do work the port does at once --
loading, decompressing -- their timer kept counting. The port charges such a
stretch a named cost (clock units) and this tool finds the value: it runs the
port with each candidate and keeps the one the comparator takes furthest.

Usage:
  python tools/fit_costs.py <game> <case> <cost name> [--from 0] [--to 12] [--step 0.25]
                            [--fixed name=units,...] [--seconds N]
The range is in timer tics (8192 clock cycles each, 1000 units a cycle).
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import common

TICK_UNITS = 8192 * 1000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("cost")
    ap.add_argument("--from", dest="lo", type=float, default=0.0)
    ap.add_argument("--to", dest="hi", type=float, default=12.0)
    ap.add_argument("--step", type=float, default=0.25)
    ap.add_argument("--fixed", default="")
    ap.add_argument("--seconds", type=float, default=None)
    ap.add_argument("--oracle", default=None, help="oracle run folder (default <oracle_runs>/<game>_<case>_a)")
    args = ap.parse_args()
    cfg = common.config()
    oracle = args.oracle or str(Path(cfg["oracle_runs"]) / f"{args.game}_{args.case}_a")
    case = common.load_case(args.game, args.case) if hasattr(common, "load_case") else None
    seconds = args.seconds or (case["seconds"] if case else 30)
    results = []
    n = int(round((args.hi - args.lo) / args.step)) + 1
    for k in range(n):
        tics = args.lo + k * args.step
        units = int(round(tics * TICK_UNITS))
        out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"fit_{args.game}_{args.case}_{args.cost}_{k}"
        shutil.rmtree(out, ignore_errors=True)
        costs = f"{args.cost}={units}" + ("," + args.fixed if args.fixed else "")
        subprocess.run([sys.executable, "tools/gdtest.py", "simv01_boot", "--", f"--game={args.game}", f"--seconds={seconds}",
                        f"--out={out}", f"--costs={costs}"], capture_output=True, text=True)
        c = subprocess.run([sys.executable, "tools/compare_frames.py", "port", str(out), oracle], capture_output=True, text=True)
        m = re.search(r"game frame (\d+) of (\d+)", c.stdout)
        if "PASS" in c.stdout:
            score, note = 10 ** 9, "PASS"
        elif m:
            score, note = int(m.group(1)), f"first difference at game frame {m.group(1)} of {m.group(2)}"
        else:
            score, note = -1, (c.stdout + c.stderr).strip()[-120:]
        print(f"  {args.cost} = {tics:6.2f} tics ({units:10d} units): {note}")
        results.append((score, tics, units))
        shutil.rmtree(out, ignore_errors=True)
    results.sort(reverse=True)
    best = [r for r in results if r[0] == results[0][0]]
    lo, hi = min(r[1] for r in best), max(r[1] for r in best)
    print(f"best: {results[0][0] if results[0][0] < 10**9 else 'PASS'} with {args.cost} in [{lo}, {hi}] tics; "
          f"middle {(lo + hi) / 2:.2f} tics = {int(round((lo + hi) / 2 * TICK_UNITS))} units")


if __name__ == "__main__":
    main()
