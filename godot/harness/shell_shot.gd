# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## A screenshot of the program as the player sees it (for reviewing the shell's look): opens the main
## scene in a window of the given size, lets it run (the scan, the title art) for `wait` seconds,
## optionally sends a few keys, and saves the window's picture.
##
##   godot --path godot --script res://harness/shell_shot.gd -- --out=<png> [--size=1280x720]
##         [--wait=6] [--keys=ui_right,ui_right] [--scale=1]
## (tools/shell_shot.py runs it.)

var _out: String = ""
var _wait: float = 6.0
var _keys: PackedStringArray = PackedStringArray()


func _init() -> void:
	var opts: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_out = str(opts.get("out", "user://shot.png"))
	_wait = float(opts.get("wait", "6"))
	_keys = str(opts.get("keys", "")).split(",", false)
	var size: PackedStringArray = str(opts.get("size", "1280x720")).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	root.size = Vector2i(int(size[0]), int(size[1]))
	var main: Node = load("res://shell/main.tscn").instantiate()
	root.add_child.call_deferred(main)
	_run.call_deferred()


func _run() -> void:
	await create_timer(_wait).timeout
	for k: String in _keys:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = k
		ev.pressed = true
		Input.parse_input_event(ev)
		await process_frame
		var up: InputEventAction = InputEventAction.new()
		up.action = k
		up.pressed = false
		Input.parse_input_event(up)
		await create_timer(0.3).timeout
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	print("shot: ", _out, " ", img.get_size())
	quit()
