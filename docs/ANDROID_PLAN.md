# Megarocket Android — Phase Plan

Drafted 2026-08-28 from the portability audit done in the Windows audio-fix session.
The long-standing decision (DESIGN_NOTES.md "Long-term possibilities") is now active work.
Read this first if you're the conversation picking the Android work up.

## Ground rules (carried over, non-negotiable)

- **One portable codebase.** Engines build for Windows and Android from identical
  sources; platform code stays `#ifdef`'d or in per-platform backend files. No
  Android-only engine forks.
- **Replay gates still govern.** The simulation is platform-independent C; the
  desktop harness (`verify/run_verify.ps1`) keeps protecting every engine change.
  Add a one-time on-device checksum replay per engine as an Android sanity gate.
- **No game data in the APK.** Same constructive posture as the Windows dist:
  users supply their own files.

## Repo layout decision

- Android work lives in **this repo and the existing engine forks** — no new repo.
- New top-level `android/` directory: the Gradle project, launcher shell activity,
  per-engine SDL activities, touch overlay assets.
- Main repo work happens on an **`android` branch** until first light, then merges.
  Engine-fork changes go on their existing branches (`megarocket`, `keenlauncher`)
  since they must stay `#ifdef`-portable anyway.

## Portability audit results (2026-08-28)

| Component | State |
|---|---|
| refkeen (Dreams) | **Official Android project in-tree** (`refkeen/src/android-project/`, Gradle). SDL3. Shortest path to first light. |
| keen13 port | One Win32 block total (crash reporter, `idlib13.c:431`, has no-op fallback). LZEXE boot-rip is pure C. MSVC `/FI` force-include → clang `-include`. |
| omnispeak fork | Plain SDL2 renderer backend, nothing platform-bound; needs stock SDL2 Android template. Audio drift fix is Win32-path-only; Android uses callback audio (immune). |
| launcher | All six `_WIN32` blocks are the CreateProcess/WaitForSingleObject launch model — **the one real architecture change**. Remaining ~1,300 lines are pure SDL2 and carry over. |

## The launch-model replacement (the architectural piece)

Android can't spawn engine exes (SDL apps need their Java activity). Target design:
**one APK; each engine is a shared library with its own SDL activity declared in its
own `android:process`**. The launcher activity fires an Intent and waits for the
activity result — which preserves the existing "launcher blocks while a game runs"
design exactly. Engine exit → process dies → launcher resumes.

## Phases

1. **Prereqs / spike** — Android SDK+NDK install, test device. Build refkeen's own
   android-project with the fork's `keenlauncher` branch. First light for Keen Dreams
   validates the widescreen compositor on mobile GLES with near-zero scaffolding.
2. **Engine libraries** — omnispeak and keen13 (×3 episodes) as `.so` targets on the
   stock SDL2 Android template. Fix whatever small portability lint surfaces
   (gcc/clang flags, case-sensitive filenames, `/FI` replacement).
3. **Launcher shell** — port `launcher/launcher.c` UI to an SDL activity; replace the
   six Win32 launch blocks with the Intent/activity-result model above.
4. **Data import** — scoped storage: SAF folder picker, copy user files into app
   storage. Existing detection logic then works unchanged on those paths.
5. **Art-pull rework** — the hidden-window subprocess pull can't work on Android.
   Either an in-process headless dump mode per engine or lazy pull on each game's
   first real launch. Text-tile fallback already exists, so this degrades safely.
6. **Touch overlay** — on-screen controls for gameplay; tap navigation in the
   launcher. Physical pads already work via SDL (Android TV / Bluetooth-pad builds
   are nearly free; consider TV-first as an early shippable).
7. **Lifecycle QA** — pause/resume, process death and state restore, cutouts/notches,
   audio latency pass, on-device checksum replays, then release packaging (APK
   signing, versioning alongside the Windows zip releases).

## Progress log

**2026-08-28 — Phase 1 spike: refkeen APK builds.**
- Toolchain confirmed on the dev PC: SDK (build-tools 34-37, platforms 35/37),
  NDK 29.0.14206865, Android Studio JBR as JDK. No emulator installed; install/run
  needs a physical device on adb.
- Official SDL 3.2.30 source lives at `deps\SDL3-3.2.30` (deliberately NOT the
  patched sandstranger SDL fork vendored in F:\DoomAndroid).
- Wiring (local, not committed; junctions + copies per refkeen COMPILING.md):
  `jni\SDL` -> deps SDL source, `jni\ReflectionHLE` -> refkeen repo root,
  SDL's `org.libsdl.app` Java tree copied into `src/main/java`, `local.properties`
  with sdk.dir. All git-excluded via `refkeen/.git/info/exclude`.
- Fork fixes needed (in refkeen fork, on `keenlauncher` branch):
  `reflectionhle/build.gradle` ndkVersion 28.2 -> 29.0.14206865, and
  `be_video.c` KL-compositor guards `REFKEEN_VER_KDREAMS` ->
  `REFKEEN_HAS_VER_KDREAMS` (Android's unified backend build compiles be_video.c
  without per-game defines; the HAS_VER form is upstream's convention and is
  defined in both desktop and unified builds — no-op on Windows).
- Result: `gradlew assembleDebug` -> 27 MB APK, all four ABIs, all seven
  `BE_ST_KL_*` compositor symbols confirmed present in libreflectionhle.so.
- Desktop no-op after the guard change verified: Windows rebuild passes the
  Dreams replay gate (494 frames bit-identical). Fork fixes pushed
  (CrossplayGaming/ReflectionHLE@71708ac).

**2026-08-28 — FIRST LIGHT: Keen Dreams runs on Android.**
- Standing emulator infrastructure installed (user-requested, works headlessly
  for remote sessions): SDK `emulator` package + `system-images;android-35;
  google_apis;x86_64`, AVD **`megarocket_test`** (Pixel 5 profile, Android 15).
  Boot with `emulator -avd megarocket_test -gpu swiftshader_indirect -no-audio`;
  drive via adb (`input tap/swipe/keyevent`, `exec-out screencap`).
  Gotchas hit: sdkmanager.bat needs JAVA_HOME (Android Studio jbr) and exits 0
  even on failure; Git Bash mangles `/sdcard` paths (set MSYS_NO_PATHCONV=1).
- APK installed; storage granted via
  `appops set com.reflectionhle MANAGE_EXTERNAL_STORAGE allow` (emulator only —
  real users go through the app's own permission flow, which was verified too).
- Game data pushed to `/sdcard/kdreams` (kdreams.exe + 3 .kdr), detected via the
  in-app browser as "Keen Dreams EGA v1.00" (same kdreamse100 as the replay
  gate). Game boots: Softdisk screen -> title/credits, rendered INSIDE the
  fork's framed widescreen backdrop — the BE_ST_KL_* compositor path works on
  mobile GLES. Screenshots delivered in-session.
- NOT yet exercised on Android: actual level gameplay/input, audio, lifecycle
  (pause/resume), touch controls (none exist yet — phase 6).

**2026-08-28 — Phase 2 (part 1): Keen 4-6 (omnispeak) runs on Android, widescreen.**
- `android/` Gradle project created in this repo (branch `android`): top-level
  build files + `omnispeak` application module (SDL2 activity, CMake wiring).
  Per-machine junctions and SDL Java copy documented in `android/README.md`.
- SDL2 2.32.10 source at `deps\SDL2-2.32.10-src` (official, downloaded under the
  user's standing build-deps approval).
- Omnispeak fork changes (CrossplayGaming/omnispeak@cdb8e65): CMakeLists in-tree
  SDL2 target + Android shared-lib/SDL_main mode; id_fs.c defaults paths to
  SDL_AndroidGetExternalStoragePath() on Android (permissionless, adb-pushable).
  Desktop verified: all four Keen 4 replay gates bit-identical after the change.
- First build compiled CLEAN across all four ABIs — zero portability errors.
- Verified on emulator: APK installs, Keen 4 data pushed to
  `/sdcard/Android/data/com.megarocket.omnispeak/files/`, game boots through
  terminator intro into the demo loop **with the widescreen compositor active**.
- NOT yet: Keen 5/6 data smoke test (same engine; low risk), audio
  verification on-device, touch controls (phase 6).

**2026-08-28 — Phase 2 (part 2): Keen 1-3 runs on Android, widescreen.**
- `android/keen13` module: ONE APK, three SDL activities (Keen1/2/3Activity),
  each in its own `android:process` loading its own episode library — this
  validates the activity-per-process model phase 3's launcher shell needs.
- keen13 port made clang/bionic-clean (all in this repo, `android` branch):
  `<io.h>` guarded MSVC-only; compat layer grew a POSIX branch (filelength/
  strupr/itoa/ltoa via k13_ helpers, S_IREAD/S_IWRITE, `inp` mapping) and
  prototypes for the port-provided functions the reconstruction calls
  implicitly (bioskey, printscan, K13_QLoad*, harderr...); port-I/O prototypes
  after IDLIB.H's #undef block; KEENMAIN's dummy ctrl/lastctrl de-static'd;
  `-fcommon` on Android targets (the reconstruction relies on tentative-
  definition merging, Turbo C/MSVC semantics).
- Android entry: `k13_android.c` wraps the Borland-style `void main` (renamed
  k13_realmain) in an exported SDL_main that chdirs to app storage first, so
  every relative fopen in the engine works unchanged.
- Desktop verified after every shared-source change: MSVC rebuild clean, all
  three keen13 replay gates PASS (741/589/596 frames).
- On emulator: Keen 1 demo loop in widescreen (boot-time LZEXE rip of the
  user's KEEN1.EXE works on ARM); Keen 2 boots to the Apogee intro via its own
  activity/library. Keen 3 not yet smoked (same pattern).
- Desktop keen13 builds: note the PATH cmake 4.4 fails to reconfigure the
  existing build dir — use the VS BuildTools cmake (as build_megarocket.ps1
  does).

## Notes

- refkeen is SDL3, the rest SDL2 — both support Android; the APK carries both.
- Precedent for the whole exercise: the user's TURBOSTEIN ECWolf Android launcher
  (packaging/Gradle terrain already familiar).
- Windows release flow is unaffected throughout; `build_megarocket.ps1` stays as-is.
