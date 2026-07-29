# Commander Keen Launcher (Megarocket) — Project Delta

Generated 2026-07-29 · References **`F:\GameDev\BASELINE_BLUEPRINT.md`** (the portfolio
baseline). Records only what *differs* from the baseline, plus this project's tier.

## Classification (delta from baseline)

**This is the first project in the retrofit that is a launcher rather than a game port**, so
the baseline's *launcher/setup half* is the governing catalog and the *fidelity half* barely
applies. There is no translation differential here: the launcher is original software, not a
recreation of anything.

- **Type:** original **multi-game launcher** (native C + SDL2, "Megarocket") wrapping seven
  Keen slots. It does not recreate a game — it detects, configures and starts other engines
  (omnispeak, refkeen) plus per-game patch sets.
- **Platforms:** desktop (Windows) primary. A POSIX branch exists in `launch()` but is
  effectively untested — Windows is the shipped target.
- **Distribution:** free, self-hosted; the "Megarocket" build assembles a distributable tree by
  **constructive copy** (only known-safe files are placed) so no game data or derived asset can
  leak in.
- **Fidelity posture:** **original work.** Generic best practice is authoritative here; there is
  no original to defer to. (The *games* it launches are emulated/ported by third-party engines
  whose fidelity is not this project's responsibility.)
- **Input:** keyboard **and gamepad**. Gamepad is first-class — see below.
- **Multiplayer:** `not-applicable`.

## Tier: **B — public, quieter**

Released and downloadable, but not the promoted centrepiece. High-consequence items fixed;
medium items documented in `KNOWN_ISSUES.md`.

## Deltas from the baseline

### Baseline decisions that land differently here

| # | Baseline decision | How it applies |
|---|---|---|
| 1 | Controller unplugged → pause + prompt | **Met, differently.** There is no simulation to pause. `SDL_CONTROLLERDEVICEREMOVED` closes the pad cleanly and `…ADDED` re-acquires it, so a disconnect degrades to keyboard rather than hanging. Correct behaviour for a launcher. |
| 2 | Focus loss → pause + mute | **`not-applicable`.** No running simulation and no audio; the launcher is idle UI. While a game is running the launcher is blocked on `WaitForSingleObject`, so it is not competing for the screen or the pad. |
| 4 | Invalid config → refuse to start + explain | **Deliberately overridden.** The only persisted value is `lastslot`, a cosmetic cursor position. It is bounds-checked (`fscanf(...) == 1 && v >= 0 && v < NSLOTS`) and falls back to the default. Refusing to start a launcher over a bad cursor position would be absurd; the baseline's rule is aimed at configs that carry real state. |
| 5 | Gamepad-only navigation everywhere | **Met in the launcher** — `SDL_GameController` with stick axes and button events, so the whole UI is pad-drivable. *Whether each launched game is pad-playable is the third-party engines' business, not this launcher's.* |
| 9 | Unusable display mode recoverable | **Met by construction.** The launcher derives its logical canvas from the window size and clamps to min/max; it never sets a display mode. |
| 6 | Converter fails loudly | Applies to `tools/` (the extractors and patchers), not the launcher binary. |

### Systems unique to this project
- **Seven game slots across two different third-party engines** (omnispeak for Vorticons-era,
  refkeen for Galaxy-era/Dreams), each with its own working directory, arguments and config
  conventions. Nothing else in the portfolio orchestrates foreign engines.
- **First-run art/audio pull** — runs each engine once in a hidden window to dump title art,
  with an on-screen notice so the launcher does not appear frozen.
- **Patch sets** (`keen13/*.pat`, `keen6patch/`) applied to the games themselves.
- **`verify/`** — a screenshot-baseline harness (`run_verify.ps1`) plus a menu-text audit. This
  is the closest thing in the portfolio to a UI regression test.

### Deliberate design decisions worth not re-litigating
- **The launcher blocks while a game runs** (`WaitForSingleObject(..., INFINITE)`), by design:
  it stops the launcher competing for the screen and the pad, and returning from a game lands
  back on the launcher.
- **The art/audio pulls are time-bounded** (30s / 60s then `TerminateProcess`) so a wedged
  engine can never hang the launcher permanently.

## Coverage

There is **no fidelity harness for this project and there should not be** — nothing here is a
recreation, so there is no original to diff against. Verification leans on `verify/` (screenshot
baselines) instead. A full blueprint coverage sweep against the *launcher* catalog has not been
run; see `KNOWN_ISSUES.md`.
