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


## A frame: the engine (its tables), its draw list and the frame's palette (16 RGB).
func show_frame(eng: Object, list: Dictionary, palette: PackedByteArray) -> void:
	_eng = eng
	_list = list
	_palette_image.set_data(16, 1, false, Image.FORMAT_RGB8, palette.slice(0, 48))
	_palette_tex.update(_palette_image)
	queue_redraw()


func _draw() -> void:
	if _eng == null or _list.is_empty() or _tiles.is_empty():
		return
	var scale: Vector2 = Vector2(size.x / VortDrawLayout.W, size.y / VortDrawLayout.H)
	for op: Dictionary in VortDrawLayout.ops(_eng, _list, scale, false):
		var tex: Texture2D = null
		match op.kind:
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
