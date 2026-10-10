# Megarocket 2.0 — Menu Design

Status: design, 2026-10-06. Governs the SCREENS, CHEAT and FIX units in `BUILD_LEDGER.md`.

The rule for every addition: **it sits where the original would have put it, drawn the way the
original draws its own screens, and reads as though it shipped in 1991.** Each engine keeps its
own menu system, its own fonts, windows, cards or control-panel buttons, and its own navigation
feel. The additions are rows and screens *inside* those systems, never a modern overlay on top.
Every row is reachable and operable with a pad alone (ledger A16); every added value row cycles
with left/right and confirm, the way the engine's own toggles do.

The launcher screen (the shell) carries only what is global and game-independent: which games are
found, where to put files, the global defaults for display and input, and the how-to page. Once a
game is running, everything is inside that game's own menus.

## The three menu systems

| Engine | Original system | Where the originals put options |
|---|---|---|
| Vorticons (1–3) | Text windows (`ExpWin`) with a blinking caret cursor; main menu list on the title screen; in play, F-keys open single-purpose windows (F1 help, F2 sound Y/N, F3 keyboard, F4 joystick, F5 save, Esc quit) | Nowhere central — each F-key is its own prompt |
| Galaxy (4–6) | Card menus (`US_RunCards`): MAIN → NEW GAME / LOAD GAME / SAVE GAME / CONFIGURE / RETURN TO GAME / END GAME / PADDLE WAR / QUIT; CONFIGURE → SOUND / MUSIC / OPTIONS / KEYBOARD / USE JOYSTICK #1 / #2; OPTIONS → SCORE BOX / TWO-BUTTON FIRING / FIX JERKY MOTION / SVGA COMPATIBILITY | The OPTIONS card — already a list of toggles |
| Dreams | Control panel of icon buttons: Start or Resume / Help / Load-Save-Quit / Controls / Sound / Music, each opening a sub-panel of more buttons | A button per subject |

## Vorticons (Keen 1–3)

**Title-screen main menu** gains one row, *Options*, between *High Scores* and *Ordering Info*
(the one place a 1990 player would look). In play, the keyboard-config key (F3) and the pad's Start
open the same Options window as the pause menu — the one thing Megarocket got right here.

```
          OPTIONS                          (ExpWin, 26 wide, game font, caret cursor)
   Mode            Enhanced  <>           Classic / Enhanced / Custom (computed)
   Display...                             -> window below
   Controls...                            -> keyboard page / gamepad page / touch page
   Sound...                               -> speaker on/off, Galaxy sfx, Galaxy tunes, volumes
   Quicksave...                           -> confirm on/off, slot count, autosave on level exit
   Fixes...                               -> the bug-fix list
   Cheats...                              -> the cheat list
   Quit game                              -> K13-style confirm (Enter/Esc), then launcher
   Exit
```

*Display*: View (4:3 / Wide), Smooth motion, Native resolution (Integer / Fit), Fullscreen, Pixel
shape (4:3 / Square), Backdrop (tile picker: Starfield / Rock / ... / Black), Reduce flashes.
Each row is a value cycle; the window is the same `ExpWin` chrome as the save menu.

*Controls*: three pages (Keyboard / Gamepad / Touch), left/right flips pages. Every row opens
the small action list *Rebind / Add second / Clear / Back*; capture has a visible countdown and
cancels itself. The original *Keyboard Commands* screen (F3's ten-key walk) is reached from the
Keyboard page's first row and keeps behaving as it always did, but can be left with Esc/B at any
step.

The original single-letter prompts stay in the original letters but are *also* pick-lists:
F2's "Sound (Y/N)?" becomes a two-row list (Y/N still answer), Esc's "Quit to (D)os or (T)itle"
a two-row list (D/T still answer), F5's "1-9" a nine-row list showing which slots are used.

## Galaxy (Keen 4–6)

The card system already has the right shape, so the additions are **cards**. New cards need a
title graphic where the originals use an EGAGRAPH picture (`PIC_OPTIONSCARD`); those are drawn at
run time from the game's own menu font in the same style (the card header is text in a box in the
originals' own idiom) — nothing derived from the game's art is shipped.

```
MAIN:      NEW GAME / LOAD GAME / SAVE GAME / CONFIGURE / CHEATS / RETURN TO GAME / END GAME / PADDLE WAR / QUIT
CONFIGURE: SOUND / MUSIC / DISPLAY / OPTIONS / FIXES / KEYBOARD / GAMEPAD / TOUCH
OPTIONS:   MODE (Classic/Enhanced/Custom) / SCORE BOX / TWO-BUTTON FIRING / FIX JERKY MOTION /
           QUICKSAVE CONFIRM / AUTOSAVE ON LEVEL EXIT / CREATURE QUESTION (Keen 6) / REDUCE FLASHES
DISPLAY:   VIEW (4:3 / WIDE) / SMOOTH MOTION / SCALING (INTEGER / FIT) / FULLSCREEN /
           PIXEL SHAPE (4:3 / SQUARE) / BACKDROP TILE
GAMEPAD:   JUMP / POGO / FIRE / MENU / STATUS / QUICKSAVE / QUICKLOAD / DEAD ZONE / MOTION MODE
           (replaces USE JOYSTICK #1/#2 and JOYSTICK CONFIGURATION; the bind capture has a countdown)
TOUCH:     LAYOUT / OPACITY / SIZE / SHOW WHEN PAD PRESENT (default off)
FIXES:     one radio row per fix (see below)
CHEATS:    see below
```

*SVGA COMPATIBILITY* is dropped from OPTIONS (meaningless here) and noted as such; *FIX JERKY
MOTION* stays because it changes behaviour (it is an original option).

## Dreams

The control panel gets one more top-level button, *Options*, with its own two-colour icon drawn
in the panel's style (original pixel art, ours). Its sub-panel: *Display*, *Gamepad & Touch*,
*Fixes*, *Cheats*, *Quicksave*. Each opens a panel of the same button-and-caption kind the
original uses for Load/Save. Value rows are shown as the panel's existing radio-button idiom.

## The Mode row

Every Options screen starts with *Mode*: **Classic** (original rates, every fix off, 4:3 view,
no smooth motion, speaker/AdLib as original), **Enhanced** (the fixes on, wide, smooth, native
resolution, one-button fire) or **Custom**, which is never chosen — it is what the row *reads*
once any individual value differs from both presets, exactly as in the Wolf3D project. Choosing a
mode again sets every row below it. Controls, sound levels, backdrop and cheats are never part of
a mode.

## The cheat menu

Modelled on the Wolf3D project's rules: cheats act only on a game in progress (rows are off and
greyed on the title screen), every cheat is off again at every launch, each sets exactly its
documented effect, one-shot cheats say what they did. The originals' own cheat key combinations
keep working unchanged and are listed at the bottom of the card so people can find them.

| Cheat | Kind | 1–3 | 4–6 | Dreams | Notes |
|---|---|---|---|---|---|
| God mode | toggle | ✓ | ✓ | ✓ | Original: G+O+D (1–3), F10+G (4–6, Dreams). In 1–3 it is G+O+D's own effect (the halo and the pogo flight with it), kept from level to level where the original clears it. |
| Infinite ammo | toggle | ✓ | ✓ | ✓ (flowers) | A shot uses nothing. |
| Infinite lives | toggle | ✓ | ✓ | ✓ | Death still plays; the count never falls. |
| No clipping | toggle | ✓ | ✓ | ✓ | Original F10+N in 4–6/Dreams; new for 1–3 (same effect: solid tiles ignored). |
| Jump cheat | toggle | ✓ | ✓ | ✓ | Original F10+J: hold jump to keep rising. In 1–3, G+O+D's flight alone: hold jump while pogoing. |
| Slow motion | toggle | ✓ | ✓ | ✓ | Original F10+S in 4–6/Dreams; new for 1–3. |
| Free items | one-shot | ✓ | ✓ | ✓ | 1–3: C+T+Space (pogo, keycards, ammo); 4–6: B+A+T; Dreams: F10+I. |
| Extra lives | one-shot | ✓ | ✓ | ✓ | +9 each press (the originals count lives in a byte). |
| Skip this level | one-shot | ✓ | ✓ | ✓ | Original F10+E (end level) in 4–6/Dreams. Marks the level done as if played. |
| Level select | pick + go | ✓ | ✓ | ✓ | A list of this game's levels by name; original F10+W warp in 4–6/Dreams. |
| Unlock the map | one-shot | ✓ | ✓ | ✓ | Every level on the world map becomes enterable (doors/blockers cleared). |
| Reveal secrets | toggle | ✓ | ✓ | ✓ | Hidden passages and fake walls drawn visibly (presentation only; draw-list flag). |
| Freeze enemies | toggle | ✓ | ✓ | ✓ | Actors stop thinking; Keen still moves. New in all three. |
| Original cheat codes | info rows | | | | The key combinations above, listed so they are discoverable. |

Cheats never alter the simulation code paths used by the oracle comparisons: each is a flag read
at one named point (the same places the originals' debug keys read theirs), and the replay harness
asserts that with every cheat off the hash is unchanged. Whether a cheated session may enter the
high-score table is an open decision (J-15; default: as the originals, which do not block it).

## The bug-fix list

One row per fix, each **on by default** (J-03), each a line of text that says what the bug was.
The Classic mode turns every row off. The list is populated as the replay work exposes the bugs —
the reconstruction's own `// BUG:` annotations (dozens, Keen 1–3) and omnispeak's known-bug notes
(4–6) are the seed; Dreams' come from its source comments. Every fix has a replay case showing
the original behaviour and the fixed behaviour, and the toggle is what switches between them.

Format of a row: `Impossible pogo bounce     ON  <>` with the description on the line below when
the row is selected, in the engine's own font.

## What the launcher keeps

Global defaults only: display (same rows as a game's Display screen, used until a game overrides),
gamepad defaults, touch defaults, audio volumes, where files are, the how-to page, and the game
tiles. No cheats, no fixes, no per-game rows — those live where the player is already looking.
