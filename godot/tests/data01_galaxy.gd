# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## DATA-01G: Keen 4, 5 and 6 load from the player's folders with omnispeak's
## metadata: every graphics chunk the tables name expands, every map the
## episode lists loads with three full planes, every audio chunk expands, and
## the strings/actions/chunk-name files parse. Writes tile sheets to --out.
##
## Options: --game_data=<folder>  --out=<folder>  --plant=<file>  (keen4 copy
## with that file damaged; the loader must refuse it by name)

const EGA: PackedColorArray = [
	Color8(0, 0, 0), Color8(0, 0, 170), Color8(0, 170, 0), Color8(0, 170, 170),
	Color8(170, 0, 0), Color8(170, 0, 170), Color8(170, 85, 0), Color8(170, 170, 170),
	Color8(85, 85, 85), Color8(85, 85, 255), Color8(85, 255, 85), Color8(85, 255, 255),
	Color8(255, 85, 85), Color8(255, 85, 255), Color8(255, 255, 85), Color8(255, 255, 255),
]

const GAMES: Array = [["keen4", "keen4"], ["keen5", "keen5"], ["keen6", "keen6e14"]]


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
	var meta_root: String = "res://data/omnispeak"
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	if plant != "":
		_plant(t, root, meta_root, plant)
		t.finish(self)
		return
	var only: String = opts.get("only", "")
	var games: PackedStringArray = PackedStringArray(opts.get("games", "keen4,keen5,keen6").split(","))
	for g: Array in GAMES:
		if only != "" and g[0] != only:
			continue
		if not games.has(g[0]):
			continue
		var dir: String = root.path_join(g[0])
		var d: GalData = GalData.new()
		var t0: int = Time.get_ticks_msec()
		var ok: bool = d.load_game(dir, meta_root.path_join(g[1]))
		print("  %s: setup %d ms" % [g[0], Time.get_ticks_msec() - t0])
		if not t.ok("%s: files load (%s)" % [g[0], d.error], ok):
			continue
		if g[0] == "keen6":
			t.ok("keen6: the three version tables come from the executable (%s)" % d.exe_build, d.exe_build != "")
			_without_exe(t, dir, meta_root.path_join(g[1]))
		var gfx: Dictionary = d.gfx
		t.ok("%s: tables (%d bitmaps, %d masked, %d sprites, %d tiles16, %d tiles16m, %d chunks)" %
			[g[0], gfx.numBitmaps, gfx.numMasked, gfx.numSprites, gfx.numTiles16, gfx.numTiles16m, d.num_chunks],
			gfx.numBitmaps > 0 and gfx.numSprites > 100 and gfx.numTiles16 > 100 and d.num_chunks > 1000)
		# every chunk the tables name expands
		var bad: int = 0
		var absent: int = 0
		for i: int in range(gfx.numBitmaps):
			if d.bitmap(i).is_empty():
				bad += 1
		for i: int in range(gfx.numMasked):
			if d.masked_bitmap(i).is_empty():
				bad += 1
		for i: int in range(gfx.numSprites):
			if d.sprite(i).is_empty():
				bad += 1
		t.ok("%s: every bitmap, masked bitmap and sprite expands (%d failed: %s)" % [g[0], bad, d.error], bad == 0 and d.error == "")
		print("  %s: graphics %d ms" % [g[0], Time.get_ticks_msec() - t0])
		t0 = Time.get_ticks_msec()
		var tiles: PackedByteArray = d.tiles16()
		var tilesm: Dictionary = d.tiles16m()
		t.ok("%s: tiles expand (%s)" % [g[0], d.error], d.error == "" and tiles.size() == gfx.numTiles16 * 256)
		var fonts_ok: bool = true
		for c: int in [d.chunk_names.get_int("FON_MAINFONT"), d.chunk_names.get_int("FON_WATCHFONT")]:
			var f: Dictionary = d.font(c)
			if f.is_empty() or f.height <= 0 or f.glyphs.size() != 256:
				fonts_ok = false
		t.ok("%s: fonts parse (%s)" % [g[0], d.error], fonts_ok and d.error == "")
		print("  %s digests: tiles16 %s tiles16m %s sprite0 %s bitmap0 %s" % [g[0], digest(tiles), digest(tilesm.pixels),
			digest(d.sprite(0).pixels), digest(d.bitmap(0).pixels)])
		# maps: the world map and every level the episode lists
		var hi: int = d.episode.get_int("ck_maxDoneLevel", 17)
		var present: int = 0
		var loaded: int = 0
		var names: PackedStringArray = PackedStringArray()
		for i: int in range(GalData.NUM_MAPS):
			if not d.has_map(i):
				continue
			present += 1
			var m: Dictionary = d.load_map(i)
			if m.is_empty():
				t.ok("%s: map %d loads (%s)" % [g[0], i, d.error], false)
				d.error = ""
				continue
			var good: bool = m.plane.size() == 3 and m.plane[0].size() == m.width * m.height and m.plane[2].size() == m.width * m.height
			if good:
				loaded += 1
				names.append(m.name)
		print("  %s: maps %d ms" % [g[0], Time.get_ticks_msec() - t0])
		t0 = Time.get_ticks_msec()
		t.eq("%s: every map MAPHEAD lists (%d) loads with three full planes" % [g[0], present], loaded, present)
		t.ok("%s: the world map and at least 15 levels are among them" % g[0], d.has_map(0) and present >= 15)
		print("  %s maps: %s" % [g[0], ", ".join(names.slice(0, 6))])
		# audio: every chunk the tables cover
		var aud: Dictionary = d.aud
		var abad: int = 0
		var empty: int = 0
		for c: int in range(d.num_audio_chunks()):
			var a: PackedByteArray = d.audio_chunk(c)
			if d.error != "":
				abad += 1
				d.error = ""
			elif a.is_empty():
				empty += 1
		t.ok("%s: all %d audio chunks expand (%d sounds, %d songs; %d empty slots, %d failed)" %
			[g[0], d.num_audio_chunks(), aud.numSounds, aud.numSongs, empty, abad], abad == 0 and d.num_audio_chunks() >= aud.startMusic + aud.numSongs)
		print("  %s: audio %d ms" % [g[0], Time.get_ticks_msec() - t0])
		t.ok("%s: strings and actions parsed (%d strings, %d actions)" % [g[0], d.strings.strings.size(), d.actions.action_order.size()],
			d.strings.strings.size() > 20 and d.actions.action_order.size() > 100)
		t.ok("%s: tile info present (%d bytes)" % [g[0], d.tileinfo.size()], d.tileinfo.size() > 1000)
		if out_dir != "":
			DirAccess.make_dir_recursive_absolute(out_dir)
			sheet(tiles, 16, 16, gfx.numTiles16, 18).save_png(out_dir.path_join("%s_tiles16.png" % g[0]))
			sheet(tilesm.pixels, 16, 16, gfx.numTiles16m, 18).save_png(out_dir.path_join("%s_tiles16m.png" % g[0]))
			var b: Dictionary = d.bitmap(0)
			sheet(b.pixels, b.w, b.h, 1, 1).save_png(out_dir.path_join("%s_bitmap0.png" % g[0]))
			var s: Dictionary = d.sprite(0)
			sheet(s.pixels, s.w, s.h, 1, 1).save_png(out_dir.path_join("%s_sprite0.png" % g[0]))
	t.finish(self)


## A copy of the Keen 6 folder without its executable: v1.0 data cannot be
## read through the v1.4 headers, and the message must say what to do.
func _without_exe(t: T, src: String, meta: String) -> void:
	var tmp: String = OS.get_temp_dir().path_join("gal_noexe_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	var dir: DirAccess = DirAccess.open(src)
	for f: String in dir.get_files():
		if not f.to_upper().ends_with(".EXE"):
			dir.copy(src.path_join(f), tmp.path_join(f))
	var d: GalData = GalData.new()
	var ok: bool = d.load_game(tmp, meta)
	t.ok("keen6: without the executable the v1.0 data is refused, naming the remedy (%s)" % d.error,
		not ok and d.error.contains("v1.0") and d.error.contains("KEEN6C.EXE"))
	for f: String in DirAccess.open(tmp).get_files():
		DirAccess.remove_absolute(tmp.path_join(f))
	DirAccess.remove_absolute(tmp)


func _plant(t: T, root: String, meta_root: String, plant: String) -> void:
	# a Keen 6 name damages the Keen 6 copy (its executable included)
	var six: bool = plant.to_upper().contains("6")
	var src: String = root.path_join("keen6" if six else "keen4")
	var tmp: String = OS.get_temp_dir().path_join("gal_plant_%d" % Time.get_ticks_usec())
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
	var d: GalData = GalData.new()
	var ok: bool = d.load_game(tmp, meta_root.path_join("keen6e14" if six else "keen4"))
	if ok:
		# the damage is deeper in: touch every map and every chunk
		for i: int in range(0, 19):
			if d.load_map(i).is_empty():
				ok = false
				break
	if ok:
		for i: int in range(d.gfx.numSprites):
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
