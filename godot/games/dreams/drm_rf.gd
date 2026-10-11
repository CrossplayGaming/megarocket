# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's refresh manager (id_rf.c, id_rf_a.c) as carried in ReflectionHLE, (C) 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
class_name DrmRF
extends DrmVW
## id_rf*.c: tile refresh, scrolling and sprites, the EGA paths. The CGA
## routines, the 2015 release's and the KeenLauncher compositor's calls are
## left out.
##
## The update array: `update` holds both pages' arrays (update[0] at 0,
## update[1] at UPDATESIZE); `updateptr`, `updatestart[2]` and
## `baseupdatestart[2]` are offsets into it.
##
## Sprites: the C's `void **user` is the object whose `sprite` field holds the
## record (an objtype, as `&ob->sprite`, or a `spriteuser` holder); the record
## is a `spritelisttype`, read and stored back through `user.sprite` (null for
## NULL). A record's `prevptr` (the address of whatever points at it) is the
## index of the record before it in its priority list (its `nextsprite`), or
## -1 - priority when it is first (`&prioritystart[priority]`). An animating
## tile's `prevptr` is the index of the tile before it, or -1 for `&animhead`;
## its `chain` is an index into allanims and its `mapplane` a plane number with
## the word offset in `mapofs`. (Indices, not references: no reference cycles.)
##
## Reads past the end of an allocation (a map plane, a missing tile, allanims)
## are guarded, not reproduced (docs/DREAMS_PLAN.md, Memory (a)).

# ===================================================================== id_rf.c

const SCREENTILESWIDE: int = 20
const SCREENTILESHIGH: int = 13

const SCREENSPACE: int = SCREENWIDTH_EGA * 240
const FREEEGAMEM: int = 0x10000 - 3 * SCREENSPACE

# the update array must have enough space for two screens that can float up two tiles each way
const UPDATESCREENSIZE: int = UPDATEWIDE * PORTTILESHIGH + 2
const UPDATESPARESIZE: int = UPDATEWIDE * 2 + 4
const UPDATESIZE: int = UPDATESCREENSIZE + 2 * UPDATESPARESIZE

const G_EGASX_SHIFT: int = 7    # global >> ?? = screen x
const G_SY_SHIFT: int = 4       # global >> ?? = screen y

var SX_T_SHIFT: int = 0         # screen x >> ?? = tile EGA = 1
const SY_T_SHIFT: int = 4       # screen y >> ?? = tile

const EGAPORTSCREENWIDE: int = 42
const PORTSCREENHIGH: int = 224

## When an animated tile's step is stored in a map's info plane, the same 16-bit value as in DOS
## (originally a pointer to a cell of allanims).
var refkeen_compat_id_rf_allanims_table_offset: int = 0


func COMPAT_ALLANIMS_CONVERT_INDEX_TO_DOS_PTR(i: int) -> int:
	return u16(4 * i + refkeen_compat_id_rf_allanims_table_offset)


func COMPAT_ALLANIMS_CONVERT_DOS_PTR_TO_INDEX(dosptr: int) -> int:
	@warning_ignore("integer_division")
	return (dosptr - refkeen_compat_id_rf_allanims_table_offset) / 4


# ---- local types

class spritelisttype:
	var index: int = 0    # its place in spritearray
	var screenx: int = 0
	var screeny: int = 0
	var width: int = 0
	var height: int = 0
	var shift: int = 0    # REFKEEN - New member
	var grseg: int = 0
	var sourceofs: int = 0
	var planesize: int = 0
	var draw: int = 0     # drawtype
	var tilex: int = 0
	var tiley: int = 0
	var tilewide: int = 0
	var tilehigh: int = 0
	var priority: int = 0
	var updatecount: int = 0
	var prevptr: int = 0    # >= 0: spritearray[prevptr].nextsprite; < 0: prioritystart[-1 - prevptr]
	var nextsprite: spritelisttype = null
	# REND-01D: where it is, for the shell's renderers (not the original's): its top-left in units, and
	# its left edge in world pixels as the original draws it (the shifted copy's offset added)
	var ux: int = 0
	var uy: int = 0
	var px: int = 0
	var gen: int = 0    # REND-03: draw_gen when the record was handed out


class eraseblocktype:
	var screenx: int = 0
	var screeny: int = 0
	var width: int = 0
	var height: int = 0


class tiletype:
	var current: int = 0    # foreground tiles have high bit set
	var count: int = 0


class animtiletype:
	var index: int = 0    # its place in animarray
	var x: int = 0
	var y: int = 0
	var tile: int = 0
	var chain: int = 0       # index into allanims
	var mapplane: int = 0    # the map plane (0 or 1) ...
	var mapofs: int = 0      # ... and the word in it
	var prevptr: int = -1    # >= 0: animarray[prevptr].nexttile; -1: animhead
	var nexttile: animtiletype = null


## A `void *` for RF_PlaceSprite's `user` when the caller has no objtype.
class spriteuser:
	var sprite: Variant = null


# ---- local variables

var allanims: Array = _rf_new_allanims()    # tiletype, MAXANIMTYPES
var numanimchains: int = 0

var refreshvector: StringName = &""

var screenpage: int = 0    # screen currently being displayed
var otherpage: int = 0

var spritearray: Array = _rf_new_spritearray()    # spritelisttype, MAXSPRITES
var prioritystart: Array = [null, null, null, null]    # spritelisttype, PRIORITIES
var spritefreeptr: spritelisttype = null

var animarray: Array = _rf_new_animarray()    # animtiletype, MAXANIMTILES
var animhead: animtiletype = null
var animfreeptr: animtiletype = null

var animfreespot: int = 0

## eraselist[2][MAXSPRITES] as one list (eraselist[1][0] at MAXSPRITES); eraselistptr: indices.
var eraselist: Array = _rf_new_eraselist()
var eraselistptr: PackedInt32Array = PackedInt32Array([0, MAXSPRITES])

var baseupdatestart: PackedInt32Array = PackedInt32Array([0, 0])

## RFL_NewTile, set by version and mode (RefKeen_Patch_id_rf_a)
var RFL_NewTile: StringName = &""

## The "comp" parameter (id_rf.c's static ParmStrings; id_vw.c has another).
const ParmStrings_id_rf: PackedStringArray = ["comp", ""]

## BE_Cross's zero segment: what a missing tile reads as.
var _rf_zeroseg: PackedByteArray = _rf_new_zeroseg()


static func _rf_new_allanims() -> Array:
	var a: Array = []
	for i: int in range(MAXANIMTYPES):
		a.append(tiletype.new())
	return a


static func _rf_new_spritearray() -> Array:
	var a: Array = []
	for i: int in range(MAXSPRITES):
		var s: spritelisttype = spritelisttype.new()
		s.index = i
		a.append(s)
	return a


static func _rf_new_animarray() -> Array:
	var a: Array = []
	for i: int in range(MAXANIMTILES):
		var t: animtiletype = animtiletype.new()
		t.index = i
		a.append(t)
	return a


static func _rf_new_eraselist() -> Array:
	var a: Array = []
	for i: int in range(2 * MAXSPRITES):
		a.append(eraseblocktype.new())
	return a


static func _rf_new_zeroseg() -> PackedByteArray:
	var z: PackedByteArray = PackedByteArray()
	z.resize(256)
	return z


## A word of a map plane (0 past its end).
func _rf_mapword(plane: int, ofs: int) -> int:
	var m: PackedInt32Array = mapsegs[plane]
	if ofs < 0 or ofs >= m.size():
		return 0
	return m[ofs] & 0xFFFF


## A byte of the tile info (0 past its end).
func _rf_tinf(i: int) -> int:
	if i < 0 or i >= tinf.size():
		return 0
	return tinf[i]


## A cached graphics chunk's bytes; a missing one reads as the zero segment
## (VANILLA KEEN BUG WORKAROUND, "Empty" tile found in map).
func _rf_grseg(chunk: int) -> PackedByteArray:
	if chunk >= 0 and chunk < grsegs.size() and grsegs[chunk] is PackedByteArray:
		return grsegs[chunk]
	return _rf_zeroseg


## The EGAWRITEMODE / EGAMAPMASK macros of id_vw.h: the card's registers.
func _rf_egawritemode(x: int) -> void:
	vm.out8(EgaCard.GC_INDEX, EgaCard.GC_MODE)
	vm.out8(EgaCard.GC_DATA, x)


func _rf_egamapmask(x: int) -> void:
	vm.out8(EgaCard.SC_INDEX, EgaCard.SC_MAPMASK)
	vm.out8(EgaCard.SC_DATA, x)


## memcpy (eraselistptr[page]++,sprite,sizeof(eraseblocktype))
func _rf_posterase(page: int, sprite: spritelisttype) -> void:
	var i: int = eraselistptr[page]
	while i >= eraselist.size():    # past eraselist[1]: the C overruns, the port grows
		eraselist.append(eraseblocktype.new())
	var b: eraseblocktype = eraselist[i]
	b.screenx = sprite.screenx
	b.screeny = sprite.screeny
	b.width = sprite.width
	b.height = sprite.height
	eraselistptr[page] = i + 1


## *prevptr = value, for a sprite record's prevptr.
func _rf_storesprite(prevptr: int, value: spritelisttype) -> void:
	if prevptr < 0:
		prioritystart[-1 - prevptr] = value
	else:
		(spritearray[prevptr] as spritelisttype).nextsprite = value


## *prevptr = value, for an animating tile's prevptr.
func _rf_storeanim(prevptr: int, value: animtiletype) -> void:
	if prevptr < 0:
		animhead = value
	else:
		(animarray[prevptr] as animtiletype).nexttile = value


# ===================================================================== GRMODE independant routines

func RF_Startup() -> void:
	_rf_storage()
	if grmode == EGAGR:
		# id0_argv[i] of the C is id0_argv[i - 1] here (the arguments after the name)
		for i: int in range(1, id0_argc()):
			if US_CheckParm(id0_argv[i - 1], ParmStrings_id_rf) == 0:
				compatability = true
				break

	for i: int in range(PORTTILESHIGH):
		uwidthtable[i] = UPDATEWIDE * i

	originxmin = MAPBORDER * TILEGLOBAL
	originymin = originxmin

	eraselistptr[0] = 0
	eraselistptr[1] = MAXSPRITES

	if grmode == EGAGR:
		SX_T_SHIFT = 1

		baseupdatestart[0] = UPDATESPARESIZE
		baseupdatestart[1] = UPDATESIZE + UPDATESPARESIZE

		screenpage = 0
		otherpage = 1
		displayofs = screenstart[screenpage]
		bufferofs = screenstart[otherpage]
		masterofs = screenstart[2]

		updateptr = baseupdatestart[otherpage]

		var blockstart: int = 0
		for y: int in range(UPDATEHIGH):
			for x: int in range(UPDATEWIDE):
				blockstarts[blockstart] = SCREENWIDTH_EGA * 16 * y + x * TILEWIDTH_EGA
				blockstart += 1

		xpanmask = 6    # dont pan to odd pixels


## The C's static storage of the shared tables (sized once; screenstart's initializer
## {0,SCREENSPACE,SCREENSPACE*2}).
func _rf_storage() -> void:
	if update.size() != 2 * UPDATESIZE:
		update.resize(2 * UPDATESIZE)
		update.fill(0)
	if blockstarts.size() != UPDATEWIDE * UPDATEHIGH:
		blockstarts.resize(UPDATEWIDE * UPDATEHIGH)
		blockstarts.fill(0)
	if updatemapofs.size() != UPDATEWIDE * UPDATEHIGH:
		updatemapofs.resize(UPDATEWIDE * UPDATEHIGH)
		updatemapofs.fill(0)
	if uwidthtable.size() != PORTTILESHIGH:
		uwidthtable.resize(PORTTILESHIGH)
		uwidthtable.fill(0)
	if mapbwidthtable.size() != MAXMAPHEIGHT:
		mapbwidthtable.resize(MAXMAPHEIGHT)
		mapbwidthtable.fill(0)
	if tilecache.size() != NUMTILE16:
		tilecache.resize(NUMTILE16)
		tilecache.fill(0)
	if screenstart.size() != 3 or (screenstart[0] == 0 and screenstart[1] == 0 and screenstart[2] == 0):
		screenstart = PackedInt32Array([0, SCREENSPACE, SCREENSPACE * 2])


func RF_Shutdown() -> void:
	pass


## Makes some convienient calculations based on maphead.
func RF_NewMap() -> void:
	var hdr: maptype = mapheaderseg[mapon]
	mapwidth = u16(hdr.width)
	mapbyteswide = u16(2 * mapwidth)
	mapheight = u16(hdr.height)
	mapwordsextra = u16(mapwidth - PORTTILESWIDE)
	mapbytesextra = u16(2 * mapwordsextra)

	# make a lookup table for the maps left edge
	var spot: int = 0
	for i: int in range(mapheight):
		if i < mapbwidthtable.size():    # (a map over MAXMAPHEIGHT high overruns in the C)
			mapbwidthtable[i] = spot
		spot = u16(spot + mapbyteswide)

	# fill in updatemapofs with the new width info
	var table: int = 0
	for y: int in range(PORTTILESHIGH):
		for x: int in range(UPDATEWIDE):
			updatemapofs[table] = u16(mapbwidthtable[y] + x * 2)
			table += 1

	# the y max value clips off the bottom half of a tile so a map that is
	# 13 + MAPBORDER*2 tile high will not scroll at all vertically
	originxmax = u16((mapwidth - MAPBORDER - SCREENTILESWIDE) * TILEGLOBAL)
	originymax = u16((mapheight - MAPBORDER - SCREENTILESHIGH) * TILEGLOBAL)
	if originxmax < originxmin:    # for very small maps
		originxmax = originxmin
	if originymax < originymin:
		originymax = originymin

	# clear out the lists
	RFL_InitSpriteList()
	RFL_InitAnimList()

	lasttimecount = s32(SD_GetTimeCount())    # setup for adaptive timing
	tics = 1


## Goes through mapplane[0/1] and marks all background/foreground tiles needed, then follows all
## animation sequences to make sure animated tiles get all the stages. Every unique animating tile
## is given an entry in allanims[], so every instance of that tile will animate at the same rate.
## The info plane for each animating tile will hold a pointer into allanims[], therefore you can't
## have both an animating foreground and background tile in the same spot!
func RF_MarkTileGraphics() -> void:
	for a: tiletype in allanims:
		a.current = 0
		a.count = 0
	numanimchains = 0

	var size: int = u16(mapwidth * mapheight)
	var info: PackedInt32Array = mapsegs[2]

	# background plane
	var pos: int = 0
	while true:
		var tile: int = s16(_rf_mapword(0, pos))
		if tile >= 0:    # <0 is a tile that is never drawn
			_rf_markgrchunk(STARTTILE16 + tile)
			if _rf_tinf(ANIM + tile) != 0:
				# this tile will animated
				var i: int = 0
				var found: bool = false
				while i < numanimchains:
					if (allanims[i] as tiletype).current == tile:
						_rf_setinfo(info, pos, COMPAT_ALLANIMS_CONVERT_INDEX_TO_DOS_PTR(i))
						found = true
						break
					i += 1
				if not found:
					# new chain of animating tiles
					if i >= MAXANIMTYPES:
						mapsegs[2] = info
						Quit("RF_MarkTileGraphics: Too many unique animated tiles!")
						return
					(allanims[i] as tiletype).current = tile
					(allanims[i] as tiletype).count = _rf_tinf(SPEED + tile)
					_rf_setinfo(info, pos, COMPAT_ALLANIMS_CONVERT_INDEX_TO_DOS_PTR(i))
					numanimchains += 1

					var anims: int = 0
					var next: int = s16(tile + s8(_rf_tinf(ANIM + tile)))
					while next != tile:
						_rf_markgrchunk(STARTTILE16 + next)
						next = s16(next + s8(_rf_tinf(ANIM + next)))
						anims += 1
						if anims > 20:
							mapsegs[2] = info
							Quit("MarkTileGraphics: Unending animation!")
							return
		pos += 1
		if pos >= size:
			break

	# foreground plane
	pos = 0
	while true:
		var tile: int = s16(_rf_mapword(1, pos))
		if tile >= 0:    # <0 is a tile that is never drawn
			_rf_markgrchunk(STARTTILE16M + tile)
			if _rf_tinf(MANIM + tile) != 0:
				# this tile will animated
				var tilehigh: int = tile | 0x8000    # foreground tiles have high bit
				var i: int = 0
				var found: bool = false
				while i < numanimchains:
					if (allanims[i] as tiletype).current == tilehigh:
						_rf_setinfo(info, pos, COMPAT_ALLANIMS_CONVERT_INDEX_TO_DOS_PTR(i))
						found = true
						break
					i += 1
				if not found:
					# new chain of animating tiles
					if i >= MAXANIMTYPES:
						mapsegs[2] = info
						Quit("RF_MarkTileGraphics: Too many unique animated tiles!")
						return
					(allanims[i] as tiletype).current = tilehigh
					(allanims[i] as tiletype).count = _rf_tinf(MSPEED + tile)
					_rf_setinfo(info, pos, COMPAT_ALLANIMS_CONVERT_INDEX_TO_DOS_PTR(i))
					numanimchains += 1

					var anims: int = 0
					var next: int = s16(tile + s8(_rf_tinf(MANIM + tile)))
					while next != tile:
						_rf_markgrchunk(STARTTILE16M + next)
						next = s16(next + s8(_rf_tinf(MANIM + next)))
						anims += 1
						if anims > 20:
							mapsegs[2] = info
							Quit("MarkTileGraphics: Unending animation!")
							return
		pos += 1
		if pos >= size:
			break
	mapsegs[2] = info


## CA_MarkGrChunk (id_ca.h's macro).
func _rf_markgrchunk(chunk: int) -> void:
	if chunk >= 0 and chunk < grneeded.size():
		grneeded[chunk] |= ca_levelbit


func _rf_setinfo(info: PackedInt32Array, pos: int, value: int) -> void:
	if pos < info.size():
		info[pos] = value


## Call to clear out the entire animating tile list and return all of them to the free list.
func RFL_InitAnimList() -> void:
	animfreeptr = animarray[0]
	var i: int = 0
	while i < MAXANIMTILES - 1:
		(animarray[i] as animtiletype).nexttile = animarray[i + 1]
		i += 1
	(animarray[i] as animtiletype).nexttile = null
	animhead = null    # nothing in list


func RFL_CheckForAnimTile(x: int, y: int) -> void:
	# the info plane of each animating tile has a near pointer into allanims[]
	# which gives the current state of all concurrently animating tiles
	@warning_ignore("integer_division")
	var offset: int = u16(mapbwidthtable[y] / 2 + x)

	# background
	var tile: int = _rf_mapword(0, offset)
	if _rf_tinf(ANIM + tile) != 0:
		_rf_newanim(x, y, tile, 0, offset)
		if quitting:
			return

	# foreground
	tile = _rf_mapword(1, offset)
	if _rf_tinf(MANIM + tile) != 0:
		_rf_newanim(x, y, tile, 1, offset)


## RFL_CheckForAnimTile's link of a new animating tile at the start of the list.
func _rf_newanim(x: int, y: int, tile: int, plane: int, offset: int) -> void:
	if animfreeptr == null:
		Quit("RF_CheckForAnimTile: No free spots in tilearray!")
		return
	var anim: animtiletype = animfreeptr
	animfreeptr = animfreeptr.nexttile
	var next: animtiletype = animhead    # stick it at the start of the list
	animhead = anim
	if next != null:
		next.prevptr = anim.index
	anim.nexttile = next
	anim.prevptr = -1    # &animhead

	anim.x = x
	anim.y = y
	anim.tile = tile
	anim.mapplane = plane
	anim.mapofs = offset
	anim.chain = COMPAT_ALLANIMS_CONVERT_DOS_PTR_TO_INDEX(_rf_mapword(2, offset))


func RFL_RemoveAnimsOnX(x: int) -> void:
	var current: animtiletype = animhead
	while current != null:
		if current.x == x:
			_rf_storeanim(current.prevptr, current.nexttile)
			if current.nexttile != null:
				current.nexttile.prevptr = current.prevptr
			var next: animtiletype = current.nexttile
			current.nexttile = animfreeptr
			animfreeptr = current
			current = next
		else:
			current = current.nexttile


func RFL_RemoveAnimsOnY(y: int) -> void:
	var current: animtiletype = animhead
	while current != null:
		if current.y == y:
			_rf_storeanim(current.prevptr, current.nexttile)
			if current.nexttile != null:
				current.nexttile.prevptr = current.prevptr
			var next: animtiletype = current.nexttile
			current.nexttile = animfreeptr
			animfreeptr = current
			current = next
		else:
			current = current.nexttile


func RFL_AnimateTiles() -> void:
	# animate the lists of tiles (the C runs on to the first empty entry; the port stops at
	# the end of allanims)
	var a: int = 0
	while a < MAXANIMTYPES and (allanims[a] as tiletype).current != 0:
		var anim: tiletype = allanims[a]
		anim.count = s16(anim.count - tics)
		while anim.count < 1:
			var tile: int
			if anim.current & 0x8000:
				tile = anim.current & 0x7fff
				tile = u16(tile + s8(_rf_tinf(MANIM + tile)))
				anim.count = s16(anim.count + _rf_tinf(MSPEED + tile))
				tile |= 0x8000
			else:
				tile = anim.current
				tile = u16(tile + s8(_rf_tinf(ANIM + tile)))
				anim.count = s16(anim.count + _rf_tinf(SPEED + tile))
			anim.current = tile
		a += 1

	# traverse the list of animating tiles
	var current: animtiletype = animhead
	while current != null:
		var tile: int = current.tile
		if current.chain >= 0 and current.chain < MAXANIMTYPES:
			tile = (allanims[current.chain] as tiletype).current
		if tile != current.tile:
			# tile has animated
			#
			# remove tile from master screen cache,
			# change a tile to its next state, set the structure up for
			# next animation, and post an update region to both update pages
			current.tile = tile

			var m: PackedInt32Array = mapsegs[current.mapplane]    # change in map
			if current.mapofs < m.size():
				m[current.mapofs] = tile & 0x7fff
				mapsegs[current.mapplane] = m

			if tile < 0x8000:    # background
				tilecache[tile] = 0

			var x: int = u16(current.x - originxtile)
			var y: int = u16(current.y - originytile)

			if x >= PORTTILESWIDE or y >= PORTTILESHIGH:
				Quit("RFL_AnimateTiles: Out of bounds!")
				return

			var updateofs: int = uwidthtable[y] + x
			call(RFL_NewTile, updateofs)    # puts "1"s in both pages
		current = current.nexttile


## Call to clear out the entire sprite list and return all of them to the free list.
func RFL_InitSpriteList() -> void:
	spritefreeptr = spritearray[0]
	var i: int = 0
	while i < MAXSPRITES - 1:
		(spritearray[i] as spritelisttype).nextsprite = spritearray[i + 1]
		i += 1
	(spritearray[i] as spritelisttype).nextsprite = null

	# NULL in all priority levels
	prioritystart = [null, null, null, null]


## REFKEEN - New function, used after swapping CGA/EGA graphics from the 2015 port.
func RF_RefreshSpriteList() -> void:
	for priority: int in range(PRIORITIES):
		var sprite: spritelisttype = prioritystart[priority]
		while sprite != null:
			var block: PackedByteArray = _rf_grseg(sprite.grseg)
			var shift: int = sprite.shift
			sprite.width = s16(VW_GetSpriteShiftWidth(block, shift))
			sprite.sourceofs = VW_GetSpriteShiftSourceOffset(block, shift)
			sprite.planesize = VW_GetSpriteShiftPlaneSize(block, shift)
			sprite = sprite.nextsprite


## Calculate all the global variables for a new position. Long parms so position can be clipped
## to a maximum near 64k.
func RFL_CalcOriginStuff(x: int, y: int) -> void:
	if x < originxmin:
		x = originxmin
	elif x > originxmax:
		x = originxmax

	if y < originymin:
		y = originymin
	elif y > originymax:
		y = originymax

	originxglobal = u16(x)
	originyglobal = u16(y)
	originxtile = originxglobal >> G_T_SHIFT
	originytile = originyglobal >> G_T_SHIFT
	originxscreen = u16(originxtile << SX_T_SHIFT)
	originyscreen = u16(originytile << SY_T_SHIFT)
	# (a map under 17 tiles high leaves originymax unclamped: the C reads past mapbwidthtable)
	var bwidth: int = mapbwidthtable[originytile] if originytile < mapbwidthtable.size() else 0
	originmap = u16(bwidth + originxtile * 2)

	if GRMODE == EGAGR:
		panx = (originxglobal >> G_P_SHIFT) & 15
		pansx = panx & 8
		pany = (originyglobal >> G_P_SHIFT) & 15
		pansy = pany
		@warning_ignore("integer_division")
		panadjust = u16(panx / 8 + ylookup[pany])


func RF_SetRefreshHook(hook: StringName) -> void:
	refreshvector = hook


## Bring a new row of tiles onto the port, spawning animating tiles.
func RFL_NewRow(dir: int) -> void:
	var count: int
	var updatespot: int
	var updatestep: int
	var x: int
	var y: int
	var xstep: int
	var ystep: int

	match dir:
		0:    # top row
			updatespot = 0
			updatestep = 1
			x = originxtile
			y = originytile
			xstep = 1
			ystep = 0
			count = PORTTILESWIDE
		1:    # right row
			updatespot = PORTTILESWIDE - 1
			updatestep = UPDATEWIDE
			x = originxtile + PORTTILESWIDE - 1
			y = originytile
			xstep = 0
			ystep = 1
			count = PORTTILESHIGH
		2:    # bottom row
			updatespot = UPDATEWIDE * (PORTTILESHIGH - 1)
			updatestep = 1
			x = originxtile
			y = originytile + PORTTILESHIGH - 1
			xstep = 1
			ystep = 0
			count = PORTTILESWIDE
		3:    # left row
			updatespot = 0
			updatestep = UPDATEWIDE
			x = originxtile
			y = originytile
			xstep = 0
			ystep = 1
			count = PORTTILESHIGH
		_:
			Quit("RFL_NewRow: Bad dir!")
			return

	while count > 0:
		count -= 1
		call(RFL_NewTile, updatespot)
		RFL_CheckForAnimTile(x, y)
		if quitting:
			return
		updatespot += updatestep
		x = s16(x + xstep)
		y = s16(y + ystep)


func RF_ForceRefresh() -> void:
	call(RF_NewPosition, originxglobal, originyglobal)
	call(RF_Refresh)
	call(RF_Refresh)


# ===================================================================== EGA specific routines

func RF_NewPosition_EGA(x: int, y: int) -> void:
	# calculate new origin related globals
	RFL_CalcOriginStuff(x, y)

	_draw_extra = Rect2i()    # REND-09: every block painted again on both pages, nothing drawn over the play is left

	# clear out all animating tiles
	RFL_InitAnimList()

	# set up the new update arrays at base position
	tilecache.fill(0)    # old cache is invalid

	updatestart[0] = baseupdatestart[0]
	updatestart[1] = baseupdatestart[1]

	var page0ptr: int = updatestart[0] + PORTTILESWIDE    # used to stick "0"s after rows
	var page1ptr: int = updatestart[1] + PORTTILESWIDE

	var updatenum: int = 0    # start at first visable tile

	for my: int in range(PORTTILESHIGH):
		for mx: int in range(PORTTILESWIDE):
			RFL_NewTile_EGA(updatenum)    # puts "1"s in both pages
			RFL_CheckForAnimTile(mx + originxtile, my + originytile)
			if quitting:
				return
			updatenum += 1
		updatenum += 1
		update[page0ptr] = 0    # set a 0 at end of a line of tiles
		update[page1ptr] = 0
		page0ptr += PORTTILESWIDE + 1
		page1ptr += PORTTILESWIDE + 1
	# REFKEEN - Safe unaligned accesses (UPDATETERMINATE)
	update[page0ptr - PORTTILESWIDE] = 1
	update[page1ptr - PORTTILESWIDE] = 1
	page0ptr += 1
	page1ptr += 1
	update[page0ptr - PORTTILESWIDE] = 3
	update[page1ptr - PORTTILESWIDE] = 3


## REND-01R: the master screen copied to another place (the compatibility mode's move): its record too.
func _draw_master_moved(from: int, to: int) -> void:
	var moved: Dictionary = {}
	for y: int in range(PORTTILESHIGH):
		for x: int in range(PORTTILESWIDE):
			var o: int = u16(from + blockstarts[y * UPDATEWIDE + x])
			if _draw_master.has(o):
				moved[u16(to + blockstarts[y * UPDATEWIDE + x])] = _draw_master[o]
	_draw_master.merge(moved, true)


## Uncache the trailing row of tiles. `updatespot` and `step` are in bytes, both even.
func RFL_OldRow(updatespot: int, count: int, step: int) -> void:
	var backptr: int = updatespot    # inside background plane
	var foreptr: int = updatespot    # inside foreground plane
	var loopvar: int = count
	while loopvar != 0:
		# if a foreground tile, block wasn't cached so we don't clear
		if _rf_mapword(1, foreptr >> 1) == 0:
			# tile is no longer in master screen cache
			tilecache[_rf_mapword(0, backptr >> 1)] = 0
		loopvar -= 1
		foreptr += step
		backptr += step


## Move the origin x/y global coordinates, readjust the screen panning, and scroll if needed. If
## the scroll distance is greater than one tile, the entire screen will be redrawn (this could be
## generalized, but scrolling more than one tile per refresh is a bad idea!).
func RF_Scroll_EGA(x: int, y: int) -> void:
	var oldxt: int = originxtile
	var oldyt: int = originytile
	var oldoriginmap: int = originmap
	var oldpanadjust: int = panadjust
	var oldpanx: int = panx

	RFL_CalcOriginStuff(originxglobal + x, originyglobal + y)

	var deltax: int = s16(originxtile - oldxt)
	var absdx: int = absi(deltax)
	var deltay: int = s16(originytile - oldyt)
	var absdy: int = absi(deltay)

	if absdx > 1 or absdy > 1:
		# scrolled more than one tile, so start from scratch
		RF_NewPosition_EGA(originxglobal, originyglobal)
		return

	if absdx == 0 and absdy == 0:
		return    # the screen has not scrolled an entire tile

	# adjust screens and handle SVGA crippled compatability mode
	var screenmove: int = s16(deltay * 16 * SCREENWIDTH_EGA + deltax * TILEWIDTH_EGA)
	for i: int in range(3):
		screenstart[i] = u16(screenstart[i] + screenmove)
		if compatability and screenstart[i] > 0x10000 - SCREENSPACE:
			# move the screen to the opposite end of the buffer
			var screencopy: int = u16(FREEEGAMEM if screenmove > 0 else -FREEEGAMEM)
			var oldscreen: int = u16(screenstart[i] - screenmove)
			var newscreen: int = u16(oldscreen + screencopy)
			screenstart[i] = u16(newscreen + screenmove)
			VW_ScreenToScreen_EGA(oldscreen, newscreen, PORTTILESWIDE * 2, PORTTILESHIGH * 16)
			if i == 2 and draw_capture:
				_draw_master_moved(oldscreen, newscreen)

			if i == screenpage:
				VW_SetScreen_EGA(u16(newscreen + oldpanadjust), oldpanx & xpanmask)
	bufferofs = screenstart[otherpage]
	displayofs = screenstart[screenpage]
	masterofs = screenstart[2]

	# float the update regions
	var move: int = deltax
	if deltay == 1:
		move += UPDATEWIDE
	elif deltay == -1:
		move -= UPDATEWIDE

	updatestart[0] += move
	updatestart[1] += move

	# draw the new tiles just scrolled on to the master screen, and
	# mark them as needing to be copied to each screen next refreshes
	# Make sure a zero is at the end of each row in update
	if deltax != 0:
		if deltax == 1:
			RFL_NewRow(1)    # new right row
			RFL_OldRow(oldoriginmap, PORTTILESHIGH, mapbyteswide)
			RFL_RemoveAnimsOnX(u16(originxtile - 1))
		else:
			RFL_NewRow(3)    # new left row
			RFL_OldRow(u16(oldoriginmap + (PORTTILESWIDE - 1) * 2), PORTTILESHIGH, mapbyteswide)
			RFL_RemoveAnimsOnX(originxtile + PORTTILESWIDE)
		if quitting:
			return

		var update0: int = updatestart[0] + PORTTILESWIDE
		var update1: int = updatestart[1] + PORTTILESWIDE
		for yy: int in range(PORTTILESHIGH):
			update[update0] = 0    # drop a 0 at end of each row
			update[update1] = 0
			update0 += UPDATEWIDE
			update1 += UPDATEWIDE

	if deltay != 0:
		var updatespot: int
		if deltay == 1:
			RFL_NewRow(2)    # new bottom row
			RFL_OldRow(oldoriginmap, PORTTILESWIDE, 2)
			updatespot = UPDATEWIDE * (PORTTILESHIGH - 1)
			RFL_RemoveAnimsOnY(u16(originytile - 1))
		else:
			RFL_NewRow(0)    # new top row
			RFL_OldRow(u16(oldoriginmap + mapbwidthtable[PORTTILESHIGH - 1]), PORTTILESWIDE, 2)
			updatespot = 0
			RFL_RemoveAnimsOnY(originytile + PORTTILESHIGH)
		if quitting:
			return

		update[updatestart[0] + updatespot + PORTTILESWIDE] = 0
		update[updatestart[1] + updatespot + PORTTILESWIDE] = 0

	# place a new terminator
	var u0: int = updatestart[0] + UPDATEWIDE * PORTTILESHIGH - 1
	var u1: int = updatestart[1] + UPDATEWIDE * PORTTILESHIGH - 1
	update[u0] = 0
	update[u1] = 0
	# REFKEEN - Safe unaligned accesses (UPDATETERMINATE)
	update[u0 + 1] = 1
	update[u1 + 1] = 1
	update[u0 + 2] = 3
	update[u1 + 2] = 3


## `user`: the object whose `sprite` holds the record (see the class comment).
func RF_PlaceSprite_EGA(user: Object, globalx: int, globaly: int, spritenumber: int, draw: int, priority: int) -> void:
	if spritenumber == 0:
		RF_RemoveSprite_EGA(user)
		return

	var sprite: spritelisttype = user.get(&"sprite")
	var next: spritelisttype
	var linknewspot: bool = false

	if sprite != null:
		# sprite allready exists in the list, so we can use it's block
		#
		# post an erase block to both pages by copying screenx,screeny,width,height
		# both pages may not need to be erased if the sprite just changed last frame
		if sprite.updatecount < 2:
			if sprite.updatecount == 0:
				_rf_posterase(otherpage, sprite)
			_rf_posterase(screenpage, sprite)

		if priority != sprite.priority:
			# sprite mvoed to another priority, so unlink the old one and
			# relink it in the new priority
			next = sprite.nextsprite    # cut old links
			if next != null:
				next.prevptr = sprite.prevptr
			_rf_storesprite(sprite.prevptr, next)
			linknewspot = true
	else:
		# this is a brand new sprite, so allocate a block from the array
		if spritefreeptr == null:
			Quit("RF_PlaceSprite: No free spots in spritearray!")
			return

		sprite = spritefreeptr
		spritefreeptr = spritefreeptr.nextsprite
		linknewspot = true
		draw_gen += 1
		sprite.gen = draw_gen

	if linknewspot:
		next = prioritystart[priority]    # stick it in new spot
		if next != null:
			next.prevptr = sprite.index
		sprite.nextsprite = next
		prioritystart[priority] = sprite
		sprite.prevptr = -1 - priority

	# write the new info to the sprite
	var spr: spritetabletype = spritetable[spritenumber - STARTSPRITES]
	var block: PackedByteArray = _rf_grseg(spritenumber)

	globaly = u16(globaly + spr.orgy)
	globalx = u16(globalx + spr.orgx)

	var pixx: int = globalx >> G_SY_SHIFT
	@warning_ignore("integer_division")
	var shift: int = (pixx & 7) / 2

	sprite.screenx = s16(pixx >> (G_EGASX_SHIFT - G_SY_SHIFT))
	sprite.screeny = s16(globaly >> G_SY_SHIFT)
	sprite.width = s16(VW_GetSpriteShiftWidth(block, shift))
	sprite.height = s16(spr.height)
	sprite.grseg = spritenumber
	sprite.sourceofs = VW_GetSpriteShiftSourceOffset(block, shift)
	sprite.planesize = VW_GetSpriteShiftPlaneSize(block, shift)
	sprite.draw = draw
	sprite.priority = priority
	sprite.tilex = u16(sprite.screenx >> SX_T_SHIFT)
	sprite.tiley = u16(sprite.screeny >> SY_T_SHIFT)
	sprite.tilewide = u16(((sprite.screenx + sprite.width - 1) >> SX_T_SHIFT) - sprite.tilex + 1)
	sprite.tilehigh = u16(((sprite.screeny + sprite.height - 1) >> SY_T_SHIFT) - sprite.tiley + 1)

	sprite.updatecount = 2    # draw on next two refreshes

	sprite.shift = shift    # REFKEEN - New member

	# REND-01D: its units, and the column its shifted copy puts it at: two pixels a shift with four
	# copies, four for the upper two with two copies, none with one (CAL_CacheSprite's tables)
	sprite.ux = globalx
	sprite.uy = globaly
	match spr.shifts:
		4:
			sprite.px = (sprite.screenx << 3) + shift * 2
		2:
			sprite.px = (sprite.screenx << 3) + (4 if shift >= 2 else 0)
		_:
			sprite.px = sprite.screenx << 3

	# save the sprite pointer off in the user's pointer so it can be moved again later
	user.set(&"sprite", sprite)


func RF_RemoveSprite_EGA(user: Object) -> void:
	var sprite: spritelisttype = user.get(&"sprite")
	if sprite == null:
		return

	# post an erase block to both pages by copying screenx,screeny,width,height
	# both pages may not need to be erased if the sprite just changed last frame
	if sprite.updatecount < 2:
		if sprite.updatecount == 0:
			_rf_posterase(otherpage, sprite)
		_rf_posterase(screenpage, sprite)

	# unlink the sprite node
	var next: spritelisttype = sprite.nextsprite
	if next != null:    # if (!next), sprite is last in chain
		next.prevptr = sprite.prevptr
	_rf_storesprite(sprite.prevptr, next)

	# add it back to the free list
	sprite.nextsprite = spritefreeptr
	spritefreeptr = sprite

	# null the users pointer, so next time that actor gets placed, it will allocate a new block
	user.set(&"sprite", null)


## Write mode 1 should be set.
func RFL_EraseBlocks_EGA() -> void:
	var blockidx: int = MAXSPRITES if otherpage else 0
	var done: int = eraselistptr[otherpage]

	while blockidx != done:
		var block: eraseblocktype = eraselist[blockidx]
		blockidx += 1
		# clip the block to the current screen view
		block.screenx = s16(block.screenx - originxscreen)
		block.screeny = s16(block.screeny - originyscreen)
		if block.screenx < 0:
			block.width = s16(block.width + block.screenx)
			if block.width < 1:
				continue
			block.screenx = 0
		if block.screeny < 0:
			block.height = s16(block.height + block.screeny)
			if block.height < 1:
				continue
			block.screeny = 0
		var screenxh: int = block.screenx + block.width
		var screenyh: int = block.screeny + block.height
		if screenxh > EGAPORTSCREENWIDE:
			block.width = EGAPORTSCREENWIDE - block.screenx
			screenxh = block.screenx + block.width
		if screenyh > PORTSCREENHIGH:
			block.height = PORTSCREENHIGH - block.screeny
			screenyh = block.screeny + block.height
		if block.width < 1 or block.height < 1:
			continue

		# erase the block by copying from the master screen
		var pos: int = u16(ylookup[block.screeny] + block.screenx)
		VW_ScreenToScreen_EGA(u16(masterofs + pos), u16(bufferofs + pos), block.width, block.height)

		# put 2s in update where the block was, to force sprites to update
		var xtl: int = block.screenx >> SX_T_SHIFT
		var xth: int = (block.screenx + block.width - 1) >> SX_T_SHIFT
		var ytl: int = block.screeny >> SY_T_SHIFT
		var yth: int = (block.screeny + block.height - 1) >> SY_T_SHIFT
		var updatespot: int = updateptr + uwidthtable[ytl] + xtl
		var updatedelta: int = UPDATEWIDE - (xth - xtl + 1)
		for yy: int in range(ytl, yth + 1):
			for xx: int in range(xtl, xth + 1):
				update[updatespot] = 2
				updatespot += 1
			updatespot += updatedelta    # down to next line
	eraselistptr[otherpage] = MAXSPRITES if otherpage else 0


## NOTE: Implement vertical clipping!
func RFL_UpdateSprites_EGA() -> void:
	for priority: int in range(PRIORITIES):
		if priority == MASKEDTILEPRIORITY:
			RFL_MaskForegroundTiles()

		var sprite: spritelisttype = prioritystart[priority]
		while sprite != null:
			var thissprite: spritelisttype = sprite
			sprite = sprite.nextsprite
			# see if the sprite has any visable area in the port
			var portx: int = s16(thissprite.screenx - originxscreen)
			var porty: int = s16(thissprite.screeny - originyscreen)
			var xtl: int = portx >> SX_T_SHIFT
			var xth: int = (portx + thissprite.width - 1) >> SX_T_SHIFT
			var ytl: int = porty >> SY_T_SHIFT
			var yth: int = (porty + thissprite.height - 1) >> SY_T_SHIFT
			if xtl < 0:
				xtl = 0
			if xth >= PORTTILESWIDE:
				xth = PORTTILESWIDE - 1
			if ytl < 0:
				ytl = 0
			if yth >= PORTTILESHIGH:
				yth = PORTTILESHIGH - 1
			if xtl > xth or ytl > yth:
				continue

			# see if it's visable area covers any non 0 update tiles
			var baseupdatespot: int = updateptr + uwidthtable[ytl] + xtl
			var updatespot: int = baseupdatespot
			var updatedelta: int = UPDATEWIDE - (xth - xtl + 1)
			var redraw: bool = false
			if thissprite.updatecount != 0:
				thissprite.updatecount -= 1    # the sprite was just placed,
				redraw = true                  # so draw it for sure
			else:
				for yy: int in range(ytl, yth + 1):
					for xx: int in range(xtl, xth + 1):
						if update[updatespot] != 0:
							redraw = true
							break
						updatespot += 1
					if redraw:
						break
					updatespot += updatedelta    # down to next line
			if not redraw:
				continue    # no need to update

			# set the tiles it covers to 3, because those tiles are being updated
			updatespot = baseupdatespot
			for yy: int in range(ytl, yth + 1):
				for xx: int in range(xtl, xth + 1):
					update[updatespot] = 3
					updatespot += 1
				updatespot += updatedelta    # down to next line

			# draw it!
			var height: int = u16(thissprite.height)
			var sourceofs: int = thissprite.sourceofs
			if porty < 0:
				height = u16(height + porty)    # clip top off
				sourceofs = u16(sourceofs - porty * thissprite.width)
				porty = 0
			elif porty + height > PORTSCREENHIGH:
				height = PORTSCREENHIGH - porty    # clip bottom off

			var dest: int = u16(bufferofs + ylookup[porty] + portx)

			match thissprite.draw:
				spritedraw:
					VW_MaskBlock_EGA(grsegs[thissprite.grseg], sourceofs, dest, thissprite.width, height,
						thissprite.planesize)
				maskdraw:
					pass


## All routines will draw at the port at bufferofs, possibly copying from the port at masterofs.
## The EGA version then page flips. Screenpage is the currently displayed page, not the one being
## drawn; otherpage is the page to be worked with now.
func RF_Refresh_EGA() -> void:
	updateptr = updatestart[otherpage]

	RFL_AnimateTiles()    # DEBUG
	if quitting:
		return

	# update newly scrolled on tiles and animated tiles from the master screen
	_rf_egawritemode(1)
	_rf_egamapmask(15)
	RFL_UpdateTiles()
	RFL_EraseBlocks_EGA()

	# Update is all 0 except where sprites have changed or new area has
	# been scrolled on.  Go through all sprites and update the ones that cover
	# a non 0 update tile
	_rf_egawritemode(0)
	RFL_UpdateSprites_EGA()

	# if the main program has a refresh hook set, call their function before
	# displaying the new page
	var presents: int = _draw_presents
	if refreshvector != &"":
		call(refreshvector)

	# REND-01D: the list of what this refresh drew, for the page flip to present. Not when the hook put
	# pictures on the card itself (v1.10 on: FadeAndUnhook's RF_ForceRefresh, two refreshes of their own,
	# with the tiles animated twice): the page this one flips to is the first of those's, and the map is
	# the second's (REND-01R: kdreams193's level sessions, an animated tile a frame apart); the flip then
	# has no list of its own (a window over the last refresh's page, or none)
	if draw_capture and _draw_presents == presents:
		_capture_draw_list()
	draw_stepped.clear()

	# display the changed screen
	VW_SetScreen_EGA(u16(bufferofs + panadjust), panx & xpanmask)

	# prepare for next refresh
	#
	# Set the update array to the middle position and clear it out to all "0"s
	# with an UPDATETERMINATE at the end
	var newupdate: int = baseupdatestart[otherpage]
	updatestart[otherpage] = newupdate
	@warning_ignore("integer_division")
	var cleared: int = 2 * ((UPDATESCREENSIZE - 2) / 2)
	for i: int in range(cleared):
		update[newupdate + i] = 0
	# REFKEEN - Safe unaligned accesses (UPDATETERMINATE)
	update[newupdate + cleared] = 1
	update[newupdate + cleared + 1] = 3

	screenpage ^= 1
	otherpage ^= 1
	bufferofs = screenstart[otherpage]
	displayofs = screenstart[screenpage]

	# calculate tics since last refresh for adaptive timing
	# REFKEEN - Looks like this is an unsigned comparison in original EXE
	if u32(lasttimecount) > int(SD_GetTimeCount()):
		lasttimecount = s32(SD_GetTimeCount())    # if the game was paused a LONG time
	# REFKEEN - Some replacement
	SD_TimeCountWaitFromSrc(lasttimecount, MINTICS)
	var newtime: int = int(SD_GetTimeCount())
	tics = u16(newtime - lasttimecount)
	lasttimecount = s32(newtime)

	if tics > MAXTICS:
		SD_AddToTimeCount(-(tics - MAXTICS))
		tics = MAXTICS


## A foreground tile drawn over the sprites beneath priority 3 (RFL_MaskForegroundTiles' rule: INTILE's
## high bit), for the shell's renderers.
func RF_ForeMasked(tile: int) -> bool:
	return (_rf_tinf(tile + INTILE) & 0x80) != 0


## REND-01D: the draw list of the refresh being presented (draw_list, drm_vw.gd), as Keen 4-6's
## (gal_rf.gd). The picture's top-left in world pixels (the port's first tile and the panning: the
## panning shows even columns only, xpanmask), the map's two planes over the picture with a tile all
## round and the wide view's tiles each side, and the sprites in the order the refresh draws them
## (priority by priority, each list in order): [x, y (pixels, as the original draws it: the column its
## shifted copy puts it at), chunk, false (nothing is drawn as a white shape), priority, the record's
## slot (the same thing from refresh to refresh), x, y (its top-left in units, for native resolution)].
## The score box is named ("hud") and its image, which the game draws its numbers into, copied as it is
## now ("dyn"). A window drawn over the play since the last full repaint is the list's "overlay" (the
## shell copies that from the card). The refresh hook (FadeAndUnhook) draws nothing: no "user" routine.
func _capture_draw_list() -> void:
	var gx: int = originxtile - 1 - wide_tiles
	var gy: int = originytile - 1
	var gw: int = PORTTILESWIDE + 2 + 2 * wide_tiles
	var gh: int = PORTTILESHIGH + 2
	var bg: PackedInt32Array = PackedInt32Array()
	var fg: PackedInt32Array = PackedInt32Array()
	bg.resize(gw * gh)
	fg.resize(gw * gh)
	var m0: PackedInt32Array = mapsegs[0]
	var m1: PackedInt32Array = mapsegs[1]
	for ty: int in range(gh):
		var y: int = gy + ty
		for tx: int in range(gw):
			var x: int = gx + tx
			var i: int = ty * gw + tx
			var ofs: int = y * mapwidth + x
			if x >= 0 and x < mapwidth and y >= 0 and y < mapheight and ofs < m0.size():
				bg[i] = m0[ofs] & 0xFFFF
				fg[i] = (m1[ofs] & 0xFFFF) if ofs < m1.size() else 0
				# in the port: the background tile the master screen holds there (and the page copied)
				var px: int = x - originxtile
				var py: int = y - originytile
				if fg[i] == 0 and px >= 0 and px < PORTTILESWIDE and py >= 0 and py < PORTTILESHIGH:
					var held: Array = _draw_master.get(u16(masterofs + blockstarts[py * UPDATEWIDE + px]), [])
					if not held.is_empty() and int(held[1]) == 0:
						bg[i] = int(held[0])
			else:
				bg[i] = -1    # past the map
	var sprites: Array = []
	for priority: int in range(PRIORITIES):
		var s: spritelisttype = prioritystart[priority]
		while s != null:
			if s.draw == spritedraw:    # (maskdraw draws nothing)
				sprites.append([s.px, s.screeny, s.grseg, false, priority, s.index, s.ux, s.uy, s.gen])
			s = s.nextsprite
	# REND-03: the records of the objects that stepped (drawn where they are, not slid)
	var step: Array = []
	for o: Object in draw_stepped:
		var o_s: Variant = o.get(&"sprite")
		if o_s is spritelisttype:
			step.append((o_s as spritelisttype).index)
	var hud: int = -1
	var dyn: Dictionary = {}
	if scoreobj != null and scoreobj.sprite is spritelisttype:
		var bs: spritelisttype = scoreobj.sprite
		hud = bs.index
		# the score box's numbers are drawn into its cached image: a copy of the unshifted one as it is now
		var block: PackedByteArray = _rf_grseg(bs.grseg)
		if bs.grseg >= STARTSPRITES and bs.grseg - STARTSPRITES < spritetable.size() and block.size() > MAXSHIFTS_EGA * 6:
			var spr: spritetabletype = spritetable[bs.grseg - STARTSPRITES]
			var so: int = VW_GetSpriteShiftSourceOffset(block, 0)
			dyn[bs.grseg] = block.slice(so, so + spr.width * spr.height * 5)
	var sx: int = originxtile * 16 + (panx & 14)
	var sy: int = originytile * 16 + pany
	# the play (a level): v1.00's title map (map 20) is a screen, as Keen 1-3's title is, shown framed
	_draw_pending = {"t": vm.seconds(), "wide": wide_tiles, "play": mapon != 20,
		"user": "" if refreshvector in [&"", &"FadeAndUnhook"] else String(refreshvector),
		"overlay": _draw_overlay_on(sx, sy),
		"sx": sx, "sy": sy, "ux": originxglobal, "uy": originyglobal, "pan": panx & xpanmask,
		# the columns the camera never crosses (the map's border): the wide view stops at them too
		"xmin": originxmin >> 4, "xmax": (originxmax >> 4) + 320,
		"map": mapon, "gx": gx, "gy": gy, "gw": gw, "gh": gh, "bg": bg, "fg": fg,
		"sprites": sprites, "step": step, "hud": hud, "dyn": dyn,
		"reveal": cheat_revealSecrets, "hud_mid": false}    # the Reveal secrets cheat (the view's alone)


## Patching version-specific stuff (the EGA releases).
func RefKeen_Patch_id_rf() -> void:
	match refkeen_current_gamever:
		BE_GAMEVER_KDREAMSE100:
			refkeen_compat_id_rf_allanims_table_offset = 0xC128
		BE_GAMEVER_KDREAMSE113:
			refkeen_compat_id_rf_allanims_table_offset = 0xC11E
		BE_GAMEVER_KDREAMSE193:
			refkeen_compat_id_rf_allanims_table_offset = 0xC06E
		BE_GAMEVER_KDREAMSE120:
			refkeen_compat_id_rf_allanims_table_offset = 0xC340

	RF_NewPosition = &"RF_NewPosition_EGA"
	RF_Scroll = &"RF_Scroll_EGA"
	RF_PlaceSprite = &"RF_PlaceSprite_EGA"
	RF_RemoveSprite = &"RF_RemoveSprite_EGA"
	RF_Refresh = &"RF_Refresh_EGA"


# ===================================================================== id_rf_a.c

const TILESWIDE: int = 21
const TILESHIGH: int = 14

var screenstartcs: int = 0    # in code segment for accesability


## REND-01R: what each tile place of the master screen holds, by its offset in the card's memory:
## [background, foreground] as drawn there. A background tile drawn from the master screen cache copies
## whatever its cached place holds now, which an animated tile may have changed since (the original's
## cache keeps the old tile's place: AnimateTiles uncaches only the new one), so the pages can show
## another frame of a water tile than the map says (kdreams193 level 4, a column scrolled on); the draw
## list takes the background from here. Presentation only (draw_capture).
var _draw_master: Dictionary = {}


## Draws a composit two plane tile to the master screen and sets the update spot to 1 in both
## update pages, forcing the tile to be copied to the view pages the next two refreshes. Called to
## draw newly scrolled on strips and animating tiles. Assumes write mode 0.
func RFL_NewTile_EGA(updateoffset: int) -> void:
	# mark both update lists at this spot
	update[updatestart[0] + updateoffset] = 1    # page 0 pointer
	update[updatestart[1] + updateoffset] = 1    # page 1 pointer
	# offset in map from origin
	var currmapoffset: int = u16(updatemapofs[updateoffset] + originmap)
	# screen location for tile
	var currtileoffset: int = u16(blockstarts[updateoffset] + masterofs)
	# set screenstartcs to the location in screenseg to draw the tile
	screenstartcs = currtileoffset
	# If either of the tile numbers is 0xFFFF, the tile does not need to
	# be masked together; as one of the planes totally eclipses the other
	var foretilenum: int = _rf_mapword(1, currmapoffset >> 1)
	var backtilenum: int = _rf_mapword(0, currmapoffset >> 1)
	if foretilenum == 0:
		# No foreground tile, so draw a single background tile.
		# Use the master screen cache if possible (CACHETILES)
		if tilecache[backtilenum] != 0:
			# Draw single tile from cache
			var egasrcoff: int = tilecache[backtilenum]
			var egadestoff: int = screenstartcs
			if draw_capture:
				_draw_master[screenstartcs] = _draw_master.get(egasrcoff, [backtilenum, 0])
			for loopvar: int in range(15):
				BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(egadestoff, egasrcoff)
				BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(egadestoff + 1, egasrcoff + 1)
				egasrcoff = u16(egasrcoff + SCREENWIDTH_EGA)
				egadestoff = u16(egadestoff + SCREENWIDTH_EGA)
			BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(egadestoff, egasrcoff)
			BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(egadestoff + 1, egasrcoff + 1)
			return

		# Draw single tile from main memory
		tilecache[backtilenum] = screenstartcs    # next time it can be drawn from here with latch
		if draw_capture:
			_draw_master[screenstartcs] = [backtilenum, 0]
		var backsrc: PackedByteArray = _rf_grseg(STARTTILE16 + backtilenum)
		var backofs: int = 0
		for currentplane: int in range(4):    # draw four planes
			var egadestoff: int = screenstartcs    # start at same place in all planes
			for loopvar: int in range(15):
				BE_ST_EGAUpdateGFXBufferInPlane(egadestoff, backsrc, backofs, TILEWIDTH_EGA, currentplane)
				backofs += TILEWIDTH_EGA
				egadestoff = u16(egadestoff + SCREENWIDTH_EGA)
			BE_ST_EGAUpdateGFXBufferInPlane(egadestoff, backsrc, backofs, TILEWIDTH_EGA, currentplane)
			backofs += TILEWIDTH_EGA
		return

	# Draw a masked tile combo
	if draw_capture:
		_draw_master[screenstartcs] = [backtilenum, foretilenum]
	var back: PackedByteArray = _rf_grseg(STARTTILE16 + backtilenum)
	var fore: PackedByteArray = _rf_grseg(STARTTILE16M + foretilenum)
	var bp: int = 0
	var egadest: int = screenstartcs
	var dataloc: int = 32
	for currentplane: int in range(4):
		var fp: int = 0
		var lineoffset: int = 0
		for loopvar: int in range(16):
			# back - background tile, fore - mask, fore[dataloc] - masked data
			BE_ST_EGAUpdateGFXByteInPlane(egadest + lineoffset, (back[bp] & fore[fp]) | fore[fp + dataloc], currentplane)
			bp += 1
			fp += 1
			BE_ST_EGAUpdateGFXByteInPlane(egadest + lineoffset + 1, (back[bp] & fore[fp]) | fore[fp + dataloc], currentplane)
			bp += 1
			fp += 1
			lineoffset += SCREENWIDTH_EGA
		dataloc += 32


## Scans through the update matrix pointed to by updateptr, looking for 1s. A 1 represents a tile
## that needs to be copied from the master screen to the current screen (a new row or an animated
## tiled). If more than one adjacent tile in a horizontal row needs to be copied, they will be
## copied as a group. Assumes write mode 1.
func RFL_UpdateTiles() -> void:
	var scanptr: int = updateptr
	var scanendptr: int = updateptr + (TILESWIDE + 1) * TILESHIGH + 1
	var iterationstodo: int = 0xFFFF    # definitely scan the entire thing

	while true:
		# scan for a 1 in the update list, meaning a tile needs
		# to be copied from the master screen to the current screen
		while iterationstodo != 0:
			iterationstodo -= 1
			var v: int = update[scanptr]
			scanptr += 1
			if v == 1:
				break

		if scanptr == scanendptr:
			return    # Nothing left
		if update[scanptr] != 1:
			# copy a single tile
			scanptr += 1    # we know the next tile is nothing
			var tileloc: int = blockstarts[scanptr - updateptr - 2]    # start of tile location on screen
			var egadestoff: int = u16(tileloc + bufferofs)    # dest in current screen
			var egasrcoff: int = u16(tileloc + masterofs)     # source in master screen
			for loopvar: int in range(15):
				BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(egadestoff, egasrcoff, TILEWIDTH_EGA)
				egasrcoff = u16(egasrcoff + SCREENWIDTH_EGA)
				egadestoff = u16(egadestoff + SCREENWIDTH_EGA)
			BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(egadestoff, egasrcoff, TILEWIDTH_EGA)
			continue

		# more than one tile in a row needs to be updated, so do it as a group
		var rowscanstartptr: int = scanptr    # hold starting position + 1
		scanptr += 1    # we know the next tile also gets updated
		# see how many more in a row
		while iterationstodo != 0:
			iterationstodo -= 1
			var v: int = update[scanptr]
			scanptr += 1
			if v != 1:
				break
		var bytesperrow: int = u16(2 * (scanptr - rowscanstartptr))
		var tileloc: int = blockstarts[rowscanstartptr - updateptr - 1]    # start of tile location

		var egadestoff: int = u16(tileloc + bufferofs)    # dest in current screen
		var egasrcoff: int = u16(tileloc + masterofs)     # source in master screen
		for loopvar: int in range(15):
			BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(egadestoff, egasrcoff, bytesperrow)
			egasrcoff = u16(egasrcoff + SCREENWIDTH_EGA)
			egadestoff = u16(egadestoff + SCREENWIDTH_EGA)
		BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(egadestoff, egasrcoff, bytesperrow)

		# was 0, now 0xFFFF for above loop
		iterationstodo = 0xFFFF


## Scan through update looking for 3's. If the foreground tile there is a masked foreground tile,
## draw it to the screen.
func RFL_MaskForegroundTiles() -> void:
	var scanptr: int = updateptr
	var scanendptr: int = updateptr + (TILESWIDE + 1) * TILESHIGH + 2
	var iterationstodo: int = 0xFFFF    # definitely scan the entire thing
	while true:
		# scan for a 3 in the updates list
		while iterationstodo != 0:
			iterationstodo -= 1
			var v: int = update[scanptr]
			scanptr += 1
			if v == 3:
				break
		if scanptr == scanendptr:
			return    # Nothing left

		# found a tile, see if it needs to be masked on
		var offsettedoriginmap: int = u16(updatemapofs[scanptr - updateptr - 1] + originmap)
		var foretilenum: int = _rf_mapword(1, offsettedoriginmap >> 1)
		if foretilenum == 0:    # 0 = no foreground tile
			continue
		if not (_rf_tinf(foretilenum + INTILE) & 0x80):    # high bit = masked tile
			continue

		# mask the tile
		planenum = 0

		var tileloc: int = blockstarts[scanptr - updateptr - 1]
		screenstartcs = u16(tileloc + bufferofs)

		var dataloc: int = 32    # data starts 32 bytes after mask

		var src: PackedByteArray = _rf_grseg(STARTTILE16M + foretilenum)
		while true:    # plane loop
			var sp: int = 0
			var egadestoff: int = screenstartcs
			for loopvar: int in range(16):
				BE_ST_EGAUpdateGFXByteInPlane(egadestoff,
					(BE_ST_EGAFetchGFXByteFromPlane(egadestoff, planenum) & src[sp]) | src[sp + dataloc], planenum)
				sp += 1
				egadestoff += 1
				BE_ST_EGAUpdateGFXByteInPlane(egadestoff,
					(BE_ST_EGAFetchGFXByteFromPlane(egadestoff, planenum) & src[sp]) | src[sp + dataloc], planenum)
				sp += 1
				egadestoff += SCREENWIDTH_EGA - 1
			dataloc += 32    # the mask is now further away

			planenum += 1
			if planenum == 4:
				break

		iterationstodo = 0xFFFF    # definitely scan the entire thing


## Patching version-specific stuff.
func RefKeen_Patch_id_rf_a() -> void:
	RFL_NewTile = &"RFL_NewTile_EGA"
