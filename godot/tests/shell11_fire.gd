# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-11 and CTRL-02: the host's controls in Keen 1 (real time, a level). The game reads the player's
## bindings (ControlsModel): Fire's keys (Space, Shift) hold both buttons, the original's fire, with the
## Fire button row at Left Shift... "Own button"; at Two keys they do nothing. The pad, while the game reads
## its play controls, is the bindings (A jump, X and the right trigger fire, Back the status screen); in a
## menu it is Enter and Escape. The shoulders quicksave (F7) and quickload (F9). A key rebound is the
## action at once, and a key taken away does nothing. F11 moves the game's Fullscreen row. The intro, a
## screen and not play, is shown as the 320x200 picture in the frame (REND-08).
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _key(host: GameHost, code: Key, down: bool) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.pressed = down
	host._input(k)


func _button(host: GameHost, b: JoyButton, down: bool) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	host._input(e)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_shell11_%d.cfg" % Time.get_ticks_usec())
	# first the intro (not play): a screen in the frame, and the pad is the menus' keys
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1")})
	t.ok("Keen 1 starts (%s)" % host.error, ok)
	if not ok:
		t.finish(self)
		return
	await _wait(func() -> bool: return host.frames_shown >= 30, 60.0)
	t.ok("the intro is a screen: the 320x200 picture, framed (%s)" % host._backdrop.frame_rect,
		host._view.visible and host._backdrop.frame_rect.size.x > 0.0)
	t.ok("in the intro the game is not reading its play controls", not host.controls_live())
	var g0: VortActs = host.engine
	_button(host, JOY_BUTTON_A, true)
	t.ok("there the pad's A is Enter", await _wait(func() -> bool: return g0.keydown[0x1C] == 1, 3.0))
	_button(host, JOY_BUTTON_A, false)
	await _wait(func() -> bool: return g0.keydown[0x1C] == 0, 3.0)
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()

	# then a level
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1"), "play_level": 1})
	var g: VortActs = host.engine
	t.ok("in a level the game reads its play controls", await _wait(func() -> bool: return host.controls_live(), 30.0))
	var c: Callable = func() -> Dictionary: return g._shell_control()
	var buttons: Callable = func(b1: bool, b2: bool) -> bool: return c.call().button1 == b1 and c.call().button2 == b2
	_key(host, KEY_SHIFT, true)
	t.ok("Shift (Fire) holds both buttons: the original's fire", await _wait(func() -> bool: return buttons.call(true, true), 3.0))
	_key(host, KEY_SHIFT, false)
	t.ok("and lets go", await _wait(func() -> bool: return buttons.call(false, false), 3.0))
	_key(host, KEY_SPACE, true)
	t.ok("Space is Fire too", await _wait(func() -> bool: return buttons.call(true, true), 3.0))
	_key(host, KEY_SPACE, false)
	await _wait(func() -> bool: return buttons.call(false, false), 3.0)
	_button(host, JOY_BUTTON_A, true)
	t.ok("the pad's A is Jump alone", await _wait(func() -> bool: return buttons.call(true, false), 3.0))
	_button(host, JOY_BUTTON_A, false)
	t.ok("and lets go", await _wait(func() -> bool: return buttons.call(false, false), 3.0))
	_button(host, JOY_BUTTON_X, true)
	t.ok("the pad's X fires", await _wait(func() -> bool: return buttons.call(true, true), 3.0))
	_button(host, JOY_BUTTON_X, false)
	await _wait(func() -> bool: return buttons.call(false, false), 3.0)
	var rt: InputEventJoypadMotion = InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	host._input(rt)
	t.ok("the right trigger fires", await _wait(func() -> bool: return buttons.call(true, true), 3.0))
	rt.axis_value = 0.0
	host._input(rt)
	t.ok("and lets go", await _wait(func() -> bool: return buttons.call(false, false), 3.0))
	_button(host, JOY_BUTTON_BACK, true)
	t.ok("Back is the status screen", await _wait(func() -> bool: return g.shell_held("status"), 3.0))
	_button(host, JOY_BUTTON_BACK, false)
	await _wait(func() -> bool: return not g.shell_held("status"), 3.0)
	# SAVE-02 (the user's choice): the left shoulder quicksaves (F7), the right quickloads (F9)
	for pair: Array in [[JOY_BUTTON_LEFT_SHOULDER, 0x41], [JOY_BUTTON_RIGHT_SHOULDER, 0x43]]:
		_button(host, pair[0], true)
		var held: bool = host._held.has(pair[1])
		_button(host, pair[0], false)
		t.ok("the %s shoulder is %s" % ["left" if pair[0] == JOY_BUTTON_LEFT_SHOULDER else "right", "F7 (quicksave)" if pair[1] == 0x41 else "F9 (quickload)"],
			held and not host._held.has(pair[1]))
	# a key rebound is the action at once; a key taken from an action does nothing
	host.controls.bind("keys", "jump", KEY_Q, 0)
	host.controls.clear("keys", "pogo")
	host.apply_setting("controls")
	_key(host, KEY_Q, true)
	t.ok("Q given to Jump jumps", await _wait(func() -> bool: return buttons.call(true, false), 3.0))
	_key(host, KEY_Q, false)
	await _wait(func() -> bool: return buttons.call(false, false), 3.0)
	_key(host, KEY_ALT, true)
	await _wait(func() -> bool: return false, 0.4)
	t.ok("Alt, taken from Pogo, does nothing", buttons.call(false, false) and g.keydown[0x38] == 1)
	_key(host, KEY_ALT, false)
	var f11: InputEventKey = InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	var was: bool = bool(host.options.get_value("fullscreen"))
	host._input(f11)
	t.ok("F11 moves the game's Fullscreen row (%s -> %s)" % [was, host.options.get_value("fullscreen")], bool(host.options.get_value("fullscreen")) != was)
	host.options.step("fullscreen", 1)
	host.options.step("one_button_fire", 1)
	await _wait(func() -> bool: return not g.shell_one_fire, 2.0)
	_key(host, KEY_SHIFT, true)
	await _wait(func() -> bool: return false, 0.5)
	t.ok("with Two keys, Fire's keys fire nothing", buttons.call(false, false))
	_key(host, KEY_SHIFT, false)
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
