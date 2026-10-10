# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name VortNativeView
extends Control
## REND-02 (Keen 1-3): native resolution. A refresh's draw list drawn at the view's own size: each tile,
## sprite and picture from the game's data as a texture of palette indices, placed where the game says
## it is (VortDrawLayout without snapping: the map scrolls by fractions of the original's pixel and a
## sprite sits on its own pixel), coloured through the frame's palette as the 320x200 view is. The
## shell shows it while the picture is the list's alone (a window over the play shows the 320x200).
## Textures: red the palette index, green the coverage (a sprite's mask; a masked tile shows where the
## tile after it, its mask, is clear).

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D palette : filter_nearest;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.g < 0.5) discard;
	float i = floor(t.r * 255.0 + 0.5);
	COLOR = vec4(texture(palette, vec2((i + 0.5) / 16.0, 0.5)).rgb, 1.0);
}
"""

var _eng: Object = null
var _list: Dictionary = {}
## REND-03: smooth motion between the list before and this one, by the machine's clock
var smooth: bool = false
## REND-04: the view's width in the original's pixels (320, or wider for the wide view)
var view_w: int = VortDrawLayout.W
## Native resolution off with the wide view on: the original's whole-pixel places, scaled
var snap: bool = false
var _prev: Dictionary = {}
var _machine_t: float = 0.0
var _shown_at: float = 0.0    # the machine's time when the newest list was first shown
## A window printed over the play: that rectangle of the card's picture (palette indices, 320x200)
## drawn over the list's, where it sits in the world (no flip to 4:3; Megarocket 1.0's way)
var _card: PackedByteArray = PackedByteArray()
var _black: ImageTexture = null
var _overlay_tex: ImageTexture = null
const MAX_GAP: float = 0.25    # seconds between two refreshes past which nothing slides (a load, a pause)
var _tiles: Array = []         # ImageTexture per tile
var _mtiles: Dictionary = {}   # tile -> its masked texture
var _sprites: Array = []
var _pics: Array = []
var _palette_image: Image = Image.create(16, 1, false, Image.FORMAT_RGB8)
var _palette_tex: ImageTexture = ImageTexture.create_from_image(_palette_image)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("palette", _palette_tex)
	material = mat


## The game's images as textures (once per game).
func setup(data: Object) -> void:
	var tiles: PackedByteArray = data.tiles
	_tiles = []
	for t: int in range(tiles.size() / 256):
		_tiles.append(_texture(tiles.slice(t * 256, t * 256 + 256), PackedByteArray(), 16, 16))
	_sprites = []
	for s: Dictionary in data.sprites:
		_sprites.append(_texture(s.pixels, s.mask, int(s.w), int(s.h)))
	_pics = []
	for p: Dictionary in data.pics:
		_pics.append(_texture(p.pixels, PackedByteArray(), int(p.w), int(p.h)))
	_mtiles = {}


## A frame: the engine (its tables), its draw list, the frame's palette (16 RGB) and the machine's
## time now (smooth motion's place between the last two refreshes).
func show_frame(eng: Object, list: Dictionary, palette: PackedByteArray, machine_t: float = 0.0,
		card: PackedByteArray = PackedByteArray()) -> void:
	_eng = eng
	_card = card
	if _list.is_empty() or float(list.get("t", 0.0)) != float(_list.get("t", 0.0)):
		_prev = _list
		_shown_at = machine_t
	_list = list
	_machine_t = machine_t
	_palette_image.set_data(16, 1, false, Image.FORMAT_RGB8, palette.slice(0, 48))
	_palette_tex.update(_palette_image)
	queue_redraw()


func _draw() -> void:
	if _eng == null or _list.is_empty() or _tiles.is_empty():
		return
	var scale: Vector2 = Vector2(size.x / view_w, size.y / VortDrawLayout.H)
	var layout: Array
	var gap: float = float(_list.get("t", 0.0)) - float(_prev.get("t", 0.0))
	var overlay: Rect2i = list_overlay(_list)
	if smooth and not snap and overlay.size == Vector2i.ZERO and not _prev.is_empty() and gap > 0.0 and gap <= MAX_GAP:
		# one refresh behind: from the one before to the newest, over the time between them, counted from
		# when the newest was first shown (a list shows a retrace or more after it is made)
		var alpha: float = clampf((_machine_t - _shown_at) / gap, 0.0, 1.0)
		layout = VortDrawLayout.between(_eng, _prev, _list, alpha, scale, view_w)
	else:
		layout = VortDrawLayout.ops(_eng, _list, scale, snap, view_w)
	var view: Vector2 = Vector2.ZERO
	if _black == null:
		_black = _texture(PackedByteArray([0]), PackedByteArray(), 1, 1)
	for op: Dictionary in layout:
		var tex: Texture2D = null
		match op.kind:
			"view":
				view = Vector2(op.x, op.y)
				continue
			"mask":
				draw_texture_rect(_black, Rect2(Vector2(roundf(op.x), 0), Vector2(roundf(op.w), size.y)), false)
				continue
			"tile":
				tex = _tiles[op.id] if op.id < _tiles.size() else null
			"mtile":
				tex = _masked(int(op.id))
			"sprite":
				tex = _sprites[op.id] if op.id < _sprites.size() else null
			"pic":
				tex = _pics[op.id] if op.id < _pics.size() else null
		if tex == null:
			continue
		var at: Vector2 = Vector2(roundf(op.x), roundf(op.y))
		var to: Vector2 = Vector2(roundf(op.x + tex.get_width() * scale.x), roundf(op.y + tex.get_height() * scale.y))
		draw_texture_rect(tex, Rect2(at, to - at), false)
	_draw_overlay(view, scale)


## A masked tile's texture: the tile where the next tile (its mask) is clear.
func _masked(t: int) -> Texture2D:
	if not _mtiles.has(t):
		var tiles: PackedByteArray = _eng.data.tiles
		if (t + 2) * 256 > tiles.size():
			return null
		var cover: PackedByteArray = PackedByteArray()
		cover.resize(256)
		for k: int in range(256):
			cover[k] = 1 if tiles[(t + 1) * 256 + k] == 0 else 0
		_mtiles[t] = _texture(tiles.slice(t * 256, t * 256 + 256), cover, 16, 16)
	return _mtiles[t]


## Palette indices (and coverage: 1 shown, 0 not; empty for all shown) as an RG8 texture.
static func _texture(pixels: PackedByteArray, cover: PackedByteArray, w: int, h: int) -> ImageTexture:
	var rg: PackedByteArray = PackedByteArray()
	rg.resize(w * h * 2)
	for k: int in range(w * h):
		rg[k * 2] = pixels[k]
		rg[k * 2 + 1] = 255 if cover.is_empty() or cover[k] != 0 else 0
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RG8, rg))


## The rectangle of the picture a window was printed on (empty for none).
static func list_overlay(list: Dictionary) -> Rect2i:
	return list.get("overlay", Rect2i())


## The picture's top-left in world pixels (whole: the game's camera).
func _camera() -> Vector2:
	var pg: int = int(_eng.PIXGLOBAL)
	return Vector2(float(int(_list.originx) / pg), float(int(_list.originy) / pg))


func _draw_overlay(view: Vector2, scale: Vector2) -> void:
	var r: Rect2i = list_overlay(_list).intersection(Rect2i(0, 0, VortDrawLayout.W, VortDrawLayout.H))
	if r.size.x <= 0 or r.size.y <= 0 or _card.size() != VortDrawLayout.W * VortDrawLayout.H:
		return
	var px: PackedByteArray = PackedByteArray()
	px.resize(r.size.x * r.size.y)
	for y: int in range(r.size.y):
		for x: int in range(r.size.x):
			px[y * r.size.x + x] = _card[(r.position.y + y) * VortDrawLayout.W + r.position.x + x]
	# kept until the next draw: the canvas draws it after this returns, and a texture freed by then is blank
	_overlay_tex = _texture(px, PackedByteArray(), r.size.x, r.size.y)
	var tex: ImageTexture = _overlay_tex
	draw_texture_rect(tex, overlay_place(r, _camera(), view, view_w, scale), false)


## REND-09: where a window from the card's picture goes on the view: centred across the view's width
## (the original's picture centred in the wide field, even where the view stands to one side of the
## camera at a map's edge), at its height on the picture (the view and the picture share their top).
static func overlay_place(r: Rect2i, cam: Vector2, view: Vector2, view_w: int, scale: Vector2) -> Rect2:
	var at: Vector2 = Vector2(float(r.position.x) + float(view_w - VortDrawLayout.W) / 2.0, cam.y + float(r.position.y) - view.y) * scale
	var to: Vector2 = at + Vector2(r.size) * scale
	return Rect2(at.round(), (to - at).round())
