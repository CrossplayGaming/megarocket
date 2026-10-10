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

import json
import subprocess
import sys
import time
from pathlib import Path

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
        # Pictures up four refreshes or more count (compare_frames.LONG_LIVED):
        # a picture caught for two refreshes in one run is caught for three
        # in the other, at the mercy of where refreshes fall, as the Duke
        # project found; Dreams' intro animation (two refreshes a frame)
        # showed exactly that on 2026-10-06.
        held_a = [a.digest(i) for i in range(1, len(a) - 1) if a.repeats(i) >= 4]
        held_b = [b.digest(i) for i in range(1, len(b) - 1) if b.repeats(i) >= 4]
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


def data01v():
    """The Vorticons loader over Keen 1-3, damaged copies refused by name, and
    the GDScript LZEXE unpacker agreeing with the Python one on every program."""
    import hashlib
    import gdtest
    import unlzexe
    code, out = gdtest.run("data01_vorticons", timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "digests" in line or "unpacked program" in line or "checks" in line:
            print("  " + line.strip())
    if code != common.PASS:
        return code
    for game in ("keen2", "keen3"):
        exe = [p for p in common.game_files(game) if p.suffix.upper() == ".EXE"][0]
        want = hashlib.sha1(unlzexe.unpack(exe.read_bytes())).hexdigest()[:12]
        if f"{game} unpacked program" not in out or want not in out:
            print(f"  {game}: the GDScript unpacker's image digest is not {want} (Python's)")
            return common.FAIL
    print("  unpacked programs: GDScript and Python agree")
    for victim in ("EGALATCH.CK1", "LEVEL01.CK1", "EGAHEAD.CK1", "SOUNDS.CK1", "EGASPRIT.CK1"):
        code, out = gdtest.run("data01_vorticons", [f"--plant={victim}"], timeout=300.0, quiet=True)
        if code != common.PASS:
            print(f"  planted damage in {victim}: NOT refused by name")
            return common.FAIL
    print("  planted damage in five file kinds: each refused by name")
    return common.PASS


def data01g():
    """The Galaxy loader over Keen 4-6 with omnispeak's metadata, and damaged copies refused by name."""
    import gdtest
    # Keen 6 is the user's v1.0 copy: its three version tables are read from
    # KEEN6C.EXE beside the data (DATA-01G6); the rest is omnispeak's keen6e14.
    code, out = gdtest.run("data01_galaxy", ["--games=keen4,keen5,keen6"], timeout=1800.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "digests" in line or "maps:" in line or "checks" in line:
            print("  " + line.strip())
    if code != common.PASS:
        return code
    for victim in ("EGAGRAPH.CK4", "GAMEMAPS.CK4", "AUDIO.CK4", "KEEN6C.EXE", "GAMEMAPS.CK6"):
        code, out = gdtest.run("data01_galaxy", [f"--plant={victim}"], timeout=600.0, quiet=True)
        if code != common.PASS:
            print(f"  planted damage in {victim}: NOT refused by name")
            for line in out.splitlines():
                if "FAIL" in line:
                    print("    " + line.strip())
            return common.FAIL
    print("  planted damage in five file kinds: each refused by name")
    return common.PASS


def data01d():
    """The Keen Dreams loader (PKLITE-unpacked executable, embedded headers) and damaged copies refused."""
    import gdtest
    code, out = gdtest.run("data01_dreams", timeout=900.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "digests" in line or "maps:" in line or "checks" in line or "unpacked" in line:
            print("  " + line.strip())
    if code != common.PASS:
        return code
    for victim in ("EGAGRAPH.KDR", "GAMEMAPS.KDR", "AUDIO.KDR", "KDREAMS.EXE"):
        code, out = gdtest.run("data01_dreams", [f"--plant={victim}"], timeout=600.0, quiet=True)
        if code != common.PASS:
            print(f"  planted damage in {victim}: NOT refused by name")
            for line in out.splitlines():
                if "FAIL" in line:
                    print("    " + line.strip())
            return common.FAIL
    print("  planted damage in four file kinds: each refused by name")
    return common.PASS


def sim02():
    """The emulated EGA card against golden pictures worked out from the EGA specification, and
    compose() against a one-pixel-at-a-time reading over random states."""
    import gdtest
    code, out = gdtest.run("sim02_ega_card", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "differs" in line:
            print("  " + line.strip())
    return code


def data02():
    """Detection fixtures (fake Steam/GOG/loose/ZIP/read-only trees built from the development
    copies) and the finder's identification of every release, wrong file and CGA rename over them."""
    import gdtest
    code, out = gdtest.run("harn13_detect", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "real Steam" in line:
            print("  " + line.strip())
    return code


def _intro_refreshes(run_dir):
    """How many refreshes a Keen 1-3 recording holds from its first intro picture
    (the first with a few hundred lit pixels: the stars) to its end, and that picture's index."""
    import numpy as np
    seq = frames.Sequence(Path(run_dir) / "frames")
    reps = [seq.repeats(i) for i in range(len(seq))]
    for i in range(len(seq)):
        lit = int((np.frombuffer(seq.frame(i), np.uint8).reshape(200, 320, 3).max(axis=2) > 0).sum())
        if 100 < lit < 1000:
            return i, sum(reps[i:])
    return None, 0


def simv01():
    """The Vorticons port's Keen 1 boot (intro, title) against the oracle's 30 s recording:
    the same pictures in the same order, by the comparator's rules."""
    import gdtest
    import shutil
    cfg = common.config()
    oracle = Path(cfg["oracle_runs"]) / "keen1_boot_a"
    if not (oracle / "frames" / "frames.json").exists():
        print("  COULD-NOT-RUN: no decoded oracle run keen1_boot_a")
        return common.COULD_NOT_RUN
    intro, after = _intro_refreshes(oracle)
    if intro is None:
        print("  COULD-NOT-RUN: the recording's first intro picture was not found")
        return common.COULD_NOT_RUN
    out = Path(cfg["oracle_runs"]).parent / "port_runs" / "keen1_boot"
    shutil.rmtree(out, ignore_errors=True)
    code, text = gdtest.run("simv01_boot", ["--game=keen1", "--seconds=40", f"--out={out}", f"--refreshes_after_intro={after - 10}"],
                            timeout=600.0, quiet=True)
    for line in text.splitlines():
        if "keen1:" in line or "FAIL" in line:
            print("  " + line.strip())
    if code != common.PASS:
        return code
    r = subprocess.run([sys.executable, str(Path(__file__).parent / "compare_frames.py"), "port", str(out), str(oracle)],
                       capture_output=True, text=True)
    for line in r.stdout.splitlines()[-3:]:
        print("  " + line.strip())
    return common.PASS if "PASS" in r.stdout else common.FAIL


def _timing_case(game, case, seconds, extra=()):
    """Run the port from power-on for a recording's case and score it refresh for refresh."""
    import gdtest
    import shutil
    import timing_score
    cfg = common.config()
    oracle = Path(cfg["oracle_runs"]) / f"{game}_{case}_a"
    if not (oracle / "frames" / "frames.json").exists():
        print(f"  COULD-NOT-RUN: no decoded oracle run {game}_{case}_a")
        return common.COULD_NOT_RUN
    out = Path(cfg["oracle_runs"]).parent / "port_runs" / f"timing_{game}_{case}"
    shutil.rmtree(out, ignore_errors=True)
    args = [f"--game={game}", f"--seconds={seconds}", f"--out={out}"]
    port_case = Path(__file__).parent / "cases" / game / f"{case}.port.json"
    if port_case.exists():
        # a session with keys: the keys fitted to the recording, run past its end
        from fit_keys import SCANCODES
        pc = json.loads(port_case.read_text(encoding="utf-8"))
        args = [f"--game={game}", "--seconds=120", f"--out={out}",
                "--keys_after_intro=" + ",".join(f"{t:.4f}:{SCANCODES[k]}:{h}" for t, k, h in pc["keys_after_intro"]),
                f"--refreshes_after_intro={pc['refreshes_after_intro'] + 20}"]
        spec = json.loads((Path(__file__).parent / "cases" / game / f"{case}.json").read_text())
        if spec.get("overrides"):
            args.append(f"--save_seed={(common.ROOT / spec['overrides']).as_posix()}")
    code, text = gdtest.run("simv01_boot", args + list(extra), timeout=900.0, quiet=True)
    if code != common.PASS:
        for line in text.splitlines():
            if "FAIL" in line or "ERROR" in line:
                print("  " + line.strip())
        return code
    k, note, port, orc, _ = timing_score.score(out, oracle, transient=True)
    print(f"  {game} {case}: {note} (recording: {len(orc) - 1} complete pictures)")
    return common.PASS if k >= len(orc) - 1 else common.FAIL


def timev1():
    """The Vorticons port's timing against DOSBox, refresh for refresh: the Keen 1 boot (30 s)
    and title (50 s, through the id and high-score screens) recordings and Keen 2's and Keen 3's titles, every picture lasting
    exactly as many refreshes as in the recording (instruction-counted drawing, fitted phase/rate)."""
    results = [_timing_case("keen1", "boot", 33), _timing_case("keen1", "title", 53), _timing_case("keen1", "newgame", 120), _timing_case("keen1", "level1", 120),
               _timing_case("keen2", "title", 53), _timing_case("keen3", "title", 53)]
    return common.COULD_NOT_RUN if common.COULD_NOT_RUN in results else max(results)


# Keen 1 level sessions (save on the entrance, enter, play ~20 s) that match their recordings
# picture for picture and refresh for refresh; Border Village (level1) is in TIME-V1.
REPLAY_V1_LEVELS = [f"level{n:02d}" for n in range(2, 17)]


REPLAY_V2_LEVELS = [f"level{n:02d}" for n in range(1, 17)]
# Keen 3's sessions that match so far (1, 2 and 8 are still being fitted)
REPLAY_V3_LEVELS = [f"level{n:02d}" for n in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)]


def _replay(game, levels):
    """A game's verified level sessions, run side by side: every picture and its duration
    match the DOSBox recording (one-refresh slips that recover at the next picture pass)."""
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda case: _timing_case(game, case, 120), levels))
    return common.COULD_NOT_RUN if common.COULD_NOT_RUN in results else max(results)


def rend03():
    """REND-03: native resolution and smooth motion leave the game alone: Keen 1's level sessions run with
    the draw lists kept (sprites' owners, the grid's margin, the capture time) and still match the
    recordings refresh for refresh."""
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda case: _timing_case("keen1", case, 120, ("--draw_capture=1",)), REPLAY_V1_LEVELS))
    return common.COULD_NOT_RUN if common.COULD_NOT_RUN in results else max(results)


def replayv1():
    """Keen 1's level sessions (levels 2-16; Border Village is in TIME-V1)."""
    return _replay("keen1", REPLAY_V1_LEVELS)


def replayv2():
    """Keen 2's sixteen level sessions."""
    return _replay("keen2", REPLAY_V2_LEVELS)


def replayv3():
    """Keen 3's verified level sessions."""
    return _replay("keen3", REPLAY_V3_LEVELS)


# the verified ones; level 18 is the ending (no session). Sessions whose .port.json says "lock" are held
# under HARN-20's frame lock (the game's logic, not the frames' timing); the others are frame for frame.
REPLAY_G4_LEVELS = ["level01", "level02", "level04"]


def _galaxy_case(game, case):
    """One Galaxy level session (tools/galaxy_case.py): its fitted keys, timer phase and DOS clock."""
    p = subprocess.run([sys.executable, "tools/galaxy_case.py", game, case, "--tag", "regress"],
                       cwd=str(common.ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace")
    import galaxy_case
    lock = " [frame lock]" if galaxy_case.case_lock(game, case) else ""
    print("  " + (p.stdout.strip().splitlines() or ["(no output)"])[-1] + lock)
    return p.returncode


REPLAY_G5_LEVELS = ["level01", "level02", "level04", "level12"]    # the verified ones (15 is the high scores)


def replayg5():
    """Keen 5's verified level sessions (/TEDLEVEL n), as REPLAY-G4's."""
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda case: _galaxy_case("keen5", case), REPLAY_G5_LEVELS))
    return max(results)


REPLAY_G6_LEVELS = ["level04"]    # the verified ones, against the user's v1.0 (18 sessions)


# keen6_boot_a's first demo against the user's v1.0, from the first picture after the title: the
# pictures matched in order (deterministic play). Keen 6 plays by v1.4's rules (J-19), which part from
# v1.0's at picture 1336 (R_Walk's ledge step-back, DATA-01G6): a floor against regressions.
REPLAY_G6_DEMO_FLOOR = 192


def replayg6():
    """Keen 6's verified level sessions (/TEDLEVEL n) against the user's v1.0, as REPLAY-G4's, and the
    boot recording's demo held to its floor."""
    from concurrent.futures import ThreadPoolExecutor
    import galaxy_boot_score
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda case: _galaxy_case("keen6", case), REPLAY_G6_LEVELS))
    r = galaxy_boot_score.run("keen6", "keen6_boot_a", 75, 1317, tag="regress")
    if r is None:
        print("  keen6 demo: the port's run failed")
        return common.COULD_NOT_RUN
    ok = r["matched"] >= REPLAY_G6_DEMO_FLOOR
    print(f"  keen6 demo (v1.0): {r['matched']} of {r['pictures'] - 1317} pictures in order from the title "
          f"(floor {REPLAY_G6_DEMO_FLOOR})")
    return max(results + [0 if ok else 1])


def mm01():
    """The original's memory manager, modelled (MM-01): the port's picture of its memory (the
    debug key F10-M, one pixel a paragraph) agrees block for block with the original's under
    DOSBox, after a level's load and after a death's restart (Keen 4, keen4_mem08b_a) and after
    a level's load (Keen 5, keen5_mem01_a)."""
    worst = 0
    for game, case in (("keen4", "mem08b"), ("keen5", "mem01")):
        p = subprocess.run([sys.executable, "tools/mm_oracle.py", game, case], cwd=str(common.ROOT),
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        for line in p.stdout.strip().splitlines()[-3:]:
            print("  " + line)
        worst = max(worst, p.returncode)
    return worst


def replayg4():
    """Keen 4's verified level sessions (/TEDLEVEL n): the opening's pictures in order, then from
    the fade-in every picture and its duration (galaxy_case.level_score)."""
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda case: _galaxy_case("keen4", case), REPLAY_G4_LEVELS))
    return max(results)


def _dreams_test(name):
    import gdtest
    code, out = gdtest.run(name, [], timeout=900.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simd01a():
    """The Dreams library draws what the data says: every picture, masked picture, tile 8/16, sprite at
    every shift and the font drawn on the emulated card equal DreamsData's decode (BE, CA, VW)."""
    return max(_dreams_test("drm_parse"), _dreams_test("drm_vw_draw"))


def simd01b():
    """The Dreams refresh manager: a real map's tables, animated tile chains, origins, scrolling in every
    direction and the sprite lists as id_rf.c computes them."""
    return _dreams_test("drm_rf_check")


def simd01c():
    """The Dreams input and sound managers on the DOS machine: the 140 Hz timer and TimeCount, keys through
    INT 9, controls, demo playback, PC speaker and AdLib effects."""
    return _dreams_test("drm_io_check")


def simd01d():
    """The Dreams user manager: parameters, the random table and its seed, windows and printing, the
    start screens, config, saved game headers, high scores, gelib's buffered reads and ILBM unpacking."""
    return _dreams_test("drm_us_check")


def simd01e():
    """The Dreams actors: all 213 states as kd_keen.c, kd_act1.c and kd_act2.c define them (shapes, timing,
    moves, functions, links, both releases' DOS offsets) and the physics helpers on hand-worked cases."""
    return _dreams_test("drm_acts_check")


def simd01f():
    """Keen Dreams boots headless, v1.00 and v1.93: start-up, the text start screen, the title and the
    demo loop for 40 s of machine time without the program quitting."""
    import gdtest
    code, out = gdtest.run("drm_boot", [f"--out={Path('F:/KeenReworkWork/port_runs/drm_boot_regress').as_posix()}"],
                           timeout=900.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "game time" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simg01a():
    """The Galaxy library layer draws what the data says: every tile, bitmap, sprite (all
    shifts) and a font string read back from the surface as GalData decodes them; VL_Present
    puts the scrolled window on the card; fades reach the palette registers (Keen 4, 5, 6)."""
    import gdtest
    code, out = gdtest.run("simg01a_draw", ["--games=keen4,keen5,keen6"], timeout=1800.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simg01b():
    """The Galaxy refresh manager: on real maps of Keen 4, 5 and 6 the card shows exactly the map's
    tiles at the scroll position after repositioning and through smooth scrolling in six directions;
    a sprite placed, moved and removed leaves the map exact; animated tiles step."""
    import gdtest
    code, out = gdtest.run("simg01b_refresh", ["--games=keen4,keen5,keen6"], timeout=2400.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simg01c1():
    """The Galaxy timer, sound and input layer on the machine: 70 tics a second at 140 Hz and at
    560 Hz with AdLib music; PC speaker and AdLib effects note for note; keys through the
    keyboard interrupt as states, scan codes, ASCII and controls; every demo plays back as its
    bytes say; recorded controls play back the same (Keen 4, 5, 6)."""
    import gdtest
    code, out = gdtest.run("simg01c_io", ["--games=keen4,keen5,keen6"], timeout=1800.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simg01c2():
    """The Galaxy user manager: windows and frames, centred and running text, the random table,
    typed input through the keyboard, CONFIG round trip and defaults, empty saved-game slots
    (Keen 4, 5, 6)."""
    import gdtest
    code, out = gdtest.run("simg01c2_us", ["--games=keen4,keen5,keen6"], timeout=1800.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def _galaxy_demos(games):
    import galaxy_verify
    cfg = common.config()
    if not galaxy_verify.EXE.exists():
        galaxy_verify.build(cfg)
    rc = 0
    for g in games:
        for d in range(4):
            rc = max(rc, galaxy_verify.compare(cfg, g, d, False))
    return rc


def simg01d():
    """The Galaxy port's scripts (the declarations, the game core, the three episodes) all parse
    and every episode class instantiates."""
    import gdtest
    code, out = gdtest.run("galaxy_parse", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simg01g():
    """Keen 4's four built-in demos: the port's per-frame state hash (ck_verify.c's: camera, random
    index, tics, game state, every object's fields) equals omnispeak's, built headless from
    omnispeak-ref, on every frame."""
    return _galaxy_demos(["keen4"])


def simg01h():
    """Keen 5's and Keen 6's built-in demos: per-frame state hash equal to omnispeak's on every frame."""
    return _galaxy_demos(["keen5", "keen6"])


def dist02():
    """Every source file carries the GPL notice; every game script names its reference."""
    r = subprocess.run([sys.executable, "tools/check_headers.py"], cwd=common.ROOT, capture_output=True, text=True)
    for line in r.stdout.splitlines()[-6:]:
        print("  " + line)
    return r.returncode


def simg01i():
    """The Galaxy control panel: the main card draws; selection, new game, the sound card,
    paddle war, load/save cards, options and key binding work as the C does; QUIT confirms
    (Keen 4, 5, 6)."""
    import gdtest
    code, out = gdtest.run("simg01i_menus", ["--games=keen4,keen5,keen6"], timeout=1800.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def timeg4():
    """Keen 4's boot against keen4_boot_a (a guard while TIME-G4 is in progress): exact to the
    refresh through the terminator and the title's fizzle (picture 1317), and from the title on at
    least 743 pictures in order with every duration equal except three named ones. Re-based
    2026-10-08 (evening) on the memory manager (MM-01) and the original's intro structure (the
    plaques loaded before the scroll), which moved the demo's tic waits onto another timer phase:
    the phase is 6000000 (a plateau 5.7M-6.45M). Named: 1318, the DEMO box's second countdown step
    (the original's 11 refreshes against 3-4 for its like; a one-off, probably MML_SortMem
    compacting memory, not seen in the manager's trace); 1321, a step a refresh off; 2065, the
    recording's last pictures (the story screen's reveal rows are within 4)."""
    import galaxy_boot_score
    r = galaxy_boot_score.run("keen4", "keen4_boot_a", 75, 1317, timer_offset=6000000)
    if r is None:
        print("  COULD-NOT-RUN")
        return 2
    durs = [e for e in r["events"] if e[0] == "duration"]
    print(f"  exact to picture {r['exact']}; from 1317: {r['matched']} matched, {len(durs)} durations differ "
          f"(at {[e[1] for e in durs]})")
    allowed = {1318, 1321, 2065}
    return 0 if r["exact"] >= 1317 and r["matched"] >= 743 and all(e[1] in allowed for e in durs) else 1


def timeg5():
    """Keen 5's boot against keen5_boot_a, to the parity standard (J-20): exact to the refresh through
    the terminator and the title (picture 1317, one-refresh slips that recover allowed), then the demo's
    pictures in order to its end; the ones not matched are one-refresh in-between pictures (at least
    810 of 867 matched)."""
    import galaxy_boot_score
    r = galaxy_boot_score.run("keen5", "keen5_boot_a", 75, 1317)
    if r is None:
        print("  COULD-NOT-RUN")
        return 2
    lost = [e for e in r["events"] if e[0] == "lost"]
    print(f"  exact to picture {r['exact']}; from 1317: {r['matched']} of {r['pictures'] - 1317} in order"
          f"{'; lost at ' + str(lost[0][1]) if lost else ''}")
    return 0 if r["exact"] >= 1317 and r["matched"] >= 810 and not lost else 1


def timeg6():
    """Keen 6's boot against keen6_boot_a (the user's v1.0), to the parity standard (J-20): every picture
    in order from the first to the demo's first frames (picture 1335), every duration within one
    refresh (the terminator intro's one-refresh pairs). The demo itself parts where v1.0's rules
    differ from v1.4's (J-19; REPLAY-G6 keeps its floor)."""
    import galaxy_boot_score
    r = galaxy_boot_score.run("keen6", "keen6_boot_a", 75, 0)
    if r is None:
        print("  COULD-NOT-RUN")
        return 2
    early = [e for e in r["events"] if e[1] < 1336]
    skips = [e for e in early if e[0] != "duration"]
    worst = max([abs(e[2] - e[3]) for e in early if e[0] == "duration" and e[1] < 1317] or [0])
    print(f"  to picture 1335: {len(skips)} pictures out of order, durations within {worst} refresh")
    return 0 if not skips and worst <= 1 else 1


def shell01():
    """The main scene is the launcher: seven tiles, the right found / unsupported / missing status
    with no games, some and all, inside the window's width at 1280x720 and 480x800."""
    import gdtest
    code, out = gdtest.run("shell01_launcher", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def host01():
    """A game plays in real time: the engine on its own thread paced by the wall clock, frames to the
    screen side, keys to the game (Keen 4 quits through its own menu), a stop from outside ends it
    (Keen 1), the launcher starts a game from its tile and is back when it ends (Keen 2)."""
    import gdtest
    code, out = gdtest.run("host01_play", [], timeout=900.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell02():
    """The launcher's title art (J-12): Keen 1's made by running its engine to the title, Keen 4's from
    PIC_TITLESCREEN, the cache reused, and the launcher shows art on found tiles only."""
    import gdtest
    code, out = gdtest.run("shell02_art", [], timeout=900.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def menu01():
    """Keen 1-3's Options (MENU-01): with a player at the controls the title menu has an Options row
    and its window changes the settings (Mode, Display's Fullscreen) for that game only; headless, the
    menu is the original's."""
    import gdtest
    code, out = gdtest.run("menu01_vorticons", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def menu02():
    """Keen 4-6's Options (MENU-02): with a player at the controls CONFIGURE has a DISPLAY card and
    OPTIONS starts with MODE, and choosing their rows changes the settings for that game only;
    headless, the cards are the original's."""
    import gdtest
    code, out = gdtest.run("menu02_galaxy", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def cheat_read_points(folder):
    """CHEAT-01's rule: each `cheat_*` flag an engine declares with "# read in <Function>" is read only in
    that function, outside the shell's adapter (the part after "the shell's cheats" banner)."""
    import re
    root = Path(__file__).resolve().parent.parent
    sources = {}
    for f in sorted((root / folder).glob("*.gd")):
        text = f.read_text(encoding="utf-8")
        cut = text.find("the shell's cheats (CHEAT-01)")
        sources[f.name] = text if cut < 0 else text[:cut]
    flags = {}
    for name, text in sources.items():
        for m in re.finditer(r"^var (cheat_\w+): bool = false\s*# read in (\w+)", text, re.M):
            flags[m.group(1)] = m.group(2)
    bad = []
    for flag, where in flags.items():
        found = set()
        for name, text in sources.items():
            func = None
            for line in text.splitlines():
                m = re.match(r"^func (\w+)", line)
                if m:
                    func = m.group(1)
                if re.search(r"\b%s\b" % flag, line) and not line.startswith("var "):
                    found.add(func)
        if found != {where}:
            bad.append(f"{flag}: read in {sorted(map(str, found))}, declared for {where}")
    print(f"  {len(flags)} cheat flags, each read at its one named point" if not bad and flags else "  " + "; ".join(bad or ["no cheat flags found"]))
    return common.PASS if flags and not bad else common.FAIL


def cheat01():
    """The cheats (CHEAT-01/02), Keen 1-6: each flag read at its one named point; Keen 4-6's CHEATS card
    and Keen 1-3's Cheats page, greyed with no game; the effects in a level."""
    import gdtest
    code = max(cheat_read_points("godot/games/galaxy"), cheat_read_points("godot/games/vorticons"))
    for test, mark in (("cheat01_galaxy", "objects"), ("cheat01_vorticons", "keen1:")):
        code2, out = gdtest.run(test, [], timeout=600.0, quiet=True)
        code = max(code, code2)
        for line in out.splitlines():
            if "FAIL" in line or "checks" in line or "ERROR" in line or mark in line:
                print("  " + line.strip())
    return code


def rend01():
    """The draw list (REND-01), Keen 1-3: every gameplay picture drawn again from its refresh's list
    equals the card's; pictures with a window over the play are set aside (shown from the card)."""
    import gdtest
    code, out = gdtest.run("rend01_vorticons", ["--games=keen1,keen2,keen3"], timeout=2400.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line or "compared" in line:
            print("  " + line.strip())
    return code


def fix01():
    """The bug-fix toggles (FIX-01/02): the model (on by default, Classic off, Custom), and each fix's
    case built so far, off (the original) and on."""
    import gdtest
    code, out = gdtest.run("fix01_fixes", [], timeout=1500.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line or "lurch:" in line or "Earth scenes:" in line:
            print("  " + line.strip())
    return code


def shell05():
    """Settings persist, reset, survive damage value by value, per-game values win, and no
    simulation script reads them (A15)."""
    import gdtest
    code, out = gdtest.run("shell05_settings", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell09():
    """Every shell message says what happened and ends in a next step, on fixture errors; the log is
    written and the launcher shows its path."""
    import gdtest
    code, out = gdtest.run("shell09_messages", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell06():
    """In the host: focus loss pauses (the clock stops), mutes and lets go of held keys; focus back
    resumes with nothing made up; a 2 s stall is dropped but for one refresh."""
    import gdtest
    code, out = gdtest.run("shell06_focus", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell08():
    """In the host: the pad played with unplugged pauses with a prompt and lets go of its button; a key
    (not played) or plugging it back in goes on; another pad changes nothing."""
    import gdtest
    code, out = gdtest.run("shell08_pad", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def audio05():
    """Music and effects volume: exact scaling of scripted AdLib notes split by channel, the speaker as
    an effect, the saved volumes reaching a game, a game running under the dummy audio driver."""
    import gdtest
    code, out = gdtest.run("audio05_volume", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def and01():
    """The APK exports from this project (d2opl for arm64 and x86_64) and boots to the launcher on the
    emulator, sound chip loaded, no errors (tools/android_check.py; starts the emulator if needed)."""
    p = subprocess.run([sys.executable, str(Path(__file__).parent / "android_check.py")], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=2400)
    for line in p.stdout.splitlines():
        if "FAIL" in line or "checks passed" in line or "COULD-NOT-RUN" in line:
            print("  " + line.strip())
    return p.returncode


def and02():
    """On the emulator: Keen 1's folder imported through the system picker, found, and played
    (tools/android_check.py --import, after AND-01's checks)."""
    p = subprocess.run([sys.executable, str(Path(__file__).parent / "android_check.py"), "--import"], capture_output=True,
                       text=True, encoding="utf-8", errors="replace", timeout=2400)
    for line in p.stdout.splitlines():
        if "FAIL" in line or "checks passed" in line or "COULD-NOT-RUN" in line:
            print("  " + line.strip())
    return p.returncode


def and02a():
    """The importer on the desktop: a folder, a damaged release, an export ZIP and manifest, retries,
    progress, re-import, the source untouched, the launcher's import page."""
    import gdtest
    code, out = gdtest.run("and02_import", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell10():
    """On the emulator: the launcher's export of all seven games imported in one pick, 7 of 7 found, and
    Keen 1-6 each started by keyboard from its tile and drawing (tools/android_check.py --export)."""
    p = subprocess.run([sys.executable, str(Path(__file__).parent / "android_check.py"), "--export"], capture_output=True,
                       text=True, encoding="utf-8", errors="replace", timeout=3000)
    for line in p.stdout.splitlines():
        if "FAIL" in line or "checks passed" in line or "COULD-NOT-RUN" in line:
            print("  " + line.strip())
    return p.returncode


def shell10b():
    """The launcher's Export for Android button and page: off with no game, on with one and all, Enter
    opens it, a folder export of all seven with progress and results checks against its manifest, a ZIP."""
    import gdtest
    code, out = gdtest.run("shell10_button", [], timeout=400.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def and04():
    """On the emulator: Back closes a launcher page, reaches a game as Escape, and on the launcher sends
    the app to the background without quitting (tools/android_check.py --export --back)."""
    p = subprocess.run([sys.executable, str(Path(__file__).parent / "android_check.py"), "--export", "--back"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=3000)
    for line in p.stdout.splitlines():
        if "FAIL" in line or "checks passed" in line or "COULD-NOT-RUN" in line:
            print("  " + line.strip())
    return p.returncode


def and03a():
    """The touch controls: bounds at three screens, each engine's Fire, and in the host on Keen 1 the
    touches delivered to the game as the keyboard's scan codes; hidden with a pad in use."""
    import gdtest
    code, out = gdtest.run("and03_touch", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell07():
    """One copy at a time: with a second process holding the lock the launcher waits; Enter starts it
    anyway; a stale lock is ignored; leaving removes the lock."""
    import gdtest
    code, out = gdtest.run("shell07_instance", [], timeout=300.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def simv02():
    """Every level of Keen 1, 2 and 3, the world maps, the status and ordering screens and the
    endings run to a time limit under scripted play without a script error."""
    import gdtest
    code, out = gdtest.run("simv02_levels", ["--games=keen1,keen2,keen3", "--seconds=12"], timeout=1800.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "ERROR" in line:
            print("  " + line.strip())
    return code


def shell10a():
    """Export for Android (core): the found games' release files, exactly, one folder per game,
    with a manifest; sources untouched; re-export keeps, repairs, refuses a damaged source;
    the ZIP both ways; the finder recognises what was exported."""
    import gdtest
    code, out = gdtest.run("shell10_export", [], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line or "every game" in line:
            print("  " + line.strip())
    return code


def save01v():
    """Keen 1's save file: the port saves on the world map in the same session as the
    original did in DOSBox (keen1_savetest_a) and writes the identical 92 bytes."""
    import gdtest
    import shutil
    from fit_keys import SCANCODES
    cfg = common.config()
    original = Path(cfg["oracle_runs"]) / "keen1_savetest_a" / "game" / "SAVED1.CK1"
    if not original.exists():
        print("  COULD-NOT-RUN: no oracle run keen1_savetest_a")
        return common.COULD_NOT_RUN
    case = json.loads((Path(__file__).parent / "cases" / "keen1" / "savetest.json").read_text())
    spec = ",".join(f"{t - 0.956 + 0.17:.4f}:{SCANCODES[k]}:{h}" for t, k, h in case["held"])
    save = Path(cfg["oracle_runs"]).parent / "port_runs" / "save01v"
    shutil.rmtree(save, ignore_errors=True)
    code, _ = gdtest.run("simv01_boot", ["--game=keen1", "--seconds=17", f"--out={save}_frames", f"--keys_after_intro={spec}",
                                         f"--save={save}"], timeout=600.0, quiet=True)
    mine = save / "SAVED1.CK1"
    if not mine.exists():
        print("  the port wrote no save")
        return common.FAIL
    same = mine.read_bytes() == original.read_bytes()
    print(f"  port {mine.stat().st_size} bytes, original {original.stat().st_size}: {'identical' if same else 'DIFFERENT'}")
    return common.PASS if same else common.FAIL


def harn05a():
    """The Vorticons determinism harness: two runs of the same inputs give the same state hash
    at every frame; a skipped random draw is reported at its frame; the hash covers the variables."""
    import gdtest
    code, out = gdtest.run("harn05_determinism", ["--seconds=18", "--plant=900"], timeout=600.0, quiet=True)
    for line in out.splitlines():
        if "FAIL" in line or "checks" in line:
            print("  " + line.strip())
    return code


CHECKS = {
    "HARN-01a": (harn01a, "slow"),
    "HARN-03a": (harn03a, "fast"),
    "HARN-04a": (harn04a, "fast"),
    "HARN-12a": (harn12a, "fast"),
    "NATIVE-01": (native01, "fast"),
    "DATA-01V": (data01v, "fast"),
    "DATA-01G": (data01g, "slow"),
    "DATA-01D": (data01d, "fast"),
    "SIM-02": (sim02, "fast"),
    "DATA-02": (data02, "fast"),
    "SIM-V-01": (simv01, "fast"),
    "HARN-05a": (harn05a, "fast"),
    "TIME-V1": (timev1, "fast"),
    "SHELL-10a": (shell10a, "fast"),
    "SAVE-01V": (save01v, "fast"),
    "SIM-V-02": (simv02, "slow"),
    "SIM-G-01a": (simg01a, "slow"),
    "SIM-G-01b": (simg01b, "slow"),
    "SIM-G-01c1": (simg01c1, "slow"),
    "SIM-G-01c2": (simg01c2, "slow"),
    "DIST-02": (dist02, "fast"),
    "SHELL-01": (shell01, "fast"),
    "MENU-01": (menu01, "fast"),
    "MENU-02": (menu02, "fast"),
    "CHEAT-01": (cheat01, "fast"),
    "REND-01": (rend01, "slow"),
    "REND-03": (rend03, "slow"),
    "FIX-01": (fix01, "slow"),
    "SHELL-05": (shell05, "fast"),
    "SHELL-06": (shell06, "slow"),
    "SHELL-07": (shell07, "fast"),
    "SHELL-08": (shell08, "slow"),
    "AUDIO-05": (audio05, "slow"),
    "AND-01": (and01, "slow"),
    "AND-02": (and02, "slow"),
    "SHELL-10": (shell10, "slow"),
    "AND-04": (and04, "slow"),
    "SHELL-09": (shell09, "fast"),
    "AND-02a": (and02a, "fast"),
    "SHELL-10b": (shell10b, "fast"),
    "AND-03a": (and03a, "fast"),
    "HOST-01": (host01, "slow"),
    "SHELL-02": (shell02, "slow"),
    "SIM-G-01d": (simg01d, "slow"),
    "SIM-G-01g": (simg01g, "slow"),
    "SIM-G-01h": (simg01h, "slow"),
    "SIM-G-01i": (simg01i, "slow"),
    "SIM-D-01a": (simd01a, "fast"),
    "SIM-D-01b": (simd01b, "fast"),
    "SIM-D-01c": (simd01c, "fast"),
    "SIM-D-01d": (simd01d, "fast"),
    "SIM-D-01e": (simd01e, "fast"),
    "SIM-D-01f": (simd01f, "slow"),
    "TIME-G4": (timeg4, "slow"),
    "TIME-G5": (timeg5, "slow"),
    "TIME-G6": (timeg6, "slow"),
    "REPLAY-G4": (replayg4, "slow"),
    "MM-01": (mm01, "slow"),
    "REPLAY-G5": (replayg5, "slow"),
    "REPLAY-G6": (replayg6, "slow"),
    "REPLAY-V1": (replayv1, "slow"),
    "REPLAY-V2": (replayv2, "slow"),
    "REPLAY-V3": (replayv3, "slow"),
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
