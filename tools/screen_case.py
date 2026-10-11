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
more (default 4); the first and last are never settled (cut by the recording's start and end).

  S1  every settled picture of the port is a picture the original showed;
  S2  every settled picture of the original is one the port showed;
  S3  each side shows at least `least` different settled pictures (default: one per named screen);
  S4  a settled picture the original shows in one stretch (a screen that stays up, not an animation's
      returning frame) is up about as long in all in the port: within `stay` refreshes (default 12) and 5%
      (the case's "stay": null leaves it out);
  S5  order: a picture that one side showed only after another was gone, the other shows after it too.

A failure is reported under the named screen it falls in, with the nearest picture of the other side
(its index, the box of the pixels that differ and their count) and a picture of the three (this, nearest,
differences) under the work folder, F:/KeenReworkWork/port_runs/screen_<game>_<case>[_tag]/diff.

Text-mode screens (Keen Dreams' start screens, a program's exit screen) are drawn by the shell in
Megarocket's own font, so they are compared by their 80x25 cells: every cell the port says holds the same
(character, attribute) looks the same in the recording, cells of different pairs look different, and each
cell's colours are its attribute's (blinking cells shown or hidden, all alike; the hardware cursor is noted,
not failed). Every settled text picture of the recording (TEXT_SETTLED) is one of the port's screens, in
order, and the reverse; the recording's pictures before the first that is the port's, and after the last
once the program has quit, are DOS's own (its prompt).

    python tools/screen_case.py list [game ...]
    python tools/screen_case.py port <game> <case> [--tag T] [--keep DIR]   the port alone: a sheet to design by
    python tools/screen_case.py record <game> <case> [--run a|b]            the original, into oracle_runs
    python tools/screen_case.py check <game> <case> [--run a] [--tag T] [--no-run] [--all]
    python tools/screen_case.py pair <game> <case>                          run a against run b (HARN-06a)
    python tools/screen_case.py selftest <game> <case> [--tag T]            planted faults must be reported

Cannot catch: a difference on a picture neither side keeps up `settled` refreshes; anything under a mask;
in text screens, a character the port puts where the original has another if that character appears
nowhere else on the screen (the shapes themselves are not compared).
"""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import numpy as np

import common
import frames
import keyfeed

CASES = Path(__file__).parent / "cases"
WORK = Path("F:/KeenReworkWork/port_runs")
REFRESH_HZ = 70.086
SETTLED = 4             # refreshes a picture stays up to count (harn01a's held pictures)
STAY = 12               # S4: refreshes, plus STAY_SHARE of the original's time
STAY_SHARE = 0.05
NEAR = 3.0              # seconds either side searched for the nearest picture of the other side
PORT_EXTRA = 8.0        # seconds the port runs past "seconds" from its start (its start-up comes first)
PRE_SECONDS = 12        # the recording's seconds before the game's start-up is done (oracle_run pre_seconds)
TEXT_SETTLED = 10       # refreshes a text picture stays up to count (the original's start screens are drawn
                        # in steps up 6-8 refreshes each as its hardware checks finish; the cursor blinks
                        # every 16)


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


def run_port(game, case, out, say=print, keep=None):
    """The port's runner with the case's timetable, frames to `out`; `keep`: a folder the player's files the
    program writes are kept in (a saved game for another case's overrides). Returns (code, frames folder,
    text screens file)."""
    import gdtest
    spec = load(game, case)
    engine = common.game(game)["engine"]
    feed = ",".join(f"{m}:{c}:{b}" for m, c, b in keyfeed.feed_pairs(spec["held"]))
    shutil.rmtree(out, ignore_errors=True)
    args = [f"--seconds={spec['seconds'] + PORT_EXTRA}", f"--out={Path(out).as_posix()}", f"--feed_keys={feed}"]
    seed = overrides_dir(spec)
    if seed:
        args.append(f"--save_seed={seed.as_posix()}")
    if spec["may_exit"]:
        args.append("--may_exit=1")
    if keep:
        Path(keep).mkdir(parents=True, exist_ok=True)
        args.append(f"--save={Path(keep).resolve().as_posix()}")
    extra = dict(spec["port"])
    if engine == "vorticons":
        test, folder = "simv01_boot", Path(out)
        args.append(f"--game={game}")
    elif engine == "galaxy":
        test, folder = "simg_boot", Path(out)
        args += [f"--game={game}", f"--args={spec['args']}"]
        extra.setdefault("clock", 0)        # the runner's 00:00:00 (galaxy_case's DOS_CLOCK_AT_START_US)
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
        """The settled entries' positions (first and last left out)."""
        return [k for k in range(1, len(self.entries) - 1) if self.entries[k].reps >= least]


def screen_of(spec, t):
    name = "(before the first named screen)"
    for start, n in spec["screens"]:
        if t + 1e-9 >= start:
            name = n
    return name


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
            fails.append({"rule": "S1", "screen": screen_of(spec, e.at), "at": e.at,
                          "text": f"S1: the {where(port, k)}, is one the original never showed",
                          "detail": lambda k=k: explain(port, k, orig, f"S1_port{k}")})
    for k in os_:
        if od[k] not in pset:
            e = orig.entries[k]
            fails.append({"rule": "S2", "screen": screen_of(spec, e.at), "at": e.at,
                          "text": f"S2: the {where(orig, k)}, never shows in the port",
                          "detail": lambda k=k: explain(orig, k, port, f"S2_original{k}")})
    for side, sett in ((port, ps), (orig, os_)):
        distinct = len({side.entries[k].digest for k in sett})
        if distinct < spec["least"]:
            fails.append({"rule": "S3", "screen": "(the whole case)", "at": 0.0,
                          "text": f"S3: the {side.side} shows {distinct} different settled pictures; at least "
                                  f"{spec['least']} expected", "detail": None})
    # S4: time on show in all, for the original's settled pictures that it shows in one stretch (a screen
    # that stays up; not an animation's recurring frame, whose count of returns rests on timing, nor an
    # empty screen: a load's)
    if spec["stay"] is not None:
        ot, pt, stretches = {}, {}, {}
        for e in orig.entries:
            ot[e.digest] = ot.get(e.digest, 0) + e.reps
            stretches[e.digest] = stretches.get(e.digest, 0) + 1
        for e in port.entries:
            pt[e.digest] = pt.get(e.digest, 0) + e.reps
        ends = {od[0], od[-1], pd[0], pd[-1]}
        for k in os_:
            d = od[k]
            if stretches[d] > 1 or d in ends or d not in pt or _empty(orig.entries[k].frame()):
                continue
            if abs(ot[d] - pt[d]) > spec["stay"] + STAY_SHARE * ot[d]:
                e = orig.entries[k]
                fails.append({"rule": "S4", "screen": screen_of(spec, e.at), "at": e.at,
                              "text": f"S4: the {where(orig, k)}, is up {ot[d]} refreshes in all in the original, "
                                      f"{pt[d]} in the port", "detail": None})
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
                fails.append({"rule": "S5", "screen": screen_of(spec, e.at), "at": e.at,
                              "text": f"S5: the original shows its picture {so[x][0]} ({orig.entries[so[x][0]].at:.2f} s) "
                                      f"before its picture {so[y][0]} ({e.at:.2f} s); the port shows them the other way "
                                      f"round (its {sp[y][0]} at {port.entries[sp[y][0]].at:.2f} s, then its "
                                      f"{sp[x][0]} at {port.entries[sp[x][0]].at:.2f} s)", "detail": None})
    fails.sort(key=lambda f: f["at"])
    return fails


def report(spec, port, orig, fails, out_dir=None, every=False):
    """Lines: per named screen, PASS or FAIL with its first difference (`every`: all of them)."""
    lines = []
    least = spec["settled"]
    ps, os_ = port.settled(least), orig.settled(least)
    names = [n for _, n in spec["screens"]] or ["(the whole case)"]
    if any(screen_of(spec, orig.entries[k].at) == "(before the first named screen)" for k in os_) and spec["screens"]:
        names = ["(before the first named screen)"] + names
    for name in names + (["(the whole case)"] if "(the whole case)" not in names else []):
        mine = [f for f in fails if f["screen"] == name]
        if name == "(the whole case)" and not mine and spec["screens"]:
            continue
        no = len([k for k in os_ if screen_of(spec, orig.entries[k].at) == name or not spec["screens"]])
        npt = len([k for k in ps if screen_of(spec, port.entries[k].at) == name or not spec["screens"]])
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


def cell_class(c, a):
    """What a (character, attribute) pair must look like: ("solid", colour) for a cell of one colour (a
    blank, the full block, a character drawn in its background colour) or ("glyph", c, fg, bg), and whether
    it blinks (attribute bit 7, the VGA's default blink mode: 8 background colours; a blinking cell is
    shown or is its background alone)."""
    fg, bg = a & 15, (a >> 4) & 7
    blink = bool(a & 0x80)
    if c in BLANK_CHARS or fg == bg:
        return ("solid", bg), False
    if c in FULL_CHARS and not blink:
        return ("solid", fg), False
    return ("glyph", c, fg, bg), blink


def _cells(frame):
    h, w = frame.shape[:2]
    cw, ch = w // 80, h // 25
    return frame.reshape(25, ch, 80, cw, 3).swapaxes(1, 2), ch


def _colours(img):
    return {tuple(int(v) for v in c) for c in np.unique(img.reshape(-1, 3), axis=0)}


def text_problems(frame, cells, cursor, fonts=None, masked=frozenset(), cursors=None):
    """How one recorded text picture fails to be the port's 80x25 screen `cells` (character, attribute
    bytes), [] if it is. `cursor` (column, row): the port's cursor, left out, as are the `masked` cells
    ((row, column): the case's text masks). `fonts`: class -> look, kept across the pictures matched so far
    (the original's shapes never change). `cursors`: a set the recording's cursor is noted in, when it
    shows on another cell ((row, column) in the recording, (row, column) in the port)."""
    grid, ch = _cells(frame)
    groups, blinkers = {}, {}
    for r in range(25):
        for col in range(80):
            if (col, r) == tuple(cursor) or (r, col) in masked:
                continue
            k = 2 * (r * 80 + col)
            cls, blink = cell_class(cells[k], cells[k + 1])
            look = grid[r, col].tobytes()
            (blinkers if blink else groups).setdefault(cls, {}).setdefault(look, []).append((r, col))
    problems = []
    # one look per pair (one cell may differ from its pair's look in the last three rows: a cursor)
    majority = {}
    odd = []
    for cls, looks in groups.items():
        best = max(looks, key=lambda lk: len(looks[lk]))
        majority[cls] = best
        for lk, where in looks.items():
            if lk != best:
                odd += [(cls, lk, w) for w in where]
    if odd:
        cls, lk, (r, col) = odd[0]
        a = np.frombuffer(lk, np.uint8).reshape(ch, -1, 3)
        b = np.frombuffer(majority[cls], np.uint8).reshape(ch, -1, 3)
        rows = np.nonzero(np.any(a != b, axis=(1, 2)))[0]
        if len(odd) == 1 and rows.min() >= ch - 3:
            # the hardware cursor (its last scan lines, blinking): not a cell's character or colours
            if cursors is not None:
                cursors.add(((r, col), (cursor[1], cursor[0])))
        else:
            where = ", ".join(f"{w[0]}/{w[1]}" for _, _, w in odd[:8])
            problems.append(f"{len(odd)} cells look unlike others the port gives the same pair (row/column {where}"
                            f"{', ...' if len(odd) > 8 else ''}; the first holds {_pair_text(cls)} in the port)")
    # different pairs look different
    by_look = {}
    for cls, lk in majority.items():
        by_look.setdefault(lk, []).append(cls)
    for lk, classes in by_look.items():
        if len(classes) > 1:
            where = groups[classes[0]][lk][0]
            problems.append(f"pairs {_pair_text(classes[0])} and {_pair_text(classes[1])} look alike (row {where[0]} "
                            f"column {where[1]})")
            break
    # each pair's colours are its attribute's
    for cls, lk in majority.items():
        img = np.frombuffer(lk, np.uint8).reshape(ch, -1, 3)
        got = _colours(img)
        want = _want_colours(cls)
        if got != want:
            where = groups[cls][lk][0]
            problems.append(f"row {where[0]} column {where[1]} (pair {_pair_text(cls)}) shows colours "
                            f"{sorted(got)}, its attribute's are {sorted(want)}")
            break
    # blinking pairs: one look each, all in the same phase (shown, or their background alone)
    phases = set()
    for cls, looks in blinkers.items():
        if len(looks) > 1:
            where = next(iter(looks.values()))[0]
            problems.append(f"cells of the blinking pair {_pair_text(cls)} look unlike each other (row {where[0]} "
                            f"column {where[1]})")
            continue
        img = np.frombuffer(next(iter(looks)), np.uint8).reshape(ch, -1, 3)
        got = _colours(img)
        on = {TEXT_PALETTE[cls[2]]} if cls[1] in FULL_CHARS else _want_colours(cls)
        if got == on:
            phases.add("on")
        elif got == {TEXT_PALETTE[cls[3]]}:
            phases.add("off")
        else:
            where = next(iter(looks.values()))[0]
            problems.append(f"row {where[0]} column {where[1]} (blinking pair {_pair_text(cls)}) shows colours "
                            f"{sorted(got)}")
    if len(phases) > 1:
        problems.append("blinking cells shown and hidden in the same picture")
    if fonts is not None and not problems:
        for cls, lk in majority.items():
            if cls in fonts and fonts[cls] != lk:
                problems.append(f"pair {_pair_text(cls)} looks unlike it did on an earlier screen")
                break
    return problems


def _want_colours(cls):
    if cls[0] == "solid":
        return {TEXT_PALETTE[cls[1]]}
    return {TEXT_PALETTE[cls[2]], TEXT_PALETTE[cls[3]]}


def _pair_text(cls):
    if cls[0] == "solid":
        return f"(one colour, {cls[1]})"
    c = cls[1]
    shown = chr(c) if 32 <= c < 127 else f"{c:02X}h"
    return f"('{shown}', colours {cls[2]} on {cls[3]})"


def _learn(fonts, frame, cells, cursor, masked):
    grid, _ = _cells(frame)
    for r in range(25):
        for col in range(80):
            if (col, r) == tuple(cursor) or (r, col) in masked:
                continue
            k = 2 * (r * 80 + col)
            cls, blink = cell_class(cells[k], cells[k + 1])
            if not blink:
                fonts.setdefault(cls, grid[r, col].tobytes())


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


def compare_text(rec_seq, port_screens, masked=frozenset()):
    """The text screens, as the EGA pictures' S1, S2 and order: (failures, notes). Every settled text
    picture of the recording (up TEXT_SETTLED refreshes or more) is one of the port's screens, in order;
    every settled screen of the port is one the recording shows (for however long), in order. The
    recording's settled pictures before the first that is one of the port's screens are DOS's own (its
    prompt), and so are those after the last in a capture made after the program's EGA pictures (it quit)."""
    fails, notes, cursors = [], [], set()
    rec = [i for i in range(len(rec_seq)) if rec_seq.repeats(i) >= TEXT_SETTLED]
    port = [k for k, s in enumerate(port_screens) if s[0] >= TEXT_SETTLED]
    quit_from = _quit_start(rec_seq)
    # once the program has quit, DOS's prompt takes the bottom row (an exit screen leaves it free)
    after_quit = masked | {(24, c) for c in range(80)}
    memo = {}

    def problems(i, k, fonts=None):
        s = port_screens[k]
        m = after_quit if quit_from is not None and i >= quit_from else masked
        if fonts is not None:
            return text_problems(rec_seq.frame(i), s[1], s[2], fonts, m)
        if (i, k) not in memo:
            memo[(i, k)] = text_problems(rec_seq.frame(i), s[1], s[2], None, m, cursors)
        return memo[(i, k)]

    # the recording's settled pictures, each one of the port's screens (any), in order
    fonts, p, hits = {}, 0, []
    for i in rec:
        k = next((k for k in range(p, len(port_screens)) if not problems(i, k)), None)
        if k is not None and problems(i, k, fonts):
            k = None        # a shape unlike the same pair's on an earlier screen
        hits.append(k)
        if k is not None:
            p = k
            _learn(fonts, rec_seq.frame(i), port_screens[k][1], port_screens[k][2], masked)
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
            k, why = min(((k, problems(i, k)) for k in range(len(port_screens))), key=lambda x: len(x[1]))
            fails.append(f"text: the recording's text picture {i} (up {rec_seq.repeats(i)} refreshes) is none of the "
                         f"port's screens; nearest, the port's screen {k}: {why[0] if why else 'out of order'}")
    # the port's settled screens, each shown by the recording (any picture), in order
    last = -1
    for k in port:
        at = next((i for i in range(len(rec_seq)) if not problems(i, k)), None)
        if at is None:
            best = min(((i, problems(i, k)) for i in range(len(rec_seq))), key=lambda x: len(x[1]), default=None)
            detail = f"; nearest, the recording's text picture {best[0]}: {best[1][0]}" if best and best[1] else ""
            fails.append(f"text: the port's screen {k} (up {port_screens[k][0]} refreshes) is in no recorded text "
                         f"picture{detail}")
        elif at < last:
            fails.append(f"text: the port's screen {k} first shows in the recording at its text picture {at}, "
                         f"before the screen ahead of it (at {last})")
        else:
            last = at
    notes.append(f"text screens: {len(port)} settled in the port, {len(rec)} settled pictures in the recording "
                 f"({dos_before} before the first of the port's screens, DOS's prompt or a start-up screen the port "
                 f"does not show, and {dos_after} after the program quit, left out)"
                 + (f"; {len(masked)} cells masked" if masked else "")
                 + ("; after the program quit, DOS's prompt row (24) left out" if quit_from is not None else ""))
    for (rr, rc), (pr, pc) in sorted(cursors):
        notes.append(f"text: the original's cursor blinks at row {rr} column {rc}, the port's is at row {pr} "
                     f"column {pc} (not a cell's character or colours: not failed)")
    return fails, notes


# ------------------------------------------------------------------ commands

def oracle_view(game, case, spec, run="a"):
    folder = common.config()["oracle_runs"] / run_name(game, case, run)
    if not (folder / "frames" / "frames.json").exists():
        return None, folder
    return View(frames.Sequence(folder / "frames"), spec["masks"], spec["seconds"], "original"), folder


def check(game, case, run="a", tag="", no_run=False, every=False, say=print):
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
        code, pframes, ptext = run_port(game, case, pfolder, say)
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
            print(f"  {e.at:7.2f} s  up {e.reps / REFRESH_HZ:5.2f} s  picture {k:4d}  [{screen_of(spec, e.at)}]")
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
    """The comparison must fail on planted faults: one settled picture of the port altered by a pixel, one
    settled picture of the original left out of the port, and (with text screens) one cell's colour."""
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

    clean = compare(spec, fresh(), orig)
    print(f"  as recorded: {'PASS' if not clean else 'FAIL (' + clean[0]['text'] + ')'}")
    ok &= not clean
    # one pixel of a settled picture of the port turned to its opposite, outside every mask
    port = fresh()
    ks = port.settled(spec["settled"])
    k = ks[len(ks) // 2]
    e = port.entries[k]
    x, y = 160, 100
    while any(m["rect"][0] <= x < m["rect"][2] and m["rect"][1] <= y < m["rect"][3] for m in e.masks):
        y = (y + 37) % 200
    e.plant = (x, y)
    e.digest = hashlib.sha1(e.frame().tobytes()).hexdigest()
    got = compare(spec, port, orig)
    hit = any(f["rule"] == "S1" and f"picture {k} " in f["text"] for f in got)
    print(f"  planted: the port's picture {k} ({e.at:.2f} s) with one pixel changed: "
          f"{'reported (' + screen_of(spec, e.at) + ')' if hit else 'MISSED'}")
    ok &= hit
    # a settled picture of the original never shown by the port
    port = fresh()
    os_ = orig.settled(spec["settled"])
    target = orig.entries[os_[len(os_) // 2]]
    port.entries = [p for p in port.entries if p.digest != target.digest]
    got = compare(spec, port, orig)
    hit = any(f["rule"] == "S2" for f in got)
    print(f"  planted: the original's picture {os_[len(os_) // 2]} ({target.at:.2f} s) left out of the port: "
          f"{'reported (' + screen_of(spec, target.at) + ')' if hit else 'MISSED'}")
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
    ptext = pframes / "text_frames.json"
    rec_text = ofolder / "text_frames"
    if ptext.exists() and (rec_text / "frames.json").exists():
        shown = load_port_text(ptext)
        fails, _ = compare_text(frames.Sequence(rec_text), shown, text_masked(spec))
        print(f"  text screens as recorded: {'PASS' if not fails else 'FAIL (' + fails[0] + ')'}")
        ok &= not fails
        settled = [s for s in shown if s[0] >= TEXT_SETTLED]
        if settled:
            s = settled[len(settled) // 2]
            old = s[1]
            cells = bytearray(old)
            # the first cell showing a character: its foreground one colour on
            at = next(i for i in range(0, 4000, 2) if cell_class(cells[i], cells[i + 1])[0][0] == "glyph")
            cells[at + 1] = (cells[at + 1] & 0xF0) | (((cells[at + 1] & 15) + 1) & 15)
            for t in shown:
                if t[1] == old:
                    t[1] = bytes(cells)
            fails, _ = compare_text(frames.Sequence(rec_text), shown, text_masked(spec))
            print(f"  planted: one cell's colour changed in the port's text screen (row {at // 160}, column "
                  f"{at % 160 // 2}): {'reported' if fails else 'MISSED'}")
            ok &= bool(fails)
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
