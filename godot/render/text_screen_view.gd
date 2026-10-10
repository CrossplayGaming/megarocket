# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name TextScreenView
extends Control
## A game's text-mode screen (80x25 character cells: Keen Dreams' start screens), drawn by the shell. The
## letters are Megarocket's own pixel font (no PC font ships: A12); the box-drawing and block characters
## the screens use are drawn as lines and fills on the cell grid; the 16 EGA colours; an attribute's top
## bit blinks the character, as the PC's text mode does by default. Fills its rectangle (the 4:3 picture's
## place in the frame).

const COLS: int = 80
const ROWS: int = 25
const BLINK_HZ: float = 1.875    # the PC's text blink (every 16 retraces at 60 Hz, on and off)

var _mem: PackedByteArray = PackedByteArray()
var _blinking: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The screen: character and attribute bytes, row by row (at least 4000).
func show_text(mem: PackedByteArray) -> void:
	_mem = mem
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	var on: bool = fmod(Time.get_ticks_msec() / 1000.0 * BLINK_HZ, 1.0) < 0.5
	if on != _blinking:
		_blinking = on
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _mem.size() < COLS * ROWS * 2:
		return
	var cell: Vector2 = Vector2(size.x / COLS, size.y / ROWS)
	var font: Font = MegaTheme.font()
	var fs: int = maxi(6, int(cell.y * 0.75))
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var i: int = (row * COLS + col) * 2
			var ch: int = _mem[i]
			var attr: int = _mem[i + 1]
			var r: Rect2 = Rect2(Vector2(col, row) * cell, cell)
			var bg: Color = MegaTheme.ega((attr >> 4) & 7)
			if bg != Color.BLACK:
				draw_rect(r, bg)
			if (attr & 0x80) != 0 and not _blinking:
				continue    # blinking, in its off half
			var fg: Color = MegaTheme.ega(attr & 15)
			if ch == 0 or ch == 32 or ch == 255:
				continue
			if _draw_special(ch, r, fg):
				continue
			if ch > 32 and ch < 127:
				var s: String = String.chr(ch)
				var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, Vector2(r.position.x + (cell.x - w) / 2.0, r.position.y + cell.y * 0.8), s,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


## The box-drawing and block characters (code page 437) the screens use: true when drawn.
func _draw_special(ch: int, r: Rect2, fg: Color) -> bool:
	var t: float = maxf(1.0, roundf(r.size.y / 12.0))    # a line's thickness
	var c: Vector2 = r.get_center()
	var x0: float = r.position.x
	var x1: float = r.end.x
	var y0: float = r.position.y
	var y1: float = r.end.y
	var hl: Callable = func(a: float, b: float, y: float) -> void: draw_rect(Rect2(a, y - t / 2.0, b - a, t), fg)
	var vl: Callable = func(a: float, b: float, x: float) -> void: draw_rect(Rect2(x - t / 2.0, a, t, b - a), fg)
	var g: float = t * 1.5    # the gap between a double line's two strokes, from the middle
	match ch:
		219:    # full block
			draw_rect(r, fg)
		220:    # lower half
			draw_rect(Rect2(x0, c.y, r.size.x, y1 - c.y), fg)
		223:    # upper half
			draw_rect(Rect2(x0, y0, r.size.x, c.y - y0), fg)
		221:    # left half
			draw_rect(Rect2(x0, y0, c.x - x0, r.size.y), fg)
		222:    # right half
			draw_rect(Rect2(c.x, y0, x1 - c.x, r.size.y), fg)
		196:    # single horizontal
			hl.call(x0, x1, c.y)
		179:    # single vertical
			vl.call(y0, y1, c.x)
		218:    # single top-left
			hl.call(c.x - t / 2.0, x1, c.y)
			vl.call(c.y - t / 2.0, y1, c.x)
		191:    # single top-right
			hl.call(x0, c.x + t / 2.0, c.y)
			vl.call(c.y - t / 2.0, y1, c.x)
		192:    # single bottom-left
			hl.call(c.x - t / 2.0, x1, c.y)
			vl.call(y0, c.y + t / 2.0, c.x)
		217:    # single bottom-right
			hl.call(x0, c.x + t / 2.0, c.y)
			vl.call(y0, c.y + t / 2.0, c.x)
		205:    # double horizontal
			hl.call(x0, x1, c.y - g)
			hl.call(x0, x1, c.y + g)
		186:    # double vertical
			vl.call(y0, y1, c.x - g)
			vl.call(y0, y1, c.x + g)
		201:    # double top-left
			hl.call(c.x - g - t / 2.0, x1, c.y - g)
			hl.call(c.x + g - t / 2.0, x1, c.y + g)
			vl.call(c.y - g - t / 2.0, y1, c.x - g)
			vl.call(c.y + g - t / 2.0, y1, c.x + g)
		187:    # double top-right
			hl.call(x0, c.x + g + t / 2.0, c.y - g)
			hl.call(x0, c.x - g + t / 2.0, c.y + g)
			vl.call(c.y - g - t / 2.0, y1, c.x + g)
			vl.call(c.y + g - t / 2.0, y1, c.x - g)
		200:    # double bottom-left
			hl.call(c.x + g - t / 2.0, x1, c.y - g)
			hl.call(c.x - g - t / 2.0, x1, c.y + g)
			vl.call(y0, c.y + g + t / 2.0, c.x - g)
			vl.call(y0, c.y - g + t / 2.0, c.x + g)
		188:    # double bottom-right
			hl.call(x0, c.x - g + t / 2.0, c.y - g)
			hl.call(x0, c.x + g + t / 2.0, c.y + g)
			vl.call(y0, c.y + g + t / 2.0, c.x + g)
			vl.call(y0, c.y - g + t / 2.0, c.x - g)
		_:
			return false
	return true
