# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-08: Keen 4-6's MAIN card in the modern order (with a player at the controls): RETURN TO DEMO (RESUME
## in a game), NEW GAME, LOAD GAME, SAVE GAME, OPTIONS, CHEATS, HIGH SCORES, EXTRAS (PADDLE WAR), QUIT (END
## GAME, QUIT); the title's menu opens on NEW GAME; HIGH SCORES there closes the menu and the high scores
## are shown next. Pictures to --shots.
##
## Options: --game_data=<folder> [--game=keen4] [--shots=<folder>]

var t: T = T.new()

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const CLASSES: Dictionary = {"keen4": "res://games/galaxy/gal_keen4.gd",
	"keen5": "res://games/galaxy/gal_keen5.gd", "keen6": "res://games/galaxy/gal_keen6.gd"}
const KEY_ENTER: int = 0x1C
const KEY_DOWN: int = 0x50


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var game: String = opts.get("game", "keen4")
	var shots: String = opts.get("shots", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_menu08g_%d.cfg" % Time.get_ticks_usec())
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
	# from NEW GAME down five to HIGH SCORES (LOAD, SAVE, OPTIONS, CHEATS, HIGH SCORES), chosen
	for k: Array in [[1.5, KEY_DOWN], [2.0, KEY_DOWN], [2.5, KEY_DOWN], [3.0, KEY_DOWN], [3.5, KEY_DOWN], [4.5, KEY_ENTER]]:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	var card: EgaCard = vm.card
	var seen: Dictionary = {}
	var menu_at: Array = [-1.0]
	var selected_first: Array = [-1]
	vm.on_display = func() -> void:
		if menu_at[0] < 0.0 and vm.marks.has("menu"):
			menu_at[0] = vm.seconds()
			var mm: Object = g.get("ck_us_mainMenu")
			selected_first[0] = int(mm.get("selectedItem"))
		if bool(g.get("ck_inHighScores")) and menu_at[0] >= 0.0:
			seen["scores"] = true
		if shots != "" and menu_at[0] >= 0.0 and card.video_mode == EgaCard.MODE_EGA and card.frame_pixels.size() == 64000:
			for name: String in {"m08g_main": 1.0, "m08g_scores": 8.0}:
				var at: float = {"m08g_main": 1.0, "m08g_scores": 8.0}[name]
				if not seen.has(name) and vm.seconds() - menu_at[0] >= at:
					seen[name] = true
					_save(card, shots.path_join(name + ".png"))
	vm.time_limit = DosMachine.seconds_to_units(30.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	var main: Array = []
	for item: Object in g.get("ck_us_mainMenuItems"):
		if str(item.get("caption")) != "":
			main.append(str(item.get("caption")))
	var sub: Callable = func(caption: String) -> Array:
		for item: Object in g.get("ck_us_mainMenuItems"):
			if str(item.get("caption")) == caption:
				return (item.get("subMenu").get("items") as Array).map(func(i: Object) -> String: return str(i.get("caption"))).filter(func(c: String) -> bool: return c != "")
		return []
	t.ok("the run kept going (quit '%s')" % g.quit_message, g.quit_message == "time limit")
	t.eq("MAIN in the modern order", main, ["RETURN TO DEMO", "NEW GAME", "LOAD GAME", "SAVE GAME", "OPTIONS", "CHEATS", "HIGH SCORES", "EXTRAS", "QUIT"])
	t.eq("EXTRAS", sub.call("EXTRAS"), ["PADDLE WAR"])
	t.eq("QUIT", sub.call("QUIT"), ["END GAME", "QUIT"])
	t.eq("the title's menu opens on NEW GAME", selected_first[0], 1)
	t.ok("HIGH SCORES on the title: the menu closed and the high scores shown", seen.has("scores"))
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	DirAccess.remove_absolute(cfg)
	t.finish(self)


func _save(card: EgaCard, path: String) -> void:
	var pal: PackedByteArray = card.frame_palette
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(320 * 200 * 3)
	for i: int in range(320 * 200):
		var c: int = card.frame_pixels[i] * 3
		rgb[i * 3] = pal[c]
		rgb[i * 3 + 1] = pal[c + 1]
		rgb[i * 3 + 2] = pal[c + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(path)
