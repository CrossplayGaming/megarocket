"""Compare the Galaxy port with omnispeak, frame by frame, over the built-in demos.

omnispeak (omnispeak-ref/src) is built headless (its null video/sound/input back-ends, vanilla build) and
run with /CHECKSUM <file> /PLAYDEMO n: ck_verify.c writes one FNV-1a hash per play-loop frame of the
camera, the random index, the frame's tics, the game state and every live object's fields. The port runs
the same demo through CK_Main with the same option (godot/tests/galaxy_verify.gd) and writes the same lines.
The first line that differs is the first frame the port's state is not omnispeak's.

Both sides read the same data: the player's files from game_data/<game>, omnispeak's metadata from
godot/data/omnispeak/<meta>, and for Keen 6 v1.0 the EGAHEAD/EGADICT/MAPHEAD tables GalData takes from
KEEN6C.EXE (godot/tests/galaxy_dump_k6_tables.gd writes them into the run folder).

    python tools/galaxy_verify.py --build                 # compile omnispeak_null.exe (MinGW gcc)
    python tools/galaxy_verify.py keen4 0 1 2 3           # compare demos
    python tools/galaxy_verify.py keen6 0 --keep          # keep both traces
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

import common
import gdtest

WORK = Path("F:/KeenReworkWork/omni_run")
BUILD = Path("F:/KeenReworkWork/omni_build")
EXE = BUILD / "omnispeak_null.exe"
META = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
SKIP = ("id_vl_sdl", "id_in_sdl", "id_sd_sdl", "id_vl_dos", "id_in_dos", "id_sd_dos", "id_sd_opl2", "id_sd_liboplhw",
        "icon", "ck_us_2")   # ck_us_2.c is #included by id_us_2.c


def build(cfg):
    gcc = Path(cfg["gcc"])
    src = common.ROOT / "omnispeak-ref" / "src"
    obj = BUILD / "obj_verify"
    obj.mkdir(parents=True, exist_ok=True)
    flags = ["-std=gnu99", "-O2", "-DCK_VANILLA", "-mno-ms-bitfields", "-DWITH_KEEN4", "-DWITH_KEEN5", "-DWITH_KEEN6"]
    objs = []
    for c in sorted(list(src.glob("*.c")) + list((src / "opl").glob("*.c"))):
        if c.stem.startswith(SKIP) or c.stem in SKIP:
            continue
        o = obj / (c.stem + ".o")
        r = subprocess.run([str(gcc), *flags, "-c", "-o", str(o), str(c)], capture_output=True, text=True,
                           cwd=src, env={**__import__("os").environ, "PATH": str(gcc.parent) + ";" + __import__("os").environ["PATH"]})
        if r.returncode != 0:
            print(r.stderr[-2000:])
            sys.exit(f"compile failed: {c.name}")
        objs.append(str(o))
    r = subprocess.run([str(gcc), "-o", str(EXE), *objs, "-lm"], capture_output=True, text=True,
                       env={**__import__("os").environ, "PATH": str(gcc.parent) + ";" + __import__("os").environ["PATH"]})
    if r.returncode != 0:
        sys.exit("link failed:\n" + r.stderr[-2000:])
    print(f"built {EXE}")


def prepare(cfg, game):
    run = WORK / game
    run.mkdir(parents=True, exist_ok=True)
    for f in (cfg["game_data"] / game).iterdir():
        if f.is_file():
            shutil.copy2(f, run / f.name)
    for f in (common.ROOT / "godot" / "data" / "omnispeak" / META[game]).iterdir():
        if f.is_file() and not (run / f.name).exists():
            shutil.copy2(f, run / f.name)
    if game == "keen6" and (cfg["game_data"] / game / "KEEN6C.EXE").exists():
        # v1.0: the headers live in the executable; write the port's reading of them for omnispeak
        code, out = gdtest.run("galaxy_dump_k6_tables", [f"--out={run.as_posix()}"], timeout=600.0, quiet=True)
        if code != 0:
            sys.exit("keen6: could not write KEEN6C.EXE's tables: " + out[-1500:])
    return run


def lines(p):
    return [l.strip() for l in p.read_text().splitlines() if l.strip()]


def compare(cfg, game, demo, keep):
    run = prepare(cfg, game)
    c_out, p_out = run / f"c_{demo}.txt", run / f"p_{demo}.txt"
    for p in (c_out, p_out):
        p.unlink(missing_ok=True)
    subprocess.run([str(EXE), "/CHECKSUM", c_out.name, "/PLAYDEMO", str(demo)], cwd=run, stdin=subprocess.DEVNULL,
                   capture_output=True, timeout=600)
    code, out = gdtest.run("galaxy_verify", [f"--game={game}", f"--demo={demo}", f"--out={p_out.as_posix()}"],
                           timeout=1800.0, quiet=True)
    if not c_out.exists() or not p_out.exists():
        print(f"{game} demo {demo}: COULD-NOT-RUN (omnispeak trace {c_out.exists()}, port trace {p_out.exists()})")
        return 2
    c, p = lines(c_out), lines(p_out)
    first = next((i for i in range(min(len(c), len(p))) if c[i] != p[i]), None)
    if first is None and len(c) == len(p):
        print(f"{game} demo {demo}: identical, {len(c) - 1} frames ({c[-1]})")
        rc = 0
    else:
        at = first if first is not None else min(len(c), len(p))
        print(f"{game} demo {demo}: first difference at line {at} of {len(c)} / {len(p)}: "
              f"omnispeak {c[at] if at < len(c) else '-'} | port {p[at] if at < len(p) else '-'}")
        rc = 1
    if not keep and rc == 0:
        c_out.unlink()
        p_out.unlink()
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game", nargs="?")
    ap.add_argument("demos", nargs="*", type=int)
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    cfg = common.config()
    if a.build or not EXE.exists():
        build(cfg)
    if not a.game:
        return 0
    rc = 0
    for d in a.demos or [0, 1, 2, 3]:
        rc = max(rc, compare(cfg, a.game, d, a.keep))
    return rc


if __name__ == "__main__":
    sys.exit(main())
