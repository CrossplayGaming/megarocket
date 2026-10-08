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


## CFG_GetConfigInt: omnispeak's config file; the port runs with its defaults.
func CFG_GetConfigInt(_name: String, default: int) -> int:
	return default


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


## ck_*/id_us: the program stops with a message.
var quit_message: String = ""
var quitting: bool = false


func Quit(msg: String) -> void:
	if not quitting:
		quitting = true
		quit_message = msg
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
	# CAL_SetupGrFile: the three header tables are cached at once and kept
	CA_CacheGrChunk(int(ca_gfxInfoE.hdrBitmaps))
	CA_CacheGrChunk(int(ca_gfxInfoE.hdrMasked))
	CA_CacheGrChunk(int(ca_gfxInfoE.hdrSprites))


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


func CA_CacheGrChunk(chunk: int) -> void:
	CA_MarkGrChunk(chunk)
	if ca_graphChunks[chunk] != null:
		return
	if data.chunk_start(chunk) == -1:
		return
	if chunk >= int(ca_gfxInfoE.offSprites) and chunk < int(ca_gfxInfoE.offSprites) + int(ca_gfxInfoE.numSprites):
		CAL_CacheSprite(chunk)
	else:
		var expanded: PackedByteArray = data.chunk(chunk)
		if data.error != "":
			Quit("Tried to expand an invalid chunk! Make sure you're using a compatible version of Keen!")
			return
		ca_graphChunks[chunk] = expanded


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


## Purging is a memory matter the port does not have: chunks stay cached.
func CA_SetGrPurge() -> void:
	pass


func CA_MarkGrChunk(chunk: int) -> void:
	ca_graphChunkNeeded[chunk] = ca_graphChunkNeeded[chunk] | ca_levelbit


func CA_CacheMarks(_msg: String) -> void:
	for i: int in range(ca_graphChunkNeeded.size()):
		if (ca_graphChunkNeeded[i] & ca_levelbit) != 0 and ca_graphChunks[i] == null:
			CA_CacheGrChunk(i)


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
func CA_MarkAllLumps(lumpStarts: PackedInt32Array, lumpEnds: PackedInt32Array) -> void:
	for i: int in range(ca_lumpsNeeded.size()):
		if ca_lumpsNeeded[i] != 0:
			for chunk: int in range(lumpStarts[i], lumpEnds[i] + 1):
				CA_MarkGrChunk(chunk)


func CA_CacheMap(mapIndex: int) -> void:
	ca_mapOn = mapIndex
	var m: Dictionary = data.load_map(mapIndex)
	if m.is_empty():
		Quit("CA_CacheMap: Tried to load a non-existant map!")
		return
	CA_MapHeaders[mapIndex] = {"width": int(m.width), "height": int(m.height), "name": String(m.get("name", ""))}
	for plane: int in range(CA_NUMMAPPLANES):
		CA_mapPlanes[plane] = (m.plane[plane] as PackedInt32Array).duplicate()


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


func VL_FadeFromBlack() -> void:
	for i: int in range(4):
		vl_palette[i][16] = vl_border_color
		VL_SetPaletteAndBorderColor(vl_palette[i])
		VL_Present()
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


## The original's VW_WaitVBL: whole refreshes on the machine.
func VL_DelayTics(tics: int) -> void:
	vm.wait_vbl(tics)


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


## The 320 x 200 window at the scroll position, written into the card's hidden
## page in write mode 0 one plane at a time, then shown from the next retrace.
func VL_Present() -> void:
	vl_lastFrameTime = SD_GetTimeCount()
	var card: EgaCard = vm.card
	var page: int = 1 - vl_shownPage
	var base: int = page * EgaCard.PAGE_SIZE
	var src: PackedByteArray = vl_screen.pixels
	var pitch: int = vl_screen.w
	var p0: PackedByteArray = card.plane0
	var p1: PackedByteArray = card.plane1
	var p2: PackedByteArray = card.plane2
	var p3: PackedByteArray = card.plane3
	for y: int in range(VL_EGAVGA_GFX_HEIGHT):
		var srow: int = (y + vl_scrollYpixels) * pitch + vl_scrollXpixels
		var drow: int = base + y * (VL_EGAVGA_GFX_WIDTH / 8)
		for bx: int in range(VL_EGAVGA_GFX_WIDTH / 8):
			var b0: int = 0
			var b1: int = 0
			var b2: int = 0
			var b3: int = 0
			var s: int = srow + bx * 8
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
			p0[drow + bx] = b0
			p1[drow + bx] = b1
			p2[drow + bx] = b2
			p3[drow + bx] = b3
	card.plane0 = p0
	card.plane1 = p1
	card.plane2 = p2
	card.plane3 = p3
	# the CRTC start address, latched by the card at the next retrace
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTHIGH)
	vm.out8(EgaCard.CRTC_DATA, (base >> 8) & 0xFF)
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTLOW)
	vm.out8(EgaCard.CRTC_DATA, base & 0xFF)
	vl_shownPage = page


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
func VH_MeasurePropString(string: String, chunk: int) -> PackedInt32Array:
	var width: int = 0
	var height: int = 0
	for i: int in range(string.length()):
		var ci: Dictionary = VH_GetFontCharInfo(chunk, string.unicode_at(i) & 0xFF)
		width = (width + ci.width) & 0xFFFF
		height = ci.height
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


func VH_UpdateScreen() -> void:
	VL_Present()
