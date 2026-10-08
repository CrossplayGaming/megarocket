# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-V-01 / REPLAY-V1 "boot": runs the Vorticons port headless from the
## program's start for a case's length, with the case's timed keys, and
## writes every displayed picture to a frame store for tools/compare_frames.py
## to hold against the oracle's recording of the same case.
##
## Options: --game_data=<folder> --game=keen1 --seconds=30 --out=<folder>
##          --keys=<at:scancode:hold,...> --save=<folder for CTLPANEL/SCORES>

var t: T = T.new()


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", "")
	var game: String = opts.get("game", "keen1")
	var seconds: float = float(opts.get("seconds", "30"))
	if root == "" or out == "":
		t.blocked("need --game_data and --out")
		t.finish(self)
		return
	var data: VortData = VortData.new()
	var ext: String = "CK" + game.substr(4, 1)
	if not data.load_game(root.path_join(game), ext):
		t.blocked("%s data: %s" % [game, data.error])
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = vm
	g.data = data
	g.trace_frames = OS.has_environment("MR_TRACE")
	g.save_dir = opts.get("save", OS.get_temp_dir().path_join("mr_vort_save_%d" % Time.get_ticks_usec()))
	# a case's saved games (its oracle "overrides" folder) go into a fresh save folder
	if opts.has("save_seed"):
		DirAccess.make_dir_recursive_absolute(g.save_dir)
		var seed_dir: DirAccess = DirAccess.open(str(opts["save_seed"]))
		if seed_dir != null:
			for f: String in seed_dir.get_files():
				seed_dir.copy(str(opts["save_seed"]).path_join(f), g.save_dir.path_join(f))
	for spec: String in str(opts.get("keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key(float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	# keys timed from the first intro frame: <seconds after it>:<scancode>:<hold>
	for spec: String in str(opts.get("keys_after_intro", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key_after("intro", float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	var writer: FrameWriter = FrameWriter.new()
	if not writer.open(out):
		t.blocked("cannot write " + out + ": " + writer.error)
		t.finish(self)
		return
	var card: EgaCard = vm.card
	var written: Array = [0]
	# the run may end a given number of displayed refreshes after the first
	# intro frame, the way a recording of the same length does
	var after_intro: Array = [int(opts.get("refreshes_after_intro", "-1"))]
	var mark_written: Array = [-1]
	var stopped: Array = [false]
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA and not stopped[0]:
			writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
			written[0] += 1
			if written[0] == 1 and OS.has_environment("MR_TRACE"):
				print("TRACE first_display vbl=%d" % vm.vbl_count)
			if mark_written[0] < 0 and vm.marks.has("intro"):
				mark_written[0] = written[0]
			if after_intro[0] >= 0 and vm.marks.has("intro"):
				after_intro[0] -= 1
				if after_intro[0] < 0:
					# the run is over: nothing drawn while the program unwinds is recorded
					stopped[0] = true
					g.exited = true
					vm.limit_fired = true
	vm.time_limit = DosMachine.seconds_to_units(seconds)
	# the oracle's fitted timing unless an option overrides a part of it
	var timing: Dictionary = {}
	for k: String in ["cycles", "vbl_period", "timer_offset"]:
		if opts.has(k):
			timing[k] = int(opts[k])
	g.apply_dosbox_timing(timing)
	if opts.has("spawn_scan"):
		g.spawn_scan_per_tile = int(opts["spawn_scan"])
	if opts.has("repeat_phase"):
		vm.repeat_phase_ms = float(opts["repeat_phase"])
	if opts.has("repeat_pause"):
		vm.repeat_pause_ms = int(opts["repeat_pause"])
	if opts.has("map_anim"):
		g.map_anim0 = int(opts["map_anim"])
	if opts.has("level_tc"):
		g.level_tc_shift = int(opts["level_tc"])
	if opts.has("dos_ticks"):
		g.dos_ticks = int(opts["dos_ticks"])
	if g.trace_frames:
		var used: Dictionary = g.dosbox_timing.duplicate()
		used.merge(timing, true)
		print("TRACE timing " + JSON.stringify(used))
	vm.vga_access_units = int(opts.get("vga_cost", "0"))
	for spec: String in str(opts.get("costs", "")).split(",", false):
		var kv: PackedStringArray = spec.split("=")
		g.costs[kv[0]] = int(kv[1])    # overrides the game's fitted values
	vm.on_limit = func() -> void:
		g.exited = true
	var t0: int = Time.get_ticks_msec()
	g.main()
	var wall: float = (Time.get_ticks_msec() - t0) / 1000.0
	writer.close({"game": game, "seconds": seconds, "kinds": [], "level_starts": [0]})
	print("  %s: %.1f s of game time in %.1f s, %d displays, %d distinct pictures, exit '%s'" %
		[game, vm.seconds(), wall, written[0], writer._index.size(), g.exit_message])
	if vm.marks.has("intro"):
		print("  intro mark at %.3f s, %d displays after it" % [float(vm.marks["intro"]) / (DosMachine.PIT_HZ * DosMachine.UNIT), written[0] - mark_written[0]])
	t.ok("the run reached the time limit without the program quitting on its own", g.exit_message == "" and vm.limit_fired)
	t.ok("pictures were written", written[0] > 100)
	# break the cycles between the machine's handlers and the game
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.vm = null
	t.finish(self)
