# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Keen Dreams in the host, for review: the text start screen, then Enter and the graphics screens, saved
## as PNGs every few seconds.
##
##   godot --path godot --script res://harness/dreams_shot.gd -- --game_data=<folder> --out=<png>
##         [--folder=kdreams193] [--size=1280x800] [--enters=1] [--shots=6] [--every=3]
##         [--level=N: straight into level N (the trace tool's way), no Enters]

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var size: PackedStringArray = str(_opts.get("size", "1280x800")).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	root.size = Vector2i(int(size[0]), int(size[1]))
	_run.call_deferred()


func _hold(host: GameHost, seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if host.paused:
			host.set_paused(false)
		await process_frame


func _shot(name: String) -> void:
	var out: String = str(_opts.get("out", "user://dreams.png")).get_basename() + "_" + name + ".png"
	root.get_texture().get_image().save_png(out)
	print("shot: ", out)


func _run() -> void:
	await process_frame
	var cfg: String = OS.get_temp_dir().path_join("mr_dreams_shot.cfg")
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	root.add_child(host)
	var folder: String = str(_opts.get("folder", "kdreams193"))
	var spec: Dictionary = {"id": "kdreams", "title": "Keen Dreams", "folder": str(_opts.get("game_data", "")).path_join(folder)}
	if _opts.has("level"):
		spec["play_level"] = int(_opts.level)
	if not host.start(spec):
		print("could not start: ", host.error)
		quit(1)
		return
	await _hold(host, 2.5)
	_shot("text")
	for i: int in range(int(_opts.get("enters", "1"))):
		host.send_key(0x1C, true)
		await _hold(host, 0.2)
		host.send_key(0x1C, false)
		await _hold(host, 1.5)
	for n: int in range(int(_opts.get("shots", "6"))):
		await _hold(host, float(_opts.get("every", "3")))
		_shot("after%02d" % n)
	host.stop()
	await create_timer(1.0).timeout
	DirAccess.remove_absolute(cfg)
	quit()
