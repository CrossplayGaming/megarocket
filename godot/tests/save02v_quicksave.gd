# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SAVE-02 (Keen 1-3, Enhanced): quicksave F7 and quickload F9 (1.0's keys; F5 stays the original's save
## menu), each answered Y (Keen 2: with jump, a pad's A). A new game's state, level 1: F7, Y; Keen walks right; F9, Y: he is back where he
## was saved, in the same level (each message closed with a key, as Keen 4-6's are). Then the level is left (Skip, as completed) and on the world map F9, Y:
## the map steers into level 1 and it opens as it was saved (Keen's place, the level not marked done).
## The quicksave is on disk (QUICK.CKn), and a fresh session reads it. In Classic, F7 and F9 do nothing.
##
## Options: --game_data=<folder>

var t: T = T.new()

const F7: int = 0x41
const F9: int = 0x43
const Y: int = 0x15
const RIGHT: int = 0x4D


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for game: String in ["keen1", "keen2", "keen3"]:
		_game(root, game, "enhanced")
	_game(root, "keen1", "classic")
	t.finish(self)


func _game(root: String, game: String, mode: String) -> void:
	var d: VortData = VortData.new()
	if not d.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
		t.blocked("%s: %s" % [game, d.error])
		return
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = vm
	g.data = d
	g.save_dir = OS.get_temp_dir().path_join("mr_save02v_%s_%d" % [game, Time.get_ticks_usec()])
	var cfg: String = OS.get_temp_dir().path_join("mr_save02v_%d.cfg" % Time.get_ticks_usec())
	var m: OptionsModel = OptionsModel.new(Settings.new(cfg), game, "vorticons")
	if mode == "classic":
		m.step("mode", 1)
	g.set("options", m)
	var st: Dictionary = {"phase": 0}
	var yes: int = 0x1D if game == "keen2" else Y    # Keen 2 answers with jump (a pad's A), the others with Y
	vm.on_display = func() -> void:
		var now: float = vm.seconds()
		var keen_x: int = g.objlist[0].x >> 12
		match st.phase:
			0:
				if g.shell_in_level and g.level == 1:
					st.phase = 1
					st.t0 = now
					vm.add_key(now + 0.5, F7, 0.15)
					vm.add_key(now + 1.3, yes, 0.15)
					vm.add_key(now + 1.9, 0x39, 0.15)    # the "Game quicksaved" message closed
					vm.add_key(now + 2.4, RIGHT, 1.5)
					vm.add_key(now + 4.5, F9, 0.15)
					vm.add_key(now + 5.3, yes, 0.15)
			1:
				if not st.has("saved_x") and not g._quick.is_empty():
					st.saved_x = int(g._quick.state.objlist[0].x) >> 12
				if now > st.t0 + 4.2 and not st.has("walked_x"):
					st.walked_x = keen_x
				if now > st.t0 + 6.5:
					st.back_x = keen_x
					st.phase = 2
					g.shell_cheat_fire("skip_level")    # out of the level, as completed: to the map
			2:
				if g.shell_on_map and not st.has("map_t"):
					st.map_t = now
					vm.add_key(now + 3.0, F9, 0.15)    # once the map's fade-in is over and its loop reads keys
					vm.add_key(now + 3.8, yes, 0.15)
				if st.has("map_t") and g.shell_in_level and g.level == 1 and not st.has("again_x"):
					st.again_x = keen_x
					st.done_flag = g.gamestate.leveldone[0]
	g.after_startup = func() -> void:
		g.helptextPtr = g.PrepareText(d.help_text)
		g.storytxtPtr = g.PrepareText(d.story_text)
		g.endtextPtr = g.PrepareText(d.end_text)
		g.previewsPtr = g.PrepareText(d.previews_text)
		g._new_game_state()
		g.shell_playing = true
		var code: int = g.LevelLoop(1)
		g.shell_in_level = false
		if code == g.ex_completed:
			g.gamestate.leveldone[0] = true
		g.WorldMap()
	vm.time_limit = DosMachine.seconds_to_units(28.0)
	vm.on_limit = func() -> void:
		g.exited = true
	g.main()
	if mode == "enhanced":
		t.ok("%s: F7 quicksaved in level 1 (Keen at %s), and it is on disk" % [game, st.get("saved_x", "?")],
			st.has("saved_x") and FileAccess.file_exists(g.save_dir.path_join("QUICK.CK" + game.substr(4, 1))))
		t.ok("%s: he walked away (%s) and F9 brought him back in the level (%s)" % [game, st.get("walked_x", "?"), st.get("back_x", "?")],
			st.has("walked_x") and st.walked_x != st.saved_x and st.get("back_x", -1) == st.saved_x)
		t.ok("%s: after leaving the level, F9 on the map went back into level 1 as saved (Keen at %s, done %s)" % [game, st.get("again_x", "?"), st.get("done_flag", "?")],
			st.get("again_x", -1) == st.saved_x and st.get("done_flag", true) == false)
		var fresh: VortActs = VortKeen1.new()
		fresh.data = d
		fresh.save_dir = g.save_dir
		fresh._quick_read()
		t.ok("%s: a new session reads the quicksave (level %s)" % [game, fresh._quick.get("level", "none")], fresh._quick.get("level", -1) == 1)
	else:
		t.ok("%s, Classic: F7 and F9 do nothing (no quicksave)" % game, g._quick.is_empty() and not st.has("saved_x"))
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null
	if DirAccess.dir_exists_absolute(g.save_dir):
		for f: String in DirAccess.get_files_at(g.save_dir):
			DirAccess.remove_absolute(g.save_dir.path_join(f))
		DirAccess.remove_absolute(g.save_dir)
	DirAccess.remove_absolute(cfg)
