# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-01D (Keen Dreams, v1.00 and v1.93): the draw list drawn at 1x equals the card's picture. Each
## release is run headless from its start through its title demo (v1.00's title map scrolled between the
## credits; v1.93 shows pictures, none from a refresh), then straight into a level (--kl_warp's way, HARN-23)
## with the trace tool's keys (a walk left with jumps and throws, a turn back now and then) and the status
## window opened once; every picture shown from a refresh's page (the card's start address and panning are
## the list's, nothing written onto the page since) is drawn again from that refresh's draw list
## (render/drm_draw_layout.gd with the data's unshifted images, render/drm_images.gd) and compared pixel for
## pixel through the palette (a fade can show different indices in the same colour). Pictures the lists
## don't account for (the title picture, the panel, the high scores) are counted apart; the claim is that
## every gameplay picture matches. The first few mismatches are saved as PNGs (card left, render right) to
## --out.
## REND-02: at 4x (native) the same images in the same order, each under its step from its 1x place (two
## original pixels; a sprite with two shifted copies four, with one eight: the original moves those on the
## copies' grid).
## Windows over the play (REND-09): the credits over v1.00's title map, "Loading" and the level's name, the
## status window (Space), each a rectangle the list carries as its overlay: the list's picture with that
## rectangle copied from the card's is the card's.
## The game left alone: the level run again without the draw lists ends the same (the machine's time, the
## game state's hash, the origin).
##
## Options: --game_data=<folder> [--releases=kdreams,kdreams193] [--level=1] [--title_seconds=30]
##          [--level_seconds=45] [--out=<folder>] [--wide=N]

var t: T = T.new()

## The releases: folder, and the keys the start-up waits for (seconds, scan code): v1.00's piracy screen
## (Return; skipped on the way straight into a level), then the start screen's "Press a Key".
const RELEASES: Dictionary = {"kdreams": [[1.0, 0x1C], [3.0, 0x1C]], "kdreams193": [[2.0, 0x1C]]}
## DOSBox's timing as drm_boot has it
const DOSBOX: Dictionary = {"cycles": 20000, "vbl_period": 17024400, "timer_offset": 0}
const LEFT: int = 0x4B
const RIGHT: int = 0x4D
const JUMP: int = 0x1D
const THROW: int = 0x38
const SPACE: int = 0x39
const ENTER: int = 0x1C


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_rend01d"))
	DirAccess.make_dir_recursive_absolute(out)
	var wide: int = int(opts.get("wide", "0"))
	var level: int = int(opts.get("level", "1"))
	var title_s: float = float(opts.get("title_seconds", "30"))
	var level_s: float = float(opts.get("level_seconds", "45"))
	var ran: int = 0
	for folder: String in str(opts.get("releases", "kdreams,kdreams193")).split(",", false):
		if not DirAccess.dir_exists_absolute(root.path_join(folder)):
			print("  %s: not present, skipped" % folder)
			continue
		ran += 1
		var r: Dictionary = {"compared": 0, "match": 0, "differ": 0, "skipped": 0, "saved": 0}
		var t0: int = Time.get_ticks_msec()
		_run(root, folder, -1, title_s, out, r, wide, true)
		var end: Array = _run(root, folder, level, level_s, out, r, wide, true)
		var plain: Array = _run(root, folder, level, level_s, out, {}, wide, false)
		print("  %s: %d pictures compared, %d match, %d differ; %d not from a list (%.1f s)" % [
			folder, r.compared, r.match, r.differ, r.skipped, (Time.get_ticks_msec() - t0) / 1000.0])
		for k: String in r:
			if k.begins_with("why "):
				print("    set aside: %s %d" % [k.substr(4), r[k]])
		t.ok("%s: the game is left alone: level %d ends the same without the draw lists (%s / %s)" % [folder, level, end, plain],
			not plain.is_empty() and plain == end)
		t.ok("%s: the draw list's 1x picture equals the card's (%d of %d)" % [folder, r.match, r.compared],
			r.compared > 300 and r.differ == 0)
		t.ok("%s: REND-02's native layout at 4x places every image under its step from 1x (two original pixels; a sprite with fewer copies, four or eight) (%d of %d)" % [folder, r.get("placed", 0), r.compared],
			r.compared > 300 and r.get("placed", 0) == r.compared)
		print("    windows over the play: %d pictures (%d within the picture), %d right" % [r.get("windows", 0), r.get("windows_part", 0), r.get("windows_ok", 0)])
		t.ok("%s: windows over the play: the list's picture with the window's rectangle from the card is the card's (%d of %d)" % [folder, r.get("windows_ok", 0), r.get("windows", 0)],
			r.get("windows", 0) > 20 and r.get("windows_ok", 0) == r.get("windows", 0))
		if wide > 0:
			t.ok("%s: REND-04D, at %d pixels every image shifted alike, the score box kept on the screen, the map's tiles over all of it (%d of %d)" % [folder, 320 + 16 * wide, r.get("shifted", 0), r.compared],
				r.compared > 300 and r.get("shifted", 0) == r.compared)
	if ran == 0:
		t.blocked("no Keen Dreams release under " + root)
	t.finish(self)


## The trace tool's keys (tools/dreams_trace.py default_keys): a direction held, with jump and throw every
## 3 seconds from 4 and a turn back for a second every 10, from `t0`; the status window at 20 s, dismissed
## a moment later.
func _play_keys(vm: DosMachine, t0: float, seconds: float) -> void:
	var at: float = 3.0
	while at < seconds:
		vm.add_key(t0 + at, LEFT, 9.0)
		vm.add_key(t0 + at + 9.0, RIGHT, 1.0)
		at += 10.0
	at = 4.0
	while at < seconds - 1.0:
		vm.add_key(t0 + at, JUMP, 0.4)
		vm.add_key(t0 + at + 1.5, THROW, 0.2)
		at += 3.0
	vm.add_key(t0 + 20.0, SPACE, 0.2)
	vm.add_key(t0 + 21.5, ENTER, 0.2)


## One run: the release from its start, into `level` (-1: the title demo left to itself), for `seconds` of
## the machine's time, checking each picture (with `capture`); returns how it ended: [the machine's time,
## the game state's hash, the origin].
func _run(root: String, folder: String, level: int, seconds: float, out: String, r: Dictionary, wide: int, capture: bool) -> Array:
	var d: DreamsData = DreamsData.new()
	if not d.load_game(root.path_join(folder)):
		t.blocked("%s data: %s" % [folder, d.error])
		return []
	var images: DrmImages = DrmImages.new(d)
	var vm: DosMachine = DosMachine.new()
	var g: DreamsGame = DreamsGame.new()
	g.vm = vm
	g.data = d
	vm.set_cycles(int(DOSBOX.cycles))
	vm.vbl_period = int(DOSBOX.vbl_period)
	vm.timer_offset = int(DOSBOX.timer_offset)
	g.kl_warp = level
	g.draw_capture = capture
	g.wide_tiles = wide
	if d.version == "e193":
		g.us_files["KDREAMS.CMP"] = d._read("KDREAMS.CMP")
	for k: Array in RELEASES[folder]:
		vm.add_key(k[0], k[1], 0.1)
	if level >= 0:
		_play_keys(vm, 6.0, seconds - 6.0)
	var card: EgaCard = vm.card
	var cache: Dictionary = {"t": -1.0, "overlay": Rect2i(), "pic": PackedByteArray()}
	vm.on_display = func() -> void:
		if not capture or card.video_mode != EgaCard.MODE_EGA or card.frame_mixed:
			return
		var list: Dictionary = shown(g, vm)
		if list.is_empty():
			return
		var why: String = ""
		if list.get("none", false):
			why = "not a refresh"
		elif list.get("touched", false):
			why = "written onto the page"
		elif str(list.user) != "":
			why = "draw routine " + str(list.user)
		elif not list.play:
			why = "not the play"
		if why != "":
			r.skipped += 1
			r["why " + why] = r.get("why " + why, 0) + 1
			return
		if list.get("overlay", Rect2i()).size != Vector2i.ZERO:
			_window(g, images, list, card, r, out, folder, cache)
			return
		r.compared += 1
		var ops1: Array = DrmDrawLayout.ops(g, list)
		var pic: PackedByteArray = _composed(g, images, list, cache)
		# REND-02 at 4x, native: the same images in the same order, each less than two original pixels
		# from its 1x place (1x drops a sprite to its shifted copy's pixel and the scroll to its even one)
		var ops4: Array = DrmDrawLayout.ops(g, list, Vector2(4, 4), false)
		var placed: bool = ops4.size() == ops1.size()
		for k: int in range(mini(ops1.size(), ops4.size())):
			var a: Dictionary = ops1[k]
			var b: Dictionary = ops4[k]
			if a.kind == "view" and b.kind == "view":
				continue
			# a sprite with fewer shifted copies steps further: four pixels with two, eight with one
			var step: float = 2.0
			if a.kind == "sprite":
				step = maxf(2.0, 8.0 / float(maxi(1, int(d.sprite_table[int(a.id) - DreamsData.STARTSPRITES].shifts))))
			if a.kind != b.kind or a.id != b.id or absf(b.x - a.x * 4.0) >= step * 4.0 or absf(b.y - a.y * 4.0) >= 8.0:
				placed = false
				break
		if placed:
			r.placed = r.get("placed", 0) + 1
		if wide > 0:
			_wide_check(g, list, ops1, wide, r)
		if pic == card.frame_pixels or _same_colours(pic, card.frame_pixels, card.frame_palette):
			r.match += 1
			return
		r.differ += 1
		if r.saved < 6:
			r.saved += 1
			_save(card, pic, out.path_join("%s_level%d_differ_%d.png" % [folder, level, r.saved]))
	vm.time_limit = DosMachine.seconds_to_units(seconds)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.kd_main_entry(PackedStringArray())
	var end: Array = [vm.now, g._kl_state_hash() if g.player != null else -1, g.originxglobal, g.originyglobal, g.quit_message]
	g.RF_Shutdown()
	g.release_links()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return end


## The list composed at 1x (kept for the next picture of the same refresh).
func _composed(g: Object, images: DrmImages, list: Dictionary, cache: Dictionary) -> PackedByteArray:
	var over: Rect2i = list.get("overlay", Rect2i())
	if float(cache.t) == float(list.t) and cache.overlay == over and not (cache.pic as PackedByteArray).is_empty():
		return cache.pic
	var pic: PackedByteArray = DrmDrawLayout.compose(images, DrmDrawLayout.ops(g, list), list.dyn)
	cache.t = float(list.t)
	cache.overlay = over
	cache.pic = pic
	return pic


## REND-04D: at 320 + 16 * wide (wide: the tiles the view reaches past the picture on one side, the host's
## rule): every image the 320 view has, shifted alike; the score box where it was on the screen; the map's
## tiles (or the black past a narrow level) over the whole view.
func _wide_check(g: Object, list: Dictionary, ops1: Array, wide: int, r: Dictionary) -> void:
	var vw: int = 320 + 16 * wide
	var ow: Array = DrmDrawLayout.ops(g, list, Vector2.ONE, true, vw)
	var by_k: Dictionary = {}
	for op: Dictionary in ow:
		if op.has("k"):
			by_k[op.k] = op
	var shift: float = NAN
	var same: bool = true
	for op: Dictionary in ops1:
		if not op.has("k") or not by_k.has(op.k):
			continue
		var other: Dictionary = by_k[op.k]
		if op.get("hud", false):
			if absf(other.x - op.x) > 0.001 or absf(other.y - op.y) > 0.001:
				same = false
			continue
		if is_nan(shift):
			shift = other.x - op.x
		elif absf(other.x - op.x - shift) > 0.001 or absf(other.y - op.y) > 0.001:
			same = false
	var cx0: float = INF
	var cx1: float = -INF
	for op: Dictionary in ow:
		if op.kind == "tile":
			cx0 = minf(cx0, op.x)
			cx1 = maxf(cx1, op.x + 16.0)
		elif op.kind == "mask" and op.w > 0.0:
			cx0 = minf(cx0, op.x)
			cx1 = maxf(cx1, op.x + op.w)
	if cx0 > 0.0 or cx1 < float(vw):
		same = false
		r.uncovered = r.get("uncovered", 0) + 1
	if same:
		r.shifted = r.get("shifted", 0) + 1


## A picture with a window over the play: the list's with the overlay's rectangle copied from the card's
## is the card's.
func _window(g: Object, images: DrmImages, list: Dictionary, card: EgaCard, r: Dictionary, out: String, folder: String, cache: Dictionary) -> void:
	var with: PackedByteArray = _composed(g, images, list, cache).duplicate()
	var rect: Rect2i = (list.overlay as Rect2i).intersection(Rect2i(0, 0, 320, 200))
	for y: int in range(rect.position.y, rect.end.y):
		var row: int = y * 320
		for x: int in range(rect.position.x, rect.end.x):
			with[row + x] = card.frame_pixels[row + x]
	r.windows = r.get("windows", 0) + 1
	if rect.size.x < 320 or rect.size.y < 200:
		r.windows_part = r.get("windows_part", 0) + 1
	if with == card.frame_pixels or _same_colours(with, card.frame_pixels, card.frame_palette):
		r.windows_ok = r.get("windows_ok", 0) + 1
	elif r.get("win_saved", 0) < 3:
		r.win_saved = r.get("win_saved", 0) + 1
		_save(card, with, out.path_join("%s_window_differ_%d.png" % [folder, r.win_saved]))


## The list of the picture on display (taken at the last retrace): the newest whose start was written
## before it, if the card's start and panning are that list's; {} when none is.
static func shown(g: Object, vm: DosMachine) -> Dictionary:
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return {}
	if vm.card.display_start != int(list.start):
		return {}
	if not list.get("none", false) and (vm.card.atc[EgaCard.ATR_PELPAN] & 7) != int(list.get("pan", 0)):
		return {}
	return list


## The two pictures look the same through the palette (every index pair the same colour).
func _same_colours(a: PackedByteArray, b: PackedByteArray, pal: PackedByteArray) -> bool:
	var same: Dictionary = {}
	for i: int in range(a.size()):
		var x: int = a[i]
		var y: int = b[i]
		if x == y:
			continue
		var key: int = x * 16 + y
		if not same.has(key):
			same[key] = pal[x * 3] == pal[y * 3] and pal[x * 3 + 1] == pal[y * 3 + 1] and pal[x * 3 + 2] == pal[y * 3 + 2]
		if not same[key]:
			return false
	return true


func _save(card: EgaCard, pic: PackedByteArray, path: String) -> void:
	var pal: PackedByteArray = card.frame_palette
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(640 * 200 * 3)
	for y: int in range(200):
		for x: int in range(320):
			for side: int in range(2):
				var c: int = (card.frame_pixels if side == 0 else pic)[y * 320 + x] * 3
				var o: int = (y * 640 + side * 320 + x) * 3
				rgb[o] = pal[c]
				rgb[o + 1] = pal[c + 1]
				rgb[o + 2] = pal[c + 2]
	Image.create_from_data(640, 200, false, Image.FORMAT_RGB8, rgb).save_png(path)
