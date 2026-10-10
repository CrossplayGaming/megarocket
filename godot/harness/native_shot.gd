# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-02, for review: Keen 1 played in a window from the host (the title, New Game, the world map),
## with native resolution on or off, and the window's picture saved: the same moment drawn from the
## draw list at the window's size, or the 320x200 scaled.
##
##   godot --path godot --script res://harness/native_shot.gd -- --game_data=<folder> --out=<png>
##         [--native=on|off] [--size=1280x800] [--game=keen1] [--wait=8]

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var size: PackedStringArray = str(_opts.get("size", "1280x800")).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	root.size = Vector2i(int(size[0]), int(size[1]))
	_run.call_deferred()


var _host: GameHost = null


## Waits, keeping the game going: a window without focus pauses it (SHELL-06), and this one is
## usually not in front.
func _hold(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if _host != null and _host.paused:
			_host.set_paused(false)
		await process_frame


func _press(host: GameHost, code: int) -> void:
	host.send_key(code, true)
	await _hold(0.15)
	host.send_key(code, false)
	await _hold(1.2)


func _run() -> void:
	await process_frame    # the root is free to take children
	var game: String = str(_opts.get("game", "keen1"))
	var cfg: String = OS.get_temp_dir().path_join("mr_native_shot.cfg")
	var s: Settings = Settings.new(cfg)
	s.set_value("native_resolution", str(_opts.get("native", "on")) == "on", game)
	s.save()
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	_host = host
	if not host.start({"id": game, "title": game, "folder": str(_opts.get("game_data", "")).path_join(game)}):
		print("could not start: ", host.error)
		quit(1)
		return
	await _hold(float(_opts.get("wait", "8")))
	await _press(host, 0x1C)    # to the title menu
	await _press(host, 0x1C)    # New Game
	await _hold(4.0)
	await _press(host, 0x1C)    # past the lives window
	await _hold(2.0)
	var img: Image = root.get_texture().get_image()
	var out: String = str(_opts.get("out", "user://native.png"))
	img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	print("shot: ", out, " ", img.get_size(), " native view shown: ", host._native != null and host._native.visible)
	host.stop() if host.has_method("stop") else null
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(cfg)
	quit()
