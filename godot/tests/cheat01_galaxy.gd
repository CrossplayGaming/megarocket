# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CHEAT-01/02 (Keen 4-6): the shell's cheats on the cards and their effects.
## With an OptionsModel attached (a player at the controls), from the keyboard: the menu from the title,
## CHEATS (after CONFIGURE): its rows are greyed with no game (GOD MODE chosen: nothing changes); back,
## NEW GAME, BEGIN NORMAL GAME; on the world map Escape, CHEATS, GOD MODE and INFINITE AMMO chosen (their
## dialogs answered), back to the game. Checks: MAIN's items (CHEATS after CONFIGURE, nine in all),
## the cheats off before the game and on after (the rows not greyed in it), and the run kept going.
## Without a model (the original cards): during the demo's level the cheats are set as the CHEATS card
## sets them; checks: every cheat off until then; FREEZE ENEMIES holds still, for as long as they are in
## play over 100 refreshes, objects that moved in the 50 before it (a control), while Keen goes on; NO CLIPPING clears Keen's clipping at once; a shot with INFINITE
## AMMO costs nothing and one without costs one.
## Every picture is written to --out for review.
##
## Options: --game_data=<folder> --out=<folder> [--game=keen4]

var t: T = T.new()

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
const KEY_ENTER: int = 0x1C
const KEY_DOWN: int = 0x50
const KEY_UP: int = 0x48
const KEY_ESC: int = 0x01
const KEY_SPACE: int = 0x39


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_cheat01"))
	var game: String = opts.get("game", "keen4")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_cheat01_%d.cfg" % Time.get_ticks_usec())
	var res: Dictionary = _walk(root, game, out, OptionsModel.new(Settings.new(cfg), game, "galaxy"))
	t.ok("the run kept going to its end (quit '%s')" % res.get("quit", ""), res.get("quit", "") == "time limit")
	t.ok("MAIN has CHEATS after CONFIGURE (%s)" % [res.get("main", [])],
		res.get("main", []).size() == 9 and res.main[3] == "CONFIGURE" and res.main[4] == "CHEATS")
	t.ok("on the title the cheat rows were greyed and choosing GOD MODE did nothing (%s)" % [res.get("title", {})],
		res.get("title", {}).get("disabled", false) and not res.get("title", {}).get("god", true))
	if game == "keen6":
		# its creature question stands before every new game until OPTIONS' CREATURE QUESTION row exists
		print("  keen6: the in-game walk is not run (the creature question)")
	else:
		t.ok("in the game GOD MODE and INFINITE AMMO went on (%s)" % [res.get("game", {})],
			res.get("game", {}).get("god", false) and res.get("game", {}).get("ammo", false) and res.get("game", {}).get("in_game", false))
	var fx: Dictionary = _effects(root, game, out + "_fx")
	print("  %s: %d objects, %d moved without freeze, %d with (Keen moved %s), clipped %s, shot cost %d on / %d off" % [game,
		fx.get("frozen", 0), fx.get("control_moved", 0), fx.get("moved", -1), fx.get("keen_moved", false), fx.get("clipped", "?"),
		fx.get("cost_on", -1), fx.get("cost_off", -1)])
	t.ok("every cheat off until set (%s)" % [fx.get("off_at_start", {})], fx.get("off_at_start", {}).values().all(func(v: bool) -> bool: return not v)
		and not fx.get("off_at_start", {}).is_empty())
	t.ok("FREEZE ENEMIES: of %d objects %d moved in 50 refreshes without it, %d in 100 with it; Keen moved %s" % [fx.get("frozen", 0), fx.get("control_moved", 0), fx.get("moved", -1), fx.get("keen_moved", false)],
		fx.get("frozen", 0) > 0 and fx.get("control_moved", 0) > 0 and fx.get("moved", -1) == 0 and fx.get("keen_moved", false))
	t.ok("NO CLIPPING cleared Keen's clipping at once (%s)" % fx.get("clipped", "?"), fx.get("clipped", -1) == 0)
	t.ok("a shot cost %d with INFINITE AMMO and %d without" % [fx.get("cost_on", -1), fx.get("cost_off", -1)],
		fx.get("cost_on", -1) == 0 and fx.get("cost_off", -1) == 1)
	DirAccess.remove_absolute(cfg)
	t.finish(self)


func _start(root: String, game: String) -> Array:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game])):
		t.blocked("%s data: %s" % [game, d.error])
		return []
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	return [vm, g]


func _frames(vm: DosMachine, out: String, extra: Callable) -> FrameWriter:
	DirAccess.make_dir_recursive_absolute(out)
	var writer: FrameWriter = FrameWriter.new()
	writer.open(out)
	var card: EgaCard = vm.card
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA:
			if card.frame_mixed:
				writer.add(card.frame_rgb(), "P")
			else:
				writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
		extra.call()
	return writer


func _finish(vm: DosMachine, g: GalGame) -> void:
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()


func _walk(root: String, game: String, out: String, model: OptionsModel) -> Dictionary:
	var s: Array = _start(root, game)
	if s.is_empty():
		return {}
	var vm: DosMachine = s[0]
	var g: GalGame = s[1]
	g.set("options", model)
	# past the intro, the menu; then from its first picture: down to CHEATS (the fifth item), into it,
	# GOD MODE chosen (greyed: the not-allowed sound), back, up to NEW GAME, into it, BEGIN NORMAL GAME;
	# on the world map Escape (the menu, RETURN TO GAME highlighted), up to CHEATS, into it, GOD MODE
	# chosen, its dialog, down, INFINITE AMMO chosen, its dialog, back, down to RETURN TO GAME, chosen
	vm.add_key(6.0, KEY_ENTER, 0.2)
	vm.add_key(8.0, KEY_ENTER, 0.2)
	var script: Array = [[1.0, KEY_DOWN], [2.0, KEY_DOWN], [3.0, KEY_DOWN], [4.0, KEY_DOWN], [5.0, KEY_ENTER],
		[6.5, KEY_ENTER], [8.0, KEY_ESC], [9.5, KEY_UP], [10.5, KEY_UP], [11.5, KEY_UP], [12.5, KEY_UP],
		[13.5, KEY_ENTER], [15.0, KEY_ENTER],
		[24.0, KEY_ESC], [26.0, KEY_UP], [27.0, KEY_ENTER], [28.5, KEY_ENTER], [30.0, KEY_SPACE],
		[31.5, KEY_DOWN], [32.5, KEY_ENTER], [34.0, KEY_SPACE], [35.5, KEY_ESC], [37.0, KEY_DOWN], [38.0, KEY_ENTER]]
	for k: Array in script:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	var r: Dictionary = {}
	var gal: Object = g
	var seen: Array = [false]
	var writer: FrameWriter = _frames(vm, out, func() -> void:
		# on the title, once the CHEATS card is up and GOD MODE was chosen: its rows' state
		var card: Object = gal.get("ck_us_cheatsMenu")
		if card != null and gal.get("us_currentCard") == card and not seen[0] and gal.game_in_progress == 0 \
				and vm.marks.has("menu") and vm.now > vm.marks["menu"] + DosMachine.seconds_to_units(7.5):
			seen[0] = true
			r["title"] = {"disabled": ((card.items[0] as Object).get("state") & 0x04) != 0, "god": gal.shell_cheat_get("god")}
		elif card != null and gal.get("us_currentCard") == card and gal.game_in_progress != 0:
			r["in_game"] = gal.shell_in_game() and ((card.items[0] as Object).get("state") & 0x04) == 0)
	vm.time_limit = DosMachine.seconds_to_units(52.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	writer.close({"game": game})
	r["quit"] = g.quit_message
	var main: Array = []
	for item: Object in g.get("ck_us_mainMenuItems"):
		if item.get("type") != g.US_ITEM_None:
			main.append(str(item.get("caption")))
	r["main"] = main
	r["game"] = {"god": g.shell_cheat_get("god"), "ammo": g.shell_cheat_get("infinite_ammo"), "in_game": r.get("in_game", false)}
	_finish(vm, g)
	return r


func _effects(root: String, game: String, out: String) -> Dictionary:
	var s: Array = _start(root, game)
	if s.is_empty():
		return {}
	var vm: DosMachine = s[0]
	var g: GalGame = s[1]
	var gal: Object = g
	var r: Dictionary = {}
	var state: Dictionary = {"count": 0, "still": {}, "keen": Vector2i(), "phase": 0, "at": 0}
	# past the intro, the menu, RETURN TO DEMO (the fifth item of the original MAIN)
	vm.add_key(6.0, KEY_ENTER, 0.2)
	vm.add_key(8.0, KEY_ENTER, 0.2)
	for k: Array in [[1.0, KEY_DOWN], [2.0, KEY_DOWN], [3.0, KEY_DOWN], [4.0, KEY_DOWN], [5.0, KEY_ENTER]]:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	var writer: FrameWriter = _frames(vm, out, func() -> void:
		# the demo's level: Keen's object in play
		if gal.ck_gameState.currentLevel == 0 or gal.ck_keenObj == null or gal.ck_keenObj.type != gal.CT_Player \
				or gal.IN_DemoGetMode() != gal.IN_Demo_Playback:
			return
		state.count += 1
		if state.count == 70:
			var off: Dictionary = {}
			for key: String in gal.shell_cheat_supported():
				if key in ["god", "infinite_ammo", "infinite_lives", "no_clip", "jump", "slow_motion", "freeze_enemies"]:
					off[key] = gal.shell_cheat_get(key)
			r["off_at_start"] = off
			var k: Object = gal.ck_keenObj
			gal.shell_cheat_set("no_clip", true)
			r["clipped"] = k.clipped
			gal.shell_cheat_set("no_clip", false)
		# from then on, once an enemy is in play: 50 refreshes watched without freezing, 100 with it
		if state.count >= 70 and state.phase == 0:
			_snapshot(gal, state)
			if not state.still.is_empty():
				state.phase = 1
				state.at = state.count
		elif state.phase == 1:
			_watch(state)
			if state.count == state.at + 50:
				r["control_moved"] = _moved(state)[1]
				if r["control_moved"] == 0:
					state.phase = 0    # nothing here moves on its own: try again with what comes next
					return
				gal.shell_cheat_set("freeze_enemies", true)
				_snapshot(gal, state)
				state.keen = Vector2i(gal.ck_keenObj.posX, gal.ck_keenObj.posY)
				state.phase = 2
		elif state.phase == 2:
			_watch(state)
			if state.count == state.at + 150:
				var m: Array = _moved(state)
				r["frozen"] = m[0]
				r["moved"] = m[1]
				r["keen_moved"] = Vector2i(gal.ck_keenObj.posX, gal.ck_keenObj.posY) != state.keen
				state.phase = 3
				gal.shell_cheat_set("freeze_enemies", false)
				# last (a shot may stun what the freeze check watches): one without, one with INFINITE AMMO
				var k: Object = gal.ck_keenObj
				gal.ck_gameState.numShots = 5
				gal.CK_SpawnShot(k.posX, k.posY, 2)
				r["cost_off"] = 5 - gal.ck_gameState.numShots
				gal.shell_cheat_set("infinite_ammo", true)
				var before: int = gal.ck_gameState.numShots
				gal.CK_SpawnShot(k.posX, k.posY, 2)
				r["cost_on"] = before - gal.ck_gameState.numShots
				gal.shell_cheat_set("infinite_ammo", false))
	vm.time_limit = DosMachine.seconds_to_units(45.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	writer.close({"game": game})
	_finish(vm, g)
	return r


## The objects freezing would hold, and where they are.
func _snapshot(gal: Object, state: Dictionary) -> void:
	state.still = {}
	state.seen = {}
	state.went = {}
	var o: Object = gal.ck_keenObj.next
	while o != null:
		if o.active != 0 and gal.CK_CheatFrozen(o):
			state.still[o] = [o.type, Vector2i(o.posX, o.posY)]
		o = o.next


## Every refresh: each snapshot object still in play (same type, active) is seen, and noted if it has
## left its place.
func _watch(state: Dictionary) -> void:
	for o: Object in state.still:
		if o.active == 0 or o.type != state.still[o][0]:
			continue
		state.seen[o] = state.seen.get(o, 0) + 1
		if Vector2i(o.posX, o.posY) != state.still[o][1]:
			state.went[o] = true


## [the snapshot's objects seen in play for at least 10 refreshes, how many of those moved].
func _moved(state: Dictionary) -> Array:
	var n: int = 0
	var moved: int = 0
	for o: Object in state.seen:
		if state.seen[o] < 10:
			continue
		n += 1
		if state.went.has(o):
			moved += 1
	return [n, moved]
