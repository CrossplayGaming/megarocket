# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GalNativeView
extends VortNativeView
## REND-02/03/04 (Keen 4-6): the refresh's draw list (GalLib.draw_list) drawn at the view's own size, as
## Keen 1-3's view draws theirs: each tile and sprite from the game's files (GalImages) as a texture of
## palette indices, placed where GalDrawLayout puts it, coloured through the frame's palette. The score
## box's image is the list's own copy (the game draws its numbers into it).

var images: GalImages = null
var _gtiles: Dictionary = {}
var _gmtiles: Dictionary = {}
var _gsprites: Dictionary = {}
var _gwhite: Dictionary = {}
var _dyn_key: PackedByteArray = PackedByteArray()
var _dyn_tex: ImageTexture = null


func setup(data: Object) -> void:
	_stage = data.stage
	images = GalImages.new(data as GalData)
	_gtiles = {}
	_gmtiles = {}
	_gsprites = {}
	_gwhite = {}
	_dyn_key = PackedByteArray()
	_dyn_tex = null


func _draw() -> void:
	if _eng == null or _list.is_empty() or images == null:
		return
	var scale: Vector2 = Vector2(size.x / view_w, size.y / GalDrawLayout.H)
	var layout: Array
	var gap: float = float(_list.get("t", 0.0)) - float(_prev.get("t", 0.0))
	var overlay: Rect2i = list_overlay(_list)
	if smooth and not snap and overlay.size == Vector2i.ZERO and not _prev.is_empty() and _prev.has("sprites") \
			and gap > 0.0 and gap <= MAX_GAP:
		var alpha: float = clampf((_machine_t - _shown_at) / gap, 0.0, 1.0)
		layout = GalDrawLayout.between(_eng, _prev, _list, alpha, scale, view_w)
	else:
		layout = GalDrawLayout.ops(_eng, _list, scale, snap, view_w)
	if _black == null:
		_black = _texture(PackedByteArray([0]), PackedByteArray(), 1, 1)
	# black under it all: a map cell with no background tile (an empty chunk, which the original's buffer
	# leaves as it was; past its screen, in the wide view's margins) shows black, not what is behind
	draw_texture_rect(_black, Rect2(Vector2.ZERO, size), false)
	var dyn: Dictionary = _list.get("dyn", {})
	var view: Vector2 = Vector2.ZERO
	var revealed: Array = []
	for op: Dictionary in layout:
		var tex: Texture2D = null
		match op.kind:
			"view":
				view = Vector2(op.x, op.y)
				continue
			"reveal":
				revealed.append(op)
				continue
			"mask":
				draw_texture_rect(_black, Rect2(Vector2(roundf(op.x), 0), Vector2(roundf(op.w), size.y)), false)
				continue
			"tile":
				tex = _cached(_gtiles, int(op.id), func() -> Dictionary: return images.tile(int(op.id)), false)
			"mtile":
				tex = _cached(_gmtiles, int(op.id), func() -> Dictionary: return images.mtile(int(op.id)), false)
			"sprite":
				if dyn.has(int(op.id)):
					tex = _dynamic(int(op.id), dyn)
				else:
					tex = _cached(_gsprites, int(op.id), func() -> Dictionary: return images.sprite(int(op.id)), false)
			"smask":
				tex = _cached(_gwhite, int(op.id), func() -> Dictionary: return images.sprite(int(op.id)), true)
		if tex == null:
			continue
		var at: Vector2 = Vector2(roundf(op.x), roundf(op.y))
		var to: Vector2 = Vector2(roundf(op.x + tex.get_width() * scale.x), roundf(op.y + tex.get_height() * scale.y))
		draw_texture_rect(tex, Rect2(at, to - at), false, GHOST if op.get("ghost", false) else Color.WHITE)
	_draw_overlay(view, scale)
	_show_revealed(revealed, overlay)


## The picture's top-left in world pixels (where the card's picture, and so a window copied from it, sits).
func _camera() -> Vector2:
	return Vector2(float(int(_list.sx)), float(int(_list.sy)))


## An image's texture, made once: its pixels where its mask is clear (all of a background tile); with
## `white`, colour 15 there (a sprite's shape drawn in white).
func _cached(cache: Dictionary, id: int, make: Callable, white: bool) -> Texture2D:
	if not cache.has(id):
		cache[id] = _image_texture(make.call(), white)
	return cache[id]


func _dynamic(chunk: int, dyn: Dictionary) -> Texture2D:
	var raw: PackedByteArray = dyn[chunk]
	if raw != _dyn_key or _dyn_tex == null:
		_dyn_key = raw
		_dyn_tex = _image_texture(images.sprite(chunk, dyn), false)
	return _dyn_tex


static func _image_texture(img: Dictionary, white: bool) -> ImageTexture:
	if img.is_empty():
		return null
	var mask: PackedByteArray = img.get("mask", PackedByteArray())
	var n: int = int(img.w) * int(img.h)
	var cover: PackedByteArray = PackedByteArray()
	var pix: PackedByteArray = img.pixels
	if not mask.is_empty():
		cover.resize(n)
		for k: int in range(n):
			cover[k] = 1 if mask[k] == 0 else 0
	if white:
		pix = PackedByteArray()
		pix.resize(n)
		pix.fill(15)
		return _texture(pix, cover, int(img.w), int(img.h))
	return _staged_texture(pix, cover, int(img.w), int(img.h), img.get("extras", {}))
