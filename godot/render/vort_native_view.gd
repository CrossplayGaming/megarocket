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

## A18: two more kinds of texture come from the asset stage (AssetStage.extras): a Keen's Closet sprite
## (blue = the closet's code, slot * 40 + (tone + 1) * 8: those pixels take the slot's colour in the
## tone (lighter, as is, shaded, deeper), darkened as the frame's palette darkens that pixel's own colour
## against the EGA default, so fades still fade him) and a pack's picture in its
## own colours (alpha 0.5 where it draws, 0 where it is clear; darkened by the frame's overall fade).
const SHADER: String = """
shader_type canvas_item;
uniform sampler2D palette : filter_nearest;
uniform vec3 slots[6];
uniform float fade = 1.0;
const vec3 EGA[16] = vec3[16](vec3(0.0), vec3(0.0, 0.0, 0.667), vec3(0.0, 0.667, 0.0), vec3(0.0, 0.667, 0.667),
	vec3(0.667, 0.0, 0.0), vec3(0.667, 0.0, 0.667), vec3(0.667, 0.333, 0.0), vec3(0.667), vec3(0.333),
	vec3(0.333, 0.333, 1.0), vec3(0.333, 1.0, 0.333), vec3(0.333, 1.0, 1.0), vec3(1.0, 0.333, 0.333),
	vec3(1.0, 0.333, 1.0), vec3(1.0, 1.0, 0.333), vec3(1.0));
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.75) {
		if (t.a < 0.25) discard;
		COLOR = vec4(t.rgb * fade, 1.0);
	} else {
		if (t.g < 0.5) discard;
		float i = floor(t.r * 255.0 + 0.5);
		vec3 c = texture(palette, vec2((i + 0.5) / 16.0, 0.5)).rgb;
		int code = int(floor(t.b * 255.0 + 0.5));
		int slot = code / 40;
		if (slot > 0) {
			int tone = (code - slot * 40) / 8 - 1;
			vec3 s = slots[slot];
			vec3 shade = tone < 0 ? mix(s, vec3(1.0), 0.4) : s * (tone == 0 ? 1.0 : (tone == 1 ? 0.62 : 0.4));
			float k = clamp(dot(c, vec3(1.0)) / max(dot(EGA[int(i)], vec3(1.0)), 0.05), 0.0, 1.0);
			c = shade * k;
		}
		COLOR = vec4(c, COLOR.a);
	}
}
"""
## The EGA default palette's sum of channels (the fade's measure for a pack's own colours)
const EGA_SUM: float = 6035.0

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
## A18: the game's asset stage (its closet colours, its packs' pictures)
var _stage: AssetStage = null
var _palette_image: Image = Image.create(16, 1, false, Image.FORMAT_RGB8)
var _palette_tex: ImageTexture = ImageTexture.create_from_image(_palette_image)
## The Reveal secrets cheat's tints, over the picture (its own canvas item: no palette shader)
var _reveal: RevealLayer = null
## A foreground tile over a revealed cell: drawn see-through, so what it hides shows
const GHOST: Color = Color(1, 1, 1, 0.35)


## The tints: a cell revealed is washed magenta and outlined, a trap orange.
class RevealLayer:
	extends Control
	var cells: Array = []    # [Rect2, trap]

	func _draw() -> void:
		for c: Array in cells:
			var col: Color = Color(1.0, 0.55, 0.0) if c[1] else Color(1.0, 0.2, 1.0)
			draw_rect(c[0], Color(col, 0.28))
			draw_rect(c[0], Color(col, 0.8), false, 1.0)


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
	_reveal = RevealLayer.new()
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_reveal)


## The game's images as textures (once per game).
func setup(data: Object) -> void:
	_stage = data.stage
	var tiles: PackedByteArray = data.tiles
	_tiles = []
	for t: int in range(tiles.size() / 256):
		_tiles.append(_texture(tiles.slice(t * 256, t * 256 + 256), PackedByteArray(), 16, 16))
	_sprites = []
	for i: int in range(data.sprites.size()):
		var s: Dictionary = data.sprites[i]
		_sprites.append(_staged_texture(s.pixels, s.mask, int(s.w), int(s.h), _stage.extras(i)))
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
	if _stage != null and not _stage.is_identity():
		var sum: int = 0
		for k: int in range(48):
			sum += palette[k]
		var mat: ShaderMaterial = material as ShaderMaterial
		mat.set_shader_parameter("fade", clampf(float(sum) / EGA_SUM, 0.0, 1.0))
		var cols: PackedVector3Array = PackedVector3Array()
		for c: Color in _stage.slot_colors:
			cols.append(Vector3(c.r, c.g, c.b))
		mat.set_shader_parameter("slots", cols)
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
	_show_revealed(revealed, overlay)


## The Reveal secrets cheat's cells (the layout's "reveal" ops) to the tint layer; none while a window is
## over the play.
func _show_revealed(ops: Array, overlay: Rect2i) -> void:
	var cells: Array = []
	if overlay.size == Vector2i.ZERO:
		for op: Dictionary in ops:
			var at: Vector2 = Vector2(roundf(op.x), roundf(op.y))
			var to: Vector2 = Vector2(roundf(op.x + op.w), roundf(op.y + op.h))
			cells.append([Rect2(at, to - at), bool(op.trap)])
	if cells != _reveal.cells:
		_reveal.cells = cells
		_reveal.queue_redraw()


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


## A18: a sprite's texture with what the asset stage added (AssetStage.extras): a pack's picture in its
## own colours, drawn at the sprite's size (its detail kept), or the closet's slots in the blue channel.
static func _staged_texture(pixels: PackedByteArray, cover: PackedByteArray, w: int, h: int, x: Dictionary) -> ImageTexture:
	if x.has("image"):
		var src: Image = x.image
		var img: Image = Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
		for y: int in range(src.get_height()):
			for xx: int in range(src.get_width()):
				var c: Color = src.get_pixel(xx, y)
				img.set_pixel(xx, y, Color(c.r, c.g, c.b, 128.0 / 255.0 if c.a >= 0.5 else 0.0))
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		tex.set_size_override(Vector2i(w, h))
		return tex
	if not x.has("slots"):
		return _texture(pixels, cover, w, h)
	var slots: PackedByteArray = x.slots
	var rgba: PackedByteArray = PackedByteArray()
	rgba.resize(w * h * 4)
	for k: int in range(w * h):
		rgba[k * 4] = pixels[k]
		rgba[k * 4 + 1] = 255 if cover.is_empty() or cover[k] != 0 else 0
		rgba[k * 4 + 2] = slots[k]
		rgba[k * 4 + 3] = 255
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba))


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
