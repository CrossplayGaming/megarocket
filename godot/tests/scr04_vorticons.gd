# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SCR-04 (and SCR-03's Keen 1-3 routes): Keen 1-3's letter and digit questions answered by the pad alone,
## its buttons fed through the host as a player's pad reaches it (real time), and each still answered by its
## letter or digit key. Keen 1: the title's Quit (Y/N)? (B and No: nothing); Extras' Help (the F1 pages) on
## the title and in the pause menu; F4's Controller page and the pad's own way to it; F2's Sound (Y/N)? (No
## by the pad, B nothing, N and Y by key); Save Game's list (a position chosen by the pad: its file is the
## game's state; the positions marked Empty or with their score); Overwrite it? (B: nothing saved; Yes);
## Load Game's Leave this game (Y/N)? (B: still playing; Yes) and Continue Which Game? (the game loaded);
## Reset every control (Y/N)? (Yes: the controls back); Quit to (D)os or (T)itle (B: nothing; Title). Then
## the keys: N, 3 loads, F5 and 2 saves, N then Escape keeps the file, Y overwrites, Y and 2 load, T quits
## to the title; last, Quit (Y/N)? Yes by the pad ends the game. Then in a level (played in place) the
## pad's Start opens the pause menu (MENU-01). Headless (no player) the original's prompts are asked,
## never a list: F5's 1-9 answered by 4, the title's Quit answered by Y.
## With --smoke=1 (Keen 2 and 3): a save by the pad, loaded back by the pad, and Quit to the title.
##
## Options: --game_data=<folder> [--game=keen1|keen2|keen3] [--smoke=1] [--shots=<folder>]

var t: T = T.new()
var host: GameHost = null
var g: VortActs = null
var shots: String = ""
var game: String = "keen1"
var ext: String = "CK1"

const TITLEMAP: int = 90


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _pause(seconds: float) -> void:
	await _wait(func() -> bool: return false, seconds)


func _tap(code: Key) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.pressed = true
	host._input(k)
	await _pause(0.12)
	k = k.duplicate()
	k.pressed = false
	host._input(k)
	await _pause(0.2)


func _press(b: JoyButton) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	host._input(e)
	await _pause(0.12)
	e = e.duplicate()
	e.pressed = false
	host._input(e)
	await _pause(0.2)


func _presses(b: JoyButton, n: int) -> void:
	for i: int in range(n):
		await _press(b)


## A list (or the name entry) waiting on a question starting with `q`, and a moment more: the pad is the
## menus' keys once the game has stopped reading its play controls.
func _asked(q: String) -> bool:
	var up: bool = await _wait(func() -> bool: return g.shell_asking.begins_with(q), 5.0)
	if not up:
		print("  (waiting for \"%s\": asking \"%s\", page \"%s\", menu \"%s\", level %d)" % [q, g.shell_asking, g._menu_page, g.shell_menu_page, g.level])
	await _pause(0.25)
	return up


func _answered() -> bool:
	return await _wait(func() -> bool: return g.shell_asking == "", 3.0)


## The Options window on page `p` and reading the controls again (not inside a question it asked).
func _page(p: String) -> bool:
	var up: bool = await _wait(func() -> bool: return g.shell_menu_page == p and g.shell_asking == "" and host.controls_live(), 4.0)
	await _pause(0.3)
	return up


func _closed() -> bool:
	return await _wait(func() -> bool: return not g.shell_menu_open, 4.0)


func _slot(n: int) -> String:
	return g.save_dir.path_join("SAVED%d.%s" % [n, ext])


func _slot_score(n: int) -> int:
	var st: VortMain.GameState = VortMain.GameState.new()
	if not st.from_bytes(FileAccess.get_file_as_bytes(_slot(n))):
		return -1
	return st.score


## Back to the title's menu after a game is left: the game-over and score screens skipped with A, then one
## A on the title screen (never on the menu itself, which would start a game).
func _to_title_menu() -> bool:
	g._menu_page = ""
	for i: int in range(40):
		if g._menu_page == "main":
			await _pause(0.8)
			return true
		if g.level == TITLEMAP and g.originx == VortMain.X_TITLE and g.originy == VortMain.Y_TITLE:
			await _press(JOY_BUTTON_A)
			await _wait(func() -> bool: return g._menu_page == "main", 3.0)
			continue
		await _press(JOY_BUTTON_A)
		await _pause(0.6)
	return false


## A new game from the title's menu (New Game is its first row), on the world map.
func _new_game() -> bool:
	await _press(JOY_BUTTON_A)
	var on: bool = await _wait(func() -> bool: return g.shell_on_map and host.controls_live(), 25.0)
	await _pause(2.0)    # the Keens Left window's wait
	return on


func _shot(name: String) -> void:
	if shots == "":
		return
	var card: EgaCard = host.vm.card
	var px: PackedByteArray = card.frame_pixels.duplicate()
	var pal: PackedByteArray = card.frame_palette.duplicate()
	if px.size() != 64000 or pal.size() < 48:
		return
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(64000 * 3)
	for i: int in range(64000):
		var c: int = mini(px[i], pal.size() / 3 - 1) * 3
		rgb[i * 3] = pal[c]
		rgb[i * 3 + 1] = pal[c + 1]
		rgb[i * 3 + 2] = pal[c + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(shots.path_join("%s_%s.png" % [game, name]))


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	shots = T.options().get("shots", "")
	game = T.options().get("game", "keen1")
	ext = "CK" + game.substr(4, 1)
	var smoke: bool = T.options().get("smoke", "0") == "1"
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	if not smoke:
		_headless(root_dir)
	var cfg: String = OS.get_temp_dir().path_join("mr_scr04_%d.cfg" % Time.get_ticks_usec())
	var saves: String = OS.get_temp_dir().path_join("mr_scr04_%s_%d" % [game, Time.get_ticks_usec()])
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": game, "title": game, "version": "v1.31 EGA", "folder": root_dir.path_join(game)})
	g = host.engine
	g.save_dir = saves    # (the player's own saves left alone; read before the title's scores are)
	DirAccess.make_dir_recursive_absolute(saves)
	await _wait(func() -> bool: return host.frames_shown >= 30, 60.0)
	await _pause(2.0)
	await _press(JOY_BUTTON_A)    # past the intro: the title menu
	await _pause(2.5)
	if smoke:
		await _smoke()
	else:
		await _keen1()
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	if not smoke:
		await _start_in_level(root_dir, cfg, saves)
	for f: String in DirAccess.get_files_at(saves):
		DirAccess.remove_absolute(saves.path_join(f))
	DirAccess.remove_absolute(saves)
	DirAccess.remove_absolute(cfg)
	t.finish(self)


## MENU-01's Start: in a level (the first, played in place), the pad's Start opens the pause menu, B closes
## it and the level plays on.
func _start_in_level(root_dir: String, cfg: String, saves: String) -> void:
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": game, "title": game, "version": "v1.31 EGA", "folder": root_dir.path_join(game), "play_level": 1})
	g = host.engine
	g.save_dir = saves
	var playing: bool = await _wait(func() -> bool: return g.shell_in_level and host.controls_live(), 30.0)
	await _pause(1.0)
	await _press(JOY_BUTTON_START)
	t.ok("in a level the pad's Start opens the pause menu", playing and await _page("pause"))
	await _press(JOY_BUTTON_B)
	t.ok("B closes it, the level plays on", await _closed() and await _wait(func() -> bool: return g.shell_in_level and host.controls_live(), 3.0))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()


## The whole walk, Keen 1.
func _keen1() -> void:
	var m: ControlsModel = host.controls
	# the title's Quit (Y/N)?: B on the menu asks it; B answers nothing, A on No (where it starts) neither
	await _press(JOY_BUTTON_B)
	t.ok("title: B asks Quit (Y/N)? as a list", await _asked("Quit (Y/N)?"))
	await _shot("quit_yn")
	await _press(JOY_BUTTON_B)
	t.ok("title: B answers nothing", await _answered() and not g.exited)
	await _pause(0.8)
	await _press(JOY_BUTTON_B)
	await _asked("Quit (Y/N)?")
	await _press(JOY_BUTTON_A)
	t.ok("title: A on No (the caret's start) answers no", await _answered() and not g.exited)
	await _pause(0.8)

	# Extras' Help on the title: the F1 pages, closed with B, then B back to the main list
	await _presses(JOY_BUTTON_DPAD_DOWN, 5)
	await _press(JOY_BUTTON_A)
	await _wait(func() -> bool: return g._menu_page == "extras", 3.0)
	await _pause(0.8)
	var labels: Array = g._menu_rows().map(func(r: Dictionary) -> String: return r.label)
	t.eq("title Extras' rows, Help first", labels, ["Help", "Story", "About ID...", "Ordering Info", "Previews!", "Restart Demo", "Back"])
	await _shot("extras")
	g.textdataPtr = PackedByteArray()
	await _press(JOY_BUTTON_A)
	t.ok("title: Help shows the F1 pages", await _wait(func() -> bool: return g.textdataPtr == g.helptextPtr and g.textWindowMaxY == 20, 4.0))
	await _pause(0.5)
	await _shot("help")
	await _press(JOY_BUTTON_B)
	await _pause(1.0)
	await _press(JOY_BUTTON_B)
	t.ok("title: B closes the help, B again back to the main list", await _wait(func() -> bool: return g._menu_page == "main", 3.0))
	await _pause(1.0)

	if not t.ok("New Game by the pad: the world map", await _new_game()):
		return

	# F4's Controller page, and the same page by the pad alone: Start, Options..., Controls..., Controller...
	await _tap(KEY_F4)
	t.ok("F4 opens the Controller page", await _page("pad"))
	await _presses(JOY_BUTTON_B, 3)
	t.ok("B three times: back in play", await _closed())
	await _pause(0.5)
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _presses(JOY_BUTTON_DPAD_DOWN, 4)
	await _press(JOY_BUTTON_A)
	await _page("options")
	await _presses(JOY_BUTTON_DPAD_DOWN, 3)
	await _press(JOY_BUTTON_A)
	await _page("controls")
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_A)
	t.ok("the pad alone reaches the Controller page (Start, Options..., Controls..., Controller...)", await _page("pad"))
	await _presses(JOY_BUTTON_B, 4)
	await _closed()
	await _pause(0.5)

	# Help in the pause menu: Extras (up two from Resume) opens, Help works, the title's screens greyed
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _shot("pause")
	await _presses(JOY_BUTTON_DPAD_UP, 2)
	await _press(JOY_BUTTON_A)
	t.ok("pause: Extras... opens", await _page("extras"))
	var ex: Array = g._options_rows("extras")
	t.ok("pause Extras: Help can be chosen, the title's screens greyed", ex[0].key == "help" and ex[0].get("enabled", true)
		and not ex[1].get("enabled", true) and ex.back().key == "exit" and ex.back().get("enabled", true))
	await _shot("pause_extras")
	g.textdataPtr = PackedByteArray()
	await _press(JOY_BUTTON_A)
	t.ok("pause: Help shows the F1 pages", await _wait(func() -> bool: return g.textdataPtr == g.helptextPtr, 4.0))
	await _pause(0.5)
	await _shot("pause_help")
	await _press(JOY_BUTTON_B)
	await _pause(1.0)
	await _shot("pause_after_help")
	await _press(JOY_BUTTON_B)
	t.ok("pause: B closes the help, B again back to the pause menu", await _page("pause"))
	await _press(JOY_BUTTON_B)
	await _closed()
	await _pause(0.5)

	# F2's Sound (Y/N)?: the caret on Yes (the sound is on); down, A: off. B: nothing. N and Y by key
	t.eq("the sound is on to start with", g.soundmode, 1)
	await _tap(KEY_F2)
	await _asked("Sound (Y/N)?")
	await _shot("sound")
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_A)
	t.ok("F2: No by the pad turns the sound off", await _answered() and g.soundmode == 0)
	await _pause(0.4)
	await _tap(KEY_F2)
	await _asked("Sound (Y/N)?")
	await _press(JOY_BUTTON_B)
	t.ok("F2: B answers nothing", await _answered() and g.soundmode == 0)
	await _pause(0.4)
	await _tap(KEY_F2)
	await _asked("Sound (Y/N)?")
	await _tap(KEY_Y)
	t.ok("F2: Y by key turns it on", await _answered() and g.soundmode == 1)
	await _pause(0.4)
	await _tap(KEY_F2)
	await _asked("Sound (Y/N)?")
	await _tap(KEY_N)
	t.ok("F2: N by key turns it off", await _answered() and g.soundmode == 0)
	await _pause(0.4)

	# Save Game by the pad: the third position
	await _save_by_pad(40)
	# Overwrite it?: B saves nothing; Yes overwrites
	g.gamestate.score = 60
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _presses(JOY_BUTTON_DPAD_DOWN, 3)
	await _press(JOY_BUTTON_A)
	await _asked("Which game position")
	var rows: Array = g._shell_slot_rows()
	t.ok("the positions marked (%s, %s)" % [rows[0], rows[2]], rows[0] == "1  Empty" and rows[2] == "3  Score 40")
	await _presses(JOY_BUTTON_DPAD_DOWN, 2)
	await _press(JOY_BUTTON_A)
	t.ok("a used position asks Overwrite it?", await _asked("That game position"))
	await _shot("overwrite")
	await _press(JOY_BUTTON_B)
	await _answered()
	t.ok("Overwrite it?: B saves nothing (score %d)" % _slot_score(3), await _page("pause") and _slot_score(3) == 40)
	await _press(JOY_BUTTON_A)    # (the caret still on Save Game)
	await _asked("Which game position")
	await _presses(JOY_BUTTON_DPAD_DOWN, 2)
	await _press(JOY_BUTTON_A)
	await _asked("That game position")
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	t.ok("Overwrite it?: Yes by the pad overwrites (score %d)" % _slot_score(3), await _wait(func() -> bool: return _slot_score(3) == 60, 4.0))
	await _pause(0.5)
	await _press(JOY_BUTTON_A)    # You can continue this game... Press a key
	await _page("pause")
	await _press(JOY_BUTTON_B)
	await _closed()
	await _pause(0.5)

	# Load Game by the pad: Leave this game (Y/N)? B stays; Yes, then the list: the third position
	g.gamestate.score = 10
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _presses(JOY_BUTTON_DPAD_DOWN, 2)
	await _press(JOY_BUTTON_A)
	await _asked("Leave this game")
	await _shot("leave")
	await _press(JOY_BUTTON_B)
	t.ok("Leave this game: B stays in the game", await _answered() and g.shell_playing and await _page("pause"))
	await _press(JOY_BUTTON_A)
	await _asked("Leave this game")
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	t.ok("Leave this game: Yes by the pad leaves for the title's Continue Which Game?", await _asked("  Continue Which Game?"))
	await _shot("continue")
	await _press(JOY_BUTTON_A)    # the caret on the newest game: the third
	if not t.ok("the third game loaded by the pad (score %d)" % g.gamestate.score,
			await _wait(func() -> bool: return g.restoredGame and g.shell_on_map and g.gamestate.score == 60, 20.0)):
		return
	await _pause(2.0)

	# Reset every control (Y/N)?: Start, Options..., Controls..., Reset to defaults; up to Yes
	m.bind("keys", "jump", KEY_Q, 0)
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _presses(JOY_BUTTON_DPAD_DOWN, 4)
	await _press(JOY_BUTTON_A)
	await _page("options")
	await _presses(JOY_BUTTON_DPAD_DOWN, 3)
	await _press(JOY_BUTTON_A)
	await _page("controls")
	await _presses(JOY_BUTTON_DPAD_DOWN, 4)    # (Keyboard, Controller, Touch, Fire button: Reset)
	await _press(JOY_BUTTON_A)
	await _asked("Reset every control")
	await _shot("reset")
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	t.ok("Reset every control: Yes by the pad puts them back (jump %s)" % m.shown("keys", "jump"),
		await _wait(func() -> bool: return m.keys("jump") == [KEY_CTRL, KEY_Z], 3.0))
	await _pause(0.5)
	await _press(JOY_BUTTON_A)    # The controls are reset
	await _page("controls")
	await _presses(JOY_BUTTON_B, 3)
	await _closed()
	await _pause(0.5)

	# Quit to (D)os or (T)itle: B nothing; A on Title (where it starts)
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _press(JOY_BUTTON_DPAD_UP)    # (Resume up to Quit)
	await _press(JOY_BUTTON_A)
	t.ok("pause: Quit asks (D)os or (T)itle as a list", await _asked("Quit to (D)os"))
	await _shot("dos_title")
	await _press(JOY_BUTTON_B)
	t.ok("(D)os or (T)itle: B answers nothing", await _answered() and g.shell_playing and await _page("pause"))
	await _press(JOY_BUTTON_A)
	await _asked("Quit to (D)os")
	await _press(JOY_BUTTON_A)
	t.ok("(D)os or (T)itle: Title by the pad leaves the game, the program running",
		await _wait(func() -> bool: return g.resetgame or not g.shell_on_map, 5.0) and not g.exited)
	if not t.ok("back at the title's menu", await _to_title_menu()):
		return

	# the keys, as before: N answers the title's Quit; 3 loads; F5, 2 saves; 2, N, Escape keep it; Y overwrites
	await _tap(KEY_ESCAPE)
	await _asked("Quit (Y/N)?")
	await _tap(KEY_N)
	t.ok("keys: N answers the title's Quit (Y/N)?", await _answered() and not g.exited)
	await _pause(0.8)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _asked("  Continue Which Game?")
	await _tap(KEY_3)
	if not t.ok("keys: 3 loads the third game", await _wait(func() -> bool: return g.restoredGame and g.shell_on_map and g.gamestate.score == 60, 20.0)):
		return
	await _pause(2.0)
	await _tap(KEY_F5)
	await _asked("Which game position")
	await _tap(KEY_2)
	t.ok("keys: F5, 2 saves the second position", await _wait(func() -> bool: return FileAccess.file_exists(_slot(2)), 4.0)
		and FileAccess.get_file_as_bytes(_slot(2)) == g.gamestate.to_bytes())
	await _pause(0.4)
	await _tap(KEY_ENTER)    # You can continue this game...
	await _pause(0.6)
	g.gamestate.score = 70
	await _tap(KEY_F5)
	await _asked("Which game position")
	await _tap(KEY_2)
	await _asked("That game position")
	await _tap(KEY_N)
	t.ok("keys: N asks again", await _asked("Which game position"))
	await _tap(KEY_ESCAPE)
	t.ok("keys: Escape leaves, nothing saved", await _answered() and _slot_score(2) == 60)
	await _pause(0.6)
	await _tap(KEY_F5)
	await _asked("Which game position")
	await _tap(KEY_2)
	await _asked("That game position")
	await _tap(KEY_Y)
	t.ok("keys: Y overwrites", await _wait(func() -> bool: return _slot_score(2) == 70, 4.0))
	await _pause(0.4)
	await _tap(KEY_ENTER)
	await _pause(0.6)
	# Leave this game by Y, the second game by 2
	g.gamestate.score = 20
	await _tap(KEY_ESCAPE)
	await _page("pause")
	await _tap(KEY_DOWN)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _asked("Leave this game")
	await _tap(KEY_Y)
	await _asked("  Continue Which Game?")
	await _tap(KEY_2)
	t.ok("keys: Y leaves, 2 loads the second game", await _wait(func() -> bool: return g.restoredGame and g.shell_on_map and g.gamestate.score == 70, 20.0))
	await _pause(2.0)
	# T: to the title
	g.gamestate.score = 20
	await _tap(KEY_ESCAPE)
	await _page("pause")
	await _tap(KEY_UP)
	await _tap(KEY_ENTER)
	await _asked("Quit to (D)os")
	await _tap(KEY_T)
	t.ok("keys: T leaves for the title", await _wait(func() -> bool: return g.resetgame or not g.shell_on_map, 5.0) and not g.exited)
	await _to_title_menu()

	# last: the title's Quit (Y/N)? Yes by the pad (the Quit row: up from New Game) ends the game
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	await _asked("Quit (Y/N)?")
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	t.ok("title: Quit, Yes by the pad ends the game", await _wait(func() -> bool: return g.exited, 5.0))


## Save Game from the pause menu by the pad into the third position (down two from the first, empty one);
## the file is the game's state.
func _save_by_pad(score: int) -> void:
	g.gamestate.score = score
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _presses(JOY_BUTTON_DPAD_DOWN, 3)
	await _press(JOY_BUTTON_A)
	t.ok("pause: Save Game asks for a position as a list", await _asked("Which game position"))
	await _shot("save")
	await _presses(JOY_BUTTON_DPAD_DOWN, 2)
	await _press(JOY_BUTTON_A)
	var saved: bool = await _wait(func() -> bool: return FileAccess.file_exists(_slot(3)), 4.0)
	await _pause(0.3)
	t.ok("the third position saved by the pad (%d bytes, score %d): the game's state" % [FileAccess.get_file_as_bytes(_slot(3)).size(), _slot_score(3)],
		saved and FileAccess.get_file_as_bytes(_slot(3)) == g.gamestate.to_bytes() and _slot_score(3) == score)
	await _press(JOY_BUTTON_A)    # You can continue this game... Press a key
	await _page("pause")
	await _press(JOY_BUTTON_B)
	await _closed()
	await _pause(0.5)


## Keen 2 and 3: a new game, a save by the pad, loaded back by the pad, Quit to the title by the pad.
func _smoke() -> void:
	if not t.ok("%s: New Game by the pad: the world map" % game, await _new_game()):
		return
	await _save_by_pad(30)
	g.gamestate.score = 10
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _presses(JOY_BUTTON_DPAD_DOWN, 2)
	await _press(JOY_BUTTON_A)
	await _asked("Leave this game")
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	await _asked("  Continue Which Game?")
	await _press(JOY_BUTTON_A)
	t.ok("%s: the third game loaded by the pad (score %d)" % [game, g.gamestate.score],
		await _wait(func() -> bool: return g.restoredGame and g.shell_on_map and g.gamestate.score == 30, 20.0))
	await _pause(2.0)
	g.gamestate.score = 10
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_A)
	await _asked("Quit to (D)os")
	await _press(JOY_BUTTON_A)
	t.ok("%s: Title by the pad leaves the game" % game, await _wait(func() -> bool: return g.resetgame or not g.shell_on_map, 5.0) and not g.exited)
	t.ok("%s: back at the title's menu" % game, await _to_title_menu())


## No player at the controls (options null, as headless runs and the oracle comparisons): the original's
## prompts, never a list. F5's 1-9 answered by 4 on the map writes SAVED4; the title's Quit (Y/N)? by Y.
func _headless(root_dir: String) -> void:
	var d: VortData = VortData.new()
	if not d.load_game(root_dir.path_join(game), ext):
		t.blocked("%s: %s" % [game, d.error])
		return
	var vm: DosMachine = DosMachine.new()
	var e: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	e.vm = vm
	e.data = d
	e.save_dir = OS.get_temp_dir().path_join("mr_scr04_headless_%d" % Time.get_ticks_usec())
	var listed: Array = [false]
	vm.on_display = func() -> void:
		if e.shell_asking != "":
			listed[0] = true
	e.after_startup = func() -> void:
		e.canSave = true
		vm.add_key(vm.seconds() + 1.0, 0x05, 0.1)    # 4
		vm.add_key(vm.seconds() + 2.0, 0x1C, 0.1)    # You can continue... Press a key
		e.SaveMenu()
		e.level = TITLEMAP
		vm.add_key(vm.seconds() + 1.0, 0x15, 0.1)    # Y
		e.AskQuit()
	vm.time_limit = DosMachine.seconds_to_units(15.0)
	vm.on_limit = func() -> void:
		e.exited = true
	e.main()
	t.ok("headless: F5's 1-9 answered by 4 saved the fourth position", FileAccess.file_exists(e.save_dir.path_join("SAVED4." + ext)))
	t.ok("headless: the title's Quit (Y/N)? answered by Y quits (the control panel written as it leaves)",
		FileAccess.file_exists(e.save_dir.path_join("CTLPANEL." + ext)))
	t.ok("headless: the original's prompts, never a list", not listed[0])
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	e.after_startup = Callable()
	e.vm = null
	for f: String in DirAccess.get_files_at(e.save_dir):
		DirAccess.remove_absolute(e.save_dir.path_join(f))
	DirAccess.remove_absolute(e.save_dir)
