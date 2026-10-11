# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's ck4_misc.c, ck4_map.c and ck4_obj1-3.c, by David Gow and the Omnispeak authors,
# GPL v2 or later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalKeen4
extends GalMenu
## Keen 4's episode code (SIM-G-01g): the info-layer scan, the dialogs, swimming
## Keen, the world map's swimming and every Keen 4 creature's think, collide and
## draw functions. ck4_episode (ck4_misc.c's CK_EpisodeDef) is declared in
## gal_ck.gd. C's `CK_ACTION(x)` is `CK_GetActionByName("x")`; every store
## wraps as the C field's type does (uint16_t: u16, int16_t: s16).



# ===================================================================== ck4_misc.c

# Contains some keen-4 specific functions.

# Level Ending Object Spawn
func CK4_SetupFunctions() -> void:
	CK4_Obj1_SetupFunctions()
	CK4_Obj2_SetupFunctions()
	CK4_Obj3_SetupFunctions()
	CK4_Map_SetupFunctions()
	CK4_Misc_SetupFunctions()


## Check if all the game files are present. The files come from GalData, not
## a file system: Keen 4 is present when GalData loaded a Keen 4 data set.
func CK4_IsPresent() -> bool:
	return data != null and data.ext == "CK4"


## Spawn an enemy projectile.
## Note that the behaviour is slightly different from DOS Keen:
## DOS Keen SpawnEnemyShot returns 0 if shot is spawned, or -1 otherwise;
## omnispeak CK4_SpawnEnemyShot returns the object if succesful, null otherwise.
func CK4_SpawnEnemyShot(posX: int, posY: int, action: CK_action) -> CK_object:
	var new_object: CK_object = CK_GetNewObj(true)

	if new_object == null:
		return null

	new_object.posX = u16(posX)
	new_object.posY = u16(posY)
	new_object.type = CT4_EnemyShot
	new_object.active = OBJ_EXISTS_ONLY_ONSCREEN
	CK_SetAction(new_object, action)

	if CK_NotStuckInWall(new_object):
		return new_object
	else:
		CK_RemoveObj(new_object)
		return null


func CK4_ScanInfoLayer() -> void:
	# Reset the lumps (contiguous lists of chunks for sprites) required by
	# the level.
	CA_ClearLumps()

	#TODO: Work out where to store current map number, etc.
	var mapW: int = CA_GetMapWidth()
	var mapH: int = CA_GetMapHeight()

	for y: int in range(mapH):
		for x: int in range(mapW):
			var infoValue: int = CA_TileAtPos(x, y, 2)
			# C's switch falls through from a harder difficulty's case into the
			# easier one's ("case H: if (difficulty < D_Hard) break; case N:
			# if (difficulty < D_Normal) break; case E: spawn"); each such group
			# is one branch here with the same skip conditions.
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

				# ScubaKeen
				42:
					CK4_SpawnScubaKeen(x, y)
					CK_DemoSignSpawn()
					CA_MARKLUMP("LUMP_SCUBAKEEN")
					CA_MarkGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"))

				3:
					CK_DemoSignSpawn()
					CA_MarkGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"))
					CA_MARKLUMP("LUMP_MAPKEEN")
					CK_SpawnMapKeen(x, y)

				4:
					CK4_SpawnCouncilMember(x, y)
					CA_MARKLUMP("LUMP_ORACLEMEMBER")

				25:
					RF_SetScrollBlock(x, y, true)
				26:
					RF_SetScrollBlock(x, y, false)

				# Miragia
				33:
					CK4_SpawnMiragia(x, y)

				# Slugs
				44, 43, 22:
					if (infoValue == 44 and ck_gameState.difficulty < D_Hard) or (infoValue != 22 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_SLUG")
						CK4_SpawnSlug(x, y)

				# Mushrooms
				21:
					CA_MARKLUMP("LUMP_MUSHROOM")
					CK4_SpawnMushroom(x, y)

				# Birds
				13:
					CA_MARKLUMP("LUMP_EGG")
					CA_MARKLUMP("LUMP_BLUEBIRD")
					CK4_SpawnEgg(x, y)

				78, 77:
					if (infoValue == 78 and ck_gameState.difficulty < D_Hard) or ck_gameState.difficulty < D_Normal:
						pass
					else:
						CA_MARKLUMP("LUMP_BLUEBIRD")
						CK4_SpawnBird(x, y)

				# Arachnuts
				74, 73, 20:
					if (infoValue == 74 and ck_gameState.difficulty < D_Hard) or (infoValue != 20 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_ARACHNUT")
						CK4_SpawnArachnut(x, y)

				75:
					CA_MARKLUMP("LUMP_KEENMOON")

				# Skypest
				46, 45, 8:
					if (infoValue == 46 and ck_gameState.difficulty < D_Hard) or (infoValue != 8 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_SKYPEST")
						CK4_SpawnSkypest(x, y)

				# Wormmouth
				52, 51, 7:
					if (infoValue == 52 and ck_gameState.difficulty < D_Hard) or (infoValue != 7 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_WORMMOUTH")
						CK4_SpawnWormmouth(x, y)

				# Clouds
				9:
					CA_MARKLUMP("LUMP_CLOUD")
					CK4_SpawnCloud(x, y)

				# Berks
				50, 49, 5:
					if (infoValue == 50 and ck_gameState.difficulty < D_Hard) or (infoValue != 5 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_BERKELOID")
						CK4_SpawnBerkeloid(x, y)

				# Inchworms: both cases end in "goto cachePoofs"
				10, 11:
					if infoValue == 10:
						CA_MARKLUMP("LUMP_INCHWORM")
						CK4_SpawnFoot(x, y)
					else:
						CA_MARKLUMP("LUMP_INCHWORM")
						CK4_SpawnInchworm(x, y)

					# cachePoofs:
					# We re-use the smirky smoke, but only the first three frames.
					var i: int = CK_CHUNKNUM("SPR_EATERPUFF1")
					while i <= CK_CHUNKNUM("SPR_EATERPUFF3"):
						CA_MarkGrChunk(i)
						i += 1

				# Bounders
				12:
					CA_MARKLUMP("LUMP_BOUNDER")
					CK4_SpawnBounder(x, y)

				# Licks
				48, 47, 14:
					if (infoValue == 48 and ck_gameState.difficulty < D_Hard) or (infoValue != 14 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_LICK")
						CK4_SpawnLick(x, y)

				# Plats
				27, 28, 29, 30:
					CK4_SpawnAxisPlatform(x, y, infoValue - 27)
					CA_MARKLUMP("LUMP_PLATFORM")

				31:
					# B Block
					pass

				32:
					CK_SpawnFallPlat(x, y)
					CA_MARKLUMP("LUMP_PLATFORM")

				#Smirkies
				18:
					CK4_SpawnSmirky(x, y)
					CA_MARKLUMP("LUMP_ANCIENT")

				#Mimrocks
				19:
					CK4_SpawnMimrock(x, y)
					CA_MARKLUMP("LUMP_MIMROCK")

				# Dopefish
				88, 87, 15:
					if (infoValue == 88 and ck_gameState.difficulty < D_Hard) or (infoValue != 15 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_DOPEFISH")
						CK4_SpawnDopefish(x, y)

				# Schoolfish
				16:
					CA_MARKLUMP("LUMP_SCHOOLFISH")
					CK4_SpawnSchoolfish(x, y)

				# Sprites
				24, 23, 17:
					if (infoValue == 24 and ck_gameState.difficulty < D_Hard) or (infoValue != 17 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CA_MARKLUMP("LUMP_SPRITE")
						CK4_SpawnSprite(x, y)

				# Mines
				69, 70, 71, 72:
					CA_MARKLUMP("LUMP_MINE")
					CK4_SpawnMine(x, y, infoValue - 69)

				# Lindsey
				6:
					CA_MARKLUMP("LUMP_LINDSEY")
					CK4_SpawnLindsey(x, y)

				83, 79, 53:
					if (infoValue == 83 and ck_gameState.difficulty < D_Hard) or (infoValue != 53 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CK4_SpawnDartGun(x, y, 0)
						CA_MARKLUMP("LUMP_POISONDART")

				84, 80, 54:
					if (infoValue == 84 and ck_gameState.difficulty < D_Hard) or (infoValue != 54 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CK4_SpawnDartGun(x, y, 1)
						CA_MARKLUMP("LUMP_POISONDART")

				85, 81, 55:
					if (infoValue == 85 and ck_gameState.difficulty < D_Hard) or (infoValue != 55 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CK4_SpawnDartGun(x, y, 2)
						CA_MARKLUMP("LUMP_POISONDART")

				86, 82, 56:
					if (infoValue == 86 and ck_gameState.difficulty < D_Hard) or (infoValue != 56 and ck_gameState.difficulty < D_Normal):
						pass
					else:
						CK4_SpawnDartGun(x, y, 3)
						CA_MARKLUMP("LUMP_POISONDART")

				# Wetsuit
				35:
					CK4_SpawnWetsuit(x, y)
					CA_MarkGrChunk(CK_CHUNKNUM("SPR_SCUBAGEAR"))

				# case 34 falls through into the item cases
				34, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68:
					var spawnItem: bool = true
					if infoValue == 34:
						# Spawn extra stunner if Keen has low ammo
						if ck_gameState.numShots >= 5:
							spawnItem = false
						else:
							infoValue = 68
							CA_MARKLUMP("LUMP_STUNNER")
					if spawnItem:
						CK_SpawnItem(x, y, infoValue - 57)
						CA_MarkLumpNeeded(CK_INTELEMENT("ck_itemLumps", infoValue - 57))

				_:
					pass

	var obj: CK_object = ck_keenObj
	while obj != null:
		if obj.active != OBJ_ALWAYS_ACTIVE:
			obj.active = OBJ_INACTIVE
		obj = obj.next

	# CA_MarkAllLumps() reads the episode's lumpStarts/lumpEnds itself in C
	CA_MarkAllLumps(CK_VAR_GetIntArray("lumpStarts"), CK_VAR_GetIntArray("lumpEnds"))


# Dialog Functions
# These are right after ScanInfoLayer in DOS exe
func CK4_ShowPrincessMessage() -> void:
	# (SCR-01: the VW_WaitVBL waits omnispeak leaves out are in Keen 4's own code
	# (KEEN4E.EXE image 0xEFE8, 0xF059, 0xF08C): a key pressed while a window is still waiting does not count)
	SD_WaitSoundDone()
	StopMusic()
	CA_UpLevel()

	CA_MarkGrChunk(CK_CHUNKNUM("PIC_LINDSEY"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK2"))
	CA_CacheMarks("")

	VL_FixRefreshBuffer()
	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_LINDSEY"))
	US_SetPrintY(US_GetPrintY() + 6)
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetWindowX(US_GetWindowX() + 0x30)
	US_CPrint(CK_STRING("ck4_str_lindsaySays"))

	if ca_mapOn == CK_INT("CK4_LindseyMessage1Level", 7):
		US_CPrint(CK_STRING("ck4_str_lindsayMessage1"))
	else:
		US_CPrint(CK_STRING("ck4_str_lindsayMessage2"))

	VH_UpdateScreen()
	SD_PlaySound(CK_SOUNDNUM("SOUND_FOOTAPPEAR"))
	VL_DelayTics(60)    # VW_WaitVBL(60);
	IN_ClearKeysDown()
	IN_WaitButton()
	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 12)

	if ca_mapOn == CK_INT("CK4_LindseyMessage1Level", 7):
		US_CPrint(CK_STRING("ck4_str_lindsayThanks1"))
	else:
		US_CPrint(CK_STRING("ck4_str_lindsayThanks2"))

	VH_UpdateScreen()
	VL_DelayTics(30)    # VW_WaitVBL(30);

	IN_ClearKeysDown()
	IN_WaitButton()

	VHB_DrawBitmap(US_GetWindowW() + US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK2"))
	VH_UpdateScreen()

	VL_DelayTics(30)    # VW_WaitVBL(30);

	IN_ClearKeysDown()
	IN_WaitButton()
	CA_DownLevel()

	StartMusic(ck_gameState.currentLevel)
	# ck_scoreBoxObj->user1 = ck_scoreBoxObj->user2 = ck_scoreBoxObj->user3 = ck_scoreBoxObj->user4 = -1;
	ck_scoreBoxObj.user4 = -1
	ck_scoreBoxObj.user3 = -1
	ck_scoreBoxObj.user2 = -1
	ck_scoreBoxObj.user1 = -1


func CK4_ShowJanitorMessage() -> void:
	# (SCR-01: the VW_WaitVBL waits omnispeak leaves out are in Keen 4's own code
	# (KEEN4E.EXE image 0xF171, 0xF1E2, 0xF255, 0xF2C6, 0xF32A): a key pressed while a window is still waiting does not count)
	SD_WaitSoundDone()
	CA_UpLevel()
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_ORACLE"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENMAD"))
	CA_CacheMarks("")

	VL_FixRefreshBuffer()
	StartMusic(s16(0xFFFF))  # StartMusic(0xFFFF): its int16_t parameter makes it -1

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_ORACLE"))
	US_SetPrintY(US_GetPrintY() + 6)
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetWindowX(US_GetWindowX() + 0x30)
	US_CPrint(CK_STRING("ck4_str_janitor1"))
	VH_UpdateScreen()
	VL_DelayTics(60)    # VW_WaitVBL(60);
	IN_ClearKeysDown()
	IN_WaitButton()

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_ORACLE"))
	US_SetPrintY(US_GetPrintY() + 6)
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetWindowX(US_GetWindowX() + 0x30)
	US_CPrint(CK_STRING("ck4_str_janitor2"))
	VH_UpdateScreen()
	VL_DelayTics(60)    # VW_WaitVBL(60);
	IN_ClearKeysDown()
	IN_WaitButton()

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 12)
	US_CPrint(CK_STRING("ck4_str_janitor3"))
	VH_UpdateScreen()
	VL_DelayTics(60)    # VW_WaitVBL(60);
	IN_ClearKeysDown()
	IN_WaitButton()

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_ORACLE"))
	US_SetPrintY(US_GetPrintY() + 6)
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetWindowX(US_GetWindowX() + 0x30)
	US_CPrint(CK_STRING("ck4_str_janitor4"))
	VH_UpdateScreen()
	VL_DelayTics(60)    # VW_WaitVBL(60);
	IN_ClearKeysDown()
	IN_WaitButton()

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x28, US_GetWindowY() + 0x18, CK_CHUNKNUM("PIC_KEENMAD"))
	VH_UpdateScreen()

	VL_DelayTics(30)    # VW_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()

	StopMusic()
	CA_DownLevel()
	StartMusic(ck_gameState.currentLevel)


func CK4_ShowCantSwimMessage() -> void:
	# (SCR-01: the VW_WaitVBL waits omnispeak leaves out are in Keen 4's own code
	# (KEEN4E.EXE image 0xF3B9): a key pressed while a window is still waiting does not count)
	SD_WaitSoundDone()
	CA_UpLevel()
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 6)
	US_CPrint(CK_STRING("ck4_str_cantSwim"))
	VH_UpdateScreen()
	VL_DelayTics(30)    # VL_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()
	CA_DownLevel()


func CK4_ShowWetsuitMessage() -> void:
	# (SCR-01: the VW_WaitVBL waits omnispeak leaves out are in Keen 4's own code
	# (KEEN4E.EXE image 0xF449, 0xF47C): a key pressed while a window is still waiting does not count)
	SD_WaitSoundDone()
	CA_UpLevel()
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK2"))
	CA_CacheMarks("")
	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 12)
	US_CPrint(CK_STRING("ck4_str_gotWetsuit"))
	VH_UpdateScreen()
	VL_DelayTics(30)    # VL_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()

	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW(), US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK2"))
	VH_UpdateScreen()

	VL_DelayTics(30)    # VL_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()

	CA_DownLevel()


func CK4_ShowCouncilMessage() -> void:
	SD_WaitSoundDone()
	CA_UpLevel()

	CA_MarkGrChunk(CK_CHUNKNUM("PIC_ORACLE"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK1"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_KEENTALK2"))
	CA_CacheMarks("")
	StartMusic(-1)

	VL_FixRefreshBuffer()

	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_ORACLE"))
	US_SetPrintY(US_GetPrintY() + 6)
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetWindowX(US_GetWindowX() + 0x30)

	if ca_mapOn == CK_INT("CK4_CouncilMessageUnderwaterLevel", 17):
		# Underwater level
		US_CPrint(CK_STRING("ck4_str_councilThanks2"))
	else:
		US_CPrint(CK_STRING("ck4_str_councilThanks"))

	VH_UpdateScreen()
	# SCR-01: the waits omnispeak leaves out, and the third IN_ClearKeysDown, are in Keen 4's own code
	# (KEEN4E.EXE 0F00:0495): a key pressed while a window waits does not count
	VL_DelayTics(60)    # VL_WaitVBL(60);
	IN_ClearKeysDown()
	IN_WaitButton()
	US_CenterWindow(26, 8)
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW() - 0x30, US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK1"))
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetPrintY(US_GetPrintY() + 12)
	US_CPrint(CK_STRINGELEMENT("ck4_str_councilMessage", ck_gameState.ck4_membersRescued))
	VH_UpdateScreen()
	VL_DelayTics(30)    # VW_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()
	VHB_DrawBitmap(US_GetWindowX() + US_GetWindowW(), US_GetWindowY(), CK_CHUNKNUM("PIC_KEENTALK2"))
	VH_UpdateScreen()
	VL_DelayTics(30)    # VW_WaitVBL(30);
	IN_ClearKeysDown()
	IN_WaitButton()
	ck_gameState.ck4_membersRescued = s16(ck_gameState.ck4_membersRescued + 1)
	CA_DownLevel()
	StopMusic()


# Scuba Keen
func CK4_SpawnScubaKeen(tileX: int, tileY: int) -> void:
	ck_keenObj.type = CT_Player
	ck_keenObj.active = OBJ_ALWAYS_ACTIVE
	ck_keenObj.zLayer = PRIORITIES - 3
	ck_keenObj.posX = u16(RF_TileToUnit(tileX))
	ck_keenObj.posY = u16(RF_TileToUnit(tileY))
	ck_keenObj.xDirection = IN_motion_Right
	ck_keenObj.yDirection = IN_motion_Down
	ck_keenObj.clipped = CLIP_simple
	CK_SetAction(ck_keenObj, CK_GetActionByName("CK4_ACT_KeenSwim0"))


func CK4_SpawnKeenBubble(obj: CK_object) -> void:
	obj.user4 = 0
	var bubble: CK_object = CK_GetNewObj(true)
	bubble.posX = obj.posX if obj.xDirection == IN_motion_Left else u16(obj.posX + 0x180)

	bubble.posY = obj.posY
	bubble.type = CT_Friendly
	bubble.zLayer = PRIORITIES - 1
	bubble.active = OBJ_EXISTS_ONLY_ONSCREEN
	bubble.clipped = CLIP_not
	bubble.velY = -24
	bubble.velX = 4

	@warning_ignore("integer_division")
	match US_RndT() / 64:
		0:
			CK_SetAction(bubble, CK_GetActionByName("CK4_ACT_Bubble0"))

		1:
			CK_SetAction(bubble, CK_GetActionByName("CK4_ACT_Bubble1"))

		2:
			CK_SetAction(bubble, CK_GetActionByName("CK4_ACT_Bubble2"))

		3:
			CK_SetAction(bubble, CK_GetActionByName("CK4_ACT_Bubble3"))

	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENBUBBLE"))


func CK4_KeenSwim(obj: CK_object) -> void:
	var movingLeft: int = 1 if obj.velX < 0 else 0
	var movingUp: int = 1 if obj.velY < 4 else 0

	# if ((obj->user4 += SD_GetSpriteSync()) > 60)
	obj.user4 = s16(obj.user4 + SD_GetSpriteSync())
	if obj.user4 > 60:
		CK4_SpawnKeenBubble(obj)

	if ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed:
		ck_keenState.jumpWasPressed = true
		if ck_inputFrame.xDirection != 0:
			obj.velX = s16(ck_inputFrame.xDirection * 18)
		if ck_inputFrame.yDirection != 0:
			obj.velY = s16(ck_inputFrame.yDirection * 18)

		if obj.currentAction.next != null:
			obj.currentAction = obj.currentAction.next

	if ck_inputFrame.xDirection != 0:
		obj.xDirection = ck_inputFrame.xDirection

	var lastTimeCount: int = SD_GetLastTimeCount()
	var tic: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tic < lastTimeCount:
		if (tic & 7) == 0:
			var dx: int
			if obj.velX > 12:
				dx = -3
			elif obj.velX > 0:
				dx = -1
			elif obj.velX > -12:
				dx = 1
			else:
				dx = 3

			dx += 2 * ck_inputFrame.xDirection
			obj.velX = s16(obj.velX + dx)

			if ck_inputFrame.xDirection == 0:
				var stillMovingLeft: int = 1 if obj.velX < 0 else 0

				if stillMovingLeft != movingLeft:
					obj.velX = 0

			var dy: int
			if obj.velY > 12:
				dy = -3
			elif obj.velY > 4:
				dy = -1
			elif obj.velY > -12:
				dy = 1
			else:
				dy = 3

			dy += 2 * ck_inputFrame.yDirection
			obj.velY = s16(obj.velY + dy)

			if ck_inputFrame.yDirection == 0:
				if obj.velY > 4 and movingUp != 0:
					obj.velY = 0

		ck_nextX = s16(ck_nextX + obj.velX)
		ck_nextY = s16(ck_nextY + obj.velY)
		tic = s32(tic + 1)


func CK4_KeenSwimFast(obj: CK_object) -> void:
	# if ((obj->user4 += SD_GetSpriteSync()) > 60)
	obj.user4 = s16(obj.user4 + SD_GetSpriteSync())
	if obj.user4 > 60:
		CK4_SpawnKeenBubble(obj)

	if ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed:
		ck_keenState.jumpWasPressed = true
		obj.velX = s16(ck_inputFrame.xDirection * 18)

		if ck_inputFrame.yDirection != 0:
			obj.velY = s16(ck_inputFrame.yDirection * 18)

	if obj.currentAction == CK_GetActionByName("CK4_ACT_KeenSwimFast0"):
		obj.currentAction = CK_GetActionByName("CK4_ACT_KeenSwimFast1")
	else:
		obj.currentAction = CK_GetActionByName("CK4_ACT_KeenSwimFast0")

	ck_nextX = s16(ck_nextX + obj.velX * SD_GetSpriteSync())
	ck_nextY = s16(ck_nextY + obj.velY * SD_GetSpriteSync())

	if ck_nextX > 0:
		obj.xDirection = IN_motion_Right
	elif ck_nextX < 0:
		obj.xDirection = IN_motion_Left

	ck_nextY = s16(ck_nextY + SD_GetSpriteSync() * 4)


func CK4_KeenSwimCol(_a: CK_object, b: CK_object) -> void:
	if b.type == CT4_Item:
		if b.user1 > 11:
			return

		SD_PlaySound(CK_INTELEMENT("ck_itemSounds", b.user1))

		b.type = CT_Friendly
		b.zLayer = PRIORITIES - 1
		b.gfxChunk = u16(CK_LookupChunk(ck_itemShadows[b.user1]))

		CK_IncreaseScore(ck_itemPoints[b.user1])

		#b->yDirection = -1;

		if b.user1 < 4:
			ck_gameState.keyGems[b.user1] = s16(ck_gameState.keyGems[b.user1] + 1)
		elif b.user1 == 10:
			ck_gameState.numLives = s16(ck_gameState.numLives + 1)
		elif b.user1 == 11:
			ck_gameState.numShots = s16(ck_gameState.numShots + (8 if ck_gameState.difficulty == D_Easy else 5))
		CK_SetAction2(b, CK_GetActionByName("CK_ACT_itemNotify"))
	elif b.type == CT4_CouncilMember:
		ck_gameState.levelState = LS_CouncilRescued


func CK4_KeenSwimDraw(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0

	if (obj.topTI != 0 and obj.velY > 0) or (obj.bottomTI != 0 and obj.velY < 0):
		obj.velY = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# ===========================================================================

func CK4_Misc_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK4_KeenSwim", &"CK4_KeenSwim")
	CK_ACT_AddFunction("CK4_KeenSwimFast", &"CK4_KeenSwimFast")
	CK_ACT_AddColFunction("CK4_KeenSwimCol", &"CK4_KeenSwimCol")
	CK_ACT_AddFunction("CK4_KeenSwimDraw", &"CK4_KeenSwimDraw")


# ===================================================================== ck4_map.c

func CK4_MapKeenFoot(obj: CK_object) -> void:
	var spriteSync: int = SD_GetSpriteSync()
	obj.user1 = s16(obj.user1 - spriteSync)
	ck_nextX = s16(spriteSync * obj.velX)
	ck_nextY = s16(spriteSync * obj.velY)
	if obj.user1 <= 0:
		ck_nextX = s16(ck_nextX - obj.velX * -obj.user1)
		ck_nextY = s16(ck_nextY - obj.velY * -obj.user1)
		obj.zLayer = PRIORITIES - 3
		obj.user1 = 6
		obj.user2 = 3
		obj.user3 = 0
		# use global pointer for some reason
		ck_keenObj.yDirection = IN_motion_None
		ck_keenObj.xDirection = IN_motion_None
		obj.currentAction = CK_GetActionByName("CK_ACT_MapKeenStart")
		obj.gfxChunk = 256
		obj.clipped = CLIP_normal


const ck4_swimFrames: PackedInt32Array = [280, 288, 282, 290, 284, 292, 286, 294]


func CK4_MapKeenSwim(obj: CK_object) -> void:
	if obj.user3 != 0:
		# if ((obj->user3 -= 6) < 0)
		obj.user3 = s16(obj.user3 - 6)
		if obj.user3 < 0:
			obj.user3 = 0
	else:
		obj.xDirection = ck_inputFrame.xDirection
		obj.yDirection = ck_inputFrame.yDirection

		if ck_inputFrame.xDirection != 0 or ck_inputFrame.yDirection != 0:
			obj.user1 = ck_inputFrame.dir

	obj.gfxChunk = u16(ck4_swimFrames[obj.user1] + obj.user2)

	obj.user2 = s16(obj.user2 + 1)
	if obj.user2 == 2:
		obj.user2 = 0

	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSWIMHI") if obj.user2 != 0 else CK_SOUNDNUM("SOUND_KEENSWIMLO"))


const ck4_wetsuitOffs: PackedInt32Array = [4, 6, 0, 2]
const ck4_wetsuitOffs2: PackedInt32Array = [4, 5, 6, 7, 0, 1, 2, 3]


func CK4_MapMiscFlagsCheck(obj: CK_object) -> void:
	if obj.user3 == 0:
		var midX: int = obj.clipRects.tileXmid
		@warning_ignore("integer_division")
		var midY: int = RF_UnitToTile(obj.clipRects.unitY1 + (obj.clipRects.unitY2 - obj.clipRects.unitY1) / 2)
		var mf: int = TI_ForeMisc(CA_TileAtPos(midX, midY, 1))

		if mf == MF_WaterN or mf == MF_WaterE or mf == MF_WaterS or mf == MF_WaterW:
			if ck_gameState.ck4_wetsuit == 0:
				SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
				CK4_ShowCantSwimMessage()
				# RF_ForceRefresh();
				ck_nextX = s16(-obj.deltaPosX)
				ck_nextY = s16(-obj.deltaPosY)
				obj.yDirection = 0
				obj.xDirection = 0
				CK_PhysUpdateNormalObj(obj)
			else:
				obj.user1 = ck4_wetsuitOffs[mf - MF_WaterN]

				if obj.currentAction == CK_GetActionByName("CK4_ACT_MapKeenSwim0"):
					obj.user1 = ck4_wetsuitOffs2[obj.user1]

				match obj.user1:
					0:
						obj.xDirection = 0
						obj.yDirection = -1
					2:
						obj.xDirection = 1
						obj.yDirection = 0
					4:
						obj.xDirection = 0
						obj.yDirection = 1
					6:
						obj.xDirection = -1
						obj.yDirection = 0

				obj.user2 = 0
				obj.user3 = 18

				if obj.currentAction == CK_GetActionByName("CK4_ACT_MapKeenSwim0"):
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_MapKeenStart"))
				else:
					CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_MapKeenSwim0"))


func CK4_Map_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK4_MapKeenFoot", &"CK4_MapKeenFoot")
	CK_ACT_AddFunction("CK4_MapKeenSwim", &"CK4_MapKeenSwim")
	CK_ACT_AddFunction("CK4_MapMiscFlagsCheck", &"CK4_MapMiscFlagsCheck")


# ===================================================================== ck4_obj1.c

# Miragia

func CK4_SpawnMiragia(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT_Friendly
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.posX = u16(tileX)
	obj.posY = u16(tileY)
	obj.currentAction = CK_GetActionByName("CK4_ACT_Miragia0")


func CK4_Miragia0(obj: CK_object) -> void:
	if ((ck_keenObj.clipRects.tileX2 >= obj.posX) and
			(ck_keenObj.clipRects.tileX1 <= obj.posX + 5) and
			(ck_keenObj.clipRects.tileY1 >= obj.posY) and
			(ck_keenObj.clipRects.tileY2 <= obj.posY + 4)):
		obj.currentAction = CK_GetActionByName("CK4_ACT_Miragia7")
	else:
		RF_ReplaceTileBlock(8, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia1(obj: CK_object) -> void:
	RF_ReplaceTileBlock(14, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia2(obj: CK_object) -> void:
	RF_ReplaceTileBlock(20, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia3(obj: CK_object) -> void:
	RF_ReplaceTileBlock(26, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia4(obj: CK_object) -> void:
	RF_ReplaceTileBlock(20, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia5(obj: CK_object) -> void:
	RF_ReplaceTileBlock(14, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia6(obj: CK_object) -> void:
	RF_ReplaceTileBlock(8, 60, obj.posX, obj.posY, 6, 4)


func CK4_Miragia7(obj: CK_object) -> void:
	RF_ReplaceTileBlock(2, 60, obj.posX, obj.posY, 6, 4)


func CK4_SpawnCouncilMember(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_CouncilMember
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_CouncilSpawnYOffset", 369))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_CouncilWalk0"))


func CK4_CouncilWalk(obj: CK_object) -> void:
	if SD_GetSpriteSync() << CK_INT("CK4_CouncilPauseProbability", 3) > US_RndT():
		obj.currentAction = CK_GetActionByName("CK4_ACT_CouncilPause")


# Slugs

func CK4_SpawnSlug(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Slug
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_SlugSpawnYOffset", 0x71))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_SlugMove0"))


func CK4_SlugMove(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK4_SlugSlimeChance", 0x10):
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left
		obj.currentAction = CK_GetActionByName("CK4_ACT_SlugSliming0")
		SD_PlaySound(CK_SOUNDNUM("SOUND_SLUGSLIME"))


func CK4_SlugSlime(obj: CK_object) -> void:
	var slime: CK_object = CK_GetNewObj(true)
	slime.type = CT_Friendly
	slime.active = OBJ_EXISTS_ONLY_ONSCREEN
	slime.zLayer = PRIORITIES - 4
	slime.posX = obj.posX
	slime.posY = u16(obj.clipRects.unitY2 - CK_INT("CK4_SlugSlimeYOffset", 0x80))
	CK_SetAction(slime, CK_GetActionByName("CK4_ACT_SlugSlime0"))


func CK4_SlugCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		CK_StunCreature(a, b, (CK_GetActionByName("CK4_ACT_SlugStunned0") if US_RndT() < 0x80 else CK_GetActionByName("CK4_ACT_SlugStunned1")))
		a.velY = s16(CK_INT("CK4_SlugDeathYVel", -24))
		a.velX = s16(a.xDirection * 8)


# Mad Mushrooms

func CK4_SpawnMushroom(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Mushroom
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_MushroomSpawnYOffset", 0xF1))
	obj.xDirection = IN_motion_Right
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Mushroom0"))


func CK4_MushroomMove(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Right if ck_keenObj.posX > obj.posX else IN_motion_Left
	CK_PhysGravityMid(obj)


func CK4_MushroomCol(_a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_ShotHit(b)
	elif b.type == CT_Player:
		CK_KillKeen()


func CK4_MushroomDraw(obj: CK_object) -> void:
	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		obj.velY = 0
		obj.user1 = s16(obj.user1 + 1)
		if obj.user1 == CK_INT("CK4_MushroomNumJumps", 3):  # Jump counter
			obj.user1 = 0
			obj.velY = s16(CK_INT("CK4_MushroomJumpYVel", -68))
			SD_PlaySound(CK_SOUNDNUM("SOUND_MUSHROOMLEAP"))
		else:
			SD_PlaySound(CK_SOUNDNUM("SOUND_MUSHROOMHOP"))
			obj.velY = s16(CK_INT("CK4_MushroomHopYVel", -40))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Bluebird

func CK4_SpawnEgg(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Egg
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_EggSpawnYOffset", 0x71))
	obj.xDirection = IN_motion_Right
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Egg0"))


func CK4_BirdRecover(obj: CK_object) -> void:
	obj.type = CT4_Bird


func CK4_SpawnBird(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(true)
	obj.type = CT4_Bird
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_BirdSpawnYOffset", 0xF1))
	obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_BirdHatched0"))


func CK4_EggCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player or b.type == CT_Stunner:
		if b.type == CT_Stunner:
			CK_ShotHit(b)

		a.type = CT_Friendly
		a.active = OBJ_EXISTS_ONLY_ONSCREEN
		CK_SetAction(a, CK_GetActionByName("CK4_ACT_Eggshell0"))

		# Spawn bird
		var bird: CK_object = CK_GetNewObj(true)
		bird.type = CT4_Bird
		bird.active = OBJ_ACTIVE
		bird.posX = a.posX
		bird.posY = u16(a.posY - CK_INT("CK4_BirdHatchYOffset", 0x80))
		bird.xDirection = IN_motion_Right if a.posX < ck_keenObj.posX else IN_motion_Left
		bird.yDirection = IN_motion_Down
		CK_SetAction(bird, CK_GetActionByName("CK4_EggHatchAction"))

		# Shell bits
		var shell: CK_object = CK_GetNewObj(true)
		shell.type = CT_Friendly
		shell.active = OBJ_EXISTS_ONLY_ONSCREEN
		shell.posX = a.posX
		shell.posY = a.posY
		shell.velX = s16(CK_INT("CK4_BirdEggShellBitAXVel", -28))
		shell.velY = s16(CK_INT("CK4_BirdEggShellBitAYVel", -40))
		CK_SetAction(shell, CK_GetActionByName("CK4_ACT_EggshellBitA0"))

		shell = CK_GetNewObj(true)
		shell.type = CT_Friendly
		shell.active = OBJ_EXISTS_ONLY_ONSCREEN
		shell.posX = a.posX
		shell.posY = a.posY
		shell.velX = s16(CK_INT("CK4_BirdEggShellBitBXVel", 28))
		shell.velY = s16(CK_INT("CK4_BirdEggShellBitBYVel", -40))
		CK_SetAction(shell, CK_GetActionByName("CK4_ACT_EggshellBitB0"))

		shell = CK_GetNewObj(true)
		shell.type = CT_Friendly
		shell.active = OBJ_EXISTS_ONLY_ONSCREEN
		shell.posX = a.posX
		shell.posY = a.posY
		shell.velX = s16(CK_INT("CK4_BirdEggShellBitCXVel", 0))
		shell.velY = s16(CK_INT("CK4_BirdEggShellBitCYVel", -56))
		CK_SetAction(shell, CK_GetActionByName("CK4_ACT_EggshellBitC0"))


func CK4_BirdWalk(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left
	if (obj.clipRects.unitY2 >= ck_keenObj.clipRects.unitY2 + CK_INT("CK4_BirdWalkKeenYHeight", 0x300) and
			ck_keenObj.topTI != 0 and
			CK_PreviewClipRects(obj, CK_GetActionByName("CK4_ACT_BirdFly0"))):
		obj.currentAction = CK_GetActionByName("CK4_ACT_BirdFly0")
		obj.clipped = CLIP_simple
		obj.velY = s16(CK_INT("CK4_BirdInitialFlyVel", -8))
		obj.user1 = 0


func CK4_BirdFly(obj: CK_object) -> void:
	if obj.user1 == 0:
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left

	CK_PhysAccelHorz2(obj, obj.xDirection, CK_INT("CK4_BirdFlyXAccel", 16))

	if obj.posY < ck_keenObj.posY:
		CK_PhysAccelVert1(obj, 1, CK_INT("CK4_BirdFlyYAccel", 16))
	else:
		CK_PhysAccelVert1(obj, -1, CK_INT("CK4_BirdFlyYAccel", 16))


func CK4_BirdCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	elif b.type == CT_Stunner:
		a.velX = 0
		a.clipped = CLIP_normal
		CK_StunCreature(a, b, CK_GetActionByName("CK4_ACT_BirdStunned0"))


func CK4_BirdHatchedCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		a.velX = 0
		CK_StunCreature(a, b, CK_GetActionByName("CK4_ACT_BirdStunned0"))


func CK4_BirdDraw(obj: CK_object) -> void:
	# Hit wall walking right; turn around and go left
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		@warning_ignore("integer_division")
		obj.timeUntillThink = u16(US_RndT() / CK_INT("CK4_BirdWallCooldownDivisor", 32))
		CK_SetAction2(obj, obj.currentAction)
	# Hit wall walking left; turn around and go right
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		@warning_ignore("integer_division")
		obj.timeUntillThink = u16(US_RndT() / CK_INT("CK4_BirdWallCooldownDivisor", 32))
		CK_SetAction2(obj, obj.currentAction)

	if obj.topTI == 0:
		obj.velY = s16(-CK_INT("CK4_BirdFlyYAccel", 16))
		obj.clipped = CLIP_simple
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_BirdFly0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_BirdLandingDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_BirdWalk0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_EggshellDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		obj.velY = 0
		obj.velX = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_BirdFlyingDraw(obj: CK_object) -> void:
	if obj.bottomTI != 0 or obj.topTI != 0:
		if obj.user1 == 0:
			obj.user1 += 1

	if (obj.rightTI != 0 and obj.velX < 0) or (obj.leftTI != 0 and obj.velX > 0):
		obj.velX = 0
		obj.xDirection = s16(-obj.xDirection)

	if obj.topTI == 1 and ck_keenObj.clipRects.unitY2 - obj.clipRects.unitY2 < CK_INT("CK4_BirdLandYOffset", 0x80):
		# Attempt to land, and remain flying if can't
		var act: CK_action = obj.currentAction
		obj.clipped = CLIP_normal
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_BirdWalk0"))
		ck_nextX = 0
		ck_nextY = s16(CK_INT("CK4_BirdLandYOffset", 0x80))
		CK_PhysUpdateSimpleObj(obj)
		if obj.topTI == 0:
			obj.clipped = CLIP_simple
			CK_SetAction2(obj, act)
		# Shouldn't we draw here? (omnispeak upstream returns without drawing)
		return

	if obj.bottomTI == 0 and obj.topTI == 0:
		obj.user1 = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Arachnut

func CK4_SpawnArachnut(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Arachnut
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_ArachnutSpawnYOffset", 0x171))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_ArachnutWalk0"))


func CK4_ArachnutSearch(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left


func CK4_ArachnutCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK4_ACT_ArachnutStunned0"))
	elif b.type == CT_Player:
		CK_KillKeen()


func CK4_ArachnutStunnedCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK4_ACT_ArachnutStunned0"))


# Skypests

func CK4_SpawnSkypest(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Skypest
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down if US_RndT() < 0x80 else IN_motion_Up
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_SkypestFly0"))


func CK4_SkypestFly(obj: CK_object) -> void:
	if US_RndT() < SD_GetSpriteSync():
		obj.xDirection = s16(-obj.xDirection)

	if obj.yDirection == IN_motion_Up and US_RndT() < SD_GetSpriteSync():
		obj.yDirection = IN_motion_Down

	if obj.yDirection == IN_motion_Down and US_RndT() < SD_GetSpriteSync() * 2:
		obj.yDirection = s16(-obj.yDirection)

	CK_PhysAccelHorz(obj, obj.xDirection, CK_INT("CK4_SkypestAccelX", 20))
	CK_PhysAccelVert1(obj, obj.yDirection, CK_INT("CK4_SkypestAccelY", 20))


func CK4_SkypestAirCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	# There's no "else" in the original Keen 4 EXE so, so let's omit it for
	# the sake of consistency, even if there's no change to behaviors
	if b.type == CT_Stunner:
		if b.xDirection == IN_motion_Right:
			a.velX = s16(CK_INT("CK4_SkypestAccelX", 20))
		elif b.xDirection == IN_motion_Left:
			a.velX = s16(-CK_INT("CK4_SkypestAccelX", 20))
		elif b.yDirection == IN_motion_Down:
			a.velY = s16(CK_INT("CK4_SkypestAccelY", 20))
		elif b.yDirection == IN_motion_Up:
			a.velY = s16(-CK_INT("CK4_SkypestAccelY", 20))

		CK_ShotHit(b)


func CK4_SkypestGroundCol(a: CK_object, b: CK_object) -> void:
	if (b.currentAction == CK_GetActionByName("CK_ACT_keenPogo1") or
			b.currentAction == CK_GetActionByName("CK_ACT_keenPogo2") or
			b.currentAction == CK_GetActionByName("CK_ACT_keenPogo3")):
		CK_SetAction2(a, CK_GetActionByName("CK4_ACT_SkypestSquish0"))
		SD_PlaySound(CK_SOUNDNUM("SOUND_SKYPESTSQUISH"))
		a.type = CT_Friendly


func CK4_SkypestTakeoff(obj: CK_object) -> void:
	obj.yDirection = IN_motion_Up
	obj.velY = s16(CK_INT("CK4_SkypestTakeoffYVel", -16))
	ck_nextY = s16(CK_INT("CK4_SkypestTakeoffYOffset", -144))


func CK4_SkypestDraw(obj: CK_object) -> void:
	if obj.bottomTI != 0:
		obj.velY = s16(CK_INT("CK4_SkypestHitCeilingYVel", 8))
		obj.yDirection = IN_motion_Down

	if obj.topTI != 0 and obj.rightTI == 0 and obj.leftTI == 0:
		obj.posY = u16(obj.posY + CK_INT("CK4_SkypestPreenYOffset", 0x80))
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_SkypestPreen0"))

	if obj.leftTI != 0:
		obj.velX = 0
		obj.xDirection = IN_motion_Left

	if obj.rightTI != 0:
		obj.velX = 0
		obj.xDirection = IN_motion_Right

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


## Setup all of the functions in this file.
func CK4_Obj1_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK4_Miragia0", &"CK4_Miragia0")
	CK_ACT_AddFunction("CK4_Miragia1", &"CK4_Miragia1")
	CK_ACT_AddFunction("CK4_Miragia2", &"CK4_Miragia2")
	CK_ACT_AddFunction("CK4_Miragia3", &"CK4_Miragia3")
	CK_ACT_AddFunction("CK4_Miragia4", &"CK4_Miragia4")
	CK_ACT_AddFunction("CK4_Miragia5", &"CK4_Miragia5")
	CK_ACT_AddFunction("CK4_Miragia6", &"CK4_Miragia6")
	CK_ACT_AddFunction("CK4_Miragia7", &"CK4_Miragia7")

	CK_ACT_AddFunction("CK4_CouncilWalk", &"CK4_CouncilWalk")

	CK_ACT_AddFunction("CK4_SlugMove", &"CK4_SlugMove")
	CK_ACT_AddFunction("CK4_SlugSlime", &"CK4_SlugSlime")
	CK_ACT_AddColFunction("CK4_SlugCol", &"CK4_SlugCol")

	CK_ACT_AddFunction("CK4_MushroomMove", &"CK4_MushroomMove")
	CK_ACT_AddColFunction("CK4_MushroomCol", &"CK4_MushroomCol")
	CK_ACT_AddFunction("CK4_MushroomDraw", &"CK4_MushroomDraw")

	CK_ACT_AddFunction("CK4_BirdRecover", &"CK4_BirdRecover")
	CK_ACT_AddColFunction("CK4_EggCol", &"CK4_EggCol")
	CK_ACT_AddFunction("CK4_BirdWalk", &"CK4_BirdWalk")
	CK_ACT_AddFunction("CK4_BirdFly", &"CK4_BirdFly")
	CK_ACT_AddColFunction("CK4_BirdCol", &"CK4_BirdCol")
	CK_ACT_AddColFunction("CK4_BirdHatchedCol", &"CK4_BirdHatchedCol")
	CK_ACT_AddFunction("CK4_BirdDraw", &"CK4_BirdDraw")
	CK_ACT_AddFunction("CK4_BirdLandingDraw", &"CK4_BirdLandingDraw")
	CK_ACT_AddFunction("CK4_EggshellDraw", &"CK4_EggshellDraw")
	CK_ACT_AddFunction("CK4_BirdFlyingDraw", &"CK4_BirdFlyingDraw")

	CK_ACT_AddFunction("CK4_ArachnutSearch", &"CK4_ArachnutSearch")
	CK_ACT_AddColFunction("CK4_ArachnutCol", &"CK4_ArachnutCol")
	CK_ACT_AddColFunction("CK4_ArachnutStunnedCol", &"CK4_ArachnutStunnedCol")

	CK_ACT_AddFunction("CK4_SkypestFly", &"CK4_SkypestFly")
	CK_ACT_AddColFunction("CK4_SkypestAirCol", &"CK4_SkypestAirCol")
	CK_ACT_AddColFunction("CK4_SkypestGroundCol", &"CK4_SkypestGroundCol")
	CK_ACT_AddFunction("CK4_SkypestTakeoff", &"CK4_SkypestTakeoff")
	CK_ACT_AddFunction("CK4_SkypestDraw", &"CK4_SkypestDraw")


# ===================================================================== ck4_obj2.c

func CK4_SpawnWormmouth(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Wormmouth
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_WormmouthSpawnYOffset", 0x8F))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_WormmouthMove0"))


func CK4_WormmouthLookRight(obj: CK_object) -> void:
	if ck_keenObj.posX > obj.posX:
		obj.xDirection = IN_motion_Right
		obj.currentAction = CK_GetActionByName("CK4_ACT_WormmouthMove0")


func CK4_WormmouthGoToPlayer(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Right if ck_keenObj.posX > obj.posX else IN_motion_Left


func CK4_WormmouthLookLeft(obj: CK_object) -> void:
	if ck_keenObj.posX < obj.posX:
		obj.xDirection = IN_motion_Left
		obj.currentAction = CK_GetActionByName("CK4_ACT_WormmouthMove0")


func CK4_WormmouthMove(obj: CK_object) -> void:
	var dx: int = s16(s16(ck_keenObj.posX) - s16(obj.posX))
	var dy: int = s16(s16(ck_keenObj.clipRects.unitY2) - s16(obj.clipRects.unitY2))

	if (dx < -CK_INT("CK4_WormmouthPeepXRadius", 0x300) or dx > CK_INT("CK4_WormmouthPeepXRadius", 0x300)) and US_RndT() < CK_INT("CK4_WormmouthPeepChance", 6):
		obj.currentAction = CK_GetActionByName("CK4_ACT_WormmouthPeep0")
		return

	if dy >= -CK_INT("CK4_WormmouthBiteYRadius", 0x100) and dy <= CK_INT("CK4_WormmouthBiteYRadius", 0x100):
		if ((obj.xDirection == IN_motion_Right and dx > CK_INT("CK4_WormmouthBiteRightMinX", 0x80) and dx < CK_INT("CK4_WormmouthBiteRightMaxX", 0x180)) or
				(obj.xDirection == IN_motion_Left and dx < CK_INT("CK4_WormmouthBiteLeftMaxX", -0x80) and dx > CK_INT("CK4_WormmouthBiteLeftMinX", -0x200))):
			SD_PlaySound(CK_SOUNDNUM("SOUND_WORMMOUTHBITE"))
			obj.currentAction = CK_GetActionByName("CK4_ACT_WormmouthBite0")


func CK4_WormmouthCheckShot(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK4_ACT_WormmouthStunned0"))


func CK4_WormmouthCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		if ((a.xDirection == IN_motion_Right and a.posX <= b.posX) or
				(a.xDirection == IN_motion_Left and a.posX >= b.posX)):
			CK_KillKeen()
			return

	CK4_WormmouthCheckShot(a, b)


# Clouds

func CK4_SpawnCloud(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Cloud
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_Right
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_CloudDormant0"))


func CK4_CloudMove(obj: CK_object) -> void:
	if US_RndT() < SD_GetSpriteSync():
		obj.xDirection = IN_motion_Left if ck_keenObj.posX < obj.posX else IN_motion_Right

	CK_PhysAccelHorz(obj, obj.xDirection, CK_INT("CK4_CloudXAccel", 10))

	if (ck_keenObj.clipRects.unitY2 >= obj.clipRects.unitY2 and
			ck_keenObj.clipRects.unitY1 - obj.clipRects.unitY2 <= 0x400 and
			obj.clipRects.unitX1 < ck_keenObj.clipRects.unitX2 and
			obj.clipRects.unitX2 > ck_keenObj.clipRects.unitX1):
		obj.currentAction = CK_GetActionByName("CK4_ACT_CloudCheckStrike0")


func CK4_CloudCheckStrike(obj: CK_object) -> void:
	CK_PhysAccelHorz(obj, obj.xDirection, CK_INT("CK4_CloudXAccel", 10))

	# Align the cloud on an 8px boundary so that the lightning bolt,
	# which has one shift, is aligned properly
	if ck_nextX < 0 and (obj.posX & 0x7F) + ck_nextX <= 0:
		ck_nextX = s16(-(obj.posX & 0x7F))
		obj.currentAction = CK_GetActionByName("CK4_ACT_CloudStrike0")

	if ck_nextX > 0 and (obj.posX & 0x7F) + ck_nextX >= 0x80:
		ck_nextX = s16(0x80 - (obj.posX & 0x7F))
		obj.currentAction = CK_GetActionByName("CK4_ACT_CloudStrike0")


func CK4_CloudDraw(obj: CK_object) -> void:
	if obj.leftTI != 0:
		obj.velX = 0
		obj.xDirection = IN_motion_Left
	elif obj.rightTI != 0:
		obj.velX = 0
		obj.xDirection = IN_motion_Right

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_CloudStrike(obj: CK_object) -> void:
	var bolt: CK_object = CK_GetNewObj(true)
	bolt.type = CT4_Bolt
	bolt.active = OBJ_EXISTS_ONLY_ONSCREEN
	bolt.clipped = CLIP_not
	bolt.posX = u16(obj.posX + CK_INT("CK4_CloudBoltXOffset", 0x100))
	bolt.posY = u16(obj.posY + CK_INT("CK4_CloudBoltYOffset", 0x100))
	CK_SetAction(bolt, CK_GetActionByName("CK4_ACT_Lightning0"))
	SD_PlaySound(CK_SOUNDNUM("SOUND_LIGHTNINGBOLT"))


func CK4_CloudCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_SetAction2(a, CK_GetActionByName("CK4_ACT_CloudAwaken0"))


# Berkeloids
# user1 = vertical offset for floating behaviour
# user2 = instantaneous floating velocity

func CK4_SpawnBerkeloid(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Berkeloid
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_BerkeloidSpawnYOffset", -0x200))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	obj.user2 = 8
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_BerkeloidMove0"))


func CK4_BerkeloidMove(obj: CK_object) -> void:
	if US_RndT() < CK_INT("CK4_BerkeloidTurnChance", 0x20):
		obj.xDirection = IN_motion_Left if ck_keenObj.posX < obj.posX else IN_motion_Right

	if US_RndT() < CK_INT("CK4_BerkeloidThrowChance", 8):
		obj.currentAction = CK_GetActionByName("CK4_ACT_BerkeloidThrow0")
	elif US_RndT() < CK_INT("CK4_BerkeloidTargetKeenChance", 0x40):
		var dx: int = s16(ck_keenObj.posX - obj.posX)
		var dy: int = s16(ck_keenObj.posY - obj.posY)

		if dy >= -CK_INT("CK4_BerkeloidTargetKeenYRadius", 0x100) and dy <= CK_INT("CK4_BerkeloidTargetKeenYRadius", 0x100):
			if ((obj.xDirection == IN_motion_Right and dx > 0) or
					(obj.xDirection == IN_motion_Left and dx < 0)):
				obj.currentAction = CK_GetActionByName("CK4_ACT_BerkeloidThrow0")
				SD_PlaySound(CK_SOUNDNUM("SOUND_BERKELOIDTHROW"))


func CK4_BerkeloidThrow(obj: CK_object) -> void:
	var ball: CK_object = CK_GetNewObj(true)
	ball.active = OBJ_EXISTS_ONLY_ONSCREEN
	ball.type = CT4_Berkeloid
	ball.posY = u16(obj.posY + CK_INT("CK4_BerkeloidFireballYOffset", 0x80))
	ball.velY = s16(CK_INT("CK4_BerkeloidFireballYVelocity", -8))
	if obj.xDirection == IN_motion_Right:
		ball.velX = s16(CK_INT("CK4_BerkeloidFireballXVelocity", 48))
		ball.posX = u16(obj.posX + CK_INT("CK4_BerkeloidFireballXOffsetRight", 0x200))
		ball.xDirection = IN_motion_Right
	else:
		ball.velX = s16(-CK_INT("CK4_BerkeloidFireballXVelocity", 48))
		ball.posX = u16(obj.posX + CK_INT("CK4_BerkeloidFireballXOffsetLeft", -0x100))
		ball.xDirection = IN_motion_Left

	CK_SetAction(ball, CK_GetActionByName("CK4_ACT_FireballAir0"))
	obj.visible = true


func CK4_BerkeloidThrowDone(obj: CK_object) -> void:
	obj.timeUntillThink = u16(CK_INT("CK4_BerkeloidThrowCooldown", 4))
	obj.visible = true


func CK4_BerkeloidCol(_a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_ShotHit(b)
	elif b.type == CT_Player:
		CK_KillKeen()


func CK4_FireballDraw(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0

	if obj.topTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_FIREBALLLAND"))
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_FireballGround0"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_BerkeloidHover(obj: CK_object) -> void:
	obj.user1 = s16(obj.user2 * SD_GetSpriteSync() + obj.user1)
	if obj.user1 > CK_INT("CK4_BerkeloidHoverMaxYOffset", 0):
		obj.user1 = s16(CK_INT("CK4_BerkeloidHoverMaxYOffset", 0))
		obj.user2 = s16(-CK_INT("CK4_BerkeloidHoverYVelocity", 8))
	elif obj.user1 < CK_INT("CK4_BerkeloidHoverMinYOffset", -0x100):
		obj.user1 = s16(CK_INT("CK4_BerkeloidHoverMinYOffset", -0x100))
		obj.user2 = s16(CK_INT("CK4_BerkeloidHoverYVelocity", 8))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY + obj.user1, obj.gfxChunk, false, obj.zLayer)


func CK4_BerkeloidDraw(obj: CK_object) -> void:
	# DrawFunc2 with hovering added
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		@warning_ignore("integer_division")
		obj.timeUntillThink = u16(US_RndT() / CK_INT("CK4_BerkeloidThinkTimeDivisor", 32))
		CK_SetAction2(obj, obj.currentAction)
	# Hit wall walking left; turn around and go right
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		@warning_ignore("integer_division")
		obj.timeUntillThink = u16(US_RndT() / CK_INT("CK4_BerkeloidThinkTimeDivisor", 32))
		CK_SetAction2(obj, obj.currentAction)
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX * 2)
		obj.xDirection = s16(-obj.xDirection)
		@warning_ignore("integer_division")
		obj.timeUntillThink = u16(US_RndT() / CK_INT("CK4_BerkeloidThinkTimeDivisor", 32))
		CK_SetAction2(obj, obj.currentAction)

	CK4_BerkeloidHover(obj)


# Foot and worms
func CK4_SpawnInchworm(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Inchworm
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Inchworm0"))
	@warning_ignore("integer_division")
	obj.actionTimer = s16(US_RndT() / CK_INT("CK4_InchwormThinkTimeDivisor", 32))  # So the worms don't all inch in unison?


func CK4_SpawnFoot(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Foot
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY - CK_INT("CK4_FootSpawnYOffsetTiles", 3)))
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Foot1"))


func CK4_InchwormMove(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Left if obj.posX > ck_keenObj.posX else IN_motion_Right


func CK4_InchwormCol(a: CK_object, b: CK_object) -> void:
	var lastTimeCount: int = SD_GetLastTimeCount()

	if b.type == CT4_Inchworm:
		# Here, DOS keen stores the low word of the 32-bit lastTimeCount = user1
		# Omnispeak can store the whole thing. Either way, it's irrelevant, because
		# user1 is just being used as a "static" variable for this function for this frame
		# (Quirk kept: user1 is an int16_t compared with the int32_t count, so
		# once lastTimeCount passes 32767 they never match and the count
		# restarts on every call, as in omnispeak.)
		if a.user1 != lastTimeCount:
			a.user1 = s16(lastTimeCount)
			a.user2 = 0

		a.user2 = s16(a.user2 + 1)
		if a.user2 == CK_INT("CK4_InchworkMaxCount", 11):
			# Turn worm into foot
			SD_PlaySound(CK_SOUNDNUM("SOUND_FOOTAPPEAR"))
			a.posY = u16(a.posY - CK_INT("CK4_InchwormFootYOffset", 0x500))
			a.type = CT4_Foot
			CK_SetAction2(a, CK_GetActionByName("CK4_ACT_Foot1"))

			# Spawn Foot poofs
			var poof: CK_object = CK_GetNewObj(true)
			poof.posX = u16(a.posX + CK_INT("CK4_FootPoof1XOffset", -0x80))
			poof.posY = u16(a.posY + CK_INT("CK4_FootPoof1YOffset", 0x100))
			poof.zLayer = PRIORITIES - 1
			CK_SetAction(poof, CK_GetActionByName("CK4_ACT_FootPoof0"))

			poof = CK_GetNewObj(true)
			poof.posX = u16(a.posX + CK_INT("CK4_FootPoof2XOffset", 0x100))
			poof.posY = u16(a.posY + CK_INT("CK4_FootPoof2YOffset", 0x180))
			poof.zLayer = PRIORITIES - 1
			CK_SetAction(poof, CK_GetActionByName("CK4_ACT_FootPoof0"))

			poof = CK_GetNewObj(true)
			poof.posX = u16(a.posX + CK_INT("CK4_FootPoof3XOffset", 0x280))
			poof.posY = u16(a.posY + CK_INT("CK4_FootPoof3YOffset", 0x100))
			poof.zLayer = PRIORITIES - 1
			CK_SetAction(poof, CK_GetActionByName("CK4_ACT_FootPoof0"))

			poof = CK_GetNewObj(true)
			poof.posX = u16(a.posX + CK_INT("CK4_FootPoof4XOffset", 0))
			poof.posY = u16(a.posY + CK_INT("CK4_FootPoof4YOffset", -0x80))
			poof.zLayer = PRIORITIES - 1
			CK_SetAction(poof, CK_GetActionByName("CK4_ACT_FootPoof0"))

			# Remove all other worms on level (CK_RemoveObj keeps o.next, as in C)
			var o: CK_object = ck_keenObj
			while o != null:
				if o.type == CT4_Inchworm:
					CK_RemoveObj(o)
				o = o.next


func CK4_FootCol(_a: CK_object, _b: CK_object) -> void:
	# Just an empty function :(
	pass


# Bounder

func CK4_SpawnBounder(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Bounder
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_BounderSpawnYOffset", -0x80))
	obj.yDirection = IN_motion_Down
	obj.xDirection = IN_motion_None
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Bounder0"))


func CK4_BounderCheckShot(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		a.user3 = 0
		a.user2 = 0
		a.user1 = 0
		a.user4 = a.type
		CK_ShotHit(b)
		CK_SetAction2(a, CK_GetActionByName("CK4_ACT_BounderStunned0"))
		a.type = CT4_StunnedCreature
		a.velY = s16(a.velY + CK_INT("CK4_BounderDeathHopVelocity", -32))


func CK4_BounderDraw(obj: CK_object) -> void:
	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		obj.user2 = s16(obj.user2 + 1)
		if CK_ObjectVisible(obj):
			SD_PlaySound(CK_SOUNDNUM("SOUND_MUSHROOMLEAP"))

		obj.velY = s16(CK_INT("CK4_BounderBounceYVelocity", -50))

		if ck_keenState.platform == obj:
			obj.user2 = 0
			if ck_keenObj.clipRects.unitX1 < obj.clipRects.unitX1 - CK_INT("CK4_BounderRideRadius", 0x40):
				obj.xDirection = IN_motion_Left
			elif ck_keenObj.clipRects.unitX2 > obj.clipRects.unitX2 + CK_INT("CK4_BounderRideRadius", 0x40):
				obj.xDirection = IN_motion_Right
			else:
				obj.xDirection = IN_motion_None
			obj.velX = s16(obj.xDirection * CK_INT("CK4_BounderRideXVel", 24))
		elif obj.user2 > CK_INT("CK4_BounderBounceCycle", 2) and obj.user1 != 0:
			# Change direction every third bounce, and not if just changed direction
			obj.user1 = 0
			var r: int = s16(US_RndT())
			if r < CK_INT("CK4_BounderBounceLeftChance", 100):
				obj.xDirection = IN_motion_Left
			elif r < CK_INT("CK4_BounderBounceRightChance", 200):
				obj.xDirection = IN_motion_Right
			else:
				obj.xDirection = IN_motion_None

			obj.velX = s16(obj.xDirection * CK_INT("CK4_BounderBounceXVel", 24))
		else:
			# Bounce in same direction; can potentially change direction on next bounce
			obj.user1 = 1
			obj.velX = 0
			obj.xDirection = IN_motion_None
			CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_Bounder0"))

		if obj.xDirection != IN_motion_None:
			CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_BounderMoveHorz0"))
		else:
			CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_Bounder0"))

	if obj.leftTI != 0 or obj.rightTI != 0:
		obj.xDirection = s16(-obj.xDirection)
		obj.velX = s16(-obj.velX)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Licks

func CK4_SpawnLick(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Lick
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	@warning_ignore("integer_division")
	obj.timeUntillThink = u16(US_RndT() / CK_INT("CK4_LickThinkTimeDivisor", 0x40))
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_LickHop2"))


func CK4_LickMove(obj: CK_object) -> void:
	obj.xDirection = IN_motion_Left if obj.posX > ck_keenObj.posX else IN_motion_Right

	var dx: int = s16(ck_keenObj.posX - obj.posX)
	var dy: int = s16(ck_keenObj.posY - obj.posY)

	if dy >= -CK_INT("CK4_LickFlameYRadius", 0x100) and dy <= CK_INT("CK4_LickFlameYRadius", 0x100):
		if ((obj.xDirection == IN_motion_Right and dx > CK_INT("CK4_LickFlameRightMinX", -0x20) and dx < CK_INT("CK4_LickFlameRightMaxX", 0x180)) or
				(obj.xDirection == IN_motion_Left and dx < CK_INT("CK4_LickFlameLeftMaxX", 0x20) and dx > CK_INT("CK4_LickFlameLeftMinX", -0x200))):
			SD_PlaySound(CK_SOUNDNUM("SOUND_LICKFLAME"))
			CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_LickFlame0"))
			return

	# CK_Cross_abs(dx): dx is promoted to int, so absi matches
	if absi(dx) > CK_INT("CK4_LickLongHopRadius", 0x300):
		obj.velX = s16(obj.xDirection * CK_INT("CK4_LickLongHopXVelocity", 32))
		obj.velY = s16(CK_INT("CK4_LickLongHopYVelocity", -32))
	else:
		obj.velX = s16(obj.xDirection * CK_INT("CK4_LickShortHopXVelocity", 16))
		obj.velY = s16(CK_INT("CK4_LickShortHopYVelocity", -16))


func CK4_LickCheckShot(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		CK_StunCreature(a, b, CK_GetActionByName("CK4_ACT_LickStunned0"))
		a.velY = s16(a.velY + CK_INT("CK4_LickDeathHopYVelocity", 16))


func CK4_LickCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		if ((a.xDirection == IN_motion_Right and ck_keenObj.posX > a.posX) or
				(a.xDirection == IN_motion_Left and ck_keenObj.posX < a.posX)):
			CK_KillKeen()
			return

	CK4_LickCheckShot(a, b)


func CK4_LickDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_LickHop3"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Platforms (CK4-unique behaviour)

func CK4_SpawnAxisPlatform(tileX: int, tileY: int, direction: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT4_Platform
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.zLayer = 0
	obj.posX = u16(tileX << 8)
	obj.posY = u16(tileY << 8)

	match direction:
		0:
			obj.xDirection = 0
			obj.yDirection = -1
		1:
			obj.xDirection = 1
			obj.yDirection = 0
		2:
			obj.xDirection = 0
			obj.yDirection = 1
		3:
			obj.xDirection = -1
			obj.yDirection = 0

	CK_SetAction(obj, CK_GetActionByName("CK_ACT_AxisPlatform"))


# AxisPlatformMove in ck_obj.c

## The flames are sprite entries kept as 16-bit offsets in user2 and user3
## (RF_*SpriteDrawUsing16BitOffset take the field and return its new value).
func CK4_PlatformDraw(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	# Draw the flames

	@warning_ignore("integer_division")
	var di: int = s16((SD_GetLastTimeCount() / 4) & 1)

	if obj.xDirection == IN_motion_Right:
		obj.user2 = RF_AddSpriteDrawUsing16BitOffset(obj.user2, obj.posX - 0x10, obj.posY + 0x30, di + 485, false, PRIORITIES - 4)
		if obj.user3 != 0:
			obj.user3 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user3)
	elif obj.xDirection == IN_motion_Left:
		if obj.user2 != 0:
			obj.user2 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user2)
		obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + 0x300, obj.posY + 0x50, di + 485, false, PRIORITIES - 3)
	elif obj.yDirection == IN_motion_Up:
		obj.user2 = RF_AddSpriteDrawUsing16BitOffset(obj.user2, obj.posX + 0x20, obj.posY + 0x90, di + 489, false, PRIORITIES - 4)
		obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + 0x2E0, obj.posY + 0x80, di + 487, false, PRIORITIES - 4)
	elif obj.yDirection == IN_motion_Down:
		if di != 0:
			obj.user2 = RF_AddSpriteDrawUsing16BitOffset(obj.user2, obj.posX + 0x20, obj.posY + 0x90, di + 489, false, PRIORITIES - 4)
			obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + 0x2E0, obj.posY + 0x80, di + 487, false, PRIORITIES - 4)
		else:
			if obj.user2 != 0:
				obj.user2 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user2)
			if obj.user3 != 0:
				obj.user3 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user3)


## Setup all of the functions in this file.
func CK4_Obj2_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK4_WormmouthLookRight", &"CK4_WormmouthLookRight")
	CK_ACT_AddFunction("CK4_WormmouthGoToPlayer", &"CK4_WormmouthGoToPlayer")
	CK_ACT_AddFunction("CK4_WormmouthLookLeft", &"CK4_WormmouthLookLeft")
	CK_ACT_AddFunction("CK4_WormmouthMove", &"CK4_WormmouthMove")
	CK_ACT_AddColFunction("CK4_WormmouthCheckShot", &"CK4_WormmouthCheckShot")
	CK_ACT_AddColFunction("CK4_WormmouthCol", &"CK4_WormmouthCol")

	CK_ACT_AddFunction("CK4_CloudMove", &"CK4_CloudMove")
	CK_ACT_AddFunction("CK4_CloudDraw", &"CK4_CloudDraw")
	CK_ACT_AddFunction("CK4_CloudCheckStrike", &"CK4_CloudCheckStrike")
	CK_ACT_AddFunction("CK4_CloudStrike", &"CK4_CloudStrike")
	CK_ACT_AddColFunction("CK4_CloudCol", &"CK4_CloudCol")

	CK_ACT_AddFunction("CK4_BerkeloidMove", &"CK4_BerkeloidMove")
	CK_ACT_AddFunction("CK4_BerkeloidThrow", &"CK4_BerkeloidThrow")
	CK_ACT_AddFunction("CK4_BerkeloidThrowDone", &"CK4_BerkeloidThrowDone")
	CK_ACT_AddColFunction("CK4_BerkeloidCol", &"CK4_BerkeloidCol")
	CK_ACT_AddFunction("CK4_FireballDraw", &"CK4_FireballDraw")
	CK_ACT_AddFunction("CK4_BerkeloidHover", &"CK4_BerkeloidHover")
	CK_ACT_AddFunction("CK4_BerkeloidDraw", &"CK4_BerkeloidDraw")

	CK_ACT_AddFunction("CK4_InchwormMove", &"CK4_InchwormMove")
	CK_ACT_AddColFunction("CK4_InchwormCol", &"CK4_InchwormCol")
	CK_ACT_AddColFunction("CK4_FootCol", &"CK4_FootCol")

	CK_ACT_AddColFunction("CK4_BounderCheckShot", &"CK4_BounderCheckShot")
	CK_ACT_AddFunction("CK4_BounderDraw", &"CK4_BounderDraw")

	CK_ACT_AddFunction("CK4_LickMove", &"CK4_LickMove")
	CK_ACT_AddColFunction("CK4_LickCheckShot", &"CK4_LickCheckShot")
	CK_ACT_AddColFunction("CK4_LickCol", &"CK4_LickCol")
	CK_ACT_AddFunction("CK4_LickDraw", &"CK4_LickDraw")

	CK_ACT_AddFunction("CK4_PlatformDraw", &"CK4_PlatformDraw")


# ===================================================================== ck4_obj3.c

func CK4_SpawnSmirky(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Smirky
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 1
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_SmirkySpawnYOffset", -0x180))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Smirky0"))


func CK4_SmirkySearch(obj: CK_object) -> void:
	obj.currentAction = CK_GetActionByName("CK4_ACT_SmirkyJump0")

	# Jump for item goodies
	# (Quirk kept: an item's unitY2 can't be both above the smirky's unitY1
	# and below unitY1 + 3 tiles, so this never fires, as in omnispeak.)
	var o: CK_object = ck_keenObj
	while o != null:
		if o.type == CT4_Item:
			if (o.active == OBJ_ACTIVE and
					o.clipRects.unitX2 > obj.clipRects.unitX1 and
					o.clipRects.unitX1 < obj.clipRects.unitX2 and
					o.clipRects.unitY2 < obj.clipRects.unitY1 and
					o.clipRects.unitY2 > obj.clipRects.unitY1 + RF_TileToUnit(CK_INT("CK4_SmirkyHeightInTiles", 3))):
				obj.velX = s16(CK_INT("CK4_SmirkyJumpXVelocity", 0))
				obj.velY = s16(CK_INT("CK4_SmirkyJumpYVelocity", -48))
				return
		o = o.next

	# Jump for tile goodies
	# DOS Keen increments a far pointer to the foreground plane, but it is
	# semantically equivalent to calculate the offset on every iteration
	for y: int in range(obj.clipRects.tileY1 - CK_INT("CK4_SmirkyHeightInTiles", 3), obj.clipRects.tileY1):
		for x: int in range(obj.clipRects.tileX1, obj.clipRects.tileX2 + 1):
			var mf: int = TI_ForeMisc(CA_TileAtPos(x, y, 1)) & 0x7F
			if mf == MF_Centilife or (mf >= MF_Points100 and mf <= MF_Stunner):
				obj.velX = s16(CK_INT("CK4_SmirkyJumpXVelocity", 0))
				obj.velY = s16(CK_INT("CK4_SmirkyJumpYVelocity", -48))
				return

	# Decide to teleport for some reason
	if obj.user1 >= CK_INT("CK4_SmirkyTeleCycle", 2):
		obj.currentAction = CK_GetActionByName("CK4_ACT_SmirkyTele0")
		return

	# Decide to hop to the side if there's something to land on
	for i: int in range(4):
		var y: int = obj.clipRects.tileY2 - 2 + i
		var x: int = obj.clipRects.tileXmid + obj.xDirection * 4
		var tf: int = TI_ForeTop(CA_TileAtPos(x, y, 1))
		if tf != 0:
			obj.velX = s16(obj.xDirection * CK_INT("CK4_SmirkyHopXVelocity", 20))
			obj.velY = s16(CK_INT("CK4_SmirkyHopYVelocity", -24))
			return

	# Decide to teleport if counter hits threshold
	obj.user1 = s16(obj.user1 + 1)
	if obj.user1 == CK_INT("CK4_SmirkyTeleCycle", 2):
		SD_PlaySound(CK_SOUNDNUM("SOUND_SMIRKYTELE"))
		obj.currentAction = CK_GetActionByName("CK4_ACT_SmirkyTele0")
		return

	# Finally, just turn around and hop back where we came from
	obj.velX = s16(-obj.xDirection * CK_INT("CK4_SmirkyHopXVelocity", 20))
	obj.velY = s16(CK_INT("CK4_SmirkyHopYVelocity", -24))


func CK4_SmirkyTeleport(obj: CK_object) -> void:
	obj.user1 = 0  # reset tleport timer
	var o: CK_object = ck_keenObj
	while o != null:
		if o.type == CT4_Item:
			obj.posX = u16(o.posX + CK_INT("CK4_SmirkyTeleItemXOffset", -0x80))
			obj.posY = o.posY
			CK_SetAction(obj, CK_GetActionByName("CK4_ACT_SmirkyTele0"))
		o = o.next

	# Remove smirky if all the treasure items are gone
	# (Quirk kept: the loop above never breaks, so o is always NULL here and
	# the smirky is always removed, as in omnispeak.)
	if o == null:
		CK_RemoveObj(obj)
		return


func CK4_SmirkyCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT4_Item:
		b.type = CT_Friendly
		b.zLayer = PRIORITIES - 1
		CK_SetAction2(b, CK_GetActionByName("CK4_ACT_StolenItem0"))
		SD_PlaySound(CK_SOUNDNUM("SOUND_SMIRKYSTEAL"))
	elif b.type == CT_Stunner:
		a.user3 = 0
		a.user2 = 0
		a.user1 = 0
		a.user4 = a.type
		a.type = CT4_StunnedCreature
		CK_ShotHit(b)
		CK_SetAction2(a, CK_GetActionByName("CK4_ACT_SmirkyStunned0"))
		a.velY = s16(a.velY + CK_INT("CK4_SmirkyDeathHopYVelocity", -16))


## CK4_SmirkyCheckTiles' function-static emptyTile (C: static uint16_t
## emptyTile = 0). Suffixed: ck_keen.c has a file-static emptyTile of its own.
const emptyTile_ck4obj3: PackedInt32Array = [0]


func CK4_SmirkyCheckTiles(obj: CK_object) -> void:
	for y: int in range(obj.clipRects.tileY1, obj.clipRects.tileY2 + 1):
		for x: int in range(obj.clipRects.tileX1, obj.clipRects.tileX2 + 1):
			var mf: int = TI_ForeMisc(CA_TileAtPos(x, y, 1)) & 0x7F
			if mf == MF_Centilife or (mf >= MF_Points100 and mf <= MF_Stunner):
				# emptyTile: actually this is the same address in memory as the
				# lifewater drop emptytile... suggesting that it's a global var
				RF_ReplaceTiles(emptyTile_ck4obj3, 0, 1, x, y, 1, 1)

				var o: CK_object = CK_GetNewObj(true)
				o.type = CT_Friendly
				o.zLayer = PRIORITIES - 1
				o.clipped = CLIP_not
				o.posX = u16(RF_TileToUnit(x))
				o.posY = u16(RF_TileToUnit(y))
				o.active = OBJ_EXISTS_ONLY_ONSCREEN
				CK_SetAction2(o, CK_GetActionByName("CK4_ACT_StolenItem0"))


func CK4_SmirkyDraw(obj: CK_object) -> void:
	CK4_SmirkyCheckTiles(obj)

	if obj.topTI != 0:
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_Smirky0"))

	if obj.leftTI != 0 or obj.rightTI != 0:
		obj.user1 = s16(obj.user1 + 1)
		obj.xDirection = s16(-obj.xDirection)
		obj.velX = 0

	if obj.topTI != 0:
		obj.velY = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Mimrocks

func CK4_SpawnMimrock(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Mimrock
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 1
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) - CK_INT("CK4_MimrockSpawnYOffset", 0xD0))
	obj.xDirection = IN_motion_Right
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Mimrock0"))


# CK_Cross_abs((int16_t)(...)): the int16_t is promoted to int, so absi(s16(...)) matches.
func CK4_MimrockWait(obj: CK_object) -> void:
	if absi(s16(obj.clipRects.unitY2 - ck_keenObj.clipRects.unitY2)) <= CK_INT("CK4_MimrockWaitYRadius", 0x500):
		if absi(s16(obj.posX - ck_keenObj.posX)) > CK_INT("CK4_MimrockWaitXRadius", 0x300):
			if ck_keenObj.posX < obj.posX:
				if ck_keenObj.xDirection == IN_motion_Left:
					obj.xDirection = IN_motion_Left
					obj.currentAction = CK_GetActionByName("CK4_ACT_MimrockWalk0")
			else:
				if ck_keenObj.xDirection == IN_motion_Right:
					obj.xDirection = IN_motion_Right
					obj.currentAction = CK_GetActionByName("CK4_ACT_MimrockWalk0")


func CK4_MimrockCheckJump(obj: CK_object) -> void:
	if ((absi(s16(obj.clipRects.unitY2 - ck_keenObj.clipRects.unitY2)) <= CK_INT("CK4_MimrockJumpYRadius", 0x500)) and
			(obj.xDirection == ck_keenObj.xDirection)):
		if absi(s16(obj.posX - ck_keenObj.posX)) < CK_INT("CK4_MimrockJumpXRadius", 0x400):
			obj.velX = s16(obj.xDirection * CK_INT("CK4_MimrockJumpXVelocity", 20))
			obj.velY = s16(CK_INT("CK4_MimrockJumpYVelocity", -40))
			ck_nextY = s16(obj.velY * SD_GetSpriteSync())
			obj.currentAction = CK_GetActionByName("CK4_ACT_MimrockJump0")
	else:
		obj.currentAction = CK_GetActionByName("CK4_ACT_Mimrock0")


func CK4_MimrockCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Stunner:
		a.user3 = 0
		a.user2 = 0
		a.user1 = 0
		a.user4 = a.type
		a.type = CT4_StunnedCreature
		CK_ShotHit(b)
		CK_SetAction2(a, CK_GetActionByName("CK4_ACT_MimrockStunned0"))
		a.velY = s16(a.velY + CK_INT("CK4_MimrockDeathHopYVelocity", -16))


func CK4_MimrockAirCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_KillKeen()
	else:
		CK4_MimrockCol(a, b)


func CK4_MimrockJumpDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_MIMROCKJUMP"))
		obj.velY = s16(CK_INT("CK4_MimrockBounceYVelocity", -20))
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_MimrockBounce0"))

	if obj.leftTI != 0 or obj.topTI != 0:
		obj.velX = 0

	if obj.topTI != 0 or obj.bottomTI != 0:
		obj.velY = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_MimrockBounceDraw(obj: CK_object) -> void:
	if obj.topTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_MIMROCKJUMP"))
		CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_Mimrock0"))

	if obj.leftTI != 0 or obj.rightTI != 0:
		obj.velX = 0

	if obj.topTI != 0:
		obj.velY = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Dopefish

func CK4_SpawnDopefish(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Dopefish
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 2
	obj.clipped = CLIP_simple
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_DopefishSpawnYOffset", -0x300))
	obj.xDirection = IN_motion_Right if US_RndT() < 0x80 else IN_motion_Left
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_DopefishSwim0"))


func CK4_KillKeenUnderwater(_obj: CK_object) -> void:
	ck_gameState.levelState = LS_Died


func CK4_DopefishMove(obj: CK_object) -> void:
	if obj.user1 == 0:
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left

	CK_PhysAccelHorz2(obj, obj.xDirection, CK_INT("CK4_DopefishXAccel", 10))

	if obj.posY < ck_keenObj.posY:
		CK_PhysAccelVert1(obj, 1, CK_INT("CK4_DopefishYAccel", 10))
	else:
		CK_PhysAccelVert1(obj, -1, CK_INT("CK4_DopefishYAccel", 10))


## user4 holds the eaten object as a 16-bit offset (uint16_t parameter of
## CK_ConvertObj16BitOffsetToPointer, hence u16).
func CK4_DopefishEat(obj: CK_object) -> void:
	var si: CK_object = obj

	si = CK_ConvertObj16BitOffsetToPointer(u16(obj.user4))
	var dy: int = s16(si.posY - CK_INT("CK4_DopefishMouthYOffset", 0x100) - obj.posY)
	var dx: int
	if obj.xDirection == IN_motion_Right:
		dx = s16((si.clipRects.unitX2 + CK_INT("CK4_DopefishMouthXOffset", 0x20)) - obj.clipRects.unitX2)
	else:
		dx = s16((si.clipRects.unitX1 - CK_INT("CK4_DopefishMouthXOffset", 0x20)) - obj.clipRects.unitX1)

	if dx < 0:
		ck_nextX = s16(SD_GetSpriteSync() * -CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextX < dx:
			ck_nextX = dx
	else:
		ck_nextX = s16(SD_GetSpriteSync() * CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextX > dx:
			ck_nextX = dx

	if dy < 0:
		ck_nextY = s16(SD_GetSpriteSync() * -CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextY < dy:
			ck_nextY = dy
	else:
		ck_nextY = s16(SD_GetSpriteSync() * CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextY > dy:
			ck_nextY = dy

	if ck_nextX == dx and ck_nextY == dy:
		if si == ck_keenObj:
			CK_SetAction2(si, CK_GetActionByName("CK4_ACT_KeenEaten1"))
		elif si.currentAction.next != null:
			CK_SetAction2(si, si.currentAction.next)
		else:
			CK_RemoveObj(si)

		obj.currentAction = CK_GetActionByName("CK4_ACT_DopefishBurp0")


func CK4_DopefishAfterBurp(obj: CK_object) -> void:
	# Move back to where the eating sequence started
	# so that the dopefish doesn't get caught in a wall
	var dy: int = s16(obj.user3 - obj.posY)
	var dx: int = s16(obj.user2 - obj.posX)

	if dx < 0:
		ck_nextX = s16(SD_GetSpriteSync() * -CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextX < dx:
			ck_nextX = dx
	else:
		ck_nextX = s16(SD_GetSpriteSync() * CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextX > dx:
			ck_nextX = dx

	if dy < 0:
		ck_nextY = s16(SD_GetSpriteSync() * -CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextY < dy:
			ck_nextY = dy
	else:
		ck_nextY = s16(SD_GetSpriteSync() * CK_INT("CK4_DopefishEatVelocity", 32))
		if ck_nextY > dy:
			ck_nextY = dy

	if ck_nextX == dx and ck_nextY == dy:
		obj.currentAction = obj.currentAction.next
		obj.clipped = CLIP_simple


func CK4_DopefishBurp(obj: CK_object) -> void:
	# Spawn a bubble
	var bubble: CK_object = CK_GetNewObj(true)
	bubble.posX = u16(obj.posX + CK_INT("CK4_DopefishBurpBubbleXOffset", 0x380))
	bubble.posY = u16(obj.posY + CK_INT("CK4_DopefishBurpBubbleYOffset", 0x200))
	bubble.type = CT_Friendly
	bubble.zLayer = PRIORITIES - 1
	bubble.active = OBJ_EXISTS_ONLY_ONSCREEN
	bubble.clipped = CLIP_not
	bubble.velY = s16(CK_INT("CK4_DopefishBurpBubbleYVelocity", -20))
	bubble.velX = s16(CK_INT("CK4_DopefishBurpBubbleXVelocity", 4))
	CK_SetAction(bubble, CK_GetActionByName("CK4_ACT_DopeBubble0"))
	SD_PlaySound(CK_SOUNDNUM("SOUND_DOPEFISHBURP"))


func CK4_Bubbles(obj: CK_object) -> void:
	CK_Glide(obj)
	if US_RndT() < SD_GetSpriteSync() * CK_INT("CK4_DopefishBubbleWaveChance", 16):
		obj.velX = s16(-obj.velX)

	if obj.posY < CK_INT("CK4_DopefishBurpBubbleMaxY", 0x300):
		CK_RemoveObj(obj)


func CK4_DopefishCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT4_Schoolfish:
		CK_SetAction2(b, CK_GetActionByName("CK4_ACT_SchoolfishEaten0"))
	elif b.type == CT_Player and not ck_godMode:
		b.type = CT_Friendly
		b.clipped = CLIP_not
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENDIE"))
		CK_SetAction2(b, CK_GetActionByName("CK4_ACT_KeenEaten0"))
	else:
		return

	a.user2 = s16(a.posX)
	a.user3 = s16(a.posY)
	a.user4 = s16(CK_ConvertObjPointerTo16BitOffset(b))
	a.xDirection = IN_motion_Left if b.clipRects.unitXmid < a.clipRects.unitXmid else IN_motion_Right
	CK_SetAction2(a, CK_GetActionByName("CK4_ACT_DopefishEat0"))
	a.clipped = CLIP_not


func CK4_FishDraw(obj: CK_object) -> void:
	if obj.bottomTI != 0 or obj.topTI != 0:
		if obj.user1 == 0:
			obj.user1 += 1

	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0
		obj.xDirection = s16(-obj.xDirection)
		obj.user1 = 1

	if obj.bottomTI == 0 and obj.topTI == 0:
		obj.user1 = 0

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_SpawnSchoolfish(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Schoolfish
	obj.active = OBJ_ACTIVE
	obj.clipped = CLIP_simple
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_Right
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_SchoolfishSwim0"))


func CK4_SchoolfishMove(obj: CK_object) -> void:
	if obj.user1 == 0:
		obj.xDirection = IN_motion_Right if obj.posX < ck_keenObj.posX else IN_motion_Left

	CK_PhysAccelHorz2(obj, obj.xDirection, CK_INT("CK4_SchoolfishXVelocity", 10))

	if obj.posY < ck_keenObj.posY:
		CK_PhysAccelVert1(obj, 1, CK_INT("CK4_SchoolfishYVelocity", 10))
	else:
		CK_PhysAccelVert1(obj, -1, CK_INT("CK4_SchoolfishYVelocity", 10))


# Sprites - the underwater kind

func CK4_SpawnSprite(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Sprite
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.clipped = CLIP_not
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.user1 = s16(obj.posY)
	obj.xDirection = IN_motion_Right
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Sprite0"))


func CK4_SpritePatrol(obj: CK_object) -> void:
	CK_PhysAccelVert1(obj, obj.yDirection, CK_INT("CK4_SpritePatrolYAccel", 8))
	if obj.user1 - obj.posY > CK_INT("CK4_SpritePatrolYRadius", 0x20):
		obj.yDirection = IN_motion_Down

	if obj.posY - obj.user1 > CK_INT("CK4_SpritePatrolYRadius", 0x20):
		obj.yDirection = IN_motion_Up

	if (ck_keenObj.clipRects.unitY1 < obj.clipRects.unitY2 and
			ck_keenObj.clipRects.unitY2 > obj.clipRects.unitY1):
		obj.xDirection = IN_motion_Left if ck_keenObj.posX < obj.posX else IN_motion_Right
		obj.currentAction = CK_GetActionByName("CK4_ACT_SpriteAiming0")


func CK4_SpriteAim(obj: CK_object) -> void:
	if (ck_keenObj.clipRects.unitY1 < obj.clipRects.unitY2 and
			ck_keenObj.clipRects.unitY2 > obj.clipRects.unitY1):
		obj.currentAction = CK_GetActionByName("CK4_ACT_SpriteShooting0")


func CK4_SpriteShoot(obj: CK_object) -> void:
	var shot: CK_object = CK_GetNewObj(true)
	shot.posX = obj.posX
	shot.posY = u16(obj.posY + CK_INT("CK4_SpriteShotYOffset", 0x80))
	shot.zLayer = PRIORITIES - 4
	shot.type = CT4_Sprite
	shot.active = OBJ_EXISTS_ONLY_ONSCREEN
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSHOOT"))
	shot.xDirection = obj.xDirection
	CK_SetAction(shot, CK_GetActionByName("CK4_ACT_SpriteBullet0"))
	SD_PlaySound(CK_SOUNDNUM("SOUND_SPRITESHOOT"))


func CK4_ProjectileDraw(obj: CK_object) -> void:
	if obj.topTI != 0 or obj.rightTI != 0 or obj.bottomTI != 0 or obj.leftTI != 0:
		CK_RemoveObj(obj)
		return

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK4_SpawnMine(tileX: int, tileY: int, direction: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Mine
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))

	match direction:
		0:
			obj.xDirection = 0
			obj.yDirection = -1
		1:
			obj.xDirection = 1
			obj.yDirection = 0
		2:
			obj.xDirection = 0
			obj.yDirection = 1
		3:
			obj.xDirection = -1
			obj.yDirection = 0

	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Mine0"))


func CK4_MineCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_SetAction2(a, CK_GetActionByName("CK4_ACT_MineExplode0"))
		SD_PlaySound(CK_SOUNDNUM("SOUND_CK4MINEEXPLODE"))
		CK_KillKeen()


# Lindsey

func CK4_SpawnLindsey(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Lindsey
	obj.active = OBJ_ACTIVE
	obj.zLayer = PRIORITIES - 4
	obj.posX = u16(RF_TileToUnit(tileX))
	# obj->user1 = obj->posY = RF_TileToUnit(tileY) + ...: user1 gets posY's uint16_t value
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_LindseySpawnYOffset", -0x100))
	obj.user1 = s16(obj.posY)
	obj.yDirection = IN_motion_Down
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Lindsey0"))


func CK4_LindseyFloat(obj: CK_object) -> void:
	CK_PhysAccelVert1(obj, obj.yDirection, CK_INT("CK4_LindseyFloatYAccel", 8))
	if obj.user1 - obj.posY > CK_INT("CK4_LindseyFloatYRadius", 0x20):
		obj.yDirection = IN_motion_Down

	if obj.posY - obj.user1 > CK_INT("CK4_LindseyFloatYRadius", 0x20):
		obj.yDirection = IN_motion_Up


func CK4_SpawnDartGun(tileX: int, tileY: int, direction: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Turret  # CT_Friendly
	obj.active = OBJ_ACTIVE
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.clipped = CLIP_not
	obj.user1 = s16(direction)
	match direction:
		0:
			obj.posY = u16(obj.posY - 0x30)
			obj.posX = u16(obj.posX + 0x90)
			obj.gfxChunk = 0x17C

		1:
			obj.posX = u16(obj.posX + 0x80)
			obj.posY = u16(obj.posY + 0x50)
			obj.gfxChunk = 0x180

		2:
			obj.posX = u16(obj.posX + 0x90)
			obj.gfxChunk = 0x17E

		3:
			obj.posY = u16(obj.posY + 0x70)
			obj.posX = u16(obj.posX - 0x30)
			obj.gfxChunk = 0x182

	CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_DartGun0"))


func CK4_DartGun(obj: CK_object) -> void:
	var dart: CK_object = CK_GetNewObj(true)
	dart.posX = obj.posX
	dart.posY = obj.posY
	dart.type = CT4_EnemyShot
	dart.active = OBJ_EXISTS_ONLY_ONSCREEN

	match obj.user1:
		0:
			dart.xDirection = IN_motion_None
			dart.yDirection = IN_motion_Up
			CK_SetAction(dart, CK_GetActionByName("CK4_ACT_DartUp0"))
		1:
			dart.xDirection = IN_motion_Right
			dart.yDirection = IN_motion_None
			CK_SetAction(dart, CK_GetActionByName("CK4_ACT_DartHorz0"))
		2:
			dart.xDirection = IN_motion_None
			dart.yDirection = IN_motion_Down
			CK_SetAction(dart, CK_GetActionByName("CK4_ACT_DartDown0"))
		3:
			dart.xDirection = IN_motion_Left
			dart.yDirection = IN_motion_None
			CK_SetAction(dart, CK_GetActionByName("CK4_ACT_DartHorz0"))

	SD_PlaySound(CK_SOUNDNUM("SOUND_DARTSHOOT"))


# Wetsuit
func CK4_SpawnWetsuit(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)
	obj.type = CT4_Wetsuit
	obj.active = OBJ_ACTIVE
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY) + CK_INT("CK4_WetsuitSpawnYOffset", -0x100))
	CK_SetAction(obj, CK_GetActionByName("CK4_ACT_Wetsuit0"))


func CK4_WetsuitCol(_a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player and b.topTI != 0:
		ck_gameState.ck4_wetsuit = 1  # true
		SD_PlaySound(CK_SOUNDNUM("SOUND_FOOTAPPEAR"))
		CK4_ShowWetsuitMessage()
		#RF_ForceRefresh();
		ck_gameState.levelState = LS_LevelComplete


## Setup all of the functions in this file.
func CK4_Obj3_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK4_SmirkySearch", &"CK4_SmirkySearch")
	CK_ACT_AddFunction("CK4_SmirkyTeleport", &"CK4_SmirkyTeleport")
	CK_ACT_AddColFunction("CK4_SmirkyCol", &"CK4_SmirkyCol")
	CK_ACT_AddFunction("CK4_SmirkyDraw", &"CK4_SmirkyDraw")

	CK_ACT_AddFunction("CK4_MimrockWait", &"CK4_MimrockWait")
	CK_ACT_AddFunction("CK4_MimrockCheckJump", &"CK4_MimrockCheckJump")
	CK_ACT_AddColFunction("CK4_MimrockCol", &"CK4_MimrockCol")
	CK_ACT_AddColFunction("CK4_MimrockAirCol", &"CK4_MimrockAirCol")
	CK_ACT_AddFunction("CK4_MimrockJumpDraw", &"CK4_MimrockJumpDraw")
	CK_ACT_AddFunction("CK4_MimrockBounceDraw", &"CK4_MimrockBounceDraw")

	CK_ACT_AddFunction("CK4_KillKeenUnderwater", &"CK4_KillKeenUnderwater")
	CK_ACT_AddFunction("CK4_DopefishMove", &"CK4_DopefishMove")
	CK_ACT_AddFunction("CK4_DopefishEat", &"CK4_DopefishEat")
	CK_ACT_AddFunction("CK4_DopefishAfterBurp", &"CK4_DopefishAfterBurp")
	CK_ACT_AddFunction("CK4_DopefishBurp", &"CK4_DopefishBurp")
	CK_ACT_AddFunction("CK4_Bubbles", &"CK4_Bubbles")
	CK_ACT_AddColFunction("CK4_DopefishCol", &"CK4_DopefishCol")
	CK_ACT_AddFunction("CK4_FishDraw", &"CK4_FishDraw")
	CK_ACT_AddFunction("CK4_SchoolfishMove", &"CK4_SchoolfishMove")

	CK_ACT_AddFunction("CK4_SpritePatrol", &"CK4_SpritePatrol")
	CK_ACT_AddFunction("CK4_SpriteAim", &"CK4_SpriteAim")
	CK_ACT_AddFunction("CK4_SpriteShoot", &"CK4_SpriteShoot")
	CK_ACT_AddFunction("CK4_ProjectileDraw", &"CK4_ProjectileDraw")

	CK_ACT_AddColFunction("CK4_MineCol", &"CK4_MineCol")

	CK_ACT_AddFunction("CK4_LindseyFloat", &"CK4_LindseyFloat")

	CK_ACT_AddFunction("CK4_DartGun", &"CK4_DartGun")

	CK_ACT_AddColFunction("CK4_WetsuitCol", &"CK4_WetsuitCol")
