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

## Keen 1-3's cases (SCR-01V, 2026-10-11)

The cases in `tools/cases/keen1..3/scr_*.json` (`python tools/screen_case.py list keen1`, and so on):

| case | screens |
|---|---|
| `scr_story` | Story: the text window scrolled (Down, PgDn twice, PgUp, Up), Escape |
| `scr_about` | About ID..., High Scores, Ordering Info from the menu (each left with Space) |
| `scr_previews` | Previews! (Keen 1: PREVIEW2/3 then the text; Keen 2-3: the text), Restart Demo |
| `scr_fkeys` | on the menu: F1 help, F2 Sound (Y/N)?, F3 Keyboard Commands (8, Ctrl), F4 joystick, F5 not on the map, Escape Quit (Y/N)? N |
| `scr_continue` | Continue Which Game?: a slot never saved, a file of the wrong size (`saves/scr_badsave`) |
| `scr_quit` | Escape, Y: the exit screen in text mode (ENDSCRN), compared by its cells |
| `scr_map` | from a new game's save on the map: status (Space), F5 1 Y (Overwrite), C+T+Space (the cheat), G+O+D on and off, Escape T (GAME OVER, the scores) |
| `scr_hiscore` | a crafted save with 15000 points: F1 over the map, Escape T, the high-score window, a name typed (Backspace too), the table |
| `scr_gameover` | a save with no Keens left beside a pit: the last death, GAME OVER over the level (Keen 2: the Earth explodes first), the table |
| `scr_attract` | no keys: title, id screen, high scores, the timed ordering screen (Keen 1's Yorp and Garg, Keen 2's Scrub, Keen 3's Foob), the title again |
| `scr_ending` (Keen 1) | all four ship parts, level 5 walked through: DoFinale to the end text |

Saves for these (game state only, so committed) are in `tools/cases/keenN/saves/scr_*`, made from the
level-entrance saves by changing fields (score, lives, parts, cities; the 92-byte layout is
`VortMain.GameState`).

**The recordings are DOSBox Staging 0.83's; the port's timing is fitted to 0.80.** Two things differ and
each case says so in its `port` options:

- `costs: loadgraphics=...`: the start-up's length. 0.83 takes a few refreshes more or less before the clock
  starts (Keen 1 +4, Keen 2 -8, Keen 3 -5 refreshes: the middle of the range over which the main menu's
  first picture comes out right in each game's `scr_menu` recording).
- `dos_ticks: 23` (Keen 1 only; 22 for the 0.80 recordings): the BIOS tick the program reads the DOS clock at,
  which seeds the random numbers. With 22 the ordering screen's Yorp walks another way (`scr_attract`: 6 of
  42 steps alike; with 23 all 42). Keen 3's Foob matches with its usual 4 (262 of 263); Keen 2 draws no
  random numbers outside the levels.

**What still falls apart, and the masks for it.** From the first key on, the two machines' refreshes and
loop passes stand up to three refreshes apart (Keen 2's main menu comes up three refreshes earlier in the
original than in the port). Animated tiles stop at the clock's phase whenever a screen stops refreshing
(the main menu and every window over the title, the fades, the map under a window, the story's scene), so
one time in three or so the two machines stop them at different phases. Every case masks only the tiles
that animate (listed below, taken from the game's tile data and the attract loop's recording), only while
they stand still, and each mask starts and ends in the black between two screens (0.61-0.67 s after an
Enter that leaves the menu, 0.38-0.55 s after a key that leaves a screen) or while the tiles animate, where a
masked and an unmasked picture cannot be told apart by timing. A mask edge in the middle of a still screen
fails the case (one side's picture starts a refresh before the edge, the other's after).

- the title: Keen 1 x 197-284 y 131-144, 256-267/177-190, 48-80/192-200, 193-238/192-200; Keen 2 179-189/
  128-140, 97-127/145-171, 3-13 and 35-45/151-153, 192-304/192-200; Keen 3 192-288/161-200, 16-32/162-175,
  115-124/163-168, 55-62/176-178, 49-61/184-191. Under the main menu, less what the menu's window covers
  (x 80-239, y 48-143): Keen 1 240-284/131-144 instead of the first, Keen 2 without the first. Where the F1
  help, Keyboard Commands and joystick windows lie over the rest, a few of their pixels are masked too (the
  help is compared whole over the map);
- the high scores' and the id screen's animated borders, in their fades;
- Keen 3's story scene (its stars, x 160-192 y 160-200); Keen 2-3's previews text: the title's tiles below it;
- `scr_gameover`: Keen 2's twinkling star by the Earth (x 160-176 y 80-96), Keen 3's two map tiles by
  level 13's entrance while the map fades out;
- `scr_about` (Keen 2-3): the ordering screen's walker (Scrub, Foob) where the screen is left; it is compared
  in `scr_attract`;
- `scr_about` and `scr_previews` (Keen 2-3): the menu's cursor column (x 96-104, y 56-120) while the menu is
  moved through and an Enter chooses (each arrow is read up to three refreshes apart, so the cursor reaches a
  row in another of its three pictures); the cursor is compared in their other cases, and Keen 1's About and
  Previews have their keys moved off those edges instead (`steady_keys` on these two took over half an hour a
  case on the shared machine);
- `scr_attract`: each screen's animated tiles in its fades (no key resynchronises the attract loop, and the
  original's frames under 0.83 fall a few refreshes from the port's).

`keen1/scr_gameover` was recorded twice: the two runs agree on every picture and refresh (`pair`).

**Keys.** On an edge that decides which pass of a loop reads a key (the main menu reads the arrows on six
refreshes of thirteen, Enter on one), the menu's spinning cursor ends up in another phase.
`python tools/steady_keys.py <game> <case> --write` runs the port with each key moved up to four refreshes
either way and moves the key until what follows it does not change (mask edges between it and the next key
move with it); record the case again after it. In a level the frames come every three refreshes, so a key
pressed during play meets them at another phase whenever the level began a refresh or two apart: the
level cases press Right while the map fades out, so Keen walks from the level's first frame on both
machines, and need no key during play.

**Not covered yet (Keen 1-3).** Keen 2's finale (all eight cities saved and a level finished) and Keen 3's
(Mortimer's machine: its six sparks and the heart shot) need keys pressed during level play, and those do
not land on the same frame on both machines: with the level entered on the same refresh (Ctrl steadied),
Keen 1 level 5 with Right, Ctrl and Left pressed in play still parted at the first press (the original's
level frames under 0.83 fall a refresh from the port's 0.80-fitted ones, so a press meets another frame).
The cases here play only with keys held from the level's first frame. Also not compared: the levels'
message windows (Keen 1's Yorp statues, Keen 2's Vorticon Elders: inside levels), Keen 2's "Oops." (the
Tantalus switch), and the start-up lines DOS prints before the game's graphics (the port has no DOS
console). Mortimer's introduction is in REPLAY-V3's level 16 recording.

**A port fix: the exit screen.** Keen 1-3 leave a text screen as they quit to DOS (KEENMAIN.C's `Quit`:
ENDSCRN's 4000 bytes past its 7-byte header copied to B800:0000, the cursor at column 1, row 23). The port
dropped it; `Quit("")` now keeps it (`VortLib.exit_textScreen`, `exit_cursor`) and `simv01_boot` writes it to
`text_frames.json` when the case may exit. `scr_quit` compares it cell for cell (DOS's prompt, written on
the row below once the program has quit, is masked: row 23, columns 0-4). The shell does not show it
(as Keen 4-6's).

## Keen 4-6 (SCR-01G, 2026-10-11)

- **Keys against the cursors.** The control panel's cursor blinks every 35 tics (0.5 s) from each key, so menu
  keys go 1.75 s apart (between two blinks; 1.5 or 2.0 s lands on one and either side may draw the other
  phase). A typed line's cursor blinks every 36 tics from the line's start and typing does not reset it:
  letters go 72 tics (1.027 s) apart, the first 0.8 s after the line opens. An ending's page waits with its
  arrow; a key while the page is still being drawn does not count (IN_ClearKeysDown after the drawing), so each
  key goes 0.5 s after its page is drawn (the port's times: `keen4/scr_end`).
- **Cutting the intro short.** Keen 4 and 5: Space at 3 s, Space on the title at 5 s opens the panel. Keen 6
  (the user's v1.0) opens the panel at once on the first key where v1.4 shows the title (J-19), so Keen 6
  cases wait for the title (Escape at 33 s).
- **The DOS clock** the port starts with is `GALAXY_CLOCK_US` (screen_case.py), fitted on Paddle War's serves.
- **Saved games** for the endings and game over: `python tools/galaxy_case_save.py keen4 keen5` (the port's own
  save, its score raised; never committed). Keen 6 v1.0 takes no save of the port's (its header's code offset
  differs from v1.4's), and its ending pages differ from v1.4's (below), so Keen 6 has no ending case.
- **Masks used** (each says why in the case): the world map's one animated tile in view (Keen 4's water, Keen 5's
  rocket flame) from the level's start, because the frame it is held in under a window follows the port's
  timing of the panel's exit and the level load (not fitted: TIME-G), from 10.2 s in the cases that load a
  game, before the Loading box on both sides (the box itself is the same picture: the port holds it 4
  refreshes, the original 2 whole and a part at each end); Keen 4's level 1 play around the Game Over! window
  (the creatures' random numbers, REPLAY-G). Keen 5's scr_over keeps `settled: 5`: Keen's death and the
  galaxy explosion's frames follow the death animation US_RndT picks, and the port's level 1 runs a frame
  ahead of the original's (TIME-G's level openings); its note says more.
- **Not comparable with the user's Keen 6 v1.0** (v1.4's rules, J-19): CONFIGURE and OPTIONS (other items),
  the creature question (v1.0 never asks it: the code is there, nothing calls it), the ending's pages (grey,
  dark text), the debug keys (A+2 does nothing), so no game over by F10+Z.

## Keen Dreams' cases (SCR-01D, 2026-10-11)

Nine cases a release, the same timetables for v1.00 and v1.93 except where noted: `scr_menu` (start screens,
title, panel), `scr_attract` (no key: the title, v1.00's credits and copyright windows, the high scores),
`scr_help` (F1, 2, 3: the three help texts paged, the help line's Press F1 for Help), `scr_options` (C, F3:
keycaps redefined and refused; F2 and F7: sound and music), `scr_quit` (F6: the save slots out of a game; Q,
Enter: Exit to DOS), `scr_game` (new game, status window, the debug keys' windows G I J S W, a level, the
in-game panel), `scr_save` (save with a typed name, load it: PAUSED), `scr_gameover` (Boobus kills Keen four
times: You didn't make it past, Try Again, Exit to Tuberia, Game Over!, the scores), `scr_ending` (v1.00: the
fight, the five finale windows, a high score typed; v1.93: from a saved game, see below).

- **Keys in play go in the middle of a frame.** A key within a few milliseconds of the moment a frame reads
  input can land a frame apart in DOSBox (a v1.00 bomb thrown at 22.000 s did). Moving each key of a fight
  by +-5 to 10 ms in the port and checking the run is unchanged finds the safe times (the scratch tool for it
  moved one key at a time and compared every picture).
- **The Enter that answers a death stays in LastScan** (the original's habit): the next death's box takes it
  at once (Try Again). `scr_gameover` presses N in between.
- **v1.93's ending starts from a saved game**, because v1.93's first frames in level 15 come a tic apart from
  the original's (TIME-D's v1.93 loads), which moves King Boobus's walk and the bombs' hits by a frame. The
  save is the port's own: run this timetable as a case in the port with
  `--keep F:/KeenReworkWork/case_saves/scrd_kdreams193_ending` and copy SAVEGM0.KDR alone into
  `F:/KeenReworkWork/case_saves/scrd_kdreams193_ending_save` (the case's overrides):

      {"seconds": 46.6, "keyfeed": true, "held": [[4.0, "space", 0.2], [6.0, "enter", 0.2], [10.0, "f10", 0.8],
       [10.3, "w", 0.15], [11.4, "1", 0.15], [11.8, "5", 0.15], [12.6, "enter", 0.15], [14.0, "f10", 0.8],
       [14.3, "i", 0.15], [15.6, "n", 0.15], [17.0, "f10", 0.8], [17.3, "g", 0.15], [18.6, "n", 0.15],
       [19.993, "alt", 0.143], [20.507, "alt", 0.143], [21.027, "alt", 0.143], [21.541, "alt", 0.143],
       [22.054, "alt", 0.143], [22.568, "alt", 0.143], [23.082, "alt", 0.143], [23.595, "alt", 0.143],
       [24.109, "alt", 0.143], [24.622, "alt", 0.143], [25.136, "alt", 0.143], [25.65, "alt", 0.143],
       [26.163, "alt", 0.143], [26.677, "alt", 0.143], [30.6, "esc", 0.15], [32.5, "f6", 0.15],
       [34.0, "right", 0.15], [35.5, "enter", 0.15], [37.0, "b", 0.1], [38.0, "enter", 0.15], [40.0, "esc", 0.15]]}

- Found on the way (details: docs/notes/DREAMS_MEMORY.md): the original finds DOSBox's mouse driver and gets
  435 KB (434 with a long KEYFEED.COM); DOSBox keeps the host's date, so v1.00's fifth finale window shows;
  SaveGame's compression takes the original 4 refreshes (its Saving box); v1.93's random seed comes a BIOS
  tick later than feed_pre puts it (dreams_case.py START_LAG); v1.00's warp to a missing map ends otherwise
  than the port's.
