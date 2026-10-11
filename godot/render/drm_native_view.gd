# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name DrmNativeView
extends VortNativeView
## REND-02/03/04 (Keen Dreams): the refresh's draw list (DrmVW.draw_list) drawn at the view's own size, as
## Keen 4-6's view draws theirs (GalNativeView): each tile and sprite from the game's files (DrmImages) as a
## texture of palette indices, placed where DrmDrawLayout puts it, coloured through the frame's palette.
## The score box's image is the list's own copy (the game draws its numbers into it).

var images: DrmImages = null
var _gtiles: Dictionary = {}
var _gmtiles: Dictionary = {}
var _gsprites: Dictionary = {}
var _dyn_key: PackedByteArray = PackedByteArray()
var _dyn_tex: ImageTexture = null


func setup(data: Object) -> void:
	images = DrmImages.new(data as DreamsData)
	_gtiles = {}
	_gmtiles = {}
	_gsprites = {}
	_dyn_key = PackedByteArray()
	_dyn_tex = null


func _draw() -> void:
	if _eng == null or _list.is_empty() or images == null:
		return
	var scale: Vector2 = Vector2(size.x / view_w, size.y / DrmDrawLayout.H)
	var layout: Array
	var gap: float = float(_list.get("t", 0.0)) - float(_prev.get("t", 0.0))
	var overlay: Rect2i = list_overlay(_list)
	if smooth and not snap and overlay.size == Vector2i.ZERO and not _prev.is_empty() and _prev.has("sprites") \
			and gap > 0.0 and gap <= MAX_GAP:
		var alpha: float = clampf((_machine_t - _shown_at) / gap, 0.0, 1.0)
		layout = DrmDrawLayout.between(_eng, _prev, _list, alpha, scale, view_w)
	else:
		layout = DrmDrawLayout.ops(_eng, _list, scale, snap, view_w)
	if _black == null:
		_black = _texture(PackedByteArray([0]), PackedByteArray(), 1, 1)
	# black under it all: a map cell with no background tile (a sparse chunk, which the original draws
	# from a segment of zeros; past the map, in the wide view's margins) shows black, not what is behind
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
				tex = _cached(_gtiles, int(op.id), func() -> Dictionary: return images.tile(int(op.id)))
			"mtile":
				tex = _cached(_gmtiles, int(op.id), func() -> Dictionary: return images.mtile(int(op.id)))
			"sprite":
				if dyn.has(int(op.id)):
					tex = _dynamic(int(op.id), dyn)
				else:
					tex = _cached(_gsprites, int(op.id), func() -> Dictionary: return images.sprite(int(op.id)))
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


## An image's texture, made once: its pixels where its mask is clear (all of a background tile).
func _cached(cache: Dictionary, id: int, make: Callable) -> Texture2D:
	if not cache.has(id):
		cache[id] = _image_texture(make.call())
	return cache[id]


func _dynamic(chunk: int, dyn: Dictionary) -> Texture2D:
	var raw: PackedByteArray = dyn[chunk]
	if raw != _dyn_key or _dyn_tex == null:
		_dyn_key = raw
		_dyn_tex = _image_texture(images.sprite(chunk, dyn))
	return _dyn_tex


static func _image_texture(img: Dictionary) -> ImageTexture:
	if img.is_empty():
		return null
	var mask: PackedByteArray = img.get("mask", PackedByteArray())
	var n: int = int(img.w) * int(img.h)
	var cover: PackedByteArray = PackedByteArray()
	if not mask.is_empty():
		cover.resize(n)
		for k: int in range(n):
			cover[k] = 1 if mask[k] == 0 else 0
	return _texture(img.pixels, cover, int(img.w), int(img.h))
