# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## HARN-09 (the path walker; SCR-03's check, SCR-06's bindings, SCR-08's mash walk): the real program
## (shell/main.tscn, the launcher), any of the seven games, driven only by one device's own events through
## Input.parse_input_event, as the device sends them (the pad's buttons; the keys; touches on the game's
## on-screen controls and the launcher's tiles), never by calling a game or its menus. Per game the walk moves to its tile and starts it, reaches the title and the main
## menu, then walks (a) every row the OptionsModel lists for that engine, each row's effect asserted (the
## page changed, the value stepped and stepped back, the action done), the Cheats with a game in progress;
## (b) the originals' functions from a small table per engine; (c) back out to the launcher, whose tile has
## the focus and still moves. State is only read, to decide and to assert: the menus' probes (Keen 1-3's
## and Dreams' shell_menu_page and shell_menu_row), Keen 4-6's cards, the OptionsModel's values, the
## engines' flags, the launcher's focus. A function that cannot be completed is recorded with where the
## walk got stuck; the walk gets back to a known place (Back, or the game stopped from the launcher's side
## and started again) and goes on; every function has a time limit. The player's own files are never
## touched: the settings and every game's saves go to a folder of the walk's own.
## Evidence: <out>/harn09_walk.json, [{game, function, device, reached, completed, note}], and a summary
## (lines starting WALK). Every function not completed is a failed check: RESULT: FAIL until each is.
## SCR-08's mash walk (--mash=1, its evidence harn09_mash.json): see _mash_walk.
##
## Options: --game_data=<folder> [--games=keen1,keen4,kdreams193] [--device=pad|keys|touch] [--out=<folder>]
## [--trace=1] [--mash=1 [--seed=<n>]]

var t: T = T.new()
var l: Launcher = null
## The device walked with ("pad", "keys" or "touch") and the game walked now (a GAMES key).
var device: String = "pad"
var game: String = ""
var games: PackedStringArray = PackedStringArray()
var out_dir: String = "user://"
## The walk's own folder: the settings and every game's saves (never the player's).
var own: String = ""
## GameFinder's results for the game_data folder (the launcher shows them as a scan would).
var finds: Array = []
## Every function walked: {game, function, device, reached, completed, note}.
var records: Array = []
## The function under way: when its time is up (Time.get_ticks_msec(); 0 none) and where it stopped.
var _deadline: int = 0
var _stuck: String = ""
## How a function got there when not the usual way, said in its record.
var _via: String = ""
## --trace=1: every move printed with where it left the walk.
var trace: bool = false

## The games the walk knows: the launcher's tile, the folder under game_data, the engine.
const GAMES: Dictionary = {
	"keen1": {"tile": "keen1", "folder": "keen1", "engine": "vorticons"},
	"keen2": {"tile": "keen2", "folder": "keen2", "engine": "vorticons"},
	"keen3": {"tile": "keen3", "folder": "keen3", "engine": "vorticons"},
	"keen4": {"tile": "keen4", "folder": "keen4", "engine": "galaxy"},
	"keen5": {"tile": "keen5", "folder": "keen5", "engine": "galaxy"},
	"keen6": {"tile": "keen6", "folder": "keen6", "engine": "galaxy"},
	"kdreams": {"tile": "kdreams", "folder": "kdreams", "engine": "dreams"},
	"kdreams193": {"tile": "kdreams", "folder": "kdreams193", "engine": "dreams"},
}

## Each device's event for the walk's moves: the pad's button, the key, the on-screen control touched
## ("dpad:<direction>" or a button's name). "yes" answers Keen 4-6's dialogs (their Y, or the Jump button);
## "spare" and "spare2" are what the bindings catch (bound to nothing by default). A move a device's table
## lacks is one it cannot make, and the walk records where it needed it; "char:<c>" (a letter or digit) and
## "fkey:<n>" are the keyboard's alone.
const PAD: Dictionary = {
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
	"accept": JOY_BUTTON_A, "back": JOY_BUTTON_B, "menu": JOY_BUTTON_START, "jump": JOY_BUTTON_A, "pogo": JOY_BUTTON_B,
	"fire": JOY_BUTTON_X, "status": JOY_BUTTON_Y, "yes": JOY_BUTTON_A, "spare": JOY_BUTTON_RIGHT_STICK,
	"spare2": JOY_BUTTON_LEFT_STICK,
}
const KEYS: Dictionary = {
	"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
	"accept": KEY_ENTER, "back": KEY_ESCAPE, "menu": KEY_ESCAPE, "jump": KEY_CTRL, "pogo": KEY_ALT,
	"fire": KEY_SPACE, "status": KEY_ENTER, "yes": KEY_Y, "spare": KEY_TAB, "spare2": KEY_BACKSLASH,
}
## (Touch: OK is Enter; J-50: Status its own button, whatever the keyboard's Status is bound to.)
const TOUCH: Dictionary = {
	"up": "dpad:up", "down": "dpad:down", "left": "dpad:left", "right": "dpad:right",
	"accept": "OK", "back": "Menu", "menu": "Menu", "jump": "Jump", "pogo": "Pogo", "fire": "Fire", "yes": "Jump",
	"status": "Status",
}
## What each move is called on each device, for the notes.
const SAY: Dictionary = {
	"pad": {"accept": "A", "back": "B", "menu": "Start", "jump": "A", "pogo": "B", "status": "Y", "yes": "A", "up": "d-pad up",
		"down": "d-pad down", "left": "d-pad left", "right": "d-pad right", "spare": "the right stick's button",
		"spare2": "the left stick's button"},
	"keys": {"accept": "Enter", "back": "Escape", "menu": "Escape", "jump": "Ctrl", "pogo": "Alt", "status": "Enter", "yes": "Y",
		"spare": "Tab", "spare2": "Backslash"},
	"touch": {"accept": "OK", "back": "Menu", "menu": "Menu", "yes": "Jump", "status": "Status"},
}

## Keen 1-3's and Dreams' Options pages walked row by row where a row opens them (the others are opened
## and left: each action's binding page, Level select).
const INTO: Array = ["display", "sound", "controls", "gameplay", "fixes", "keys", "pad", "touch", "codes"]
## The Options pages by the names the records give them (the OptionsModel's own, as Keen 1-3 show them).
const PAGE_NAMES: Dictionary = {"options": "Options", "display": "Options > Display...", "sound": "Options > Sound...",
	"controls": "Options > Controls...", "keys": "Options > Controls... > Keyboard...", "pad": "Options > Controls... > Controller...",
	"touch": "Options > Controls... > Touch...", "gameplay": "Options > Gameplay...", "fixes": "Options > Gameplay... > Fixes...", "cheats": "Cheats...",
	"codes": "Cheats... > Original codes...", "extras": "Extras..."}


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var opts: Dictionary = T.options()
	var root_dir: String = opts.get("game_data", "")
	device = opts.get("device", "pad")
	out_dir = opts.get("out", "user://")
	games = String(opts.get("games", "keen1,keen4,kdreams193")).split(",", false)
	trace = opts.get("trace", "") == "1"
	mash = opts.get("mash", "") == "1"
	rng.seed = int(opts.get("seed", "8"))
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	if not device in ["pad", "keys", "touch"]:
		t.blocked("--device is pad, keys or touch, not %s" % device)
		t.finish(self)
		return
	for g: String in games:
		if not GAMES.has(g):
			t.blocked("no game %s (the walk knows %s)" % [g, ", ".join(PackedStringArray(GAMES.keys()))])
			t.finish(self)
			return
	own = OS.get_temp_dir().path_join("mr_harn09_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(own)
	finds = GameFinder.new().scan_folder(root_dir)
	root.size = Vector2i(1280, 720)
	l = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = own.path_join("megarocket.lock")
	l.settings_path = own.path_join("settings.cfg")
	l.child_entered_tree.connect(_on_child)
	root.add_child(l)
	await _frames(3)
	for g: String in games:
		if mash:
			await _mash_walk(g)
		else:
			await _walk(g)
	_write()
	_summary()
	l.queue_free()
	await _frames(3)
	_remove(own)
	t.finish(self)


## A game's host as the launcher makes it: its saves into the walk's folder; on touch, the on-screen
## controls shown (the player's own choice where the screen is not a touch screen).
func _on_child(node: Node) -> void:
	var h: GameHost = node as GameHost
	if h == null:
		return
	h.saves_dir = ProjectSettings.globalize_path(own.path_join("saves"))
	h.force_touch = device == "touch"


# ------------------------------------------------------------------ the walk of one game

func _walk(id: String) -> void:
	game = id
	_show_tiles()
	print("WALK %s by %s" % [game, device])
	var r: Dictionary = await _fn("Launcher: to the tile, the game started", _launch, 40.0)
	if not r.completed:
		return
	r = await _fn("The title and the main menu", _boot, 120.0)
	if r.completed:
		match GAMES[game].engine:
			"vorticons":
				await _vorticons()
			"galaxy":
				await _galaxy()
			"dreams":
				await _dreams()
	await _fn("Back on the launcher, its tile focused and moving", _launcher_back, 40.0)


## The launcher shows what a scan of game_data finds, this game's own release on its tile.
func _show_tiles() -> void:
	var shown: Array = []
	for f: Dictionary in finds:
		if f.status != GameFinder.STATUS_OK:
			continue
		if f.id == GAMES[game].tile and not str(f.folder).replace("\\", "/").trim_suffix("/").ends_with("/" + str(GAMES[game].folder)):
			continue
		shown.append(f)
	l.show_results(shown)


## Starts the game from its tile: the device moves the focus there and presses it (a touch taps it).
func _launch() -> Dictionary:
	var tile: String = GAMES[game].tile
	if l.states.get(tile, "") != "found":
		return _res(false, false, "the launcher did not find %s in game_data" % GAMES[game].folder)
	if device == "touch":
		if not await _press("tile:" + tile):
			return _res(false, false, _stuck)
	else:
		for i: int in range(16):
			var at: String = _focus()
			if at == tile:
				break
			if not await _press(_launcher_step(at, tile)):
				return _res(false, false, _stuck)
		if _focus() != tile:
			return _res(false, false, "the focus never reached the tile (it is on %s)" % _focus())
		if not await _press("accept"):
			return _res(true, false, _stuck)
	var started: bool = await _wait(func() -> bool: return _host() != null and _host().thread != null, 20.0)
	return _res(true, started, "" if started else "the tile did not start the game")


## Which way the focus goes from one tile towards another in the launcher's grid (or carousel).
func _launcher_step(at: String, tile: String) -> String:
	var ids: Array = Launcher.GAMES.map(func(g: Array) -> String: return g[0])
	var a: int = ids.find(at)
	var b: int = ids.find(tile)
	if a < 0:
		return "down"
	var cols: int = maxi(l.grid.columns, 1)
	if a / cols != b / cols:
		return "down" if a / cols < b / cols else "up"
	return "right" if a % cols < b % cols else "left"


## (c): the game left by its own Quit (or, when the walk could not, stopped from the launcher's side), then
## the launcher: the game's tile focused, and the device moves the focus away and back.
func _launcher_back() -> Dictionary:
	var note: String = ""
	if _host() != null:
		note = "the walk could not quit the game itself; it was stopped from the launcher's side. "
		await _stop_game()
	if _host() != null:
		return _res(false, false, note + "the game would not stop")
	var tile: String = GAMES[game].tile
	if not await _wait(func() -> bool: return _focus() == tile, 5.0):
		return _res(true, false, note + "the launcher's focus is on %s, not the game's tile" % _focus())
	if device == "touch":
		return _res(true, true, note + "focused (a touch on a tile starts it: the move is not tried)")
	var ids: Array = Launcher.GAMES.map(func(g: Array) -> String: return g[0])
	var at: int = ids.find(tile)
	var cols: int = maxi(l.grid.columns, 1)
	var away: String = "left" if at % cols == cols - 1 or at == ids.size() - 1 else "right"
	await _press(away)
	var moved: bool = await _wait(func() -> bool: return _focus() != tile, 2.0)
	await _press("left" if away == "right" else "right")
	var back: bool = await _wait(func() -> bool: return _focus() == tile, 2.0)
	if not moved or not back:
		return _res(true, false, note + "the launcher did not move with %s and %s" % [_say(away), _say("right" if away == "left" else "left")])
	return _res(true, true, note + "focused, moved and back")


## The title and the main menu reached from the game's start (accept pressed until a menu waits).
func _boot() -> Dictionary:
	for i: int in range(20):
		if _menu_ready():
			await _refreshes(20)
			return _res(true, true, "")
		if _host() == null:
			return _res(true, false, "the game ended")
		if not await _press("accept"):
			return _res(true, false, _stuck)
		await _wait(_menu_ready, 4.0)
	return _res(true, false, "no main menu after the title (%s)" % _where())


## The title's main menu waits for a press (no game in progress).
func _menu_ready() -> bool:
	match GAMES[game].engine:
		"vorticons":
			return _page() == "title:main"
		"galaxy":
			return _g_open() and _g_card() == _g_main() and not _g_dialog()
		"dreams":
			return _page() == "panel" and not bool(_eng().get("ingame"))
	return false


## Where the walk is, for a note.
func _where() -> String:
	if _host() == null:
		return "the launcher"
	match GAMES[game].engine:
		"galaxy":
			if _g_open():
				return "the card %s" % _g_name(_g_card()) + (" with a dialog" if _g_dialog() else "")
			return "play" if _live() else "a screen of the game's"
	if _page() != "":
		return "the menu's page %s" % _page()
	return "play" if _live() else "a screen or prompt of the game's"


## A game stopped from the launcher's side (the walk's way back when the device could not quit it).
func _stop_game() -> void:
	if _host() != null:
		_host().stop()
	await _wait(func() -> bool: return _host() == null, 20.0)


## The game started again from its tile and walked to its main menu (after a stop).
func _restart() -> bool:
	await _stop_game()
	var r: Dictionary = await _launch()
	if not r.completed:
		return false
	r = await _boot()
	return r.completed


# ------------------------------------------------------------------ Keen 1-3

func _vorticons() -> void:
	# (a) the title's main menu: a single press of accept; Options (every page), Cheats with no game, High
	# Scores, Extras
	await _fn("Main menu: one press of %s chooses (four tries)" % _say("accept"), _v_short_press)
	var r: Dictionary = await _fn("Main menu > Options...", _list_open.bind("title:main", "options", "options"))
	if r.completed:
		await _list_walk("options", "Options")
		await _bind_walk("options")
		await _fn("Options: left with %s" % _say("back"), _list_back.bind("options", "title:main"))
	await _v_title()
	await _fn("Main menu > Cheats... (no game: greyed, says why)", _cheats_greyed.bind("title:main"), 30.0, _v_title)
	await _fn("Main menu > High Scores", _list_screen.bind("title:main", "high_scores"), 40.0, _v_title)
	r = await _fn("Main menu > Extras...", _list_open.bind("title:main", "extras", "title:extras"), 30.0, _v_title)
	if r.completed:
		for row: Dictionary in _list_rows("title:extras"):
			if row.key == "exit":
				continue
			if row.key == "demo":
				await _fn("Extras... > Restart Demo", _v_demo, 60.0)
			elif row.key == "help":
				await _fn("Extras... > Help (F1's pages)", _v_help_row.bind("title:extras"), 60.0)
			else:
				await _fn("Extras... > %s" % row.label, _list_screen.bind("title:extras", row.key), 60.0)
		await _v_title()
	# (b) the originals' functions (the hot keys on the title: the keyboard's alone; a pad's and a touch
	# screen's way to each is a row: Extras' Help, Sound's Effects volume), and the pause menu's rows and the
	# cheats with a game in progress
	if device == "keys":
		await _fn("Help (F1)", _v_help, 30.0, _v_title)
	await _fn("Sound off and on (F2; %s)" % ("Y and N" if device == "keys" else "Options > Sound... > Effects volume"),
		_v_sound, 60.0, _v_title)
	await _fn("New game: the world map", _v_new_game, 60.0)
	await _fn("Status on the map (%s)" % _say("status"), _v_status, 20.0)
	await _fn("Save to a slot (the pause menu's Save Game)", _v_save, 40.0)
	await _fn("Into a level from the map", _v_level, 60.0)
	await _v_pause_rows()
	await _fn("Quit to the title (the pause menu's Quit: Title)", _v_quit_to_title, 40.0)
	await _fn("Load the saved slot", _v_load, 40.0)
	await _fn("Quit out (the title's Quit: Yes; in a game, Dos)", _v_quit_out, 30.0)


## Back to the title's main menu after a function left the walk elsewhere (Back pressed; the game
## started again if it is past that).
func _v_title() -> void:
	if await _v_reach_title():
		return
	print("  (recovery: Keen 1-3 started again from the launcher)")
	await _restart()


func _v_reach_title() -> bool:
	for i: int in range(6):
		if _host() == null:
			return false
		if _page() == "title:main":
			return true
		if bool(_eng().get("shell_playing")):
			return false
		if _page() == "" and _live():
			return (await _boot()).completed    # the title's attract loop: accept opens the menu
		await _press("back")
		await _wait(func() -> bool: return _page() == "title:main", 2.0)
	return _page() == "title:main"


## The title menu takes a single press of accept as a player makes it (held some 7 refreshes): Extras...
## chosen four times, each by one press, Back between (it once read the pad at one refresh in thirteen and
## missed about half: SCR-03 made it read at every one).
func _v_short_press() -> Dictionary:
	var took: int = 0
	for i: int in range(4):
		if not await _v_reach_title() or not await _list_goto("title:main", "extras"):
			return _res(false, false, _stuck if _stuck != "" else "not at the title's menu (%s)" % _where())
		await _press("accept")
		if await _wait(func() -> bool: return _page() != "title:main", 1.0):
			took += 1
		await _to_page("title:extras", 2.0)
	await _v_reach_title()
	return _res(true, took == 4, "%d of 4 single presses of %s chose the row (vort_demo.gd _modern_menu_loop)" % [took, _say("accept")])


## Restart Demo: the menu left for the attract loop, the menu again with accept.
func _v_demo() -> Dictionary:
	if not await _list_goto("title:extras", "demo"):
		return _res(false, false, _stuck)
	await _choose("title:extras")
	if not await _wait(func() -> bool: return _page() == "", 3.0):
		return _res(true, false, "the menu stayed")
	var r: Dictionary = await _boot()
	return _res(true, r.completed, "the attract loop, then the menu again" if r.completed else r.note)


func _v_new_game() -> Dictionary:
	await _v_title()
	if _page() != "title:main":
		return _res(false, false, "not at the title's menu (%s)" % _where())
	if not await _list_goto("title:main", "new_game"):
		return _res(false, false, _stuck)
	await _choose("title:main")
	if not await _wait(func() -> bool: return bool(_eng().get("shell_on_map")) and _live() and _page() == "", 30.0):
		return _res(true, false, "no world map (%s)" % _where())
	await _refreshes(90)    # (the Keens left box waits a moment or a button)
	return _res(true, true, "")


## Status: the window over the play (the play stops reading its controls), gone with accept.
func _v_status() -> Dictionary:
	if not await _to_play():
		return _res(false, false, _stuck)
	if not await _press("status"):
		return _res(false, false, _stuck)
	if not await _wait(func() -> bool: return not _live(), 3.0):
		return _res(true, false, "no status window")
	await _refreshes(20)
	await _press("accept")
	if not await _wait(_live, 4.0):
		return _res(true, false, "the status window stayed after %s" % _say("accept"))
	return _res(true, true, "")


## Save Game from the pause menu on the map: slot 9 (SaveMenu's "1-9 or ESC"), the file written.
func _v_save() -> Dictionary:
	if not bool(_eng().get("shell_on_map")) or not await _to_play():
		return _res(false, false, "not on the world map (%s)" % _where())
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _list_goto("pause", "save_game"):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return _page() == "", 3.0):
		return _res(true, false, "no save window")
	await _refreshes(10)
	var file: String = str(_eng().get("save_dir")).path_join("SAVED9." + str(_eng().get("data").ext))
	if not await _answer("char:9", "SaveMenu's 'Which game position do you want to save? 1-9 or ESC:' (vort_screens.gd)", 8):
		await _press("back")
		await _leave_pause()
		return _res(true, false, _stuck)
	var saved: bool = await _wait(func() -> bool: return FileAccess.file_exists(file), 5.0)
	await _refreshes(10)
	await _press("accept")    # "You can continue this game ... Press a key:"
	await _to_page("pause")
	await _leave_pause()
	return _res(true, saved, "SAVED9 written" if saved else "no SAVED9 written")


## From a new game's place on the map into the first level, as a player steers: the way from Keen's tile to
## the first level's entrance found on the map the game shows (its tiles' walls and blocking places, as
## ClipMapKeen has them), the d-pad held along it a tile at a time (Keen's place read back), then Jump.
func _v_level() -> Dictionary:
	if not bool(_eng().get("shell_on_map")) or not await _to_play():
		return _res(false, false, "not on the world map (%s)" % _where())
	var path: Array = _v_map_path(1)
	if path.is_empty():
		return _res(false, false, "no way on the map from Keen to the first level's entrance")
	await _v_steer(path)
	await _v_onto(path)
	for i: int in range(3):
		await _press("jump")
		if await _wait(func() -> bool: return bool(_eng().get("shell_in_level")), 3.0):
			break
	if not bool(_eng().get("shell_in_level")):
		var ob: Object = (_eng().get("objlist") as Array)[0]
		return _res(true, false, "steered to the first level's entrance, but %s did not enter it (Keen at %d,%d)" % [_say("jump"),
			int(ob.get("x")) / VortMain.TILEGLOBAL, int(ob.get("y")) / VortMain.TILEGLOBAL])
	await _wait(_live, 20.0)
	await _refreshes(90)
	return _res(true, _live(), "%d tiles walked" % (path.size() - 1))


## Keen walked along a path of the map's tiles up to the last (an entrance: he stops at it), the d-pad held a
## tile at a time until he stands on the next (within a step of it on that axis; Keen's place read back).
func _v_steer(path: Array) -> void:
	var ob: Object = (_eng().get("objlist") as Array)[0]
	var tg: int = VortMain.TILEGLOBAL
	for i: int in range(1, path.size() - 1):
		var to: Vector2i = path[i]
		var dir: Vector2i = to - path[i - 1]
		for k: int in range(30):
			var at: int = int(ob.get("x")) if dir.x != 0 else int(ob.get("y"))
			var want: int = (to.x if dir.x != 0 else to.y) * tg
			if absi(at - want) < tg / 8 or (at - want) * (dir.x + dir.y) > 0:
				break
			await _press(_v_way(path[i - 1], to), 2 if absi(at - want) > tg / 2 else 1, 1)


## Keen stepped on from the path's last tile but one until he stands over the entrance (a tile under his
## box with something on the map's info plane, as ControlMapKeen looks for it). Whether he does.
func _v_onto(path: Array) -> bool:
	var e: Object = _eng()
	var ob: Object = (e.get("objlist") as Array)[0]
	var tg: int = VortMain.TILEGLOBAL
	for k: int in range(12):
		for x: int in range(int(ob.get("left")) / tg, int(ob.get("right")) / tg + 1):
			for y: int in range(int(ob.get("top")) / tg, int(ob.get("bottom")) / tg + 1):
				var info: int = int(e.call("GETTILE", x, y, 1))
				if info != 0 and info != 255:
					return true
		await _press(_v_way(path[path.size() - 2], path.back()), 1, 1)
	return false


## The d-pad's way from one tile to the next.
static func _v_way(from: Vector2i, to: Vector2i) -> String:
	var d: Vector2i = to - from
	return "right" if d.x > 0 else ("left" if d.x < 0 else ("down" if d.y > 0 else "up"))


## The tiles from Keen's to level `n`'s entrance on the world map (a breadth-first search over the tiles
## Keen can walk to: no wall on the side he comes in by, nothing blocking), [] if none.
func _v_map_path(n: int) -> Array:
	var e: Object = _eng()
	var ob: Object = (e.get("objlist") as Array)[0]
	var tg: int = VortMain.TILEGLOBAL
	var start: Vector2i = Vector2i((int(ob.get("x")) + tg / 2) / tg, (int(ob.get("y")) + tg / 2) / tg)
	var w: int = int(e.get("mapwwide"))
	var h: int = int(e.get("mapheight"))
	var walls: Dictionary = {Vector2i(0, 1): e.get("northwall"), Vector2i(0, -1): e.get("southwall"),
		Vector2i(1, 0): e.get("westwall"), Vector2i(-1, 0): e.get("eastwall")}
	var prev: Dictionary = {start: start}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in walls:
			var nt: Vector2i = c + d
			if nt.x < 0 or nt.y < 0 or nt.x >= w or nt.y >= h or prev.has(nt):
				continue
			var info: int = int(e.call("GETTILE", nt.x, nt.y, 1))
			if (info & 0x7FFF) == n:
				prev[nt] = c
				var path: Array = [nt]
				while path.front() != start:
					path.push_front(prev[path.front()])
				return path
			if int((walls[d] as PackedInt32Array)[int(e.call("GETTILE", nt.x, nt.y, 0))]) != 0 or (info & 0x8000) != 0:
				continue
			prev[nt] = c
			queue.append(nt)
	return []


## The pause menu's rows in a level: Resume; High Scores and Extras greyed (from the title); Options;
## Cheats with a game (every toggle, the one-shots, the codes, Level select into another level, Skip this
## level back to the map).
func _v_pause_rows() -> void:
	if not bool(_eng().get("shell_playing")):
		await _fn("Pause menu (%s in play)" % _say("menu"), func() -> Dictionary: return _res(false, false, "no game in progress (%s)" % _where()))
		return
	var r: Dictionary = await _fn("Pause menu (%s in play)" % _say("menu"), _open_pause_fn)
	if not r.completed:
		return
	await _fn("Pause menu > Resume", _pause_resume.bind("resume"))
	await _fn("Pause menu > High Scores (greyed: from the title)", _list_greyed.bind("pause", "high_scores"), 20.0, _open_pause)
	r = await _fn("Pause menu > Extras...", _list_open.bind("pause", "extras", "extras"), 20.0, _open_pause)
	if r.completed:
		await _fn("Pause menu > Extras... > Help (in a game)", _v_help_row.bind("extras"), 60.0)
		await _fn("Pause menu > Extras... > Story (greyed: from the title)", _list_greyed.bind("extras", "story"), 20.0)
		await _fn("Pause menu > Extras... > Back", _list_leave.bind("extras", "pause"), 20.0)
	await _fn("Pause menu > Options...", _list_visit.bind("pause", "options", "options"), 20.0, _open_pause)
	r = await _fn("Pause menu > Cheats...", _list_open.bind("pause", "cheats", "cheats"), 20.0, _open_pause)
	if r.completed:
		await _list_walk("cheats", "Cheats...")
		await _fn("Cheats... > Level select... > Level 2", _level_select.bind("cheats", "cheat:warp:2"), 60.0)
		await _fn("Cheats... > Skip this level", _skip_level.bind("cheats"), 60.0)
	await _leave_pause()
	await _fn("Pause menu > New Game (Leave this game? Yes)", _v_pause_new_game, 60.0)


## The pause menu's New Game: asked 'Leave this game (Y/N)?', then by the title a new game at once.
func _v_pause_new_game() -> Dictionary:
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _list_goto("pause", "new_game"):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return _page() == "", 3.0):
		return _res(true, false, "no question")
	await _refreshes(10)
	if not await _answer("char:Y", "the pause menu's 'Leave this game (Y/N)?' (vort_screens.gd OptionsMenu)", 0):
		await _press("back")
		await _to_page("pause")
		await _leave_pause()
		return _res(true, false, _stuck)
	await _wait(func() -> bool: return not bool(_eng().get("shell_on_map")) and not bool(_eng().get("shell_in_level")), 8.0)
	var ok: bool = await _wait(func() -> bool: return bool(_eng().get("shell_on_map")) and _in_play(), 30.0)
	await _refreshes(90)
	return _res(true, ok, "a new game on the world map" if ok else "no new game (%s)" % _where())


func _v_quit_to_title() -> Dictionary:
	if not bool(_eng().get("shell_playing")):
		return _res(false, false, "no game in progress (%s)" % _where())
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _list_goto("pause", "quit"):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return _page() == "", 3.0):
		return _res(true, false, "no question")
	await _refreshes(10)
	if not await _answer("char:T", "AskQuit's 'Quit to (D)os or (T)itle:' (vort_main.gd)", 1):
		await _press("back")    # neither: back to the pause menu
		await _leave_pause()
		return _res(true, false, _stuck)
	# the original's Game Over and the score table (a name asked only for a place in it) wait for a key
	for i: int in range(8):
		if await _wait(func() -> bool: return _host() == null or not bool(_eng().get("shell_playing")), 3.0):
			break
		await _press("accept")
	if _host() == null or bool(_eng().get("shell_playing")):
		return _res(true, false, "the game went on (%s)" % _where())
	var r: Dictionary = await _boot()
	return _res(true, r.completed, "" if r.completed else r.note)


## Load: from the title, Load Game's "Continue Which Game? 1-9"; in a game, the pause menu's Load Game
## (asked first) by the title.
func _v_load() -> Dictionary:
	if bool(_eng().get("shell_playing")):
		if not await _open_pause():
			return _res(false, false, _stuck)
		if not await _list_goto("pause", "load_game"):
			return _res(false, false, _stuck)
		await _press("accept")
		if not await _wait(func() -> bool: return _page() == "", 3.0):
			return _res(true, false, "no question")
		await _refreshes(10)
		if not await _answer("char:Y", "the pause menu's 'Leave this game (Y/N)?' (vort_screens.gd OptionsMenu)", 0):
			await _press("back")
			await _to_page("pause")
			await _leave_pause()
			return _res(true, false, _stuck + " (the game could not be left for the title, where Load Game is)")
	else:
		if not await _v_reach_title():
			return _res(false, false, "not at the title's menu (%s)" % _where())
		if not await _list_goto("title:main", "load_game"):
			return _res(false, false, _stuck)
		await _choose("title:main")
	if not await _wait(func() -> bool: return _page() == "", 6.0):
		return _res(true, false, "no Continue Game window")
	await _refreshes(20)
	if not await _answer("char:9", "RestoreMenu's 'Continue Which Game? 1-9 or ESC:' (vort_screens.gd)", 8):
		await _press("back")
		await _v_title()
		return _res(true, false, _stuck)
	var on_map: bool = await _wait(func() -> bool: return bool(_eng().get("shell_on_map")) and _live(), 20.0)
	await _refreshes(60)
	return _res(true, on_map, "the saved game on the world map" if on_map else "no saved game resumed (%s)" % _where())


## Extras' Help row (SCR-03: F1's pages, for the devices with no F1), on the title or in a game: the help's
## text in the pager, left with Back, the list again.
func _v_help_row(page: String) -> Dictionary:
	if not await _list_goto(page, "help"):
		return _res(false, false, _stuck)
	var e: Object = _eng()
	await _choose(page)
	if not await _wait(func() -> bool: return _page() != page and e.get("textdataPtr") == e.get("helptextPtr"), 3.0):
		return _res(true, false, "no help shown (%s)" % _where())
	await _refreshes(30)
	for i: int in range(4):
		await _press("back")
		if await _to_page(page, 2.5):
			return _res(true, true, "shown, left with %s" % _say("back"))
	return _res(true, false, "the help stayed (%s)" % _where())


## F1's help, from the title's menu: its text in the pager (the pager's text the help's), left with Back, and
## the menu moving again.
func _v_help() -> Dictionary:
	if not _can("fkey:1"):
		return _res(false, false, "F1 is the only way to the help: no %s button sends it and no menu row offers it (Extras: Story, About ID, Ordering Info, Previews, Restart Demo)" % device)
	if not await _v_reach_title():
		return _res(false, false, "not at the title's menu (%s)" % _where())
	var e: Object = _eng()
	await _press("fkey:1")
	if not await _wait(func() -> bool: return e.get("textdataPtr") == e.get("helptextPtr"), 3.0):
		return _res(true, false, "no help shown")
	await _refreshes(30)
	await _press("back")
	await _refreshes(30)
	var row: int = _row()
	await _press("down")
	var moved: bool = await _wait(func() -> bool: return _row() != row, 2.0)
	if moved:
		await _press("up")
		await _wait(func() -> bool: return _row() == row, 2.0)
	return _res(true, moved, "shown, left with %s" % _say("back") if moved else "the help stayed (%s)" % _where())


## F2: Sound (Y/N)? answered N then Y (its list: No, then Yes); the game's sound mode follows. A pad or a
## touch screen has no F2: the sound goes off and on by Options > Sound...'s Effects volume (the speaker's
## loudness, AUDIO-05), down to 0% and back.
func _v_sound() -> Dictionary:
	if not _can("fkey:2"):
		return await _v_volume_off_on()
	for answer: String in ["char:N", "char:Y"]:
		await _press("fkey:2")
		await _refreshes(20)
		if not await _answer(answer, "F2's 'Sound (Y/N)?' (vort_main.gd DoFkeys)", 1 if answer == "char:N" else 0):
			await _press("back")
			return _res(true, false, _stuck)
		var want: int = 0 if answer == "char:N" else 1
		if not await _wait(func() -> bool: return int(_eng().get("soundmode")) == want, 3.0):
			return _res(true, false, "%s left the sound mode %d" % [answer.substr(5), int(_eng().get("soundmode"))])
		await _refreshes(20)
	return _res(true, true, "off, then on")


## The sound off and on again by Options > Sound...'s Effects volume (left to 0%, right back), from the
## title's menu and back to it.
func _v_volume_off_on() -> Dictionary:
	if not (await _list_open("title:main", "options", "options")).completed or not (await _list_open("options", "sound", "sound")).completed:
		return _res(false, false, _stuck if _stuck != "" else "Sound... did not open (%s)" % _where())
	if not await _list_goto("sound", "effects_volume"):
		return _res(false, false, _stuck)
	var before: int = int(_value("effects_volume"))
	for i: int in range(12):
		if int(_value("effects_volume")) == 0:
			break
		await _press("left")
		await _list_dismiss("sound")
	var off: bool = int(_value("effects_volume")) == 0
	for i: int in range(12):
		if int(_value("effects_volume")) >= before:
			break
		await _press("right")
		await _list_dismiss("sound")
	var on: bool = int(_value("effects_volume")) == before
	for i: int in range(3):
		if _page() == "title:main":
			break
		await _press("back")
		await _wait(func() -> bool: return _page() == "title:main", 2.0)
	return _res(true, off and on, "Effects volume %d%% -> 0%% -> %d%%" % [before, int(_value("effects_volume"))])


## Quit: from the title's menu its Quit (Y/N)?; in a game the pause menu's Quit, (D)os.
func _v_quit_out() -> Dictionary:
	if bool(_eng().get("shell_playing")):
		if not await _open_pause():
			return _res(false, false, _stuck)
		if not await _list_goto("pause", "quit"):
			return _res(false, false, _stuck)
		await _press("accept")
		await _wait(func() -> bool: return _page() == "", 3.0)
		await _refreshes(10)
		if not await _answer("char:D", "AskQuit's 'Quit to (D)os or (T)itle:' (vort_main.gd)", 0):
			await _press("back")
			await _leave_pause()
			return _res(true, false, _stuck)
	else:
		if not await _v_reach_title():
			return _res(false, false, "not at the title's menu (%s)" % _where())
		if not await _list_goto("title:main", "quit"):
			return _res(false, false, _stuck)
		await _choose("title:main")
		await _wait(func() -> bool: return _page() == "", 3.0)
		await _refreshes(10)
		if not await _answer("char:Y", "the title's 'Quit (Y/N)?' (vort_main.gd AskQuit)", 0):
			await _press("back")
			return _res(true, false, _stuck)
	var gone: bool = await _wait(func() -> bool: return _host() == null, 15.0)
	return _res(true, gone, "" if gone else "the game did not end")


# ------------------------------------------------------------------ Keen 1-3's and Dreams' lists

## The probes: the page a list (or the title menu, or Dreams' panel) shows while it waits for a press, and
## the row its cursor is on.
func _page() -> String:
	var e: Object = _eng()
	return str(e.get("shell_menu_page")) if e != null and "shell_menu_page" in e else ""


func _row() -> int:
	var e: Object = _eng()
	return int(e.get("shell_menu_row")) if e != null and "shell_menu_row" in e else -1


## A page's rows as the engine shows them (the model's; the title menu's; the cheats', the pause menu's).
func _list_rows(page: String) -> Array:
	var e: Object = _eng()
	if e == null or _opts() == null:
		return []
	if page == "title:main":
		return _opts().main_rows(false)
	if page == "title:extras":
		return e.call("_extras_rows", false)    # (the model's, Help first: SCR-03)
	if GAMES[game].engine == "dreams":
		return e.call("_shell_list_rows", page)
	return e.call("_options_rows", page)


## Waits for a page, then a moment (the pad's menu keys again once a page stops reading the controls).
func _to_page(page: String, seconds: float = 4.0) -> bool:
	if not await _wait(func() -> bool: return _page() == page, seconds):
		return false
	await _refreshes(6)
	return _page() == page


## The cursor moved to a row on the page shown (up or down, the shorter way: the lists wrap).
func _list_goto(page: String, key: String) -> bool:
	if not await _to_page(page, 3.0):
		_stuck = "not on %s (%s)" % [page, _where()]
		return false
	var rows: Array = _list_rows(page)
	var want: int = -1
	for i: int in range(rows.size()):
		if str(rows[i].key) == key:
			want = i
	if want < 0:
		_stuck = "%s has no row %s" % [page, key]
		return false
	for k: int in range(rows.size() + 4):
		if _page() != page:
			_stuck = "the list left %s (%s)" % [page, _where()]
			return false
		var at: int = _row()
		if at == want:
			return true
		var down: bool = (want - at + rows.size()) % rows.size() <= rows.size() / 2
		if not await _press("down" if down else "up"):
			return false
		await _wait(func() -> bool: return _row() != at or _page() != page, 1.5)
	_stuck = "the cursor never reached %s on %s (it is on row %d)" % [key, page, _row()]
	return false


## The value a row shows (Mode's word, a cheat's state, a setting).
func _value(key: String) -> Variant:
	if key == "mode":
		return _opts().mode_text()
	if key.begins_with("cheat:"):
		return _eng().call("shell_cheat_get", key.substr(6))
	return _opts().get_value(key)


## Every row of a page, each its own function: a value moved and moved back, a page opened (INTO's walked
## in turn, then left by its Back row) or opened and left, an action done. Rows that are functions of their
## own elsewhere in the walk (a binding's capture, Level select's levels, Skip this level) are left to them.
func _list_walk(page: String, label: String) -> void:
	for r: Dictionary in _list_rows(page):
		var key: String = str(r.key)
		var name: String = "%s > %s" % [label, r.label]
		if key == "exit" or key == "pad_fixed" or key.begins_with("capture:") or key.begins_with("clear:") \
				or key.begins_with("cheat:warp:") or key == "cheat:skip_level":
			continue
		var target: String = key
		if key.begins_with("bind:"):
			target = "bindact:" + key.substr(5)
		elif key.begins_with("cheat:"):
			target = key.substr(6)
		if r.kind == "page" or key.begins_with("bind:"):
			if not r.get("enabled", true):
				await _fn(name + " (greyed: says why)", _list_greyed.bind(page, key))
			elif INTO.has(target):
				var o: Dictionary = await _fn(name, _list_open.bind(page, key, target))
				if o.completed:
					await _list_walk(target, name)
					await _fn(name + " > Back", _list_leave.bind(target, page))
			else:
				await _fn(name, _list_visit.bind(page, key, target))
		elif r.kind == "value":
			await _fn(name, _list_step.bind(page, key, bool(r.get("enabled", true))))
		elif key == "reset_controls":
			await _fn(name, _list_reset.bind(page))
		elif not r.get("enabled", true):
			await _fn(name + " (greyed: says why)", _list_greyed.bind(page, key))
		elif key == "cheat:info":
			await _fn(name, _list_info.bind(page, key))
		elif key == "cheat:free_items" or key == "cheat:extra_lives":
			await _fn(name, _list_once.bind(page, key))


## Accept on the row the cursor is on, once: a press a menu misses is its defect (_v_short_press counts
## them on Keen 1-3's title, where SCR-03 found one), and the function then fails where it stopped.
func _choose(_page_name: String) -> void:
	await _press("accept")


## A page row: the page opens.
func _list_open(page: String, key: String, target: String) -> Dictionary:
	if not await _list_goto(page, key):
		return _res(false, false, _stuck)
	await _choose(page)
	if await _to_page(target):
		return _res(true, true, "")
	return _res(true, false, "%s did not open (%s)" % [target, _where()])


## A page opened and left again with Back.
func _list_visit(page: String, key: String, target: String) -> Dictionary:
	var r: Dictionary = await _list_open(page, key, target)
	if not r.completed:
		return r
	await _press("back")
	if await _to_page(page):
		return _res(true, true, "opened, and left with %s" % _say("back"))
	return _res(true, false, "%s did not go back to %s (%s)" % [_say("back"), page, _where()])


## A page's Back row: the page before it again.
func _list_leave(page: String, parent: String) -> Dictionary:
	if not await _list_goto(page, "exit"):
		return _res(false, false, _stuck)
	await _press("accept")
	if await _to_page(parent):
		return _res(true, true, "")
	return _res(true, false, "Back did not return to %s (%s)" % [parent, _where()])


## The device's Back on a page: the page before it (or the window closed).
func _list_back(page: String, parent: String) -> Dictionary:
	if not await _to_page(page, 3.0):
		return _res(false, false, "not on %s (%s)" % [page, _where()])
	await _press("back")
	if await _to_page(parent):
		return _res(true, true, "")
	return _res(true, false, "%s did not return to %s (%s)" % [_say("back"), parent, _where()])


## A value row moved with right (left at its end) and back: the value it shows changes and returns.
func _list_step(page: String, key: String, enabled: bool) -> Dictionary:
	if not await _list_goto(page, key):
		return _res(false, false, _stuck)
	var before: Variant = _value(key)
	var back: String = "left"
	await _press("right")
	var changed: bool = await _wait(func() -> bool: return _value(key) != before, 1.5)
	if not changed and enabled:
		await _press("left")    # (a volume at its top)
		back = "right"
		changed = await _wait(func() -> bool: return _value(key) != before, 1.5)
	if not enabled:
		await _list_dismiss(page)
		return _res(true, not changed, "greyed: unchanged" if not changed else "greyed, but it changed")
	if not changed:
		return _res(true, false, "%s and %s left it at %s" % [_say("right"), _say("left"), str(before)])
	var after: Variant = _value(key)
	await _list_dismiss(page)
	await _press(back)
	var restored: bool = await _wait(func() -> bool: return _value(key) == before, 1.5)
	await _list_dismiss(page)
	return _res(true, restored, "%s -> %s%s" % [str(before), str(after), ", and back" if restored else ", not back (%s)" % str(_value(key))])


## A word said over the list (Keen 1-3's window waits for a key) put away; Dreams says it on the help line.
func _list_dismiss(page: String) -> void:
	await _refreshes(6)
	if _page() == "" and _host() != null:
		await _press("accept")
		await _to_page(page, 3.0)


## A greyed row chosen: it says why, and nothing changes.
func _list_greyed(page: String, key: String) -> Dictionary:
	if not await _list_goto(page, key):
		return _res(false, false, _stuck)
	var god: bool = bool(_eng().call("shell_cheat_get", "god"))
	await _press("accept")
	await _refreshes(12)
	var said: bool = _page() == ""
	await _list_dismiss(page)
	var same: bool = _page() == page and bool(_eng().call("shell_cheat_get", "god")) == god
	return _res(true, same, ("says why" if said else "chosen, nothing done") if same else "left %s (%s)" % [page, _where()])


## An original cheat code's row: its line is under it; choosing it does nothing more.
func _list_info(page: String, key: String) -> Dictionary:
	if not await _list_goto(page, key):
		return _res(false, false, _stuck)
	await _press("accept")
	await _refreshes(12)
	var same: bool = _page() == page
	return _res(true, same, "" if same else "left %s (%s)" % [page, _where()])


## A one-shot cheat: done, and said (Extra lives: the lives counted up, or full; Free items: the items).
func _list_once(page: String, key: String) -> Dictionary:
	if not await _list_goto(page, key):
		return _res(false, false, _stuck)
	var lives: int = _lives()
	await _press("accept")
	await _refreshes(12)
	await _list_dismiss(page)
	var ok: bool = false
	var note: String = ""
	if key == "cheat:extra_lives":
		ok = _lives() > lives or _lives() >= CheatsModel.MAX_LIVES
		note = "lives %d -> %d" % [lives, _lives()]
	else:
		ok = _items_given()
		note = "the items given" if ok else "no items given"
	return _res(true, ok and _page() == page, note + ("" if _page() == page else "; left %s (%s)" % [page, _where()]))


## Reset to defaults: asked Y/N (Keen 1-3's window, Dreams' help line), Y resets every control.
func _list_reset(page: String) -> Dictionary:
	if not await _list_goto(page, "reset_controls"):
		return _res(false, false, _stuck)
	await _press("accept")
	await _refreshes(12)
	var asked: String = "'Reset every control (Y/N)?' (vort_screens.gd OptionsMenu)" if GAMES[game].engine == "vorticons" \
		else "'Reset Every Control? Press Y' (drm_us.gd _shell_page_list)"
	if not await _answer("char:Y", asked, 0, "jump"):
		await _press("back")
		await _to_page(page)
		return _res(true, false, _stuck)
	await _refreshes(12)
	await _list_dismiss(page)
	var ok: bool = _host().controls.keys("jump") == ControlsModel.KEY_DEFAULTS["jump"] and _page() == page
	return _res(true, ok, "every control back to its default" if ok else "not reset (%s)" % _where())


## A screen from a menu row (High Scores, Story, About ID, Ordering Info, Previews): the menu left for it,
## and back with Back (or accept) pressed until the menu waits again.
func _list_screen(page: String, key: String) -> Dictionary:
	if not await _list_goto(page, key):
		return _res(false, false, _stuck)
	await _choose(page)
	if not await _wait(func() -> bool: return _page() != page, 3.0):
		return _res(true, false, "the menu stayed")
	await _refreshes(70)
	# accept first: Escape on Keen 1-3's screens is the originals' DoFkeys, which asks Quit to (D)os or (T)itle
	for i: int in range(16):
		var move: String = "accept" if i % 2 == 0 else "back"
		await _press(move)
		if await _to_page(page, 2.5):
			return _res(true, true, "shown, back with %s" % _say(move))
	return _res(true, false, "the screen stayed (%s)" % _where())


## SCR-06 (CTRL-03..05): the bindings changed by the device in use, from `start` (Keen 1-3's Options page,
## Dreams' Controls list; "" for Keen 4-6's cards, from MAIN): Status's Change catches the spare; Fire's
## Change left alone shows its countdown (5 to 1) and changes nothing; Fire cleared; Fire's Change catches a
## second spare, and its Add second the first spare (taken from Status, which keeps its own button or key).
## A touch screen has no key or button to bind.
func _bind_walk(start: String) -> void:
	if device == "touch":
		return
	var dev: String = "pad" if device == "pad" else "keys"
	var where: String = "Options > Controls... > %s..." % ("Controller" if dev == "pad" else "Keyboard")
	var fire: String = _opts().action_label("fire")    # (Dreams: Throw)
	await _fn("%s > Status > Change: one caught" % where, _bind_op.bind(start, "status", "capture:%s:status:0" % dev, "spare"), 40.0)
	await _fn("%s > %s > Change: left alone, its countdown runs out" % [where, fire],
		_bind_op.bind(start, "fire", "capture:%s:fire:0" % dev, ""), 40.0)
	await _fn("%s > %s > Clear" % [where, fire], _bind_op.bind(start, "fire", "clear:%s:fire" % dev, ""), 40.0)
	await _fn("%s > %s > Change: one caught" % [where, fire], _bind_op.bind(start, "fire", "capture:%s:fire:0" % dev, "spare2"), 40.0)
	await _fn("%s > %s > Add second: one caught" % [where, fire], _bind_op.bind(start, "fire", "capture:%s:fire:1" % dev, "spare"), 40.0)


## The device's keys or buttons for an action.
func _bound(dev: String, action: String) -> Array:
	var m: ControlsModel = _host().controls
	return m.buttons(action) if dev == "pad" else m.keys(action)


## One binding row of an action's page chosen (Change, Add second, Clear): a capture answered by the
## device's `move` (none: left alone, the countdown watched), the binding read back, the word said put
## away and the walk back where it started.
func _bind_op(start: String, action: String, row: String, move: String) -> Dictionary:
	var dev: String = "pad" if device == "pad" else "keys"
	var galaxy: bool = start == ""
	var before: Array = _bound(dev, action)
	if galaxy:
		var item: Object = _g_row_item(row, ["capture", "clear"])
		if item == null or not await _g_follow(_g_path(_g_main(), item)):
			return _res(false, false, _stuck if item != null else "no %s on the cards" % row)
	elif not await _bind_page(start, dev, action) or not await _list_goto("bindact:%s:%s" % [dev, action], row):
		return _res(false, false, _stuck)
	await _press("accept")
	var ok: bool = false
	var said: String = ""
	if row.begins_with("clear:"):
		ok = await _wait(func() -> bool: return _bound(dev, action).is_empty(), 3.0)
	elif not await _wait(func() -> bool: return str(_eng().get("controls_capture")) == dev, 3.0):
		said = "it did not wait for a %s (%s)" % ["button" if dev == "pad" else "key", _where()]
	elif move == "":
		var seen: Array = []
		await _wait(func() -> bool:
			var left: int = int(_eng().get("controls_capture_left"))
			if left > 0 and (seen.is_empty() or seen.back() != left):
				seen.append(left)
			return str(_eng().get("controls_capture")) == "", 8.0)
		var same: bool = _bound(dev, action) == before
		ok = seen == [5, 4, 3, 2, 1] and same
		said = "the countdown showed %s, then %s; " % [", ".join(PackedStringArray(seen.map(func(s: int) -> String: return str(s)))),
			"nothing changed" if same else "it changed"]
	else:
		var code: int = PAD[move] if dev == "pad" else KEYS[move]
		await _press(move)
		ok = await _wait(func() -> bool: return _bound(dev, action).has(code), 3.0)
		if row.ends_with(":1"):
			ok = ok and _bound(dev, action).size() == 2
	var note: String = said + "%s: %s" % [_opts().action_label(action), _host().controls.shown(dev, action)]
	if action == "fire" and move == "spare":
		note += "; Status: %s" % _host().controls.shown(dev, "status")
	# the word said put away, then back where the walk started
	if galaxy:
		await _wait(_g_dialog, 3.0)
		await _press("accept")
		await _wait(func() -> bool: return not _g_dialog(), 3.0)
		await _g_to_main()
	else:
		await _refreshes(12)
		if _page() == "" and _host() != null:
			await _press("accept")
		for i: int in range(5):
			if await _to_page(start, 2.0):
				break
			await _press("back")
	return _res(true, ok, note)


## From `start` (Keen 1-3's Options page or Dreams' Controls list) to an action's page: Controls..., the
## device's page, the action.
func _bind_page(start: String, dev: String, action: String) -> bool:
	var at: String = start
	for s: Array in [["controls", "controls"], [dev, dev], ["bind:%s:%s" % [dev, action], "bindact:%s:%s" % [dev, action]]]:
		if at == "controls" and s[1] == "controls":
			continue
		var r: Dictionary = await _list_open(at, s[0], s[1])
		if not r.completed:
			_stuck = r.note
			return false
		at = s[1]
	return true


## Cheats with no game: every row greyed; one chosen says why and changes nothing.
func _cheats_greyed(menu: String) -> Dictionary:
	var r: Dictionary = await _list_open(menu, "cheats", "cheats")
	if not r.completed:
		return r
	var greyed: bool = _list_rows("cheats").all(func(c: Dictionary) -> bool: return not str(c.key).begins_with("cheat:") or c.key == "cheat:codes" or not c.get("enabled", true))
	r = await _list_greyed("cheats", "cheat:god")
	await _press("back")
	await _to_page(menu)
	return _res(true, greyed and r.completed, ("every cheat greyed; " if greyed else "a cheat not greyed; ") + r.note)


## Level select: a level chosen in a game; the menu closes and the level is played.
func _level_select(page: String, key: String) -> Dictionary:
	if not (await _list_open(page, "cheat:levels:0", "levels:0")).completed:
		return _res(false, false, _stuck if _stuck != "" else "Level select did not open")
	if not await _list_goto("levels:0", key):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return _in_level() and _live() and _page() == "", 30.0):
		return _res(true, false, "no level entered (%s)" % _where())
	await _refreshes(90)
	return _res(true, true, "")


## Skip this level (inside a level): said, the menu left, the level ends and the map is back.
func _skip_level(_page_name: String) -> Dictionary:
	if not _in_level():
		return _res(false, false, "not inside a level (%s)" % _where())
	if not await _open_pause():
		return _res(false, false, _stuck)
	if GAMES[game].engine == "vorticons":
		if not (await _list_open("pause", "cheats", "cheats")).completed:
			return _res(false, false, _stuck)
	elif not await _d_open_list(4):
		return _res(false, false, _stuck)
	if not await _list_goto("cheats", "cheat:skip_level"):
		return _res(false, false, _stuck)
	await _press("accept")
	await _refreshes(12)
	if GAMES[game].engine == "vorticons":
		await _list_dismiss("cheats")    # "Level skipped"; the level ends once the menu is left
		await _leave_pause()
	var back: bool = await _wait(func() -> bool: return not _in_level() and _live(), 30.0)
	await _refreshes(60)
	return _res(true, back, "the world map again" if back else "still in the level (%s)" % _where())


# ------------------------------------------------------------------ play and the pause menus

## In play: the menus left (Back pressed while a menu waits).
func _to_play() -> bool:
	for i: int in range(6):
		if _host() == null:
			_stuck = "the game ended"
			return false
		if _in_play():
			return true
		if not await _press("back"):
			return false
		await _wait(_in_play, 2.0)
	_stuck = "not in play (%s)" % _where()
	return _in_play()


func _in_play() -> bool:
	if _host() == null or not _live():
		return false
	match GAMES[game].engine:
		"vorticons":
			return bool(_eng().get("shell_playing")) and not bool(_eng().get("shell_menu_open"))
		"galaxy":
			return not _g_open() and int(_eng().get("game_in_progress")) != 0
		"dreams":
			return bool(_eng().get("ingame")) and _page() == ""
	return false


func _in_level() -> bool:
	var e: Object = _eng()
	if e == null:
		return false
	match GAMES[game].engine:
		"vorticons":
			return bool(e.get("shell_in_level"))
		"galaxy":
			return int((e.get("ck_gameState") as Object).get("currentLevel")) != 0
		"dreams":
			return int((e.get("gamestate") as Object).get("mapon")) != 0
	return false


## The game's menu over the play (the device's menu button: the pad's Start).
func _open_pause() -> bool:
	if _pause_open():
		return true
	if not await _to_play():
		return false
	if not await _press("menu"):
		return false
	if not await _wait(_pause_open, 4.0):
		_stuck = "%s did not open the menu (%s)" % [_say("menu"), _where()]
		return false
	await _refreshes(10)
	return true


func _open_pause_fn() -> Dictionary:
	var ok: bool = await _open_pause()
	return _res(ok, ok, "" if ok else _stuck)


func _pause_open() -> bool:
	match GAMES[game].engine:
		"vorticons":
			return _page() == "pause"
		"galaxy":
			return _g_open() and _g_card() == _g_main() and not _g_dialog() and int(_eng().get("game_in_progress")) != 0
		"dreams":
			return _page() == "panel" and bool(_eng().get("ingame"))
	return false


## The pause menu left for the play (Back, as many as it takes).
func _leave_pause() -> void:
	for i: int in range(6):
		if _host() == null or _in_play():
			return
		await _press("back")
		await _wait(_in_play, 2.0)


## Resume: back to the play.
func _pause_resume(key: String) -> Dictionary:
	if not await _list_goto("pause", key):
		return _res(false, false, _stuck)
	await _press("accept")
	var ok: bool = await _wait(_in_play, 3.0)
	return _res(true, ok, "" if ok else "not back in play (%s)" % _where())


## A prompt's answer: the letter or digit the originals wait for, which the keyboard gives; a pad or a touch
## screen answers Keen 1-3's questions from their lists (SCR-04; `row`, the answer's row) and a question
## that reads the controls by its own move (`alt`: Dreams' Reset, Jump's button). False, with where, when
## the device has no way to give it.
func _answer(move: String, asked: String, row: int = -1, alt: String = "") -> bool:
	if _can(move):
		await _press(move)
		return true
	if row >= 0 and GAMES[game].engine == "vorticons":
		return await _pick(row, asked)
	if alt != "" and _can(alt):
		await _press(alt)
		return true
	_stuck = "at %s the %s has no %s" % [asked, device, _say(move)]
	return false


## The question Keen 1-3's list asks ("" none: SCR-04's probe).
func _asking() -> String:
	var e: Object = _eng()
	return str(e.get("shell_asking")) if e != null and "shell_asking" in e else ""


## Keen 1-3's question answered from its list (SCR-04): the caret moved to `row`, then chosen.
func _pick(row: int, asked: String) -> bool:
	if not await _wait(func() -> bool: return _asking() != "", 3.0):
		_stuck = "at %s no list to answer from (%s)" % [asked, _where()]
		return false
	var e: Object = _eng()
	for k: int in range(12):
		var at: int = int(e.get("shell_asking_row"))
		if at == row:
			break
		await _press("down" if row > at else "up")
		await _wait(func() -> bool: return int(e.get("shell_asking_row")) != at or _asking() == "", 1.5)
	if _asking() == "" or int(e.get("shell_asking_row")) != row:
		_stuck = "at %s the list's caret never reached row %d (%s)" % [asked, row, _where()]
		return false
	await _press("accept")
	return true


## A name (capitals) typed into a text field: the keys type it; the pad and touch use SCR-05's d-pad entry
## (Keen 1-3's Input, PadTextEntry in Keen 4-6 and Dreams: the first up shows A, each up the next letter,
## right keeps it and goes on; the last is kept by accept, which the caller presses). `erase`: the letters
## the field shows already (a slot's old name), taken back first (Backspace; the d-pad's left).
func _type_text(text: String, erase: int = 0) -> void:
	for i: int in range(erase):
		await _press("code:%d" % KEY_BACKSPACE if device == "keys" else "left", 3, 3)
	for i: int in range(text.length()):
		var c: String = text[i]
		if device == "keys":
			await _press("char:" + c)
		else:
			for k: int in range(c.unicode_at(0) - "A".unicode_at(0) + 1):
				await _press("up", 3, 3)
			if i < text.length() - 1:
				await _press("right", 3, 3)


func _lives() -> int:
	var e: Object = _eng()
	match GAMES[game].engine:
		"vorticons":
			return int((e.get("gamestate") as Object).get("lives"))
		"galaxy":
			return int((e.get("ck_gameState") as Object).get("numLives"))
		"dreams":
			return int((e.get("gamestate") as Object).get("lives"))
	return 0


func _items_given() -> bool:
	var e: Object = _eng()
	match GAMES[game].engine:
		"vorticons":
			return int((e.get("gamestate") as Object).get("ammo")) == 100
		"galaxy":
			return int((e.get("ck_gameState") as Object).get("numShots")) == 99
		"dreams":
			return int((e.get("gamestate") as Object).get("flowerpowers")) == 99
	return false


# ------------------------------------------------------------------ Keen 4-6

func _galaxy() -> void:
	# (a) the title's MAIN: OPTIONS (CONFIGURE's cards: every OptionsModel row on its card), CHEATS greyed,
	# HIGH SCORES, EXTRAS (Paddle War; Restart Demo is RETURN TO DEMO)
	for page: String in ["options", "display", "sound", "controls", "keys", "pad", "touch", "gameplay", "fixes"]:
		var label: String = PAGE_NAMES[page] if page != "touch" else "Options > Touch"    # (J-54: CONFIGURE's TOUCH card)
		if page == "fixes" and FixesModel.for_game(game).is_empty():
			continue
		await _fn("Main menu > " + label + (" (CONFIGURE)" if page == "options" else ""), _g_visit_card.bind(page))
		for r: Dictionary in _opts().page(page):
			var key: String = str(r.key)
			if key == "exit" or key == "pad_fixed" or r.kind == "page":
				continue
			if key.begins_with("bind:"):
				await _fn("%s > %s" % [label, r.label], _g_visit_bind.bind(key))
			elif r.kind == "value":
				await _fn("%s > %s" % [label, r.label], _g_option.bind(key))
			elif key == "reset_controls":
				await _fn("%s > %s" % [label, r.label], _g_reset)
	await _bind_walk("")
	await _fn("Main menu > Cheats... (no game: greyed)", _g_cheats_greyed)
	await _fn("Main menu > High Scores", _g_scores, 60.0)
	await _fn("Main menu > Extras... > Paddle War", _g_paddle, 40.0)
	await _fn("Main menu > Extras... > Restart Demo (RETURN TO DEMO)", _g_demo, 60.0)
	if game != "keen6":    # (Keen 6 has no help screens)
		await _fn("Main menu > Extras... > Help", _g_help_item, 60.0)
		if device == "keys":
			await _fn("Help (F1)", _g_help, 30.0)
	# (b) the originals' functions, and the cheats with a game in progress
	await _fn("New game: the world map", _g_new_game, 90.0)
	await _fn("Status on the map (%s)" % _say("status"), _g_status, 20.0)
	await _fn("Save with a typed name", _g_save, 90.0)
	await _fn("Load it", _g_load, 40.0)
	await _fn("Main menu > Resume (in a game)", _g_resume, 30.0)
	await _g_cheats()
	await _fn("End game", _g_end_game, 40.0)
	await _fn("Quit out (QUIT > QUIT, REALLY QUIT? yes)", _g_quit_out, 40.0)


## The card menu is up (and not leaving): Keen 4-6's wristwatch, from its first picture.
func _g_open() -> bool:
	var g: Object = _eng()
	return g != null and (g.get("vm") as DosMachine) != null and (g.get("vm") as DosMachine).marks.has("menu") \
		and not bool(g.get("command_confirmed")) and not bool(g.get("quitting"))


func _g_card() -> Object:
	return _eng().get("us_currentCard") if _eng() != null else null


func _g_main() -> Object:
	return _eng().get("ck_us_mainMenu") if _eng() != null else null


## A dialog over the cards (the toggles' word, the questions): the dialog reads the controls, the cards not
## (read as such though the host gives the pad the menus' keys there: SCR-03's shell_menu_keys).
func _g_dialog() -> bool:
	return _g_open() and _reads()


## The game reads its controls (the last few refreshes), whatever the host makes of the pad there.
func _reads() -> bool:
	var h: GameHost = _host()
	return h != null and h.engine != null and h.vm != null and "controls_read_vbl" in h.engine \
		and h.vm.vbl_count - int(h.engine.get("controls_read_vbl")) <= 6


## A card's items, up to its end.
func _g_items(card: Object) -> Array:
	var out: Array = []
	if card == null:
		return out
	for it: Object in card.get("items"):
		if int(it.get("type")) == GalMenu.US_ITEM_None:
			break
		out.append(it)
	return out


func _g_name(card: Object) -> String:
	if card == null:
		return "none"
	if card == _g_main():
		return "MAIN"
	return str(card.get("gfxChunk")).trim_prefix("TEXT:").trim_prefix("PIC_").trim_suffix("CARD")


## The items from `card` down to `target` (the submenus' items, then the target), or [].
func _g_path(card: Object, target: Object, depth: int = 0) -> Array:
	if card == null or depth > 6:
		return []
	for it: Object in _g_items(card):
		if it == target:
			return [it]
		var sub: Object = it.get("subMenu")
		if sub != null and int(it.get("type")) == GalMenu.US_ITEM_Submenu:
			var p: Array = _g_path(sub, target, depth + 1)
			if not p.is_empty():
				return [it] + p
	return []


## The item on MAIN's tree that opens `card`.
func _g_opener(card: Object, from: Object = null, depth: int = 0) -> Object:
	from = _g_main() if from == null else from
	if from == null or depth > 6:
		return null
	for it: Object in _g_items(from):
		var sub: Object = it.get("subMenu")
		if sub == card:
			return it
		if sub != null and int(it.get("type")) == GalMenu.US_ITEM_Submenu:
			var found: Object = _g_opener(card, sub, depth + 1)
			if found != null:
				return found
	return null


## Back to MAIN (Back pressed on the cards; a dialog answered no).
func _g_to_main() -> bool:
	for i: int in range(8):
		if not _g_open():
			_stuck = "the cards are not up (%s)" % _where()
			return false
		if _g_card() == _g_main() and not _g_dialog():
			return true
		await _press("back")
		await _wait(func() -> bool: return _g_card() == _g_main() and not _g_dialog(), 1.5)
	_stuck = "MAIN never came back (%s)" % _where()
	return false


## The cursor on an item of the card shown.
func _g_select(item: Object) -> bool:
	var card: Object = _g_card()
	var items: Array = _g_items(card)
	var want: int = items.find(item)
	if want < 0:
		_stuck = "%s is not on the card %s" % [str(item.get("caption")), _g_name(card)]
		return false
	for i: int in range(items.size() * 2 + 2):
		var at: int = int(card.get("selectedItem"))
		if at == want:
			return true
		if not await _press("down" if want > at else "up"):
			return false
		await _wait(func() -> bool: return int(card.get("selectedItem")) != at, 1.5)
		if _g_card() != card:
			_stuck = "the card changed (%s)" % _where()
			return false
	_stuck = "the cursor never reached %s on %s" % [str(item.get("caption")), _g_name(card)]
	return false


## From MAIN down a path: each submenu item chosen, its card waited for; the last item selected.
func _g_follow(path: Array) -> bool:
	if path.is_empty():
		_stuck = "no card holds it"
		return false
	if not await _g_to_main():
		return false
	for k: int in range(path.size()):
		var it: Object = path[k]
		if not await _g_select(it):
			return false
		if k < path.size() - 1:
			var sub: Object = it.get("subMenu")
			await _press("accept")
			if not await _wait(func() -> bool: return _g_card() == sub and not _g_dialog(), 3.0):
				_stuck = "%s did not open its card (%s)" % [str(it.get("caption")), _where()]
				return false
			await _refreshes(4)
	return true


## A row's item from the shell's toggles (its key and kind).
func _g_row_item(key: String, kinds: Array = ["option"]) -> Object:
	var toggles: Dictionary = _eng().get("_shell_toggles")
	for card: Object in toggles:
		var v: Array = toggles[card]
		if str(v[0]) == key and kinds.has(str(v[2])):
			return v[1]
	return null


## The card each Options page is on (Keen 4-6 hold the pages on CONFIGURE's cards).
func _g_page_card(page: String) -> Object:
	var g: Object = _eng()
	match page:
		"options":
			return g.get("ck_us_configureMenu")
		"display":
			return g.get("ck_us_displayMenu")
		"sound":
			return g.get("ck_us_soundMenu")
		"controls":
			return g.get("ck_us_controlsMenu")
		"gameplay":
			return g.get("ck_us_optionsMenu")
		"cheats":
			return g.get("ck_us_cheatsMenu")
		"touch":
			return g.get("ck_us_touchMenu")
	var names: Dictionary = {"keys": "KEYBOARD", "pad": "CONTROLLER", "fixes": "FIXES", "extras": "EXTRAS"}
	var holder: Object = g.get("ck_us_controlsMenu") if page in ["keys", "pad"] else (g.get("ck_us_configureMenu") if page == "fixes" else _g_main())
	for it: Object in _g_items(holder):
		if str(it.get("caption")) == names.get(page, ""):
			return it.get("subMenu")
	return null


## A page's card opened from MAIN, then back to MAIN.
func _g_visit_card(page: String) -> Dictionary:
	var card: Object = _g_page_card(page)
	if card == null:
		return _res(false, false, "no card for %s" % PAGE_NAMES.get(page, page))
	var opener: Object = _g_opener(card)
	if not await _g_follow(_g_path(_g_main(), opener)):
		return _res(false, false, _stuck)
	await _press("accept")
	var ok: bool = await _wait(func() -> bool: return _g_card() == card, 3.0)
	await _g_to_main()
	return _res(true, ok, _g_name(card) if ok else "%s did not open (%s)" % [str(opener.get("caption")), _where()])


## An option row on its card chosen twice: its value moves on (its word said), then back.
func _g_option(key: String) -> Dictionary:
	var item: Object = _g_row_item(key)
	if item == null:
		return _res(false, false, "no card shows it (the OptionsModel lists it for Keen 4-6)")
	if not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck)
	var before: Variant = _value(key)
	var seen: Array = []
	# a toggle comes back in two; a volume goes round its eleven steps (SCR-03: from the top to 0); J-54's
	# touch rows: the three layouts, the opacity's ten steps (10-100), the size's eleven (50-150)
	var times: int = {"touch_layout": 3, "touch_opacity": 10, "touch_size": 11}.get(key, 11 if key.ends_with("_volume") else 2)
	for i: int in range(times):
		await _press("accept")
		if not await _wait(_g_dialog, 3.0):
			return _res(true, false, "no word after choosing it (%s)" % _where())
		seen.append_array([_value(key), str(item.get("caption")), _shown(key)])
		await _press("accept")
		await _wait(func() -> bool: return not _g_dialog(), 3.0)
		await _refreshes(4)
	# the card's caption shows the value the model now has, as Keen 1-3's window does
	var changed: bool = seen[0] != before and str(seen[1]).contains("(%s)" % str(seen[2]).to_upper())
	var restored: bool = _value(key) == before
	await _g_to_main()
	return _res(true, changed and restored, "%s -> %s (%s), and back%s" % [str(before), str(seen[0]), seen[1], "" if restored else " not (%s)" % str(_value(key))])


## What the model's row shows for a key (its value word: "On", "Wide", "Enhanced").
func _shown(key: String) -> String:
	for page: String in ["options", "gameplay", "display", "fixes", "controls", "sound", "touch"]:
		for r: Dictionary in _opts().page(page):
			if str(r.key) == key:
				return str(r.value)
	return ""


## An action's card on KEYBOARD or CONTROLLER opened and left.
func _g_visit_bind(key: String) -> Dictionary:
	var p: PackedStringArray = key.split(":")
	var items: Dictionary = _eng().get("_shell_bind_items")
	for it: Object in items:
		var da: Array = items[it]
		if da[0] == p[1] and da[1] == p[2]:
			if not await _g_follow(_g_path(_g_main(), it)):
				return _res(false, false, _stuck)
			var sub: Object = it.get("subMenu")
			await _press("accept")
			var ok: bool = await _wait(func() -> bool: return _g_card() == sub, 3.0)
			await _g_to_main()
			return _res(true, ok, str(it.get("caption")) if ok else "its card did not open (%s)" % _where())
	return _res(false, false, "no card for %s" % key)


## RESET TO DEFAULTS: asked (PRESS Y TO RESET), the device's yes, every control back.
func _g_reset() -> Dictionary:
	var item: Object = _g_row_item("reset_controls", ["reset"])
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no RESET TO DEFAULTS item")
	await _press("accept")
	if not await _wait(_g_dialog, 3.0):
		return _res(true, false, "not asked")
	if not await _answer("yes", "'RESET EVERY CONTROL? PRESS Y TO RESET' (gal_menu.gd CK_US_ShellRowProc)"):
		await _press("back")
		await _g_to_main()
		return _res(true, false, _stuck)
	await _wait(func() -> bool: return not _g_dialog(), 3.0)
	await _wait(_g_dialog, 3.0)    # "THE CONTROLS ARE RESET"
	await _press("accept")
	await _wait(func() -> bool: return not _g_dialog(), 3.0)
	var ok: bool = _host().controls.keys("jump") == ControlsModel.KEY_DEFAULTS["jump"]
	await _g_to_main()
	return _res(true, ok, "every control back to its default" if ok else "not reset")


## CHEATS with no game: every toggle greyed; one chosen changes nothing.
func _g_cheats_greyed() -> Dictionary:
	var card: Object = _g_page_card("cheats")
	if card == null:
		return _res(false, false, "no CHEATS card")
	var item: Object = _g_row_item("god", ["cheat"])
	if not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck)
	var greyed: bool = _g_items(card).all(func(it: Object) -> bool: return int(it.get("type")) == GalMenu.US_ITEM_Submenu and (_g_name(it.get("subMenu")) == "MORE CHEATS" or (int(it.get("state")) & GalMenu.US_IS_Disabled) != 0))
	await _press("accept")
	await _refreshes(20)
	var same: bool = not bool(_eng().call("shell_cheat_get", "god")) and _g_card() == card
	await _g_to_main()
	return _res(true, greyed and same, ("every toggle greyed" if greyed else "a toggle not greyed") + (", GOD MODE chosen: nothing" if same else ", GOD MODE chosen changed something"))


## HIGH SCORES on the title: the menu closes and the attract loop shows them; the menu again with accept.
func _g_scores() -> Dictionary:
	var item: Object = _g_row_item("high_scores", ["scores"])
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no HIGH SCORES item")
	await _press("accept")
	var shown: bool = await _wait(func() -> bool: return bool(_eng().get("ck_inHighScores")), 8.0)
	var r: Dictionary = await _boot()
	return _res(true, shown and r.completed, ("the high scores shown" if shown else "no high scores") + ("" if r.completed else "; " + r.note))


## PADDLE WAR on EXTRAS: played (it reads the controls), left with Back.
func _g_paddle() -> Dictionary:
	var item: Object = _eng().get("ck_us_mainOriginal")[6]
	if not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck)
	var card: Object = _g_card()
	await _press("accept")
	if not await _wait(func() -> bool: return _g_card() == _eng().get("ck_us_paddleWarMenu") and _reads(), 3.0):
		return _res(true, false, "Paddle War did not start (%s)" % _where())
	await _hold("left", 40)
	await _press("back")    # (SCR-03: the menus' keys there, so the pad's B is Escape as on every card)
	var left: bool = await _wait(func() -> bool: return _g_card() == card, 3.0)
	await _g_to_main()
	return _res(true, left, "played, left with %s" % _say("back") if left else "%s did not leave it (%s)" % [_say("back"), _where()])


## RETURN TO DEMO on the title (Extras' Restart Demo): the demo plays; the menu again with accept.
func _g_demo() -> Dictionary:
	var item: Object = _eng().get("ck_us_mainOriginal")[4]
	if not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return not _g_open(), 3.0):
		return _res(true, false, "the menu stayed")
	await _refreshes(140)
	var r: Dictionary = await _boot()
	return _res(true, r.completed, "the demo, then the menu again" if r.completed else r.note)


## EXTRAS > HELP (SCR-03, Keen 4 and 5: F1's help screens for the devices with no F1): the topics up (the
## menus' keys asked for), the first topic opened and left, the help left with Back, EXTRAS again.
func _g_help_item() -> Dictionary:
	var item: Object = _g_row_item("help", ["help"])
	if item == null:
		return _res(false, false, "no HELP on EXTRAS")
	if not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck)
	var card: Object = _g_card()
	var g: Object = _eng()
	await _press("accept")
	if not await _wait(func() -> bool: return bool(g.get("shell_menu_keys")), 4.0):
		return _res(true, false, "no help screens (%s)" % _where())
	await _refreshes(40)
	await _press("accept")    # the first topic's pages
	await _refreshes(40)
	for i: int in range(6):
		await _press("back")
		if await _wait(func() -> bool: return _g_card() == card and not bool(g.get("shell_menu_keys")) and not _g_dialog(), 2.0):
			await _g_to_main()
			return _res(true, true, "a topic read, left with %s" % _say("back"))
	return _res(true, false, "the help stayed (%s)" % _where())


## F1: the help screens (Keen 4 and 5; Keen 6 has none), the keyboard's way.
func _g_help() -> Dictionary:
	await _g_to_main()
	await _press("fkey:1")
	await _refreshes(70)
	for i: int in range(12):
		await _press("back")
		if await _wait(func() -> bool: return _g_open() and _g_card() == _g_main() and not _g_dialog(), 2.0):
			return _res(true, true, "")
	return _res(true, false, "the help stayed (%s)" % _where())


## NEW GAME > BEGIN NORMAL GAME to the world map. Keen 6: OPTIONS' CREATURE QUESTION turned on first (off by
## default, J-04; Classic's), and the question answered by typing the creature's name.
func _g_new_game() -> Dictionary:
	if not _menu_ready() and not (await _boot()).completed:
		return _res(false, false, "not at the title's menu (%s)" % _where())
	var g: Object = _eng()
	if game == "keen6" and not bool(_opts().get_value("creature_question")):
		if not await _g_choose_row("creature_question") or not bool(_opts().get_value("creature_question")):
			return _res(false, false, "CREATURE QUESTION not turned on (%s)" % (_stuck if _stuck != "" else _where()))
	var item: Object = g.get("ck_us_newGameMenuItems")[1]
	if not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck)
	await _press("accept")
	var note: String = ""
	if game == "keen6":
		if not await _wait(func() -> bool: return bool(g.get("shell_text_entry")), 10.0):
			return _res(true, false, "no creature question (%s)" % _where())
		var answer: String = str(g.call("CK_STRINGELEMENT", "ck6_copyCreatureNames", int(g.get("currentCreature")))).to_upper()
		await _refreshes(10)
		await _type_text(answer)
		await _press("accept")
		if not await _wait(func() -> bool: return bool(g.get("ck6_creatureQuestionDone")), 5.0):
			return _res(true, false, "the creature question (%s) not answered (%s)" % [answer, _where()])
		note = "the creature question answered: %s" % answer
	if not await _wait(func() -> bool: return int(_eng().get("game_in_progress")) != 0 and not _in_level() and _in_play(), 60.0):
		return _res(true, false, note + "no world map (%s)" % _where())
	await _refreshes(90)
	return _res(true, true, note)


## An option row on its card chosen once (its value moves on, its word said and put away), then MAIN.
func _g_choose_row(key: String) -> bool:
	var item: Object = _g_row_item(key)
	if item == null:
		_stuck = "no card shows %s" % key
		return false
	if not await _g_follow(_g_path(_g_main(), item)):
		return false
	await _press("accept")
	if not await _wait(_g_dialog, 3.0):
		_stuck = "no word after choosing %s (%s)" % [key, _where()]
		return false
	await _press("accept")
	await _wait(func() -> bool: return not _g_dialog(), 3.0)
	await _refreshes(4)
	return await _g_to_main()


## Status: the window drops down, waits, and goes up again with accept.
func _g_status() -> Dictionary:
	if not await _to_play():
		return _res(false, false, _stuck)
	if not await _press("status"):
		return _res(false, false, _stuck)
	if not await _wait(func() -> bool: return int(_eng().get("ck_statusWindowYPx")) == 168, 4.0):
		return _res(true, false, "no status window")
	await _refreshes(10)
	await _press("accept")
	var ok: bool = await _wait(func() -> bool: return int(_eng().get("ck_statusWindowYPx")) <= 0 and _in_play(), 4.0)
	return _res(true, ok, "" if ok else "the status window stayed")


## SAVE GAME's first slot: the name typed (KEEN) and accepted; the slot's name read back.
func _g_save() -> Dictionary:
	if not await _open_pause():
		return _res(false, false, _stuck)
	var g: Object = _eng()
	var slot: Object = g.get("ck_us_loadSaveMenuItems")[0]
	if not await _g_follow([g.get("ck_us_mainOriginal")[2]]):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return _g_card() == g.get("ck_us_saveGameMenu"), 3.0):
		return _res(true, false, "SAVE GAME's card did not open")
	await _refreshes(6)
	if not await _g_select(slot):
		return _res(true, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return str(g.get("footer_str")[2]) == "Type name", 3.0):
		return _res(true, false, "no name field")
	await _refreshes(10)
	var entry: Object = g.get("us_savefiles")[0]
	await _type_text("KEEN", str(entry.get("name")).length() if bool(entry.get("used")) else 0)
	await _press("accept")
	var saved: bool = await _wait(func() -> bool: return bool(entry.get("used")) and str(g.get("footer_str")[2]) != "Type name", 6.0)
	var name: String = str(entry.get("name"))
	await _g_to_main()
	await _g_resume_play()
	if not saved:
		return _res(true, false, "nothing saved (%s)" % _where())
	var ok: bool = name.to_upper() == "KEEN"    # (the keys type it as the game reads them: lower case)
	return _res(true, ok, "saved as '%s'%s" % [name, "" if ok else ", not KEEN (US_LineInput, gal_us.gd)"])


## LOAD GAME's first slot (asked YOU'RE IN A GAME, the device's yes): the game goes on from it.
func _g_load() -> Dictionary:
	var g: Object = _eng()
	if not bool((g.get("us_savefiles")[0] as Object).get("used")):
		return _res(false, false, "no saved game in the first slot")
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _g_follow([g.get("ck_us_mainOriginal")[1]]):
		return _res(false, false, _stuck)
	await _press("accept")
	if not await _wait(func() -> bool: return _g_card() == g.get("ck_us_loadGameMenu"), 3.0):
		return _res(true, false, "LOAD GAME's card did not open")
	await _refreshes(6)
	if not await _g_select(g.get("ck_us_loadSaveMenuItems")[0]):
		return _res(true, false, _stuck)
	await _press("accept")
	if await _wait(_g_dialog, 3.0):
		if not await _answer("yes", "LOAD GAME's 'YOU'RE IN A GAME / PRESS Y TO LOAD GAME' (gal_menu.gd USL_ConfirmComm)"):
			await _press("back")
			await _g_to_main()
			await _g_resume_play()
			return _res(true, false, _stuck)
	var ok: bool = await _wait(func() -> bool: return not _g_open() and _in_play(), 20.0)
	await _refreshes(60)
	return _res(true, ok, "the game goes on from the save" if ok else "not loaded (%s)" % _where())


## RESUME (in a game): the menu closes, the play goes on.
func _g_resume() -> Dictionary:
	if not await _open_pause():
		return _res(false, false, _stuck)
	var ok: bool = await _g_resume_play()
	return _res(true, ok, "" if ok else "not back in play (%s)" % _where())


func _g_resume_play() -> bool:
	if not _g_open():
		return _in_play()
	if not await _g_follow([_eng().get("ck_us_mainOriginal")[4]]):
		return false
	await _press("accept")
	var ok: bool = await _wait(_in_play, 4.0)
	await _refreshes(20)
	return ok


## CHEATS with a game: every toggle on and off, the one-shots, the original codes, Level select into a
## level, Skip this level back to the map.
func _g_cheats() -> void:
	if int(_eng().get("game_in_progress")) == 0:
		await _fn("Cheats... (with a game)", func() -> Dictionary: return _res(false, false, "no game in progress (%s)" % _where()))
		return
	for r: Dictionary in CheatsModel.rows(_eng(), "toggle"):
		await _fn("Cheats... > %s" % r.label, _g_cheat_toggle.bind(str(r.key)), 30.0, _open_pause)
	for r: Dictionary in CheatsModel.rows(_eng(), "once"):
		if r.key != "skip_level":
			await _fn("Cheats... > More cheats > %s" % r.label, _g_cheat_once.bind(str(r.key)), 30.0, _open_pause)
	await _fn("Cheats... > More cheats > Original codes", _g_codes, 30.0, _open_pause)
	await _fn("Cheats... > More cheats > Level select > the first level", _g_level_select, 60.0, _open_pause)
	await _fn("Cheats... > More cheats > Skip this level", _g_skip, 60.0)
	if _g_open():
		await _g_to_main()
		await _g_resume_play()


func _g_cheat_toggle(key: String) -> Dictionary:
	var item: Object = _g_row_item(key, ["cheat"])
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no row for %s" % key)
	var before: bool = bool(_eng().call("shell_cheat_get", key))
	var seen: Array = []
	for i: int in range(2):
		await _press("accept")
		if not await _wait(_g_dialog, 3.0):
			return _res(true, false, "no word after choosing it")
		seen.append(bool(_eng().call("shell_cheat_get", key)))
		await _press("accept")
		await _wait(func() -> bool: return not _g_dialog(), 3.0)
		await _refreshes(4)
	await _g_to_main()
	var ok: bool = seen[0] != before and seen[1] == before
	return _res(true, ok, "on and off" if ok else "%s -> %s -> %s" % [before, seen[0], seen[1]])


func _g_cheat_once(key: String) -> Dictionary:
	var item: Object = _g_row_item(key, ["once"])
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no row for %s" % key)
	var lives: int = _lives()
	await _press("accept")
	if not await _wait(_g_dialog, 3.0):
		return _res(true, false, "no word after choosing it")
	await _press("accept")
	await _wait(func() -> bool: return not _g_dialog(), 3.0)
	await _g_to_main()
	if key == "extra_lives":
		var ok: bool = _lives() > lives or _lives() >= CheatsModel.MAX_LIVES
		return _res(true, ok, "lives %d -> %d" % [lives, _lives()])
	return _res(true, _items_given(), "the items given" if _items_given() else "no items given")


func _g_codes() -> Dictionary:
	var item: Object = _g_row_item("code:B+A+T", ["info"])
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no ORIGINAL CODES")
	await _press("accept")
	var said: bool = await _wait(_g_dialog, 3.0)
	await _press("accept")
	await _wait(func() -> bool: return not _g_dialog(), 3.0)
	await _g_to_main()
	return _res(true, said, "B+A+T says what it does" if said else "nothing said")


func _g_level_select() -> Dictionary:
	var item: Object = null
	var first: int = 1000
	var toggles: Dictionary = _eng().get("_shell_toggles")
	for card: Object in toggles:
		if str(toggles[card][2]) == "warp" and int(str(toggles[card][0]).substr(6)) < first:
			first = int(str(toggles[card][0]).substr(6))
			item = toggles[card][1]
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no LEVEL SELECT")
	var caption: String = str(item.get("caption"))
	await _press("accept")
	var ok: bool = await _wait(func() -> bool: return _in_level() and _in_play(), 40.0)
	await _refreshes(90)
	return _res(true, ok, caption if ok else "no level entered (%s)" % _where())


func _g_skip() -> Dictionary:
	if not _in_level():
		return _res(false, false, "not inside a level (%s)" % _where())
	if not await _open_pause():
		return _res(false, false, _stuck)
	var item: Object = _g_row_item("skip_level", ["once"])
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return _res(false, false, _stuck if item != null else "no SKIP THIS LEVEL")
	await _press("accept")
	await _wait(_g_dialog, 3.0)
	await _press("accept")
	await _wait(func() -> bool: return not _g_dialog(), 3.0)
	await _g_to_main()
	await _g_resume_play()
	var back: bool = await _wait(func() -> bool: return not _in_level() and _in_play(), 40.0)
	await _refreshes(60)
	return _res(true, back, "the world map again" if back else "still in the level (%s)" % _where())


## QUIT > END GAME (REALLY END CURRENT GAME? yes): the game over, the title's demo loop again.
func _g_end_game() -> Dictionary:
	if int(_eng().get("game_in_progress")) == 0:
		return _res(false, false, "no game in progress (%s)" % _where())
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _g_follow(_g_path(_g_main(), _eng().get("ck_us_mainOriginal")[5])):
		return _res(false, false, _stuck)
	await _press("accept")
	if await _wait(_g_dialog, 3.0):
		if not await _answer("yes", "END GAME's 'REALLY END CURRENT GAME? PRESS Y TO END IT' (gal_menu.gd USL_ConfirmComm)"):
			await _press("back")
			await _g_to_main()
			await _g_resume_play()
			return _res(true, false, _stuck)
	var ended: bool = await _wait(func() -> bool: return int(_eng().get("game_in_progress")) == 0, 15.0)
	var r: Dictionary = await _boot()
	return _res(true, ended, ("" if ended else "the game went on") + ("" if r.completed else "; " + r.note))


## QUIT > QUIT (REALLY QUIT? yes): the program ends, the launcher back.
func _g_quit_out() -> Dictionary:
	if not _g_open() and int(_eng().get("game_in_progress")) != 0:
		await _open_pause()    # (in a game: the cards over the play)
	if not _g_open() and not (await _boot()).completed:
		return _res(false, false, "no menu (%s)" % _where())
	if not await _g_follow(_g_path(_g_main(), _eng().get("ck_us_mainOriginal")[7])):
		return _res(false, false, _stuck)
	await _press("accept")
	if await _wait(_g_dialog, 3.0):
		if not await _answer("yes", "QUIT's 'REALLY QUIT? PRESS Y TO QUIT' (gal_menu.gd USL_ConfirmComm)"):
			await _press("back")
			return _res(true, false, _stuck)
	var gone: bool = await _wait(func() -> bool: return _host() == null, 15.0)
	return _res(true, gone, "" if gone else "the game did not end (%s)" % _where())


# ------------------------------------------------------------------ Keen Dreams

## The panel's icons (CtlPanels: 0 Start, 1 Help (Extras), 2 Disk, 3 Options, 4 Sound, 5 Music) and the
## row each puts up (CtlPanels2), by the panel's own order.
const D_ICONS: Array = [[0, "Start or Resume"], [2, "Load / Save / Quit"], [3, "Options"], [4, "Sound"], [5, "Music"], [1, "Extras"]]


func _dreams() -> void:
	# (a) the panel on the title: every icon; the Options keycaps' lists walked (every OptionsModel row);
	# Extras' help pages, the story and the high scores
	for ic: Array in D_ICONS:
		await _fn("Panel > %s" % ic[1], _d_icon.bind(ic[0]))
	var pages: Array = ["controls", "display", "sound", "gameplay"]
	var caps: Array = ["Input (Controls...)", "Video (Display...)", "Audio (Sound...)", "Game (Gameplay...)"]
	for k: int in range(pages.size()):
		var page: String = pages[k]
		var label: String = PAGE_NAMES[page]
		var r: Dictionary = await _fn("Panel > Options > %s" % caps[k], _d_list.bind(k))
		if r.completed:
			await _list_walk(page, label)
			if page == "controls":
				await _bind_walk("controls")
			await _fn(label + ": left with %s" % _say("back"), _list_back.bind(page, "panel"))
	await _fn("Panel > Options > Cheats... (no game: greyed, says why)", _d_cheats_greyed)
	for n: int in range(3):
		var names: Array = ["Help Me, I'm Lost! (F1)", "Help with the controls", "The story and game tips"]
		await _fn("Panel > Extras > %s" % names[n], _d_help.bind(n), 60.0)
	await _fn("Panel > Extras > High Scores", _d_scores, 40.0)
	# (b) the originals' functions, and the cheats with a game in progress
	await _fn("New game: the world map", _d_new_game, 60.0)
	await _fn("Status (%s)" % _say("status"), _d_status, 20.0)
	await _fn("Save with a typed name", _d_save, 90.0)
	await _fn("Load it", _d_load, 40.0)
	await _fn("Panel > Start > Resume (in a game)", _d_resume, 30.0)
	await _d_cheats()
	await _fn("Quit out (Disk > Exit to DOS > Really Exit)", _d_quit_out, 40.0)


## A panel item: [list, number] from the probe's row.
func _d_under() -> int:
	return _row() if _page() == "panel" else -2


func _d_rect(list: int, n: int) -> Array:
	var items: Variant = (_eng().get("TheItems") as Array)[list]
	if items == null or n >= (items as Array).size():
		return []
	var r: Object = (items as Array)[n].get("r")
	var ul: Object = r.get("ul")
	var lr: Object = r.get("lr")
	return [int(ul.get("x")), int(ul.get("y")), int(lr.get("x")), int(lr.get("y"))]


## The panel's cursor moved onto an item and the item chosen. The arrows glide the cursor to the nearest
## item that way (USL_FindRect); the walk tries the way towards the item first, then the others, never the
## same way twice from the same place, so an item it does not reach is one the arrows cannot reach from
## anywhere the walk has been.
func _d_hit(list: int, n: int, hit: bool = true) -> bool:
	var tried: Dictionary = {}
	var seen: Array = []
	for k: int in range(40):
		if not await _to_page("panel", 3.0):
			_stuck = "not on the panel (%s)" % _where()
			return false
		if _d_under() == list * 100 + n:
			if hit:
				await _press("accept")
			return true
		var r: Array = _d_rect(list, n)
		if r.is_empty():
			_stuck = "the panel shows no item %d of row %d" % [n, list]
			return false
		var x: int = int(_eng().get("CursorX"))
		var y: int = int(_eng().get("CursorY"))
		if not seen.has(_d_under()):
			seen.append(_d_under())
		var dx: int = (r[0] + r[2]) / 2 - x
		var dy: int = (r[1] + r[3]) / 2 - y
		var h: String = "right" if dx > 0 else "left"
		var v: String = "down" if dy > 0 else "up"
		var ways: Array = [h, v, "up" if v == "down" else "down", "left" if h == "right" else "right"] if absi(dx) >= absi(dy) \
			else [v, h, "left" if h == "right" else "right", "up" if v == "down" else "down"]
		var move: String = ""
		for w: String in ways:
			if not tried.has("%d,%d,%s" % [x, y, w]):
				move = w
				break
		if move == "":
			break
		tried["%d,%d,%s" % [x, y, move]] = true
		await _press(move)
		await _wait(func() -> bool: return int(_eng().get("CursorX")) != x or int(_eng().get("CursorY")) != y, 1.0)
		await _refreshes(4)
	var item: Object = ((_eng().get("TheItems") as Array)[list] as Array)[n]
	var name: String = str(item.get("help"))
	var code: int = _key_of_scancode(int(item.get("key")))
	if device == "keys" and code != KEY_NONE:
		# the keyboard has the item's own key (the panel's hot keys)
		await _press("code:%d" % code)
		_via = "by its key %s (the arrows do not reach it)" % OS.get_keycode_string(code as Key)
		return true
	_stuck = "the d-pad never brought the cursor to '%s' (item %d of the panel's row %d; the arrows reached %s)" % [name, n, list,
		", ".join(PackedStringArray(seen.map(func(s: int) -> String: return "%d.%d" % [s / 100, s % 100] if s >= 0 else "none")))]
	return false


## An icon hit: its row of keycaps or buttons put up.
func _d_icon(k: int) -> Dictionary:
	if not await _d_hit(0, k):
		return _res(false, false, _stuck)
	var want: Variant = (_eng().get("CtlPanels2") as Array)[k]
	var ok: bool = await _wait(func() -> bool: return _page() == "panel" and (_eng().get("TheItems") as Array)[1] == want, 3.0)
	return _res(true, ok, "" if ok else "its row did not come up (%s)" % _where())


## The Options icon's keycap `k` (Input, Video, Audio, Game, Cheat): its list in the box.
func _d_list(k: int) -> Dictionary:
	var ok: bool = await _d_open_list(k)
	return _res(ok, ok, "" if ok else _stuck)


func _d_open_list(k: int) -> bool:
	if not await _d_hit(0, 3):
		return false
	await _refreshes(10)
	if not await _d_hit(1, k):
		return false
	var page: String = (_eng().get("_shell_pages") as Array)[k]
	if not await _to_page(page):
		_stuck = "the %s list did not open (%s)" % [page, _where()]
		return false
	return true


func _d_cheats_greyed() -> Dictionary:
	if not await _d_open_list(4):
		return _res(false, false, _stuck)
	var greyed: bool = _list_rows("cheats").all(func(c: Dictionary) -> bool: return not str(c.key).begins_with("cheat:") or c.key == "cheat:codes" or not c.get("enabled", true))
	var r: Dictionary = await _list_greyed("cheats", "cheat:god")
	await _press("back")
	await _to_page("panel")
	return _res(true, greyed and r.completed, ("every cheat greyed; " if greyed else "a cheat not greyed; ") + r.note)


## Extras' help keycaps: the help's text pages, left with Back.
func _d_help(n: int) -> Dictionary:
	if not await _d_hit(0, 1):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, n):
		return _res(false, false, _stuck)
	if not await _wait(func() -> bool: return _page() != "panel", 3.0):
		return _res(true, false, "no help shown")
	await _refreshes(70)
	for i: int in range(10):
		await _press("back")
		if await _to_page("panel", 2.5):
			return _res(true, true, "shown, back with %s" % _say("back"))
	return _res(true, false, "the help stayed (%s)" % _where())


func _d_scores() -> Dictionary:
	if not await _d_hit(0, 1):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 3):
		return _res(false, false, _stuck)
	if not await _wait(func() -> bool: return _page() != "panel", 3.0):
		return _res(true, false, "no high scores shown")
	await _refreshes(70)
	await _press("accept")
	var ok: bool = await _to_page("panel", 4.0)
	return _res(true, ok, "shown, back with %s" % _say("accept") if ok else "the scores stayed")


## Start > New Game > Normal: the world map.
func _d_new_game() -> Dictionary:
	if not _menu_ready() and not (await _boot()).completed:
		return _res(false, false, "not at the title's panel (%s)" % _where())
	if not await _d_hit(0, 0):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 0):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(2, 0):
		return _res(false, false, _stuck)
	var ok: bool = await _wait(func() -> bool: return bool(_eng().get("ingame")) and _in_play(), 40.0)
	await _refreshes(90)
	return _res(true, ok, "" if ok else "no world map (%s)" % _where())


func _d_status() -> Dictionary:
	if not await _to_play():
		return _res(false, false, _stuck)
	if not await _press("status"):
		return _res(false, false, _stuck)
	if not await _wait(func() -> bool: return not _live(), 3.0):
		return _res(true, false, "no status window")
	await _refreshes(20)
	await _press("accept")
	var ok: bool = await _wait(_in_play, 4.0)
	return _res(true, ok, "" if ok else "the status window stayed")


## Disk > Load / Save > the first slot's Save: the name typed (KEEN) and accepted, read back.
func _d_save() -> Dictionary:
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _d_hit(0, 2):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 0):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(2, 1):
		return _res(false, false, _stuck)
	if not await _wait(func() -> bool: return _page() == "", 3.0):
		return _res(true, false, "no name field")
	await _refreshes(20)
	var slot: Object = (_eng().get("Games") as Array)[0]
	await _type_text("KEEN", (slot.get("name") as PackedByteArray).get_string_from_ascii().length() if bool(slot.get("present")) else 0)
	await _press("accept")
	var saved: bool = await _wait(func() -> bool: return bool(slot.get("present")) and _page() == "panel", 8.0)
	var name: String = (slot.get("name") as PackedByteArray).get_string_from_ascii()
	await _leave_pause()
	if not saved:
		return _res(true, false, "nothing saved (%s)" % _where())
	var ok: bool = name.to_upper() == "KEEN"    # (the keys type it as the game reads them: lower case)
	return _res(true, ok, "saved as '%s'%s" % [name, "" if ok else ", not KEEN (US_LineInput, drm_us.gd)"])


## Disk > Load / Save > the first slot's Load: the game goes on from it.
func _d_load() -> Dictionary:
	if not bool(((_eng().get("Games") as Array)[0] as Object).get("present")):
		return _res(false, false, "no saved game in the first slot")
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _d_hit(0, 2):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 0):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(2, 0):
		return _res(false, false, _stuck)
	await _wait(func() -> bool: return _page() == "", 6.0)
	for i: int in range(4):    # (PAUSED after a load waits for a key)
		if await _wait(_in_play, 3.0):
			break
		await _press("accept")
	var ok: bool = _in_play()
	await _refreshes(60)
	return _res(true, ok, "the game goes on from the save" if ok else "not loaded (%s)" % _where())


## Start > Resume > Resume Current Game: the play goes on.
func _d_resume() -> Dictionary:
	if not await _open_pause():
		return _res(false, false, _stuck)
	if not await _d_hit(0, 0):
		return _res(true, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 1):
		return _res(true, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(2, 0):
		return _res(true, false, _stuck)
	var ok: bool = await _wait(_in_play, 4.0)
	return _res(true, ok, "" if ok else "not back in play (%s)" % _where())


func _d_cheats() -> void:
	if not bool(_eng().get("ingame")):
		await _fn("Cheats... (with a game)", func() -> Dictionary: return _res(false, false, "no game in progress (%s)" % _where()))
		return
	var r: Dictionary = await _fn("Panel > Options > Cheats...", _d_list.bind(4), 30.0, _open_pause)
	if r.completed:
		await _list_walk("cheats", "Cheats...")
		await _fn("Cheats... > Level select... > the first level", _level_select.bind("cheats", "cheat:warp:1"), 60.0)
		await _fn("Cheats... > Skip this level", _skip_level.bind("cheats"), 60.0)
	if _page() != "":
		await _leave_pause()


## Disk > Exit to DOS > Really Exit to DOS: the program ends.
func _d_quit_out() -> Dictionary:
	if _page() != "panel" and not await _open_pause() and not _menu_ready():
		return _res(false, false, _stuck)
	if not await _d_hit(0, 2):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 1):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(2, 0):
		return _res(false, false, _stuck)
	var gone: bool = await _wait(func() -> bool: return _host() == null, 15.0)
	return _res(true, gone, "" if gone else "the game did not end (%s)" % _where())


# ------------------------------------------------------------------ SCR-08: the mash walk

## SCR-08 (--mash=1): per game, from the launcher, buttons pressed and let go at random gaps of 15 to 50 ms
## (seeded: --seed, the same presses each run) where a player mashes them: B (back) through the intro, the
## title, its attract loop and its menus; A (accept) into a new game, into a level, through a death and the
## game's way back; A and B through a level's end; Start (menu) over the play, Keen 4-6's cards and Dreams'
## panel opened and shut. Each stretch passes the fades its screens have. Asserted: a new game, an entry, a
## restart and an end each load the map or the level once (the engines' shell_level_loads, counted where
## each loads one), the windows the originals show there still come (Keen 1-3's Keens Left, Keen 4-6's level
## box, Dreams' Loading box: shell_level_boxes), and the game quits back to the launcher.
var mash: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Where Keen dies soon with a direction held from a level's start (found by holding it; the level entered
## by Level select): [level, the direction].
const DEATHS: Dictionary = {
	"keen1": [3, "right"], "keen2": [9, "right"], "keen3": [1, "right"], "keen4": [2, "left"], "keen5": [2, "left"],
	"keen6": [4, "left"], "kdreams": [5, "right"], "kdreams193": [5, "right"],
}
## How many times each stretch shows its window, as one press makes it (-1: as the cache has it, Keen 4-6's
## box comes only while a level's pictures are still to load): [new game, entry, death, end].
const MASH_BOXES: Dictionary = {"vorticons": [1, 0, 1, 0], "galaxy": [1, 1, -1, -1], "dreams": [1, 1, 1, 1]}


func _mash_walk(id: String) -> void:
	game = id
	_show_tiles()
	print("WALK %s by %s, mashed (seed %d)" % [game, device, rng.seed])
	var r: Dictionary = await _fn("Launcher: to the tile, the game started", _launch, 40.0)
	if not r.completed:
		return
	var engine: String = GAMES[game].engine
	var boxes: Array = MASH_BOXES[engine]
	await _fn("Mashed B from the start through the title and its menus: no game started, the menu again", _mash_back, 60.0)
	# A into a new game: Keen 1-3 from the title's menu (its first row); Keen 4-6 and Dreams from their new
	# game's last choice (BEGIN NORMAL GAME; Normal), which A chooses
	if engine != "vorticons":
		r = await _fn("To the new game's last choice", _mash_new_game_choice, 60.0)
		if not r.completed:
			await _fn("Back on the launcher, its tile focused and moving", _launcher_back, 40.0)
			return
	await _fn("Mashed A into a new game: the map loaded once, its window shown", _mash_through.bind(["accept"],
		_on_map, 40.0, 2.0, 1, boxes[0]), 70.0)
	await _fn("Mashed %s over the map: %s opened and shut, the play again" % [_say("menu"), _menus_name()], _mash_menus, 40.0)
	# A into a level: Keen 1-3 steered to the first level's entrance; Keen 4-6 and Dreams by Level select
	r = await _fn("To a level's way in", _mash_entry_ready, 60.0)
	if r.completed:
		await _fn("Mashed A into the level: loaded once, its window shown", _mash_through.bind(["accept"],
			func() -> bool: return _in_level() and _in_play(), 30.0, 2.0, 1, boxes[1]), 50.0)
	await _fn("Mashed %s in a level: %s opened and shut, the play again" % [_say("menu"), _menus_name()], _mash_menus, 40.0)
	# a death and the game's way back (Keen 1-3's map, Keen 4-6's and Dreams' Try Again)
	r = await _fn("A death: Level select to level %d, %s held" % [DEATHS[game][0], _say(DEATHS[game][1])], _mash_to_death, 90.0)
	if r.completed:
		var l0: int = _loads()
		await _fn("Mashed A through the death and back: loaded once, its window shown", _mash_through.bind(["accept"],
			func() -> bool: return _loads() > l0 and (_on_map() if engine == "vorticons" else _in_play()), 40.0, 0.0, 1, boxes[2]), 60.0)
	# a level's end: Skip this level chosen and the menus left, then A mashed until the map is back
	await _fn("Skip this level, then A mashed through the level's end: the map loaded once", _mash_end.bind(boxes[3]), 120.0)
	match engine:
		"vorticons":
			await _fn("Quit out (Quit: Dos)", _v_quit_out, 30.0)
		"galaxy":
			await _fn("Quit out (QUIT > QUIT, REALLY QUIT? yes)", _g_quit_out, 40.0)
		"dreams":
			await _fn("Quit out (Disk > Exit to DOS > Really Exit)", _d_quit_out, 40.0)
	await _fn("Back on the launcher, its tile focused and moving", _launcher_back, 40.0)


func _loads() -> int:
	return int(_eng().get("shell_level_loads")) if _eng() != null else -1


func _boxes() -> int:
	return int(_eng().get("shell_level_boxes")) if _eng() != null else -1


## On the world map, in play (Keen 1-3: its own loop running, Keens Left put away: canSave).
func _on_map() -> bool:
	if not _in_play():
		return false
	if GAMES[game].engine == "vorticons":
		return bool(_eng().get("shell_on_map")) and bool(_eng().get("canSave"))
	return not _in_level()


func _menus_name() -> String:
	return {"vorticons": "the menu", "galaxy": "the cards", "dreams": "the panel"}[GAMES[game].engine]


## `moves` (one at random each time) pressed and let go at random gaps of 15 to 50 ms until `done` holds,
## for at most `seconds`. Whether it held.
func _mash(moves: Array, seconds: float, done: Callable) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and _host() != null:
		if done.call():
			return true
		var move: String = moves[rng.randi() % moves.size()]
		var down: InputEvent = _event(move, true)
		if down == null:
			_stuck = "the %s has no %s" % [device, _say(move)]
			return false
		Input.parse_input_event(down)
		await _pause(rng.randi_range(15, 50) / 1000.0)
		var up: InputEvent = _event(move, false)
		if up == null:
			up = down.duplicate()
			up.set("pressed", false)
		Input.parse_input_event(up)
		await _pause(rng.randi_range(15, 50) / 1000.0)
	return _host() != null and done.call()


## A mashed stretch, from where the walk stands until `done`: the map or the level loaded `loads` times and
## the window shown `boxes` times there (-1: not counted), as one press makes them; `settle` seconds more
## mashed past it (a second start's chance).
func _mash_through(moves: Array, done: Callable, seconds: float, settle: float, loads: int, boxes: int) -> Dictionary:
	var l0: int = _loads()
	var b0: int = _boxes()
	var reached: bool = await _mash(moves, seconds, done)
	if reached and settle > 0.0:
		await _mash(moves, settle, func() -> bool: return false)
	if _host() == null:
		return _res(true, false, "the game ended")
	await _refreshes(30)
	var dl: int = _loads() - l0
	var db: int = _boxes() - b0
	var ok: bool = reached and done.call() and dl == loads and (boxes < 0 or db == boxes)
	return _res(true, ok, "%s; loaded %d (%d wanted), its window %d%s" % ["there" if reached else "not there (%s)" % _where(),
		dl, loads, db, "" if boxes < 0 else " (%d wanted)" % boxes])


## The menus mashed open and shut over the play (Start, as a player mashes it): no level loaded, the play
## again once the mashing stops (Back while a menu is up).
func _mash_menus() -> Dictionary:
	if not await _to_play():
		return _res(false, false, _stuck)
	var l0: int = _loads()
	var level: bool = _in_level()
	await _mash(["menu"], 4.0, func() -> bool: return false)
	await _refreshes(30)
	if GAMES[game].engine == "galaxy" and _g_open():
		# (Escape on MAIN asks REALLY QUIT?, as the original's USL_UpLevel does: answered no, then RESUME)
		for i: int in range(4):
			if not _g_dialog():
				break
			await _press("back")
			await _wait(func() -> bool: return not _g_dialog(), 2.0)
		await _g_to_main()
		await _g_resume_play()
	for i: int in range(8):
		if _in_play():
			break
		await _press("back")
		await _wait(_in_play, 2.0)
	var ok: bool = _in_play() and _loads() == l0 and _in_level() == level
	return _res(true, ok, "%s, loaded %d" % ["the play again" if _in_play() else "not back in play (%s)" % _where(), _loads() - l0])


## B mashed from wherever the game stands (its intro, title, attract loop, menus) for a few seconds: no
## game started, then the title's menu reached by A as ever.
func _mash_back() -> Dictionary:
	await _mash(["back"], 6.0, func() -> bool: return false)
	if _host() == null:
		return _res(true, false, "B quit the game")
	await _refreshes(30)
	# (Keen 4-6: B on MAIN asks REALLY QUIT?, as the original's Escape does: answered no before A goes on)
	for i: int in range(4):
		if GAMES[game].engine != "galaxy" or not _g_dialog():
			break
		await _press("back")
		await _wait(func() -> bool: return not _g_dialog(), 2.0)
	var playing: bool = false
	match GAMES[game].engine:
		"vorticons":
			playing = bool(_eng().get("shell_playing"))
		"galaxy":
			playing = int(_eng().get("game_in_progress")) != 0
		"dreams":
			playing = bool(_eng().get("ingame"))
	var r: Dictionary = await _boot()
	await _refreshes(70)
	if not _menu_ready():    # (a last B still on its way left the menu again: A brings it back, as ever)
		r = await _boot()
	return _res(true, not playing and r.completed, ("no game started" if not playing else "a game started") + (", the menu again" if r.completed else ", " + r.note))


## Keen 4-6: NEW GAME > BEGIN NORMAL GAME under the cursor; Dreams: Start > New Game > Normal under it.
func _mash_new_game_choice() -> Dictionary:
	if not _menu_ready() and not (await _boot()).completed:
		return _res(false, false, "not at the title's menu (%s)" % _where())
	if GAMES[game].engine == "galaxy":
		var ok: bool = await _g_follow(_g_path(_g_main(), _eng().get("ck_us_newGameMenuItems")[1]))
		return _res(ok, ok, "" if ok else _stuck)
	if not await _d_hit(0, 0):
		return _res(false, false, _stuck)
	await _refreshes(10)
	if not await _d_hit(1, 0):
		return _res(false, false, _stuck)
	await _refreshes(10)
	var on: bool = await _d_hit(2, 0, false)
	return _res(on, on, "" if on else _stuck)


## Keen 1-3: on the map, steered to the first level's entrance; Keen 4-6 and Dreams: Level select's first
## level under the cursor (the cards; the panel's list).
func _mash_entry_ready() -> Dictionary:
	match GAMES[game].engine:
		"vorticons":
			if not bool(_eng().get("shell_on_map")) or not await _to_play():
				return _res(false, false, "not on the world map (%s)" % _where())
			var path: Array = _v_map_path(1)
			if path.is_empty():
				return _res(false, false, "no way on the map from Keen to the first level's entrance")
			await _v_steer(path)
			var over: bool = await _v_onto(path)
			return _res(over, over, "%d tiles walked" % (path.size() - 1) if over else "Keen never stood over the entrance")
		"galaxy":
			if not await _open_pause():
				return _res(false, false, _stuck)
			var item: Object = _g_warp_item(1)
			var ok: bool = item != null and await _g_follow(_g_path(_g_main(), item))
			return _res(ok, ok, "" if ok else (_stuck if item != null else "no level 1 in Level select"))
	if not await _open_pause() or not await _d_open_list(4) or not (await _list_open("cheats", "cheat:levels:0", "levels:0")).completed \
			or not await _list_goto("levels:0", "cheat:warp:1"):
		return _res(false, false, _stuck)
	return _res(true, true, "")


## Keen 4-6's Level select item for level `n`.
func _g_warp_item(n: int) -> Object:
	var toggles: Dictionary = _eng().get("_shell_toggles")
	for card: Object in toggles:
		if str(toggles[card][2]) == "warp" and int(str(toggles[card][0]).substr(6)) == n:
			return toggles[card][1]
	return null


## Keen's death begun (his dying state), for each engine.
func _dying() -> bool:
	var e: Object = _eng()
	if e == null:
		return false
	match GAMES[game].engine:
		"vorticons":
			return str(((e.get("objlist") as Array)[0] as Object).get("think")) == "KeenDead"
		"galaxy":
			var k: Object = e.get("ck_keenObj")
			var act: Object = k.get("currentAction") if k != null else null
			for name: String in ["CK_ACT_keenDie0", "CK_ACT_keenDie1", "CK4_ACT_KeenSwimDie0", "CK4_ACT_KeenSwimDie1"]:
				if act != null and act == e.call("CK_GetActionByName", name):
					return true
			return int((e.get("ck_gameState") as Object).get("levelState")) == 1    # (LS_Died)
		"dreams":
			var p: Object = e.get("player")
			var st: Object = p.get("state") if p != null else null
			return st != null and [e.call("S", &"s_keendie1"), e.call("S", &"s_keendie2"), e.call("S", &"s_keendie3")].has(st)
	return false


## Into DEATHS' level by Level select, then its direction held (nothing else pressed) until Keen dies.
func _mash_to_death() -> Dictionary:
	var d: Array = DEATHS[game]
	if not await _mash_level_select(int(d[0])):
		return _res(false, false, "Level select did not take Keen into level %d (%s)" % [d[0], _stuck if _stuck != "" else _where()])
	var held: InputEvent = _event(d[1], true)
	Input.parse_input_event(held)
	var died: bool = await _wait(_dying, 40.0)
	var up: InputEvent = held.duplicate()
	up.set("pressed", false)
	Input.parse_input_event(up)
	return _res(true, died, "Keen dies" if died else "Keen lives on (%s)" % _where())


## Level select into level `n` (the menus walked as ever), in play there.
func _mash_level_select(n: int) -> bool:
	if not await _open_pause():
		return false
	match GAMES[game].engine:
		"vorticons":
			if not (await _list_open("pause", "cheats", "cheats")).completed:
				return false
			return (await _level_select("cheats", "cheat:warp:%d" % n)).completed
		"dreams":
			if not await _d_open_list(4):
				return false
			return (await _level_select("cheats", "cheat:warp:%d" % n)).completed
	var item: Object = _g_warp_item(n)
	if item == null or not await _g_follow(_g_path(_g_main(), item)):
		return false
	await _press("accept")
	var ok: bool = await _wait(func() -> bool: return _in_level() and _in_play(), 40.0)
	await _refreshes(30)
	return ok


## A level's end: in a level (Level select's first when on the map), the cheats' Skip this level chosen and
## the menus left as ever (the level ends then), A mashed from there until the map is back: the map loaded
## once, its window `boxes` times (-1: not counted).
func _mash_end(boxes: int) -> Dictionary:
	if not _in_level() and not await _mash_level_select(1):
		return _res(false, false, "no level entered (%s)" % (_stuck if _stuck != "" else _where()))
	await _refreshes(60)
	var l0: int = _loads()
	if not await _open_pause():
		return _res(false, false, _stuck)
	var ok: bool = false
	match GAMES[game].engine:
		"vorticons":
			ok = (await _list_open("pause", "cheats", "cheats")).completed and await _list_goto("cheats", "cheat:skip_level")
		"dreams":
			ok = await _d_open_list(4) and await _list_goto("cheats", "cheat:skip_level")
		"galaxy":
			var item: Object = _g_row_item("skip_level", ["once"])
			ok = item != null and await _g_follow(_g_path(_g_main(), item))
	if not ok:
		return _res(false, false, _stuck)
	await _press("accept")
	await _refreshes(12)
	match GAMES[game].engine:
		"vorticons":
			await _list_dismiss("cheats")    # "Level skipped"; the level ends once the menu is left
			await _leave_pause()
		"dreams":
			await _leave_pause()
		"galaxy":
			await _wait(_g_dialog, 3.0)
			await _press("accept")
			await _wait(func() -> bool: return not _g_dialog(), 3.0)
			await _g_to_main()
			await _g_resume_play()
	var b0: int = _boxes()    # (from here: the menus' own boxes, Keen 4-6's Control Panel and Dreams' Options Screen, not counted)
	var there: bool = await _mash(["accept"], 40.0, _on_map)
	await _refreshes(30)
	var dl: int = _loads() - l0
	var db: int = _boxes() - b0
	return _res(true, there and dl == 1 and (boxes < 0 or db == boxes), "%s; loaded %d (1 wanted), its window %d%s" % [
		"there" if there else "not there (%s)" % _where(), dl, db, "" if boxes < 0 else " (%d wanted)" % boxes])


# ------------------------------------------------------------------ the device

## The event a move makes on the walk's device (null: it cannot make it). On the launcher a touch is on a
## tile ("tile:<id>"); in a game on the on-screen controls.
func _event(move: String, down: bool) -> InputEvent:
	match device:
		"pad":
			if not PAD.has(move):
				return null
			var b: InputEventJoypadButton = InputEventJoypadButton.new()
			b.button_index = PAD[move]
			b.pressed = down
			b.pressure = 1.0 if down else 0.0
			b.device = 0
			return b
		"keys":
			var code: int = _keycode(move)
			if code == KEY_NONE:
				return null
			var k: InputEventKey = InputEventKey.new()
			k.keycode = code as Key
			k.physical_keycode = code as Key
			k.pressed = down
			return k
		"touch":
			var at: Variant = _touch_point(move)
			if at == null:
				return null
			var s: InputEventScreenTouch = InputEventScreenTouch.new()
			s.index = 0
			s.position = at
			s.pressed = down
			return s
	return null


func _keycode(move: String) -> int:
	if move.begins_with("code:"):
		return int(move.substr(5))
	if move.begins_with("char:"):
		return OS.find_keycode_from_string(move.substr(5))
	if move.begins_with("fkey:"):
		return OS.find_keycode_from_string("F" + move.substr(5))
	return int(KEYS.get(move, KEY_NONE))


## The Godot key a game's scan code comes from (KEY_NONE for none).
func _key_of_scancode(scancode: int) -> int:
	for k: int in ControlsModel.SCANCODES:
		if int(ControlsModel.SCANCODES[k]) == scancode and scancode != 0:
			return k
	return KEY_NONE


func _touch_point(move: String) -> Variant:
	if move.begins_with("tile:"):
		var tile: Control = l.tiles.get(move.substr(5))
		return tile.get_global_rect().get_center() if tile != null else null
	var h: GameHost = _host()
	if h == null or h.overlay == null or not h.overlay.visible or not TOUCH.has(move):
		return null
	var o: TouchOverlay = h.overlay
	var name: String = TOUCH[move]
	var p: Vector2 = Vector2.ZERO
	if name.begins_with("dpad:"):
		var r: Rect2 = o.dpad_rect()
		var dir: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[name.substr(5)]
		p = r.get_center() + dir * r.size.x / 3.0
	else:
		p = o.button_rect(name).get_center()
	return o.get_global_transform_with_canvas() * p


## Whether the device can make a move (touch: on the launcher only a tile; in a game the controls shown).
func _can(move: String) -> bool:
	match device:
		"pad":
			return PAD.has(move)
		"keys":
			return _keycode(move) != KEY_NONE
		"touch":
			return TOUCH.has(move) or move.begins_with("tile:")
	return false


func _say(move: String) -> String:
	if move.begins_with("char:"):
		return move.substr(5)
	if move.begins_with("fkey:"):
		return "F" + move.substr(5)
	return str((SAY[device] as Dictionary).get(move, move))


## A move pressed and let go: held for `hold` of the game's refreshes, then `gap` more (on the launcher
## the same in wall time). False, with where, when the device cannot make it.
func _press(move: String, hold: int = 7, gap: int = 8) -> bool:
	var down: InputEvent = _event(move, true)
	if down == null:
		_stuck = "the %s has no %s" % [device, _say(move)]
		return false
	Input.parse_input_event(down)
	await _refreshes(hold)
	var up: InputEvent = _event(move, false)
	if up == null:
		up = down.duplicate()
		up.set("pressed", false)
	Input.parse_input_event(up)
	await _refreshes(gap)
	if trace:
		print("    . %s -> %s (page '%s', row %d)" % [_say(move), _where(), _page(), _row()])
	return true


## A move held (walking on a map, a paddle).
func _hold(move: String, refreshes: int) -> bool:
	return await _press(move, refreshes, 6)


# ------------------------------------------------------------------ waiting, records

func _host() -> GameHost:
	return l.host if l != null and is_instance_valid(l.host) else null


func _eng() -> Object:
	var h: GameHost = _host()
	return h.engine if h != null else null


func _opts() -> OptionsModel:
	var h: GameHost = _host()
	return h.options if h != null else null


## The game reads its play controls (CTRL-02): the pad is then the player's bindings.
func _live() -> bool:
	var h: GameHost = _host()
	return h != null and h.engine != null and h.vm != null and h.controls_live()


func _focus() -> String:
	var f: Control = root.gui_get_focus_owner()
	return str(f.name) if f != null else "none"


func _vbl() -> int:
	var h: GameHost = _host()
	return h.vm.vbl_count if h != null and h.vm != null else -1


## Waits for `n` of the game's refreshes (on the launcher, as long in wall time).
func _refreshes(n: int) -> void:
	var start: int = _vbl()
	if start < 0:
		await _pause(maxf(n / 70.0, 0.05))
		return
	await _wait(func() -> bool: return _vbl() < 0 or _vbl() - start >= n, maxf(n / 35.0, 0.5))


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


## Waits for a condition, at most `seconds` (and never past the function's time limit).
func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	if _deadline > 0:
		until = mini(until, _deadline)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _pause(seconds: float) -> void:
	await _wait(func() -> bool: return false, seconds)


static func _res(reached: bool, completed: bool, note: String = "") -> Dictionary:
	return {"reached": reached, "completed": completed, "note": note}


## One function of the walk, within its time limit: run (after `ready`, which puts the walk where the
## function starts, when given), recorded, a check. A function that ran out of time says so.
func _fn(name: String, fn: Callable, seconds: float = 30.0, ready: Callable = Callable()) -> Dictionary:
	_stuck = ""
	_via = ""
	_deadline = Time.get_ticks_msec() + int(seconds * 1000.0)
	var r: Dictionary = {}
	if _host() == null and not name.begins_with("Launcher") and not name.begins_with("Back on the launcher"):
		r = _res(false, false, "the game had ended")
	else:
		if ready.is_valid() and _host() != null:
			await ready.call()
		r = await fn.call()
	if Time.get_ticks_msec() >= _deadline and not r.completed:
		r.note = "%s (its %d s ran out)" % [r.note, int(seconds)]
	if _via != "":
		r.note = _via if r.note == "" else "%s; %s" % [_via, r.note]
	_deadline = 0
	records.append({"game": game, "function": name, "device": device, "reached": r.reached, "completed": r.completed, "note": r.note})
	t.ok("%s by %s: %s%s" % [game, device, name, ": " + str(r.note) if r.note != "" else ""], r.completed)
	if r.completed:
		print("  ok    %s: %s%s" % [game, name, ": " + str(r.note) if r.note != "" else ""])
	return r


## The evidence: every function walked, as JSON.
func _write() -> void:
	var dir: String = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("harn09_mash.json" if mash else "harn09_walk.json")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("WALK could not write %s" % path)
		return
	f.store_string(JSON.stringify(records, "  "))
	f.close()
	print("WALK evidence: %s" % path)


func _summary() -> void:
	for g: String in games:
		var mine: Array = records.filter(func(r: Dictionary) -> bool: return r.game == g)
		var done: int = mine.filter(func(r: Dictionary) -> bool: return r.completed).size()
		print("WALK %s by %s: %d of %d functions completed" % [g, device, done, mine.size()])
		for r: Dictionary in mine:
			if not r.completed:
				print("WALK   %s %s: %s" % ["stuck at" if r.reached else "not reached:", r.function, r.note])


func _remove(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
