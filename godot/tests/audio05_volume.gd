# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## AUDIO-05: music and effects volume scale the output and persist; with no
## audio device a game still runs. On scripted AdLib notes (an effect on
## channel 0, music on channel 1): music at full and effects at 0 sounds
## exactly as the music alone, effects alone the same, both at half is
## exactly half of both at full; the speaker (an effect) scales with the
## effects volume; the volumes saved in the settings reach a game the host
## starts; under the dummy audio driver (headless) the game runs. The output
## keeps sound in hand through stalls the machine drops (a phone's hitches):
## a run of them refills it with one short gap instead of running it dry.
##
## Options: --game_data=<folder>

var t: T = T.new()

const SHARED: Array = [[0x01, 0x20]]
# an instrument and a key-on on channel 0 (operator slots 0 and 3)
const FX: Array = [[0x20, 0x01], [0x23, 0x01], [0x40, 0x10], [0x43, 0x00], [0x60, 0xF0], [0x63, 0xF0],
	[0x80, 0x77], [0x83, 0x77], [0xE0, 0x00], [0xE3, 0x00], [0xC0, 0x00], [0xA0, 0x98], [0xB0, 0x31]]
# the same on channel 1 (slots 1 and 4), another note
const MUSIC: Array = [[0x21, 0x02], [0x24, 0x01], [0x41, 0x10], [0x44, 0x00], [0x61, 0xF0], [0x64, 0xF0],
	[0x81, 0x77], [0x84, 0x77], [0xE1, 0x00], [0xE4, 0x00], [0xC1, 0x00], [0xA1, 0x41], [0xB1, 0x32]]


func _init() -> void:
	_go.call_deferred()


func _render(writes: Array, music: float, effects: float, n: int = 4096) -> PackedVector2Array:
	var a: HostAudio = HostAudio.new()
	a.configure(music, effects)
	for w: Array in SHARED + writes:
		a.push_opl(0.001, w[0], w[1])
	var out: PackedVector2Array = a.render(n)
	a.close()
	return out


func _peak(s: PackedVector2Array) -> float:
	var p: float = 0.0
	for v: Vector2 in s:
		p = maxf(p, absf(v.x))
	return p


func _same(a: PackedVector2Array, b: PackedVector2Array, k: float = 1.0) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if absf(a[i].x - b[i].x * k) > 1e-6:
			return false
	return true


func _go() -> void:
	t.ok("the OPL is there (NATIVE-01)", ClassDB.class_exists("D2Opl"))
	var music_only: PackedVector2Array = _render(MUSIC, 1.0, 1.0)
	var fx_only: PackedVector2Array = _render(FX, 1.0, 1.0)
	t.ok("both notes sound (music peak %.3f, effect peak %.3f)" % [_peak(music_only), _peak(fx_only)], _peak(music_only) > 0.01 and _peak(fx_only) > 0.01)
	t.ok("music full, effects 0: exactly the music alone", _same(_render(FX + MUSIC, 1.0, 0.0), music_only))
	t.ok("effects full, music 0: exactly the effect alone", _same(_render(FX + MUSIC, 0.0, 1.0), fx_only))
	var both: PackedVector2Array = _render(FX + MUSIC, 1.0, 1.0)
	t.ok("both at half: exactly half of both at full", _same(_render(FX + MUSIC, 0.5, 0.5), both, 0.5))
	t.ok("music at 0.3, effects at 0.7: the sum of each scaled", _same(_render(FX + MUSIC, 0.3, 0.7),
		_mix(music_only, 0.3, fx_only, 0.7)))
	t.ok("channel 0's registers are the effects', the shared ones both's",
		HostAudio.is_effects_register(0xB0) and HostAudio.is_effects_register(0x43) and not HostAudio.is_effects_register(0xB1) and
		not HostAudio.is_effects_register(0x44) and HostAudio.is_shared_register(0xBD) and HostAudio.is_shared_register(0x01))
	# the speaker is an effect
	for pair: Array in [[0.0, 0.0], [0.5, 0.1], [1.0, 0.2]]:
		var a: HostAudio = HostAudio.new()
		a.configure(1.0, pair[0])
		a.push_speaker(0.0, 1193)
		var pk: float = _peak(a.render(2000))
		a.close()
		t.ok("the speaker at effects %.1f: peak %.3f (want %.3f)" % [pair[0], pk, pair[1]], absf(pk - pair[1]) < 1e-6)
	# the volumes persist and reach a game
	var dir: String = OS.get_temp_dir().path_join("mr_audio05_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var sp: String = dir.path_join("settings.cfg")
	var s: Settings = Settings.new(sp)
	s.set_value("music_volume", 30)
	s.set_value("effects_volume", 70)
	s.set_value("effects_volume", 10, "keen1")
	t.ok("saved", s.save())
	var r: Settings = Settings.new(sp)
	t.ok("read back (music %s, effects %s, Keen 1's effects %s)" % [r.get_value("music_volume"), r.get_value("effects_volume"), r.get_value("effects_volume", "keen1")],
		r.get_value("music_volume") == 30 and r.get_value("effects_volume") == 70 and r.get_value("effects_volume", "keen1") == 10)
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var host: GameHost = GameHost.new()
	host.speed = 20.0
	host.settings_path = sp
	root.add_child(host)
	var ok: bool = host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1")})
	t.ok("the game gets the saved volumes (music %.2f, effects %.2f, two chips %s)" % [host.audio.music_volume, host.audio.effects_volume, host.audio.opl_fx != null],
		ok and is_equal_approx(host.audio.music_volume, 0.3) and is_equal_approx(host.audio.effects_volume, 0.1) and host.audio.opl_fx != null)
	var until: int = Time.get_ticks_msec() + 20000
	while host.frames_made < 50 and Time.get_ticks_msec() < until:
		await process_frame
	t.ok("with no audio device (driver %s) the game runs (%d frames)" % [AudioServer.get_driver_name(), host.frames_made], host.frames_made >= 50)
	t.ok("in hand at the latency, no refill", GameHost.audio_refill(0.10, 0.02) == 0 and GameHost.audio_refill(0.041, 0.0) == 0)
	t.ok("near empty, refilled to the latency (%d frames)" % GameHost.audio_refill(0.0, 0.005),
		absi(GameHost.audio_refill(0.0, 0.005) - int(0.115 * HostAudio.RATE)) <= 1)
	var dry: Array = [_stalls(false), _stalls(true)]
	t.ok("ten seconds at 60 frames with a 30 ms stall dropped every half second: the output ran dry in %d frames, %d with the refill" % dry,
		dry[0] >= 10 and dry[1] == 0)
	host.stop()
	while host.thread != null and Time.get_ticks_msec() < until + 10000:
		await process_frame
	host.queue_free()
	await process_frame
	t.finish(self)


## Frames (of 600) in which the output ran dry: each frame it plays 1/60 s; the machine gains 1/60 s
## but every 30th frame loses a 30 ms stall (_pace drops it); the host renders up to the machine's time.
func _stalls(refill: bool) -> int:
	var held: float = 0.0
	var ready: float = GameHost.AUDIO_LATENCY
	var dry: int = 0
	for f: int in range(600):
		if refill:
			held += float(GameHost.audio_refill(held, ready)) / HostAudio.RATE
		held += ready
		ready = 0.0
		held -= 1.0 / 60.0
		if held < 0.0:
			dry += 1
			held = 0.0
		ready = 1.0 / 60.0 - (0.03 if f % 30 == 29 else 0.0)
		ready = maxf(ready, 0.0)
	return dry


func _mix(a: PackedVector2Array, ka: float, b: PackedVector2Array, kb: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(a.size())
	for i: int in range(a.size()):
		out[i] = a[i] * ka + b[i] * kb
	return out
