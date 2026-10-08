# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Runs one built-in demo through the Galaxy port with omnispeak's /CHECKSUM
## per-frame state hash (ck_verify.c) and writes the lines to --out, for
## tools/galaxy_verify.py to compare with omnispeak's own run.
##
## Options: --game_data=<folder> --game=keen4 --demo=0 --out=<file>

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var game: String = opts.get("game", "keen4")
	var d: GalData = GalData.new()
	if not t.ok("files load (%s)" % d.error, d.load_game(str(opts.get("game_data", "")).path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.time_limit = DosMachine.seconds_to_units(600.0)
	vm.on_limit = func() -> void:
		g.Quit("emulated time limit reached")
	g.CK_Main(PackedStringArray(["/CHECKSUM", "port", "/PLAYDEMO", str(opts.get("demo", "0"))]))
	g.CK_VERIFY_Shutdown()
	var f: FileAccess = FileAccess.open(opts.get("out", "user://verify.txt"), FileAccess.WRITE)
	f.store_string("\n".join(g.ck_verifyLines) + "\n")
	f.close()
	t.ok("ran (%d lines, quit '%s')" % [g.ck_verifyLines.size(), g.quit_message], g.ck_verifyLines.size() > 0)
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_limit = Callable()
	t.finish(self)
