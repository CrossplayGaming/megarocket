# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""HARN-06: screen cases. A case drives the original (in DOSBox) and the port to the same screens with the
same keys, and holds the pictures each one showed against the other's, by content. How to write one:
docs/notes/SCREEN_CASES.md.

Both sides take the keys on one timetable, seconds after the EGA mode set: KEYFEED.COM types them into the
original inside DOS (HARN-22, tools/keyfeed.py), and the port's runner (simv01_boot, simg_boot, drm_boot
--feed_keys) puts them at the same moments after its own mode set. The port is exact, so a timetable that
reaches a screen in the port reaches it in the original: design a case in the port first (`port`).

A case is tools/cases/<game>/scr_<name>.json:

    {"seconds": 30,                            compared up to this long after the mode set (keys: 64 s at most)
     "keyfeed": true,                          (always: oracle_run.py then types "held" with KEYFEED.COM too)
     "held": [[4.0, "enter", 0.2], ...],       seconds after the mode set, key (keyfeed.SCANCODES), seconds down
     "screens": [[0, "title"], [4.0, "main menu"], ...],   what is on show from when: the report's sections
     "masks": [{"rect": [0, 131, 320, 200], "reason": "why", "from": 0, "to": 4.0}],   blanked on both sides
                                               (x0, y0, x1, y1, the last row and column not included; "from"
                                               and "to", seconds on each side's own clock, optional)
     "text_masks": [{"cells": [15, 60, 16, 70], "reason": "why"}],   text cells left out (row0, col0, row1, col1)
     "sequences": [{"from": 65, "to": 81, "reason": "why"}],   S6's spans (optional)
     "args": "/TEDLEVEL 3",                    the program's command line (optional)
     "overrides": "tools/cases/keen1/saves/x", a folder of files put beside the original's program and in the
                                               port's save folder: saves from the port's own writers, config
                                               files (optional; repository-relative or absolute)
     "may_exit": false,                        the program quits before the end (its text screen is compared)
     "settled": 4, "least": 2, "stay": 12,     (optional: see below)
     "port": {"clock": 0},                     (optional: more options for the port's runner, --name=value)
     "note": "what the case does"}

The comparison (the Duke project's S1-S4, adapted). Each side's pictures, masks applied, cut at "seconds";
pictures alike after masking run together. A picture is SETTLED when it stays up `settled` refreshes or
more (default 4); the first never is (cut by the recording's start), the last only when it is up to the
cut FINAL_SETTLED refreshes (a second) or more: the screen a case ends on (Keen 1's end text).

  S1  every settled picture of the port is a picture the original showed;
  S2  every settled picture of the original is one the port showed;
  S3  each side shows at least `least` different settled pictures (default: one per named screen);
  S4  a settled picture the original shows in one stretch (a screen that stays up, not an animation's
      returning frame) is up about as long in the port. A screen a key ends (a key goes down or up while it
      is up: the two machines read a key up to a few refreshes, or a loop's step, apart): its time in all
      within `stay` refreshes (default 12) and 5%. A screen no key ends (a box up while the program works,
      a timed screen): its longest stretch in the port within half its time, never under 2 refreshes, nor
      over the first allowance (a box the original holds 4 refreshes: 2-6 in the port). The case's
      "stay": null leaves S4 out;
  S5  order: a picture that one side showed only after another was gone, the other shows after it too;
  S6  in the case's "sequences" (a timed animation no key steers: the ordering screen's walker), every
      picture of each side that starts in the span, however short, the same and in the same order.

A failure is reported under the named screen the picture is up longest in (a picture that comes a few
milliseconds before a screen's named start is that screen's), with the nearest picture of the other side
(its index, the box of the pixels that differ and their count) and a picture of the three (this, nearest,
differences) under the work folder, F:/KeenReworkWork/port_runs/screen_<game>_<case>[_tag]/diff.

Text-mode screens (Keen Dreams' start screens, a program's exit screen) are drawn by the shell in
Megarocket's own font, so they are compared by their 80x25 cells (J-38: identical when every cell holds the
same character in the same colours). Each recorded cell is read as a character by its shape, learnt each run
from the recordings of Keen 1-3's exit screens, whose characters the programs themselves name (glyphs(),
GLYPH_SOURCES; DOSBox's font is never kept in the repository); a character those screens do not show must
have one shape in all its cells, none a known character's. Each cell's colours are its attribute's
(blinking cells all shown or all hidden). The hardware cursor, where the recording shows it, is where the
port's runner puts it; once the program has quit, DOS's prompt (left out, cursor and all) is on the row below
the port's exit cursor (the screen scrolled a row when that is the last). Every settled text picture of the
recording (TEXT_SETTLED) is one of the port's screens, in order, and the reverse; the recording's pictures
before the first that is the port's, and after the last once the program has quit, are DOS's own.

    python tools/screen_case.py list [game ...]
    python tools/screen_case.py port <game> <case> [--tag T] [--keep DIR]   the port alone: a sheet to design by
    python tools/screen_case.py record <game> <case> [--run a|b]            the original, into oracle_runs
    python tools/screen_case.py check <game> <case> [--run a] [--tag T] [--no-run] [--all]
    python tools/screen_case.py pair <game> <case>                          run a against run b (HARN-06a)
    python tools/screen_case.py selftest <game> <case> [--tag T]            planted faults must be reported

Cannot catch: a difference on a picture neither side keeps up `settled` refreshes (outside "sequences");
anything under a mask; in text screens, a character the exit screens of Keen 1-3 do not show, put by the
port where the original has another such character that appears nowhere else on the screen; the column of
an exit screen's cursor (DOS starts its prompt at column 0 whatever it is); a cursor the original hides.
"""
import argparse
import hashlib
import json
import shutil
import sys
import threading
from pathlib import Path

import numpy as np

import common
import frames
import keyfeed

CASES = Path(__file__).parent / "cases"
WORK = Path("F:/KeenReworkWork/port_runs")
REFRESH_HZ = 70.086
SETTLED = 4             # refreshes a picture stays up to count (harn01a's held pictures)
FINAL_SETTLED = 70      # refreshes (a second) the last picture must be up to the cut to count: a screen the case
                        # ends on, not one that came a few refreshes before the cut on one side only
STAY = 12               # S4: refreshes, plus STAY_SHARE of the original's time, at most;
STAY_SHARE = 0.05
STAY_PART = 0.5         # and at most this share of the original's time, but never under STAY_FLOOR refreshes
STAY_FLOOR = 2          # (a box the original holds 4 refreshes may be up 2-6 in the port, not 1)
KEY_LAG = 2 / REFRESH_HZ  # S4: a key this long or more after a picture came can be what ends it
NEAR = 3.0              # seconds either side searched for the nearest picture of the other side
PORT_EXTRA = 8.0        # seconds the port runs past "seconds" from its start (its start-up comes first)
PRE_SECONDS = 12        # the recording's seconds before the game's start-up is done (oracle_run pre_seconds)
TEXT_SETTLED = 10       # refreshes a text picture stays up to count (the original's start screens are drawn
                        # in steps up 6-8 refreshes each as its hardware checks finish; the cursor blinks
                        # every 16)
GALAXY_CLOCK_US = 42000  # SCR-01G: the DOS clock as Keen 4-6 start in a key-fed recording (the runner sets
                        # 00:00:00 just before; DOS then loads the program): US_InitRndT(true) takes its
                        # hundredths, and Paddle War's serves follow them. keen4/5/6 scr_paddle agree point for
                        # point from 30000 to 54925 microseconds on all three, at 0 only to the second point


# ------------------------------------------------------------------ cases

def case_name(case):
    return case if case.startswith("scr_") else f"scr_{case}"


def load(game, case):
    """The case, defaults filled in; None if there is no such file."""
    path = CASES / game / f"{case_name(case)}.json"
    if not path.exists():
        return None
    spec = json.loads(path.read_text(encoding="utf-8"))
    spec.setdefault("held", [])
    spec.setdefault("args", "")
    spec.setdefault("overrides", None)
    spec.setdefault("may_exit", False)
    spec.setdefault("masks", [])
    spec.setdefault("screens", [])
    spec.setdefault("settled", SETTLED)
    spec.setdefault("least", max(1, len(spec["screens"])))
    spec.setdefault("stay", STAY)
    spec.setdefault("port", {})
    spec.setdefault("sequences", [])
    for q in spec["sequences"]:
        if not q.get("reason"):
            raise ValueError(f"{path.name}: a sequence without a reason")
    for m in spec["masks"]:
        m.setdefault("from", 0.0)
        m.setdefault("to", 1e9)
        if not m.get("reason"):
            raise ValueError(f"{path.name}: a mask without a reason")
    spec["screens"] = sorted([float(t), str(n)] for t, n in spec["screens"])
    # KEYFEED.COM counts 1024 ticks a second in 16 bits: every key must be up again within 64 s
    late = [k for k in spec["held"] if (k[0] + k[2]) * 1024 >= 0xFFFF]
    if late:
        raise ValueError(f"{path.name}: keys after 64 s, which KEYFEED.COM cannot time: {late}")
    for k in spec["held"]:
        if k[1] not in keyfeed.SCANCODES:
            raise ValueError(f"{path.name}: no key named {k[1]!r} (tools/keyfeed.py SCANCODES)")
    return spec


def cases(game):
    return sorted(p.stem for p in (CASES / game).glob("scr_*.json"))


def overrides_dir(spec):
    return (common.ROOT / spec["overrides"]).resolve() if spec["overrides"] else None


def run_name(game, case, run="a"):
    return f"{game}_{case_name(case)}_{run}"


def work_dir(game, case, tag=""):
    return WORK / f"screen_{game}_{case_name(case)}{('_' + tag) if tag else ''}"


# ------------------------------------------------------------------ the two sides

def record(game, case, run="a", show=False):
    """The original, key-fed, into oracle_runs/<game>_<case>_<run>, decoded. Returns an exit code."""
    import oracle_decode
    import oracle_run
    spec = load(game, case)
    if spec is None:
        print(f"COULD-NOT-RUN: no case tools/cases/{game}/{case_name(case)}.json")
        return common.COULD_NOT_RUN
    seed = overrides_dir(spec)
    ospec = {"seconds": spec["seconds"] + 2, "keys": "", "held": spec["held"], "keyfeed": True,
             "pre_seconds": PRE_SECONDS, "args": spec["args"], "may_exit": spec["may_exit"],
             "hold_exit": spec["may_exit"],
             "overrides": str(seed) if seed else None, "cycles": spec.get("cycles", oracle_run.DEFAULT_CYCLES)}
    name = run_name(game, case, run)
    code, _ = oracle_run.run(game, case_name(case), run_name=name, show=show, spec=ospec)
    if code != common.PASS:
        return code
    return oracle_decode.decode(name)


def run_port(game, case, out, say=print, keep=None, more=None, spec=None, seconds=None):
    """The port's runner with the case's timetable, frames to `out`; `keep`: a folder the player's files the
    program writes are kept in (a saved game for another case's overrides); `more`: further options for the
    runner ({name: value}: REND-01R's compare_lists); `spec`: the case as given (its keys changed:
    tools/steady_keys.py) instead of its file; `seconds`: the run cut there. Returns (code, frames folder,
    text screens file)."""
    import gdtest
    spec = spec or load(game, case)
    engine = common.game(game)["engine"]
    feed = ",".join(f"{m}:{c}:{b}" for m, c, b in keyfeed.feed_pairs(spec["held"]))
    shutil.rmtree(out, ignore_errors=True)
    seconds = seconds if seconds is not None else spec["seconds"] + PORT_EXTRA
    args = [f"--seconds={seconds}", f"--out={Path(out).as_posix()}", f"--feed_keys={feed}"]
    seed = overrides_dir(spec)
    if seed:
        args.append(f"--save_seed={seed.as_posix()}")
    if spec["may_exit"]:
        args.append("--may_exit=1")
    if keep:
        Path(keep).mkdir(parents=True, exist_ok=True)
        args.append(f"--save={Path(keep).resolve().as_posix()}")
    extra = dict(spec["port"])
    extra.update(more or {})
    if engine == "vorticons":
        test, folder = "simv01_boot", Path(out)
        args.append(f"--game={game}")
    elif engine == "galaxy":
        test, folder = "simg_boot", Path(out)
        args += [f"--game={game}", f"--args={spec['args']}"]
        extra.setdefault("clock", GALAXY_CLOCK_US)
    else:
        import dreams_case
        test, folder = "drm_boot", Path(out) / game
        args.append(f"--only={game}")
        # KEYFEED's start-up taps, the DOS clock and TIME-D's costs, as REPLAY-D's sessions run
        extra.setdefault("feed_pre", dreams_case.feed_pre(game, case_name(case)))
        extra.setdefault("clock", dreams_case.feed_clock(game, case_name(case)))
        # KEYFEED.COM's DOS memory, which the program does not get (v1.00's start screen shows it)
        extra.setdefault("tsr_paras", keyfeed.dos_paragraphs(spec["held"]))
        costs = dreams_case.calibrated_costs(game)
        if costs:
            extra.setdefault("costs", costs)
    args += [f"--{k}={v}" for k, v in extra.items()]
    code, text = gdtest.run(test, args, timeout=900.0, quiet=True)
    if not (folder / "frames.json").exists():
        tail = "\n".join(text.splitlines()[-8:])
        say(f"COULD-NOT-RUN: the port's run wrote no pictures ({common.NAMES[code]})\n{tail}")
        return common.COULD_NOT_RUN, None, None
    for line in text.splitlines():
        if "FAIL" in line or "mode 0Dh" in line or "quit" in line:
            say("  port: " + line.strip())
    tf = folder / "text_frames.json"
    return code, folder, tf if tf.exists() else None


# ------------------------------------------------------------------ the pictures as compared

class Entry:
    """One picture as the comparison sees it: digest (masks applied), refreshes up, the sequence's index of
    its first raw picture, its start (seconds after the mode set), the masks applied."""

    def __init__(self, view, digest, reps, index, at, masks):
        self.view, self.digest, self.reps, self.index, self.at, self.masks = view, digest, reps, index, at, masks
        self.plant = None       # selftest: a pixel turned to its opposite

    def frame(self):
        picture = self.view.seq.frame(self.index)
        if self.masks or self.plant:
            picture = picture.copy()
            for m in self.masks:
                x0, y0, x1, y1 = m["rect"]
                picture[y0:y1, x0:x1] = 0
            if self.plant:
                x, y = self.plant
                picture[y, x] = 255 - picture[y, x]
        return picture


class View:
    """A frame sequence cut at `seconds` after its first picture, `masks` blanked, alike pictures run together."""

    def __init__(self, seq, masks, seconds, side):
        self.seq, self.side = seq, side
        self.entries = []
        end = int(round(seconds * REFRESH_HZ))
        at = 0
        for i in range(len(seq)):
            if at >= end:
                break
            reps = min(seq.repeats(i), end - at)
            t = at / REFRESH_HZ
            active = [m for m in masks if m["from"] <= t < m["to"]]
            if active:
                picture = seq.frame(i).copy()
                for m in active:
                    x0, y0, x1, y1 = m["rect"]
                    picture[y0:y1, x0:x1] = 0
                digest = hashlib.sha1(picture.tobytes()).hexdigest()
            else:
                digest = seq.digest(i)
            if self.entries and self.entries[-1].digest == digest:
                self.entries[-1].reps += reps
            else:
                self.entries.append(Entry(self, digest, reps, i, t, active))
            at += seq.repeats(i)
        self.refreshes = min(at, end)

    def settled(self, least):
        """The settled entries' positions: the first left out (cut by the recording's start), the last only
        when it is up FINAL_SETTLED refreshes or more to the cut (a screen the case ends on: Keen 1's end text)."""
        last = len(self.entries) - 1
        out = [k for k in range(1, last) if self.entries[k].reps >= least]
        if last >= 1 and self.entries[last].reps >= max(least, FINAL_SETTLED):
            out.append(last)
        return out


def screen_of(spec, t, reps=0):
    """The named screen a picture shown from `t` for `reps` refreshes is filed under: the one it is up longest
    in (a picture that comes a few milliseconds before a screen's named start is that screen's), or with no
    `reps` the one `t` falls in."""
    name = "(before the first named screen)"
    if reps <= 0 or not spec["screens"]:
        for start, n in spec["screens"]:
            if t + 1e-9 >= start:
                name = n
        return name
    end = t + reps / REFRESH_HZ
    starts = spec["screens"]
    best = min(end, starts[0][0]) - t
    for i, (start, n) in enumerate(starts):
        stop = starts[i + 1][0] if i + 1 < len(starts) else float("inf")
        overlap = min(end, stop) - max(t, start)
        if overlap > best + 1e-9:
            name, best = n, overlap
    return name


def entry_screen(spec, e):
    return screen_of(spec, e.at, e.reps)


def _diff(a, b):
    """(pixels that differ, box (x0, y0, x1, y1) or None) between two pictures."""
    d = np.any(a != b, axis=2)
    n = int(d.sum())
    if not n:
        return 0, None
    ys, xs = np.nonzero(d)
    return n, (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def nearest(entry, other):
    """The entry of `other` nearest in content to `entry` among those within NEAR seconds (all if none):
    (position, pixels that differ, box)."""
    picture = entry.frame()
    pool = [k for k, e in enumerate(other.entries) if abs(e.at - entry.at) <= NEAR] or range(len(other.entries))
    best = None
    for k in pool:
        n, box = _diff(picture, other.entries[k].frame())
        if best is None or n < best[1]:
            best = (k, n, box)
    return best


def save_diff(entry, other_entry, path):
    from PIL import Image
    a, b = entry.frame(), other_entry.frame()
    marked = b.copy()
    marked[np.any(a != b, axis=2)] = (255, 0, 255)
    sheet = np.concatenate([a, b, marked], axis=1)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).resize((sheet.shape[1] * 2, sheet.shape[0] * 2), Image.NEAREST).save(path)


def _empty(picture):
    return bool((picture == picture[0, 0]).all())


def compare(spec, port, orig, out_dir=None):
    """The content rules over two views. Returns [failure], each {rule, screen, at, text, detail}."""
    least = spec["settled"]
    fails = []
    pd = [e.digest for e in port.entries]
    od = [e.digest for e in orig.entries]
    pset, oset = set(pd), set(od)
    ps, os_ = port.settled(least), orig.settled(least)

    def where(side, k):
        e = side.entries[k]
        return f"{side.side}'s picture {k} at {e.at:.2f} s, up {e.reps} refreshes"

    def explain(side, k, other, tag):
        e = side.entries[k]
        near = nearest(e, other)
        if near is None:
            return f"the {other.side} shows nothing to set it against"
        j, n, box = near
        text = f"nearest: the {other.side}'s picture {j} at {other.entries[j].at:.2f} s, {n} pixels differ"
        if box:
            text += f" in ({box[0]},{box[1]})-({box[2]},{box[3]})"
        if out_dir is not None:
            path = Path(out_dir) / f"{tag}.png"
            save_diff(e, other.entries[j], path)
            text += f"; picture ({side.side}, {other.side}, differences): {path}"
        return text

    for k in ps:
        if pd[k] not in oset:
            e = port.entries[k]
            fails.append({"rule": "S1", "screen": entry_screen(spec, e), "at": e.at,
                          "text": f"S1: the {where(port, k)}, is one the original never showed",
                          "detail": lambda k=k: explain(port, k, orig, f"S1_port{k}")})
    for k in os_:
        if od[k] not in pset:
            e = orig.entries[k]
            fails.append({"rule": "S2", "screen": entry_screen(spec, e), "at": e.at,
                          "text": f"S2: the {where(orig, k)}, never shows in the port",
                          "detail": lambda k=k: explain(orig, k, port, f"S2_original{k}")})
    for side, sett in ((port, ps), (orig, os_)):
        distinct = len({side.entries[k].digest for k in sett})
        if distinct < spec["least"]:
            fails.append({"rule": "S3", "screen": "(the whole case)", "at": 0.0,
                          "text": f"S3: the {side.side} shows {distinct} different settled pictures; at least "
                                  f"{spec['least']} expected", "detail": None})
    # S4: time on show, for the original's settled pictures that it shows in one stretch (a screen that
    # stays up; not an animation's recurring frame, whose count of returns rests on timing, nor an empty
    # screen: a load's). A screen a key ends: the port's time in all; one no key ends: its longest stretch
    if spec["stay"] is not None:
        ot, pt, pmax, stretches = {}, {}, {}, {}
        for e in orig.entries:
            ot[e.digest] = ot.get(e.digest, 0) + e.reps
            stretches[e.digest] = stretches.get(e.digest, 0) + 1
        for e in port.entries:
            pt[e.digest] = pt.get(e.digest, 0) + e.reps
            pmax[e.digest] = max(pmax.get(e.digest, 0), e.reps)
        ends = {od[0], od[-1], pd[0], pd[-1]}
        for k in os_:
            d = od[k]
            if stretches[d] > 1 or d in ends or d not in pt or _empty(orig.entries[k].frame()):
                continue
            e = orig.entries[k]
            keyed = key_while(spec, e)
            tol = stay_tolerance(spec, ot[d], keyed)
            got = pt[d] if keyed else pmax[d]
            if abs(ot[d] - got) > tol:
                fails.append({"rule": "S4", "screen": entry_screen(spec, e), "at": e.at,
                              "text": f"S4: the {where(orig, k)}, is up {ot[d]} refreshes in the original, "
                                      + (f"{got} in all in the port (at most {tol:.1f} apart: a key ends it)" if keyed
                                         else f"{got} at the longest in the port (at most {tol:.1f} apart: no key "
                                              f"ends it)"), "detail": None})
    # S5: order. [first, last] position of each picture on each side; a pair one side shows strictly one
    # after the other must not come strictly the other way round on the other side
    def spans(entries):
        s = {}
        for k, e in enumerate(entries):
            s.setdefault(e.digest, [k, k])[1] = k
        return s
    sp, so = spans(port.entries), spans(orig.entries)
    # the pictures settled on either side and shown on both, in order of first showing (a dict keeps it)
    common_settled = list(dict.fromkeys([pd[k] for k in ps if pd[k] in so] + [od[k] for k in os_ if od[k] in sp]))
    reported = set()
    for x in common_settled:
        for y in common_settled:
            if x == y or (y, x) in reported:
                continue
            if so[x][1] < so[y][0] and sp[y][1] < sp[x][0]:
                reported.add((x, y))
                e = orig.entries[so[y][0]]
                fails.append({"rule": "S5", "screen": entry_screen(spec, e), "at": e.at,
                              "text": f"S5: the original shows its picture {so[x][0]} ({orig.entries[so[x][0]].at:.2f} s) "
                                      f"before its picture {so[y][0]} ({e.at:.2f} s); the port shows them the other way "
                                      f"round (its {sp[y][0]} at {port.entries[sp[y][0]].at:.2f} s, then its "
                                      f"{sp[x][0]} at {port.entries[sp[x][0]].at:.2f} s)", "detail": None})
    # S6: in the case's "sequences" (a timed animation no key steers: the ordering screen's walker), every
    # picture, however short, in the same order on both sides
    for span in spec["sequences"]:
        f0, f1 = span["from"], span["to"]
        ko = [k for k, e in enumerate(orig.entries) if f0 <= e.at < f1]
        kp = [k for k, e in enumerate(port.entries) if f0 <= e.at < f1]
        a, b = [od[k] for k in ko], [pd[k] for k in kp]
        if a != b:
            n = next((i for i in range(min(len(a), len(b))) if a[i] != b[i]), min(len(a), len(b)))
            at = orig.entries[ko[n]].at if n < len(ko) else f1
            mine = f"its picture {ko[n]} at {at:.2f} s" if n < len(ko) else "nothing more"
            there = f"its picture {kp[n]} at {port.entries[kp[n]].at:.2f} s" if n < len(kp) else "nothing more"
            fails.append({"rule": "S6", "screen": screen_of(spec, at), "at": at,
                          "text": f"S6: from {f0} to {f1} s, every picture in order: the original shows {len(a)}, "
                                  f"the port {len(b)}; they part at number {n + 1}: the original shows {mine}, the "
                                  f"port {there}", "detail": None})
    fails.sort(key=lambda f: f["at"])
    return fails


def key_while(spec, e):
    """Whether a key goes down or up while the entry is on show (on its side's clock), KEY_LAG or more after it
    came: a screen a key ends, whose length follows where the key's read falls (the two machines read a key
    up to a few refreshes, or a loop's step, apart). A picture a key brings comes within a refresh of it (the
    Saving box Enter brings: its length is the program's work, not the key's read)."""
    t0, t1 = e.at, e.at + e.reps / REFRESH_HZ
    return any(t0 + KEY_LAG <= t < t1 for k in spec["held"] for t in (k[0], k[0] + k[2]))


def stay_tolerance(spec, held, keyed=True):
    """S4: how many refreshes the port's time on show may differ from the original's `held`: `stay` and a
    share of it for a screen a key ends; for one no key ends (a box up while the program works, a timed
    screen), at most STAY_PART of it, never under STAY_FLOOR."""
    loose = spec["stay"] + STAY_SHARE * held
    return loose if keyed else min(loose, max(STAY_FLOOR, STAY_PART * held))


def report(spec, port, orig, fails, out_dir=None, every=False):
    """Lines: per named screen, PASS or FAIL with its first difference (`every`: all of them)."""
    lines = []
    least = spec["settled"]
    ps, os_ = port.settled(least), orig.settled(least)
    names = [n for _, n in spec["screens"]] or ["(the whole case)"]
    if any(entry_screen(spec, orig.entries[k]) == "(before the first named screen)" for k in os_) and spec["screens"]:
        names = ["(before the first named screen)"] + names
    for name in names + (["(the whole case)"] if "(the whole case)" not in names else []):
        mine = [f for f in fails if f["screen"] == name]
        if name == "(the whole case)" and not mine and spec["screens"]:
            continue
        no = len([k for k in os_ if entry_screen(spec, orig.entries[k]) == name or not spec["screens"]])
        npt = len([k for k in ps if entry_screen(spec, port.entries[k]) == name or not spec["screens"]])
        start = next((t for t, n in spec["screens"] if n == name), None)
        when = f" (from {start:.1f} s)" if start is not None else ""
        if not mine:
            lines.append(f"  {name}{when}: PASS ({no} settled pictures in the original, {npt} in the port)")
            continue
        rules = sorted({f["rule"] for f in mine})
        lines.append(f"  {name}{when}: FAIL ({len(mine)} differences: {', '.join(rules)}; {no} settled pictures "
                     f"in the original, {npt} in the port)")
        for n, f in enumerate(mine if every else mine[:1]):
            lines.append(f"    {'first' if n == 0 else 'then'}: {f['text']}")
            if f["detail"] is not None:
                lines.append(f"    {f['detail']()}")
    return lines


# ------------------------------------------------------------------ text-mode screens

# the VGA's text colours as DOSBox records them (6-bit DAC values widened)
TEXT_PALETTE = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170), (170, 0, 0), (170, 0, 170), (170, 85, 0),
                (170, 170, 170), (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255), (255, 85, 85),
                (255, 85, 255), (255, 255, 85), (255, 255, 255)]
BLANK_CHARS = (0x00, 0x20, 0xFF)       # shapes with no foreground
FULL_CHARS = (0xDB,)                  # the full block: no background
# HARN-06 (J-38: a text screen is the original's when every cell holds the same character in the same colours).
# The recorded cells are read as characters by their shapes, learnt from Keen 1-3's exit screens: each program
# carries its screen (ENDSCRN: a 7-byte header, then 4000 bytes of characters and attributes; v1.31's offsets
# in the LZEXE-unpacked program, as vort_data.gd's LINKED), and each scr_quit recording shows it once the
# program has quit, so every character on it is named by the original's own bytes and drawn by DOSBox. The
# shapes are learnt from the recordings each run, never kept in the repository. Program, offset, the row of
# the cursor it leaves (KEENMAIN.C's Quit: gotoxy(1, 23)).
GLYPH_SOURCES = {"keen1": ("KEEN1.EXE", 0x12080, 22), "keen2": ("KEEN2.EXE", 0x11780, 22),
                 "keen3": ("KEEN3.EXE", 0x12AC0, 22)}
CURSOR_LINES = (-3, -1)               # the hardware cursor: a cell's scan lines 13-14 of 16, 8 pixels wide, in
                                      # its foreground colour (DOSBox's default), on and off every 16 refreshes


class Glyphs:
    """Character shapes (foreground pixels of a `size` cell) learnt from recordings: `shapes` (256, lines,
    columns), `known` (256,), `by_shape` (a shape's bytes -> the characters it is), `notes`."""

    def __init__(self, size=(16, 9)):
        self.size = size
        self.shapes = np.zeros((256,) + size, bool)
        self.known = np.zeros(256, bool)
        self.by_shape = {}
        self.notes = []
        self.learnt = 0

    def add(self, c, shape):
        self.known[c] = True
        self.shapes[c] = shape
        self.by_shape.setdefault(shape.tobytes(), []).append(c)


_GLYPHS = {}
_GLYPHS_LOCK = threading.Lock()


def glyphs():
    """The shapes of the characters on Keen 1-3's exit screens, as their scr_quit recordings show them (built
    once a run)."""
    with _GLYPHS_LOCK:
        if "table" not in _GLYPHS:
            _GLYPHS["table"] = _learn_glyphs()
        return _GLYPHS["table"]


def _learn_glyphs():
    import unlzexe
    votes, size, table = {}, None, None
    notes = []
    for game, (exe, off, row) in GLYPH_SOURCES.items():
        folder = common.config()["oracle_runs"] / run_name(game, "scr_quit") / "text_frames"
        path = common.game(game)["dir"] / exe
        if not (folder / "frames.json").exists() or not path.exists():
            notes.append(f"{game}: no scr_quit recording or no {exe}: not learnt from")
            continue
        block = unlzexe.unpack(path.read_bytes())[off:off + 7 + 4000]
        if len(block) < 4007 or block[0] != 0xFD:
            notes.append(f"{exe}: no exit screen at {off:#x} (another version): not learnt from")
            continue
        cells = block[7:]
        seq = frames.Sequence(folder)
        last = max((i for i in range(len(seq)) if seq.repeats(i) >= TEXT_SETTLED), default=None)
        if last is None:
            notes.append(f"{game}: its scr_quit recording ends on no settled text picture: not learnt from")
            continue
        r = _read(seq.frame(last), cells)
        if size is not None and r["size"] != size:
            notes.append(f"{game}: its text pictures have cells of another size: not learnt from")
            continue
        size = r["size"]
        glyph = (~r["blank"]) & (~r["full"]) & (~r["blink"])
        glyph[row + 1, :] = False               # DOS's prompt, on the row below the exit cursor
        if not r["colours_ok"][glyph].all():
            notes.append(f"{game}: its recording's last text picture is not the program's exit screen: not learnt "
                         f"from")
            continue
        for y, x in zip(*np.nonzero(glyph)):
            votes.setdefault(int(r["chars"][y, x]), set()).add(r["shape"][y, x].tobytes())
    table = Glyphs(size or (16, 9))
    table.notes = notes
    for c, shapes in sorted(votes.items()):
        if len(shapes) == 1:
            table.add(c, np.frombuffer(next(iter(shapes)), bool).reshape(table.size))
            table.learnt += 1
        else:
            table.notes.append(f"character {c:02X}h shows {len(shapes)} shapes on the exit screens: not learnt")
    for c in BLANK_CHARS:
        table.add(c, np.zeros(table.size, bool))
    for c in FULL_CHARS:
        table.add(c, np.ones(table.size, bool))
    return table


def _read(frame, cells):
    """A recorded text picture against 80x25 (character, attribute) cells: per cell (25, 80, ...) arrays."""
    h, w = frame.shape[:2]
    ch, cw = h // 25, w // 80
    grid = frame[:25 * ch, :80 * cw].reshape(25, ch, 80, cw, 3).swapaxes(1, 2)
    arr = np.frombuffer(bytes(cells), np.uint8)
    chars, attrs = arr[0::2].reshape(25, 80), arr[1::2].reshape(25, 80)
    fg, bg = attrs & 15, (attrs >> 4) & 7
    pal = np.array(TEXT_PALETTE, np.uint8)
    isfg = np.all(grid == pal[fg][:, :, None, None, :], axis=-1)
    isbg = np.all(grid == pal[bg][:, :, None, None, :], axis=-1)
    one = fg == bg
    blank = np.isin(chars, BLANK_CHARS) | one
    return {"size": (ch, cw), "chars": chars, "attrs": attrs, "blink": (attrs & 0x80) != 0, "blank": blank,
            "full": np.isin(chars, FULL_CHARS) & ~blank, "shape": isfg & ~one[:, :, None, None],
            "colours_ok": np.all(isfg | isbg, axis=(2, 3))}


def _char_text(c):
    return f"'{chr(c)}'" if 32 <= c < 127 else f"{c:02X}h"


def text_problems(frame, cells, table, masked=frozenset(), fonts=None):
    """How one recorded text picture fails to be the 80x25 screen `cells` (character, attribute bytes), cell by
    cell (J-38): every cell's colours are its attribute's, and its shape is its character's as `table` knows
    it (a character the table does not know: one shape for all its cells, none a known character's, and the
    shape `fonts` holds from earlier screens). Blinking cells are all shown or all hidden. The cursor (its
    two scan lines on one cell) is found, not failed here. The `masked` cells ((row, column)) are left out.
    Returns (problems, the cursor's cells (row, column), the unknown characters' shapes {(char, attr): bytes},
    how many cells are wrong)."""
    r = _read(frame, cells)
    ch, cw = r["size"]
    if table is None or table.size != (ch, cw):
        table = Glyphs((ch, cw))
    chars, attrs, shape, blink = r["chars"], r["attrs"], r["shape"], r["blink"]
    look = np.ones((25, 80), bool)
    for y, x in masked:
        look[y, x] = False
    cur = np.zeros((ch, cw), bool)
    cur[ch + CURSOR_LINES[0]:ch + CURSOR_LINES[1], :8] = True
    known = (table.known[chars] | r["blank"] | r["full"])
    expect = table.shapes[chars].copy()
    expect[r["blank"]] = False
    expect[r["full"]] = True
    exact = np.all(shape == expect, axis=(2, 3))
    cursor_on = np.all(shape == (expect | cur), axis=(2, 3)) & ~exact
    hidden = ~np.any(shape, axis=(2, 3)) & np.any(expect, axis=(2, 3))
    problems, seen, wrong = [], [], []
    bad_colour = [(y, x) for y, x in zip(*np.nonzero(look & ~r["colours_ok"]))]
    if bad_colour:
        y, x = bad_colour[0]
        a = int(attrs[y, x])
        where = ", ".join(f"{p[0]}/{p[1]}" for p in bad_colour[:8])
        problems.append(f"{len(bad_colour)} cells show other colours than the port's attributes (row/column {where}"
                        f"{', ...' if len(bad_colour) > 8 else ''}; the first: the port's {_char_text(int(chars[y, x]))}"
                        f" in colours {a & 15} on {(a >> 4) & 7})")
    phases = set()
    ok_colour = look & r["colours_ok"]
    for y, x in zip(*np.nonzero(ok_colour & known)):
        if exact[y, x]:
            if blink[y, x] and np.any(expect[y, x]):
                phases.add("shown")
        elif cursor_on[y, x]:
            seen.append((int(y), int(x)))
        elif blink[y, x] and hidden[y, x]:
            phases.add("hidden")
        else:
            wrong.append((int(y), int(x)))
    # characters the table does not know: each one look for all its cells, none a known character's shape
    groups = {}
    for y, x in zip(*np.nonzero(ok_colour & ~known)):
        if blink[y, x] and not np.any(shape[y, x]):
            phases.add("hidden")
            continue
        if blink[y, x]:
            phases.add("shown")
        groups.setdefault((int(chars[y, x]), int(attrs[y, x]) & 0x7F), {}).setdefault(shape[y, x].tobytes(), []).append((int(y), int(x)))
    looks = {}
    for cls, by_look in groups.items():
        best = max(by_look, key=lambda lk: len(by_look[lk]))
        looks[cls] = best
        for lk, where in by_look.items():
            if lk == best:
                if lk in table.by_shape:
                    wrong += where
                continue
            on = np.frombuffer(best, bool).reshape(ch, cw) | cur
            if on.tobytes() == lk and len(where) == 1:
                seen += where
            else:
                wrong += where
    by_best = {}
    for cls, lk in looks.items():
        by_best.setdefault(lk, []).append(cls)
    alike = [v for v in by_best.values() if len({c for c, _ in v}) > 1]
    if alike:
        (c1, _), (c2, _) = alike[0][:2]
        problems.append(f"the port's characters {_char_text(c1)} and {_char_text(c2)} look alike in the recording")
    if wrong:
        wrong.sort()
        y, x = wrong[0]
        read = table.by_shape.get(shape[y, x].tobytes())
        shows = (f"the recording shows {_char_text(read[0])}" if read else
                 "the recording shows no character the table knows")
        where = ", ".join(f"{p[0]}/{p[1]}" for p in wrong[:8])
        problems.append(f"{len(wrong)} cells hold other characters than the port's (row/column {where}"
                        f"{', ...' if len(wrong) > 8 else ''}; the first: {shows}, the port "
                        f"{_char_text(int(chars[y, x]))})")
    if len(phases) > 1:
        problems.append("blinking cells shown and hidden in the same picture")
    if len(seen) > 1:
        problems.append(f"the cursor's lines on {len(seen)} cells ({', '.join(f'{p[0]}/{p[1]}' for p in seen[:4])})")
    if fonts is not None and not problems:
        for cls, lk in looks.items():
            if cls in fonts and fonts[cls] != lk:
                problems.append(f"the port's {_char_text(cls[0])} looks unlike it did on an earlier screen")
                break
    return problems, seen, looks, len(bad_colour) + len(wrong) + len(problems)


def load_port_text(path):
    """[[refreshes, cells, (column, row)], ...] from a runner's text_frames.json."""
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    return [[n, bytes.fromhex(h), (cx, cy)] for n, h, cx, cy in doc["screens"]]


def text_masked(spec):
    """The cells ((row, column)) the case's "text_masks" leave out: {"cells": [row0, col0, row1, col1]},
    the last row and column not included, each with its reason."""
    out = set()
    for m in spec.get("text_masks", []):
        if not m.get("reason"):
            raise ValueError("a text mask without a reason")
        r0, c0, r1, c1 = m["cells"]
        out |= {(r, c) for r in range(r0, r1) for c in range(c0, c1)}
    return frozenset(out)


def _quit_start(rec_seq):
    """The first of the recording's text pictures captured after the program's EGA pictures (it quit), or
    None. DOS's prompt comes only before the program, at the start of the first capture, and after it quits
    (frames.from_videos' "parts")."""
    parts = rec_seq.meta.get("parts") or [["", 0, rec_seq.raw_frames, 0]]
    starts, at = [], 0
    for i in range(len(rec_seq)):
        starts.append(at)
        at += rec_seq.repeats(i)
    after = [part for part in parts if part[3] > 0]
    if not after:
        return None
    first_raw = after[-1][1]
    return next((i for i, st in enumerate(starts) if st >= first_raw), len(rec_seq))


def after_quit(cells, cursor):
    """The port's exit screen as DOS leaves it, and the row of DOS's prompt: COMMAND.COM starts a new line below
    the cursor the program left (the screen scrolls up a row when that is the last) and writes its prompt
    there, its cursor after it (that row is left out)."""
    row = cursor[1] + 1
    if row <= 24:
        return bytes(cells), row
    return bytes(cells[160:4000]) + bytes([0x20, 0x07]) * 80, 24


def compare_text(rec_seq, port_screens, masked=frozenset(), table=None):
    """The text screens, as the EGA pictures' S1, S2 and order: (failures, notes). Every settled text
    picture of the recording (up TEXT_SETTLED refreshes or more) is one of the port's screens, in order;
    every settled screen of the port is one the recording shows (for however long), in order. Cells are read
    as characters (glyphs()); the cursor, where the recording shows it, is where the port has it, and once the
    program has quit DOS's prompt is on the row below the port's exit cursor (its cells and cursor left out).
    The recording's settled pictures before the first that is one of the port's screens are DOS's own (its
    prompt), and so are those after the last in a capture made after the program's EGA pictures (it quit)."""
    table = table if table is not None else glyphs()
    fails, notes = [], []
    rec = [i for i in range(len(rec_seq)) if rec_seq.repeats(i) >= TEXT_SETTLED]
    port = [k for k, s in enumerate(port_screens) if s[0] >= TEXT_SETTLED]
    quit_from = _quit_start(rec_seq)
    memo = {}
    cursors_seen = set()

    def problems(i, k, fonts=None):
        if fonts is None and (i, k) in memo:
            return memo[(i, k)]
        s = port_screens[k]
        cells, (cx, cy) = s[1], s[2]
        gone = quit_from is not None and i >= quit_from
        m = masked
        if gone:
            cells, prompt = after_quit(cells, (cx, cy))
            m = masked | {(prompt, c) for c in range(80)}
        probs, seen, looks, bad = text_problems(rec_seq.frame(i), cells, table, m, fonts)
        before = len(probs)
        if seen and gone:
            # DOS's cursor stands after its prompt, on the row left out
            y, x = seen[0]
            probs.append(f"the recording's cursor (DOS's, after its prompt) is at row {y} column {x}; the port's exit "
                         f"cursor (row {cy} column {cx}) puts DOS's prompt on row {prompt}")
        elif seen and not probs:
            y, x = seen[0]
            if (y, x) != (cy, cx):
                probs.append(f"the recording's cursor is at row {y} column {x}, the port's at row {cy} column {cx}")
        out = (probs, looks, bad + len(probs) - before)
        if fonts is None:
            memo[(i, k)] = out
            if not probs and seen:
                cursors_seen.add(k)
        return out

    # the recording's settled pictures, each one of the port's screens (any), in order
    fonts, p, hits = {}, 0, []
    for i in rec:
        k = next((k for k in range(p, len(port_screens)) if not problems(i, k)[0]), None)
        if k is not None and problems(i, k, fonts)[0]:
            k = None        # a shape unlike the same character's on an earlier screen
        hits.append(k)
        if k is not None:
            p = k
            for cls, lk in problems(i, k)[1].items():
                fonts.setdefault(cls, lk)
    found = [n for n, k in enumerate(hits) if k is not None]
    dos_before = found[0] if found else len([i for i in rec if quit_from is None or i < quit_from])
    dos_after = 0
    if quit_from is not None:
        dos_after = len([n for n in range(len(rec)) if rec[n] >= quit_from and (not found or n > found[-1])])
    for n in range(dos_before, len(rec) - dos_after):
        if hits[n] is None:
            i = rec[n]
            if not port_screens:
                fails.append(f"text: the recording's text picture {i} (up {rec_seq.repeats(i)} refreshes): the port "
                             f"shows no text screen")
                continue
            k = min(range(len(port_screens)), key=lambda k: problems(i, k)[2])
            why = problems(i, k)[0]
            fails.append(f"text: the recording's text picture {i} (up {rec_seq.repeats(i)} refreshes) is none of the "
                         f"port's screens; nearest, the port's screen {k}: {why[0] if why else 'out of order'}")
    # the port's settled screens, each shown by the recording (any picture), in order
    last = -1
    for k in port:
        at = next((i for i in range(len(rec_seq)) if not problems(i, k)[0]), None)
        if at is None:
            near = min(range(len(rec_seq)), key=lambda i: problems(i, k)[2], default=None)
            best = (near, problems(near, k)[0]) if near is not None else None
            detail = f"; nearest, the recording's text picture {best[0]}: {best[1][0]}" if best and best[1] else ""
            fails.append(f"text: the port's screen {k} (up {port_screens[k][0]} refreshes) is in no recorded text "
                         f"picture{detail}")
        elif at < last:
            fails.append(f"text: the port's screen {k} first shows in the recording at its text picture {at}, "
                         f"before the screen ahead of it (at {last})")
        else:
            last = at
    unknown = sorted({c for k in port for c in port_screens[k][1][0::2] if not table.known[c]})
    notes.append(f"text screens: {len(port)} settled in the port, {len(rec)} settled pictures in the recording "
                 f"({dos_before} before the first of the port's screens, DOS's prompt or a start-up screen the port "
                 f"does not show, and {dos_after} after the program quit, left out)"
                 + (f"; {len(masked)} cells masked" if masked else "")
                 + ("; after the program quit, DOS's prompt row (below the port's exit cursor) left out"
                    if quit_from is not None else ""))
    notes.append(f"text cells read by shape: {table.learnt} characters learnt from Keen 1-3's exit screens"
                 + (f"; the port's {''.join(chr(c) if 32 <= c < 127 else '?' for c in unknown)} "
                    f"({len(unknown)} not learnt) held by one shape each, none another's" if unknown else "")
                 + (f"; the cursor seen where the port has it on {len(cursors_seen)} of the port's screens"
                    if cursors_seen else "")
                 + ("; " + "; ".join(table.notes) if table.notes else ""))
    return fails, notes


# ------------------------------------------------------------------ commands

def oracle_view(game, case, spec, run="a"):
    folder = common.config()["oracle_runs"] / run_name(game, case, run)
    if not (folder / "frames" / "frames.json").exists():
        return None, folder
    return View(frames.Sequence(folder / "frames"), spec["masks"], spec["seconds"], "original"), folder


def check(game, case, run="a", tag="", no_run=False, every=False, say=print, more=None):
    spec = load(game, case)
    if spec is None:
        say(f"COULD-NOT-RUN: no case tools/cases/{game}/{case_name(case)}.json")
        return common.COULD_NOT_RUN
    orig, ofolder = oracle_view(game, case, spec, run)
    if orig is None:
        say(f"{game} {case_name(case)}: COULD-NOT-RUN, not recorded (python tools/screen_case.py record {game} "
              f"{case_name(case)} --run {run})")
        return common.COULD_NOT_RUN
    work = work_dir(game, case, tag)
    pfolder = work / "port"
    if no_run:
        pframes = pfolder / game if (pfolder / game / "frames.json").exists() else pfolder
        ptext = pframes / "text_frames.json"
        ptext = ptext if ptext.exists() else None
    else:
        code, pframes, ptext = run_port(game, case, pfolder, say, more=more)
        if pframes is None:
            return common.COULD_NOT_RUN
    port = View(frames.Sequence(pframes), spec["masks"], spec["seconds"], "port")
    diff = work / "diff"
    shutil.rmtree(diff, ignore_errors=True)
    fails = compare(spec, port, orig, diff)
    lines = report(spec, port, orig, fails, diff, every)
    text_fails, text_notes = [], []
    rec_text = ofolder / "text_frames"
    if (rec_text / "frames.json").exists() and ptext is not None:
        text_fails, text_notes = compare_text(frames.Sequence(rec_text), load_port_text(ptext), text_masked(spec))
    elif (rec_text / "frames.json").exists():
        n = sum(1 for i in range(len(frames.Sequence(rec_text))) if frames.Sequence(rec_text).repeats(i) >= TEXT_SETTLED)
        text_notes.append(f"the recording holds {n} settled text pictures (DOS's prompt, a start-up screen); the "
                          f"port's runner writes no text screens for {game}: not compared")
    ok = not fails and not text_fails
    say(f"{game} {case_name(case)}: {'PASS' if ok else 'FAIL'} ({len(orig.entries)} pictures in the original, "
          f"{len(port.entries)} in the port to {spec['seconds']} s; settled = up {spec['settled']} refreshes or more)")
    for line in lines:
        say(line)
    shown = text_fails if every else text_fails[:3]
    for line in shown + ([f"(and {len(text_fails) - len(shown)} more: --all)"] if len(text_fails) > len(shown) else []) + text_notes:
        say("  " + line)
    if fails or text_fails:
        say(f"  pictures of the differences: {diff}")
    (work / "result.json").write_text(json.dumps({"game": game, "case": case_name(case), "pass": ok,
                                                  "report": lines + text_fails + text_notes}, indent=1),
                                      encoding="utf-8")
    return common.PASS if ok else common.FAIL


def preview(game, case, tag="", hold=0.5, step=1.0, no_run=False, keep=None):
    """The port alone: the pictures it keeps up `hold` seconds or more, with their times (masks applied),
    and a sheet of what is on show every `step` seconds, to design a timetable by."""
    from PIL import Image, ImageDraw
    spec = load(game, case)
    work = work_dir(game, case, tag)
    if no_run:
        pframes = work / "port" / game if (work / "port" / game / "frames.json").exists() else work / "port"
        ptext = pframes / "text_frames.json" if (pframes / "text_frames.json").exists() else None
        code = common.PASS
    else:
        code, pframes, ptext = run_port(game, case, work / "port", keep=keep)
        if pframes is None:
            return common.COULD_NOT_RUN
        if keep:
            print(f"  the player's files it wrote: {keep}: {', '.join(sorted(f.name for f in Path(keep).iterdir()))}")
    port = View(frames.Sequence(pframes), spec["masks"], spec["seconds"], "port")
    print(f"{game} {case_name(case)} in the port: {len(port.entries)} pictures to {spec['seconds']} s; "
          f"up {hold} s or more (masks applied):")
    for k, e in enumerate(port.entries):
        if e.reps >= hold * REFRESH_HZ:
            print(f"  {e.at:7.2f} s  up {e.reps / REFRESH_HZ:5.2f} s  picture {k:4d}  [{entry_screen(spec, e)}]")
    tiles, t, k = [], 0.0, 0
    while t < spec["seconds"] and len(tiles) < 64:
        while k + 1 < len(port.entries) and port.entries[k + 1].at <= t:
            k += 1
        img = Image.fromarray(port.entries[k].frame())
        ImageDraw.Draw(img).text((2, 2), f"{t:.1f}s", fill=(255, 0, 255))
        tiles.append(np.asarray(img))
        t += step
    if tiles:
        while len(tiles) % 4:
            tiles.append(np.zeros_like(tiles[0]))
        rows = [np.concatenate(tiles[i:i + 4], axis=1) for i in range(0, len(tiles), 4)]
        path = work / "sheet.png"
        Image.fromarray(np.concatenate(rows, axis=0)).save(path)
        print(f"  sheet of what is on show every {step} s: {path}")
    if ptext:
        shown = load_port_text(ptext)
        print(f"  text screens: {len(shown)} ({sum(1 for s in shown if s[0] >= TEXT_SETTLED)} settled)")
    return code


def pair(game, case, plant=True):
    """HARN-06a: runs a and b of the original agree on every picture up 4 refreshes or more (first and last
    left out), in order, to the case's end; a planted altered picture is noticed. Returns (code, lines)."""
    spec = load(game, case)
    views = []
    for run in ("a", "b"):
        v, _ = oracle_view(game, case, dict(spec, masks=[]), run)
        if v is None:
            return common.COULD_NOT_RUN, [f"{game} {case_name(case)}: run {run} not recorded"]
        views.append(v)
    a, b = views
    held_a = [a.entries[k].digest for k in a.settled(SETTLED)]
    held_b = [b.entries[k].digest for k in b.settled(SETTLED)]
    same = held_a == held_b
    lines = [f"{game} {case_name(case)}: {a.refreshes}/{b.refreshes} refreshes to {spec['seconds']} s, "
             f"{len(held_a)}/{len(held_b)} held pictures ({len(set(held_a))} different): "
             f"{'identical in order' if same else 'DIFFERENT'}"]
    if not same:
        k = next((i for i in range(min(len(held_a), len(held_b))) if held_a[i] != held_b[i]), min(len(held_a), len(held_b)))
        lines.append(f"  first difference at held picture {k}")
    # (said, not required: key-fed runs have come out alike to every picture and refresh)
    every = [(e.digest, e.reps) for e in a.entries] == [(e.digest, e.reps) for e in b.entries]
    lines.append(f"  every picture ({len(a.entries)}/{len(b.entries)}) and its refreshes: "
                 f"{'the same' if every else 'not the same'}")
    texts = [common.config()["oracle_runs"] / run_name(game, case, r) / "text_frames" for r in "ab"]
    if all((t / "frames.json").exists() for t in texts):
        # (DOS's prompt names the run's own folder in its mount line: those pictures differ by design)
        ta, tb = (frames.Sequence(t) for t in texts)
        alike = [n for n in range(min(len(ta), len(tb))) if ta.digest(n) == tb.digest(n)]
        reps = [ta.repeats(n) for n in range(len(ta))] == [tb.repeats(n) for n in range(len(tb))]
        lines.append(f"  text pictures: {len(ta)}/{len(tb)}, {len(alike)} alike, their refreshes "
                     f"{'the same' if reps else 'not the same'} (DOS's prompt names each run's folder)")
    noticed = True
    if plant:
        tampered = list(held_b)
        if tampered:
            tampered[len(tampered) // 2] = "0" * 40
        noticed = held_a != tampered
        lines.append(f"  planted one altered picture: {'noticed' if noticed else 'MISSED'}")
    ok = same and noticed and len(set(held_a)) >= max(2, spec["least"])
    return (common.PASS if ok else common.FAIL), lines


def selftest(game, case, tag=""):
    """The comparison must fail on planted faults: one settled picture of the port altered by a pixel (and
    the last, when the case ends on a screen held to the cut), one settled picture of the original left out
    of the port, two swapped, a screen no key ends cut to one refresh (S4), two steps of a "sequences" span
    swapped (S6), and with text screens one cell's colour, one character swapped for one shown nowhere else
    on the screen and the cursor moved."""
    spec = load(game, case)
    orig, ofolder = oracle_view(game, case, spec)
    work = work_dir(game, case, tag)
    pfolder = work / "port"
    pframes = pfolder / game if (pfolder / game / "frames.json").exists() else pfolder
    if orig is None or not (pframes / "frames.json").exists():
        print("COULD-NOT-RUN: record the case and check it first")
        return common.COULD_NOT_RUN
    ok = True

    def fresh():
        return View(frames.Sequence(pframes), spec["masks"], spec["seconds"], "port")

    def plant_pixel(port, k):
        e = port.entries[k]
        x, y = 160, 100
        while any(m["rect"][0] <= x < m["rect"][2] and m["rect"][1] <= y < m["rect"][3] for m in e.masks):
            y = (y + 37) % 200
        e.plant = (x, y)
        e.digest = hashlib.sha1(e.frame().tobytes()).hexdigest()
        got = compare(spec, port, orig)
        return any(f["rule"] == "S1" and f"picture {k} " in f["text"] for f in got)

    clean = compare(spec, fresh(), orig)
    print(f"  as recorded: {'PASS' if not clean else 'FAIL (' + clean[0]['text'] + ')'}")
    ok &= not clean
    # one pixel of a settled picture of the port turned to its opposite, outside every mask
    port = fresh()
    ks = port.settled(spec["settled"])
    k = ks[len(ks) // 2]
    hit = plant_pixel(port, k)
    print(f"  planted: the port's picture {k} ({port.entries[k].at:.2f} s) with one pixel changed: "
          f"{'reported (' + entry_screen(spec, port.entries[k]) + ')' if hit else 'MISSED'}")
    ok &= hit
    # the same in the last picture, when the case ends on a screen held to the cut
    port = fresh()
    last = len(port.entries) - 1
    if last in port.settled(spec["settled"]):
        hit = plant_pixel(port, last)
        print(f"  planted: the port's last picture {last} ({port.entries[last].at:.2f} s, up {port.entries[last].reps} "
              f"refreshes to the cut) with one pixel changed: "
              f"{'reported (' + entry_screen(spec, port.entries[last]) + ')' if hit else 'MISSED'}")
        ok &= hit
    else:
        print("  (the case does not end on a screen held to the cut: the last picture's fault not planted)")
    # a settled picture of the original never shown by the port
    port = fresh()
    os_ = orig.settled(spec["settled"])
    target = orig.entries[os_[len(os_) // 2]]
    port.entries = [p for p in port.entries if p.digest != target.digest]
    got = compare(spec, port, orig)
    hit = any(f["rule"] == "S2" for f in got)
    print(f"  planted: the original's picture {os_[len(os_) // 2]} ({target.at:.2f} s) left out of the port: "
          f"{'reported (' + entry_screen(spec, target) + ')' if hit else 'MISSED'}")
    ok &= hit
    # two screens the port shows once each (and the original too), swapped in the port
    port = fresh()
    counts = {}
    for side in (port, orig):
        for e in side.entries:
            counts[(side.side, e.digest)] = counts.get((side.side, e.digest), 0) + 1
    once = [k for k in port.settled(spec["settled"])
            if counts[("port", port.entries[k].digest)] == 1 and counts.get(("original", port.entries[k].digest)) == 1]
    if len(once) >= 2:
        x, y = once[0], once[-1]
        port.entries[x], port.entries[y] = port.entries[y], port.entries[x]
        got = compare(spec, port, orig)
        hit = any(f["rule"] == "S5" for f in got)
        print(f"  planted: the port's pictures {x} and {y} swapped: {'reported' if hit else 'MISSED'}")
        ok &= hit
    else:
        print("  (no two pictures shown once each to swap: the order fault not planted)")
    # S4: a screen the original holds in one stretch, no key ending it, up one refresh in the port
    port = fresh()
    ends = {orig.entries[0].digest, orig.entries[-1].digest, port.entries[0].digest, port.entries[-1].digest}
    shown = {e.digest for e in port.entries}
    held = [k for k in os_ if counts.get(("original", orig.entries[k].digest)) == 1 and not key_while(spec, orig.entries[k])
            and orig.entries[k].digest in shown and orig.entries[k].digest not in ends
            and not _empty(orig.entries[k].frame())]
    if spec["stay"] is not None and held:
        k = min(held, key=lambda k: orig.entries[k].reps)
        d = orig.entries[k].digest
        for e in port.entries:
            if e.digest == d:
                e.reps = 1
        got = compare(spec, port, orig)
        hit = any(f["rule"] == "S4" for f in got)
        print(f"  planted: the original's picture {k} ({orig.entries[k].at:.2f} s, up {orig.entries[k].reps} refreshes, "
              f"no key ending it) up 1 refresh in the port: {'reported' if hit else 'MISSED'}")
        ok &= hit
    else:
        print("  (no screen held without a key to shorten: the S4 fault not planted)")
    # S6: two steps of a sequence swapped in the port
    for span in spec["sequences"]:
        port = fresh()
        inside = [k for k, e in enumerate(port.entries) if span["from"] <= e.at < span["to"]]
        pair_at = next((k for k in inside[1:-1] if port.entries[k].digest != port.entries[k + 1].digest
                        and k + 1 in inside and port.entries[k - 1].digest != port.entries[k + 1].digest), None)
        if pair_at is None:
            continue
        a, b = port.entries[pair_at], port.entries[pair_at + 1]
        a.digest, b.digest = b.digest, a.digest
        got = compare(spec, port, orig)
        hit = any(f["rule"] == "S6" for f in got)
        print(f"  planted: the port's steps {pair_at} and {pair_at + 1} ({a.at:.2f} s) swapped in the sequence from "
              f"{span['from']} s: {'reported' if hit else 'MISSED'}")
        ok &= hit
    ptext = pframes / "text_frames.json"
    rec_text = ofolder / "text_frames"
    if ptext.exists() and (rec_text / "frames.json").exists():
        rec = frames.Sequence(rec_text)
        fails, _ = compare_text(rec, load_port_text(ptext), text_masked(spec))
        print(f"  text screens as recorded: {'PASS' if not fails else 'FAIL (' + fails[0] + ')'}")
        ok &= not fails
        table = glyphs()

        def plant_text(what, change):
            shown = load_port_text(ptext)
            settled = [s for s in shown if s[0] >= TEXT_SETTLED]
            if not settled:
                return True
            s = settled[len(settled) // 2]
            old = s[1]
            cells, cursor, text = change(bytearray(old), s[2])
            for t in shown:
                if t[1] == old:
                    t[1], t[2] = bytes(cells), cursor
            fails, _ = compare_text(rec, shown, text_masked(spec))
            print(f"  planted: {what} {text}: {'reported' if fails else 'MISSED'}")
            return bool(fails)

        def first_glyph(cells):
            return next(i for i in range(0, 4000, 2) if cells[i] not in BLANK_CHARS + FULL_CHARS
                        and (cells[i + 1] & 15) != ((cells[i + 1] >> 4) & 7) and not cells[i + 1] & 0x80
                        and table.known[cells[i]])

        def colour(cells, cursor):
            at = first_glyph(cells)
            cells[at + 1] = (cells[at + 1] & 0xF0) | (((cells[at + 1] & 15) + 1) & 15)
            return cells, cursor, f"(row {at // 160}, column {at % 160 // 2})"

        def character(cells, cursor):
            # a character the screen shows nowhere, in place of one it shows (as 432 KB for 435 KB)
            at = first_glyph(cells)
            used = set(cells[0::2])
            new = next(c for c in range(33, 256) if table.known[c] and c not in used and c not in FULL_CHARS)
            was = cells[at]
            cells[at] = new
            return cells, cursor, (f"(row {at // 160}, column {at % 160 // 2}: {_char_text(was)} made "
                                   f"{_char_text(new)}, shown nowhere else)")

        def cursor_move(cells, cursor):
            moved = (40, 10) if tuple(cursor) != (40, 10) else (20, 5)
            return cells, moved, f"(from column {cursor[0]} row {cursor[1]} to column {moved[0]} row {moved[1]})"

        ok &= plant_text("one cell's colour changed in the port's text screen", colour)
        ok &= plant_text("one character changed in the port's text screen", character)
        ok &= plant_text("the port's text cursor moved", cursor_move)
    print("PASS" if ok else "FAIL")
    return common.PASS if ok else common.FAIL


def checkout_tag(what):
    """A work-folder tag naming this checkout too ("regress_1600ac2d8c71" in a worktree), so that copies of the project
    checking the same case at once (worktrees side by side) do not share the port's folder."""
    return what + "_" + "".join(c for c in common.ROOT.name if c.isalnum())[-12:]


def check_games(games, tag=None):
    """SCR-01V/G/D: every tools/cases/<game>/scr_*.json of the games checked against its recording (run a).
    A case not recorded yet is COULD-NOT-RUN. Returns the worst code (PASS when there are no cases)."""
    from concurrent.futures import ThreadPoolExecutor
    tag = tag or checkout_tag("regress")
    todo = [(game, case) for game in games for case in cases(game)]
    if not todo:
        print(f"  no screen cases yet for {', '.join(games)}")
        return common.PASS

    def one(item):
        lines = []
        code = check(item[0], item[1], tag=tag, say=lines.append)
        return code, lines

    # four port runs at once (the machine is shared); each case's report printed whole, in order
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(one, todo))
    for code, lines in results:
        for line in lines:
            print("  " + line)
    return max(code for code, _ in results)


def list_cases(games):
    root = common.config()["oracle_runs"]
    for game in games or [p.name for p in sorted(CASES.iterdir()) if p.is_dir()]:
        for case in cases(game):
            spec = load(game, case)
            runs = "".join(r for r in "ab" if (root / run_name(game, case, r) / "frames" / "frames.json").exists())
            print(f"{game:11s} {case:24s} {spec['seconds']:5.1f} s  recorded: {runs or '-':3s} "
                  f"screens: {' | '.join(n for _, n in spec['screens'])}")
    return common.PASS


def main():
    ap = argparse.ArgumentParser(description="HARN-06 screen cases")
    ap.add_argument("command", choices=["list", "port", "record", "check", "pair", "selftest"])
    ap.add_argument("game", nargs="?")
    ap.add_argument("case", nargs="?")
    ap.add_argument("--run", default="a", choices=["a", "b"])
    ap.add_argument("--tag", default="")
    ap.add_argument("--no-run", action="store_true", help="check, port: the port's last run again")
    ap.add_argument("--show", action="store_true", help="record: DOSBox's window shown")
    ap.add_argument("--all", action="store_true", help="check: every difference, not only the first per screen")
    ap.add_argument("--hold", type=float, default=0.5, help="port: list the pictures up this long (seconds)")
    ap.add_argument("--step", type=float, default=1.0, help="port: the sheet's spacing (seconds)")
    ap.add_argument("--keep", help="port: a folder to keep the player's files the program writes in (saves)")
    a = ap.parse_args()
    if a.command == "list":
        return list_cases([g for g in (a.game, a.case) if g])
    if not a.game or not a.case:
        ap.error("a game and a case are needed")
    if load(a.game, a.case) is None:
        print(f"COULD-NOT-RUN: no case tools/cases/{a.game}/{case_name(a.case)}.json")
        return common.COULD_NOT_RUN
    if a.command == "record":
        return record(a.game, a.case, a.run, a.show)
    if a.command == "port":
        return preview(a.game, a.case, a.tag, a.hold, a.step, a.no_run, a.keep)
    if a.command == "check":
        return check(a.game, a.case, a.run, a.tag, a.no_run, a.all)
    if a.command == "selftest":
        return selftest(a.game, a.case, a.tag)
    code, lines = pair(a.game, a.case)
    print("\n".join(lines))
    return code


if __name__ == "__main__":
    sys.exit(main())
