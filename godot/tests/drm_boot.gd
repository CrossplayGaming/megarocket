# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01e "boot": runs the Dreams port headless from the program's start (kd_main_entry: the
## patches, InitGame, the demo loop) for each supported release found under --game_data
## (kdreams = v1.00, kdreams193 = v1.93), writing every displayed EGA picture to a frame store per
## release (--out/<folder>). Checks: the run gets past InitGame without a Quit (the EGA mode is
## reached), the text start screen appears in text mode (written beside the frames as
## text_screen.txt), the title appears (v1.93: the frames hold TITLESCR.LBM as DreamsData
## decodes it; v1.00: the title map, a picture of many colours), and the demo loop goes on
## through distinct pictures until the time limit. Until DreamsGame's actors are ported the run
## may stop at the first unported function (a Quit naming it): reported, not failed.
##
## Options: --game_data=<folder> --out=<folder> --seconds=40
##          --only=<folder> (one release) --keys=<at:scancode:hold,...> (more keys, seconds)
##          --case_keys=<at:scancode:hold,...> (keys timed from the first EGA picture, as the
##          recordings' held keys are: REPLAY-D, tools/dreams_case.py)
##          --cycles= --vbl_period= --timer_offset= (the machine's timing)
##          --tc_adds=<at:tics,...> (HARN-21: at the first EGA picture at or after `at` seconds
##          from the first one, that many tics added to TimeCount: the time the original's loads
##          take that the port's do not yet (TIME-D) runs on its game clock, whose parity decides
##          the tic each frame accelerates on; fitted by tools/fit_dreams.py)
##          --feed_keys=<make_tick:scancode:break_tick,...> (HARN-22: KEYFEED.COM's timetable, 1024 ticks a
##          second from the EGA mode set, no typematic repeat: tools/keyfeed.py)
##          --costs=<name:units,...> (TIME-D: the original's time where the port does the work at once)
##          --clock=us (the DOS clock at the start, microseconds since 00:00:00: the random
##          table's seed is its hundredths at US_Startup; unset, the port's own seed)

## DOSBox's timing as the Vorticons fit found it (same runner settings)
const DOSBOX: Dictionary = {"cycles": 20000, "vbl_period": 17024400, "timer_offset": 0}
## The releases: folder, and the keys the start-up waits for (seconds, scan code): v1.00's piracy
## screen (Return), then the start screen's "Press a Key".
const RELEASES: Array = [
	["kdreams", [[1.0, 0x1c], [3.0, 0x1c]]],
	["kdreams193", [[2.0, 0x1c]]],
]

var t: T = T.new()


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", "")
	var seconds: float = float(opts.get("seconds", "40"))
	if root == "" or out == "":
		t.blocked("need --game_data and --out")
		t.finish(self)
		return
	var ran: int = 0
	for rel: Array in RELEASES:
		var folder: String = rel[0]
		if opts.get("only", folder) != folder:
			continue
		if not DirAccess.dir_exists_absolute(root.path_join(folder)):
			print("  %s: not present, skipped" % folder)
			continue
		_run(root.path_join(folder), out.path_join(folder), folder, rel[1], seconds, opts)
		ran += 1
	if ran == 0:
		t.blocked("no Keen Dreams release under " + root)
	t.finish(self)


func _run(dir: String, out: String, name: String, keys: Array, seconds: float, opts: Dictionary) -> void:
	var d: DreamsData = DreamsData.new()
	if not d.load_game(dir):
		t.blocked("%s does not load: %s" % [name, d.error])
		return
	var vm: DosMachine = DosMachine.new()
	var g: DreamsGame = DreamsGame.new()
	g.vm = vm
	g.data = d
	vm.set_cycles(int(opts.get("cycles", DOSBOX.cycles)))
	vm.vbl_period = int(opts.get("vbl_period", DOSBOX.vbl_period))
	vm.timer_offset = int(opts.get("timer_offset", DOSBOX.timer_offset))
	g.us_dosClockAtStart = int(opts.get("clock", "-1"))
	for spec: String in str(opts.get("costs", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		g.costs[parts[0]] = int(parts[1])
	# the files the program opens itself (gelib's reads): v1.93's title archive
	if d.version == "e193":
		g.us_files["KDREAMS.CMP"] = d._read("KDREAMS.CMP")
	for k: Array in keys:
		vm.add_key(k[0], k[1], 0.1)
	for spec: String in str(opts.get("keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key(float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	for spec: String in str(opts.get("feed_keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.repeat_pause_ms = 0    # the feeder sends no repeats
		vm.add_key_after("mode_0d", int(parts[0]) / 1024.0, int(parts[1]), (int(parts[2]) - int(parts[0])) / 1024.0)
	for spec: String in str(opts.get("case_keys", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key_after("ega", float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	var tc_adds: Array = []
	for spec: String in str(opts.get("tc_adds", "")).split(",", false):
		var parts: PackedStringArray = spec.split(":")
		tc_adds.append([DosMachine.seconds_to_units(float(parts[0])), int(parts[1])])
	DirAccess.make_dir_recursive_absolute(out)
	var writer: FrameWriter = FrameWriter.new()
	if not writer.open(out):
		t.blocked("cannot write " + out + ": " + writer.error)
		return
	var card: EgaCard = vm.card
	var title: PackedByteArray = _decode_ilbm(d.title_shape) if d.version == "e193" else PackedByteArray()
	# [EGA displays, text screen seen, best title match, most colours in a picture, last hash]
	var st: Dictionary = {"ega": 0, "text": "", "title": 0.0, "colours": 0, "last": 0, "pictures": 0}
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA:
			if not tc_adds.is_empty() and vm.marks.has("ega") and vm.now - int(vm.marks["ega"]) >= int(tc_adds[0][0]):
				g.TimeCount = (g.TimeCount + int(tc_adds.pop_front()[1])) & 0xFFFFFFFF
			if st.ega == 0:
				vm.mark("ega")    # the recording's start: DOSBox's first entry into the EGA mode
				print("  %s: the first EGA picture at %.2f s" % [name, vm.seconds()])
			if card.frame_mixed:
				writer.add(card.frame_rgb(), "P")
			else:
				writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
			st.ega += 1
			var h: int = hash(card.frame_pixels)
			if h != st.last:
				st.last = h
				st.pictures += 1
				_look(card.frame_pixels, title, st)
		elif st.text == "":
			var txt: String = _text_screen(g.textmem)
			if txt.to_lower().contains("press a key"):
				st.text = txt
	vm.time_limit = DosMachine.seconds_to_units(seconds)
	vm.on_limit = func() -> void:
		# end the run the way Quit does, without Quit's error report
		g.quitting = true
		g.quit_message = "time limit"
	var t0: int = Time.get_ticks_msec()
	g.kd_main_entry(PackedStringArray())
	var wall: float = (Time.get_ticks_msec() - t0) / 1000.0
	writer.close({"game": name, "seconds": seconds, "kinds": [], "level_starts": [0]})
	var distinct: Dictionary = {}
	for e: Array in writer._index:
		distinct[e[3]] = true
	if st.text != "":
		var f: FileAccess = FileAccess.open(out.path_join("text_screen.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string(st.text)
			f.close()
	print("  %s (%s): %.1f s of game time in %.1f s, %d EGA displays, %d distinct pictures, quit '%s'" %
		[name, d.version, vm.seconds(), wall, st.ega, distinct.size(), g.quit_message])
	print("  %s: title match %.3f, most colours in a picture %d" % [name, st.title, st.colours])
	var unported: bool = g.quit_message.begins_with("not ported yet")
	t.ok("%s: past InitGame without a Quit (the EGA mode reached)" % name, st.ega > 0)
	t.ok("%s: the text start screen in text mode (Keen Dreams, Press a Key)" % name,
		st.text.to_lower().contains("keen dreams") and st.text.to_lower().contains("press a key"))
	if d.version == "e193":
		t.ok("%s: the title picture shown (TITLESCR.LBM, %.1f%% of pixels)" % [name, st.title * 100.0], st.title > 0.99)
	else:
		t.ok("%s: the title map shown (%d colours in a picture)" % [name, st.colours], st.colours >= 8)
	t.ok("%s: distinct pictures (%d)" % [name, distinct.size()], distinct.size() >= 3)
	if unported:
		print("  %s: stopped at an unported function: %s" % [name, g.quit_message])
	else:
		t.ok("%s: the demo loop ran to the time limit (quit '%s')" % [name, g.quit_message], g.quit_message == "time limit")
	g.RF_Shutdown()
	g.release_links()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()


## The colours a picture uses, and how much of it is the title picture (every 3rd pixel).
func _look(px: PackedByteArray, title: PackedByteArray, st: Dictionary) -> void:
	var seen: Dictionary = {}
	for i: int in range(0, px.size(), 7):
		seen[px[i]] = true
	st.colours = maxi(st.colours, seen.size())
	if title.size() != px.size() or st.title > 0.99:
		return
	var same: int = 0
	var n: int = 0
	for i: int in range(0, px.size(), 3):
		n += 1
		if px[i] == title[i]:
			same += 1
	st.title = maxf(st.title, float(same) / n)


## An ILBM shape (SoftLib.load_lib_shape) as 320x200 colour indices: plane by plane, each row
## packbits-compressed if `comp`, as UnpackEGAShapeToScreen reads it.
func _decode_ilbm(sh: Dictionary) -> PackedByteArray:
	if sh.is_empty():
		return PackedByteArray()
	var w: int = sh.w
	var h: int = sh.h
	var planes: int = sh.d
	var bpr: int = ((int(sh.bpr) + 1) >> 1) << 1
	var data: PackedByteArray = sh.data
	var out: PackedByteArray = PackedByteArray()
	out.resize(320 * 200)
	var src: int = 0
	for y: int in range(h):
		for p: int in range(planes):
			var row: PackedByteArray = PackedByteArray()
			while row.size() < bpr and src < data.size():
				if sh.comp:
					var n: int = data[src]
					src += 1
					if n >= 128:
						n -= 256
					if n >= 0:
						for k: int in range(n + 1):
							row.append(data[src] if src < data.size() else 0)
							src += 1
					elif n != -128:
						var v: int = data[src] if src < data.size() else 0
						src += 1
						for k: int in range(-n + 1):
							row.append(v)
				else:
					row.append(data[src])
					src += 1
			if y >= 200 or p >= 4:
				continue
			for x: int in range(mini(w, 320)):
				if (row[x >> 3] if (x >> 3) < row.size() else 0) & (0x80 >> (x & 7)):
					out[y * 320 + x] |= 1 << p
	return out


## The text screen (80x25 characters) as lines of text.
func _text_screen(mem: PackedByteArray) -> String:
	var s: String = ""
	for row: int in range(25):
		var line: String = ""
		for col: int in range(80):
			var ch: int = mem[(row * 80 + col) * 2]
			line += String.chr(ch) if ch >= 32 and ch < 127 else " "
		s += line.strip_edges(false, true) + "\n"
	return s
