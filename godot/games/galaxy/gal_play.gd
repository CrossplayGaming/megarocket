# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's ck_play.c and ck_keen.c, by David Gow and the Omnispeak authors,
# GPL v2 or later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalPlay
extends GalAct
## The play loop, object manager, camera, status window and Keen himself (SIM-G-01e).
##
## ck_play.c's globals that other C files use (ck_objArray, ck_keenObj, ck_gameState,
## ck_inputFrame, its static tempObj as ck_tempObj, ...) are declared in gal_ck.gd; the
## ones only ck_play.c and ck_keen.c use are declared here. C's `continue` inside a
## `for (obj = ...; obj; obj = obj->next)` loop becomes an explicit step to `obj.next`
## before the `continue`. C's Quit does not return; where the C would go on to use what
## it failed to get, the port returns after Quit.

# ===================================================================== ck_play.c

# ck_objArray, ck_freeObject, ck_lastObject, ck_numObjects, ck_keenObj, the static
# tempObj (ck_tempObj), ck_activeX0Tile..ck_activeY1Tile, ck_debugActive and
# ck_gameState: gal_ck.gd.

var ck_slowMotionEnabled: bool = false

var ck_extraVBLs: int = 0

# ck_scrollDisabled, ck_godMode, ck_invincibilityTimer (int16_t), ck_scoreBoxObj,
# ck_pogoTimer and ck_inputFrame: gal_ck.gd. ck_scoreBoxEnabled, ck_twoButtonFiring,
# ck_fixJerkyMotion, ck_svgaCompatibility and ck_gamePadEnabled: gal_us.gd.
# game_in_progress, load_game_error: gal_us.gd. ck_startingSavedGame,
# ck_startingDifficulty, ck6_smashScreenDistance, ck6_smashScreenOfs: gal_ck.gd.


func CK_CountActiveObjects() -> void:
	var active: int = 0
	var inactive: int = 0

	var current: CK_object = ck_keenObj

	while current != null:
		if current.active != 0:
			active += 1
		else:
			inactive += 1
		current = current.next

	VL_FixRefreshBuffer()
	US_CenterWindow(18, 4)
	US_PrintF("Active Objects : %d\n", [active])
	US_PrintF("Inactive Object : %d\n", [inactive])
	VH_UpdateScreen()
	IN_WaitButton()


## The original's DebugMemory (F10-M): the manager's totals, then its picture of memory.
func CK_DebugMemory() -> void:
	VL_FixRefreshBuffer()
	US_CenterWindow(16, 7)
	US_CPrint("Memory Usage")
	US_CPrint("------------")
	@warning_ignore("integer_division")
	US_Print("Total     :%dk" % ((mm_mainmem + mm_emsmem + mm_xmsmem) / 1024))
	@warning_ignore("integer_division")
	US_Print("\nFree      :%dk" % (MM_FreeMemory(false) / 1024))
	@warning_ignore("integer_division")
	US_Print("\nWith purge:%dk" % (MM_FreeMemory(true) / 1024))
	VH_UpdateScreen()
	IN_WaitButton()    # IN_Ack
	MM_ShowMemory()
	IN_WaitButton()


func CK_BeginDemoRecord() -> void:
	VL_FixRefreshBuffer()
	US_CenterWindow(30, 3)
	US_SetPrintY(US_GetPrintY() + 3)
	US_Print("  Record a demo from level (0-21):")
	VH_UpdateScreen()
	var saveX: int = u16(US_GetPrintX())
	var saveY: int = u16(US_GetPrintY())

	var input: Array = US_LineInput(saveX, saveY, "", true, 2, 0)
	if input[0]:
		var level: int = _sscanf_d(input[1], 0)

		ck_gameState.currentLevel = s16(level)
		ck_gameState.levelState = LS_AboutToRecordDemo

		IN_DemoStartRecording(0x1000)


func CK_EndDemoRecord() -> void:
	var demoFileName: String = ""
	VL_FixRefreshBuffer()
	IN_DemoStopPlaying()
	US_CenterWindow(22, 3)

	US_SetPrintY(US_GetPrintY() + 6)

	US_Print("  Save as demo #(0-9):")

	VH_UpdateScreen()

	var saveX: int = u16(US_GetPrintX())
	var saveY: int = u16(US_GetPrintY())

	var input: Array = US_LineInput(saveX, saveY, "", true, 2, 0)
	if input[0]:
		var typed: String = input[1]
		var c0: int = typed.unicode_at(0) if typed.length() > 0 else 0
		if c0 >= 0x30 and c0 <= 0x39:
			var filename_pattern: String = CK_VAR_GetString("ck_demoFileName", FS_AdjustExtension("DEMO?.EXT"))
			# The C copies the pattern and its terminator into a FS_MAX_FILENAME_LEN
			# buffer, '?' replaced by the digit typed.
			if filename_pattern.length() >= FS_MAX_FILENAME_LEN:
				QuitF("Savegame filename \"%s\" too long! (Maximum length %d)", [filename_pattern, FS_MAX_FILENAME_LEN])
				return
			for i: int in range(filename_pattern.length()):
				if filename_pattern.unicode_at(i) == 0x3F:
					demoFileName += String.chr(c0)
				else:
					demoFileName += filename_pattern[i]
			IN_DemoSaveToFile(demoFileName, ck_gameState.currentLevel)
		IN_DemoFreeBuffer()


func CK_SpriteTest() -> void:
	VL_FixRefreshBuffer()
	US_CenterWindow(30, 17)
	US_CPrint("Sprite Test")
	US_CPrint("-----------")
	var startpy: int = US_GetPrintY()
	var startpx: int = (US_GetPrintX() + 0x38) & ~7

	var startpx_2: int = startpx + 0x28
	US_PrintF(
		"Chunk:\n" +
		"Width:\n" +
		"Height:\n" +
		"Orgx:\n" +
		"Orgy:\n" +
		"Xl:\n" +
		"Yl:\n" +
		"Xh:\n" +
		"Yh:\n" +
		"Shifts:\n" +
		"Mem:\n", [])

	var var8: int = US_GetPrintY()
	var offSprites: int = int(ca_gfxInfoE.offSprites)
	var numSprites: int = int(ca_gfxInfoE.numSprites)
	var chunk: int = offSprites
	var shifts: int = 0
	var selectedChunk: int = 0
	var oldShifts: int = 0

	while true:
		# max min chunks
		if selectedChunk != chunk or oldShifts != shifts:
			if chunk >= offSprites + numSprites:
				chunk = offSprites + numSprites - 1
			elif chunk < offSprites:
				chunk = offSprites

			var ste: Dictionary = VH_GetSpriteTableEntry(chunk - offSprites)
			var chunk_ptr: Variant = ca_graphChunks[chunk]

			VHB_Bar(startpx, startpy, 0x28, var8 - startpy, 0xF)
			US_SetPrintX(startpx)
			US_SetPrintY(startpy)

			US_PrintF("%d\n", [chunk])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.width])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.height])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.originX])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.originY])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.xl])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.yl])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.xh])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.yh])
			US_SetPrintX(startpx)
			US_PrintF("%d\n", [ste.shifts])
			US_SetPrintX(startpx)

			if chunk_ptr != null:
				# Omnispeak: don't store preshifted sprites
				# DOS: memused = (h*w) + (shifts-1) * (h*(w+1))
				# all of this is precomputed and stored in "spritetype" struct on sprite cache in DOS
				# so the DOS game here would read this information out of the spritetype struct
				US_PrintF("%d=", [int(ste.width) * int(ste.height) * 5])
			else:
				US_PrintF("-----", [])

			VHB_Bar(startpx_2, startpy, 0x6E, var8 - startpy, 0xF)
			if chunk_ptr != null:
				US_SetPrintX(startpx_2)
				US_SetPrintY(startpy)
				US_PrintF("Shift:%d\n", [shifts])
				VHB_DrawSprite(startpx_2 + shifts * 2 + 0x10, US_GetPrintY(), chunk)
			oldShifts = shifts
			selectedChunk = chunk

		VH_UpdateScreen()

		IN_WaitKey()
		var sc: int = IN_GetLastScan()
		IN_ClearKeysDown()

		if sc == IN_SC_LeftArrow:
			shifts -= 1
			if shifts == -1:
				shifts = 3
		elif sc == IN_SC_RightArrow:
			shifts += 1
			if shifts == 4:
				shifts = 0
		elif sc == IN_SC_DownArrow:
			chunk -= 1
		elif sc == IN_SC_PgDown:
			chunk -= 10
			if chunk < offSprites:
				chunk = offSprites
		elif sc == IN_SC_UpArrow:
			chunk += 1
		elif sc == IN_SC_PgUp:
			chunk += 10
			if chunk >= offSprites + numSprites:
				chunk = offSprites + numSprites
		elif sc == IN_SC_Escape:
			break
		if quitting:
			# the port's Quit returns; C's would have ended the program
			break


func CK_ItemCheat() -> void:
	for i: int in range(IN_SC_A, IN_SC_Z + 1):
		if i != IN_SC_B and i != IN_SC_A and i != IN_SC_Z:
			if IN_GetKeyState(i):
				return

	US_CenterWindow(20, 7)
	# TODO: PrintY+=2;
	US_CPrint(CK_STRING("ck_str_itemCheat"))
	VH_UpdateScreen()

	IN_WaitButton()
	RF_ForceRefresh()
	ck_gameState.numShots = 99
	ck_gameState.numLives = s16(ck_gameState.numLives + 1)
	ck_gameState.ck5_securityCard = 1
	ck_gameState.keyGems[3] = 1
	ck_gameState.keyGems[2] = 1
	ck_gameState.keyGems[1] = 1
	ck_gameState.keyGems[0] = 1


func CK_SetupObjArray() -> void:
	for i: int in range(CK_MAX_OBJECTS):
		# the last one's prev is &ck_objArray[CK_MAX_OBJECTS] (one past the end), reset below
		(ck_objArray[i] as CK_object).prev = ck_objArray[i + 1] if i + 1 < CK_MAX_OBJECTS else null
		(ck_objArray[i] as CK_object).next = null

	(ck_objArray[CK_MAX_OBJECTS - 1] as CK_object).prev = null

	ck_freeObject = ck_objArray[0]
	ck_lastObject = null
	ck_numObjects = 0

	ck_keenObj = CK_GetNewObj(false)

	ck_scoreBoxObj = CK_GetNewObj(false)


func CK_GetNewObj(nonCritical: bool) -> CK_object:
	if ck_freeObject == null:
		if nonCritical:
			#printf("Warning: No free spots in objarray! Using temp object\n");
			return ck_tempObj
		else:
			Quit("GetNewObj: No free spots in objarray!")
			return ck_tempObj

	var newObj: CK_object = ck_freeObject
	ck_freeObject = ck_freeObject.prev

	#Clear any old crap out of the struct.
	newObj.clear()

	if ck_lastObject != null:
		ck_lastObject.next = newObj
	newObj.prev = ck_lastObject

	newObj.active = OBJ_ACTIVE
	newObj.clipped = CLIP_normal

	ck_lastObject = newObj
	ck_numObjects += 1

	return newObj


func CK_RemoveObj(obj: CK_object) -> void:
	if obj == ck_keenObj:
		Quit("RemoveObj: Tried to remove the player!")
		return

	# TODO: Make a better spritedraw handler that
	# replaces the user int variables
	obj.sde = RF_RemoveSpriteDraw(obj.sde)

	if obj.type == CT_CLASS("StunnedCreature"):
		obj.user3 = RF_RemoveSpriteDrawUsing16BitOffset(obj.user3)

	if obj == ck_lastObject:
		ck_lastObject = obj.prev
	else:
		obj.next.prev = obj.prev

	obj.prev.next = obj.next
	#obj->next = 0;

	obj.prev = ck_freeObject
	ck_freeObject = obj
	ck_numObjects -= 1


#** Used for saved games compatibility **
const COMPAT_ORIG_OBJ_SIZE: int = 76


func CK_ConvertObjPointerTo16BitOffset(obj: CK_object) -> int:
	if obj != null and obj.index >= 0 and obj.index < CK_MAX_OBJECTS and ck_objArray[obj.index] == obj:
		return u16(obj.index * COMPAT_ORIG_OBJ_SIZE + CK_INT("ck_exe_objArrayOffset", 0x0000))
	if obj == ck_tempObj:
		return u16(CK_INT("ck_exe_tempObjOffset", 0xFEFE))
	return 0


func CK_ConvertObj16BitOffsetToPointer(offset: int) -> CK_object:
	offset = u16(offset)
	var objArrayOffset: int = u16(CK_INT("ck_exe_objArrayOffset", 0x0000))
	# Original size of each object was 76 bytes
	if offset >= objArrayOffset and offset < objArrayOffset + COMPAT_ORIG_OBJ_SIZE * CK_MAX_OBJECTS:
		@warning_ignore("integer_division")
		return ck_objArray[(offset - objArrayOffset) / COMPAT_ORIG_OBJ_SIZE]
	if offset == CK_INT("ck_exe_tempObjOffset", 0xFEFE):
		return ck_tempObj
	return null


# Used for reproduction of vanilla Keen bugs; Does NOT include function pointers
var ck_partialNullAction: CK_action = _ck_partialNullAction_init()


static func _ck_partialNullAction_init() -> CK_action:
	var a: CK_action = CK_action.new()
	a.chunkLeft = 0
	a.chunkRight = 0
	a.type = AT_NullActionTypeValue
	a.protectAnimation = 0x6C72
	a.stickToGround = 0x6E61
	a.timer = 0x2064
	a.velX = 0x2B43
	a.velY = 0x202B
	return a


func CK_ActionThink(obj: CK_object, time: int) -> int:
	time = s16(time)
	var lastAction: CK_action = obj.currentAction
	# WORKAROUND FOR VANILLA KEEN BUG: The original code does not
	# check if lastAction != NULL. Naively accessing *lastAction
	# may lead to a crash in this case (try no-clip cheat).
	# Returning from the function in case lastAction == NULL
	# resolves this, but we try to emulate original behaviors here.
	var action: CK_action = lastAction if lastAction != null else ck_partialNullAction

	# ThinkMethod: 2
	if action.type == AT_Frame:
		if action.think != &"":
			if obj.timeUntillThink != 0:
				obj.timeUntillThink = u16(obj.timeUntillThink - 1)
			else:
				call(action.think, obj)
		return 0

	var newTime: int = s16(time + obj.actionTimer)

	# If we won't run out of time.
	if action.timer > newTime or action.timer == 0:
		obj.actionTimer = newTime

		if action.type == AT_ScaledOnce or action.type == AT_ScaledFrame:
			if obj.xDirection != 0:
				#TODO: Work out what to do with the nextVelocity stuff.
				ck_nextX = s16(ck_nextX + action.velX * (time * obj.xDirection))
			if obj.yDirection != 0:
				ck_nextY = s16(ck_nextY + action.velY * (time * obj.yDirection))

		if action.type == AT_UnscaledFrame or action.type == AT_ScaledFrame:
			if action.think != &"":
				if obj.timeUntillThink != 0:
					obj.timeUntillThink = u16(obj.timeUntillThink - 1)
				else:
					call(action.think, obj)
		return 0

	var remainingTime: int = s16(action.timer - obj.actionTimer)
	newTime = s16(newTime - action.timer)
	obj.actionTimer = 0

	if action.type == AT_ScaledOnce or action.type == AT_ScaledFrame:
		if obj.xDirection != 0:
			ck_nextX = s16(ck_nextX + action.velX * (remainingTime * obj.xDirection))
		if obj.yDirection != 0:
			ck_nextY = s16(ck_nextY + action.velY * (remainingTime * obj.yDirection))
	else: #if (action->type == AT_UnscaledOnce || action->type == AT_UnscaledFrame)
		if obj.xDirection != 0:
			ck_nextX = s16(ck_nextX + action.velX * obj.xDirection)
		if obj.yDirection != 0:
			ck_nextY = s16(ck_nextY + action.velY * obj.yDirection)

	if action.think != &"":
		if obj.timeUntillThink != 0:
			obj.timeUntillThink = u16(obj.timeUntillThink - 1)
		else:
			call(action.think, obj)

	# Do NOT use action variable here
	if lastAction != obj.currentAction:
		if obj.currentAction == null:
			return 0
	else:
		# C quirk kept: when lastAction is NULL (the partial null action's timer ran
		# out) this reads through a NULL pointer; here it is a script error.
		obj.currentAction = lastAction.next
	return newTime


func CK_RunAction(obj: CK_object) -> void:
	var oldChunk: int = s16(obj.gfxChunk)

	#TODO: Check these
	#int16_t oldPosX = obj->posX;
	#int16_t oldPosY = obj->posY;

	obj.deltaPosX = 0
	obj.deltaPosY = 0

	ck_nextX = 0
	ck_nextY = 0

	var prevAction: CK_action = obj.currentAction

	var ticsLeft: int = CK_ActionThink(obj, SD_GetSpriteSync())

	if obj.currentAction != prevAction:
		obj.actionTimer = 0
		prevAction = obj.currentAction
	while ticsLeft != 0:
		# WORKAROUND FOR VANILLA KEEN BUG: As in CK_ActionThink, the
		# original code does not check if prevAction != NULL. Naively
		# accessing *prevAction may lead to a crash in this case
		# (try no-clip cheat). Adding a check if prevAction == NULL
		# before entering the loop resolves this, but we try
		# to emulate original behaviors here.
		var prevActionToAccess: CK_action = prevAction if prevAction != null else ck_partialNullAction

		if prevActionToAccess.protectAnimation != 0 or prevActionToAccess.timer > ticsLeft:
			ticsLeft = CK_ActionThink(obj, ticsLeft)
		else:
			ticsLeft = CK_ActionThink(obj, prevActionToAccess.timer - 1)
		# Do NOT use prevActionToAccess here
		if obj.currentAction != prevAction:
			obj.actionTimer = 0
			prevAction = obj.currentAction

	if prevAction == null:
		CK_RemoveObj(obj)
		return
	if prevAction.chunkRight != 0:
		obj.gfxChunk = u16(prevAction.chunkRight if obj.xDirection > 0 else prevAction.chunkLeft)
	if obj.gfxChunk == 0xFFFF: # (uint16_t)-1
		obj.gfxChunk = 0
	# (the uint16_t gfxChunk and the int16_t oldChunk both promote to int, as in C)
	if obj.gfxChunk != oldChunk or ck_nextX != 0 or ck_nextY != 0 or obj.topTI == 0x19:
		if obj.clipped == CLIP_simple:
			CK_PhysFullClipToWalls(obj)
		else:
			CK_PhysUpdateNormalObj(obj)


# CK_OverlayForegroundTile's static nullTile:
# Some random DOSBox memory dump, resolving crashes with NULL pointers and
# somewhat emulating the behaviors of vanilla Keen in DOSBox (at least Keen 4)
const nullTile: PackedInt32Array = [
	0x0162, 0x01A2, 0x0008, 0x0070, 0x0008, 0x0070, 0x0008, 0x0070, 0x0008, 0x0070,
	0x1060, 0xF000, 0x1060, 0xF000, 0x1060, 0xF000, 0x05F5, 0x1A16, 0x000B, 0x1602,
	0xFF55, 0xF000, 0x1060, 0xF000, 0x1060, 0xF000, 0x1060, 0xF000, 0x1080, 0xF000,
	0x1060, 0xF000, 0x1320, 0xF000, 0x1120, 0xF000, 0x1140, 0xF000, 0x1160, 0xF000,
	0x11C0, 0xF000, 0x11E0, 0xF000, 0x1200, 0xF000, 0x1240, 0xF000, 0x12E0, 0xF000,
	0x12E0, 0xF000, 0x1260, 0xF000, 0x1060, 0xF000, 0x1280, 0xF000, 0xF0A4, 0xF000,
	0x1060, 0xF000, 0x0500, 0xC000, 0x14A0, 0xF000, 0x14C0, 0xF000, 0x20C8, 0xF000,
	0x0000, 0x0118, 0x1AAB, 0x01A2, 0x14E0, 0xF000, 0x1500, 0xF000, 0x1520, 0xF000,
]


## A tile chunk's little-endian 16-bit word `w` (C's uint16_t * over the chunk).
static func _tile_word(buf: PackedByteArray, w: int) -> int:
	return buf[w * 2] | (buf[w * 2 + 1] << 8)


static func _set_tile_word(buf: PackedByteArray, w: int, v: int) -> void:
	buf[w * 2] = v & 0xFF
	buf[w * 2 + 1] = (v >> 8) & 0xFF


func CK_OverlayForegroundTile(fgTile: int, overlayTile: int) -> void:
	# Note: CK_WallDebug makes sure dst is never NULL; It's src which may be NULL.
	var srcChunk: int = int(ca_gfxInfoE.offTiles16m) + overlayTile
	var dstChunk: int = int(ca_gfxInfoE.offTiles16m) + fgTile
	var src: Variant = ca_graphChunks[srcChunk]
	var dst: PackedByteArray = ca_graphChunks[dstChunk]

	for i: int in range(64):
		var row: int = i & 0xF # Row of the tile we're on
		var overlayColor: int = 0
		var overlayMask: int = 0
		if src == null: # src = src ? src : nullTile;
			overlayColor = nullTile[i + 0x10]
			overlayMask = nullTile[row]
		elif srcChunk == dstChunk: # the same tile: C's src reads what dst has written
			overlayColor = _tile_word(dst, i + 0x10)  # Get the overlay color plane
			overlayMask = _tile_word(dst, row)        # Get the overlay mask plane
		else:
			overlayColor = _tile_word(src, i + 0x10)
			overlayMask = _tile_word(src, row)
		_set_tile_word(dst, row, _tile_word(dst, row) & overlayMask)                  # Mask dest mask w/ overlay mask
		_set_tile_word(dst, 0x10 + i, _tile_word(dst, 0x10 + i) & overlayMask)        # Now draw the overlayTile (mask...)
		_set_tile_word(dst, 0x10 + i, _tile_word(dst, 0x10 + i) | overlayColor)       # (... and draw color plane)
	ca_graphChunks[dstChunk] = dst


# TODO: make this interoperable between episodes
func CK_WallDebug() -> void:
	VL_FixRefreshBuffer()
	US_CenterWindow(24, 3)
	US_PrintCentered("WORKING")
	VH_UpdateScreen()

	var offTiles16m: int = int(ca_gfxInfoE.offTiles16m)
	# Cache the slope info foreground tiles
	for i: int in range(offTiles16m + 0x6C, offTiles16m + 0x6C + 16):
		CA_CacheGrChunk(i)

	# Draw the slope info tile over each foreground tile
	for i: int in range(int(ca_gfxInfoE.numTiles16m)):
		if ca_graphChunks[i + offTiles16m] != null:
			var ti: int = 0

			ti = TI_ForeTop(i) & 7
			if ti != 0:
				CK_OverlayForegroundTile(i, ti + 0x6B)

			ti = TI_ForeBottom(i) & 7
			if ti != 0:
				CK_OverlayForegroundTile(i, ti + 0x73)

			ti = TI_ForeRight(i) & 7
			if ti > 1:
				Quit("CK_WallDebug: East wall other than 1:%d" % i)
				return
			elif ti == 1:
				CK_OverlayForegroundTile(i, ti + 0x72)

			ti = TI_ForeLeft(i) & 7
			if ti > 1:
				Quit("CK_WallDebug: West wall other than 1:%d" % i)
				return
			elif ti == 1:
				CK_OverlayForegroundTile(i, ti + 0x7A)
	# Hack to work around F10-Y not updating the screen immediately.
	RF_Reposition(rf_scrollXUnit, rf_scrollYUnit)


func CK_DebugKeys() -> bool:
	# Border colour
	if IN_GetKeyState(IN_SC_B) and game_in_progress != 0:
		VL_FixRefreshBuffer()
		US_CenterWindow(0x18, 3)
		US_SetPrintY(US_GetPrintY() + 6)
		var wh: PackedInt32Array = VH_MeasurePropString(" Border color (0-15):", US_GetPrintFont())
		var saveX: int = u16(US_GetPrintX() + wh[0])
		var saveY: int = u16(US_GetPrintY())
		US_Print(" Border color (0-15):")
		VH_UpdateScreen()

		var input: Array = US_LineInput(saveX, saveY, "", true, 2, 0)
		if input[0]:
			# Convert string into number (C leaves colour uninitialised when sscanf fails)
			var colour: int = _sscanf_d(input[1], 0)

			if colour >= 0 and colour <= 15:
				VL_ColorBorder(colour)
		return true
	if IN_GetKeyState(IN_SC_C) and game_in_progress != 0:
		CK_CountActiveObjects()
		return true
	# TODO: Demo Recording
	if IN_GetKeyState(IN_SC_D) and game_in_progress != 0:
		if IN_DemoGetMode() == IN_Demo_Off:
			CK_BeginDemoRecord()
		elif IN_DemoGetMode() == IN_Demo_Record:
			CK_EndDemoRecord()
			ck_gameState.levelState = LS_LevelComplete
		return true

	# End Level
	if IN_GetKeyState(IN_SC_E) and game_in_progress != 0:
		# TODO: Handle ted level differently?
		if us_tedLevel:
			#run_ted();
			Quit("")
		ck_gameState.levelState = LS_LevelComplete
		# Nope, no return of "true"

	# God Mode
	if IN_GetKeyState(IN_SC_G) and game_in_progress != 0:
		VL_FixRefreshBuffer()
		US_CenterWindow(12, 2)

		if ck_godMode:
			US_PrintCentered(CK_STRING("ck_str_godModeOff"))
		else:
			US_PrintCentered(CK_STRING("ck_str_godModeOn"))

		VH_UpdateScreen()
		IN_WaitButton()
		ck_godMode = not ck_godMode
		return true

	# Free Item Cheat
	if IN_GetKeyState(IN_SC_I):
		VL_FixRefreshBuffer()
		US_CenterWindow(12, 3)
		US_PrintCentered(CK_STRING("ck_str_freeItems"))

		for i: int in range(4):
			ck_gameState.keyGems[i] = s16(ck_gameState.keyGems[i] + 1)

		ck_gameState.numShots = 99
		if ck_currentEpisode_ep == EP_CK4:
			ck_gameState.ck4_wetsuit = 1
		elif ck_currentEpisode_ep == EP_CK5:
			ck_gameState.ck5_securityCard = 1
		elif ck_currentEpisode_ep == EP_CK6:
			ck_gameState.ck6_passcard = 1
			ck_gameState.ck6_rope = 1
			ck_gameState.ck6_sandwich = 1

		VH_UpdateScreen()
		IN_WaitButton()
		CK_IncreaseScore(3000)
		return true

	if IN_GetKeyState(IN_SC_J):
		ck_gameState.jumpCheat = not ck_gameState.jumpCheat
		VL_FixRefreshBuffer()
		US_CenterWindow(18, 3)

		if ck_gameState.jumpCheat:
			US_PrintCentered(CK_STRING("ck_str_jumpCheatOn"))
		else:
			US_PrintCentered(CK_STRING("ck_str_jumpCheatOff"))

		VH_UpdateScreen()
		IN_WaitButton()
		return true

	if IN_GetKeyState(IN_SC_M):
		CK_DebugMemory()
		return true

	if IN_GetKeyState(IN_SC_N):
		VL_FixRefreshBuffer()
		US_CenterWindow(18, 3)
		if ck_keenObj.clipped != 0:
			US_PrintCentered(CK_STRING("ck_str_noClippingOn"))
			ck_keenObj.clipped = CLIP_not
		else:
			US_PrintCentered(CK_STRING("ck_str_noClippingOff"))
			ck_keenObj.clipped = CLIP_normal
		VH_UpdateScreen()
		IN_WaitButton()
		return true

	# Pause

	# Slow Motion
	if IN_GetKeyState(IN_SC_S) and game_in_progress != 0:
		ck_slowMotionEnabled = not ck_slowMotionEnabled
		VL_FixRefreshBuffer()
		US_CenterWindow(18, 3)

		if ck_slowMotionEnabled:
			US_PrintCentered(CK_STRING("ck_str_slowMotionOn"))
		else:
			US_PrintCentered(CK_STRING("ck_str_slowMotionOff"))
		VH_UpdateScreen()
		IN_WaitButton()
		return true

	# Sprite Test
	if IN_GetKeyState(IN_SC_T):
		CK_SpriteTest()
		return true

	# Extra Vibbles
	if IN_GetKeyState(IN_SC_V) and game_in_progress != 0:
		VL_FixRefreshBuffer()
		US_CenterWindow(30, 3)
		US_SetPrintY(US_GetPrintY() + 3)
		US_Print(CK_STRING("ck_str_extraVBLs"))
		VH_UpdateScreen()
		var vblInput: Array = US_LineInput(US_GetPrintX(), US_GetPrintY(), "", true, 2, 0)
		if vblInput[0]:
			var extraVBLs: int = _sscanf_d(vblInput[1], 0)
			if extraVBLs > CK_INT("ck_minExtraVBLs", 0) and extraVBLs <= CK_INT("ck_maxExtraVBLs", 8):
				ck_extraVBLs = extraVBLs
		return true

	# Level Warp
	if IN_GetKeyState(IN_SC_W) and game_in_progress != 0:
		var msg: String = CK_STRING("ck_str_levelWarp")
		# uint16_t h, w, saveX, saveY; // omnispeak hacks

		VL_FixRefreshBuffer()
		US_CenterWindow(26, 3)
		US_SetPrintY(US_GetPrintY() + 6)
		var msgWH: PackedInt32Array = VH_MeasurePropString(msg, US_GetPrintFont())
		var warpX: int = u16(US_GetPrintX() + msgWH[0])
		var warpY: int = u16(US_GetPrintY())
		US_Print(msg)
		VH_UpdateScreen()

		var warpInput: Array = US_LineInput(warpX, warpY, "", true, 2, 0)
		if warpInput[0]:
			# Convert string into number
			var level: int = _sscanf_d(warpInput[1], 0)

			if level >= CK_INT("ck_minWarpLevel", 1) and level <= CK_INT("ck_maxWarpLevel", 18):
				ck_gameState.currentLevel = s16(level)
				ck_gameState.levelState = LS_AboutToRecordDemo
		return true

	if IN_GetKeyState(IN_SC_Y):
		CK_WallDebug()
		return true

	if IN_GetKeyState(IN_SC_Z):
		ck_gameState.numLives = 0
		CK_KillKeen()
		# Not sure why this'd be 'false', but that's what
		# the disassembly says.
		return false

	return false


# Check non-game keys
func CK_CheckKeys() -> void:
	# TODO: Also check for a gamepad button when relevant

	if vl_screenFaded:
		return

	# Drop down status
	if IN_GetKeyState(IN_SC_Enter) or IN_IsJoyButtonDown(IN_joy_status):
		CK_ShowStatusWindow()
		RF_ForceRefresh() # Reanimate the tiles
		SD_SetLastTimeCount(SD_GetTimeCount())

	# TODO: If Paused
	if in_Paused:
		SD_MusicOff()
		VL_FixRefreshBuffer()
		US_CenterWindow(in_PausedMessage.length() + 2, 3)
		US_PrintCentered(in_PausedMessage)
		VH_UpdateScreen()
		IN_WaitButton()
		RF_ForceRefresh()
		in_Paused = false
		in_PausedMessage = CK_STRING("ck_str_paused")
		SD_MusicOn()

	# HELP (HAS_HELPSCREEN)
	if (ck_currentEpisode_ep != EP_CK6) and (IN_GetLastScan() == IN_SC_F1):
		StopMusic()
		HelpScreens()
		StartMusic(ck_gameState.currentLevel)

		# Force scorebox redraw if it's enabled
		if ck_scoreBoxEnabled:
			ck_scoreBoxObj.user1 = -1
			ck_scoreBoxObj.user2 = -1
			ck_scoreBoxObj.user3 = -1
			ck_scoreBoxObj.user4 = -1
		RF_ForceRefresh()

	if not ck_storeDemo:
		# QUICKSAVE_ENABLED (omnispeak upstream), the shell's Enhanced mode only (SAVE-02): F5 and F9
		# before the wristwatch's keys, as 1.0 had them
		var quick: bool = bool(call("shell_quicksave_on"))
		# the question asked over the play, the watch not drawn (its last card would flash up), the play
		# painted again after it
		var card: Variant = get("us_currentCard")
		if quick and IN_GetLastScan() == IN_SC_F5:
			# Quicksave
			set("us_currentCard", null)
			var saved: bool = call("US_QuickSave")
			set("us_currentCard", card)
			RF_ForceRefresh()
			if saved:
				in_Paused = true
				in_PausedMessage = CK_STRING("ck_str_gameQuickSaved")
		elif quick and IN_GetLastScan() == IN_SC_F9:
			# Quickload
			set("us_currentCard", null)
			var loaded: bool = call("US_QuickLoad")
			set("us_currentCard", card)
			if not loaded:
				RF_ForceRefresh()
			if loaded:
				StopMusic()
				# Force scorebox redraw if it's enabled
				if ck_scoreBoxEnabled:
					ck_scoreBoxObj.user1 = -1
					ck_scoreBoxObj.user2 = -1
					ck_scoreBoxObj.user3 = -1
					ck_scoreBoxObj.user4 = -1
				ck_gameState.levelState = LS_LoadedGame
				StartMusic(ck_gameState.currentLevel)
			if load_game_error != 0:
				load_game_error = 0
				ck_gameState.levelState = LS_AbortGame

		# Go back to wristwatch
		elif (IN_GetLastScan() >= IN_SC_F2 and IN_GetLastScan() <= IN_SC_F7) or IN_GetLastScan() == IN_SC_Escape:
			# don't re-enter menu immediately if we came here
			# via joystick button
			ck_inputFrame.button3 = false

			VL_FixRefreshBuffer()
			StopMusic()
			US_RunCards()

			# RF_Reset();
			StartMusic(ck_gameState.currentLevel)

			# Wipe the scorebox if it got disabled
			if not ck_scoreBoxEnabled and ck_scoreBoxObj.sde != null:
				ck_scoreBoxObj.sde = RF_RemoveSpriteDraw(ck_scoreBoxObj.sde)

			# Force scorebox redraw if it's enabled
			if ck_scoreBoxEnabled:
				ck_scoreBoxObj.user1 = -1
				ck_scoreBoxObj.user2 = -1
				ck_scoreBoxObj.user3 = -1
				ck_scoreBoxObj.user4 = -1

			IN_ClearKeysDown()

			if ck_startingDifficulty != 0:
				ck_gameState.levelState = LS_ResetGame
			elif ck_startingSavedGame == 0:
				RF_ForceRefresh()

			if load_game_error != 0:
				load_game_error = 0
				ck_gameState.levelState = LS_AbortGame

			if ck_startingSavedGame != 0:
				ck_gameState.levelState = LS_LoadedGame

			# gameticks_2 = TimeCount
			# FIXME: Is this the right way to handle this?
			SD_SetLastTimeCount(SD_GetTimeCount())

	# BAT ITEM CHEAT
	if IN_GetKeyState(IN_SC_B) and IN_GetKeyState(IN_SC_A) and IN_GetKeyState(IN_SC_T):
		CK_ItemCheat()

	# Debug Keys
	if IN_GetKeyState(IN_SC_F10):
		if ck_debugActive and CK_DebugKeys():
			RF_ForceRefresh()
			SD_SetLastTimeCount(SD_GetTimeCount())

	if ck_storeDemo and IN_GetKeyState(IN_SC_Control) and IN_GetLastScan() == IN_SC_S:
		if SD_GetSoundMode() != sdm_Off:
			SD_SetSoundMode(sdm_Off)
			SD_SetMusicMode(smm_Off)
		else:
			if SD_IsAdlibPresent():
				SD_SetSoundMode(sdm_AdLib)
				SD_SetQuietSfx(false)
				# Note that this won't actually start the music
				# immediately.
				SD_SetMusicMode(smm_AdLib)
			else:
				SD_SetSoundMode(sdm_PC)
				SD_SetMusicMode(smm_Off)
			CA_LoadAllSounds()

	# CTRL + Q
	if IN_GetKeyState(IN_SC_Control) and IN_GetLastScan() == IN_SC_Q:
		IN_ClearKeysDown()
		Quit("")


func CK_HandleInput() -> void:
	IN_ReadControls(0, ck_inputFrame)

	if ck_inputFrame.yDirection != -1:
		ck_keenState.keenSliding = false

	if not ck_gamePadEnabled or (IN_DemoGetMode() != IN_Demo_Off):
		# Two button firing mode is used for demo playback
		if not ck_twoButtonFiring and (IN_DemoGetMode() == IN_Demo_Off):
			ck_keenState.jumpIsPressed = ck_inputFrame.jump
			ck_keenState.pogoIsPressed = ck_inputFrame.pogo
			ck_keenState.shootIsPressed = ck_inputFrame.button2
			if not ck_keenState.jumpIsPressed:
				ck_keenState.jumpWasPressed = false
			if not ck_keenState.pogoIsPressed:
				ck_keenState.pogoWasPressed = false

			if not ck_keenState.shootIsPressed:
				ck_keenState.shootWasPressed = false
		else:
			# Check for two-button firing
			if ck_inputFrame.jump and ck_inputFrame.pogo:
				ck_keenState.shootIsPressed = true
				ck_keenState.jumpIsPressed = false
				ck_keenState.pogoIsPressed = false
				ck_keenState.jumpWasPressed = false
				ck_keenState.pogoWasPressed = false
				return

			ck_keenState.shootWasPressed = false
			ck_keenState.shootIsPressed = false

			if ck_inputFrame.jump:
				ck_keenState.jumpIsPressed = true
			else:
				ck_keenState.jumpWasPressed = false
				ck_keenState.jumpIsPressed = false

			if ck_inputFrame.pogo:
				# Here be dragons!
				# In order to better emulate the original trilogy's controls, a delay
				# is introduced when pogoing in two-button firing.
				if ck_pogoTimer <= 8:
					ck_pogoTimer += SD_GetSpriteSync()
				else:
					ck_keenState.pogoIsPressed = true
			else:
				# If the player lets go of pogo, pogo immediately.
				if ck_pogoTimer != 0:
					ck_keenState.pogoIsPressed = true
				else:
					ck_keenState.pogoWasPressed = false
					ck_keenState.pogoIsPressed = false
				ck_pogoTimer = 0
	else:
		# TODO: Gravis Gamepad input handling
		pass


func StopMusic() -> void:
	SD_MusicOff()
	for i: int in range(int(ca_audInfoE.numSongs)):
		var chunk: int = int(ca_audInfoE.startMusic) + i
		# (C's CA_audio is fixed-size; past the port's lazily sized array nothing is cached)
		if chunk < CA_audio.size() and CA_audio[chunk] != null:
			MM_SetPurge("aud:%d" % chunk, true)


func StartMusic(level: int) -> void:
	level = s16(level)
	var song: int = -1

	if (level >= 20) and (level != -1):
		Quit("StartMusic() - bad level number")
		return
	SD_MusicOff()

	# NOTE: For buffer overflow emulation in Keen 4,
	# consider assigning in_kbdControls.fire as the song number
	if (level == -1) and (ck_currentEpisode_ep == EP_CK4):
		song = s16(CK_INT("ck4_specialMusic", 5))
	else:
		song = s16(CK_INTELEMENT("CK_LevelMusic", level))

	if (song == -1) or (SD_GetMusicMode() != smm_AdLib):
		return
	MM_BombOnError(false)
	# TIME-G: loading a song beside its bytes (the black before a level fades in);
	# none when it is still cached (a restart), as CA_CacheAudioChunk returns at once
	var musicChunk: int = int(ca_audInfoE.startMusic) + song
	if CA_audio.size() <= musicChunk or CA_audio[musicChunk] == null:
		cost("musicload")
	CA_CacheAudioChunk(musicChunk)
	MM_BombOnError(true)
	# TODO: FINISH THIS! (the "Insufficient memory for background music" block is #if 0)
	SD_StartMusic(CA_audio[int(ca_audInfoE.startMusic) + song])


#===========================================================================
#
# DROPDOWN STATUS WINDOW
#
#===========================================================================

# ck_statusSurface, ck_backupSurface: gal_ck.gd.

# The status window is drawn to scratch area in the video buffer
# Then it is copied from the scratch to the screen using the RF_ Hook

var ck_statusWindowYPx: int = 0
var ck_statusDown: bool = false
var statusWindowOfs: int = 0 # screen buffer (unsigned; unused)


func CK_DrawLongRight(x: int, y: int, digits: int, zerotile: int, value: int) -> void:
	var s: String = "%d" % value
	# itoa(value, s, 10);
	var slen: int = s.length() # len = strlen(s)
	var i: int = digits

	while i > slen:
		VHB_DrawTile8(x, y, zerotile)
		x += 8
		i -= 1

	while i > 0:
		VHB_DrawTile8(x, y, zerotile + s.unicode_at(slen - i) - 47)
		i -= 1
		x += 8


func CK_DrawStatusWindow() -> void:
	var si: int = 0
	var oldcolor: int = 0

	# Draw the backdrop
	var var2: int = 64
	var di: int = 16
	var statusWidth: int = STATUS_W - 8
	var statusHeight: int = STATUS_H - 8

	VHB_DrawTile8(var2, di, 54)
	VHB_DrawTile8(var2, di + statusHeight, 60)
	si = var2 + 8

	while var2 + statusWidth - 8 >= si:
		VHB_DrawTile8(si, di, 55)
		VHB_DrawTile8(si, di + statusHeight, 61)
		si += 8

	VHB_DrawTile8(si, di, 56)
	VHB_DrawTile8(si, di + statusHeight, 62)

	si = di + 8

	while di + statusHeight - 8 >= si:
		VHB_DrawTile8(var2, si, 57)
		VHB_DrawTile8(var2 + statusWidth, si, 59)
		si += 8

	VHB_Bar(72, 24, 176, 136, 7)

	# Print the stuff
	oldcolor = US_GetPrintColour()

	# Level
	US_SetPrintY(28)
	US_SetWindowX(80)
	US_SetWindowW(160)
	US_SetPrintColour(15)
	US_CPrint(CK_STRING("ck_str_statusLocation"))
	VHB_Bar(79, 38, 162, 20, 15)
	var levelName: String = CK_STRINGELEMENT("ck_str_levelNames", ca_mapOn) # strcpy(str, ...) into char[256]
	# CK_MeasureMultiline(str, &strW, &strH): [strW, strH] returned (the two out-parameters' slots are dummies)
	var strWH: Variant = CK_MeasureMultiline(levelName, 0, 0)
	var strH: int = u16(int(strWH[1]))
	@warning_ignore("integer_division")
	US_SetPrintY((20 - strH) / 2 + 40 - 2)
	US_CPrint(levelName)

	# Score
	US_SetPrintY(61)
	US_SetWindowX(80)
	US_SetWindowW(64)
	US_SetPrintColour(15)
	US_CPrint(CK_STRING("ck_str_statusScore"))

	VHB_Bar(79, 71, 66, 10, 0)
	CK_DrawLongRight(80, 72, 8, 41, ck_gameState.keenScore)

	# Extra man
	US_SetPrintY(61)
	US_SetWindowX(176)
	US_SetWindowW(64)
	US_CPrint(CK_STRING("ck_str_statusExtra"))
	VHB_Bar(175, 71, 66, 10, 0)
	CK_DrawLongRight(176, 72, 8, 41, ck_gameState.nextKeenAt)

	# Episode-dependent field
	if ck_currentEpisode_ep == EP_CK4:
		US_SetPrintY(85)
		US_SetWindowX(80)
		US_SetWindowW(64)
		US_CPrint(CK_STRING("ck4_str_statusRescued"))

		VHB_Bar(79, 95, 66, 10, 0)
		for r: int in range(ck_gameState.ck4_membersRescued):
			VHB_DrawTile8(80 + 8 * r, 96, 40)
	elif ck_currentEpisode_ep == EP_CK5:
		US_SetPrintY(91)
		US_SetPrintX(80)
		US_Print(CK_STRING("ck5_str_statusKeycard"))

		VHB_Bar(135, 90, 10, 10, 0)
		if ck_gameState.ck5_securityCard != 0:
			VHB_DrawTile8(136, 91, 40)
	elif ck_currentEpisode_ep == EP_CK6:
		US_SetPrintX(80)
		US_SetPrintY(96)
		US_Print(CK_STRING("ck6_str_statusItems"))
		VHB_Bar(127, 95, 26, 10, 0)

		if ck_gameState.ck6_sandwich == 1:
			VHB_DrawTile8(128, 96, 2)
		else:
			VHB_DrawTile8(128, 96, 1)

		if ck_gameState.ck6_rope == 1:
			VHB_DrawTile8(136, 96, 4)
		else:
			VHB_DrawTile8(136, 96, 3)

		if ck_gameState.ck6_passcard == 1:
			VHB_DrawTile8(144, 96, 6)
		else:
			VHB_DrawTile8(144, 96, 5)
	else:
		Quit("No episode set!")

	# Difficulty
	US_SetPrintY(85)
	US_SetWindowX(176)
	US_SetWindowW(64)
	US_SetPrintColour(15)
	US_CPrint(CK_STRING("ck_str_statusLevel"))
	VHB_Bar(175, 95, 66, 10, 15)

	US_SetPrintY(96)
	US_SetWindowX(176)
	US_SetWindowW(64)
	US_SetPrintColour(15)

	if ck_gameState.difficulty == D_Easy:
		US_CPrint(CK_STRING("ck_str_statusEasy"))
	elif ck_gameState.difficulty == D_Normal:
		US_CPrint(CK_STRING("ck_str_statusNormal"))
	elif ck_gameState.difficulty == D_Hard:
		US_CPrint(CK_STRING("ck_str_statusHard"))
	else:
		Quit("No difficulty set!")

	# Key gems
	US_SetPrintX(80)
	US_SetPrintY(112)
	US_SetPrintColour(15)
	US_Print(CK_STRING("ck_str_statusKeys"))

	VHB_Bar(119, 111, 34, 10, 0)

	for i: int in range(4):
		if ck_gameState.keyGems[i] != 0:
			VHB_DrawTile8(120 + i * 8, 112, 36 + i)

	# AMMO
	US_SetPrintX(176)
	US_SetPrintY(112)
	US_Print(CK_STRING("ck_str_statusAmmo"))
	VHB_Bar(215, 111, 26, 10, 0)
	CK_DrawLongRight(216, 112, 3, 41, ck_gameState.numShots)

	# Lives
	US_SetPrintX(80)
	US_SetPrintY(128)
	US_Print(CK_STRING("ck_str_statusLives"))
	VHB_Bar(127, 127, 18, 10, 0)
	CK_DrawLongRight(128, 128, 2, 41, ck_gameState.numLives)

	# Lifeups
	US_SetPrintX(176)
	US_SetPrintY(128)
	US_Print(CK_STRING("ck_str_statusCentilives"))
	VHB_Bar(224, 127, 16, 10, 0)
	CK_DrawLongRight(224, 128, 2, 41, ck_gameState.numCentilife)

	# Episode-dependent field
	var addX: int = 0
	if ck_currentEpisode_ep == EP_CK4 or ck_currentEpisode_ep == EP_CK5 or ck_currentEpisode_ep == EP_CK6:
		if ck_currentEpisode_ep == EP_CK4:
			# Wetsuit
			VHB_Bar(79, 143, 66, 10, 15)

			US_SetPrintY(144)
			US_SetWindowX(80)
			US_SetWindowW(64)
			US_SetPrintColour(15)
			US_CPrint(CK_STRING("ck4_str_statusWetsuit") if ck_gameState.ck4_wetsuit != 0 else CK_STRING("ck4_str_statusNoWetsuit"))

			addX = 5
			# (no break: falls through into the Keen 5 and 6 case, as in C)

		for y: int in range(2):
			for x: int in range(10):
				VHB_DrawTile8(120 + 8 * (x + addX), 140 + 8 * y, 72 + y * 10 + x)
	else:
		Quit("No episode set!")

	US_SetPrintColour(oldcolor)


func CK_ScrollStatusWindow() -> void:
	var dx: int = 0
	var dy: int = 0
	var sx: int = 0
	var sy: int = 0
	var height: int = 0

	var scrX: int = VL_GetScrollX() & 8
	var scrY: int = VL_GetScrollY() % 16
	var statusWindowXPx: int = STATUS_X + scrX

	# Check if there's some game visible behind the top of the window.
	if ck_statusWindowYPx > STATUS_H:
		# The bit of tilemap behind the status window would need to be
		# redrawn after the top border of the status window scrolled on to the screen
		VL_SurfaceToScreen(ck_statusSurface,
			statusWindowXPx, 0,
			statusWindowXPx, 0,
			STATUS_W, ck_statusWindowYPx)

		# MPic atop the statusbox
		VH_DrawMaskedBitmap(136 + scrX, (ck_statusWindowYPx - STATUS_BOTTOM) + scrY,
			CK_CHUNKNUM("MPIC_STATUSRIGHT"))

		# Set up the position for the status box.
		height = STATUS_H
		sx = statusWindowXPx
		sy = STATUS_Y + scrY
		dx = statusWindowXPx
		dy = ck_statusWindowYPx - STATUS_H + scrY
	else:
		# If the status window is not unfurled, its height is equal to
		# the y-position of its bottom.
		height = ck_statusWindowYPx

		dx = statusWindowXPx
		dy = scrY
		sx = statusWindowXPx
		sy = STATUS_BOTTOM - height + scrY

	if height > 0:
		VL_SurfaceToScreen(ck_statusSurface,
			dx, dy,
			sx, sy,
			STATUS_W, height)

	# Draw the tile map underneath the scrolling status box
	if ck_statusDown:
		# Coming back up, need to redraw the map back underneath
		height = STATUS_BOTTOM - ck_statusWindowYPx

		VL_SurfaceToScreen(ck_backupSurface,
			statusWindowXPx, ck_statusWindowYPx + scrY,
			statusWindowXPx, ck_statusWindowYPx + scrY,
			STATUS_W, height)

		# Draw underneath the left masked pic
		height = ck_statusWindowYPx

		if height > 0:
			VL_SurfaceToScreen(ck_statusSurface,
				40 + scrX, 0,
				40 + scrX, 0,
				24, height)
	else:
		# Going down
		height = ck_statusWindowYPx - 72

		# Reset the area under the masked pic to the left
		if height > 0:
			VL_SurfaceToScreen(ck_statusSurface, 40 + scrX % 16, 0, 40 + scrX % 16, 0, 24, height)

	if ck_statusWindowYPx >= 72:
		VH_DrawMaskedBitmap(40 + scrX, ck_statusWindowYPx - STATUS_BOTTOM + scrY,
			CK_CHUNKNUM("MPIC_STATUSLEFT"))


func CK_ShowStatusWindow() -> void:
	# int oldBufferofs;

	US_SetWindowX(0)
	US_SetWindowW(320)
	US_SetWindowY(0)
	US_SetWindowH(200)

	# This function is called when enter pressed; check for A+2 to enable debug mode
	if IN_GetKeyState(IN_SC_A) and IN_GetKeyState(IN_SC_Two):
		US_CenterWindow(20, 2)
		US_SetPrintY(US_GetPrintY() + 2)
		US_Print(CK_STRING("ck_str_debugKeysActive"))
		VH_UpdateScreen()
		IN_WaitButton()
		ck_debugActive = true

	RF_Refresh()

	# Clear out all animating tiles
	RFL_SetupOnscreenAnimList()

	# Draw the status window to scratch area in the buffer
	# (the DOS bufferofs juggling is #if 0)

	# Omnispeak: make a surface and set it as the screen, temporarily,
	# in order to use the VH_ functions for drawing
	var screen: VL_Surface = vl_screen
	VL_SurfaceToSurface(screen, ck_statusSurface, 0, 0, 0, 0, RF_BUFFER_WIDTH_PIXELS, STATUS_H + 16)
	# And save a copy of the screen as-is to a backup surface as well.
	VL_SurfaceToSurface(screen, ck_backupSurface, 0, 0, 0, 0, RF_BUFFER_WIDTH_PIXELS, RF_BUFFER_HEIGHT_PIXELS)
	VL_SetScreen(ck_statusSurface)
	#int oldScrollX = VL_GetScrollX();
	#int oldScrollY = VL_GetScrollY();
	CK_DrawStatusWindow()
	#VL_SetScrollCoords(oldScrollX, oldScrollY);
	VL_SetScreen(screen)
	# bufferofs = oldBufferofs;
	RF_Refresh()

	# Scroll the window down
	SD_PlaySound(CK_SOUNDNUM("SOUND_STATUSDOWN"))
	ck_statusWindowYPx = 16
	ck_statusDown = false
	RF_SetDrawFunc(&"CK_ScrollStatusWindow")
	while not quitting:    # (a harness run's time limit ends the wait; the port's Quit returns)
		RF_Refresh()
		if ck_statusWindowYPx == 168:
			break

		ck_statusWindowYPx += SD_GetSpriteSync() * 8
		if ck_statusWindowYPx <= 168:
			continue

		ck_statusWindowYPx = 168

	RF_Refresh()
	RF_SetDrawFunc(&"")
	IN_ClearKeysDown()
	IN_WaitButton() #IN_Ack();

	# Scroll the window up
	SD_PlaySound(CK_SOUNDNUM("SOUND_STATUSUP"))
	ck_statusWindowYPx -= 16
	ck_statusDown = true
	RF_SetDrawFunc(&"CK_ScrollStatusWindow")

	while not quitting:    # (a harness run's time limit ends the wait; the port's Quit returns)
		RF_Refresh()
		if ck_statusWindowYPx == 0:
			break

		ck_statusWindowYPx -= SD_GetSpriteSync() * 8
		if ck_statusWindowYPx >= 0:
			continue

		ck_statusWindowYPx = 0

	RF_SetDrawFunc(&"")

	ck_scoreBoxObj.posX = 0


# ===========================================================================

# rf_scrollXUnit, rf_scrollYUnit: gal_rf.gd.

# The intended y-coordinate of the bottom of the keen sprite
# in pixels from the top of the screen. (static uint16_t)
var screenYpx: int = 0


# Centre the camera on the given object.
func CK_CentreCamera(obj: CK_object) -> void:
	var screenX: int = 0
	var screenY: int = 0

	screenYpx = 140

	if obj.posX < RF_PixelToUnit(152):
		screenX = 0
	else:
		screenX = u16(obj.posX - RF_PixelToUnit(152))

	if ca_mapOn == 0:
		# World Map
		if obj.posY < RF_PixelToUnit(80):
			screenY = 0
		else:
			screenY = u16(obj.posY - RF_PixelToUnit(80))
	else:
		# In Level
		if obj.clipRects.unitY2 < RF_PixelToUnit(140):
			screenY = 0
		else:
			screenY = u16(obj.clipRects.unitY2 - RF_PixelToUnit(140))

	# TODO: Find out why this is locking the game up
	if not ck_inHighScores:
		RF_Reposition(screenX, screenY)

	#TODO: This is 4 in Andy's disasm.
	ck_activeX0Tile = CK_Cross_max(RF_UnitToTile(rf_scrollXUnit) - CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT) - wide_tiles, 0)
	ck_activeX1Tile = CK_Cross_max(RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320) + CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT) + wide_tiles, 0)
	ck_activeY0Tile = CK_Cross_max(RF_UnitToTile(rf_scrollYUnit) - CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT), 0)
	ck_activeY1Tile = CK_Cross_max(RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208) + CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT), 0)


#
# Move the camera that follows keen on the world map
#
func CK_MapCamera(keen: CK_object) -> void:
	var scr_y: int = 0
	var scr_x: int = 0

	if ck_scrollDisabled:
		return

	# Scroll Left, Right, or nowhere
	if keen.clipRects.unitX1 < rf_scrollXUnit + RF_PixelToUnit(144):
		scr_x = s16(keen.clipRects.unitX1 - (rf_scrollXUnit + RF_PixelToUnit(144)))
	elif keen.clipRects.unitX2 > rf_scrollXUnit + RF_PixelToUnit(192):
		scr_x = s16(keen.clipRects.unitX2 + 16 - (rf_scrollXUnit + RF_PixelToUnit(192)))
	else:
		scr_x = 0

	# Scroll Up, Down, or nowhere
	if keen.clipRects.unitY1 < rf_scrollYUnit + RF_PixelToUnit(80):
		scr_y = s16(keen.clipRects.unitY1 - (rf_scrollYUnit + RF_PixelToUnit(80)))
	elif keen.clipRects.unitY2 > rf_scrollYUnit + RF_PixelToUnit(112):
		scr_y = s16(keen.clipRects.unitY2 - (rf_scrollYUnit + RF_PixelToUnit(112)))
	else:
		scr_y = 0

	# Limit scrolling to 256 map units (1 tile)
	# And update the active boundaries of the map
	if scr_x != 0 or scr_y != 0:
		if scr_x >= 256:
			scr_x = 255
		elif scr_x <= -256:
			scr_x = -255

		if scr_y >= 256:
			scr_y = 255
		elif scr_y <= -256:
			scr_y = -255

		RF_SmoothScroll(scr_x, scr_y)

		#
		# No ScrollX1_T in omnispeak; it's computed whenever it's needed
		# ScrollX1_T = ScrollX0_T + VIRTUAL_SCREEN_W_T;
		# ScrollY1_T = ScrollY0_T + VIRTUAL_SCREEN_H_T;
		#

		#TODO: This is 4 in Andy's disasm.
		ck_activeX0Tile = CK_Cross_max(RF_UnitToTile(rf_scrollXUnit) - CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT) - wide_tiles, 0)
		ck_activeX1Tile = CK_Cross_max(RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320) + CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT) + wide_tiles, 0)
		ck_activeY0Tile = CK_Cross_max(RF_UnitToTile(rf_scrollYUnit) - CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT), 0)
		ck_activeY1Tile = CK_Cross_max(RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208) + CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT), 0)


# Run the normal camera which follows keen
func CK_NormalCamera(obj: CK_object) -> void:
	var deltaX: int = 0 # in Units
	var deltaY: int = 0

	#TODO: some unknown var must be 0
	#This var is a "ScrollDisabled flag." If keen dies, it's set so he
	# can fall out the bottom
	if ck_scrollDisabled:
		return

	# End level if keen makes it out either side
	if obj.clipRects.unitX1 < rf_scrollXMinUnit or obj.clipRects.unitX2 > rf_scrollXMaxUnit + RF_TileToUnit(RF_SCREEN_WIDTH_TILES):
		ck_gameState.levelState = LS_LevelComplete
		return

	# Kill keen if he falls out the bottom
	if obj.clipRects.unitY2 > (rf_scrollYMaxUnit + RF_TileToUnit(RF_SCREEN_HEIGHT_TILES)):
		obj.posY = u16(obj.posY - (obj.clipRects.unitY2 - (rf_scrollYMaxUnit + RF_TileToUnit(RF_SCREEN_HEIGHT_TILES))))
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENFALL"))
		ck_godMode = false
		CK_KillKeen()
		return

	# Keep keen's x-coord between 144-192 pixels
	if obj.posX < (rf_scrollXUnit + RF_PixelToUnit(144)):
		deltaX = s16(obj.posX - (rf_scrollXUnit + RF_PixelToUnit(144)))

	if obj.posX > (rf_scrollXUnit + RF_PixelToUnit(192)):
		deltaX = s16(obj.posX - (rf_scrollXUnit + RF_PixelToUnit(192)))

	# Keen should be able to look up and down.
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenLookUp2"):
		var pxToMove: int = 0
		if screenYpx + SD_GetSpriteSync() > 167:
			# Keen should never be so low on the screen that his
			# feet are more than 167 px from the top.
			pxToMove = s16(167 - screenYpx)
		else:
			# Move 1px per tick.
			pxToMove = s16(SD_GetSpriteSync())
		screenYpx = u16(screenYpx + pxToMove)
		deltaY = s16(RF_PixelToUnit(-pxToMove))
	elif obj.currentAction == CK_GetActionByName("CK_ACT_keenLookDown3"):
		var pxToMoveDown: int = 0
		if screenYpx - SD_GetSpriteSync() < 33:
			# Keen should never be so high on the screen that his
			# feet are fewer than 33 px from the top.
			pxToMoveDown = s16(screenYpx - 33)
		else:
			# Move 1px/tick.
			pxToMoveDown = s16(SD_GetSpriteSync())
		screenYpx = u16(screenYpx - pxToMoveDown)
		deltaY = s16(RF_PixelToUnit(pxToMoveDown))

	# If we're attached to the ground, or otherwise awesome
	# do somethink inscrutible.
	if ck_currentEpisode_ep == EP_CK6 and ck6_smashScreenDistance != 0:
		# C: `int16_t dx, ax;` and dx is read without ever being set (undefined
		# behaviour). The port uses 0 for it.
		var dx: int = 0
		var ax: int = s16(ck6_smashScreenOfs[ck6_smashScreenDistance] + obj.clipRects.unitY2)
		deltaY = s16(deltaY + (dx - ax)) # Undefined behaviour here
	elif obj.topTI != 0 or obj.clipped == CLIP_not or obj.currentAction == CK_GetActionByName("CK_ACT_keenHang1"):
		if obj.currentAction != CK_GetActionByName("CK_ACT_keenPull1") and \
				obj.currentAction != CK_GetActionByName("CK_ACT_keenPull2") and \
				obj.currentAction != CK_GetActionByName("CK_ACT_keenPull3") and \
				obj.currentAction != CK_GetActionByName("CK_ACT_keenPull4"):
			deltaY = s16(deltaY + obj.deltaPosY)

			#TODO: Something hideous
			# TODO: Convert to 16-bit once the rest is converted
			# (due to unsigned vs signed mess)
			var cmpAmt: int = s32(RF_PixelToUnit(screenYpx) + rf_scrollYUnit + deltaY)
			if cmpAmt != obj.clipRects.unitY2:
				var oneDiff: int = 0
				var otherDiff: int = 0
				if obj.clipRects.unitY2 < cmpAmt:
					oneDiff = s32(cmpAmt - obj.clipRects.unitY2)
				else:
					oneDiff = s32(obj.clipRects.unitY2 - cmpAmt)

				# TODO: Unsigned shift left,
				# followed by a signed shift right...
				otherDiff = s32((oneDiff << 4) & 0xFFFFFFFF) >> 7
				if otherDiff > 48:
					otherDiff = 48
				otherDiff = s32(otherDiff * SD_GetSpriteSync())
				if otherDiff < 16:
					if oneDiff < 16:
						otherDiff = oneDiff
					else:
						otherDiff = 16
				if obj.clipRects.unitY2 < cmpAmt:
					deltaY = s16(deltaY - otherDiff)
				else:
					deltaY = s16(deltaY + otherDiff)
	else:
		# Reset to 140px.
		screenYpx = 140

	# Scroll the screen to keep keen between 33 and 167 px.
	if obj.clipRects.unitY2 < (rf_scrollYUnit + deltaY + RF_PixelToUnit(32)):
		deltaY = s16(deltaY + obj.clipRects.unitY2 - (rf_scrollYUnit + deltaY + RF_PixelToUnit(32)))

	if obj.clipRects.unitY2 > (rf_scrollYUnit + deltaY + RF_PixelToUnit(168)):
		deltaY = s16(deltaY + obj.clipRects.unitY2 - (rf_scrollYUnit + deltaY + RF_PixelToUnit(168)))

	#Don't scroll more than one tile's worth per frame.
	if deltaX != 0 or deltaY != 0:
		if deltaX > 255:
			deltaX = 255
		elif deltaX < -255:
			deltaX = -255

		if deltaY > 255:
			deltaY = 255
		elif deltaY < -255:
			deltaY = -255

		# Do the scroll!
		RF_SmoothScroll(deltaX, deltaY)

		# Update the rectangle of active objects
		ck_activeX0Tile = CK_Cross_max(RF_UnitToTile(rf_scrollXUnit) - CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT) - wide_tiles, 0)
		ck_activeX1Tile = CK_Cross_max(RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320) + CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT) + wide_tiles, 0)
		ck_activeY0Tile = CK_Cross_max(RF_UnitToTile(rf_scrollYUnit) - CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT), 0)
		ck_activeY1Tile = CK_Cross_max(RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208) + CK_INT("CK_activeLimit", DEFAULT_ACTIVE_LIMIT), 0)


# Play a level.
## Freeze enemies (CHEAT-01): the objects that stop thinking. Keen, his shots, platforms (he may be
## riding one), items and the friendly and decorative objects keep going.
func CK_CheatFrozen(obj: CK_object) -> bool:
	return not (obj.type == CT_Player or obj.type == CT_Stunner or obj.type == CT_Nothing or obj.type == CT_Friendly
		or obj.type == CT_CLASS("Platform") or obj.type == CT_CLASS("Item") or obj.type == CT_CLASS("MapFlag"))


func CK_PlayLoop() -> void:
	StartMusic(ck_gameState.currentLevel)
	ck_pogoTimer = 0
	# memset(&ck_keenState, 0, sizeof(ck_keenState));
	ck_keenState.jumpTimer = 0
	ck_keenState.poleGrabTime = 0
	ck_keenState.jumpIsPressed = false
	ck_keenState.jumpWasPressed = false
	ck_keenState.pogoIsPressed = false
	ck_keenState.pogoWasPressed = false
	ck_keenState.shootIsPressed = false
	ck_keenState.shootWasPressed = false
	ck_keenState.keenSliding = false
	ck_keenState.platform = null
	ck_invincibilityTimer = 0
	ck_scrollDisabled = false
	ck_keenState.jumpWasPressed = false
	ck_keenState.pogoWasPressed = false
	ck_keenState.shootWasPressed = false
	game_in_progress = 1
	# If this is nonzero, the level will quit immediately.
	ck_gameState.levelState = LS_Playing

	#ck_keenState.pogoTimer = ck_scrollDisabled = ck_keenState.invincibilityTimer = 0;

	CK_CentreCamera(ck_keenObj)

	# Note that this appears in CK_LoadLevel as well
	if IN_DemoGetMode() != IN_Demo_Off:
		US_InitRndT(false)
	else:
		US_InitRndT(true)

	SD_SetSpriteSync(3)
	SD_SetLastTimeCount(3)
	SD_SetTimeCount(3)

	# (`not quitting`: the port's Quit returns, where C's ends the program)
	while ck_gameState.levelState == LS_Playing and not quitting:
		IN_PumpEvents()
		CK_HandleInput()

		# Set, unset active objects. (J-30: with the wide view, by its edges: wide_tiles more each side,
		# here and in the limits; 0, the original's, otherwise)
		var currentObj: CK_object = ck_keenObj
		while currentObj != null:
			if currentObj.active == 0 and \
					(currentObj.clipRects.tileX2 >= RF_UnitToTile(rf_scrollXUnit) - 1 - wide_tiles) and \
					(currentObj.clipRects.tileX1 <= RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320) + 1 + wide_tiles) and \
					(currentObj.clipRects.tileY1 <= RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208) + 1) and \
					(currentObj.clipRects.tileY2 >= RF_UnitToTile(rf_scrollYUnit) - 1):
				currentObj.active = OBJ_ACTIVE
				currentObj.visible = true
			if currentObj.active != 0:
				if (currentObj.clipRects.tileX2 < ck_activeX0Tile) or \
						(currentObj.clipRects.tileX1 > ck_activeX1Tile) or \
						(currentObj.clipRects.tileY1 > ck_activeY1Tile) or \
						(currentObj.clipRects.tileY2 < ck_activeY0Tile):
					#TODO: Add an Episode callback. Ep 4 requires
					# type 33 to remove int33 (Andy's decomp)
					# For Ep 5 that's type 7
					if currentObj.active == OBJ_EXISTS_ONLY_ONSCREEN:
						CK_RemoveObj(currentObj)
						currentObj = currentObj.next
						continue
					elif currentObj.active != OBJ_ALWAYS_ACTIVE:
						if US_RndT() < SD_GetSpriteSync() * 2 or vl_screenFaded or ck_startingSavedGame != 0:
							currentObj.sde = RF_RemoveSpriteDraw(currentObj.sde)
							if currentObj.type == CT_CLASS("StunnedCreature"):
								currentObj.user3 = RF_RemoveSpriteDrawUsing16BitOffset(currentObj.user3)
							currentObj.active = OBJ_INACTIVE
							currentObj = currentObj.next
							continue
				if not (cheat_freezeEnemies and CK_CheatFrozen(currentObj)):
					CK_RunAction(currentObj)
			currentObj = currentObj.next
		# (CK_ENABLE_PLAYLOOP_DUMPER is not defined in the vanilla build)

		if ck_keenState.platform != null:
			CK_KeenRidePlatform(ck_keenObj)

		currentObj = ck_keenObj
		while currentObj != null:
			# Some strange Keen4 stuff here. Ignoring for now.

			if currentObj.active != 0:
				var collideObj: CK_object = currentObj.next
				while collideObj != null:
					if collideObj.active != 0:
						if (currentObj.clipRects.unitX2 > collideObj.clipRects.unitX1) and \
								(currentObj.clipRects.unitX1 < collideObj.clipRects.unitX2) and \
								(currentObj.clipRects.unitY1 < collideObj.clipRects.unitY2) and \
								(currentObj.clipRects.unitY2 > collideObj.clipRects.unitY1):
							if currentObj.currentAction.collide != &"":
								call(currentObj.currentAction.collide, currentObj, collideObj)
							if collideObj.currentAction.collide != &"":
								call(collideObj.currentAction.collide, collideObj, currentObj)
					collideObj = collideObj.next
			currentObj = currentObj.next

		if ca_mapOn == CK_INT("ck_worldMapNumber", 0):
			# CK_FUNCTION(ck_mapMiscFlagsCheck): NULL unless the episode file names it
			var ck_mapMiscFlagsCheck: StringName = CK_ACT_GetFunction("ck_mapMiscFlagsCheck") \
					if ck_functionTable.has("ck_mapMiscFlagsCheck") else &""
			if ck_mapMiscFlagsCheck == &"":
				if ck_currentEpisode_ep == EP_CK4:
					ck_mapMiscFlagsCheck = &"CK4_MapMiscFlagsCheck"
				elif ck_currentEpisode_ep == EP_CK5:
					ck_mapMiscFlagsCheck = &"CK5_MapMiscFlagsCheck"
				elif ck_currentEpisode_ep == EP_CK6:
					ck_mapMiscFlagsCheck = &"CK6_MapMiscFlagsCheck"
				else:
					#TODO: Maybe print a warning here?
					pass
			# It's actually perfectly normal to not need these, if the world
			# map is boring enough…
			if ck_mapMiscFlagsCheck != &"":
				call(ck_mapMiscFlagsCheck, ck_keenObj)
		else:
			CK_KeenCheckSpecialTileInfo(ck_keenObj)

		currentObj = ck_keenObj
		while currentObj != null:
			if currentObj.active != 0:
				if currentObj.clipRects.tileY2 >= (CA_GetMapHeight() - 1):
					if currentObj.type == CT_Player:
						# Kill Keen if he exits the bottom of the map.
						ck_gameState.levelState = LS_Died
						currentObj = currentObj.next
						continue
					else:
						CK_RemoveObj(currentObj)
						currentObj = currentObj.next
						continue
				if currentObj.visible and currentObj.currentAction.draw != &"":
					currentObj.visible = false #We don't need to render it twice!
					call(currentObj.currentAction.draw, currentObj)
			currentObj = currentObj.next

		# Follow the player with the camera.
		if ca_mapOn == 0 or (ck_currentEpisode_ep == EP_CK4 and ca_mapOn == CK_INT("CK4_UnderwaterCameraLevel", 17)):
			CK_MapCamera(ck_keenObj)
		else:
			CK_NormalCamera(ck_keenObj)

		#Draw the scorebox
		CK_UpdateScoreBox(ck_scoreBoxObj)

		if ck_startingSavedGame != 0:
			ck_startingSavedGame = 0

		CK_VERIFY_Frame()

		RF_Refresh()

		if ck_invincibilityTimer != 0:
			ck_invincibilityTimer = s16(ck_invincibilityTimer - SD_GetSpriteSync())
			if ck_invincibilityTimer < 0:
				ck_invincibilityTimer = 0

		if ck_currentEpisode_ep == EP_CK6 and ck6_smashScreenDistance != 0:
			ck6_smashScreenDistance -= SD_GetSpriteSync()
			if ck6_smashScreenDistance < 0:
				ck6_smashScreenDistance = 0

		if ck_slowMotionEnabled:
			VL_DelayTics(14)
			SD_SetLastTimeCount(SD_GetTimeCount())

		if ck_extraVBLs != 0:
			VL_DelayTics(ck_extraVBLs)

		# If we've finished playing back our demo, or the player presses a key,
		# exit the playloop.
		if IN_DemoGetMode() == IN_Demo_Playback:
			if not vl_screenFaded and IN_CheckAck() != 0:
				ck_gameState.levelState = LS_LevelComplete
				if IN_GetLastScan() != IN_SC_F1:
					IN_SetLastScan(IN_SC_Space)
		elif IN_DemoGetMode() == IN_Demo_PlayDone:
			ck_gameState.levelState = LS_LevelComplete
		else:
			CK_CheckKeys()
		# End-Of-Game cheat
		if IN_GetKeyState(IN_SC_E) and IN_GetKeyState(IN_SC_N) and IN_GetKeyState(IN_SC_D):
			if ck_currentEpisode_ep == EP_CK4:
				ck_gameState.ck4_membersRescued = s16(CK_INT("CK4_NumCouncilsToRescue", 8) - 1)
				ck_gameState.levelState = LS_CouncilRescued
			if ck_currentEpisode_ep == EP_CK5:
				ck_gameState.levelState = LS_DestroyedQED
			if ck_currentEpisode_ep == EP_CK6:
				ck_gameState.levelState = LS_Molly
	game_in_progress = 0
	StopMusic()


# ===================================================================== ck_keen.c

# ck_keenState, ck_itemPoints and ck_itemShadows: gal_ck.gd.

# Episode dependent stuff (int16_t)
var ck_keenMoon: int = 0


func CK_KeenColFunc(a: CK_object, b: CK_object) -> void:
	if b.type == CT_CLASS("Item"):
		if (ck_currentEpisode_ep == EP_CK4 and b.user1 > 11) or \
				(ck_currentEpisode_ep == EP_CK5 and b.user1 > 12):
			return

		SD_PlaySound(CK_INTELEMENT("ck_itemSounds", b.user1))

		b.type = 1
		b.zLayer = 3
		b.gfxChunk = u16(CK_LookupChunk(ck_itemShadows[b.user1]))

		CK_IncreaseScore(ck_itemPoints[b.user1])

		#b->yDirection = -1;

		if b.user1 < 4:
			ck_gameState.keyGems[b.user1] = s16(ck_gameState.keyGems[b.user1] + 1)
		elif b.user1 == 10:
			ck_gameState.numLives = s16(ck_gameState.numLives + 1)
		elif b.user1 == 11:
			ck_gameState.numShots = s16(ck_gameState.numShots + (8 if ck_gameState.difficulty == D_Easy else 5))
		elif (ck_currentEpisode_ep == EP_CK5) and (b.user1 == 12):
			ck_gameState.ck5_securityCard = 1
		CK_SetAction2(b, CK_GetActionByName("CK_ACT_itemNotify"))
	elif b.type == CT_CLASS("Platform"): #Platform
		# impossibleBullet: (the label the two `goto`s below jump to)
		if ck_keenState.platform == null:
			CK_PhysPushY(a, b)
	elif b.type == CT_Stunner and ck_currentEpisode_ep != EP_CK6:
		# Support the impossible bullet on non-Keen6 episodes.
		if CFG_GetConfigBool("impossibleBullet", CK_INT("ck6_impossibleBullet", 0) != 0):
			# goto impossibleBullet;
			if ck_keenState.platform == null:
				CK_PhysPushY(a, b)
	elif ck_currentEpisode_ep == EP_CK4:
		if b.type == CT4_Foot:
			ck_gameState.levelState = LS_Foot
		elif b.type == CT4_StunnedCreature and b.user4 == CT4_Bounder:
			if ck_keenState.platform == null:
				CK_PhysPushY(a, b)
		elif b.type == CT4_Lindsey:
			CK4_ShowPrincessMessage()
			CK_RemoveObj(b)
			# RF_ForceRefresh();
		elif b.type == CT4_CouncilMember:
			if a.topTI != 0:
				if ca_mapOn == CK_INT("CK4_JanitorLevel", 14): # Janitor level
					CK4_ShowJanitorMessage()
					#RF_ForceRefresh();
					CK_RemoveObj(b)
				else:
					SD_PlaySound(CK_SOUNDNUM("SOUND_COUNCILSAVE"))
					ck_gameState.levelState = LS_CouncilRescued
		elif b.type == CT4_Bounder:
			CK_PhysPushXY(a, b, false)
	elif ck_currentEpisode_ep == EP_CK5:
		pass
	elif ck_currentEpisode_ep == EP_CK6:
		if b.type == CT_Stunner:
			# Reflected off of flect
			if b.user4 != 0:
				CK_ShotHit(b)
				CK_SetAction2(a, CK_GetActionByName("CK6_ACT_keenStunned0"))

			if CFG_GetConfigBool("impossibleBullet", CK_INT("ck6_impossibleBullet", 1) != 0):
				# goto impossibleBullet;
				if ck_keenState.platform == null:
					CK_PhysPushY(a, b)
			# The legendary bug!  For some reason, the control flows to check if
			# keen is riding a platform he contacts his own stunner bullet.


const ck_KeenRunXVels: PackedInt32Array = [0, 0, 4, 4, 8, -4, -4, -8]

const ck_KeenPoleOffs: PackedInt32Array = [-8, 0, 8]


func CK_IncreaseScore(score: int) -> void:
	ck_gameState.keenScore = s32(ck_gameState.keenScore + score)
	if IN_DemoGetMode() != IN_Demo_Off:
		return
	if ck_gameState.keenScore >= ck_gameState.nextKeenAt:
		SD_PlaySound(CK_SOUNDNUM("SOUND_GOTEXTRALIFE"))
		ck_gameState.numLives = s16(ck_gameState.numLives + 1)
		ck_gameState.nextKeenAt = s32(ck_gameState.nextKeenAt * 2)


func CK_SpawnKeen(tileX: int, tileY: int, direction: int) -> void:
	ck_keenObj.type = CT_Player #TODO: obj_keen
	ck_keenObj.active = OBJ_ALWAYS_ACTIVE
	ck_keenObj.visible = true
	ck_keenObj.zLayer = 1
	ck_keenObj.clipped = CLIP_not if cheat_noClip else CLIP_normal
	ck_keenObj.posX = u16(RF_TileToUnit(tileX))
	ck_keenObj.posY = u16(RF_TileToUnit(tileY) - 241)
	ck_keenObj.xDirection = s16(direction)
	ck_keenObj.yDirection = 1
	CK_SetAction(ck_keenObj, CK_GetActionByName("CK_ACT_keenStanding"))


# static uint16_t emptyTile (ck4_obj3.c has a function-local static of the same name;
# being later in the chain, its port is the one to take a suffix)
var emptyTile: int = 0


func CK_KeenGetTileItem(tileX: int, tileY: int, itemNumber: int) -> void:
	RF_ReplaceTiles(PackedInt32Array([emptyTile]), 0, 1, tileX, tileY, 1, 1)
	SD_PlaySound(CK_INTELEMENT("ck_itemSounds", itemNumber))

	CK_IncreaseScore(ck_itemPoints[itemNumber])

	if itemNumber < 4:
		ck_gameState.keyGems[itemNumber] = 1 # true
	elif itemNumber == 10:
		ck_gameState.numLives = s16(ck_gameState.numLives + 1)
	elif itemNumber == 11:
		ck_gameState.numShots = s16(ck_gameState.numShots + (8 if ck_gameState.difficulty == D_Easy else 5))

	var notify: CK_object = CK_GetNewObj(true)
	notify.type = 1
	notify.zLayer = 3
	notify.posX = u16(RF_TileToUnit(tileX))
	notify.posY = u16(RF_TileToUnit(tileY))
	notify.yDirection = -1
	notify.user2 = s16(CK_LookupChunk(ck_itemShadows[itemNumber]))
	notify.gfxChunk = u16(notify.user2)
	CK_SetAction(notify, CK_GetActionByName("CK_ACT_itemNotify"))
	notify.clipped = CLIP_not


func CK_KeenGetTileCentilife(tileX: int, tileY: int) -> void:
	RF_ReplaceTiles(PackedInt32Array([emptyTile]), 0, 1, tileX, tileY, 1, 1)
	SD_PlaySound(CK_SOUNDNUM("SOUND_GOTCENTILIFE"))
	CK_SpawnCentilifeNotify(tileX, tileY)
	ck_gameState.numCentilife = s16(ck_gameState.numCentilife + 1)
	if ck_gameState.numCentilife == 100:
		ck_gameState.numCentilife = 0
		SD_PlaySound(CK_SOUNDNUM("SOUND_GOTEXTRALIFE"))
		ck_gameState.numLives = s16(ck_gameState.numLives + 1)

		# Spawn a 1up shadow
		var obj: CK_object = CK_GetNewObj(true)
		obj.type = CT_Friendly
		obj.zLayer = PRIORITIES - 1
		obj.posX = u16(RF_TileToUnit(tileX))
		obj.posY = u16(RF_TileToUnit(tileY))
		obj.yDirection = IN_motion_Up
		obj.gfxChunk = u16(CK_CHUNKNUM("SPR_VIVASPLASH1"))
		obj.user2 = s16(obj.gfxChunk)
		CK_SetAction(obj, CK_GetActionByName("CK_ACT_itemNotify"))
		obj.clipped = CLIP_not


func CK_KeenCheckSpecialTileInfo(obj: CK_object) -> void:
	if ck_keenMoon == 1:
		ck_keenMoon = 0 # Yes, also set in Keen 5
	# (C re-reads the bounds every pass: CK_KillKeen can move obj's clip rectangle)
	var y: int = obj.clipRects.tileY1
	while y <= obj.clipRects.tileY2:
		var x: int = obj.clipRects.tileX1
		while x <= obj.clipRects.tileX2:
			var specialTileInfo: int = (TI_ForeMisc(CA_TileAtPos(x, y, 1)) & 0x7F)
			match specialTileInfo:
				0:
					pass
				MISCFLAG_DEADLY:
					CK_KillKeen()
				4:
					CK_KeenGetTileCentilife(x, y)
				MISCFLAG_GEMHOLDER0, MISCFLAG_GEMHOLDER1, MISCFLAG_GEMHOLDER2, MISCFLAG_GEMHOLDER3:
					if y == obj.clipRects.tileY2 and obj.topTI != 0 and obj.currentAction != CK_GetActionByName("CK_ACT_keenPlaceGem") and ck_gameState.keyGems[specialTileInfo - MISCFLAG_GEMHOLDER0] != 0:
						var targetXUnit: int = RF_TileToUnit(x) - 64
						if obj.posX == targetXUnit:
							ck_gameState.keyGems[specialTileInfo - MISCFLAG_GEMHOLDER0] = s16(ck_gameState.keyGems[specialTileInfo - MISCFLAG_GEMHOLDER0] - 1)
							CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenPlaceGem"))
						else:
							obj.user1 = s16(targetXUnit)
							obj.currentAction = CK_GetActionByName("CK_ACT_keenSlide")
					return
				16:
					if ck_keenMoon == 0:
						ck_keenMoon = 1 # Yes, also set in Keen 5
				21, 22, 23, 24, 25, 26, 27, 28, 29:
					CK_KeenGetTileItem(x, y, specialTileInfo - 17)
					#CK_KeenGetTileItem(x,y,specialTileInfo - 21 + 4);
			x += 1
		y += 1


func CK_KeenPressSwitchThink(obj: CK_object) -> void:
	var switchTarget: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY1, 2)
	var switchTargetX: int = (switchTarget >> 8)
	var switchTargetY: int = (switchTarget & 0xFF)
	var switchTile: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY1, 1)
	var switchMisc: int = TI_ForeMisc(switchTile)

	# Toggle the switch.
	var switchNextTile: int = u16(switchTile + TI_ForeAnimTile(switchTile))
	RF_ReplaceTiles(PackedInt32Array([switchNextTile]), 0, 1, obj.clipRects.tileXmid, obj.clipRects.tileY1, 1, 1)
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENOUTOFAMMO"))

	if switchMisc == MISCFLAG_SWITCHBRIDGE:
		for tileY: int in range(switchTargetY, switchTargetY + 2):
			var tileX: int = switchTargetX - (0 if tileY == switchTargetY else 1)
			while tileX < CA_GetMapWidth():
				var currentTile: int = CA_TileAtPos(tileX, tileY, 1)
				if TI_ForeAnimTile(currentTile) == 0:
					break
				var newTile: int = u16(currentTile + TI_ForeAnimTile(currentTile))
				RF_ReplaceTiles(PackedInt32Array([newTile]), 0, 1, tileX, tileY, 1, 1)
				tileX += 1
	else:
		var infoPlaneInverses: PackedInt32Array = [2, 3, 0, 1, 6, 7, 4, 5]
		var infoPlaneValue: int = CA_TileAtPos(switchTargetX, switchTargetY, 2)
		# NOTE: This is only officially supported in Keen 5, though we probably will
		# want to add it for mods. (WITH_KEEN5: compiled in, so every episode does it)
		if infoPlaneValue >= 91 and infoPlaneValue < 99:
			# Invert the direction of the goplat arrow.
			infoPlaneValue = infoPlaneInverses[infoPlaneValue - 91] + 91
		else:
			# Insert or remove a [B] block.
			infoPlaneValue ^= 0x1F

		CA_mapPlanes[2][switchTargetY * CA_GetMapWidth() + switchTargetX] = u16(infoPlaneValue)


func CK_KeenPressUp(obj: CK_object) -> bool:
	var tileMiscFlag: int = TI_ForeMisc(CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY1, 1))

	# Are we pressing a switch?
	if tileMiscFlag == MISCFLAG_SWITCHPLATON or tileMiscFlag == MISCFLAG_SWITCHPLATOFF or tileMiscFlag == MISCFLAG_SWITCHBRIDGE:
		var destXunit: int = s16(RF_TileToUnit(obj.clipRects.tileXmid) - 64)
		if obj.posX == destXunit:
			# Flip that switch!
			obj.currentAction = CK_GetActionByName("CK_ACT_keenPressSwitch1")
		else:
			obj.user1 = destXunit
			obj.currentAction = CK_GetActionByName("CK_ACT_keenSlide")
		ck_keenState.keenSliding = true
		return true

	# Are we enterting a door?
	if tileMiscFlag == MISCFLAG_DOOR or tileMiscFlag == MISCFLAG_SECURITYDOOR:
		var destUnitX: int = u16(RF_TileToUnit(obj.clipRects.tileXmid) + 96)

		# If the door is two tiles wide, we want to be in the centre.
		var miscFlagLeft: int = TI_ForeMisc(CA_TileAtPos(obj.clipRects.tileXmid - 1, obj.clipRects.tileY1, 1))
		if miscFlagLeft == MISCFLAG_DOOR or miscFlagLeft == MISCFLAG_SECURITYDOOR:
			destUnitX = u16(destUnitX - 256)

		if obj.posX == destUnitX:
			#We're at the door.

			# Is it a security door? (WITH_KEEN5: compiled in, not tied to the episode)
			if tileMiscFlag == MISCFLAG_SECURITYDOOR:
				if ck_gameState.ck5_securityCard != 0:
					ck_gameState.ck5_securityCard = 0
					SD_PlaySound(CK_SOUNDNUM("SOUND_OPENSECURITYDOOR"))
					var newObj: CK_object = CK_GetNewObj(false)
					newObj.posX = u16(obj.clipRects.tileXmid - 2)
					newObj.posY = u16(obj.clipRects.tileY2 - 4)
					newObj.active = OBJ_ALWAYS_ACTIVE
					newObj.type = 1
					CK_SetAction(newObj, CK_GetActionByName("CK_ACT_SecurityDoorOpen"))
					obj.currentAction = CK_GetActionByName("CK_ACT_keenEnterSecurityDoor")
					obj.zLayer = 0
					ck_keenState.keenSliding = true
					return true
				else:
					SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
					obj.currentAction = CK_GetActionByName("CK_ACT_keenStanding")
					ck_keenState.keenSliding = true
					return false
			else:
				ck_invincibilityTimer = 110
				obj.currentAction = CK_GetActionByName("CK_ACT_keenEnterDoor0")
				obj.zLayer = 0

				if (ck_currentEpisode_ep == EP_CK5) and CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY1, 2) == 0:
					CK5_SpawnLightning()
		else:
			obj.user1 = s16(destUnitX)
			obj.currentAction = CK_GetActionByName("CK_ACT_keenSlide")

		ck_keenState.keenSliding = true

		return true

	# No? Return to our caller, who will handle poles/looking up.
	return false


# Think function for keen "sliding" towards a switch, keygem or door.
func CK_KeenSlide(obj: CK_object) -> void:
	var deltaX: int = s16(obj.user1 - obj.posX)
	if deltaX < 0:
		# Move left one px per tick.
		ck_nextX = s16(ck_nextX - SD_GetSpriteSync() * 16)
		# If we're not at our target yet, return.
		if ck_nextX > deltaX:
			return
	elif deltaX > 0:
		# Move right one px per tick.
		ck_nextX = s16(ck_nextX + SD_GetSpriteSync() * 16)
		# If we're not at our target yet, return.
		if ck_nextX < deltaX:
			return

	# We're at our target.
	ck_nextX = deltaX
	obj.user1 = 0
	if not CK_KeenPressUp(obj):
		obj.currentAction = CK_GetActionByName("CK_ACT_keenStanding")


func CK_KeenEnterDoor0(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK0"))


func CK_KeenEnterDoor1(_obj: CK_object) -> void:
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK1"))


# Think function for entering a door.
func CK_KeenEnterDoor(obj: CK_object) -> void:
	var destination: int = CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY2, 2)

	if ck_currentEpisode_ep == EP_CK5:
		if destination == 0x0000:
			ck_gameState.levelState = LS_TeleportToKorath
			obj.currentAction = CK_GetActionByName("CK_ACT_keenEnteredDoor")
			return

		if destination == 0xB1B1:
			ck_gameState.levelState = LS_LevelComplete
			obj.currentAction = CK_GetActionByName("CK_ACT_keenEnteredDoor")
			return
	obj.posY = u16(RF_TileToUnit((destination & 0xFF)) - 256 + 15)
	obj.posX = u16(RF_TileToUnit((destination >> 8)))
	obj.zLayer = 1
	obj.clipped = CLIP_not
	CK_SetAction2(obj, obj.currentAction.next)
	obj.clipped = CLIP_normal
	CK_CentreCamera(obj)


func CK_KeenPlaceGem(obj: CK_object) -> void:
	var oldFGTile: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY2, 1)
	var newFGTile: int = u16(oldFGTile + 18)
	var target: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY2, 2)

	var targetX: int = target >> 8
	var targetY: int = target & 0xFF

	RF_ReplaceTiles(PackedInt32Array([newFGTile]), 0, 1, obj.clipRects.tileXmid, obj.clipRects.tileY2, 1, 1)

	SD_PlaySound(CK_SOUNDNUM("SOUND_OPENGEMDOOR"))

	var newObj: CK_object = CK_GetNewObj(false)

	newObj.posX = u16(targetX)
	newObj.posY = u16(targetY)

	if targetX > CA_GetMapWidth() or targetX < 2 or targetY > CA_GetMapHeight() or targetY < 2:
		Quit("Keyholder points to a bad spot!")
		return

	# Calculate the height of the door.
	var doorHeight: int = 0
	var doorY: int = targetY
	var doorTile: int = CA_TileAtPos(targetX, doorY, 1)
	while true:
		doorHeight += 1
		doorY += 1
		if CA_TileAtPos(targetX, doorY, 1) != doorTile:
			break

	newObj.user1 = s16(doorHeight)
	newObj.clipped = CLIP_not
	newObj.type = CT_Friendly
	newObj.active = OBJ_ALWAYS_ACTIVE
	CK_SetAction(newObj, CK_GetActionByName("CK_ACT_DoorOpen1"))


func CK_KeenRidePlatform(obj: CK_object) -> void:
	# Save the platform pointer, we might be wiping it.
	var plat: CK_object = ck_keenState.platform

	if obj.clipRects.unitX2 < plat.clipRects.unitX1 or obj.clipRects.unitX1 > plat.clipRects.unitX2:
		# We've fallen off the platform horizontally.
		ck_keenState.platform = null
		return

	if obj.deltaPosY < 0:
		# If we've jumped off the platform.
		ck_keenState.platform = null
		if plat.deltaPosY < 0:
			ck_nextX = 0
			ck_nextY = plat.deltaPosY
			CK_PhysUpdateSimpleObj(obj)
			return
	else:
		#Ride the platform
		ck_nextX = plat.deltaPosX
		ck_nextY = s16(plat.clipRects.unitY1 - obj.clipRects.unitY2 - 16)
		CK_PhysUpdateSimpleObj(obj)

		if vl_noPan:
			# Keen has a "/NOPAN" parameter which disables use of the EGA panning
			# register. In order to make platforms less ugly when this is on
			# (though not much less ugly, IMHO), clamp Keen's movement to the nearest
			# 8px, so that scrolling timing is aligned with the platform.
			# This causes a bug where you can't always walk off bounders, see:
			#   https://pckf.com/viewtopic.php?p=102264
			#   https://www.youtube.com/watch?v=cScZlYPhFnU
			obj.posX = u16(obj.posX & ~0x7F)
			obj.posX = u16(obj.posX | (plat.posX & 0x7F))
		else:
			# Make Keen's x-position move in tandem with the platform, so that they appear to move as a unit,
			# and (more importantly) that the platform moves in time with the camera scrolling (which is based
			# on Keen's position).
			# Technically, this probably should clear out the low bits like the /NOPAN case, so that their subpixel
			# values are identical.
			obj.posX = u16(obj.posX | (plat.posX & 0x1F))

		# We've hit the ceiling?
		if obj.bottomTI != 0:
			ck_keenState.platform = null
			return

		# We're standing on something, don't fall down!
		obj.topTI = 0x19


func CK_KeenTryClimbPole(obj: CK_object) -> bool:
	if SD_GetLastTimeCount() < ck_keenState.poleGrabTime:
		ck_keenState.poleGrabTime = 0
	elif s32(SD_GetLastTimeCount() - ck_keenState.poleGrabTime) < 19:
		return false

	var candidateTile: int = CA_TileAtPos(obj.clipRects.tileXmid,
		(RF_UnitToTile(obj.clipRects.unitY1 + 96)) if (ck_inputFrame.yDirection == -1) else (obj.clipRects.tileY2 + 1), 1)

	if (TI_ForeMisc(candidateTile) & 0x7F) == 1:
		obj.posX = u16(128 + RF_TileToUnit(obj.clipRects.tileXmid - 1))
		ck_nextX = 0
		ck_nextY = s16(ck_inputFrame.yDirection << 5)
		obj.clipped = CLIP_not
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleSit")
		return true
	return false


func CK_KeenRunningThink(obj: CK_object) -> void:
	if ck_inputFrame.xDirection == 0:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenStanding")
		CK_HandleInputOnGround(obj)
		return

	obj.xDirection = ck_inputFrame.xDirection

	if ck_inputFrame.yDirection == -1:
		if CK_KeenTryClimbPole(obj):
			return
		if ck_keenState.keenSliding or CK_KeenPressUp(obj):
			return
	elif ck_inputFrame.yDirection == 1:
		if CK_KeenTryClimbPole(obj):
			return

	if ck_keenState.shootIsPressed and not ck_keenState.shootWasPressed:
		ck_keenState.shootWasPressed = true

		if ck_inputFrame.yDirection == -1:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenShootUp1")
		else:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenShoot1")
		return

	if ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed:
		ck_keenState.jumpWasPressed = true
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENJUMP"))
		obj.velX = s16(obj.xDirection * 16)
		obj.velY = -40
		ck_nextX = 0
		ck_nextY = 0
		ck_keenState.jumpTimer = 18
		obj.currentAction = CK_GetActionByName("CK_ACT_keenJump1")
		# Is this the mystical 'impossible pogo'?
		# k5disasm has a 'return' here, probably a mistake?

	if ck_keenState.pogoIsPressed and not ck_keenState.pogoWasPressed:
		ck_keenState.pogoWasPressed = true
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPogo1")
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENJUMP"))
		obj.velX = s16(obj.xDirection * 16)
		obj.velY = -48
		# Should this be nextY? Andy seems to think so, but lemm thinks that X is right...
		ck_nextX = 0
		ck_keenState.jumpTimer = 24
		return

	# Andy seems to think this is Y as well. Need to do some more disasm.
	# If this is an X vel, then surely we'd want to multiply it by the direction?
	ck_nextX = s16(ck_nextX + ck_KeenRunXVels[obj.topTI & 7] * SD_GetSpriteSync())

	if (obj.currentAction.chunkLeft == CK_GetActionByName("CK_ACT_keenRun1").chunkLeft) and obj.user3 == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK0"))
		obj.user3 = 1
		return

	if (obj.currentAction.chunkLeft == CK_GetActionByName("CK_ACT_keenRun3").chunkLeft) and obj.user3 == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK1"))
		obj.user3 = 1
		return
	if (obj.currentAction.chunkLeft == CK_GetActionByName("CK_ACT_keenRun2").chunkLeft) or (obj.currentAction.chunkLeft == CK_GetActionByName("CK_ACT_keenRun4").chunkLeft):
		obj.user3 = 0


func CK_HandleInputOnGround(obj: CK_object) -> void:
	# (WITH_KEEN5) If we're riding a platform, do it surfin' style!
	if obj.topTI == 0x19:
		# But only if such an action exists in this episode. :/
		if ck_currentEpisode_ep == EP_CK5:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenRidePlatform")
	if ck_inputFrame.xDirection != 0:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenRun1")
		CK_KeenRunningThink(obj)
		@warning_ignore("integer_division")
		ck_nextX = s16((obj.xDirection * obj.currentAction.velX * SD_GetSpriteSync()) / 4)
		return

	if ck_keenState.shootIsPressed and not ck_keenState.shootWasPressed:
		ck_keenState.shootWasPressed = true
		if ck_inputFrame.yDirection == -1:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenShootUp1")
		else:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenShoot1")
		return

	if ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed:
		ck_keenState.jumpWasPressed = true
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENJUMP"))
		obj.velX = 0
		obj.velY = -40
		ck_nextY = 0
		ck_keenState.jumpTimer = 18
		obj.currentAction = CK_GetActionByName("CK_ACT_keenJump1")
		return

	if ck_keenState.pogoIsPressed and not ck_keenState.pogoWasPressed:
		ck_keenState.pogoWasPressed = true
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENJUMP"))
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPogo1")
		obj.velX = 0
		obj.velY = -48
		ck_nextY = 0
		ck_keenState.jumpTimer = 24
		return

	if ck_inputFrame.yDirection == -1:
		if CK_KeenTryClimbPole(obj):
			return
		if not ck_keenState.keenSliding and CK_KeenPressUp(obj):
			return
		obj.currentAction = CK_GetActionByName("CK_ACT_keenLookUp1")
	elif ck_inputFrame.yDirection == 1:
		# Try poles.
		if CK_KeenTryClimbPole(obj):
			return
		# Keen looks down.
		obj.currentAction = CK_GetActionByName("CK_ACT_keenLookDown1")
		return


func CK_KeenStandingThink(obj: CK_object) -> void:
	# (WITH_KEEN5) If we're riding a platform, do it surfin' style!
	if obj.topTI == 0x19:
		# But only if such an action exists in this episode. :/
		if ck_currentEpisode_ep == EP_CK5:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenRidePlatform")
	if ck_inputFrame.xDirection != 0 or ck_inputFrame.yDirection != 0 or ck_keenState.jumpIsPressed or ck_keenState.pogoIsPressed or ck_keenState.shootIsPressed:
		obj.user1 = 0 #Idle Time + Idle State
		obj.user2 = 0
		obj.currentAction = CK_GetActionByName("CK_ACT_keenStanding")
		CK_HandleInputOnGround(obj)

		return

	#If not on platform
	if (obj.topTI & ~7) != 0x18:
		obj.user1 = s16(obj.user1 + SD_GetSpriteSync())

	if obj.user2 == 0 and obj.user1 > 200:
		obj.user2 = s16(obj.user2 + 1)
		obj.currentAction = CK_GetActionByName("CK_ACT_keenIdle")
		obj.user1 = 0
		return

	if obj.user2 == 1 and obj.user1 > 300:
		obj.user2 = s16(obj.user2 + 1)
		if (ck_currentEpisode_ep == EP_CK4) and (ck_keenMoon == 1):
			ck_keenMoon = 2
			obj.currentAction = CK_GetActionByName("CK_ACT_keenMoon1")
		else:
			obj.currentAction = CK_GetActionByName("CK_ACT_keenBored1")
		obj.user1 = 0
		return

	if obj.user2 == 2 and obj.user1 > 700:
		obj.user2 = s16(obj.user2 + 1)
		obj.currentAction = CK_GetActionByName("CK_ACT_keenOpenBook1")
		obj.user1 = 0


func CK_KeenLookUpThink(obj: CK_object) -> void:
	if ck_inputFrame.yDirection != -1 or \
			ck_inputFrame.xDirection != 0 or \
			(ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed) or \
			(ck_keenState.pogoIsPressed and not ck_keenState.pogoWasPressed) or \
			(ck_keenState.shootIsPressed):
		obj.currentAction = CK_GetActionByName("CK_ACT_keenStanding")
		CK_HandleInputOnGround(obj)


func CK_KeenLookDownThink(obj: CK_object) -> void:
	#Try to jump down
	if ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed and (obj.topTI & 7) == 1:
		ck_keenState.jumpWasPressed = true

		#If the tiles below the player are blocking on any side but the top, they cannot be jumped through
		var tile1: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY2, 1)
		var tile2: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY2 + 1, 1)

		if TI_ForeLeft(tile1) != 0 or TI_ForeBottom(tile1) != 0 or TI_ForeRight(tile1) != 0:
			return

		if TI_ForeLeft(tile2) != 0 or TI_ForeBottom(tile2) != 0 or TI_ForeRight(tile2) != 0:
			return

		var deltay: int = u16(CK_Cross_max(SD_GetSpriteSync(), 4) << 4)

		#Moving platforms
		if ck_keenState.platform != null:
			deltay = u16(deltay + ck_keenState.platform.deltaPosY)

		ck_keenState.platform = null

		obj.clipRects.unitY2 = u16(obj.clipRects.unitY2 + deltay)
		obj.posY = u16(obj.posY + deltay)
		ck_nextX = 0
		ck_nextY = 0
		obj.currentAction = CK_GetActionByName("CK_ACT_keenFall1")
		obj.velX = 0
		obj.velY = 0
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENFALL"))
		return

	if ck_inputFrame.yDirection != 1 or ck_inputFrame.xDirection != 0 or (ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed) or (ck_keenState.pogoIsPressed and not ck_keenState.pogoWasPressed):
		obj.currentAction = CK_GetActionByName("CK_ACT_keenLookDown4")
		return


# TODO: More to modify here
func CK_KeenDrawFunc(obj: CK_object) -> void:
	if obj.topTI == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENFALL"))
		obj.velX = s16(obj.xDirection * 8)
		obj.velY = 0
		CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenFall1"))
		ck_keenState.jumpTimer = 0
	elif (obj.topTI & 0xFFF8) == 8:
		CK_KillKeen()
	elif obj.topTI == 0x29:
		# Keen6 conveyor belt right
		ck_nextX = s16(SD_GetSpriteSync() * 8)
		ck_nextY = 0
		obj.user1 = 0
		CK_PhysUpdateNormalObj(obj)
	elif obj.topTI == 0x31:
		# Keen6 conveyor belt left
		ck_nextX = s16(SD_GetSpriteSync() * -8)
		ck_nextY = 0
		obj.user1 = 0
		CK_PhysUpdateNormalObj(obj)
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# TODO: More to modify here
func CK_KeenRunDrawFunc(obj: CK_object) -> void:
	if obj.topTI == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENFALL"))
		obj.velX = s16(obj.xDirection * 8)
		obj.velY = 0
		CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenFall1"))
		ck_keenState.jumpTimer = 0
	elif (obj.topTI & 0xFFF8) == 8:
		CK_KillKeen()
	elif obj.topTI == 0x29:
		# Keen6 conveyor belt right
		ck_nextX = s16(SD_GetSpriteSync() * 8)
		ck_nextY = 0
		CK_PhysUpdateNormalObj(obj)
	elif obj.topTI == 0x31:
		# Keen6 conveyor belt left
		ck_nextX = s16(SD_GetSpriteSync() * -8)
		ck_nextY = 0
		CK_PhysUpdateNormalObj(obj)

	# If we're running into a wall, we should stand still.
	if (obj.rightTI != 0 and obj.xDirection == -1) or (obj.leftTI != 0 and obj.xDirection == 1):
		obj.actionTimer = 0
		obj.currentAction = CK_GetActionByName("CK_ACT_keenStanding")
		obj.gfxChunk = u16(obj.currentAction.chunkLeft if (obj.xDirection == -1) else obj.currentAction.chunkRight)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK_KeenReadThink(obj: CK_object) -> void:
	# If we're running in "Store Demo" mode, abort the game if the player
	# isn't doing anything.
	if ck_storeDemo:
		ck_gameState.levelState = LS_AbortGame
		IN_ClearKeysDown()

	if ck_inputFrame.xDirection != 0 or ck_keenState.jumpIsPressed or ck_keenState.pogoIsPressed:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenStowBook1")
		obj.user1 = 0
		obj.user2 = 0


func CK_KeenJumpThink(obj: CK_object) -> void:
	# Handle Jump Cheat
	if ck_gameState.jumpCheat and ck_keenState.jumpIsPressed:
		obj.velY = -40
		ck_keenState.jumpTimer = 18
		ck_keenState.jumpWasPressed = true

	if ck_keenState.jumpTimer != 0:
		if ck_keenState.jumpTimer <= SD_GetSpriteSync():
			ck_nextY = s16(obj.velY * ck_keenState.jumpTimer)
			ck_keenState.jumpTimer = 0
		else:
			ck_nextY = s16(obj.velY * SD_GetSpriteSync())
			if not ck_gameState.jumpCheat:
				ck_keenState.jumpTimer -= SD_GetSpriteSync()

		# Stop moving up if we've let go of control.
		if not ck_keenState.jumpIsPressed:
			ck_keenState.jumpTimer = 0

		if ck_keenState.jumpTimer == 0 and obj.currentAction.next != null:
			obj.currentAction = obj.currentAction.next
	else:
		if ck_gameState.difficulty == D_Easy and CK_INT("ck_easyJumpGravity", 1) != 0:
			CK_PhysGravityMid(obj)
		else: # Normal or Hard
			CK_PhysGravityHigh(obj)

		if obj.velY > 0 and obj.currentAction != CK_GetActionByName("CK_ACT_keenFall1") and obj.currentAction != CK_GetActionByName("CK_ACT_keenFall2"):
			obj.currentAction = obj.currentAction.next

	#Move horizontally
	if ck_inputFrame.xDirection != 0:
		obj.xDirection = ck_inputFrame.xDirection
		CK_PhysAccelHorz(obj, ck_inputFrame.xDirection * 2, 24)

		# K1n9_Duk3's fix for 70Hz ledge grabbing.
		# See: https://pckf.com/viewtopic.php?p=108855#p108855
		if CFG_GetConfigBool("ck_fix70HzLedgeGrabbing", CK_NEW_FEATURE_DEFAULT):
			# Keen can only grab edges reliably if the hiteast / hitwest values are
			# set correctly, which requires the object to move by at least 1 unit
			# along the x axis. CK_PhysAccelHorz only accelerates every other tic and
			# hitting a wall while jumping always sets xVel to 0, which means it
			# would take at least 2 tics to make the object move and set hiteast and
			# hitwest to the correct values after hitting a wall. The original Keen
			# games only ran at up to 35 fps (2 tics per frame), so the ck_nextX value
			# would almost never be 0 here. This fix makes sure that Keen always
			# moves by at least 1 unit while jumping and holding down the left or
			# right key, so that Keen can grab edges reliably.
			if ck_nextX == 0 and SD_GetSpriteSync() < 2:
				ck_nextX = ck_inputFrame.xDirection
	else:
		CK_PhysDampHorz(obj)

	#Pole
	if obj.bottomTI == 17:
		ck_nextX = 0
		obj.velX = 0

	#Shooting
	if ck_keenState.shootIsPressed and not ck_keenState.shootWasPressed:
		ck_keenState.shootWasPressed = true
		match ck_inputFrame.yDirection:
			-1:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenJumpShootUp1")
			0:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenJumpShoot1")
			1:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenJumpShootDown1")
		return

	if ck_keenState.pogoIsPressed and not ck_keenState.pogoWasPressed:
		ck_keenState.pogoWasPressed = true
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPogo2")
		ck_keenState.jumpTimer = 0
		return

	if ck_inputFrame.yDirection == -1:
		CK_KeenTryClimbPole(obj)


# rf_scrollXUnit, rf_scrollYUnit: gal_rf.gd.

func CK_KeenJumpDrawFunc(obj: CK_object) -> void:
	if obj.rightTI != 0 and obj.xDirection == -1:
		obj.velX = 0
	elif obj.leftTI != 0 and obj.xDirection == 1:
		obj.velX = 0

	# Keen 6 v1.0 (KEEN6C.EXE 0A2F:1956, CK_KeenPoleHoleV10): a head hit first looks for a pole
	# hole (a tile whose bottom wall is 17) in the rows from one above the top of Keen's box to one
	# above its bottom; on one, Keen is centred on the pole and carries on up through it
	var throughPoleHole: bool = false
	if obj.bottomTI != 0 and CK_INT("CK_KeenPoleHoleV10", 0) != 0:
		var row: int = obj.clipRects.tileY1 - 1
		var rowCount: int = obj.clipRects.tileY1
		while not throughPoleHole and (obj.clipRects.tileY2 & 0xFFFF) >= (rowCount & 0xFFFF):
			for x: int in range(obj.clipRects.tileX1, obj.clipRects.tileX2 + 1):
				if TI_ForeBottom(CA_TileAtPos(x, row, 1)) == 17:
					obj.velX = 0
					obj.posX = u16(RF_TileToUnit(obj.clipRects.tileXmid) - 32)
					var dy: int = s16(obj.velY * SD_GetSpriteSync())
					obj.posY = u16(obj.posY + dy)
					obj.clipRects.unitY1 = u16(obj.clipRects.unitY1 + dy)
					throughPoleHole = true    # on to the landing check
					break
			rowCount += 1
			row += 1

	# Did we hit our head on the ceiling?
	if obj.bottomTI != 0 and not throughPoleHole:
		#TODO: Something to do with poles (push keen into the centre)
		if obj.bottomTI == 17: #Pole
			obj.posY = u16(obj.posY - 32)
			obj.clipRects.unitY1 = u16(obj.clipRects.unitY1 - 32)
			obj.velX = 0
			obj.posX = u16(RF_TileToUnit(obj.clipRects.tileXmid) - 32)
			# (v1.0 then bumps the head as on any ceiling: the sound, the speed, the jump's end)
			if CK_INT("CK_KeenPoleHoleV10", 0) != 0 and not ck_gameState.jumpCheat:
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENHITCEILING"))
				obj.velY = s16(obj.velY + 16)    # (17 > 1)
				if obj.velY < 0:
					obj.velY = 0
				ck_keenState.jumpTimer = 0
		else:
			# (WITH_KEEN6: compiled in, not tied to the episode)
			if obj.bottomTI == 0x21: # Bloog switches
				CK6_ToggleBigSwitch(obj, false)

			if not ck_gameState.jumpCheat:
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENHITCEILING"))
				if obj.bottomTI > 1:
					obj.velY = s16(obj.velY + 16)
					if obj.velY < 0:
						obj.velY = 0
				else:
					obj.velY = 0
				ck_keenState.jumpTimer = 0

	# Have we landed?
	if obj.topTI != 0:
		obj.deltaPosY = 0
		#Check if deadly.
		if (obj.topTI & ~7) == 8:
			CK_KillKeen()
		else:
			# (WITH_KEEN5: compiled in, not tied to the episode)
			if obj.topTI == 0x39: # Fuse
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENLANDONFUSE"))
			if ck_currentEpisode_ep == EP_CK6 and obj.topTI == 0x21: # BigSwitch
				CK6_ToggleBigSwitch(obj, true)
			if obj.topTI != 0x19 or ck_keenState.jumpTimer == 0: # Or standing on a platform.
				obj.user1 = 0 # Being on the ground is boring.
				obj.user2 = 0

				#TODO: Finish these
				if obj.currentAction == CK_GetActionByName("CK_ACT_keenJumpShoot1"):
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenShoot1"))
				elif obj.currentAction == CK_GetActionByName("CK_ACT_keenJumpShootUp1"):
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenShootUp1"))
				elif ck_inputFrame.xDirection != 0:
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenRun1"))
				else:
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenStanding"))
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENLAND"))
	elif obj.deltaPosY > 0:
		# temp6 = Keen's previous upper y coord
		var temp6: int = obj.clipRects.unitY1 - obj.deltaPosY
		# temp8 = Keen's current upper y coord - 1.5 tiles, rounded to nearest tile, + 1.5 tiles
		var temp8: int = ((obj.clipRects.unitY1 - 64) & 0xFF00) + 64
		# temp10 = temp8 in tile coords, - 1
		var temp10: int = RF_UnitToTile(temp8) - 1

		# If we're moving past a tile boundary.
		if temp6 < temp8 and obj.clipRects.unitY1 >= temp8:
			# Moving left...
			if ck_inputFrame.xDirection == -1:
				var tileX: int = obj.clipRects.tileX1 - (1 if obj.rightTI != 0 else 0)
				var tileY: int = temp10
				#VL_ScreenRect((tileX << 4) - (rf_scrollXUnit >> 4), (tileY << 4) - (rf_scrollYUnit >> 4), 16, 16, 1);
				var upperTile: int = CA_TileAtPos(tileX, tileY, 1)
				var lowerTile: int = CA_TileAtPos(tileX, tileY + 1, 1)
				if (TI_ForeLeft(upperTile) == 0 and TI_ForeRight(upperTile) == 0 and TI_ForeTop(upperTile) == 0 and TI_ForeBottom(upperTile) == 0) and \
						TI_ForeRight(lowerTile) != 0 and TI_ForeTop(lowerTile) != 0:
					obj.xDirection = -1
					obj.clipped = CLIP_not
					obj.posX = u16((obj.posX & 0xFF00) + 128)
					obj.posY = u16(temp8 - 64)
					obj.velY = 0
					obj.deltaPosY = 0
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenHang1"))
			elif ck_inputFrame.xDirection == 1:
				var tileXr: int = obj.clipRects.tileX2 + (1 if obj.leftTI != 0 else 0)
				var tileYr: int = temp10
				var upperTileR: int = CA_TileAtPos(tileXr, tileYr, 1)
				var lowerTileR: int = CA_TileAtPos(tileXr, tileYr + 1, 1)

				if TI_ForeLeft(upperTileR) == 0 and TI_ForeRight(upperTileR) == 0 and TI_ForeTop(upperTileR) == 0 and TI_ForeBottom(upperTileR) == 0 and \
						TI_ForeLeft(lowerTileR) != 0 and TI_ForeTop(lowerTileR) != 0:
					obj.xDirection = 1
					obj.clipped = CLIP_not
					obj.posX = u16((obj.posX & 0xFF00) + 256)
					obj.posY = u16(temp8 - 64)
					obj.velY = 0
					obj.deltaPosY = 0
					CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenHang1"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK_KeenPogoBounceThink(obj: CK_object) -> void:
	obj.velY = -48
	ck_nextY = s16(6 * obj.velY)
	ck_keenState.jumpTimer = 24
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENPOGO"))


func CK_KeenPogoThink(obj: CK_object) -> void:
	if ck_keenState.jumpTimer == 0:
		if ck_gameState.difficulty == D_Easy and CK_INT("ck_easyJumpGravity", 1) != 0:
			CK_PhysGravityMid(obj)
		else:
			CK_PhysGravityHigh(obj)
	else:
		if ck_keenState.jumpIsPressed or ck_keenState.jumpTimer <= 9:
			CK_PhysGravityLow(obj)
		else:
			CK_PhysGravityHigh(obj)

		if ck_keenState.jumpTimer <= SD_GetSpriteSync():
			ck_keenState.jumpTimer = 0
		else:
			ck_keenState.jumpTimer -= SD_GetSpriteSync()

		if ck_keenState.jumpTimer == 0 and obj.currentAction.next != null:
			obj.currentAction = obj.currentAction.next
	if ck_inputFrame.xDirection != 0:
		if obj.velX == 0:
			obj.xDirection = ck_inputFrame.xDirection
		CK_PhysAccelHorz(obj, ck_inputFrame.xDirection, 24)
	else:
		ck_nextX = s16(ck_nextX + obj.velX * SD_GetSpriteSync())
		if obj.velX < 0:
			obj.xDirection = -1
		elif obj.velX > 0:
			obj.xDirection = 1

	# Stop for poles?
	if obj.bottomTI == 17:
		ck_nextX = 0
		obj.velX = 0

	#Shooting
	if ck_keenState.shootIsPressed and not ck_keenState.shootWasPressed:
		ck_keenState.shootWasPressed = true
		match ck_inputFrame.yDirection:
			-1:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenJumpShootUp1")
				return
			0:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenJumpShoot1")
				return
			1:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenJumpShootDown1")
				return

	#Stop pogoing if Alt pressed
	if ck_keenState.pogoIsPressed and not ck_keenState.pogoWasPressed:
		ck_keenState.pogoWasPressed = true
		obj.currentAction = CK_GetActionByName("CK_ACT_keenFall1")


# (WITH_KEEN5)
func CK_KeenBreakFuse(x: int, y: int) -> void:
	CK5_SpawnFuseExplosion(x, y)
	ck_gameState.ck5_fusesRemaining = s16(ck_gameState.ck5_fusesRemaining - 1)
	if ck_gameState.ck5_fusesRemaining == 0:
		CK5_SpawnLevelEnd()

	var brokenFuseTiles: PackedInt32Array = [0, 0]
	brokenFuseTiles[0] = CA_TileAtPos(0, 0, 1)
	brokenFuseTiles[1] = CA_TileAtPos(0, 1, 1)

	RF_ReplaceTiles(brokenFuseTiles, 0, 1, x, y, 1, 2)


func CK_KeenPogoDrawFunc(obj: CK_object) -> void:
	if obj.rightTI != 0 and obj.xDirection == -1:
		obj.velX = 0
	elif obj.leftTI != 0 and obj.xDirection == 1:
		obj.velX = 0

	if obj.bottomTI != 0:
		if obj.bottomTI == 17: #Pole
			obj.posY = u16(obj.posY - 32)
			obj.clipRects.unitY1 = u16(obj.clipRects.unitY1 - 32)
			obj.velX = 0
			obj.posX = u16(RF_TileToUnit(obj.clipRects.tileXmid) - 32)
		else:
			# (WITH_KEEN6: compiled in, not tied to the episode)
			if obj.bottomTI == 0x21: # Bloog switches
				CK6_ToggleBigSwitch(obj, false)

			if not ck_gameState.jumpCheat:
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENHITCEILING"))

				if obj.bottomTI > 1:
					obj.velY = s16(obj.velY + 16)
					if obj.velY < 0:
						obj.velY = 0
				else:
					obj.velY = 0

				ck_keenState.jumpTimer = 0

	# Houston, we've landed!
	if obj.topTI != 0:
		obj.deltaPosY = 0
		#Check if deadly.
		if (obj.topTI & ~7) == 8:
			CK_KillKeen()
		else:
			if ck_currentEpisode_ep == EP_CK6:
				if obj.topTI == 0x21: # BigSwitch
					CK6_ToggleBigSwitch(obj, true)
				elif obj.topTI == 0x29: # Keen 6 conveyor belt right
					obj.velX = s16(obj.velX + 8)
					if obj.velX > 8:
						obj.velX = 8
				elif obj.topTI == 0x31: # Keen 6 conveyor belt left
					obj.velX = s16(obj.velX - 8)
					if obj.velX < -8:
						obj.velX = -8
			if ck_currentEpisode_ep == EP_CK5 and obj.topTI == 0x39: # Fuse
				if obj.velY >= 0x30:
					CK_KeenBreakFuse(obj.clipRects.tileXmid, obj.clipRects.tileY2)
					obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)
					return
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENLANDONFUSE"))
			if obj.topTI != 0x19 or ck_keenState.jumpTimer == 0:
				obj.velY = -48
				ck_keenState.jumpTimer = 24
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENPOGO"))
				CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenPogo2"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK_KeenSpecialColFunc(obj: CK_object, other: CK_object) -> void:
	if other.type == CT_CLASS("Platform"):
		# NOTE: Keen 6 fixes the "pole foreground bug", where Keen can
		# get stuck with a zLayer of 3 if ledge-grabbing is interrupted.
		# See:
		#     https://pckf.com/viewtopic.php?t=12901
		if CFG_GetConfigBool("ck_fixPlatformZLayer", (ck_currentEpisode_ep == EP_CK6)) or fix_on("keen_over_scenery"):
			obj.zLayer = 1
		obj.clipped = CLIP_normal
		CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenFall1"))
		ck_keenState.jumpTimer = 0
		obj.velX = 0
		obj.velY = 0
		CK_PhysPushY(obj, other)
	elif (ck_currentEpisode_ep == EP_CK4) and \
			((other.type == CT4_Mushroom) or (other.type == CT4_Arachnut) or (other.type == CT4_Berkeloid)):
		CK_KillKeen()
	elif ((ck_currentEpisode_ep == EP_CK4) and (other.type == CT4_Bounder)) or \
			((ck_currentEpisode_ep == EP_CK5) and ((other.type == CT5_Ampton) or (other.type == CT5_Korath))) or \
			((ck_currentEpisode_ep == EP_CK6) and ((other.type == CT6_Gik) or (other.type == CT6_Flect) or (other.type == CT6_Blooglet))) or \
			false:
		obj.zLayer = 1
		obj.clipped = CLIP_normal
		CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenFall1"))
		ck_keenState.jumpTimer = 0
		obj.velX = 0
		obj.velY = 0

		# Keen's yDirection needs to be Down (1) when on the ground, or
		# we can hit _nasty_ issues when going through a door, leading to
		# a visual glitch (walking down into the door) and an exploit
		# (the door's target is read from the wrong tile, becoming 0000 in
		# most cases, leading to finishing the level, and possibly going to
		# the secret level in Keen 5).
		# See:
		#   https://keenwiki.shikadi.net/wiki/Keen_5_Bugs#Ampton_Pole_Push_Door_Trick
		#   https://keenwiki.shikadi.net/wiki/Keen_5_Bugs#Shelley.2FDoor_Trick
		#   https://keenwiki.shikadi.net/wiki/Keen_4_Bugs#Bounder_Pole_Door_Glitch
		if not CFG_GetConfigBool("ck_poleDoorGlitch", true):
			obj.yDirection = IN_motion_Down
		if ck_currentEpisode_ep == EP_CK4:
			CK_PhysPushXY(obj, other, false)
		if ck_currentEpisode_ep == EP_CK6:
			CK_PhysPushY(obj, other)


func CK_KeenSpecialDrawFunc(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Used by CK6
func CK_KeenJumpDownThink(obj: CK_object) -> void:
	obj.clipped = CLIP_normal


func CK_KeenHangThink(obj: CK_object) -> void:
	if ck_inputFrame.yDirection == -1 or ck_inputFrame.xDirection == obj.xDirection:
		var tile: int = 0
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPull1")

		if obj.xDirection == 1:
			tile = CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1 - 1, 1)
			ck_nextY = -256
		else:
			tile = CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY1 - 1, 1)
			ck_nextY = -128

		if (TI_ForeMisc(tile) & 0x80) == 0:
			obj.zLayer = 3
	elif ck_inputFrame.yDirection == 1 or (ck_inputFrame.xDirection != 0 and ck_inputFrame.xDirection != obj.xDirection):
		# Drop down.
		obj.currentAction = CK_GetActionByName("CK_ACT_keenFall1")
		obj.clipped = CLIP_normal


func CK_KeenPullThink1(obj: CK_object) -> void:
	if obj.xDirection == 1:
		ck_nextX = 128
	else:
		ck_nextY = -128


func CK_KeenPullThink2(obj: CK_object) -> void:
	ck_nextX = s16(obj.xDirection * 128)
	ck_nextY = -128


func CK_KeenPullThink3(_obj: CK_object) -> void:
	ck_nextY = -128


func CK_KeenPullThink4(obj: CK_object) -> void:
	obj.clipped = CLIP_normal
	obj.zLayer = 1
	ck_nextY = 128


func CK_KeenDeathThink(obj: CK_object) -> void:
	CK_PhysGravityMid(obj)
	ck_nextX = s16(obj.velX * SD_GetSpriteSync())
	if not CK_ObjectVisible(obj):
		ck_gameState.levelState = LS_Died


func CK_KillKeen() -> void:
	var obj: CK_object = ck_keenObj
	if ck_invincibilityTimer != 0 or ck_godMode or (obj.currentAction == CK_GetActionByName("CK_ACT_keenNot")):
		return

	ck_keenMoon = 0 # Yes, also set in Keen 5
	ck_invincibilityTimer = 30
	ck_scrollDisabled = true
	obj.clipped = CLIP_not
	obj.zLayer = 3
	if (ck_currentEpisode_ep == EP_CK4) and ca_mapOn == 17:
		if US_RndT() < 0x80:
			CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_KeenSwimDie0"))
		else:
			CK_SetAction2(obj, CK_GetActionByName("CK4_ACT_KeenSwimDie1"))
	else:
		if US_RndT() < 0x80:
			CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenDie0"))
		else:
			CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenDie1"))

	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENDIE"))

	obj.velY = -40
	obj.velX = 16


func CK_KeenPoleHandleInput(obj: CK_object) -> void:
	if ck_inputFrame.xDirection != 0:
		obj.xDirection = ck_inputFrame.xDirection

	#Shooting things. *ZAP!*
	if ck_keenState.shootIsPressed and not ck_keenState.shootWasPressed:
		ck_keenState.shootWasPressed = true

		match ck_inputFrame.yDirection:
			-1:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleShootUp1")
			0:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleShoot1")
			1:
				obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleShootDown1")

	if ck_keenState.jumpIsPressed and not ck_keenState.jumpWasPressed:
		ck_keenState.jumpWasPressed = true
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENJUMP"))
		obj.velX = ck_KeenPoleOffs[ck_inputFrame.xDirection + 1]
		obj.velY = -20
		obj.clipped = CLIP_normal
		ck_keenState.jumpTimer = 10
		obj.currentAction = CK_GetActionByName("CK_ACT_keenJump1")
		obj.yDirection = 1
		ck_keenState.poleGrabTime = SD_GetLastTimeCount()
	return


func CK_KeenPoleSitThink(obj: CK_object) -> void:
	#TODO: Support climb up/down
	if ck_inputFrame.yDirection == 1:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleDown1")
		obj.yDirection = 1
		CK_KeenPoleDownThink(obj)
		return
	elif ck_inputFrame.yDirection == -1:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleUp1")
		obj.yDirection = -1
		#CK_KeenPoleUpThink(obj);
		return

	# When keen is at ground level, allow dismounting using left/right.
	if ck_inputFrame.xDirection != 0:
		var groundTile: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY2 + 1, 1)
		if TI_ForeTop(groundTile) != 0:
			obj.velX = 0
			obj.velY = 0
			obj.clipped = CLIP_normal
			ck_keenState.jumpTimer = 0
			obj.currentAction = CK_GetActionByName("CK_ACT_keenFall1")
			obj.yDirection = 1
			SD_PlaySound(CK_SOUNDNUM("SOUND_KEENFALL"))
			return

	#TODO: Pole input func
	CK_KeenPoleHandleInput(obj)


func CK_KeenPoleUpThink(obj: CK_object) -> void:
	var topTile: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY1, 1)

	if (TI_ForeMisc(topTile) & 127) != 1:
		ck_nextY = 0
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleSit")
		CK_KeenPoleHandleInput(obj)
		return

	if ck_inputFrame.yDirection == 0:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleSit")
		obj.yDirection = 0
		#CK_KeenPoleSitThink(obj);
	elif ck_inputFrame.yDirection == 1:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleDown1")
		obj.yDirection = 1
		CK_KeenPoleDownThink(obj)

	CK_KeenPoleHandleInput(obj)


func CK_KeenPoleDownThink(obj: CK_object) -> void:
	var tileUnderneath: int = CA_TileAtPos(obj.clipRects.tileXmid, RF_UnitToTile(obj.clipRects.unitY2 - 64), 1)

	if (TI_ForeMisc(tileUnderneath) & 127) != 1:
		# We're no longer on a pole.
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENFALL"))
		obj.currentAction = CK_GetActionByName("CK_ACT_keenFall1")
		ck_keenState.jumpTimer = 0
		obj.velX = ck_KeenPoleOffs[ck_inputFrame.xDirection + 1]
		obj.velY = 0
		obj.clipped = CLIP_normal
		obj.clipRects.tileY2 = u16(obj.clipRects.tileY2 - 1) #WTF?
		return

	if ck_inputFrame.yDirection == 0:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleSit")
		obj.yDirection = 0
	elif ck_inputFrame.yDirection == -1:
		obj.currentAction = CK_GetActionByName("CK_ACT_keenPoleUp1")
		obj.yDirection = -1

	CK_KeenPoleHandleInput(obj)


func CK_KeenPoleDownDrawFunc(obj: CK_object) -> void:
	# Check if keen is trying to climb through the floor.
	# It's quite a strange clipping error if he succeeds.

	var groundTile: int = CA_TileAtPos(obj.clipRects.tileXmid, obj.clipRects.tileY2, 1)

	if TI_ForeTop(groundTile) == 1:
		var yReset: int = -(obj.clipRects.unitY2 & 255) - 1
		obj.posY = u16(obj.posY + yReset)
		obj.clipRects.unitY2 = u16(obj.clipRects.unitY2 + yReset)
		obj.clipRects.tileY2 = u16(obj.clipRects.tileY2 + -1)
		obj.clipped = CLIP_normal
		CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenLookDown1"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


# Defined for a seemingly unused state
func CK_KeenSetClipped(obj: CK_object) -> void:
	obj.clipped = CLIP_normal


# Shooting

func CK_SpawnShot(x: int, y: int, direction: int) -> void:
	if ck_gameState.numShots == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENOUTOFAMMO"))
		return

	if not cheat_infiniteAmmo:
		ck_gameState.numShots = s16(ck_gameState.numShots - 1)

	var shot: CK_object = CK_GetNewObj(true)
	shot.posX = u16(x)
	shot.posY = u16(y)
	shot.zLayer = 0
	shot.type = CT_Stunner # TODO: obj_stunner
	shot.active = OBJ_ALWAYS_ACTIVE

	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSHOOT"))

	match direction:
		0:
			shot.xDirection = 0
			shot.yDirection = -1
		2:
			shot.xDirection = 1
			shot.yDirection = 0
		4:
			shot.xDirection = 0
			shot.yDirection = 1
		6:
			shot.xDirection = -1
			shot.yDirection = 0
		_:
			Quit("SpawnShot: Bad dir!")
			return

	CK_SetAction(shot, CK_GetActionByName("CK_ACT_keenShot1"))

	# This assists when Keen may shoot "through" a blooglet (see last demo in Keen 6 v1.5)
	if ck_currentEpisode_ep == EP_CK6:
		var currentObj: CK_object = ck_keenObj
		while currentObj != null:
			if currentObj.active != 0 and \
					(shot.clipRects.unitX2 > currentObj.clipRects.unitX1) and \
					(shot.clipRects.unitX1 < currentObj.clipRects.unitX2) and \
					(shot.clipRects.unitY1 < currentObj.clipRects.unitY2) and \
					(shot.clipRects.unitY2 > currentObj.clipRects.unitY1) and \
					currentObj.currentAction.collide != &"":
				call(currentObj.currentAction.collide, currentObj, shot)
			currentObj = currentObj.next


func CK_ShotHit(obj: CK_object) -> void:
	#TODO: Implement obj_ classes.
	obj.type = CT_Friendly
	CK_SetAction2(obj, CK_GetActionByName("CK_ACT_keenShotHit1"))
	SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSHOTHIT"))


func CK_ShotThink(shot: CK_object) -> void:
	# Stun things which are offscreen.
	if (shot.clipRects.tileX2 < RF_UnitToTile(rf_scrollXUnit)) or \
			(shot.clipRects.tileY2 < RF_UnitToTile(rf_scrollYUnit)) or \
			(shot.clipRects.tileX1 > RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320)) or \
			(shot.clipRects.tileY1 > RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208)):
		if (shot.clipRects.tileX2 + 10 < RF_UnitToTile(rf_scrollXUnit)) or \
				(shot.clipRects.tileX1 - 10 > RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320)) or \
				(shot.clipRects.tileY2 + 6 < RF_UnitToTile(rf_scrollYUnit)) or \
				(shot.clipRects.tileY1 - 6 > RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208)):
			CK_RemoveObj(shot)
			return
		var currentObj: CK_object = ck_keenObj.next
		while currentObj != null:
			if currentObj.active != 0 or \
					(shot.clipRects.unitX2 <= currentObj.clipRects.unitX1) or \
					(shot.clipRects.unitX1 >= currentObj.clipRects.unitX2) or \
					(shot.clipRects.unitY1 >= currentObj.clipRects.unitY2) or \
					(shot.clipRects.unitY2 <= currentObj.clipRects.unitY1):
				currentObj = currentObj.next
				continue
			if currentObj.currentAction.collide != &"":
				call(currentObj.currentAction.collide, currentObj, shot)
				currentObj.visible = true
				currentObj.active = OBJ_ACTIVE
			if shot.type == CT_Nothing:
				return
			currentObj = currentObj.next


func CK_ShotDrawFunc(obj: CK_object) -> void:
	var t: int = 0

	# shoot down through a pole hole
	if obj.topTI == 1 and obj.clipRects.tileX1 != obj.clipRects.tileX2:
		t = CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1 - 1, 1)
		if TI_ForeTop(t) == 0x11:
			obj.topTI = 0x11
			obj.posX = u16(obj.posX + 0x100 - (obj.posX & 0xFF))
	# move into pole hole before making contact
	elif obj.topTI == 0x11 and obj.clipRects.tileX1 != obj.clipRects.tileX2:
		obj.posX = u16(obj.posX & 0xFF00)

	# shoot through pole hole upwards
	if obj.bottomTI == 1 and obj.clipRects.tileX1 != obj.clipRects.tileX2:
		t = CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY2 + 1, 1)
		if TI_ForeBottom(t) == 0x11:
			obj.bottomTI = 0x11
			obj.posX = u16(obj.posX + 0x100 - (obj.posX & 0xFF))
	# move into pole hole whilst travelling upwards
	elif obj.bottomTI == 0x11 and obj.clipRects.tileX1 != obj.clipRects.tileX2:
		obj.posX = u16(obj.posX & 0xFF00)

	# if hit any other type of object, die
	if obj.topTI != 0x11 and obj.bottomTI != 0x11:
		if obj.topTI != 0 or obj.bottomTI != 0 or obj.rightTI != 0 or obj.leftTI != 0:
			CK_ShotHit(obj)
	else:
		# correct for pole hole passage
		ck_nextY = s16(obj.currentAction.velY * SD_GetSpriteSync() * obj.yDirection)
		obj.posY = u16(obj.posY + ck_nextY)
		obj.clipRects.unitY1 = u16(obj.clipRects.unitY1 + ck_nextY)
		obj.clipRects.unitY2 = u16(obj.clipRects.unitY2 + ck_nextY)
		obj.clipRects.tileY1 = u16(RF_UnitToTile(obj.clipRects.unitY1))
		obj.clipRects.tileY2 = u16(RF_UnitToTile(obj.clipRects.unitY2))
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


func CK_KeenSpawnShot(obj: CK_object) -> void:
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenShoot1"):
		if obj.xDirection == 1:
			CK_SpawnShot(obj.posX + 256, obj.posY + 64, 2)
		else:
			CK_SpawnShot(obj.posX - 128, obj.posY + 64, 6)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenJumpShoot2"):
		if obj.xDirection == 1:
			CK_SpawnShot(obj.posX + 256, obj.posY + 32, 2)
		else:
			CK_SpawnShot(obj.posX, obj.posY + 32, 6)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenJumpShootDown2"):
		CK_SpawnShot(obj.posX + 128, obj.posY + 288, 4)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenJumpShootUp2"):
		CK_SpawnShot(obj.posX + 80, obj.posY - 160, 0)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenShootUp1"):
		CK_SpawnShot(obj.posX + 80, obj.posY - 160, 0)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenPoleShoot1"):
		if obj.xDirection == 1:
			CK_SpawnShot(obj.posX + 256, obj.posY + 64, 2)
		else:
			CK_SpawnShot(obj.posX - 128, obj.posY + 64, 6)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenPoleShootUp1"):
		if obj.xDirection == 1:
			CK_SpawnShot(obj.posX + 96, obj.posY + 64, 0)
		else:
			CK_SpawnShot(obj.posX + 192, obj.posY + 64, 0)
	if obj.currentAction == CK_GetActionByName("CK_ACT_keenPoleShootDown1"):
		if obj.xDirection == 1:
			CK_SpawnShot(obj.posX + 96, obj.posY + 384, 4)
		else:
			CK_SpawnShot(obj.posX + 192, obj.posY + 384, 4)


func CK_KeenSetupFunctions() -> void:
	CK_ACT_AddFunction("CK_KeenSlide", &"CK_KeenSlide")
	CK_ACT_AddFunction("CK_KeenEnterDoor0", &"CK_KeenEnterDoor0")
	CK_ACT_AddFunction("CK_KeenEnterDoor1", &"CK_KeenEnterDoor1")
	CK_ACT_AddFunction("CK_KeenEnterDoor", &"CK_KeenEnterDoor")
	CK_ACT_AddFunction("CK_KeenPlaceGem", &"CK_KeenPlaceGem")
	CK_ACT_AddFunction("CK_KeenRunningThink", &"CK_KeenRunningThink")
	CK_ACT_AddFunction("CK_KeenStandingThink", &"CK_KeenStandingThink")
	CK_ACT_AddFunction("CK_HandleInputOnGround", &"CK_HandleInputOnGround")
	CK_ACT_AddFunction("CK_KeenLookUpThink", &"CK_KeenLookUpThink")
	CK_ACT_AddFunction("CK_KeenLookDownThink", &"CK_KeenLookDownThink")
	CK_ACT_AddFunction("CK_KeenPressSwitchThink", &"CK_KeenPressSwitchThink")
	CK_ACT_AddFunction("CK_KeenDrawFunc", &"CK_KeenDrawFunc")
	CK_ACT_AddFunction("CK_KeenRunDrawFunc", &"CK_KeenRunDrawFunc")
	CK_ACT_AddFunction("CK_KeenReadThink", &"CK_KeenReadThink")
	CK_ACT_AddFunction("CK_KeenJumpThink", &"CK_KeenJumpThink")
	CK_ACT_AddFunction("CK_KeenJumpDrawFunc", &"CK_KeenJumpDrawFunc")
	CK_ACT_AddFunction("CK_KeenPogoThink", &"CK_KeenPogoThink")
	CK_ACT_AddFunction("CK_KeenPogoBounceThink", &"CK_KeenPogoBounceThink")
	CK_ACT_AddFunction("CK_KeenPogoDrawFunc", &"CK_KeenPogoDrawFunc")
	CK_ACT_AddFunction("CK_KeenSpecialDrawFunc", &"CK_KeenSpecialDrawFunc")
	CK_ACT_AddColFunction("CK_KeenSpecialColFunc", &"CK_KeenSpecialColFunc")
	CK_ACT_AddFunction("CK_KeenHangThink", &"CK_KeenHangThink")
	CK_ACT_AddFunction("CK_KeenPullThink1", &"CK_KeenPullThink1")
	CK_ACT_AddFunction("CK_KeenPullThink2", &"CK_KeenPullThink2")
	CK_ACT_AddFunction("CK_KeenPullThink3", &"CK_KeenPullThink3")
	CK_ACT_AddFunction("CK_KeenPullThink4", &"CK_KeenPullThink4")
	CK_ACT_AddFunction("CK_KeenPoleSitThink", &"CK_KeenPoleSitThink")
	CK_ACT_AddFunction("CK_KeenPoleUpThink", &"CK_KeenPoleUpThink")
	CK_ACT_AddFunction("CK_KeenPoleDownThink", &"CK_KeenPoleDownThink")
	CK_ACT_AddFunction("CK_KeenJumpDownThink", &"CK_KeenJumpDownThink")
	CK_ACT_AddFunction("CK_KeenPoleDownDrawFunc", &"CK_KeenPoleDownDrawFunc")
	CK_ACT_AddFunction("CK_KeenSetClipped", &"CK_KeenSetClipped")
	CK_ACT_AddColFunction("CK_KeenColFunc", &"CK_KeenColFunc")
	CK_ACT_AddFunction("CK_KeenDeathThink", &"CK_KeenDeathThink")
	CK_ACT_AddFunction("CK_KeenSpawnShot", &"CK_KeenSpawnShot")
	CK_ACT_AddFunction("CK_ShotThink", &"CK_ShotThink")
	CK_ACT_AddFunction("CK_ShotDrawFunc", &"CK_ShotDrawFunc")


# ===================================================================== ck_verify.c
# The sim-state trace that omnispeak-ref's CK_PlayLoop calls once a frame
# (ck_verify.c, the Keen Launcher project's addition to omnispeak). The trace lines
# go to ck_verifyLines rather than a file; the caller writes them out.

var ck_verifyActive: bool = false
var ck_verifyLines: PackedStringArray = PackedStringArray()   # static FILE *ck_verifyFile
var ck_verifyTotalHash: int = 0x811c9dc5
var ck_verifyFrame: int = 0


static func CKV_FNV1a(h: int, value: int) -> int:
	value &= 0xFFFFFFFF
	for i: int in range(4):
		h ^= (value >> (i * 8)) & 0xFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h


func CK_VERIFY_Startup(_filename: String) -> void:
	ck_verifyLines = PackedStringArray()
	ck_verifyActive = true
	ck_verifyTotalHash = 0x811c9dc5
	ck_verifyFrame = 0


func CK_VERIFY_Frame() -> void:
	if not ck_verifyActive:
		return

	var h: int = 0x811c9dc5
	# CKV(v): h = CKV_FNV1a(h, (uint32_t)(int32_t)(v))

	# Camera, RNG, frame pacing.
	h = CKV_FNV1a(h, rf_scrollXUnit)
	h = CKV_FNV1a(h, rf_scrollYUnit)
	h = CKV_FNV1a(h, US_GetRndI())
	h = CKV_FNV1a(h, SD_GetSpriteSync())

	# Global game state.
	h = CKV_FNV1a(h, ck_gameState.mapPosX)
	h = CKV_FNV1a(h, ck_gameState.mapPosY)
	h = CKV_FNV1a(h, ck_gameState.keenScore)
	h = CKV_FNV1a(h, ck_gameState.nextKeenAt)
	h = CKV_FNV1a(h, ck_gameState.numShots)
	h = CKV_FNV1a(h, ck_gameState.numCentilife)
	h = CKV_FNV1a(h, ck_gameState.currentLevel)
	h = CKV_FNV1a(h, ck_gameState.numLives)
	h = CKV_FNV1a(h, ck_gameState.difficulty)
	h = CKV_FNV1a(h, ck_gameState.levelState)

	# Every live object, in list order.
	var objCount: int = 0
	var o: CK_object = ck_keenObj
	while o != null:
		h = CKV_FNV1a(h, o.type)
		h = CKV_FNV1a(h, o.active)
		h = CKV_FNV1a(h, o.clipped)
		h = CKV_FNV1a(h, o.timeUntillThink)
		h = CKV_FNV1a(h, o.posX)
		h = CKV_FNV1a(h, o.posY)
		h = CKV_FNV1a(h, o.xDirection)
		h = CKV_FNV1a(h, o.yDirection)
		h = CKV_FNV1a(h, o.deltaPosX)
		h = CKV_FNV1a(h, o.deltaPosY)
		h = CKV_FNV1a(h, o.velX)
		h = CKV_FNV1a(h, o.velY)
		h = CKV_FNV1a(h, o.actionTimer)
		h = CKV_FNV1a(h, o.currentAction.compatDosPointer if o.currentAction != null else 0)
		h = CKV_FNV1a(h, o.gfxChunk)
		h = CKV_FNV1a(h, o.clipRects.unitX1)
		h = CKV_FNV1a(h, o.clipRects.unitY1)
		h = CKV_FNV1a(h, o.clipRects.unitX2)
		h = CKV_FNV1a(h, o.clipRects.unitY2)
		h = CKV_FNV1a(h, o.topTI)
		h = CKV_FNV1a(h, o.rightTI)
		h = CKV_FNV1a(h, o.bottomTI)
		h = CKV_FNV1a(h, o.leftTI)
		h = CKV_FNV1a(h, o.user1)
		h = CKV_FNV1a(h, o.user2)
		h = CKV_FNV1a(h, o.user3)
		h = CKV_FNV1a(h, o.user4)
		objCount += 1
		o = o.next
	h = CKV_FNV1a(h, objCount)

	ck_verifyTotalHash = CKV_FNV1a(ck_verifyTotalHash, h)
	ck_verifyLines.append("%06d %08x" % [ck_verifyFrame, h])
	ck_verifyFrame += 1


func CK_VERIFY_Shutdown() -> void:
	if not ck_verifyActive:
		return
	ck_verifyLines.append("TOTAL %08x frames %d" % [ck_verifyTotalHash, ck_verifyFrame])
	ck_verifyActive = false


# ===================================================================== C library helpers

## sscanf(s, "%d", &v): the number s starts with (after blanks), or `unset` when it
## starts with none (C leaves the variable as it was: uninitialised in every caller
## here, so the port's callers pass 0).
static func _sscanf_d(s: String, unset: int) -> int:
	var i: int = 0
	var n: int = s.length()
	while i < n and (s[i] == " " or s[i] == "\t" or s[i] == "\n" or s[i] == "\r" or s[i] == "\f" or s[i] == "\v"):
		i += 1
	var neg: bool = false
	if i < n and (s[i] == "-" or s[i] == "+"):
		neg = s[i] == "-"
		i += 1
	var start: int = i
	var v: int = 0
	while i < n and s.unicode_at(i) >= 0x30 and s.unicode_at(i) <= 0x39:
		v = v * 10 + (s.unicode_at(i) - 0x30)
		i += 1
	if i == start:
		return unset
	return s32(-v if neg else v)
