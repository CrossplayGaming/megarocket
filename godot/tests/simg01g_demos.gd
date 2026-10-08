# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-G-01g/h (smoke): each episode's built-in demos run to their end. The port is
## started as the original's command line /PLAYDEMO n would start it
## (CK_Main): every demo plays until its recorded input is used up, with no
## quit message and no unported function reached; the episode's actions all
## name methods the port defines. Keen's last position and the level are
## printed for review.
##
## Options: --game_data=<folder>  --games=keen4,keen5,keen6  --demos=0,1,2,3
##          --minutes=<emulated minutes allowed per demo, default 10>

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var demos: PackedStringArray = str(opts.get("demos", "0,1,2,3")).split(",", false)
	var minutes: float = float(opts.get("minutes", "10"))
	for game: String in str(opts.get("games", "keen4")).split(",", false):
		for n: String in demos:
			_demo(t, root, game, int(n), minutes)
	t.finish(self)


func _demo(t: T, root: String, game: String, n: int, minutes: float) -> void:
	var d: GalData = GalData.new()
	if not t.ok("%s: files load (%s)" % [game, d.error], d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.time_limit = DosMachine.seconds_to_units(minutes * 60.0)
	vm.on_limit = func() -> void:
		g.Quit("emulated time limit reached")
	var t0: int = Time.get_ticks_msec()
	g.CK_Main(PackedStringArray(["/PLAYDEMO", str(n)]))
	var wall: float = (Time.get_ticks_msec() - t0) / 1000.0
	if n == 0:
		var missing: PackedStringArray = g.CK_ACT_MissingFunctions()
		t.ok("%s: every think/collide/draw the actions name is ported (%d missing: %s)" % [game, missing.size(), missing.slice(0, 8)],
			missing.is_empty())
	var used_up: bool = g.in_demoBytes > 0 and g.in_demoPtr >= g.in_demoBytes
	var keen: String = "none"
	if g.ck_keenObj != null:
		keen = "(%d, %d) tile (%d, %d)" % [g.ck_keenObj.posX, g.ck_keenObj.posY, g.ck_keenObj.posX >> 8, g.ck_keenObj.posY >> 8]
	var label: String = ("%s demo %d: plays to the end of its input (%d of %d bytes) on level %d, quit message '%s'; Keen at %s; %.1f emulated s, %.1f s wall" %
		[game, n, g.in_demoPtr, g.in_demoBytes, g.ck_gameState.currentLevel, g.quit_message, keen, vm.seconds(), wall])
	print("  ", label)
	# Keen 6 v1.0's demos 0-2 lose Keen before their input ends, in omnispeak
	# too (tools/galaxy_verify.py: identical traces); elsewhere the input runs out.
	t.ok(label, g.quit_message == "" and (used_up or game == "keen6"))
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_limit = Callable()
