# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's ck6_misc.c, ck6_map.c and ck6_obj1-3.c, by David Gow and the Omnispeak authors,
# GPL v2 or later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalKeen6
extends GalMenu
## Keen 6's episode code (SIM-G-01h).
##
## Every store wraps as its C type does (u16 for the uint16_t position and
## clip-rect fields, s16 for the int16_t ones). CK_INT is intptr_t in C, so
## arithmetic with it is wide (no wrap) until the store. C's uint16_t * map
## pointers (CA_TilePtrAtPos) are indices into CA_mapPlanes[plane]; *ptr is
## CA_mapPlanes[plane][ptr]. C's Quit() never returns; here it only flags the
## quit, so each Quit is followed by a return.


## The DOS memory Keen 6's manager gets: provisional, Keen 5's layout (the user's v1.0
## executable did not answer the debug keys in keen6_mem01_a/b, so its own map is not yet
## read; MM-01 in the ledger).
func mm_layout() -> Dictionary:
	return {"near": [0x3ff8, 0x177], "far": [0x41d8, 0x5e26], "high": [0xd001, 0x1fff],
		"introscn": [0x2270, 0xfa], "tile8": 108, "tile8m": 36}


# ===================================================================== ck6_misc.c

# ck6_episode (the CK_EpisodeDef) is declared in gal_ck.gd.


func CK6_SetupFunctions() -> void:
	CK6_Obj1_SetupFunctions()
	CK6_Obj2_SetupFunctions()
	CK6_Obj3_SetupFunctions()
	CK6_Map_SetupFunctions()


## Check if all the game files are present.
## (C asks the file system for EGAGRAPH, GAMEMAPS, AUDIO and omnispeak's own
## files; here GalData has loaded the data set, so this checks it is Keen 6's.)
func CK6_IsPresent() -> bool:
	return data != null and data.ext == "CK6"


func CK6_ScanInfoLayer() -> void:
	CA_ClearLumps()

	var mapW: int = CA_GetMapWidth()
	var mapH: int = CA_GetMapHeight()

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
					ca_graphChunkNeeded[175] = ca_graphChunkNeeded[175] | ca_levelbit
					CK_SpawnMapKeen(x, y)
					CA_MARKLUMP("LUMP_MAPKEEN")

				# Bloogs (C: case 6 falls through to 5, 5 to 4)
				4, 5, 6:
					if infoValue == 6 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 5 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BLOOG")
						CK6_SpawnBloog(x, y)

				7, 8, 9, 10, 11, 12, 13, 14:
					var color: int = (infoValue - 7) % 4
					CA_MarkLumpNeeded(CK_INT("LUMP_RBLOOGLET", -color) + color)
					if infoValue > 10:
						CA_MARKLUMP("LUMP_KEYGEMS")
					CK6_SpawnBlooglet(x, y, infoValue - 7)

				15, 16:
					CK6_SpawnMapCliff(x, y, infoValue - 15)

				# Molly (for some reason, values 21, 22, and 23 also work.
				# (use 24 in-game)
				21, 22, 23, 24:
					CA_MARKLUMP("LUMP_MOLLY")
					CK6_SpawnMolly(x, y)

				# Fleex (C: case 20 falls through to 19, 19 to 18)
				18, 19, 20:
					if infoValue == 20 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 19 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_FLEEX")
						CK6_SpawnFleex(x, y)

				25:
					RF_SetScrollBlock(x, y, true)
				26:
					RF_SetScrollBlock(x, y, false)

				# Platforms
				27, 28, 29, 30:
					CK_SpawnAxisPlatform(x, y, infoValue - 27, false)
					CA_MARKLUMP("LUMP_PLATFORM")
				32:
					CK_SpawnFallPlat(x, y)
					CA_MARKLUMP("LUMP_PLATFORM")

				# (C: case 33 falls through to 34, 34 to 35)
				33, 34, 35:
					if infoValue == 33 and ck_gameState.difficulty > D_Easy:
						pass
					elif infoValue <= 34 and ck_gameState.difficulty > D_Normal:
						pass
					else:
						CK_SpawnStandPlatform(x, y)
						CA_MARKLUMP("LUMP_PLATFORM")

				36, 37, 38, 39:
					CK_SpawnGoPlat(x, y, infoValue - 36, false)
					CA_MARKLUMP("LUMP_PLATFORM")
					CA_MARKLUMP("LUMP_BIPSQUISHED")
				40:
					CK_SneakPlatSpawn(x, y)
					CA_MARKLUMP("LUMP_PLATFORM")

				# Bobbas (C: case 43 falls through to 42, 42 to 41)
				41, 42, 43:
					if infoValue == 43 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 42 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BOBBA")
						CK6_SpawnBobba(x, y)

				44, 45:
					CK6_SpawnSatelliteLoading(x, y, infoValue - 44)

				# Nospike (C: case 49 falls through to 48, 48 to 47)
				47, 48, 49:
					if infoValue == 49 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 48 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_NOSPIKE")
						CK6_SpawnNospike(x, y)

				# Gik (C: case 52 falls through to 51, 51 to 50)
				50, 51, 52:
					if infoValue == 52 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 51 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_GIK")
						CK6_SpawnGik(x, y)

				# Turrets
				53, 54, 55, 56:
					CA_MARKLUMP("LUMP_LASER")
					CK_TurretSpawn(x, y, infoValue - 53)

				# (C: case 69 falls through to the items, as item 68)
				57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69:
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

				# Orbatrices (C: case 72 falls through to 71, 71 to 70)
				70, 71, 72:
					if infoValue == 72 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 71 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_ORBATRIX")
						CK6_SpawnOrbatrix(x, y)

				# Bip (C: case 75 falls through to 74, 74 to 73)
				73, 74, 75:
					if infoValue == 75 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 74 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BIP")
						CA_MARKLUMP("LUMP_BIPSQUISHED")
						CA_MARKLUMP("LUMP_BIPSHIP")
						CK6_SpawnBipship(x, y)

				# Flects (C: case 78 falls through to 77, 77 to 76)
				76, 77, 78:
					if infoValue == 78 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 77 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_FLECT")
						CK6_SpawnFlect(x, y)

				# Blorbs (C: case 81 falls through to 80, 80 to 79)
				79, 80, 81:
					if infoValue == 81 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 80 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BLORB")
						CK6_SpawnBlorb(x, y)

				# Ceilicks (C: case 84 falls through to 83, 83 to 82)
				82, 83, 84:
					if infoValue == 84 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 83 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_CEILICK")
						CK6_SpawnCeilick(x, y)

				# Bloogguards (C: case 87 falls through to 86, 86 to 85)
				85, 86, 87:
					if infoValue == 87 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 86 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BLOOGGUARD")
						CK6_SpawnBloogguard(x, y)

				# Grabbiter
				88:
					CK6_SpawnGrabbiter(x, y)

				# Satellite
				89:
					CK6_SpawnSatellite(x, y)

				# Story Items
				99:
					CA_MARKLUMP("LUMP_HOOK")
					CK6_SpawnRope(x, y)
				100:
					CA_MARKLUMP("LUMP_SANDWICH")
					CK6_SpawnSandwich(x, y)
				101:
					CA_MARKLUMP("LUMP_PASSCARD")
					CK6_SpawnPasscard(x, y)

				# Babobbas (C: case 104 falls through to 103, 103 to 102)
				102, 103, 104:
					if infoValue == 104 and ck_gameState.difficulty < D_Hard:
						pass
					elif infoValue >= 103 and ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BABOBBA")
						CK6_SpawnBabobba(x, y)

				# Rocketship
				105, 106:
					CK6_SpawnRocket(x, y, infoValue - 105)

	var obj: CK_object = ck_keenObj
	while obj != null:
		if obj.active != OBJ_ALWAYS_ACTIVE:
			obj.active = OBJ_INACTIVE
		obj = obj.next

	# (C's CA_MarkAllLumps(void) reads the lumpStarts/lumpEnds arrays itself)
	CA_MarkAllLumps(CK_VAR_GetIntArray("lumpStarts"), CK_VAR_GetIntArray("lumpEnds"))


func CK6_ToggleBigSwitch(obj: CK_object, dir: bool) -> void:
	# Replace switch tiles
	var ty: int = obj.clipRects.tileY2 if dir else obj.clipRects.tileY1 - 2
	var tx: int = obj.clipRects.tileX1 - 1

	var infoTile: int = CA_TilePtrAtPos(s16(tx + 1), s16(ty + 1), 2) # uint16_t *

	while CA_mapPlanes[2][infoTile] == 0:
		tx += 1
		infoTile += 1

	var fgTile: int = CA_TilePtrAtPos(s16(tx), s16(ty), 1) # uint16_t *

	var tile_array: PackedInt32Array = PackedInt32Array() # uint16_t[6]
	tile_array.resize(6)
	for y: int in range(3):
		for x: int in range(2):
			var fg: int = CA_mapPlanes[1][fgTile]
			tile_array[2 * y + x] = u16(fg + TI_ForeAnimTile(fg))
			fgTile += 1

		fgTile += CA_GetMapWidth() - 2

	RF_ReplaceTiles(tile_array, 0, 1, tx, ty, 2, 3)

	# Apply the switch effect
	infoTile = CA_TilePtrAtPos(s16(tx + 1), s16(ty + 1), 2)
	var destX: int = CA_mapPlanes[2][infoTile] >> 8
	var destY: int = CA_mapPlanes[2][infoTile] & 0xFF
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENOUTOFAMMO"))

	infoTile = CA_TilePtrAtPos(s16(destX), s16(destY), 2)

	var info: int = CA_mapPlanes[2][infoTile]
	if info >= 0x5B and info < 0x5B + 8:
		# Toggle a goplat arrow
		const infoPlaneInverses: PackedInt32Array = [2, 3, 0, 1, 6, 7, 4, 5] # static uint16_t[8]
		CA_mapPlanes[2][infoTile] = infoPlaneInverses[(info - 0x5B)] + 0x5B
	else:
		fgTile = CA_TilePtrAtPos(s16(destX), s16(destY), 1)
		var miscValue: int = TI_ForeMisc(CA_mapPlanes[1][fgTile]) & 0x7F

		if miscValue == MISCFLAG_ACTIVEZAPPER:
			var start: int = CA_TileAtPos(0, 0, 1)
			var mid: int = CA_TileAtPos(1, 0, 1)
			var end: int = CA_TileAtPos(2, 0, 1)

			RF_ReplaceTiles(PackedInt32Array([start]), 0, 1, destX, destY, 1, 1)
			destY += 1

			while TI_ForeMisc(CA_TileAtPos(s16(destX), s16(destY), 1)) == MISCFLAG_DEADLY:
				RF_ReplaceTiles(PackedInt32Array([mid]), 0, 1, destX, destY, 1, 1)
				destY += 1

			RF_ReplaceTiles(PackedInt32Array([end]), 0, 1, destX, destY, 1, 1)
		elif miscValue == MISCFLAG_INACTIVEZAPPER:
			var start: int = CA_TileAtPos(3, 0, 1)
			var mid: int = CA_TileAtPos(4, 0, 1)
			var end: int = CA_TileAtPos(5, 0, 1)

			RF_ReplaceTiles(PackedInt32Array([start]), 0, 1, destX, destY, 1, 1)
			destY += 1

			while TI_ForeMisc(CA_TileAtPos(s16(destX), s16(destY), 1)) != MISCFLAG_INACTIVEZAPPER:
				RF_ReplaceTiles(PackedInt32Array([mid]), 0, 1, destX, destY, 1, 1)
				destY += 1

			RF_ReplaceTiles(PackedInt32Array([end]), 0, 1, destX, destY, 1, 1)
		elif miscValue == MISCFLAG_BRIDGE:
			var y: int = destY
			while y < destY + 2:
				var x: int = destX - (0 if y == destY else 1)
				while x < CA_GetMapWidth():
					var currentTile: int = CA_TileAtPos(s16(x), s16(y), 1)
					if TI_ForeAnimTile(currentTile) == 0:
						break
					var newTile: int = u16(currentTile + TI_ForeAnimTile(currentTile))
					RF_ReplaceTiles(PackedInt32Array([newTile]), 0, 1, x, y, 1, 1)
					x += 1
				y += 1
		else:
			# Toggle a B block
			CA_mapPlanes[2][infoTile] = info ^ 0x1F


# Story item dialogues

## #define SOUND_STORYITEM 0x2D (unused: CK_SOUNDNUM stringifies its argument,
## so the variable file's SOUND_STORYITEM is what plays).
const SOUND_STORYITEM: int = 0x2D


func CK6_ShowGetSandwich() -> void:
	SD_WaitSoundDone()
	SD_PlaySound(CK_SOUNDNUM("SOUND_STORYITEM"))
	CA_UpLevel()
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 12)
	US_CPrint(CK_STRING("ck6_str_getSandwich"))
	VH_UpdateScreen()

	VL_DelayTics(30) # VW_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()
	CA_DownLevel()
	ck_gameState.ck6_sandwich = 1 # true


func CK6_ShowGetRope() -> void:
	SD_WaitSoundDone()
	SD_PlaySound(CK_SOUNDNUM("SOUND_STORYITEM"))
	CA_UpLevel()
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 12)
	US_CPrint(CK_STRING("ck6_str_getRope"))
	VH_UpdateScreen()

	VL_DelayTics(30) # VW_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()
	CA_DownLevel()
	ck_gameState.ck6_rope = 1 # true


func CK6_ShowGetPasscard() -> void:
	SD_WaitSoundDone()
	SD_PlaySound(CK_SOUNDNUM("SOUND_STORYITEM"))
	CA_UpLevel()
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 4)
	US_CPrint(CK_STRING("ck6_str_getPasscard"))
	VH_UpdateScreen()

	VL_DelayTics(30) # VW_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()
	CA_DownLevel()
	ck_gameState.ck6_passcard = 1 # true


# ===================================================================== ck6_map.c

# =========================================================================

func CK6_MapMiscFlagsCheck(obj: CK_object) -> void:
	if obj.user3 == 0:
		var tileX: int = obj.clipRects.tileXmid
		var tileY: int = RF_UnitToTile(obj.clipRects.unitY1 + (obj.clipRects.unitY2 - obj.clipRects.unitY1) / 2)
		var tile: int = CA_TileAtPos(s16(tileX), s16(tileY), 1) # uint16_t
		var miscValue: int = u8(TI_ForeMisc(tile)) # uint8_t

		if miscValue == MISCFLAG_TELEPORT:
			CK_AnimateMapTeleporter(tileX, tileY)


func CK6_Map_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK6_MapMiscFlagsCheck", &"CK6_MapMiscFlagsCheck")


# ===================================================================== ck6_obj1.c

# ck_infoplaneArrowsX / ck_infoplaneArrowsY (extern here) are declared in gal_ck.gd.

# =========================================================================

#

# Grabbiter

func CK6_SpawnGrabbiter(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.active = OBJ_ACTIVE
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.type = CT6_Grabbiter
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))

	if ck_gameState.ck6_sandwich == 2:
		CK_SetAction(obj, CK_GetActionByName("CK6_ACT_GrabbiterNapping0"))
	else:
		CK_SetAction(obj, CK_GetActionByName("CK6_ACT_GrabbiterHungry0"))


func CK6_GrabbiterCol(a: CK_object, b: CK_object) -> void:
	if ck_gameState.ck6_sandwich == 0:
		CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
		SD_PlaySound(CK_SOUNDNUM("SOUND_GRABBITER"))
		VL_FixRefreshBuffer()
		US_CenterWindow(26, 8)
		VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
		US_SetWindowW(US_GetWindowW() - 0x30)
		US_SetPrintY(US_GetPrintY() + 5)
		US_CPrint(CK_STRING("ck6_str_grabbiterHungry"))
		VH_UpdateScreen()
		SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
		VL_DelayTics(30) # VW_WaitVBL(30);
		IN_ClearKeysDown()
		IN_WaitButton()
		RF_ForceRefresh()
		ck_nextX = s16(-b.deltaPosX)
		ck_nextY = s16(-b.deltaPosY)
		b.yDirection = IN_motion_None
		b.xDirection = b.yDirection
		CK_PhysUpdateNormalObj(b)
	else:
		ck_gameState.ck6_sandwich = s16(ck_gameState.ck6_sandwich + 1)
		CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
		VL_FixRefreshBuffer()
		US_CenterWindow(26, 8)
		VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
		US_SetWindowW(US_GetWindowW() - 0x30)
		US_SetPrintY(US_GetPrintY() + 2)
		US_CPrint(CK_STRING("ck6_str_grabbiterFed"))
		VH_UpdateScreen()
		VL_DelayTics(30) # VW_WaitVBL(30);
		IN_ClearKeysDown()
		IN_WaitButton()
		CK_SetAction2(a, CK_GetActionByName("CK6_ACT_GrabbiterNapping0"))
		RF_ForceRefresh()


# Rocket ship
func CK6_SpawnRocket(tileX: int, tileY: int, dir: int) -> void:
	if ck_gameState.ck6_inRocket == dir:
		var obj: CK_object = CK_GetNewObj(false)
		obj.active = OBJ_ACTIVE
		obj.clipped = CLIP_not
		obj.zLayer = PRIORITIES - 1
		obj.type = CT6_Rocket
		obj.posX = u16(RF_TileToUnit(tileX))
		obj.posY = u16(RF_TileToUnit(tileY))
		CK_SetAction(obj, CK_GetActionByName("CK6_ACT_RocketSit0"))


func CK6_Rocket(obj: CK_object) -> void:
	obj.visible = true


func CK6_RocketCol(a: CK_object, b: CK_object) -> void:
	if ck_gameState.ck6_passcard == 0:
		CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
		VL_FixRefreshBuffer()
		US_CenterWindow(26, 8)
		VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
		US_SetWindowW(US_GetWindowW() - 0x30)
		US_SetPrintY(US_GetPrintY() + 5)
		US_CPrint(CK_STRING("ck6_str_rocketNoPasscard"))
		VH_UpdateScreen()
		SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
		VL_DelayTics(30) # VW_WaitVBL(30);
		IN_ClearKeysDown()
		IN_WaitButton()
		RF_ForceRefresh()
		ck_nextX = s16(-b.deltaPosX)
		ck_nextY = s16(-b.deltaPosY)
		b.yDirection = IN_motion_None
		b.xDirection = b.yDirection
		CK_PhysUpdateNormalObj(b)
	elif ck_gameState.ck6_passcard == 1:
		a.user1 = 0
		a.user2 = 0x100
		CK_SetAction2(a, CK_GetActionByName("CK6_ACT_RocketFly0"))
		b.posX = a.posX
		b.posY = u16(a.posY + CK_INT("CK6_RocketFlyYOffset", 0x100))
		b.clipped = CLIP_not
		CK_SetAction2(b, CK_GetActionByName("CK6_ACT_MapKeenRocketSit0"))
		SD_PlaySound(CK_SOUNDNUM("SOUND_ROCKETLAUNCH"))
		SD_WaitSoundDone()


func CK6_RocketFlyCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		b.posX = a.posX
		b.posY = u16(a.posY + 0x100)
		CK_SetAction2(b, b.currentAction)


## (As CK_GoPlatThink: C indexes the 8-entry arrow tables with user1, which
## the check below lets reach 8; C then reads past the array, here that index
## is an error.)
func CK6_RocketFly(obj: CK_object) -> void:
	if ck_nextX == 0 and ck_nextY == 0:
		if SD_SoundPlaying() == 0:
			SD_PlaySound(CK_SOUNDNUM("SOUND_ROCKETFLY"))

		var delta: int = s32(SD_GetSpriteSync() * CK_INT("CK6_RocketFlySpeed", 32)) # int

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

			# (the uint16_t cast is outside RF_UnitToTile here, unlike CK_GoPlatThink's)
			var tileX: int = u16(RF_UnitToTile(obj.posX + ck_nextX))
			var tileY: int = u16(RF_UnitToTile(obj.posY + ck_nextY))

			obj.user1 = s16(CA_TileAtPos(s16(tileX), s16(tileY), 2) - 0x5B)

			if (obj.user1 < 0) or (obj.user1 > 8):
				obj.posX = u16(obj.posX + ck_nextX)
				obj.posY = u16(obj.posY + ck_nextY)
				CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_RocketSit0"))

				ck_keenObj.posX = u16(RF_TileToUnit(tileX + 1) + 0x10)
				ck_keenObj.posY = u16(RF_TileToUnit(tileY + 1))
				ck_keenObj.type = CT_Player
				ck_keenObj.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_STAND_E"))
				ck_keenObj.clipped = CLIP_normal
				CK_SetAction(ck_keenObj, CK_GetActionByName("CK_ACT_MapKeenStart"))
				ck_gameState.ck6_inRocket = s16(ck_gameState.ck6_inRocket ^ 1)
				return

			delta = s32(delta - obj.user2)
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


# Cliff and Rope

func CK6_SpawnMapCliff(tileX: int, tileY: int, dir: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.active = OBJ_ACTIVE
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.type = CT6_MapCliff
	obj.clipRects.tileX2 = u16(tileX)
	obj.clipRects.tileX1 = obj.clipRects.tileX2
	obj.clipRects.tileY2 = u16(tileY)
	obj.clipRects.tileY1 = obj.clipRects.tileY2
	obj.user1 = s16(dir)
	obj.clipRects.unitX1 = u16(RF_TileToUnit(tileX))
	obj.posX = obj.clipRects.unitX1
	obj.clipRects.unitX2 = u16(obj.clipRects.unitX1 + RF_TileToUnit(CK_INT("CK6_MapCliffTileWidth", 1)))
	if dir != 0:
		obj.clipRects.unitY1 = u16(RF_TileToUnit(tileY + CK_INT("CK6_MapCliffTileHeight", 1)) - 1)
		obj.posY = obj.clipRects.unitY1
	else:
		obj.clipRects.unitY1 = u16(RF_TileToUnit(tileY))
		obj.posY = obj.clipRects.unitY1

	obj.clipRects.unitY2 = u16(obj.clipRects.unitY1 + 1)
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_MapCliff0"))

	if ck_gameState.ck6_rope == 2 and dir != 0:
		# (C shadows obj with a second declaration in this block)
		var rope: CK_object = CK_GetNewObj(false)
		rope.active = OBJ_ACTIVE
		rope.clipped = CLIP_not
		rope.zLayer = PRIORITIES - 4
		rope.type = CT_Friendly
		rope.posX = u16(RF_TileToUnit(tileX))
		rope.posY = u16(RF_TileToUnit(tileY + CK_INT("CK6_MapCliffTileHeight", 1)))
		CK_SetAction(rope, CK_GetActionByName("CK6_ACT_RopeOnMap0"))


func CK6_MapKeenThrowRope(obj: CK_object) -> void:
	var rope: CK_object = CK_GetNewObj(false)
	rope.active = OBJ_ACTIVE
	rope.clipped = CLIP_not
	rope.zLayer = PRIORITIES - 4
	rope.type = CT_Friendly
	rope.posX = u16(RF_TileToUnit(obj.clipRects.tileX2))
	rope.posY = u16(obj.posY + CK_INT("CK6_MapKeenRopeSpawnYOffset", -0x200))
	CK_SetAction(rope, CK_GetActionByName("CK6_ACT_RopeOnMap0"))
	obj.type = CT_Player
	obj.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_STAND_N"))


func CK6_MapKeenClimb(obj: CK_object) -> void:
	obj.user4 = s16(obj.user4 - 1)
	if obj.user4 == 0:
		if obj.yDirection == IN_motion_Down:
			obj.posY = u16(obj.posY + CK_INT("CK6_MapKeenRopeClimbSpeed", 0x30))
			obj.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_STAND_S"))
		else:
			obj.posY = u16(obj.posY - CK_INT("CK6_MapKeenRopeClimbSpeed", 0x30))
			obj.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_STAND_N"))
		obj.type = CT_Player
		CK_SetAction(obj, CK_GetActionByName("CK_ACT_MapKeenStart"))


func CK6_MapCliffCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		if ck_gameState.ck6_rope == 0:
			CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
			VL_FixRefreshBuffer()
			US_CenterWindow(26, 8)
			VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
			US_SetWindowW(US_GetWindowW() - 0x30)
			US_SetPrintY(US_GetPrintY() + 15)
			US_CPrint(CK_STRING("ck6_str_cliffNoRope"))
			VH_UpdateScreen()
			SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
			VL_DelayTics(30) # VW_WaitVBL(30);
			IN_ClearKeysDown()
			IN_WaitButton()
			RF_ForceRefresh()
			ck_nextX = s16(-b.deltaPosX)
			ck_nextY = s16(-b.deltaPosY)
			b.yDirection = IN_motion_None
			b.xDirection = b.yDirection
			CK_PhysUpdateNormalObj(b)
		elif ck_gameState.ck6_rope == 1:
			ck_gameState.ck6_rope = s16(ck_gameState.ck6_rope + 1)
			SD_PlaySound(CK_SOUNDNUM("SOUND_KEENTHROWROPE"))
			CK_SetAction2(b, CK_GetActionByName("CK6_ACT_MapKeenThrowRope0"))
			b.type = CT_Friendly
		elif ck_gameState.ck6_rope == 2:
			if a.user1 != 0:
				b.posY = u16(b.posY + CK_INT("CK6_MapKeenRopeClimbStartY", 0x40))
				b.user4 = s16(CK_INT("CK6_MapKeenRopeClimbDist", 6))
				b.yDirection = IN_motion_Down
			else:
				b.posY = u16(b.posY - CK_INT("CK6_MapKeenRopeClimbStartY", 0x40))
				b.user4 = s16(CK_INT("CK6_MapKeenRopeClimbDist", 6))
				b.yDirection = IN_motion_Up

			CK_SetAction(b, CK_GetActionByName("CK6_ACT_MapKeenClimbRope0"))
			b.type = CT_Friendly


# Satellite

func CK6_SpawnSatelliteLoading(tileX: int, tileY: int, dir: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.type = CT6_SatelliteLoading
	obj.clipRects.tileX2 = u16(tileX)
	obj.clipRects.tileX1 = obj.clipRects.tileX2
	obj.clipRects.tileY2 = u16(tileY)
	obj.clipRects.tileY1 = obj.clipRects.tileY2
	obj.user1 = s16((dir ^ 1) + 1)
	obj.clipRects.unitX1 = u16(RF_TileToUnit(tileX))
	obj.posX = obj.clipRects.unitX1
	obj.clipRects.unitX2 = u16(obj.clipRects.unitX1 + 0x100)
	obj.clipRects.unitY1 = u16(RF_TileToUnit(tileY))
	obj.posY = obj.clipRects.unitY1
	obj.clipRects.unitY2 = u16(obj.clipRects.unitY1 + 0x100)
	CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_SatelliteInvisible0"))


func CK6_SpawnSatellite(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.type = CT6_Satellite
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_Satellite0"))
	CA_SetTileAtPos(s16(tileX), s16(tileY), 2, 0x5B + 3)
	obj.user1 = 3
	obj.user2 = 0x100
	obj.user4 = 2


func CK6_Satellite(obj: CK_object) -> void:
	if ck_nextX == 0 and ck_nextY == 0:
		var user3: int = obj.user3 # int16_t
		if (user3 & 0xFF) == 0 and (user3 & 0xFF00) != 0:
			obj.user4 = s16(user3 / 256) # SAR instruction (C's / here: the low byte is 0, so exact)
		obj.user3 = s16(obj.user3 * 256)
		CK_GoPlatThink(obj)


func CK6_SatelliteCol(a: CK_object, b: CK_object) -> void:
	if b.currentAction == CK_GetActionByName("CK6_ACT_SatelliteInvisible0"):
		a.user3 = s16(a.user3 | b.user1)
	elif b.type == CT_Player:
		var var2: int = a.user3 / 256 # int (C's / truncates toward zero)
		if var2 == 0 or a.user4 == var2:
			if b.currentAction == CK_GetActionByName("CK6_ACT_KeenSatellite0"):
				b.posX = u16(a.posX + CK_INT("CK6_KeenSatelliteXOffset", 0xC0))
				b.posY = u16(a.posY + CK_INT("CK6_KeenSatelliteYOffset", 0x100))
				CK_SetAction2(b, b.currentAction)
		else:
			SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSATELLITE"))
			a.user4 = s16(var2)
			if ck_keenObj.currentAction == CK_GetActionByName("CK6_ACT_KeenSatellite0"):
				a = ck_keenObj.next
				while a != null:
					if a.type == CT6_SatelliteLoading and a.user1 == var2:
						b.posX = a.posX
						b.posY = a.posY
						b.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_STAND_N"))
						CK_SetAction2(ck_keenObj, CK_GetActionByName("CK_ACT_MapKeenStart"))
						b.clipped = CLIP_normal
						break
					a = a.next
			else:
				b.posX = u16(a.posX + CK_INT("CK6_KeenSatelliteXOffset", 0xC0))
				b.posY = u16(a.posY + CK_INT("CK6_KeenSatelliteYOffset", 0x100))
				b.clipped = CLIP_not
				CK_SetAction2(ck_keenObj, CK_GetActionByName("CK6_ACT_KeenSatellite0"))


func CK6_KeenSatelliteDraw(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX + CK_INT("CK6_SatelliteDrawXOffset", 0x40), obj.posY + CK_INT("CK6_SatelliteDrawYOffset", 0x80), CK_CHUNKNUM("SPR_MAPKEEN_HANG"), false, 1)


# Story Items
func CK6_SpawnSandwich(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.type = CT6_Sandwich
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_Sandwich0"))


func CK6_SpawnRope(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.type = CT6_Rope
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_Rope0"))


func CK6_SpawnPasscard(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 2
	obj.type = CT6_Passcard
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_Passcard0"))


func CK6_StoryItemCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		if a.type == CT6_Rope:
			ck_gameState.levelState = LS_Rope
		elif a.type == CT6_Passcard:
			ck_gameState.levelState = LS_Passcard
		elif a.type == CT6_Molly:
			ck_gameState.levelState = LS_Molly
		elif a.type == CT6_Sandwich:
			ck_gameState.levelState = LS_Sandwich


func CK6_SpawnMolly(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Molly
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_MollySpawnYOffset", -0x80))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_Molly0"))


# Go Plats

func CK6_GoPlatDraw(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)
	obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + CK_INT("CK6_GoplatGikXOffset", 0x100), obj.posY + 0x100, obj.user1 + CK_CHUNKNUM("SPR_PLATBIP1"), false, 0)


# Bloogs

func CK6_SpawnBloog(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Bloog
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BloogSpawnYOffset", -0x200))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BloogWalk0"))


func CK6_Bloog(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK6_BloogTurnChance", 0x20):
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left


func CK6_BloogCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_BloogStunned0"))


# ck6_smashScreenDistance and ck6_smashScreenOfs are declared in gal_ck.gd
# (ck_play.c uses them); CK6_Obj1_SetupFunctions gives ck6_smashScreenOfs its
# C contents (a constant table: nothing writes it).



func CK6_SpawnBloogguard(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Bloogguard
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BloogguardSpawnYOffset", -0x280))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	obj.user2 = s16(CK_INT("CK6_BloogguardHealth", 3))
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BloogguardWalk0"))


func CK6_BloogguardWalk(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK6_BloogguardTurnChance", 0x20):
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left

	if (obj.xDirection == IN_motion_Right and ck_keenObj.posX > obj.posX) or (obj.xDirection == IN_motion_Left and ck_keenObj.posX < obj.posX):
		if obj.clipRects.unitY2 == ck_keenObj.clipRects.unitY2:
			if US_RndT() < CK_INT("CK6_BloogguardClubChance", 0x20):
				obj.currentAction = CK_GetActionByName("CK6_ACT_BloogguardClub0")


func CK6_BloogguardSmash(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_BLOOGGUARDSMASH"))
	ck6_smashScreenDistance = s32(CK_INT("CK6_BloogguardSmashDist", 23))
	if ck_keenObj.topTI != 0:
		CK_SetAction2(ck_keenObj, CK_GetActionByName("CK6_ACT_keenStunned0"))


func CK6_BloogguardCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		a.user2 = s16(a.user2 - 1)
		if a.user2 == 0:
			CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_BloogguardStunned0"))
		else:
			a.user1 = 2
			a.visible = true
			CK_ShotHit(b)


## Also used for Fleex and Nospikes
func CK6_MultihitDraw(obj: CK_object) -> void:
	# Hit wall walking right; turn around and go left
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Hit wall walking left; turn around and go right
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Walked off of ledge; turn around
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX * 2)
		obj.xDirection = s16(-obj.xDirection)
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)

	if obj.user1 != 0:
		obj.user1 = s16(obj.user1 - 1)
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, true, obj.zLayer)
	else:
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Blooglets
func CK6_SpawnBlooglet(tileX: int, tileY: int, type: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Blooglet
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BloogletSpawnYOffset", -0x80))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	obj.user1 = s16(type)

	match type % 4:
		0:
			CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BloogletRRun0"))
		1:
			CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BloogletYRun0"))
		2:
			CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BloogletBRun0"))
		3:
			CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BloogletGRun0"))


## static const char *stunnedBloogletActions[]
const stunnedBloogletActions: PackedStringArray = [
	"CK6_ACT_BloogletRStunned0",
	"CK6_ACT_BloogletYStunned0",
	"CK6_ACT_BloogletBStunned0",
	"CK6_ACT_BloogletGStunned0",
]


# CK_ItemSpriteChunks (extern here) is declared in gal_act.gd.
func CK6_BloogletCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player and b.currentAction.collide != &"":
		ck_keenIgnoreVertClip = true
		CK_PhysPushX(b, a)
		ck_keenIgnoreVertClip = false
	elif b.type == CT_Stunner:
		var color: int = a.user1 & 3
		if a.user1 > 3:
			var gem: CK_object = CK_GetNewObj(false)
			gem.clipped = CLIP_normal
			gem.zLayer = PRIORITIES - 2
			gem.type = CT6_Item
			gem.posX = a.posX
			gem.posY = a.posY
			gem.yDirection = IN_motion_Up
			gem.velY = s16(CK_INT("CK6_BloogletGemYVel", -40))
			gem.user1 = s16(color)
			gem.gfxChunk = u16(CK_LookupChunk(CK_ItemSpriteChunks[color]))
			gem.user2 = s16(gem.gfxChunk)
			gem.user3 = s16(gem.user2 + 2)
			CK_SetAction(gem, CK_GetActionByName("CK_ACT_fallingitem"))
			SD_PlaySound(CK_SOUNDNUM("SOUND_BLOOGLETGEM"))

		CK_StunCreature(a, b, CK_GetActionByName(stunnedBloogletActions[color]))


## Setup all of the functions in this file.
## (Also gives gal_ck.gd's ck6_smashScreenOfs the contents C initializes it with.)
func CK6_Obj1_SetupFunctions() -> void:
	CK_ACT_AddColFunction("CK6_GrabbiterCol", &"CK6_GrabbiterCol")

	CK_ACT_AddFunction("CK6_Rocket", &"CK6_Rocket")
	CK_ACT_AddColFunction("CK6_RocketCol", &"CK6_RocketCol")
	CK_ACT_AddColFunction("CK6_RocketFlyCol", &"CK6_RocketFlyCol")
	CK_ACT_AddFunction("CK6_RocketFly", &"CK6_RocketFly")

	CK_ACT_AddFunction("CK6_MapKeenThrowRope", &"CK6_MapKeenThrowRope")
	CK_ACT_AddFunction("CK6_MapKeenClimb", &"CK6_MapKeenClimb")
	CK_ACT_AddColFunction("CK6_MapCliffCol", &"CK6_MapCliffCol")

	CK_ACT_AddFunction("CK6_Satellite", &"CK6_Satellite")
	CK_ACT_AddColFunction("CK6_SatelliteCol", &"CK6_SatelliteCol")
	CK_ACT_AddFunction("CK6_KeenSatelliteDraw", &"CK6_KeenSatelliteDraw")

	CK_ACT_AddColFunction("CK6_StoryItemCol", &"CK6_StoryItemCol")

	CK_ACT_AddFunction("CK6_GoPlatDraw", &"CK6_GoPlatDraw")

	CK_ACT_AddFunction("CK6_Bloog", &"CK6_Bloog")
	CK_ACT_AddColFunction("CK6_BloogCol", &"CK6_BloogCol")

	CK_ACT_AddFunction("CK6_BloogguardWalk", &"CK6_BloogguardWalk")
	CK_ACT_AddFunction("CK6_BloogguardSmash", &"CK6_BloogguardSmash")
	CK_ACT_AddColFunction("CK6_BloogguardCol", &"CK6_BloogguardCol")
	CK_ACT_AddFunction("CK6_MultihitDraw", &"CK6_MultihitDraw")

	CK_ACT_AddColFunction("CK6_BloogletCol", &"CK6_BloogletCol")


# ===================================================================== ck6_obj2.c

# =========================================================================

# Nospikes
func CK6_SpawnNospike(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Nospike
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_NospikeSpawnYOffset", -0x180))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_NospikeSit0"))
	obj.user4 = s16(CK_INT("CK6_NospikeHealth", 4))


func CK6_NospikeWalk(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK6_NospikeSitChance", 0x10):
		obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeSit0")
	elif obj.clipRects.unitY2 == ck_keenObj.clipRects.unitY2 and US_RndT() <= CK_INT("CK6_NospikeChargeChance", 0x20):
		obj.xDirection = IN_motion_Right if ck_keenObj.posX > obj.posX else IN_motion_Left
		obj.user1 = 0
		obj.user2 = 1

		if obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk0"):
			obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeCharge1")
		elif obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk1"):
			obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeCharge2")
		elif obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk2"):
			obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeCharge3")
		elif obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk3"):
			obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeCharge0")


func CK6_NospikeCharge(obj: CK_object) -> void:
	if obj.user1 == 0:
		if ((ck_keenObj.clipRects.unitY2 != obj.clipRects.unitY2 or (obj.xDirection == IN_motion_Left and obj.posX < ck_keenObj.posX) or (obj.xDirection == IN_motion_Right and obj.posX > ck_keenObj.posX)) and US_RndT() < CK_INT("CK6_NospikeGiveUpChance", 0x8)) or not CK_ObjectVisible(obj):
			# Stop charging if nospike gets bored, or goes off screen
			obj.user2 = 0
			if obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeCharge0"):
				obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeWalk1")
			elif obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeCharge1"):
				obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeWalk2")
			elif obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeCharge2"):
				obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeWalk3")
			elif obj.currentAction == CK_GetActionByName("CK6_ACT_NospikeCharge3"):
				obj.currentAction = CK_GetActionByName("CK6_ACT_NospikeWalk0")


func CK6_NospikeCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		a.user4 = s16(a.user4 - 1)
		if a.user4 == 0:
			CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_NospikeStunned0"))
			a.velY = s16(CK_INT("CK6_NospikeDeathHopYVel", -24))
		else:
			a.xDirection = IN_motion_Left if ck_keenObj.posX < a.posX else IN_motion_Right
			a.user2 = s16(a.user2 | 0x400)
			a.visible = true

			if a.currentAction == CK_GetActionByName("CK6_ACT_NospikeSit0") or a.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk0"):
				CK_SetAction2(a, CK_GetActionByName("CK6_ACT_NospikeCharge1"))
			elif a.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk1"):
				CK_SetAction2(a, CK_GetActionByName("CK6_ACT_NospikeCharge2"))
			elif a.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk2"):
				CK_SetAction2(a, CK_GetActionByName("CK6_ACT_NospikeCharge3"))
			elif a.currentAction == CK_GetActionByName("CK6_ACT_NospikeWalk3"):
				CK_SetAction2(a, CK_GetActionByName("CK6_ACT_NospikeCharge0"))

			CK_ShotHit(b)
	elif b.type == CT6_Nospike:
		# Two charging nospikes will stun each other if they collide head on
		if (a.user2 & 0xFF) != 0 and (b.user2 & 0xFF) != 0 and a.xDirection != b.xDirection:
			a.user3 = 0
			a.user2 = 0
			a.user1 = 0
			b.user3 = 0
			b.user2 = 0
			b.user1 = 0
			b.user4 = s16(a.type)
			a.user4 = b.user4
			CK_SetAction2(a, CK_GetActionByName("CK6_ACT_NospikeStunned0"))
			CK_SetAction2(b, CK_GetActionByName("CK6_ACT_NospikeStunned0"))
			SD_PlaySound(CK_SOUNDNUM("SOUND_NOSPIKECOLLIDE"))
			b.type = CT6_StunnedCreature
			a.type = b.type
			b.velY = s16(CK_INT("CK6_NospikeDeathHopYVel", -24))
			a.velY = b.velY


func CK6_NospikeFall(obj: CK_object) -> void:
	obj.user3 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user3)


func CK6_NospikeFallDraw(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	# Place the question mark
	obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + CK_INT("CK6_NospikeQuestionXOffset", 0x100), obj.posY + CK_INT("CK6_NospikeQuestionYOffset", -0x80), CK_CHUNKNUM("SPR_NOSPIKE_QUESTIONMARK"), false, 3)


func CK6_NospikeFallDraw2(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	if obj.topTI != 0:
		# (C quirk, kept: user1 and user2 get user3, the question mark's
		# sprite offset, not 0 as CK_StunCreature would give them)
		obj.user2 = obj.user3
		obj.user1 = obj.user2
		obj.user4 = s16(obj.type)
		CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_NospikeStunned0"))
		SD_PlaySound(CK_SOUNDNUM("SOUND_NOSPIKECOLLIDE"))
		obj.type = CT6_StunnedCreature
		obj.velY = s16(CK_INT("CK6_NospikeDeathHopYVel", -24))


func CK6_NospikeChargeDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		obj.user1 = 0
		if obj.rightTI != 0 or obj.leftTI != 0:
			obj.posX = u16(obj.posX - obj.xDirection * 128)
			CK_SetAction(obj, CK_GetActionByName("CK6_ACT_NospikeSit0")) # Not Setaction2
			obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)
			obj.user2 = 0
			return
	else:
		obj.user1 = s16(obj.user1 + 1)
		if obj.user1 == CK_INT("CK6_NospikeAirHangTime", 6):
			CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_NospikeFall0"))

	if (obj.user2 & 0xFF00) != 0:
		obj.user2 = s16(obj.user2 - 0x100)
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, true, obj.zLayer)
	else:
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Giks
func CK6_SpawnGik(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Gik
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_GikWalk0"))


func CK6_GikWalk(obj: CK_object) -> void:
	if obj.topTI != 9:
		var dx: int = ck_keenObj.posX - obj.posX # int

		var dy: int = obj.clipRects.unitY2 - ck_keenObj.clipRects.unitY2 # int
		if dy >= CK_INT("CK6_GikJumpKeenYMin", 0) and dy <= CK_INT("CK6_GikJumpKeenYMax", 0x400):
			obj.xDirection = IN_motion_Left if dx < 0 else IN_motion_Right
			if dx >= -CK_INT("CK6_GikJumpKeenXRadiusMax", 0x700) and dx <= CK_INT("CK6_GikJumpKeenXRadiusMax", 0x700) and (dx <= -CK_INT("CK6_GikJumpKeenXRadiusMin", 0x100) or dx >= CK_INT("CK6_GikJumpKeenXRadiusMin", 0x100)):
				obj.velX = s16(-CK_INT("CK6_GikJumpXVel", 40) if dx < 0 else CK_INT("CK6_GikJumpXVel", 40))
				obj.velY = s16(CK_INT("CK6_GikJumpYVel", -28))
				obj.currentAction = CK_GetActionByName("CK6_ACT_GikJump0")
				SD_PlaySound(CK_SOUNDNUM("SOUND_GIKJUMP"))


## static uint16_t gikslides_r[] / gikslides_l[]
const gikslides_r: PackedInt32Array = [0, 7, 0, 0, 0, 3, 3, 1]
const gikslides_l: PackedInt32Array = [0, 7, 3, 3, 1, 0, 0, 0]


func CK6_GikSlide(obj: CK_object) -> void:
	CK_PhysGravityHigh(obj)

	var topflag: int = obj.topTI & 7
	var di: int = gikslides_r[topflag] if obj.xDirection == IN_motion_Right else gikslides_l[topflag] # uint16_t
	if obj.velX == 0 and obj.topTI != 0:
		# Hit a wall and on the ground
		obj.currentAction = CK_GetActionByName("CK6_ACT_GikEndSlide0")
	else:
		# Slide to a halt
		var lastTimeCount: int = s32(SD_GetLastTimeCount()) # int32_t
		var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync()) # int32_t
		while tickCount < lastTimeCount:
			if di != 0:
				var ddi: int = di # uint32_t
				# (ddi & (uint32_t)tickCount: the low bits are the same in two's complement)
				if (ddi & tickCount) == 0:
					# (velX < 0 && ++velX == 0) || (velX > 0 && --velX == 0)
					var stop: bool = false
					if obj.velX < 0:
						obj.velX = s16(obj.velX + 1)
						stop = obj.velX == 0
					if not stop and obj.velX > 0:
						obj.velX = s16(obj.velX - 1)
						stop = obj.velX == 0
					if stop:
						obj.currentAction = CK_GetActionByName("CK6_ACT_GikEndSlide0")
						break
			ck_nextX = s16(ck_nextX + obj.velX)
			tickCount = s32(tickCount + 1)


func CK6_GikJumpDraw(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0

	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		obj.velY = 0
		SD_PlaySound(CK_SOUNDNUM("SOUND_GIKLAND"))
		CK_SetAction2(obj, obj.currentAction.next)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK6_GikSlideDraw(obj: CK_object) -> void:
	if (obj.rightTI != 0 and obj.velX < 0) or (obj.leftTI != 0 and obj.velX > 0):
		obj.velX = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Orbatrices
func CK6_SpawnOrbatrix(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Orbatrix
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit((tileY)) + CK_INT("CK6_OrbatrixSpawnYOffset", -0x180))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	obj.user4 = 1
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_OrbatrixFloat0"))


func CK6_OrbatrixFloat(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK6_OrbatrixIdleChance", 0x20):
		obj.currentAction = CK_GetActionByName("CK6_ACT_OrbatrixUncurl2")
	elif obj.clipRects.unitY2 == ck_keenObj.clipRects.unitY2:
		var dx: int = s16(ck_keenObj.posX - obj.posX) # int16_t
		obj.xDirection = IN_motion_Left if dx < 0 else IN_motion_Right
		if dx > -CK_INT("CK6_OrbatrixCurlKeenXRadius", 0x500) and dx < CK_INT("CK6_OrbatrixCurlKeenXRadius", 0x500):
			obj.currentAction = CK_GetActionByName("CK6_ACT_OrbatrixCurl0")


func CK6_OrbatrixCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_ShotHit(b)
		CK_SetAction2(a, CK_GetActionByName("CK6_ACT_OrbatrixUncurl2"))


func CK6_OrbatrixDraw(obj: CK_object) -> void:
	obj.posY = u16(obj.posY - obj.user3)
	CK_BasicDrawFunc2(obj)
	obj.posY = u16(obj.posY + obj.user3)

	obj.user3 = s16(obj.user3 + obj.user4 * SD_GetSpriteSync() * 4)

	if obj.user3 > CK_INT("CK6_OrbatrixMaxFloatYVel", 0x80):
		obj.user3 = s16(CK_INT("CK6_OrbatrixMaxFloatYVel", 0x80))
		obj.user4 = -1
	elif obj.user3 < -CK_INT("CK6_OrbatrixMaxFloatYVel", 0x80):
		obj.user3 = s16(-CK_INT("CK6_OrbatrixMaxFloatYVel", 0x80))
		obj.user4 = 1


func CK6_OrbatrixBounceDraw(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	if obj.topTI != 0:
		obj.velY = s16(-obj.velY)

	if obj.topTI != 0 or obj.leftTI != 0 or obj.rightTI != 0:
		obj.velX = s16(-obj.velX)
		SD_PlaySound(CK_SOUNDNUM("SOUND_ORBATRIXBOUNCE"))

		if obj.topTI != 0:
			obj.user1 = s16(obj.user1 - 1)
			if obj.user1 == 0:
				CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_OrbatrixUncurl0"))
				obj.user2 = s16(CK_INT("CK6_OrbatrixRiseHeight", 0x180))


func CK6_OrbatrixCurl(obj: CK_object) -> void:
	if obj.user3 >= CK_INT("CK6_OrbatrixBounceMinYVel", 0x10):
		obj.velX = s16(obj.xDirection * CK_INT("CK6_OrbatrixBounceXVel", 60))
		obj.velY = s16(CK_INT("CK6_OrbatrixBounceYVel", -32))
		obj.posY = u16(obj.posY - obj.user3)
		obj.user1 = s16(CK_INT("CK6_OrbatrixBounceCount", 5))
		obj.currentAction = obj.currentAction.next

	obj.visible = true


func CK6_OrbatrixUncurlThink(obj: CK_object) -> void:
	ck_nextY = s16(SD_GetSpriteSync() * CK_INT("CK6_OrbatrixRiseYVel", -8))
	obj.user2 = s16(obj.user2 + ck_nextY)
	if obj.user2 <= 0:
		ck_nextY = s16(ck_nextY - obj.user2)
		obj.currentAction = obj.currentAction.next


func CK6_OrbatrixCol2(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		CK_ShotHit(b)
		a.velX = 0


# Bips

func CK6_BipWalk(obj: CK_object) -> void:
	if obj.clipRects.unitY2 == ck_keenObj.clipRects.unitY2:
		if ck_keenObj.clipRects.unitX1 - CK_INT("CK6_BipTurnRadius", 0x40) < obj.clipRects.unitX2:
			obj.xDirection = IN_motion_Right

		if ck_keenObj.clipRects.unitX2 + CK_INT("CK6_BipTurnRadius", 0x40) > obj.clipRects.unitX1:
			obj.xDirection = IN_motion_Left
	else:
		if US_RndT() < CK_INT("CK6_BipStandChance", 0x10):
			obj.xDirection = s16(-obj.xDirection)
			obj.currentAction = CK_GetActionByName("CK6_ACT_BipStand0")


func CK6_BipCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player and b.deltaPosY == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_BIPSQUISH"))
		a.type = CT_Friendly
		CK_SetAction2(a, CK_GetActionByName("CK6_ACT_BipSquished0"))


# Bipship
func CK6_SpawnBipship(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Bipship
	obj.active = OBJ_ACTIVE
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BipshipSpawnYOffset", -0x180))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.velX = s16(obj.xDirection * CK_INT("CK6_BipshipInitXVel", 20))
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BipshipFly0"))


func CK6_BipShotDraw(obj: CK_object) -> void:
	if obj.topTI != 0 or obj.bottomTI != 0 or obj.rightTI != 0 or obj.leftTI != 0:
		CK_RemoveObj(obj)
	else:
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK6_BipshipTurn(obj: CK_object) -> void:
	CK_PhysAccelHorz(obj, obj.xDirection, CK_INT("CK6_BipshipXAccel", 20))


func CK6_BipshipFly(obj: CK_object) -> void:
	CK_PhysAccelHorz(obj, obj.xDirection, CK_INT("CK6_BipshipXAccel", 20))
	var xdir: int = obj.xDirection # int
	var ycheck: int = u16(ck_keenObj.clipRects.unitY2 + CK_INT("CK6_BipshipSearchYOffset", 0x100) - obj.clipRects.unitY2) # uint16_t
	if ycheck <= CK_INT("CK6_BipshipSearchYDiameter", 0x200):
		# Fire!!
		xdir = IN_motion_Left if (ck_keenObj.posX < obj.posX) else IN_motion_Right
		if obj.xDirection == xdir and US_RndT() < SD_GetSpriteSync() * 4:
			SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSHOOT"))
			var shot: CK_object = CK_GetNewObj(true)
			shot.type = CT6_EnemyShot
			shot.active = OBJ_EXISTS_ONLY_ONSCREEN
			shot.zLayer = PRIORITIES - 3
			if obj.xDirection == IN_motion_Right:
				shot.posX = u16(obj.posX + CK_INT("CK6_BipshipShotXOffsetRight", 0x100))
				shot.velX = s16(CK_INT("CK6_BipshipShotXVel", 64))
			else:
				shot.posX = u16(obj.posX + CK_INT("CK6_BipshipShotXOffsetLeft", 0))
				shot.velX = s16(-CK_INT("CK6_BipshipShotXVel", 64))

			shot.posY = u16(obj.posY + CK_INT("CK6_BipshipShotYOffset", 0xA0))
			shot.velY = s16(CK_INT("CK6_BipshipShotYVel", 16))
			CK_SetAction(shot, CK_GetActionByName("CK6_ACT_BipShot0"))

	var startx: int = obj.clipRects.tileXmid + 4 * xdir
	var y: int = obj.clipRects.tileY1
	var tile: int = CA_TilePtrAtPos(s16(startx), s16(y), 1) # uint16_t *

	# (C's goto checkTurn: a wall flips xdir and skips the ledge check)
	var gotoCheckTurn: bool = false
	while y <= obj.clipRects.tileY2:
		if TI_ForeLeft(CA_mapPlanes[1][tile]) != 0 or TI_ForeRight(CA_mapPlanes[1][tile]) != 0:
			xdir = -xdir
			gotoCheckTurn = true
			break
		y += 1
		tile += CA_GetMapWidth()

	if not gotoCheckTurn:
		# And turn around at ledge-ends
		if TI_ForeTop(CA_mapPlanes[1][tile]) == 0:
			xdir = -xdir

	# checkTurn:

	if obj.xDirection != xdir:
		obj.xDirection = s16(xdir)
		CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_BipshipTurn0"))


func CK6_BipshipCrash(obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_BIPSHIPCRASH"))

	# Spawn smoke
	var smoke: CK_object = CK_GetNewObj(true)
	smoke.type = CT_Friendly
	smoke.active = OBJ_ACTIVE
	smoke.zLayer = PRIORITIES - 2
	smoke.posX = obj.posX
	smoke.posY = u16(obj.posY + CK_INT("CK6_BipshipCrashSmokeYOffset", -0x180))
	CK_SetAction(smoke, CK_GetActionByName("CK6_ACT_BipshipSmoke0"))
	smoke.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left

	var bip: CK_object = CK_GetNewObj(true)
	bip.type = CT6_Bip
	bip.active = OBJ_ACTIVE
	bip.zLayer = PRIORITIES - 4
	bip.posX = obj.posX
	bip.posY = u16(obj.posY + CK_INT("CK6_BipCrashYOffset", -0x80))
	bip.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	CK_SetAction(bip, CK_GetActionByName("CK6_ACT_BipStand0"))


func CK6_BipshipCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_ShotHit(b)
		CK_SetAction2(a, CK_GetActionByName("CK6_ACT_BipshipHit0"))


# Flects

func CK6_SpawnFlect(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Flect
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_FlectSpawnYOffset", -0x100))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_FlectWalk0"))


func CK6_FlectTurn(obj: CK_object) -> void:
	if ck_keenObj.posX < obj.posX:
		if obj.xDirection == IN_motion_Left:
			obj.currentAction = CK_GetActionByName("CK6_ACT_FlectWalk0")
		else:
			obj.currentAction = CK_GetActionByName("CK6_ACT_FlectTurn1")
			obj.xDirection = IN_motion_Left
	else:
		if obj.xDirection == IN_motion_Right:
			obj.currentAction = CK_GetActionByName("CK6_ACT_FlectWalk0")
		else:
			obj.currentAction = CK_GetActionByName("CK6_ACT_FlectTurn1")
			obj.xDirection = IN_motion_Right


func CK6_FlectWalk(obj: CK_object) -> void:
	if ck_keenObj.posX < obj.posX and obj.xDirection == IN_motion_Right:
		# if (obj->xDirection != IN_motion_Left) // Always true
		obj.currentAction = CK_GetActionByName("CK6_ACT_FlectTurn1")

		obj.xDirection = IN_motion_Left

	if ck_keenObj.posX > obj.posX and obj.xDirection == IN_motion_Left:
		# if (obj->xDirection != IN_motion_Right) // Always true
		obj.currentAction = CK_GetActionByName("CK6_ACT_FlectTurn1")

		obj.xDirection = IN_motion_Right

	if US_RndT() < CK_INT("CK6_FlectTurnChance", 0x20):
		obj.currentAction = CK_GetActionByName("CK6_ACT_FlectTurn0")


func CK6_FlectCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_PhysPushX(b, a)
	elif b.type == CT_Stunner:
		if b.xDirection == IN_motion_None:
			CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_FlectStunned0"))
		elif a.xDirection != b.xDirection:
			b.xDirection = a.xDirection
			b.user4 = 1 # Shot is hazardous to keen now
			SD_PlaySound(CK_SOUNDNUM("SOUND_FLECTSHOT"))


func CK6_FlectDraw(obj: CK_object) -> void:
	# Hit wall walking right; turn around and go left
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Hit wall walking left; turn around and go right
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Walked off of ledge; turn around
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = s16(-obj.xDirection)
		CK_SetAction2(obj, obj.currentAction)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


## Setup all of the functions in this file.
func CK6_Obj2_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK6_NospikeWalk", &"CK6_NospikeWalk")
	CK_ACT_AddFunction("CK6_NospikeCharge", &"CK6_NospikeCharge")
	CK_ACT_AddColFunction("CK6_NospikeCol", &"CK6_NospikeCol")
	CK_ACT_AddFunction("CK6_NospikeFall", &"CK6_NospikeFall")
	CK_ACT_AddFunction("CK6_NospikeFallDraw", &"CK6_NospikeFallDraw")
	CK_ACT_AddFunction("CK6_NospikeFallDraw2", &"CK6_NospikeFallDraw2")
	CK_ACT_AddFunction("CK6_NospikeChargeDraw", &"CK6_NospikeChargeDraw")

	CK_ACT_AddFunction("CK6_GikWalk", &"CK6_GikWalk")
	CK_ACT_AddFunction("CK6_GikSlide", &"CK6_GikSlide")
	CK_ACT_AddFunction("CK6_GikJumpDraw", &"CK6_GikJumpDraw")
	CK_ACT_AddFunction("CK6_GikSlideDraw", &"CK6_GikSlideDraw")

	CK_ACT_AddFunction("CK6_OrbatrixFloat", &"CK6_OrbatrixFloat")
	CK_ACT_AddColFunction("CK6_OrbatrixCol", &"CK6_OrbatrixCol")
	CK_ACT_AddFunction("CK6_OrbatrixDraw", &"CK6_OrbatrixDraw")
	CK_ACT_AddFunction("CK6_OrbatrixBounceDraw", &"CK6_OrbatrixBounceDraw")
	CK_ACT_AddFunction("CK6_OrbatrixCurl", &"CK6_OrbatrixCurl")
	CK_ACT_AddFunction("CK6_OrbatrixUncurlThink", &"CK6_OrbatrixUncurlThink")
	CK_ACT_AddColFunction("CK6_OrbatrixCol2", &"CK6_OrbatrixCol2")

	CK_ACT_AddFunction("CK6_BipWalk", &"CK6_BipWalk")
	CK_ACT_AddColFunction("CK6_BipCol", &"CK6_BipCol")
	CK_ACT_AddFunction("CK6_BipShotDraw", &"CK6_BipShotDraw")
	CK_ACT_AddFunction("CK6_BipshipTurn", &"CK6_BipshipTurn")
	CK_ACT_AddFunction("CK6_BipshipFly", &"CK6_BipshipFly")
	CK_ACT_AddFunction("CK6_BipshipCrash", &"CK6_BipshipCrash")
	CK_ACT_AddColFunction("CK6_BipshipCol", &"CK6_BipshipCol")

	CK_ACT_AddFunction("CK6_FlectTurn", &"CK6_FlectTurn")
	CK_ACT_AddFunction("CK6_FlectWalk", &"CK6_FlectWalk")
	CK_ACT_AddColFunction("CK6_FlectCol", &"CK6_FlectCol")
	CK_ACT_AddFunction("CK6_FlectDraw", &"CK6_FlectDraw")


# ===================================================================== ck6_obj3.c

# Fleex
func CK6_SpawnFleex(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Fleex
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_FleexSpawnYOffset", -0x280))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_FleexWalk0"))
	obj.user2 = s16(CK_INT("CK6_FleexHealth", 4))


func CK6_FleexWalk(obj: CK_object) -> void:
	if ck_keenObj.deltaPosX == 0 and obj.user1 == 0:
		obj.currentAction = CK_GetActionByName("CK6_ACT_FleexSearch0")
	else:
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left


func CK6_FleexSearch(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left


func CK6_FleexCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()

	if b.type == CT_Stunner:
		a.user2 = s16(a.user2 - 1)
		if a.user2 != 0:
			a.user1 = 2
			a.visible = true
			CK_ShotHit(b)
			if a.currentAction == CK_GetActionByName("CK6_ACT_FleexSearch0") or a.currentAction == CK_GetActionByName("CK6_ACT_FleexSearch1"):
				a.xDirection = IN_motion_Right if a.posX < ck_keenObj.posX else IN_motion_Left
				CK_SetAction2(a, CK_GetActionByName("CK6_ACT_FleexWalk0"))
		else:
			CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_FleexStunned0"))
			a.velY = s16(CK_INT("CK6_FleexDeathHopYVel", -20))


# Bobbas

func CK6_SpawnBobba(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Bobba
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BobbaSpawnYOffset", -0x200))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BobbaJump0"))


func CK6_BobbaFireball(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_BOBBAFIREBALL"))


func CK6_Bobba(obj: CK_object) -> void:
	obj.user1 = s16(obj.user1 + 1)
	if obj.user1 == CK_INT("CK6_BobbaHopsPerShot", 3):
		# Shoot every third hop
		obj.user1 = 0
		var shot: CK_object = CK_GetNewObj(true)
		shot.active = OBJ_EXISTS_ONLY_ONSCREEN
		shot.type = CT6_EnemyShot
		shot.posY = u16(obj.posY + CK_INT("CK6_BobbaShotYOffset", 0xB0))
		shot.xDirection = obj.xDirection
		shot.posX = u16(obj.posX + CK_INT("CK6_BobbaShotXOffsetRight", 0x100) if obj.xDirection == IN_motion_Right else obj.posX + CK_INT("CK6_BobbaShotXOffsetLeft", 0xB0))
		CK_SetAction(shot, CK_GetActionByName("CK6_ACT_BobbaTwinkle0"))
		shot.zLayer = PRIORITIES - 2

		obj.currentAction = CK_GetActionByName("CK6_ACT_BobbaShoot0")
	else:
		# Turn around if there's no where to jump
		var tile: int = CA_TilePtrAtPos(s16(obj.clipRects.tileXmid), s16(obj.clipRects.tileY2 + 1), 1) # uint16_t *
		for _i: int in range(4):
			var w: int = CA_GetMapWidth()
			if TI_ForeTop(CA_mapPlanes[1][tile]) == 0 and TI_ForeTop(CA_mapPlanes[1][tile - w]) == 0 and TI_ForeTop(CA_mapPlanes[1][tile + w]) == 0:
				obj.xDirection = s16(-obj.xDirection)
				break

			tile += obj.xDirection

		obj.velX = s16(obj.xDirection * CK_INT("CK6_BobbaHopXVel", 32))
		obj.velY = s16(CK_INT("CK6_BobbaHopYVel", -32))
		SD_PlaySound(CK_SOUNDNUM("SOUND_BOBBAJUMP"))


func CK6_BobbaCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		CK_ShotHit(b)
		a.xDirection = s16(-a.xDirection)


func CK6_BobbaJumpDraw(obj: CK_object) -> void:
	if obj.rightTI != 0:
		obj.xDirection = IN_motion_Right
		obj.velX = s16(-obj.velX)
	elif obj.leftTI != 0:
		obj.xDirection = IN_motion_Left
		obj.velX = s16(-obj.velX)

	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_BOBBALAND"))
		CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_BobbaStand0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK6_BobbaFireballDraw(obj: CK_object) -> void:
	if obj.topTI != 0 or obj.bottomTI != 0 or obj.rightTI != 0 or obj.leftTI != 0:
		CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_BobbaFireballHits0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Babobbas

func CK6_SpawnBabobba(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Babobba
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BabobbaSpawnYOffset", -0x200))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_BabobbaJump0"))


func CK6_BabobbaSit(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK6_BabobbaNapChance", 4):
		# Nap time
		obj.user1 = 0
		obj.currentAction = CK_GetActionByName("CK6_ACT_BabobbaNap0")
	else:
		obj.user1 = s16(obj.user1 + 1)
		if obj.user1 == CK_INT("CK6_BabobbaHopsPerShot", 3):
			# Shoot every third hop
			obj.user1 = 0
			var shot: CK_object = CK_GetNewObj(true)
			shot.active = OBJ_EXISTS_ONLY_ONSCREEN
			shot.type = CT6_EnemyShot
			shot.posY = u16(obj.posY + CK_INT("CK6_BabobbaShotYOffset", 0x40))
			shot.xDirection = obj.xDirection
			shot.posX = u16(obj.posX + CK_INT("CK6_BabobbaShotXOffsetRight", 0x100) if obj.xDirection == IN_motion_Right else obj.posX + CK_INT("CK6_BabobbaShotXOffsetLeft", 0xB0))
			shot.velX = s16(shot.xDirection * CK_INT("CK6_BabobbaShotXVel", 32))
			CK_SetAction(shot, CK_GetActionByName("CK6_ACT_BabobbaShotStart0"))
			shot.zLayer = PRIORITIES - 2

			obj.currentAction = CK_GetActionByName("CK6_ACT_BabobbaSit1")
		else:
			# Turn around if there's no where to jump
			var tile: int = CA_TilePtrAtPos(s16(obj.clipRects.tileXmid), s16(obj.clipRects.tileY2 + 1), 1) # uint16_t *
			for _i: int in range(4):
				var w: int = CA_GetMapWidth()
				if TI_ForeTop(CA_mapPlanes[1][tile]) == 0 and TI_ForeTop(CA_mapPlanes[1][tile - w]) == 0 and TI_ForeTop(CA_mapPlanes[1][tile + w]) == 0:
					obj.xDirection = s16(-obj.xDirection)
					break

				tile += obj.xDirection

			obj.velX = s16(obj.xDirection * CK_INT("CK6_BabobbaHopXVel", 24))
			obj.velY = s16(CK_INT("CK6_BabobbaHopYVel", -32))


func CK6_BabobbaCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_BabobbaStunned0"))


func CK6_BabobbaNapCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK6_ACT_BabobbaStunned0"))


func CK6_BabobbaJumpDraw(obj: CK_object) -> void:
	if obj.rightTI != 0:
		obj.xDirection = IN_motion_Right
		obj.velX = s16(-obj.velX)
	elif obj.leftTI != 0:
		obj.xDirection = IN_motion_Left
		obj.velX = s16(-obj.velX)

	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		CK_SetAction2(obj, CK_GetActionByName("CK6_ACT_BabobbaSit0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK6_BabobbaShot(obj: CK_object) -> void:
	obj.user1 = s16(obj.user1 + 1)
	if obj.user1 == CK_INT("CK6_BabobbaShotDecayTime", 10):
		obj.user1 = 0
		obj.currentAction = CK_GetActionByName("CK6_ACT_BabobbaShotVanish0")


func CK6_BabobbaShotVanish(obj: CK_object) -> void:
	obj.user1 = s16(obj.user1 + 1)
	if obj.user1 == CK_INT("CK6_BabobbaShotVanishTime", 5):
		CK_RemoveObj(obj)


# Blorbs

func CK6_SpawnBlorb(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Blorb
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK6_BlorbSpawnYOffset", -0x80))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down if US_RndT() < 0x80 else IN_motion_Up
	obj.clipped = CLIP_simple
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_Blorb0"))


func CK6_BlorbDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		obj.yDirection = IN_motion_Up
		SD_PlaySound(CK_SOUNDNUM("SOUND_BLORBBOUNCE"))
	elif obj.bottomTI != 0:
		obj.yDirection = IN_motion_Down
		SD_PlaySound(CK_SOUNDNUM("SOUND_BLORBBOUNCE"))

	if obj.leftTI != 0:
		obj.xDirection = IN_motion_Left
		SD_PlaySound(CK_SOUNDNUM("SOUND_BLORBBOUNCE"))
	elif obj.rightTI != 0:
		obj.xDirection = IN_motion_Right
		SD_PlaySound(CK_SOUNDNUM("SOUND_BLORBBOUNCE"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK6_SpawnCeilick(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT6_Ceilick
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.clipped = CLIP_not
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.user1 = s16(obj.posY)
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK6_ACT_CeilickWait0"))


func CK6_Ceilick(obj: CK_object) -> void:
	if (u16(ck_keenObj.posY - obj.posY) <= CK_INT("CK6_CeilickSearchHeight", 0x280)) and (obj.clipRects.unitX2 + CK_INT("CK6_CeilickSearchXRadius", 0x10) >= ck_keenObj.clipRects.unitX1) and (obj.clipRects.unitX1 - CK_INT("CK6_CeilickSearchXRadius", 0x10) <= ck_keenObj.clipRects.unitX2): # <- relies on unsignedness of posY
		SD_PlaySound(CK_SOUNDNUM("SOUND_CEILICKATTACK"))
		obj.currentAction = CK_GetActionByName("CK6_ACT_CeilickStrike00")


func CK6_CeilickDescend(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_CEILICKLAUGH"))


func CK6_CeilickStunned(obj: CK_object) -> void:
	obj.visible = true


func CK6_CeilickCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		a.posY = u16(a.user1)
		CK_ShotHit(b)
		a.user3 = 0
		a.user2 = 0
		a.user1 = 0
		a.user4 = s16(a.type)
		CK_SetAction2(a, CK_GetActionByName("CK6_ACT_CeilickStunned0"))
		a.type = CT6_StunnedCreature


func CK6_Obj3_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK6_FleexWalk", &"CK6_FleexWalk")
	CK_ACT_AddFunction("CK6_FleexSearch", &"CK6_FleexSearch")
	CK_ACT_AddColFunction("CK6_FleexCol", &"CK6_FleexCol")

	CK_ACT_AddFunction("CK6_BobbaFireball", &"CK6_BobbaFireball")
	CK_ACT_AddFunction("CK6_Bobba", &"CK6_Bobba")
	CK_ACT_AddColFunction("CK6_BobbaCol", &"CK6_BobbaCol")
	CK_ACT_AddFunction("CK6_BobbaJumpDraw", &"CK6_BobbaJumpDraw")
	CK_ACT_AddFunction("CK6_BobbaFireballDraw", &"CK6_BobbaFireballDraw")

	CK_ACT_AddFunction("CK6_BabobbaSit", &"CK6_BabobbaSit")
	CK_ACT_AddColFunction("CK6_BabobbaCol", &"CK6_BabobbaCol")
	CK_ACT_AddColFunction("CK6_BabobbaNapCol", &"CK6_BabobbaNapCol")
	CK_ACT_AddFunction("CK6_BabobbaJumpDraw", &"CK6_BabobbaJumpDraw")
	CK_ACT_AddFunction("CK6_BabobbaShot", &"CK6_BabobbaShot")
	CK_ACT_AddFunction("CK6_BabobbaShotVanish", &"CK6_BabobbaShotVanish")

	CK_ACT_AddFunction("CK6_Ceilick", &"CK6_Ceilick")
	CK_ACT_AddFunction("CK6_CeilickDescend", &"CK6_CeilickDescend")
	CK_ACT_AddFunction("CK6_CeilickStunned", &"CK6_CeilickStunned")
	CK_ACT_AddColFunction("CK6_CeilickCol", &"CK6_CeilickCol")

	CK_ACT_AddFunction("CK6_BlorbDraw", &"CK6_BlorbDraw")
