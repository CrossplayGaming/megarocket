# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name BrandHeader
extends Control
## Megarocket's mark: the EGA pixel rocket (the first Megarocket's app icon, its own art) beside the
## MEGAROCKET wordmark, the pixel font's capitals three times over with a black outline, a bright
## top-left edge and a brown shade, yellow faced. Drawn at the shell's pixel scale.

const ROCKET: PackedStringArray = [
	"........K........",
	".......KRK.......",
	".......KRK.......",
	"......KRRDK......",
	"......KRRDK......",
	".....KRRRDDK.....",
	".....KWWWWWK.....",
	".....KWWWWGK.....",
	"....KWWWWWWGK....",
	"....KWKKKKKGK....",
	"....KWKCCBKGK....",
	"....KWKCBBKGK....",
	"....KWKKKKKGK....",
	"....KWWWWWWGK....",
	"....KWWWWWWGK....",
	"...KDWWWWWWGDK...",
	"..KDDWWWWWWGDDK..",
	".KDRDWWWWWWGDRDK.",
	".KDRDWWWWWWGDRDK.",
	".KDRKWWWWWWGKRDK.",
	".KDKKGGGGGGGKKDK.",
	".KKK.KKKKKKK.KKK.",
	".....KYYYYYK.....",
	"......KYRYK......",
	"......KYRYK......",
	".......KYK.......",
	"........K........",
]
const ROCKET_COLOURS: Dictionary = {"K": 0, "W": 15, "G": 7, "R": 12, "D": 4, "C": 11, "B": 1, "Y": 14}
const WORD: String = "MEGAROCKET"
const LETTER_SCALE: int = 3

var pixel: int = 2:
	set(v):
		pixel = v
		update_minimum_size()
		queue_redraw()
## The flame flickers.
var _flame: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.12:
		_t = 0.0
		_flame = not _flame
		queue_redraw()


func _get_minimum_size() -> Vector2:
	var letters: int = WORD.length()
	var w: int = 17 + 6 + letters * (PixelFontData.W + 1) * LETTER_SCALE + 4
	return Vector2(w, ROCKET.size()) * pixel


func _draw() -> void:
	# the rocket
	for y: int in range(ROCKET.size()):
		var row: String = ROCKET[y]
		for x: int in range(row.length()):
			var k: String = row[x]
			if k == ".":
				continue
			var c: Color = MegaTheme.ega(ROCKET_COLOURS[k])
			if _flame and y >= 22 and k == "Y":
				c = MegaTheme.ega(12)
			draw_rect(Rect2(x * pixel, y * pixel, pixel, pixel), c)
	# the wordmark: outline, shade, light edge, face
	var ox: int = (17 + 6) * pixel
	var oy: int = int((ROCKET.size() - PixelFontData.BASE * LETTER_SCALE) / 2.0) * pixel
	var cell: int = LETTER_SCALE * pixel
	var lit: Dictionary = {}
	for i: int in range(WORD.length()):
		var rows: Array = PixelFontData.GLYPHS[WORD[i]]
		for y: int in range(PixelFontData.BASE):
			for x: int in range(PixelFontData.W):
				if rows[y][x] == "#":
					lit[Vector2i(i * (PixelFontData.W + 1) + x, y)] = true
	for p: Vector2i in lit:    # black outline, one letter-pixel all round
		for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(2, 1)]:
			draw_rect(Rect2(ox + (p.x + d.x) * cell, oy + (p.y + d.y) * cell, cell, cell), Color.BLACK)
	for p: Vector2i in lit:    # brown shade under and right
		draw_rect(Rect2(ox + (p.x + 1) * cell, oy + (p.y + 1) * cell, cell, cell), MegaTheme.ega(6))
	for p: Vector2i in lit:    # the face, its top-left edge lit
		var r: Rect2 = Rect2(ox + p.x * cell, oy + p.y * cell, cell, cell)
		draw_rect(r, MegaTheme.ega(14))
		if not lit.has(p + Vector2i(0, -1)) or not lit.has(p + Vector2i(-1, 0)):
			draw_rect(Rect2(r.position, Vector2(cell, pixel)), MegaTheme.ega(15))
			draw_rect(Rect2(r.position, Vector2(pixel, cell)), MegaTheme.ega(15))
