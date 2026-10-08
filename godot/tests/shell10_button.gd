# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-10 on the launcher: the Export for Android button is off with no game
## found and on with one or all; Enter on it (keyboard or a pad's A) opens
## the export page, whose first choice has the focus; exporting the seven
## development copies to a folder shows each game's progress and result and
## the folder checks against its manifest; as a ZIP, every game is in it;
## Done (Enter) closes the page.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _accept() -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	root.push_input(ev)
	var up: InputEventAction = InputEventAction.new()
	up.action = "ui_accept"
	up.pressed = false
	root.push_input(up)


func _wait_export(l: Launcher) -> void:
	var until: int = Time.get_ticks_msec() + 120000
	while l._export_thread != null and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame


func _go() -> void:
	var data: String = T.options().get("game_data", "")
	if data == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var base: String = OS.get_temp_dir().path_join("mr_shell10_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(base)
	root.size = Vector2i(1280, 720)
	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = base.path_join("lock")
	l.settings_path = base.path_join("settings.cfg")
	root.add_child(l)
	await process_frame
	t.ok("no game found: the button is off", l.export_button != null and l.export_button.visible and l.export_button.disabled)
	var finder: GameFinder = GameFinder.new()
	var all: Array = []
	for id: String in ["keen1", "keen2", "keen3", "keen4", "keen5", "keen6", "kdreams"]:
		all.append_array(finder.scan_folder(data.path_join(id), 1))
	var k1: Array = all.filter(func(r: Dictionary) -> bool: return r.id == "keen1")
	l.show_results(k1)
	t.ok("one game found: the button is on", not l.export_button.disabled)
	l.show_results(all)
	t.ok("all seven found: on (%d exportable)" % GameExporter.exportable(l.found_results.values()).size(),
		not l.export_button.disabled and GameExporter.exportable(l.found_results.values()).size() == 7)
	# Enter on the button opens the page, its first choice focused
	l.export_button.grab_focus()
	await process_frame
	_accept()
	await process_frame
	await process_frame
	var focus: Control = root.gui_get_focus_owner()
	t.ok("Enter on the button opens the export page, \"To a folder\" focused (%s)" % (focus.name if focus != null else "none"),
		l.export_page != null and focus != null and focus.name == "ToFolder")
	# to a folder
	var dest: String = base.path_join("out")
	DirAccess.make_dir_recursive_absolute(dest)
	l.export_games(dest, false)
	await _wait_export(l)
	var oks: int = 0
	for r: Dictionary in l.export_results:
		if r.ok:
			oks += 1
	t.ok("each game's progress was shown (%s)" % str(l.export_progress), l.export_progress.size() == 7)
	t.ok("each game's result is on the page (%d exported)" % oks, oks == 7 and l._export_label.text.count("Exported: ") == 7)
	var chk: Dictionary = GameExporter.check_export(dest)
	t.ok("the folder checks against its manifest (%d games)" % chk.games.size(), chk.ok and chk.games.size() == 7)
	t.ok("the page ends with where it is and what to do next", ShellMessages.has_next_step(l._export_label.text))
	focus = root.gui_get_focus_owner()
	t.ok("Done has the focus", focus != null and focus.name == "Done")
	_accept()
	await process_frame
	await process_frame
	t.ok("Enter on Done closes the page", l.export_page == null and l._page.visible)
	# as a ZIP
	var zip: String = base.path_join("Megarocket Games.zip")
	l.export_games(zip, true)
	await _wait_export(l)
	var in_zip: Array = finder.identify_zip(zip).filter(func(r: Dictionary) -> bool: return r.status == GameFinder.STATUS_OK)
	t.ok("as a ZIP: every game in it (%d)" % in_zip.size(), in_zip.size() == 7)
	l.close_export()
	l.queue_free()
	await process_frame
	GameImporter._remove_tree(base)
	t.finish(self)
