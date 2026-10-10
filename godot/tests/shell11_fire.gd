# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-11: the host's added controls (Keen 1, real time). One-button fire (J-06, on by default): Left
## Shift presses jump and pogo together (Ctrl and Alt) and lets go of both; the pad's X and its right
## trigger do the same; Back is the status screen (Space); with the Fire button row at Two keys, Left
## Shift fires nothing. F11 moves the game's Fullscreen row. The intro, a screen and not play, is shown
## as the 320x200 picture in the frame (REND-08).
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


func _shift(host: GameHost, down: bool) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = KEY_SHIFT
	k.location = KEY_LOCATION_LEFT
	k.pressed = down
	host._input(k)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_shell11_%d.cfg" % Time.get_ticks_usec())
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
	var g: VortActs = host.engine
	var both: Callable = func(v: int) -> bool: return g.keydown[0x1D] == v and g.keydown[0x38] == v
	t.ok("the intro is a screen: the 320x200 picture, framed (%s)" % host._backdrop.frame_rect,
		host._view.visible and host._backdrop.frame_rect.size.x > 0.0)
	_shift(host, true)
	t.ok("Left Shift presses jump and pogo together", await _wait(func() -> bool: return both.call(1), 3.0))
	_shift(host, false)
	t.ok("and lets go of both", await _wait(func() -> bool: return both.call(0), 3.0))
	var x: InputEventJoypadButton = InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	host._input(x)
	t.ok("the pad's X fires", await _wait(func() -> bool: return both.call(1), 3.0))
	x.pressed = false
	host._input(x)
	await _wait(func() -> bool: return both.call(0), 3.0)
	var rt: InputEventJoypadMotion = InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	host._input(rt)
	t.ok("the right trigger fires", await _wait(func() -> bool: return both.call(1), 3.0))
	rt.axis_value = 0.0
	host._input(rt)
	t.ok("and lets go", await _wait(func() -> bool: return both.call(0), 3.0))
	var back: InputEventJoypadButton = InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	host._input(back)
	t.ok("Back is the status screen's Space", await _wait(func() -> bool: return g.keydown[0x39] == 1, 3.0))
	back.pressed = false
	host._input(back)
	await _wait(func() -> bool: return g.keydown[0x39] == 0, 3.0)
	var f11: InputEventKey = InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	var was: bool = bool(host.options.get_value("fullscreen"))
	host._input(f11)
	t.ok("F11 moves the game's Fullscreen row (%s -> %s)" % [was, host.options.get_value("fullscreen")], bool(host.options.get_value("fullscreen")) != was)
	host.options.step("fullscreen", 1)
	host.options.step("one_button_fire", 1)
	await _wait(func() -> bool: return not host._one_fire, 2.0)
	_shift(host, true)
	await _wait(func() -> bool: return false, 0.5)
	t.ok("with Two keys, Left Shift fires nothing", both.call(0))
	_shift(host, false)
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
