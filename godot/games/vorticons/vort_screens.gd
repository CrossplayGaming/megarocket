# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEENSCRN.C from K1n9_Duk3's Reconstructed Commander Keen 1-3
# Source Code (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortScreens
extends VortMain
## The Vorticons engine's screens: previews, about id, the title, the high
## scores, save and restore, story and help text in a scrolling window, the
## Apogee intro, the ordering screen, the world-map Keen, and the text viewer.

# text window state (KEENDEMO.C globals used here)
var textLineOffsets: Array = []      # [[off, len], ...]
var textdataPtr: PackedByteArray = PackedByteArray()
var textWindowX: int = 0
var textWindowMinY: int = 0
var textVisibleLines: int = 0
var textWindowMaxY: int = 0
var line_offsets: Array = []
var apogeeY: int = 0                  # re-uses textWindowX in the original

# text files, prepared
var helptextPtr: PackedByteArray = PackedByteArray()
var storytxtPtr: PackedByteArray = PackedByteArray()
var endtextPtr: PackedByteArray = PackedByteArray()
var previewsPtr: PackedByteArray = PackedByteArray()

var highscores: HighScores = HighScores.new()
var restoredGame: bool = false
var canSave: bool = false
var forcemenu: bool = false
var worldkeenx: int = 0
var worldkeeny: int = 0
var worldCamX: int = 0
var worldCamY: int = 0
var oldx: int = 0
var oldy: int = 0
var warpspots: Array = [[28 * TILEGLOBAL, 6 * TILEGLOBAL, 1], [36 * TILEGLOBAL, 5 * TILEGLOBAL, 1], [62 * TILEGLOBAL, 37 * TILEGLOBAL, 0]]

var mapkeen: Obj = Obj.new()

const APOGEE_END_Y: int = 55
const APOGEE_START_DELAY: int = 30


func _init() -> void:
	super()
	line_offsets.resize(MAXTEXTLINES + 1)
	for i: int in range(line_offsets.size()):
		line_offsets[i] = [0, 0]


# ---------------------------------------------------------- previews, id

func Previews() -> void:
	if episode == 1:
		DrawPicFile("PREVIEW2.CK1")
		FadeIn()
		WaitVBL(300)
		FadeOut()
		DrawPicFile("PREVIEW3.CK1")
		FadeIn()
		ReadLevel(TITLEMAP)    # reload menu backgrounds (DrawPicFile trashes the level data!)
		WaitVBL(300)
		ShowText(previewsPtr, 0, 22)
	else:
		DrawTextScreen(previewsPtr, 0, 22)
		FadeIn()
		ShowText(previewsPtr, 0, 22)
		originx = X_HIGH


func ShowAboutId() -> void:
	originx = X_ID
	originy = Y_ID
	RF_ForceRefresh()
	RF_Clear()
	DrawIdScreen()
	FadeIn()
	ClearKeys()
	while true:
		RF_Clear()
		RF_Refresh()
		if DoFkeys():
			DrawIdScreen()
		var ctrl: Dictionary = ControlPlayer(1)
		if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0 or exited:
			break


func DrawTitlePics() -> void:
	DrawPic(8, 1, P.TITLEPIC)
	if episode == 3:
		DrawPic(19, 182, P.F1HELPPIC)
	else:
		DrawPic(16, 182, P.F1HELPPIC)


func DrawTitleScreen() -> void:
	uservect = &"DrawTitlePics"
	RF_Clear()
	RF_Refresh()
	RF_Refresh()
	uservect = &""
	ClearKeys()


func DrawAboutId() -> void:
	var lines: Array = [
		"We are a group of Software Artists\n",
		"whose goal is to bring commercial\n",
		"quality software to the public\n",
		"at shareware prices.\n\n",
		"Our effort is only possible with\n",
		"your support. Without it, we cannot\n",
		"continue to make this fine\n",
		"software so affordable.\n\n",
		"Thank you in advance for your\n",
		"contribution to the future of the\n",
		"growing shareware market.",
	]
	DrawPic(17, 23, P.IDLOGOPIC)
	leftedge = 7
	sx = 7
	sy = 9
	for i: int in range(11):
		PrintGrey(lines[i])


func DrawIdScreen() -> void:
	uservect = &"DrawAboutId"
	RF_ForceRefresh()
	RF_Clear()
	RF_Refresh()
	RF_Refresh()
	cost("drawidscreen")    # two pages of text and the logo drawn character by character
	uservect = &""
	ClearKeys()


# ------------------------------------------------------------- high scores

func DrawHighscores() -> void:
	var X: int = 5 if episode == 3 else 0
	DrawPic(15, 7, P.HIGHSCORPIC)
	DrawPic(9 + X, 44, P.NAMEPIC)
	DrawPic(23 + X, 44, P.SCOREPIC)
	if episode == 1:
		DrawPic(33, 44, P.PARTSPIC)
	elif episode == 2:
		DrawPic(33, 40, P.SAVEDPIC)
	for i: int in range(HIGHSCORE_NUMENTRIES):
		var tx: int = originx / TILEGLOBAL
		var ty: int = originy / TILEGLOBAL
		var anim: int = i % 4
		sy = i * 2 + 8
		if episode == 1:
			if highscores.gotJoystick[i] != 0:
				SETTILE(tx + 14, sy / 2 + ty, 0, anim + 221)
			if highscores.gotBattery[i] != 0:
				SETTILE(tx + 15, sy / 2 + ty, 0, anim + 237)
			if highscores.gotVacuum[i] != 0:
				SETTILE(tx + 16, sy / 2 + ty, 0, anim + 241)
			if highscores.gotEverclear[i] != 0:
				SETTILE(tx + 17, sy / 2 + ty, 0, anim + 245)
		elif episode == 2:
			sx = 36
			PrintGrey(str(highscores.citiesSaved[i]))
		var scorestr: String = str(highscores.scores[i])
		sx = 29 + X - scorestr.length()
		PrintGrey(scorestr)
		sx = 9 + X
		PrintGrey(highscores.names[i])


func DrawScoreScreen() -> void:
	originx = X_HIGH
	originy = Y_HIGH
	RF_ForceRefresh()
	RF_Clear()
	uservect = &"DrawHighscores"
	RF_Refresh()
	RF_Refresh()
	uservect = &""


func ShowScoreScreen() -> void:
	DrawScoreScreen()
	FadeIn()
	ClearKeys()
	while true:
		RF_Clear()
		RF_Refresh()
		if DoFkeys():
			DrawScoreScreen()
		var ctrl: Dictionary = ControlPlayer(1)
		if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0 or exited:
			break


# ----------------------------------------------------------- save, restore

func _saved_path(c: int) -> String:
	return save_dir.path_join("SAVED%c.%s" % [c, data.ext])


func SaveMenu() -> void:
	var save: int = 0
	var c: int = 0
	if not canSave:
		ExpWin(22, 3)
		Print("You can SAVE the game\n")
		Print("ONLY on the World Map!\n")
		Print("    press a key:")
		ClearKeys()
		Ack()
		return
	while save == 0 and not exited:
		ExpWin(20, 3)
		Print("Which game position\n")
		Print("do you want to save?\n")
		Print("    1-9 or ESC:")
		while true:
			c = Get() & 0xFF
			if c == CHAR_ESCAPE or (c >= 49 and c <= 57) or exited:
				break
		if c == CHAR_ESCAPE or exited:
			return
		if FileAccess.file_exists(_saved_path(c)):
			ExpWin(20, 3)
			Print("That game position\n")
			Print("already exists!\n")
			Print("Overwrite it?:")
			while true:
				var k: int = _toupper(Get() & 0xFF)
				if k == CHAR_ESCAPE or exited:
					return
				if k == 89:
					save += 1
					break
				if k == 78:
					break
		else:
			save += 1
	gamestate.worldoriginx = worldCamX
	gamestate.worldoriginy = worldCamY
	gamestate.worldx = worldkeenx
	gamestate.worldy = worldkeeny
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f: FileAccess = FileAccess.open(_saved_path(c), FileAccess.WRITE)
	if f != null:
		f.store_buffer(gamestate.to_bytes())
		f.close()
	ExpWin(29, 3)
	Print("You can continue this game\n")
	Print("from the Main Menu next time\n")
	Print("you play. Press a key:")
	Get()


func RestoreMenu() -> bool:
	DrawChar(sx, sy * 8, 32)   # erase cursor from Main Menu
	while not exited:
		ExpWin(25, 2)
		oldx = sx
		oldy = sy
		Print("  Continue Which Game?\n")
		Print("       1-9 or ESC:")
		var c: int = 0
		while true:
			c = Get() & 0xFF
			if (c >= 49 and c <= 57) or c == CHAR_ESCAPE or exited:
				break
		if c == CHAR_ESCAPE or exited:
			return false
		var path: String = _saved_path(c)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		if bytes.is_empty():
			ExpWin(25, 2)
			Print("  That game hasn't\n")
			Print("  been saved yet!:")
			Get()
		elif bytes.size() == 88:
			gamestate.from_bytes(bytes)
			restoredGame = true
			return true
		else:
			ExpWin(25, 2)
			Print("That file is incompatible\n")
			Print("with this verion of CK:")
			Get()
	return false


# ----------------------------------------------------------- help, story

func ShowStoryText() -> void:
	FadeOut()
	originx = X_STORY
	originy = Y_STORY
	RF_ForceRefresh()
	RF_Refresh()
	FadeIn()
	ShowText(storytxtPtr, 0, 16)
	FadeOut()


func ShowHelpText() -> void:
	var x: int = originx
	var y: int = originy
	originx = TILE_ALIGN(originx)
	originy = TILE_ALIGN(originy)
	ShowText(helptextPtr, 1, 20)
	originx = x
	originy = y


func DrawTextEx(useGrey: bool, x: int, y: int, text: String) -> void:
	var oldsx: int = sx
	var oldsy: int = sy
	sx = x
	sy = y
	if useGrey:
		PrintGrey(text)
	else:
		Print(text)
	sx = oldsx
	sy = oldsy


func DrawTextWindow() -> void:
	DrawWindow(4, textWindowMinY, 43, textWindowMaxY)
	DrawChar(4, (textWindowMaxY + 1) * 8, 4)
	DrawChar(43, (textWindowMaxY + 1) * 8, 4)
	DrawChar(4, (textWindowMaxY + 2) * 8, 1)
	DrawChar(43, (textWindowMaxY + 2) * 8, 3)
	for x: int in range(5, 43):
		DrawChar(x, (textWindowMaxY + 2) * 8, 2)
	DrawTextEx(true, 5, textWindowMaxY + 1, "       ESC to Exit / \u000f \u0013 to Read      ")
	DrawTextLines(textWindowX, textWindowMinY + 1, textdataPtr, 0, textVisibleLines)


func DrawTextScreen(textPtr: PackedByteArray, minY: int, maxY: int) -> void:
	var height: int = maxY - minY - 1
	GetLineOffsets(textPtr, 38, MAXTEXTLINES)
	textWindowX = 5
	textWindowMinY = minY
	textdataPtr = textPtr
	textVisibleLines = height
	textWindowMaxY = maxY
	uservect = &"DrawTextWindow"
	RF_Refresh()
	RF_Refresh()
	uservect = &""


func ShowText(textPtr: PackedByteArray, minY: int, maxY: int) -> void:
	var height: int = maxY - minY - 1
	var lines: int = GetLineOffsets(textPtr, 38, MAXTEXTLINES)
	textWindowX = 5
	textWindowMinY = minY
	textdataPtr = textPtr
	textVisibleLines = height
	textWindowMaxY = maxY
	uservect = &"DrawTextWindow"
	RF_Refresh()
	RF_Refresh()
	uservect = &""
	var line: int = 0
	WaitVBL(8)
	var ctrl: Dictionary
	while true:
		ctrl = ControlPlayer(1)
		if keydown[KEY_UP] != 0 or ctrl.dir == north:
			if line > 0:
				line -= 1
				ScrollTextWindow(minY + 1, maxY - 1, 1)
				DrawTextLines(5, minY + 1, textPtr, line, 1)
				WaitVBL(2)
		elif keydown[KEY_DOWN] != 0 or ctrl.dir == south:
			if lines - height >= line and 200 - height >= line:
				line += 1
				ScrollTextWindow(minY + 1, maxY - 1, 0)
				DrawTextLines(5, maxY - 1, textPtr, line + height - 1, 1)
				WaitVBL(2)
		if keydown[KEY_PGUP] != 0:
			if line - height + 1 > 0:
				line -= height - 1
			else:
				line = 0
			DrawTextLines(5, minY + 1, textPtr, line, height)
			while keydown[KEY_PGUP] != 0 and not exited:
				vm.poll()
		if keydown[KEY_PGDN] != 0:
			if line + height * 2 < lines:
				line += height - 1
			else:
				line = lines - height + 1
			DrawTextLines(5, minY + 1, textPtr, line, height)
			while keydown[KEY_PGDN] != 0 and not exited:
				vm.poll()
		if keydown[KEY_ESC] != 0 or ctrl.button1 or ctrl.button2 or exited:
			break
		vm.poll()
	while true:
		ctrl = ControlPlayer(1)
		if not (ctrl.button1 or ctrl.button2) or exited:
			break
		vm.poll()
	ClearKeys()


# ---------------------------------------------------------- Apogee intro

func DrawApogeePic() -> void:
	DrawPic(16, apogeeY, P.APOGEEPIC)


func DrawIntroPics() -> void:
	DrawPic(22, apogeeY - 10, P.ANPIC)
	DrawPic(16, apogeeY, P.APOGEEPIC)
	DrawPic(18, apogeeY + 32, P.PRESENTPIC)
	DrawPic(21, 99, P.OFANPIC)
	DrawPic(19, 114, P.IDSOFTPIC)
	DrawPic(19, 159, P.PRODUCTPIC)


func ShowApogeeIntro() -> void:
	vm.mark("intro")
	originx = X_APOGEE
	originy = Y_APOGEE
	var towait: int = 300
	var y: int = 200
	var state: int = 0
	var n: int = 0
	RF_ForceRefresh()
	ClearKeys()
	forcemenu = false
	while towait > 0 and not exited:
		towait -= 1
		RF_Clear()
		apogeeY = y
		RF_Refresh()
		match state:
			0:
				n += 1
				if n > APOGEE_START_DELAY:
					n = 0
					state += 1
					uservect = &"DrawApogeePic"
			1:
				if y > APOGEE_END_Y:
					y -= 1
				else:
					state += 1
					uservect = &"DrawIntroPics"
		var ctrl: Dictionary = ControlPlayer(1)
		if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0:
			towait = 0
			forcemenu = true
	uservect = &""


# ------------------------------------------------------- ordering screen

func ShowOrderingScreen(timed: bool) -> void:
	if episode == 1:
		var SWAPDELAY: int = 500
		var frame: int = 0
		var sprites: Array = [S.YORPSTAND1SPR, S.GARGSTAND1SPR]
		var screenys: Array = [151 * PIXGLOBAL, 143 * PIXGLOBAL]
		var screenxs: Array = [144 * PIXGLOBAL, 141 * PIXGLOBAL]
		var n: int = 0
		var spr: int = 0
		var counter: int = 0
		DrawOrderingScreen()
		FadeIn()
		ClearKeys()
		var towait: int = SCREENTIME
		while true:
			var ctrl: Dictionary = ControlPlayer(1)
			RF_Clear()
			if counter % 6 == 0:
				frame = frame + Rnd(3) - 2
				if frame > 7 or frame < 0:
					frame = Rnd(7 * 7) / 7
			n += 1
			if n > SWAPDELAY:
				spr ^= 1
				n = 0
			RF_PlaceSprite(screenxs[spr] + originx, screenys[spr] + originy, sprites[spr] + frame)
			RF_Refresh()
			counter += 1
			if timed:
				towait = towait - tics
			if DoFkeys():
				ClearKeys()
				DrawOrderingScreen()
			if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0:
				towait = 0
			if towait <= 0 or exited:
				break
	else:
		_ordering_screen_other(timed)


func _ordering_screen_other(_timed: bool) -> void:
	pass


func DrawOrderingInfo() -> void:
	if episode == 1:
		leftedge = 12
		sx = 12
		sy = 4
		PrintGrey("Commander Keen: Invasion\n")
		PrintGrey("of the Vorticons consists\n")
		PrintGrey("   of three unique and\n")
		PrintGrey("  challenging episodes:\n")
		PrintGrey("1. Marooned on Mars   $15\n")
		PrintGrey("2. The Earth Explodes $15\n")
		PrintGrey("3. Keen Must Die!     $15\n")
		leftedge = 5
		sx = 5
		PrintGrey(" Order the trilogy for $30 and you get\n")
		sx -= 1
		leftedge = sx
		PrintGrey("  * The \"Secret Hints & Tricks\" sheet\n")
		PrintGrey("  * The special \"cheat mode\" password\n")
		PrintGrey("  * The latest version of each game\n")
		PrintGrey("  * SEVERAL FREE BONUS GAMES!\n\n")
		PrintGrey("                       Mail orders to:\n")
		PrintGrey("(U.S. funds only       Apogee Software\n")
		PrintGrey("checks or M/O's        P.O. Box 476389\n")
		PrintGrey("include $2 P&H)        Garland, TX 75047\n\n\n")
		PrintGrey("Specify 5.25/3.5 disk size when ordering\n")
		sx = 0
		PrintGrey("       Or order toll free: 1-800-852-5659    \n")
	else:
		_ordering_info_other()


func _ordering_info_other() -> void:
	pass


func DrawOrderingScreen() -> void:
	originx = X_ORDER
	originy = Y_ORDER
	ox = GLOBAL_TO_TILE(originx)
	oy = GLOBAL_TO_TILE(originy)
	if episode == 2:
		originy -= 4 * PIXGLOBAL
	RF_ForceRefresh()
	RF_Clear()
	uservect = &"DrawOrderingInfo"
	RF_Refresh()
	RF_Refresh()
	uservect = &""
	ClearKeys()


# --------------------------------------------------------------- mapkeen

func ClipMapKeen(ob: Obj) -> bool:
	if cheatmode:
		return false
	ob.xmove = s16(ob.xmove + ob.xspeed * tics)
	ob.ymove = s16(ob.ymove + ob.yspeed * tics)
	mapkeen.copy_from(ob)
	var result: bool = false
	mapkeen.bottom += mapkeen.ymove
	mapkeen.top += mapkeen.ymove
	var tileleft: int = mapkeen.left / TILEGLOBAL
	var tileright: int = mapkeen.right / TILEGLOBAL
	var tiletop: int
	var tilebottom: int
	var extra: int
	if mapkeen.ymove > 0:
		if mapkeen.bottom / TILEGLOBAL != (mapkeen.bottom - mapkeen.ymove) / TILEGLOBAL:
			tilebottom = mapkeen.bottom / TILEGLOBAL
			for x: int in range(tileleft, tileright + 1):
				if northwall[GETTILE(x, tilebottom, 0)] != 0 or (GETTILE(x, tilebottom, 1) & infoBlockMask) != 0:
					ob.yspeed = 0
					extra = (mapkeen.bottom + 1) % TILEGLOBAL
					ob.ymove -= extra
					mapkeen.top -= extra
					mapkeen.bottom -= extra
					result = true
					break
	elif mapkeen.ymove < 0:
		if mapkeen.top / TILEGLOBAL != (mapkeen.top - mapkeen.ymove) / TILEGLOBAL:
			tiletop = mapkeen.top / TILEGLOBAL
			for x: int in range(tileleft, tileright + 1):
				if southwall[GETTILE(x, tiletop, 0)] != 0 or (GETTILE(x, tiletop, 1) & infoBlockMask) != 0:
					ob.yspeed = 0
					extra = TILEGLOBAL - mapkeen.top % TILEGLOBAL
					ob.ymove += extra
					mapkeen.top += extra
					mapkeen.bottom += extra
					result = true
					break
	mapkeen.left += mapkeen.xmove
	mapkeen.right += mapkeen.xmove
	tiletop = mapkeen.top / TILEGLOBAL
	tilebottom = mapkeen.bottom / TILEGLOBAL
	if mapkeen.xmove > 0:
		if mapkeen.right / TILEGLOBAL != (mapkeen.right - mapkeen.xmove) / TILEGLOBAL:
			tileright = mapkeen.right / TILEGLOBAL
			for y: int in range(tiletop, tilebottom + 1):
				if westwall[GETTILE(tileright, y, 0)] != 0 or (GETTILE(tileright, y, 1) & infoBlockMask) != 0:
					ob.xspeed = 0
					extra = (mapkeen.right + 1) % TILEGLOBAL
					ob.xmove -= extra
					mapkeen.left -= extra
					mapkeen.right -= extra
					result = true
					break
	elif mapkeen.xmove < 0:
		if mapkeen.left / TILEGLOBAL != (mapkeen.left - mapkeen.xmove) / TILEGLOBAL:
			tileleft = mapkeen.left / TILEGLOBAL
			for y: int in range(tiletop, tilebottom + 1):
				if eastwall[GETTILE(tileleft, y, 0)] != 0 or (GETTILE(tileleft, y, 1) & infoBlockMask) != 0:
					ob.xspeed = 0
					extra = TILEGLOBAL - mapkeen.left % TILEGLOBAL
					ob.xmove += extra
					mapkeen.left += extra
					mapkeen.right += extra
					result = true
					break
	return result


var _spotX: int = 0
var _spotY: int = 0


func ControlMapKeen(ctrl: Dictionary, ob: Obj) -> void:
	if episode == 3 and messiestate != 0:
		return
	UpdateObjHitbox(ob)
	if ctrl.button1 or ctrl.button2:
		var tileleft: int = ob.left / TILEGLOBAL
		var tileright: int = ob.right / TILEGLOBAL
		var tiletop: int = ob.top / TILEGLOBAL
		var tilebottom: int = ob.bottom / TILEGLOBAL
		for x: int in range(tileleft, tileright + 1):
			for y: int in range(tiletop, tilebottom + 1):
				if GETTILE(x, y, 1) != 0:
					_spotX = x
					_spotY = y
					LevelNumber = GETTILE(x, y, 1)
					if LevelNumber == 255:
						LevelNumber = 0
	ob.xmove = 0
	ob.ymove = 0
	match ctrl.dir:
		northwest:
			ob.ymove = -4 * PIXGLOBAL
			ob.xmove = -4 * PIXGLOBAL
			ob.shapenum = S.MAPKEENU1SPR
		north:
			ob.ymove = -4 * PIXGLOBAL
			ob.shapenum = S.MAPKEENU1SPR
		northeast:
			ob.ymove = -4 * PIXGLOBAL
			ob.xmove = 4 * PIXGLOBAL
			ob.shapenum = S.MAPKEENU1SPR
		east:
			ob.xmove = 4 * PIXGLOBAL
			ob.shapenum = S.MAPKEENR1SPR
		southeast:
			ob.ymove = 4 * PIXGLOBAL
			ob.xmove = 4 * PIXGLOBAL
			ob.shapenum = S.MAPKEEND1SPR
		south:
			ob.ymove = 4 * PIXGLOBAL
			ob.shapenum = S.MAPKEEND1SPR
		southwest:
			ob.ymove = 4 * PIXGLOBAL
			ob.xmove = -4 * PIXGLOBAL
			ob.shapenum = S.MAPKEEND1SPR
		west:
			ob.xmove = -4 * PIXGLOBAL
			ob.shapenum = S.MAPKEENL1SPR
	var move: bool = false
	var anim: int
	if (ob.xmove | ob.ymove) != 0:
		anim = (u16(timecount) >> 4) & 3
		move = true
	else:
		anim = 0
	infoBlockMask = 0x8000
	if keydown[KEY_TAB] != 0 and keydown[KEY_LSHIFT] != 0:
		infoBlockMask = 0
	var blocked: bool = ClipMapKeen(ob)
	ob.x += ob.xmove
	ob.y += ob.ymove
	if move and ((u16(timecount) >> 3) & 3) == 0:
		if blocked:
			PlaySound(SND.WLDBLOCKSND)
		else:
			PlaySound(SND.WLDWALKSND)
	if ob.xmove > 0 and ob.x - originx > 11 * TILEGLOBAL:
		originx += ob.xmove
		if originx > originxmax:
			originx = originxmax
	elif ob.xmove < 0 and ob.x - originx < 9 * TILEGLOBAL:
		originx += ob.xmove
		if originx < originxmin:
			originx = originxmin
	if ob.ymove > 0 and ob.y - originy > 7 * TILEGLOBAL:
		originy += ob.ymove
		if originy > originymax:
			originy = originymax
	elif ob.ymove < 0 and ob.y - originy < 3 * TILEGLOBAL:
		originy += ob.ymove
		if originy < originymin:
			originy = originymin
	ox = GLOBAL_TO_TILE(originx)
	oy = GLOBAL_TO_TILE(originy)
	RF_PlaceSprite(ob.x, ob.y, ob.shapenum + anim)
	if episode == 3:
		_messie_touch(ob)
	if LevelNumber != 0:
		if CheckMapKeenTiles(LevelNumber, ob, _spotX, _spotY):
			LevelNumber = 0


## Keen 3's Messie; the episode class supplies it.
var messiestate: int = 0


func _messie_touch(_ob: Obj) -> void:
	pass


func CheckMapKeenTiles(num: int, ob: Obj, spotX: int, spotY: int) -> bool:
	if episode == 1:
		var anim: int = 0
		if num == 20:
			ExpWin(20, 8)
			Print("Your ship is missing\nthese parts:\n\n\n\n\n")
			Print("    GO GET THEM!\n")
			Print("   press a ")
			if playermode[1] == keyboard:
				Print("key:")
			else:
				Print("button:")
			if not gamestate.gotJoystick:
				DrawTile(leftedge + 3, (sy - 4) * 8, 321)
			if not gamestate.gotBattery:
				DrawTile(leftedge + 7, (sy - 4) * 8, 322)
			if not gamestate.gotVacuum:
				DrawTile(leftedge + 11, (sy - 4) * 8, 323)
			if not gamestate.gotEverclear:
				DrawTile(leftedge + 15, (sy - 4) * 8, 324)
			WaitVBL(15)
			Ack()
			RF_ForceRefresh()
			return true
		if (num & 0x20) == 0x20:
			var t1: int = (num & 3) - 1
			var t2: int = ((num >> 2) & 3) - 1
			var x: int = spotX
			var y: int = spotY
			var basetile: int = 338
			if warpspots[t2][2] != 0:
				basetile = 342
			PlaySound(SND.TELEPORTSND)
			for i: int in range(16):
				RF_Clear()
				RF_ForceRefresh()
				if i % 2 == 0:
					anim += 1
					if anim > 3:
						anim = 0
				SETTILE(x, y, 0, anim + basetile)
				RF_Refresh()
			basetile = 325
			if warpspots[t2][2] != 0:
				basetile = 99
			SETTILE(x, y, 0, basetile)
			ob.x = warpspots[t1][0]
			oldx = ob.x
			worldkeenx = ob.x
			ob.y = warpspots[t1][1]
			oldy = ob.y
			worldkeeny = ob.y
			originx = ob.x - 9 * TILEGLOBAL
			originy = ob.y - 3 * TILEGLOBAL
			x = ob.x / TILEGLOBAL
			y = ob.y / TILEGLOBAL
			basetile = 338
			if warpspots[t1][2] != 0:
				basetile = 342
			for i: int in range(16):
				RF_Clear()
				RF_ForceRefresh()
				if i % 2 == 0:
					anim += 1
					if anim > 3:
						anim = 0
				SETTILE(x, y, 0, anim + basetile)
				RF_Refresh()
			basetile = 325
			if warpspots[t1][2] != 0:
				basetile = 99
			SETTILE(x, y, 0, basetile)
			while true:
				RF_Clear()
				var ctrl: Dictionary = ControlPlayer(1)
				RF_PlaceSprite(ob.x, ob.y, ob.shapenum)
				RF_Refresh()
				HandleUserKeys()
				DoFkeys()
				if not (ctrl.button1 or ctrl.button2) or exited:
					break
			return true
		return false
	return _check_map_tiles_other(num, ob, spotX, spotY)


func _check_map_tiles_other(_num: int, _ob: Obj, _spotX: int, _spotY: int) -> bool:
	return false


## Waits for a key or button, animating the cursor.
func Ack() -> void:
	var anim: int = 0
	var done: bool = false
	while not done and not exited:
		DrawChar(sx, sy * 8, anim + 9)
		for i: int in range(6):
			WaitVBL(1)
			var c: Dictionary = ControlPlayer(1)
			if c.button1 or c.button2 or NoBiosKey(1) != 0 or exited:
				done = true
				break
		anim += 1
		if anim > 4:
			anim = 0
	while not exited:
		var c: Dictionary = ControlPlayer(1)
		if not (c.button1 or c.button2):
			break
		vm.poll()
	ClearKeys()


# ----------------------------------------------------------- text viewer

func DrawTextLines(x: int, y: int, textPtr: PackedByteArray, first: int, numlines: int) -> void:
	sx = x
	sy = y
	for line: int in range(numlines):
		var off: int = line_offsets[first + line][0]
		if off == 0xFFFF:
			return
		var len: int = line_offsets[first + line][1]
		if len > 0 and textPtr[off + len - 1] == 13:
			len -= 1
		var fontoff: int = 0
		if textPtr[off] == 126:   # '~'
			fontoff = 0x80
			off += 1
			len -= 1
		for i: int in range(len):
			DrawChar(sx, sy * 8, (textPtr[off + i] + fontoff) & 0xFF)
			sx += 1
		if sx < 43:
			CharBar(sx, sy, 42, sy, fontoff + 32)
		sy += 1
		sx = x


## Removes the line breaks the original removes (CR LF pairs become a space
## unless a blank line follows; CTRL-_ forces one), up to the CTRL-Z.
func PrepareText(textPtr: PackedByteArray) -> PackedByteArray:
	if textPtr.is_empty():
		Quit("Missing a text file!")
		return textPtr
	var text: PackedByteArray = textPtr.duplicate()
	var len: int = 0
	while len < text.size() and text[len] != 0x1A:
		len += 1
	var i: int = 0
	while i < text.size() and text[i] != 0x1A:
		var c: int = text[i]
		if c == 0x1F:
			text[i] = 13
		elif c == 13 and (i + 2 >= text.size() or text[i + 2] != 13):
			text[i] = 32
			# movedata(text+i+2 -> text+i+1, len-i)
			var tail: PackedByteArray = text.slice(i + 2, i + 2 + (len - i))
			for k: int in range(tail.size()):
				if i + 1 + k < text.size():
					text[i + 1 + k] = tail[k]
			len -= 1
		elif c == 13 and text[i + 2] == 13:
			while i < text.size() and text[i] == 13:
				i += 2
			i -= 1
		i += 1
	return text


func GetLineOffsets(textPtr: PackedByteArray, width: int, maxlines: int) -> int:
	var linestart: int = 0
	var state: int = 0
	var line: int = 0
	var off: int = 0
	while true:
		state = 0
		line_offsets[line][0] = linestart
		off = linestart
		while off < linestart + width:
			var c: int = textPtr[off] if off < textPtr.size() else 0x1A
			if c == 0x1A:
				state = 2
				line_offsets[line][1] = off - linestart
				line_offsets[line + 1][0] = 0xFFFF
				line_offsets[line + 1][1] = 0xFFFF
				break
			elif c == 13:
				line_offsets[line][1] = off - linestart + 1
				line += 1
				linestart = off + 2
				state += 1
				break
			off += 1
		if state == 0:
			while off > linestart:
				if textPtr[off] == 32:
					line_offsets[line][1] = off - linestart
					line += 1
					linestart = off + 1
					break
				off -= 1
			if off == linestart:
				line_offsets[line][1] = width
				line += 1
				off += width
				linestart += width
		if line == maxlines:
			line_offsets[line - 1][0] = 0xFFFF
			line_offsets[line - 1][1] = 0xFFFF
			state = 2
		if state >= 2:
			break
	return line


## Scrolls the whole width of the video buffer by one character row through
## the latches: dir 0 moves the picture down, dir 1 moves it up.
func ScrollTextWindow(minY: int, maxY: int, dir: int) -> void:
	var blocksize: int = ((maxY - minY) * 8) * SCREENWIDTH
	var base: int = seg_addr(screenseg, 0)
	vm.out8(GC_INDEX, GC_MODE)
	vm.out8(GC_INDEX + 1, 1)
	vm.out8(SC_INDEX, SC_MAPMASK)
	vm.out8(SC_INDEX + 1, 15)
	if dir == 0:
		var di: int = minY * SCREENWIDTH * 8
		var si: int = di + SCREENWIDTH * 8
		for k: int in range(blocksize):
			_latch((base + si + k) & 0xFFFF, (base + di + k) & 0xFFFF)
	else:
		var di: int = maxY * SCREENWIDTH * 8 + SCREENWIDTH * 8 - 1
		var si: int = di - SCREENWIDTH * 8
		for k: int in range(blocksize):
			_latch((base + si - k) & 0xFFFF, (base + di - k) & 0xFFFF)


## KEENACTS.C's; the actor module supplies it.
func UpdateObjHitbox(ob: Obj) -> void:
	var spr: int = ob.shapenum * 4 + (ob.x >> (G_P_SHIFT + 1)) % 4
	image = spritetable[spr]
	ob.left = ob.x + image.xl
	ob.right = ob.x + image.xh
	ob.top = ob.y + image.yl
	ob.bottom = ob.y + image.yh
