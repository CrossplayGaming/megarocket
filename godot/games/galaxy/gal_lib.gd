# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's id_ca.c (the graphics and map caches: CA_CacheGrChunk,
# CAL_CacheSprite, CAL_ShiftSprite, CA_GetGrChunk, the marks and lumps,
# CA_CacheMap, the tile accessors), id_vl.c (palettes, fades, the surface
# layer and its 8-bit software blits VL_*ToPAL8, as the SDL2 back-end
# id_vl_sdl2.c drives them) and id_vh.c (tiles, bitmaps, sprites, fonts, the
# VHB_* buffer routines) by David Gow and the Omnispeak authors, GPL v2 or
# later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalLib
extends RefCounted
## The Galaxy engine's library layer (SIM-G-01a). Every surface holds one byte
## per pixel (EGA colour 0-15), as omnispeak's reference software path does;
## the screen surface is the RF buffer (21 x 14 tiles), and VL_Present writes
## the 320 x 200 window at the scroll position into the emulated card's hidden
## page and flips to it, so the picture is read back from the card (A3) and
## changes at the retrace that latches the new start address.
##
## The machine (`vm`) and the game files (`data`, a GalData) are set by the
## caller before VL_Startup and CA_Startup.

var vm: DosMachine
var data: GalData


# --------------------------------------------------------------- arithmetic

static func s16(v: int) -> int:
	v &= 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


static func u16(v: int) -> int:
	return v & 0xFFFF


static func s32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


static func u8(v: int) -> int:
	return v & 0xFF


static func CK_Cross_max(a: int, b: int) -> int:
	return a if a > b else b


static func CK_Cross_min(a: int, b: int) -> int:
	return a if a < b else b


# --------------------------------------------------------------- the episode

const EP_Nil: int = 0
const EP_CK4: int = 1
const EP_CK5: int = 2
const EP_CK6: int = 3
## ck_currentEpisode->ep
var ck_currentEpisode_ep: int = EP_Nil


## CK_INT(name, default): an integer from the episode's variable file.
func CK_INT(name: String, default: int) -> int:
	return data.episode.get_int(name, default)


## omnispeak's config values the port sets (OMNISPK.CFG): the original's
## behaviour where omnispeak adds its own. loadingDelay: omnispeak waits 10
## tics at each step of the loading box "because loading is VERY fast on
## omnispeak"; the original waits for its disk and decompression instead,
## which the port charges as costs (TIME-G).
var cfg_values: Dictionary = {"loadingDelay": 0}


## CFG_GetConfigInt: a value set in cfg_values, else omnispeak's default.
func CFG_GetConfigInt(name: String, default: int) -> int:
	return int(cfg_values.get(name, default))


## id_cfg.c: a boolean from omnispeak's config file (GalLib's CFG_GetConfigInt
## gives the default: the port runs without a config file).
func CFG_GetConfigBool(name: String, defValue: bool) -> bool:
	return CFG_GetConfigInt(name, 1 if defValue else 0) != 0


# ===================================================================== id_sd (time)
# The counters id_sd keeps; the timer interrupt that advances sd_timeCount is
# SIM-G-01c's (until then a test advances it).

var sd_timeCount: int = 0
var sd_lastTimeCount: int = 0
var sd_SpriteSync: int = 0


func SD_GetTimeCount() -> int:
	return sd_timeCount


func SD_SetTimeCount(newval: int) -> void:
	sd_timeCount = newval & 0xFFFFFFFF


func SD_GetLastTimeCount() -> int:
	return sd_lastTimeCount


func SD_SetLastTimeCount(newval: int) -> void:
	sd_lastTimeCount = s32(newval)


func SD_GetSpriteSync() -> int:
	return sd_SpriteSync


func SD_SetSpriteSync(newval: int) -> void:
	sd_SpriteSync = newval & 0xFFFF


# ------------------------------------------------- declared here, defined later
# (A function a later script defines but this one calls: the later script
# overrides it. GalDecl will hold these once the whole engine is ported.)

## id_sd: wait for the timer's next interrupt.
func SD_WaitTick() -> void:
	vm.poll()


func SD_PlaySound(_sound: int) -> void:
	pass


## id_in: the demo state (IN_Demo_Off while neither recording nor playing).
const IN_Demo_Off: int = 0
var in_demoState: int = IN_Demo_Off


## id_rf: mark a buffer tile for redraw on `page` (-1: every page).
func RFL_MarkBlockDirty(_x: int, _y: int, _val: int, _page: int) -> void:
	pass


func RFL_IsBlockDirty(_x: int, _y: int, _page: int) -> int:
	return 0


## Time the original's processor spent on work the port does at once
## (decompression, scanning a map): named amounts in machine time units,
## fitted against the oracle's recordings (TIME-G), charged where the work
## happens. Not game state.
var costs: Dictionary = {}


func cost(name: String) -> void:
	var units: int = int(costs.get(name, 0))
	if units > 0:
		vm.cpu_work(units)


## DOSBox time the original spends where the port does none (TIME-G), the same
## engine code in all three episodes: fitted together on keen4_boot_a and the
## seventeen Keen 4 level openings (tools/galaxy_calibrate.py --boot). Huffman
## decoding per compressed (grbyte) and expanded tile (grexp) byte; a sprite's
## shifted copies, per sprite and per byte of them; the rest of a level's set-up
## before its box; clearing the EGA page per byte; a 16x16 tile and a masked one
## rendered; RF_NewPosition beside its tiles; a song started and its bytes
## expanded (the black before a level fades in follows the song's size); the
## story crawl's tables, rows and pixels; the title picture; VW_ClearVideo. A
## test's own values take precedence.
func timing_defaults() -> Dictionary:
	return {"grbyte": 5100, "grexp": 245, "sprchunk": 140000, "sprbyte": 56, "levelload": 74900000,
		"clearbyte": 1200, "tile16": 20000, "tile16m": 20000, "repos": 8000000, "musicload": 7000000,
		"audiobyte": 2900, "swrow": 210000, "swpixel": 2600, "swtables": 27000000, "swstart": 17000000,
		"picbyte": 100, "clearvideo": 51000000}


## costs[name] for each of n things (bytes, chunks).
func cost_n(name: String, n: int) -> void:
	var units: int = int(costs.get(name, 0)) * n
	if units > 0:
		vm.cpu_work(units)


## ck_*/id_us: the program stops with a message.
var quit_message: String = ""
var quitting: bool = false


func Quit(msg: String) -> void:
	if not quitting:
		quitting = true
		quit_message = msg
		# Quit(NULL) is the normal way out; a message is an error exit
		if msg != "":
			push_error("Galaxy engine quit: " + msg)


# ===================================================================== id_ca

const CA_NUMMAPPLANES: int = 3

## GFXINFOE: offsets and counts of every graphics kind (GalData.gfx).
var ca_gfxInfoE: Dictionary = {}
## The cached graphics chunks: null, a PackedByteArray (the expanded chunk) or
## a VH_ShiftedSprite.
var ca_graphChunks: Array = []
var ca_graphChunkNeeded: PackedByteArray = PackedByteArray()
var ca_levelbit: int = 1
var ca_levelnum: int = 0
var ca_mapOn: int = -1
## The current map's three planes, one word per tile.
var CA_mapPlanes: Array = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
## Map headers read so far: {width, height, name}, by map index.
var CA_MapHeaders: Dictionary = {}
var ca_lumpsNeeded: PackedByteArray = PackedByteArray()


## A sprite as CAL_CacheSprite leaves it: the unshifted image, then the
## shifted copies (one byte wider each), five planes each (mask first).
class VH_ShiftedSprite:
	var sprShiftByteWidths: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var sprShiftOffset: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var data: PackedByteArray = PackedByteArray()


func CA_Startup() -> void:
	ca_gfxInfoE = data.gfx
	ca_graphChunks = []
	ca_graphChunks.resize(data.num_chunks)
	ca_graphChunkNeeded = PackedByteArray()
	ca_graphChunkNeeded.resize(data.num_chunks)
	ca_mapOn = -1
	ca_levelbit = 1
	ca_levelnum = 0
	# CAL_SetupGrFile: the three header tables are cached at once and kept. The original
	# allocates each table, reads its chunk into a temporary block and expands it there
	# (the memory manager sees the same: pictable, picmtable, spritetable, compseg)
	var tables: Array = [[int(ca_gfxInfoE.hdrBitmaps), "pictable", int(ca_gfxInfoE.numBitmaps) * 4],
		[int(ca_gfxInfoE.hdrMasked), "picmtable", int(ca_gfxInfoE.numMasked) * 4],
		[int(ca_gfxInfoE.hdrSprites), "spritetable", int(ca_gfxInfoE.numSprites) * 18]]
	for tb: Array in tables:
		MM_GetPtr(tb[1], tb[2])
		MM_GetPtr("compseg", data.chunk_comp_length(tb[0]) + 4)
		CA_CacheGrChunk(tb[0])
		MM_FreePtr("compseg")


func CAL_ShiftSprite(src: PackedByteArray, dst: PackedByteArray, dst_off: int, width: int, height: int, pxShift: int) -> void:
	# The mask plane is filled with 0xFF so the unused bits mask nothing out.
	var d: int = dst_off
	var s: int = 0
	for y: int in range(height):
		dst[d] = 0xFF
		for x: int in range(width):
			var raw_val: int = ((~src[s]) & 0xFF) << 8
			s += 1
			var val: int = (~(raw_val >> pxShift)) & 0xFFFF
			dst[d] = dst[d] & (val >> 8)
			d += 1
			dst[d] = val & 0xFF
		d += 1
	# The data planes are filled with 0; all four shift as one tall plane.
	for y: int in range(height * 4):
		dst[d] = 0
		for x: int in range(width):
			var raw_val: int = src[s] << 8
			s += 1
			var val: int = raw_val >> pxShift
			dst[d] = dst[d] | (val >> 8)
			d += 1
			dst[d] = val & 0xFF
		d += 1


func CAL_CacheSprite(chunkNumber: int) -> void:
	var spriteNumber: int = chunkNumber - int(ca_gfxInfoE.offSprites)
	var sprite: Dictionary = VH_GetSpriteTableEntry(spriteNumber)
	var smallPlane: int = sprite.width * sprite.height
	var bigPlane: int = (sprite.width + 1) * sprite.height
	var fullSize: int = (smallPlane + (sprite.shifts - 1) * bigPlane) * 5
	var shifted: VH_ShiftedSprite = VH_ShiftedSprite.new()
	shifted.data.resize(fullSize)
	var shiftOffsets: PackedInt32Array = PackedInt32Array([0, smallPlane * 5, 0, 0, 0])
	shiftOffsets[2] = shiftOffsets[1] + bigPlane * 5
	shiftOffsets[3] = shiftOffsets[2] + bigPlane * 5
	shiftOffsets[4] = shiftOffsets[3] + bigPlane * 5
	var raw: PackedByteArray = data.chunk(chunkNumber)
	for i: int in range(mini(raw.size(), smallPlane * 5)):
		shifted.data[i] = raw[i]
	match sprite.shifts:
		1:
			for i: int in range(4):
				shifted.sprShiftByteWidths[i] = sprite.width
				shifted.sprShiftOffset[i] = shiftOffsets[0]
		2:
			for i: int in range(2):
				shifted.sprShiftByteWidths[i] = sprite.width
				shifted.sprShiftOffset[i] = shiftOffsets[0]
			for i: int in range(2, 4):
				shifted.sprShiftByteWidths[i] = sprite.width + 1
				shifted.sprShiftOffset[i] = shiftOffsets[1]
			CAL_ShiftSprite(raw, shifted.data, shiftOffsets[1], sprite.width, sprite.height, 4)
		4:
			shifted.sprShiftByteWidths[0] = sprite.width
			shifted.sprShiftByteWidths[1] = sprite.width + 1
			shifted.sprShiftByteWidths[2] = sprite.width + 1
			shifted.sprShiftByteWidths[3] = sprite.width + 1
			for i: int in range(4):
				shifted.sprShiftOffset[i] = shiftOffsets[i]
			CAL_ShiftSprite(raw, shifted.data, shiftOffsets[1], sprite.width, sprite.height, 2)
			CAL_ShiftSprite(raw, shifted.data, shiftOffsets[2], sprite.width, sprite.height, 4)
			CAL_ShiftSprite(raw, shifted.data, shiftOffsets[3], sprite.width, sprite.height, 6)
		_:
			Quit("CAL_CacheSprite: Bad shifts number!")
	ca_graphChunks[chunkNumber] = shifted


## The three header tables are the manager's pictable, picmtable and spritetable, not grsegs.
func _mm_is_table(chunk: int) -> bool:
	return chunk == int(ca_gfxInfoE.hdrBitmaps) or chunk == int(ca_gfxInfoE.hdrMasked) or chunk == int(ca_gfxInfoE.hdrSprites)


## The bytes the original allocates for a chunk: a sprite's shifted copies (CAL_CacheSprite),
## a tile chunk by its kind (CAL_ExpandGrChunk, with the original's tile8 counts), else the
## expanded length the chunk carries.
func _mm_chunk_size(chunk: int, expanded: int) -> int:
	var g: Dictionary = ca_gfxInfoE
	if chunk >= int(g.offSprites) and chunk < int(g.offSprites) + int(g.numSprites):
		var spr: Dictionary = VH_GetSpriteTableEntry(chunk - int(g.offSprites))
		var smallplane: int = int(spr.width) * int(spr.height)
		var bigplane: int = (int(spr.width) + 1) * int(spr.height)
		return 4 * 6 + 5 * (smallplane + (int(spr.shifts) - 1) * bigplane)
	if chunk >= int(g.offTiles8) and chunk < int(g.offBinaries):
		var lay: Dictionary = mm_layout()
		if chunk < int(g.offTiles8m):
			return 32 * int(lay.tile8)
		if chunk < int(g.offTiles16):
			return 40 * int(lay.tile8m)
		if chunk < int(g.offTiles16m):
			return 32 * 4
		if chunk < int(g.offTiles32):
			return 40 * 4
		if chunk < int(g.offTiles32m):
			return 32 * 16
		return 40 * 16
	return expanded


func CA_CacheGrChunk(chunk: int) -> void:
	CA_MarkGrChunk(chunk)
	var managed: bool = mm_started and not _mm_is_table(chunk)
	if ca_graphChunks[chunk] != null:
		if managed:
			MM_SetPurge("gr:%d" % chunk, false)
		return
	if data.chunk_start(chunk) == -1:
		return
	# the file's bytes of the chunk (the length word of a non-tile chunk included), read
	# into the misc buffer or, too big for it, a block of their own
	var filebytes: int = data.chunk_comp_length(chunk) + (0 if data.chunk_exp_length(chunk) != 0 else 4)
	var bigbuffer: bool = managed and filebytes > MM_BUFFERSIZE
	if bigbuffer:
		if not MM_GetPtr("bigbuffer", filebytes):
			return
		MM_SetLock("bigbuffer", true)
	if chunk >= int(ca_gfxInfoE.offSprites) and chunk < int(ca_gfxInfoE.offSprites) + int(ca_gfxInfoE.numSprites):
		if managed and not MM_GetPtr("gr:%d" % chunk, _mm_chunk_size(chunk, 0)):
			if bigbuffer:
				MM_FreePtr("bigbuffer")
			return
		CAL_CacheSprite(chunk)
	else:
		var expanded: PackedByteArray = data.chunk(chunk)
		if data.error != "":
			Quit("Tried to expand an invalid chunk! Make sure you're using a compatible version of Keen!")
			return
		if managed and not MM_GetPtr("gr:%d" % chunk, _mm_chunk_size(chunk, expanded.size())):
			if bigbuffer:
				MM_FreePtr("bigbuffer")
			return
		ca_graphChunks[chunk] = expanded
	# reading and Huffman-expanding the chunk (TIME-G); a sprite is also shifted
	cost("grchunk")
	cost_n("grexp", data.chunk_exp_length(chunk))
	if chunk >= int(ca_gfxInfoE.offSprites) and chunk < int(ca_gfxInfoE.offSprites) + int(ca_gfxInfoE.numSprites):
		cost("sprchunk")
		if costs.has("sprbyte") and ca_graphChunks[chunk] is VH_ShiftedSprite:
			cost_n("sprbyte", (ca_graphChunks[chunk] as VH_ShiftedSprite).data.size())    # the shifted copies, by their size
	cost_n("grbyte", data.chunk_comp_length(chunk))
	if bigbuffer:
		MM_FreePtr("bigbuffer")


func CA_GetGrChunk(base: int, index: int, _chunkType: String, required: bool) -> Variant:
	var chunk: int = base + index
	if chunk < 0 or chunk >= ca_graphChunks.size():
		Quit("tried to render a graphics chunk with invalid ID")
		return null
	var result: Variant = ca_graphChunks[chunk]
	if result == null:
		CA_CacheGrChunk(chunk)
		result = ca_graphChunks[chunk]
		if result == null and required:
			Quit("tried to render an uncached graphics chunk")
	return result


func CA_ClearMarks() -> void:
	for i: int in range(ca_graphChunkNeeded.size()):
		ca_graphChunkNeeded[i] = ca_graphChunkNeeded[i] & ~ca_levelbit


## Every cached chunk made purgeable: the manager may throw it out for room.
func CA_SetGrPurge() -> void:
	if not mm_started:
		return
	for i: int in range(ca_graphChunks.size()):
		if ca_graphChunks[i] != null and not _mm_is_table(i):
			MM_SetPurge("gr:%d" % i, true)


## The map headers and sounds made purgeable, the map planes freed, the graphics too.
func CA_SetAllPurge() -> void:
	CA_ClearMarks()
	if not mm_started:
		return
	for i: int in CA_MapHeaders.keys():
		MM_SetPurge("maphead:%d" % i, true)
	for plane: int in range(CA_NUMMAPPLANES):
		if mm_blocks.has("map:%d" % plane):
			MM_FreePtr("map:%d" % plane)
	for i: int in range(CA_audio.size()):
		if CA_audio[i] != null:
			MM_SetPurge("aud:%d" % i, true)
	CA_SetGrPurge()


func CA_MarkGrChunk(chunk: int) -> void:
	ca_graphChunkNeeded[chunk] = ca_graphChunkNeeded[chunk] | ca_levelbit


## The cache-box callbacks (method names; &"" for NULL). GalCK and later
## scripts set them (ck_main.c: CK_BeginCacheBox ...).
var ca_beginCacheBox: StringName = &""
var ca_updateCacheBox: StringName = &""
var ca_finishCacheBox: StringName = &""


## msg "" is C's NULL (no loading box); every real message is non-empty.
func CA_CacheMarks(msg: String) -> void:
	var isMessage: bool = msg != ""
	var numChunksToCache: int = 0
	# what is needed and cached stays, what is cached and not needed may go
	for i: int in range(ca_graphChunkNeeded.size()):
		if (ca_graphChunkNeeded[i] & ca_levelbit) != 0:
			if ca_graphChunks[i] == null:
				numChunksToCache += 1
			elif mm_started and not _mm_is_table(i):
				MM_SetPurge("gr:%d" % i, false)
		elif ca_graphChunks[i] != null and mm_started and not _mm_is_table(i):
			MM_SetPurge("gr:%d" % i, true)
	if numChunksToCache == 0:
		return
	if isMessage and ca_beginCacheBox != &"":
		call(ca_beginCacheBox, msg, numChunksToCache)
	for i: int in range(ca_graphChunkNeeded.size()):
		if (ca_graphChunkNeeded[i] & ca_levelbit) != 0 and ca_graphChunks[i] == null:
			if isMessage and ca_updateCacheBox != &"":
				call(ca_updateCacheBox)
			CA_CacheGrChunk(i)
	if isMessage and ca_finishCacheBox != &"":
		call(ca_finishCacheBox)


func CA_UpLevel() -> void:
	if ca_levelnum == 7:
		Quit("CA_UpLevel: Up past level 7!")
		return
	ca_levelbit = (ca_levelbit << 1) & 0xFF
	ca_levelnum += 1


func CA_DownLevel() -> void:
	if ca_levelnum == 0:
		Quit("CA_DownLevel: Down past level 0!")
		return
	ca_levelbit >>= 1
	ca_levelnum -= 1
	CA_CacheMarks("")


func CA_InitLumps(numLumps: int) -> void:
	ca_lumpsNeeded = PackedByteArray()
	ca_lumpsNeeded.resize(numLumps)


func CA_ClearLumps() -> void:
	ca_lumpsNeeded.fill(0)


func CA_MarkLumpNeeded(lump: int) -> void:
	ca_lumpsNeeded[lump] = 1


## lumpStarts/lumpEnds: the episode's lump ranges (EPISODE file arrays).
## id_ca.h's CA_MARKLUMP(name) macro: CA_MarkLumpNeeded(CK_INT(name, -1)).
func CA_MARKLUMP(name: String) -> void:
	CA_MarkLumpNeeded(CK_INT(name, -1))


func CA_MarkAllLumps(lumpStarts: PackedInt32Array, lumpEnds: PackedInt32Array) -> void:
	for i: int in range(ca_lumpsNeeded.size()):
		if ca_lumpsNeeded[i] != 0:
			for chunk: int in range(lumpStarts[i], lumpEnds[i] + 1):
				CA_MarkGrChunk(chunk)


func CA_CacheMap(mapIndex: int) -> void:
	# free up memory from the last map (levels are always reloaded, never cached)
	if ca_mapOn > -1 and CA_MapHeaders.has(ca_mapOn):
		MM_SetPurge("maphead:%d" % ca_mapOn, true)
	for plane: int in range(CA_NUMMAPPLANES):
		if mm_blocks.has("map:%d" % plane):
			MM_FreePtr("map:%d" % plane)
	ca_mapOn = mapIndex
	var m: Dictionary = data.load_map(mapIndex)
	if m.is_empty():
		Quit("CA_CacheMap: Tried to load a non-existant map!")
		return
	# the header is cached if it is still around
	if CA_MapHeaders.has(mapIndex):
		MM_SetPurge("maphead:%d" % mapIndex, false)
	else:
		MM_GetPtr("maphead:%d" % mapIndex, 38)    # sizeof(maptype)
	CA_MapHeaders[mapIndex] = {"width": int(m.width), "height": int(m.height), "name": String(m.get("name", ""))}
	# each plane: its block, the file's bytes read into the misc buffer or a block of their own,
	# the Carmack expansion into a scratch block, the RLEW expansion into the plane, the scratch
	# freed (id_ca.c 1991; keen4_mem08b_a: the third plane's scratch takes the box picture's room)
	var sizes: Array = data.map_plane_sizes(mapIndex)
	for plane: int in range(CA_NUMMAPPLANES):
		MM_GetPtr("map:%d" % plane, int(m.width) * int(m.height) * 2)
		var compressed: int = int(sizes[plane][0]) if plane < sizes.size() else 0
		var expanded: int = int(sizes[plane][1]) if plane < sizes.size() else 0
		var bigbuffer: bool = mm_started and compressed > MM_BUFFERSIZE
		if bigbuffer:
			MM_GetPtr("bigbuffer", compressed)
		MM_GetPtr("buffer2seg", expanded)
		CA_mapPlanes[plane] = (m.plane[plane] as PackedInt32Array).duplicate()
		MM_FreePtr("buffer2seg")
		if bigbuffer:
			MM_FreePtr("bigbuffer")
	# reading and expanding the three planes (TIME-G)
	cost_n("mapword", int(m.width) * int(m.height))


## CA_TilePtrAtPos: the index of the tile's word in its plane (a C pointer).
func CA_TilePtrAtPos(x: int, y: int, _plane: int) -> int:
	return y * int(CA_MapHeaders[ca_mapOn].width) + x


func CA_TileAtPos(x: int, y: int, plane: int) -> int:
	# omnispeak's stand-in for Keen 4 level 10's read above the map
	var mh: Dictionary = CA_MapHeaders[ca_mapOn]
	if x >= 0 and x < mh.width and y >= 0 and y < mh.height:
		return CA_mapPlanes[plane][y * mh.width + x]
	return u16(s32(y * x * y * x) % (int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m) * 6))


func CA_SetTileAtPos(x: int, y: int, plane: int, value: int) -> void:
	var w: int = CA_MapHeaders[ca_mapOn].width
	CA_mapPlanes[plane][y * w + x] = value & 0xFFFF


func CA_GetMapWidth() -> int:
	return CA_MapHeaders[ca_mapOn].width


func CA_GetMapHeight() -> int:
	return CA_MapHeaders[ca_mapOn].height


# ===================================================================== id_ti
# Tile properties, from omnispeak's TILEINFO file: background animation (next
# tile offset, time), then for foreground tiles the four edges, the misc flags
# and the animation. A tile number past its table reads 0, as omnispeak's does.

static func _s8(v: int) -> int:
	return v - 256 if v >= 128 else v


func _ti(index: int) -> int:
	var ti: PackedByteArray = data.tileinfo
	return ti[index] if index >= 0 and index < ti.size() else 0


func TI_BackAnimTile(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16):
		return 0
	return _s8(_ti(tile + int(ca_gfxInfoE.numTiles16)))


func TI_BackAnimTime(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16):
		return 0
	return _ti(tile)


func TI_ForeTop(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _ti(tile + int(ca_gfxInfoE.numTiles16) * 2)


func TI_ForeBottom(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _ti(tile + int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m) * 2)


func TI_ForeLeft(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _ti(tile + int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m) * 3)


func TI_ForeRight(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _ti(tile + int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m))


func TI_ForeMisc(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _ti(tile + int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m) * 5)


func TI_ForeAnimTile(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _s8(_ti(tile + int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m) * 4))


func TI_ForeAnimTime(tile: int) -> int:
	if tile > int(ca_gfxInfoE.numTiles16m):
		return 0
	return _ti(tile + int(ca_gfxInfoE.numTiles16) * 2 + int(ca_gfxInfoE.numTiles16m) * 6)


# ===================================================================== id_vl

const VL_EGAVGA_GFX_WIDTH: int = 320
const VL_EGAVGA_GFX_HEIGHT: int = 200
const RF_BUFFER_WIDTH_TILES: int = 21
const RF_BUFFER_HEIGHT_TILES: int = 14
const RF_BUFFER_WIDTH_PIXELS: int = RF_BUFFER_WIDTH_TILES << 4
const RF_BUFFER_HEIGHT_PIXELS: int = RF_BUFFER_HEIGHT_TILES << 4

## EGA signal palettes (the 17th entry of each is the border colour).
var vl_palette: Array = [
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0]),
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 24, 25, 26, 27, 28, 29, 30, 31, 0]),
	PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 24, 25, 26, 27, 28, 29, 30, 31, 0]),
	PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 31, 31, 31, 31, 31, 31, 31, 31, 0]),
	PackedByteArray([31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]),
]
var vl_screenFaded: bool = false
var vl_border_color: int = 0
var vl_mapMask: int = 0xF
var vl_scrollXpixels: int = 0
var vl_scrollYpixels: int = 0
var vl_lastFrameTime: int = 0
var vl_noPan: bool = false
## The palette registers as last set (EGA signals) and the border.
var vl_adapterPalette: PackedByteArray = PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 24, 25, 26, 27, 28, 29, 30, 31])
var vl_adapterBorder: int = 0
## Which of the card's two pages shows (VL_Present draws the other, then flips).
var vl_shownPage: int = 0


## A surface: one byte per pixel, `w` bytes a row.
class VL_Surface:
	var w: int = 0
	var h: int = 0
	var pixels: PackedByteArray = PackedByteArray()

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		pixels.resize(width * height)


## The screen surface (omnispeak's vl_emuegavgaadapter.screen).
var vl_screen: VL_Surface = null


func VL_SetPaletteAndBorderColor(palette: PackedByteArray) -> void:
	for i: int in range(16):
		vl_adapterPalette[i] = palette[i]
	vl_adapterBorder = palette[16]
	# int 10h AX=1002h: the sixteen palette registers and the border
	var table: PackedByteArray = PackedByteArray()
	table.resize(17)
	for i: int in range(17):
		table[i] = palette[i]
	vm.card.bios_set_palette(table)


func VL_SetPaletteFromArray(palArray: PackedInt32Array) -> void:
	var p: PackedByteArray = PackedByteArray()
	p.resize(17)
	for i: int in range(16):
		p[i] = palArray[i] & 0xFF
	p[16] = vl_adapterBorder
	VL_SetPaletteAndBorderColor(p)


func VL_ColorBorder(color: int) -> void:
	var p: PackedByteArray = vl_adapterPalette.duplicate()
	p.append(color & 0xFF)
	VL_SetPaletteAndBorderColor(p)
	vl_border_color = color


func VL_SetDefaultPalette() -> void:
	vl_palette[3][16] = vl_border_color
	VL_SetPaletteAndBorderColor(vl_palette[3])
	vl_screenFaded = false


func VL_SetPaletteByID(id: int) -> void:
	vl_palette[id][16] = vl_border_color
	VL_SetPaletteAndBorderColor(vl_palette[id])


func VL_SetPalette(palette: PackedByteArray) -> void:
	palette[16] = vl_border_color
	VL_SetPaletteAndBorderColor(palette)


func VL_FadeToBlack() -> void:
	for i: int in range(3, -1, -1):
		vl_palette[i][16] = vl_border_color
		VL_SetPaletteAndBorderColor(vl_palette[i])
		VL_Present()
		VL_DelayTics(6)
	vl_screenFaded = true


## `flip` false: DOS's VW_FadeIn as such, palette steps only, the page on
## display kept (from RF_Refresh's hook, which runs before the page it drew is
## shown: the level's first frame drawn in the black is the one that fades in,
## keen4_level08_a); true: omnispeak's present at each step, for its callers
## that drew without one.
func VL_FadeFromBlack(flip: bool = true) -> void:
	for i: int in range(4):
		vl_palette[i][16] = vl_border_color
		VL_SetPaletteAndBorderColor(vl_palette[i])
		if flip:
			VL_Present()
		elif not vm.in_retrace():
			vm.wait_retrace_start()
		VL_DelayTics(6)
	vl_screenFaded = false


## VL_Clip: returns [src_w, src_h, dst_x, dst_y] as the C function leaves them.
func VL_Clip(src_w: int, src_h: int, dst_x: int, dst_y: int, dst_w: int, dst_h: int) -> PackedInt32Array:
	var initialX: int = CK_Cross_max(-dst_x, 0)
	var initialY: int = CK_Cross_max(-dst_y, 0)
	var finalW: int = CK_Cross_min(CK_Cross_max(dst_w - dst_x, 0), CK_Cross_min(src_w, dst_x + src_w))
	var finalH: int = CK_Cross_min(CK_Cross_max(dst_h - dst_y, 0), CK_Cross_min(src_h, dst_y + src_h))
	return PackedInt32Array([CK_Cross_max(finalW, 0), CK_Cross_max(finalH, 0), initialX, initialY])


# ---- the 8-bit software blits (sources are planar chunks at `so`) ----------
# A C pointer write outside the destination corrupts other memory; here an
# index outside the surface's array is skipped, and one that only wraps to the
# previous or next row lands there, as it did in C.

static func _put(dst: PackedByteArray, i: int, v: int) -> void:
	if i >= 0 and i < dst.size():
		dst[i] = v


func VL_UnmaskedToPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int) -> void:
	var plane: int = (w / 8) * h
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var pixel: int = (8 if (src[plane_off + plane * 3] & plane_bit) != 0 else 0) | \
				(4 if (src[plane_off + plane * 2] & plane_bit) != 0 else 0) | \
				(2 if (src[plane_off + plane] & plane_bit) != 0 else 0) | \
				(1 if (src[plane_off] & plane_bit) != 0 else 0)
			_put(dst, (sy + y) * pitch + (sx + x), pixel)


func VL_UnmaskedToPAL8_PM(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, mapmask: int) -> void:
	var plane: int = (w / 8) * h
	mapmask &= 0xF
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var pixel: int = (8 if (mapmask & 8) != 0 and (src[plane_off + plane * 3] & plane_bit) != 0 else 0) | \
				(4 if (mapmask & 4) != 0 and (src[plane_off + plane * 2] & plane_bit) != 0 else 0) | \
				(2 if (mapmask & 2) != 0 and (src[plane_off + plane] & plane_bit) != 0 else 0) | \
				(1 if (mapmask & 1) != 0 and (src[plane_off] & plane_bit) != 0 else 0)
			var i: int = (sy + y) * pitch + (sx + x)
			if i >= 0 and i < dst.size():
				dst[i] = (dst[i] & ~mapmask) | pixel


func VL_MaskedToPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int) -> void:
	var plane: int = (w / 8) * h
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var pixel: int = (8 if (src[plane_off + plane * 4] & plane_bit) != 0 else 0) | \
				(4 if (src[plane_off + plane * 3] & plane_bit) != 0 else 0) | \
				(2 if (src[plane_off + plane * 2] & plane_bit) != 0 else 0) | \
				(1 if (src[plane_off + plane] & plane_bit) != 0 else 0)
			_put(dst, (sy + y) * pitch + (sx + x), pixel & (0xF0 if (src[plane_off] & plane_bit) != 0 else 0x00))


func VL_MaskedBlitClipToPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, dw: int, dh: int) -> void:
	var plane: int = (w / 8) * h
	var initialX: int = CK_Cross_max(-x, 0)
	var initialY: int = CK_Cross_max(-y, 0)
	var finalW: int = CK_Cross_min(CK_Cross_max(dw - x, 0), w)
	var finalH: int = CK_Cross_min(CK_Cross_max(dh - y, 0), h)
	for sy: int in range(initialY, finalH):
		for sx: int in range(initialX, finalW):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var i: int = (sy + y) * pitch + (sx + x)
			if (src[plane_off] & plane_bit) == 0:
				dst[i] = 0
			var pixel: int = (8 if (src[plane_off + plane * 4] & plane_bit) != 0 else 0) | \
				(4 if (src[plane_off + plane * 3] & plane_bit) != 0 else 0) | \
				(2 if (src[plane_off + plane * 2] & plane_bit) != 0 else 0) | \
				(1 if (src[plane_off + plane] & plane_bit) != 0 else 0)
			dst[i] = dst[i] | pixel


func VL_1bppToPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, colour: int) -> void:
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			_put(dst, (sy + y) * pitch + (sx + x), colour if (src[plane_off] & plane_bit) != 0 else colour & 0xF0)


func VL_1bppToPAL8_PM(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, colour: int, mapmask: int) -> void:
	mapmask &= 0xF
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var pixel: int = (colour if (src[plane_off] & plane_bit) != 0 else colour & 0xF0) & mapmask
			var i: int = (sy + y) * pitch + (sx + x)
			if i >= 0 and i < dst.size():
				dst[i] = (dst[i] & ~mapmask) | pixel


func VL_1bppXorWithPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, colour: int) -> void:
	var spitch: int = ((w + 7) / 8) * 8
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * spitch + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * spitch + sx) & 7))
			if (src[plane_off] & plane_bit) == 0:
				continue
			var i: int = (sy + y) * pitch + (sx + x)
			if i >= 0 and i < dst.size():
				dst[i] = dst[i] ^ (colour & 0xFF)


func VL_1bppBlitToPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, colour: int) -> void:
	var spitch: int = ((w + 7) / 8) * 8
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * spitch + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * spitch + sx) & 7))
			if (src[plane_off] & plane_bit) == 0:
				continue
			_put(dst, (sy + y) * pitch + (sx + x), colour)


func VL_1bppInvBlitClipToPAL8(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, dw: int, dh: int, colour: int) -> void:
	var initialX: int = CK_Cross_max(-x, 0)
	var initialY: int = CK_Cross_max(-y, 0)
	var finalW: int = CK_Cross_min(CK_Cross_max(dw - x, 0), w)
	var finalH: int = CK_Cross_min(CK_Cross_max(dh - y, 0), h)
	var spitch: int = ((w + 7) / 8) * 8
	for sy: int in range(initialY, finalH):
		for sx: int in range(initialX, finalW):
			var plane_off: int = so + ((sy * spitch + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * spitch + sx) & 7))
			if (src[plane_off] & plane_bit) != 0:
				continue
			dst[(sy + y) * pitch + (sx + x)] = colour


# ---- the surface layer (id_vl.c over the SDL2 back-end's semantics) --------

func VL_InitScreen() -> void:
	vm.card.bios_set_video_mode(0x0D)
	vl_screen = VL_Surface.new(RF_BUFFER_WIDTH_PIXELS, RF_BUFFER_HEIGHT_PIXELS)
	VL_SetPaletteAndBorderColor(vl_palette[3])


func VL_Startup() -> void:
	VL_InitScreen()


func VL_CreateSurface(w: int, h: int) -> VL_Surface:
	return VL_Surface.new(w, h)


func VL_DestroySurface(_surf: VL_Surface) -> void:
	pass


func VL_SetScreen(surf: VL_Surface) -> VL_Surface:
	var old_screen: VL_Surface = vl_screen
	vl_screen = surf
	return old_screen


func VL_SurfacePGet(surf: VL_Surface, x: int, y: int) -> int:
	return surf.pixels[y * surf.w + x]


## SDL_FillRect: the rectangle clipped to the surface.
func VL_SurfaceRect(dst: VL_Surface, x: int, y: int, w: int, h: int, colour: int) -> void:
	var x0: int = maxi(x, 0)
	var y0: int = maxi(y, 0)
	var x1: int = mini(x + w, dst.w)
	var y1: int = mini(y + h, dst.h)
	for py: int in range(y0, y1):
		var row: int = py * dst.w
		for px: int in range(x0, x1):
			dst.pixels[row + px] = colour & 0xFF


func VL_SurfaceRect_PM(dst: VL_Surface, x: int, y: int, w: int, h: int, colour: int, mapmask: int) -> void:
	mapmask &= 0xF
	colour &= mapmask
	for py: int in range(y, y + h):
		for px: int in range(x, x + w):
			var i: int = py * dst.w + px
			if i >= 0 and i < dst.pixels.size():
				dst.pixels[i] = (dst.pixels[i] & ~mapmask) | colour


func VL_ScreenRect(x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_SurfaceRect(vl_screen, x, y, w, h, colour)


func VL_ScreenRect_PM(x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_SurfaceRect_PM(vl_screen, x, y, w, h, colour, vl_mapMask)


func VL_SurfaceToSurface(src: VL_Surface, dst: VL_Surface, x: int, y: int, sx: int, sy: int, sw: int, sh: int) -> void:
	for _y: int in range(sy, sy + sh):
		var d: int = (_y - sy + y) * dst.w + x
		var s: int = _y * src.w + sx
		for k: int in range(sw):
			if d + k >= 0 and d + k < dst.pixels.size() and s + k >= 0 and s + k < src.pixels.size():
				dst.pixels[d + k] = src.pixels[s + k]


func VL_SurfaceToSelf(surf: VL_Surface, x: int, y: int, sx: int, sy: int, sw: int, sh: int) -> void:
	var rows: Array = range(sh) if sy > y else range(sh - 1, -1, -1)
	for yi: int in rows:
		var d: int = (yi + y) * surf.w + x
		var s: int = (sy + yi) * surf.w + sx
		# memmove: a copy that survives overlap
		var line: PackedByteArray = PackedByteArray()
		line.resize(sw)
		for k: int in range(sw):
			if s + k >= 0 and s + k < surf.pixels.size():
				line[k] = surf.pixels[s + k]
		for k: int in range(sw):
			if d + k >= 0 and d + k < surf.pixels.size():
				surf.pixels[d + k] = line[k]


func VL_ScreenToScreen(x: int, y: int, sx: int, sy: int, sw: int, sh: int) -> void:
	VL_SurfaceToSelf(vl_screen, x, y, sx, sy, sw, sh)


func VL_SurfaceToScreen(src: VL_Surface, x: int, y: int, sx: int, sy: int, sw: int, sh: int) -> void:
	VL_SurfaceToSurface(src, vl_screen, x, y, sx, sy, sw, sh)


func VL_UnmaskedToSurface(src: PackedByteArray, so: int, dest: VL_Surface, x: int, y: int, w: int, h: int) -> void:
	VL_UnmaskedToPAL8(src, so, dest.pixels, x, y, dest.w, w, h)


func VL_UnmaskedToScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int) -> void:
	VL_UnmaskedToPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h)


func VL_UnmaskedToScreen_PM(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int) -> void:
	VL_UnmaskedToPAL8_PM(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, vl_mapMask)


func VL_MaskedToSurface(src: PackedByteArray, so: int, dest: VL_Surface, x: int, y: int, w: int, h: int) -> void:
	VL_MaskedToPAL8(src, so, dest.pixels, x, y, dest.w, w, h)


func VL_MaskedBlitToSurface(src: PackedByteArray, so: int, dest: VL_Surface, x: int, y: int, w: int, h: int) -> void:
	VL_MaskedBlitClipToPAL8(src, so, dest.pixels, x, y, dest.w, w, h, dest.w, dest.h)


func VL_MaskedToScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int) -> void:
	VL_MaskedToPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h)


func VL_MaskedBlitToScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int) -> void:
	VL_MaskedBlitClipToPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, vl_screen.w, vl_screen.h)


func VL_1bppToScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_1bppToPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, colour)


func VL_1bppToScreen_PM(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_1bppToPAL8_PM(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, colour, vl_mapMask)


func VL_1bppXorWithScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_1bppXorWithPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, colour)


func VL_1bppBlitToScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_1bppBlitToPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, colour)


func VL_1bppInvBlitToScreen(src: PackedByteArray, so: int, x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_1bppInvBlitClipToPAL8(src, so, vl_screen.pixels, x, y, vl_screen.w, w, h, vl_screen.w, vl_screen.h, colour)


## SDL2's ScrollSurface: the surface moved by (x, y) within itself.
func VL_ScrollScreen(x: int, y: int) -> void:
	var dx: int = 0
	var dy: int = 0
	var sx: int = 0
	var sy: int = 0
	var w: int = vl_screen.w - CK_Cross_max(x, -x)
	var h: int = vl_screen.h - CK_Cross_max(y, -y)
	if x > 0:
		sx = x
	else:
		dx = -x
	if y > 0:
		sy = y
	else:
		dy = -y
	VL_SurfaceToSelf(vl_screen, dx, dy, sx, sy, w, h)


func VL_GetTics(wait: int) -> int:
	var tics: int = 0
	while true:
		tics = SD_GetTimeCount() - vl_lastFrameTime
		if tics >= wait or quitting:
			break
		vm.poll()
	return tics


## id_vl_dos.c's waitVBLs: for each, wait for the vertical blank to begin
## (at once if it already has), then for it to end.
func VL_DelayTics(tics: int) -> void:
	for i: int in range(tics):
		if quitting:
			return
		if not vm.in_retrace():
			vm.wait_retrace_start()
		vm.wait_retrace_end()


func VL_Yield() -> void:
	pass


func VL_SetScrollCoords(x: int, y: int) -> void:
	if not vl_noPan:
		vl_scrollXpixels = x
	vl_scrollYpixels = y


func VL_GetScrollX() -> int:
	return vl_scrollXpixels


func VL_GetScrollY() -> int:
	return vl_scrollYpixels


func VL_ClearScreen(colour: int) -> void:
	if vl_screen == null:
		return
	VL_ScreenRect(0, 0, vl_screen.w, vl_screen.h, colour)
	# the original writes every byte of the EGA page (TIME-G)
	cost_n("clearbyte", vl_screen.w * vl_screen.h / 8)


func VL_SetMapMask(mapmask: int) -> void:
	vl_mapMask = mapmask & 0xF


func VL_GetActiveBuffer() -> int:
	return 0


func VL_GetNumBuffers() -> int:
	return 1


func VL_FixRefreshBuffer() -> void:
	pass


func VL_UpdateRect(_x: int, _y: int, _w: int, _h: int) -> void:
	pass


func VL_SwapOnNextPresent() -> void:
	pass


## A verification harness's hold on each picture (HARN-12, tests only): called
## with the page just written, before it is put on display. Not game state.
var present_lock: Callable = Callable()


## The 320 x 200 window at the scroll position, written into the card's hidden
## page in write mode 0 one plane at a time, then shown from the next retrace.
func VL_Present() -> void:
	vl_lastFrameTime = SD_GetTimeCount()
	var page: int = 1 - vl_shownPage
	var base: int = page * EgaCard.PAGE_SIZE
	_write_rows(base, 0, VL_EGAVGA_GFX_HEIGHT, -1)
	if present_lock.is_valid():
		present_lock.call(base)
	# the CRTC start address, latched by the card at the next retrace; then, as
	# id_vl_dos.c's present does, wait for that retrace to begin (no wait when
	# one already has)
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTHIGH)
	vm.out8(EgaCard.CRTC_DATA, (base >> 8) & 0xFF)
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTLOW)
	vm.out8(EgaCard.CRTC_DATA, base & 0xFF)
	vl_shownPage = page
	if not vm.in_retrace():
		vm.wait_retrace_start()


## DOS's VW_ClearVideo: every byte of all four planes zeroed at once, the page
## on display too, so the black shows as the beam reaches it (TIME-G).
func VL_ClearVideo() -> void:
	var card: EgaCard = vm.card
	for i: int in range(4):
		var pl: PackedByteArray = card.get("plane%d" % i)
		pl.fill(0)
		card.set("plane%d" % i, pl)


## Rows y0..y1-1 of the screen (at the scroll position), or those rows filled
## with `colour` (>= 0), written straight into the page on display: for what
## the original draws onto the page being shown, so the card shows the work
## in progress at each refresh (TIME-G4: the story screen).
func VL_ShowRows(y0: int, y1: int, colour: int = -1) -> void:
	_write_rows(vl_shownPage * EgaCard.PAGE_SIZE, y0, y1, colour)


## The bytes holding these pixels (y * 320 + x each), from the screen, written
## straight into the page on display (TIME-G4: the title's fizzle).
func VL_ShowPixels(pixels: PackedInt32Array) -> void:
	var card: EgaCard = vm.card
	var base: int = vl_shownPage * EgaCard.PAGE_SIZE
	var src: PackedByteArray = vl_screen.pixels
	var pitch: int = vl_screen.w
	var p0: PackedByteArray = card.plane0
	var p1: PackedByteArray = card.plane1
	var p2: PackedByteArray = card.plane2
	var p3: PackedByteArray = card.plane3
	for p: int in pixels:
		var y: int = p / VL_EGAVGA_GFX_WIDTH
		var bx: int = (p % VL_EGAVGA_GFX_WIDTH) >> 3
		var s: int = (y + vl_scrollYpixels) * pitch + vl_scrollXpixels + bx * 8
		var b0: int = 0
		var b1: int = 0
		var b2: int = 0
		var b3: int = 0
		for k: int in range(8):
			var c: int = src[s + k] if s + k < src.size() else 0
			var bit: int = 0x80 >> k
			if (c & 1) != 0:
				b0 |= bit
			if (c & 2) != 0:
				b1 |= bit
			if (c & 4) != 0:
				b2 |= bit
			if (c & 8) != 0:
				b3 |= bit
		var d: int = base + y * (VL_EGAVGA_GFX_WIDTH / 8) + bx
		p0[d] = b0
		p1[d] = b1
		p2[d] = b2
		p3[d] = b3
	card.plane0 = p0
	card.plane1 = p1
	card.plane2 = p2
	card.plane3 = p3


## The rows into the card's memory at `base`, in write mode 0 one plane at a time.
func _write_rows(base: int, y0: int, y1: int, colour: int) -> void:
	var card: EgaCard = vm.card
	var src: PackedByteArray = vl_screen.pixels
	var pitch: int = vl_screen.w
	var p0: PackedByteArray = card.plane0
	var p1: PackedByteArray = card.plane1
	var p2: PackedByteArray = card.plane2
	var p3: PackedByteArray = card.plane3
	for y: int in range(y0, y1):
		var srow: int = (y + vl_scrollYpixels) * pitch + vl_scrollXpixels
		var drow: int = base + y * (VL_EGAVGA_GFX_WIDTH / 8)
		for bx: int in range(VL_EGAVGA_GFX_WIDTH / 8):
			var b0: int = 0
			var b1: int = 0
			var b2: int = 0
			var b3: int = 0
			var s: int = srow + bx * 8
			for k: int in range(8):
				var c: int = colour if colour >= 0 else (src[s + k] if s + k < src.size() else 0)
				var bit: int = 0x80 >> k
				if (c & 1) != 0:
					b0 |= bit
				if (c & 2) != 0:
					b1 |= bit
				if (c & 4) != 0:
					b2 |= bit
				if (c & 8) != 0:
					b3 |= bit
			p0[drow + bx] = b0
			p1[drow + bx] = b1
			p2[drow + bx] = b2
			p3[drow + bx] = b3
	card.plane0 = p0
	card.plane1 = p1
	card.plane2 = p2
	card.plane3 = p3


# ===================================================================== id_vh

func VH_GetBitmapTableEntry(bitmapNumber: int) -> Dictionary:
	var t: PackedByteArray = ca_graphChunks[int(ca_gfxInfoE.hdrBitmaps)]
	return {"width": t[bitmapNumber * 4] | (t[bitmapNumber * 4 + 1] << 8),
		"height": t[bitmapNumber * 4 + 2] | (t[bitmapNumber * 4 + 3] << 8)}


func VH_GetMaskedBitmapTableEntry(bitmapNumber: int) -> Dictionary:
	var t: PackedByteArray = ca_graphChunks[int(ca_gfxInfoE.hdrMasked)]
	return {"width": t[bitmapNumber * 4] | (t[bitmapNumber * 4 + 1] << 8),
		"height": t[bitmapNumber * 4 + 2] | (t[bitmapNumber * 4 + 3] << 8)}


func VH_GetSpriteTableEntry(spriteNumber: int) -> Dictionary:
	var t: PackedByteArray = ca_graphChunks[int(ca_gfxInfoE.hdrSprites)]
	var e: int = spriteNumber * 18
	return {"width": t[e] | (t[e + 1] << 8), "height": t[e + 2] | (t[e + 3] << 8),
		"originX": s16(t[e + 4] | (t[e + 5] << 8)), "originY": s16(t[e + 6] | (t[e + 7] << 8)),
		"xl": s16(t[e + 8] | (t[e + 9] << 8)), "yl": s16(t[e + 10] | (t[e + 11] << 8)),
		"xh": s16(t[e + 12] | (t[e + 13] << 8)), "yh": s16(t[e + 14] | (t[e + 15] << 8)),
		"shifts": t[e + 16] | (t[e + 17] << 8)}


func VH_GetShiftedSprite(chunk: int) -> VH_ShiftedSprite:
	return CA_GetGrChunk(chunk, 0, "Sprite", true)


func VH_GetShiftedSpriteWidth(shifted: VH_ShiftedSprite, shift: int) -> int:
	return shifted.sprShiftByteWidths[shift] * 8


## {height, data (the font chunk), offset (the glyph's start in it), width}
func VH_GetFontCharInfo(chunk: int, ch: int) -> Dictionary:
	var fnt: PackedByteArray = CA_GetGrChunk(chunk, 3, "Font", true)
	return {"height": fnt[0] | (fnt[1] << 8), "data": fnt,
		"offset": fnt[ch * 2 + 2] | (fnt[ch * 2 + 3] << 8), "width": fnt[2 * 256 + 2 + ch]}


func VH_Plot(x: int, y: int, colour: int) -> void:
	VL_ScreenRect(x, y, 1, 1, colour)


func VH_HLine(x1: int, x2: int, y: int, colour: int) -> void:
	VL_ScreenRect(x1, y, x2 - x1 + 1, 1, colour)


func VH_VLine(y1: int, y2: int, x: int, colour: int) -> void:
	VL_ScreenRect(x, y1, 1, y2 - y1 + 1, colour)


func VH_Bar(x: int, y: int, w: int, h: int, colour: int) -> void:
	VL_ScreenRect(x, y, w, h, colour)


func VH_DrawTile8(x: int, y: int, tile: int) -> void:
	var c: PackedByteArray = CA_GetGrChunk(int(ca_gfxInfoE.offTiles8), 0, "Tile8", true)
	VL_UnmaskedToScreen(c, tile * 32, x, y, 8, 8)


func VH_DrawTile8M(x: int, y: int, tile: int) -> void:
	var c: PackedByteArray = CA_GetGrChunk(int(ca_gfxInfoE.offTiles8m), 0, "Tile8m", true)
	VL_MaskedBlitToScreen(c, tile * 40, x, y, 8, 8)


func VH_DrawTile16(x: int, y: int, tile: int) -> void:
	var c: Variant = CA_GetGrChunk(int(ca_gfxInfoE.offTiles16), tile, "Tile16", true)
	if c == null:
		return
	VL_UnmaskedToScreen(c, 0, x, y, 16, 16)


func VH_DrawTile16M(x: int, y: int, tile: int) -> void:
	var c: Variant = ca_graphChunks[int(ca_gfxInfoE.offTiles16m) + tile]
	if c == null:
		return
	VL_MaskedBlitToScreen(c, 0, x, y, 16, 16)


func VH_DrawBitmap(x: int, y: int, chunk: int) -> void:
	var bitmapNumber: int = chunk - int(ca_gfxInfoE.offBitmaps)
	var dimensions: Dictionary = VH_GetBitmapTableEntry(bitmapNumber)
	VL_UnmaskedToScreen(CA_GetGrChunk(chunk, 0, "Bitmap", true), 0, x, y, dimensions.width * 8, dimensions.height)


func VH_DrawMaskedBitmap(x: int, y: int, chunk: int) -> void:
	var bitmapNumber: int = chunk - int(ca_gfxInfoE.offMasked)
	var dim: Dictionary = VH_GetMaskedBitmapTableEntry(bitmapNumber)
	VL_MaskedBlitToScreen(CA_GetGrChunk(chunk, 0, "MaskedBitmap", true), 0, x, y, dim.width * 8, dim.height)


func VH_DrawSprite(x: int, y: int, chunk: int) -> void:
	var spriteNumber: int = chunk - int(ca_gfxInfoE.offSprites)
	var spr: Dictionary = VH_GetSpriteTableEntry(spriteNumber)
	var shifted: VH_ShiftedSprite = VH_GetShiftedSprite(chunk)
	var shift: int = (x & 7) / 2
	var width: int = shifted.sprShiftByteWidths[shift] * 8
	VL_MaskedBlitToScreen(shifted.data, shifted.sprShiftOffset[shift], x & ~7, y, width, spr.height)


func VH_DrawSpriteMask(x: int, y: int, chunk: int, colour: int) -> void:
	var spriteNumber: int = chunk - int(ca_gfxInfoE.offSprites)
	var spr: Dictionary = VH_GetSpriteTableEntry(spriteNumber)
	var shifted: VH_ShiftedSprite = VH_GetShiftedSprite(chunk)
	var shift: int = (x & 7) / 2
	var width: int = shifted.sprShiftByteWidths[shift] * 8
	VL_1bppInvBlitToScreen(shifted.data, shifted.sprShiftOffset[shift], x & ~7, y, width, spr.height, colour)


func VH_DrawShiftedSprite(x: int, y: int, chunk: int, shift: int) -> void:
	var spriteNumber: int = chunk - int(ca_gfxInfoE.offSprites)
	var spr: Dictionary = VH_GetSpriteTableEntry(spriteNumber)
	var shifted: VH_ShiftedSprite = VH_GetShiftedSprite(chunk)
	var width: int = shifted.sprShiftByteWidths[shift] * 8
	VL_MaskedBlitToScreen(shifted.data, shifted.sprShiftOffset[shift], x, y, width, spr.height)


func VH_DrawShiftedSpriteMask(x: int, y: int, chunk: int, shift: int, colour: int) -> void:
	var spriteNumber: int = chunk - int(ca_gfxInfoE.offSprites)
	var spr: Dictionary = VH_GetSpriteTableEntry(spriteNumber)
	var shifted: VH_ShiftedSprite = VH_GetShiftedSprite(chunk)
	var width: int = shifted.sprShiftByteWidths[shift] * 8
	VL_1bppInvBlitToScreen(shifted.data, shifted.sprShiftOffset[shift], x, y, width, spr.height, colour)


func VH_DrawPropChar(x: int, y: int, chunk: int, c: int, colour: int) -> void:
	var ci: Dictionary = VH_GetFontCharInfo(chunk, c & 0xFF)
	VL_1bppXorWithScreen(ci.data, ci.offset, x, y, ci.width, ci.height, colour)


## Returns [width, height] (the C version's out-parameters).
## C leaves *height untouched for an empty string: the caller's local keeps
## what it held, in practice the last height measured into that stack slot.
## The port gives the last height measured.
var vh_lastMeasuredHeight: int = 0


func VH_MeasurePropString(string: String, chunk: int) -> PackedInt32Array:
	var width: int = 0
	var height: int = vh_lastMeasuredHeight
	for i: int in range(string.length()):
		var ci: Dictionary = VH_GetFontCharInfo(chunk, string.unicode_at(i) & 0xFF)
		width = (width + ci.width) & 0xFFFF
		height = ci.height
	vh_lastMeasuredHeight = height
	return PackedInt32Array([width, height])


func VH_DrawPropString(string: String, x: int, y: int, chunk: int, colour: int) -> void:
	var w: int = 0
	for i: int in range(string.length()):
		var c: int = string.unicode_at(i) & 0xFF
		var ci: Dictionary = VH_GetFontCharInfo(chunk, c)
		VH_DrawPropChar(x + w, y, chunk, c, colour)
		w += ci.width


# ---- the buffer routines: mark the tiles they draw over for id_rf ----------

func VHB_DrawTile8(x: int, y: int, tile: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y, x + 7, y + 7):
		VH_DrawTile8(x, y, tile)


func VHB_DrawTile8M(x: int, y: int, tile: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y, x + 7, y + 7):
		VH_DrawTile8M(x, y, tile)


## omnispeak draws an 8x8 tile here, as written.
func VHB_DrawTile16(x: int, y: int, tile: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y, x + 15, y + 15):
		VH_DrawTile8(x, y, tile)


func VHB_DrawTile16M(x: int, y: int, tile: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y, x + 15, y + 15):
		VH_DrawTile8M(x, y, tile)


func VHB_DrawBitmap(x: int, y: int, chunk: int) -> void:
	var bitmapNumber: int = chunk - int(ca_gfxInfoE.offBitmaps)
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	var dimensions: Dictionary = VH_GetBitmapTableEntry(bitmapNumber)
	if VH_MarkUpdateBlock(x, y, x + dimensions.width * 8, y + dimensions.height):
		VL_UnmaskedToScreen(CA_GetGrChunk(chunk, 0, "Bitmap", true), 0, x, y, dimensions.width * 8, dimensions.height)


func VHB_DrawMaskedBitmap(x: int, y: int, chunk: int) -> void:
	var bitmapNumber: int = chunk - int(ca_gfxInfoE.offMasked)
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	var dim: Dictionary = VH_GetMaskedBitmapTableEntry(bitmapNumber)
	if VH_MarkUpdateBlock(x, y, x + dim.width * 8, y + dim.height):
		VL_MaskedBlitToScreen(CA_GetGrChunk(chunk, 0, "Bitmap", true), 0, x, y, dim.width * 8, dim.height)


func VHB_DrawSprite(x: int, y: int, chunk: int) -> void:
	var spriteNumber: int = chunk - int(ca_gfxInfoE.offSprites)
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	var spr: Dictionary = VH_GetSpriteTableEntry(spriteNumber)
	var shifted: VH_ShiftedSprite = CA_GetGrChunk(chunk, 0, "Sprite", true)
	var shift: int = (x & 7) / 2
	var width: int = shifted.sprShiftByteWidths[shift] * 8
	var realX: int = (x + (spr.originX >> 4)) & ~7
	var realY: int = y + (spr.originY >> 4)
	if VH_MarkUpdateBlock(realX, realY, realX + spr.width * 8, realY + spr.height):
		VL_MaskedBlitToScreen(shifted.data, shifted.sprShiftOffset[shift], realX, realY, width, spr.height)


func VHB_Plot(x: int, y: int, colour: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y, x + 1, y + 1):
		VL_ScreenRect(x, y, 1, 1, colour)


func VHB_HLine(x1: int, x2: int, y: int, colour: int) -> void:
	x1 += VL_GetScrollX() & 8
	x2 += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x1, y, x2 + 1, y + 1):
		VL_ScreenRect(x1, y, x2 - x1 + 1, 1, colour)


func VHB_VLine(y1: int, y2: int, x: int, colour: int) -> void:
	x += VL_GetScrollX() & 8
	y1 += VL_GetScrollY()
	y2 += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y1, x + 1, y2 + 1):
		VL_ScreenRect(x, y1, 1, y2 - y1 + 1, colour)


func VHB_Bar(x: int, y: int, w: int, h: int, colour: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	if VH_MarkUpdateBlock(x, y, x + w, y + h):
		VL_ScreenRect(x, y, w, h, colour)


func VHB_DrawPropString(string: String, x: int, y: int, chunk: int, colour: int) -> void:
	x += VL_GetScrollX() & 8
	y += VL_GetScrollY()
	var wh: PackedInt32Array = VH_MeasurePropString(string, chunk)
	if VH_MarkUpdateBlock(x, y, x + wh[0], y + wh[1]):
		VH_DrawPropString(string, x, y, chunk, colour)


## Mark a block (in pixels) dirty; false when no tile was in the buffer.
func VH_MarkUpdateBlock(x1px: int, y1px: int, x2px: int, y2px: int) -> bool:
	var x1tile: int = x1px >> 4
	var y1tile: int = y1px >> 4
	var x2tile: int = x2px >> 4
	var y2tile: int = y2px >> 4
	if x1tile >= RF_BUFFER_WIDTH_TILES:
		return false
	x1tile = 0 if x1tile < 0 else x1tile
	if y1tile >= RF_BUFFER_HEIGHT_TILES:
		return false
	y1tile = 0 if y1tile < 0 else y1tile
	if x2tile < 0:
		return false
	x2tile = x2tile if x2tile < RF_BUFFER_WIDTH_TILES - 1 else RF_BUFFER_WIDTH_TILES - 2
	if y2tile < 0:
		return false
	y2tile = y2tile if y2tile < RF_BUFFER_HEIGHT_TILES else RF_BUFFER_HEIGHT_TILES - 1
	for y: int in range(y1tile, y2tile + 1):
		for x: int in range(x1tile, x2tile + 1):
			RFL_MarkBlockDirty(x, y, 1, -1)
	return true


## DOS's VW_UpdateScreen: the changed blocks copied straight onto the page on
## display, no wait for the retrace (omnispeak presents with a flip); the beam
## shows the rows above it old until the next refresh (keen4_level08_a: the
## level's box caught half copied when Keen dies and the level restarts).
func VH_UpdateScreen() -> void:
	VL_ShowRows(0, VL_EGAVGA_GFX_HEIGHT)


# ===================================================================== id_fs, id_ca, id_vl, id_mm, id_cfg and C library pieces the game layer needs
# (written with the ck_* ports, moved here by SIM-G-01j)


## id_fs.c's FS_File over a byte buffer (no file system: A11). The shell
## keeps `data` (a saved game is one of us_saveFiles); reads and writes go at
## `pos`, a write past the end extends the buffer.
class FS_File:
	var data: PackedByteArray = PackedByteArray()
	var pos: int = 0

	func _init(bytes: PackedByteArray = PackedByteArray(), at: int = 0) -> void:
		data = bytes
		pos = at


## id_fs.c (fread): the bytes of the whole items read (nmemb at most).
func FS_Read(size: int, nmemb: int, file: FS_File) -> PackedByteArray:
	var n: int = 0
	if size > 0:
		n = clampi((file.data.size() - file.pos) / size, 0, nmemb)
	var out: PackedByteArray = file.data.slice(file.pos, file.pos + n * size)
	file.pos += n * size
	return out


## id_fs.c (fwrite): returns the number of items written (always all).
func FS_Write(ptr: PackedByteArray, size: int, nmemb: int, file: FS_File) -> int:
	var n: int = size * nmemb
	if file.pos + n > file.data.size():
		file.data.resize(file.pos + n)
	for i: int in range(n):
		file.data[file.pos + i] = ptr[i]
	file.pos += n
	return nmemb


## id_fs.c: count words read, returned unsigned (the C writes them through
## its pointer; the caller stores each as its field's type). size() is the C's count.
func FS_ReadInt16LE(count: int, stream: FS_File) -> PackedInt64Array:
	var b: PackedByteArray = FS_Read(2, count, stream)
	var out: PackedInt64Array = PackedInt64Array()
	for i: int in range(b.size() / 2):
		out.append(b[i * 2] | (b[i * 2 + 1] << 8))
	return out


## id_fs.c: count doublewords read, returned unsigned.
func FS_ReadInt32LE(count: int, stream: FS_File) -> PackedInt64Array:
	var b: PackedByteArray = FS_Read(4, count, stream)
	var out: PackedInt64Array = PackedInt64Array()
	for i: int in range(b.size() / 4):
		out.append(b[i * 4] | (b[i * 4 + 1] << 8) | (b[i * 4 + 2] << 16) | (b[i * 4 + 3] << 24))
	return out


## id_fs.c: `ptr` holds the values the C's pointer points at.
func FS_WriteInt16LE(ptr: Array, count: int, stream: FS_File) -> int:
	var b: PackedByteArray = PackedByteArray()
	for i: int in range(count):
		var v: int = int(ptr[i])
		b.append(v & 0xFF)
		b.append((v >> 8) & 0xFF)
	return FS_Write(b, 2, count, stream)


func FS_WriteInt32LE(ptr: Array, count: int, stream: FS_File) -> int:
	var b: PackedByteArray = PackedByteArray()
	for i: int in range(count):
		var v: int = int(ptr[i])
		b.append(v & 0xFF)
		b.append((v >> 8) & 0xFF)
		b.append((v >> 16) & 0xFF)
		b.append((v >> 24) & 0xFF)
	return FS_Write(b, 4, count, stream)


## id_fs.c: the bools read (a nonzero word is true); size() is the C's count.
func FS_ReadBoolFrom16LE(count: int, stream: FS_File) -> Array:
	var out: Array = []
	for i: int in range(count):
		var b: PackedByteArray = FS_Read(2, 1, stream)
		if b.size() == 2:    # Should be either 0 or 1
			out.append((b[0] | (b[1] << 8)) != 0)
	return out


func FS_WriteBoolTo16LE(ptr: Array, count: int, stream: FS_File) -> int:
	var actualCount: int = 0
	for i: int in range(count):
		var v: int = 1 if ptr[i] else 0
		actualCount += FS_Write(PackedByteArray([v, 0]), 2, 1, stream)
	return actualCount


## id_fs.c: whether omnispeak's data folder holds `filename`. Without a file
## system: the episode file GalData has loaded is the one present.
func FS_IsOmniFilePresent(filename: String) -> bool:
	return data != null and data.ext != "" and filename.to_upper() == ("EPISODE." + data.ext).to_upper()


## id_ca.c: no file system, so every load fails (an empty buffer: the C's false).
func CA_LoadFile(_filename: String) -> PackedByteArray:
	return PackedByteArray()


## omnispeak caches a chunk again before using it in places the original just uses it (its
## print routines, CK_SetAction); the original's memory manager never hears of those, so
## here the chunk is cached only when it is missing (which the original could not survive).
func CA_EnsureGrChunk(chunk: int) -> void:
	if ca_graphChunks[chunk] == null:
		CA_CacheGrChunk(chunk)


## id_ca.c: MM_SetLock on the chunk.
func CA_LockGrChunk(chunk: int) -> void:
	if mm_started and ca_graphChunks[chunk] != null:
		MM_SetLock("gr:%d" % chunk, true)


## id_ca.c: the RLEW compressor. src is a map plane (words) from src_off;
## the compressed words are appended to dest. Returns the compressed length in bytes.
func CAL_RLEWCompress(src: PackedInt32Array, src_off: int, expLength: int, dest: PackedInt64Array, rletag: int) -> int:
	var compLength: int = 0
	var srcptr: int = src_off
	var count: int = 0

	if (expLength & 1) != 0:
		Quit("CAL_RLEWCompress: Expanded length must be divisible by 2.")
		return 0

	while expLength != 0:
		count = 1
		var val: int = src[srcptr] & 0xFFFF if srcptr < src.size() else 0
		srcptr += 1
		expLength -= 2
		while expLength != 0 and (src[srcptr] & 0xFFFF if srcptr < src.size() else 0) == val:
			count = u16(count + 1)
			expLength -= 2
			srcptr += 1
		if count > 3 or val == rletag:
			dest.append(rletag)
			dest.append(count)
			dest.append(val)
			compLength += 6
		else:
			compLength += count * 2
			while count != 0:
				count -= 1
				dest.append(val)
	return compLength


## id_ca.c: the RLEW expander, from the words in src into dest (a map plane)
## from dest_off.
func CAL_RLEWExpand(src: PackedInt64Array, dest: PackedInt32Array, dest_off: int, expLength: int, rletag: int) -> void:
	var srcptr: int = 0
	var dstptr: int = dest_off
	var count: int = 0
	var value: int = 0

	while expLength > 0:
		value = int(src[srcptr]) & 0xFFFF if srcptr < src.size() else 0
		srcptr += 1
		if value != rletag:
			if dstptr < dest.size():
				dest[dstptr] = value
			dstptr += 1
			expLength -= 2
		else:
			count = int(src[srcptr]) & 0xFFFF if srcptr < src.size() else 0
			srcptr += 1
			value = int(src[srcptr]) & 0xFFFF if srcptr < src.size() else 0
			srcptr += 1
			expLength -= count * 2
			if expLength < 0:
				return
			for i: int in range(count):
				if dstptr < dest.size():
					dest[dstptr] = value
				dstptr += 1


## id_ca.c: closes the data files; GalData holds none open.
func CA_Shutdown() -> void:
	pass


## id_vl.c: VL_ResizeScreen, the screen surface made anew at the size.
func VL_ResizeScreen(w: int, h: int) -> void:
	VL_DestroySurface(vl_screen)
	vl_screen = VL_CreateSurface(w, h)


## id_vl.c with id_vl_dos.c's setVideoMode(0): back to text mode 3.
func VL_Shutdown() -> void:
	if vl_screen != null:    # vl_started
		VL_DestroySurface(vl_screen)
		vl_screen = null
		vm.card.bios_set_video_mode(0x03)


## id_cfg.c: saves OMNISPK.CFG when started; CFG_Startup is the shell's, so
## nothing was started here.
func CFG_Shutdown() -> void:
	pass


## rand()'s state (the C library's, seeded 1 as an unseeded rand() is).
var rand_seed: int = 1


## rand(): Borland C's (the original's compiler, as CK_FizzleFade's note says):
## seed = seed * 0x015A4E35 + 1, the result bits 16-30.
func rand() -> int:
	rand_seed = (rand_seed * 0x015A4E35 + 1) & 0xFFFFFFFF
	return (rand_seed >> 16) & 0x7FFF


## ck_config.h (the vanilla build)
const FS_MAX_FILENAME_LEN: int = 24


const CK_NEW_FEATURE_DEFAULT: bool = false


# ===================================================================== id_mm.c (TIME-G)
# The original's memory manager, kept beside the port's own storage. What it throws out (a
# purgeable block in the way of an allocation) and when it compacts memory (MML_SortMem)
# decide what the original loads again and when it spends time moving memory, which the
# recordings show (REPLAY-G4's restarts, TIME-G4's demo box). The blocks are the original's:
# start and length in paragraphs, the lock and purge bits, a list in address order; each is
# keyed by the C pointer variable it belongs to ("gr:N" grsegs[N], "aud:N" audiosegs[N],
# "map:P" a map plane, "maphead:N", and the temporaries by name). A block purged has its
# owner cleared (_mm_purged), so the port caches the thing again, at its cost. The regions
# (the DOS program's near and far heaps, the upper memory with the EMS frame) are the
# machine's, read from the original's own memory map (F10-M) under DOSBox: mm_layout().

const MM_LOCKBIT: int = 1
const MM_PURGEBIT: int = 2
const MM_BUFFERSIZE: int = 0x1000


class MMBlock:
	var start: int = 0
	var length: int = 0
	var attr: int = 0
	var key: String = ""
	var next: MMBlock = null


## The cached audio chunks (id_ca.c's audiosegs; GalIO fills it), here so the manager can clear one.
var CA_audio: Array = []

var mm_head: MMBlock = null
var mm_rover: MMBlock = null
var mm_blocks: Dictionary = {}    # key -> MMBlock
var mm_error: bool = false        # mmerror
var mm_bombonerror: bool = true
var mm_started: bool = false
var mm_mainmem: int = 0
var mm_emsmem: int = 0
var mm_xmsmem: int = 0


## The DOS memory the original's manager gets, in paragraphs [start, length]: the near heap
## (what is left of the data segment), the far heap (DOS's free memory above the program), the
## upper memory blocks with the EMS page frame (one gap, 0xd001-0xf000), and the start-up text
## screen's buffer that InitGame hands over. Keen 4 v1.4 under DOSBox with 632K free
## (keen4_mem08_a); tile8 and tile8m are the sizes the original allocates for those chunks
## (its compile-time counts, 108 and 36 tiles, not the data's). Episodes override.
func mm_layout() -> Dictionary:
	return {"near": [0x3f34, 0xee], "far": [0x408b, 0x5f73], "high": [0xd001, 0x1fff],
		"introscn": [0x2187, 0xfa], "tile8": 108, "tile8m": 36}


func MM_Startup() -> void:
	if OS.has_environment("MMOFF"):    # a harness switch: the port without the manager
		return
	var lay: Dictionary = mm_layout()
	mm_head = MMBlock.new()
	mm_head.start = 0
	mm_head.length = 0xffff
	mm_head.attr = MM_LOCKBIT
	mm_blocks = {}
	mm_rover = mm_head
	mm_error = false
	mm_bombonerror = true
	mm_started = true
	MML_UseSpace(lay.near[0], lay.near[1])
	MML_UseSpace(lay.far[0], lay.far[1])
	mm_mainmem = (lay.near[1] + lay.far[1]) * 16
	# EMS (4 pages at the frame) and the XMS upper memory blocks, adjacent here
	MML_UseSpace(lay.high[0], lay.high[1])
	mm_emsmem = 0x10000
	mm_xmsmem = (lay.high[1] - 0x1000) * 16
	mm_rover = mm_head
	# the misc buffer: the first allocation (keen4_mem08_a: the far heap starts with it)
	MM_GetPtr("bufferseg", MM_BUFFERSIZE)


func MM_Shutdown() -> void:
	mm_started = false


## A range of memory the manager may use, taken out of the locked block holding it.
func MML_UseSpace(segstart: int, seglength: int) -> void:
	if not mm_started:
		return
	var scan: MMBlock = mm_head
	var last: MMBlock = mm_head
	mm_rover = mm_head
	while scan.start + scan.length < segstart:
		last = scan
		scan = scan.next
	var oldend: int = scan.start + scan.length
	var extra: int = oldend - (segstart + seglength)
	if extra < 0:
		Quit("MML_UseSpace: Segment spans two blocks!")
		return
	if segstart == scan.start:
		last.next = scan.next
		scan = last
	else:
		scan.length = segstart - scan.start
	if extra > 0:
		var b: MMBlock = MMBlock.new()
		b.next = scan.next
		scan.next = b
		b.start = segstart + seglength
		b.length = extra
		b.attr = MM_LOCKBIT


## FREEBLOCK: the block's owner loses it.
func _mm_free_block(b: MMBlock) -> void:
	if b.key != "":
		mm_blocks.erase(b.key)
		_mm_purged(b.key)


## The owner of a purged block: the port's cache of it is cleared, so it is read again.
func _mm_purged(key: String) -> void:
	if key.begins_with("gr:"):
		ca_graphChunks[int(key.substr(3))] = null
	elif key.begins_with("aud:"):
		var n: int = int(key.substr(4))
		if n < CA_audio.size():
			CA_audio[n] = null
	elif key.begins_with("maphead:"):
		CA_MapHeaders.erase(int(key.substr(8)))


## Allocates an unlocked, unpurgable block; false when there is no room (bombonerror off).
func MM_GetPtr(key: String, size: int) -> bool:
	if not mm_started:
		return true
	if mm_blocks.has(key):
		push_warning("MM_GetPtr: %s allocated twice" % key)
		MM_FreePtr(key)
	@warning_ignore("integer_division")
	var needed: int = (size + 15) / 16
	var mmnew: MMBlock = MMBlock.new()
	mmnew.length = needed
	mmnew.key = key
	mmnew.attr = 0
	for search: int in range(3):
		var lastscan: MMBlock
		var scan: MMBlock
		var endscan: MMBlock = null
		# first search: right after the rover, then on up; second: from the head up to the
		# rover; third: compress memory, then from the start
		if search == 1 and mm_rover == mm_head:
			continue
		match search:
			0:
				lastscan = mm_rover
				scan = mm_rover.next
			1:
				lastscan = mm_head
				scan = mm_head.next
				endscan = mm_rover
			_:
				MML_SortMem()
				lastscan = mm_head
				scan = mm_head.next
		var startseg: int = lastscan.start + lastscan.length
		while scan != endscan:
			if scan.start - startseg >= needed:
				# room between the end of lastscan and the start of scan: throw out
				# anything in the middle and allocate there
				var purge: MMBlock = lastscan.next
				lastscan.next = mmnew
				mmnew.start = startseg
				mmnew.next = scan
				while purge != scan:
					var nxt: MMBlock = purge.next
					_mm_free_block(purge)
					purge = nxt
				mm_rover = mmnew
				mm_blocks[key] = mmnew
				return true
			# a block locked or at purge level zero is skipped past
			if (scan.attr & MM_LOCKBIT) != 0 or (scan.attr & MM_PURGEBIT) == 0:
				lastscan = scan
				startseg = lastscan.start + lastscan.length
			scan = scan.next
	if mm_bombonerror:
		Quit("MM_GetPtr: Out of memory!")
	else:
		mm_error = true
	return false


func MM_FreePtr(key: String) -> void:
	if not mm_started:
		return
	if mm_rover.key == key:    # removed the last allocated block
		mm_rover = mm_head
	var last: MMBlock = mm_head
	var scan: MMBlock = mm_head.next
	while scan != null and scan.key != key:
		last = scan
		scan = scan.next
	if scan == null:
		Quit("MM_FreePtr: Block not found! (%s)" % key)
		return
	last.next = scan.next
	mm_blocks.erase(key)


## The rover moved to the block (MML_SetRover): on from where it is, round to the head.
func _mm_set_rover(key: String) -> bool:
	var start: MMBlock = mm_rover
	while true:
		if mm_rover.key == key:
			return true
		mm_rover = mm_rover.next
		if mm_rover == null:
			mm_rover = mm_head
		elif mm_rover == start:
			return false
	return false


func MM_SetPurge(key: String, purge: bool) -> void:
	if not mm_started:
		return
	if not _mm_set_rover(key):
		Quit("MM_SetPurge: Block not found! (%s)" % key)
		return
	mm_rover.attr &= ~MM_PURGEBIT
	if purge:
		mm_rover.attr |= MM_PURGEBIT


func MM_SetLock(key: String, locked: bool) -> void:
	if not mm_started:
		return
	if not _mm_set_rover(key):
		Quit("MM_SetLock: Block not found! (%s)" % key)
		return
	mm_rover.attr &= ~MM_LOCKBIT
	if locked:
		mm_rover.attr |= MM_LOCKBIT


## Throws out all purgeable blocks and piles the movable ones down, each moved block costing
## its paragraphs (TIME-G, mmmove); the border turns white meanwhile, as the original's does.
func MML_SortMem() -> void:
	var playing: int = SD_SoundPlaying()
	var sound_key: String = ""
	if playing != 0 and mm_blocks.has("aud:%d" % playing):
		sound_key = "aud:%d" % playing
		MM_SetLock(sound_key, true)
	var oldborder: int = vl_border_color
	VL_ColorBorder(15)
	var moved: int = 0
	var start: int = 0
	var last: MMBlock = null
	var scan: MMBlock = mm_head
	while scan != null:
		if (scan.attr & MM_LOCKBIT) != 0:
			# locked: later blocks pile right after it
			start = scan.start + scan.length
		elif (scan.attr & MM_PURGEBIT) != 0:
			# the purgeable block goes
			var nxt: MMBlock = scan.next
			_mm_free_block(scan)
			last.next = nxt
			scan = nxt
			continue
		else:
			if scan.start != start:
				moved += scan.length
				scan.start = start
			start = scan.start + scan.length
		last = scan
		scan = scan.next
	mm_rover = mm_head
	cost_n("mmmove", moved)
	VL_ColorBorder(oldborder)
	if sound_key != "":
		MM_SetLock(sound_key, false)


## The free space in bytes, the purgeable (unlocked) blocks counted when asked.
func MM_FreeMemory(withpurging: bool) -> int:
	if not mm_started:
		return 0
	var free: int = 0
	var scan: MMBlock = mm_head
	while scan.next != null:
		if withpurging and (scan.attr & MM_PURGEBIT) != 0 and (scan.attr & MM_LOCKBIT) == 0:
			free += scan.length
		free += scan.next.start - (scan.start + scan.length)
		scan = scan.next
	return free * 16


func MM_BombOnError(bomb: bool) -> void:
	mm_bombonerror = bomb


## id_sd.c's, GalIO's: the sound playing, which MML_SortMem locks down meanwhile.
func SD_SoundPlaying() -> int:
	return 0


## The debug key's picture of memory: one pixel a paragraph, 320 to a row, each block a line
## (purple purgeable, blue not, red locked) from a white pixel at its start, free space black.
func MM_ShowMemory() -> void:
	if not mm_started:
		return
	if OS.has_environment("MMDUMP"):    # a harness aid: the block list behind the picture
		var b: MMBlock = mm_head
		while b != null:
			print("MMDUMP %s %s %d %s" % [String.num_int64(b.start, 16), String.num_int64(b.length, 16), b.attr, b.key])
			b = b.next
	var scan: MMBlock = mm_head
	var end: int = -1
	while scan != null:
		var color: int = 5 if (scan.attr & MM_PURGEBIT) != 0 else 9
		if (scan.attr & MM_LOCKBIT) != 0:
			color = 12
		if scan.start <= end:
			Quit("MM_ShowMemory: Memory block order currupted!")
			return
		end = scan.start + scan.length - 1
		_mm_hlin(scan.start, end, color)
		_mm_hlin(scan.start, scan.start, 15)
		if scan.next != null and scan.next.start > end + 1:
			_mm_hlin(end + 1, scan.next.start, 0)
		scan = scan.next
	VL_ShowRows(0, VL_EGAVGA_GFX_HEIGHT)
	# (the caller waits for the key, IN_Ack)


## VW_Hlin over the 320-wide memory picture, paragraphs a..b inclusive.
func _mm_hlin(a: int, b: int, color: int) -> void:
	var i: int = a
	while i <= b and i < 320 * VL_EGAVGA_GFX_HEIGHT:
		@warning_ignore("integer_division")
		var y: int = i / 320
		var x: int = i % 320
		var run: int = mini(b - i + 1, 320 - x)
		# the original shows the page from address 0; here the shown window is at the scroll
		VL_ScreenRect(x + vl_scrollXpixels, y + vl_scrollYpixels, run, 1, color)
		i += run


## C's errno, as the port's file calls leave it (ENOENT for a user file that
## is not there).
var errno: int = 0


const ENOENT: int = 2


func FS_IsFileValid(file: FS_File) -> bool:
	return file != null


## getenv(): the port has no environment ("" is NULL).
func getenv(_name: String) -> String:
	return ""


## ck_cross.h
static func CK_Cross_clamp(x: int, a: int, b: int) -> int:
	return CK_Cross_max(CK_Cross_min(x, b), a)


## ck_cross.c, over the strings' bytes (a NUL ends each).
static func CK_Cross_strcasecmp(s1: String, s2: String) -> int:
	var b1: PackedByteArray = s1.to_ascii_buffer()
	var b2: PackedByteArray = s2.to_ascii_buffer()
	b1.append(0)
	b2.append(0)
	var i: int = 0
	while b1[i] != 0 and CK_Cross_toupper(b1[i]) == CK_Cross_toupper(b2[mini(i, b2.size() - 1)]):
		i += 1
	var uc1: int = CK_Cross_toupper(b1[i]) & 0xFF
	var uc2: int = CK_Cross_toupper(b2[mini(i, b2.size() - 1)]) & 0xFF
	return uc1 - uc2


## ck_cross.h: CK_Log_Message_Class_T
const CK_LOG_MSG_NORMAL: int = 0


const CK_LOG_MSG_WARNING: int = 1


const CK_LOG_MSG_ERROR: int = 2


const CK_LOG_MSG_NONE: int = 3


## ck_cross.c: the message on stdout/stderr (the format already applied);
## the port logs it verbosely (the log level is the shell's).
func CK_Cross_LogMessage(msgClass: int, msg: String) -> void:
	match msgClass:
		CK_LOG_MSG_NORMAL:
			print_verbose(msg.strip_edges(false, true))
		CK_LOG_MSG_WARNING:
			print_verbose("Warning: " + msg.strip_edges(false, true))
		CK_LOG_MSG_ERROR:
			print_verbose("Error: " + msg.strip_edges(false, true))


## CK_Cross_toupper over a C char.
static func CK_Cross_toupper(c: int) -> int:
	return c - 32 if c >= 97 and c <= 122 else c
