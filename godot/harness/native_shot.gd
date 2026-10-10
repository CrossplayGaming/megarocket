# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-02, for review: Keen 1 played in a window from the host (the title, New Game, the world map),
## with native resolution on or off, and the window's picture saved: the same moment drawn from the
## draw list at the window's size, or the 320x200 scaled.
##
##   godot --path godot --script res://harness/native_shot.gd -- --game_data=<folder> --out=<png>
##         [--native=on|off] [--smooth=on|off] [--size=1280x800] [--game=keen1] [--wait=8]
##         [--tour: also the intro, the lives window, the map and level 1 as <out>_<name>.png]
##         [--frames=N: hold an arrow (--walk=4d, a scan code in hex) and save N frames as <out>_<n>.png]
##         [--gtour: Keen 4-6's new game, the world map, walking right, as <out>_gmap / _gwalk<n>.png]
##         [--attract=N: no keys, N shots of the title's demos (Keen 4-6) every --every=3 seconds]

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
	s.set_value("smooth_motion", str(_opts.get("smooth", "on")) == "on", game)
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
	var attract: int = int(_opts.get("attract", "0"))
	if attract > 0:
		# no keys: the title's own demos (Keen 4-6), a shot every --every seconds
		for n: int in range(attract):
			await _hold(float(_opts.get("every", "3")))
			_shot(str(_opts.get("out", "")).get_basename() + "_attract%02d.png" % n)
			print("  native view shown: ", host._native != null and host._native.visible)
		host.stop()
		await create_timer(0.5).timeout
		DirAccess.remove_absolute(cfg)
		quit()
		return
	if _opts.has("gtour"):
		# Keen 4-6: the title's menu, NEW GAME, the difficulty card's choice; the world map, walking right
		await _hold(float(_opts.get("wait", "8")))
		for i: int in range(int(_opts.get("enters", "4"))):
			await _press(host, 0x1C)
		await _hold(5.0)
		_shot(str(_opts.get("out", "")).get_basename() + "_gmap.png")
		host.send_key(0x4D, true)
		for n: int in range(4):
			await _hold(0.6)
			_shot(str(_opts.get("out", "")).get_basename() + "_gwalk%d.png" % n)
		host.send_key(0x4D, false)
		if _opts.has("bat"):
			# B+A+T: the item cheat's window over the play
			for code: int in [0x30, 0x1E, 0x14]:
				host.send_key(code, true)
			await _hold(0.15)
			for code: int in [0x30, 0x1E, 0x14]:
				host.send_key(code, false)
			await _hold(0.8)
			_shot(str(_opts.get("out", "")).get_basename() + "_gbat.png")
			_card_shot(host, str(_opts.get("out", "")).get_basename() + "_gbat_card.png")
			var nv: VortNativeView = host._native
			var r: Rect2i = VortNativeView.list_overlay(nv._list)
			var dark: int = 0
			for y: int in range(r.position.y, r.end.y):
				for x: int in range(r.position.x, r.end.x):
					if nv._card.size() == 64000 and nv._card[y * 320 + x] != 15:
						dark += 1
			print("  view's list overlay ", r, " t ", nv._list.get("t"), " card bytes ", nv._card.size(), " non-white in rect ", dark)
			for code: int in [0x30, 0x1E, 0x14]:
				host.send_key(code, false)
			await _hold(0.5)
		print("  native view shown: ", host._native != null and host._native.visible)
		host.stop()
		await create_timer(0.5).timeout
		DirAccess.remove_absolute(cfg)
		quit()
		return
	var tour: bool = _opts.has("tour")
	if tour:
		await _hold(3.0)
		_shot(str(_opts.get("out", "")).get_basename() + "_intro.png")
	await _hold(float(_opts.get("wait", "8")) - (3.0 if tour else 0.0))
	await _press(host, 0x1C)    # to the title menu
	await _press(host, 0x1C)    # New Game
	if tour:
		for n: int in range(10):
			await _hold(0.2)
			_shot(str(_opts.get("out", "")).get_basename() + "_lives%d.png" % n)
		await _hold(2.0)
	else:
		await _hold(4.0)
	await _press(host, 0x1C)    # past the lives window
	await _hold(2.0)
	if tour:
		_shot(str(_opts.get("out", "")).get_basename() + "_map.png")
		# F3, Cheats... (row 6), Level select... (row 11), Level 1
		await _press(host, 0x3D)
		_shot(str(_opts.get("out", "")).get_basename() + "_menu.png")
		for i: int in range(5):
			await _press(host, 0x50)
		await _press(host, 0x1C)
		for i: int in range(10):
			await _press(host, 0x50)
		await _press(host, 0x1C)
		await _press(host, 0x1C)
		await _hold(4.0)
		_shot(str(_opts.get("out", "")).get_basename() + "_level.png")
	var out: String = str(_opts.get("out", "user://native.png"))
	var frames: int = int(_opts.get("frames", "0"))
	if frames > 0:
		# a walk: the arrow held, each frame the window shows saved as <out>_<n>.png
		var walk: int = str(_opts.get("walk", "4d")).hex_to_int()    # the arrow held (scan code)
		host.send_key(walk, true)
		await _hold(0.3)
		for n: int in range(frames):
			await process_frame
			if host.paused:
				host.set_paused(false)
			root.get_texture().get_image().save_png(out.get_basename() + "_%03d.png" % n)
		host.send_key(walk, false)
	else:
		var img: Image = root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	print("shot: ", out, " native view shown: ", host._native != null and host._native.visible)
	host.stop() if host.has_method("stop") else null
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(cfg)
	quit()


func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("shot: ", path)


## The card's picture the host has now (its 320x200 indices through its palette).
func _card_shot(host: GameHost, path: String) -> void:
	host._mutex.lock()
	var idx: PackedByteArray = host._frame_indices
	var pal: PackedByteArray = host._frame_palette
	host._mutex.unlock()
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(320 * 200 * 3)
	for i: int in range(320 * 200):
		rgb[i * 3] = pal[idx[i] * 3]
		rgb[i * 3 + 1] = pal[idx[i] * 3 + 1]
		rgb[i * 3 + 2] = pal[idx[i] * 3 + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(path)
	print("shot: ", path)
