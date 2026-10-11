# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""HARN-23: the Dreams port's play, frame by frame, against ReflectionHLE's.

The port (godot/tests/drm_boot.gd, --kl_record and --kl_warp) plays a level with scripted keys and writes
each play-loop frame (its tics, the player's controls, the last scan code, lasttimecount's low 16 bits and
a hash of the whole game state) in KL_Frame's layout. ReflectionHLE (refkeen/src/kdreams/kl_verify.c),
built from this repository's copy, replays the same controls, tics and clock and checks the hash every
frame; a mismatch prints both sides' first differing frame (its fields, from the C side: run with
KL_DUMP=<frame> for any other frame).

ReflectionHLE's run folder (RUNS/<game>) holds the release's files, reflection-kdreams.exe and SDL3.dll;
--build rebuilds the executable first (VS 2022 build tools, CMake build folder BUILD).

    python tools/dreams_trace.py [--game kdreams193] [--level 1 | 1-16] [--seconds 45] [--way left] [--runs 3] [--build]
                                 [--tag NAME]

--tag names the port's run folder and its trace (copies of the project checking at once keep apart).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = Path("F:/KeenReworkWork")
RUNS = WORK / "refkeen_run"
BUILD = WORK / "refkeen_build"
CMAKE = Path("C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/IDE/CommonExtensions/"
             "Microsoft/CMake/CMake/bin/cmake.exe")
GAMEVER = {"kdreams193": "kdreamse193", "kdreams": "kdreamse100"}
# v1.00's GAMEMAPS lacks these maps (its warp there quits to DOS, the port likewise: REPLAY-D)
MISSING = {"kdreams": (6, 8, 11, 13)}

# a direction held (left: the levels start at their right), with jump (ctrl) and throw (alt) every 3
# seconds from 4 and a turn back for a second every 10: walls, jumps in the air and throws are where the
# odd-tic loops and the clipping meet, and the throws and the enemies they wake use the random numbers
LEFT, RIGHT, JUMP, THROW = 0x4B, 0x4D, 0x1D, 0x38


def default_keys(seconds, way="left"):
    ahead, back = (LEFT, RIGHT) if way == "left" else (RIGHT, LEFT)
    keys = []
    t = 3.0
    while t < seconds:
        keys.append(f"{t}:{ahead}:9")
        keys.append(f"{t + 9}:{back}:1")
        t += 10.0
    t = 4.0
    while t < seconds - 1:
        keys.append(f"{t}:{JUMP}:0.4")
        keys.append(f"{t + 1.5}:{THROW}:0.2")
        t += 3.0
    return ",".join(keys)


def build():
    p = subprocess.run([str(CMAKE), "-S", str(ROOT / "refkeen"), "-B", str(BUILD), "-G", "Visual Studio 17 2022",
                        "-A", "x64", "-DBUILD_UNIFIED=OFF", "-DSDL3_DIR=F:/KeenLauncher/deps/SDL3-3.2.18/cmake"],
                       capture_output=True, text=True)
    if p.returncode:
        return p.stdout + p.stderr
    p = subprocess.run([str(CMAKE), "--build", str(BUILD), "--config", "Release", "--target", "reflection-kdreams",
                        "--", "/m", "/v:minimal", "/nologo"], capture_output=True, text=True)
    return "" if p.returncode == 0 else p.stdout + p.stderr


def record(game, level, seconds, keys, trace, tag=""):
    out = WORK / "port_runs" / f"trace_{game}{('_' + tag) if tag else ''}"
    shutil.rmtree(out, ignore_errors=True)
    if trace.exists():
        trace.unlink()
    p = subprocess.run([sys.executable, "tools/gdtest.py", "drm_boot", "--", f"--only={game}",
                        f"--seconds={seconds}", f"--out={out.as_posix()}", f"--kl_record={trace.as_posix()}",
                        f"--kl_warp={level}", f"--keys={keys}"],
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout + p.stderr


def replay(game, level, trace, dump=None):
    run = RUNS / game
    env = dict(os.environ, KL_REPLAY=str(trace), KL_WARP=str(level), SDL_VIDEO_DRIVER="dummy",
               SDL_AUDIO_DRIVER="dummy")
    if dump is not None:
        env["KL_DUMP"] = str(dump)
    try:
        p = subprocess.run([str(run / "reflection-kdreams.exe"), "-gamever", GAMEVER[game]], cwd=run, env=env,
                           capture_output=True, text=True, errors="replace", timeout=300)
    except subprocess.TimeoutExpired:
        # waiting outside the play loop, where the replay feeds nothing: the C left the loop where the
        # port did not (a death or a level's end the port's trace does not have)
        return 1, "KL REPLAY STALLED (no verdict in 300 seconds: the C left the play loop early?)"
    return p.returncode, p.stderr


def levels(spec):
    out = []
    for part in str(spec).split(","):
        lo, _, hi = part.partition("-")
        out += list(range(int(lo), int(hi or lo) + 1))
    return out


def one_level(a, run, level):
    """Record the port's life on `level`, replay it a.runs times: 0 all matched, 1 a mismatch or a stall,
    2 the port wrote no trace."""
    trace = run / f"port{('_' + a.tag) if a.tag else ''}.bin"
    code, out = record(a.game, level, a.seconds, a.keys or default_keys(a.seconds, a.way), trace, a.tag)
    if not trace.exists() or trace.stat().st_size % 24 or trace.stat().st_size == 0:
        print(out[-3000:])
        print(f"level {level}: COULD-NOT-RUN (the port wrote no trace)")
        return 2
    frames = trace.stat().st_size // 24
    for i in range(a.runs):
        code, err = replay(a.game, level, trace)
        line = next((ln for ln in err.splitlines() if ln.startswith("KL ")), "(no verdict)")
        print(f"level {level}: port {frames} frames; replay {i + 1}: {line}", flush=True)
        if code != 0:
            print("\n".join(ln for ln in err.splitlines() if ln.startswith(("obj 0", "game", "KL "))
                            or " active 1 " in ln))
            m = re.search(r"frame (\d+)", line)
            if m:
                print(f"(the C's frame before: KL_DUMP={int(m.group(1)) - 1})")
            return 1
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--game", default="kdreams193", choices=sorted(GAMEVER))
    ap.add_argument("--level", default="1", help="a level, a range (1-16) or a list (1,5,9)")
    ap.add_argument("--seconds", type=float, default=45)
    ap.add_argument("--keys", default="", help="drm_boot's --keys (at:scancode:hold, seconds)")
    ap.add_argument("--way", default="left", choices=["left", "right"], help="the default keys' direction")
    ap.add_argument("--runs", type=int, default=3, help="replays: one that passes only sometimes is a harness bug")
    ap.add_argument("--build", action="store_true", help="rebuild ReflectionHLE and copy it to the run folder")
    ap.add_argument("--tag", default="", help="a name for the port's run folder and trace (parallel runs)")
    a = ap.parse_args()

    run = RUNS / a.game
    if a.build:
        err = build()
        if err:
            print(err[-3000:])
            print("RESULT: COULD-NOT-RUN (ReflectionHLE did not build)")
            return 2
        for folder in GAMEVER:
            if (RUNS / folder).is_dir():
                shutil.copy2(BUILD / "Release" / "reflection-kdreams.exe", RUNS / folder / "reflection-kdreams.exe")
    if not (run / "reflection-kdreams.exe").exists():
        print(f"RESULT: COULD-NOT-RUN (no {run / 'reflection-kdreams.exe'}: --build)")
        return 2

    worst = 0
    for level in levels(a.level):
        if level in MISSING.get(a.game, ()):
            print(f"level {level}: not in this release")
            continue
        worst = max(worst, one_level(a, run, level))
    print("RESULT: " + ("PASS", "FAIL", "COULD-NOT-RUN")[worst])
    return worst


if __name__ == "__main__":
    sys.exit(main())
