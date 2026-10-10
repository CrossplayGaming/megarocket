# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SecretFinder review: every level of a game run through the finder; a marked-up picture per level
## (secret areas tinted magenta, passages tinted cyan and outlined yellow, dents orange, Keen's start
## outlined green, items dotted white, a faint line every 10 tiles) and a summary on stdout and in
## <out>/<game>_secrets.json.
##
##   godot --headless --path godot --script res://harness/secret_report.gd -- --game_data=<folder>
##         --out=<folder> [--game=keen4|keen3] [--levels=1,2,3] [--body_h=2] [--fore_opaque=0.0]
##         [--min_area=1] [--jump=N] [--drift=N] [--gravity=0] [--pictures=0] [--all=1]
## Items no route reaches are dotted red.

const SF = preload("res://maker/secret_finder.gd")

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
	var out: String = str(_opts.get("out", OS.get_temp_dir().path_join("secrets")))
	var game: String = str(_opts.get("game", "keen4"))
	DirAccess.make_dir_recursive_absolute(out)
	var fopts: Dictionary = {"body_h": int(_opts.get("body_h", "2")), "fore_opaque": float(_opts.get("fore_opaque", "0")),
		"min_area": int(_opts.get("min_area", "1")), "gravity": str(_opts.get("gravity", "1")) != "0",
		"drift": int(_opts.get("drift", "8"))}
	if _opts.has("edges"):
		fopts.edges = str(_opts.edges) != "0"
	if _opts.has("jump"):
		fopts.jump = int(_opts.jump)
	var pictures: bool = str(_opts.get("pictures", "1")) != "0"
	var summary: Array = []
	if game in ["keen4", "keen5", "keen6"]:
		var d: GalData = GalData.new()
		if not d.load_game(root.path_join(game), "res://data/omnispeak/" + ("keen6e14" if game == "keen6" else game)):
			print("load failed: ", d.error)
			quit(1)
			return
		var imgs: GalImages = GalImages.new(d)
		var levels: Array = _levels(range(GalData.NUM_MAPS))
		for i: int in levels:
			if not d.has_map(i):
				continue
			var r: Dictionary = SF.galaxy(d, imgs, i, fopts)
			if r.is_empty():
				continue
			summary.append(_report(game, i, r))
			if pictures:
				_picture_galaxy(d, imgs, i, r, out.path_join("%s_map%02d.png" % [game, i]))
	else:
		var d: VortData = VortData.new()
		var ext: String = "CK" + game.substr(4, 1)
		if not d.load_game(root.path_join(game), ext):
			print("load failed: ", d.error)
			quit(1)
			return
		var levels: Array = _levels(Array(d.level_numbers()))
		for n: int in levels:
			if not d.has_file(("LEVEL%02d." % n) + ext):
				continue
			var r: Dictionary = SF.vorticons(d, n, fopts)
			if r.is_empty():
				continue
			summary.append(_report(game, n, r))
			if pictures:
				_picture_vort(d, r, out.path_join("%s_level%02d.png" % [game, n]))
	var f: FileAccess = FileAccess.open(out.path_join(game + "_secrets.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, " "))
	f.close()
	quit(0)


func _levels(all: Array) -> Array:
	if not _opts.has("levels"):
		return all
	var out: Array = []
	for s: String in str(_opts.levels).split(","):
		out.append(int(s))
	return out


func _report(game: String, n: int, r: Dictionary) -> Dictionary:
	var w: int = int(r.width)
	var regs: Array = []
	var cnt: Callable = func(a: PackedByteArray) -> int:
		var k: int = 0
		for v: int in a:
			k += 1 if v != 0 else 0
		return k
	var unreached: PackedStringArray = PackedStringArray()
	for c: Array in r.items:
		if c[2] == "unreached":
			unreached.append("%s@%d,%d" % [c[1], c[0] % w, c[0] / w])
	print("%s %d %s (%dx%d) start %s: %d regions  [lookalike %d, invisible %d, reach real %d, visual %d]" % [game, n, r.name, w, r.height,
		r.start, r.regions.size(), cnt.call(r.lookalike), cnt.call(r.invisible), cnt.call(r.reach_real), cnt.call(r.reach_visual)])
	var lives: PackedStringArray = PackedStringArray()
	for c: Array in r.items:
		if c[1] == "1UP" or c[1] == "5000" or c[1] == "ankh":
			lives.append("%s@%d,%d:%s" % [c[1], c[0] % w, c[0] / w, c[2]])
	if not lives.is_empty() and _opts.has("lives"):
		print("   lives/5000: ", " ".join(lives))
	var plats: PackedStringArray = PackedStringArray()
	for p: int in range(w * int(r.height)):
		if r.invisible[p] != 0:
			plats.append("%d,%d" % [p % w, p / w])
	if not plats.is_empty():
		print("   hidden platforms (%d): %s" % [plats.size(), " ".join(plats.slice(0, 40))])
	if not unreached.is_empty():
		print("   items unreached (%d): %s" % [unreached.size(), " ".join(unreached.slice(0, 40))])
	for reg: Dictionary in r.regions:
		var line: Dictionary = {"kind": reg.kind, "x0": reg.x0, "y0": reg.y0, "x1": reg.x1, "y1": reg.y1,
			"passages": reg.passages.size(), "areas": reg.areas.size(), "platforms": reg.platforms.size(), "contacts": reg.contacts,
			"contents": reg.contents}
		regs.append(line)
		if reg.kind == "dent" and reg.contents.is_empty() and not _opts.has("all"):
			continue
		print("   %-8s x %d-%d y %d-%d  passages %d platforms %d areas %d contacts %d  %s" % [reg.kind, reg.x0, reg.x1, reg.y0, reg.y1,
			reg.passages.size(), reg.platforms.size(), reg.areas.size(), reg.contacts, ", ".join(PackedStringArray(reg.contents))])
	return {"level": n, "name": r.name, "width": w, "height": r.height, "start": [r.start.x, r.start.y], "regions": regs,
		"hidden_platforms": Array(plats)}


func _picture_galaxy(d: GalData, imgs: GalImages, i: int, r: Dictionary, path: String) -> void:
	var m: Dictionary = d.load_map(i)
	var w: int = int(m.width)
	var h: int = int(m.height)
	var px: PackedByteArray = PackedByteArray()
	px.resize(w * 16 * h * 16 * 3)
	for ty: int in range(h):
		for tx: int in range(w):
			var b: int = m.plane[0][ty * w + tx]
			var f: int = m.plane[1][ty * w + tx]
			var bi: Dictionary = imgs.tile(b)
			var fi: Dictionary = imgs.mtile(f) if f > 0 else {}
			for y: int in range(16):
				for x: int in range(16):
					var k: int = y * 16 + x
					var c: int = 0 if bi.is_empty() else bi.pixels[k]
					if not fi.is_empty() and fi.mask[k] == 0:
						c = fi.pixels[k]
					_put(px, w * 16, tx * 16 + x, ty * 16 + y, EGA[c & 15])
	_marks(px, r)
	_save(px, w * 16, h * 16, path)


func _picture_vort(d: VortData, r: Dictionary, path: String) -> void:
	var w: int = int(r.width)
	var h: int = int(r.height)
	var tp: PackedInt32Array = r.tiles
	var px: PackedByteArray = PackedByteArray()
	px.resize(w * 16 * h * 16 * 3)
	for ty: int in range(h):
		for tx: int in range(w):
			var t: int = tp[ty * w + tx]
			for y: int in range(16):
				for x: int in range(16):
					var c: int = 0
					if t >= 0 and t * 256 + 256 <= d.tiles.size():
						c = d.tiles[t * 256 + y * 16 + x]
					_put(px, w * 16, tx * 16 + x, ty * 16 + y, EGA[c & 15])
	_marks(px, r)
	_save(px, w * 16, h * 16, path)


func _marks(px: PackedByteArray, r: Dictionary) -> void:
	var w: int = int(r.width)
	var h: int = int(r.height)
	var pw: int = w * 16
	if str(_opts.get("show_reach", "1")) != "0":
		# open cells no route reaches, darkened
		for p: int in range(w * h):
			if r.reach_real[p] == 0 and r.real[p] == 0:
				_tint_cell(px, pw, p % w, p / w, Color(0, 0, 0), 0.45)
	for reg: Dictionary in r.regions:
		if reg.kind == "dent" and reg.contents.is_empty() and not _opts.has("all"):
			continue
		var tint: Color = Color(1, 0, 1) if reg.kind == "area" else (Color(0, 1, 1) if reg.kind == "shortcut" else Color(1, 0.5, 0))
		for p: int in reg.areas:
			_tint_cell(px, pw, p % w, p / w, tint, 0.45)
		for p: int in reg.passages:
			_tint_cell(px, pw, p % w, p / w, Color(0, 1, 1) if reg.kind != "dent" else Color(1, 0.5, 0), 0.35)
			_outline(px, pw, p % w, p / w, Color(1, 1, 0))
		for p: int in reg.platforms:
			_tint_cell(px, pw, p % w, p / w, Color(0, 1, 0), 0.5)
			_outline(px, pw, p % w, p / w, Color(1, 1, 1))
	# every hidden platform, in a region or not
	for p: int in range(w * h):
		if r.invisible[p] != 0:
			_outline(px, pw, p % w, p / w, Color(1, 1, 1))
	# faint lines every 10 tiles
	for ty: int in range(h):
		for tx: int in range(w):
			if tx % 10 == 0:
				for y: int in range(16):
					_blend(px, pw, tx * 16, ty * 16 + y, Color(1, 1, 1), 0.35)
			if ty % 10 == 0:
				for x: int in range(16):
					_blend(px, pw, tx * 16 + x, ty * 16, Color(1, 1, 1), 0.35)
	var s: Vector2i = r.start
	if s.x >= 0:
		_outline(px, pw, s.x, s.y, Color(0, 1, 0))
		_outline(px, pw, s.x, s.y + 1, Color(0, 1, 0))
	for c: Array in r.items:
		var p: int = c[0]
		var col: Color = Color(1, 1, 1) if c[2] != "unreached" else Color(1, 0, 0)
		for y: int in range(6, 10):
			for x: int in range(6, 10):
				_put(px, pw, (p % w) * 16 + x, (p / w) * 16 + y, col)


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


func _put(px: PackedByteArray, pw: int, x: int, y: int, c: Color) -> void:
	var o: int = (y * pw + x) * 3
	if o < 0 or o + 2 >= px.size():
		return
	px[o] = int(c.r * 255)
	px[o + 1] = int(c.g * 255)
	px[o + 2] = int(c.b * 255)


func _blend(px: PackedByteArray, pw: int, x: int, y: int, c: Color, a: float) -> void:
	var o: int = (y * pw + x) * 3
	if o < 0 or o + 2 >= px.size():
		return
	px[o] = int(px[o] * (1.0 - a) + c.r * 255 * a)
	px[o + 1] = int(px[o + 1] * (1.0 - a) + c.g * 255 * a)
	px[o + 2] = int(px[o + 2] * (1.0 - a) + c.b * 255 * a)


func _save(px: PackedByteArray, pw: int, ph: int, path: String) -> void:
	var img: Image = Image.create_from_data(pw, ph, false, Image.FORMAT_RGB8, px)
	img.save_png(path)
