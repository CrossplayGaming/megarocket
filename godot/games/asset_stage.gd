# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name AssetStage
extends RefCounted
## A18 / PREP-01 (the stage part): the one load-time place every engine's sprites pass through when
## they are cached: Keen 1-3's sprite file as VortData decodes it, Keen 4-6's and Dreams' sprite
## chunks as GalData and DreamsData expand them (so the engine's cache, the emulated card's pictures
## and the native view's images (GalImages, DrmImages, VortNativeView) all see the same result).
## Packs (V15-01) and Keen's Closet (V15-06) are filters here; with none, every sprite goes through
## untouched (the identity stage: the same bytes, the same object).
##
## A sprite is known by its key, the engine's own numbering (Keen 1-3: the sprite number in EGAHEAD's
## order; Keen 4-6 and Dreams: the graphics chunk number), and by its stable name, the engine's own
## (Keen 1-3: the reconstructed source's GRAPHCKn.H names; Keen 4-6: omnispeak's GFXCHUNK names, as
## SPR_KEENSTANDR; Dreams: GRAPHKDR.H's, as KEENSTANDRSPR); "SPRITE_n" where a number has no name.
##
## A filter is a Callable (stage, key, name, img) -> img, where img is {w, h, pixels (palette indices,
## a byte each), opaque (1 where the sprite draws)} and may gain native-view extras: "slots" (a byte a
## pixel: 0, or where Keen's Closet colours the pixel in RGB its slot 1..SLOTS times 40 plus its tone
## (-1 light, 0, 1 shade, 2 deep shade) plus one, times 8) or "image" (an RGBA Image, a
## whole multiple of the size, drawn by the native view instead). A filter returns the img it was given
## when it leaves the sprite alone. The pixels and opaque it returns keep the size.

const SLOTS: int = 5

var game: String = ""
var names: Dictionary = {}       # key -> stable name
var keys: Dictionary = {}        # stable name -> key
var filters: Array[Callable] = []
## The native view's colours for the closet's slots (index 1..SLOTS; 0 unused)
var slot_colors: PackedColorArray = PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK])
## What the filters noted (a malformed pack file, a frame a rule could not settle), for the log and reports
var notes: PackedStringArray = []
var _done: Dictionary = {}       # key -> the img the filters made (only for sprites they changed)


## The game ("keen1".."keen6", "kdreams") and its sprites' names (key -> name). Clears what was staged.
func bind(game_id: String, sprite_names: Dictionary) -> void:
	game = game_id
	names = sprite_names
	keys = {}
	for k: int in names:
		if not keys.has(names[k]):
			keys[names[k]] = k
	_done = {}


func name_of(key: int) -> String:
	return names.get(key, "SPRITE_%d" % key)


func add_filter(f: Callable) -> void:
	filters.append(f)
	_done = {}


func clear_filters() -> void:
	filters.clear()
	notes.clear()
	_done = {}


func is_identity() -> bool:
	return filters.is_empty()


## A sprite through the filters: the img they made, or `img` itself when none changed it.
func run(key: int, img: Dictionary) -> Dictionary:
	if filters.is_empty():
		return img
	if _done.has(key):
		return _done[key]
	var out: Dictionary = img
	var nm: String = name_of(key)
	for f: Callable in filters:
		out = f.call(self, key, nm, out)
	if out != img:
		_done[key] = out
	return out


## The native-view extras the filters gave a sprite already run ({} for none).
func extras(key: int) -> Dictionary:
	var img: Dictionary = _done.get(key, {})
	var x: Dictionary = {}
	if img.has("slots"):
		x.slots = img.slots
	if img.has("image"):
		x.image = img.image
	return x


## Keen 4-6 and Dreams: a sprite chunk as expanded (the mask plane, 1 where the background shows, then
## the B, G, R, I planes; `wbytes` x `h` bytes each) through the stage. The same bytes when no filter
## changes the sprite.
func planar_masked(key: int, raw: PackedByteArray, wbytes: int, h: int) -> PackedByteArray:
	if filters.is_empty():
		return raw
	var stride: int = wbytes * h
	if raw.size() < stride * 5:
		return raw
	if _done.has(key):
		var d: Dictionary = _done[key]
		return encode_masked(d.pixels, d.opaque, wbytes, h, raw)
	var m: Dictionary = GalData.unplane_masked(raw, 0, wbytes, h)
	var opaque: PackedByteArray = m.mask
	for k: int in range(opaque.size()):
		opaque[k] = 1 - opaque[k]
	var img: Dictionary = {"w": wbytes * 8, "h": h, "pixels": m.pixels, "opaque": opaque}
	var out: Dictionary = run(key, img)
	if out == img:
		return raw
	return encode_masked(out.pixels, out.opaque, wbytes, h, raw)


## Pixels and opaque back to the masked planar form (mask, B, G, R, I); bytes of `like` past the five
## planes are kept.
static func encode_masked(pixels: PackedByteArray, opaque: PackedByteArray, wbytes: int, h: int, like: PackedByteArray) -> PackedByteArray:
	var stride: int = wbytes * h
	var out: PackedByteArray = like.duplicate()
	for i: int in range(stride):
		var planes: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
		for bit: int in range(8):
			var p: int = i * 8 + bit
			var m: int = 0x80 >> bit
			if opaque[p] == 0:
				planes[0] |= m
			var c: int = pixels[p]
			for b: int in range(4):
				if c & (1 << b):
					planes[1 + b] |= m
		for pl: int in range(5):
			out[stride * pl + i] = planes[pl]
	return out


## Keen 4-6's sprite names from omnispeak's GFXCHUNK (chunk numbers in [first, first + count)).
static func galaxy_names(chunk_names: VarFile, first: int, count: int) -> Dictionary:
	var out: Dictionary = {}
	if chunk_names == null:
		return out
	for n: String in chunk_names.ints:
		var c: int = int(chunk_names.ints[n])
		if c >= first and c < first + count and not out.has(c):
			out[c] = n
	return out


## Dreams' sprite names, GRAPHKDR.H's as DrmDecl holds them (chunk numbers in [first, first + count)).
static func dreams_names(first: int, count: int) -> Dictionary:
	var out: Dictionary = {}
	var cm: Dictionary = (load("res://games/dreams/drm_decl.gd") as Script).get_script_constant_map()
	for n: String in cm:
		if n.ends_with("SPR") and cm[n] is int:
			var c: int = int(cm[n])
			if c >= first and c < first + count and not out.has(c):
				out[c] = n
	return out


## Keen 1-3's sprite names by number.
static func vorticons_names(list: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(list.size()):
		out[i] = list[i]
	return out
