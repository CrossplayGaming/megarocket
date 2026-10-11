# HARN-09: the path walker (HARN-09a, 2026-10-11)

`godot/tests/harn09_walk.gd` loads the real program (`shell/main.tscn`, the launcher) and drives it only with one
device's own events through `Input.parse_input_event`: the pad's buttons, the keys, or touches on the game's
on-screen controls (and the launcher's tiles). It never calls a game or its menus; it only reads state, to decide
where to go and to assert what happened. `python tools/regress.py HARN-09` runs the pad walk of Keen 1, Keen 4 and
Keen Dreams v1.93 (about 10 minutes) and fails while any function fails.

    python tools/gdtest.py harn09_walk --timeout 1800 -- --games=keen1,keen4,kdreams193 --device=pad --out=<folder> --trace=1

Options (after `--`): `--games` (any of keen1..keen6, kdreams, kdreams193), `--device=pad|keys|touch`, `--out`
(the folder for harn09_walk.json; user:// by default), `--trace=1` (every move printed with where it left the walk).

## What one game's walk does

1. Launcher: the device moves the focus to the game's tile and presses it (touch taps it).
2. The title and the main menu: accept until a menu waits.
3. (a) Every row the OptionsModel lists for the engine, each its own record: a value row moved and moved back (the
   value read from the model), a page opened (the probe's page) and left by its Back row or by Back, an action done
   (Reset to defaults, the cheats' one-shots, the codes). One binding is caught with the device in use (Status's
   Change: the pad's right stick, or Tab). The Cheats rows with no game (greyed, they say why) and again in a game.
4. (b) The originals' functions, a small table per engine (see `_vorticons`, `_galaxy`, `_dreams`).
5. (c) Quit by the game's own menus; if the device could not, the game is stopped from the launcher's side (that is
   said); the launcher must have the game's tile focused and move with the device.

A function that cannot be completed is recorded with where the walk got stuck, and the walk goes on from a known
place (Back pressed; for Keen 1-3 the game is started again if it cannot get back to the title). Every function has
a time limit. The player's own files are never touched: the launcher's settings file and every game's saves go to a
temporary folder of the walk's own (`GameHost.saves_dir`, set as the launcher adds the host).

## Read-only probes it needs

- Keen 1-3 (`vort_screens.gd`, `vort_demo.gd`): `shell_menu_page` and `shell_menu_row`, the page the Options window
  or the title menu shows ("title:main", "title:extras", or an OptionsModel page) and the row its cursor is on, set
  while the menu waits for a press, "" otherwise (a prompt over it, or no menu).
- Keen Dreams (`drm_us.gd`): the same two, "panel" with the item under the cursor (row * 100 + number) while the
  control panel waits, a shell list's page and row inside one, "" while an item's own screen runs.
- Keen 4-6 need none: the cards (`us_currentCard`, `selectedItem`), `command_confirmed` and the "menu" mark say it.

Nothing in the games reads the probes; headless runs and the oracle comparisons never reach the code that sets them.

## Extending it

- A game: its row in `GAMES` (tile, folder, engine). Keen 2 and 3 have no `map_route` yet (the d-pad held from a new
  game's place on the world map into the first level, in refreshes); without one the walk records that and enters a
  level through Level select instead.
- A device: its table (`PAD`, `KEYS`, `TOUCH`) maps the walk's moves to events. A move the table lacks is one the
  device cannot make, and the function needing it fails with that said.
- When SCR-04's pick-lists land, the Vorticons prompts are answered in `_answer` (today: the letter or digit, which
  only the keys have). When SCR-05's d-pad entry lands, `_type_text` already types with the d-pad as SCR-05 describes
  it (up from A to the letter, right to the next); adjust it to the built entry if that differs.

## The pad walk on 2026-10-11 (Keen 1 82 of 91, Keen 4 60 of 64, Dreams v1.93 61 of 65)

Expected (the parallel tracks' subjects):
- Keen 1-3 letter and digit prompts: Reset every control (Y/N)?, SaveMenu's 1-9, Leave this game (Y/N)? (pause New
  Game and Load Game), AskQuit's (D)os or (T)itle, the title's Quit (Y/N)?; F1 help and F2 Sound (Y/N)? have no pad
  route or menu row. With no way to leave a game for the title or to quit, the pad cannot load a saved game once a
  game is under way, and the walk stops Keen 1 from the launcher's side.
- No d-pad text entry: Keen 4's and Dreams' save names (saved as "Untitled").
- Keen 4: F1's help screens have no pad route.

Found by the walk, new:
- Keen 1-3's title menu sees a held pad button at one refresh in thirteen (`vort_demo.gd` `_modern_menu_loop`: the
  buttons come from the last of its six reads, then it waits 7 refreshes), so a press of 7 refreshes is missed about
  half the time (2 of 4 in the run). The keyboard's Enter goes through the key buffer and is never missed.
- Keen 4-6: the OptionsModel lists Effects volume and Music volume for the Galaxy engine, but no card shows them.
- Keen Dreams: the Options icon's Video and Game keycaps cannot be reached with the d-pad. The caps are 56 pixels
  wide and 48 apart (`drm_us.gd` `_shell_panel_setup`, `CtlPanelKC2R` at 0, 6, 12, 18, 24), so they overlap, and
  `USL_FindRect` only moves to an item that starts past the edge of the one the cursor is on: the arrows go Input,
  Audio, Cheat. Display and Gameplay (with Mode) are reachable by the keyboard's V and G only.
- Keen Dreams: the Controls list's Reset to defaults waits for the letter Y (`_shell_page_list`).
- Keen 4: Paddle War is left with Start, not B (it reads the pad's own codes there, and B is Pogo); recorded as done.

## The keyboard and touch walks (same day, not in the regress entry yet)

- Keys: Keen 1 91 of 91, Keen 4 62 of 64 (only the volumes), Dreams v1.93 79 of 79 (Video and Game by their keys V
  and G). So the walk itself completes every function a device can reach: the pad's failures are the program's.
- Touch: Keen 1 81 of 91, Keen 4 58 of 63, Dreams v1.93 59 of 64. Besides the pad's gaps, the on-screen controls
  have no Status button, so the status window cannot be opened by touch. (A touch screen binds no key or button, so
  the binding capture is not walked by touch.)
