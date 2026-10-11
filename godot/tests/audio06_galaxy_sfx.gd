# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## AUDIO-06: Keen 4-6's AdLib effects in Keen 1-3. GalaxySounds finds every table sound in Keen 4 and 5's
## own data, and in Keen 5's alone (Keen 4 missing: each sound's second choice); an effect's writes are the
## instrument then a note a tick (140 Hz); played through the chip it sounds. In Keen 1 in the host with
## the setting on, a jump starts its Keen 4 effect and the speaker is silent; with it off, no effects.
## Headless, the same keys with the host's hook and without: the state hash equal at every frame, and each
## hook call made as the speaker's sequencer starts that very sound (the effect's frame is the speaker's).
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


## Keen 1 headless from its intro with `keys` (HARN-05a's runner); with `hook` the host's sound hook is set
## and each call is checked against the speaker's sequencer at that moment. {hashes, calls, in_step}.
func _headless(root: String, keys: String, seconds: float, hook: bool, plant: bool = false) -> Dictionary:
	var data: VortData = VortData.new()
	data.load_game(root.path_join("keen1"), "CK1")
	var vm: DosMachine = DosMachine.new()
	var g: VortKeen1 = VortKeen1.new()
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_audio06_%d" % Time.get_ticks_usec())
	for spec: String in keys.split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key_after("intro", float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	var hashes: PackedStringArray = PackedStringArray()
	var calls: Array = [0, 0]    # hook calls, of them made as the sequencer started that sound
	if hook:
		g.shell_sound_hook = func(playnum: int) -> void:
			calls[0] += 1
			if g.SndPtr == (playnum << 16):
				calls[1] += 1
			if plant:
				g.RndT()    # the planted fault: a hook that touches the game
	vm.on_display = func() -> void:
		if vm.card.video_mode == EgaCard.MODE_EGA:
			hashes.append(g.state_hash())
	vm.time_limit = DosMachine.seconds_to_units(seconds)
	vm.on_limit = func() -> void: g.exited = true
	g.main()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.shell_sound_hook = Callable()
	g.vm = null
	return {"hashes": hashes, "calls": calls[0], "in_step": calls[1]}


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	# headless: the hook changes nothing in the game, and fires as the speaker's sound starts
	var keys: String = "1.0:28:0.2,3.0:28:0.2,6.0:77:1.5,7.8:80:0.35,8.5:29:0.2,9.5:29:0.2,10.5:56:0.2,11.0:77:3.0,12.0:29:0.3,13.0:57:0.2,14.0:29:0.2"
	var off: Dictionary = _headless(root_dir, keys, 18.0, false)
	var on: Dictionary = _headless(root_dir, keys, 18.0, true)
	var first_diff: int = -1
	for i: int in range(mini(off.hashes.size(), on.hashes.size())):
		if off.hashes[i] != on.hashes[i]:
			first_diff = i
			break
	t.ok("headless, the same keys with the hook and without: the state hash equal at every frame (%d frames; first difference %d)" % [on.hashes.size(), first_diff],
		on.hashes.size() > 500 and on.hashes.size() == off.hashes.size() and first_diff < 0)
	t.ok("each hook call made as the speaker's sequencer starts that sound (%d of %d)" % [on.in_step, on.calls], on.calls > 2 and on.in_step == on.calls)
	var bad: Dictionary = _headless(root_dir, keys, 18.0, true, true)
	t.ok("a planted hook that draws a random number is caught", bad.hashes != off.hashes)
	print("  headless: %d frames, %d sounds started, the hash equal at every frame" % [on.hashes.size(), on.calls])
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
	# the tracks: every level of every game, from both and from Keen 5 alone (Keen 1 takes Keen 2's table)
	var no_track: Array = []
	for g: String in ["keen1", "keen2", "keen3"]:
		for lv: int in range(17):
			if both.music_for(g, lv).size() <= 6:
				no_track.append("%s:%d" % [g, lv])
			if five.music_for(g, lv).size() <= 6:
				no_track.append("k5 alone %s:%d" % [g, lv])
	t.ok("a track for every level of Keen 1-3, with both and with Keen 5 alone (missing %s)" % [no_track], no_track.is_empty())
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
		var mus: HostAudio = HostAudio.new()
		mus.play_music(0.0, both.music_for("keen1", 0))
		var mpeak: float = 0.0
		for v: Vector2 in mus.render(int(2.0 * HostAudio.RATE)):
			mpeak = maxf(mpeak, absf(v.x))
		t.ok("Keen 1's world map track sounds (peak %.3f, %d writes)" % [mpeak, mus.writes_applied], mpeak > 0.01)
		mus.close()
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
	host.options.step("galaxy_music", 1)
	await _wait(func() -> bool: return host.controls_live(), 30.0)
	t.ok("in level 1 its track plays (%d)" % host._music_level, await _wait(func() -> bool: return host._music_level == 1 and host.audio._mus_end > 6, 5.0))
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
