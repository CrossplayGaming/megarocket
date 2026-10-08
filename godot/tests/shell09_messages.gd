# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-09: every message the shell shows says what happened and ends in a
## next step (ShellMessages.has_next_step: a last sentence starting with an
## imperative). Checked on the list of messages, then in place, on fixture
## errors: a missing game, an unsupported one, a game folder with broken
## files, a game whose engine isn't ready, a game that stops with an error
## or at a part not ported yet, an unreadable settings file, an export with
## nothing to export, and another copy running. The log file is written and
## the launcher shows its path.

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _check(label: String, text: String) -> void:
	t.ok("%s has a next step: %s" % [label, text.replace("\n", " / ")], ShellMessages.has_next_step(text))


func _go() -> void:
	# the list
	var list: Dictionary = {
		"missing": ShellMessages.missing("Looks for KEEN1.EXE v1.31 EGA (Steam)."),
		"not run": ShellMessages.not_run("v1.0 CGA", "Megarocket reads the EGA release."),
		"can't load": ShellMessages.cant_load("Commander Keen 4", "EGAGRAPH: chunk 3 claims 9999 bytes"),
		"not ready": ShellMessages.not_ready("Keen Dreams"),
		"stopped, not ported": ShellMessages.game_stopped("Commander Keen 5", "not ported yet: CK5_SpawnX"),
		"stopped, the game's error": ShellMessages.game_stopped("Commander Keen 4", "CA_CacheMap: Tried to load a non-existant map!"),
		"already running": ShellMessages.already_running(),
		"settings reset": ShellMessages.settings_reset("settings.cfg", "Parse error"),
		"settings not saved": ShellMessages.settings_not_saved("settings.cfg"),
		"nothing to export": ShellMessages.nothing_to_export(),
		"cannot create": ShellMessages.cannot_create("D:/Out"),
		"no space": ShellMessages.no_space("D:/", 12.5),
	}
	for k: String in list:
		_check(k, list[k])
	t.ok("a sentence without an imperative is caught", not ShellMessages.has_next_step("The game stopped: something.") and
		not ShellMessages.has_next_step("Not found. Looks for KEEN1.EXE."))

	var dir: String = OS.get_temp_dir().path_join("mr_msgs_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir.path_join("broken4"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("broken1"))
	# an unreadable settings file
	var sp: String = dir.path_join("settings.cfg")
	var f: FileAccess = FileAccess.open(sp, FileAccess.WRITE)
	f.store_string("this is { not a settings file\n")
	f.close()

	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = dir.path_join("lock")
	l.settings_path = sp
	root.add_child(l)
	await process_frame
	# a missing game on every tile, Keen 6 found but unsupported
	l.show_results([{"id": "keen6", "title": "Commander Keen 6: Aliens Ate My Baby Sitter!", "version": "v1.5 CGA", "status": GameFinder.STATUS_UNSUPPORTED,
		"folder": dir, "message": "v1.5 CGA: not supported. " + KnownFiles.REMEDY["keen6"], "exe": "KEEN6C.EXE"}])
	for g: Array in Launcher.GAMES:
		_check("the %s tile" % g[0], l._status_label(l.tiles[g[0]]).text)
	t.ok("the unreadable settings file is reported on the launcher", l.summary.text.contains("settings.cfg"))
	_check("the launcher's line above the tiles", l.summary.text)

	# a found game whose files are broken, and one whose engine isn't ready
	l.found_results["keen4"] = {"id": "keen4", "title": "Commander Keen 4: Secret of the Oracle", "version": "v1.4 EGA (Steam)", "folder": dir.path_join("broken4"), "status": "ok"}
	l.found_results["keen1"] = {"id": "keen1", "title": "Commander Keen 1: Marooned on Mars", "version": "v1.31 EGA (Steam)", "folder": dir.path_join("broken1"), "status": "ok"}
	l.found_results["kdreams"] = {"id": "kdreams", "title": "Keen Dreams", "version": "EGA v1.93", "folder": dir, "status": "ok"}
	for id: String in ["keen4", "keen1", "kdreams"]:
		l.states[id] = "found"
		var started: bool = l.launch(id)
		var text: String = l._status_label(l.tiles[id]).text
		t.ok("%s does not start from a broken or unready folder" % id, not started and l.host == null)
		_check("%s's can't-start message" % id, text)
	t.ok("a load failure names the log", l._status_label(l.tiles["keen4"]).text.contains(ShellMessages.log_path()))

	# a game that stops with an error, and one that reaches an unported part
	for pair: Array in [["keen4", "CA_CacheMap: Tried to load a non-existant map!"], ["keen5", "not ported yet: CK5_SpawnX"]]:
		l.host = GameHost.new()
		l.add_child(l.host)
		l._on_game_finished(pair[1], pair[0])
		_check("%s stopping (%s)" % pair, l._status_label(l.tiles[pair[0]]).text)

	# exporting nothing
	var ex: GameExporter = GameExporter.new()
	ex.export_folder([], dir.path_join("out"))
	_check("an export with nothing to export", ex.error)

	# the log: shown on the launcher, and written
	t.ok("the launcher shows the log's path (%s)" % ShellMessages.log_path(), l.log_label != null and l.log_label.visible and l.log_label.text.contains(ShellMessages.log_path()))
	t.ok("file logging is on for every platform", bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging")) and
		bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging.pc")))
	t.ok("the log file exists", FileAccess.file_exists(ShellMessages.log_path()))
	l.queue_free()
	await process_frame

	# another copy running
	var other: int = OS.create_process("ping", ["-n", "30", "127.0.0.1"])
	f = FileAccess.open(dir.path_join("lock2"), FileAccess.WRITE)
	f.store_string(str(other))
	f.close()
	var l2: Launcher = load("res://shell/main.tscn").instantiate()
	l2.scan_on_ready = false
	l2.make_art = false
	l2.lock_path = dir.path_join("lock2")
	l2.settings_path = dir.path_join("settings2.cfg")
	root.add_child(l2)
	await process_frame
	await process_frame
	var wait_text: String = (l2._wait_panel.get_child(0) as Label).text if l2._wait_panel != null else ""
	_check("another copy running", wait_text)
	OS.kill(other)
	l2.queue_free()
	await process_frame
	t.finish(self)
