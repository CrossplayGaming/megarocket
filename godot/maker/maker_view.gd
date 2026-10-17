# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerView
extends Control
## The level on the maker's screen (V15-02): its tiles (the game's own) at a whole-number zoom (hard
## pixels) or zoomed out to see the whole level, the markers' plane (Keen 1-3's sprites, the others' info:
## Keen's start, creatures and items named in small boxes), the cursor (moved by the d-pad, the arrows
## or the pointer) with the part about to be placed, and Keen's last test run as a fading trail.
## Tools: paint, the ground brush (its edges and corners chosen as the game's levels have them), pick (the cell's part becomes the one painted), erase, fill a rectangle (two corners),
## Keen's start. The mouse: the left button uses the tool (a drag is one undo step), the right picks, the
## middle drags the view, the wheel zooms. The screen sends the pad's and keys' presses to act_at().

signal picked(plane: int, value: int)
signal hovered(cell: Vector2i)
signal changed
## V15-04: a part refused, and why
signal refused(reason: String)
## MAKER-07: what building just did, for its sound: "place", "paint" (a drag), "erase", "box" (a big one),
## "undo", "link"
signal built(kind: String)

const TOOLS: Array = ["paint", "brush", "pick", "erase", "rect", "link", "start"]
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
## MAKER-07: building's animations: [kind ("pop" a part put in, "puff" one taken out), cell, plane, tile, start
## (msec)]. Presentation only; at most FX_MAX at once (a big box flashes its outline instead).
var _fx: Array = []
var _flash: Array = []    # [Rect2 in cells (position, size), start]
const FX_MAX: int = 160
const POP_MS: float = 220.0
const PUFF_MS: float = 300.0
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
	# the markers over the tiles: the game's own sprite where there is one (its foot on the marker's cell),
	# else a named box; Keen's start framed yellow, creatures red, the rest green
	for y: int in range(y0, mini(l.height, y1 + 3)):
		for x: int in range(maxi(0, x0 - 3), x1):
			var v: int = l.get_word(mplane, x, y)
			if v == 0:
				continue
			var r: Rect2 = _cell_rect(Vector2i(x, y))
			var start: bool = v in MakerModel.START_MARKERS[model.engine]
			var n: String = "K" if start else (parts.marker_name(v) if parts != null else "")
			var colour: Color = MegaTheme.ega(14) if start else (MegaTheme.ega(12) if parts.use_of(mplane, v) == MakerParts.ENEMIES else MegaTheme.ega(10))
			var tex: Texture2D = tiles.marker_texture(v) if n != "" else null
			if tex != null:
				var s: Vector2 = tex.get_size() * zoom
				var at: Vector2 = r.position if model.engine == KeenLevel.VORTICONS else Vector2(r.position.x, r.end.y - s.y)
				draw_texture_rect(tex, Rect2(at.round(), s), false)
				draw_rect(r, colour, false, 1.0)
			elif n != "":
				_marker(r, n.substr(0, 2), colour, font, labels)
			elif plane == mplane and parts.link_target(l, x, y).x < 0:
				_marker(r, str(v), MegaTheme.ega(11), font, labels)
			# a harder difficulty's creature: N or H in its corner
			var vr: String = parts.variant(v) if parts != null else ""
			if vr != "" and labels:
				var fs2: int = maxi(8, int(r.size.y * 0.35))
				draw_rect(Rect2(r.position, Vector2(fs2, fs2)), Color(0, 0, 0, 0.8))
				draw_string(font, r.position + Vector2(1, fs2 - 1), vr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, MegaTheme.ega(15))
	# Keen 4-6's links as lines: a switch to its platform or bridge, a gem holder to its door, a door to
	# its exit (the info plane's (x << 8) | y at the linking tile)
	if model.engine == KeenLevel.GALAXY:
		for y: int in range(l.height):
			for x: int in range(l.width):
				var to: Vector2i = parts.link_target(l, x, y)
				if to.x >= 0:
					var a: Vector2 = _cell_rect(Vector2i(x, y)).get_center()
					var b: Vector2 = _cell_rect(to).get_center()
					draw_line(a, b, MegaTheme.ega(13), maxf(1.0, zoom))
					draw_rect(_cell_rect(to).grow(-2), MegaTheme.ega(13), false, 1.0)
					draw_circle(a, maxf(2.0, 3.0 * zoom), MegaTheme.ega(13))
	if anchor.x >= 0 and tool == "link":
		draw_line(_cell_rect(anchor).get_center(), _cell_rect(cursor).get_center(), MegaTheme.ega(15), maxf(1.0, zoom))
	var t: float = 16.0 * zoom
	draw_rect(Rect2(((Vector2.ZERO - scroll) * zoom).round(), Vector2(l.width, l.height) * t), MegaTheme.ega(8), false, 1.0)
	# Keen's last run: a trail of his positions, fading from the oldest
	var n: int = model.trail.size()
	for i: int in range(0, n, 2):
		var p: Vector2 = (model.trail[i] * 16.0 - scroll) * zoom
		var c: Color = MegaTheme.ega(14)
		c.a = 0.15 + 0.75 * float(i) / float(maxi(1, n))
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), c)
	_draw_fx()
	# the rectangle being filled, and the cursor with the part it places
	if anchor.x >= 0 and tool == "rect":
		var a: Rect2 = _cell_rect(Vector2i(mini(anchor.x, cursor.x), mini(anchor.y, cursor.y)))
		var b: Rect2 = _cell_rect(Vector2i(maxi(anchor.x, cursor.x), maxi(anchor.y, cursor.y)))
		draw_rect(a.merge(b), MegaTheme.ega(11), false, 2.0)
	if l.in_bounds(cursor.x, cursor.y):
		var r: Rect2 = _cell_rect(cursor)
		if tool == "paint" and plane == MakerObjects.PLANE and model.kit != null and value < model.kit.objects.size():
			# MAKER-04: the whole object, see-through, where it will go
			var o: Dictionary = model.kit.objects[value]
			var shown: Array = []
			if o.has("slope"):
				# the ramp from the first end (the anchor once set) to the cursor: its slope tiles and tops
				var from: Vector2i = anchor if anchor.x >= 0 else cursor
				var to: Vector2i = cursor if anchor.x >= 0 else cursor + Vector2i(5, 0)
				var fam: Dictionary = model.slopes.families[int(o.slope)]
				for w: Array in model.slope_cells(value, from, to):
					shown.append([w[0], w[1]])
					var ov: int = int((fam.over as Dictionary).get(int(w[1]), 0))
					if ov != 0:
						shown.append([(w[0] as Vector2i) + Vector2i(0, -1), ov])
			elif o.has("terrain"):
				pass    # (drawn below: the style's fill piece)
			elif o.has("backdrop"):
				shown.append([cursor, MakerObjects.backdrop_tile(o, cursor.x, cursor.y)])
			elif o.has("stretch"):
				# laid from the first end (the anchor once set) to the cursor
				var from: Vector2i = anchor if anchor.x >= 0 else cursor
				var to: Vector2i = cursor if anchor.x >= 0 else cursor + (Vector2i(2, 0) if o.stretch == "h" else Vector2i(0, 2))
				shown = model.kit.stretch_cells(o, from, to)
			else:
				for oc: Array in o.cells:
					shown.append([cursor + (oc[0] as Vector2i), oc[1]])
			if o.has("terrain"):
				var piece: int = model.terrain.piece(int(o.terrain), 255, cursor.x, cursor.y)
				for tex: Texture2D in tiles.piece_textures(piece):
					draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.6))
				shown.append([cursor, -1])
			if shown.is_empty():
				shown.append([cursor, -1])
			var box: Rect2 = _cell_rect(shown[0][0])
			for sc: Array in shown:
				if int(sc[1]) < 0:
					continue
				var tex: Texture2D = tiles.texture(int(o.plane), int(sc[1]))
				if tex != null:
					draw_texture_rect(tex, _cell_rect(sc[0]), false, Color(1, 1, 1, 0.6))
				box = box.merge(_cell_rect(sc[0]))
			draw_rect(box, MegaTheme.ega(11), false, 1.0)
		elif tool == "paint" and plane != mplane:
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
	if model == null or model.level == null:
		return
	if not model.level.in_bounds(c.x, c.y):
		if not drag:
			refused.emit(model.refusal(plane, c.x, c.y, value))
		return
	match tool:
		"paint" when plane == MakerObjects.PLANE and terrain():
			# a ground style paints like the ground brush, in its own material
			if not drag:
				model.begin_stroke()
			model.terrain_at(value, c.x, c.y, true)
		"erase" when model.terrain != null and model.parts.is_ground(model.level.get_word(model.parts.tile_plane(), c.x, c.y)) and plane != model.parts.marker_plane():
			# MAKER-06: ground taken out, the edges round it made right again
			if not drag:
				model.begin_stroke()
			model.terrain_at(-1, c.x, c.y, false)
		"paint" when plane == MakerObjects.PLANE and backdrop():
			# a backdrop paints like a brush, its pattern lined up with the level
			if not drag:
				model.begin_stroke()
			model.paint_backdrop(value, c.x, c.y)
		"paint" when plane == MakerObjects.PLANE:
			if drag:
				return
			if not dragged():
				model.place_object(value, c.x, c.y)
			elif anchor.x < 0:
				anchor = c
			else:
				if sloping():
					model.place_slope(value, anchor, c)
				else:
					model.place_stretch(value, anchor, c)
				anchor = Vector2i(-1, -1)
		"erase" when not drag and _erase_object(c):
			pass
		"paint", "erase":
			if not drag:
				model.begin_stroke()
			var why: String = model.refusal(plane, c.x, c.y, value) if tool == "paint" else ""
			if why != "":
				refused.emit(why)
				return
			model.paint(plane, c.x, c.y, value if tool == "paint" else erase_value())
		"brush", "unbrush":
			if not drag:
				model.begin_stroke()
			model.brush_at(c.x, c.y, tool == "brush")
		"pick":
			if not drag:
				pick_at(c)
		"link":
			if drag:
				return
			if anchor.x < 0:
				if model.engine != KeenLevel.GALAXY:
					refused.emit("Only Keen 4-6 link switches, gem holders and doors.")
				elif not parts.is_linking(model.level.get_word(1, c.x, c.y)):
					refused.emit("Start a link on a switch, gem holder or door.")
				else:
					anchor = c
			else:
				model.link(anchor, c)
				anchor = Vector2i(-1, -1)
		"rect":
			if drag:
				return
			if anchor.x < 0:
				anchor = c
			else:
				var why: String = _box_refusal(anchor, c)
				if why != "":
					refused.emit(why)
				elif backdrop():
					model.fill_backdrop(value, anchor, c)
				elif terrain():
					model.fill_terrain(value, anchor, c)
				elif plane == MakerObjects.PLANE:
					refused.emit("The box fills with a tile or a backdrop; an object goes in whole with Paint.")
				else:
					model.fill_rect(plane, anchor, c, value)
				anchor = Vector2i(-1, -1)
		"start":
			if not drag:
				model.place_start(c.x, c.y)
	_take_fx()
	changed.emit()
	queue_redraw()


## A box of the part refused: Keen's start, or more objects than the engine holds.
func _box_refusal(a: Vector2i, b: Vector2i) -> String:
	var why: String = model.refusal(plane, a.x, a.y, value)
	if why != "" or plane != MakerModel.START_PLANE[model.engine] or parts.marker_name(value) == "":
		return why
	var more: int = 0
	for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if parts.marker_name(model.level.get_word(plane, x, y)) == "":
				more += 1
	if model.objects() + more > MakerModel.OBJECT_LIMIT[model.engine]:
		return "No room: the game holds %d creatures, items and platforms in a level." % MakerModel.OBJECT_LIMIT[model.engine]
	return ""


## The end of a held press: a drag's cells are one undo step.
## MAKER-07: what the model just painted, as animations: a part put in pops (springs up a little and
## settles), one taken out puffs (shrinks and fades, a little dust). More than FX_MAX cells at once (a big
## box): one flash of their outline.
func _take_fx() -> void:
	if model == null or model.recent.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var changes: Array = model.recent
	var undone: bool = model.recent_undo
	model.recent = []
	model.recent_undo = false
	built.emit(_kind_of(changes, undone))
	if changes.size() > FX_MAX:
		var lo: Vector2i = Vector2i(changes[0][1], changes[0][2])
		var hi: Vector2i = lo
		for e: Array in changes:
			lo = Vector2i(mini(lo.x, e[1]), mini(lo.y, e[2]))
			hi = Vector2i(maxi(hi.x, e[1]), maxi(hi.y, e[2]))
		_flash.append([Rect2(Vector2(lo), Vector2(hi - lo + Vector2i.ONE)), now])
		return
	var seen: Dictionary = {}
	for e: Array in changes:
		var c: Vector2i = Vector2i(e[1], e[2])
		var plane_e: int = e[0]
		var gone: bool = int(e[4]) == 0 or (model.engine == KeenLevel.VORTICONS and plane_e == 0 and int(e[4]) == erase_value_of(0))
		var key: Array = [c, plane_e]
		if seen.has(key):
			continue
		seen[key] = true
		_fx.append(["puff" if gone else "pop", c, plane_e, int(e[3]) if gone else int(e[4]), now])
	if _fx.size() > FX_MAX:
		_fx = _fx.slice(_fx.size() - FX_MAX)


## MAKER-07: what a batch of changes was, for its sound.
func _kind_of(changes: Array, undone: bool) -> String:
	if undone:
		return "undo"
	if tool == "link" or (changes.size() == 1 and int(changes[0][0]) == 2 and model.engine == KeenLevel.GALAXY and parts.marker_name(int(changes[0][4])) == ""):
		return "link"
	if changes.size() > FX_MAX:
		return "box"
	if tool == "erase":
		return "erase"
	return "paint" if _painting else "place"


func erase_value_of(p: int) -> int:
	if model.engine == KeenLevel.VORTICONS and p == 0:
		return int(model.tile_defaults.get("background", 0))
	return 0


func _process(_delta: float) -> void:
	if model != null and not model.recent.is_empty():
		_take_fx()    # (an undo, a redo, the screen's own changes)
	if _fx.is_empty() and _flash.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_fx = _fx.filter(func(f: Array) -> bool: return now - int(f[4]) < (POP_MS if f[0] == "pop" else PUFF_MS))
	_flash = _flash.filter(func(f: Array) -> bool: return now - int(f[1]) < PUFF_MS)
	queue_redraw()


## MAKER-07: the animations over the level.
func _draw_fx() -> void:
	var now: int = Time.get_ticks_msec()
	var mplane: int = MakerModel.START_PLANE[model.engine]
	for f: Array in _fx:
		var r: Rect2 = _cell_rect(f[1])
		var tex: Texture2D = tiles.marker_texture(int(f[3])) if int(f[2]) == mplane else tiles.texture(int(f[2]), int(f[3]))
		if f[0] == "pop":
			var t: float = clampf((now - int(f[4])) / POP_MS, 0.0, 1.0)
			var s: float = 1.0 + 0.35 * sin(t * PI) * (1.0 - t * 0.5)
			var rr: Rect2 = Rect2(r.get_center() - r.size * s / 2.0, r.size * s)
			if tex != null and int(f[2]) != mplane:
				draw_texture_rect(tex, rr, false)
			draw_rect(rr, Color(1, 1, 1, 0.7 * (1.0 - t)), false, maxf(1.0, zoom))
		else:
			var t2: float = clampf((now - int(f[4])) / PUFF_MS, 0.0, 1.0)
			var s2: float = 1.0 - 0.6 * t2
			var rr2: Rect2 = Rect2(r.get_center() - r.size * s2 / 2.0, r.size * s2)
			if tex != null and int(f[2]) != mplane:
				draw_texture_rect(tex, rr2, false, Color(1, 1, 1, 1.0 - t2))
			# dust: four specks flying out from the corners
			var spread: float = r.size.x * (0.2 + 0.6 * t2)
			for d: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var p: Vector2 = r.get_center() + d * spread
				var dot: float = maxf(1.0, zoom * 1.5 * (1.0 - t2))
				draw_rect(Rect2(p - Vector2(dot, dot) / 2.0, Vector2(dot, dot)), Color(0.85, 0.85, 0.85, 1.0 - t2))
	for fl: Array in _flash:
		var t3: float = clampf((now - int(fl[1])) / PUFF_MS, 0.0, 1.0)
		var cr: Rect2 = fl[0]
		var a: Rect2 = _cell_rect(Vector2i(cr.position))
		var b: Rect2 = _cell_rect(Vector2i(cr.end) - Vector2i.ONE)
		draw_rect(a.merge(b).grow(2.0 + 6.0 * t3), Color(1, 1, 1, 0.8 * (1.0 - t3)), false, maxf(1.0, zoom * 1.5))


func act_end() -> void:
	if model != null:
		model.end_stroke()
	changed.emit()


## What erasing leaves: Keen 1-3's tiles their game's background tile, the others nothing (0).
## MAKER-04: a stretchable object is chosen (it is laid from one end to the other, like a box's corners)
func stretching() -> bool:
	return tool == "paint" and plane == MakerObjects.PLANE and model != null and model.kit != null \
		and value >= 0 and value < model.kit.objects.size() and model.kit.objects[value].has("stretch")


## MAKER-08: a ramp is chosen (laid from one end to the other)
func sloping() -> bool:
	return tool == "paint" and plane == MakerObjects.PLANE and model != null and model.kit != null \
		and value >= 0 and value < model.kit.objects.size() and model.kit.objects[value].has("slope")


## A stretchable or a ramp: laid by its two ends
func dragged() -> bool:
	return stretching() or sloping()


## MAKER-06: a ground style is chosen (painted like a brush; the box fills with it)
func terrain() -> bool:
	return plane == MakerObjects.PLANE and model != null and model.kit != null \
		and value >= 0 and value < model.kit.objects.size() and model.kit.objects[value].has("terrain")


## MAKER-04: a backdrop is chosen (painted like a brush; the box fills with it)
func backdrop() -> bool:
	return plane == MakerObjects.PLANE and model != null and model.kit != null \
		and value >= 0 and value < model.kit.objects.size() and model.kit.objects[value].has("backdrop")


## MAKER-04: the eraser takes a whole object at once (the foreground's first, then the background's); false
## when the cell holds none, so it erases the one tile as before.
func _erase_object(c: Vector2i) -> bool:
	var planes: Array = [0] if model.engine == KeenLevel.VORTICONS else [1, 0]
	if plane >= 0 and plane != model.parts.marker_plane() and planes.has(plane):
		planes = [plane]
	for p: int in planes:
		if model.erase_object_at(p, c.x, c.y) > 0:
			return true
	return false


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
	# MAKER-04: a cell of a whole object picks the object
	if p != mplane and model.kit != null:
		for op: int in ([p] if p == 1 or model.engine == KeenLevel.VORTICONS else [0]):
			var o: int = model.kit.object_at(l, op, c.x, c.y)
			if o >= 0:
				plane = MakerObjects.PLANE
				value = o
				break
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
					_painting = tool in ["paint", "erase", "brush"] and not dragged() and not (tool == "paint" and plane == MakerObjects.PLANE and not backdrop() and not terrain())
					if tool == "rect" or dragged():
						anchor = c
					else:
						act_at(c)
				else:
					if (tool == "rect" or dragged()) and anchor.x >= 0:
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
