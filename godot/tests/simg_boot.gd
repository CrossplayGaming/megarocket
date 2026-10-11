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
##          --seed=n (the random index US_InitRndT(true) takes)
##          --clock=us (or the DOS clock at the start, microseconds since 00:00:00)
##          --seed_ticks=n:d,... (BIOS ticks added to the clock's n-th reading)
##          --lock=<json> (HARN-20: each picture after a fade-in held until the
##            refresh the recording first shows it, counted from that fade-in)
##          --feed_keys=<make_tick:scancode:break_tick,...> (HARN-06: KEYFEED.COM's
##            timetable, 1024 ticks a second from the EGA mode set, no typematic
##            repeat: tools/keyfeed.py, tools/screen_case.py)
##          --save_seed=<folder> (HARN-06: the files placed beside the original's
##            program, CONFIG.CKx and SAVEGAMn.CKx, read as the player's files)
##          --save=<folder> (HARN-06: the player's files kept there, as the game writes them)
##          --may_exit=1 (HARN-06: the program may quit before the time limit; the
##            text screen it leaves is written as <out>/text_frames.json)
##          --compare_lists=1 (REND-01R: the draw lists kept and every picture shown held
##            against its refresh's list composed at 1x, tests/list_compare.gd: the counts
##            to <out>/lists.json, the first pictures that differ as PNGs to
##            --compare_out=<folder>, by default <out>/lists)

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
	g.us_dosClockAtStart = int(opts.get("clock", "-1"))
	for spec: String in str(opts.get("seed_ticks", "")).split(",", false):
		g.us_seedTicks[int(spec.split(":")[0])] = int(spec.split(":")[1])
	for spec: String in str(opts.get("costs", "")).split(",", false):
		var kv: PackedStringArray = spec.split("=")
		g.costs[kv[0]] = int(kv[1])
	for spec: String in str(opts.get("keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key(float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	# HARN-06: a screen case's keys, timed from the EGA mode set as KEYFEED.COM types them into the
	# original (no repeats: the feeder sends none)
	for spec: String in str(opts.get("feed_keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.repeat_pause_ms = 0
		vm.add_key_after("mode_0d", int(parts[0]) / 1024.0, int(parts[1]), (int(parts[2]) - int(parts[0])) / 1024.0)
	# HARN-06: a case's files beside the program (its oracle "overrides") in a fresh folder of the player's,
	# or --save's folder, which keeps what the program writes (a saved game for another case to start from)
	if opts.has("save_seed") or opts.has("save"):
		g.user_dir = str(opts.get("save", OS.get_temp_dir().path_join("mr_gal_save_%d" % Time.get_ticks_usec())))
		DirAccess.make_dir_recursive_absolute(g.user_dir)
		if opts.has("save_seed"):
			for f: String in DirAccess.get_files_at(str(opts["save_seed"])):
				DirAccess.copy_absolute(str(opts["save_seed"]).path_join(f), g.user_dir.path_join(f.to_upper()))
		g.load_user_files()
	var writer: FrameWriter = FrameWriter.new()
	if not writer.open(out):
		t.blocked("cannot write " + out + ": " + writer.error)
		t.finish(self)
		return
	var card: EgaCard = vm.card
	var written: Array = [0]
	var lock: Dictionary = _lock_setup(g, vm, str(opts.get("lock", "")))
	# REND-01R: each picture shown against its refresh's draw list (presentation only: the game plays the same)
	var lists: ListCompare = null
	if opts.has("compare_lists"):
		g.draw_capture = true
		lists = ListCompare.new({}, str(opts.get("compare_out", out.path_join("lists"))), game, GalImages.new(d))
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA:
			if card.frame_mixed:
				writer.add(card.frame_rgb(), "P")
			else:
				writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
			written[0] += 1
			if lists != null:
				lists.galaxy(g, vm)
			if not lock.is_empty():
				_lock_display(g, vm, lock)
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
	if vm.marks.has("mode_0d"):
		print("  mode 0Dh set at %.3f s" % (float(vm.marks["mode_0d"]) / (DosMachine.PIT_HZ * DosMachine.UNIT)))
	if lists != null:
		_write_lists(lists, out)
	if opts.has("may_exit"):
		# HARN-06: a screen case that quits to DOS; the text screen the program leaves (the order screen)
		# for tools/screen_case.py's text comparison, held from the quit to the time limit
		print("  the program %s" % ("ran to the time limit" if g.quit_message == "time limit" else "quit ('%s')" % g.quit_message))
		if not g.us_textScreen.is_empty():
			var cells: PackedByteArray = g.us_textScreen.duplicate()
			cells.resize(4000)
			for i: int in range(g.us_textScreen.size(), 4000, 2):
				cells[i] = 0x20
				cells[i + 1] = 0x07
			var held: int = maxi(1, int(round((float(vm.time_limit) - float(vm.now)) * 70.086 / (DosMachine.PIT_HZ * DosMachine.UNIT))))
			# the cursor the original leaves: column 0, row 23 (the 24 rows printed; DOS's prompt goes on the
			# row below, row 24, as the recordings show; HARN-06 checks it there)
			var f: FileAccess = FileAccess.open(out.path_join("text_frames.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"cols": 80, "rows": 25, "screens": [[held, cells.hex_encode(), 0, 23]]}))
			f.close()
	else:
		t.ok("the run reached the time limit without the program quitting on its own", g.quit_message == "time limit")
	t.ok("pictures were written", written[0] > 100)
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	g.present_lock = Callable()
	vm.on_limit = Callable()
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


# ----------------------------------------------------------------- HARN-20

## The frame lock: segments[i] holds, for the i-th fade-in (the level's first, then each restart's),
## the refresh at which the recording first shows each picture from the first one after the black.
## A present whose page differs from the one on display is the next picture; it is put on display
## no sooner than the recording's refresh for it (never sooner than the port would: a picture the
## port shows late still fails). This stands in for the original's processing time per frame,
## which the port does not model, so a session can be held against the original's game logic.
func _lock_setup(g: GalGame, vm: DosMachine, path: String) -> Dictionary:
	if path == "":
		return {}
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(spec) != TYPE_DICTIONARY:
		t.blocked("bad lock file " + path)
		return {}
	var lock: Dictionary = {"segments": spec.segments, "seg": -1, "pic": 0, "anchor": -1,
		"last": 0, "fading": false, "await": false, "shown": 0, "held": 0, "pending": 0}
	g.present_lock = func(base: int) -> void:
		var card: EgaCard = vm.card
		var h: int = hash([card.plane0.slice(base, base + 8000), card.plane1.slice(base, base + 8000),
			card.plane2.slice(base, base + 8000), card.plane3.slice(base, base + 8000)])
		if h == lock.shown:
			return
		lock.shown = h
		if lock.seg < 0 or lock.seg >= lock.segments.size() or lock.anchor < 0:
			return
		var offs: Array = lock.segments[lock.seg]
		# the next picture after those shown and those presented but not yet scanned out
		var j: int = int(lock.pic) + 1 + int(lock.pending)
		lock.pending = int(lock.pending) + 1
		if j >= offs.size():
			return
		var target: int = int(lock.anchor) + int(offs[j])
		if vm.vbl_count < target - 1:
			lock.held = int(lock.held) + 1
			while vm.vbl_count < target - 1 and not g.quitting:
				vm.wait_retrace_start()
			vm.wait_retrace_end()
	return lock


func _lock_display(g: GalGame, vm: DosMachine, lock: Dictionary) -> void:
	var card: EgaCard = vm.card
	var h: int = hash([card.frame_pixels, card.frame_palette]) if not card.frame_mixed else hash(card.frame_rgb())
	# a fade-in (CK_UpdateFadeDrawing's second call) starts a segment at the next picture shown
	var fading: bool = g.ck_fadeDrawCounter == 2
	if fading and not lock.fading:
		lock.await = true
	lock.fading = fading
	if h == lock.last:
		return
	lock.last = h
	var black: bool = true
	for c: int in card.frame_palette:
		if c != 0:
			black = false
			break
	if lock.await and not black:
		lock.await = false
		lock.seg = int(lock.seg) + 1
		lock.anchor = vm.vbl_count
		lock.pic = 0
		lock.pending = 0
	else:
		lock.pic = int(lock.pic) + 1
		if int(lock.pending) > 0:
			lock.pending = int(lock.pending) - 1

