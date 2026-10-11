# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's ck5_misc.c, ck5_map.c and ck5_obj1-3.c, by David Gow and the Omnispeak authors,
# GPL v2 or later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalKeen5
extends GalMenu
## Keen 5's episode code (SIM-G-01h).
##
## Every store wraps as its C type does (u16 for the uint16_t position and
## clip-rect fields, s16 for the int16_t ones, ck_nextX/ck_nextY included).
## Arguments C passes to an int16_t parameter (CA_TileAtPos's x and y) are
## wrapped with s16 where the value is computed. C's Quit() never returns;
## here it only flags the quit, so each Quit is followed by a return.
## C's RF_SpriteDrawEntry ** arguments follow GalRF's rule (the new pointer is
## returned: `obj.sde = RF_AddSpriteDraw(obj.sde, ...)`); the int16_t * user
## field offsets follow GalCK's (`obj.user4 = RF_AddSpriteDrawUsing16BitOffset(obj.user4, ...)`).
## ck5_episode is declared in gal_ck.gd.





## The DOS memory Keen 5 v1.4's manager gets under DOSBox with 632K free (keen5_mem01_a): its
## near heap holds the 4K misc buffer, which Keen 4's cannot (see GalLib.mm_layout).
func mm_layout() -> Dictionary:
	return {"near": [0x3ff8, 0x177], "far": [0x41d8, 0x5e26], "high": [0xd001, 0x1fff],
		"introscn": [0x2270, 0xfa], "tile8": 108, "tile8m": 36}


# ===================================================================== ck5_misc.c

# Contains some keen-5 specific functions.

## Check if all the game files are present. (C asks the file system for each
## of the episode's files; here GalData has loaded them, and this checks it
## loaded a Keen 5 data set.)
func CK5_IsPresent() -> bool:
	return data != null and data.ext == "CK5"


func CK5_PurpleAxisPlatform(obj: CK_object) -> void:
	var nextPosUnit: int # uint16_t
	var nextPosTile: int # uint16_t

	if ck_nextX != 0 or ck_nextY != 0:
		return
	# TODO: Implement properly.
	ck_nextX = s16(obj.xDirection * 12 * SD_GetSpriteSync())
	ck_nextY = s16(obj.yDirection * 12 * SD_GetSpriteSync())

	if obj.xDirection == 1:
		nextPosUnit = u16(obj.clipRects.unitX2 + ck_nextX)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileX2 != nextPosTile and CA_TileAtPos(s16(nextPosTile), obj.clipRects.tileY1, 2) == 0x1F:
			obj.xDirection = -1
			# TODO: Change DeltaVelocity
			ck_nextX = s16(ck_nextX - (nextPosUnit & 255))
	elif obj.xDirection == -1:
		nextPosUnit = u16(obj.clipRects.unitX1 + ck_nextX)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileX1 != nextPosTile and CA_TileAtPos(s16(nextPosTile), obj.clipRects.tileY1, 2) == 0x1F:
			obj.xDirection = 1
			# TODO: Change DeltaVelocity
			# CK_PhysUpdateX(obj, 256 - nextPosUnit&255);
			ck_nextX = s16(ck_nextX + ((256 - nextPosUnit) & 255))
	elif obj.yDirection == 1:
		nextPosUnit = u16(obj.clipRects.unitY2 + ck_nextY)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileY2 != nextPosTile and CA_TileAtPos(s16(obj.clipRects.tileX1 + 1), s16(nextPosTile), 2) == 0x1F:
			if CA_TileAtPos(obj.clipRects.tileX1, s16(nextPosTile - 2), 2) == 0x1F:
				# Stop the platform.
				obj.visible = true
				ck_nextY = 0
			else:
				obj.yDirection = -1
				# TODO: Change DeltaVelocity
				ck_nextY = s16(ck_nextY - (nextPosUnit & 255))
	elif obj.yDirection == -1:
		nextPosUnit = u16(obj.clipRects.unitY1 + ck_nextY)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileY1 != nextPosTile and CA_TileAtPos(s16(obj.clipRects.tileX1 + 1), s16(nextPosTile), 2) == 0x1F:
			if CA_TileAtPos(obj.clipRects.tileX1, s16(nextPosTile + 2), 2) == 0x1F:
				# Stop the platform.
				obj.visible = true
				ck_nextY = 0
			else:
				obj.yDirection = 1
				# TODO: Change DeltaVelocity
				ck_nextY = s16(ck_nextY + 256 - (nextPosUnit & 255))


# MISC Keen 5 functions

# Teleporter Lightning Spawn

func CK5_SpawnLightning() -> void:
	var new_object: CK_object

	# Spawn the top lightning
	new_object = CK_GetNewObj(true)
	new_object.zLayer = 3
	new_object.clipped = CLIP_not
	new_object.type = 24
	new_object.posX = u16(RF_TileToUnit(ck_keenObj.clipRects.tileX1) - 0x80)
	new_object.posY = u16(RF_TileToUnit(ck_keenObj.clipRects.tileY2) - 0x500)
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_LightningH0"))

	# Spawn the vertical lightning that covers keen
	new_object = CK_GetNewObj(true)
	new_object.zLayer = 3
	new_object.clipped = CLIP_not
	new_object.type = 24
	new_object.posX = u16(RF_TileToUnit(ck_keenObj.clipRects.tileX1))
	new_object.posY = u16(RF_TileToUnit(ck_keenObj.clipRects.tileY1) - 0x80)
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_LightningV0"))

	SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN41"))


# Fuse Explosion Spawn

func CK5_SpawnFuseExplosion(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(true)
	new_object.zLayer = 3
	new_object.clipped = CLIP_not
	new_object.type = 24
	new_object.posX = u16(RF_TileToUnit(tileX - 1))
	new_object.posY = u16(RF_TileToUnit(tileY))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_FuseExplosion0"))
	SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN52"))


# Level Ending Object Spawn

func CK5_SpawnLevelEnd() -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.active = OBJ_ALWAYS_ACTIVE
	new_object.clipped = CLIP_not
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_LevelEnd"))


# LevelEnd Behaviour
# If in the QED, end the game
# Otherwise, do the Korath Fuse message

func CK5_LevelEnd(_obj: CK_object) -> void:
	ck_gameState.levelState = LS_DestroyedQED if ca_mapOn == 12 else LS_KorathFuse


func CK5_SetupFunctions() -> void:
	# Quick hack as we haven't got a deadly function yet
	CK5_Obj1_SetupFunctions()
	CK5_Obj2_SetupFunctions()
	CK5_Obj3_SetupFunctions()
	CK5_Map_SetupFunctions()
	CK_ACT_AddFunction("CK5_PurpleAxisPlatform", &"CK5_PurpleAxisPlatform")
	CK_ACT_AddFunction("CK5_LevelEnd", &"CK5_LevelEnd")


## Spawn an enemy projectile
## Note that the behaviour is slightly different from DOS Keen
## DOS Keen SpawnEnemyShot returns 0 if shot is spawned, or -1 otherwise
## omnispeak CK5_SpawnEnemyShot returns pointer if succesful, NULL otherwise
func CK5_SpawnEnemyShot(posX: int, posY: int, action: CK_action) -> CK_object:
	var new_object: CK_object = CK_GetNewObj(true)

	if new_object == null:
		return null

	new_object.posX = u16(posX)
	new_object.posY = u16(posY)
	new_object.type = CT5_EnemyShot
	new_object.active = OBJ_EXISTS_ONLY_ONSCREEN
	CK_SetAction(new_object, action)

	if CK_NotStuckInWall(new_object):
		return new_object
	else:
		CK_RemoveObj(new_object)
		return null


func CK5_OpenMapTeleporter(tileX: int, tileY: int) -> void:
	var tile_array: PackedInt32Array = PackedInt32Array() # uint16_t[4]
	tile_array.resize(4)
	for y: int in range(2):
		for x: int in range(2):
			tile_array[y * 2 + x] = CA_TileAtPos(5 * 2 + x, y, 1)
	RF_ReplaceTiles(tile_array, 0, 1, tileX, tileY, 2, 2)


func CK5_CloseMapTeleporter(tileX: int, tileY: int) -> void:
	var tile_array: PackedInt32Array = PackedInt32Array() # uint16_t[4]
	tile_array.resize(4)
	for y: int in range(2):
		for x: int in range(2):
			tile_array[y * 2 + x] = CA_TileAtPos(x, y, 1)
	RF_ReplaceTiles(tile_array, 0, 1, tileX, tileY, 2, 2)


## CK5_ScanInfoLayer's switch falls through from the hard to the normal to the
## easy case of a creature: `case hardVal: if (difficulty < D_Hard) break;
## case normalVal: if (difficulty < D_Normal) break; case easyVal: spawn`.
## True when the spawn is reached. (A helper: GDScript's match has no fall-through.)
func _ck5_DifficultyFallThrough(infoValue: int, normalVal: int, hardVal: int) -> bool:
	if infoValue == hardVal and ck_gameState.difficulty < D_Hard:
		return false
	if (infoValue == hardVal or infoValue == normalVal) and ck_gameState.difficulty < D_Normal:
		return false
	return true


func CK5_ScanInfoLayer() -> void:
	CA_InitLumps(CK_INT("NUMLUMPS", 0))

	# TODO: Work out where to store current map number, etc.
	var mapW: int = CA_GetMapWidth()
	var mapH: int = CA_GetMapHeight()

	ck_gameState.ck5_fusesRemaining = 0

	for y: int in range(mapH):
		for x: int in range(mapW):
			var infoValue: int = CA_TileAtPos(x, y, 2)
			match infoValue:
				1:
					CK_SpawnKeen(x, y, 1)
					CK_DemoSignSpawn()
					CA_MarkGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"))
					CA_MARKLUMP("LUMP_KEEN")
				2:
					CK_SpawnKeen(x, y, -1)
					CK_DemoSignSpawn()
					CA_MarkGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"))
					CA_MARKLUMP("LUMP_KEEN")

				3:
					CK_DemoSignSpawn()
					CA_MarkGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"))
					CA_MARKLUMP("LUMP_MAPKEEN")
					if ck_gameState.levelState != LS_TeleportToKorath:
						CK_SpawnMapKeen(x, y)

				6, 5, 4:
					if _ck5_DifficultyFallThrough(infoValue, 5, 6):
						CK5_SpawnSparky(x, y)
						CA_MARKLUMP("LUMP_SPARKY")

				9, 8, 7:
					if _ck5_DifficultyFallThrough(infoValue, 8, 9):
						CK5_SpawnMine(x, y)
						CA_MARKLUMP("LUMP_MINE")

				12, 11, 10:
					if _ck5_DifficultyFallThrough(infoValue, 11, 12):
						CK5_SpawnSlice(x, y, CD_north)
						CA_MARKLUMP("LUMP_SLICESTAR")

				15, 14, 13:
					if _ck5_DifficultyFallThrough(infoValue, 14, 15):
						CK5_SpawnRobo(x, y)
						CA_MARKLUMP("LUMP_ROBORED")

				18, 17, 16:
					if _ck5_DifficultyFallThrough(infoValue, 17, 18):
						CK5_SpawnSpirogrip(x, y)
						CA_MARKLUMP("LUMP_SPIROGRIP")

				21, 20, 19:
					if _ck5_DifficultyFallThrough(infoValue, 20, 21):
						CK5_SpawnSliceDiag(x, y)
						CA_MARKLUMP("LUMP_SLICESTAR")

				24, 23, 22:
					if _ck5_DifficultyFallThrough(infoValue, 23, 24):
						CK5_SpawnSlice(x, y, CD_east)
						CA_MARKLUMP("LUMP_SLICESTAR")

				25:
					RF_SetScrollBlock(x, y, true)
				26:
					# RF_SetScrollBlock(x, y, false);
					if ck_gameState.levelState == LS_TeleportToKorath:
						CK5_MapKeenTeleSpawn(x, y)
				27, 28, 29, 30:
					CK_SpawnAxisPlatform(x, y, infoValue - 27, false)
					CA_MARKLUMP("LUMP_PLATFORM")
				32:
					CK_SpawnFallPlat(x, y)
					CA_MARKLUMP("LUMP_PLATFORM")

				33, 34, 35:
					# case 33: if (difficulty > D_Easy) break;
					# case 34: if (difficulty > D_Normal) break;
					# case 35: spawn
					var spawn: bool = true
					if infoValue == 33 and ck_gameState.difficulty > D_Easy:
						spawn = false
					elif (infoValue == 33 or infoValue == 34) and ck_gameState.difficulty > D_Normal:
						spawn = false
					if spawn:
						CK_SpawnStandPlatform(x, y)
						CA_MARKLUMP("LUMP_PLATFORM")

				36, 37, 38, 39:
					CK_SpawnGoPlat(x, y, infoValue - 36, false)
					CA_MARKLUMP("LUMP_PLATFORM")
				40:
					CK_SneakPlatSpawn(x, y)
					CA_MARKLUMP("LUMP_PLATFORM")
				41:
					if ck_gameState.currentLevel == 12:
						ck_gameState.ck5_fusesRemaining = 4
						CK5_QEDSpawn(x, y)
					else:
						ck_gameState.ck5_fusesRemaining = s16(ck_gameState.ck5_fusesRemaining + 1)
					CA_MARKLUMP("LUMP_FUSE")
					# ck5_lumpsNeeded[Lump_QEDFuse] = true;
				44, 43, 42:
					if _ck5_DifficultyFallThrough(infoValue, 43, 44):
						CK5_SpawnAmpton(x, y)
						CA_MARKLUMP("LUMP_AMPTON")

				53, 49, 45:
					if _ck5_DifficultyFallThrough(infoValue, 49, 53):
						CK_TurretSpawn(x, y, 0)
						CA_MARKLUMP("LUMP_LASER")

				54, 50, 46:
					if _ck5_DifficultyFallThrough(infoValue, 50, 54):
						CK_TurretSpawn(x, y, 1)
						CA_MARKLUMP("LUMP_LASER")

				55, 51, 47:
					if _ck5_DifficultyFallThrough(infoValue, 51, 55):
						CK_TurretSpawn(x, y, 2)
						CA_MARKLUMP("LUMP_LASER")

				56, 52, 48:
					if _ck5_DifficultyFallThrough(infoValue, 52, 56):
						CK_TurretSpawn(x, y, 3)
						CA_MARKLUMP("LUMP_LASER")

				69, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68:
					var spawnItem: bool = true
					if infoValue == 69:
						# Spawn extra stunner if Keen has low ammo
						if ck_gameState.numShots >= 5:
							spawnItem = false
						else:
							infoValue = 68
					if spawnItem:
						CK_SpawnItem(x, y, infoValue - 57)
						CA_MarkLumpNeeded(CK_INTELEMENT("ck_itemLumps", infoValue - 57))
				70:
					CK_SpawnItem(x, y, infoValue - 58) # Omegamatic Keycard
					CA_MARKLUMP("LUMP_KEYCARD")

				73, 72, 71:
					if _ck5_DifficultyFallThrough(infoValue, 72, 73):
						CK5_SpawnVolte(x, y)
						CA_MARKLUMP("LUMP_VOLTEFACE")

				76, 75, 74:
					if _ck5_DifficultyFallThrough(infoValue, 75, 76):
						CK5_SpawnShelly(x, y)
						CA_MARKLUMP("LUMP_SHELLEY")

				79, 78, 77:
					if _ck5_DifficultyFallThrough(infoValue, 78, 79):
						CK5_SpawnSpindred(x, y)
						CA_MARKLUMP("LUMP_SPINDRED")

				80, 81, 82, 83:
					CK_SpawnGoPlat(x, y, infoValue - 80, true)
					CA_MARKLUMP("LUMP_PURPLEPLAT")
				84, 85, 86, 87:
					CK_SpawnAxisPlatform(x, y, infoValue - 84, true)
					CA_MARKLUMP("LUMP_PURPLEPLAT")

				90, 89, 88:
					if _ck5_DifficultyFallThrough(infoValue, 89, 90):
						CK5_SpawnMaster(x, y)
						CA_MARKLUMP("LUMP_MASTER")

				101, 100, 99:
					if _ck5_DifficultyFallThrough(infoValue, 100, 101):
						CK5_SpawnShikadi(x, y)
						CA_MARKLUMP("LUMP_SHIKADI")

				104, 103, 102:
					if _ck5_DifficultyFallThrough(infoValue, 103, 104):
						CK5_SpawnShocksund(x, y)
						CA_MARKLUMP("LUMP_SHOCKSHUND")

				107, 106, 105:
					if _ck5_DifficultyFallThrough(infoValue, 106, 107):
						CK5_SpawnSphereful(x, y)
						CA_MARKLUMP("LUMP_SPHEREFUL")

				124:
					CK5_SpawnKorath(x, y)
					CA_MARKLUMP("LUMP_KORATH")
				125:
					# TODO: Signal about teleportation (caching)
					CA_MARKLUMP("LUMP_TELEPORT")

	var obj: CK_object = ck_keenObj
	while obj != null:
		if obj.active != OBJ_ALWAYS_ACTIVE:
			obj.active = OBJ_INACTIVE
		obj = obj.next
	# TODO: Some more stuff (including opening elevator after breaking fuses)

	# Mark all of the chunks for needed lumps.
	CA_MarkAllLumps(CK_VAR_GetIntArray("lumpStarts"), CK_VAR_GetIntArray("lumpEnds"))

	if ck_gameState.currentLevel == 0:
		var keenYTilePos: int = ck_keenObj.posY >> 8

		# The top of the lower shaft is opened if you're above its entrance or
		# on Korath III.
		if keenYTilePos < 75 or keenYTilePos > 100:
			CK5_CloseMapTeleporter(24, 76)
			CK5_OpenMapTeleporter(22, 55)

		# Unlock the entrance to the upper shaft if we're below the top and the
		# fuses are broken.
		if ck_gameState.levelsDone[4] != 0 and ck_gameState.levelsDone[6] != 0 and ck_gameState.levelsDone[8] != 0 and ck_gameState.levelsDone[10] != 0 and keenYTilePos > 39:
			CK5_OpenMapTeleporter(26, 55)

		# Unlock the top elevator when we're at the top or on Korath III.
		if keenYTilePos < 39 or keenYTilePos > 100:
			CK5_OpenMapTeleporter(24, 30)


# Galaxy Explosion Ending Sequence
const endsplosion_pal_change: Array = [
	[0x8, 0x8, 0x7, 0xF, 0x7, 0x8, 0x0, 0x8, 0x7, 0xF, 0x7, 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0],
	[0x7, 0x7, 0x7, 0x7, 0x7, 0xF, 0x7, 0x8, 0x0, 0x7, 0xF, 0x7, 0x8, 0x0, 0x0, 0x0, 0x0, 0x0],
]

## uint8_t[17] (a global C writes into)
var endsplosion_palette: PackedByteArray = PackedByteArray([0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x3])

# There can be 4000 stars in the galaxy ending
# Each star is defined by an initial position and velocity vector
# Each pixel is 0x80 units square, upper left of screen is (0,0)
# When galaxy explodes, star is updated by its velocity component
#  on every tick, until it exceeds screen boundaries.
#
# typedef struct CK5_GalExplode { uint16_t x[4000]; int16_t dx[4000];
# uint16_t y[4000]; int16_t dy[4000]; } CK5_GalExplode;
# Here the struct is read and written in place in EXTERN_GALAXY's cached
# chunk bytes (little-endian, as on the PC): x at byte 0, dx at 8000, y at
# 16000, dy at 24000, two bytes per star.


func CK_GalExplodePageFlip(_offset: int) -> void:
	VL_Present()


func CK_GalExplodeUpdateCoords(_offset: int) -> void:
	# NOTE: Normally, the offset would be set to allow for page flipping
	# But we don't need to worry about that in omnispeak

	# Blank the video buffer
	VH_Bar(0, 0, 320, 200, 0)

	var chunk: int = CK_CHUNKNUM("EXTERN_GALAXY")
	var info: PackedByteArray = CA_GetGrChunk(chunk, 0, "GalExplodeInfo", true)

	# Update the star positions
	# Each pixel is 0x80 x 0x80 "distance units"
	var i: int = 3999
	while i >= 0:
		var newPos: int # uint16_t

		newPos = u16(info.decode_u16(i * 2) + info.decode_s16(8000 + i * 2))
		if newPos > 320 * 0x80:
			i -= 1
			continue
		info.encode_u16(i * 2, newPos)

		newPos = u16(info.decode_u16(16000 + i * 2) + info.decode_s16(24000 + i * 2))
		if newPos > 200 * 0x80:
			i -= 1
			continue
		info.encode_u16(16000 + i * 2, newPos)

		VH_Plot(info.decode_u16(i * 2) / 0x80, info.decode_u16(16000 + i * 2) / 0x80, 0xF)
		i -= 1

	# (C writes through the chunk's pointer: the cache keeps the updated stars)
	ca_graphChunks[chunk] = info


## C's busy-wait `while (SD_GetTimeCount() - SD_GetLastTimeCount() < 4) ;`
## (uint32_t arithmetic), running the machine to its next tick while it waits.
func _ck5_GalExplodeDelay() -> void:
	while ((SD_GetTimeCount() - SD_GetLastTimeCount()) & 0xFFFFFFFF) < 4:
		if quitting:
			return
		SD_WaitTick()


func CK5_ExplodeGalaxy() -> void:
	# purge_chunks()
	VL_SetScrollCoords(0, 0)

	VL_FadeToBlack()
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_MILKYWAY")) # Galaxy Pic
	CA_CacheGrChunk(CK_CHUNKNUM("EXTERN_GALAXY")) # Star Coords
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_GAMEOVER")) # Game Over Pic

	# VW_SetLineWidth(40);
	# VH_SetScreen(0);
	# VW_ClearVideo(0);
	VL_ClearScreen(0)

	# Draw the galaxy
	VH_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_MILKYWAY"))
	VL_FadeFromBlack()
	IN_ClearKeysDown()
	SD_PlaySound(CK_SOUNDNUM("SOUND_GALAXYEXPLODEPRE"))

	# (C's `goto done` is this flag)
	var done: bool = false

	# Galaxy is about to explode
	for i: int in range(18):
		IN_PumpEvents()

		endsplosion_palette[8] = endsplosion_pal_change[0][i]
		# (SCR-01: the second row, as Keen 5's own code has it, KEEN5E.EXE 0F00:0701; omnispeak gives both
		# colours the first row, keen5 scr_over)
		endsplosion_palette[7] = endsplosion_pal_change[1][i]
		VL_SetPaletteAndBorderColor(endsplosion_palette)
		# VW_WaitVBL(10);
		VL_DelayTics(10)

		if IN_GetLastScan() != 0:
			done = true
			break

		VL_Present()

	if not done:
		# Write Mode 2();
		# Set Plane Write Mask;

		SD_PlaySound(CK_SOUNDNUM("SOUND_GALAXYEXPLODE"))
		VL_ClearScreen(0)

		for i: int in range(30):
			IN_PumpEvents()

			SD_SetLastTimeCount(SD_GetTimeCount())

			CK_GalExplodeUpdateCoords(2000)
			CK_GalExplodePageFlip(2000)

			# Delay
			_ck5_GalExplodeDelay()

			SD_SetLastTimeCount(SD_GetTimeCount())

			CK_GalExplodeUpdateCoords(0)
			CK_GalExplodePageFlip(0)

			# Delay
			_ck5_GalExplodeDelay()

			if IN_GetLastScan() != 0:
				break

	# done:
	# Set Video back to normal
	VL_ClearScreen(0)
	# VW_SetLineWidth(0);
	VL_SetDefaultPalette()

	# RF_Reset();

	StartMusic(18)

	VH_DrawBitmap(32, 80, CK_CHUNKNUM("PIC_GAMEOVER"))
	VL_Present()

	IN_UserInput(24 * 70, false)

	StopMusic()


# Fuse Explosion Message

# (extern uint8_t ca_levelbit; extern uint8_t ca_graphChunkNeeded[]: GalLib's)

func CK5_FuseMessage() -> void:
	SD_WaitSoundDone()

	# Cache the Keen thumbs up pic
	CA_UpLevel()
	ca_graphChunkNeeded[CK_CHUNKNUM("PIC_KEENTALK1")] |= ca_levelbit
	ca_graphChunkNeeded[CK_CHUNKNUM("PIC_KEENTALK2")] |= ca_levelbit
	CA_CacheMarks("") # C: CA_CacheMarks(0)

	VL_FixRefreshBuffer()

	# Draw Keen Talking
	US_CenterWindow(0x1A, 8)
	US_SetWindowW(US_GetWindowW() - 0x30)
	VHB_DrawBitmap(US_GetWindowW() + US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetPrintY(US_GetPrintY() + 0xC)

	if ck_gameState.currentLevel == 0xD:
		US_CPrint(CK_STRING("ck5_str_fuseDestroyedKorath"))
	else:
		US_CPrint(CK_STRING("ck5_str_fuseDestroyed"))

	VH_UpdateScreen()
	VL_DelayTics(30)

	IN_ClearKeysDown()
	IN_WaitButton()

	# Draw the Keen Thumbs Up Pic
	VHB_DrawBitmap(US_GetWindowW() + US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK2"))
	VH_UpdateScreen()
	VL_DelayTics(30)
	IN_ClearKeysDown()
	IN_WaitButton()
	CA_DownLevel()
	StopMusic()


# ===================================================================== ck5_map.c

# =========================================================================

# Thisis called from playloop

func CK5_MapMiscFlagsCheck(keen: CK_object) -> void:
	var midTileX: int
	var midTileY: int

	if keen.user3 != 0:
		return

	midTileX = keen.clipRects.tileXmid
	midTileY = ((keen.clipRects.unitY2 - keen.clipRects.unitY1) / 2 + keen.clipRects.unitY1) >> 8

	match TI_ForeMisc(CA_TileAtPos(midTileX, midTileY, 1)):
		MISCFLAG_TELEPORT:
			CK_AnimateMapTeleporter(midTileX, midTileY)

		MISCFLAG_LEFTELEVATOR:
			CK5_AnimateMapElevator(midTileX, midTileY, 0)

		MISCFLAG_RIGHTELEVATOR:
			CK5_AnimateMapElevator(midTileX, midTileY, -1)


func CK5_MapKeenTeleSpawn(tileX: int, tileY: int) -> void:
	ck_keenObj.type = 2
	ck_keenObj.posX = u16(RF_TileToUnit(tileX))
	ck_keenObj.posY = u16(RF_TileToUnit(tileY))
	ck_keenObj.active = OBJ_ALWAYS_ACTIVE
	ck_keenObj.zLayer = 1
	ck_keenObj.yDirection = IN_motion_None
	ck_keenObj.xDirection = IN_motion_None
	ck_keenObj.user1 = 6
	ck_keenObj.user2 = 3
	ck_keenObj.user3 = 0
	ck_keenObj.gfxChunk = 244
	CK_SetAction(ck_keenObj, CK_GetActionByName("CK_ACT_MapKeenStart"))


# this is a move proc.. closes doors on keen
# (the #if 0 MapKeenElevator draft is dropped)

func CK5_MapKeenElevator(keen: CK_object) -> void:
	var tileX: int
	var tileY: int

	# Move keen in the Y direction
	ck_nextY = s16(keen.yDirection * 64 * SD_GetSpriteSync())

	if keen.posX != keen.user2:
		ck_nextX = s16(keen.xDirection * 12 * SD_GetSpriteSync())
		if (keen.xDirection == IN_motion_Right and ck_nextX + keen.posX > keen.user2) or (keen.xDirection == IN_motion_Left and ck_nextX + keen.posX < keen.user2):
			ck_nextX = s16(keen.user2 - keen.posX)

	# 1D776
	# Update hitbox
	keen.clipRects.unitX1 = u16(keen.posX + ck_nextX)
	keen.clipRects.unitX2 = u16(keen.clipRects.unitX1 + 0xFF)

	keen.clipRects.unitY1 = u16(keen.posY + ck_nextY)
	keen.clipRects.unitY2 = u16(keen.clipRects.unitY1 + 0xFF)

	# If keen has not yet hit the Y destination, keep moving
	if keen.yDirection == IN_motion_Down:
		if u16(keen.posY + ck_nextY) < u16(keen.user1):
			return
	else:
		if u16(keen.posY + ck_nextY) > u16(keen.user1):
			return

	# 1D7C5
	# Arrived at destination; turn travelling keen back into normal map keen
	ck_nextY = 0
	ck_nextX = 0
	keen.posX = u16(keen.user2)
	keen.posY = u16(keen.user1)
	keen.zLayer = 1
	keen.user1 = 4 # Keen faces south
	keen.user2 = 3
	keen.user3 = 0
	ck_keenObj.yDirection = IN_motion_None
	ck_keenObj.xDirection = IN_motion_None
	keen.currentAction = CK_GetActionByName("CK_ACT_MapKeenStart")
	keen.gfxChunk = 0xFD
	keen.clipped = CLIP_normal
	tileX = keen.posX >> 8
	tileY = keen.posY >> 8
	CK_MapCamera(keen)
	# Draw the scorebox
	CK_UpdateScoreBox(ck_scoreBoxObj)

	RF_Refresh()
	RF_Refresh()

	keen.posY = u16(keen.posY - 0x100)
	keen.sde = RF_AddSpriteDraw(keen.sde, keen.posX, keen.posY, keen.gfxChunk, false, keen.zLayer)
	SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN63"))

	# Animate the elevator operation
	var tile_array: PackedInt32Array = PackedInt32Array() # uint16_t[4]
	tile_array.resize(4)
	for frame: int in range(6):
		for y: int in range(2):
			for x: int in range(2):
				tile_array[y * 2 + x] = CA_TileAtPos(frame * 2 + x, y, 1)
		RF_ReplaceTiles(tile_array, 0, 1, tileX, tileY - 2, 2, 2)
		RF_Refresh()
		VL_DelayTics(8) # Simulate 8 calls to VL_WaitVBL();

	# Draw keen walking out of elevator
	for frame: int in range(32):
		keen.posY = u16(keen.posY + 8)
		keen.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_WALK1_S") + (frame / 4) % 3)
		keen.sde = RF_AddSpriteDraw(keen.sde, keen.posX, keen.posY, keen.gfxChunk, false, keen.zLayer)
		RF_Refresh()

	keen.clipped = CLIP_normal


## Keen enters an elevator
func CK5_AnimateMapElevator(tileX: int, tileY: int, dir: int) -> void:
	var unitX: int
	var unitY: int
	var timer: int
	var ticsx2: int

	unitX = RF_TileToUnit(tileX)
	unitY = RF_TileToUnit(tileY)

	timer = 0
	while timer < 130:
		# (port only: the loop's time comes from RF_Refresh's clock, which stops
		# advancing once the engine quits; leave rather than spin)
		if quitting:
			return
		# NOTE: this function in omnispeak will calculate the new tile clipRects
		# Here, Vanilla keen calls a function which does not calculate new clipRects
		# But this is the only time that function is ever called,
		# so we can just call CK_ResetClipRects in this spot

		CK_ResetClipRects(ck_keenObj)
		CK_MapCamera(ck_keenObj)

		# Draw the scorebox
		CK_UpdateScoreBox(ck_scoreBoxObj)

		# Draw screen and delay 1/35th of a second
		RF_Refresh()

		ticsx2 = SD_GetSpriteSync() * 2
		timer += SD_GetSpriteSync()

		# If keen arrives at the target, then he's done walking
		if ck_keenObj.posX == unitX and ck_keenObj.posY == unitY:
			break

		# Move Keen closer to the target on every loop
		if ck_keenObj.posY < unitY:
			ck_keenObj.posY = u16(ck_keenObj.posY + ticsx2)
			if ck_keenObj.posY > unitY:
				ck_keenObj.posY = u16(unitY)
		elif ck_keenObj.posY > unitY:
			ck_keenObj.posY = u16(ck_keenObj.posY - ticsx2)
			if ck_keenObj.posY < unitY:
				ck_keenObj.posY = u16(unitY)

		if ck_keenObj.posX < unitX:
			ck_keenObj.posX = u16(ck_keenObj.posX + ticsx2)
			if ck_keenObj.posX > unitX:
				ck_keenObj.posX = u16(unitX)
		elif ck_keenObj.posX > unitX:
			ck_keenObj.posX = u16(ck_keenObj.posX - ticsx2)
			if ck_keenObj.posX < unitX:
				ck_keenObj.posX = u16(unitX)

		# Draw Keen walking into target
		# TODO: Is that done by the original code?
		ck_keenObj.gfxChunk = u16(((SD_GetTimeCount() >> 3) % 3) + CK_CHUNKNUM("SPR_MAPKEEN_WALK1_N"))
		ck_keenObj.sde = RF_AddSpriteDraw(ck_keenObj.sde, ck_keenObj.posX, ck_keenObj.posY, ck_keenObj.gfxChunk, false, ck_keenObj.zLayer)

	SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN63"))

	# Draw the elevator operation
	var tile_array: PackedInt32Array = PackedInt32Array() # uint16_t[4]
	tile_array.resize(4)
	var frame: int = 5
	while frame >= 0:
		for y: int in range(2):
			for x: int in range(2):
				tile_array[y * 2 + x] = CA_TileAtPos(frame * 2 + x, y, 1)
		RF_ReplaceTiles(tile_array, 0, 1, tileX + dir, tileY - 1, 2, 2)
		RF_Refresh()
		VL_DelayTics(8) # Simulate 8 calls to VL_WaitVBL();
		frame -= 1

	# Keen is now behind the elevator door, so don't draw him
	ck_keenObj.sde = RF_RemoveSpriteDraw(ck_keenObj.sde)

	# Get the destination stored in the info plane
	# and store X in map units in user1; Y in user 2
	var dest_tile: int = CA_TileAtPos(tileX, tileY, 2)
	ck_keenObj.user2 = s16(dest_tile / 256 * 256)
	ck_keenObj.user1 = s16(RF_TileToUnit((dest_tile & 0x007F) + 1))

	# Move keen based on the relative location of the target
	if u16(ck_keenObj.user1) < u16(ck_keenObj.posY):
		ck_keenObj.yDirection = IN_motion_Up
	else:
		ck_keenObj.yDirection = IN_motion_Down

	if u16(ck_keenObj.user2) < u16(ck_keenObj.posX):
		ck_keenObj.xDirection = IN_motion_Left
	else:
		ck_keenObj.xDirection = IN_motion_Right

	# Keen is going to become invisible and "fly" to the destination
	ck_keenObj.clipped = CLIP_not
	ck_keenObj.currentAction = CK_GetActionByName("CK5_ACT_MapKeenElevator")

	# Note: This should have been added
	# ck_keenObj->user3 = 1;


## Setup all of the functions in this file.
func CK5_Map_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK5_MapKeenElevator", &"CK5_MapKeenElevator")
	CK_ACT_AddFunction("CK5_MapMiscFlagsCheck", &"CK5_MapMiscFlagsCheck")


# ===================================================================== ck5_obj1.c

# (extern int ck_infoplaneArrowsX[], ck_infoplaneArrowsY[]: declared in gal_ck.gd)

## (C indexes the 8-entry arrow tables with user1, which the check below lets
## reach 8: C then reads past the array; here that index is an error.)
func CK5_PurpleGoPlatThink(obj: CK_object) -> void:
	if ck_nextX != 0 or ck_nextY != 0:
		return

	var delta: int = s16(SD_GetSpriteSync() * 12) # int16_t

	# Will we reach a new tile?
	if obj.user2 > delta:
		# No... keep moving in the same direction.
		obj.user2 = s16(obj.user2 - delta)

		var dirX: int = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + delta)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - delta)

		var dirY: int = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + delta)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - delta)
	else:
		# Move to next tile.
		var dirX: int = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + obj.user2)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - obj.user2)

		var dirY: int = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + obj.user2)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - obj.user2)

		var tileX: int = RF_UnitToTile(obj.posX + ck_nextX + 0x40)
		var tileY: int = RF_UnitToTile(obj.posY + ck_nextY + 0x40)

		obj.user1 = s16(CA_TileAtPos(s16(tileX), s16(tileY), 2) - 0x5B)

		if (obj.user1 < 0) or (obj.user1 > 8):
			Quit("Goplat moved to a bad spot.")
			return

		delta = s16(delta - obj.user2)
		obj.user2 = s16(256 - delta)

		# Move in the new direction.
		dirX = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + delta)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - delta)

		dirY = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + delta)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - delta)


func CK5_SpawnVolte(tileX: int, tileY: int) -> void:
	var dir: int

	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Volte
	new_object.active = OBJ_ALWAYS_ACTIVE
	new_object.zLayer = 2
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY))
	new_object.clipped = CLIP_not
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Volte0"))

	# Initialize Volte Direction
	# (Vanilla keen does this with far pointer arithmetic)
	if CA_TileAtPos(tileX - 1, tileY, 2) == 0x5C:
		dir = 1
	elif CA_TileAtPos(tileX + 1, tileY, 2) == 0x5E:
		dir = 3
	elif CA_TileAtPos(tileX, tileY - 1, 2) == 0x5D:
		dir = 2
	elif CA_TileAtPos(tileX, tileY + 1, 2) == 0x5B:
		dir = 0
	else:
		Quit("Volte spawned at bad spot!") # Not present in vanilla keen
		return

	CA_SetTileAtPos(tileX, tileY, 2, dir + 0x5B)
	new_object.user1 = s16(dir)
	new_object.user2 = 0x100


## This is very similar to the GoPlat function
## The only difference is the increased speed and the error message
## (As CK5_PurpleGoPlatThink, user1 reaching 8 indexes past the arrow tables.)
func CK5_VolteMove(obj: CK_object) -> void:
	if ck_nextX != 0 or ck_nextY != 0:
		return

	var delta: int = s16(SD_GetSpriteSync() * CK_INT("CK5_VolteSpeed", 32)) # int16_t

	# Will we reach a new tile?
	if obj.user2 > delta:
		# No... keep moving in the same direction.
		obj.user2 = s16(obj.user2 - delta)

		var dirX: int = ck_infoplaneArrowsX[obj.user1] # int16_t
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + delta)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - delta)

		var dirY: int = ck_infoplaneArrowsY[obj.user1] # int16_t
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + delta)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - delta)
	else:
		# Move to next tile.
		var dirX: int = ck_infoplaneArrowsX[obj.user1] # int16_t
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + obj.user2)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - obj.user2)

		var dirY: int = ck_infoplaneArrowsY[obj.user1] # int16_t
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + obj.user2)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - obj.user2)

		var tileX: int = s16(RF_UnitToTile(obj.posX + ck_nextX)) # int16_t
		var tileY: int = s16(RF_UnitToTile(obj.posY + ck_nextY)) # int16_t

		obj.user1 = s16(CA_TileAtPos(tileX, tileY, 2) - 0x5B)

		if (obj.user1 < 0) or (obj.user1 > 8):
			# TODO: Add printf style variable arg list to Quit()
			# and add the offending tile here
			Quit("Volte moved to a bad spot")
			return

		delta = s16(delta - obj.user2)
		obj.user2 = s16(256 - delta)

		# Move in the new direction.
		dirX = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + delta)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - delta)

		dirY = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + delta)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - delta)


func CK5_VolteCol(volte: CK_object, other: CK_object) -> void:
	if other.type == CT_Player:
		CK_KillKeen()
	elif other.type == CT_Stunner:
		# stunner
		CK_ShotHit(other)
		CK_SetAction2(volte, CK_GetActionByName("CK5_ACT_VolteStunned"))


## Setup all of the functions in this file.
func CK5_Obj1_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK5_PurpleGoPlatThink", &"CK5_PurpleGoPlatThink")

	# VolteFace
	CK_ACT_AddFunction("CK5_VolteMove", &"CK5_VolteMove")
	CK_ACT_AddColFunction("CK5_VolteCol", &"CK5_VolteCol")


# ===================================================================== ck5_obj2.c

func CK5_SpawnSparky(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Sparky
	new_object.active = OBJ_ACTIVE
	new_object.zLayer = 0
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_SparkySpawnYOffset", -0x100))
	new_object.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	new_object.yDirection = IN_motion_Down
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Sparky0"))


func CK5_SparkyWait(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK5_SparkySearchChance", 0x40):
		obj.currentAction = CK_GetActionByName("CK5_ACT_SparkySearch0")
		ck_nextX = 0


func CK5_SparkyPrepareCharge(obj: CK_object) -> void:
	obj.user1 = s16(obj.user1 - 1)
	if obj.user1 == 0:
		obj.currentAction = CK_GetActionByName("CK5_ACT_SparkyCharge0")


func CK5_SparkySearchLeft(obj: CK_object) -> void:
	var delY: int = u16(ck_keenObj.clipRects.unitY2 + 0x100 - obj.clipRects.unitY2) # uint16_t

	if delY < CK_INT("CK5_SparkySearchYRadius", 0x200) and ck_keenObj.posX < obj.posX:
		obj.xDirection = IN_motion_Left
		SD_PlaySound(CK_SOUNDNUM("SOUND_SPARKYPREPCHARGE"))
		obj.currentAction = CK_GetActionByName("CK5_ACT_SparkyPrepCharge0")
		obj.user1 = s16(CK_INT("CK5_SparkyPrepChargeDelay", 3)) # should this counter be multiplied by spritesync?


func CK5_SparkySearchRight(obj: CK_object) -> void:
	var delY: int = u16(ck_keenObj.clipRects.unitY2 + 0x100 - obj.clipRects.unitY2) # uint16_t

	if delY < CK_INT("CK5_SparkySearchYRadius", 0x200) and ck_keenObj.posX > obj.posX:
		obj.xDirection = IN_motion_Right
		SD_PlaySound(CK_SOUNDNUM("SOUND_SPARKYPREPCHARGE"))
		obj.currentAction = CK_GetActionByName("CK5_ACT_SparkyPrepCharge0")
		obj.user1 = s16(CK_INT("CK5_SparkyPrepChargeDelay", 3)) # should this counter be multiplied by spritesync?


func CK5_SparkyCharge0(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK0"))


func CK5_SparkyCharge1(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK0"))


func CK5_SparkyCol(obj1: CK_object, obj2: CK_object) -> void:
	if obj2.type == CT_Player:
		CK_KillKeen()
	elif obj2.type == CT_Stunner:
		CK_StunCreature(obj1, obj2, CK_GetActionByName("CK5_ACT_SparkyStunned0"))


func CK5_SparkyTileCol(obj: CK_object) -> void:
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_SparkyTurn0"))
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_SparkyTurn0"))
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = s16(-obj.xDirection)
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_SparkyTurn0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnAmpton(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Ampton
	new_object.active = OBJ_ACTIVE
	new_object.zLayer = 0
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_AmptonSpawnYOffset", -0x80))
	new_object.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	new_object.yDirection = IN_motion_Down
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Ampton0"))


func CK5_AmptonWalk(obj: CK_object) -> void:
	# play tic toc sound
	if obj.currentAction == CK_GetActionByName("CK5_ACT_Ampton0"):
		SD_PlaySound(CK_SOUNDNUM("SOUND_AMPTONWALK0"))
	elif obj.currentAction == CK_GetActionByName("CK5_ACT_Ampton2"):
		SD_PlaySound(CK_SOUNDNUM("SOUND_AMPTONWALK1"))

	# if on tile boundary (i.e. sliding or computer) then skip
	# the check for a pole or a computer
	if (obj.posX & 0xFF) != 0:
		var tileX: int = obj.clipRects.tileX1 + 1
		var tileY: int = obj.clipRects.tileY1
		var miscflags: int = TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY), 1)) & 0x7F
		if miscflags == MISCFLAG_COMPUTER:
			obj.currentAction = CK_GetActionByName("CK5_ACT_AmptonComp0")
			return

		# Check for a pole
		if miscflags == MISCFLAG_POLE:
			# Don't always climb the pole
			if US_RndT() < CK_INT("CK5_AmptonClimbPoleChance", 0xC4):
				var polebelow: bool = ((TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY + 2), 1)) & 0x7F) == MISCFLAG_POLE)
				var poleabove: bool = ((TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY - 2), 1)) & 0x7F) == MISCFLAG_POLE)

				# Pick direction if there is a choice
				if poleabove and polebelow:
					if US_RndT() < 0x80:
						poleabove = false
					else:
						polebelow = false

				# climb up
				if poleabove:
					obj.yDirection = IN_motion_Up
					obj.currentAction = CK_GetActionByName("CK5_ACT_AmptonPole0")
					obj.clipped = CLIP_not
					obj.timeUntillThink = 6
					ck_nextX = 0
					return

				# slide down
				if polebelow:
					obj.yDirection = IN_motion_Down
					obj.currentAction = CK_GetActionByName("CK5_ACT_AmptonPole0")
					obj.clipped = CLIP_not
					obj.timeUntillThink = 6
					ck_nextX = 0
					return


func CK5_AmptonPoleClimb(obj: CK_object) -> void:
	var newYT: int

	# Check if ampton is moving into new tile
	newYT = RF_UnitToTile(obj.clipRects.unitY2 + ck_nextY)

	if obj.clipRects.tileY2 == newYT:
		return

	if obj.yDirection == IN_motion_Up:
		# Going Up
		# Check if coming up through a pole hole
		var tileX: int = obj.clipRects.tileX1 + 1
		var tileY: int = newYT

		if TI_ForeTop(CA_TileAtPos(s16(tileX), s16(tileY), 1)) == 0 and TI_ForeTop(CA_TileAtPos(s16(tileX), s16(tileY + 1), 1)) != 0:
			# Dismount if there are fewer than 4 pole tiles above the hole
			# or randomly, if there are more than 4
			if ((TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY - CK_INT("CK5_AmptonPoleMinHeight", 4)), 1)) & 0x7F) != MISCFLAG_POLE) or US_RndT() >= CK_INT("CK5_AmptonPoleDismountChance", 0x80):
				# Set the ampton on the ground
				var delY: int = (obj.clipRects.unitY2 & 0xFF) + 1
				obj.posY = u16(obj.posY - delY)
				obj.clipRects.unitY2 = u16(obj.clipRects.unitY2 - delY)
				obj.clipped = CLIP_normal
				obj.currentAction = CK_GetActionByName("CK5_ACT_AmptonDismount0")
				ck_nextY = 0x10
				obj.yDirection = IN_motion_Down
				CK_PhysUpdateNormalObj(obj)
				obj.timeUntillThink = 4
				return
		elif (TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY - 1), 1)) & 0x7F) != MISCFLAG_POLE:
			# Hit the top of a pole; go back down
			ck_nextY = 0
			obj.yDirection = IN_motion_Down
			return
	else:
		# Ampton is sliding down a pole
		var tileX: int = obj.clipRects.tileX1 + 1
		var tileY: int = newYT

		if TI_ForeTop(CA_TileAtPos(s16(tileX), s16(tileY), 1)) != 0 and TI_ForeTop(CA_TileAtPos(s16(tileX), s16(tileY - 1), 1)) == 0:
			# Dismount if not landing on pole hole
			# If pole hole, randomly dismount
			if (TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY), 1)) & 0x7F) != MISCFLAG_POLE or US_RndT() >= CK_INT("CK5_AmptonPoleDismountChance", 0x80):
				# Set ampton on the ground
				var delY: int = 0xFF - (obj.clipRects.unitY2 & 0xFF)
				obj.posY = u16(obj.posY + delY)
				# (omnispeak's quirk, kept: unitX2, not unitY2)
				obj.clipRects.unitX2 = u16(obj.clipRects.unitX2 + delY)
				obj.clipped = CLIP_normal
				obj.currentAction = CK_GetActionByName("CK5_ACT_AmptonDismount0")
				ck_nextY = 0x10
				CK_PhysUpdateNormalObj(obj)
				obj.timeUntillThink = 4
				return
		elif (TI_ForeMisc(CA_TileAtPos(s16(tileX), s16(tileY), 1)) & 0x7F) != MISCFLAG_POLE:
			ck_nextY = 0
			obj.yDirection = IN_motion_Up
			return


func CK5_AmptonSwitch(obj: CK_object) -> void:
	obj.timeUntillThink = 4


func CK5_AmptonCol(obj1: CK_object, obj2: CK_object) -> void:
	if obj2.type == CT_Player:
		if obj1.currentAction == CK_GetActionByName("CK5_ACT_AmptonPole2"):
			CK_KillKeen()
		else:
			CK_PhysPushX(obj2, obj1)
	elif obj2.type == CT_Stunner:
		obj1.clipped = CLIP_normal
		obj1.yDirection = IN_motion_Down
		obj1.velY = 0
		SD_PlaySound(CK_SOUNDNUM("SOUND_AMPTONSTUN"))
		CK_StunCreature(obj1, obj2, CK_GetActionByName("CK5_ACT_AmptonStunned0"))


## (The three checks are separate ifs in C, not an else-if chain: kept.)
func CK5_AmptonTileCol(obj: CK_object) -> void:
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_AmptonTurn0"))

	if obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_AmptonTurn0"))

	if obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = s16(-obj.xDirection)
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_AmptonTurn0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnSlice(tileX: int, tileY: int, dir: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)

	new_object.type = CT5_SliceStar
	new_object.active = OBJ_ACTIVE
	new_object.zLayer = 2
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY))
	new_object.user4 = s16(CK_INT("CK5_SliceHealth", 20))

	match dir:
		0:
			new_object.xDirection = IN_motion_None
			new_object.yDirection = IN_motion_Up
		1:
			new_object.xDirection = IN_motion_Right
			new_object.yDirection = IN_motion_None
		2:
			new_object.xDirection = IN_motion_None
			new_object.yDirection = IN_motion_Down
		3:
			new_object.xDirection = IN_motion_Left
			new_object.yDirection = IN_motion_None

	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Slice0"))
	return


## (Cases 0 and 3 are the same direction in C: kept.)
func CK5_SpawnSliceDiag(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_SliceStar
	new_object.active = OBJ_ACTIVE
	new_object.zLayer = 2
	new_object.clipped = CLIP_simple
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY))
	new_object.user4 = s16(CK_INT("CK5_SliceDiagHealth", 50)) # strength

	match US_RndT() / 0x40:
		0:
			new_object.xDirection = IN_motion_Left
			new_object.yDirection = IN_motion_Up
		1:
			new_object.xDirection = IN_motion_Right
			new_object.yDirection = IN_motion_Down
		2:
			new_object.xDirection = IN_motion_Left
			new_object.yDirection = IN_motion_Down
		3:
			new_object.xDirection = IN_motion_Left
			new_object.yDirection = IN_motion_Up

	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_SliceDiag0"))


func CK5_SliceCol(obj1: CK_object, obj2: CK_object) -> void:
	if obj2.type == CT_Player:
		CK_KillKeen()
		return

	if obj2.type == CT_Stunner:
		CK_ShotHit(obj2)
		obj1.user4 = s16(obj1.user4 - 1)
		if obj1.user4 == 0:
			CK_SetAction(obj1, CK_GetActionByName("CK5_ACT_SliceDie0"))


func CK5_SliceDiagTileCol(obj: CK_object) -> void:
	if obj.topTI != 0:
		obj.yDirection = IN_motion_Up
		SD_PlaySound(CK_SOUNDNUM("SOUND_SLICEBUMP"))
	elif obj.bottomTI != 0:
		obj.yDirection = IN_motion_Down
		SD_PlaySound(CK_SOUNDNUM("SOUND_SLICEBUMP"))

	if obj.leftTI != 0:
		obj.xDirection = IN_motion_Left
		SD_PlaySound(CK_SOUNDNUM("SOUND_SLICEBUMP"))
	elif obj.rightTI != 0:
		obj.xDirection = IN_motion_Right
		SD_PlaySound(CK_SOUNDNUM("SOUND_SLICEBUMP"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnShelly(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Sparky # Apparently, the same type as a sparky
	new_object.active = OBJ_ACTIVE
	new_object.zLayer = 0
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY))
	new_object.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	new_object.yDirection = IN_motion_Down
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Shelly0"))


func CK5_ShellyWait(obj: CK_object) -> void:
	if ck_keenObj.clipRects.unitY1 >= obj.clipRects.unitY2:
		# Jump off of ledge if Keen is a ledge below
		var xDel: int = ck_keenObj.clipRects.unitXmid - obj.clipRects.unitXmid
		if obj.xDirection == IN_motion_Right:
			if xDel > CK_INT("CK5_ShelleyDiveMinX", 0x100) and xDel < CK_INT("CK5_ShelleyDiveMaxX", 0x300):
				obj.velX = s16(CK_INT("CK5_ShelleyDiveXVel", 0x10))
				obj.velY = s16(CK_INT("CK5_ShelleyDiveYVel", -0x18))
				obj.currentAction = CK_GetActionByName("CK5_ACT_ShellyDive0")
				ck_nextX = 0
				ck_nextY = 0
		else:
			if xDel < -CK_INT("CK5_ShelleyDiveMinX", 0x100) and xDel > -CK_INT("CK5_ShelleyDiveMaxX", 0x300):
				obj.velX = s16(-CK_INT("CK5_ShelleyDiveXVel", 0x10))
				obj.velY = s16(CK_INT("CK5_ShelleyDiveYVel", -0x18))
				obj.currentAction = CK_GetActionByName("CK5_ACT_ShellyDive0")
				ck_nextX = 0
				ck_nextY = 0


func CK5_ShellyStartJump(obj: CK_object) -> void:
	obj.xDirection = s16(-obj.xDirection)


func CK5_SpawnShellyBits(obj: CK_object) -> void:
	var new_object: CK_object
	new_object = CK_GetNewObj(true)
	if new_object != null:
		new_object.posX = obj.posX
		new_object.posY = obj.posY
		new_object.velX = s16(CK_INT("CK5_ShelleyBits0XVel", 0x20))
		new_object.velY = s16(CK_INT("CK5_ShelleyBits0YVel", -0x18))
		CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_ShellyBits0"))

	new_object = CK_GetNewObj(true)
	if new_object != null:
		new_object.posX = obj.posX
		new_object.posY = obj.posY
		new_object.velX = s16(CK_INT("CK5_ShelleyBits1XVel", -0x20))
		new_object.velY = s16(CK_INT("CK5_ShelleyBits1YVel", -0x18))
		CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_ShellyBits1"))


func CK5_ShellyCol(obj1: CK_object, obj2: CK_object) -> void:
	var new_object: CK_object

	# Player, Stunners, and Enemy shots destroy shelly
	if obj2.type == CT_Player:
		CK_PhysPushX(obj2, obj1)
		# don't detonate if not inside shelley
		if ck_keenObj.clipRects.unitXmid < obj1.clipRects.unitX1 or ck_keenObj.clipRects.unitXmid > obj1.clipRects.unitX2:
			return
	elif obj2.type == CT_Stunner:
		CK_ShotHit(obj2)
	elif obj2.type == CT5_EnemyShot:
		CK_RemoveObj(obj2)
	else:
		return

	# destroy old shelly and spawn explosion
	SD_PlaySound(CK_SOUNDNUM("SOUND_SHELLYEXPLODE"))
	if obj1.topTI == 0:
		CK_SetAction2(obj1, CK_GetActionByName("CK5_ACT_ShellyDieAir"))
	else:
		CK_SetAction2(obj1, CK_GetActionByName("CK5_ACT_ShellyDieGround"))

	new_object = CK_GetNewObj(true)
	if new_object != null:
		new_object.posX = obj1.posX
		new_object.posY = obj1.posY
		CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_ShellyExplode0"))


func CK5_ShellyGroundTileCol(obj: CK_object) -> void:
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_ShellyWait0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)
	return


func CK5_ShellyAirTileCol(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0

	if obj.topTI != 0:
		var new_object: CK_object
		SD_PlaySound(CK_SOUNDNUM("SOUND_SHELLYEXPLODE"))
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_ShellyDieAir"))
		new_object = CK_GetNewObj(true)
		if new_object != null:
			new_object.posX = obj.posX
			new_object.posY = obj.posY
			CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_ShellyExplode0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_Obj2_SetupFunctions() -> void:
	# Sparky
	CK_ACT_AddFunction("CK5_SparkyWait", &"CK5_SparkyWait")
	CK_ACT_AddFunction("CK5_SparkyPrepareCharge", &"CK5_SparkyPrepareCharge")
	CK_ACT_AddFunction("CK5_SparkySearchLeft", &"CK5_SparkySearchLeft")
	CK_ACT_AddFunction("CK5_SparkySearchRight", &"CK5_SparkySearchRight")
	CK_ACT_AddFunction("CK5_SparkyCharge0", &"CK5_SparkyCharge0")
	CK_ACT_AddFunction("CK5_SparkyCharge1", &"CK5_SparkyCharge1")
	CK_ACT_AddColFunction("CK5_SparkyCol", &"CK5_SparkyCol")
	CK_ACT_AddFunction("CK5_SparkyTileCol", &"CK5_SparkyTileCol")

	CK_ACT_AddFunction("CK5_AmptonWalk", &"CK5_AmptonWalk")
	CK_ACT_AddFunction("CK5_AmptonPoleClimb", &"CK5_AmptonPoleClimb")
	CK_ACT_AddFunction("CK5_AmptonSwitch", &"CK5_AmptonSwitch")
	CK_ACT_AddColFunction("CK5_AmptonCol", &"CK5_AmptonCol")
	CK_ACT_AddFunction("CK5_AmptonTileCol", &"CK5_AmptonTileCol")

	CK_ACT_AddColFunction("CK5_SliceCol", &"CK5_SliceCol")
	CK_ACT_AddFunction("CK5_SliceDiagTileCol", &"CK5_SliceDiagTileCol")

	CK_ACT_AddFunction("CK5_ShellyWait", &"CK5_ShellyWait")
	CK_ACT_AddFunction("CK5_ShellyStartJump", &"CK5_ShellyStartJump")
	CK_ACT_AddFunction("CK5_SpawnShellyBits", &"CK5_SpawnShellyBits")
	CK_ACT_AddColFunction("CK5_ShellyCol", &"CK5_ShellyCol")
	CK_ACT_AddFunction("CK5_ShellyGroundTileCol", &"CK5_ShellyGroundTileCol")
	CK_ACT_AddFunction("CK5_ShellyAirTileCol", &"CK5_ShellyAirTileCol")


# ===================================================================== ck5_obj3.c

# (extern int ck_ticsThisFrame: unused here)

# Shikadi Mine Funcs

func CK5_SpawnMine(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT5_Mine
	obj.active = OBJ_ACTIVE
	obj.clipped = CLIP_not
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_MineSpawnYOffset", -0x1F1))

	# X and Y offsets of the Dot relative to the mine
	obj.user2 = s16(CK_INT("CK5_MineDotXOffset", 0x100))
	obj.user3 = s16(CK_INT("CK5_MineDotYOffset", 0xD0))
	CK_SetAction(obj, CK_GetActionByName("CK5_ACT_Mine2"))
	obj.velX = 0x100

	for i: int in range(4):
		if CK5_Walk(obj, i) != 0:
			break
	return


## Check a 3 x 2 square originating from (tileX, tileY)
## If blocked, then return false
func CK5_MinePathClear(tileX: int, tileY: int) -> int:
	var t: int
	var x: int
	var y: int

	y = 0
	while y < CK_INT("CK5_MinePathTileHeight", 2):
		x = 0
		while x < CK_INT("CK5_MinePathTileWidth", 3):
			t = CA_TileAtPos(s16(tileX + x), s16(tileY + y), 1)
			if TI_ForeTop(t) != 0 or TI_ForeBottom(t) != 0 or TI_ForeLeft(t) != 0 or TI_ForeRight(t) != 0:
				return 0 # path is blocked
			x += 1
		y += 1
	return 1 # didn't hit anything


## (C falls off the end after Quit, an undefined return; here 0.)
func CK5_Walk(obj: CK_object, dir: int) -> int:
	var tx: int
	var ty: int

	tx = RF_UnitToTile(obj.posX + ck_nextX)
	ty = RF_UnitToTile(obj.posY + ck_nextY)

	match dir:
		CD_north: # up
			if CK5_MinePathClear(tx, ty - 1) != 0:
				obj.xDirection = IN_motion_None
				obj.yDirection = IN_motion_Up
				return 1
			else:
				return 0

		CD_east: # right
			if CK5_MinePathClear(tx + 1, ty) != 0:
				obj.xDirection = IN_motion_Right
				obj.yDirection = IN_motion_None
				return 1
			else:
				return 0
		CD_south: # down
			if CK5_MinePathClear(tx, ty + 1) != 0:
				obj.xDirection = IN_motion_None
				obj.yDirection = IN_motion_Down
				return 1
			else:
				return 0
		CD_west: # left
			if CK5_MinePathClear(tx - 1, ty) != 0:
				obj.xDirection = IN_motion_Left
				obj.yDirection = IN_motion_None
				return 1
			else:
				return 0
	Quit("CK5_Walk: Bad Dir")
	return 0


## Pick direction to chase keen
func CK5_SeekKeen(obj: CK_object) -> void:
	# What is the point of the ordinal directions?
	# The mine only ever moves in cardinal directions.
	# Perhaps it was supposed to move in all eight?

	# EDIT: principalDir is lated passed as a CK_Controldir anyway
	var mine_dirs: PackedInt32Array = PackedInt32Array([Dir_north, Dir_northwest, Dir_east, Dir_northeast,
		Dir_south, Dir_southeast, Dir_west, Dir_southwest, Dir_nodir])
	# CK_Dir mine_dirs[9] ={CD_south, CD_west, CD_north, CD_east, 6, 7, 4, 5, 8};

	var deltaX: int
	var deltaY: int
	# These values should store CK_Controldir values (0 to 3), but 8
	# is stored in the axes (same as Dir_nodir from the CK_Dir enum).
	# Maybe there were different plans at some point.
	var closestAxis: int
	var farthestAxis: int
	var cardinalDir: int
	var principalDir: int

	# Convert x and y motions into current controldirection
	if obj.xDirection == IN_motion_Right:
		cardinalDir = CD_east
	elif obj.xDirection == IN_motion_Left:
		cardinalDir = CD_west
	elif obj.yDirection == IN_motion_Up:
		cardinalDir = CD_north
	elif obj.yDirection == IN_motion_Down:
		cardinalDir = CD_south
	else:
		Quit("CK5_SeekKeen: Bad Mine Direction")
		return

	# Should this not be cardinalDir * 2?
	# (omnispeak's quirk, kept: a CK_Dir used as a CK_Controldir)
	principalDir = mine_dirs[cardinalDir]

	# Determine which component (x or y) has the greatest absolute difference from keen
	# We want to move in that direction first?

	# Get position difference between Keen and Mine
	deltaX = ck_keenObj.posX - (obj.posX + ck_nextX)
	deltaY = ck_keenObj.posY - (obj.posY + ck_nextY)
	closestAxis = Dir_nodir
	farthestAxis = Dir_nodir

	if deltaX > 0:
		farthestAxis = CD_east
	if deltaX < 0:
		farthestAxis = CD_west
	if deltaY > 0:
		closestAxis = CD_south
	if deltaY < 0:
		closestAxis = CD_north

	# CK_Cross_abs(x): ((x) > 0 ? (x) : (-(x)))
	if (deltaY if deltaY > 0 else -deltaY) > (deltaX if deltaX > 0 else -deltaX):
		var s: int = farthestAxis
		farthestAxis = closestAxis
		closestAxis = s

	# If one of the intended components is already the mine's movement
	# Then there's no need to check twice
	if farthestAxis == principalDir:
		farthestAxis = Dir_nodir
	if closestAxis == principalDir:
		closestAxis = Dir_nodir

	# Check if there's free space ahead first in the desired directions
	# and then finally in the current direction
	if closestAxis != Dir_nodir and CK5_Walk(obj, closestAxis) != 0:
		return
	if farthestAxis != Dir_nodir and CK5_Walk(obj, farthestAxis) != 0:
		return
	if CK5_Walk(obj, cardinalDir) != 0:
		return

	# Otherwise, look for some free space
	if US_RndT() > 0x80:
		for i: int in range(0, 4):
			if i != principalDir:
				if CK5_Walk(obj, i) != 0:
					return
	else:
		for i: int in range(3, -1, -1):
			if i != principalDir:
				if CK5_Walk(obj, i) != 0:
					return

	# Finally, just keep going forward
	CK5_Walk(obj, principalDir)
	return


func CK5_MineMove(obj: CK_object) -> void:
	var deltaX: int # int16_t
	var deltaY: int # int16_t
	var delta: int # int16_t
	var xDir: int # int16_t
	var yDir: int # int16_t

	# Get distance to keen
	deltaX = s16(obj.posX - ck_keenObj.posX)
	deltaY = s16(obj.posY - ck_keenObj.posY)

	# Check if Mine should explode
	if deltaX < CK_INT("CK5_MineExplodeMaxX", 0x200) and deltaX > CK_INT("CK5_MineExplodeMinX", -0x500) and deltaY < CK_INT("CK5_MineExplodeMaxY", 0x300) and deltaY > CK_INT("CK5_MineExplodeMinY", -0x50):
		SD_PlaySound(CK_SOUNDNUM("SOUND_MINEEXPLODE"))
		obj.currentAction = CK_GetActionByName("CK5_ACT_MineExplode0")
		obj.user4 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user4)
		return

	# Move the mine to the next tile boundary
	# obj->velX is used as a ticker
	# When the ticker reaches zero, check if directional change needed
	delta = s16(SD_GetSpriteSync() * CK_INT("CK5_MineMoveDist", 10))
	if obj.velX <= delta:
		# Move up to the tile boundary
		ck_nextX = s16(obj.xDirection * obj.velX)
		ck_nextY = s16(obj.yDirection * obj.velX)
		delta = s16(delta - obj.velX)
		xDir = obj.xDirection
		yDir = obj.yDirection

		# Switch to the changing direction action if necessary
		CK5_SeekKeen(obj)
		obj.velX = 0x100
		if obj.xDirection != xDir or obj.yDirection != yDir:
			obj.currentAction = CK_GetActionByName("CK5_ACT_Mine1")
			return

	# Tick down velX and move mine
	obj.velX = s16(obj.velX - delta)
	ck_nextX = s16(ck_nextX + delta * obj.xDirection)
	ck_nextY = s16(ck_nextY + delta * obj.yDirection)
	return


func CK5_MineCol(_o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
	return


func CK5_MineShrapCol(_o1: CK_object, o2: CK_object) -> void:
	# Explode stunner
	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
		return

	# Kill keen
	if o2.type == CT_Player:
		CK_KillKeen()
		return

	# blow up QED
	if o2.type == CT5_QED:
		CK5_SpawnFuseExplosion(o2.clipRects.tileX1, o2.clipRects.tileY1)
		CK5_SpawnFuseExplosion(o2.clipRects.tileX2, o2.clipRects.tileY1)
		CK5_SpawnFuseExplosion(o2.clipRects.tileX1, o2.clipRects.tileY2)
		CK5_SpawnFuseExplosion(o2.clipRects.tileX2, o2.clipRects.tileY2)
		RF_ReplaceTileBlock(0, 0, 0x10, 0xB, 4, 2)
		RF_ReplaceTileBlock(4, 0, 0x10, 0xD, 4, 2)
		CK5_SpawnLevelEnd()
		CK_RemoveObj(o2)

	return


## (If an action's next is NULL the second step reads through NULL: C crashes,
## here it is a script error. Kept.)
func CK5_MineMoveDotsToCenter(obj: CK_object) -> void:
	var deltaX: int # int16_t
	var deltaY: int # int16_t
	var dotOffsetX: int # int16_t
	var dotOffsetY: int # int16_t

	deltaX = s16(obj.posX - ck_keenObj.posX)
	deltaY = s16(obj.posY - ck_keenObj.posY)

	# Blow up if keen is nearby
	if deltaX < CK_INT("CK5_MineExplode2MaxX", 0x200) and deltaX > CK_INT("CK5_MineExplode2MinX", -0x300) and deltaY < CK_INT("CK5_MineExplode2MaxY", 0x300) and deltaY > CK_INT("CK5_MineExplode2MinY", -0x300):
		SD_PlaySound(CK_SOUNDNUM("SOUND_MINEEXPLODE"))
		obj.currentAction = CK_GetActionByName("CK5_ACT_MineExplode0")
		obj.user4 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user4)
		return

	obj.visible = true
	dotOffsetX = s16(CK_INT("CK5_MineDotXOffset", 0x100))
	dotOffsetY = s16(CK_INT("CK5_MineDotYOffset", 0xD0))

	# Move Dot to the center, then change Action
	if obj.user2 < dotOffsetX:
		obj.user2 = s16(obj.user2 + SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user2 >= dotOffsetX:
			obj.user2 = dotOffsetX
			obj.currentAction = obj.currentAction.next
	elif obj.user2 > dotOffsetX:
		obj.user2 = s16(obj.user2 - SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user2 <= dotOffsetX:
			obj.user2 = dotOffsetX
			obj.currentAction = obj.currentAction.next

	# Do the same in the Y direction
	if obj.user3 < dotOffsetY:
		obj.user3 = s16(obj.user3 + SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user3 >= dotOffsetY:
			obj.user3 = dotOffsetY
			obj.currentAction = obj.currentAction.next
	elif obj.user3 > dotOffsetY:
		obj.user3 = s16(obj.user3 - SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user3 <= dotOffsetY:
			obj.user3 = dotOffsetY
			obj.currentAction = obj.currentAction.next

	return


func CK5_MineMoveDotsToSides(obj: CK_object) -> void:
	var deltaX: int # int16_t
	var deltaY: int # int16_t
	var dotOffsetX: int = 0 # int16_t
	var dotOffsetY: int = 0 # int16_t

	deltaX = s16(obj.posX - ck_keenObj.posX)
	deltaY = s16(obj.posY - ck_keenObj.posY)

	# Explode if Keen is nearby
	if deltaX < CK_INT("CK5_MineExplode2MaxX", 0x200) and deltaX > CK_INT("CK5_MineExplode2MinX", -0x300) and deltaY < CK_INT("CK5_MineExplode2MaxY", 0x300) and deltaY > CK_INT("CK5_MineExplode2MinY", -0x300):
		SD_PlaySound(CK_SOUNDNUM("SOUND_MINEEXPLODE"))
		obj.currentAction = CK_GetActionByName("CK5_ACT_MineExplode0")
		obj.user4 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user4)
		return

	obj.visible = true

	match obj.xDirection:
		IN_motion_Left:
			dotOffsetX = s16(CK_INT("CK5_MineDotLeftXOffset", 0x80))
		IN_motion_None:
			dotOffsetX = s16(CK_INT("CK5_MineDotXOffset", 0x100))
		IN_motion_Right:
			dotOffsetX = s16(CK_INT("CK5_MineDotRightXOffset", 0x180))
		_:
			Quit("CK5_MineMoveDotsToSides: bad X direction")
			return

	match obj.yDirection:
		IN_motion_Up:
			dotOffsetY = s16(CK_INT("CK5_MineDotUpYOffset", 0x50))
		IN_motion_None:
			dotOffsetY = s16(CK_INT("CK5_MineDotYOffset", 0xD0))
		IN_motion_Down:
			dotOffsetY = s16(CK_INT("CK5_MineDotDownYOffset", 0x150))
		_:
			Quit("CK5_MineMoveDotsToSides: bad Y direction")
			return

	# Move the dot and change action
	# when it reaches the desired offset
	if obj.user2 < dotOffsetX:
		obj.user2 = s16(obj.user2 + SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user2 >= dotOffsetX:
			obj.user2 = dotOffsetX
			obj.currentAction = obj.currentAction.next
	elif obj.user2 > dotOffsetX:
		obj.user2 = s16(obj.user2 - SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user2 <= dotOffsetX:
			obj.user2 = dotOffsetX
			obj.currentAction = obj.currentAction.next

	# Do the same in the Y direction
	if obj.user3 < dotOffsetY:
		obj.user3 = s16(obj.user3 + SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user3 >= dotOffsetY:
			obj.user3 = dotOffsetY
			obj.currentAction = obj.currentAction.next
	elif obj.user3 > dotOffsetY:
		obj.user3 = s16(obj.user3 - SD_GetSpriteSync() * CK_INT("CK5_MineDotsSpeed", 4))
		if obj.user3 <= dotOffsetY:
			obj.user3 = dotOffsetY
			obj.currentAction = obj.currentAction.next

	return


func CK5_MineExplode(obj: CK_object) -> void:
	var new_object: CK_object
	SD_PlaySound(CK_SOUNDNUM("SOUND_MINEEXPLODE"))

	# upleft
	new_object = CK_GetNewObj(true)
	new_object.posX = u16(obj.posX + CK_INT("CK5_MineShrapASpawnXOffset", 0))
	new_object.posY = obj.posY
	new_object.velX = s16(CK_INT("CK5_MineShrapABaseXVel", 0) + US_RndT() / CK_INT("CK5_MineShrapARndXVel", -8))
	new_object.velY = s16(CK_INT("CK5_MineShrapABaseYVel", -48))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MineShrap0"))

	# upright
	new_object = CK_GetNewObj(true)
	new_object.posX = u16(obj.posX + CK_INT("CK5_MineShrapBSpawnXOffset", 0x100))
	new_object.posY = obj.posY
	new_object.velX = s16(CK_INT("CK5_MineShrapBBaseXVel", 0) + US_RndT() / CK_INT("CK5_MineShrapBRndXVel", 8))
	new_object.velY = s16(CK_INT("CK5_MineShrapBBaseYVel", -48))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MineShrap0"))

	new_object = CK_GetNewObj(true)
	new_object.posX = u16(obj.posX + CK_INT("CK5_MineShrapCSpawnXOffset", 0))
	new_object.posY = obj.posY
	new_object.velX = s16(US_RndT() / CK_INT("CK5_MineShrapCRndXVel", 16) + CK_INT("CK5_MineShrapCBaseXVel", 40))
	new_object.velY = s16(CK_INT("CK5_MineShrapCBaseYVel", -24))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MineShrap0"))

	new_object = CK_GetNewObj(true)
	new_object.posX = u16(obj.posX + CK_INT("CK5_MineShrapDSpawnXOffset", 0x100))
	new_object.posY = obj.posY
	new_object.velX = s16(CK_INT("CK5_MineShrapDBaseXVel", -40) + US_RndT() / CK_INT("CK5_MineShrapDRndXVel", 16))
	new_object.velY = s16(CK_INT("CK5_MineShrapDBaseYVel", -24))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MineShrap0"))

	new_object = CK_GetNewObj(true)
	new_object.posX = u16(obj.posX + CK_INT("CK5_MineShrapESpawnXOffset", 0))
	new_object.posY = obj.posY
	new_object.velX = s16(CK_INT("CK5_MineShrapEBaseXVel", 24))
	new_object.velY = s16(CK_INT("CK5_MineShrapEBaseYVel", 16))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MineShrap0"))

	new_object = CK_GetNewObj(true)
	new_object.posX = u16(obj.posX + CK_INT("CK5_MineShrapFSpawnXOffset", 0x100))
	new_object.posY = obj.posY
	new_object.velX = s16(CK_INT("CK5_MineShrapFBaseXVel", 24))
	new_object.velY = s16(CK_INT("CK5_MineShrapFBaseYVel", 16))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MineShrap0"))

	return


func CK5_MineTileCol(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer) # mine
	obj.user4 = RF_AddSpriteDrawUsing16BitOffset(obj.user4, obj.posX + obj.user2, obj.posY + obj.user3, CK_CHUNKNUM("SPR_SHIKADIMINEEYE"), false, 2) # dot
	return


func CK5_SpawnRobo(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT5_Robo
	obj.active = OBJ_ACTIVE
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_RoboSpawnYOffset", -0x400))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_None
	CK_SetAction(obj, CK_GetActionByName("CK5_ACT_Robo0"))


func CK5_RoboMove(obj: CK_object) -> void:
	# Check for shot opportunity
	if (obj.posX & 0x40) == 0 and ck_keenObj.clipRects.unitY2 > obj.clipRects.unitY1 and ck_keenObj.clipRects.unitY1 < obj.clipRects.unitY2 and US_RndT() < CK_INT("CK5_RoboShootChance", 0x10):
		obj.xDirection = IN_motion_Left if obj.posX > ck_keenObj.posX else IN_motion_Right
		obj.user1 = s16(CK_INT("CK5_RoboNumShots", 10))
		obj.currentAction = CK_GetActionByName("CK5_ACT_RoboShoot0")
# time is number of shots


func CK5_RoboCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
		o1.xDirection = IN_motion_Left if o1.posX > ck_keenObj.posX else IN_motion_Right
		o1.user1 = s16(CK_INT("CK5_RoboNumShots", 10))
		CK_SetAction2(o1, CK_GetActionByName("CK5_ACT_RoboShoot0"))
		return
	if o2.type == CT_Player:
		CK_KillKeen()


func CK5_RoboShoot(obj: CK_object) -> void:
	var new_object: CK_object
	var shotSpawnX: int

	obj.user1 = s16(obj.user1 - 1)
	if obj.user1 == 0:
		obj.currentAction = CK_GetActionByName("CK5_ACT_Robo0")

	shotSpawnX = (obj.posX + CK_INT("CK5_RoboShotRightXOffset", 0x380)) if obj.xDirection == IN_motion_Right else (obj.posX + CK_INT("CK5_RoboShotLeftXOffset", 0))

	new_object = CK5_SpawnEnemyShot(shotSpawnX, obj.posY + CK_INT("CK5_RoboShotYOffset", 0x200), CK_GetActionByName("CK5_ACT_RoboShot0"))
	if new_object != null:
		new_object.velX = s16(obj.xDirection * CK_INT("CK5_RoboShotXVelocity", 60))
		new_object.velY = s16(-CK_INT("CK5_RoboShotYVelocity", 8) if (obj.user1 & 1) != 0 else CK_INT("CK5_RoboShotYVelocity", 8))
		SD_PlaySound(CK_SOUNDNUM("SOUND_ENEMYSHOOT"))
		ck_nextX = s16(-CK_INT("CK5_RoboShotRecoil", 0x40) if obj.xDirection == IN_motion_Right else CK_INT("CK5_RoboShotRecoil", 0x40))


func CK5_RoboShotCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Player:
		CK_KillKeen()
		CK_SetAction2(o1, CK_GetActionByName("CK5_ACT_RoboShotHit0"))


func CK5_RoboShotTileCol(obj: CK_object) -> void:
	if obj.topTI != 0 or obj.rightTI != 0 or obj.bottomTI != 0 or obj.leftTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_ENEMYSHOTHIT"))
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_RoboShotHit0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Spirogrip Funcs

func CK5_SpawnSpirogrip(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT5_Spirogrip
	obj.active = OBJ_ACTIVE
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_SpirogripSpawnYOffset", -256))

	obj.xDirection = 1 # Right
	obj.yDirection = 1 # Down

	CK_SetAction(obj, CK_GetActionByName("CK5_ACT_SpirogripAttachDown"))


func CK5_SpirogripSpin(obj: CK_object) -> void:
	# If we're bored of spinning...
	if US_RndT() > CK_INT("CK5_SpirogripLaunchChance", 20):
		return

	SD_PlaySound(CK_SOUNDNUM("SOUND_SPIROFLY"))

	# and we're in the right direction, fly!
	if obj.currentAction == CK_GetActionByName("CK5_ACT_SpirogripSpin1"):
		obj.currentAction = CK_GetActionByName("CK5_ACT_SpirogripFlyUp")
	elif obj.currentAction == CK_GetActionByName("CK5_ACT_SpirogripSpin3"):
		obj.currentAction = CK_GetActionByName("CK5_ACT_SpirogripFlyRight")
	elif obj.currentAction == CK_GetActionByName("CK5_ACT_SpirogripSpin5"):
		obj.currentAction = CK_GetActionByName("CK5_ACT_SpirogripFlyDown")
	elif obj.currentAction == CK_GetActionByName("CK5_ACT_SpirogripSpin7"):
		obj.currentAction = CK_GetActionByName("CK5_ACT_SpirogripFlyLeft")


func CK5_SpirogripFlyDraw(obj: CK_object) -> void:
	# Draw the sprite
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	# Check if we've collided with a tile
	if obj.topTI != 0 or obj.rightTI != 0 or obj.bottomTI != 0 or obj.leftTI != 0:
		# obj->currentAction = obj->currentAction->next;
		CK_SetAction2(obj, obj.currentAction.next)
		SD_PlaySound(CK_SOUNDNUM("SOUND_SPIROSLAM"))


func CK5_SpawnSpindred(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Spindred
	new_object.active = OBJ_ACTIVE
	new_object.zLayer = 0
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_SpindredSpawnYOffset", -0x80))
	new_object.yDirection = IN_motion_Down
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Spindred0"))


func CK5_SpindredBounce(obj: CK_object) -> void:
	var lastTimeCount: int = s32(SD_GetLastTimeCount()) # int32_t
	var timedelta: int = s32(lastTimeCount - SD_GetSpriteSync()) # int32_t
	while timedelta < lastTimeCount:
		# Every odd tic...
		if (timedelta & 1) != 0:
			if obj.yDirection == IN_motion_Down:
				if obj.velY < 0 and obj.velY >= -CK_INT("CK5_SpindredAccel", 3):
					ck_nextY = s16(ck_nextY + obj.velY)
					obj.velY = 0
					return

				obj.velY = s16(obj.velY + CK_INT("CK5_SpindredAccel", 3))
				if obj.velY > CK_INT("CK5_SpindredTerminalVelocity", 70):
					obj.velY = s16(CK_INT("CK5_SpindredTerminalVelocity", 70))
			else:
				if obj.velY > 0 and obj.velY <= CK_INT("CK5_SpindredAccel", 3):
					ck_nextY = s16(ck_nextY + obj.velY)
					obj.velY = 0
					return
				obj.velY = s16(obj.velY - CK_INT("CK5_SpindredAccel", 3))
				if obj.velY < -CK_INT("CK5_SpindredTerminalVelocity", 70):
					obj.velY = s16(-CK_INT("CK5_SpindredTerminalVelocity", 70))
		ck_nextY = s16(ck_nextY + obj.velY)
		timedelta = s32(timedelta + 1)


func CK5_SpindredTileCol(obj: CK_object) -> void:
	if obj.bottomTI != 0:
		obj.velY = 0
		if obj.yDirection == IN_motion_Up:
			# Reverse directions after three slams
			obj.user1 = s16(obj.user1 + 1)
			if obj.user1 == CK_INT("CK5_SpindredNumBounces", 3):
				obj.user1 = 0
				obj.velY = s16(CK_INT("CK5_SpindredFlyVel", 68))
				obj.yDirection = s16(-obj.yDirection)
				SD_PlaySound(CK_SOUNDNUM("SOUND_SPINDREDFLYDOWN")) # fly down
			else:
				SD_PlaySound(CK_SOUNDNUM("SOUND_SPINDREDSLAM")) # slam once
				obj.velY = s16(CK_INT("CK5_SpindredSlamVel", 40))

	if obj.topTI != 0:
		obj.velY = 0
		if obj.yDirection == IN_motion_Down:
			obj.user1 = s16(obj.user1 + 1)
			if obj.user1 == CK_INT("CK5_SpindredNumBounces", 3):
				# time holds slamcount
				obj.user1 = 0
				obj.velY = s16(-CK_INT("CK5_SpindredFlyVel", 68))
				obj.yDirection = s16(-obj.yDirection)
				SD_PlaySound(CK_SOUNDNUM("SOUND_SPINDREDFLYUP")) # fly down
			else:
				SD_PlaySound(CK_SOUNDNUM("SOUND_SPINDREDSLAM")) # slam once
				obj.velY = s16(-CK_INT("CK5_SpindredSlamVel", 40))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnMaster(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Master
	new_object.active = OBJ_ACTIVE
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_MasterSpawnYOffset", -0x180))
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Master0"))


func CK5_MasterStand(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK5_MasterStandChance", 0x40):
		return

	if obj.user1 != 0:
		obj.currentAction = CK_GetActionByName("CK5_ACT_MasterTele0")
		obj.user1 = 0
		return

	obj.user1 = 1
	obj.xDirection = IN_motion_Right if ck_keenObj.posX > obj.posX else IN_motion_Left
	obj.currentAction = CK_GetActionByName("CK5_ACT_MasterShoot0")


func CK5_MasterShoot(obj: CK_object) -> void:
	var xPos: int
	var new_object: CK_object

	xPos = (CK_INT("CK5_MasterShotRightXOffset", 0x100) + obj.posX) if obj.xDirection == IN_motion_Right else (CK_INT("CK5_MasterShotLeftXOffset", 0) + obj.posX)
	new_object = CK5_SpawnEnemyShot(xPos, obj.posY + CK_INT("CK5_MasterShotYOffset", 0x80), CK_GetActionByName("CK5_ACT_MasterBall0"))
	if new_object != null:
		new_object.velX = s16(obj.xDirection * CK_INT("CK5_MasterShotXVel", 48))
		new_object.velY = s16(CK_INT("CK5_MasterShotYVel", -16))
		SD_PlaySound(CK_SOUNDNUM("SOUND_MASTERSHOT"))


# time is shooting flag

func CK5_MasterCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
		# (omnispeak's quirk, kept: the difference's truth, not its sign, picks the direction)
		o1.xDirection = IN_motion_Right if (ck_keenObj.posX - o1.posX) != 0 else IN_motion_Left
		o1.user1 = 1
		CK_SetAction2(o1, CK_GetActionByName("CK5_ACT_MasterShoot0"))
		return

	if o2.type == CT_Player:
		CK_KillKeen()


func CK5_MasterTele(obj: CK_object) -> void:
	var posX_0: int
	var posY_0: int
	var tx: int
	var ty: int
	var tries: int
	var mapXT: int
	var mapYT: int
	var tile: int
	var new_object: CK_object

	posX_0 = obj.posX
	posY_0 = obj.posY

	# Spawn sparks going in both directions
	new_object = CK_GetNewObj(true)
	if new_object != null:
		new_object.posX = obj.posX
		new_object.posY = obj.posY
		new_object.velX = 0x30
		CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MasterSparks0"))

	new_object = CK_GetNewObj(true)
	if new_object != null:
		new_object.posX = obj.posX
		new_object.posY = obj.posY
		new_object.velX = -0x30
		CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MasterSparks0"))

	SD_PlaySound(CK_SOUNDNUM("SOUND_MASTERTELE"))

	# Find a teleportation destination
	tries = 0
	while true:
		tries += 1
		if not (tries < CK_INT("CK5_MasterTeleNumTries", 10)):
			break
		# Pick a spot near keen
		tx = US_RndT() / CK_INT("CK5_MasterTeleRadiusDiv", 8) + ck_keenObj.clipRects.tileXmid + CK_INT("CK5_MasterTeleXOffset", -0x10)
		ty = US_RndT() / CK_INT("CK5_MasterTeleRadiusDiv", 8) + ck_keenObj.clipRects.tileY2 + CK_INT("CK5_MasterTeleYOffset", -0x10)

		# Try again if out of the map bounds
		if ty < 2 or tx < 2 or CA_GetMapWidth() - 5 < tx or CA_GetMapHeight() - 5 < ty:
			continue

		# Set the new position and clipping rectangle of the master
		obj.posX = u16(RF_TileToUnit(tx))
		obj.posY = u16(RF_TileToUnit(ty))
		obj.clipRects.tileX1 = u16(tx + CK_INT("CK5_MasterTeleClipX1", -1))
		obj.clipRects.tileX2 = u16(tx + CK_INT("CK5_MasterTeleClipX2", 4))
		obj.clipRects.tileY1 = u16(ty + CK_INT("CK5_MasterTeleClipY1", -1))
		obj.clipRects.tileY2 = u16(ty + CK_INT("CK5_MasterTeleClipY2", 4))

		# Check that the master hasn't spawned in a wall or a hidden passage
		# (omnispeak's quirk, kept: the inner loop runs mapXT from tileX1 while
		# it is below tileX1, so it never runs, and its `continue` would only
		# continue the inner loop anyway: every in-bounds spot is accepted)
		mapYT = obj.clipRects.tileY1
		while mapYT < obj.clipRects.tileY2:
			mapXT = obj.clipRects.tileX1
			while mapXT < obj.clipRects.tileX1:
				tile = CA_TileAtPos(s16(mapXT), s16(mapYT), 1)

				if (TI_ForeMisc(tile) & 0x80) != 0 or TI_ForeTop(tile) != 0 or TI_ForeRight(tile) != 0 or TI_ForeLeft(tile) != 0 or TI_ForeBottom(tile) != 0:
					mapXT += 1
					continue
				mapXT += 1
			mapYT += 1

		# make it through previous nested loop == succesful tele
		ck_nextX = 0
		ck_nextY = 0
		return

	# couldn't find a suitable spawn point, so reset to default master behaviour
	US_RndT() # Advance the random table for some reason
	obj.currentAction = CK_GetActionByName("CK5_ACT_Master0")
	obj.posX = u16(posX_0 - 1)
	obj.posY = u16(posY_0)
	ck_nextX = 1
	ck_nextY = 0


# This was actually found in CK_MISC.C, which would suggest it had a more
# general use  (changing action when floor is hit)
# But it ended up only being used for the master teleporting tile col
# so it goes here

func CK5_MasterTeleTileCol(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0

	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		obj.velY = 0
		if obj.currentAction.next == null:
			CK_RemoveObj(obj)
			return
		else:
			CK_SetAction2(obj, obj.currentAction.next)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_MasterBallCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
		CK_RemoveObj(o1)
		return

	if o2.type == CT_Player:
		CK_KillKeen()
		CK_RemoveObj(o1)


func CK5_MasterBallTileCol(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = s16(-obj.velX)
	if obj.bottomTI != 0:
		obj.velY = 0
	if obj.topTI != 0:
		# turn ball into sparks, spawn sparks in reverse direction
		SD_PlaySound(CK_SOUNDNUM("SOUND_MASTERSHOT"))
		var new_object: CK_object
		obj.velX = s16(CK_INT("CK5_MasterSparksXVel", 48))
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_MasterSparks0"))
		new_object = CK_GetNewObj(true)
		if new_object != null:
			new_object.posX = obj.posX
			new_object.posY = obj.posY
			new_object.velX = s16(-CK_INT("CK5_MasterSparksXVel", 48))

			CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_MasterSparks0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_MasterSparksTileCol(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		CK_RemoveObj(obj)
		return

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnShikadi(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Shikadi
	new_object.active = OBJ_ACTIVE
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_ShikadiSpawnYOffset", -0x100))
	new_object.user2 = s16(CK_INT("CK5_ShikadiHealth", 4))
	new_object.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	new_object.yDirection = IN_motion_Down
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_ShikadiStand0"))


# (#define MISCFLAG_POLE 1: the same value as gal_ck.gd's constant)
# (extern void CK_KeenSpecialColFunc(...): ck_keen.c's)

func CK5_ShikadiWalk(obj: CK_object) -> void:
	var tx: int
	var tile: int

	# By casting to unsigned, we also check if the difference in
	# Y values is greater than zero
	if ck_keenObj.currentAction.collide == &"CK_KeenSpecialColFunc" or ((obj.clipRects.unitY2 - ck_keenObj.clipRects.unitY2 + 0x100) & 0xFFFFFFFF) <= 0x200:
		# if Keen on Pole or Keen at shikadi level , get to keen
		# walk back and forth one tile to the left or right underneath him
		if obj.posX > ck_keenObj.posX + CK_INT("CK5_ShikadiPoleXRadius", 0x100):
			obj.xDirection = IN_motion_Left
		elif obj.posX < ck_keenObj.posX - CK_INT("CK5_ShikadiPoleXRadius", 0x100):
			obj.xDirection = IN_motion_Right

		tx = obj.clipRects.tileX2 if obj.xDirection == IN_motion_Right else obj.clipRects.tileX1

		if ck_keenObj.clipRects.tileXmid != tx:
			return # no zapping if not below keen
	else:
		if US_RndT() < CK_INT("CK5_ShikadiPoleZapChance", 0x10):
			# 1/16 chance of stopping walk
			ck_nextX = 0
			obj.currentAction = CK_GetActionByName("CK5_ACT_ShikadiStand0")
			return

		# if at tile boundary (i.e., ready for zap)
		if (obj.posX & 0xFF) != 0 or not CK_ObjectVisible(obj):
			return

		tx = obj.clipRects.tileX2 if obj.xDirection == IN_motion_Right else obj.clipRects.tileX1

	# Make a pole zap
	tile = CA_TileAtPos(tx, obj.clipRects.tileY1, 1)
	# tile = *MAPSPOT(tx, obj->clipRects.tileY1, FGPLANE);
	if TI_ForeMisc(tile) == MISCFLAG_POLE:
		obj.user1 = s16(tx)
		obj.currentAction = CK_GetActionByName("CK5_ACT_ShikadiPole0")
		ck_nextX = 0
		SD_PlaySound(CK_SOUNDNUM("SOUND_POLEZAP"))


# int33 is white flash duration
# state = health

func CK5_ShikadiCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Player:
		CK_KillKeen()

	if o2.type == CT_Stunner:
		o1.user2 = s16(o1.user2 - 1)
		if o1.user2 != 0:
			o1.user3 = 2
			o1.visible = true
			CK_ShotHit(o2)
		else:
			o1.velY = 0
			o1.velX = 0
			CK_StunCreature(o1, o2, CK_GetActionByName("CK5_ACT_ShikadiStun0"))


func CK5_ShikadiPole(obj: CK_object) -> void:
	var sparkX: int
	var new_object: CK_object

	obj.timeUntillThink = 2
	sparkX = RF_TileToUnit(obj.clipRects.tileX2) if obj.xDirection == IN_motion_Right else RF_TileToUnit(obj.clipRects.tileX1)
	new_object = CK_GetNewObj(true)
	new_object.posX = u16(sparkX)
	new_object.posY = u16(obj.posY + 0x80)
	new_object.type = CT5_EnemyShot
	new_object.active = OBJ_EXISTS_ONLY_ONSCREEN
	new_object.clipped = CLIP_not
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_PoleZap0"))
	new_object.yDirection = IN_motion_Up if obj.posY > ck_keenObj.posY else IN_motion_Down
	SD_PlaySound(CK_SOUNDNUM("SOUND_POLEZAP"))


func CK5_PoleZap(obj: CK_object) -> void:
	var tile: int
	if ck_nextY == 0:
		# Slide up until there's no more pole
		ck_nextY = s16(obj.yDirection * CK_INT("CK5_ShikadiPoleZapSpeed", 48))
		tile = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY1, 1)

		if TI_ForeMisc(tile) != MISCFLAG_POLE:
			obj.currentAction = null


func CK5_ShikadiTileCol(obj: CK_object) -> void:
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = s16(-obj.xDirection)
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)

	# if flashing white
	if obj.user3 != 0:
		obj.user3 = s16(obj.user3 - 1)
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, true, obj.zLayer)
	else:
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnShocksund(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Shocksund
	new_object.active = OBJ_ACTIVE
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_ShocksundSpawnYOffset", -0x80))
	new_object.user2 = s16(CK_INT("CK5_ShocksundHealth", 2))
	new_object.xDirection = IN_motion_Right
	new_object.yDirection = IN_motion_Down
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Shocksund0"))


func CK5_ShocksundSearch(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Left if obj.posX > ck_keenObj.posX else IN_motion_Right

	if US_RndT() < CK_INT("CK5_ShocksundStandChance", 0x10):
		ck_nextX = 0
		obj.currentAction = CK_GetActionByName("CK5_ACT_ShocksundStand0")
		obj.user1 = s16(CK_INT("CK5_ShocksundStandTime", 0x10))
		return

	if obj.clipRects.unitY2 != ck_keenObj.clipRects.unitY2:
		obj.currentAction = CK_GetActionByName("CK5_ACT_ShocksundJump0")
		obj.velX = s16((1 if obj.xDirection == IN_motion_Right else -1) * CK_INT("CK5_ShocksundJumpXVel", 40))
		obj.velY = s16(CK_INT("CK5_ShocksundJumpYVel", -40))

	if US_RndT() < CK_INT("CK5_ShocksundShootChance", 0x80):
		ck_nextX = 0
		obj.currentAction = CK_GetActionByName("CK5_ACT_ShocksundShoot0")


func CK5_ShocksundStand(obj: CK_object) -> void:
	obj.user1 = s16(obj.user1 - 1)
	if obj.user1 == 0:
		obj.currentAction = CK_GetActionByName("CK5_ACT_Shocksund0")


func CK5_ShocksundShoot(obj: CK_object) -> void:
	var new_object: CK_object
	var posX: int = (obj.posX + CK_INT("CK5_ShocksundShotRightXOffset", 0x70)) if obj.xDirection == IN_motion_Right else (obj.posX + CK_INT("CK5_ShocksundShotLeftXOffset", 0))

	new_object = CK5_SpawnEnemyShot(posX, obj.posY + CK_INT("CK5_ShocksundShotYOffset", 0x40), CK_GetActionByName("CK5_ACT_BarkShot0"))
	if new_object != null:
		new_object.velX = s16(obj.xDirection * CK_INT("CK5_ShocksundShotXVel", 60))
		new_object.xDirection = obj.xDirection
		SD_PlaySound(CK_SOUNDNUM("SOUND_SHOCKSUNDBARK"))


func CK5_ShocksundCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Player:
		CK_KillKeen()

	if o2.type == CT_Stunner:
		o1.user2 = s16(o1.user2 - 1)
		if o1.user2 != 0:
			o1.user3 = 2
			o1.visible = true
			CK_ShotHit(o2)
		else:
			o1.velY = 0
			o1.velX = 0
			CK_StunCreature(o1, o2, CK_GetActionByName("CK5_ACT_ShocksundStun0"))


func CK5_ShocksundGroundTileCol(obj: CK_object) -> void:
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	elif obj.topTI == 0:
		# if facing ck_keenObj, jump towards him, else turn around at edge
		if (obj.xDirection == IN_motion_Right and ck_keenObj.posX > obj.posX) or (obj.xDirection == IN_motion_Left and ck_keenObj.posX < obj.posX):
			CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_ShocksundJump0"))
			obj.velX = s16(CK_INT("CK5_ShocksundJumpXVel", 40) if obj.xDirection == IN_motion_Right else -CK_INT("CK5_ShocksundJumpXVel", 40))
			obj.velY = s16(CK_INT("CK5_ShocksundJumpYVel", -40))
		else:
			obj.posX = u16(obj.posX - obj.deltaPosX)
			obj.xDirection = s16(-obj.xDirection)
			obj.timeUntillThink = u16(US_RndT() / 32)
			CK_SetAction2(obj, obj.currentAction)

	# if flashing white
	if obj.user3 != 0:
		obj.user3 = s16(obj.user3 - 1) # flash counter
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, true, obj.zLayer)
	else:
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_ShocksundJumpTileCol(obj: CK_object) -> void:
	if obj.topTI != 0:
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_Shocksund0"))
	if obj.user3 != 0:
		obj.user3 = s16(obj.user3 - 1) # flash counter
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, true, obj.zLayer)
	else:
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_BarkShotCol(o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Player:
		CK_KillKeen()
		CK_SetAction2(o1, CK_GetActionByName("CK5_ACT_BarkShotDie0"))
		return

	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
		CK_SetAction2(o1, CK_GetActionByName("CK5_ACT_BarkShotDie0"))


func CK5_BarkShotTileCol(obj: CK_object) -> void:
	if obj.topTI != 0 or obj.rightTI != 0 or obj.bottomTI != 0 or obj.leftTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_BARKSHOTDIE"))

		CK_SetAction2(obj, CK_GetActionByName("CK5_ACT_BarkShotDie0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK5_SpawnSphereful(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_Sphereful
	new_object.clipped = CLIP_simple
	new_object.active = OBJ_ACTIVE
	new_object.posX = u16(RF_TileToUnit(tileX))
	new_object.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_SpherefulSpawnYOffset", -0x100))
	new_object.zLayer = 1
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_Sphereful0"))


func CK5_SpherefulBounce(obj: CK_object) -> void:
	obj.visible = true

	if ck_nextX != 0 or ck_nextY != 0:
		return

	var lastTimeCount: int = s32(SD_GetLastTimeCount()) # int32_t
	# Bounce around, and home in on Keen
	var ticks_0: int = s32(lastTimeCount - SD_GetSpriteSync()) # int32_t
	while ticks_0 < lastTimeCount:
		if (ticks_0 & 0xF) == 0:
			if obj.velY < CK_INT("CK5_SpherefulMaxYVel", 8):
				obj.velY = s16(obj.velY + 1)

			if ck_keenObj.posX > obj.posX and obj.velX < CK_INT("CK5_SpherefulMaxXVel", 8):
				obj.velX = s16(obj.velX + 1)

			if ck_keenObj.posX < obj.posX and obj.velX > -CK_INT("CK5_SpherefulMaxXVel", 8):
				obj.velX = s16(obj.velX - 1)
		ck_nextY = s16(ck_nextY + obj.velY)
		ck_nextX = s16(ck_nextX + obj.velX)
		ticks_0 = s32(ticks_0 + 1)


## CK5_SpherefulTileCol's static uint16_t diamondpos[16].
const diamondpos: PackedInt32Array = [0x180, 0x171, 0x148, 0x109, 0x0C0, 0x077, 0x03A, 0x00F,
	0x000, 0x00F, 0x03A, 0x077, 0x0C0, 0x109, 0x148, 0x171]


## (The diamond sprite chunk is the literal 362, as in omnispeak.)
func CK5_SpherefulTileCol(obj: CK_object) -> void:
	var zLayer: int # int16_t
	var time: int # uint16_t
	var diamond_chunk: int # uint16_t

	# Make the sphereful bounce off of walls
	if obj.leftTI != 0 or obj.rightTI != 0:
		obj.velX = s16(-obj.velX)
		SD_PlaySound(CK_SOUNDNUM("SOUND_SPHEREFULCEILING"))

	if obj.bottomTI != 0:
		obj.velY = s16(-obj.velY)
		SD_PlaySound(CK_SOUNDNUM("SOUND_SPHEREFULCEILING"))

	if obj.topTI != 0:
		obj.velY = s16(-obj.velY)
		if ck_keenObj.posY < obj.posY:
			obj.velY = s16(obj.velY - 1)
		else:
			obj.velY = s16(obj.velY + 1)

		if obj.velY > CK_INT("CK5_SpherefulBounceMaxYVel", -4):
			obj.velY = s16(CK_INT("CK5_SpherefulBounceMaxYVel", -4))
		elif obj.velY < CK_INT("CK5_SpherefulBounceMinYVel", -12):
			obj.velY = s16(CK_INT("CK5_SpherefulBounceMinYVel", -12))
		# FIXME: Any better name for (shared) sound?
		SD_PlaySound(CK_SOUNDNUM("SOUND_SPINDREDFLYUP"))

	# First draw the sphereful
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	# draw the diamonds
	time = u16((SD_GetLastTimeCount() >> 3) & 0xF)

	diamond_chunk = u16((time >> 2) + 362)
	zLayer = 2 if time >= 8 else 0

	# topleft
	obj.user1 = RF_AddSpriteDrawUsing16BitOffset(obj.user1, obj.posX + diamondpos[time], obj.posY + diamondpos[time], diamond_chunk, false, zLayer)

	# topright
	obj.user2 = RF_AddSpriteDrawUsing16BitOffset(obj.user2, obj.posX + 0x180 - diamondpos[time], obj.posY + diamondpos[time], diamond_chunk, false, zLayer)

	time = u16((time + 8) & 0xF)
	zLayer = 2 if time >= 8 else 0

	# botleft
	obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + diamondpos[time], obj.posY + diamondpos[time], diamond_chunk, false, zLayer)

	# botright
	obj.user4 = RF_AddSpriteDrawUsing16BitOffset(obj.user4, obj.posX + 0x180 - diamondpos[time], obj.posY + diamondpos[time], diamond_chunk, false, zLayer)


# Korath Funcs

func CK5_KorathWalk(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK5_KorathTurnChance", 10):
		ck_nextX = 0
		obj.xDirection = 1 if US_RndT() < 128 else -1
		obj.currentAction = CK_GetActionByName("CK5_ACT_KorathWait")


func CK5_KorathColFunc(obj: CK_object, other: CK_object) -> void:
	# if keen and pushable
	if other.type == CT_Player and other.currentAction.collide != &"":
		CK_PhysPushX(other, obj)
	elif other.type == CT_Stunner:
		CK_StunCreature(obj, other, CK_GetActionByName("CK5_ACT_KorathStun0"))


func CK5_SpawnKorath(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT5_Korath
	obj.active = OBJ_ACTIVE
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK5_KorathSpawnYOffset", -128))
	obj.xDirection = 1 if US_RndT() < 128 else -1
	CK_SetAction(obj, CK_GetActionByName("CK5_ACT_KorathWalk1"))


func CK5_QEDSpawn(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT5_QED
	new_object.active = OBJ_ACTIVE
	new_object.clipRects.tileX1 = u16(tileX)
	new_object.clipRects.tileY1 = u16(tileY)
	new_object.clipRects.tileX2 = u16(new_object.clipRects.tileX1 + 1)
	new_object.clipRects.tileY2 = u16(new_object.clipRects.tileY1 + 1)
	new_object.clipRects.unitX1 = u16(RF_TileToUnit(tileX) - 0x10)
	new_object.clipRects.unitY1 = u16(RF_TileToUnit(tileY) - 0x10)
	new_object.clipRects.unitX2 = u16(new_object.clipRects.unitX1 + 0x220)
	new_object.clipRects.unitY2 = u16(new_object.clipRects.unitY1 + 0x220)
	CK_SetAction(new_object, CK_GetActionByName("CK5_ACT_QED"))


## Add the Obj3 functions to the function db
func CK5_Obj3_SetupFunctions() -> void:
	# Shikadi Mine
	CK_ACT_AddFunction("CK5_MineMove", &"CK5_MineMove")
	CK_ACT_AddFunction("CK5_MineMoveDotsToCenter", &"CK5_MineMoveDotsToCenter")
	CK_ACT_AddFunction("CK5_MineMoveDotsToSides", &"CK5_MineMoveDotsToSides")
	CK_ACT_AddFunction("CK5_MineExplode", &"CK5_MineExplode")
	CK_ACT_AddColFunction("CK5_MineCol", &"CK5_MineCol")
	CK_ACT_AddColFunction("CK5_MineShrapCol", &"CK5_MineShrapCol")
	CK_ACT_AddFunction("CK5_MineTileCol", &"CK5_MineTileCol")

	# Robo Red
	CK_ACT_AddFunction("CK5_RoboMove", &"CK5_RoboMove")
	CK_ACT_AddColFunction("CK5_RoboCol", &"CK5_RoboCol")
	CK_ACT_AddFunction("CK5_RoboShoot", &"CK5_RoboShoot")
	CK_ACT_AddColFunction("CK5_RoboShotCol", &"CK5_RoboShotCol")
	CK_ACT_AddFunction("CK5_RoboShotTileCol", &"CK5_RoboShotTileCol")

	# Spirogrip
	CK_ACT_AddFunction("CK5_SpirogripSpin", &"CK5_SpirogripSpin")
	CK_ACT_AddFunction("CK5_SpirogripFlyDraw", &"CK5_SpirogripFlyDraw")

	# Spindred
	CK_ACT_AddFunction("CK5_SpindredBounce", &"CK5_SpindredBounce")
	CK_ACT_AddFunction("CK5_SpindredTileCol", &"CK5_SpindredTileCol")

	# Shikadi Master
	CK_ACT_AddFunction("CK5_MasterStand", &"CK5_MasterStand")
	CK_ACT_AddFunction("CK5_MasterShoot", &"CK5_MasterShoot")
	CK_ACT_AddColFunction("CK5_MasterCol", &"CK5_MasterCol")
	CK_ACT_AddFunction("CK5_MasterTele", &"CK5_MasterTele")
	CK_ACT_AddFunction("CK5_MasterTeleTileCol", &"CK5_MasterTeleTileCol")
	CK_ACT_AddColFunction("CK5_MasterBallCol", &"CK5_MasterBallCol")
	CK_ACT_AddFunction("CK5_MasterBallTileCol", &"CK5_MasterBallTileCol")
	CK_ACT_AddFunction("CK5_MasterSparksTileCol", &"CK5_MasterSparksTileCol")

	# Shikadi
	CK_ACT_AddFunction("CK5_ShikadiWalk", &"CK5_ShikadiWalk")
	CK_ACT_AddColFunction("CK5_ShikadiCol", &"CK5_ShikadiCol")
	CK_ACT_AddFunction("CK5_ShikadiPole", &"CK5_ShikadiPole")
	CK_ACT_AddFunction("CK5_PoleZap", &"CK5_PoleZap")
	CK_ACT_AddFunction("CK5_ShikadiTileCol", &"CK5_ShikadiTileCol")
	CK_ACT_AddFunction("CK5_ShocksundSearch", &"CK5_ShocksundSearch")
	CK_ACT_AddFunction("CK5_ShocksundStand", &"CK5_ShocksundStand")
	CK_ACT_AddFunction("CK5_ShocksundShoot", &"CK5_ShocksundShoot")
	CK_ACT_AddColFunction("CK5_ShocksundCol", &"CK5_ShocksundCol")
	CK_ACT_AddFunction("CK5_ShocksundGroundTileCol", &"CK5_ShocksundGroundTileCol")
	CK_ACT_AddFunction("CK5_ShocksundJumpTileCol", &"CK5_ShocksundJumpTileCol")
	CK_ACT_AddColFunction("CK5_BarkShotCol", &"CK5_BarkShotCol")
	CK_ACT_AddFunction("CK5_BarkShotTileCol", &"CK5_BarkShotTileCol")

	# Sphereful
	CK_ACT_AddFunction("CK5_SpherefulBounce", &"CK5_SpherefulBounce")
	CK_ACT_AddFunction("CK5_SpherefulTileCol", &"CK5_SpherefulTileCol")

	# Korath
	CK_ACT_AddFunction("CK5_KorathWalk", &"CK5_KorathWalk")
	CK_ACT_AddColFunction("CK5_KorathColFunc", &"CK5_KorathColFunc")

	# QED
