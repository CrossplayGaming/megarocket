# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CTRL-05: Keen Dreams' control panel, its Controls subject (v1.93 in the host, real time). The keyboard
## button (F3) opens Megarocket's Keyboard list in the panel's box: each action and its keys (no Pogo, Fire
## is Throw), Reset all controls, Back; Jump's own list; Change catches Q (the game never sees it) and the
## help line says so; Escape goes back. The controller button (F4, usable with no joystick) opens the
## Controller list, walked with the pad alone, and a button caught for Status. Pictures to --shots.
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
	await _pause(0.25)


func _press(b: JoyButton) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	host._input(e)
	await _pause(0.12)
	e = e.duplicate()
	e.pressed = false
	host._input(e)
	await _pause(0.25)


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
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(shots.path_join(name + ".png"))


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	shots = T.options().get("shots", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_ctrl05_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "kdreams", "title": "Keen Dreams", "version": "v1.93", "folder": root_dir.path_join("kdreams193")})
	t.ok("Keen Dreams starts (%s)" % host.error, ok)
	if not ok:
		t.finish(self)
		return
	var g: Object = host.engine
	var m: ControlsModel = host.controls
	await _pause(2.0)
	await _tap(KEY_ENTER)    # the text start screen
	await _pause(5.0)
	await _tap(KEY_ENTER)    # the title: the control panel
	await _pause(2.0)
	await _tap(KEY_C)        # Controls
	await _pause(1.0)
	await _tap(KEY_F3)       # the keyboard button
	await _pause(1.0)
	await _shot("ctrl05_keys")
	var rows: Array = host.options.page("keys").map(func(r: Dictionary) -> String: return r.label)
	t.eq("the Keyboard list's actions (Dreams: no Pogo, Fire is Throw)", rows, ["Up", "Down", "Left", "Right", "Jump", "Throw", "Status", "Back"])
	for i: int in range(4):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)    # Jump's list
	await _pause(0.4)
	await _shot("ctrl05_jump")
	await _tap(KEY_ENTER)    # Change
	t.ok("Change: the capture waits for a key", await _wait(func() -> bool: return str(g.get("controls_capture")) == "keys", 3.0))
	await _shot("ctrl05_capture")
	await _tap(KEY_Q)
	t.ok("Q caught for Jump (%s)" % m.shown("keys", "jump"), await _wait(func() -> bool: return m.keys("jump") == [KEY_Q, KEY_CTRL], 3.0))
	await _pause(0.5)
	await _shot("ctrl05_after")
	t.ok("the game never saw Q", not bool(g.Keyboard[0x10]))
	await _tap(KEY_ESCAPE)   # out of the list, back to the panel
	await _pause(0.8)
	await _tap(KEY_F4)       # the controller button
	await _pause(1.0)
	await _shot("ctrl05_pad")
	t.ok("the Controller list is open", await _wait(func() -> bool: return host.controls_live(), 3.0))
	for i: int in range(2):
		await _press(JOY_BUTTON_DPAD_DOWN)    # Jump, Throw, Status
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_A)
	t.ok("the pad alone reaches a button's capture", await _wait(func() -> bool: return str(g.get("controls_capture")) == "pad", 3.0))
	await _press(JOY_BUTTON_RIGHT_STICK)
	t.ok("the right stick's button caught for Status (%s)" % m.shown("pad", "status"),
		await _wait(func() -> bool: return m.buttons("status") == [JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_Y], 3.0))
	await _press(JOY_BUTTON_B)    # back out of the list
	await _pause(0.5)
	t.ok("out of the list, the panel's own again", not host.controls_live())
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
