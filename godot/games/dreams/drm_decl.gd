# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# The declarations of the Keen Dreams source as carried in ReflectionHLE
# (refkeen/src/kdreams: id_heads.h, id_mm.h, id_ca.h, id_vw.h, id_rf.h,
# id_in.h, id_sd.h, id_us.h, kd_def.h, graphkdr.h, audiokdr.h), Copyright (C)
# 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
class_name DrmDecl
extends RefCounted
## The Dreams port's shared declarations (docs/DREAMS_PLAN.md): the machine and
## data the engine runs on, the versions, the structs, every global more than
## one C file uses, the constants (generated) and an untyped stub for every
## function (generated). The scripts after this one (DrmBE, DrmCA, DrmVW,
## DrmRF, DrmIO, DrmUS, DrmGame, DreamsGame) define the functions, each
## overriding its stub with a typed signature of the same arity, and declare
## only the globals their own C files alone use.

# ===================================================================== the machine

## The DOS machine the program runs on (timer, keyboard, EGA card, speaker).
var vm: DosMachine = null
## The player's game files, decoded (DATA-01D/D2).
var data: DreamsData = null

## Time the original's processor spent on work the port does at once (TIME-D),
## named amounts in machine units, fitted against the oracle. Not game state.
var costs: Dictionary = {}


func cost(name: String) -> void:
	var units: int = int(costs.get(name, 0))
	if units > 0:
		vm.cpu_work(units)


func cost_n(name: String, n: int) -> void:
	var units: int = int(costs.get(name, 0)) * n
	if units > 0:
		vm.cpu_work(units)


## kd_main.c's Quit: the program stops (the port returns instead of exiting:
## every loop checks `quitting`). An empty message is the normal way out.
var quit_message: String = ""
var quitting: bool = false


func Quit(error: String) -> void:
	if not quitting:
		quitting = true
		quit_message = error
		if error != "":
			push_error("Dreams engine quit: " + error)


## A function not ported yet: the program stops, naming it.
func _undefined(fn: StringName) -> Variant:
	Quit("not ported yet: %s" % fn)
	return null


# ===================================================================== versions (be_gamever.h)

# BE_GameVer_T, in refkeen's order (the source compares versions with < and >=)
const BE_GAMEVER_KDREAMSE100: int = 0
const BE_GAMEVER_KDREAMSC100: int = 1
const BE_GAMEVER_KDREAMSE113: int = 2
const BE_GAMEVER_KDREAMSC105: int = 3
const BE_GAMEVER_KDREAMSE193: int = 4
const BE_GAMEVER_KDREAMSE120: int = 5
const BE_GAMEVER_KDREAMS2015: int = 6

## The release running, from DreamsData's identification (e100 or e193).
var refkeen_current_gamever: int = BE_GAMEVER_KDREAMSE100
## The command line (id_heads.h's id0_argc / id0_argv: the program's arguments after its name,
## as US_CheckParm reads them).
var id0_argv: PackedStringArray = PackedStringArray()


func id0_argc() -> int:
	return id0_argv.size() + 1


## id_heads.h: the graphics mode (EGA for both supported releases).
var GRMODE: int = 2    # EGAGR
var current_gamever_int: int = 0
## kd_def.h: CREDITS, by version (the new DemoLoop)
var CREDITS: int = 0

const TEXTGR: int = 0
const CGAGR: int = 1
const EGAGR: int = 2
const VGAGR: int = 3


# ===================================================================== C helpers

## Wrapping integer arithmetic where the C does it (A10).
static func s16(v: int) -> int:
	v &= 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


static func u16(v: int) -> int:
	return v & 0xFFFF


static func s32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


static func u32(v: int) -> int:
	return v & 0xFFFFFFFF


static func s8(v: int) -> int:
	v &= 0xFF
	return v - 0x100 if v >= 0x80 else v


static func u8(v: int) -> int:
	return v & 0xFF


# ===================================================================== types

## id_heads.h
class Point:
	var x: int = 0
	var y: int = 0


class Rect:
	var ul: Point = Point.new()
	var lr: Point = Point.new()


## id_mm.h
class mminfotype:
	var nearheap: int = 0
	var farheap: int = 0
	var EMSmem: int = 0
	var XMSmem: int = 0
	var mainmem: int = 0


## id_ca.h
class maptype:
	var planestart: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var planelength: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var width: int = 0
	var height: int = 0
	var name: String = ""


## id_vw.h
class spritetabletype:
	var width: int = 0
	var height: int = 0
	var orgx: int = 0
	var orgy: int = 0
	var xl: int = 0
	var yl: int = 0
	var xh: int = 0
	var yh: int = 0
	var shifts: int = 0


## spritetype_ega: the memptr of a cached sprite points to this (the shifted copies after it).
class spritetype:
	var sourceoffset: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var planesize: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var width: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var data: PackedByteArray = PackedByteArray()


class pictabletype:
	var width: int = 0
	var height: int = 0


class fontstruct:
	var height: int = 0
	var location: PackedInt32Array = PackedInt32Array()
	var width: PackedByteArray = PackedByteArray()
	var data: PackedByteArray = PackedByteArray()    # the whole chunk (glyphs at `location`)


## id_in.h
class CursorInfo:
	var button0: bool = false
	var button1: bool = false
	var x: int = 0
	var y: int = 0
	var xaxis: int = 0    # Motion
	var yaxis: int = 0
	var dir: int = 8      # Direction (dir_None)


class KeyboardDef:
	var button0: int = 0
	var button1: int = 0
	var upleft: int = 0
	var up: int = 0
	var upright: int = 0
	var left: int = 0
	var right: int = 0
	var downleft: int = 0
	var down: int = 0
	var downright: int = 0


class JoystickDef:
	var joyMinX: int = 0
	var joyMinY: int = 0
	var threshMinX: int = 0
	var threshMinY: int = 0
	var threshMaxX: int = 0
	var threshMaxY: int = 0
	var joyMaxX: int = 0
	var joyMaxY: int = 0
	var joyMultXL: int = 0
	var joyMultYL: int = 0
	var joyMultXH: int = 0
	var joyMultYH: int = 0


## id_sd.h
class Instrument:
	var mChar: int = 0
	var cChar: int = 0
	var mScale: int = 0
	var cScale: int = 0
	var mAttack: int = 0
	var cAttack: int = 0
	var mSus: int = 0
	var cSus: int = 0
	var mWave: int = 0
	var cWave: int = 0
	var nConn: int = 0


## id_us.h
class WindowRec:
	var x: int = 0
	var y: int = 0
	var w: int = 0
	var h: int = 0
	var px: int = 0
	var py: int = 0


## kd_def.h. Function pointers are method names (StringName, &"" for NULL).
class statetype:
	var name: StringName = &""
	var leftshapenum: int = 0
	var rightshapenum: int = 0
	var progress: int = 0    # progresstype
	var skippable: bool = false
	var pushtofloor: bool = false
	var tictime: int = 0
	var xmove: int = 0
	var ymove: int = 0
	var thinkptr: StringName = &""
	var contactptr: StringName = &""
	var reactptr: StringName = &""
	var nextstate: statetype = null
	## the state's 16-bit offset in the original's data segment (saved games, temp2)
	var compatdospointer: int = 0


class gametype:
	var worldx: int = 0
	var worldy: int = 0
	var leveldone: Array[bool] = []
	var score: int = 0
	var nextextra: int = 0
	var flowerpowers: int = 0
	var boobusbombs: int = 0
	var bombsthislevel: int = 0
	var keys: int = 0
	var mapon: int = 0
	var lives: int = 0
	var difficulty: int = 0

	func _init() -> void:
		leveldone.resize(17)    # GAMELEVELS
		leveldone.fill(false)


class objtype:
	var index: int = -1    # its place in objarray (the original's pointer)
	var obclass: int = 0
	var active: int = 0
	var needtoreact: bool = false
	var needtoclip: bool = false
	var nothink: int = 0
	var x: int = 0
	var y: int = 0
	var xdir: int = 0
	var ydir: int = 0
	var xmove: int = 0
	var ymove: int = 0
	var xspeed: int = 0
	var yspeed: int = 0
	var ticcount: int = 0
	var ticadjust: int = 0
	var state: statetype = null
	var shapenum: int = 0
	var left: int = 0
	var top: int = 0
	var right: int = 0
	var bottom: int = 0
	var midx: int = 0
	var tileleft: int = 0
	var tiletop: int = 0
	var tileright: int = 0
	var tilebottom: int = 0
	var tilemidx: int = 0
	var hitnorth: int = 0
	var hiteast: int = 0
	var hitsouth: int = 0
	var hitwest: int = 0
	var temp1: int = 0
	var temp2: int = 0
	var temp3: int = 0
	var temp4: int = 0
	var temp2stateptr: statetype = null
	var sprite: Variant = null    # the refresh manager's sprite record
	var next: objtype = null
	var prev: objtype = null


# ===================================================================== shared globals

# id_mm.h
var MAXBLOCKS: int = 0
var mminfo: mminfotype = mminfotype.new()
var bufferseg: Variant = null
var bombonerror: bool = false
var beforesort: StringName = &""
var aftersort: StringName = &""

# id_ca.h / id_ca.c
var tinf: PackedByteArray = PackedByteArray()
var mapon: int = 0
var mapsegs: Array = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
var mapheaderseg: Array = []    # maptype or null, NUMMAPS
var audiosegs: Array = []       # PackedByteArray or null, NUMSNDCHUNKS
var grsegs: Array = []          # PackedByteArray / spritetype / fontstruct or null, NUMCHUNKS
var grneeded: PackedByteArray = PackedByteArray()
var ca_levelbit: int = 1
var ca_levelnum: int = 0
var titleptr: PackedStringArray = PackedStringArray(["", "", "", "", "", "", "", ""])
var profilehandle: Variant = null
var gametext: String = ""
var context: String = ""
var story: String = ""
var xpanmask: int = 0

# id_vw.h / id_vw.c / id_vw_a*.c
var SCREENWIDTH: int = 64
var CHARWIDTH: int = 1
var TILEWIDTH: int = 2
var WHITE: int = 15
var BLACK: int = 0
var FIRSTCOLOR: int = 1
var SECONDCOLOR: int = 12
var F_BLACK: int = 15
var F_FIRSTCOLOR: int = 14
var F_SECONDCOLOR: int = 3
var videocard: int = 0
var grmode: int = 2
var bufferofs: int = 0
var displayofs: int = 0
var panx: int = 0
var pany: int = 0
var pansx: int = 0
var pansy: int = 0
var panadjust: int = 0
var linewidth: int = 0
var ylookup: PackedInt32Array = PackedInt32Array()
var screenfaded: bool = false
var pictable: Array = []        # pictabletype
var picmtable: Array = []
var spritetable: Array = []     # spritetabletype
var px: int = 0
var py: int = 0
var pdrawmode: int = 0
var fontcolor: int = 0
var fakecgamode: bool = false
var shifttabletable: Array = []
var colorbyte: PackedByteArray = PackedByteArray([0, 0, 0, 0])
var bufferwidth: int = 0
var bufferheight: int = 0
var bufferbit: int = 0
var bufferbyte: int = 0
var bufferextra: int = 0
var screenextra: int = 0
var screenspot: int = 0
var linedelta: int = 0
# function pointers (set by version and mode)
var VW_MaskBlock: StringName = &""
var VW_MemToScreen: StringName = &""
var VW_ScreenToMem: StringName = &""
var VW_ScreenToScreen: StringName = &""
var VW_DrawTile8: StringName = &""
var VW_DrawPropString: StringName = &""
var VW_Plot: StringName = &""
var VW_Hlin: StringName = &""
var VW_Vlin: StringName = &""
var VW_Bar: StringName = &""

# id_rf.h / id_rf_a.c
var compatability: bool = false
var tics: int = 0
var lasttimecount: int = 0
var originxglobal: int = 0
var originyglobal: int = 0
var originxtile: int = 0
var originytile: int = 0
var originxscreen: int = 0
var originyscreen: int = 0
var mapwidth: int = 0
var mapheight: int = 0
var mapbyteswide: int = 0
var mapwordswide: int = 0
var mapbytesextra: int = 0
var mapwordsextra: int = 0
var mapbwidthtable: PackedInt32Array = PackedInt32Array()
var originxmin: int = 0
var originxmax: int = 0
var originymin: int = 0
var originymax: int = 0
var masterofs: int = 0
## the update array (UPDATEWIDE*UPDATEHIGH bytes per page) and where the current one starts
var updateptr: int = 0
var baseupdateptr: int = 0
var update: PackedByteArray = PackedByteArray()
var blockstarts: PackedInt32Array = PackedInt32Array()
var updatemapofs: PackedInt32Array = PackedInt32Array()
var uwidthtable: PackedInt32Array = PackedInt32Array()
var updatestart: PackedInt32Array = PackedInt32Array([0, 0])
var planenum: int = 0
var originmap: int = 0
var screenstart: PackedInt32Array = PackedInt32Array([0, 0, 0])
var tilecache: PackedInt32Array = PackedInt32Array()
var RF_NewPosition: StringName = &""
var RF_Scroll: StringName = &""
var RF_PlaceSprite: StringName = &""
var RF_RemoveSprite: StringName = &""
var RF_Refresh: StringName = &""

# id_in.h
var Keyboard: Array[bool] = []
## CTRL-02: the player's keys and pad buttons (ControlsModel.table(): action -> scan codes), read by
## IN_ReadControl and the status key in place of KbdDefs; empty (the tests, the recordings) the original's.
## The throw (button 1) is Fire's and Pogo's (the second button, as Alt is the original's).
var shell_controls: Dictionary = {}
## The refresh the controls were last read on: the host's pad is the controls while they are being read,
## the menus' arrows, Enter and Escape otherwise.
var controls_read_vbl: int = -1000000
## CTRL-03..05: a Controls page catching a key ("keys") or a button ("pad") for an action; the host puts
## the next one pressed in controls_captured (a Godot key or pad button; -1 Escape or Start: cancelled;
## -2 none yet) and the game never sees it.
var controls_capture: String = ""
var controls_captured: int = -2


func shell_held(action: String) -> bool:
	for c: int in shell_controls.get(action, PackedInt32Array()):
		if c < Keyboard.size() and Keyboard[c]:
			return true
	return false
var MousePresent: bool = false
var JoysPresent: Array[bool] = [false, false]
var DemoMode: int = 0
var Paused: bool = false
var LastASCII: int = 0
var LastScan: int = 0
var KbdDefs: Array = []         # KeyboardDef
var JoyDefs: Array = []         # JoystickDef
var Controls: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

# id_sd.h
var LeaveDriveOn: bool = false
var SoundSourcePresent: bool = false
var SoundBlasterPresent: bool = false
var AdLibPresent: bool = false
var NeedsDigitized: bool = false
var NeedsMusic: bool = false
var SoundMode: int = 0
var MusicMode: int = 0
var ssIsTandy: bool = false
var ssPort: int = 2

# id_us.h
var ingame: bool = false
var abortgame: bool = false
var loadedgame: bool = false
var abortprogram: String = ""
var restartgame: int = 0
var PrintX: int = 0
var PrintY: int = 0
var WindowX: int = 0
var WindowY: int = 0
var WindowW: int = 0
var WindowH: int = 0

# kd_def.h
var str: String = ""
var str2: String = ""
var singlestep: bool = false
var jumpcheat: bool = false
var godmode: bool = false
# CHEAT-01: the shell's cheats, each a flag read at its one named point (the originals' F10 keys read
# godmode, jumpcheat and singlestep, which God mode, Jump cheat and Slow motion share)
var cheat_infiniteAmmo: bool = false    # read in ThrowPower
var cheat_infiniteLives: bool = false    # read in HandleDeath
var cheat_noClip: bool = false    # read in StateMachine
var cheat_freezeEnemies: bool = false    # read in PlayLoop
var tedlevel: bool = false
var tedlevelnum: int = 0
var DemoLoop: StringName = &""
var gamestate: gametype = gametype.new()
var playstate: int = 0
var button0held: bool = false
var button1held: bool = false
var originxtilemax: int = 0
var originytilemax: int = 0
var newobj: objtype = null
var check: objtype = null
var player: objtype = null
var scoreobj: objtype = null
var c: CursorInfo = CursorInfo.new()    # ControlInfo
var dummyobj: objtype = objtype.new()
var levelnames: PackedStringArray = PackedStringArray()
var refkeen_compat_kd_play_objoffset: int = 0
var objarray: Array = []        # objtype, MAXACTORS
var singlegravity: int = 0
var bounceangle: Array = []     # [8][8]
var PIRACY: PackedByteArray = PackedByteArray()
## Every statetype by name (the s_* tables, built by the scripts that define them: a
## state is shared across files through here, as the C's externs share them).
var states: Dictionary = {}


## A state by name (kd_def.h's `extern statetype s_...`).
func S(name: StringName) -> statetype:
	return states.get(name, null)


# ---- GENERATED by tools/gen_drm_consts.py: constants (do not edit) ----

# graphkdr.h
const CTL_STARTUPPIC: int = 4
const CTL_HELPUPPIC: int = 5
const CTL_DISKUPPIC: int = 6
const CTL_CONTROLSUPPIC: int = 7
const CTL_SOUNDUPPIC: int = 8
const CTL_MUSICUPPIC: int = 9
const CTL_STARTDNPIC: int = 10
const CTL_HELPDNPIC: int = 11
const CTL_DISKDNPIC: int = 12
const CTL_CONTROLSDNPIC: int = 13
const CTL_SOUNDDNPIC: int = 14
const CTL_MUSICDNPIC: int = 15
const CTL_C_KBDUPPIC: int = 16
const CTL_C_JOY1UPPIC: int = 17
const CTL_C_JOY2UPPIC: int = 18
const CTL_S_NOSNDUPPIC: int = 19
const CTL_S_PCSNDUPPIC: int = 20
const CTL_S_ADLIBUPPIC: int = 21
const CTL_S_SNDBLUPPIC: int = 22
const CTL_S_SNDSRCUPPIC: int = 23
const CTL_M_NOMUSUPPIC: int = 24
const CTL_C_KBDDNPIC: int = 25
const CTL_C_JOY1DNPIC: int = 26
const CTL_C_JOY2DNPIC: int = 27
const CTL_S_NOSNDDNPIC: int = 28
const CTL_S_PCSNDDNPIC: int = 29
const CTL_S_ADLIBDNPIC: int = 30
const CTL_S_SNDBLDNPIC: int = 31
const CTL_S_SNDSRCDNPIC: int = 32
const CTL_M_NOMUSDNPIC: int = 33
const CTL_CHECKUPPIC: int = 34
const CTL_CHECKDNPIC: int = 35
const CTL_KEYCAPPIC: int = 36
const CTL_KEYCAPCURPIC: int = 37
const CTL_DIRSPIC: int = 38
const CTL_D_SAVEUPPIC: int = 39
const CTL_D_SAVEDNPIC: int = 40
const CTL_D_LOADUPPIC: int = 41
const CTL_D_LOADDNPIC: int = 42
const CTL_P_EASYUPPIC: int = 43
const CTL_P_EASYDNPIC: int = 44
const CTL_P_MEDUPPIC: int = 45
const CTL_P_MEDDNPIC: int = 46
const CTL_P_HARDUPPIC: int = 47
const CTL_P_HARDDNPIC: int = 48
const CTL_P_RESUMEUPPIC: int = 49
const CTL_P_RESUMEDNPIC: int = 50
const CTL_P_GORESUMEUPPIC: int = 51
const CTL_P_GORESUMEDNPIC: int = 52
const CTL_P_NEWGAMEUPPIC: int = 53
const CTL_P_NEWGAMEDNPIC: int = 54
const CTL_C_CALIBRATEUPPIC: int = 55
const CTL_C_CALIBRATEDNPIC: int = 56
const CTL_H_STORYUPPIC: int = 57
const CTL_H_STORYDNPIC: int = 58
const CTL_H_CTRLUPPIC: int = 59
const CTL_H_CTRLDNPIC: int = 60
const CTL_H_LOSTUPPIC: int = 61
const CTL_H_LOSTDNPIC: int = 62
const CTL_D_LSGAMEUPPIC: int = 63
const CTL_D_LSGAMEDNPIC: int = 64
const CTL_D_DOSUPPIC: int = 65
const CTL_D_DOSDNPIC: int = 66
const CTL_D_EXITUPPIC: int = 67
const CTL_D_EXITDNPIC: int = 68
const CTL_LITTLEMASKPICM: int = 69
const CTL_LSMASKPICM: int = 70
const CURSORARROWSPR: int = 71
const KEENSTANDRSPR: int = 72
const KEENRUNR1SPR: int = 73
const KEENRUNR2SPR: int = 74
const KEENRUNR3SPR: int = 75
const KEENRUNR4SPR: int = 76
const KEENJUMPR1SPR: int = 77
const KEENJUMPR2SPR: int = 78
const KEENJUMPR3SPR: int = 79
const KEENSTANDLSPR: int = 80
const KEENRUNL1SPR: int = 81
const KEENRUNL2SPR: int = 82
const KEENRUNL3SPR: int = 83
const KEENRUNL4SPR: int = 84
const KEENJUMPL1SPR: int = 85
const KEENJUMPL2SPR: int = 86
const KEENJUMPL3SPR: int = 87
const KEENLOOKURSPR: int = 88
const KEENWAITR1SPR: int = 89
const KEENWAITR2SPR: int = 90
const KEENWAITR3SPR: int = 91
const KEENTURNRSPR: int = 92
const KEENJUMPUR1SPR: int = 93
const KEENJUMPUR2SPR: int = 94
const KEENLOOKULSPR: int = 95
const KEENWAITL1SPR: int = 96
const KEENWAITL2SPR: int = 97
const KEENWAITL3SPR: int = 98
const KEENTURNLSPR: int = 99
const KEENJUMPUL1SPR: int = 100
const KEENJUMPUL2SPR: int = 101
const KEENYAWN1SPR: int = 102
const KEENYAWN2SPR: int = 103
const KEENYAWN3SPR: int = 104
const KEENYAWN4SPR: int = 105
const KEENDUCKRSPR: int = 106
const KEENDUCKLSPR: int = 107
const KEENTHROWL1SPR: int = 108
const KEENTHROWL2SPR: int = 109
const KEENTHROWL3SPR: int = 110
const KEENTHROWU1SPR: int = 111
const KEENTHROWU2SPR: int = 112
const KEENSLEEP1SPR: int = 113
const KEENSLEEP2SPR: int = 114
const KEENSLEEP3SPR: int = 115
const KEENSLEEP4SPR: int = 116
const KEENTHROWR1SPR: int = 117
const KEENTHROWR2SPR: int = 118
const KEENTHROWR3SPR: int = 119
const KEENZEES1SPR: int = 120
const KEENZEES2SPR: int = 121
const KEENZEES3SPR: int = 122
const KEENJLTHROWL1SPR: int = 123
const KEENJLTHROWL2SPR: int = 124
const KEENJLTHROWU1SPR: int = 125
const KEENJLTHROWU2SPR: int = 126
const KEENJLTHROWD1SPR: int = 127
const KEENJLTHROWD2SPR: int = 128
const KEENJRTHROWR1SPR: int = 129
const KEENJRTHROWR2SPR: int = 130
const KEENJRTHROWU1SPR: int = 131
const KEENJRTHROWU2SPR: int = 132
const KEENJRTHROWD1SPR: int = 133
const KEENJRTHROWD2SPR: int = 134
const KEENDREAM1SPR: int = 135
const KEENDREAM2SPR: int = 136
const KEENDREAM3SPR: int = 137
const KEENSHINNYR1SPR: int = 138
const KEENSHINNYR2SPR: int = 139
const KEENSHINNYR3SPR: int = 140
const KEENSLIDED1SPR: int = 141
const KEENSLIDED2SPR: int = 142
const KEENSLIDED3SPR: int = 143
const KEENSLIDED4SPR: int = 144
const KEENSHINNYL1SPR: int = 145
const KEENSHINNYL2SPR: int = 146
const KEENSHINNYL3SPR: int = 147
const KEENPTHROWL1SPR: int = 148
const KEENPTHROWL2SPR: int = 149
const KEENPTHROWR1SPR: int = 150
const KEENPTHROWR2SPR: int = 151
const KEENPLTHROWU1SPR: int = 152
const KEENPLTHROWU2SPR: int = 153
const KEENPRTHROWD1SPR: int = 154
const KEENPRTHROWD2SPR: int = 155
const KEENGETUPRSPR: int = 156
const KEENPRTHROWU1SPR: int = 157
const KEENPRTHROWU2SPR: int = 158
const KEENPLTHROWD1SPR: int = 159
const KEENPLTHROWD2SPR: int = 160
const KEENGETUPLSPR: int = 161
const FLOWERPOWER1SPR: int = 162
const FLOWERPOWER2SPR: int = 163
const FLOWER1SPR: int = 164
const FLOWER2SPR: int = 165
const FLOWER3SPR: int = 166
const FLOWER4SPR: int = 167
const POOF1SPR: int = 168
const POOF2SPR: int = 169
const POOF3SPR: int = 170
const POOF4SPR: int = 171
const PEPPERMINT1SPR: int = 172
const PEPPERMINT2SPR: int = 173
const COOKIE1SPR: int = 174
const COOKIE2SPR: int = 175
const CANDYCANE1SPR: int = 176
const CANDYCANE2SPR: int = 177
const CANDYBAR1SPR: int = 178
const CANDYBAR2SPR: int = 179
const LOLLIPOP1SPR: int = 180
const LOLLIPOP2SPR: int = 181
const COTTONCANDY1SPR: int = 182
const COTTONCANDY2SPR: int = 183
const EXTRAKEEN1SPR: int = 184
const EXTRAKEEN2SPR: int = 185
const SUPERBONUS1SPR: int = 186
const SUPERBONUS2SPR: int = 187
const SUPERBONUS3SPR: int = 188
const SUPERBONUS4SPR: int = 189
const FLOWERPOWERUP1SPR: int = 190
const FLOWERPOWERUP2SPR: int = 191
const BOOBUSBOMB1SPR: int = 192
const BOOBUSBOMB2SPR: int = 193
const BOOBUSBOMB3SPR: int = 194
const BOOBUSBOOM1SPR: int = 195
const BOOBUSBOOM2SPR: int = 196
const MAGICKEY1SPR: int = 197
const MAGICKEY2SPR: int = 198
const BONUS100SPR: int = 199
const BONUS200SPR: int = 200
const BONUS500SPR: int = 201
const BONUS1000SPR: int = 202
const BONUS2000SPR: int = 203
const BONUS5000SPR: int = 204
const BONUS1UPSPR: int = 205
const BONUSSUPERSPR: int = 206
const BONUSFLOWERSPR: int = 207
const BONUSFLOWERUPSPR: int = 208
const BONUSBOMBSPR: int = 209
const BONUSKEYSPR: int = 210
const DOORSPR: int = 211
const SCOREBOXSPR: int = 212
const WORLDKEENL1SPR: int = 213
const WORLDKEENL2SPR: int = 214
const WORLDKEENL3SPR: int = 215
const WORLDKEENR1SPR: int = 216
const WORLDKEENR2SPR: int = 217
const WORLDKEENR3SPR: int = 218
const WORLDKEENU1SPR: int = 219
const WORLDKEENU2SPR: int = 220
const WORLDKEENU3SPR: int = 221
const WORLDKEEND1SPR: int = 222
const WORLDKEEND2SPR: int = 223
const WORLDKEEND3SPR: int = 224
const WORLDKEENDR1SPR: int = 225
const WORLDKEENDR2SPR: int = 226
const WORLDKEENDR3SPR: int = 227
const WORLDKEENDL1SPR: int = 228
const WORLDKEENDL2SPR: int = 229
const WORLDKEENDL3SPR: int = 230
const WORLDKEENUL1SPR: int = 231
const WORLDKEENUL2SPR: int = 232
const WORLDKEENUL3SPR: int = 233
const WORLDKEENUR1SPR: int = 234
const WORLDKEENUR2SPR: int = 235
const WORLDKEENUR3SPR: int = 236
const WORLDKEENSLEEP1SPR: int = 237
const WORLDKEENSLEEP2SPR: int = 238
const WORLDKEENWAVE1SPR: int = 239
const WORLDKEENWAVE2SPR: int = 240
const BROCCOLASHRUNL1SPR: int = 241
const BROCCOLASHRUNL2SPR: int = 242
const BROCCOLASHRUNL3SPR: int = 243
const BROCCOLASHRUNL4SPR: int = 244
const BROCCOLASHSMASHL1SPR: int = 245
const BROCCOLASHSMASHL2SPR: int = 246
const BROCCOLASHSMASHL3SPR: int = 247
const BROCCOLASHSMASHL4SPR: int = 248
const BROCCOLASHRUNR1SPR: int = 249
const BROCCOLASHRUNR2SPR: int = 250
const BROCCOLASHRUNR3SPR: int = 251
const BROCCOLASHRUNR4SPR: int = 252
const BROCCOLASHSMASHR1SPR: int = 253
const BROCCOLASHSMASHR2SPR: int = 254
const BROCCOLASHSMASHR3SPR: int = 255
const BROCCOLASHSMASHR4SPR: int = 256
const TOMATOOTHL1SPR: int = 257
const TOMATOOTHL2SPR: int = 258
const TOMATOOTHR1SPR: int = 259
const TOMATOOTHR2SPR: int = 260
const CARROTRUNL1SPR: int = 261
const CARROTRUNL2SPR: int = 262
const CARROTRUNL3SPR: int = 263
const CARROTRUNL4SPR: int = 264
const CARROTLEAPL1SPR: int = 265
const CARROTRUNR1SPR: int = 266
const CARROTRUNR2SPR: int = 267
const CARROTRUNR3SPR: int = 268
const CARROTRUNR4SPR: int = 269
const CARROTLEAPR1SPR: int = 270
const ASPARAGUSRUNL1SPR: int = 271
const ASPARAGUSRUNL2SPR: int = 272
const ASPARAGUSRUNL3SPR: int = 273
const ASPARAGUSRUNL4SPR: int = 274
const ASPARAGUSRUNR1SPR: int = 275
const ASPARAGUSRUNR2SPR: int = 276
const ASPARAGUSRUNR3SPR: int = 277
const ASPARAGUSRUNR4SPR: int = 278
const GRAPEONVINESPR: int = 279
const GRAPEFALLINGSPR: int = 280
const TATERTROOPWALKR1SPR: int = 281
const TATERTROOPWALKR2SPR: int = 282
const TATERTROOPWALKR3SPR: int = 283
const TATERTROOPWALKR4SPR: int = 284
const TATERTROOPLUNGER1SPR: int = 285
const TATERTROOPLUNGER2SPR: int = 286
const TATERTROOPWALKL1SPR: int = 287
const TATERTROOPWALKL2SPR: int = 288
const TATERTROOPWALKL3SPR: int = 289
const TATERTROOPWALKL4SPR: int = 290
const TATERTROOPLUNGEL1SPR: int = 291
const TATERTROOPLUNGEL2SPR: int = 292
const CANTCARTL1SPR: int = 293
const CANTCARTL2SPR: int = 294
const FRENCHYRUNR1SPR: int = 295
const FRENCHYRUNR2SPR: int = 296
const FRENCHYRUNR3SPR: int = 297
const FRENCHYRUNR4SPR: int = 298
const FRENCHYTHROWR1SPR: int = 299
const FRENCHYTHROWR2SPR: int = 300
const FRENCHYRUNL1SPR: int = 301
const FRENCHYRUNL2SPR: int = 302
const FRENCHYRUNL3SPR: int = 303
const FRENCHYRUNL4SPR: int = 304
const FRENCHYTHROWL1SPR: int = 305
const FRENCHYTHROWL2SPR: int = 306
const FRENCHFRY1SPR: int = 307
const FRENCHFRY2SPR: int = 308
const MELONLIPSR1SPR: int = 309
const MELONLIPSR2SPR: int = 310
const MELONLIPSL1SPR: int = 311
const MELONLIPSL2SPR: int = 312
const MELONLIPSD1SPR: int = 313
const MELONLIPSD2SPR: int = 314
const MELONSEEDR1SPR: int = 315
const MELONSEEDR2SPR: int = 316
const MELONSEEDL1SPR: int = 317
const MELONSEEDL2SPR: int = 318
const MELONSEEDD1SPR: int = 319
const MELONSEEDD2SPR: int = 320
const SQUASHERWALKR1SPR: int = 321
const SQUASHERWALKR2SPR: int = 322
const SQUASHERJUMPR1SPR: int = 323
const SQUASHERJUMPR2SPR: int = 324
const SQUASHERWALKL1SPR: int = 325
const SQUASHERWALKL2SPR: int = 326
const SQUASHERJUMPL1SPR: int = 327
const SQUASHERJUMPL2SPR: int = 328
const APELWALKR1SPR: int = 329
const APELWALKR2SPR: int = 330
const APELWALKR3SPR: int = 331
const APELWALKL1SPR: int = 332
const APELWALKL2SPR: int = 333
const APELWALKL3SPR: int = 334
const APELSHINNY1SPR: int = 335
const APELSHINNY2SPR: int = 336
const APELSLIDE1SPR: int = 337
const APELSLIDE2SPR: int = 338
const APELSLIDE3SPR: int = 339
const APELSLIDE4SPR: int = 340
const PEAPODRUNR1SPR: int = 341
const PEAPODRUNR2SPR: int = 342
const PEAPODRUNR3SPR: int = 343
const PEAPODRUNR4SPR: int = 344
const PEAPODSPITRSPR: int = 345
const PEAPODRUNL1SPR: int = 346
const PEAPODRUNL2SPR: int = 347
const PEAPODRUNL3SPR: int = 348
const PEAPODRUNL4SPR: int = 349
const PEAPODSPITLSPR: int = 350
const PEABRAINWALKR1SPR: int = 351
const PEABRAINWALKR2SPR: int = 352
const PEABRAINWALKR3SPR: int = 353
const PEABRAINWALKR4SPR: int = 354
const PEABRAINWALKL1SPR: int = 355
const PEABRAINWALKL2SPR: int = 356
const PEABRAINWALKL3SPR: int = 357
const PEABRAINWALKL4SPR: int = 358
const BOOBUSWALKL1SPR: int = 359
const BOOBUSWALKL2SPR: int = 360
const BOOBUSWALKL3SPR: int = 361
const BOOBUSWALKL4SPR: int = 362
const BOOBUSWALKR1SPR: int = 363
const BOOBUSWALKR2SPR: int = 364
const BOOBUSWALKR3SPR: int = 365
const BOOBUSWALKR4SPR: int = 366
const BOOBUSJUMPSPR: int = 367
const CONTROLS_LUMP_START: int = 4
const CONTROLS_LUMP_END: int = 68
const KEEN_LUMP_START: int = 72
const KEEN_LUMP_END: int = 212
const WORLDKEEN_LUMP_START: int = 213
const WORLDKEEN_LUMP_END: int = 240
const BROCCOLASH_LUMP_START: int = 241
const BROCCOLASH_LUMP_END: int = 256
const TOMATO_LUMP_START: int = 257
const TOMATO_LUMP_END: int = 260
const CARROT_LUMP_START: int = 261
const CARROT_LUMP_END: int = 270
const ASPAR_LUMP_START: int = 271
const ASPAR_LUMP_END: int = 278
const GRAPE_LUMP_START: int = 279
const GRAPE_LUMP_END: int = 280
const TATER_LUMP_START: int = 281
const TATER_LUMP_END: int = 292
const CANTA_LUMP_START: int = 293
const CANTA_LUMP_END: int = 294
const FRENCHY_LUMP_START: int = 295
const FRENCHY_LUMP_END: int = 308
const MELONLIPS_LUMP_START: int = 309
const MELONLIPS_LUMP_END: int = 320
const SQUASHER_LUMP_START: int = 321
const SQUASHER_LUMP_END: int = 328
const APEL_LUMP_START: int = 329
const APEL_LUMP_END: int = 340
const PEAS_LUMP_START: int = 341
const PEAS_LUMP_END: int = 358
const BOOBUS_LUMP_START: int = 359
const BOOBUS_LUMP_END: int = 367
const NUMCHUNKS: int = 3016
const NUMFONT: int = 1
const NUMFONTM: int = 0
const NUMPICS: int = 65
const NUMPICM: int = 2
const NUMSPRITES: int = 297
const NUMTILE8: int = 72
const NUMTILE8M: int = 36
const NUMTILE16: int = 1440
const NUMTILE16M: int = 1206
const NUMTILE32: int = 0
const NUMTILE32M: int = 0
const STRUCTPIC: int = 0
const STRUCTPICM: int = 1
const STRUCTSPRITE: int = 2
const STARTFONT: int = 3
const STARTFONTM: int = 4
const STARTPICS: int = 4
const STARTPICM: int = 69
const STARTSPRITES: int = 71
const STARTTILE8: int = 368
const STARTTILE8M: int = 369
const STARTTILE16: int = 370
const STARTTILE16M: int = 1810
const STARTTILE32: int = 3016
const STARTTILE32M: int = 3016

# audiokdr.h
const NUMSOUNDS: int = 28
const NUMSNDCHUNKS: int = 84
const KEENWALK1SND: int = 0
const KEENWALK2SND: int = 1
const JUMPSND: int = 2
const LANDSND: int = 3
const THROWSND: int = 4
const DIVESND: int = 5
const GETPOWERSND: int = 6
const GETPOINTSSND: int = 7
const GETBOMBSND: int = 8
const FLOWERPOWERSND: int = 9
const UNFLOWERPOWERSND: int = 10
const ENTERLEVELSND: int = 11
const WAKEUPSND: int = 12
const LEVELDONESND: int = 13
const NOWAYSND: int = 14
const HITHEADSND: int = 15
const TATERSWINGSND: int = 16
const BOUNCESND: int = 17
const EXTRAKEENSND: int = 18
const OPENDOORSND: int = 19
const THROWBOMBSND: int = 20
const BOMBBOOMSND: int = 21
const BOOBUSGONESND: int = 22
const GETKEYSND: int = 23
const GRAPESCREAMSND: int = 24
const PLUMMETSND: int = 25
const CLICKSND: int = 26
const TICKSND: int = 27
const STARTPCSOUNDS: int = 0
const STARTADLIBSOUNDS: int = 28
const STARTDIGISOUNDS: int = 56
const STARTMUSIC: int = 84

# id_mm.h
const SAVENEARHEAP: int = 0x400
const SAVEFARHEAP: int = 0
const BUFFERSIZE: int = 0x1000

# id_ca.h
const NUMMAPS: int = 30
const SPEED: int = 502
const ANIM: int = (SPEED + NUMTILE16)
const NORTHWALL: int = (ANIM + NUMTILE16)
const EASTWALL: int = (NORTHWALL + NUMTILE16M)
const SOUTHWALL: int = (EASTWALL + NUMTILE16M)
const WESTWALL: int = (SOUTHWALL + NUMTILE16M)
const MANIM: int = (WESTWALL + NUMTILE16M)
const INTILE: int = (MANIM + NUMTILE16M)
const MSPEED: int = (INTILE + NUMTILE16M)

# id_vw.h
const G_P_SHIFT: int = 4
const SCREENWIDTH_EGA: int = 64
const CHARWIDTH_EGA: int = 1
const TILEWIDTH_EGA: int = 2
const SCREENWIDTH_CGA: int = 128
const CHARWIDTH_CGA: int = 2
const TILEWIDTH_CGA: int = 4
const VIRTUALHEIGHT: int = 300
const VIRTUALWIDTH: int = 512
const MAXSHIFTS_CGA: int = 1
const WHITE_CGA: int = 3
const BLACK_CGA: int = 0
const FIRSTCOLOR_CGA: int = 1
const SECONDCOLOR_CGA: int = 2
const F_WHITE_CGA: int = 0
const F_BLACK_CGA: int = 3
const F_FIRSTCOLOR_CGA: int = 2
const F_SECONDCOLOR_CGA: int = 1
const MAXSHIFTS_EGA: int = 8
const WHITE_EGA: int = 15
const BLACK_EGA: int = 0
const FIRSTCOLOR_EGA: int = 1
const SECONDCOLOR_EGA: int = 12
const F_WHITE_EGA: int = 0
const F_BLACK_EGA: int = 15
const F_FIRSTCOLOR_EGA: int = 14
const F_SECONDCOLOR_EGA: int = 3
const SC_INDEX: int = 0x3C4
const SC_RESET: int = 0
const SC_CLOCK: int = 1
const SC_MAPMASK: int = 2
const SC_CHARMAP: int = 3
const SC_MEMMODE: int = 4
const CRTC_INDEX: int = 0x3D4
const CRTC_H_TOTAL: int = 0
const CRTC_H_DISPEND: int = 1
const CRTC_H_BLANK: int = 2
const CRTC_H_ENDBLANK: int = 3
const CRTC_H_RETRACE: int = 4
const CRTC_H_ENDRETRACE: int = 5
const CRTC_V_TOTAL: int = 6
const CRTC_OVERFLOW: int = 7
const CRTC_ROWSCAN: int = 8
const CRTC_MAXSCANLINE: int = 9
const CRTC_CURSORSTART: int = 10
const CRTC_CURSOREND: int = 11
const CRTC_STARTHIGH: int = 12
const CRTC_STARTLOW: int = 13
const CRTC_CURSORHIGH: int = 14
const CRTC_CURSORLOW: int = 15
const CRTC_V_RETRACE: int = 16
const CRTC_V_ENDRETRACE: int = 17
const CRTC_V_DISPEND: int = 18
const CRTC_OFFSET: int = 19
const CRTC_UNDERLINE: int = 20
const CRTC_V_BLANK: int = 21
const CRTC_V_ENDBLANK: int = 22
const CRTC_MODE: int = 23
const CRTC_LINECOMPARE: int = 24
const GC_INDEX: int = 0x3CE
const GC_SETRESET: int = 0
const GC_ENABLESETRESET: int = 1
const GC_COLORCOMPARE: int = 2
const GC_DATAROTATE: int = 3
const GC_READMAP: int = 4
const GC_MODE: int = 5
const GC_MISCELLANEOUS: int = 6
const GC_COLORDONTCARE: int = 7
const GC_BITMASK: int = 8
const ATR_INDEX: int = 0x3c0
const ATR_MODE: int = 16
const ATR_OVERSCAN: int = 17
const ATR_COLORPLANEENABLE: int = 18
const ATR_PELPAN: int = 19
const ATR_COLORSELECT: int = 20
const WAITFORVBL: int = 1
# cardtype
const NOcard: int = 0
const MDAcard: int = NOcard + 1
const CGAcard: int = MDAcard + 1
const EGAcard: int = CGAcard + 1
const MCGAcard: int = EGAcard + 1
const VGAcard: int = MCGAcard + 1
const HGCcard: int = 0x80
const HGCPcard: int = HGCcard + 1
const HICcard: int = HGCPcard + 1

# id_rf.h
const MINTICS: int = 2
const MAXTICS: int = 6
const MAPBORDER: int = 2
const MAXSPRITES: int = 100
const MAXANIMTILES: int = 90
const MAXANIMTYPES: int = 50
const MAXMAPHEIGHT: int = 128
const PRIORITIES: int = 4
const MASKEDTILEPRIORITY: int = 3
const TILEGLOBAL: int = 256
const PIXGLOBAL: int = 16
const G_T_SHIFT: int = 8
const P_T_SHIFT: int = 4
const PORTTILESWIDE: int = 21
const PORTTILESHIGH: int = 14
const UPDATEWIDE: int = (PORTTILESWIDE + 1)
const UPDATEHIGH: int = PORTTILESHIGH
# drawtype
const spritedraw: int = 0
const maskdraw: int = spritedraw + 1

# id_in.h
const MaxPlayers: int = 4
const MaxKbds: int = 2
const MaxJoys: int = 2
const NumCodes: int = 128
const sc_None: int = 0
const sc_Bad: int = 0xff
const sc_Return: int = 0x1c
const sc_Escape: int = 0x01
const sc_Space: int = 0x39
const sc_BackSpace: int = 0x0e
const sc_Tab: int = 0x0f
const sc_Alt: int = 0x38
const sc_Control: int = 0x1d
const sc_CapsLock: int = 0x3a
const sc_LShift: int = 0x2a
const sc_RShift: int = 0x36
const sc_UpArrow: int = 0x48
const sc_DownArrow: int = 0x50
const sc_LeftArrow: int = 0x4b
const sc_RightArrow: int = 0x4d
const sc_Insert: int = 0x52
const sc_Delete: int = 0x53
const sc_Home: int = 0x47
const sc_End: int = 0x4f
const sc_PgUp: int = 0x49
const sc_PgDn: int = 0x51
const sc_F1: int = 0x3b
const sc_F2: int = 0x3c
const sc_F3: int = 0x3d
const sc_F4: int = 0x3e
const sc_F5: int = 0x3f
const sc_F6: int = 0x40
const sc_F7: int = 0x41
const sc_F8: int = 0x42
const sc_F9: int = 0x43
const sc_F10: int = 0x44
const sc_F11: int = 0x57
const sc_F12: int = 0x59
const sc_A: int = 0x1e
const sc_B: int = 0x30
const sc_C: int = 0x2e
const sc_D: int = 0x20
const sc_E: int = 0x12
const sc_F: int = 0x21
const sc_G: int = 0x22
const sc_H: int = 0x23
const sc_I: int = 0x17
const sc_J: int = 0x24
const sc_K: int = 0x25
const sc_L: int = 0x26
const sc_M: int = 0x32
const sc_N: int = 0x31
const sc_O: int = 0x18
const sc_P: int = 0x19
const sc_Q: int = 0x10
const sc_R: int = 0x13
const sc_S: int = 0x1f
const sc_T: int = 0x14
const sc_U: int = 0x16
const sc_V: int = 0x2f
const sc_W: int = 0x11
const sc_X: int = 0x2d
const sc_Y: int = 0x15
const sc_Z: int = 0x2c
const key_None: int = 0
const key_Return: int = 0x0d
const key_Escape: int = 0x1b
const key_Space: int = 0x20
const key_BackSpace: int = 0x08
const key_Tab: int = 0x09
const key_Delete: int = 0x7f
# Demo
const demo_Off: int = 0
const demo_Record: int = demo_Off + 1
const demo_Playback: int = demo_Record + 1
const demo_PlayDone: int = demo_Playback + 1
# ControlType
const ctrl_Keyboard: int = 0
const ctrl_Keyboard1: int = ctrl_Keyboard
const ctrl_Keyboard2: int = ctrl_Keyboard1 + 1
const ctrl_Joystick: int = ctrl_Keyboard2 + 1
const ctrl_Joystick1: int = ctrl_Joystick
const ctrl_Joystick2: int = ctrl_Joystick1 + 1
const ctrl_Mouse: int = ctrl_Joystick2 + 1
# Motion
const motion_Left: int = - 1
const motion_Up: int = - 1
const motion_None: int = 0
const motion_Right: int = 1
const motion_Down: int = 1
# Direction
const dir_North: int = 0
const dir_NorthEast: int = dir_North + 1
const dir_East: int = dir_NorthEast + 1
const dir_SouthEast: int = dir_East + 1
const dir_South: int = dir_SouthEast + 1
const dir_SouthWest: int = dir_South + 1
const dir_West: int = dir_SouthWest + 1
const dir_NorthWest: int = dir_West + 1
const dir_None: int = dir_NorthWest + 1

# id_sd.h
const REFKEEN_SD_ENABLE_MUSIC: int = 0
const REFKEEN_SD_ENABLE_SOUNDSOURCE: int = 0
const REFKEEN_SD_ENABLE_SOUNDBLASTER: int = 0
const TickBase: int = 70
const pcTimer: int = 0x42
const pcTAccess: int = 0x43
const pcSpeaker: int = 0x61
const pcSpkBits: int = 3
const sbReset: int = 0x206
const sbReadData: int = 0x20a
const sbWriteCmd: int = 0x20c
const sbWriteData: int = 0x20c
const sbWriteStat: int = 0x20c
const sbDataAvail: int = 0x20e
const alChar: int = 0x20
const alScale: int = 0x40
const alAttack: int = 0x60
const alSus: int = 0x80
const alWave: int = 0xe0
const alFreqL: int = 0xa0
const alFreqH: int = 0xb0
const alFeedCon: int = 0xc0
const alEffects: int = 0xbd
const sqMaxTracks: int = 10
const sqMaxMoods: int = 1
const sev_Null: int = 0
const sev_NoteOff: int = 1
const sev_NoteOn: int = 2
const sev_NotePitch: int = 3
const sev_NewInst: int = 4
const sev_NewPerc: int = 5
const sev_PercOn: int = 6
const sev_PercOff: int = 7
const sev_SeqEnd: int = - 1
const sqmode_Normal: int = 0
const sqmode_FadeIn: int = 1
const sqmode_FadeOut: int = 2
const sqMaxFade: int = 64
# SDMode
const sdm_Off: int = 0
const sdm_PC: int = sdm_Off + 1
const sdm_AdLib: int = sdm_PC + 1
const sdm_SoundBlaster: int = sdm_AdLib + 1
const sdm_SoundSource: int = sdm_SoundBlaster + 1
# SMMode
const smm_Off: int = 0
const smm_AdLib: int = smm_Off + 1

# id_us.h
const MaxString: int = 128
# GameDiff
const gd_Continue: int = 0
const gd_Easy: int = gd_Continue + 1
const gd_Normal: int = gd_Easy + 1
const gd_Hard: int = gd_Normal + 1

# sl_file.h
const SOFTLIB_VER: int = 2
const SL_FILENAMESIZE: int = 16

# jam_io.h
const SRC_FILE: int = (0x0001)
const SRC_FFILE: int = (0x0002)
const SRC_MEM: int = (0x0004)
const SRC_BFILE: int = (0x0008)
const SRC_TYPES: int = (SRC_FILE | SRC_FFILE | SRC_MEM | SRC_BFILE)
const DEST_FILE: int = (0x0100)
const DEST_FFILE: int = (0x0200)
const DEST_MEM: int = (0x0400)
const DEST_IMEM: int = (0x0800)
const DEST_TYPES: int = (DEST_FILE | DEST_FFILE | DEST_MEM | DEST_IMEM)

# kd_def.h
const FRILLS: int = 0
const MAXACTORS: int = MAXSPRITES
const ACCGRAVITY: int = 3
const SPDMAXY: int = 80
const BLOCKSIZE: int = (8 * PIXGLOBAL)
const SCROLLEAST: int = (TILEGLOBAL * 11)
const SCROLLWEST: int = (TILEGLOBAL * 9)
const SCROLLSOUTH: int = (TILEGLOBAL * 8)
const SCROLLNORTH: int = (TILEGLOBAL * 4)
const CLIPMOVE: int = 24
const GAMELEVELS: int = 17
const COMPAT_OBJ_CONVERSION_SIZE: int = 76
# exittype
const notdone: int = 0
const resetgame: int = notdone + 1
const levelcomplete: int = resetgame + 1
const warptolevel: int = levelcomplete + 1
const died: int = warptolevel + 1
const victorious: int = died + 1
# classtype
const nothing: int = 0
const keenobj: int = nothing + 1
const powerobj: int = keenobj + 1
const doorobj: int = powerobj + 1
const bonusobj: int = doorobj + 1
const broccoobj: int = bonusobj + 1
const tomatobj: int = broccoobj + 1
const carrotobj: int = tomatobj + 1
const celeryobj: int = carrotobj + 1
const asparobj: int = celeryobj + 1
const grapeobj: int = asparobj + 1
const taterobj: int = grapeobj + 1
const cartobj: int = taterobj + 1
const frenchyobj: int = cartobj + 1
const melonobj: int = frenchyobj + 1
const turnipobj: int = melonobj + 1
const cauliobj: int = turnipobj + 1
const brusselobj: int = cauliobj + 1
const mushroomobj: int = brusselobj + 1
const squashobj: int = mushroomobj + 1
const apelobj: int = squashobj + 1
const peapodobj: int = apelobj + 1
const peabrainobj: int = peapodobj + 1
const boobusobj: int = peabrainobj + 1
const shotobj: int = boobusobj + 1
const inertobj: int = shotobj + 1
# progresstype
const step: int = 0
const slide: int = step + 1
const think: int = slide + 1
const stepthink: int = think + 1
const slidethink: int = stepthink + 1
# activetype
const no: int = 0
const yes: int = no + 1
const allways: int = yes + 1
const removable: int = allways + 1
# ---- END GENERATED CONSTANTS ----
# ---- GENERATED by tools/gen_drm_decl.py: forward declarations (do not edit) ----

# gelib.c
func FreeShape(_p0):
	return _undefined(&"FreeShape")
func UnpackEGAShapeToScreen(_p0, _p1, _p2):
	return _undefined(&"UnpackEGAShapeToScreen")
func VerifyReadOnly(_p0):
	return _undefined(&"VerifyReadOnly")
func InitBufferedIO(_p0, _p1):
	return _undefined(&"InitBufferedIO")
func FreeBufferedIO(_p0):
	return _undefined(&"FreeBufferedIO")
func bio_readch(_p0):
	return _undefined(&"bio_readch")
func bio_fillbuffer(_p0):
	return _undefined(&"bio_fillbuffer")
func MoveGfxDst(_p0, _p1):
	return _undefined(&"MoveGfxDst")

# id_ca.c
func CAL_GetGrChunkLength(_p0):
	return _undefined(&"CAL_GetGrChunkLength")
func CA_FarRead(_p0, _p1, _p2):
	return _undefined(&"CA_FarRead")
func CA_FarWrite(_p0, _p1, _p2):
	return _undefined(&"CA_FarWrite")
func CA_LoadFile(_p0, _p1):
	return _undefined(&"CA_LoadFile")
func CAL_OptimizeNodes(_p0):
	return _undefined(&"CAL_OptimizeNodes")
func CAL_HuffExpand(_p0, _p1, _p2, _p3):
	return _undefined(&"CAL_HuffExpand")
func CA_RLEWCompress(_p0, _p1, _p2, _p3):
	return _undefined(&"CA_RLEWCompress")
func CA_RLEWexpand(_p0, _p1, _p2, _p3):
	return _undefined(&"CA_RLEWexpand")
func CAL_SetupGrFile():
	return _undefined(&"CAL_SetupGrFile")
func CAL_FreeGrFile():
	return _undefined(&"CAL_FreeGrFile")
func CA_ReloadGrChunks():
	return _undefined(&"CA_ReloadGrChunks")
func CAL_SetupMapFile():
	return _undefined(&"CAL_SetupMapFile")
func CAL_SetupAudioFile():
	return _undefined(&"CAL_SetupAudioFile")
func CA_Startup():
	return _undefined(&"CA_Startup")
func CA_Shutdown():
	return _undefined(&"CA_Shutdown")
func CA_CacheAudioChunk(_p0):
	return _undefined(&"CA_CacheAudioChunk")
func CA_LoadAllSounds():
	return _undefined(&"CA_LoadAllSounds")
func CAL_ShiftSprite(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"CAL_ShiftSprite")
func CAL_CacheSprite(_p0, _p1):
	return _undefined(&"CAL_CacheSprite")
func CAL_ExpandGrChunk(_p0, _p1):
	return _undefined(&"CAL_ExpandGrChunk")
func CAL_ReadGrChunk(_p0):
	return _undefined(&"CAL_ReadGrChunk")
func CA_CacheGrChunk(_p0):
	return _undefined(&"CA_CacheGrChunk")
func CA_CacheMap(_p0):
	return _undefined(&"CA_CacheMap")
func CA_UpLevel():
	return _undefined(&"CA_UpLevel")
func CA_DownLevel():
	return _undefined(&"CA_DownLevel")
func CA_ClearMarks():
	return _undefined(&"CA_ClearMarks")
func CA_ClearAllMarks():
	return _undefined(&"CA_ClearAllMarks")
func CA_CacheMarks(_p0, _p1):
	return _undefined(&"CA_CacheMarks")
func RefKeen_Patch_id_ca():
	return _undefined(&"RefKeen_Patch_id_ca")
func RefKeen_Load_Embedded_Resources_From_kdreams_exe():
	return _undefined(&"RefKeen_Load_Embedded_Resources_From_kdreams_exe")

# id_in.c
func IN_GetJoyAbs(_p0, _p1, _p2):
	return _undefined(&"IN_GetJoyAbs")
func IN_GetJoyButtonsDB(_p0):
	return _undefined(&"IN_GetJoyButtonsDB")
func IN_SetupJoy(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"IN_SetupJoy")
func IN_Startup():
	return _undefined(&"IN_Startup")
func IN_Default(_p0, _p1):
	return _undefined(&"IN_Default")
func IN_Shutdown():
	return _undefined(&"IN_Shutdown")
func IN_SetKeyHook(_p0):
	return _undefined(&"IN_SetKeyHook")
func IN_ClearKeysDown():
	return _undefined(&"IN_ClearKeysDown")
func IN_ReadCursor(_p0):
	return _undefined(&"IN_ReadCursor")
func IN_ReadControl(_p0, _p1):
	return _undefined(&"IN_ReadControl")
func IN_SetControlType(_p0, _p1):
	return _undefined(&"IN_SetControlType")
func IN_StartDemoRecord(_p0):
	return _undefined(&"IN_StartDemoRecord")
func IN_StartDemoPlayback(_p0, _p1):
	return _undefined(&"IN_StartDemoPlayback")
func IN_StopDemo():
	return _undefined(&"IN_StopDemo")
func IN_FreeDemoBuffer():
	return _undefined(&"IN_FreeDemoBuffer")
func IN_GetScanName(_p0):
	return _undefined(&"IN_GetScanName")
func IN_WaitForKey():
	return _undefined(&"IN_WaitForKey")
func IN_WaitForASCII():
	return _undefined(&"IN_WaitForASCII")
func IN_AckBack():
	return _undefined(&"IN_AckBack")
func IN_Ack():
	return _undefined(&"IN_Ack")
func IN_IsUserInput():
	return _undefined(&"IN_IsUserInput")
func IN_UserInput(_p0, _p1):
	return _undefined(&"IN_UserInput")

# id_mm.c
func MM_Startup():
	return _undefined(&"MM_Startup")
func MM_Shutdown():
	return _undefined(&"MM_Shutdown")
func MM_GetPtr(_p0, _p1):
	return _undefined(&"MM_GetPtr")
func MM_FreePtr(_p0):
	return _undefined(&"MM_FreePtr")
func MM_SetPurge(_p0, _p1):
	return _undefined(&"MM_SetPurge")
func MM_SetLock(_p0, _p1):
	return _undefined(&"MM_SetLock")
func MM_SortMem():
	return _undefined(&"MM_SortMem")
func MM_ShowMemory():
	return _undefined(&"MM_ShowMemory")
func MM_UnusedMemory():
	return _undefined(&"MM_UnusedMemory")
func MM_TotalFree():
	return _undefined(&"MM_TotalFree")
func MM_GetAttributes(_p0):
	return _undefined(&"MM_GetAttributes")
func MM_SetAttributes(_p0, _p1):
	return _undefined(&"MM_SetAttributes")
func RefKeen_Patch_id_mm():
	return _undefined(&"RefKeen_Patch_id_mm")

# id_rf.c
func RF_Startup():
	return _undefined(&"RF_Startup")
func RF_Shutdown():
	return _undefined(&"RF_Shutdown")
func RF_NewMap():
	return _undefined(&"RF_NewMap")
func RF_MarkTileGraphics():
	return _undefined(&"RF_MarkTileGraphics")
func RFL_InitAnimList():
	return _undefined(&"RFL_InitAnimList")
func RFL_CheckForAnimTile(_p0, _p1):
	return _undefined(&"RFL_CheckForAnimTile")
func RFL_RemoveAnimsOnX(_p0):
	return _undefined(&"RFL_RemoveAnimsOnX")
func RFL_RemoveAnimsOnY(_p0):
	return _undefined(&"RFL_RemoveAnimsOnY")
func RFL_AnimateTiles():
	return _undefined(&"RFL_AnimateTiles")
func RFL_InitSpriteList():
	return _undefined(&"RFL_InitSpriteList")
func RF_RefreshSpriteList():
	return _undefined(&"RF_RefreshSpriteList")
func RFL_CalcOriginStuff(_p0, _p1):
	return _undefined(&"RFL_CalcOriginStuff")
func RF_SetRefreshHook(_p0):
	return _undefined(&"RF_SetRefreshHook")
func RFL_NewRow(_p0):
	return _undefined(&"RFL_NewRow")
func RF_ForceRefresh():
	return _undefined(&"RF_ForceRefresh")
func RF_NewPosition_EGA(_p0, _p1):
	return _undefined(&"RF_NewPosition_EGA")
func RFL_OldRow(_p0, _p1, _p2):
	return _undefined(&"RFL_OldRow")
func RF_Scroll_EGA(_p0, _p1):
	return _undefined(&"RF_Scroll_EGA")
func RF_PlaceSprite_EGA(_p0, _p1, _p2, _p3, _p4, _p5):
	return _undefined(&"RF_PlaceSprite_EGA")
func KL_GhostSpriteHelper(_p0, _p1):
	return _undefined(&"KL_GhostSpriteHelper")
func RF_RemoveSprite_EGA(_p0):
	return _undefined(&"RF_RemoveSprite_EGA")
func RFL_EraseBlocks_EGA():
	return _undefined(&"RFL_EraseBlocks_EGA")
func RFL_UpdateSprites_EGA():
	return _undefined(&"RFL_UpdateSprites_EGA")
func RF_Refresh_EGA():
	return _undefined(&"RF_Refresh_EGA")
func RF_NewPosition_CGA(_p0, _p1):
	return _undefined(&"RF_NewPosition_CGA")
func RF_Scroll_CGA(_p0, _p1):
	return _undefined(&"RF_Scroll_CGA")
func RF_PlaceSprite_CGA(_p0, _p1, _p2, _p3, _p4, _p5):
	return _undefined(&"RF_PlaceSprite_CGA")
func RF_RemoveSprite_CGA(_p0):
	return _undefined(&"RF_RemoveSprite_CGA")
func RFL_EraseBlocks_CGA():
	return _undefined(&"RFL_EraseBlocks_CGA")
func RFL_UpdateSprites_CGA():
	return _undefined(&"RFL_UpdateSprites_CGA")
func RF_Refresh_CGA():
	return _undefined(&"RF_Refresh_CGA")
func RefKeen_Patch_id_rf():
	return _undefined(&"RefKeen_Patch_id_rf")

# id_rf_a.c
func RFL_NewTile_CGA(_p0):
	return _undefined(&"RFL_NewTile_CGA")
func RFL_NewTile_EGA(_p0):
	return _undefined(&"RFL_NewTile_EGA")
func RFL_UpdateTiles():
	return _undefined(&"RFL_UpdateTiles")
func RFL_MaskForegroundTiles():
	return _undefined(&"RFL_MaskForegroundTiles")
func RefKeen_Patch_id_rf_a():
	return _undefined(&"RefKeen_Patch_id_rf_a")

# id_sd.c
func alOut(_p0, _p1):
	return _undefined(&"alOut")
func SD_SetSoundMode(_p0):
	return _undefined(&"SD_SetSoundMode")
func SD_SetMusicMode(_p0):
	return _undefined(&"SD_SetMusicMode")
func SD_Startup():
	return _undefined(&"SD_Startup")
func SD_Default(_p0, _p1, _p2):
	return _undefined(&"SD_Default")
func SD_Shutdown():
	return _undefined(&"SD_Shutdown")
func SD_SetUserHook(_p0):
	return _undefined(&"SD_SetUserHook")
func SD_PlaySound(_p0):
	return _undefined(&"SD_PlaySound")
func SD_SoundPlaying():
	return _undefined(&"SD_SoundPlaying")
func SD_StopSound():
	return _undefined(&"SD_StopSound")
func SD_WaitSoundDone():
	return _undefined(&"SD_WaitSoundDone")
func SD_StartMusic(_p0):
	return _undefined(&"SD_StartMusic")
func SD_FadeOutMusic():
	return _undefined(&"SD_FadeOutMusic")
func SD_MusicPlaying():
	return _undefined(&"SD_MusicPlaying")
func SD_GetTimeCount():
	return _undefined(&"SD_GetTimeCount")
func SD_SetTimeCount(_p0):
	return _undefined(&"SD_SetTimeCount")
func SD_AddToTimeCount(_p0):
	return _undefined(&"SD_AddToTimeCount")
func SD_TimeCountWaitFromSrc(_p0, _p1):
	return _undefined(&"SD_TimeCountWaitFromSrc")

# id_us.c
func US_SetLoadSaveHooks(_p0, _p1, _p2):
	return _undefined(&"US_SetLoadSaveHooks")
func US_Startup():
	return _undefined(&"US_Startup")
func US_Setup():
	return _undefined(&"US_Setup")
func US_Shutdown():
	return _undefined(&"US_Shutdown")
func US_CheckParm(_p0, _p1):
	return _undefined(&"US_CheckParm")
func US_TextScreen():
	return _undefined(&"US_TextScreen")
func US_UpdateTextScreen():
	return _undefined(&"US_UpdateTextScreen")
func US_FinishTextScreen():
	return _undefined(&"US_FinishTextScreen")
func US_SetPrintRoutines(_p0, _p1):
	return _undefined(&"US_SetPrintRoutines")
func US_Print(_p0):
	return _undefined(&"US_Print")
func US_PrintUnsigned(_p0):
	return _undefined(&"US_PrintUnsigned")
func US_PrintSigned(_p0):
	return _undefined(&"US_PrintSigned")
func US_PrintCentered(_p0):
	return _undefined(&"US_PrintCentered")
func US_CPrintLine(_p0, _p1):
	return _undefined(&"US_CPrintLine")
func US_CPrint(_p0):
	return _undefined(&"US_CPrint")
func US_ClearWindow():
	return _undefined(&"US_ClearWindow")
func US_DrawWindow(_p0, _p1, _p2, _p3):
	return _undefined(&"US_DrawWindow")
func US_CenterWindow(_p0, _p1):
	return _undefined(&"US_CenterWindow")
func US_CenterSaveWindow(_p0, _p1, _p2):
	return _undefined(&"US_CenterSaveWindow")
func US_RestoreSaveWindow(_p0):
	return _undefined(&"US_RestoreSaveWindow")
func US_SaveWindow(_p0):
	return _undefined(&"US_SaveWindow")
func US_RestoreWindow(_p0):
	return _undefined(&"US_RestoreWindow")
func US_StartCursor():
	return _undefined(&"US_StartCursor")
func US_ShutCursor():
	return _undefined(&"US_ShutCursor")
func US_UpdateCursor():
	return _undefined(&"US_UpdateCursor")
func US_LineInput(_p0, _p1, _p2, _p3, _p4, _p5, _p6):
	return _undefined(&"US_LineInput")
func US_ControlPanel():
	return _undefined(&"US_ControlPanel")
func US_DisplayHighScores(_p0):
	return _undefined(&"US_DisplayHighScores")
func US_CheckHighScore(_p0, _p1):
	return _undefined(&"US_CheckHighScore")
func RefKeen_Patch_id_us():
	return _undefined(&"RefKeen_Patch_id_us")

# id_us_a.c
func US_InitRndT(_p0):
	return _undefined(&"US_InitRndT")
func US_RndT():
	return _undefined(&"US_RndT")

# id_vw.c
func VW_Startup():
	return _undefined(&"VW_Startup")
func VW_Shutdown():
	return _undefined(&"VW_Shutdown")
func VW_SetScreenMode(_p0):
	return _undefined(&"VW_SetScreenMode")
func VW_ColorBorder(_p0):
	return _undefined(&"VW_ColorBorder")
func VW_SetDefaultColors():
	return _undefined(&"VW_SetDefaultColors")
func VW_FadeOut():
	return _undefined(&"VW_FadeOut")
func VW_FadeIn():
	return _undefined(&"VW_FadeIn")
func VW_FadeUp():
	return _undefined(&"VW_FadeUp")
func VW_FadeDown():
	return _undefined(&"VW_FadeDown")
func VW_SetLineWidth(_p0):
	return _undefined(&"VW_SetLineWidth")
func VW_ClearVideo(_p0):
	return _undefined(&"VW_ClearVideo")
func VW_DrawPic(_p0, _p1, _p2):
	return _undefined(&"VW_DrawPic")
func VW_DrawMPic(_p0, _p1, _p2):
	return _undefined(&"VW_DrawMPic")
func VW_DrawSprite(_p0, _p1, _p2):
	return _undefined(&"VW_DrawSprite")
func VW_Hlin_EGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_Hlin_EGA")
func VW_Hlin_CGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_Hlin_CGA")
func VW_Bar_CGA(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"VW_Bar_CGA")
func VW_Bar_EGA(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"VW_Bar_EGA")
func VWL_MeasureString(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"VWL_MeasureString")
func VW_MeasurePropString(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_MeasurePropString")
func VW_MeasureMPropString(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_MeasureMPropString")
func VW_CGAFullUpdate():
	return _undefined(&"VW_CGAFullUpdate")
func VWL_DrawCursor():
	return _undefined(&"VWL_DrawCursor")
func VWL_EraseCursor():
	return _undefined(&"VWL_EraseCursor")
func VW_ShowCursor():
	return _undefined(&"VW_ShowCursor")
func VW_HideCursor():
	return _undefined(&"VW_HideCursor")
func VW_MoveCursor(_p0, _p1):
	return _undefined(&"VW_MoveCursor")
func VW_SetCursor(_p0):
	return _undefined(&"VW_SetCursor")
func VW_InitDoubleBuffer():
	return _undefined(&"VW_InitDoubleBuffer")
func VW_FixRefreshBuffer():
	return _undefined(&"VW_FixRefreshBuffer")
func VW_QuitDoubleBuffer():
	return _undefined(&"VW_QuitDoubleBuffer")
func VW_MarkUpdateBlock(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_MarkUpdateBlock")
func VW_UpdateScreen():
	return _undefined(&"VW_UpdateScreen")
func VWB_DrawTile8(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawTile8")
func VWB_DrawTile8M(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawTile8M")
func VWB_DrawTile16(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawTile16")
func VWB_DrawTile16M(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawTile16M")
func VWB_DrawPic(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawPic")
func VWB_DrawMPic(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawMPic")
func VWB_Bar(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"VWB_Bar")
func VWB_DrawPropString(_p0, _p1):
	return _undefined(&"VWB_DrawPropString")
func VWB_DrawSprite(_p0, _p1, _p2):
	return _undefined(&"VWB_DrawSprite")
func VWB_Plot(_p0, _p1, _p2):
	return _undefined(&"VWB_Plot")
func VWB_Hlin(_p0, _p1, _p2, _p3):
	return _undefined(&"VWB_Hlin")
func VWB_Vlin(_p0, _p1, _p2, _p3):
	return _undefined(&"VWB_Vlin")
func RefKeen_Patch_id_vw():
	return _undefined(&"RefKeen_Patch_id_vw")

# id_vw_a.c
func VW_VideoID():
	return _undefined(&"VW_VideoID")

# id_vw_ac.c
func VW_Plot_CGA(_p0, _p1, _p2):
	return _undefined(&"VW_Plot_CGA")
func VW_Vlin_CGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_Vlin_CGA")
func VW_DrawTile8_CGA(_p0, _p1, _p2):
	return _undefined(&"VW_DrawTile8_CGA")
func VW_MaskBlock_CGA(_p0, _p1, _p2, _p3, _p4, _p5):
	return _undefined(&"VW_MaskBlock_CGA")
func VW_ScreenToScreen_CGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_ScreenToScreen_CGA")
func VW_MemToScreen_CGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_MemToScreen_CGA")
func VW_ScreenToMem_CGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_ScreenToMem_CGA")
func VW_DrawPropString_CGA(_p0, _p1):
	return _undefined(&"VW_DrawPropString_CGA")
func RefKeen_Patch_id_vw_ac():
	return _undefined(&"RefKeen_Patch_id_vw_ac")

# id_vw_ae.c
func VW_Plot_EGA(_p0, _p1, _p2):
	return _undefined(&"VW_Plot_EGA")
func VW_Vlin_EGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_Vlin_EGA")
func VW_DrawTile8_EGA(_p0, _p1, _p2):
	return _undefined(&"VW_DrawTile8_EGA")
func VW_MaskBlock_EGA(_p0, _p1, _p2, _p3, _p4, _p5):
	return _undefined(&"VW_MaskBlock_EGA")
func VW_ScreenToScreen_EGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_ScreenToScreen_EGA")
func VW_MemToScreen_EGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_MemToScreen_EGA")
func VW_ScreenToMem_EGA(_p0, _p1, _p2, _p3):
	return _undefined(&"VW_ScreenToMem_EGA")
func VWL_UpdateScreenBlocks():
	return _undefined(&"VWL_UpdateScreenBlocks")
func VW_SetScreen_EGA(_p0, _p1):
	return _undefined(&"VW_SetScreen_EGA")
func VW_DrawPropString_EGA(_p0, _p1):
	return _undefined(&"VW_DrawPropString_EGA")
func RefKeen_Patch_id_vw_ae():
	return _undefined(&"RefKeen_Patch_id_vw_ae")

# jam_io.c
func WritePtr(_p0, _p1, _p2):
	return _undefined(&"WritePtr")
func ReadPtr(_p0, _p1):
	return _undefined(&"ReadPtr")

# kd_act1.c
func DoGravity(_p0):
	return _undefined(&"DoGravity")
func AccelerateX(_p0, _p1, _p2):
	return _undefined(&"AccelerateX")
func FrictionX(_p0):
	return _undefined(&"FrictionX")
func ProjectileThink(_p0):
	return _undefined(&"ProjectileThink")
func VelocityThink(_p0):
	return _undefined(&"VelocityThink")
func DrawReact(_p0):
	return _undefined(&"DrawReact")
func DrawReact2(_p0):
	return _undefined(&"DrawReact2")
func DrawReact3(_p0):
	return _undefined(&"DrawReact3")
func ChangeState(_p0, _p1):
	return _undefined(&"ChangeState")
func WalkReact(_p0):
	return _undefined(&"WalkReact")
func SpawnDoor(_p0, _p1):
	return _undefined(&"SpawnDoor")
func DoorContact(_p0, _p1):
	return _undefined(&"DoorContact")
func ChangeToFlower(_p0):
	return _undefined(&"ChangeToFlower")
func FlowerThink(_p0):
	return _undefined(&"FlowerThink")
func ChangeFromFlower(_p0):
	return _undefined(&"ChangeFromFlower")
func SpawnBonus(_p0, _p1, _p2):
	return _undefined(&"SpawnBonus")
func BonusThink(_p0):
	return _undefined(&"BonusThink")
func SpawnBrocco(_p0, _p1):
	return _undefined(&"SpawnBrocco")
func BroccoGetUp(_p0):
	return _undefined(&"BroccoGetUp")
func BroccoThink(_p0):
	return _undefined(&"BroccoThink")
func SpawnTomat(_p0, _p1):
	return _undefined(&"SpawnTomat")
func TomatBounceThink(_p0):
	return _undefined(&"TomatBounceThink")
func TomatReact(_p0):
	return _undefined(&"TomatReact")
func SpawnCarrot(_p0, _p1):
	return _undefined(&"SpawnCarrot")
func CarrotReact(_p0):
	return _undefined(&"CarrotReact")
func CarrotAirReact(_p0):
	return _undefined(&"CarrotAirReact")
func SpawnAspar(_p0, _p1):
	return _undefined(&"SpawnAspar")
func SpawnGrape(_p0, _p1):
	return _undefined(&"SpawnGrape")
func GrapeThink(_p0):
	return _undefined(&"GrapeThink")
func GrapeRiseReact(_p0):
	return _undefined(&"GrapeRiseReact")
func GrapeFallReact(_p0):
	return _undefined(&"GrapeFallReact")

# kd_act2.c
func SpawnTater(_p0, _p1):
	return _undefined(&"SpawnTater")
func TaterThink(_p0):
	return _undefined(&"TaterThink")
func BackupReact(_p0):
	return _undefined(&"BackupReact")
func SpawnCart(_p0, _p1):
	return _undefined(&"SpawnCart")
func CartReact(_p0):
	return _undefined(&"CartReact")
func SpawnFrenchy(_p0, _p1):
	return _undefined(&"SpawnFrenchy")
func FrenchyRunThink(_p0):
	return _undefined(&"FrenchyRunThink")
func FrenchyThrow(_p0):
	return _undefined(&"FrenchyThrow")
func FrenchyThink(_p0):
	return _undefined(&"FrenchyThink")
func SpawnMelon(_p0, _p1, _p2):
	return _undefined(&"SpawnMelon")
func MelonSpitThink(_p0):
	return _undefined(&"MelonSpitThink")
func ProjectileReact(_p0):
	return _undefined(&"ProjectileReact")
func SpawnSquasher(_p0, _p1):
	return _undefined(&"SpawnSquasher")
func SquasherThink(_p0):
	return _undefined(&"SquasherThink")
func SquasherJumpReact(_p0):
	return _undefined(&"SquasherJumpReact")
func SpawnApel(_p0, _p1):
	return _undefined(&"SpawnApel")
func ApelThink(_p0):
	return _undefined(&"ApelThink")
func ApelClimbThink(_p0):
	return _undefined(&"ApelClimbThink")
func ApelSlideThink(_p0):
	return _undefined(&"ApelSlideThink")
func ApelClimbReact(_p0):
	return _undefined(&"ApelClimbReact")
func ApelFallReact(_p0):
	return _undefined(&"ApelFallReact")
func SpawnPeaBrain(_p0, _p1):
	return _undefined(&"SpawnPeaBrain")
func PeaBrainThink(_p0):
	return _undefined(&"PeaBrainThink")
func PeaFlyReact(_p0):
	return _undefined(&"PeaFlyReact")
func SpawnPeaPod(_p0, _p1):
	return _undefined(&"SpawnPeaPod")
func SpitPeaBrain(_p0):
	return _undefined(&"SpitPeaBrain")
func PeaPodThink(_p0):
	return _undefined(&"PeaPodThink")
func SpawnBoobus(_p0, _p1):
	return _undefined(&"SpawnBoobus")
func FragThink(_p0):
	return _undefined(&"FragThink")
func FinishThink(_p0):
	return _undefined(&"FinishThink")
func BoobusThink(_p0):
	return _undefined(&"BoobusThink")
func BoobusGroundReact(_p0):
	return _undefined(&"BoobusGroundReact")
func BoobusAirReact(_p0):
	return _undefined(&"BoobusAirReact")

# kd_demo.c
func NewGame():
	return _undefined(&"NewGame")
func GameOver():
	return _undefined(&"GameOver")
func StatusWindow():
	return _undefined(&"StatusWindow")
func SaveGame(_p0):
	return _undefined(&"SaveGame")
func LoadGame(_p0):
	return _undefined(&"LoadGame")
func ResetGame():
	return _undefined(&"ResetGame")
func TEDDeath():
	return _undefined(&"TEDDeath")
func DemoLoop_Old():
	return _undefined(&"DemoLoop_Old")
func DemoLoop_New():
	return _undefined(&"DemoLoop_New")
func RefKeen_Patch_kd_demo():
	return _undefined(&"RefKeen_Patch_kd_demo")

# kd_keen.c
func SpawnScore():
	return _undefined(&"SpawnScore")
func FixScoreBox():
	return _undefined(&"FixScoreBox")
func MemDrawCharEGA(_p0, _p1, _p2, _p3):
	return _undefined(&"MemDrawCharEGA")
func MemDrawCharCGA(_p0, _p1, _p2, _p3):
	return _undefined(&"MemDrawCharCGA")
func ShiftScore():
	return _undefined(&"ShiftScore")
func ScoreThink(_p0):
	return _undefined(&"ScoreThink")
func ScoreReact(_p0):
	return _undefined(&"ScoreReact")
func ThrowPower(_p0, _p1, _p2):
	return _undefined(&"ThrowPower")
func PowerCount(_p0):
	return _undefined(&"PowerCount")
func CalcSingleGravity():
	return _undefined(&"CalcSingleGravity")
func PowerContact(_p0, _p1):
	return _undefined(&"PowerContact")
func PowerReact(_p0):
	return _undefined(&"PowerReact")
func SpawnWorldKeen(_p0, _p1):
	return _undefined(&"SpawnWorldKeen")
func CheckEnterLevel(_p0):
	return _undefined(&"CheckEnterLevel")
func KeenWorldThink(_p0):
	return _undefined(&"KeenWorldThink")
func KeenWorldWalk(_p0):
	return _undefined(&"KeenWorldWalk")
func SpawnKeen(_p0, _p1, _p2):
	return _undefined(&"SpawnKeen")
func CheckGrabPole(_p0):
	return _undefined(&"CheckGrabPole")
func KeenStandThink(_p0):
	return _undefined(&"KeenStandThink")
func KeenPauseThink(_p0):
	return _undefined(&"KeenPauseThink")
func KeenGoSleepThink(_p0):
	return _undefined(&"KeenGoSleepThink")
func KeenSleepThink(_p0):
	return _undefined(&"KeenSleepThink")
func KeenDieThink(_p0):
	return _undefined(&"KeenDieThink")
func KeenDuckThink(_p0):
	return _undefined(&"KeenDuckThink")
func KeenDropDownThink(_p0):
	return _undefined(&"KeenDropDownThink")
func KeenWalkThink(_p0):
	return _undefined(&"KeenWalkThink")
func KeenAirThink(_p0):
	return _undefined(&"KeenAirThink")
func PoleActions(_p0):
	return _undefined(&"PoleActions")
func KeenPoleThink(_p0):
	return _undefined(&"KeenPoleThink")
func KeenClimbThink(_p0):
	return _undefined(&"KeenClimbThink")
func KeenDropThink(_p0):
	return _undefined(&"KeenDropThink")
func KeenThrow(_p0):
	return _undefined(&"KeenThrow")
func KillKeen():
	return _undefined(&"KillKeen")
func KeenContact(_p0, _p1):
	return _undefined(&"KeenContact")
func KeenSimpleReact(_p0):
	return _undefined(&"KeenSimpleReact")
func KeenStandReact(_p0):
	return _undefined(&"KeenStandReact")
func KeenWalkReact(_p0):
	return _undefined(&"KeenWalkReact")
func KeenAirReact(_p0):
	return _undefined(&"KeenAirReact")
func KeenSlideReact(_p0):
	return _undefined(&"KeenSlideReact")
func RefKeen_Patch_kd_keen():
	return _undefined(&"RefKeen_Patch_kd_keen")

# kd_main.c
func DebugMemory():
	return _undefined(&"DebugMemory")
func TestSprites():
	return _undefined(&"TestSprites")
func DebugKeys():
	return _undefined(&"DebugKeys")
func ShutdownId():
	return _undefined(&"ShutdownId")
func InitGame():
	return _undefined(&"InitGame")
func kdreams_exe_main():
	return _undefined(&"kdreams_exe_main")

# kd_play.c
func CheckKeys():
	return _undefined(&"CheckKeys")
func CalcInactivate():
	return _undefined(&"CalcInactivate")
func InitObjArray():
	return _undefined(&"InitObjArray")
func GetNewObj(_p0):
	return _undefined(&"GetNewObj")
func RemoveObj(_p0):
	return _undefined(&"RemoveObj")
func HandleInfo():
	return _undefined(&"HandleInfo")
func ScanInfoPlane():
	return _undefined(&"ScanInfoPlane")
func PatchWorldMap():
	return _undefined(&"PatchWorldMap")
func FadeAndUnhook():
	return _undefined(&"FadeAndUnhook")
func SetupGameLevel(_p0):
	return _undefined(&"SetupGameLevel")
func ScrollScreen():
	return _undefined(&"ScrollScreen")
func GivePoints(_p0):
	return _undefined(&"GivePoints")
func MoveObjVert(_p0, _p1):
	return _undefined(&"MoveObjVert")
func MoveObjHoriz(_p0, _p1):
	return _undefined(&"MoveObjHoriz")
func ClipToEnds(_p0):
	return _undefined(&"ClipToEnds")
func ClipToEastWalls(_p0):
	return _undefined(&"ClipToEastWalls")
func ClipToWestWalls(_p0):
	return _undefined(&"ClipToWestWalls")
func ClipToWalls(_p0):
	return _undefined(&"ClipToWalls")
func ClipToSpriteSide(_p0, _p1):
	return _undefined(&"ClipToSpriteSide")
func ClipToSprite(_p0, _p1, _p2):
	return _undefined(&"ClipToSprite")
func DoActor(_p0, _p1):
	return _undefined(&"DoActor")
func StateMachine(_p0):
	return _undefined(&"StateMachine")
func NewState(_p0, _p1):
	return _undefined(&"NewState")
func PlayLoop():
	return _undefined(&"PlayLoop")
func GameFinale():
	return _undefined(&"GameFinale")
func HandleDeath():
	return _undefined(&"HandleDeath")
func GameLoop():
	return _undefined(&"GameLoop")
func RefKeen_Patch_kd_play():
	return _undefined(&"RefKeen_Patch_kd_play")

# lzhuf.c
func lzhDecompress(_p0, _p1, _p2, _p3, _p4):
	return _undefined(&"lzhDecompress")
func lzhCompress(_p0, _p1, _p2, _p3):
	return _undefined(&"lzhCompress")

# soft.c
func BLoad(_p0, _p1):
	return _undefined(&"BLoad")
func LoadLIBShape(_p0, _p1, _p2):
	return _undefined(&"LoadLIBShape")
func LoadLIBFile(_p0, _p1, _p2):
	return _undefined(&"LoadLIBFile")
# ---- END GENERATED ----
