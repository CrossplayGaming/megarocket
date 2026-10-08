# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-G-01c (part 2): the Galaxy user manager. A centred window clears to
## white inside a border of the eight frame tiles; centred text lines sit
## symmetric about the window's middle and advance the print line by the font
## height; US_Print carries the pen along a line and back to the window's left
## at a newline. The random table runs from the index as omnispeak's does.
## Typed keys (with a backspace) through the keyboard interrupt come back from
## US_LineInput as text; Escape returns the default. CONFIG.CKx written and
## read back keeps the high scores, keys and switches; with no file the
## defaults are omnispeak's. No saved games reads as six "Empty" slots.
##
## Options: --game_data=<folder>  --games=keen4,keen5,keen6

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const EP: Dictionary = {"keen4": 1, "keen5": 2, "keen6": 3}


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	for game: String in str(opts.get("games", "keen4")).split(",", false):
		_game(t, root, game)
	t.finish(self)


## Columns [first, last] in rows y0..y1 of the screen surface that are not `bg`.
func inked(scr: GalLib.VL_Surface, x0: int, x1: int, y0: int, y1: int, bg: int) -> Vector2i:
	var lo: int = 1 << 30
	var hi: int = -1
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			if scr.pixels[y * scr.w + x] != bg:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return Vector2i(lo, hi)


func _game(t: T, root: String, game: String) -> void:
	var d: GalData = GalData.new()
	if not t.ok("%s: files load (%s)" % [game, d.error], d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalUS = GalUS.new()
	g.vm = vm
	g.data = d
	g.ck_currentEpisode_ep = EP[game]
	g.CA_Startup()
	g.VL_Startup()
	g.RF_Startup()
	g.SD_Startup()
	g.IN_Startup()
	var scr: GalLib.VL_Surface = g.vl_screen
	var tiles8: PackedByteArray = d.tiles8()

	# ---- a centred window
	g.VL_ScreenRect(0, 0, scr.w, scr.h, 3)
	g.US_CenterWindow(20, 5)
	var wx: int = g.US_GetWindowX()
	var wy: int = g.US_GetWindowY()
	var ww: int = g.US_GetWindowW()
	var wh: int = g.US_GetWindowH()
	var bad: int = 0
	for y: int in range(wy, wy + wh):
		for x: int in range(wx, wx + ww):
			if scr.pixels[y * scr.w + x] != 15:
				bad += 1
	t.ok("%s: US_CenterWindow(20, 5) is %d,%d %dx%d and clears to white (%d pixels not)" % [game, wx, wy, ww, wh, bad],
		wx == 80 and wy == 80 and ww == 160 and wh == 40 and bad == 0)
	# the frame: tile 0 at the top-left corner, 1 along the top, 8 at the bottom right
	var t8m: Dictionary = {}
	var frame_bad: int = 0
	for spec: Array in [[wx - 8, wy - 8, 0], [wx + 8, wy - 8, 1], [wx + ww, wy - 8, 2], [wx - 8, wy + 8, 3],
			[wx + ww, wy + 8, 5], [wx - 8, wy + wh, 6], [wx + 8, wy + wh, 7], [wx + ww, wy + wh, 8]]:
		# draw the same masked tile on a spare patch of known background and compare
		g.VL_ScreenRect(0, 200, 8, 8, 3)
		g.VHB_DrawTile8M(0, 200, spec[2])
		for y: int in range(8):
			for x: int in range(8):
				if scr.pixels[(spec[1] + y) * scr.w + spec[0] + x] != scr.pixels[(200 + y) * scr.w + x]:
					frame_bad += 1
	t.ok("%s: the window's frame is the eight border tiles (%d pixels differ)" % [game, frame_bad], frame_bad == 0)

	# ---- centred lines
	# the font XORs its colour in: 15 on the white window prints black, as the games do
	g.US_SetPrintColour(15)
	var y_before: int = g.US_GetPrintY()
	g.US_CPrint("Commander Keen\nis here")
	var fh: int = g.VH_MeasurePropString("A", 0)[1]
	var l1: Vector2i = inked(scr, wx, wx + ww, wy, wy + fh, 15)
	var l2: Vector2i = inked(scr, wx, wx + ww, wy + fh, wy + 2 * fh, 15)
	var mid2: int = (wx * 2 + ww)
	t.ok("%s: US_CPrint centres each line (ink %s and %s about %d) and moves the print line down two lines (%d -> %d)" %
		[game, l1, l2, mid2 / 2, y_before, g.US_GetPrintY()],
		absi(l1.x + l1.y + 1 - mid2) <= 3 and absi(l2.x + l2.y + 1 - mid2) <= 3 and g.US_GetPrintY() == y_before + 2 * fh and l1.x < l2.x)
	# US_Print carries the pen
	g.US_ClearWindow()
	g.US_Print("Ab")
	var after_ab: int = g.US_GetPrintX()
	g.US_Print("c\nd")
	t.ok("%s: US_Print moves the pen by the string's width (%d) and a newline returns it to the window's left a line down" %
		[game, after_ab - wx],
		after_ab == wx + g.VH_MeasurePropString("Ab", 0)[0] and g.US_GetPrintX() == wx + g.VH_MeasurePropString("d", 0)[0] and g.US_GetPrintY() == wy + fh)

	# ---- the random table
	g.US_InitRndT(false)
	var seq: Array = []
	for i: int in range(300):
		seq.append(g.US_RndT())
	var want: Array = []
	for i: int in range(300):
		want.append(GalUS.us_RandomTable[(i + 1) & 0xFF])
	g.US_SetRndI(254)
	var wrap: Array = [g.US_RndT(), g.US_RndT(), g.US_GetRndI()]
	t.ok("%s: US_RndT walks the table from the index and wraps (%s)" % [game, wrap], seq == want and wrap == [249, 0, 0])

	# ---- line input through the keyboard
	var at: float = vm.seconds() + 0.1
	var typed: Array = [GalIO.IN_SC_K, GalIO.IN_SC_E, GalIO.IN_SC_E, GalIO.IN_SC_X, GalIO.IN_SC_Backspace, GalIO.IN_SC_N, GalIO.IN_SC_Enter]
	for i: int in range(typed.size()):
		vm.add_key(at + 0.15 * i, typed[i], 0.05)
	g.US_ClearWindow()
	var r: Array = g.US_LineInput(wx, wy, "", true, 32, 150)
	t.ok("%s: US_LineInput returns what was typed, a backspace removing a letter (%s)" % [game, r], r == [true, "keen"])
	vm.add_key(vm.seconds() + 0.1, GalIO.IN_SC_A, 0.05)
	vm.add_key(vm.seconds() + 0.3, GalIO.IN_SC_Escape, 0.05)
	r = g.US_LineInput(wx, wy, "Billy", true, 32, 150)
	t.ok("%s: Escape leaves the default (%s)" % [game, r], r == [false, "Billy"])

	# ---- the config file
	g.us_configFile = PackedByteArray()
	g.US_LoadConfig()
	# no file: SD_Default(false, ...) chooses AdLib sound and music
	t.ok("%s: with no config the sound and music are AdLib and the score box on" % game,
		g.SD_GetSoundMode() == GalIO.sdm_AdLib and g.SD_GetMusicMode() == GalIO.smm_AdLib and g.ck_scoreBoxEnabled and g.in_gamepadButtons[2] == -1)
	(g.ck_highScores[0] as GalUS.CK_HighScore).name = "Commander Keen"
	(g.ck_highScores[0] as GalUS.CK_HighScore).score = 123456
	(g.ck_highScores[0] as GalUS.CK_HighScore).arg4 = 7
	g.in_kbdControls["jump"] = GalIO.IN_SC_Z
	g.in_kbdControls["fire"] = GalIO.IN_SC_X
	g.ck_twoButtonFiring = true
	g.SD_SetSoundMode(GalIO.sdm_PC)
	g.SD_SetMusicMode(GalIO.smm_Off)
	g.US_SaveConfig()
	var saved: PackedByteArray = g.us_configFile.duplicate()
	(g.ck_highScores[0] as GalUS.CK_HighScore).name = ""
	(g.ck_highScores[0] as GalUS.CK_HighScore).score = 0
	g.in_kbdControls["jump"] = GalIO.IN_SC_Control
	g.in_kbdControls["fire"] = GalIO.IN_SC_Space
	g.ck_twoButtonFiring = false
	g.SD_SetSoundMode(GalIO.sdm_AdLib)
	g.SD_SetMusicMode(GalIO.smm_AdLib)
	g.US_LoadConfig()
	var hs: GalUS.CK_HighScore = g.ck_highScores[0]
	t.ok("%s: CONFIG.%s (%d bytes) reads back the high score (%s %d %d), keys, two-button firing, PC sound and no music" %
		[game, d.ext, saved.size(), hs.name, hs.score, hs.arg4],
		saved.size() == 6 + 8 * 64 + 6 + 10 + 12 + 1 + 2 + 8 and hs.name == "Commander Keen" and hs.score == 123456 and hs.arg4 == 7 and
		g.in_kbdControls.jump == GalIO.IN_SC_Z and g.in_kbdControls.fire == GalIO.IN_SC_X and g.ck_twoButtonFiring and
		g.SD_GetSoundMode() == GalIO.sdm_PC and g.SD_GetMusicMode() == GalIO.smm_Off)
	var other: PackedByteArray = saved.duplicate()
	other[2] = 0x39    # "CK9": another episode's file is ignored
	g.us_configFile = other
	g.US_LoadConfig()
	t.ok("%s: a config from another episode is ignored (defaults)" % game, g.SD_GetSoundMode() == GalIO.sdm_AdLib and g.in_kbdControls.jump == GalIO.IN_SC_Z)
	g.SD_SetMusicMode(GalIO.smm_Off)

	# ---- saved games
	g.US_Setup()
	var names: Array = []
	for s: GalUS.US_Savefile in g.us_savefiles:
		names.append(s.name if not s.used else "used")
	t.ok("%s: no saved games reads as six empty slots (%s)" % [game, names], names == ["Empty", "Empty", "Empty", "Empty", "Empty", "Empty"])

	t.ok("%s: no quit (%s)" % [game, g.quit_message], not g.quitting)
	g.SD_Shutdown()
	g.RF_Shutdown()
	vm.int9 = Callable()
