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
## every picture from a refresh matches (the level's, and v1.00's title map, which the shell shows framed
## as a screen but which is a refresh's picture all the same). The first few mismatches are saved as PNGs
## (card left, render right) to --out. The comparison is tests/list_compare.gd's, which the session
## runners' --compare_lists make on the recorded sessions (REND-01R).
## REND-02: at 4x (native) the same images in the same order, each under its step from its 1x place (two
## original pixels; a sprite with two shifted copies four, with one eight: the original moves those on the
## copies' grid). REND-03D: between two refreshes, at 1 the newest's layout, at a half each followed sprite
## midway; a creature that stepped (its state's whole move made as its time ran out, with its next picture)
## where the newest has it.
## Windows over the play (REND-09): the credits over v1.00's title map, "Loading" and the level's name, the
## status window (Space), each a rectangle the list carries as its overlay: the list's picture with that
## rectangle copied from the card's is the card's.
## The game left alone: the level run again without the draw lists ends the same (the machine's time, the
## game state's hash, the origin).
##
## REND-04D (--wide=N, the wide view's tiles each side): the 1x picture is still the card's, at 320 + 16N
## every map tile and sprite the 320 view has is shifted by the same amount, the score box stays where it is
## on the screen (the view's corner), the map's tiles (or the black past a narrow level) cover the whole
## view; creatures wake past the original's edge (J-30: a creature inactive at one picture, active at the
## next, wholly outside the original's waking columns); without it, none ever does.
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
		print("    creatures woken past the original's edge: %d" % r.get("beyond", 0))
		t.ok("%s: J-30, creatures wake by the wide view's edges only with it (%d woke past the original's)" % [folder, r.get("beyond", 0)],
			(r.get("beyond", 0) > 0) == (wide > 0))
		if wide > 0:
			t.ok("%s: REND-04D, at %d pixels every image shifted alike, the score box kept on the screen, the map's tiles over all of it (%d of %d)" % [folder, 320 + 16 * wide, r.get("shifted", 0), r.compared],
				r.compared > 300 and r.get("shifted", 0) == r.compared)
		print("    smooth motion: %d pairs, %d right, %d sprites slid, %d stepped, %d new in a reused record" % [r.get("smooth_pairs", 0), r.get("smooth", 0), r.get("slid", 0), r.get("stepped", 0), r.get("reused", 0)])
		t.ok("%s: REND-03D between two refreshes: at 1 the newest picture, at a half each followed sprite midway, the creatures' steps not slid, a new sprite in a reused record drawn where it is (%d of %d; %d stepped, %d new)" % [folder, r.get("smooth", 0), r.get("smooth_pairs", 0), r.get("stepped", 0), r.get("reused", 0)],
			r.get("smooth_pairs", 0) > 100 and r.get("smooth", 0) == r.get("smooth_pairs", 0) and r.get("slid", 0) > 100 and r.get("stepped", 0) > 0
			and r.get("reused", 0) > 0)
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
	var lc: ListCompare = ListCompare.new(r, out, "%s_level%d" % [folder, level], images)
	var awake: Dictionary = {}
	vm.on_display = func() -> void:
		if not capture or card.video_mode != EgaCard.MODE_EGA or card.frame_mixed:
			return
		# J-30: a creature asleep at the last picture, awake at this one, wholly past the original's waking
		# columns (the port's 21 tiles, and the tile the view may have scrolled since it woke)
		if g.player != null and level >= 0:
			var o: Object = g.player.next
			while o != null:
				if o.active != 0 and awake.get(o, [-1, 1]) == [o.obclass, 0] and \
						(o.tileleft > g.originxtilemax + 1 or o.tileright < g.originxtile - 1):
					r.beyond = r.get("beyond", 0) + 1
				awake[o] = [o.obclass, o.active]
				o = o.next
		# the list composed at 1x against the card's picture (a window over the play: the window check;
		# a picture no list makes set aside)
		var list: Dictionary = lc.dreams_list(g, vm)
		if list.is_empty() or lc.galaxy_check(g, list, card, false).is_empty():
			return
		var ops1: Array = DrmDrawLayout.ops(g, list)
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
		# REND-03D: at 1 the newest list's layout; at a half each sprite in both (by its record) midway
		var before: Dictionary = g.draw_list_prev if is_same(list, g.draw_list) else {}
		if not before.is_empty() and not before.get("none", false) and before.has("sprites"):
			_smooth_check(g, d, before, list, r)
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


## REND-03D, a pair of refreshes: at 1 the newest list's layout exactly; at a half every sprite whose record
## is in both lists midway between its places (the view too), unless it stepped (b's "step") or jumped
## further than JUMP, when it is where the newest has it.
func _smooth_check(g: Object, d: DreamsData, before: Dictionary, list: Dictionary, r: Dictionary) -> void:
	var s4: Vector2 = Vector2(4, 4)
	var end_ok: bool = DrmDrawLayout.between(g, before, list, 1.0, s4) == DrmDrawLayout.ops(g, list, s4, false)
	var half: Array = DrmDrawLayout.between(g, before, list, 0.5, s4).filter(func(op: Dictionary) -> bool:
		return op.kind == "sprite")
	var was: Dictionary = {}
	for s: Array in before.sprites:
		was[int(s[5])] = s
	var mid_ok: bool = half.size() == list.sprites.size()
	var view: Vector2 = _view_of(before, list, 0.5)
	for k: int in range(mini(half.size(), list.sprites.size())):
		var s: Array = list.sprites[k]
		if int(s[5]) == int(list.hud):
			continue
		var expect: Vector2 = Vector2(float(s[6]), float(s[7])) / 16.0
		if list.get("step", []).has(int(s[5])):
			r.stepped = r.get("stepped", 0) + 1
		elif was.has(int(s[5])) and int(was[int(s[5])][8]) != int(s[8]):
			r.reused = r.get("reused", 0) + 1    # its entry handed out again: a new sprite, drawn where it is
		elif was.has(int(s[5])):
			var p: Vector2 = Vector2(float(was[int(s[5])][6]), float(was[int(s[5])][7])) / 16.0
			if absf(expect.x - p.x) <= DrmDrawLayout.JUMP and absf(expect.y - p.y) <= DrmDrawLayout.JUMP:
				expect = (expect + p) / 2.0
				r.slid = r.get("slid", 0) + 1
		var got: Vector2 = Vector2(half[k].x, half[k].y) / 4.0 + view
		if got.distance_to(expect) > 0.01:
			mid_ok = false
	if end_ok and mid_ok:
		r.smooth = r.get("smooth", 0) + 1
	r.smooth_pairs = r.get("smooth_pairs", 0) + 1


## Where REND-03's half-way picture has its view, in world pixels (the layout's own rule).
func _view_of(a: Dictionary, b: Dictionary, alpha: float) -> Vector2:
	var bv: Vector2 = Vector2(float(int(b.ux)), float(int(b.uy))) / 16.0
	var av: Vector2 = Vector2(float(int(a.ux)), float(int(a.uy))) / 16.0
	if absf(bv.x - av.x) <= DrmDrawLayout.JUMP and absf(bv.y - av.y) <= DrmDrawLayout.JUMP:
		return av.lerp(bv, alpha)
	return bv
