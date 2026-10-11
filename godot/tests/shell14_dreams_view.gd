# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-14: Keen Dreams in the host with the default settings (Enhanced: native resolution, smooth motion,
## the wide view), v1.00 and v1.93. Each release starts; its text start screens are drawn by the shell in
## the frame; Enter leads to the title (v1.93's picture, v1.00's title map with its credits), which is the
## 320x200 picture in the frame over the game's backdrop (a screen, never widened); started straight into a
## level (the maker's play_level, HARN-23's warp), the play is drawn by the shell's view (DrmNativeView) as
## wide as the window allows, the frame put away, the engine told the wide view's extra tiles. The Options
## model's Display page shows the View, Native resolution and Smooth motion rows for Dreams.
##
## Options: --game_data=<folder> [--releases=kdreams,kdreams193]

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
	root.size = Vector2i(1600, 900)
	var ran: int = 0
	for folder: String in str(T.options().get("releases", "kdreams,kdreams193")).split(",", false):
		if not DirAccess.dir_exists_absolute(root_dir.path_join(folder)):
			print("  %s: not present, skipped" % folder)
			continue
		ran += 1
		await _title(root_dir, folder)
		await _level(root_dir, folder)
	if ran == 0:
		t.blocked("no Keen Dreams release under " + root_dir)
	t.finish(self)


func _host(root_dir: String, folder: String, cfg: String, level: int) -> GameHost:
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 4.0
	root.add_child(host)
	var found: Dictionary = {"id": "kdreams", "title": "Keen Dreams", "folder": root_dir.path_join(folder)}
	if level >= 0:
		found["play_level"] = level
	var ok: bool = host.start(found)
	t.ok("%s starts in the host (%s)" % [folder, host.error], ok)
	return host if ok else null


func _text_of(view: TextScreenView) -> String:
	var s: String = ""
	for i: int in range(0, mini(view._mem.size(), 4000), 2):
		var c: int = view._mem[i]
		s += String.chr(c) if c >= 32 and c < 127 else " "
	return s


## Past the text screens: Enter on each (v1.00's notice, then "Press a Key"; with a warp the notice is
## skipped), each press once its screen shows and only while the screen is still in text mode (a key
## reaching the title would open the panel).
func _past_text(host: GameHost, presses: int) -> bool:
	var text: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		return host._text_view.visible and _text_of(host._text_view).strip_edges() != "", 30.0)
	for i: int in range(presses):
		var last: String = _text_of(host._text_view)
		await _wait(func() -> bool: return false, 1.0)
		if host.vm == null or host.vm.card.video_mode == EgaCard.MODE_EGA:
			break
		await _press(host, 0x1C)
		# the next screen (its words differ), or the graphics
		await _wait(func() -> bool:
			if host.paused:
				host.set_paused(false)
			return host.vm == null or host.vm.card.video_mode == EgaCard.MODE_EGA or _text_of(host._text_view) != last, 15.0)
	return text


func _stop(host: GameHost, cfg: String) -> void:
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 20.0)
	host.queue_free()
	for i: int in range(5):
		await process_frame
	DirAccess.remove_absolute(cfg)


## The title: the 320x200 picture in the frame, the view put away.
func _title(root_dir: String, folder: String) -> void:
	var cfg: String = OS.get_temp_dir().path_join("mr_shell14_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = _host(root_dir, folder, cfg, -1)
	if host == null:
		return
	var rows: Array = host.options.page("display").map(func(r: Dictionary) -> String: return r.label)
	t.ok("%s: the Display page shows View, Native resolution and Smooth motion (%s)" % [folder, rows],
		rows.slice(0, 3) == ["View", "Native resolution", "Smooth motion"])
	t.ok("%s: the shell's view for Dreams is DrmNativeView" % folder, host._native is DrmNativeView)
	var text: bool = await _past_text(host, 2 if folder == "kdreams" else 1)
	t.ok("%s: the text start screen drawn by the shell" % folder, text)
	var framed: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		return host.vm != null and host.vm.card.video_mode == EgaCard.MODE_EGA and host.frames_shown > 10 \
			and host._view.visible and host._backdrop.frame_rect.size.x > 0.0, 60.0)
	# a few more pictures of it: the title stays framed (v1.00's title map is a screen, not the play)
	var stayed: bool = framed
	var went: String = ""
	for i: int in range(60):
		await process_frame
		if host.paused:
			host.set_paused(false)
		if host._native.visible or not host._view.visible:
			stayed = false
			host._mutex.lock()
			went = "map %s play %s" % [host._frame_list.get("map"), host._frame_list.get("play")]
			host._mutex.unlock()
	t.ok("%s: the title is the 320x200 picture in the frame (%s), the view put away%s" % [folder, host._backdrop.frame_rect,
		"" if went == "" else " (went to the view: " + went + ")"], framed and stayed)
	await _stop(host, cfg)


## A level: drawn by the shell's view, wide, the frame put away, the engine told its extra tiles.
func _level(root_dir: String, folder: String) -> void:
	var cfg: String = OS.get_temp_dir().path_join("mr_shell14_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = _host(root_dir, folder, cfg, 1)
	if host == null:
		return
	await _past_text(host, 1)
	var drawn: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		return host._native != null and host._native.visible, 120.0)
	t.ok("%s: level 1 is drawn by the shell's view (%s)" % [folder, host._native.get_class() if host._native != null else "none"],
		drawn and host._native is DrmNativeView)
	t.ok("%s: wide, the frame put away, the view %d pixels wide; the engine told %d extra tiles, its lists kept" % [folder, host._native.view_w, host.engine.wide_tiles],
		drawn and host._native.view_w > 320 and host._backdrop.frame_rect.size == Vector2.ZERO and host.engine.wide_tiles > 0 and host.engine.draw_capture)
	# a few more pictures: the play stays on the view
	var stayed: bool = drawn
	for i: int in range(60):
		await process_frame
		if host.paused:
			host.set_paused(false)
		if not host._native.visible:
			stayed = false
	t.ok("%s: the play stays on the view" % folder, stayed)
	# F1: the panel ("Loading", then the panel itself): a screen, the 320x200 picture back in the frame
	await _press(host, 0x3B)
	var panel: bool = await _wait(func() -> bool:
		if host.paused:
			host.set_paused(false)
		return host._view.visible and not host._native.visible and host._backdrop.frame_rect.size.x > 0.0, 20.0)
	t.ok("%s: the panel over the level is the 320x200 picture in the frame (%s)" % [folder, host._backdrop.frame_rect], panel)
	await _stop(host, cfg)
