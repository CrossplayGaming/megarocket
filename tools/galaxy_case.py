# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""REPLAY-G's measure for one recorded session: runs the Galaxy port (godot/tests/simg_boot.gd) with the
session's keys and holds its pictures, with their durations, against the recording <game>_<case>_a.

The keys are the case's own (seconds after the recording's first picture, which is the port's start
within 0.05 s), or, when tools/cases/<game>/<case>.port.json exists, the keys fitted to the recording
(the moments the original's keyboard actually saw them).

    python tools/galaxy_case.py keen4 level05 [--keys-from case|port] [--tag NAME] [--compare-lists]

--compare-lists (REND-01R): the port also holds every picture it shows against its refresh's draw list
(simg_boot's --compare_lists); the counts are left in the run's folder as lists.json.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

import common
import frames
import timing_score

ROOT = Path(__file__).resolve().parent.parent
CASES = Path(__file__).parent / "cases"
WORK = Path("F:/KeenReworkWork/port_runs")
SCANCODES = {"esc": 0x01, "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06, "6": 0x07, "7": 0x08, "8": 0x09, "9": 0x0A,
             "0": 0x0B, "w": 0x11, "o": 0x18, "enter": 0x1C, "ctrl": 0x1D, "a": 0x1E, "b": 0x30, "alt": 0x38, "space": 0x39,
             "f10": 0x44, "up": 0x48, "left": 0x4B, "right": 0x4D, "down": 0x50, "y": 0x15, "n": 0x31, "m": 0x32}


def case_timer_offset(game, case):
    """The timer's phase fitted to the recording (0 when not fitted): where the game's 70 Hz clock falls
    in each refresh depends on when DOSBox's start-up screen got its key, so it differs per recording."""
    port = CASES / game / f"{case}.port.json"
    if port.exists():
        return int(json.loads(port.read_text(encoding="utf-8")).get("timer_offset", 0))
    return 0


# The DOS clock when the program starts: the runner sets it to 00:00:00 just before the game
# (tools/oracle_run.py), so this is the time DOS takes to load and start the program (fitted once).
DOS_CLOCK_AT_START_US = 0


def recording_clock(game, case):
    """Microseconds the DOS clock has run since 00:00:00 as the recording's program starts."""
    return DOS_CLOCK_AT_START_US


def case_clock(game, case):
    """The DOS clock at the program's start for the recording, microseconds (its .port.json's "clock"
    if fitted): US_InitRndT(true) takes its hundredths when the level starts."""
    port = CASES / game / f"{case}.port.json"
    if port.exists():
        fitted = json.loads(port.read_text(encoding="utf-8")).get("clock")
        if fitted is not None:
            return int(fitted)
    return recording_clock(game, case)


def _port_spec(game, case):
    port = CASES / game / f"{case}.port.json"
    return json.loads(port.read_text(encoding="utf-8")) if port.exists() else {}


def case_seed_ticks(game, case):
    """BIOS ticks added to the clock's n-th reading, {n: ticks}, fitted per restart (HARN-20)."""
    return {int(n): int(d) for n, d in _port_spec(game, case).get("seed_ticks", {}).items()}


def case_lock(game, case):
    """Whether the session was fitted under HARN-20's frame lock."""
    return bool(_port_spec(game, case).get("lock", False))


def case_keys(game, case, source="port"):
    port = CASES / game / f"{case}.port.json"
    if source == "port" and port.exists():
        return [list(k) for k in json.loads(port.read_text(encoding="utf-8"))["keys"]]
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
    return [list(k) for k in spec["held"]]


def lock_file(game, case, path=None):
    """HARN-20's frame lock for a session: for each of the recording's blacks (the level's, then each
    restart's), the refresh at which each following picture first shows, counted from the first picture
    after the black, up to the next restart's pictures (whose timing is the load's, TIME-G). Written to
    `path` (by default WORK/lock_<game>_<case>.json)."""
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    orc = timing_score.pictures(frames.Sequence(oracle / "frames"), True)
    blacks = black_pictures(oracle)
    segments = []
    for i, b in enumerate(blacks):
        stop = blacks[i + 1] - RESTART_PICTURES if i + 1 < len(blacks) else len(orc) - 1
        offs, at = [], 0
        for k in range(b + 1, stop + 1):
            offs.append(at)
            at += orc[k][1]
        segments.append(offs)
    path = Path(path) if path else WORK / f"lock_{game}_{case}.json"
    path.write_text(json.dumps({"segments": segments}), encoding="utf-8")
    return path


def run_port(game, case, keys, out, seconds=None, extra=(), timer_offset=None, clock=None, lock=None,
             seed_ticks=None):
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
    seed_ticks = case_seed_ticks(game, case) if seed_ticks is None else seed_ticks
    if seed_ticks:
        extra = (f"--seed_ticks={','.join(f'{n}:{d}' for n, d in sorted(seed_ticks.items()) if d)}", *extra)
    if case_lock(game, case) if lock is None else lock:
        # (beside the run's own folder: runs of the same case side by side do not share it)
        extra = (f"--lock={lock_file(game, case, Path(out).with_name(Path(out).name + '_lock.json')).as_posix()}", *extra)
    secs = seconds or spec["seconds"] + 2
    keyarg = ",".join(f"{t:.4f}:{SCANCODES[k]}:{h}" for t, k, h in keys)
    if spec.get("args"):
        extra = (f"--args={spec['args']}", *extra)
    shutil.rmtree(out, ignore_errors=True)
    p = subprocess.run([sys.executable, "tools/gdtest.py", "simg_boot", "--", f"--game={game}", f"--seconds={secs}",
                        f"--out={Path(out).as_posix()}", f"--keys={keyarg}",
                        f"--timer_offset={case_timer_offset(game, case) if timer_offset is None else timer_offset}",
                        f"--clock={case_clock(game, case) if clock is None else clock}", *extra],
                       cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return p.returncode


def opening_end(oracle):
    """The index of the recording's first all-black picture: the level's black before the fade-in (the
    opening is the level loading under its name box, the fade out and that black)."""
    seq = frames.Sequence(Path(oracle) / "frames")
    seen = {}
    for i in range(len(seq)):
        seen.setdefault(seq.digest(i), i)
    orc = timing_score.pictures(seq, True)
    for n, (d, _r) in enumerate(orc[:60]):
        if not np.asarray(seq.frame(seen[d])).any():
            return n
    return -1


def black_pictures(oracle):
    """The indices of the recording's all-black pictures (the black before each fade-in)."""
    seq = frames.Sequence(Path(oracle) / "frames")
    seen = {}
    for i in range(len(seq)):
        seen.setdefault(seq.digest(i), i)
    orc = timing_score.pictures(seq, True)
    return [n for n, (d, _r) in enumerate(orc) if not np.asarray(seq.frame(seen[d])).any()]


# A restart's pictures whose durations follow the reload: the last one of play (held while the map
# loads), the level's box, the fade-out's three steps and the black.
RESTART_PICTURES = 5
# How far a restart's durations may sum from the recording's (TIME-G's restart error, refreshes)
RESTART_TOLERANCE = 2


def level_score(out, oracle):
    """REPLAY-G's measure of a level session: (k, note, n, opening_error).

    The opening (to the black before the fade-in, opening_end) must show the recording's pictures in
    order; how long each is held follows the level's loading time, which TIME-G's costs model to within
    a refresh or two, and after the fade-in the original restarts its clock (FadeAndUnhook's TimeCount =
    lasttimecount), so nothing after depends on it: those durations are only summed (opening_error).
    From the first picture after the black every picture and its duration must match, one-refresh slips
    that recover passed (timing_score's transient rule). A death's restart is the opening again (the
    level loads, its box, the fade-out, the black, and the fade-in sets the clock back): its pictures
    must match, their durations sum to within RESTART_TOLERANCE of the recording's (added to the error),
    and the count starts again after its black. The RNG is seeded from the DOS clock at the load and the
    fade-in, so a restart timed wrongly enough to matter still shows as a picture that differs."""
    _k, _note, port, orc, start = timing_score.score(Path(out), Path(oracle), transient=True)
    end = opening_end(oracle)
    n = min(len(port), len(orc) - 1)
    err = 0
    for k in range(min(end + 1, n)):
        if port[k][0] != orc[k][0]:
            return k, f"opening picture {k} differs", n, err
        if k < end:
            err += abs(port[k][1] - orc[k][1])
    restarts = [b for b in black_pictures(oracle) if b > end + RESTART_PICTURES]
    offset = 0
    slips = []
    for k in range(end + 1, n):
        if port[k][0] != orc[k][0]:
            return k, f"picture {k} differs" + timing_score._slips(slips), n, err
        b = next((b for b in restarts if b - RESTART_PICTURES <= k <= b), None)
        if b is not None:
            if k == b:
                miss = sum(port[j][1] - orc[j][1] for j in range(b - RESTART_PICTURES, b + 1))
                err += abs(miss)
                if abs(miss) > RESTART_TOLERANCE:
                    return k, f"the restart ending at picture {k} lasts {miss:+d} refreshes against the recording" +                         timing_score._slips(slips), n, err
                offset = 0
            continue
        if offset != 0:
            slips.append(k - 1)
        offset += port[k][1] - orc[k][1]
        if abs(offset) > 1 or (offset != 0 and slips and slips[-1] == k - 1):
            return k, f"picture {k} lasts {port[k][1]} refreshes in the port, {orc[k][1]} in the recording" + timing_score._slips(slips), n, err
    return n, f"all {n} pictures match, from the fade-in their durations too" + timing_score._slips(slips), n, err


def score(game, case, out):
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    k, note, n, err = level_score(out, oracle)
    if err:
        note += f"; the opening's durations {err} refreshes off in all"
    return k, note, n + 1


def case_out(game, case, tag="", lock=False):
    """The folder a session's run goes to (main's)."""
    return WORK / f"gcase_{game}_{case}{('_' + tag) if tag else ''}{'_lock' if lock else ''}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--keys-from", default="port", choices=["case", "port"])
    ap.add_argument("--tag", default="")
    ap.add_argument("--lock", action="store_true", help="hold each picture to the recording's refresh (HARN-20)")
    ap.add_argument("--compare-lists", action="store_true", help="REND-01R: each picture against its draw list")
    a = ap.parse_args()
    out = case_out(a.game, a.case, a.tag, a.lock)
    code = run_port(a.game, a.case, case_keys(a.game, a.case, a.keys_from), out, lock=True if a.lock else None,
                    extra=("--compare_lists=1",) if a.compare_lists else ())
    if code != 0:
        print(f"COULD-NOT-RUN: the port's run failed ({code})")
        return 2
    k, note, n = score(a.game, a.case, out)
    print(f"{a.game} {a.case}: {k} of {n} pictures ({note})")
    return 0 if k >= n - 1 else 1


if __name__ == "__main__":
    sys.exit(main())
