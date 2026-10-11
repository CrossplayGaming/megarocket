# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CTRL-04: Keen 4-6's CONTROLS card, walked from the title's menu with the keyboard (the host's part, the
## capture's hand-over, played by the test): CONFIGURE has CONTROLS where KEYBOARD and the joysticks were;
## CONTROLS > KEYBOARD lists each action and its keys; JUMP > CHANGE catches Q (Jump: Q, Ctrl); ADD SECOND
## greyed while an action has two; FIRE BUTTON moves to JUMP + POGO; OPTIONS has no TWO-BUTTON FIRING.
## Pictures at the steps go to --shots.
##
## Options: --game_data=<folder> [--game=keen4] [--shots=<folder>]

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
	var game: String = opts.get("game", "keen4")
	var shots: String = opts.get("shots", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_ctrl04_%d.cfg" % Time.get_ticks_usec())
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
	g.set("shell_controls", model.controls.table())
	vm.add_key(6.0, KEY_ENTER, 0.2)
	vm.add_key(8.0, KEY_ENTER, 0.2)
	# CONFIGURE (fourth); CONTROLS (sixth: SOUND, MUSIC, DISPLAY, OPTIONS, FIXES, CONTROLS); KEYBOARD;
	# down to JUMP (fifth); its card; CHANGE: the capture (Q handed over at once); the word; back to the
	# list; back to CONTROLS; down to FIRE BUTTON; chosen, its word
	var script: Array = [[1.0, KEY_DOWN], [2.0, KEY_DOWN], [3.0, KEY_DOWN], [4.0, KEY_ENTER],
		[5.5, KEY_DOWN], [6.0, KEY_DOWN], [6.5, KEY_DOWN], [7.0, KEY_DOWN], [7.5, KEY_DOWN], [8.5, KEY_ENTER],
		[10.0, KEY_ENTER],
		[11.5, KEY_DOWN], [12.0, KEY_DOWN], [12.5, KEY_DOWN], [13.0, KEY_DOWN], [14.0, KEY_ENTER],
		[15.5, KEY_ENTER], [18.0, KEY_SPACE],
		[19.5, KEY_ESC], [21.0, KEY_ESC], [22.5, KEY_DOWN], [23.0, KEY_DOWN], [24.0, KEY_ENTER], [25.5, KEY_SPACE]]
	for k: Array in script:
		vm.add_key_after("menu", k[0], k[1], 0.2)
	var card: EgaCard = vm.card
	var seen: Dictionary = {}
	var marks: Dictionary = {"ctrl04_controls": 9.6, "ctrl04_keyboard": 13.6, "ctrl04_capture": 16.2, "ctrl04_after": 19.2, "ctrl04_fire": 25.0}
	var menu_at: Array = [-1.0]
	vm.on_display = func() -> void:
		# the host's part: a capture waiting gets Q
		if str(g.get("controls_capture")) == "keys" and int(g.get("controls_captured")) == -2:
			if not seen.has("cap_at"):
				seen["cap_at"] = vm.seconds()
			elif vm.seconds() - float(seen["cap_at"]) > 0.6:
				g.set("controls_captured", KEY_Q)
		if menu_at[0] < 0.0 and vm.marks.has("menu"):
			menu_at[0] = vm.seconds()
		if shots != "" and menu_at[0] >= 0.0 and card.video_mode == EgaCard.MODE_EGA and card.frame_pixels.size() == 64000:
			for name: String in marks:
				if not seen.has(name) and vm.seconds() - menu_at[0] >= float(marks[name]):
					seen[name] = true
					_save(card, shots.path_join(name + ".png"))
	vm.time_limit = DosMachine.seconds_to_units(40.0)
	vm.on_limit = func() -> void:
		g.quitting = true
		g.quit_message = "time limit"
	g.CK_Main(PackedStringArray())
	var configure: Array = []
	for item: Object in g.get("ck_us_configureMenuItems"):
		if str(item.get("caption")) != "":
			configure.append(str(item.get("caption")))
	var options_rows: Array = []
	for item: Object in g.get("ck_us_optionsMenuItems"):
		if str(item.get("caption")) != "":
			options_rows.append(str(item.get("caption")))
	var controls: Array = []
	var keyboard: Array = []
	var jump_card: Array = []
	var cm: Object = g.get("ck_us_controlsMenu")
	if cm != null:
		for item: Object in cm.get("items"):
			if str(item.get("caption")) != "":
				controls.append(str(item.get("caption")))
		var kb: Object = (cm.get("items")[0] as Object).get("subMenu")
		for item: Object in kb.get("items"):
			if str(item.get("caption")) != "":
				keyboard.append(str(item.get("caption")))
		for item: Object in (kb.get("items")[4] as Object).get("subMenu").get("items"):
			if str(item.get("caption")) != "":
				jump_card.append([str(item.get("caption")), (int(item.get("state")) & GalMenu.US_IS_Disabled) != 0])
	t.ok("the run kept going (quit '%s')" % g.quit_message, g.quit_message == "time limit")
	# (the original's items: USE KEYBOARD, USE JOYSTICK #1 / #2 and USE GRAVIS GAMEPAD (ON)/(OFF), SCR-01)
	t.ok("CONFIGURE: CONTROLS where USE KEYBOARD, the joysticks and the gamepad were (%s)" % [configure],
		configure.has("CONTROLS") and not configure.any(func(c: String) -> bool:
			return c.contains("KEYBOARD") or c.begins_with("USE JOYSTICK") or c.contains("GAMEPAD")))
	t.ok("OPTIONS has no TWO-BUTTON FIRING (%s)" % [options_rows], not options_rows.any(func(c: String) -> bool: return c.begins_with("TWO-BUTTON")))
	t.eq("CONTROLS' items", controls, ["KEYBOARD", "CONTROLLER", "FIRE BUTTON (JUMP + POGO)", "RESET TO DEFAULTS"])
	t.ok("KEYBOARD lists each action and its keys (%s)" % [keyboard],
		keyboard.size() == 8 and keyboard[0] == "UP (UP)" and keyboard[4] == "JUMP (Q, CTRL)" and keyboard[6] == "FIRE (SPACE, SHIFT)")
	t.eq("Jump's card: CHANGE, ADD SECOND greyed (it has two), CLEAR", jump_card, [["CHANGE", false], ["ADD SECOND", true], ["CLEAR", false]])
	t.eq("Q caught for Jump", model.controls.keys("jump"), [KEY_Q, KEY_CTRL])
	t.ok("FIRE BUTTON moved to Jump + Pogo", bool(settings.get_value("two_button_fire", game)))
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
