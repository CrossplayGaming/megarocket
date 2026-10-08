# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-G-01i: the control panel (omnispeak's id_us_2.c with ck_us_2.c). Each
## episode is started as CK_Main starts it, up to CK_InitGame; then
## US_RunCards runs with keys scripted on the machine, and the expectations
## follow the C's code paths:
## - the main card is drawn over the wristwatch (the screen changes; the
##   wristwatch picture is cached); Escape on the main card is USL_UpLevel at
##   stack index 0, the "REALLY QUIT?" dialog, and Escape there backs out with
##   no command; R selects RETURN TO DEMO and Enter confirms it;
## - Down/Up move the main card's selection one item at a time (onto disabled
##   items too, and not above the first); Enter on NEW GAME opens the new game
##   card on BEGIN NORMAL GAME (its initialiser's selectedItem 1), and Enter
##   there gives US_Comm_NewNormalGame and the normal difficulty;
## - CONFIGURE, SOUND: the card opens on the current mode's item; P and Enter
##   check PC SPEAKER, and the menu's end sets the sound mode to PC;
## - PADDLE WAR plays until Escape and returns to the main card;
## - LOAD GAME with no saved games shows every slot disabled; OPTIONS, SCORE
##   BOX toggles the score box through its dialog; KEYBOARD, BUTTONS, JUMP
##   takes the next key pressed;
## - QUIT asks: N leaves no command, Y gives US_Comm_Quit, quit_to_dos and
##   Quit(NULL) (an empty quit message);
## - no quit message elsewhere (so no "not ported yet" stub reached).
##
## Options: --game_data=<folder>  --games=keen4,keen5,keen6

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
const STEP: float = 0.3

var g: GalMenu = null
var vm: DosMachine = null
## [seconds, card name, selectedItem, us_currentCommand, us_cardStackIndex] at each display
var trace: Array = []
var menu_screen: PackedByteArray = PackedByteArray()


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	for game: String in str(opts.get("games", "keen4")).split(",", false):
		_game(t, root, game)
	t.finish(self)


func card_name(c: GalMenu.US_Card) -> String:
	if c == null:
		return "none"
	for n: String in ["ck_us_mainMenu", "ck_us_newGameMenu", "ck_us_configureMenu", "ck_us_soundMenu",
			"ck_us_musicMenu", "ck_us_paddleWarMenu", "ck_us_loadGameMenu", "ck_us_saveGameMenu",
			"ck_us_optionsMenu", "ck_us_scoreBoxMenu", "ck_us_keyboardMenu", "ck_us_buttonsMenu"]:
		if g.get(n) == c:
			return n.trim_prefix("ck_us_")
	return "other"


func _sample() -> void:
	if g.us_currentCard == null:
		return
	trace.append([vm.seconds(), card_name(g.us_currentCard), g.us_currentCard.selectedItem, g.us_currentCommand, g.us_cardStackIndex])
	if menu_screen.is_empty() and card_name(g.us_currentCard) == "mainMenu":
		menu_screen = g.vl_screen.pixels.duplicate()


## The distinct [card, selectedItem] states the trace passes through, in order.
func states() -> Array:
	var out: Array = []
	for s: Array in trace:
		var k: String = "%s:%d" % [s[1], s[2]]
		if out.is_empty() or out[-1] != k:
			out.append(k)
	return out


## Run the menu with `keys` (scan codes) pressed STEP apart, the first `lead` seconds from now;
## a key given as [scancode, extra seconds] waits that much longer first.
func run_cards(keys: Array, lead: float = 0.5) -> float:
	trace = []
	var at: float = vm.seconds() + lead
	for k: Variant in keys:
		if k is Array:
			at += float(k[1])
			vm.add_key(at, int(k[0]))
		else:
			vm.add_key(at, int(k))
		at += STEP
	var t0: int = Time.get_ticks_msec()
	g.US_RunCards()
	return (Time.get_ticks_msec() - t0) / 1000.0


func _game(t: T, root: String, game: String) -> void:
	var d: GalData = GalData.new()
	if not t.ok("%s: files load (%s)" % [game, d.error], d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		return
	vm = DosMachine.new()
	g = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.time_limit = DosMachine.seconds_to_units(600.0)
	vm.on_limit = func() -> void:
		g.Quit("emulated time limit reached")

	# ---- CK_MainBody, up to CK_InitGame
	g.us_argv = PackedStringArray()
	g.CK_ACT_SetupFunctions()
	g.CK_KeenSetupFunctions()
	g.CK_OBJ_SetupFunctions()
	g.CK_Map_SetupFunctions()
	g.CK_Misc_SetupFunctions()
	for fn: StringName in [&"CK4_SetupFunctions", &"CK5_SetupFunctions", &"CK6_SetupFunctions"]:
		if g._defined_after_decl(fn):
			g.call(fn)
	g.CK_VAR_Startup()
	var ep: GalCK.CK_EpisodeDef = {"keen4": g.ck4_episode, "keen5": g.ck5_episode, "keen6": g.ck6_episode}[game]
	g.CK_SetCurrentEpisode(ep)
	g.ck_episodeFile = ep.episodeFile
	g.CK_VAR_LoadVars(g.ck_episodeFile)
	g.CK_InitGame()
	if not t.ok("%s: CK_InitGame runs (quit message '%s')" % [game, g.quit_message], not g.quitting):
		return
	vm.on_display = _sample
	var wristwatch: int = g.CK_CHUNKNUM("PIC_WRISTWATCH")
	var before: PackedByteArray = g.vl_screen.pixels.duplicate()

	# ---- 1: Escape asks REALLY QUIT?, Escape backs out; R, Enter: RETURN TO DEMO
	var wall: float = run_cards([GalIO.IN_SC_Escape, GalIO.IN_SC_Escape, GalIO.IN_SC_R, GalIO.IN_SC_Enter])
	var st: Array = states()
	print("  %s run 1 (%.1f s wall): %s" % [game, wall, st])
	t.ok("%s: the main card is drawn over the wristwatch (screen changed: %s; PIC_WRISTWATCH %d cached: %s)" %
		[game, not menu_screen.is_empty() and menu_screen != before, wristwatch, g.ca_graphChunks[wristwatch] != null],
		not menu_screen.is_empty() and menu_screen != before and g.ca_graphChunks[wristwatch] != null)
	t.ok("%s: Escape, Escape (the quit dialog backed out of), R, Enter: command %d (US_Comm_ReturnToGame), quit_to_dos %d, states %s" %
		[game, g.us_currentCommand, g.quit_to_dos, st],
		g.us_currentCommand == GalUS.US_Comm_ReturnToGame and g.command_confirmed and g.quit_to_dos == 0 and not g.quitting
		and st == ["mainMenu:0", "mainMenu:4"])
	var footer_main: String = g.footer_str[0]
	t.ok("%s: the main card's footer reads '%s'" % [game, footer_main], footer_main == "ESC to quit")

	# ---- 2: Down, Down, Up, Up, Up, Enter (NEW GAME), Enter (BEGIN NORMAL GAME)
	wall = run_cards([GalIO.IN_SC_DownArrow, GalIO.IN_SC_DownArrow, GalIO.IN_SC_UpArrow, GalIO.IN_SC_UpArrow,
		GalIO.IN_SC_UpArrow, GalIO.IN_SC_Enter, GalIO.IN_SC_Enter])
	st = states()
	print("  %s run 2 (%.1f s wall): %s" % [game, wall, st])
	t.ok("%s: Down/Up move the main card's selection 0-1-2-1-0 (onto disabled SAVE GAME too, not above NEW GAME): %s" % [game, st],
		st.slice(0, 5) == ["mainMenu:0", "mainMenu:1", "mainMenu:2", "mainMenu:1", "mainMenu:0"])
	t.ok("%s: SAVE GAME and END GAME are disabled with no game in progress (states %d, %d)" %
		[game, g.ck_us_mainMenuItems[2].state, g.ck_us_mainMenuItems[5].state],
		(g.ck_us_mainMenuItems[2].state & GalMenu.US_IS_Disabled) != 0 and (g.ck_us_mainMenuItems[5].state & GalMenu.US_IS_Disabled) != 0)
	t.ok("%s: Enter on NEW GAME opens the new game card on BEGIN NORMAL GAME; Enter: command %d (US_Comm_NewNormalGame), difficulty %d" %
		[game, g.us_currentCommand, g.ck_startingDifficulty],
		st.size() == 6 and st[5] == "newGameMenu:1" and g.us_currentCommand == GalUS.US_Comm_NewNormalGame
		and g.ck_startingDifficulty == GalCK.D_Normal and not g.quitting)
	g.ck_startingDifficulty = GalCK.D_NotPlaying    # (CK_GameLoop takes it in the game)

	# ---- 3: C (CONFIGURE), Enter, Enter (SOUND), P, Enter (PC SPEAKER), Escape, Escape, R, Enter
	var mode_before: int = g.SD_GetSoundMode()
	wall = run_cards([GalIO.IN_SC_C, GalIO.IN_SC_Enter, GalIO.IN_SC_Enter, GalIO.IN_SC_P, GalIO.IN_SC_Enter,
		GalIO.IN_SC_Escape, GalIO.IN_SC_Escape, GalIO.IN_SC_R, GalIO.IN_SC_Enter])
	st = states()
	print("  %s run 3 (%.1f s wall): %s" % [game, wall, st])
	t.ok("%s: CONFIGURE then SOUND opens the sound card on the current mode (%d): %s" % [game, mode_before, st],
		st.slice(0, 4) == ["mainMenu:0", "mainMenu:3", "configureMenu:0", "soundMenu:%d" % mode_before])
	t.ok("%s: P and Enter check PC SPEAKER (state %d) and the menu's end sets the sound mode %d -> %d (sdm_PC)" %
		[game, g.ck_us_soundMenuItems[1].state, mode_before, g.SD_GetSoundMode()],
		mode_before == GalIO.sdm_AdLib and g.SD_GetSoundMode() == GalIO.sdm_PC
		and (g.ck_us_soundMenuItems[1].state & GalMenu.US_IS_Checked) != 0
		and (g.ck_us_soundMenuItems[2].state & GalMenu.US_IS_Checked) == 0)
	t.ok("%s: Escape backs out sound -> configure -> main; R, Enter returns (command %d): %s" % [game, g.us_currentCommand, st],
		st.slice(4) == ["soundMenu:1", "configureMenu:0", "mainMenu:3", "mainMenu:4"]
		and g.us_currentCommand == GalUS.US_Comm_ReturnToGame and not g.quitting)

	# ---- 4: P (PADDLE WAR), Enter, two seconds of play, Escape, R, Enter
	wall = run_cards([GalIO.IN_SC_P, GalIO.IN_SC_Enter, [GalIO.IN_SC_Escape, 2.0], GalIO.IN_SC_R, GalIO.IN_SC_Enter])
	st = states()
	print("  %s run 4 (%.1f s wall): %s" % [game, wall, st])
	t.ok("%s: PADDLE WAR plays until Escape and returns to the main card (command %d, quit message '%s'): %s" %
		[game, g.us_currentCommand, g.quit_message, st],
		st == ["mainMenu:0", "mainMenu:6", "paddleWarMenu:0", "mainMenu:6", "mainMenu:4"]
		and g.us_currentCommand == GalUS.US_Comm_ReturnToGame and not g.quitting)

	# ---- 5: LOAD GAME (every slot empty, so disabled: Enter only sounds), back; CONFIGURE, OPTIONS,
	# SCORE BOX (its dialog, any key); KEYBOARD, BUTTONS, JUMP bound to X; back out; R, Enter
	var scorebox_before: bool = g.ck_scoreBoxEnabled
	wall = run_cards([GalIO.IN_SC_L, GalIO.IN_SC_Enter, GalIO.IN_SC_Enter, GalIO.IN_SC_Escape,
		GalIO.IN_SC_C, GalIO.IN_SC_Enter, GalIO.IN_SC_O, GalIO.IN_SC_Enter, GalIO.IN_SC_Enter, GalIO.IN_SC_Space,
		GalIO.IN_SC_Escape, GalIO.IN_SC_K, GalIO.IN_SC_Enter, GalIO.IN_SC_DownArrow, GalIO.IN_SC_Enter,
		GalIO.IN_SC_Enter, GalIO.IN_SC_X, GalIO.IN_SC_Escape, GalIO.IN_SC_Escape, GalIO.IN_SC_Escape,
		GalIO.IN_SC_R, GalIO.IN_SC_Enter])
	st = states()
	print("  %s run 5 (%.1f s wall): %s" % [game, wall, st])
	var slots_disabled: bool = true
	for i: int in range(6):
		if (g.ck_us_loadSaveMenuItems[i].state & GalMenu.US_IS_Disabled) == 0:
			slots_disabled = false
	t.ok("%s: the load card's empty slots are disabled; options, score box dialog, keyboard, buttons: %s" % [game, st],
		slots_disabled and st == ["mainMenu:0", "mainMenu:1", "loadGameMenu:0", "mainMenu:1", "mainMenu:3",
			"configureMenu:0", "configureMenu:2", "optionsMenu:0", "scoreBoxMenu:0", "optionsMenu:0", "configureMenu:2",
			"configureMenu:3", "keyboardMenu:0", "keyboardMenu:1", "buttonsMenu:0", "keyboardMenu:1", "configureMenu:3",
			"mainMenu:3", "mainMenu:4"])
	t.ok("%s: SCORE BOX toggles the score box (%s -> %s, caption '%s')" %
		[game, scorebox_before, g.ck_scoreBoxEnabled, g.ck_us_optionsMenuItems[0].caption],
		g.ck_scoreBoxEnabled == not scorebox_before
		and g.ck_us_optionsMenuItems[0].caption == ("SCORE BOX (ON)" if g.ck_scoreBoxEnabled else "SCORE BOX (OFF)"))
	t.ok("%s: JUMP is bound to X (0x%x) and the command is US_Comm_ReturnToGame (%d), quit message '%s'" %
		[game, int(g.in_kbdControls.jump), g.us_currentCommand, g.quit_message],
		int(g.in_kbdControls.jump) == GalIO.IN_SC_X and g.us_currentCommand == GalUS.US_Comm_ReturnToGame and not g.quitting)

	# ---- 6: Q, Enter, N (no command); Enter, Y (quit)
	var t_n: float = vm.seconds() + 0.5 + 2 * STEP
	wall = run_cards([GalIO.IN_SC_Q, GalIO.IN_SC_Enter, GalIO.IN_SC_N, GalIO.IN_SC_Enter, GalIO.IN_SC_Y])
	st = states()
	print("  %s run 6 (%.1f s wall): %s" % [game, wall, st])
	var none_after_n: bool = true
	var samples_after_n: int = 0
	for s: Array in trace:
		if s[0] > t_n + 0.05 and s[0] < t_n + STEP:
			samples_after_n += 1
			if s[3] != GalUS.US_Comm_None:
				none_after_n = false
	t.ok("%s: QUIT asks; N leaves no command (%d samples after it)" % [game, samples_after_n],
		none_after_n and samples_after_n > 0 and st == ["mainMenu:0", "mainMenu:7"])
	t.ok("%s: Y gives US_Comm_Quit (%d), quit_to_dos %d and Quit(NULL) (quitting %s, message '%s')" %
		[game, g.us_currentCommand, g.quit_to_dos, g.quitting, g.quit_message],
		g.us_currentCommand == GalUS.US_Comm_Quit and g.quit_to_dos == 1 and g.quitting and g.quit_message == "")

	vm.on_display = Callable()
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_limit = Callable()
