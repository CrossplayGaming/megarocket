# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-03, V15-02..04: the editor's document (maker/maker_model.gd) and the library, headless, for Keen 1,
## Keen 4 and Keen Dreams. Opening lists the game's levels; a remix is a copy (the game's own level never
## changes); a drag of three cells is one undo step, undo and redo; a filled rectangle is one step; Keen's
## start moved leaves exactly one; a new level has the engine's size, a solid frame, ground of the game's
## own tiles (by use) and Keen standing on it; the library (the player's folder) saves, lists, reads back
## equal, renames, duplicates and deletes; the play request from the cursor carries a copy with Keen there
## (the level being made unchanged), written in the engine's own format and read back by its reader with
## the game's other levels as they were. The tile-use tables (PREP-01): every tile sorted by its engine
## properties (a sample of each kind checked against them), the palette's creatures named.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for game: String in ["keen1", "keen4", "kdreams"]:
		_game(root, game)
	t.finish(self)


func _game(root: String, game: String) -> void:
	var m: MakerModel = MakerModel.new()
	if not t.ok("%s opens (%s)" % [game, m.error], m.open(game, root.path_join(game))):
		return
	var list: Array = m.level_list()
	t.ok("%s: its levels listed (%d, first %s)" % [game, list.size(), list[0] if not list.is_empty() else "none"],
		list.size() >= {"keen1": 16, "keen4": 18, "kdreams": 14}[game])
	m.remix(1)
	var l: KeenLevel = m.level
	var own: KeenLevel = m.original(1).copy()
	var before: KeenLevel = l.copy()
	var cells: Array = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
	m.begin_stroke()
	for c: Vector2i in cells:
		m.paint(0, c.x, c.y, (l.get_word(0, c.x, c.y) + 1) % 200)
	m.end_stroke()
	var painted: KeenLevel = l.copy()
	t.ok("%s: the drag changed three cells (%s)" % [game, before.plane_difference(painted)], before.plane_difference(painted) != "")
	t.ok("%s: a remix is a copy: the game's own level 1 unchanged" % game, own.plane_difference(m.original(1)) == "")
	m.undo()
	t.ok("%s: one undo puts all three back" % game, before.plane_difference(l) == "" and m._undo.is_empty())
	m.redo()
	t.ok("%s: redo makes them again" % game, painted.plane_difference(l) == "")
	var n: int = m.fill_rect(0, Vector2i(12, 8), Vector2i(10, 6), l.get_word(0, 10, 6) ^ 1)
	var undo_steps: int = m._undo.size()
	m.undo()
	t.ok("%s: a 3x3 rectangle filled (%d cells changed) is one undo step" % [game, n], n > 0 and n <= 9 and painted.plane_difference(l) == ""
		and undo_steps == 2)
	var s0: Vector2i = m.start_at()
	m.place_start(s0.x + 3, s0.y)
	t.ok("%s: Keen's start moved from %s to %s, the only one" % [game, s0, m.start_at()], m.start_at() == Vector2i(s0.x + 3, s0.y) and _starts(m, l) == 1)
	# the play request from the cursor: a copy with Keen there, written in the engine's format
	var cursor: Vector2i = Vector2i(s0.x - 4 if s0.x >= 6 else s0.x + 5, s0.y)
	var kept: KeenLevel = l.copy()
	var req: Dictionary = m.play_request("Test", cursor)
	var played: KeenLevel = _read_back(m, req, 1)
	t.ok("%s: play from the cursor: the written level has Keen at %s, the only one (%s)" % [game, cursor, m.start_at(played) if played != null else "not read"],
		played != null and m.start_at(played) == cursor and _starts(m, played) == 1)
	t.ok("%s: and the level being made is unchanged (Keen still at %s)" % [game, m.start_at()], kept.plane_difference(l) == "")
	if m.engine != KeenLevel.VORTICONS:
		var other: KeenLevel = _read_back(m, req, 2)
		t.ok("%s: the set's other levels as the game's own (level 2)" % game, other != null and other.plane_difference(m.original(2)) == "")
	# a new level
	t.ok("%s: a new level (%s)" % [game, m.error], m.new_level("Test level"))
	var nl: KeenLevel = m.level
	var size: Vector2i = MakerModel.NEW_SIZE[m.engine]
	var s: Vector2i = m.start_at()
	var tp: int = m.parts.tile_plane()
	var ground_y: int = nl.height - MakerModel.NEW_GROUND
	var below: int = nl.get_word(tp, s.x, ground_y)
	t.ok("%s: the new level is %dx%d, Keen's start at %s over ground (%s, tile %d)" % [game, nl.width, nl.height, s, m.parts.use_of(tp, below), below],
		nl.width == size.x and nl.height == size.y and s.x >= 0 and m.parts.use_of(tp, below) == MakerParts.GROUND
		and s.y == ground_y - (2 if m.engine == KeenLevel.VORTICONS else 1) and _starts(m, nl) == 1)
	var frame_ok: bool = true
	for y: int in range(nl.height):
		for x: int in [0, nl.width - 1]:
			frame_ok = frame_ok and m.parts.use_of(tp, nl.get_word(tp, x, y)) == MakerParts.GROUND
	t.ok("%s: a solid frame round it (its sides ground)" % game, frame_ok)
	var nreq: Dictionary = m.play_request("Test")
	var nback: KeenLevel = _read_back(m, nreq, MakerModel.NEW_SLOT)
	t.ok("%s: the new level written in the engine's format reads back equal" % game, nback != null and nback.plane_difference(nl) == "")
	# the library
	m.paint(tp, 10, 10, below)
	t.ok("%s: saved into the library (%s)" % [game, m.error], m.save_doc() and m.path.begins_with(MakerLibrary.dir_for(game)))
	var entries: Array = MakerLibrary.list(game)
	t.ok("%s: the library lists it (%s)" % [game, entries], entries.size() == 1 and entries[0].name == "Test level" and entries[0].origin == "new")
	var m2: MakerModel = MakerModel.new()
	m2.open(game, root.path_join(game), "", false)
	t.ok("%s: it reads back equal" % game, m2.load_doc(m.path) and m2.level.plane_difference(nl) == "" and m2.doc_name == "Test level")
	var lib: MakerLibrary = MakerLibrary.new()
	t.ok("%s: renamed" % game, lib.rename(m.path, "Renamed") and MakerLibrary.list(game)[0].name == "Renamed")
	var copy: String = lib.duplicate_level(m.path)
	t.ok("%s: duplicated (%s)" % [game, copy.get_file()], copy != "" and MakerLibrary.list(game).size() == 2)
	t.ok("%s: deleted" % game, lib.delete(copy) and lib.delete(m.path) and MakerLibrary.list(game).is_empty())
	t.ok("%s: a file outside the maker's folder is not deleted" % game, not lib.delete(root.path_join(game).path_join("x.mkl")))
	# the tile-use tables
	_uses(m, game)


func _starts(m: MakerModel, l: KeenLevel) -> int:
	var n: int = 0
	var plane: int = MakerModel.START_PLANE[m.engine]
	for y: int in range(l.height):
		for x: int in range(l.width):
			if l.get_word(plane, x, y) in MakerModel.START_MARKERS[m.engine]:
				n += 1
	return n


## The level `slot` of a play request's files, read with the engine's own reader.
func _read_back(m: MakerModel, req: Dictionary, slot: int) -> KeenLevel:
	if req.is_empty():
		return null
	if m.engine == KeenLevel.VORTICONS:
		var name: String = ("LEVEL%02d." % slot) + m.ext
		var files: Dictionary = req.get("maker_files", {})
		return VortLevels.new().read(files[name], name, slot) if files.has(name) else null
	var set: Dictionary = req.get("maker_maps", {})
	var tm: TedMaps = TedMaps.new()
	tm.engine = m.engine
	tm.dict = m.maps.dict
	if set.is_empty() or not tm.read(set.maphead, set.gamemaps, "written"):
		return null
	return tm.maps[slot]


func _uses(m: MakerModel, game: String) -> void:
	var p: MakerParts = m.parts
	var names: Array = []
	for c: Dictionary in p.categories:
		names.append("%s %d" % [c.name, (c.values as PackedInt32Array).size()])
	print("  %s parts: %s" % [game, ", ".join(names)])
	var want: Array = {"keen1": [MakerParts.GROUND, MakerParts.PLATFORMS, MakerParts.HAZARDS, MakerParts.DOORS, MakerParts.ITEMS, MakerParts.EXIT, MakerParts.ENEMIES],
		"keen4": [MakerParts.GROUND, MakerParts.SLOPES, MakerParts.PLATFORMS, MakerParts.POLES, MakerParts.HAZARDS, MakerParts.DOORS, MakerParts.ITEMS, MakerParts.ENEMIES, MakerParts.MOVING, MakerParts.EXIT, MakerParts.BACKGROUND],
		"kdreams": [MakerParts.GROUND, MakerParts.PLATFORMS, MakerParts.POLES, MakerParts.ITEMS, MakerParts.ENEMIES, MakerParts.EXIT, MakerParts.BACKGROUND]}[game]
	var have: Dictionary = {}
	for c: Dictionary in p.categories:
		if not (c.values as PackedInt32Array).is_empty():
			have[c.name] = true
	var missing: Array = want.filter(func(w: String) -> bool: return not have.has(w))
	t.ok("%s: the palette has every kind of part (missing: %s)" % [game, missing], missing.is_empty())
	# every tile in a kind has the properties that kind means
	var wrong: Array = []
	var tp: int = p.tile_plane()
	for c: Dictionary in p.categories:
		if int(c.plane) != tp or not (c.names as Dictionary).is_empty():
			continue
		for v: int in c.values:
			var pr: Dictionary = p.props(v)
			var ok: bool = true
			match c.name:
				MakerParts.GROUND:
					ok = pr.n != 0 or pr.e != 0 or pr.s != 0 or pr.w != 0
				MakerParts.PLATFORMS:
					ok = pr.n != 0 and pr.s == 0 and pr.e == 0 and pr.w == 0
				MakerParts.POLES:
					ok = pr.use == 1
				MakerParts.HAZARDS:
					ok = pr.use == (1 if m.engine == KeenLevel.VORTICONS else 3)
				MakerParts.SLOPES:
					ok = pr.n >= 2 and pr.n <= 7
				MakerParts.SCENERY:
					ok = pr.n == 0 and pr.e == 0 and pr.s == 0 and pr.w == 0 and pr.use == 0
			if not ok:
				wrong.append("%s %d %s" % [c.name, v, pr])
	t.ok("%s: every tile's kind agrees with its properties (%d wrong: %s)" % [game, wrong.size(), wrong.slice(0, 3)], wrong.is_empty())
	var named: Array = {"keen1": [1, "Yorp"], "keen4": [22, "Poison slug"], "kdreams": [41, "Broccolash"]}[game]
	t.eq("%s: a creature named on the marker plane" % game, p.marker_name(named[0]), named[1])
