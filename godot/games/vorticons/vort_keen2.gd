# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEEN2ACT.C (and the episode-2 parts of KEENMAIN.C and
# KEENSCRN.C) from K1n9_Duk3's Reconstructed Commander Keen 1-3 Source Code
# (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortKeen2
extends VortActs
## Commander Keen 2: The Earth Explodes. Grunts, Vortikids, Elites, Scrubs,
## guard robots, platforms, the tantalus sparks, the Elder's messages, the
## Earth exploding and the finale.

const gruntobj: int = 2
const youthobj: int = 3
const eliteobj: int = 4
const scrubobj: int = 5
const guardobj: int = 6
const platformobj: int = 7
const sparkobj: int = 8
const ep2_volatileobj: int = 9
const ep2_shotobj: int = 10
const ep2_enemyshotobj: int = 11
const ep2_splashobj: int = 12
const ep2_deadobj: int = 13
const POBJ_TANTALUSEXPLOSION: int = 5     # after POBJ_BORDERFLASH (4) in Keen 2
const POBJ_BORDERFLASH2: int = 4


func _init() -> void:
	super()
	episode = 2
	P = VortNames2.PICS
	S = VortNames2.sprites()
	SND = VortNames2.sounds()
	volatileobj = ep2_volatileobj
	shotobj = ep2_shotobj
	enemyshotobj = ep2_enemyshotobj
	splashobj = ep2_splashobj
	deadobj = ep2_deadobj
	classes = {"volatileobj": volatileobj, "shotobj": shotobj, "enemyshotobj": enemyshotobj,
		"splashobj": splashobj, "deadobj": deadobj}
	# Fitted on keen2_title_a: the sprite loading ends 21.6 refreshes after
	# the ONE MOMENT picture (only the part within a refresh shows: it places
	# the timer's start against the refresh), and the timer's own phase.
	costs = {"loadgraphics": 367727040, "demoloop_load": 5 * 8192 * DosMachine.UNIT,
		"worldmap_load": 4355114, "mapframe": 190909, "levelframe": 50000, "levelthink": 71600, "levelobject": 103400, "levelskip": 13200}    # Keen 1's, until fitted here
	dosbox_timing.timer_offset = -2539712
	# the BIOS tick count when the program reads the DOS clock (oracle clock set
	# to midnight): the only value 0-60 under which keen2_level01_a matches throughout
	dos_ticks = 3


func LoadLevel(number: int) -> void:
	ReadLevel(number)
	# the spawn pass: Turbo C's loop over every tile, GETTILE and the switch
	vm.instructions(mapheight * mapwwide * spawn_scan_per_tile)
	for y: int in range(mapheight):
		for x: int in range(mapwwide):
			match GETTILE(x, y, 1):
				1:
					SpawnGrunt(x, y)
				2:
					SpawnYouth(x, y)
				3:
					SpawnElite(x, y)
				4:
					SpawnScrub(x, y)
				5:
					SpawnGuard(x, y)
				6:
					SpawnPlatformX(x, y)
				7:
					SpawnSpark(x, y)
				255:
					objlist[0].x = TILE_TO_GLOBAL(x)
					objlist[0].y = TILE_TO_GLOBAL(y) + 8 * PIXGLOBAL


# ------------------------------------------------------------------ spawns

func SpawnGrunt(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = gruntobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"GruntWalk"
	ob.contact = &"GruntContact"
	ob.health = 1
	ob.xspeed = -90 if ob.x > objlist[0].x else 90
	ob.shapenum = S.GRUNTSTAND1SPR


func SpawnYouth(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = youthobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"YouthWalk"
	ob.contact = &"YouthContact"
	ob.health = 1
	ob.xspeed = -250 if ob.x > objlist[0].x else 250
	ob.shapenum = S.YOUTHLEFT1SPR


func SpawnElite(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = eliteobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"EliteWalk"
	ob.contact = &"EliteContact"
	ob.health = 2
	ob.xspeed = -100 if ob.x > objlist[0].x else 100
	ob.shapenum = S.ELITELEFT1SPR


func SpawnScrub(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = scrubobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"ScrubWalkLeft"
	ob.contact = &"ScrubContact"
	ob.shapenum = S.SCRUBL1SPR


func SpawnGuard(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = guardobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.xspeed = 100
	ob.think = &"GuardMove"
	ob.contact = &"GuardContact"
	ob.health = 99
	ob.shapenum = S.GUARDSTAND1SPR


func SpawnPlatformX(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = platformobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y) - 4 * PIXGLOBAL
	ob.think = &"PlatformMove"
	ob.contact = &"NullContact"
	ob.shapenum = S.PLATFORM1SPR
	ob.xspeed = 75


func SpawnSpark(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = sparkobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"SparkThink"
	ob.contact = &"SparkContact"
	ob.shapenum = S.SPARK1SPR


# ------------------------------------------------------------------- grunt

func GruntWalk() -> void:
	obon.shapenum = (S.GRUNTRIGHT1SPR if obon.xspeed > 0 else S.GRUNTLEFT1SPR) + ((u16(timecount) >> 4) & 3)
	if RndT() < tics * 2 and lightson:
		obon.yspeed = -Rnd(300)
		obon.think = &"GruntJump"
	elif RndT() < tics * 2:
		match obon.xspeed:
			-90: obon.xspeed = -120
			-120: obon.xspeed = -90
			90: obon.xspeed = 120
			120: obon.xspeed = 90
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -90
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 90
	if (block & BLOCK_DOWN) == 0:
		obon.think = &"GruntJump"


func GruntJump() -> void:
	obon.shapenum = S.GRUNTJUMPLSPR if obon.xspeed > 0 else S.GRUNTJUMPRSPR
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"GruntStand"
		obon.temp1 = 0
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -90
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 90


func GruntStand() -> void:
	obon.xspeed = 0
	obon.shapenum = ((u16(timecount) >> 5) & 3) + S.GRUNTSTAND1SPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 80:
		obon.xspeed = 90
		if obon.x > objlist[0].x:
			obon.xspeed = -obon.xspeed
		obon.think = &"GruntWalk"
	DoGravity()
	MoveObon()


func GruntContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj or hit.obclass == enemyshotobj:
		ob.health -= 1
		if ob.health != 0:
			return
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.GRUNTDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# ------------------------------------------------------------------- youth

func YouthWalk() -> void:
	obon.shapenum = (S.YOUTHRIGHT1SPR if obon.xspeed > 0 else S.YOUTHLEFT1SPR) + ((u16(timecount) >> 4) & 3)
	if RndT() < tics * 3:
		obon.yspeed = -Rnd(400)
		obon.think = &"YouthJump"
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) == 0:
		obon.think = &"YouthJump"
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -250
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 250


func YouthJump() -> void:
	obon.shapenum = S.YOUTHRIGHT4SPR if obon.xspeed > 0 else S.YOUTHLEFT4SPR
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"YouthWalk"
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -250
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 250


func YouthContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj or hit.obclass == enemyshotobj:
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.YOUTHDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# ------------------------------------------------------------------- elite

func EliteWalk() -> void:
	obon.shapenum = (S.ELITERIGHT1SPR if obon.xspeed > 0 else S.ELITELEFT1SPR) + ((u16(timecount) >> 4) & 3)
	if RndT() < tics * 2 and lightson:
		obon.yspeed = -Rnd(300)
		obon.think = &"EliteJump"
	elif RndT() < tics * 2:
		if obon.y + 8 * PIXGLOBAL == objlist[0].y:
			obon.xspeed = 200
		else:
			obon.xspeed = 100
		if obon.x > objlist[0].x:
			obon.xspeed = -obon.xspeed
	elif RndT() < tics * 2:
		obon.think = &"EliteShoot"
		obon.temp1 = 0
		obon.temp2 = 0
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -100
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 100
	if (block & BLOCK_DOWN) == 0:
		obon.think = &"EliteJump"


func EliteShoot() -> void:
	obon.shapenum = S.ELITEFIRELSPR if obon.xspeed < 0 else S.ELITEFIRERSPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 < 30:
		return
	if obon.temp2 == 0:
		obon.temp2 = 1
		PlaySound(SND.TANKFIRESND)
		SpawnEnemyShot(obon.x, obon.y - PIXGLOBAL, -350 if obon.xspeed < 0 else 350)
	if obon.temp1 > 50:
		obon.think = &"EliteWalk"


func EliteJump() -> void:
	obon.shapenum = S.ELITEJUMPLSPR if obon.xspeed > 0 else S.ELITEJUMPRSPR
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"EliteWalk"
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -100
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 100


func EliteContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj:
		var h: int = ob.health
		ob.health -= 1
		if h != 0:
			return
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.ELITEDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# ------------------------------------------------------------------- scrub

func ScrubWalkLeft() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.SCRUBL1SPR
	obon.xspeed = -80
	obon.yspeed = 80
	if obon.temp1 == 0:
		obon.ymove = obon.ymove + 4 * PIXGLOBAL
	var block: int = MoveObon()
	if (block & BLOCK_LEFT) != 0:
		obon.think = &"ScrubWalkUp"
		obon.temp1 = 0
		return
	if (block & BLOCK_DOWN) == 0:
		if obon.temp1 != 0:
			obon.think = &"ScrubWalkDown"
			obon.temp1 = 0
			obon.y += PIXGLOBAL
			return
		else:
			obon.think = &"ScrubFall"
	if obon.temp1 == 0:
		obon.temp1 = 1


func ScrubWalkDown() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.SCRUBD1SPR
	obon.xspeed = 80
	obon.yspeed = 80
	if obon.temp1 == 0:
		obon.xmove = obon.xmove + 4 * PIXGLOBAL
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"ScrubWalkLeft"
		obon.temp1 = 0
		return
	if (block & BLOCK_RIGHT) == 0:
		if obon.temp1 != 0:
			obon.think = &"ScrubWalkRight"
			obon.temp1 = 0
			obon.x += PIXGLOBAL
			return
		else:
			obon.think = &"ScrubFall"
	if obon.temp1 == 0:
		obon.temp1 = 1


func ScrubWalkRight() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.SCRUBR1SPR
	obon.xspeed = 80
	obon.yspeed = -80
	if obon.temp1 == 0:
		obon.ymove = obon.ymove - 4 * PIXGLOBAL
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.think = &"ScrubWalkDown"
		obon.temp1 = 0
		return
	if (block & BLOCK_UP) == 0:
		if obon.temp1 != 0:
			obon.think = &"ScrubWalkUp"
			obon.temp1 = 0
			obon.y -= PIXGLOBAL
			return
		else:
			obon.think = &"ScrubFall"
	if obon.temp1 == 0:
		obon.temp1 = 1


func ScrubWalkUp() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.SCRUBU1SPR
	obon.xspeed = -80
	obon.yspeed = -80
	if obon.temp1 == 0:
		obon.xmove = obon.xmove - 4 * PIXGLOBAL
	var block: int = MoveObon()
	if (block & BLOCK_UP) != 0:
		obon.think = &"ScrubWalkRight"
		obon.temp1 = 0
		return
	if (block & BLOCK_LEFT) == 0:
		if obon.temp1 != 0:
			obon.think = &"ScrubWalkLeft"
			obon.temp1 = 0
			obon.x -= PIXGLOBAL
			return
		else:
			obon.think = &"ScrubFall"
	if obon.temp1 == 0:
		obon.temp1 = 1


func ScrubFall() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.SCRUBL1SPR
	obon.xspeed = 0
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"ScrubWalkLeft"
		obon.temp1 = 0


func ScrubContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj or hit.obclass == enemyshotobj:
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.SCRUBSHOTSPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# ------------------------------------------------------------------- guard

func GuardMove() -> void:
	obon.shapenum = (S.GUARDLEFT1SPR if obon.xspeed > 0 else S.GUARDRIGHT1SPR) + ((u16(timecount) >> 4) & 3)
	if RndT() < tics:
		obon.think = &"GuardShoot"
		obon.temp1 = 0
		obon.temp2 = 0
	var block: int = MoveObon()
	if (block & BLOCK_LEFT) != 0:
		obon.temp2 = 100
		obon.temp1 = 0
		obon.think = &"GuardStand"
	elif (block & BLOCK_RIGHT) != 0:
		obon.temp1 = 0
		obon.temp2 = -100
		obon.think = &"GuardStand"


func GuardShoot() -> void:
	obon.shapenum = (S.GUARDLEFT1SPR if obon.xspeed > 0 else S.GUARDRIGHT1SPR) + ((u16(timecount) >> 4) & 3)
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 < 50:
		return
	if obon.temp1 > 150:
		obon.think = &"GuardMove"
	obon.temp2 = obon.temp2 + tics
	if obon.temp2 > 20:
		obon.temp2 = 0
		PlaySound(SND.TANKFIRESND)
		SpawnEnemyShot(obon.x, obon.y - 4 * PIXGLOBAL, -350 if obon.xspeed < 0 else 350)


func GuardStand() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 50:
		obon.think = &"GuardMove"
		obon.xspeed = obon.temp2
	obon.shapenum = ((u16(timecount) >> 4) & 1) + S.GUARDSTAND1SPR


func GuardContact(_ob: Obj, _hit: Obj) -> void:
	pass


# --------------------------------------------------------------- platform

func PlatformMove() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.PLATFORM1SPR
	var block: int = MoveObon()
	if (block & BLOCK_LEFT) != 0:
		obon.temp2 = 75
		obon.temp1 = 0
		obon.xspeed = 0
		obon.think = &"PlatformTurn"
	elif (block & BLOCK_RIGHT) != 0:
		obon.temp2 = -75
		obon.temp1 = 0
		obon.xspeed = 0
		obon.think = &"PlatformTurn"


func PlatformTurn() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 75:
		obon.xspeed = obon.temp2
		obon.think = &"PlatformMove"


# ---------------------------------------------------------- spark, tantalus

func SparkThink() -> void:
	obon.shapenum = ((u16(timecount) >> 3) & 3) + S.SPARK1SPR
	var block: int = MoveObon()
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 75
	elif (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -75


func SparkContact(ob: Obj, hit: Obj) -> void:
	match level:
		4: gamestate.citySaved[CITY_LONDON] = 1
		6: gamestate.citySaved[CITY_CAIRO] = 1
		7: gamestate.citySaved[CITY_SYDNEY] = 1
		9: gamestate.citySaved[CITY_NEWYORK] = 1
		11: gamestate.citySaved[CITY_PARIS] = 1
		13: gamestate.citySaved[CITY_ROME] = 1
		15: gamestate.citySaved[CITY_MOSCOW] = 1
		16: gamestate.citySaved[CITY_WASHINGTONDC] = 1
	if hit.obclass != shotobj:
		return
	ob.obclass = nothing
	GivePoints(10000)
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_TANTALUSEXPLOSION
	pob.think = &"TantalusExplode"
	pob.x = GLOBAL_TO_TILE(ob.x)
	pob.y = GLOBAL_TO_TILE(ob.y)
	pob.temp[1] = 0
	pob.temp[2] = 0
	pob = FindFreePObj()
	pob.type = POBJ_BORDERFLASH2
	pob.think = &"BorderFlash"
	pob.temp[1] = 0


func ExplodeTile(x: int, y: int, newtile: int) -> void:
	PlaySound(SND.SHOTHITSND)
	var ob: Obj = FindFreeObj()
	ob.think = &"ShotSplash"
	ob.obclass = deadobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.temp1 = 0
	ob.contact = &"NullContact"
	ob.shapenum = S.SHOTSPLASHRSPR if RndT() > 0x80 else S.SHOTSPLASHLSPR
	SETTILE(x, y, 0, newtile)


func TantalusExplode(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] < 40:
		return
	pob.temp[1] -= 40
	pob.temp[2] += 1
	var x: int = pob.x
	var y: int = pob.y
	match pob.temp[2]:
		1:
			SETTILE(x - 1, y - 1, 0, 143)
			SETTILE(x, y - 1, 0, 143)
			SETTILE(x + 1, y - 1, 0, 143)
			SETTILE(x - 1, y, 0, 546)
			SETTILE(x, y, 0, 547)
			SETTILE(x + 1, y, 0, 548)
			SETTILE(x - 3, y + 4, 0, 506)
		2:
			ExplodeTile(x - 2, y, 492)
		3:
			ExplodeTile(x + 2, y, 492)
		4, 5, 6:
			ExplodeTile(x, y + pob.temp[2] - 1, 505)
		7, 8, 9, 10:
			for iy: int in range(y + 3, y + 6):
				ExplodeTile(x + pob.temp[2] - 4, iy, 549)
		_:
			for ix: int in range(x - 7, x - 4):
				for iy: int in range(y + 2, y + 5):
					SETTILE(ix, iy, 0, 533)
			pob.type = POBJ_NOTHING


# ------------------------------------------------------------ stunned Keen

func KeenFrozen() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.KEENSICLE1SPR
	obon.temp1 = obon.temp1 - tics
	if obon.temp1 < 0:
		obon.shapenum = S.KEENMELTSPR
		if obon.temp1 < -40:
			obon.think = &"KeenWalk"
	if obon.xspeed > 0:
		AccelerateX(-3)
		if obon.xspeed < 0:
			obon.xspeed = 0
	elif obon.xspeed < 0:
		AccelerateX(3)
		if obon.xspeed > 0:
			obon.xspeed = 0
	DoGravity()
	MoveObon()
	PlayerCheckMapBorders()


# ------------------------------------------------------------- messages

func ShowMessage() -> void:
	var oldtime: int = timecount
	CenterWindow(22, 13)
	match level:
		8:
			Print("The Elder Vorticon    \n")
			Print("in the stasis field   \n")
			Print("says:                 \n")
			Print("The wise Vorticon     \n")
			Print("never jumps in the    \n")
			Print("dark.  In fact, even  \n")
			Print("unwise Vorticons will \n")
			Print("not jump in darkness. \n")
		10:
			Print("The Vorticon Elder    \n")
			Print("says through the      \n")
			Print("stasis field:         \n")
			Print("The Grand Intellect   \n")
			Print("is not from Vorticon  \n")
			Print("VI--he is from the    \n")
			Print("planet Earth. His evil\n")
			Print("Mind-Belts control    \n")
			Print("their minds.  They are\n")
			Print("not evil. Please do   \n")
			Print("not shoot them, human.\n")
	sy = screencentery + 7
	PrintC("Press ENTER:")
	ClearKeys()
	while (Get() & 0xFF) != CHAR_ENTER and not exited:
		pass
	RF_ForceRefresh()
	ClearKeys()
	timecount = oldtime


# ------------------------------------------------------ game over, finale

func TheEarthExplodes() -> void:
	var explFrames: PackedInt32Array = [0, 0, 1, 1, 2, 2, 3, 3, 2, 2, 3, 3, 2, 2, 3, 3, 2, 2, 1, 1, 0, 0]
	var explX: PackedInt32Array = [2, 1, 3, 1, 3, 0, 2, 2, 4]
	var explY: PackedInt32Array = [2, 1, 1, 3, 3, 2, 0, 4, 2]
	var explDelays: PackedInt32Array = [0, 2, 4, 6, 8, 10, 12, 14, 16]
	ReadLevel(ENDINGMAP)
	originx = 0
	originy = 0
	RF_Clear()
	RF_ForceRefresh()
	RF_Refresh()
	FadeIn()
	WaitVBL(120)
	PlaySound(SND.TANKFIRESND)
	var shotX: int = 6 * TILEGLOBAL
	var shotY: int = 5 * TILEGLOBAL
	for i: int in range(21):
		# the original checks the BIOS key buffer here, which its own
		# keyboard handler keeps empty in v1.31: no early exit. The fix (V05)
		# reads the keys the handler keeps, as v1.3 should have
		if fix_on("k2_esc_skips") and (NoBiosKey(1) & 0xFF) == CHAR_ESCAPE:
			NoBiosKey(0)
			return
		RF_Clear()
		shotX = (i * (41 * TILEGLOBAL)) / 20 + 6 * TILEGLOBAL
		shotY = (i * (17 * TILEGLOBAL)) / 20 + 5 * TILEGLOBAL
		originx = shotX - 6 * TILEGLOBAL
		originy = shotY - 5 * TILEGLOBAL
		RF_PlaceSprite(shotX, shotY, i % 2 + S.TANTALUS1SPR)
		RF_Refresh()
		if exited:
			return
	PlaySound(SND.EARTHPOWSND)
	var earthX: int = 47 * TILEGLOBAL
	var earthY: int = 22 * TILEGLOBAL
	for n: int in range(60):
		RF_Clear()
		if n == 20:
			for tx: int in range(3):
				for ty: int in range(3):
					SETTILE(tx + 47, ty + 22, 0, 155)
		if n >= 15:
			var delta: int = 10 * PIXGLOBAL * (n - 15)
			var f: int = (n / 2) % 4 + S.LILCHUNK1SPR
			RF_PlaceSprite(earthX - delta / 2, earthY - delta, f)
			RF_PlaceSprite(earthX + delta / 2 + TILEGLOBAL, earthY - delta, f)
			RF_PlaceSprite(earthX - delta / 2, earthY + delta + TILEGLOBAL, f)
			RF_PlaceSprite(earthX + delta / 2 + TILEGLOBAL, earthY + delta + TILEGLOBAL, f)
			RF_PlaceSprite(earthX - delta, earthY - delta / 2, f)
			RF_PlaceSprite(earthX + delta + TILEGLOBAL, earthY - delta / 2, f)
			RF_PlaceSprite(earthX - delta, earthY + delta / 2 + TILEGLOBAL, f)
			RF_PlaceSprite(earthX + delta + TILEGLOBAL, earthY + delta / 2 + TILEGLOBAL, f)
		if n >= 20:
			var delta: int = PIXEL_TO_GLOBAL((n - 20) << 3)
			var f: int = (n / 2) % 4 + S.EARTHCHUNK1SPR
			RF_PlaceSprite(earthX - delta, earthY - delta, f)
			RF_PlaceSprite(earthX + delta + TILEGLOBAL, earthY - delta, f)
			RF_PlaceSprite(earthX - delta, earthY + delta + TILEGLOBAL, f)
			RF_PlaceSprite(earthX + delta + TILEGLOBAL, earthY + delta + TILEGLOBAL, f)
		for i: int in range(9):
			var stage: int = n - explDelays[i]
			if stage >= 0:
				var frame: int = explFrames[stage] if stage < explFrames.size() else -1
				if frame != -1:
					RF_PlaceSprite(TILE_TO_GLOBAL(explX[i] + 47 * 2) / 2, TILE_TO_GLOBAL(explY[i] + 22 * 2) / 2, frame + S.FIREARTH1SPR)
		RF_Refresh()
		WaitVBL(3)
		if exited:
			return


func EraseWin() -> void:
	CharBar(win_xl, win_yl, win_xh, win_yh, 32)


func _finale_other() -> void:
	ReadLevel(ENDINGMAP)
	originx = 0
	originy = 0
	RF_Clear()
	RF_ForceRefresh()
	var shipX: int = 7 * TILEGLOBAL
	var shipY: int = 3 * TILEGLOBAL
	RF_PlaceSprite(shipX, shipY, S.SMALLSHIPRSPR)
	RF_Refresh()
	DrawWindow(4, 17, 36, 24)
	FadeIn()
	TypeText("After disabling the weaponry of\n")
	TypeText("the Vorticon Mothership, Billy\n")
	TypeText("heads for earth.  Even great\n")
	TypeText("space heroes need a nap after\n")
	TypeText("defeating a vicious horde\n")
	TypeText("of violence-bent aliens!")
	WaitVBL(300)
	RF_ForceRefresh()
	RF_Refresh()
	for i: int in range(121):
		# the same check as the Earth's (V06): no early exit in the original
		if fix_on("k2_esc_skips") and (NoBiosKey(1) & 0xFF) == CHAR_ESCAPE:
			NoBiosKey(0)
			return
		RF_Clear()
		shipX = (i * (648 * PIXGLOBAL)) / 120 + 7 * TILEGLOBAL
		shipY = (i * (312 * PIXGLOBAL)) / 120 + 3 * TILEGLOBAL
		originx = shipX - 7 * TILEGLOBAL
		originy = shipY - 3 * TILEGLOBAL
		RF_PlaceSprite(shipX, shipY, S.SMALLSHIPRSPR)
		RF_Refresh()
		if exited:
			return
	WaitVBL(120)
	FadeOut()
	RF_Clear()
	originx = 0
	originy = 12 * TILEGLOBAL
	var lameX: int = 10 * TILEGLOBAL
	var lameY: int = 17 * TILEGLOBAL
	RF_PlaceSprite(lameX, lameY, S.LAMESHIPSPR)
	RF_Refresh()
	DrawWindow(4, 17, 36, 24)
	FadeIn()
	TypeText("The Vorticon ship limps back\n")
	TypeText("toward Vorticon VI to tell of  \n")
	TypeText("their defeat at the hands of\n")
	TypeText("Commander Keen.  The Grand\n")
	TypeText("Intellect will not be pleased.\n")
	WaitVBL(120)
	RF_ForceRefresh()
	for i: int in range(120):
		RF_Clear()
		lameX -= PIXGLOBAL
		lameY -= PIXGLOBAL
		RF_PlaceSprite(lameX, lameY, S.LAMESHIPSPR)
		RF_Refresh()
		if exited:
			return
	FadeOut()
	originx &= 0xFFFF000     # the original's mask (28 bits), as written
	RF_Refresh()
	DrawPicFile("finale.ck2")
	ReadLevel(ENDINGMAP)
	FadeIn()
	DrawWindow(4, 18, 29, 22)
	TypeText("Wake up, Billy.  It\n")
	TypeText("Snowed last night!\n")
	TypeText("There's no school!")
	WaitVBL(120)
	EraseWin()
	DrawWindow(4, 16, 29, 24)
	TypeText("Wonderful, Mother.  That\n")
	TypeText("will give me time to rid\n")
	TypeText("the Galaxy of the\n")
	TypeText("Vorticon menace and\n")
	TypeText("discover the secret of\n")
	TypeText("the mysterious Grand\n")
	TypeText("Intellect!\n")
	WaitVBL(120)
	EraseWin()
	DrawWindow(4, 18, 29, 23)
	TypeText("Ok, hon, but you'd\n")
	TypeText("better have a nourishing\n")
	TypeText("vitamin fortified bowl\n")
	TypeText("of Sugar Stoopies first.\n")
	WaitVBL(120)
	EraseWin()
	DrawWindow(4, 18, 16, 20)
	TypeText("Ok, mom...")
	WaitVBL(120)
	EraseWin()
	DrawWindow(12, 3, 32, 5)
	TypeText("TO BE CONTINUED....")
	WaitVBL(400)
	originx = TILE_ALIGN(originx)
	RF_ForceRefresh()
	RF_Refresh()
	RF_Refresh()
	DrawTextScreen(endtextPtr, 0, 22)
	PlaySound(SND.KEENSLEFTSND)
	WaitEndSound()
	ShowText(endtextPtr, 0, 22)


# ------------------------------------------------- the common code's hooks

func KeenContact(ob: Obj, hit: Obj) -> void:
	match hit.obclass:
		scrubobj, platformobj:
			RideObj(ob, hit)
		youthobj:
			if ob.think == &"KeenFrozen":
				return
			ob.think = &"KeenFrozen"
			ob.xspeed = hit.xspeed
			ob.yspeed = hit.yspeed
			ob.temp1 = 400
		gruntobj, eliteobj, guardobj, enemyshotobj:
			HurtKeen()


func _shot_passes(hit: Obj) -> bool:
	return hit.obclass == guardobj or hit.obclass == eliteobj


func _always_active(ob: Obj) -> bool:
	return ob.obclass == platformobj


func _lose_items(currentlevel: int) -> void:
	match currentlevel:
		4: gamestate.citySaved[CITY_LONDON] = 0
		6: gamestate.citySaved[CITY_CAIRO] = 0
		7: gamestate.citySaved[CITY_SYDNEY] = 0
		9: gamestate.citySaved[CITY_NEWYORK] = 0
		11: gamestate.citySaved[CITY_PARIS] = 0
		13: gamestate.citySaved[CITY_ROME] = 0
		15: gamestate.citySaved[CITY_MOSCOW] = 0
		16: gamestate.citySaved[CITY_WASHINGTONDC] = 0


# ------------------------------------------- the episode's own screens

func _status_screen_other() -> void:
	ExpWin(28, 12)
	var x: int = sx
	var y: int = sy
	PrintGrey("    SCORE     EXTRA KEEN AT \n")
	sx = x + 12
	PrintGrey(" \n")
	PrintGrey("    KEENS            PISTOL \n")
	for i: int in range(3):
		sx = x + 19
		PrintGrey(" \n")
	PrintGrey("   TARGETS SAVED      KEYS  \n")
	for i: int in range(4):
		sx = x + 19
		PrintGrey(" \n")
	PrintGrey("     PLEASE PRESS A KEY     ")
	var text: String = str(gamestate.score)
	sx = x + 10 - text.length()
	sy = y + 1
	Print(text)
	text = str(lastextra + EXTRASCORE)
	sx = x + 26 - text.length()
	Print(text)
	for i: int in range(mini(gamestate.lives, 9)):
		DrawSprite(x + i * 2 + 1, (y + 3) * 8, S.KEENWALKR1SPR * 4)
	DrawTile(x + 21, (y + 3) * 8 + 4, 414)
	sx = x + 24
	sy = y + 4
	PrintInt(gamestate.ammo)
	sx = x + 21
	sy = y + 7
	if gamestate.keys[0]:
		DrawTile(sx, sy * 8, 424)
	if gamestate.keys[1]:
		DrawTile(sx + 4, sy * 8, 425)
	if gamestate.keys[2]:
		DrawTile(sx, sy * 8 + 16, 426)
	if gamestate.keys[3]:
		DrawTile(sx + 4, sy * 8 + 16, 427)
	var cities: Array = [[CITY_LONDON, 0, 7, "London"], [CITY_CAIRO, 0, 8, "Cairo"], [CITY_SYDNEY, 0, 9, "Sydney"],
		[CITY_NEWYORK, 0, 10, "New York"], [CITY_PARIS, 10, 7, "Paris"], [CITY_ROME, 10, 8, "Rome"],
		[CITY_MOSCOW, 10, 9, "Moscow"], [CITY_WASHINGTONDC, 10, 10, "Wash D.C."]]
	for c: Array in cities:
		if gamestate.citySaved[c[0]] != 0:
			sx = x + c[1]
			sy = y + c[2]
			Print(c[3])


func _ordering_screen_other(timed: bool) -> void:
	var shapes: Array = [S.SCRUBR1SPR, S.SCRUBD1SPR, S.SCRUBL1SPR, S.SCRUBU1SPR]
	var scruby: int = 4
	var scrubx: int = 0
	var xspeed: int = 2
	var yspeed: int = 0
	var frame: int = 0
	var counter: int = 0
	var baseshape: int = shapes[0]
	DrawOrderingScreen()
	FadeIn()
	ClearKeys()
	var towait: int = SCREENTIME
	while true:
		var ctrl: Dictionary = ControlPlayer(1)
		RF_Clear()
		if xspeed > 0:
			baseshape = shapes[0]
			scrubx += PIXEL_TO_GLOBAL(xspeed)
			if scrubx > 302 * PIXGLOBAL:
				xspeed = 0
				yspeed = 2
		if xspeed < 0:
			baseshape = shapes[2]
			scrubx += PIXEL_TO_GLOBAL(xspeed)
			if scrubx < 2:
				xspeed = 0
				yspeed = -2
		if yspeed > 0:
			baseshape = shapes[1]
			scruby += PIXEL_TO_GLOBAL(yspeed)
			if scruby > 184 * PIXGLOBAL:
				xspeed = -2
				yspeed = 0
		if yspeed < 0:
			baseshape = shapes[3]
			scruby += PIXEL_TO_GLOBAL(yspeed)
			if scruby < 6:
				xspeed = 2
				yspeed = 0
		if (counter % 4) == 0:
			frame ^= 1
		RF_PlaceSprite(scrubx + originx, scruby + originy, baseshape + frame)
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


func _ordering_info_other() -> void:
	leftedge = 6
	sx = 6
	sy = 3
	PrintGrey("   Commander Keen: Invasion of the  \n")
	PrintGrey(" Vorticons consists of three unique \n")
	PrintGrey("      and challenging episodes:\n\n")
	PrintGrey(" Order the trilogy for $30 and get:\n")
	PrintGrey("* The \"Secret Hints & Tricks\" sheet\n")
	PrintGrey("* The special \"cheat mode\" password\n")
	PrintGrey("* The latest version of each game\n")
	PrintGrey("* SEVERAL FREE BONUS GAMES!\n\n")
	PrintGrey("          Mail orders to:\n")
	PrintGrey("          Apogee Software\n")
	PrintGrey("          P.O. Box 476389\n")
	PrintGrey("          Garland, TX 75047\n\n")
	PrintGrey("  U.S. funds only; checks or M/O's\n")
	PrintGrey("   Include $2 postage & handling\n")
	PrintGrey("Specify 5.25/3.5 disk when ordering.\n")
	PrintGrey(" Or order toll free: 1-800-852-5659 ")


func _cheat_keeps_going(ob: Obj) -> bool:
	return ob.obclass in [platformobj]
