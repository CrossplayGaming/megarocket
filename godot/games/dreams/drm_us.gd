# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's user manager (id_us.c, id_us_a.c, the version's start-up screen file, gelib.c) as carried in ReflectionHLE, (C) 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
class_name DrmUS
extends DrmIO
## id_us*.c and gelib.c: windows, printing, menus, the control panel, config and saved games.
## EGA releases v1.00 and v1.93 only: the 2015 release's paths (its panels, USL_CtlGButtonCustom),
## ReflectionHLE's alternative controllers and the KeenLauncher hooks are left out. The text-mode
## start screen writes to `textmem`, the 32 KB at B800:0000 as the processor sees it (character,
## attribute pairs): the EgaCard does not model the text mode's memory, so the script keeps it and
## the shell shows it. Files (the config, saved games, KDREAMS.CMP for gelib's reads) are byte
## buffers in `us_files` that the shell supplies and keeps (A11), read and written in the C's
## layout. Strings are Strings with one character per byte (codes 0-255); C's fixed char arrays
## that are written whole to files are PackedByteArrays, so what strcpy leaves behind stays.
## Measuring and printing go through DrmVW's convention: measure(s, optsend, w, h) returns
## [w, h], optsend -1 for the C's NULL.

# ===================================================================== id_us.c

const EXTENSION: String = "KDR"    # id_heads.h
const MaxX: int = 320
const MaxY: int = 200
const MaxHelpLines: int = 500
const MaxHighName: int = 57
const MaxScores: int = 10
const MaxGameName: int = 32
const MaxSaveGames: int = 7
# Borland's errno values the code tests
const ENOENT: int = 2
const ENOMEM: int = 8


class HighScore:
	var name: PackedByteArray = PackedByteArray()    # char[MaxHighName + 1]
	var score: int = 0        # long
	var completed: int = 0    # word

	func _init(s: int = 0) -> void:
		name.resize(58)
		score = s

	func copy_from(o: HighScore) -> void:
		name = o.name.duplicate()
		score = o.score
		completed = o.completed


## C's SaveGame (renamed: kd_demo.c's SaveGame function has the name).
class US_SaveGame:
	var signature: PackedByteArray = PackedByteArray()    # char[4]
	var present: bool = false
	var name: PackedByteArray = PackedByteArray()         # char[MaxGameName + 1]

	func _init() -> void:
		signature.resize(4)
		name.resize(33)


# (REFKEEN) the config file's name, by version (RefKeen_Patch_id_us)
var refkeen_compat_config_filename: String = ""

const ParmStrings: PackedStringArray = ["TEDLEVEL", ""]

# internal variables
var US_Started: bool = false
var GameIsDirty: bool = false
var HighScoresDirty: bool = false
var QuitToDos: bool = false
var ResumeGame: bool = false
## LineOffsets (memptr): the help text's line starts; empty when not allocated
var LineOffsets: PackedInt32Array = PackedInt32Array()
var Button0: bool = false
var Button1: bool = false
var CursorBad: bool = false
var CursorX: int = 0
var CursorY: int = 0
var USL_MeasureString: StringName = &"VW_MeasurePropString"
var USL_DrawString: StringName = &"VWB_DrawPropString"
var USL_SaveGame: StringName = &""
var USL_LoadGame: StringName = &""
var USL_ResetGame: StringName = &""
var Games: Array = _us_new_games()
var Scores: Array = _us_new_scores()
## Borland's errno, as the file functions below leave it
var errno: int = 0
## US_CenterSaveWindow's saved backgrounds, by the memptr's key
var us_savedwindows: Dictionary = {}


static func _us_new_games() -> Array:
	var a: Array = []
	for i: int in range(MaxSaveGames):
		a.append(US_SaveGame.new())
	return a


static func _us_new_scores() -> Array:
	var a: Array = []
	for i: int in range(MaxScores):
		a.append(HighScore.new(10000))
	return a


# ---- C string helpers (one character per byte)

## The C string at `off` in a byte buffer (to its NUL or the end).
static func _cstring(b: PackedByteArray, off: int = 0) -> String:
	var s: String = ""
	var i: int = off
	while i < b.size() and b[i] != 0:
		s += String.chr(b[i])
		i += 1
	return s


## strcpy into a byte buffer (grown if the C would overrun it).
static func _strcpy(dst: PackedByteArray, s: String) -> void:
	if dst.size() < s.length() + 1:
		dst.resize(s.length() + 1)
	for i: int in range(s.length()):
		dst[i] = s.unicode_at(i) & 0xFF
	dst[s.length()] = 0


## A String's bytes, `n` of them (memcpy from a C string: zeros past its end).
static func _bytes_of(s: String, n: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(n)
	for i: int in range(mini(n, s.length())):
		b[i] = s.unicode_at(i) & 0xFF
	return b


static func _isalpha(ch: int) -> bool:
	return (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122)


static func _isprint(ch: int) -> bool:
	return ch >= 0x20 and ch <= 0x7E


## The measuring routine's [w, h].
func _measure(s: String, optsend: int) -> PackedInt32Array:
	return call(USL_MeasureString, s, optsend, 0, 0)


## IN_KeyDown and IN_ClearKey (id_in.h's macros).
func _keydown(code: int) -> bool:
	return code >= 0 and code < Keyboard.size() and Keyboard[code]


func _clearkey(code: int) -> void:
	if code >= 0 and code < Keyboard.size():
		Keyboard[code] = false
	if code == LastScan:
		LastScan = sc_None


## KbdDefs[0], made if the input manager has not made it yet.
func _kbddef0() -> KeyboardDef:
	if KbdDefs.is_empty():
		KbdDefs.append(KeyboardDef.new())
	return KbdDefs[0]


## Returns the filename to use for the specified save game.
func USL_GiveSaveName(game: int) -> String:
	return "SAVEGM" + String.chr((game + 48) & 0xFF) + "." + EXTENSION


## Sets the routines that the User Mgr calls after reading or writing the save game headers.
func US_SetLoadSaveHooks(load: StringName, save: StringName, reset: StringName) -> void:
	USL_LoadGame = load
	USL_SaveGame = save
	USL_ResetGame = reset


## Reads the configuration file (with the high scores), if present; else uses defaults.
func USL_ReadConfig() -> void:
	var gotit: bool
	var sd: int = 0
	var sm: int = 0
	var ctl: int = 0
	var file: BE_FILE_T = BE_Cross_open_rewritable_for_reading(refkeen_compat_config_filename)
	if BE_Cross_IsFileValid(file):
		for i: int in range(MaxScores):
			var hs: HighScore = Scores[i]
			BE_Cross_readInt8LEBuffer(file, hs.name, MaxHighName + 1)
			hs.score = s32(BE_Cross_readInt32LE(file, hs.score)[1])
			hs.completed = u16(BE_Cross_readInt16LE(file, hs.completed)[1])
		sd = BE_Cross_readInt16LE(file, sd)[1]
		sm = BE_Cross_readInt16LE(file, sm)[1]
		ctl = BE_Cross_readInt16LE(file, ctl)[1]
		# KeyboardDef is a ScanCode array, and ScanCode is simply a byte
		var kd: KeyboardDef = _kbddef0()
		var kb: PackedByteArray = PackedByteArray()
		for k: String in KeyMaps:
			kb.append(int(kd.get(k)) & 0xFF)
		BE_Cross_readInt8LEBuffer(file, kb, KeyMaps.size())
		for j: int in range(KeyMaps.size()):
			kd.set(KeyMaps[j], kb[j])
		BE_Cross_close(file)

		HighScoresDirty = false
		gotit = true
	else:
		sd = sdm_Off
		sm = smm_Off
		ctl = ctrl_Keyboard

		gotit = false
		HighScoresDirty = true

	SD_Default(gotit, sd, sm)
	IN_Default(gotit, ctl)


## Writes out the current configuration, including the high scores.
func USL_WriteConfig() -> void:
	var file: BE_FILE_T = BE_Cross_open_rewritable_for_overwriting(refkeen_compat_config_filename)
	if BE_Cross_IsFileValid(file):
		for i: int in range(MaxScores):
			var hs: HighScore = Scores[i]
			BE_Cross_writeInt8LEBuffer(file, hs.name, MaxHighName + 1)
			BE_Cross_writeInt32LE(file, hs.score)
			BE_Cross_writeInt16LE(file, hs.completed)
		BE_Cross_writeInt16LE(file, SoundMode)
		BE_Cross_writeInt16LE(file, MusicMode)
		BE_Cross_writeInt16LE(file, Controls[0])
		var kd: KeyboardDef = _kbddef0()
		var kb: PackedByteArray = PackedByteArray()
		for k: String in KeyMaps:
			kb.append(int(kd.get(k)) & 0xFF)
		BE_Cross_writeInt8LEBuffer(file, kb, KeyMaps.size())
		BE_Cross_close(file)


## The saved game header (signature, present, name, one byte of struct padding) read from `file`;
## true if all of it was there.
func _us_read_game_header(file: BE_FILE_T, game: US_SaveGame) -> bool:
	if BE_Cross_readInt8LEBuffer(file, game.signature, 4) != 4:
		return false
	var r: Array = BE_Cross_read_boolean_From16LE(file, game.present)
	game.present = r[1]
	if r[0] != 2:
		return false
	if BE_Cross_readInt8LEBuffer(file, game.name, MaxGameName + 1) != MaxGameName + 1:
		return false
	return BE_Cross_readInt8LE(file, 0)[0] == 1    # padding


## strcmp(game->signature, EXTENSION) == 0
static func _us_signature_ok(game: US_SaveGame) -> bool:
	return _cstring(game.signature) == EXTENSION and game.signature[3] == 0


## Checks to see which saved games are present & valid.
func USL_CheckSavedGames() -> void:
	USL_SaveGame = &""
	USL_LoadGame = &""

	for i: int in range(MaxSaveGames):
		var game: US_SaveGame = Games[i]
		var filename: String = USL_GiveSaveName(i)
		var ok: bool = false
		var file: BE_FILE_T = BE_Cross_open_rewritable_for_reading(filename)
		if BE_Cross_IsFileValid(file):
			if _us_read_game_header(file, game) and _us_signature_ok(game):
				ok = true

			BE_Cross_close(file)

		if ok:
			game.present = true
		else:
			_strcpy(game.signature, EXTENSION)
			game.present = false
			_strcpy(game.name, "Empty")


## Starts the User Mgr.
func US_Startup() -> void:
	if US_Started:
		return

	US_InitRndT(true)    # Initialize the random number generator

	USL_ReadConfig()    # Read config file

	US_Started = true


## Does the disk access part of the User Mgr's startup.
func US_Setup() -> void:
	USL_CheckSavedGames()    # Check which saved games are present


## Shuts down the User Mgr.
func US_Shutdown() -> void:
	if not US_Started:
		return

	if abortprogram == "":
		USL_WriteConfig()

	US_Started = false


## Checks to see if a string matches one of a set of strings (each a prefix of `parm`, case
## insensitive, after `parm`'s leading non-letters). Returns the index of the string that
## matched, or -1. `strings` ends at its end or at an empty string.
func US_CheckParm(parm: String, strings: PackedStringArray) -> int:
	var p0: int = 0
	while p0 < parm.length() and not _isalpha(parm.unicode_at(p0)):    # Skip non-alphas
		p0 += 1

	var i: int = 0
	while i < strings.size() and strings[i] != "":
		var s: String = strings[i]
		var k: int = 0
		while true:
			if k >= s.length():
				return i
			var cs: int = s.unicode_at(k)
			var cp: int = parm.unicode_at(p0 + k) if p0 + k < parm.length() else 0
			if cs >= 65 and cs <= 90:
				cs += 32
			if cp >= 65 and cp <= 90:
				cp += 32
			if cs != cp:
				break
			k += 1
		i += 1
	return -1


## Draws a chunk of the text screen (called only by US_TextScreen()).
func USL_ScreenDraw(x: int, y: int, s: String, attr: int) -> void:
	var screen: PackedByteArray = BE_ST_GetTextModeMemoryPtr()
	var o: int = u16(x * 2 + y * 80 * 2)
	for i: int in range(s.length()):
		screen[o & 0x7FFF] = s.unicode_at(i) & 0xFF
		screen[(o + 1) & 0x7FFF] = attr & 0xFF
		o += 2
	BE_ST_MarkGfxForUpdate()


## Makes sure the screen is in text mode, clears it, and moves the cursor to the leftmost column
## of the bottom line.
func USL_ClearTextScreen() -> void:
	# Set to 80x25 color text mode
	BE_ST_SetScreenMode(3)    # Mode 3
	_be_text_mode_set()
	# Move the cursor to the bottom of the screen
	BE_ST_MoveTextCursorTo(0, 24)


## Puts up the startup text screen. These are the only User Manager functions that can be safely
## called before the User Mgr has been started up.
func US_TextScreen() -> void:
	USL_ClearTextScreen()

	# the version's id_us_s*.c: scr_rowcol(y,x) then scr_aputs(s,a)
	var screen: Array = []
	match refkeen_current_gamever:
		BE_GAMEVER_KDREAMSE100:
			screen = US_S_KDREAMS100
		BE_GAMEVER_KDREAMSE193:
			screen = US_S_KDREAMS192ANDLATER
	for e: Array in screen:
		var sx: int = int(e[1]) - 1
		var sy: int = int(e[0]) - 1
		USL_ScreenDraw(sx, sy, e[2], e[3])

	# Check for TED launching here
	for i: int in range(1, id0_argc()):
		if US_CheckParm(id0_argv[i - 1], ParmStrings) == 0:
			# atoi(id0_argv[i + 1]) into a word: never negative
			var arg: String = id0_argv[i] if i < id0_argv.size() else ""
			tedlevelnum = u16(arg.to_int())
			if tedlevelnum >= 0:
				tedlevel = true
				return
			else:
				break


## Changes the appearance of one of the fields on the text screen. Possibly adds a checkmark in
## front of it and highlights it.
func USL_Show(x: int, y: int, w: int, show: bool, hilight: bool) -> void:
	var screen: PackedByteArray = BE_ST_GetTextModeMemoryPtr()
	var o: int = u16((x - 1) * 2 + y * 80 * 2)
	screen[o & 0x7FFF] = 251 if show else 32    # Checkmark char or space
	o += 1
	screen[o & 0x7FFF] = 0x48
	if show and hilight:
		w = u16(w + 1)
		while w:
			w -= 1
			screen[o & 0x7FFF] = 0x4f
			o += 2
	BE_ST_MarkGfxForUpdate()


## Right justifies a longword in one of the memory fields on the text screen.
func USL_ShowMem(x: int, y: int, mem: int) -> void:
	var buf: String = "%d" % s32(mem)
	var i: int = buf.length()
	while i < 5:
		USL_ScreenDraw(x, y, " ", 0x48)
		x += 1
		i += 1
	USL_ScreenDraw(x, y, buf, 0x48)


## Called after the ID libraries are started up. Displays what hardware is present.
func US_UpdateTextScreen() -> void:
	var b: bool
	# Show video card info
	b = (grmode == CGAGR)
	USL_Show(21, 7, 4, (videocard >= CGAcard) and (videocard <= VGAcard), b)
	b = (grmode == EGAGR)
	USL_Show(21, 8, 4, (videocard >= EGAcard) and (videocard <= VGAcard), b)
	b = (grmode == VGAGR)
	USL_Show(21, 9, 4, videocard == VGAcard, b)
	if compatability:
		USL_ScreenDraw(5, 10, "SVGA Compatibility Mode Enabled.", 0x4f)

	# Show input device info
	USL_Show(60, 7, 8, true, true)
	USL_Show(60, 8, 11, JoysPresent[0], true)
	USL_Show(60, 9, 11, JoysPresent[1], true)
	USL_Show(60, 10, 5, MousePresent, true)

	# Show sound hardware info
	USL_Show(21, 14, 11, true, SoundMode == sdm_PC)
	b = (SoundMode == sdm_AdLib) or (MusicMode == smm_AdLib)
	USL_Show(21, 15, 5, AdLibPresent and not SoundBlasterPresent, b and not SoundBlasterPresent)
	USL_Show(21, 16, 13, SoundBlasterPresent, SoundBlasterPresent and (b or (SoundMode == sdm_SoundBlaster)))
	USL_Show(21, 17, 13, SoundSourcePresent, SoundMode == sdm_SoundSource)

	# Show memory available/used
	@warning_ignore("integer_division")
	USL_ShowMem(63, 15, mminfo.mainmem / 1024)
	USL_Show(53, 15, 23, true, true)
	@warning_ignore("integer_division")
	USL_ShowMem(63, 16, mminfo.EMSmem / 1024)
	USL_Show(53, 16, 23, mminfo.EMSmem != 0, true)
	@warning_ignore("integer_division")
	USL_ShowMem(63, 17, mminfo.XMSmem / 1024)
	USL_Show(53, 17, 23, mminfo.XMSmem != 0, true)
	var totalmem: int = u32(mminfo.mainmem + mminfo.EMSmem + mminfo.XMSmem)
	@warning_ignore("integer_division")
	USL_ShowMem(63, 18, totalmem / 1024)
	var screen: PackedByteArray = BE_ST_GetTextModeMemoryPtr()
	var o: int = 1 + ((63 - 1) * 2) + (18 * 80 * 2)
	for i: int in range(13):
		screen[o] = 0x4f
		o += 2
	BE_ST_MarkGfxForUpdate()

	# Change Initializing... to Loading...
	USL_ScreenDraw(27, 22, "  Loading...   ", 0x9c)


## After the main program has finished its initial loading, waits for a keypress and then
## clears the screen.
func US_FinishTextScreen() -> void:
	# Change Loading... to Press a Key
	if current_gamever_int == 100:
		USL_ScreenDraw(29, 22, " Ready - Press a Key     ", 0x9a)
	else:
		USL_ScreenDraw(30, 18, "Ready - Press a Key", 0xCE)

	if not tedlevel and not kl_active():    # (kl_verify.c: the harness skips the wait)
		IN_ClearKeysDown()
		IN_Ack()
	IN_ClearKeysDown()

	USL_ClearTextScreen()


# ---- Window/Printing routines

## Sets the routines used to measure and print from within the User Mgr (masked or non-masked fonts).
func US_SetPrintRoutines(measure: StringName, print: StringName) -> void:
	USL_MeasureString = measure
	USL_DrawString = print


## Prints a string in the current window. Newlines are supported.
func US_Print(s: String) -> void:
	var at: int = 0
	var n: int = s.length()
	while at < n:
		var se: int = s.find("\n", at)
		var nl: bool = se >= 0
		if not nl:
			se = n
		var line: String = s.substr(at, se - at)

		var wh: PackedInt32Array = _measure(line, -1)
		px = PrintX
		py = PrintY
		call(USL_DrawString, line, -1)

		at = se
		if nl:
			at += 1

			PrintX = WindowX
			PrintY = u16(PrintY + wh[1])
		else:
			PrintX = u16(PrintX + wh[0])


## Prints an unsigned long.
func US_PrintUnsigned(n: int) -> void:
	US_Print("%d" % u32(n))


## Prints a signed long.
func US_PrintSigned(n: int) -> void:
	US_Print("%d" % s32(n))


## Prints a string in the center of the given rect (word arithmetic, as the 16-bit original).
func USL_PrintInCenter(s: String, r: Rect) -> void:
	var wh: PackedInt32Array = _measure(s, -1)
	var rw: int = u16(r.lr.x - r.ul.x)
	var rh: int = u16(r.lr.y - r.ul.y)

	@warning_ignore("integer_division")
	px = u16(r.ul.x + u16(rw - wh[0]) / 2)
	@warning_ignore("integer_division")
	py = u16(r.ul.y + u16(rh - wh[1]) / 2)
	call(USL_DrawString, s, -1)


## A Rect from its corners.
static func _us_rect(x1: int, y1: int, x2: int, y2: int) -> Rect:
	var r: Rect = Rect.new()
	r.ul.x = x1
	r.ul.y = y1
	r.lr.x = x2
	r.lr.y = y2
	return r


## Prints a string centered in the current window.
func US_PrintCentered(s: String) -> void:
	var r: Rect = _us_rect(WindowX, WindowY, WindowX + WindowW, WindowY + WindowH)
	USL_PrintInCenter(s, r)


## Prints a string centered on the current line and advances to the next line. Newlines are not
## supported. `optse`: one past the end of `s`, -1 for the C's NULL (ReflectionHLE's argument).
func US_CPrintLine(s: String, optse: int) -> void:
	var wh: PackedInt32Array = _measure(s, optse)
	var w: int = wh[0]
	var h: int = wh[1]

	if w > WindowW:
		Quit("US_CPrintLine() - String exceeds width")
		return
	@warning_ignore("integer_division")
	px = u16(WindowX + u16(WindowW - w) / 2)
	py = PrintY
	call(USL_DrawString, s, optse)
	PrintY = u16(PrintY + h)


## Prints a string centered in the current window. Newlines are supported.
func US_CPrint(s: String) -> void:
	var at: int = 0
	var n: int = s.length()
	while at < n and not quitting:
		var se: int = s.find("\n", at)
		var nl: bool = se >= 0
		if not nl:
			se = n

		US_CPrintLine(s.substr(at, se - at), -1)

		at = se
		if nl:
			at += 1


## Clears the current window to white and homes the cursor.
func US_ClearWindow() -> void:
	VWB_Bar(WindowX, WindowY, WindowW, WindowH, WHITE)
	PrintX = WindowX
	PrintY = WindowY


## id_us.h's US_HomeWindow() macro.
func US_HomeWindow() -> void:
	PrintX = WindowX
	PrintY = WindowY


## Draws a frame and sets the current window parms.
func US_DrawWindow(x: int, y: int, w: int, h: int) -> void:
	WindowX = u16(x * 8)
	WindowY = u16(y * 8)
	WindowW = u16(w * 8)
	WindowH = u16(h * 8)

	PrintX = WindowX
	PrintY = WindowY

	var sx: int = u16((x - 1) * 8)
	var sy: int = u16((y - 1) * 8)
	var sw: int = u16((w + 1) * 8)
	var sh: int = u16((h + 1) * 8)

	US_ClearWindow()

	VWB_DrawTile8M(sx, sy, 0)
	VWB_DrawTile8M(sx, u16(sy + sh), 6)
	var i: int = u16(sx + 8)
	while i <= u16(sx + sw - 8):
		VWB_DrawTile8M(i, sy, 1)
		VWB_DrawTile8M(i, u16(sy + sh), 7)
		i = u16(i + 8)
	VWB_DrawTile8M(i, sy, 2)
	VWB_DrawTile8M(i, u16(sy + sh), 8)

	i = u16(sy + 8)
	while i <= u16(sy + sh - 8):
		VWB_DrawTile8M(sx, i, 3)
		VWB_DrawTile8M(u16(sx + sw), i, 5)
		i = u16(i + 8)


## Generates a window of a given width & height in the middle of the screen.
func US_CenterWindow(w: int, h: int) -> void:
	@warning_ignore("integer_division")
	US_DrawWindow(u16((MaxX / 8) - w) / 2, u16((MaxY / 8) - h) / 2, w, h)


## Generates a window of a given width & height in the middle of the screen, saving the
## background into the block `save` (the memptr's key).
func US_CenterSaveWindow(w: int, h: int, save: String) -> void:
	@warning_ignore("integer_division")
	var x: int = u16((MaxX / 8) - w) / 2
	@warning_ignore("integer_division")
	var y: int = u16((MaxY / 8) - h) / 2
	MM_GetPtr(save, (w * h) * CHARWIDTH)
	var mem: PackedByteArray = PackedByteArray()
	mem.resize(u16((w * h) * CHARWIDTH))
	us_savedwindows[save] = mem
	var screen: int = u16(bufferofs + panadjust + _ylookup(y) + (x * CHARWIDTH))
	call(VW_ScreenToMem, screen, mem, w * CHARWIDTH, h)
	@warning_ignore("integer_division")
	US_DrawWindow(u16((MaxX / 8) - w) / 2, u16((MaxY / 8) - h) / 2, w, h)


## Restores the background of the size of the current window from the memory specified by save.
func US_RestoreSaveWindow(save: String) -> void:
	var screen: int = u16(bufferofs + panadjust + _ylookup(WindowY) + (WindowX * CHARWIDTH))
	call(VW_MemToScreen, us_savedwindows.get(save, PackedByteArray()), screen, WindowW * CHARWIDTH, WindowH)
	MM_FreePtr(save)
	us_savedwindows.erase(save)


## Saves the current window parms into a record for later restoration.
func US_SaveWindow(win: WindowRec) -> void:
	win.x = s16(WindowX)
	win.y = s16(WindowY)
	win.w = s16(WindowW)
	win.h = s16(WindowH)

	win.px = s16(PrintX)
	win.py = s16(PrintY)


## Sets the current window parms to those held in the record.
func US_RestoreWindow(win: WindowRec) -> void:
	WindowX = u16(win.x)
	WindowY = u16(win.y)
	WindowW = u16(win.w)
	WindowH = u16(win.h)

	PrintX = u16(win.px)
	PrintY = u16(win.py)


# ---- Cursor routines

## Sets up the cursor for User Mgr use.
func US_StartCursor() -> void:
	var info: CursorInfo = CursorInfo.new()

	VW_SetCursor(CURSORARROWSPR)
	@warning_ignore("integer_division")
	CursorX = MaxX / 2
	@warning_ignore("integer_division")
	CursorY = MaxY / 2
	VW_MoveCursor(CursorX, CursorY)
	VW_ShowCursor()

	IN_ReadCursor(info)    # Dispose of any accumulated movement


## Cleans up after US_StartCursor().
func US_ShutCursor() -> void:
	VW_HideCursor()


## Gets the new cursor position & button states from the Input Mgr and tells the View Mgr where
## the cursor is.
func US_UpdateCursor() -> bool:
	var info: CursorInfo = CursorInfo.new()

	IN_ReadCursor(info)
	if info.x or info.y or CursorBad:
		CursorX = s16(CursorX + info.x)
		if CursorX >= MaxX:
			CursorX = MaxX - 1
		elif CursorX < 0:
			CursorX = 0

		CursorY = s16(CursorY + info.y)
		if CursorY >= MaxY:
			CursorY = MaxY - 1
		elif CursorY < 0:
			CursorY = 0

		VW_MoveCursor(CursorX, CursorY)

		CursorBad = false
	Button0 = info.button0
	Button1 = info.button1
	return Button0 or Button1


# ---- Input routines

## XORs the I-bar text cursor. Used by US_LineInput().
func USL_XORICursor(x: int, y: int, s: String, cursor: int) -> void:
	var buf: String = s.substr(0, cursor)
	var wh: PackedInt32Array = _measure(buf, -1)

	px = u16(x + wh[0] - 1)
	py = u16(y)
	call(USL_DrawString, String.chr(0x80), -1)


## Gets a line of user input at (x,y), the string defaulting to `def` (a String, or null).
## Input is restricted to maxchars chars or maxwidth pixels wide. If the user hits escape (and
## escok is true), nothing is copied into buf, and false is returned. If the user hits return,
## the current string is copied into buf (a C string in the byte buffer), and true is returned.
func US_LineInput(x: int, y: int, buf: PackedByteArray, def: Variant, escok: bool, maxchars: int, maxwidth: int) -> bool:
	var redraw: bool
	var cursorvis: bool
	var cursormoved: bool
	var done: bool
	var result: bool = false
	var s: String
	var olds: String
	var cursor: int
	var lasttime: int

	VW_HideCursor()

	if def != null:
		s = def
	else:
		s = ""
	olds = ""
	cursor = s.length()
	cursormoved = true
	redraw = true

	cursorvis = false
	done = false
	lasttime = SD_GetTimeCount()
	LastASCII = key_None
	LastScan = sc_None

	# SCR-05: with a player at the controls the d-pad types too (PadTextEntry), a letter going in where a
	# typed one may
	var pad: bool = options != null
	var fits: Callable = func(t: String) -> bool:
		return (t.length() < MaxString - 1) and ((not maxchars) or (t.length() < maxchars)) \
			and ((not maxwidth) or (_measure(t, -1)[0] < maxwidth))
	shell_text_entry = pad

	while not done and not quitting:
		if cursorvis:
			USL_XORICursor(x, y, s, cursor)

		BE_ST_ShortSleep()

		var sc: int = LastScan
		LastScan = sc_None
		var ch: int = LastASCII
		LastASCII = key_None

		if pad and PadTextEntry.is_pad(sc):
			var line: Array = PadTextEntry.press(s, cursor, sc, fits)
			redraw = redraw or line[0] != s
			s = line[0]
			cursor = line[1]
			ch = key_None
			cursormoved = true

		match sc:
			sc_LeftArrow:
				if cursor:
					cursor -= 1
				ch = key_None
				cursormoved = true
			sc_RightArrow:
				if cursor < s.length():
					cursor += 1
				ch = key_None
				cursormoved = true
			sc_Home:
				cursor = 0
				ch = key_None
				cursormoved = true
			sc_End:
				cursor = s.length()
				ch = key_None
				cursormoved = true

			sc_Return:
				_strcpy(buf, s)
				done = true
				result = true
				ch = key_None
			sc_Escape:
				if escok:
					done = true
					result = false
				ch = key_None

			sc_BackSpace:
				if cursor:
					s = s.substr(0, cursor - 1) + s.substr(cursor)
					cursor -= 1
					redraw = true
				ch = key_None
				cursormoved = true
			sc_Delete:
				if cursor < s.length():
					s = s.substr(0, cursor) + s.substr(cursor + 1)
					redraw = true
				ch = key_None
				cursormoved = true

			0x4c, sc_UpArrow, sc_DownArrow, sc_PgUp, sc_PgDn, sc_Insert:    # 0x4c: keypad 5
				ch = key_None

		if ch:
			var len: int = s.length()
			var wh: PackedInt32Array = _measure(s, -1)

			if _isprint(ch) and (len < MaxString - 1) and ((not maxchars) or (len < maxchars)) \
					and ((not maxwidth) or (wh[0] < maxwidth)):
				s = s.substr(0, cursor) + String.chr(ch) + s.substr(cursor)
				cursor += 1
				redraw = true

		if redraw:
			px = u16(x)
			py = u16(y)
			call(USL_DrawString, olds, -1)
			olds = s

			px = u16(x)
			py = u16(y)
			call(USL_DrawString, s, -1)

			redraw = false

		if cursormoved:
			cursorvis = false
			lasttime = u32(SD_GetTimeCount() - TickBase)

			cursormoved = false
		@warning_ignore("integer_division")
		if u32(SD_GetTimeCount() - lasttime) > TickBase / 2:
			lasttime = SD_GetTimeCount()

			cursorvis = not cursorvis
		if cursorvis:
			USL_XORICursor(x, y, s, cursor)

		VW_UpdateScreen()

	shell_text_entry = false
	if cursorvis:
		USL_XORICursor(x, y, s, cursor)
	if not result:
		px = u16(x)
		py = u16(y)
		call(USL_DrawString, olds, -1)
	VW_ShowCursor()
	VW_UpdateScreen()

	IN_ClearKeysDown()
	return result


# ---- Control panel routines

var FlushHelp: bool = false
var HelpWindow: WindowRec = WindowRec.new()
var BottomWindow: WindowRec = WindowRec.new()
# UserCall
const uic_Draw: int = 0
const uic_Hit: int = 1
# UIType
const uii_Bad: int = 0
const uii_Button: int = 1
const uii_RadioButton: int = 2
const uii_CheckBox: int = 3
const uii_KeyCap: int = 4
const ui_Normal: int = 0
const ui_Selected: int = 1
const ui_Disabled: int = 2

const CTL_M_ADLIBUPPIC: int = CTL_S_ADLIBUPPIC
const CTL_M_ADLIBDNPIC: int = CTL_S_ADLIBDNPIC


## The structure of a user interaction item. `custom` is the custom routine's name (&"": none).
class UserItem:
	var r: Rect = Rect.new()    # The enclosing rectangle
	var type: int = 0           # The type of item
	var picup: int = 0          # What to draw when up/down
	var picdown: int = 0
	var help: Variant = null    # Floating help string (String or null)
	var key: int = 0            # Key equiv
	var sel: int = 0            # Interaction flags (ui_XXX)
	var custom: StringName = &""
	var text: Variant = null    # Text for some items (String or null)


## The fields of KbdDefs[0] the keycaps define, in the struct's order (KeyMaps[]).
const KeyMaps: PackedStringArray = ["button0", "button1", "upleft", "up", "upright", "left", "right",
	"downleft", "down", "downright"]

# Some macros to make rectangle definition quite a bit less unpleasant
const CtlPanelX: int = 8
const CtlPanelY: int = 4
const CtlPanel2X: int = 8 * 8
const CtlPanel2Y: int = 2 * 8
const CtlPanel3X: int = 8 * 8
const CtlPanel3Y: int = 7 * 8


static func _ui(r: Array, type: int, picup: int, picdown: int, help: Variant, key: int, sel: int,
		custom: StringName, text: Variant = null) -> UserItem:
	var ip: UserItem = UserItem.new()
	ip.r = _us_rect(r[0], r[1], r[2], r[3])
	ip.type = type
	ip.picup = picup
	ip.picdown = picdown
	ip.help = help
	ip.key = key
	ip.sel = sel
	ip.custom = custom
	ip.text = text
	return ip


## {-1,-1,-1,-1,uii_Bad}: the end of a list.
static func _ui_end() -> UserItem:
	return _ui([-1, -1, -1, -1], uii_Bad, 0, 0, null, 0, 0, &"")


static func CtlPanelR(n: int) -> Array:
	return [CtlPanelX, CtlPanelY + (32 * n), CtlPanelX + 40, CtlPanelY + (32 * n) + 32]


static func CtlPanel2R(x: int, y: int) -> Array:
	return [CtlPanel2X + x * 8, CtlPanel2Y + y * 8, CtlPanel2X + 32 + x * 8, CtlPanel2Y + 24 + y * 8]


static func CtlPanel3R(x: int, y: int) -> Array:
	return [CtlPanel3X + x * 8, CtlPanel3Y + y * 8, CtlPanel3X + 32 + x * 8, CtlPanel3Y + 24 + y * 8]


static func CtlPanel3LSR(x: int, y: int) -> Array:
	return [CtlPanel3X + x * 8, CtlPanel3Y + y * 8, CtlPanel3X + 32 + x * 8, CtlPanel3Y + 16 + y * 8]


static func CtlPanel3ER(x: int, y: int) -> Array:
	return [CtlPanel3X + x * 8, CtlPanel3Y + y * 8, CtlPanel3X + 40 + x * 8, CtlPanel3Y + 24 + y * 8]


static func CtlPanelKC3R(x: int, y: int) -> Array:
	return [CtlPanel3X + x * 8, CtlPanel3Y + y * 8, CtlPanel3X + 56 + x * 8, CtlPanel3Y + 32 + y * 8]


static func _ctl_panels() -> Array:
	return [
		_ui(CtlPanelR(0), uii_RadioButton, CTL_STARTUPPIC, CTL_STARTDNPIC, "Start or Resume a Game", sc_None, ui_Normal, &"USL_CtlButtonCustom"),
		_ui(CtlPanelR(1), uii_RadioButton, CTL_HELPUPPIC, CTL_HELPDNPIC, "Get Help With Commander Keen", sc_None, ui_Normal, &"USL_CtlButtonCustom"),
		_ui(CtlPanelR(2), uii_RadioButton, CTL_DISKUPPIC, CTL_DISKDNPIC, "Load / Save / Quit", sc_None, ui_Normal, &"USL_CtlButtonCustom"),
		_ui(CtlPanelR(3), uii_RadioButton, CTL_CONTROLSUPPIC, CTL_CONTROLSDNPIC, "Choose Controls", sc_C, ui_Normal, &"USL_CtlButtonCustom"),
		_ui(CtlPanelR(4), uii_RadioButton, CTL_SOUNDUPPIC, CTL_SOUNDDNPIC, "Select Sound Device", sc_F2, ui_Normal, &"USL_CtlButtonCustom"),
		_ui(CtlPanelR(5), uii_RadioButton, CTL_MUSICUPPIC, CTL_MUSICDNPIC, "Turn Music On / Off", sc_F7, ui_Normal, &"USL_CtlButtonCustom"),
		_ui_end()]


static func _ctl_ppanels() -> Array:
	return [
		_ui(CtlPanel2R(10, 0), uii_RadioButton, CTL_P_NEWGAMEUPPIC, CTL_P_NEWGAMEDNPIC, "Choose Difficulty for the New Game", sc_F5, ui_Normal, &"USL_CtlPButtonCustom"),
		_ui(CtlPanel2R(15, 0), uii_RadioButton, CTL_P_RESUMEUPPIC, CTL_P_RESUMEDNPIC, "Go Back to Current Game", sc_None, ui_Normal, &"USL_CtlPButtonCustom"),
		_ui_end()]


static func _ctl_pspanels() -> Array:
	return [
		_ui(CtlPanel3R(13, 5), uii_Button, CTL_P_MEDUPPIC, CTL_P_MEDDNPIC, "Start New Game in Normal Mode", sc_None, ui_Normal, &"USL_CtlPSButtonCustom"),
		_ui(CtlPanel3R(8, 5), uii_Button, CTL_P_EASYUPPIC, CTL_P_EASYDNPIC, "Start New Game in Easy Mode", sc_None, ui_Normal, &"USL_CtlPSButtonCustom"),
		_ui(CtlPanel3R(18, 5), uii_Button, CTL_P_HARDUPPIC, CTL_P_HARDDNPIC, "Start New Game in Hard Mode", sc_None, ui_Normal, &"USL_CtlPSButtonCustom"),
		_ui_end()]


static func _ctl_prpanels() -> Array:
	return [
		_ui(CtlPanel3R(13, 5), uii_Button, CTL_P_GORESUMEUPPIC, CTL_P_GORESUMEDNPIC, "Resume Current Game", sc_None, ui_Normal, &"USL_CtlPRButtonCustom"),
		_ui_end()]


static func _ctl_hpanels() -> Array:
	return [
		_ui(CtlPanel2R(8, 0), uii_Button, CTL_H_LOSTUPPIC, CTL_H_LOSTDNPIC, "Help Me, I'm Lost!", sc_F1, ui_Normal, &"USL_CtlHButtonCustom"),
		_ui(CtlPanel2R(13, 0), uii_Button, CTL_H_CTRLUPPIC, CTL_H_CTRLDNPIC, "Get Help with Controls", sc_None, ui_Normal, &"USL_CtlHButtonCustom"),
		_ui(CtlPanel2R(18, 0), uii_Button, CTL_H_STORYUPPIC, CTL_H_STORYDNPIC, "Read Story & Game Tips", sc_None, ui_Normal, &"USL_CtlHButtonCustom"),
		_ui_end()]


static func _ctl_dpanels() -> Array:
	return [
		_ui(CtlPanel2R(9, 0), uii_RadioButton, CTL_D_LSGAMEUPPIC, CTL_D_LSGAMEDNPIC, "Load or Save a Game", sc_F6, ui_Normal, &"USL_CtlDButtonCustom"),
		_ui(CtlPanel2R(15, 0), uii_RadioButton, CTL_D_DOSUPPIC, CTL_D_DOSDNPIC, "Exit to DOS", sc_Q, ui_Normal, &"USL_CtlDButtonCustom"),
		_ui_end()]


static func _ctl_dlspanels() -> Array:
	var a: Array = []
	for y: int in range(0, 14, 2):
		a.append(_ui(CtlPanel3LSR(1, y), uii_Button, CTL_D_LOADUPPIC, CTL_D_LOADDNPIC, "Load This Game", sc_None, ui_Normal, &"USL_CtlDLButtonCustom"))
		a.append(_ui(CtlPanel3LSR(6, y), uii_Button, CTL_D_SAVEUPPIC, CTL_D_SAVEDNPIC, "Save Current Game Here", sc_None, ui_Normal, &"USL_CtlDSButtonCustom"))
	a.append(_ui_end())
	return a


static func _ctl_depanels() -> Array:
	return [
		_ui(CtlPanel3ER(12, 5), uii_Button, CTL_D_EXITUPPIC, CTL_D_EXITDNPIC, "Really Exit to DOS", sc_None, ui_Normal, &"USL_CtlDEButtonCustom"),
		_ui_end()]


static func _ctl_cpanels() -> Array:
	return [
		_ui(CtlPanel2R(8, 0), uii_RadioButton, CTL_C_KBDUPPIC, CTL_C_KBDDNPIC, "Use / Configure Keyboard", sc_F3, ui_Normal, &"USL_CtlCButtonCustom"),
		_ui(CtlPanel2R(13, 0), uii_RadioButton, CTL_C_JOY1UPPIC, CTL_C_JOY1DNPIC, "Use / Configure Joystick 1", sc_None, ui_Normal, &"USL_CtlCButtonCustom"),
		_ui(CtlPanel2R(18, 0), uii_RadioButton, CTL_C_JOY2UPPIC, CTL_C_JOY2DNPIC, "Use / Configure Joystick 2", sc_None, ui_Normal, &"USL_CtlCButtonCustom"),
		_ui_end()]


static func _ctl_ckbdpanels() -> Array:
	var where: Array = [[1, 2, "Define Key for Jumping"], [1, 6, "Define Key for Throwing"],
		[8, 0, "Define Key to move Up & Left"], [15, 0, "Define Key to move Up"], [22, 0, "Define Key to move Up & Right"],
		[8, 4, "Define Key to move Left"], [22, 4, "Define Key to move Right"],
		[8, 8, "Define Key to move Down & Left"], [15, 8, "Define Key to move Down"], [22, 8, "Define Key to move Down & Right"]]
	var a: Array = []
	for e: Array in where:
		a.append(_ui(CtlPanelKC3R(e[0], e[1]), uii_KeyCap, CTL_KEYCAPPIC, CTL_KEYCAPCURPIC, e[2], sc_None, ui_Normal, &"USL_CtlCKbdButtonCustom"))
	a.append(_ui_end())
	return a


static func _ctl_cjoypanels() -> Array:
	return [
		_ui(CtlPanel3R(13, 5), uii_Button, CTL_C_CALIBRATEUPPIC, CTL_C_CALIBRATEDNPIC, "Configure Joystick", sc_None, ui_Normal, &"USL_CtlCJoyButtonCustom"),
		_ui_end()]


static func _ctl_spanels() -> Array:
	return [
		_ui(CtlPanel2R(3, 0), uii_RadioButton, CTL_S_NOSNDUPPIC, CTL_S_NOSNDDNPIC, "Turn Sound Off", sc_None, ui_Normal, &"USL_CtlSButtonCustom"),
		_ui(CtlPanel2R(8, 0), uii_RadioButton, CTL_S_PCSNDUPPIC, CTL_S_PCSNDDNPIC, "Use PC Speaker", sc_None, ui_Normal, &"USL_CtlSButtonCustom"),
		_ui(CtlPanel2R(13, 0), uii_RadioButton, CTL_S_ADLIBUPPIC, CTL_S_ADLIBDNPIC, "Use AdLib Sound Effects", sc_None, ui_Normal, &"USL_CtlSButtonCustom"),
		_ui(CtlPanel2R(18, 0), uii_RadioButton, CTL_S_SNDBLUPPIC, CTL_S_SNDBLDNPIC, "Use SoundBlaster Sound Effects", sc_None, ui_Normal, &"USL_CtlSButtonCustom"),
		_ui(CtlPanel2R(23, 0), uii_RadioButton, CTL_S_SNDSRCUPPIC, CTL_S_SNDSRCDNPIC, "Use Sound Source Sound Effects", sc_None, ui_Normal, &"USL_CtlSButtonCustom"),
		_ui_end()]


static func _ctl_ssspanels() -> Array:
	return [
		_ui(CtlPanel3R(7, 2), uii_CheckBox, CTL_CHECKUPPIC, CTL_CHECKDNPIC, "Turn Tandy Mode On / Off", sc_None, ui_Normal, &"", "Tandy Mode"),
		_ui(CtlPanel3R(7, 6), uii_CheckBox, CTL_CHECKUPPIC, CTL_CHECKDNPIC, "Switch between LPT1 & LPT2", sc_None, ui_Normal, &"", "Use LPT2"),
		_ui_end()]


static func _ctl_mpanels() -> Array:
	return [
		_ui(CtlPanel2R(9, 0), uii_RadioButton, CTL_M_NOMUSUPPIC, CTL_M_NOMUSDNPIC, "Background Music Off", sc_None, ui_Normal, &""),
		_ui(CtlPanel2R(15, 0), uii_RadioButton, CTL_M_ADLIBUPPIC, CTL_M_ADLIBDNPIC, "Use AdLib/SoundBlaster Music", sc_None, ui_Normal, &""),
		_ui_end()]


var CtlPanels: Array = _ctl_panels()
var CtlPPanels: Array = _ctl_ppanels()
var CtlPSPanels: Array = _ctl_pspanels()
var CtlPRPanels: Array = _ctl_prpanels()
var CtlHPanels: Array = _ctl_hpanels()
var CtlDPanels: Array = _ctl_dpanels()
var CtlDLSPanels: Array = _ctl_dlspanels()
var CtlDEPanels: Array = _ctl_depanels()
var CtlCPanels: Array = _ctl_cpanels()
var CtlCKbdPanels: Array = _ctl_ckbdpanels()
var CtlCJoyPanels: Array = _ctl_cjoypanels()
var CtlSPanels: Array = _ctl_spanels()
var CtlSSSPanels: Array = _ctl_ssspanels()
var CtlMPanels: Array = _ctl_mpanels()
var CtlPanels2: Array = [CtlPPanels, CtlHPanels, CtlDPanels, CtlCPanels, CtlSPanels, CtlMPanels]
## The item lists on screen (null: none): the leftmost column, the top row, the bottom area.
var TheItems: Array = [CtlPanels, null, null, null]
var CtlPanelButton: int = 0


## Goes through a list of UserItems and sets them all to the normal state.
func USL_TurnOff(ip: Array) -> void:
	var k: int = 0
	while ip[k].type != uii_Bad:
		ip[k].sel = ui_Normal
		k += 1


## Finds which UserItem, if any, is selected in the given list.
func USL_FindDown(ip: Array) -> int:
	var i: int = 0
	while ip[i].type != uii_Bad:
		if ip[i].sel & ui_Selected:
			return i
		i += 1
	return -1


## Shows the specified string in the help window.
func USL_ShowHelp(s: Variant) -> void:
	var wr: WindowRec = WindowRec.new()

	if s == null:
		return

	US_SaveWindow(wr)
	US_RestoreWindow(HelpWindow)

	US_ClearWindow()
	US_PrintCentered(s)

	US_RestoreWindow(wr)


## Handles telling the user that there's been an error.
func USL_HandleError(num: int) -> void:
	var buf: String = "Error: "
	if num < 0:
		buf += "Unknown"
	elif num == ENOMEM:
		buf += "Disk is Full"
	elif num == 11:    # EINVFMT
		buf += "File is Incomplete"
	else:
		# (ReflectionHLE's text in place of sys_errlist[num])
		buf = "Unrecognized error %d" % num

	VW_HideCursor()

	fontcolor = F_SECONDCOLOR
	USL_ShowHelp(buf)
	fontcolor = F_BLACK
	VW_UpdateScreen()

	IN_ClearKeysDown()
	IN_Ack()

	VW_ShowCursor()
	VW_UpdateScreen()


## Draws a UserItem. If there's a custom routine, this will call it with a uic_Draw command. If
## the custom routine returns true, then the routine handled all of the drawing. If it returns
## false, then this routine does the default drawing.
func USL_DrawItem(hiti: int, hitn: int) -> void:
	var handled: bool
	var centered: bool = false
	var text: Variant = null
	var r: Rect = null
	var ip: UserItem = TheItems[hiti][hitn]
	if ip.custom != &"":
		handled = call(ip.custom, uic_Draw, hiti, hitn)
	else:
		handled = false

	if not handled:
		var picup: int = ip.picup
		var picdown: int = ip.picdown
		match ip.type:
			uii_CheckBox:
				px = u16(ip.r.lr.x + 8)
				py = u16(ip.r.ul.y + 8)
				text = ip.text
				centered = false
			uii_KeyCap:
				if not (ip.sel & ui_Selected):
					text = ip.text
					if text != null:
						r = _us_rect(ip.r.ul.x, ip.r.ul.y, ip.r.lr.x, ip.r.lr.y)
						centered = true
				else:
					text = null
			_:
				text = null

		VWB_DrawPic(ip.r.ul.x, ip.r.ul.y, picdown if (ip.sel & ui_Selected) else picup)
		if text != null:
			if centered:
				USL_PrintInCenter(text, r)
			else:
				var wh: PackedInt32Array = _measure(text, -1)
				VWB_Bar(px, py, wh[0] + 7, wh[1], WHITE)
				call(USL_DrawString, text, -1)
		if ip.sel & ui_Disabled:
			if (picup == CTL_D_LOADUPPIC) or (picup == CTL_D_SAVEUPPIC):
				VWB_DrawMPic(ip.r.ul.x, ip.r.ul.y, CTL_LSMASKPICM)
			else:
				VWB_DrawMPic(ip.r.ul.x, ip.r.ul.y, CTL_LITTLEMASKPICM)


## Handles a hit on a UserItem. If there's a custom routine, it will be called. If it returns
## true, then don't do anything more. If it returns false, then use the standard behaviour.
func USL_DoHit(hiti: int, hitn: int) -> void:
	var handled: bool
	var ip: UserItem = TheItems[hiti][hitn]
	if ip.custom != &"":
		handled = call(ip.custom, uic_Hit, hiti, hitn)
	else:
		handled = false

	if not handled:
		if TheItems[hiti][hitn].sel & ui_Disabled:
			fontcolor = F_SECONDCOLOR
			USL_ShowHelp("This Item is Disabled")
			fontcolor = F_BLACK
			return

		FlushHelp = true

		match ip.type:
			uii_Button, uii_CheckBox:
				if ip.type == uii_Button:
					# Must have a custom routine to handle hits - this just redraws
					ip.sel ^= ui_Selected
					USL_DrawItem(hiti, hitn)
				# (falls through)
				ip.sel ^= ui_Selected
				USL_DrawItem(hiti, hitn)
			uii_RadioButton:
				var list: Array = TheItems[hiti]
				var i: int = 0
				while list[i].type != uii_Bad:
					var op: UserItem = list[i]
					if (i != hitn) and (op.type == uii_RadioButton) and (op.sel & ui_Selected):
						op.sel &= ~ui_Selected
						USL_DrawItem(hiti, i)
					i += 1
				TheItems[hiti][hitn].sel |= ui_Selected
				USL_DrawItem(hiti, hitn)
			uii_KeyCap:
				pass


## Checks to see if the coordinates given are within any of the Rects in the UserItem list.
## Returns [found (0/1), index, number] (the C writes index & number whether found or not).
func USL_IsInRect(x: int, y: int, _index: Variant, _number: Variant) -> PackedInt32Array:
	var index: int = 0
	var number: int = 0
	x = u16(x)
	y = u16(y)
	while index < TheItems.size() and TheItems[index] != null:
		var items: Array = TheItems[index]
		number = 0
		while items[number].type != uii_Bad:
			var item: UserItem = items[number]
			if (x >= item.r.ul.x) and (x < item.r.lr.x) and (y >= item.r.ul.y) and (y < item.r.lr.y):
				return PackedInt32Array([1, index, number])
			number += 1

		index += 1
	return PackedInt32Array([0, index, number])


## Tracks the given item. If the cursor is inside of the item, it's redrawn as down. If the cursor
## is outside, the item is drawn in its original state. Returns true if the button was released
## while the cursor was inside the item, or false if it wasn't.
func USL_TrackItem(hiti: int, hitn: int) -> bool:
	var inside: bool
	var last: bool
	var on: int = 0
	var othersel: int = 0
	var op: UserItem = null

	var ip: UserItem = TheItems[hiti][hitn]
	var sel: int = ip.sel
	if ip.type == uii_RadioButton:
		inside = false
		var list: Array = TheItems[hiti]
		while list[on].type != uii_Bad:
			op = list[on]
			if op.sel & ui_Selected:
				inside = true
				break
			on += 1
		if not inside:
			op = ip
		othersel = op.sel
	else:
		op = null

	if ip.sel & ui_Disabled:
		fontcolor = F_SECONDCOLOR
		USL_ShowHelp("This item is disabled")
		fontcolor = F_BLACK

		while US_UpdateCursor() and not quitting:
			VW_UpdateScreen()
			BE_ST_ShortSleep()

		FlushHelp = true
		return false

	last = false
	while true:
		var hit: PackedInt32Array = USL_IsInRect(CursorX, CursorY, 0, 0)
		inside = (hit[1] == hiti) and (hit[2] == hitn)
		if inside != last:
			if inside:
				if op != null:
					op.sel &= ~ui_Selected
					ip.sel |= ui_Selected
				else:
					ip.sel = sel ^ ui_Selected
			else:
				if op != null and (op != ip):
					op.sel |= ui_Selected
					ip.sel &= ~ui_Selected
				else:
					ip.sel = sel

			USL_DrawItem(hiti, hitn)
			if op != null and (op != ip):
				USL_DrawItem(hiti, on)

			last = inside
		VW_UpdateScreen()
		BE_ST_ShortSleep()
		if not US_UpdateCursor() or quitting:
			break

	if op != null:
		op.sel = othersel
	ip.sel = sel
	if not inside:
		if op != null and (op != ip):
			USL_DrawItem(hiti, on)
		USL_DrawItem(hiti, hitn)
		VW_UpdateScreen()

	return inside


## Smoothly moves the cursor to the given location.
func USL_GlideCursor(newx: int, newy: int) -> void:
	var steps: int
	if grmode == CGAGR:
		steps = 1
	else:
		steps = 8

	var x: int = CursorX << 16
	var dx: int = s32(s32((newx << 16) - x) / steps)
	var y: int = CursorY << 16
	var dy: int = s32(s32((newy << 16) - y) / steps)

	while (CursorX != newx) or (CursorY != newy):
		x = s32(x + dx)
		y = s32(y + dy)

		CursorX = s16(x >> 16)
		CursorY = s16(y >> 16)
		VW_MoveCursor(CursorX, CursorY)
		VW_UpdateScreen()
		if quitting:
			break
	CursorBad = true


## Given a Rect and direction, tries to find a UserItem to move the cursor to.
func USL_FindRect(r: Rect, xd: int, yd: int) -> void:
	var i1: int = 0
	var i2: int = 0
	var i3: int = 0
	var diffs: Array = []
	var goods: Array = []
	for m1: int in range(motion_Up, motion_Down + 1):
		for m2: int in range(motion_Left, motion_Right + 1):
			var dp: Point = Point.new()
			dp.x = s16(m2 * 1024)
			dp.y = s16(m1 * 1024)
			diffs.append(dp)
	for i: int in range(9):
		goods.append(null)

	# Find out which octants all of the rects (except r) are in
	for items: Variant in TheItems:
		if items == null:
			break
		var k: int = 0
		while items[k].type != uii_Bad:
			var rp: Rect = items[k].r
			k += 1
			var diff: Point = Point.new()
			diff.x = s16(rp.ul.x - r.ul.x)
			diff.y = s16(rp.ul.y - r.ul.y)
			if not (diff.x or diff.y):
				continue

			if ((rp.ul.x >= r.ul.x) and (rp.ul.x < r.lr.x)) or ((rp.lr.x > r.ul.x) and (rp.lr.x <= r.lr.x)):    # 1,4,7
				if rp.lr.y <= r.ul.y:
					if not (goods[1] != null and (diff.y < diffs[1].y)):
						goods[1] = rp
						diffs[1] = diff
				elif rp.ul.y >= r.lr.y:
					if not (goods[7] != null and (diff.y > diffs[7].y)):
						goods[7] = rp
						diffs[7] = diff

			if ((rp.ul.y >= r.ul.y) and (rp.ul.y < r.lr.y)) or ((rp.lr.y > r.ul.y) and (rp.lr.y <= r.lr.y)):    # 3,4,5
				if rp.lr.x <= r.ul.x:
					if not (goods[3] != null and (diff.x < diffs[3].x)):
						goods[3] = rp
						diffs[3] = diff
				elif rp.ul.x >= r.lr.x:
					if not (goods[5] != null and (diff.x > diffs[5].x)):
						goods[5] = rp
						diffs[5] = diff

			if rp.ul.x < r.ul.x:    # 0,6
				if rp.lr.y <= r.ul.y:
					if (goods[0] == null) or (diff.y > diffs[0].y) or (diff.x > diffs[6].x):
						goods[0] = rp
						diffs[0] = diff
				elif rp.ul.y >= r.lr.y:
					if (goods[6] == null) or (diff.y < diffs[6].y) or (diff.x > diffs[6].x):
						goods[6] = rp
						diffs[6] = diff

			if rp.lr.x > r.lr.x:    # 2,8
				if rp.lr.y <= r.ul.y:
					if (goods[2] == null) or (diff.y > diffs[2].y) or (diff.x < diffs[2].x):
						goods[2] = rp
						diffs[2] = diff
				elif rp.ul.y >= r.lr.y:
					if (goods[8] == null) or (diff.y < diffs[8].y) or (diff.x < diffs[8].x):
						goods[8] = rp
						diffs[8] = diff

	match yd:
		motion_Up:
			i1 = 1
			i2 = 0
			i3 = 2
		motion_None:
			match xd:
				motion_Left:
					i1 = 3
					i2 = 0
					i3 = 6
				motion_Right:
					i1 = 5
					i2 = 8
					i3 = 2
		motion_Down:
			i1 = 7
			i2 = 8
			i3 = 6

	var good: Rect = goods[i1]
	if good == null:
		good = goods[i2]
	if good == null:
		good = goods[i3]
	if good == null:
		good = r
	USL_GlideCursor(good.lr.x - 8, good.lr.y - 8)


## The custom routine for all of the Control Panel (leftmost) buttons. Clears all of the other item
## lists, clears the large area, and draws the line dividing the top and bottom areas. Then it
## sets up and draws the appropriate top row of icons.
func USL_CtlButtonCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false

	if n == CtlPanelButton:
		return true

	US_ClearWindow()
	for j: int in range(8, 38):
		VWB_DrawTile8M(j * 8, 6 * 8, 10)
		VWB_DrawTile8M(j * 8, 21 * 8, 10)
	VWB_DrawTile8M(7 * 8, 6 * 8, 9)
	VWB_DrawTile8M(38 * 8, 6 * 8, 11)
	VWB_DrawTile8M(7 * 8, 21 * 8, 9)
	VWB_DrawTile8M(38 * 8, 21 * 8, 11)

	for j: int in range(1, 4):
		TheItems[j] = null

	# Set to new button
	CtlPanelButton = n

	# Draw new items
	var ip: Array = CtlPanels2[CtlPanelButton]
	TheItems[1] = ip
	var k: int = 0
	while ip != null and ip[k].type != uii_Bad:
		USL_DrawItem(i + 1, k)
		if ip[k].sel & ui_Selected:
			USL_DoHit(i + 1, k)
		k += 1

	return false


## The custom routine for the keyboard keycaps. Gets a scancode and puts it in the appropriate
## KbdDefs[0] member.
func USL_CtlCKbdButtonCustom(call_: int, i: int, n: int) -> bool:
	var state: bool
	var scan: int = sc_None
	var time: int

	if call_ != uic_Hit:
		return false

	var ip: UserItem = TheItems[i][n]

	fontcolor = F_SECONDCOLOR
	USL_ShowHelp(ip.help)
	fontcolor = F_BLACK
	VW_HideCursor()
	VWB_DrawPic(ip.r.ul.x, ip.r.ul.y, ip.picdown)
	VW_UpdateScreen()

	LastScan = sc_None
	time = SD_GetTimeCount()
	state = true
	while not quitting:
		if u32(SD_GetTimeCount() - time) > 35:    # Half-second delays
			state = not state
			VWB_DrawPic(ip.r.ul.x, ip.r.ul.y, ip.picdown if state else ip.picup)
			VW_UpdateScreen()
			time = SD_GetTimeCount()
		if US_UpdateCursor():
			while US_UpdateCursor() and not quitting:
				BE_ST_ShortSleep()
			scan = sc_Escape
			break

		BE_ST_ShortSleep()
		if LastScan == sc_LShift:
			LastScan = sc_None
		scan = LastScan & 0xFF
		if scan:
			break
	if quitting:
		return true
	_clearkey(scan)
	if scan != sc_Escape:
		state = false
		var kd: KeyboardDef = _kbddef0()
		for j: int in range(10):
			if j == n:
				continue
			if int(kd.get(KeyMaps[j])) == scan:
				state = true
				break
		if state:
			fontcolor = F_SECONDCOLOR
			USL_ShowHelp("That Key is Already Used!")
			fontcolor = F_BLACK
		else:
			ip.text = IN_GetScanName(scan)
			kd.set(KeyMaps[n], scan)
			FlushHelp = true

	USL_DrawItem(i, n)
	VW_ShowCursor()
	VW_UpdateScreen()

	return true


## The custom button routine for joystick calibration.
func USL_CtlCJoyButtonCustom(call_: int, _i: int, _n: int) -> bool:
	var Done: bool = false
	var minx: int = 0
	var maxx: int = 0
	var miny: int = 0
	var maxy: int = 0

	if call_ != uic_Hit:
		return false

	IN_ClearKeysDown()
	var joy: int = u16(USL_FindDown(CtlCPanels) - 1)

	VW_HideCursor()
	FlushHelp = true
	fontcolor = F_SECONDCOLOR

	while not Done and not quitting:
		# (REFKEEN) Originally this code block was outside any loop in v1.00
		if current_gamever_int == 100:
			Done = true

		USL_ShowHelp("Move Joystick to the Upper-Left")
		VW_UpdateScreen()
		while (LastScan != sc_Escape) and not IN_GetJoyButtonsDB(joy) and not quitting:
			BE_ST_ShortSleep()

		if LastScan != sc_Escape:
			var xy: PackedInt32Array = IN_GetJoyAbs(joy, 0, 0)
			minx = xy[0]
			miny = xy[1]
			while IN_GetJoyButtonsDB(joy) and not quitting:
				BE_ST_ShortSleep()

			USL_ShowHelp("Move Joystick to the Lower-Right")
			VW_UpdateScreen()
			while (LastScan != sc_Escape) and not IN_GetJoyButtonsDB(joy) and not quitting:
				BE_ST_ShortSleep()

			if LastScan != sc_Escape:
				xy = IN_GetJoyAbs(0, 0, 0)
				maxx = xy[0]
				maxy = xy[1]

				# (v1.00 does not compare)
				if ((maxx != minx) and (maxy != miny)) or (current_gamever_int == 100):
					Done = true
					IN_SetupJoy(joy, minx, maxx, miny, maxy)
				else:
					while IN_GetJoyButtonsDB(joy) and not quitting:
						BE_ST_ShortSleep()
			else:
				Done = true
		else:
			Done = true

	if LastScan != sc_Escape:
		while IN_GetJoyButtonsDB(joy) and not quitting:
			BE_ST_ShortSleep()

	if LastScan:
		IN_ClearKeysDown()

	fontcolor = F_BLACK
	VW_ShowCursor()

	return false


## Clears the bottom part of the window.
func USL_ClearBottom() -> void:
	var wr: WindowRec = WindowRec.new()

	US_SaveWindow(wr)
	US_RestoreWindow(BottomWindow)

	US_ClearWindow()

	US_RestoreWindow(wr)


## Formats helptext. Runs through and calculates the number of lines, and the offset for the
## start of each line (into LineOffsets). Stops after len bytes or when it hits a tilde ('~').
## Munges the text.
func USL_FormatHelp(text: PackedByteArray, len: int) -> int:
	var line: int = 0
	var o: int = 0

	WindowX = u16(WindowX + 4)
	WindowW = u16(WindowW - 4)

	MM_GetPtr("us:LineOffsets", MaxHelpLines * 2)
	LineOffsets = PackedInt32Array()
	LineOffsets.resize(MaxHelpLines)
	var s: int = 0
	var l: int = 0
	var le: int = 0
	while (s < len) and (_tb(text, s) != 126):    # '~'
		var ch: int = _tb(text, s)
		if ch == 10:
			text[s] = 0
			o = _off_put(o, l)    # Save offset of start of line
			line += 1             # Bump line number
			l = s + 1             # Set start of line ptr
			le = l

		if ch == 13:
			ch = 32
			text[s] = 32
		if (ch == 32) and (s == l) and (_tb(text, s - 1) == 0) and (_tb(text, s + 1) != 32) and (s > 0):
			# Strip orphaned spaces
			l = s + 1
			le = l
		elif ch == 32:
			text[s] = 0
			var wh: PackedInt32Array = _measure(_cstring(text, l), -1)
			if wh[0] >= WindowW:    # If string width exceeds window,
				text[s] = ch        # Replace null char with proper char
				text[le] = 0        # Go back to last line end
				o = _off_put(o, l)  # Save offset of start of line
				line += 1           # Bump line number
				l = le + 1          # Start next time through after last line end
				s = l
			else:
				text[s] = ch        # Width still ok - put char back
				le = s              # And save ptr to last ok end of word
		s += 1

	WindowX = u16(WindowX - 4)
	WindowW = u16(WindowW + 4)

	return u16(line)


## A byte of the help text (out of the buffer: 0).
static func _tb(text: PackedByteArray, i: int) -> int:
	return text[i] if i >= 0 and i < text.size() else 0


## *off++ = v
func _off_put(o: int, v: int) -> int:
	if o >= LineOffsets.size():
		LineOffsets.resize(o + 1)
	LineOffsets[o] = v
	return o + 1


## Draws helptext in the current window.
func USL_DrawHelp(text: PackedByteArray, start: int, end: int, line: int, h: int, lp: PackedInt32Array) -> void:
	px = u16(WindowX + 4)
	py = u16(WindowY + (line * h))
	var k: int = start
	while start < end:
		call(USL_DrawString, _cstring(text, lp[k] if k < lp.size() else 0), -1)
		k += 1
		start += 1
		px = u16(WindowX + 4)
		py = u16(py + h)


## Formats and displays the specified help.
func USL_DoHelp(text: PackedByteArray, len: int) -> void:
	var done: bool
	var moved: bool
	var scroll: int
	var lines: int
	var cur: int
	var page: int
	var top: int = 0
	var num: int = 0
	var loc: int = 0
	var base: int
	var srcbase: int
	var destbase: int
	var waitkey: int
	var lasttime: int
	var wr: WindowRec = WindowRec.new()
	var info: CursorInfo = CursorInfo.new()

	USL_ShowHelp("Arrow Keys Move / Escape Exits")
	fontcolor = F_BLACK

	US_SaveWindow(wr)
	US_RestoreWindow(BottomWindow)
	US_ClearWindow()

	VW_HideCursor()
	VW_UpdateScreen()

	lines = USL_FormatHelp(text, len)
	var h: int = _measure("", -1)[1]
	@warning_ignore("integer_division")
	page = WindowH / h if h else 0
	cur = 0
	var lp: PackedInt32Array = LineOffsets

	IN_ClearKeysDown()
	moved = true
	lasttime = 0
	scroll = 0
	done = false
	waitkey = sc_None
	while not done and not quitting:
		if moved:
			SD_TimeCountWaitFromSrc(lasttime, 5)
			lasttime = SD_GetTimeCount()

			if scroll == -1:
				top = cur
				num = 1
				loc = 0
			elif scroll == 1:
				num = 1
				loc = page - 1
				top = cur + loc
			else:
				top = cur
				num = page if (page < lines) else lines
				loc = 0
			if scroll:
				# (EGA)
				VWB_Bar(WindowX, WindowY + (loc * h), WindowW, num * h, WHITE)
				USL_DrawHelp(text, top, top + num, loc, h, lp)

				var pixdiv: int = 8
				@warning_ignore("integer_division")
				base = u16(displayofs + panadjust + (WindowX / pixdiv))

				if scroll == 1:
					srcbase = u16(base + _ylookup(WindowY + h))
					destbase = u16(base + _ylookup(WindowY))
					EGAWRITEMODE(1)
					BE_ST_WaitForNewVerticalRetraces(1)    # VW_WaitVBL(1)
					@warning_ignore("integer_division")
					call(VW_ScreenToScreen, srcbase, destbase, WindowW / pixdiv, u16(WindowH - h))
				else:
					var i: int = u16(WindowY + (h * (page - 1)))
					srcbase = u16(base + _ylookup(i - h))
					destbase = u16(base + _ylookup(i))
					base = _ylookup(h)
					i = u16(page - 1)
					while i and not quitting:
						@warning_ignore("integer_division")
						call(VW_ScreenToScreen, srcbase, destbase, WindowW / pixdiv, h)
						i -= 1
						srcbase = u16(srcbase - base)
						destbase = u16(destbase - base)
				@warning_ignore("integer_division")
				base = u16(panadjust + (WindowX / pixdiv) + _ylookup(WindowY + (loc * h)))
				@warning_ignore("integer_division")
				call(VW_ScreenToScreen, u16(base + bufferofs), u16(base + displayofs), WindowW / pixdiv, h)
			else:
				US_ClearWindow()
				USL_DrawHelp(text, top, top + num, loc, h, lp)
				VW_UpdateScreen()

			moved = false
			scroll = 0

		if waitkey:
			while _keydown(waitkey) and not quitting:
				BE_ST_ShortSleep()
		waitkey = sc_None

		IN_ReadCursor(info)
		if info.y < 0:
			if cur > 0:
				scroll = -1
				cur -= 1
				moved = true
		elif info.y > 0:
			if cur + page < lines:
				scroll = 1
				cur += 1
				moved = true
		elif info.button0 or info.button1:
			done = true
		elif _keydown(LastScan):
			match LastScan:
				sc_Escape:
					done = true
				sc_UpArrow:
					if cur > 0:
						scroll = -1
						cur -= 1
						moved = true
				sc_DownArrow:
					if cur + page < lines:
						scroll = 1
						cur += 1
						moved = true
				sc_PgUp:
					if cur > page:
						cur -= page
					else:
						cur = 0
					moved = true
					waitkey = sc_PgUp
				sc_PgDn:
					if cur + page < lines:
						cur += page
						if cur + page >= lines:
							cur = lines - page
						moved = true
					waitkey = sc_PgDn
		BE_ST_ShortSleep()
	IN_ClearKeysDown()
	while true:
		IN_ReadCursor(info)
		BE_ST_ShortSleep()
		if not (info.button0 or info.button1) or quitting:
			break

	VW_ShowCursor()
	US_ClearWindow()
	VW_UpdateScreen()
	US_RestoreWindow(wr)


## ylookup[i] (0 past the table).
func _ylookup(i: int) -> int:
	i = u16(i)
	return ylookup[i] if i < ylookup.size() else 0


## id_vw.h's EGAWRITEMODE(x): the graphics controller's mode register.
func EGAWRITEMODE(x: int) -> void:
	vm.out16(GC_INDEX, GC_MODE + 256 * x)


## The custom routine for all of the help buttons.
func USL_CtlHButtonCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false

	var ip: UserItem = TheItems[i][n]
	if ip.sel & ui_Disabled:
		return false

	ip.sel |= ui_Selected
	USL_DrawItem(i, n)

	USL_ClearBottom()

	fontcolor = F_SECONDCOLOR
	USL_ShowHelp("Loading & Formatting Text...")
	VW_UpdateScreen()

	# HELPTEXTLINKED: the texts linked into the program
	var buf: String = ""
	match n:
		0:
			buf = gametext
		1:
			buf = context
		2:
			buf = story

	var size: int = 5000 if current_gamever_int < 110 else 5600
	MM_GetPtr("us:dupe", size)
	var dupe: PackedByteArray = _bytes_of(buf, size)

	USL_DoHelp(dupe, size)

	MM_FreePtr("us:dupe")
	if not LineOffsets.is_empty():
		MM_FreePtr("us:LineOffsets")
		LineOffsets = PackedInt32Array()

	fontcolor = F_BLACK

	ip.sel &= ~ui_Selected
	USL_DrawItem(i, n)

	return false


## The custom routine for all of the disk buttons. Sets up the bottom area of the window with
## the appropriate buttons.
func USL_CtlDButtonCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false

	var ip: UserItem = TheItems[i][n]
	if ip.sel & ui_Disabled:
		return false

	USL_ClearBottom()

	var list: Array = CtlDEPanels if n else CtlDLSPanels
	TheItems[i + 1] = list
	var j: int = 0
	while list[j].type != uii_Bad:
		USL_DrawItem(i + 1, j)
		j += 1

	return false


## Draw the rectangle for the save game names.
func USL_DLSRect(ip: UserItem) -> Rect:
	var r: Rect = _us_rect(ip.r.lr.x + 40 + 2, ip.r.ul.y + 2, u16(WindowX + WindowW - 8 - 2), ip.r.lr.y - 2)

	VWB_Bar(r.ul.x, r.ul.y, r.lr.x - r.ul.x, r.lr.y - r.ul.y, WHITE)

	VWB_Hlin(r.ul.x, r.lr.x, r.ul.y, BLACK)
	VWB_Hlin(r.ul.x, r.lr.x, r.lr.y, BLACK)
	VWB_Vlin(r.ul.y, r.lr.y, r.ul.x, BLACK)
	VWB_Vlin(r.ul.y, r.lr.y, r.lr.x, BLACK)

	px = u16(r.ul.x + 2)
	py = u16(r.ul.y + 2)

	return r


## The load game custom routine.
func USL_CtlDLButtonCustom(call_: int, i: int, n: int) -> bool:
	var wr: WindowRec = WindowRec.new()
	var game: US_SaveGame = Games[n >> 1]
	var ip: UserItem = TheItems[i][n]

	match call_:
		uic_Draw:
			if not loadedgame:
				USL_DLSRect(ip)
				fontcolor = F_BLACK if game.present else F_FIRSTCOLOR
				call(USL_DrawString, _cstring(game.name) if game.present else "Empty", -1)
				fontcolor = F_BLACK
		uic_Hit:
			if ip.sel & ui_Disabled:
				return false

			var filename: String = USL_GiveSaveName(n >> 1)

			US_SaveWindow(wr)
			US_CenterWindow(30, 3)
			US_PrintCentered("Loading `" + _cstring(game.name) + "'")
			VW_HideCursor()
			VW_UpdateScreen()

			var err: int = 0
			var file: BE_FILE_T = BE_Cross_open_rewritable_for_reading(filename)
			if BE_Cross_IsFileValid(file):
				if _us_read_game_header(file, game):
					if USL_LoadGame != &"":
						if not call(USL_LoadGame, file):
							err = errno
							USL_HandleError(err)
				else:
					err = errno
					USL_HandleError(err)
				BE_Cross_close(file)
			else:
				err = errno
				USL_HandleError(err)
			if err:
				abortgame = true
			else:
				loadedgame = true
			game.present = true

			if loadedgame:
				Paused = true

			VW_ShowCursor()
			US_RestoreWindow(wr)
	return false


## The save game custom routine.
func USL_CtlDSButtonCustom(call_: int, i: int, n: int) -> bool:
	var ok: bool
	var wr: WindowRec = WindowRec.new()

	if call_ != uic_Hit:
		return false

	var game: US_SaveGame = Games[n >> 1]
	var ip: UserItem = TheItems[i][n]
	if ip.sel & ui_Disabled:
		return false

	FlushHelp = true
	fontcolor = F_SECONDCOLOR
	USL_ShowHelp("Enter Game Name / Escape Aborts")
	fontcolor = F_BLACK

	var r: Rect = USL_DLSRect(TheItems[i][n - 1])    # ip - 1
	ok = US_LineInput(px, py, game.name, _cstring(game.name) if game.present else null, true,
			MaxGameName, r.lr.x - r.ul.x - 8)
	if _cstring(game.name).length() == 0:
		_strcpy(game.name, "Untitled")
	if ok:
		US_SaveWindow(wr)
		US_CenterWindow(10, 3)
		US_PrintCentered("Saving")
		VW_HideCursor()
		VW_UpdateScreen()

		var filename: String = USL_GiveSaveName(n >> 1)
		var err: int = 0
		var file: BE_FILE_T = BE_Cross_open_rewritable_for_overwriting(filename)
		if BE_Cross_IsFileValid(file):
			# signature, present, name and one byte of struct padding
			if BE_Cross_writeInt8LEBuffer(file, game.signature, 4) == 4 \
					and BE_Cross_write_boolean_To16LE(file, game.present) == 2 \
					and BE_Cross_writeInt8LEBuffer(file, game.name, MaxGameName + 1) == MaxGameName + 1 \
					and BE_Cross_writeInt8LE(file, 0) == 1:
				if USL_SaveGame != &"":
					ok = call(USL_SaveGame, file)
				if not ok:
					err = errno
					USL_HandleError(err)
			else:
				err = ENOMEM if errno == ENOENT else errno
				USL_HandleError(err)
			BE_Cross_close(file)
		else:
			err = ENOMEM if errno == ENOENT else errno
			USL_HandleError(err)
		if err:
			BE_Cross_remove(filename)
			ok = false

		VW_ShowCursor()
		US_RestoreWindow(wr)
		USL_DoHit(i - 1, 0)
		VW_UpdateScreen()

	if not game.present:
		game.present = ok

	if ok:
		GameIsDirty = false
		TheItems[i][n - 1].sel &= ~ui_Disabled

	USL_DrawItem(i, n - 1)

	return true


## The custom routine for all of the sound buttons.
func USL_CtlSButtonCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false

	var ip: UserItem = TheItems[i][n]
	if ip.sel & ui_Disabled:
		return false

	USL_ClearBottom()

	if n == sdm_SoundSource:
		TheItems[i + 1] = CtlSSSPanels
		var j: int = 0
		while CtlSSSPanels[j].type != uii_Bad:
			USL_DrawItem(i + 1, j)
			j += 1
	else:
		TheItems[i + 1] = null

	return false


## The custom routine for all of the start game buttons.
func USL_CtlPButtonCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false

	var ip: UserItem = TheItems[i][n]
	if ip.sel & ui_Disabled:
		return false

	USL_ClearBottom()

	var list: Array = CtlPRPanels if n else CtlPSPanels
	TheItems[i + 1] = list
	var j: int = 0
	while list[j].type != uii_Bad:
		USL_DrawItem(i + 1, j)
		j += 1

	return false


## Draws a string that warns the user that an action they're about to take will abort the game
## in progress.
func USL_GiveAbortWarning() -> void:
	var wr: WindowRec = WindowRec.new()

	if not GameIsDirty:
		return

	US_SaveWindow(wr)
	US_RestoreWindow(BottomWindow)
	US_HomeWindow()
	PrintY = u16(PrintY + 5)

	VWB_Bar(WindowX, WindowY, WindowW, 30, WHITE)
	fontcolor = F_SECONDCOLOR
	US_CPrint("Warning! If you do this, you'll")
	US_CPrint("abort the current game.")
	fontcolor = F_BLACK

	US_RestoreWindow(wr)


## The custom routine for the start game button.
func USL_CtlPSButtonCustom(call_: int, _i: int, n: int) -> bool:
	var result: bool

	match call_:
		uic_Hit:
			match n:
				0:
					restartgame = gd_Normal
				1:
					restartgame = gd_Easy
				2:
					restartgame = gd_Hard
			if restartgame and ingame and USL_ResetGame != &"":
				call(USL_ResetGame)
			result = false
		uic_Draw:
			USL_GiveAbortWarning()
			result = false
		_:
			result = false
	return result


## The custom routine for the resume game button.
func USL_CtlPRButtonCustom(call_: int, _i: int, _n: int) -> bool:
	if call_ != uic_Hit:
		return false

	ResumeGame = true
	return false


## The custom routine for the exit to DOS button.
func USL_CtlDEButtonCustom(call_: int, _i: int, _n: int) -> bool:
	var result: bool = false

	match call_:
		uic_Hit:
			QuitToDos = true
		uic_Draw:
			USL_GiveAbortWarning()
			result = false
		_:
			result = false
	return result


## The custom routine for all of the control buttons.
func USL_CtlCButtonCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false

	var ip: UserItem = TheItems[i][n]
	if ip.sel & ui_Disabled:
		return false

	if options != null and n < 2:
		# CTRL-05: the keyboard and the controller as Megarocket's lists, in place of the keycaps and the
		# joystick calibration
		TheItems[i + 1] = null
		USL_ClearBottom()
		_shell_controls_list("keys" if n == 0 else "pad")
		USL_ClearBottom()
		USL_ShowHelp(ip.help)
		return false

	USL_ClearBottom()
	var list: Array
	if n == 0:    # Keyboard
		list = CtlCKbdPanels
		TheItems[i + 1] = list
		var p: Point = CtlCKbdPanels[2].r.lr
		VWB_DrawPic(p.x, p.y, CTL_DIRSPIC)
	else:
		list = CtlCJoyPanels
		TheItems[i + 1] = list

	var j: int = 0
	while list[j].type != uii_Bad:
		USL_DrawItem(i + 1, j)
		j += 1

	return false


# ===================================================================== the shell's controls (CTRL-05)

## The shell's Options rows (an OptionsModel) while a player is at the controls; null in headless runs and
## the recordings, which see the original panel.
var options: Object = null

## The list's place: the panel's lower box (the keycaps' box), and its rows' height.
const SHELL_LIST_X: int = CtlPanel3X + 8
const SHELL_LIST_Y: int = CtlPanel3Y + 2
const SHELL_LIST_W: int = 38 * 8 - CtlPanel3X - 16
const SHELL_LIST_ROW: int = 10


## CTRL-05 / MENU-08 (the user, 2026-10-10: the same pages in every game, in its own style): one of
## Megarocket's Options pages (OptionsModel: controls, keys, pad, display, gameplay, fixes, an action's
## own) as a list in the panel's box, the pages it opens in turn. Up and down move, Enter (the jump
## button) chooses, left and right change a value, Escape (the throw button) goes back a page; the help
## line says how, or what the row chosen does (a fix's line). A capture is said there with Esc (Start)
## and a countdown, the host handing the next press over.
func _shell_page_list(start: String) -> void:
	VW_HideCursor()
	var stack: Array = []    # [page, cursor] to come back to
	var page: String = start
	var pos: int = 0
	_shell_list_top = 0
	var info: CursorInfo = CursorInfo.new()
	var was: Array = [true, true, 0, 0]    # the buttons held and the stick's y and x last time (one step a press)
	var said: String = ""
	var device: String = "pad" if start == "pad" else "keys"
	while not quitting:
		var rows: Array = _shell_list_rows(page)
		pos = clampi(pos, 0, rows.size() - 1)
		_shell_list_draw(rows, pos, page)
		var hint: String = "D-pad Moves  A Chooses  B Goes Back" if device == "pad" else "Arrows Move  Enter Chooses  Esc Goes Back"
		var desc: String = str(rows[pos].get("desc", "")) if not page.begins_with("bindact:") else ""
		USL_ShowHelp(said if said != "" else (desc if desc != "" else hint))
		VW_UpdateScreen()
		var act: int = 0    # -1 up, 1 down, 2 choose, 3 back, 4 left, 5 right
		while not quitting and act == 0:
			BE_ST_ShortSleep()
			IN_ReadControl(0, info)
			var scan: int = LastScan
			if scan in [sc_UpArrow, sc_DownArrow, sc_Return, sc_Space, sc_Escape, sc_LeftArrow, sc_RightArrow]:
				_clearkey(scan)
				act = {sc_UpArrow: -1, sc_DownArrow: 1, sc_Return: 2, sc_Space: 2, sc_Escape: 3, sc_LeftArrow: 4, sc_RightArrow: 5}[scan]
				device = "keys"
				continue
			LastScan = sc_None    # (another key, or the pad's own codes, read as held below)
			if info.yaxis != 0 and info.yaxis != was[2]:
				act = info.yaxis
			elif info.xaxis != 0 and info.xaxis != was[3]:
				act = 4 if info.xaxis < 0 else 5
			elif info.button0 and not was[0]:
				act = 2
			elif info.button1 and not was[1]:
				act = 3
			if act != 0 and not _keydown(sc_UpArrow) and not _keydown(sc_DownArrow) and not _keydown(sc_LeftArrow) and not _keydown(sc_RightArrow):
				device = "pad"
			was = [info.button0, info.button1, info.yaxis, info.xaxis]
		was = [true, true, info.yaxis, info.xaxis]
		said = ""
		if act == -1 or act == 1:
			pos = (pos + act + rows.size()) % rows.size()
			continue
		var row: Dictionary = rows[pos]
		if act == 4 or act == 5:
			if row.kind == "value" and str(row.key).begins_with("cheat:") and row.get("enabled", true):
				_shell_cheat(row)
			elif row.kind == "value" and not str(row.key).begins_with("bind:"):
				options.step(row.key, -1 if act == 4 else 1)
			continue
		var key: String = "exit" if act == 3 else str(row.key)
		if key == "exit":
			if stack.is_empty():
				break
			var back: Array = stack.pop_back()
			page = back[0]
			pos = back[1]
			continue
		if not row.get("enabled", true):
			said = str(row.get("why", "Not Now"))
			continue
		var to: String = ""
		if key.begins_with("cheat:"):
			to = _shell_cheat(row)
			if to == "close":
				break
			if to.begins_with("say:"):
				said = to.substr(4)
				continue
		else:
			to = options.activate(key)
		if to.begins_with("page:"):
			stack.append([page, pos])
			page = to.substr(5)
			pos = 0
			_shell_list_top = 0
		elif key.begins_with("capture:"):
			var cp: PackedStringArray = key.split(":")
			said = _shell_capture(cp[1], cp[2], int(cp[3]))
			var back: Array = stack.pop_back()
			page = back[0]
			pos = back[1]
		elif key.begins_with("clear:"):
			var cl: PackedStringArray = key.split(":")
			options.clear_binding(cl[1], cl[2])
			said = "%s: none" % options.action_label(cl[2])
			var back: Array = stack.pop_back()
			page = back[0]
			pos = back[1]
		elif key == "reset_controls":
			# Y resets, another key backs out; SCR-03: the pad answers as it chooses in the list, its choosing
			# button (Jump's, A) pressed anew resets and its going-back one (Throw's, B) backs out (its own
			# codes are no key)
			USL_ShowHelp("Reset Every Control? A Resets, B Backs Out" if device == "pad" else "Reset Every Control? Press Y")
			VW_UpdateScreen()
			IN_ClearKeysDown()
			var yes: bool = false
			var held: Array = [true, true]
			while not quitting:
				BE_ST_ShortSleep()
				IN_ReadControl(0, info)
				if LastScan != sc_None and LastScan < 0x62:
					yes = LastScan == sc_Y
					break
				if info.button0 and not held[0]:
					yes = true
					break
				if info.button1 and not held[1]:
					break
				held = [info.button0, info.button1]
			if yes:
				options.reset_controls()
				said = "The Controls Are Reset"
			IN_ClearKeysDown()
	IN_ClearKeysDown()
	VWB_Bar(SHELL_LIST_X - 6, SHELL_LIST_Y - 1, SHELL_LIST_W + 10, 13 * 8 - 2, WHITE)
	VW_ShowCursor()
	VW_UpdateScreen()


## The Keyboard or Controller list (the panel's own keyboard and joystick buttons, CTRL-05).
func _shell_controls_list(device: String) -> void:
	_shell_page_list(device)


## A page's rows (the model's), the movement row of the Controller page left out (nothing to choose).
## The cheats (CHEAT-01): the engine's, from CheatsModel: a toggle reads On or Off, a one-shot is a plain
## row, Level select its own pages, the original's F10 codes last; with no game in progress every one is
## greyed, and says so when chosen.
func _shell_list_rows(page: String) -> Array:
	if page.begins_with("levels:"):
		var levels: Array = call(&"shell_levels")    # (DreamsGame's, down the chain)
		var first: int = int(page.substr(7))
		var rows: Array = []
		for l: Array in levels.slice(first, first + 10):
			rows.append({"key": "cheat:warp:%d" % l[0], "label": l[1], "kind": "action", "enabled": bool(call(&"shell_in_game")), "why": "Only During a Game"})
		if first + 10 < levels.size():
			rows.append({"key": "cheat:levels:%d" % (first + 10), "label": "More levels...", "kind": "page"})
		rows.append({"key": "exit", "label": "Back", "kind": "action"})
		return rows
	if page == "codes":
		var rows: Array = []
		for c: Array in CheatsModel.CODES.get("dreams", []):
			rows.append({"key": "cheat:info", "label": str(c[0]), "kind": "action", "desc": str(c[1])})
		rows.append({"key": "exit", "label": "Back", "kind": "action"})
		return rows
	if page == "cheats":
		var rows: Array = []
		for r: Dictionary in CheatsModel.rows(self):
			if r.kind == "toggle":
				rows.append({"key": "cheat:" + r.key, "label": r.label, "kind": "value", "value": "On" if r.value else "Off", "enabled": r.enabled, "why": "Only During a Game"})
			elif r.kind == "once":
				rows.append({"key": "cheat:" + r.key, "label": r.label, "kind": "action", "enabled": r.enabled, "why": "Only During a Game"})
			elif r.kind == "pick" and r.key == "level_select":
				rows.append({"key": "cheat:levels:0", "label": r.label + "...", "kind": "page", "enabled": r.enabled, "why": "Only During a Game"})
		if not (CheatsModel.CODES.get("dreams", []) as Array).is_empty():
			rows.append({"key": "cheat:codes", "label": "Original codes...", "kind": "page"})
		rows.append({"key": "exit", "label": "Back", "kind": "action"})
		return rows
	return (options.page(page) as Array).filter(func(r: Dictionary) -> bool: return r.key != "pad_fixed")


## A cheat row chosen (or, a toggle, moved): the toggle flips; a one-shot is applied and says what it did;
## Level select's level is entered. Returns the list's next act: "say:<word>", "page:<name>", "close" (the
## panel is leaving for the game) or "" (the list drawn again).
func _shell_cheat(row: Dictionary) -> String:
	var key: String = str(row.key).substr(6)
	if key == "codes":
		return "page:codes"
	if key == "info":
		return ""
	if key.begins_with("levels:"):
		return "page:" + key
	if key.begins_with("warp:"):
		var why: String = str(call(&"shell_warp_to", int(key.substr(5))))
		return "say:" + why if why != "" else "close"
	if row.kind == "value":
		CheatsModel.toggle(self, key)
		return ""
	var said: String = str(call(&"shell_cheat_fire", key))
	return "close" if ResumeGame else "say:" + said


## The list in the box: on an action's page its keys first, as a heading; the row chosen in the panel's
## red (its own highlight: the chosen button's frame, the help's second colour) with a red mark before it.
## A list longer than the box (the cheats') scrolls: its window of rows follows the cursor, and a red
## mark at the box's top or bottom edge says there are more that way.
var _shell_list_top: int = 0


func _shell_list_draw(rows: Array, pos: int, page: String) -> void:
	VWB_Bar(SHELL_LIST_X - 6, SHELL_LIST_Y - 1, SHELL_LIST_W + 10, 13 * 8 - 2, WHITE)
	var y: int = SHELL_LIST_Y
	var heading: bool = page.begins_with("bindact:")
	if heading:
		fontcolor = F_SECONDCOLOR
		px = SHELL_LIST_X
		py = y
		call(USL_DrawString, str(rows[0].get("desc", "")), -1)
		y += SHELL_LIST_ROW + 4
	var max_rows: int = (13 * 8 - 2 - (y - SHELL_LIST_Y)) / SHELL_LIST_ROW
	if pos < _shell_list_top:
		_shell_list_top = pos
	if pos >= _shell_list_top + max_rows:
		_shell_list_top = pos - max_rows + 1
	_shell_list_top = clampi(_shell_list_top, 0, maxi(0, rows.size() - max_rows))
	if _shell_list_top > 0:
		VWB_Bar(SHELL_LIST_X + SHELL_LIST_W / 2 - 4, SHELL_LIST_Y - 1, 8, 2, 12)
	if _shell_list_top + max_rows < rows.size():
		VWB_Bar(SHELL_LIST_X + SHELL_LIST_W / 2 - 4, SHELL_LIST_Y + 13 * 8 - 5, 8, 2, 12)
	for k: int in range(_shell_list_top, mini(rows.size(), _shell_list_top + max_rows)):
		var r: Dictionary = rows[k]
		if k == pos:
			VWB_Bar(SHELL_LIST_X - 5, y + 1, 3, SHELL_LIST_ROW - 4, 12)    # (EGA light red)
		fontcolor = F_SECONDCOLOR if k == pos else F_BLACK
		px = SHELL_LIST_X
		py = y
		call(USL_DrawString, str(r.label), -1)
		if r.kind == "value":
			var v: String = str(r.value)
			px = SHELL_LIST_X + SHELL_LIST_W - _measure(v, -1)[0]
			py = y
			call(USL_DrawString, v, -1)
		y += SHELL_LIST_ROW
	fontcolor = F_BLACK


## CTRL-05: a key or button caught for an action, the help line saying what to press, Esc (Start) cancels
## and the seconds left; the host hands the next press over (controls_captured) and the game never sees it.
func _shell_capture(device: String, action: String, slot: int) -> String:
	var prompt: String = options.capture_prompt(device, action)
	var cancel: String = "Esc" if device == "keys" else "Start"
	controls_captured = -2
	controls_capture = device
	var start: int = SD_GetTimeCount()
	var shown: int = -1
	while not quitting and controls_captured == -2:
		var left: int = 5 - int(u32(SD_GetTimeCount() - start) / 70)
		if left <= 0:
			break
		if left != shown:
			shown = left
			fontcolor = F_SECONDCOLOR
			USL_ShowHelp("%s (%s Cancels) %d" % [prompt, cancel, left])
			fontcolor = F_BLACK
			VW_UpdateScreen()
		BE_ST_ShortSleep()
	controls_capture = ""
	var code: int = controls_captured
	controls_captured = -2
	IN_ClearKeysDown()
	return options.capture_done(device, action, slot, code if code != -2 else -1)


## MENU-08 (the user, 2026-10-10: every game's menu in one order; Dreams' in text keycaps, no new art): the
## icons Start or Resume, Load / Save / Quit, Options (the Controls icon: Controls, Display and Gameplay
## keycaps, each one of Megarocket's pages in the box), Sound, Music, Extras (the Help icon: the help,
## the story, High Scores). Only with a player at the controls; the recordings see the original's panel.
var _shell_panel_done: bool = false


## A keycap in the icons' row, as the keycaps' own rectangle (CtlPanelKC3R's: its label centred on the cap,
## whose face holds some 38 pixels of the panel's font).
static func CtlPanelKC2R(x: int, y: int) -> Array:
	return [CtlPanel2X + x * 8, CtlPanel2Y + y * 8, CtlPanel2X + 56 + x * 8, CtlPanel2Y + 32 + y * 8]


func _shell_panel_setup() -> void:
	if _shell_panel_done:
		return
	_shell_panel_done = true
	# the icons' places: Start 0, Disk 1, Options 2, Sound 3, Music 4, Extras 5
	for p: Array in [[0, 0], [2, 1], [3, 2], [4, 3], [5, 4], [1, 5]]:
		var r: Array = CtlPanelR(p[1])
		CtlPanels[p[0]].r = _us_rect(r[0], r[1], r[2], r[3])
	CtlPanels[3].help = "Options: Controls, Display, Gameplay"
	CtlPanels[1].help = "Extras: Help, the Story, High Scores"
	CtlPanels[3].key = sc_O
	CtlPanels[1].key = sc_E
	var keys: Array = []
	# (a cap's face holds some 38 pixels of the panel's font: the help line names each in full; five caps
	# six units apart fill the box)
	for e: Array in [[0, "Input", "controls", "Controls: Keys and Controller Buttons", sc_F3],
			[6, "Video", "display", "Display: Fullscreen, Pixel Shape", sc_V],
			[12, "Audio", "sound", "Audio: the Volume of Effects and Music", sc_A],
			[18, "Game", "gameplay", "Gameplay: Mode, Quicksave, Fixes", sc_G],
			[24, "Cheat", "cheats", "Cheats (Only During a Game)", sc_C]]:
		var item: UserItem = _ui(CtlPanelKC2R(e[0], 0), uii_KeyCap, CTL_KEYCAPPIC, CTL_KEYCAPCURPIC, e[3], e[4], ui_Normal,
			&"USL_CtlShellKeyCustom", e[1])
		keys.append(item)
	keys.append(_ui_end())
	CtlPanels2[3] = keys
	_shell_pages = ["controls", "display", "sound", "gameplay", "cheats"]
	# the help's three moved left to make room: the row of four centred in the box
	for k: int in range(3):
		var hr: Array = CtlPanel2R(4 + 5 * k, 0)
		CtlHPanels[k].r = _us_rect(hr[0], hr[1], hr[2], hr[3])
	CtlHPanels.insert(CtlHPanels.size() - 1, _ui(CtlPanelKC2R(20, 0), uii_KeyCap, CTL_KEYCAPPIC, CTL_KEYCAPCURPIC,
		"See the High Scores", sc_S, ui_Normal, &"USL_CtlShellScoresCustom", "Score"))


var _shell_pages: Array = []


## An Options keycap chosen: its page as a list in the box.
func USL_CtlShellKeyCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false
	TheItems[i + 1] = null
	USL_ClearBottom()
	_shell_page_list(_shell_pages[n])
	USL_ClearBottom()
	USL_ShowHelp(TheItems[i][n].help)
	return true


## Extras' High Scores keycap: the table in its window over the panel, a key, the panel drawn again.
func USL_CtlShellScoresCustom(call_: int, i: int, n: int) -> bool:
	if call_ != uic_Hit:
		return false
	VW_HideCursor()
	var wr: WindowRec = WindowRec.new()
	US_SaveWindow(wr)
	US_DisplayHighScores(-1)
	VW_UpdateScreen()
	IN_ClearKeysDown()
	IN_Ack()
	US_RestoreWindow(wr)
	_shell_redraw_panel(i)
	USL_ShowHelp(TheItems[i][n].help)
	VW_ShowCursor()
	VW_UpdateScreen()
	return true


## The panel drawn again as US_ControlPanel draws it, with the row of the icon chosen.
func _shell_redraw_panel(row: int) -> void:
	VWB_Bar(0, 0, MaxX, MaxY, FIRSTCOLOR)
	US_DrawWindow(8, 22, 30, 2)
	US_DrawWindow(8, 7, 30, 14)
	US_DrawWindow(8, 1, 30, 20)
	var k: int = 0
	while CtlPanels[k].type != uii_Bad:
		USL_DrawItem(0, k)
		k += 1
	var list: Variant = TheItems[row] if row < TheItems.size() else null
	if list != null:
		for j: int in range((list as Array).size()):
			if (list as Array)[j].type == uii_Bad:
				break
			USL_DrawItem(row, j)


## After a hotkey was hit, move the cursor to the first selected item in the group after the
## group containing the item holding the hotkey.
func USL_HitHotKey(i: int, n: int) -> void:
	i += 1
	var list: Variant = TheItems[i] if i < TheItems.size() else null
	if list != null:
		n = USL_FindDown(list)
		if n == -1:
			n = 0
		var ip: UserItem = list[n]
		CursorX = s16(ip.r.lr.x - 8)
		CursorY = s16(ip.r.lr.y - 8)
		CursorBad = true


## Checks to see if the scancode in LastScan corresponds to anything in the list of useritems. If
## so, selects the item. Returns [hit (0/1), ci, cn] (ci and cn as given unless set).
func USL_CheckScan(ci: int, cn: int) -> PackedInt32Array:
	var i: int
	var n: int

	if not LastScan:
		return PackedInt32Array([0, ci, cn])

	# DEBUG - probably kill this code
	# Use 1..? for the items across the top row
	if TheItems[1] != null and not _keydown(sc_RShift):
		var list: Array = TheItems[1]
		i = 0
		while (list[i].type != uii_Bad) and (i < 9):
			i += 1
		for k: int in range(i):
			if LastScan == 2 + k:    # Numbers from 1..9
				if not (TheItems[1][k].sel & ui_Disabled):
					LastScan = sc_None
					USL_DoHit(1, k)
					return PackedInt32Array([1, ci, cn])

	# Use Alt-1..6 for the items in the leftmost column
	if _keydown(sc_RShift):
		n = u16(LastScan - 2)
		if n < 6:    # Numbers from 1..6
			USL_DoHit(0, n)
			LastScan = sc_None
			return PackedInt32Array([1, ci, cn])

	# Check normal hotkeys for the leftmost column
	i = 0
	while CtlPanels[i].type != uii_Bad:
		if CtlPanels[i].key == LastScan:
			LastScan = sc_None
			USL_DoHit(0, i)
			USL_HitHotKey(0, i)
			return PackedInt32Array([1, 0, i])
		i += 1

	# Check normal hotkeys for the top row
	for k: int in range(6):
		var list: Variant = CtlPanels2[k]
		n = 0
		while list != null and list[n].type != uii_Bad:
			var ip: UserItem = list[n]
			if (ip.key == LastScan) and not (ip.sel & ui_Disabled):
				LastScan = sc_None
				USL_DoHit(0, k)
				USL_DoHit(1, n)
				USL_HitHotKey(1, n)
				return PackedInt32Array([1, 1, n])
			n += 1
	return PackedInt32Array([0, ci, cn])


## Sets the states of the UserItems to reflect the values of all the appropriate variables.
func USL_SetUpCtlPanel() -> void:
	var i: int

	GameIsDirty = ingame

	# Set up restart game
	USL_TurnOff(CtlPanels2[0])
	CtlPanels2[0][0].sel = ui_Normal if ingame else ui_Selected
	CtlPanels2[0][1].sel = ui_Selected if ingame else ui_Disabled

	# Set up disk stuff - default to load/save game
	USL_TurnOff(CtlDPanels)
	CtlDPanels[0].sel = ui_Selected

	# Set up load/save buttons
	USL_TurnOff(CtlDLSPanels)
	for k: int in range(MaxSaveGames):
		if not Games[k].present:
			CtlDLSPanels[k * 2].sel = ui_Disabled
		if not ingame:
			CtlDLSPanels[(k * 2) + 1].sel = ui_Disabled

	# Set up Controls
	USL_TurnOff(CtlCPanels)
	CtlCPanels[1].sel = ui_Normal if JoysPresent[0] else ui_Disabled
	CtlCPanels[2].sel = ui_Normal if JoysPresent[1] else ui_Disabled
	if options != null:
		# CTRL-05: the keyboard and the controller lists (the second joystick's button not used)
		CtlCPanels[0].help = "Choose Your Keys"
		CtlCPanels[1].help = "Choose Your Controller Buttons"
		CtlCPanels[1].sel = ui_Normal
		CtlCPanels[2].sel = ui_Disabled
		_shell_panel_setup()
	if Controls[0] == ctrl_Keyboard:
		i = 0
	else:
		i = 1 if (Controls[0] == ctrl_Joystick1) else 2
	CtlCPanels[i].sel |= ui_Selected
	if JoysPresent[1] and not JoysPresent[0]:
		CtlCPanels[2].key = sc_F4
	else:
		CtlCPanels[1].key = sc_F4

	# Set up Keyboard
	var kd: KeyboardDef = _kbddef0()
	for k: int in range(10):
		CtlCKbdPanels[k].text = IN_GetScanName(int(kd.get(KeyMaps[k])))

	# Set up Sounds
	USL_TurnOff(CtlSPanels)
	CtlSPanels[sdm_AdLib].sel = ui_Normal if AdLibPresent else ui_Disabled
	# DEBUG - hack because no space for digitized sounds on Keen Dreams
	CtlSPanels[sdm_SoundBlaster].sel = ui_Disabled
	CtlSPanels[sdm_SoundSource].sel = ui_Disabled
	CtlSPanels[SoundMode].sel |= ui_Selected

	# Set up SoundSource (the original's; ReflectionHLE compiles it out with the Sound Source)
	USL_TurnOff(CtlSSSPanels)
	CtlSSSPanels[0].sel = ui_Selected if ssIsTandy else ui_Normal
	CtlSSSPanels[1].sel = ui_Selected if (ssPort == 2) else ui_Normal

	# Set up Music
	USL_TurnOff(CtlMPanels)
	CtlMPanels[smm_AdLib].sel = ui_Normal if AdLibPresent else ui_Disabled
	CtlMPanels[MusicMode].sel |= ui_Selected


## Given the state of the control panel, sets the modes and values as appropriate.
func USL_TearDownCtlPanel() -> void:
	var i: int = USL_FindDown(CtlCPanels)
	if i != -1 and options != null:
		i = 0    # CTRL-05: the bindings are read whatever the button (the keyboard's reader stays)
	if i != -1:
		i = (ctrl_Joystick1 if i == 1 else ctrl_Joystick2) if i else ctrl_Keyboard
		IN_SetControlType(0, i)

	CtlCPanels[1].key = sc_None
	CtlCPanels[2].key = sc_None

	i = USL_FindDown(CtlPanels2[4])
	if i != -1:
		SD_SetSoundMode(i)

	# (the original's; ReflectionHLE compiles them out with the Sound Source)
	ssIsTandy = (CtlSSSPanels[0].sel & ui_Selected) != 0
	ssPort = 2 if (CtlSSSPanels[1].sel & ui_Selected) else 1

	i = USL_FindDown(CtlMPanels)
	if i != -1:
		# (the original's call; ReflectionHLE compiles it out with the music)
		SD_SetMusicMode(i)

		if not QuitToDos:
			if current_gamever_int < 110:
				US_CenterWindow(20, 8)
				US_CPrint("Loading")
				VW_UpdateScreen()

			CA_LoadAllSounds()


## This is the main routine for the control panel.
func US_ControlPanel() -> void:
	var gamename: String
	var done: bool
	var buttondown: bool
	var inrect: bool
	var hiti: int
	var hitn: int
	var i: int = 0
	var n: int = 0
	var lasti: int
	var lastn: int
	var lastx: int
	var lasty: int
	var lasttime: int
	var userect: Rect

	var ch: int = LastScan
	if ch == sc_Escape:    # Map escape from game to Exit to DOS
		ch = sc_Q

	# (REFKEEN) originally may have been read uninitialized
	lasttime = 0
	lastn = 0
	lasti = 0

	CA_UpLevel()
	for k: int in range(CONTROLS_LUMP_START, CONTROLS_LUMP_END + 1):
		grneeded[k] |= ca_levelbit    # CA_MarkGrChunk
	grneeded[CTL_LITTLEMASKPICM] |= ca_levelbit
	grneeded[CTL_LSMASKPICM] |= ca_levelbit
	# (v1.00 and 1.05's take one argument: the second is ignored)
	CA_CacheMarks("Options Screen", 0)

	USL_SetUpCtlPanel()

	US_SetPrintRoutines(&"VW_MeasurePropString", &"VWB_DrawPropString")
	fontcolor = F_BLACK

	VW_InitDoubleBuffer()

	VWB_Bar(0, 0, MaxX, MaxY, FIRSTCOLOR)
	US_DrawWindow(8, 22, 30, 2)
	US_SaveWindow(HelpWindow)
	US_DrawWindow(8, 7, 30, 14)
	US_SaveWindow(BottomWindow)
	US_DrawWindow(8, 1, 30, 20)

	var k2: int = 0
	while CtlPanels[k2].type != uii_Bad:
		var ip: UserItem = CtlPanels[k2]
		VWB_DrawPic(ip.r.ul.x, ip.r.ul.y, ip.picup)
		k2 += 1

	US_StartCursor()
	@warning_ignore("integer_division")
	CursorX = (8 * 8) + ((MaxX - (8 * 8)) / 2)
	CursorBad = true

	CtlPanelButton = -1
	LastScan = ch
	var cs: PackedInt32Array = USL_CheckScan(i, n)
	i = cs[1]
	n = cs[2]
	if CtlPanelButton == -1:
		USL_DoHit(0, 0)

	ResumeGame = false
	done = false
	FlushHelp = true
	lastx = 0xFFFF
	lasty = 0xFFFF
	while (restartgame == gd_Continue) and not (done or loadedgame or ResumeGame) and not quitting:
		VW_UpdateScreen()
		BE_ST_ShortSleep()

		buttondown = US_UpdateCursor()
		var hit: PackedInt32Array = USL_IsInRect(CursorX, CursorY, 0, 0)
		inrect = hit[0] != 0
		i = hit[1]
		n = hit[2]

		if FlushHelp:
			lasti = u16(-2)
			lasttime = SD_GetTimeCount()
			FlushHelp = false
		if inrect:
			if (lasti != i) or (lastn != n):
				# If over a Load button
				if (CtlPanelButton == 2) and (i == 2) and (TheItems[1][0].sel & ui_Selected) \
						and Games[n >> 1].present and not (n & 1):
					gamename = "Load `" + _cstring(Games[n >> 1].name) + "'"
					USL_ShowHelp(gamename)
				else:
					USL_ShowHelp(TheItems[i][n].help)
				lasti = i
				lastn = n
		elif lasti != 0xFFFF:
			USL_ShowHelp("Select a Button")
			lasti = 0xFFFF

		hiti = i
		hitn = n

		if inrect:
			var rr: Rect = TheItems[i][n].r
			userect = _us_rect(rr.ul.x, rr.ul.y, rr.lr.x, rr.lr.y)
		else:
			userect = _us_rect(CursorX, CursorY, CursorX, CursorY)

		if _keydown(sc_UpArrow):
			USL_FindRect(userect, motion_None, motion_Up)
			buttondown = false
			_clearkey(sc_UpArrow)
		elif _keydown(sc_DownArrow):
			USL_FindRect(userect, motion_None, motion_Down)
			buttondown = false
			_clearkey(sc_DownArrow)
		elif _keydown(sc_LeftArrow):
			USL_FindRect(userect, motion_Left, motion_None)
			buttondown = false
			_clearkey(sc_LeftArrow)
		elif _keydown(sc_RightArrow):
			USL_FindRect(userect, motion_Right, motion_None)
			buttondown = false
			_clearkey(sc_RightArrow)
		elif _keydown(sc_Return) or _keydown(_kbddef0().button0) or _keydown(_kbddef0().button1):
			if _keydown(sc_Return):
				ch = sc_Return
			elif _keydown(_kbddef0().button0):
				ch = _kbddef0().button0
			else:
				ch = _kbddef0().button1
			_clearkey(ch)
			if inrect:
				var ip: UserItem = TheItems[hiti][hitn]

				if (ip.type == uii_Button) and not (ip.sel & ui_Disabled):
					lasttime = SD_GetTimeCount()

					ip.sel |= ui_Selected
					USL_DrawItem(hiti, hitn)
					VW_UpdateScreen()

					@warning_ignore("integer_division")
					SD_TimeCountWaitFromSrc(lasttime, TickBase / 4)
					lasttime = SD_GetTimeCount()

					ip.sel &= ~ui_Selected
					USL_DrawItem(hiti, hitn)
					VW_UpdateScreen()

					@warning_ignore("integer_division")
					SD_TimeCountWaitFromSrc(lasttime, TickBase / 4)

				USL_DoHit(hiti, hitn)
		else:
			cs = USL_CheckScan(i, n)
			i = cs[1]
			n = cs[2]
			if cs[0]:
				pass
			elif buttondown and inrect and USL_TrackItem(hiti, hitn):
				USL_DoHit(hiti, hitn)

		if LastScan == sc_Escape:
			_clearkey(sc_Escape)
			done = true

		if QuitToDos:
			done = true

		if (lastx != u16(CursorX)) or (lasty != u16(CursorY)):
			lastx = u16(CursorX)
			lasty = u16(CursorY)
			lasttime = SD_GetTimeCount()
		if u32(SD_GetTimeCount() - lasttime) > TickBase * 10:
			@warning_ignore("integer_division")
			var secs: int = u32(SD_GetTimeCount() - lasttime) / TickBase
			if secs & 2:
				fontcolor = F_SECONDCOLOR
			USL_ShowHelp("Press F1 for Help")
			fontcolor = F_BLACK

	US_ShutCursor()

	USL_TearDownCtlPanel()

	if QuitToDos:
		# (FRILLS is 0: no TEDDeath)
		US_CenterWindow(20, 3)
		fontcolor = F_SECONDCOLOR
		US_PrintCentered("Now Exiting to DOS...")
		fontcolor = F_BLACK
		VW_UpdateScreen()
		Quit("")
		return

	CA_DownLevel()


# ---- High score routines

## Assumes that double buffering has been started. If passed a -1 will just display the high
## scores, but if passed a non-negative number will display that entry in red and let the user
## type in a name.
func US_DisplayHighScores(which: int) -> void:
	var y: int = 0    # (REFKEEN) originally not initialized

	US_CenterWindow(30, MaxScores + (MaxScores >> 1))

	@warning_ignore("integer_division")
	var x: int = u16(WindowX + (WindowW / 2))
	US_Print(" Name")
	PrintX = u16(x + 20)
	US_Print("Score")
	PrintX = u16(x + 60)
	US_Print("Done\n\n")
	PrintY = u16(PrintY - 3)

	var i: int = WindowX
	while i < u16(WindowX + WindowW):
		VWB_DrawTile8M(i, WindowY + 8, 10)
		i = u16(i + 8)
	VWB_DrawTile8M(u16(WindowX - 8), WindowY + 8, 9)
	VWB_DrawTile8M(u16(WindowX + WindowW), WindowY + 8, 11)

	for k: int in range(MaxScores):
		var s: HighScore = Scores[k]
		fontcolor = F_SECONDCOLOR if (k == which) else F_BLACK

		if k != which:
			US_Print(" ")
			var nm: String = _cstring(s.name)
			if nm.length():
				US_Print(nm)
			else:
				US_Print("-")
		else:
			y = PrintY

		PrintX = u16(x + (7 * 8))
		var buffer: String = ""
		for d: String in "%d" % u32(s.score):
			buffer += String.chr(d.unicode_at(0) + (129 - 48))    # Used fixed-width numbers (129...)
		var wh: PackedInt32Array = _measure(buffer, -1)
		PrintX = u16(PrintX - wh[0])
		US_Print(buffer)

		PrintX = u16(x + 60)
		if s.completed:
			US_PrintUnsigned(s.completed)
		else:
			US_Print("-")

		US_Print("\n")

	if which != -1:
		fontcolor = F_SECONDCOLOR
		PrintY = y
		PrintX = WindowX
		US_Print(" ")
		var hs: HighScore = Scores[which]
		_strcpy(hs.name, "")
		@warning_ignore("integer_division")
		US_LineInput(s16(PrintX), s16(PrintY), hs.name, null, true, MaxHighName, (WindowW / 2) - 8)
	fontcolor = F_BLACK

	VW_UpdateScreen()


## Checks gamestate to see if the just-ended game should be entered in the high score list. If
## so, lets the user enter their name.
func US_CheckHighScore(score: int, other: int) -> void:
	var myscore: HighScore = HighScore.new()
	var n: int = -1

	myscore.score = s32(score)
	myscore.completed = u16(other)

	for i: int in range(MaxScores):
		var si: HighScore = Scores[i]
		if (myscore.score > si.score) or ((myscore.score == si.score) and (myscore.completed > si.completed)):
			var j: int = MaxScores - 1
			while j > i:
				Scores[j].copy_from(Scores[j - 1])
				j -= 1
			Scores[i].copy_from(myscore)

			n = i
			HighScoresDirty = true
			break

	VW_InitDoubleBuffer()
	VWB_Bar(0, 0, MaxX, MaxY, FIRSTCOLOR)

	US_DisplayHighScores(n)
	IN_UserInput(5 * TickBase, false)


## (REFKEEN) Version-specific settings (the 2015 release's left out).
func RefKeen_Patch_id_us() -> void:
	CtlPanels[5].help = "Turn Music On / Off"
	CtlPanels2[0] = CtlPPanels
	CtlPanels2[4] = CtlSPanels
	CtlPanels2[5] = CtlMPanels

	refkeen_compat_config_filename = ("CONFIG." + EXTENSION) if current_gamever_int < 110 else "KDREAMS.CFG"


# ===================================================================== id_us_a.c: the random table

var rndindex: int = 0

const rndtable: PackedByteArray = [
	0, 8, 109, 220, 222, 241, 149, 107, 75, 248, 254, 140, 16, 66,
	74, 21, 211, 47, 80, 242, 154, 27, 205, 128, 161, 89, 77, 36,
	95, 110, 85, 48, 212, 140, 211, 249, 22, 79, 200, 50, 28, 188,
	52, 140, 202, 120, 68, 145, 62, 70, 184, 190, 91, 197, 152, 224,
	149, 104, 25, 178, 252, 182, 202, 182, 141, 197, 4, 81, 181, 242,
	145, 42, 39, 227, 156, 198, 225, 193, 219, 93, 122, 175, 249, 0,
	175, 143, 70, 239, 46, 246, 163, 53, 163, 109, 168, 135, 2, 235,
	25, 92, 20, 145, 138, 77, 69, 166, 78, 176, 173, 212, 166, 113,
	94, 161, 41, 50, 239, 49, 111, 164, 70, 60, 2, 37, 171, 75,
	136, 156, 11, 56, 42, 146, 138, 229, 73, 146, 77, 61, 98, 196,
	135, 106, 63, 197, 195, 86, 96, 203, 113, 101, 170, 247, 181, 113,
	80, 250, 108, 7, 255, 237, 129, 226, 79, 107, 112, 166, 103, 241,
	24, 223, 239, 120, 198, 58, 60, 82, 128, 3, 184, 66, 143, 224,
	145, 224, 81, 206, 163, 45, 63, 90, 168, 114, 59, 33, 159, 95,
	28, 139, 123, 98, 125, 196, 15, 70, 194, 253, 54, 14, 109, 226,
	71, 17, 161, 93, 186, 87, 244, 138, 20, 52, 123, 251, 26, 36,
	17, 46, 52, 231, 232, 76, 31, 221, 84, 37, 216, 165, 212, 106,
	197, 242, 98, 43, 39, 175, 254, 145, 190, 84, 118, 222, 187, 136,
	120, 163, 236, 249]

## The seed US_InitRndT(true) takes when the DOS clock is not given (the shell sets it, A11). Not state.
var us_randomSeed: int = 0
## The DOS clock (A11, set from outside, as gal_us.gd): microseconds since the clock read
## 00:00:00 when the program started. id's ID_US_A.ASM takes DL of int 21h 2Ch, the hundredths
## of a second, which DOS works out from the BIOS tick count (18.2 a second). -1: unset,
## us_randomSeed instead.
var us_dosClockAtStart: int = -1
## HARN-20 (tests only, set from outside): BIOS ticks added to the n-th reading of the clock. Not state.
var us_seedTicks: Dictionary = {}
var us_clockReads: int = 0


## DL of int 21h 2Ch: the BIOS ticks since 00:00:00 as hundredths (DOSBox: ticks * 100 /
## (1193182 / 65536), truncated), modulo 100. The Dreams timer handler (SDL_t0Service) does not
## pass ticks on to the BIOS, so the time of day stands still from SD_Startup on: the machine's
## time then is DrmIO's `sd_startupNow` when it keeps one, else the time now.
func US_DOSHundredths() -> int:
	var started: Variant = get(&"sd_startupNow")
	var before: int = vm.now if (started == null or int(started) < 0) else int(started)
	@warning_ignore("integer_division")
	var units: int = before + us_dosClockAtStart * DosMachine.PIT_HZ / 1000
	@warning_ignore("integer_division")
	var ticks: int = units / (65536 * DosMachine.UNIT)
	us_clockReads += 1
	ticks += int(us_seedTicks.get(us_clockReads, 0))
	return int(float(ticks) * 100.0 * 65536.0 / float(DosMachine.PIT_HZ)) % 100


## Init table based RND generator; if randomize is false, the counter is set to 0.
func US_InitRndT(randomize: bool) -> void:
	if randomize:
		if us_dosClockAtStart >= 0:
			rndindex = US_DOSHundredths()
		else:
			rndindex = us_randomSeed & 0xFF
	else:
		rndindex = 0


## Return a random # between 0-255.
func US_RndT() -> int:
	rndindex = (rndindex + 1) & 0xFF
	return rndtable[rndindex]


# ===================================================================== gelib.c

const BIO_BUFFER_LEN: int = 512
const NEAR_BUFFER_LEN: int = 64


## kd_def.h / gelib.h
class BitMapHeader:
	var w: int = 0
	var h: int = 0
	var x: int = 0
	var y: int = 0
	var d: int = 0
	var trans: int = 0
	var comp: int = 0
	var pad: int = 0


## Data: the memptr's bytes (empty: NULL) and `key`, its block in the memory manager.
class Shape:
	var Data: PackedByteArray = PackedByteArray()
	var key: String = ""
	var size: int = 0
	var BPR: int = 0
	var bmHdr: BitMapHeader = BitMapHeader.new()


class BufferedIO:
	var handle: BE_FILE_T = null    # handle of file
	var buffer: PackedByteArray = PackedByteArray()    # pointer to buffer
	var key: String = "bio"
	var offset: int = 0    # offset into buffer
	var status: int = 0    # read/write status


func FreeShape(shape: Shape) -> void:
	if not shape.Data.is_empty():
		MM_FreePtr(shape.key)
		shape.Data = PackedByteArray()


## Unpacks an ILBM body (packbits or not) to the screen at displayofs, a plane at a time.
func UnpackEGAShapeToScreen(SHP: Shape, startx: int, starty: int) -> int:
	var NotWordAligned: int = SHP.BPR & 1
	startx >>= 3
	var src: int = 0
	var currenty: int = starty
	var DstOff: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var Height: int = u16(SHP.bmHdr.h)
	while Height and not quitting:
		Height -= 1
		DstOff[0] = u16(displayofs + _ylookup(currenty) + startx)
		for loop: int in range(1, mini(SHP.bmHdr.d, 8)):
			DstOff[loop] = DstOff[0]

		for Plane: int in range(mini(SHP.bmHdr.d, 8)):
			var BPR: int = u16(((SHP.BPR + 1) >> 1) << 1)    # IGNORE WORD ALIGN
			while BPR:
				var n: int
				if SHP.bmHdr.comp:
					n = s8(_tb(SHP.Data, src))
					src += 1
				else:
					n = s8(BPR - 1)

				# n is a signed char: its arithmetic wraps, and while (n--) runs until it was 0
				if n < 0:
					if n != -128:
						n = s8((-n) + 1)
						BPR = u16(BPR - n)
						var Rep: int = _tb(SHP.Data, src)
						src += 1
						if (not BPR) and NotWordAligned:    # IGNORE WORD ALIGN
							n = s8(n - 1)

						while n != 0:
							n = s8(n - 1)
							BE_ST_EGAUpdateGFXByteInPlane(DstOff[Plane], Rep, Plane)
							DstOff[Plane] = u16(DstOff[Plane] + 1)
					else:
						BPR = u16(BPR - 1)
				else:
					n = s8(n + 1)
					BPR = u16(BPR - n)
					if (not BPR) and NotWordAligned:    # IGNORE WORD ALIGN
						n = s8(n - 1)

					while n != 0:
						n = s8(n - 1)
						BE_ST_EGAUpdateGFXByteInPlane(DstOff[Plane], _tb(SHP.Data, src), Plane)
						src += 1
						DstOff[Plane] = u16(DstOff[Plane] + 1)

					if (not BPR) and NotWordAligned:    # IGNORE WORD ALIGN
						src += 1
		currenty += 1

	return 0


## (REFKEEN: Verify, renamed) The file's length, 0 if it is not there.
func VerifyReadOnly(filename: String) -> int:
	var handle: BE_FILE_T = BE_Cross_open_readonly_for_reading(filename)
	if not BE_Cross_IsFileValid(handle):
		return 0
	var size: int = BE_Cross_FileLengthFromHandle(handle)
	BE_Cross_close(handle)
	return size


## Returns the buffer (the C's memptr: empty for NULL).
func InitBufferedIO(handle: BE_FILE_T, bio: BufferedIO) -> PackedByteArray:
	bio.handle = handle
	bio.offset = BIO_BUFFER_LEN
	bio.status = 0
	MM_GetPtr(bio.key, BIO_BUFFER_LEN)
	bio.buffer = PackedByteArray()
	bio.buffer.resize(BIO_BUFFER_LEN)

	return bio.buffer


func FreeBufferedIO(bio: BufferedIO) -> void:
	if not bio.buffer.is_empty():
		MM_FreePtr(bio.key)
		bio.buffer = PackedByteArray()


func bio_readch(bio: BufferedIO) -> int:
	if bio.offset == BIO_BUFFER_LEN:
		bio.offset = 0
		bio_fillbuffer(bio)

	var v: int = _tb(bio.buffer, bio.offset)
	bio.offset = u16(bio.offset + 1)
	return v


## Fills the buffer 64 bytes at a time through a near buffer (a short read leaves the near
## buffer's earlier bytes, as the C).
func bio_fillbuffer(bio: BufferedIO) -> void:
	var near_buffer: PackedByteArray = PackedByteArray()
	near_buffer.resize(NEAR_BUFFER_LEN)
	var bytes_read: int = 0
	var bio_length: int = BIO_BUFFER_LEN
	while bio_length:
		var bytes_requested: int
		if bio_length > NEAR_BUFFER_LEN - 1:
			bytes_requested = NEAR_BUFFER_LEN
		else:
			bytes_requested = bio_length

		BE_Cross_readInt8LEBuffer(bio.handle, near_buffer, bytes_requested)
		for k: int in range(bytes_requested):
			bio.buffer[bytes_read + k] = near_buffer[k]

		bio_length -= bytes_requested
		bytes_read += bytes_requested


func MoveGfxDst(x: int, y: int) -> void:
	@warning_ignore("integer_division")
	var address: int = u16((s16(y) * linewidth) + (s16(x) / 8))
	bufferofs = address
	displayofs = address


# ===================================================================== BE_ST_* / BE_Cross_* the back end lacks (move to drm_be.gd)

## B800:0000 as the processor sees it in text mode: 32 KB of character, attribute pairs.
var textmem: PackedByteArray = _new_textmem()
## The BIOS cursor (column, row).
var textcursor: Vector2i = Vector2i(0, 0)
## The files the program reads and writes, by upper-case name (the shell supplies and keeps them, A11).
var us_files: Dictionary = {}

## HARN-23: Megarocket 1.0's verify harness for ReflectionHLE (refkeen/src/kdreams/kl_verify.c), on the
## port's side. kl_record: a file each play-loop frame is written to (its tics, the player's controls, the
## last scan code and a hash of the whole game state), which ReflectionHLE replays with KL_REPLAY and
## checks frame by frame; kl_warp: straight into that level (KL_WARP). As in the C, either skips the
## start-up's key waits, and a record starts the random index at 0. Tests only, not game state.
var kl_record: String = ""
var kl_warp: int = -1


## KL_HarnessActive
func kl_active() -> bool:
	return kl_record != "" or kl_warp >= 0
## SAVE-06 (Dreams): the folder the player's files (the config with its high scores, the saved games)
## live in between sessions, set by the shell (user://saves/kdreams); "" (tests, oracle runs): memory only.
var user_dir: String = ""


## The player's files from user_dir into us_files (before kd_main_entry).
func load_user_files() -> void:
	if user_dir == "" or not DirAccess.dir_exists_absolute(user_dir):
		return
	for name: String in DirAccess.get_files_at(user_dir):
		var key: String = name.to_upper()
		if key.ends_with(".TMP"):
			continue
		if key.ends_with(".BAK"):
			key = key.substr(0, key.length() - 4)
			if FileAccess.file_exists(user_dir.path_join(key)) or us_files.has(key):
				continue    # the swap finished: the .BAK is stale
		us_files[key] = FileAccess.get_file_as_bytes(user_dir.path_join(name))


## A file the program has just written (or removed, with no bytes), kept in user_dir: beside the old
## one first, then swapped in, the old kept as .BAK until then.
func _user_write(key: String, bytes: Variant) -> void:
	if user_dir == "" or key == "KDREAMS.CMP":
		return
	DirAccess.make_dir_recursive_absolute(user_dir)
	var path: String = user_dir.path_join(key)
	if bytes == null:
		DirAccess.remove_absolute(path)
		return
	var f: FileAccess = FileAccess.open(path + ".TMP", FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(bytes)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".BAK")
		DirAccess.rename_absolute(path, path + ".BAK")
	DirAccess.rename_absolute(path + ".TMP", path)
	DirAccess.remove_absolute(path + ".BAK")


static func _new_textmem() -> PackedByteArray:
	var m: PackedByteArray = PackedByteArray()
	m.resize(0x8000)
	return m


## What the BIOS mode set leaves in text memory: spaces in light grey on black.
func _be_text_mode_set() -> void:
	for i: int in range(0, textmem.size(), 2):
		textmem[i] = 0x20
		textmem[i + 1] = 0x07


func BE_ST_GetTextModeMemoryPtr() -> PackedByteArray:
	return textmem


func BE_ST_MoveTextCursorTo(x: int, y: int) -> void:
	textcursor = Vector2i(x, y)


## A file: its bytes and where reading or writing is.
class BE_FILE_T:
	var name: String = ""
	var data: PackedByteArray = PackedByteArray()
	var pos: int = 0
	var writable: bool = false


func BE_Cross_IsFileValid(fp: BE_FILE_T) -> bool:
	return fp != null


func _be_open(filename: String, writable: bool) -> BE_FILE_T:
	var key: String = filename.to_upper()
	var f: BE_FILE_T = BE_FILE_T.new()
	f.name = key
	f.writable = writable
	if writable:
		us_files[key] = f.data    # created (or truncated)
		return f
	if not us_files.has(key):
		errno = ENOENT
		return null
	f.data = (us_files[key] as PackedByteArray).duplicate()
	return f


func BE_Cross_open_readonly_for_reading(filename: String) -> BE_FILE_T:
	return _be_open(filename, false)


func BE_Cross_open_rewritable_for_reading(filename: String) -> BE_FILE_T:
	return _be_open(filename, false)


func BE_Cross_open_rewritable_for_overwriting(filename: String) -> BE_FILE_T:
	return _be_open(filename, true)


func BE_Cross_close(fp: BE_FILE_T) -> void:
	if fp != null and fp.writable:
		us_files[fp.name] = fp.data
		_user_write(fp.name, fp.data)


func BE_Cross_remove(filename: String) -> void:
	us_files.erase(filename.to_upper())
	_user_write(filename.to_upper(), null)


func BE_Cross_FileLengthFromHandle(fp: BE_FILE_T) -> int:
	return fp.data.size()


## Up to `num` bytes into dst[0..]; the count read (what is not read stays as it was).
func BE_Cross_readInt8LEBuffer(fp: BE_FILE_T, dst: PackedByteArray, num: int) -> int:
	var n: int = clampi(fp.data.size() - fp.pos, 0, num)
	if dst.size() < n:
		dst.resize(n)
	for k: int in range(n):
		dst[k] = fp.data[fp.pos + k]
	fp.pos += n
	return n


## A little-endian value of `size` bytes read over `old`: [bytes read, the value (unsigned)].
func _be_read_le(fp: BE_FILE_T, old: int, size: int) -> Array:
	var b: PackedByteArray = PackedByteArray()
	var n: int = BE_Cross_readInt8LEBuffer(fp, b, size)
	var v: int = old & ((1 << (size * 8)) - 1)
	for k: int in range(n):
		v = (v & ~(0xFF << (8 * k))) | (b[k] << (8 * k))
	return [n, v]


func BE_Cross_readInt8LE(fp: BE_FILE_T, old: int) -> Array:
	return _be_read_le(fp, old, 1)


func BE_Cross_readInt16LE(fp: BE_FILE_T, old: int) -> Array:
	return _be_read_le(fp, old, 2)


func BE_Cross_readInt32LE(fp: BE_FILE_T, old: int) -> Array:
	return _be_read_le(fp, old, 4)


## [bytes read, the boolean] (unchanged unless both bytes were read).
func BE_Cross_read_boolean_From16LE(fp: BE_FILE_T, old: bool) -> Array:
	var r: Array = _be_read_le(fp, 0, 2)
	return [r[0], (r[1] != 0) if r[0] == 2 else old]


func BE_Cross_writeInt8LEBuffer(fp: BE_FILE_T, src: PackedByteArray, num: int) -> int:
	if fp.pos + num > fp.data.size():
		fp.data.resize(fp.pos + num)
	for k: int in range(num):
		fp.data[fp.pos + k] = src[k] if k < src.size() else 0
	fp.pos += num
	return num


func _be_write_le(fp: BE_FILE_T, v: int, size: int) -> int:
	var b: PackedByteArray = PackedByteArray()
	for k: int in range(size):
		b.append((v >> (8 * k)) & 0xFF)
	return BE_Cross_writeInt8LEBuffer(fp, b, size)


func BE_Cross_writeInt8LE(fp: BE_FILE_T, v: int) -> int:
	return _be_write_le(fp, v, 1)


func BE_Cross_writeInt16LE(fp: BE_FILE_T, v: int) -> int:
	return _be_write_le(fp, v, 2)


func BE_Cross_writeInt32LE(fp: BE_FILE_T, v: int) -> int:
	return _be_write_le(fp, v, 4)


func BE_Cross_write_boolean_To16LE(fp: BE_FILE_T, v: bool) -> int:
	return _be_write_le(fp, 1 if v else 0, 2)


# ===================================================================== the start-up screens (id_us_s_kdreams100.c, id_us_s_kdreams192andlater.c)

## id_us_s_kdreams100.c: each `scr_rowcol(y,x) scr_aputs(s,a)` as [y, x, s, a] (a character per byte).
const US_S_KDREAMS100: Array = [
	[1, 1, "\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD", 0x1E],
	[2, 1, "\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4             Gamer's Edge presents            \u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4", 0x1E],
	[3, 1, "\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4             Commander Keen in \"", 0x1E],
	[3, 45, "Keen Dreams", 0x1F],
	[3, 56, "\"            \u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4", 0x1E],
	[4, 1, "\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4                                              \u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4\u00C4", 0x1E],
	[5, 1, "\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD", 0x1E],
	[6, 1, "                                                                                ", 0x1E],
	[7, 1, "  ", 0x1E],
	[7, 3, "\u00C9\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BB", 0x4E],
	[7, 40, "\u00DC", 0x10],
	[7, 41, " ", 0x1E],
	[7, 42, "\u00C9\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BB", 0x4E],
	[7, 78, "\u00DC", 0x10],
	[7, 79, "  ", 0x1E],
	[8, 1, "  ", 0x1E],
	[8, 3, "\u00BA Video Modes      ", 0x4E],
	[8, 22, "CGA", 0x48],
	[8, 25, "              \u00BA", 0x4E],
	[8, 40, " ", 0x0E],
	[8, 41, " ", 0x1E],
	[8, 42, "\u00BA Detected Input  ", 0x4E],
	[8, 60, " ", 0x4F],
	[8, 61, "Keyboard", 0x48],
	[8, 69, "        \u00BA", 0x4E],
	[8, 78, "\u00DB ", 0x10],
	[8, 80, " ", 0x1E],
	[9, 1, "  ", 0x1E],
	[9, 3, "\u00BA Available        ", 0x4E],
	[9, 22, "EGA", 0x48],
	[9, 25, "              \u00BA", 0x4E],
	[9, 40, " ", 0x0E],
	[9, 41, " ", 0x1E],
	[9, 42, "\u00BA Devices         ", 0x4E],
	[9, 60, " ", 0x4F],
	[9, 61, "Joystick #1", 0x48],
	[9, 72, "     \u00BA", 0x4E],
	[9, 78, "\u00DB", 0x10],
	[9, 79, "  ", 0x1E],
	[10, 1, "  ", 0x1E],
	[10, 3, "\u00BA                  ", 0x4E],
	[10, 22, "VGA", 0x48],
	[10, 25, "              \u00BA", 0x4E],
	[10, 40, " ", 0x0E],
	[10, 41, " ", 0x1E],
	[10, 42, "\u00BA                 ", 0x4E],
	[10, 60, " ", 0x4F],
	[10, 61, "Joystick #2", 0x48],
	[10, 72, "     \u00BA", 0x4E],
	[10, 78, "\u00DB", 0x10],
	[10, 79, "  ", 0x1E],
	[11, 1, "  ", 0x1E],
	[11, 3, "\u00BA                                   \u00BA", 0x4E],
	[11, 40, " ", 0x0E],
	[11, 41, " ", 0x1E],
	[11, 42, "\u00BA                 ", 0x4E],
	[11, 60, " Mouse     ", 0x48],
	[11, 71, "      \u00BA", 0x4E],
	[11, 78, "\u00DB", 0x10],
	[11, 79, "  ", 0x1E],
	[12, 1, "  ", 0x1E],
	[12, 3, "\u00C8\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BC", 0x4E],
	[12, 40, " ", 0x0E],
	[12, 41, " ", 0x1E],
	[12, 42, "\u00C8\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BC", 0x4E],
	[12, 78, "\u00DB", 0x10],
	[12, 79, "  ", 0x1E],
	[13, 1, "   ", 0x1E],
	[13, 4, "\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF", 0x10],
	[13, 41, " ", 0x1E],
	[13, 42, " \u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF", 0x10],
	[13, 79, "  ", 0x1E],
	[14, 1, "  ", 0x1E],
	[14, 3, "\u00C9\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BB", 0x4E],
	[14, 40, "\u00DC", 0x10],
	[14, 41, " ", 0x1E],
	[14, 42, "\u00C9\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BB", 0x4E],
	[14, 78, "\u00DC", 0x10],
	[14, 79, "  ", 0x1E],
	[15, 1, "  ", 0x1E],
	[15, 3, "\u00BA Detected Sound   ", 0x4E],
	[15, 22, "PC Speaker", 0x48],
	[15, 32, "       \u00BA", 0x4E],
	[15, 40, " ", 0x00],
	[15, 41, " ", 0x1E],
	[15, 42, "\u00BA", 0x4E],
	[15, 43, " ", 0x48],
	[15, 44, "Memory", 0x4E],
	[15, 50, " ", 0x48],
	[15, 51, "Available to Game         \u00BA", 0x4E],
	[15, 78, " ", 0x00],
	[15, 79, "  ", 0x1E],
	[16, 1, "  ", 0x1E],
	[16, 3, "\u00BA Hardware         ", 0x4E],
	[16, 22, "AdLib", 0x48],
	[16, 27, "            \u00BA", 0x4E],
	[16, 40, " ", 0x0E],
	[16, 41, " ", 0x10],
	[16, 42, "\u00BA", 0x4E],
	[16, 43, "           Standard  xxxxx Kbytes", 0x48],
	[16, 76, " ", 0x4F],
	[16, 77, "\u00BA", 0x4E],
	[16, 78, " ", 0x00],
	[16, 79, "  ", 0x1E],
	[17, 1, "  ", 0x1E],
	[17, 3, "\u00BA                  ", 0x4E],
	[17, 22, "Sound Blaster", 0x48],
	[17, 35, "    \u00BA", 0x4E],
	[17, 40, " ", 0x0E],
	[17, 41, " ", 0x1E],
	[17, 42, "\u00BA", 0x4E],
	[17, 43, "           Extended  xxxxx Kbytes ", 0x48],
	[17, 77, "\u00BA", 0x4E],
	[17, 78, " ", 0x00],
	[17, 79, "  ", 0x1E],
	[18, 1, "  ", 0x1E],
	[18, 3, "\u00BA                  ", 0x4E],
	[18, 22, "Sound Source", 0x48],
	[18, 34, "     \u00BA", 0x4E],
	[18, 40, " ", 0x0E],
	[18, 41, " ", 0x1E],
	[18, 42, "\u00BA", 0x4E],
	[18, 43, "           Expanded  xxxxx Kbytes ", 0x48],
	[18, 77, "\u00BA", 0x4E],
	[18, 78, " ", 0x00],
	[18, 79, "  ", 0x1E],
	[19, 1, "  ", 0x1E],
	[19, 3, "\u00BA                                   \u00BA", 0x4E],
	[19, 40, " ", 0x0E],
	[19, 41, " ", 0x1E],
	[19, 42, "\u00BA", 0x4E],
	[19, 43, "         ", 0x48],
	[19, 52, "  ", 0x4E],
	[19, 54, "   ", 0x48],
	[19, 57, "Total", 0x4E],
	[19, 62, "  xxxxx Kbytes ", 0x48],
	[19, 77, "\u00BA", 0x4E],
	[19, 78, " ", 0x00],
	[19, 79, "  ", 0x1E],
	[20, 1, "  ", 0x1E],
	[20, 3, "\u00C8\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BC", 0x4E],
	[20, 40, " ", 0x0E],
	[20, 41, " ", 0x1E],
	[20, 42, "\u00C8\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BC", 0x4E],
	[20, 78, " ", 0x00],
	[20, 79, "  ", 0x1E],
	[21, 1, "   ", 0x1E],
	[21, 4, "\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF", 0x10],
	[21, 41, "  ", 0x1E],
	[21, 43, "\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF", 0x10],
	[21, 79, "  ", 0x1E],
	[22, 1, "                \u00C9\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BB                ", 0x1E],
	[23, 1, "                \u00BA          ", 0x1E],
	[23, 28, "Initializing...Please Wait ", 0x9C],
	[23, 55, " ", 0x9F],
	[23, 56, "        \u00BA                ", 0x1E],
	[24, 1, "                \u00C8\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BC                ", 0x1E],
	[25, 1, "                                                                                ", 0x1E],
]


## id_us_s_kdreams192andlater.c: each `scr_rowcol(y,x) scr_aputs(s,a)` as [y, x, s, a] (a character per byte).
const US_S_KDREAMS192ANDLATER: Array = [
	[1, 1, "                                                                                ", 0xC4],
	[2, 1, "                                                                                ", 0xC4],
	[3, 1, "           ", 0xC4],
	[3, 12, "                                                          ", 0x4E],
	[3, 70, "           ", 0xC4],
	[4, 1, "           ", 0xC4],
	[4, 12, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x40],
	[4, 70, "           ", 0xC4],
	[5, 1, "           ", 0xC4],
	[5, 12, "\u00DE", 0x0F],
	[5, 13, "\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF", 0x7F],
	[5, 69, "\u00DD", 0x08],
	[5, 70, "           ", 0xC4],
	[6, 1, "           ", 0xC4],
	[6, 12, "\u00DE", 0x0F],
	[6, 13, "                                                        ", 0x77],
	[6, 69, "\u00DD", 0x08],
	[6, 70, "           ", 0xC4],
	[7, 1, "           ", 0xC4],
	[7, 12, "\u00DE", 0x0F],
	[7, 13, " ", 0x77],
	[7, 14, " ", 0x44],
	[7, 15, "                ", 0x40],
	[7, 31, "Let the Dreams begin!", 0x4E],
	[7, 52, "               ", 0x40],
	[7, 67, " ", 0x44],
	[7, 68, " ", 0x77],
	[7, 69, "\u00DD", 0x08],
	[7, 70, "           ", 0xC4],
	[8, 1, "           ", 0xC4],
	[8, 12, "\u00DE", 0x0F],
	[8, 13, "                                                        ", 0x77],
	[8, 69, "\u00DD", 0x08],
	[8, 70, "           ", 0xC4],
	[9, 1, "           ", 0xC4],
	[9, 12, "\u00DE", 0x0F],
	[9, 13, "      ", 0x77],
	[9, 19, "\u00C9\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BB", 0x70],
	[9, 64, "     ", 0x77],
	[9, 69, "\u00DD", 0x08],
	[9, 70, "           ", 0xC4],
	[10, 1, "           ", 0xC4],
	[10, 12, "\u00DE", 0x0F],
	[10, 13, "      ", 0x77],
	[10, 19, "\u00BA", 0x70],
	[10, 20, "   ", 0x77],
	[10, 23, " ", 0x70],
	[10, 24, "  ", 0x77],
	[10, 26, " ", 0x78],
	[10, 27, "Softdisk Publishing presents", 0x71],
	[10, 55, "        ", 0x77],
	[10, 63, "\u00BA", 0x70],
	[10, 64, "     ", 0x77],
	[10, 69, "\u00DD", 0x08],
	[10, 70, "           ", 0xC4],
	[11, 1, "           ", 0xC4],
	[11, 12, "\u00DE", 0x0F],
	[11, 13, "      ", 0x77],
	[11, 19, "\u00BA", 0x70],
	[11, 20, "   ", 0x77],
	[11, 23, " ", 0x70],
	[11, 24, "        ", 0x77],
	[11, 32, "             ", 0x74],
	[11, 45, "                  ", 0x77],
	[11, 63, "\u00BA", 0x70],
	[11, 64, "     ", 0x77],
	[11, 69, "\u00DD", 0x08],
	[11, 70, "           ", 0xC4],
	[12, 1, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[12, 12, "\u00DE", 0x0F],
	[12, 13, "      ", 0x77],
	[12, 19, "\u00BA", 0x70],
	[12, 20, "   ", 0x77],
	[12, 23, " ", 0x70],
	[12, 24, "          ", 0x77],
	[12, 34, " ", 0x78],
	[12, 35, "KEEN DREAMS", 0x74],
	[12, 46, "                 ", 0x77],
	[12, 63, "\u00BA", 0x70],
	[12, 64, "     ", 0x77],
	[12, 69, "\u00DD", 0x08],
	[12, 70, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[13, 1, "           ", 0xC4],
	[13, 12, "\u00DE", 0x0F],
	[13, 13, "      ", 0x77],
	[13, 19, "\u00BA", 0x70],
	[13, 20, "   ", 0x77],
	[13, 23, " ", 0x70],
	[13, 24, "                                       ", 0x77],
	[13, 63, "\u00BA", 0x70],
	[13, 64, "     ", 0x77],
	[13, 69, "\u00DD", 0x08],
	[13, 70, "           ", 0xC4],
	[14, 1, "           ", 0xC4],
	[14, 12, "\u00DE", 0x0F],
	[14, 13, "      ", 0x77],
	[14, 19, "\u00BA", 0x70],
	[14, 20, "   ", 0x77],
	[14, 23, " ", 0x70],
	[14, 24, "      ", 0x77],
	[14, 30, "    COMMANDER KEEN", 0x78],
	[14, 48, "               ", 0x77],
	[14, 63, "\u00BA", 0x70],
	[14, 64, "     ", 0x77],
	[14, 69, "\u00DD", 0x08],
	[14, 70, "           ", 0xC4],
	[15, 1, "           ", 0xC4],
	[15, 12, "\u00DE", 0x0F],
	[15, 13, "      ", 0x77],
	[15, 19, "\u00BA", 0x70],
	[15, 20, "   ", 0x77],
	[15, 23, " ", 0x70],
	[15, 24, "       ", 0x77],
	[15, 31, " is a trademark of", 0x78],
	[15, 49, "              ", 0x77],
	[15, 63, "\u00BA", 0x70],
	[15, 64, "     ", 0x77],
	[15, 69, "\u00DD", 0x08],
	[15, 70, "           ", 0xC4],
	[16, 1, "           ", 0xC4],
	[16, 12, "\u00DE", 0x0F],
	[16, 13, "      ", 0x77],
	[16, 19, "\u00BA", 0x70],
	[16, 20, "   ", 0x77],
	[16, 23, " ", 0x70],
	[16, 24, "        ", 0x77],
	[16, 32, "   Id Software", 0x78],
	[16, 46, "                 ", 0x77],
	[16, 63, "\u00BA", 0x70],
	[16, 64, "     ", 0x77],
	[16, 69, "\u00DD", 0x08],
	[16, 70, "           ", 0xC4],
	[17, 1, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[17, 12, "\u00DE", 0x0F],
	[17, 13, "      ", 0x77],
	[17, 19, "\u00C8\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00CD\u00BC", 0x70],
	[17, 64, "     ", 0x77],
	[17, 69, "\u00DD", 0x08],
	[17, 70, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[18, 1, "           ", 0xC4],
	[18, 12, "\u00DE", 0x0F],
	[18, 13, "                                                        ", 0x77],
	[18, 69, "\u00DD", 0x08],
	[18, 70, "           ", 0xC4],
	[19, 1, "           ", 0xC4],
	[19, 12, "\u00DE", 0x0F],
	[19, 13, " ", 0x77],
	[19, 14, "                   ", 0x44],
	[19, 33, "Please standby...", 0x4E],
	[19, 50, "                  ", 0x44],
	[19, 68, " ", 0x77],
	[19, 69, "\u00DD", 0x08],
	[19, 70, "           ", 0xC4],
	[20, 1, "           ", 0xC4],
	[20, 12, "\u00DE", 0x0F],
	[20, 13, "                                                        ", 0x77],
	[20, 69, "\u00DD", 0x08],
	[20, 70, "           ", 0xC4],
	[21, 1, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[21, 12, "\u00DE", 0x0F],
	[21, 13, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x78],
	[21, 69, "\u00DD", 0x08],
	[21, 70, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[22, 1, "           ", 0xC4],
	[22, 12, "\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF\u00DF", 0x40],
	[22, 70, "           ", 0xC4],
	[23, 1, "                                                                                ", 0xC4],
	[24, 1, "\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC\u00DC", 0x0C],
	[25, 1, "                                                                                ", 0x07],
]
