# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's id_rf.c (the refresh manager: tile buffer, dirty
# blocks, scroll blocks, animated tiles, sprite draw lists and erasers, the
# frame's tic calculation) by David Gow and the Omnispeak authors, GPL v2 or
# later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalRF
extends GalLib
## The Galaxy refresh manager (SIM-G-01b). Tiles are drawn into a tile buffer
## surface as the view scrolls a tile at a time; each frame the dirty blocks
## are copied to the screen surface, sprites are erased and redrawn, and the
## screen surface is presented at the pixel scroll position.
##
## C's RF_SpriteDrawEntry ** parameters become a value passed in and the new
## value returned (`obj.sde = RF_AddSpriteDraw(obj.sde, ...)`); an entry's
## prevNextPtr (the address of whatever points at it) is `prev_owner`: the
## entry before it in its layer, or the layer's index when it is first.

const RF_MAX_BUFFERS: int = 2
## id_rf.h: the number of sprite priorities (z layers).
const PRIORITIES: int = 4
## id_rf.h: global >> G_T_SHIFT = tile.
const G_T_SHIFT: int = 8
const RF_MAX_SCROLLBLOCKS: int = 6
const RF_SCREEN_WIDTH_TILES: int = 20
const RF_SCREEN_HEIGHT_TILES: int = 13
const RF_BUFFER_WIDTH_UNITS: int = RF_BUFFER_WIDTH_TILES << 8
const RF_BUFFER_HEIGHT_UNITS: int = RF_BUFFER_HEIGHT_TILES << 8
const RF_MAX_SPRITETABLEENTRIES: int = 60
const RF_NUM_SPRITE_Z_LAYERS: int = 4
const RF_MAX_ANIMTILETIMERS: int = 180
const RF_MAX_ONSCREENANIMTILES: int = 90
const RF_MAX_ANIM_LOOP: int = 20
const RF_BUFFER_SIZE: int = RF_BUFFER_WIDTH_TILES * RF_BUFFER_HEIGHT_TILES
const TILEGLOBAL: int = 256
const PIXGLOBAL: int = 16


static func RF_UnitToTile(u: int) -> int:
	return u >> 8


static func RF_TileToUnit(t: int) -> int:
	return t << 8


static func RF_UnitToPixel(u: int) -> int:
	return u >> 4


static func RF_PixelToUnit(p: int) -> int:
	return p << 4


static func RF_PixelToTile(p: int) -> int:
	return p >> 4


static func RF_TileToPixel(t: int) -> int:
	return t << 4


class RF_SpriteDrawEntry:
	var index: int = 0          # its slot in rf_spriteTable (for 16-bit offsets)
	var chunk: int = 0
	var zLayer: int = 0
	var x: int = 0
	var y: int = 0
	var sx: int = 0
	var sy: int = 0
	var sw: int = 0
	var sh: int = 0
	var maskOnly: bool = false
	var updateCount: int = 0
	var shift: int = 0
	var prev_owner: Variant = null    # RF_SpriteDrawEntry, or the layer index (int)
	var next: RF_SpriteDrawEntry = null


class RF_AnimTileTimer:
	var tileNumber: int = 0
	var timeToSwitch: int = 0
	var tileWithSound: int = 0
	var numOfOnScreenTiles: int = 0
	var sound: int = 0


class RF_OnscreenAnimTile:
	var tileX: int = 0
	var tileY: int = 0
	var tile: int = 0
	var plane: int = 0
	var timerIndex: int = 0
	var next: RF_OnscreenAnimTile = null
	var prev: RF_OnscreenAnimTile = null


var rf_horzScrollBlocks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var rf_vertScrollBlocks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var rf_numHorzScrollBlocks: int = 0
var rf_numVertScrollBlocks: int = 0
var rf_tileBuffer: VL_Surface = null
var rf_mapWidthTiles: int = 0
var rf_mapHeightTiles: int = 0
var rf_scrollXUnit: int = 0
var rf_scrollYUnit: int = 0
var rf_scrollXMinUnit: int = 0
var rf_scrollYMinUnit: int = 0
var rf_scrollXMaxUnit: int = 0
var rf_scrollYMaxUnit: int = 0

var rf_spriteTable: Array[RF_SpriteDrawEntry] = []
var rf_freeSpriteTableEntry: RF_SpriteDrawEntry = null
var rf_firstSpriteTableEntry: Array = [null, null, null, null]
var rf_numSpriteDraws: int = 0
var rf_freeSpriteEraserIndex: PackedInt32Array = PackedInt32Array([0, 0])
## Erasers: four ints each (pxX, pxY, pxW, pxH), RF_MAX_SPRITETABLEENTRIES per page.
var rf_spriteErasers: PackedInt32Array = PackedInt32Array()

var rf_numAnimTileTimers: int = 0
var rf_animTileTimers: Array[RF_AnimTileTimer] = []
var rf_onscreenAnimTiles: Array[RF_OnscreenAnimTile] = []
var rf_firstOnscreenAnimTile: RF_OnscreenAnimTile = null
var rf_freeOnscreenAnimTile: RF_OnscreenAnimTile = null

var rf_minTics: int = 1
var rf_maxTics: int = 5
var rf_demoTics: int = 3

var rf_dirtyBlocks: Array = [PackedByteArray(), PackedByteArray()]
var rf_dirtyBufferOffset: int = 0
## rf_drawFunc: a method name called after the sprites are drawn ("" for none).
var rf_drawFunc: StringName = &""


func _init() -> void:
	for i: int in range(RF_MAX_SPRITETABLEENTRIES):
		var e: RF_SpriteDrawEntry = RF_SpriteDrawEntry.new()
		e.index = i
		rf_spriteTable.append(e)
	rf_spriteErasers.resize(RF_MAX_SPRITETABLEENTRIES * RF_MAX_BUFFERS * 4)
	for i: int in range(RF_MAX_ANIMTILETIMERS):
		rf_animTileTimers.append(RF_AnimTileTimer.new())
	for i: int in range(RF_MAX_ONSCREENANIMTILES):
		rf_onscreenAnimTiles.append(RF_OnscreenAnimTile.new())
	for p: int in range(RF_MAX_BUFFERS):
		var d: PackedByteArray = PackedByteArray()
		d.resize(RF_BUFFER_SIZE)
		rf_dirtyBlocks[p] = d


## Where prevNextPtr points: the owner's `next`, or the layer's first entry.
func _set_prev_next(owner: Variant, value: RF_SpriteDrawEntry) -> void:
	if owner is int:
		rf_firstSpriteTableEntry[owner] = value
	elif owner != null:
		(owner as RF_SpriteDrawEntry).next = value


func RFL_ConvertAnimTileTimerIndexTo16BitOffset(i: int) -> int:
	return (CK_INT("ck_exe_animTileSize", 4) * i + CK_INT("ck_exe_animTilesOffset", 0x0000)) & 0xFFFF


func RFL_ConvertAnimTileTimer16BitOffsetToIndex(offset: int) -> int:
	return (offset - CK_INT("ck_exe_animTilesOffset", 0x0000)) / CK_INT("ck_exe_animTileSize", 4)


func RFL_MarkBlockDirty(x: int, y: int, val: int, page: int) -> void:
	if x >= RF_BUFFER_WIDTH_TILES or y >= RF_BUFFER_HEIGHT_TILES:
		return
	if page == -1:
		for _page: int in range(VL_GetNumBuffers()):
			RFL_MarkBlockDirty(x, y, val, _page)
	else:
		if rf_dirtyBufferOffset < 0:
			rf_dirtyBufferOffset += RF_BUFFER_SIZE
		var offset: int = posmod((y * RF_BUFFER_WIDTH_TILES + x) + rf_dirtyBufferOffset, RF_BUFFER_SIZE)
		rf_dirtyBlocks[page][offset] = val


func RFL_IsBlockDirty(x: int, y: int, page: int) -> int:
	if x >= RF_BUFFER_WIDTH_TILES or y >= RF_BUFFER_HEIGHT_TILES:
		return 0
	if page == -1:
		return RFL_IsBlockDirty(x, y, VL_GetActiveBuffer())
	if rf_dirtyBufferOffset < 0:
		rf_dirtyBufferOffset += RF_BUFFER_SIZE
	var offset: int = posmod((y * RF_BUFFER_WIDTH_TILES + x) + rf_dirtyBufferOffset, RF_BUFFER_SIZE)
	return rf_dirtyBlocks[page][offset]


func RF_SetScrollBlock(tileX: int, tileY: int, vertical: bool) -> void:
	if not vertical:
		if rf_numHorzScrollBlocks == RF_MAX_SCROLLBLOCKS:
			Quit("RF_SetScrollBlock: Too many horizontal scroll blocks")
			return
		rf_horzScrollBlocks[rf_numHorzScrollBlocks] = tileX
		rf_numHorzScrollBlocks += 1
	else:
		if rf_numVertScrollBlocks == RF_MAX_SCROLLBLOCKS:
			Quit("RF_SetScrollBlock: Too many vertical scroll blocks")
			return
		rf_vertScrollBlocks[rf_numVertScrollBlocks] = tileY
		rf_numVertScrollBlocks += 1


func RFL_SetupOnscreenAnimList() -> void:
	rf_freeOnscreenAnimTile = rf_onscreenAnimTiles[0]
	for i: int in range(RF_MAX_ONSCREENANIMTILES - 1):
		rf_onscreenAnimTiles[i].next = rf_onscreenAnimTiles[i + 1]
	rf_onscreenAnimTiles[RF_MAX_ONSCREENANIMTILES - 1].next = null
	rf_firstOnscreenAnimTile = null
	if ck_currentEpisode_ep == EP_CK6:
		var k: int = 0
		while k < RF_MAX_ANIMTILETIMERS and rf_animTileTimers[k].tileNumber != 0:
			rf_animTileTimers[k].numOfOnScreenTiles = 0
			k += 1


func RFL_SetupSpriteTable() -> void:
	rf_freeSpriteTableEntry = rf_spriteTable[0]
	rf_numSpriteDraws = 0
	for i: int in range(RF_MAX_SPRITETABLEENTRIES - 1):
		rf_spriteTable[i].next = rf_spriteTable[i + 1]
		rf_spriteTable[i + 1].prev_owner = rf_spriteTable[i]
	rf_spriteTable[RF_MAX_SPRITETABLEENTRIES - 1].next = null
	for i: int in range(RF_NUM_SPRITE_Z_LAYERS):
		rf_firstSpriteTableEntry[i] = null


## Keen 6: the two animated tiles that play a sound when they come round.
func RFL_MarkTileWithSound(animTileTimer: RF_AnimTileTimer, tile: int) -> void:
	var tilesWithSounds: PackedInt32Array = PackedInt32Array([0x8868, 0x88a0, 58, 59])
	for i: int in range(2):
		if tile == tilesWithSounds[i]:
			animTileTimer.tileWithSound = tile
			animTileTimer.sound = tilesWithSounds[i + 2]
			return


func _clear_anim_timers() -> void:
	for t: RF_AnimTileTimer in rf_animTileTimers:
		t.tileNumber = 0
		t.timeToSwitch = 0
		t.tileWithSound = 0
		t.numOfOnScreenTiles = 0
		t.sound = 0


func RF_MarkTileGraphics() -> void:
	_clear_anim_timers()
	rf_numAnimTileTimers = 0
	# As in the original, `i` is not initialised (it only matters for
	# RFL_MarkTileWithSound in Keen 6, where vanilla shows no effect).
	var i: int = 0
	for plane: int in [0, 1]:
		for tileY: int in range(rf_mapHeightTiles):
			for tileX: int in range(rf_mapWidthTiles):
				var needNewTimer: bool = true
				var t: int = CA_TileAtPos(tileX, tileY, plane)
				var anim_tile: int
				var anim_time: int
				var tag: int
				if plane == 0:
					CA_MarkGrChunk(int(ca_gfxInfoE.offTiles16) + t)
					anim_tile = TI_BackAnimTile(t)
					anim_time = TI_BackAnimTime(t)
					tag = t
				else:
					CA_MarkGrChunk(int(ca_gfxInfoE.offTiles16m) + t)
					anim_tile = TI_ForeAnimTile(t)
					anim_time = TI_ForeAnimTime(t)
					tag = t | 0x8000
				if anim_tile == 0:
					continue
				if anim_time != 0:
					i = 0
					while i < rf_numAnimTileTimers:
						if rf_animTileTimers[i].tileNumber == tag:
							CA_SetTileAtPos(tileX, tileY, 2, RFL_ConvertAnimTileTimerIndexTo16BitOffset(i))
							needNewTimer = false
							break
						i += 1
					if needNewTimer:
						if i >= RF_MAX_ANIMTILETIMERS:
							Quit("RF_MarkTileGraphics: Too many unique animations")
							return
						var att: RF_AnimTileTimer = rf_animTileTimers[i]
						att.tileNumber = tag
						att.timeToSwitch = anim_time
						if ck_currentEpisode_ep == EP_CK6:
							att.numOfOnScreenTiles = 0
							att.sound = -1
						CA_SetTileAtPos(tileX, tileY, 2, RFL_ConvertAnimTileTimerIndexTo16BitOffset(i))
						rf_numAnimTileTimers += 1
					else:
						continue
				if ck_currentEpisode_ep == EP_CK6 and i < RF_MAX_ANIMTILETIMERS:
					RFL_MarkTileWithSound(rf_animTileTimers[i], tag)
				# mark every tile of the animation loop to be cached
				var animLength: int = 0
				var nextTileOffset: int = anim_tile
				var nextTile: int = t + nextTileOffset
				while nextTileOffset != 0 and nextTile != t:
					if plane == 0:
						if ck_currentEpisode_ep == EP_CK6 and i < RF_MAX_ANIMTILETIMERS:
							RFL_MarkTileWithSound(rf_animTileTimers[i], nextTile)
						CA_MarkGrChunk(int(ca_gfxInfoE.offTiles16) + nextTile)
						nextTileOffset = TI_BackAnimTile(nextTile)
					else:
						if ck_currentEpisode_ep == EP_CK6 and i < RF_MAX_ANIMTILETIMERS:
							RFL_MarkTileWithSound(rf_animTileTimers[i], nextTile | 0x8000)
						CA_MarkGrChunk(int(ca_gfxInfoE.offTiles16m) + nextTile)
						nextTileOffset = TI_ForeAnimTile(nextTile)
					nextTile += nextTileOffset
					animLength += 1
					if animLength > RF_MAX_ANIM_LOOP:
						Quit("RF_MarkTileGraphics: Unending %s animation" % ("background" if plane == 0 else "foreground"))
						return


func _add_onscreen(tileX: int, tileY: int, tile: int, plane: int) -> void:
	if rf_freeOnscreenAnimTile == null:
		Quit("RFL_CheckForAnimTile: No free spots in tilearray!")
		return
	var ost: RF_OnscreenAnimTile = rf_freeOnscreenAnimTile
	rf_freeOnscreenAnimTile = rf_freeOnscreenAnimTile.next
	ost.tileX = tileX
	ost.tileY = tileY
	ost.tile = tile
	ost.plane = plane
	ost.timerIndex = RFL_ConvertAnimTileTimer16BitOffsetToIndex(CA_TileAtPos(tileX, tileY, 2))
	if ck_currentEpisode_ep == EP_CK6 and ost.timerIndex >= 0 and ost.timerIndex < RF_MAX_ANIMTILETIMERS:
		rf_animTileTimers[ost.timerIndex].numOfOnScreenTiles += 1
	ost.next = rf_firstOnscreenAnimTile
	ost.prev = null
	rf_firstOnscreenAnimTile = ost


func RFL_CheckForAnimTile(tileX: int, tileY: int) -> void:
	var backTile: int = CA_TileAtPos(tileX, tileY, 0)
	var foreTile: int = CA_TileAtPos(tileX, tileY, 1)
	if TI_BackAnimTile(backTile) != 0 and TI_BackAnimTime(backTile) != 0:
		_add_onscreen(tileX, tileY, backTile, 0)
	if TI_ForeAnimTile(foreTile) != 0 and TI_ForeAnimTime(foreTile) != 0:
		_add_onscreen(tileX, tileY, foreTile, 1)


## The three RFL_RemoveAnim* loops: unlink every on-screen animated tile `hit`
## accepts, as omnispeak's loops do (restarting from the previous entry).
func _remove_anims(hit: Callable) -> void:
	var prev: RF_OnscreenAnimTile = null
	var ost: RF_OnscreenAnimTile = rf_firstOnscreenAnimTile
	while ost != null:
		if hit.call(ost):
			if ck_currentEpisode_ep == EP_CK6 and ost.timerIndex >= 0 and ost.timerIndex < RF_MAX_ANIMTILETIMERS:
				rf_animTileTimers[ost.timerIndex].numOfOnScreenTiles -= 1
			var obsolete: RF_OnscreenAnimTile = ost
			if prev != null:
				prev.next = ost.next
			else:
				rf_firstOnscreenAnimTile = ost.next
			ost = prev if prev != null else rf_firstOnscreenAnimTile
			obsolete.next = rf_freeOnscreenAnimTile
			rf_freeOnscreenAnimTile = obsolete
			continue
		prev = ost
		ost = ost.next


func RFL_RemoveAnimRect(tileX: int, tileY: int, tileW: int, tileH: int) -> void:
	_remove_anims(func(o: RF_OnscreenAnimTile) -> bool:
		return o.tileX >= tileX and o.tileX < tileX + tileW and o.tileY >= tileY and o.tileY < tileY + tileH)


func RFL_RemoveAnimCol(tileX: int) -> void:
	_remove_anims(func(o: RF_OnscreenAnimTile) -> bool: return o.tileX == tileX)


func RFL_RemoveAnimRow(tileY: int) -> void:
	_remove_anims(func(o: RF_OnscreenAnimTile) -> bool: return o.tileY == tileY)


func RFL_AnimateTiles() -> void:
	for i: int in range(rf_numAnimTileTimers):
		var att: RF_AnimTileTimer = rf_animTileTimers[i]
		att.timeToSwitch -= SD_GetSpriteSync()
		# ID_RF.C: `while (anim->count < 1)`: a fast animation steps as often as the frame's tics
		# cover it (omnispeak steps it once a frame)
		while att.timeToSwitch <= 0:
			if (att.tileNumber & 0x8000) != 0:
				var tile: int = att.tileNumber & ~0x8000
				tile += TI_ForeAnimTile(tile)
				att.timeToSwitch += TI_ForeAnimTime(tile)
				att.tileNumber = tile | 0x8000
			else:
				var tile: int = att.tileNumber
				tile += TI_BackAnimTile(tile)
				att.timeToSwitch += TI_BackAnimTime(tile)
				att.tileNumber = tile
			if ck_currentEpisode_ep == EP_CK6:
				if att.numOfOnScreenTiles != 0 and att.tileNumber == att.tileWithSound and (att.sound & 0xFFFF) != 0xFFFF:
					SD_PlaySound(att.sound)
			if quitting:
				return
	var ost: RF_OnscreenAnimTile = rf_firstOnscreenAnimTile
	while ost != null:
		var tile: int = rf_animTileTimers[ost.timerIndex].tileNumber & ~0x8000
		if tile != ost.tile:
			ost.tile = tile
			var screenTileX: int = ost.tileX - RF_UnitToTile(rf_scrollXUnit)
			var screenTileY: int = ost.tileY - RF_UnitToTile(rf_scrollYUnit)
			if screenTileX < 0 or screenTileX > RF_BUFFER_WIDTH_TILES or screenTileY < 0 or screenTileY > RF_BUFFER_HEIGHT_TILES:
				Quit("RFL_AnimateTiles: Out of bounds!")
				return
			CA_SetTileAtPos(ost.tileX, ost.tileY, ost.plane, tile)
			RF_RenderTile16(screenTileX, screenTileY, CA_TileAtPos(ost.tileX, ost.tileY, 0))
			RF_RenderTile16m(screenTileX, screenTileY, CA_TileAtPos(ost.tileX, ost.tileY, 1))
			RFL_MarkBlockDirty(screenTileX, screenTileY, 1, -1)
		ost = ost.next


func RF_SetDrawFunc(fn: StringName) -> void:
	rf_drawFunc = fn


func RF_Startup() -> void:
	rf_tileBuffer = VL_CreateSurface(RF_BUFFER_WIDTH_PIXELS, RF_BUFFER_HEIGHT_PIXELS)
	rf_minTics = CFG_GetConfigInt("rf_minTics", 2)
	rf_maxTics = CFG_GetConfigInt("rf_maxTics", 5)
	rf_demoTics = CFG_GetConfigInt("rf_demoTics", 3)


func RF_Shutdown() -> void:
	VL_DestroySurface(rf_tileBuffer)
	# the lists link their entries both ways: unlink them so they can be freed
	for e: RF_SpriteDrawEntry in rf_spriteTable:
		e.next = null
		e.prev_owner = null
	for o: RF_OnscreenAnimTile in rf_onscreenAnimTiles:
		o.next = null
		o.prev = null
	rf_freeSpriteTableEntry = null
	rf_firstSpriteTableEntry = [null, null, null, null]
	rf_firstOnscreenAnimTile = null
	rf_freeOnscreenAnimTile = null


func RF_NewMap() -> void:
	rf_mapWidthTiles = CA_GetMapWidth()
	rf_mapHeightTiles = CA_GetMapHeight()
	rf_scrollXMinUnit = 0x0200
	rf_scrollYMinUnit = 0x0200
	rf_scrollXMaxUnit = RF_TileToUnit(CA_GetMapWidth() - RF_SCREEN_WIDTH_TILES - 2)
	rf_scrollYMaxUnit = RF_TileToUnit(CA_GetMapHeight() - RF_SCREEN_HEIGHT_TILES - 2)
	rf_numVertScrollBlocks = 0
	rf_numHorzScrollBlocks = 0
	RFL_SetupOnscreenAnimList()
	RFL_SetupSpriteTable()
	for page: int in range(VL_GetNumBuffers()):
		rf_freeSpriteEraserIndex[page] = 0
	# a two-tile border
	RF_SetScrollBlock(0, 1, true)
	RF_SetScrollBlock(0, CA_GetMapHeight() - 2, true)
	RF_SetScrollBlock(1, 0, false)
	RF_SetScrollBlock(CA_GetMapWidth() - 2, 0, false)
	SD_SetLastTimeCount(SD_GetTimeCount())
	SD_SetSpriteSync(1)


func RF_RenderTile16(x: int, y: int, tile: int) -> void:
	var src: Variant = CA_GetGrChunk(int(ca_gfxInfoE.offTiles16), tile, "Tile16", false)
	# empty background tiles (Keen 6's Guard Post 3) are skipped
	if src == null:
		return
	VL_UnmaskedToSurface(src, 0, rf_tileBuffer, x * 16, y * 16, 16, 16)
	cost("tile16")    # TIME-G


func RF_RenderTile16m(x: int, y: int, tile: int) -> void:
	if tile == 0:
		return
	VL_MaskedBlitToSurface(CA_GetGrChunk(int(ca_gfxInfoE.offTiles16m), tile, "Tile16m", true), 0, rf_tileBuffer, x * 16, y * 16, 16, 16)
	cost("tile16m")    # TIME-G


func RF_ForceRefresh() -> void:
	RF_Reposition(rf_scrollXUnit, rf_scrollYUnit)
	RF_Refresh()
	RF_Refresh()


## Copy a block of tiles, in all planes, from one place on the map to another.
func RF_ReplaceTileBlock(srcx: int, srcy: int, destx: int, desty: int, width: int, height: int) -> void:
	RFL_RemoveAnimRect(destx, desty, width, height)
	for ty: int in range(height):
		for tx: int in range(width):
			var different: bool
			var src_bgtile: int = CA_TileAtPos(srcx + tx, srcy + ty, 0)
			var src_fgtile: int = CA_TileAtPos(srcx + tx, srcy + ty, 1)
			var src_infotile: int = CA_TileAtPos(srcx + tx, srcy + ty, 2)
			var dst_bgtile: int = CA_TileAtPos(destx + tx, desty + ty, 0)
			var dst_fgtile: int = CA_TileAtPos(destx + tx, desty + ty, 1)
			var dst_infotile: int = CA_TileAtPos(destx + tx, desty + ty, 2)
			if dst_bgtile != src_bgtile or dst_fgtile != src_fgtile or dst_infotile != src_infotile:
				CA_SetTileAtPos(destx + tx, desty + ty, 0, src_bgtile)
				CA_SetTileAtPos(destx + tx, desty + ty, 1, src_fgtile)
				CA_SetTileAtPos(destx + tx, desty + ty, 2, src_infotile)
				different = true
			else:
				different = false
			var screenX: int = destx + tx - RF_UnitToTile(rf_scrollXUnit)
			var screenY: int = desty + ty - RF_UnitToTile(rf_scrollYUnit)
			if screenX >= 0 and screenY >= 0 and screenY < RF_BUFFER_HEIGHT_TILES and screenX < RF_BUFFER_WIDTH_TILES:
				if different:
					RFL_MarkBlockDirty(screenX, screenY, 1, -1)
					RF_RenderTile16(screenX, screenY, src_bgtile)
					RF_RenderTile16m(screenX, screenY, src_fgtile)
				RFL_CheckForAnimTile(destx + tx, desty + ty)


## tiles: the words to put (width x height), C's uint16_t *tilePtr.
func RF_ReplaceTiles(tiles: PackedInt32Array, tiles_off: int, plane: int, dstX: int, dstY: int, width: int, height: int) -> void:
	RFL_RemoveAnimRect(dstX, dstY, width, height)
	for y: int in range(height):
		for x: int in range(width):
			var dstTileX: int = dstX + x
			var dstTileY: int = dstY + y
			var tileScreenX: int = dstTileX - RF_UnitToTile(rf_scrollXUnit)
			var tileScreenY: int = dstTileY - RF_UnitToTile(rf_scrollYUnit)
			var oldTile: int = CA_TileAtPos(dstTileX, dstTileY, plane)
			var newTile: int = tiles[tiles_off + y * width + x] & 0xFFFF
			if oldTile != newTile:
				CA_SetTileAtPos(dstTileX, dstTileY, plane, newTile)
			if tileScreenX >= 0 and tileScreenX < RF_BUFFER_WIDTH_TILES and tileScreenY >= 0 and tileScreenY < RF_BUFFER_HEIGHT_TILES:
				if oldTile != newTile:
					RFL_MarkBlockDirty(tileScreenX, tileScreenY, 1, -1)
					RF_RenderTile16(tileScreenX, tileScreenY, CA_TileAtPos(dstTileX, dstTileY, 0))
					RF_RenderTile16m(tileScreenX, tileScreenY, CA_TileAtPos(dstTileX, dstTileY, 1))
				RFL_CheckForAnimTile(dstTileX, dstTileY)


func RFL_RenderForeTiles() -> void:
	var scrollXtile: int = RF_UnitToTile(rf_scrollXUnit)
	var scrollYtile: int = RF_UnitToTile(rf_scrollYUnit)
	for stx: int in range(scrollXtile, scrollXtile + RF_BUFFER_WIDTH_TILES):
		for sty: int in range(scrollYtile, scrollYtile + RF_BUFFER_HEIGHT_TILES):
			var tile: int = CA_TileAtPos(stx, sty, 1)
			var bufferX: int = stx - scrollXtile
			var bufferY: int = sty - scrollYtile
			if RFL_IsBlockDirty(bufferX, bufferY, -1) != 3:
				continue
			if tile == 0:
				continue
			if (TI_ForeMisc(tile) & 0x80) == 0:
				continue
			VL_MaskedBlitToScreen(CA_GetGrChunk(int(ca_gfxInfoE.offTiles16m), tile, "Tile16m", true), 0,
				RF_TileToPixel(stx - scrollXtile), RF_TileToPixel(sty - scrollYtile), 16, 16)


## A new row of tiles at the bottom (dir) or the top.
func RFL_NewRowHorz(dir: bool) -> void:
	var bufferRow: int = RF_BUFFER_HEIGHT_TILES - 1 if dir else 0
	var mapRow: int = RF_UnitToTile(rf_scrollYUnit) + bufferRow
	var xOffset: int = RF_UnitToTile(rf_scrollXUnit)
	for i: int in range(RF_BUFFER_WIDTH_TILES):
		RFL_CheckForAnimTile(i + xOffset, mapRow)
		RFL_MarkBlockDirty(i, bufferRow, 1, -1)
		RF_RenderTile16(i, bufferRow, CA_TileAtPos(xOffset + i, mapRow, 0))
		RF_RenderTile16m(i, bufferRow, CA_TileAtPos(xOffset + i, mapRow, 1))


## A new column of tiles at the right (dir) or the left.
func RFL_NewRowVert(dir: bool) -> void:
	var bufferCol: int = RF_BUFFER_WIDTH_TILES - 1 if dir else 0
	var mapCol: int = RF_UnitToTile(rf_scrollXUnit) + bufferCol
	var yOffset: int = RF_UnitToTile(rf_scrollYUnit)
	for i: int in range(RF_BUFFER_HEIGHT_TILES):
		RFL_CheckForAnimTile(mapCol, i + yOffset)
		RFL_MarkBlockDirty(bufferCol, i, 1, -1)
		RF_RenderTile16(bufferCol, i, CA_TileAtPos(mapCol, yOffset + i, 0))
		RF_RenderTile16m(bufferCol, i, CA_TileAtPos(mapCol, yOffset + i, 1))


func RF_RepositionLimit(scrollXunit: int, scrollYunit: int) -> void:
	rf_scrollXUnit = scrollXunit
	rf_scrollYUnit = scrollYunit
	if scrollXunit < rf_scrollXMinUnit:
		rf_scrollXUnit = rf_scrollXMinUnit
	if scrollYunit < rf_scrollYMinUnit:
		rf_scrollYUnit = rf_scrollYMinUnit
	if scrollXunit > rf_scrollXMaxUnit:
		rf_scrollXUnit = rf_scrollXMaxUnit
	if scrollYunit > rf_scrollYMaxUnit:
		rf_scrollYUnit = rf_scrollYMaxUnit
	var scrollXtile: int = RF_UnitToTile(rf_scrollXUnit)
	var scrollYtile: int = RF_UnitToTile(rf_scrollYUnit)
	var leftHalf: int = RF_SCREEN_WIDTH_TILES / 2
	var topHalf: int = RF_SCREEN_HEIGHT_TILES / 2
	for sb: int in range(rf_numHorzScrollBlocks):
		var b: int = rf_horzScrollBlocks[sb]
		if b >= scrollXtile and scrollXtile + leftHalf >= b:
			rf_scrollXUnit = RF_TileToUnit(b) + RF_TileToUnit(1)
			break
		if scrollXtile + leftHalf + 1 <= b and scrollXtile + RF_SCREEN_WIDTH_TILES >= b:
			rf_scrollXUnit = RF_TileToUnit(b) - RF_TileToUnit(RF_SCREEN_WIDTH_TILES)
			break
	for sb: int in range(rf_numVertScrollBlocks):
		var b: int = rf_vertScrollBlocks[sb]
		if b >= scrollYtile and scrollYtile + topHalf >= b:
			rf_scrollYUnit = RF_TileToUnit(b) + RF_TileToUnit(1)
			break
		if scrollYtile + topHalf + 1 <= b and scrollYtile + RF_SCREEN_HEIGHT_TILES >= b:
			rf_scrollYUnit = RF_TileToUnit(b) - RF_TileToUnit(RF_SCREEN_HEIGHT_TILES)
			break


func RFL_SmoothScrollLimit(scrollXdelta: int, scrollYdelta: int) -> void:
	rf_scrollXUnit += scrollXdelta
	rf_scrollYUnit += scrollYdelta
	var scrollXtile: int = RF_UnitToTile(rf_scrollXUnit)
	var scrollYtile: int = RF_UnitToTile(rf_scrollYUnit)
	if scrollXdelta > 0:
		scrollXtile += RF_SCREEN_WIDTH_TILES
		for sb: int in range(rf_numHorzScrollBlocks):
			if rf_horzScrollBlocks[sb] == scrollXtile:
				rf_scrollXUnit &= ~0xff
				break
	elif scrollXdelta < 0:
		for sb: int in range(rf_numHorzScrollBlocks):
			if rf_horzScrollBlocks[sb] == scrollXtile:
				rf_scrollXUnit &= ~0xff
				rf_scrollXUnit += 256
				break
	if scrollYdelta > 0:
		scrollYtile += RF_SCREEN_HEIGHT_TILES
		for sb: int in range(rf_numVertScrollBlocks):
			if rf_vertScrollBlocks[sb] == scrollYtile:
				rf_scrollYUnit &= ~0xff
				break
	elif scrollYdelta < 0:
		for sb: int in range(rf_numVertScrollBlocks):
			if rf_vertScrollBlocks[sb] == scrollYtile:
				rf_scrollYUnit &= ~0xff
				rf_scrollYUnit += 256
				break


func RFL_CalcTics() -> void:
	var inctime: int
	if (SD_GetLastTimeCount() & 0xFFFFFFFF) > SD_GetTimeCount():
		SD_SetTimeCount(SD_GetLastTimeCount())
	if in_demoState != IN_Demo_Off:
		# recording or playing a demo: a fixed rf_demoTics a frame
		var new_time: int = SD_GetLastTimeCount() & 0xFFFFFFFF
		while new_time + rf_demoTics * 2 > SD_GetTimeCount():
			if quitting:
				return
			SD_WaitTick()
		SD_SetLastTimeCount(new_time + rf_demoTics)
		SD_SetTimeCount(new_time + rf_demoTics * 2)
		SD_SetSpriteSync(rf_demoTics)
		return
	while true:
		inctime = SD_GetTimeCount()
		SD_SetSpriteSync(((inctime & 0xFFFF) - (SD_GetLastTimeCount() & 0xFFFF)) & 0xFFFF)
		if SD_GetSpriteSync() >= rf_minTics or quitting:
			break
		SD_WaitTick()
	SD_SetLastTimeCount(inctime)
	# under 14 Hz the game slows down rather than drop more frames
	if SD_GetSpriteSync() > rf_maxTics:
		SD_SetTimeCount(SD_GetTimeCount() - (SD_GetSpriteSync() - rf_maxTics))
		SD_SetSpriteSync(rf_maxTics)


func RF_Reposition(scrollXunit: int, scrollYunit: int) -> void:
	cost("repos")    # TIME-G: the original's RF_NewPosition beside its tiles (origin, update arrays, anim list)
	RFL_RemoveAnimRect(RF_UnitToTile(rf_scrollXUnit), RF_UnitToTile(rf_scrollYUnit), RF_BUFFER_WIDTH_TILES, RF_BUFFER_HEIGHT_TILES)
	RF_RepositionLimit(scrollXunit, scrollYunit)
	var scrollXtile: int = RF_UnitToTile(rf_scrollXUnit)
	var scrollYtile: int = RF_UnitToTile(rf_scrollYUnit)
	RFL_SetupOnscreenAnimList()
	for ty: int in range(RF_BUFFER_HEIGHT_TILES):
		for tx: int in range(RF_BUFFER_WIDTH_TILES):
			RFL_CheckForAnimTile(tx + scrollXtile, ty + scrollYtile)
			RF_RenderTile16(tx, ty, CA_TileAtPos(tx + scrollXtile, ty + scrollYtile, 0))
			RF_RenderTile16m(tx, ty, CA_TileAtPos(tx + scrollXtile, ty + scrollYtile, 1))
			RFL_MarkBlockDirty(tx, ty, 1, -1)


func RF_SmoothScroll(scrollXdelta: int, scrollYdelta: int) -> void:
	var oldScrollXTile: int = RF_UnitToTile(rf_scrollXUnit)
	var oldScrollYTile: int = RF_UnitToTile(rf_scrollYUnit)
	RFL_SmoothScrollLimit(scrollXdelta, scrollYdelta)
	var scrollXTileDelta: int = RF_UnitToTile(rf_scrollXUnit) - oldScrollXTile
	var scrollYTileDelta: int = RF_UnitToTile(rf_scrollYUnit) - oldScrollYTile
	if scrollXTileDelta == 0 and scrollYTileDelta == 0:
		return
	if scrollXTileDelta > 1 or scrollXTileDelta < -1 or scrollYTileDelta > 1 or scrollYTileDelta < -1:
		RF_Reposition(rf_scrollXUnit, rf_scrollYUnit)
		return
	var dest_x: int = 16 if scrollXTileDelta < 0 else 0
	var dest_y: int = 16 if scrollYTileDelta < 0 else 0
	var src_x: int = 16 if scrollXTileDelta > 0 else 0
	var src_y: int = 16 if scrollYTileDelta > 0 else 0
	var wOffset: int = -16 if scrollXTileDelta != 0 else 0
	var hOffset: int = -16 if scrollYTileDelta != 0 else 0
	VL_SurfaceToSelf(rf_tileBuffer, dest_x, dest_y, src_x, src_y, RF_BUFFER_WIDTH_PIXELS + wOffset, RF_BUFFER_HEIGHT_PIXELS + hOffset)
	VL_ScrollScreen(scrollXTileDelta * 16, scrollYTileDelta * 16)
	rf_dirtyBufferOffset += scrollXTileDelta + scrollYTileDelta * RF_BUFFER_WIDTH_TILES
	if rf_dirtyBufferOffset < 0:
		rf_dirtyBufferOffset += RF_BUFFER_SIZE
	if scrollXTileDelta != 0:
		RFL_NewRowVert(scrollXTileDelta > 0)
		if scrollXTileDelta > 0:
			RFL_RemoveAnimCol(RF_UnitToTile(rf_scrollXUnit) - 1)
		else:
			RFL_RemoveAnimCol(RF_UnitToTile(rf_scrollXUnit) + RF_BUFFER_WIDTH_TILES)
	if scrollYTileDelta != 0:
		RFL_NewRowHorz(scrollYTileDelta > 0)
		if scrollYTileDelta > 0:
			RFL_RemoveAnimRow(RF_UnitToTile(rf_scrollYUnit) - 1)
		else:
			RFL_RemoveAnimRow(RF_UnitToTile(rf_scrollYUnit) + RF_BUFFER_HEIGHT_TILES)


func RF_PlaceEraser(pxX: int, pxY: int, pxW: int, pxH: int, page: int) -> void:
	var arrayBase: int = RF_MAX_SPRITETABLEENTRIES * page
	if rf_freeSpriteEraserIndex[page] == RF_MAX_SPRITETABLEENTRIES:
		Quit("Too many sprite erasers.")
		return
	var e: int = (rf_freeSpriteEraserIndex[page] + arrayBase) * 4
	rf_spriteErasers[e] = pxX
	rf_spriteErasers[e + 1] = pxY
	rf_spriteErasers[e + 2] = pxW
	rf_spriteErasers[e + 3] = pxH
	rf_freeSpriteEraserIndex[page] += 1


func RF_EraseRegion(pxX: int, pxY: int, pxW: int, pxH: int) -> void:
	for page: int in range(VL_GetNumBuffers()):
		RF_PlaceEraser(pxX, pxY, pxW, pxH, page)


func RF_GetLastPage(page: int) -> int:
	return (VL_GetActiveBuffer() - page + VL_GetNumBuffers()) % VL_GetNumBuffers()


## Returns the new value of the caller's entry pointer (always null).
func RF_RemoveSpriteDraw(drawEntry: RF_SpriteDrawEntry) -> RF_SpriteDrawEntry:
	if drawEntry == null:
		return null
	rf_numSpriteDraws -= 1
	if drawEntry.updateCount < VL_GetNumBuffers():
		if drawEntry.updateCount == 0:
			RF_PlaceEraser(drawEntry.x, drawEntry.y, drawEntry.sw, drawEntry.sh, RF_GetLastPage(0))
		RF_PlaceEraser(drawEntry.x, drawEntry.y, drawEntry.sw, drawEntry.sh, RF_GetLastPage(1))
	if drawEntry.next != null:
		drawEntry.next.prev_owner = drawEntry.prev_owner
	_set_prev_next(drawEntry.prev_owner, drawEntry.next)
	drawEntry.next = rf_freeSpriteTableEntry
	rf_freeSpriteTableEntry = drawEntry
	return null


func RFL_ProcessSpriteErasers() -> void:
	var page: int = VL_GetActiveBuffer()
	var arrayBase: int = RF_MAX_SPRITETABLEENTRIES * page
	for i: int in range(arrayBase, arrayBase + rf_freeSpriteEraserIndex[page]):
		var e: int = i * 4
		rf_spriteErasers[e] -= RF_UnitToTile(rf_scrollXUnit) * 16
		rf_spriteErasers[e + 1] -= RF_UnitToTile(rf_scrollYUnit) * 16
		if rf_spriteErasers[e] < 0:
			rf_spriteErasers[e + 2] += rf_spriteErasers[e]
			rf_spriteErasers[e] = 0
		if rf_spriteErasers[e + 1] < 0:
			rf_spriteErasers[e + 3] += rf_spriteErasers[e + 1]
			rf_spriteErasers[e + 1] = 0
		var x2: int = rf_spriteErasers[e] + rf_spriteErasers[e + 2]
		var y2: int = rf_spriteErasers[e + 1] + rf_spriteErasers[e + 3]
		if x2 > RF_BUFFER_WIDTH_PIXELS:
			rf_spriteErasers[e + 2] = RF_BUFFER_WIDTH_PIXELS - rf_spriteErasers[e]
		if y2 > RF_BUFFER_HEIGHT_PIXELS:
			rf_spriteErasers[e + 3] = RF_BUFFER_HEIGHT_PIXELS - rf_spriteErasers[e + 1]
		if rf_spriteErasers[e + 2] < 1 or rf_spriteErasers[e + 3] < 1:
			continue
		VL_SurfaceToScreen(rf_tileBuffer, rf_spriteErasers[e], rf_spriteErasers[e + 1],
			rf_spriteErasers[e], rf_spriteErasers[e + 1], rf_spriteErasers[e + 2], rf_spriteErasers[e + 3])
		# the tiles under the eraser are marked 2, so sprites over them redraw
		var tileX1: int = RF_PixelToTile(rf_spriteErasers[e])
		var tileY1: int = RF_PixelToTile(rf_spriteErasers[e + 1])
		var tileX2: int = RF_PixelToTile(rf_spriteErasers[e] + rf_spriteErasers[e + 2] - 1)
		var tileY2: int = RF_PixelToTile(rf_spriteErasers[e + 1] + rf_spriteErasers[e + 3] - 1)
		for ty: int in range(tileY1, tileY2 + 1):
			for tx: int in range(tileX1, tileX2 + 1):
				RFL_MarkBlockDirty(tx, ty, 2, page)
	rf_freeSpriteEraserIndex[page] = 0


## Returns the new value of the caller's entry pointer.
func RF_AddSpriteDraw(drawEntry: RF_SpriteDrawEntry, unitX: int, unitY: int, chunk: int, allWhite: bool, zLayer: int) -> RF_SpriteDrawEntry:
	var insertNeeded: bool = true
	if chunk == 0 or chunk == -1:
		return RF_RemoveSpriteDraw(drawEntry)
	var sde: RF_SpriteDrawEntry = drawEntry
	if sde != null:
		if sde.updateCount < VL_GetNumBuffers():
			if sde.updateCount == 0:
				RF_PlaceEraser(sde.x, sde.y, sde.sw, sde.sh, RF_GetLastPage(0))
			RF_PlaceEraser(sde.x, sde.y, sde.sw, sde.sh, RF_GetLastPage(1))
		if zLayer == sde.zLayer:
			insertNeeded = false
		else:
			if sde.next != null:
				sde.next.prev_owner = sde.prev_owner
			_set_prev_next(sde.prev_owner, sde.next)
	elif rf_freeSpriteTableEntry != null:
		sde = rf_freeSpriteTableEntry
		rf_freeSpriteTableEntry = rf_freeSpriteTableEntry.next
		rf_numSpriteDraws += 1
	else:
		Quit("RF_AddSpriteDraw: No free spots in spritearray")
		return drawEntry
	if insertNeeded:
		if rf_firstSpriteTableEntry[zLayer] != null:
			(rf_firstSpriteTableEntry[zLayer] as RF_SpriteDrawEntry).prev_owner = sde
		sde.next = rf_firstSpriteTableEntry[zLayer]
		rf_firstSpriteTableEntry[zLayer] = sde
		sde.prev_owner = zLayer
	var sprite_number: int = chunk - int(ca_gfxInfoE.offSprites)
	if CA_GetGrChunk(int(ca_gfxInfoE.offSprites), sprite_number, "Sprite", false) == null:
		Quit("RF_AddSpriteDraw: Placed an uncached sprite")
		return sde
	var shifted: VH_ShiftedSprite = VH_GetShiftedSprite(chunk)
	var ste: Dictionary = VH_GetSpriteTableEntry(sprite_number)
	var unshiftedX: int = RF_UnitToPixel(unitX + ste.originX)
	var shift: int = (unshiftedX & 7) / 2
	if vl_noPan:
		shift = 0
	sde.chunk = chunk
	sde.zLayer = zLayer
	sde.x = unshiftedX & ~7
	sde.y = RF_UnitToPixel(unitY + ste.originY)
	sde.sw = VH_GetShiftedSpriteWidth(shifted, shift)
	sde.sh = ste.height
	sde.maskOnly = allWhite
	sde.updateCount = VL_GetNumBuffers()
	sde.shift = shift
	return sde


## Saved games keep sprite entries as 16-bit offsets into the original's table.
func RF_ConvertSpriteArray16BitOffsetToPtr(drawEntryoffset: int) -> RF_SpriteDrawEntry:
	if drawEntryoffset == 0:
		return null
	return rf_spriteTable[(drawEntryoffset - CK_INT("ck_exe_spriteArrayOffset", 0x0000)) / 32]


func RF_ConvertSpriteArrayPtrTo16BitOffset(drawEntry: RF_SpriteDrawEntry) -> int:
	if drawEntry == null:
		return 0
	return (drawEntry.index * 32 + CK_INT("ck_exe_spriteArrayOffset", 0x0000)) & 0xFFFF


func RFL_DrawSpriteList() -> void:
	for zLayer: int in range(RF_NUM_SPRITE_Z_LAYERS):
		# every layer but the last is beneath the fore-foreground tiles
		if zLayer == 3:
			RFL_RenderForeTiles()
		var sde: RF_SpriteDrawEntry = rf_firstSpriteTableEntry[zLayer]
		while sde != null:
			var pixelX: int = sde.x - RF_UnitToTile(rf_scrollXUnit) * 16
			var pixelY: int = sde.y - RF_UnitToTile(rf_scrollYUnit) * 16
			var tileX1: int = CK_Cross_max(RF_PixelToTile(pixelX), 0)
			var tileY1: int = CK_Cross_max(RF_PixelToTile(pixelY), 0)
			var tileX2: int = CK_Cross_min(RF_PixelToTile(pixelX + sde.sw), RF_BUFFER_WIDTH_TILES - 1)
			var tileY2: int = CK_Cross_min(RF_PixelToTile(pixelY + sde.sh), RF_BUFFER_HEIGHT_TILES - 1)
			if tileX2 < tileX1 or tileY2 < tileY1:
				sde = sde.next
				continue
			if sde.updateCount == 0:
				var found: bool = false
				for y: int in range(tileY1, tileY2 + 1):
					for x: int in range(tileX1, tileX2 + 1):
						if RFL_IsBlockDirty(x, y, VL_GetActiveBuffer()) != 0:
							sde.updateCount = 1
							found = true
							break
					if found:
						break
			if sde.updateCount != 0:
				if sde.maskOnly:
					VH_DrawShiftedSpriteMask(pixelX, pixelY, sde.chunk, sde.shift, 15)
				else:
					VH_DrawShiftedSprite(pixelX, pixelY, sde.chunk, sde.shift)
				cost_n("sprpixel", sde.sw * sde.sh)    # TIME-G: the original's masked draw, row by row
				for y: int in range(tileY1, tileY2 + 1):
					for x: int in range(tileX1, tileX2 + 1):
						RFL_MarkBlockDirty(x, y, 3, VL_GetActiveBuffer())
				sde.updateCount -= 1
			sde = sde.next


func RFL_UpdateTiles() -> void:
	for y: int in range(RF_BUFFER_HEIGHT_TILES):
		for x: int in range(RF_BUFFER_WIDTH_TILES):
			if RFL_IsBlockDirty(x, y, -1) == 1:
				VL_SurfaceToScreen(rf_tileBuffer, x * 16, y * 16, x * 16, y * 16, 16, 16)
				cost("blockcopy")    # TIME-G


func RF_Refresh() -> void:
	RFL_AnimateTiles()
	RFL_UpdateTiles()
	RFL_ProcessSpriteErasers()
	RFL_DrawSpriteList()
	# no block is dirty on this page once the frame is drawn
	for y: int in range(RF_BUFFER_HEIGHT_TILES):
		for x: int in range(RF_BUFFER_WIDTH_TILES):
			RFL_MarkBlockDirty(x, y, 0, VL_GetActiveBuffer())
	if rf_drawFunc != &"":
		call(rf_drawFunc)
	# 0xef in X matches EGA Keen's 2-pixel horizontal scrolling
	VL_SetScrollCoords(RF_UnitToPixel(rf_scrollXUnit & 0xef), RF_UnitToPixel(rf_scrollYUnit & 0xff))
	VL_SwapOnNextPresent()
	VL_Present()
	RFL_CalcTics()
