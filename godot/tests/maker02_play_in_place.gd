# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-02: the maker's play button, engine side. In a copy of level 1 made with the maker's readers,
## Keen's start is moved two tiles along his row (Keen 1-3: the sprite plane's 255, right; Keen 4-6: the
## info plane's 1 or 2, left: two right, Keen 4's Border Village has him on its exit and the level ends) and the level written; the game is started straight into that level (Keen 1-3:
## shell_play_level as after_startup; Keen 4-6: the original's own /TEDLEVEL, as id's map editor launched
## it), with the maker's files in place of the folder's. Checks: the level's first picture comes with
## Keen where the maker put him; the game goes on playing it (no Quit) until the run is ended.
##
## Options: --game_data=<folder> [--dx=-2: Keen 4-6's move]

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


## Where `marker` is in `plane`, and that spot moved `dx` tiles along its row (every other marker cleared).
func _move_start(level: KeenLevel, plane: int, markers: Array, dx: int) -> Vector2i:
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.get_word(plane, x, y) in markers:
				var v: int = level.get_word(plane, x, y)
				level.set_word(plane, x, y, 0)
				level.set_word(plane, x + dx, y, v)
				return Vector2i(x + dx, y)
	return Vector2i(-1, -1)


func _vorticons(root: String, game: String) -> void:
	var dir: String = root.path_join(game)
	var ext: String = "CK" + game.substr(4, 1)
	var level: KeenLevel = VortLevels.new().read_file(dir, 1, ext)
	if level == null:
		t.blocked("%s: LEVEL01 not read" % game)
		return
	var at: Vector2i = _move_start(level, 1, [255], 2)
	var data: VortData = VortData.new()
	if not data.load_game(dir, ext):
		t.blocked("%s data: %s" % [game, data.error])
		return
	data.overrides[("LEVEL01." + ext).to_upper()] = VortLevels.new().write(level)
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_maker02_%d" % Time.get_ticks_usec())
	var seen: Dictionary = {}
	vm.on_display = func() -> void:
		if seen.is_empty() and g.get("shell_in_level") and g.level == 1:
			seen["keen"] = Vector2i(g.objlist[0].x >> 12, (g.objlist[0].y - 8 * g.PIXGLOBAL) >> 12)
			seen["at"] = vm.seconds()
	g.after_startup = func() -> void: g.shell_play_level(1)
	vm.time_limit = DosMachine.seconds_to_units(20.0)
	vm.on_limit = func() -> void:
		g.exited = true
		g.exit_message = "time limit"
	g.main()
	t.ok("%s: level 1 opened with Keen where the maker moved him (%s, the maker's %s)" % [game, seen.get("keen", "never seen"), at],
		at.x >= 0 and seen.get("keen", Vector2i(-9, -9)) == at)
	t.ok("%s: and it played on until the run was ended (%s)" % [game, g.exit_message], g.exit_message == "time limit")
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null


func _galaxy(root: String, game: String) -> void:
	var dir: String = root.path_join(game)
	var meta: String = "res://data/omnispeak".path_join(GALAXY_META[game])
	var maps: TedMaps = TedMaps.open_galaxy(dir, meta)
	if maps == null or maps.error != "":
		t.blocked("%s maps: %s" % [game, maps.error if maps != null else "none"])
		return
	var at: Vector2i = _move_start(maps.maps[1], 2, [1, 2], int(T.options().get("dx", "-2")))
	var set: Dictionary = maps.write()
	var d: GalData = GalData.new()
	if not d.load_game(dir, meta) or not d.use_maps(set.maphead, set.gamemaps):
		t.blocked("%s data: %s" % [game, d.error])
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(GALAXY_CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	var seen: Dictionary = {}
	vm.on_display = func() -> void:
		if seen.is_empty() and g.ck_gameState.currentLevel == 1 and g.ck_keenObj != null and g.ck_keenObj.type == g.CT_Player:
			seen["keen"] = Vector2i(g.ck_keenObj.posX >> 8, -1)
			seen["y"] = g.ck_keenObj.posY
	vm.time_limit = DosMachine.seconds_to_units(25.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray(["/TEDLEVEL", "1"]))
	print("  %s: ended at %.1f s, level state %d, level %d, lives %d" % [game, vm.seconds(), g.ck_gameState.levelState, g.ck_gameState.currentLevel, g.ck_gameState.numLives])
	t.ok("%s: /TEDLEVEL 1 opened the maker's level with Keen in the maker's column (%s, the maker's %s)" % [game, seen.get("keen", "never seen"), at],
		at.x >= 0 and seen.has("keen") and (seen.keen as Vector2i).x == at.x)
	t.ok("%s: and it played on until the run was ended (%s)" % [game, g.quit_message], g.quit_message == "time limit")
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
