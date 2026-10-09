# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-01 (Keen 1-3's Options): with an OptionsModel attached (a player at the controls), the title
## menu has an Options row after High Scores, and the Options window works from the keyboard: down to
## Options, open it, Mode to Enhanced, into Display, Fullscreen on, back out twice. Checks: the
## settings the model wrote (Mode Enhanced, Fullscreen on, both for keen1 only), the game kept running
## to the end (no Quit), and the menu came back (the run reaches its limit on the title menu). Without
## a model (headless, the oracle runs) the menu is the original's: the same keys then start a game.
## Every picture is written to --out for review.
##
## Options: --game_data=<folder> --out=<folder> [--game=keen1]

var t: T = T.new()

const KEY_ENTER: int = 0x1C
const KEY_DOWN: int = 0x50
const KEY_RIGHT: int = 0x4D
const KEY_ESC: int = 0x01


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_menu01"))
	var game: String = opts.get("game", "keen1")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_menu01_%d.cfg" % Time.get_ticks_usec())
	var settings: Settings = Settings.new(cfg)
	var res: Dictionary = _run(root, game, out, OptionsModel.new(settings, game, "vorticons"))
	var after: Settings = Settings.new(cfg)
	t.ok("the run kept going to its end (quit '%s')" % res.quit, res.quit == "")
	t.ok("Mode went to Enhanced for %s (%s)" % [game, after.get_value("view", game)], after.get_value("view", game) == "enhanced")
	t.ok("Fullscreen went on for %s (%s)" % [game, after.get_value("fullscreen", game)], after.get_value("fullscreen", game) == true)
	t.ok("the global values are untouched", after.get_value("view") == "classic" and after.get_value("fullscreen") == false)
	t.ok("pictures were drawn (%d)" % res.pictures, res.pictures > 100)
	t.ok("back on the title menu at the end, not in a level (level %d)" % res.level, res.level == res.titlemap)
	# no model: the original menu (the downs land on Ordering Info's row instead, still the title)
	var plain: Dictionary = _run(root, game, out + "_plain", null)
	t.ok("without a model the run is the original's (no Options; quit '%s')" % plain.quit, plain.quit == "")
	DirAccess.remove_absolute(cfg)
	t.finish(self)


func _run(root: String, game: String, out: String, model: OptionsModel) -> Dictionary:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
		t.blocked("%s data: %s" % [game, data.error])
		return {"quit": "no data", "pictures": 0, "level": -1, "titlemap": 0}
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen1.new() if game == "keen1" else (VortKeen2.new() if game == "keen2" else VortKeen3.new())
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_menu01_save_%d" % Time.get_ticks_usec())
	g.options = model
	g.apply_dosbox_timing({})
	# from the first intro picture: a key to the title menu, down to Options (row 6), open it,
	# Mode right, down to Display, open it, Fullscreen right, back, back
	var script: Array = [[8.0, KEY_ENTER], [10.0, KEY_DOWN], [11.0, KEY_DOWN], [12.0, KEY_DOWN], [13.0, KEY_DOWN],
		[14.0, KEY_DOWN], [15.0, KEY_ENTER], [17.0, KEY_RIGHT], [18.0, KEY_DOWN], [19.0, KEY_ENTER],
		[21.0, KEY_RIGHT], [22.0, KEY_ESC], [23.5, KEY_ESC]]
	if model == null:
		script = script.slice(0, 1)    # the original: a key, then nothing (the title menu waits)
	for k: Array in script:
		vm.add_key_after("intro", k[0], k[1], 0.2)    # held a little longer than the menu's 6-refresh look
	DirAccess.make_dir_recursive_absolute(out)
	var writer: FrameWriter = FrameWriter.new()
	writer.open(out)
	var card: EgaCard = vm.card
	var pictures: Array = [0]
	vm.on_display = func() -> void:
		if card.video_mode == EgaCard.MODE_EGA:
			writer.add_indexed(card.frame_pixels, card.frame_palette, "P")
			pictures[0] += 1
	vm.time_limit = DosMachine.seconds_to_units(40.0)
	vm.on_limit = func() -> void:
		g.exited = true
	g.main()
	writer.close({"game": game})
	var r: Dictionary = {"quit": g.quit_message if g.get("quit_message") != null else "", "pictures": pictures[0],
		"level": g.level, "titlemap": g.TITLEMAP}
	g.options = null
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return r
