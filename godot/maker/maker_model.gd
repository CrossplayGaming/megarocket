# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerModel
extends RefCounted
## MAKER-03, V15-02..04: the editor's document, without its screen. A game's levels opened with the
## maker's readers (VortLevels for Keen 1-3, TedMaps for Keen 4-6 and Keen Dreams); the level being made
## is always the maker's own copy: a new one (ground and Keen's start, of a size for the engine) or a
## remix of any of the game's levels, or one from the player's library (MakerLibrary). Painting a cell, a
## filled rectangle, placing Keen's start, undo and redo; saving into the library (the player's folder,
## never the game's); and the play button's request for GameHost.start (MAKER-02: straight into this
## level, written in the engine's own format in place of the game's, from Keen's start or set down at
## the cursor). Everything a screen shows comes from here, so the tests can drive it headless.

const ENGINES: Dictionary = {"keen1": KeenLevel.VORTICONS, "keen2": KeenLevel.VORTICONS, "keen3": KeenLevel.VORTICONS,
	"keen4": KeenLevel.GALAXY, "keen5": KeenLevel.GALAXY, "keen6": KeenLevel.GALAXY, "kdreams": KeenLevel.DREAMS}
## Keen's start: Keen 1-3 the sprite plane's 255; Keen 4-6 and Dreams the info plane's 1 (facing right; 2 left)
const START_PLANE: Dictionary = {KeenLevel.VORTICONS: 1, KeenLevel.GALAXY: 2, KeenLevel.DREAMS: 2}
const START_MARKERS: Dictionary = {KeenLevel.VORTICONS: [255], KeenLevel.GALAXY: [1, 2], KeenLevel.DREAMS: [1, 2]}
## A new level's size by engine (cells), and the level slot it plays as (the first level after the map)
const NEW_SIZE: Dictionary = {KeenLevel.VORTICONS: Vector2i(96, 26), KeenLevel.GALAXY: Vector2i(96, 32), KeenLevel.DREAMS: Vector2i(96, 32)}
const NEW_SLOT: int = 1
## Rows of ground under a new level, and the solid frame round it
const NEW_GROUND: int = 4
const NEW_FRAME: int = 2

var game_id: String = ""
var folder: String = ""
var version: String = ""
var engine: String = ""
var ext: String = ""             # Keen 1-3: "CK1" ...
var error: String = ""
## Keen 1-3: level number -> KeenLevel (the LEVELnn files found); Keen 4-6 and Dreams: the map set
var levels: Dictionary = {}
var maps: TedMaps = null
## The tile-use tables and the game's data (MakerParts); made by open() unless `parts_too` is false
var parts: MakerParts = null
## The tiles a new level is made of, chosen by use from the game's level NEW_SLOT (MakerParts.defaults)
var tile_defaults: Dictionary = {}
## The level being made (the maker's own copy), the game's level slot it plays as, its name, where it
## came from ("new", "remix <n>") and its library file ("" until saved)
var level: KeenLevel = null
var number: int = -1
var doc_name: String = ""
var origin: String = ""
var path: String = ""
## Keen's last test run: his positions in cells (MakerScreen keeps it while he plays)
var trail: PackedVector2Array = PackedVector2Array()
## Undo: lists of changes, each [plane, x, y, before, after]; a stroke is one entry
var _undo: Array = []
var _redo: Array = []
var _stroke: Array = []
## Whether anything changed since the last save
var dirty: bool = false


## The omnispeak metadata folder for a Galaxy game (Keen 6 v1.5 its own).
static func meta_dir(id: String, ver: String = "") -> String:
	var m: String = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}.get(id, id)
	if id == "keen6" and ver.contains("1.5"):
		m = "keen6e15"
	return "res://data/omnispeak".path_join(m)


## Opens a game's levels (`id` keen1..keen6 or kdreams, `dir` its folder, `ver` its release as the
## launcher found it). False with `error`.
func open(id: String, dir: String, ver: String = "", parts_too: bool = true) -> bool:
	game_id = id
	folder = dir
	version = ver
	engine = ENGINES.get(id, "")
	levels = {}
	maps = null
	parts = null
	level = null
	number = -1
	_reset()
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
		KeenLevel.GALAXY, KeenLevel.DREAMS:
			maps = TedMaps.open_galaxy(dir, meta_dir(id, ver)) if engine == KeenLevel.GALAXY else TedMaps.open_dreams(dir)
			if maps == null or maps.error != "":
				error = maps.error if maps != null else "the maps did not open"
				return false
		_:
			error = "The maker does not have %s yet" % id
			return false
	if parts_too:
		parts = MakerParts.new()
		var e: String = parts.open(id, dir, ver)
		if e != "":
			error = e
			return false
		if original(NEW_SLOT) != null:
			tile_defaults = parts.defaults(original(NEW_SLOT))
			parts.put_first([tile_defaults.top, tile_defaults.fill])
	error = ""
	return true


func _reset() -> void:
	_undo = []
	_redo = []
	_stroke = []
	dirty = false
	trail = PackedVector2Array()


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


## The game's own level `n` (not a copy: never edited), or null.
func original(n: int) -> KeenLevel:
	if engine == KeenLevel.VORTICONS:
		return levels.get(n)
	return maps.maps[n] if maps != null and n >= 0 and n < maps.maps.size() else null


## Opens the game's level `n` as a copy to remix (V15-04): it plays as level `n`.
func remix(n: int) -> bool:
	var l: KeenLevel = original(n)
	if l == null:
		error = "There is no level %d" % n
		return false
	level = l.copy()
	number = n
	var label: String = l.name.strip_edges() if l.name.strip_edges() != "" else "Level %d" % n
	doc_name = label + " remix"
	origin = "remix %d" % n
	path = ""
	_reset()
	return true


## MAKER-03's preview opened a level by number: now a remix of it.
func select(n: int) -> bool:
	return remix(n)


## A new level (V15-03): the engine's size, the game's own background, a solid frame, ground along the
## bottom (its top edge and fill chosen by use from the game's level 1) and Keen's start on the ground at
## the left. It plays as level NEW_SLOT (the header values and the map's name taken from that level).
func new_level(name: String = "My level") -> bool:
	var base: KeenLevel = original(NEW_SLOT)
	if base == null or parts == null:
		error = "This game has no level %d to start from" % NEW_SLOT
		return false
	var size: Vector2i = NEW_SIZE[engine]
	var l: KeenLevel = KeenLevel.create(engine, size.x, size.y, base.name)
	l.number = NEW_SLOT
	l.fields = base.fields.duplicate(true)
	var d: Dictionary = tile_defaults if not tile_defaults.is_empty() else parts.defaults(base)
	var tp: int = parts.tile_plane()
	var ground_top: int = size.y - NEW_GROUND
	for y: int in range(size.y):
		for x: int in range(size.x):
			l.set_word(0, x, y, d.background)
			var frame: bool = x < NEW_FRAME or x >= size.x - NEW_FRAME or y < NEW_FRAME
			if y == ground_top and not frame:
				l.set_word(tp, x, y, d.top)
			elif y > ground_top or frame:
				l.set_word(tp, x, y, d.fill)
	# Keen 1-3 set Keen 8 pixels into the marker's cell, 24 tall: two cells above the ground; the others
	# stand him on the cell below the marker
	var sy: int = ground_top - (2 if engine == KeenLevel.VORTICONS else 1)
	l.set_word(START_PLANE[engine], NEW_FRAME + 2, sy, START_MARKERS[engine][0])
	level = l
	number = NEW_SLOT
	doc_name = name
	origin = "new"
	path = ""
	_reset()
	dirty = true
	return true


## Opens a level from the player's library. False with `error`.
func load_doc(file: String) -> bool:
	var lib: MakerLibrary = MakerLibrary.new()
	var got: Dictionary = lib.load_level(file)
	if got.is_empty():
		error = lib.error
		return false
	var l: KeenLevel = got.level
	if l.engine != engine or str(got.meta.get("game", "")) != game_id:
		error = "%s is a level for another game" % file.get_file()
		return false
	level = l
	number = int(got.meta.get("slot", NEW_SLOT))
	var base: KeenLevel = original(number)
	if base != null:
		l.name = base.name if l.name == "" else l.name
		l.number = number
	doc_name = str(got.meta.get("name", ""))
	origin = str(got.meta.get("origin", "new"))
	path = file
	_reset()
	trail = got.trail
	return true


## Saves the level into the library (a new file the first time). False with `error`.
func save_doc() -> bool:
	if level == null:
		error = "no level"
		return false
	end_stroke()
	var lib: MakerLibrary = MakerLibrary.new()
	var to: String = path if path != "" else MakerLibrary.new_path(game_id)
	if not lib.save(to, level, {"game": game_id, "name": doc_name, "slot": number, "origin": origin}, trail):
		error = lib.error
		return false
	path = to
	dirty = false
	return true


## The planes' names for the screen (Keen 1-3: tiles, sprites; the others: background, foreground, info).
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


## Fills the rectangle between two cells (either corner first) with `value`: one undo step.
func fill_rect(plane: int, a: Vector2i, b: Vector2i, value: int) -> int:
	begin_stroke()
	var n: int = 0
	for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if paint(plane, x, y, value):
				n += 1
	end_stroke()
	return n


func begin_stroke() -> void:
	end_stroke()


func end_stroke() -> void:
	if not _stroke.is_empty():
		_undo.append(_stroke)
		_redo = []
		_stroke = []


## Keen's start at (x, y) in `l` (the level being made if null): every start marker cleared, one placed
## (facing as before). As one undo step when it is the level being made.
func place_start(x: int, y: int, l: KeenLevel = null) -> bool:
	var target: KeenLevel = l if l != null else level
	if target == null or not target.in_bounds(x, y):
		return false
	var plane: int = START_PLANE[engine]
	var value: int = START_MARKERS[engine][0]
	if target == level:
		begin_stroke()
	for yy: int in range(target.height):
		for xx: int in range(target.width):
			var v: int = target.get_word(plane, xx, yy)
			if v in START_MARKERS[engine]:
				value = v
				if target == level:
					paint(plane, xx, yy, 0)
				else:
					target.set_word(plane, xx, yy, 0)
	if target == level:
		paint(plane, x, y, value)
		end_stroke()
	else:
		target.set_word(plane, x, y, value)
	return true


## Where Keen starts (-1, -1 when the level has no start).
func start_at(l: KeenLevel = null) -> Vector2i:
	var target: KeenLevel = l if l != null else level
	if target == null:
		return Vector2i(-1, -1)
	var plane: int = START_PLANE[engine]
	for y: int in range(target.height):
		for x: int in range(target.width):
			if target.get_word(plane, x, y) in START_MARKERS[engine]:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func can_undo() -> bool:
	return not _undo.is_empty() or not _stroke.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


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


## The engine's files with `l` (the level being made if null) as level `number`: Keen 1-3
## {"LEVELnn.CKn": bytes}; Keen 4-6 and Dreams the whole map set {maphead, gamemaps}, the game's other
## maps as they are. Empty with `error` when a writer refuses (a limit the engine has).
func files(l: KeenLevel = null) -> Dictionary:
	var lv: KeenLevel = l if l != null else level
	if lv == null:
		error = "no level"
		return {}
	if engine == KeenLevel.VORTICONS:
		var w: VortLevels = VortLevels.new()
		lv.number = number
		var bytes: PackedByteArray = w.write(lv)
		if bytes.is_empty():
			error = w.error
			return {}
		return {("LEVEL%02d." % number) + ext: bytes}
	var was: KeenLevel = maps.maps[number]
	maps.maps[number] = lv
	var set: Dictionary = maps.write()
	maps.maps[number] = was
	if set.is_empty():
		error = maps.error
	return set


## The play button's request for GameHost.start: this game, straight into the level being made, written
## in place of the game's (MAKER-02). With `at` inside the level, Keen is set down there (a copy's start
## moved; the level being made is not changed).
func play_request(title: String = "", at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if level == null:
		error = "no level"
		return {}
	end_stroke()
	var lv: KeenLevel = level
	if level.in_bounds(at.x, at.y):
		lv = level.copy()
		place_start(at.x, at.y, lv)
	if start_at(lv).x < 0:
		error = "Keen has nowhere to start: place his start first"
		return {}
	var f: Dictionary = files(lv)
	if f.is_empty():
		return {}
	var found: Dictionary = {"id": game_id, "title": title if title != "" else game_id, "folder": folder,
		"version": version, "play_level": number}
	if engine == KeenLevel.VORTICONS:
		found["maker_files"] = f
	else:
		found["maker_maps"] = f
	return found
