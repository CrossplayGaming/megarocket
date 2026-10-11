# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""Run a headless Godot test script with a watchdog.

A test script lives in godot/tests/, extends SceneTree, and ends by printing one
line `RESULT: PASS`, `RESULT: FAIL` or `RESULT: COULD-NOT-RUN` and quitting.

A headless Godot script that hits a run-time error never reaches quit() and
would run forever, so every run has a time limit. Hitting the limit, a script
error in the output, or a missing RESULT line all count as COULD-NOT-RUN: the
test itself is broken, which says nothing about the thing under test.

Usage: python tools/gdtest.py <test name> [--timeout N] [-- extra args for the script]
"""

import os
import subprocess
import time
import sys

import common

# Godot's output can hold characters the console's code page lacks.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

ERROR_MARKERS = ("SCRIPT ERROR", "Parse Error", "Failed to load script", "ERROR: ")


def refresh_class_cache(cfg):
    """Godot only learns about `class_name` scripts when the project is imported.

    Re-import when any script is newer than the class cache, so a test never
    runs against a stale list of classes.
    """
    project = common.ROOT / "godot"
    cache = project / ".godot" / "global_script_class_cache.cfg"
    newest = max((p.stat().st_mtime for p in project.rglob("*.gd")), default=0.0)
    if cache.exists() and cache.stat().st_mtime >= newest:
        return
    # one import at a time: tests started together after an edit would otherwise
    # all import at once and some fail (seen with parallel key-fit trials)
    lock = project / ".godot" / "import.lock"
    for _ in range(600):
        try:
            fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except FileExistsError:
            try:
                if time.time() - lock.stat().st_mtime > 300:    # left by a run that died
                    lock.unlink(missing_ok=True)
            except FileNotFoundError:
                continue    # the import that held it has just finished: try again at once
            time.sleep(0.5)
    else:
        fd = None
    try:
        if not (cache.exists() and cache.stat().st_mtime >= newest):
            subprocess.run([str(cfg["godot"]), "--headless", "--path", str(project), "--import"],
                           capture_output=True, timeout=300)
            if cache.exists():
                cache.touch()
    finally:
        if fd is not None:
            os.close(fd)
            lock.unlink(missing_ok=True)


def run(test, extra=(), timeout=120.0, quiet=False, project=None):
    """`project`: another copy of the Godot project to run the test in (see
    tools/branch_coverage.py); it must have been imported already."""
    cfg = common.config()
    if not cfg["godot"].exists():
        print(f"COULD-NOT-RUN: Godot not found at {cfg['godot']}")
        return common.COULD_NOT_RUN, ""
    script = (project or common.ROOT / "godot") / "tests" / f"{test}.gd"
    if not script.exists():
        print(f"COULD-NOT-RUN: no such test {script}")
        return common.COULD_NOT_RUN, ""
    if project is None:
        refresh_class_cache(cfg)
    cmd = [str(cfg["godot"]), "--headless", "--path", str(project or common.ROOT / "godot"),
           "--script", f"res://tests/{test}.gd", "--",
           f"--game_data={cfg['game_data']}", *extra]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                              encoding="utf-8", errors="replace")
        out = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as err:
        out = (err.stdout or b"").decode("utf-8", "replace") if isinstance(err.stdout, bytes) else (err.stdout or "")
        out += (err.stderr or b"").decode("utf-8", "replace") if isinstance(err.stderr, bytes) else (err.stderr or "")
        if not quiet:
            print(out)
        print(f"COULD-NOT-RUN: {test} exceeded {timeout:.0f} s (a script error stops a headless run from quitting)")
        return common.COULD_NOT_RUN, out
    if not quiet:
        print(out.rstrip())
    result = None
    for line in out.splitlines():
        if line.startswith("RESULT: "):
            result = line[len("RESULT: "):].strip()
    broken = [line for line in out.splitlines() if any(m in line for m in ERROR_MARKERS)]
    if broken:
        print(f"COULD-NOT-RUN: {test} printed engine errors, e.g. {broken[0].strip()}")
        return common.COULD_NOT_RUN, out
    if result == "PASS":
        return common.PASS, out
    if result == "FAIL":
        return common.FAIL, out
    print(f"COULD-NOT-RUN: {test} ended without a RESULT line")
    return common.COULD_NOT_RUN, out


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(common.COULD_NOT_RUN)
    extra = []
    if "--" in args:
        split = args.index("--")
        args, extra = args[:split], args[split + 1:]
    timeout = 120.0
    if "--timeout" in args:
        i = args.index("--timeout")
        timeout = float(args[i + 1])
        del args[i:i + 2]
    code, _ = run(args[0], extra, timeout)
    sys.exit(code)


if __name__ == "__main__":
    main()
