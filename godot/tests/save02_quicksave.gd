# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SAVE-02 (Keen 4-6, Enhanced): quicksave and quickload through the original's own save and load
## (omnispeak's QUICKSAVE_ENABLED, 1.0's keys). In level 1 (/TEDLEVEL) with a player's settings: F5, the
## confirmation answered Y, the pause message closed; Keen walks right; F9, Y. Checks: the quick slot (the
## sixth) holds a game named QuickSave; after the quickload Keen is back where he was when it was saved
## (not where he walked to). With QUICKSAVE ASKS off, the same without the questions. In Classic F5 is the
## original's: the save card opens, nothing quicksaved.
##
## Options: --game_data=<folder>

var t: T = T.new()

const META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
const F5: int = 0x3F
const F9: int = 0x43
const Y: int = 0x15
const SPACE: int = 0x39
const RIGHT: int = 0x4D


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for game: String in ["keen4", "keen5", "keen6"]:
		_game(root, game, "enhanced")
	_game(root, "keen4", "classic")
	_game(root, "keen5", "noask")
	t.finish(self)


func _game(root: String, game: String, mode: String) -> void:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(META[game])):
		t.blocked("%s data: %s" % [game, d.error])
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	var cfg: String = OS.get_temp_dir().path_join("mr_save02_%d.cfg" % Time.get_ticks_usec())
	var s: Settings = Settings.new(cfg)
	var m: OptionsModel = OptionsModel.new(s, game, "galaxy")
	if mode == "classic":
		m.step("mode", 1)    # Enhanced (the default) to Classic
	elif mode == "noask":
		m.step("quicksave_confirm", 1)    # QUICKSAVE ASKS off: F5 and F9 act at once (the Y presses land in play)
	g.set("options", m)
	var st: Dictionary = {"phase": 0}
	vm.on_display = func() -> void:
		if g.ck_keenObj == null or g.ck_keenObj.type != g.CT_Player or g.ck_gameState.currentLevel != 1:
			return
		var now: float = vm.seconds()
		match st.phase:
			0:
				# in play: F5, Y, Space; then walk right; F9, Y, Space
				st.phase = 1
				st.t0 = now
				vm.add_key(now + 0.5, F5, 0.15)
				vm.add_key(now + 1.5, Y, 0.15)
				vm.add_key(now + 2.5, SPACE, 0.15)
				vm.add_key(now + 3.5, RIGHT, 1.5)
				vm.add_key(now + 6.0, F9, 0.15)
				vm.add_key(now + 7.0, Y, 0.15)
				vm.add_key(now + 8.0, SPACE, 0.15)
			1:
				if not st.has("saved_x") and not (g.us_saveFiles[5] as PackedByteArray).is_empty():
					st.saved_x = g.ck_keenObj.posX
				if now > st.t0 + 5.5 and not st.has("walked_x"):
					st.walked_x = g.ck_keenObj.posX
				if now > st.t0 + 9.5 and not st.has("after_x"):
					st.after_x = g.ck_keenObj.posX
				if vm.marks.has("menu"):
					st.menu = true
	vm.time_limit = DosMachine.seconds_to_units(30.0)
	vm.on_limit = func() -> void:
		g.quitting = true
	g.CK_Main(PackedStringArray(["/TEDLEVEL", "1"]))
	var slot: Object = g.us_savefiles[5] if g.us_savefiles.size() > 5 else null
	if mode != "classic":
		game += " (asks)" if mode == "enhanced" else " (asks off)"
		t.ok("%s: F5 quicksaved into the sixth slot, named %s" % [game, slot.name if slot != null else "none"],
			not (g.us_saveFiles[5] as PackedByteArray).is_empty() and slot != null and slot.name == "QuickSave")
		t.ok("%s: Keen walked away (%s -> %s) and F9 brought him back (%s)" % [game, st.get("saved_x", "?"), st.get("walked_x", "?"), st.get("after_x", "?")],
			st.has("saved_x") and st.has("walked_x") and st.has("after_x") and st.walked_x != st.saved_x and st.after_x == st.saved_x)
	else:
		t.ok("%s, Classic: F5 is the original's (the save card opened: %s), nothing quicksaved" % [game, st.get("menu", false)],
			st.get("menu", false) and (g.us_saveFiles[5] as PackedByteArray).is_empty())
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	DirAccess.remove_absolute(cfg)
