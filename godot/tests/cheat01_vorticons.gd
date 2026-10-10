# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CHEAT-01/02 (Keen 1-3): the shell's cheats in the Options window and their effects.
## With an OptionsModel attached (a player at the controls), from the keyboard: the title menu's Options,
## Cheats...: its rows are greyed with no game (God mode chosen: only a word why); back out, New Game;
## on the world map F3, Cheats..., God mode chosen, Infinite ammo moved on, Level select..., Level 3. Checks: God mode
## off on the title, God mode and Infinite ammo on in the game (the rows usable there).
## Then level 1 played directly (the level test's way), the cheats set as the window sets them: God
## mode carried into the level's start; a shot costs one without Infinite ammo and nothing with it;
## Freeze enemies holds still, for as long as they are in play over two seconds, creatures that moved
## in the second before it; No clipping lets Keen sink through the floor he stands on; Skip this level
## ends the level as completed.
## Every picture is written to --out for review.
##
## Options: --game_data=<folder> --out=<folder> [--game=keen1]

var t: T = T.new()

const KEY_ENTER: int = 0x1C
const KEY_DOWN: int = 0x50
const KEY_UP: int = 0x48
const KEY_RIGHT: int = 0x4D
const KEY_ESC: int = 0x01
const KEY_SPACE: int = 0x39
const KEY_F3: int = 0x3D
const KEY_CTRL: int = 29
const KEY_ALT: int = 56


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_cheat01v"))
	var game: String = opts.get("game", "keen1")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_cheat01v_%d.cfg" % Time.get_ticks_usec())
	var w: Dictionary = _walk(root, game, out, OptionsModel.new(Settings.new(cfg), game, "vorticons"))
	t.ok("on the title God mode stayed off (%s)" % [w.get("title", {})], w.get("title", {}).get("seen", false) and not w.title.god)
	t.ok("Level select's Level 3 was entered from the world map (level %s)" % w.get("warped", "none"), w.get("warped", 0) == 3)
	t.ok("in the game God mode and Infinite ammo went on (%s)" % [w.get("game", {})],
		w.get("game", {}).get("god", false) and w.game.get("ammo", false) and w.game.get("playing", false))
	var fx: Dictionary = _effects(root, game, out + "_fx")
	print("  %s: god at the level's start %s; shot cost %d off / %d on; %d creatures, %d moved without freeze, %d with; sank %d px; level ended %s" % [
		game, fx.get("god_at_start", false), fx.get("cost_off", -1), fx.get("cost_on", -1), fx.get("frozen", 0),
		fx.get("control_moved", 0), fx.get("moved", -1), fx.get("sank", 0), fx.get("ended", -1)])
	t.ok("God mode carried into the level's start", fx.get("god_at_start", false))
	t.ok("every other cheat off until set (%s)" % [fx.get("off_at_start", {})], not fx.get("off_at_start", {}).is_empty()
		and fx.off_at_start.values().all(func(v: bool) -> bool: return not v))
	t.ok("a shot cost %d without Infinite ammo and %d with it" % [fx.get("cost_off", -1), fx.get("cost_on", -1)],
		fx.get("cost_off", -1) == 1 and fx.get("cost_on", -1) == 0)
	t.ok("Freeze enemies: of %d creatures %d moved in a second without it, %d in two with it" % [fx.get("frozen", 0), fx.get("control_moved", 0), fx.get("moved", -1)],
		fx.get("frozen", 0) > 0 and fx.get("control_moved", 0) > 0 and fx.get("moved", -1) == 0)
	t.ok("No clipping: Keen sank %d px through his floor" % fx.get("sank", 0), fx.get("sank", 0) > 16)
	t.ok("Skip this level: the level ended as completed (%s)" % fx.get("ended", -1), fx.get("ended", -1) == 1)
	t.ok("the original's C+T+Space still works (%s)" % [fx.get("ctspace", {})], fx.get("ctspace", {}).get("ammo", 0) == 100
		and fx.get("ctspace", {}).get("pogo", false) and fx.get("ctspace", {}).get("keys", []).all(func(k: bool) -> bool: return k))
	var g0: VortScreens = VortKeen1.new()
	var codes: Array = g0._options_code_rows().filter(func(r: Dictionary) -> bool: return r.key != "exit").map(func(r: Dictionary) -> String: return r.label)
	t.ok("the Cheats page's Original codes lists the originals' codes (%s)" % [codes], codes == ["G+O+D", "C+T+Space"])
	DirAccess.remove_absolute(cfg)
	t.finish(self)


func _start(root: String, game: String) -> Array:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
		t.blocked("%s data: %s" % [game, data.error])
		return []
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen1.new() if game == "keen1" else (VortKeen2.new() if game == "keen2" else VortKeen3.new())
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_cheat01v_save_%d" % Time.get_ticks_usec())
	g.apply_dosbox_timing({})
	return [vm, g, data]


func _frames(vm: DosMachine, out: String, extra: Callable) -> FrameWriter:
	DirAccess.make_dir_recursive_absolute(out)
	var writer: FrameWriter = FrameWriter.new()
	writer.open(out)
	var card: EgaCard = vm.card
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA:
			writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
		extra.call()
	return writer


func _walk(root: String, game: String, out: String, model: OptionsModel) -> Dictionary:
	var s: Array = _start(root, game)
	if s.is_empty():
		return {}
	var vm: DosMachine = s[0]
	var g: VortActs = s[1]
	g.options = model
	# from the first intro picture: a key to the title menu, down to Options (row 6), open it; down to
	# Cheats... (row 6, after Fixes...), open it, God mode chosen (greyed: a word why), a key, back, back (the title
	# menu's caret is on New Game again), New Game chosen; on the world map F3, down to Cheats..., open
	# it, God mode chosen, down, Infinite ammo moved on, back, back
	var script: Array = [[8.0, KEY_ENTER], [10.0, KEY_DOWN], [11.0, KEY_DOWN], [12.0, KEY_DOWN], [13.0, KEY_DOWN],
		[14.0, KEY_DOWN], [15.0, KEY_ENTER], [17.0, KEY_DOWN], [18.0, KEY_DOWN], [19.0, KEY_DOWN], [20.0, KEY_DOWN],
		[20.5, KEY_DOWN], [21.0, KEY_ENTER], [22.5, KEY_ENTER], [24.0, KEY_SPACE], [25.5, KEY_ESC], [27.5, KEY_ESC], [30.0, KEY_ENTER],
		[35.0, KEY_F3], [37.0, KEY_DOWN], [38.0, KEY_DOWN], [39.0, KEY_DOWN], [40.0, KEY_DOWN], [40.5, KEY_DOWN], [41.0, KEY_ENTER],
		[42.5, KEY_ENTER], [43.5, KEY_DOWN], [44.5, KEY_RIGHT],
		# then down to Level select... (the twelfth row), into it, down to Level 3, chosen: the window
		# closes and the world map enters level 3
		[46.0, KEY_DOWN], [47.0, KEY_DOWN], [48.0, KEY_DOWN], [49.0, KEY_DOWN], [50.0, KEY_DOWN], [51.0, KEY_DOWN],
		[52.0, KEY_DOWN], [53.0, KEY_DOWN], [54.0, KEY_DOWN], [54.5, KEY_DOWN], [55.0, KEY_ENTER], [56.5, KEY_DOWN], [57.5, KEY_DOWN],
		[58.5, KEY_ENTER]]
	for k: Array in script:
		vm.add_key_after("intro", k[0], k[1], 0.2)
	var r: Dictionary = {}
	var unit: int = DosMachine.seconds_to_units(1.0)
	var writer: FrameWriter = _frames(vm, out, func() -> void:
		if not vm.marks.has("intro"):
			return
		var at: float = float(vm.now - vm.marks["intro"]) / unit
		if at > 26.0 and not r.has("title"):
			r["title"] = {"seen": true, "god": g.cheat_god}
		if at > 45.5 and not r.has("game"):
			r["game"] = {"god": g.cheat_god, "ammo": g.cheat_infiniteAmmo, "playing": g.shell_in_game()}
		if at > 58.5 and g.shell_in_level and not r.has("warped"):
			r["warped"] = g.LevelNumber & 0xFF)
	vm.time_limit = DosMachine.seconds_to_units(68.0)
	vm.on_limit = func() -> void:
		g.exited = true
	g.main()
	writer.close({"game": game})
	g.options = null
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return r


func _effects(root: String, game: String, out: String) -> Dictionary:
	var s: Array = _start(root, game)
	if s.is_empty():
		return {}
	var vm: DosMachine = s[0]
	var g: VortActs = s[1]
	var data: VortData = s[2]
	var r: Dictionary = {}
	var unit: int = DosMachine.seconds_to_units(1.0)
	var st: Dictionary = {"phase": 0, "at": 0.0, "still": {}, "seen": {}, "went": {}, "y": 0}
	var writer: FrameWriter = _frames(vm, out, func() -> void:
		if not g.shell_in_level:
			return
		vm.mark("play")    # the level's first picture: the times below, and the fire keys, count from it
		var at: float = float(vm.now - vm.marks["play"]) / unit
		if not r.has("god_at_start"):
			r["god_at_start"] = g.cheatmode
			g.shell_cheat_set("god", false)
			var off: Dictionary = {}
			for key: String in ["infinite_ammo", "infinite_lives", "no_clip", "jump", "slow_motion", "freeze_enemies"]:
				off[key] = g.shell_cheat_get(key)
			r["off_at_start"] = off
			g.gamestate.ammo = 5
		# the shots (after Freeze's check, which they could spoil by stunning its creature): fired at
		# 7.0 s without Infinite ammo, at 8.5 s with it
		if at > 8.0 and not r.has("cost_off"):
			r["cost_off"] = 5 - g.gamestate.ammo
			g.shell_cheat_set("infinite_ammo", true)
			st["ammo"] = g.gamestate.ammo
		if at > 9.9 and not r.has("ctspace"):
			r["ctspace"] = {"ammo": g.gamestate.ammo, "pogo": g.gamestate.gotPogo, "keys": g.gamestate.keys.duplicate()}
		if at > 9.5 and not r.has("cost_on"):
			r["cost_on"] = st.ammo - g.gamestate.ammo
			g.shell_cheat_set("infinite_ammo", false)
		# from 1 s, once a creature is in play: a second watched without freezing, two with it
		if at <= 1.0:
			return
		if st.phase == 0:
			_snapshot(g, st)
			if not st.still.is_empty():
				st.phase = 1
				st.at = at
		elif st.phase == 1:
			_watch(g, st)
			if at > st.at + 1.0:
				r["control_moved"] = _moved(st)[1]
				if r.control_moved == 0:
					st.phase = 0
					return
				g.shell_cheat_set("freeze_enemies", true)
				_snapshot(g, st)
				st.phase = 2
				st.at = at
		elif st.phase == 2:
			_watch(g, st)
			if at > st.at + 2.0:
				var m: Array = _moved(st)
				r["frozen"] = m[0]
				r["moved"] = m[1]
				g.shell_cheat_set("freeze_enemies", false)
				st.phase = 3    # then, after the shots, No clipping: Keen, standing, sinks through his floor
		elif st.phase == 3:
			if at > 10.0 and st.y == 0:
				st.y = g.objlist[0].y
				g.shell_cheat_set("no_clip", true)
				st.at = at
			elif st.y != 0 and at > st.at + 0.5:
				r["sank"] = (g.objlist[0].y - st.y) / g.PIXGLOBAL
				g.shell_cheat_set("no_clip", false)
				r["skip_said"] = g.shell_cheat_fire("skip_level")
				st.phase = 4)
	vm.on_limit = func() -> void:
		g.exited = true
	g.after_startup = func() -> void:
		g.helptextPtr = g.PrepareText(data.help_text)
		g.storytxtPtr = g.PrepareText(data.story_text)
		g.endtextPtr = g.PrepareText(data.end_text)
		g.previewsPtr = g.PrepareText(data.previews_text)
		g.gamestate.lives = 9
		g.gamestate.gotPogo = true
		g.shell_playing = true
		g.shell_cheat_set("god", true)    # set before the level: its start carries it in
		for at: float in [7.0, 8.5]:
			vm.add_key_after("play", at, KEY_CTRL, 0.3)
			vm.add_key_after("play", at, KEY_ALT, 0.3)
		# the original's C+T+Space; its window waits for a key: Enter
		for k: int in [0x2E, 0x14, KEY_SPACE]:
			vm.add_key_after("play", 9.6, k, 0.2)
		vm.add_key_after("play", 9.95, KEY_ENTER, 0.1)
		vm.time_limit = vm.now + DosMachine.seconds_to_units(30.0)
		r["ended"] = g.LevelLoop(1)
		g.exited = true
	g.main()
	writer.close({"game": game})
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	return r


## The creatures freezing would hold, and where they are.
func _snapshot(g: VortActs, st: Dictionary) -> void:
	st.still = {}
	st.seen = {}
	st.went = {}
	for i: int in range(1, g.numobj):
		var o: Object = g.objlist[i]
		if o.obclass != g.nothing and o.active and g._cheat_frozen(o):
			st.still[i] = [o.obclass, Vector2i(o.x, o.y)]


## Each snapshot creature still in play (same class, active) is seen, and noted if it left its place.
func _watch(g: VortActs, st: Dictionary) -> void:
	for i: int in st.still:
		var o: Object = g.objlist[i]
		if not o.active or o.obclass != st.still[i][0]:
			continue
		st.seen[i] = st.seen.get(i, 0) + 1
		if Vector2i(o.x, o.y) != st.still[i][1]:
			st.went[i] = true


## [creatures seen in play at least 10 times, how many of them moved].
func _moved(st: Dictionary) -> Array:
	var n: int = 0
	var moved: int = 0
	for i: int in st.seen:
		if st.seen[i] < 10:
			continue
		n += 1
		if st.went.has(i):
			moved += 1
	return [n, moved]
