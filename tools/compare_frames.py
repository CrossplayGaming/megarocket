# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""HARN-04: compare the port's frames with the original's, and one oracle run with another.
(Keen edition of the Duke project's comparator; the rules are the same.)

What the oracle recording contains
----------------------------------
DOSBox records one picture per display refresh (70 a second). Within one game
frame the original does this (Duke's WaitAndUpdatePlayer; Keen's RF_Refresh / VW_UpdateScreen do the same):

    wait about four refreshes        the finished previous frame is on screen
    run the game logic               the score, ammo and other HUD numbers are
                                     drawn STRAIGHT to the visible screen here
    draw the new playfield off-screen
    swap screens

So the recording holds, for each game frame, the finished picture (the one up
during the wait) and sometimes one or more in-between pictures: the old
playfield with a newer score, a screen flash part filled in, half of a tile.
How long each lasts depends on how long the emulated CPU took, and where a
refresh happened to fall, so durations are NOT a reliable way to tell the two
kinds apart: a finished picture can last two refreshes and an in-between one
three. Matching is therefore by content and order.

Comparing the port
------------------
The port writes the picture on its visible screen at every wait: the finished
picture of each game frame ("primaries"). It may also write pictures it knows
to be in-between states ("intermediates").

  R1  Every primary must appear in the recording, in order. A primary the
      original never shows is a failure, reported with a difference picture.
  R1a When the port shows the same picture for several game frames in a row
      (back-to-back screen flashes do this: the white screen stays up while
      the frames between are on screen too briefly to be recorded), the
      recording has them as one picture shown for longer. Such a run of
      identical primaries is matched as one, and its length is checked the
      only way it can be, by time: from the run's first appearance to the
      next primary's, the recording must span between HELD_MIN and HELD_MAX
      refreshes per game frame, give or take HELD_SLACK.
  R2  A recorded picture between two matched primaries must be a port
      intermediate for that game frame, or last no longer than EXTRA_MAX
      refreshes. Anything longer that the port cannot account for is a failure.

  R3  After the port's last primary of a stretch, the original must not go on
      showing the game: a recorded picture that still shows the in-game HUD,
      lasts longer than EXTRA_MAX refreshes, and is neither that last primary,
      one of its intermediates, nor the first primary of the next stretch, is
      a failure. This is what stops the port ending a level early.

R1 does not depend on timing at all. R2 and R3 are what stop the port skipping
game frames, and are the only places a duration is used.

Comparing two oracle runs
-------------------------
Two runs made with the same settings must agree on every picture lasting
SETTLED refreshes or more, from the first gameplay frame on.

Cannot catch: two wrongs that draw the same picture; a state the port skips
that the original showed for EXTRA_MAX refreshes or fewer and that does not
change any later picture; anything the demo route does not reach.

Usage:
  python tools/compare_frames.py selftest <oracle run A> <oracle run B>
  python tools/compare_frames.py oracle <run A> <run B>
  python tools/compare_frames.py port <port frames folder> <oracle run> [--out DIR]
"""

import argparse
import hashlib
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import common
import frames as framestore

SETTLED = 3             # refreshes, for comparing two oracle runs
EXTRA_MAX = 2           # refreshes an unexplained recorded picture may last (R2)
HELD_MIN = 4            # refreshes per game frame, least and most, for a picture
HELD_MAX = 6            # that the port shows for several game frames running (R1a)
HELD_SLACK = 2

# Which recorded pictures show the game being played is a per-engine question
# (Keen 1-3, Galaxy and Dreams have different HUDs); a predicate can be
# installed by the REPLAY units. Until then every picture counts, which
# leaves R3 strict (anything the original keeps showing after the port's
# last frame is a failure) and starts comparisons after the recording's cut
# first picture.
NAMES = {common.PASS: "PASS", common.FAIL: "FAIL", common.COULD_NOT_RUN: "COULD-NOT-RUN"}


def settled(seq, least=SETTLED):
    """Indices of frames lasting `least` refreshes or more, consecutive duplicates merged."""
    out = []
    for i in range(len(seq)):
        if seq.repeats(i) >= least and (not out or seq.digest(out[-1]) != seq.digest(i)):
            out.append(i)
    return out


IN_PLAY = None


def set_in_play(predicate):
    global IN_PLAY
    IN_PLAY = predicate


def shows_hud(frame):
    return True if IN_PLAY is None else IN_PLAY(frame)


def gameplay_start(seq, idx):
    """Position in `idx` of the first frame showing the game being played
    (the recording's first picture is cut by where recording began, so it
    never counts)."""
    for n, i in enumerate(idx):
        if i == 0:
            continue
        if shows_hud(seq.frame(i)):
            return n
    return None


def gameplay_segments(seq, gap=30):
    """Stretches of the recording that show the in-game HUD: one per level played.

    Returns a list of (first frame, last frame, number of settled frames). A
    stretch ends when the HUD has been off screen for `gap` refreshes.
    """
    out = []
    cur = None
    away = 0
    for i in range(len(seq)):
        if shows_hud(seq.frame(i)):
            if cur is None:
                cur = [i, i, 0]
            cur[1] = i
            away = 0
            if seq.repeats(i) >= SETTLED:
                cur[2] += 1
        elif cur is not None:
            away += seq.repeats(i)
            if away >= gap:
                out.append(tuple(cur))
                cur = None
    if cur is not None:
        out.append(tuple(cur))
    return out


LONG_LIVED = 4          # refreshes: a picture up this long is certainly a finished frame


def _long_lived(seq):
    """The pictures a run showed for LONG_LIVED refreshes or more, from gameplay on."""
    idx = settled(seq, LONG_LIVED)
    start = gameplay_start(seq, idx)
    if start is None:
        return None
    chosen = idx[start:]
    return PortFrames([seq.digest(i) for i in chosen], [0], lambda n: seq.frame(chosen[n]))


def compare_oracles(seq_a, seq_b):
    """Two runs with the same settings must show the same game.

    They must be the same length, and every picture one run kept up for
    LONG_LIVED refreshes or more must appear in the other, in the same order.
    Durations are not compared beyond that: whether an in-between picture is
    caught for one refresh or three varies from run to run.
    """
    long_a, long_b = _long_lived(seq_a), _long_lived(seq_b)
    if long_a is None or long_b is None:
        return common.COULD_NOT_RUN, "no gameplay frames found in one of the recordings"
    summary = (f"recorded frames: {seq_a.raw_frames} and {seq_b.raw_frames}; "
               f"long-lived gameplay pictures: {len(long_a.digests)} and {len(long_b.digests)}")
    if seq_a.raw_frames != seq_b.raw_frames:
        return common.FAIL, summary + "; the recordings differ in length"
    for label, port, other in (("first", long_a, seq_b), ("second", long_b, seq_a)):
        code, lines = compare_port(port, other, check_extras=False)
        if code != common.PASS:
            return common.FAIL, summary + f"; pictures of the {label} run are missing from the other: {lines[-1]}"
    return common.PASS, summary


class PortFrames:
    """The port's output.

    digests       one per written picture
    kinds         'P' (primary) or 'I' (intermediate) per picture
    level_starts  index of the first picture of each level
    loader        function(index) -> 200x320x3 array, for difference pictures
    """

    def __init__(self, digests, level_starts, loader, kinds=None):
        self.digests = digests
        self.kinds = kinds or ["P"] * len(digests)
        self.level_starts = level_starts
        self.loader = loader

    @classmethod
    def from_folder(cls, folder, rgb565=False):
        seq = framestore.Sequence(folder, rgb565=rgb565)
        starts = set(seq.meta.get("level_starts", [0]))
        kinds = seq.meta.get("kinds") or ["P"] * len(seq)
        # Two stored pictures can differ in a colour nothing uses and so look
        # identical. Consecutive identical pictures count once, as they do in
        # a recording of the original.
        digests, out_kinds, level_starts, source = [], [], [], []
        for i in range(len(seq)):
            digest = seq.digest(i)
            if i in starts:
                level_starts.append(len(digests))
            elif digests and digests[-1] == digest:
                if kinds[i] == "P":
                    out_kinds[-1] = "P"
                continue
            digests.append(digest)
            out_kinds.append(kinds[i])
            source.append(i)
        return cls(digests, level_starts or [0], lambda n: seq.frame(source[n]), out_kinds)

    def levels(self):
        """Per level: a list of (index of primary, set of intermediate digests that follow it)."""
        bounds = list(self.level_starts) + [len(self.digests)]
        out = []
        for n in range(len(bounds) - 1):
            level = []
            for i in range(bounds[n], bounds[n + 1]):
                if self.kinds[i] == "P":
                    level.append((i, set()))
                elif level:
                    level[-1][1].add(self.digests[i])
            out.append(level)
        return out


def _diff_picture(port_frame, oracle_frame, path):
    diff = np.any(port_frame != oracle_frame, axis=2)
    marked = oracle_frame.copy()
    marked[diff] = (255, 0, 255)
    sheet = np.concatenate([port_frame, oracle_frame, marked], axis=1)
    Image.fromarray(sheet).resize((sheet.shape[1] * 2, sheet.shape[0] * 2), Image.NEAREST).save(path)
    return int(diff.sum())


def _closest(oracle, frame, lo, hi):
    best, best_n = None, None
    for k in range(lo, min(hi, len(oracle))):
        n = int(np.any(oracle.frame(k) != frame, axis=2).sum())
        if best_n is None or n < best_n:
            best, best_n = k, n
    return best, best_n


def compare_port(port, oracle, out_dir=None, check_extras=True, check_end=True):
    """Returns (code, report lines). `check_extras=False` applies R1 only;
    `check_end=False` leaves out R3, for a port run stopped on purpose part-way."""
    lines = []
    o_digest = oracle.digests()
    o = 0                       # next recording frame to look at
    total_primaries = 0
    total_short = 0
    total_explained = 0
    for level, primaries in enumerate(port.levels()):
        label = f"level {level + 1}"
        if not primaries:
            lines.append(f"{label}: the port produced no frames")
            return common.FAIL, lines
        first = primaries[0][0]
        try:
            o = o_digest.index(port.digests[first], o)
        except ValueError:
            lines.append(f"{label}: the port's first frame never appears in the original")
            if out_dir is not None:
                pf = port.loader(first)
                best, best_n = _closest(oracle, pf, o, o + 1500)
                if best is not None:
                    path = Path(out_dir) / f"level{level + 1}_first_frame.png"
                    _diff_picture(pf, oracle.frame(best), path)
                    lines.append(f"  closest recorded frame is #{best} ({best_n} pixels differ); "
                                 f"picture (port, original, differences): {path}")
            return common.FAIL, lines
        short = explained = held = 0
        # R1a: primaries that repeat the one before them are counted with it.
        runs = []               # [index of the first primary, intermediates, game frames]
        for index, between in primaries:
            if runs and port.digests[runs[-1][0]] == port.digests[index]:
                runs[-1][1] |= between
                runs[-1][2] += 1
            else:
                runs.append([index, set(between), 1])
        frame_count = len(primaries)
        primaries = [(index, between) for index, between, _ in runs]
        first_frame = [0]
        for _, _, length in runs:
            first_frame.append(first_frame[-1] + length)
        for n in range(len(primaries) - 1):
            current, intermediates = primaries[n]
            want = port.digests[primaries[n + 1][0]]
            run_start = o
            o += 1
            while True:
                if o >= len(o_digest):
                    lines.append(f"{label}: the recording ends before game frame {first_frame[n + 1]} "
                                 f"of {frame_count}")
                    return common.FAIL, lines
                got = o_digest[o]
                if got == want:
                    break
                if got == port.digests[current] or got in intermediates:
                    explained += 1
                elif not check_extras or oracle.repeats(o) <= EXTRA_MAX:
                    short += 1
                else:
                    lines.append(
                        f"{label}: game frame {first_frame[n + 1]} of {frame_count} differs. The original "
                        f"shows a picture for {oracle.repeats(o)} refreshes (recording frame "
                        f"#{o}) that the port did not produce.")
                    if out_dir is not None:
                        path = Path(out_dir) / f"level{level + 1}_frame{first_frame[n + 1]}.png"
                        count = _diff_picture(port.loader(primaries[n + 1][0]), oracle.frame(o), path)
                        lines.append(f"  {count} pixels differ from the port's game frame "
                                     f"{first_frame[n + 1]}; picture (port, original, differences): {path}")
                    return common.FAIL, lines
                o += 1
            if runs[n][2] > 1:
                held += 1
                lasted = sum(oracle.repeats(i) for i in range(run_start, o))
                frames_held = runs[n][2]
                if check_extras and not (HELD_MIN * frames_held - HELD_SLACK <= lasted
                                         <= HELD_MAX * frames_held + HELD_SLACK):
                    lines.append(
                        f"{label}: the port shows one picture for {frames_held} game frames running "
                        f"(game frames {first_frame[n]} to {first_frame[n + 1] - 1} of {frame_count}); "
                        f"the original has it up for {lasted} refreshes (recording frame #{run_start}), "
                        f"which is not {frames_held} game frames' worth.")
                    return common.FAIL, lines
        if check_extras and check_end:
            # R3: the original must not go on playing after the port's last frame.
            last_index, last_intermediates = primaries[-1]
            levels = port.levels()
            next_first = (port.digests[levels[level + 1][0][0]]
                          if level + 1 < len(levels) and levels[level + 1] else None)
            k = o + 1
            while k < len(o_digest):
                got = o_digest[k]
                if got == port.digests[last_index] or got in last_intermediates:
                    k += 1
                    continue
                if got == next_first or not shows_hud(oracle.frame(k)):
                    break
                if oracle.repeats(k) > EXTRA_MAX:
                    lines.append(
                        f"{label}: the original went on playing after the port's last game frame "
                        f"({frame_count}): it shows a picture for {oracle.repeats(k)} refreshes "
                        f"(recording frame #{k}) that the port did not produce.")
                    if out_dir is not None:
                        path = Path(out_dir) / f"level{level + 1}_after_last_frame.png"
                        count = _diff_picture(port.loader(last_index), oracle.frame(k), path)
                        lines.append(f"  {count} pixels differ from the port's last game frame; "
                                     f"picture (port, original, differences): {path}")
                    return common.FAIL, lines
                short += 1
                k += 1
        lines.append(f"{label}: {frame_count} game frames match "
                     f"({explained} in-between pictures accounted for, {short} short ones skipped"
                     f"{f', {held} pictures held over several game frames' if held else ''})")
        total_primaries += frame_count
        total_short += short
        total_explained += explained
        o += 1
    lines.append(f"all {total_primaries} game frames match; in-between pictures: "
                 f"{total_explained} accounted for, {total_short} short ones skipped")
    return common.PASS, lines


def _stand_in_port(seq, least=SETTLED):
    """A stand-in for port output: one oracle run's own long-lasting frames of the first level."""
    idx = settled(seq, least)
    start = gameplay_start(seq, idx)
    chosen = []
    for i in idx[start:]:
        if not shows_hud(seq.frame(i)):
            break
        chosen.append(i)
    digests = [seq.digest(i) for i in chosen]
    return PortFrames(digests, [0], lambda n: seq.frame(chosen[n])), chosen


def selftest(run_a, run_b):
    root = common.config()["oracle_runs"]
    fa, fb = root / run_a / "frames", root / run_b / "frames"
    if not (fa / "frames.json").exists() or not (fb / "frames.json").exists():
        print("COULD-NOT-RUN: both oracle runs must have been decoded to frames first")
        return common.COULD_NOT_RUN
    a, b = framestore.Sequence(fa), framestore.Sequence(fb)
    ok = True

    def expect(label, got_code, want_code, detail=""):
        nonlocal ok
        good = got_code == want_code
        print(f"  {label}: expected {NAMES[want_code]}, got {NAMES[got_code]}"
              f"{'' if good else '   <-- WRONG'} {detail}")
        ok &= good

    def expect_named(lines, text):
        nonlocal ok
        named = any(text in line for line in lines)
        print(f"    report says '{text}': {'yes' if named else 'NO   <-- WRONG'}")
        ok &= named

    # 1. A recording against itself.
    code, text = compare_oracles(a, a)
    expect("recording against itself", code, common.PASS, f"({text})")

    # 2. A stand-in port sequence taken from run A, matched against run B.
    port, chosen = _stand_in_port(a)
    count = len(port.digests)
    code, lines = compare_port(port, b)
    expect(f"{count} long-lasting frames of run A found in order in run B",
           code, common.PASS, f"({lines[-1]})")
    target = count // 2

    # 3. Planted: one pixel changed in one frame, half-way through. The port's
    # frame is then never shown, and the original's real frame is unaccounted for.
    altered = a.frame(chosen[target]).copy()
    altered[100, 160] = (altered[100, 160].astype(int) + 85) % 256
    bad_digests = list(port.digests)
    bad_digests[target] = hashlib.sha1(altered.tobytes()).hexdigest()
    bad = PortFrames(bad_digests, [0], lambda n: altered if n == target else a.frame(chosen[n]))
    code, lines = compare_port(bad, b)
    expect("one altered pixel in one frame", code, common.FAIL)
    expect_named(lines, f"game frame {target} of {count}")

    # 4. Planted: the port skips a game frame.
    skipped = PortFrames(port.digests[:target] + port.digests[target + 1:], [0],
                         lambda n: a.frame(chosen[n if n < target else n + 1]))
    code, lines = compare_port(skipped, b)
    expect("port skips one game frame", code, common.FAIL)
    expect_named(lines, f"game frame {target} of {count - 1}")

    # 5. Planted: the port's very first frame is wrong.
    wrong_first = PortFrames(["0" * 40] + port.digests[1:], [0], lambda n: a.frame(chosen[n]))
    code, lines = compare_port(wrong_first, b)
    expect("port's first frame never shown by the original", code, common.FAIL)
    expect_named(lines, "first frame never appears")

    # 6. Planted: the port invents an extra game frame.
    extra = PortFrames(port.digests[:target] + ["f" * 40] + port.digests[target:], [0],
                       lambda n: a.frame(chosen[min(n, len(chosen) - 1)]))
    code, lines = compare_port(extra, b)
    expect("port invents an extra game frame", code, common.FAIL)
    expect_named(lines, f"game frame {target} of {count + 1}")

    # 7. The skipped frame of case 4 is accepted once the port lists it as an
    # in-between picture: R2's "accounted for" route works.
    kinds = ["P"] * count
    kinds[target] = "I"
    declared = PortFrames(port.digests, [0], lambda n: a.frame(chosen[n]), kinds)
    code, lines = compare_port(declared, b)
    expect("skipped frame declared as an in-between picture", code, common.PASS, f"({lines[-1]})")
    ok &= "1 accounted for" in lines[-1] or " accounted for" in lines[-1]

    # 7b. Planted: the port stops ten game frames before the original does (R3).
    early = PortFrames(port.digests[:count - 10], [0], lambda n: a.frame(chosen[n]))
    code, lines = compare_port(early, b)
    expect("port ends the level ten game frames early", code, common.FAIL)
    expect_named(lines, "went on playing")

    # 7c. R1a: one picture shown for several game frames running, which the
    # recording has as one longer picture. Made-up sequences: letters stand
    # for pictures, numbers for how many refreshes the recording shows each.
    class MadeUp:
        def __init__(self, pictures):
            self.pictures = pictures
        def __len__(self): return len(self.pictures)
        def repeats(self, i): return self.pictures[i][1]
        def digest(self, i): return self.pictures[i][0]
        def digests(self): return [name for name, _ in self.pictures]
        def frame(self, i): return np.zeros((200, 320, 3), dtype=np.uint8)

    def made_up_port(text):
        """'a b x b y b c' with kinds 'P P I P I P P'."""
        names, kinds = text
        return PortFrames(names.split(), [0], lambda n: np.zeros((200, 320, 3), dtype=np.uint8), kinds.split())

    flashes = made_up_port(("a b x b y b c", "P P I P I P P"))
    code, lines = compare_port(flashes, MadeUp([("a", 4), ("b", 12), ("c", 4)]), check_end=False)
    expect("a picture held for three game frames, recorded as one of 12 refreshes", code, common.PASS, f"({lines[-1]})")
    expect_named(lines, "1 pictures held")
    code, lines = compare_port(flashes, MadeUp([("a", 4), ("b", 4), ("x", 1), ("b", 3), ("b2", 1), ("b", 4), ("c", 4)]),
                               check_end=False)
    expect("the same, recorded as three showings with brief pictures between", code, common.PASS, f"({lines[-1]})")
    code, lines = compare_port(flashes, MadeUp([("a", 4), ("b", 4), ("c", 4)]), check_end=False)
    expect("planted: the port holds a picture for three game frames, the original for one", code, common.FAIL)
    expect_named(lines, "not 3 game frames' worth")
    code, lines = compare_port(flashes, MadeUp([("a", 4), ("b", 40), ("c", 4)]), check_end=False)
    expect("planted: the port holds a picture for three game frames, the original for ten", code, common.FAIL)
    expect_named(lines, "not 3 game frames' worth")
    twice = made_up_port(("a b x b c", "P P I P P"))
    code, lines = compare_port(twice, MadeUp([("a", 4), ("b", 5), ("c", 4)]), check_end=False)
    expect("planted: the port repeats a game frame the original shows once", code, common.FAIL)
    expect_named(lines, "not 2 game frames' worth")

    # 8. Planted: oracle-against-oracle must notice a settled frame changed in one run.
    class Tampered:
        def __init__(self, seq, at):
            self.seq, self.at = seq, at
            self.raw_frames = seq.raw_frames
        def __len__(self): return len(self.seq)
        def repeats(self, i): return self.seq.repeats(i)
        def digest(self, i): return "e" * 40 if i == self.at else self.seq.digest(i)
        def digests(self): return [self.digest(i) for i in range(len(self.seq))]
        def frame(self, i): return self.seq.frame(i)
    # The tampered picture must be one that counts: up for LONG_LIVED refreshes.
    long_lived = [i for i in chosen if a.repeats(i) >= LONG_LIVED]
    tampered_at = long_lived[len(long_lived) // 2]
    code, text = compare_oracles(a, Tampered(a, tampered_at))
    expect("a long-lived frame altered in one of two recordings", code, common.FAIL, f"({text})")

    # 9. Planted: two recordings of different length (an interrupted attract loop).
    class Shorter(Tampered):
        def __init__(self, seq):
            super().__init__(seq, -1)
            self.raw_frames = seq.raw_frames - 700
    code, text = compare_oracles(a, Shorter(a))
    expect("recordings of different length", code, common.FAIL, f"({text})")

    print("PASS" if ok else "FAIL")
    return common.PASS if ok else common.FAIL


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("selftest", "oracle"):
        s = sub.add_parser(name)
        s.add_argument("run_a")
        s.add_argument("run_b")
    p = sub.add_parser("port")
    p.add_argument("port_frames")
    p.add_argument("oracle_run")
    p.add_argument("--out")
    args = ap.parse_args()
    root = common.config()["oracle_runs"]
    if args.cmd == "selftest":
        sys.exit(selftest(args.run_a, args.run_b))
    if args.cmd == "oracle":
        a = framestore.Sequence(root / args.run_a / "frames")
        b = framestore.Sequence(root / args.run_b / "frames")
        code, text = compare_oracles(a, b)
        print(text)
        print(NAMES[code])
        sys.exit(code)
    oracle = framestore.Sequence(root / args.oracle_run / "frames")
    port = PortFrames.from_folder(args.port_frames)
    out = args.out
    if out:
        Path(out).mkdir(parents=True, exist_ok=True)
    code, lines = compare_port(port, oracle, out)
    print("\n".join(lines))
    print(NAMES[code])
    sys.exit(code)


if __name__ == "__main__":
    main()
