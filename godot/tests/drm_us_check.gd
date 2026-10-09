# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01d: the Dreams user manager (drm_us.gd) without the game's graphics: US_CheckParm, the
## random table against id_us_a.c's, US_InitRndT's DOS clock seed (the Galaxy model), window and
## print arithmetic, the text-mode start screens, the config file's round trip and layout, the
## saved-game headers, the high-score table's insertion order (with typed names), and gelib's
## buffered reads, MoveGfxDst and ILBM unpacking. The drawing and input calls the code makes
## are replaced by recorders in a subclass made here, each with the signature the class chain
## has for it now (an untyped stub or a library's typed function), so the check runs before and
## after DrmVW and DrmIO land.

var t: T = T.new()

## The calls the recorders replace: name -> [body, return expression ("" for none)].
const OVERRIDES: Dictionary = {
	"VWB_Bar": ["calls.append([\"bar\", a0, a1, a2, a3, a4])", ""],
	"VWB_DrawTile8M": ["calls.append([\"tile\", a0, a1, a2])", ""],
	"VW_InitDoubleBuffer": ["pass", ""],
	"VW_UpdateScreen": ["pass", ""],
	"VW_HideCursor": ["pass", ""],
	"VW_ShowCursor": ["pass", ""],
	"IN_ClearKeysDown": ["pass", ""],
	"IN_UserInput": ["pass", "false"],
	"SD_GetTimeCount": ["ticks += 1", "ticks"],
	"BE_ST_ShortSleep": ["_next_key()", ""],
	"SD_Default": ["defaults.append([\"sd\", a0, a1, a2])", ""],
	"IN_Default": ["defaults.append([\"in\", a0, a1])", ""],
}

const HEADER: String = """extends DrmUS
var calls: Array = []
var drawn: Array = []
var defaults: Array = []
var keyq: Array = []
var ticks: int = 0


func _t_measure(s: String, optsend: int, _w: Variant, _h: Variant) -> PackedInt32Array:
	var n: int = s.length() if optsend < 0 else optsend
	return PackedInt32Array([n * 8, 10])


func _t_draw(s: String, optsend: int) -> void:
	drawn.append([px, py, s if optsend < 0 else s.substr(0, optsend)])


func _next_key() -> void:
	if keyq.is_empty():
		LastScan = sc_Return
		LastASCII = 13
	else:
		var k: Array = keyq.pop_front()
		LastScan = k[0]
		LastASCII = k[1]
"""


## A recorder's header with the signature the chain has for `name` (the most derived first).
func _signature(name: String) -> Array:
	for m: Dictionary in (DrmUS as Script).get_script_method_list():
		if m.name != name:
			continue
		var args: PackedStringArray = PackedStringArray()
		for k: int in range(m.args.size()):
			var a: Dictionary = m.args[k]
			if a.type == TYPE_NIL:
				args.append("a%d" % k)
			elif a.type == TYPE_OBJECT:
				args.append("a%d: %s" % [k, a.class_name])
			else:
				args.append("a%d: %s" % [k, type_string(a.type)])
		var ret: String = ""
		var void_ret: bool = false
		if m.return.type == TYPE_NIL:
			if not (m.return.usage & PROPERTY_USAGE_NIL_IS_VARIANT):
				ret = " -> void"
				void_ret = true
		else:
			ret = " -> " + type_string(m.return.type)
		return ["func %s(%s)%s:" % [name, ", ".join(args), ret], void_ret]
	return []


func _make_us() -> DrmUS:
	var src: String = HEADER
	for name: String in OVERRIDES:
		var sig: Array = _signature(name)
		if sig.is_empty():
			t.blocked("no method %s in the class chain" % name)
			return null
		src += "\n\n" + sig[0] + "\n\t" + OVERRIDES[name][0] + "\n"
		if not sig[1]:
			var r: String = OVERRIDES[name][1]
			src += "\treturn %s\n" % (r if r != "" else "null")
	var gs: GDScript = GDScript.new()
	gs.source_code = src
	if gs.reload() != OK:
		t.blocked("the recorder subclass does not compile")
		return null
	var u: DrmUS = gs.new()
	u.vm = DosMachine.new()
	u.US_SetPrintRoutines(&"_t_measure", &"_t_draw")
	return u


## id_us_a.c's rndtable, read from the reference.
func _c_rndtable() -> PackedByteArray:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../refkeen/src/kdreams/id_us_a.c")
	var text: String = FileAccess.get_file_as_string(path)
	var a: int = text.find("rndtable[] = {")
	var b: int = text.find("};", a)
	var out: PackedByteArray = PackedByteArray()
	if a < 0 or b < 0:
		return out
	var re: RegEx = RegEx.create_from_string("\\d+")
	for m: RegExMatch in re.search_all(text.substr(a + 14, b - a - 14)):
		out.append(m.get_string().to_int())
	return out


func _init() -> void:
	var u: DrmUS = _make_us()
	if u == null:
		t.finish(self)
		return
	_check_parm(u)
	_check_random(u)
	_check_windows(u)
	_check_text_screen(_make_us())
	_check_config()
	_check_saved_games(_make_us())
	_check_high_scores(_make_us())
	_check_gelib(_make_us())
	t.finish(self)


func _check_parm(u: DrmUS) -> void:
	var p: PackedStringArray = PackedStringArray(["TEDLEVEL", "NOWAIT", ""])
	t.eq("US_CheckParm /tedlevel", u.US_CheckParm("/tedlevel", p), 0)
	t.eq("US_CheckParm -NoWait (any case, after non-letters)", u.US_CheckParm("--NoWait", p), 1)
	t.eq("US_CheckParm TEDLEVELX (the string a prefix of the parameter)", u.US_CheckParm("TEDLEVELX", p), 0)
	t.eq("US_CheckParm TED (the parameter shorter)", u.US_CheckParm("TED", p), -1)
	t.eq("US_CheckParm 123", u.US_CheckParm("123", p), -1)
	t.eq("US_CheckParm stops at the empty string", u.US_CheckParm("b", PackedStringArray(["A", "", "B"])), -1)


func _check_random(u: DrmUS) -> void:
	var table: PackedByteArray = _c_rndtable()
	t.eq("id_us_a.c's table read (256 entries)", table.size(), 256)
	t.eq("rndtable equals id_us_a.c's", u.rndtable, table)
	u.US_InitRndT(false)
	var seq: PackedByteArray = PackedByteArray()
	for i: int in range(300):
		seq.append(u.US_RndT())
	var want: PackedByteArray = PackedByteArray()
	for i: int in range(300):
		want.append(table[(i + 1) & 0xFF])
	t.eq("US_InitRndT(false), then 300 US_RndT: table[1], table[2], ... wrapping", seq, want)
	# the DOS clock: DL of int 21h 2Ch (hundredths) from the BIOS ticks, as gal_us.gd
	for clock_us: int in [0, 45296780000, 86399990000]:
		u.vm.now = 123456789
		u.us_dosClockAtStart = clock_us
		u.US_InitRndT(true)
		@warning_ignore("integer_division")
		var units: int = u.vm.now + clock_us * DosMachine.PIT_HZ / 1000
		@warning_ignore("integer_division")
		var ticks: int = units / (65536 * DosMachine.UNIT)
		var hundredths: int = int(float(ticks) * 100.0 * 65536.0 / float(DosMachine.PIT_HZ)) % 100
		t.eq("US_InitRndT(true) at clock %d us: the hundredths" % clock_us, u.rndindex, hundredths)
		var g: GalUS = GalUS.new()
		g.vm = u.vm
		g.us_dosClockAtStart = clock_us
		t.eq("  ... as the Galaxy port's US_DOSHundredths", u.rndindex, g.US_DOSHundredths())
	u.us_dosClockAtStart = -1
	u.us_randomSeed = 0x1234
	u.US_InitRndT(true)
	t.eq("US_InitRndT(true) without a clock: the session seed's low byte", u.rndindex, 0x34)


func _check_windows(u: DrmUS) -> void:
	u.calls.clear()
	u.US_CenterWindow(30, 15)
	t.eq("US_CenterWindow(30,15): WindowX/Y/W/H", [u.WindowX, u.WindowY, u.WindowW, u.WindowH], [40, 40, 240, 120])
	t.eq("  PrintX/PrintY homed", [u.PrintX, u.PrintY], [40, 40])
	t.eq("  cleared to white", u.calls[0], ["bar", 40, 40, 240, 120, u.WHITE])
	var tiles: Array = u.calls.filter(func(c: Array) -> bool: return c[0] == "tile")
	t.eq("  the frame: 94 tiles", tiles.size(), 94)
	t.eq("  corners", [tiles[0], tiles[1]], [["tile", 32, 32, 0], ["tile", 32, 160, 6]])
	t.ok("  top right corner and right side", tiles.has(["tile", 280, 32, 2]) and tiles.has(["tile", 280, 160, 8]) and tiles.has(["tile", 280, 152, 5]))
	u.calls.clear()
	u.US_CenterWindow(41, 3)
	t.eq("US_CenterWindow(41,3): (40 - w) wraps as a word", u.WindowX, 0xFFF8)
	u.US_CenterWindow(30, 15)
	u.PrintX = 99
	u.PrintY = 77
	u.US_HomeWindow()
	t.eq("US_HomeWindow", [u.PrintX, u.PrintY], [40, 40])
	var wr: DrmDecl.WindowRec = DrmDecl.WindowRec.new()
	u.PrintX = 50
	u.US_SaveWindow(wr)
	u.US_DrawWindow(1, 1, 5, 5)
	u.US_RestoreWindow(wr)
	t.eq("US_SaveWindow / US_RestoreWindow", [u.WindowX, u.WindowY, u.WindowW, u.WindowH, u.PrintX, u.PrintY], [40, 40, 240, 120, 50, 40])
	# printing with an 8x10 measuring stub
	u.US_HomeWindow()
	u.drawn.clear()
	u.US_Print("AB\nCDE")
	t.eq("US_Print AB\\nCDE: lines drawn at", u.drawn, [[40, 40, "AB"], [40, 50, "CDE"]])
	t.eq("  then PrintX/PrintY", [u.PrintX, u.PrintY], [64, 50])
	u.drawn.clear()
	u.US_Print("X\n")
	t.eq("US_Print X\\n: back to the window's left, a line down", [u.drawn, u.PrintX, u.PrintY], [[[64, 50, "X"]], 40, 60])
	u.drawn.clear()
	u.US_CPrintLine("ABCD", -1)
	t.eq("US_CPrintLine ABCD: centred, PrintY a line on", [u.drawn, u.PrintY], [[[144, 60, "ABCD"]], 70])
	u.drawn.clear()
	u.US_CPrint("A\nBB")
	t.eq("US_CPrint A\\nBB", [u.drawn, u.PrintY], [[[156, 70, "A"], [152, 80, "BB"]], 90])
	u.drawn.clear()
	u.US_PrintCentered("ABC")
	t.eq("US_PrintCentered ABC: in the window's middle", u.drawn, [[148, 95, "ABC"]])
	u.drawn.clear()
	u.US_HomeWindow()
	u.US_PrintUnsigned(-1)
	u.US_PrintSigned(-5)
	t.eq("US_PrintUnsigned(-1), US_PrintSigned(-5)", [u.drawn[0][2], u.drawn[1][2]], ["4294967295", "-5"])


func _cell(u: DrmUS, x: int, y: int) -> Array:
	var o: int = x * 2 + y * 160
	return [u.textmem[o], u.textmem[o + 1]]


func _row_text(u: DrmUS, x: int, y: int, n: int) -> String:
	var s: String = ""
	for i: int in range(n):
		s += String.chr(u.textmem[(x + i) * 2 + y * 160])
	return s


func _check_text_screen(u: DrmUS) -> void:
	u.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE100
	u.current_gamever_int = 100
	u.US_TextScreen()
	t.eq("v1.00 start screen: 'Keen Dreams' at row 3 column 45", _row_text(u, 44, 2, 11), "Keen Dreams")
	t.eq("  in attribute 1Fh", _cell(u, 44, 2)[1], 0x1F)
	t.eq("  the top border: CDh in 1Eh", [_cell(u, 0, 0), _cell(u, 79, 0)], [[0xCD, 0x1E], [0xCD, 0x1E]])
	t.eq("  'Initializing...Please Wait' at row 23 column 28", _row_text(u, 27, 22, 27), "Initializing...Please Wait ")
	t.eq("  the card in text mode", u.vm.card.video_mode, 3)
	t.eq("  cursor at the bottom left", u.textcursor, Vector2i(0, 24))
	t.ok("  no TED launch", not u.tedlevel)
	u.USL_Show(21, 7, 4, true, true)
	t.eq("USL_Show(21,7,4,on,lit): a checkmark, attributes 4Fh over w + 1 cells",
		[_cell(u, 20, 7), _cell(u, 24, 7)[1], _cell(u, 25, 7)[1]], [[251, 0x4F], 0x4F, 0x4E])
	u.USL_ShowMem(63, 15, 612)
	t.eq("USL_ShowMem 612: right-justified in five", _row_text(u, 63, 15, 5), "  612")
	u.US_UpdateTextScreen()
	t.eq("US_UpdateTextScreen: Initializing becomes Loading", _row_text(u, 27, 22, 15), "  Loading...   ")

	var v: DrmUS = _make_us()
	v.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE193
	v.current_gamever_int = 193
	v.id0_argv = PackedStringArray(["/TEDLEVEL", "3"])
	v.US_TextScreen()
	t.eq("v1.93 start screen: 'Please standby...' at row 19 column 33", _row_text(v, 32, 18, 17), "Please standby...")
	t.eq("  in attribute 4Eh", _cell(v, 32, 18)[1], 0x4E)
	t.eq("  the bottom row: spaces in 07h", _cell(v, 0, 24), [0x20, 0x07])
	t.eq("  /TEDLEVEL 3: tedlevel, tedlevelnum", [v.tedlevel, v.tedlevelnum], [true, 3])
	v.US_FinishTextScreen()
	t.eq("US_FinishTextScreen (TED: no key wait): the text screen cleared", _row_text(v, 32, 18, 17), " ".repeat(17))


func _check_config() -> void:
	var u: DrmUS = _make_us()
	u.current_gamever_int = 100
	u.RefKeen_Patch_id_us()
	t.eq("RefKeen_Patch_id_us: v1.00's config file", u.refkeen_compat_config_filename, "CONFIG.KDR")
	u.USL_ReadConfig()
	t.eq("no config file: defaults (sound off, keyboard)", u.defaults, [["sd", false, DrmDecl.sdm_Off, DrmDecl.smm_Off], ["in", false, DrmDecl.ctrl_Keyboard]])
	t.ok("  high scores dirty", u.HighScoresDirty)

	for i: int in range(u.MaxScores):
		var hs: DrmUS.HighScore = u.Scores[i]
		DrmUS._strcpy(hs.name, "Player %d" % i)
		hs.score = 100000 - i * 7919 if i != 3 else -5
		hs.completed = i * 3
	DrmUS._strcpy(u.Scores[2].name, "Al")    # what strcpy leaves after the NUL is kept
	u.SoundMode = DrmDecl.sdm_PC
	u.MusicMode = DrmDecl.smm_AdLib
	u.Controls[0] = DrmDecl.ctrl_Joystick1
	var kd: DrmDecl.KeyboardDef = u._kbddef0()
	var keys: Array = [0x1d, 0x38, 0x47, 0x48, 0x49, 0x4b, 0x4d, 0x4f, 0x50, 0x51]
	keys[0] = 0x2a
	keys[9] = 0x10
	for j: int in range(10):
		kd.set(u.KeyMaps[j], keys[j])
	u.USL_WriteConfig()
	var f: PackedByteArray = u.us_files.get("CONFIG.KDR", PackedByteArray())
	t.eq("USL_WriteConfig: 10 x 64 bytes of scores, three words, ten scan codes", f.size(), 656)
	t.eq("  the third score's name bytes (strcpy's leftovers kept)", f.slice(128, 136), PackedByteArray([65, 108, 0, 121, 101, 114, 32, 50]))
	t.eq("  the fourth score (-5) as a long, its count as a word", [f.decode_s32(192 + 58), f.decode_u16(192 + 62)], [-5, 9])
	t.eq("  sound, music, control words", [f.decode_u16(640), f.decode_u16(642), f.decode_u16(644)], [DrmDecl.sdm_PC, DrmDecl.smm_AdLib, DrmDecl.ctrl_Joystick1])
	t.eq("  the scan codes", f.slice(646, 656), PackedByteArray(keys))

	var r: DrmUS = _make_us()
	r.current_gamever_int = 100
	r.RefKeen_Patch_id_us()
	r.us_files["CONFIG.KDR"] = f
	r.USL_ReadConfig()
	var same: bool = true
	for i: int in range(u.MaxScores):
		var a: DrmUS.HighScore = u.Scores[i]
		var b: DrmUS.HighScore = r.Scores[i]
		same = same and a.name == b.name and a.score == b.score and a.completed == b.completed
	t.ok("USL_ReadConfig reads the scores back (names' bytes, signed scores, counts)", same)
	t.eq("  and passes the modes on", r.defaults, [["sd", true, DrmDecl.sdm_PC, DrmDecl.smm_AdLib], ["in", true, DrmDecl.ctrl_Joystick1]])
	var got: Array = []
	for j: int in range(10):
		got.append(int(r._kbddef0().get(r.KeyMaps[j])))
	t.eq("  the keyboard definition", got, keys)
	t.ok("  high scores not dirty", not r.HighScoresDirty)
	r.US_Started = true
	r.us_files.erase("CONFIG.KDR")
	r.US_Shutdown()
	t.eq("US_Shutdown writes the config again", r.us_files.get("CONFIG.KDR", PackedByteArray()).size(), 656)

	var s: DrmUS = _make_us()
	s.current_gamever_int = 193
	s.RefKeen_Patch_id_us()
	t.eq("v1.93's config file", s.refkeen_compat_config_filename, "KDREAMS.CFG")
	s.us_files["KDREAMS.CFG"] = f.slice(0, 70)
	s.USL_ReadConfig()
	t.eq("a short config: what is there is read", [DrmUS._cstring(s.Scores[0].name), s.Scores[0].score, DrmUS._cstring(s.Scores[1].name)], ["Player 0", 100000, "Player"])
	t.eq("  the rest as before (10000)", s.Scores[2].score, 10000)


func _check_saved_games(u: DrmUS) -> void:
	var h: PackedByteArray = PackedByteArray([75, 68, 82, 0, 1, 0])
	var name: PackedByteArray = PackedByteArray()
	name.resize(33)
	DrmUS._strcpy(name, "My Game")
	h.append_array(name)
	h.append(0)
	h.append_array(PackedByteArray([1, 2, 3]))    # the game's own data after the header
	u.us_files["SAVEGM0.KDR"] = h
	var bad: PackedByteArray = h.duplicate()
	bad[2] = 88    # "KDX"
	u.us_files["SAVEGM3.KDR"] = bad
	u.us_files["SAVEGM5.KDR"] = h.slice(0, 20)    # short
	u.US_Setup()
	var present: Array = []
	for g: DrmUS.US_SaveGame in u.Games:
		present.append(g.present)
	t.eq("US_Setup: which saved games are present", present, [true, false, false, false, false, false, false])
	t.eq("  the first's name", DrmUS._cstring(u.Games[0].name), "My Game")
	t.eq("  the others Empty, signed KDR", [DrmUS._cstring(u.Games[3].name), DrmUS._cstring(u.Games[3].signature)], ["Empty", "KDR"])
	t.eq("USL_GiveSaveName(6)", u.USL_GiveSaveName(6), "SAVEGM6.KDR")


func _check_high_scores(u: DrmUS) -> void:
	# the first: typed K, E, N then Return; the second: Z then Return
	u.keyq = [[DrmDecl.sc_None, 75], [DrmDecl.sc_None, 69], [DrmDecl.sc_None, 78], [DrmDecl.sc_Return, 13]]
	u.US_CheckHighScore(20000, 3)
	t.eq("US_CheckHighScore(20000, 3): first, named", [u.Scores[0].score, u.Scores[0].completed, DrmUS._cstring(u.Scores[0].name)], [20000, 3, "KEN"])
	t.eq("  the rest moved down", [u.Scores[1].score, u.Scores[9].score], [10000, 10000])
	t.ok("  high scores dirty", u.HighScoresDirty)
	var digits: String = ""
	for c: String in "20000":
		digits += String.chr(c.unicode_at(0) + 81)
	t.ok("  the score drawn in the fixed-width digits (129...)", u.drawn.any(func(d: Array) -> bool: return d[2] == digits))
	u.keyq = [[DrmDecl.sc_None, 90], [DrmDecl.sc_Return, 13]]
	u.US_CheckHighScore(10000, 2)
	t.eq("US_CheckHighScore(10000, 2): an equal score with more done goes before", [u.Scores[1].score, u.Scores[1].completed, DrmUS._cstring(u.Scores[1].name)], [10000, 2, "Z"])
	t.eq("  and the earlier 10000s after it", [u.Scores[2].score, u.Scores[2].completed, u.Scores[9].score], [10000, 0, 10000])
	u.keyq = [[DrmDecl.sc_None, 81], [DrmDecl.sc_Escape, 27]]
	u.US_CheckHighScore(15000, 0)
	t.eq("US_CheckHighScore(15000, 0), escaped: placed, the name left empty", [u.Scores[1].score, DrmUS._cstring(u.Scores[1].name), u.Scores[2].score], [15000, "", 10000])
	u.HighScoresDirty = false
	u.US_CheckHighScore(5000, 9)
	t.ok("US_CheckHighScore(5000, 9): not placed", not u.HighScoresDirty and u.Scores[9].score == 10000)
	var order: Array = []
	for hs: DrmUS.HighScore in u.Scores:
		order.append(hs.score)
	t.eq("  the table", order, [20000, 15000, 10000, 10000, 10000, 10000, 10000, 10000, 10000, 10000])
	t.eq("  the names", [DrmUS._cstring(u.Scores[0].name), DrmUS._cstring(u.Scores[2].name)], ["KEN", "Z"])
	# US_LineInput's editing: A B C, Left, Left, Backspace, X, End, D, Return
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(10)
	u.keyq = [[0, 65], [0, 66], [0, 67], [DrmDecl.sc_LeftArrow, 0], [DrmDecl.sc_LeftArrow, 0],
		[DrmDecl.sc_BackSpace, 0], [0, 88], [DrmDecl.sc_End, 0], [0, 68], [DrmDecl.sc_Return, 13]]
	var ok: bool = u.US_LineInput(0, 0, buf, null, true, 0, 0)
	t.eq("US_LineInput: editing keys", [ok, DrmUS._cstring(buf)], [true, "XBCD"])
	u.keyq = [[0, 65], [0, 66], [0, 67], [DrmDecl.sc_Return, 13]]
	ok = u.US_LineInput(0, 0, buf, "Q", true, 2, 0)
	t.eq("US_LineInput: default Q, at most 2 characters", [ok, DrmUS._cstring(buf)], [true, "QA"])


func _check_gelib(u: DrmUS) -> void:
	u.linewidth = 64
	u.MoveGfxDst(0, 200)
	t.eq("MoveGfxDst(0, 200): bufferofs = displayofs = 200 * linewidth", [u.bufferofs, u.displayofs], [12800, 12800])
	u.MoveGfxDst(-8, 1)
	t.eq("MoveGfxDst(-8, 1)", u.displayofs, 63)

	var data: PackedByteArray = PackedByteArray()
	for i: int in range(600):
		data.append((i * 7) & 0xFF)
	u.us_files["KDREAMS.CMP"] = data
	t.eq("VerifyReadOnly", [u.VerifyReadOnly("kdreams.cmp"), u.VerifyReadOnly("NONE.XXX")], [600, 0])
	var bio: DrmUS.BufferedIO = DrmUS.BufferedIO.new()
	var buffer: PackedByteArray = u.InitBufferedIO(u.BE_Cross_open_readonly_for_reading("KDREAMS.CMP"), bio)
	t.eq("InitBufferedIO: a 512-byte buffer", buffer.size(), 512)
	var back: PackedByteArray = PackedByteArray()
	for i: int in range(600):
		back.append(u.bio_readch(bio))
	t.eq("bio_readch: the file's bytes in order (two fills)", back, data)
	u.FreeBufferedIO(bio)
	t.ok("FreeBufferedIO", bio.buffer.is_empty())

	# a 16-pixel-wide, two-row, four-plane ILBM body, packbits
	var shp: DrmUS.Shape = DrmUS.Shape.new()
	shp.bmHdr.w = 16
	shp.bmHdr.h = 2
	shp.bmHdr.d = 4
	shp.bmHdr.comp = 1
	shp.BPR = 2
	shp.Data = PackedByteArray([0x01, 0xA1, 0xA2, 0xFF, 0xB0, 0x01, 0xC1, 0xC2, 0xFF, 0xD0,
		0xFF, 0x11, 0x01, 0x21, 0x22, 0x80, 0x00, 0x33, 0x01, 0x41, 0x42])
	u.BE_ST_SetScreenMode(0x0D)
	u.ylookup = PackedInt32Array([0, 40])
	u.displayofs = 0x100
	u.UnpackEGAShapeToScreen(shp, 8, 0)
	var got: Array = []
	for row: int in range(2):
		for p: int in range(4):
			var o: int = 0x101 + row * 40
			got.append([u.BE_ST_EGAFetchGFXByteFromPlane(o, p), u.BE_ST_EGAFetchGFXByteFromPlane(o + 1, p)])
	t.eq("UnpackEGAShapeToScreen: literal and repeat runs, the 0x80 no-op, a plane a run",
		got, [[0xA1, 0xA2], [0xB0, 0xB0], [0xC1, 0xC2], [0xD0, 0xD0], [0x11, 0x11], [0x21, 0x22], [0x33, 0x00], [0x41, 0x42]])
