# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-06: in the host (Keen 1, real time), losing focus pauses the game
## (the machine's clock stops), mutes it and lets go of a held key (the
## game's own key table shows it up); regaining focus resumes from where it
## stopped (no time made up); a stall of two seconds is dropped but for one
## refresh (the game does not run fast to catch up).
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
	# hold Right, see the game's key table take it
	host.send_key(0x4D, true)
	var held: bool = await _wait(func() -> bool: return g.keydown.size() > 0x4D and g.keydown[0x4D] != 0, 3.0)
	t.ok("a held key reaches the game", held)
	# focus out: paused, muted, the key let go
	host._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _wait(func() -> bool: return false, 0.3)
	var m0: float = _machine(host)
	await _wait(func() -> bool: return false, 1.0)
	var m1: float = _machine(host)
	t.ok("paused: the machine's clock stops (%.3f s in 1 s)" % (m1 - m0), host.paused and m1 - m0 < 0.02)
	t.ok("paused: the sound stream is paused and \"Paused\" shows", host._player != null and host._player.stream_paused and
		host._paused_label != null and host._paused_label.visible)
	t.ok("paused: the held key is let go in the game (keydown %d)" % (g.keydown[0x4D] if g.keydown.size() > 0x4D else -1),
		g.keydown.size() > 0x4D and g.keydown[0x4D] == 0 and host._held.is_empty())
	# focus in: resumes from where it stopped
	host._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var w0: int = Time.get_ticks_msec()
	await _wait(func() -> bool: return false, 1.0)
	var m2: float = _machine(host)
	var wall: float = (Time.get_ticks_msec() - w0) / 1000.0
	t.ok("resumed: the clock runs on from the pause, nothing made up (%.3f s in %.3f s)" % [m2 - m1, wall],
		not host.paused and m2 - m1 > wall - 0.2 and m2 - m1 < wall + 0.05 and not host._paused_label.visible and not host._player.stream_paused)
	# a stall of two seconds (as if the host had not run the machine): at most one refresh made up
	var drops: int = host.stalls_dropped
	var m3: float = _machine(host)
	host._start_usec -= 2000000
	var w3: int = Time.get_ticks_msec()
	await _wait(func() -> bool: return false, 1.0)
	var m4: float = _machine(host)
	var wall2: float = (Time.get_ticks_msec() - w3) / 1000.0
	t.ok("a 2 s stall is dropped but for a refresh (%.3f s of machine time in %.3f s, %d drops)" % [m4 - m3, wall2, host.stalls_dropped - drops],
		host.stalls_dropped > drops and m4 - m3 < wall2 + 1.0 / 70.086 + 0.05 and m4 - m3 > wall2 - 0.2)
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	t.ok("stops cleanly", host.thread == null)
	host.queue_free()
	await process_frame
	t.finish(self)
