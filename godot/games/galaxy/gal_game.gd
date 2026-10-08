# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's ck_main.c, ck_game.c, ck_text.c, ck_inter.c and ck_quit.c, by David Gow and the
# Omnispeak authors, GPL v2 or later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalGame
extends GalPlay
## Start-up, the game and level loops, saving, help text and the title, terminator, star wars and high scores (SIM-G-01f).
##
## Files are byte buffers (A11): a saved game is a PackedByteArray the shell
## keeps (us_saveFiles), read and written through an FS_File over it. C
## pointers into a buffer are a BytePtr (buffer and offset) or, where the
## buffer is always the same one, an offset into it.


## The C initialiser of ck_highScores (ck_inter.c; gal_us.gd declares the array).
func _init() -> void:
	super()
	var names: PackedStringArray = ["Id Software - '91", "", "Jason Blochowiak", "Adrian Carmack",
		"John Carmack", "Tom Hall", "John Romero", ""]
	for i: int in range(8):
		var hs: CK_HighScore = ck_highScores[i]
		hs.name = names[i]
		hs.score = 10000
		hs.arg4 = 0


## A C pointer into a byte buffer: the buffer (shared, as a C pointer is) and an offset.
class BytePtr:
	var buf: PackedByteArray
	var off: int

	func _init(b: PackedByteArray, o: int) -> void:
		buf = b
		off = o


## A little-endian word of `b` at `o`; past the end of the buffer, 0xFFFF
## (the C reads on past the chunk; the port stops its scans there).
static func _game_rd16(b: PackedByteArray, o: int) -> int:
	if o < 0 or o + 1 >= b.size():
		return 0xFFFF
	return b[o] | (b[o + 1] << 8)


static func _game_wr16(b: PackedByteArray, o: int, v: int) -> void:
	_put(b, o, v & 0xFF)
	_put(b, o + 1, (v >> 8) & 0xFF)


## The C string in `b` from `o` (up to its NUL or the buffer's end), one
## character per byte.
static func _game_cstring(b: PackedByteArray, o: int) -> String:
	var s: String = ""
	var i: int = o
	while i < b.size() and b[i] != 0:
		s += char(b[i])
		i += 1
	return s


## CK_Cross_toupper over a C char.
static func CK_Cross_toupper(c: int) -> int:
	return c - 32 if c >= 97 and c <= 122 else c


# ===================================================================== ck_main.c

# (ck_currentEpisode and ck_storeDemo: gal_ck.gd)


## Measure the containing box size of a string that spans multiple lines.
## Returns [w, h] (the C's out-parameters; the last two arguments are unused).
## Quirk kept: the line buffer is never cleared, so a line shorter than the
## one before it is measured with the earlier line's tail (and the newline).
func CK_MeasureMultiline(string: String, _w: int = 0, _h: int = 0) -> PackedInt32Array:
	var x: int = 0
	var y: int = 0
	var w: int = 0
	var h: int = 0
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(80)
	var p: int = 0
	var n: int = string.length()
	for k: int in range(n):
		var c: int = string.unicode_at(k) & 0xFF
		if p >= buf.size():
			buf.resize(p + 1)    # C writes past its 80-byte buffer
		buf[p] = c
		p += 1
		if c == 10 or k + 1 == n:
			var xy: PackedInt32Array = VH_MeasurePropString(_game_cstring(buf, 0), US_GetPrintFont())
			x = xy[0]
			y = xy[1]
			h = u16(h + y)
			if w < x:
				w = x
			p = 0
			# Shouldn't buf be cleared so that a newline is not read over by
			# VH_MeasurePropString? (omnispeak's note; the C doesn't)
	return PackedInt32Array([w, h])


## Shutdown all of the 'ID Engine' components.
func CK_ShutdownID() -> void:
	# CK_VERIFY_Shutdown(): ck_verify.c's checksum log, a file (not ported)
	VL_DestroySurface(ck_backupSurface)
	VL_DestroySurface(ck_statusSurface)
	US_Shutdown()
	SD_Shutdown()
	# IN
	RF_Shutdown()
	# VH
	VL_Shutdown()
	CA_Shutdown()
	CFG_Shutdown()
	MM_Shutdown()


## Start the game!
func CK_InitGame() -> void:
	# Set the default high scores once we've loaded the episode.
	CK_SetDefaultHighScores()

	# Load the core datafiles
	CA_Startup()
	CA_InitLumps(CK_INT("NUMLUMPS", 0))
	# Setup saved games handling
	US_Setup()

	# Set a few Menu Callbacks
	US_SetMenuFunctionPointers(&"CK_LoadGame", &"CK_SaveGame", &"CK_ExitMenu")
	# Set ID engine Callbacks
	ca_beginCacheBox = &"CK_BeginCacheBox"
	ca_updateCacheBox = &"CK_UpdateCacheBox"
	ca_finishCacheBox = &"CK_FinishCacheBox"

	# Mark some chunks we'll need.
	CA_ClearMarks()
	CA_MarkGrChunk(CK_CHUNKNUM("FON_MAINFONT"))
	CA_MarkGrChunk(int(ca_gfxInfoE.offTiles8))
	CA_MarkGrChunk(int(ca_gfxInfoE.offTiles8m))
	CA_MarkGrChunk(CK_CHUNKNUM("MPIC_STATUSLEFT"))
	CA_MarkGrChunk(CK_CHUNKNUM("MPIC_STATUSRIGHT"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_TITLESCREEN"))    # Moved from CA_Startup
	CA_CacheMarks("")    # CA_CacheMarks(0): no message

	# Lock them chunks in memory.
	CA_LockGrChunk(CK_CHUNKNUM("FON_MAINFONT"))
	CA_LockGrChunk(int(ca_gfxInfoE.offTiles8))
	CA_LockGrChunk(int(ca_gfxInfoE.offTiles8m))
	CA_LockGrChunk(CK_CHUNKNUM("MPIC_STATUSLEFT"))
	CA_LockGrChunk(CK_CHUNKNUM("MPIC_STATUSRIGHT"))

	# Setup the screen
	VL_Startup()
	# TODO: Palette initialization should be done in the terminator code
	VL_SetDefaultPalette()

	# Setup input
	IN_Startup()

	# Setup audio
	SD_Startup()

	US_Startup()

	RF_Startup()

	VL_ColorBorder(3)
	VL_ClearScreen(0)
	VL_Present()

	# Create a surface for the dropdown menu
	ck_statusSurface = VL_CreateSurface(RF_BUFFER_WIDTH_PIXELS, STATUS_H + 16 + 16)
	ck_backupSurface = VL_CreateSurface(RF_BUFFER_WIDTH_PIXELS, RF_BUFFER_HEIGHT_PIXELS)


## The Demo Loop: runs the title and demos, and calls into the main menu and
## game loops when they are required.
func CK_DemoLoop() -> void:
	# Commander Keen could be 'launched' from the map editor TED to test a map
	# (/TEDLEVEL xx).
	if us_tedLevel:
		var difficultyParms: PackedStringArray = ["easy", "normal", "hard", ""]
		CK_NewGame()
		CA_LoadAllSounds()
		ck_gameState.currentLevel = s16(us_tedLevelNumber)
		ck_startingDifficulty = D_Normal

		# C loops i = 1 .. argc-1; us_argv holds the arguments after the program name
		for i: int in range(us_argv.size()):
			var difficulty: int = US_CheckParm(us_argv[i], difficultyParms)
			if difficulty == -1:
				continue
			ck_startingDifficulty = D_Easy + difficulty
			break

		CK_GameLoop()
		Quit("")    # Quit(0): run_ted
		return

	# Given we're not coming from TED, run through the demos.
	var demoNumber: int = 0
	ck_gameState.levelState = LS_Playing

	while true:
		if quitting:
			break
		var dn: int = demoNumber
		demoNumber += 1
		match dn:
			0:    # Terminator scroller and Title Screen
				# If no pixel panning capability, the terminator screen isn't shown
				if vl_noPan:
					CK_ShowTitleScreen()
				else:
					CK_DrawTerminator()
			1:
				CK_PlayDemo(0)
			2:
				# Star Wars story text
				CK_DrawStarWars()
			3:
				CK_PlayDemo(1)
			4:
				CK_DoHighScores()    # High Scores
			5:
				CK_PlayDemo(2)
			6:
				CK_PlayDemo(3)
				demoNumber = 0

		# Game Loop
		while true:
			if quitting:
				break
			if ck_gameState.levelState == LS_ResetGame or ck_gameState.levelState == LS_LoadedGame:
				CK_GameLoop()
				CK_DoHighScores()
				if ck_gameState.levelState == LS_ResetGame or ck_gameState.levelState == LS_LoadedGame:
					continue

				CK_ShowTitleScreen()

				if ck_gameState.levelState == LS_ResetGame or ck_gameState.levelState == LS_LoadedGame:
					continue
			else:
				break

	Quit("Demo loop exited!?")


## ck_episodes[] (the NULL that ends the C array included).
var ck_episodes: Array = [ck4_episode, ck5_episode, ck6_episode, null]
var ck_episodeFile: String = ""    # NULL: ""


## main(), after the command line: argv holds the arguments after the program
## name (C's argv[1..]). The file system (FS_Startup), the memory manager
## (MM_Startup), the config file (CFG_Startup) and the SDL window parameters are
## the shell's; the data are GalData's (`data`). Returns main's exit code.
func CK_Main(argv: PackedStringArray) -> int:
	var argc: int = argv.size()
	# Send the cmd-line args to the User Manager.
	us_argv = argv

	# Check if we're running the store demo.
	if US_ParmPresent("DEMO"):
		ck_storeDemo = true

	# FS_Startup(), MM_Startup(), CFG_Startup(): the shell's (no file system here)
	# ck_cross_logLevel = CFG_GetConfigEnum("logLevel", ...): logging only

	# Compile the actions
	CK_ACT_SetupFunctions()
	CK_KeenSetupFunctions()
	CK_OBJ_SetupFunctions()
	CK_Map_SetupFunctions()
	CK_Misc_SetupFunctions()

	# Set up all of the episode functions.
	CK4_SetupFunctions()
	CK5_SetupFunctions()
	CK6_SetupFunctions()

	CK_VAR_Startup()

	# Default to the first episode with all files present.
	CK_SetCurrentEpisode(ck_episodes[0])
	var i: int = 0
	while ck_episodes[i] != null:
		if call((ck_episodes[i] as CK_EpisodeDef).isPresent):
			CK_SetCurrentEpisode(ck_episodes[i])
			ck_episodeFile = ck_currentEpisode.episodeFile
			break
		i += 1

	# If we don't have an episode with all files present, look for _just_
	# an EPISODE.CKx file.
	if ck_episodeFile == "":
		i = 0
		while ck_episodes[i] != null:
			if FS_IsOmniFilePresent((ck_episodes[i] as CK_EpisodeDef).episodeFile):
				CK_SetCurrentEpisode(ck_episodes[i])
				ck_episodeFile = ck_currentEpisode.episodeFile
				break
			i += 1

	var isFullScreen: bool = CFG_GetConfigBool("fullscreen", false)
	var isAspectCorrected: bool = CFG_GetConfigBool("aspect", true)
	var hasBorder: bool = CFG_GetConfigBool("border", true)
	var isIntegerScaled: bool = CFG_GetConfigBool("integer", false)
	var overrideCopyProtection: bool = CFG_GetConfigBool("ck6_noCreatureQuestion", false)
	var swapInterval: int = CFG_GetConfigInt("swapInterval", 1)

	for a: int in range(argc):
		if argv[a].to_upper() == "/EPISODE":
			# A bit of stuff from the usual demo loop
			# (C tests argc >= i + 1, always true: argv[argc] is NULL; "" here)
			if argc >= a + 1:
				var e: String = argv[a + 1] if a + 1 < argc else ""
				if FS_IsOmniFilePresent(e):
					ck_episodeFile = e
				elif e == "4":
					ck_episodeFile = "EPISODE.CK4"
				elif e == "5":
					ck_episodeFile = "EPISODE.CK5"
				elif e == "6":
					ck_episodeFile = "EPISODE.CK6"
				# For compatibility, we accept version-specific arguments for 6.
				elif e == "6v14":
					ck_episodeFile = "EPISODE.CK6"
				elif e == "6v15":
					ck_episodeFile = "EPISODE.CK6"
				else:
					QuitF("Unsupported episode \"%s\"!", [e])
					return -1
		elif argv[a].to_upper() == "/FULLSCREEN":
			isFullScreen = true
		elif argv[a].to_upper() == "/FILLED":
			isAspectCorrected = false
		elif argv[a].to_upper() == "/NOBORDER":
			hasBorder = false
		elif argv[a].to_upper() == "/INTEGER":
			isIntegerScaled = true
		elif argv[a].to_upper() == "/VSYNC":
			swapInterval = 1
		elif argv[a].to_upper() == "/NOVSYNC":
			swapInterval = 0
		elif argv[a].to_upper() == "/NOJOYS":
			in_disableJoysticks = true
		elif argv[a].to_upper() == "/NOCOPY":
			overrideCopyProtection = true

	# Load the EPISODE.CKx file.
	if ck_episodeFile == "":
		Quit("No episode found! Make sure the game files are present, and run with /EPISODE <EPISODE.CKx>")
		return -1
	CK_VAR_LoadVars(ck_episodeFile)

	# Determine the base episode number
	var episodeNumber: int = CK_INT("ck_episodeNumber", -1)
	if episodeNumber == -1:
		push_warning("Episode doesn't declare a base episode number.")
		var fnamelen: int = ck_episodeFile.length()
		if fnamelen >= 4 and ck_episodeFile[fnamelen - 4] == "." and ck_episodeFile[fnamelen - 3].to_lower() == "c" \
				and ck_episodeFile[fnamelen - 2].to_lower() == "k":
			match ck_episodeFile[fnamelen - 1]:
				"4":
					episodeNumber = 4
					push_warning("Assuming episode 4 from filename %s" % ck_episodeFile)
				"5":
					episodeNumber = 5
					push_warning("Assuming episode 5 from filename %s" % ck_episodeFile)
				"6":
					episodeNumber = 6
					push_warning("Assuming episode 6 from filename %s" % ck_episodeFile)
				_:
					QuitF("Episode %s doesn't provide an episode number, and one couldn't be guessed from the filename.", [ck_episodeFile])
					return -1
	match episodeNumber:
		4:
			CK_SetCurrentEpisode(ck4_episode)
		5:
			CK_SetCurrentEpisode(ck5_episode)
		6:
			CK_SetCurrentEpisode(ck6_episode)
		_:
			QuitF("No base episode specified in %s\n", [ck_episodeFile])
			return -1

	# vl_swapInterval = swapInterval; VL_SetParams(...): the host window's (SDL), the shell's
	var _window: Array = [isFullScreen, isAspectCorrected, hasBorder, isIntegerScaled, swapInterval]

	if overrideCopyProtection:
		ck6_creatureQuestionDone = true

	CK_InitGame()

	# /CHECKSUM <file>: CK_VERIFY_Startup (ck_verify.c) writes a checksum file; not ported

	var a2: int = 0
	while a2 < argc:
		if argv[a2].to_upper() == "/DEMOFILE":
			# A bit of stuff from the usual demo loop
			ck_gameState.levelState = LS_Playing

			CK_PlayDemoFile(argv[a2 + 1] if a2 + 1 < argc else "")
			Quit("")
			return 0
		elif argv[a2].to_upper() == "/PLAYDEMO":
			# A bit of stuff from the usual demo loop
			ck_gameState.levelState = LS_Playing

			CK_PlayDemo((argv[a2 + 1] if a2 + 1 < argc else "").to_int())
			Quit("")
			return 0
		elif argv[a2].to_upper() == "/ASLEV":
			us_tedLevel = true
			a2 += 1
			us_aslevFilename = argv[a2] if a2 < argc else ""
		a2 += 1

	if us_noWait or us_tedLevel or CFG_GetConfigBool("debugActive", false):
		ck_debugActive = true

	# Draw the ANSI "Press Key When Ready Screen" here
	CK_DemoLoop()
	CK_ShutdownID()
	return 0


# ===================================================================== ck_game.c

var ck_lastLevelFinished: int = 0    # static


## Purge stuff for endgame. Purging is a memory matter the port does not have
## (MM_SetPurge on each cached sprite, tile and font chunk): chunks stay cached.
func CK_EndingPurge() -> void:
	for i: int in range(int(ca_gfxInfoE.offSprites), int(ca_gfxInfoE.offTiles8)):
		if ca_graphChunks[i] != null:
			pass    # MM_SetPurge(ca_graphChunks + i, 1)
	for i: int in range(int(ca_gfxInfoE.offTiles16), int(ca_gfxInfoE.offBinaries)):
		if ca_graphChunks[i] != null:
			pass    # MM_SetPurge(ca_graphChunks + i, 1)


## NewGame: Setup the default starting stats.
func CK_NewGame() -> void:
	# NOTE: the level state wasn't originally part of the game state, so preserve it.
	var ls: int = ck_gameState.levelState
	ck_gameState.clear()
	ck_gameState.nextKeenAt = 20000
	ck_gameState.numLives = 3
	ck_gameState.numShots = 5
	ck_gameState.currentLevel = 0
	ck_gameState.levelState = ls


func CK_GameOver() -> void:
	VL_FixRefreshBuffer()
	US_CenterWindow(16, 3)
	US_PrintCentered(CK_STRING("ck_str_gameOver"))
	VH_UpdateScreen()
	IN_ClearKeysDown()
	IN_UserInput(4 * 70, false)


## OMNISPEAK - New cross-platform methods for reading/writing objects from/to saved games.
func CK_SaveObject(fp: FS_File, o: CK_object) -> bool:
	var dummy: int = 0
	# Convert a few enums
	var activeInt: int = s16(o.active)
	var clippedInt: int = s16(o.clipped)
	# BACKWARD COMPATIBILITY
	var statedosoffset: int = u16(o.currentAction.compatDosPointer) if o.currentAction != null else 0
	# Just tells if "o->next" is zero or not
	var isnext: int = 1 if o.next != null else 0
	# Now writing
	return (FS_WriteInt16LE([o.type], 1, fp) == 1
		and FS_WriteInt16LE([activeInt], 1, fp) == 1
		and FS_WriteBoolTo16LE([o.visible], 1, fp) == 1
		and FS_WriteInt16LE([clippedInt], 1, fp) == 1
		and FS_WriteInt16LE([o.timeUntillThink], 1, fp) == 1
		and FS_WriteInt16LE([o.posX], 1, fp) == 1
		and FS_WriteInt16LE([o.posY], 1, fp) == 1
		and FS_WriteInt16LE([o.xDirection], 1, fp) == 1
		and FS_WriteInt16LE([o.yDirection], 1, fp) == 1
		and FS_WriteInt16LE([o.deltaPosX], 1, fp) == 1
		and FS_WriteInt16LE([o.deltaPosY], 1, fp) == 1
		and FS_WriteInt16LE([o.velX], 1, fp) == 1
		and FS_WriteInt16LE([o.velY], 1, fp) == 1
		and FS_WriteInt16LE([o.actionTimer], 1, fp) == 1
		and FS_WriteInt16LE([statedosoffset], 1, fp) == 1    # BACKWARD COMPATIBILITY
		and FS_WriteInt16LE([o.gfxChunk], 1, fp) == 1
		and FS_WriteInt16LE([o.zLayer], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.unitX1], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.unitY1], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.unitX2], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.unitY2], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.unitXmid], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.tileX1], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.tileY1], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.tileX2], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.tileY2], 1, fp) == 1
		and FS_WriteInt16LE([o.clipRects.tileXmid], 1, fp) == 1
		and FS_WriteInt16LE([o.topTI], 1, fp) == 1
		and FS_WriteInt16LE([o.rightTI], 1, fp) == 1
		and FS_WriteInt16LE([o.bottomTI], 1, fp) == 1
		and FS_WriteInt16LE([o.leftTI], 1, fp) == 1
		and FS_WriteInt16LE([o.user1], 1, fp) == 1
		and FS_WriteInt16LE([o.user2], 1, fp) == 1
		and FS_WriteInt16LE([o.user3], 1, fp) == 1
		and FS_WriteInt16LE([o.user4], 1, fp) == 1
		# No need to write sde, prev pointers as-is, these are ignored on
		# loading. So write dummy value. All we need to know about next on
		# loading is if it's zero or not.
		and FS_WriteInt16LE([dummy], 1, fp) == 1    # sde
		and FS_WriteInt16LE([isnext], 1, fp) == 1    # next
		and FS_WriteInt16LE([dummy], 1, fp) == 1)    # prev


## static in ck_game.c. Reads the 38 words in order; a short read stops there,
## leaving the fields read so far written (as the C's chain of reads does).
func CK_LoadObject(fp: FS_File, o: CK_object) -> bool:
	var w: PackedInt64Array = PackedInt64Array()
	for k: int in range(38):
		var r: PackedInt64Array
		if k == 2:
			var b: Array = FS_ReadBoolFrom16LE(1, fp)
			r = PackedInt64Array([1 if b[0] else 0]) if b.size() == 1 else PackedInt64Array()
		else:
			r = FS_ReadInt16LE(1, fp)
		if r.size() != 1:
			break
		w.append(r[0])
	var n: int = w.size()
	# the fields in file order (activeInt, clippedInt, statedosoffset, dummy and isnext are locals)
	if n > 0: o.type = s16(w[0])
	var activeInt: int = s16(w[1]) if n > 1 else 0
	if n > 2: o.visible = w[2] != 0
	var clippedInt: int = s16(w[3]) if n > 3 else 0
	if n > 4: o.timeUntillThink = u16(w[4])
	if n > 5: o.posX = u16(w[5])
	if n > 6: o.posY = u16(w[6])
	if n > 7: o.xDirection = s16(w[7])
	if n > 8: o.yDirection = s16(w[8])
	if n > 9: o.deltaPosX = s16(w[9])
	if n > 10: o.deltaPosY = s16(w[10])
	if n > 11: o.velX = s16(w[11])
	if n > 12: o.velY = s16(w[12])
	if n > 13: o.actionTimer = s16(w[13])
	var statedosoffset: int = u16(w[14]) if n > 14 else 0    # BACKWARD COMPATIBILITY
	if n > 15: o.gfxChunk = u16(w[15])
	if n > 16: o.zLayer = s16(w[16])
	if n > 17: o.clipRects.unitX1 = u16(w[17])
	if n > 18: o.clipRects.unitY1 = u16(w[18])
	if n > 19: o.clipRects.unitX2 = u16(w[19])
	if n > 20: o.clipRects.unitY2 = u16(w[20])
	if n > 21: o.clipRects.unitXmid = u16(w[21])
	if n > 22: o.clipRects.tileX1 = u16(w[22])
	if n > 23: o.clipRects.tileY1 = u16(w[23])
	if n > 24: o.clipRects.tileX2 = u16(w[24])
	if n > 25: o.clipRects.tileY2 = u16(w[25])
	if n > 26: o.clipRects.tileXmid = u16(w[26])
	if n > 27: o.topTI = s16(w[27])
	if n > 28: o.rightTI = s16(w[28])
	if n > 29: o.bottomTI = s16(w[29])
	if n > 30: o.leftTI = s16(w[30])
	if n > 31: o.user1 = s16(w[31])
	if n > 32: o.user2 = s16(w[32])
	if n > 33: o.user3 = s16(w[33])
	if n > 34: o.user4 = s16(w[34])
	# 35: dummy (sde), 36: isnext, 37: dummy (prev)
	if n != 38:
		return false
	var isnext: int = s16(w[36])

	o.active = activeInt
	o.clipped = clippedInt
	o.currentAction = CK_LookupActionFrom16BitOffset(statedosoffset)
	# HACK: All we need to know is if next was originally NULL or not
	o.next = o if isnext != 0 else null
	return true


## Similar new methods for writing/reading game state.
func CK_SaveGameState(fp: FS_File, state: CK_GameState) -> bool:
	var difficultyInt: int = s16(state.difficulty)    # Convert enum
	# TODO - platform should be a part of the game state
	var platformObjOffset: int = u16(CK_ConvertObjPointerTo16BitOffset(ck_keenState.platform))

	return (FS_WriteInt16LE([state.mapPosX], 1, fp) == 1
		and FS_WriteInt16LE([state.mapPosY], 1, fp) == 1
		and FS_WriteInt16LE(Array(state.levelsDone), 25, fp) == 25
		and FS_WriteInt32LE([state.keenScore], 1, fp) == 1
		and FS_WriteInt32LE([state.nextKeenAt], 1, fp) == 1
		and FS_WriteInt16LE([state.numShots], 1, fp) == 1
		and FS_WriteInt16LE([state.numCentilife], 1, fp) == 1
		and ((ck_currentEpisode_ep == EP_CK4
				and FS_WriteInt16LE([state.ck4_wetsuit], 1, fp) == 1
				and FS_WriteInt16LE([state.ck4_membersRescued], 1, fp) == 1)
			or (ck_currentEpisode_ep == EP_CK5
				and FS_WriteInt16LE([state.ck5_securityCard], 1, fp) == 1
				and FS_WriteInt16LE([state.ck5_word_4729C], 1, fp) == 1
				and FS_WriteInt16LE([state.ck5_fusesRemaining], 1, fp) == 1)
			or (ck_currentEpisode_ep == EP_CK6
				and FS_WriteInt16LE([state.ck6_sandwich], 1, fp) == 1
				and FS_WriteInt16LE([state.ck6_rope], 1, fp) == 1
				and FS_WriteInt16LE([state.ck6_passcard], 1, fp) == 1
				and FS_WriteInt16LE([state.ck6_inRocket], 1, fp) == 1))
		and FS_WriteInt16LE(Array(state.keyGems), 4, fp) == 4
		and FS_WriteInt16LE([state.currentLevel], 1, fp) == 1
		and FS_WriteInt16LE([state.numLives], 1, fp) == 1
		and FS_WriteInt16LE([difficultyInt], 1, fp) == 1
		and FS_WriteInt16LE([platformObjOffset], 1, fp) == 1)    # BACKWARDS COMPATIBILITY


## One word read for CK_LoadGameState: the unsigned value, or -1 when the read is short.
func _CK_ReadWord(fp: FS_File) -> int:
	var r: PackedInt64Array = FS_ReadInt16LE(1, fp)
	return r[0] if r.size() == 1 else -1


## static in ck_game.c. Stops at the first short read, as the C's chain of || does.
func CK_LoadGameState(fp: FS_File, state: CK_GameState) -> bool:
	var v: int = _CK_ReadWord(fp)
	if v < 0:
		return false
	state.mapPosX = u16(v)
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	state.mapPosY = u16(v)
	var r: PackedInt64Array = FS_ReadInt16LE(25, fp)
	for k: int in range(r.size()):
		state.levelsDone[k] = u16(r[k])
	if r.size() != 25:
		return false
	r = FS_ReadInt32LE(1, fp)
	if r.size() != 1:
		return false
	state.keenScore = s32(r[0])
	r = FS_ReadInt32LE(1, fp)
	if r.size() != 1:
		return false
	state.nextKeenAt = s32(r[0])
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	state.numShots = s16(v)
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	state.numCentilife = s16(v)
	if ck_currentEpisode_ep == EP_CK4:
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck4_wetsuit = s16(v)
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck4_membersRescued = s16(v)
	if ck_currentEpisode_ep == EP_CK5:
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck5_securityCard = s16(v)
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck5_word_4729C = s16(v)
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck5_fusesRemaining = s16(v)
	if ck_currentEpisode_ep == EP_CK6:
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck6_sandwich = s16(v)
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck6_rope = s16(v)
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck6_passcard = s16(v)
		v = _CK_ReadWord(fp)
		if v < 0:
			return false
		state.ck6_inRocket = s16(v)
	r = FS_ReadInt16LE(4, fp)
	for k: int in range(r.size()):
		state.keyGems[k] = s16(r[k])
	if r.size() != 4:
		return false
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	state.currentLevel = s16(v)
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	state.numLives = s16(v)
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	var difficultyInt: int = s16(v)
	v = _CK_ReadWord(fp)
	if v < 0:
		return false
	var platformObjOffset: int = u16(v)    # BACKWARDS COMPATIBILITY

	state.difficulty = difficultyInt
	# TODO - platform should be a part of the game state
	ck_keenState.platform = CK_ConvertObj16BitOffsetToPointer(platformObjOffset)
	return true


## This saves the game: the stats, the current level's three planes
## (RLEW-compressed), then every object from Keen on.
func CK_SaveGame(fp: FS_File) -> bool:
	var cmplen: int = 0
	var bufsize: int = 0
	var obj: CK_object = null

	# Write out Keen stats
	ck_keenState.platform = null
	if not CK_SaveGameState(fp, ck_gameState):
		return false

	bufsize = u16(CA_GetMapWidth() * CA_GetMapHeight() * 2)

	# Compress and save the current level
	for i: int in range(3):
		var buf: PackedInt64Array = PackedInt64Array([0])    # the length word, then buf + 2
		cmplen = u16(CAL_RLEWCompress(CA_mapPlanes[i], CA_TilePtrAtPos(0, 0, i), bufsize, buf, 0xABCD))

		# Write the size of the compressed level
		buf[0] = cmplen
		cmplen /= 2
		if FS_WriteInt16LE(Array(buf), cmplen + 1, fp) != cmplen + 1:
			return false

	# Save all the objects
	obj = ck_keenObj
	while obj != null:
		if not CK_SaveObject(fp, obj):
			return false
		obj = obj.next

	return true


func CK_LoadGame(fp: FS_File, fromMenu: bool) -> bool:
	var cmplen: int = 0
	var bufsize: int = 0
	var prevFuses: int = 0    # uninitialised in C; only read in Keen 5
	var objprev: CK_object = null
	var objnext: CK_object = null
	var moreObj: CK_object = null

	if not CK_LoadGameState(fp, ck_gameState):
		return false

	if ck_currentEpisode_ep == EP_CK5:
		prevFuses = s16(ck_gameState.ck5_fusesRemaining)

	if fromMenu:
		# loading from menu -> load the level into the cache stack entry *below* the menu
		ca_levelbit = u8(ca_levelbit >> 1)
		ca_levelnum = u8(ca_levelnum - 1)
		CK_LoadLevel(false, false)
		ca_levelbit = u8(ca_levelbit << 1)
		ca_levelnum = u8(ca_levelnum + 1)
	else:
		# quickloading -> replace the currently cached level
		CK_LoadLevel(true, true)

	bufsize = u16(CA_GetMapWidth() * CA_GetMapHeight() * 2)
	var buf: PackedInt64Array = PackedInt64Array()    # MM_GetPtr(&buf, bufsize): words, reused for each plane
	buf.resize(bufsize / 2)

	# Decompress and load the level
	for i: int in range(3):
		var r: PackedInt64Array = FS_ReadInt16LE(1, fp)
		if r.size() != 1:
			return false
		cmplen = u16(r[0])
		cmplen /= 2
		r = FS_ReadInt16LE(cmplen, fp)
		for k: int in range(r.size()):
			if k >= buf.size():
				buf.append(0)    # the C writes past its buffer
			buf[k] = r[k]
		if r.size() != cmplen:
			return false

		CAL_RLEWExpand(buf, CA_mapPlanes[i], CA_TilePtrAtPos(0, 0, i), bufsize, 0xABCD)

	CK_SetupObjArray()
	var newObj: CK_object = ck_keenObj

	# Read the first object (keen) from the list
	objprev = newObj.prev
	objnext = newObj.next
	if not CK_LoadObject(fp, newObj):
		return false
	newObj.prev = objprev
	newObj.next = objnext

	newObj.visible = true
	newObj.sde = null
	newObj = ck_scoreBoxObj

	while true:
		if quitting:
			return false
		# Read the object from the file and put it in the list
		objprev = newObj.prev
		objnext = newObj.next
		if not CK_LoadObject(fp, newObj):
			return false
		moreObj = newObj.next
		newObj.prev = objprev
		newObj.next = objnext

		newObj.visible = true
		newObj.sde = null

		# Omit stale sprite draw pointers
		if newObj.type == CT_CLASS("StunnedCreature"):
			newObj.user3 = 0
		elif ck_currentEpisode_ep == EP_CK4:
			if newObj.type == CT4_Platform:
				newObj.user3 = 0
				newObj.user2 = 0
		elif ck_currentEpisode_ep == EP_CK5:
			if newObj.type == CT5_Mine:
				newObj.user4 = 0
			elif newObj.type == CT5_Sphereful:
				newObj.user4 = 0
				newObj.user3 = 0
				newObj.user2 = 0
				newObj.user1 = 0
		elif ck_currentEpisode_ep == EP_CK6:
			if newObj.type == CT6_Platform:
				newObj.user3 = 0

		# If this is the last object in the saved list, exit the loop
		if moreObj == null:
			break

		# Otherwise we add a new object
		newObj = CK_GetNewObj(false)

	ck_scoreBoxObj.user1 = -1
	ck_scoreBoxObj.user2 = -1
	ck_scoreBoxObj.user3 = -1
	ck_scoreBoxObj.user4 = -1

	if ck_currentEpisode_ep == EP_CK5:
		ck_gameState.ck5_fusesRemaining = prevFuses

	return true


# TODO: KillKeen


func CK_ExitMenu() -> void:
	CK_NewGame()
	ca_levelnum = u8(ca_levelnum - 1)
	ca_levelbit = u8(ca_levelbit >> 1)
	CA_ClearMarks()
	ca_levelbit = u8(ca_levelbit << 1)
	ca_levelnum = u8(ca_levelnum + 1)


func CK_MapLevelMarkAsDone() -> void:
	var w: int = 0
	var level: int = 0
	var flags: int = 0
	var i: int = 0
	var pw: int = CA_TilePtrAtPos(0, 0, 2)    # info layer

	# Look through the map for level-related tiles
	for y: int in range(CA_GetMapHeight()):
		for x: int in range(CA_GetMapWidth()):
			w = CA_mapPlanes[2][pw]
			level = w & 0xFF
			# (levelsDone has 25 entries; past them the C reads on into keenScore: 0 here)
			if level >= CK_INT("ck_minDoneLevel", 1) and level <= CK_INT("ck_maxDoneLevel", 17) \
					and (ck_gameState.levelsDone[level] if level < 25 else 0) != 0:
				# Is this a level tile
				flags = w >> 8
				# Set the info tile at this position to 0
				CA_mapPlanes[2][pw] = 0
				if flags == 0xD0:
					# If this is a 'blocking' part of the level, set the
					# foreground tile at this position to 0 also (remove the fences)
					CA_SetTileAtPos(x, y, 1, 0)
				elif flags == 0xF0:
					# If this is the flag holder for the level
					if ck_currentEpisode_ep != EP_CK5 and ck_lastLevelFinished == level:
						CK_FlippingFlagSpawn(x, y)
					else:
						CK_MapFlagSpawn(x, y)
			pw += 1
			i += 1


var ck_fadeDrawCounter: int = 0    # static int16_t


func CK_UpdateFadeDrawing() -> void:
	ck_fadeDrawCounter = s16(ck_fadeDrawCounter + 1)
	if ck_fadeDrawCounter == 2:
		VL_FadeFromBlack()
		RF_SetDrawFunc(&"")
		SD_SetTimeCount(SD_GetLastTimeCount())


func CK_BeginFadeDrawing() -> void:
	VL_FadeToBlack()
	ck_fadeDrawCounter = 0
	RF_SetDrawFunc(&"CK_UpdateFadeDrawing")


func CK_LoadLevel(doCache: bool, silent: bool) -> void:
	if IN_DemoGetMode() != IN_Demo_Off:
		# If we're recording or playing back a demo, the game needs to be
		# deterministic. Seed the RNG at 0 and set difficulty to normal.
		US_InitRndT(false)
		ck_gameState.difficulty = D_Normal
	else:
		US_InitRndT(true)

	if us_aslevFilename != "":
		CA_CacheMapFromASLEV(ck_gameState.currentLevel, us_aslevFilename)
	else:
		CA_CacheMap(ck_gameState.currentLevel)
	RF_NewMap()
	CA_ClearMarks()

	CK_SetupObjArray()    # This is done inside ScanInfoLayer in CK4
	call(ck_currentEpisode.scanInfoLayer)

	if ca_mapOn == 0:
		CK_MapLevelMarkAsDone()

	RF_MarkTileGraphics()
	CA_LoadAllSounds()

	# Cache Marked graphics and draw loading box
	if doCache:
		if ck_inHighScores or silent:
			CA_CacheMarks("")    # NULL
		elif IN_DemoGetMode() != IN_Demo_Off:
			CA_CacheMarks(CK_STRING("ck_str_demo"))
		elif ck_currentEpisode_ep == EP_CK5 and ca_mapOn == 0 and ck_keenObj.clipRects.tileY1 > 100:
			# Stepping on to korath
			CA_CacheMarks(CK_STRING("ck5_str_korath3"))
		else:
			CA_CacheMarks(CK_STRINGELEMENT("ck_str_levelEntryText", ca_mapOn))

	if doCache and not silent:
		CK_BeginFadeDrawing()


# Cache Box Routines: callbacks of the caching manager

var ck_cacheCountdownNum: int = 0       # static
var ck_cacheBoxChunksPerPic: int = 0    # static
var ck_cacheBoxChunkCounter: int = 0    # static


func CK_BeginCacheBox(title: String, numChunks: int) -> void:
	# Vanilla keen checks if > 2kb free here; not necessary for omnispeak
	ck_cacheCountdownNum = 0

	# Cache the Keen countdown graphics
	for i: int in range(6):
		# TODO: Episode independence
		CA_CacheGrChunk(CK_CHUNKNUM("PIC_COUNTDOWN5") + i)
		ca_graphChunkNeeded[CK_CHUNKNUM("PIC_COUNTDOWN5") + i] &= ~ca_levelbit

		# If a pic can't be cached, forget updating the hand pics by setting
		# the countdown counter at 5
		if ca_graphChunks[CK_CHUNKNUM("PIC_COUNTDOWN5") + i] == null:
			ck_cacheCountdownNum = 5
			break

		# MM_SetPurge(ca_graphChunks + PIC_COUNTDOWN5 + i, 3): memory only

	US_CenterWindow(26, 8)

	if ca_graphChunks[CK_CHUNKNUM("PIC_COUNTDOWN5")] != null:
		VHB_DrawBitmap(US_GetWindowX(), US_GetWindowY(), CK_CHUNKNUM("PIC_COUNTDOWN5"))
	else:
		ck_cacheCountdownNum = 5

	ca_graphChunkNeeded[CK_CHUNKNUM("PIC_COUNTDOWN5")] &= ~ca_levelbit
	US_SetWindowW(US_GetWindowW() - 0x30)
	US_SetWindowX(US_GetWindowX() + 0x30)
	# Omnispeak FIXME: Start printX at the right spot (not present in Keen 5)
	US_SetPrintX(US_GetWindowX())
	var wh: PackedInt32Array = CK_MeasureMultiline(title)
	US_SetPrintY(US_GetPrintY() + (US_GetWindowH() - wh[1]) / 2 - 4)
	US_CPrint(title)
	VH_UpdateScreen()

	ck_cacheBoxChunksPerPic = numChunks / 6
	ck_cacheBoxChunkCounter = ck_cacheBoxChunksPerPic

	if ck_cacheBoxChunksPerPic == 0 and ck_cacheCountdownNum == 0:
		ck_cacheCountdownNum = 5
		if ca_graphChunks[CK_CHUNKNUM("PIC_COUNTDOWN0")] != null:
			VHB_DrawBitmap(US_GetWindowX() - 24, US_GetWindowY() + 40, CK_CHUNKNUM("PIC_COUNTDOWN0"))

		VH_UpdateScreen()


func CK_UpdateCacheBox() -> void:
	ck_cacheBoxChunkCounter -= 1

	if ck_cacheBoxChunkCounter == 0 and ck_cacheCountdownNum <= 4:
		ck_cacheBoxChunkCounter = ck_cacheBoxChunksPerPic
		if ca_graphChunks[CK_CHUNKNUM("PIC_COUNTDOWN4") + ck_cacheCountdownNum] != null:
			VHB_DrawBitmap(US_GetWindowX() - 24, US_GetWindowY() + 40, CK_CHUNKNUM("PIC_COUNTDOWN4") + ck_cacheCountdownNum)
		VH_UpdateScreen()
		# Because loading is VERY fast on omnispeak, add artificial delay
		var loadingDelay: int = CFG_GetConfigInt("loadingDelay", 10)
		if loadingDelay != 0:
			VL_DelayTics(loadingDelay)
		ck_cacheCountdownNum += 1


func CK_FinishCacheBox() -> void:
	pass


func CK_TryAgainMenu() -> bool:
	var y1: int = 0
	var y2: int = 0
	var sel: int = 0
	var y: int = 0
	var clr: int = 0

	# Copy and measure the level name
	var buf: String = CK_STRINGELEMENT("ck_str_levelNames", ca_mapOn).substr(0, 79)    # CK_Cross_strscpy(buf, ..., 80)
	var wh: PackedInt32Array = CK_MeasureMultiline(buf)
	var h: int = wh[1]

	# Take away all gems
	ck_gameState.keyGems = PackedInt32Array([0, 0, 0, 0])

	# If lives remain, see if they want to try this level again
	ck_gameState.numLives = s16(ck_gameState.numLives - 1)
	if ck_gameState.numLives >= 0:
		VL_FixRefreshBuffer()
		US_CenterWindow(20, 8)
		US_SetPrintY(US_GetPrintY() + 3)
		US_CPrint(CK_STRING("ck_str_tryAgainIntro"))
		y1 = US_GetPrintY() + 22

		# Center the level name vertically
		if h < 15:
			US_SetPrintY(US_GetPrintY() + 4)
		US_CPrint(buf)

		US_SetPrintY(y1 + 2)
		US_CPrint(CK_STRING("ck_str_tryAgainTryAgain"))
		US_SetPrintY(US_GetPrintY() + 4)
		y2 = US_GetPrintY() - 2
		US_CPrint(CK_STRING("ck_str_exitToMap"))

		IN_ClearKeysDown()
		sel = 0
		while true:
			if quitting:
				return false
			IN_PumpEvents()

			# Decide which selection to draw
			if sel != 0:
				y = y2
			else:
				y = y1

			# Choose a color to draw it in
			if ((SD_GetTimeCount() >> 4) & 1) != 0:
				clr = 12
			else:
				clr = 1

			# And draw the selection box
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y, clr)
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y + 1, clr)
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y + 12, clr)
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y + 13, clr)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + 4, clr)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + 5, clr)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + US_GetWindowW() - 4, clr)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + US_GetWindowW() - 5, clr)
			VH_UpdateScreen()

			# Erase the box for next time
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y, 15)
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y + 1, 15)
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y + 12, 15)
			VHB_HLine(US_GetWindowX() + 4, US_GetWindowX() + US_GetWindowW() - 4, y + 13, 15)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + 4, 15)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + 5, 15)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + US_GetWindowW() - 4, 15)
			VHB_VLine(y + 1, y + 11, US_GetWindowX() + US_GetWindowW() - 5, 15)

			# If they press Esc, they want to go back to the Map
			if IN_GetLastScan() == IN_SC_Escape:
				ck_gameState.currentLevel = 0
				IN_ClearKeysDown()
				return false

			IN_ReadControls(0, ck_inputFrame)
			if ck_inputFrame.jump or ck_inputFrame.pogo or IN_GetLastScan() == IN_SC_Enter or IN_GetLastScan() == IN_SC_Space:
				# If they want to go back to the Map, set the current level to zero
				if sel != 0:
					ck_gameState.currentLevel = 0
				return false

			if ck_inputFrame.yDirection == -1 or IN_GetLastScan() == IN_SC_UpArrow:
				sel = 0
			elif ck_inputFrame.yDirection == 1 or IN_GetLastScan() == IN_SC_DownArrow:
				sel = 1
			# (QUICKSAVE_ENABLED is off in the vanilla build)
	return false


# CK_GameLoop's goto labels
const _GL_TOP: int = 0
const _GL_RESET_DIFFICULTY_AND_LEVEL: int = 1
const _GL_LOAD_LEVEL: int = 2
const _GL_REPLAY_LEVEL: int = 3


## The game loop. The C's gotos (resetDifficultyAndLevel, loadLevel,
## replayLevel, levelcomplete, highscores) become a jump target the loop
## dispatches on (replayLevel skips both loading steps); the order of
## everything done is the C's.
func CK_GameLoop() -> void:
	if not ck_storeDemo:
		if not CK6_CreatureQuestion():
			ck_startingSavedGame = 0
			ck_startingDifficulty = D_NotPlaying
			return

	var target: int = _GL_TOP
	var highscores: bool = false
	while true:    # do { ... } while (true)
		if quitting:
			return
		if target == _GL_TOP:
			target = _GL_RESET_DIFFICULTY_AND_LEVEL if ck_gameState.levelState != LS_LoadedGame else _GL_REPLAY_LEVEL
		if target == _GL_RESET_DIFFICULTY_AND_LEVEL:
			# resetDifficultyAndLevel:
			ck_gameState.difficulty = ck_startingDifficulty
			ck_startingDifficulty = D_NotPlaying
			target = _GL_LOAD_LEVEL
		if target == _GL_LOAD_LEVEL:
			# loadLevel:
			CK_LoadLevel(true, false)
			# TODO: If this didn't succeed, return to level 0.

		# replayLevel:
		ck_scrollDisabled = false
		SD_WaitSoundDone()
		CK_PlayLoop()
		if quitting:
			return

		if ck_gameState.levelState != LS_LoadedGame:
			ck_gameState.keyGems = PackedInt32Array([0, 0, 0, 0])
			if ck_currentEpisode_ep == EP_CK5:
				ck_gameState.ck5_securityCard = 0

		VL_FixRefreshBuffer()

		if us_tedLevel:
			if ck_gameState.levelState == LS_LoadedGame:
				target = _GL_REPLAY_LEVEL
				continue
			elif ck_gameState.levelState == LS_Died:
				target = _GL_LOAD_LEVEL
				continue
			else:
				# NOTE: We don't actually try to launch TED, which was done by TEDDeath().
				Quit("")
				return

		ck_lastLevelFinished = -1
		var levelcomplete: bool = false
		match ck_gameState.levelState:
			LS_Died:
				if CK_TryAgainMenu():
					target = _GL_REPLAY_LEVEL
					continue

			LS_Foot:
				if ck_currentEpisode_ep == EP_CK6:
					IN_ClearKeysDown()
				else:
					levelcomplete = true    # falls through into LS_LevelComplete

			LS_LevelComplete, LS_TeleportToKorath:
				levelcomplete = true

			LS_ResetGame:
				target = _GL_RESET_DIFFICULTY_AND_LEVEL
				continue

			LS_LoadedGame:
				target = _GL_REPLAY_LEVEL
				continue

			LS_AbortGame:
				# Quit to Dos
				IN_ClearKeysDown()
				return

			# Episode Specific Level Endings
			LS_CouncilRescued:
				if ck_currentEpisode_ep == EP_CK4:
					if ca_mapOn != 0:
						SD_PlaySound(CK_SOUNDNUM("SOUND_LEVELEXIT"))

					ck_lastLevelFinished = ca_mapOn
					ck_gameState.levelsDone[ca_mapOn] = 1
					CK4_ShowCouncilMessage()

					if ck_gameState.ck4_membersRescued == CK_INT("CK4_NumCouncilsToRescue", 8):
						# Game won
						CK_EndingPurge()
						# RF_Reset();
						VL_FixRefreshBuffer()
						help_endgame()
						CK_SubmitHighScore(ck_gameState.keenScore, ck_gameState.ck4_membersRescued)
						return
					else:
						# Back to map
						ck_gameState.currentLevel = 0

			LS_Sandwich:
				CK6_ShowGetSandwich()
				levelcomplete = true    # goto levelcomplete
			LS_Rope:
				CK6_ShowGetRope()
				levelcomplete = true    # goto levelcomplete
			LS_Passcard:
				CK6_ShowGetPasscard()
				levelcomplete = true    # goto levelcomplete
			LS_Molly:
				# Game won
				CK_EndingPurge()
				# RF_Reset();
				VL_FixRefreshBuffer()
				help_endgame()
				highscores = true    # goto highscores

			LS_KorathFuse:
				if ck_currentEpisode_ep == EP_CK5:
					# The level has been ended by fuse destruction
					SD_PlaySound(CK_SOUNDNUM("SOUND_LEVELEXIT"))
					ck_lastLevelFinished = ca_mapOn
					ck_gameState.levelsDone[ca_mapOn] = LS_KorathFuse
					CK5_FuseMessage()
					ck_gameState.currentLevel = 0

			LS_DestroyedQED:
				# The QED was destroyed
				CK_EndingPurge()
				VL_FixRefreshBuffer()
				help_endgame()
				CK_SubmitHighScore(ck_gameState.keenScore, 0)
				return

		if levelcomplete:
			# levelcomplete:
			if ca_mapOn == 0:
				# NOTE: In theory, this is written directly to the current
				# frontbuffer. It shouldn't matter, as we've already fixed
				# the refresh buffer.
				US_CenterWindow(26, 8)
				US_SetPrintY(US_GetPrintY() + 25)
				US_Print("One moment")
				# The original only does this for CGA due to the frontbuffer hack above.
				VH_UpdateScreen()
			else:
				# We've won, return to main map.
				SD_PlaySound(CK_SOUNDNUM("SOUND_LEVELEXIT"))
				ck_gameState.currentLevel = 0
				ck_lastLevelFinished = ca_mapOn
				ck_gameState.levelsDone[ca_mapOn] = 1

				# Quit out early if we're doing the store demo.
				if ck_storeDemo and ca_mapOn == 2:
					IN_ClearKeysDown()
					return

		if highscores:
			break

		if ck_gameState.numLives < 0:
			break

		target = _GL_LOAD_LEVEL    # goto loadLevel (livesLeft >= 0)

	if not highscores:
		# Keen 5: Blow up the galaxy
		if ck_currentEpisode_ep == EP_CK5:
			CK5_ExplodeGalaxy()
		else:
			CK_GameOver()

	# highscores:
	if ck_currentEpisode_ep == EP_CK4:
		CK_SubmitHighScore(ck_gameState.keenScore, ck_gameState.ck4_membersRescued)
	if ck_currentEpisode_ep == EP_CK5:
		CK_SubmitHighScore(ck_gameState.keenScore, 0)
	if ck_currentEpisode_ep == EP_CK6:
		var complete: int = 0
		for i: int in range(25):
			if ck_gameState.levelsDone[i] != 0:
				complete += 1
		CK_SubmitHighScore(ck_gameState.keenScore, complete)


# ===================================================================== ck_text.c

var help_delay: int = 0
var help_pic: int = 0
var help_y: int = 0
var help_x: int = 0
## help_ptr (char *): an offset into help_text, the text chunk it points into.
var help_ptr: int = 0
var help_text: PackedByteArray = PackedByteArray()
var help_line: int = 0
var help_line_startx: PackedInt32Array = _game_int_array(18)
var help_line_endx: PackedInt32Array = _game_int_array(18)
var help_cur_page: int = 0
var help_num_pages: int = 0
var help_topic: int = 0
var help_full_page: int = 0
## The chunks for each of the topics (HAS_HELPSCREEN).
const help_chunks: PackedStringArray = ["TEXT_HELPMENU", "TEXT_CONTROLS", "TEXT_STORY", "TEXT_ORDER", "TEXT_ABOUTID"]


static func _game_int_array(n: int) -> PackedInt32Array:
	var a: PackedInt32Array = PackedInt32Array()
	a.resize(n)
	return a


## *(help_ptr + d) as a C char (signed); 0 past the chunk's end.
func _help_char(d: int = 0) -> int:
	var i: int = help_ptr + d
	if i < 0 or i >= help_text.size():
		return 0
	return s8(help_text[i])


## True when help_ptr has left the chunk: a scan the C would run on past the
## chunk into other memory stops there instead (with a Quit).
func _help_overrun(where: String) -> bool:
	if help_ptr < 0 or help_ptr > help_text.size():
		Quit("%s: read past the end of the text" % where)
		return true
	return quitting


func RipToEOL() -> void:
	while true:
		if _help_overrun("RipToEOL"):
			return
		var c: int = _help_char()
		help_ptr += 1
		if c == 10:
			break


func ParseNumber() -> int:
	var s: String = ""
	var c: int = 0

	# Find first digit
	c = _help_char()
	while c < 48 or c > 57:
		if _help_overrun("ParseNumber"):
			return 0
		help_ptr += 1
		c = _help_char()

	# Copy digits into array
	while true:
		s += char(c)    # will be digit
		help_ptr += 1
		c = _help_char()
		if not (c >= 48 and c <= 57):
			break

	return s.to_int()    # atoi


func ParsePicCommand() -> void:
	help_y = ParseNumber()
	help_x = ParseNumber()
	help_pic = ParseNumber()
	RipToEOL()


func ParseTimedCommand() -> void:
	help_y = ParseNumber()
	help_x = ParseNumber()
	help_pic = ParseNumber()
	help_delay = ParseNumber()
	RipToEOL()


func TimedPicCommand() -> void:
	ParseTimedCommand()
	# VW_WaitVBL( 1 );
	VL_GetTics(1)
	# VWL_ScreenToScreen( AZ : A7B4, AZ : A7B2, 40, 200 );
	VL_Present()
	VL_DelayTics(help_delay)
	VHB_DrawBitmap(help_x & 0xFFF8, help_y, help_pic)


func HandleCommand() -> void:
	var i: int = 0
	var w: int = 0
	var h: int = 0
	var midx: int = 0
	var wrapx: int = 0
	var miny: int = 0
	var maxy: int = 0

	help_ptr += 1
	match CK_Cross_toupper(_help_char()):
		66:    # 'B'
			# Solid red box y, x, w, h
			help_y = ParseNumber()
			help_x = ParseNumber()
			w = s16(ParseNumber())
			h = s16(ParseNumber())
			VHB_Bar(help_x, help_y, w, h, 4)
			RipToEOL()

		80, 69:    # 'P', 'E'
			# Page or end of text
			help_full_page = 1
			help_ptr -= 1

		67:    # 'C'
			# Set the text color
			help_ptr += 1

			# A single hex digit is used for the text color
			i = s16(CK_Cross_toupper(_help_char()))
			if i >= 48 and i <= 57:
				US_SetPrintColour(i - 48)
			elif i >= 65 and i <= 70:
				US_SetPrintColour(i - 65 + 10)

			# We're writing on a red background, so take that into account
			US_SetPrintColour(US_GetPrintColour() ^ 4)
			help_ptr += 1

		76:    # 'L'
			# Set the next location for text
			US_SetPrintY(ParseNumber())

			# Set the y position to the nearest line
			help_line = (US_GetPrintY() - 10) / 10
			US_SetPrintY(help_line * 10 + 10)

			# Set the x position
			US_SetPrintX(ParseNumber())

			# Skip to the next line
			while true:
				if _help_overrun("HandleCommand"):
					return
				var c: int = _help_char()
				help_ptr += 1
				if c == 10:
					break

		84:    # 'T'
			TimedPicCommand()

		71:    # 'G'
			# Draw the picture
			ParsePicCommand()
			VHB_DrawBitmap(help_x & ~7, help_y, help_pic)
			var bmpinfo: Dictionary = VH_GetBitmapTableEntry(help_pic - int(ca_gfxInfoE.offBitmaps))
			w = s16(int(bmpinfo.width) * 8)
			h = s16(bmpinfo.height)

			# Wrap text either on the left or the right-hand-side of the picture
			midx = s16(help_x + w / 2)
			if midx > 160:
				wrapx = s16(help_x - 8)
			else:
				wrapx = s16(help_x + w + 8)

			# Get the first line that the picture covers
			miny = s16((help_y - 10) / 10)
			if miny < 0:
				miny = 0

			# Get the last line that the picture covers
			maxy = s16((help_y + h - 10) / 10)
			if maxy >= 18:
				maxy = 17

			# Set the lines' starting or finishing text positions
			i = miny
			while i <= maxy:
				if midx > 160:    # Wrapping to the left
					help_line_endx[i] = wrapx
				else:    # Wrapping to the right
					help_line_startx[i] = wrapx
				i += 1

			# Make sure the next print doesn't start in the middle of the pic
			if help_line_startx[help_line] > US_GetPrintX():
				US_SetPrintX(help_line_startx[help_line])


func NewLine() -> void:
	var c: int = 0

	help_line += 1
	if help_line == 18:
		# Move back to line 1 and read input till the next ^P or ^E command
		help_full_page = 1
		while true:
			if _help_overrun("NewLine"):
				return
			if _help_char() == 94:    # '^'
				c = CK_Cross_toupper(_help_char(1))
				if c == 69 or c == 80:    # 'E', 'P'
					help_full_page = 1
					return
			help_ptr += 1

	# Move to the next line
	US_SetPrintX(help_line_startx[help_line])
	US_SetPrintY(US_GetPrintY() + 10)


func HandleChar() -> void:
	var c: int = _help_char()
	help_ptr += 1

	# If the last character was a newline, do something about it!
	if c == 10:
		NewLine()


func HandleWord() -> void:
	var buf: PackedByteArray = PackedByteArray()
	var w: int = 0
	var maxx: int = 0
	var i: int = 0

	# Read a word into the buffer
	buf.append(_help_char() & 0xFF)
	help_ptr += 1
	i = 1
	while _help_char() > 32:
		buf.append(_help_char() & 0xFF)
		help_ptr += 1
		i += 1
		if i == 80:
			Quit("PageLayout: Word limit exceeded")
			return

	# Measure the word (buf is terminated with a null)
	var word: String = _game_cstring(buf, 0)
	var wh: PackedInt32Array = VH_MeasurePropString(word, US_GetPrintFont())
	w = wh[0]

	# See if we can find a line to fit the word on
	while help_line_endx[help_line] < US_GetPrintX() + w:
		NewLine()
		if help_full_page != 0:
			return

	# Display the word
	maxx = u16(US_GetPrintX() + w)
	VHB_DrawPropString(word, US_GetPrintX(), US_GetPrintY(), US_GetPrintFont(), US_GetPrintColour())
	US_SetPrintX(maxx)

	# Handle spaces between this word and the next
	while _help_char() == 32:
		US_SetPrintX(US_GetPrintX() + 7)
		help_ptr += 1


func PageLayout(show_status: int) -> void:
	var old_print_color: int = 0
	var c: int = 0

	# Save the current print color
	old_print_color = s8(US_GetPrintColour())
	US_SetPrintColour(10)

	# We want to scanout from the right offset.
	VL_SetScrollCoords(0, 0)

	# Fill the background and draw the border
	VHB_Bar(0, 0, 320, 200, 4)
	if ck_currentEpisode_ep != EP_CK6:
		VHB_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_BORDERTOP"))    # Top border
		VHB_DrawBitmap(0, 8, CK_CHUNKNUM("PIC_BORDERLEFT"))    # Left border
		VHB_DrawBitmap(312, 8, CK_CHUNKNUM("PIC_BORDERRIGHT"))    # Right border
		if show_status != 0:
			VHB_DrawBitmap(8, 176, CK_CHUNKNUM("PIC_BORDERBOTTOMSTATUS"))    # Bottom status bar
		else:
			VHB_DrawBitmap(8, 192, CK_CHUNKNUM("PIC_BORDERBOTTOM"))    # Bottom border

	# Set the lines' start and end positions so the text stays within the border
	for i: int in range(18):
		help_line_startx[i] = 10
		help_line_endx[i] = 310

	# The text should start inside the border
	US_SetPrintX(10)
	US_SetPrintY(10)
	help_line = 0
	help_full_page = 0

	# Skip any nonprinting characters at the start (a C char: bytes over 127 count too)
	while _help_char() <= 32:
		if _help_overrun("PageLayout"):
			return
		help_ptr += 1

	# Make sure we start with a "new page" command
	var caret: bool = _help_char() == 94
	help_ptr += 1
	if not (caret and CK_Cross_toupper(_help_char()) == 80):
		Quit("PageLayout: Text not headed with ^P")
		return

	# Move to the next line after the ^P
	while true:
		if _help_overrun("PageLayout"):
			return
		c = _help_char()
		help_ptr += 1
		if c == 10:
			break

	while true:
		if _help_overrun("PageLayout"):
			return
		# Parse a command or print a word
		c = _help_char()
		if c == 94:
			HandleCommand()
		elif c <= 32:
			HandleChar()
		else:
			HandleWord()
		if help_full_page != 0:
			break

	# Set the page number that we're on
	help_cur_page += 1

	# Show the current page number
	if show_status != 0:
		var buf: String = "pg %d of %d" % [help_cur_page, help_num_pages]

		US_SetPrintColour(8)
		US_SetPrintY(186)
		US_SetPrintX(218)
		VHB_DrawPropString(buf, US_GetPrintX(), US_GetPrintY(), US_GetPrintFont(), US_GetPrintColour())

	# Restore the original print color
	US_SetPrintColour(old_print_color)


func BackPage() -> void:
	help_cur_page -= 1

	# Look backwards for a '^P'
	while true:
		help_ptr -= 1
		if _help_overrun("BackPage"):
			return
		if _help_char() == 94 and CK_Cross_toupper(_help_char(1)) == 80:
			break


func CacheLayoutGraphics() -> void:
	var pstart: int = 0
	var pmax: int = 0
	var c: int = 0

	# Initialise the pointers
	pstart = help_ptr
	pmax = pstart + 30000

	help_cur_page = 0
	help_num_pages = 0

	# Cache the border graphics
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_BORDERTOP"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_BORDERLEFT"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_BORDERRIGHT"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_BORDERBOTTOMSTATUS"))
	CA_MarkGrChunk(CK_CHUNKNUM("PIC_BORDERBOTTOM"))

	while true:
		if quitting:
			return
		if _help_char() == 94:
			help_ptr += 1
			c = CK_Cross_toupper(_help_char())

			# Count pages
			if c == 80:
				help_num_pages += 1
			# If we've reached the end, rewind the help pointer and return
			if c == 69:
				CA_CacheMarks("")    # CA_CacheMarks(0)
				help_ptr = pstart
				return
			# Cache ordinary graphics
			if c == 71:
				ParsePicCommand()
				ca_graphChunkNeeded[help_pic] |= ca_levelbit
			# Cache timed graphics
			if c == 84:
				ParseTimedCommand()
				ca_graphChunkNeeded[help_pic] |= ca_levelbit
		else:
			help_ptr += 1
		if not (help_ptr < pmax):
			break

	# If we got here, we didn't find the end of the text
	Quit("CacheLayoutGraphics: No ^E to terminate file!")


func ShowHelp() -> int:
	var ymove: int = 0
	var key: int = 0
	var cinfo: IN_ControlFrame = IN_ControlFrame.new()

	# Erase the screen
	VHB_Bar(0, 0, 320, 200, 4)

	# Cache graphics
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_HELPMENU"))    # Help menu pic
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_HELPPOINTER"))    # Help menu pointer
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_BORDERTOP"))    # Top border
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_BORDERLEFT"))    # Left border
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_BORDERRIGHT"))    # Right border
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_BORDERBOTTOM"))    # Bottom border

	# Draw the border and the main menu pic
	VHB_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_BORDERTOP"))    # Top border
	VHB_DrawBitmap(0, 8, CK_CHUNKNUM("PIC_BORDERLEFT"))    # Left border
	VHB_DrawBitmap(312, 8, CK_CHUNKNUM("PIC_BORDERRIGHT"))    # Right border
	VHB_DrawBitmap(8, 192, CK_CHUNKNUM("PIC_BORDERBOTTOM"))    # Bottom border
	VHB_DrawBitmap(96, 8, CK_CHUNKNUM("PIC_HELPMENU"))    # Menu picture

	ymove = 0
	IN_ClearKeysDown()
	while true:
		if quitting:
			return -1
		IN_PumpEvents()

		# Make sure the pointer is in a valid place
		if help_topic < 0:
			help_topic = 0
		elif help_topic > 4:
			help_topic = 4

		# Draw the pointer
		VHB_DrawBitmap(48, 48 + help_topic * 24, CK_CHUNKNUM("PIC_HELPPOINTER"))
		VL_SetScrollCoords(0, 0)
		VH_UpdateScreen()

		# Erase the pointer
		VHB_Bar(48, 48 + help_topic * 24, 39, 24, 4)

		# Check for input
		IN_ReadControls(0, cinfo)

		# Handle keys
		if IN_GetLastScan() != IN_SC_None:
			key = IN_GetLastScan()
			IN_ClearKeysDown()
			match key:
				IN_SC_UpArrow:
					help_topic -= 1
				IN_SC_Escape:
					VL_ClearScreen(4)
					return -1
				IN_SC_Enter:
					VL_ClearScreen(4)
					return help_topic
				IN_SC_DownArrow:
					help_topic += 1

		# Handle other input
		if cinfo.jump or cinfo.pogo:
			VL_ClearScreen(4)
			return help_topic

		if ymove < -40:
			ymove += 40
			help_topic -= 1
		elif ymove > 40:
			ymove -= 40
			help_topic += 1
	return -1


func HelpScreens() -> void:
	var oldfont: int = 0
	var page_changed: int = 0
	var n: int = 0

	# Save the variables
	oldfont = s16(US_GetPrintFont())

	# Init stuff
	VL_SetScrollCoords(0, 0)
	VL_ClearScreen(4)
	US_SetPrintFont(0)

	if ck_currentEpisode_ep == EP_CK5:
		StartMusic(19)

	while true:
		if quitting:
			return
		n = s16(ShowHelp())
		VL_ClearScreen(4)

		# If the user pressed Esc
		if n == -1:
			# Clean up and return
			# CA_DownLevel();
			IN_ClearKeysDown()
			US_SetPrintFont(oldfont)
			VL_ClearScreen(4)
			# RF_Reset();
			if ck_currentEpisode_ep == EP_CK5:
				StopMusic()
			return

		# Cache the chunk with the topic
		n = s16(CK_LookupChunk(help_chunks[n]))
		CA_CacheGrChunk(n)

		# Set up the help ptr and initialise the parser
		help_text = ca_graphChunks[n]
		help_ptr = 0
		CacheLayoutGraphics()

		page_changed = 1
		while true:
			if quitting:
				return
			if page_changed != 0:
				page_changed = 0
				PageLayout(1)

				VL_SwapOnNextPresent()
				VL_Present()

			# Wait for the user to press a key
			IN_ClearKeysDown()
			while IN_GetLastScan() == IN_SC_None and not quitting:
				IN_PumpEvents()

			# Take action
			match IN_GetLastScan():
				IN_SC_UpArrow, IN_SC_PgUp, IN_SC_LeftArrow:
					if help_cur_page > 1:
						BackPage()    # This one only takes us back to the *current* page
						BackPage()
						page_changed = 1
				IN_SC_RightArrow, IN_SC_DownArrow, IN_SC_PgDown:
					if help_cur_page < help_num_pages:
						page_changed = 1
			if IN_GetLastScan() == IN_SC_Escape:
				break

		# Uncache the topic we just saw
		ca_graphChunks[n] = null    # MM_FreePtr(&ca_graphChunks[n])
		IN_ClearKeysDown()

		# Return to main help menu loop


func help_endgame() -> void:
	# Set up
	VL_ClearScreen(4)
	# RF_Reset();
	CA_UpLevel()
	CA_SetGrPurge()
	# CA_SetGrPurge2();

	# Cache the chunks we need
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_ARROWDIM"))    # Dim arrow
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_ARROWBRIGHT"))    # Bright arrow

	# Check for Korath Fuse (in every episode: the C's episode check is commented out)
	var ptext: PackedByteArray
	if ck_gameState.levelsDone[13] == 0x0E:
		CA_CacheGrChunk(CK_CHUNKNUM("TEXT_SECRETEND"))
		ptext = ca_graphChunks[CK_CHUNKNUM("TEXT_SECRETEND")]
	else:
		CA_CacheGrChunk(CK_CHUNKNUM("TEXT_END"))
		ptext = ca_graphChunks[CK_CHUNKNUM("TEXT_END")]

	# Initialise the parser
	help_text = ptext
	help_ptr = 0
	CacheLayoutGraphics()

	# Play some music
	StartMusic(CK_INT("CK_EndingMusicLevel", 0))

	while help_cur_page < help_num_pages:
		if quitting:
			return
		# Draw the current page (which also advances to the next page)
		PageLayout(0)
		IN_ClearKeysDown()
		# VW_SetScreen( AZ : A7B4, 0 );

		# This looks like it was written with a GOTO instead of an "advancePage" variable
		var advancePage: bool = false
		while not advancePage:
			if quitting:
				return
			# Draw the dim arrow and wait a short time
			VHB_DrawBitmap(0x12A & ~3, 0xB8, CK_CHUNKNUM("PIC_ARROWDIM"))
			VH_UpdateScreen()

			if IN_UserInput(70, false):
				advancePage = true
				break
			# Draw the bright arrow and wait a short time
			VHB_DrawBitmap(0x12A & ~3, 0xB8, CK_CHUNKNUM("PIC_ARROWBRIGHT"))
			VH_UpdateScreen()

			if IN_UserInput(70, false):
				advancePage = true
				break

	# Uncache our graphics and clean up
	StopMusic()
	if ck_gameState.levelsDone[13] == LS_KorathFuse:
		ca_graphChunks[CK_CHUNKNUM("TEXT_SECRETEND")] = null    # MM_FreePtr
	else:
		ca_graphChunks[CK_CHUNKNUM("TEXT_END")] = null
	ca_graphChunks[CK_CHUNKNUM("PIC_ARROWBRIGHT")] = null
	ca_graphChunks[CK_CHUNKNUM("PIC_ARROWDIM")] = null
	# CA_DownLevel();
	IN_ClearKeysDown()
	VL_ClearScreen(4)
	# RF_Reset();
	# CA_SetGrPurge();


# ===================================================================== ck_inter.c

# (ck_startingSavedGame, ck_inHighScores and ck_startingDifficulty: gal_ck.gd)


func CK_HandleDemoKeys() -> void:
	if IN_GetLastScan() == 0:
		return

	if ck_storeDemo:
		ck_gameState.levelState = LS_ResetGame
		ck_startingDifficulty = D_Normal
		IN_ClearKeysDown()
		CK_NewGame()
	elif ck_currentEpisode_ep != EP_CK6 and IN_GetLastScan() == IN_SC_F1:
		HelpScreens()
		return
	else:
		# Otherwise, start the wristwatch menu
		US_RunCards()
		if ck_startingDifficulty != 0:
			ck_gameState.levelState = LS_ResetGame
			return

		if ck_startingSavedGame != 0:
			ck_gameState.levelState = LS_LoadedGame


# Terminator Intro Text
#
# Three planes move over each other: the KEEN graphic (video plane 0), put in
# video memory once and scrolled left off the screen; the visible part of the
# COMMANDER graphic (plane 1), kept in 8 shifts for smooth scrolling; and the
# scrolling credits on top (planes 2 and 3). Then the zoom-out runs, scaling a
# bitmap made of the COMMANDER and KEEN graphics joined.

const TERMINATORSCREENWIDTH: int = 150    # 124

## The two monochrome bitmaps scrolled during the intro (introbmptype *: the
## chunk: height, width, linestarts[200], then the RLE data).
var ck_introKeen: PackedByteArray = PackedByteArray()
var ck_introCommander: PackedByteArray = PackedByteArray()

# segment pointers to various graphic chunks
var introbuffer: PackedByteArray = PackedByteArray()
var introbuffer2: PackedByteArray = PackedByteArray()
var shiftedCmdrBMPsegs: Array = [PackedByteArray(), PackedByteArray(), PackedByteArray(), PackedByteArray(),
	PackedByteArray(), PackedByteArray(), PackedByteArray(), PackedByteArray()]

const terminator_blackmasks: PackedByteArray = [0xFF, 0x7F, 0x3F, 0x1F, 0x0F, 0x07, 0x03, 0x01]
const terminator_lightmasks: PackedByteArray = [0x00, 0x80, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC, 0xFE]
var ck_terminator_palette1: PackedByteArray = PackedByteArray()
var ck_terminator_palette2: PackedByteArray = PackedByteArray()

## chunk #'s for the vertically scrolling pics
const terminator_pics: PackedStringArray = ["PIC_CREDIT1", "PIC_CREDIT2", "PIC_CREDIT3", "PIC_CREDIT4"]
## storage for the vertically scrolling pics
var terminator_pic_memptrs: Array = [null, null, null, null]

## Width of the COMMANDER graphic, in BYTES
var ck_introCommanderWidth: int = 0

var ck_introScreenWidth: int = 0

# type-identified variables
var ck_currentTermPicTimeRemaining: int = 0
var ck_currentTermPicStartTime: int = 0

## Which terminator credit image we're drawing
var ck_currentTerminatorCredit: int = 0

## What action the terminator credit is currently doing (loading/flying up/pausing/flying out)
var ck_termCreditStage: int = 0

var word_499D1: int = 0    # unsigned *
var ck_currentTermPicSeg: PackedByteArray = PackedByteArray()

var word_499CB: int = 0
# unknown variables

var word_46CA2: PackedInt32Array = PackedInt32Array([0, 0])
var word_46CB0: int = 0

var word_499C7: int = 0
var terminatorOfs: int = 0    # Start of the screen buffer; the KEEN graphic is aligned to the left edge of this
var terminatorPlaneOn: int = 0
var ck_currentTermPicNextLineDist: int = 0
var ck_currentTermPicSize: int = 0
var ck_currentTermPicHeight: int = 0
var ck_currentTermPicHalfWidth: int = 0
var ck_currentTermPicWidth: int = 0
var ck_termPicHeights: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var ck_termPicWidths: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])

# (DoubleSizeTerminatorPics is declared in ck_inter.c but never defined)


## Returns the Y-position of the terminator credit.
func AdvanceTerminatorCredit(elapsedTime: int) -> int:
	var picchunk: int = 0

	# case -1 flows into case 0, as the C's switch does
	if ck_termCreditStage == -1:
		# loading
		picchunk = CK_LookupChunk(terminator_pics[ck_currentTerminatorCredit])
		CA_CacheGrChunk(picchunk)
		var bmp: Dictionary = VH_GetBitmapTableEntry(picchunk - int(ca_gfxInfoE.offBitmaps))
		ck_currentTermPicSeg = ca_graphChunks[picchunk]
		ck_currentTermPicWidth = u16(bmp.width)    # This is width in EGA bytes (1/8 px)
		ck_currentTermPicHalfWidth = u16((ck_currentTermPicWidth + 3) >> 1)
		ck_currentTermPicHeight = u16(bmp.height)
		# The size in bytes of the pic.
		ck_currentTermPicSize = u16(ck_currentTermPicWidth * ck_currentTermPicHeight)
		ck_termCreditStage += 1

		ck_currentTermPicStartTime = elapsedTime
		ck_currentTermPicTimeRemaining = 240
		# no break, flow into case 0
		return _AdvanceTerminatorCredit_flyUp(elapsedTime)

	match ck_termCreditStage:
		0:
			return _AdvanceTerminatorCredit_flyUp(elapsedTime)

		1:
			# Pausing in the middle
			if elapsedTime - ck_currentTermPicStartTime > 200:
				ck_termCreditStage += 1
				ck_currentTermPicStartTime = elapsedTime

			return 100 - (ck_currentTermPicHeight >> 1)

		2:
			# Flying up and out of the top of the screen
			ck_currentTermPicTimeRemaining = s32(ck_currentTermPicTimeRemaining - ((elapsedTime - ck_currentTermPicStartTime) << 1))

			if ck_currentTermPicTimeRemaining < -40:
				ck_currentTermPicTimeRemaining = -40

				# Are there any more terminator credit images?
				ck_currentTerminatorCredit += 1
				if ck_currentTerminatorCredit < 4:
					ck_termCreditStage = -1
				else:
					ck_termCreditStage = 3

			ck_currentTermPicStartTime = elapsedTime

			return ck_currentTermPicTimeRemaining - (ck_currentTermPicHeight >> 1)

	return -40


## AdvanceTerminatorCredit's case 0 (case -1 falls into it).
func _AdvanceTerminatorCredit_flyUp(elapsedTime: int) -> int:
	# Flying up from bottom of screen
	ck_currentTermPicTimeRemaining = s32(ck_currentTermPicTimeRemaining - ((elapsedTime - ck_currentTermPicStartTime) << 1))

	if ck_currentTermPicTimeRemaining < 100:
		ck_currentTermPicTimeRemaining = 100
		ck_termCreditStage += 1

	ck_currentTermPicStartTime = elapsedTime

	return ck_currentTermPicTimeRemaining - (ck_currentTermPicHeight >> 1)


# ScrollTerminatorCredits' statics ("Vars are static because BP is used during ASM draw routine")
var ScrollTerminatorCredits_rowsToDraw: int = 0
var ScrollTerminatorCredits_oldY2: PackedInt32Array = PackedInt32Array([0, 0])


func ScrollTerminatorCredits(elapsedTime: int, xpixel: int) -> void:
	elapsedTime = u16(elapsedTime)
	xpixel = u16(xpixel)
	var creditY1: int = 0
	var picStartOffset: int = 0

	var picX: int = xpixel + (160 - ck_currentTermPicWidth * 4)

	VL_SetMapMask(0xC)

	creditY1 = AdvanceTerminatorCredit(elapsedTime)

	# Erasing the area underneath the credit
	var creditY2: int = creditY1 + ck_currentTermPicHeight
	# The original assembly code here cleared a word at a time, hence the rounding here.
	var termPicClearWidth: int = ((ck_currentTermPicWidth + 3) / 2) * 16

	if creditY2 < 0:
		creditY2 = 0

	if creditY2 < 200 and ScrollTerminatorCredits_oldY2[VL_GetActiveBuffer()] > creditY2:
		var rowsToClear: int = ScrollTerminatorCredits_oldY2[VL_GetActiveBuffer()] - creditY2
		# Omnispeak: Just draw an empty rectangle over the area
		VL_ScreenRect_PM(picX, creditY2, termPicClearWidth, rowsToClear, 0x0)

	if creditY2 > 200:
		creditY2 = 200

	ScrollTerminatorCredits_oldY2[VL_GetActiveBuffer()] = creditY2

	ScrollTerminatorCredits_rowsToDraw = ck_currentTermPicHeight
	picStartOffset = 0

	if creditY1 < 0:
		# clipped by screen top
		picStartOffset = -creditY1 * ck_currentTermPicWidth
		ScrollTerminatorCredits_rowsToDraw += creditY1
		creditY1 = 0
	elif creditY1 + ck_currentTermPicHeight > 200:
		# clipped by screen bot
		ScrollTerminatorCredits_rowsToDraw = 200 - creditY1

	if ScrollTerminatorCredits_rowsToDraw > 0:
		var plane_1: int = picStartOffset    # into ck_currentTermPicSeg
		var plane_2: int = plane_1 + ck_currentTermPicWidth * ck_currentTermPicHeight

		VL_SetMapMask(0x4)
		VL_1bppToScreen_PM(ck_currentTermPicSeg, plane_1, picX, creditY1, ck_currentTermPicWidth * 8, ScrollTerminatorCredits_rowsToDraw, 0xF)
		VL_ScreenRect_PM(picX + ck_currentTermPicWidth * 8, creditY1, 8, ScrollTerminatorCredits_rowsToDraw, 0)
		VL_SetMapMask(0x8)
		VL_1bppToScreen_PM(ck_currentTermPicSeg, plane_2, picX, creditY1, ck_currentTermPicWidth * 8, ScrollTerminatorCredits_rowsToDraw, 0xF)
		VL_ScreenRect_PM(picX + ck_currentTermPicWidth * 8, creditY1, 8, ScrollTerminatorCredits_rowsToDraw, 0)


## Does the terminator scrolling.
func AnimateTerminator() -> void:
	var cmdrLeftEdgeFromScreenLeft: int = 0
	var delaytime: int = 0

	var joyButtonPressedNow: bool = false
	var joyButtonPressedPrev: bool = false

	# At the end of the terminator scrolling, left edge of the commander graphic
	# is this many pixels from the Left/Right edge of the Visible screen
	var finalCmdrPosFromScreenLeft: int = 0
	var finalCmdrPosFromScreenRight: int = 0

	# How far it's currently scrolled
	var elapsedCmdrScrollDist: int = 0

	# How many pixels the left edge of the screen is away from the left edge of the KEEN image
	var xpixel: int = ck_introScreenWidth

	# start of the visible area in the screen buffer (unsigned)
	var screenofs: int = 0

	var elapsedTime: int = 0

	# The pixel modulo 8 that the left edge of the scrolling CMDR graphic is
	# aligned to, relative to the left edge of the buffer
	var cmdrBMPpelpan: int = 0

	# Which of the shifted "COMMANDER" graphics to use
	var bmpsrcseg: PackedByteArray

	# The distance from the left margin of the COMMANDER graphic that should be
	# drawn, measured in BYTES (px * 8)
	var cmdrLeftDrawStart: int = 0

	# variables of unknown type
	var screenWidthInPx: int = 0
	var maxTime: int = 0
	var leftMarginBlackWords: int = 0
	var cmdrWords: int = 0
	var rightMarginBlackWords: int = 0
	var offscreenCmdrPixels: int = 0
	var nextRowDist: int = 0

	ck_introScreenWidth = _game_rd16(ck_introKeen, 2) + 25 * 8

	finalCmdrPosFromScreenLeft = 120 - _game_rd16(ck_introCommander, 2)
	screenWidthInPx = 320
	finalCmdrPosFromScreenRight = finalCmdrPosFromScreenLeft - screenWidthInPx
	maxTime = absi(finalCmdrPosFromScreenRight)

	terminatorOfs = 0

	# delay for a tic before starting
	SD_SetLastTimeCount(SD_GetTimeCount())
	while SD_GetLastTimeCount() == SD_GetTimeCount() and not quitting:
		SD_WaitTick()    # Keep CPU usage low

	SD_SetLastTimeCount(SD_GetTimeCount())

	# Update the terminator
	elapsedTime = 0
	while elapsedTime <= maxTime:
		if quitting:
			return

		# Reposition the left edge of the screen in direct proportionality to time elapsed
		xpixel = (ck_introScreenWidth * (maxTime - elapsedTime)) / maxTime

		# Scroll the Credits graphics
		ScrollTerminatorCredits(elapsedTime, xpixel)

		elapsedCmdrScrollDist = screenWidthInPx + (finalCmdrPosFromScreenRight * elapsedTime) / maxTime
		elapsedCmdrScrollDist += xpixel & 7

		cmdrLeftEdgeFromScreenLeft = (elapsedCmdrScrollDist + 0x800) / 8 - 0x100
		cmdrBMPpelpan = ((elapsedCmdrScrollDist + 0x800) & 7)

		bmpsrcseg = shiftedCmdrBMPsegs[cmdrBMPpelpan]
		cmdrLeftDrawStart = 0

		# DOS: Move the screen start address
		# screenofs = terminatorOfs + xpixel/8;
		screenofs = xpixel / 8    # Omnispeak

		# Omnispeak: pan the screen to the appropriate spot over the KEEN surface
		VL_SetScrollCoords(xpixel, 0)

		if cmdrLeftEdgeFromScreenLeft > 0:
			# The COMMANDER graphic has not started to scroll off the left edge of the screen
			leftMarginBlackWords = (cmdrLeftEdgeFromScreenLeft + 1) / 2

			if (cmdrLeftEdgeFromScreenLeft & 1) != 0:
				screenofs -= 1    # unsigned: 0 - 1 wraps, and screenofs * 8 then reads as -8

			cmdrWords = 21 - leftMarginBlackWords
			rightMarginBlackWords = 0
		elif cmdrLeftEdgeFromScreenLeft > (42 - ck_introCommanderWidth):
			# The COMMANDER graphic is clipped on both left and right edges
			leftMarginBlackWords = 0
			cmdrWords = 21    # 42 * 8 pixels = 336
			rightMarginBlackWords = 0
			cmdrLeftDrawStart -= cmdrLeftEdgeFromScreenLeft
		else:
			# The COMMANDER graphic is only clipped by the left side of the screen
			leftMarginBlackWords = 0
			cmdrWords = (ck_introCommanderWidth + cmdrLeftEdgeFromScreenLeft) / 2
			rightMarginBlackWords = 21 - cmdrWords
			cmdrLeftDrawStart -= cmdrLeftEdgeFromScreenLeft

		offscreenCmdrPixels = ck_introCommanderWidth - (cmdrWords << 1)
		nextRowDist = TERMINATORSCREENWIDTH - ((leftMarginBlackWords + cmdrWords + rightMarginBlackWords) << 1)

		# Only draw to Plane 1 of EGA memory
		VL_SetMapMask(2)

		# Omnispeak: Just draw the visible part of the COMMANDER surface atop the KEEN surface
		var rowptr: int = 0
		var sx: int = s32(screenofs * 8)
		for row: int in range(200):
			VL_ScreenRect_PM(sx, row, leftMarginBlackWords * 16, 1, 0x0)
			VL_1bppToScreen_PM(bmpsrcseg, rowptr + cmdrLeftDrawStart, sx + leftMarginBlackWords * 16, row, cmdrWords * 16, 1, 0xF)
			VL_ScreenRect_PM(sx + (leftMarginBlackWords + cmdrWords) * 16, row, rightMarginBlackWords * 16, 1, 0x0)

			if (row & 1) != 0:
				rowptr += ck_introCommanderWidth

		# Update the screen
		VL_SwapOnNextPresent()
		VL_Present()

		IN_PumpEvents()
		# Delay
		while true:
			delaytime = s32(SD_GetTimeCount())
			SD_SetSpriteSync(delaytime - SD_GetLastTimeCount())
			SD_WaitTick()
			if SD_GetSpriteSync() >= 2 or quitting:
				break

		SD_SetLastTimeCount(delaytime)

		# Stop drawing if key pressed
		if IN_CheckAck() != 0 and IN_GetLastScan() == IN_SC_F1:
			IN_SetLastScan(IN_SC_Space)

		joyButtonPressedPrev = joyButtonPressedNow
		joyButtonPressedNow = (IN_JoyPresent(0) and IN_GetJoyButtonsDB(0) != 0) or (IN_JoyPresent(1) and IN_GetJoyButtonsDB(1) != 0)
		if joyButtonPressedPrev and not joyButtonPressedNow:
			IN_SetLastScan(IN_SC_Space)

		if IN_GetLastScan() != 0:
			return

		elapsedTime += SD_GetSpriteSync()

	word_499C7 = u16(xpixel / 8)
	var _unused: Array = [offscreenCmdrPixels, nextRowDist, finalCmdrPosFromScreenLeft]


## RLE-Expands one line of monochrome terminator BMP data. Each source line is
## a sequence of words, alternating runs of black and white pixels (black
## first), ended by 0xFFFF. src and dest are C pointers (BytePtr).
func TerminatorExpandRLE(src: BytePtr, dest: BytePtr) -> void:
	# nextword = next source word; runlength = pixels of one color remaining in
	# one byte before the transition; lastbyte = the byte at the transition
	var runlength: int = 0
	var di: int = 0
	var nextword: int = 0
	var lastbyte: int = 0
	var s: int = src.off
	var d: int = dest.off

	while true:
		nextword = _game_rd16(src.buf, s)
		s += 2
		if nextword == 0xFFFF:
			break
		# Expand a Black Run of pixels
		runlength = u16(runlength + nextword)
		if runlength > 7:
			# write the transition byte
			_put(dest.buf, d, lastbyte)
			d += 1

			# the leftmost pixels of the transition byte will be black
			lastbyte = 0

			# write complete bytes
			di = u16(runlength / 8 - 1)
			while di != 0:
				di -= 1
				_put(dest.buf, d, 0)
				d += 1

			# count the leftover pixels on this last byte
			runlength &= 7

		# Check if we've hit a stop signal
		nextword = _game_rd16(src.buf, s)
		s += 2
		if nextword == 0xFFFF:
			_put(dest.buf, d, lastbyte)
			d += 1
			_put(dest.buf, d, 0)
			return

		# the lowest bits in this byte will be black (zero), so we OR the right
		# most remaining bits so that they are drawn white
		lastbyte = u8(lastbyte | terminator_blackmasks[runlength])

		# Expand a Light Run of pixels
		runlength = u16(runlength + nextword)
		if runlength > 7:
			# write the transition byte
			_put(dest.buf, d, lastbyte)
			d += 1

			# the leftmost pixels of the transition byte will be light
			lastbyte = 0xFF

			# write runs of 8 light pixels
			di = u16(runlength / 8 - 1)
			while di != 0:
				di -= 1
				_put(dest.buf, d, 0xFF)
				d += 1

			# count the leftover light pixels on this last byte
			runlength &= 7

		# the lowest bits in this byte will be light (set), so we AND the
		# rightmost remaining bits so that they are drawn black
		lastbyte = lastbyte & terminator_lightmasks[runlength]

	# write the final byte, and one padding byte of black
	_put(dest.buf, d, lastbyte)
	d += 1
	_put(dest.buf, d, 0)


## Generate an RLE-compressed bitmap with COMMANDER KEEN separated by some
## space: here alternating runs are given by their start positions.
func JoinTerminatorPics() -> void:
	# Allocate memory for the COMMANDER KEEN graphic
	introbuffer2 = PackedByteArray()
	introbuffer2.resize(30000)

	# Where we start writing the bitmap data (((introbmptype *)introbuffer2)->data)
	var introBMPDataPtr: int = 4 + 200 * 2

	for i: int in range(200):
		var count: int = 0
		var inword: int = 0
		var linestart: int = 0

		# Generate a pointer to this line of data
		_game_wr16(introbuffer2, 4 + i * 2, introBMPDataPtr)

		count = 0

		linestart = _game_rd16(ck_introCommander, 4 + i * 2)
		inword = _game_rd16(ck_introCommander, linestart)
		linestart += 2

		while true:
			_game_wr16(introbuffer2, introBMPDataPtr, count)
			introBMPDataPtr += 2
			count = u16(count + inword)
			inword = _game_rd16(ck_introCommander, linestart)
			linestart += 2
			if inword == 0xFFFF:
				break

		# Add some space between the COMMANDER and the KEEN
		count = u16(count + 80)

		linestart = _game_rd16(ck_introKeen, 4 + i * 2)
		linestart += 2
		inword = _game_rd16(ck_introKeen, linestart)
		linestart += 2

		while true:
			_game_wr16(introbuffer2, introBMPDataPtr, count)
			introBMPDataPtr += 2
			count = u16(count + inword)
			inword = _game_rd16(ck_introKeen, linestart)
			linestart += 2
			if inword == 0xFFFF:
				break

		_game_wr16(introbuffer2, introBMPDataPtr, count)
		introBMPDataPtr += 2
		_game_wr16(introbuffer2, introBMPDataPtr, 0xFFFF)
		introBMPDataPtr += 2


## One zoomed line: rleData is a byte offset into introbuffer2 (the C's
## uint16_t pointer into it). The C's gotos (writeWhiteRun, loc_147E5,
## writeBlackRun) become the entry point into the run loop.
func ZoomOutTerminator_1(rleData: int, arg4: int, leftOffset: int, scaleFactor: int) -> void:
	arg4 = u16(arg4)
	scaleFactor = u16(scaleFactor)
	var inputOffset: int = 0
	var scaledOffset: int = 0

	# X coord where the zoomed bitmap is clipped by the left edge of the screen
	var runBegin: int = 0

	var runLength: int = 0

	var rightOffset: int = 320 - leftOffset

	var vidOffset: int = 0

	var entry: int = 0    # 0: writeWhiteRun, 1: loc_147E5, 2: writeBlackRun
	if leftOffset < 0:
		# The zooming bitmap is clipped by the left edge of the screen, so find
		# out where we start drawing it
		runBegin = -leftOffset

		while true:
			if rleData >= introbuffer2.size():
				return    # (the C reads on past the buffer)
			inputOffset = _game_rd16(introbuffer2, rleData)
			rleData += 2
			scaledOffset = u16((inputOffset * scaleFactor) / 256)
			if scaledOffset > runBegin:
				entry = 0    # goto writeWhiteRun
				break

			inputOffset = _game_rd16(introbuffer2, rleData)
			rleData += 2
			scaledOffset = u16((inputOffset * scaleFactor) / 256)
			if scaledOffset > runBegin:
				entry = 2    # goto writeBlackRun
				break
	else:
		# loc_147C2: the zooming bitmap is not clipped by left edge of screen
		runBegin = 0
		rleData += 2
		vidOffset = leftOffset
		entry = 1    # goto loc_147E5

	while true:
		if entry == 0:
			# writeWhiteRun: writing a run of pixels
			runLength = s32(scaledOffset - runBegin)
			VL_ScreenRect(vidOffset, arg4, runLength, 1, 0xF)
			runBegin = scaledOffset
			vidOffset = s32(vidOffset + runLength)

			if scaledOffset > rightOffset:
				return
			entry = 1

		if entry == 1:
			# loc_147E5:
			inputOffset = _game_rd16(introbuffer2, rleData)
			rleData += 2
			scaledOffset = u16((inputOffset * scaleFactor) / 256)

		# writeBlackRun: writing a run of pixels
		runLength = s32(scaledOffset - runBegin)
		VL_ScreenRect(vidOffset, arg4, runLength, 1, 0x0)
		runBegin = scaledOffset
		vidOffset = s32(vidOffset + runLength)

		if scaledOffset > rightOffset:
			return

		inputOffset = _game_rd16(introbuffer2, rleData)
		rleData += 2
		if inputOffset != 0xFFFF:
			scaledOffset = u16((inputOffset * scaleFactor) / 256)
		else:
			break
		entry = 0

	# Write black until the end of the screen?
	runLength = s32(320 - vidOffset)
	VL_ScreenRect(vidOffset, arg4, runLength, 1, 0)


## The COMMANDER and KEEN RLE-encoded bitmaps are first joined together into
## one big RLE-encoded bitmap, which is then scaled and translated to its
## final position.
func ZoomOutTerminator() -> void:
	var startingLeftOffset: int = 0
	var yBottom: int = 0
	var scaledHeight: int = 0
	var var20: int = 0
	var var1C: int = 0
	var si: int = 0

	# The px offset of the left edge of the bitmap from the left edge of the screen
	var leftOffset: int = 0

	var elapsedTime: int = 0
	var maxTime: int = 0
	var var16: int = 0

	var newTime: int = 0
	var scaleFactor: int = 0
	var finalHeight: int = 0
	var varC: int = 0
	var varE: int = 0

	# Set the palette
	VL_SetPaletteFromArray(CK_VAR_GetIntArray("ck_terminatorPalette2"))

	# The starting (negative) offset of the COMMANDER graphic from the left edge of the screen
	startingLeftOffset = 120 - _game_rd16(ck_introCommander, 2)

	JoinTerminatorPics()

	scaleFactor = 256
	finalHeight = 33
	var20 = 200
	elapsedTime = 1
	maxTime = 30    # Set to large value to slow down the zoom

	while elapsedTime <= maxTime:
		if quitting:
			break

		if elapsedTime == maxTime:
			# We're done
			scaleFactor = finalHeight
			leftOffset = 0
			yBottom = 4
		else:
			scaleFactor = u16(256 - (((256 - finalHeight) * elapsedTime) / maxTime))

			leftOffset = (startingLeftOffset * (maxTime - elapsedTime)) / maxTime

			yBottom = (elapsedTime * 4) / maxTime

		if elapsedTime == maxTime:
			leftOffset = 0
		else:
			leftOffset = ((maxTime - elapsedTime) * startingLeftOffset) / maxTime

		scaledHeight = (200 * scaleFactor) >> 8
		varC = 0
		varE = u16(0x10000 / scaleFactor)

		if yBottom > 0:
			VL_ScreenRect(0, 0, 320, yBottom, 0)

		# Draw each line to the screen
		si = 0
		while si < ((200 * scaleFactor) >> 8):
			var16 = _game_rd16(introbuffer2, 4 + (varC >> 8) * 2)
			ZoomOutTerminator_1(var16, si + yBottom, leftOffset, scaleFactor)
			varC = u16(varC + varE)
			si += 1

		var1C = scaledHeight + yBottom
		if var20 > var1C:
			VL_ScreenRect(0, var1C, 320, var20 - var1C + 1, 0)
			var20 = var1C

		IN_PumpEvents()
		VL_UpdateRect(0, 0, 320, 200)
		VL_Present()

		newTime = u16(SD_GetTimeCount())
		SD_SetSpriteSync(newTime - SD_GetLastTimeCount())
		SD_SetLastTimeCount(newTime)
		if SD_GetSpriteSync() > 8:
			SD_SetSpriteSync(8)

		if elapsedTime == maxTime:
			break

		elapsedTime += SD_GetSpriteSync()

		if elapsedTime > maxTime:
			elapsedTime = maxTime

		if IN_GetLastScan() == IN_SC_F1:
			IN_SetLastScan(IN_SC_Space)

		if IN_GetLastScan() != 0:
			# return;// should this be break instead? Want to free intro buffers!
			break

	introbuffer2 = PackedByteArray()    # MM_FreePtr(&introbuffer2)


## The Fizzlefade routine: the title graphic drawn to a new surface, then
## copied from it to the screen pixel by pixel.
func CK_FizzleFade() -> void:
	var i: int = 0

	var columns1: PackedInt32Array = _game_int_array(320)
	var rows1: PackedInt32Array = _game_int_array(200)

	# Construct a multiplication table for multiples of
	for c: int in range(320):
		columns1[c] = c

	# Shuffle the table entries
	i = 0
	while i < 320:
		# NOTE: BCC rand() implementation is capped at 0x7FFF
		var var2: int = s16((320 * (rand() & 0x7FFF)) / 0x8000)

		var var4: int = columns1[var2]

		columns1[var2] = columns1[i]

		columns1[i] = var4
		i += 1

	for r: int in range(200):
		rows1[r] = columns1[r]

	VL_SetDefaultPalette()
	VL_FixRefreshBuffer()

	# VW_SetScreen(0, bufferofs_0);
	VL_SetScrollCoords(0, 0)

	# DOS: Draw Title Bitmap offscreen; SDL: Draw it to a new surface
	var titleBuffer: VL_Surface = VL_CreateSurface(320, 200)

	# FIXME: This is cached somewhere else
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_TITLESCREEN"))

	var dimensions: Dictionary = VH_GetBitmapTableEntry(CK_CHUNKNUM("PIC_TITLESCREEN") - int(ca_gfxInfoE.offBitmaps))

	VL_UnmaskedToSurface(ca_graphChunks[CK_CHUNKNUM("PIC_TITLESCREEN")], 0, titleBuffer, 0, 0, int(dimensions.width) * 8, int(dimensions.height))

	# Do the fizzling
	i = 0
	while i < 360:
		if quitting:
			return
		var var_10: int = s16(i - 160)

		if var_10 < 0:
			var_10 = 0

		var var_12: int = s16(i)

		if var_12 >= 200:
			var_12 = 199

		var y: int = var_10
		while y <= var_12:
			for _attempt: int in range(2):
				var x: int = columns1[rows1[y]]

				rows1[y] = u16(rows1[y] + 1)
				if rows1[y] == 320:
					rows1[y] = 0

				# We use VL_ScreenRect here instead of VL_SurfaceToScreen() because
				# the EGA backend requires VL_SurfaceToScreen()'s x coordinate be divisble by 8.
				var pixelValue: int = VL_SurfacePGet(titleBuffer, x, y)
				VL_ScreenRect(x, y, 1, 1, pixelValue)
				# Update the byte we modified if we're double-buffering.
				VL_UpdateRect(x & ~7, y, 8, 1)
			y += 1

		VL_FixRefreshBuffer()
		VL_Present()

		# VL_WaitVBL(1);
		VL_DelayTics(1)

		IN_PumpEvents()

		if IN_CheckAck() != 0:
			if IN_GetLastScan() == IN_SC_F1:
				IN_SetLastScan(IN_SC_Space)

		if IN_GetLastScan() != 0:
			VL_DestroySurface(titleBuffer)
			return
		i += 1

	# Title screen is now drawn, wait for a bit
	IN_UserInput(420, false)

	VL_DestroySurface(titleBuffer)


func CK_DrawTerminator() -> void:
	var cmdrWidthX100: int = 0

	var terminator_complete: bool = false
	VL_ResizeScreen(TERMINATORSCREENWIDTH * 8 + 64, 200)
	VL_ClearScreen(0)

	# Cache Intro Bitmaps
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_TITLESCREEN"))
	CA_CacheGrChunk(CK_CHUNKNUM("EXTERN_COMMANDER"))
	CA_CacheGrChunk(CK_CHUNKNUM("EXTERN_KEEN"))

	ck_introKeen = ca_graphChunks[CK_CHUNKNUM("EXTERN_KEEN")]
	ck_introCommander = ca_graphChunks[CK_CHUNKNUM("EXTERN_COMMANDER")]

	# Only writing to plane 0 of display memory
	VL_SetMapMask(1)

	# Because "KEEN" needs to end up on the right side of the screen, an extra
	# padding amount is added to the left side of the Keen graphic
	ck_introScreenWidth = _game_rd16(ck_introKeen, 2) + 25 * 8

	# Set the screen to the right of the "KEEN" graphic
	VL_SetScrollCoords(ck_introScreenWidth + 1, 0)

	# Copy each line of the KEEN graphic into video memory, accounting for the padding amount
	var destbuf: PackedByteArray = PackedByteArray()    # calloc: zeroed, and reused for every line
	destbuf.resize((ck_introScreenWidth + 7) / 8 + 1)
	for i: int in range(200):
		# Left margin of KEEN is 25*8 = 200 pixels
		# Omnispeak: RLE-Expand into temp buffer, then copy into video memory
		var keenptr: BytePtr = BytePtr.new(ck_introKeen, _game_rd16(ck_introKeen, 4 + i * 2))
		TerminatorExpandRLE(keenptr, BytePtr.new(destbuf, 25))
		VL_1bppToScreen_PM(destbuf, 0, 0, i, ck_introScreenWidth, 1, 0xF)
	# free(destbuf)

	VL_UpdateRect(0, 0, TERMINATORSCREENWIDTH * 8 + 64, 200)

	# Allocate memory for 8 shifts of the COMMANDER graphic. There are only 100
	# rows of memory: each EVEN row of source graphics is duplicated.

	# The most shifted version of the image will be shifted 7px, taking at most
	# one extra byte; round up, then up to the nearest 16-bit word.
	ck_introCommanderWidth = ((_game_rd16(ck_introCommander, 2) + 7) / 8) + 1
	ck_introCommanderWidth = (ck_introCommanderWidth + 1) & 0xFFFE

	cmdrWidthX100 = ck_introCommanderWidth * 100
	for i: int in range(8):
		# MM_GetPtr: malloc'd (uninitialised in C; zeroed here)
		var seg: PackedByteArray = PackedByteArray()
		seg.resize(cmdrWidthX100)
		shiftedCmdrBMPsegs[i] = seg

	ck_introKeen = ca_graphChunks[CK_CHUNKNUM("EXTERN_KEEN")]
	ck_introCommander = ca_graphChunks[CK_CHUNKNUM("EXTERN_COMMANDER")]

	# Decompress the RLE-encoded "Commander" bitmap.
	var cmdrLineStarts: PackedInt32Array = _game_int_array(200)
	for i: int in range(100):
		cmdrLineStarts[2 * i] = i * ck_introCommanderWidth
		cmdrLineStarts[2 * i + 1] = i * ck_introCommanderWidth

		var srcptr: BytePtr = BytePtr.new(ck_introCommander, _game_rd16(ck_introCommander, 4 + i * 2 * 2))
		var destptr: BytePtr = BytePtr.new(shiftedCmdrBMPsegs[0], cmdrLineStarts[2 * i])
		TerminatorExpandRLE(srcptr, destptr)

	# Looks like we're making 8 shifts of the "Commander" graphic
	for i: int in range(1, 8):
		var last: PackedByteArray = shiftedCmdrBMPsegs[i - 1]
		var next: PackedByteArray = shiftedCmdrBMPsegs[i]

		var c: int = 0
		for j: int in range(cmdrWidthX100):
			var d: int = last[j]
			next[j] = u8((d >> 1) | c)
			c = (d << 7)

	# Set the terminator palette
	VL_SetPaletteFromArray(CK_VAR_GetIntArray("ck_terminatorPalette1"))

	# Do the terminator
	ck_currentTerminatorCredit = 0
	ck_currentTermPicStartTime = 0
	ck_termCreditStage = -1
	AnimateTerminator()

	# Omnispeak
	VL_ResizeScreen(RF_BUFFER_WIDTH_TILES * 16, RF_BUFFER_HEIGHT_TILES * 16)

	VL_SetScrollCoords(0, 0)

	# After the terminator text has run, keys are checked
	if IN_GetLastScan() == 0:
		ZoomOutTerminator()

	if IN_GetLastScan() == 0:
		CK_FizzleFade()
		terminator_complete = true

	# Free the COMMANDER and KEEN bitmaps
	# MM_SetPurge(EXTERN_COMMANDER, 3); MM_SetPurge(EXTERN_KEEN, 3): memory only

	# Restore video mode to normal
	VL_ClearScreen(0)
	# OMNISPEAK: Because we draw the title screen to both pages, we need to
	# clear both pages, unlike in the original game.
	VL_UpdateRect(0, 0, 21 * 16, 14 * 16)
	# VW_SetLineWidth(0x40);
	VL_SetDefaultPalette()
	# RF_Reset();
	CA_ClearMarks()

	# Handle any keypresses
	if IN_GetLastScan() == 0:
		return

	# Go to help screen
	if ck_currentEpisode_ep != EP_CK6 and IN_GetLastScan() == IN_SC_F1:
		HelpScreens()
		return

	if not terminator_complete:
		# RF_Reset();

		# Display Title Screen
		CA_CacheGrChunk(CK_CHUNKNUM("PIC_TITLESCREEN"))
		VH_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_TITLESCREEN"))

		VL_SetScrollCoords(0, 0)
		# Instead of flipping to the backbuffer here, we update both.
		VL_UpdateRect(0, 0, 21 * 16, 14 * 16)
		VL_Present()
		IN_WaitButton()
		CA_ClearMarks()

		if ck_storeDemo:
			ck_gameState.levelState = LS_ResetGame
			ck_startingDifficulty = D_Normal
			IN_ClearKeysDown()
			CK_NewGame()
			return

	US_RunCards()
	if ck_startingDifficulty != 0:
		ck_gameState.levelState = LS_ResetGame
		return

	if ck_startingSavedGame != 0:
		ck_gameState.levelState = LS_LoadedGame


# Star Wars Story Text

var ck_storyText: String = ""

## The units of the Star Wars scroller: 1/2048 of a pixel.
const SWunitsPerPixel: int = 2048
const log2_SWunitsPerPixel: int = 11


static func CK_SWunitsToPixels(sw: int) -> int:
	return sw >> log2_SWunitsPerPixel


static func CK_PixelsToSWunits(px: int) -> int:
	return px << log2_SWunitsPerPixel


## A row-displacement when selecting a line of the master text image to draw,
## by row on the visible screen (skewed: the text bunches up at the top).
var ck_SWScreenRowToMasterRow: PackedInt32Array = _game_int_array(200)

## The distance (in SWunits) between two screen pixels in master pixel coordinates.
var ck_SWRowPixelDistance: PackedInt32Array = _game_int_array(200)

## The width of each row in screen pixels.
var ck_SWRowWidthInScreenPx: PackedInt32Array = _game_int_array(200)

## The total height of the master text, in master pixels.
var ck_starWarsTotalHeight: int = 0

## The master text screen for the Star Wars scroller.
var ck_starWarsTextSurface: VL_Surface = null


## This replaces CompileSWUpdate in Keen (BuildScalers in CKSRCMOD): the
## scaling parameters of each row.
func CK_PrepareSWUpdate() -> void:
	# This is the width of the trapezoid at the bottom of the screen.
	var trapezoidWidth: int = CK_PixelsToSWunits(320)

	# This is the change in width per scanline (the top of the screen will be ~40px).
	var delTrapWidth: int = 0xB33

	# The Y-coordinate of where the current screen row maps to on the master
	# SW text surface (in SWunits).
	var currentMasterRow: int = 0

	for row: int in range(199, -1, -1):
		# Width of the row in pixels, even.
		var rowWidth: int = CK_SWunitsToPixels(trapezoidWidth / 2) * 2

		ck_SWRowWidthInScreenPx[row] = u16(rowWidth)

		ck_SWScreenRowToMasterRow[row] = u16(CK_SWunitsToPixels(currentMasterRow))

		# The distance between successive pixels (in SWunits); also the distance
		# between this row and the one above it.
		var rowDistance: int = (CK_PixelsToSWunits(336) / rowWidth) & 0xFFFFFFFF

		ck_SWRowPixelDistance[row] = u16(rowDistance)

		currentMasterRow = (currentMasterRow + rowDistance) & 0xFFFFFFFF

		# Shrink the scale distance for the next line.
		trapezoidWidth = (trapezoidWidth - delTrapWidth) & 0xFFFFFFFF


## Converts a string from ASCII to Star Wars font indices. Returns the
## translation (the C writes it to `output`, unused here).
func CK_TranslateString(input: String, _output: String = "") -> String:
	var out: String = ""
	for k: int in range(input.length()):
		var c: int = input.unicode_at(k) & 0xFF
		if c >= 65 and c <= 90:
			c -= 33
		elif c >= 97 and c <= 122:
			c -= 39
		elif c == 46:    # '.'
			c = 0x54
		elif c == 44:    # ','
			c = 0x55
		elif c == 45:    # '-'
			c = 0x56
		elif c == 34:    # '"'
			c = 0x57
		elif c == 32:    # ' '
			c = 0x58
		elif c == 33:    # '!'
			c = 0x59
		elif c == 39:    # '\''
			c = 0x5A
		elif c != 10:
			c = 0x54
		out += char(c)
	return out


## This is PrintStarWars in CKSRCMOD: the story text printed to an offscreen
## buffer, whose rows are later scaled to make the trapezoidal text.
func CK_DrawSWText() -> void:
	var storyText: String = CK_STRING("ck_str_storyText")
	var storyTextIndex: int = 0

	# We want to render to a 336px wide texture.
	US_SetWindowX(0)
	US_SetWindowW(336)

	# We start from row 1, as row 0 is used as an empty row for rendering
	# otherwise out-of-bounds rows.
	US_SetPrintY(1)
	US_SetPrintColour(0xF)

	# TODO: Calculate the height of the text (1024 px is enough for the originals).
	ck_starWarsTextSurface = VL_CreateSurface(336, 1024)

	# We want to render to this offscreen buffer.
	var oldScreen: VL_Surface = VL_SetScreen(ck_starWarsTextSurface)
	VL_ClearScreen(0)

	# More than a screen-height of text: print unbuffered (not US_CPrint's default VHB_ routine).
	US_SetPrintRoutines(&"", &"VH_DrawPropString")

	while storyTextIndex < storyText.length():
		if quitting:
			break
		var currentTextLine: String = ""
		var ch: int = 0

		# Extract one line of text (with its newline).
		while true:
			ch = storyText.unicode_at(storyTextIndex) if storyTextIndex < storyText.length() else 0
			if ch != 0:
				currentTextLine += char(ch)
				storyTextIndex += 1
			if not (ch != 0 and ch != 10):
				break

		# Translate from ASCII to SW font indices.
		currentTextLine = CK_TranslateString(currentTextLine, currentTextLine)

		# And print it centered in its line.
		US_CPrint(currentTextLine)

	# Save off the total height of the scroller.
	ck_starWarsTotalHeight = US_GetPrintY()
	US_SetPrintY(0)
	US_SetPrintRoutines(&"", &"")

	# Restore the screen.
	VL_SetScreen(oldScreen)


## This is StarWarsLoop in CKSRCMOD.
func CK_ScrollSWText() -> void:
	SD_SetLastTimeCount(0)
	SD_SetTimeCount(0)
	SD_SetSpriteSync(0)
	# We draw the text on plane 4.
	VL_SetMapMask(8)

	var scrollDistance: int = 0    # uint16_t
	VL_SwapOnNextPresent()
	VL_Present()
	VL_FixRefreshBuffer()

	while scrollDistance <= ck_starWarsTotalHeight + 400:
		if quitting:
			return
		# Update rows from the bottom.
		for row: int in range(199, -1, -1):
			var masterRowToDraw: int = scrollDistance - ck_SWScreenRowToMasterRow[row]

			# If it's out of range, set it to our reserved blank row 0.
			if masterRowToDraw < 0 or masterRowToDraw >= ck_starWarsTotalHeight:
				masterRowToDraw = 0

			var rowStart: int = 160 - ck_SWRowWidthInScreenPx[row] / 2
			var rowEnd: int = 160 + ck_SWRowWidthInScreenPx[row] / 2

			# The x-coordinate of the current pixel in the offscreen text buffer, in SWunits.
			var masterX: int = 0

			# For each screen pixel: the master pixel, read and masked to the screen in plane 4.
			for screenX: int in range(rowStart, rowEnd):
				var masterPixelX: int = CK_SWunitsToPixels(masterX)
				var pixelValue: int = VL_SurfacePGet(ck_starWarsTextSurface, masterPixelX, masterRowToDraw)

				VL_ScreenRect_PM(screenX, row, 1, 1, pixelValue)
				masterX += ck_SWRowPixelDistance[row]

		IN_PumpEvents()
		VL_SwapOnNextPresent()
		VL_Present()

		var newTime: int = SD_GetTimeCount()    # uint32_t
		SD_SetSpriteSync(SD_GetSpriteSync() + newTime - SD_GetLastTimeCount())
		SD_SetLastTimeCount(newTime)

		if SD_GetSpriteSync() > 20:
			SD_SetSpriteSync(20)

		scrollDistance = u16(scrollDistance + SD_GetSpriteSync() / 4)
		SD_SetSpriteSync(SD_GetSpriteSync() % 4)

		if IN_CheckAck() != 0 and IN_GetLastScan() != IN_SC_F1:
			IN_SetLastScan(IN_SC_Space)

		if IN_GetLastScan() != 0:
			return


func CK_DrawStarWars() -> void:
	# Keen5 sets the palette to the default one here.
	VL_ClearScreen(0)
	VL_SetScrollCoords(0, 0)

	CA_SetGrPurge()
	# Cache and set the Star Wars font.
	CA_CacheGrChunk(5)
	US_SetPrintFont(2)
	# Render out the story text (to an offscreen buffer)
	CK_DrawSWText()
	# Restore the font.
	US_SetPrintFont(0)

	CA_CacheGrChunk(CK_CHUNKNUM("PIC_STARWARS"))    # Story bkg image.

	# Keen draws this to a separate surface, for fast copies.
	VH_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_STARWARS"))

	VL_SetPaletteFromArray(CK_VAR_GetIntArray("ck_starWarsPalette"))

	# Keen builds machine-code scalers here (BuildScalers/CompileSWUpdate);
	# instead, we just precalculate the various scaling factors.
	CK_PrepareSWUpdate()

	# ...and scroll the text!
	if IN_GetLastScan() == 0:
		StartMusic(CK_INT("CK_StarWarsMusicLevel", 0))
		CK_ScrollSWText()
		StopMusic()

	VL_DestroySurface(ck_starWarsTextSurface)

	VL_ClearScreen(0)
	VL_SetScrollCoords(0, 0)
	VL_SetDefaultPalette()
	CA_ClearMarks()

	CK_HandleDemoKeys()


func CK_ShowTitleScreen() -> void:
	# scrollofs = 0;
	CA_CacheGrChunk(CK_CHUNKNUM("PIC_TITLESCREEN"))
	VH_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_TITLESCREEN"))
	# VW_SetScreen(0,bufferofs_0);
	VL_SetScrollCoords(0, 0)
	VL_UpdateRect(0, 0, 42 * 8, 224)
	VL_Present()
	IN_UserInput(420, false)
	CA_ClearMarks()
	CK_HandleDemoKeys()
	VL_Present()


# TODO: Add some demo number stuff

func CK_PlayDemoFile(demoName: String) -> void:
	CK_NewGame()

	var demoBuf: PackedByteArray = CA_LoadFile(demoName)
	if demoBuf.size() < 4:
		# The C doesn't check CA_LoadFile and reads through a NULL pointer
		Quit("CK_PlayDemoFile: couldn't load %s" % demoName)
		return

	var demoMap: int = demoBuf[0]    # *demoBuf: one byte
	var demoLen: int = GalData.u16(demoBuf, 2)

	ck_gameState.currentLevel = s16(demoMap)

	IN_DemoStartPlaying(demoBuf, 4, demoLen)

	CK_LoadLevel(true, false)

	CK_PlayLoop()

	# MM_FreePtr((void **)&demoBuf)


func CK_PlayDemo(demoNumber: int) -> void:
	var demoChunk: int = CK_CHUNKNUM("DEMOSTART") + demoNumber

	CK_NewGame()

	CA_CacheGrChunk(demoChunk)
	var demoBuf: PackedByteArray = ca_graphChunks[demoChunk]
	# MM_SetLock(&ca_graphChunks[demoChunk], true): memory only

	var demoMap: int = demoBuf[0]    # uint16_t demoMap = *demoBuf: one byte (demoBuf is uint8_t *)
	var demoLen: int = GalData.u16(demoBuf, 2)

	ck_gameState.currentLevel = s16(demoMap)

	IN_DemoStartPlaying(demoBuf, 4, demoLen)

	CK_LoadLevel(true, false)

	if ck_inHighScores:
		CK_OverlayHighScores()

	CK_PlayLoop()
	IN_DemoStopPlaying()

	# We have to get rid of the demo buffer, as if we want to play it again,
	# we need a fresh copy. ID_IN modifies the buffer.
	ca_graphChunks[demoChunk] = null    # MM_FreePtr(&ca_graphChunks[demoChunk])
	VL_FixRefreshBuffer()
	CA_ClearMarks()

	# What should we do after playing the demo?
	CK_HandleDemoKeys()


# High scores (ck_highScores: gal_us.gd declares it; its C initialiser is in _init)

func CK_SetDefaultHighScores() -> void:
	var names: PackedStringArray = CK_VAR_GetStringArray("ck_defaultHighScoreNames")
	var scores: PackedInt32Array = CK_VAR_GetIntArray("ck_defaultHighScores")
	var args: PackedInt32Array = CK_VAR_GetIntArray("ck_defaultHighScoreArgs")

	for i: int in range(8):
		# TODO: Work out a way to bounds-check these in debug mode.
		# (an absent array is the C's NULL; an index past a short one is skipped here)
		var hs: CK_HighScore = ck_highScores[i]
		if names.size() > 0 and i < names.size():
			hs.name = names[i].substr(0, 58)    # strncpy into char[58]
		if scores.size() > 0 and i < scores.size():
			hs.score = scores[i] & 0xFFFFFFFF
		if args.size() > 0 and i < args.size():
			hs.arg4 = u16(args[i])


## Draw the high scores overtop the level.
func CK_OverlayHighScores() -> void:
	# Omnispeak
	var topMargin: int = CK_INT("CK_highScoreTopMargin", 0)
	var rightMargin: int = CK_INT("CK_highScoreRightMargin", 0)
	var leftMargin: int = CK_INT("CK_highScoreLeftMargin", 0)

	RF_Reposition(0, 0)

	# DOS: Set the back buffer to the master tilebuffer (the print routines
	# draw to the backbuffer). Omnispeak: the tilebuffer surface replaces the
	# screen surface.
	var screen: VL_Surface = VL_SetScreen(rf_tileBuffer)

	US_SetPrintRoutines(&"", &"VH_DrawPropString")

	US_SetPrintColour(CK_INT("CK_highScoreFontColour", 15))

	for entry: int in range(8):
		var hs: CK_HighScore = ck_highScores[entry]
		# Print the name
		US_SetPrintY(16 * entry + topMargin)
		US_SetPrintX(leftMargin)
		US_Print(hs.name)

		# Keen 4: print the councilmembers rescued
		if ck_currentEpisode_ep == EP_CK4:
			US_SetPrintX(0x98)
			for i: int in range(hs.arg4):
				VH_DrawTile8(US_GetPrintX(), US_GetPrintY() + 1, 0x47)
				US_SetPrintX(US_GetPrintX() + 8)

		# Print the score, right aligned in the second column of the table
		# (sprintf "%d" of the uint32_t score: read as a signed int)
		var digits: String = str(s32(hs.score))

		# Convert it to high score numbers
		var buf: String = ""
		for k: int in range(digits.length()):
			buf += char(u8(digits.unicode_at(k) + 0x51))

		# Align it
		var wh: PackedInt32Array = VH_MeasurePropString(buf, US_GetPrintFont())
		US_SetPrintX(rightMargin - wh[0])
		US_Print(buf)

	US_SetPrintRoutines(&"", &"")
	US_SetPrintColour(15)

	# restore the backbuffer
	VL_SetScreen(screen)


var ck_highScoresDirty: bool = false    # static


## Enter name if a high score has been achieved.
func CK_SubmitHighScore(score: int, arg_4: int) -> void:
	arg_4 = u16(arg_4)
	# Omnispeak
	var topMargin: int = CK_INT("CK_highScoreTopMargin", 0)
	var leftMargin: int = CK_INT("CK_highScoreLeftMargin", 0)

	var entry: int = 0
	var entryRank: int = 0

	var newHighScore: CK_HighScore = CK_HighScore.new()
	newHighScore.name = ""
	newHighScore.score = score & 0xFFFFFFFF    # uint32_t
	newHighScore.arg4 = arg_4

	# Check if this entry made the high scores
	entryRank = -1
	entry = 0
	while entry < 8:
		var hs: CK_HighScore = ck_highScores[entry]
		if hs.score >= newHighScore.score:
			entry += 1
			continue

		if newHighScore.score == hs.score:
			if hs.arg4 >= newHighScore.arg4:
				entry += 1
				continue

		# Made it in! Insert the new high score into the proper slot
		var e: int = 8
		while true:
			e -= 1
			if not (e > entry):
				break
			(ck_highScores[e] as CK_HighScore).copy_from(ck_highScores[e - 1])

		(ck_highScores[entry] as CK_HighScore).copy_from(newHighScore)
		entryRank = entry
		ck_highScoresDirty = true

		break

	if entryRank != -1:
		ck_inHighScores = true
		ck_gameState.currentLevel = s16(CK_INT("CK_highScoreLevel", 1))
		CK_LoadLevel(true, false)
		CK_OverlayHighScores()
		US_SetPrintColour(CK_INT("CK_highScoreFontColour", 15))

		# FIXME: Calling these causes segfault
		RF_Refresh()
		RF_Refresh()

		US_SetPrintY(entry * 16 + topMargin)
		US_SetPrintX(leftMargin)

		# US_LineInput(x, y, buf = the entry's name, def = NULL, escok, maxchars, maxwidth)
		var typed: Array = US_LineInput(US_GetPrintX(), US_GetPrintY(), "", true, 0x39, 0x70)
		(ck_highScores[entryRank] as CK_HighScore).name = typed[1]

		ck_inHighScores = false

	US_SetPrintColour(15)


## Play the high score level.
func CK_DoHighScores() -> void:
	ck_inHighScores = true
	IN_ClearKeysDown()
	CK_PlayDemo(4)
	ck_inHighScores = false


# ===================================================================== ck_quit.c
# (Quit: gal_lib.gd)


## Quit with a printf-style message: `args` are the C's varargs.
func QuitF(msg: String, args: Array = []) -> void:
	var msg_buf: String = (msg % args) if args.size() > 0 else msg
	Quit(msg_buf.substr(0, 511))    # vsnprintf into char[512]


# ---- id_* functions the library lacks (move to the library)

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


## id_ca.c: MM_SetLock on the chunk, a memory matter the port does not have.
func CA_LockGrChunk(_chunk: int) -> void:
	pass


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


## id_ca.c: a map from an Abiathar .aslev file. CA_LoadFile fails without a
## file system, so this ends at the C's "Couldn't load" Quit (the LZW and
## RLEW unpacking past it is not reachable here).
func CA_CacheMapFromASLEV(mapIndex: int, fname: String) -> void:
	# Unload the previous map.
	for plane: int in range(CA_NUMMAPPLANES):
		CA_mapPlanes[plane] = PackedInt32Array()    # MM_FreePtr

	ca_mapOn = mapIndex

	var aslevFile: PackedByteArray = CA_LoadFile(fname)
	if aslevFile.is_empty():
		QuitF("Couldn't load map file %s\n", [fname])
		return


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


## id_mm.c: frees the memory manager's blocks; the port has none.
func MM_Shutdown() -> void:
	pass


# ---- C library functions the port lacks

## rand()'s state (the C library's, seeded 1 as an unseeded rand() is).
var rand_seed: int = 1


## rand(): Borland C's (the original's compiler, as CK_FizzleFade's note says):
## seed = seed * 0x015A4E35 + 1, the result bits 16-30.
func rand() -> int:
	rand_seed = (rand_seed * 0x015A4E35 + 1) & 0xFFFFFFFF
	return (rand_seed >> 16) & 0x7FFF
