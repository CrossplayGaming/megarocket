# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-V-01 / REPLAY-V1 "boot": runs the Vorticons port headless from the
## program's start for a case's length, with the case's timed keys, and
## writes every displayed picture to a frame store for tools/compare_frames.py
## to hold against the oracle's recording of the same case.
##
## Options: --game_data=<folder> --game=keen1 --seconds=30 --out=<folder>
##          --keys=<at:scancode:hold,...> --save=<folder for CTLPANEL/SCORES>
##          --feed_keys=<make_tick:scancode:break_tick,...> (HARN-06: KEYFEED.COM's timetable, 1024 ticks
##          a second from the EGA mode set, no typematic repeat: tools/keyfeed.py, tools/screen_case.py)
##          --may_exit=1 (HARN-06: the program may quit before the time limit; SCR-01V: the exit screen it
##          leaves goes to <out>/text_frames.json)
##          --compare_lists=1 (REND-01R: the draw lists kept, as --draw_capture, and every picture shown held
##          against its refresh's list composed at 1x, tests/list_compare.gd: the counts to <out>/lists.json,
##          the first pictures that differ as PNGs to --compare_out=<folder>, by default <out>/lists)

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
	# HARN-06: a screen case's keys, timed from the EGA mode set as KEYFEED.COM types them into the
	# original (no repeats: the feeder sends none)
	for spec: String in str(opts.get("feed_keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.repeat_pause_ms = 0
		vm.add_key_after("mode_0d", int(parts[0]) / 1024.0, int(parts[1]), (int(parts[2]) - int(parts[0])) / 1024.0)
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
	# REND-01R: each picture shown against its refresh's draw list (presentation only: the game plays the same)
	var lists: ListCompare = null
	if opts.has("compare_lists"):
		lists = ListCompare.new({}, str(opts.get("compare_out", out.path_join("lists"))), game)
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA and not stopped[0]:
			if card.frame_mixed:
				writer.add(card.frame_rgb(), "P")
			else:
				writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
			if lists != null:
				lists.vorticons(g, vm)
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
	if opts.has("draw_capture") or opts.has("compare_lists"):
		g.draw_capture = true    # REND-01..03: the draw lists kept, as native resolution keeps them
	if opts.has("spawn_scan"):
		g.spawn_scan_per_tile = int(opts["spawn_scan"])
	if opts.has("repeat_phase"):
		vm.repeat_phase_ms = float(opts["repeat_phase"])
	if opts.has("repeat_pause"):
		vm.repeat_pause_ms = int(opts["repeat_pause"])
	if opts.has("teleport_anim"):
		g.set("teleport_anim0", int(opts["teleport_anim"]))
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
	if vm.marks.has("mode_0d"):
		print("  mode 0Dh set at %.3f s" % (float(vm.marks["mode_0d"]) / (DosMachine.PIT_HZ * DosMachine.UNIT)))
	if lists != null:
		_write_lists(lists, out)
	if opts.has("may_exit"):
		# HARN-06: a screen case that quits to DOS (its "may_exit"); SCR-01V: the exit screen the program
		# leaves, for tools/screen_case.py's text comparison, held from the quit to the time limit
		print("  the program %s" % ("ran to the time limit" if vm.limit_fired else "quit ('%s')" % g.exit_message))
		if not g.exit_textScreen.is_empty():
			var held: int = maxi(1, int(round((float(vm.time_limit) - float(vm.now)) * 70.086 / (DosMachine.PIT_HZ * DosMachine.UNIT))))
			var f: FileAccess = FileAccess.open(out.path_join("text_frames.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"cols": 80, "rows": 25, "screens": [[held, g.exit_textScreen.hex_encode(), g.exit_cursor.x, g.exit_cursor.y]]}))
			f.close()
	else:
		t.ok("the run reached the time limit without the program quitting on its own", g.exit_message == "" and vm.limit_fired)
	t.ok("pictures were written", written[0] > 100)
	# break the cycles between the machine's handlers and the game
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.vm = null
	t.finish(self)


## REND-01R: the counts of the pictures held against their lists, printed and kept beside the frames.
func _write_lists(lists: ListCompare, out: String) -> void:
	var line: String = lists.summary()
	print("  LISTS " + line)
	var f: FileAccess = FileAccess.open(out.path_join("lists.json"), FileAccess.WRITE)
	if f == null:
		t.blocked("cannot write lists.json in " + out)
		return
	f.store_string(line + "\n")
	f.close()
