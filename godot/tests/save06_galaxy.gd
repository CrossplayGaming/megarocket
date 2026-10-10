# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SAVE-06: Keen 4-6 keep the player's files between sessions (the settings and high scores in CONFIG.CKx,
## the saved games in SAVEGAMn.CKx), in the folder the shell gives (user_dir). Session one (level 1, the
## original's /TEDLEVEL): a game saved in slot 3 through the original's own save routine, the top high
## score changed, the game quit (its US_Shutdown writes the config). Checks: both files on disk, equal to
## what the game wrote, no half-written leftovers. Session two, a fresh engine on the same folder: the
## files read back, the high score in the game's table, the saved game loads through the original's own
## load routine. A write cut short before its swap (only the .BAK left) still reads back.
##
## Options: --game_data=<folder>

var t: T = T.new()

const META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for game: String in ["keen4", "keen5", "keen6"]:
		_game(root, game)
	t.finish(self)


func _session(root: String, game: String, dir: String, during: Callable) -> GalGame:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(META[game])):
		t.blocked("%s data: %s" % [game, d.error])
		return null
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	g.user_dir = dir
	g.load_user_files()
	var done: Array = [false]
	vm.on_display = func() -> void:
		if not done[0] and g.ck_gameState.currentLevel == 1 and g.ck_keenObj != null and g.ck_keenObj.type == g.CT_Player:
			done[0] = true
			during.call(g)
	vm.time_limit = DosMachine.seconds_to_units(8.0)
	vm.on_limit = func() -> void:
		g.quitting = true
	g.CK_Main(PackedStringArray(["/TEDLEVEL", "1"]))
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return g


func _game(root: String, game: String) -> void:
	var dir: String = OS.get_temp_dir().path_join("mr_save06_%s_%d" % [game, Time.get_ticks_usec()])
	var ext: String = "CK" + game.substr(4, 1)
	var saved: Array = [PackedByteArray()]
	var g1: GalGame = _session(root, game, dir, func(g: GalGame) -> void:
		var f: GalLib.FS_File = g.FS_CreateUserFile(g.US_GetSavefileName(2))
		if f != null and g.CK_SaveGame(f):
			g.FS_CloseFile(f)
			saved[0] = g.us_saveFiles[2]
		(g.ck_highScores[0] as GalUS.CK_HighScore).score = 4242424
		(g.ck_highScores[0] as GalUS.CK_HighScore).name = "Megarocket")
	if g1 == null:
		return
	var cfg: String = dir.path_join("CONFIG." + ext)
	var sav: String = dir.path_join("SAVEGAM2." + ext)
	t.ok("%s: the saved game is on disk, as the game wrote it (%d bytes)" % [game, (saved[0] as PackedByteArray).size()],
		(saved[0] as PackedByteArray).size() > 100 and FileAccess.get_file_as_bytes(sav) == saved[0])
	t.ok("%s: the config (settings, high scores) is on disk, as the game wrote it at its quit" % game,
		FileAccess.file_exists(cfg) and FileAccess.get_file_as_bytes(cfg) == g1.us_configFile)
	var left: Array = Array(DirAccess.get_files_at(dir)).filter(func(n: String) -> bool: return n.ends_with(".TMP") or n.ends_with(".BAK"))
	t.ok("%s: no half-written files left (%s)" % [game, left], left.is_empty())
	var loaded: Array = [false]
	var g2: GalGame = _session(root, game, dir, func(g: GalGame) -> void:
		var f: GalLib.FS_File = g.FS_OpenUserFile(g.US_GetSavefileName(2))
		loaded[0] = f != null and g.CK_LoadGame(f, false))
	if g2 == null:
		return
	t.ok("%s: a new session reads the saved game back" % game, g2.us_saveFiles[2] == saved[0])
	var top: GalUS.CK_HighScore = g2.ck_highScores[0]
	t.ok("%s: and the high score is in its table (%s %d)" % [game, top.name, top.score], top.score == 4242424 and top.name == "Megarocket")
	t.ok("%s: the saved game loads through the original's own load routine" % game, loaded[0])
	# a write cut short before its swap: the old file only as .BAK
	DirAccess.rename_absolute(cfg, cfg + ".BAK")
	var g3: GalGame = load(CLASSES[game]).new()
	g3.data = g2.data
	g3.user_dir = dir
	g3.load_user_files()
	t.ok("%s: a write cut short leaves the last good config, read from its .BAK" % game, g3.us_configFile == FileAccess.get_file_as_bytes(cfg + ".BAK") and not g3.us_configFile.is_empty())
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
