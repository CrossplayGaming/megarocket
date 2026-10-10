# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-08: Keen 1-3's main menus in the modern order (Keen 1 in the host, real time). The title menu: New
## Game, Load Game, Options..., Cheats..., High Scores, Extras..., Quit; Extras its own list (Story, About
## ID..., Ordering Info, Previews!, Restart Demo, Back), Escape back. In a game Escape is the pause menu:
## Resume, New Game, Load Game, Save Game, Options..., Cheats..., High Scores and Extras... (greyed: from the
## title), Quit; Resume back to play; New Game asks, goes by the title and starts a new game at once; Load
## Game asks, goes by the title and opens its Continue Game window. Pictures to --shots.
##
## Options: --game_data=<folder> [--shots=<folder>]

var t: T = T.new()
var host: GameHost = null
var shots: String = ""


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


func _tap(code: Key) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.pressed = true
	host._input(k)
	await _pause(0.15)
	k = k.duplicate()
	k.pressed = false
	host._input(k)
	await _pause(0.3)


func _shot(name: String) -> void:
	if shots == "":
		return
	var card: EgaCard = host.vm.card
	var px: PackedByteArray = card.frame_pixels.duplicate()
	var pal: PackedByteArray = card.frame_palette.duplicate()
	if px.size() != 64000 or pal.size() < 48:
		return
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(64000 * 3)
	for i: int in range(64000):
		var c: int = mini(px[i], pal.size() / 3 - 1) * 3
		rgb[i * 3] = pal[c]
		rgb[i * 3 + 1] = pal[c + 1]
		rgb[i * 3 + 2] = pal[c + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(shots.path_join(name + ".png"))


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	shots = T.options().get("shots", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_menu08_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": root_dir.path_join("keen1")})
	var g: VortDemo = host.engine
	await _wait(func() -> bool: return host.frames_shown >= 30, 60.0)
	await _pause(2.0)
	await _tap(KEY_ENTER)    # past the intro: the title menu
	await _pause(2.5)
	await _shot("m08_title")
	var labels: Callable = func(rows: Array) -> Array: return rows.map(func(r: Dictionary) -> String: return r.label)
	t.eq("the title menu's rows", labels.call(g._menu_rows()), ["New Game", "Load Game", "Options...", "Cheats...", "High Scores", "Extras...", "Quit"])
	for i: int in range(5):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _pause(1.0)
	await _shot("m08_extras")
	t.ok("Extras is its own list (%s)" % [labels.call(g._menu_rows())], g._menu_page == "extras"
		and labels.call(g._menu_rows()) == ["Story", "About ID...", "Ordering Info", "Previews!", "Restart Demo", "Back"])
	await _tap(KEY_ESCAPE)
	t.ok("Escape: back to the main list", await _wait(func() -> bool: return g._menu_page == "main", 3.0))
	await _pause(1.0)
	await _tap(KEY_ENTER)    # New Game
	t.ok("New Game starts a game", await _wait(func() -> bool: return host.controls_live(), 20.0))
	await _pause(1.5)

	# the pause menu
	await _tap(KEY_ESCAPE)
	t.ok("Escape in a game: the pause menu", await _wait(func() -> bool: return g.shell_menu_open, 3.0))
	await _pause(0.6)
	await _shot("m08_pause")
	var pause: Array = g._options_rows("pause")
	t.eq("the pause menu's rows", labels.call(pause), ["Resume", "New Game", "Load Game", "Save Game", "Options...", "Cheats...", "High Scores", "Extras...", "Quit"])
	t.ok("High Scores and Extras greyed there", not pause[6].get("enabled", true) and not pause[7].get("enabled", true))
	await _tap(KEY_ENTER)    # Resume
	t.ok("Resume: back in play", await _wait(func() -> bool: return not g.shell_menu_open and host.controls_live(), 3.0))
	await _pause(0.5)

	# New Game from the pause menu: asked, by the title, a new game at once
	await _tap(KEY_ESCAPE)
	await _wait(func() -> bool: return g.shell_menu_open, 3.0)
	await _pause(0.4)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _pause(0.4)
	await _shot("m08_leave")
	await _tap(KEY_Y)
	t.ok("New Game: the game left (no score to keep: no game-over, no table)", await _wait(func() -> bool: return not g.shell_on_map, 5.0))
	t.ok("and a new one started without the menu", await _wait(func() -> bool: return g.shell_on_map and host.controls_live() and not g.shell_menu_open, 20.0))
	await _pause(1.5)

	# Load Game from the pause menu: asked, by the title, its Continue Game window
	await _pause(1.5)
	await _tap(KEY_ESCAPE)
	t.ok("the pause menu again", await _wait(func() -> bool: return g.shell_menu_open, 3.0))
	await _pause(0.4)
	await _tap(KEY_DOWN)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await _pause(0.4)
	await _shot("m08_leave2")
	await _tap(KEY_Y)
	t.ok("Load Game: the game left for the title", await _wait(func() -> bool: return not g.shell_playing, 8.0))
	await _pause(2.0)
	await _shot("m08_load")
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
