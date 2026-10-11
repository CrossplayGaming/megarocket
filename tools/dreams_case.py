# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""REPLAY-D's measure for one recorded Keen Dreams session: runs the Dreams port (godot/tests/drm_boot.gd)
with the session's keys and holds its pictures, with their durations, against the recording
<game>_<case>_a (tools/record_dreams.py).

The case's held keys are seconds after the recording's first frame. The runner starts recording once
DOSBox reports the EGA mode, a couple of seconds into the title (F8 and its confirmation), so the port
times the keys from its own first EGA picture (drm_boot's --case_keys) plus `start`, the time from
there to the recording's first frame: measured from the run (the port's refreshes up to the
recording's first whole picture, less the recording's frames before it) and kept in
tools/cases/<game>/<case>.port.json; when the measure differs from the start used, the port runs
again with it. The start-up screens before the EGA mode get the port's own keys (drm_boot's RELEASES),
as the recording's get the runner's.

    python tools/dreams_case.py kdreams level05 [--tag NAME] [--show N]
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import common
import frames
import timing_score
from galaxy_case import SCANCODES

ROOT = Path(__file__).resolve().parent.parent
CASES = Path(__file__).parent / "cases"
WORK = Path("F:/KeenReworkWork/port_runs")


# The time from the first EGA picture to the recording's first frame when it cannot be measured (v1.93's
# title is one picture until a key): the runner's, as measured on v1.00's scrolling title
DEFAULT_START = 0.3
# A first whole picture held longer than this (refreshes) is waiting on a key: no measure of the start
MEASURE_MAX = 70
REFRESH_HZ = 70.086


def _port_spec(game, case):
    port = CASES / game / f"{case}.port.json"
    return json.loads(port.read_text(encoding="utf-8")) if port.exists() else {}


def case_start(game, case):
    return float(_port_spec(game, case).get("start", DEFAULT_START))


def case_keys(game, case, source="port"):
    """The session's keys: fitted (.port.json "keys", the moments the original saw them) or the case's."""
    fitted = _port_spec(game, case).get("keys")
    if source == "port" and fitted:
        return [list(k) for k in fitted]
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
    return [list(k) for k in spec["held"]]


def case_tc_adds(game, case):
    """HARN-21: [[seconds from the first EGA picture, tics added to TimeCount], ...] (fitted)."""
    return [list(x) for x in _port_spec(game, case).get("tc_adds", [])]


def case_clock(game, case):
    """The DOS clock at the program's start, microseconds (fitted; -1: the port's own seed)."""
    return int(_port_spec(game, case).get("clock", -1))


def measured_start(game, case, out):
    """Seconds from the port's first EGA picture to the recording's first frame, or None."""
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    oseq = frames.Sequence(oracle / "frames")
    lead = oseq.repeats(0)        # the recording's frames of its first (partial) picture
    if len(oseq) < 2 or oseq.repeats(1) > MEASURE_MAX:
        return None
    first = oseq.digest(1)
    pseq = frames.Sequence(Path(out) / game)
    at = 0
    for i in range(len(pseq)):
        if pseq.digest(i) == first and i > 0 and pseq.digest(i - 1) == oseq.digest(0):
            return (at - lead) / REFRESH_HZ
        at += pseq.repeats(i)
    return None


# HARN-22: the seconds from KEYFEED.COM's loading to the program's start, per release. KEYFEED's start-up
# Enter taps (every PRE_PERIOD + PRE_HOLD ticks from its loading, tools/keyfeed.py) answer the start-up
# screens, and the runner's autoexec sets the DOS clock to 00:00:00 just before it loads, so this one
# time places the taps, the game clock's start (SD_Startup) against the key timetable, and the random
# table's seed (the hundredths at US_Startup). Measured on the recordings' text-mode captures (video0001:
# v1.00's piracy screen at frame 4, the first tap's text screen at frame 104, 1.427 s on; v1.93's text
# screen at frame 3-4, the mode set at frame 104-105), less the port's first display (0.014 s): about
# 0.06 s, give or take a frame. Within that the value is fitted on the pictures matched in all (2.5 ms
# steps from 0.045 to 0.075 s; the outcome swings with it, which frame a key or the mode set falls in),
# with the costs of dreams_costs.json: fit it again when they change.
FEED_PRE = {"kdreams": 0.05, "kdreams193": 0.045}
# SCR-01: microseconds the original's start-up spends before SD_Startup (which stops the DOS clock: the random
# table's seed is its hundredths then) that the port does not charge, so the seed's clock runs this much later
# than feed_pre's. v1.93: one BIOS tick (the seed is the next tick's hundredths); found on King Boobus Tuber's
# pauses at a wall (US_RndT; kdreams193 scr_gameover matched 54 of 68 pictures after its third load with the
# clock at 0.045 s, all 68 from 0.070 to 0.100 s, 64 at 0.125 s: the tick starts between 0.045 and 0.070 s),
# set in the middle of the tick (0.085 s), and confirmed on REPLAY-D's sessions: 2887 -> 3104 of v1.93's
# pictures matched (level09 all 567, level12 174 -> 218, level14 166 -> 179, level15 173 -> 292), none
# fewer. v1.00's seed is right as it is (REPLAY-D level10's squasher; SCR-01's v1.00 cases).
START_LAG = {"kdreams193": 40000}
COSTS = Path(__file__).resolve().parent.parent / "godot" / "data" / "dreams_costs.json"    # (the game's own copy: the host reads it)


def feed_pre(game, case=None):
    """Seconds from KEYFEED.COM's loading to the program's start: the case's "feed_pre", else the release's."""
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8")) if case else {}
    return float(spec.get("feed_pre", FEED_PRE.get(game, 0.0)))


def feed_clock(game, case=None):
    """The DOS clock at the program's start, microseconds: the case's fitted "clock" (a random draw that
    decides a stop, with how it was found in "clock_note"), else the runner's 00:00:00 at KEYFEED's loading
    plus feed_pre and the release's START_LAG."""
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8")) if case else {}
    return int(spec.get("clock", round(feed_pre(game, case) * 1e6) + START_LAG.get(game, 0)))


def calibrated_costs(game=None):
    """TIME-D's fitted costs (tools/calibrate_dreams.py), as drm_boot's --costs argument ("" if none): the
    shared ones, with the release's own where it has them (by_game: v1.93's loads differ from v1.00's)."""
    if not COSTS.exists():
        return ""
    doc = json.loads(COSTS.read_text(encoding="utf-8"))
    costs = {**doc["costs"], **doc.get("by_game", {}).get(game, {})}
    return ",".join(f"{k}:{int(v)}" for k, v in sorted(costs.items()) if int(v))


def run_feed(game, held, out, seconds, extra=(), clock=None, case=None, pre=None):
    """HARN-22: drm_boot for the one release with KEYFEED.COM's timetable (`held`: seconds after the EGA
    mode set, tools/keyfeed.py's ticks) and its start-up taps, frames to `out`. `clock` and `pre` default
    to the case's (feed_clock, feed_pre)."""
    import keyfeed
    arg = ",".join(f"{m}:{c}:{b}" for m, c, b in keyfeed.feed_pairs(held))
    pre = feed_pre(game, case) if pre is None else pre
    clock = feed_clock(game, case) if clock is None else clock
    shutil.rmtree(out, ignore_errors=True)
    p = subprocess.run([sys.executable, "tools/gdtest.py", "drm_boot", "--", f"--only={game}", f"--seconds={seconds}",
                        f"--out={Path(out).as_posix()}", f"--feed_keys={arg}", f"--feed_pre={pre}", f"--clock={clock}",
                        f"--tsr_paras={keyfeed.dos_paragraphs(held)}", *extra],
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout + p.stderr


# the port runs this much past a case's "seconds": the start-up ahead of the recording's first picture
# and the recording's own tail (v1.00 level15's recording runs to 62 s of a 37.2 s case)
PORT_MARGIN = 26


def run_port(game, case, keys, out, seconds=None, extra=(), start=None, clock=None, tc_adds=None):
    """drm_boot for the one release, frames to `out` (its release folder inside)."""
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
    if spec.get("keyfeed"):
        # HARN-22: the keys are the case's own timetable, typed into the original inside DOS
        # with the calibrated costs, as tools/calibrate_dreams.py scores it
        costs = calibrated_costs(game)
        if costs and not any(str(x).startswith("--costs=") for x in extra):
            extra = (f"--costs={costs}", *extra)
        # (the runner sets the DOS clock: no "port's own seed" here, -1 is the case's)
        return run_feed(game, keys, out, seconds or spec["seconds"] + PORT_MARGIN, extra,
                        None if clock is None or clock < 0 else clock, case)
    start = case_start(game, case) if start is None else start
    tc_adds = case_tc_adds(game, case) if tc_adds is None else tc_adds
    if tc_adds:
        extra = (f"--tc_adds={','.join(f'{t:.4f}:{n}' for t, n in tc_adds)}", *extra)
    clock = case_clock(game, case) if clock is None else clock
    spec = json.loads((CASES / game / f"{case}.json").read_text(encoding="utf-8"))
    # the port's start-up (text screen, keys, mode set) runs ahead of the recording's first picture
    secs = seconds or spec["seconds"] + PORT_MARGIN
    keyarg = ",".join(f"{t + start:.4f}:{SCANCODES[k]}:{h}" for t, k, h in keys)
    shutil.rmtree(out, ignore_errors=True)
    p = subprocess.run([sys.executable, "tools/gdtest.py", "drm_boot", "--", f"--only={game}", f"--seconds={secs}",
                        f"--out={Path(out).as_posix()}", f"--case_keys={keyarg}", f"--clock={clock}", *extra],
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout + p.stderr


# Runs of pictures one side shows and the other does not are passed when each lasts at most this many
# refreshes and there are at most SKIP_MAX of them: the original's work in progress on screen (a
# loading box drawn, its text, the bar's steps, text being printed) that the port, whose loads and
# drawing take no time yet (TIME-D), does at once (SKIP_ORACLE), and the port's own (SKIP_PORT): a
# load finished within one refresh, caught half drawn by the beam. The port's pictures in play last at
# least two refreshes (MINTICS; its drawing takes no time), so a one-refresh picture of the port is
# never a frame of play, and a different frame of play is never passed. Every pass is reported.
SKIP_ORACLE = 6
SKIP_PORT = 1
SKIP_MAX = 16


def level_score(port, orc):
    """REPLAY-D's measure: (j, note, n, load_error, skips, k): j the recording's picture reached, k the port's.

    The pictures must follow the recording's in order; each lasts as long as the recording's, give or take
    a refresh (counted as slips). Where the original shows its work in
    progress (SKIP_ORACLE, SKIP_PORT, SKIP_MAX) the extra pictures are passed
    and the next picture's duration is free (it absorbs the load's time); the time so absorbed is summed
    as the load error, reported, not failed (J-20: loading time the player cannot tell apart)."""
    n = len(orc) - 1                      # the recording's last picture is partial
    k = j = 0
    slips, skips, load_err, free = [], [], 0, False

    def resync(k, j):
        for total in range(1, SKIP_MAX + 1):
            for a in range(total + 1):
                b = total - a
                if k + a >= len(port) or j + b >= n:
                    continue
                if port[k + a][0] != orc[j + b][0]:
                    continue
                if all(port[k + x][1] <= SKIP_PORT for x in range(a)) and \
                        all(orc[j + x][1] <= SKIP_ORACLE for x in range(b)):
                    return a, b
        return None

    while j < n:
        if k >= len(port):
            return j, f"the port's run ends at picture {j}" + timing_score._slips(slips), n, load_err, skips, k
        if port[k][0] != orc[j][0]:
            r = resync(k, j)
            if r is None:
                return j, f"picture {j} differs" + timing_score._slips(slips), n, load_err, skips, k
            a, b = r
            skips.append((j, a, b, k))
            load_err += abs(sum(p[1] for p in port[k:k + a]) - sum(o[1] for o in orc[j:j + b]))
            k += a
            j += b
            free = True
            continue
        if free:
            load_err += abs(port[k][1] - orc[j][1])
            free = False
        else:
            # a picture may last one refresh more or less than the recording's: the original's frame or
            # load took that much longer or shorter, a timing the port does not model to the refresh
            # (J-20); everything after is compared from there. A difference in play shows as a different
            # picture (the game's motion follows its tics), so this passes no different play.
            d = port[k][1] - orc[j][1]
            if d:
                slips.append(j)
            if abs(d) > 1:
                return j, f"picture {j} lasts {port[k][1]} refreshes in the port, {orc[j][1]} in the recording" +                     timing_score._slips(slips), n, load_err, skips, k
        k += 1
        j += 1
    return n, f"all {n} pictures match" + timing_score._slips(slips), n, load_err, skips, k


def align(port, orc, lead=4):
    """The port's pictures from the recording's first whole one, and the recording's from there: when the
    recording opens on a picture of the original's drawing in progress (v1.93's title half drawn), up to
    `lead` such pictures are left out. ([], orc) when none is found."""
    for i in range(min(lead + 1, len(orc))):
        start = next((n for n, (d, _) in enumerate(port) if d == orc[i][0]), None)
        if start is not None:
            return port[start:], orc[i:]
    return [], orc


def score(game, case, out):
    """(j, note, n, port, orc, k): the port's pictures from the recording's first whole one, scored."""
    oracle = Path(common.config()["oracle_runs"]) / f"{game}_{case}_a"
    port = timing_score.pictures(frames.Sequence(Path(out) / game), False)
    orc = timing_score.pictures(frames.Sequence(oracle / "frames"), True)
    port, orc = align(port, orc)
    if not port:
        return 0, "the recording's first pictures are not in the port's run", len(orc) - 1, port, orc, 0
    j, note, n, load_err, skips, k = level_score(port, orc)
    score.skips = skips    # (recording picture, port's extras, recording's extras, port picture) per pass
    if skips:
        note += f"; {len(skips)} runs of work in progress passed (at {[s[0] for s in skips[:6]]}), loads {load_err} refreshes off in all"
    return j, note, n, port, orc, k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--tag", default="")
    ap.add_argument("--show", type=int, default=0, help="pictures to list around the first difference")
    ap.add_argument("--no-run", action="store_true", help="score the last run again")
    ap.add_argument("--keys-from", default="port", choices=["case", "port"])
    a = ap.parse_args()
    out = WORK / f"dcase_{a.game}_{a.case}{('_' + a.tag) if a.tag else ''}"
    if not a.no_run:
        start = case_start(a.game, a.case)
        for _attempt in range(2):
            code, log = run_port(a.game, a.case, case_keys(a.game, a.case, a.keys_from), out, start=start)
            if not (out / a.game / "frames.json").exists():
                print(f"COULD-NOT-RUN: the port's run failed ({code})\n{log[-2000:]}")
                return 2
            keyfed = json.loads((CASES / a.game / f"{a.case}.json").read_text(encoding="utf-8")).get("keyfeed")
            got = None if keyfed else measured_start(a.game, a.case, out)    # (HARN-22: no start to measure)
            if got is None or abs(got - start) < 0.5 / REFRESH_HZ:
                break
            print(f"  the recording starts {got:.3f} s after the first EGA picture (ran with {start:.3f}): again")
            start = got
            spec = _port_spec(a.game, a.case)
            spec["start"] = round(got, 4)
            (CASES / a.game / f"{a.case}.port.json").write_text(json.dumps(spec, indent=1) + "\n", encoding="utf-8")
    j, note, n, port, orc, k = score(a.game, a.case, out)
    print(f"{a.game} {a.case}: {j} of {n} pictures ({note})")
    if a.show:
        tp = sum(r for _, r in port[:max(k - a.show, 0)])
        to = sum(r for _, r in orc[:max(j - a.show, 0)])
        for x in range(-min(a.show, k, j), a.show):
            p = port[k + x] if k + x < len(port) else None
            o = orc[j + x] if j + x < len(orc) else None
            mark = " " if p and o and p == o else "*"
            print(f"{mark} {k + x:4d}  port {p[0][:6] if p else '------'} x{p[1] if p else 0:<3d} @{tp/REFRESH_HZ:8.3f}   "
                  f"{j + x:4d}  oracle {o[0][:6] if o else '------'} x{o[1] if o else 0:<3d} @{to/REFRESH_HZ:8.3f}")
            tp += p[1] if p else 0
            to += o[1] if o else 0
    return 0 if j >= n else 1


if __name__ == "__main__":
    sys.exit(main())
