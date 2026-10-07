# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""Shared helpers for the verification tools."""

import fnmatch
import json
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Exit codes shared by every tool. COULD_NOT_RUN means the thing under test was
# never reached (missing program, missing data), which is not a pass or a fail.
PASS = 0
FAIL = 1
COULD_NOT_RUN = 2

NAMES = {PASS: "PASS", FAIL: "FAIL", COULD_NOT_RUN: "COULD-NOT-RUN"}


def config():
    cfg = json.loads((ROOT / "tools" / "config.json").read_text(encoding="utf-8"))
    cfg["game_data"] = ROOT / cfg["game_data"]
    cfg["oracle_runs"] = Path(cfg["oracle_runs"])
    cfg["dosbox"] = Path(cfg["dosbox"])
    godot = Path(cfg["godot"])
    cfg["godot"] = godot if godot.is_absolute() else ROOT / godot
    cfg["gcc"] = Path(cfg.get("gcc", "gcc"))
    return cfg


def game(name):
    """The config entry for one game, with its data folder resolved."""
    cfg = config()
    if name not in cfg["games"]:
        raise KeyError(f"no such game {name!r}; one of {', '.join(cfg['games'])}")
    entry = dict(cfg["games"][name])
    entry["name"] = name
    entry["dir"] = cfg["game_data"] / name
    return entry


def game_files(name):
    """The original files of a game as found in its data folder, by the
    config's patterns. Missing executable -> empty list."""
    entry = game(name)
    if not entry["dir"].exists():
        return []
    out = []
    for path in sorted(entry["dir"].iterdir()):
        if path.is_file() and any(fnmatch.fnmatch(path.name.upper(), pat.upper()) for pat in entry["files"]):
            out.append(path)
    if not any(p.name.upper() == entry["exe"].upper() for p in out):
        return []
    return out


def oracle_lock():
    """A file that exists while an original is being run in DOSBox. Tools that
    open windows check for it and decline to run while it is there (a window
    opened then takes the keyboard focus from DOSBox)."""
    return config()["oracle_runs"].parent / "oracle_running.lock"


def oracle_busy():
    lock = oracle_lock()
    return lock.exists() and time.time() - lock.stat().st_mtime < 3600
