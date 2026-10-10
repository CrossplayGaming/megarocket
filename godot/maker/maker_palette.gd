# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerPalette
extends Control
## The chosen plane's tiles in a grid (the game's own), the one painted with framed; a click chooses one.
## Sits in a ScrollContainer: its height is the grid's.

signal chosen(value: int)

const COLUMNS: int = 8
var tiles: MakerTiles = null
var plane: int = 0
var count: int = 0
var value: int = 0
var zoom: int = 2


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_plane(t: MakerTiles, p: int, n: int, v: int) -> void:
	tiles = t
	plane = p
	count = n
	value = v
	custom_minimum_size = Vector2(COLUMNS * 16 * zoom, ceili(float(count) / COLUMNS) * 16 * zoom)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MegaTheme.SPACE)
	if tiles == null:
		return
	var t: float = 16.0 * zoom
	for i: int in range(count):
		var r: Rect2 = Rect2(Vector2(i % COLUMNS, i / COLUMNS) * t, Vector2(t, t))
		var tex: Texture2D = tiles.texture(plane, i)
		if tex != null:
			draw_texture_rect(tex, r, false)
		if i == value:
			draw_rect(r, MegaTheme.ega(15), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position / (16.0 * zoom)
		var i: int = int(p.y) * COLUMNS + int(p.x)
		if p.x >= 0 and p.x < COLUMNS and i < count:
			value = i
			chosen.emit(i)
			queue_redraw()
		accept_event()
