# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEENMAIN.C and KEENDEF.H from K1n9_Duk3's Reconstructed Commander
# Keen 1-3 Source Code (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortMain
extends VortLib
## The Vorticons engine's main module: the refresh lists (what to draw where
## this frame), level reading into the big buffer, the F-key handlers, the
## status screen, the cheat, Quit and the program's start-up.

# ------------------------------------------------------------- constants

const NUMLEVELS: int = 16
const MAXTEXTLINES: int = 200
const EXTRASCORE: int = 20000
const BIGBUFFERSIZE: int = 0x10000
const MINTICS: int = 6
const MAXTICS: int = 15
const G_T_SHIFT: int = 12
const G_P_SHIFT: int = 8
const TILEGLOBAL: int = 1 << G_T_SHIFT
const PIXGLOBAL: int = 1 << G_P_SHIFT
const WORLDMAP: int = 80
const ENDINGMAP: int = 81
const TITLEMAP: int = 90
const X_TITLE: int = 2 * TILEGLOBAL
const X_ORDER: int = 22 * TILEGLOBAL
const X_STORY: int = 42 * TILEGLOBAL
const X_ID: int = 63 * TILEGLOBAL
const X_HIGH: int = 84 * TILEGLOBAL
const X_APOGEE: int = 104 * TILEGLOBAL
const Y_TITLE: int = 2 * TILEGLOBAL
const Y_ORDER: int = 2 * TILEGLOBAL
const Y_STORY: int = 2 * TILEGLOBAL
const Y_ID: int = 2 * TILEGLOBAL - (TILEGLOBAL >> 2)
const Y_HIGH: int = 2 * TILEGLOBAL
const Y_APOGEE: int = 2 * TILEGLOBAL
const SCREENTIME: int = 2400
const NUMKEYS: int = 4
const NUMCITIES: int = 8
const MAXOBJECTS: int = 80
const MAXPOBJECTS: int = 16
const HIGHSCORE_NUMENTRIES: int = 7
const HIGHSCORE_NAMELENGTH: int = 12

const BLOCK_NONE: int = 0
const BLOCK_LEFT: int = 1
const BLOCK_DOWN: int = 2
const BLOCK_RIGHT: int = 4
const BLOCK_UP: int = 8

# exittype
const ex_nothing: int = 0
const ex_completed: int = 1
const ex_warped: int = 2
const ex_tantalus: int = 3
## The shell's Level select left a level for another (CHEAT-04): no life lost, nothing marked done.
const ex_shellwarp: int = 4

# classtype (nothing and keenobj are the same in every episode; the rest
# are set per episode in `classes`)
const nothing: int = 0
const keenobj: int = 1

# pobjclass
const POBJ_NOTHING: int = 0
const POBJ_OPENDOOR: int = 1
const POBJ_BRIDGE: int = 2
const POBJ_CANNON: int = 3
const POBJ_BLOCKFALL: int = 4      # Keen 1
const POBJ_BORDERFLASH: int = 5    # Keen 1 (4 in Keen 2 and 3)

const CITY_LONDON: int = 0
const CITY_CAIRO: int = 1
const CITY_SYDNEY: int = 2
const CITY_NEWYORK: int = 3
const CITY_PARIS: int = 4
const CITY_ROME: int = 5
const CITY_MOSCOW: int = 6
const CITY_WASHINGTONDC: int = 7


static func TILE_TO_GLOBAL(n: int) -> int:
	return n << G_T_SHIFT


static func GLOBAL_TO_TILE(n: int) -> int:
	return n >> G_T_SHIFT


static func PIXEL_TO_GLOBAL(n: int) -> int:
	return n << G_P_SHIFT


static func GLOBAL_TO_PIXEL(n: int) -> int:
	return n >> G_P_SHIFT


static func TILE_ALIGN(x: int) -> int:
	return x & ~(TILEGLOBAL - 1)


# ----------------------------------------------------------------- types

class Obj:
	var obclass: int = 0
	var active: bool = false
	var x: int = 0
	var y: int = 0
	var left: int = 0
	var top: int = 0
	var right: int = 0
	var bottom: int = 0
	var xmove: int = 0
	var ymove: int = 0
	var xspeed: int = 0
	var yspeed: int = 0
	var health: int = 0
	var baseshape: int = 0
	var shapenum: int = 0
	var temp1: int = 0
	var temp2: int = 0
	var temp3: int = 0
	var temp4: int = 0
	var think: StringName = &""
	var contact: StringName = &""

	func copy_from(o: Obj) -> void:
		obclass = o.obclass
		active = o.active
		x = o.x
		y = o.y
		left = o.left
		top = o.top
		right = o.right
		bottom = o.bottom
		xmove = o.xmove
		ymove = o.ymove
		xspeed = o.xspeed
		yspeed = o.yspeed
		health = o.health
		baseshape = o.baseshape
		shapenum = o.shapenum
		temp1 = o.temp1
		temp2 = o.temp2
		temp3 = o.temp3
		temp4 = o.temp4
		think = o.think
		contact = o.contact

	func clear() -> void:
		copy_from(Obj.new())

	func to_dict() -> Dictionary:
		return {"obclass": obclass, "active": active, "x": x, "y": y, "left": left, "top": top, "right": right,
			"bottom": bottom, "xmove": xmove, "ymove": ymove, "xspeed": xspeed, "yspeed": yspeed, "health": health,
			"baseshape": baseshape, "shapenum": shapenum, "temp1": temp1, "temp2": temp2, "temp3": temp3,
			"temp4": temp4, "think": String(think), "contact": String(contact)}

	func from_dict(d: Dictionary) -> void:
		obclass = d.obclass
		active = d.active
		x = d.x
		y = d.y
		left = d.left
		top = d.top
		right = d.right
		bottom = d.bottom
		xmove = d.xmove
		ymove = d.ymove
		xspeed = d.xspeed
		yspeed = d.yspeed
		health = d.health
		baseshape = d.baseshape
		shapenum = d.shapenum
		temp1 = d.temp1
		temp2 = d.temp2
		temp3 = d.temp3
		temp4 = d.temp4
		think = StringName(d.think)
		contact = StringName(d.contact)


class PObj:
	var x: int = 0
	var y: int = 0
	var type: int = 0
	var temp: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   # temp1..temp12 at 1..12
	var think: StringName = &""

	func clear() -> void:
		x = 0
		y = 0
		type = 0
		temp.fill(0)
		think = &""

	func to_dict() -> Dictionary:
		return {"x": x, "y": y, "type": type, "temp": temp.duplicate(), "think": String(think)}

	func from_dict(d: Dictionary) -> void:
		x = d.x
		y = d.y
		type = d.type
		temp = PackedInt32Array(d.temp)
		think = StringName(d.think)


class GameState:
	const SIZE: int = 92
	var gotJoystick: bool = false
	var gotVacuum: bool = false
	var gotEverclear: bool = false
	var gotPogo: bool = false
	var gotBattery: bool = false
	var keys: Array = [false, false, false, false]
	var leveldone: Array = []
	var lives: int = 0
	var ammo: int = 0
	var score: int = 0
	var worldx: int = 0
	var worldy: int = 0
	var worldoriginx: int = 0
	var worldoriginy: int = 0
	var citySaved: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0]
	var _unused: int = 0

	func _init() -> void:
		leveldone.resize(NUMLEVELS)
		leveldone.fill(false)

	## The original's file layout: sizeof(gametype) is 92 bytes (two-byte
	## booleans and words, four-byte longs, no padding), as a save the original
	## wrote in DOSBox shows (oracle run keen1_savetest_a).
	func to_bytes() -> PackedByteArray:
		var b: PackedByteArray = PackedByteArray()
		for v: bool in [gotJoystick, gotVacuum, gotEverclear, gotPogo, gotBattery]:
			_w16(b, 1 if v else 0)
		for v: bool in keys:
			_w16(b, 1 if v else 0)
		for v: bool in leveldone:
			_w16(b, 1 if v else 0)
		_w16(b, lives)
		_w16(b, ammo)
		_w32(b, score)
		_w32(b, worldx)
		_w32(b, worldy)
		_w32(b, worldoriginx)
		_w32(b, worldoriginy)
		for v: int in citySaved:
			_w16(b, v)
		_w16(b, _unused)
		return b

	func from_bytes(b: PackedByteArray) -> bool:
		if b.size() != SIZE:
			return false
		var o: int = 0
		gotJoystick = _r16(b, o) != 0
		gotVacuum = _r16(b, o + 2) != 0
		gotEverclear = _r16(b, o + 4) != 0
		gotPogo = _r16(b, o + 6) != 0
		gotBattery = _r16(b, o + 8) != 0
		o = 10
		for i: int in range(NUMKEYS):
			keys[i] = _r16(b, o) != 0
			o += 2
		for i: int in range(NUMLEVELS):
			leveldone[i] = _r16(b, o) != 0
			o += 2
		lives = _r16(b, o)
		ammo = _r16(b, o + 2)
		score = _r32(b, o + 4)
		worldx = _r32(b, o + 8)
		worldy = _r32(b, o + 12)
		worldoriginx = _r32(b, o + 16)
		worldoriginy = _r32(b, o + 20)
		o += 24
		for i: int in range(NUMCITIES):
			citySaved[i] = _r16(b, o)
			o += 2
		_unused = _r16(b, o)
		return true

	static func _w16(b: PackedByteArray, v: int) -> void:
		b.append(v & 0xFF)
		b.append((v >> 8) & 0xFF)

	static func _w32(b: PackedByteArray, v: int) -> void:
		for i: int in range(4):
			b.append((v >> (8 * i)) & 0xFF)

	static func _r16(b: PackedByteArray, o: int) -> int:
		var v: int = b[o] | (b[o + 1] << 8)
		return v - 0x10000 if v >= 0x8000 else v

	static func _r32(b: PackedByteArray, o: int) -> int:
		var v: int = b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)
		return v - 0x100000000 if v >= 0x80000000 else v


class HighScores:
	var scores: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var gotJoystick: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var gotBattery: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var gotEverclear: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var gotVacuum: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var citiesSaved: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var _unused: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
	var names: PackedStringArray = ["", "", "", "", "", "", ""]

	## 204 bytes: names[7][13] padded to an even length by the compiler.
	func to_bytes() -> PackedByteArray:
		var b: PackedByteArray = PackedByteArray()
		for v: int in scores:
			GameState._w32(b, v)
		for arr: PackedInt32Array in [gotJoystick, gotBattery, gotEverclear, gotVacuum, citiesSaved, _unused]:
			for v: int in arr:
				GameState._w16(b, v)
		for n: String in names:
			var raw: PackedByteArray = n.to_ascii_buffer()
			raw.resize(13)
			b.append_array(raw)
		b.append(0)
		return b

	func from_bytes(b: PackedByteArray) -> bool:
		if b.size() < 203:
			return false
		var o: int = 0
		for i: int in range(7):
			scores[i] = GameState._r32(b, o)
			o += 4
		for arr_i: int in range(6):
			var arr: PackedInt32Array = PackedInt32Array()
			for i: int in range(7):
				arr.append(GameState._r16(b, o))
				o += 2
			match arr_i:
				0: gotJoystick = arr
				1: gotBattery = arr
				2: gotEverclear = arr
				3: gotVacuum = arr
				4: citiesSaved = arr
				5: _unused = arr
		for i: int in range(7):
			var raw: PackedByteArray = b.slice(o, o + 13)
			var end: int = raw.find(0)
			names[i] = (raw.slice(0, end) if end >= 0 else raw).get_string_from_ascii()
			o += 13
		return true


# ---------------------------------------------------------------- globals

var coverlist: PackedInt32Array = PackedInt32Array()
var coverlistptr: int = 0
var tics: int = 0
var lasttimecount: int = 0
var ox: int = 0
var oy: int = 0
var monxmax: int = 0
var monymax: int = 0
var originxmin: int = 0
var originymin: int = 0
var playerxmax: int = 0
var playerymax: int = 0
var originxmax: int = 0
var originymax: int = 0
var SNDstarted: bool = false
var KBDstarted: bool = false
var resetgame: bool = false
var joystickok: bool = false
var cheatmode: bool = false
## The shell's cheats (CHEAT-01, docs/MENUS.md): each read at one named point; off unless a player
## turns one on from the Options window's Cheats page (headless runs and the oracle comparisons never do).
var cheat_god: bool = false              # read in LevelLoop (each level's start sets cheatmode from it)
var cheat_jump: bool = false             # read in KeenPogoAir (G+O+D's flight on its own)
var cheat_infiniteAmmo: bool = false     # read in KeenShoot
var cheat_infiniteLives: bool = false    # read in WorldMap
var cheat_noClip: bool = false           # read in ClipMoveObon
var cheat_slowMotion: bool = false       # read in LevelLoop
var cheat_freezeEnemies: bool = false    # read in LevelLoop
## The bug-fix toggles (FIX-01, FixesModel): key -> on, set by the host from the player's settings.
## Empty in headless runs and the oracle comparisons: every fix off, the original bug for bug.
var fixes: Dictionary = {}


func fix_on(key: String) -> bool:
	return fixes.get(key, false)


## A game in progress (the world map and its levels): the Cheats rows are greyed otherwise.
var shell_playing: bool = false
## A level in progress (not the world map): Skip this level works only there.
var shell_in_level: bool = false
## Level select's choice (CHEAT-04): the world map enters it next, done or not; 0 for none.
var shell_warp: int = 0
var LevelNumber: int = 0
var lastextra: int = 0
var lastdir: int = 0
var LevelDone: int = ex_nothing
var numobj: int = 0
var objlist: Array[Obj] = []

# the level header (LevelDef), read from the big buffer
var lh_width: int = 0
var lh_height: int = 0
var lh_planes: int = 0
var lh_planesize: int = 0

# from the executable: the tile property tables
var nexttile: PackedInt32Array = PackedInt32Array()
var intile: PackedInt32Array = PackedInt32Array()
var northwall: PackedInt32Array = PackedInt32Array()
var eastwall: PackedInt32Array = PackedInt32Array()
var southwall: PackedInt32Array = PackedInt32Array()
var westwall: PackedInt32Array = PackedInt32Array()

# KEENDEMO.C / KEENACTS.C globals the main module refers to
var gamestate: GameState = GameState.new()
var ankhtime: int = 0
var infoBlockMask: int = 0

## Episode-specific class numbers; filled by the episode class.
var classes: Dictionary = {}


func _init() -> void:
	super()
	coverlist.resize(600)
	for i: int in range(MAXOBJECTS):
		objlist.append(Obj.new())


## The six tables of signed words linked into the executable, in the order
## nexttile, intile, northwall, eastwall, southwall, westwall.
func _load_tileinfo() -> void:
	var n: int = data.tileinfo.size() / 12
	var tables: Array = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for k: int in range(6):
		var t: PackedInt32Array = tables[k]
		t.resize(n)
		for i: int in range(n):
			t[i] = s16(data.tileinfo[(k * n + i) * 2] | (data.tileinfo[(k * n + i) * 2 + 1] << 8))
		tables[k] = t
	nexttile = tables[0]
	intile = tables[1]
	northwall = tables[2]
	eastwall = tables[3]
	southwall = tables[4]
	westwall = tables[5]


# ---------------------------------------------------------------- refresh

func RF_Clear() -> void:
	spritesshown = 0
	picsshown = 0
	tilesshown = 0
	spritelist = []
	piclist = []
	tilelist = []
	sprite_world = []
	coverlistptr = 0
	while true:
		tics = u16(timecount - lasttimecount)
		if tics >= MINTICS or exited:
			break
		vm.poll()
	if tics > MAXTICS:
		tics = MAXTICS
	lasttimecount = timecount


func RF_Refresh() -> void:
	VidRefresh()
	if EGApage != 0:
		for i: int in range(coverlistptr):
			oldtiles[coverlist[i]] = -1
	else:
		for i: int in range(coverlistptr):
			oldtiles2[coverlist[i]] = -1


var trace_sprites: int = 0    # tests: sprites still to print


func RF_PlaceSprite(x: int, y: int, shapenum: int) -> bool:
	if trace_frames and trace_sprites > 0:
		trace_sprites -= 1
		print("TRACE sprite x=%d y=%d sx=%d sy=%d shape=%d" % [x, y, (x - originx) >> 8, (y - originy) >> 8, shapenum])
	var px: int = (x / PIXGLOBAL) - ((originx / PIXGLOBAL) & ~15)
	var py: int = (y / PIXGLOBAL) - ((originy / PIXGLOBAL) & ~15)
	if px < -32 or py < -32 or px > 336 or py > 199:
		return false
	var num: int = shapenum * 4 + (px & 7) / 2
	image = spritetable[num]
	px = (px + 32) / 8 - 4
	var tx_min: int = px / 2
	if tx_min < 0:
		tx_min = 0
	elif tx_min > PORTTILESWIDE:
		return false
	var tx_max: int = (px + image.w - 1) / 2
	if tx_max > PORTTILESWIDE:
		tx_max = PORTTILESWIDE
	elif tx_max < 0:
		return false
	var ty_min: int = py / 16
	if ty_min < 0:
		ty_min = 0
	elif ty_min > PORTTILESHIGH:
		return false
	var ty_max: int = (py + image.h - 1) / 16
	if ty_max > PORTTILESHIGH - 1:
		ty_max = PORTTILESHIGH - 1
	elif ty_max < 0:
		return false
	px += 4
	py += 32
	for ty: int in range(ty_min, ty_max + 1):
		for tx: int in range(tx_min, tx_max + 1):
			var tilenum: int = GETTILE(tx + ox, ty + oy, 0)
			var tiletype: int = intile[tilenum] if tilenum < intile.size() else 0
			if tiletype >= 0:
				_cover(ty * PORTTILESWIDE + tx)
			else:
				var t: Array = [tx * 2 + 4, ty * 16 + 32, tilenum]
				if tiletype == -2:
					t[2] = tilenum | 0x8000
					_cover(ty * PORTTILESWIDE + tx)
				tilesshown += 1
				tilelist.append(t)
	spritelist.append([px, py, num])
	if draw_capture:
		sprite_world.append([x, y, shapenum])    # REND-02: where it is, not where the 1x page puts it
	spritesshown += 1
	return true


func _cover(spot: int) -> void:
	if coverlistptr < coverlist.size():
		coverlist[coverlistptr] = spot
	coverlistptr += 1


func RF_PlaceTile(x: int, y: int, tilenum: int) -> bool:
	var px: int = (x / PIXGLOBAL) - ((originx / PIXGLOBAL) & ~15)
	var py: int = (y / PIXGLOBAL) - ((originy / PIXGLOBAL) & ~15)
	if px < -32 or py < -32:
		return false
	px = (px + 32) / 8 - 4
	var tx_min: int = px / 2
	if tx_min < 0:
		tx_min = 0
	elif tx_min > PORTTILESWIDE:
		return false
	var tx_max: int = (px + image.w - 1) / 2     # BUG in the original: the sprite's width
	if tx_max > PORTTILESWIDE - 1:
		tx_max = PORTTILESWIDE - 1
	elif tx_max < 0:
		return false
	var ty_min: int = py / 16
	if ty_min < 0:
		ty_min = 0
	elif ty_min > PORTTILESHIGH - 1:
		return false
	var ty_max: int = (py + image.h - 1) / 16     # and height
	if ty_max > PORTTILESHIGH - 1:
		ty_max = PORTTILESHIGH - 1
	elif ty_max < 0:
		return false
	px += 4
	py += 32
	for ty: int in range(ty_min, ty_max + 1):
		for tx: int in range(tx_min, tx_max + 1):
			_cover(ty * PORTTILESWIDE + tx)
	tilelist.append([px, py, tilenum])
	tilesshown += 1
	return true


# ------------------------------------------------------------- the level

## Loads LEVELnn into the big buffer the way the original does: the
## compressed file at the top, expanded from the bottom.
func ReadLevel(number: int) -> void:
	level = number
	var name: String = ("LEVEL%02d." % number) + data.ext
	var raw: PackedByteArray = data._read(name)
	var expanded: PackedByteArray = data.rlew_expand(raw, name)
	if raw.is_empty() or expanded.is_empty():
		Quit("Error loading " + name + ": " + data.error)
		return
	vm.instructions(_rlew_instructions(raw))
	var top: int = (BIGBUFFERSIZE - 1) - raw.size()
	for i: int in range(raw.size()):
		if top + i < BIGBUFFERSIZE:
			bigbuffer[top + i] = raw[i]
	for i: int in range(mini(expanded.size(), BIGBUFFERSIZE)):
		bigbuffer[i] = expanded[i]
	lh_width = s16(bigbuffer[0] | (bigbuffer[1] << 8))
	lh_height = s16(bigbuffer[2] | (bigbuffer[3] << 8))
	lh_planes = s16(bigbuffer[4] | (bigbuffer[5] << 8))
	lh_planesize = bigbuffer[14] | (bigbuffer[15] << 8)
	for i: int in range(lh_planes):
		mapplane[i] = (i * lh_planesize + 32) & 0xFFFF
	mapwwide = lh_width
	mapheight = lh_height
	mapbwide = mapwwide * 2
	mapwidthextra = mapbwide - 2 * PORTTILESWIDE
	originxmin = 2 * TILEGLOBAL
	originymin = 2 * TILEGLOBAL
	originxmax = TILE_TO_GLOBAL(lh_width - PORTTILESWIDE - 1)
	monxmax = TILE_TO_GLOBAL(lh_width - 2)
	monymax = TILE_TO_GLOBAL(lh_height)
	originymax = TILE_TO_GLOBAL(lh_height - PORTTILESHIGH - 1) + 8 * PIXGLOBAL
	playerxmax = TILE_TO_GLOBAL(lh_width - 3)
	playerymax = TILE_TO_GLOBAL(lh_height)


## IDLIBC's RLEWExpand compiled by Turbo C with far pointers: about 13
## instructions a literal word, 20 to start a run and 7 a word of it.
func _rlew_instructions(raw: PackedByteArray) -> int:
	if raw.size() < 4:
		return 0
	var out_words: int = (raw[0] | (raw[1] << 8) | (raw[2] << 16) | (raw[3] << 24)) / 2
	var i: int = 4
	var made: int = 0
	var n: int = 0
	while made < out_words and i + 1 < raw.size():
		var value: int = raw[i] | (raw[i + 1] << 8)
		i += 2
		if value != 0xFEFE:
			n += 13
			made += 1
		else:
			var count: int = raw[i] | (raw[i + 1] << 8) if i + 1 < raw.size() else 0
			i += 4
			n += 20 + 7 * count
			made += count
	return n


func AskQuit() -> void:
	ClearKeys()
	if level == TITLEMAP:
		ExpWin(12, 1)
		Print("Quit (Y/N)?")
		var c: int = _toupper(Get() & 0xFF)
		if c == 89:   # 'Y'
			Quit("")
	else:
		ExpWin(20, 2)
		Print("Quit to (D)os or\n")
		Print("(T)itle:")
		var c: int = _toupper(Get() & 0xFF)
		if c == 68:   # 'D'
			Quit("")
		if c == 84:   # 'T'
			resetgame = true


static func _toupper(c: int) -> int:
	return c - 32 if c >= 97 and c <= 122 else c


func JoyButton() -> int:
	var portval: int = vm.in8(0x201)
	if (portval & 0x10) == 0:
		return 1
	if (portval & 0x20) == 0:
		return 2
	return 0


## A full-screen picture file straight into video memory, through the big
## buffer (so the level in it is lost, as the original loses it).
func DrawPicFile(filename: String) -> void:
	var raw: PackedByteArray = data._read(filename)
	var expanded: PackedByteArray = data.rle_expand(raw, filename)
	if raw.is_empty() or expanded.is_empty():
		Quit("Error loading " + filename + ": " + data.error)
		return
	for i: int in range(raw.size()):
		if 0x8000 + i < BIGBUFFERSIZE:
			bigbuffer[0x8000 + i] = raw[i]
	for i: int in range(mini(expanded.size(), BIGBUFFERSIZE)):
		bigbuffer[i] = expanded[i]
	var picoff: int = 0
	var screenoff: int = 4
	originx = 0
	originy = 0
	RF_Clear()
	RF_Refresh()
	vm.out16(GC_INDEX, GC_MODE)   # read mode 0 / write mode 0
	var base: int = seg_addr(screenseg, 0)
	for y: int in range(200):
		for plane: int in range(4):
			vm.out8(SC_INDEX, SC_MAPMASK)
			vm.out8(SC_INDEX + 1, 1 << plane)
			vm.card.mem_write_block((base + screenoff) & 0xFFFF, bigbuffer.slice(plane * 0x2000 + picoff, plane * 0x2000 + picoff + 40))
		picoff += 40
		screenoff += SCREENWIDTH
	vm.out8(SC_INDEX, SC_MAPMASK)
	vm.out8(SC_INDEX + 1, 0xF)
	RF_ForceRefresh()


## Checks for an F-key (or Escape) and handles it; true if one was handled.
func DoFkeys() -> bool:
	NoBiosKey(1)
	var oldtime: int = timecount
	var i: int = 0
	match NBKscan & 0x7F:
		KEY_F1:
			PauseSound()
			ClearKeys()
			ShowHelpText()
			i += 1
		KEY_F2:
			PauseSound()
			ClearKeys()
			ExpWin(13, 1)
			Print("Sound (Y/N)?")
			var c: int = _toupper(Get() & 0xFF)
			if c == 78:
				soundmode = 0
			elif c == 89:
				soundmode = 1
			i += 1
		KEY_F3:
			PauseSound()
			ClearKeys()
			# MENU-01: with a player at the controls F3 opens Options (its Controls page keeps
			# the original Keyboard Commands walk); headless, the original
			if get(&"options") != null:
				call(&"OptionsMenu")
			else:
				CalibrateKeys()
			i += 1
		KEY_F4:
			PauseSound()
			ClearKeys()
			CalibrateJoy(1)
			i += 1
		KEY_F5:
			PauseSound()
			SaveMenu()
			i += 1
		KEY_ESC:
			PauseSound()
			AskQuit()
			i += 1
		_:
			return false
	timecount = oldtime
	if i != 0:
		ClearKeys()
		ContinueSound()
		RF_ForceRefresh()
		return true
	return false


func GivePoints(toadd: int) -> void:
	gamestate.score += toadd
	if gamestate.score - lastextra >= EXTRASCORE:
		PlaySound(SND.EXTRAMANSND)
		lastextra = (gamestate.score / EXTRASCORE) * EXTRASCORE
		gamestate.lives += 1


func DoCheat() -> void:
	var oldtime: int = timecount
	ClearKeys()
	ExpWin(26, 4)
	if episode == 1:
		Print("You are now cheating!\n")
		Print("You just got a pogo stick,\n")
		Print("all the key cards, and\n")
		Print("lots of ray gun charges.")
	else:
		Print("You are now cheating!\n")
		Print("You just got all the\n")
		Print("key cards, and lots of\n")
		Print("ray gun charges.")
	gamestate.gotPogo = true
	gamestate.ammo = 100
	for i: int in range(NUMKEYS):
		gamestate.keys[i] = true
	Get()
	RF_ForceRefresh()
	RF_Refresh()
	RF_Refresh()
	timecount = oldtime
	ClearKeys()


func ShowStatusScreen() -> void:
	var oldtime: int = timecount
	ClearKeys()
	if episode == 1:
		ExpWin(28, 13)
		var x: int = sx
		var y: int = sy
		PrintGrey("    SCORE     EXTRA KEEN AT \n")
		sx = x + 12
		PrintGrey(" \n")
		PrintGrey("    KEENS       SHIP PARTS  \n")
		sx = x + 14
		PrintGrey(" \n")
		sx = x + 14
		PrintGrey(" \n")
		sx = x + 14
		PrintGrey(" \n")
		PrintGrey(" RAYGUN   POGO    KEYCARDS  \n")
		sx = x + 8
		PrintGrey(" ")
		sx += 6
		PrintGrey(" \n")
		sx = x + 8
		PrintGrey(" ")
		sx += 6
		PrintGrey(" \n")
		sx = x + 8
		PrintGrey(" ")
		sx += 6
		PrintGrey(" \n")
		PrintGrey(" CHARGE  ")
		sx += 6
		PrintGrey(" \n")
		sx = x + 8
		PrintGrey(" ")
		sx += 6
		PrintGrey(" \n")
		PrintGrey("     PLEASE PRESS A KEY     ")
		var text: String = str(gamestate.score)
		sx = x + 10 - text.length()
		sy = y + 1
		Print(text)
		text = str(lastextra + EXTRASCORE)
		sx = x + 26 - text.length()
		Print(text)
		for i: int in range(mini(gamestate.lives, 6)):
			DrawSprite(x + i * 2 + 1, (y + 3) * 8, S.KEENWALKR1SPR * 4)
		sx = x + 16
		sy = y + 3
		DrawTile(sx, sy * 8 + 4, 448 if gamestate.gotJoystick else 321)
		sx += 3
		DrawTile(sx, sy * 8 + 4, 449 if gamestate.gotBattery else 322)
		sx += 3
		DrawTile(sx, sy * 8 + 4, 450 if gamestate.gotVacuum else 323)
		sx += 3
		DrawTile(sx, sy * 8 + 4, 451 if gamestate.gotEverclear else 324)
		sx = x + 19
		sy = y + 7
		if gamestate.keys[0]:
			DrawTile(sx, sy * 8 + 3, 424)
		if gamestate.keys[1]:
			DrawTile(sx + 4, sy * 8 + 3, 425)
		if gamestate.keys[2]:
			DrawTile(sx, sy * 8 + 21, 426)
		if gamestate.keys[3]:
			DrawTile(sx + 4, sy * 8 + 21, 427)
		DrawTile(x + 3, (y + 7) * 8 + 4, 414)
		sx = x + 3
		sy = y + 11
		PrintInt(gamestate.ammo)
		if gamestate.gotPogo:
			DrawTile(x + 11, (y + 8) * 8 + 4, 415)
	else:
		_status_screen_other()
	ClearKeys()
	NoBiosKey(0)
	RF_ForceRefresh()
	RF_Refresh()
	RF_Refresh()
	ClearKeys()
	timecount = oldtime


## Keen 2 and 3's status screens; the episode classes supply them.
func _status_screen_other() -> void:
	pass


func HandleUserKeys() -> void:
	if keydown[KEY_C] != 0 and keydown[KEY_T] != 0 and keydown[KEY_SPACE] != 0:
		DoCheat()
	if keydown[KEY_G] != 0 and keydown[KEY_O] != 0 and keydown[KEY_D] != 0:
		ClearKeys()
		ExpWin(20, 1)
		cheatmode = not cheatmode
		if cheatmode:
			Print("God mode enabled")
		else:
			Print("God mode disabled")
		Get()
		RF_ForceRefresh()
		if fix_on("god_lurch"):
			lasttimecount = timecount    # V22: the clock starts again after the wait, as the F-key windows do
	elif keydown[KEY_SPACE] != 0:
		PauseSound()
		ShowStatusScreen()
		ContinueSound()


## The original changes to text mode, saves the control panel, restores the
## interrupts, shows the exit screen and leaves to DOS. Here the program
## stops: every loop and wait ends.
func Quit(error: String) -> void:
	vm.card.bios_set_video_mode(3)
	if error == "":
		SaveCtrls()
	exit_message = error
	if KBDstarted:
		vm.int9 = Callable()
	if SNDstarted:
		ShutdownSound()
	exited = true


## The program's start: everything main() does before DemoLoop.
## The machine the oracle recordings were made on, fitted to them
## (tools/timing_score.py, tools/fit_option.py; see the ledger's A17):
## DOSBox Staging's normal core at a fixed 20000 instructions a
## millisecond, its refresh period in thousandths of a timer cycle, and the
## phase of the timer the program reprograms against the refresh.
var dosbox_timing: Dictionary = {"cycles": 20000, "vbl_period": 17024400, "timer_offset": -1442892}


## Puts the machine on the oracle's timing (a test or a faithful-timing option).
func apply_dosbox_timing(overrides: Dictionary = {}) -> void:
	var tm: Dictionary = dosbox_timing.duplicate()
	tm.merge(overrides, true)
	vm.set_cycles(int(tm.cycles))
	vm.vbl_period = int(tm.vbl_period)
	vm.timer_offset = int(tm.timer_offset)


## Tests only: called in place of DemoLoop once the program has started up.
var after_startup: Callable = Callable()


func main() -> void:
	# "Joystick not detected"
	var xy: PackedInt32Array = ReadJoystick(1)
	joystickok = xy[0] < 500
	passtobios = true
	videocard = VideoID()
	_load_tileinfo()
	LoadGraphics()
	var i: int = 0
	while i < numtiles:
		match nexttile[i]:
			1:
				for a: int in range(4):
					tile_anim[a * MAXTILES + i] = i << 5
			2:
				tile_anim[0 * MAXTILES + i] = i << 5
				tile_anim[2 * MAXTILES + i] = i << 5
				tile_anim[1 * MAXTILES + i] = (i << 5) + 0x20
				tile_anim[3 * MAXTILES + i] = (i << 5) + 0x20
				i += 1
				tile_anim[0 * MAXTILES + i] = i << 5
				tile_anim[2 * MAXTILES + i] = i << 5
				tile_anim[1 * MAXTILES + i] = (i << 5) - 0x20
				tile_anim[3 * MAXTILES + i] = (i << 5) - 0x20
			4:
				tile_anim[0 * MAXTILES + i] = i << 5
				tile_anim[1 * MAXTILES + i] = (i << 5) + 0x20
				tile_anim[2 * MAXTILES + i] = (i << 5) + 0x40
				tile_anim[3 * MAXTILES + i] = (i << 5) + 0x60
				i += 1
				tile_anim[0 * MAXTILES + i] = i << 5
				tile_anim[1 * MAXTILES + i] = (i << 5) + 0x20
				tile_anim[2 * MAXTILES + i] = (i << 5) + 0x40
				tile_anim[3 * MAXTILES + i] = (i << 5) - 0x20
				i += 1
				tile_anim[0 * MAXTILES + i] = i << 5
				tile_anim[1 * MAXTILES + i] = (i << 5) + 0x20
				tile_anim[2 * MAXTILES + i] = (i << 5) - 0x40
				tile_anim[3 * MAXTILES + i] = (i << 5) - 0x20
				i += 1
				tile_anim[0 * MAXTILES + i] = i << 5
				tile_anim[1 * MAXTILES + i] = (i << 5) - 0x60
				tile_anim[2 * MAXTILES + i] = (i << 5) - 0x40
				tile_anim[3 * MAXTILES + i] = (i << 5) - 0x20
		i += 1
	InitRndT(true)
	InitRnd(true)
	StartupSound()
	SNDstarted = true
	vm.int9 = Callable(self, "Int9ISR")
	KBDstarted = true
	LoadCtrls()
	playermode[1] = keyboard
	screencenterx = SCREENWIDTH / 2 - 1
	cyclespeed = 7
	timecount = 0
	lasttimecount = 0
	if after_startup.is_valid():
		after_startup.call()    # a test drives the game from here instead of the demo loop
		return
	DemoLoop()


## KEENDEMO.C's entry point; the demo module supplies it.
func DemoLoop() -> void:
	pass


## KEENSCRN.C's; the screens module supplies them.
func ShowHelpText() -> void:
	pass


func SaveMenu() -> void:
	pass
