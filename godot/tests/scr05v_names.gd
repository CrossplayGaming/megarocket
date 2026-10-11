# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SCR-05 (Keen 1-3's part): a high-score name entered by the pad alone, through the host as a player's pad
## reaches it (real time), and read back from the score file. A game is left with a score that earns first
## place (the score set in the game's state); at "Enter your name:" the d-pad spells KEEN (up and down turn
## the letter, right keeps it, left drops the letter shown and then takes back the last one) and A keeps the
## letter shown and ends: SCORES.CKn has KEEN first. Keen 1 also: the keyboard types ZAX, Backspace, Q,
## Enter: ZAQ second (typing unchanged); the pad spells OK and B ends it as the original's Escape does
## (what was kept is kept): OK third. Headless (no player) the original's Input: typed AB, Enter.
##
## Options: --game_data=<folder> [--game=keen1|keen2|keen3] [--shots=<folder>]

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
	await _pause(0.1)
	k = k.duplicate()
	k.pressed = false
	host._input(k)
	await _pause(0.15)


func _press(b: JoyButton) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	host._input(e)
	await _pause(0.1)
	e = e.duplicate()
	e.pressed = false
	host._input(e)
	await _pause(0.15)


func _presses(b: JoyButton, n: int) -> void:
	for i: int in range(n):
		await _press(b)


func _asked(q: String) -> bool:
	var up: bool = await _wait(func() -> bool: return g.shell_asking.begins_with(q), 8.0)
	await _pause(0.25)
	return up


func _page(p: String) -> bool:
	var up: bool = await _wait(func() -> bool: return g.shell_menu_page == p and g.shell_asking == "" and host.controls_live(), 4.0)
	await _pause(0.3)
	return up


## The score table as the file has it.
func _scores() -> VortMain.HighScores:
	var h: VortMain.HighScores = VortMain.HighScores.new()
	h.from_bytes(FileAccess.get_file_as_bytes(g.save_dir.path_join("SCORES." + ext)))
	return h


## Back to the title's menu: the score screen skipped with A, then one A on the title screen.
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


## A new game from the title's menu with `score`, left at once (Start, Quit, Title): the name asked.
func _game_over_with(score: int) -> bool:
	await _press(JOY_BUTTON_A)    # New Game
	if not await _wait(func() -> bool: return g.shell_on_map and host.controls_live(), 25.0):
		return false
	await _pause(2.0)
	g.gamestate.score = score
	await _press(JOY_BUTTON_START)
	await _page("pause")
	await _press(JOY_BUTTON_DPAD_UP)    # (Resume up to Quit)
	await _press(JOY_BUTTON_A)
	await _asked("Quit to (D)os")
	await _press(JOY_BUTTON_A)    # Title
	return await _asked("name")


## The d-pad's turns from no letter shown to `c`: up from A, or down from the end of SHELL_LETTERS.
func _spell(word: String) -> void:
	for ch: String in word:
		var i: int = VortLib.SHELL_LETTERS.find(ch)
		await _presses(JOY_BUTTON_DPAD_UP, i + 1)
		await _press(JOY_BUTTON_DPAD_RIGHT)


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
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	if game == "keen1":
		_headless(root_dir)
	var cfg: String = OS.get_temp_dir().path_join("mr_scr05v_%d.cfg" % Time.get_ticks_usec())
	var saves: String = OS.get_temp_dir().path_join("mr_scr05v_%s_%d" % [game, Time.get_ticks_usec()])
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": game, "title": game, "version": "v1.31 EGA", "folder": root_dir.path_join(game)})
	g = host.engine
	g.save_dir = saves    # (the player's own scores left alone; read before the title's are)
	DirAccess.make_dir_recursive_absolute(saves)
	await _wait(func() -> bool: return host.frames_shown >= 30, 60.0)
	await _pause(2.0)
	await _press(JOY_BUTTON_A)    # past the intro: the title menu
	await _pause(2.5)
	await _walk()
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	for f: String in DirAccess.get_files_at(saves):
		DirAccess.remove_absolute(saves.path_join(f))
	DirAccess.remove_absolute(saves)
	DirAccess.remove_absolute(cfg)
	t.finish(self)


func _walk() -> void:
	# KEEN by the pad: K, E; then C shown, left drops it, left takes back the E; F then down to E, kept;
	# E; N shown and A keeps it and ends
	if not t.ok("%s: a first-place score asks the name" % game, await _game_over_with(50000)):
		return
	await _shot("name")
	await _spell("KE")
	await _presses(JOY_BUTTON_DPAD_UP, 3)
	await _shot("name_shown")
	await _press(JOY_BUTTON_DPAD_LEFT)
	await _press(JOY_BUTTON_DPAD_LEFT)
	await _presses(JOY_BUTTON_DPAD_UP, 6)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _spell("E")
	await _presses(JOY_BUTTON_DPAD_UP, VortLib.SHELL_LETTERS.find("N") + 1)
	await _shot("name_n")
	await _press(JOY_BUTTON_A)
	var ok: bool = await _wait(func() -> bool: return g.shell_asking == "" and FileAccess.file_exists(g.save_dir.path_join("SCORES." + ext)) and _scores().scores[0] == 50000, 5.0)
	var h: VortMain.HighScores = _scores()
	t.ok("%s: KEEN by the pad is first in SCORES.%s (%s, %d)" % [game, ext, h.names[0], h.scores[0]], ok and h.names[0] == "KEEN")
	if game != "keen1":
		return
	t.ok("back at the title's menu", await _to_title_menu())

	# typed: ZAX, Backspace, Q, Enter: ZAQ second
	if not t.ok("a second-place score asks the name", await _game_over_with(40000)):
		return
	for k: Key in [KEY_Z, KEY_A, KEY_X, KEY_BACKSPACE, KEY_Q, KEY_ENTER]:
		await _tap(k)
	ok = await _wait(func() -> bool: return g.shell_asking == "" and _scores().scores[1] == 40000, 5.0)
	h = _scores()
	t.ok("typing unchanged: ZAX, Backspace, Q, Enter is ZAQ second (%s)" % h.names[1], ok and h.names[1] == "ZAQ" and h.names[0] == "KEEN")
	await _to_title_menu()

	# OK by the pad, then B: kept as typed (the original's Escape)
	if not t.ok("a third-place score asks the name", await _game_over_with(30000)):
		return
	await _spell("OK")
	await _press(JOY_BUTTON_B)
	ok = await _wait(func() -> bool: return g.shell_asking == "" and _scores().scores[2] == 30000, 5.0)
	h = _scores()
	t.ok("B ends the name as Escape does, keeping OK third (%s)" % h.names[2], ok and h.names[2] == "OK")


## No player at the controls: the original's Input (typed AB, Enter), never the d-pad's.
func _headless(root_dir: String) -> void:
	var d: VortData = VortData.new()
	if not d.load_game(root_dir.path_join(game), ext):
		t.blocked("%s: %s" % [game, d.error])
		return
	var vm: DosMachine = DosMachine.new()
	var e: VortActs = VortKeen1.new()
	e.vm = vm
	e.data = d
	var got: Array = []
	var asked: Array = [false]
	vm.on_display = func() -> void:
		if e.shell_asking != "":
			asked[0] = true
	e.after_startup = func() -> void:
		vm.add_key(vm.seconds() + 0.5, 0x48, 0.1)    # up: nothing in the original
		vm.add_key(vm.seconds() + 1.0, 0x1E, 0.1)    # A
		vm.add_key(vm.seconds() + 1.5, 0x30, 0.1)    # B
		vm.add_key(vm.seconds() + 2.0, 0x1C, 0.1)    # Enter
		got.append_array(e.Input(12))
		e.exited = true
	vm.time_limit = DosMachine.seconds_to_units(10.0)
	vm.on_limit = func() -> void:
		e.exited = true
	e.main()
	t.ok("headless: the original's Input: AB (%s), up ignored" % [got], got == [1, "AB"] and not asked[0])
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	e.after_startup = Callable()
	e.vm = null
