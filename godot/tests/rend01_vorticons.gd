# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-01 (Keen 1-3): the draw list rendered at 1x equals the card's picture. Levels and the world
## map are played with the level test's scripted running, jumping, pogoing and firing; every picture
## shown from the last refresh's page (the card's start address and panning are the list's) is drawn
## again from that refresh's draw list (render/vort_draw_renderer.gd) and compared pixel for pixel
## (through the palette: during a fade different indices can show the same colour).
## Pictures the list can't account for (a user routine, a page the lists don't make) are counted
## apart; the claim is that every gameplay picture matches. The first few mismatches are saved as
## PNGs (card left, render right) to --out. REND-02: the layout at 1x (snapped) composed from the data's
## unshifted images is the same picture (tests/list_compare.gd, the comparison the session runners'
## --compare_lists make on the recorded sessions, REND-01R), and at 4x (native) places every image under
## two original pixels from its 1x place.
##
## REND-04 (--wide=N, the wide view's tiles each side): the snapped layout at 320 is still the card's
## picture, at 320 + 32N the same images each shifted by the same amount (inside the map), and creatures
## wake past the original's edge (J-30); without it, none ever does.
##
## Options: --game_data=<folder> --games=keen1,keen2,keen3 --levels=1,2,3 --seconds=10 --out=<folder>
##          [--wide=N]

var t: T = T.new()

const KEY_CTRL: int = 29
const KEY_ALT: int = 56
const KEY_RIGHT: int = 77
const KEY_LEFT: int = 75
const KEY_DOWN: int = 80
const KEY_ENTER: int = 28


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var games: PackedStringArray = str(opts.get("games", "keen1")).split(",")
	var levels: Array = Array(str(opts.get("levels", "1,2,3")).split(",")).map(func(v: String) -> int: return int(v))
	var seconds: float = float(opts.get("seconds", "10"))
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_rend01"))
	DirAccess.make_dir_recursive_absolute(out)
	var wide: int = int(opts.get("wide", "0"))
	for game: String in games:
		var r: Dictionary = _game(root, game, levels, seconds, out, wide)
		print("  %s: %d pictures compared, %d match, %d differ; %d not from the list (user routines, pages the lists don't make)" % [
			game, r.get("compared", 0), r.get("rendered", 0), r.get("render_differ", 0), r.get("skipped", 0)])
		for k: String in r:
			if k.begins_with("why "):
				print("    set aside: %s %d" % [k.substr(4), r[k]])
		if wide == 0:
			t.ok("%s: the draw list's 1x picture equals the card's (%d of %d)" % [game, r.get("rendered", 0), r.get("compared", 0)],
				r.get("compared", 0) > 300 and r.get("render_differ", 1) == 0 and r.get("rendered", 0) == r.get("compared", 0))
		else:
			t.ok("%s: REND-04, at %d pixels every image shifted alike, the map's tiles over all of it (%d of %d)" % [game, 320 + 16 * wide, r.get("shifted", 0), r.get("compared", 0)],
				r.get("compared", 0) > 300 and r.get("shifted", 0) == r.get("compared", 0))
		print("    creatures awake past the original's edge: %d times" % r.get("beyond", 0))
		var rules: Array = r.get("rules", [])
		t.ok("%s: J-30's edges: a creature 24 tiles out wakes, 30 out is kept, only with the wide view (%s)" % [game, rules],
			rules == ([true, true] if wide > 0 else [false, false]))
		var laid: int = r.get("laid", 0) if wide > 0 else r.get("match", 0)
		t.ok("%s: REND-02's layout at 1x, with the unshifted images, equals the card's (%d of %d)" % [game, laid, r.get("compared", 0)],
			r.get("compared", 0) > 300 and laid == r.get("compared", 0))
		print("    windows over the play: %d, the list plus the window's rectangle right in %d" % [r.get("windows", 0), r.get("windows_ok", 0)])
		if wide == 0:
			t.ok("%s: a window over the play: the list's picture with its rectangle from the card is the card's (%d of %d)" % [game, r.get("windows_ok", 0), r.get("windows", 0)],
				r.get("windows", 0) > 10 and r.get("windows_ok", 0) == r.get("windows", 0))
			t.ok("%s: REND-02's native layout at 4x places every image under two original pixels from 1x (%d of %d)" % [game, r.get("placed", 0), r.get("compared", 0)],
				r.get("compared", 0) > 300 and r.get("placed", 0) == r.get("compared", 0))
			print("    smooth motion: %d pairs, %d right, %d sprites slid" % [r.get("smooth_pairs", 0), r.get("smooth", 0), r.get("slid", 0)])
			t.ok("%s: REND-03 between two refreshes: at 1 the newest picture, at a half each followed sprite midway (%d of %d)" % [game, r.get("smooth", 0), r.get("smooth_pairs", 0)],
				r.get("smooth_pairs", 0) > 100 and r.get("smooth", 0) == r.get("smooth_pairs", 0) and r.get("slid", 0) > 100)
	t.finish(self)


func _game(root: String, game: String, levels: Array, seconds: float, out: String, wide: int = 0) -> Dictionary:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
		t.blocked("%s data: %s" % [game, data.error])
		return {}
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_rend01_save_%d" % Time.get_ticks_usec())
	g.draw_capture = true
	g.wide_tiles = wide
	var renderer: VortDrawRenderer = VortDrawRenderer.new()
	var r: Dictionary = {"compared": 0, "match": 0, "differ": 0, "skipped": 0, "saved": 0, "rendered": 0, "render_differ": 0}
	# the layout at 1x against the card's picture, windows over the play, pages set aside: one copy for
	# the tests and the session runners
	var lc: ListCompare = ListCompare.new(r, out, game + "_layout")
	lc.keep = 2
	lc.keep_windows = 2
	var card: EgaCard = vm.card
	vm.on_display = func() -> void:
		var list: Dictionary = lc.vorticons_list(g, vm)
		if list.is_empty():
			return
		# J-30: a creature waking past the original's waking edge (the 23rd tile): the same creature
		# (slot and class) asleep at the last picture, awake at this one, a tile or more past it (the
		# camera may have moved since it woke; a creature spawned into a free slot doesn't count)
		var awake: Dictionary = r.get("awake", {})
		for i: int in range(1, g.numobj):
			var o: Object = g.objlist[i]
			if o.obclass != g.nothing and o.active and awake.has(i) and awake[i] == [o.obclass, false] and (o.x >> 12) >= g.ox + 24:
				r.beyond = r.get("beyond", 0) + 1
			awake[i] = [o.obclass, o.active]
		r["awake"] = awake
		if wide > 0:
			if g.draw_overlaid[int(list.page)] or str(list.user) != "":
				r.skipped += 1
				return
			r.compared += 1
			var o320: Array = VortDrawLayout.ops(g, list)
			var c320: PackedByteArray = VortDrawLayout.compose(g, o320)
			if c320 == card.frame_pixels or ListCompare.same_colours(c320, card.frame_pixels, card.frame_palette):
				r.laid = r.get("laid", 0) + 1
			elif r.get("wide_saved", 0) < 3:
				r.wide_saved = r.get("wide_saved", 0) + 1
				ListCompare.save(card, c320, out.path_join("%s_wide_differ_%d.png" % [game, r.wide_saved]))
			# at 320 + 16 * wide (wide: the tiles the view reaches past the picture on one side, the host's
			# rule) every map tile and sprite the 320 view has, shifted by the same amount
			var ow: Array = VortDrawLayout.ops(g, list, Vector2.ONE, true, 320 + 16 * wide)
			var by_k: Dictionary = {}
			for op: Dictionary in ow:
				if op.has("k"):
					by_k[op.k] = op
			var shift: float = NAN
			var same: bool = true
			for op: Dictionary in o320:
				if not op.has("k") or not by_k.has(op.k):
					continue
				var other: Dictionary = by_k[op.k]
				if is_nan(shift):
					shift = other.x - op.x
				elif absf(other.x - op.x - shift) > 0.001 or absf(other.y - op.y) > 0.001:
					same = false
			# the map's tiles (or the black past a narrow level) cover the whole view: at a map's edge it
			# stands to one side of the picture by all its extra width, which the list's margin must hold
			var cx0: float = INF
			var cx1: float = -INF
			for op: Dictionary in ow:
				if op.kind == "tile":
					cx0 = minf(cx0, op.x)
					cx1 = maxf(cx1, op.x + 16.0)
				elif op.kind == "mask" and op.w > 0.0:
					cx0 = minf(cx0, op.x)
					cx1 = maxf(cx1, op.x + op.w)
			if cx0 > 0.0 or cx1 < float(320 + 16 * wide):
				same = false
				r.uncovered = r.get("uncovered", 0) + 1
			if same:
				r.shifted = r.get("shifted", 0) + 1
			return
		# REND-02's layout at 1x (snapped) with the data's unshifted images against the card's picture; a
		# window over the play: the list's picture with the window's rectangle copied from the card's
		# (what the shell shows) is the card's picture; a user routine set aside
		if lc.vorticons_check(g, list, card).is_empty():
			return
		var pic: PackedByteArray = renderer.render(g, list)
		var ops1: Array = VortDrawLayout.ops(g, list)
		# REND-02 at 4x, native (unsnapped): the same images in the same order, each less than two
		# original pixels from where 1x puts it (1x drops a sprite to its even pixel, under 2, and the
		# scroll's fraction, under 1, the other way)
		var ops4: Array = VortDrawLayout.ops(g, list, Vector2(4, 4), false)
		var placed: bool = ops4.size() == ops1.size()
		for k: int in range(mini(ops1.size(), ops4.size())):
			var a: Dictionary = ops1[k]
			var b: Dictionary = ops4[k]
			if a.kind == "view" and b.kind == "view":
				continue    # the view's corner, in world pixels at any size
			if a.kind != b.kind or a.id != b.id or absf(b.x - a.x * 4.0) >= 8.0 or absf(b.y - a.y * 4.0) >= 8.0:
				placed = false
				break
		if placed:
			r.placed = r.get("placed", 0) + 1
		# REND-03: between the list before and this one: at 1 the picture is this one's; at a half every
		# sprite one owner placed in both (moving less than a jump) is midway, the others where this has them
		var before: Dictionary = g.draw_list_prev if list == g.draw_list else {}
		if not before.is_empty() and before.has("world"):
			var s4: Vector2 = Vector2(4, 4)
			var end_ok: bool = VortDrawLayout.between(g, before, list, 1.0, s4) == VortDrawLayout.ops(g, list, s4, false)
			var half: Array = VortDrawLayout.between(g, before, list, 0.5, s4).filter(func(op: Dictionary) -> bool: return op.kind == "sprite")
			var was: Dictionary = {}
			for w: Array in before.world:
				if int(w[3]) >= 0 and not was.has(int(w[3])):
					was[int(w[3])] = w
			var mid_ok: bool = half.size() == list.world.size()
			var pg: float = g.PIXGLOBAL
			for k: int in range(mini(half.size(), list.world.size())):
				var w: Array = list.world[k]
				var expect: Vector2 = Vector2(float(w[0]), float(w[1])) / pg
				var o: int = int(w[3])
				if o >= 0 and was.has(o) and int(was[o][5]) != int(w[5]):
					r.reused = r.get("reused", 0) + 1    # its slot handed out again: a new object, drawn where it is
				elif o >= 0 and was.has(o):
					var p: Vector2 = Vector2(float(was[o][0]), float(was[o][1])) / pg
					if absf(expect.x - p.x) <= VortDrawLayout.JUMP and absf(expect.y - p.y) <= VortDrawLayout.JUMP:
						expect = (expect + p) / 2.0
						r.slid = r.get("slid", 0) + 1
				# the op is relative to the half-way view; undo it with the half-way view of the layout's tiles
				var view: Vector2 = _view_of(g, before, list, 0.5)
				var got: Vector2 = Vector2(half[k].x, half[k].y) / 4.0 + view
				if got.distance_to(expect) > 0.01:
					mid_ok = false
			if end_ok and mid_ok:
				r.smooth = r.get("smooth", 0) + 1
			r.smooth_pairs = r.get("smooth_pairs", 0) + 1
		# the renderer (the original's page, its pre-shifted sprites) against the card's picture
		if pic == card.frame_pixels or ListCompare.same_colours(pic, card.frame_pixels, card.frame_palette):
			r.rendered = r.get("rendered", 0) + 1    # the same picture (a fade can show different indices in the same colour)
			return
		r.render_differ = r.get("render_differ", 0) + 1
		if r.get("render_saved", 0) < 4:
			r.render_saved = r.get("render_saved", 0) + 1
			ListCompare.save(card, pic, out.path_join("%s_differ_%d.png" % [game, r.render_saved]))
	vm.on_limit = func() -> void:
		g.exited = true
	g.after_startup = func() -> void:
		g.helptextPtr = g.PrepareText(data.help_text)
		g.storytxtPtr = g.PrepareText(data.story_text)
		g.endtextPtr = g.PrepareText(data.end_text)
		g.previewsPtr = g.PrepareText(data.previews_text)
		g.gamestate.lives = 9
		g.gamestate.gotPogo = true
		var stage: Array = [0]
		var run: Callable = func(what: Callable) -> void:
			stage[0] += 1
			var mark: String = "stage%d" % stage[0]
			_script_keys(vm, mark, seconds)
			vm.mark(mark)
			vm.time_limit = vm.now + DosMachine.seconds_to_units(seconds)
			vm.limit_fired = false
			g.exited = false
			what.call()
		for n: int in levels:
			if FileAccess.file_exists(data.dir.path_join(("LEVEL%02d." % n) + data.ext)):
				run.call(func() -> void:
					g.gamestate.ammo = 99
					g.LevelLoop(n))
		run.call(func() -> void:
			g.restoredGame = false
			g.WorldMap())
	g.main()
	# the J-30 rules themselves: a creature 24 tiles past the camera's left (the original wakes at 22 and
	# under), and one 30 past (the original retires past 28), at the camera where the run left it
	var wakes: bool = g.Wakes(g.ox + 24, g.oy + 2)
	g.obon = VortMain.Obj.new()
	g.obon.obclass = 2
	g.obon.x = (g.ox + 30) << 12
	g.obon.y = (g.oy + 2) << 12
	var kept: bool = not g.RemoveInactive()
	r["rules"] = [wakes, kept]
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null
	return r


## Where REND-03's half-way picture has its view, in world pixels (the layout's own rule).
func _view_of(g: Object, a: Dictionary, b: Dictionary, alpha: float) -> Vector2:
	var pg: float = g.PIXGLOBAL
	var bv: Vector2 = Vector2(float(int(b.originx)), float(int(b.originy))) / pg
	var av: Vector2 = Vector2(float(int(a.originx)), float(int(a.originy))) / pg
	if absf(bv.x - av.x) <= VortDrawLayout.JUMP and absf(bv.y - av.y) <= VortDrawLayout.JUMP:
		return av.lerp(bv, alpha)
	return bv


## The level test's input: run right, then left, jumping, pogoing and firing; Enter now and then.
func _script_keys(vm: DosMachine, mark: String, seconds: float) -> void:
	var half: float = seconds / 2.0
	vm.add_key_after(mark, 0.5, KEY_RIGHT, half - 0.5)
	vm.add_key_after(mark, half, KEY_LEFT, half - 0.5)
	var at: float = 0.7
	var k: int = 0
	while at < seconds - 0.3:
		match k % 4:
			0, 2:
				vm.add_key_after(mark, at, KEY_CTRL, 0.25)
			1:
				vm.add_key_after(mark, at, KEY_ALT, 0.4)
			3:
				vm.add_key_after(mark, at, KEY_CTRL, 0.2)
				vm.add_key_after(mark, at, KEY_ALT, 0.2)
		if k % 5 == 4:
			vm.add_key_after(mark, at + 0.1, KEY_ENTER, 0.1)
		if k % 7 == 6:
			vm.add_key_after(mark, at + 0.15, KEY_DOWN, 0.2)
		at += 0.45
		k += 1
