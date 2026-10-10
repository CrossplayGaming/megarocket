# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-02 (Keen 4-6's cards): with an OptionsModel attached (a player at the controls), CONFIGURE has a
## DISPLAY card after MUSIC and OPTIONS starts with MODE; from the keyboard: the menu from the title,
## CONFIGURE, DISPLAY, FULLSCREEN chosen (its dialog answered), back, OPTIONS, MODE chosen. Checks: the
## settings the model wrote (Fullscreen on, Mode Classic with its fixes off, for this game only), the run kept going, and
## SVGA COMPATIBILITY gone (Keen 6: CREATURE QUESTION last); without a model the cards are the original's (no DISPLAY item, OPTIONS from
## SCORE BOX to SVGA COMPATIBILITY).
## Every picture is written to --out for review.
##
## Options: --game_data=<folder> --out=<folder> [--game=keen4]

var t: T = T.new()

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
const KEY_ENTER: int = 0x1C
const KEY_DOWN: int = 0x50
const KEY_ESC: int = 0x01
const KEY_SPACE: int = 0x39


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var out: String = opts.get("out", OS.get_temp_dir().path_join("mr_menu02"))
	var game: String = opts.get("game", "keen4")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_menu02_%d.cfg" % Time.get_ticks_usec())
	var settings: Settings = Settings.new(cfg)
	var res: Dictionary = _run(root, game, out, OptionsModel.new(settings, game, "galaxy"))
	var after: Settings = Settings.new(cfg)
	t.ok("the run kept going to its end (quit '%s')" % res.quit, res.quit == "time limit")
	t.ok("CONFIGURE has DISPLAY after MUSIC (%s)" % [res.configure],res.configure.slice(0, 4) == ["SOUND", "MUSIC", "DISPLAY", "OPTIONS"])
	t.ok("OPTIONS starts with MODE (%s)" % res.first_option, res.first_option.begins_with("MODE ("))
	t.ok("OPTIONS has no SVGA COMPATIBILITY (%s)" % [res.options], res.options.size() == (5 if game == "keen6" else 4)
		and res.options.all(func(c: String) -> bool: return not c.begins_with("SVGA")))
	if game == "keen6":
		t.ok("Keen 6's OPTIONS ends with CREATURE QUESTION (ON) (%s)" % res.options.back(), res.options.back() == "CREATURE QUESTION (ON)")
	t.ok("Fullscreen went on for %s (%s)" % [game, after.get_value("fullscreen", game)], after.get_value("fullscreen", game) == true)
	t.ok("Mode went from Enhanced (the default) to Classic for %s (%s)" % [game, after.get_value("view", game)], after.get_value("view", game) == "classic")
	t.ok("Classic turned this game's fixes off (%s)" % [OptionsModel.new(after, game, "").fixes()],
		OptionsModel.new(after, game, "").fixes().values().all(func(v: bool) -> bool: return not v))
	t.ok("the global values are untouched", after.get_value("view") == "enhanced" and after.get_value("fullscreen") == false)
	var plain: Dictionary = _run(root, game, out + "_plain", null)
	t.ok("without a model the cards are the original's (%s; %s)" % [plain.configure, plain.options],
		not plain.configure.has("DISPLAY") and plain.first_option.begins_with("SCORE BOX") and plain.options.size() == 4 and plain.options[3].begins_with("SVGA"))
	DirAccess.remove_absolute(cfg)
	t.finish(self)


func _run(root: String, game: String, out: String, model: OptionsModel) -> Dictionary:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game])):
		t.blocked("%s data: %s" % [game, d.error])
		return {"quit": "no data", "configure": [], "first_option": "", "options": []}
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load(CLASSES[game]).new()
	g.vm = vm
	g.data = d
	vm.set_cycles(20000)
	g.set("options", model)
	# a key past the intro, another on the title for the menu; then from its first picture: CONFIGURE
	# (the fourth item; SAVE GAME is a stop, though choosing it does nothing while a demo runs);
	# DISPLAY; FULLSCREEN, its dialog; back; OPTIONS; MODE, its dialog
	vm.add_key(6.0, KEY_ENTER, 0.2)
	vm.add_key(8.0, KEY_ENTER, 0.2)
	var script: Array = [[1.0, KEY_DOWN], [2.0, KEY_DOWN], [3.0, KEY_DOWN], [4.0, KEY_ENTER],
		[5.5, KEY_DOWN], [6.5, KEY_DOWN], [7.5, KEY_ENTER], [9.0, KEY_ENTER], [10.5, KEY_SPACE],
		[12.0, KEY_ESC], [13.5, KEY_DOWN], [14.5, KEY_ENTER], [16.0, KEY_ENTER], [17.5, KEY_SPACE]]
	if model == null:
		script = []
	for k: Array in script:
		vm.add_key_after("menu", k[0], k[1], 0.2)
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
	vm.time_limit = DosMachine.seconds_to_units(28.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	writer.close({"game": game})
	var configure: Array = []
	for item: Object in g.get("ck_us_configureMenuItems"):
		if str(item.get("caption")) != "":
			configure.append(str(item.get("caption")))
	var option_rows: Array = []
	for item: Object in g.get("ck_us_optionsMenuItems"):
		if str(item.get("caption")) != "":
			option_rows.append(str(item.get("caption")))
	var r: Dictionary = {"quit": g.quit_message, "configure": configure, "first_option": option_rows[0], "options": option_rows}
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return r
