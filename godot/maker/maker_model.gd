# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerModel
extends RefCounted
## MAKER-03: the editor's document, without its screen. A game's levels opened with the maker's readers
## (VortLevels for Keen 1-3, TedMaps for Keen 4-6), one level being edited; painting a cell, placing
## Keen's start, undo and redo; saving into Megarocket's own folder (never the game's); and the play
## button's request for GameHost.start (MAKER-02: straight into this level, the edits in place of the
## game's files). Everything a screen shows comes from here, so the tests can drive it headless.

const ENGINES: Dictionary = {"keen1": KeenLevel.VORTICONS, "keen2": KeenLevel.VORTICONS, "keen3": KeenLevel.VORTICONS,
	"keen4": KeenLevel.GALAXY, "keen5": KeenLevel.GALAXY, "keen6": KeenLevel.GALAXY}
const GALAXY_META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
## Keen's start: Keen 1-3 the sprite plane's 255; Keen 4-6 the info plane's 1 (facing right; 2 left)
const START_PLANE: Dictionary = {KeenLevel.VORTICONS: 1, KeenLevel.GALAXY: 2}
const START_MARKERS: Dictionary = {KeenLevel.VORTICONS: [255], KeenLevel.GALAXY: [1, 2]}

var game_id: String = ""
var folder: String = ""
var engine: String = ""
var ext: String = ""             # Keen 1-3: "CK1" ...
var error: String = ""
## Keen 1-3: level number -> KeenLevel (the LEVELnn files found); Keen 4-6: the map set
var levels: Dictionary = {}
var maps: TedMaps = null
## The level being edited (its number) and its KeenLevel
var number: int = -1
var level: KeenLevel = null
## Undo: lists of changes, each [plane, x, y, before, after]; a stroke is one entry
var _undo: Array = []
var _redo: Array = []
var _stroke: Array = []
## Whether anything changed since the last save
var dirty: bool = false


## Opens a game's levels (`game_id` keen1..keen6, `dir` its folder). False with `error`.
func open(id: String, dir: String) -> bool:
	game_id = id
	folder = dir
	engine = ENGINES.get(id, "")
	levels = {}
	maps = null
	number = -1
	level = null
	_undo = []
	_redo = []
	dirty = false
	match engine:
		KeenLevel.VORTICONS:
			ext = "CK" + id.substr(4, 1)
			for n: int in range(1, 100):
				var l: KeenLevel = VortLevels.new().read_file(dir, n, ext)
				if l != null:
					levels[n] = l
			if levels.is_empty():
				error = "No level files (LEVELnn.%s) in %s" % [ext, dir]
				return false
		KeenLevel.GALAXY:
			maps = TedMaps.open_galaxy(dir, "res://data/omnispeak".path_join(GALAXY_META[id]))
			if maps == null or maps.error != "":
				error = maps.error if maps != null else "the maps did not open"
				return false
		_:
			error = "The maker does not have %s yet" % id
			return false
	error = ""
	return true


## The levels to choose from: [number, name] in order (Keen 1-3 name theirs by number).
func level_list() -> Array:
	var out: Array = []
	if engine == KeenLevel.VORTICONS:
		for n: int in levels.keys():
			out.append([n, "Level %d" % n])
		out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	elif maps != null:
		for n: int in range(maps.maps.size()):
			if maps.maps[n] != null:
				out.append([n, (maps.maps[n] as KeenLevel).name.strip_edges()])
	return out


func select(n: int) -> bool:
	var l: KeenLevel = levels.get(n) if engine == KeenLevel.VORTICONS else (maps.maps[n] if maps != null and n >= 0 and n < maps.maps.size() else null)
	if l == null:
		return false
	number = n
	level = l
	_undo = []
	_redo = []
	return true


## The planes' names for the screen (Keen 1-3: tiles, sprites; Keen 4-6: background, foreground, info).
func plane_names() -> Array:
	return KeenLevel.PLANE_NAMES.get(engine, [])


## Sets one cell; part of the current stroke (begin_stroke / end_stroke make one undo step of a drag).
func paint(plane: int, x: int, y: int, value: int) -> bool:
	if level == null or not level.in_bounds(x, y):
		return false
	var before: int = level.get_word(plane, x, y)
	if before == value:
		return false
	level.set_word(plane, x, y, value)
	_stroke.append([plane, x, y, before, value])
	dirty = true
	return true


func begin_stroke() -> void:
	end_stroke()


func end_stroke() -> void:
	if not _stroke.is_empty():
		_undo.append(_stroke)
		_redo = []
		_stroke = []


## Keen's start at (x, y): every start marker cleared, one placed (Keen 4-6 keeps the facing it had).
func place_start(x: int, y: int) -> bool:
	if level == null or not level.in_bounds(x, y):
		return false
	var plane: int = START_PLANE[engine]
	var value: int = START_MARKERS[engine][0]
	begin_stroke()
	for yy: int in range(level.height):
		for xx: int in range(level.width):
			var v: int = level.get_word(plane, xx, yy)
			if v in START_MARKERS[engine]:
				value = v
				paint(plane, xx, yy, 0)
	paint(plane, x, y, value)
	end_stroke()
	return true


## Where Keen starts (-1, -1 when the level has no start).
func start_at() -> Vector2i:
	if level == null:
		return Vector2i(-1, -1)
	var plane: int = START_PLANE[engine]
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.get_word(plane, x, y) in START_MARKERS[engine]:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func can_undo() -> bool:
	return not _undo.is_empty() or not _stroke.is_empty()


func undo() -> bool:
	end_stroke()
	if _undo.is_empty():
		return false
	var step: Array = _undo.pop_back()
	for i: int in range(step.size() - 1, -1, -1):
		var c: Array = step[i]
		level.set_word(c[0], c[1], c[2], c[3])
	_redo.append(step)
	dirty = true
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var step: Array = _redo.pop_back()
	for c: Array in step:
		level.set_word(c[0], c[1], c[2], c[4])
	_undo.append(step)
	dirty = true
	return true


## The edited files: Keen 1-3 {"LEVELnn.CKn": bytes} for every level; Keen 4-6 {maphead, gamemaps}.
## Empty with `error` when a writer refuses (a limit the engine has).
func files() -> Dictionary:
	if engine == KeenLevel.VORTICONS:
		var out: Dictionary = {}
		for n: int in levels:
			var w: VortLevels = VortLevels.new()
			var bytes: PackedByteArray = w.write(levels[n])
			if bytes.is_empty():
				error = w.error
				return {}
			out[("LEVEL%02d." % n) + ext] = bytes
		return out
	var set: Dictionary = maps.write()
	if set.is_empty():
		error = maps.error
	return set


## Saves into `dir` (Megarocket's own folder for this game, e.g. user://maker/keen4): the level files,
## or GAMEMAPS and MAPHEAD. The game's folder is never written.
func save(dir: String) -> bool:
	var f: Dictionary = files()
	if f.is_empty():
		return false
	if ProjectSettings.globalize_path(dir).simplify_path() == ProjectSettings.globalize_path(folder).simplify_path():
		error = "Saving into the game's own folder is not allowed"
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var named: Dictionary = f
	if engine == KeenLevel.GALAXY:
		named = {"GAMEMAPS." + game_id.substr(4, 1).insert(0, "CK"): f.gamemaps, "MAPHEAD." + game_id.substr(4, 1).insert(0, "CK"): f.maphead}
	for name: String in named:
		var fa: FileAccess = FileAccess.open(dir.path_join(name), FileAccess.WRITE)
		if fa == null:
			error = "%s: cannot write (%s)" % [name, error_string(FileAccess.get_open_error())]
			return false
		fa.store_buffer(named[name])
		fa.close()
	dirty = false
	return true


## The play button's request for GameHost.start: this game, straight into the level being edited, the
## edits in place of the game's files (MAKER-02).
func play_request(title: String = "") -> Dictionary:
	var f: Dictionary = files()
	if f.is_empty() or level == null:
		return {}
	var found: Dictionary = {"id": game_id, "title": title if title != "" else game_id, "folder": folder, "play_level": number}
	if engine == KeenLevel.VORTICONS:
		found["maker_files"] = f
	else:
		found["maker_maps"] = f
	return found
