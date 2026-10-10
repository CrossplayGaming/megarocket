# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-01: the program's main scene is the launcher, and it shows seven
## game tiles with the right status with no games found, some, and all; the
## tiles lie in a grid inside the window's width at a desktop size, and in one
## sideways row (the carousel, J-12) in a portrait window; the scroll area is
## inside the window either way.

var t: T = T.new()


func _init() -> void:
	t.ok("the project's main scene is the launcher", ProjectSettings.get_setting("application/run/main_scene") == "res://shell/main.tscn")
	var scene: PackedScene = load("res://shell/main.tscn")
	if not t.ok("main.tscn loads", scene != null):
		t.finish(self)
		return
	_run.call_deferred(scene)


func _run(scene: PackedScene) -> void:
	t.ok("the UI's scale: a 440 dpi phone 2.75, a 120 dpi one 1, a desktop 1",
		is_equal_approx(Launcher.scale_for(440, true), 2.75) and Launcher.scale_for(120, true) == 1.0 and Launcher.scale_for(440, false) == 1.0)
	# a desktop window, a portrait phone, a landscape phone (2340x1080 at 2.75: short)
	for win: Vector2i in [Vector2i(1280, 720), Vector2i(480, 800), Vector2i(851, 393)]:
		root.size = win
		var l: Launcher = scene.instantiate()
		l.scan_on_ready = false
		l.lock_path = OS.get_temp_dir().path_join("mr_lock_%d" % Time.get_ticks_usec())
		l.make_art = false
		l.settings_path = OS.get_temp_dir().path_join("mr_launcher_settings_%d.cfg" % Time.get_ticks_usec())
		root.add_child(l)
		await process_frame
		await process_frame
		var r: Rect2 = Rect2(Vector2.ZERO, Vector2(win))
		var cases: Array = [
			["none", []],
			["some", [{"id": "keen1", "title": "Commander Keen 1", "version": "v1.31 EGA (Steam)", "status": "ok", "folder": "C:/fixture/keen1", "message": "", "exe": "KEEN1.EXE"},
				{"id": "kdreams", "title": "Keen Dreams", "version": "Keen Dreams 2015 (Steam)", "status": "unsupported", "folder": "C:/fixture/kd", "message": "Use v1.93.", "exe": "KDREAMS.EXE"}]],
			["all", []],
		]
		for g: Array in Launcher.GAMES:
			(cases[2][1] as Array).append({"id": g[0], "title": g[1], "version": "v", "status": "ok", "folder": "C:/fixture/" + g[0], "message": "", "exe": ""})
		for c: Array in cases:
			l.show_results(c[1])
			await process_frame
			var found: int = 0
			var unsupported: int = 0
			var inside: bool = true
			for id: String in l.tiles:
				var tile: Control = l.tiles[id]
				if l.states[id] == "found":
					found += 1
				elif l.states[id] == "unsupported":
					unsupported += 1
				# wide: every tile within the window's width, scrolling down; narrow
				# (the carousel): one row, every tile on it, scrolling sideways
				var tr: Rect2 = tile.get_global_rect()
				if l.carousel:
					if absf(tr.position.y - (l.tiles["keen1"] as Control).get_global_rect().position.y) > 0.5 or tr.size.x < 50:
						inside = false
				elif tr.position.x < 0 or tr.end.x > win.x or tr.size.x < 50:
					inside = false
			if not r.encloses(l.scroll.get_global_rect()):
				inside = false
			var want: Array = {"none": [0, 0], "some": [1, 1], "all": [7, 0]}[c[0]]
			if l.carousel != (win.x != 1280):
				inside = false    # the carousel for the phones only (portrait, or too short for the grid's rows)
			t.ok("%dx%d, %s found: 7 tiles, %d found and %d unsupported (want %s), every tile inside the window (%s), summary '%s'" %
				[win.x, win.y, c[0], found, unsupported, want, inside, l.summary.text],
				l.tiles.size() == 7 and found == want[0] and unsupported == want[1] and inside)
		var missing_text: String = l._status_label(l.tiles["keen2"]).text
		l.show_results([])
		t.ok("a missing game's tile says what is looked for (%s)" % l._status_label(l.tiles["keen2"]).text.left(60),
			l._status_label(l.tiles["keen2"]).text.begins_with("Not found.") and l._status_label(l.tiles["keen2"]).text.length() > 20)
		# a chosen folder is remembered (saved at once) and scanned from then on
		var added: bool = l.add_folder("D:/Some/Keen Folder")
		var again: Settings = Settings.new(l.settings_path)
		t.ok("%dx%d: a chosen folder is saved and scanned (%s); the same folder twice is one" % [win.x, win.y, l.extra_folders],
			added and again.get_value("game_folders") == ["D:/Some/Keen Folder"] and l.extra_folders.has("D:/Some/Keen Folder") and not l.add_folder("D:/Some/Keen Folder"))
		# the how-to page opens over the tiles, says where it looks and what each game needs, and closes
		l.show_howto()
		await process_frame
		var txt: String = l.howto_text()
		var open_ok: bool = l.howto != null and not l._page.visible and txt.contains("Steam") and txt.contains("KEEN6C.EXE") and txt.contains("never changes")
		var cancel: InputEventAction = InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		l._unhandled_input(cancel)
		await process_frame
		t.ok("%dx%d: the how-to page opens (where it looks, what each game needs) and ui_cancel closes it" % [win.x, win.y],
			open_ok and l.howto == null and l._page.visible)
		# the quit box: Stay chosen first; the arrows (the pad's d-pad is the same ui_* actions) move between
		# Quit and Stay and never to the tiles behind it; Escape stays
		l.confirm_quit()
		await process_frame
		var path: Callable = func() -> String:
			var f: Control = root.gui_get_focus_owner()
			return str(f.name) if f != null and l.quit_box != null and l.quit_box.is_ancestor_of(f) else "outside"
		var seen: Array = [path.call()]
		for a: String in ["ui_left", "ui_left", "ui_up", "ui_right", "ui_down", "ui_right"]:
			var ev: InputEventAction = InputEventAction.new()
			ev.action = a
			ev.pressed = true
			root.push_input(ev)
			await process_frame
			seen.append(path.call())
		var esc: InputEventAction = InputEventAction.new()
		esc.action = "ui_cancel"
		esc.pressed = true
		l._unhandled_input(esc)
		await process_frame
		t.ok("%dx%d: the quit box keeps the keys and pad to its two buttons (%s) and Escape closes it" % [win.x, win.y, seen],
			seen == ["Stay", "Quit", "Quit", "Quit", "Stay", "Stay", "Stay"] and l.quit_box == null)
		l.queue_free()
		await process_frame
	t.finish(self)
