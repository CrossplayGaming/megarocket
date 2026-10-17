# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerSounds
extends Node
## MAKER-07: Keen Maker's building sounds, each game's own effects (the user, 2026-10-17: sounds and
## animations while building, as Mario Maker has): a part put in lands as Keen does, one erased is zapped,
## painting steps as Keen walks, a big box pogos, undo jumps, a door's key or gem asked for chimes. Keen
## 4-6 and Keen Dreams play their AdLib effects through the sound chip (d2opl, as GalaxySounds does), Keen
## 1-3 their PC speaker tones (140 a second). Read from the player's files when a game is opened, made into
## sound once each and kept; nothing of the games is stored. Quiet when the effects volume is 0 or the sound
## chip is missing.

## event -> the sound's name: Keen 4-6 (the episode's SOUND_ names), Keen Dreams (its sound numbers), Keen
## 1-3 (SOUNDS' names); "paint" alternates between its two
const GALAXY: Dictionary = {"place": ["SOUND_KEENLAND"], "paint": ["SOUND_KEENWALK0", "SOUND_KEENWALK1"],
	"erase": ["SOUND_KEENSHOOT"], "box": ["SOUND_KEENPOGO"], "undo": ["SOUND_KEENJUMP"], "link": ["SOUND_FLAGFLIP"],
	"ask": ["SOUND_GOTITEM"], "pick": ["SOUND_KEENPADDLE"]}
const DREAMS: Dictionary = {"place": [3], "paint": [0, 1], "erase": [4], "box": [17], "undo": [2], "link": [19],
	"ask": [23], "pick": [26]}
const VORTICONS: Dictionary = {"place": ["KEENLANDSND"], "paint": ["KEENWALKSND", "KEENWLK2SND"],
	"erase": ["KEENFIRESND"], "box": ["KEENPOGOSND"], "undo": ["KEENJUMPSND"], "link": ["DOOROPENSND"],
	"ask": ["GETCARDSND"], "pick": ["CLICKSND"]}
## The least time between two plays of one event (a drag paints a cell a frame)
const GAP_MS: Dictionary = {"paint": 90, "pick": 60}
const OPL_RATE: int = 49716
const SPEAKER_RATE: int = 22050
const SPEAKER_TICK: float = 1.0 / 140.0
const PIT_HZ: float = 1193182.0
const PEAK: int = 14000

var volume: float = 1.0
var _parts: MakerParts = null
var _sounds: Dictionary = {}    # sound key -> AudioStreamWAV (or null: none)
var _last: Dictionary = {}      # event -> msec
var _step: int = 0
var _player: AudioStreamPlayer = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.max_polyphony = 6
	add_child(_player)


## The game's sounds (the parts of the game Keen Maker opened) at `vol` (0-1, the effects volume).
func use(parts: MakerParts, vol: float) -> void:
	_parts = parts
	volume = clampf(vol, 0.0, 1.0)
	_sounds = {}


## Plays the event's sound (none for an event the game has no sound for, or too soon after the last).
func play(event: String) -> void:
	if _parts == null or volume <= 0.0 or _player == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last.get(event, -100000)) < int(GAP_MS.get(event, 30)):
		return
	_last[event] = now
	var names: Array = _table().get(event, [])
	if names.is_empty():
		return
	var name: Variant = names[_step % names.size()] if event == "paint" else names[0]
	if event == "paint":
		_step += 1
	var wav: AudioStreamWAV = _sound(name)
	if wav == null:
		return
	_player.stream = wav
	_player.volume_db = linear_to_db(volume * 0.8)
	_player.play()


func _table() -> Dictionary:
	match _parts.engine:
		KeenLevel.VORTICONS:
			return VORTICONS
		KeenLevel.DREAMS:
			return DREAMS
	return GALAXY


## A sound made once: the game's effect as a sample.
func _sound(name: Variant) -> AudioStreamWAV:
	if _sounds.has(name):
		return _sounds[name]
	var wav: AudioStreamWAV = null
	match _parts.engine:
		KeenLevel.VORTICONS:
			wav = _speaker(str(name))
		KeenLevel.DREAMS:
			if _parts.dreams != null:
				wav = _adlib(_parts.dreams.audio_chunk(28 + int(name)))    # STARTADLIBSOUNDS
		_:
			if _parts.gal != null:
				var n: int = _parts.gal.episode.get_int(str(name), -1)
				if n >= 0:
					wav = _adlib(_parts.gal.audio_chunk(int(_parts.gal.aud.startAdlibSounds) + n))
	_sounds[name] = wav
	return wav


## An AdLib effect (SoundCommon, the instrument, its block, a note a tick) played through the sound chip,
## with a little time after its last note for the chip to fall quiet.
func _adlib(chunk: PackedByteArray) -> AudioStreamWAV:
	if chunk.size() <= 23 or not ClassDB.class_exists("D2Opl"):
		return null
	var writes: Array = GalaxySounds.writes(chunk, 0.0)
	var chip: Object = ClassDB.instantiate("D2Opl")
	chip.write(0x01, 0x20)
	var end: float = float(writes[writes.size() - 1][0]) + 0.25
	var n: int = int(end * OPL_RATE)
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(n * 2)
	var w: int = 0
	for i: int in range(n):
		var t: float = float(i) / OPL_RATE
		while w < writes.size() and float(writes[w][0]) <= t:
			chip.write(int(writes[w][1]), int(writes[w][2]))
			w += 1
		pcm.encode_s16(i * 2, clampi(int(chip.sample()) * 2, -32768, 32767))
	chip.free()
	return _wav(pcm, OPL_RATE)


## A Keen 1-3 sound: its tones (PIT divisors, 0 a rest) a tick each, as a square wave.
func _speaker(name: String) -> AudioStreamWAV:
	if _parts.vort == null:
		return null
	var divisors: PackedInt32Array = PackedInt32Array()
	for s: Dictionary in _parts.vort.sounds:
		if str(s.name) == name:
			divisors = s.divisors
			break
	if divisors.is_empty():
		return null
	var per_tick: int = int(SPEAKER_TICK * SPEAKER_RATE)
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(divisors.size() * per_tick * 2)
	var phase: float = 0.0
	var i: int = 0
	for d: int in divisors:
		var f: float = PIT_HZ / float(d) if d > 0 else 0.0
		for k: int in range(per_tick):
			var v: int = 0
			if f > 0.0:
				phase = fmod(phase + f / SPEAKER_RATE, 1.0)
				v = 6000 if phase < 0.5 else -6000
			pcm.encode_s16(i * 2, v)
			i += 1
	return _wav(pcm, SPEAKER_RATE)


## As a sample, brought to one loudness (PEAK at its loudest: the games' effects differ a lot, Keen 4's steps
## a sixth of its shot), so no building sound drowns another.
static func _wav(pcm: PackedByteArray, rate: int) -> AudioStreamWAV:
	var peak: int = 1
	for i: int in range(0, pcm.size() - 1, 2):
		peak = maxi(peak, absi(pcm.decode_s16(i)))
	var k: float = float(PEAK) / float(peak)
	for i: int in range(0, pcm.size() - 1, 2):
		pcm.encode_s16(i, clampi(int(pcm.decode_s16(i) * k), -32768, 32767))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	return wav
