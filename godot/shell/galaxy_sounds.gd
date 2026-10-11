# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GalaxySounds
extends RefCounted
## AUDIO-06 (J-08; the user, 2026-10-10): Keen 4 and 5's AdLib effects in Keen 1-3, in place of the PC
## speaker, from the player's own Keen 4 and 5 (nothing of theirs ships with Megarocket). The table is
## Megarocket 1.0's (each Keen 1-3 sound to the Galaxy sound that fits), written by the sounds' names with a
## second choice from the other game, so either Keen 4 or Keen 5 alone is enough (Keen 6 is never needed).
## Sounds with no fitting Galaxy sound play nothing, as sparse as Galaxy's own effects. Presentation only:
## the speaker's sequencer still runs as the original's (its sound is what is silenced).
##
## The effects are played as Galaxy's id_sd.c plays them (SDL_ALPlaySound and its 140 Hz service): the
## instrument into channel 0's two operators, then a note a tick, key off at the end.

## Keen 1-3 sound -> [[game, Galaxy sound], ...] in order of preference
const TABLE: Dictionary = {
	"WLDWALKSND": [["keen4", "KEENWALK0"], ["keen5", "KEENWALK0"]],    # (alternates with KEENWALK1)
	"KEENWALKSND": [["keen4", "KEENWALK0"], ["keen5", "KEENWALK0"]],
	"KEENWLK2SND": [["keen4", "KEENWALK1"], ["keen5", "KEENWALK1"]],
	"KEENJUMPSND": [["keen4", "KEENJUMP"], ["keen5", "KEENJUMP"]],
	"KEENLANDSND": [["keen4", "KEENLAND"], ["keen5", "KEENLAND"]],
	"KEENDIESND": [["keen4", "KEENDIE"], ["keen5", "KEENDIE"]],
	"GOTBONUSSND": [["keen4", "GOTITEM"], ["keen5", "GOTITEM"]],
	"GOTITEMSND": [["keen4", "GOTSTUNNER"], ["keen5", "GOTSTUNNER"]],
	"GOTPARTSND": [["keen4", "COUNCILSAVE"], ["keen5", "GOTKEYCARD"]],
	"KEENFIRESND": [["keen4", "KEENSHOOT"], ["keen5", "KEENSHOOT"]],
	"KEENPOGOSND": [["keen4", "KEENPOGO"], ["keen5", "KEENPOGO"]],
	"LVLDONESND": [["keen4", "LEVELEXIT"], ["keen5", "LEVELEXIT"]],
	"TELEPORTSND": [["keen5", "MASTERTELE"], ["keen4", "SMIRKYTELE"]],
	"CHUNKSMASHSND": [["keen4", "FIREBALLLAND"], ["keen5", "ENEMYSHOTHIT"]],
	"BUMPHEADSND": [["keen4", "KEENHITCEILING"], ["keen5", "KEENHITCEILING"]],
	"CANNONFIRESND": [["keen4", "BERKELOIDTHROW"], ["keen5", "ENEMYSHOOT"]],
	"CLICKSND": [["keen4", "KEENHITCEILING"], ["keen5", "KEENHITCEILING"]],
	"EXTRAMANSND": [["keen4", "GOTEXTRALIFE"], ["keen5", "GOTEXTRALIFE"]],
	"YORPBUMPSND": [["keen4", "SLICEBUMP"], ["keen5", "SLICEBUMP"]],
	"YORPBOPSND": [["keen5", "AMPTONSTUN"], ["keen4", "KEENSHOTHIT"]],
	"GETCARDSND": [["keen5", "GOTKEYCARD"], ["keen4", "GOTGEM"]],
	"DOOROPENSND": [["keen5", "OPENSECURITYDOOR"], ["keen4", "OPENGEMDOOR"]],
	"GUNCLICKSND": [["keen4", "KEENOUTOFAMMO"], ["keen5", "KEENOUTOFAMMO"]],
	"SHOTHITSND": [["keen4", "KEENSHOTHIT"], ["keen5", "KEENSHOTHIT"]],
	"TANKFIRESND": [["keen5", "ENEMYSHOOT"], ["keen4", "SPRITESHOOT"]],
	"YORPSCREAMSND": [["keen4", "SKYPESTSQUISH"], ["keen5", "BARKSHOTDIE"]],
	"GARGSCREAMSND": [["keen5", "BARKSHOTDIE"], ["keen4", "SKYPESTSQUISH"]],
	"VORTSCREAMSND": [["keen5", "BARKSHOTDIE"], ["keen4", "SKYPESTSQUISH"]],
	"GAMEOVERSND": [["keen4", "KEENDIE"], ["keen5", "KEENDIE"]],
	"KEENSLEFTSND": [["keen4", "STATUSUP"], ["keen5", "STATUSUP"]],
	"KEENSICLESND": [["keen4", "SLICEBUMP"], ["keen5", "SLICEBUMP"]],
	"EARTHPOWSND": [["keen5", "GALAXYEXPLODE"], ["keen4", "CK4MINEEXPLODE"]],    # Keen 2
	"ANKHSND": [["keen4", "GOTGEM"], ["keen5", "GOTGEM"]],                     # Keen 3
	"MEEPSND": [["keen5", "SHOCKSUNDBARK"], ["keen4", "DOPEFISHBURP"]],
	"FOOTSLAMSND": [["keen5", "SPINDREDSLAM"], ["keen4", "FIREBALLLAND"]],
}
## The AdLib effects' service rate (Galaxy's: a sound byte a tick).
const RATE: float = 140.0

var _data: Dictionary = {}     # "keen4" / "keen5" -> GalData (its audio)
var _cache: Dictionary = {}    # Keen 1-3 sound name -> the Galaxy sound's chunk
var _walk: int = 0


## Keen 4 and 5's data from the folders found ({"keen4": folder, "keen5": folder}, either or both).
func load(folders: Dictionary) -> void:
	for g: String in ["keen4", "keen5"]:
		if not folders.has(g):
			continue
		var d: GalData = GalData.new()
		if d.load_game(str(folders[g]), "res://data/omnispeak".path_join(g)):
			_data[g] = d


func available() -> bool:
	return not _data.is_empty()


## The Galaxy effect for a Keen 1-3 sound (its chunk: SoundCommon, Instrument, block, the notes), or empty.
func sound_for(name: String) -> PackedByteArray:
	if name == "WLDWALKSND":
		_walk ^= 1
		if _walk == 0:
			name = "KEENWLK2SND"    # the world map's steps alternate the two walk sounds (1.0's)
	if _cache.has(name):
		return _cache[name]
	var out: PackedByteArray = PackedByteArray()
	for choice: Array in TABLE.get(name, []):
		var d: GalData = _data.get(choice[0])
		if d == null:
			continue
		var n: int = d.episode.get_int("SOUND_" + str(choice[1]), -1)
		if n < 0:
			continue
		out = d.audio_chunk(int(d.aud.startAdlibSounds) + n)
		if out.size() > 23:
			break
		out = PackedByteArray()
	_cache[name] = out
	return out


## The register writes that play an effect from `t0` (seconds): [[seconds, register, value], ...].
static func writes(chunk: PackedByteArray, t0: float) -> Array:
	var out: Array = [[t0, 0xB0, 0]]    # the one sounding stops (SDL_ALStopSound)
	if chunk.size() <= 23:
		return out
	var length: int = chunk.decode_u32(0)
	var inst: PackedByteArray = chunk.slice(6, 22)
	var block: int = ((chunk[22] & 7) << 2) | 0x20
	# SDL_AlSetFXInst: modulator (slot 0) and carrier (slot 3): character, scale, attack, sustain, wave
	for p: Array in [[0x20, 0, 1], [0x40, 2, 3], [0x60, 4, 5], [0x80, 6, 7], [0xE0, 8, 9]]:
		out.append([t0, int(p[0]), inst[p[1]]])
		out.append([t0, int(p[0]) + 3, inst[p[2]]])
	out.append([t0, 0xC0, 0])
	var n: int = mini(length, chunk.size() - 23)
	for i: int in range(n):
		var t: float = t0 + float(i + 1) / RATE
		var s: int = chunk[23 + i]
		if s == 0:
			out.append([t, 0xB0, 0])
		else:
			out.append([t, 0xA0, s])
			out.append([t, 0xB0, block])
	out.append([t0 + float(n + 1) / RATE, 0xB0, 0])
	return out
