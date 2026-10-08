# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## AND-02's core, on the desktop with a plain-folder source (the Android
## source, SafSource, reads a picked folder through Android's own APIs and is
## checked on the emulator): from a folder holding Keen 1 loose, a Keen 4
## with one file damaged, a SHELL-10 export ZIP of Keen 3 and an export
## manifest naming Keen 2 too, the importer brings in Keen 1 and Keen 3 whole
## and verified, refuses Keen 4 with the file named, reports Keen 2 as listed
## but missing; copies that fail are retried (and a file that never copies is
## reported); progress counts every file copied; importing again replaces,
## never duplicates; the source folder is unchanged; the launcher scans the
## imported games and its import page shows each game's result.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _tree_hashes(dir: String) -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		out[f] = GameFinder.sha256(FileAccess.get_file_as_bytes(dir.path_join(f)))
	for sub: String in d.get_directories():
		var h: Dictionary = _tree_hashes(dir.path_join(sub))
		for k: String in h:
			out[sub + "/" + k] = h[k]
	return out


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for f: String in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))


func _go() -> void:
	var data: String = T.options().get("game_data", "")
	if data == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var base: String = OS.get_temp_dir().path_join("mr_and02_%d" % Time.get_ticks_usec())
	var src: String = base.path_join("phone")
	_copy_dir(data.path_join("keen1"), src.path_join("Keen1"))
	_copy_dir(data.path_join("keen4"), src.path_join("Stuff/Keen4"))
	var maps: String = src.path_join("Stuff/Keen4/GAMEMAPS.CK4")
	var b: PackedByteArray = FileAccess.get_file_as_bytes(maps)
	b[1000] = b[1000] ^ 0xFF
	var f: FileAccess = FileAccess.open(maps, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()
	# a SHELL-10 export of Keen 3 as a ZIP, and an export manifest naming Keen 2 as well
	var finder: GameFinder = GameFinder.new()
	var k3: Array = finder.scan_folder(data.path_join("keen3"), 0)
	var ex: GameExporter = GameExporter.new()
	ex.export_zip(k3, src.path_join("Megarocket Games.zip"))
	f = FileAccess.open(src.path_join(GameImporter.MANIFEST), FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": 1, "games": [{"id": "keen2"}, {"id": "keen3"}]}))
	f.close()
	var before: Dictionary = _tree_hashes(src)

	var imp: GameImporter = GameImporter.new()
	imp.games_root = base.path_join("app/games")
	imp.staging_root = base.path_join("app/import_staging")
	var steps: Array = [0, 0]
	imp.progress = func(_what: String, done: int, total: int) -> void:
		steps[0] = done
		steps[1] = total
	var source: GameImporter.FolderSource = GameImporter.FolderSource.new(src)
	source.fail_first = {"KEEN1.EXE": 2}    # two failed copies, then it comes
	var results: Array = imp.import_from(source)
	var by: Dictionary = {}
	for r: Dictionary in results:
		by[r.id] = r
		print("  result: ", r.message)
	t.ok("Keen 1 imported whole (%s)" % by.get("keen1", {}).get("message", "none"), by.has("keen1") and by.keen1.ok and by.keen1.files == 31)
	t.ok("Keen 3 imported from the export ZIP", by.has("keen3") and by.keen3.ok)
	t.ok("Keen 4 refused, the damaged file named", by.has("keen4") and not by.keen4.ok and String(by.keen4.message).contains("GAMEMAPS.CK4"))
	t.ok("Keen 2, listed in the export but absent, reported", by.has("keen2") and not by.keen2.ok and String(by.keen2.message).contains("listed in the export"))
	for r: Dictionary in results:
		if not r.ok:
			t.ok("a refusal says what to do next: %s" % r.message, ShellMessages.has_next_step(r.message))
	t.ok("failed copies were retried (%d)" % imp.copies_retried, imp.copies_retried == 2)
	t.ok("progress counted every file copied (%d of %d)" % steps, steps[1] > 31 and steps[0] == steps[1])
	var imported: Array = finder.scan_folder(imp.games_root, 1)
	var ok_ids: Array = []
	for r: Dictionary in imported:
		if r.status == GameFinder.STATUS_OK:
			ok_ids.append(r.id)
	ok_ids.sort()
	t.ok("the app's storage holds Keen 1 and Keen 3, verified (%s)" % str(ok_ids), ok_ids == ["keen1", "keen3"])
	t.ok("the staging folder is gone", not DirAccess.dir_exists_absolute(imp.staging_root))
	t.ok("the source folder is unchanged", _tree_hashes(src) == before)
	# again: replaced, not duplicated
	results = imp.import_from(GameImporter.FolderSource.new(src))
	var dirs: PackedStringArray = DirAccess.get_directories_at(imp.games_root)
	t.ok("importing again replaces (folders %s)" % str(dirs), Array(dirs) == ["keen1", "keen3"] and DirAccess.get_files_at(imp.games_root.path_join("keen1")).size() == 31)
	# a file that never copies is reported, and its game not imported
	var s2: GameImporter.FolderSource = GameImporter.FolderSource.new(src)
	s2.fail_first = {"LEVEL01.CK1": 99}
	var imp2: GameImporter = GameImporter.new()
	imp2.games_root = base.path_join("app2/games")
	imp2.staging_root = base.path_join("app2/import_staging")
	var r2: Array = imp2.import_from(s2)
	var reported: bool = false
	var k1_ok: bool = false
	for r: Dictionary in r2:
		if String(r.message).contains("could not be copied") and String(r.message).contains("LEVEL01.CK1"):
			reported = true
		if r.id == "keen1" and r.ok:
			k1_ok = true
	t.ok("a file that never copies is reported and its game left out", reported and not k1_ok)
	# nothing there
	var empty: String = base.path_join("empty")
	DirAccess.make_dir_recursive_absolute(empty)
	var r3: Array = GameImporter.new().import_from(GameImporter.FolderSource.new(empty))
	t.ok("an empty folder: one result saying so, with a next step", r3.size() == 1 and not r3[0].ok and ShellMessages.has_next_step(r3[0].message))
	# the launcher: scans the imported games; the import page shows the results
	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = base.path_join("lock")
	l.settings_path = base.path_join("settings.cfg")
	l.imported_games_root = base.path_join("app3/games")
	root.add_child(l)
	await process_frame
	t.ok("no imported games yet: not scanned", not l.scan_roots().has(l.imported_games_root))
	l.import_games(GameImporter.FolderSource.new(src.path_join("Keen1")))
	var until: int = Time.get_ticks_msec() + 30000
	while l._import_thread != null and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	var page_text: String = l._import_label.text if l._import_label != null else ""
	t.ok("the import page shows the result (%s)" % page_text.left(60), l.import_page != null and page_text.begins_with("Imported: ") and
		l.import_page.find_child("Done", true, false) != null)
	t.ok("the imported games are scanned from then on", l.scan_roots().has(l.imported_games_root))
	l.close_import()
	await process_frame
	t.ok("Done closes the page", l.import_page == null and l._page.visible)
	l.queue_free()
	await process_frame
	GameImporter._remove_tree(base)
	t.finish(self)
