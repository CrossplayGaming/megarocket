# Commander Keen Launcher (Megarocket) — Known Issues

Closes out the retrofit for this title (see `PROJECT_DELTA.md` and the portfolio
`F:\GameDev\BASELINE_BLUEPRINT.md`). Tier B: high-consequence items fixed, medium items
documented here rather than necessarily fixed.

---

## Fixed during the retrofit

| Item | Fix |
|---|---|
| **A failed game launch was silent** | On-screen dismissible error naming the actual cause |

The launch path called `CreateProcessA` and, on failure, printed to `stderr` — which goes
nowhere in a windowed SDL app with no console. The player pressed Play, nothing happened, and
there was no way to find out why: indistinguishable from a broken launcher. It now shows
"COULD NOT START THE GAME" with the real reason (program missing / folder missing / blocked by
Windows or antivirus / other, plus the exe name and error number).

Verified: compiles clean via cmake, strings confirmed present in the rebuilt binary, and
`launcher/keenlauncher.exe` (the copy `play-keen.bat` runs) refreshed from the build.

---

## Open — accepted, not fixed

### 1. The error screen has not been seen on screen
The code path is verified compiled and the strings are in the binary, but no failing launch has
actually been triggered to look at it. Rendering follows the existing `pull_notice` pattern
exactly, so the risk is low — but "it compiles" is not "it looks right".
**To close:** temporarily rename an engine exe and press Play.

### 2. Detection is all-or-nothing per slot
`detect()` sets `available = file_exists(exe) && file_exists(data)`, so a slot that is missing
its *engine* looks identical to one missing its *game data*. The launcher catalog explicitly
wants per-item status rather than a single boolean, because those two have completely different
fixes for the player. Partially mitigated at launch time by the new error screen, which does
distinguish them — but the tile itself still cannot say which is wrong.

### 3. No log file — launcher catalog item not met
Nothing is written to disk for diagnosis. A user reporting "slot 4 won't start" has nothing to
send. The catalog wants a discoverable log capturing enough to diagnose without reproducing.
**To close:** append failures (and the first-run pull results) to `keenlauncher.log` beside the
exe, and mention its location in the About page.

### 4. The two art/audio-pull launches still fail silently
The `CreateProcessA` calls in `art_pull()` and the Galaxy audio pull have no failure branch.
Left alone deliberately: both are **cosmetic paths with working fallbacks** (the launcher uses
its own baked tile art if a pull fails) and both are time-bounded, so a failure degrades rather
than breaks. Worth a log line once item 3 exists.

### 5. The POSIX branch is effectively dead code
`launch()`'s non-Windows path shells out via `system()` with no error handling and no quoting
review. Windows is the shipped target; this branch is untested and should either be exercised or
removed rather than left as an implicit promise of portability.

### 6. No coverage sweep run
Only a targeted pass against the launcher catalog was done (detection, external process
management, errors/diagnostics, input). The blueprint's full sweep — install/first-run from a
truly clean machine, settings persistence, window management, update/versioning — has not been
run.

---

## Explicitly NOT issues (decided; do not re-flag)

- **`lastslot` config falls back silently instead of refusing to start** — deliberate override of
  baseline decision 4; it is a cosmetic cursor position, bounds-checked on read. See
  `PROJECT_DELTA.md`.
- **Focus loss does nothing** — `not-applicable`; the launcher is idle UI with no simulation or
  audio, and it is blocked while a game runs.
- **The launcher blocks while a game runs** — by design, so it does not compete for the screen
  or the pad.
- **No fidelity harness** — correct. This is original software, not a recreation; there is no
  original to diff against.
- **Controller disconnect does not pause anything** — correct here. There is nothing to pause;
  the pad is closed cleanly and re-acquired on reconnect, and the UI stays keyboard-navigable.
