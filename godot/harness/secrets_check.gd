# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## The Reveal secrets list, entry by entry, for checking by eye: a picture per entry of
## godot/data/secrets/<game>.json, the place as the player sees it (left) beside the same place revealed
## (right: the foreground lifted off the entry's cells, the cells tinted magenta, traps orange, items
## dotted white, or red where the finder finds no route to them), six tiles around, twice the size.
## Keen 4-6's item sprites (the info plane's) are not drawn: on the left a yellow dot marks each the
## game would show (no foreground drawn over Keen on its cell), so a "hidden" item in plain view shows.
##
##   godot --headless --path godot --script res://harness/secrets_check.gd -- --game_data=<folder>
##         --out=<folder> --game=keen5 [--source=data] [--ids=k5-01-a,...] [--list=<json>] [--fore=0.9]
##         [--misses=1 [--cover=75]]
## --misses (Keen 4-6): no pictures; every item sprite the game hides (a foreground drawn over Keen on
## its cell, painting at least --cover percent of it) that no entry of the list covers, map by map:
## what the list may have missed.
## Keen Dreams (--game=kdreams or kdreams193, the list data/secrets/kdreams.json for both releases):
## its items are the info plane's bonuses (21-32), hidden as Keen 4-6's are, under a foreground tile
## drawn over Keen (INTILE's top bit) painting --cover percent of the cell or more; --misses lists
## those no entry covers. Without it, a picture per level that has entries, for review: the whole
## level, the entries' cells tinted magenta (traps orange) and outlined, items dotted white, those the
## foreground hides red, Keen's start outlined green, a faint line every 10 tiles
## (<out>/<game>_mapNN.png).

const SF = preload("res://maker/secret_finder.gd")
const MARGIN: int = 6
## Keen Dreams' INTILE table, from the start of DreamsData.tileinfo (id_ca.c's tinf past SPEED).
const DRM_INTILE: int = DreamsData.NUMTILE16 * 2 + DreamsData.NUMTILE16M * 5
const SCALE: int = 2

const EGA: Array = [
	Color8(0, 0, 0), Color8(0, 0, 170), Color8(0, 170, 0), Color8(0, 170, 170),
	Color8(170, 0, 0), Color8(170, 0, 170), Color8(170, 85, 0), Color8(170, 170, 170),
	Color8(85, 85, 85), Color8(85, 85, 255), Color8(85, 255, 85), Color8(85, 255, 255),
	Color8(255, 85, 85), Color8(255, 85, 255), Color8(255, 255, 85), Color8(255, 255, 255)]

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var root: String = str(_opts.get("game_data", ""))
	var out: String = str(_opts.get("out", OS.get_temp_dir().path_join("secrets_check")))
	var game: String = str(_opts.get("game", "keen5"))
	DirAccess.make_dir_recursive_absolute(out)
	var dreams: bool = game.begins_with("kdreams")
	var list: String = str(_opts.get("list", "res://data/secrets/%s.json" % ("kdreams" if dreams else game)))
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(list))
	if typeof(doc) != TYPE_DICTIONARY:
		print("no list: " + list)
		quit(1)
		return
	var ids: PackedStringArray = str(_opts.get("ids", "")).split(",", false)
	var source: String = str(_opts.get("source", ""))
	var gal: bool = game in ["keen4", "keen5", "keen6"]
	var gd: GalData = null
	var imgs: GalImages = null
	var vd: VortData = null
	var dd: DreamsData = null
	if dreams:
		dd = DreamsData.new()
		if not dd.load_game(root.path_join(game)):
			print("load failed: ", dd.error)
			quit(1)
			return
	elif gal:
		gd = GalData.new()
		if not gd.load_game(root.path_join(game), "res://data/omnispeak/" + ("keen6e14" if game == "keen6" else game)):
			print("load failed: ", gd.error)
			quit(1)
			return
		imgs = GalImages.new(gd)
	else:
		vd = VortData.new()
		if not vd.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
			print("load failed: ", vd.error)
			quit(1)
			return
	# the finder's settings for the routes (Keen 5-6's lists were built with --fore=0.9: a passable tile
	# drawn over Keen and nearly opaque counts as a wall)
	var fopts: Dictionary = {}
	if _opts.has("fore"):
		fopts.fore_opaque = float(_opts.fore)
	if dreams:
		_dreams(dd, doc, ids, source, out, game)
		quit(0)
		return
	if gal and str(_opts.get("misses", "0")) != "0":
		_misses(gd, imgs, doc)
		quit(0)
		return
	var made: int = 0
	for key: String in doc.levels:
		var entries: Array = []
		for e: Dictionary in doc.levels[key]:
			if (ids.is_empty() or str(e.id) in ids) and (source == "" or str(e.get("source", "")) == source):
				entries.append(e)
		if entries.is_empty():
			continue
		var n: int = int(key)
		var r: Dictionary = SF.galaxy(gd, imgs, n, fopts) if gal else SF.vorticons(vd, n, fopts)
		if r.is_empty():
			print("level %d: the finder could not read it" % n)
			continue
		var view: Dictionary = _render_galaxy(gd, imgs, n) if gal else _render_vort(vd, r)
		for e: Dictionary in entries:
			_picture(view, r, e, out.path_join("%s.png" % e.id))
			made += 1
	print("%d pictures in %s" % [made, out])
	quit(0)


func _misses(d: GalData, imgs: GalImages, doc: Dictionary) -> void:
	var total: int = 0
	for i: int in range(GalData.NUM_MAPS):
		if not d.has_map(i):
			continue
		var m: Dictionary = d.load_map(i)
		var w: int = int(m.width)
		var covered: Dictionary = {}
		for e: Dictionary in doc.levels.get(str(i), []):
			for c: Array in e.cells:
				for y: int in range(int(c[1]), int(c[3]) + 1):
					for x: int in range(int(c[0]), int(c[2]) + 1):
						covered[y * w + x] = true
		var t16: int = int(d.gfx.numTiles16)
		var t16m: int = int(d.gfx.numTiles16m)
		var out: PackedStringArray = PackedStringArray()
		for p: int in range(w * int(m.height)):
			var v: int = m.plane[2][p]
			var f: int = m.plane[1][p]
			if v < 57 or v > 70 or f <= 0 or f > t16m:
				continue
			var at: int = f + t16 * 2 + t16m * 5
			if at < d.tileinfo.size() and (d.tileinfo[at] & 0x80) != 0 and not covered.has(p):
				# how much of the cell the foreground paints (its mask clear): an edge strip leaves the item seen
				var mt: Dictionary = imgs.mtile(f)
				var painted: int = 0
				for k: int in range(256):
					painted += 1 if not mt.is_empty() and mt.mask[k] == 0 else 0
				if painted * 100 / 256 >= int(_opts.get("cover", "75")):
					out.append("(%d, %d) info %d cover %d%%" % [p % w, p / w, v, painted * 100 / 256])
		if not out.is_empty():
			total += out.size()
			print("map %d %s: %d hidden items in no entry: %s" % [i, m.name, out.size(), ", ".join(out)])
	print("%d hidden items in no entry" % total)


## The level twice, a pixel per pixel: as drawn (`seen`) and with no foreground (`bare`).
func _render_galaxy(d: GalData, imgs: GalImages, i: int) -> Dictionary:
	var m: Dictionary = d.load_map(i)
	var w: int = int(m.width)
	var h: int = int(m.height)
	var seen: PackedByteArray = PackedByteArray()
	var bare: PackedByteArray = PackedByteArray()
	seen.resize(w * 16 * h * 16)
	bare.resize(w * 16 * h * 16)
	var shown: Dictionary = {}
	var t16: int = int(d.gfx.numTiles16)
	var t16m: int = int(d.gfx.numTiles16m)
	for ty: int in range(h):
		for tx: int in range(w):
			var bi: Dictionary = imgs.tile(m.plane[0][ty * w + tx])
			var f: int = m.plane[1][ty * w + tx]
			var v: int = m.plane[2][ty * w + tx]
			if v >= 57 and v <= 70:
				# an item sprite: seen unless its cell's foreground is drawn over Keen (TI_ForeMisc's top bit)
				var at: int = f + t16 * 2 + t16m * 5
				var misc: int = d.tileinfo[at] if f > 0 and f <= t16m and at < d.tileinfo.size() else 0
				if (misc & 0x80) == 0:
					shown[ty * w + tx] = true
			var fi: Dictionary = imgs.mtile(f) if f > 0 else {}
			for y: int in range(16):
				for x: int in range(16):
					var k: int = y * 16 + x
					var c: int = 0 if bi.is_empty() else bi.pixels[k]
					var o: int = (ty * 16 + y) * w * 16 + tx * 16 + x
					bare[o] = c & 15
					if not fi.is_empty() and fi.mask[k] == 0:
						c = fi.pixels[k]
					seen[o] = c & 15
	return {"w": w, "h": h, "seen": seen, "bare": bare, "shown": shown}


## Keen 1-3 have one plane: what is drawn is the tile, hidden bricks included. The bare view is the same
## (the tint and the item dots show the entry).
func _render_vort(d: VortData, r: Dictionary) -> Dictionary:
	var w: int = int(r.width)
	var h: int = int(r.height)
	var tp: PackedInt32Array = r.tiles
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * 16 * h * 16)
	for ty: int in range(h):
		for tx: int in range(w):
			var t: int = tp[ty * w + tx]
			for y: int in range(16):
				for x: int in range(16):
					var c: int = 0
					if t >= 0 and t * 256 + 256 <= d.tiles.size():
						c = d.tiles[t * 256 + y * 16 + x]
					seen[(ty * 16 + y) * w * 16 + tx * 16 + x] = c & 15
	return {"w": w, "h": h, "seen": seen, "bare": seen, "shown": {}}


func _picture(view: Dictionary, r: Dictionary, e: Dictionary, path: String) -> void:
	var w: int = view.w
	var h: int = view.h
	var x0: int = 1 << 20
	var y0: int = 1 << 20
	var x1: int = -1
	var y1: int = -1
	var mine: Dictionary = {}
	for c: Array in e.cells:
		x0 = mini(x0, int(c[0]))
		y0 = mini(y0, int(c[1]))
		x1 = maxi(x1, int(c[2]))
		y1 = maxi(y1, int(c[3]))
		for ty: int in range(int(c[1]), int(c[3]) + 1):
			for tx: int in range(int(c[0]), int(c[2]) + 1):
				mine[ty * w + tx] = true
	var cx0: int = maxi(0, x0 - MARGIN)
	var cy0: int = maxi(0, y0 - MARGIN)
	var cx1: int = mini(w - 1, x1 + MARGIN)
	var cy1: int = mini(h - 1, y1 + MARGIN)
	var cw: int = (cx1 - cx0 + 1) * 16
	var ch: int = (cy1 - cy0 + 1) * 16
	var gap: int = 8
	var pw: int = (cw * 2 + gap) * SCALE
	var ph: int = ch * SCALE
	var px: PackedByteArray = PackedByteArray()
	px.resize(pw * ph * 3)
	px.fill(255)
	var tint: Color = Color(1, 0.5, 0) if str(e.get("kind", "secret")) == "trap" else Color(1, 0, 1)
	var items: Dictionary = {}
	for it: Array in r.items:
		items[int(it[0])] = it[2] != "unreached"
	for y: int in range(ch):
		for x: int in range(cw):
			var gx: int = cx0 * 16 + x
			var gy: int = cy0 * 16 + y
			var cell: int = (gy / 16) * w + gx / 16
			var o: int = gy * w * 16 + gx
			var left: Color = EGA[view.seen[o]]
			var right: Color = EGA[(view.bare if mine.has(cell) else view.seen)[o]]
			if mine.has(cell):
				right = right.lerp(tint, 0.35)
				if x % 16 == 0 or y % 16 == 0:
					right = right.lerp(tint, 0.6)
			if items.has(cell) and x % 16 >= 5 and x % 16 < 11 and y % 16 >= 5 and y % 16 < 11:
				right = Color(1, 1, 1) if items[cell] else Color(1, 0, 0)
			if view.shown.has(cell) and x % 16 >= 6 and x % 16 < 10 and y % 16 >= 6 and y % 16 < 10:
				left = Color(1, 1, 0)
			for sy: int in range(SCALE):
				for sx: int in range(SCALE):
					_put(px, pw, x * SCALE + sx, y * SCALE + sy, left)
					_put(px, pw, (cw + gap + x) * SCALE + sx, y * SCALE + sy, right)
	var img: Image = Image.create_from_data(pw, ph, false, Image.FORMAT_RGB8, px)
	img.save_png(path)
	var inside: int = 0
	var seen_in: int = 0
	var unreached: int = 0
	for c: int in mine:
		if items.has(c):
			inside += 1
			unreached += 0 if items[c] else 1
			seen_in += 1 if view.shown.has(c) else 0
	print("%s: %d cells, %d items, %d in plain view, %d unreached" % [e.id, mine.size(), inside, seen_in, unreached])


func _put(px: PackedByteArray, pw: int, x: int, y: int, c: Color) -> void:
	var o: int = (y * pw + x) * 3
	if o < 0 or o + 2 >= px.size():
		return
	px[o] = int(c.r * 255)
	px[o + 1] = int(c.g * 255)
	px[o + 2] = int(c.b * 255)


# ------------------------------------------------------------------ Keen Dreams

func _dreams(d: DreamsData, doc: Dictionary, ids: PackedStringArray, source: String, out: String, game: String) -> void:
	var m16: Dictionary = d.tiles16m()
	# how much of its cell each masked tile paints (its mask clear)
	var cover: PackedInt32Array = PackedInt32Array()
	cover.resize(DreamsData.NUMTILE16M)
	for t: int in range(DreamsData.NUMTILE16M):
		var painted: int = 0
		for k: int in range(256):
			painted += 1 if m16.mask[t * 256 + k] == 0 else 0
		cover[t] = painted * 100 / 256
	if str(_opts.get("misses", "0")) != "0":
		_dreams_misses(d, doc, cover)
		return
	var t16: PackedByteArray = d.tiles16()
	var made: int = 0
	for key: String in doc.levels:
		var entries: Array = []
		for e: Dictionary in doc.levels[key]:
			if (ids.is_empty() or str(e.id) in ids) and (source == "" or str(e.get("source", "")) == source):
				entries.append(e)
		if entries.is_empty():
			continue
		var n: int = int(key)
		if not d.has_map(n):
			print("level %d: no such map" % n)
			continue
		_dreams_picture(d, n, entries, t16, m16, cover, out.path_join("%s_map%02d.png" % [game, n]))
		made += 1
	print("%d pictures in %s" % [made, out])


## An item (the info plane's 21-32) the game draws a foreground tile over, painting --cover percent
## of its cell or more.
func _dreams_hidden(d: DreamsData, m: Dictionary, p: int, cover: PackedInt32Array) -> bool:
	var v: int = m.plane[2][p]
	var f: int = m.plane[1][p]
	if v < 21 or v > 32 or f <= 0 or f >= DreamsData.NUMTILE16M:
		return false
	if (d.tileinfo[DRM_INTILE + f] & 0x80) == 0:
		return false
	return cover[f] >= int(_opts.get("cover", "75"))


func _dreams_misses(d: DreamsData, doc: Dictionary, cover: PackedInt32Array) -> void:
	var total: int = 0
	for i: int in range(DreamsData.NUM_MAPS):
		if not d.has_map(i):
			continue
		var m: Dictionary = d.load_map(i)
		if m.is_empty():
			print("map %d: %s" % [i, d.error])
			d.error = ""
			continue
		var w: int = int(m.width)
		var covered: Dictionary = {}
		for e: Dictionary in doc.levels.get(str(i), []):
			for c: Array in e.cells:
				for y: int in range(int(c[1]), int(c[3]) + 1):
					for x: int in range(int(c[0]), int(c[2]) + 1):
						covered[y * w + x] = true
		var out: PackedStringArray = PackedStringArray()
		for p: int in range(w * int(m.height)):
			if _dreams_hidden(d, m, p, cover) and not covered.has(p):
				out.append("(%d, %d) info %d cover %d%%" % [p % w, p / w, m.plane[2][p], cover[m.plane[1][p]]])
		if not out.is_empty():
			total += out.size()
			print("map %d %s: %d hidden items in no entry: %s" % [i, m.name, out.size(), ", ".join(out)])
	print("%d hidden items in no entry" % total)


func _dreams_picture(d: DreamsData, n: int, entries: Array, t16: PackedByteArray, m16: Dictionary, cover: PackedInt32Array, path: String) -> void:
	var m: Dictionary = d.load_map(n)
	if m.is_empty():
		print("level %d: %s" % [n, d.error])
		d.error = ""
		return
	var w: int = int(m.width)
	var h: int = int(m.height)
	var pw: int = w * 16
	var px: PackedByteArray = PackedByteArray()
	px.resize(pw * h * 16 * 3)
	for ty: int in range(h):
		for tx: int in range(w):
			var b: int = m.plane[0][ty * w + tx]
			var f: int = m.plane[1][ty * w + tx]
			var fore: bool = f > 0 and f < DreamsData.NUMTILE16M
			for y: int in range(16):
				for x: int in range(16):
					var k: int = y * 16 + x
					var c: int = t16[b * 256 + k] if b >= 0 and b < DreamsData.NUMTILE16 else 0
					if fore and m16.mask[f * 256 + k] == 0:
						c = m16.pixels[f * 256 + k]
					_put(px, pw, tx * 16 + x, ty * 16 + y, EGA[c & 15])
	for ty: int in range(h):
		for tx: int in range(w):
			if tx % 10 == 0:
				for y: int in range(16):
					_blend(px, pw, tx * 16, ty * 16 + y, Color(1, 1, 1), 0.35)
			if ty % 10 == 0:
				for x: int in range(16):
					_blend(px, pw, tx * 16 + x, ty * 16, Color(1, 1, 1), 0.35)
	for e: Dictionary in entries:
		var tint: Color = Color(1, 0.5, 0) if str(e.get("kind", "secret")) == "trap" else Color(1, 0, 1)
		var mine: Dictionary = {}
		for c: Array in e.cells:
			for ty: int in range(int(c[1]), int(c[3]) + 1):
				for tx: int in range(int(c[0]), int(c[2]) + 1):
					mine[ty * w + tx] = true
		var items: int = 0
		var hidden: int = 0
		for p: int in mine:
			_tint_cell(px, pw, p % w, p / w, tint, 0.35)
			# an outline along the entry's edge only
			var tx: int = p % w
			var ty: int = p / w
			for k: int in range(16):
				if not mine.has(p - w) or ty == 0:
					_put(px, pw, tx * 16 + k, ty * 16, tint)
				if not mine.has(p + w) or ty == h - 1:
					_put(px, pw, tx * 16 + k, ty * 16 + 15, tint)
				if not mine.has(p - 1) or tx == 0:
					_put(px, pw, tx * 16, ty * 16 + k, tint)
				if not mine.has(p + 1) or tx == w - 1:
					_put(px, pw, tx * 16 + 15, ty * 16 + k, tint)
			var v: int = m.plane[2][p]
			if v >= 21 and v <= 32:
				items += 1
				hidden += 1 if _dreams_hidden(d, m, p, cover) else 0
		print("%s: %d cells, %d items, %d of them hidden by the foreground" % [e.id, mine.size(), items, hidden])
	for p: int in range(w * h):
		var v: int = m.plane[2][p]
		if v == 1 or v == 2:
			_outline(px, pw, p % w, p / w, Color(0, 1, 0))
			_outline(px, pw, p % w, p / w + 1, Color(0, 1, 0))
		elif v >= 21 and v <= 32:
			var col: Color = Color(1, 0, 0) if _dreams_hidden(d, m, p, cover) else Color(1, 1, 1)
			for y: int in range(6, 10):
				for x: int in range(6, 10):
					_put(px, pw, (p % w) * 16 + x, (p / w) * 16 + y, col)
	var img: Image = Image.create_from_data(pw, h * 16, false, Image.FORMAT_RGB8, px)
	img.save_png(path)


func _tint_cell(px: PackedByteArray, pw: int, tx: int, ty: int, c: Color, a: float) -> void:
	for y: int in range(16):
		for x: int in range(16):
			_blend(px, pw, tx * 16 + x, ty * 16 + y, c, a)


func _outline(px: PackedByteArray, pw: int, tx: int, ty: int, c: Color) -> void:
	for k: int in range(16):
		_put(px, pw, tx * 16 + k, ty * 16, c)
		_put(px, pw, tx * 16 + k, ty * 16 + 15, c)
		_put(px, pw, tx * 16, ty * 16 + k, c)
		_put(px, pw, tx * 16 + 15, ty * 16 + k, c)


func _blend(px: PackedByteArray, pw: int, x: int, y: int, c: Color, a: float) -> void:
	var o: int = (y * pw + x) * 3
	if o < 0 or o + 2 >= px.size():
		return
	px[o] = int(px[o] * (1.0 - a) + c.r * 255 * a)
	px[o + 1] = int(px[o + 1] * (1.0 - a) + c.g * 255 * a)
	px[o + 2] = int(px[o + 2] * (1.0 - a) + c.b * 255 * a)
