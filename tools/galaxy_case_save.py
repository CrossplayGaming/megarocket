# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""SCR-01G: the saved games the Keen 4 and 5 screen cases load (scr_end, scr_end2, scr_over), made from the port's
own save. A Galaxy saved game holds the level's map planes, which come from the game's files, so it is never
committed: this rebuilds them under F:/KeenReworkWork/case_saves/scrg/<game>/ from scratch.

    python tools/galaxy_case_save.py keen4 [keen5 ...]

For each game: the port runs scr_game (a new game, saved into the first slot as KE) keeping the files it writes in
.../<game>/game; then end/ gets that save with its score set to 31415 (so that it makes the high scores), and for
Keen 5 end2/ the same with level 13 marked as its fuse destroyed (levelsDone[13] = 14, LS_KorathFuse: the secret
ending). The fields are CK_SaveGameState's, after the 42-byte header: mapPosX, mapPosY, levelsDone[25], keenScore.
"""
import shutil
import struct
import sys
from pathlib import Path

import common
import screen_case

ROOT = Path("F:/KeenReworkWork/case_saves/scrg")
HEADER = 42
LEVELS_DONE = HEADER + 4
SCORE = LEVELS_DONE + 50


def make(game):
    ext = {"keen4": "CK4", "keen5": "CK5"}[game]
    kept = ROOT / game / "game"
    shutil.rmtree(kept, ignore_errors=True)
    code = screen_case.preview(game, "scr_game", tag=screen_case.checkout_tag("casesave"), keep=kept)
    save = kept / f"SAVEGAM0.{ext}"
    if code == common.COULD_NOT_RUN or not save.exists():
        print(f"COULD-NOT-RUN: {game}'s scr_game wrote no saved game")
        return common.COULD_NOT_RUN
    data = bytearray(save.read_bytes())
    struct.pack_into("<i", data, SCORE, 31415)
    outs = {"end": bytes(data)}
    if game == "keen5":
        struct.pack_into("<H", data, LEVELS_DONE + 13 * 2, 14)
        outs["end2"] = bytes(data)
    for name, blob in outs.items():
        folder = ROOT / game / name
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)
        (folder / save.name).write_bytes(blob)
        print(f"{game}: {folder / save.name}")
    return common.PASS


def main():
    games = sys.argv[1:] or ["keen4", "keen5"]
    return max(make(g) for g in games)


if __name__ == "__main__":
    sys.exit(main())
