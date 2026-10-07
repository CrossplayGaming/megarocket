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
import timing_score

FRAME_SECONDS = 6 * 8192 / 1193182.0     # one game frame: six timer tics
REFRESH_SECONDS = 1 / 70.086               # one display refresh; keys in a WaitVBL-driven screen land on these
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


EXTRA_OPTS = []     # runner options every run gets (--fixed)
TIMING = False      # score by pictures and durations (tools/timing_score.py) instead of order alone


def run_port(game, keys, after, out):
    spec = ",".join(f"{t:.4f}:{SCANCODES[k]}:{h}" for t, k, h in keys)
    shutil.rmtree(out, ignore_errors=True)
    subprocess.run([sys.executable, "tools/gdtest.py", "simv01_boot", "--", f"--game={game}", "--seconds=120",
                    f"--out={out}", f"--keys_after_intro={spec}", f"--refreshes_after_intro={after - 10}"] + EXTRA_OPTS,
                   capture_output=True, text=True)


def score(out, oracle):
    if TIMING:
        try:
            k, note, port, orc, _ = timing_score.score(out, oracle)
        except Exception as err:
            return -1, str(err)[-100:]
        return (10 ** 9, "PASS") if k >= len(orc) - 1 else (k, note)
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
    ap.add_argument("--refreshes", action="store_true", help="shift by display refreshes instead of game frames")
    ap.add_argument("--keys", default=None, help="only fit these keys (comma-separated indices)")
    ap.add_argument("--start", default="case", choices=["case", "port"],
                    help="start from the case's scripted keys or from the fitted .port.json")
    ap.add_argument("--timing", action="store_true", help="score pictures and their durations, not order alone")
    ap.add_argument("--fixed", default="", help="runner options for every run, e.g. timer_offset=-1392640,vbl_period=17024000")
    args = ap.parse_args()
    global TIMING, EXTRA_OPTS
    TIMING = args.timing
    EXTRA_OPTS = [f"--{kv}" for kv in args.fixed.split(",") if kv]
    step = REFRESH_SECONDS if args.refreshes else FRAME_SECONDS
    cfg = common.config()
    oracle = Path(args.oracle or Path(cfg["oracle_runs"]) / f"{args.game}_{args.case}_a")
    case = json.loads((Path(__file__).parent / "cases" / args.game / f"{args.case}.json").read_text())
    intro_s, after = intro_of(oracle)
    keys = [[t - intro_s, k, h] for t, k, h in case["held"]]
    target = Path(__file__).parent / "cases" / args.game / f"{args.case}.port.json"
    if args.start == "port":
        keys = [list(k) for k in json.loads(target.read_text(encoding="utf-8"))["keys_after_intro"]]
    which = [int(i) for i in args.keys.split(",")] if args.keys else range(len(keys))
    print(f"recording's first intro frame {intro_s:.3f} s in; {after} refreshes follow; {len(keys)} keys")
    out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"fitkeys_{args.game}_{args.case}"
    run_port(args.game, keys, after, out)
    best_score, note = score(out, oracle)
    print(f"as scripted: {note}")
    for i in which:
        if best_score == 10 ** 9:
            break
        tried = {0: best_score}
        for d in sorted(range(-args.range, args.range + 1), key=abs):
            if d == 0:
                continue
            trial = [k[:] for k in keys]
            trial[i][0] += d * step
            run_port(args.game, trial, after, out)
            s, note = score(out, oracle)
            tried[d] = s
            print(f"  key {i} ({keys[i][1]} at {keys[i][0]:.3f} s) shifted {d:+d} {'refreshes' if args.refreshes else 'frames'}: {note}")
            if s > best_score:
                best_score = s
                keys = trial
        # then the release: how long the key was held, the press kept where it landed
        for d in sorted(range(-args.range, args.range + 1), key=abs):
            if d == 0 or best_score == 10 ** 9:
                continue
            trial = [k[:] for k in keys]
            trial[i][2] = round(trial[i][2] + d * step, 4)
            if trial[i][2] <= 0.01:
                continue
            run_port(args.game, trial, after, out)
            s, note = score(out, oracle)
            print(f"  key {i} ({keys[i][1]} held {keys[i][2]:.3f} s) release moved {d:+d}: {note}")
            if s > best_score:
                best_score = s
                keys = trial
        print(f"key {i}: kept {keys[i][0]:.4f} s, held {keys[i][2]:.4f} s (best {best_score if best_score < 10**9 else 'PASS'})")
    fitted = {"keys_after_intro": [[round(t, 4), k, h] for t, k, h in keys], "refreshes_after_intro": after,
              "result": "PASS" if best_score == 10 ** 9 else f"first difference at game frame {best_score}"}
    target.write_text(json.dumps(fitted, indent=1), encoding="utf-8")
    print("wrote", target, fitted["result"])


if __name__ == "__main__":
    main()
