# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Keen Maker, for review: its screens in a window, saved as PNGs (outside the repository: they hold the
## game's tiles): the game picker; a game's library; a new level in the editor with a row of ground and a
## creature placed, a block of ground brushed; the whole level zoomed out; the menu; Keen 1 and Keen Dreams' editors; a remix.
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


func _editor(m: MakerScreen, game: String, name: String) -> void:
	m.open_game(game)
	await _frames(5)
	m.new_level()
	await _frames(10)
	var v: MakerView = m.view
	var s: Vector2i = m.model.start_at()
	# a ledge of the palette's first ground part over Keen, and the first creature to his right
	m.palette.show_category(0)
	m.model.fill_rect(m.palette.part()[0], s + Vector2i(3, -4), s + Vector2i(9, -4), m.palette.part()[1])
	# a block of ground with the ground brush (its edges chosen as the game's levels have them)
	for y: int in range(s.y - 9, s.y - 6):
		for x: int in range(s.x + 10, s.x + 17):
			m.model.brush_at(x, y, true)
	for i: int in range(m.model.parts.categories.size()):
		if m.model.parts.categories[i].name == MakerParts.ENEMIES:
			m.palette.show_category(i)
	m.model.paint(m.palette.part()[0], s.x + 6, s.y, m.palette.part()[1])
	v.set_cursor(s + Vector2i(6, -5))
	m._refresh()
	await _frames(10)
	_shot(name)


func _run() -> void:
	await process_frame
	var m: MakerScreen = MakerScreen.new()
	m.roots = PackedStringArray([str(_opts.get("game_data", ""))])
	root.add_child(m)
	await _frames(20)
	_shot("games")
	var game: String = str(_opts.get("game", "keen4"))
	m.open_game(game)
	await _frames(10)
	_shot("library")
	await _editor(m, game, "editor")
	m.toggle_whole()
	await _frames(5)
	_shot("whole")
	m.toggle_whole()
	m.open_menu()
	await _frames(5)
	_shot("menu")
	m.close_dialog()
	await _editor(m, "keen1", "keen1")
	await _editor(m, "kdreams", "kdreams")
	m.open_game(game)
	m.remix(int(_opts.get("remix", "1")))
	await _frames(10)
	_shot("remix")
	quit(0)
