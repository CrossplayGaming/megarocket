# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## FIX-01/02: the bug-fix toggles. The model: a game's fixes are on by default (Enhanced, J-03), the
## Classic mode turns them all off, a row changed alone makes Mode read Custom and changing it back
## Classic again, Enhanced turns them on. Then fixes, each with it off (the original) and on:
##   God mode lurch (Keen 1): the frame after G+O+D's window runs the tics the wait piled up (capped)
##     without the fix, and few with it;
##   Esc skips Earth scenes (Keen 2): with Escape held, the Earth-explodes scene plays to its end
##     without the fix and stops at once with it;
##   Keen over scenery (Keen 4): a platform interrupting a ledge climb leaves Keen on the climb's
##     layer (3) without the fix and puts him back on his own (1) with it;
##   Tantalus double fade (Keen 2): a level left by the Tantalus switch (a test class ends level 1 so,
##     faded out, entered from the world map by Level select's warp): pictures in colour between that
##     fade and the Earth scene without the fix, none with it;
##   Messie double Keen (Keen 3): on the world map, Messie beside a shore with Keen on her back and the
##     way to the shore held: Keen steps off, and her sprite still shows him without the fix, hers
##     alone with it.
## (Dreams' two: FIX-02's open part.)
##
## Options: --game_data=<folder>

var t: T = T.new()

const KEY_G: int = 0x22
const KEY_O: int = 0x18
const KEY_D: int = 0x20
const KEY_SPACE: int = 0x39
const KEY_ESC: int = 0x01


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	_model()
	var lurch_off: int = _god_lurch(root, {})
	var lurch_on: int = _god_lurch(root, {"god_lurch": true})
	print("  god mode lurch: the frame after the window ran %d tics without the fix, %d with it" % [lurch_off, lurch_on])
	t.ok("God mode lurch: the capped tics without the fix (%d), a normal frame's with it (%d)" % [lurch_off, lurch_on], lurch_off == 15 and lurch_on == 6)
	var esc_off: float = _earth(root, {})
	var esc_on: float = _earth(root, {"k2_esc_skips": true})
	print("  Esc skips Earth scenes: the scene ran %.1f s without the fix, %.1f s with it" % [esc_off, esc_on])
	t.ok("Esc skips Earth scenes: plays on without the fix (%.1f s), stops at once with it (%.1f s)" % [esc_off, esc_on], esc_off > esc_on + 1.0)
	var flash_off: int = _tantalus(root, {})
	var flash_on: int = _tantalus(root, {"k2_tantalus_fade": true})
	print("  Tantalus double fade: %d pictures in colour between the fades without the fix, %d with it" % [flash_off, flash_on])
	t.ok("Tantalus double fade: a flash without the fix (%d), none with it (%d)" % [flash_off, flash_on], flash_off > 0 and flash_on == 0)
	var messie: Dictionary = _messie(root)
	print("  Messie double Keen: %s" % [messie])
	t.ok("Messie double Keen: Keen got off; her sprite kept him without the fix, not with it (%s)" % [messie],
		messie.get("off", false) and messie.get("without", -1) == messie.get("riding", -2) and messie.get("with", -1) == messie.get("alone", -2)
		and messie.get("riding", -1) != messie.get("alone", -1))
	var z_off: int = _over_scenery(root, {})
	var z_on: int = _over_scenery(root, {"keen_over_scenery": true})
	t.ok("Keen over scenery: layer %d without the fix, %d with it" % [z_off, z_on], z_off == 3 and z_on == 1)
	t.finish(self)


func _model() -> void:
	var cfg: String = OS.get_temp_dir().path_join("mr_fix01_%d.cfg" % Time.get_ticks_usec())
	var m: OptionsModel = OptionsModel.new(Settings.new(cfg), "keen2", "vorticons")
	var all: Callable = func(v: bool) -> bool: return m.fixes().values().all(func(x: bool) -> bool: return x == v)
	t.ok("Keen 2's fixes: %s" % [m.fixes().keys()], m.fixes().keys() == ["k2_esc_skips", "k2_tantalus_fade", "god_lurch"])
	t.ok("by default Mode reads Enhanced and every fix is on (%s)" % m.mode_text(), m.mode_text() == "Enhanced" and all.call(true))
	m.step("mode", 1)
	t.ok("Classic turns every fix off (%s, %s)" % [m.mode_text(), m.fixes()], m.mode_text() == "Classic" and all.call(false))
	m.step("fix_god_lurch", 1)
	t.ok("one fix on makes Mode read Custom (%s)" % m.mode_text(), m.mode_text() == "Custom" and m.fixes().god_lurch)
	m.step("fix_god_lurch", 1)
	t.ok("and off again, Classic (%s)" % m.mode_text(), m.mode_text() == "Classic")
	m.step("mode", 1)
	t.ok("Enhanced turns them on again (%s)" % m.mode_text(), m.mode_text() == "Enhanced" and all.call(true))
	# (MENU-08: Fixes... on the Gameplay page, after quicksave's rows, before Back)
	var rows: Array = m.page("gameplay").map(func(r: Dictionary) -> String: return r.key)
	t.ok("the Gameplay page has Fixes... before Back (%s)" % [rows], rows.find("fixes") >= 0 and rows.find("fixes") + 1 == rows.find("exit"))
	t.ok("the Fixes page: the three, each with its line, and Back", m.page("fixes").size() == 4 and m.page("fixes")[0].has("desc"))
	DirAccess.remove_absolute(cfg)


func _vort(root: String, game: String) -> Array:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
		t.blocked("%s data: %s" % [game, data.error])
		return []
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen1.new() if game == "keen1" else VortKeen2.new()
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_fix01_save_%d" % Time.get_ticks_usec())
	vm.on_limit = func() -> void:
		g.exited = true
	return [vm, g, data]


func _done(vm: DosMachine, g: VortActs) -> void:
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null


## Keen 1's level 1: G+O+D at 2 s, a key a second later answers the window; the most tics a frame
## ran in the second after it (MINTICS 6 a frame in play; the cap MAXTICS 15 is the lurch).
func _god_lurch(root: String, fixes: Dictionary) -> int:
	var s: Array = _vort(root, "keen1")
	if s.is_empty():
		return -1
	var vm: DosMachine = s[0]
	var g: VortActs = s[1]
	g.fixes = fixes
	var r: Array = [-1]
	var unit: int = DosMachine.seconds_to_units(1.0)
	vm.on_display = func() -> void:
		if g.shell_in_level:
			vm.mark("play")    # the level's first picture: the keys count from it
		# the second after the window closes (the key at 3.5 s): the most tics a frame ran
		if vm.marks.has("play") and g.cheatmode:
			var at: float = float(vm.now - vm.marks["play"]) / unit
			if at > 3.6 and at < 4.6:
				r[0] = maxi(r[0], g.tics)
	g.after_startup = func() -> void:
		g.gamestate.lives = 9
		for k: int in [KEY_G, KEY_O, KEY_D]:
			vm.add_key_after("play", 2.0, k, 0.3)
		vm.add_key_after("play", 3.5, KEY_SPACE, 0.2)
		vm.time_limit = vm.now + DosMachine.seconds_to_units(6.0)
		g.LevelLoop(1)
		g.exited = true
	g.main()
	_done(vm, g)
	return r[0]


## Keen 2's Earth-explodes scene with Escape held from its start: how long it ran, in seconds.
func _earth(root: String, fixes: Dictionary) -> float:
	var s: Array = _vort(root, "keen2")
	if s.is_empty():
		return -1.0
	var vm: DosMachine = s[0]
	var g: VortActs = s[1]
	g.fixes = fixes
	var took: Array = [0.0]
	g.after_startup = func() -> void:
		vm.add_key_after("earth", 2.2, KEY_ESC, 0.3)    # during the shot's flight (2.0-2.8 s in, after a 120-retrace wait)
		vm.mark("earth")    # after the key is asked for: a mark schedules the keys timed from it
		vm.time_limit = vm.now + DosMachine.seconds_to_units(40.0)
		var t0: int = vm.now
		g.TheEarthExplodes()
		took[0] = float(vm.now - t0) / DosMachine.seconds_to_units(1.0)
		g.exited = true
	g.main()
	_done(vm, g)
	return took[0]


## Keen 4: Keen on the ledge climb's layer (3) meets a platform. Called on the real Keen in the
## demo's level (the map there for the push that follows): past the intro, the menu, RETURN TO DEMO.
func _over_scenery(root: String, fixes: Dictionary) -> int:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join("keen4"), "res://data/omnispeak/keen4"):
		t.blocked("keen4 data: %s" % d.error)
		return -1
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = GalKeen4.new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	g.set("fixes", fixes)
	vm.add_key(6.0, 0x1C, 0.2)
	vm.add_key(8.0, 0x1C, 0.2)
	for k: Array in [[1.0, 0x50], [2.0, 0x50], [3.0, 0x50], [4.0, 0x50], [5.0, 0x1C]]:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	var r: Array = [-1, 0]
	vm.on_display = func() -> void:
		if r[0] != -1 or g.ck_gameState.currentLevel == 0 or g.ck_keenObj == null or g.ck_keenObj.type != g.CT_Player:
			return
		r[1] += 1
		if r[1] < 70:
			return    # well into the level
		r[0] = -2    # once, even if the call fails
		var plat: GalCK.CK_object = GalCK.CK_object.new()
		plat.type = g.CT_CLASS("Platform")
		g.ck_keenObj.zLayer = 3
		g.CK_KeenSpecialColFunc(g.ck_keenObj, plat)
		r[0] = g.ck_keenObj.zLayer
		g.quitting = true
	vm.time_limit = DosMachine.seconds_to_units(30.0)
	vm.on_limit = func() -> void:
		g.quitting = true
	g.CK_Main(PackedStringArray())
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return r[0]


## Keen 2: level 1, entered from the world map by the warp, ends as the Tantalus switch ends a level
## (faded out); the Earth scene then stops the run. Pictures shown in colour in between.
class TantalusKeen2 extends VortKeen2:
	var phase: int = 0

	func LevelLoop(_currentlevel: int) -> int:
		phase = 1
		FadeOut()    # as a level's end leaves it
		phase = 2
		return ex_tantalus

	func TheEarthExplodes() -> void:
		phase = 3
		exited = true


func _tantalus(root: String, fixes: Dictionary) -> int:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join("keen2"), "CK2"):
		t.blocked("keen2 data: %s" % data.error)
		return -1
	var vm: DosMachine = DosMachine.new()
	var g: TantalusKeen2 = TantalusKeen2.new()
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_fix01_save_%d" % Time.get_ticks_usec())
	g.fixes = fixes
	var lit: Array = [0]
	vm.on_display = func() -> void:
		if g.phase != 2 or vm.card.video_mode != EgaCard.MODE_EGA:
			return
		var rgb: PackedByteArray = vm.card.frame_rgb()
		for i: int in range(0, rgb.size(), 97):
			if rgb[i] != 0:
				lit[0] += 1
				return
	vm.on_limit = func() -> void:
		g.exited = true
	g.after_startup = func() -> void:
		g.helptextPtr = g.PrepareText(data.help_text)
		g.storytxtPtr = g.PrepareText(data.story_text)
		g.endtextPtr = g.PrepareText(data.end_text)
		g.previewsPtr = g.PrepareText(data.previews_text)
		g.gamestate.lives = 9
		g.restoredGame = false
		g.shell_warp = 1
		vm.time_limit = vm.now + DosMachine.seconds_to_units(30.0)
		g.WorldMap()
		g.exited = true
	g.main()
	_done(vm, g)
	return lit[0]


## Keen 3's world map: a lake tile beside a shore; Messie there, moving east, Keen aboard, the way to
## the shore held; _update_messie once. Her sprite after it, with the fix off and on, against hers
## riding and alone.
func _messie(root: String) -> Dictionary:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join("keen3"), "CK3"):
		t.blocked("keen3 data: %s" % data.error)
		return {}
	var vm: DosMachine = DosMachine.new()
	var g: VortKeen3 = VortKeen3.new()
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_fix01_save_%d" % Time.get_ticks_usec())
	var r: Dictionary = {}
	vm.on_limit = func() -> void:
		g.exited = true
	g.after_startup = func() -> void:
		g.ReadLevel(g.WORLDMAP)
		var dx: Array = [0, 1, 1, 1, 0, -1, -1, -1]
		var dy: Array = [-1, -1, 0, 1, 1, 1, 0, -1]
		var spot: Array = []
		for y: int in range(1, g.mapheight - 1):
			for x: int in range(1, g.mapwwide - 1):
				if g.GETTILE(x, y, 1) != 0x2000:
					continue
				for d: int in range(8):
					if g.GETTILE(x + dx[d], y + dy[d], 1) == 0x2200:
						spot = [x, y, d]
						break
				if not spot.is_empty():
					break
			if not spot.is_empty():
				break
		if spot.is_empty():
			r["error"] = "no lake tile beside a shore"
			g.exited = true
			return
		var keen: Object = g.objlist[0]
		var place: Callable = func(state: int, fix: bool, held: bool) -> int:
			g.fixes = {"k3_messie_double": fix}
			g.messiex = spot[0] * g.TILEGLOBAL
			g.messiey = spot[1] * g.TILEGLOBAL
			g.messiexmove = g.MESSIESPEED * g.PIXGLOBAL
			g.messieymove = 0
			g.messiecount = 5
			g.messiestate = state
			g.keydown.fill(0)
			if held:
				g.keydown[g.key[spot[2]]] = 1
			g.call("_update_messie", keen)
			r["off"] = g.messiestate == 0
			return g.messieshape
		r["riding"] = place.call(1, false, false)
		r["alone"] = place.call(0, false, false)
		r["without"] = place.call(1, false, true)
		r["with"] = place.call(1, true, true)
		g.exited = true
	g.main()
	_done(vm, g)
	return r
