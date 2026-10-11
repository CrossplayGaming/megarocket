# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-01 (Keen 4-6): the draw list drawn at 1x equals the card's picture. Each episode's built-in demos
## are played (the original's /PLAYDEMO n); every picture shown from a refresh's page (the card's start
## address is the list's, nothing written onto the page since) is drawn again from that refresh's draw
## list (render/gal_draw_layout.gd with the data's unshifted images) and compared pixel for pixel through
## the palette (a fade can show different indices in the same colour). Pictures the lists don't account
## for (a menu, a window, a draw routine over the play) are counted apart; the claim is that every
## gameplay picture matches. The first few mismatches are saved as PNGs (card left, render right) to --out.
## REND-02: at 4x (native) the same images in the same order, each under its step from its 1x place (two
## original pixels; a sprite with two shifted copies four, with one eight: the original moves those on
## the copies' grid). REND-03: between two refreshes, at 1 the newest's layout, at a half each followed
## sprite midway.
##
## REND-04 (--wide=N, the wide view's tiles each side): the 1x picture is still the card's, at 320 + 32N
## every map tile and sprite the 320 view has is shifted by the same amount, the score box (or demo sign)
## stays where it is on the screen (the view's corner, or its middle); creatures wake past the original's
## edge (J-30: a creature inactive at one picture, active at the next, wholly outside the original's
## waking columns); without it, none ever does.
##
## The game left alone: the first demo played again without the draw lists ends the same (the machine's
## time, Keen's place, the score, the level).
##
## Windows over the play (REND-09): a new game started from the keyboard; on the world map Enter (the
## status window, down and up again) and B+A+T (the item cheat's window, drawn outside the refreshes);
## every picture with a window over the play is the list's picture with the window's rectangle (the
## list's overlay) copied from the card's: what the shell shows. Any such picture in the demos counts too.
##
## Options: --game_data=<folder> --games=keen4,keen5,keen6 --demos=0,1,2,3 --out=<folder> [--wide=N]

var t: T = T.new()

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_rend01g"))
	DirAccess.make_dir_recursive_absolute(out)
	var demos: PackedStringArray = str(opts.get("demos", "0,1,2,3")).split(",", false)
	var wide: int = int(opts.get("wide", "0"))
	for game: String in str(opts.get("games", "keen4,keen5,keen6")).split(",", false):
		var r: Dictionary = {"compared": 0, "match": 0, "differ": 0, "skipped": 0, "saved": 0}
		var ends: Array = []
		for n: String in demos:
			ends.append(_demo(root, game, int(n), out, r, wide))
		var plain: Array = _demo(root, game, int(demos[0]), out, {}, wide, false)
		t.ok("%s: the game is left alone: demo %s ends the same without the draw lists (%s / %s)" % [game, demos[0], ends[0], plain],
			not plain.is_empty() and plain == ends[0])
		print("  %s: %d pictures compared, %d match, %d differ; %d not from a list" % [
			game, r.compared, r.match, r.differ, r.skipped])
		for k: String in r:
			if k.begins_with("why "):
				print("    set aside: %s %d" % [k.substr(4), r[k]])
		t.ok("%s: the draw list's 1x picture equals the card's (%d of %d)" % [game, r.match, r.compared],
			r.compared > 300 and r.differ == 0)
		t.ok("%s: REND-02's native layout at 4x places every image under its step from 1x (two original pixels; a sprite with fewer copies, four or eight) (%d of %d)" % [game, r.get("placed", 0), r.compared],
			r.compared > 300 and r.get("placed", 0) == r.compared)
		_status(root, game, out, r, wide)
		print("    windows over the play: %d pictures (%d within the picture), %d right; item cheat window %s" % [r.get("windows", 0), r.get("windows_part", 0), r.get("windows_ok", 0), r.get("cheat_window", "not seen")])
		t.ok("%s: windows over the play: the list's picture with the window's rectangle from the card is the card's (%d of %d)" % [game, r.get("windows_ok", 0), r.get("windows", 0)],
			r.get("windows", 0) > 20 and r.get("windows_ok", 0) == r.get("windows", 0))
		t.ok("%s: the item cheat's window (drawn outside the refreshes) came along as an overlay: %s" % [game, r.get("cheat_window", "not seen")],
			r.get("cheat_window", Rect2i()) is Rect2i)
		print("    creatures woken past the original's edge: %d" % r.get("beyond", 0))
		t.ok("%s: J-30, creatures wake by the wide view's edges only with it (%d woke past the original's)" % [game, r.get("beyond", 0)],
			(r.get("beyond", 0) > 0) == (wide > 0))
		if wide > 0:
			t.ok("%s: REND-04, at %d pixels every image shifted alike, the HUD kept on the screen, the map's tiles over all of it (%d of %d)" % [game, 320 + 16 * wide, r.get("shifted", 0), r.compared],
				r.compared > 300 and r.get("shifted", 0) == r.compared)
		print("    smooth motion: %d pairs, %d right, %d sprites slid, %d stepped, %d new in a reused entry" % [r.get("smooth_pairs", 0), r.get("smooth", 0), r.get("slid", 0), r.get("stepped", 0), r.get("reused", 0)])
		t.ok("%s: REND-03 between two refreshes: at 1 the newest picture, at a half each followed sprite midway (%d of %d)" % [game, r.get("smooth", 0), r.get("smooth_pairs", 0)],
			r.get("smooth_pairs", 0) > 100 and r.get("smooth", 0) == r.get("smooth_pairs", 0) and r.get("slid", 0) > 100)
	t.finish(self)


## Plays demo n, checking each picture (with `capture`); returns how it ended: [the machine's time, Keen's
## place, the score, the level].
func _demo(root: String, game: String, n: int, out: String, r: Dictionary, wide: int, capture: bool = true) -> Array:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game])):
		t.blocked("%s data: %s" % [game, d.error])
		return []
	var images: GalImages = GalImages.new(d)
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	g.draw_capture = capture
	g.wide_tiles = wide
	var awake: Dictionary = {}
	var card: EgaCard = vm.card
	vm.on_display = func() -> void:
		if not capture or card.video_mode != EgaCard.MODE_EGA or card.frame_mixed:
			return
		# J-30: a creature asleep at the last picture, awake at this one, wholly past the original's waking
		# columns (a tile beyond the 21 the screen spans)
		var stx: int = g.rf_scrollXUnit >> 8
		var o: Object = g.ck_keenObj.next if g.ck_keenObj != null else null
		while o != null:
			if o.active != 0 and awake.get(o, [-1, 1]) == [o.type, 0] and \
					(o.clipRects.tileX1 > stx + 21 or o.clipRects.tileX2 < stx - 1):
				r.beyond = r.get("beyond", 0) + 1
			awake[o] = [o.type, o.active]
			o = o.next
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
			why = "high scores"
		if why != "":
			r.skipped += 1
			r["why " + why] = r.get("why " + why, 0) + 1
			return
		if list.get("overlay", Rect2i()).size != Vector2i.ZERO:
			_window(g, images, list, card, r, out, game)
			return
		r.compared += 1
		var ops1: Array = GalDrawLayout.ops(g, list)
		var pic: PackedByteArray = GalDrawLayout.compose(images, ops1, list.dyn)
		# REND-02 at 4x, native: the same images in the same order, each less than two original pixels
		# from its 1x place (1x drops a sprite to its shifted copy's pixel and the scroll to its even one)
		var ops4: Array = GalDrawLayout.ops(g, list, Vector2(4, 4), false)
		var placed: bool = ops4.size() == ops1.size()
		for k: int in range(mini(ops1.size(), ops4.size())):
			var a: Dictionary = ops1[k]
			var b: Dictionary = ops4[k]
			if a.kind == "view" and b.kind == "view":
				continue
			# a sprite with fewer shifted copies steps further: four pixels with two, eight with one
			var step: float = 2.0
			if a.kind in ["sprite", "smask"]:
				step = maxf(2.0, 8.0 / float(maxi(1, int(d.sprite_table[int(a.id) - int(d.gfx.offSprites)].shifts))))
			if a.kind != b.kind or a.id != b.id or absf(b.x - a.x * 4.0) >= step * 4.0 or absf(b.y - a.y * 4.0) >= 8.0:
				placed = false
				break
		if placed:
			r.placed = r.get("placed", 0) + 1
		if wide > 0:
			# at 320 + 16 * wide (wide: the tiles the view reaches past the picture on one side, the host's
			# rule): every image the 320 view has, shifted alike; the HUD where it was on the screen
			var vw: int = 320 + 16 * wide
			var ow: Array = GalDrawLayout.ops(g, list, Vector2.ONE, true, vw)
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
					var hx: float = op.x + (float(vw - 320) / 2.0 if list.get("hud_mid", false) else 0.0)
					if absf(other.x - hx) > 0.001 or absf(other.y - op.y) > 0.001:
						same = false
					continue
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
			if cx0 > 0.0 or cx1 < float(vw):
				same = false
				r.uncovered = r.get("uncovered", 0) + 1
			if same:
				r.shifted = r.get("shifted", 0) + 1
		# REND-03: at 1 the newest list's layout; at a half each sprite in both (by its entry) midway
		var before: Dictionary = g.draw_list_prev if list == g.draw_list else {}
		if not before.is_empty() and not before.get("none", false) and before.has("sprites"):
			var s4: Vector2 = Vector2(4, 4)
			var end_ok: bool = GalDrawLayout.between(g, before, list, 1.0, s4) == GalDrawLayout.ops(g, list, s4, false)
			var half: Array = GalDrawLayout.between(g, before, list, 0.5, s4).filter(func(op: Dictionary) -> bool:
				return op.kind in ["sprite", "smask"])
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
					if absf(expect.x - p.x) <= GalDrawLayout.JUMP and absf(expect.y - p.y) <= GalDrawLayout.JUMP:
						expect = (expect + p) / 2.0
						r.slid = r.get("slid", 0) + 1
				var got: Vector2 = Vector2(half[k].x, half[k].y) / 4.0 + view
				if got.distance_to(expect) > 0.01:
					mid_ok = false
			if end_ok and mid_ok:
				r.smooth = r.get("smooth", 0) + 1
			r.smooth_pairs = r.get("smooth_pairs", 0) + 1
		if pic == card.frame_pixels or _same_colours(pic, card.frame_pixels, card.frame_palette):
			r.match += 1
			return
		r.differ += 1
		if r.saved < 6:
			r.saved += 1
			_save(card, pic, out.path_join("%s_demo%d_differ_%d.png" % [game, n, r.saved]))
	vm.time_limit = DosMachine.seconds_to_units(600.0)
	vm.on_limit = func() -> void:
		g.Quit("emulated time limit reached")
	g.CK_Main(PackedStringArray(["/PLAYDEMO", str(n)]))
	var end: Array = [vm.now, g.ck_keenObj.posX if g.ck_keenObj != null else -1, g.ck_keenObj.posY if g.ck_keenObj != null else -1,
		g.ck_gameState.keenScore, g.ck_gameState.currentLevel]
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return end


## A new game from the keyboard (past the intro, the menu, NEW GAME, BEGIN NORMAL GAME), Enter on the
## world map, the window let down, a key, back up; the pictures with the window over the play checked.
func _status(root: String, game: String, out: String, r: Dictionary, wide: int) -> void:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game])):
		return
	var images: GalImages = GalImages.new(d)
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	g.draw_capture = true
	g.wide_tiles = wide
	var cfg: String = OS.get_temp_dir().path_join("mr_rend01g_%d.cfg" % Time.get_ticks_usec())
	var settings: Settings = Settings.new(cfg)
	settings.set_value("creature_question", false, game)    # Keen 6: straight into the game
	g.set("options", OptionsModel.new(settings, game, "galaxy"))
	vm.add_key(6.0, 0x1C, 0.2)
	vm.add_key(8.0, 0x1C, 0.2)
	for k: Array in [[1.0, 0x1C], [2.5, 0x1C], [10.0, 0x1C], [13.0, 0x39]]:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	# B+A+T together (the item cheat), then a key to close its window
	for code: int in [0x30, 0x1E, 0x14]:
		vm.add_key_after("menu", 16.0, code, 0.5)
	vm.add_key_after("menu", 18.0, 0x39, 0.2)
	var card: EgaCard = vm.card
	vm.on_display = func() -> void:
		if card.video_mode != EgaCard.MODE_EGA or card.frame_mixed:
			return
		var list: Dictionary = shown(g, vm)
		if list.is_empty() or list.get("none", false) or list.get("touched", false) or str(list.get("user", "")) != "":
			return
		if list.get("overlay", Rect2i()).size != Vector2i.ZERO:
			if str(g.rf_drawFunc) != "CK_ScrollStatusWindow" and vm.marks.has("menu") and vm.now > int(vm.marks["menu"]) + DosMachine.seconds_to_units(15.9) \
					and not r.has("cheat_window"):
				r["cheat_window"] = list.overlay
			_window(g, images, list, card, r, out, game)
	vm.time_limit = DosMachine.seconds_to_units(34.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	DirAccess.remove_absolute(cfg)


## A picture with a window over the play: the list's with the overlay's rectangle copied from the card's
## is the card's.
func _window(g: Object, images: GalImages, list: Dictionary, card: EgaCard, r: Dictionary, out: String, game: String) -> void:
	var with: PackedByteArray = GalDrawLayout.compose(images, GalDrawLayout.ops(g, list), list.dyn)
	var rect: Rect2i = (list.overlay as Rect2i).intersection(Rect2i(0, 0, 320, 200))
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			with[y * 320 + x] = card.frame_pixels[y * 320 + x]
	r.windows = r.get("windows", 0) + 1
	if rect.size.x < 320 or rect.size.y < 200:
		r.windows_part = r.get("windows_part", 0) + 1
	if with == card.frame_pixels or _same_colours(with, card.frame_pixels, card.frame_palette):
		r.windows_ok = r.get("windows_ok", 0) + 1
	elif r.get("win_saved", 0) < 3:
		r.win_saved = r.get("win_saved", 0) + 1
		_save(card, with, out.path_join("%s_window_differ_%d.png" % [game, r.win_saved]))


## The list of the picture on display (taken at the last retrace): the newest whose start was written
## before it, if the card's start is that list's; {} when none is.
static func shown(g: Object, vm: DosMachine) -> Dictionary:
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return {}
	if vm.card.display_start != int(list.start):
		return {}
	return list


## Where REND-03's half-way picture has its view, in world pixels (the layout's own rule).
func _view_of(a: Dictionary, b: Dictionary, alpha: float) -> Vector2:
	var bv: Vector2 = Vector2(float(int(b.ux)), float(int(b.uy))) / 16.0
	var av: Vector2 = Vector2(float(int(a.ux)), float(int(a.uy))) / 16.0
	if absf(bv.x - av.x) <= GalDrawLayout.JUMP and absf(bv.y - av.y) <= GalDrawLayout.JUMP:
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
