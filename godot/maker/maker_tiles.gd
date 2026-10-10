# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerTiles
extends RefCounted
## The chosen game's own tiles as textures for the maker's screen (read from the player's files, never
## stored): Keen 1-3's tiles (VortData), Keen 4-6's background and masked foreground tiles (GalImages),
## in the EGA's 16 colours. Made on first use.

var engine: String = ""
var count: Array = [0, 0]       # tiles in the first two planes (Keen 1-3: tiles and none)
var _vort: VortData = null
var _gal: GalImages = null
var _cache: Dictionary = {}


## False with `error` when the game's graphics don't load.
func open(game_id: String, folder: String) -> String:
	engine = MakerModel.ENGINES.get(game_id, "")
	_cache = {}
	if engine == KeenLevel.VORTICONS:
		_vort = VortData.new()
		if not _vort.load_game(folder, "CK" + game_id.substr(4, 1)):
			return _vort.error
		count = [_vort.tiles.size() / 256, 0]
	else:
		var d: GalData = GalData.new()
		if not d.load_game(folder, "res://data/omnispeak".path_join(MakerModel.GALAXY_META[game_id])):
			return d.error
		_gal = GalImages.new(d)
		count = [int(d.gfx.numTiles16), int(d.gfx.numTiles16m)]
	return ""


## Plane 0's tile (Keen 1-3's tiles, Keen 4-6's backgrounds) or plane 1's (Keen 4-6's foregrounds, with
## their clear parts clear); null for none.
func texture(plane: int, tile: int) -> Texture2D:
	var key: int = plane * 65536 + tile
	if _cache.has(key):
		return _cache[key]
	var img: Dictionary = {}
	if engine == KeenLevel.VORTICONS:
		if plane == 0 and tile >= 0 and tile < count[0]:
			img = {"w": 16, "h": 16, "pixels": _vort.tiles.slice(tile * 256, tile * 256 + 256)}
	elif plane == 0:
		img = _gal.tile(tile)
	elif plane == 1 and tile > 0:
		img = _gal.mtile(tile)
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
			rgba[k * 4 + 3] = 0 if (not mask.is_empty() and mask[k] != 0) else 255
		tex = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba))
	_cache[key] = tex
	return tex
