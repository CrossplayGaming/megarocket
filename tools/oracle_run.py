# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""HARN-01: run an original Keen executable in DOSBox unattended and record what it shows.

The game runs on a scratch copy of the user's own files. Settings are hermetic
and the same for every run of every game:

  machine = vga       the games as sold today run under DOSBox with a VGA card
                      (Steam's keen4.conf), so the oracle does too; the 200-line
                      modes refresh at 70.086 Hz there. Keen 1-3 pace themselves
                      by that refresh, so an EGA card would run them slower.
  core = normal       the dynamic core makes these DOS games see key presses
                      that never happened (found on the Duke project).
  cycles = fixed      a fixed emulated speed, so two runs are alike.
  no sound device     the oracle is never heard; sound is captured as chip
                      writes (--opl) or a mixed wave (--wave) when wanted.
  no host game keys   nothing on the host keyboard reaches the game. Keys are
                      typed by DOSBox's own AUTOTYPE from the case, and keys
                      that must be HELD are posted to DOSBox's window bound to
                      spare function keys.

Every run is a TIMED run: the case says how many seconds to record after the
game's first picture, what AUTOTYPE types and when, and which keys are held.
Runs are compared by their sequence of distinct pictures (tools/frames.py),
so AUTOTYPE's timing (good to a few hundredths of a second) is good enough.

A case is tools/cases/<game>/<name>.json:

    {"seconds": 45, "keys": "", "key_wait": 3, "key_pace": 0.5,
     "prekeys": [[6.0, "enter", 0.2]],      posted before the first picture (start-up screens)
     "held": [[12.0, "esc", 0.3]], "may_exit": false, "cycles": 20000}

Usage: python tools/oracle_run.py <game> <case> [--as NAME] [--opl] [--wave] [--show]
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import common
import winkeys

COOL_DOWN_SECONDS = 30.0        # between one DOSBox ending and the next starting
REFRESH_HZ = 70.086             # pictures a second in mode 0Dh on a VGA
MIN_SPEED = 0.97                # least share of full speed a timed run may have had
DEFAULT_CYCLES = 20000          # a 386-class machine; Keen's own timing is unaffected
MODE_OF = {"vorticons": "0Dh", "galaxy": "0Dh", "dreams": "0Dh"}

# DOSBox's own controls on F8-F12 (record video, record the sound output,
# capture the sound chip, fast-forward, shut down); nothing else is bound.
MAPPER = """hand_video "key 65"
hand_recwave "key 66"
hand_caprawopl "key 67"
hand_speedlock "key 68"
hand_shutdown "key 69"
"""

CONF = """[sdl]
fullscreen = false
output = opengl
windowresolution = 640x400
vsync = off
mapperfile = {mapper}

[dosbox]
machine = vga
captures = {captures}
memsize = 16
startup_verbosity = quiet

[render]
frameskip = 0
aspect = false

[cpu]
core = normal
cputype = auto
cycles = {cycles}

[mixer]
nosound = {nosound}
rate = 48000

[midi]
mididevice = none
mpu401 = none

[sblaster]
sbtype = sbpro2
sbbase = 220
irq = 7
dma = 1
oplmode = auto

[speaker]
pcspeaker = true

[autoexec]
mount c "{game}"
c:
{autotype}
{exe}
exit
"""

SPARE_HOST_KEYS = [("f5", 62), ("f6", 63), ("f7", 64), ("f1", 58), ("f2", 59), ("f3", 60), ("f4", 61)]


def recorded_frames(video):
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=nb_frames",
         "-of", "csv=p=0", str(video)], capture_output=True, text=True)
    try:
        return int(probe.stdout.strip())
    except ValueError:
        return 0


def _rmtree(path):
    for _ in range(10):
        try:
            shutil.rmtree(path)
            return
        except PermissionError:
            time.sleep(0.5)
    shutil.rmtree(path)


def load_case(game, case):
    path = common.ROOT / "tools" / "cases" / game / f"{case}.json"
    if not path.exists():
        return None
    spec = json.loads(path.read_text(encoding="utf-8"))
    spec.setdefault("seconds", 30)
    spec.setdefault("keys", "")
    spec.setdefault("key_wait", 3)
    spec.setdefault("key_pace", 0.5)
    spec.setdefault("held", [])
    spec.setdefault("prekeys", [])      # keys posted BEFORE the first picture: [[seconds after the window, key, hold]]
    spec.setdefault("press_until_picture", None)   # {"key": "enter", "from": 8.0, "every": 1.5}: tap until the first picture
    spec.setdefault("may_exit", False)
    spec.setdefault("cycles", DEFAULT_CYCLES)
    spec.setdefault("overrides", None)
    return spec


def prepare(game, run_name, overrides):
    cfg = common.config()
    entry = common.game(game)
    files = common.game_files(game)
    if not files:
        print(f"COULD-NOT-RUN: no {entry['exe']} in {entry['dir']}")
        return None
    run_dir = cfg["oracle_runs"] / run_name
    game_dir = run_dir / "game"
    cap_dir = run_dir / "capture"
    if run_dir.exists():
        _rmtree(run_dir)
    game_dir.mkdir(parents=True)
    cap_dir.mkdir()
    for src in files:
        shutil.copy2(src, game_dir / src.name.upper())
    if overrides:
        for src in Path(overrides).iterdir():
            if not src.is_file():
                continue
            if src.name.upper().endswith(".REMOVE"):
                (game_dir / src.name.upper()[:-len(".REMOVE")]).unlink(missing_ok=True)
            else:
                shutil.copy2(src, game_dir / src.name.upper())
    return cfg, entry, run_dir, game_dir, cap_dir


class Log:
    """DOSBox Staging writes its log to stderr.txt in the working directory with -noconsole."""

    def __init__(self, path):
        self.path = path

    def lines(self):
        if not self.path.exists():
            return []
        return self.path.read_text(encoding="utf-8", errors="replace").splitlines()

    def modes(self):
        out = []
        for line in self.lines():
            if "DISPLAY:" in line and "(mode " in line:
                out.append(line.split("(mode ")[1].split(")")[0])
        return out

    def count(self, text):
        return sum(1 for line in self.lines() if text in line)


def _wait(cond, timeout, proc, step=0.1):
    end = time.time() + timeout
    while time.time() < end:
        if cond():
            return True
        if proc.poll() is not None:
            return False
        time.sleep(step)
    return False


def _keep_at_full_speed(pid):
    """Opt the process out of Windows' background throttling and pin it to the fast cores."""
    if os.name != "nt":
        return
    import ctypes
    from ctypes import wintypes

    class PowerThrottling(ctypes.Structure):
        _fields_ = [("Version", wintypes.ULONG), ("ControlMask", wintypes.ULONG), ("StateMask", wintypes.ULONG)]

    kernel32 = ctypes.windll.kernel32
    kernel32.OpenProcess.restype = wintypes.HANDLE
    handle = kernel32.OpenProcess(0x0200 | 0x0400, False, pid)
    if not handle:
        return
    state = PowerThrottling(1, 0x1 | 0x4, 0)
    kernel32.SetProcessInformation(wintypes.HANDLE(handle), 4, ctypes.byref(state), ctypes.sizeof(state))
    mask = common.config().get("fast_cores")
    if mask:
        kernel32.SetProcessAffinityMask.argtypes = [wintypes.HANDLE, ctypes.c_size_t]
        kernel32.SetProcessAffinityMask(wintypes.HANDLE(handle), int(str(mask), 0))
    kernel32.CloseHandle(wintypes.HANDLE(handle))


def _shut_down(proc, hwnd):
    if proc.poll() is not None:
        return
    for attempt in (lambda: winkeys.tap(hwnd, "f12"), lambda: winkeys.close(hwnd)):
        if hwnd is None:
            break
        try:
            attempt()
            proc.wait(timeout=12)
            return
        except subprocess.TimeoutExpired:
            pass
    proc.kill()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass


def run(game, case, run_name=None, opl=False, wave=False, show=False, spec=None):
    """Run one case. Returns (exit code, run directory)."""
    for driver in common.config().get("drivers_that_must_be_stopped", []):
        state = subprocess.run(["sc", "query", driver], capture_output=True, text=True).stdout
        if "RUNNING" in state:
            print(f"COULD-NOT-RUN: the driver {driver} is loaded. DOSBox runs have blue-screened this "
                  f"machine with it loaded; stop it first (on this PC: end the Wave Link tasks).")
            return common.COULD_NOT_RUN, None
    spec = spec or load_case(game, case)
    if spec is None:
        print(f"COULD-NOT-RUN: no case tools/cases/{game}/{case}.json")
        return common.COULD_NOT_RUN, None
    lock = common.oracle_lock()
    lock.parent.mkdir(parents=True, exist_ok=True)
    last_exit = lock.with_name("oracle_last_exit.txt")
    if last_exit.exists():
        wait = COOL_DOWN_SECONDS - (time.time() - last_exit.stat().st_mtime)
        if wait > 0:
            time.sleep(wait)
    lock.write_text(f"{game}/{case}", encoding="ascii")
    try:
        return _run(game, case, run_name or f"{game}_{case}", spec, opl, wave, show)
    finally:
        last_exit.write_text(f"{game}/{case}", encoding="ascii")
        lock.unlink(missing_ok=True)


def _run(game, case, run_name, spec, opl, wave, show):
    prepared = prepare(game, run_name, spec.get("overrides"))
    if prepared is None:
        return common.COULD_NOT_RUN, None
    cfg, entry, run_dir, game_dir, cap_dir = prepared
    if not cfg["dosbox"].exists():
        print(f"COULD-NOT-RUN: DOSBox not found at {cfg['dosbox']}")
        return common.COULD_NOT_RUN, run_dir

    held = [tuple(h) for h in spec["held"]]
    prekeys = [tuple(h) for h in spec["prekeys"]]
    pup = spec["press_until_picture"]
    if pup:
        prekeys = prekeys + [(pup["from"], pup["key"], 0.3)]
    host_key_for = {}
    for _, game_key, _ in held + prekeys:
        if game_key not in host_key_for:
            if len(host_key_for) == len(SPARE_HOST_KEYS):
                print(f"COULD-NOT-RUN: more than {len(SPARE_HOST_KEYS)} different held keys")
                return common.COULD_NOT_RUN, run_dir
            host_key_for[game_key] = SPARE_HOST_KEYS[len(host_key_for)]
    mapper = run_dir / "oracle.map"
    mapper.write_text(MAPPER + "".join(f'key_{k} "key {scan}"\n' for k, (_, scan) in host_key_for.items()),
                      encoding="ascii")
    autotype = ""
    if spec["keys"]:
        autotype = f"autotype -w {spec['key_wait']} -p {spec['key_pace']} {spec['keys']}"
    conf = run_dir / "oracle.conf"
    conf.write_text(CONF.format(
        mapper=mapper.as_posix(), captures=cap_dir.as_posix(), game=str(game_dir),
        cycles=spec["cycles"], nosound="false" if (opl or wave) else "true",
        autotype=autotype, exe=entry["exe"],
    ), encoding="ascii")
    (run_dir / "case.json").write_text(json.dumps({"game": game, "case": case, **spec}), encoding="utf-8")

    log = Log(run_dir / "stderr.txt")
    env = dict(os.environ, SDL_AUDIODRIVER="dummy")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 1 if show else 7          # 7: minimised, not activated
    proc = subprocess.Popen(
        [str(cfg["dosbox"]), "-noprimaryconf", "-nolocalconf", "-conf", str(conf), "-noconsole"],
        cwd=str(run_dir), env=env, startupinfo=startup,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _keep_at_full_speed(proc.pid)
    hwnd = None

    def fail(code, message):
        _shut_down(proc, hwnd)
        print(message)
        return code, run_dir

    hwnd = winkeys.wait_for_window(proc.pid)
    if hwnd is None:
        return fail(common.COULD_NOT_RUN, "COULD-NOT-RUN: DOSBox window never appeared")

    # 1. The game's first picture: its first entry into the EGA mode. Keys the
    # start-up screens need (the "Ready - Press a Key" hardware detection of
    # Galaxy and Dreams) are posted to DOSBox's window meanwhile; they reach
    # the emulated keyboard controller like real key presses, which Dreams'
    # own keyboard handler needs (DOSBox's AUTOTYPE did not wake it).
    want = MODE_OF[entry["engine"]]
    opened = time.time()
    pending = []
    for at, game_key, how_long in prekeys:
        pending.append((at, 0, host_key_for[game_key][0]))
        pending.append((at + how_long, 1, host_key_for[game_key][0]))
    pending.sort()
    while want not in log.modes():
        if proc.poll() is not None or time.time() - opened > 40:
            return fail(common.COULD_NOT_RUN, f"COULD-NOT-RUN: the game never entered mode {want}")
        if pup and not pending and time.time() - opened >= pup["from"]:
            # The start-up screens eat a key pressed while hardware detection
            # is still running (Dreams, up to ~12 s in) and wait for ever
            # afterwards, so the key is tapped again every so often until the
            # first picture appears; the mode is checked before every tap.
            at = time.time() - opened + pup["every"]
            pending = [(at, 0, host_key_for[pup["key"]][0]), (at + 0.3, 1, host_key_for[pup["key"]][0])]
        while pending and time.time() - opened >= pending[0][0]:
            _, is_release, host_key = pending.pop(0)
            (winkeys.key_up if is_release else winkeys.key_down)(hwnd, host_key)
            if not is_release:
                print(f"  posted {host_key} at {time.time() - opened:.1f} s after the window")
        time.sleep(0.02)
    # A key pressed just before the first picture must still be released:
    # left down, the game would see it held for the whole run (found on
    # 2026-10-06: Keen 4 sat on a menu with Enter held, 27 distinct pictures
    # in 75 s instead of the intro and demo).
    for _, is_release, host_key in pending:
        if is_release:
            time.sleep(0.3)
            winkeys.key_up(hwnd, host_key)
    pending = []
    print(f"  first picture (mode {want}) {time.time() - opened:.1f} s after the window")
    # 2. Start recording; retry until DOSBox confirms.
    for _ in range(10):
        winkeys.tap(hwnd, "f8")
        if _wait(lambda: log.count("Capturing Video") > 0, 2, proc):
            break
    else:
        return fail(common.COULD_NOT_RUN, "COULD-NOT-RUN: DOSBox would not start recording")
    if wave:
        winkeys.tap(hwnd, "f9")
        time.sleep(0.3)
    if opl:
        for _ in range(10):
            winkeys.tap(hwnd, "f10")
            if _wait(lambda: log.count("OPL") > 0, 2, proc):
                break
    started = time.time()

    # 3. Real time, pressing the held keys at their moments.
    events = []
    for at, game_key, how_long in held:
        events.append((at, 0, host_key_for[game_key][0]))
        events.append((at + how_long, 1, host_key_for[game_key][0]))
    events.sort()
    exited = False
    while time.time() - started < spec["seconds"]:
        if proc.poll() is not None:
            exited = True
            if spec["may_exit"]:
                break
            return fail(common.FAIL, "FAIL: DOSBox exited before the run finished")
        while events and time.time() - started >= events[0][0]:
            _, is_release, host_key = events.pop(0)
            (winkeys.key_up if is_release else winkeys.key_down)(hwnd, host_key)
        time.sleep(0.005)
    elapsed = time.time() - started

    # 4. Stop recording so the last file is finalised, then shut DOSBox down.
    if proc.poll() is None:
        time.sleep(0.3)
        if wave:
            winkeys.tap(hwnd, "f9")
            time.sleep(0.3)
        stops = log.count("Stopped capturing video")
        winkeys.tap(hwnd, "f8")
        _wait(lambda: log.count("Stopped capturing video") > stops, 3, proc)
        winkeys.tap(hwnd, "f12")
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            winkeys.close(hwnd)
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()

    videos = sorted(cap_dir.glob("*.avi"))
    if not videos:
        print("FAIL: no recording was produced")
        return common.FAIL, run_dir
    recorded = sum(recorded_frames(v) for v in videos) / REFRESH_HZ
    speed = recorded / elapsed if elapsed > 0 else 0.0
    print(f"{game}/{case}: ran {elapsed:.0f} s; {len(videos)} recordings holding {recorded:.1f} s "
          f"({speed:.0%} of full speed){'; the game exited' if exited else ''}")
    if not exited and speed < MIN_SPEED:
        print(f"COULD-NOT-RUN: DOSBox ran at {speed:.0%} of full speed; the machine is too busy for a timed run")
        return common.COULD_NOT_RUN, run_dir
    (run_dir / "videos.txt").write_text("\n".join(v.name for v in videos), encoding="ascii")
    return common.PASS, run_dir


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--as", dest="run_name")
    ap.add_argument("--opl", action="store_true")
    ap.add_argument("--wave", action="store_true")
    ap.add_argument("--show", action="store_true")
    args = ap.parse_args()
    code, _ = run(args.game, args.case, args.run_name, args.opl, args.wave, args.show)
    sys.exit(code)


if __name__ == "__main__":
    main()
