# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-01 (Keen 1-3): the draw list rendered at 1x equals the card's picture. Levels and the world
## map are played with the level test's scripted running, jumping, pogoing and firing; every picture
## shown from the last refresh's page (the card's start address and panning are the list's) is drawn
## again from that refresh's draw list (render/vort_draw_renderer.gd) and compared pixel for pixel
## (through the palette: during a fade different indices can show the same colour).
## Pictures the list can't account for (a window printed over the play, a user routine) are counted
## apart; the claim is that every gameplay picture matches. The first few mismatches are saved as
## PNGs (card left, render right) to --out.
##
## Options: --game_data=<folder> --games=keen1,keen2,keen3 --levels=1,2,3 --seconds=10 --out=<folder>

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
	for game: String in games:
		var r: Dictionary = _game(root, game, levels, seconds, out)
		print("  %s: %d pictures compared, %d match, %d differ; %d not from the list (windows, user routines)" % [
			game, r.get("compared", 0), r.get("match", 0), r.get("differ", 0), r.get("skipped", 0)])
		for k: String in r:
			if k.begins_with("user ") or k == "overlaid":
				print("    set aside: %s %d" % [k, r[k]])
		t.ok("%s: the draw list's 1x picture equals the card's (%d of %d)" % [game, r.get("match", 0), r.get("compared", 0)],
			r.get("compared", 0) > 300 and r.get("differ", 1) == 0)
	t.finish(self)


func _game(root: String, game: String, levels: Array, seconds: float, out: String) -> Dictionary:
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
		var pic: PackedByteArray = renderer.render(g, list)
		if pic.is_empty():
			r.skipped += 1
			var why: String = "user " + str(list.user) if str(list.user) != "" else "overlaid"
			r[why] = r.get(why, 0) + 1
			return
		r.compared += 1
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
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null
	return r


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
