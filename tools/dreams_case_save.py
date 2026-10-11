# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""SCR-01D: the saved game Keen Dreams v1.93's ending case loads (tools/cases/kdreams193/scr_ending.json,
its "overrides"), made from the port's own save. A Dreams saved game holds the level's map planes, which come
from the game's files, so it is never committed: this rebuilds it under F:/KeenReworkWork/case_saves from
scratch, byte for byte the save the case was recorded with (the original loaded that very file).

    python tools/dreams_case_save.py [--force]

The port plays TIMETABLE (a new game, the warp to level 15, the debug keys' free items and god mode, bombs
thrown at King Boobus Tuber) and, as his last explosions fade, saves into the first slot as 'b' (Escape, F6,
Right, Enter, b, Enter), keeping the files it writes. The run is pinned to the timing it was made with (COSTS,
FEED_PRE, CLOCK: later fits of dreams_costs.json do not move it), and the save must have DIGEST: a port that
plays the fight otherwise writes another save, which is not the recording's, so nothing is written and the
reason is given. --force rebuilds it even if it is there.
"""
import hashlib
import shutil
import sys
from pathlib import Path

import common
import keyfeed
import screen_case

SAVE = Path("F:/KeenReworkWork/case_saves/scrd_kdreams193_ending_save")
KEPT = Path("F:/KeenReworkWork/case_saves/scrd_kdreams193_ending")
NAME = "SAVEGM0.KDR"
# the save the recording kdreams193_scr_ending_a was made with (3050 bytes)
DIGEST = "fdbeb3750cf14e22e0e86cbcdac379224cda77779228ac3d3be3ab6801df3a2d"
# the timing the save was made with, 2026-10-11 (dreams_costs.json then, v1.93's own; dreams_case.FEED_PRE and
# START_LAG then): the fight is play, and any change to these moves it
COSTS = "grbyte:4847,grexp:758,lzhbyte:28500,mapbyte:5225,mapword:1457,mmscan:1833,pitphase:4500000"
FEED_PRE = 0.045
CLOCK = 85000
TIMETABLE = [
    [4.0, "space", 0.2], [6.0, "enter", 0.2], [10.0, "f10", 0.8], [10.3, "w", 0.15], [11.4, "1", 0.15],
    [11.8, "5", 0.15], [12.6, "enter", 0.15], [14.0, "f10", 0.8], [14.3, "i", 0.15], [15.6, "n", 0.15],
    [17.0, "f10", 0.8], [17.3, "g", 0.15], [18.6, "n", 0.15],
    [19.993, "alt", 0.143], [20.507, "alt", 0.143], [21.027, "alt", 0.143], [21.541, "alt", 0.143],
    [22.054, "alt", 0.143], [22.568, "alt", 0.143], [23.082, "alt", 0.143], [23.595, "alt", 0.143],
    [24.109, "alt", 0.143], [24.622, "alt", 0.143], [25.136, "alt", 0.143], [25.65, "alt", 0.143],
    [26.163, "alt", 0.143], [26.677, "alt", 0.143], [30.6, "esc", 0.15], [32.5, "f6", 0.15],
    [34.0, "right", 0.15], [35.5, "enter", 0.15], [37.0, "b", 0.1], [38.0, "enter", 0.15], [40.0, "esc", 0.15]]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def present():
    """The save is there, and is the recording's."""
    return (SAVE / NAME).exists() and digest(SAVE / NAME) == DIGEST


def make(force=False, say=print):
    """Rebuilds the save if it is missing (or --force). Returns a common code."""
    if present() and not force:
        say(f"kdreams193: {SAVE / NAME} is there (the recording's)")
        return common.PASS
    spec = {"seconds": 46.6, "keyfeed": True, "held": TIMETABLE, "args": "", "overrides": None, "may_exit": False,
            "masks": [], "screens": [], "port": {"costs": COSTS, "feed_pre": FEED_PRE, "clock": CLOCK,
                                                 "tsr_paras": keyfeed.dos_paragraphs(TIMETABLE)}}
    shutil.rmtree(KEPT, ignore_errors=True)
    work = screen_case.work_dir("kdreams193", "scr_ending", screen_case.checkout_tag("casesave")) / "port"
    code, pframes, _ = screen_case.run_port("kdreams193", "scr_ending", work, say, keep=KEPT, spec=spec)
    made = KEPT / NAME
    if pframes is None or not made.exists():
        say(f"COULD-NOT-RUN: kdreams193's ending timetable wrote no saved game ({KEPT})")
        return common.COULD_NOT_RUN
    if digest(made) != DIGEST:
        say(f"COULD-NOT-RUN: the port's save ({made}, {made.stat().st_size} bytes) is not the one the recording "
            f"kdreams193_scr_ending_a loaded (sha256 {digest(made)[:16]}..., wanted {DIGEST[:16]}...): the port "
            f"now plays the timetable otherwise; the case needs a save and a recording made anew "
            f"(docs/notes/SCREEN_CASES.md)")
        return common.COULD_NOT_RUN
    shutil.rmtree(SAVE, ignore_errors=True)
    SAVE.mkdir(parents=True)
    shutil.copyfile(made, SAVE / NAME)
    say(f"kdreams193: {SAVE / NAME} rebuilt (the recording's, sha256 {DIGEST[:16]}...)")
    return common.PASS


def main():
    return make(force="--force" in sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
