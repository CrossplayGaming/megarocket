# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## TOUCH-01 (J-54, J-50): the touch controls' own settings and their Status button, in one game of each
## engine (in the host, real time, with real key, controller and touch events: Input.parse_input_event).
## The game's Touch page (Keen 1-3: Options > Controls... > Touch...; Keen 4-6: CONFIGURE's TOUCH card;
## Keen Dreams: the Input keycap's Touch...) lists Layout, Opacity, Size and Show with a pad; each is moved
## by the keys or by the controller, the game's own setting changes (that game's only), and the on-screen
## controls follow at once: the d-pad on the right, their opacity, their size, and shown with a controller
## in use only once Show with a pad is on. Then, with the keyboard's Status moved to Q, the overlay's OK
## (Enter) no longer opens the status screen (Keen 1, Keen 4) but its Status button does, in every engine,
## and a key closes it again.
##
## Pictures of the game's screen (the machine's own 320x200, without the touch controls) at the steps go
## to --shots.
##
## Options: --game_data=<folder> [--game=keen1|keen4|kdreams193] [--shots=<folder>]

var t: T = T.new()
var host: GameHost = null
var game: String = "keen1"
var cfg: String = ""
var shots: String = ""
const SCREEN: Vector2i = Vector2i(851, 393)


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


## A key pressed and let go, as the keyboard sends it.
func _key(code: Key) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	Input.parse_input_event(k)
	await _pause(0.12)
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await _pause(0.2)


## A controller button pressed and let go, as the device sends it.
func _button(b: JoyButton) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	e.device = 0
	Input.parse_input_event(e)
	await _pause(0.12)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _pause(0.2)


## A finger on one of the overlay's buttons, then lifted.
func _tap(button_name: String) -> void:
	var o: TouchOverlay = host.overlay
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = 0
	e.position = o.get_global_transform_with_canvas() * o.button_rect(button_name).get_center()
	e.pressed = true
	Input.parse_input_event(e)
	await _pause(0.25)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _pause(0.2)


## The machine's picture to --shots.
func _shot(name: String) -> void:
	if shots == "":
		return
	var card: EgaCard = host.vm.card
	var px: PackedByteArray = card.frame_pixels.duplicate()    # (the engine's thread draws on)
	var pal: PackedByteArray = card.frame_palette.duplicate()
	if px.size() != 320 * 200 or pal.size() < 48:
		return
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(320 * 200 * 3)
	for i: int in range(320 * 200):
		var c: int = mini(px[i], pal.size() / 3 - 1) * 3
		rgb[i * 3] = pal[c]
		rgb[i * 3 + 1] = pal[c + 1]
		rgb[i * 3 + 2] = pal[c + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(shots.path_join("touch01_%s_%s.png" % [game, name]))


## This game's own value of a setting, as saved in the settings file.
func _saved(name: String, id: String = "") -> Variant:
	return Settings.new(cfg).get_value(name, game_id() if id == "" else id)


func game_id() -> String:
	return "kdreams" if game.begins_with("kdreams") else game


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	game = T.options().get("game", "keen1")
	shots = T.options().get("shots", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var tag: String = "mr_touch01_%s_%d" % [game, Time.get_ticks_usec()]
	cfg = OS.get_temp_dir().path_join(tag + ".cfg")
	root.size = SCREEN
	host = GameHost.new()
	host.settings_path = cfg
	host.saves_dir = OS.get_temp_dir().path_join(tag)
	host.speed = 1.0
	host.force_touch = true
	root.add_child(host)
	var found: Dictionary = {"id": game_id(), "title": game, "folder": root_dir.path_join(game)}
	if game == "keen1":
		found["version"] = "v1.31 EGA"
		found["play_level"] = 1
	elif game == "kdreams193":
		found["version"] = "v1.93"
	var ok: bool = host.start(found)
	t.ok("%s starts (%s)" % [game, host.error], ok)
	if not ok:
		t.finish(self)
		return
	var o: TouchOverlay = host.overlay
	t.ok("the touch controls at their defaults: d-pad left, opacity 50, size 100, hidden with a pad",
		o.layout == "standard" and o.opacity == 50 and o.size_percent == 100 and not o.with_pad
		and o.dpad_rect().position.x < SCREEN.x / 2.0 and o.has_method("shade"))
	t.ok("a Status button of its own (J-50: the touch screen's Status code, 0x74)",
		o.codes_at(o.button_rect("Status").get_center()) == [0x74] and ControlsModel.TOUCH_CODES.get("status") == 0x74)
	match game:
		"keen1":
			await _vorticons()
		"keen4":
			await _galaxy()
		_:
			await _dreams()
	host.stop()
	await _pause(1.0)
	host.queue_free()
	await process_frame
	DirAccess.remove_absolute(cfg)
	t.finish(self)


## The overlay follows each row as it changes (the four checks every engine makes).
func _check_layout() -> void:
	var o: TouchOverlay = host.overlay
	t.ok("Layout moved to D-pad right: saved for %s only (%s; Keen 2: %s)" % [game_id(), _saved("touch_layout"), _saved("touch_layout", "keen2")],
		await _wait(func() -> bool: return _saved("touch_layout") == "swapped", 3.0) and _saved("touch_layout", "keen2") == "standard")
	t.ok("the d-pad now on the right, the buttons on the left (d-pad at x %d, Jump at x %d)" % [o.dpad_rect().position.x, o.button_rect("Jump").position.x],
		o.layout == "swapped" and o.dpad_rect().position.x > SCREEN.x / 2.0 and o.button_rect("Jump").end.x < SCREEN.x / 2.0)


func _check_opacity(want: int) -> void:
	var o: TouchOverlay = host.overlay
	t.ok("Opacity moved to %d%% (%s)" % [want, str(_saved("touch_opacity"))], await _wait(func() -> bool: return _saved("touch_opacity") == want, 3.0))
	t.ok("the controls drawn at it (a button %.3f, was 0.180)" % o.shade(0.18), o.opacity == want and is_equal_approx(o.shade(0.18), 0.18 * want / 50.0))


func _check_size(want: int) -> void:
	var o: TouchOverlay = host.overlay
	t.ok("Size moved to %d%% (%s)" % [want, str(_saved("touch_size"))], await _wait(func() -> bool: return _saved("touch_size") == want, 3.0))
	t.ok("the buttons that size (Jump %.1f wide, d-pad %.1f)" % [o.button_rect("Jump").size.x, o.dpad_rect().size.x],
		is_equal_approx(o.button_rect("Jump").size.x, TouchOverlay.BUTTON * want / 100.0) and is_equal_approx(o.dpad_rect().size.x, TouchOverlay.BUTTON * 3 * want / 100.0))


## A pad in use (its buttons pressed, as connected): the controls hidden; Show with a pad then moved on
## by `move` (the pad itself): shown again.
func _check_with_pad(move: Callable) -> void:
	var o: TouchOverlay = host.overlay
	host.connected_pads = func() -> Array: return [0]
	t.ok("a controller in use: the touch controls hidden (Show with a pad off)", await _wait(func() -> bool: return not o.visible, 2.0))
	await move.call()
	t.ok("Show with a pad moved On by the controller (%s)" % str(_saved("touch_with_pad")), await _wait(func() -> bool: return _saved("touch_with_pad") == true, 3.0))
	t.ok("the touch controls shown with the controller in use", await _wait(func() -> bool: return o.visible, 2.0))
	host.connected_pads = func() -> Array: return []


## J-50: the keyboard's Status moved to Q; OK (Enter) opens nothing (where `ok_check`), the overlay's
## Status opens the status screen (`shown`), a key closes it (`gone`).
func _check_status(shown: Callable, gone: Callable, ok_check: bool) -> void:
	host.controls.clear("keys", "status")
	host.controls.bind("keys", "status", KEY_Q, 0)
	host.apply_setting("controls")
	await _pause(0.5)
	t.ok("the touch controls shown, in play", host.overlay.visible and host.controls_live())
	if ok_check:
		await _tap("OK")
		await _pause(1.5)
		t.ok("OK (Enter, no longer Status) opens no status screen", not shown.call() and host.controls_live())
	await _tap("Status")
	t.ok("the overlay's Status opens the status screen (the keyboard's Status: %s)" % host.controls.shown("keys", "status"),
		await _wait(shown, 4.0))
	await _pause(1.0)
	_shot("status")
	await _key(KEY_ENTER)
	t.ok("a key closes it: back in play", await _wait(gone, 6.0))


# ------------------------------------------------------------------ Keen 1

func _vorticons() -> void:
	var g: Object = host.engine
	t.ok("Keen 1 in a level", await _wait(func() -> bool: return host.controls_live(), 30.0))
	await _pause(1.0)
	var page: Callable = func(p: String) -> Callable: return func() -> bool: return str(g.get("shell_menu_page")) == p
	await _key(KEY_F3)    # the Options window at the Keyboard page
	await _wait(page.call("keys"), 3.0)
	await _key(KEY_ESCAPE)    # up to Controls
	t.ok("Options > Controls... lists Touch... beside Keyboard... and Controller...",
		await _wait(page.call("controls"), 3.0) and (host.options.page("controls") as Array).map(func(r: Dictionary) -> String: return r.label).slice(0, 3)
			== ["Keyboard...", "Controller...", "Touch..."])
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	t.ok("Touch... opens the Touch page: Layout, Opacity, Size, Show with a pad",
		await _wait(page.call("touch"), 3.0) and (host.options.page("touch") as Array).map(func(r: Dictionary) -> String: return r.label)
			== ["Layout", "Opacity", "Size", "Show with a pad", "Back"])
	await _pause(0.5)
	_shot("page")
	await _key(KEY_RIGHT)    # Layout (the keys)
	await _check_layout()
	await _button(JOY_BUTTON_DPAD_DOWN)    # Opacity (the controller)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _check_opacity(60)
	await _key(KEY_DOWN)    # Size (the keys)
	await _key(KEY_LEFT)
	await _key(KEY_LEFT)
	await _check_size(80)
	_shot("changed")
	await _button(JOY_BUTTON_DPAD_DOWN)    # Show with a pad
	await _check_with_pad(func() -> void: await _button(JOY_BUTTON_DPAD_RIGHT))
	for i: int in range(4):
		if host.controls_live() and g.get("shell_menu_open") != true:
			break
		await _key(KEY_ESCAPE)
		await _pause(0.4)
	t.ok("out of Options, back in play", await _wait(func() -> bool: return host.controls_live() and g.get("shell_menu_open") != true, 3.0))
	await _pause(0.5)
	# (the status screen: the play stops reading its controls while it waits for a key)
	await _check_status(func() -> bool: return not host.controls_live(), func() -> bool: return host.controls_live(), true)


# ------------------------------------------------------------------ Keen 4

func _caption() -> String:
	var card: Object = host.engine.get("us_currentCard")
	return str((card.items[card.selectedItem] as Object).get("caption")) if card != null else ""


func _captions() -> Array:
	var card: Object = host.engine.get("us_currentCard")
	if card == null:
		return []
	return (card.items as Array).map(func(i: Object) -> String: return str(i.get("caption"))).filter(func(c: String) -> bool: return c != "")


## The card's item starting with `prefix` selected with the d-pad.
func _select(prefix: String) -> bool:
	var card: Object = host.engine.get("us_currentCard")
	var at: int = -1
	for i: int in range((card.items as Array).size()):
		if str((card.items[i] as Object).get("caption")).begins_with(prefix):
			at = i
	for n: int in range(12):
		if at < 0 or card.selectedItem == at:
			break
		await _button(JOY_BUTTON_DPAD_DOWN if card.selectedItem < at else JOY_BUTTON_DPAD_UP)
	return at >= 0 and card.selectedItem == at


## A row chosen by `press` (Enter or A), its word said, the word dismissed by the same.
func _g_choose(press: Callable) -> void:
	await press.call()
	await _pause(0.8)
	await press.call()
	await _pause(0.6)


func _galaxy() -> void:
	var g: Object = host.engine
	for i: int in range(12):
		if host.vm.marks.has("menu"):
			break
		await _button(JOY_BUTTON_START)
		await _pause(1.5)
	t.ok("the menu from the title", host.vm.marks.has("menu"))
	await _pause(1.0)
	await _select("OPTIONS")
	await _button(JOY_BUTTON_A)
	await _pause(0.8)
	t.ok("CONFIGURE has TOUCH after CONTROLS (%s)" % [_captions()], _captions().find("TOUCH") == _captions().find("CONTROLS") + 1)
	_shot("configure")
	await _select("TOUCH")
	await _button(JOY_BUTTON_A)
	t.ok("TOUCH opens its card", await _wait(func() -> bool: return g.get("us_currentCard") == g.get("ck_us_touchMenu"), 3.0))
	await _pause(0.6)
	t.eq("TOUCH's rows", _captions(), ["LAYOUT (D-PAD LEFT)", "OPACITY (50%)", "SIZE (100%)", "SHOW WITH A PAD (OFF)"])
	_shot("page")
	await _select("LAYOUT")
	await _g_choose(func() -> void: await _key(KEY_ENTER))    # the keys
	await _check_layout()
	await _select("OPACITY")
	await _g_choose(func() -> void: await _button(JOY_BUTTON_A))    # the controller
	await _check_opacity(60)
	await _select("SIZE")
	await _g_choose(func() -> void: await _key(KEY_ENTER))
	await _check_size(110)
	t.ok("the card's captions read the values (%s)" % [_captions()], _captions().slice(0, 3) == ["LAYOUT (D-PAD RIGHT)", "OPACITY (60%)", "SIZE (110%)"])
	_shot("changed")
	await _select("SHOW WITH A PAD")
	await _check_with_pad(func() -> void: await _g_choose(func() -> void: await _button(JOY_BUTTON_A)))
	await _button(JOY_BUTTON_B)
	await _pause(0.6)
	await _button(JOY_BUTTON_B)
	await _pause(0.8)
	await _select("NEW GAME")
	await _button(JOY_BUTTON_A)
	await _pause(1.0)
	await _select("BEGIN NORMAL GAME")
	await _button(JOY_BUTTON_A)
	t.ok("a new game: on the world map", await _wait(func() -> bool: return int(g.get("game_in_progress")) != 0 and host.controls_live(), 30.0))
	await _pause(2.0)
	await _check_status(func() -> bool: return int(g.get("ck_statusWindowYPx")) == 168,
		func() -> bool: return int(g.get("ck_statusWindowYPx")) <= 0 and host.controls_live(), true)


# ------------------------------------------------------------------ Keen Dreams

func _dreams() -> void:
	var g: Object = host.engine
	var page: Callable = func(p: String) -> Callable: return func() -> bool: return str(g.get("shell_menu_page")) == p
	await _pause(2.0)
	await _key(KEY_ENTER)    # the text start screen
	await _pause(5.0)
	await _key(KEY_ENTER)    # the title: the control panel
	await _pause(2.0)
	await _key(KEY_O)        # Options
	await _pause(0.6)
	await _key(KEY_F3)       # the Input keycap: the Controls page
	t.ok("the Input keycap: the Controls page, Touch... beside Keyboard... and Controller...",
		await _wait(page.call("controls"), 3.0) and (host.options.page("controls") as Array).map(func(r: Dictionary) -> String: return r.label).slice(0, 3)
			== ["Keyboard...", "Controller...", "Touch..."])
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	t.ok("Touch... opens the Touch page in the panel's box", await _wait(page.call("touch"), 3.0))
	await _pause(0.5)
	_shot("page")
	await _key(KEY_RIGHT)    # Layout (the keys)
	await _check_layout()
	await _button(JOY_BUTTON_DPAD_DOWN)    # Opacity (the controller)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _check_opacity(60)
	await _key(KEY_DOWN)    # Size (the keys)
	await _key(KEY_LEFT)
	await _key(KEY_LEFT)
	await _check_size(80)
	_shot("changed")
	await _button(JOY_BUTTON_DPAD_DOWN)    # Show with a pad
	await _check_with_pad(func() -> void: await _button(JOY_BUTTON_DPAD_RIGHT))
	await _key(KEY_ESCAPE)    # back to the Controls page
	await _pause(0.4)
	await _key(KEY_ESCAPE)    # out of the list
	await _pause(0.6)
	await _key(KEY_F5)        # New Game: the difficulty buttons
	await _pause(0.6)
	await _key(KEY_ENTER)     # Normal
	t.ok("a game started on the world map", await _wait(func() -> bool: return bool(g.get("ingame")) and host.controls_live(), 20.0))
	await _pause(1.5)
	# (the status window: the play stops reading its controls while it waits for a key; Enter on the map
	# is no status key either way, so OK's own check is Keen 1's and Keen 4's)
	await _check_status(func() -> bool: return not host.controls_live(), func() -> bool: return host.controls_live(), false)
