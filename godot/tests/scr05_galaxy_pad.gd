# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SCR-05 / SCR-03 / MENU-02: Keen 4 (or 5) by the controller alone, in the host, real time, with real
## controller events (Input.parse_input_event). From the title the menu by Start; EXTRAS' HELP opens the
## original's help screens, the d-pad moves its menu, A opens a topic, B leaves the topic and the help.
## NEW GAME and BEGIN NORMAL GAME by A; on the world map Start, SAVE GAME, the first slot, KEEN typed with
## the d-pad (Up steps the letter under the cursor, Right moves on) and A: the saved game's file holds the
## name KEEN. RESUME. A game over made on the map (no lives left and a top score, set while the host is
## paused) asks for a high score's name: KEEN by the d-pad. With Jump's controller buttons cleared, QUIT's
## REALLY QUIT? is answered by the pad: the A held to open it (its Enter repeating) is no answer, B backs
## out, A quits; CONFIG.CK4, written as the game quits, holds the high score's name KEEN.
##
## Options: --game_data=<folder> [--game=keen4|keen5]

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


## A controller button's press or release, as the device sends it.
func _send(b: JoyButton, down: bool) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.device = 0
	Input.parse_input_event(e)


## A controller button pressed and let go.
func _button(b: JoyButton) -> void:
	_send(b, true)
	await _pause(0.1)
	_send(b, false)
	await _pause(0.15)


## A word typed with the d-pad: each letter stepped to with Up from none, Right to the next.
func _type(word: String) -> void:
	for k: int in range(word.length()):
		for i: int in range(PadTextEntry.LETTERS.find(word[k]) + 1):
			await _button(JOY_BUTTON_DPAD_UP)
		if k < word.length() - 1:
			await _button(JOY_BUTTON_DPAD_RIGHT)


## The caption of the card's selected item.
func _selected() -> String:
	var card: Object = g.us_currentCard
	if card == null:
		return ""
	return str((card.items[card.selectedItem] as Object).get("caption"))


## The card's item with this caption selected with the d-pad. False if it is not on the card.
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


## Start pressed until the menu has opened (the first time from the intro and title: its mark).
func _menu_from_title() -> bool:
	for i: int in range(12):
		if host.vm.marks.has("menu"):
			return true
		await _button(JOY_BUTTON_START)
		await _pause(1.5)
	return host.vm.marks.has("menu")


## Start in play: the menu open (its loop waiting for a command, the controls no longer read).
func _menu_in_play() -> bool:
	await _button(JOY_BUTTON_START)
	var open: bool = await _wait(func() -> bool: return not g.command_confirmed and not host.controls_live(), 10.0)
	await _pause(1.0)
	return open


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	var game: String = T.options().get("game", "keen4")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var tag: String = "mr_scr05g_%d" % Time.get_ticks_usec()
	var cfg: String = OS.get_temp_dir().path_join(tag + ".cfg")
	var saves: String = OS.get_temp_dir().path_join(tag)
	host = GameHost.new()
	host.settings_path = cfg
	host.saves_dir = saves
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": game, "title": "Commander Keen", "folder": root_dir.path_join(game)})
	t.ok("%s starts (%s)" % [game, host.error], ok)
	if not ok:
		t.finish(self)
		return
	g = host.engine
	t.ok("Start opens the menu from the title", await _menu_from_title())
	await _pause(1.0)

	# EXTRAS' HELP: the help screens by the pad
	await _select("EXTRAS")
	await _button(JOY_BUTTON_A)
	await _pause(0.8)
	var extras: Array = (g.us_currentCard.items as Array).map(func(i: Object) -> String: return str(i.get("caption"))).filter(func(c: String) -> bool: return c != "")
	t.eq("EXTRAS: HELP, PADDLE WAR", extras, ["HELP", "PADDLE WAR"])
	await _select("HELP")
	await _button(JOY_BUTTON_A)
	t.ok("HELP opens the help screens (the pad the menus' keys in them)", await _wait(func() -> bool: return g.shell_menu_keys, 10.0))
	await _pause(1.0)
	var topic: int = g.help_topic
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _pause(0.5)
	t.eq("the d-pad moves the help's menu", g.help_topic, topic + 1)
	await _button(JOY_BUTTON_A)
	t.ok("A opens the topic (%d pages)" % g.help_num_pages, await _wait(func() -> bool: return g.help_num_pages > 0 and g.help_cur_page > 0, 10.0))
	await _pause(1.0)
	await _button(JOY_BUTTON_B)
	await _pause(1.5)
	await _button(JOY_BUTTON_B)
	t.ok("B leaves the topic, then the help: the cards again", await _wait(func() -> bool: return not g.shell_menu_keys and _selected() == "HELP", 10.0))
	await _button(JOY_BUTTON_B)
	await _pause(1.0)

	# a new game by the pad
	await _select("NEW GAME")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _select("BEGIN NORMAL GAME")
	await _button(JOY_BUTTON_A)
	t.ok("NEW GAME, BEGIN NORMAL GAME: on the world map", await _wait(func() -> bool: return g.game_in_progress != 0 and g.ck_gameState.currentLevel == 0 and host.controls_live(), 30.0))
	await _pause(2.0)

	# SAVE GAME: KEEN by the d-pad
	t.ok("Start in play opens the menu", await _menu_in_play())
	await _select("SAVE GAME")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _button(JOY_BUTTON_A)    # the first slot
	t.ok("the first slot asks for a name (the d-pad its letters)", await _wait(func() -> bool: return g.shell_text_entry, 10.0))
	await _type("KEEN")
	await _button(JOY_BUTTON_A)
	var file: String = saves.path_join(game).path_join(g.US_GetSavefileName(0))
	t.ok("A accepts: the game saved (%s)" % file.get_file(), await _wait(func() -> bool: return not g.shell_text_entry and FileAccess.file_exists(file), 10.0))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file)
	t.eq("the saved game's file holds the name typed", GalUS._cstr(bytes, 8, 33), "KEEN")
	await _pause(1.0)
	await _button(JOY_BUTTON_B)
	await _pause(1.0)
	await _select("RESUME")
	await _button(JOY_BUTTON_A)
	t.ok("RESUME: back on the map", await _wait(func() -> bool: return host.controls_live(), 10.0))
	await _pause(1.0)

	# a game over on the map, made while the host is paused: no lives left, a top score
	host.set_paused(true)
	await _pause(0.5)
	g.ck_gameState.numLives = 0
	g.ck_gameState.keenScore = 999999
	g.ck_gameState.levelState = g.LS_Died
	host.set_paused(false)
	# (Keen 5 blows the galaxy up first: some 30 seconds)
	t.ok("the game over asks for a high score's name", await _wait(func() -> bool: return g.shell_text_entry, 75.0))
	await _pause(0.5)
	await _type("KEEN")
	await _button(JOY_BUTTON_A)
	t.ok("A accepts the high score's name (%s)" % (g.ck_highScores[0] as Object).get("name"),
		await _wait(func() -> bool: return not g.shell_text_entry and str((g.ck_highScores[0] as Object).get("name")) == "KEEN", 10.0))
	await _pause(3.0)

	# Jump's buttons cleared: QUIT's question answered by the pad
	host.controls.clear("pad", "jump")
	host.apply_setting("controls")
	t.ok("Jump has no controller button (%s)" % host.controls.shown("pad", "jump"), host.controls.buttons("jump").is_empty())
	var opened: bool = false
	var main_card: Callable = func() -> bool:
		return not g.command_confirmed and not host.controls_live() and g.us_currentCard == g.ck_us_mainMenu and not g.shell_menu_keys
	for i: int in range(6):
		await _button(JOY_BUTTON_START)
		if await _wait(main_card, 6.0):
			opened = true
			break
	t.ok("Start opens the menu after the high scores", opened)
	await _pause(1.0)
	await _select("QUIT")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _select("QUIT")
	await _pause(0.5)
	t.ok("on QUIT's card, its QUIT chosen, no question open (%s)" % _selected(), _selected() == "QUIT" and not g.shell_menu_keys and not g.quitting)
	_send(JOY_BUTTON_A, true)    # held a second and a half: the machine's keyboard repeats its Enter
	var asked: bool = await _wait(func() -> bool: return g.shell_menu_keys, 5.0)
	await _pause(1.5)
	_send(JOY_BUTTON_A, false)
	await _pause(0.5)
	t.ok("REALLY QUIT? asks (the pad the menus' keys while it waits) and A held to open it is no answer",
		asked and g.shell_menu_keys and not g.quitting and host.thread != null)
	await _button(JOY_BUTTON_B)
	await _pause(1.5)
	t.ok("B backs out: still playing", host.thread != null and not g.quitting and not g.shell_menu_keys)
	await _button(JOY_BUTTON_A)
	t.ok("asked again", await _wait(func() -> bool: return g.shell_menu_keys, 5.0))
	await _pause(0.5)
	await _button(JOY_BUTTON_A)
	t.ok("A answers yes with no controller button on Jump: the game quits", await _wait(func() -> bool: return host.thread == null, 20.0))
	var config: String = saves.path_join(game).path_join("CONFIG." + ("CK4" if game == "keen4" else "CK5"))
	var cb: PackedByteArray = FileAccess.get_file_as_bytes(config)
	t.eq("CONFIG's first high score is named KEEN", GalUS._cstr(cb, 6, 58) if cb.size() > 70 else "(no file)", "KEEN")
	host.queue_free()
	await _pause(0.2)
	if DirAccess.dir_exists_absolute(saves.path_join(game)):
		for name: String in DirAccess.get_files_at(saves.path_join(game)):
			DirAccess.remove_absolute(saves.path_join(game).path_join(name))
		DirAccess.remove_absolute(saves.path_join(game))
	DirAccess.remove_absolute(saves)
	DirAccess.remove_absolute(cfg)
	t.finish(self)
