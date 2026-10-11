# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CTRL-03: Keen 1-3's Controls pages, walked in Keen 1 (real time, a level) with the keys and with the
## pad. F3 opens the Keyboard page; Jump's page changes its key: the capture takes the next key (the game
## never sees it), says it, and the game jumps with it at once; a key taken from another action says so;
## Clear empties an action; Escape cancels a capture. F4 opens the Controller page, walked with the pad
## alone (the d-pad, A, B), and a button caught for Status. Reset to defaults asks and puts them back.
## Every page fits its window.
##
## Options: --game_data=<folder> [--shots=<folder>]

var t: T = T.new()
var host: GameHost = null
var shots: String = ""


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
	await _pause(0.12)


func _press(b: JoyButton) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	host._input(e)
	await _pause(0.12)
	e = e.duplicate()
	e.pressed = false
	host._input(e)
	await _pause(0.15)


## Back a page at a time (Escape, or the pad's B) until the game is playing again: never one more, which
## would reach the game (its quit question).
func _leave(pad: bool) -> bool:
	for i: int in range(6):
		await _pause(0.3)
		if host.controls_live() and not _in_menu():
			return true
		if pad:
			await _press(JOY_BUTTON_B)
		else:
			await _tap(KEY_ESCAPE)
	return false


## The Options window open: the game reads its controls there too, so its own stack says.
func _in_menu() -> bool:
	return host.engine.get("shell_menu_open") == true


func _shot(name: String) -> void:
	if shots == "":
		return
	var card: EgaCard = host.vm.card
	var px: PackedByteArray = card.frame_pixels.duplicate()    # (the engine's thread draws on)
	var pal: PackedByteArray = card.frame_palette.duplicate()
	if px.size() != 320 * 200 or pal.size() < 48:
		return
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(320 * 200 * 3)
	for i: int in range(320 * 200):
		var c: int = mini(px[i], pal.size() / 3 - 1) * 3
		rgb[i * 3] = pal[c]
		rgb[i * 3 + 1] = pal[c + 1]
		rgb[i * 3 + 2] = pal[c + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(shots.path_join(name + ".png"))


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	shots = T.options().get("shots", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_ctrl03_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1"), "play_level": 1})
	var g: VortActs = host.engine
	t.ok("Keen 1 in a level", await _wait(func() -> bool: return host.controls_live(), 30.0))
	var c: Callable = func() -> Dictionary: return g._shell_control()
	var m: ControlsModel = host.controls

	# every page fits the window
	var fits: bool = true
	for p: String in ["controls", "keys", "pad", "touch", "bindact:keys:jump", "bindact:pad:fire"]:
		var rows: Array = host.options.page(p)
		if rows.size() > VortScreens.OPTIONS_H:
			fits = false
		for r: Dictionary in rows:
			if 3 + str(r.label).length() + (1 + str(r.get("value", "")).length() if r.kind == "value" else 0) > VortScreens.OPTIONS_W:
				fits = false
	t.ok("every Controls page fits the Options window", fits)

	# F3: the Keyboard page; down to Jump (Up, Down, Left, Right, Jump), Enter: its page; Enter: Change
	await _tap(KEY_F3)
	await _pause(0.5)
	await _shot("ctrl03_keys")
	for i: int in range(4):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _pause(0.3)
	await _shot("ctrl03_jump")
	await _tap(KEY_ENTER)
	t.ok("Change: the capture waits for a key", await _wait(func() -> bool: return g.controls_capture == "keys", 3.0))
	await _shot("ctrl03_capture")
	await _tap(KEY_Q)
	t.ok("Q caught for Jump, first (%s)" % m.shown("keys", "jump"), await _wait(func() -> bool: return m.keys("jump") == [KEY_Q, KEY_CTRL], 3.0))
	t.ok("the game never saw Q", g.keydown[0x10] == 0)
	await _pause(0.3)
	await _tap(KEY_ENTER)    # the word said; back to the list
	await _shot("ctrl03_after")
	await _leave(false)    # up to Controls, to Options, and out
	var k: InputEventKey = InputEventKey.new()
	k.keycode = KEY_Q
	k.pressed = true
	host._input(k)
	t.ok("in play Q jumps at once", await _wait(func() -> bool: return c.call().button1 and not c.call().button2, 3.0))
	k = k.duplicate()
	k.pressed = false
	host._input(k)
	await _pause(0.3)

	# Pogo's page: Change, X... a key taken from another action: Space from Fire
	await _tap(KEY_F3)
	await _pause(0.4)
	for i: int in range(5):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _tap(KEY_ENTER)
	await _wait(func() -> bool: return g.controls_capture == "keys", 3.0)
	await _tap(KEY_SPACE)
	t.ok("Space given to Pogo, taken from Fire (pogo %s, fire %s)" % [m.shown("keys", "pogo"), m.shown("keys", "fire")],
		await _wait(func() -> bool: return m.keys("pogo") == [KEY_SPACE, KEY_ALT] and m.keys("fire") == [KEY_SHIFT], 3.0))
	await _tap(KEY_ENTER)
	await _pause(0.5)
	# Fire's page (down one): Clear (Change, Add second, Clear)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _tap(KEY_DOWN)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	t.ok("Clear: Fire has no keys", await _wait(func() -> bool: return m.keys("fire").is_empty(), 3.0))
	await _tap(KEY_ENTER)
	await _pause(0.5)
	# Status's page: Change, then Escape: nothing changes
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _tap(KEY_ENTER)
	await _wait(func() -> bool: return g.controls_capture == "keys", 3.0)
	await _tap(KEY_ESCAPE)
	t.ok("Escape cancels: Status keeps Enter", await _wait(func() -> bool: return g.controls_capture == "" and m.keys("status") == [KEY_ENTER], 3.0))
	await _tap(KEY_ENTER)
	await _leave(false)

	# F4: the Controller page, with the pad alone: down three to Status (Jump, Pogo, Fire, Status), A, A: capture
	await _tap(KEY_F4)
	await _pause(0.5)
	await _shot("ctrl03_pad")
	for i: int in range(3):
		await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_A)
	t.ok("the pad alone reaches a button's capture", await _wait(func() -> bool: return g.controls_capture == "pad", 3.0))
	await _press(JOY_BUTTON_RIGHT_STICK)
	t.ok("the right stick's button caught for Status (%s)" % m.shown("pad", "status"),
		await _wait(func() -> bool: return m.buttons("status") == [JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_Y], 3.0))
	await _press(JOY_BUTTON_A)
	await _leave(true)    # back out of Options with B

	# Reset to defaults (Controls page: Keyboard, Controller, Touch (J-54), Fire button, Reset)
	await _tap(KEY_F3)
	await _pause(0.4)
	await _tap(KEY_ESCAPE)    # from the Keyboard page up to Controls
	await _pause(0.3)
	await _shot("ctrl03_controls")
	for i: int in range(4):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _pause(0.3)
	await _tap(KEY_Y)
	t.ok("Reset to defaults asks, then puts every control back",
		await _wait(func() -> bool: return m.keys("jump") == [KEY_CTRL, KEY_Z] and m.keys("fire") == [KEY_SPACE, KEY_SHIFT] and m.buttons("status") == [JOY_BUTTON_Y, JOY_BUTTON_BACK], 3.0))
	await _tap(KEY_ENTER)
	t.ok("out of Options, back in play", await _leave(false))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
