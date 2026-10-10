# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerView
extends Control
## The level on the maker's screen: its tiles at a whole-number zoom (hard pixels), the plane being
## edited marked (Keen 1-3's sprites, Keen 4-6's info: each value in a small box), Keen's start, and the
## cell under the pointer. Left button paints (a drag is one undo step), right button picks the cell's
## value up, the middle button or the arrow keys scroll, the wheel zooms.

signal picked(value: int)
signal hovered(cell: Vector2i, value: int)

var model: MakerModel = null
var tiles: MakerTiles = null
var plane: int = 0
var value: int = 0
## "paint" or "start" (the next click places Keen's start)
var tool: String = "paint"
var zoom: int = 2
var scroll: Vector2 = Vector2.ZERO    # the view's top-left, in level pixels
var _hover: Vector2i = Vector2i(-1, -1)
var _painting: bool = false
var _panning: bool = false


func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func cell_at(p: Vector2) -> Vector2i:
	var w: Vector2 = p / float(zoom) + scroll
	return Vector2i(floori(w.x / 16.0), floori(w.y / 16.0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MegaTheme.SPACE)
	if model == null or model.level == null or tiles == null:
		return
	var l: KeenLevel = model.level
	var t: float = 16.0 * zoom
	var x0: int = maxi(0, floori(scroll.x / 16.0))
	var y0: int = maxi(0, floori(scroll.y / 16.0))
	var x1: int = mini(l.width, ceili((scroll.x + size.x / zoom) / 16.0) + 1)
	var y1: int = mini(l.height, ceili((scroll.y + size.y / zoom) / 16.0) + 1)
	var galaxy: bool = model.engine == KeenLevel.GALAXY
	var font: Font = get_theme_default_font()
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var at: Vector2 = (Vector2(x * 16, y * 16) - scroll) * zoom
			var r: Rect2 = Rect2(at.round(), Vector2(t, t))
			var bg: Texture2D = tiles.texture(0, l.get_word(0, x, y))
			if bg != null:
				draw_texture_rect(bg, r, false)
			if galaxy:
				var fg: Texture2D = tiles.texture(1, l.get_word(1, x, y))
				if fg != null:
					draw_texture_rect(fg, r, false)
			# the markers' plane: values shown while it is edited
			var mplane: int = MakerModel.START_PLANE[model.engine]
			var v: int = l.get_word(mplane, x, y)
			if v in MakerModel.START_MARKERS[model.engine]:
				_marker(r, "K", MegaTheme.ega(14), font)
			elif v != 0 and plane == mplane:
				_marker(r, str(v), MegaTheme.ega(11), font)
	# the map's edge and the cell under the pointer
	var edge: Rect2 = Rect2(((Vector2.ZERO - scroll) * zoom).round(), Vector2(l.width, l.height) * t)
	draw_rect(edge, MegaTheme.ega(8), false, 1.0)
	if l.in_bounds(_hover.x, _hover.y):
		draw_rect(Rect2(((Vector2(_hover * 16) - scroll) * zoom).round(), Vector2(t, t)), MegaTheme.ega(15), false, 2.0)


func _marker(r: Rect2, text: String, colour: Color, font: Font) -> void:
	var inner: Rect2 = r.grow(-r.size.x * 0.15)
	draw_rect(inner, Color(0, 0, 0, 0.7))
	draw_rect(inner, colour, false, 1.0)
	if font != null:
		var fs: int = maxi(8, int(r.size.y * 0.4))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(inner.get_center().x - w / 2.0, inner.get_center().y + fs * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colour)


func _gui_input(event: InputEvent) -> void:
	if model == null or model.level == null:
		return
	if event is InputEventMouseButton:
		var b: InputEventMouseButton = event
		grab_focus()
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				if b.pressed:
					if tool == "start":
						var c: Vector2i = cell_at(b.position)
						model.place_start(c.x, c.y)
						tool = "paint"
					else:
						_painting = true
						model.begin_stroke()
						_paint_at(b.position)
				else:
					_painting = false
					model.end_stroke()
				queue_redraw()
			MOUSE_BUTTON_RIGHT:
				if b.pressed:
					var c: Vector2i = cell_at(b.position)
					if model.level.in_bounds(c.x, c.y):
						value = model.level.get_word(plane, c.x, c.y)
						picked.emit(value)
			MOUSE_BUTTON_MIDDLE:
				_panning = b.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					_zoom_at(b.position, 1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		accept_event()
	elif event is InputEventMouseMotion:
		var m: InputEventMouseMotion = event
		if _panning:
			scroll -= m.relative / float(zoom)
			_clamp()
			queue_redraw()
		var c: Vector2i = cell_at(m.position)
		if c != _hover:
			_hover = c
			hovered.emit(c, model.level.get_word(plane, c.x, c.y) if model.level.in_bounds(c.x, c.y) else -1)
			queue_redraw()
		if _painting:
			_paint_at(m.position)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var step: float = 64.0
		match (event as InputEventKey).keycode:
			KEY_LEFT:
				scroll.x -= step
			KEY_RIGHT:
				scroll.x += step
			KEY_UP:
				scroll.y -= step
			KEY_DOWN:
				scroll.y += step
			_:
				return
		_clamp()
		queue_redraw()
		accept_event()


func _paint_at(p: Vector2) -> void:
	var c: Vector2i = cell_at(p)
	if model.paint(plane, c.x, c.y, value):
		queue_redraw()


func _zoom_at(p: Vector2, dir: int) -> void:
	var before: Vector2 = p / float(zoom) + scroll
	zoom = clampi(zoom + dir, 1, 6)
	scroll = before - p / float(zoom)
	_clamp()
	queue_redraw()


func _clamp() -> void:
	if model == null or model.level == null:
		return
	var w: Vector2 = Vector2(model.level.width, model.level.height) * 16.0
	scroll.x = clampf(scroll.x, -64.0, maxf(-64.0, w.x - size.x / zoom + 64.0))
	scroll.y = clampf(scroll.y, -64.0, maxf(-64.0, w.y - size.y / zoom + 64.0))


## Shows Keen's start (or the level's top-left) in the middle.
func centre_on_start() -> void:
	if model == null or model.level == null:
		return
	var s: Vector2i = model.start_at()
	var at: Vector2 = Vector2(s * 16) if s.x >= 0 else Vector2(size / 2.0 / zoom)
	scroll = at - size / 2.0 / float(zoom)
	_clamp()
	queue_redraw()
