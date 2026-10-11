# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerPalette
extends Control
## The parts palette (V15-02): one category of MakerParts at a time (ground, slopes, platforms, poles,
## hazards, doors and gems, items, creatures, moving platforms, the exit, scenery, background), its tiles
## the game's own in a grid, or its creatures and items as named boxes; the part being placed framed. A
## click chooses one; the screen steps through the parts and categories for the pad and keys. Sits in a
## ScrollContainer: its height is the grid's.

signal chosen(plane: int, value: int)

const COLUMNS: int = 6
var tiles: MakerTiles = null
var parts: MakerParts = null
## The category shown (an index into parts.categories) and the part chosen in it (an index into its values)
var category: int = 0
var index: int = 0
var zoom: int = 2


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var sc: ScrollContainer = get_parent() as ScrollContainer
	if sc != null:
		sc.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: queue_redraw())


## Keeps the chosen part in sight in the ScrollContainer.
func show_chosen() -> void:
	var sc: ScrollContainer = get_parent() as ScrollContainer
	if sc == null:
		return
	var r: Rect2 = rect_of(index)
	if r.position.y < sc.scroll_vertical:
		sc.scroll_vertical = int(r.position.y)
	elif r.end.y > sc.scroll_vertical + sc.size.y:
		sc.scroll_vertical = int(r.end.y - sc.size.y)
	queue_redraw()


func setup(t: MakerTiles, p: MakerParts) -> void:
	tiles = t
	parts = p
	category = 0
	index = 0
	_resize()


func current() -> Dictionary:
	if parts == null or parts.categories.is_empty():
		return {}
	return parts.categories[category]


## The part chosen: [plane, value] (empty without parts).
func part() -> Array:
	var c: Dictionary = current()
	if c.is_empty() or (c.values as PackedInt32Array).is_empty():
		return []
	return [int(c.plane), int(c.values[clampi(index, 0, c.values.size() - 1)])]


func part_name() -> String:
	var c: Dictionary = current()
	var p: Array = part()
	if p.is_empty():
		return ""
	return str(c.names.get(p[1], "%s tile %d" % [c.name, p[1]]))


func _named() -> bool:
	return not (current().get("names", {}) as Dictionary).is_empty()


func _cell() -> float:
	return 16.0 * zoom + 4.0


func _row_h() -> float:
	return maxf(20.0, get_theme_default_font_size() * 1.6)


func _resize() -> void:
	var c: Dictionary = current()
	var n: int = (c.get("values", PackedInt32Array()) as PackedInt32Array).size()
	if _named():
		custom_minimum_size = Vector2(COLUMNS * _cell(), n * _row_h())
	else:
		custom_minimum_size = Vector2(COLUMNS * _cell(), ceili(float(n) / COLUMNS) * _cell())
	queue_redraw()


## Shows category `i` (wrapping round), its first part chosen.
func show_category(i: int) -> void:
	if parts == null or parts.categories.is_empty():
		return
	category = posmod(i, parts.categories.size())
	index = 0
	_resize()
	_emit()


## Chooses the part `d` steps on in the category (wrapping round).
func step(d: int) -> void:
	var c: Dictionary = current()
	if c.is_empty():
		return
	index = posmod(index + d, maxi(1, (c.values as PackedInt32Array).size()))
	queue_redraw()
	_emit()


## Shows the category holding `value` on `plane` with it chosen; false if no category has it.
func select_value(plane: int, value: int) -> bool:
	if parts == null:
		return false
	for i: int in range(parts.categories.size()):
		var c: Dictionary = parts.categories[i]
		if int(c.plane) == plane:
			var at: int = (c.values as PackedInt32Array).find(value)
			if at >= 0:
				category = i
				index = at
				_resize()
				return true
	return false


func _emit() -> void:
	var p: Array = part()
	if not p.is_empty():
		chosen.emit(p[0], p[1])


## The rectangle of part `i` in the palette.
func rect_of(i: int) -> Rect2:
	if _named():
		return Rect2(Vector2(0, i * _row_h()), Vector2(size.x, _row_h()))
	var t: float = _cell()
	return Rect2(Vector2(i % COLUMNS, i / COLUMNS) * t, Vector2(t, t))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MegaTheme.ega(0))
	var c: Dictionary = current()
	if c.is_empty() or tiles == null:
		return
	var values: PackedInt32Array = c.values
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	# only the parts in sight (a background holds two thousand tiles)
	var seen: Rect2 = Rect2(Vector2.ZERO, size)
	var sc: ScrollContainer = get_parent() as ScrollContainer
	if sc != null:
		seen = Rect2(Vector2(0, sc.scroll_vertical), sc.size)
	for i: int in range(values.size()):
		var r: Rect2 = rect_of(i)
		if not r.intersects(seen):
			continue
		if _named():
			var colour: Color = MegaTheme.ega(12) if c.name == MakerParts.ENEMIES else MegaTheme.ega(10)
			var box: Rect2 = Rect2(r.position + Vector2(2, 2), Vector2(r.size.y - 4, r.size.y - 4))
			draw_rect(box, colour, false, 1.0)
			var label: String = str(c.names.get(values[i], str(values[i])))
			draw_string(font, box.get_center() + Vector2(-fs * 0.5, fs * 0.35), label.substr(0, 2), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, fs - 2), colour)
			draw_string(font, Vector2(box.end.x + 6, r.position.y + r.size.y * 0.5 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - box.end.x - 8, fs, MegaTheme.ega(15))
		else:
			var tex: Texture2D = tiles.texture(int(c.plane), values[i])
			if tex != null:
				draw_texture_rect(tex, r.grow(-2), false)
		if i == index:
			draw_rect(r.grow(-1), MegaTheme.ega(15), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		var n: int = (current().get("values", PackedInt32Array()) as PackedInt32Array).size()
		for i: int in range(n):
			if rect_of(i).has_point(p):
				index = i
				queue_redraw()
				_emit()
				break
		accept_event()
