# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GameImporter
extends RefCounted
## Brings games into the app's own storage (AND-02), for where the launcher
## cannot read a game where it lies (Android: a folder picked with the
## system picker). From a source (a picked folder, two levels down, and any
## ZIP in it) it copies only the files that may belong to a supported
## release (known name and size) into a staging folder, file by file with
## progress and up to three tries each, identifies the releases there by
## their hashes (GameFinder), and moves each supported game whole into
## games_root/<id> (replacing an older import of it). Every game the source
## holds gets a result: imported, or why not (another release, files
## missing or damaged). A SHELL-10 export (its megarocket-export.json) is
## checked: every game it lists must be imported. The source is only read.
##
## A source is an object with list() -> [{path, name, size, dir, doc}] and
## copy(doc, dest_path) -> bool: FolderSource (a plain folder: desktop and
## tests) or SafSource (Android).

const TRIES: int = 3
const MANIFEST: String = "megarocket-export.json"

var games_root: String = OS.get_user_data_dir().path_join("games")
var staging_root: String = OS.get_user_data_dir().path_join("import_staging")
## (what: String, done: int, total: int), on the importing thread.
var progress: Callable = Callable()
var copies_retried: int = 0


class FolderSource:
	var root: String
	## file name -> times to fail before a copy succeeds (tests: retries)
	var fail_first: Dictionary = {}

	func _init(folder: String) -> void:
		root = folder

	func list(depth: int = 2) -> Array:
		var out: Array = []
		_list(root, "", depth, out)
		return out

	func _list(dir: String, prefix: String, depth: int, out: Array) -> void:
		var d: DirAccess = DirAccess.open(dir)
		if d == null:
			return
		for f: String in d.get_files():
			var p: String = dir.path_join(f)
			out.append({"path": prefix + f, "name": f, "size": FileAccess.get_file_as_bytes(p).size(), "dir": false, "doc": p})
		for sub: String in d.get_directories():
			out.append({"path": prefix + sub, "name": sub, "size": 0, "dir": true, "doc": dir.path_join(sub)})
			if depth > 0:
				_list(dir.path_join(sub), prefix + sub + "/", depth - 1, out)

	func copy(doc: String, dest: String) -> bool:
		var n: int = int(fail_first.get(doc.get_file(), 0))
		if n > 0:
			fail_first[doc.get_file()] = n - 1
			return false
		return DirAccess.copy_absolute(doc, dest) == OK


class SafSource:
	var tree: String
	var saf: AndroidSaf

	func _init(tree_uri: String) -> void:
		tree = tree_uri
		saf = AndroidSaf.new()

	func list(depth: int = 2) -> Array:
		return saf.list_tree(tree, depth)

	func copy(doc: String, dest: String) -> bool:
		return saf.copy(tree, doc, dest)


## Every known file name (UPPER) -> the sizes the supported releases give it.
static func _known_sizes() -> Dictionary:
	var out: Dictionary = {}
	for s: Dictionary in KnownFiles.SETS:
		for name: String in s.files:
			if not out.has(name):
				out[name] = []
			(out[name] as Array).append(int(s.files[name][0]))
	return out


## One file copied, tried up to TRIES times; the copy must have the listed size.
func _copy(source: Object, entry: Dictionary, dest: String) -> bool:
	for attempt: int in range(TRIES):
		if attempt > 0:
			copies_retried += 1
		if source.copy(entry.doc, dest) and FileAccess.file_exists(dest) and \
				FileAccess.get_file_as_bytes(dest).size() == int(entry.size):
			return true
	return false


## Imports what the source holds. Returns one result per game:
## {id, title, ok, message, files}.
func import_from(source: Object) -> Array:
	_remove_tree(staging_root)
	DirAccess.make_dir_recursive_absolute(staging_root)
	DirAccess.make_dir_recursive_absolute(games_root)
	var entries: Array = source.list()
	var sizes: Dictionary = _known_sizes()
	# what to copy: known names at a known size, and every ZIP; grouped by folder
	var wanted: Array = []
	var manifest_entry: Dictionary = {}
	for e: Dictionary in entries:
		if e.dir:
			continue
		var upper: String = String(e.name).to_upper()
		if upper == MANIFEST.to_upper():
			manifest_entry = e
		elif upper.ends_with(".ZIP") or (sizes.has(upper) and (sizes[upper] as Array).has(int(e.size))):
			wanted.append(e)
	var failed_copies: PackedStringArray = PackedStringArray()
	var done: int = 0
	for e: Dictionary in wanted:
		var dest: String = staging_root.path_join(String(e.path))
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		if not _copy(source, e, dest):
			failed_copies.append(String(e.path))
			DirAccess.remove_absolute(dest)
		done += 1
		if progress.is_valid():
			progress.call(String(e.path), done, wanted.size())
	# identify in staging: folders, then ZIPs
	var finder: GameFinder = GameFinder.new()
	var found: Array = finder.scan_folder(staging_root, 2)
	for e: Dictionary in wanted:
		if String(e.name).to_upper().ends_with(".ZIP"):
			found.append_array(finder.identify_zip(staging_root.path_join(String(e.path))))
	var results: Array = []
	var done_ids: Dictionary = {}
	for r: Dictionary in found:
		if done_ids.has(r.id) and (done_ids[r.id] as Dictionary).ok:
			continue
		var res: Dictionary = {"id": r.id, "title": GameFinder._title(r.id), "ok": false, "message": "", "files": 0}
		if r.status == GameFinder.STATUS_OK:
			var n: int = _install(r)
			res.ok = n > 0
			res.files = n
			res.message = "%s %s: %d files imported." % [res.title, r.version, n] if n > 0 else \
				ShellMessages.say("%s could not be written to the app's storage" % res.title, "Check that the phone has free space, then import again.")
		else:
			res.message = ShellMessages.say(r.message, "Copy that release's files to the phone, then import again.")
		done_ids[r.id] = res
	for id: String in done_ids:
		results.append(done_ids[id])
	# an export lists its games: each must have come in
	if not manifest_entry.is_empty():
		var mpath: String = staging_root.path_join("_manifest.json")
		if _copy(source, manifest_entry, mpath):
			var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(mpath))
			if doc is Dictionary:
				for g: Variant in (doc as Dictionary).get("games", []):
					var id: String = String((g as Dictionary).get("id", ""))
					if id != "" and not (done_ids.has(id) and (done_ids[id] as Dictionary).ok):
						results.append({"id": id, "title": GameFinder._title(id), "ok": false, "files": 0,
							"message": ShellMessages.say("%s is listed in the export but did not come in whole" % GameFinder._title(id),
								"Export it again from the computer, copy the whole export to the phone, then import again.")})
	if not failed_copies.is_empty():
		results.append({"id": "", "title": "", "ok": false, "files": 0,
			"message": ShellMessages.say("%d file(s) could not be copied after %d tries (%s)" % [failed_copies.size(), TRIES, ", ".join(failed_copies.slice(0, 3))],
				"Check the files are still in the folder you picked, then import again.")})
	if results.is_empty():
		results.append({"id": "", "title": "", "ok": false, "files": 0,
			"message": ShellMessages.say("No Keen game was found in that folder", "Pick the folder that holds a game's files (or a Megarocket export), then import again.")})
	_remove_tree(staging_root)
	return results


## A recognised game's files, from staging (a folder or a ZIP in it) into
## games_root/<id>, verified again by hash. The number of files, 0 on failure.
func _install(r: Dictionary) -> int:
	var s: Dictionary = {}
	for set_: Dictionary in KnownFiles.SETS:
		if set_.id == r.id and set_.version == r.version:
			s = set_
	if s.is_empty():
		return 0
	var target: String = games_root.path_join(String(r.id))
	var temp: String = target + ".new"
	_remove_tree(temp)
	DirAccess.make_dir_recursive_absolute(temp)
	var folder: String = String(r.folder)
	var zip_at: int = folder.to_lower().find(".zip")
	var z: ZIPReader = null
	var inner: String = ""
	if zip_at >= 0:
		z = ZIPReader.new()
		if z.open(folder.substr(0, zip_at + 4)) != OK:
			return 0
		inner = folder.substr(zip_at + 5) if folder.length() > zip_at + 4 else ""
	var names: Dictionary = {}
	if z != null:
		for e: String in z.get_files():
			if e.get_base_dir() == inner:
				names[e.get_file().to_upper()] = e
	else:
		names = GameFinder._listing(folder)
	var n: int = 0
	for upper: String in s.files:
		var bytes: PackedByteArray = z.read_file(names[upper]) if z != null else FileAccess.get_file_as_bytes(folder.path_join(names[upper]))
		if bytes.size() != int(s.files[upper][0]) or GameFinder.sha256(bytes) != String(s.files[upper][1]):
			n = -1
			break
		var actual: String = String(names[upper]).get_file()
		var f: FileAccess = FileAccess.open(temp.path_join(actual), FileAccess.WRITE)
		if f == null:
			n = -1
			break
		f.store_buffer(bytes)
		f.close()
		n += 1
	if z != null:
		z.close()
	if n <= 0:
		_remove_tree(temp)
		return 0
	_remove_tree(target)
	if DirAccess.rename_absolute(temp, target) != OK:
		return 0
	return n


static func _remove_tree(path: String) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in d.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)
