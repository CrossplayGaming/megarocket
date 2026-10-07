# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEENDEMO.C from K1n9_Duk3's Reconstructed Commander Keen 1-3
# Source Code (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortDemo
extends VortScreens
## The Vorticons engine's demo loop: the title cycle and main menu, the
## world map, the finale, the high-score entry and the "Keens left" window.

var showIntro: bool = true
var entrances: Array = []            # NUMLEVELS of [x, y, type]

# the main menu
const mm_NewGame: int = 0
const mm_ContinueGame: int = 1
const mm_Story: int = 2
const mm_AboutID: int = 3
const mm_HighScores: int = 4
const mm_OrderingInfo: int = 5
const mm_Previews: int = 6
const mm_RestartDemo: int = 7
const NUMMENUITEMS: int = 8
const MAXMENUPOS: int = NUMMENUITEMS - 1


func _init() -> void:
	super()
	for i: int in range(NUMLEVELS):
		entrances.append([0, 0, 0])


func _scores_path() -> String:
	return save_dir.path_join("SCORES." + data.ext)


func DemoLoop() -> void:
	var names: Array = ["Yorpy", "Gargile", "Zzapp!"]
	helptextPtr = PrepareText(data.help_text)
	storytxtPtr = PrepareText(data.story_text)
	endtextPtr = PrepareText(data.end_text)
	previewsPtr = PrepareText(data.previews_text)
	canSave = false
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_scores_path()) if save_dir != "" and FileAccess.file_exists(_scores_path()) else PackedByteArray()
	if bytes.is_empty():
		for i: int in range(7):
			highscores.scores[i] = 100
			highscores._unused[i] = 0
			highscores.citiesSaved[i] = 0
			highscores.names[i] = names[i % 3]
			highscores.gotJoystick[i] = 0
			highscores.gotBattery[i] = 0
			highscores.gotVacuum[i] = 0
			highscores.gotEverclear[i] = 0
		_save_scores()
	else:
		highscores.from_bytes(bytes)
	cost("demoloop_load")    # the four text files, PrepareText and the score file
	FadeOut()   # fade out the "one moment" pic
	while not exited:
		MenuLoop()
		if exited:
			break
		WorldMap()


func _save_scores() -> void:
	if save_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f: FileAccess = FileAccess.open(_scores_path(), FileAccess.WRITE)
	if f != null:
		f.store_buffer(highscores.to_bytes())
		f.close()


# -------------------------------------------------------------- world map

func WorldMap() -> void:
	var exitcode: int = ex_nothing
	ClearKeys()
	RF_ForceRefresh()
	ReadLevel(WORLDMAP)
	cost("worldmap_load")    # fitting hook: time DOSBox spends entering the map not yet modelled
	if episode == 3:
		_spawn_messie()
	if not restoredGame:
		var pos: PackedInt32Array = GetPlayerPosition()
		gamestate.worldx = pos[0]
		gamestate.worldy = pos[1]
		gamestate.worldoriginx = gamestate.worldx - 9 * TILEGLOBAL
		gamestate.worldoriginy = gamestate.worldy - 3 * TILEGLOBAL
		gamestate.score = 0
	worldCamX = gamestate.worldoriginx
	worldCamY = gamestate.worldoriginy
	worldkeenx = gamestate.worldx
	worldkeeny = gamestate.worldy
	infoBlockMask = 0x8000
	lastextra = (gamestate.score / EXTRASCORE) * EXTRASCORE
	resetgame = false
	EGApage = 0
	cyclespeed = 3
	while true:
		var ob: Obj = objlist[0]
		ob.xmove = 0
		ob.ymove = 0
		ob.xspeed = 0
		ob.yspeed = 0
		ob.shapenum = S.MAPKEEND1SPR
		LevelNumber = 0
		ReadLevel(WORLDMAP)
		ScanWorldMap()
		for i: int in range(NUMLEVELS):
			var x: int = entrances[i][0]
			var y: int = entrances[i][1]
			if gamestate.leveldone[i]:
				match entrances[i][2]:
					0:
						SETTILE(x, y, 1, 0)
						SETTILE(x, y, 0, 56 if episode == 3 else 77)
					1:
						SETTILE(x, y, 1, 0)
						SETTILE(x + 1, y, 1, 0)
						SETTILE(x, y + 1, 1, 0)
						SETTILE(x + 1, y + 1, 1, 0)
						if episode != 3:
							SETTILE(x, y, 0, 78)
							SETTILE(x + 1, y, 0, 79)
							SETTILE(x, y + 1, 0, 80)
							SETTILE(x + 1, y + 1, 0, 81)
						else:
							SETTILE(x, y, 0, 52)
							SETTILE(x + 1, y, 0, 53)
							SETTILE(x, y + 1, 0, 54)
							SETTILE(x + 1, y + 1, 0, 55)
		ob.x = worldkeenx
		ob.y = worldkeeny
		originx = worldCamX
		originy = worldCamY
		RF_Clear()
		RF_Refresh()
		RF_Refresh()
		if exitcode == ex_nothing:
			ShowLives()
		if exitcode < ex_warped:
			FadeIn()
		if exitcode == ex_nothing:
			ClearKeys()
			var ctrl: Dictionary
			for i: int in range(60):
				WaitVBL(1)
				ctrl = ControlPlayer(1)
				if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0 or exited:
					break
			while not exited:
				ctrl = ControlPlayer(1)
				if not (ctrl.button1 or ctrl.button2):
					break
				vm.poll()
		ClearKeys()
		RF_ForceRefresh()
		canSave = true
		var anim: int = 0
		while true:
			RF_Clear()
			if episode == 3:
				_update_messie(ob)
			ControlMapKeen(ControlPlayer(1), ob)
			if episode == 3:
				_place_messie(anim)
			RF_Refresh()
			HandleUserKeys()
			worldkeenx = ob.x
			worldkeeny = ob.y
			worldCamX = originx
			worldCamY = originy
			DoFkeys()
			if keydown[KEY_SPACE] != 0:
				ShowStatusScreen()
			if resetgame or exited:
				if not exited:
					CheckHighScore()
				return
			anim += 1
			if LevelNumber != 0:
				break
		canSave = false
		var idx: int = (LevelNumber & 0xFF) - 1    # the original's 16-bit index drops the blocking bit
		if idx >= 0 and idx < NUMLEVELS and not gamestate.leveldone[idx]:
			PlaySound(SND.WLDENTERSND)
			exitcode = LevelLoop(LevelNumber & 0xFF)
			if resetgame or exited:
				resetgame = false
				if not exited:
					CheckHighScore()
				return
			elif exitcode != ex_nothing:
				match exitcode:
					ex_completed:
						gamestate.leveldone[idx] = true
					ex_warped:
						if episode == 1:
							WarpToSecretLevel()
					ex_tantalus:
						if episode == 2:
							FadeOut()
							TheEarthExplodes()
							CheckHighScore()
							return
				if _episode_finished():
					DoFinale()
					CheckHighScore()
					return
			else:
				gamestate.lives -= 1
		if gamestate.lives <= -1:
			break
	WaitEndSound()
	if episode == 2:
		TheEarthExplodes()
	else:
		FadeIn()
	CheckHighScore()


func _episode_finished() -> bool:
	match episode:
		1:
			return gamestate.gotJoystick and gamestate.gotBattery and gamestate.gotVacuum and gamestate.gotEverclear
		2:
			var saved: int = 0
			for i: int in range(NUMCITIES):
				saved += gamestate.citySaved[i]
			return saved == NUMCITIES
		3:
			return (LevelNumber & 0xFF) == 16
	return false


## Keen 3's Messie and Keen 2's ending; the episode classes supply them.
func _spawn_messie() -> void:
	pass


func _update_messie(_keen: Obj) -> void:
	pass


func _place_messie(_anim: int) -> void:
	pass


func TheEarthExplodes() -> void:
	pass


func ScanWorldMap() -> void:
	for i: int in range(NUMLEVELS):
		entrances[i][0] = 0
	if episode == 3:
		_clear_warps()
	for y: int in range(mapheight):
		var x: int = 0
		while x < mapwwide:
			var infoval: int = GETTILE(x, y, 1) & 0x7FFF
			if episode == 3 and (infoval & 0xF00) == 0xF00:
				_note_warp(infoval, x, y)
			if infoval > 0 and infoval < 0x100 and infoval <= NUMLEVELS and entrances[infoval - 1][0] == 0:
				entrances[infoval - 1][0] = x
				entrances[infoval - 1][1] = y
				entrances[infoval - 1][2] = 0
				if (GETTILE(x + 1, y, 1) & 0x7FFF) == infoval:
					x += 1
					entrances[infoval - 1][2] = 1
			x += 1


func _clear_warps() -> void:
	pass


func _note_warp(_infoval: int, _x: int, _y: int) -> void:
	pass


# ----------------------------------------------------------------- finale

func EraseWindow() -> void:
	CharBar(win_xl, win_yl, win_xh, win_yh, 0)


func TypeText(text: String) -> void:
	for i: int in range(text.length()):
		Print(text[i])
		WaitVBL(6)


func DoFinale() -> void:
	if episode != 1:
		_finale_other()
		return
	var shipspeeds1: Array = [[0, -3], [0, -3], [0, -3], [0, -3], [0, -3], [0, -3], [0, -3], [0, -3], [0, -3], [0, -3],
		[3, -3], [3, -2], [3, -1], [3, 0], [0, 0]]
	var shipspeeds2: Array = [[-3, -3], [-3, -3], [-3, -3], [-3, -3], [-3, -3], [-3, -3], [-3, -3], [-3, -3],
		[-3, -2], [-3, -2], [-3, -2], [-3, -2], [-3, -2], [-3, -2], [-3, -2], [-3, -2],
		[-3, -1], [-3, -1], [-3, -1], [-3, -1], [-3, -1], [-3, -1], [-3, -1], [-3, -1],
		[-3, 0], [-3, 0], [-3, 0], [-3, 0], [-3, 0], [-3, 0], [-3, 0], [-3, 1], [-3, 1], [-3, 2], [-3, 2],
		[-4, 2], [-4, 2], [-4, 2], [-4, 2], [-4, 3], [-3, 3], [-2, 3], [0, 0]]
	var shipspeeds3: Array = [[3, -1], [3, -1], [3, -2], [3, -2], [3, -2], [3, -2], [3, -2], [3, -2],
		[3, 0], [3, 0], [3, 0], [3, 0], [3, 0], [3, 0], [3, 0], [3, 1], [3, 1], [3, 1], [3, 1], [3, 1], [3, 1], [3, 1], [3, 1],
		[3, 2], [3, 2], [3, 2], [3, 2], [3, 2], [3, 2], [3, 2], [3, 2], [2, 2], [1, 2], [1, 2], [1, 2], [1, 2], [1, 2], [1, 2], [1, 2], [0, 0]]
	ClearKeys()
	ReadLevel(WORLDMAP)
	originx = 3 * TILEGLOBAL
	originy = 35 * TILEGLOBAL
	RF_ForceRefresh()
	RF_Clear()
	RF_PlaceSprite(13 * TILEGLOBAL, 39 * TILEGLOBAL, S.MAPKEENL1SPR)
	RF_Refresh()
	WaitVBL(300)
	DrawWindow(5, 15, 42, 20)
	FadeIn()
	TypeText("Commander Keen returns to the Bean-\n")
	TypeText("with-Bacon Megarocket and quickly\n")
	TypeText("replaces the missing parts. He must\n")
	TypeText("get home before his parents do!\n")
	ReadLevel(ENDINGMAP)
	WaitVBL(240)
	FadeOut()
	originx = 0
	originy = 0
	RF_ForceRefresh()
	RF_Clear()
	RF_Refresh()
	RF_Refresh()
	FadeIn()
	var i: int = 0
	var shipx: int = 100 * PIXGLOBAL
	var shipy: int = 80 * PIXGLOBAL
	while true:
		shipx += shipspeeds1[i][0] * PIXGLOBAL
		shipy += shipspeeds1[i][1] * PIXGLOBAL
		RF_Clear()
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
		RF_Refresh()
		WaitVBL(4)
		var done: bool = shipspeeds1[i][0] + shipspeeds1[i][1] == 0
		i += 1
		if done or exited:
			break
	i = 0
	while true:
		shipx += 3 * PIXGLOBAL
		shipy += 1 * PIXGLOBAL
		RF_Clear()
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
		RF_Refresh()
		var done: bool = not (i < 20)
		i += 1
		if done or exited:
			break
	i = 0
	while true:
		originx += 3 * PIXGLOBAL
		originy += 1 * PIXGLOBAL
		shipx += 3 * PIXGLOBAL
		shipy += 1 * PIXGLOBAL
		RF_Clear()
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
		RF_Refresh()
		var done: bool = not (i < 200)
		i += 1
		if done or exited:
			break
	i = 0
	while true:
		shipy += 1 * PIXGLOBAL
		if i < 20:
			originy += 3 * PIXGLOBAL
		RF_Clear()
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
		RF_Refresh()
		var done: bool = not (i < 60)
		i += 1
		if done or exited:
			break
	WaitVBL(20)
	i = 0
	while true:
		RF_Clear()
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
		RF_PlaceSprite(shipx + 6 * PIXGLOBAL, shipy - 14 * PIXGLOBAL, S.MARKSPR)
		RF_Refresh()
		var done: bool = not (i < 30)
		i += 1
		if done or exited:
			break
	i = 0
	while true:
		RF_Clear()
		shipx -= 2 * PIXGLOBAL
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP2SPR)
		RF_Refresh()
		var done: bool = not (i < 50)
		i += 1
		if done or exited:
			break
	i = 0
	while true:
		RF_Clear()
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP2SPR)
		RF_PlaceSprite(shipx + 6 * PIXGLOBAL, shipy - 14 * PIXGLOBAL, S.POINTSPR)
		RF_Refresh()
		var done: bool = not (i < 30)
		i += 1
		if done or exited:
			break
	i = 0
	while true:
		RF_Clear()
		shipx += shipspeeds3[i][0] * PIXGLOBAL
		shipy += shipspeeds3[i][1] * PIXGLOBAL
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
		RF_Refresh()
		var done: bool = shipspeeds3[i][0] + shipspeeds3[i][1] == 0
		i += 1
		if done or exited:
			break
	WaitVBL(60)
	FadeOut()
	var savedx: int = originx
	var savedy: int = originy
	DrawPicFile("FINALE.CK1")
	DrawWindow(4, 15, 27, 19)
	FadeIn()
	TypeText("Keen makes it home and\n")
	TypeText("rushes to beat his\n")
	TypeText("parents upstairs.")
	WaitVBL(120)
	EraseWindow()
	WaitVBL(60)
	DrawPic(14, 0, P.WINDONPIC)
	PlaySound(SND.CLICKSND)
	WaitVBL(120)
	DrawPic(14, 0, P.WINDOFFPIC)
	PlaySound(SND.CLICKSND)
	WaitVBL(300)
	DrawWindow(4, 15, 27, 19)
	TypeText("Shhh, honey...let's\n")
	TypeText("see if little Billy\n")
	TypeText("is asleep.")
	WaitVBL(180)
	EraseWindow()
	WaitVBL(60)
	DrawPic(14, 0, P.WINDONPIC)
	PlaySound(SND.CLICKSND)
	DrawWindow(4, 15, 27, 20)
	TypeText("Billy...? Are you a--\n")
	Print("WHAT IS THIS ONE-EYED\n")
	Print("GREEN THING IN YOUR\n")
	Print("ROOM!!!!???\n")
	WaitVBL(240)
	EraseWindow()
	DrawWindow(4, 15, 27, 18)
	TypeText("Aw, Mom, can't I\n")
	TypeText("keep him?")
	WaitVBL(180)
	EraseWindow()
	DrawWindow(4, 15, 29, 19)
	TypeText("Well, we'll talk about\n")
	TypeText("that in the morning,\n")
	TypeText("son. You get some rest.")
	WaitVBL(180)
	EraseWindow()
	DrawWindow(4, 15, 27, 17)
	TypeText("OK, Mom. Goodnight.")
	WaitVBL(180)
	DrawWindow(4, 15, 27, 17)
	TypeText("Goodnight, dear.")
	WaitVBL(180)
	EraseWindow()
	WaitVBL(60)
	DrawPic(14, 0, P.WINDOFFPIC)
	PlaySound(SND.CLICKSND)
	WaitVBL(300)
	DrawPic(14, 0, P.WINDONPIC)
	DrawWindow(4, 15, 29, 21)
	PlaySound(SND.CLICKSND)
	TypeText("But there is no sleep\n")
	TypeText("for Commander Keen! The\n")
	TypeText("Vorticon Mothership\n")
	TypeText("looms above, ready to\n")
	TypeText("destroy Earth!")
	WaitVBL(300)
	FadeOut()
	ReadLevel(ENDINGMAP)
	originx = savedx
	originy = savedy
	RF_ForceRefresh()
	RF_Clear()
	RF_PlaceSprite(shipx, shipy, S.SMALLSHIP2SPR)
	RF_Refresh()
	FadeIn()
	WaitVBL(30)
	i = 0
	while true:
		RF_Clear()
		shipx += shipspeeds2[i][0] * PIXGLOBAL
		shipy += shipspeeds2[i][1] * PIXGLOBAL
		RF_PlaceSprite(shipx, shipy, S.SMALLSHIP2SPR)
		RF_Refresh()
		var done: bool = shipspeeds2[i][0] + shipspeeds2[i][1] == 0
		i += 1
		if done or exited:
			break
	RF_Clear()
	RF_PlaceSprite(shipx, shipy, S.SMALLSHIP1SPR)
	RF_Refresh()
	WaitVBL(60)
	DrawWindow(12, 3, 32, 5)
	TypeText("TO BE CONTINUED....")
	WaitVBL(400)
	originx = TILE_ALIGN(originx)
	RF_Refresh()
	RF_Refresh()
	PlaySound(SND.KEENSLEFTSND)
	ShowText(endtextPtr, 0, 22)


func _finale_other() -> void:
	pass


func WarpToSecretLevel() -> void:
	if episode != 1:
		return
	ReadLevel(WORLDMAP)
	PlaySound(SND.TELEPORTSND)
	var ob: Obj = objlist[0]
	ob.xmove = 0
	ob.ymove = 0
	ob.xspeed = 0
	ob.yspeed = 0
	ob.shapenum = S.MAPKEEND1SPR
	ob.x = warpspots[2][0]
	oldx = ob.x
	worldkeenx = ob.x
	ob.y = warpspots[2][1]
	oldy = ob.y
	worldkeeny = ob.y
	originx = ob.x - 9 * TILEGLOBAL
	worldCamX = originx
	originy = ob.y - 3 * TILEGLOBAL
	worldCamY = originy
	RF_Clear()
	RF_ForceRefresh()
	RF_Refresh()
	FadeIn()
	var tx: int = ob.x / TILEGLOBAL
	var ty: int = ob.y / TILEGLOBAL
	var tile: int = 338
	if warpspots[2][2] != 0:
		tile = 342
	var anim: int = 0    # uninitialised in the original
	for i: int in range(16):
		RF_Clear()
		RF_ForceRefresh()
		if i % 2 == 0:
			anim += 1
			if anim > 3:
				anim = 0
		SETTILE(tx, ty, 0, anim + tile)
		RF_Refresh()
	tile = 325
	if warpspots[2][2] != 0:
		tile = 99
	SETTILE(tx, ty, 0, tile)
	while true:
		RF_Clear()
		var ctrl: Dictionary = ControlPlayer(1)
		RF_PlaceSprite(ob.x, ob.y, ob.shapenum)
		RF_Refresh()
		HandleUserKeys()
		DoFkeys()
		if not (ctrl.button1 or ctrl.button2) or exited:
			break
	worldCamX = originx
	worldCamY = originy


# ------------------------------------------------------------ high score

func CheckHighScore() -> void:
	var numberstrings: Array = ["first", "second", "third", "fourth", "fifth", "sixth", "last"]
	var rank: int = 0
	for i: int in range(HIGHSCORE_NUMENTRIES):
		if highscores.scores[i] < gamestate.score:
			rank = i + 1
			break
	originx = TILE_ALIGN(originx)
	originy = TILE_ALIGN(originy)
	RF_ForceRefresh()
	RF_Clear()
	RF_Refresh()
	var x: int = 0
	var y: int = 0
	if rank != 0:
		ExpWin(32, 13)
		x = sx
		y = sy
	else:
		sx = 7
		sy = 10
	DrawPic(sx + 9, sy * 8, P.GAMEOVERPIC)
	PlaySound(SND.GAMEOVERSND)
	rank -= 1
	if rank >= 0:
		leftedge = x + 1
		sx = leftedge
		sy = y + 4
		Print("         SCORE:")
		Print(str(gamestate.score))
		sx = leftedge + 11
		if episode == 1:
			if gamestate.gotJoystick:
				DrawTile(sx, (sy + 2) * 8 - 4, 448)
			if gamestate.gotBattery:
				DrawTile(sx + 2, (sy + 2) * 8 - 4, 449)
			if gamestate.gotVacuum:
				DrawTile(sx + 4, (sy + 2) * 8 - 4, 450)
			if gamestate.gotEverclear:
				DrawTile(sx + 6, (sy + 2) * 8 - 4, 451)
		elif episode == 2:
			var numsaved: int = 0
			for i: int in range(NUMCITIES):
				numsaved += gamestate.citySaved[i]
			sx = leftedge + 6
			sy += 2
			Print("You saved ")
			if numsaved == 0:
				Print("no cities!")
			else:
				Print(str(numsaved))
				if numsaved > 1:
					Print(" cities!")
				else:
					Print(" city!")
			sy -= 2
		sx = leftedge
		sy += 4
		Print("       CONGRATULATIONS!\n")
		Print("     You got ")
		Print(numberstrings[rank])
		Print(" place!\n\n\nEnter your name:")
		for i: int in range(HIGHSCORE_NUMENTRIES - 2, rank - 1, -1):
			highscores.scores[i + 1] = highscores.scores[i]
			highscores.citiesSaved[i + 1] = highscores.citiesSaved[i]
			highscores._unused[i + 1] = highscores._unused[i]
			highscores.gotJoystick[i + 1] = highscores.gotJoystick[i]
			highscores.gotBattery[i + 1] = highscores.gotBattery[i]
			highscores.gotVacuum[i + 1] = highscores.gotVacuum[i]
			highscores.gotEverclear[i + 1] = highscores.gotEverclear[i]
			highscores.names[i + 1] = highscores.names[i]
		ClearKeys()
		var entered: Array = Input(HIGHSCORE_NAMELENGTH)
		highscores.names[rank] = entered[1]
		highscores.scores[rank] = gamestate.score
		highscores.gotJoystick[rank] = 1 if gamestate.gotJoystick else 0
		highscores.gotBattery[rank] = 1 if gamestate.gotBattery else 0
		highscores.gotVacuum[rank] = 1 if gamestate.gotVacuum else 0
		highscores.gotEverclear[rank] = 1 if gamestate.gotEverclear else 0
		var saved: int = 0
		for i: int in range(NUMCITIES):
			saved += gamestate.citySaved[i]
		highscores.citiesSaved[rank] = saved
		highscores._unused[rank] = gamestate._unused
		_save_scores()
	var ctrl: Dictionary
	while not exited:
		ctrl = ControlPlayer(1)
		if not (ctrl.button1 or ctrl.button2):
			break
		vm.poll()
	ClearKeys()
	if rank < 0:
		for i: int in range(360):
			WaitVBL(1)
			ctrl = ControlPlayer(1)
			if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0 or exited:
				break
	FadeOut()
	ClearKeys()
	ReadLevel(TITLEMAP)
	DrawScoreScreen()
	FadeIn()
	var towait: int = SCREENTIME
	canSave = false
	while true:
		RF_Clear()
		RF_Refresh()
		ctrl = ControlPlayer(1)
		if DoFkeys():
			DrawScoreScreen()
		towait = towait - tics
		if ctrl.button1 or ctrl.button2 or NoBiosKey(1) != 0 or towait <= 0 or exited:
			break
	FadeOut()


func ShowLives() -> void:
	ExpWin(16, 4)
	var x: int = sx
	Print("   Keens Left")
	var keens: int = mini(gamestate.lives, 6)
	for i: int in range(keens):
		DrawSprite(x + 2 * i + 1, sy * 8 + 11, S.MAPKEEND1SPR * 4)
	PlaySound(SND.KEENSLEFTSND)


func GetPlayerPosition() -> PackedInt32Array:
	for y: int in range(mapheight):
		for x: int in range(mapwwide):
			if GETTILE(x, y, 1) == 255:
				return PackedInt32Array([TILE_TO_GLOBAL(x), TILE_TO_GLOBAL(y)])
	return PackedInt32Array([0, 0])


# -------------------------------------------------------------- main menu

func MenuLoop() -> void:
	restoredGame = false
	gamestate.lives = 4
	gamestate.ammo = 0
	match episode:
		1:
			gamestate.gotPogo = false
		2:
			gamestate.gotPogo = true
			gamestate.ammo = 3
		3:
			gamestate.gotPogo = true
			gamestate.ammo = 5
	gamestate.gotJoystick = false
	gamestate.gotBattery = false
	gamestate.gotVacuum = false
	gamestate.gotEverclear = false
	for i: int in range(NUMCITIES):
		gamestate.citySaved[i] = 0
	for i: int in range(4):
		gamestate.keys[i] = false
	for i: int in range(NUMLEVELS):
		gamestate.leveldone[i] = false
	var startgame: bool = false
	while not startgame and not exited:
		EGApage = 0
		cyclespeed = 3
		RF_ForceRefresh()
		ReadLevel(TITLEMAP)
		var towait: int
		var screen: int
		if showIntro:
			ReadLevel(TITLEMAP)
			originx = X_APOGEE
			originy = Y_APOGEE
			RF_ForceRefresh()
			RF_Clear()
			RF_Refresh()
			FadeIn()
			towait = SCREENTIME
			screen = 4
			ShowApogeeIntro()
			FadeOut()
			showIntro = false
		towait = SCREENTIME
		screen = 0
		originx = X_TITLE
		originy = Y_TITLE
		RF_ForceRefresh()
		RF_Clear()
		DrawTitleScreen()
		FadeIn()
		ClearKeys()
		var ctrl: Dictionary
		while true:
			ctrl = ControlPlayer(1)
			RF_Clear()
			RF_Refresh()
			if DoFkeys():
				match screen:
					0:
						DrawTitleScreen()
					1:
						DrawIdScreen()
					2:
						DrawScoreScreen()
					3:
						DrawOrderingScreen()
						RF_Refresh()
						DrawOrderingScreen()
			towait = towait - tics
			if towait <= 0:
				FadeOut()
				var skip: bool = false
				match screen:
					0:
						originx = X_ID
						originy = Y_ID
						DrawIdScreen()
					1:
						originx = X_HIGH
						originy = Y_HIGH
						DrawScoreScreen()
					2:
						screen += 1
						ShowOrderingScreen(true)
						ctrl = ControlPlayer(1)
						if NoBiosKey(1) != 0 or ctrl.button1 or ctrl.button2:
							towait = SCREENTIME
							skip = true
						else:
							FadeOut()
				if skip:
					continue
				towait = SCREENTIME
				RF_Clear()
				RF_Refresh()
				screen += 1
				if screen == 4:
					screen = 0
					originx = X_TITLE
					originy = Y_TITLE
					RF_ForceRefresh()
					DrawTitleScreen()
				FadeIn()
			if NoBiosKey(1) != 0 or ctrl.button1 or ctrl.button2 or forcemenu or exited:
				break
		forcemenu = false
		if originx != X_TITLE:
			FadeOut()
		startgame = MainMenuLoop(screen)
	ClearKeys()
	FadeOut()


func MainMenuLoop(_screen: int) -> bool:
	var startgame: bool = false
	var menupos: int = 0
	while true:
		if originx != X_TITLE:
			DrawMainMenuScreen()
			FadeIn()
		else:
			DrawMainMenuScreen()
		ClearKeys()
		var anim: int = 0
		menupos = 0
		var delay: int = 20
		var ctrl: Dictionary = {"dir": nodir, "button1": false, "button2": false}
		while true:
			for i: int in range(6):
				WaitVBL(1)
				ctrl = ControlPlayer(1)
				if ctrl.dir != nodir:
					break
			DrawChar(sx, sy * 8, anim + 9)
			anim += 1
			if anim > 2:
				anim = 0
			match ctrl.dir:
				north:
					if menupos != 0:
						menupos -= 1
						for i: int in range(8):
							DrawChar(sx, sy * 8 - i, anim + 9)
							WaitVBL(1)
							DrawChar(sx, sy * 8 - i, 32)
							anim += 1
							if anim > 2:
								anim = 0
					else:
						menupos = MAXMENUPOS
						DrawChar(sx, sy * 8, 32)
					sy = oldy + menupos
					DrawChar(sx, sy * 8, anim + 9)
					while delay > 0 and ctrl.dir != nodir and not exited:
						delay -= 1
						ctrl = ControlPlayer(1)
						WaitVBL(1)
					delay = 20
					ClearKeys()
				south:
					if menupos < MAXMENUPOS:
						menupos += 1
						for i: int in range(8):
							DrawChar(sx, sy * 8 + i, anim + 9)
							WaitVBL(1)
							DrawChar(sx, sy * 8 + i, 32)
							anim += 1
							if anim > 2:
								anim = 0
					else:
						menupos = 0
						DrawChar(sx, sy * 8, 32)
					sy = oldy + menupos
					DrawChar(sx, sy * 8, anim + 9)
					while delay > 0 and ctrl.dir != nodir and not exited:
						delay -= 1
						ctrl = ControlPlayer(1)
						WaitVBL(1)
					delay = 20
					ClearKeys()
				_:
					WaitVBL(7)
			var c: int = NoBiosKey(1) & 0xFF
			if c != 0 and playermode[1] != keyboard:
				ctrl.button1 = true
			if (c == 32 or c == 13) and playermode[1] == keyboard:
				ctrl.button1 = true
			if DoFkeys():
				DrawMainMenuScreen()
				sy = oldy + menupos
			if ctrl.button1 or ctrl.button2 or exited:
				break
		ClearKeys()
		WaitVBL(8)
		match menupos:
			mm_NewGame:
				startgame = true
			mm_ContinueGame:
				startgame = RestoreMenu()
			mm_Story:
				startgame = false
				ShowStoryText()
			mm_AboutID:
				startgame = false
				FadeOut()
				ShowAboutId()
				FadeOut()
			mm_HighScores:
				startgame = false
				FadeOut()
				ShowScoreScreen()
				FadeOut()
			mm_OrderingInfo:
				startgame = false
				FadeOut()
				ShowOrderingScreen(false)
				FadeOut()
			mm_Previews:
				startgame = false
				FadeOut()
				Previews()
				FadeOut()
			mm_RestartDemo:
				startgame = false
				FadeOut()
		if menupos == mm_RestartDemo or startgame or exited:
			break
	return startgame


func DrawMainMenu() -> void:
	ExpWin(18, 10)
	oldx = sx
	oldy = sy
	Print("   New Game\n")
	Print("   Continue Game\n")
	Print("   Story\n")
	Print("   About ID...\n")
	Print("   High Scores\n")
	Print("   Ordering Info\n")
	Print("   Previews!\n")
	Print("   Restart Demo\n\n")
	Print("Use the ")
	match playermode[1]:
		keyboard:
			Print("arrows")
		mouse:
			Print("mouse")
		joystick1, joystick2:
			Print("joystick")
	sx = oldx + 1
	sy = oldy


func DrawMainMenuScreen() -> void:
	originx = X_TITLE
	originy = Y_TITLE
	RF_ForceRefresh()
	DrawTitleScreen()
	uservect = &"DrawMainMenu"
	RF_Refresh()
	cost("drawmainmenu")    # three page draws with the title picture and the window
	uservect = &""


## KEENACTS.C's; the actor module supplies it.
func LevelLoop(_currentlevel: int) -> int:
	return ex_nothing
