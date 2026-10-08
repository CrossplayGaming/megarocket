# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""REPLAY-G's measure for one recorded session: runs the Galaxy port (godot/tests/simg_boot.gd) with the
session's keys and holds its pictures, with their durations, against the recording <game>_<case>_a.

The keys are the case's own (seconds after the recording's first picture, which is the port's start
within 0.05 s), or, when tools/cases/<game>/<case>.port.json exists, the keys fitted to the recording
(the moments the original's keyboard actually saw them).

    python tools/galaxy_case.py keen4 level05 [--keys-from case|port] [--tag NAME]
"""
import argparse
import calendar
import json
import shutil
import subprocess
import sys
from pathlib import Path

import common
import timing_score

ROOT = Path(__file__).resolve().parent.parent
CASES = Path(__file__).parent / "cases"
WORK = Path("F:/KeenReworkWork/port_runs")
SCANCODES = {"esc": 0x01, "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06, "6": 0x07, "7": 0x08, "8": 0x09, "9": 0x0A,
             "0": 0x0B, "w": 0x11, "o": 0x18, "enter": 0x1C, "ctrl": 0x1D, "a": 0x1E, "b": 0x30, "alt": 0x38, "space": 0x39,
             "f10": 0x44, "up": 0x48, "left": 0x4B, "right": 0x4D, "down": 0x50, "y": 0x15, "n": 0x31}


def case_timer_offset(game, case):
    """The timer's phase fitted to the recording (0 when not fitted): where the game's 70 Hz clock falls
    in each refresh depends on when DOSBox's start-up screen got its key, so it differs per recording."""
    port = CASES / game / f"{case}.port.json"
    if port.exists():
        return int(json.loads(port.read_text(encoding="utf-8")).get("timer_offset", 0))
    return 0


# Borland's time() for the DOS clock, in its default zone EST5EDT: the local time plus five hours
ZONE_SECONDS = 5 * 3600


def recording_clock(game, case, zone=ZONE_SECONDS):
    """time(0) as the recording's program started: the runner sets the DOS clock to 00:00:00 just before it
    (tools/oracle_run.py) and the date stays the host's, the day the recording was made (its log's date)."""
    log = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a" / "stderr.txt"
    day = log.read_text(encoding="utf-8", errors="replace")[:10]
    y, m, d = (int(x) for x in day.split("-"))
    return calendar.timegm((y, m, d, 0, 0, 0)) + zone


def case_clock(game, case):
    """time(0) at the program's start for the recording (its .port.json's "clock" if fitted)."""
    port = CASES / game / f"{case}.port.json"
    if port.exists():
        fitted = json.loads(port.read_text(encoding="utf-8")).get("clock")
        if fitted is not None:
            return int(fitted)
    return recording_clock(game, case)


def case_keys(game, case, source="port"):
    port = CASES / game / f"{case}.port.json"
    if source == "port" and port.exists():
        return [list(k) for k in json.loads(port.read_text(encoding="utf-8"))["keys"]]
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
    return [list(k) for k in spec["held"]]


def run_port(game, case, keys, out, seconds=None, extra=(), timer_offset=None, clock=None):
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
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


def score(game, case, out):
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    k, note, port, orc, start = timing_score.score(Path(out), oracle, transient=True)
    return k, note, len(orc)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--keys-from", default="port", choices=["case", "port"])
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    out = WORK / f"gcase_{a.game}_{a.case}{('_' + a.tag) if a.tag else ''}"
    code = run_port(a.game, a.case, case_keys(a.game, a.case, a.keys_from), out)
    if code != 0:
        print(f"COULD-NOT-RUN: the port's run failed ({code})")
        return 2
    k, note, n = score(a.game, a.case, out)
    print(f"{a.game} {a.case}: {k} of {n} pictures ({note})")
    return 0 if k >= n - 1 else 1


if __name__ == "__main__":
    sys.exit(main())
