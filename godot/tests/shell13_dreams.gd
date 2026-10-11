# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-13: Keen Dreams in the host (v1.00 and v1.93, the folders kdreams and kdreams193). It starts; its
## text-mode start screen is drawn by the shell (TextScreenView, in the frame) with the screen's words in
## it; Enter (v1.00: twice, the notice then the start screen) leads to the graphics screens (the 320x200
## picture in the frame); the player's files are kept in user://saves/kdreams; it stops when asked.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _press(host: GameHost, code: int) -> void:
	host.send_key(code, true)
	await _wait(func() -> bool: return false, 0.2)
	host.send_key(code, false)


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	root.size = Vector2i(1280, 800)
	for rel: Array in [["kdreams", "v1.00", ["notice", "start"]], ["kdreams193", "v1.93", ["start"]]]:
		await _release(root_dir, rel[0], rel[1], rel[2])
	t.finish(self)


func _text_of(view: TextScreenView) -> String:
	var s: String = ""
	for i: int in range(0, mini(view._mem.size(), 4000), 2):
		var c: int = view._mem[i]
		s += String.chr(c) if c >= 32 and c < 127 else " "
	return s


func _release(root_dir: String, folder: String, version: String, screens: Array) -> void:
	var cfg: String = OS.get_temp_dir().path_join("mr_shell13_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "kdreams", "title": "Keen Dreams", "version": version, "folder": root_dir.path_join(folder)})
	t.ok("Keen Dreams %s starts in the host (%s)" % [version, host.error], ok)
	if not ok:
		host.queue_free()
		return
	t.ok("%s: the player's files kept in %s" % [version, host.engine.user_dir], str(host.engine.user_dir).ends_with("saves/" + folder))    # J-51: each release its own
	# TIME-D: the fitted costs (godot/data/dreams_costs.json) reach the game and the machine in play
	var cst: Dictionary = host.engine.costs
	t.ok("%s: TIME-D's costs in play (grbyte %d, mmscan %d, the timer's phase %d)" % [version, cst.get("grbyte", 0), cst.get("mmscan", 0), host.vm.timer_offset],
		int(cst.get("grbyte", 0)) == 4847 and int(cst.get("mmscan", 0)) == (1833 if version.contains("1.93") else 1362) and host.vm.timer_offset == 4500000)
	# (the start screen with its key prompt: with TIME-D's costs the loading text before it stays up a while)
	var text: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		var w: String = _text_of(host._text_view) if host._text_view.visible else ""
		return w.contains("Press") or w.contains("ENTER"), 30.0)
	var words: String = _text_of(host._text_view)
	t.ok("%s: the text start screen drawn by the shell, in the frame (%s...)" % [version, words.strip_edges().substr(0, 40)],
		text and host._backdrop.frame_rect.size.x > 0.0 and (words.contains("Press") or words.contains("ENTER")))
	for s: String in screens:
		await _wait(func() -> bool: return false, 1.5)
		await _press(host, 0x1C)
	var ega: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		return host._view.visible and not host._text_view.visible and host.vm.card.video_mode == EgaCard.MODE_EGA, 30.0)
	t.ok("%s: Enter leads to the graphics screens (the 320x200 picture in the frame)" % version, ega)
	host.stop()
	var stopped: bool = await _wait(func() -> bool: return host.thread == null, 20.0)
	t.ok("%s: it stops when asked (quit '%s')" % [version, host._quit_message], stopped)
	host.queue_free()
	for i: int in range(5):
		await process_frame
	DirAccess.remove_absolute(cfg)
