# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-08 (J-49): Keen 4-6's main card in a game, with a player at the controls. The pad's B or Start (the
## host's Escape, its shell_pad_escape set) goes back to the game; the keyboard's Escape asks REALLY QUIT? as
## the original's. A new game from the title's menu; on the map Escape opens the panel, the pad's Escape goes
## back to the map and a Y after it does nothing; Escape again, the keyboard's Escape and Y quit the program.
##
## Options: --game_data=<folder> [--game=keen4]

var t: T = T.new()

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
const KEY_ENTER: int = 0x1C
const KEY_ESC: int = 0x01
const KEY_Y: int = 0x15
## after the title's menu opens: NEW GAME's card, its first item; then on the map the panel (pad), back
## (pad), Y; the panel again, the keyboard's Escape, Y
const PAD_UNTIL: float = 12.0


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var game: String = opts.get("game", "keen4")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_menu08gp_%d.cfg" % Time.get_ticks_usec())
	var settings: Settings = Settings.new(cfg)
	var model: OptionsModel = OptionsModel.new(settings, game, "galaxy")
	model.controls = ControlsModel.new(settings)
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game])):
		t.blocked("%s data: %s" % [game, d.error])
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	g.set("options", model)
	vm.add_key(6.0, KEY_ENTER, 0.2)
	vm.add_key(8.0, KEY_ENTER, 0.2)
	for k: Array in [[1.5, KEY_ENTER], [3.0, KEY_ENTER], [8.0, KEY_ESC], [10.0, KEY_ESC], [11.0, KEY_Y],
			[13.0, KEY_ESC], [15.0, KEY_ESC], [16.5, KEY_Y]]:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	var menu_at: Array = [-1.0]
	var state: Dictionary = {"quit_at": -1.0, "in_game_at_pad": false}
	vm.on_display = func() -> void:
		if menu_at[0] < 0.0 and vm.marks.has("menu"):
			menu_at[0] = vm.seconds()
		if menu_at[0] < 0.0:
			return
		var rel: float = vm.seconds() - menu_at[0]
		# the host's word: the Escapes before PAD_UNTIL come from the pad, the later ones from the keyboard
		g.set("shell_pad_escape", rel < PAD_UNTIL)
		if rel > 9.5 and rel < 10.0:
			state["in_game_at_pad"] = int(g.get("game_in_progress")) != 0
		if g.quitting and float(state["quit_at"]) < 0.0:
			state["quit_at"] = rel
	vm.time_limit = DosMachine.seconds_to_units(40.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	var quit_at: float = float(state["quit_at"])
	t.ok("a game in progress when the pad's Escape came", bool(state["in_game_at_pad"]))
	t.ok("the pad's Escape went back to the game: its Y quit nothing (quit at %.2f s)" % quit_at,
		quit_at < 0.0 or quit_at > 15.0)
	t.ok("the keyboard's Escape asked REALLY QUIT? and Y quit (at %.2f s, quit '%s')" % [quit_at, g.quit_message],
		quit_at > 16.5 and quit_at < 20.0 and g.quit_message == "")
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
