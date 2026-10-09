# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name Starfield
extends Control
## The shell's backdrop: deep space with a fixed scatter of EGA stars at the pixel scale (the same
## field every time; denser on a bigger screen). A few stars twinkle slowly.

var pixel: int = 2
var _seed: int = 0x9E37


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MegaTheme.SPACE)
	var cells: Vector2i = Vector2i(int(size.x / pixel) + 1, int(size.y / pixel) + 1)
	var count: int = int(cells.x * cells.y / 260.0)
	var seed: int = _seed
	var now: float = Time.get_ticks_msec() / 1000.0
	for n: int in range(count):
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var x: int = (seed >> 8) % cells.x
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var y: int = (seed >> 8) % cells.y
		var kind: int = (seed >> 4) % 10
		var c: Color = MegaTheme.ega(8) if kind < 6 else (MegaTheme.ega(7) if kind < 9 else MegaTheme.ega(15))
		if kind == 9 and sin(now * 1.3 + n) > 0.6:
			c = MegaTheme.ega(11)
		draw_rect(Rect2(x * pixel, y * pixel, pixel, pixel), c)
