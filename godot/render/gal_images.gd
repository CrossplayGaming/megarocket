# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GalImages
extends RefCounted
## Keen 4-6's tiles and sprites as palette indices, unshifted, read from the game's files (GalData), for
## the shell's renderers (REND-01/02): {w, h, pixels, mask (1 where clear; none for a background tile)}.
## Decoded once each, on first use. A draw list's own copies of an image (the score box, whose numbers
## the game draws into its cached sprite) are decoded from those bytes instead.

var data: GalData = null
var _tiles: Dictionary = {}
var _mtiles: Dictionary = {}
var _sprites: Dictionary = {}


func _init(d: GalData) -> void:
	data = d


func tile(t: int) -> Dictionary:
	if not _tiles.has(t):
		var img: Dictionary = {}
		if t >= 0 and t < int(data.gfx.numTiles16):
			var raw: PackedByteArray = data.chunk(int(data.gfx.offTiles16) + t)
			if not raw.is_empty():
				img = {"w": 16, "h": 16, "pixels": GalData.unplane(raw, 0, 2, 16)}
		_tiles[t] = img
	return _tiles[t]


func mtile(t: int) -> Dictionary:
	if not _mtiles.has(t):
		var img: Dictionary = {}
		if t > 0 and t < int(data.gfx.numTiles16m):
			var raw: PackedByteArray = data.chunk(int(data.gfx.offTiles16m) + t)
			if not raw.is_empty():
				var m: Dictionary = GalData.unplane_masked(raw, 0, 2, 16)
				img = {"w": 16, "h": 16, "pixels": m.pixels, "mask": m.mask}
		_mtiles[t] = img
	return _mtiles[t]


## A sprite by its chunk number; `dyn` a draw list's copies (chunk -> its bytes as cached now).
func sprite(chunk: int, dyn: Dictionary = {}) -> Dictionary:
	var i: int = chunk - int(data.gfx.offSprites)
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
		_sprites[chunk] = {} if s.is_empty() else {"w": int(s.w), "h": int(s.h), "pixels": s.pixels, "mask": s.mask,
			"extras": data.stage.extras(chunk)}
	return _sprites[chunk]
