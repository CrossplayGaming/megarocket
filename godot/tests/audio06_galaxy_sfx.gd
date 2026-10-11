# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## AUDIO-06: Keen 4-6's AdLib effects in Keen 1-3. GalaxySounds finds every table sound in Keen 4 and 5's
## own data, and in Keen 5's alone (Keen 4 missing: each sound's second choice); an effect's writes are the
## instrument then a note a tick (140 Hz); played through the chip it sounds. In Keen 1 in the host with
## the setting on, a jump starts its Keen 4 effect and the speaker is silent; with it off, no effects.
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


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var both: GalaxySounds = GalaxySounds.new()
	both.load({"keen4": root_dir.path_join("keen4"), "keen5": root_dir.path_join("keen5")})
	var missing: Array = []
	for name: String in GalaxySounds.TABLE:
		if both.sound_for(name).size() <= 23:
			missing.append(name)
	t.ok("Keen 4 and 5: every table sound found (missing %s)" % [missing], both.available() and missing.is_empty())
	var five: GalaxySounds = GalaxySounds.new()
	five.load({"keen5": root_dir.path_join("keen5")})
	missing = []
	for name: String in GalaxySounds.TABLE:
		if five.sound_for(name).size() <= 23:
			missing.append(name)
	t.ok("Keen 5 alone: every table sound found from it (missing %s)" % [missing], five.available() and missing.is_empty())
	var none: GalaxySounds = GalaxySounds.new()
	none.load({})
	t.ok("neither: not available", not none.available())

	var jump: PackedByteArray = both.sound_for("KEENJUMPSND")
	var w: Array = GalaxySounds.writes(jump, 1.0)
	var length: int = jump.decode_u32(0)
	var notes: Array = w.filter(func(e: Array) -> bool: return e[1] == 0xA0)
	t.ok("Keen 4's jump: the instrument's ten writes at once, then its notes a tick apart (%d of %d bytes)" % [notes.size(), length],
		w.slice(1, 11).all(func(e: Array) -> bool: return is_equal_approx(float(e[0]), 1.0)) and notes.size() > 0 and notes.size() <= length
		and is_equal_approx(float(notes[0][0]), 1.0 + 1.0 / 140.0))
	var audio: HostAudio = HostAudio.new()
	if audio.opl != null:
		audio.play_sfx(0.0, GalaxySounds.writes(jump, 0.0))
		var peak: float = 0.0
		for v: Vector2 in audio.render(int(0.3 * HostAudio.RATE)):
			peak = maxf(peak, absf(v.x))
		t.ok("played through the chip it sounds (peak %.3f)" % peak, peak > 0.01)
	audio.close()

	# Keen 1 in the host: a jump's effect, the speaker silent
	var cfg: String = OS.get_temp_dir().path_join("mr_audio05_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	host.galaxy_folders = {"keen4": root_dir.path_join("keen4"), "keen5": root_dir.path_join("keen5")}
	root.add_child(host)
	host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1"), "play_level": 1})
	t.ok("the Sound page's row is there and usable", host.options.galaxy_available
		and host.options.page("sound").any(func(r: Dictionary) -> bool: return r.key == "galaxy_sfx" and r.get("enabled", true)))
	host.options.step("galaxy_sfx", 1)
	await _wait(func() -> bool: return host.controls_live(), 30.0)
	var spk: Array = []
	var before: int = host.audio.sfx.size()
	var k: InputEventKey = InputEventKey.new()
	k.keycode = KEY_CTRL
	k.pressed = true
	host._input(k)
	t.ok("a jump: its Keen 4 effect is played", await _wait(func() -> bool: return host.audio.sfx.size() > before, 3.0))
	k = k.duplicate()
	k.pressed = false
	host._input(k)
	await _wait(func() -> bool: return false, 0.6)
	for e: Array in host.audio.events:
		if e[1] == 1:
			spk.append(e[2])
	t.ok("and the speaker silent (%d speaker events, all off)" % spk.size(), spk.all(func(c: int) -> bool: return c == 0))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
