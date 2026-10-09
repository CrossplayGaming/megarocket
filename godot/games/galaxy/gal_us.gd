# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's id_us_1.c (printing, windows, line input, the random
# table, the config and saved-game records) and the text-screen half of
# id_us_textscreen.c, by David Gow and the Omnispeak authors, GPL v2 or later.
# Names, order and arithmetic follow omnispeak upstream (A10). Files are byte
# buffers the shell supplies and keeps: no file system here (A11).
class_name GalUS
extends GalIO
## The Galaxy engine's user manager (SIM-G-01c, part 2): text in windows, the
## 256-entry random table, typed input, CONFIG.CKx and the saved-game list.
## The control-panel menus (id_us_2.c with ck_us_2.c) are SIM-G-01i; until
## then US_RunCards returns at once, as if the player backed straight out.

# ===================================================================== CK globals id_us_1 reads and writes
# (defined in ck_main.c / ck_game.c; declared here, the earliest script that uses them)

class CK_HighScore:
	var name: String = ""     # char[58]
	var score: int = 0        # uint32_t
	var arg4: int = 0         # uint16_t: the number of citizens/fuses/... (the episode's item count)

	func copy_from(o: CK_HighScore) -> void:
		name = o.name
		score = o.score
		arg4 = o.arg4


var ck_highScores: Array = _new_high_scores()
var ck_scoreBoxEnabled: bool = false
var ck_svgaCompatibility: bool = false
var ck_fixJerkyMotion: bool = false
var ck_twoButtonFiring: bool = false
var ck_gamePadEnabled: bool = false


static func _new_high_scores() -> Array:
	var a: Array = []
	for i: int in range(8):
		a.append(CK_HighScore.new())
	return a


static func s8(v: int) -> int:
	v &= 0xFF
	return v - 0x100 if v >= 0x80 else v


# ===================================================================== windows and printing

const US_WINDOW_MAX_X: int = 320
const US_WINDOW_MAX_Y: int = 200

class US_WindowRec:
	var x: int = 0
	var y: int = 0
	var w: int = 0
	var h: int = 0
	var px: int = 0
	var py: int = 0


var us_windowX: int = 0
var us_windowY: int = 0
var us_windowW: int = 0
var us_windowH: int = 0
var us_printX: int = 0
var us_printY: int = 0
var us_printFont: int = 0
var us_printColour: int = 15

## USL_MeasureString / USL_DrawString (US_SetPrintRoutines swaps them).
var USL_MeasureString: StringName = &"VH_MeasurePropString"
var USL_DrawString: StringName = &"VHB_DrawPropString"
var p_save_game: StringName = &""
var p_load_game: StringName = &""
var p_exit_menu: StringName = &""


func US_SetPrintRoutines(measure: StringName, draw: StringName) -> void:
	USL_MeasureString = measure if measure != &"" else &"VH_MeasurePropString"
	USL_DrawString = draw if draw != &"" else &"VHB_DrawPropString"


func US_SetMenuFunctionPointers(loadgamefunc: StringName, savegamefunc: StringName, exitmenufunc: StringName) -> void:
	p_load_game = loadgamefunc
	p_save_game = savegamefunc
	p_exit_menu = exitmenufunc


func US_Print(str: String) -> void:
	var i: int = 0
	var n: int = str.length()
	while i < n:
		var line_start: int = i
		while i < n and str.unicode_at(i) != 10:
			i += 1
		var strbuf: String = str.substr(line_start, i - line_start)
		var nl: bool = i < n
		if nl:
			i += 1
		var wh: PackedInt32Array = call(USL_MeasureString, strbuf, us_printFont)
		call(USL_DrawString, strbuf, us_printX, us_printY, us_printFont, us_printColour)
		if nl:
			us_printX = us_windowX
			us_printY = s16(us_printY + wh[1])
		else:
			us_printX = s16(us_printX + wh[0])
			break


func US_PrintF(fmt: String, args: Array) -> void:
	US_Print(fmt % args)


func USL_PrintInCenter(str: String, x1: int, y1: int, x2: int, y2: int) -> void:
	var wh: PackedInt32Array = VH_MeasurePropString(str, us_printFont)
	var rw: int = u16(x2 - x1)
	var rh: int = u16(y2 - y1)
	var px: int = u16(x1 + u16(rw - wh[0]) / 2)
	var py: int = u16(y1 + u16(rh - wh[1]) / 2)
	VHB_DrawPropString(str, px, py, us_printFont, us_printColour)


func US_PrintCentered(str: String) -> void:
	USL_PrintInCenter(str, us_windowX, us_windowY, us_windowX + us_windowW, us_windowY + us_windowH)


func US_CPrintLine(str: String) -> void:
	CA_EnsureGrChunk(3)
	var wh: PackedInt32Array = call(USL_MeasureString, str, us_printFont)
	if wh[0] <= us_windowW:
		var x: int = us_windowX + ((us_windowW - wh[0]) / 2)
		call(USL_DrawString, str, x, us_printY, us_printFont, us_printColour)
		us_printY = s16(us_printY + wh[1])
	else:
		Quit("US_CPrintLine() - String exceeds width")


func US_CPrint(str: String) -> void:
	if str.length() >= 256:
		Quit("US_CPrint() - String too long")
		return
	var i: int = 0
	var n: int = str.length()
	while i < n:
		var line_start: int = i
		while i < n and str.unicode_at(i) != 10:
			i += 1
		US_CPrintLine(str.substr(line_start, i - line_start))
		if i < n:
			i += 1


func US_CPrintF(fmt: String, args: Array) -> void:
	US_CPrint(fmt % args)


func US_ClearWindow() -> void:
	VHB_Bar(us_windowX, us_windowY, us_windowW, us_windowH, 15)
	us_printX = us_windowX
	us_printY = us_windowY


## Coordinates in 8-pixel tiles.
func US_DrawWindow(x: int, y: int, w: int, h: int) -> void:
	us_windowX = s16(x * 8)
	us_windowY = s16(y * 8)
	us_windowW = s16(w * 8)
	us_windowH = s16(h * 8)
	var borderX: int = us_windowX - 8
	var borderY: int = us_windowY - 8
	var borderW: int = us_windowW + 8
	var borderH: int = us_windowH + 8
	us_printX = us_windowX
	us_printY = us_windowY
	US_ClearWindow()
	VHB_DrawTile8M(borderX, borderY, 0)
	VHB_DrawTile8M(borderX, borderY + borderH, 6)
	VHB_DrawTile8M(borderX + borderW, borderY, 2)
	VHB_DrawTile8M(borderX + borderW, borderY + borderH, 8)
	var i: int = borderX + 8
	while i <= borderX + borderW - 8:
		VHB_DrawTile8M(i, borderY, 1)
		VHB_DrawTile8M(i, borderY + borderH, 7)
		i += 8
	i = borderY + 8
	while i <= borderY + borderH - 8:
		VHB_DrawTile8M(borderX, i, 3)
		VHB_DrawTile8M(borderX + borderW, i, 5)
		i += 8


func US_CenterWindow(w: int, h: int) -> void:
	var maxXtile: int = US_WINDOW_MAX_X / 8
	var maxYtile: int = US_WINDOW_MAX_Y / 8
	US_DrawWindow((maxXtile - w) / 2, (maxYtile - h) / 2, w, h)


func US_SaveWindow(win: US_WindowRec) -> void:
	win.x = US_GetWindowX()
	win.y = US_GetWindowY()
	win.w = US_GetWindowW()
	win.h = US_GetWindowH()
	win.px = US_GetPrintX()
	win.py = US_GetPrintY()


func US_RestoreWindow(win: US_WindowRec) -> void:
	US_SetWindowX(win.x)
	US_SetWindowY(win.y)
	US_SetWindowW(win.w)
	US_SetWindowH(win.h)
	US_SetPrintX(win.px)
	US_SetPrintY(win.py)


# ===================================================================== line input

func USL_XORICursor(x: int, y: int, s: String, cursor: int) -> void:
	if cursor > 128:
		Quit("USL_XORICursor: buffer too small!")
		return
	var wh: PackedInt32Array = VH_MeasurePropString(s.substr(0, cursor), us_printFont)
	US_SetPrintX(x + wh[0] - 1)
	US_SetPrintY(y)
	VHB_DrawPropString(char(0x80), US_GetPrintX(), US_GetPrintY(), US_GetPrintFont(), US_GetPrintColour())


## C's isprint over a char.
static func _isprint(c: int) -> bool:
	return c >= 0x20 and c < 0x7F


## Returns [result, text]: text is what the player typed (or `def` unchanged
## when escaped), cut to maxchars as C's strscpy into buf does.
func US_LineInput(x: int, y: int, def: String, escok: bool, maxchars: int, maxwidth: int) -> Array:
	var s: String = def.substr(0, 127)
	var olds: String = ""
	var buf: String = def
	var cursor: int = s.length()
	var cursormoved: bool = true
	var redraw: bool = true
	var cursorvis: bool = false
	var done: bool = false
	var result: bool = false
	var lasttime: int = SD_GetTimeCount()
	IN_SetLastASCII(IN_KP_None)
	IN_SetLastScan(IN_SC_None)
	IN_StartTextInput("", "")
	while not done and not quitting:
		IN_PumpEvents()
		if cursorvis:
			USL_XORICursor(x, y, s, cursor)
		var sc: int = IN_GetLastScan()
		IN_SetLastScan(IN_SC_None)
		var c: int = IN_GetLastASCII()
		IN_SetLastASCII(IN_KP_None)
		match sc:
			IN_SC_LeftArrow:
				if cursor != 0:
					cursor -= 1
				c = 0
				cursormoved = true
			IN_SC_RightArrow:
				if cursor < s.length():
					cursor += 1
				c = 0
				cursormoved = true
			IN_SC_Home:
				cursor = 0
				c = 0
				cursormoved = true
			IN_SC_End:
				cursor = s.length()
				c = 0
				cursormoved = true
			IN_SC_Enter:
				buf = s.substr(0, maxchars)
				done = true
				result = true
				c = 0
			IN_SC_Escape:
				if escok:
					done = true
					result = false
				c = 0
			IN_SC_Backspace:
				if cursor != 0:
					s = s.substr(0, cursor - 1) + s.substr(cursor)
					cursor -= 1
					redraw = true
				c = 0
				cursormoved = true
			IN_SC_Delete:
				if cursor < s.length():
					s = s.substr(0, cursor) + s.substr(cursor + 1)
					redraw = true
				c = 0
				cursormoved = true
			0x4c, IN_SC_UpArrow, IN_SC_DownArrow, IN_SC_PgUp, IN_SC_PgDown, IN_SC_Insert:
				c = 0
		if c != 0:
			var length: int = s.length()
			var wh: PackedInt32Array = VH_MeasurePropString(s, US_GetPrintFont())
			if _isprint(c) and length < 128 - 1 and (maxchars == 0 or length < maxchars) and (maxwidth == 0 or wh[0] < maxwidth):
				s = s.substr(0, cursor) + char(c) + s.substr(cursor)
				cursor += 1
				redraw = true
		if redraw:
			VHB_DrawPropString(olds, x, y, us_printFont, us_printColour)
			olds = s
			VHB_DrawPropString(s, x, y, us_printFont, us_printColour)
			redraw = false
		if cursormoved:
			cursorvis = false
			lasttime = (SD_GetTimeCount() - 70) & 0xFFFFFFFF
			cursormoved = false
		if ((SD_GetTimeCount() - lasttime) & 0xFFFFFFFF) > 35:
			lasttime = SD_GetTimeCount()
			cursorvis = not cursorvis
		if cursorvis:
			USL_XORICursor(x, y, s, cursor)
		VH_UpdateScreen()
	if cursorvis:
		USL_XORICursor(x, y, s, cursor)
	if not result:
		VHB_DrawPropString(olds, x, y, us_printFont, us_printColour)
	VH_UpdateScreen()
	IN_ClearKeysDown()
	IN_StopTextInput()
	return [result, buf]


# ===================================================================== random numbers

const us_RandomTable: PackedByteArray = [
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

var us_randomIndex: int = 0
## The seed US_InitRndT(true) takes: the original reads the clock's hundredths
## (below); here the shell sets it from the session (A11). Not state.
var us_randomSeed: int = 0
## Or the DOS clock itself (A11, set from outside): microseconds since the clock
## read 00:00:00 when the program started (the oracle runner sets it just before
## the game). US_InitRndT is id's assembly (ID_US_A.ASM): DOS GetSystemTime (int
## 21h 2Ch) and DL, the hundredths of a second, which DOS works out from the BIOS
## tick count (18.2 a second). -1: unset, us_randomSeed instead.
var us_dosClockAtStart: int = -1
## HARN-20 (tests only, set from outside): BIOS ticks added to the n-th reading of
## the clock (1 = the first). A death's restart reads it right after the last
## frame, where the original's frame took processing time the port does not
## model, so its tick is fitted per restart as the clock at the start is. Not state.
var us_seedTicks: Dictionary = {}
var us_clockReads: int = 0


## DL of int 21h 2Ch: the BIOS ticks since 00:00:00 as hundredths (DOSBox:
## ticks * 100 / (1193182 / 65536), truncated), modulo 100. The BIOS counts its
## own ticks until SD_Startup takes the timer over, then the game's handler
## passes them on (sd_biosTicks).
func US_DOSHundredths() -> int:
	var before: int = vm.now if sd_startupNow < 0 else sd_startupNow
	var units: int = before + us_dosClockAtStart * DosMachine.PIT_HZ / 1000
	var ticks: int = units / (65536 * DosMachine.UNIT) + sd_biosTicks
	us_clockReads += 1
	ticks += int(us_seedTicks.get(us_clockReads, 0))
	return int(float(ticks) * 100.0 * 65536.0 / float(DosMachine.PIT_HZ)) % 100


func US_InitRndT(randomize: bool) -> void:
	if randomize:
		if us_dosClockAtStart >= 0:
			us_randomIndex = US_DOSHundredths()
		else:
			us_randomIndex = us_randomSeed & 0xFF
	else:
		us_randomIndex = 0


func US_RndT() -> int:
	us_randomIndex = (us_randomIndex + 1) & 0xFF
	return us_RandomTable[us_randomIndex]


func US_SetRndI(index: int) -> void:
	us_randomIndex = index & 0xFFFF


func US_GetRndI() -> int:
	return us_randomIndex


# ===================================================================== common: config and saved games

var us_noWait: bool = false
var us_tedLevel: bool = false
var us_tedLevelNumber: int = 1
var us_started: bool = false
## The program's arguments after its name (US_CheckParm reads them). Not state.
var us_argv: PackedStringArray = PackedStringArray()

## CONFIG.CKx's bytes (empty: no file). The shell loads and keeps it.
var us_configFile: PackedByteArray = PackedByteArray()
const US_MAX_SAVEDGAMENAME_LEN: int = 32
const US_MAX_NUM_OF_SAVED_GAMES: int = 6
## SAVEGAMn.CKx's bytes for each slot (empty: none). The shell keeps them.
var us_saveFiles: Array = [PackedByteArray(), PackedByteArray(), PackedByteArray(),
	PackedByteArray(), PackedByteArray(), PackedByteArray()]

class US_Savefile:
	var id: String = ""
	var printXOffset: int = 0
	var used: bool = false
	var name: String = ""


var us_savefiles: Array = []


func US_CheckParm(parm: String, strings: PackedStringArray) -> int:
	var i: int = 0
	while i < parm.length():
		var c: int = parm.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			break
		i += 1
	parm = parm.substr(i)
	for k: int in range(strings.size()):
		if strings[k] == "":
			break
		if parm.to_upper() == strings[k].to_upper():
			return k
	return -1


func US_ParmPresent(arg: String) -> bool:
	for a: String in us_argv:
		if US_CheckParm(a, PackedStringArray([arg])) != -1:
			return true
	return false


## The file's bytes read the way FS_Read* reads them: C strings by fixed size.
static func _cstr(b: PackedByteArray, o: int, n: int) -> String:
	var e: int = o
	while e < o + n and e < b.size() and b[e] != 0:
		e += 1
	return b.slice(o, e).get_string_from_ascii()


func US_LoadConfig() -> void:
	var sd: int = sdm_AdLib
	var sm: int = smm_AdLib
	var hadQuietSfx: bool = false
	var hadAdlib: bool = false
	var inputDevice: int = 0
	var configFileLoaded: bool = false
	var f: PackedByteArray = us_configFile
	# extension (4), revision (2), 8 high scores (58 + 4 + 2), then the settings
	var size_needed: int = 4 + 2 + 8 * 64 + 2 + 2 + 2 + 10 + 6 * 2 + 1 + 2 + 8
	var valid: bool = f.size() >= 6 and _cstr(f, 0, 4) == data.ext and GalData.u16(f, 4) == 4
	if valid:
		var o: int = 6
		for i: int in range(8):
			var hs: CK_HighScore = ck_highScores[i]
			hs.name = _cstr(f, o, 58)
			hs.score = GalData.u32(f, o + 58) if o + 62 <= f.size() else 0
			hs.arg4 = GalData.u16(f, o + 62) if o + 64 <= f.size() else 0
			o += 64
		# a short file reads as far as it goes (FS_ReadInt16LE returns 0 past the end)
		if o + 2 <= f.size():
			sd = s16(GalData.u16(f, o))
		o += 2
		if o + 2 <= f.size():
			sm = s16(GalData.u16(f, o))
		o += 2
		if o + 2 <= f.size():
			inputDevice = s16(GalData.u16(f, o))
		o += 2
		if o + 10 <= f.size():
			for k: String in ["jump", "pogo", "upLeft", "up", "upRight", "left", "right", "downLeft", "down", "downRight"]:
				in_kbdControls[k] = f[o]
				o += 1
		else:
			o += 10
		var bools: Array = []
		for k: int in range(6):
			bools.append(o + 2 <= f.size() and GalData.u16(f, o) != 0)
			o += 2
		ck_scoreBoxEnabled = bools[0]
		ck_svgaCompatibility = bools[1]
		hadQuietSfx = bools[2]
		hadAdlib = bools[3]
		ck_fixJerkyMotion = bools[4]
		ck_twoButtonFiring = bools[5]
		if o < f.size():
			in_kbdControls["fire"] = f[o]
		o += 1
		ck_gamePadEnabled = o + 2 <= f.size() and GalData.u16(f, o) != 0
		o += 2
		for k: int in range(4):
			if o + 2 <= f.size():
				in_gamepadButtons[k] = s16(GalData.u16(f, o))
			o += 2
		configFileLoaded = true
	else:
		sd = sdm_Off
		sm = smm_Off
		inputDevice = 0
		ck_scoreBoxEnabled = true
		ck_twoButtonFiring = false
		configFileLoaded = false
		in_gamepadButtons[0] = 0
		in_gamepadButtons[1] = 1
		in_gamepadButtons[2] = -1
		in_gamepadButtons[3] = -1
	SD_SetQuietSfx(hadQuietSfx)
	SD_Default(configFileLoaded and (hadAdlib == SD_IsAdlibPresent()), sd, sm)
	IN_Default(configFileLoaded, inputDevice)


static func _put16(b: PackedByteArray, v: int) -> void:
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)


static func _putstr(b: PackedByteArray, s: String, n: int) -> void:
	var a: PackedByteArray = s.to_ascii_buffer()
	for i: int in range(n):
		b.append(a[i] if i < a.size() else 0)


func US_SaveConfig() -> void:
	var f: PackedByteArray = PackedByteArray()
	_putstr(f, data.ext, 4)
	_put16(f, 4)
	for i: int in range(8):
		var hs: CK_HighScore = ck_highScores[i]
		_putstr(f, hs.name, 58)
		_put16(f, hs.score & 0xFFFF)
		_put16(f, (hs.score >> 16) & 0xFFFF)
		_put16(f, hs.arg4)
	_put16(f, SD_GetSoundMode())
	_put16(f, SD_GetMusicMode())
	var dev: int = in_controlType
	if dev == IN_ctrl_All:
		dev = in_backupControlType
	_put16(f, dev)
	for k: String in ["jump", "pogo", "upLeft", "up", "upRight", "left", "right", "downLeft", "down", "downRight"]:
		f.append(int(in_kbdControls[k]) & 0xFF)
	for v: bool in [ck_scoreBoxEnabled, ck_svgaCompatibility, SD_GetQuietSfx(), SD_IsAdlibPresent(), ck_fixJerkyMotion, ck_twoButtonFiring]:
		_put16(f, int(v))
	f.append(int(in_kbdControls["fire"]) & 0xFF)
	_put16(f, int(ck_gamePadEnabled))
	for k: int in range(4):
		_put16(f, in_gamepadButtons[k] & 0xFFFF)
	us_configFile = f


func US_GetSavefiles() -> void:
	us_savefiles = []
	for i: int in range(US_MAX_NUM_OF_SAVED_GAMES):
		var psfe: US_Savefile = US_Savefile.new()
		var h: PackedByteArray = us_saveFiles[i]
		var valid: bool = false
		# id[4], printXOffset u16, used (bool as u16), name[33], one byte of padding
		if h.size() >= 4 + 2 + 2 + 33 + 1:
			psfe.id = _cstr(h, 0, 4)
			psfe.printXOffset = GalData.u16(h, 4)
			psfe.used = GalData.u16(h, 6) != 0
			psfe.name = _cstr(h, 8, US_MAX_SAVEDGAMENAME_LEN + 1)
			if h.slice(0, 4).get_string_from_ascii().substr(0, 4) == data.ext.substr(0, 4) and \
					psfe.printXOffset == CK_INT("ck_exe_printXOffset", 0xF00D):
				valid = true
		if not valid:
			psfe.id = data.ext
			psfe.used = false
			psfe.name = "Empty"
		else:
			psfe.used = true
		us_savefiles.append(psfe)


func US_Startup() -> void:
	US_InitRndT(true)
	US_LoadConfig()
	var parms: PackedStringArray = PackedStringArray(["TEDLEVEL", "NOWAIT", ""])
	for i: int in range(us_argv.size()):
		match US_CheckParm(us_argv[i], parms):
			0:
				us_tedLevelNumber = us_argv[i + 1].to_int() if i + 1 < us_argv.size() else 0
				if us_tedLevelNumber > -1:
					us_tedLevel = true
			1:
				us_noWait = true
	us_started = true


func US_Setup() -> void:
	p_save_game = &""
	p_load_game = &""
	US_GetSavefiles()


func US_Shutdown() -> void:
	if not us_started:
		return
	US_SaveConfig()


func US_GetWindowX() -> int:
	return us_windowX


func US_GetWindowY() -> int:
	return us_windowY


func US_GetWindowW() -> int:
	return us_windowW


func US_GetWindowH() -> int:
	return us_windowH


func US_GetPrintX() -> int:
	return us_printX


func US_GetPrintY() -> int:
	return us_printY


func US_GetPrintFont() -> int:
	return us_printFont


func US_GetPrintColour() -> int:
	return us_printColour


func US_SetWindowX(parm: int) -> void:
	us_windowX = s16(parm)


func US_SetWindowY(parm: int) -> void:
	us_windowY = s16(parm)


func US_SetWindowW(parm: int) -> void:
	us_windowW = s16(parm)


func US_SetWindowH(parm: int) -> void:
	us_windowH = s16(parm)


func US_SetPrintX(parm: int) -> void:
	us_printX = s16(parm)


func US_SetPrintY(parm: int) -> void:
	us_printY = s16(parm)


func US_SetPrintFont(parm: int) -> void:
	us_printFont = s16(parm)


func US_SetPrintColour(parm: int) -> void:
	us_printColour = s8(parm)


# ===================================================================== id_us_2 (SIM-G-01i)

const US_Comm_None: int = 0
const US_Comm_ReturnToGame: int = 1
const US_Comm_EndGame: int = 2
const US_Comm_Quit: int = 3
const US_Comm_LoadGame: int = 4
const US_Comm_NewEasyGame: int = 5
const US_Comm_NewNormalGame: int = 6
const US_Comm_NewHardGame: int = 7

var game_unsaved: int = 0
var game_in_progress: int = 0
var quit_to_dos: int = 0
var load_game_error: int = 0
var us_currentCommand: int = US_Comm_None
var command_confirmed: bool = false


## The control panel: SIM-G-01i. Until then the player leaves it at once.
func US_RunCards() -> void:
	us_currentCommand = US_Comm_ReturnToGame if game_in_progress != 0 else US_Comm_None


func US_DrawCards() -> void:
	pass


# ===================================================================== id_us_textscreen

## The 80x25 text screen the original copies to B800:0000 as it quits (the
## order screen): character and attribute bytes. The shell shows it.
var us_textScreen: PackedByteArray = PackedByteArray()


func US_TerminalOk() -> bool:
	return true


func US_PrintB8000Text(textscreen: PackedByteArray, numChars: int) -> void:
	us_textScreen = textscreen.slice(0, numChars * 2)
