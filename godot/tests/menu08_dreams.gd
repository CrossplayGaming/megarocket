# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-08: Keen Dreams' control panel in the modern order (v1.93 in the host, real time; text keycaps, no
## new art): the icons Start or Resume, Load / Save / Quit, Options, Sound, Music, Extras. Options (O): the
## Input, Video, Audio, Game and Cheat keycaps; Video (V) the Display page in the box, Fullscreen changed
## with Enter; Audio (A) the volumes, Effects volume moved with Right;
## Game (G) the Gameplay page (Mode, quicksave, Fixes...), Mode moved with Right; Extras (E): the help's three and Score (S), the high scores
## over the panel, a key, the panel again. Pictures to --shots.
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
	await _pause(0.12)
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
	var cfg: String = OS.get_temp_dir().path_join("mr_menu08d_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	host.start({"id": "kdreams", "title": "Keen Dreams", "version": "v1.93", "folder": root_dir.path_join("kdreams193")})
	var g: Object = host.engine
	await _pause(2.0)
	await _tap(KEY_ENTER)    # the text start screen
	await _pause(5.0)
	await _tap(KEY_ENTER)    # the title: the control panel
	await _pause(2.0)
	await _shot("m08d_panel")
	var panels: Array = g.get("CtlPanels")
	var ys: Array = []
	for k: int in [0, 2, 3, 4, 5, 1]:    # Start, Disk, Controls (Options), Sound, Music, Help (Extras)
		ys.append(int(panels[k].r.ul.y))
	t.ok("the icons in the modern order: Start, Disk, Options, Sound, Music, Extras (%s)" % [ys], ys == ys.duplicate().map(func(v: int) -> int: return v) and ys[0] < ys[1] and ys[1] < ys[2] and ys[2] < ys[3] and ys[3] < ys[4] and ys[4] < ys[5])
	await _tap(KEY_O)
	await _pause(1.0)
	await _shot("m08d_options")
	var was: bool = bool(host.options.get_value("fullscreen"))
	await _tap(KEY_V)        # Video: the Display page
	await _pause(1.0)
	await _shot("m08d_display")
	await _tap(KEY_ENTER)    # Fullscreen
	t.ok("Video's Display page: Enter changes Fullscreen (%s -> %s)" % [was, host.options.get_value("fullscreen")],
		await _wait(func() -> bool: return bool(host.options.get_value("fullscreen")) != was, 3.0))
	await _tap(KEY_ESCAPE)
	await _pause(0.6)
	await _tap(KEY_A)        # Audio: the volumes
	await _pause(0.8)
	await _shot("m08d_audio")
	var vol: int = int(host.options.get_value("effects_volume"))
	await _tap(KEY_RIGHT)
	await _pause(0.3)
	t.ok("Audio's page: Effects volume moved with Right (%d -> %d); Music volume there too" % [vol, int(host.options.get_value("effects_volume"))],
		int(host.options.get_value("effects_volume")) == mini(vol + 10, 100)
		and host.options.page("sound").any(func(r: Dictionary) -> bool: return r.key == "music_volume"))
	await _tap(KEY_ESCAPE)
	await _pause(0.6)
	await _tap(KEY_G)        # Game: the Gameplay page
	await _pause(1.0)
	await _shot("m08d_gameplay")
	var rows: Array = host.options.page("gameplay").map(func(r: Dictionary) -> String: return r.label)
	t.eq("the Gameplay page (Dreams: Mode, quicksave, the fixes)", rows, ["Mode", "Quicksave F8/F9", "Quicksave asks", "Fixes...", "Back"])
	await _tap(KEY_RIGHT)    # Mode: Enhanced -> Classic
	await _pause(0.3)
	t.ok("Mode moved with Right (%s)" % host.options.mode_text(), host.options.mode_text() == "Classic")
	await _tap(KEY_RIGHT)
	await _pause(0.3)
	for i: int in range(3):
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)    # Fixes...
	await _pause(0.8)
	await _shot("m08d_fixes")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_ESCAPE)
	await _pause(0.6)
	await _tap(KEY_E)        # Extras
	await _pause(1.0)
	await _shot("m08d_extras")
	await _tap(KEY_S)        # Score
	await _pause(1.5)
	await _shot("m08d_scores")
	await _tap(KEY_ENTER)
	await _pause(1.5)
	await _shot("m08d_back")
	t.ok("still in the panel after the scores (the help line's Extras)", host.thread != null and not bool(g.get("quitting")))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
