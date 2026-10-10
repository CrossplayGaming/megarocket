# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of KEENACTS.C from K1n9_Duk3's Reconstructed Commander Keen 1-3
# Source Code (Copyright (C) 2021-2026 K1n9_Duk3), GPL v2 or later.
class_name VortActs
extends VortDemo
## The Vorticons engine's actors: the object lists, movement and clipping
## against the map, Keen's walking, jumping, pogo, shooting, dying and the
## tiles he touches, doors, bridges and switches, shots, and the level loop.
## The episodes' own creatures follow in their classes.

const itemScores: PackedInt32Array = [500, 100, 200, 1000, 5000]

var obon: Obj = Obj.new()
var ctrl: Dictionary = {"dir": nodir, "button1": false, "button2": false}
var ctrl2: Dictionary = {"dir": nodir, "button1": false, "button2": false}
var pobjlist: Array[PObj] = []
var pobjcount: int = 0
var switchxtile: int = 0
var switchytile: int = 0
var lightson: bool = false
var sparksgone: int = 0
var buttontouched: bool = false

# episode-specific class numbers the common code needs
var volatileobj: int = 0
var shotobj: int = 0
var enemyshotobj: int = 0
var splashobj: int = 0
var deadobj: int = 0


func _init() -> void:
	super()
	for i: int in range(MAXPOBJECTS):
		pobjlist.append(PObj.new())


# ------------------------------------------------------------- objects

func DoorThink(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	var y: int = pob.temp[1] / 5
	if y > 32:
		y = 32
		pob.type = POBJ_NOTHING
	RF_PlaceTile(pob.x, pob.y + y * PIXGLOBAL, pob.temp[4])
	RF_PlaceTile(pob.x, pob.y + y * PIXGLOBAL + TILEGLOBAL, pob.temp[4] + 1)
	RF_PlaceTile(pob.x, pob.y + 2 * TILEGLOBAL, pob.temp[3])
	RF_PlaceTile(pob.x, pob.y + 3 * TILEGLOBAL, pob.temp[2])


func OpenDoor(x: int, y: int) -> void:
	PlaySound(SND.DOOROPENSND)
	var tiletype1: int = intile[GETTILE(x, y, 0)]
	var tiletype2: int = intile[GETTILE(x, y - 1, 0)]
	var ty: int = y - 1 if tiletype2 == tiletype1 else y
	var pob: PObj = FindFreePObj()
	pob.type = POBJ_OPENDOOR
	pob.think = &"DoorThink"
	pob.x = TILE_TO_GLOBAL(x)
	pob.y = TILE_TO_GLOBAL(ty)
	pob.temp[1] = 0
	pob.temp[2] = GETTILE(x, ty + 3, 0)
	pob.temp[3] = GETTILE(x, ty + 2, 0)
	pob.temp[4] = GETTILE(x, ty, 0)
	gamestate.keys[tiletype1 - 2] = false
	if episode != 3:
		SETTILE(x, ty, 0, 143)
		SETTILE(x, ty + 1, 0, 143)
	else:
		tiletype1 = GETTILE(x - 1, ty, 0)
		SETTILE(x, ty, 0, tiletype1)
		SETTILE(x, ty + 1, 0, tiletype1)


func RemoveThink() -> void:
	obon.obclass = nothing


func BadThink() -> void:
	Quit("Bad think pointer!")


func BadContact(_ob: Obj, _hit: Obj) -> void:
	Quit("Bad contact pointer!")


func FindFreeObj() -> Obj:
	var i: int = 1
	while i < numobj and objlist[i].obclass != nothing:
		i += 1
	if i >= numobj:
		numobj += 1
	if i >= MAXOBJECTS:
		i = MAXOBJECTS - 1    # the original corrupts memory here
	var ob: Obj = objlist[i]
	ob.clear()
	ob.think = &"BadThink"
	ob.contact = &"BadContact"
	ob.active = true
	return ob


func FindFreePObj() -> PObj:
	var i: int = 0
	while i < pobjcount and pobjlist[i].type != POBJ_NOTHING:
		i += 1
	if i >= pobjcount:
		pobjcount += 1
	if i >= MAXPOBJECTS:
		i = MAXPOBJECTS - 1
	var pob: PObj = pobjlist[i]
	pob.clear()
	pob.think = &"BadThink"
	return pob


func ObjectsCollide(ob1: Obj, ob2: Obj) -> bool:
	if ob1.left == 0 or ob2.left == 0:
		return false
	if ob1.right < ob2.left:
		return false
	if ob1.bottom < ob2.top:
		return false
	if ob1.left > ob2.right:
		return false
	if ob1.top > ob2.bottom:
		return false
	return true


func UpdateObonHitbox() -> void:
	UpdateObjHitbox(obon)


func AccelerateX(amount: int) -> void:
	for i: int in range(1, tics + 1):
		obon.xspeed += amount
		if obon.xspeed > 120:
			obon.xspeed = 120
		elif obon.xspeed < -120:
			obon.xspeed = -120
		if i != tics:
			obon.xmove += obon.xspeed


func AccelerateY(max_speed: int, amount: int) -> void:
	for i: int in range(1, tics + 1):
		obon.yspeed += amount
		if obon.yspeed > max_speed:
			obon.yspeed = max_speed
		elif obon.yspeed < -max_speed:
			obon.yspeed = -max_speed
		if i != tics:
			obon.ymove += obon.yspeed


func DoGravity() -> void:
	for i: int in range(1, tics + 1):
		obon.yspeed += 3
		if obon.yspeed > 200:
			obon.yspeed = 200
		elif obon.yspeed < -400:
			obon.yspeed = -400
		if i != tics:
			obon.ymove += obon.yspeed


func MoveObon() -> int:
	obon.xmove = s16(obon.xmove + obon.xspeed * tics)
	obon.ymove = s16(obon.ymove + obon.yspeed * tics)
	return ClipMoveObon()


func ClipMoveObon() -> int:
	var result: int = BLOCK_NONE
	if obon.xmove > 15 * PIXGLOBAL:
		obon.xmove = 15 * PIXGLOBAL
	elif obon.xmove < -15 * PIXGLOBAL:
		obon.xmove = -15 * PIXGLOBAL
	if obon.ymove > 15 * PIXGLOBAL:
		obon.ymove = 15 * PIXGLOBAL
	elif obon.ymove < -15 * PIXGLOBAL:
		obon.ymove = -15 * PIXGLOBAL
	if cheat_noClip and obon.obclass == keenobj:
		obon.bottom += obon.ymove
		obon.top += obon.ymove
		return result
	obon.bottom += obon.ymove
	obon.top += obon.ymove
	var tileleft: int = GLOBAL_TO_TILE(obon.left)
	var tileright: int = GLOBAL_TO_TILE(obon.right)
	var tiletop: int
	var tilebottom: int
	var extra: int
	if obon.ymove > 0:
		if GLOBAL_TO_TILE(obon.bottom) != GLOBAL_TO_TILE(obon.bottom - obon.ymove):
			tilebottom = GLOBAL_TO_TILE(obon.bottom)
			for x: int in range(tileleft, tileright + 1):
				if northwall[GETTILE(x, tilebottom, 0)] != 0:
					obon.yspeed = 0
					extra = (obon.bottom + 1) % TILEGLOBAL
					obon.ymove -= extra
					obon.top -= extra
					obon.bottom -= extra
					result = BLOCK_DOWN
					break
	elif obon.ymove < 0:
		if GLOBAL_TO_TILE(obon.top) != GLOBAL_TO_TILE(obon.top - obon.ymove):
			tiletop = GLOBAL_TO_TILE(obon.top)
			for x: int in range(tileleft, tileright + 1):
				if southwall[GETTILE(x, tiletop, 0)] != 0:
					obon.yspeed = 0
					extra = TILEGLOBAL - obon.top % TILEGLOBAL
					obon.ymove += extra
					obon.top += extra
					obon.bottom += extra
					result = BLOCK_UP
					break
	obon.left += obon.xmove
	obon.right += obon.xmove
	tiletop = GLOBAL_TO_TILE(obon.top)
	tilebottom = GLOBAL_TO_TILE(obon.bottom)
	if obon.xmove > 0:
		if GLOBAL_TO_TILE(obon.right) != GLOBAL_TO_TILE(obon.right - obon.xmove):
			tileright = GLOBAL_TO_TILE(obon.right)
			for y: int in range(tiletop, tilebottom + 1):
				if westwall[GETTILE(tileright, y, 0)] != 0:
					obon.xspeed = 0
					extra = (obon.right + 1) % TILEGLOBAL
					obon.xmove -= extra
					obon.left -= extra
					obon.right -= extra
					result |= BLOCK_RIGHT
					break
	elif obon.xmove < 0:
		if GLOBAL_TO_TILE(obon.left) != GLOBAL_TO_TILE(obon.left - obon.xmove):
			tileleft = GLOBAL_TO_TILE(obon.left)
			for y: int in range(tiletop, tilebottom + 1):
				if eastwall[GETTILE(tileleft, y, 0)] != 0:
					obon.xspeed = 0
					extra = TILEGLOBAL - obon.left % TILEGLOBAL
					obon.xmove += extra
					obon.left += extra
					obon.right += extra
					result |= BLOCK_LEFT
					break
	return result


func RideObj(ob: Obj, plat: Obj) -> void:
	obon.copy_from(ob)
	var dxmove: int
	var xinto: int
	var dymove: int
	var yinto: int
	if plat.x < obon.x:
		dxmove = plat.xmove - obon.xmove + 2
		xinto = plat.right - obon.left + 1
	else:
		dxmove = obon.xmove - plat.xmove + 2
		xinto = obon.right - plat.left + 1
	if plat.y < obon.y:
		dymove = plat.ymove - obon.ymove + 2
		yinto = plat.bottom - obon.top + 1
	else:
		dymove = obon.ymove - plat.ymove + 2
		yinto = obon.bottom - plat.top + 1
	obon.xmove = 0
	obon.ymove = 0
	if dymove >= yinto:
		if plat.y > obon.y:
			obon.xmove = plat.xmove
			obon.ymove = -yinto - PIXGLOBAL / 2
			if obon.think == &"KeenJump":
				obon.think = &"KeenWalk"
			elif obon.think == &"KeenPogoAir":
				obon.think = &"KeenPogoGround"
				obon.temp1 = 0
				obon.temp2 = obon.xspeed
				obon.xspeed = 0
			obon.temp4 = 1
			obon.yspeed = plat.yspeed
			if obon.yspeed < 0:
				obon.yspeed /= 2
		else:
			obon.ymove = yinto
			if plat.yspeed > obon.yspeed:
				obon.yspeed = plat.yspeed
	else:
		if plat.x > obon.x:
			obon.xmove = -xinto
			if plat.xspeed < obon.xspeed:
				obon.xspeed = plat.xspeed
		else:
			obon.xmove = xinto
			if plat.xspeed > obon.xspeed:
				obon.xspeed = plat.xspeed
	ClipMoveObon()
	obon.x += obon.xmove
	obon.y += obon.ymove
	UpdateObonHitbox()
	ob.copy_from(obon)
	ScrollScreen()


func PushObj(ob: Obj, solid: Obj) -> void:
	obon.copy_from(ob)
	if (obon.right + obon.left) / 2 < (solid.left + solid.right) / 2:
		obon.xmove = -(obon.right - solid.left + 1)
		if obon.xmove > 120:
			obon.ymove = 120    # the original's bug: ymove, not xmove
	else:
		obon.xmove = solid.right - obon.left + 1
		if obon.xmove < -120:
			obon.ymove = -120
	ClipMoveObon()
	obon.x += obon.xmove
	obon.y += obon.ymove
	UpdateObonHitbox()
	ob.copy_from(obon)
	ScrollScreen()


func RemoveInactive() -> bool:
	var tx: int = GLOBAL_TO_TILE(obon.x)
	var ty: int = GLOBAL_TO_TILE(obon.y)
	if obon.y < 0:
		obon.y = 0
	if obon.x > monxmax or obon.x < 0 or obon.y > monymax:
		obon.obclass = nothing
		return true
	if ox - 8 > tx or oy - 8 > ty or ox + 28 < tx or oy + 18 < ty:
		if obon.obclass < volatileobj:
			obon.active = false
		else:
			obon.obclass = nothing
		return true
	return false


func NullThink() -> void:
	pass


func NullContact(_ob: Obj, _hit: Obj) -> void:
	pass


func NullPThink(_pob: PObj) -> void:
	pass


func PlayerCheckMapBorders() -> void:
	if originxmin + 8 > obon.x:
		obon.xspeed = 0
		obon.xmove = 0
		obon.x = originxmin + 8
	elif obon.x > playerxmax:
		obon.xspeed = 0
		obon.xmove = 0
		obon.x = playerxmax
	if obon.y < originymin:
		obon.yspeed = 0
		obon.ymove = 0
		obon.y = originymin
	elif obon.y > playerymax:
		PlaySound(SND.PLUMMETSND)
		WaitEndSound()
		KillKeen()


func ScrollScreen() -> void:
	var keen: Obj = objlist[0]
	if keen.think == &"KeenExit" or keen.think == &"KeenDead":
		return
	var x: int = keen.x
	var y: int = keen.y
	var xmove: int = keen.xmove
	var ymove: int = keen.ymove
	if xmove > 0 and x - originx > 11 * TILEGLOBAL:
		originx += xmove
		if originx > originxmax:
			originx = originxmax
	elif xmove < 0 and x - originx < 9 * TILEGLOBAL:
		originx += xmove
		if originx < originxmin:
			originx = originxmin
	if ymove > 0 and y - originy > 7 * TILEGLOBAL:
		originy += ymove
		if originy > originymax:
			originy = originymax
	elif ymove < 0 and y - originy < 3 * TILEGLOBAL:
		originy += ymove
		if originy < originymin:
			originy = originymin


func TurnLightsOn() -> void:
	lightson = true
	WaitVBL(1)
	_set_palette(colors[3])


func TurnLightsOff() -> void:
	lightson = false
	WaitVBL(1)
	_set_palette(colors[1])


func ToggleSwitch() -> void:
	PlaySound(SND.CLICKSND)
	if GETTILE(switchxtile + 3, switchytile + 5, 0) == 479:
		# a tantalus switch
		var orgx: int = originx
		var orgy: int = originy
		for i: int in range(1, 80):
			RF_Clear()
			originx = orgx - (Rnd(64) - 32) * PIXGLOBAL
			originy = orgy - (Rnd(64) - 32) * PIXGLOBAL
			RF_PlaceSprite(obon.x, obon.y, obon.shapenum)
			RF_Refresh()
		ExpWin(5, 1)
		Print("Oops.")
		WaitVBL(100)
		LevelDone = ex_tantalus
		return
	var tile: int = GETTILE(switchxtile, switchytile, 0)
	match tile:
		480:
			SETTILE(switchxtile, switchytile, 0, 493)
		493:
			SETTILE(switchxtile, switchytile, 0, 480)
		271:
			if lightson:
				TurnLightsOff()
			else:
				TurnLightsOn()
			return
	var infoval: int = GETTILE(switchxtile, switchytile, 1)
	var x: int = infoval & 0xFF
	if x >= 128:
		x -= 256
	var yy: int = infoval >> 8
	if yy >= 128:
		yy -= 256
	var tx: int = switchxtile + x
	var ty: int = switchytile + yy
	var i: int = 0
	while i < pobjcount:
		if pobjlist[i].type != POBJ_NOTHING and pobjlist[i].x == tx and pobjlist[i].y == ty:
			break
		i += 1
	if i < pobjcount:
		if pobjlist[i].think == &"BridgeRemove":
			pobjlist[i].think = &"BridgeCreate"
		else:
			pobjlist[i].think = &"BridgeRemove"
	else:
		var pob: PObj = FindFreePObj()
		pob.type = POBJ_BRIDGE
		pob.think = &"BridgeCreate"
		pob.x = tx
		pob.y = ty
		pob.temp[1] = 0
		if westwall[GETTILE(tx + 1, ty, 0)] != 0:
			pob.temp[2] = -1
		else:
			pob.temp[2] = 1
		pob.temp[3] = GETTILE(tx, ty, 0)
		pob.temp[4] = 0


# ------------------------------------------------------------------ Keen

func _start_jump() -> void:
	obon.temp3 = obon.xspeed
	obon.xspeed = 0
	obon.temp2 = 0
	obon.temp1 = 0
	if lastdir >= 0:
		obon.baseshape = S.KEENJUMPR1SPR
	else:
		obon.baseshape = S.KEENJUMPL1SPR
	obon.think = &"KeenStartJump"


func _start_shoot() -> void:
	obon.think = &"KeenShoot"
	obon.temp1 = 0
	obon.temp2 = 0
	obon.xmove = 0
	if lastdir > 0:
		obon.shapenum = S.KEENSHOOTRSPR
	else:
		obon.shapenum = S.KEENSHOOTLSPR


func KeenWalk() -> void:
	var floor_type: int
	if obon.temp4 != 0:
		floor_type = 1
	else:
		var tileleft: int = GLOBAL_TO_TILE(obon.left)
		var tileright: int = GLOBAL_TO_TILE(obon.right)
		var tilebottom: int = GLOBAL_TO_TILE(obon.bottom) + 1
		floor_type = 1
		for x: int in range(tileleft, tileright + 1):
			var blockDown: int = northwall[GETTILE(x, tilebottom, 0)]
			if blockDown > 1:
				floor_type = blockDown
	if ctrl.button1:
		_start_jump()
	if floor_type < 3:
		match ctrl.dir:
			northeast, east, southeast:
				AccelerateX(2)
				if obon.xspeed < 0:
					ctrl.dir = nodir
			southwest, west, northwest:
				AccelerateX(-2)
				if obon.xspeed > 0:
					ctrl.dir = nodir
	if floor_type == 1 and ctrl.dir == nodir:
		if obon.xspeed > 0:
			AccelerateX(-3)
			if obon.xspeed < 0:
				obon.xspeed = 0
		elif obon.xspeed < 0:
			AccelerateX(3)
			if obon.xspeed > 0:
				obon.xspeed = 0
	if floor_type == 3:
		if lastdir > 0:
			obon.xspeed = 180
		elif lastdir < 0:
			obon.xspeed = -180
	if obon.xspeed == 0:
		if lastdir >= 0:
			obon.shapenum = S.KEENWALKR1SPR
		else:
			obon.shapenum = S.KEENWALKL1SPR
	else:
		if obon.xspeed > 0:
			obon.shapenum = S.KEENWALKR1SPR
			if floor_type < 3:
				obon.shapenum = obon.shapenum + ((u16(timecount) >> 4) & 3)
			lastdir = obon.xspeed
		else:
			obon.shapenum = S.KEENWALKL1SPR
			if floor_type < 3:
				obon.shapenum = obon.shapenum + ((u16(timecount) >> 4) & 3)
			lastdir = obon.xspeed
	if obon.xspeed != 0 and ((u16(timecount) >> 4) & 1) != 0 and floor_type < 3:
		if ((u16(timecount) >> 5) & 1) != 0:
			PlaySound(SND.KEENWLK2SND)
		else:
			PlaySound(SND.KEENWALKSND)
	DoGravity()
	var block: int = MoveObon()
	PlayerCheckMapBorders()
	if (block & BLOCK_RIGHT) != 0 or (block & BLOCK_LEFT) != 0:
		if ((u16(timecount) >> 4) & 1) != 0:
			PlaySound(SND.KEENBLOKSND)
	if (block & BLOCK_DOWN) == 0 and obon.temp4 == 0:
		obon.think = &"KeenJump"
		PlaySound(SND.PLUMMETSND)
		return
	if ctrl.button1:
		_start_jump()
	if ctrl.button2 and not ctrl2.button2:
		if buttontouched:
			ToggleSwitch()
		else:
			obon.temp1 = 0
			obon.temp2 = obon.xspeed
			obon.xspeed = 0
			if gamestate.gotPogo:
				obon.think = &"KeenPogoGround"
	if ctrl.button1 and ctrl.button2 and not ctrl2.button1 and not ctrl2.button2:
		_start_shoot()
	if obon.temp4 != 0:
		obon.temp4 -= 1


func KeenStartJump() -> void:
	obon.shapenum = obon.baseshape + obon.temp1 / 6
	if ctrl.button1:
		obon.temp2 = obon.temp2 + tics * 6
	elif obon.temp1 < 12:
		obon.temp1 = 24 - obon.temp1
	match ctrl.dir:
		northeast, east, southeast:
			obon.temp3 = obon.temp3 + tics * 2
			if obon.temp3 > 120:
				obon.temp3 = 120
		southwest, west, northwest:
			obon.temp3 = obon.temp3 - tics * 2
			if obon.temp3 < -120:
				obon.temp3 = -120
	obon.xspeed = 0
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 36:
		obon.think = &"KeenJump"
		obon.yspeed -= obon.temp2
		obon.xspeed = obon.temp3
		PlaySound(SND.KEENJUMPSND)
	DoGravity()
	MoveObon()
	PlayerCheckMapBorders()
	if ctrl.button1 and ctrl.button2:
		_start_shoot()


func KeenJump() -> void:
	match ctrl.dir:
		northeast, east, southeast:
			AccelerateX(2)
			if obon.xspeed < 0:
				ctrl.dir = nodir
		southwest, west, northwest:
			AccelerateX(-2)
			if obon.xspeed > 0:
				ctrl.dir = nodir
	if ctrl.dir == nodir:
		if obon.xspeed > 0:
			AccelerateX(-1)
			if obon.xspeed < 0:
				obon.xspeed = 0
		elif obon.xspeed < 0:
			AccelerateX(1)
			if obon.xspeed > 0:
				obon.xspeed = 0
	if lastdir > 0:
		obon.shapenum = S.KEENJUMPR6SPR
	else:
		obon.shapenum = S.KEENJUMPL6SPR
	if obon.xspeed != 0:
		lastdir = obon.xspeed
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0 or (block & BLOCK_LEFT) != 0:
		if ((u16(timecount) >> 4) & 1) != 0:
			PlaySound(SND.KEENBLOKSND)
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"KeenWalk"
		PlaySound(SND.KEENLANDSND)
		return
	if (block & BLOCK_UP) != 0:
		PlaySound(SND.BUMPHEADSND)
	PlayerCheckMapBorders()
	if ctrl.button2 and not ctrl2.button2:
		if buttontouched:
			ToggleSwitch()
		elif gamestate.gotPogo:
			obon.think = &"KeenPogoAir"
	if ctrl.button1 and ctrl.button2 and not ctrl2.button1 and not ctrl2.button2:
		_start_shoot()


func KeenShoot() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp2 == 0 and obon.temp1 > 1:
		if gamestate.ammo != 0:
			PlaySound(SND.KEENFIRESND)
			if not cheat_infiniteAmmo:
				gamestate.ammo -= 1
			SpawnPlayerShot(obon.x, obon.y)
		else:
			PlaySound(SND.GUNCLICKSND)
		obon.temp2 = 1
	if obon.temp1 > 30 and not ctrl.button1 and not ctrl.button2:
		obon.think = &"KeenWalk"
	if obon.xspeed > 0:
		AccelerateX(-1)
		if obon.xspeed < 0:
			obon.xspeed = 0
	elif obon.xspeed < 0:
		AccelerateX(1)
		if obon.xspeed > 0:
			obon.xspeed = 0
	DoGravity()
	MoveObon()
	PlayerCheckMapBorders()


func KeenPogoAir() -> void:
	ctrl = ControlPlayer(1)
	match ctrl.dir:
		northeast, east, southeast:
			AccelerateX(1)
			if obon.xspeed < 0:
				ctrl.dir = nodir
		southwest, west, northwest:
			AccelerateX(-1)
			if obon.xspeed > 0:
				ctrl.dir = nodir
	if ctrl.button1 and obon.yspeed < 0:
		AccelerateY(200, -1)
	if (cheatmode or cheat_jump) and ctrl.button1:
		obon.yspeed = -200
	if obon.xspeed != 0:
		lastdir = obon.xspeed
	if lastdir >= 0:
		obon.baseshape = S.KEENPOGOR1SPR
	else:
		obon.baseshape = S.KEENPOGOL1SPR
	obon.shapenum = obon.baseshape
	DoGravity()
	var block: int = MoveObon()
	if (block & BLOCK_RIGHT) != 0 or (block & BLOCK_LEFT) != 0:
		if ((u16(timecount) >> 4) & 1) != 0:
			PlaySound(SND.KEENBLOKSND)
	if (block & BLOCK_DOWN) != 0:
		obon.think = &"KeenPogoGround"
		obon.temp1 = 0
		obon.temp2 = obon.xspeed
		obon.xspeed = 0
	if (block & BLOCK_UP) != 0:
		PlaySound(SND.BUMPHEADSND)
	PlayerCheckMapBorders()
	if ctrl.button2 and not ctrl2.button2:
		if buttontouched:
			ToggleSwitch()
		else:
			obon.think = &"KeenJump"
	if ctrl.button1 and ctrl.button2:
		_start_shoot()
	if obon.temp4 != 0:
		obon.temp4 -= 1


func KeenPogoGround() -> void:
	obon.xmove = 0
	obon.xspeed = 0
	obon.shapenum = obon.baseshape + 1
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 22:
		obon.think = &"KeenPogoAir"
		obon.temp4 = 0
		obon.yspeed -= 200
		obon.xspeed = obon.temp2
		PlaySound(SND.KEENJUMPSND)
	if ctrl.button2 and not ctrl2.button2:
		obon.think = &"KeenWalk"
	if ctrl.button1 and ctrl.button2:
		_start_shoot()
	MoveObon()
	obon.temp4 = 0


func KeenExit() -> void:
	var tx: int = obon.temp1
	var ty: int = obon.temp2
	obon.xmove = tics * 60
	obon.shapenum = ((u16(timecount) >> 4) & 3) + S.KEENWALKR1SPR
	lastdir = obon.xspeed
	if episode != 3:
		RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty), 160)
		RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty + 1), 160)
		RF_PlaceTile(TILE_TO_GLOBAL(tx + 1), TILE_TO_GLOBAL(ty), 143)
		RF_PlaceTile(TILE_TO_GLOBAL(tx + 1), TILE_TO_GLOBAL(ty + 1), 143)
	else:
		RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty), 257)
		RF_PlaceTile(TILE_TO_GLOBAL(tx), TILE_TO_GLOBAL(ty + 1), 257)
		RF_PlaceTile(TILE_TO_GLOBAL(tx + 1), TILE_TO_GLOBAL(ty), 246)
		RF_PlaceTile(TILE_TO_GLOBAL(tx + 1), TILE_TO_GLOBAL(ty + 1), 246)
	if TILE_TO_GLOBAL(tx) <= obon.x:
		obon.obclass = nothing
		LevelDone = ex_completed


func KeenDead() -> void:
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 >= 200:
		obon.temp1 = -999
		obon.xspeed = RndT() - 128
		obon.yspeed = -400
	obon.shapenum = ((u16(timecount) >> 4) & 1) + S.KEENISDEAD1SPR
	obon.xmove = s16(obon.xspeed * tics)
	obon.ymove = s16(obon.yspeed * tics)
	if obon.bottom < originy:
		obon.obclass = nothing


func HurtKeen() -> void:
	if cheatmode or ankhtime != 0:
		return
	var keen: Obj = objlist[0]
	keen.think = &"KeenDead"
	keen.contact = &"NullContact"
	keen.y += 8 * PIXGLOBAL
	keen.xspeed = 0
	keen.yspeed = 0
	keen.temp1 = 0
	keen.shapenum = S.KEENISDEAD1SPR
	PlaySound(SND.KEENDIESND)


func KillKeen() -> void:
	obon.think = &"KeenDead"
	obon.contact = &"NullContact"
	obon.y += 8 * PIXGLOBAL
	obon.xspeed = 0
	objlist[0].yspeed = 0
	obon.temp1 = 0
	objlist[0].xspeed = 0
	obon.shapenum = S.KEENISDEAD1SPR
	PlaySound(SND.KEENDIESND)


## The blank tile an item leaves: 143 in Keen 1 and 2 (276 for the second
## tileset's items), the first of its row of 13 in Keen 3.
func _blank_for(x: int, y: int, tile: int, kind: String) -> void:
	if episode == 3:
		SETTILE(x, y, 0, (tile / 13) * 13)
		return
	match kind:
		"item":
			if GETTILE(x, y, 0) < 305:
				SETTILE(x, y, 0, 143)
			else:
				SETTILE(x, y, 0, 276)
		"ammo":
			if episode == 2 and GETTILE(x, y, 0) > 305:
				SETTILE(x, y, 0, 276)
			else:
				SETTILE(x, y, 0, 143)
		_:
			SETTILE(x, y, 0, 143)


func PlayerCheckTiles() -> void:
	var keen: Obj = objlist[0]
	if keen.think == &"KeenDead":
		return
	buttontouched = false
	var tileleft: int = GLOBAL_TO_TILE(keen.left)
	var tileright: int = GLOBAL_TO_TILE(keen.right)
	var tiletop: int = GLOBAL_TO_TILE(keen.top)
	var tilebottom: int = GLOBAL_TO_TILE(keen.bottom)
	for x: int in range(tileleft, tileright + 1):
		for y: int in range(tiletop, tilebottom + 1):
			var tile: int = GETTILE(x, y, 0)
			var tiletype: int = intile[tile] if tile < intile.size() else 0
			if tiletype == 0:
				continue
			match tiletype:
				1:
					HurtKeen()
				2, 3, 4, 5:
					if gamestate.keys[tiletype - 2]:
						OpenDoor(x, y)
					else:
						if keen.xmove > 0:
							keen.x = TILE_ALIGN(keen.x)
						else:
							keen.x = (keen.x + TILEGLOBAL) & ~(TILEGLOBAL - 1)
				6, 7, 8, 9, 10:
					GivePoints(itemScores[tiletype - 6])
					PlaySound(SND.GOTBONUSSND)
					_blank_for(x, y, tile, "item")
				11, 12, 13, 14:
					if episode == 1:
						if tiletype == 11:
							gamestate.gotJoystick = true
						if tiletype == 12:
							gamestate.gotBattery = true
						if tiletype == 13:
							gamestate.gotVacuum = true
						if tiletype == 14:
							gamestate.gotEverclear = true
						GivePoints(10000)
						PlaySound(SND.GOTPARTSND)
						SETTILE(x, y, 0, 143)
				15, 16:
					if tiletype == 15:
						gamestate.ammo += 5
					if tiletype == 16:
						gamestate.gotPogo = true
					PlaySound(SND.GOTITEMSND)
					_blank_for(x, y, tile, "ammo")
				17:
					if keen.think == &"KeenWalk":
						PlaySound(SND.LVLDONESND)
						keen.think = &"KeenExit"
						keen.contact = &"NullContact"
						keen.temp1 = x + 2
						keen.temp2 = y
				18, 19, 20, 21:
					gamestate.keys[tiletype - 18] = true
					PlaySound(SND.GETCARDSND)
					_blank_for(x, y, tile, "card")
				22:
					ShowMessage()
					if episode == 1:
						if level == 11:
							SETTILE(x, y, 0, 434)
						else:
							SETTILE(x, y, 0, 315)
					else:
						SETTILE(x, y, 0, 143)
				23, 25, 26:
					buttontouched = true
					switchxtile = x
					switchytile = y
				24:
					LevelDone = ex_warped
				27:
					if episode == 3:
						ankhtime += 1400
						PlaySound(SND.ANKHSND)
						SETTILE(x, y, 0, (tile / 13) * 13)
				28:
					if episode == 3:
						gamestate.ammo += 1
						SETTILE(x, y, 0, (tile / 13) * 13)
						PlaySound(SND.GOTITEMSND)


## Each episode's Keen-touches-creature rules; the episode class supplies them.
func KeenContact(_ob: Obj, _hit: Obj) -> void:
	pass


func ShowMessage() -> void:
	pass


func _splash(ob: Obj) -> void:
	PlaySound(SND.SHOTHITSND)
	ob.obclass = splashobj
	ob.think = &"ShotSplash"
	ob.temp1 = 0
	if RndT() > 128:
		ob.shapenum = S.SHOTSPLASHRSPR
	else:
		ob.shapenum = S.SHOTSPLASHLSPR


func SpawnPlayerShot(x: int, y: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = shotobj
	ob.x = x
	ob.y = y + 9 * PIXGLOBAL
	ob.think = &"ShotThink"
	ob.yspeed = 0
	ob.contact = &"ShotContact"
	ob.shapenum = S.KEENSHOTSPR
	if lastdir >= 0:
		ob.xspeed = 400
		if eastwall[GETTILE(GLOBAL_TO_TILE(x) + 1, GLOBAL_TO_TILE(y) + 1, 0)] != 0:
			_splash(ob)
	else:
		ob.xspeed = -400
		if westwall[GETTILE(GLOBAL_TO_TILE(x), GLOBAL_TO_TILE(y) + 1, 0)] != 0:
			_splash(ob)


func ShotSplash() -> void:
	obon.obclass = deadobj
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 20:
		obon.obclass = nothing


func ShotThink() -> void:
	var block: int = MoveObon()
	if block != 0:
		PlaySound(SND.SHOTHITSND)
		obon.obclass = splashobj
		obon.think = &"ShotSplash"
		obon.temp1 = 0
		if RndT() > 128:
			obon.shapenum = S.SHOTSPLASHRSPR
		else:
			obon.shapenum = S.SHOTSPLASHLSPR


func ShotContact(ob: Obj, hit: Obj) -> void:
	if hit.obclass == keenobj or hit.obclass == deadobj:
		return
	PlaySound(SND.SHOTHITSND)
	ob.think = &"ShotSplash"
	ob.contact = &"NullContact"
	ob.temp1 = 0
	if RndT() > 128:
		ob.shapenum = S.SHOTSPLASHRSPR
	else:
		ob.shapenum = S.SHOTSPLASHLSPR


func DeadThink() -> void:
	obon.temp1 += 1
	DoGravity()
	MoveObon()


func DyingThink() -> void:
	obon.obclass = deadobj
	obon.temp1 = obon.temp1 + tics
	if obon.temp1 > 40:
		obon.temp1 -= 40
		obon.shapenum += 1
		obon.temp2 -= 1
		if obon.temp2 == 1:
			obon.think = &"DeadThink"
	obon.xspeed = 0
	DoGravity()
	MoveObon()


func SpawnEnemyShot(x: int, y: int, xspeed: int) -> void:
	var ob: Obj = FindFreeObj()
	ob.obclass = enemyshotobj
	ob.x = x
	if episode == 2:
		ob.y = y + 9 * PIXGLOBAL
	elif episode == 1:
		ob.y = y + 5 * PIXGLOBAL
	ob.think = &"ShotThink"
	ob.xspeed = xspeed
	ob.contact = &"EnemyShotContact"
	ob.shapenum = S.TANKSHOTSPR
	if xspeed >= 0:
		if eastwall[GETTILE(GLOBAL_TO_TILE(x) + 1, GLOBAL_TO_TILE(y) + 1, 0)] != 0:
			_splash(ob)
	else:
		if westwall[GETTILE(GLOBAL_TO_TILE(x), GLOBAL_TO_TILE(y) + 1, 0)] != 0:
			_splash(ob)


## Which creatures an enemy shot passes through; the episode class says.
func _shot_passes(_hit: Obj) -> bool:
	return false


func EnemyShotContact(ob: Obj, hit: Obj) -> void:
	if _shot_passes(hit) or hit.obclass == deadobj:
		return
	PlaySound(SND.SHOTHITSND)
	ob.think = &"ShotSplash"
	ob.temp1 = 0
	ob.contact = &"NullContact"
	if RndT() > 128:
		ob.shapenum = S.SHOTSPLASHRSPR
	else:
		ob.shapenum = S.SHOTSPLASHLSPR


func BorderFlash(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] > 300:
		vm.card.bios_set_border(3)
		pob.type = POBJ_NOTHING
	else:
		if ((u16(timecount) >> 6) & 1) != 0:
			vm.card.bios_set_border(14)
		else:
			vm.card.bios_set_border(3)


func BridgeCreate(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] < 12:
		return
	pob.temp[1] -= 12
	var x: int = pob.x + pob.temp[4]
	if GETTILE(x, pob.y, 0) != pob.temp[3]:
		pob.think = &"NullPThink"
	else:
		SETTILE(x, pob.y, 0, 270)
		pob.temp[4] += pob.temp[2]


func BridgeRemove(pob: PObj) -> void:
	pob.temp[1] = pob.temp[1] + tics
	if pob.temp[1] < 12:
		return
	pob.temp[1] -= 12
	pob.temp[4] -= pob.temp[2]
	var x: int = pob.x + pob.temp[4]
	if GETTILE(x, pob.y, 0) != 270:
		pob.type = POBJ_NOTHING
	else:
		SETTILE(x, pob.y, 0, pob.temp[3])


# ------------------------------------------------------------ the level

## Objects the level loop keeps thinking even off screen (platforms in 2 and 3).
func _always_active(_ob: Obj) -> bool:
	return false


## What happens to a creature as it comes back on screen (Keen 1's stunned Yorps).
func _reactivate() -> void:
	pass


## The items Keen loses by dying in their level.
func _lose_items(_currentlevel: int) -> void:
	pass


## Instructions LoadLevel's spawn pass spends on each tile of the level (per episode; see each _init).
var spawn_scan_per_tile: int = 16
## Diagnosis only: tics added to timecount as a level starts (0 in play).
var level_tc_shift: int = 0


func LevelLoop(currentlevel: int) -> int:
	var keen: Obj = objlist[0]
	keen.obclass = keenobj
	keen.think = &"KeenWalk"
	keen.contact = &"KeenContact"
	keen.xspeed = 0
	keen.yspeed = 0
	keen.shapenum = S.KEENWALKL1SPR
	keen.active = true
	numobj = 1
	pobjcount = 0
	var showbossintro: bool = true
	lastdir = 1
	if trace_frames:
		var unit: float = DosMachine.PIT_HZ * DosMachine.UNIT
		print("TRACE level_start t=%.6f next_tick=%.6f last_vbl=%.6f rndindex=%d" % [vm.now / unit, vm.next_tick / unit, vm.last_vbl / unit, rndindex])
	timecount = 0
	lasttimecount = 0
	tics = 0
	LevelDone = ex_nothing
	cheatmode = cheat_god
	ankhtime = 0
	if trace_frames:
		print("TRACE load_begin t=%.6f" % (float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT)))
	LoadLevel(currentlevel)
	if trace_frames:
		print("TRACE load_end t=%.6f" % (float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT)))
	if trace_frames:    # the level's objects as spawned (tests only)
		for q: int in range(numobj):
			print("TRACE spawned %d class %d tile %d,%d xspeed %d think %s" % [q, objlist[q].obclass, objlist[q].x >> 12, objlist[q].y >> 12, objlist[q].xspeed, objlist[q].think])
	cost("levelload")    # time after the level's read and spawns, before the first RF_Clear; 0 until fitted
	timecount += level_tc_shift
	lasttimecount += level_tc_shift
	originx = keen.x - 10 * TILEGLOBAL
	originy = keen.y - 5 * TILEGLOBAL
	if originx < originxmin:
		originx = originxmin
	if originy < originymin:
		originy = originymin
	if originx > originxmax:
		originx = originxmax
	if originy > originymax:
		originy = originymax
	RF_Clear()
	if trace_frames:
		print("TRACE fade_begin t=%.6f" % (float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT)))
	FadeOut()
	lightson = true
	RF_ForceRefresh()
	RF_Refresh()
	RF_Refresh()
	FadeIn()
	ox = GLOBAL_TO_TILE(originx)
	oy = GLOBAL_TO_TILE(originy)
	shell_in_level = true
	var traced_first: bool = false
	while true:
		RF_Clear()
		if trace_frames and not traced_first:
			traced_first = true
			trace_sprites = 30
			var unit2: float = DosMachine.PIT_HZ * DosMachine.UNIT
			print("TRACE level_first t=%.6f next_tick=%.6f last_vbl=%.6f timecount=%d tics=%d" % [vm.now / unit2, vm.next_tick / unit2, vm.last_vbl / unit2, timecount, tics])
		ctrl = ControlPlayer(1)
		# the frame's C code before the refresh (thinks, contacts, placement), not yet
		# counted. Charged before the thinks, not after: the creatures read timecount
		# as they think, and in the original Keen's think alone has run by then (a
		# tic falling inside it changes a Yorp's walk frame: Keen 1 levels 3, 4, 13).
		cost("levelframe")
		# `i < numobj` is tested on every pass, as in the original's for loop: an
		# object spawned during a think (a tank's shot) is appended and thinks in
		# the same frame. range(numobj) would fix the count at the frame's start.
		var updated: int = 0    # objects updated this frame
		var i: int = -1
		while i + 1 < numobj:
			i += 1
			var ob: Obj = objlist[i]
			if ob.obclass == nothing:
				continue
			var updated_before: int = updated
			obon.copy_from(ob)
			if obon.active:
				if i == 0 or _always_active(obon) or not RemoveInactive():
					updated += 1
					UpdateObonHitbox()
					obon.xmove = 0
					obon.ymove = 0
					if trace_frames and trace_sprites > 0:
						print("TRACE think i=%d class=%d tc=%d t=%.6f next_tick=%.6f" % [i, obon.obclass, timecount, float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT), float(vm.next_tick) / float(DosMachine.PIT_HZ * DosMachine.UNIT)])
					if not (cheat_freezeEnemies and _cheat_frozen(obon)):
						call(obon.think)
					cost("levelthink")
					obon.x += obon.xmove
					obon.y += obon.ymove
					UpdateObonHitbox()
			else:
				var tx: int = GLOBAL_TO_TILE(obon.x)
				var ty: int = GLOBAL_TO_TILE(obon.y)
				if ox - 2 < tx and oy - 2 < ty and ox + 23 > tx and oy + 12 > ty:
					obon.active = true
					_reactivate()
					updated += 1
					UpdateObonHitbox()
					obon.xmove = 0
					obon.ymove = 0
					if trace_frames and trace_sprites > 0:
						print("TRACE think i=%d class=%d tc=%d t=%.6f next_tick=%.6f" % [i, obon.obclass, timecount, float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT), float(vm.next_tick) / float(DosMachine.PIT_HZ * DosMachine.UNIT)])
					if not (cheat_freezeEnemies and _cheat_frozen(obon)):
						call(obon.think)
					cost("levelthink")
					obon.x += obon.xmove
					obon.y += obon.ymove
					UpdateObonHitbox()
			ob.copy_from(obon)
			if updated == updated_before:
				cost("levelskip")    # an object visited but not updated: RemoveInactive's bounds, or an inactive one's; 0 until fitted
		# the rest of each updated object's time, after the updates (contacts, placing
		# sprites); `levelthink` is the part inside the update loop, charged after each
		# think: Keen 2's first frames show the second object updated thinking before a
		# tic 121 us in and the third after it
		vm.cpu_work(int(costs.get("levelobject", 0)) * updated)
		ScrollScreen()
		i = 0
		while i < numobj:    # both counts re-read each pass, as above
			var ob: Obj = objlist[i]
			if ob.obclass != nothing and ob.active:
				var i2: int = i + 1
				while i2 < numobj:
					var ob2: Obj = objlist[i2]
					if ob2.obclass != nothing and ob2.active and ObjectsCollide(ob, ob2):
						call(ob.contact, ob, ob2)
						call(ob2.contact, ob2, ob)
					i2 += 1
			i += 1
		ox = GLOBAL_TO_TILE(originx)
		oy = GLOBAL_TO_TILE(originy)
		for j: int in range(numobj - 1, -1, -1):
			var ob: Obj = objlist[j]
			if ob.obclass != nothing and ob.active:
				RF_PlaceSprite(ob.x, ob.y, ob.shapenum)
		if episode == 3:
			_halo()
		PlayerCheckTiles()
		i = 0
		while i < pobjcount:    # re-read each pass, as above
			var pob: PObj = pobjlist[i]
			if pob.type != POBJ_NOTHING:
				call(pob.think, pob)
			i += 1
		RF_Refresh()
		ctrl2 = ctrl.duplicate()
		if episode == 3 and showbossintro and currentlevel == 16:
			_boss_intro()
			showbossintro = false
		HandleUserKeys()
		if DoFkeys():
			lasttimecount = timecount
		if cheat_slowMotion:
			var until: int = timecount + 14
			while timecount < until and not exited:
				vm.poll()
			lasttimecount = timecount
		if resetgame or exited:
			return ex_nothing
		if LevelDone != ex_nothing or objlist[0].obclass == nothing:
			break
	WaitEndSound()
	FadeOut()
	for tx: int in range(NUMKEYS):
		gamestate.keys[tx] = false
	if LevelDone == ex_nothing:
		_lose_items(currentlevel)
	return LevelDone


func _halo() -> void:
	pass


func _boss_intro() -> void:
	pass


## KEENnACT.C's; the episode class supplies it.
func LoadLevel(_number: int) -> void:
	pass


## Freeze enemies (CHEAT-01): the objects that stop thinking. Keen, his shots and what he may be riding
## keep going.
func _cheat_frozen(ob: Obj) -> bool:
	return ob.obclass != keenobj and ob.obclass != shotobj and not _cheat_keeps_going(ob)


## An episode's objects Keen rides (platforms, Keen 3's ball): they keep going under Freeze enemies.
func _cheat_keeps_going(_ob: Obj) -> bool:
	return false


# ===================================================================== the shell's cheats (CHEAT-01)

## The cheats this engine has so far (CheatsModel's keys).
func shell_cheat_supported() -> Array:
	return ["god", "infinite_ammo", "infinite_lives", "no_clip", "jump", "slow_motion", "freeze_enemies",
		"free_items", "extra_lives", "skip_level"]


func shell_in_game() -> bool:
	return shell_playing


func shell_cheat_get(key: String) -> bool:
	match key:
		"god": return cheat_god
		"infinite_ammo": return cheat_infiniteAmmo
		"infinite_lives": return cheat_infiniteLives
		"no_clip": return cheat_noClip
		"jump": return cheat_jump
		"slow_motion": return cheat_slowMotion
		"freeze_enemies": return cheat_freezeEnemies
	return false


func shell_cheat_set(key: String, on: bool) -> void:
	match key:
		"god":
			cheat_god = on
			cheatmode = on    # at once, as G+O+D does (and so G+O+D and the row agree)
		"infinite_ammo": cheat_infiniteAmmo = on
		"infinite_lives": cheat_infiniteLives = on
		"no_clip": cheat_noClip = on
		"jump": cheat_jump = on
		"slow_motion": cheat_slowMotion = on
		"freeze_enemies": cheat_freezeEnemies = on


## A one-shot applied; what it did, for the window.
func shell_cheat_fire(key: String) -> String:
	match key:
		"free_items":
			# C+T+Space's items, without its window
			gamestate.gotPogo = true
			gamestate.ammo = 100
			for i: int in range(NUMKEYS):
				gamestate.keys[i] = true
			return "Pogo, keys, 100 shots" if episode == 1 else "Keys, 100 shots"
		"extra_lives":
			var before: int = gamestate.lives
			gamestate.lives = mini(before + CheatsModel.EXTRA_LIVES, CheatsModel.MAX_LIVES)
			return "%d lives" % gamestate.lives if gamestate.lives != before else "Lives are full"
		"skip_level":
			if not shell_in_level:
				return "Only inside a level"
			# as walking out of the exit: the level is marked done on the map
			LevelDone = ex_completed
			return "Level skipped"
	return ""
