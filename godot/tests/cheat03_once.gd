# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CHEAT-03: the one-shot cheats, each applying once per use and saying what it did, in Keen 1 and Keen 4
## (straight into level 1: shell_play_level, /TEDLEVEL). Free items gives what the original's own code
## gives (Keen 1's C+T+Space: pogo, the four keys, 100 shots; Keen 4's B+A+T: the four gems, 99 shots, a
## life); Extra lives adds 9 a use up to 99 and says so when full; Skip this level ends the level as
## completed (the original's exit; F10+E in Keen 4-6) at once. Unlock the map waits on the user's call of
## what it opens in each game (MENUS.md).
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	_keen1(root)
	_keen4(root)
	t.finish(self)


func _lives(t2: T, game: String, fire: Callable, lives: Callable, set_lives: Callable) -> void:
	var before: int = lives.call()
	var said: String = fire.call("extra_lives")
	t2.ok("%s: Extra lives adds 9 (%d -> %d, '%s')" % [game, before, lives.call(), said], lives.call() == before + 9 and said == "%d lives" % (before + 9))
	set_lives.call(95)
	fire.call("extra_lives")
	var full: String = fire.call("extra_lives")
	t2.ok("%s: up to 99, then says so (%d, '%s')" % [game, lives.call(), full], lives.call() == 99 and full == "Lives are full")


func _keen1(root: String) -> void:
	var d: VortData = VortData.new()
	if not d.load_game(root.path_join("keen1"), "CK1"):
		t.blocked("keen1: " + d.error)
		return
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen1.new()
	g.vm = vm
	g.data = d
	g.save_dir = OS.get_temp_dir().path_join("mr_cheat03_%d" % Time.get_ticks_usec())
	var st: Dictionary = {}
	vm.on_display = func() -> void:
		if st.is_empty() and g.shell_in_level and g.level == 1:
			st.done = true
			var said: String = g.shell_cheat_fire("free_items")
			t.ok("keen1: Free items: pogo, the four keys, 100 shots ('%s')" % said,
				g.gamestate.gotPogo and g.gamestate.keys.all(func(k: bool) -> bool: return k) and g.gamestate.ammo == 100 and said != "")
			_lives(t, "keen1", g.shell_cheat_fire, func() -> int: return g.gamestate.lives, func(v: int) -> void: g.gamestate.lives = v)
			st.skip = g.shell_cheat_fire("skip_level")
			st.at = vm.seconds()
	g.after_startup = func() -> void: g.shell_play_level(1)
	vm.time_limit = DosMachine.seconds_to_units(30.0)
	vm.on_limit = func() -> void:
		g.exited = true
		g.exit_message = "time limit"
	g.main()
	t.ok("keen1: Skip this level ended level 1 as completed at once ('%s', %.1f s, level done %d)" % [st.get("skip", ""), vm.seconds() - float(st.get("at", 0.0)), g.LevelDone],
		st.get("skip", "") == "Level skipped" and g.LevelDone == g.ex_completed and g.exit_message != "time limit")
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null


func _keen4(root: String) -> void:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join("keen4"), "res://data/omnispeak/keen4"):
		t.blocked("keen4: " + d.error)
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load("res://games/galaxy/gal_keen4.gd").new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	var st: Dictionary = {}
	vm.on_display = func() -> void:
		if st.has("done") or g.ck_gameState.currentLevel != 1 or g.ck_keenObj == null or g.ck_keenObj.type != g.CT_Player:
			return
		# a second into play (the level's first pictures come before its play loop starts, which sets
		# the level going; the cheat card can't be opened before then either)
		if not st.has("seen"):
			st.seen = vm.seconds()
		if vm.seconds() >= float(st.seen) + 1.0:
			st.done = true
			var lives0: int = g.ck_gameState.numLives
			var said: String = g.shell_cheat_fire("free_items")
			t.ok("keen4: Free items: the four gems, 99 shots, a life ('%s')" % said,
				Array(g.ck_gameState.keyGems).all(func(k: int) -> bool: return k == 1) and g.ck_gameState.numShots == 99
				and g.ck_gameState.numLives == lives0 + 1 and said != "")
			_lives(t, "keen4", g.shell_cheat_fire, func() -> int: return g.ck_gameState.numLives, func(v: int) -> void: g.ck_gameState.numLives = v)
			st.skip = g.shell_cheat_fire("skip_level")
			st.at = vm.seconds()
	vm.time_limit = DosMachine.seconds_to_units(30.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray(["/TEDLEVEL", "1"]))
	t.ok("keen4: Skip this level ended level 1 as completed at once ('%s', %.1f s after, state %d)" % [st.get("skip", ""), vm.seconds() - float(st.get("at", 0.0)), g.ck_gameState.levelState],
		st.get("skip", "") == "Level skipped" and g.ck_gameState.levelState == g.LS_LevelComplete and g.quit_message != "time limit")
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
