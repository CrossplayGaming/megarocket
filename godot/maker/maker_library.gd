# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerLibrary
extends RefCounted
## V15-03: the player's own levels, per game, in the player's folder (Settings.user_dir()/maker/<game>,
## never a game's folder and never the repository). One file per level ("<id>.mkl", JSON): its name, when
## it was made and last changed, the game's level slot it plays as, where it came from ("new" or "remix
## <n>"), its size, the engine's header values, its planes (16-bit words, deflated, base64) and Keen's
## last test run (the trail). A level is played by writing it into the engine's own format (MakerModel).

const EXT: String = "mkl"
const FORMAT: int = 1

var error: String = ""


## The folder a game's levels live in.
static func dir_for(game: String) -> String:
	return Settings.user_dir().path_join("maker").path_join(game)


## V15-04's sharing: where shared level files are written (to send on), and where ones received are put
## to bring in.
static func shared_dir() -> String:
	return Settings.user_dir().path_join("maker").path_join("shared")


static func inbox_dir() -> String:
	return Settings.user_dir().path_join("maker").path_join("inbox")


## The game's saved levels, newest change first: [{path, name, created, modified, slot, origin}].
static func list(game: String) -> Array:
	var out: Array = []
	var dir: String = dir_for(game)
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() != EXT:
			continue
		var meta: Dictionary = _read_json(dir.path_join(f))
		if meta.is_empty() or str(meta.get("game", "")) != game:
			continue
		out.append({"path": dir.path_join(f), "name": str(meta.get("name", f.get_basename())),
			"created": int(meta.get("created", 0)), "modified": int(meta.get("modified", 0)),
			"slot": int(meta.get("slot", 1)), "origin": str(meta.get("origin", "new")), "cleared": str(meta.get("cleared", "")) != ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.modified > b.modified or (a.modified == b.modified and str(a.path) < str(b.path)))
	return out


static func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var v: Variant = JSON.parse_string(text)
	return v if v is Dictionary else {}


## A new file name in the game's folder (the time, then a number if taken).
static func new_path(game: String) -> String:
	var dir: String = dir_for(game)
	var base: String = "level_%d" % int(Time.get_unix_time_from_system())
	var path: String = dir.path_join(base + "." + EXT)
	var n: int = 2
	while FileAccess.file_exists(path):
		path = dir.path_join("%s_%d.%s" % [base, n, EXT])
		n += 1
	return path


## Writes a level to `path`: `meta` holds game, name, slot, origin (and created, kept from the file it
## replaces); `trail` Keen's last run. False with `error`.
func save(path: String, level: KeenLevel, meta: Dictionary, trail: PackedVector2Array = PackedVector2Array()) -> bool:
	error = ""
	var game: String = str(meta.get("game", ""))
	if game == "" or level == null:
		error = "no level to save"
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var planes: Array = []
	for words: PackedInt32Array in level.planes:
		var raw: PackedByteArray = LevelCodec.words_to_bytes(words)
		planes.append(Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE)))
	var now: int = int(Time.get_unix_time_from_system())
	var old: Dictionary = _read_json(path)
	var t: Array = []
	for p: Vector2 in trail:
		t.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	var doc: Dictionary = {"megarocket_maker": FORMAT, "game": game, "engine": level.engine,
		"name": str(meta.get("name", "My level")), "created": int(old.get("created", meta.get("created", now))),
		"modified": now, "slot": int(meta.get("slot", 1)), "origin": str(meta.get("origin", "new")), "cleared": str(meta.get("cleared", "")),
		"width": level.width, "height": level.height, "fields": level.fields, "planes": planes, "trail": t}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		error = "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		return false
	f.store_string(JSON.stringify(doc, " "))
	f.close()
	return true


## Reads a saved level: {level: KeenLevel, meta: the file's other values, trail: PackedVector2Array};
## empty with `error`.
func load_level(path: String) -> Dictionary:
	error = ""
	var doc: Dictionary = _read_json(path)
	if doc.is_empty() or int(doc.get("megarocket_maker", 0)) != FORMAT:
		error = "%s is not a Keen Maker level" % path.get_file()
		return {}
	var w: int = int(doc.get("width", 0))
	var h: int = int(doc.get("height", 0))
	var level: KeenLevel = KeenLevel.create(str(doc.get("engine", "")), w, h, str(doc.get("name", "")))
	var planes: Array = doc.get("planes", [])
	if w <= 0 or h <= 0 or planes.size() != level.planes.size():
		error = "%s: its size or planes are wrong" % path.get_file()
		return {}
	for p: int in range(planes.size()):
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(planes[p])).decompress(w * h * 2, FileAccess.COMPRESSION_DEFLATE)
		if raw.size() != w * h * 2:
			error = "%s: plane %d is damaged" % [path.get_file(), p]
			return {}
		level.planes[p] = LevelCodec.bytes_to_words(raw)
	var fields: Variant = doc.get("fields", {})
	if fields is Dictionary:
		for k: String in fields:
			level.fields[k] = int(fields[k])
	var trail: PackedVector2Array = PackedVector2Array()
	for p: Variant in doc.get("trail", []):
		if p is Array and (p as Array).size() == 2:
			trail.append(Vector2(float(p[0]), float(p[1])))
	doc.erase("planes")
	doc.erase("trail")
	return {"level": level, "meta": doc, "trail": trail}


## Gives a saved level a new name. False with `error`.
func rename(path: String, name: String) -> bool:
	var got: Dictionary = load_level(path)
	if got.is_empty():
		return false
	var meta: Dictionary = got.meta
	meta["name"] = name
	return save(path, got.level, meta, got.trail)


## A copy of a saved level under a new file ("<name> copy"); its path, or "" with `error`.
func duplicate_level(path: String) -> String:
	var got: Dictionary = load_level(path)
	if got.is_empty():
		return ""
	var meta: Dictionary = got.meta
	meta["name"] = str(meta.get("name", "")) + " copy"
	meta.erase("created")
	var to: String = new_path(str(meta.get("game", "")))
	return to if save(to, got.level, meta, got.trail) else ""


## Removes a saved level's file (asked first on the screen). Only files of the maker's own folder.
func delete(path: String) -> bool:
	error = ""
	if path.get_extension() != EXT or not path.get_base_dir().get_base_dir().get_file() == "maker":
		error = "not a Keen Maker level"
		return false
	if DirAccess.remove_absolute(path) != OK:
		error = "cannot remove " + path.get_file()
		return false
	return true
