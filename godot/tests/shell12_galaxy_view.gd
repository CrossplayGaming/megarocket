# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-12: Keen 4-6 in the host with the default settings (Enhanced: native resolution, smooth motion,
## the wide view). Each game starts; its first screens (the intro, the title) are the 320x200 picture in
## the frame over the game's own backdrop; then its title demo plays and is drawn by the shell's view
## (GalNativeView) as wide as the window allows, the frame put away; the engine is told the wide view's
## extra tiles (J-30).
##
## Options: --game_data=<folder> [--games=keen4,keen5,keen6]

var t: T = T.new()

const META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	root.size = Vector2i(1600, 900)
	for game: String in str(T.options().get("games", "keen4,keen5,keen6")).split(","):
		await _game(root_dir, game)
	t.finish(self)


func _game(root_dir: String, game: String) -> void:
	var cfg: String = OS.get_temp_dir().path_join("mr_shell12_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 4.0    # to the title demo sooner
	root.add_child(host)
	var ok: bool = host.start({"id": game, "title": game, "folder": root_dir.path_join(game)})
	t.ok("%s starts (%s)" % [game, host.error], ok)
	if not ok:
		host.queue_free()
		return
	var framed: bool = await _wait(func() -> bool:
		return host.frames_shown > 10 and host._view.visible and host._backdrop.frame_rect.size.x > 0.0, 30.0)
	t.ok("%s: the first screens are the 320x200 picture in the frame (%s)" % [game, host._backdrop.frame_rect], framed)
	var drawn: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		return host._native != null and host._native.visible, 120.0)
	t.ok("%s: the title demo is drawn by the shell's view (%s)" % [game, host._native.get_class() if host._native != null else "none"],
		drawn and host._native is GalNativeView)
	t.ok("%s: wide, the frame put away, the view %d pixels wide; the engine told %d extra tiles" % [game, host._native.view_w, host.engine.wide_tiles],
		drawn and host._native.view_w > 320 and host._backdrop.frame_rect.size == Vector2.ZERO and host.engine.wide_tiles > 0)
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 20.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
