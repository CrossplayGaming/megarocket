# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEEN1ACT.C from K1n9_Duk3's Reconstructed Commander Keen 1-3
# Source Code (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortKeen1
extends VortActs
## Commander Keen 1: Marooned on Mars. The episode's names, its creatures
## (Yorps, Gargs, Vorticons, butler and tank robots, ice cannons, the chain
## that drops the block), the statue messages and the Keensicle.

# classtype for episode 1
const yorpobj: int = 2
const gargobj: int = 3
const vorticonobj: int = 4
const butlerobj: int = 5
const tankobj: int = 6
const classtype_7: int = 7
const chainobj: int = 8
const ep1_volatileobj: int = 9
const ep1_shotobj: int = 10
const ep1_enemyshotobj: int = 11
const icechunkobj: int = 12
const ep1_splashobj: int = 13
const ep1_deadobj: int = 14
const iceballobj: int = 15


func _init() -> void:
	super()
	episode = 1
	P = VortNames1.PICS
	S = VortNames1.sprites()
	SND = VortNames1.sounds()
	volatileobj = ep1_volatileobj
	shotobj = ep1_shotobj
	enemyshotobj = ep1_enemyshotobj
	splashobj = ep1_splashobj
	deadobj = ep1_deadobj
	classes = {"volatileobj": volatileobj, "shotobj": shotobj, "enemyshotobj": enemyshotobj,
		"splashobj": splashobj, "deadobj": deadobj}
	# Processor time the original spends where the port does the work at once,
	# fitted against DOSBox recordings of this game (tools/fit_costs.py):
	# loading the sprites (the "one moment" picture stays 32 refreshes in the
	# recording) and the four text files before the first fade (5 timer tics).
	# (Drawing is charged by instruction count; these are the file work.)
	# Entering the world map: 11.5 ms more than the map's expansion (fitted on
	# the new-game recording: anything from 5 to 18 ms holds the black pause
	# at 20 refreshes; not yet explained by instruction counts).
	costs = {"loadgraphics": 21 * DosMachine.VBL_PERIOD, "demoloop_load": 5 * 8192 * DosMachine.UNIT,
		"worldmap_load": 13721593,
		# each map frame's C code before its refresh (ControlMapKeen, the
		# clipping, placing the sprite, the key checks): 0.16 ms, fitted (0.13-0.19 pass)
		"mapframe": 190909,
		# each level frame's C code before its refresh (the thinks and
		# contacts, placing sprites): 0.28 ms, fitted on the Border Village
		# recording (0.25-0.31 pass)
		"levelframe": 334091}
	# the BIOS tick count when the program reads the DOS clock, the oracle's
	# clock being set to midnight before the game starts (fitted: 22)
	dos_ticks = 22


func LoadLevel(number: int) -> void:
	ReadLevel(number)
	for y: int in range(mapheight):
		for x: int in range(mapwwide):
			match GETTILE(x, y, 1):
				1:
					SpawnYorp(x, y)
				2:
					SpawnGarg(x, y)
				3:
					SpawnVorticon(x, y)
				4:
					SpawnButler(x, y)
				5:
					SpawnTank(x, y)
				6:
					SpawnCannon(x, y, 0)
				7:
					SpawnCannon(x, y, 1)
				8:
					SpawnCannon(x, y, 2)
				9:
					SpawnCannon(x, y, 3)
				10:
					SpawnChain(x, y)
				255:
					objlist[0].x = TILE_TO_GLOBAL(x)
					objlist[0].y = TILE_TO_GLOBAL(y) + 8 * PIXGLOBAL


# ------------------------------------------------------------------ spawns

func SpawnTank(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = tankobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y) + 8 * PIXGLOBAL
	ob.xspeed = 90
	if ob.x < objlist[0].x:
		ob.xspeed = -ob.xspeed
	ob.think = &"TankFall"
	ob.contact = &"TankContact"
	ob.shapenum = S.TANKSTAND1SPR


func SpawnButler(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = butlerobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.xspeed = 90
	if ob.x < objlist[0].x:
		ob.xspeed = -ob.xspeed
	ob.think = &"ButlerWalk"
	ob.contact = &"ButlerContact"
	ob.shapenum = S.CANSTAND1SPR


func SpawnVorticon(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = vorticonobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"VorticonWalk"
	ob.contact = &"VorticonContact"
	ob.health = 3
	if level == 16:
		ob.health = 104
	if ob.x > objlist[0].x:
		ob.xspeed = -90
	else:
		ob.xspeed = 90
	ob.shapenum = S.VORTSTAND1SPR


func SpawnGarg(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = gargobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"GargStand"
	ob.contact = &"GargContact"
	ob.shapenum = S.GARGSTAND1SPR


func SpawnYorp(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = yorpobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y) + 8 * PIXGLOBAL
	ob.think = &"YorpWalk"
	if ob.x < objlist[0].x:
		ob.xspeed = 60
	else:
		ob.xspeed = -60
	ob.contact = &"YorpContact"
	ob.shapenum = S.YORPSTAND1SPR


func SpawnChain(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = chainobj
	ob.x = TILE_TO_GLOBAL(x)
	ob.y = TILE_TO_GLOBAL(y)
	ob.think = &"NullThink"
	ob.contact = &"ChainContact"
	ob.shapenum = S.CHAINSPR


func SpawnCannon(x: int, y: int, num: int) -> void:
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_CANNON
	pob.think = &"CannonThink"
	pob.temp[1] = num
	pob.x = x
	pob.y = y


# ------------------------------------------------------------------- Yorp

func YorpWalk() -> void:
	if obon.yspeed == 0:
		if RndT() < tics:
			obon.yspeed = -Rnd(128)
		elif RndT() < tics:
			obon.think = &"YorpStand"
			obon.temp1 = 0
	if obon.xspeed > 0:
		obon.shapenum = S.YORPRIGHT1SPR
	else:
		obon.shapenum = S.YORPLEFT1SPR
	obon.shapenum = obon.shapenum + ((u16(timecount) >> 4) & 1)
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -60
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 60


func YorpStand() -> void:
	obon.xspeed = 0
	obon.shapenum = ((u16(timecount) >> 5) & 3) + S.YORPSTAND1SPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 200:
		if obon.x < objlist[0].x:
			obon.xspeed = 60
		else:
			obon.xspeed = -60
		obon.think = &"YorpWalk"
	DoGravity()
	MoveObon()


func YorpStunned() -> void:
	obon.shapenum = ((u16(timecount) >> 4) & 1) + S.YORPSTUN1SPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 800:
		obon.temp1 = 0
		obon.think = &"YorpStand"
	obon.xspeed = 0
	DoGravity()
	MoveObon()


func YorpContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj or hit.obclass == enemyshotobj:
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.YORPCORPSE1SPR
		ob.think = &"DyingThink"
		ob.contact = &"NullContact"
		ob.yspeed = -80
		PlaySound(SND.YORPSCREAMSND)


# ------------------------------------------------------------------- Garg

func GargWalk() -> void:
	if obon.yspeed == 0 and obon.xspeed > -220 and obon.xspeed < 220 and RndT() < tics:
		obon.think = &"GargStand"
		obon.temp1 = 0
	if obon.xspeed > 0:
		obon.shapenum = S.GARGRIGHT1SPR
	else:
		obon.shapenum = S.GARGLEFT1SPR
	obon.shapenum = obon.shapenum + ((u16(timecount) >> 4) & 1)
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -60
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 60
	if (block & BLOCK_DOWN) != 0:
		obon.temp1 = 0
	elif absi(obon.xspeed) == 220 and obon.temp1 == 0:
		obon.temp1 = 1
		obon.yspeed = -200


func GargStand() -> void:
	obon.xspeed = 0
	obon.shapenum = ((u16(timecount) >> 5) & 3) + S.GARGSTAND1SPR
	obon.temp1 = obon.temp1 + tics
	DoGravity()
	MoveObon()
	if obon.temp1 >= 80:
		if obon.y + 8 * PIXGLOBAL == objlist[0].y:
			obon.xspeed = 220
		else:
			obon.xspeed = 60
		if obon.x > objlist[0].x:
			obon.xspeed = -obon.xspeed
		obon.think = &"GargWalk"


func GargContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj or hit.obclass == enemyshotobj:
		ob.temp1 = 0
		ob.temp2 = 2
		ob.shapenum = S.GARGCORPSE1SPR
		ob.think = &"DyingThink"
		ob.contact = &"NullContact"
		ob.yspeed = -80
		PlaySound(SND.GARGSCREAMSND)


# --------------------------------------------------------------- Vorticon

func VorticonWalk() -> void:
	if obon.xspeed > 0:
		obon.shapenum = S.VORTRIGHT1SPR
	else:
		obon.shapenum = S.VORTLEFT1SPR
	obon.shapenum = obon.shapenum + ((u16(timecount) >> 4) & 3)
	if RndT() < (tics << 1):
		obon.yspeed = -Rnd(300)
		obon.think = &"VorticonJump"
	elif RndT() < (tics << 1):
		match obon.xspeed:
			-90:
				obon.xspeed = -120
			-120:
				obon.xspeed = -90
			90:
				obon.xspeed = 120
			120:
				obon.xspeed = 90
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -90
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 90


func VorticonJump() -> void:
	if obon.xspeed > 0:
		obon.shapenum = S.VORTJUMPLSPR
	else:
		obon.shapenum = S.VORTJUMPRSPR
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"VorticonStand"
		obon.temp1 = 0
	if (block & BLOCK_RIGHT) != 0:
		obon.xspeed = -90
	if (block & BLOCK_LEFT) != 0:
		obon.xspeed = 90


func VorticonStand() -> void:
	obon.xspeed = 0
	obon.shapenum = ((u16(timecount) >> 5) & 3) + S.VORTSTAND1SPR
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 80:
		obon.xspeed = 90
		if obon.x > objlist[0].x:
			obon.xspeed = -obon.xspeed
		obon.think = &"VorticonWalk"
	DoGravity()
	MoveObon()


func VorticonContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj or hit.obclass == enemyshotobj:
		var h: int = ob.health
		ob.health -= 1
		if h == 0:
			PlaySound(SND.VORTSCREAMSND)
			ob.temp1 = 0
			ob.temp2 = 6
			ob.shapenum = S.VORTDIE1SPR
			ob.contact = &"NullContact"
			ob.think = &"DyingThink"
			var pob: PObj = FindFreePObj()
			pob.type = POBJ_BORDERFLASH
			pob.think = &"BorderFlash"
			pob.temp[1] = 0


# ----------------------------------------------------------------- Butler

func ButlerWalk() -> void:
	# the butler's sprites are mislabeled (left and right swapped)
	if obon.xspeed > 0:
		obon.shapenum = S.CANLEFT1SPR
	else:
		obon.shapenum = S.CANRIGHT1SPR
	obon.shapenum = obon.shapenum + ((u16(timecount) >> 5) & 3)
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) == 0:
		obon.xmove = -obon.xmove * 2
		obon.ymove = 0
		obon.temp2 = -obon.xspeed
		obon.think = &"ButlerStand"
		obon.temp1 = 0
		obon.xspeed = 0
	if (block & BLOCK_RIGHT) != 0:
		obon.temp2 = -90
		obon.think = &"ButlerStand"
		obon.temp1 = 0
		obon.xspeed = 0
	if (block & BLOCK_LEFT) != 0:
		obon.temp2 = 90
		obon.think = &"ButlerStand"
		obon.temp1 = 0
		obon.xspeed = 0


func ButlerStand() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 50:
		obon.think = &"ButlerWalk"
		obon.xspeed = obon.temp2
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.CANSTAND1SPR
	DoGravity()
	MoveObon()


func ButlerContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj:
		ob.temp1 = 0


# ------------------------------------------------------------------- Tank

func TankMove() -> void:
	if obon.xspeed > 0:
		obon.shapenum = S.TANKLEFT1SPR
	else:
		obon.shapenum = S.TANKRIGHT1SPR
	obon.shapenum = obon.shapenum + ((u16(timecount) >> 3) & 3)
	if RndT() < tics:
		obon.think = &"TankFire"
		obon.temp1 = 0
		obon.temp2 = 0
		obon.temp3 = obon.xspeed
		obon.xspeed = 0
	DoGravity()
	var block: int = MoveObon()
	obon.ymove = 0
	obon.yspeed = 0
	if (block & BLOCK_DOWN) == 0:
		if obon.shapenum < S.TANKRIGHT1SPR:
			obon.xmove = tics * -180
			obon.temp2 = -90
		else:
			obon.xmove = tics * 180
			obon.temp2 = 90
		obon.think = &"TankStand"
		obon.temp1 = 0
		obon.xspeed = 0
	else:
		if (block & BLOCK_RIGHT) != 0:
			obon.temp2 = -90
			obon.think = &"TankStand"
			obon.temp1 = 0
			obon.xspeed = 0
		if (block & BLOCK_LEFT) != 0:
			obon.temp2 = 90
			obon.think = &"TankStand"
			obon.temp1 = 0
			obon.xspeed = 0


func TankFall() -> void:
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"TankMove"


func TankStand() -> void:
	obon.temp1 = obon.temp1 + tics
	obon.shapenum = ((u16(timecount) >> 4) & 1) + S.TANKSTAND1SPR
	if obon.temp1 > 50:
		obon.think = &"TankMove"
		obon.xspeed = obon.temp2


func TankFire() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp2 == 0 and obon.temp1 > 80:
		PlaySound(SND.TANKFIRESND)
		var speed: int = 350
		if obon.temp3 < 0:
			speed = -350
		SpawnEnemyShot(obon.x, obon.y, speed)
		obon.temp2 = 1
	if obon.temp1 > 120:
		obon.temp2 = 90
		if obon.x > objlist[0].x:
			obon.temp2 = -90
		obon.temp1 = 0
		obon.think = &"TankStand"


func TankContact(_ob: Obj, _hit: Obj) -> void:
	pass


# ------------------------------------------------------------ cannon, ice

func CannonThink(pob: PObj) -> void:
	if (u16(timecount) >> 7) != pob.temp[2]:
		pob.temp[2] = u16(timecount) >> 7
		var x: int = pob.x
		var y: int = pob.y
		if ox - 4 < x and oy - 4 < y and ox + 24 > x and oy + 14 > y:
			PlaySound(SND.CANNONFIRESND)
			SpawnIceball(TILE_TO_GLOBAL(pob.x), TILE_TO_GLOBAL(pob.y), pob.temp[1])


func SpawnIceball(x: int, y: int, direction: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = iceballobj
	ob.x = x
	ob.y = y
	ob.think = &"IceballThink"
	match direction:
		0:
			ob.x += TILEGLOBAL
			ob.yspeed = -200
			ob.xspeed = 200
		1:
			ob.yspeed = -200
			ob.xspeed = 0
		2:
			ob.yspeed = 200
			ob.xspeed = 0
		3:
			ob.yspeed = -200
			ob.xspeed = -200
	ob.contact = &"IceballContact"
	ob.shapenum = S.ICESHOTSPR


func IcechunkThink() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 60:
		obon.obclass = nothing
	else:
		DoGravity()
		obon.xmove = s16(obon.xmove + obon.xspeed * tics)
		obon.ymove = s16(obon.ymove + obon.yspeed * tics)


func _spawn_chunk(x: int, y: int, xs: int, ys: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = icechunkobj
	ob.think = &"IcechunkThink"
	ob.contact = &"NullContact"
	ob.x = x
	ob.y = y
	ob.xspeed = xs
	ob.yspeed = ys
	ob.shapenum = S.ICECHUNKSPR


func IceballThink() -> void:
	var block: int = MoveObon()
	if block != 0:
		obon.obclass = nothing
		_spawn_chunk(obon.x, obon.y, 300, 300)
		_spawn_chunk(obon.x, obon.y, 300, -300)
		_spawn_chunk(obon.x, obon.y, -300, 300)
		_spawn_chunk(obon.x, obon.y, -300, -300)
		PlaySound(SND.CHUNKSMASHSND)


func IceballContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == keenobj:
		ob.think = &"RemoveThink"


# ------------------------------------------------------------ chain, block

func ChainContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == shotobj:
		ob.think = &"ShotSplash"
		ob.temp1 = 0
		ob.contact = &"NullContact"
		if RndT() > 0x80:
			ob.shapenum = S.SHOTSPLASHRSPR
		else:
			ob.shapenum = S.SHOTSPLASHLSPR
		var pob: PObj = FindFreePObj()
		pob.type = POBJ_BLOCKFALL
		pob.think = &"BlockFall"
		pob.x = GLOBAL_TO_TILE(ob.x)
		pob.y = GLOBAL_TO_TILE(ob.y) + 1
		pob.temp[1] = 0
		# kill the Vorticon: the last one in the list (the original walks
		# down from one past the end, and never ends without one)
		var i: int = mini(numobj, MAXOBJECTS - 1)
		while i > 0 and objlist[i].obclass != vorticonobj:
			i -= 1
		var v: Obj = objlist[i]
		PlaySound(SND.VORTSCREAMSND)
		v.temp1 = 0
		v.temp2 = 6
		v.shapenum = S.VORTDIE1SPR
		v.contact = &"NullContact"
		v.think = &"DyingThink"


func BlockFall(pob: PObj) -> void:
	if u16(timecount) / 32 == pob.temp[2]:
		return
	pob.temp[2] = u16(timecount) / 32
	var x: int = pob.x - 4
	SETTILE(x, pob.y, 0, 155)
	SETTILE(x, pob.y + 1, 0, 476)
	SETTILE(x, pob.y + 2, 0, 489)
	for xx: int in range(pob.x - 3, pob.x + 4):
		SETTILE(xx, pob.y, 0, 155)
		SETTILE(xx, pob.y + 1, 0, 477)
		SETTILE(xx, pob.y + 2, 0, 490)
	x = pob.x + 4
	SETTILE(x, pob.y, 0, 155)
	SETTILE(x, pob.y + 1, 0, 478)
	SETTILE(x, pob.y + 2, 0, 491)
	pob.y += 1
	pob.temp[1] += 1
	if pob.temp[1] == 4:
		pob.type = POBJ_NOTHING


# ------------------------------------------------------- statue messages

func ShowMessage() -> void:
	var oldtime: int = timecount
	CenterWindow(21, 10)
	match level:
		2:
			Print("You hear in your    \n")
			Print("mind:               \n")
			Print("                    \n")
			Print("It is too bad that  \n")
			Print("you cannot read the \n")
			Print("Standard Galactic   \n")
			Print("Alphabet, human.    \n")
		6:
			Print("A message echoes in \n")
			Print("your head:          \n")
			Print("                    \n")
			Print("The teleporter in   \n")
			Print("the ice will send   \n")
			Print("you to the dark side\n")
			Print("of Mars.            \n")
		9:
			Print("A voice buzzes in   \n")
			Print("your mind:          \n")
			Print("                    \n")
			Print("There is a hidden   \n")
			Print("city. Look in the   \n")
			Print("dark area of the    \n")
			Print("city to the south.  \n")
		10:
			Print("You see these words \n")
			Print("in your head:       \n")
			Print("                    \n")
			Print("You will need a     \n")
			Print("raygun in the end,  \n")
			Print("but not to shoot the\n")
			Print("Vorticon...         \n")
		11:
			Print("You hear in your    \n")
			Print("mind:               \n")
			Print("                    \n")
			Print(" GAAARRRRRGG!       \n")
		12:
			Print("A Yorpish whisper   \n")
			Print("says:               \n")
			Print("                    \n")
			Print("Look for dark, hidden\n")
			Print("bricks. You can see \n")
			Print("naught but their    \n")
			Print("upper left corner.  \n")
		15:
			Print("A Yorpy mind-thought\n")
			Print("bellows:            \n")
			Print("                    \n")
			Print("You cannot kill the \n")
			Print("Vorticon Commander  \n")
			Print("directly.           \n")
	sy = screencentery + 5
	PrintC("Press ENTER:")
	ClearKeys()
	while (Get() & 0xFF) != CHAR_ENTER and not exited:
		pass
	RF_ForceRefresh()
	ClearKeys()
	timecount = oldtime


# -------------------------------------------------------------- Keensicle

func KeenFrozen() -> void:
	obon.shapenum = ((u16(timecount) >> 5) & 1) + S.KEENSICLE1SPR
	obon.temp1 = obon.temp1 - tics
	if obon.temp1 < 0:
		obon.shapenum = S.KEENMELTSPR
		if obon.temp1 < -50:
			obon.think = &"KeenWalk"
	DoGravity()
	MoveObon()
	PlayerCheckMapBorders()


# ------------------------------------------------- the common code's hooks

func KeenContact(ob: Obj, hit: Obj) -> void:
	match hit.obclass:
		yorpobj:
			if hit.think == &"YorpStunned":
				return
			if ob.yspeed <= 0 or ob.y + 8 * PIXGLOBAL > hit.y:
				ob.yspeed = 0
				if hit.xspeed > 0:
					ob.xspeed = 240
				else:
					ob.xspeed = -240
				PlaySound(SND.YORPBUMPSND)
			else:
				hit.think = &"YorpStunned"
				hit.temp1 = 0
				ob.yspeed = 0
				ob.think = &"KeenWalk"
				PlaySound(SND.YORPBOPSND)
		butlerobj, tankobj:
			ob.yspeed = 0
			if hit.xspeed > 0:
				ob.xspeed = 240
			else:
				ob.xspeed = -240
			PlaySound(SND.YORPBUMPSND)
		gargobj, vorticonobj, enemyshotobj:
			if hit.obclass == enemyshotobj and ob.think == &"KeenFrozen":
				ob.temp1 = 0
			else:
				HurtKeen()
		iceballobj:
			ob.think = &"KeenFrozen"
			ob.xspeed = hit.xspeed
			ob.yspeed = hit.yspeed
			ob.temp1 = 800
			PlaySound(SND.KEENSICLESND)


func _shot_passes(hit: Obj) -> bool:
	return hit.obclass == tankobj


func _reactivate() -> void:
	if obon.think == &"YorpStunned":
		obon.think = &"YorpStand"
		obon.temp1 = 0


func _lose_items(currentlevel: int) -> void:
	match currentlevel:
		3:
			gamestate.gotBattery = false
		4:
			gamestate.gotJoystick = false
		8:
			gamestate.gotVacuum = false
		16:
			gamestate.gotEverclear = false
