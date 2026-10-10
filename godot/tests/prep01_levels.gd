# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## PREP-01 (a level writer per engine with a round trip): for every game
## present, every level is read by the maker's reader for its engine
## (VortLevels for Keen 1-3, TedMaps for Keen 4-6 and Dreams), checked against
## what the game's own loader reads, written back, and the written files read
## again from disk. Checked: (a) the planes, size and name come back
## identical; (b) the written bytes are the original files byte for byte
## (Keen 1-3: each LEVELnn; Keen 4-6 and Dreams: the whole GAMEMAPS and
## MAPHEAD, and each map's own bytes). Also: an edited tile and name survive
## the round trip, and a new level made from nothing (with words that look
## like the compressors' tags) writes and reads back in every engine.
##
## Round-trip files go to a temporary folder, removed at the end unless
## --keep=1. Options: --game_data=<folder>  --keep=1

const VORT: Array = [["keen1", "CK1"], ["keen2", "CK2"], ["keen3", "CK3"]]
const GAL: Array = [["keen4", "keen4"], ["keen5", "keen5"], ["keen6", "keen6e14"]]
const DRM: Array = ["kdreams", "kdreams193"]
const META_ROOT: String = "res://data/omnispeak"

var t: T = T.new()
var tmp: String = ""
var summary: PackedStringArray = PackedStringArray()
var dreams_dict: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	tmp = OS.get_temp_dir().path_join("megarocket_prep01_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	var present: int = 0
	for g: Array in VORT:
		if _vorticons(root.path_join(g[0]), g[0], g[1]):
			present += 1
	for g: Array in GAL:
		if _galaxy(root.path_join(g[0]), g[0], META_ROOT.path_join(g[1])):
			present += 1
	for g: String in DRM:
		if _dreams(root.path_join(g), g):
			present += 1
	_fresh_levels()
	print("  summary:")
	for line: String in summary:
		print("    " + line)
	if present == 0:
		t.blocked("no game found in %s" % root)
	if opts.get("keep", "") != "":
		print("  round-trip files kept in %s" % tmp)
	else:
		_remove_tree(tmp)
	t.finish(self)


# ------------------------------------------------------------ Keen 1-3

func _vorticons(dir: String, game: String, ext: String) -> bool:
	var vd: VortData = VortData.new()
	vd.dir = dir
	vd.ext = ext
	var numbers: PackedInt32Array = vd.level_numbers()
	if numbers.is_empty():
		print("  %s: not present" % game)
		return false
	var t0: int = Time.get_ticks_msec()
	var out_dir: String = tmp.path_join(game)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var reader: VortLevels = VortLevels.new()
	var read_n: int = 0
	var plane_same: int = 0
	var byte_same: int = 0
	var first: KeenLevel = null
	for n: int in numbers:
		var file: String = ("LEVEL%02d." % n) + ext
		var original: PackedByteArray = FileAccess.get_file_as_bytes(_find(dir, file))
		var level: KeenLevel = reader.read(original, file, n)
		if not t.ok("%s %s: reads (%s)" % [game, file, reader.error], level != null):
			continue
		read_n += 1
		if first == null:
			first = level
		# the maker's reader against the game's own loader
		var own: Dictionary = vd.load_level(n)
		var agree: bool = not own.is_empty() and own.width == level.width and own.height == level.height \
			and own.plane.size() == level.planes.size()
		if agree:
			for p: int in range(level.planes.size()):
				agree = agree and own.plane[p] == level.planes[p]
		t.ok("%s %s: reads as VortData.load_level does (%s)" % [game, file, vd.error], agree)
		var written: PackedByteArray = reader.write(level)
		if not t.ok("%s %s: writes (%s)" % [game, file, reader.error], not written.is_empty()):
			continue
		var back: PackedByteArray = _save_and_load(out_dir.path_join(file), written)
		var again: KeenLevel = VortLevels.new().read(back, file, n)
		var diff: String = "unreadable" if again == null else level.plane_difference(again)
		if again != null and diff == "" and again.fields != level.fields:
			diff = "header fields %s, not %s" % [again.fields, level.fields]
		if t.ok("%s %s: planes identical after the round trip (%s)" % [game, file, diff], diff == ""):
			plane_same += 1
		if back == original:
			byte_same += 1
		else:
			print("  %s %s: written %d bytes, original %d, first difference at %d" % [game, file, back.size(), original.size(), _first_difference(back, original)])
	t.eq("%s: every level byte-identical" % game, byte_same, read_n)
	if first != null:
		_vorticons_edit(first, game, out_dir)
	summary.append("%s: %d levels read, %d plane-identical, %d byte-identical (%d ms)" % [game, read_n, plane_same, byte_same, Time.get_ticks_msec() - t0])
	return true


## A changed tile survives a write and a read, and nothing else changes.
func _vorticons_edit(level: KeenLevel, game: String, out_dir: String) -> void:
	var edited: KeenLevel = level.copy()
	var old: int = edited.get_word(0, 2, 2)
	edited.set_word(0, 2, 2, old ^ 1)
	var writer: VortLevels = VortLevels.new()
	var back: PackedByteArray = _save_and_load(out_dir.path_join("EDITED.LVL"), writer.write(edited))
	var again: KeenLevel = VortLevels.new().read(back, "EDITED.LVL")
	t.ok("%s: an edited tile survives the round trip" % game, again != null and again.get_word(0, 2, 2) == (old ^ 1))
	if again != null:
		again.set_word(0, 2, 2, old)
		t.eq("%s: and nothing else changed" % game, level.plane_difference(again), "")


# ------------------------------------------------------------ Keen 4-6

func _galaxy(dir: String, game: String, meta: String) -> bool:
	var ext: String = "CK" + game.substr(4, 1)
	if not FileAccess.file_exists(_find(dir, "GAMEMAPS." + ext)):
		print("  %s: not present" % game)
		return false
	var t0: int = Time.get_ticks_msec()
	var m: TedMaps = TedMaps.open_galaxy(dir, meta)
	if not t.ok("%s: maps read (%s)" % [game, m.error], m.error == ""):
		return true
	print("  %s: MAPHEAD from %s" % [game, m.head_from])
	# the maker's reader against the game's own loader
	var gd: GalData = GalData.new()
	if t.ok("%s: GalData loads (%s)" % [game, gd.error], gd.load_game(dir, meta)):
		var agree: int = 0
		for i: int in range(TedMaps.NUM_MAPS):
			var mine: KeenLevel = m.maps[i]
			if gd.has_map(i) != (mine != null):
				t.ok("%s map %d: present in both readers" % [game, i], false)
				continue
			if mine == null:
				continue
			var own: Dictionary = gd.load_map(i)
			var same: bool = not own.is_empty() and own.width == mine.width and own.height == mine.height \
				and own.name == mine.name.strip_edges()
			for p: int in range(3):
				same = same and own.plane[p] == mine.planes[p]
			if t.ok("%s map %d: reads as GalData.load_map does" % [game, i], same):
				agree += 1
		t.eq("%s: every map reads as GalData does" % game, agree, m.map_count())
	_round_trip_set(m, game, "GAMEMAPS." + ext, "MAPHEAD." + ext, t0)
	return true


# ------------------------------------------------------------ Keen Dreams

func _dreams(dir: String, label: String) -> bool:
	if not FileAccess.file_exists(_find(dir, "KDREAMS.EXE")):
		print("  %s: not present" % label)
		return false
	var t0: int = Time.get_ticks_msec()
	var m: TedMaps = TedMaps.open_dreams(dir)
	if not t.ok("%s: maps read (%s)" % [label, m.error], m.error == ""):
		return true
	print("  %s: MAPHEAD from %s" % [label, m.head_from])
	dreams_dict = m.dict
	var dd: DreamsData = DreamsData.new()
	if t.ok("%s: DreamsData loads (%s)" % [label, dd.error], dd.load_game(dir)):
		var agree: int = 0
		for i: int in range(TedMaps.NUM_MAPS):
			var mine: KeenLevel = m.maps[i]
			if dd.has_map(i) != (mine != null):
				t.ok("%s map %d: present in both readers" % [label, i], false)
				continue
			if mine == null:
				continue
			var own: Dictionary = dd.load_map(i)
			var same: bool = not own.is_empty() and own.width == mine.width and own.height == mine.height \
				and own.name == mine.name.strip_edges()
			for p: int in range(3):
				same = same and own.plane[p] == mine.planes[p]
			if t.ok("%s map %d: reads as DreamsData.load_map does (%s)" % [label, i, dd.error], same):
				agree += 1
		t.eq("%s: every map reads as DreamsData does" % label, agree, m.map_count())
	var maps_name: String = DreamsData.VERSIONS[dd.version].maps if dd.version != "" else "GAMEMAPS.KDR"
	_round_trip_set(m, label, maps_name, "MAPHEAD.KDR", t0)
	return true


# ------------------------------------------------------------ shared

## Write a whole map set, read it back from disk and compare: every map's
## planes and name, every map's bytes, and both files whole.
func _round_trip_set(m: TedMaps, game: String, maps_name: String, head_name: String, t0: int) -> void:
	var out_dir: String = tmp.path_join(game)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var written: Dictionary = m.write()
	if not t.ok("%s: the map set writes (%s)" % [game, m.error], not written.is_empty()):
		return
	var maps_back: PackedByteArray = _save_and_load(out_dir.path_join(maps_name), written.gamemaps)
	var head_back: PackedByteArray = _save_and_load(out_dir.path_join(head_name), written.maphead)
	var again: TedMaps = TedMaps.new()
	again.engine = m.engine
	again.dict = m.dict
	if not t.ok("%s: the written set reads (%s)" % [game, again.error], again.read(head_back, maps_back, maps_name)):
		return
	var read_n: int = 0
	var plane_same: int = 0
	var byte_same: int = 0
	for i: int in range(TedMaps.NUM_MAPS):
		var level: KeenLevel = m.maps[i]
		if level == null:
			t.ok("%s map %d: still absent" % [game, i], again.maps[i] == null)
			continue
		read_n += 1
		var diff: String = "missing" if again.maps[i] == null else level.plane_difference(again.maps[i])
		if diff == "" and again.maps[i].name != level.name:
			diff = "name \"%s\", not \"%s\"" % [again.maps[i].name, level.name]
		if t.ok("%s map %d (%s): planes identical after the round trip (%s)" % [game, i, level.name, diff], diff == ""):
			plane_same += 1
		var a: Vector2i = m.spans[i]
		var b: Vector2i = again.spans[i]
		if m.source_maps.slice(a.x, a.y) == maps_back.slice(b.x, b.y):
			byte_same += 1
		else:
			print("  %s map %d: its bytes differ (%d at %d written, %d at %d originally)" % [game, i, b.y - b.x, b.x, a.y - a.x, a.x])
	var maps_same: bool = maps_back == m.source_maps
	var head_same: bool = head_back == m.source_head
	if not maps_same:
		print("  %s: %s written %d bytes, original %d, first difference at %d" % [game, maps_name, maps_back.size(), m.source_maps.size(), _first_difference(maps_back, m.source_maps)])
	if not head_same:
		print("  %s: MAPHEAD written %d bytes, original %d, first difference at %d" % [game, head_back.size(), m.source_head.size(), _first_difference(head_back, m.source_head)])
	t.eq("%s: every map's bytes identical" % game, byte_same, read_n)
	t.ok("%s: %s byte-identical (%d bytes)" % [game, maps_name, maps_back.size()], maps_same)
	t.ok("%s: MAPHEAD byte-identical (%d bytes)" % [game, head_back.size()], head_same)
	summary.append("%s: %d maps read, %d plane-identical, %d byte-identical; %s %s, MAPHEAD %s (%d ms)" % [game, read_n, plane_same, byte_same,
		maps_name, "identical" if maps_same else "DIFFERENT", "identical" if head_same else "DIFFERENT", Time.get_ticks_msec() - t0])
	_set_edit(again, game, maps_name)


## In a set read back: change a foreground tile and rename the first map;
## after another write and read both changes are there and every other map
## is as it was.
func _set_edit(m: TedMaps, game: String, maps_name: String) -> void:
	var i: int = 0
	while i < TedMaps.NUM_MAPS and m.maps[i] == null:
		i += 1
	if i == TedMaps.NUM_MAPS:
		return
	var before: Array[KeenLevel] = []
	for level: KeenLevel in m.maps:
		before.append(null if level == null else level.copy())
	var target: KeenLevel = m.maps[i]
	var old: int = target.get_word(1, 3, 3)
	target.set_word(1, 3, 3, old ^ 1)
	target.name = "MAKER TEST"
	var written: Dictionary = m.write()
	var again: TedMaps = TedMaps.new()
	again.engine = m.engine
	again.dict = m.dict
	var ok: bool = not written.is_empty() and again.read(written.maphead, written.gamemaps, maps_name)
	t.ok("%s map %d: an edited tile and a new name survive the round trip (%s)" % [game, i, again.error],
		ok and again.maps[i].get_word(1, 3, 3) == (old ^ 1) and again.maps[i].name == "MAKER TEST")
	if not ok:
		return
	again.maps[i].set_word(1, 3, 3, old)
	var others: bool = true
	for k: int in range(TedMaps.NUM_MAPS):
		if before[k] != null:
			others = others and before[k].plane_difference(again.maps[k]) == ""
	t.ok("%s: and nothing else changed" % game, others)


## A level made from nothing, in every engine: odd sizes, runs, and words
## that look like the RLEW tags (FEFE, ABCD) and Carmack's tags (A7xx, A8xx).
func _fresh_levels() -> void:
	var specials: Array = [0xFEFE, 0xABCD, 0xA700, 0xA7FF, 0xA812, 0xA800, 0x00A7]
	var engines: Array = [KeenLevel.VORTICONS, KeenLevel.GALAXY]
	if dreams_dict.size() >= 512:
		engines.append(KeenLevel.DREAMS)
	for engine: String in engines:
		var level: KeenLevel = KeenLevel.create(engine, 37, 19, "FRESH")
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 2026
		for p: int in range(level.plane_count()):
			for i: int in range(level.width * level.height):
				var r: int = rng.randi_range(0, 9)
				if r < 4:
					level.planes[p][i] = level.planes[p][i - 1] if i > 0 else 0      # runs
				elif r < 6:
					level.planes[p][i] = specials[rng.randi_range(0, specials.size() - 1)]
				elif r < 8 and i >= 40:
					level.planes[p][i] = level.planes[p][i - 37 - rng.randi_range(0, 3)]  # repeats a row up
				else:
					level.planes[p][i] = rng.randi_range(0, 0xFFFF)
		var again: KeenLevel = null
		if engine == KeenLevel.VORTICONS:
			var w: VortLevels = VortLevels.new()
			var bytes: PackedByteArray = w.write(level)
			t.eq("new Keen 1-3 level: expanded size with planes rounded to 16 bytes", bytes.decode_u32(0) if bytes.size() >= 4 else -1,
				32 + 2 * ((37 * 19 * 2 + 15) / 16 * 16))
			again = VortLevels.new().read(bytes, "new level")
		else:
			var m: TedMaps = TedMaps.new()
			m.engine = engine
			m.dict = dreams_dict
			level.number = 7
			m.maps[7] = level
			var written: Dictionary = m.write()
			var back: TedMaps = TedMaps.new()
			back.engine = engine
			back.dict = dreams_dict
			if t.ok("new %s level: writes (%s)" % [engine, m.error], not written.is_empty()) \
					and t.ok("new %s level: reads back (%s)" % [engine, back.error], back.read(written.maphead, written.gamemaps, "new")):
				again = back.maps[7]
				t.ok("new %s level: GAMEMAPS starts with TED5's signature" % engine, written.gamemaps.slice(0, 8).get_string_from_ascii() == TedMaps.SIGNATURE)
				t.eq("new %s level: the name" % engine, again.name if again != null else "", "FRESH")
		t.eq("new %s level: planes identical after the round trip" % engine, level.plane_difference(again), "")


static func _find(dir: String, name: String) -> String:
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			if f.to_upper() == name.to_upper():
				return dir.path_join(f)
	return dir.path_join(name)


## Write `bytes` to `path` and read them back from the disk.
func _save_and_load(path: String, bytes: PackedByteArray) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		t.ok("can write %s (%s)" % [path, error_string(FileAccess.get_open_error())], false)
		return PackedByteArray()
	f.store_buffer(bytes)
	f.close()
	return FileAccess.get_file_as_bytes(path)


static func _first_difference(a: PackedByteArray, b: PackedByteArray) -> int:
	for i: int in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			return i
	return mini(a.size(), b.size())


## Remove this test's own temporary folder and what it wrote there.
static func _remove_tree(path: String) -> void:
	if not path.get_file().begins_with("megarocket_prep01_") and not path.get_base_dir().get_file().begins_with("megarocket_prep01_"):
		return
	for sub: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
