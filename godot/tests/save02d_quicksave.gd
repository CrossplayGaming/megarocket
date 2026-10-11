# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SAVE-02 (Keen Dreams, v1.93 in the host, real time): F8 quicksaves (asked Y/N first), F9 quickloads;
## the Gameplay page's row reads Quicksave F8/F9. In The Melon Mines (by Level select): F9 with no
## quicksave says so; after a walk, F8 and Y write QUICKSAV.KDR in the player's folder; after a further
## walk F9 and Y put Keen back where he was saved (the level started again from the saved state, the
## original's pause first); with Quicksave asks off, F8 saves at once; with quicksave off, F8 does nothing.
##
## Options: --game_data=<folder>

var t: T = T.new()
var host: GameHost = null


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _pause(seconds: float) -> void:
	await _wait(func() -> bool: return false, seconds)


func _key(code: Key, down: bool) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.pressed = down
	host._input(k)


func _tap(code: Key) -> void:
	_key(code, true)
	await _pause(0.12)
	_key(code, false)
	await _pause(0.3)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_save02d_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": "kdreams", "title": "Keen Dreams", "version": "v1.93", "folder": root_dir.path_join("kdreams193")})
	var g: Object = host.engine
	var rows: Array = host.options.page("gameplay").map(func(r: Dictionary) -> String: return r.label)
	t.ok("the Gameplay page: Mode, then Quicksave F8/F9, Quicksave asks (%s)" % [rows], rows[0] == "Mode" and rows[1] == "Quicksave F8/F9" and rows[2] == "Quicksave asks")
	var quick_file: String = g.user_dir.path_join(g.QUICK_FILE)
	DirAccess.remove_absolute(quick_file)
	g.us_files.erase(g.QUICK_FILE)
	await _pause(2.0)
	await _tap(KEY_ENTER)    # the text start screen
	await _pause(5.0)
	await _tap(KEY_ENTER)    # the title: the control panel
	await _pause(2.0)
	await _tap(KEY_F5)       # New Game, Normal
	await _pause(0.6)
	await _tap(KEY_ENTER)
	t.ok("a game started", await _wait(func() -> bool: return bool(g.get("ingame")) and host.controls_live(), 20.0))
	await _pause(1.5)
	# The Melon Mines by Level select (Options, Cheat, the eleventh row, the second level)
	await _tap(KEY_ESCAPE)
	await _pause(1.0)
	await _tap(KEY_O)
	await _pause(0.5)
	await _tap(KEY_C)
	await _pause(0.6)
	for i: int in range(10):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _pause(0.4)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	t.ok("in The Melon Mines", await _wait(func() -> bool: return int(g.gamestate.mapon) == 2 and host.controls_live(), 20.0))
	await _pause(2.0)

	# F9 with no quicksave: a word
	await _tap(KEY_F9)
	await _pause(0.6)
	t.ok("F9 with no quicksave: nothing loaded, the game goes on", not FileAccess.file_exists(quick_file) and not bool(g.get("loadedgame")))
	await _tap(KEY_ENTER)    # the word's key
	await _pause(0.5)
	# a walk, then F8, Y
	_key(KEY_RIGHT, true)
	await _pause(1.0)
	_key(KEY_RIGHT, false)
	await _pause(0.3)
	var saved_x: int = int(g.player.x)
	await _tap(KEY_F8)
	await _pause(0.6)
	await _tap(KEY_Y)
	t.ok("F8 and Y: QUICKSAV.KDR written in the player's folder", await _wait(func() -> bool: return FileAccess.file_exists(quick_file), 5.0))
	await _tap(KEY_ENTER)    # Game Quicksaved
	await _pause(0.5)
	# a further walk, then F9, Y: Keen back where he was
	_key(KEY_RIGHT, true)
	await _pause(1.2)
	_key(KEY_RIGHT, false)
	await _pause(0.3)
	var moved_x: int = int(g.player.x)
	t.ok("Keen walked on since (%d -> %d)" % [saved_x, moved_x], moved_x != saved_x)
	await _tap(KEY_F9)
	await _pause(0.6)
	await _tap(KEY_Y)
	await _pause(2.5)
	await _tap(KEY_ENTER)    # the original's PAUSED after a load
	t.ok("F9 and Y: the level starts again from the quicksave, Keen where he was saved (%d)" % int(g.player.x),
		await _wait(func() -> bool: return int(g.player.x) == saved_x and host.controls_live() and int(g.gamestate.mapon) == 2, 10.0))
	await _pause(1.0)
	# Quicksave asks off: F8 saves at once
	host.options.step("quicksave_confirm", 1)
	var before: int = FileAccess.get_modified_time(quick_file)
	await _pause(1.1)
	await _tap(KEY_F8)
	t.ok("with Quicksave asks off, F8 saves at once", await _wait(func() -> bool: return FileAccess.get_modified_time(quick_file) > before, 5.0))
	await _tap(KEY_ENTER)
	await _pause(0.5)
	# quicksave off: F8 does nothing
	host.options.step("quicksave", 1)
	before = FileAccess.get_modified_time(quick_file)
	await _pause(1.1)
	await _tap(KEY_F8)
	await _pause(1.0)
	t.ok("with quicksave off, F8 does nothing", FileAccess.get_modified_time(quick_file) == before and host.controls_live())
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	DirAccess.remove_absolute(quick_file)
	t.finish(self)
