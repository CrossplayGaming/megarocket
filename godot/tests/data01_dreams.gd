# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## DATA-01D: Keen Dreams EGA v1.00 loads from the player's folder: the
## executable unpacks (PKLITE) to the size ReflectionHLE states and its
## embedded dictionaries and headers drive the loaders; every picture, sprite
## and tile expands; every map loads with three full planes; every audio
## chunk expands; the texts are present. Writes tile sheets to --out.
##
## Options: --game_data=<folder>  --out=<folder>  --plant=<file>

const EGA: PackedColorArray = [
	Color8(0, 0, 0), Color8(0, 0, 170), Color8(0, 170, 0), Color8(0, 170, 170),
	Color8(170, 0, 0), Color8(170, 0, 170), Color8(170, 85, 0), Color8(170, 170, 170),
	Color8(85, 85, 85), Color8(85, 85, 255), Color8(85, 255, 85), Color8(85, 255, 255),
	Color8(255, 85, 85), Color8(255, 85, 255), Color8(255, 255, 85), Color8(255, 255, 255),
]


static func digest(bytes: PackedByteArray) -> String:
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	h.update(bytes)
	return h.finish().hex_encode().substr(0, 12)


static func sheet(pixels: PackedByteArray, tile_w: int, tile_h: int, count: int, per_row: int) -> Image:
	var rows: int = int(ceil(float(count) / per_row))
	var img: Image = Image.create(per_row * tile_w, max(1, rows) * tile_h, false, Image.FORMAT_RGB8)
	for t: int in range(count):
		var ox: int = (t % per_row) * tile_w
		var oy: int = (t / per_row) * tile_h
		for y: int in range(tile_h):
			for x: int in range(tile_w):
				img.set_pixel(ox + x, oy + y, EGA[pixels[t * tile_w * tile_h + y * tile_w + x] & 15])
	return img


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out_dir: String = opts.get("out", "")
	var plant: String = opts.get("plant", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	if plant != "":
		_plant(t, root, plant)
		t.finish(self)
		return
	var v100: Dictionary = _check(t, root.path_join("kdreams"), "kdreams", "e100", out_dir)
	if DirAccess.dir_exists_absolute(root.path_join("kdreams193")):
		var v193: Dictionary = _check(t, root.path_join("kdreams193"), "kdreams193", "e193", out_dir)
		if not v100.is_empty() and not v193.is_empty():
			t.eq("v1.93's graphics decode exactly as v1.00's (the same file renamed)", v193.digests, v100.digests)
			_title(t, v193.data, out_dir)
	t.finish(self)


## The checks every supported version passes; returns its digests and data.
func _check(t: T, dir: String, label: String, want: String, out_dir: String) -> Dictionary:
	var d: DreamsData = DreamsData.new()
	var t0: int = Time.get_ticks_msec()
	var ok: bool = d.load_game(dir)
	print("  %s: setup %d ms" % [label, Time.get_ticks_msec() - t0])
	if not t.ok("%s: files load (%s)" % [label, d.error], ok):
		return {}
	t.eq("%s: identified as %s" % [label, want], d.version, want)
	print("  unpacked program: %d bytes, sha1 %s" % [d.image.size(), digest(d.image)])
	var bad: int = 0
	for i: int in range(DreamsData.NUMPICS):
		if d.pic(i).is_empty():
			bad += 1
	for i: int in range(DreamsData.NUMPICM):
		if d.masked_pic(i).is_empty():
			bad += 1
	for i: int in range(DreamsData.NUMSPRITES):
		if d.sprite(i).is_empty():
			bad += 1
	t.ok("%s: every picture, masked picture and sprite expands (%d failed: %s)" % [label, bad, d.error], bad == 0 and d.error == "")
	var tiles: PackedByteArray = d.tiles16()
	var tilesm: Dictionary = d.tiles16m()
	t.ok("%s: tiles expand (%s)" % [label, d.error], d.error == "" and tiles.size() == DreamsData.NUMTILE16 * 256)
	var f: Dictionary = d.font()
	t.ok("%s: font parses (%s)" % [label, d.error], not f.is_empty() and f.height > 0 and d.error == "")
	print("  %s digests: tiles16 %s tiles16m %s sprite0 %s pic0 %s" % [label, digest(tiles), digest(tilesm.pixels),
		digest(d.sprite(0).pixels), digest(d.pic(0).pixels)])
	var present: int = 0
	var loaded: int = 0
	var names: PackedStringArray = PackedStringArray()
	for i: int in range(DreamsData.NUM_MAPS):
		if not d.has_map(i):
			continue
		present += 1
		var m: Dictionary = d.load_map(i)
		if m.is_empty():
			t.ok("%s: map %d loads (%s)" % [label, i, d.error], false)
			d.error = ""
			continue
		if m.plane.size() == 3 and m.plane[0].size() == m.width * m.height and m.plane[2].size() == m.width * m.height:
			loaded += 1
			names.append(m.name)
	t.eq("%s: every map the header lists (%d) loads with three full planes" % [label, present], loaded, present)
	t.ok("%s: the world map and at least 12 levels are among the %d present" % [label, present], d.has_map(0) and present >= 13)
	print("  %s maps: %s" % [label, ", ".join(names.slice(0, 6))])
	var abad: int = 0
	var empty: int = 0
	for c: int in range(d.num_audio_chunks()):
		var a: PackedByteArray = d.audio_chunk(c)
		if d.error != "":
			abad += 1
			print("    audio chunk %d: %s" % [c, d.error])
			d.error = ""
		elif a.is_empty():
			empty += 1
	t.ok("%s: all %d audio chunks expand (%d empty slots, %d failed)" % [label, d.num_audio_chunks(), empty, abad], abad == 0 and d.num_audio_chunks() > 40)
	t.ok("%s: game, context and story text present" % label, d.game_text.size() > 1000 and d.context_text.size() > 1000 and d.story_text.size() > 1000)
	t.ok("%s: tile info (%d bytes) and anti-piracy screen (%d bytes)" % [label, d.tileinfo.size(), d.piracy_screen.size()], d.tileinfo.size() > 5000 and d.piracy_screen.size() == (4001 if want == "e100" else 0))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		sheet(tiles, 16, 16, DreamsData.NUMTILE16, 18).save_png(out_dir.path_join(label + "_tiles16.png"))
		sheet(tilesm.pixels, 16, 16, DreamsData.NUMTILE16M, 18).save_png(out_dir.path_join(label + "_tiles16m.png"))
		var p: Dictionary = d.pic(0)
		sheet(p.pixels, p.w, p.h, 1, 1).save_png(out_dir.path_join(label + "_pic0.png"))
		var s: Dictionary = d.sprite(0)
		sheet(s.pixels, s.w, s.h, 1, 1).save_png(out_dir.path_join(label + "_sprite0.png"))
	return {"digests": [digest(tiles), digest(tilesm.pixels), digest(d.sprite(0).pixels), digest(d.pic(0).pixels)], "data": d}


## v1.93's title picture: TITLESCR.LBM from KDREAMS.CMP, an EGA-depth ILBM.
func _title(t: T, d: DreamsData, out_dir: String) -> void:
	var s: Dictionary = d.title_shape
	t.ok("kdreams193: the title picture is 320x200 in 4 planes (%s)" % str(s.keys()), s.get("w", 0) == 320 and s.get("h", 0) == 200 and s.get("d", 0) == 4)
	# ByteRun1 rows, plane after plane, as UnpackEGAShapeToScreen walks them
	var bpr: int = ((int(s.bpr) + 1) >> 1) << 1
	var data: PackedByteArray = s.data
	var src: int = 0
	var planes: Array = []
	for p: int in range(4):
		var pl: PackedByteArray = PackedByteArray()
		pl.resize(bpr * 200)
		planes.append(pl)
	var ok: bool = true
	for y: int in range(200):
		for p: int in range(4):
			var left: int = bpr
			var at: int = y * bpr
			while left > 0 and ok:
				var n: int = data[src] if s.comp != 0 else left - 1
				if s.comp != 0:
					src += 1
				if n >= 128:
					n -= 256
				if n < 0:
					if n != -128:
						var count: int = -n + 1
						var rep: int = data[src]
						src += 1
						for k: int in range(count):
							planes[p][at] = rep
							at += 1
						left -= count
					else:
						left -= 1
				else:
					var count: int = n + 1
					for k: int in range(count):
						planes[p][at] = data[src]
						at += 1
						src += 1
					left -= count
				if src > data.size():
					ok = false
	t.ok("kdreams193: the title's packed rows end exactly at the end of its data (%d of %d bytes)" % [src, data.size()], ok and src == data.size())
	if out_dir != "":
		var ega: PackedByteArray = PackedByteArray([0,0,0, 0,0,170, 0,170,0, 0,170,170, 170,0,0, 170,0,170, 170,85,0, 170,170,170,
			85,85,85, 85,85,255, 85,255,85, 85,255,255, 255,85,85, 255,85,255, 255,255,85, 255,255,255])
		var rgb: PackedByteArray = PackedByteArray()
		rgb.resize(320 * 200 * 3)
		for y: int in range(200):
			for x: int in range(320):
				var bit: int = 7 - (x & 7)
				var c: int = 0
				for p: int in range(4):
					c |= ((planes[p][y * bpr + (x >> 3)] >> bit) & 1) << p
				var o: int = (y * 320 + x) * 3
				rgb[o] = ega[c * 3]
				rgb[o + 1] = ega[c * 3 + 1]
				rgb[o + 2] = ega[c * 3 + 2]
		Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(out_dir.path_join("kdreams193_title.png"))


func _plant(t: T, root: String, plant: String) -> void:
	var src: String = root.path_join("kdreams")
	var tmp: String = OS.get_temp_dir().path_join("kdr_plant_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	var dir: DirAccess = DirAccess.open(src)
	for f: String in dir.get_files():
		dir.copy(src.path_join(f), tmp.path_join(f))
	var victim: String = ""
	for f: String in DirAccess.open(tmp).get_files():
		if f.to_upper() == plant.to_upper():
			victim = tmp.path_join(f)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(victim)
	bytes = bytes.slice(0, bytes.size() / 2)
	var w: FileAccess = FileAccess.open(victim, FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()
	var d: DreamsData = DreamsData.new()
	var ok: bool = d.load_game(tmp)
	if ok:
		for i: int in range(DreamsData.NUM_MAPS):
			if d.has_map(i) and d.load_map(i).is_empty():
				ok = false
				break
	if ok:
		for i: int in range(DreamsData.NUMSPRITES):
			if d.sprite(i).is_empty():
				ok = false
				break
	if ok:
		for c: int in range(d.num_audio_chunks()):
			d.audio_chunk(c)
			if d.error != "":
				ok = false
				break
	t.ok("a damaged %s is refused" % plant, not ok)
	t.ok("the refusal names the file (%s)" % d.error, d.error.to_upper().contains(plant.to_upper().get_basename()))
	for f: String in DirAccess.open(tmp).get_files():
		DirAccess.remove_absolute(tmp.path_join(f))
	DirAccess.remove_absolute(tmp)
