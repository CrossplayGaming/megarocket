#!/usr/bin/env python3
# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Fit the frames a Vorticons oracle recording's keys landed on.

The oracle runner posts a case's held keys to DOSBox's window at their
moments, which reach the game a frame or so later than scripted, differently
each run. The recording is nevertheless a fact: every key reached the game in
a definite game frame. This tool finds those frames: it runs the port with the
keys timed from the first intro frame and, key by key, shifts each one by up
to `--range` frames until the comparator takes the run furthest. The result is
the case's key list for the port, frame-exact, written beside the oracle case.

Usage:
  python tools/fit_keys.py <game> <case> [--range 3] [--oracle <run folder>]
The case file's "held" entries are [seconds after the recording's start, key,
hold]; the recording's first intro frame is found in it, and the port's keys
are timed from the same moment.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import common
import frames

FRAME_SECONDS = 6 * 8192 / 1193182.0     # one game frame: six timer tics
SCANCODES = {"enter": 28, "esc": 1, "space": 57, "ctrl": 29, "alt": 56, "up": 72, "down": 80, "left": 75, "right": 77,
             "tab": 15, "lshift": 42, "f1": 59, "f2": 60, "f3": 61, "f4": 62, "f5": 63, "y": 21, "n": 49, "d": 32, "t": 20}


def intro_of(run_dir):
    seq = frames.Sequence(Path(run_dir) / "frames")
    reps = [seq.repeats(i) for i in range(len(seq))]
    for i in range(len(seq)):
        lit = int((np.frombuffer(seq.frame(i), np.uint8).reshape(200, 320, 3).max(axis=2) > 0).sum())
        if 100 < lit < 1000:
            return sum(reps[:i]) / 70.086, sum(reps[i:])
    raise SystemExit("the recording's first intro picture was not found")


def run_port(game, keys, after, out):
    spec = ",".join(f"{t:.4f}:{SCANCODES[k]}:{h}" for t, k, h in keys)
    shutil.rmtree(out, ignore_errors=True)
    subprocess.run([sys.executable, "tools/gdtest.py", "simv01_boot", "--", f"--game={game}", "--seconds=120",
                    f"--out={out}", f"--keys_after_intro={spec}", f"--refreshes_after_intro={after - 10}"],
                   capture_output=True, text=True)


def score(out, oracle):
    c = subprocess.run([sys.executable, "tools/compare_frames.py", "port", str(out), str(oracle)], capture_output=True, text=True)
    if "PASS" in c.stdout:
        return 10 ** 9, "PASS"
    m = re.search(r"game frame (\d+) of (\d+)", c.stdout)
    return (int(m.group(1)), m.group(0)) if m else (-1, c.stdout.strip()[-100:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--range", type=int, default=3)
    ap.add_argument("--oracle", default=None)
    args = ap.parse_args()
    cfg = common.config()
    oracle = Path(args.oracle or Path(cfg["oracle_runs"]) / f"{args.game}_{args.case}_a")
    case = json.loads((Path(__file__).parent / "cases" / args.game / f"{args.case}.json").read_text())
    intro_s, after = intro_of(oracle)
    keys = [[t - intro_s, k, h] for t, k, h in case["held"]]
    print(f"recording's first intro frame {intro_s:.3f} s in; {after} refreshes follow; {len(keys)} keys")
    out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"fitkeys_{args.game}_{args.case}"
    run_port(args.game, keys, after, out)
    best_score, note = score(out, oracle)
    print(f"as scripted: {note}")
    for i in range(len(keys)):
        if best_score == 10 ** 9:
            break
        tried = {0: best_score}
        for d in sorted(range(-args.range, args.range + 1), key=abs):
            if d == 0:
                continue
            trial = [k[:] for k in keys]
            trial[i][0] += d * FRAME_SECONDS
            run_port(args.game, trial, after, out)
            s, note = score(out, oracle)
            tried[d] = s
            print(f"  key {i} ({keys[i][1]} at {keys[i][0]:.3f} s) shifted {d:+d} frames: {note}")
            if s > best_score:
                best_score = s
                keys = trial
        print(f"key {i}: kept {keys[i][0]:.4f} s (best {best_score if best_score < 10**9 else 'PASS'})")
    fitted = {"keys_after_intro": [[round(t, 4), k, h] for t, k, h in keys], "refreshes_after_intro": after,
              "result": "PASS" if best_score == 10 ** 9 else f"first difference at game frame {best_score}"}
    target = Path(__file__).parent / "cases" / args.game / f"{args.case}.port.json"
    target.write_text(json.dumps(fitted, indent=1), encoding="utf-8")
    print("wrote", target, fitted["result"])


if __name__ == "__main__":
    main()
