# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-04, the two-button reset: Back and Start held together on a controller for three seconds give its
## buttons back their defaults, in any menu or in play, with real controller events (Input.parse_input_event)
## to Keen 4 in the host. In the menu, Jump's buttons cleared: Back then Start held one second does nothing
## (and Start, the second, never reaches the game: no REALLY QUIT?); held three and a half, Jump has A again,
## in the game's controls at once and in the settings file, and the screen says so. In play, Jump cleared
## again: Start then Back (the menu opens, Back's Status never sent) held as long resets them the same.
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


func _send(b: JoyButton, down: bool) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.device = 0
	Input.parse_input_event(e)


func _button(b: JoyButton) -> void:
	_send(b, true)
	await _pause(0.1)
	_send(b, false)
	await _pause(0.15)


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


## `first` then `second` held for `seconds`, then both let go. Returns the scan codes the game was given
## and held at any time meanwhile (sampled every frame).
func _hold(first: JoyButton, second: JoyButton, seconds: float) -> Dictionary:
	var held: Dictionary = {}
	_send(first, true)
	await _pause(0.3)
	for code: int in host._held:
		held[code] = true
	_send(second, true)
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		for code: int in host._held:
			held[code] = true
	_send(second, false)
	_send(first, false)
	await _pause(0.3)
	return held


func _jump_cleared() -> bool:
	host.controls.clear("pad", "jump")
	host.apply_setting("controls")
	return host.controls.buttons("jump").is_empty() and not (g.shell_controls.get("jump", PackedInt32Array()) as PackedInt32Array).has(0x62)


func _jump_back() -> bool:
	var saved: ControlsModel = ControlsModel.new(Settings.new(host.settings_path))
	return host.controls.buttons("jump") == [JOY_BUTTON_A] and saved.buttons("jump") == [JOY_BUTTON_A] and \
		(g.shell_controls.get("jump", PackedInt32Array()) as PackedInt32Array).has(0x62)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var tag: String = "mr_shell04_%d" % Time.get_ticks_usec()
	var cfg: String = OS.get_temp_dir().path_join(tag + ".cfg")
	var saves: String = OS.get_temp_dir().path_join(tag)
	host = GameHost.new()
	host.settings_path = cfg
	host.saves_dir = saves
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "keen4", "title": "Commander Keen 4", "folder": root_dir.path_join("keen4")})
	t.ok("Keen 4 starts (%s)" % host.error, ok)
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

	# in the menu
	t.ok("Jump's controller buttons cleared (in the game's controls too)", _jump_cleared())
	var held: Dictionary = await _hold(JOY_BUTTON_BACK, JOY_BUTTON_START, 1.0)
	await _pause(0.5)
	t.ok("Back and Start held one second: nothing reset", host.controls.buttons("jump").is_empty())
	t.ok("Start, the second down, never reached the game (held: %s; no REALLY QUIT?)" % [held.keys()], not held.has(0x01) and not g.shell_menu_keys)
	var shown: Array = [false]
	var watch: Callable = func() -> bool:
		shown[0] = shown[0] or (host._message != null and host._message.visible and host._message.text == GameHost.RESET_TEXT)
		return false
	_send(JOY_BUTTON_BACK, true)
	await _pause(0.3)
	_send(JOY_BUTTON_START, true)
	await _wait(watch, 3.6)
	_send(JOY_BUTTON_START, false)
	_send(JOY_BUTTON_BACK, false)
	await _pause(0.3)
	t.ok("held three and a half seconds: Jump has A again, in the game's controls and the settings file (%s)" % host.controls.shown("pad", "jump"), _jump_back())
	t.ok("the screen says so (%s)" % GameHost.RESET_TEXT, shown[0])
	t.ok("and the word goes after a few seconds", await _wait(func() -> bool: return not host._message.visible, 5.0))
	t.ok("still in the menu, no question asked", host.thread != null and not g.shell_menu_keys and not host.controls_live())

	# in play
	await _select("NEW GAME")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _select("BEGIN NORMAL GAME")
	await _button(JOY_BUTTON_A)
	t.ok("A new game by A (Jump's A back): on the world map", await _wait(func() -> bool: return g.game_in_progress != 0 and host.controls_live(), 30.0))
	await _pause(2.0)
	t.ok("Jump cleared again", _jump_cleared())
	held = await _hold(JOY_BUTTON_START, JOY_BUTTON_BACK, 3.5)
	t.ok("in play, Start then Back held: Jump has A again (%s)" % host.controls.shown("pad", "jump"), _jump_back())
	t.ok("Start opened the menu as ever; Back, the second, never reached the game (held: %s)" % [held.keys()], held.has(0x01) and not held.has(0x6A))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 15.0)
	host.queue_free()
	await _pause(0.2)
	if DirAccess.dir_exists_absolute(saves.path_join("keen4")):
		for name: String in DirAccess.get_files_at(saves.path_join("keen4")):
			DirAccess.remove_absolute(saves.path_join("keen4").path_join(name))
		DirAccess.remove_absolute(saves.path_join("keen4"))
	DirAccess.remove_absolute(saves)
	DirAccess.remove_absolute(cfg)
	t.finish(self)
