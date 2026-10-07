# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""The regression set: every check that has ever passed, run together.

  python tools/regress.py --fast        after every unit (no DOSBox runs)
  python tools/regress.py --full        at group boundaries
  python tools/regress.py <unit id>...  just those checks

A check returns PASS, FAIL or COULD-NOT-RUN. COULD-NOT-RUN (missing game files,
missing oracle recordings, a broken test script) is reported separately and
makes the whole run fail, because an unrun check proves nothing.
"""

import sys
import time

import common
import frames

NAMES = common.NAMES

# Games whose boot the oracle self-test records, one per engine.
BOOT_GAMES = ("keen1", "keen4", "kdreams")


def _oracle_pair(game, case):
    """Two recordings of the same case, made (or reused if present) as <game>_<case>_a / _b."""
    import oracle_decode
    import oracle_run
    root = common.config()["oracle_runs"]
    runs = []
    for suffix in ("a", "b"):
        name = f"{game}_{case}_{suffix}"
        if not (root / name / "frames" / "frames.json").exists():
            code, _ = oracle_run.run(game, case, run_name=name)
            if code != common.PASS:
                return code, None
            if oracle_decode.decode(name) != common.PASS:
                return common.FAIL, None
        runs.append(frames.Sequence(root / name / "frames"))
    return common.PASS, runs


def harn01a():
    """Two oracle runs of the same case give the same recorded length and the
    same ordered sequence of pictures held three refreshes or more."""
    worst = common.PASS
    for game in BOOT_GAMES:
        if not common.game_files(game):
            print(f"  {game}: COULD-NOT-RUN (no game files)")
            return common.COULD_NOT_RUN
        code, runs = _oracle_pair(game, "boot")
        if code != common.PASS:
            return code
        a, b = runs
        # The first and last pictures are cut by where the recording starts
        # and stops (a few refreshes either way), so their hold counts are
        # not the game's; they are left out of the comparison.
        held_a = [a.digest(i) for i in range(1, len(a) - 1) if a.repeats(i) >= 3]
        held_b = [b.digest(i) for i in range(1, len(b) - 1) if b.repeats(i) >= 3]
        same = held_a == held_b
        length_ok = abs(a.raw_frames - b.raw_frames) <= 3
        unique = len(set(held_a))
        print(f"  {game}: {a.raw_frames}/{b.raw_frames} recorded, {len(held_a)}/{len(held_b)} held pictures "
              f"({unique} different): {'identical in order' if same else 'DIFFERENT'}; "
              f"length {'agrees' if length_ok else 'DIFFERS'}")
        # The comparison must be able to fail: plant one altered picture.
        tampered = list(held_b)
        if tampered:
            tampered[len(tampered) // 2] = "0" * 40
        noticed = held_a != tampered
        print(f"  {game}: planted one altered picture: {'noticed' if noticed else 'MISSED'}")
        if not (same and length_ok and noticed and unique >= 2):
            worst = common.FAIL
    return worst


def harn03a():
    """Godot writes a known pattern through FrameWriter; Python regenerates it and reads the store back."""
    import shutil
    import tempfile
    from pathlib import Path
    import gdtest
    import numpy as np

    def pattern(seed):
        out = bytearray(frames.FRAME_BYTES)
        x = seed
        for i in range(frames.FRAME_BYTES):
            x = (x * 1103515245 + 12345) & 0x7FFFFFFF
            out[i] = (x >> 16) & 0xFF
        return np.frombuffer(bytes(out), dtype=np.uint8).reshape(frames.HEIGHT, frames.WIDTH, 3)

    want_seeds = [1, 2, 3, 4, 5, 5, 6, 7, 8]
    want_kinds = ["P", "P", "I", "P", "P", "P", "P", "I", "P"]
    want_repeats = [1, 2, 1, 1, 2, 1, 1, 1, 1]
    want_starts = [0, 5]
    patterns = {seed: pattern(seed) for seed in set(want_seeds)}

    def read_back(folder):
        seq = frames.Sequence(folder)
        problems = []
        if len(seq) != len(want_seeds):
            return [f"entry count {len(seq)}, want {len(want_seeds)}"]
        for i, seed in enumerate(want_seeds):
            if not np.array_equal(seq.frame(i), patterns[seed]):
                problems.append(f"pixels of entry {i}")
            if seq.repeats(i) != want_repeats[i]:
                problems.append(f"repeat count of entry {i}")
        if seq.meta.get("kinds") != want_kinds:
            problems.append(f"kinds {seq.meta.get('kinds')}")
        if seq.meta.get("level_starts") != want_starts:
            problems.append(f"level starts {seq.meta.get('level_starts')}")
        if seq.raw_frames != 12:
            problems.append(f"raw frame count {seq.raw_frames}")
        return problems

    tmp = Path(tempfile.mkdtemp(prefix="harn03_"))
    try:
        code, _ = gdtest.run("harn03_frame_writer", [f"--out={tmp / 'clean'}"])
        if code != common.PASS:
            return code
        problems = read_back(tmp / "clean")
        print(f"  read back by Python: {'identical to the pattern' if not problems else problems}")
        if problems:
            return common.FAIL
        code, _ = gdtest.run("harn03_frame_writer", [f"--out={tmp / 'planted'}", "--plant=9"], quiet=True)
        if code != common.PASS:
            return common.COULD_NOT_RUN
        problems = read_back(tmp / "planted")
        noticed = problems == ["pixels of entry 6"]
        print(f"  planted one altered pixel: {'noticed, in that picture only' if noticed else 'WRONG: ' + str(problems)}")
        return common.PASS if noticed else common.FAIL
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def harn04a():
    """The frame comparator's self-test on two decoded oracle runs of the same case."""
    import compare_frames
    root = common.config()["oracle_runs"]
    for run in ("keen1_boot_a", "keen1_boot_b"):
        if not (root / run / "frames" / "frames.json").exists():
            print(f"COULD-NOT-RUN: {run} is not decoded (python tools/regress.py HARN-01a makes it)")
            return common.COULD_NOT_RUN
    return compare_frames.selftest("keen1_boot_a", "keen1_boot_b")


def harn12a():
    import check_clean
    code = check_clean.selftest()
    if code != common.PASS:
        return code
    return check_clean.check()[0]


def native01():
    import subprocess
    import sys as _sys
    for args in (["tools/build_native.py"], ["tools/build_native.py", "--selftest"]):
        done = subprocess.run([_sys.executable, *args], cwd=str(common.ROOT), capture_output=True, text=True)
        print(done.stdout.rstrip())
        if done.returncode != 0:
            return done.returncode
    return common.PASS


CHECKS = {
    "HARN-01a": (harn01a, "slow"),
    "HARN-03a": (harn03a, "fast"),
    "HARN-04a": (harn04a, "fast"),
    "HARN-12a": (harn12a, "fast"),
    "NATIVE-01": (native01, "fast"),
}


def main():
    args = sys.argv[1:]
    fast = "--fast" in args
    full = "--full" in args
    ids = [a for a in args if not a.startswith("--")]
    if not ids:
        ids = [k for k, (_, kind) in CHECKS.items() if full or (fast and kind == "fast")]
    results = {}
    started = time.time()
    for unit in ids:
        if unit not in CHECKS:
            print(f"{unit}: no such check")
            results[unit] = common.COULD_NOT_RUN
            continue
        print(f"== {unit}")
        fn, _ = CHECKS[unit]
        try:
            results[unit] = fn()
        except Exception as error:      # a broken check proves nothing
            print(f"  check raised {type(error).__name__}: {error}")
            results[unit] = common.COULD_NOT_RUN
        print(f"{unit}: {NAMES[results[unit]]}")
    print(f"-- {len(results)} checks in {time.time() - started:.0f} s: "
          + ", ".join(f"{k} {NAMES[v]}" for k, v in results.items()))
    sys.exit(max(results.values(), default=common.COULD_NOT_RUN))


if __name__ == "__main__":
    main()
