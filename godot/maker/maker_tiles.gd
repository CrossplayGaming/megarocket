# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerTiles
extends RefCounted
## The chosen game's own tiles as textures for the maker's screen (read from the player's files, never
## stored): Keen 1-3's tiles (VortData), Keen 4-6's and Keen Dreams' background and masked foreground
## tiles, in the EGA's 16 colours. Made on first use, from the data MakerParts read.

var engine: String = ""
var count: Array = [0, 0]       # tiles in the first two planes (Keen 1-3: tiles and none)
var _parts: MakerParts = null
var _gal: GalImages = null
var _cache: Dictionary = {}


## Uses the game MakerParts opened.
func use(parts: MakerParts) -> void:
	_parts = parts
	engine = parts.engine
	count = parts.count
	_cache = {}
	_gal = GalImages.new(parts.gal) if parts.gal != null else null


## Plane 0's tile (Keen 1-3's tiles, the others' backgrounds) or plane 1's (foregrounds, with their
## clear parts clear); null for none.
func texture(plane: int, tile: int) -> Texture2D:
	var key: int = plane * 65536 + tile
	if _cache.has(key):
		return _cache[key]
	var img: Dictionary = {}
	match engine:
		KeenLevel.VORTICONS:
			if plane == 0 and tile >= 0 and tile < count[0]:
				img = {"w": 16, "h": 16, "pixels": _parts.vort.tiles.slice(tile * 256, tile * 256 + 256)}
		KeenLevel.GALAXY:
			if plane == 0:
				img = _gal.tile(tile)
			elif plane == 1 and tile > 0:
				img = _gal.mtile(tile)
		KeenLevel.DREAMS:
			if plane == 0 and tile >= 0 and tile < DreamsData.NUMTILE16:
				var raw: PackedByteArray = _parts.dreams.chunk(DreamsData.STARTTILE16 + tile)
				if not raw.is_empty():
					img = {"w": 16, "h": 16, "pixels": GalData.unplane(raw, 0, 2, 16)}
			elif plane == 1 and tile > 0 and tile < DreamsData.NUMTILE16M:
				var raw: PackedByteArray = _parts.dreams.chunk(DreamsData.STARTTILE16M + tile)
				if not raw.is_empty():
					var m: Dictionary = GalData.unplane_masked(raw, 0, 2, 16)
					img = {"w": 16, "h": 16, "pixels": m.pixels, "mask": m.mask}
	var tex: Texture2D = _texture(img, false)
	_cache[key] = tex
	return tex


## V15-02: a marker's sprite (MakerParts.marker_sprite: the game's own picture of the creature, item or
## platform, or Keen); null for a marker the game never draws.
func marker_texture(value: int) -> Texture2D:
	var key: int = -1 - value
	if not _cache.has(key):
		_cache[key] = _texture(_parts.marker_sprite(value), engine == KeenLevel.VORTICONS)
	return _cache[key]


## An image {w, h, pixels, mask} as a texture: the mask's clear parts clear (Keen 1-3's sprites keep 1
## where they are drawn, the others' masks 1 where the background shows).
func _texture(img: Dictionary, mask_drawn: bool) -> Texture2D:
	var tex: Texture2D = null
	if not img.is_empty():
		var w: int = int(img.w)
		var h: int = int(img.h)
		var rgba: PackedByteArray = PackedByteArray()
		rgba.resize(w * h * 4)
		var px: PackedByteArray = img.pixels
		var mask: PackedByteArray = img.get("mask", PackedByteArray())
		for k: int in range(w * h):
			var c: Color = MegaTheme.ega(px[k])
			rgba[k * 4] = c.r8
			rgba[k * 4 + 1] = c.g8
			rgba[k * 4 + 2] = c.b8
			rgba[k * 4 + 3] = 0 if (not mask.is_empty() and (mask[k] != 0) != mask_drawn) else 255
		tex = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba))
	return tex
