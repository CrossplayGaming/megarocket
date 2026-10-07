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
import functools
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
print = functools.partial(print, flush=True)    # progress shows while a long fit runs
import common
import frames
import timing_score

FRAME_SECONDS = 6 * 8192 / 1193182.0     # one game frame: six timer tics
REFRESH_SECONDS = 1 / 70.086               # one display refresh; keys in a WaitVBL-driven screen land on these
SCANCODES = {"enter": 28, "esc": 1, "space": 57, "ctrl": 29, "alt": 56, "up": 72, "down": 80, "left": 75, "right": 77,
             "tab": 15, "1": 2, "lshift": 42, "f1": 59, "f2": 60, "f3": 61, "f4": 62, "f5": 63, "y": 21, "n": 49, "d": 32, "t": 20}


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


SAVE_SEED = []      # --save_seed for a case with an "overrides" folder of saves
PAIRS = 0           # --pairs N: when no single move helps, try press and release moved jointly by up to N steps each


def run_port(game, keys, after, out):
    """Runs the port; returns the display index of the first intro frame (for timing mismatches)."""
    spec = ",".join(f"{t:.4f}:{SCANCODES[k]}:{h}" for t, k, h in keys)
    shutil.rmtree(out, ignore_errors=True)
    r = subprocess.run([sys.executable, "tools/gdtest.py", "simv01_boot", "--", f"--game={game}", "--seconds=120",
                        f"--out={out}", f"--keys_after_intro={spec}", f"--refreshes_after_intro={after - 10}"] + EXTRA_OPTS + SAVE_SEED,
                       capture_output=True, text=True)
    total = re.search(r"(\d+) displays,", r.stdout)
    later = re.search(r"intro mark at [\d.]+ s, (\d+) displays after it", r.stdout)
    return int(total.group(1)) - int(later.group(1)) if total and later else 0


def mismatch_time(out, oracle, intro_display):
    """Seconds after the first intro frame at which the first mismatching picture starts in the port."""
    k, _, port, orc, start = timing_score.score(out, oracle, transient=True)
    full = timing_score.pictures(frames.Sequence(Path(out)), False)
    disp = sum(n for _, n in full[:start + k])
    longest = max(port[k][1] if k < len(port) else 0, orc[k][1] if k < len(orc) else 0)
    return (disp - intro_display) / 70.086, (disp + longest - intro_display) / 70.086


MOVES = {0: "key", 1: "press", 2: "release"}


def targeted(game, keys, after, out, oracle, step, rng, window):
    """Repeatedly: find the first mismatch, try moving each key whole, its press
    alone or its release alone where they fall in the `window` seconds before
    it, keep the best single change."""
    intro_display = run_port(game, keys, after, out)
    best, note = score(out, oracle)
    print(f"as given: {note}")
    rounds = 0
    while best != 10 ** 9 and rounds < 40:
        rounds += 1
        t_mis, t_end = mismatch_time(out, oracle, intro_display)
        cands = []
        for i, (t, k, h) in enumerate(keys):
            if t_mis - window <= t <= t_end + 0.1:
                cands.append((i, 0))
                cands.append((i, 1))
            if t_mis - window <= t + h <= t_end + 0.1:
                cands.append((i, 2))
        print(f"round {rounds}: mismatch in the picture at {t_mis:.3f}-{t_end:.3f} s after the intro; trying {[(i, MOVES[f]) for i, f in cands]}")
        top = (best, None, note)
        for i, field in cands:
            for d in sorted(range(-rng, rng + 1), key=abs):
                if d == 0:
                    continue
                trial = [k[:] for k in keys]
                if field == 1:      # the press alone: the release stays where it landed
                    trial[i][0] = round(trial[i][0] + d * step, 4)
                    trial[i][2] = round(trial[i][2] - d * step, 4)
                else:
                    trial[i][field] = round(trial[i][field] + d * step, 4)
                if trial[i][2] <= 0.01:
                    continue
                run_port(game, trial, after, out)
                s, n2 = score(out, oracle)
                if s > top[0]:
                    top = (s, trial, n2)
        if top[1] is None and PAIRS:
            # no single move helps: try each key's press and release moved together, independently
            for i in sorted({i for i, _ in cands}):
                for dp in range(-PAIRS, PAIRS + 1):
                    for dr in range(-PAIRS, PAIRS + 1):
                        if dp == 0 or dr == 0 or dp == dr:
                            continue    # those are the single moves already tried
                        trial = [k[:] for k in keys]
                        trial[i][0] = round(trial[i][0] + dp * step, 4)
                        trial[i][2] = round(trial[i][2] + (dr - dp) * step, 4)
                        if trial[i][2] <= 0.01:
                            continue
                        run_port(game, trial, after, out)
                        s, n2 = score(out, oracle)
                        if s > top[0]:
                            top = (s, trial, n2)
                            print(f"  pair move key {i}: press {dp:+d}, release {dr:+d}: {n2}")
        if top[1] is None:
            print(f"  no single move helps; stopping at {note}")
            break
        keys = top[1]
        best, note = top[0], top[2]
        intro_display = run_port(game, keys, after, out)
        print(f"  kept: {note}")
    return keys, best


def score(out, oracle):
    if TIMING:
        try:
            k, note, port, orc, _ = timing_score.score(out, oracle, transient=True)
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
    ap.add_argument("--step_ms", type=float, default=None,
                    help="shift by this many milliseconds instead (a key whose repeat must land on one side of a frame's input read)")
    ap.add_argument("--keys", default=None, help="only fit these keys (comma-separated indices)")
    ap.add_argument("--start", default="case", choices=["case", "port"],
                    help="start from the case's scripted keys or from the fitted .port.json")
    ap.add_argument("--timing", action="store_true", help="score pictures and their durations, not order alone")
    ap.add_argument("--fixed", default="", help="runner options for every run, e.g. timer_offset=-1392640,vbl_period=17024000")
    ap.add_argument("--delay", type=float, default=0.0, help="--start case: seconds the posted keys are assumed to land late (0.17 is typical)")
    ap.add_argument("--targeted", action="store_true", help="move only the presses and releases just before each mismatch, repeatedly")
    ap.add_argument("--window", type=float, default=1.5, help="--targeted: seconds before a mismatch whose key events are tried")
    ap.add_argument("--pairs", type=int, default=0, help="--targeted: when no single move helps, try each key's press and release moved jointly by up to N steps")
    args = ap.parse_args()
    global TIMING, EXTRA_OPTS, PAIRS
    PAIRS = args.pairs
    TIMING = args.timing
    EXTRA_OPTS = [f"--{kv}" for kv in args.fixed.split(",") if kv]
    step = args.step_ms / 1000.0 if args.step_ms else REFRESH_SECONDS if args.refreshes else FRAME_SECONDS
    cfg = common.config()
    oracle = Path(args.oracle or Path(cfg["oracle_runs"]) / f"{args.game}_{args.case}_a")
    case = json.loads((Path(__file__).parent / "cases" / args.game / f"{args.case}.json").read_text())
    global SAVE_SEED
    if case.get("overrides"):
        SAVE_SEED = [f"--save_seed={(common.ROOT / case['overrides']).as_posix()}"]
    intro_s, after = intro_of(oracle)
    keys = [[t - intro_s + args.delay, k, h] for t, k, h in case["held"]]
    target = Path(__file__).parent / "cases" / args.game / f"{args.case}.port.json"
    if args.start == "port":
        keys = [list(k) for k in json.loads(target.read_text(encoding="utf-8"))["keys_after_intro"]]
    which = [int(i) for i in args.keys.split(",")] if args.keys else range(len(keys))
    print(f"recording's first intro frame {intro_s:.3f} s in; {after} refreshes follow; {len(keys)} keys")
    out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"fitkeys_{args.game}_{args.case}"
    if args.targeted:
        keys, best_score = targeted(args.game, keys, after, out, oracle, step, args.range, args.window)
        fitted = {"keys_after_intro": [[round(t, 4), k, h] for t, k, h in keys], "refreshes_after_intro": after,
                  "result": "PASS" if best_score == 10 ** 9 else f"first difference at picture {best_score}"}
        target.write_text(json.dumps(fitted, indent=1), encoding="utf-8")
        print("wrote", target, fitted["result"])
        return
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
