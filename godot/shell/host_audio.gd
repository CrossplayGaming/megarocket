# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name HostAudio
extends RefCounted
## The sound of a game being played (HOST-02): the AdLib register writes and
## PC speaker changes the machine made, each with its machine time, turned
## into samples at the OPL's own rate. The OPL is d2opl (NATIVE-01); the
## speaker is a square wave at the timer's frequency. Samples are made on the
## screen side as the audio output asks for them; an event is applied when
## the audio clock reaches its time, so the sound follows the game a fixed
## latency behind. Not the oracle's measure of sound (AUDIO units); a way to
## hear the game.

const RATE: int = 49716
const PIT_HZ: float = 1193182.0

var opl: Object = null
var events: Array = []        # [seconds, kind (0 opl, 1 speaker), a, b], in time order
var _next: int = 0
var t: float = 0.0            # the audio clock, seconds of machine time
var _spk_freq: float = 0.0
var _spk_phase: float = 0.0
var opl_volume: float = 0.6
var speaker_volume: float = 0.2
var writes_applied: int = 0


func _init() -> void:
	if ClassDB.class_exists("D2Opl"):
		opl = ClassDB.instantiate("D2Opl")


func close() -> void:
	if opl != null:
		opl.free()
		opl = null


func push_opl(at: float, reg: int, value: int) -> void:
	events.append([at, 0, reg, value])


## count: the speaker's timer divisor, 0 for off.
func push_speaker(at: float, count: int) -> void:
	events.append([at, 1, count, 0])


## Moves the audio clock to `to` without sound, applying what fell due (the
## registers keep their state; a speaker tone is left as it stands).
func skip_to(to: float) -> void:
	while _next < events.size() and float(events[_next][0]) <= to:
		var e: Array = events[_next]
		_next += 1
		if e[1] == 0:
			if opl != null:
				opl.write(e[2], e[3])
			writes_applied += 1
		else:
			_spk_freq = PIT_HZ / float(e[2]) if e[2] > 0 else 0.0
	t = maxf(t, to)


## n stereo frames from the audio clock on.
func render(n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var dt: float = 1.0 / RATE
	for i: int in range(n):
		while _next < events.size() and float(events[_next][0]) <= t:
			var e: Array = events[_next]
			_next += 1
			if e[1] == 0:
				if opl != null:
					opl.write(e[2], e[3])
				writes_applied += 1
			else:
				_spk_freq = PIT_HZ / float(e[2]) if e[2] > 0 else 0.0
		var s: float = 0.0
		if opl != null:
			s = float(opl.sample()) / 32768.0 * opl_volume
		if _spk_freq > 0.0:
			_spk_phase = fmod(_spk_phase + _spk_freq * dt, 1.0)
			s += speaker_volume if _spk_phase < 0.5 else -speaker_volume
		out[i] = Vector2(s, s)
		t += dt
	if _next > 4096:
		events = events.slice(_next)
		_next = 0
	return out
