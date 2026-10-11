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
## V15-04's rules: the most creatures, items and platforms a level may hold, the engine's object table
## less Keen and ten for what the level makes as it plays (shots, sparks, spawned helpers): Keen 1-3's
## MAXOBJECTS 80, Keen 4-6's CK_MAX_OBJECTS 100, Dreams' MAXACTORS 100 (each engine quits or runs out
## when its table is full)
const OBJECT_LIMIT: Dictionary = {KeenLevel.VORTICONS: 80 - 11, KeenLevel.GALAXY: 100 - 11, KeenLevel.DREAMS: 100 - 11}
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
## V15-04's clear check: the level's fingerprint when the player last finished it from Keen's start
## ("" never); it holds only while the level is unchanged since
var cleared_hash: String = ""
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
	_all_levels = []
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
		for entry: Array in level_list():
			_all_levels.append(original(int(entry[0])))
	error = ""
	return true


## The game's levels, for the ground brush's shapes the slot's own level lacks
var _all_levels: Array = []


## The level's fingerprint (its size and planes).
func fingerprint(l: KeenLevel = null, slot: int = -9999) -> String:
	var target: KeenLevel = l if l != null else level
	if target == null:
		return ""
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(("%d %d %d" % [number if slot == -9999 else slot, target.width, target.height]).to_ascii_buffer())
	for words: PackedInt32Array in target.planes:
		h.update(LevelCodec.words_to_bytes(words))
	return h.finish().hex_encode()


## Whether the player has finished the level as it is now, from Keen's start (V15-04's clear check).
func is_cleared() -> bool:
	return cleared_hash != "" and cleared_hash == fingerprint()


## After a play: whether the game ended with the level finished (Keen 1-3's LevelDone ex_completed,
## Keen 4-6's levelState LS_LevelComplete, Dreams' playstate levelcomplete). Played from Keen's start,
## a finish clears the level as it is.
func note_play(engine_obj: Object, from_start: bool) -> bool:
	var won: bool = false
	if engine_obj is GalGame:
		won = int((engine_obj as GalGame).ck_gameState.levelState) == GalCK.LS_LevelComplete
	elif engine_obj is DreamsGame:
		won = int((engine_obj as DreamsGame).playstate) == DrmDecl.levelcomplete
	elif engine_obj != null and engine_obj.get("LevelDone") != null:
		won = int(engine_obj.get("LevelDone")) == 1    # ex_completed
	if won and from_start:
		cleared_hash = fingerprint()
	return won


func _reset() -> void:
	cleared_hash = ""
	if parts != null and original(number) != null:
		parts.learn_brush([original(number)], _all_levels)
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
	cleared_hash = str(got.meta.get("cleared", ""))
	return true


## Saves the level into the library (a new file the first time). False with `error`.
func save_doc() -> bool:
	if level == null:
		error = "no level"
		return false
	end_stroke()
	var lib: MakerLibrary = MakerLibrary.new()
	var to: String = path if path != "" else MakerLibrary.new_path(game_id)
	if not lib.save(to, level, {"game": game_id, "name": doc_name, "slot": number, "origin": origin, "cleared": cleared_hash}, trail):
		error = lib.error
		return false
	path = to
	dirty = false
	return true


## The game's level a remix was made from (-1 for a new level).
func remixed_from() -> int:
	return int(origin.substr(6)) if origin.begins_with("remix ") else -1


## The level slots a level can play as (its music and the level's own behaviour come with the slot):
## [number, name], the world maps and Keen 1-3's title and ending maps left out.
func slot_choices() -> Array:
	return level_list().filter(func(e: Array) -> bool:
		return (int(e[0]) < 80) if engine == KeenLevel.VORTICONS else int(e[0]) > 0)


## The level plays as slot `n` (the level's settings); a new level takes that map's name with it.
func set_slot(n: int) -> bool:
	var base: KeenLevel = original(n)
	if level == null or base == null or n == number:
		return base != null and n == number
	number = n
	level.number = n
	if origin == "new":
		level.name = base.name
		level.fields = base.fields.duplicate(true)
	dirty = true
	return true


## V15-04: the level as a file to share (.keenlevel, JSON): a remix as its changes only (each cell that
## differs from the game's own level, with that level's fingerprint so the receiver's copy is checked to
## be the same), applied to the receiver's own game, so no level data of the game leaves the sender; a
## new level whole (all of it the player's). Only a cleared level is shared. "" with `error`.
func share_text() -> String:
	if level == null:
		error = "no level"
		return ""
	if not is_cleared():
		error = "Finish it from Keen's start first (the clear check), then share it."
		return ""
	var from: int = remixed_from()
	var doc: Dictionary = {"megarocket_share": 1, "game": game_id, "name": doc_name, "slot": number, "origin": origin,
		"from": from, "width": level.width, "height": level.height}
	var base: KeenLevel = original(from) if from >= 0 else null
	if base != null and base.width == level.width and base.height == level.height:
		var changes: PackedInt32Array = PackedInt32Array()
		for p: int in range(level.planes.size()):
			for i: int in range(level.width * level.height):
				if level.planes[p][i] != base.planes[p][i]:
					changes.append_array(PackedInt32Array([p, i, level.planes[p][i]]))
		doc["kind"] = "changes"
		doc["base"] = fingerprint(base, from)
		doc["changes"] = Marshalls.raw_to_base64(changes.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))
		doc["count"] = changes.size() / 3
	else:
		doc["kind"] = "whole"
		doc["fields"] = level.fields
		var planes: Array = []
		for words: PackedInt32Array in level.planes:
			planes.append(Marshalls.raw_to_base64(LevelCodec.words_to_bytes(words).compress(FileAccess.COMPRESSION_DEFLATE)))
		doc["planes"] = planes
	return JSON.stringify(doc)


## Opens a shared level (share_text's) as the level being made, unsaved. False with `error`: another
## game's, or a remix whose game level differs here (another release).
func open_shared(text: String) -> bool:
	var v: Variant = JSON.parse_string(text)
	var doc: Dictionary = v if v is Dictionary else {}
	if int(doc.get("megarocket_share", 0)) != 1:
		error = "That is not a shared Keen Maker level."
		return false
	if str(doc.get("game", "")) != game_id:
		error = "That level is for %s." % str(doc.get("game", "another game"))
		return false
	var n: int = int(doc.get("slot", NEW_SLOT))
	var w: int = int(doc.get("width", 0))
	var h: int = int(doc.get("height", 0))
	var l: KeenLevel = null
	if doc.get("kind", "") == "changes":
		var from: int = int(doc.get("from", n))
		var base: KeenLevel = original(from)
		var same: bool = base != null and fingerprint(base, from) == str(doc.get("base", ""))
		if not same or base.width != w or base.height != h:
			error = "That remix was made from another release of the game: its level %d differs here." % from
			return false
		l = base.copy()
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(doc.get("changes", ""))).decompress(int(doc.get("count", 0)) * 12, FileAccess.COMPRESSION_DEFLATE)
		var changes: PackedInt32Array = raw.to_int32_array()
		if changes.size() != int(doc.get("count", -1)) * 3:
			error = "The shared level's changes are damaged."
			return false
		for k: int in range(0, changes.size(), 3):
			if changes[k] < 0 or changes[k] >= l.planes.size() or changes[k + 1] < 0 or changes[k + 1] >= w * h:
				error = "The shared level's changes are damaged."
				return false
			l.set_word(changes[k], changes[k + 1] % w, changes[k + 1] / w, changes[k + 2])
	else:
		var base: KeenLevel = original(n)
		l = KeenLevel.create(engine, w, h, base.name if base != null else "")
		var planes: Array = doc.get("planes", [])
		if w <= 0 or h <= 0 or planes.size() != l.planes.size():
			error = "The shared level is damaged."
			return false
		for p: int in range(planes.size()):
			var raw: PackedByteArray = Marshalls.base64_to_raw(str(planes[p])).decompress(w * h * 2, FileAccess.COMPRESSION_DEFLATE)
			if raw.size() != w * h * 2:
				error = "The shared level is damaged."
				return false
			l.planes[p] = LevelCodec.bytes_to_words(raw)
		var fields: Variant = doc.get("fields", {})
		if fields is Dictionary:
			for k: String in fields:
				l.fields[k] = int(fields[k])
	l.number = n
	level = l
	number = n
	doc_name = str(doc.get("name", "Shared level"))
	origin = str(doc.get("origin", "new"))
	path = ""
	_reset()
	dirty = true
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


## The objects the level places (the marker plane's creatures, items and platforms).
func objects(l: KeenLevel = null) -> int:
	var target: KeenLevel = l if l != null else level
	if target == null or parts == null:
		return 0
	var plane: int = START_PLANE[engine]
	var n: int = 0
	for v: int in target.planes[plane]:
		if v != 0 and parts.marker_name(v) != "":
			n += 1
	return n


## V15-04: why a part may not go at (x, y), at once and in words ("" when it may): outside the level;
## Keen's start painted as a part (the start tool keeps him to one); one object more than the engine holds.
func refusal(plane: int, x: int, y: int, value: int) -> String:
	if level == null or not level.in_bounds(x, y):
		return "That's outside the level."
	if plane == START_PLANE[engine] and value in START_MARKERS[engine]:
		return "Keen starts in one place: use the Keen start tool."
	if plane == START_PLANE[engine] and parts != null and parts.marker_name(value) != "" 			and parts.marker_name(level.get_word(plane, x, y)) == "" and objects() >= OBJECT_LIMIT[engine]:
		return "No room: the game holds %d creatures, items and platforms in a level." % OBJECT_LIMIT[engine]
	return ""


## V15-04: what would spoil a play, in words: no start; a door whose key or gem is nowhere in the level
## (Keen 1-3: a door's keycard, intile 2-5 and 18-21; Keen 4-6: a gem holder's gem, misc 7-10 and info
## 57-60). Empty when there is nothing.
func problems() -> Array:
	var out: Array = []
	if level == null:
		return out
	if start_at().x < 0:
		out.append("Keen has nowhere to start.")
	if parts == null or engine == KeenLevel.DREAMS:
		return out
	var colours: Array = ["yellow", "red", "green", "blue"] if engine == KeenLevel.VORTICONS else ["red", "yellow", "blue", "green"]
	var tp: int = parts.tile_plane()
	var doors: Dictionary = {}
	var keys: Dictionary = {}
	for i: int in range(level.width * level.height):
		var u: int = parts.props(level.planes[tp][i]).use
		if engine == KeenLevel.VORTICONS:
			if u >= 2 and u <= 5:
				doors[u - 2] = true
			elif u >= 18 and u <= 21:
				keys[u - 18] = true
		else:
			if u >= 7 and u <= 10:
				doors[u - 7] = true
			var info: int = level.planes[2][i]
			if info >= 57 and info <= 60:
				keys[info - 57] = true
	for c: int in doors:
		if not keys.has(c):
			out.append("The %s %s has no %s %s in the level." % [colours[c], "door" if engine == KeenLevel.VORTICONS else "gem holder",
				colours[c], "keycard" if engine == KeenLevel.VORTICONS else "gem"])
	return out


func begin_stroke() -> void:
	end_stroke()


func end_stroke() -> void:
	if not _stroke.is_empty():
		_undo.append(_stroke)
		_redo = []
		_stroke = []


## Keen 4-6: the linking tile at `from` (a switch, gem holder or door) set to work on `to` (the info
## plane's (x << 8) | y at its cell), one undo step. False where it can't.
func link(from: Vector2i, to: Vector2i) -> bool:
	if level == null or engine != KeenLevel.GALAXY or not level.in_bounds(from.x, from.y) or not level.in_bounds(to.x, to.y) \
			or not parts.is_linking(level.get_word(1, from.x, from.y)):
		return false
	begin_stroke()
	paint(2, from.x, from.y, (to.x << 8) | to.y)
	end_stroke()
	return true


## V15-04's ground brush: ground put in (on) or taken out of (off: the erased cell left empty) the cell
## at (x, y), and it and the cells round it given the edge, corner or fill piece their shape takes in the
## game's own levels (MakerParts.brush). Part of the current stroke.
func brush_at(x: int, y: int, on: bool) -> bool:
	if level == null or parts == null or not level.in_bounds(x, y):
		return false
	var tp: int = parts.tile_plane()
	if on and not parts.is_ground(level.get_word(tp, x, y)):
		_put_piece(x, y, parts.brush_tile(parts.shape_at(level, x, y)))
	elif not on and parts.is_ground(level.get_word(tp, x, y)):
		paint(0, x, y, int(tile_defaults.get("background", 0)))
		if engine != KeenLevel.VORTICONS:
			paint(1, x, y, 0)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var cx: int = x + dx
			var cy: int = y + dy
			if level.in_bounds(cx, cy) and parts.is_ground(level.get_word(tp, cx, cy)):
				_put_piece(cx, cy, parts.brush_tile(parts.shape_at(level, cx, cy)))
	return true


## A brush piece into a cell (MakerParts.brush_key's form).
func _put_piece(x: int, y: int, key: int) -> void:
	if key < 0:
		return
	if engine == KeenLevel.VORTICONS:
		paint(0, x, y, key)
	else:
		paint(0, x, y, key >> 16)
		paint(1, x, y, key & 0xFFFF)


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
