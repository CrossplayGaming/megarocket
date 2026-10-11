# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's main, demo and play code (kd_main.c, kd_demo.c, kd_play.c) as carried in ReflectionHLE, (C) 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
# Also the parts of soft.c, lzhuf.c and jam_io.c the title picture needs (the LZH decoder itself
# is SoftLib's, softlib.gd), and ReflectionHLE's start-up sequence (be_gamedefs_kdreams.h's
# patchers, be_startup.c) as kd_main_entry.
class_name DrmGame
extends DrmUS
## kd_main.c, kd_demo.c, kd_play.c: start-up, the demo loop, the game loop and the actor engine.
## EGA releases v1.00 and v1.93 only: the 2015 release's, CGA's, E113's and E120's branches,
## ReflectionHLE's alternative controllers and key binds, the KeenLauncher hooks (KL_*) and the
## FRILLS code (DebugMemory, TestSprites, TEDDeath: FRILLS is 0) are left out. The C's Quit never
## returns: here it flags `quitting`, every loop stops on it, and kd_main_entry runs the rest of
## Quit (ShutdownId, the message on the text screen) once, where the program would have ended.
## Objects are the objtype instances of `objarray` (index = the C's pointer arithmetic); a map
## plane is a PackedInt32Array of words; reads past a map or table are guarded (0), not
## reproduced.

# ===================================================================== kd_main.c

const EntryParmStrings: PackedStringArray = ["detour", ""]


## DebugKeys: the F10 debug keys. Returns 1 if one was handled.
func DebugKeys() -> int:
	var esc: bool
	var level: int

	if Keyboard[0x22] and ingame:    # G = god mode
		VW_FixRefreshBuffer()
		US_CenterWindow(12, 2)
		if godmode:
			US_PrintCentered("God mode OFF")
		else:
			US_PrintCentered("God mode ON")
		VW_UpdateScreen()
		IN_Ack()
		godmode = not godmode
		return 1
	elif Keyboard[0x17]:    # I = item cheat
		VW_FixRefreshBuffer()
		US_CenterWindow(12, 3)
		US_PrintCentered("Free items!")
		gamestate.boobusbombs = 99
		gamestate.flowerpowers = 99
		gamestate.keys = 99
		VW_UpdateScreen()
		IN_Ack()
		return 1
	elif Keyboard[0x24]:    # J = jump cheat
		jumpcheat = not jumpcheat
		VW_FixRefreshBuffer()
		US_CenterWindow(18, 3)
		if jumpcheat:
			US_PrintCentered("Jump cheat ON")
		else:
			US_PrintCentered("Jump cheat OFF")
		VW_UpdateScreen()
		IN_Ack()
		return 1
	elif Keyboard[0x19]:    # P = pause with no screen disruptioon
		IN_Ack()
	elif Keyboard[0x1f] and ingame:    # S = slow motion
		singlestep = not singlestep
		VW_FixRefreshBuffer()
		US_CenterWindow(18, 3)
		if singlestep:
			US_PrintCentered("Slow motion ON")
		else:
			US_PrintCentered("Slow motion OFF")
		VW_UpdateScreen()
		IN_Ack()
		return 1
	elif Keyboard[0x11] and ingame:    # W = warp to level
		VW_FixRefreshBuffer()
		US_CenterWindow(26, 3)
		PrintY = u16(PrintY + 6)
		US_Print("  Warp to which level(0-16):")
		VW_UpdateScreen()
		var buf: PackedByteArray = _bytes_of(str, 80)    # char str[80]
		esc = not US_LineInput(px, py, buf, null, true, 2, 0)
		str = _cstring(buf)
		if not esc:
			level = _atoi(str)
			if level >= 0 and level <= 16:
				gamestate.mapon = level
				playstate = warptolevel
		return 1
	return 0


## C's atoi (16-bit int).
static func _atoi(s: String) -> int:
	var i: int = 0
	while i < s.length() and (s[i] == " " or s[i] == "\t"):
		i += 1
	var neg: bool = false
	if i < s.length() and (s[i] == "-" or s[i] == "+"):
		neg = s[i] == "-"
		i += 1
	var v: int = 0
	while i < s.length() and s.unicode_at(i) >= 48 and s.unicode_at(i) <= 57:
		v = v * 10 + s.unicode_at(i) - 48
		i += 1
	return s16(-v if neg else v)


## Shuts down all ID_?? managers.
func ShutdownId() -> void:
	US_Shutdown()
	SD_Shutdown()
	IN_Shutdown()
	RF_Shutdown()
	VW_Shutdown()
	CA_Shutdown()
	MM_Shutdown()


## The C's Quit after its first line: what the program does as it ends (the port's Quit, DrmDecl's,
## only flags it; kd_main_entry runs this once the callers have unwound).
func _Quit_kd_main(error: String) -> void:
	ShutdownId()
	if error != "":
		if current_gamever_int != 100:
			BE_ST_clrscr()
		BE_ST_puts(error)
		if current_gamever_int != 100:
			BE_ST_puts("\n")
		BE_ST_HandleExit(1)
		return
	BE_ST_HandleExit(0)


## Load a few things right away.
func InitGame() -> void:
	MM_Startup()

	if current_gamever_int == 100 and not kl_active():    # (kl_verify.c: the harness skips it)
		# Handle piracy screen...
		var screen: PackedByteArray = BE_ST_GetTextModeMemoryPtr()
		for k: int in range(mini(4000, PIRACY.size())):
			screen[(displayofs + k) & 0x7FFF] = PIRACY[k]
		BE_ST_MarkGfxForUpdate()
		while BE_ST_BiosScanCode(0) != sc_Return and not quitting:
			BE_ST_ShortSleep()
		if quitting:
			return

	if GRMODE == EGAGR:
		if mminfo.mainmem < 335 * 1024:
			BE_ST_clrscr()    # we can't include CONIO because of a name conflict
			BE_ST_puts("There is not enough memory available to play the game reliably.  You can")
			BE_ST_puts("play anyway, but an out of memory condition will eventually pop up.  The")
			BE_ST_puts("correct solution is to unload some TSRs or rename your CONFIG.SYS and")
			BE_ST_puts("AUTOEXEC.BAT to free up more memory.\n")
			BE_ST_puts("Do you want to (Q)uit, or (C)ontinue?")
			var i: int = BE_ST_BiosScanCode(0)
			if i != sc_C:
				Quit("")
				return

	US_TextScreen()

	VW_Startup()
	RF_Startup()
	IN_Startup()
	SD_Startup()
	US_Startup()

	if current_gamever_int == 100:
		US_UpdateTextScreen()

	CA_Startup()
	US_Setup()
	if quitting:
		return

	# load in and lock down some basic chunks

	CA_ClearMarks()

	grneeded[STARTFONT] |= ca_levelbit    # CA_MarkGrChunk
	grneeded[STARTFONTM] |= ca_levelbit
	grneeded[STARTTILE8] |= ca_levelbit
	grneeded[STARTTILE8M] |= ca_levelbit
	for i: int in range(KEEN_LUMP_START, KEEN_LUMP_END + 1):
		grneeded[i] |= ca_levelbit

	# (REFKEEN) one argument in v1.00, the second ignored
	CA_CacheMarks("", false)
	if quitting:
		return

	MM_SetLock("gr:%d" % STARTFONT, true)
	MM_SetLock("gr:%d" % STARTFONTM, true)
	MM_SetLock("gr:%d" % STARTTILE8, true)
	MM_SetLock("gr:%d" % STARTTILE8M, true)
	for i: int in range(KEEN_LUMP_START, KEEN_LUMP_END + 1):
		MM_SetLock("gr:%d" % i, true)

	CA_LoadAllSounds()

	fontcolor = WHITE

	US_FinishTextScreen()

	VW_SetScreenMode(GRMODE)
	VW_ClearVideo(BLACK)


## The original starting point of the game EXE.
func kdreams_exe_main() -> void:
	# (the port's id0_argv has no program name: the C's id0_argv[1] is the first entry; ReflectionHLE
	# passes "" for a missing one)
	var arg1: String = id0_argv[0] if id0_argv.size() > 0 else ""
	if refkeen_current_gamever == BE_GAMEVER_KDREAMSE193:
		if arg1.to_upper() == "/VER":
			BE_ST_printf("\nKeen Dreams version 1.93  (Rev 1)\n")
			BE_ST_printf("developed for use with 100% IBM compatibles\n")
			BE_ST_printf("that have 640K memory, DOS version 3.3 or later,\n")
			BE_ST_printf("and an EGA or VGA display adapter.\n")
			BE_ST_printf("Copyright 1991-1993 Softdisk Publishing.\n")
			BE_ST_printf("Commander Keen is a trademark of Id Software.\n")
			BE_ST_HandleExit(0)
			return

		if arg1.to_upper() == "/?":
			BE_ST_printf("\nKeen Dreams version 1.93\n")
			BE_ST_printf("Copyright 1991-1993 Softdisk Publishing.\n\n")
			BE_ST_printf("Commander Keen is a trademark of Id Software.\n")
			BE_ST_printf("Type KDREAMS from the DOS prompt to run.\n\n")
			BE_ST_printf("KDREAMS /COMP for SVGA compatibility mode\n")
			BE_ST_printf("KDREAMS /NODR stops program hang with the drive still on\n")
			BE_ST_printf("KDREAMS /NOAL disables AdLib and Sound Blaster detection\n")
			BE_ST_printf("KDREAMS /NOSB disables Sound Blaster detection\n")
			BE_ST_printf("KDREAMS /NOJOYS ignores joystick\n")
			BE_ST_printf("KDREAMS /NOMOUSE ignores mouse\n")
			BE_ST_printf("KDREAMS /HIDDENCARD overrides video card detection\n")
			BE_ST_printf("KDREAMS /VER  for version and compatibility information\n")
			BE_ST_printf("KDREAMS /? for this help information\n")
			BE_ST_HandleExit(0)
			return

		BE_ST_textcolor(7)
		BE_ST_textbackground(0)

	InitGame()
	if quitting:
		return

	call(DemoLoop)    # DemoLoop calls Quit when everything is done
	Quit("Demo loop exited???")


# ===================================================================== kd_demo.c

const RLETAG: int = 0xABCD


## Set up new game to start from the beginning.
func NewGame() -> void:
	gamestate.worldx = 0    # spawn keen at starting spot

	gamestate.mapon = 0
	gamestate.score = 0
	gamestate.nextextra = 20000
	gamestate.lives = 3
	gamestate.boobusbombs = 0
	gamestate.flowerpowers = 0
	# (REFKEEN) gamestate.keys is not reset: a vanilla bug, kept (the 2015 release fixed it)
	for i: int in range(GAMELEVELS):
		gamestate.leveldone[i] = false


func GameOver() -> void:
	VW_InitDoubleBuffer()
	US_CenterWindow(16, 3)

	US_PrintCentered("Game Over!")

	VW_UpdateScreen()
	IN_ClearKeysDown()
	IN_Ack()


func StatusWindow() -> void:
	var x: int

	# DEBUG - make this look better

	US_CenterWindow(22, 7)
	US_CPrint("Status Window")

	WindowX = u16(WindowX + 8)
	WindowW = u16(WindowW - 8)
	WindowY = u16(WindowY + 20)
	WindowH = u16(WindowH - 20)
	PrintX = WindowX
	PrintY = WindowY

	VWB_DrawTile8(PrintX, PrintY, 26)
	VWB_DrawTile8(PrintX + 8, PrintY, 27)
	PrintX = u16(PrintX + 24)
	US_PrintUnsigned(gamestate.lives)
	US_Print("\n")

	VWB_DrawTile8(PrintX, PrintY, 32)
	VWB_DrawTile8(PrintX + 8, PrintY, 33)
	VWB_DrawTile8(PrintX, PrintY + 8, 34)
	VWB_DrawTile8(PrintX + 8, PrintY + 8, 35)
	PrintX = u16(PrintX + 24)
	US_PrintUnsigned(gamestate.boobusbombs)
	US_Print("\n")

	WindowX = u16(WindowX + 50)
	WindowW = u16(WindowW - 50)
	PrintX = WindowX
	PrintY = WindowY

	fontcolor = F_FIRSTCOLOR
	US_Print("Next ")
	fontcolor = F_BLACK
	x = PrintX
	VWB_DrawTile8(PrintX, PrintY, 26)
	VWB_DrawTile8(PrintX + 8, PrintY, 27)
	PrintX = u16(PrintX + 24)
	US_PrintUnsigned(gamestate.nextextra)
	US_Print("\n")

	PrintX = x
	VWB_DrawTile8(PrintX, PrintY, 24)
	VWB_DrawTile8(PrintX + 8, PrintY, 25)
	PrintX = u16(PrintX + 24)
	US_PrintUnsigned(gamestate.keys)
	US_Print("\n")

	# DEBUG - add flower powers (#36)

	VW_UpdateScreen()
	IN_Ack()


## (REFKEEN) objtype's fields as a saved game holds them, 16 bits each, in order: [field, signed].
## "<dos>" is the state's 16-bit pointer, "<next>" whether next is set, "<dummy>" a placeholder.
const SAVEOBJECT_FIELDS: Array = [
	["obclass", false], ["active", false], ["needtoreact", false], ["needtoclip", false],
	["nothink", false], ["x", false], ["y", false], ["xdir", true], ["ydir", true],
	["xmove", true], ["ymove", true], ["xspeed", true], ["yspeed", true],
	["ticcount", true], ["ticadjust", true], ["<dos>", false], ["shapenum", false],
	["left", false], ["top", false], ["right", false], ["bottom", false], ["midx", false],
	["tileleft", false], ["tiletop", false], ["tileright", false], ["tilebottom", false],
	["tilemidx", false], ["hitnorth", true], ["hiteast", true], ["hitsouth", true], ["hitwest", true],
	["temp1", true], ["temp2", true], ["temp3", true], ["temp4", true],
	["<dummy>", true], ["<next>", true], ["<dummy>", true],
]


## (REFKEEN) Writes an object field by field (sprite and prev as dummies, next as set or not).
func SaveObject(file: BE_FILE_T, o: objtype) -> bool:
	# BACKWARDS COMPATIBILITY
	var statedosoffset: int = o.state.compatdospointer if o.state != null else 0
	for f: Array in SAVEOBJECT_FIELDS:
		var v: int
		match f[0]:
			"<dos>":
				v = statedosoffset
			"<next>":
				v = 1 if o.next != null else 0
			"<dummy>":
				v = 0
			"needtoreact", "needtoclip":
				v = 1 if o.get(f[0]) else 0
			_:
				v = int(o.get(f[0]))
		if BE_Cross_writeInt16LE(file, v) != 2:
			return false
	return true


## (REFKEEN) Reads an object field by field; the state from its 16-bit pointer, next set to the
## object itself if it was set (all LoadGame needs to know).
func LoadObject(file: BE_FILE_T, o: objtype) -> bool:
	var statedosoffset: int = 0
	var isnext: int = 0
	var dummy: int = 0
	for f: Array in SAVEOBJECT_FIELDS:
		var name: String = f[0]
		match name:
			"<dos>":
				var r: Array = BE_Cross_readInt16LE(file, statedosoffset)
				statedosoffset = r[1]
				if r[0] != 2:
					return false
			"<next>":
				var r: Array = BE_Cross_readInt16LE(file, isnext)
				isnext = s16(r[1])
				if r[0] != 2:
					return false
			"<dummy>":
				var r: Array = BE_Cross_readInt16LE(file, dummy)
				dummy = s16(r[1])
				if r[0] != 2:
					return false
			"needtoreact", "needtoclip":
				var r: Array = BE_Cross_read_boolean_From16LE(file, o.get(name))
				o.set(name, r[1])
				if r[0] != 2:
					return false
			_:
				var r: Array = BE_Cross_readInt16LE(file, int(o.get(name)))
				o.set(name, s16(r[1]) if f[1] else u16(r[1]))
				if r[0] != 2:
					return false

	o.state = RefKeen_GetObjStatePtrFromDOSPointer(statedosoffset)
	# ANOTHER SPECIAL CASE (for almost all creatures as flowers)
	o.temp2stateptr = RefKeen_GetObjStatePtrFromDOSPointer(u16(o.temp2))
	# HACK: All we need to know is if next was originally NULL or not
	o.next = o if isnext else null
	return true


## (REFKEEN) The game state, field by field (leveldone as 16-bit booleans).
func SaveGameState(file: BE_FILE_T, state: gametype) -> bool:
	return (BE_Cross_writeInt16LE(file, state.worldx) == 2
		and BE_Cross_writeInt16LE(file, state.worldy) == 2
		and BE_Cross_write_booleans_To16LEBuffer(file, state.leveldone, 2 * GAMELEVELS) == 2 * GAMELEVELS
		and BE_Cross_writeInt32LE(file, state.score) == 4
		and BE_Cross_writeInt32LE(file, state.nextextra) == 4
		and BE_Cross_writeInt16LE(file, state.flowerpowers) == 2
		and BE_Cross_writeInt16LE(file, state.boobusbombs) == 2
		and BE_Cross_writeInt16LE(file, state.bombsthislevel) == 2
		and BE_Cross_writeInt16LE(file, state.keys) == 2
		and BE_Cross_writeInt16LE(file, state.mapon) == 2
		and BE_Cross_writeInt16LE(file, state.lives) == 2
		and BE_Cross_writeInt16LE(file, state.difficulty) == 2)


func LoadGameState(file: BE_FILE_T, state: gametype) -> bool:
	var r: Array = BE_Cross_readInt16LE(file, state.worldx)
	state.worldx = u16(r[1])
	if r[0] != 2:
		return false
	r = BE_Cross_readInt16LE(file, state.worldy)
	state.worldy = u16(r[1])
	if r[0] != 2:
		return false
	if BE_Cross_read_booleans_From16LEBuffer(file, state.leveldone, 2 * GAMELEVELS) != 2 * GAMELEVELS:
		return false
	r = BE_Cross_readInt32LE(file, state.score)
	state.score = s32(r[1])
	if r[0] != 4:
		return false
	r = BE_Cross_readInt32LE(file, state.nextextra)
	state.nextextra = s32(r[1])
	if r[0] != 4:
		return false
	for name: String in ["flowerpowers", "boobusbombs", "bombsthislevel", "keys", "mapon", "lives", "difficulty"]:
		r = BE_Cross_readInt16LE(file, int(state.get(name)))
		state.set(name, s16(r[1]))
		if r[0] != 2:
			return false
	return true


func SaveGame(file: BE_FILE_T) -> bool:
	# (REFKEEN) Writing fields one-by-one in a cross-platform manner
	if not SaveGameState(file, gamestate):
		return false

	var expanded: int = u16(mapwidth * mapheight * 2)
	MM_GetPtr("kd:bigbuffer", expanded)

	for i: int in range(3):    # Write all three planes of the map
		# leave a word at start of compressed data for compressed length
		var dest: PackedInt32Array = PackedInt32Array()
		var compressed: int = u16(CA_RLEWCompress(mapsegs[i], expanded, dest, RLETAG))
		var bigbuffer: PackedInt32Array = PackedInt32Array([compressed])
		bigbuffer.append_array(dest)

		if BE_Cross_writeInt16LEBuffer(file, bigbuffer, compressed + 2) != u16(compressed + 2):
			MM_FreePtr("kd:bigbuffer")
			return false

	var o: objtype = player
	while o != null:
		# (REFKEEN) Writing fields one-by-one in a cross-platform manner
		if not SaveObject(file, o):
			MM_FreePtr("kd:bigbuffer")
			return false
		o = o.next

	MM_FreePtr("kd:bigbuffer")
	return true


func LoadGame(file: BE_FILE_T) -> bool:
	var prev: objtype
	var next: objtype
	var followed: objtype

	# (REFKEEN) Reading fields one-by-one in a cross-platform manner
	if not LoadGameState(file, gamestate):
		return false

	# drop down a cache level and mark everything, so when the option screen
	# is exited it will be cached

	ca_levelbit >>= 1
	ca_levelnum -= 1

	SetupGameLevel(false)    # load in and cache the base old level
	if quitting:
		return false
	titleptr[ca_levelnum] = levelnames[mapon]

	ca_levelbit = (ca_levelbit << 1) & 0xFF
	ca_levelnum += 1

	var expanded: int = u16(mapwidth * mapheight * 2)
	MM_GetPtr("kd:bigbuffer", expanded)

	for i: int in range(3):    # Read all three planes of the map
		var r: Array = BE_Cross_readInt16LE(file, 0)
		var compressed: int = r[1]
		if r[0] != 2:
			MM_FreePtr("kd:bigbuffer")
			return false

		var bigbuffer: PackedInt32Array = PackedInt32Array()
		bigbuffer.resize((expanded + 1) >> 1)
		if BE_Cross_readInt16LEBuffer(file, bigbuffer, compressed) != compressed:
			MM_FreePtr("kd:bigbuffer")
			return false

		# (the compressed length where CA_RLEWexpand wants the expanded one: as the C)
		CA_RLEWexpand(bigbuffer, mapsegs[i], compressed, RLETAG)

	MM_FreePtr("kd:bigbuffer")

	# Read the object list back in - assumes at least one object in list

	InitObjArray()
	newobj = player
	prev = newobj.prev
	next = newobj.next
	# (REFKEEN) Reading fields one-by-one in a cross-platform manner
	if not LoadObject(file, newobj):
		return false
	newobj.prev = prev
	newobj.next = next
	newobj.needtoreact = true
	newobj.sprite = null
	newobj = scoreobj
	while not quitting:
		prev = newobj.prev
		next = newobj.next
		# And again
		if not LoadObject(file, newobj):
			return false
		followed = newobj.next
		newobj.prev = prev
		newobj.next = next
		newobj.needtoreact = true
		newobj.sprite = null

		if followed != null:
			GetNewObj(false)
		else:
			break

	scoreobj.temp1 = -1    # force score to be updated
	scoreobj.temp2 = -1
	scoreobj.temp3 = -1    # and flower power
	scoreobj.temp4 = -1    # and lives

	return true


func ResetGame() -> void:
	NewGame()

	ca_levelnum -= 1
	CA_ClearMarks()
	titleptr[ca_levelnum] = ""    # don't reload old level
	ca_levelnum += 1


## Scrolls the title map to `offset` (global x); true if the user interrupted.
func MoveTitleTo(offset: int) -> bool:
	var done: bool
	var dir: int
	var chunk: int
	var move: int
	var lasttime: int
	var delay: int

	if offset < originxglobal:
		dir = -1
	else:
		dir = 1

	chunk = dir * PIXGLOBAL

	done = false
	delay = 1
	while not done and not quitting:
		lasttime = SD_GetTimeCount()
		move = s16(delay * chunk)
		if chunk < 0:
			done = originxglobal + move <= offset
		else:
			done = originxglobal + move >= offset
		if not done:
			call(RF_Scroll, move, 0)
			call(RF_Refresh)
		if IN_IsUserInput():
			return true
		delay = u32(SD_GetTimeCount() - lasttime)
	if originxglobal != offset and not quitting:
		call(RF_Scroll, offset - originxglobal, 0)
		call(RF_Refresh)
	return false


## Waits `time` tics refreshing every MINTICS; true if the user interrupted.
func Wait(time: int) -> bool:
	time = u32(time + SD_GetTimeCount())
	while SD_GetTimeCount() < time and not IN_IsUserInput() and not quitting:
		if not (SD_GetTimeCount() % MINTICS):
			call(RF_Refresh)
		else:
			BE_ST_ShortSleep()
	return IN_IsUserInput()


func ShowText(offset: int, wr: WindowRec, s: String) -> bool:
	if MoveTitleTo(offset):
		return true

	US_RestoreWindow(wr)
	US_CPrint(s)
	VW_UpdateScreen()

	if Wait(TickBase * 5):
		return true

	US_RestoreWindow(wr)
	US_CPrint(s)
	VW_UpdateScreen()
	return false


## The demo loop of v1.00: the title map scrolled between the credits, then the high scores.
func DemoLoop_Old() -> void:
	if _kl_warp_into_level():
		return
	var s: String
	var mywin: WindowRec = WindowRec.new()

	# demo loop
	US_SetLoadSaveHooks(&"LoadGame", &"SaveGame", &"ResetGame")
	restartgame = gd_Continue
	while not quitting:
		# Load the Title map
		gamestate.mapon = 20    # title map number
		loadedgame = false
		SetupGameLevel(true)

		while not restartgame and not loadedgame and not quitting:
			VW_InitDoubleBuffer()
			IN_ClearKeysDown()

			while not quitting:
				# Display the Title map
				@warning_ignore("integer_division")
				call(RF_NewPosition, (5 * TILEGLOBAL) + (TILEGLOBAL / 2),
					(TILEGLOBAL * 2) + (TILEGLOBAL / 2) + (TILEGLOBAL / 4))
				RF_ForceRefresh()
				call(RF_Refresh)
				call(RF_Refresh)

				if Wait(TickBase * 2):
					break

				mywin.x = (16 * 13) + 4
				mywin.y = 0
				mywin.w = 16 * 7
				mywin.h = 200
				mywin.px = mywin.x + 0
				mywin.py = mywin.y + 10
				s = ("Game\n"
					+ "John Carmack\n"
					+ "\n"
					+ "Utilities\n"
					+ "John Romero\n"
					+ "\n"
					+ "Interface/Sound\n"
					+ "Jason Blochowiak\n"
					+ "\n"
					+ "Creative Director\n"
					+ "Tom Hall\n"
					+ "\n"
					+ "Art\n"
					+ "Adrian Carmack\n")
				if ShowText((9 * TILEGLOBAL) - (PIXGLOBAL * 2), mywin, s):
					break

				mywin.x = 4
				mywin.y = 0
				mywin.w = 16 * 7
				mywin.h = 200
				mywin.px = mywin.x + 0
				mywin.py = mywin.y + 10
				s = ("Gamer's Edge\n"
					+ "\"Keen Dreams\"\n"
					+ "Copyright 1991\n"
					+ "Softdisk, Inc.\n"
					+ "\n"
					+ "Subscriptions\n"
					+ "1-800-831-2694\n"
					+ "\n"
					+ "Commander Keen\n"
					+ "Copyright 1990-91\n"
					+ "Id Software, Inc.\n"
					+ "\n"
					+ "Press F1 for Help\n"
					+ "SPACE to Start\n")
				if ShowText((2 * TILEGLOBAL) + (PIXGLOBAL * 2), mywin, s):
					break

				@warning_ignore("integer_division")
				if MoveTitleTo((5 * TILEGLOBAL) + (TILEGLOBAL / 2)):
					break
				if Wait(TickBase * 3):
					break

				VWB_Bar(0, 0, 320, 200, FIRSTCOLOR)
				US_DisplayHighScores(-1)

				if IN_UserInput(TickBase * 8, false):
					break

			if quitting:
				return
			US_ControlPanel()

		if quitting:
			return
		if not loadedgame:
			NewGame()
		GameLoop()


## The demo loop of v1.10 on: the title picture (KDREAMS.CMP), then the high scores.
func DemoLoop_New() -> void:
	if _kl_warp_into_level():
		return
	var FileName1: String
	var FileShape1: Shape = Shape.new()
	var bufsave: int = bufferofs
	var dissave: int = displayofs

	# demo loop
	US_SetLoadSaveHooks(&"LoadGame", &"SaveGame", &"ResetGame")
	restartgame = gd_Continue

	var handle: BE_FILE_T = BE_Cross_open_readonly_for_reading("KDREAMS.CMP")
	if not BE_Cross_IsFileValid(handle):
		Quit("Couldn't find KDREAMS.CMP")
		return
	BE_Cross_close(handle)

	while not quitting:
		loadedgame = false

		FileName1 = "TITLESCR.LBM"
		if LoadLIBShape("KDREAMS.CMP", FileName1, FileShape1):
			Quit("Can't load TITLE SCREEN")
		if quitting:
			return
		# (CREDITS is 0 in the DOS releases: no credits screens)

		while not restartgame and not loadedgame and not quitting:
			VW_InitDoubleBuffer()
			IN_ClearKeysDown()

			while not quitting:
				# REFKEEN - We're in an EGA-only function anyway,
				# so use EGA versions of VW functions...
				VW_SetScreen_EGA(0, 0)
				MoveGfxDst(0, 200)
				UnpackEGAShapeToScreen(FileShape1, 0, 0)
				VW_ScreenToScreen_EGA(64 * 200, 0, 40, 200)

				if IN_UserInput((TickBase * 8) if CREDITS else (TickBase * 4), false):
					break

				MoveGfxDst(0, 200)
				UnpackEGAShapeToScreen(FileShape1, 0, 0)
				VW_ScreenToScreen_EGA(64 * 200, 0, 40, 200)

				if IN_UserInput(TickBase * 3, false):
					break

				displayofs = 0
				VWB_Bar(0, 0, 320, 200, FIRSTCOLOR)
				US_DisplayHighScores(-1)

				if IN_UserInput(TickBase * 6, false):
					break

			if quitting:
				return
			bufferofs = bufsave
			displayofs = dissave

			VW_FixRefreshBuffer()
			US_ControlPanel()

		if quitting:
			return
		if not loadedgame:
			NewGame()

		FreeShape(FileShape1)
		GameLoop()


## (REFKEEN) Version-specific settings: the demo loop (current_gamever_int must be patched first).
func RefKeen_Patch_kd_demo() -> void:
	DemoLoop = &"DemoLoop_Old" if current_gamever_int < 110 else &"DemoLoop_New"
	CREDITS = 0


# ===================================================================== kd_play.c

const INACTIVATEDIST: int = 10
const MAXMOVE: int = TILEGLOBAL - 17
const NUMLUMPS: int = 22

const CONTROLSLUMP: int = 0
const KEENLUMP: int = 1
const WORLDKEENLUMP: int = 2
const BROCCOLUMP: int = 3
const TOMATLUMP: int = 4
const CARROTLUMP: int = 5
const ASPARLUMP: int = 6
const GRAPELUMP: int = 7
const TATERLUMP: int = 8
const CARTLUMP: int = 9
const FRENCHYLUMP: int = 10
const MELONLUMP: int = 11
const SQUASHLUMP: int = 12
const APELLUMP: int = 13
const PEALUMP: int = 14
const BOOBUSLUMP: int = 15

## levelnames' initialiser (21 entries; the last two NULL, here "").
const LEVELNAMES_KD_PLAY: PackedStringArray = [
	"The Land of Tuberia",
	"Horseradish Hill",
	"The Melon Mines",
	"Bridge Bottoms",
	"Rhubarb Rapids",
	"Parsnip Pass",
	"Level 6",
	"Spud City",
	"Level 8",
	"Apple Acres",
	"Grape Grove",
	"Level 11",
	"Brussels Sprout Bay",
	"Level 13",
	"Squash Swamp",
	"Boobus' Chamber",
	"Castle Tuberia",
	"",
	"Title Page",
	"",
	"",
]

# for asm scaning of map planes (UPDATE (REFKEEN): Code ported to C)
var mapx: int = 0
var mapy: int = 0
var maptile: int = 0

var plummet: int = 0

var objectcount: int = 0

var lastobj: objtype = null
var objfreelist: objtype = null

var oldtileleft: int = 0
var oldtiletop: int = 0
var oldtileright: int = 0
var oldtilebottom: int = 0
var oldtilemidx: int = 0
var oldleft: int = 0
var oldtop: int = 0
var oldright: int = 0
var oldbottom: int = 0
var oldmidx: int = 0
var leftmoved: int = 0
var topmoved: int = 0
var rightmoved: int = 0
var bottommoved: int = 0
var midxmoved: int = 0

var topmove: int = 0
var bottommove: int = 0
var midxmove: int = 0

var inactivateleft: int = 0
var inactivateright: int = 0
var inactivatetop: int = 0
var inactivatebottom: int = 0

var fadecount: int = 0

var bombspresent: bool = false

var lumpneeded: Array[bool] = _kd_new_lumpneeded()
## (the initialisers name 16 lumps of NUMLUMPS; the rest are 0)
const lumpstart: PackedInt32Array = [
	CONTROLS_LUMP_START, KEEN_LUMP_START, WORLDKEEN_LUMP_START, BROCCOLASH_LUMP_START,
	TOMATO_LUMP_START, CARROT_LUMP_START, ASPAR_LUMP_START, GRAPE_LUMP_START,
	TATER_LUMP_START, CANTA_LUMP_START, FRENCHY_LUMP_START, MELONLIPS_LUMP_START,
	SQUASHER_LUMP_START, APEL_LUMP_START, PEAS_LUMP_START, BOOBUS_LUMP_START,
	0, 0, 0, 0, 0, 0,
]
const lumpend: PackedInt32Array = [
	CONTROLS_LUMP_END, KEEN_LUMP_END, WORLDKEEN_LUMP_END, BROCCOLASH_LUMP_END,
	TOMATO_LUMP_END, CARROT_LUMP_END, ASPAR_LUMP_END, GRAPE_LUMP_END,
	TATER_LUMP_END, CANTA_LUMP_END, FRENCHY_LUMP_END, MELONLIPS_LUMP_END,
	SQUASHER_LUMP_END, APEL_LUMP_END, PEAS_LUMP_END, BOOBUS_LUMP_END,
	0, 0, 0, 0, 0, 0,
]


static func _kd_new_lumpneeded() -> Array[bool]:
	var a: Array[bool] = []
	a.resize(NUMLUMPS)
	a.fill(false)
	return a


## The static initialisers of kd_play.c (levelnames) and the objarray's storage (the C's static
## array: MAXACTORS objects that live as long as the program).
func _kd_static_init() -> void:
	levelnames = LEVELNAMES_KD_PLAY.duplicate()
	if objarray.size() != MAXACTORS:
		objarray = []
		for i: int in range(MAXACTORS):
			var o: objtype = objtype.new()
			o.index = i
			objarray.append(o)


func CheckKeys() -> void:
	if screenfaded:    # don't do anything with a faded screen
		return

	# space for status screen
	if Keyboard[sc_Space] if shell_controls.is_empty() else shell_held("status"):
		StatusWindow()
		IN_ClearKeysDown()
		RF_ForceRefresh()
		lasttimecount = s32(SD_GetTimeCount())

	# pause key wierdness can't be checked as a scan code
	if Paused:
		VW_FixRefreshBuffer()
		US_CenterWindow(8, 3)
		US_PrintCentered("PAUSED")
		VW_UpdateScreen()
		IN_Ack()
		RF_ForceRefresh()
		Paused = false

	# SAVE-02 (the user, 2026-10-10: Dreams' parity): F8 quicksaves and F9 quickloads, Megarocket's keys
	# (the original's F1-F7 open the panel); nothing with quicksave off or no player
	if (LastScan == sc_F8 or LastScan == sc_F9) and shell_quicksave_on():
		var quick: int = LastScan
		IN_ClearKeysDown()
		VW_FixRefreshBuffer()
		shell_quick_key(quick)
		IN_ClearKeysDown()
		if not loadedgame:
			RF_ForceRefresh()
		lasttimecount = s32(SD_GetTimeCount())

	# F1-F7/ESC to enter control panel
	if (LastScan >= sc_F1 and LastScan <= sc_F7) or LastScan == sc_Escape:
		VW_FixRefreshBuffer()
		US_CenterWindow(20, 8)
		US_CPrint("Loading")
		VW_UpdateScreen()
		US_ControlPanel()
		IN_ClearKeysDown()
		if restartgame:
			playstate = resetgame
		elif not loadedgame:
			RF_ForceRefresh()    # don't refresh if loading a new game

		lasttimecount = s32(SD_GetTimeCount())

	# F10-? debug keys
	if Keyboard[sc_F10] and DebugKeys():
		RF_ForceRefresh()
		lasttimecount = s32(SD_GetTimeCount())


# ---- SAVE-02: quicksave and quickload (the shell's, Enhanced)

## The quicksave's file, beside the panel's SAVEGMn.KDR in the player's folder.
const QUICK_FILE: String = "QUICKSAV.KDR"


func shell_quicksave_on() -> bool:
	return options != null and bool(options.get_value("quicksave"))


## F8: the game saved through the original's own SaveGame (the state, the map, every object: anywhere in
## a game, the map included, as the panel saves); F9: loaded through LoadGame, and the level starts again
## from it as the panel's load does (loadedgame; a pause first, as then). Each asks first while the
## Quicksave asks row is on.
func shell_quick_key(scan: int) -> void:
	if scan == sc_F8:
		if not _quick_confirm("Quicksave? (Y/N)"):
			return
		US_CenterWindow(10, 3)
		US_PrintCentered("Saving")
		VW_UpdateScreen()
		_quick_say("Game Quicksaved" if _quick_write() else "Quicksave Failed")
		return
	if not us_files.has(QUICK_FILE):
		_quick_say("No Quicksave Yet")
		return
	if not _quick_confirm("Quickload? (Y/N)"):
		return
	US_CenterWindow(10, 3)
	US_PrintCentered("Loading")
	VW_UpdateScreen()
	if _quick_read():
		loadedgame = true
		Paused = true
	else:
		_quick_say("Quickload Failed")


func _quick_write() -> bool:
	var game: US_SaveGame = US_SaveGame.new()
	var sig: PackedByteArray = EXTENSION.to_ascii_buffer()
	for i: int in range(mini(3, sig.size())):
		game.signature[i] = sig[i]
	game.present = true
	var nm: PackedByteArray = "QuickSave".to_ascii_buffer()
	for i: int in range(nm.size()):
		game.name[i] = nm[i]
	var file: BE_FILE_T = BE_Cross_open_rewritable_for_overwriting(QUICK_FILE)
	if not BE_Cross_IsFileValid(file):
		return false
	var ok: bool = BE_Cross_writeInt8LEBuffer(file, game.signature, 4) == 4 \
		and BE_Cross_write_boolean_To16LE(file, game.present) == 2 \
		and BE_Cross_writeInt8LEBuffer(file, game.name, MaxGameName + 1) == MaxGameName + 1 \
		and BE_Cross_writeInt8LE(file, 0) == 1 \
		and SaveGame(file)
	BE_Cross_close(file)
	if not ok:
		BE_Cross_remove(QUICK_FILE)
	return ok


func _quick_read() -> bool:
	var game: US_SaveGame = US_SaveGame.new()
	var file: BE_FILE_T = BE_Cross_open_rewritable_for_reading(QUICK_FILE)
	if not BE_Cross_IsFileValid(file):
		return false
	var ok: bool = _us_read_game_header(file, game) and _us_signature_ok(game) and LoadGame(file)
	BE_Cross_close(file)
	return ok


## The question in the panel's window: Y, Enter or the jump button yes; N, Escape or the throw button no.
func _quick_confirm(question: String) -> bool:
	if options != null and not bool(options.get_value("quicksave_confirm")):
		return true
	US_CenterWindow(16, 3)
	US_PrintCentered(question)
	VW_UpdateScreen()
	IN_ClearKeysDown()
	var info: CursorInfo = CursorInfo.new()
	var was: Array = [true, true]
	while not quitting:
		BE_ST_ShortSleep()
		var scan: int = LastScan
		if scan == sc_Y or scan == sc_Return:
			IN_ClearKeysDown()
			return true
		if scan == sc_N or scan == sc_Escape:
			IN_ClearKeysDown()
			return false
		IN_ReadControl(0, info)
		if info.button0 and not was[0]:
			return true
		if info.button1 and not was[1]:
			return false
		was = [info.button0, info.button1]
	return false


## A word in the panel's window until a key or button.
func _quick_say(text: String) -> void:
	US_CenterWindow(18, 3)
	US_PrintCentered(text)
	VW_UpdateScreen()
	IN_ClearKeysDown()
	IN_Ack()


func CalcInactivate() -> void:
	originxtilemax = u16(originxtile + PORTTILESWIDE - 1)
	originytilemax = u16(originytile + PORTTILESHIGH - 1)

	inactivateleft = s16(originxtile - INACTIVATEDIST)
	if inactivateleft < 0:
		inactivateleft = 0
	inactivateright = s16(originxtilemax + INACTIVATEDIST)
	inactivatetop = s16(originytile - INACTIVATEDIST)
	if inactivatetop < 0:
		inactivatetop = 0
	inactivatebottom = s16(originytilemax + INACTIVATEDIST)


# ---- The objarray data structure
#
# Objarray containt structures for every actor currently playing. The structure is accessed as a
# linked list starting at *player, ending when ob->next == NULL. GetNewObj inserts a new object at
# the end of the list, meaning that if an actor spawn another actor, the new one WILL get to think
# and react the same frame. RemoveObj unlinks the given object and returns it to the free list,
# but does not damage the objects ->next pointer, so if the current object removes itself, a
# linked list following loop can still safely get to the next element.

## Call to clear out the entire object list, returning them all to the free list. Allocates a
## special spot for the player.
func InitObjArray() -> void:
	_kd_static_init()
	for i: int in range(MAXACTORS):
		var o: objtype = objarray[i]
		o.prev = objarray[i + 1] if i + 1 < MAXACTORS else null
		o.next = null

	objfreelist = objarray[0]
	lastobj = null

	objectcount = 0

	# give the player and score the first free spots
	GetNewObj(false)
	player = newobj
	GetNewObj(false)
	scoreobj = newobj


## memset(ob, 0, sizeof(*ob)): every field zero (the slot keeps its index).
static func _kd_clear_obj(o: objtype) -> void:
	o.obclass = 0
	o.active = 0
	o.needtoreact = false
	o.needtoclip = false
	o.nothink = 0
	o.x = 0
	o.y = 0
	o.xdir = 0
	o.ydir = 0
	o.xmove = 0
	o.ymove = 0
	o.xspeed = 0
	o.yspeed = 0
	o.ticcount = 0
	o.ticadjust = 0
	o.state = null
	o.shapenum = 0
	o.left = 0
	o.top = 0
	o.right = 0
	o.bottom = 0
	o.midx = 0
	o.tileleft = 0
	o.tiletop = 0
	o.tileright = 0
	o.tilebottom = 0
	o.tilemidx = 0
	o.hitnorth = 0
	o.hiteast = 0
	o.hitsouth = 0
	o.hitwest = 0
	o.temp1 = 0
	o.temp2 = 0
	o.temp3 = 0
	o.temp4 = 0
	o.temp2stateptr = null
	o.sprite = null
	o.next = null
	o.prev = null


## Sets the global variable newobj to point to a free spot in objarray. The free spot is inserted
## at the end of the liked list. When the object list is full, the caller can either have it bomb
## out ot return a dummy object pointer that will never get used.
func GetNewObj(usedummy: bool) -> void:
	if objfreelist == null:
		if usedummy:
			newobj = dummyobj
			return
		Quit("GetNewObj: No free spots in objarray!")
		newobj = dummyobj    # (the C never gets here)
		return

	newobj = objfreelist
	objfreelist = newobj.prev
	_kd_clear_obj(newobj)

	if lastobj != null:
		lastobj.next = newobj
	newobj.prev = lastobj    # newobj->next is already NULL from memset

	newobj.active = yes
	newobj.needtoclip = true
	lastobj = newobj

	objectcount += 1


## Add the given object back into the free list, and unlink it from it's neighbors.
func RemoveObj(gone: objtype) -> void:
	if gone == player:
		Quit("RemoveObj: Tried to remove the player!")
		return

	# erase it from the refresh manager
	call(RF_RemoveSprite, gone)

	# fix the next object's back link
	if gone == lastobj:
		lastobj = gone.prev
	else:
		gone.next.prev = gone.prev

	# fix the previous object's forward link
	gone.prev.next = gone.next

	# add it back in to the free list
	gone.prev = objfreelist
	objfreelist = gone


func HandleInfo() -> void:
	match maptile:
		1:
			SpawnKeen(mapx, mapy, 1)
		2:
			SpawnKeen(mapx, mapy, -1)
		19:
			SpawnWorldKeen(mapx, mapy)
			lumpneeded[WORLDKEENLUMP] = true

		31, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32:
			if maptile == 31:
				bombspresent = true
			SpawnBonus(mapx, mapy, maptile - 21)
			newobj.active = no
		33:
			SpawnDoor(mapx, mapy)
			newobj.active = no
		41:
			SpawnBrocco(mapx, mapy)
			newobj.active = no
			lumpneeded[BROCCOLUMP] = true
		42:
			SpawnTomat(mapx, mapy)
			newobj.active = no
			lumpneeded[TOMATLUMP] = true
		43:
			SpawnCarrot(mapx, mapy)
			newobj.active = no
			lumpneeded[CARROTLUMP] = true
		45:
			SpawnAspar(mapx, mapy)
			newobj.active = no
			lumpneeded[ASPARLUMP] = true
		46:
			SpawnGrape(mapx, mapy)
			newobj.active = no
			lumpneeded[GRAPELUMP] = true
		47:
			SpawnTater(mapx, mapy)
			newobj.active = no
			lumpneeded[TATERLUMP] = true
		48:
			SpawnCart(mapx, mapy)
			lumpneeded[CARTLUMP] = true
		49:
			SpawnFrenchy(mapx, mapy)
			newobj.active = no
			lumpneeded[FRENCHYLUMP] = true
		50, 51, 52:
			SpawnMelon(mapx, mapy, maptile - 50)
			newobj.active = no
			lumpneeded[MELONLUMP] = true
		57:
			SpawnSquasher(mapx, mapy)
			newobj.active = no
			lumpneeded[SQUASHLUMP] = true
		58:
			SpawnApel(mapx, mapy)
			newobj.active = no
			lumpneeded[APELLUMP] = true
		59:
			SpawnPeaPod(mapx, mapy)
			newobj.active = no
			lumpneeded[PEALUMP] = true
		60:
			SpawnPeaBrain(mapx, mapy)
			newobj.active = no
			lumpneeded[PEALUMP] = true
		61:
			SpawnBoobus(mapx, mapy)
			lumpneeded[BOOBUSLUMP] = true

	if newobj.active != allways:
		newobj.active = no


## Spawn all actors and mark down special places.
func ScanInfoPlane() -> void:
	InitObjArray()    # start spawning things with a clean slate

	lumpneeded.fill(false)

	# Ported from ASM
	var start: PackedInt32Array = mapsegs[2]
	var spot: int = 0
	mapy = 0
	while mapy < mapheight and not quitting:
		mapx = 0
		while mapx < mapwidth and not quitting:
			var tile: int = s16(start[spot]) if spot < start.size() else 0
			spot += 1
			if tile:
				maptile = u16(tile)
				HandleInfo()
			mapx += 1
		mapy += 1

	for i: int in range(NUMLUMPS):
		if lumpneeded[i]:
			for j: int in range(lumpstart[i], lumpend[i] + 1):
				grneeded[j] |= ca_levelbit    # CA_MarkGrChunk


## Takes out blocking squares and puts in dones.
func PatchWorldMap() -> void:
	var size: int = u16(mapwidth * mapheight)
	var spot: int = 0
	var info: int
	var foreground: int
	var p1: PackedInt32Array = mapsegs[1]
	var p2: PackedInt32Array = mapsegs[2]
	while true:
		info = p2[spot] if spot < p2.size() else 0
		# finished a city here?
		if info >= 3 and info <= 18 and gamestate.leveldone[info - 2]:
			p2[spot] = 0
			foreground = p1[spot]
			if foreground == 130:
				p1[spot] = 0    # not blocking now
			elif foreground == 90:
				# plant done flag
				p1[spot] = 133
				_kd_setword(p1, spot - mapwidth - 1, 131)
				_kd_setword(p1, spot - mapwidth, 132)
		spot += 1
		if spot >= size:
			break
	# TIME-D: the original's pass over the whole map, a few instructions a cell (the port's is free)
	cost_n("mapscan", size)


## A word of a map plane, written if it lies in the plane (guarded).
static func _kd_setword(plane: PackedInt32Array, ofs: int, v: int) -> void:
	if ofs >= 0 and ofs < plane.size():
		plane[ofs] = v & 0xFFFF


## Latch this onto the refresh so the screen only gets faded in after two refreshes. This lets
## all actors draw themselves to both pages before fading the screen in.
func FadeAndUnhook() -> void:
	fadecount += 1
	if fadecount == 2:
		if current_gamever_int >= 110:
			RF_ForceRefresh()

		VW_FadeIn()
		RF_SetRefreshHook(&"")
		lasttimecount = s32(SD_GetTimeCount())    # don't adaptively time the fade


## Load in map mapon and cache everything needed for it.
func SetupGameLevel(loadnow: bool) -> void:
	var orgx: int
	var orgy: int

	bombspresent = false

	# load the level header and three map planes
	CA_CacheMap(gamestate.mapon)
	if quitting:
		return

	# let the refresh manager set up some variables
	RF_NewMap()

	# decide which graphics are needed and spawn actors
	CA_ClearMarks()

	if not mapon:
		PatchWorldMap()

	if mapon != 20:    # map 20 is the title screen
		ScanInfoPlane()
	if quitting:
		return
	RF_MarkTileGraphics()

	# have the caching manager load and purge stuff to make sure all marks are in memory
	if loadnow:
		if bombspresent:
			VW_FixRefreshBuffer()
			US_DrawWindow(10, 1, 20, 2)
			US_PrintCentered("Boobus Bombs Near!")
			VW_UpdateScreen()
		# (REFKEEN) one argument in v1.00, the second ignored
		CA_CacheMarks(levelnames[mapon], false)
	if quitting:
		return

	if mapon != 20 and loadnow:    # map 20 is the title screen
		VW_FadeOut()
		fadecount = 0
		RF_SetRefreshHook(&"FadeAndUnhook")
		SpawnScore()
		if quitting:
			return

		# start the initial view position to center the player
		orgx = s32(player.x - (150 << G_P_SHIFT))
		orgy = s32(player.y - (84 << G_P_SHIFT))
		if orgx < 0:
			orgx = 0
		if orgy < 0:
			orgy = 0

		call(RF_NewPosition, u16(orgx), u16(orgy))
		CalcInactivate()


## Scroll if Keen is nearing an edge. Set playstate to levelcomplete.
func ScrollScreen() -> void:
	var xscroll: int
	var yscroll: int

	# walked off edge of map?
	if player.left < originxmin or player.right > originxmax + 20 * TILEGLOBAL:
		playstate = levelcomplete
		return

	# fallen off bottom of world?
	if not plummet and player.bottom > originymax + 13 * TILEGLOBAL:
		godmode = false
		plummet = 1
		KillKeen()
		return

	if player.x < originxglobal + SCROLLWEST:
		xscroll = s16(player.x - (originxglobal + SCROLLWEST))
	elif player.x > originxglobal + SCROLLEAST:
		xscroll = s16(player.x - (originxglobal + SCROLLEAST))
	else:
		xscroll = 0

	if player.y < originyglobal + SCROLLNORTH:
		yscroll = s16(player.y - (originyglobal + SCROLLNORTH))
	elif player.y > originyglobal + SCROLLSOUTH:
		yscroll = s16(player.y - (originyglobal + SCROLLSOUTH))
	else:
		yscroll = 0

	if xscroll or yscroll:
		call(RF_Scroll, xscroll, yscroll)
		CalcInactivate()
		scoreobj.needtoreact = true


## Grants extra men at 20k,40k,80k,160k,320k.
func GivePoints(points: int) -> void:
	gamestate.score = s32(gamestate.score + u16(points))
	if gamestate.score >= gamestate.nextextra:
		SD_PlaySound(EXTRAKEENSND)
		gamestate.lives = s16(gamestate.lives + 1)
		gamestate.nextextra = s32(gamestate.nextextra * 2)


func MoveObjVert(ob: objtype, ymove: int) -> void:
	ob.y = u16(ob.y + ymove)
	ob.top = u16(ob.top + ymove)
	ob.bottom = u16(ob.bottom + ymove)
	ob.tiletop = ob.top >> G_T_SHIFT
	ob.tilebottom = ob.bottom >> G_T_SHIFT


func MoveObjHoriz(ob: objtype, xmove: int) -> void:
	ob.x = u16(ob.x + xmove)
	ob.left = u16(ob.left + xmove)
	ob.right = u16(ob.right + xmove)
	ob.tileleft = ob.left >> G_T_SHIFT
	ob.tileright = ob.right >> G_T_SHIFT


# ---- Actor to tile clipping rouitnes

## walltype / x coordinate (0-15): the height of a given point in a tile
const wallclip: Array = [
	[256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38, 0x40, 0x48, 0x50, 0x58, 0x60, 0x68, 0x70, 0x78],
	[0x80, 0x88, 0x90, 0x98, 0xa0, 0xa8, 0xb0, 0xb8, 0xc0, 0xc8, 0xd0, 0xd8, 0xe0, 0xe8, 0xf0, 0xf8],
	[0, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0],
	[0x78, 0x70, 0x68, 0x60, 0x58, 0x50, 0x48, 0x40, 0x38, 0x30, 0x28, 0x20, 0x18, 0x10, 0x08, 0],
	[0xf8, 0xf0, 0xe8, 0xe0, 0xd8, 0xd0, 0xc8, 0xc0, 0xb8, 0xb0, 0xa8, 0xa0, 0x98, 0x90, 0x88, 0x80],
	[0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0],
]


## mapbwidthtable[y]/2: a row's start in words (0 past the table, guarded).
func _kd_rowstart(y: int) -> int:
	if y < 0 or y >= mapbwidthtable.size():
		return 0
	@warning_ignore("integer_division")
	return mapbwidthtable[y] / 2


## The foreground word at `ofs` (0 past the plane, guarded).
func _kd_fore(ofs: int) -> int:
	var m: PackedInt32Array = mapsegs[1]
	return m[ofs] if ofs >= 0 and ofs < m.size() else 0


## tinf[i] (0 past the table, guarded).
func _kd_tinf(i: int) -> int:
	return tinf[i] if i >= 0 and i < tinf.size() else 0


func ClipToEnds(ob: objtype) -> void:
	var wall: int
	var y: int
	var clip: int
	var move: int
	var totalmove: int
	var maxmove: int
	var midxpix: int
	var guard: int = 0

	midxpix = (ob.midx & 0xf0) >> 4

	maxmove = s16(-absi(midxmoved) - bottommoved - 16)
	var map: int = _kd_rowstart(oldtilebottom - 1) + ob.tilemidx
	# (REFKEEN) Comparison is unsigned in vanilla Keen (has an effect on the explosion of King
	# Boobus Tuber). (A loop the original could never leave is cut after 64K rows.)
	y = s16(oldtilebottom - 1)
	while u16(y) <= ob.tilebottom and guard < 0x10000:
		wall = _kd_tinf(NORTHWALL + _kd_fore(map))
		if wall:
			clip = wallclip[wall & 7][midxpix]
			move = s16(((y << G_T_SHIFT) + clip - 1) - ob.bottom)
			if move < 0 and move >= maxmove:
				ob.hitnorth = wall
				MoveObjVert(ob, move)
				return
		y = s16(y + 1)
		map += mapwidth
		guard += 1

	maxmove = s16(absi(midxmoved) - topmoved + 16)
	map = _kd_rowstart(oldtiletop + 1) + ob.tilemidx
	# (REFKEEN) Again comparison should be unsigned
	y = s16(oldtiletop + 1)
	guard = 0
	while u16(y) >= ob.tiletop and guard < 0x10000:
		wall = _kd_tinf(SOUTHWALL + _kd_fore(map))
		if wall:
			clip = wallclip[wall & 7][midxpix]
			move = s16((((y + 1) << G_T_SHIFT) - clip) - ob.top)
			if move > 0 and move <= maxmove:
				totalmove = s16(ob.ymove + move)
				if totalmove < TILEGLOBAL and totalmove > -TILEGLOBAL:
					ob.hitsouth = wall
					MoveObjVert(ob, move)
		y = s16(y - 1)
		map -= mapwidth
		guard += 1


func ClipToEastWalls(ob: objtype) -> void:
	var move: int
	var top: int
	var bottom: int

	# clip to east walls if moving west

	top = s16(ob.tiletop)
	if ob.hitsouth > 1:
		top = s16(top + 1)    # on a slope inside a tile
	bottom = s16(ob.tilebottom)
	if ob.hitnorth > 1:
		bottom = s16(bottom - 1)    # on a slope inside a tile

	for y: int in range(top, bottom + 1):
		var map: int = _kd_rowstart(y) + ob.tileleft

		ob.hiteast = _kd_tinf(EASTWALL + _kd_fore(map))
		if ob.hiteast:
			move = s16(((ob.tileleft + 1) << G_T_SHIFT) - ob.left)
			MoveObjHoriz(ob, move)
			return


func ClipToWestWalls(ob: objtype) -> void:
	var move: int
	var top: int
	var bottom: int

	# check west walls if moving east

	top = s16(ob.tiletop)
	if ob.hitsouth > 1:
		top = s16(top + 1)    # on a slope inside a tile
	bottom = s16(ob.tilebottom)
	if ob.hitnorth > 1:
		bottom = s16(bottom - 1)    # on a slope inside a tile

	for y: int in range(top, bottom + 1):
		var map: int = _kd_rowstart(y) + ob.tileright

		ob.hitwest = _kd_tinf(WESTWALL + _kd_fore(map))
		if ob.hitwest:
			move = s16(((ob.tileright << G_T_SHIFT) - 1) - ob.right)
			MoveObjHoriz(ob, move)
			return


## Moves the current object xmove/ymove units, clipping to walls.
func ClipToWalls(ob: objtype) -> void:
	var shape: spritetabletype

	# make sure it stays in contact with a 45 degree slope
	# REFKEEN - It's possible that state == NULL, e.g., after loading a saved game, after which
	# ChangeFromFlower is going to be called, while the flower is in one of the s_pooffrom* states.
	# If state == NULL then, under DOS (with Borland C++ 2.0), ob->state->pushtofloor is a part of
	# a small Borland C++ string.
	if ob.state == null or ob.state.pushtofloor:
		if ob.xmove > 0:
			ob.ymove = s16(ob.xmove + 16)
		else:
			ob.ymove = s16(-ob.xmove + 16)

	# move the shape
	if ob.xmove > MAXMOVE:
		ob.xmove = MAXMOVE
	elif ob.xmove < -MAXMOVE:
		ob.xmove = -MAXMOVE

	if ob.ymove > MAXMOVE + 16:    # +16 for push to floor
		ob.ymove = MAXMOVE + 16
	elif ob.ymove < -MAXMOVE:
		ob.ymove = -MAXMOVE

	ob.x = u16(ob.x + ob.xmove)
	ob.y = u16(ob.y + ob.ymove)

	ob.needtoreact = true

	if not ob.shapenum:    # can't get a hit rect with no shape!
		return

	var si: int = ob.shapenum - STARTSPRITES
	if si < 0 or si >= spritetable.size():
		return    # (outside the table: guarded)
	shape = spritetable[si]

	oldtileright = s16(ob.tileright)
	oldtiletop = s16(ob.tiletop)
	oldtileleft = s16(ob.tileleft)
	oldtilebottom = s16(ob.tilebottom)
	oldtilemidx = s16(ob.tilemidx)

	oldright = s16(ob.right)
	oldtop = s16(ob.top)
	oldleft = s16(ob.left)
	oldbottom = s16(ob.bottom)
	oldmidx = s16(ob.midx)

	ob.left = u16(ob.x + shape.xl)
	ob.right = u16(ob.x + shape.xh)
	ob.top = u16(ob.y + shape.yl)
	ob.bottom = u16(ob.y + shape.yh)
	@warning_ignore("integer_division")
	ob.midx = u16(ob.left + (ob.right - ob.left) / 2)

	ob.tileleft = ob.left >> G_T_SHIFT
	ob.tileright = ob.right >> G_T_SHIFT
	ob.tiletop = ob.top >> G_T_SHIFT
	ob.tilebottom = ob.bottom >> G_T_SHIFT
	ob.tilemidx = ob.midx >> G_T_SHIFT

	ob.hitnorth = 0
	ob.hiteast = 0
	ob.hitsouth = 0
	ob.hitwest = 0

	if not ob.needtoclip:
		return

	leftmoved = s16(ob.left - oldleft)
	rightmoved = s16(ob.right - oldright)
	topmoved = s16(ob.top - oldtop)
	bottommoved = s16(ob.bottom - oldbottom)
	midxmoved = s16(ob.midx - oldmidx)

	# clip it

	ClipToEnds(ob)

	if leftmoved < 0 or ob == player:    # make sure player gets cliped
		ClipToEastWalls(ob)
	if rightmoved > 0 or ob == player:
		ClipToWestWalls(ob)


## Clips push to solid.
func ClipToSpriteSide(push: objtype, solid: objtype) -> void:
	var xmove: int
	var leftinto: int
	var rightinto: int

	# amount the push shape can be pushed
	xmove = s16(solid.xmove - push.xmove)

	# amount it is inside
	leftinto = s16(solid.right - push.left)
	rightinto = s16(push.right - solid.left)

	if leftinto > 0 and leftinto <= xmove:
		push.xmove = leftinto
		if push.state.pushtofloor:
			push.ymove = s16(leftinto + 16)
		ClipToWalls(push)
		push.hiteast = 1
		return

	if rightinto > 0 and rightinto <= -xmove:
		push.xmove = -rightinto
		if push.state.pushtofloor:
			push.ymove = s16(rightinto + 16)
		ClipToWalls(push)
		push.hitwest = 1
		return


## Clips push to solid.
func ClipToSprite(push: objtype, solid: objtype, squish: bool) -> void:
	var temp: bool
	var walltemp: int
	var xmove: int
	var leftinto: int
	var rightinto: int
	var topinto: int
	var bottominto: int

	xmove = s16(solid.xmove - push.xmove)

	push.xmove = 0
	push.ymove = 0

	# left / right
	leftinto = s16(solid.right - push.left)
	rightinto = s16(push.right - solid.left)

	if leftinto > 0 and leftinto <= xmove:
		push.xmove = leftinto
		walltemp = push.hitnorth
		ClipToWalls(push)
		if not push.hitnorth:
			push.hitnorth = walltemp
		if squish and push.hitwest:
			KillKeen()
		push.hiteast = 1
		return
	elif rightinto > 0 and rightinto <= -xmove:
		push.xmove = -rightinto
		walltemp = push.hitnorth
		ClipToWalls(push)
		if not push.hitnorth:
			push.hitnorth = walltemp
		if squish and push.hiteast:
			KillKeen()
		push.hitwest = 1
		return

	# top / bottom
	topinto = s16(solid.bottom - push.top)
	bottominto = s16(push.bottom - solid.top)

	if bottominto > 0:
		push.ymove = s16(-bottominto + 16)
		push.xmove = solid.xmove
		temp = push.state.pushtofloor
		push.state.pushtofloor = false
		walltemp = push.hitnorth
		ClipToWalls(push)
		if not push.hitnorth:
			push.hitnorth = walltemp
		push.state.pushtofloor = temp
		push.hitnorth = 25
	elif topinto > 0:
		push.ymove = topinto
		ClipToWalls(push)
		push.hitsouth = 25


## Moves an actor in its current state by a given number of tics. If that time takes it into the
## next state, it changes the state and returns the number of excess tics after the state change.
## (`ntics`: the C's parameter `tics`, renamed: the refresh manager's global has the name.)
func DoActor(ob: objtype, ntics: int) -> int:
	var newtics: int
	var movetics: int
	var excesstics: int
	var state: statetype

	state = ob.state

	# REFKEEN: Vanilla Keen Dreams bug emulation (state may be 0). If state == NULL then, under
	# DOS (with Borland C++ 2.0), state->progress is a part of a small Borland C++ string.
	if state != null and state.progress == think:
		if state.thinkptr != &"":
			if ob.nothink:
				ob.nothink = u16(ob.nothink - 1)
			else:
				call(state.thinkptr, ob)
		return 0

	newtics = s16(ob.ticcount + ntics)

	# REFKEEN: Vanilla Keen Dreams bug emulation (state may be 0). Magic number is based on what
	# would occur if there were a null-pointer dereference, assuming the value was never overwritten.
	if (state == null and newtics < 0x2064) or (state != null and (newtics < state.tictime or state.tictime == 0)):
		ob.ticcount = newtics
		# REFKEEN: Vanilla Keen Dreams bug (state may be 0): state->progress would differ from all
		# compared values with the original DOS versions in that case, unless modified.
		if state == null:
			return 0
		if state.progress == slide or state.progress == slidethink:
			if ob.xdir:
				ob.xmove = s16(ob.xmove + (ntics * state.xmove if ob.xdir == 1 else -ntics * state.xmove))
			if ob.ydir:
				ob.ymove = s16(ob.ymove + (ntics * state.ymove if ob.ydir == 1 else -ntics * state.ymove))
		if state.progress == slidethink or state.progress == stepthink:
			if state.thinkptr != &"":
				if ob.nothink:
					ob.nothink = u16(ob.nothink - 1)
				else:
					call(state.thinkptr, ob)
		return 0
	else:
		if state == null:
			return 0    # (a NULL state past its time: the C reads garbage here; guarded)
		movetics = s16(state.tictime - ob.ticcount)
		excesstics = s16(newtics - state.tictime)
		ob.ticcount = 0
		if state.progress == slide or state.progress == slidethink:
			if ob.xdir:
				ob.xmove = s16(ob.xmove + (movetics * state.xmove if ob.xdir == 1 else -movetics * state.xmove))
			if ob.ydir:
				ob.ymove = s16(ob.ymove + (movetics * state.ymove if ob.ydir == 1 else -movetics * state.ymove))
		else:
			if ob.xdir:
				ob.xmove = s16(ob.xmove + (state.xmove if ob.xdir == 1 else -state.xmove))
			if ob.ydir:
				ob.ymove = s16(ob.ymove + (state.ymove if ob.ydir == 1 else -state.ymove))
			if draw_capture and ((ob.xdir != 0 and state.xmove != 0) or (ob.ydir != 0 and state.ymove != 0)):
				draw_stepped[ob] = true    # REND-03D: a step (the whole move with the next picture), not a slide; presentation only

		if state.thinkptr != &"":
			if ob.nothink:
				ob.nothink = u16(ob.nothink - 1)
			else:
				call(state.thinkptr, ob)

		if ob.state == state:
			ob.state = state.nextstate    # go to next state
		elif ob.state == null:
			return 0    # object removed itself
		return excesstics


## Change state and give directions.
func StateMachine(ob: objtype) -> void:
	var excesstics: int
	var oldshapenum: int
	var state: statetype

	ob.xmove = 0
	ob.ymove = 0
	oldshapenum = ob.shapenum

	state = ob.state

	excesstics = DoActor(ob, tics)
	if ob.state != state:
		ob.ticcount = 0    # start the new state at 0, then use excess
		state = ob.state

	while excesstics and not quitting:
		# passed through to next state
		# REFKEEN: Vanilla Keen Dreams CGA v1.05 bug fix (state may be 0). state->skippable would be
		# true with the original EXEs if state was 0, unless modified earlier.
		if state != null and not state.skippable and excesstics >= state.tictime:
			excesstics = DoActor(ob, state.tictime - 1)
		else:
			excesstics = DoActor(ob, excesstics)
		if ob.state != state:
			ob.ticcount = 0    # start the new state at 0, then use excess
			state = ob.state

	if state == null:    # object removed itself
		RemoveObj(ob)
		return

	# if state->rightshapenum == NULL, the state does not have a standard
	# shape (the think routine should have set it)
	if state.rightshapenum:
		if ob.xdir > 0:
			ob.shapenum = u16(state.rightshapenum)
		else:
			ob.shapenum = u16(state.leftshapenum)
	if ob.shapenum == 0xFFFF:
		ob.shapenum = 0    # make it invisable this time

	if ob.xmove or ob.ymove or ob.shapenum != oldshapenum:
		# actor moved or changed shape
		# make sure the movement is within limits (one tile)
		if cheat_noClip and ob == player:
			# CHEAT-02: No clipping: Keen's edges worked out, the walls not applied (NewState's trick)
			var keep: bool = ob.needtoclip
			ob.needtoclip = false
			ClipToWalls(ob)
			ob.needtoclip = keep
		else:
			ClipToWalls(ob)


func NewState(ob: objtype, state: statetype) -> void:
	var temp: bool

	ob.state = state

	if state.rightshapenum:
		if ob.xdir > 0:
			ob.shapenum = u16(state.rightshapenum)
		else:
			ob.shapenum = u16(state.leftshapenum)

	temp = ob.needtoclip

	ob.needtoclip = false

	ClipToWalls(ob)    # just calculate values

	ob.needtoclip = temp

	if ob.needtoclip:
		ClipToWalls(ob)


func PlayLoop() -> void:
	var obj: objtype
	var checkob: objtype    # (the C's local `check`, which shadows the global)

	button0held = false
	button1held = false

	ingame = true
	playstate = notdone
	plummet = 0

	FixScoreBox()    # draw bomb/flower

	while not quitting:
		CalcSingleGravity()
		IN_ReadControl(0, c)    # get player input
		if _kl_file != null:
			_kl_frame(c)    # HARN-23 (tests only)
		if not c.button0:
			button0held = false
		if not c.button1:
			button1held = false

		# go through state changes and propose movements
		obj = player
		while obj != null and not quitting:
			# (REND-04D, J-30: with the wide view, creatures wake by its edges: wide_tiles more each side; 0,
			# the original's columns, otherwise)
			if (not obj.active
					and obj.tileright >= originxtile - wide_tiles
					and obj.tileleft <= originxtilemax + wide_tiles
					and obj.tiletop <= originytilemax
					and obj.tilebottom >= originytile):
				obj.needtoreact = true
				obj.active = yes

			# CHEAT-02: Freeze enemies: every actor but Keen, his flowers and the score box holds still
			if obj.active and not (cheat_freezeEnemies and obj != player and obj != scoreobj and obj.obclass != powerobj):
				StateMachine(obj)

			if ((obj.active == yes or obj.active == removable) and
					(obj.tileright < inactivateleft
					or obj.tileleft > inactivateright
					or obj.tiletop > inactivatebottom
					or obj.tilebottom < inactivatetop)):
				if obj.active == removable:
					RemoveObj(obj)    # temp thing (shots, etc)
				else:
					if US_RndT() < tics:    # let them get a random dist
						call(RF_RemoveSprite, obj)
						obj.active = no

			obj = obj.next
		if quitting:
			break

		# check for and handle collisions between objects
		obj = player
		while obj != null and not quitting:
			if obj.active:
				checkob = obj.next
				while checkob != null:
					if (checkob.active
							and obj.right > checkob.left
							and obj.left < checkob.right
							and obj.top < checkob.bottom
							and obj.bottom > checkob.top):
						if obj.state != null and obj.state.contactptr != &"":
							call(obj.state.contactptr, obj, checkob)
						if checkob.state != null and checkob.state.contactptr != &"":
							call(checkob.state.contactptr, checkob, obj)
						if not obj.obclass:
							break    # contact removed object
					checkob = checkob.next
			obj = obj.next
		if quitting:
			break

		ScrollScreen()

		# react to whatever happened, and post sprites to the refresh manager
		obj = player
		while obj != null and not quitting:
			if obj.needtoreact and obj.state != null and obj.state.reactptr != &"":
				obj.needtoreact = false
				call(obj.state.reactptr, obj)
			obj = obj.next
		if quitting:
			break

		# update the screen and calculate the number of tics it took to execute
		# this cycle of events (for adaptive timing of next cycle)
		call(RF_Refresh)

		# single step debug mode
		if singlestep:
			VW_WaitVBL(14)
			lasttimecount = s32(SD_GetTimeCount())

		CheckKeys()
		if loadedgame or playstate:
			break

	if _kl_file != null:
		# HARN-23: a trace is one life (the replay follows the play loop only, not the boxes after it)
		_kl_file.close()
		_kl_file = null
		kl_record = ""
	ingame = false


func GameFinale() -> void:
	VW_FixRefreshBuffer()

	# screen 1 of finale text (16 lines)
	US_CenterWindow(30, 21)
	PrintY = u16(PrintY + 4)
	US_CPrint(
		"Yes!  Boobus Tuber's hash-brown-\n"
		+ "like remains rained down from\n"
		+ "the skies as Commander Keen\n"
		+ "walked up to the Dream Machine.\n"
		+ "He analyzed all the complex\n"
		+ "controls and readouts on it, then\n"
		+ "pulled down a huge red lever\n"
		+ "marked \"On/Off Switch.\"  The\n"
		+ "machine clanked and rattled,\n"
		+ "then went silent. He had freed\n"
		+ "all the children from their\n"
		+ "vegetable-enforced slavery!\n"
		+ "Everything around Keen wobbled\n"
		+ "in a disconcerting manner, his\n"
		+ "eyelids grew heavy, and he\n"
		+ "fell asleep....\n")
	VW_UpdateScreen()
	VW_WaitVBL(60)
	SD_WaitSoundDone()
	IN_ClearKeysDown()
	IN_Ack()
	if quitting:
		return

	# screen 2 of finale (15 lines)
	US_CenterWindow(30, 21)
	PrintY = u16(PrintY + 9)
	if current_gamever_int == 100:
		US_CPrint(
			"Billy woke up, squinting at the\n"
			+ "early morning sun shining in his\n"
			+ "face through the bedroom window.\n"
			+ "Nothing. No vegetables to be seen.\n"
			+ "Was it all just a dream?\n\n"
			+ "Billy's mom entered the room.\n\n"
			+ "\"Good morning, dear. I heard some\n"
			+ "news on TV that you'd be\n"
			+ "interested in,\" she said, sitting\n"
			+ "by him on the bed.\n\n"
			+ "\"What news?\" Billy asked,\n"
			+ "still groggy.\n\n")
	else:
		US_CPrint(
			"Billy woke up, looking around the\n"
			+ "room, the early morning sun\n"
			+ "shining in his face.  Nothing.\n"
			+ "No vegetables to be seen.  Was it\n"
			+ "all just a dream?\n\n"
			+ "Billy's mom entered the room.\n\n"
			+ "\"Good morning, dear. I heard some\n"
			+ "news on TV that you'd be\n"
			+ "interested in,\" she said, sitting\n"
			+ "by him on the bed.\n\n"
			+ "\"What news?\" Billy asked,\n"
			+ "still groggy.\n\n")
	VW_UpdateScreen()
	VW_WaitVBL(60)
	IN_ClearKeysDown()
	IN_Ack()
	if quitting:
		return

	# screen 3 of finale (12 lines)
	US_CenterWindow(30, 21)
	PrintY = u16(PrintY + 23)
	var s3: String = (
		"\"The President declared today\n"
		+ "National 'I Hate Broccoli' Day.\n"
		+ "He said kids are allowed to pick\n"
		+ "one vegetable today, and they\n"
		+ "don't have to eat it.\"\n\n"
		+ "\"Aw, mom, I'm not afraid of any\n"
		+ "stupid vegetables,\" Billy said.\n"
		+ "\"But if it's okay with you, I'd\n"
		+ "rather not have any french fries\n"
		+ "for awhile.\"\n\n")
	if current_gamever_int != 100:
		s3 += "THE END"
	US_CPrint(s3)
	VW_UpdateScreen()
	VW_WaitVBL(60)
	IN_ClearKeysDown()
	IN_Ack()

	if current_gamever_int != 100 or quitting:
		return

	# screen 4 of finale (13 lines)
	US_CenterWindow(30, 21)
	PrintY = u16(PrintY + 18)
	US_CPrint(
		"\"Okay, honey,\" Billy's mom said.\n\n"
		+ "\"Uh, Mom, what are we having for\n"
		+ "supper tonight?\" Billy asked.\n\n"
		+ "\"Oh, we're having liver, dear.\"\n"
		+ "\"I HATE liver!  I don't have to\n"
		+ "eat liver.  I saved the earth!\"\n\n"
		+ "THE END\n\n"
		+ "(Possibly continued in...\n"
		+ "\"Commander Keen Meets the Meats\")\n")
	VW_UpdateScreen()
	VW_WaitVBL(60)
	IN_ClearKeysDown()
	IN_Ack()
	if quitting:
		return

	# getdate(&d): the machine has no calendar (no wall clock, A8); any date after 29 July 1991,
	# as every date the game has run on since, shows the last screen
	if true:
		# screen 5 of finale (6 lines)
		US_CenterWindow(30, 21)
		PrintY = u16(PrintY + 53)
		US_CPrint(
			"Commander Keen will definitely\n"
			+ "return in...\n\n"
			+ "\"Goodbye, Galaxy!\"\n\n"
			+ "Watch for it!\n")
		VW_UpdateScreen()
		VW_WaitVBL(60)
		IN_ClearKeysDown()
		IN_Ack()


func HandleDeath() -> void:
	var top: int
	var bottom: int
	var selection: int
	var y: int
	var color: int

	gamestate.keys = 0
	gamestate.boobusbombs = s16(gamestate.boobusbombs - gamestate.bombsthislevel)
	if not cheat_infiniteLives:    # CHEAT-02: death still plays; the count never falls
		gamestate.lives = s16(gamestate.lives - 1)
	if gamestate.lives < 0:
		return

	VW_FixRefreshBuffer()
	US_CenterWindow(20, 8)
	PrintY = u16(PrintY + 4)
	US_CPrint("You didn't make it past")
	US_CPrint(levelnames[mapon])
	PrintY = u16(PrintY + 8)
	top = u16(PrintY - 2)
	US_CPrint("Try Again")
	PrintY = u16(PrintY + 4)
	bottom = u16(PrintY - 2)
	US_CPrint("Exit to Tuberia")

	selection = 0
	while not quitting:
		if selection:
			y = bottom
		else:
			y = top

		# draw select bar
		@warning_ignore("integer_division")
		if (SD_GetTimeCount() / 16) & 1:
			color = SECONDCOLOR
		else:
			color = FIRSTCOLOR

		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y, color)
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y + 1, color)
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y + 12, color)
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y + 13, color)
		VWB_Vlin(y + 1, y + 11, WindowX + 4, color)
		VWB_Vlin(y + 1, y + 11, WindowX + 5, color)
		VWB_Vlin(y + 1, y + 11, WindowX + WindowW - 4, color)
		VWB_Vlin(y + 1, y + 11, WindowX + WindowW - 5, color)

		VW_UpdateScreen()

		# erase select bar
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y, WHITE)
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y + 1, WHITE)
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y + 12, WHITE)
		VWB_Hlin(WindowX + 4, WindowX + WindowW - 4, y + 13, WHITE)
		VWB_Vlin(y + 1, y + 11, WindowX + 4, WHITE)
		VWB_Vlin(y + 1, y + 11, WindowX + 5, WHITE)
		VWB_Vlin(y + 1, y + 11, WindowX + WindowW - 4, WHITE)
		VWB_Vlin(y + 1, y + 11, WindowX + WindowW - 5, WHITE)

		if LastScan == sc_Escape:
			gamestate.mapon = 0    # exit to tuberia
			IN_ClearKeysDown()
			return

		IN_ReadControl(0, c)    # get player input
		if c.button0 or c.button1 or LastScan == sc_Return or LastScan == sc_Space:
			if selection:
				gamestate.mapon = 0    # exit to tuberia
			return
		if c.yaxis == -1 or LastScan == sc_UpArrow:
			selection = 0
		elif c.yaxis == 1 or LastScan == sc_DownArrow:
			selection = 1
		BE_ST_ShortSleep()


## A game has just started (after the cinematic or load game).
func GameLoop() -> void:
	var cities: int
	var orgx: int
	var orgy: int

	gamestate.difficulty = restartgame
	restartgame = gd_Continue

	var finale: bool = false
	while not quitting:
		# startlevel: (a goto back here skips the loop's condition)
		var startlevel: bool = true
		while startlevel and not quitting:
			startlevel = false
			if loadedgame:
				loadedgame = false
				# start the initial view position to center the player
				orgx = s32(player.x - (150 << G_P_SHIFT))
				orgy = s32(player.y - (84 << G_P_SHIFT))
				if orgx < 0:
					orgx = 0
				if orgy < 0:
					orgy = 0

				VW_FadeOut()
				fadecount = 0
				RF_SetRefreshHook(&"FadeAndUnhook")
				call(RF_NewPosition, u16(orgx), u16(orgy))
				CalcInactivate()
			else:
				VW_FixRefreshBuffer()
				US_CenterWindow(20, 8)
				US_CPrint("Loading")
				VW_UpdateScreen()
				gamestate.bombsthislevel = 0
				SetupGameLevel(true)
			if quitting:
				return

			PlayLoop()
			if quitting:
				return

			if loadedgame:
				startlevel = true
				continue

			match playstate:
				warptolevel:
					startlevel = true

				died:
					HandleDeath()

				levelcomplete:
					if mapon:
						SD_PlaySound(LEVELDONESND)
					gamestate.leveldone[mapon] = true    # finished the level
					if mapon != 0:
						gamestate.mapon = 0

				resetgame:
					return

				victorious:
					GameFinale()
					finale = true    # goto done

		if quitting:
			return
		if finale or not (gamestate.lives > -1 and playstate != victorious):
			break

	if quitting:
		return
	if not finale:
		GameOver()

	# done:
	cities = 0
	for i: int in range(1, 17):
		if gamestate.leveldone[i]:
			cities += 1
	US_CheckHighScore(gamestate.score, cities)
	VW_ClearVideo(FIRSTCOLOR)


## (REFKEEN) Version-specific settings: the objects' 16-bit offsets and the unnamed levels'
## names (current_gamever_int must be patched first).
func RefKeen_Patch_kd_play() -> void:
	match refkeen_current_gamever:
		BE_GAMEVER_KDREAMSE100:
			refkeen_compat_kd_play_objoffset = 0x7144
		BE_GAMEVER_KDREAMSE193:
			refkeen_compat_kd_play_objoffset = 0x707A

	if current_gamever_int == 100:
		levelnames[6] = ""
		levelnames[8] = ""
		levelnames[11] = ""
		levelnames[13] = ""
	else:
		levelnames[6] = "Level 6"
		levelnames[8] = "Level 8"
		levelnames[11] = "Level 11"
		levelnames[13] = "Level 13"


# ===================================================================== kd_def.h (REFKEEN)

## BACKWARDS COMPATIBILITY: an object as the 16-bit offset the original keeps in a temp field.
func COMPAT_OBJ_CONVERT_OBJ_PTR_TO_DOS_PTR(objptr: objtype) -> int:
	if objptr == null:
		return 0
	return u16(u16(objptr.index) * COMPAT_OBJ_CONVERSION_SIZE + refkeen_compat_kd_play_objoffset)


## BACKWARDS COMPATIBILITY: the object a 16-bit offset in a temp field names (null for 0).
func COMPAT_OBJ_CONVERT_DOS_PTR_TO_OBJ_PTR(dosptr: int) -> objtype:
	if u16(dosptr) == 0:
		return null
	@warning_ignore("integer_division")
	var i: int = u16(u16(dosptr) - refkeen_compat_kd_play_objoffset) / COMPAT_OBJ_CONVERSION_SIZE
	# (an offset outside objarray is dummyobj's: the original's pointer to it converts back to it)
	return objarray[i] if i < objarray.size() else dummyobj


## (REFKEEN) statetype_ptr_conversion.c's lookup: the state whose 16-bit offset in the original's
## data segment is `dosptr` (compatdospointer), null for none.
func RefKeen_GetObjStatePtrFromDOSPointer(dosptr: int) -> statetype:
	if dosptr == 0:
		return null
	for st: Variant in states.values():
		if st != null and (st as statetype).compatdospointer == dosptr:
			return st
	return null


# ===================================================================== soft.c

const ct_NONE: int = 0
const ct_LZW: int = 1
const ct_LZH: int = 2
const COMP: String = "COMP"
const CMP1: String = "CMP1"
## sl_file.h's IDs as read little-endian
const ID_SLIB: int = 0x42494C53
const ID_CHUNK: int = 0x4B4E5543

var lzwBIO: BufferedIO = BufferedIO.new()


## Loads a file of the given library into the memory the memptr holder names. `MemPtr`: the C's
## memptr variable as [key (its block in the memory manager), bytes (empty for NULL)]. Returns the
## bytes (empty for NULL).
func LoadLIBFile(LibName: String, FileName: String, MemPtr: Array) -> PackedByteArray:
	var handle: BE_FILE_T = BE_Cross_open_readonly_for_reading(LibName)
	if not BE_Cross_IsFileValid(handle):
		return PackedByteArray()

	# Throw out error if this isn't a library file.
	var r: Array = BE_Cross_readInt32LE(handle, 0)
	if r[0] < 4:
		BE_Cross_close(handle)
		return PackedByteArray()
	if r[1] != ID_SLIB:
		BE_Cross_close(handle)
		return PackedByteArray()

	# Read in the library header (struct SoftLibHdr: Version, FileCount)
	var hdr: PackedByteArray = PackedByteArray()
	if BE_Cross_readInt8LEBuffer(handle, hdr, 4) < 4:
		Quit("read error in LoadSLIBFile()\n")
		return PackedByteArray()
	var Version: int = hdr.decode_u16(0)
	var FileCount: int = hdr.decode_u16(2)

	if Version > SOFTLIB_VER:
		Quit("Unsupported file ver ")
		return PackedByteArray()

	# Now Scan through the library for the file (struct FileEntryHdr, 30 bytes each)
	var found: bool = false
	var Offset: int = 0
	var EntryChunkLen: int = 0
	var OrginalLength: int = 0
	for x: int in range(1, s16(FileCount) + 1):
		var e: PackedByteArray = PackedByteArray()
		if BE_Cross_readInt8LEBuffer(handle, e, 30) < 30:
			BE_Cross_close(handle)
			return PackedByteArray()
		var name: String = _cstring(e.slice(0, SL_FILENAMESIZE))    # may not be null terminated
		if name.to_upper() == FileName.to_upper():
			Offset = e.decode_u32(16)
			EntryChunkLen = e.decode_u32(20)
			OrginalLength = e.decode_u32(24)
			found = true

	# Load the header (struct ChunkHeader: HeaderID, OrginalLength, Compression)
	if found:
		handle.pos += Offset    # SEEK_CUR

		var ch: PackedByteArray = PackedByteArray()
		if BE_Cross_readInt8LEBuffer(handle, ch, 10) < 10:
			Quit("LIB File - Unable to read Header!")
			return PackedByteArray()
		if ch.decode_u32(0) != ID_CHUNK:
			Quit("LIB File - BAD HeaderID!")
			return PackedByteArray()
		var Compression: int = ch.decode_s16(8)

		# Allocate memory if Necessary
		if (MemPtr[1] as PackedByteArray).is_empty():
			MM_GetPtr(MemPtr[0], OrginalLength)
			var mem: PackedByteArray = PackedByteArray()
			mem.resize(OrginalLength)
			MemPtr[1] = mem

		# Calculate the length of the data (without the chunk header).
		var ChunkLen: int = u32(EntryChunkLen - 10)

		# Extract Data from file
		match Compression:
			ct_LZH:
				if InitBufferedIO(handle, lzwBIO).is_empty():
					Quit("No memory for buffered I/O.")
					return PackedByteArray()
				lzhDecompress(lzwBIO, [MemPtr[1], 0], OrginalLength, ChunkLen, SRC_BFILE | DEST_MEM)
				FreeBufferedIO(lzwBIO)
			ct_NONE:
				if not CA_FarRead(handle, MemPtr[1], ChunkLen):
					MemPtr[1] = PackedByteArray()
			_:
				BE_Cross_close(handle)
				Quit("Unknown Chunk.Compression Type!")
				return PackedByteArray()
	else:
		MemPtr[1] = PackedByteArray()

	BE_Cross_close(handle)
	return MemPtr[1]


## Loads a shape (an IFF ILBM's header and BODY) from a SoftLib file into `SHP`; 0 on success.
func LoadLIBShape(SLIB_Filename: String, Filename: String, SHP: Shape) -> int:
	var RT_CODE: int = 1
	var IFFfile: Array = ["kd:IFFfile", PackedByteArray()]

	# Decompress to ram and return ptr to data and return len of data in passed variable...
	if LoadLIBFile(SLIB_Filename, Filename, IFFfile).is_empty():
		Quit("Error Loading Compressed lib shape!")
		return RT_CODE

	# Evaluate the file
	var iff: PackedByteArray = IFFfile[1]
	var ptr: int = 0
	if not _kd_chunk(iff, ptr, "FORM"):
		return _kd_lib_exit(IFFfile, RT_CODE)
	ptr += 4

	var FileLen: int = _kd_be32(iff, ptr)
	ptr += 4

	if not _kd_chunk(iff, ptr, "ILBM"):
		return _kd_lib_exit(IFFfile, RT_CODE)
	ptr += 4

	FileLen = u32(FileLen + 4)
	while FileLen and not quitting:
		var ChunkLen: int = (_kd_be32(iff, ptr + 4) + 1) & 0xFFFFFFFE

		if _kd_chunk(iff, ptr, "BMHD"):
			ptr += 8
			SHP.bmHdr.w = _kd_be16(iff, ptr)
			SHP.bmHdr.h = _kd_be16(iff, ptr + 2)
			SHP.bmHdr.x = _kd_be16(iff, ptr + 4)
			SHP.bmHdr.y = _kd_be16(iff, ptr + 6)
			SHP.bmHdr.d = _kd_byte(iff, ptr + 8)
			SHP.bmHdr.trans = _kd_byte(iff, ptr + 9)
			SHP.bmHdr.comp = _kd_byte(iff, ptr + 10)
			SHP.bmHdr.pad = _kd_byte(iff, ptr + 11)
			ptr += ChunkLen
		elif _kd_chunk(iff, ptr, "BODY"):
			ptr += 4
			var size: int = _kd_be32(iff, ptr)
			ptr += 4
			SHP.BPR = (SHP.bmHdr.w + 7) >> 3
			if SHP.key == "":
				SHP.key = "kd:shape:" + Filename
			MM_GetPtr(SHP.key, size)
			SHP.Data = iff.slice(ptr, ptr + size)
			if SHP.Data.size() < size:
				SHP.Data.resize(size)    # (past the end of the file: zeros, guarded)
			ptr += ChunkLen
			break
		else:
			ptr += ChunkLen + 8

		FileLen = u32(FileLen - (ChunkLen + 8))

	RT_CODE = 0
	return _kd_lib_exit(IFFfile, RT_CODE)


## LoadLIBShape's EXIT_FUNC: frees the decompressed file.
func _kd_lib_exit(IFFfile: Array, RT_CODE: int) -> int:
	if not (IFFfile[1] as PackedByteArray).is_empty():
		MM_FreePtr(IFFfile[0])
		IFFfile[1] = PackedByteArray()
	return RT_CODE


## CHUNK(Name): the four bytes at `ptr` are Name.
static func _kd_chunk(b: PackedByteArray, ptr: int, tag: String) -> bool:
	for k: int in range(4):
		if _kd_byte(b, ptr + k) != tag.unicode_at(k):
			return false
	return true


static func _kd_byte(b: PackedByteArray, o: int) -> int:
	return b[o] if o >= 0 and o < b.size() else 0


static func _kd_be16(b: PackedByteArray, o: int) -> int:
	return (_kd_byte(b, o) << 8) | _kd_byte(b, o + 1)


static func _kd_be32(b: PackedByteArray, o: int) -> int:
	return (_kd_be16(b, o) << 16) | _kd_be16(b, o + 2)


# ===================================================================== lzhuf.c

## Decompresses `CompressLength` bytes read through ReadPtr into `OrginalLength` bytes written
## through WritePtr. The decoder is SoftLib's (softlib.gd: the same adaptive Huffman tree and the
## C's 16-bit arithmetic); the bytes it reads are fetched first, as many as GetByte/GetBit can
## take. Returns OrginalLength.
func lzhDecompress(infile: Variant, outfile: Variant, OrginalLength: int, CompressLength: int, PtrTypes: int) -> int:
	var src: PackedByteArray = PackedByteArray()
	src.resize(CompressLength)
	for i: int in range(CompressLength):
		src[i] = ReadPtr(infile, PtrTypes) & 0xFF
	var out: PackedByteArray = SoftLib.lzh_decompress(src, 0, CompressLength, OrginalLength)
	cost_n("lzhbyte", OrginalLength)
	for b: int in out:
		WritePtr(outfile, b, PtrTypes)
	return OrginalLength


# ===================================================================== jam_io.c

## Outputs data to a particular ptr type (DEST_TYPES). `outfile`: a BE_FILE_T for DEST_FILE, or
## for DEST_MEM [bytes, offset] (the C's pointer, advanced). For DEST_MEM a 0 is always returned.
func WritePtr(outfile: Variant, data_: int, PtrType: int) -> int:
	var returnval: int = 0

	match PtrType & DEST_TYPES:
		DEST_FILE, DEST_FFILE:
			# REFKEEN: Actually DEST_FFILE but done for compatibility
			returnval = BE_Cross_writeInt8LE(outfile, data_ & 0xFF)
		DEST_IMEM:
			BE_ST_printf("WritePtr - unsupported ptr type\n")
			BE_ST_HandleExit(0)
		DEST_MEM:
			var h: Array = outfile
			var mem: PackedByteArray = h[0]
			if h[1] < mem.size():
				mem[h[1]] = data_ & 0xFF
			h[1] += 1

	return returnval


## Reads data from a particular ptr type (SRC_TYPES). `infile`: a BE_FILE_T for SRC_FILE, a
## BufferedIO for SRC_BFILE, or for SRC_MEM [bytes, offset] (the C's pointer, advanced).
func ReadPtr(infile: Variant, PtrType: int) -> int:
	var returnval: int = 0

	match PtrType & SRC_TYPES:
		SRC_FILE, SRC_FFILE:
			# REFKEEN: Actually SRC_FFILE but done for compatibility
			var r: Array = BE_Cross_readInt8LE(infile, 0)
			returnval = r[1] if r[0] == 1 else -1    # EOF
		SRC_BFILE:
			returnval = bio_readch(infile)
		SRC_MEM:
			var h: Array = infile
			var mem: PackedByteArray = h[0]
			returnval = mem[h[1]] if h[1] < mem.size() else 0
			h[1] += 1

	return returnval


# ===================================================================== id_* functions the library lacks (move to the library)

## id_ca.c: (REFKEEN) the graphics mode and the version's number (the file names are DreamsData's).
func RefKeen_Patch_id_ca() -> void:
	GRMODE = EGAGR    # (the CGA releases are not supported)
	match refkeen_current_gamever:
		BE_GAMEVER_KDREAMSE100:
			current_gamever_int = 100
		BE_GAMEVER_KDREAMSE193:
			current_gamever_int = 193


## id_mm.c: (REFKEEN) the block table's size (DrmCA's manager keeps a list, not a table).
func RefKeen_Patch_id_mm() -> void:
	MAXBLOCKS = 1300


## id_ca.c: the texts and the piracy screen linked into the program (DreamsData reads them from
## the unpacked KDREAMS.EXE); the dictionaries and headers are DreamsData's.
func RefKeen_Load_Embedded_Resources_From_kdreams_exe() -> void:
	gametext = _kd_text(data.game_text)
	context = _kd_text(data.context_text)
	story = _kd_text(data.story_text)
	if current_gamever_int == 100:
		PIRACY = data.piracy_screen


## A text linked into the program, as the String the help screens read (a character per byte).
static func _kd_text(b: PackedByteArray) -> String:
	var s: String = ""
	for v: int in b:
		s += String.chr(v)
	return s


## id_ca.c: reads `length` bytes from the file into `dest`; false if they were not all there.
func CA_FarRead(handle: BE_FILE_T, dest: PackedByteArray, length: int) -> bool:
	if length > 0xffff:
		Quit("CA_FarRead doesn't support 64K reads yet!")
		return false
	var got: int = BE_Cross_readInt8LEBuffer(handle, dest, length)
	return got == length


## id_ca.c: RLEW-compresses `length` bytes of words from `source` into `dest` (grown as written);
## returns the compressed length in bytes.
func CA_RLEWCompress(source: PackedInt32Array, length: int, dest: PackedInt32Array, rlewtag: int) -> int:
	var src: int = 0
	@warning_ignore("integer_division")
	var end: int = (length + 1) / 2
	var out: PackedInt32Array = PackedInt32Array()

	# compress it
	while true:
		var count: int = 1
		var value: int = source[src] if src < source.size() else 0
		src += 1
		while src < end and (source[src] if src < source.size() else 0) == value:
			count += 1
			src += 1
		if count > 3 or value == rlewtag:
			# send a tag / count / value string
			out.append(rlewtag)
			out.append(count & 0xFFFF)
			out.append(value)
		else:
			# send word without compressing
			for i: int in range(count):
				out.append(value)
		if src >= end:
			break

	dest.resize(out.size())
	for i: int in range(out.size()):
		dest[i] = out[i]
	return 2 * out.size()


## id_ca.c: RLEW-expands `source` into `dest` until `length` bytes of it are written (length is the
## expanded length; LoadGame passes the compressed one, as the C).
func CA_RLEWexpand(source: PackedInt32Array, dest: PackedInt32Array, length: int, rlewtag: int) -> void:
	var src: int = 0
	var d: int = 0
	@warning_ignore("integer_division")
	var end: int = length / 2

	# expand it
	while true:
		if src >= source.size():
			break    # (past the source: guarded)
		var value: int = source[src]
		src += 1
		if value != rlewtag:
			# uncompressed
			if d < dest.size():
				dest[d] = value
			d += 1
		else:
			# compressed string
			var count: int = source[src] if src < source.size() else 0
			src += 1
			value = source[src] if src < source.size() else 0
			src += 1
			for i: int in range(count):
				if d < dest.size():
					dest[d] = value
				d += 1
		if d >= end:
			break


# ===================================================================== BE_ST_* / BE_Cross_* the back end lacks (move to drm_be.gd)

## The text attribute BE_ST_textcolor / BE_ST_textbackground set (conio's).
var be_textattr: int = 0x07
## The program ended through BE_ST_HandleExit (exit()): nothing more runs.
var be_exited: bool = false


## conio's clrscr: the text screen blank in the current attribute, the cursor home.
func BE_ST_clrscr() -> void:
	var screen: PackedByteArray = BE_ST_GetTextModeMemoryPtr()
	for i: int in range(0, 4000, 2):
		screen[i] = 0x20
		screen[i + 1] = be_textattr
	BE_ST_MoveTextCursorTo(0, 0)
	BE_ST_MarkGfxForUpdate()


## The text written at the cursor (teletype: newlines, wrapping, scrolling).
func _be_text_out(s: String) -> void:
	var screen: PackedByteArray = BE_ST_GetTextModeMemoryPtr()
	var x: int = textcursor.x
	var y: int = textcursor.y
	for i: int in range(s.length()):
		var ch: int = s.unicode_at(i) & 0xFF
		if ch == 10:
			x = 0
			y += 1
		else:
			var o: int = (y * 80 + x) * 2
			screen[o] = ch
			screen[o + 1] = be_textattr
			x += 1
			if x >= 80:
				x = 0
				y += 1
		if y >= 25:
			# scroll the screen up a line
			for o: int in range(0, 24 * 160):
				screen[o] = screen[o + 160]
			for o: int in range(24 * 160, 25 * 160, 2):
				screen[o] = 0x20
				screen[o + 1] = be_textattr
			y = 24
	BE_ST_MoveTextCursorTo(x, y)
	BE_ST_MarkGfxForUpdate()


## puts: the string and a newline.
func BE_ST_puts(s: String) -> void:
	_be_text_out(s + "\n")


## printf with the arguments already formatted in.
func BE_ST_printf(s: String) -> void:
	_be_text_out(s)


func BE_ST_textcolor(color: int) -> void:
	be_textattr = (be_textattr & 0xF0) | (color & 0x0F)


func BE_ST_textbackground(color: int) -> void:
	be_textattr = (be_textattr & 0x8F) | ((color & 7) << 4)


## The BIOS's INT 16h (command 0): waits for a key and returns its scan code. Only before the
## program takes the keyboard interrupt over (IN_Startup): the BIOS handler takes the key here.
func BE_ST_BiosScanCode(_command: int) -> int:
	var got: Array = [0]
	var saved: Callable = vm.int9
	vm.int9 = func() -> void:
		var k: int = vm.in8(0x60)
		if k < 0x80 and got[0] == 0:
			got[0] = k
	while got[0] == 0 and not quitting:
		BE_ST_ShortSleep()
	vm.int9 = saved
	return got[0]


## exit(): the program ends here (nothing after it runs).
func BE_ST_HandleExit(_status: int) -> void:
	be_exited = true
	quitting = true


## BE_Cross_writeInt16LEBuffer: `nbytes` bytes of the words in `src`; the count written.
func BE_Cross_writeInt16LEBuffer(fp: BE_FILE_T, src: PackedInt32Array, nbytes: int) -> int:
	var b: PackedByteArray = PackedByteArray()
	b.resize(nbytes)
	for k: int in range(nbytes):
		var w: int = src[k >> 1] if (k >> 1) < src.size() else 0
		b[k] = (w >> (8 * (k & 1))) & 0xFF
	return BE_Cross_writeInt8LEBuffer(fp, b, nbytes)


## BE_Cross_readInt16LEBuffer: `nbytes` bytes into the words of `dst` (grown if the C would
## overrun it); the count read.
func BE_Cross_readInt16LEBuffer(fp: BE_FILE_T, dst: PackedInt32Array, nbytes: int) -> int:
	var b: PackedByteArray = PackedByteArray()
	var n: int = BE_Cross_readInt8LEBuffer(fp, b, nbytes)
	if dst.size() < (n + 1) >> 1:
		dst.resize((n + 1) >> 1)
	for k: int in range(n):
		var sh: int = 8 * (k & 1)
		dst[k >> 1] = (dst[k >> 1] & ~(0xFF << sh)) | (b[k] << sh)
	return n


## BE_Cross_write_booleans_To16LEBuffer: each boolean as a 16-bit 0 or 1, `nbytes` bytes in all.
func BE_Cross_write_booleans_To16LEBuffer(fp: BE_FILE_T, src: Array[bool], nbytes: int) -> int:
	var b: PackedByteArray = PackedByteArray()
	b.resize(nbytes)
	for k: int in range(nbytes >> 1):
		b[k * 2] = 1 if (k < src.size() and src[k]) else 0
	return BE_Cross_writeInt8LEBuffer(fp, b, nbytes)


## BE_Cross_read_booleans_From16LEBuffer: `nbytes` bytes of 16-bit booleans into `dst`; the count
## read (a boolean whose two bytes were not both read is unchanged).
func BE_Cross_read_booleans_From16LEBuffer(fp: BE_FILE_T, dst: Array[bool], nbytes: int) -> int:
	var b: PackedByteArray = PackedByteArray()
	var n: int = BE_Cross_readInt8LEBuffer(fp, b, nbytes)
	for k: int in range(n >> 1):
		if k < dst.size():
			dst[k] = (b[k * 2] | (b[k * 2 + 1] << 8)) != 0
	return n


# ===================================================================== start-up (ReflectionHLE's)

## Breaks the reference cycles the program's structures hold (the object list's prev/next, the
## states' nextstate loops, the sprite records' owners) so the RefCounted objects can be freed:
## call once a run is over (the program is not usable afterwards). Not part of the C.
func release_links() -> void:
	for o: Variant in objarray:
		var ob: objtype = o
		ob.next = null
		ob.prev = null
		ob.state = null
		ob.temp2stateptr = null
		ob.sprite = null
	objarray = []
	for o: objtype in [dummyobj, newobj, check, player, scoreobj, lastobj, objfreelist]:
		if o != null:
			o.next = null
			o.prev = null
			o.state = null
			o.temp2stateptr = null
			o.sprite = null
	newobj = null
	check = null
	player = null
	scoreobj = null
	lastobj = null
	objfreelist = null
	for st: Variant in states.values():
		if st != null:
			(st as statetype).nextstate = null
	states = {}


## Whether this object's class (DrmGame or a script after it) defines `fn` (a stub of DrmDecl's
## does not count).
func _defined_after_decl_drm(fn: StringName) -> bool:
	var s: Script = get_script()
	var decl: Script = load("res://games/dreams/drm_decl.gd")
	while s != null and s != decl:
		if s.source_code.contains("\nfunc %s(" % fn):
			return true
		s = s.get_base_script()
	return false


## The program: what ReflectionHLE does to start Keen Dreams (be_startup.c's BE_Cross_InitGame
## and BEL_Cross_DoCallMainFunc), then main (kdreams_exe_main), then the rest of Quit. `argv`: the
## command line after the program's name. The version comes from DreamsData's identification.
func kd_main_entry(argv: PackedStringArray) -> void:
	id0_argv = argv
	match data.version:
		"e100":
			refkeen_current_gamever = BE_GAMEVER_KDREAMSE100
			current_gamever_int = 100
		"e193":
			refkeen_current_gamever = BE_GAMEVER_KDREAMSE193
			current_gamever_int = 193
		_:
			Quit("Unsupported version of Keen Dreams: " + data.version)
			return

	# the C's static initialisers
	_kd_static_init()

	# be_gamedefs_kdreams.h's g_be_patcherfuncs_kdreams, in order (RefKeen_Patch_id_ca MUST be
	# first). RefKeen_Patch_id_vw_ac only sets CGA routines: not called (EGA only).
	RefKeen_Patch_id_ca()
	RefKeen_Patch_id_mm()
	RefKeen_Patch_id_us()
	RefKeen_Patch_id_rf()
	RefKeen_Patch_id_rf_a()
	RefKeen_Patch_id_vw()
	RefKeen_Patch_id_vw_ae()
	RefKeen_Patch_kd_demo()
	if _defined_after_decl_drm(&"RefKeen_Patch_kd_keen"):
		RefKeen_Patch_kd_keen()
	else:
		push_warning("DrmGame: RefKeen_Patch_kd_keen is not ported yet; skipped")
	RefKeen_Patch_kd_play()
	# statetype_ptr_conversion.c (DreamsGame's): the states' 16-bit offsets for this version
	if has_method(&"RefKeen_FillObjStatesWithDOSPointers"):
		call(&"RefKeen_FillObjStatesWithDOSPointers")

	# the EXE's embedded resources (g_be_exefiles_kdreamse*'s loader)
	RefKeen_Load_Embedded_Resources_From_kdreams_exe()

	kdreams_exe_main()

	# the C's Quit, past its flag: the managers shut down and the message shown
	if quitting and not be_exited:
		_Quit_kd_main(quit_message)


# ===================================================================== HARN-23: the verify harness's trace

var _kl_file: FileAccess = null


## kd_demo.c's KL_WARP block at the demo loop's entry (and kl_init: the record opened, the random index
## at 0): a new game straight into kl_warp's level, then the program ends. False when there is no warp.
func _kl_warp_into_level() -> bool:
	if kl_record != "" and _kl_file == null:
		_kl_file = FileAccess.open(kl_record, FileAccess.WRITE)
		rndindex = 0
	if kl_warp < 0 or kl_warp >= GAMELEVELS:
		return false
	US_SetLoadSaveHooks(&"LoadGame", &"SaveGame", &"ResetGame")
	NewGame()
	gamestate.mapon = kl_warp
	GameLoop()
	Quit("")
	return true


## KL_FrameInput's record: KL_Frame as MSVC lays it out (24 bytes: the tics, eight 16-bit fields,
## lasttimecount's low 16 bits, the 32-bit hash). The odd-tic loops read lasttimecount's parity, so the
## replay sets its clock from it.
func _kl_frame(c: CursorInfo) -> void:
	var b: PackedByteArray = PackedByteArray()
	b.resize(24)
	b.encode_u16(0, tics & 0xFFFF)
	var fields: Array = [int(c.button0), int(c.button1), c.x, c.y, c.xaxis, c.yaxis, c.dir, LastScan]
	for i: int in range(8):
		b.encode_u16(2 + i * 2, int(fields[i]) & 0xFFFF)
	b.encode_u16(18, lasttimecount & 0xFFFF)
	b.encode_u32(20, _kl_state_hash())
	_kl_file.store_buffer(b)
	_kl_file.flush()


## kl_state_hash: FNV-1a over every live object, the game state, the origin and the random index, in
## kl_verify.c's order and sizes (16-bit fields, 32-bit score and next extra, leveldone as 17 one-byte bools).
func _kl_state_hash() -> int:
	var b: PackedByteArray = PackedByteArray()
	var put16: Callable = func(v: int) -> void:
		b.append(v & 0xFF)
		b.append((v >> 8) & 0xFF)
	var put32: Callable = func(v: int) -> void:
		for k: int in range(4):
			b.append((v >> (8 * k)) & 0xFF)
	var ob: objtype = player
	while ob != null:
		for v: int in [ob.obclass, ob.active, int(ob.needtoclip), ob.nothink, ob.x, ob.y, ob.xdir, ob.ydir, ob.xmove,
				ob.ymove, ob.xspeed, ob.yspeed, ob.ticcount, ob.ticadjust,
				ob.state.compatdospointer if ob.state != null else 0, ob.shapenum, ob.left, ob.top, ob.right, ob.bottom,
				ob.hitnorth, ob.hiteast, ob.hitsouth, ob.hitwest, ob.temp1, ob.temp2, ob.temp3, ob.temp4]:
			put16.call(v)
		ob = ob.next
	put16.call(gamestate.worldx)
	put16.call(gamestate.worldy)
	for done: bool in gamestate.leveldone:
		b.append(1 if done else 0)
	put32.call(gamestate.score)
	put32.call(gamestate.nextextra)
	for v: int in [gamestate.flowerpowers, gamestate.boobusbombs, gamestate.bombsthislevel, gamestate.keys,
			gamestate.mapon, gamestate.lives, gamestate.difficulty, originxglobal, originyglobal, rndindex]:
		put16.call(v)
	var h: int = 2166136261
	for x: int in b:
		h = ((h ^ x) * 16777619) & 0xFFFFFFFF
	return h

