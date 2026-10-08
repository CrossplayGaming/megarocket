# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REPLAY-G "boot": runs the Galaxy port headless from the program's start
## (CK_Main with the case's command line, into CK_DemoLoop) for a case's
## length, with the case's timed keys, and writes every displayed EGA picture
## to a frame store for tools/timing_score.py / compare_frames.py to hold
## against the oracle's recording of the same case.
##
## Options: --game_data=<folder> --game=keen4 --seconds=30 --out=<folder>
##          --keys=<at:scancode:hold,...> --args=<command line, space-separated>
##          --cycles= --vbl_period= --timer_offset= (the machine's timing)
##          --costs=name=units,... (TIME-G costs over the game's own)
##          --seed=n (the original's time(0) & 0xFF, which US_InitRndT(true) takes)
##          --clock=n (or time(0) at the start, and the machine's seconds since)

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
## DOSBox's timing as the Vorticons fit found it (same runner settings)
const DOSBOX: Dictionary = {"cycles": 20000, "vbl_period": 17024400, "timer_offset": 0}

var t: T = T.new()


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", "")
	var game: String = opts.get("game", "keen4")
	var seconds: float = float(opts.get("seconds", "30"))
	if root == "" or out == "":
		t.blocked("need --game_data and --out")
		t.finish(self)
		return
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game])):
		t.blocked("%s data: %s" % [game, d.error])
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(int(opts.get("cycles", DOSBOX.cycles)))
	vm.vbl_period = int(opts.get("vbl_period", DOSBOX.vbl_period))
	vm.timer_offset = int(opts.get("timer_offset", DOSBOX.timer_offset))
	g.us_randomSeed = int(opts.get("seed", "0"))
	g.us_clockAtStart = int(opts.get("clock", "-1"))
	for spec: String in str(opts.get("costs", "")).split(",", false):
		var kv: PackedStringArray = spec.split("=")
		g.costs[kv[0]] = int(kv[1])
	for spec: String in str(opts.get("keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key(float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	var writer: FrameWriter = FrameWriter.new()
	if not writer.open(out):
		t.blocked("cannot write " + out + ": " + writer.error)
		t.finish(self)
		return
	var card: EgaCard = vm.card
	var written: Array = [0]
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA:
			writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
			written[0] += 1
	vm.time_limit = DosMachine.seconds_to_units(seconds)
	vm.on_limit = func() -> void:
		# end the run the way Quit does, without Quit's error report
		g.quitting = true
		g.quit_message = "time limit"
	var t0: int = Time.get_ticks_msec()
	g.CK_Main(str(opts.get("args", "")).split(" ", false))
	var wall: float = (Time.get_ticks_msec() - t0) / 1000.0
	writer.close({"game": game, "seconds": seconds, "kinds": [], "level_starts": [0]})
	print("  %s: %.1f s of game time in %.1f s, %d displays, %d distinct pictures, quit '%s'" %
		[game, vm.seconds(), wall, written[0], writer._index.size(), g.quit_message])
	t.ok("the run reached the time limit without the program quitting on its own", g.quit_message == "time limit")
	t.ok("pictures were written", written[0] > 100)
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	t.finish(self)
