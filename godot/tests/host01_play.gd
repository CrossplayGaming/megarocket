# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## HOST-01: a game plays in real time from the launcher's host. The engine
## runs on its own thread, paced by the wall clock (Keen 4 at real time, Keen 1
## 20 times faster);
## the card's frames reach the screen side; keys the player presses reach
## the game (Keen 4: Escape opens the control panel, Q, Enter and Y quit, and the
## host reports the game's end); stopping from outside ends a game cleanly
## (Keen 1); Keen 4's AdLib music reaches the mixer and makes a signal; the
## launcher starts a game from its tile and is back when it
## ends (Keen 2); the threads are gone afterwards.
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


func _press(host: GameHost, code: int) -> void:
	host.send_key(code, true)
	await _wait(func() -> bool: return false, 0.12)
	host.send_key(code, false)
	await _wait(func() -> bool: return false, 1.5)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	# ---- Keen 4: play, then quit through the game's own menu
	var host: GameHost = GameHost.new()
	host.speed = 1.0    # real time: a key held for a moment, as a player would
	root.add_child(host)
	var ended: Array = [false, ""]
	host.finished.connect(func(m: String) -> void:
		ended[0] = true
		ended[1] = m)
	var ok: bool = host.start({"id": "keen4", "title": "Keen 4", "version": "v1.4 EGA", "folder": root_dir.path_join("keen4")})
	t.ok("Keen 4 starts on its thread (%s)" % host.error, ok)
	if ok:
		var shown: bool = await _wait(func() -> bool: return host.frames_shown >= 50, 120.0)
		t.ok("frames reach the screen side (%d made, %d shown)" % [host.frames_made, host.frames_shown], shown)
		# sound: the title's AdLib music reaches the mixer and makes a signal
		# (the intro is silent; the demo's music starts after the title, about 19 s in)
		await _wait(func() -> bool: return host.audio != null and host.audio.events.size() > 1000, 45.0)
		var a: HostAudio = host.audio
		var peak: float = 0.0
		if a != null and a.events.size() > 0:
			a.t = float(a.events[a.events.size() - 1][0])    # render where the music is (headless has no audio output)
			a._next = 0
			for v: Vector2 in a.render(8192):
				peak = maxf(peak, absf(v.x))
		t.ok("the game's AdLib writes reach the mixer (%d events, OPL %s) and make sound (peak %.3f)" %
			[a.events.size() if a != null else 0, a != null and a.opl != null, peak], a != null and a.events.size() > 1000 and a.opl != null and peak > 0.01)
		# keys: Escape until the control panel is up (the first may only skip the
		# intro), then Q (QUIT) and Y to confirm
		var g4: GalGame = host.engine
		for i: int in range(4):
			if g4.get("us_currentCard") != null and g4.get("us_cardStackIndex") == 0 and g4.game_in_progress == 0:
				break
			await _press(host, 0x01)
		var menu_up: bool = g4.get("us_currentCard") != null
		t.ok("Escape opens the control panel", menu_up)
		# a pad: A is jump (Ctrl), the stick's left is the left arrow, released past the deadzone
		host._keys.clear()
		var ab: InputEventJoypadButton = InputEventJoypadButton.new()
		ab.button_index = JOY_BUTTON_A
		ab.pressed = true
		host._input(ab)
		var st: InputEventJoypadMotion = InputEventJoypadMotion.new()
		st.axis = JOY_AXIS_LEFT_X
		st.axis_value = -0.9
		host._input(st)
		st.axis_value = -0.1
		host._input(st)
		t.ok("a pad's A and stick reach the game as Ctrl and the left arrow (%s)" % [host._keys], host._keys == [[0x1D, true], [0x4B, true], [0x4B, false]])
		host._keys.clear()
		var au: InputEventJoypadButton = InputEventJoypadButton.new()
		au.button_index = JOY_BUTTON_A
		au.pressed = false
		host._input(au)
		await _press(host, 0x10)    # Q: the selection to QUIT
		await _press(host, 0x1C)    # Enter: REALLY QUIT?
		await _press(host, 0x15)    # Y
		var gone: bool = await _wait(func() -> bool: return ended[0], 60.0)
		if not gone and host.engine != null:
			var g: GalGame = host.engine
			print("  debug: t=%.2f s, keys delivered %d of %d, card %s, command %d, quitting %s" % [host.vm.seconds(), host.vm._key_index, host.vm.key_events.size(),
				g.get("us_currentCard"), g.us_currentCommand, g.quitting])
		t.ok("Escape, Q, Enter, Y quit the game and the host reports its end (message '%s')" % ended[1], gone and ended[1] == "")
	if not ended[0]:
		host.stop()
		await _wait(func() -> bool: return ended[0], 30.0)
	host.queue_free()
	await process_frame

	# ---- Keen 1: play, then stop from outside
	var h1: GameHost = GameHost.new()
	h1.speed = 20.0
	root.add_child(h1)
	var ended1: Array = [false]
	h1.finished.connect(func(_m: String) -> void: ended1[0] = true)
	ok = h1.start({"id": "keen1", "title": "Keen 1", "version": "v1.31", "folder": root_dir.path_join("keen1")})
	t.ok("Keen 1 starts on its thread (%s)" % h1.error, ok)
	if ok:
		var shown1: bool = await _wait(func() -> bool: return h1.frames_shown >= 30, 120.0)
		t.ok("Keen 1's frames reach the screen side (%d)" % h1.frames_shown, shown1)
		h1.stop()
		var gone1: bool = await _wait(func() -> bool: return ended1[0], 60.0)
		t.ok("stopping from outside ends the game and its thread", gone1 and h1.thread == null and h1.engine == null)
	h1.queue_free()
	await process_frame
	# ---- from the launcher: a found tile starts the game; when it ends the launcher is back
	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.lock_path = OS.get_temp_dir().path_join("mr_lock_%d" % Time.get_ticks_usec())
	l.make_art = false
	root.add_child(l)
	await process_frame
	l.show_results([{"id": "keen2", "title": "Commander Keen 2", "version": "v1.31 EGA (Steam)", "status": "ok", "folder": root_dir.path_join("keen2"), "message": "", "exe": "KEEN2.EXE"}])
	var started: bool = l.launch("keen2")
	var playing: bool = started and l.host != null and not l._page.visible
	if started:
		l.host.speed = 20.0
		await _wait(func() -> bool: return l.host.frames_shown >= 20, 120.0)
		l.host.stop()
	var back: bool = await _wait(func() -> bool: return l.host == null and l._page.visible, 60.0)
	t.ok("the launcher starts Keen 2 from its tile (playing %s) and is back when it ends (%s); a missing game's tile starts nothing (%s)" %
		[playing, back, not l.launch("keen5")], playing and back and not l.launch("keen5"))
	l.queue_free()
	await process_frame
	# ---- a game whose engine isn't ready says so
	var h2: GameHost = GameHost.new()
	root.add_child(h2)
	t.ok("Keen Dreams says its engine isn't ready (%s)" % h2.error, not h2.start({"id": "kdreams", "title": "Keen Dreams", "folder": ""}) and h2.error != "")
	h2.queue_free()
	await process_frame
	t.finish(self)
