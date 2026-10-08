# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""REPLAY-G4/5/6's recorded sessions: one case per level of Keen 4, 5 and 6 (tools/cases/<game>/levelNN.json).

Each session starts the original straight in the level with /TEDLEVEL n, id's own test option for
the map editor (no intro, menus, saved game or warp; normal difficulty), and plays it for half a
minute with the same run, jump, fire and pogo pattern for every level. The opening screens and menus
are proven by their own recordings (TIME-G); these prove the levels. The port runs the same command
line and keys through the same code.

Times are seconds after the recording's first picture (the port's first picture is at its start,
within 0.05 s). Worked out on the port (the scratchpad's gkeys.py sheets), with a second or more
between steps so the original's slower moments cannot swallow a key.

    python tools/make_galaxy_cases.py          # writes the cases
"""
import json
from pathlib import Path

CASES = Path(__file__).parent / "cases"
LEVELS = range(1, 19)


def level_keys(start):
    """The play pattern, from `start` seconds (the level has just appeared)."""
    plan = [(5, "right", 3.0), (6, "ctrl", 0.3), (9, "right", 2.0), (9.5, "ctrl", 0.3), (12, "left", 1.5), (13, "space", 0.2),
            (15, "right", 4.0), (16, "ctrl", 0.3), (18, "alt", 0.2), (20, "alt", 0.2), (21, "right", 3.0), (22, "ctrl", 0.3),
            (24, "space", 0.2), (25.5, "left", 2.0), (26, "ctrl", 0.3)]
    return [[round(start + a, 3), k, h] for a, k, h in plan]


def case(game, level):
    """The original started straight in the level (/TEDLEVEL, id's map-editor test option: no intro, menu or
    warp; normal difficulty), then the play pattern from 2 s, the level's name box just gone."""
    return {"seconds": 32.0, "keys": "", "cycles": 20000, "args": f"/TEDLEVEL {level}",
            "press_until_picture": {"key": "enter", "from": 5.0, "every": 1.5},
            "held": level_keys(2.0 - 5.0),
            "note": f"KEEN?E /TEDLEVEL {level} (straight into level {level}), then run, jump, fire and pogo for half a "
                    "minute. Held times are seconds after the recording's first picture."}


def main():
    n = 0
    for game in ("keen4", "keen5", "keen6"):
        d = CASES / game
        d.mkdir(parents=True, exist_ok=True)
        for level in LEVELS:
            (d / f"level{level:02d}.json").write_text(json.dumps(case(game, level), indent=1), encoding="utf-8")
            n += 1
    boot4 = json.loads((CASES / "keen4" / "boot.json").read_text(encoding="utf-8"))
    (CASES / "keen5" / "boot.json").write_text(json.dumps(boot4), encoding="utf-8")
    print(f"{n} level cases written, and keen5/boot.json")


if __name__ == "__main__":
    main()
