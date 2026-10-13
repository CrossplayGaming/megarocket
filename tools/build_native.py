# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""NATIVE-01: build the one native library (native/d2opl, the AdLib chip) for every target.

  python tools/build_native.py            Windows x86_64 (gcc), Android arm64 + x86_64 (NDK clang)
  python tools/build_native.py --linux    also Linux x86_64 through WSL's gcc
  python tools/build_native.py --selftest the chip's own self-test built with each host compiler,
                                          plus the Android x86_64 self-test run on the emulator
                                          when one is up; all must give the same samples

Godot's interface header is not kept in the repository; the configured Godot
writes it out first.
"""

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

import common

SOURCES = ["opl2.c", "blit.c", "d2opl_gdextension.c"]
NDK = Path(os.environ.get("ANDROID_NDK_HOME", "")) if os.environ.get("ANDROID_NDK_HOME") else None
NDK_CANDIDATES = [
    Path.home() / "AppData/Local/Android/Sdk/ndk",
    Path("C:/Android/ndk"),
]
ANDROID_API = 21
ANDROID_TARGETS = {          # Godot export name -> clang triple prefix
    "arm64": "aarch64-linux-android",
    "x86_64": "x86_64-linux-android",
}


def find_ndk():
    if NDK and NDK.exists():
        return NDK
    for base in NDK_CANDIDATES:
        if base.is_dir():
            versions = sorted(p for p in base.iterdir() if p.is_dir())
            if versions:
                return versions[-1]
    return None


def ndk_clang(ndk, triple):
    host = "windows-x86_64" if platform.system() == "Windows" else "linux-x86_64"
    exe = ndk / "toolchains" / "llvm" / "prebuilt" / host / "bin" / f"{triple}{ANDROID_API}-clang"
    if platform.system() == "Windows":
        exe = exe.with_suffix(".cmd")
    return exe if exe.exists() else None


def interface_header(cfg, build):
    dumped = subprocess.run([str(cfg["godot"]), "--headless", "--dump-gdextension-interface"],
                            cwd=build, capture_output=True, text=True, timeout=120)
    if not (build / "gdextension_interface.h").exists():
        print("COULD-NOT-RUN: Godot did not write its interface header")
        print(dumped.stdout[-500:], dumped.stderr[-500:])
        return False
    return True


def host_gcc(cfg):
    gcc = str(cfg.get("gcc") or "")
    if not gcc or not Path(gcc).exists():
        gcc = shutil.which("gcc") or ""
    return gcc


def gcc_env(gcc):
    # MinGW's compiler needs its own folder on the PATH to find its parts.
    return dict(os.environ, PATH=str(Path(gcc).parent) + os.pathsep + os.environ["PATH"])


def build_windows(gcc, src, build, out_dir):
    target = out_dir / "d2opl.windows.x86_64.dll"
    cmd = [gcc, "-O2", "-std=c99", "-Wall", "-Wextra", "-Wno-cast-function-type", "-shared", "-o", str(target),
           *[str(src / name) for name in SOURCES], f"-I{build}", f"-I{src}", "-static-libgcc", "-lm"]
    done = subprocess.run(cmd, capture_output=True, text=True, env=gcc_env(gcc))
    if done.returncode != 0:
        print(done.stdout, done.stderr)
        print("FAIL: the Windows library did not compile")
        return False
    print(f"built {target.name} ({target.stat().st_size} bytes)")
    return True


def build_android(ndk, src, build, out_dir):
    ok = True
    for arch, triple in ANDROID_TARGETS.items():
        clang = ndk_clang(ndk, triple)
        if clang is None:
            print(f"FAIL: no NDK compiler for {triple} under {ndk}")
            ok = False
            continue
        target = out_dir / f"libd2opl.android.{arch}.so"
        cmd = [str(clang), "-O2", "-std=c99", "-Wall", "-Wextra", "-shared", "-fPIC", "-fvisibility=hidden",
               "-o", str(target), *[str(src / name) for name in SOURCES], f"-I{build}", f"-I{src}", "-lm"]
        done = subprocess.run(cmd, capture_output=True, text=True)
        if done.returncode != 0 or not target.exists():
            print(done.stdout, done.stderr)
            print(f"FAIL: the Android {arch} library did not compile")
            ok = False
            continue
        print(f"built {target.name} ({target.stat().st_size} bytes)")
    return ok


def wsl_path(path):
    path = Path(path).resolve()
    return f"/mnt/{path.drive[0].lower()}{path.as_posix()[2:]}"


def build_linux(src, build, out_dir):
    target = out_dir / "libd2opl.linux.x86_64.so"
    cmd = ["wsl", "-e", "gcc", "-O2", "-std=c99", "-Wall", "-Wextra", "-Wno-cast-function-type", "-shared",
           "-o", wsl_path(target), *[wsl_path(src / name) for name in SOURCES],
           f"-I{wsl_path(build)}", f"-I{wsl_path(src)}", "-fPIC", "-fvisibility=hidden", "-lm"]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0 or not target.exists():
        print(done.stdout, done.stderr)
        print("FAIL: the Linux library did not compile (is gcc installed in WSL?)")
        return False
    print(f"built {target.name} ({target.stat().st_size} bytes)")
    return True


def selftest(cfg, gcc, src, build):
    """The chip's self-test (a fixed register script rendered to samples and
    fingerprinted) built with every compiler in reach; all fingerprints must
    agree, and a planted change to the chip must be noticed."""
    results = {}
    env = gcc_env(gcc)
    program = build / "opl2_selftest.exe"
    for label, flags in (("Windows gcc -O2", ["-O2"]), ("Windows gcc -O0", ["-O0"])):
        done = subprocess.run([gcc, *flags, "-std=c99", "-o", str(program), str(src / "opl2.c"),
                               str(src / "opl2_selftest.c"), f"-I{src}", "-lm"],
                              capture_output=True, text=True, env=env)
        if done.returncode != 0:
            print(done.stderr)
            print("FAIL: the self-test did not compile")
            return common.FAIL
        ran = subprocess.run([str(program)], capture_output=True, text=True, env=env)
        results[label] = (ran.returncode, ran.stdout.strip())
    ndk = find_ndk()
    if ndk is not None:
        clang = ndk_clang(ndk, ANDROID_TARGETS["x86_64"])
        adb = shutil.which("adb") or str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe")
        devices = subprocess.run([adb, "devices"], capture_output=True, text=True).stdout if Path(adb).exists() else ""
        if clang is not None and "\tdevice" in devices:
            prog = build / "opl2_selftest_android"
            done = subprocess.run([str(clang), "-O2", "-std=c99", "-fPIE", "-pie", "-o", str(prog),
                                   str(src / "opl2.c"), str(src / "opl2_selftest.c"), f"-I{src}", "-lm"],
                                  capture_output=True, text=True)
            if done.returncode == 0:
                subprocess.run([adb, "push", str(prog), "/data/local/tmp/opl2_selftest"], capture_output=True)
                ran = subprocess.run([adb, "shell", "chmod 755 /data/local/tmp/opl2_selftest && /data/local/tmp/opl2_selftest"],
                                     capture_output=True, text=True)
                results["Android x86_64 (emulator)"] = (ran.returncode, ran.stdout.strip())
            else:
                print(done.stderr)
        else:
            print("  (no Android run: no emulator or device attached)")
    for label, (code, text) in results.items():
        print(f"  {label}: {text}{'' if code == 0 else '   <-- did not run, or was silent'}")
    same = len({text for _, text in results.values()}) == 1 and all(code == 0 for code, _ in results.values())
    print(f"{len(results)} builds, {'all give the same samples' if same else 'they DIFFER'}")
    # A deliberately different chip: one table entry changed must not match.
    changed = (src / "opl2.c").read_text(encoding="utf-8").replace("% 210", "% 211", 1)
    (build / "opl2_planted.c").write_text(changed, encoding="utf-8")
    done = subprocess.run([gcc, "-O2", "-std=c99", "-o", str(program), str(build / "opl2_planted.c"),
                           str(src / "opl2_selftest.c"), f"-I{src}", "-lm"], capture_output=True, text=True, env=env)
    ran = subprocess.run([str(program)], capture_output=True, text=True, env=env)
    noticed = done.returncode == 0 and ran.stdout.strip() not in {text for _, text in results.values()}
    print(f"  planted (the tremolo cycle one step longer): {'noticed' if noticed else 'NOT noticed   <-- WRONG'}")
    return common.PASS if same and noticed else common.FAIL


def main():
    cfg = common.config()
    src = common.ROOT / "native" / "d2opl"
    out_dir = common.ROOT / "godot" / "bin"
    out_dir.mkdir(exist_ok=True)
    build = cfg["oracle_runs"].parent / "native_build"
    build.mkdir(parents=True, exist_ok=True)
    gcc = host_gcc(cfg)
    if not gcc:
        print("COULD-NOT-RUN: no C compiler found (set \"gcc\" in tools/config.json)")
        return common.COULD_NOT_RUN
    if not interface_header(cfg, build):
        return common.COULD_NOT_RUN
    if "--selftest" in sys.argv:
        return selftest(cfg, gcc, src, build)
    ok = build_windows(gcc, src, build, out_dir)
    ndk = find_ndk()
    if ndk is None:
        print("FAIL: no Android NDK found (set ANDROID_NDK_HOME)")
        ok = False
    else:
        ok &= build_android(ndk, src, build, out_dir)
    if "--linux" in sys.argv:
        ok &= build_linux(src, build, out_dir)
    return common.PASS if ok else common.FAIL


if __name__ == "__main__":
    sys.exit(main())
