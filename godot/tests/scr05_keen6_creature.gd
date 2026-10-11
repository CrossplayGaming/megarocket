# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SCR-05 (J-04, 2026-10-06: Keen 6's creature question answered for the player by default; a toggle
## shows it, and then any answer passes): Keen 6 in the host, real time, by the controller alone with
## real controller events. With the default settings NEW GAME, BEGIN NORMAL GAME goes straight onto the
## world map, no question asked. Then CREATURE QUESTION turned on (as Classic does): Start opens the menu, B
## and then Start on the main card go back to the game (J-49); NEW GAME from the menu in the game, YOU'RE IN A
## GAME answered with A: the map again, no question (J-43, as the original); QUIT's END GAME, its
## REALLY END CURRENT GAME? answered yes with A; from the title NEW GAME again, the creature question shown
## and a wrong answer typed with the d-pad (Z), A: the game starts all the same. The model: off by
## default, Classic on, Enhanced off.
##
## Options: --game_data=<folder>

var t: T = T.new()
var host: GameHost = null
var g: GalGame = null


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


func _button(b: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		e.device = 0
		Input.parse_input_event(e)
		await _pause(0.1 if down else 0.15)


func _select(caption: String) -> bool:
	var card: Object = g.us_currentCard
	var at: int = -1
	for i: int in range((card.items as Array).size()):
		if str((card.items[i] as Object).get("caption")) == caption:
			at = i
	if at < 0:
		return false
	for n: int in range(12):
		if card.selectedItem == at:
			return true
		await _button(JOY_BUTTON_DPAD_DOWN if card.selectedItem < at else JOY_BUTTON_DPAD_UP)
	return card.selectedItem == at


## NEW GAME, BEGIN NORMAL GAME by A from the main card.
func _new_game() -> void:
	await _select("NEW GAME")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _select("BEGIN NORMAL GAME")
	await _button(JOY_BUTTON_A)


func _on_map() -> bool:
	return g.game_in_progress != 0 and g.ck_gameState.currentLevel == 0 and host.controls_live()


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var tag: String = "mr_scr05k6_%d" % Time.get_ticks_usec()
	var cfg: String = OS.get_temp_dir().path_join(tag + ".cfg")
	var saves: String = OS.get_temp_dir().path_join(tag)
	# the model: off by default (answered for the player), Classic asks, Enhanced does not
	var model: OptionsModel = OptionsModel.new(Settings.new(OS.get_temp_dir().path_join(tag + "_m.cfg")), "keen6", "galaxy")
	var by_default: bool = bool(model.get_value("creature_question"))
	model.step("mode", 1)
	var classic: bool = bool(model.get_value("creature_question"))
	model.step("mode", 1)
	t.ok("CREATURE QUESTION: off by default (%s), on in Classic (%s), off in Enhanced (%s)" % [by_default, classic, model.get_value("creature_question")],
		not by_default and classic and not bool(model.get_value("creature_question")) and model.mode_text() == "Enhanced")
	DirAccess.remove_absolute(OS.get_temp_dir().path_join(tag + "_m.cfg"))

	host = GameHost.new()
	host.settings_path = cfg
	host.saves_dir = saves
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "keen6", "title": "Commander Keen 6", "version": "v1.4", "folder": root_dir.path_join("keen6")})
	t.ok("Keen 6 starts (%s)" % host.error, ok)
	if not ok:
		t.finish(self)
		return
	g = host.engine
	for i: int in range(12):
		if host.vm.marks.has("menu"):
			break
		await _button(JOY_BUTTON_START)
		await _pause(1.5)
	t.ok("Start opens the menu", host.vm.marks.has("menu"))
	await _pause(1.0)
	var asked: Array = [false]
	var map_unasked: Callable = func() -> bool:
		asked[0] = asked[0] or g.shell_text_entry
		return _on_map()
	await _new_game()
	t.ok("the default settings: straight onto the world map", await _wait(map_unasked, 30.0))
	t.ok("no creature question asked", not asked[0] and not g.ck6_creatureQuestionDone)
	await _pause(2.0)

	# the question shown (the row on): any answer passes
	host.options.step("creature_question", 1)
	t.ok("CREATURE QUESTION on", bool(host.options.get_value("creature_question")))
	await _button(JOY_BUTTON_START)
	var in_menu: Callable = func() -> bool: return not g.command_confirmed and not host.controls_live()
	var in_play: Callable = func() -> bool: return g.game_in_progress != 0 and host.controls_live()
	t.ok("Start in play opens the menu", await _wait(in_menu, 10.0))
	await _pause(1.0)
	# J-49: in a game the pad's B or Start on the main card goes back to the game (the keyboard's Escape
	# asks REALLY QUIT? as the original's: menu08_galaxy_pad)
	await _button(JOY_BUTTON_B)
	t.ok("B on the main card in a game: back to the game (J-49)", await _wait(in_play, 10.0))
	await _pause(1.0)
	await _button(JOY_BUTTON_START)
	t.ok("Start opens the menu again", await _wait(in_menu, 10.0))
	await _pause(1.0)
	await _button(JOY_BUTTON_START)
	t.ok("Start on the main card in a game: back to the game (J-49)", await _wait(in_play, 10.0))
	await _pause(1.0)
	# J-43: a new game chosen in a game goes on in the game's loop, which asked at its start: no question
	# (the original asks only for a game begun from the title)
	await _button(JOY_BUTTON_START)
	t.ok("Start opens the menu a third time", await _wait(in_menu, 10.0))
	await _pause(1.0)
	await _new_game()
	t.ok("YOU'RE IN A GAME asks", await _wait(func() -> bool: return g.shell_menu_keys, 5.0))
	await _pause(0.5)
	await _button(JOY_BUTTON_A)
	var asked_in_game: Array = [false]
	await _wait(func() -> bool:
		asked_in_game[0] = asked_in_game[0] or g.shell_text_entry
		return false, 6.0)
	t.ok("a new game from the menu in a game: no creature question (J-43)",
		not asked_in_game[0] and not g.ck6_creatureQuestionDone and await _wait(_on_map, 20.0))
	await _pause(1.0)
	await _button(JOY_BUTTON_START)
	t.ok("Start opens the menu once more", await _wait(in_menu, 10.0))
	await _pause(1.0)
	# (so the game is ended first, and the next one begun from the title)
	await _select("QUIT")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _select("END GAME")
	await _button(JOY_BUTTON_A)
	t.ok("REALLY END CURRENT GAME? asks (the pad the menus' keys while it waits)", await _wait(func() -> bool: return g.shell_menu_keys, 5.0))
	await _pause(0.5)
	await _button(JOY_BUTTON_A)
	t.ok("A answers yes: the game ended", await _wait(func() -> bool: return g.game_in_progress == 0, 20.0))
	await _pause(2.0)
	var opened: bool = false
	for i: int in range(6):
		await _button(JOY_BUTTON_START)
		if await _wait(func() -> bool: return not g.command_confirmed and not host.controls_live(), 3.0):
			opened = true
			break
	t.ok("Start opens the menu from the title", opened)
	await _pause(1.0)
	await _new_game()
	t.ok("the creature question, its line typed with the d-pad", await _wait(func() -> bool: return g.shell_text_entry, 20.0))
	await _pause(0.5)
	await _button(JOY_BUTTON_DPAD_DOWN)    # Z: no creature's name
	await _pause(0.3)
	await _button(JOY_BUTTON_A)
	t.ok("a wrong answer passes: the game starts on the world map", await _wait(_on_map, 30.0))
	t.ok("the question counts as answered", g.ck6_creatureQuestionDone)
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 15.0)
	host.queue_free()
	await _pause(0.2)
	if DirAccess.dir_exists_absolute(saves.path_join("keen6")):
		for name: String in DirAccess.get_files_at(saves.path_join("keen6")):
			DirAccess.remove_absolute(saves.path_join("keen6").path_join(name))
		DirAccess.remove_absolute(saves.path_join("keen6"))
	DirAccess.remove_absolute(saves)
	DirAccess.remove_absolute(cfg)
	t.finish(self)
