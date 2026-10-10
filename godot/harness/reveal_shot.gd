# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SECRET-02, for review: the Reveal secrets cheat in the host's own view. A game started straight in a
## level (MAKER-02's play_level), a few seconds of play, a picture with the cheat off and one with it on
## (<out>_off.png, <out>_on.png).
##
##   godot --path godot --script res://harness/reveal_shot.gd -- --game_data=<folder> --out=<png>
##         --game=keen4 --level=16 [--wait=4] [--size=1280x800] [--wide=on|off]

var _opts: Dictionary = {}
var _host: GameHost = null


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var size: PackedStringArray = str(_opts.get("size", "1280x800")).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	root.size = Vector2i(int(size[0]), int(size[1]))
	_run.call_deferred()


## Waits, keeping the game going (a window without focus pauses it, SHELL-06).
func _hold(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if _host != null and _host.paused:
			_host.set_paused(false)
		await process_frame


func _run() -> void:
	await process_frame
	var game: String = str(_opts.get("game", "keen4"))
	var cfg: String = OS.get_temp_dir().path_join("mr_reveal_shot.cfg")
	var s: Settings = Settings.new(cfg)
	s.set_value("native_resolution", true, game)
	s.set_value("wide_view", str(_opts.get("wide", "on")) == "on", game)
	s.save()
	_host = GameHost.new()
	_host.settings_path = cfg
	root.add_child(_host)
	if not _host.start({"id": game, "title": game, "folder": str(_opts.get("game_data", "")).path_join(game),
			"play_level": int(_opts.get("level", "1"))}):
		print("could not start: ", _host.error)
		quit(1)
		return
	await _hold(float(_opts.get("wait", "4")))
	var out: String = str(_opts.get("out", OS.get_temp_dir().path_join("reveal.png"))).get_basename()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	_host.engine.shell_cheat_set("reveal_secrets", false)
	await _hold(0.5)
	root.get_texture().get_image().save_png(out + "_off.png")
	_host.engine.shell_cheat_set("reveal_secrets", true)
	await _hold(0.5)
	root.get_texture().get_image().save_png(out + "_on.png")
	print("shots: %s_off.png, %s_on.png (cheat %s)" % [out, out, _host.engine.shell_cheat_get("reveal_secrets")])
	_host.stop()
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(cfg)
	quit()
