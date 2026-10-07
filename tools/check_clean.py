# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""HARN-12: fail if anything from the original games is in the repository or in a build.

Two tests are applied to every file that git tracks (and to every file under
build/ if it exists):

  1. Whole-file: its SHA-256 equals that of a game file, .
  2. Embedded: it contains a 48 byte run copied from a game file. Runs are
     sampled at several places in each game file and skipped where the bytes
     are too repetitive to identify anything (blank areas, padding).

Cannot catch: game data that has been re-encoded (base64, hex, an image
re-saved as PNG, a table retyped as numbers), and runs shorter than the
sample length.

Usage:
  python tools/check_clean.py            scan the repository and build/
  python tools/check_clean.py selftest
"""

import hashlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import common

RUN = 48
SAMPLES_PER_FILE = 6
MIN_DISTINCT = 12       # a sampled run must contain at least this many different byte values


def origins():
    """All original material: {name: bytes}, every file of every game under game_data/."""
    cfg = common.config()
    out = {}
    root = cfg["game_data"]
    if not root.is_dir():
        return out
    for folder in sorted(root.iterdir()):
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            if path.is_file():
                out[f"{folder.name}/{path.name}"] = path.read_bytes()
    return out


def fingerprints(material):
    """Returns ({sha256: origin}, [(run bytes, origin)])."""
    hashes = {}
    runs = []
    for origin, data in material.items():
        if not data:
            continue
        hashes.setdefault(hashlib.sha256(data).hexdigest(), origin)
        if len(data) < RUN:
            continue
        step = max((len(data) - RUN) // SAMPLES_PER_FILE, 1)
        taken = 0
        pos = 0
        while pos + RUN <= len(data) and taken < SAMPLES_PER_FILE:
            run = data[pos:pos + RUN]
            if len(set(run)) >= MIN_DISTINCT:
                runs.append((run, origin))
                taken += 1
                pos += step
            else:
                pos += RUN
    return hashes, runs


def scan(files, hashes, runs):
    """Returns a list of (file, kind, origin) findings."""
    findings = []
    for path in files:
        try:
            data = Path(path).read_bytes()
        except OSError as err:
            findings.append((str(path), "unreadable", str(err)))
            continue
        digest = hashlib.sha256(data).hexdigest()
        if digest in hashes:
            findings.append((str(path), "whole-file copy", hashes[digest]))
            continue
        for run, origin in runs:
            if run in data:
                findings.append((str(path), "embedded copy", origin))
                break
    return findings


def tracked_files(root):
    listing = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "--cached", "--others",
                              "--exclude-standard"],
                             capture_output=True, check=True).stdout
    files = [root / name.decode("utf-8") for name in listing.split(b"\0") if name]
    for name in ("build", "dist"):
        build = root / name
        if build.is_dir():
            files += [p for p in build.rglob("*") if p.is_file()]
    return [f for f in files if f.is_file()]


def check(root=common.ROOT, quiet=False):
    material = origins()
    if not material:
        print("COULD-NOT-RUN: no original game files found to compare against")
        return common.COULD_NOT_RUN, []
    hashes, runs = fingerprints(material)
    files = tracked_files(Path(root))
    findings = scan(files, hashes, runs)
    if not quiet:
        print(f"compared {len(files)} files against {len(material)} original files "
              f"({len(hashes)} hashes, {len(runs)} sampled runs)")
        for path, kind, origin in findings:
            print(f"  FOUND {kind}: {path}  <-  {origin}")
        print("PASS" if not findings else "FAIL")
    return (common.PASS if not findings else common.FAIL), findings


def scan_folder(folder):
    """Every file under a folder (a build to be handed out) against the
    original material. Returns a list of findings as text; empty if clean.
    (Scripts in a build are packed and compressed, so a copy hidden in one
    would not be seen here; they are the repository's, which is checked as
    plain files.)"""
    material = origins()
    if not material:
        return ["no original game files found to compare against"]
    hashes, runs = fingerprints(material)
    files = [p for p in Path(folder).rglob("*") if p.is_file()]
    return [f"{kind}: {path} <- {origin}" for path, kind, origin in scan(files, hashes, runs)]


def selftest():
    material = origins()
    if not material:
        print("COULD-NOT-RUN: no original game files found to compare against")
        return common.COULD_NOT_RUN
    hashes, runs = fingerprints(material)
    ok = True
    tmp = Path(tempfile.mkdtemp(prefix="check_clean_"))
    try:
        level = material["keen1/LEVEL01.CK1"]
        exe = material["keen4/KEEN4E.EXE"]

        clean = tmp / "clean.gd"
        clean.write_bytes(b"extends Node\n# nothing from the game here\n" * 40)
        renamed = tmp / "notes.txt"
        renamed.write_bytes(exe)
        entry = tmp / "level_one.bin"
        entry.write_bytes(level)
        packed = tmp / "pack.dat"
        packed.write_bytes(b"HEADER" * 100 + level + b"TRAILER" * 100)
        blank = tmp / "blank.bin"
        blank.write_bytes(bytes(100000))

        expect = {
            str(clean): None,
            str(renamed): ("whole-file copy", "keen4/KEEN4E.EXE"),
            str(entry): ("whole-file copy", "keen1/LEVEL01.CK1"),
            str(packed): ("embedded copy", "keen1/LEVEL01.CK1"),
            str(blank): None,
        }
        findings = {path: (kind, origin) for path, kind, origin in scan(list(expect), hashes, runs)}
        for path, want in expect.items():
            got = findings.get(path)
            good = got == want
            print(f"  {Path(path).name}: expected {want}, got {got}: {'ok' if good else 'WRONG'}")
            ok &= good
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("PASS" if ok else "FAIL")
    return common.PASS if ok else common.FAIL


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "selftest":
        sys.exit(selftest())
    sys.exit(check()[0])
