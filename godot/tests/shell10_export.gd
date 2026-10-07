# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-10 (core): "Export for Android" on fixture installs built from the
## development copies of the games in a temporary folder.
##
## Options: --game_data=<folder>

var t: T = T.new()
var game_root: String = ""
var tmp: String = ""


func _init() -> void:
	game_root = T.options().get("game_data", "")
	if game_root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	tmp = OS.get_temp_dir().path_join("mr_export_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	_button_state()
	_folder_export()
	_zip_both_ways()
	_every_game()
	_remove_tree(tmp)
	t.finish(self)


# ---------------------------------------------------------------- helpers

func copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var d: DirAccess = DirAccess.open(from)
	for f: String in d.get_files():
		d.copy(from.path_join(f), to.path_join(f))


## name -> sha256 of every file under `path`, relative paths.
func tree_hashes(path: String, prefix: String = "") -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return out
	for f: String in d.get_files():
		out[prefix + f] = GameFinder.sha256(FileAccess.get_file_as_bytes(path.path_join(f)))
	for sub: String in d.get_directories():
		out.merge(tree_hashes(path.path_join(sub), prefix + sub + "/"))
	return out


func _remove_tree(path: String) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		FileAccess.set_read_only_attribute(path.path_join(f), false)
		d.remove(f)
	for sub: String in d.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func ids(results: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Dictionary in results:
		if r.get("status", "ok") == GameFinder.STATUS_OK and r.get("ok", true):
			out.append(r.id)
	out.sort()
	return out


func set_files(id: String) -> PackedStringArray:
	for s: Dictionary in KnownFiles.SETS:
		if s.id == id:
			var names: PackedStringArray = PackedStringArray(s.files.keys())
			names.sort()
			return names
	return PackedStringArray()


# ------------------------------------------------------------------ checks

func _button_state() -> void:
	var finder: GameFinder = GameFinder.new()
	t.ok("the button is off with no games found", not GameExporter.can_export([]))
	var odd: String = tmp.path_join("odd")
	DirAccess.make_dir_recursive_absolute(odd)
	var f: FileAccess = FileAccess.open(odd.path_join("KEEN4E.EXE"), FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3]))
	f.close()
	var found: Array = finder.scan_folder(odd)
	t.ok("an unrecognised game alone does not enable it", found.size() == 1 and not GameExporter.can_export(found))
	copy_tree(game_root.path_join("keen2"), tmp.path_join("one/keen2"))
	t.ok("one supported game enables it", GameExporter.can_export(finder.scan_folder(tmp.path_join("one"))))


func _folder_export() -> void:
	var finder: GameFinder = GameFinder.new()
	var src: String = tmp.path_join("src")
	copy_tree(game_root.path_join("keen1"), src.path_join("Keen1"))
	copy_tree(game_root.path_join("keen4"), src.path_join("base4"))
	var extra: FileAccess = FileAccess.open(src.path_join("Keen1/DOSBOX.CONF"), FileAccess.WRITE)
	extra.store_string("not part of the game")
	extra.close()
	FileAccess.set_read_only_attribute(src.path_join("base4/GAMEMAPS.CK4"), true)
	var before: Dictionary = tree_hashes(src)
	var found: Array = finder.scan_folder(src)
	t.eq("the fixture's games are found", ids(found), PackedStringArray(["keen1", "keen4"]))
	var ex: GameExporter = GameExporter.new()
	var calls: Array = [0]
	var results: Array = ex.export_folder(found, tmp.path_join("out"), func(_id: String, _done: int, _of: int) -> void: calls[0] += 1)
	t.eq("both games export", ids(results), PackedStringArray(["keen1", "keen4"]))
	t.ok("progress was reported per file", calls[0] == set_files("keen1").size() + set_files("keen4").size())
	var root: String = tmp.path_join("out").path_join(GameExporter.FOLDER)
	var tree: Dictionary = tree_hashes(root)
	var want: Dictionary = {}
	for id: String in ["keen1", "keen4"]:
		for name: String in set_files(id):
			want[id + "/" + name] = true
	var game_files: PackedStringArray = PackedStringArray()
	for k: String in tree:
		if k.contains("/"):
			game_files.append(k.to_upper().replace("KEEN1/", "keen1/").replace("KEEN4/", "keen4/"))
	game_files.sort()
	var want_list: PackedStringArray = PackedStringArray(want.keys())
	want_list.sort()
	t.eq("the export holds exactly the release files, one folder per game (no DOSBOX.CONF)", game_files, want_list)
	var same: bool = true
	for k: String in tree:
		if k.begins_with("keen1/") and tree[k] != before.get("Keen1/" + k.get_file(), ""):
			same = false
		if k.begins_with("keen4/") and tree[k] != before.get("base4/" + k.get_file(), ""):
			same = false
	t.ok("every exported file is byte-identical to its source", same)
	t.ok("the manifest and the README are written", tree.has(GameExporter.MANIFEST) and tree.has(GameExporter.README))
	var check: Dictionary = GameExporter.check_export(tmp.path_join("out"))
	t.ok("the export checks against its manifest (from the parent folder too)", check.ok and check.games.size() == 2)
	t.eq("the sources are untouched", tree_hashes(src), before)
	t.ok("a read-only source stays read-only", FileAccess.get_read_only_attribute(src.path_join("base4/GAMEMAPS.CK4")))
	# the round trip: the phone side finds the exported games as supported releases
	t.eq("the finder recognises the exported folder's games", ids(finder.scan_folder(root)), PackedStringArray(["keen1", "keen4"]))

	# again: nothing to copy
	results = ex.export_folder(found, tmp.path_join("out"))
	t.ok("a second export keeps every file", results.all(func(r: Dictionary) -> bool: return r.ok and r.written == 0))
	# a damaged exported file is put right
	var damaged: String = root.path_join("keen1").path_join(DirAccess.open(root.path_join("keen1")).get_files()[0])
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(damaged)
	bytes[0] ^= 0xFF
	var w: FileAccess = FileAccess.open(damaged, FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()
	t.ok("a damaged exported file fails the manifest check", not GameExporter.check_export(root).ok)
	results = ex.export_folder(found, tmp.path_join("out"))
	t.ok("re-exporting rewrites just that file", results[0].ok and results[0].written == 1 and GameExporter.check_export(root).ok)
	# a source changed after it was found: that game is refused, the other goes
	FileAccess.set_read_only_attribute(src.path_join("base4/GAMEMAPS.CK4"), false)
	var s4: FileAccess = FileAccess.open(src.path_join("base4/GAMEMAPS.CK4"), FileAccess.READ_WRITE)
	s4.seek(100)
	s4.store_8(0x55)
	s4.close()
	_remove_tree(root)
	results = ex.export_folder(found, tmp.path_join("out"))
	var by: Dictionary = {}
	for r: Dictionary in results:
		by[r.id] = r
	t.ok("a source damaged after detection is refused with a reason", not by.keen4.ok and by.keen4.message.contains("GAMEMAPS.CK4") and by.keen1.ok)
	t.ok("the manifest then lists only the complete game", GameExporter.check_export(root).games.size() == 1)
	t.ok("no half-written file is left", not tree_hashes(root).keys().any(func(k: String) -> bool: return k.ends_with(".part")))


func _zip_both_ways() -> void:
	var finder: GameFinder = GameFinder.new()
	var src: String = tmp.path_join("zsrc")
	copy_tree(game_root.path_join("keen3"), src.path_join("k3"))
	copy_tree(game_root.path_join("kdreams"), src.path_join("dreams"))
	var found: Array = finder.scan_folder(src)
	var ex: GameExporter = GameExporter.new()
	var zip_path: String = tmp.path_join("megarocket-games.zip")
	var results: Array = ex.export_zip(found, zip_path)
	t.eq("both games go into the ZIP", ids(results), PackedStringArray(["kdreams", "keen3"]))
	var in_zip: Array = finder.identify_zip(zip_path)
	t.eq("the finder recognises the games inside the exported ZIP", ids(in_zip), PackedStringArray(["kdreams", "keen3"]))
	var z: ZIPReader = ZIPReader.new()
	z.open(zip_path)
	var has_manifest: bool = z.get_files().has(GameExporter.FOLDER + "/" + GameExporter.MANIFEST)
	z.close()
	t.ok("the ZIP carries the manifest", has_manifest)
	# and a ZIP found by the finder exports to a folder
	results = ex.export_folder(in_zip, tmp.path_join("fromzip"))
	t.ok("games found inside a ZIP export to a folder", ids(results) == PackedStringArray(["kdreams", "keen3"]) and GameExporter.check_export(tmp.path_join("fromzip")).ok)


func _every_game() -> void:
	var finder: GameFinder = GameFinder.new()
	var found: Array = finder.scan_folder(game_root)
	var ex: GameExporter = GameExporter.new()
	var results: Array = ex.export_folder(found, tmp.path_join("all"))
	var check: Dictionary = GameExporter.check_export(tmp.path_join("all"))
	print("  every game in the development copies: ", ids(results))
	t.ok("all seven games export and check (%d)" % results.size(), results.size() == 7 and check.ok and check.games.size() == 7)
