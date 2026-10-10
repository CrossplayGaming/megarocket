# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# The declarations of omnispeak's game layer (ck_def.h, ck_act.h, ck_phys.h,
# ck_play.h, ck_ep.h) and a port of ck_act.c (the variable and action
# tables), by David Gow and the Omnispeak authors, GPL v2 or later. Names and
# arithmetic follow omnispeak upstream (A10).
class_name GalCK
extends GalUS
## The Galaxy game layer's shared declarations (docs/GALAXY_PLAN.md, conventions
## 3 and 5): the structs, every global more than one C file uses, the
## variable/action tables, and an untyped stub for every function of ck_*.c
## and ck4/5/6_*.c (generated). The scripts after this one (GalAct, GalPlay,
## GalGame, GalKeen4/5/6) define the functions, each overriding its stub with
## a typed signature of the same arity, and declare only the globals that
## their own C files alone use.

# ===================================================================== ck_def.h

const CK_MAX_OBJECTS: int = 100
const DEFAULT_ACTIVE_LIMIT: int = 4

const MISCFLAG_POLE: int = 1
const MISCFLAG_DOOR: int = 2
const MISCFLAG_DEADLY: int = 3
const MISCFLAG_SWITCHPLATON: int = 5
const MISCFLAG_SWITCHPLATOFF: int = 6
const MISCFLAG_GEMHOLDER0: int = 7
const MISCFLAG_GEMHOLDER1: int = 8
const MISCFLAG_GEMHOLDER2: int = 9
const MISCFLAG_GEMHOLDER3: int = 10
const MISCFLAG_SWITCHBRIDGE: int = 15
const MISCFLAG_BRIDGE: int = 18
const MISCFLAG_ACTIVEZAPPER: int = 19
const MISCFLAG_TELEPORT: int = 20
const MISCFLAG_INACTIVEZAPPER: int = 30
const MISCFLAG_COMPUTER: int = 31
const MISCFLAG_SECURITYDOOR: int = 32
const MISCFLAG_LEFTELEVATOR: int = 33
const MISCFLAG_RIGHTELEVATOR: int = 34

# CK_Difficulty
const D_NotPlaying: int = 0
const D_Easy: int = 1
const D_Normal: int = 2
const D_Hard: int = 3

# CK_Controldir
const CD_north: int = 0
const CD_east: int = 1
const CD_south: int = 2
const CD_west: int = 3

# CK_Dir
const Dir_east: int = 0
const Dir_northeast: int = 1
const Dir_north: int = 2
const Dir_northwest: int = 3
const Dir_west: int = 4
const Dir_southwest: int = 5
const Dir_south: int = 6
const Dir_southeast: int = 7
const Dir_nodir: int = 8

# CK_ClassType
const CT_Nothing: int = 0
const CT_Friendly: int = 1
const CT_Player: int = 2
const CT_Stunner: int = 3
const CT4_Item: int = 4
const CT4_Slug: int = 5
const CT4_CouncilMember: int = 6
const CT4_7: int = 7
const CT4_Egg: int = 8
const CT4_Mushroom: int = 9
const CT4_Arachnut: int = 10
const CT4_Skypest: int = 11
const CT4_Wormmouth: int = 12
const CT4_Cloud: int = 13
const CT4_Berkeloid: int = 14
const CT4_Bounder: int = 15
const CT4_Inchworm: int = 16
const CT4_Foot: int = 17
const CT4_Lick: int = 18
const CT4_Mimrock: int = 19
const CT4_Platform: int = 20
const CT4_Dopefish: int = 21
const CT4_Schoolfish: int = 22
const CT4_Sprite: int = 23
const CT4_Lindsey: int = 24
const CT4_Bolt: int = 25
const CT4_Smirky: int = 26
const CT4_Bird: int = 27
const CT4_0x1C: int = 28
const CT4_0x1D: int = 29
const CT4_Wetsuit: int = 30
const CT4_EnemyShot: int = 31
const CT4_Mine: int = 32
const CT4_StunnedCreature: int = 33
const CT4_MapFlag: int = 34
const CT4_Turret: int = 1
const CT5_EnemyShot: int = 4
const CT5_Item: int = 5
const CT5_Platform: int = 6
const CT5_StunnedCreature: int = 7
const CT5_MapFlag: int = 8
const CT5_Sparky: int = 9
const CT5_Mine: int = 10
const CT5_SliceStar: int = 11
const CT5_Robo: int = 12
const CT5_Spirogrip: int = 13
const CT5_Ampton: int = 14
const CT5_Turret: int = 15
const CT5_Volte: int = 16
const CT5_0x11: int = 17
const CT5_Spindred: int = 18
const CT5_Master: int = 19
const CT5_Shikadi: int = 20
const CT5_Shocksund: int = 21
const CT5_Sphereful: int = 22
const CT5_Korath: int = 23
const CT5_QED: int = 25
const CT6_EnemyShot: int = 4
const CT6_Item: int = 5
const CT6_Platform: int = 6
const CT6_Bloog: int = 7
const CT6_Blooglet: int = 8
const CT6_Fleex: int = 10
const CT6_Molly: int = 12
const CT6_Babobba: int = 13
const CT6_Bobba: int = 14
const CT6_Nospike: int = 16
const CT6_Gik: int = 17
const CT6_Turret: int = 18
const CT6_Orbatrix: int = 19
const CT6_Bip: int = 20
const CT6_Flect: int = 21
const CT6_Blorb: int = 22
const CT6_Ceilick: int = 23
const CT6_Bloogguard: int = 24
const CT6_Bipship: int = 26
const CT6_Sandwich: int = 27
const CT6_Rope: int = 28
const CT6_Passcard: int = 29
const CT6_StunnedCreature: int = 25
const CT6_Grabbiter: int = 30
const CT6_Rocket: int = 31
const CT6_MapCliff: int = 32
const CT6_Satellite: int = 33
const CT6_SatelliteLoading: int = 34
const CT6_MapFlag: int = 35

const _CT_BY_EP: Dictionary = {
	"Item": [CT4_Item, CT5_Item, CT6_Item],
	"EnemyShot": [CT4_EnemyShot, CT5_EnemyShot, CT6_EnemyShot],
	"Platform": [CT4_Platform, CT5_Platform, CT6_Platform],
	"StunnedCreature": [CT4_StunnedCreature, CT5_StunnedCreature, CT6_StunnedCreature],
	"MapFlag": [CT4_MapFlag, CT5_MapFlag, CT6_MapFlag],
	"Turret": [CT4_Turret, CT5_Turret, CT6_Turret],
}


## CT_CLASS(type): the episode's number for a class all three episodes have.
func CT_CLASS(type: String) -> int:
	if ck_currentEpisode_ep < EP_CK4 or ck_currentEpisode_ep > EP_CK6:
		return CT_Nothing
	return _CT_BY_EP[type][ck_currentEpisode_ep - EP_CK4]


# CK_MiscFlag
const MF_Nil: int = 0
const MF_Pole: int = 1
const MF_Door: int = 2
const MF_Deadly: int = 3
const MF_Centilife: int = 4
const MF_SwitchOff: int = 5
const MF_SwitchOn: int = 6
const MF_KeyholderA: int = 7
const MF_KeyholderB: int = 8
const MF_KeyholderC: int = 9
const MF_KeyholderD: int = 10
const MF_WaterN: int = 11
const MF_WaterE: int = 12
const MF_WaterS: int = 13
const MF_WaterW: int = 14
const MF_BridgeSwitch: int = 15
const MF_Moon: int = 16
const MF_PathArrow: int = 17
const MF_Bridge: int = 18
const MF_ZapperOn: int = 19
const MF_Teleporter: int = 20
const MF_Points100: int = 21
const MF_Points200: int = 22
const MF_Points500: int = 23
const MF_Points1000: int = 24
const MF_Points2000: int = 25
const MF_Points5000: int = 26
const MF_1UP: int = 27
const MF_Stunner: int = 28
const MF_ZapperOff: int = 30
const MF_AmptonComputer: int = 31
const MF_KeycardDoor: int = 32
const MF_MapElevatorLeft: int = 33
const MF_MapElevatorRight: int = 34

# CK_LevelState
const LS_Playing: int = 0
const LS_Died: int = 1
const LS_LevelComplete: int = 2
const LS_CouncilRescued: int = 3
const LS_AboutToRecordDemo: int = 4
const LS_ResetGame: int = 5
const LS_LoadedGame: int = 6
const LS_Foot: int = 7
const LS_AbortGame: int = 8
const LS_Sandwich: int = 9
const LS_Rope: int = 10
const LS_Passcard: int = 11
const LS_Molly: int = 12
const LS_TeleportToKorath: int = 13
const LS_KorathFuse: int = 14
const LS_DestroyedQED: int = 15

# CK_ActionType
const AT_UnscaledOnce: int = 0
const AT_ScaledOnce: int = 1
const AT_Frame: int = 2
const AT_UnscaledFrame: int = 3
const AT_ScaledFrame: int = 4
const AT_NullActionTypeValue: int = 0x6F42

# CK_objActive
const OBJ_INACTIVE: int = 0
const OBJ_ACTIVE: int = 1
const OBJ_ALWAYS_ACTIVE: int = 2
const OBJ_EXISTS_ONLY_ONSCREEN: int = 3

# CK_ClipType
const CLIP_not: int = 0
const CLIP_normal: int = 1
const CLIP_simple: int = 2

# ck_play.h: the status window
const STATUS_W: int = 192
const STATUS_H: int = 152
const STATUS_X: int = 64
const STATUS_Y: int = 16
const STATUS_BOTTOM: int = STATUS_H + STATUS_Y

# ck_phys.h
const SLOPEMASK: int = 7


## CK_GameState. The episode union (`ep`) is four 16-bit words shared by the
## three episodes' names, as in C: ck4_wetsuit and ck5_securityCard are the same word.
class CK_GameState:
	var mapPosX: int = 0
	var mapPosY: int = 0
	var levelsDone: PackedInt32Array = PackedInt32Array()
	var keenScore: int = 0
	var nextKeenAt: int = 0
	var numShots: int = 0
	var numCentilife: int = 0
	var ep: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var keyGems: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var currentLevel: int = 0
	var numLives: int = 0
	var difficulty: int = 0
	var levelState: int = 0
	var jumpCheat: bool = false

	var ck4_wetsuit: int:
		get: return ep[0]
		set(v): ep[0] = v
	var ck4_membersRescued: int:
		get: return ep[1]
		set(v): ep[1] = v
	var ck5_securityCard: int:
		get: return ep[0]
		set(v): ep[0] = v
	var ck5_word_4729C: int:
		get: return ep[1]
		set(v): ep[1] = v
	var ck5_fusesRemaining: int:
		get: return ep[2]
		set(v): ep[2] = v
	var ck6_sandwich: int:
		get: return ep[0]
		set(v): ep[0] = v
	var ck6_rope: int:
		get: return ep[1]
		set(v): ep[1] = v
	var ck6_passcard: int:
		get: return ep[2]
		set(v): ep[2] = v
	var ck6_inRocket: int:
		get: return ep[3]
		set(v): ep[3] = v

	func _init() -> void:
		levelsDone.resize(25)

	## C's struct assignment / memset to zero.
	func clear() -> void:
		mapPosX = 0
		mapPosY = 0
		levelsDone = PackedInt32Array()
		levelsDone.resize(25)
		keenScore = 0
		nextKeenAt = 0
		numShots = 0
		numCentilife = 0
		ep = PackedInt32Array([0, 0, 0, 0])
		keyGems = PackedInt32Array([0, 0, 0, 0])
		currentLevel = 0
		numLives = 0
		difficulty = 0
		levelState = 0
		jumpCheat = false

	func copy_from(o: CK_GameState) -> void:
		mapPosX = o.mapPosX
		mapPosY = o.mapPosY
		levelsDone = o.levelsDone.duplicate()
		keenScore = o.keenScore
		nextKeenAt = o.nextKeenAt
		numShots = o.numShots
		numCentilife = o.numCentilife
		ep = o.ep.duplicate()
		keyGems = o.keyGems.duplicate()
		currentLevel = o.currentLevel
		numLives = o.numLives
		difficulty = o.difficulty
		levelState = o.levelState
		jumpCheat = o.jumpCheat


## CK_action. think/collide/draw are method names (&"" for NULL).
class CK_action:
	var name: String = ""
	var chunkLeft: int = 0
	var chunkRight: int = 0
	var type: int = 0
	var protectAnimation: int = 0
	var stickToGround: int = 0
	var timer: int = 0
	var velX: int = 0
	var velY: int = 0
	var think: StringName = &""
	var collide: StringName = &""
	var draw: StringName = &""
	var next: CK_action = null
	var compatDosPointer: int = 0


class CK_objPhysData:
	var unitX1: int = 0
	var unitY1: int = 0
	var unitX2: int = 0
	var unitY2: int = 0
	var unitXmid: int = 0
	var tileX1: int = 0
	var tileY1: int = 0
	var tileX2: int = 0
	var tileY2: int = 0
	var tileXmid: int = 0

	func copy_from(o: CK_objPhysData) -> void:
		unitX1 = o.unitX1
		unitY1 = o.unitY1
		unitX2 = o.unitX2
		unitY2 = o.unitY2
		unitXmid = o.unitXmid
		tileX1 = o.tileX1
		tileY1 = o.tileY1
		tileX2 = o.tileX2
		tileY2 = o.tileY2
		tileXmid = o.tileXmid


class CK_objPhysDataDelta:
	var unitX1: int = 0
	var unitY1: int = 0
	var unitX2: int = 0
	var unitY2: int = 0
	var unitXmid: int = 0


## CK_object. `index` is the object's place in ck_objArray (-1 for tempObj),
## which C gets by pointer arithmetic.
class CK_object:
	var index: int = -1
	var type: int = 0
	var active: int = 0
	var visible: bool = false
	var clipped: int = 0
	var timeUntillThink: int = 0
	var posX: int = 0
	var posY: int = 0
	var xDirection: int = 0
	var yDirection: int = 0
	var deltaPosX: int = 0
	var deltaPosY: int = 0
	var velX: int = 0
	var velY: int = 0
	var actionTimer: int = 0
	var currentAction: CK_action = null
	var gfxChunk: int = 0
	var zLayer: int = 0
	var clipRects: CK_objPhysData = CK_objPhysData.new()
	var topTI: int = 0
	var rightTI: int = 0
	var bottomTI: int = 0
	var leftTI: int = 0
	var sde: GalRF.RF_SpriteDrawEntry = null
	var user1: int = 0
	var user2: int = 0
	var user3: int = 0
	var user4: int = 0
	var next: CK_object = null
	var prev: CK_object = null

	## C's whole-struct copy (*a = *b): every field, the links and sprite entry too.
	func copy_from(o: CK_object) -> void:
		type = o.type
		active = o.active
		visible = o.visible
		clipped = o.clipped
		timeUntillThink = o.timeUntillThink
		posX = o.posX
		posY = o.posY
		xDirection = o.xDirection
		yDirection = o.yDirection
		deltaPosX = o.deltaPosX
		deltaPosY = o.deltaPosY
		velX = o.velX
		velY = o.velY
		actionTimer = o.actionTimer
		currentAction = o.currentAction
		gfxChunk = o.gfxChunk
		zLayer = o.zLayer
		clipRects.copy_from(o.clipRects)
		topTI = o.topTI
		rightTI = o.rightTI
		bottomTI = o.bottomTI
		leftTI = o.leftTI
		sde = o.sde
		user1 = o.user1
		user2 = o.user2
		user3 = o.user3
		user4 = o.user4
		next = o.next
		prev = o.prev

	## memset(obj, 0, sizeof(CK_object)), keeping the array place.
	func clear() -> void:
		type = 0
		active = 0
		visible = false
		clipped = 0
		timeUntillThink = 0
		posX = 0
		posY = 0
		xDirection = 0
		yDirection = 0
		deltaPosX = 0
		deltaPosY = 0
		velX = 0
		velY = 0
		actionTimer = 0
		currentAction = null
		gfxChunk = 0
		zLayer = 0
		clipRects = CK_objPhysData.new()
		topTI = 0
		rightTI = 0
		bottomTI = 0
		leftTI = 0
		sde = null
		user1 = 0
		user2 = 0
		user3 = 0
		user4 = 0
		next = null
		prev = null


class CK_keenState:
	var jumpTimer: int = 0
	var poleGrabTime: int = 0
	var jumpIsPressed: bool = false
	var jumpWasPressed: bool = false
	var pogoIsPressed: bool = false
	var pogoWasPressed: bool = false
	var shootIsPressed: bool = false
	var shootWasPressed: bool = false
	var keenSliding: bool = false
	var platform: CK_object = null


## CK_EpisodeDef: what ck_currentEpisode points at. The functions are method names.
class CK_EpisodeDef:
	var ep: int = 0
	var ext: String = ""
	var episodeFile: String = ""
	var scanInfoLayer: StringName = &""
	var isPresent: StringName = &""


# ===================================================================== globals used by more than one C file

# ck_main.c
var ck_currentEpisode: CK_EpisodeDef = CK_EpisodeDef.new()
var ck_storeDemo: bool = false
# ck_phys.c
var ck_oldRects: CK_objPhysData = CK_objPhysData.new()
var ck_deltaRects: CK_objPhysDataDelta = CK_objPhysDataDelta.new()
var ck_nextX: int = 0
var ck_nextY: int = 0
var ck_keenIgnoreVertClip: bool = false
# ck_play.c
var ck_objArray: Array = _new_obj_array()
var ck_freeObject: CK_object = null
var ck_lastObject: CK_object = null
var ck_numObjects: int = 0
var ck_keenObj: CK_object = null
var ck_tempObj: CK_object = CK_object.new()        # ck_play.c's static tempObj
var ck_activeX0Tile: int = 0
var ck_activeY0Tile: int = 0
var ck_activeX1Tile: int = 0
var ck_activeY1Tile: int = 0
var ck_debugActive: bool = false
var ck_gameState: CK_GameState = CK_GameState.new()
var ck_scrollDisabled: bool = false
var ck_godMode: bool = false
## The bug-fix toggles (FIX-01, FixesModel): key -> on, set by the host from the player's settings.
## Empty in headless runs and the oracle comparisons: every fix off, the original bug for bug.
var fixes: Dictionary = {}


func fix_on(key: String) -> bool:
	return fixes.get(key, false)


## The shell's cheats (CHEAT-01, docs/MENUS.md): each read at one named point; off unless a player
## turns one on from the CHEATS card (headless runs and the oracle comparisons never do).
var cheat_infiniteAmmo: bool = false     # read in CK_SpawnShot
var cheat_infiniteLives: bool = false    # read in CK_TryAgainMenu
var cheat_noClip: bool = false           # read in CK_SpawnKeen
var cheat_freezeEnemies: bool = false    # read in CK_PlayLoop, at CK_RunAction
var ck_invincibilityTimer: int = 0
var ck_scoreBoxObj: CK_object = null
var ck_pogoTimer: int = 0
var ck_inputFrame: IN_ControlFrame = IN_ControlFrame.new()
var ck_statusSurface: VL_Surface = null
var ck_backupSurface: VL_Surface = null
# ck_keen.c
var ck_keenState: CK_keenState = CK_keenState.new()
const ck_itemPoints: PackedInt32Array = [0, 0, 0, 0, 100, 200, 500, 1000, 2000, 5000, 0, 0, 0]
## ck_itemShadows (chunk_id_t): chunk names, looked up with CK_LookupChunk.
## (WITH_KEEN5 adds SPR_BONUSSECURITYCARD; the port is built with every episode.)
const ck_itemShadows: PackedStringArray = ["SPR_BONUSGEM", "SPR_BONUSGEM", "SPR_BONUSGEM", "SPR_BONUSGEM",
	"SPR_BONUS100", "SPR_BONUS200", "SPR_BONUS500", "SPR_BONUS1000", "SPR_BONUS2000", "SPR_BONUS5000",
	"SPR_BONUS1UP", "SPR_BONUSCLIP", "SPR_BONUSSECURITYCARD"]
# ck_obj.c
const ck_infoplaneArrowsX: PackedInt32Array = [0, 1, 0, -1, 1, 1, -1, -1]
const ck_infoplaneArrowsY: PackedInt32Array = [-1, 0, 1, 0, -1, 1, 1, -1]
# ck_inter.c
var ck_startingSavedGame: int = 0
var ck_inHighScores: bool = false
var ck_startingDifficulty: int = D_NotPlaying
# the episodes (ck4/5/6_misc.c's ck4_episode ...; ck_main.c points ck_currentEpisode at one)
var ck4_episode: CK_EpisodeDef = _episode_def(EP_CK4, "CK4", &"CK4_ScanInfoLayer", &"CK4_IsPresent")
var ck5_episode: CK_EpisodeDef = _episode_def(EP_CK5, "CK5", &"CK5_ScanInfoLayer", &"CK5_IsPresent")
var ck6_episode: CK_EpisodeDef = _episode_def(EP_CK6, "CK6", &"CK6_ScanInfoLayer", &"CK6_IsPresent")
# episode globals the core uses
var ck6_smashScreenDistance: int = 0
## ck6_obj1.c's table (constant: nothing writes it)
const ck6_smashScreenOfs: PackedInt32Array = [
	0, -64, -64, -64, 64, 64, 64, -200, -200, -200, 200, 200, 200,
	-250, -250, -250, 250, 250, 250, -250, -250, -250, 250, 250, 250]
var ck6_creatureQuestionDone: bool = false


static func _episode_def(ep: int, ext: String, scan: StringName, present: StringName) -> CK_EpisodeDef:
	var e: CK_EpisodeDef = CK_EpisodeDef.new()
	e.ep = ep
	e.ext = ext
	e.episodeFile = "EPISODE." + ext
	e.scanInfoLayer = scan
	e.isPresent = present
	return e


## ck_currentEpisode = &ckN_episode, keeping GalLib's ck_currentEpisode_ep in step.
func CK_SetCurrentEpisode(e: CK_EpisodeDef) -> void:
	ck_currentEpisode = e
	ck_currentEpisode_ep = e.ep


static func _new_obj_array() -> Array:
	var a: Array = []
	for i: int in range(CK_MAX_OBJECTS):
		var o: CK_object = CK_object.new()
		o.index = i
		a.append(o)
	return a


# ===================================================================== ck_act.c: variables and actions

const CK_VAR_MAXACTIONS: int = 512
## name -> CK_action (an alias maps to its target's instance)
var ck_actionsByName: Dictionary = {}
var ck_actionData: Array = []
var ck_actionsUsed: int = 0
var ck_varsLocked: bool = false
## %function aliases: name -> the C function's name
var ck_functionTable: Dictionary = {}


func CK_ACT_SetupFunctions() -> void:
	ck_functionTable = {}


## C registers each function pointer by name; here every method is its own
## entry, so an added name is an alias for a method.
func CK_ACT_AddFunction(fnName: String, fn: StringName) -> void:
	ck_functionTable[fnName] = fn


func CK_ACT_AddColFunction(fnName: String, fn: StringName) -> void:
	ck_functionTable[fnName] = fn


func CK_ACT_GetFunction(fnName: String) -> StringName:
	if fnName == "NULL":
		return &""
	if ck_functionTable.has(fnName):
		return ck_functionTable[fnName]
	return StringName(fnName)


func CK_ACT_GetColFunction(fnName: String) -> StringName:
	return CK_ACT_GetFunction(fnName)


func CK_VAR_Startup() -> void:
	ck_actionsByName = {}
	ck_actionData = []
	ck_actionsUsed = 0
	ck_varsLocked = false


func CK_VAR_GetInt(name: String, def: int) -> int:
	return data.episode.ints.get(name, def)


func CK_VAR_GetString(name: String, def: String) -> String:
	return data.episode.strings.get(name, def)


func CK_VAR_GetIntArray(name: String) -> PackedInt32Array:
	return data.episode.int_arrays.get(name, PackedInt32Array())


func CK_VAR_GetIntArrayElement(name: String, index: int) -> int:
	var a: PackedInt32Array = data.episode.int_arrays.get(name, PackedInt32Array())
	if index < 0 or index >= a.size():
		Quit("CK_VAR_GetIntArrayElement: Index out of range!")
		return 0
	return a[index]


func CK_VAR_GetStringArray(name: String) -> PackedStringArray:
	return data.episode.string_arrays.get(name, PackedStringArray())


func CK_VAR_GetStringArrayElement(name: String, index: int) -> String:
	var a: PackedStringArray = data.episode.string_arrays.get(name, PackedStringArray())
	if index < 0 or index >= a.size():
		Quit("CK_VAR_GetStringArrayElement: Index out of range!")
		return ""
	return a[index]


## The macros of ck_act.h over the variable file.
func CK_CHUNKNUM(name: String) -> int:
	return CK_VAR_GetInt(name, 0)


func CK_SOUNDNUM(name: String) -> int:
	return CK_VAR_GetInt(name, 0)


func CK_STRING(name: String) -> String:
	return CK_VAR_GetString(name, name)


func CK_LookupChunk(id: String) -> int:
	return CK_VAR_GetInt(id, 0)


func CK_INTELEMENT(name: String, i: int) -> int:
	return CK_VAR_GetIntArrayElement(name, i)


func CK_STRINGELEMENT(name: String, i: int) -> String:
	return CK_VAR_GetStringArrayElement(name, i)


func CK_ACTION(name: String) -> CK_action:
	return CK_GetActionByName(name)


func CK_FUNCTION(name: String) -> StringName:
	return CK_ACT_GetFunction(name)


func CK_GetActionByName(name: String) -> CK_action:
	return ck_actionsByName.get(name, null)


func CK_GetOrCreateActionByName(name: String) -> CK_action:
	var ptr: CK_action = ck_actionsByName.get(name, null)
	if ptr == null:
		if ck_actionsUsed >= CK_VAR_MAXACTIONS:
			Quit("Too many actions!")
			return null
		ptr = CK_action.new()
		ptr.name = name
		ck_actionData.append(ptr)
		ck_actionsUsed += 1
		if not (ck_varsLocked and ck_actionsByName.has(name)):
			ck_actionsByName[name] = ptr
	return ptr


func CK_LookupActionFrom16BitOffset(offset: int) -> CK_action:
	for i: int in range(ck_actionsUsed):
		if (ck_actionData[i] as CK_action).compatDosPointer == offset:
			return ck_actionData[i]
	return null


func _action_type(tok: String) -> int:
	match tok:
		"UnscaledOnce":
			return AT_UnscaledOnce
		"ScaledOnce":
			return AT_ScaledOnce
		"Frame":
			return AT_Frame
		"UnscaledFrame":
			return AT_UnscaledFrame
		"ScaledFrame":
			return AT_ScaledFrame
	return data.episode._int_value(tok)


func _int_or_var(tok: String) -> int:
	if tok.begins_with("@"):
		return CK_VAR_GetInt(tok.substr(1), 0)
	return data.episode._int_value(tok)


## CK_VAR_LoadVars over the episode's variable files, already read by GalData:
## the %function aliases, then every %action in file order (aliases resolve
## to the action defined so far, as the C parser's single pass does).
func CK_VAR_LoadVars(_filename: String) -> void:
	var v: VarFile = data.episode
	for alias: String in v.functions:
		CK_ACT_AddFunction(alias, CK_ACT_GetFunction(v.functions[alias]))
	for name: String in v.action_order:
		var f: Variant = v.actions[name]
		if f is Dictionary:
			var target: CK_action = CK_GetActionByName(f.alias)
			if target == null:
				push_warning("Couldn't resolve action variable reference %s" % f.alias)
			ck_actionsByName[name] = target
			continue
		var fields: Array = f
		var act: CK_action = CK_GetOrCreateActionByName(name)
		act.compatDosPointer = _int_or_var(fields[0])
		act.chunkLeft = _int_or_var(fields[1])
		act.chunkRight = _int_or_var(fields[2])
		act.type = _action_type(fields[3])
		act.protectAnimation = _int_or_var(fields[4])
		act.stickToGround = _int_or_var(fields[5])
		act.timer = _int_or_var(fields[6])
		act.velX = _int_or_var(fields[7])
		act.velY = _int_or_var(fields[8])
		act.think = CK_ACT_GetFunction(fields[9])
		act.collide = CK_ACT_GetColFunction(fields[10])
		act.draw = CK_ACT_GetFunction(fields[11])
		act.next = CK_GetOrCreateActionByName(fields[12]) if fields[12] != "NULL" else null


## Every think, collide and draw name the actions use that no script past
## this one defines (a check for the port: each must be a real method).
func CK_ACT_MissingFunctions() -> PackedStringArray:
	var missing: Dictionary = {}
	for act: CK_action in ck_actionData:
		for fn: StringName in [act.think, act.collide, act.draw]:
			if fn != &"" and not _defined_after_decl(fn):
				missing[String(fn)] = true
	return PackedStringArray(missing.keys())


## True when a script later in the chain than this one defines `fn`.
func _defined_after_decl(fn: StringName) -> bool:
	var s: Script = get_script()
	var decl: Script = load("res://games/galaxy/gal_ck.gd")
	while s != null and s != decl:
		for m: Dictionary in s.get_script_method_list():
			if m.name == fn:
				# get_script_method_list includes inherited methods; check this script's source defines it
				if s.source_code.contains("\nfunc %s(" % fn):
					return true
		s = s.get_base_script()
	return false


# ===================================================================== globals added by the ports
# (a global a port needs that another C file defines: one line each, naming the C file)
var us_aslevFilename: String = ""         # id_us_1.c ("" for NULL)


# ===================================================================== saved-game offsets (id_rf.c's helpers over int16 user fields)

## RF_AddSpriteDrawUsing16BitOffset: takes and returns the 16-bit offset C keeps in a user field.
func RF_AddSpriteDrawUsing16BitOffset(drawEntryOffset: int, unitX: int, unitY: int, chunk: int, allWhite: bool, zLayer: int) -> int:
	var drawEntry: RF_SpriteDrawEntry = RF_ConvertSpriteArray16BitOffsetToPtr(drawEntryOffset & 0xFFFF)
	drawEntry = RF_AddSpriteDraw(drawEntry, unitX, unitY, chunk, allWhite, zLayer)
	return s16(RF_ConvertSpriteArrayPtrTo16BitOffset(drawEntry))


## RF_RemoveSpriteDrawUsing16BitOffset: returns the cleared field (0).
func RF_RemoveSpriteDrawUsing16BitOffset(drawEntryOffset: int) -> int:
	var drawEntry: RF_SpriteDrawEntry = RF_ConvertSpriteArray16BitOffsetToPtr(drawEntryOffset & 0xFFFF)
	RF_RemoveSpriteDraw(drawEntry)
	return 0


## Unlinks the actions' and objects' references to each other (C pointers
## become references; cycles would outlive the engine). Call when done with it.
func CK_ReleaseLinks() -> void:
	for act: CK_action in ck_actionData:
		act.next = null
	ck_actionsByName = {}
	ck_actionData = []
	for o: CK_object in ck_objArray:
		o.next = null
		o.prev = null
		o.currentAction = null
		o.sde = null
	ck_tempObj.next = null
	ck_tempObj.prev = null
	ck_freeObject = null
	ck_lastObject = null
	ck_keenObj = null
	ck_scoreBoxObj = null
	ck_keenState.platform = null


## A stub reached at run time: the function is not ported yet.
func _undefined(fn: StringName) -> Variant:
	Quit("not ported yet: %s" % fn)
	return null


# ---- GENERATED by tools/gen_gal_decl.py: forward declarations (do not edit) ----

# ck_phys.c
func CK_ResetClipRects(_p0):
	return _undefined(&"CK_ResetClipRects")
func CK_SetOldClipRects(_p0):
	return _undefined(&"CK_SetOldClipRects")
func CK_SetDeltaClipRects(_p0):
	return _undefined(&"CK_SetDeltaClipRects")
func CK_PhysUpdateX(_p0, _p1):
	return _undefined(&"CK_PhysUpdateX")
func CK_PhysUpdateY(_p0, _p1):
	return _undefined(&"CK_PhysUpdateY")
func CK_PhysKeenClipDown(_p0):
	return _undefined(&"CK_PhysKeenClipDown")
func CK_PhysKeenClipUp(_p0):
	return _undefined(&"CK_PhysKeenClipUp")
func CK_NotStuckInWall(_p0):
	return _undefined(&"CK_NotStuckInWall")
func CK_PreviewClipRects(_p0, _p1):
	return _undefined(&"CK_PreviewClipRects")
func CK_PhysClipVert(_p0):
	return _undefined(&"CK_PhysClipVert")
func CK_PhysClipHorz(_p0):
	return _undefined(&"CK_PhysClipHorz")
func CK_PhysUpdateNormalObj(_p0):
	return _undefined(&"CK_PhysUpdateNormalObj")
func CK_PhysFullClipToWalls(_p0):
	return _undefined(&"CK_PhysFullClipToWalls")
func CK_PhysUpdateSimpleObj(_p0):
	return _undefined(&"CK_PhysUpdateSimpleObj")
func CK_PhysPushX(_p0, _p1):
	return _undefined(&"CK_PhysPushX")
func CK_PhysPushY(_p0, _p1):
	return _undefined(&"CK_PhysPushY")
func CK_PhysPushXY(_p0, _p1, _p2):
	return _undefined(&"CK_PhysPushXY")
func CK_SetAction(_p0, _p1):
	return _undefined(&"CK_SetAction")
func CK_SetAction2(_p0, _p1):
	return _undefined(&"CK_SetAction2")
func CK_ObjectVisible(_p0):
	return _undefined(&"CK_ObjectVisible")
func CK_PhysGravityHigh(_p0):
	return _undefined(&"CK_PhysGravityHigh")
func CK_PhysGravityMid(_p0):
	return _undefined(&"CK_PhysGravityMid")
func CK_PhysGravityLow(_p0):
	return _undefined(&"CK_PhysGravityLow")
func CK_PhysDampHorz(_p0):
	return _undefined(&"CK_PhysDampHorz")
func CK_PhysAccelHorz(_p0, _p1, _p2):
	return _undefined(&"CK_PhysAccelHorz")
func CK_PhysAccelHorz2(_p0, _p1, _p2):
	return _undefined(&"CK_PhysAccelHorz2")
func CK_PhysAccelVert1(_p0, _p1, _p2):
	return _undefined(&"CK_PhysAccelVert1")

# ck_obj.c
func CK_DoorOpen(_p0):
	return _undefined(&"CK_DoorOpen")
func CK_SecurityDoorOpen(_p0):
	return _undefined(&"CK_SecurityDoorOpen")
func CK_SpawnItem(_p0, _p1, _p2):
	return _undefined(&"CK_SpawnItem")
func CK_SpawnCentilifeNotify(_p0, _p1):
	return _undefined(&"CK_SpawnCentilifeNotify")
func CK_PointItem(_p0):
	return _undefined(&"CK_PointItem")
func CK_FallingItem(_p0):
	return _undefined(&"CK_FallingItem")
func CK_SpawnAxisPlatform(_p0, _p1, _p2, _p3):
	return _undefined(&"CK_SpawnAxisPlatform")
func CK_AxisPlatform(_p0):
	return _undefined(&"CK_AxisPlatform")
func CK_SpawnFallPlat(_p0, _p1):
	return _undefined(&"CK_SpawnFallPlat")
func CK_FallPlatSit(_p0):
	return _undefined(&"CK_FallPlatSit")
func CK_FallPlatFall(_p0):
	return _undefined(&"CK_FallPlatFall")
func CK_FallPlatRise(_p0):
	return _undefined(&"CK_FallPlatRise")
func CK_SpawnStandPlatform(_p0, _p1):
	return _undefined(&"CK_SpawnStandPlatform")
func CK_SpawnGoPlat(_p0, _p1, _p2, _p3):
	return _undefined(&"CK_SpawnGoPlat")
func CK_GoPlatThink(_p0):
	return _undefined(&"CK_GoPlatThink")
func CK_SneakPlatSpawn(_p0, _p1):
	return _undefined(&"CK_SneakPlatSpawn")
func CK_SneakPlatThink(_p0):
	return _undefined(&"CK_SneakPlatThink")
func CK_TurretSpawn(_p0, _p1, _p2):
	return _undefined(&"CK_TurretSpawn")
func CK_TurretShoot(_p0):
	return _undefined(&"CK_TurretShoot")
func CK_TurretShotCol(_p0, _p1):
	return _undefined(&"CK_TurretShotCol")
func CK_TurretShotDraw(_p0):
	return _undefined(&"CK_TurretShotDraw")
func CK_OBJ_SetupFunctions():
	return _undefined(&"CK_OBJ_SetupFunctions")

# ck_misc.c
func CK_SetDraw(_p0):
	return _undefined(&"CK_SetDraw")
func CK_Fall(_p0):
	return _undefined(&"CK_Fall")
func CK_Fall2(_p0):
	return _undefined(&"CK_Fall2")
func CK_Glide(_p0):
	return _undefined(&"CK_Glide")
func CK_BasicDrawFunc1(_p0):
	return _undefined(&"CK_BasicDrawFunc1")
func CK_BasicDrawFunc2(_p0):
	return _undefined(&"CK_BasicDrawFunc2")
func CK_BasicDrawFunc3(_p0):
	return _undefined(&"CK_BasicDrawFunc3")
func CK_ObjBadstate(_p0):
	return _undefined(&"CK_ObjBadstate")
func CK_BasicDrawFunc4(_p0):
	return _undefined(&"CK_BasicDrawFunc4")
func CK_StunCreature(_p0, _p1, _p2):
	return _undefined(&"CK_StunCreature")
func CK_DeadlyCol(_p0, _p1):
	return _undefined(&"CK_DeadlyCol")
func CK_LethalCol(_p0, _p1):
	return _undefined(&"CK_LethalCol")
func CK_PushKeenCol(_p0, _p1):
	return _undefined(&"CK_PushKeenCol")
func CK_CarryKeenCol(_p0, _p1):
	return _undefined(&"CK_CarryKeenCol")
func CK_DieOnContactDraw(_p0):
	return _undefined(&"CK_DieOnContactDraw")
func CK_ShrapnelTileCol(_p0):
	return _undefined(&"CK_ShrapnelTileCol")
func CK_Misc_SetupFunctions():
	return _undefined(&"CK_Misc_SetupFunctions")

# ck_map.c
func CK_DemoSignSpawn():
	return _undefined(&"CK_DemoSignSpawn")
func CK_DemoSign(_p0):
	return _undefined(&"CK_DemoSign")
func CK_ScoreBoxDrawTile8(_p0, _p1, _p2, _p3):
	return _undefined(&"CK_ScoreBoxDrawTile8")
func CK_UpdateScoreBox(_p0):
	return _undefined(&"CK_UpdateScoreBox")
func CK_SpawnMapKeen(_p0, _p1):
	return _undefined(&"CK_SpawnMapKeen")
func CK_ScanForLevelEntry(_p0):
	return _undefined(&"CK_ScanForLevelEntry")
func CK_MapKeenStill(_p0):
	return _undefined(&"CK_MapKeenStill")
func CK_MapKeenWalk(_p0):
	return _undefined(&"CK_MapKeenWalk")
func CK_AnimateMapTeleporter(_p0, _p1):
	return _undefined(&"CK_AnimateMapTeleporter")
func CK_MapFlagSpawn(_p0, _p1):
	return _undefined(&"CK_MapFlagSpawn")
func CK_FlippingFlagSpawn(_p0, _p1):
	return _undefined(&"CK_FlippingFlagSpawn")
func CK_MapFlagThrown(_p0):
	return _undefined(&"CK_MapFlagThrown")
func CK_MapFlagFall(_p0):
	return _undefined(&"CK_MapFlagFall")
func CK_MapFlagLand(_p0):
	return _undefined(&"CK_MapFlagLand")
func CK_Map_SetupFunctions():
	return _undefined(&"CK_Map_SetupFunctions")

# ck_play.c
func CK_CountActiveObjects():
	return _undefined(&"CK_CountActiveObjects")
func CK_DebugMemory():
	return _undefined(&"CK_DebugMemory")
func CK_BeginDemoRecord():
	return _undefined(&"CK_BeginDemoRecord")
func CK_EndDemoRecord():
	return _undefined(&"CK_EndDemoRecord")
func CK_SpriteTest():
	return _undefined(&"CK_SpriteTest")
func CK_ItemCheat():
	return _undefined(&"CK_ItemCheat")
func CK_SetupObjArray():
	return _undefined(&"CK_SetupObjArray")
func CK_GetNewObj(_p0):
	return _undefined(&"CK_GetNewObj")
func CK_RemoveObj(_p0):
	return _undefined(&"CK_RemoveObj")
func CK_ConvertObjPointerTo16BitOffset(_p0):
	return _undefined(&"CK_ConvertObjPointerTo16BitOffset")
func CK_ConvertObj16BitOffsetToPointer(_p0):
	return _undefined(&"CK_ConvertObj16BitOffsetToPointer")
func CK_ActionThink(_p0, _p1):
	return _undefined(&"CK_ActionThink")
func CK_RunAction(_p0):
	return _undefined(&"CK_RunAction")
func CK_OverlayForegroundTile(_p0, _p1):
	return _undefined(&"CK_OverlayForegroundTile")
func CK_WallDebug():
	return _undefined(&"CK_WallDebug")
func CK_DebugKeys():
	return _undefined(&"CK_DebugKeys")
func CK_CheckKeys():
	return _undefined(&"CK_CheckKeys")
func CK_HandleInput():
	return _undefined(&"CK_HandleInput")
func StopMusic():
	return _undefined(&"StopMusic")
func StartMusic(_p0):
	return _undefined(&"StartMusic")
func CK_DrawLongRight(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"CK_DrawLongRight")
func CK_DrawStatusWindow():
	return _undefined(&"CK_DrawStatusWindow")
func CK_ScrollStatusWindow():
	return _undefined(&"CK_ScrollStatusWindow")
func CK_ShowStatusWindow():
	return _undefined(&"CK_ShowStatusWindow")
func CK_CentreCamera(_p0):
	return _undefined(&"CK_CentreCamera")
func CK_MapCamera(_p0):
	return _undefined(&"CK_MapCamera")
func CK_NormalCamera(_p0):
	return _undefined(&"CK_NormalCamera")
func CK_PlayLoop():
	return _undefined(&"CK_PlayLoop")

# ck_keen.c
func CK_KeenColFunc(_p0, _p1):
	return _undefined(&"CK_KeenColFunc")
func CK_IncreaseScore(_p0):
	return _undefined(&"CK_IncreaseScore")
func CK_SpawnKeen(_p0, _p1, _p2):
	return _undefined(&"CK_SpawnKeen")
func CK_KeenGetTileItem(_p0, _p1, _p2):
	return _undefined(&"CK_KeenGetTileItem")
func CK_KeenGetTileCentilife(_p0, _p1):
	return _undefined(&"CK_KeenGetTileCentilife")
func CK_KeenCheckSpecialTileInfo(_p0):
	return _undefined(&"CK_KeenCheckSpecialTileInfo")
func CK_KeenPressSwitchThink(_p0):
	return _undefined(&"CK_KeenPressSwitchThink")
func CK_KeenPressUp(_p0):
	return _undefined(&"CK_KeenPressUp")
func CK_KeenSlide(_p0):
	return _undefined(&"CK_KeenSlide")
func CK_KeenEnterDoor0(_p0):
	return _undefined(&"CK_KeenEnterDoor0")
func CK_KeenEnterDoor1(_p0):
	return _undefined(&"CK_KeenEnterDoor1")
func CK_KeenEnterDoor(_p0):
	return _undefined(&"CK_KeenEnterDoor")
func CK_KeenPlaceGem(_p0):
	return _undefined(&"CK_KeenPlaceGem")
func CK_KeenRidePlatform(_p0):
	return _undefined(&"CK_KeenRidePlatform")
func CK_KeenTryClimbPole(_p0):
	return _undefined(&"CK_KeenTryClimbPole")
func CK_KeenRunningThink(_p0):
	return _undefined(&"CK_KeenRunningThink")
func CK_HandleInputOnGround(_p0):
	return _undefined(&"CK_HandleInputOnGround")
func CK_KeenStandingThink(_p0):
	return _undefined(&"CK_KeenStandingThink")
func CK_KeenLookUpThink(_p0):
	return _undefined(&"CK_KeenLookUpThink")
func CK_KeenLookDownThink(_p0):
	return _undefined(&"CK_KeenLookDownThink")
func CK_KeenDrawFunc(_p0):
	return _undefined(&"CK_KeenDrawFunc")
func CK_KeenRunDrawFunc(_p0):
	return _undefined(&"CK_KeenRunDrawFunc")
func CK_KeenReadThink(_p0):
	return _undefined(&"CK_KeenReadThink")
func CK_KeenJumpThink(_p0):
	return _undefined(&"CK_KeenJumpThink")
func CK_KeenJumpDrawFunc(_p0):
	return _undefined(&"CK_KeenJumpDrawFunc")
func CK_KeenPogoBounceThink(_p0):
	return _undefined(&"CK_KeenPogoBounceThink")
func CK_KeenPogoThink(_p0):
	return _undefined(&"CK_KeenPogoThink")
func CK_KeenBreakFuse(_p0, _p1):
	return _undefined(&"CK_KeenBreakFuse")
func CK_KeenPogoDrawFunc(_p0):
	return _undefined(&"CK_KeenPogoDrawFunc")
func CK_KeenSpecialColFunc(_p0, _p1):
	return _undefined(&"CK_KeenSpecialColFunc")
func CK_KeenSpecialDrawFunc(_p0):
	return _undefined(&"CK_KeenSpecialDrawFunc")
func CK_KeenJumpDownThink(_p0):
	return _undefined(&"CK_KeenJumpDownThink")
func CK_KeenHangThink(_p0):
	return _undefined(&"CK_KeenHangThink")
func CK_KeenPullThink1(_p0):
	return _undefined(&"CK_KeenPullThink1")
func CK_KeenPullThink2(_p0):
	return _undefined(&"CK_KeenPullThink2")
func CK_KeenPullThink3(_p0):
	return _undefined(&"CK_KeenPullThink3")
func CK_KeenPullThink4(_p0):
	return _undefined(&"CK_KeenPullThink4")
func CK_KeenDeathThink(_p0):
	return _undefined(&"CK_KeenDeathThink")
func CK_KillKeen():
	return _undefined(&"CK_KillKeen")
func CK_KeenPoleHandleInput(_p0):
	return _undefined(&"CK_KeenPoleHandleInput")
func CK_KeenPoleSitThink(_p0):
	return _undefined(&"CK_KeenPoleSitThink")
func CK_KeenPoleUpThink(_p0):
	return _undefined(&"CK_KeenPoleUpThink")
func CK_KeenPoleDownThink(_p0):
	return _undefined(&"CK_KeenPoleDownThink")
func CK_KeenPoleDownDrawFunc(_p0):
	return _undefined(&"CK_KeenPoleDownDrawFunc")
func CK_KeenSetClipped(_p0):
	return _undefined(&"CK_KeenSetClipped")
func CK_SpawnShot(_p0, _p1, _p2):
	return _undefined(&"CK_SpawnShot")
func CK_ShotHit(_p0):
	return _undefined(&"CK_ShotHit")
func CK_ShotThink(_p0):
	return _undefined(&"CK_ShotThink")
func CK_ShotDrawFunc(_p0):
	return _undefined(&"CK_ShotDrawFunc")
func CK_KeenSpawnShot(_p0):
	return _undefined(&"CK_KeenSpawnShot")
func CK_KeenSetupFunctions():
	return _undefined(&"CK_KeenSetupFunctions")

# ck_main.c
func CK_MeasureMultiline(_p0, _p1, _p2):
	return _undefined(&"CK_MeasureMultiline")
func CK_ShutdownID():
	return _undefined(&"CK_ShutdownID")
func CK_InitGame():
	return _undefined(&"CK_InitGame")
func CK_DemoLoop():
	return _undefined(&"CK_DemoLoop")

# ck_game.c
func CK_EndingPurge():
	return _undefined(&"CK_EndingPurge")
func CK_NewGame():
	return _undefined(&"CK_NewGame")
func CK_GameOver():
	return _undefined(&"CK_GameOver")
func CK_SaveObject(_p0, _p1):
	return _undefined(&"CK_SaveObject")
func CK_SaveGameState(_p0, _p1):
	return _undefined(&"CK_SaveGameState")
func CK_SaveGame(_p0):
	return _undefined(&"CK_SaveGame")
func CK_LoadGame(_p0, _p1):
	return _undefined(&"CK_LoadGame")
func CK_ExitMenu():
	return _undefined(&"CK_ExitMenu")
func CK_MapLevelMarkAsDone():
	return _undefined(&"CK_MapLevelMarkAsDone")
func CK_UpdateFadeDrawing():
	return _undefined(&"CK_UpdateFadeDrawing")
func CK_BeginFadeDrawing():
	return _undefined(&"CK_BeginFadeDrawing")
func CK_LoadLevel(_p0, _p1):
	return _undefined(&"CK_LoadLevel")
func CK_BeginCacheBox(_p0, _p1):
	return _undefined(&"CK_BeginCacheBox")
func CK_UpdateCacheBox():
	return _undefined(&"CK_UpdateCacheBox")
func CK_FinishCacheBox():
	return _undefined(&"CK_FinishCacheBox")
func CK_TryAgainMenu():
	return _undefined(&"CK_TryAgainMenu")
func CK_GameLoop():
	return _undefined(&"CK_GameLoop")

# ck_text.c
func RipToEOL():
	return _undefined(&"RipToEOL")
func ParseNumber():
	return _undefined(&"ParseNumber")
func ParsePicCommand():
	return _undefined(&"ParsePicCommand")
func ParseTimedCommand():
	return _undefined(&"ParseTimedCommand")
func TimedPicCommand():
	return _undefined(&"TimedPicCommand")
func HandleCommand():
	return _undefined(&"HandleCommand")
func NewLine():
	return _undefined(&"NewLine")
func HandleChar():
	return _undefined(&"HandleChar")
func HandleWord():
	return _undefined(&"HandleWord")
func PageLayout(_p0):
	return _undefined(&"PageLayout")
func BackPage():
	return _undefined(&"BackPage")
func CacheLayoutGraphics():
	return _undefined(&"CacheLayoutGraphics")
func ShowHelp():
	return _undefined(&"ShowHelp")
func HelpScreens():
	return _undefined(&"HelpScreens")
func help_endgame():
	return _undefined(&"help_endgame")

# ck_inter.c
func CK_HandleDemoKeys():
	return _undefined(&"CK_HandleDemoKeys")
func AdvanceTerminatorCredit(_p0):
	return _undefined(&"AdvanceTerminatorCredit")
func ScrollTerminatorCredits(_p0, _p1):
	return _undefined(&"ScrollTerminatorCredits")
func AnimateTerminator():
	return _undefined(&"AnimateTerminator")
func TerminatorExpandRLE(_p0, _p1):
	return _undefined(&"TerminatorExpandRLE")
func JoinTerminatorPics():
	return _undefined(&"JoinTerminatorPics")
func ZoomOutTerminator_1(_p0, _p1, _p2, _p3):
	return _undefined(&"ZoomOutTerminator_1")
func ZoomOutTerminator():
	return _undefined(&"ZoomOutTerminator")
func CK_FizzleFade():
	return _undefined(&"CK_FizzleFade")
func CK_DrawTerminator():
	return _undefined(&"CK_DrawTerminator")
func CK_PrepareSWUpdate():
	return _undefined(&"CK_PrepareSWUpdate")
func CK_TranslateString(_p0, _p1):
	return _undefined(&"CK_TranslateString")
func CK_DrawSWText():
	return _undefined(&"CK_DrawSWText")
func CK_ScrollSWText():
	return _undefined(&"CK_ScrollSWText")
func CK_DrawStarWars():
	return _undefined(&"CK_DrawStarWars")
func CK_ShowTitleScreen():
	return _undefined(&"CK_ShowTitleScreen")
func CK_PlayDemoFile(_p0):
	return _undefined(&"CK_PlayDemoFile")
func CK_PlayDemo(_p0):
	return _undefined(&"CK_PlayDemo")
func CK_SetDefaultHighScores():
	return _undefined(&"CK_SetDefaultHighScores")
func CK_OverlayHighScores():
	return _undefined(&"CK_OverlayHighScores")
func CK_SubmitHighScore(_p0, _p1):
	return _undefined(&"CK_SubmitHighScore")
func CK_DoHighScores():
	return _undefined(&"CK_DoHighScores")

# ck_quit.c
func QuitF(_p0, _p1):
	return _undefined(&"QuitF")

# ck_us_2.c
func CK_US_ScoreBoxMenuProc(_p0, _p1):
	return _undefined(&"CK_US_ScoreBoxMenuProc")
func CK_US_TwoButtonFiringMenuProc(_p0, _p1):
	return _undefined(&"CK_US_TwoButtonFiringMenuProc")
func CK_US_FixJerkyMotionMenuProc(_p0, _p1):
	return _undefined(&"CK_US_FixJerkyMotionMenuProc")
func CK_US_SVGACompatibilityMenuProc(_p0, _p1):
	return _undefined(&"CK_US_SVGACompatibilityMenuProc")
func CK_US_FullscreenMenuProc(_p0, _p1):
	return _undefined(&"CK_US_FullscreenMenuProc")
func CK_US_AspectCorrectMenuProc(_p0, _p1):
	return _undefined(&"CK_US_AspectCorrectMenuProc")
func CK_US_BorderMenuProc(_p0, _p1):
	return _undefined(&"CK_US_BorderMenuProc")
func CK_US_IntegerMenuProc(_p0, _p1):
	return _undefined(&"CK_US_IntegerMenuProc")
func CK_US_VSyncMenuProc(_p0, _p1):
	return _undefined(&"CK_US_VSyncMenuProc")
func CK_US_JoyMotionModeMenuProc(_p0, _p1):
	return _undefined(&"CK_US_JoyMotionModeMenuProc")
func CK_US_QuickSaveConfirmMenuProc(_p0, _p1):
	return _undefined(&"CK_US_QuickSaveConfirmMenuProc")
func CK_US_DrawSavegameItemBorder(_p0):
	return _undefined(&"CK_US_DrawSavegameItemBorder")
func USL_ConfirmQuick(_p0, _p1):
	return _undefined(&"USL_ConfirmQuick")
func US_QuickLoad():
	return _undefined(&"US_QuickLoad")
func load_savegame_item(_p0):
	return _undefined(&"load_savegame_item")
func CK_US_LoadGameMenuProc(_p0, _p1):
	return _undefined(&"CK_US_LoadGameMenuProc")
func US_QuickSave():
	return _undefined(&"US_QuickSave")
func save_savegame_item(_p0):
	return _undefined(&"save_savegame_item")
func CK_US_SaveGameMenuProc(_p0, _p1):
	return _undefined(&"CK_US_SaveGameMenuProc")
func CK_US_ControlsMenuProc(_p0, _p1):
	return _undefined(&"CK_US_ControlsMenuProc")
func CK_US_SetKeyBinding(_p0, _p1):
	return _undefined(&"CK_US_SetKeyBinding")
func CK_US_KeyboardMenuProc(_p0, _p1):
	return _undefined(&"CK_US_KeyboardMenuProc")
func CK_US_Joystick1MenuProc(_p0, _p1):
	return _undefined(&"CK_US_Joystick1MenuProc")
func CK_US_Joystick2MenuProc(_p0, _p1):
	return _undefined(&"CK_US_Joystick2MenuProc")
func CK_US_GamepadMenuProc(_p0, _p1):
	return _undefined(&"CK_US_GamepadMenuProc")
func CK_US_JoyConfMenuProc(_p0, _p1):
	return _undefined(&"CK_US_JoyConfMenuProc")
func CK_US_SetJoyBinding(_p0, _p1):
	return _undefined(&"CK_US_SetJoyBinding")
func CK_US_ConfigureMenuProc(_p0, _p1):
	return _undefined(&"CK_US_ConfigureMenuProc")
func USL_DrawPaddleWarScore(_p0, _p1):
	return _undefined(&"USL_DrawPaddleWarScore")
func USL_PlayPaddleWar():
	return _undefined(&"USL_PlayPaddleWar")
func CK_PaddleWar(_p0, _p1):
	return _undefined(&"CK_PaddleWar")
func CK_US_SetJoystickName(_p0, _p1):
	return _undefined(&"CK_US_SetJoystickName")
func CK_US_UpdateOptionsMenus():
	return _undefined(&"CK_US_UpdateOptionsMenus")
func CK6_CreatureQuestion():
	return _undefined(&"CK6_CreatureQuestion")

# ck4_map.c
func CK4_MapKeenFoot(_p0):
	return _undefined(&"CK4_MapKeenFoot")
func CK4_MapKeenSwim(_p0):
	return _undefined(&"CK4_MapKeenSwim")
func CK4_MapMiscFlagsCheck(_p0):
	return _undefined(&"CK4_MapMiscFlagsCheck")
func CK4_Map_SetupFunctions():
	return _undefined(&"CK4_Map_SetupFunctions")

# ck4_misc.c
func CK4_SetupFunctions():
	return _undefined(&"CK4_SetupFunctions")
func CK4_IsPresent():
	return _undefined(&"CK4_IsPresent")
func CK4_SpawnEnemyShot(_p0, _p1, _p2):
	return _undefined(&"CK4_SpawnEnemyShot")
func CK4_ScanInfoLayer():
	return _undefined(&"CK4_ScanInfoLayer")
func CK4_ShowPrincessMessage():
	return _undefined(&"CK4_ShowPrincessMessage")
func CK4_ShowJanitorMessage():
	return _undefined(&"CK4_ShowJanitorMessage")
func CK4_ShowCantSwimMessage():
	return _undefined(&"CK4_ShowCantSwimMessage")
func CK4_ShowWetsuitMessage():
	return _undefined(&"CK4_ShowWetsuitMessage")
func CK4_ShowCouncilMessage():
	return _undefined(&"CK4_ShowCouncilMessage")
func CK4_SpawnScubaKeen(_p0, _p1):
	return _undefined(&"CK4_SpawnScubaKeen")
func CK4_SpawnKeenBubble(_p0):
	return _undefined(&"CK4_SpawnKeenBubble")
func CK4_KeenSwim(_p0):
	return _undefined(&"CK4_KeenSwim")
func CK4_KeenSwimFast(_p0):
	return _undefined(&"CK4_KeenSwimFast")
func CK4_KeenSwimCol(_p0, _p1):
	return _undefined(&"CK4_KeenSwimCol")
func CK4_KeenSwimDraw(_p0):
	return _undefined(&"CK4_KeenSwimDraw")
func CK4_Misc_SetupFunctions():
	return _undefined(&"CK4_Misc_SetupFunctions")

# ck4_obj1.c
func CK4_SpawnMiragia(_p0, _p1):
	return _undefined(&"CK4_SpawnMiragia")
func CK4_Miragia0(_p0):
	return _undefined(&"CK4_Miragia0")
func CK4_Miragia1(_p0):
	return _undefined(&"CK4_Miragia1")
func CK4_Miragia2(_p0):
	return _undefined(&"CK4_Miragia2")
func CK4_Miragia3(_p0):
	return _undefined(&"CK4_Miragia3")
func CK4_Miragia4(_p0):
	return _undefined(&"CK4_Miragia4")
func CK4_Miragia5(_p0):
	return _undefined(&"CK4_Miragia5")
func CK4_Miragia6(_p0):
	return _undefined(&"CK4_Miragia6")
func CK4_Miragia7(_p0):
	return _undefined(&"CK4_Miragia7")
func CK4_SpawnCouncilMember(_p0, _p1):
	return _undefined(&"CK4_SpawnCouncilMember")
func CK4_CouncilWalk(_p0):
	return _undefined(&"CK4_CouncilWalk")
func CK4_SpawnSlug(_p0, _p1):
	return _undefined(&"CK4_SpawnSlug")
func CK4_SlugMove(_p0):
	return _undefined(&"CK4_SlugMove")
func CK4_SlugSlime(_p0):
	return _undefined(&"CK4_SlugSlime")
func CK4_SlugCol(_p0, _p1):
	return _undefined(&"CK4_SlugCol")
func CK4_SpawnMushroom(_p0, _p1):
	return _undefined(&"CK4_SpawnMushroom")
func CK4_MushroomMove(_p0):
	return _undefined(&"CK4_MushroomMove")
func CK4_MushroomCol(_p0, _p1):
	return _undefined(&"CK4_MushroomCol")
func CK4_MushroomDraw(_p0):
	return _undefined(&"CK4_MushroomDraw")
func CK4_SpawnEgg(_p0, _p1):
	return _undefined(&"CK4_SpawnEgg")
func CK4_BirdRecover(_p0):
	return _undefined(&"CK4_BirdRecover")
func CK4_SpawnBird(_p0, _p1):
	return _undefined(&"CK4_SpawnBird")
func CK4_EggCol(_p0, _p1):
	return _undefined(&"CK4_EggCol")
func CK4_BirdWalk(_p0):
	return _undefined(&"CK4_BirdWalk")
func CK4_BirdFly(_p0):
	return _undefined(&"CK4_BirdFly")
func CK4_BirdCol(_p0, _p1):
	return _undefined(&"CK4_BirdCol")
func CK4_BirdHatchedCol(_p0, _p1):
	return _undefined(&"CK4_BirdHatchedCol")
func CK4_BirdDraw(_p0):
	return _undefined(&"CK4_BirdDraw")
func CK4_BirdLandingDraw(_p0):
	return _undefined(&"CK4_BirdLandingDraw")
func CK4_EggshellDraw(_p0):
	return _undefined(&"CK4_EggshellDraw")
func CK4_BirdFlyingDraw(_p0):
	return _undefined(&"CK4_BirdFlyingDraw")
func CK4_SpawnArachnut(_p0, _p1):
	return _undefined(&"CK4_SpawnArachnut")
func CK4_ArachnutSearch(_p0):
	return _undefined(&"CK4_ArachnutSearch")
func CK4_ArachnutCol(_p0, _p1):
	return _undefined(&"CK4_ArachnutCol")
func CK4_ArachnutStunnedCol(_p0, _p1):
	return _undefined(&"CK4_ArachnutStunnedCol")
func CK4_SpawnSkypest(_p0, _p1):
	return _undefined(&"CK4_SpawnSkypest")
func CK4_SkypestFly(_p0):
	return _undefined(&"CK4_SkypestFly")
func CK4_SkypestAirCol(_p0, _p1):
	return _undefined(&"CK4_SkypestAirCol")
func CK4_SkypestGroundCol(_p0, _p1):
	return _undefined(&"CK4_SkypestGroundCol")
func CK4_SkypestTakeoff(_p0):
	return _undefined(&"CK4_SkypestTakeoff")
func CK4_SkypestDraw(_p0):
	return _undefined(&"CK4_SkypestDraw")
func CK4_Obj1_SetupFunctions():
	return _undefined(&"CK4_Obj1_SetupFunctions")

# ck4_obj2.c
func CK4_SpawnWormmouth(_p0, _p1):
	return _undefined(&"CK4_SpawnWormmouth")
func CK4_WormmouthLookRight(_p0):
	return _undefined(&"CK4_WormmouthLookRight")
func CK4_WormmouthGoToPlayer(_p0):
	return _undefined(&"CK4_WormmouthGoToPlayer")
func CK4_WormmouthLookLeft(_p0):
	return _undefined(&"CK4_WormmouthLookLeft")
func CK4_WormmouthMove(_p0):
	return _undefined(&"CK4_WormmouthMove")
func CK4_WormmouthCheckShot(_p0, _p1):
	return _undefined(&"CK4_WormmouthCheckShot")
func CK4_WormmouthCol(_p0, _p1):
	return _undefined(&"CK4_WormmouthCol")
func CK4_SpawnCloud(_p0, _p1):
	return _undefined(&"CK4_SpawnCloud")
func CK4_CloudMove(_p0):
	return _undefined(&"CK4_CloudMove")
func CK4_CloudCheckStrike(_p0):
	return _undefined(&"CK4_CloudCheckStrike")
func CK4_CloudDraw(_p0):
	return _undefined(&"CK4_CloudDraw")
func CK4_CloudStrike(_p0):
	return _undefined(&"CK4_CloudStrike")
func CK4_CloudCol(_p0, _p1):
	return _undefined(&"CK4_CloudCol")
func CK4_SpawnBerkeloid(_p0, _p1):
	return _undefined(&"CK4_SpawnBerkeloid")
func CK4_BerkeloidMove(_p0):
	return _undefined(&"CK4_BerkeloidMove")
func CK4_BerkeloidThrow(_p0):
	return _undefined(&"CK4_BerkeloidThrow")
func CK4_BerkeloidThrowDone(_p0):
	return _undefined(&"CK4_BerkeloidThrowDone")
func CK4_BerkeloidCol(_p0, _p1):
	return _undefined(&"CK4_BerkeloidCol")
func CK4_FireballDraw(_p0):
	return _undefined(&"CK4_FireballDraw")
func CK4_BerkeloidHover(_p0):
	return _undefined(&"CK4_BerkeloidHover")
func CK4_BerkeloidDraw(_p0):
	return _undefined(&"CK4_BerkeloidDraw")
func CK4_SpawnInchworm(_p0, _p1):
	return _undefined(&"CK4_SpawnInchworm")
func CK4_SpawnFoot(_p0, _p1):
	return _undefined(&"CK4_SpawnFoot")
func CK4_InchwormMove(_p0):
	return _undefined(&"CK4_InchwormMove")
func CK4_InchwormCol(_p0, _p1):
	return _undefined(&"CK4_InchwormCol")
func CK4_FootCol(_p0, _p1):
	return _undefined(&"CK4_FootCol")
func CK4_SpawnBounder(_p0, _p1):
	return _undefined(&"CK4_SpawnBounder")
func CK4_BounderCheckShot(_p0, _p1):
	return _undefined(&"CK4_BounderCheckShot")
func CK4_BounderDraw(_p0):
	return _undefined(&"CK4_BounderDraw")
func CK4_SpawnLick(_p0, _p1):
	return _undefined(&"CK4_SpawnLick")
func CK4_LickMove(_p0):
	return _undefined(&"CK4_LickMove")
func CK4_LickCheckShot(_p0, _p1):
	return _undefined(&"CK4_LickCheckShot")
func CK4_LickCol(_p0, _p1):
	return _undefined(&"CK4_LickCol")
func CK4_LickDraw(_p0):
	return _undefined(&"CK4_LickDraw")
func CK4_SpawnAxisPlatform(_p0, _p1, _p2):
	return _undefined(&"CK4_SpawnAxisPlatform")
func CK4_PlatformDraw(_p0):
	return _undefined(&"CK4_PlatformDraw")
func CK4_Obj2_SetupFunctions():
	return _undefined(&"CK4_Obj2_SetupFunctions")

# ck4_obj3.c
func CK4_SpawnSmirky(_p0, _p1):
	return _undefined(&"CK4_SpawnSmirky")
func CK4_SmirkySearch(_p0):
	return _undefined(&"CK4_SmirkySearch")
func CK4_SmirkyTeleport(_p0):
	return _undefined(&"CK4_SmirkyTeleport")
func CK4_SmirkyCol(_p0, _p1):
	return _undefined(&"CK4_SmirkyCol")
func CK4_SmirkyCheckTiles(_p0):
	return _undefined(&"CK4_SmirkyCheckTiles")
func CK4_SmirkyDraw(_p0):
	return _undefined(&"CK4_SmirkyDraw")
func CK4_SpawnMimrock(_p0, _p1):
	return _undefined(&"CK4_SpawnMimrock")
func CK4_MimrockWait(_p0):
	return _undefined(&"CK4_MimrockWait")
func CK4_MimrockCheckJump(_p0):
	return _undefined(&"CK4_MimrockCheckJump")
func CK4_MimrockCol(_p0, _p1):
	return _undefined(&"CK4_MimrockCol")
func CK4_MimrockAirCol(_p0, _p1):
	return _undefined(&"CK4_MimrockAirCol")
func CK4_MimrockJumpDraw(_p0):
	return _undefined(&"CK4_MimrockJumpDraw")
func CK4_MimrockBounceDraw(_p0):
	return _undefined(&"CK4_MimrockBounceDraw")
func CK4_SpawnDopefish(_p0, _p1):
	return _undefined(&"CK4_SpawnDopefish")
func CK4_KillKeenUnderwater(_p0):
	return _undefined(&"CK4_KillKeenUnderwater")
func CK4_DopefishMove(_p0):
	return _undefined(&"CK4_DopefishMove")
func CK4_DopefishEat(_p0):
	return _undefined(&"CK4_DopefishEat")
func CK4_DopefishAfterBurp(_p0):
	return _undefined(&"CK4_DopefishAfterBurp")
func CK4_DopefishBurp(_p0):
	return _undefined(&"CK4_DopefishBurp")
func CK4_Bubbles(_p0):
	return _undefined(&"CK4_Bubbles")
func CK4_DopefishCol(_p0, _p1):
	return _undefined(&"CK4_DopefishCol")
func CK4_FishDraw(_p0):
	return _undefined(&"CK4_FishDraw")
func CK4_SpawnSchoolfish(_p0, _p1):
	return _undefined(&"CK4_SpawnSchoolfish")
func CK4_SchoolfishMove(_p0):
	return _undefined(&"CK4_SchoolfishMove")
func CK4_SpawnSprite(_p0, _p1):
	return _undefined(&"CK4_SpawnSprite")
func CK4_SpritePatrol(_p0):
	return _undefined(&"CK4_SpritePatrol")
func CK4_SpriteAim(_p0):
	return _undefined(&"CK4_SpriteAim")
func CK4_SpriteShoot(_p0):
	return _undefined(&"CK4_SpriteShoot")
func CK4_ProjectileDraw(_p0):
	return _undefined(&"CK4_ProjectileDraw")
func CK4_SpawnMine(_p0, _p1, _p2):
	return _undefined(&"CK4_SpawnMine")
func CK4_MineCol(_p0, _p1):
	return _undefined(&"CK4_MineCol")
func CK4_SpawnLindsey(_p0, _p1):
	return _undefined(&"CK4_SpawnLindsey")
func CK4_LindseyFloat(_p0):
	return _undefined(&"CK4_LindseyFloat")
func CK4_SpawnDartGun(_p0, _p1, _p2):
	return _undefined(&"CK4_SpawnDartGun")
func CK4_DartGun(_p0):
	return _undefined(&"CK4_DartGun")
func CK4_SpawnWetsuit(_p0, _p1):
	return _undefined(&"CK4_SpawnWetsuit")
func CK4_WetsuitCol(_p0, _p1):
	return _undefined(&"CK4_WetsuitCol")
func CK4_Obj3_SetupFunctions():
	return _undefined(&"CK4_Obj3_SetupFunctions")

# ck5_map.c
func CK5_MapMiscFlagsCheck(_p0):
	return _undefined(&"CK5_MapMiscFlagsCheck")
func CK5_MapKeenTeleSpawn(_p0, _p1):
	return _undefined(&"CK5_MapKeenTeleSpawn")
func CK5_MapKeenElevator(_p0):
	return _undefined(&"CK5_MapKeenElevator")
func CK5_AnimateMapElevator(_p0, _p1, _p2):
	return _undefined(&"CK5_AnimateMapElevator")
func CK5_Map_SetupFunctions():
	return _undefined(&"CK5_Map_SetupFunctions")

# ck5_misc.c
func CK5_IsPresent():
	return _undefined(&"CK5_IsPresent")
func CK5_PurpleAxisPlatform(_p0):
	return _undefined(&"CK5_PurpleAxisPlatform")
func CK5_SpawnLightning():
	return _undefined(&"CK5_SpawnLightning")
func CK5_SpawnFuseExplosion(_p0, _p1):
	return _undefined(&"CK5_SpawnFuseExplosion")
func CK5_SpawnLevelEnd():
	return _undefined(&"CK5_SpawnLevelEnd")
func CK5_LevelEnd(_p0):
	return _undefined(&"CK5_LevelEnd")
func CK5_SetupFunctions():
	return _undefined(&"CK5_SetupFunctions")
func CK5_SpawnEnemyShot(_p0, _p1, _p2):
	return _undefined(&"CK5_SpawnEnemyShot")
func CK5_OpenMapTeleporter(_p0, _p1):
	return _undefined(&"CK5_OpenMapTeleporter")
func CK5_CloseMapTeleporter(_p0, _p1):
	return _undefined(&"CK5_CloseMapTeleporter")
func CK5_ScanInfoLayer():
	return _undefined(&"CK5_ScanInfoLayer")
func CK_GalExplodePageFlip(_p0):
	return _undefined(&"CK_GalExplodePageFlip")
func CK_GalExplodeUpdateCoords(_p0):
	return _undefined(&"CK_GalExplodeUpdateCoords")
func CK5_ExplodeGalaxy():
	return _undefined(&"CK5_ExplodeGalaxy")
func CK5_FuseMessage():
	return _undefined(&"CK5_FuseMessage")

# ck5_obj1.c
func CK5_PurpleGoPlatThink(_p0):
	return _undefined(&"CK5_PurpleGoPlatThink")
func CK5_SpawnVolte(_p0, _p1):
	return _undefined(&"CK5_SpawnVolte")
func CK5_VolteMove(_p0):
	return _undefined(&"CK5_VolteMove")
func CK5_VolteCol(_p0, _p1):
	return _undefined(&"CK5_VolteCol")
func CK5_Obj1_SetupFunctions():
	return _undefined(&"CK5_Obj1_SetupFunctions")

# ck5_obj2.c
func CK5_SpawnSparky(_p0, _p1):
	return _undefined(&"CK5_SpawnSparky")
func CK5_SparkyWait(_p0):
	return _undefined(&"CK5_SparkyWait")
func CK5_SparkyPrepareCharge(_p0):
	return _undefined(&"CK5_SparkyPrepareCharge")
func CK5_SparkySearchLeft(_p0):
	return _undefined(&"CK5_SparkySearchLeft")
func CK5_SparkySearchRight(_p0):
	return _undefined(&"CK5_SparkySearchRight")
func CK5_SparkyCharge0(_p0):
	return _undefined(&"CK5_SparkyCharge0")
func CK5_SparkyCharge1(_p0):
	return _undefined(&"CK5_SparkyCharge1")
func CK5_SparkyCol(_p0, _p1):
	return _undefined(&"CK5_SparkyCol")
func CK5_SparkyTileCol(_p0):
	return _undefined(&"CK5_SparkyTileCol")
func CK5_SpawnAmpton(_p0, _p1):
	return _undefined(&"CK5_SpawnAmpton")
func CK5_AmptonWalk(_p0):
	return _undefined(&"CK5_AmptonWalk")
func CK5_AmptonPoleClimb(_p0):
	return _undefined(&"CK5_AmptonPoleClimb")
func CK5_AmptonSwitch(_p0):
	return _undefined(&"CK5_AmptonSwitch")
func CK5_AmptonCol(_p0, _p1):
	return _undefined(&"CK5_AmptonCol")
func CK5_AmptonTileCol(_p0):
	return _undefined(&"CK5_AmptonTileCol")
func CK5_SpawnSlice(_p0, _p1, _p2):
	return _undefined(&"CK5_SpawnSlice")
func CK5_SpawnSliceDiag(_p0, _p1):
	return _undefined(&"CK5_SpawnSliceDiag")
func CK5_SliceCol(_p0, _p1):
	return _undefined(&"CK5_SliceCol")
func CK5_SliceDiagTileCol(_p0):
	return _undefined(&"CK5_SliceDiagTileCol")
func CK5_SpawnShelly(_p0, _p1):
	return _undefined(&"CK5_SpawnShelly")
func CK5_ShellyWait(_p0):
	return _undefined(&"CK5_ShellyWait")
func CK5_ShellyStartJump(_p0):
	return _undefined(&"CK5_ShellyStartJump")
func CK5_SpawnShellyBits(_p0):
	return _undefined(&"CK5_SpawnShellyBits")
func CK5_ShellyCol(_p0, _p1):
	return _undefined(&"CK5_ShellyCol")
func CK5_ShellyGroundTileCol(_p0):
	return _undefined(&"CK5_ShellyGroundTileCol")
func CK5_ShellyAirTileCol(_p0):
	return _undefined(&"CK5_ShellyAirTileCol")
func CK5_Obj2_SetupFunctions():
	return _undefined(&"CK5_Obj2_SetupFunctions")

# ck5_obj3.c
func CK5_SpawnMine(_p0, _p1):
	return _undefined(&"CK5_SpawnMine")
func CK5_MinePathClear(_p0, _p1):
	return _undefined(&"CK5_MinePathClear")
func CK5_Walk(_p0, _p1):
	return _undefined(&"CK5_Walk")
func CK5_SeekKeen(_p0):
	return _undefined(&"CK5_SeekKeen")
func CK5_MineMove(_p0):
	return _undefined(&"CK5_MineMove")
func CK5_MineCol(_p0, _p1):
	return _undefined(&"CK5_MineCol")
func CK5_MineShrapCol(_p0, _p1):
	return _undefined(&"CK5_MineShrapCol")
func CK5_MineMoveDotsToCenter(_p0):
	return _undefined(&"CK5_MineMoveDotsToCenter")
func CK5_MineMoveDotsToSides(_p0):
	return _undefined(&"CK5_MineMoveDotsToSides")
func CK5_MineExplode(_p0):
	return _undefined(&"CK5_MineExplode")
func CK5_MineTileCol(_p0):
	return _undefined(&"CK5_MineTileCol")
func CK5_SpawnRobo(_p0, _p1):
	return _undefined(&"CK5_SpawnRobo")
func CK5_RoboMove(_p0):
	return _undefined(&"CK5_RoboMove")
func CK5_RoboCol(_p0, _p1):
	return _undefined(&"CK5_RoboCol")
func CK5_RoboShoot(_p0):
	return _undefined(&"CK5_RoboShoot")
func CK5_RoboShotCol(_p0, _p1):
	return _undefined(&"CK5_RoboShotCol")
func CK5_RoboShotTileCol(_p0):
	return _undefined(&"CK5_RoboShotTileCol")
func CK5_SpawnSpirogrip(_p0, _p1):
	return _undefined(&"CK5_SpawnSpirogrip")
func CK5_SpirogripSpin(_p0):
	return _undefined(&"CK5_SpirogripSpin")
func CK5_SpirogripFlyDraw(_p0):
	return _undefined(&"CK5_SpirogripFlyDraw")
func CK5_SpawnSpindred(_p0, _p1):
	return _undefined(&"CK5_SpawnSpindred")
func CK5_SpindredBounce(_p0):
	return _undefined(&"CK5_SpindredBounce")
func CK5_SpindredTileCol(_p0):
	return _undefined(&"CK5_SpindredTileCol")
func CK5_SpawnMaster(_p0, _p1):
	return _undefined(&"CK5_SpawnMaster")
func CK5_MasterStand(_p0):
	return _undefined(&"CK5_MasterStand")
func CK5_MasterShoot(_p0):
	return _undefined(&"CK5_MasterShoot")
func CK5_MasterCol(_p0, _p1):
	return _undefined(&"CK5_MasterCol")
func CK5_MasterTele(_p0):
	return _undefined(&"CK5_MasterTele")
func CK5_MasterTeleTileCol(_p0):
	return _undefined(&"CK5_MasterTeleTileCol")
func CK5_MasterBallCol(_p0, _p1):
	return _undefined(&"CK5_MasterBallCol")
func CK5_MasterBallTileCol(_p0):
	return _undefined(&"CK5_MasterBallTileCol")
func CK5_MasterSparksTileCol(_p0):
	return _undefined(&"CK5_MasterSparksTileCol")
func CK5_SpawnShikadi(_p0, _p1):
	return _undefined(&"CK5_SpawnShikadi")
func CK5_ShikadiWalk(_p0):
	return _undefined(&"CK5_ShikadiWalk")
func CK5_ShikadiCol(_p0, _p1):
	return _undefined(&"CK5_ShikadiCol")
func CK5_ShikadiPole(_p0):
	return _undefined(&"CK5_ShikadiPole")
func CK5_PoleZap(_p0):
	return _undefined(&"CK5_PoleZap")
func CK5_ShikadiTileCol(_p0):
	return _undefined(&"CK5_ShikadiTileCol")
func CK5_SpawnShocksund(_p0, _p1):
	return _undefined(&"CK5_SpawnShocksund")
func CK5_ShocksundSearch(_p0):
	return _undefined(&"CK5_ShocksundSearch")
func CK5_ShocksundStand(_p0):
	return _undefined(&"CK5_ShocksundStand")
func CK5_ShocksundShoot(_p0):
	return _undefined(&"CK5_ShocksundShoot")
func CK5_ShocksundCol(_p0, _p1):
	return _undefined(&"CK5_ShocksundCol")
func CK5_ShocksundGroundTileCol(_p0):
	return _undefined(&"CK5_ShocksundGroundTileCol")
func CK5_ShocksundJumpTileCol(_p0):
	return _undefined(&"CK5_ShocksundJumpTileCol")
func CK5_BarkShotCol(_p0, _p1):
	return _undefined(&"CK5_BarkShotCol")
func CK5_BarkShotTileCol(_p0):
	return _undefined(&"CK5_BarkShotTileCol")
func CK5_SpawnSphereful(_p0, _p1):
	return _undefined(&"CK5_SpawnSphereful")
func CK5_SpherefulBounce(_p0):
	return _undefined(&"CK5_SpherefulBounce")
func CK5_SpherefulTileCol(_p0):
	return _undefined(&"CK5_SpherefulTileCol")
func CK5_KorathWalk(_p0):
	return _undefined(&"CK5_KorathWalk")
func CK5_KorathColFunc(_p0, _p1):
	return _undefined(&"CK5_KorathColFunc")
func CK5_SpawnKorath(_p0, _p1):
	return _undefined(&"CK5_SpawnKorath")
func CK5_QEDSpawn(_p0, _p1):
	return _undefined(&"CK5_QEDSpawn")
func CK5_Obj3_SetupFunctions():
	return _undefined(&"CK5_Obj3_SetupFunctions")

# ck6_map.c
func CK6_MapMiscFlagsCheck(_p0):
	return _undefined(&"CK6_MapMiscFlagsCheck")
func CK6_Map_SetupFunctions():
	return _undefined(&"CK6_Map_SetupFunctions")

# ck6_misc.c
func CK6_SetupFunctions():
	return _undefined(&"CK6_SetupFunctions")
func CK6_IsPresent():
	return _undefined(&"CK6_IsPresent")
func CK6_ScanInfoLayer():
	return _undefined(&"CK6_ScanInfoLayer")
func CK6_ToggleBigSwitch(_p0, _p1):
	return _undefined(&"CK6_ToggleBigSwitch")
func CK6_ShowGetSandwich():
	return _undefined(&"CK6_ShowGetSandwich")
func CK6_ShowGetRope():
	return _undefined(&"CK6_ShowGetRope")
func CK6_ShowGetPasscard():
	return _undefined(&"CK6_ShowGetPasscard")

# ck6_obj1.c
func CK6_SpawnGrabbiter(_p0, _p1):
	return _undefined(&"CK6_SpawnGrabbiter")
func CK6_GrabbiterCol(_p0, _p1):
	return _undefined(&"CK6_GrabbiterCol")
func CK6_SpawnRocket(_p0, _p1, _p2):
	return _undefined(&"CK6_SpawnRocket")
func CK6_Rocket(_p0):
	return _undefined(&"CK6_Rocket")
func CK6_RocketCol(_p0, _p1):
	return _undefined(&"CK6_RocketCol")
func CK6_RocketFlyCol(_p0, _p1):
	return _undefined(&"CK6_RocketFlyCol")
func CK6_RocketFly(_p0):
	return _undefined(&"CK6_RocketFly")
func CK6_SpawnMapCliff(_p0, _p1, _p2):
	return _undefined(&"CK6_SpawnMapCliff")
func CK6_MapKeenThrowRope(_p0):
	return _undefined(&"CK6_MapKeenThrowRope")
func CK6_MapKeenClimb(_p0):
	return _undefined(&"CK6_MapKeenClimb")
func CK6_MapCliffCol(_p0, _p1):
	return _undefined(&"CK6_MapCliffCol")
func CK6_SpawnSatelliteLoading(_p0, _p1, _p2):
	return _undefined(&"CK6_SpawnSatelliteLoading")
func CK6_SpawnSatellite(_p0, _p1):
	return _undefined(&"CK6_SpawnSatellite")
func CK6_Satellite(_p0):
	return _undefined(&"CK6_Satellite")
func CK6_SatelliteCol(_p0, _p1):
	return _undefined(&"CK6_SatelliteCol")
func CK6_KeenSatelliteDraw(_p0):
	return _undefined(&"CK6_KeenSatelliteDraw")
func CK6_SpawnSandwich(_p0, _p1):
	return _undefined(&"CK6_SpawnSandwich")
func CK6_SpawnRope(_p0, _p1):
	return _undefined(&"CK6_SpawnRope")
func CK6_SpawnPasscard(_p0, _p1):
	return _undefined(&"CK6_SpawnPasscard")
func CK6_StoryItemCol(_p0, _p1):
	return _undefined(&"CK6_StoryItemCol")
func CK6_SpawnMolly(_p0, _p1):
	return _undefined(&"CK6_SpawnMolly")
func CK6_GoPlatDraw(_p0):
	return _undefined(&"CK6_GoPlatDraw")
func CK6_SpawnBloog(_p0, _p1):
	return _undefined(&"CK6_SpawnBloog")
func CK6_Bloog(_p0):
	return _undefined(&"CK6_Bloog")
func CK6_BloogCol(_p0, _p1):
	return _undefined(&"CK6_BloogCol")
func CK6_SpawnBloogguard(_p0, _p1):
	return _undefined(&"CK6_SpawnBloogguard")
func CK6_BloogguardWalk(_p0):
	return _undefined(&"CK6_BloogguardWalk")
func CK6_BloogguardSmash(_p0):
	return _undefined(&"CK6_BloogguardSmash")
func CK6_BloogguardCol(_p0, _p1):
	return _undefined(&"CK6_BloogguardCol")
func CK6_MultihitDraw(_p0):
	return _undefined(&"CK6_MultihitDraw")
func CK6_SpawnBlooglet(_p0, _p1, _p2):
	return _undefined(&"CK6_SpawnBlooglet")
func CK6_BloogletCol(_p0, _p1):
	return _undefined(&"CK6_BloogletCol")
func CK6_Obj1_SetupFunctions():
	return _undefined(&"CK6_Obj1_SetupFunctions")

# ck6_obj2.c
func CK6_SpawnNospike(_p0, _p1):
	return _undefined(&"CK6_SpawnNospike")
func CK6_NospikeWalk(_p0):
	return _undefined(&"CK6_NospikeWalk")
func CK6_NospikeCharge(_p0):
	return _undefined(&"CK6_NospikeCharge")
func CK6_NospikeCol(_p0, _p1):
	return _undefined(&"CK6_NospikeCol")
func CK6_NospikeFall(_p0):
	return _undefined(&"CK6_NospikeFall")
func CK6_NospikeFallDraw(_p0):
	return _undefined(&"CK6_NospikeFallDraw")
func CK6_NospikeFallDraw2(_p0):
	return _undefined(&"CK6_NospikeFallDraw2")
func CK6_NospikeChargeDraw(_p0):
	return _undefined(&"CK6_NospikeChargeDraw")
func CK6_SpawnGik(_p0, _p1):
	return _undefined(&"CK6_SpawnGik")
func CK6_GikWalk(_p0):
	return _undefined(&"CK6_GikWalk")
func CK6_GikSlide(_p0):
	return _undefined(&"CK6_GikSlide")
func CK6_GikJumpDraw(_p0):
	return _undefined(&"CK6_GikJumpDraw")
func CK6_GikSlideDraw(_p0):
	return _undefined(&"CK6_GikSlideDraw")
func CK6_SpawnOrbatrix(_p0, _p1):
	return _undefined(&"CK6_SpawnOrbatrix")
func CK6_OrbatrixFloat(_p0):
	return _undefined(&"CK6_OrbatrixFloat")
func CK6_OrbatrixCol(_p0, _p1):
	return _undefined(&"CK6_OrbatrixCol")
func CK6_OrbatrixDraw(_p0):
	return _undefined(&"CK6_OrbatrixDraw")
func CK6_OrbatrixBounceDraw(_p0):
	return _undefined(&"CK6_OrbatrixBounceDraw")
func CK6_OrbatrixCurl(_p0):
	return _undefined(&"CK6_OrbatrixCurl")
func CK6_OrbatrixUncurlThink(_p0):
	return _undefined(&"CK6_OrbatrixUncurlThink")
func CK6_OrbatrixCol2(_p0, _p1):
	return _undefined(&"CK6_OrbatrixCol2")
func CK6_BipWalk(_p0):
	return _undefined(&"CK6_BipWalk")
func CK6_BipCol(_p0, _p1):
	return _undefined(&"CK6_BipCol")
func CK6_SpawnBipship(_p0, _p1):
	return _undefined(&"CK6_SpawnBipship")
func CK6_BipShotDraw(_p0):
	return _undefined(&"CK6_BipShotDraw")
func CK6_BipshipTurn(_p0):
	return _undefined(&"CK6_BipshipTurn")
func CK6_BipshipFly(_p0):
	return _undefined(&"CK6_BipshipFly")
func CK6_BipshipCrash(_p0):
	return _undefined(&"CK6_BipshipCrash")
func CK6_BipshipCol(_p0, _p1):
	return _undefined(&"CK6_BipshipCol")
func CK6_SpawnFlect(_p0, _p1):
	return _undefined(&"CK6_SpawnFlect")
func CK6_FlectTurn(_p0):
	return _undefined(&"CK6_FlectTurn")
func CK6_FlectWalk(_p0):
	return _undefined(&"CK6_FlectWalk")
func CK6_FlectCol(_p0, _p1):
	return _undefined(&"CK6_FlectCol")
func CK6_FlectDraw(_p0):
	return _undefined(&"CK6_FlectDraw")
func CK6_Obj2_SetupFunctions():
	return _undefined(&"CK6_Obj2_SetupFunctions")

# ck6_obj3.c
func CK6_SpawnFleex(_p0, _p1):
	return _undefined(&"CK6_SpawnFleex")
func CK6_FleexWalk(_p0):
	return _undefined(&"CK6_FleexWalk")
func CK6_FleexSearch(_p0):
	return _undefined(&"CK6_FleexSearch")
func CK6_FleexCol(_p0, _p1):
	return _undefined(&"CK6_FleexCol")
func CK6_SpawnBobba(_p0, _p1):
	return _undefined(&"CK6_SpawnBobba")
func CK6_BobbaFireball(_p0):
	return _undefined(&"CK6_BobbaFireball")
func CK6_Bobba(_p0):
	return _undefined(&"CK6_Bobba")
func CK6_BobbaCol(_p0, _p1):
	return _undefined(&"CK6_BobbaCol")
func CK6_BobbaJumpDraw(_p0):
	return _undefined(&"CK6_BobbaJumpDraw")
func CK6_BobbaFireballDraw(_p0):
	return _undefined(&"CK6_BobbaFireballDraw")
func CK6_SpawnBabobba(_p0, _p1):
	return _undefined(&"CK6_SpawnBabobba")
func CK6_BabobbaSit(_p0):
	return _undefined(&"CK6_BabobbaSit")
func CK6_BabobbaCol(_p0, _p1):
	return _undefined(&"CK6_BabobbaCol")
func CK6_BabobbaNapCol(_p0, _p1):
	return _undefined(&"CK6_BabobbaNapCol")
func CK6_BabobbaJumpDraw(_p0):
	return _undefined(&"CK6_BabobbaJumpDraw")
func CK6_BabobbaShot(_p0):
	return _undefined(&"CK6_BabobbaShot")
func CK6_BabobbaShotVanish(_p0):
	return _undefined(&"CK6_BabobbaShotVanish")
func CK6_SpawnBlorb(_p0, _p1):
	return _undefined(&"CK6_SpawnBlorb")
func CK6_BlorbDraw(_p0):
	return _undefined(&"CK6_BlorbDraw")
func CK6_SpawnCeilick(_p0, _p1):
	return _undefined(&"CK6_SpawnCeilick")
func CK6_Ceilick(_p0):
	return _undefined(&"CK6_Ceilick")
func CK6_CeilickDescend(_p0):
	return _undefined(&"CK6_CeilickDescend")
func CK6_CeilickStunned(_p0):
	return _undefined(&"CK6_CeilickStunned")
func CK6_CeilickCol(_p0, _p1):
	return _undefined(&"CK6_CeilickCol")
func CK6_Obj3_SetupFunctions():
	return _undefined(&"CK6_Obj3_SetupFunctions")
# ---- END GENERATED ----
# ===================================================================== id_fs and id_us pieces over the game layer's declarations (saved games, ASLEV maps) the game layer needs
# (written with the ck_* ports, moved here by SIM-G-01j)


## id_ca.c: a map from an Abiathar .aslev file. CA_LoadFile fails without a
## file system, so this ends at the C's "Couldn't load" Quit (the LZW and
## RLEW unpacking past it is not reachable here).
func CA_CacheMapFromASLEV(mapIndex: int, fname: String) -> void:
	# Unload the previous map.
	for plane: int in range(CA_NUMMAPPLANES):
		CA_mapPlanes[plane] = PackedInt32Array()    # MM_FreePtr

	ca_mapOn = mapIndex

	var aslevFile: PackedByteArray = CA_LoadFile(fname)
	if aslevFile.is_empty():
		QuitF("Couldn't load map file %s\n", [fname])
		return


## id_fs.c: the name with its last three letters replaced by the episode's extension.
func FS_AdjustExtension(filename: String) -> String:
	var newname: String = filename.substr(0, FS_MAX_FILENAME_LEN - 1) # CK_Cross_strscpy into newname[FS_MAX_FILENAME_LEN]
	var fnamelen: int = newname.length()
	return newname.substr(0, fnamelen - 3) + ck_currentEpisode.ext.substr(0, 3)


## The saved-game slot each open user file is (FS_File -> [slot, writable]).
## Not state: open only inside US_LoadMain / US_SaveMain.
var fs_userFiles: Dictionary = {}


## id_us_1.c: the name of the saved game with the given index (0-based).
func US_GetSavefileName(index: int) -> String:
	# CK_FILENAME(us_saveFile, "SAVEGAM?.EXT")
	var filename_pattern: String = CK_VAR_GetString("us_saveFile", FS_AdjustExtension("SAVEGAM?.EXT"))
	if filename_pattern.length() >= FS_MAX_FILENAME_LEN:
		QuitF("Savegame filename \"%s\" too long! (Maximum length %d)", [filename_pattern, FS_MAX_FILENAME_LEN])
		return ""
	return filename_pattern.replace("?", char(index + 0x30))


## The saved-game slot a user file name is (the user folder holds only the
## saved games here, matched case-insensitively), or -1.
func _fs_user_slot(fileName: String) -> int:
	for i: int in range(US_MAX_NUM_OF_SAVED_GAMES):
		if US_GetSavefileName(i).to_upper() == fileName.to_upper():
			return i
	return -1


## id_fs.c: open a user file to read (null when it is not there: an empty
## buffer in us_saveFiles is no file).
func FS_OpenUserFile(fileName: String) -> FS_File:
	var slot: int = _fs_user_slot(fileName)
	if slot == -1 or (us_saveFiles[slot] as PackedByteArray).is_empty():
		errno = ENOENT
		return null
	var f: FS_File = FS_File.new(us_saveFiles[slot])
	fs_userFiles[f] = [slot, false]
	return f


## id_fs.c: open a user file to write, empty (fopen "wb").
func FS_CreateUserFile(fileName: String) -> FS_File:
	var slot: int = _fs_user_slot(fileName)
	if slot == -1:
		errno = ENOENT
		return null
	var f: FS_File = FS_File.new(PackedByteArray())
	fs_userFiles[f] = [slot, true]
	return f


## id_fs.c (fclose): a written file's bytes go to its slot in us_saveFiles.
func FS_CloseFile(file: FS_File) -> void:
	if fs_userFiles.has(file):
		var e: Array = fs_userFiles[file]
		if e[1]:
			us_saveFiles[e[0]] = file.data
		fs_userFiles.erase(file)


## remove(): deletes a user file (its saved-game buffer).
func remove(fname: String) -> int:
	var slot: int = _fs_user_slot(fname)
	if slot == -1:
		errno = ENOENT
		return -1
	us_saveFiles[slot] = PackedByteArray()
	return 0
