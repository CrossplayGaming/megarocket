# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerView
extends Control
## The level on the maker's screen (V15-02): its tiles (the game's own) at a whole-number zoom (hard
## pixels) or zoomed out to see the whole level, the markers' plane (Keen 1-3's sprites, the others' info:
## Keen's start, creatures and items named in small boxes), the cursor (moved by the d-pad, the arrows
## or the pointer) with the part about to be placed, and Keen's last test run as a fading trail.
## Tools: paint, pick (the cell's part becomes the one painted), erase, fill a rectangle (two corners),
## Keen's start. The mouse: the left button uses the tool (a drag is one undo step), the right picks, the
## middle drags the view, the wheel zooms. The screen sends the pad's and keys' presses to act_at().

signal picked(plane: int, value: int)
signal hovered(cell: Vector2i)
signal changed

const TOOLS: Array = ["paint", "pick", "erase", "rect", "start"]
const ZOOMS: Array = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 6.0]

var model: MakerModel = null
var tiles: MakerTiles = null
var parts: MakerParts = null
var plane: int = 0
var value: int = 0
var tool: String = "paint"
var zoom: float = 2.0
var scroll: Vector2 = Vector2.ZERO    # the view's top-left, in level pixels
var cursor: Vector2i = Vector2i.ZERO
## The rectangle tool's first corner (-1, -1 when none)
var anchor: Vector2i = Vector2i(-1, -1)
var _painting: bool = false
var _panning: bool = false


func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func cell_at(p: Vector2) -> Vector2i:
	var w: Vector2 = p / zoom + scroll
	return Vector2i(floori(w.x / 16.0), floori(w.y / 16.0))


func _cell_rect(c: Vector2i) -> Rect2:
	var t: float = 16.0 * zoom
	return Rect2(((Vector2(c * 16) - scroll) * zoom).round(), Vector2(t, t))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MegaTheme.SPACE)
	if model == null or model.level == null or tiles == null:
		return
	var l: KeenLevel = model.level
	var x0: int = maxi(0, floori(scroll.x / 16.0))
	var y0: int = maxi(0, floori(scroll.y / 16.0))
	var x1: int = mini(l.width, ceili((scroll.x + size.x / zoom) / 16.0) + 1)
	var y1: int = mini(l.height, ceili((scroll.y + size.y / zoom) / 16.0) + 1)
	var layered: bool = model.engine != KeenLevel.VORTICONS
	var font: Font = get_theme_default_font()
	var mplane: int = MakerModel.START_PLANE[model.engine]
	var labels: bool = zoom >= 1.0
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var r: Rect2 = _cell_rect(Vector2i(x, y))
			var bg: Texture2D = tiles.texture(0, l.get_word(0, x, y))
			if bg != null:
				draw_texture_rect(bg, r, false)
			if layered:
				var fg: Texture2D = tiles.texture(1, l.get_word(1, x, y))
				if fg != null:
					draw_texture_rect(fg, r, false)
			var v: int = l.get_word(mplane, x, y)
			if v in MakerModel.START_MARKERS[model.engine]:
				_marker(r, "K", MegaTheme.ega(14), font, labels)
			elif v != 0:
				var n: String = parts.marker_name(v) if parts != null else ""
				if n != "":
					_marker(r, n.substr(0, 2), MegaTheme.ega(12) if parts.use_of(mplane, v) == MakerParts.ENEMIES else MegaTheme.ega(10), font, labels)
				elif plane == mplane:
					_marker(r, str(v), MegaTheme.ega(11), font, labels)
	var t: float = 16.0 * zoom
	draw_rect(Rect2(((Vector2.ZERO - scroll) * zoom).round(), Vector2(l.width, l.height) * t), MegaTheme.ega(8), false, 1.0)
	# Keen's last run: a trail of his positions, fading from the oldest
	var n: int = model.trail.size()
	for i: int in range(0, n, 2):
		var p: Vector2 = (model.trail[i] * 16.0 - scroll) * zoom
		var c: Color = MegaTheme.ega(14)
		c.a = 0.15 + 0.75 * float(i) / float(maxi(1, n))
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), c)
	# the rectangle being filled, and the cursor with the part it places
	if anchor.x >= 0:
		var a: Rect2 = _cell_rect(Vector2i(mini(anchor.x, cursor.x), mini(anchor.y, cursor.y)))
		var b: Rect2 = _cell_rect(Vector2i(maxi(anchor.x, cursor.x), maxi(anchor.y, cursor.y)))
		draw_rect(a.merge(b), MegaTheme.ega(11), false, 2.0)
	if l.in_bounds(cursor.x, cursor.y):
		var r: Rect2 = _cell_rect(cursor)
		if tool == "paint" and plane != mplane:
			var tex: Texture2D = tiles.texture(plane, value)
			if tex != null:
				draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.6))
		draw_rect(r, MegaTheme.ega(15), false, 2.0)
		draw_rect(r.grow(2), Color(0, 0, 0, 0.8), false, 1.0)


func _marker(r: Rect2, text: String, colour: Color, font: Font, label: bool) -> void:
	var inner: Rect2 = r.grow(-r.size.x * 0.12)
	draw_rect(inner, Color(0, 0, 0, 0.7))
	draw_rect(inner, colour, false, 1.0)
	if font != null and label:
		var fs: int = maxi(8, int(r.size.y * 0.4))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(inner.get_center().x - w / 2.0, inner.get_center().y + fs * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colour)


## The tool used at the cursor (the pad's A, Enter): paint, pick, erase, a rectangle's corner, the start.
## `drag` is a held button moving on (painting goes on, nothing else repeats).
func act_at(c: Vector2i, drag: bool = false) -> void:
	if model == null or model.level == null or not model.level.in_bounds(c.x, c.y):
		return
	match tool:
		"paint", "erase":
			if not drag:
				model.begin_stroke()
			model.paint(plane, c.x, c.y, value if tool == "paint" else erase_value())
		"pick":
			if not drag:
				pick_at(c)
		"rect":
			if drag:
				return
			if anchor.x < 0:
				anchor = c
			else:
				model.fill_rect(plane, anchor, c, value)
				anchor = Vector2i(-1, -1)
		"start":
			if not drag:
				model.place_start(c.x, c.y)
	changed.emit()
	queue_redraw()


## The end of a held press: a drag's cells are one undo step.
func act_end() -> void:
	if model != null:
		model.end_stroke()
	changed.emit()


## What erasing leaves: Keen 1-3's tiles their game's background tile, the others nothing (0).
func erase_value() -> int:
	if model.engine == KeenLevel.VORTICONS and plane == 0:
		return int(model.tile_defaults.get("background", 0))
	return 0


## The part at a cell becomes the one painted: the marker if there is one, else the foreground's tile
## (Keen 4-6, Dreams), else the background's.
func pick_at(c: Vector2i) -> void:
	var l: KeenLevel = model.level
	var mplane: int = MakerModel.START_PLANE[model.engine]
	var p: int = 0
	if l.get_word(mplane, c.x, c.y) != 0:
		p = mplane
	elif model.engine != KeenLevel.VORTICONS and l.get_word(1, c.x, c.y) != 0:
		p = 1
	plane = p
	value = l.get_word(p, c.x, c.y)
	tool = "paint"
	picked.emit(plane, value)
	queue_redraw()


## Moves the cursor by cells, keeping it in the level and in view.
func move_cursor(d: Vector2i) -> void:
	if model == null or model.level == null:
		return
	cursor = Vector2i(clampi(cursor.x + d.x, 0, model.level.width - 1), clampi(cursor.y + d.y, 0, model.level.height - 1))
	_follow()
	hovered.emit(cursor)
	queue_redraw()


func set_cursor(c: Vector2i) -> void:
	cursor = c
	move_cursor(Vector2i.ZERO)


func _follow() -> void:
	var view: Vector2 = size / zoom
	var at: Vector2 = Vector2(cursor * 16)
	var margin: float = minf(48.0, view.x / 4.0)
	if at.x < scroll.x + margin:
		scroll.x = at.x - margin
	elif at.x + 16.0 > scroll.x + view.x - margin:
		scroll.x = at.x + 16.0 - view.x + margin
	margin = minf(48.0, view.y / 4.0)
	if at.y < scroll.y + margin:
		scroll.y = at.y - margin
	elif at.y + 16.0 > scroll.y + view.y - margin:
		scroll.y = at.y + 16.0 - view.y + margin
	_clamp()


func _gui_input(event: InputEvent) -> void:
	if model == null or model.level == null:
		return
	if event is InputEventMouseButton:
		var b: InputEventMouseButton = event
		grab_focus()
		var c: Vector2i = cell_at(b.position)
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				if b.pressed:
					cursor = c
					_painting = tool in ["paint", "erase"]
					if tool == "rect":
						anchor = c
					else:
						act_at(c)
				else:
					if tool == "rect" and anchor.x >= 0:
						act_at(c)
					_painting = false
					act_end()
				queue_redraw()
			MOUSE_BUTTON_RIGHT:
				if b.pressed and model.level.in_bounds(c.x, c.y):
					pick_at(c)
			MOUSE_BUTTON_MIDDLE:
				_panning = b.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					zoom_step(1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1, b.position)
		accept_event()
	elif event is InputEventMouseMotion:
		var m: InputEventMouseMotion = event
		if _panning:
			scroll -= m.relative / zoom
			_clamp()
			queue_redraw()
		var c: Vector2i = cell_at(m.position)
		if c != cursor and model.level.in_bounds(c.x, c.y):
			cursor = c
			hovered.emit(c)
			if _painting:
				act_at(c, true)
			queue_redraw()


## Zooms in (1) or out (-1) a step about `p` (the view's middle if none).
func zoom_step(dir: int, p: Vector2 = Vector2(-1, -1)) -> void:
	var at: int = 0
	for i: int in range(ZOOMS.size()):
		if absf(ZOOMS[i] - zoom) < absf(ZOOMS[at] - zoom):
			at = i
	set_zoom(ZOOMS[clampi(at + dir, 0, ZOOMS.size() - 1)], p)


func set_zoom(z: float, p: Vector2 = Vector2(-1, -1)) -> void:
	if p.x < 0:
		p = size / 2.0
	var before: Vector2 = p / zoom + scroll
	zoom = z
	scroll = before - p / zoom
	_clamp()
	queue_redraw()


## The whole level in view (zoom out), or back to the zoom it had.
func zoom_whole() -> void:
	if model == null or model.level == null or size.x <= 0:
		return
	var fit: float = minf(size.x / (model.level.width * 16.0), size.y / (model.level.height * 16.0))
	zoom = fit
	scroll = Vector2(model.level.width, model.level.height) * 8.0 - size / zoom / 2.0
	queue_redraw()


func whole_shown() -> bool:
	return model != null and model.level != null and model.level.width * 16.0 * zoom <= size.x + 1.0 \
		and model.level.height * 16.0 * zoom <= size.y + 1.0


func _clamp() -> void:
	if model == null or model.level == null:
		return
	var w: Vector2 = Vector2(model.level.width, model.level.height) * 16.0
	var view: Vector2 = size / zoom
	if view.x >= w.x:
		scroll.x = (w.x - view.x) / 2.0
	else:
		scroll.x = clampf(scroll.x, -32.0, w.x - view.x + 32.0)
	if view.y >= w.y:
		scroll.y = (w.y - view.y) / 2.0
	else:
		scroll.y = clampf(scroll.y, -32.0, w.y - view.y + 32.0)


## Shows Keen's start (or the level's middle) with the cursor on it.
func centre_on_start() -> void:
	if model == null or model.level == null:
		return
	var s: Vector2i = model.start_at()
	cursor = s if s.x >= 0 else Vector2i(model.level.width / 2, model.level.height / 2)
	scroll = Vector2(cursor * 16) - size / 2.0 / zoom
	_clamp()
	queue_redraw()
