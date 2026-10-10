# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-01 (Keen 1-3): the draw list rendered at 1x equals the card's picture. Levels and the world
## map are played with the level test's scripted running, jumping, pogoing and firing; every picture
## shown from the last refresh's page (the card's start address and panning are the list's) is drawn
## again from that refresh's draw list (render/vort_draw_renderer.gd) and compared pixel for pixel
## (through the palette: during a fade different indices can show the same colour).
## Pictures the list can't account for (a window printed over the play, a user routine) are counted
## apart; the claim is that every gameplay picture matches. The first few mismatches are saved as
## PNGs (card left, render right) to --out. REND-02: the layout at 1x (snapped) composed from the data's
## unshifted images is the same picture, and at 4x (native) places every image under two original pixels
## from its 1x place.
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
		print("  %s: %d pictures compared, %d match, %d differ; %d not from the list (windows, user routines)" % [
			game, r.get("compared", 0), r.get("match", 0), r.get("differ", 0), r.get("skipped", 0)])
		for k: String in r:
			if k.begins_with("user ") or k == "overlaid":
				print("    set aside: %s %d" % [k, r[k]])
		if wide == 0:
			t.ok("%s: the draw list's 1x picture equals the card's (%d of %d)" % [game, r.get("match", 0), r.get("compared", 0)],
				r.get("compared", 0) > 300 and r.get("differ", 1) == 0)
		else:
			t.ok("%s: REND-04, at %d pixels every image shifted alike (%d of %d)" % [game, 320 + 32 * wide, r.get("shifted", 0), r.get("compared", 0)],
				r.get("compared", 0) > 300 and r.get("shifted", 0) == r.get("compared", 0))
		print("    creatures awake past the original's edge: %d times" % r.get("beyond", 0))
		var rules: Array = r.get("rules", [])
		t.ok("%s: J-30's edges: a creature 24 tiles out wakes, 30 out is kept, only with the wide view (%s)" % [game, rules],
			rules == ([true, true] if wide > 0 else [false, false]))
		t.ok("%s: REND-02's layout at 1x, with the unshifted images, equals the card's (%d of %d)" % [game, r.get("laid", 0), r.get("compared", 0)],
			r.get("compared", 0) > 300 and r.get("laid", 0) == r.get("compared", 0))
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
	var r: Dictionary = {"compared": 0, "match": 0, "differ": 0, "skipped": 0, "saved": 0}
	var card: EgaCard = vm.card
	vm.on_display = func() -> void:
		if card.video_mode != EgaCard.MODE_EGA or card.frame_mixed or g.draw_list.is_empty():
			return
		# the picture shown was taken at the last retrace: the newest refresh whose start was written
		# before it
		var list: Dictionary = g.draw_list
		if int(list.written_vbl) < 0 or int(list.written_vbl) >= vm.vbl_count:
			list = g.draw_list_prev
		if list.is_empty() or int(list.written_vbl) < 0 or int(list.written_vbl) >= vm.vbl_count:
			return
		if card.display_start != int(list.start) or (card.atc[EgaCard.ATR_PELPAN] & 7) != int(list.pan):
			r.skipped += 1    # a page the lists don't account for
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
			if c320 == card.frame_pixels or _same_colours(c320, card.frame_pixels, card.frame_palette):
				r.laid = r.get("laid", 0) + 1
			elif r.get("wide_saved", 0) < 3:
				r.wide_saved = r.get("wide_saved", 0) + 1
				_save(card, c320, out.path_join("%s_wide_differ_%d.png" % [game, r.wide_saved]))
			# at 320 + 32 * wide every map tile and sprite the 320 view has, shifted by the same amount
			var ow: Array = VortDrawLayout.ops(g, list, Vector2.ONE, true, 320 + 32 * wide)
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
			if same:
				r.shifted = r.get("shifted", 0) + 1
			return
		var pic: PackedByteArray = renderer.render(g, list)
		if pic.is_empty() and g.draw_overlaid[int(list.page)] and str(list.user) == "":
			# a window over the play: the list's picture with the window's rectangle copied from the card's
			# (what the shell shows) is the card's picture
			var rect: Rect2i = g.draw_overlay_rect[int(list.page)].intersection(Rect2i(0, 0, 320, 200))
			var with: PackedByteArray = VortDrawLayout.compose(g, VortDrawLayout.ops(g, list))
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					with[y * 320 + x] = card.frame_pixels[y * 320 + x]
			r.windows = r.get("windows", 0) + 1
			if with == card.frame_pixels or _same_colours(with, card.frame_pixels, card.frame_palette):
				r.windows_ok = r.get("windows_ok", 0) + 1
			elif r.get("win_saved", 0) < 2:
				r.win_saved = r.get("win_saved", 0) + 1
				_save(card, with, out.path_join("%s_window_differ_%d.png" % [game, r.win_saved]))
		if pic.is_empty():
			r.skipped += 1
			var why: String = "user " + str(list.user) if str(list.user) != "" else "overlaid"
			r[why] = r.get(why, 0) + 1
			return
		r.compared += 1
		# REND-02's layout at 1x (snapped) with the data's unshifted images: the same picture
		var ops1: Array = VortDrawLayout.ops(g, list)
		var laid: PackedByteArray = VortDrawLayout.compose(g, ops1)
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
				if o >= 0 and was.has(o):
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
		if laid == card.frame_pixels or _same_colours(laid, card.frame_pixels, card.frame_palette):
			r.laid = r.get("laid", 0) + 1
		elif r.get("laid_saved", 0) < 2:
			r.laid_saved = r.get("laid_saved", 0) + 1
			_save(card, laid, out.path_join("%s_layout_differ_%d.png" % [game, r.laid_saved]))
		if pic == card.frame_pixels or _same_colours(pic, card.frame_pixels, card.frame_palette):
			r.match += 1    # the same picture (a fade can show different indices in the same colour)
			return
		r.differ += 1
		if r.saved < 4:
			r.saved += 1
			_save(card, pic, out.path_join("%s_differ_%d.png" % [game, r.saved]))
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
