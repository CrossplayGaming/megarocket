# HARN-09: the path walker (2026-10-11)

`godot/tests/harn09_walk.gd` loads the real program (`shell/main.tscn`, the launcher) and drives it only with one
device's own events through `Input.parse_input_event`: the pad's buttons, the keys, or touches on the game's
on-screen controls (and the launcher's tiles). It never calls a game or its menus; it only reads state, to decide
where to go and to assert what happened.

    python tools/regress.py HARN-09    # every game, by pad, keyboard and touch (three walks at once; slow)
    python tools/regress.py SCR-08     # the mash walk, every game by pad (one walk per engine at once; slow)
    python tools/gdtest.py harn09_walk --timeout 1800 -- --games=keen1,keen4,kdreams193 --device=pad --out=<folder> --trace=1

Options (after `--`): `--games` (any of keen1..keen6, kdreams, kdreams193), `--device=pad|keys|touch`, `--out`
(the folder for the evidence; user:// by default), `--trace=1` (every move printed with where it left the walk),
`--mash=1` and `--seed=<n>` (SCR-08's walk, below). The regress entries write their evidence under the work folder
(`F:/KeenReworkWork/harn09_<device>/harn09_walk.json`, `harn09_mash_<engine>/harn09_mash.json`): the notes name the
games' own levels, so they stay out of the repository.

## What one game's walk does

1. Launcher: the device moves the focus to the game's tile and presses it (touch taps it).
2. The title and the main menu: accept until a menu waits.
3. (a) Every row the OptionsModel lists for the engine, each its own record: a value row moved and moved back (the
   value read from the model; on Keen 4-6's cards a toggle chosen twice, a volume round its eleven steps), a page
   opened and left by its Back row or by Back, an action done (Reset to defaults, the cheats' one-shots, the codes).
   The Cheats rows with no game (greyed, they say why) and again in a game.
4. The bindings (SCR-06), by the device in use (not touch: it has no key or button): Status's Change catches the
   spare (the right stick's button, Tab); Fire's (Dreams: Throw's) Change left alone shows its countdown 5, 4, 3, 2,
   1 (the engines' `controls_capture_left`) and changes nothing; Fire cleared; Fire's Change catches a second spare
   (the left stick's button, Backslash) and its Add second the first, which is taken from Status (Status keeps Y or
   Enter). Keen 1-3 and Dreams on their Controls pages, Keen 4-6 on the CONTROLS card.
5. (b) The originals' functions, a small table per engine (`_vorticons`, `_galaxy`, `_dreams`): help (Keen 1-3's
   and Keen 4-5's Extras row; F1 too with the keyboard), the sound (F2 with the keyboard; Effects volume to 0% and
   back otherwise), a new game, status, save with a typed name (Keen 4-6, Dreams; the d-pad spells it on a pad and a
   touch screen), load, Keen 1-3's map walked into the first level (the way found on the map the game shows, a
   breadth-first search over its tiles, then steered tile by tile reading Keen's place), the pause menu and its
   questions (Keen 1-3's lists answered by their rows; the letters with the keyboard), Keen 6's creature question
   (turned on first, then typed), Paddle War, quit.
6. (c) Quit by the game's own menus; the launcher must have the game's tile focused and move with the device.

A function that cannot be completed is recorded with where the walk got stuck, and the walk goes on from a known
place. Every function has a time limit. The player's own files are never touched: the launcher's settings file and
every game's saves go to a temporary folder of the walk's own (`GameHost.saves_dir`, set as the launcher adds the
host).

## The mash walk (SCR-08, `--mash=1`)

Buttons pressed and let go at random gaps of 15 to 50 ms (`--seed`, 8 by default: the same presses each run), as a
player mashes them, per game from the launcher:

- B from the game's start through its intro, title, attract loop and menus: no game starts, the menu comes as ever.
- A into a new game (Keen 1-3 from the title's menu; Keen 4-6 and Dreams from the new game's last choice): the map
  loads once and its window comes (Keen 1-3's Keens Left, Keen 4-6's level box, Dreams' Loading box).
- Start over the map, and in a level: the menu, the cards or the panel opened and shut; nothing loads, the play
  goes on. (On Keen 4-6's MAIN, Escape asks REALLY QUIT?, as the original's USL_UpLevel: answered no, then RESUME.)
- A into a level (Keen 1-3 steered onto the first level's entrance; Keen 4-6 and Dreams by Level select): loaded
  once, its window shown.
- A death (Level select into a level where holding a direction kills Keen, `DEATHS`), then A through the death and
  the game's way back (Keen 1-3's map and Keens Left; Keen 4-6's and Dreams' Try Again): loaded once.
- Skip this level chosen and the menus left, then A through the level's end: the map loaded once.
- Quit by the menus; back on the launcher.

The counts are the engines' `shell_level_loads` (Keen 1-3: each map visit and each level; Keen 4-6: CK_LoadLevel;
Dreams: SetupGameLevel) and `shell_level_boxes` (Keen 1-3: ShowLives; Keen 4-6: CK_BeginCacheBox, which the cards'
own Control Panel box also draws, and which comes only while pictures are still to load, so a restart's and an
end's are not counted; Dreams: CA_CacheMarks' Loading box, which the panel's own "Options Screen" box also draws,
not v1.00's when it goes back down a cache level after the panel). The walk counts the windows from where the menus
are left, so the menus' own boxes are not among them. Nothing in the games reads the counts.

## Read-only probes it needs

- Keen 1-3 (`vort_screens.gd`, `vort_demo.gd`): `shell_menu_page` and `shell_menu_row`, the page the Options window
  or the title menu shows ("title:main", "title:extras", or an OptionsModel page) and the row its cursor is on, set
  while the menu waits for a press, "" otherwise. `shell_asking` and `shell_asking_row`: SCR-04's list waiting and
  the row its caret is on.
- Keen Dreams (`drm_us.gd`): the same two, "panel" with the item under the cursor (row * 100 + number) while the
  control panel waits, a shell list's page and row inside one, "" while an item's own screen runs.
- Keen 4-6 need none for the menus: the cards (`us_currentCard`, `selectedItem`), `command_confirmed`, the "menu"
  mark and whether a dialog reads the controls say it (the host's `controls_live()` is false in a dialog since
  SCR-03's `shell_menu_keys`, so the walk reads `controls_read_vbl` itself).
- All three: `controls_capture_left` (SCR-06), `shell_level_loads` and `shell_level_boxes` (SCR-08).

Headless runs and the oracle comparisons never reach the code that sets the menu probes; the counters count in
every run and change nothing.

## Extending it

- A game: its row in `GAMES` (tile, folder, engine) and in `DEATHS` (a level and a direction that kill Keen soon).
- A device: its table (`PAD`, `KEYS`, `TOUCH`) maps the walk's moves to events. A move the table lacks is one the
  device cannot make, and the function needing it fails with that said.

## Touch routes

Every function has one. Status is the on-screen OK (it presses Enter, Status's own key by default; if the keyboard's
Status is bound elsewhere, a touch screen has no Status). While a line is typed (Keen 4-6, Dreams) the host sends
the on-screen d-pad as the pad's d-pad codes, so a touch screen spells as the pad does (`GameHost._touch_key`).
Keen 1-3's lists and name entry take the on-screen arrows as the keyboard's. The bindings are not walked by touch:
a touch screen has no key or button to catch.

## What the walks found and what was changed (2026-10-11)

- Keen 4-6's cards had no Effects or Music volume: they are on the SOUND and MUSIC cards now (`gal_menu.gd`),
  chosen to step 10%, from 100% round to 0% (`OptionsModel.cycle`).
- Keen Dreams: the Options icon's Video and Game keycaps could not be reached with the d-pad (the caps are 56
  pixels wide and 48 apart, and USL_FindRect moves only to an item starting past the end of the one the cursor is
  on). The first four caps' rectangles are the 48 pixels up to the next cap; the caps are drawn as before.
- Keen 4-6's dialogs: an Enter repeat sent in the same pump as the held A's release was read as yes (SCR-05G's A
  held on QUIT quit the game in 5 of 8 runs); dropped now (`gal_menu.gd` USL_CtlDialog).
- Keen Dreams v1.00 and v1.93 share one saves folder (one tile, one game id): the walk takes a slot's old name
  back before typing its own.
- Touch: no way to type a name in Keen 4-6 or Dreams (their line input keeps the arrows' own meaning); the host
  now sends the on-screen d-pad as the pad's d-pad codes while a line is typed.
