# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-03: the editor's document (maker/maker_model.gd), headless, for Keen 1 and Keen 4. Opening lists
## the game's levels (Keen 4 by name); a drag of three cells is one undo step; undo puts every cell back,
## redo makes them again; placing Keen's start leaves exactly one start where it was put; saving writes
## the files into the maker's folder, which read back equal to the edits; saving into the game's own
## folder is refused; the play request names the level and carries the edited files.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for game: String in ["keen1", "keen4"]:
		_game(root, game)
	t.finish(self)


func _game(root: String, game: String) -> void:
	var m: MakerModel = MakerModel.new()
	if not t.ok("%s opens (%s)" % [game, m.error], m.open(game, root.path_join(game))):
		return
	var list: Array = m.level_list()
	t.ok("%s: its levels listed (%d, first %s)" % [game, list.size(), list[0] if not list.is_empty() else "none"],
		list.size() >= (16 if game == "keen1" else 18) and (game == "keen1" or str(list[1][1]) != ""))
	m.select(1)
	var l: KeenLevel = m.level
	var before: KeenLevel = l.copy()
	var cells: Array = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
	m.begin_stroke()
	for c: Vector2i in cells:
		m.paint(0, c.x, c.y, (l.get_word(0, c.x, c.y) + 1) % 200)
	m.end_stroke()
	var painted: KeenLevel = l.copy()
	t.ok("%s: the drag changed three cells (%s)" % [game, before.plane_difference(painted)], before.plane_difference(painted) != "")
	m.undo()
	t.ok("%s: one undo puts all three back" % game, before.plane_difference(l) == "" and not m._undo.size())
	m.redo()
	t.ok("%s: redo makes them again" % game, painted.plane_difference(l) == "")
	var s0: Vector2i = m.start_at()
	m.place_start(s0.x + 3, s0.y)
	var starts: int = 0
	var plane: int = MakerModel.START_PLANE[m.engine]
	for y: int in range(l.height):
		for x: int in range(l.width):
			if l.get_word(plane, x, y) in MakerModel.START_MARKERS[m.engine]:
				starts += 1
	t.ok("%s: Keen's start moved from %s to %s, the only one" % [game, s0, m.start_at()], m.start_at() == Vector2i(s0.x + 3, s0.y) and starts == 1)
	var dir: String = OS.get_temp_dir().path_join("mr_maker03_%s_%d" % [game, Time.get_ticks_usec()])
	t.ok("%s: saved into the maker's folder (%s)" % [game, m.error], m.save(dir))
	var back: KeenLevel = null
	if m.engine == KeenLevel.VORTICONS:
		back = VortLevels.new().read_file(dir, 1, m.ext)
	else:
		var tm: TedMaps = TedMaps.new()
		var head: PackedByteArray = FileAccess.get_file_as_bytes(dir.path_join("MAPHEAD.CK4"))
		var gm: PackedByteArray = FileAccess.get_file_as_bytes(dir.path_join("GAMEMAPS.CK4"))
		if tm.read(head, gm, "saved"):
			back = tm.maps[1]
	t.ok("%s: the saved level reads back as edited" % game, back != null and back.plane_difference(l) == "")
	t.ok("%s: saving into the game's own folder is refused (%s)" % [game, "refused" if not m.save(root.path_join(game)) else "WRITTEN"],
		m.error.contains("not allowed"))
	var req: Dictionary = m.play_request("Test")
	t.ok("%s: the play request is level 1 with the edited files" % game, req.get("play_level", -1) == 1 and req.get("id", "") == game
		and (req.has("maker_files") if m.engine == KeenLevel.VORTICONS else req.has("maker_maps")))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
