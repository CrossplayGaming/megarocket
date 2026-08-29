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

**2026-08-28 — Phase 3: the launcher shell runs on Android. Verified end-to-end.**
- New `android/megarocket` module: ONE APK, applicationId `com.megarocket` —
  MegarocketActivity (the shell, launcher.c as an SDL library) plus
  OmnispeakActivity (:keen46, episode via intent extra → /EPISODE /GAMEPATH
  /USERPATH args) and Keen1/2/3Activity (:keen1/2/3, per-episode K13_CWD env).
  All engines share ONE files dir mirroring the desktop tree
  (`files/rt`, `files/keen13/gamedata{,2,3}`) — which is also what makes
  detection possible under scoped storage.
- launcher.c Android support (#ifdef'd): root = external-files dir + chdir;
  detect() checks data only (engines are in the APK; Dreams slot = is the
  ReflectionHLE app installed, via JNI); launch() = JNI → launchSlot() →
  Intent. "Blocks while the game runs" maps to activity pause/resume; a
  game's exit(0) kills only its own process.
- Dreams slot launches the separate com.reflectionhle app (manifest needs
  the <queries> package entry for visibility).
- Verified on emulator: all 7 slots READY; Keen 1 launched from the shell;
  launcher resumed cleanly after backgrounding (no GL loss); Keen 4 launched
  with correct episode selection. Desktop: launcher + omnispeak rebuilt,
  replay gates bit-identical, launcher/keenlauncher.exe refreshed.
- NOT yet: in-game-quit → launcher return flow (needs deep menu keyevents or
  hands-on), art pull on Android (phase 5; text tiles show), touch controls
  (phase 6 — launcher itself is keyboard/pad-driven; tiles need tap support),
  Dreams data unification, app icon.

**2026-08-28 — Phase 6: touch controls + carousel UI. Verified on emulator.**
- Launcher (launcher.c, shared source, desktop unchanged): tap/click support
  (mouse events; Android synthesises them from touch), with present()-matched
  letterbox-offset mapping; Android back button = ESC; tapping the title strip
  opens Help.
- **Carousel mode** (user-requested small-screen UI): one horizontal row,
  selection centred with ease animation, swipe-to-browse with snap, tap to
  select/play. Default on Android; desktop keeps the grid; KEEN_CAROUSEL=1/0
  overrides (works with KEEN_SHOT for headless layout review). Tile drawing
  refactored into draw_tile() shared by both modes, thumb blit bounds-checked
  for edge-clipped tiles.
- **In-game touch overlay** — pure Java, zero engine changes: TouchOverlay
  view over the SDL surface injects Android key events via SDLActivity's
  onNativeKeyDown/Up. D-pad (multi-touch, 8-way) left; JUMP(Ctrl) POGO(Alt)
  FIRE(Space) right; ESC/ENTER top corners. EngineActivity base adds it to
  all four game activities. Dreams needs none (refkeen ships its own touch UI).
- Verified: tap-select/tap-play in both layouts; swipe scroll + snap;
  overlay renders over Keen 4 and its ENTER/ESC drive omnispeak's menus
  (key injection proven); Keen 4 launched from a carousel tap.
- Emulator gotcha hit: the AVD resumed an old default_boot snapshot and the
  pushed game data "vanished" — snapshot timelines can roll back /sdcard.
  Boot with -no-snapshot-save consistently, or repush data after restores.
- NOT yet: overlay auto-hide when a controller is present; button layout
  tuning wants real thumbs on real glass (deferred to hands-on testing).

**2026-08-28 — Phase 4: data import + self-sufficient APK. Verified end-to-end.**
- Playing an empty slot now opens the system folder picker (SAF, no
  permissions): Java walks the chosen tree, routes recognised files into the
  collection layout (.CK1-3 + KEEN?.EXE -> keen13/gamedata* uppercased,
  .CK4-6 -> rt, .kdr/kdreams.exe -> keendreams/game), copying in a background
  thread with retries; the launcher re-detects every 2s so slots light up
  live. How-To's first lines describe the tap-to-import flow on Android.
- Omnispeak's public metadata now ships IN the APK (gradle copies it from the
  junctioned engine tree into generated assets at build time — constructive
  copy, nothing new committed) and self-extracts to files/rt on first run.
  The APK is fully self-sufficient: install, import your files, play.
- Carousel tiles are now DOUBLE size (the row exists to make selections big
  and readable): tiles render 1x into a scratch buffer and blit back pixel-
  doubled, so art/text/badges all scale; hit-testing and spacing follow.
- Fixed: SDL overrides the manifest's landscape on cold boot (resizable
  window -> sensor-any) — setOrientationBis is now pinned to sensor-landscape
  in both activity bases. Found only on a cold-booted emulator; warm sessions
  had inherited landscape.
- Verified with a wiped app + files staged in Download/MyKeenFiles: picker ->
  grant -> Keen 1 lights up in-place seconds later. (Test-harness note: adb
  pushes into fresh /sdcard dirs can silently drop files — verify staging
  with ls, not push exit codes.)
- NOT yet: an "import" affordance when slots are already lit (re-import works
  by tapping any remaining empty slot); import progress feedback (copies are
  near-instant for these file sizes).

**2026-08-28 — Phase 5: title-art pull on Android + two LP64 crash fixes.**
- Design: no hidden windows on Android, so each game's FIRST NATURAL RUN
  doubles as the art pull. Omnispeak decodes title art + backdrop tile at
  boot if missing (ck_main, Android-guarded; fork @). keen13 gains
  K13_ARTDUMP_STAY=1: dump at the title screen only if the file is missing,
  then keep playing instead of exiting (env set by the Keen1-3 activities).
  The launcher refreshes art/backdrop when its window regains focus — on
  Android launch() returns immediately, so "after a game" = focus-gained.
- Note: launcher tiles use the user-chosen text style (tile_style()==3);
  the pull's visible payoff is the game-data BACKDROP pattern (and art is
  banked for style 0). Verified: Keen 1's night-sky tile behind the shell.
- **Two real LP64 bugs found via a SIGSEGV in Keen 1 on Android** (long is
  8 bytes on Android, 4 on MSVC/DOS; desktop could never see either):
  1) bloadinLZW read a 32-bit DOS length field with sizeof(long) — garbage
     length AND misplaced file cursor;
  2) LZW_ReadCode's bit buffer relies on being EXACTLY 32 bits (code =
     buffer >> (32-len); overflow discarded on <<=) — 64-bit long fed
     garbage bits into every code -> wild table index -> crash. Buffer is
     now Uint32 under K13_PORT.
  Desktop rebuilt after each; keen13 replay gates bit-identical (3x PASS).
  The standalone-APK Keen 1 success earlier was luck (allocation layout).
- Verified on emulator: Keen 1 runs to title (fully rendered), dumps art +
  backdrop, keeps playing; Keen 4 dumps at boot; launcher backdrop switches
  to game art. Dropbox APK refreshed with the fixed build.
- Emulator-driving lesson: blind coordinate taps compound (picker opened
  twice mid-test); prefer keyevents + force-stop/cold-start for determinism.
- PENDING (important): run the keen13 replay gates ON-DEVICE — LP64 long
  arithmetic could shift sim behavior on Android in other places; the
  KL_REPLAY/checksum harness is the honest check (needs an env hook in the
  activities or a debug intent extra).

**2026-08-28 — Hands-on feedback round 1 (user, on-phone with Backbone).**
Gameplay reported working well. Fixes/deliverables:
- TouchOverlay hides itself while any real external controller (Bluetooth /
  Backbone / USB — SOURCE_GAMEPAD|JOYSTICK, non-virtual) is attached, via an
  InputManager listener; reappears on disconnect. Verified visible-without-
  pad on the emulator; the hide path needs the user's Backbone (emulator
  cannot fake a physical pad).
- Dropbox kit: added the ReflectionHLE debug APK (Dreams is its own app —
  without it the Dreams tile stays dark; the .kdr data was already in the
  kit) and a PHONE SETUP README covering both APKs + the import flow.

**No-keyboard/no-mouse completeness audit** (user requirement: EVERYTHING
functional pad-only, and touch-only):
- Launcher: full pad coverage (dpad/stick browse, A play, B quit/back,
  shoulders cycle Help/About); touch: tap/swipe/title-tap. Import uses the
  system picker: dpad-navigable in DocumentsUI, touch always available.
- Keen 1-3: gameplay binds (jump/pogo/fire + status/qsave/qload/help/sound/
  savemenu/quit/scorebox) all pad-bindable; menus via injected scancodes
  (dpad->arrows, Start->Enter, Back->ESC); "press a key" screens accept any
  injected key. KNOWN MINOR: high-score name entry has no pad letters —
  Start (Enter) dismisses with the name as-is.
- Keen 4-6: full in_joy_* bindings incl. menu button, quicksave/load;
  US_LineInput (save names, high scores) already maps pad A=Enter (accept
  default/current name), B=Escape; IN_StartTextInput triggers SDL text
  input, which on Android raises the soft keyboard for touch users. VERIFY
  ON DEVICE: soft keyboard actually appearing over the save dialog.
- Dreams (refkeen): upstream ships pad support and its own on-screen
  keyboard/UI.
- Overlay (touch-only path): dpad + JUMP/POGO/FIRE + ESC/ENTER covers every
  gameplay and menu interaction the engines expose.

**2026-08-29 — Dreams unification: ONE APK, all seven games. Verified.**
- SDL2 and SDL3 Java glue coexist in the Megarocket APK: SDL3's glue is
  package-renamed to org.libsdl3.app by android/patch-sdl3-java-package.ps1
  (Java package/imports + the five JNI class-path strings in
  SDL_android.c), applied once to the vendored deps tree; the refkeen
  standalone project uses the same renamed glue.
- DreamsActivity (:dreams process) extends the SDL3 glue, chdirs the engine
  into files/keendreams/game via RHLE_CWD, and passes the DESKTOP
  launcher's exact invocation (-gamever kdreamse100 -cfgdir cfg -datadir
  data) -> refkeen's 'Local' current-dir scan finds the imported files and
  boots STRAIGHT into the game: no refkeen menus, no All-Files permission,
  no picker. Stubs requestReadExternalStoragePermission (returns 0; data
  is app-local).
- refkeen fork (@31c7ee0): enable CMDLINE on Android; RHLE_CWD chdir at
  main; fix target_link_libraries keyword order on the never-before-used
  non-unified Android path. Megarocket builds refkeen with
  -DBUILD_UNIFIED=OFF so reflection-kdreams is its own shared lib.
- Launcher: Dreams slot now detects DATA (egagraph.kdr) like every slot;
  the separate-app package check and <queries> are gone; the importer's
  .kdr routing feeds it. launchSlot -> internal DreamsActivity.
- Verified on emulator: Dreams tile lit from data, boots to Softdisk
  screen and full title/credits with the widescreen frame; Keen 1 (SDL2)
  still launches from the same session (KEEN1-OK). Desktop Dreams replay
  gate: PASS 494 frames.
- APK now carries 8 native libs (~2 SDL runtimes) — 76 files; debug size
  grew accordingly (SDL3 ~3.1MB/abi). Dropbox: single-APK story, separate
  ReflectionHLE APK removed from the kit.
- Emulator-driving note (again): the system folder picker eats blind
  keyevents (opened New-folder dialogs twice); force-stop
  com.google.android.documentsui is the reliable escape hatch.

## Notes

- refkeen is SDL3, the rest SDL2 — both support Android; the APK carries both.
- Precedent for the whole exercise: the user's TURBOSTEIN ECWolf Android launcher
  (packaging/Gradle terrain already familiar).
- Windows release flow is unaffected throughout; `build_megarocket.ps1` stays as-is.
