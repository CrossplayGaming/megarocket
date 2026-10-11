# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-15: the controller on the launcher, with real controller events as the device sends them
## (Input.parse_input_event): the d-pad and left stick move between the tiles (Godot's own ui_* actions
## hold them), A starts the focused tile's game and Start does too, B asks to quit, and in the quit box
## the d-pad moves between Quit and Stay, B stays, A presses the focused button; the how-to page's Back
## takes A; a second controller (device 1) works the same. Godot 4.7's built-in ui_accept and ui_cancel
## hold no controller buttons (the user, 2026-10-10: only the sticks did anything).
##
## Options: --game_data=<folder>

var t: T = T.new()
var l: Launcher = null


func _init() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _owner() -> String:
	var f: Control = root.gui_get_focus_owner()
	return str(f.name) if f != null else "none"


func _button(b: JoyButton, device: int = 0) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		e.device = device
		Input.parse_input_event(e)
		await _frames(3)


func _stick(axis: JoyAxis, value: float, device: int = 0) -> void:
	for v: float in [value, 0.0]:
		var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = v
		e.device = device
		Input.parse_input_event(e)
		await _frames(3)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	root.size = Vector2i(1280, 720)
	l = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = OS.get_temp_dir().path_join("mr_lock15_%d" % Time.get_ticks_usec())
	l.settings_path = OS.get_temp_dir().path_join("mr_shell15_%d.cfg" % Time.get_ticks_usec())
	root.add_child(l)
	await _frames(3)
	l.show_results([{"id": "keen1", "title": "Commander Keen 1", "version": "v1.31 EGA", "status": "ok", "folder": root_dir.path_join("keen1"), "message": "", "exe": "KEEN1.EXE"}])
	await _frames(3)
	(l.tiles["keen1"] as Control).grab_focus()
	await _frames(2)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	t.eq("the d-pad moves between the tiles", _owner(), "keen2")
	await _stick(JOY_AXIS_LEFT_X, -1.0)
	t.eq("the left stick too", _owner(), "keen1")
	# B: the quit box; the d-pad in it; B stays
	await _button(JOY_BUTTON_B)
	t.ok("B asks to quit (Stay chosen first: %s)" % _owner(), l.quit_box != null and _owner() == "Stay")
	await _button(JOY_BUTTON_DPAD_LEFT)
	t.eq("the d-pad in the quit box: Quit", _owner(), "Quit")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_B, 1)
	t.ok("B (from a second controller) stays: the box gone, the Quit button focused (%s)" % _owner(), l.quit_box == null and _owner() == "Quit")
	# A on the quit box's Stay presses it
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_A)
	t.ok("A presses the focused Stay: the box gone", l.quit_box == null)
	# the how-to page: its Back button takes A
	l.show_howto()
	await _frames(3)
	t.ok("the how-to page open, Back focused (%s)" % _owner(), l.howto != null and _owner() == "Back")
	await _button(JOY_BUTTON_A)
	t.ok("A presses Back: the page closed", l.howto == null)
	# A on a tile starts its game; Start too
	(l.tiles["keen1"] as Control).grab_focus()
	await _frames(2)
	await _button(JOY_BUTTON_A, 1)
	t.ok("A (device 1) on Keen 1's tile starts the game", await _wait(func() -> bool: return l.host != null and l.host.thread != null, 20.0))
	if l.host != null:
		l.host.stop()
		await _wait(func() -> bool: return l.host == null, 15.0)
	t.ok("back on the launcher after the game", l.host == null and l._page.visible)
	(l.tiles["keen1"] as Control).grab_focus()
	await _frames(2)
	await _button(JOY_BUTTON_START)
	t.ok("Start on the tile starts it too", await _wait(func() -> bool: return l.host != null and l.host.thread != null, 20.0))
	if l.host != null:
		l.host.stop()
		await _wait(func() -> bool: return l.host == null, 15.0)
	l.queue_free()
	await _frames(2)
	t.finish(self)
