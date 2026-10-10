# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-03, for review: the maker's screen in a window, saved as PNGs: as it opens (the first game and
## its level 1), then the chosen game (--game=keen4) with a row of tiles painted, the foreground plane, the
## markers' plane; then Play (the level with the edits) and back.
##
##   godot --path godot --script res://harness/maker_shot.gd -- --game_data=<folder> --out=<png>
##         [--game=keen4] [--size=1600x900]

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var size: PackedStringArray = str(_opts.get("size", "1600x900")).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	root.size = Vector2i(int(size[0]), int(size[1]))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _shot(name: String) -> void:
	var out: String = str(_opts.get("out", "user://maker.png")).get_basename() + "_" + name + ".png"
	root.get_texture().get_image().save_png(out)
	print("shot: ", out)


func _run() -> void:
	await process_frame
	var m: MakerScreen = MakerScreen.new()
	m.roots = PackedStringArray([str(_opts.get("game_data", ""))])
	root.add_child(m)
	await _frames(30)
	_shot("open")
	var game: String = str(_opts.get("game", "keen4"))
	for i: int in range(m.found.size()):
		if m.found[i].id == game:
			m._games.select(i)
			m._on_game(i)
	await _frames(10)
	# a row of the palette's 10th tile painted above Keen
	var s: Vector2i = m.model.start_at()
	m._set_value(10)
	m.model.begin_stroke()
	for x: int in range(s.x - 3, s.x + 4):
		m.model.paint(0, x, s.y - 3, 10)
	m.model.end_stroke()
	m.view.queue_redraw()
	m._refresh()
	await _frames(10)
	_shot("painted")
	m._on_plane(1)
	await _frames(10)
	_shot("foreground")
	m._on_plane(m.model.plane_names().size() - 1)
	await _frames(10)
	_shot("markers")
	# Play: straight into the level with the edits, then back when it ends
	m._on_play()
	for i: int in range(240):
		await process_frame
		if m.host != null and m.host.paused:
			m.host.set_paused(false)
	_shot("playing")
	if m.host != null:
		m.host.stop()
		for i: int in range(120):
			await process_frame
			if m.host == null:
				break
	await _frames(10)
	_shot("back")
	quit()
