# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GameExporter
extends RefCounted
## SHELL-10, "Export for Android": copies the files of every game the finder
## found into one folder (or one ZIP) the Android app imports in a single
## pick. Only files that identify a supported release are copied, each
## checked against the known-files list as it is read; the sources are only
## ever read. The layout:
##
##   Megarocket Games/
##     megarocket-export.json   what is inside (program, games, files, sizes, hashes)
##     README.txt               where to put it on the phone
##     keen1/ ... keen6/ kdreams/   one folder per game, its files as named in the release
##
## An existing export is brought up to date: files already there with the
## right contents are kept, others written (through a temporary name, so a
## cut-off copy never looks finished). Nothing of the games is ever written
## anywhere but the destination the user chose.

const FOLDER: String = "Megarocket Games"
const MANIFEST: String = "megarocket-export.json"
const README: String = "README.txt"
const FORMAT: int = 1

## Set when a call fails before any game is written (no space, no access).
var error: String = ""


## The games an export would contain: the supported ones the finder found,
## one per game (the first found wins, as the launcher shows it).
static func exportable(found: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for f: Dictionary in found:
		if f.status == GameFinder.STATUS_OK and not seen.has(f.id):
			seen[f.id] = true
			out.append(f)
	return out


## Whether the launcher's button is enabled.
static func can_export(found: Array) -> bool:
	return not exportable(found).is_empty()


static func _set_of(id: String) -> Dictionary:
	for s: Dictionary in KnownFiles.SETS:
		if s.id == id:
			return s
	return {}


## A reader for one found game: name -> bytes, from its folder or its ZIP.
## Names are matched without regard to case, as the finder matched them.
static func _reader(entry: Dictionary) -> Dictionary:
	var folder: String = entry.folder
	var zip_split: int = folder.to_lower().find(".zip")
	if zip_split >= 0 and not DirAccess.dir_exists_absolute(folder):
		var zip_path: String = folder.substr(0, zip_split + 4)
		var inner: String = folder.substr(zip_split + 5) if folder.length() > zip_split + 4 else ""
		var z: ZIPReader = ZIPReader.new()
		if z.open(zip_path) != OK:
			return {"error": "cannot open " + zip_path}
		var names: Dictionary = {}      # UPPER name -> name as stored (for the output)
		var entries: Dictionary = {}    # UPPER name -> entry path inside the ZIP
		for e: String in z.get_files():
			if e.get_base_dir() == inner and not e.ends_with("/"):
				names[e.get_file().to_upper()] = e.get_file()
				entries[e.get_file().to_upper()] = e
		return {"names": names, "read": func(upper: String) -> PackedByteArray: return z.read_file(entries[upper]) if entries.has(upper) else PackedByteArray(), "zip": z}
	var listing: Dictionary = GameFinder._listing(folder)
	return {"names": listing, "read": func(upper: String) -> PackedByteArray: return FileAccess.get_file_as_bytes(folder.path_join(listing[upper])) if listing.has(upper) else PackedByteArray()}


## Bytes the export will hold (for the free-space check and the progress bar).
static func total_bytes(found: Array) -> int:
	var n: int = 0
	for f: Dictionary in exportable(found):
		for name: String in _set_of(f.id).files:
			n += int(_set_of(f.id).files[name][0])
	return n


## Copies the found games into <destination>/Megarocket Games. `progress`
## is called as (game id, files done, files in that game). Returns one
## result per game: {id, title, ok, message, written, kept}.
func export_folder(found: Array, destination: String, progress: Callable = Callable()) -> Array:
	error = ""
	var games: Array = exportable(found)
	if games.is_empty():
		error = "No supported game has been found yet, so there is nothing to export."
		return []
	var root: String = destination.path_join(FOLDER)
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		error = "Cannot create %s. Choose a folder you can write to." % root
		return []
	var d: DirAccess = DirAccess.open(root)
	var need: int = total_bytes(found)
	if d != null and d.get_space_left() > 0 and d.get_space_left() < need:
		error = "Not enough free space in %s: the export needs %.1f MB." % [destination, need / 1048576.0]
		return []
	var results: Array = []
	var manifest_games: Array = []
	for g: Dictionary in games:
		var s: Dictionary = _set_of(g.id)
		var r: Dictionary = {"id": g.id, "title": s.title, "ok": true, "message": "", "written": 0, "kept": 0}
		var src: Dictionary = _reader(g)
		if src.has("error"):
			r.ok = false
			r.message = "%s: %s" % [s.title, src.error]
			results.append(r)
			continue
		var out_dir: String = root.path_join(g.id)
		DirAccess.make_dir_recursive_absolute(out_dir)
		var names: Array = s.files.keys()
		names.sort()
		var done: int = 0
		for upper: String in names:
			var want: Array = s.files[upper]
			var actual: String = src.names.get(upper, upper)
			var target: String = out_dir.path_join(actual)
			if FileAccess.file_exists(target):
				var have: PackedByteArray = FileAccess.get_file_as_bytes(target)
				if have.size() == want[0] and GameFinder.sha256(have) == want[1]:
					r.kept += 1
					done += 1
					if progress.is_valid():
						progress.call(g.id, done, names.size())
					continue
			var bytes: PackedByteArray = src.read.call(upper)
			if bytes.size() != want[0] or GameFinder.sha256(bytes) != want[1]:
				r.ok = false
				r.message = "%s: %s changed since it was found (it no longer matches %s %s); the game was not exported. Check the installation and export again." % [s.title, actual, s.title, s.version]
				break
			var tmp: String = target + ".part"
			var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
			if f == null:
				r.ok = false
				r.message = "%s: cannot write %s (%s)." % [s.title, target, error_string(FileAccess.get_open_error())]
				break
			f.store_buffer(bytes)
			f.close()
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(target)
			if DirAccess.rename_absolute(tmp, target) != OK:
				r.ok = false
				r.message = "%s: cannot finish writing %s." % [s.title, target]
				break
			r.written += 1
			done += 1
			if progress.is_valid():
				progress.call(g.id, done, names.size())
		if src.has("zip"):
			src.zip.close()
		if r.ok:
			r.message = "%s %s: %d files (%d copied, %d already there)." % [s.title, s.version, names.size(), r.written, r.kept]
			manifest_games.append(_manifest_game(s, src.names))
		results.append(r)
	# the manifest lists every game in the folder, including ones from an
	# earlier export that are still complete
	for id: String in _complete_games_in(root):
		if not manifest_games.any(func(m: Dictionary) -> bool: return m.id == id):
			manifest_games.append(_manifest_game(_set_of(id), GameFinder._listing(root.path_join(id))))
	_write_text(root.path_join(MANIFEST), JSON.stringify(_manifest(manifest_games), "\t"))
	_write_text(root.path_join(README), readme())
	return results


## The same as one ZIP at `zip_path` (Megarocket Games/... inside).
func export_zip(found: Array, zip_path: String, progress: Callable = Callable()) -> Array:
	error = ""
	var games: Array = exportable(found)
	if games.is_empty():
		error = "No supported game has been found yet, so there is nothing to export."
		return []
	var tmp: String = zip_path + ".part"
	var z: ZIPPacker = ZIPPacker.new()
	if z.open(tmp) != OK:
		error = "Cannot create %s. Choose a folder you can write to." % zip_path
		return []
	var results: Array = []
	var manifest_games: Array = []
	for g: Dictionary in games:
		var s: Dictionary = _set_of(g.id)
		var r: Dictionary = {"id": g.id, "title": s.title, "ok": true, "message": "", "written": 0, "kept": 0}
		var src: Dictionary = _reader(g)
		if src.has("error"):
			r.ok = false
			r.message = "%s: %s" % [s.title, src.error]
			results.append(r)
			continue
		var names: Array = s.files.keys()
		names.sort()
		var blobs: Array = []
		for upper: String in names:
			var bytes: PackedByteArray = src.read.call(upper)
			if bytes.size() != s.files[upper][0] or GameFinder.sha256(bytes) != s.files[upper][1]:
				r.ok = false
				r.message = "%s: %s changed since it was found; the game was not exported." % [s.title, src.names.get(upper, upper)]
				break
			blobs.append([src.names.get(upper, upper), bytes])
		if src.has("zip"):
			src.zip.close()
		if r.ok:
			# a game goes in whole or not at all
			for b: Array in blobs:
				z.start_file(FOLDER + "/" + g.id + "/" + b[0])
				z.write_file(b[1])
				z.close_file()
				r.written += 1
				if progress.is_valid():
					progress.call(g.id, r.written, names.size())
			r.message = "%s %s: %d files." % [s.title, s.version, names.size()]
			manifest_games.append(_manifest_game(s, src.names))
		results.append(r)
	z.start_file(FOLDER + "/" + MANIFEST)
	z.write_file(JSON.stringify(_manifest(manifest_games), "\t").to_utf8_buffer())
	z.close_file()
	z.start_file(FOLDER + "/" + README)
	z.write_file(readme().to_utf8_buffer())
	z.close_file()
	z.close()
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)
	DirAccess.rename_absolute(tmp, zip_path)
	return results


static func _manifest_game(s: Dictionary, names: Dictionary) -> Dictionary:
	var files: Dictionary = {}
	for upper: String in s.files:
		files[names.get(upper, upper)] = s.files[upper]
	return {"id": s.id, "title": s.title, "version": s.version, "files": files}


static func _manifest(games: Array) -> Dictionary:
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return {"format": FORMAT, "program": "Megarocket", "program_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"games": games}


## Games whose folder in an export is complete and correct (by the known-files list).
static func _complete_games_in(root: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for s: Dictionary in KnownFiles.SETS:
		var folder: String = root.path_join(s.id)
		if not DirAccess.dir_exists_absolute(folder):
			continue
		var listing: Dictionary = GameFinder._listing(folder)
		var good: bool = true
		for upper: String in s.files:
			if not listing.has(upper) or FileAccess.get_size(folder.path_join(listing[upper])) != s.files[upper][0]:
				good = false
				break
		if good:
			out.append(s.id)
	return out


## Reads an export (its folder, or the folder holding it) and checks every
## file against its manifest: what the Android import (AND-02) does first.
## Returns {ok, message, games: [{id, title, ok, folder}]}.
static func check_export(path: String) -> Dictionary:
	var root: String = path
	if not FileAccess.file_exists(root.path_join(MANIFEST)) and FileAccess.file_exists(root.path_join(FOLDER).path_join(MANIFEST)):
		root = root.path_join(FOLDER)
	var text: String = FileAccess.get_file_as_string(root.path_join(MANIFEST))
	var m: Variant = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY or int(m.get("format", 0)) != FORMAT:
		return {"ok": false, "message": "This is not a Megarocket export (no readable %s)." % MANIFEST, "games": []}
	var games: Array = []
	var all_ok: bool = true
	for g: Dictionary in m.games:
		var folder: String = root.path_join(g.id)
		var ok: bool = true
		for name: String in g.files:
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(folder.path_join(name))
			if bytes.size() != int(g.files[name][0]) or GameFinder.sha256(bytes) != g.files[name][1]:
				ok = false
				break
		all_ok = all_ok and ok
		games.append({"id": g.id, "title": g.title, "ok": ok, "folder": folder})
	return {"ok": all_ok, "message": "", "games": games}


static func readme() -> String:
	return """Megarocket - your games, ready for the Android app

This folder holds the files of the Commander Keen games Megarocket found on
your computer, one folder per game, exactly as they came from your copies.

To play them on your phone:
  1. Copy the whole "Megarocket Games" folder to the phone (USB cable,
     memory card, or any cloud folder the phone can open). The ZIP version,
     if you made one, can be copied as it is.
  2. In Megarocket on the phone, choose Import games and pick this folder
     (or the ZIP). Every game in it is imported at once.

These are your own copies of the games, for your own devices. Please do not
share them.
"""


static func _write_text(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
