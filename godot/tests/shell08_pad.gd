# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-08: in the host (Keen 1, real time), the pad being played with
## unplugged mid-game pauses it (the clock stops) with a prompt and lets go
## of its held button; a key resumes (and is not played); unplugged again,
## plugging it back in resumes; another pad coming or going changes nothing.
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


func _machine(host: GameHost) -> float:
	host._mutex.lock()
	var m: float = host._machine_t
	host._mutex.unlock()
	return m


func _clock_stopped(host: GameHost) -> bool:
	await _wait(func() -> bool: return false, 0.3)
	var m0: float = _machine(host)
	await _wait(func() -> bool: return false, 0.7)
	return _machine(host) - m0 < 0.02


func _clock_runs(host: GameHost) -> bool:
	var m0: float = _machine(host)
	await _wait(func() -> bool: return false, 0.7)
	return _machine(host) - m0 > 0.4


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var host: GameHost = GameHost.new()
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1")})
	t.ok("Keen 1 starts (%s)" % host.error, ok)
	if not ok:
		t.finish(self)
		return
	await _wait(func() -> bool: return host.frames_shown >= 30, 60.0)
	var g: VortActs = host.engine
	# play with pad 0: hold A (jump, Ctrl)
	var a: InputEventJoypadButton = InputEventJoypadButton.new()
	a.device = 0
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	host._input(a)
	var held: bool = await _wait(func() -> bool: return g.keydown.size() > 0x1D and g.keydown[0x1D] != 0, 3.0)
	t.ok("the pad's A reaches the game (pad %d)" % host.pad_device, held and host.pad_device == 0)
	# another pad going away changes nothing
	Input.joy_connection_changed.emit(1, false)
	t.ok("another pad unplugged: still playing", not host.paused and await _clock_runs(host))
	# pad 0 unplugged: paused, says so, A let go
	Input.joy_connection_changed.emit(0, false)
	var stopped: bool = await _clock_stopped(host)
	t.ok("the pad unplugged: paused, the clock stops", host.paused and host.pad_paused and stopped)
	t.ok("the prompt says so", host._paused_label != null and host._paused_label.visible and host._paused_label.text == GameHost.PAD_GONE_TEXT)
	t.ok("its held button is let go in the game", g.keydown[0x1D] == 0)
	# focus coming back does not resume a pad pause
	host._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	t.ok("focus back alone does not resume it", host.paused)
	# a key resumes, and is not played
	var k: InputEventKey = InputEventKey.new()
	k.keycode = KEY_SPACE
	k.pressed = true
	host._input(k)
	var runs: bool = await _clock_runs(host)
	t.ok("a key goes on (and is not played: Space %d)" % g.keydown[0x39], not host.paused and runs and g.keydown[0x39] == 0 and not host._paused_label.visible)
	# unplugged again, then plugged back in
	Input.joy_connection_changed.emit(0, false)
	await _wait(func() -> bool: return false, 0.3)
	t.ok("unplugged again: paused", host.paused)
	Input.joy_connection_changed.emit(0, true)
	t.ok("plugged back in: goes on", not host.paused and await _clock_runs(host))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	var before: int = Input.joy_connection_changed.get_connections().size()
	host.queue_free()
	await process_frame
	var after: int = Input.joy_connection_changed.get_connections().size()
	t.ok("the host lets go of the pad signal when it leaves (%d connections, then %d)" % [before, after], after == before - 1)
	t.finish(self)
