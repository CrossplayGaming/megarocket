# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name DrmImages
extends RefCounted
## Keen Dreams' tiles and sprites as palette indices, unshifted, read from the game's files (DreamsData),
## for the shell's renderers (REND-01D), as GalImages does Keen 4-6's: {w, h, pixels, mask (1 where
## clear; none for a background tile)}. Decoded once each, on first use. A draw list's own copies of an
## image (the score box, whose numbers the game draws into its cached sprite) are decoded from those
## bytes instead. A tile the data lacks (a sparse chunk) is what the original draws from a segment of
## zeros: nothing for a background tile (black stays), black for a masked one.

var data: DreamsData = null
var _tiles: Dictionary = {}
var _mtiles: Dictionary = {}
var _sprites: Dictionary = {}


func _init(d: DreamsData) -> void:
	data = d


func tile(t: int) -> Dictionary:
	if not _tiles.has(t):
		var img: Dictionary = {}
		if t >= 0 and t < DreamsData.NUMTILE16:
			var raw: PackedByteArray = data.chunk(DreamsData.STARTTILE16 + t)
			if raw.size() >= 128:
				img = {"w": 16, "h": 16, "pixels": GalData.unplane(raw, 0, 2, 16)}
		_tiles[t] = img
	return _tiles[t]


func mtile(t: int) -> Dictionary:
	if not _mtiles.has(t):
		var img: Dictionary = {}
		var raw: PackedByteArray = PackedByteArray()
		if t > 0 and t < DreamsData.NUMTILE16M:
			raw = data.chunk(DreamsData.STARTTILE16M + t)
		if raw.size() >= 160:
			var m: Dictionary = GalData.unplane_masked(raw, 0, 2, 16)
			img = {"w": 16, "h": 16, "pixels": m.pixels, "mask": m.mask}
		else:
			# the zero segment: a mask that keeps nothing and no colour (black over the background)
			var zero: PackedByteArray = PackedByteArray()
			zero.resize(256)
			img = {"w": 16, "h": 16, "pixels": zero, "mask": zero}
		_mtiles[t] = img
	return _mtiles[t]


## A sprite by its chunk number; `dyn` a draw list's copies (chunk -> its unshifted bytes as cached now).
func sprite(chunk: int, dyn: Dictionary = {}) -> Dictionary:
	var i: int = chunk - DreamsData.STARTSPRITES
	if i < 0 or i >= data.sprite_table.size():
		return {}
	var t: Dictionary = data.sprite_table[i]
	if dyn.has(chunk):
		var raw: PackedByteArray = dyn[chunk]
		if raw.size() < int(t.w) * int(t.h) * 5:
			return {}
		var m: Dictionary = GalData.unplane_masked(raw, 0, int(t.w), int(t.h))
		return {"w": int(t.w) * 8, "h": int(t.h), "pixels": m.pixels, "mask": m.mask}
	if not _sprites.has(chunk):
		var s: Dictionary = data.sprite(i)
		_sprites[chunk] = {} if s.is_empty() else {"w": int(s.w), "h": int(s.h), "pixels": s.pixels, "mask": s.mask}
	return _sprites[chunk]
