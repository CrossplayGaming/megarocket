# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-01: a level from the maker plays in the game (the engine side of "play in place"). For Keen 1-3
## a level is read with VortLevels, one tile changed, written, and put in place of LEVELnn (VortData's
## overrides): the game's own ReadLevel then holds the changed tile and the rest as it was, and Level
## select still lists it. For Keen 4-6 the maps are read with TedMaps, one tile changed in a level, the
## whole set written and handed to the game (GalData.use_maps): the game's own CA_CacheMap holds the
## changed tile and the rest as it was, and the level's name. The game folders are never written.
##
## Options: --game_data=<folder>

var t: T = T.new()

const GALAXY_META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const GALAXY_CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for game: String in ["keen1", "keen2", "keen3"]:
		_vorticons(root, game)
	for game: String in ["keen4", "keen5", "keen6"]:
		_galaxy(root, game)
	t.finish(self)


func _vorticons(root: String, game: String) -> void:
	var dir: String = root.path_join(game)
	var ext: String = "CK" + game.substr(4, 1)
	var level: KeenLevel = VortLevels.new().read_file(dir, 1, ext)
	if level == null:
		t.blocked("%s: LEVEL01 not read" % game)
		return
	# a cell well inside the level gets the tile of the cell beside it plus one (anything different)
	var x: int = level.width / 2
	var y: int = level.height / 2
	var was: int = level.get_word(0, x, y)
	var now: int = (was + 1) % 300
	var edited: KeenLevel = level.copy()
	edited.set_word(0, x, y, now)
	var bytes: PackedByteArray = VortLevels.new().write(edited)
	var data: VortData = VortData.new()
	if not data.load_game(dir, ext):
		t.blocked("%s data: %s" % [game, data.error])
		return
	data.overrides[("LEVEL01." + ext).to_upper()] = bytes
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = DosMachine.new()
	g.data = data
	g.ReadLevel(1)
	var same: bool = true
	for yy: int in range(level.height):
		for xx: int in range(level.width):
			var want: int = now if (xx == x and yy == y) else level.get_word(0, xx, yy)
			if g.GETTILE(xx, yy, 0) != want:
				same = false
	t.ok("%s: the game's ReadLevel holds the maker's LEVEL01: (%d, %d) is %d (was %d), every other tile as it was" % [game, x, y, g.GETTILE(x, y, 0), was],
		same and g.mapwwide == level.width and g.mapheight == level.height)
	t.ok("%s: Level select still lists level 1" % game, g.shell_levels().any(func(r: Array) -> bool: return r[0] == 1))
	g.vm = null


func _galaxy(root: String, game: String) -> void:
	var dir: String = root.path_join(game)
	var meta: String = "res://data/omnispeak".path_join(GALAXY_META[game])
	var maps: TedMaps = TedMaps.open_galaxy(dir, meta)
	if maps == null or maps.error != "":
		t.blocked("%s maps: %s" % [game, maps.error if maps != null else "none"])
		return
	var n: int = 1
	var level: KeenLevel = maps.maps[n]
	var x: int = level.width / 2
	var y: int = level.height / 2
	var was: int = level.get_word(0, x, y)
	var now: int = (was + 1) % 1000
	var original: KeenLevel = level.copy()
	level.set_word(0, x, y, now)
	var set: Dictionary = maps.write()
	if set.is_empty():
		t.blocked("%s: the maker's maps not written: %s" % [game, maps.error])
		return
	var d: GalData = GalData.new()
	if not d.load_game(dir, meta):
		t.blocked("%s data: %s" % [game, d.error])
		return
	t.ok("%s: the game takes the maker's maps (%s)" % [game, d.error], d.use_maps(set.maphead, set.gamemaps))
	var g: GalGame = load(GALAXY_CLASSES[game]).new()
	g.vm = DosMachine.new()
	g.data = d
	g.CA_Startup()
	g.CA_CacheMap(n)
	var same: bool = true
	for p: int in range(3):
		for yy: int in range(original.height):
			for xx: int in range(original.width):
				var want: int = now if (p == 0 and xx == x and yy == y) else original.get_word(p, xx, yy)
				if g.CA_TileAtPos(xx, yy, p) != want:
					same = false
	t.ok("%s: the game's CA_CacheMap holds the maker's level %d ('%s'): (%d, %d) is %d (was %d), every other cell of the three planes as it was" % [
		game, n, d.map_names[n], x, y, g.CA_TileAtPos(x, y, 0), was], same and g.quit_message == "" and d.map_names[n] == original.name.strip_edges())
	g.vm = null
