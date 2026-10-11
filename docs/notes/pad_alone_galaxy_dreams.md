# Keen 4-6 and Keen Dreams by the controller alone (SCR-03, SCR-05, SHELL-04; 2026-10-11)

What the controller sends to a game, and where, for whoever builds the pad-only walk (HARN-09). All of it
happens only with a player at the controls (the engine's `options` set); headless runs and the oracle
comparisons see the originals' routines unchanged.

## The host's three ways of sending a button (godot/shell/game_host.gd `_pad`)

- **Play**: while the game reads its play controls (`controls_live()`: the controls read in the last six
  refreshes), each button is its own scan code (ControlsModel.PAD_CODES) and the player's bindings say what
  it does. Start is always Escape.
- **Menus**: otherwise the d-pad and left stick are the arrows, A Enter, B Escape, X Space, Y Enter. A
  screen of the menus that reads the controls while it waits sets the engine's `shell_menu_keys`, and the
  pad stays the menus' keys there whatever its buttons are bound to:
  - Keen 4-6: USL_CtlDialog (every yes/no and "press any key" window of the cards; Enter answers yes as Y
    does, but not an Enter still held from choosing the item: its typematic repeats are no answer),
    IN_YesNo (the quicksave's question; Enter is yes), HelpScreens, Paddle War.
  - Dreams: the quicksave's question.
- **Typing**: while a line is typed (the engine's `shell_text_entry`, US_LineInput in both engines) the
  d-pad and stick are sent as the pad's own codes 0x6D-0x70, which no key sends, and the buttons as the
  menus' keys. PadTextEntry (godot/shell/pad_text_entry.gd) turns them into letters: Up and Down step the
  letter under the cursor through A-Z, 0-9, space and `.-!?` (a new letter at the line's end; Up starts at
  A, Down at Z), Right moves past it, Left erases it (at the end, the last letter). A is Enter (accepts),
  B is Escape (the original's Escape). The keyboard types as it always did; its own arrows keep their
  original meaning.

Lines typed this way: Keen 4-6's save names (SAVE card), high-score names (CK_SubmitHighScore), Keen 6's
creature answer; Dreams' save names (Load / Save's Save buttons) and high-score names.

## Screens and how the pad finishes them

- Keen 4-6 cards: d-pad moves, A chooses, B backs out. EXTRAS has HELP in Keen 4 and 5 (the original's
  F1 help screens; Keen 6 has none). Every question (REALLY QUIT?, REALLY END CURRENT GAME?, YOU'RE IN A
  GAME, RESET EVERY CONTROL?) takes A as yes and B as no.
- Keen 6's creature question: not asked by default (J-04); with CREATURE QUESTION on (Classic) it is drawn
  and typed as the original, and any answer passes. A game begun from the in-game menu does not ask (the
  game loop asked when it began), as in the original.
- Keen 4-6 in play: the status window (Status's buttons, Y and Back), the try-again box (the d-pad, Jump or
  Pogo's buttons, Start for the map), the pause and message windows (any button).
- Dreams' panel: the d-pad moves the cursor from button to button as the original's arrows do
  (USL_FindRect), A presses, B leaves. The help text scrolls with the d-pad and B leaves it. Megarocket's
  lists in the panel's box read the play controls (CTRL-05): the d-pad moves, Jump's buttons choose,
  Throw's go back; Reset to defaults' question takes the same (Jump's button pressed anew resets, Throw's
  backs out; Y on the keyboard).

## The two-button reset (SHELL-04)

Back and Start held together for three seconds on one pad give that pad's buttons their defaults
(controls.reset("pad"), saved), the game reading them at once, and "Controller buttons back to their
defaults" shows at the bottom of the screen for three seconds. The second of the two to go down is not sent
to the game; the first does its own thing (Start opens the menu as ever; Back is Status in play). It works
in play and in every menu.

## Checks

SCR-05G (tests/scr05_galaxy_pad.gd, Keen 4; also passes with --game=keen5; tests/scr05_keen6_creature.gd),
SCR-05D (tests/scr05_dreams_pad.gd), SHELL-04 (tests/shell04_reset_chord.gd). All drive the host with
Input.parse_input_event, as a controller's events arrive.
