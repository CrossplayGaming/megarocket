# Screen cases (HARN-06): how to write one

A screen case drives the original (DOSBox) and the port to the same screens with the same keys, then holds
what each side showed against the other, by content. The tool is `tools/screen_case.py`; its docstring has
the full case format and the rules. SCR-01V/G/D in `tools/regress.py` check every
`tools/cases/<game>/scr_*.json` automatically.

## The five steps

1. **Copy a working case.** `tools/cases/keen1/scr_menu.json` (Keen 1-3), `keen4/scr_menu.json` (Keen 4-6),
   `kdreams193/scr_menu.json` (Dreams). Name yours `scr_<what>.json`.
2. **Design the timetable in the port.** `python tools/screen_case.py port keen1 scr_help`
   lists the pictures that stay up and writes a sheet of what is on show every second to
   `F:/KeenReworkWork/port_runs/screen_keen1_scr_help/sheet.png` (`--step 0.5`, `--hold 0.2` for more).
   Change `held` until the sheet shows every screen you want, then name them in `screens` with the time
   each starts (usually the key's time). The port is exact: a timetable that works there works in DOSBox.
3. **Record the original.** `python tools/screen_case.py record keen1 scr_help` (about a minute, plus up to
   30 s waiting for the last DOSBox run; at most three at once). It goes to
   `F:/KeenReworkWork/oracle_runs/keen1_scr_help_a`.
4. **Check.** `python tools/screen_case.py check keen1 scr_help` runs the port and prints PASS or FAIL per
   named screen. `--all` lists every difference, `--no-run` re-compares the port's last run.
5. **Only if you change a key, record again** (the recording is the keys' result). For a reproducibility
   check, `record ... --run b` then `pair`.

## Timing rules of thumb

- Times are seconds **after the EGA mode set** on both sides (KEYFEED.COM starts counting there). All keys
  must be up again within 64 s (KEYFEED counts 1024 ticks a second in 16 bits); `seconds` can be longer.
- The title: Keen 1-3 at about 14 s (Enter at 16 opens the menu); Keen 4-6 fully shown at about 31 s
  (Escape at 33 opens the main card); Dreams at once (Space at 4 opens the control panel).
- Keys 1.5-2 s apart, 0.15-0.2 s down. A key pressed while the original is still loading can be lost.
- End on a still screen held 3 s or more: both sides are cut at `seconds`, and the last picture is never
  compared.
- Key names: `tools/keyfeed.py` SCANCODES (letters, digits, f1-f12, esc, enter, space, arrows, ctrl, alt,
  lshift, backspace, tab, pgup/pgdn, home/end, ins/del, comma, period, slash, minus, equals).

## Saves and config files (`overrides`)

`overrides` names a folder; its files go beside the original's program and into the port's save folder
before the run.

- **Keen 1-3**: saves hold the game state only, so they may be committed: `tools/cases/keen1/saves/<name>/`.
  `godot/tests/make_vort_saves.gd` writes a new game standing on each level's entrance.
- **Keen 4-6 and Dreams**: a saved game holds the level's map planes (taken from GAMEMAPS), so **never
  commit one**. Make it with the port: write a case that saves (F3 / the SAVE card, a name typed), run
  `python tools/screen_case.py port keen4 scr_save5 --keep F:/KeenReworkWork/case_saves/keen4/save5`, and
  put that absolute folder in the other case's `overrides`. CONFIG files (settings and high scores) are not
  taken from the game's files and may be committed.

## Shortcuts to a screen

- Keen 4-6: `"args": "/TEDLEVEL 5"` starts straight in level 5 (normal difficulty, no menus).
- Keen 4 and 5: the debug keys come on with A+2+Enter in a level (Keen 6 v1.0 ignores them; use a save).
- Dreams: hold F10, press W, type the level number, Enter (see `tools/cases/kdreams/level01.json`).
- Keen 1-3: start from a save on the world map (Continue Game, 1).

## Masks

A mask blanks a rectangle on both sides before comparing. Use one only where the two sides legitimately
differ, and say why in `reason` (the tool refuses a mask without one). `from`/`to` limit it in time (each
side's own clock); put `from` between a key and the picture it brings (the screen changes 0.1-0.2 s after
the key), never in the middle of an animation. Examples (`keen1/scr_menu.json`):

- the whole screen for 0.8 s at the end of the intro: under DOSBox Staging 0.83 the original's stars twinkle
  a step apart; the DOSBox 0.80 recordings show the port's pictures (TIME-V1 holds the intro exactly);
- the title's animated tiles around the menu window: their phase follows how long the original's loading
  took, so they meet the spinning cursor in other combinations.

Text screens take `text_masks`: `{"cells": [row0, col0, row1, col1], "reason": "..."}`.

## Reading a failure

    main menu (from 16.0 s): FAIL (2 differences: S1, S2; ...)
      first: S1: the port's picture 228 at 16.01 s, up 14 refreshes, is one the original never showed
      nearest: the original's picture 229 at 16.31 s, 444 pixels differ in (50,131)-(284,200); picture ...

- **S1** the port showed something the original never did; **S2** the reverse (a screen skipped);
  **S4** a still screen stayed up much longer or shorter; **S5** two screens came in the other order;
  **S3** too few pictures (a stuck or empty run).
- Open the picture named: the port's (or original's) picture, the nearest of the other side, and the
  differing pixels in magenta.
- Small differences inside an animated area, or a box starting at a screen's change: timing, not content.
  Look whether an older recording of the original (`oracle_runs/<game>_boot_a`, `_title_a`) shows the
  port's picture; if so, mask it with that as the reason.
- A box around text, a sprite, a menu row: a real difference. Report it; do not mask it.

## Text screens

Text-mode screens are compared by their 80x25 cells, not pixels (the shell draws them in Megarocket's own
font): cells the port says hold the same (character, colours) must look alike in the recording, different
pairs must look different, and each cell's colours must be its attribute's. A failure names the cells by
row/column. The hardware cursor is reported, not failed. The runners write text screens: `drm_boot` always
(Dreams' start screens), `simg_boot` the quit screen when the case has `may_exit`; `simv01_boot` none. The
recording's text pictures before the program's own (DOS's prompt) are left out, and so are those after it
quits.

## Found by the first cases (2026-10-11)

- All eight `scr_menu` cases: runs a and b of the original agree on every picture and refresh.
- Port against original: Keen 1-6 and Dreams v1.93 pass (Keen 1-3 with the two masks above). Dreams v1.00's
  start screen differs in seven cells: the original (under DOSBox) shows the mouse as detected and 435 KB of
  memory; the port shows no mouse and 440 KB (`drm_ca.gd` mm_layout is still provisional).
- Keen 4-6 show a text start screen ("Ready - Press a Key") that the port never shows; it is not compared.
- `keen4/scr_quit` (Escape twice, Y): the order screen left in text mode matches cell for cell. The
  REALLY QUIT? box was two pixels narrow (omnispeak's width rule; fixed to id's in gal_menu.gd); one
  difference is left while the box is up: the card's right edge (x 234-236, rows 49-150) is dotted in the
  port, solid in the original (the wrist-watch picture redrawn at x 74 by USL_DialogSetup).
- In the port, Up on Keen 4's NEW GAME does not wrap to QUIT (seen while designing `scr_quit`; the
  original's wrap is not recorded yet: SCR-02).
