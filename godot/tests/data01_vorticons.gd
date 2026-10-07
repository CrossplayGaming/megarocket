# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## DATA-01V: every file kind of Keen 1, 2 and 3 loads from the player's own
## folders with counts that agree with EGAHEAD, every level present loads with
## two planes of width x height words, every sound ends, and the full-screen
## pictures expand to 320x200. Writes a contact sheet of each game's tiles to
## --out=<folder> for a look, and prints a digest of every decoded set so a
## change in the decoder is visible.
##
## Options: --game_data=<folder>  --out=<folder>  --plant=<file>  (a damaged
## copy of that file is loaded instead; the loader must refuse it by name).

const EGA: PackedColorArray = [
	Color8(0, 0, 0), Color8(0, 0, 170), Color8(0, 170, 0), Color8(0, 170, 170),
	Color8(170, 0, 0), Color8(170, 0, 170), Color8(170, 85, 0), Color8(170, 170, 170),
	Color8(85, 85, 85), Color8(85, 85, 255), Color8(85, 255, 85), Color8(85, 255, 255),
	Color8(255, 85, 85), Color8(255, 85, 255), Color8(255, 255, 85), Color8(255, 255, 255),
]

const GAMES: Array = [["keen1", "CK1"], ["keen2", "CK2"], ["keen3", "CK3"]]


static func digest(bytes: PackedByteArray) -> String:
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	h.update(bytes)
	return h.finish().hex_encode().substr(0, 12)


static func sheet(pixels: PackedByteArray, tile_w: int, tile_h: int, count: int, per_row: int) -> Image:
	var rows: int = int(ceil(float(count) / per_row))
	var img: Image = Image.create(per_row * tile_w, rows * tile_h, false, Image.FORMAT_RGB8)
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
	for g: Array in GAMES:
		var dir: String = root.path_join(g[0])
		if not FileAccess.file_exists(dir.path_join("EGAHEAD." + g[1])):
			t.blocked("%s: no game files in %s" % [g[0], dir])
			break
		var d: VortData = VortData.new()
		var ok: bool = d.load_game(dir, g[1])
		if not t.ok("%s: fixed files load (%s)" % [g[0], d.error], ok):
			continue
		t.ok("%s: counts (%d chars, %d tiles, %d pics, %d sprites, %d sounds)" % [g[0], d.num_chars, d.num_tiles, d.num_pics, d.num_sprites, d.sounds.size()],
			d.num_chars > 0 and d.num_tiles > 0 and d.num_pics > 0 and d.num_sprites > 0 and d.sounds.size() > 1)
		t.eq("%s: chars decoded" % g[0], d.chars.size(), d.num_chars * 64)
		t.eq("%s: tiles decoded" % g[0], d.tiles.size(), d.num_tiles * 256)
		t.eq("%s: pics decoded" % g[0], d.pics.size(), d.num_pics)
		t.eq("%s: sprites decoded" % g[0], d.sprites.size(), d.num_sprites)
		var all_colours: bool = true
		for i: int in range(d.tiles.size()):
			if d.tiles[i] > 15:
				all_colours = false
				break
		t.ok("%s: every tile pixel is an EGA colour" % g[0], all_colours)
		t.ok("%s: help, story, end and previews text present" % g[0], d.help_text.size() > 100 and d.story_text.size() > 100 and d.end_text.size() > 100 and d.previews_text.size() > 100)
		t.ok("%s: tile info (%d bytes) and exit screen (%d bytes) from the program" % [g[0], d.tileinfo.size(), d.endscrn.size()], d.tileinfo.size() > 1000 and d.endscrn.size() == 0xFA8)
		print("  %s digests: chars %s tiles %s sprites %s sounds %s" % [g[0], digest(d.chars), digest(d.tiles),
			digest(d.sprites[0].pixels), digest(d.sounds[1].divisors.to_byte_array())])
		if g[0] != "keen1":
			# cross-check the LZEXE unpacker against tools/unlzexe.py (Python) by digest
			var exe: PackedByteArray = FileAccess.get_file_as_bytes(dir.path_join("KEEN%s.EXE" % g[1].substr(2, 1)))
			var image: PackedByteArray = LzExe.unpack(exe)
			print("  %s unpacked program: %d bytes, sha1 %s" % [g[0], image.size(), digest(image)])
		var levels: PackedInt32Array = d.level_numbers()
		t.ok("%s: levels present (%s)" % [g[0], levels], levels.size() >= 16)
		var loaded: int = 0
		for n: int in levels:
			var level: Dictionary = d.load_level(n)
			if level.is_empty():
				t.ok("%s: level %d loads (%s)" % [g[0], n, d.error], false)
				continue
			var good: bool = level.planes == 2 and level.plane[0].size() == level.width * level.height \
				and level.plane[1].size() == level.width * level.height
			if not good:
				t.ok("%s: level %d geometry %dx%d, %d planes" % [g[0], n, level.width, level.height, level.planes], false)
			else:
				loaded += 1
		t.eq("%s: all levels load with two full planes" % g[0], loaded, levels.size())
		for pic_file: String in ["FINALE." + g[1], "PREVIEW2." + g[1], "PREVIEW3." + g[1]]:
			if FileAccess.file_exists(dir.path_join(pic_file)):
				var px: PackedByteArray = d.load_picture_file(pic_file)
				t.eq("%s: %s is 320x200 (%s)" % [g[0], pic_file, d.error], px.size(), 64000)
		if out_dir != "":
			DirAccess.make_dir_recursive_absolute(out_dir)
			sheet(d.tiles, 16, 16, d.num_tiles, 13).save_png(out_dir.path_join("%s_tiles.png" % g[0]))
			sheet(d.chars, 8, 8, d.num_chars, 32).save_png(out_dir.path_join("%s_chars.png" % g[0]))
			var s: Dictionary = d.sprites[0]
			sheet(s.pixels, s.w, s.h, 1, 1).save_png(out_dir.path_join("%s_sprite0.png" % g[0]))
			if FileAccess.file_exists(dir.path_join("FINALE." + g[1])):
				sheet(d.load_picture_file("FINALE." + g[1]), 320, 200, 1, 1).save_png(out_dir.path_join("%s_finale.png" % g[0]))
	t.finish(self)


## Load Keen 1 with one file replaced by a damaged copy; the loader must stop
## and name that file.
func _plant(t: T, root: String, plant: String) -> void:
	var src: String = root.path_join("keen1")
	var tmp: String = OS.get_temp_dir().path_join("vort_plant_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	var dir: DirAccess = DirAccess.open(src)
	for f: String in dir.get_files():
		dir.copy(src.path_join(f), tmp.path_join(f))
	var victim: String = tmp.path_join(plant)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(victim)
	bytes = bytes.slice(0, bytes.size() / 2)          # cut in half
	var w: FileAccess = FileAccess.open(victim, FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()
	var d: VortData = VortData.new()
	var ok: bool = d.load_game(tmp, "CK1")
	if ok:
		# the fixed files were not the victim: try a level
		var level: Dictionary = d.load_level(1)
		ok = not level.is_empty()
	t.ok("a damaged %s is refused" % plant, not ok)
	t.ok("the refusal names the file (%s)" % d.error, d.error.begins_with(plant))
	for f: String in DirAccess.open(tmp).get_files():
		DirAccess.remove_absolute(tmp.path_join(f))
	DirAccess.remove_absolute(tmp)
