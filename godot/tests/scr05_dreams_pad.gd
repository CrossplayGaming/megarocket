# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SCR-05 / SCR-03: Keen Dreams (v1.93) by the controller alone, in the host, real time, with real
## controller events (Input.parse_input_event); the panel's cursor is moved with the d-pad from button to
## button as the original moves it with the arrows. A past the text screen and the title: the control
## panel. Extras' Help keycap: the help text, the d-pad scrolls it, B leaves. Options' Input keycap, the
## Controls list: Reset to defaults asks (the A that chose it is no answer), A pressed again resets
## (Throw's buttons cleared before come back). The Start
## icon's Normal button: a game. In it Start opens the panel; Load / Save's first Save button asks for a
## name: KEEN typed with the d-pad (Up steps the letter under the cursor, Right moves on) and A: the saved
## game's file holds the name KEEN; B back to the game. A game over made in it (no lives left and a top
## score, set while the host is paused): A past Game Over, the high score's name KEEN by the d-pad;
## KDREAMS.CFG, written as the game quits, holds it.
##
## Options: --game_data=<folder>

var t: T = T.new()
var host: GameHost = null
var g: DreamsGame = null


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


## A controller button pressed and let go, as the device sends it.
func _button(b: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		e.device = 0
		Input.parse_input_event(e)
		await _pause(0.1 if down else 0.15)


## A word typed with the d-pad: each letter stepped to with Up from none, Right to the next.
func _type(word: String) -> void:
	for k: int in range(word.length()):
		for i: int in range(PadTextEntry.LETTERS.find(word[k]) + 1):
			await _button(JOY_BUTTON_DPAD_UP)
		if k < word.length() - 1:
			await _button(JOY_BUTTON_DPAD_RIGHT)


## An item's rectangle as [left, top, right, bottom].
func _rect(item: Object) -> Array:
	var r: Object = item.get("r")
	return [int(r.get("ul").get("x")), int(r.get("ul").get("y")), int(r.get("lr").get("x")), int(r.get("lr").get("y"))]


## The panel's cursor moved with the d-pad onto item n of the panel's list i (TheItems[i]), as the
## original's arrows move it (USL_FindRect: across to a button level with the one it is on, else up or
## down): across once the button under the cursor is level with the target, up or down until then (the
## other way when a press moves nothing).
func _reach(i: int, n: int) -> bool:
	var last: Vector2i = Vector2i(-1, -1)
	for step: int in range(30):
		var hit: PackedInt32Array = g.USL_IsInRect(g.CursorX, g.CursorY, 0, 0)
		if hit[0] == 1 and hit[1] == i and hit[2] == n:
			return true
		var list: Variant = g.TheItems[i]
		if list == null:
			return false
		var to: Array = _rect((list as Array)[n])
		var at: Vector2i = Vector2i(g.CursorX, g.CursorY)
		var on: Array = _rect((g.TheItems[hit[1]] as Array)[hit[2]]) if hit[0] == 1 else [at.x, at.y, at.x + 1, at.y + 1]
		var level: bool = (to[1] >= on[1] and to[1] < on[3]) or (to[3] > on[1] and to[3] <= on[3])
		var vertical: bool = not level
		if at == last:
			vertical = not vertical
		last = at
		if vertical:
			await _button(JOY_BUTTON_DPAD_DOWN if to[1] >= on[3] else JOY_BUTTON_DPAD_UP)
		else:
			await _button(JOY_BUTTON_DPAD_RIGHT if to[0] >= on[2] else JOY_BUTTON_DPAD_LEFT)
		await _pause(0.3)
	return false


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var tag: String = "mr_scr05d_%d" % Time.get_ticks_usec()
	var cfg: String = OS.get_temp_dir().path_join(tag + ".cfg")
	var saves: String = OS.get_temp_dir().path_join(tag)
	host = GameHost.new()
	host.settings_path = cfg
	host.saves_dir = saves
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "kdreams", "title": "Keen Dreams", "version": "v1.93", "folder": root_dir.path_join("kdreams193")})
	t.ok("Keen Dreams starts (%s)" % host.error, ok)
	if not ok:
		t.finish(self)
		return
	g = host.engine
	await _pause(2.0)
	await _button(JOY_BUTTON_A)    # the text start screen
	await _pause(5.0)
	await _button(JOY_BUTTON_A)    # the title: the control panel
	t.ok("A past the text screen and the title: the control panel", await _wait(func() -> bool: return g.TheItems[1] != null, 10.0))
	await _pause(1.5)

	# Extras' Help keycap: the help text by the pad
	t.ok("the d-pad reaches the Extras icon", await _reach(0, 1))
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	t.ok("and the Help keycap", await _reach(1, 0))
	await _button(JOY_BUTTON_A)
	t.ok("A opens the help text", await _wait(func() -> bool: return not g.LineOffsets.is_empty(), 10.0))
	await _pause(1.0)
	var before: PackedByteArray = host.vm.card.frame_pixels.duplicate()
	for k: int in range(3):
		await _button(JOY_BUTTON_DPAD_DOWN)
	await _pause(0.5)
	t.ok("the d-pad scrolls it", host.vm.card.frame_pixels != before)
	await _button(JOY_BUTTON_B)
	t.ok("B leaves it", await _wait(func() -> bool: return g.LineOffsets.is_empty(), 10.0))
	await _pause(1.0)

	# Options' Input keycap: Reset to defaults by the pad
	host.controls.clear("pad", "fire")
	host.apply_setting("controls")
	t.ok("the d-pad reaches the Options icon", await _reach(0, 3))
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	t.ok("and its Input keycap", await _reach(1, 0))
	await _button(JOY_BUTTON_A)
	t.ok("the Controls list (the pad the play controls in it)", await _wait(func() -> bool: return host.controls_live(), 5.0))
	await _pause(0.5)
	var rows: Array = host.options.page("controls").map(func(r: Dictionary) -> String: return r.key)
	for k: int in range(rows.find("reset_controls")):
		await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	t.ok("Reset to defaults asks: the A that chose it no answer (nothing reset yet)", host.controls.buttons("fire").is_empty())
	await _button(JOY_BUTTON_A)
	t.ok("A resets: Throw's buttons back (%s)" % host.controls.shown("pad", "fire"),
		await _wait(func() -> bool: return host.controls.buttons("fire") == ControlsModel.PAD_DEFAULTS["fire"], 5.0))
	await _pause(0.5)
	await _button(JOY_BUTTON_B)    # out of the list
	await _pause(1.0)

	# the Start icon's Normal button
	t.ok("the d-pad reaches the Start icon", await _reach(0, 0))
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	t.ok("and the Normal button", await _reach(2, 0))
	await _button(JOY_BUTTON_A)
	t.ok("A starts a game", await _wait(func() -> bool: return g.ingame and host.controls_live(), 30.0))
	await _pause(2.0)

	# Load / Save: KEEN by the d-pad
	await _button(JOY_BUTTON_START)
	t.ok("Start opens the panel", await _wait(func() -> bool: return not host.controls_live(), 10.0))
	await _pause(1.5)
	t.ok("the d-pad reaches Load or Save a Game", await _reach(1, 0))
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	t.ok("and the first Save button", await _reach(2, 1))
	await _button(JOY_BUTTON_A)
	t.ok("it asks for a name (the d-pad its letters)", await _wait(func() -> bool: return g.shell_text_entry, 10.0))
	await _pause(0.5)
	await _type("KEEN")
	await _button(JOY_BUTTON_A)
	var file: String = saves.path_join("kdreams193").path_join(g.USL_GiveSaveName(0).to_upper())
	t.ok("A accepts: the game saved (%s)" % file.get_file(), await _wait(func() -> bool: return not g.shell_text_entry and FileAccess.file_exists(file), 10.0))
	await _pause(0.5)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file)
	t.eq("the saved game's file holds the name typed", GalUS._cstr(bytes, 6, 33), "KEEN")
	await _button(JOY_BUTTON_B)
	t.ok("B: back to the game", await _wait(func() -> bool: return host.controls_live(), 10.0))
	await _pause(1.5)

	# a game over made while the host is paused: no lives left, a top score
	host.set_paused(true)
	await _pause(0.5)
	g.gamestate.lives = 0
	g.gamestate.score = 999999
	g.playstate = g.died
	host.set_paused(false)
	t.ok("Game Over (the controls no longer read)", await _wait(func() -> bool: return not host.controls_live() and not g.ingame, 15.0))
	await _pause(2.0)
	await _button(JOY_BUTTON_A)
	t.ok("A past it: the high score's name asked", await _wait(func() -> bool: return g.shell_text_entry, 15.0))
	await _pause(0.5)
	await _type("KEEN")
	await _button(JOY_BUTTON_A)
	var named: Callable = func() -> bool: return not g.shell_text_entry and g._cstring((g.Scores[0] as Object).get("name")) == "KEEN"
	t.ok("A accepts the high score's name", await _wait(named, 10.0))
	await _pause(6.0)
	host.stop()
	t.ok("the game quits", await _wait(func() -> bool: return host.thread == null, 20.0))
	var cb: PackedByteArray = FileAccess.get_file_as_bytes(saves.path_join("kdreams193").path_join("KDREAMS.CFG"))
	t.eq("KDREAMS.CFG's first high score is named KEEN", GalUS._cstr(cb, 0, 58) if cb.size() > 58 else "(no file)", "KEEN")
	host.queue_free()
	await _pause(0.2)
	if DirAccess.dir_exists_absolute(saves.path_join("kdreams193")):
		for name: String in DirAccess.get_files_at(saves.path_join("kdreams193")):
			DirAccess.remove_absolute(saves.path_join("kdreams193").path_join(name))
		DirAccess.remove_absolute(saves.path_join("kdreams193"))
	DirAccess.remove_absolute(saves)
	DirAccess.remove_absolute(cfg)
	t.finish(self)
