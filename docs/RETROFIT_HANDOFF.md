# Retrofit Handoff — Commander Keen Launcher (Megarocket)

**Read this if you're picking up this project and weren't part of the work.**
Written 2026-07-29. Work was done from a different conversation (a Hovertank session that
expanded into a portfolio-wide QA pass). The repo is clean; nothing is half-finished.

---

## What happened

A **quality retrofit** pass. Portfolio standard is `F:\GameDev\BASELINE_BLUEPRINT.md`; overall
progress is in `F:\GameDev\RETROFIT_ROADMAP.md`.

This is the **first non-port** in the sweep — original C/SDL2 software rather than a recreation of
a DOS game. That changes the rules:

- **There is no fidelity harness here, and there should not be one.** Nothing is being recreated,
  so there's no original to diff against. Verification leans on `verify/` (screenshot baselines).
- Generic best practice is **authoritative**, rather than subordinate to matching an original.

## The verdict: this project was in good shape

Things that were checked and found already correct:

- **Controller hot-plug** — `SDL_CONTROLLERDEVICEADDED` / `REMOVED` are handled; a disconnect
  closes the pad cleanly and degrades to keyboard, a reconnect re-acquires.
- **Gamepad navigation** — genuine `SDL_GameController` support, stick axes and buttons; the whole
  UI is pad-drivable.
- **Config robustness** — `lastslot` is bounds-checked on read (`fscanf(...) == 1 && v >= 0 &&
  v < NSLOTS`) and falls back safely.
- **Launch discipline** — games run with their own folder as working directory; the launcher
  blocks while a game runs so it isn't competing for the screen or the pad; the first-run art
  pulls are time-bounded so a wedged engine can't hang things.

## The one real bug, now fixed

**A failed launch was completely silent.** `CreateProcessA`'s failure branch printed to `stderr` —
which goes nowhere in a windowed SDL app with no console. Press Play, nothing happens, no way to
find out why: indistinguishable from a broken launcher.

Now shows a blocking, dismissible error screen naming the actual cause — game program missing,
game folder missing, blocked by Windows/antivirus, or a generic refusal — plus the exe name and
error number. Follows the existing `pull_notice` rendering pattern. A quit received while the
error is showing is re-posted rather than swallowed.

## Build note

```
cmake --build launcher/build --config Release
cp launcher/build/Release/keenlauncher.exe launcher/keenlauncher.exe
```

`launcher/keenlauncher.exe` is what `play-keen.bat` runs and is **not tracked in git** (source
only). It has already been refreshed with this fix.

## Current state

- Repo clean, **1 commit unpushed** on `master`.
- Compiles clean via cmake (VS 2022 BuildTools); the new strings are confirmed present in the
  rebuilt binary.
- ⚠️ The **error screen itself has not been eyeballed** on a real failure. To see it: temporarily
  rename an engine exe and press Play.

## Still open (in `docs/KNOWN_ISSUES.md`)

- **No log file at all** — a user reporting "slot 4 won't start" has nothing to send.
- **Detection is all-or-nothing per slot** — `available = file_exists(exe) && file_exists(data)`,
  so a missing *engine* looks identical to missing *game data*, which have different fixes.
- The two art/audio-pull launches still fail silently — **left alone deliberately**: cosmetic
  paths with working fallbacks and hard timeouts, so they degrade rather than break.
- The POSIX branch of `launch()` is untested dead code.

## Baseline decisions that land differently here (don't re-flag them)

- **Focus-loss pause/mute** — `not-applicable`; idle UI, no audio, and it's blocked while a game runs.
- **Controller-disconnect pause** — met by hot-plug handling; there's no simulation to pause.
- **"Invalid config → refuse to start"** — deliberately overridden. `lastslot` is a cosmetic
  cursor position, not real state; refusing to start over it would be absurd.

## Where to look

`docs/PROJECT_DELTA.md`, `docs/KNOWN_ISSUES.md`, and `git log`.

**Snapshot to fall back to:** git tag `pre-retrofit`.
