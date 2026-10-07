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
	var dir: String = root.path_join("kdreams")
	var d: DreamsData = DreamsData.new()
	var t0: int = Time.get_ticks_msec()
	var ok: bool = d.load_game(dir)
	print("  kdreams: setup %d ms" % (Time.get_ticks_msec() - t0))
	if not t.ok("kdreams: files load (%s)" % d.error, ok):
		t.finish(self)
		return
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
	t.ok("kdreams: every picture, masked picture and sprite expands (%d failed: %s)" % [bad, d.error], bad == 0 and d.error == "")
	var tiles: PackedByteArray = d.tiles16()
	var tilesm: Dictionary = d.tiles16m()
	t.ok("kdreams: tiles expand (%s)" % d.error, d.error == "" and tiles.size() == DreamsData.NUMTILE16 * 256)
	var f: Dictionary = d.font()
	t.ok("kdreams: font parses (%s)" % d.error, not f.is_empty() and f.height > 0 and d.error == "")
	print("  kdreams digests: tiles16 %s tiles16m %s sprite0 %s pic0 %s" % [digest(tiles), digest(tilesm.pixels),
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
			t.ok("kdreams: map %d loads (%s)" % [i, d.error], false)
			d.error = ""
			continue
		if m.plane.size() == 3 and m.plane[0].size() == m.width * m.height and m.plane[2].size() == m.width * m.height:
			loaded += 1
			names.append(m.name)
	t.eq("kdreams: every map the header lists (%d) loads with three full planes" % present, loaded, present)
	t.ok("kdreams: the world map and at least 12 levels are among the %d present" % present, d.has_map(0) and present >= 13)
	print("  kdreams maps: %s" % ", ".join(names.slice(0, 6)))
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
	t.ok("kdreams: all %d audio chunks expand (%d empty slots, %d failed)" % [d.num_audio_chunks(), empty, abad], abad == 0 and d.num_audio_chunks() > 40)
	t.ok("kdreams: game, context and story text present", d.game_text.size() > 1000 and d.context_text.size() > 1000 and d.story_text.size() > 1000)
	t.ok("kdreams: tile info (%d bytes) and anti-piracy screen (%d bytes)" % [d.tileinfo.size(), d.piracy_screen.size()], d.tileinfo.size() > 5000 and d.piracy_screen.size() == 4001)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		sheet(tiles, 16, 16, DreamsData.NUMTILE16, 18).save_png(out_dir.path_join("kdreams_tiles16.png"))
		sheet(tilesm.pixels, 16, 16, DreamsData.NUMTILE16M, 18).save_png(out_dir.path_join("kdreams_tiles16m.png"))
		var p: Dictionary = d.pic(0)
		sheet(p.pixels, p.w, p.h, 1, 1).save_png(out_dir.path_join("kdreams_pic0.png"))
		var s: Dictionary = d.sprite(0)
		sheet(s.pixels, s.w, s.h, 1, 1).save_png(out_dir.path_join("kdreams_sprite0.png"))
	t.finish(self)


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
