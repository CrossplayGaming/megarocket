# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""AND-01's check: the APK exports from this project and boots to the launcher on the emulator.

    python tools/android_check.py            # export, install, launch, check
    python tools/android_check.py --no-export

The export uses a self-contained copy of the project's Godot (F:/KeenReworkWork/godot_export: the
binary with a `._sc_` marker, its own editor settings naming Android Studio's Java, the SDK and a
local debug keystore, and the Android and Windows templates), so the user's own editor settings are
never touched. The emulator is the AVD `megarocket_test`, run with the host GPU (the software
renderer cannot link Godot's GLES3 shaders: too few fragment uniforms) and no audio.

PASS when: the APK holds libgodot and d2opl for arm64-v8a and x86_64; it installs; the app's log
shows the launcher's first line ("Megarocket ... on Android ..., sound chip ready") and its seven
tiles' messages, with no script error; the screen is the launcher (not a flat colour).

With --import (AND-02 on the device): the development copy of Keen 1 is pushed to the emulator's
Download/Keen1; Import games is pressed and the system picker driven by its labels (uiautomator) to
that folder and its access granted; the app reports Keen 1 imported, the launcher then finds 1 of 7
games, and Keen 1 starts from its tile and draws, with no errors.
"""
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import common

ROOT = common.ROOT
KIT = Path("F:/KeenReworkWork/godot_export")
KEYSTORE = Path("F:/KeenReworkWork/android/debug.keystore")
APK = ROOT / "build" / "android" / "Megarocket.apk"
SDK = Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk"
ADB = SDK / "platform-tools" / "adb.exe"
EMULATOR = SDK / "emulator" / "emulator.exe"
JAVA = Path("C:/Program Files/Android/Android Studio/jbr")
PACKAGE = "org.megarocket.app"
ACTIVITY = PACKAGE + "/com.godot.game.GodotAppLauncher"
AVD = "megarocket_test"


def _kit():
    """The self-contained exporter, made once from the project's Godot and the installed templates."""
    godot_dir = Path(common.config()["godot"]).parent
    templates = Path(os.environ["APPDATA"]) / "Godot" / "export_templates" / "4.7.2.stable"
    kt = KIT / "editor_data" / "export_templates" / "4.7.2.stable"
    kt.mkdir(parents=True, exist_ok=True)
    for exe in ("Godot_v4.7.2-stable_win64.exe", "Godot_v4.7.2-stable_win64_console.exe"):
        if not (KIT / exe).exists():
            shutil.copy2(godot_dir / exe, KIT / exe)
    (KIT / "._sc_").touch()
    for f in ("android_debug.apk", "android_release.apk", "windows_debug_x86_64.exe", "windows_release_x86_64.exe", "version.txt", "icudt_godot.dat"):
        if (templates / f).exists() and not (kt / f).exists():
            shutil.copy2(templates / f, kt / f)
    if not KEYSTORE.exists():
        KEYSTORE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([str(JAVA / "bin" / "keytool.exe"), "-genkeypair", "-keystore", str(KEYSTORE), "-storepass", "android",
                        "-alias", "androiddebugkey", "-keypass", "android", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
                        "-dname", "CN=Android Debug,O=Android,C=US"], check=True, capture_output=True)
    (KIT / "editor_data" / "editor_settings-4.7.tres").write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        f'export/android/java_sdk_path = "{JAVA.as_posix()}"\n'
        f'export/android/android_sdk_path = "{SDK.as_posix()}"\n'
        f'export/android/debug_keystore = "{KEYSTORE.as_posix()}"\n'
        'export/android/debug_keystore_user = "androiddebugkey"\n'
        'export/android/debug_keystore_pass = "android"\n', encoding="utf-8")
    return KIT / "Godot_v4.7.2-stable_win64_console.exe"


def export():
    godot = _kit()
    APK.parent.mkdir(parents=True, exist_ok=True)
    if APK.exists():
        APK.unlink()
    p = subprocess.run([str(godot), "--headless", "--path", str(ROOT / "godot"), "--export-debug", "Android", str(APK)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1200)
    if not APK.exists():
        print((p.stdout + p.stderr)[-2000:])
        return False
    return True


def adb(*args, timeout=120):
    env = dict(os.environ, MSYS_NO_PATHCONV="1")
    return subprocess.run([str(ADB), *args], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout, env=env)


def ensure_emulator():
    if "emulator-" in adb("devices").stdout:
        return True
    log = open(Path("F:/KeenReworkWork/android/emulator.log"), "w")
    subprocess.Popen([str(EMULATOR), "-avd", AVD, "-gpu", "host", "-no-audio", "-no-snapshot-save", "-no-boot-anim"],
                     stdout=log, stderr=subprocess.STDOUT)
    for _ in range(120):
        time.sleep(5)
        if adb("shell", "getprop", "sys.boot_completed").stdout.strip() == "1":
            return True
    return False


def screenshot(path):
    path.write_bytes(subprocess.run([str(ADB), "exec-out", "screencap", "-p"], capture_output=True, timeout=60).stdout)
    from PIL import Image
    return Image.open(path).convert("RGB")


def tap_fraction(fx, fy):
    im = screenshot(Path("F:/KeenReworkWork/android/tap.png"))
    adb("shell", "input", "tap", str(int(im.size[0] * fx)), str(int(im.size[1] * fy)))


def tap_text(label, seconds=20):
    """Taps the on-screen element whose text is `label` (Android views only: the system picker)."""
    until = time.time() + seconds
    while time.time() < until:
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        xml = adb("shell", "cat", "/sdcard/ui.xml").stdout
        for m in re.finditer(r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
            if m.group(1).strip().lower() == label.lower():
                x1, y1, x2, y2 = (int(v) for v in m.groups()[1:])
                adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
                return True
        time.sleep(1)
    return False


def visible_text(label):
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    return f'text="{label}"'.lower() in adb("shell", "cat", "/sdcard/ui.xml").stdout.lower()


def wait_log(pattern, seconds):
    until = time.time() + seconds
    while time.time() < until:
        log = adb("logcat", "-d", "-s", "godot:V").stdout
        if re.search(pattern, log):
            return log
        time.sleep(1)
    return adb("logcat", "-d", "-s", "godot:V").stdout


def import_stage(ok):
    data = Path(common.config()["game_data"]) / "keen1"
    adb("shell", "rm", "-rf", "/sdcard/Download/Keen1")
    adb("push", str(data), "/sdcard/Download/Keen1", timeout=300)
    tap_fraction(0.728, 0.092)          # Import games (the launcher's own UI)
    time.sleep(3)
    if not visible_text("Keen1"):
        tap_text("Download")
    picked = tap_text("Keen1") and tap_text("Use this folder") and tap_text("Allow")
    ok("the system picker reached Download/Keen1 and its access was granted", picked)
    log = wait_log(r"Imported: Commander Keen 1", 90)
    ok("the app reports Keen 1 imported", "Imported: Commander Keen 1" in log)
    adb("shell", "input", "keyevent", "66")    # Enter: Done
    log = wait_log(r"1 of 7 games found", 30)
    ok("the launcher then finds 1 of 7 games", "1 of 7 games found" in log)
    tap_fraction(0.23, 0.44)            # the Keen 1 tile
    log = wait_log(r"Started Commander Keen 1", 20)
    time.sleep(8)
    im = screenshot(Path("F:/KeenReworkWork/android/keen1.png"))
    colours = len(im.resize((160, 80)).getcolors(maxcolors=160 * 80))
    ok(f"Keen 1 starts from its tile and draws ({colours} colours)", "Started Commander Keen 1" in log and colours > 4)
    log = adb("logcat", "-d", "-s", "godot:V").stdout
    errors = [l for l in log.splitlines() if "SCRIPT ERROR" in l or ("E godot" in l and "ERROR:" in l)]
    ok("no errors through the import and the game" + (f" (first: {errors[0][-120:]})" if errors else ""), not errors)
    adb("shell", "am", "force-stop", PACKAGE)


def main():
    checks = []

    def ok(label, cond):
        checks.append(cond)
        print(("  ok    " if cond else "  FAIL  ") + label)

    if "--no-export" not in sys.argv:
        if not export():
            print("FAIL: the export failed")
            return 1
    names = zipfile.ZipFile(APK).namelist()
    for arch in ("arm64-v8a", "x86_64"):
        ok(f"the APK holds libgodot and d2opl for {arch}",
           f"lib/{arch}/libgodot_android.so" in names and any(n.startswith(f"lib/{arch}/libd2opl") for n in names))
    if not ensure_emulator():
        print("COULD-NOT-RUN: the emulator did not boot")
        return 2
    ok("it installs", "Success" in adb("install", "-r", str(APK), timeout=300).stdout)
    adb("shell", "am", "force-stop", PACKAGE)
    adb("shell", "pm", "clear", PACKAGE)    # a first start: nothing imported, nothing remembered
    adb("logcat", "-c")
    adb("shell", "am", "start", "-W", "-n", ACTIVITY)
    time.sleep(15)
    log = adb("logcat", "-d", "-s", "godot:V").stdout
    head = re.search(r"Megarocket \S+ on (\w+) \(([^)]*)\), sound chip (\w+)", log)
    ok("the launcher's first line: %s" % (head.group(0) if head else "missing"),
       bool(head) and head.group(1) == "Android" and head.group(3) == "ready")
    tiles = len(set(re.findall(r"Looks for (\S+)", log)))
    ok(f"the seven tiles' messages ({tiles} games looked for)", tiles >= 7)
    errors = [l for l in log.splitlines() if "SCRIPT ERROR" in l or ("E godot" in l and "ERROR:" in l)]
    ok("no errors in the app's log" + (f" (first: {errors[0][-120:]})" if errors else ""), not errors)
    shot = Path("F:/KeenReworkWork/android/launcher.png")
    shot.write_bytes(subprocess.run([str(ADB), "exec-out", "screencap", "-p"], capture_output=True, timeout=60).stdout)
    try:
        from PIL import Image
        im = Image.open(shot).convert("RGB")
        colours = len(im.resize((160, 80)).getcolors(maxcolors=160 * 80))
        ok(f"the screen is the launcher, not a flat colour ({colours} colours; {shot})", colours > 8)
    except Exception as err:      # a screenshot that cannot be read proves nothing
        ok(f"the screenshot can be read ({err})", False)
    if "--import" in sys.argv:
        import_stage(ok)
    print(f"{sum(checks)} of {len(checks)} checks passed")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
