#!/usr/bin/env python3
# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Sweep one runner option or named cost against an oracle recording, scored
by tools/timing_score.py (pictures AND their durations), and report the value
that carries the port furthest.

Usage:
  python tools/fit_option.py <game> <case> <option> --from A --to B --step S [--unit N]
                             [--fixed opt=value,...] [--tolerance 0]
<option> is a simv01_boot option (timer_offset, vga_cost) or cost:<name>. The
range is multiplied by --unit (default 1; 8192000 = one timer tic in units).
A case with a fitted key file (<case>.port.json) runs with those keys.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import common
import timing_score
from fit_keys import SCANCODES

TICK_UNITS = 8192 * 1000


def run_args(game, case, seconds):
    port_case = Path(__file__).parent / "cases" / game / f"{case}.port.json"
    extra = []
    spec = json.loads((Path(__file__).parent / "cases" / game / f"{case}.json").read_text())
    if spec.get("overrides"):
        extra.append(f"--save_seed={(common.ROOT / spec['overrides']).as_posix()}")
    if port_case.exists():
        pc = json.loads(port_case.read_text(encoding="utf-8"))
        extra = [f"--keys_after_intro={','.join(f'{t:.4f}:{SCANCODES[k]}:{h}' for t, k, h in pc['keys_after_intro'])}",
                 f"--refreshes_after_intro={pc['refreshes_after_intro'] - 10}"]
        seconds = 120
    return extra, seconds


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("option")
    ap.add_argument("--from", dest="lo", type=float, required=True)
    ap.add_argument("--to", dest="hi", type=float, required=True)
    ap.add_argument("--step", type=float, required=True)
    ap.add_argument("--unit", type=float, default=1.0)
    ap.add_argument("--fixed", default="")
    ap.add_argument("--tolerance", type=int, default=0)
    ap.add_argument("--seconds", type=float, default=None)
    args = ap.parse_args()
    cfg = common.config()
    case = json.loads((Path(__file__).parent / "cases" / args.game / f"{args.case}.json").read_text())
    oracle = Path(cfg["oracle_runs"]) / f"{args.game}_{args.case}_a"
    extra, seconds = run_args(args.game, args.case, args.seconds or case.get("seconds", 30))
    fixed_opts, fixed_costs = [], []
    for spec in filter(None, args.fixed.split(",")):
        k, v = spec.split("=")
        (fixed_costs if k.startswith("cost:") else fixed_opts).append((k.removeprefix("cost:"), v))
    results = []
    n = int(round((args.hi - args.lo) / args.step)) + 1
    for k in range(n):
        value = args.lo + k * args.step
        raw = int(round(value * args.unit))
        out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"fitopt_{args.game}_{args.case}_{args.option.replace(':', '_')}_{k}"
        shutil.rmtree(out, ignore_errors=True)
        opts = [f"--{o}={v}" for o, v in fixed_opts]
        costs = list(fixed_costs)
        if args.option.startswith("cost:"):
            costs.append((args.option[5:], str(raw)))
        else:
            opts.append(f"--{args.option}={raw}")
        if costs:
            opts.append("--costs=" + ",".join(f"{c}={v}" for c, v in costs))
        subprocess.run([sys.executable, "tools/gdtest.py", "simv01_boot", "--", f"--game={args.game}", f"--seconds={seconds}",
                        f"--out={out}"] + opts + extra, capture_output=True, text=True)
        try:
            s, note, _, _, _ = timing_score.score(out, oracle, args.tolerance)
        except Exception as err:    # a run that produced nothing
            s, note = -1, str(err)[-100:]
        print(f"  {args.option} = {value:10.4f} ({raw:12d}): {s:5d}  {note}", flush=True)
        results.append((s, value, raw))
        shutil.rmtree(out, ignore_errors=True)
    results.sort(reverse=True)
    best = [r for r in results if r[0] == results[0][0]]
    print(f"best: {results[0][0]} with {args.option} in [{min(r[1] for r in best)}, {max(r[1] for r in best)}]; "
          f"middle {(min(r[1] for r in best) + max(r[1] for r in best)) / 2:.4f}", flush=True)


if __name__ == "__main__":
    main()
