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


## MAKER-06: a ground piece's textures, bottom first (Keen 1-3: its tile; the others: background then
## foreground, MakerParts.brush_key's form).
func piece_textures(piece: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if piece < 0:
		return out
	if _parts != null and _parts.engine == KeenLevel.VORTICONS:
		var t: Texture2D = texture(0, piece)
		if t != null:
			out.append(t)
		return out
	for p: Array in [[0, piece >> 16], [1, piece & 0xFFFF]]:
		if p[0] == 1 and p[1] == 0:
			continue
		var t2: Texture2D = texture(p[0], p[1])
		if t2 != null:
			out.append(t2)
	return out


## MAKER-04: an object's picture (MakerObjects: its cells' tiles put together; a ground style's, its hill
## of pieces), made once per object.
func object_texture(o: Dictionary) -> Texture2D:
	var key: int = (str(o.cells) + str(o.get("picture", ""))).hash()
	if _objects.has(key):
		return _objects[key]
	var size: Vector2i = o.size
	var img: Image = Image.create(size.x * 16, size.y * 16, false, Image.FORMAT_RGBA8)
	for c: Array in o.cells:
		var tex: Texture2D = texture(int(o.plane), int(c[1]))
		if tex == null:
			continue
		var part: Image = tex.get_image()
		part.convert(Image.FORMAT_RGBA8)
		img.blend_rect(part, Rect2i(0, 0, 16, 16), (c[0] as Vector2i) * 16)
	for c: Array in o.get("picture", []):
		# (a ramp's picture gives its foreground tiles alone as -1 - tile)
		var texs: Array[Texture2D] = []
		if int(c[1]) < 0:
			var ft: Texture2D = texture(1, -1 - int(c[1]))
			if ft != null:
				texs.append(ft)
		else:
			texs = piece_textures(int(c[1]))
		for tex: Texture2D in texs:
			var part2: Image = tex.get_image()
			part2.convert(Image.FORMAT_RGBA8)
			img.blend_rect(part2, Rect2i(0, 0, 16, 16), (c[0] as Vector2i) * 16)
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_objects[key] = t
	return t


var _objects: Dictionary = {}


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
