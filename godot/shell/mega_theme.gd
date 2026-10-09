# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MegaTheme
extends RefCounted
## Megarocket's own look for the shell (J-12: the per-game accents and rocket branding, rebuilt
## fresh): the 16 EGA colours, Megarocket's pixel font (PixelFontData), and bevelled frames in the
## games' style, all at a whole-number pixel scale so the pixels stay hard at any window size. No
## game's art: it works with none of the games present.

## The EGA palette (index -> colour).
const EGA: Array[Color] = [
	Color8(0, 0, 0), Color8(0, 0, 170), Color8(0, 170, 0), Color8(0, 170, 170),
	Color8(170, 0, 0), Color8(170, 0, 170), Color8(170, 85, 0), Color8(170, 170, 170),
	Color8(85, 85, 85), Color8(85, 85, 255), Color8(85, 255, 85), Color8(85, 255, 255),
	Color8(255, 85, 85), Color8(255, 85, 255), Color8(255, 255, 85), Color8(255, 255, 255),
]
## Each game's accent (EGA index), as the first Megarocket's launcher had them.
const ACCENT: Dictionary = {"keen1": 9, "keen2": 11, "keen3": 13, "keen4": 10, "keen5": 14, "keen6": 12, "kdreams": 3}
## The deep space behind everything.
const SPACE: Color = Color8(5, 5, 24)
## The logical canvas the pixel scale is chosen for (the first launcher's 426x240, a little larger).
const CANVAS: Vector2 = Vector2(480, 270)

static var _font: FontFile = null


## The whole-number pixel scale for a window size (1 at least).
static func pixel_scale(window: Vector2) -> int:
	return maxi(1, int(minf(window.x / CANVAS.x, window.y / CANVAS.y)))


static func ega(i: int) -> Color:
	return EGA[i & 15]


static func accent(id: String) -> Color:
	return ega(int(ACCENT.get(id, 7)))


## The bright and dark partners of an EGA colour (a bright one's dark is its dim half).
static func light_of(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.45)


static func dark_of(c: Color) -> Color:
	return c.darkened(0.55)


## Megarocket's pixel font as a bitmap FontFile: one atlas of the glyphs, line height 11 (8 above
## the baseline, 3 below), advance 6. Drawn at whole multiples of its size (font_size = 11 * n).
static func font() -> FontFile:
	if _font != null:
		return _font
	var keys: Array = PixelFontData.GLYPHS.keys()
	var cols: int = 16
	var cw: int = PixelFontData.W + 1
	var ch: int = PixelFontData.H + 1
	var atlas: Image = Image.create(cols * cw, (keys.size() / cols + 1) * ch, false, Image.FORMAT_LA8)
	var f: FontFile = FontFile.new()
	var size: Vector2i = Vector2i(line_size(), 0)
	f.fixed_size = line_size()
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.set_cache_ascent(0, line_size(), PixelFontData.BASE + 1)
	f.set_cache_descent(0, line_size(), line_size() - PixelFontData.BASE - 1)
	for n: int in range(keys.size()):
		var key: String = keys[n]
		var rows: Array = PixelFontData.GLYPHS[key]
		var ox: int = (n % cols) * cw
		var oy: int = (n / cols) * ch
		for y: int in range(rows.size()):
			for x: int in range(rows[y].length()):
				if rows[y][x] == "#":
					atlas.set_pixel(ox + x, oy + y, Color(1, 1, 1, 1))
		var code: int = key.unicode_at(0)
		f.set_glyph_advance(0, line_size(), code, Vector2(PixelFontData.W + 1, 0))
		f.set_glyph_offset(0, size, code, Vector2(0, -PixelFontData.BASE))
		f.set_glyph_size(0, size, code, Vector2(PixelFontData.W, PixelFontData.H))
		f.set_glyph_uv_rect(0, size, code, Rect2(ox, oy, PixelFontData.W, PixelFontData.H))
		f.set_glyph_texture_idx(0, size, code, 0)
	f.set_texture_image(0, size, 0, atlas)
	_font = f
	return f


## The font's own size (one line), in font pixels.
static func line_size() -> int:
	return PixelFontData.H + 2


## A bevelled frame in a colour, `s` screen pixels to a frame pixel: black, light, the colour, dark,
## black (five layers, as the games frame their pictures), the inside `fill` (transparent if null).
static func bevel(c: Color, s: int, fill: Variant = null) -> StyleBoxTexture:
	var layers: Array = [Color.BLACK, light_of(c), c, dark_of(c), Color.BLACK]
	var n: int = layers.size()
	var px: int = (2 * n + 2)
	var img: Image = Image.create(px * s, px * s, false, Image.FORMAT_RGBA8)
	img.fill(fill if fill != null else Color(0, 0, 0, 0))
	for i: int in range(n):
		var col: Color = layers[i]
		# the light layer lights the top and left, the dark one the bottom and right
		for k: int in range(i, px - i):
			_px(img, k, i, s, light_of(c) if i == 3 else col)
			_px(img, i, k, s, light_of(c) if i == 3 else col)
			_px(img, k, px - 1 - i, s, dark_of(c) if i == 1 else col)
			_px(img, px - 1 - i, k, s, dark_of(c) if i == 1 else col)
	var st: StyleBoxTexture = StyleBoxTexture.new()
	st.texture = ImageTexture.create_from_image(img)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		st.set_texture_margin(side, n * s)
		st.set_content_margin(side, (n + 2) * s)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return st


static func _px(img: Image, x: int, y: int, s: int, c: Color) -> void:
	img.fill_rect(Rect2i(x * s, y * s, s, s), c)


## The shell's theme at pixel scale `s`: the pixel font at 1x (labels, buttons), panels and buttons
## bevelled in grey, the focused button in yellow.
static func build(s: int) -> Theme:
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = line_size() * s
	var grey: Color = ega(7)
	t.set_stylebox("panel", "PanelContainer", bevel(grey, s, SPACE))
	t.set_stylebox("panel", "Panel", bevel(grey, s, SPACE))
	t.set_stylebox("normal", "Button", bevel(ega(8), s, Color8(20, 20, 44)))
	t.set_stylebox("hover", "Button", bevel(grey, s, Color8(30, 30, 64)))
	t.set_stylebox("pressed", "Button", bevel(ega(14), s, Color8(40, 40, 20)))
	t.set_stylebox("focus", "Button", bevel(ega(14), s))
	t.set_stylebox("disabled", "Button", bevel(ega(8), s, SPACE))
	t.set_color("font_color", "Button", ega(15))
	t.set_color("font_hover_color", "Button", ega(14))
	t.set_color("font_focus_color", "Button", ega(14))
	t.set_color("font_pressed_color", "Button", ega(14))
	t.set_color("font_disabled_color", "Button", ega(8))
	t.set_color("font_color", "Label", ega(15))
	t.set_constant("line_spacing", "Label", s)
	return t
