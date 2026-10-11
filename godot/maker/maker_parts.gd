# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerParts
extends RefCounted
## PREP-01's tiles named by use, and the maker's parts palette (V15-02): every tile of the chosen game
## sorted by what it does, worked out at run time from the engine's own tile properties in the player's
## files (Keen 1-3: the tile info linked into the program, its walls and "intile" behaviour; Keen 4-6:
## TILEINFO, the foreground's four edges and misc flag; Keen Dreams: the tile info at the end of the map
## header in KDREAMS.EXE). Nothing here is stored: the tables are made when a game is opened. The info
## plane's parts (creatures, items, platforms) are the engines' own spawn numbers (each engine's level
## scan: LoadLevel's switch, CKn_ScanInfoLayer, HandleInfo), named for the palette.
## Also the game's data object, shared with MakerTiles so the files are read once.

const GROUND: String = "Ground"
const SLOPES: String = "Slopes"
const PLATFORMS: String = "Platforms"
const POLES: String = "Poles"
const HAZARDS: String = "Hazards"
const DOORS: String = "Doors, keys and gems"
const ITEMS: String = "Items"
const ENEMIES: String = "Creatures"
const MOVING: String = "Moving platforms"
const EXIT: String = "Exit"
const SCENERY: String = "Scenery"
const BACKGROUND: String = "Background"
const SPECIAL: String = "Special"
## The palette's order: by use, as a player looks for parts.
const ORDER: Array = [GROUND, SLOPES, PLATFORMS, POLES, HAZARDS, DOORS, ITEMS, ENEMIES, MOVING, EXIT, SCENERY, BACKGROUND, SPECIAL]

## The marker planes' parts by game: value -> name (each creature's always-present number: the engines
## add others for the harder difficulties). Keen's start is the tool of its own.
const INFO_PARTS: Dictionary = {
	"keen1": {ENEMIES: {1: "Yorp", 2: "Garg", 3: "Vorticon", 4: "Butler robot", 5: "Tank robot",
		6: "Ice cannon up-right", 7: "Ice cannon up", 8: "Ice cannon up-left", 9: "Ice cannon left", 10: "Chain"}},
	"keen2": {ENEMIES: {1: "Vorticon grunt", 2: "Vorticon youth", 3: "Vorticon elite", 4: "Scrub", 5: "Guard robot", 7: "Spark"},
		MOVING: {6: "Platform"}},
	"keen3": {ENEMIES: {1: "Vorticon grunt", 2: "Vorticon youth", 3: "Vorticon mother", 4: "Meep", 5: "Vorticon ninja",
		6: "Foob", 7: "Ball", 8: "Jack", 11: "Vorticon grunt", 13: "Heart", 14: "Turret right", 15: "Turret down"},
		MOVING: {9: "Platform across", 10: "Platform up and down"}},
	"keen4": {ENEMIES: {21: "Mad mushroom", 22: "Poison slug", 13: "Eggbird egg", 77: "Eggbird", 20: "Arachnut",
		8: "Skypest", 7: "Wormmouth", 9: "Thundercloud", 5: "Berkeloid", 10: "Inchworm", 12: "Bounder", 14: "Lick",
		18: "Smirky", 19: "Mimrock", 15: "Dopefish", 16: "Schoolfish", 17: "Sprite", 69: "Mine", 53: "Dart gun up",
		54: "Dart gun right", 55: "Dart gun down", 56: "Dart gun left"},
		MOVING: {27: "Platform up", 28: "Platform right", 29: "Platform down", 30: "Platform left", 32: "Falling platform"},
		ITEMS: {57: "Red gem", 58: "Yellow gem", 59: "Blue gem", 60: "Green gem", 61: "100 points", 62: "200 points",
			63: "500 points", 64: "1000 points", 65: "2000 points", 66: "5000 points", 67: "Extra life", 68: "Stunner ammo"},
		SPECIAL: {6: "Princess Lindsey", 4: "Council member", 35: "Wetsuit", 42: "Keen swimming (start)"}},
	"keen5": {ENEMIES: {4: "Sparky", 7: "Shikadi mine", 10: "Slicestar across", 22: "Slicestar up and down",
		19: "Slicestar diagonal", 13: "Robo Red", 16: "Spirogrip", 42: "Ampton", 45: "Laser turret up", 46: "Laser turret right",
		47: "Laser turret down", 48: "Laser turret left", 71: "Volte-face", 74: "Shelley", 77: "Spindred",
		88: "Shikadi Master", 99: "Shikadi", 102: "Shockshund", 105: "Sphereful", 124: "Korath"},
		MOVING: {27: "Platform up", 28: "Platform right", 29: "Platform down", 30: "Platform left", 32: "Falling platform",
			33: "Standing platform", 36: "Go platform up", 37: "Go platform right", 38: "Go platform down", 39: "Go platform left",
			40: "Sneaky platform"},
		ITEMS: {57: "Red gem", 58: "Yellow gem", 59: "Blue gem", 60: "Green gem", 61: "100 points", 62: "200 points",
			63: "500 points", 64: "1000 points", 65: "2000 points", 66: "5000 points", 67: "Extra life", 68: "Stunner ammo",
			70: "Keycard"}},
	"keen6": {ENEMIES: {4: "Bloog", 7: "Blooglet", 18: "Fleex", 41: "Bobba", 47: "Nospike", 50: "Gik",
		53: "Turret up", 54: "Turret right", 55: "Turret down", 56: "Turret left", 70: "Orbatrix", 73: "Bip ship",
		76: "Flect", 79: "Blorb", 82: "Ceilick", 85: "Bloogguard", 88: "Grabbiter", 102: "Babobba"},
		MOVING: {27: "Platform up", 28: "Platform right", 29: "Platform down", 30: "Platform left", 32: "Falling platform",
			33: "Standing platform", 36: "Go platform up", 37: "Go platform right", 38: "Go platform down", 39: "Go platform left",
			40: "Sneaky platform"},
		ITEMS: {57: "Red gem", 58: "Yellow gem", 59: "Blue gem", 60: "Green gem", 61: "100 points", 62: "200 points",
			63: "500 points", 64: "1000 points", 65: "2000 points", 66: "5000 points", 67: "Extra life", 68: "Stunner ammo"},
		SPECIAL: {99: "Rope", 100: "Sandwich", 101: "Passcard", 105: "Rocket"}},
	"kdreams": {ENEMIES: {41: "Broccolash", 42: "Tomatooth", 43: "Carrot courier", 45: "Asparagusto", 46: "Grape",
		47: "Tater trooper", 48: "Cart", 49: "Frenchy", 50: "Melon lips", 57: "Squasher", 58: "Apel", 59: "Pea pod",
		60: "Pea brain", 61: "Boobus Tuber"},
		ITEMS: {21: "Bonus 1", 22: "Bonus 2", 23: "Bonus 3", 24: "Bonus 4", 25: "Bonus 5", 26: "Bonus 6", 27: "Bonus 7",
			28: "Bonus 8", 29: "Bonus 9", 30: "Bonus 10", 31: "Boobus bomb", 32: "Bonus 12"},
		EXIT: {33: "Exit door"}},
}

## V15-02: the sprite each marker shows in the maker, the one its creature, item or platform first shows in
## the game (each engine's spawn code: Keen 1-3's shapenum, Keen 4-6's first action's left chunk, Dreams'
## first state's left shape), by its name in the engine's own tables (VortNamesN.sprites(), GFXCHUNK's
## SPR_ numbers, DrmDecl's chunk constants). The pictures come from the player's files when drawn. A marker
## with none (the dart guns, ice cannons and turrets, which the game never draws) keeps its named box.
const SPRITES: Dictionary = {
	"keen1": {1: "YORPSTAND1SPR", 2: "GARGSTAND1SPR", 3: "VORTSTAND1SPR", 4: "CANSTAND1SPR", 5: "TANKSTAND1SPR", 10: "CHAINSPR"},
	"keen2": {1: "GRUNTSTAND1SPR", 2: "YOUTHLEFT1SPR", 3: "ELITELEFT1SPR", 4: "SCRUBL1SPR", 5: "GUARDSTAND1SPR", 6: "PLATFORM1SPR", 7: "SPARK1SPR"},
	"keen3": {1: "GRUNTSTAND1SPR", 2: "YOUTHLEFT1SPR", 3: "WOMANL1SPR", 4: "MEEPL1SPR", 5: "NINJAL1SPR", 6: "FOOBL1SPR", 7: "BALLSPR",
		8: "JACK1SPR", 9: "PLATFORM1SPR", 10: "PLATFORM1SPR", 11: "GRUNTSTAND1SPR", 12: "SPARK1SPR"},
	"keen4": {4: "SPR_MEMBERSHUFFLEL1", 5: "SPR_BERKEFLOATL1", 6: "SPR_LINDSEY1", 7: "SPR_WORMOUTHHINT", 8: "SPR_SKYPESTL1",
		9: "SPR_CLOUDSTERSLEEP", 10: "SPR_FOOT", 12: "SPR_BOUNDERFACE1", 13: "SPR_EGG", 14: "SPR_LICKLEAPL3", 15: "SPR_DOPEFISHL1",
		16: "SPR_SCHOOLFISHL1", 17: "SPR_SPRITEFACE", 18: "SPR_EATERSTAND1", 19: "SPR_MIMROCKSIT", 20: "SPR_ARACHNUT1",
		21: "SPR_MADMUSHROOML1", 22: "SPR_SLUGL1", 27: "SPR_PLATFORM", 28: "SPR_PLATFORM", 29: "SPR_PLATFORM", 30: "SPR_PLATFORM",
		32: "SPR_PLATFORM", 35: "SPR_SCUBAGEAR", 42: "SPR_KEENSWIML1", 69: "SPR_MINE", 77: "SPR_EGGBIRDWALKL1"},
	"keen5": {4: "SPR_SPARKYL1", 7: "SPR_SHIKADIMINE", 10: "SPR_SLICESTAR", 13: "SPR_ROBOREDL", 16: "SPR_SPIROGRABD", 19: "SPR_SLICESTAR",
		22: "SPR_SLICESTAR", 27: "SPR_PURPLEPLAT1", 28: "SPR_PURPLEPLAT1", 29: "SPR_PURPLEPLAT1", 30: "SPR_PURPLEPLAT1", 32: "SPR_PLATFORM",
		33: "SPR_PLATFORM", 36: "SPR_PURPLEPLAT1", 37: "SPR_PURPLEPLAT1", 38: "SPR_PURPLEPLAT1", 39: "SPR_PURPLEPLAT1", 40: "SPR_PLATFORM",
		42: "SPR_AMPTONWALKL1", 71: "SPR_VOLTEFACE1", 74: "SPR_SHELLEYL1", 77: "SPR_SPINDRED1", 88: "SPR_MASTER1", 99: "SPR_SHIKADI1",
		102: "SPR_PETRUNL1", 105: "SPR_SPHEREFUL1", 124: "SPR_KORATHWALKL1", 70: "SPR_SECURITYCARD_1"},
	"keen6": {4: "SPR_BLOOGWALKL1", 7: "SPR_RBLOOGLETWALKL1", 18: "SPR_FLEEXWALKL1", 27: "SPR_PLATFORM", 28: "SPR_PLATFORM",
		29: "SPR_PLATFORM", 30: "SPR_PLATFORM", 32: "SPR_PLATFORM", 33: "SPR_PLATFORM", 36: "SPR_PLATFORM", 37: "SPR_PLATFORM",
		38: "SPR_PLATFORM", 39: "SPR_PLATFORM", 40: "SPR_PLATFORM", 41: "SPR_BOBBAL2", 47: "SPR_NOSPIKESTAND", 50: "SPR_GIKWALKL1",
		70: "SPR_ORBATRIXL1", 73: "SPR_BIPSHIPL", 76: "SPR_FLECTWALKL1", 79: "SPR_BLORB1", 82: "SPR_CEILICKTONGUE1",
		85: "SPR_BLOOGUARDWALKL1", 88: "SPR_MAPGRABBITERSLEEP1", 99: "SPR_HOOK", 100: "SPR_SANDWICH", 101: "SPR_PASSCARD",
		102: "SPR_BABOBBAL2", 105: "SPR_ROCKET"},
	"kdreams": {33: "DOORSPR", 41: "BROCCOLASHRUNL1SPR", 42: "TOMATOOTHL1SPR", 43: "CARROTRUNL1SPR", 45: "ASPARAGUSRUNL1SPR",
		46: "GRAPEONVINESPR", 47: "TATERTROOPWALKL1SPR", 48: "CANTCARTL1SPR", 49: "FRENCHYRUNL1SPR", 50: "MELONLIPSL1SPR",
		57: "SQUASHERWALKL1SPR", 58: "APELWALKL1SPR", 59: "PEAPODRUNL1SPR", 60: "PEABRAINWALKL1SPR", 61: "BOOBUSWALKL1SPR"},
}
## Keen himself, on the start marker
const KEEN_SPRITE: Dictionary = {"keen1": "KEENWALKR1SPR", "keen2": "KEENWALKR1SPR", "keen3": "KEENWALKR1SPR",
	"keen4": "SPR_KEENSTANDR", "keen5": "SPR_KEENSTANDR", "keen6": "SPR_KEENSTANDR", "kdreams": "KEENSTANDRSPR"}

var game_id: String = ""
var engine: String = ""
var error: String = ""
## The game's data, read once (VortData, GalData or DreamsData).
var vort: VortData = null
var gal: GalData = null
var dreams: DreamsData = null
## Tiles per plane (Keen 1-3: tiles, then the sprite plane's markers; 4-6 and Dreams: background, foreground)
var count: Array = [0, 0]
## The categories: [{name, plane, values: PackedInt32Array, names: {value: name}}], in ORDER.
var categories: Array = []
## tile use by plane: plane -> {value: category name}
var _use: Dictionary = {}


## Reads the game's tile properties (and its graphics' table). "" or the reason it can't.
func open(id: String, folder: String, version: String = "") -> String:
	game_id = id
	engine = MakerModel.ENGINES.get(id, "")
	categories = []
	_use = {}
	match engine:
		KeenLevel.VORTICONS:
			vort = VortData.new()
			if not vort.load_game(folder, "CK" + id.substr(4, 1)):
				return vort.error
			count = [vort.tiles.size() / 256, 0]
		KeenLevel.GALAXY:
			gal = GalData.new()
			if not gal.load_game(folder, MakerModel.meta_dir(id, version)):
				return gal.error
			count = [int(gal.gfx.numTiles16), int(gal.gfx.numTiles16m)]
		KeenLevel.DREAMS:
			dreams = DreamsData.new()
			if not dreams.load_game(folder):
				return dreams.error
			count = [DreamsData.NUMTILE16, DreamsData.NUMTILE16M]
		_:
			return "The maker does not have %s" % id
	_build()
	return ""


## A tile's walls and behaviour: {n, e, s, w (nonzero where solid; Keen 4-6's top is the slope),
## use (Keen 1-3's intile, Keen 4-6's misc & 0x7F, Dreams' intile & 0x7F)}; plane 0 for Keen 1-3, the
## foreground (plane 1) for the others.
func props(tile: int) -> Dictionary:
	match engine:
		KeenLevel.VORTICONS:
			var n: int = vort.tileinfo.size() / 12
			if tile < 0 or tile >= n:
				return {"n": 0, "e": 0, "s": 0, "w": 0, "use": 0}
			return {"n": _vw(2, n, tile), "e": _vw(3, n, tile), "s": _vw(4, n, tile), "w": _vw(5, n, tile), "use": _vw(1, n, tile)}
		KeenLevel.GALAXY:
			var n16: int = count[0]
			var n16m: int = count[1]
			if tile <= 0 or tile >= n16m:
				return {"n": 0, "e": 0, "s": 0, "w": 0, "use": 0}
			var b: int = n16 * 2 + tile
			return {"n": _gb(b), "e": _gb(b + n16m), "s": _gb(b + n16m * 2), "w": _gb(b + n16m * 3), "use": _gb(b + n16m * 5) & 0x7F}
		KeenLevel.DREAMS:
			if tile <= 0 or tile >= DreamsData.NUMTILE16M:
				return {"n": 0, "e": 0, "s": 0, "w": 0, "use": 0}
			var t: PackedByteArray = dreams.map_header()
			var north: int = 502 + DreamsData.NUMTILE16 * 2
			var m: int = DreamsData.NUMTILE16M
			return {"n": _db(t, north + tile), "e": _db(t, north + m + tile), "s": _db(t, north + m * 2 + tile),
				"w": _db(t, north + m * 3 + tile), "use": _db(t, north + m * 5 + tile) & 0x7F}
	return {"n": 0, "e": 0, "s": 0, "w": 0, "use": 0}


func _vw(k: int, n: int, i: int) -> int:
	var o: int = (k * n + i) * 2
	var v: int = vort.tileinfo[o] | (vort.tileinfo[o + 1] << 8)
	return v - 0x10000 if v >= 0x8000 else v


func _gb(i: int) -> int:
	return gal.tileinfo[i] if i >= 0 and i < gal.tileinfo.size() else 0


static func _db(t: PackedByteArray, i: int) -> int:
	return t[i] if i >= 0 and i < t.size() else 0


## The plane a tile part is painted on (Keen 1-3: 0; the others: the foreground, 1).
func tile_plane() -> int:
	return 0 if engine == KeenLevel.VORTICONS else 1


## The marker plane (Keen 1-3's sprites, the others' info).
func marker_plane() -> int:
	return MakerModel.START_PLANE[engine]


## A tile's use by its properties (the palette's category name).
func use_of_tile(tile: int) -> String:
	var p: Dictionary = props(tile)
	var u: int = p.use
	var solid: bool = p.n != 0 or p.e != 0 or p.s != 0 or p.w != 0
	match engine:
		KeenLevel.VORTICONS:
			if u == 1:
				return HAZARDS
			if u in [2, 3, 4, 5, 18, 19, 20, 21]:
				return DOORS
			if (u >= 6 and u <= 16) or u == 22:
				return ITEMS
			if u == 17:
				return EXIT
			if u != 0:
				return SPECIAL
			if p.n != 0 and p.s == 0 and p.e == 0 and p.w == 0:
				return PLATFORMS
			return GROUND if solid else SCENERY
		KeenLevel.GALAXY:
			if u == GalCK.MISCFLAG_POLE:
				return POLES
			if u == GalCK.MISCFLAG_DEADLY:
				return HAZARDS
			if u == GalCK.MISCFLAG_DOOR:
				return EXIT
			if u in [5, 6, 7, 8, 9, 10, 15, 18, 20, 32]:
				return DOORS
			if u == 4 or (u >= 21 and u <= 29):
				return ITEMS
			if u != 0:
				return SPECIAL
			if p.n >= 2 and p.n <= 7:
				return SLOPES
			if p.n != 0 and p.s == 0 and p.e == 0 and p.w == 0:
				return PLATFORMS
			return GROUND if solid else SCENERY
		KeenLevel.DREAMS:
			if u == 1:
				return POLES
			if u != 0:
				return SPECIAL
			if p.n != 0 and p.s == 0 and p.e == 0 and p.w == 0:
				return PLATFORMS
			return GROUND if solid else SCENERY
	return SCENERY


## The category a cell's value belongs to on `plane` ("" for none).
func use_of(plane: int, value: int) -> String:
	return _use.get(plane, {}).get(value, "")


func _build() -> void:
	var by: Dictionary = {}
	var tp: int = tile_plane()
	var use: Dictionary = {}
	var lists: Dictionary = {}
	for t: int in range(1 if engine != KeenLevel.VORTICONS else 0, count[tp] if tp < count.size() else 0):
		var c: String = use_of_tile(t)
		if not lists.has(c):
			lists[c] = []
		(lists[c] as Array).append(t)
		use[t] = c
	for c: String in lists:
		by[c] = {"name": c, "plane": tp, "values": PackedInt32Array(lists[c]), "names": {}}
	_use[tp] = use
	if engine != KeenLevel.VORTICONS:
		var bg: PackedInt32Array = PackedInt32Array()
		for t: int in range(count[0]):
			bg.append(t)
		by[BACKGROUND] = {"name": BACKGROUND, "plane": 0, "values": bg, "names": {}}
	var mp: int = marker_plane()
	var marks: Dictionary = {}
	var info: Dictionary = INFO_PARTS.get(game_id, {})
	for c: String in info:
		var names: Dictionary = info[c]
		var values: PackedInt32Array = PackedInt32Array()
		var keys: Array = names.keys()
		keys.sort()
		for v: int in keys:
			values.append(v)
			marks[v] = c
		var key: String = c + "@info" if by.has(c) else c
		by[key] = {"name": c, "plane": mp, "values": values, "names": names}
	_use[mp] = marks
	for c: String in ORDER:
		for key: String in [c, c + "@info"]:
			if by.has(key):
				categories.append(by[key])


## V15-04's ground brush: for each way a ground cell can have ground beside it (a bit each for above,
## right, below and left: 0-15), the tile the game's own levels use most for it (the top edge, the
## corners, the sides, the fill). Learned from the player's levels when the game is opened; -1 where no
## level has that shape. Keen 4-6 and Dreams draw much of their ground in the background behind solid
## foreground tiles (Dreams' are often blank), so there a brush piece is the pair: background << 16 |
## foreground (brush_key).
var brush: PackedInt32Array = PackedInt32Array()


## Whether a tile is ground for the brush.
func is_ground(tile: int) -> bool:
	return use_of(tile_plane(), tile) == GROUND


## The brush's shape of the cell (x, y) in `l`: bit 1 ground above, 2 right, 4 below, 8 left (outside
## the level counts as ground, as the levels' frames are).
func shape_at(l: KeenLevel, x: int, y: int) -> int:
	var tp: int = tile_plane()
	var bits: int = 0
	var k: int = 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if not l.in_bounds(nx, ny) or is_ground(l.get_word(tp, nx, ny)):
			bits |= 1 << k
		k += 1
	return bits


## Learns the brush from `levels` (the level being made's own slot first, so its pieces are of one
## tileset), each shape no level of them has taken from `fallback` (the game's other levels).
func learn_brush(levels: Array, fallback: Array = []) -> void:
	_learn(levels)
	if fallback.is_empty() or not brush.has(-1):
		return
	var own: PackedInt32Array = brush
	_learn(fallback)
	for i: int in range(16):
		if own[i] >= 0:
			brush[i] = own[i]


func _learn(levels: Array) -> void:
	var tp: int = tile_plane()
	var counts: Array = []
	for i: int in range(16):
		counts.append({})
	# the pieces of the levels' outer ring are left out (Keen 4-6's EDGE OF MAP and the like fill the
	# borders; they are not ground anyone builds with)
	var ring: Dictionary = {}
	for l: KeenLevel in levels:
		if l == null:
			continue
		for y: int in range(l.height):
			for x: int in [0, l.width - 1]:
				ring[brush_key(l, x, y)] = true
		for x: int in range(l.width):
			for y: int in [0, l.height - 1]:
				ring[brush_key(l, x, y)] = true
	for l: KeenLevel in levels:
		if l == null:
			continue
		for y: int in range(l.height):
			for x: int in range(l.width):
				if is_ground(l.get_word(tp, x, y)):
					var c: Dictionary = counts[shape_at(l, x, y)]
					var k: int = brush_key(l, x, y)
					if not ring.has(k):
						c[k] = int(c.get(k, 0)) + 1
	# an edge is not the fill: where a shape's most used piece is the fill's (Dreams fills its solid parts
	# with one dark pair, edges too), its most used other piece
	brush = PackedInt32Array()
	var fill: int = _most(counts[15], -1)
	for i: int in range(16):
		var c: Dictionary = (counts[i] as Dictionary).duplicate()
		if i != 15 and c.size() > 1:
			c.erase(fill)
		brush.append(_most(c, -1))


## A cell's brush piece: Keen 1-3 its tile; the others background << 16 | foreground.
func brush_key(l: KeenLevel, x: int, y: int) -> int:
	if engine == KeenLevel.VORTICONS:
		return l.get_word(0, x, y)
	return (l.get_word(0, x, y) << 16) | l.get_word(1, x, y)


## The piece the brush puts in a cell of shape `bits` (the nearest shape the levels have, by the most bits
## in common, where they lack this one).
func brush_tile(bits: int) -> int:
	if brush.size() == 16 and brush[bits] >= 0:
		return brush[bits]
	var best: int = -1
	var score: int = -1
	for i: int in range(brush.size()):
		if brush[i] >= 0:
			var same: int = 4 - _bits(i ^ bits)
			if same > score:
				best = brush[i]
				score = same
	return best


static func _bits(v: int) -> int:
	var n: int = 0
	while v != 0:
		n += v & 1
		v >>= 1
	return n


## Moves tiles (the ground a new level is made of) to the front of their category, so the palette
## opens on the game's everyday parts.
func put_first(values: Array) -> void:
	var tp: int = tile_plane()
	for c: Dictionary in categories:
		if int(c.plane) != tp:
			continue
		var vals: PackedInt32Array = c.values
		for i: int in range(values.size() - 1, -1, -1):
			var at: int = vals.find(int(values[i]))
			if at > 0:
				vals.remove_at(at)
				vals.insert(0, int(values[i]))
		c.values = vals


## The marker's sprite as an image {w, h, pixels, mask} from the player's files; empty for none.
## Keen 4-6's items (57-68) are CK_SpawnItem's chunks; Dreams' (21-32) its bonusshape table.
func marker_sprite(value: int) -> Dictionary:
	var name: String = ""
	if value in MakerModel.START_MARKERS[engine]:
		name = KEEN_SPRITE.get(game_id, "")
	elif engine == KeenLevel.GALAXY and value >= 57 and value <= 68:
		name = GalAct.CK_ItemSpriteChunks[value - 57]
	else:
		name = SPRITES.get(game_id, {}).get(value, "")
	var bonus: bool = engine == KeenLevel.DREAMS and value >= 21 and value <= 32
	if name == "" and not bonus:
		return {}
	match engine:
		KeenLevel.VORTICONS:
			var names: Dictionary = (VortNames1 if game_id == "keen1" else (VortNames2 if game_id == "keen2" else VortNames3)).sprites()
			var i: int = int(names.get(name, -1))
			return vort.sprites[i] if i >= 0 and i < vort.sprites.size() else {}
		KeenLevel.GALAXY:
			if _gal_images == null:
				_gal_images = GalImages.new(gal)
			return _gal_images.sprite(int(gal.chunk_names.ints.get(name, -1)))
		KeenLevel.DREAMS:
			var chunk: int = int(DreamsGame.bonusshape[value - 21]) if bonus else int((DrmDecl as Script).get_script_constant_map().get(name, -1))
			var i: int = chunk - DreamsData.STARTSPRITES
			return dreams.sprite(i) if i >= 0 and i < dreams.sprite_table.size() else {}
	return {}


var _gal_images: GalImages = null


## The name of a marker value on the marker plane ("" if the palette has none for it).
func marker_name(value: int) -> String:
	for c: Dictionary in categories:
		if c.plane == marker_plane() and c.names.has(value):
			return c.names[value]
	return ""


## Tiles for a new level, chosen from one of the game's own levels by use: the background most used
## (Keen 1-3: the plain tile most used), the ground's top edge (a ground tile with open space above, most
## used) and its fill (one with ground above). {background, top, fill}.
func defaults(level: KeenLevel) -> Dictionary:
	var tp: int = tile_plane()
	var bg_counts: Dictionary = {}
	var top_counts: Dictionary = {}
	var fill_counts: Dictionary = {}
	for y: int in range(1, level.height):
		for x: int in range(level.width):
			var bgv: int = level.get_word(0, x, y)
			var t: int = level.get_word(tp, x, y)
			var above: int = level.get_word(tp, x, y - 1)
			if engine != KeenLevel.VORTICONS or use_of(tp, t) == SCENERY:
				bg_counts[bgv] = int(bg_counts.get(bgv, 0)) + 1
			if use_of(tp, t) == GROUND:
				var p: Dictionary = props(t)
				if p.n == 0 or p.e == 0 or p.s == 0 or p.w == 0:
					continue
				if use_of(tp, above) == GROUND:
					fill_counts[t] = int(fill_counts.get(t, 0)) + 1
				elif engine != KeenLevel.VORTICONS or use_of(tp, above) == SCENERY:
					top_counts[t] = int(top_counts.get(t, 0)) + 1
	var top: int = _most(top_counts, _most(fill_counts, 1))
	return {"background": _most(bg_counts, 0), "top": top, "fill": _most(fill_counts, top)}


static func _most(counts: Dictionary, fallback: int) -> int:
	var best: int = fallback
	var n: int = 0
	for k: int in counts:
		if counts[k] > n or (counts[k] == n and k < best):
			best = k
			n = counts[k]
	return best
