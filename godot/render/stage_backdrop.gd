# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name StageBackdrop
extends Control
## REND-08/10: what surrounds a picture that doesn't fill the window (Megarocket 1.0's design, approved in
## its playtests: never stretch, never black bars). A backdrop tiled from the game's own tileset (Keen
## 1-3: the starfield tile, in 5 cells of a 4x4 patch, the rest black, so it reads as stars and not
## wallpaper; Keen 4-6: 1.0's tile 87 in every cell), drawn through the frame's palette so it fades with
## the game; and round the picture, in the EGA's fixed colours, a
## five-layer bevel, 10 game pixels a side: a black outline, a raised bevel (yellow top-left, dark grey
## bottom-right), a brown face, a sunken bevel (dark grey top-left, yellow bottom-right), a black seam.

const BACKDROP_TILE: Dictionary = {"keen1": 75, "keen2": 75, "keen3": 38, "keen4": 87, "keen5": 87, "keen6": 87}
const PATCH_CELLS: Array = [Vector2i(0, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)]
const FRAME: int = 10    # game pixels each side

## The picture's rectangle (empty: no frame), and one game pixel's size on the screen.
var frame_rect: Rect2 = Rect2()
var unit: Vector2 = Vector2.ONE

var _pattern: ImageTexture = null
var _black: ImageTexture = ImageTexture.create_from_image(Image.create_from_data(1, 1, false, Image.FORMAT_RG8, PackedByteArray([0, 255])))
var _palette: PackedByteArray = PackedByteArray()
var _palette_image: Image = Image.create(16, 1, false, Image.FORMAT_RGB8)
var _palette_tex: ImageTexture = ImageTexture.create_from_image(_palette_image)
var _frame: Control = null


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = VortNativeView.SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("palette", _palette_tex)
	material = mat
	# the frame in plain colours (the palette's, looked up here), over the backdrop
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	add_child(_frame)


## The game's tiles (palette indices, 256 a tile) and its backdrop tile; none: a black backdrop.
func setup(tiles: PackedByteArray, tile: int) -> void:
	_pattern = null
	if tile < 0 or (tile + 1) * 256 > tiles.size():
		return
	setup_tile(tiles.slice(tile * 256, tile * 256 + 256), PATCH_CELLS)


## One tile's 256 pixels (palette indices), placed in these cells of the 4x4 patch.
func setup_tile(pixels: PackedByteArray, cells: Array) -> void:
	_pattern = null
	if pixels.size() < 256:
		return
	var tiles: PackedByteArray = pixels
	var tile: int = 0
	var rg: PackedByteArray = PackedByteArray()
	rg.resize(64 * 64 * 2)
	for i: int in range(64 * 64):
		rg[i * 2 + 1] = 255    # all shown: black (index 0) where no tile is
	for c: Vector2i in cells:
		for y: int in range(16):
			for x: int in range(16):
				rg[((c.y * 16 + y) * 64 + c.x * 16 + x) * 2] = tiles[tile * 256 + y * 16 + x]
	_pattern = ImageTexture.create_from_image(Image.create_from_data(64, 64, false, Image.FORMAT_RG8, rg))


func set_palette(pal: PackedByteArray) -> void:
	if pal.size() < 48 or pal == _palette:
		return
	_palette = pal.slice(0, 48)
	_palette_image.set_data(16, 1, false, Image.FORMAT_RGB8, _palette)
	_palette_tex.update(_palette_image)
	queue_redraw()
	_frame.queue_redraw()


## Where the picture is and how big a game pixel is (the frame goes round it).
func place(rect: Rect2, pixel: Vector2) -> void:
	if rect == frame_rect and pixel == unit:
		return
	frame_rect = rect
	unit = pixel
	queue_redraw()
	_frame.queue_redraw()


func _draw() -> void:
	if _pattern == null:
		draw_texture_rect(_black, Rect2(Vector2.ZERO, size), false)    # palette index 0: black, faded with the rest
		return
	# the patch in game pixels, from the picture's corner so it lines up with it
	draw_set_transform(frame_rect.position, 0.0, unit)
	var from: Vector2 = -frame_rect.position / unit
	draw_texture_rect(_pattern, Rect2(from, size / unit), true)
	draw_set_transform(Vector2.ZERO)


func _draw_frame() -> void:
	if frame_rect.size == Vector2.ZERO:
		return
	# the EGA's own colours, whatever the game's palette (1.0's frame: the same in a fade or a screen
	# with a palette of its own)
	var black: Color = Color8(0, 0, 0)
	var bright: Color = Color8(0xFF, 0xFF, 0x55)
	var face: Color = Color8(0xAA, 0x55, 0x00)
	var dark: Color = Color8(0x55, 0x55, 0x55)
	# from the outside in: [width in game pixels, top-left colour, bottom-right colour]
	var layers: Array = [[1, black, black], [2, bright, dark], [4, face, face], [2, dark, bright], [1, black, black]]
	var r: Rect2 = frame_rect.grow_individual(FRAME * unit.x, FRAME * unit.y, FRAME * unit.x, FRAME * unit.y)
	for l: Array in layers:
		var w: Vector2 = Vector2(int(l[0]) * unit.x, int(l[0]) * unit.y)
		_frame.draw_rect(Rect2(r.position, Vector2(r.size.x, w.y)), l[1])                                 # top
		_frame.draw_rect(Rect2(r.position, Vector2(w.x, r.size.y)), l[1])                                 # left
		_frame.draw_rect(Rect2(Vector2(r.position.x, r.end.y - w.y), Vector2(r.size.x, w.y)), l[2])       # bottom
		_frame.draw_rect(Rect2(Vector2(r.end.x - w.x, r.position.y), Vector2(w.x, r.size.y)), l[2])       # right
		r = r.grow_individual(-w.x, -w.y, -w.x, -w.y)
