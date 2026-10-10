# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEEN3ACT.C (and the episode-3 parts of KEENMAIN.C, KEENDEMO.C
# and KEENSCRN.C) from K1n9_Duk3's Reconstructed Commander Keen 1-3 Source
# Code (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortKeen3
extends VortActs
## Commander Keen 3: Keen Must Die! Vorticon grunts, kids, mothers and ninjas,
## Meeps and their sound waves, Foobs, jacks and balls, turrets, the Mangling
## Machine's arms and feet, Messie on the world map, the teleporters, the
## ankh's halo, Mortimer's introduction and the photo-flash finale.

const gruntobj: int = 2
const youthobj: int = 3
const womanobj: int = 4
const meepobj: int = 5
const ninjaobj: int = 6
const foobobj: int = 7
const ballobj: int = 8
const jackobj: int = 9
const platformobj: int = 10
const classtype_11: int = 11
const heartobj: int = 12
const sparkobj: int = 13
const ep3_volatileobj: int = 14
const ep3_shotobj: int = 15
const ep3_enemyshotobj: int = 16
const meepwaveobj: int = 17
const ep3_splashobj: int = 18
const ep3_deadobj: int = 19

const POBJ_BORDERFLASH3: int = 4
const POBJ_TURRET: int = 5
const POBJ_ARM: int = 6
const POBJ_FOOT: int = 7
const POBJ_DESTROYARMS: int = 8
const POBJ_DESTROYMACHINE: int = 9

const MESSIESPEED: int = 2                    # movement speed, in pixels
const MESSIEMOVES: int = 16 / MESSIESPEED     # moves to pass through one tile
const NUMWARPS: int = 16

# Messie
var messiexmove: int = 0
var messieymove: int = 0
var messiex: int = 0
var messiey: int = 0
var messiecount: int = 0
var messieshape: int = 0
var messiecooldown: int = 0
var messieoldtilex: int = 0
var messieoldtiley: int = 0
## The teleport loop's uninitialised `anim` (Messie's frame reads bit 1 of it): the
## stack slot's leftover when CheckMapKeenTiles runs. Fitted on keen3_level12_a.
var teleport_anim0: int = 0

## The teleporters found by ScanWorldMap: [x, y, tag] per index.
var warps: Array = []


func _init() -> void:
	super()
	episode = 3
	P = VortNames3.PICS
	S = VortNames3.sprites()
	SND = VortNames3.sounds()
	volatileobj = ep3_volatileobj
	shotobj = ep3_shotobj
	enemyshotobj = ep3_enemyshotobj
	splashobj = ep3_splashobj
	deadobj = ep3_deadobj
	classes = {"volatileobj": volatileobj, "shotobj": shotobj, "enemyshotobj": enemyshotobj,
		"splashobj": splashobj, "deadobj": deadobj}
	for i: int in range(NUMWARPS):
		warps.append([0, 0, 0])
	# Fitted on keen3_title_a (see Keen 2's): where the sprite loading ends
	# within a refresh, and the timer's phase. The title screen has no
	# animated tiles, so the tic count itself first shows at the id screen's
	# border: that pinned the timer's start to 21.5312 refreshes, one tic
	# after an equally good-looking 21.05.
	costs = {"loadgraphics": round(21.5312 * DosMachine.VBL_PERIOD), "demoloop_load": 5 * 8192 * DosMachine.UNIT,
		"worldmap_load": 13750000, "mapframe": 190909, "levelframe": 50000, "levelthink": 71600, "levelobject": 103400, "levelskip": 13200}
	# worldmap_load: the middle of 5.5M-22M, the window levels 6 and 14 pass in (one refresh
	# wide). mapframe and the level frame costs are Keen 1's, until fitted here.
	costs["demoloop_load"] = 33792000    # 4.125 tics: the middle of 3.25-5.0, the title's window with the spawn scan below
	# LoadLevel's spawn pass: 19 switch cases. With their keys fitted, the level entries pass
	# at 120-132 a tile on level 15, from 128 on level 9, from 124 on level 5 (Keen 1's levels
	# pass only below 52: a smaller switch, compiled differently)
	spawn_scan_per_tile = 130
	map_anim0 = 1    # the map loop's uninitialised anim: level 15's Messie frames need 1 mod 4
	teleport_anim0 = 3    # the teleport loop's uninitialised anim: level 12's Messie frames need 3 mod 4
	# the title's fit (-4453955) moved 175 us earlier: level 12's teleporter loop reads timecount
	# just before a tic there, the original just after; level 14 passes from -200 us to 0
	dosbox_timing.timer_offset = -4662762
	# the BIOS tick count when the program reads the DOS clock (oracle clock set to midnight): the only value 0-60 under which levels 6 and 14 match throughout
	dos_ticks = 4


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
					SpawnWoman(x, y)
				4:
					SpawnMeep(x, y)
				5:
					SpawnNinja(x, y)
				6:
					SpawnFoob(x, y)
				7:
					SpawnBall(x, y)
				8:
					SpawnJack(x, y)
				9:
					SpawnPlatformX(x, y)
				10:
					SpawnPlatformY(x, y)
				11:
					SpawnGrunt(x, y)
				12:
					SpawnSpark(x, y)
				13:
					SpawnHeart(x, y)
				14:
					SpawnTurretE(x, y)
				15:
					SpawnTurretS(x, y)
				16:
					SpawnArm(x, y)
				17:
					SpawnFoot(x, y, -1)
				18:
					SpawnFoot(x, y, 1)
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


func SpawnWoman(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = womanobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"WomanWalk"
	ob.contact = &"WomanContact"
	ob.health = 5
	ob.xspeed = -50 if ob.x > objlist[0].x else 50
	ob.shapenum = S.WOMANL1SPR


func SpawnMeep(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = meepobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y) + 8 * PIXGLOBAL
	ob.think = &"MeepWalk"
	ob.contact = &"MeepContact"
	ob.health = 1
	ob.xspeed = -65 if ob.x > objlist[0].x else 65
	ob.shapenum = S.MEEPL1SPR


func SpawnNinja(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = ninjaobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"NinjaStand"
	ob.contact = &"NinjaContact"
	ob.health = 3
	ob.xspeed = -1 if ob.x > objlist[0].x else 1
	ob.shapenum = S.NINJAL1SPR


func SpawnFoob(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = foobobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"FoobWalk"
	ob.contact = &"FoobContact"
	ob.health = 1
	ob.xspeed = -50 if ob.x > objlist[0].x else 50
	ob.shapenum = S.FOOBL1SPR


func SpawnBall(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = ballobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"BallThink"
	ob.contact = &"NullContact"
	ob.health = 1
	ob.xspeed = -400 if ob.x > objlist[0].x else 400
	ob.yspeed = -400 if ob.y > objlist[0].y else 400
	ob.shapenum = S.BALLSPR


func SpawnJack(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = jackobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"JackThink"
	ob.contact = &"NullContact"
	ob.health = 1
	ob.xspeed = -400 if ob.x > objlist[0].x else 400
	ob.yspeed = -400 if ob.y > objlist[0].y else 400
	ob.shapenum = S.JACK1SPR


func SpawnPlatformX(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = platformobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y) - 4 * PIXGLOBAL
	ob.think = &"PlatformThink"
	ob.contact = &"NullContact"
	ob.shapenum = S.PLATFORM1SPR
	ob.xspeed = 75


func SpawnPlatformY(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = platformobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"PlatformThink"
	ob.contact = &"NullContact"
	ob.shapenum = S.PLATFORM1SPR
	ob.yspeed = 75


func SpawnTurretE(x: int, y: int) -> void:
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_TURRET
	pob.x = TILE_TO_GLOBAL(x)
	pob.y = TILE_TO_GLOBAL(y)
	pob.think = &"TurretEThink"


func SpawnTurretS(x: int, y: int) -> void:
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_TURRET
	pob.x = TILE_TO_GLOBAL(x)
	pob.y = TILE_TO_GLOBAL(y)
	pob.think = &"TurretSThink"


func SpawnSpark(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = sparkobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"SparkThink"
	ob.contact = &"SparkContact"
	ob.shapenum = S.SPARK1SPR


func SpawnHeart(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = heartobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"HeartThink"
	ob.contact = &"HeartContact"
	ob.shapenum = S.SPARK1SPR    # the original's slip; the think sets the right one before any draw


func SpawnArm(x: int, y: int) -> void:
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_ARM
	pob.x = x
	pob.y = y
	pob.think = &"ArmThink"
	pob.temp[2] = 0
	pob.temp[1] = 1
	pob.temp[3] = 15


func SpawnFoot(x: int, y: int, dir: int) -> void:
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_FOOT
	pob.x = x
	pob.y = y
	pob.temp[3] = dir
	pob.temp[1] = dir
	pob.think = &"FootThink"


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
	if hit.obclass == shotobj:
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.YOUTHDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# ------------------------------------------------------------------- woman

func WomanWalk() -> void:
	obon.shapenum = (S.WOMANR1SPR if obon.xspeed > 0 else S.WOMANL1SPR) + ((u16(timecount) >> 4) & 1)
	var oldy: int = obon.y
	if RndT() < tics:
		obon.temp3 = -obon.xspeed
		obon.temp1 = 0
		obon.temp2 = 0
		obon.xspeed = 0
		obon.think = &"WomanShoot"
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) == 0:
		# no longer on solid ground (the woman is not supposed to fall):
		# BUG in the original: resetting y is useless (ymove should be 0)
		obon.y = oldy
		obon.xspeed = -obon.xspeed
		obon.x += obon.xspeed * 2    # unclipped movement
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -50
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 50


func WomanShoot() -> void:
	obon.shapenum = S.WOMANBLSPR if obon.temp3 < 0 else S.WOMANBRSPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 < 30:
		return
	if obon.temp2 == 0:
		obon.temp2 = 1
		PlaySound(SND.TANKFIRESND)
		SpawnWomanShot(obon.x, obon.y - PIXGLOBAL, -150 if obon.temp3 < 0 else 150)
	if obon.temp1 > 50:
		obon.xspeed = obon.temp3
		obon.think = &"WomanWalk"


func SpawnWomanShot(x: int, y: int, xspeed: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = enemyshotobj
	ob.x = x
	ob.y = y + 13 * PIXGLOBAL
	ob.think = &"WomanShotThink"
	ob.xspeed = xspeed
	ob.contact = &"WomanShotContact"
	if xspeed >= 0:
		ob.shapenum = S.WOMANFIRER1SPR
		ob.temp1 = S.WOMANFIRER1SPR
		if eastwall[GETTILE(GLOBAL_TO_TILE(x) + 1, GLOBAL_TO_TILE(y) + 1, 0)] != 0:
			_woman_shot_splash(ob)
	else:
		ob.shapenum = S.WOMANFIREL1SPR
		ob.temp1 = S.WOMANFIREL1SPR
		if westwall[GETTILE(GLOBAL_TO_TILE(x), GLOBAL_TO_TILE(y) + 1, 0)] != 0:
			_woman_shot_splash(ob)


func _woman_shot_splash(ob: Obj) -> void:
	PlaySound(SND.SHOTHITSND)
	ob.obclass = splashobj
	ob.think = &"ShotSplash"
	ob.temp1 = 0
	ob.shapenum = S.SHOTSPLASHRSPR if RndT() > 0x80 else S.SHOTSPLASHLSPR


func WomanShotThink() -> void:
	obon.shapenum = obon.temp1 + ((u16(timecount) >> 3) & 1)
	var block: int = MoveObon()
	if block != 0:
		PlaySound(SND.SHOTHITSND)
		obon.obclass = splashobj
		obon.think = &"ShotSplash"
		obon.temp1 = 0
		obon.shapenum = S.SHOTSPLASHRSPR if RndT() > 0x80 else S.SHOTSPLASHLSPR


func WomanShotContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == womanobj or hit.obclass == deadobj:
		return
	PlaySound(SND.SHOTHITSND)
	ob.think = &"ShotSplash"
	ob.contact = &"NullContact"
	ob.temp1 = 0
	ob.shapenum = S.SHOTSPLASHRSPR if RndT() > 0x80 else S.SHOTSPLASHLSPR


func WomanContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj:
		ob.health -= 1
		if ob.health != 0:
			return
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.WOMANDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# -------------------------------------------------------------------- meep

func MeepWalk() -> void:
	obon.shapenum = (S.MEEPR1SPR if obon.xspeed > 0 else S.MEEPL1SPR) + ((u16(timecount) >> 4) & 1)
	if RndT() < tics:
		obon.temp3 = obon.xspeed
		obon.temp1 = 0
		obon.temp2 = 0
		obon.xspeed = 0
		obon.think = &"MeepSing"
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) == 0:
		obon.temp3 = obon.xspeed    # BUG? in the original: keeps walking the old way after singing
		obon.temp1 = 0
		obon.temp2 = 0
		obon.xspeed = 0
		obon.think = &"MeepSing"
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -65
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 65


func MeepSing() -> void:
	obon.shapenum = S.MEEPSINGLSPR if obon.temp3 < 0 else S.MEEPSINGRSPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 60:
		if obon.temp2 == 0:
			obon.temp2 = 1
			PlaySound(SND.MEEPSND)
			var ob: Obj = FindFreeObj()
			if obon.temp3 < 0:
				ob.x = obon.x
				ob.shapenum = S.MEEPWAVEL1SPR
				ob.temp1 = S.MEEPWAVEL1SPR
				ob.xspeed = -200
			else:
				ob.x = obon.x + TILEGLOBAL
				ob.xspeed = 200
				ob.shapenum = S.MEEPWAVER1SPR
				ob.temp1 = S.MEEPWAVER1SPR
			ob.y = obon.y + 4 * PIXGLOBAL
			ob.think = &"MeepWaveThink"
			ob.contact = &"NullContact"
			ob.obclass = meepwaveobj
		if obon.temp1 > 80:
			obon.xspeed = obon.temp3
			obon.think = &"MeepWalk"


func MeepContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj:
		ob.health -= 1
		if ob.health != 0:
			return
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.MEEPDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


func MeepWaveThink() -> void:
	obon.shapenum = obon.temp1 + ((u16(timecount) >> 3) & 1)
	obon.xmove = obon.xspeed * tics    # moves without clipping


# ------------------------------------------------------------------- ninja

func NinjaStand() -> void:
	if obon.x < objlist[0].x:
		obon.xspeed = 250
		obon.shapenum = S.NINJAR1SPR
	else:
		obon.xspeed = -250
		obon.shapenum = S.NINJAL1SPR
	obon.shapenum = obon.shapenum + ((u16(timecount) >> 5) & 1)
	var ydiff: int = objlist[0].y - obon.y
	if ydiff > 5 * TILEGLOBAL or ydiff < -5 * TILEGLOBAL:
		return
	if RndT() < tics * 3:
		obon.yspeed = -Rnd(350)
		obon.think = &"NinjaJump"


func NinjaJump() -> void:
	obon.shapenum = S.NINJAJUMPRSPR if obon.xspeed > 0 else S.NINJAJUMPLSPR
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"NinjaStand"


func NinjaContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj:
		var h: int = ob.health
		ob.health -= 1
		if h != 0:
			return
		PlaySound(SND.VORTSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.NINJADIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


# -------------------------------------------------------------------- foob

func FoobWalk() -> void:
	obon.shapenum = (S.FOOBR1SPR if obon.xspeed > 0 else S.FOOBL1SPR) + ((u16(timecount) >> 5) & 1)
	var tx: int = GLOBAL_TO_TILE(obon.x)
	var ty: int = GLOBAL_TO_TILE(obon.y)
	if tx > ox and ty > oy and ox + 19 > tx:
		# the original's bitwise & of two conditions: the random number is drawn either way
		var scared: bool = RndT() < tics * 2
		if scared and oy + 12 > ty:
			obon.temp1 = 0
			obon.think = &"FoobYell"
			PlaySound(SND.YORPSCREAMSND)
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -50
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 50


func FoobRun() -> void:
	obon.shapenum = (S.FOOBR1SPR if obon.xspeed > 0 else S.FOOBL1SPR) + ((u16(timecount) >> 3) & 1)
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = -1
	elif (block & BLOCK_RIGHT) != 0:
		obon.xspeed = 1


func FoobYell() -> void:
	obon.shapenum = ((u16(timecount) / 10) & 1) + S.FOOBYELL1SPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 24:
		# run away from Keen
		obon.xspeed = 250 if obon.x > objlist[0].x else -250
		obon.think = &"FoobRun"


func FoobContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == keenobj or hit.obclass == shotobj or hit.obclass == enemyshotobj:
		PlaySound(SND.YORPSCREAMSND)
		ob.temp1 = 0
		ob.temp2 = 3
		ob.shapenum = S.FOOBDIE1SPR
		ob.contact = &"NullContact"
		ob.think = &"DyingThink"


func _reactivate() -> void:
	if obon.think == &"FoobRun":
		obon.think = &"FoobWalk"
		obon.xspeed = 50 if obon.x > objlist[0].x else -50


# ------------------------------------------------------------ jack, ball

func JackThink() -> void:
	obon.shapenum = ((u16(timecount) >> 3) & 3) + S.JACK1SPR
	_bounce(MoveObon())


func BallThink() -> void:
	_bounce(MoveObon())


func _bounce(block: int) -> void:
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -400
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 400
	if (block & BLOCK_DOWN) != 0:
		obon.yspeed = -400
	if (block & BLOCK_UP) != 0:
		obon.yspeed = 400


# --------------------------------------------------------------- platform

func PlatformThink() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.PLATFORM1SPR
	var block: int = MoveObon()
	if (block & BLOCK_LEFT) != 0:
		obon.temp2 = 75
		obon.temp1 = 0
		obon.temp3 = 0
		obon.xspeed = 0
		obon.think = &"PlatformTurn"
	elif (block & BLOCK_RIGHT) != 0:
		obon.temp2 = -75
		obon.temp1 = 0
		obon.temp3 = 0
		obon.xspeed = 0
		obon.think = &"PlatformTurn"
	if (block & BLOCK_UP) != 0:
		obon.temp3 = 75
		obon.temp1 = 0
		obon.temp2 = 0
		obon.yspeed = 0
		obon.think = &"PlatformTurn"
	elif (block & BLOCK_DOWN) != 0:
		obon.yspeed = -75


func PlatformTurn() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 75:
		obon.xspeed = obon.temp2
		obon.yspeed = obon.temp3
		obon.think = &"PlatformThink"


# ----------------------------------------------------------------- turrets

func TankShotThink() -> void:
	var block: int = MoveObon()
	if block != 0:
		PlaySound(SND.SHOTHITSND)
		obon.obclass = splashobj
		obon.think = &"ShotSplash"
		obon.temp1 = 0
		obon.shapenum = S.SHOTSPLASHRSPR if RndT() > 0x80 else S.SHOTSPLASHLSPR


func TurretEThink(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] < 400:
		return
	pob.temp[1] -= 400
	PlaySound(SND.TANKFIRESND)
	var ob: Obj = FindFreeObj()
	ob.shapenum = S.TANKSHOTSPR
	ob.xspeed = 400
	ob.x = pob.x
	ob.y = pob.y + 3 * PIXGLOBAL
	ob.think = &"TankShotThink"
	ob.contact = &"NullContact"
	ob.obclass = enemyshotobj


func TurretSThink(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] < 400:
		return
	pob.temp[1] -= 400
	PlaySound(SND.TANKFIRESND)
	var ob: Obj = FindFreeObj()
	ob.shapenum = S.VTANKSHOTSPR
	ob.yspeed = 400
	ob.x = pob.x + 4 * PIXGLOBAL
	ob.y = pob.y
	ob.think = &"TankShotThink"
	ob.contact = &"NullContact"
	ob.obclass = enemyshotobj


# -------------------------------------------------------- mangling machine

func SparkThink() -> void:
	obon.shapenum = ((u16(timecount) >> 3) & 3) + S.SPARK1SPR


func SparkContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass != shotobj:
		return
	ob.obclass = nothing    # the shot still explodes
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_BORDERFLASH3
	pob.think = &"BorderFlash"
	pob.temp[1] = 0
	GivePoints(1000)
	sparksgone += 1
	if sparksgone == 6:
		for i: int in range(pobjcount):
			if pobjlist[i].type == POBJ_ARM:
				pobjlist[i].type = POBJ_NOTHING
		pob = FindFreePObj()
		pob.type = POBJ_DESTROYARMS
		pob.think = &"DestroyArms"
		pob.y = 6
		pob.temp[1] = 0
		pob.temp[2] = 0


func HeartThink() -> void:
	obon.shapenum = ((u16(timecount) / 24) & 1) + S.HEART1SPR


func HeartContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass != shotobj:
		return
	ob.obclass = nothing
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_BORDERFLASH3
	pob.think = &"BorderFlash"
	pob.temp[1] = 0
	GivePoints(1000)
	for i: int in range(pobjcount):
		if pobjlist[i].type == POBJ_FOOT:
			pobjlist[i].type = POBJ_NOTHING
	pob = FindFreePObj()
	pob.type = POBJ_DESTROYMACHINE
	pob.think = &"DestroyManglingMachine"
	pob.y = 2
	pob.temp[1] = 0
	pob.temp[2] = 0
	numobj = 1    # every sprite object but Keen goes


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


func DestroyArms(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] >= 30:
		pob.temp[1] -= 30
		pob.y += 1
		if pob.y == 19:
			pob.type = POBJ_NOTHING
		else:
			var y: int = pob.y
			for x: int in range(5, 8):          # left arm
				if GETTILE(x, y, 0) != 169:
					ExplodeTile(x, y, 169)
			for x: int in range(17, 20):        # right arm
				if GETTILE(x, y, 0) != 169:
					ExplodeTile(x, y, 169)


func DestroyManglingMachine(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] < 20:
		return
	pob.temp[1] -= 20
	pob.y += 1
	if pob.y == 24:
		LevelDone = ex_completed
		pob.type = POBJ_NOTHING
		return
	if pob.y >= 19:
		return
	var y: int = pob.y
	for x: int in range(8, 17):
		if GETTILE(x, y, 0) != 169:
			ExplodeTile(x, y, 169)


func ArmThink(pob: PObj) -> void:
	var x: int = pob.x
	var y: int = pob.y
	pob.temp[2] = pob.temp[2] + tics
	if pob.temp[2] >= pob.temp[3]:
		pob.temp[2] -= pob.temp[3]
		# erase the old tiles
		SETTILE(x, y, 0, 169)
		SETTILE(x - 1, y, 0, 169)
		SETTILE(x - 1, y + 1, 0, 169)
		SETTILE(x - 1, y + 2, 0, 169)
		SETTILE(x + 1, y, 0, 169)
		SETTILE(x + 1, y + 1, 0, 169)
		SETTILE(x + 1, y + 2, 0, 169)
		if pob.temp[1] == -1:
			# moving up
			if GETTILE(x, y - 1, 0) != 597:
				pob.temp[1] = 1
				pob.temp[3] = 15
			else:
				y -= 1
				pob.y -= 1
		else:
			# moving down
			if GETTILE(x, y + 3, 0) == 471:
				pob.temp[1] = -1
				pob.temp[3] = 40
			else:
				SETTILE(x, y, 0, 597)
				y += 1
				pob.y += 1
		# place the new tiles
		SETTILE(x, y, 0, 597)
		SETTILE(x - 1, y, 0, 618)
		SETTILE(x - 1, y + 1, 0, 620)
		SETTILE(x - 1, y + 2, 0, 619)
		SETTILE(x + 1, y, 0, 618)
		SETTILE(x + 1, y + 1, 0, 620)
		SETTILE(x + 1, y + 2, 0, 619)


func FootThink(pob: PObj) -> void:
	var x: int = pob.x
	var y: int = pob.y
	pob.temp[2] = pob.temp[2] + tics
	if pob.temp[2] >= 35:
		pob.temp[2] -= 35
		# erase the old tiles
		SETTILE(x, y, 0, 169)
		if pob.temp[3] == -1:
			SETTILE(x - 1, y, 0, 169)
			SETTILE(x - 2, y, 0, 169)
			SETTILE(x - 3, y, 0, 169)
		else:
			SETTILE(x + 1, y, 0, 169)
			SETTILE(x + 2, y, 0, 169)
			SETTILE(x + 3, y, 0, 169)
		if pob.temp[1] == -1:
			# moving up
			if GETTILE(x, y - 1, 0) != 597:
				pob.temp[1] = 1
			else:
				y -= 1
				pob.y -= 1
		else:
			# moving down
			if GETTILE(x, y + 1, 0) == 430:
				# the foot hits the ground
				pob.temp[1] = -1
				PlaySound(SND.FOOTSLAMSND)
				pob.think = &"FootIdle"
				pob.temp[2] = 0
			else:
				SETTILE(x, y, 0, 597)
				y += 1
				pob.y += 1
		# place the new tiles
		if pob.temp[3] == -1:
			SETTILE(x, y, 0, 622)
			SETTILE(x - 1, y, 0, 623)
			SETTILE(x - 2, y, 0, 623)
			SETTILE(x - 3, y, 0, 621)
		else:
			SETTILE(x, y, 0, 621)
			SETTILE(x + 1, y, 0, 623)
			SETTILE(x + 2, y, 0, 623)
			SETTILE(x + 3, y, 0, 622)


func FootIdle(pob: PObj) -> void:
	pob.temp[2] = pob.temp[2] + tics
	if pob.temp[2] > 200:
		pob.temp[2] = 0
		pob.think = &"FootThink"


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


func ShowMessage() -> void:
	pass    # no messages in Keen 3


# ------------------------------------------------------------- the halo

func _halo() -> void:
	if ankhtime != 0 or cheatmode:
		if ankhtime > 250:
			RF_PlaceSprite(objlist[0].x - 8 * PIXGLOBAL, objlist[0].y - 8 * PIXGLOBAL, ((u16(timecount) >> 4) & 1) + S.GODHALOSPR)
		elif ((u16(timecount) >> 4) & 1) != 0:
			RF_PlaceSprite(objlist[0].x - 8 * PIXGLOBAL, objlist[0].y - 8 * PIXGLOBAL, ((u16(timecount) >> 5) & 1) + S.GODHALOSPR)
		ankhtime -= tics
		if ankhtime < 0:
			ankhtime = 0


# ----------------------------------------------------------- boss intro

func KeenWindow(width: int, height: int) -> void:
	var xl: int = screencenterx - width / 2
	var yl: int = 20 - height / 2
	DrawWindow(xl, yl, xl + width + 1, yl + height + 1)


func MortWindow(width: int, height: int) -> void:
	var xl: int = screencenterx - width / 2
	var yl: int = 18 - height / 2
	DrawWindow(xl, yl, xl + width + 1, yl + height + 1)


func BossDelay(vbls: int) -> bool:
	for i: int in range(vbls):
		WaitVBL(1)
		var key: int = NoBiosKey(1) & 0xFF
		if key == CHAR_ESCAPE or key == 32 or JoyButton() != 0 or exited:
			ClearKeys()
			ctrl2.button1 = true
			ctrl2.button2 = true
			return true
	return false


func BossTypeText(text: String) -> bool:
	for i: int in range(text.length()):
		Print(text[i])
		WaitVBL(6)
		var key: int = NoBiosKey(1) & 0xFF
		if key == CHAR_ESCAPE or key == 32 or JoyButton() != 0 or exited:
			ClearKeys()
			return true
	return false


## BossLevelIntro: each window is typed, held, then refreshed away; a key
## or button cuts the whole thing short.
func _boss_intro() -> void:
	sparksgone = 0
	PlaySound(SND.MORTIMERSND)
	PlaySound(SND.DOOROPENSND)    # only one plays, by priority
	WaitEndSound()
	var script: Array = [
		[&"KeenWindow", 5, 1, ["No..."], 180],
		[&"KeenWindow", 12, 1, ["It can't be!"], 180],
		[&"KeenWindow", 18, 1, ["MORTIMER McMIRE!!!"], 240],
		[&"KeenWindow", 38, 5, ["Mortimer has been a thorn in your side\n",
			"for as long as you can remember.  Your\n",
			"IQ test score was 314--Mortimer's was\n",
			"315.  He always held that over you,\n",
			"never letting you forget for one day.\n"], 240],
		[&"KeenWindow", 38, 5, ["All the practical jokes, the mental\n",
			"cruelty, the swirlies--each memory\n",
			"makes your teeth grit harder.  And now\n",
			"he's out to destroy earth!  You have\n",
			"had enough!\n"], 240],
		[&"KeenWindow", 31, 2, ["\"ALL RIGHT MORTIMER, WHAT'S THE\n",
			"PROBLEM?  WHY DESTROY EARTH?\"\n"], 180],
		[&"MortWindow", 35, 4, ["\"You and all those mental wimps\n",
			"deserve to die!  I'm the smartest\n",
			"person in the galaxy.  Aren't I,\n",
			"mister THREE FOURTEEN! Ah ha ha!\""], 180],
		[&"KeenWindow", 34, 1, ["\"I'll get you for that, Mortimer!\""], 180],
		[&"MortWindow", 38, 3, ["\"Come and try!  You'll never get past\n",
			"my hideous Mangling Machine!  Prepare\n",
			"to die, Commander Clown!\""], 240],
	]
	var first: bool = true
	for step: Array in script:
		if first:
			call(step[0], step[1], step[2])
			RF_ForceRefresh()
			first = false
		else:
			RF_ForceRefresh()
			call(step[0], step[1], step[2])
		for line: String in step[3]:
			if BossTypeText(line):
				RF_Refresh()
				return
		if BossDelay(step[4]):
			RF_Refresh()
			return
		RF_Refresh()


# ---------------------------------------------------------------- finale

func PhotoFlash() -> void:
	_set_palette([0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
		0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 3])
	PlaySound(SND.CLICKSND)
	WaitEndSound()
	WaitVBL(2)
	_set_palette(colors[3])


func _take_photo(x: int, y: int, t1: int, t2: int, delay: int) -> void:
	SETTILE(x, y, 0, t1)
	RF_Refresh()
	PhotoFlash()
	SETTILE(x, y, 0, t2)
	RF_Refresh()
	WaitVBL(delay)


func _finale_other() -> void:
	ReadLevel(ENDINGMAP)
	originx = 2 * TILEGLOBAL
	originy = 2 * TILEGLOBAL
	RF_Clear()
	RF_ForceRefresh()
	RF_PlaceSprite(224 * PIXGLOBAL, 96 * PIXGLOBAL, S.GRUNTRIGHT1SPR)
	RF_PlaceSprite(248 * PIXGLOBAL, 104 * PIXGLOBAL, S.KEENWALKR1SPR)
	RF_Refresh()
	FadeIn()
	DrawWindow(4, 18, 43, 23)
	TypeText("With Mortimer McMire out of the       \n")
	TypeText("picture, and his brain-wave belts no\n")
	TypeText("longer controlling them, the Vorticons\n")
	TypeText("are freed of their mental enslavement.\n")
	WaitVBL(120)
	RF_ForceRefresh()
	RF_Refresh()
	DrawWindow(4, 18, 43, 22)
	TypeText("\"Commander Keen, in honor of your     \n")
	TypeText("meritorious service in freeing us from\n")
	TypeText("the Grand Intellect's mental chains,\"\n")
	WaitVBL(120)
	RF_ForceRefresh()
	RF_Refresh()
	DrawWindow(4, 18, 43, 22)
	TypeText("\"I and the other Vorticons you haven't\n")
	TypeText("slaughtered want to award you the     \n")
	TypeText("Big V, our highest honor.\"\n")
	WaitVBL(120)
	RF_ForceRefresh()
	RF_Refresh()
	DrawWindow(17, 18, 30, 20)
	TypeText("\"Thank you!\"\n")
	WaitVBL(120)
	_take_photo(19, 5, 58, 72, 20)
	_take_photo(3, 8, 60, 61, 10)
	_take_photo(5, 8, 60, 61, 5)
	_take_photo(20, 5, 58, 72, 10)
	_take_photo(8, 8, 60, 61, 15)
	WaitVBL(120)
	FadeOut()
	originx &= 0xFFFF000    # the original's mask (28 bits), as written
	RF_Refresh()
	DrawPicFile("finale.ck3")
	FadeIn()
	ReadLevel(ENDINGMAP)    # DrawPicFile trashed the level
	originx = 2 * TILEGLOBAL
	originy = 2 * TILEGLOBAL
	WaitVBL(400)
	DrawWindow(18, 20, 29, 24)
	TypeText("The End...\n For now!\n")
	Print("    ")
	ClearKeys()
	Get()
	originx = TILE_ALIGN(originx)
	RF_ForceRefresh()
	RF_Refresh()
	RF_Refresh()
	DrawTextScreen(endtextPtr, 0, 22)
	PlaySound(SND.KEENSLEFTSND)
	WaitEndSound()
	PlaySound(SND.MORTIMERSND)
	ShowText(endtextPtr, 0, 22)
	RF_ForceRefresh()


# ------------------------------------------- the common code's hooks

func KeenContact(ob: Obj, hit: Obj) -> void:
	match hit.obclass:
		ballobj, platformobj:
			RideObj(ob, hit)
		youthobj:
			if ob.think == &"KeenFrozen" or cheatmode or ankhtime != 0:
				return
			ob.think = &"KeenFrozen"
			ob.xspeed = hit.xspeed
			ob.yspeed = hit.yspeed
			ob.temp1 = 400    # stunned for about 2.8 seconds
		womanobj, meepobj:
			PushObj(ob, hit)
		gruntobj, ninjaobj, jackobj, enemyshotobj, meepwaveobj:
			HurtKeen()


func _always_active(ob: Obj) -> bool:
	return ob.obclass == platformobj


# ------------------------------------------------------------- the map

func _spawn_messie() -> void:
	# a Messie path in the middle of a map row is where Messie starts
	@warning_ignore("integer_division")
	var mid: int = mapwwide / 2
	for y: int in range(mapheight):
		if GETTILE(mid, y, 1) == 0x2000:
			messiecooldown = 0
			messiestate = 0
			messieoldtilex = mid
			messieoldtiley = y
			messiexmove = -MESSIESPEED * PIXGLOBAL
			messieymove = 0
			messiex = TILE_TO_GLOBAL(messieoldtilex)
			messiey = TILE_TO_GLOBAL(messieoldtiley)
			messieshape = S.MESSIELD1SPR
			messiecount = MESSIEMOVES
			break


func _update_messie(keen: Obj) -> void:
	var xspeeds: PackedInt32Array = [-MESSIESPEED, 0, MESSIESPEED, -MESSIESPEED, 0, MESSIESPEED, -MESSIESPEED, 0, MESSIESPEED]
	var yspeeds: PackedInt32Array = [-MESSIESPEED, -MESSIESPEED, -MESSIESPEED, 0, 0, 0, MESSIESPEED, MESSIESPEED, MESSIESPEED]
	var messieshapes: PackedInt32Array = [S.MESSIEUL1SPR, S.MESSIEUL1SPR, S.MESSIEUR1SPR,
		S.MESSIELD1SPR, S.MESSIELD1SPR, S.MESSIERD1SPR, S.MESSIELD1SPR, S.MESSIERD1SPR, S.MESSIERD1SPR]
	var kessieshapes: PackedInt32Array = [S.KESSIEUL1SPR, S.KESSIEUL1SPR, S.KESSIEUR1SPR,
		S.KESSIELD1SPR, S.KESSIELD1SPR, S.KESSIERD1SPR, S.KESSIELD1SPR, S.KESSIERD1SPR, S.KESSIERD1SPR]
	if messiecount <= MESSIEMOVES:
		messiex += messiexmove
		messiey += messieymove
	# the sprite for the state and direction
	for x: int in range(9):
		if (xspeeds[x] << G_P_SHIFT) == messiexmove and (yspeeds[x] << G_P_SHIFT) == messieymove:
			messieshape = messieshapes[x] if messiestate == 0 else kessieshapes[x]
			break
	messiecount -= 1
	if messiecount == 0:
		messiecount = MESSIEMOVES    # on to the next tile
		@warning_ignore("integer_division")
		var tx: int = messiex / TILEGLOBAL
		@warning_ignore("integer_division")
		var ty: int = messiey / TILEGLOBAL
		var done: bool = false
		for x: int in range(tx - 1, tx + 2):
			for y: int in range(ty - 1, ty + 2):
				var infoval: int = GETTILE(x, y, 1)
				if (infoval == 0x2100 or infoval == 0x2000) and (x != tx or y != ty) \
						and (x != messieoldtilex or y != messieoldtiley):
					if x < tx:
						messiexmove = -MESSIESPEED * PIXGLOBAL
					elif x > tx:
						messiexmove = MESSIESPEED * PIXGLOBAL
					else:
						messiexmove = 0
					if y < ty:
						messieymove = -MESSIESPEED * PIXGLOBAL
					elif y > ty:
						messieymove = MESSIESPEED * PIXGLOBAL
					else:
						messieymove = 0
					messieoldtilex = tx
					messieoldtiley = ty
					if infoval == 0x2100:
						messiecount = 130    # a seaweed spot: stop for a while
					done = true
					break
			if done:
				break
	if messiestate != 0:
		# Keen rides: a shore in the direction pressed lets him off
		var dirtilex: PackedInt32Array = [0, 1, 1, 1, 0, -1, -1, -1]
		var dirtiley: PackedInt32Array = [-1, -1, 0, 1, 1, 1, 0, -1]
		var ctrl: Dictionary = ControlPlayer(1)
		# BUG in the original: with no direction pressed it reads past the
		# tables (a stack word), landing on a tile that is never a shore; the
		# port skips the check then.
		@warning_ignore("integer_division")
		if ctrl.dir < 8 and GETTILE(messiex / TILEGLOBAL + dirtilex[ctrl.dir], messiey / TILEGLOBAL + dirtiley[ctrl.dir], 1) == 0x2200:
			messiestate = 0
			keen.x = messiex + TILE_TO_GLOBAL(dirtilex[ctrl.dir])
			keen.y = messiey + TILE_TO_GLOBAL(dirtiley[ctrl.dir])
			messiecooldown = 30
		if messiexmove > 0 and messiex - originx > 11 * TILEGLOBAL:
			originx += messiexmove
			if originx > originxmax:
				originx = originxmax
		elif messiexmove < 0 and messiex - originx < 9 * TILEGLOBAL:
			originx += messiexmove
			if originx < originxmin:
				originx = originxmin
		if messieymove > 0 and messiey - originy > 7 * TILEGLOBAL:
			originy += messieymove
			if originy > originymax:
				originy = originymax
		elif messieymove < 0 and messiey - originy < 3 * TILEGLOBAL:
			originy += messieymove
			if originy < originymin:
				originy = originymin


func _place_messie(anim: int) -> void:
	@warning_ignore("integer_division")
	RF_PlaceSprite(messiex, messiey, messieshape + (anim & 2) / 2)


func _messie_touch(ob: Obj) -> void:
	if messiestate != 0:
		return
	if messiecooldown == 0:
		# Keen touching Messie's sprite box boards it (the original checks the
		# sprite's size, not the hitboxes)
		var w: int = spritetable[S.MESSIELD1SPR * 4].w
		var h: int = spritetable[S.MESSIELD1SPR * 4].h
		if ob.x >= messiex and messiex + PIXEL_TO_GLOBAL(w * 8) >= ob.x \
				and ob.y >= messiey and ob.y <= messiey + (h << G_P_SHIFT):
			PlaySound(SND.CRYSTALSND)
			messiestate += 1
			messiecooldown = 30
	else:
		messiecooldown -= 1


func _clear_warps() -> void:
	for i: int in range(NUMWARPS):
		warps[i][2] = 0    # set but never used in Keen 3


func _note_warp(infoval: int, x: int, y: int) -> void:
	var index: int = (infoval & 0xF0) >> 4
	warps[index][2] = infoval & 0xF
	warps[index][0] = x
	warps[index][1] = y


func _check_map_tiles_other(num: int, ob: Obj, _spotX: int, _spotY: int) -> bool:
	if num == 20:
		var message: int = Rnd(3)
		ExpWin(32, 6)
		var y: int = sy
		match message:
			0:
				Print("You enter your ship, sit around\n")
				Print("for a while, get bored, then\n")
				Print("remember that you have to find\n")
				Print("the Grand Intellect!")
			1:
				Print("Into the ship you journey, lie\n")
				Print("about a bit, then resume your\n")
				Print("quest for the Grand Intellect!")
			2:
				Print("You feel like entering the ship\n")
				Print("and taking a rest, but the\n")
				Print("mystery of the Grand Intellect's\n")
				Print("identity changes your mind.")
			3:
				Print("Entering the ship might be a\n")
				Print("fun thing to do, but right now,\n")
				Print("you need to find the Grand\n")
				Print("Intellect and vanquish him!")
		sy = y + 4
		Print("\n         press a ")
		if playermode[1] == keyboard:
			Print("key:")
		else:
			Print("button:")
		ClearKeys()
		Ack()
		ClearKeys()
		RF_ForceRefresh()
		return true
	if (num & 0xFF00) >= 0x2000 and (num & 0xFF00) <= 0x2200:
		return true    # Messie's paths: no level here
	if (num & 0xF00) == 0xF00:
		# a teleporter: animate the source, move the screen, animate the
		# destination, put Keen there
		var index: int = (num & 0xF0) >> 4
		var anim: int = teleport_anim0    # uninitialised in the original: the stack's leftover, fitted
		for i: int in range(2):
			PlaySound(SND.TELEPORTSND)
			for tilenum: int in range(130, 134):
				SETTILE(warps[index][0], warps[index][1], 0, tilenum)
				RF_Clear()
				_place_messie(anim)
				RF_Refresh()
				anim += 1
				WaitVBL(4)
		SETTILE(warps[index][0], warps[index][1], 0, 134)
		index = num & 0xF
		if warps[index][0] < 10:
			originx = 2 * TILEGLOBAL
		else:
			originx = TILE_TO_GLOBAL(warps[index][0] - 10)
		if warps[index][1] < 6:
			originy = 2 * TILEGLOBAL
		else:
			originy = TILE_TO_GLOBAL(warps[index][1] - 6)
		# the original leaves ox and oy stale here, so RF_PlaceSprite puts
		# Messie where it would be seen from the old origin
		for i: int in range(2):
			PlaySound(SND.TELEPORTSND)
			for tilenum: int in range(130, 134):
				SETTILE(warps[index][0], warps[index][1], 0, tilenum)
				RF_Clear()
				_place_messie(anim)
				RF_Refresh()
				anim += 1
				WaitVBL(4)
		SETTILE(warps[index][0], warps[index][1], 0, 134)
		ob.x = TILE_TO_GLOBAL(warps[index][0])
		ob.y = TILE_TO_GLOBAL(warps[index][1])
		return true
	return false


# ------------------------------------------- the episode's own screens

func _status_screen_other() -> void:
	ExpWin(28, 11)
	var x: int = sx
	var y: int = sy
	PrintGrey("    SCORE     EXTRA KEEN AT \n")
	sx = x + 12
	PrintGrey(" \n")
	PrintGrey("    KEENS            PISTOL \n")
	for i: int in range(3):
		sx = x + 19
		PrintGrey(" \n")
	PrintGrey(" ANKH TIME      KEY CARDS   \n")
	for i: int in range(3):
		sx = x + 11
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
	DrawTile(x + 21, (y + 3) * 8 + 4, 216)    # raygun
	sx = x + 24
	sy = y + 4
	PrintInt(gamestate.ammo)
	DrawTile(x + 3, (y + 7) * 8 + 4, 214)     # ankh
	sx = x + 7
	sy = y + 8
	@warning_ignore("integer_division")
	PrintInt(ankhtime / 144)    # seconds left
	sx = x + 13
	sy = y + 8
	if gamestate.keys[0]:
		DrawTile(sx, sy * 8 - 4, 217)
	if gamestate.keys[1]:
		DrawTile(sx + 4, sy * 8 - 4, 218)
	if gamestate.keys[2]:
		DrawTile(sx + 8, sy * 8 - 4, 219)
	if gamestate.keys[3]:
		DrawTile(sx + 12, sy * 8 - 4, 220)


func _ordering_screen_other(timed: bool) -> void:
	var foobx: int = 0
	var xspeed: int = 0
	var hidetics: int = 100
	var movetics: int = 0
	var counter: int = 0
	DrawOrderingScreen()
	FadeIn()
	ClearKeys()
	var towait: int = SCREENTIME
	while true:
		var ctrl: Dictionary = ControlPlayer(1)
		RF_Clear()
		var keenx: int = originx + 8 * PIXGLOBAL
		var keeny: int = originy + 176 * PIXGLOBAL
		if movetics == 0 or movetics > 10:
			RF_PlaceSprite(keenx, keeny, S.KEENWALKR1SPR)
		elif xspeed < 0:
			RF_PlaceSprite(keenx, keeny, S.KEENSHOOTRSPR)
		else:
			RF_PlaceSprite(keenx, keeny, S.KEENWALKR1SPR)
		if hidetics != 0:
			hidetics -= 1
			if hidetics == 0:
				foobx = 340 * PIXGLOBAL
				xspeed = -PIXGLOBAL
				movetics = Rnd(175) + 100
		if movetics != 0:
			foobx += xspeed
			@warning_ignore("integer_division")
			var frame: int = (counter & 2) / 2
			if xspeed < 0:
				RF_PlaceSprite(foobx + originx, originy + 184 * PIXGLOBAL, frame + S.FOOBL1SPR)
			else:
				RF_PlaceSprite(foobx + originx, originy + 184 * PIXGLOBAL, frame + S.FOOBR1SPR)
			movetics -= 1
			if movetics == 0:
				if xspeed < 0:
					PlaySound(SND.YORPSCREAMSND)
					RF_Clear()
					RF_PlaceSprite(keenx, keeny, S.KEENSHOOTRSPR)
					RF_PlaceSprite(foobx + originx, originy + 184 * PIXGLOBAL, S.FOOBYELL1SPR)
					RF_Refresh()
					RF_Refresh()
					RF_Clear()
					RF_PlaceSprite(keenx, keeny, S.KEENSHOOTRSPR)
					RF_PlaceSprite(foobx + originx, originy + 184 * PIXGLOBAL, S.FOOBYELL2SPR)
					RF_Refresh()
					RF_Refresh()
					xspeed = 6 * PIXGLOBAL
					@warning_ignore("integer_division")
					movetics = (340 * PIXGLOBAL - foobx) / (6 * PIXGLOBAL)
				else:
					hidetics = Rnd(50) + 10
					xspeed = 0
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
	leftedge = 4
	sx = 4
	sy = 4
	PrintGrey("    Commander Keen: Invasion of the\n")
	PrintGrey("   Vorticons consists of three unique\n")
	PrintGrey("        and challenging episodes:\n\n")
	PrintGrey("   Order the trilogy for $30 and get:\n")
	PrintGrey("  * The \"Secret Hints & Tricks\" sheet\n")
	PrintGrey("  * The special \"cheat mode\" password\n")
	PrintGrey("  * The latest version of each game\n")
	PrintGrey("  * SEVERAL FREE BONUS GAMES!\n\n")
	PrintGrey(" Mail orders to:     U.S funds only;\n")
	PrintGrey(" Apogee Software     checks or M/O's.\n")
	PrintGrey(" P.O. Box 476389     Include $2 postage\n")
	PrintGrey(" Garland, TX 75047   and handling.\n\n")
	PrintGrey("Specify 5.25/3.5 disk size when ordering\n")
	PrintGrey("   Or order toll free: 1-800-852-5659 ")


func _cheat_keeps_going(ob: Obj) -> bool:
	return ob.obclass in [ballobj, platformobj]
