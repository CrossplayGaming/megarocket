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
## AUDIO-06: music and effects have their own volume (the settings' 0-100,
## here 0-1). The speaker is effects. On the AdLib, id's sound effects play
## on channel 0 and the music on the others, so when the two volumes differ
## the writes are split by channel between two chips (the registers every
## channel shares go to both) and each chip is scaled by its own volume;
## when they are equal one chip is scaled by both.

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
var music_volume: float = 1.0
var effects_volume: float = 1.0
var opl_fx: Object = null      # the effects' chip, only while the volumes differ
## AUDIO-06: Keen 4-6's AdLib effects under Keen 1-3 ([seconds, register, value], in time order): a track of
## their own, since an effect is written ahead and a new one cuts the rest of the one sounding.
var sfx: Array = []
var _sfx_next: int = 0
var _sfx_ready: bool = false
## AUDIO-06, the tracks: Keen 4-5's music under Keen 1-3, played as it goes (Galaxy's 560 Hz, looping); a
## change waits for its time ([seconds, chunk] queued; an empty chunk: silence).
var _mus: PackedByteArray = PackedByteArray()
var _mus_pos: int = 0
var _mus_end: int = 0
var _mus_due: float = 0.0
var _mus_queue: Array = []


func _init() -> void:
	if ClassDB.class_exists("D2Opl"):
		opl = ClassDB.instantiate("D2Opl")


## The volumes (0-1), set before the first event.
func configure(music: float, effects: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	effects_volume = clampf(effects, 0.0, 1.0)
	if music_volume != effects_volume and opl != null and opl_fx == null:
		opl_fx = ClassDB.instantiate("D2Opl")


func close() -> void:
	if opl != null:
		opl.free()
		opl = null
	if opl_fx != null:
		opl_fx.free()
		opl_fx = null


## Channel 0's registers: its frequency, key-on and feedback, and its two
## operators' (slots 0 and 3).
static func is_effects_register(reg: int) -> bool:
	if reg == 0xA0 or reg == 0xB0 or reg == 0xC0:
		return true
	for base: int in [0x20, 0x40, 0x60, 0x80, 0xE0]:
		if reg == base or reg == base + 3:
			return true
	return false


## The registers all channels share (test, waveform enable, CSM/note select, rhythm).
static func is_shared_register(reg: int) -> bool:
	return reg == 0x01 or reg == 0x04 or reg == 0x08 or reg == 0xBD


func _opl_write(reg: int, value: int) -> void:
	if opl == null:
		return
	if opl_fx == null:
		opl.write(reg, value)
	elif is_shared_register(reg):
		opl.write(reg, value)
		opl_fx.write(reg, value)
	elif is_effects_register(reg):
		opl_fx.write(reg, value)
	else:
		opl.write(reg, value)


func push_opl(at: float, reg: int, value: int) -> void:
	events.append([at, 0, reg, value])


## AUDIO-06: an effect from `at` (GalaxySounds.writes): what is left of the one before it is dropped.
func play_sfx(at: float, writes: Array) -> void:
	var keep: Array = sfx.slice(_sfx_next).filter(func(e: Array) -> bool: return float(e[0]) < at)
	if not _sfx_ready:
		# the chip as id_sd.c sets it up: the waveforms enabled, no rhythm
		keep.append([at, 0x01, 0x20])
		keep.append([at, 0xBD, 0])
		_sfx_ready = true
	sfx = keep + writes
	_sfx_next = 0


## AUDIO-06: a track from `at` (an empty chunk stops the music).
func play_music(at: float, chunk: PackedByteArray) -> void:
	_mus_queue.append([at, chunk])


func _apply_music(to: float) -> void:
	while not _mus_queue.is_empty() and float(_mus_queue[0][0]) <= to:
		var q: Array = _mus_queue.pop_front()
		for ch: int in range(1, 9):
			_opl_write(0xB0 + ch, 0)    # the one before let go (channels 1-8: music's; 0 is the effects')
		_mus = q[1]
		_mus_pos = 2
		_mus_end = mini(2 + (_mus.decode_u16(0) if _mus.size() >= 2 else 0), _mus.size())
		_mus_due = float(q[0])
		if not _sfx_ready:
			_opl_write(0x01, 0x20)
			_opl_write(0xBD, 0)
			_sfx_ready = true
	if _mus_end <= 6:
		return
	var guard: int = 0
	while _mus_due <= to and guard < 100000:
		guard += 1
		if _mus_pos + 4 > _mus_end:
			_mus_pos = 2    # round again, as Galaxy's
		var delay: int = _mus.decode_u16(_mus_pos + 2)
		_opl_write(_mus[_mus_pos], _mus[_mus_pos + 1])
		_mus_pos += 4
		_mus_due += float(delay) / GalaxySounds.MUSIC_RATE


func _apply_sfx(to: float) -> void:
	while _sfx_next < sfx.size() and float(sfx[_sfx_next][0]) <= to:
		var e: Array = sfx[_sfx_next]
		_sfx_next += 1
		_opl_write(e[1], e[2])


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
			_opl_write(e[2], e[3])
			writes_applied += 1
		else:
			_spk_freq = PIT_HZ / float(e[2]) if e[2] > 0 else 0.0
	_apply_sfx(to)
	_apply_music(to)
	t = maxf(t, to)


## n stereo frames from the audio clock on. hold: the chips and the speaker sound on as they stand, no
## event applied and the clock not moved (the host fills a wait for the machine with it).
func render(n: int, hold: bool = false) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var dt: float = 1.0 / RATE
	for i: int in range(n):
		while not hold and _next < events.size() and float(events[_next][0]) <= t:
			var e: Array = events[_next]
			_next += 1
			if e[1] == 0:
				_opl_write(e[2], e[3])
				writes_applied += 1
			else:
				_spk_freq = PIT_HZ / float(e[2]) if e[2] > 0 else 0.0
		if not hold and _sfx_next < sfx.size():
			_apply_sfx(t)
		if not hold and (_mus_end > 6 or not _mus_queue.is_empty()):
			_apply_music(t)
		var s: float = 0.0
		if opl != null:
			if opl_fx == null:
				s = float(opl.sample()) / 32768.0 * opl_volume * music_volume
			else:
				s = (float(opl.sample()) * music_volume + float(opl_fx.sample()) * effects_volume) / 32768.0 * opl_volume
		if _spk_freq > 0.0:
			_spk_phase = fmod(_spk_phase + _spk_freq * dt, 1.0)
			var v: float = speaker_volume * effects_volume
			s += v if _spk_phase < 0.5 else -v
		out[i] = Vector2(s, s)
		if not hold:
			t += dt
	if _next > 4096:
		events = events.slice(_next)
		_next = 0
	return out
