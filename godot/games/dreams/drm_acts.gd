# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's actors (kd_keen.c, kd_act1.c, kd_act2.c) as carried in ReflectionHLE, (C) 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
# The states' DOS offsets are ReflectionHLE's statetype_ptr_conversion.c (EGA v1.00 and v1.93).
class_name DreamsGame
extends DrmGame
## kd_keen.c, kd_act1.c, kd_act2.c: Keen and every creature, with their state tables. The leaf class: the program is a DreamsGame.
##
## The `s_*` tables are built once (`_build_states`, from `_init`) into `states`, linked by name as
## the C's forward declarations link them. Their `compatdospointer` (the state's offset in the
## original's data segment, which saved games and a flower's temp2 keep) depends on the release:
## `RefKeen_FillObjStatesWithDOSPointers()` sets it for `refkeen_current_gamever`; `_init` runs it for
## the default (v1.00) and the start-up runs it again once the version is known (ReflectionHLE runs
## it among its patchers, after RefKeen_Patch_kd_keen). Left out: the CGA paths (MemDrawCharCGA, the
## fakecgamode shift, ScoreReact's CGA placement) and the 2015 release's branches.

# ===================================================================== kd_keen.c

const KEENPRIORITY: int = 1

const MINPOLEJUMPTICS: int = 19    # wait tics before allowing a pole regram

const SPDRUNJUMP: int = 16
const SPDPOLESIDEJUMP: int = 8
const WALKAIRSPEED: int = 8
const DIVESPEED: int = 32
const JUMPTIME: int = 16
const POLEJUMPTIME: int = 10
const SPDJUMP: int = 40
const SPDDIVEUP: int = 16
const SPDPOLEJUMP: int = 20

const SPDPOWERUP: int = -64
const SPDPOWER: int = 64
const SPDPOWERY: int = -20
const POWERCOUNT: int = 50

const MAXXSPEED: int = 24

var jumptime: int = 0
var leavepoletime: int = 0    # TimeCount when jumped off pole

## (REFKEEN) the score box's character drawer, by mode (RefKeen_Patch_kd_keen)
var MemDrawChar: StringName = &"MemDrawCharEGA"

const worldshapes: Array[int] = [WORLDKEENU1SPR - 1, WORLDKEENUR1SPR - 1, WORLDKEENR1SPR - 1,
	WORLDKEENDR1SPR - 1, WORLDKEEND1SPR - 1, WORLDKEENDL1SPR - 1, WORLDKEENL1SPR - 1,
	WORLDKEENUL1SPR - 1]

const worldanims: Array[int] = [2, 3, 1, 3]

## id0_unsigned_t in the C: the negative ones wrap, and wrap back in the int they are added to
const slopespeed: Array[int] = [0, 0, 4, 4, 8, -4, -4, -8]

const polexspeed: Array[int] = [-SPDPOLESIDEJUMP, 0, SPDPOLESIDEJUMP]

const bonuspoints: Array[int] = [100, 200, 500, 1000, 2000, 5000]

# ===================================================================== kd_act1.c

const flowertime: Array[int] = [700, 700, 350, 175]

const SPDTOMATBOUNCE: int = 30
const TICTOMATJUMP: int = 10
const SPDTOMAT: int = 16

const SPDCARROTLEAPX: int = 32
const SPDCARROTLEAPY: int = 40

const bonusshape: Array[int] = [PEPPERMINT1SPR, COOKIE1SPR, CANDYCANE1SPR, CANDYBAR1SPR,
	LOLLIPOP1SPR, COTTONCANDY1SPR, EXTRAKEEN1SPR, SUPERBONUS1SPR, FLOWERPOWER1SPR,
	FLOWERPOWERUP1SPR, BOOBUSBOMB1SPR, MAGICKEY1SPR]

# ===================================================================== kd_act2.c

const FRYXSPEED: int = 40
const FRYYSPEED: int = -20

const SPITXSPEED: int = 48
const SPITYSPEED: int = -20

const SPDSQUASHLEAPY: int = 50

const MAXPEASPIT: int = 4
const PEAXSPEED: int = 48
const PEAYSPEED: int = -20

const PREFRAGTHINK: int = 60
const POSTFRAGTHINK: int = 60
const SPDBOOBUSJUMP: int = 60
const SPDBOOBUSRUNJUMP: int = 24

# ===================================================================== the state tables

## state name -> [E100 offset, E193 offset] (statetype_ptr_conversion.c). Not game state.
var _state_dospointers: Dictionary = {}
## nextstate by name while the tables are built
var _state_next: Dictionary = {}


func _init() -> void:
	super()    # the parents' static initialisers (Godot runs them only when asked)
	# kd_keen.c's initialised table
	bounceangle = [
		[0, 0, 0, 0, 0, 0, 0, 0],
		[7, 6, 5, 4, 3, 2, 1, 0],
		[5, 4, 3, 2, 1, 0, 15, 14],
		[5, 4, 3, 2, 1, 0, 15, 14],
		[3, 2, 1, 0, 15, 14, 13, 12],
		[9, 8, 7, 6, 5, 4, 3, 2],
		[9, 8, 7, 6, 5, 4, 3, 2],
		[11, 10, 9, 8, 7, 6, 5, 4],
	]
	_build_states()


## One state as the C's initialiser lists it, with its DOS offsets in v1.00 and v1.93; `nextstate`
## is linked by name afterwards.
func _st(name: StringName, leftshapenum: int, rightshapenum: int, progress: int, skippable: bool,
		pushtofloor: bool, tictime: int, xmove: int, ymove: int, thinkptr: StringName,
		contactptr: StringName, reactptr: StringName, nextstate: StringName, dos_e100: int,
		dos_e193: int) -> void:
	var st: statetype = statetype.new()
	st.name = name
	st.leftshapenum = leftshapenum
	st.rightshapenum = rightshapenum
	st.progress = progress
	st.skippable = skippable
	st.pushtofloor = pushtofloor
	st.tictime = tictime
	st.xmove = xmove
	st.ymove = ymove
	st.thinkptr = thinkptr
	st.contactptr = contactptr
	st.reactptr = reactptr
	states[name] = st
	_state_next[name] = nextstate
	_state_dospointers[name] = PackedInt32Array([dos_e100, dos_e193])


## Every `statetype s_*` of kd_keen.c, kd_act1.c and kd_act2.c, in the C's order: all created, then
## `nextstate` linked (the C's forward declarations).
func _build_states() -> void:
	_state_next = {}
	# name, left, right, progress, skippable, pushtofloor, tictime, xmove, ymove, think, contact,
	# react, nextstate, DOS offset v1.00, v1.93
	# kd_keen.c
	_st(&"s_score", 0, 0, think, false, false, 0, 0, 0, &"ScoreThink", &"", &"ScoreReact", &"", 0x0CC4, 0x0DC8)
	_st(&"s_flowerpower1", FLOWERPOWER1SPR, FLOWERPOWER1SPR, stepthink, false, false, 10, 0, 0, &"ProjectileThink", &"PowerContact", &"PowerReact", &"s_flowerpower2", 0x0CE2, 0x0DE6)
	_st(&"s_flowerpower2", FLOWERPOWER2SPR, FLOWERPOWER2SPR, stepthink, false, false, 10, 0, 0, &"ProjectileThink", &"PowerContact", &"PowerReact", &"s_flowerpower1", 0x0D00, 0x0E04)
	_st(&"s_boobusbomb1", BOOBUSBOMB1SPR, BOOBUSBOMB1SPR, stepthink, false, false, 5, 0, 0, &"ProjectileThink", &"PowerContact", &"PowerReact", &"s_boobusbomb2", 0x0D1E, 0x0E22)
	_st(&"s_boobusbomb2", BOOBUSBOMB3SPR, BOOBUSBOMB3SPR, stepthink, false, false, 5, 0, 0, &"ProjectileThink", &"PowerContact", &"PowerReact", &"s_boobusbomb1", 0x0D3C, 0x0E40)
	_st(&"s_bombexplode", BOOBUSBOOM1SPR, BOOBUSBOOM1SPR, step, false, false, 5, 0, 0, &"", &"", &"DrawReact", &"s_bombexplode2", 0x0D5A, 0x0E5E)
	_st(&"s_bombexplode2", BOOBUSBOOM2SPR, BOOBUSBOOM2SPR, step, false, false, 5, 0, 0, &"", &"", &"DrawReact", &"s_bombexplode3", 0x0D78, 0x0E7C)
	_st(&"s_bombexplode3", BOOBUSBOOM1SPR, BOOBUSBOOM1SPR, step, false, false, 5, 0, 0, &"", &"", &"DrawReact", &"s_bombexplode4", 0x0D96, 0x0E9A)
	_st(&"s_bombexplode4", BOOBUSBOOM2SPR, BOOBUSBOOM2SPR, step, false, false, 5, 0, 0, &"", &"", &"DrawReact", &"s_bombexplode5", 0x0DB4, 0x0EB8)
	_st(&"s_bombexplode5", BOOBUSBOOM1SPR, BOOBUSBOOM1SPR, step, false, false, 5, 0, 0, &"", &"", &"DrawReact", &"s_bombexplode6", 0x0DD2, 0x0ED6)
	_st(&"s_bombexplode6", BOOBUSBOOM2SPR, BOOBUSBOOM2SPR, step, false, false, 5, 0, 0, &"", &"", &"DrawReact", &"", 0x0DF0, 0x0EF4)
	_st(&"s_powerblink1", FLOWERPOWER1SPR, FLOWERPOWER1SPR, step, false, false, 5, 0, 0, &"PowerCount", &"", &"DrawReact", &"s_powerblink2", 0x0E0E, 0x0F12)
	_st(&"s_powerblink2", -1, -1, step, false, false, 5, 0, 0, &"PowerCount", &"", &"DrawReact", &"s_powerblink1", 0x0E2C, 0x0F30)
	_st(&"s_worldkeen", 0, 0, stepthink, false, false, 360, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeenwave1", 0x0E4A, 0x0F4E)
	_st(&"s_worldkeenwave1", WORLDKEENWAVE1SPR, WORLDKEENWAVE1SPR, stepthink, false, false, 20, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeenwave2", 0x0E68, 0x0F6C)
	_st(&"s_worldkeenwave2", WORLDKEENWAVE2SPR, WORLDKEENWAVE2SPR, stepthink, false, false, 20, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeenwave3", 0x0E86, 0x0F8A)
	_st(&"s_worldkeenwave3", WORLDKEENWAVE1SPR, WORLDKEENWAVE1SPR, stepthink, false, false, 20, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeenwave4", 0x0EA4, 0x0FA8)
	_st(&"s_worldkeenwave4", WORLDKEENWAVE2SPR, WORLDKEENWAVE2SPR, stepthink, false, false, 20, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeenwave5", 0x0EC2, 0x0FC6)
	_st(&"s_worldkeenwave5", WORLDKEENWAVE1SPR, WORLDKEENWAVE1SPR, stepthink, false, false, 20, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeenwait", 0x0EE0, 0x0FE4)
	_st(&"s_worldkeenwait", WORLDKEEND3SPR, WORLDKEEND3SPR, stepthink, false, false, 400, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeensleep1", 0x0EFE, 0x1002)
	_st(&"s_worldkeensleep1", WORLDKEENSLEEP1SPR, WORLDKEENSLEEP1SPR, stepthink, false, false, 30, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeensleep2", 0x0F1C, 0x1020)
	_st(&"s_worldkeensleep2", WORLDKEENSLEEP2SPR, WORLDKEENSLEEP2SPR, stepthink, false, false, 90, 0, 0, &"KeenWorldThink", &"", &"DrawReact", &"s_worldkeensleep2", 0x0F3A, 0x103E)
	_st(&"s_worldwalk", 0, 0, slide, false, false, 4, 16, 16, &"KeenWorldWalk", &"", &"DrawReact", &"s_worldwalk", 0x0F58, 0x105C)
	_st(&"s_keenzee1", KEENZEES1SPR, KEENZEES1SPR, step, false, false, 30, 0, 0, &"", &"", &"DrawReact", &"s_keenzee2", 0x0F8E, 0x1092)
	_st(&"s_keenzee2", KEENZEES2SPR, KEENZEES2SPR, step, false, false, 30, 0, 0, &"", &"", &"DrawReact", &"s_keenzee3", 0x0FAC, 0x10B0)
	_st(&"s_keenzee3", KEENZEES3SPR, KEENZEES3SPR, step, false, false, 30, 0, 0, &"", &"", &"DrawReact", &"s_keenzee1", 0x0FCA, 0x10CE)
	_st(&"s_keenstand", KEENSTANDLSPR, KEENSTANDRSPR, stepthink, false, true, 4, 0, 16, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenstand", 0x0FE8, 0x10EC)
	_st(&"s_keenpauselook", KEENLOOKULSPR, KEENLOOKURSPR, stepthink, false, true, 60, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenstand", 0x1006, 0x110A)
	_st(&"s_keenyawn1", KEENYAWN1SPR, KEENYAWN1SPR, stepthink, false, true, 40, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenyawn2", 0x1024, 0x1128)
	_st(&"s_keenyawn2", KEENYAWN2SPR, KEENYAWN2SPR, stepthink, false, true, 40, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenyawn3", 0x1042, 0x1146)
	_st(&"s_keenyawn3", KEENYAWN3SPR, KEENYAWN3SPR, stepthink, false, true, 40, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenyawn4", 0x1060, 0x1164)
	_st(&"s_keenyawn4", KEENYAWN4SPR, KEENYAWN4SPR, stepthink, false, true, 40, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenstand", 0x107E, 0x1182)
	_st(&"s_keenwait1", KEENWAITL2SPR, KEENWAITR2SPR, stepthink, false, true, 90, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenwait2", 0x109C, 0x11A0)
	_st(&"s_keenwait2", KEENWAITL1SPR, KEENWAITR1SPR, stepthink, false, true, 10, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenwait3", 0x10BA, 0x11BE)
	_st(&"s_keenwait3", KEENWAITL2SPR, KEENWAITR2SPR, stepthink, false, true, 90, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenwait4", 0x10D8, 0x11DC)
	_st(&"s_keenwait4", KEENWAITL1SPR, KEENWAITR1SPR, stepthink, false, true, 10, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenwait5", 0x10F6, 0x11FA)
	_st(&"s_keenwait5", KEENWAITL2SPR, KEENWAITR2SPR, stepthink, false, true, 90, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenwait6", 0x1114, 0x1218)
	_st(&"s_keenwait6", KEENWAITL3SPR, KEENWAITR3SPR, stepthink, false, true, 70, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keenstand", 0x1132, 0x1236)
	_st(&"s_keengosleep1", KEENSLEEP1SPR, KEENSLEEP1SPR, stepthink, false, true, 20, 0, 0, &"KeenPauseThink", &"KeenContact", &"KeenStandReact", &"s_keengosleep2", 0x1150, 0x1254)
	_st(&"s_keengosleep2", KEENSLEEP2SPR, KEENSLEEP2SPR, step, false, true, 20, 0, 0, &"KeenGoSleepThink", &"KeenContact", &"KeenStandReact", &"s_keensleep1", 0x116E, 0x1272)
	_st(&"s_keensleep1", KEENSLEEP3SPR, KEENSLEEP3SPR, stepthink, false, true, 120, 0, 0, &"KeenSleepThink", &"KeenContact", &"KeenStandReact", &"s_keensleep2", 0x118C, 0x1290)
	_st(&"s_keensleep2", KEENSLEEP4SPR, KEENSLEEP4SPR, stepthink, false, true, 120, 0, 0, &"KeenSleepThink", &"KeenContact", &"KeenStandReact", &"s_keensleep1", 0x11AA, 0x12AE)
	_st(&"s_keengetup", KEENGETUPLSPR, KEENGETUPRSPR, step, false, true, 15, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenstand", 0x11C8, 0x12CC)
	_st(&"s_keendie1", KEENDREAM1SPR, KEENDREAM1SPR, step, false, false, 20, 0, 0, &"", &"", &"KeenSimpleReact", &"s_keendie2", 0x11E6, 0x12EA)
	_st(&"s_keendie2", KEENDREAM2SPR, KEENDREAM2SPR, step, false, false, 20, 0, 0, &"", &"", &"KeenSimpleReact", &"s_keendie3", 0x1204, 0x1308)
	_st(&"s_keendie3", KEENDREAM3SPR, KEENDREAM3SPR, step, false, false, 120, 0, 0, &"KeenDieThink", &"", &"KeenSimpleReact", &"s_keendie3", 0x1222, 0x1326)
	_st(&"s_keenlookup", KEENLOOKULSPR, KEENLOOKURSPR, think, false, true, 0, 0, 0, &"KeenStandThink", &"KeenContact", &"KeenStandReact", &"s_keenlookup", 0x1240, 0x1344)
	_st(&"s_keenduck", KEENDUCKLSPR, KEENDUCKRSPR, think, false, true, 0, 0, 0, &"KeenDuckThink", &"KeenContact", &"KeenStandReact", &"s_keenduck", 0x125E, 0x1362)
	_st(&"s_keendrop", KEENDUCKLSPR, KEENDUCKRSPR, step, false, false, 0, 0, 0, &"KeenDropDownThink", &"KeenContact", &"KeenSimpleReact", &"s_keenjumpup3", 0x127C, 0x1380)
	_st(&"s_keenpole", KEENSHINNYL1SPR, KEENSHINNYR1SPR, think, false, false, 0, 0, 0, &"KeenPoleThink", &"KeenContact", &"KeenSimpleReact", &"s_keenpole", 0x129A, 0x139E)
	_st(&"s_keenclimb1", KEENSHINNYL1SPR, KEENSHINNYR1SPR, slidethink, false, false, 8, 0, 8, &"KeenClimbThink", &"KeenContact", &"KeenSimpleReact", &"s_keenclimb2", 0x12B8, 0x13BC)
	_st(&"s_keenclimb2", KEENSHINNYL2SPR, KEENSHINNYR2SPR, slidethink, false, false, 8, 0, 8, &"KeenClimbThink", &"KeenContact", &"KeenSimpleReact", &"s_keenclimb3", 0x12D6, 0x13DA)
	_st(&"s_keenclimb3", KEENSHINNYL3SPR, KEENSHINNYR3SPR, slidethink, false, false, 8, 0, 8, &"KeenClimbThink", &"KeenContact", &"KeenSimpleReact", &"s_keenclimb1", 0x12F4, 0x13F8)
	_st(&"s_keenslide1", KEENSLIDED1SPR, KEENSLIDED1SPR, slide, false, false, 8, 0, 24, &"KeenDropThink", &"KeenContact", &"KeenSimpleReact", &"s_keenslide2", 0x1312, 0x1416)
	_st(&"s_keenslide2", KEENSLIDED2SPR, KEENSLIDED2SPR, slide, false, false, 8, 0, 24, &"KeenDropThink", &"KeenContact", &"KeenSimpleReact", &"s_keenslide3", 0x1330, 0x1434)
	_st(&"s_keenslide3", KEENSLIDED3SPR, KEENSLIDED3SPR, slide, false, false, 8, 0, 24, &"KeenDropThink", &"KeenContact", &"KeenSimpleReact", &"s_keenslide4", 0x134E, 0x1452)
	_st(&"s_keenslide4", KEENSLIDED4SPR, KEENSLIDED4SPR, slide, false, false, 8, 0, 24, &"KeenDropThink", &"KeenContact", &"KeenSimpleReact", &"s_keenslide1", 0x136C, 0x1470)
	_st(&"s_keenpolethrow1", KEENPTHROWL1SPR, KEENPTHROWR1SPR, step, false, false, 8, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenpolethrow2", 0x138A, 0x148E)
	_st(&"s_keenpolethrow2", KEENPTHROWL2SPR, KEENPTHROWR2SPR, step, true, false, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenSimpleReact", &"s_keenpolethrow3", 0x13A8, 0x14AC)
	_st(&"s_keenpolethrow3", KEENPTHROWL2SPR, KEENPTHROWR2SPR, step, false, false, 10, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenpole", 0x13C6, 0x14CA)
	_st(&"s_keenpolethrowup1", KEENPLTHROWU1SPR, KEENPRTHROWU1SPR, step, false, false, 8, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenpolethrowup2", 0x13E4, 0x14E8)
	_st(&"s_keenpolethrowup2", KEENPLTHROWU2SPR, KEENPRTHROWU2SPR, step, true, false, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenSimpleReact", &"s_keenpolethrowup3", 0x1402, 0x1506)
	_st(&"s_keenpolethrowup3", KEENPLTHROWU2SPR, KEENPRTHROWU2SPR, step, false, false, 10, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenpole", 0x1420, 0x1524)
	_st(&"s_keenpolethrowdown1", KEENPLTHROWD1SPR, KEENPRTHROWD1SPR, step, false, false, 8, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenpolethrowdown2", 0x143E, 0x1542)
	_st(&"s_keenpolethrowdown2", KEENPLTHROWD2SPR, KEENPRTHROWD2SPR, step, true, false, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenSimpleReact", &"s_keenpolethrowdown3", 0x145C, 0x1560)
	_st(&"s_keenpolethrowdown3", KEENPLTHROWD2SPR, KEENPRTHROWD2SPR, step, false, false, 10, 0, 0, &"", &"KeenContact", &"KeenSimpleReact", &"s_keenpole", 0x147A, 0x157E)
	_st(&"s_keenwalk1", KEENRUNL1SPR, KEENRUNR1SPR, slidethink, true, true, 6, 24, 0, &"KeenWalkThink", &"KeenContact", &"KeenWalkReact", &"s_keenwalk2", 0x1498, 0x159C)
	_st(&"s_keenwalk2", KEENRUNL2SPR, KEENRUNR2SPR, slidethink, true, true, 6, 24, 0, &"KeenWalkThink", &"KeenContact", &"KeenWalkReact", &"s_keenwalk3", 0x14B6, 0x15BA)
	_st(&"s_keenwalk3", KEENRUNL3SPR, KEENRUNR3SPR, slidethink, true, true, 6, 24, 0, &"KeenWalkThink", &"KeenContact", &"KeenWalkReact", &"s_keenwalk4", 0x14D4, 0x15D8)
	_st(&"s_keenwalk4", KEENRUNL4SPR, KEENRUNR4SPR, slidethink, true, true, 6, 24, 0, &"KeenWalkThink", &"KeenContact", &"KeenWalkReact", &"s_keenwalk1", 0x14F2, 0x15F6)
	_st(&"s_keenthrow1", KEENTHROWL1SPR, KEENTHROWR1SPR, step, true, true, 4, 0, 0, &"", &"KeenContact", &"KeenStandReact", &"s_keenthrow2", 0x1510, 0x1614)
	_st(&"s_keenthrow2", KEENTHROWL2SPR, KEENTHROWR2SPR, step, false, true, 4, 0, 0, &"", &"KeenContact", &"KeenStandReact", &"s_keenthrow3", 0x152E, 0x1632)
	_st(&"s_keenthrow3", KEENTHROWL3SPR, KEENTHROWR3SPR, step, true, true, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenStandReact", &"s_keenthrow4", 0x154C, 0x1650)
	_st(&"s_keenthrow4", KEENTHROWL3SPR, KEENTHROWR3SPR, step, false, true, 10, 0, 0, &"", &"KeenContact", &"KeenStandReact", &"s_keenstand", 0x156A, 0x166E)
	_st(&"s_keenthrowup1", KEENTHROWU1SPR, KEENTHROWU1SPR, step, false, true, 8, 0, 0, &"", &"KeenContact", &"KeenStandReact", &"s_keenthrowup2", 0x1588, 0x168C)
	_st(&"s_keenthrowup2", KEENTHROWU2SPR, KEENTHROWU2SPR, step, true, true, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenStandReact", &"s_keenthrowup3", 0x15A6, 0x16AA)
	_st(&"s_keenthrowup3", KEENTHROWU2SPR, KEENTHROWU2SPR, step, false, true, 10, 0, 0, &"", &"KeenContact", &"KeenStandReact", &"s_keenstand", 0x15C4, 0x16C8)
	_st(&"s_keenjumpup1", KEENJUMPUL1SPR, KEENJUMPUR1SPR, think, false, false, 0, 0, 0, &"KeenAirThink", &"KeenContact", &"KeenAirReact", &"s_keenjumpup2", 0x15E2, 0x16E6)
	_st(&"s_keenjumpup2", KEENJUMPUL2SPR, KEENJUMPUR2SPR, think, false, false, 0, 0, 0, &"KeenAirThink", &"KeenContact", &"KeenAirReact", &"s_keenjumpup3", 0x1600, 0x1704)
	_st(&"s_keenjumpup3", KEENJUMPUL1SPR, KEENJUMPUR1SPR, think, false, false, 0, 0, 0, &"KeenAirThink", &"KeenContact", &"KeenAirReact", &"s_keenstand", 0x161E, 0x1722)
	_st(&"s_keenjump1", KEENJUMPL1SPR, KEENJUMPR1SPR, think, false, false, 0, 0, 0, &"KeenAirThink", &"KeenContact", &"KeenAirReact", &"s_keenjump2", 0x163C, 0x1740)
	_st(&"s_keenjump2", KEENJUMPL2SPR, KEENJUMPR2SPR, think, false, false, 0, 0, 0, &"KeenAirThink", &"KeenContact", &"KeenAirReact", &"s_keenjump3", 0x165A, 0x175E)
	_st(&"s_keenjump3", KEENJUMPL3SPR, KEENJUMPR3SPR, think, false, false, 0, 0, 0, &"KeenAirThink", &"KeenContact", &"KeenAirReact", &"s_keenstand", 0x1678, 0x177C)
	_st(&"s_keenairthrow1", KEENJLTHROWL1SPR, KEENJRTHROWR1SPR, stepthink, false, false, 8, 0, 0, &"ProjectileThink", &"KeenContact", &"KeenAirReact", &"s_keenairthrow2", 0x1696, 0x179A)
	_st(&"s_keenairthrow2", KEENJLTHROWL2SPR, KEENJRTHROWR2SPR, step, true, false, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenAirReact", &"s_keenairthrow3", 0x16B4, 0x17B8)
	_st(&"s_keenairthrow3", KEENJLTHROWL2SPR, KEENJRTHROWR2SPR, stepthink, false, false, 10, 0, 0, &"ProjectileThink", &"KeenContact", &"KeenAirReact", &"s_keenjumpup3", 0x16D2, 0x17D6)
	_st(&"s_keenairthrowup1", KEENJLTHROWU1SPR, KEENJRTHROWU1SPR, stepthink, false, false, 8, 0, 0, &"ProjectileThink", &"KeenContact", &"KeenAirReact", &"s_keenairthrowup2", 0x16F0, 0x17F4)
	_st(&"s_keenairthrowup2", KEENJLTHROWU2SPR, KEENJRTHROWU2SPR, step, true, false, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenAirReact", &"s_keenairthrowup3", 0x170E, 0x1812)
	_st(&"s_keenairthrowup3", KEENJLTHROWU2SPR, KEENJRTHROWU2SPR, stepthink, false, false, 10, 0, 0, &"ProjectileThink", &"KeenContact", &"KeenAirReact", &"s_keenjumpup3", 0x172C, 0x1830)
	_st(&"s_keenairthrowdown1", KEENJLTHROWD1SPR, KEENJRTHROWD1SPR, stepthink, false, false, 8, 0, 0, &"ProjectileThink", &"KeenContact", &"KeenAirReact", &"s_keenairthrowdown2", 0x174A, 0x184E)
	_st(&"s_keenairthrowdown2", KEENJLTHROWD2SPR, KEENJRTHROWD2SPR, step, true, false, 1, 0, 0, &"KeenThrow", &"KeenContact", &"KeenAirReact", &"s_keenairthrowdown3", 0x1768, 0x186C)
	_st(&"s_keenairthrowdown3", KEENJLTHROWD2SPR, KEENJRTHROWD2SPR, stepthink, false, false, 10, 0, 0, &"ProjectileThink", &"KeenContact", &"KeenAirReact", &"s_keenjumpup3", 0x1786, 0x188A)
	# kd_act1.c
	_st(&"s_door", DOORSPR, DOORSPR, think, false, false, 0, 0, 0, &"", &"DoorContact", &"DrawReact", &"s_door", 0x1842, 0x1946)
	_st(&"s_doorraise", DOORSPR, DOORSPR, slide, false, false, 24, 0, 32, &"", &"DoorContact", &"DrawReact", &"", 0x1860, 0x1964)
	_st(&"s_flower1", FLOWER1SPR, FLOWER1SPR, stepthink, false, false, 20, 0, 0, &"FlowerThink", &"", &"DrawReact", &"s_flower2", 0x187E, 0x1982)
	_st(&"s_flower2", FLOWER2SPR, FLOWER2SPR, stepthink, false, false, 20, 0, 0, &"FlowerThink", &"", &"DrawReact", &"s_flower3", 0x189C, 0x19A0)
	_st(&"s_flower3", FLOWER3SPR, FLOWER3SPR, stepthink, false, false, 20, 0, 0, &"FlowerThink", &"", &"DrawReact", &"s_flower4", 0x18BA, 0x19BE)
	_st(&"s_flower4", FLOWER4SPR, FLOWER4SPR, stepthink, false, false, 20, 0, 0, &"FlowerThink", &"", &"DrawReact", &"s_flower5", 0x18D8, 0x19DC)
	_st(&"s_flower5", FLOWER3SPR, FLOWER3SPR, stepthink, false, false, 20, 0, 0, &"FlowerThink", &"", &"DrawReact", &"s_flower6", 0x18F6, 0x19FA)
	_st(&"s_flower6", FLOWER2SPR, FLOWER2SPR, stepthink, false, false, 20, 0, 0, &"FlowerThink", &"", &"DrawReact", &"s_flower1", 0x1914, 0x1A18)
	_st(&"s_poofto1", POOF1SPR, POOF1SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_poofto2", 0x1932, 0x1A36)
	_st(&"s_poofto2", POOF2SPR, POOF2SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_poofto3", 0x1950, 0x1A54)
	_st(&"s_poofto3", POOF3SPR, POOF3SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_poofto4", 0x196E, 0x1A72)
	_st(&"s_poofto4", POOF4SPR, POOF4SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"", 0x198C, 0x1A90)
	_st(&"s_pooffrom1", POOF4SPR, POOF4SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_pooffrom2", 0x19AA, 0x1AAE)
	_st(&"s_pooffrom2", POOF3SPR, POOF3SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_pooffrom3", 0x19C8, 0x1ACC)
	_st(&"s_pooffrom3", POOF2SPR, POOF2SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_pooffrom4", 0x19E6, 0x1AEA)
	_st(&"s_pooffrom4", POOF1SPR, POOF1SPR, step, false, false, 20, 0, 0, &"ChangeFromFlower", &"", &"DrawReact2", &"s_pooffrom5", 0x1A04, 0x1B08)
	_st(&"s_pooffrom5", POOF2SPR, POOF2SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_pooffrom6", 0x1A22, 0x1B26)
	_st(&"s_pooffrom6", POOF3SPR, POOF3SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"s_pooffrom7", 0x1A40, 0x1B44)
	_st(&"s_pooffrom7", POOF4SPR, POOF4SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact2", &"", 0x1A5E, 0x1B62)
	_st(&"s_bonus", 0, 0, step, false, false, 20, 0, 0, &"BonusThink", &"", &"DrawReact2", &"s_bonus", 0x1A7C, 0x1B80)
	_st(&"s_bonusrise", 0, 0, slide, false, false, 40, 0, 8, &"", &"", &"DrawReact3", &"", 0x1A9A, 0x1B9E)
	_st(&"s_broccowalk1", BROCCOLASHRUNL1SPR, BROCCOLASHRUNR1SPR, step, false, true, 7, 128, 0, &"BroccoThink", &"", &"WalkReact", &"s_broccowalk2", 0x1AD0, 0x1BD4)
	_st(&"s_broccowalk2", BROCCOLASHRUNL2SPR, BROCCOLASHRUNR2SPR, step, false, true, 7, 128, 0, &"BroccoThink", &"", &"WalkReact", &"s_broccowalk3", 0x1AEE, 0x1BF2)
	_st(&"s_broccowalk3", BROCCOLASHRUNL3SPR, BROCCOLASHRUNR3SPR, step, false, true, 7, 128, 0, &"BroccoThink", &"", &"WalkReact", &"s_broccowalk4", 0x1B0C, 0x1C10)
	_st(&"s_broccowalk4", BROCCOLASHRUNL4SPR, BROCCOLASHRUNR4SPR, step, false, true, 7, 128, 0, &"BroccoThink", &"", &"WalkReact", &"s_broccowalk1", 0x1B2A, 0x1C2E)
	_st(&"s_broccosmash1", BROCCOLASHSMASHL1SPR, BROCCOLASHSMASHR1SPR, step, true, false, 3, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash2", 0x1B48, 0x1C4C)
	_st(&"s_broccosmash2", BROCCOLASHSMASHL2SPR, BROCCOLASHSMASHR2SPR, step, true, false, 3, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash3", 0x1B66, 0x1C6A)
	_st(&"s_broccosmash3", BROCCOLASHSMASHL3SPR, BROCCOLASHSMASHR3SPR, step, true, false, 3, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash4", 0x1B84, 0x1C88)
	_st(&"s_broccosmash4", BROCCOLASHSMASHL4SPR, BROCCOLASHSMASHR4SPR, step, false, false, 7, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash5", 0x1BA2, 0x1CA6)
	_st(&"s_broccosmash5", BROCCOLASHSMASHL3SPR, BROCCOLASHSMASHR3SPR, step, true, false, 6, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash6", 0x1BC0, 0x1CC4)
	_st(&"s_broccosmash6", BROCCOLASHSMASHL2SPR, BROCCOLASHSMASHR2SPR, step, true, false, 6, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash7", 0x1BDE, 0x1CE2)
	_st(&"s_broccosmash7", BROCCOLASHSMASHL1SPR, BROCCOLASHSMASHR1SPR, step, true, false, 6, 0, 0, &"", &"", &"DrawReact", &"s_broccosmash8", 0x1BFC, 0x1D00)
	_st(&"s_broccosmash8", BROCCOLASHRUNL1SPR, BROCCOLASHRUNR1SPR, step, true, false, 6, 0, 0, &"BroccoGetUp", &"", &"DrawReact", &"s_broccosmash9", 0x1C1A, 0x1D1E)
	_st(&"s_broccosmash9", BROCCOLASHRUNL1SPR, BROCCOLASHRUNR1SPR, step, true, false, 6, 128, 0, &"", &"", &"WalkReact", &"s_broccowalk1", 0x1C38, 0x1D3C)
	_st(&"s_tomatbounce", TOMATOOTHL1SPR, TOMATOOTHR1SPR, stepthink, false, false, 20, 0, 0, &"TomatBounceThink", &"", &"TomatReact", &"s_tomatbounce2", 0x1C56, 0x1D5A)
	_st(&"s_tomatbounce2", TOMATOOTHL2SPR, TOMATOOTHR2SPR, stepthink, false, false, 20, 0, 0, &"TomatBounceThink", &"", &"TomatReact", &"s_tomatbounce", 0x1C74, 0x1D78)
	_st(&"s_carrotwalk1", CARROTRUNL1SPR, CARROTRUNR1SPR, step, false, true, 5, 128, 0, &"", &"", &"CarrotReact", &"s_carrotwalk2", 0x1C92, 0x1D96)
	_st(&"s_carrotwalk2", CARROTRUNL2SPR, CARROTRUNR2SPR, step, false, true, 5, 128, 0, &"", &"", &"CarrotReact", &"s_carrotwalk3", 0x1CB0, 0x1DB4)
	_st(&"s_carrotwalk3", CARROTRUNL3SPR, CARROTRUNR3SPR, step, false, true, 5, 128, 0, &"", &"", &"CarrotReact", &"s_carrotwalk4", 0x1CCE, 0x1DD2)
	_st(&"s_carrotwalk4", CARROTRUNL4SPR, CARROTRUNR4SPR, step, false, true, 5, 128, 0, &"", &"", &"CarrotReact", &"s_carrotwalk1", 0x1CEC, 0x1DF0)
	_st(&"s_carrotleap", CARROTLEAPL1SPR, CARROTLEAPR1SPR, think, false, false, 0, 0, 0, &"ProjectileThink", &"", &"CarrotAirReact", &"", 0x1D0A, 0x1E0E)
	_st(&"s_asparwalk1", ASPARAGUSRUNL1SPR, ASPARAGUSRUNR1SPR, step, true, true, 3, 100, 0, &"", &"", &"WalkReact", &"s_asparwalk2", 0x1D28, 0x1E2C)
	_st(&"s_asparwalk2", ASPARAGUSRUNL2SPR, ASPARAGUSRUNR2SPR, step, false, true, 3, 100, 0, &"", &"", &"WalkReact", &"s_asparwalk3", 0x1D46, 0x1E4A)
	_st(&"s_asparwalk3", ASPARAGUSRUNL3SPR, ASPARAGUSRUNR3SPR, step, true, true, 3, 100, 0, &"", &"", &"WalkReact", &"s_asparwalk4", 0x1D64, 0x1E68)
	_st(&"s_asparwalk4", ASPARAGUSRUNL4SPR, ASPARAGUSRUNR4SPR, step, false, true, 3, 100, 0, &"", &"", &"WalkReact", &"s_asparwalk1", 0x1D82, 0x1E86)
	_st(&"s_grapewait", GRAPEONVINESPR, GRAPEONVINESPR, think, false, false, 0, 0, 0, &"GrapeThink", &"", &"DrawReact", &"", 0x1DA0, 0x1EA4)
	_st(&"s_grapefall", GRAPEFALLINGSPR, GRAPEFALLINGSPR, think, false, false, 0, 0, 0, &"ProjectileThink", &"", &"GrapeFallReact", &"", 0x1DBE, 0x1EC2)
	_st(&"s_grapesit", GRAPEONVINESPR, GRAPEONVINESPR, step, false, false, 30, 0, 0, &"", &"", &"DrawReact", &"s_graperise", 0x1DDC, 0x1EE0)
	_st(&"s_graperise", GRAPEONVINESPR, GRAPEONVINESPR, slide, false, false, 0, 0, -16, &"", &"", &"GrapeRiseReact", &"", 0x1DFA, 0x1EFE)
	# kd_act2.c
	_st(&"s_taterwalk1", TATERTROOPWALKL1SPR, TATERTROOPWALKR1SPR, step, false, true, 10, 128, 0, &"TaterThink", &"", &"WalkReact", &"s_taterwalk2", 0x1E18, 0x1F1C)
	_st(&"s_taterwalk2", TATERTROOPWALKL2SPR, TATERTROOPWALKR2SPR, step, false, true, 10, 128, 0, &"TaterThink", &"", &"WalkReact", &"s_taterwalk3", 0x1E36, 0x1F3A)
	_st(&"s_taterwalk3", TATERTROOPWALKL3SPR, TATERTROOPWALKR3SPR, step, false, true, 10, 128, 0, &"TaterThink", &"", &"WalkReact", &"s_taterwalk4", 0x1E54, 0x1F58)
	_st(&"s_taterwalk4", TATERTROOPWALKL4SPR, TATERTROOPWALKR4SPR, step, false, true, 10, 128, 0, &"TaterThink", &"", &"WalkReact", &"s_taterwalk1", 0x1E72, 0x1F76)
	_st(&"s_taterattack1", TATERTROOPLUNGEL1SPR, TATERTROOPLUNGER1SPR, step, false, false, 12, 0, 0, &"", &"", &"BackupReact", &"s_taterattack2", 0x1E90, 0x1F94)
	_st(&"s_taterattack2", TATERTROOPLUNGEL2SPR, TATERTROOPLUNGER2SPR, step, false, false, 20, 0, 0, &"", &"", &"DrawReact", &"s_taterattack3", 0x1EAE, 0x1FB2)
	_st(&"s_taterattack3", TATERTROOPLUNGEL1SPR, TATERTROOPLUNGER1SPR, step, false, false, 8, 0, 0, &"", &"", &"DrawReact", &"s_taterwalk1", 0x1ECC, 0x1FD0)
	_st(&"s_cartroll1", CANTCARTL1SPR, CANTCARTL1SPR, slide, true, false, 5, 32, 0, &"", &"", &"CartReact", &"s_cartroll2", 0x1EEA, 0x1FEE)
	_st(&"s_cartroll2", CANTCARTL2SPR, CANTCARTL2SPR, slide, true, false, 5, 32, 0, &"", &"", &"CartReact", &"s_cartroll1", 0x1F08, 0x200C)
	_st(&"s_frenchywalk1", FRENCHYRUNL1SPR, FRENCHYRUNR1SPR, step, false, true, 10, 128, 0, &"FrenchyThink", &"", &"WalkReact", &"s_frenchywalk2", 0x1F26, 0x202A)
	_st(&"s_frenchywalk2", FRENCHYRUNL2SPR, FRENCHYRUNR2SPR, step, false, true, 10, 128, 0, &"FrenchyThink", &"", &"WalkReact", &"s_frenchywalk3", 0x1F44, 0x2048)
	_st(&"s_frenchywalk3", FRENCHYRUNL3SPR, FRENCHYRUNR3SPR, step, false, true, 10, 128, 0, &"FrenchyThink", &"", &"WalkReact", &"s_frenchywalk4", 0x1F62, 0x2066)
	_st(&"s_frenchywalk4", FRENCHYRUNL4SPR, FRENCHYRUNR4SPR, step, false, true, 10, 128, 0, &"FrenchyThink", &"", &"WalkReact", &"s_frenchywalk1", 0x1F80, 0x2084)
	_st(&"s_frenchyrun1", FRENCHYRUNL1SPR, FRENCHYRUNR1SPR, step, true, true, 5, 128, 0, &"FrenchyRunThink", &"", &"WalkReact", &"s_frenchyrun2", 0x1F9E, 0x20A2)
	_st(&"s_frenchyrun2", FRENCHYRUNL2SPR, FRENCHYRUNR2SPR, step, true, true, 5, 128, 0, &"FrenchyRunThink", &"", &"WalkReact", &"s_frenchyrun3", 0x1FBC, 0x20C0)
	_st(&"s_frenchyrun3", FRENCHYRUNL3SPR, FRENCHYRUNR3SPR, step, true, true, 5, 128, 0, &"FrenchyRunThink", &"", &"WalkReact", &"s_frenchyrun4", 0x1FDA, 0x20DE)
	_st(&"s_frenchyrun4", FRENCHYRUNL4SPR, FRENCHYRUNR4SPR, step, true, true, 5, 128, 0, &"FrenchyRunThink", &"", &"WalkReact", &"s_frenchyrun1", 0x1FF8, 0x20FC)
	_st(&"s_frenchythrow1", FRENCHYTHROWL1SPR, FRENCHYTHROWR1SPR, step, false, false, 10, 0, 0, &"", &"", &"DrawReact", &"s_frenchythrow2", 0x2016, 0x211A)
	_st(&"s_frenchythrow2", FRENCHYTHROWL2SPR, FRENCHYTHROWR2SPR, step, false, false, 1, 0, 0, &"FrenchyThrow", &"", &"DrawReact", &"s_frenchythrow3", 0x2034, 0x2138)
	_st(&"s_frenchythrow3", FRENCHYTHROWL2SPR, FRENCHYTHROWR2SPR, step, false, false, 10, -128, 0, &"", &"", &"DrawReact", &"s_frenchywalk1", 0x2052, 0x2156)
	_st(&"s_fry1", FRENCHFRY1SPR, FRENCHFRY1SPR, stepthink, false, false, 4, 0, 0, &"ProjectileThink", &"", &"ProjectileReact", &"s_fry2", 0x2070, 0x2174)
	_st(&"s_fry2", FRENCHFRY2SPR, FRENCHFRY2SPR, stepthink, false, false, 4, 0, 0, &"ProjectileThink", &"", &"ProjectileReact", &"s_fry1", 0x208E, 0x2192)
	_st(&"s_melonside", MELONLIPSL1SPR, MELONLIPSR1SPR, step, false, false, 200, 0, 0, &"", &"", &"DrawReact", &"s_melonsidespit", 0x20AC, 0x21B0)
	_st(&"s_melonsidespit", MELONLIPSL2SPR, MELONLIPSR2SPR, step, false, false, 6, 0, 0, &"MelonSpitThink", &"", &"DrawReact", &"s_melonsidespit2", 0x20CA, 0x21CE)
	_st(&"s_melonsidespit2", MELONLIPSL2SPR, MELONLIPSR2SPR, step, false, false, 6, 0, 0, &"", &"", &"DrawReact", &"s_melonside", 0x20E8, 0x21EC)
	_st(&"s_melondown", MELONLIPSD1SPR, MELONLIPSD1SPR, step, false, false, 200, 0, 0, &"", &"", &"DrawReact", &"s_melondownspit", 0x2106, 0x220A)
	_st(&"s_melondownspit", MELONLIPSD2SPR, MELONLIPSD2SPR, step, false, false, 6, 0, 0, &"MelonSpitThink", &"", &"DrawReact", &"s_melondownspit2", 0x2124, 0x2228)
	_st(&"s_melondownspit2", MELONLIPSD2SPR, MELONLIPSD2SPR, step, false, false, 6, 0, 0, &"", &"", &"DrawReact", &"s_melondown", 0x2142, 0x2246)
	_st(&"s_melonseed1", MELONSEEDL1SPR, MELONSEEDR1SPR, think, false, false, 4, 0, 0, &"ProjectileThink", &"", &"ProjectileReact", &"s_melonseed2", 0x2160, 0x2264)
	_st(&"s_melonseed2", MELONSEEDL2SPR, MELONSEEDR2SPR, think, false, false, 4, 0, 0, &"ProjectileThink", &"", &"ProjectileReact", &"s_melonseed1", 0x217E, 0x2282)
	_st(&"s_melonseedd1", MELONSEEDD1SPR, MELONSEEDD1SPR, stepthink, false, false, 4, 0, 0, &"ProjectileThink", &"", &"ProjectileReact", &"s_melonseedd2", 0x219C, 0x22A0)
	_st(&"s_melonseedd2", MELONSEEDD2SPR, MELONSEEDD2SPR, stepthink, false, false, 4, 0, 0, &"ProjectileThink", &"", &"ProjectileReact", &"s_melonseedd1", 0x21BA, 0x22BE)
	_st(&"s_squasherwalk1", SQUASHERWALKL1SPR, SQUASHERWALKR1SPR, step, false, true, 10, 128, 0, &"SquasherThink", &"", &"WalkReact", &"s_squasherwalk2", 0x21D8, 0x22DC)
	_st(&"s_squasherwalk2", SQUASHERWALKL2SPR, SQUASHERWALKR2SPR, step, false, true, 10, 128, 0, &"SquasherThink", &"", &"WalkReact", &"s_squasherwalk1", 0x21F6, 0x22FA)
	_st(&"s_squasherjump1", SQUASHERJUMPL1SPR, SQUASHERJUMPR1SPR, stepthink, false, false, 20, 0, 0, &"ProjectileThink", &"", &"SquasherJumpReact", &"s_squasherjump2", 0x2214, 0x2318)
	_st(&"s_squasherjump2", SQUASHERJUMPL2SPR, SQUASHERJUMPR2SPR, think, false, false, 0, 0, 0, &"ProjectileThink", &"", &"SquasherJumpReact", &"", 0x2232, 0x2336)
	_st(&"s_squasherwait", SQUASHERJUMPL2SPR, SQUASHERJUMPR2SPR, step, false, false, 10, 0, 0, &"ProjectileThink", &"", &"DrawReact", &"s_squasherwalk1", 0x2250, 0x2354)
	_st(&"s_apelwalk1", APELWALKL1SPR, APELWALKR1SPR, step, false, true, 10, 128, 0, &"ApelThink", &"", &"WalkReact", &"s_apelwalk2", 0x226E, 0x2372)
	_st(&"s_apelwalk2", APELWALKL2SPR, APELWALKR2SPR, step, false, true, 10, 128, 0, &"ApelThink", &"", &"WalkReact", &"s_apelwalk3", 0x228C, 0x2390)
	_st(&"s_apelwalk3", APELWALKL3SPR, APELWALKR3SPR, step, false, true, 10, 128, 0, &"ApelThink", &"", &"WalkReact", &"s_apelwalk1", 0x22AA, 0x23AE)
	_st(&"s_apelclimb1", APELSHINNY1SPR, APELSHINNY1SPR, slide, false, false, 6, 0, -16, &"ApelClimbThink", &"", &"ApelClimbReact", &"s_apelclimb2", 0x22C8, 0x23CC)
	_st(&"s_apelclimb2", APELSHINNY2SPR, APELSHINNY2SPR, slide, false, false, 6, 0, -16, &"ApelClimbThink", &"", &"ApelClimbReact", &"s_apelclimb1", 0x22E6, 0x23EA)
	_st(&"s_apelslide1", APELSLIDE1SPR, APELSLIDE1SPR, slide, false, false, 6, 0, 16, &"ApelSlideThink", &"", &"ApelFallReact", &"s_apelslide2", 0x2304, 0x2408)
	_st(&"s_apelslide2", APELSLIDE2SPR, APELSLIDE2SPR, slide, false, false, 6, 0, 16, &"ApelSlideThink", &"", &"ApelFallReact", &"s_apelslide3", 0x2322, 0x2426)
	_st(&"s_apelslide3", APELSLIDE3SPR, APELSLIDE3SPR, slide, false, false, 6, 0, 16, &"ApelSlideThink", &"", &"ApelFallReact", &"s_apelslide4", 0x2340, 0x2444)
	_st(&"s_apelslide4", APELSLIDE4SPR, APELSLIDE4SPR, slide, false, false, 6, 0, 16, &"ApelSlideThink", &"", &"ApelFallReact", &"s_apelslide1", 0x235E, 0x2462)
	_st(&"s_apelfall", APELWALKL1SPR, APELWALKR1SPR, think, false, false, 0, 0, 0, &"ProjectileThink", &"", &"ApelFallReact", &"", 0x237C, 0x2480)
	_st(&"s_peabrainfly", PEABRAINWALKL1SPR, PEABRAINWALKR1SPR, think, false, false, 0, 0, 0, &"ProjectileThink", &"", &"PeaFlyReact", &"", 0x239A, 0x249E)
	_st(&"s_peabrainwalk1", PEABRAINWALKL1SPR, PEABRAINWALKR1SPR, step, false, true, 10, 128, 0, &"PeaBrainThink", &"", &"WalkReact", &"s_peabrainwalk2", 0x23B8, 0x24BC)
	_st(&"s_peabrainwalk2", PEABRAINWALKL2SPR, PEABRAINWALKR2SPR, step, false, true, 10, 128, 0, &"PeaBrainThink", &"", &"WalkReact", &"s_peabrainwalk3", 0x23D6, 0x24DA)
	_st(&"s_peabrainwalk3", PEABRAINWALKL3SPR, PEABRAINWALKR3SPR, step, false, true, 10, 128, 0, &"PeaBrainThink", &"", &"WalkReact", &"s_peabrainwalk4", 0x23F4, 0x24F8)
	_st(&"s_peabrainwalk4", PEABRAINWALKL4SPR, PEABRAINWALKR4SPR, step, false, true, 10, 128, 0, &"PeaBrainThink", &"", &"WalkReact", &"s_peabrainwalk1", 0x2412, 0x2516)
	_st(&"s_peapodwalk1", PEAPODRUNL1SPR, PEAPODRUNR1SPR, step, false, true, 10, 128, 0, &"PeaPodThink", &"", &"WalkReact", &"s_peapodwalk2", 0x2430, 0x2534)
	_st(&"s_peapodwalk2", PEAPODRUNL2SPR, PEAPODRUNR2SPR, step, false, true, 10, 128, 0, &"PeaPodThink", &"", &"WalkReact", &"s_peapodwalk3", 0x244E, 0x2552)
	_st(&"s_peapodwalk3", PEAPODRUNL3SPR, PEAPODRUNR3SPR, step, false, true, 10, 128, 0, &"PeaPodThink", &"", &"WalkReact", &"s_peapodwalk4", 0x246C, 0x2570)
	_st(&"s_peapodwalk4", PEAPODRUNL4SPR, PEAPODRUNR4SPR, step, false, true, 10, 128, 0, &"PeaPodThink", &"", &"WalkReact", &"s_peapodwalk1", 0x248A, 0x258E)
	_st(&"s_peapodspit1", PEAPODSPITLSPR, PEAPODSPITRSPR, step, false, true, 30, 0, 0, &"SpitPeaBrain", &"", &"DrawReact", &"s_peapodspit2", 0x24A8, 0x25AC)
	_st(&"s_peapodspit2", PEAPODSPITLSPR, PEAPODSPITRSPR, step, false, true, 30, 0, 0, &"", &"", &"DrawReact", &"s_peapodwalk1", 0x24C6, 0x25CA)
	_st(&"s_boobuswalk1", BOOBUSWALKL1SPR, BOOBUSWALKR1SPR, step, false, true, 10, 128, 0, &"BoobusThink", &"", &"BoobusGroundReact", &"s_boobuswalk2", 0x24E4, 0x25E8)
	_st(&"s_boobuswalk2", BOOBUSWALKL2SPR, BOOBUSWALKR2SPR, step, false, true, 10, 128, 0, &"BoobusThink", &"", &"BoobusGroundReact", &"s_boobuswalk3", 0x2502, 0x2606)
	_st(&"s_boobuswalk3", BOOBUSWALKL3SPR, BOOBUSWALKR3SPR, step, false, true, 10, 128, 0, &"BoobusThink", &"", &"BoobusGroundReact", &"s_boobuswalk4", 0x2520, 0x2624)
	_st(&"s_boobuswalk4", BOOBUSWALKL4SPR, BOOBUSWALKR4SPR, step, false, true, 10, 128, 0, &"BoobusThink", &"", &"BoobusGroundReact", &"s_boobuswalk1", 0x253E, 0x2642)
	_st(&"s_boobusjump", BOOBUSJUMPSPR, BOOBUSJUMPSPR, think, false, false, 0, 0, 0, &"ProjectileThink", &"", &"BoobusAirReact", &"", 0x255C, 0x2660)
	_st(&"s_boobusdie", BOOBUSJUMPSPR, BOOBUSJUMPSPR, step, false, false, 4, 0, 0, &"FragThink", &"", &"DrawReact", &"s_boobusdie", 0x257A, 0x267E)
	_st(&"s_boobusdie2", 0, 0, step, false, false, 4, 0, 0, &"FragThink", &"", &"", &"s_boobusdie2", 0x2598, 0x269C)
	_st(&"s_boobusdie3", 0, 0, step, false, false, 250, 0, 0, &"FinishThink", &"", &"", &"", 0x25B6, 0x26BA)
	_st(&"s_deathboom1", BOOBUSBOOM1SPR, BOOBUSBOOM1SPR, step, false, false, 20, 0, 0, &"ProjectileThink", &"", &"DrawReact3", &"s_deathboom2", 0x25D4, 0x26D8)
	_st(&"s_deathboom2", BOOBUSBOOM2SPR, BOOBUSBOOM2SPR, step, false, false, 20, 0, 0, &"ProjectileThink", &"", &"DrawReact3", &"s_deathboom3", 0x25F2, 0x26F6)
	_st(&"s_deathboom3", POOF1SPR, POOF1SPR, step, false, false, 40, 0, 0, &"ProjectileThink", &"", &"DrawReact3", &"s_deathboom4", 0x2610, 0x2714)
	_st(&"s_deathboom4", POOF2SPR, POOF2SPR, step, false, false, 30, 0, 0, &"ProjectileThink", &"", &"DrawReact3", &"s_deathboom5", 0x262E, 0x2732)
	_st(&"s_deathboom5", POOF3SPR, POOF3SPR, step, false, false, 30, 0, 0, &"ProjectileThink", &"", &"DrawReact3", &"s_deathboom6", 0x264C, 0x2750)
	_st(&"s_deathboom6", POOF4SPR, POOF4SPR, step, false, false, 30, 0, 0, &"ProjectileThink", &"", &"DrawReact3", &"", 0x266A, 0x276E)
	for name: StringName in _state_next:
		var next: StringName = _state_next[name]
		if next != &"":
			var st: statetype = states[name]
			st.nextstate = states[next]
	_state_next = {}
	RefKeen_FillObjStatesWithDOSPointers()


## statetype_ptr_conversion.c: each state's offset in the release's data segment (the lookup back,
## RefKeen_GetObjStatePtrFromDOSPointer, is in drm_game.gd).
func RefKeen_FillObjStatesWithDOSPointers() -> void:
	var col: int = 1 if refkeen_current_gamever == BE_GAMEVER_KDREAMSE193 else 0
	for name: StringName in _state_dospointers:
		var st: statetype = states[name]
		st.compatdospointer = _state_dospointers[name][col]


## kd_def.h's COMPAT_OBJ_CONVERT_OBJ_PTR_TO_DOS_PTR: an object as the 16-bit pointer the original
## keeps in a temp. dummyobj (outside objarray, index -1) comes back as dummyobj, as the original's
## pointer to it does (KeenSleepThink compares with it); drm_game.gd's COMPAT_* give null there.
func _obj_to_dosptr(o: objtype) -> int:
	if o == null:
		return 0
	return u16(o.index * COMPAT_OBJ_CONVERSION_SIZE + refkeen_compat_kd_play_objoffset)


## COMPAT_OBJ_CONVERT_DOS_PTR_TO_OBJ_PTR
func _dosptr_to_obj(dosptr: int) -> objtype:
	dosptr = u16(dosptr)
	if dosptr == 0:
		return null
	@warning_ignore("integer_division")
	var i: int = u16(dosptr - refkeen_compat_kd_play_objoffset) / COMPAT_OBJ_CONVERSION_SIZE
	if i < objarray.size():
		return objarray[i]
	return dummyobj


## kd_keen.c's states in its data order up to s_worldwalk (worldshapes follows): what the original
## has after bounceangle, enough for walls up to 50 (the tile info's go to 17).
const _after_bounceangle: Array[StringName] = [&"s_score", &"s_flowerpower1", &"s_flowerpower2",
	&"s_boobusbomb1", &"s_boobusbomb2", &"s_bombexplode", &"s_bombexplode2", &"s_bombexplode3",
	&"s_bombexplode4", &"s_bombexplode5", &"s_bombexplode6", &"s_powerblink1", &"s_powerblink2",
	&"s_worldkeen", &"s_worldkeenwave1", &"s_worldkeenwave2", &"s_worldkeenwave3",
	&"s_worldkeenwave4", &"s_worldkeenwave5", &"s_worldkeenwait", &"s_worldkeensleep1",
	&"s_worldkeensleep2", &"s_worldwalk"]


## bounceangle[wall][angle]. A wall number past the table's 8 rows (the deadly floor, 9, has tiles)
## reads on into what the compiler put after it: the states from s_score on, 15 words each (8
## numbers, 3 far function pointers, the near next state; the stride of statetype_ptr_conversion.c's
## offsets). A function pointer's words are never below 16, so match no angle: 0xFFFF stands for
## them. Checked against both releases' programs (tests/drm_acts_check.gd).
func _bounceangle(wall: int, angle: int) -> int:
	if wall < 8:
		return bounceangle[wall][angle]
	var word: int = (wall - 8) * 8 + angle
	@warning_ignore("integer_division")
	var n: int = word / 15
	if n >= _after_bounceangle.size():
		return 0xFFFF    # past s_worldwalk: not modelled
	var st: statetype = S(_after_bounceangle[n])
	var think_w: int = 0 if st.thinkptr == &"" else 0xFFFF
	var contact_w: int = 0 if st.contactptr == &"" else 0xFFFF
	var react_w: int = 0 if st.reactptr == &"" else 0xFFFF
	var words: PackedInt32Array = PackedInt32Array([u16(st.leftshapenum), u16(st.rightshapenum),
		st.progress, 1 if st.skippable else 0, 1 if st.pushtofloor else 0, u16(st.tictime),
		u16(st.xmove), u16(st.ymove), think_w, think_w, contact_w, contact_w, react_w, react_w,
		0 if st.nextstate == null else st.nextstate.compatdospointer])
	return words[word % 15]


# ===================================================================== kd_keen.c: score box

func SpawnScore() -> void:
	scoreobj.obclass = inertobj
	scoreobj.active = allways
	scoreobj.needtoclip = false
	scoreobj.temp1 = -1    # force score to be updated
	scoreobj.temp2 = -1
	scoreobj.temp3 = -1    # and flower power
	scoreobj.temp4 = -1    # and lives
	NewState(scoreobj, S(&"s_score"))


## Draws the boobus bomb if on level 15, else the flower power, into the score box sprite.
func FixScoreBox() -> void:
	var block: PackedByteArray = grsegs[SCOREBOXSPR]
	var width: int = VW_GetSpriteShiftWidth(block, 0)
	var planesize: int = VW_GetSpriteShiftPlaneSize(block, 0)
	var dest: int = VW_GetSpriteShiftSourceOffset(block, 0) + planesize + width * 16 + 4 * CHARWIDTH
	if mapon == 15:
		call(MemDrawChar, 20, dest, width, planesize)
		call(MemDrawChar, 21, dest + CHARWIDTH, width, planesize)
		call(MemDrawChar, 22, dest + width * 8, width, planesize)
		call(MemDrawChar, 23, dest + width * 8 + CHARWIDTH, width, planesize)
	else:
		call(MemDrawChar, 28, dest, width, planesize)
		call(MemDrawChar, 29, dest + CHARWIDTH, width, planesize)
		call(MemDrawChar, 30, dest + width * 8, width, planesize)
		call(MemDrawChar, 31, dest + width * 8 + CHARWIDTH, width, planesize)


## An 8x8 character of the tile 8s, four planes of eight rows, into the score box sprite at `dest`
## (the C's pointer into grsegs[SCOREBOXSPR], its only target).
func MemDrawCharEGA(char8: int, dest: int, width: int, planesize: int) -> void:
	var src: PackedByteArray = grsegs[STARTTILE8]
	var block: PackedByteArray = grsegs[SCOREBOXSPR]
	var s: int = 32 * char8
	for plane: int in range(4):
		var d: int = dest
		for row: int in range(8):
			block[d] = src[s]
			s += 1
			d += width
		dest += planesize


## The score box's shifted copies, made again from the unshifted one.
func ShiftScore() -> void:
	var spr: spritetabletype = spritetable[SCOREBOXSPR - STARTSPRITES]
	var dest: PackedByteArray = grsegs[SCOREBOXSPR]
	_shift_sprite(dest, VW_GetSpriteShiftSourceOffset(dest, 0), dest, VW_GetSpriteShiftSourceOffset(dest, 1),
		spr.width, spr.height, 2)
	_shift_sprite(dest, VW_GetSpriteShiftSourceOffset(dest, 0), dest, VW_GetSpriteShiftSourceOffset(dest, 2),
		spr.width, spr.height, 4)
	_shift_sprite(dest, VW_GetSpriteShiftSourceOffset(dest, 0), dest, VW_GetSpriteShiftSourceOffset(dest, 3),
		spr.width, spr.height, 6)


## The digits right-aligned in `places` characters after `dest`, blanks before (ScoreThink's loops).
func _score_digits(text: String, places: int, dest: int, width: int, planesize: int) -> void:
	var i: int = places
	while i > text.length():    # erase leading spaces
		dest += CHARWIDTH
		call(MemDrawChar, 0, dest, width, planesize)
		i -= 1
	for k: int in range(text.length()):    # draw digits
		dest += CHARWIDTH
		call(MemDrawChar, text.unicode_at(k) - 48 + 1, dest, width, planesize)


func ScoreThink(ob: objtype) -> void:
	var block: PackedByteArray
	var width: int
	var planesize: int
	var dest: int

	# score changed (the low word compares as the original's 16-bit unsigned)
	if (gamestate.score >> 16) != ob.temp1 or u16(gamestate.score) != u16(ob.temp2):
		block = grsegs[SCOREBOXSPR]
		width = VW_GetSpriteShiftWidth(block, 0)
		planesize = VW_GetSpriteShiftPlaneSize(block, 0)
		dest = VW_GetSpriteShiftSourceOffset(block, 0) + planesize + width * 4 + 1 * CHARWIDTH
		_score_digits(String.num_int64(gamestate.score), 6, dest, width, planesize)
		if GRMODE == EGAGR:
			ShiftScore()
		ob.needtoreact = true
		ob.temp1 = s16(gamestate.score >> 16)
		ob.temp2 = s16(gamestate.score)

	# flower power changed
	var number: int
	if mapon == 15:
		number = u16(gamestate.boobusbombs)
	else:
		number = u16(gamestate.flowerpowers)
	if number != u16(ob.temp3):
		block = grsegs[SCOREBOXSPR]
		width = VW_GetSpriteShiftWidth(block, 0)
		planesize = VW_GetSpriteShiftPlaneSize(block, 0)
		dest = VW_GetSpriteShiftSourceOffset(block, 0) + planesize + width * 20 + 5 * CHARWIDTH
		var text: String = "99" if number > 99 else String.num_int64(number)
		_score_digits(text, 2, dest, width, planesize)
		if GRMODE == EGAGR:
			ShiftScore()
		ob.needtoreact = true
		ob.temp3 = s16(gamestate.flowerpowers)

	# lives changed
	if gamestate.lives != ob.temp4:
		block = grsegs[SCOREBOXSPR]
		width = VW_GetSpriteShiftWidth(block, 0)
		planesize = VW_GetSpriteShiftPlaneSize(block, 0)
		dest = VW_GetSpriteShiftSourceOffset(block, 0) + planesize + width * 20 + 2 * CHARWIDTH
		if gamestate.lives > 9:
			call(MemDrawChar, 9 + 1, dest, width, planesize)
		else:
			call(MemDrawChar, gamestate.lives + 1, dest, width, planesize)
		if GRMODE == EGAGR:
			ShiftScore()
		ob.needtoreact = true
		ob.temp4 = s16(gamestate.lives)

	if originxglobal != ob.x or originyglobal != ob.y:
		ob.needtoreact = true


func ScoreReact(ob: objtype) -> void:
	ob.x = originxglobal
	ob.y = originyglobal
	if GRMODE == EGAGR:
		RF_PlaceSprite_EGA(ob, u16(ob.x + 4 * PIXGLOBAL), u16(ob.y + 4 * PIXGLOBAL), SCOREBOXSPR,
			spritedraw, PRIORITIES - 1)


# ===================================================================== kd_keen.c: flower power

func ThrowPower(x: int, y: int, dir: int) -> void:
	var startstate: statetype

	if mapon == 15:
		if gamestate.boobusbombs == 0:
			SD_PlaySound(NOWAYSND)
			return    # no bombs to throw
		SD_PlaySound(THROWBOMBSND)
		gamestate.bombsthislevel -= 1
		gamestate.boobusbombs -= 1
	else:
		if gamestate.flowerpowers == 0 and not cheat_infiniteAmmo:
			SD_PlaySound(NOWAYSND)
			return    # no flower power to throw
		SD_PlaySound(THROWSND)
		if not cheat_infiniteAmmo:    # CHEAT-02: a throw uses nothing (and none is needed)
			gamestate.flowerpowers -= 1

	GetNewObj(true)
	newobj.obclass = powerobj
	newobj.temp2 = dir
	newobj.x = x
	newobj.y = y
	newobj.tileleft = x >> G_T_SHIFT
	newobj.tileright = newobj.tileleft
	newobj.tiletop = y >> G_T_SHIFT
	newobj.tilebottom = newobj.tiletop
	newobj.ydir = -1

	match dir:
		dir_North:
			newobj.xspeed = 0
			newobj.yspeed = SPDPOWERUP
		dir_East:
			newobj.xspeed = SPDPOWER
			newobj.yspeed = SPDPOWERY
		dir_South:
			newobj.xspeed = 0
			newobj.yspeed = SPDPOWER
		dir_West:
			newobj.xspeed = -SPDPOWER
			newobj.yspeed = SPDPOWERY
		_:
			Quit("ThrowPower: Bad dir!")
			return

	if mapon != 15:
		newobj.temp1 = 8    # flower power bonus
		startstate = S(&"s_flowerpower1")
	else:
		newobj.temp1 = 10    # boobus bomb bonus
		startstate = S(&"s_boobusbomb1")
	newobj.active = removable

	NewState(newobj, startstate)


func PowerCount(ob: objtype) -> void:
	ob.temp2 = s16(ob.temp2 + tics)
	ob.shapenum = 0
	if ob.temp2 > POWERCOUNT:
		RemoveObj(ob)


## The gravity a falling thing gets over this frame's tics (only on odd tics, because of limited
## precision), halved.
func CalcSingleGravity() -> void:
	var speed: int = 0
	singlegravity = 0
	for i: int in range(lasttimecount - tics, lasttimecount):
		if i & 1:
			speed += ACCGRAVITY
			if speed > SPDMAXY:
				speed = SPDMAXY
		singlegravity = s16(singlegravity + speed)
	@warning_ignore("integer_division")
	singlegravity = singlegravity / 2


func PowerContact(ob: objtype, hit: objtype) -> void:
	match hit.obclass:
		broccoobj, tomatobj, carrotobj, celeryobj, asparobj, taterobj, frenchyobj, squashobj, \
				apelobj, peapodobj, peabrainobj:
			ChangeToFlower(hit)
			RemoveObj(ob)
		boobusobj:
			hit.temp4 = s16(hit.temp4 - 1)
			if hit.temp4 == 0:
				# killed boobus
				GivePoints(50000)
				GivePoints(50000)
				hit.obclass = inertobj
				ChangeState(hit, S(&"s_boobusdie"))
				hit.temp1 = 0    # death count
			SD_PlaySound(BOMBBOOMSND)
			ChangeState(ob, S(&"s_bombexplode"))


## A thrown thing landing on a floor (PowerReact's and ProjectileReact's common part, written twice
## in the C): the bounce off the floor's slope; returns the speed it keeps.
@warning_ignore("integer_division")
func _floor_bounce(ob: objtype) -> int:
	if ob.yspeed < 0:
		ob.yspeed = 0

	var absx: int = absi(ob.xspeed)
	var absy: int = ob.yspeed
	var angle: int
	var speed: int    # the products are the original's 16-bit unsigned ones
	if absx > absy:
		if absx > u16(absy * 2):    # 22 degrees
			angle = 0
			speed = u16(absx * 286)    # x*sqrt(5)/2
		else:    # 45 degrees
			angle = 1
			speed = u16(absx * 362)    # x*sqrt(2)
	else:
		if absy > u16(absx * 2):    # 90 degrees
			angle = 3
			speed = u16(absy * 256)
		else:
			angle = 2    # 67 degrees
			speed = u16(absy * 286)    # y*sqrt(5)/2
	if ob.xspeed > 0:
		angle = 7 - angle

	speed >>= 1
	var newangle: int = _bounceangle(ob.hitnorth, angle)
	match newangle:
		0:
			ob.xspeed = s16(speed / 286)
			ob.yspeed = s16(-ob.xspeed / 2)
		1:
			ob.xspeed = s16(speed / 362)
			ob.yspeed = s16(-ob.xspeed)
		2:
			ob.yspeed = s16(-(speed / 286))
			ob.xspeed = s16(-ob.yspeed / 2)
		3, 4:
			ob.xspeed = 0
			ob.yspeed = s16(-(speed / 256))
		5:
			ob.yspeed = s16(-(speed / 286))
			ob.xspeed = s16(ob.yspeed / 2)
		6:
			ob.yspeed = s16(-(speed / 362))
			ob.xspeed = ob.yspeed
		7:
			ob.xspeed = s16(-(speed / 286))
			ob.yspeed = s16(ob.xspeed / 2)
		8:
			ob.xspeed = s16(-(speed / 286))
			ob.yspeed = s16(-ob.xspeed / 2)
		9:
			ob.xspeed = s16(-(speed / 362))
			ob.yspeed = s16(-ob.xspeed)
		10:
			ob.yspeed = s16(speed / 286)
			ob.xspeed = s16(-ob.yspeed / 2)
		11, 12:
			ob.xspeed = 0
			ob.yspeed = s16(-(speed / 256))
		13:
			ob.yspeed = s16(speed / 286)
			ob.xspeed = s16(ob.yspeed / 2)
		14:
			ob.xspeed = s16(speed / 362)
			ob.yspeed = s16(speed / 362)
		15:
			ob.xspeed = s16(speed / 286)
			ob.yspeed = s16(ob.xspeed / 2)
	return speed


func PowerReact(ob: objtype) -> void:
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)
	if ob.hiteast or ob.hitwest:
		@warning_ignore("integer_division")
		ob.xspeed = s16(-ob.xspeed / 2)
		ob.obclass = bonusobj

	if ob.hitsouth:
		if ob.hitsouth == 17:    # go through pole holes
			if ob.temp2 != dir_North:
				ob.obclass = bonusobj
			ob.top = u16(ob.top - 32)
			ob.y = u16(ob.y - 32)
			ob.xspeed = 0
			ob.x = u16(ob.tilemidx * TILEGLOBAL + 4 * PIXGLOBAL)
		else:
			@warning_ignore("integer_division")
			ob.yspeed = s16(-ob.yspeed / 2)
		return

	var wall: int = u16(ob.hitnorth)
	if wall == 17:    # go through pole holes
		if ob.temp2 != dir_South:
			ob.obclass = bonusobj
		ob.bottom = u16(ob.bottom + 32)
		ob.y = u16(ob.y + 32)
		ob.xspeed = 0
		ob.x = u16(ob.tilemidx * TILEGLOBAL + 4 * PIXGLOBAL)
	elif wall:
		ob.obclass = bonusobj
		var speed: int = _floor_bounce(ob)
		if speed < 256 * 16:
			if mapon == 15:
				ob.ydir = -1    # bonus stuff flies up when touched
				ob.shapenum = BOOBUSBOMB1SPR
				ob.temp2 = ob.shapenum
				ob.temp3 = ob.temp2 + 2
				ob.needtoclip = false
				ChangeState(ob, S(&"s_bonus"))
			else:
				ChangeState(ob, S(&"s_powerblink1"))
				ob.needtoclip = false
				ob.temp2 = 0    # blink time


# ===================================================================== kd_keen.c: mini Keen
# player.temp1 = dir, player.temp2 = animation stage

func SpawnWorldKeen(tilex: int, tiley: int) -> void:
	player.obclass = keenobj
	if gamestate.worldx == 0:
		player.x = u16(tilex << G_T_SHIFT)
		player.y = u16(tiley << G_T_SHIFT)
	else:
		player.x = gamestate.worldx
		player.y = gamestate.worldy

	player.active = yes
	player.needtoclip = true
	player.xdir = 0
	player.ydir = 0
	player.temp1 = dir_West
	player.temp2 = 3
	player.shapenum = 3 + WORLDKEENL1SPR - 1    # feet together
	NewState(player, S(&"s_worldkeen"))


func CheckEnterLevel(ob: objtype) -> void:
	for y: int in range(ob.tiletop, ob.tilebottom + 1):
		for x: int in range(ob.tileleft, ob.tileright + 1):
			@warning_ignore("integer_division")
			var tile: int = mapsegs[2][mapbwidthtable[y] / 2 + x]
			if tile >= 3 and tile <= 18:
				# enter level!
				if tile == 17:
					if gamestate.boobusbombs < 12:
						VW_FixRefreshBuffer()
						US_CenterWindow(26, 6)
						PrintY += 8
						US_CPrint("You can't possibly\ndefeat King Boobus Tuber\nwith less than 12 bombs!")
						VW_UpdateScreen()
						IN_Ack()
						RF_ForceRefresh()
						return
				gamestate.worldx = ob.x
				gamestate.worldy = ob.y
				gamestate.mapon = tile - 2
				playstate = levelcomplete
				SD_PlaySound(ENTERLEVELSND)


func KeenWorldThink(ob: objtype) -> void:
	if c.dir != dir_None:
		ob.state = S(&"s_worldwalk")
		ob.temp2 = 0
		KeenWorldWalk(ob)

	if c.button0 or c.button1:
		CheckEnterLevel(ob)


func KeenWorldWalk(ob: objtype) -> void:
	ob.xdir = c.xaxis
	ob.ydir = c.yaxis

	ob.temp2 += 1
	if ob.temp2 == 4:
		ob.temp2 = 0

	if c.button0 or c.button1:
		CheckEnterLevel(ob)

	if c.dir == dir_None:
		ob.state = S(&"s_worldkeen")
		ob.shapenum = worldshapes[ob.temp1] + 3
		return

	ob.temp1 = c.dir
	ob.shapenum = worldshapes[ob.temp1] + worldanims[ob.temp2]


# ===================================================================== kd_keen.c: Keen
# player.temp1 = pausetime / pointer to zees when sleeping, temp2 = pausecount / stagecount,
# temp4 = pole x location

func SpawnKeen(tilex: int, tiley: int, dir: int) -> void:
	player.obclass = keenobj
	player.active = yes
	player.needtoclip = true
	player.x = u16(tilex << G_T_SHIFT)
	player.y = u16((tiley << G_T_SHIFT) - BLOCKSIZE * 2)

	player.xdir = dir
	player.ydir = 1
	NewState(player, S(&"s_keenstand"))


@warning_ignore("integer_division")
func CheckGrabPole(ob: objtype) -> bool:
	# kludgy bit to not let you grab a pole the instant you jump off it
	# REFKEEN - Looks like these are unsigned comparisons in original EXE
	if SD_GetTimeCount() < u32(leavepoletime):
		leavepoletime = 0
	elif u32(SD_GetTimeCount() - u32(leavepoletime)) < MINPOLEJUMPTICS:
		return false

	var map: int
	if c.yaxis == -1:
		map = mapbwidthtable[u16(ob.top + 6 * PIXGLOBAL) / TILEGLOBAL] / 2
	else:
		map = mapbwidthtable[ob.tilebottom] / 2

	var x: int = u16(ob.left + u16(ob.right - ob.left) / 2) >> G_T_SHIFT

	map += x

	if (tinf[INTILE + mapsegs[1][map]] & 0x7f) == 1:
		ob.xmove = s16(((x << G_T_SHIFT) - 8 * PIXGLOBAL) - ob.x)
		ob.ymove = s16(c.yaxis * 32)
		ob.temp4 = x    # for future reference
		ob.needtoclip = false    # can climb through pole holes
		ob.state = S(&"s_keenpole")
		return true

	return false


func KeenStandThink(ob: objtype) -> void:
	if c.xaxis:
		# started walking
		ob.xdir = c.xaxis
		ob.state = S(&"s_keenwalk1")
		ob.xmove = s16(ob.xdir * S(&"s_keenwalk1").xmove * tics)
		KeenWalkThink(ob)
		return

	if c.button0 and not button0held:
		# jump straight up
		SD_PlaySound(JUMPSND)
		ob.xspeed = 0
		ob.yspeed = -SPDJUMP
		ob.xmove = 0
		ob.ymove = 0
		jumptime = JUMPTIME
		ob.state = S(&"s_keenjumpup1")
		button0held = true
		return

	if c.button1 and not button1held:
		# throw current xdir
		if c.yaxis == -1:
			ob.state = S(&"s_keenthrowup1")
		else:
			ob.state = S(&"s_keenthrow1")
		button1held = true
		return

	match c.yaxis:
		-1:
			if not CheckGrabPole(ob):    # try to go up/down pole first
				ob.state = S(&"s_keenlookup")
		0:
			ob.state = S(&"s_keenstand")
		1:
			if not CheckGrabPole(ob):    # try to go up/down pole first
				ob.state = S(&"s_keenduck")


## Special animations in time.
func KeenPauseThink(ob: objtype) -> void:
	if c.dir != dir_None or c.button0 or c.button1:
		ob.temp1 = 0    # not paused any more
		ob.temp2 = 0
		ob.state = S(&"s_keenstand")
		KeenStandThink(ob)
		return

	if (ob.hitnorth & ~7) != 24:    # if it is 0 now, keen is standing on a sprite
		ob.temp1 = s16(ob.temp1 + tics)

	match ob.temp2:
		0:
			if ob.temp1 > 200:
				ob.temp2 += 1
				ob.state = S(&"s_keenpauselook")
				ob.temp1 = 0
		1:
			if ob.temp1 > 300:
				ob.temp2 += 1
				ob.state = S(&"s_keenwait1")
				ob.temp1 = 0
		2:
			if ob.temp1 > 700:
				ob.temp2 += 1
				ob.state = S(&"s_keenyawn1")
				ob.temp1 = 0
		3:
			if ob.temp1 > 400:
				ob.temp2 += 1
				ob.state = S(&"s_keenpauselook")
				ob.temp1 = 0
		4:
			if ob.temp1 > 700:
				ob.temp2 += 1
				ob.state = S(&"s_keenyawn1")
				ob.temp1 = 0
		5:
			if ob.temp1 > 400:
				ob.temp2 += 1
				ob.state = S(&"s_keengosleep1")


## Spawns the zees above Keen's head.
func KeenGoSleepThink(ob: objtype) -> void:
	GetNewObj(true)

	newobj.obclass = inertobj
	newobj.x = player.x
	newobj.y = u16(player.y - 4 * PIXGLOBAL)
	newobj.xdir = 1
	newobj.ydir = -1
	NewState(newobj, S(&"s_keenzee1"))

	ob.temp1 = s16(_obj_to_dosptr(newobj))    # so they can be removed later


func KeenSleepThink(ob: objtype) -> void:
	if c.dir != dir_None or c.button0 or c.button1:
		var tempptr: objtype = _dosptr_to_obj(ob.temp1)
		if tempptr != dummyobj:
			RemoveObj(tempptr)    # remove the zees
		ob.temp1 = 0    # not paused any more
		ob.temp2 = 0
		ob.state = S(&"s_keengetup")


func KeenDieThink(_ob: objtype) -> void:
	playstate = died


@warning_ignore("integer_division")
func KeenDuckThink(ob: objtype) -> void:
	if c.yaxis != 1:
		ob.state = S(&"s_keenstand")
		KeenStandThink(ob)
		return

	if c.xaxis:
		ob.xdir = c.xaxis

	if c.button0 and not button0held:
		# drop down a level
		button0held = true

		var midtile: int = (ob.tileleft + ob.tileright) >> 1
		var bottomtile: int = ob.tilebottom
		var map: int = mapbwidthtable[bottomtile] / 2 + midtile
		var tile: int = mapsegs[1][map]
		if tinf[WESTWALL + tile] or tinf[EASTWALL + tile] or tinf[SOUTHWALL + tile]:
			return    # wall prevents drop down

		map += mapwidth
		tile = mapsegs[1][map]
		if tinf[WESTWALL + tile] or tinf[EASTWALL + tile] or tinf[SOUTHWALL + tile]:
			return    # wall prevents drop down

		var move: int = PIXGLOBAL * (4 if tics < 4 else tics)
		ob.bottom = u16(ob.bottom + move)
		ob.y = u16(ob.y + move)
		ob.xmove = 0
		ob.ymove = 0
		ob.state = S(&"s_keenjumpup3")
		ob.temp2 = 1    # allready in last stage
		ob.xspeed = 0
		ob.yspeed = 0
		SD_PlaySound(PLUMMETSND)


func KeenDropDownThink(ob: objtype) -> void:
	ob.needtoclip = true


func KeenWalkThink(ob: objtype) -> void:
	if not c.xaxis:
		# stopped running
		KeenStandThink(ob)
		return

	ob.xdir = c.xaxis

	if c.yaxis and CheckGrabPole(ob):    # try to go up/down pole
		return

	if c.button0 and not button0held:
		# running jump
		SD_PlaySound(JUMPSND)
		ob.xspeed = s16(ob.xdir * SPDRUNJUMP)
		ob.yspeed = -SPDJUMP
		ob.xmove = 0
		ob.ymove = 0
		button0held = true
		jumptime = JUMPTIME
		ob.state = S(&"s_keenjump1")

	if c.button1 and not button1held:
		# throw
		ob.state = S(&"s_keenthrow1")
		button1held = true
		return

	# give speed for slopes
	var move: int = s16(tics * slopespeed[ob.hitnorth & 7])

	ob.xmove = s16(ob.xmove + move)


func KeenAirThink(ob: objtype) -> void:
	if jumptime:
		if jumptime < tics:
			ob.ymove = s16(ob.yspeed * jumptime)
			jumptime = 0
		else:
			ob.ymove = s16(ob.yspeed * tics)
			if not jumpcheat:
				jumptime -= tics
		if not c.button0:
			jumptime = 0

		if not jumptime:
			ob.temp2 = 0
			ob.state = ob.state.nextstate    # switch to second jump stage
	else:
		DoGravity(ob)

		if ob.yspeed > 0 and not ob.temp2:
			ob.state = ob.state.nextstate    # switch to third jump stage
			ob.temp2 = 1

	if c.xaxis:
		ob.xdir = c.xaxis
		AccelerateX(ob, c.xaxis * 2, MAXXSPEED)
	else:
		FrictionX(ob)

	if c.button1 and not button1held:
		button1held = true
		# throw
		match c.yaxis:
			-1:
				ob.state = S(&"s_keenairthrowup1")
				return
			0:
				ob.state = S(&"s_keenairthrow1")
				return
			1:
				ob.state = S(&"s_keenairthrowdown1")
				return

	if ob.hitsouth == 17:    # going through a pole hole
		ob.xmove = 0
		ob.xspeed = 0

	if c.yaxis == -1:
		CheckGrabPole(ob)


func PoleActions(ob: objtype) -> void:
	if c.xaxis:
		ob.xdir = c.xaxis

	if c.button0 and not button0held:    # jump off the pole
		SD_PlaySound(JUMPSND)
		ob.xspeed = polexspeed[c.xaxis + 1]
		ob.yspeed = -SPDPOLEJUMP
		ob.needtoclip = true
		jumptime = POLEJUMPTIME
		ob.state = S(&"s_keenjump1")
		ob.ydir = 1
		button0held = true
		leavepoletime = SD_GetTimeCount()
		return

	if c.button1 and not button1held:
		button1held = true

		match c.yaxis:
			-1:
				ob.state = S(&"s_keenpolethrowup1")
			0:
				ob.state = S(&"s_keenpolethrow1")
			1:
				ob.state = S(&"s_keenpolethrowdown1")


func KeenPoleThink(ob: objtype) -> void:
	match c.yaxis:
		-1:
			ob.state = S(&"s_keenclimb1")
			ob.ydir = -1
			return
		1:
			ob.state = S(&"s_keenslide1")
			ob.ydir = 1
			KeenDropThink(ob)
			return

	if c.xaxis:
		# walk off pole if right next to ground
		@warning_ignore("integer_division")
		var tile: int = mapsegs[1][mapbwidthtable[ob.tilebottom + 1] / 2 + ob.tilemidx]
		if tinf[NORTHWALL + tile]:
			ob.xspeed = 0
			ob.yspeed = 0
			ob.needtoclip = true
			jumptime = 0
			ob.state = S(&"s_keenjump3")
			ob.ydir = 1
			SD_PlaySound(PLUMMETSND)
			return

	PoleActions(ob)


func KeenClimbThink(ob: objtype) -> void:
	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[ob.tiletop] / 2 + ob.temp4

	if (tinf[INTILE + mapsegs[1][map]] & 0x7f) != 1:
		ob.ymove = 0
		ob.state = S(&"s_keenpole")    # ran out of pole
		return

	match c.yaxis:
		0:
			ob.state = S(&"s_keenpole")
			ob.ydir = 0
		1:
			ob.state = S(&"s_keenslide1")
			ob.ydir = 1
			KeenDropThink(ob)

	PoleActions(ob)


func KeenDropThink(ob: objtype) -> void:
	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[ob.tilebottom] / 2 + ob.temp4

	if (tinf[INTILE + mapsegs[1][map]] & 0x7f) != 1:
		SD_PlaySound(PLUMMETSND)
		ob.state = S(&"s_keenjump3")    # ran out of pole
		jumptime = 0
		ob.temp2 = 1
		ob.xspeed = polexspeed[c.xaxis + 1]
		ob.yspeed = 0
		ob.needtoclip = true
		ob.tilebottom = u16(ob.tilebottom - 1)
		return

	match c.yaxis:
		-1:
			ob.state = S(&"s_keenclimb1")
			ob.ydir = -1
		0:
			ob.state = S(&"s_keenpole")
			ob.ydir = 0

	PoleActions(ob)


## The thrown flower power (or bomb) for each throwing state.
@warning_ignore("integer_division")
func KeenThrow(ob: objtype) -> void:
	if ob.state == S(&"s_keenthrow3"):
		if ob.xdir > 0:
			ThrowPower(u16(ob.midx - 4 * PIXGLOBAL), u16(ob.y + 8 * PIXGLOBAL), dir_East)
		else:
			ThrowPower(u16(ob.midx - 4 * PIXGLOBAL), u16(ob.y + 8 * PIXGLOBAL), dir_West)
		return

	if ob.state == S(&"s_keenpolethrow2"):
		if ob.xdir > 0:
			ThrowPower(u16(ob.x + 24 * PIXGLOBAL), ob.y, dir_East)
		else:
			ThrowPower(u16(ob.x - 8 * PIXGLOBAL), ob.y, dir_West)
		return

	if ob.state == S(&"s_keenthrowup2"):
		ThrowPower(u16(ob.x + 4 * PIXGLOBAL), u16(ob.y - 8 * PIXGLOBAL), dir_North)
		return

	if ob.state == S(&"s_keenpolethrowup2"):
		ThrowPower(u16(ob.x + 8 * PIXGLOBAL), u16(ob.y - 8 * PIXGLOBAL), dir_North)
		return

	if ob.state == S(&"s_keenpolethrowdown2"):
		ThrowPower(u16(ob.x + 8 * PIXGLOBAL), u16(ob.y + 8 * PIXGLOBAL), dir_South)
		return

	if ob.state == S(&"s_keenairthrow2"):
		if ob.xdir > 0:
			ThrowPower(u16(ob.midx - 4 * PIXGLOBAL), u16(ob.y + 8 * PIXGLOBAL), dir_East)
		else:
			ThrowPower(u16(ob.midx - 4 * PIXGLOBAL), u16(ob.y + 8 * PIXGLOBAL), dir_West)
		newobj.xspeed = s16(newobj.xspeed + ob.xspeed / 2)
		newobj.yspeed = s16(newobj.yspeed + ob.yspeed / 2)
		return

	if ob.state == S(&"s_keenairthrowup2"):
		if ob.xdir > 0:
			ThrowPower(u16(ob.x + 16 * PIXGLOBAL), ob.y, dir_North)
		else:
			ThrowPower(u16(ob.x + 4 * PIXGLOBAL), ob.y, dir_North)
		newobj.xspeed = s16(newobj.xspeed + ob.xspeed / 2)
		newobj.yspeed = s16(newobj.yspeed + ob.yspeed / 2)
		return

	if ob.state == S(&"s_keenairthrowdown2"):
		if ob.xdir > 0:
			ThrowPower(u16(ob.x + 3 * PIXGLOBAL), u16(ob.y + 16 * PIXGLOBAL), dir_South)
		else:
			ThrowPower(u16(ob.x + 12 * PIXGLOBAL), u16(ob.y + 16 * PIXGLOBAL), dir_South)
		newobj.xspeed = s16(newobj.xspeed + ob.xspeed / 2)
		newobj.yspeed = s16(newobj.yspeed + ob.yspeed / 2)
		return

	Quit("KeenThrow: Bad state!")


# ---- contact routines

func KillKeen() -> void:
	if not godmode:
		SD_PlaySound(WAKEUPSND)
		player.needtoclip = false
		ChangeState(player, S(&"s_keendie1"))


func KeenContact(ob: objtype, hit: objtype) -> void:
	match hit.obclass:
		bonusobj:
			hit.obclass = inertobj
			match hit.temp1:
				0, 1, 2, 3, 4, 5:
					SD_PlaySound(GETPOINTSSND)
					hit.shapenum = BONUS100SPR + hit.temp1
					GivePoints(bonuspoints[hit.temp1])
					ChangeState(hit, S(&"s_bonusrise"))
				6:
					SD_PlaySound(EXTRAKEENSND)
					hit.shapenum = BONUS1UPSPR
					gamestate.lives += 1
					ChangeState(hit, S(&"s_bonusrise"))
				7:
					SD_PlaySound(EXTRAKEENSND)
					hit.shapenum = BONUSSUPERSPR
					gamestate.lives += 3
					gamestate.flowerpowers += 8
					GivePoints(10000)
					ChangeState(hit, S(&"s_bonusrise"))
				8:
					SD_PlaySound(GETPOWERSND)
					hit.shapenum = BONUSFLOWERSPR
					gamestate.flowerpowers += 1
					ChangeState(hit, S(&"s_bonusrise"))
				9:
					SD_PlaySound(GETPOWERSND)
					hit.shapenum = BONUSFLOWERUPSPR
					gamestate.flowerpowers += 5
					ChangeState(hit, S(&"s_bonusrise"))
				10:
					SD_PlaySound(GETBOMBSND)
					hit.shapenum = BONUSBOMBSPR
					gamestate.boobusbombs += 1
					gamestate.bombsthislevel += 1
					ChangeState(hit, S(&"s_bonusrise"))
				11:
					SD_PlaySound(GETKEYSND)
					hit.shapenum = BONUSKEYSPR
					gamestate.keys += 1
					ChangeState(hit, S(&"s_bonusrise"))

		doorobj:
			if gamestate.keys:
				if hit.state != S(&"s_doorraise"):
					SD_PlaySound(OPENDOORSND)
					gamestate.keys -= 1
					ChangeState(hit, S(&"s_doorraise"))
			else:
				SD_PlaySound(NOWAYSND)
				ClipToSpriteSide(ob, hit)
		taterobj:
			if hit.state == S(&"s_taterattack2"):
				KillKeen()
		carrotobj:
			ClipToSpriteSide(ob, hit)
			if not ob.needtoclip:    # got pushed off a pole
				SD_PlaySound(PLUMMETSND)
				ob.needtoclip = true
				ob.xspeed = 0
				ob.yspeed = 0
				ChangeState(ob, S(&"s_keenjump3"))
				ob.temp2 = 1
				jumptime = 0
		cartobj:
			ClipToSprite(ob, hit, true)
		broccoobj:
			if hit.state == S(&"s_broccosmash3") or hit.state == S(&"s_broccosmash4"):
				KillKeen()
		squashobj:
			if hit.state == S(&"s_squasherjump2"):
				KillKeen()
			else:
				ClipToSpriteSide(ob, hit)
				if not ob.needtoclip:    # got pushed off a pole
					SD_PlaySound(PLUMMETSND)
					ob.needtoclip = true
					ob.xspeed = 0
					ob.yspeed = 0
					ChangeState(ob, S(&"s_keenjump3"))
					ob.temp2 = 1
					jumptime = 0
		grapeobj:
			if hit.state == S(&"s_grapefall"):
				KillKeen()
		tomatobj, celeryobj, asparobj, turnipobj, cauliobj, brusselobj, mushroomobj, apelobj, \
				peabrainobj, boobusobj, shotobj:
			KillKeen()


# ---- reaction routines

func KeenSimpleReact(ob: objtype) -> void:
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)


func KeenStandReact(ob: objtype) -> void:
	if not ob.hitnorth:
		# walked off an edge
		SD_PlaySound(PLUMMETSND)
		ob.xspeed = s16(ob.xdir * WALKAIRSPEED)
		ChangeState(ob, S(&"s_keenjump3"))
		ob.temp2 = 1
		jumptime = 0
	elif (ob.hitnorth & ~7) == 8:    # deadly floor!
		KillKeen()

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)


func KeenWalkReact(ob: objtype) -> void:
	if not ob.hitnorth:
		# walked off an edge
		ob.xspeed = s16(ob.xdir * WALKAIRSPEED)
		ob.yspeed = 0
		ChangeState(ob, S(&"s_keenjump3"))
		ob.temp2 = 1
		jumptime = 0
	elif (ob.hitnorth & ~7) == 8:    # deadly floor!
		KillKeen()
		call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)    # placeit
		return

	if ob.hiteast == 2:    # doors
		pass
	elif ob.hitwest == 2:    # doors
		pass
	elif ob.hiteast or ob.hitwest:
		# ran into a wall
		ob.ticcount = 0
		ob.state = S(&"s_keenstand")
		ob.shapenum = u16(S(&"s_keenstand").rightshapenum if ob.xdir == 1 else S(&"s_keenstand").leftshapenum)

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)


func KeenAirReact(ob: objtype) -> void:
	if ob.hiteast or ob.hitwest:
		ob.xspeed = 0

	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[ob.tiletop] / 2 + ob.tileleft
	var mapextra: int = mapwidth - (ob.tileright - ob.tileleft + 1)
	var through: bool = false    # the C's goto checknorth
	var y: int = ob.tiletop
	while y <= ob.tilebottom and not through:
		var x: int = ob.tileleft
		while x <= ob.tileright:
			if tinf[SOUTHWALL + mapsegs[1][map]] == 17:    # jumping up through a pole hole
				ob.xspeed = 0
				ob.x = u16(ob.tilemidx * TILEGLOBAL - 2 * PIXGLOBAL)
				through = true
				break
			x += 1
			map += 1
		y += 1
		map += mapextra

	if not through and ob.hitsouth:
		if ob.hitsouth == 17:    # jumping up through a pole hole
			ob.y = u16(ob.y - 32)
			ob.top = u16(ob.top - 32)
			ob.xspeed = 0
			ob.x = u16(ob.tilemidx * TILEGLOBAL - 2 * PIXGLOBAL)
		else:
			SD_PlaySound(HITHEADSND)

			if ob.hitsouth > 1:
				ob.yspeed = s16(ob.yspeed + 16)
				if ob.yspeed < 0:    # push away from slopes
					ob.yspeed = 0
			else:
				ob.yspeed = 0
			jumptime = 0

	# checknorth
	if ob.hitnorth:
		if not (ob.hitnorth == 25 and jumptime):    # KLUDGE to allow jumping off sprites
			ob.temp1 = 0
			ob.temp2 = 0
			ChangeState(ob, S(&"s_keenstand"))
			SD_PlaySound(LANDSND)

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)


func KeenSlideReact(ob: objtype) -> void:
	if ob.hitnorth:    # friction slow down
		@warning_ignore("integer_division")
		var map: int = mapbwidthtable[ob.tiletop] / 2 + ob.tileleft
		if not tinf[SOUTHWALL + mapsegs[2][map]] and not tinf[SOUTHWALL + mapsegs[2][map + 1]]:
			FrictionX(ob)

	if ob.hitwest or ob.hiteast or not ob.xspeed:
		ChangeState(ob, S(&"s_keengetup"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, KEENPRIORITY)


## (REFKEEN) Patching version-specific stuff: the score box's character drawer (EGA).
func RefKeen_Patch_kd_keen() -> void:
	MemDrawChar = &"MemDrawCharEGA"


# ===================================================================== kd_act1.c: misc actor stuff

## Changes speed and location (only accelerates on odd tics, because of limited precision).
func DoGravity(ob: objtype) -> void:
	for i: int in range(lasttimecount - tics, lasttimecount):
		if i & 1:
			if ob.yspeed < 0 and ob.yspeed >= -ACCGRAVITY:
				# stop at apex of jump
				ob.ymove = s16(ob.ymove + ob.yspeed)
				ob.yspeed = 0
				return
			ob.yspeed = s16(ob.yspeed + ACCGRAVITY)
			if ob.yspeed > SPDMAXY:
				ob.yspeed = SPDMAXY
		ob.ymove = s16(ob.ymove + ob.yspeed)


func AccelerateX(ob: objtype, dir: int, maxspeed: int) -> void:
	var olddir: int = ob.xspeed & 0x8000
	# only accelerate on odd tics, because of limited precision
	for i: int in range(lasttimecount - tics, lasttimecount):
		if i & 1:
			ob.xspeed = s16(ob.xspeed + dir)
			if (ob.xspeed & 0x8000) != olddir:
				olddir = ob.xspeed & 0x8000
				ob.xdir = -1 if olddir else 1
			if ob.xspeed > maxspeed:
				ob.xspeed = maxspeed
			elif ob.xspeed < -maxspeed:
				ob.xspeed = s16(-maxspeed)
		ob.xmove = s16(ob.xmove + ob.xspeed)


func FrictionX(ob: objtype) -> void:
	var dir: int
	var olddir: int = ob.xspeed & 0x8000

	if ob.xspeed > 0:
		dir = -1
	elif ob.xspeed < 0:
		dir = 1
	else:
		dir = 0
	# only accelerate on odd tics, because of limited precision
	for i: int in range(lasttimecount - tics, lasttimecount):
		if i & 1:
			ob.xspeed = s16(ob.xspeed + dir)
			if (ob.xspeed & 0x8000) != olddir:
				ob.xspeed = 0
		ob.xmove = s16(ob.xmove + ob.xspeed)


func ProjectileThink(ob: objtype) -> void:
	DoGravity(ob)
	ob.xmove = s16(tics * ob.xspeed)


func VelocityThink(ob: objtype) -> void:
	ob.xmove = s16(tics * ob.xspeed)
	ob.ymove = s16(tics * ob.yspeed)


func DrawReact(ob: objtype) -> void:
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 1)


func DrawReact2(ob: objtype) -> void:
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 2)


func DrawReact3(ob: objtype) -> void:
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 3)


func ChangeState(ob: objtype, state: statetype) -> void:
	ob.state = state
	ob.ticcount = 0
	# REFKEEN - state can be NULL (a loaded game's flower in one of the s_pooffrom* states); DOS
	# read zeros there.
	if state != null and state.rightshapenum:
		if ob.xdir > 0:
			ob.shapenum = u16(state.rightshapenum)
		else:
			ob.shapenum = u16(state.leftshapenum)

	ob.xmove = 0
	ob.ymove = 0

	ob.needtoreact = true    # it will need to be redrawn this frame
	ClipToWalls(ob)


func WalkReact(ob: objtype) -> void:
	if ob.xdir == 1 and ob.hitwest:
		ob.x = u16(ob.x - ob.xmove)
		ob.xdir = -1
		ob.nothink = US_RndT() >> 5
		ChangeState(ob, ob.state)
	elif ob.xdir == -1 and ob.hiteast:
		ob.x = u16(ob.x - ob.xmove)
		ob.xdir = 1
		ob.nothink = US_RndT() >> 5
		ChangeState(ob, ob.state)
	elif not ob.hitnorth:
		ob.x = u16(ob.x - 2 * ob.xmove)
		ob.y = u16(ob.y - ob.ymove)

		ob.xdir = -ob.xdir
		ob.nothink = US_RndT() >> 5
		ChangeState(ob, ob.state)

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act1.c: door

func SpawnDoor(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = doorobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	newobj.ydir = -1
	newobj.needtoclip = false
	NewState(newobj, S(&"s_door"))


func DoorContact(ob: objtype, hit: objtype) -> void:
	ClipToSpriteSide(hit, ob)


# ===================================================================== kd_act1.c: flower
# temp1 = original class, temp2 = original state, temp3 = flower count

func ChangeToFlower(ob: objtype) -> void:
	SD_PlaySound(FLOWERPOWERSND)
	ob.y = u16(ob.bottom - TILEGLOBAL * 2)
	ob.temp1 = ob.obclass
	# (REFKEEN) BACKWARDS COMPATIBILITY: the state's DOS offset, and the state itself beside it
	ob.temp2 = s16(ob.state.compatdospointer)
	ob.temp2stateptr = ob.state
	ob.temp3 = 0
	ob.needtoclip = true
	ob.obclass = inertobj
	ob.xspeed = 0
	ChangeState(ob, S(&"s_flower1"))
	ob.active = allways    # flower never deactivated
	GetNewObj(true)
	newobj.x = ob.x
	newobj.y = ob.y
	NewState(newobj, S(&"s_poofto1"))
	newobj.active = removable


func FlowerThink(ob: objtype) -> void:
	ProjectileThink(ob)
	ob.temp3 = s16(ob.temp3 + tics)
	if ob.temp3 >= flowertime[gamestate.difficulty]:
		GetNewObj(true)
		newobj.active = allways
		newobj.temp1 = s16(_obj_to_dosptr(ob))
		newobj.x = ob.x
		newobj.y = ob.y
		NewState(newobj, S(&"s_pooffrom1"))
		ob.temp3 = 0


func ChangeFromFlower(ob: objtype) -> void:
	SD_PlaySound(UNFLOWERPOWERSND)
	var flower: objtype = _dosptr_to_obj(ob.temp1)

	var oldbottom: int = flower.bottom
	ChangeState(flower, flower.temp2stateptr)
	flower.y = u16(flower.y + oldbottom - flower.bottom)

	flower.obclass = flower.temp1
	flower.active = yes    # allow it to unspawn now if off screen


# ===================================================================== kd_act1.c: bonus
# temp1 = bonus type, temp2 = base shape number, temp3 = last animated shape number +1

func SpawnBonus(tilex: int, tiley: int, type: int) -> void:
	GetNewObj(false)

	newobj.needtoclip = false
	newobj.obclass = bonusobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16(tiley << G_T_SHIFT)

	if type == 9:
		newobj.y = u16(newobj.y - 8 * PIXGLOBAL)    # flower power up one block

	newobj.ydir = -1    # bonus stuff flies up when touched

	newobj.temp1 = type
	newobj.shapenum = bonusshape[type]
	newobj.temp2 = newobj.shapenum
	if type != 7:
		newobj.temp3 = newobj.temp2 + 2
	else:
		newobj.temp3 = newobj.temp2 + 4    # super bonus is 4 stage animation

	NewState(newobj, S(&"s_bonus"))


func BonusThink(ob: objtype) -> void:
	ob.shapenum = u16(ob.shapenum + 1)
	if ob.shapenum == ob.temp3:
		ob.shapenum = ob.temp2


# ===================================================================== kd_act1.c: broccolash

func SpawnBrocco(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = broccoobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	NewState(newobj, S(&"s_broccowalk1"))


func BroccoGetUp(ob: objtype) -> void:
	ob.needtoclip = true


@warning_ignore("integer_division")
func BroccoThink(ob: objtype) -> void:
	if ob.top > player.bottom or ob.bottom < player.top:
		return

	var delta: int = s16(player.x - ob.x)

	if ob.xdir == -1:
		if delta < -3 * TILEGLOBAL:
			return
		if delta > TILEGLOBAL / 2:
			ob.xdir = 1
			return
		ob.state = S(&"s_broccosmash1")
		ob.needtoclip = false
		ob.xmove = 0
		return
	else:
		delta = s16(player.left - ob.right)
		if delta > 3 * TILEGLOBAL:
			return
		if delta < -TILEGLOBAL / 2:
			ob.xdir = -1
			return
		ob.state = S(&"s_broccosmash1")
		ob.needtoclip = false
		ob.xmove = 0
		return


# ===================================================================== kd_act1.c: tomatooth
# temp1 = jumptime

func SpawnTomat(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = tomatobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 1 * BLOCKSIZE)
	newobj.xdir = 1
	NewState(newobj, S(&"s_tomatbounce"))


func TomatBounceThink(ob: objtype) -> void:
	AccelerateX(ob, -1 if ob.x > player.x else 1, SPDTOMAT)
	if ob.xspeed > 0:
		ob.xdir = 1
	else:
		ob.xdir = -1

	if ob.temp1:
		if ob.temp1 < tics:
			ob.ymove = s16(ob.yspeed * ob.temp1)
			ob.temp1 = 0
		else:
			ob.ymove = s16(ob.yspeed * tics)
			ob.temp1 = s16(ob.temp1 - tics)
	else:
		DoGravity(ob)


func TomatReact(ob: objtype) -> void:
	if ob.hiteast or ob.hitwest:
		ob.xdir = -ob.xdir
		ob.xspeed = s16(-ob.xspeed)

	if ob.hitsouth:
		if ob.tileright >= originxtile and ob.tileleft <= originxtilemax \
				and ob.tiletop >= originytile and ob.tilebottom <= originytilemax:
			SD_PlaySound(BOUNCESND)
		ob.yspeed = s16(-ob.yspeed)

	if ob.hitnorth:
		if ob.tileright >= originxtile and ob.tileleft <= originxtilemax \
				and ob.tiletop >= originytile and ob.tilebottom <= originytilemax:
			SD_PlaySound(BOUNCESND)
		ob.yspeed = s16(-SPDTOMATBOUNCE - (US_RndT() >> 4))
		ob.temp1 = TICTOMATJUMP

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act1.c: carrot courier

func SpawnCarrot(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = carrotobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_carrotwalk1"))
	newobj.hitnorth = 1


func CarrotReact(ob: objtype) -> void:
	if ob.xdir == 1 and ob.hitwest:
		ob.xdir = -1
	elif ob.xdir == -1 and ob.hiteast:
		ob.xdir = 1
	elif not ob.hitnorth:
		ob.x = u16(ob.x - ob.xmove)
		ob.y = u16(ob.y - ob.ymove)

		ob.yspeed = -SPDCARROTLEAPY
		ob.xspeed = s16(SPDCARROTLEAPX * ob.xdir)
		ChangeState(ob, S(&"s_carrotleap"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


func CarrotAirReact(ob: objtype) -> void:
	if ob.hitsouth:
		ob.yspeed = 0

	if ob.hitnorth:
		ChangeState(ob, S(&"s_carrotwalk1"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act1.c: asparagusto

func SpawnAspar(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = asparobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16(tiley << G_T_SHIFT)
	newobj.xdir = 1
	NewState(newobj, S(&"s_asparwalk1"))


# ===================================================================== kd_act1.c: sour grape

func SpawnGrape(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = grapeobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16(tiley << G_T_SHIFT)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_grapewait"))


func GrapeThink(ob: objtype) -> void:
	if player.left > ob.right or player.right < ob.left or player.y < ob.y:
		return

	# see if there are any walls between grape and player
	var starty: int = ob.tilebottom
	var endy: int = player.tiletop

	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[starty] / 2 + ob.tilemidx
	var y: int = starty
	while y < endy:
		if tinf[NORTHWALL + mapsegs[1][map]]:
			return
		y += 1
		map += mapwidth

	ob.state = S(&"s_grapefall")
	SD_PlaySound(GRAPESCREAMSND)


func GrapeRiseReact(ob: objtype) -> void:
	if ob.hitsouth:
		ChangeState(ob, S(&"s_grapewait"))
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


func GrapeFallReact(ob: objtype) -> void:
	if ob.hitnorth:
		SD_PlaySound(BOUNCESND)
		@warning_ignore("integer_division")
		ob.yspeed = s16(-(ob.yspeed << 1) / 3)
		if ob.yspeed > -32:
			ChangeState(ob, S(&"s_grapesit"))
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act2.c: tater trooper
# temp1 = chasing player, temp2 = nothink time

func SpawnTater(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = taterobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE + 15)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_taterwalk1"))
	newobj.hitnorth = 1


func TaterThink(ob: objtype) -> void:
	if ob.top > player.bottom or ob.bottom < player.top:
		return

	var delta: int
	if ob.xdir == -1:
		delta = s16(ob.left - player.right)
		if delta > TILEGLOBAL:
			return
		if delta < -8 * PIXGLOBAL:
			ob.xdir = 1
			return
		SD_PlaySound(TATERSWINGSND)
		ob.state = S(&"s_taterattack1")
		return
	else:
		delta = s16(player.left - ob.right)
		if delta > TILEGLOBAL:
			return
		if delta < -8 * PIXGLOBAL:
			ob.xdir = -1
			return
		SD_PlaySound(TATERSWINGSND)
		ob.state = S(&"s_taterattack1")
		return


func BackupReact(ob: objtype) -> void:
	if not ob.hitnorth:
		ob.x = u16(ob.x - ob.xmove)
		ob.y = u16(ob.y - ob.ymove)

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act2.c: canteloupe cart

func SpawnCart(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = cartobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 3 * PIXGLOBAL)
	newobj.xdir = 1
	newobj.ydir = 1
	newobj.active = allways
	NewState(newobj, S(&"s_cartroll1"))


func CartReact(ob: objtype) -> void:
	if ob.xdir == 1 and ob.hitwest:
		ob.xdir = -1
	elif ob.xdir == -1 and ob.hiteast:
		ob.xdir = 1

	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[ob.tilebottom + 1] / 2
	if ob.xdir == 1:
		map += ob.tileright
	else:
		map += ob.tileleft

	if not tinf[NORTHWALL + mapsegs[1][map]]:
		ob.xdir = -ob.xdir

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act2.c: frenchy

func SpawnFrenchy(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = frenchyobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_frenchywalk1"))


func FrenchyRunThink(ob: objtype) -> void:
	ob.state = S(&"s_frenchywalk1")


func FrenchyThrow(ob: objtype) -> void:
	GetNewObj(true)
	newobj.obclass = shotobj
	if ob.xdir == 1:
		newobj.x = u16(ob.x + 24 * 16)
		newobj.y = u16(ob.y + 8 * 16)
	else:
		newobj.x = ob.x
		newobj.y = u16(ob.y + 8 * 16)
	newobj.xdir = ob.xdir
	newobj.ydir = 1
	newobj.xspeed = s16(ob.xdir * FRYXSPEED - (US_RndT() >> 4))
	newobj.yspeed = FRYYSPEED
	newobj.active = removable
	NewState(newobj, S(&"s_fry1"))

	ob.nothink = 2


func FrenchyThink(ob: objtype) -> void:
	if absi(s16(ob.y - player.y)) > 3 * TILEGLOBAL:
		if US_RndT() < 8:
			ob.xdir = -ob.xdir    # turn randomly
		return

	var delta: int = s16(player.x - ob.x)

	if delta < -8 * TILEGLOBAL:
		# walk closer
		ob.xdir = -1
	if delta < -4 * TILEGLOBAL:
		# throw
		ob.xdir = -1
		ob.state = S(&"s_frenchythrow1")
	elif delta < 0:
		# run away
		ob.xdir = 1
		ob.state = S(&"s_frenchyrun1")
		ob.nothink = 8
	elif delta < 4 * TILEGLOBAL:
		# run away
		ob.xdir = -1
		ob.state = S(&"s_frenchyrun1")
		ob.nothink = 8
	elif delta < 8 * TILEGLOBAL:
		# throw and walk closer
		ob.xdir = 1
		ob.state = S(&"s_frenchythrow1")
	else:
		# walk closer
		ob.xdir = 1


# ===================================================================== kd_act2.c: melon lips
# temp1 = direction: 0 = left, 1 = right, 2 = down

func SpawnMelon(tilex: int, tiley: int, dir: int) -> void:
	GetNewObj(false)

	newobj.obclass = melonobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16(tiley << G_T_SHIFT)
	if dir:
		newobj.xdir = 1
	else:
		newobj.xdir = -1
	if dir < 2:
		NewState(newobj, S(&"s_melonside"))
	else:
		NewState(newobj, S(&"s_melondown"))

	newobj.ticcount = US_RndT() >> 1
	newobj.temp1 = dir


func MelonSpitThink(ob: objtype) -> void:
	GetNewObj(false)
	newobj.obclass = shotobj
	match ob.temp1:
		0:
			newobj.x = u16(ob.x + 24 * 16)
			newobj.y = u16(ob.y + 8 * 16)
			newobj.xdir = ob.xdir
			newobj.ydir = 1
			newobj.xspeed = s16(-SPITXSPEED - (US_RndT() >> 4))
			newobj.yspeed = SPITYSPEED
			NewState(newobj, S(&"s_melonseed1"))
		1:
			newobj.x = ob.x
			newobj.y = u16(ob.y + 8 * 16)
			newobj.xdir = ob.xdir
			newobj.ydir = 1
			newobj.xspeed = s16(SPITXSPEED + (US_RndT() >> 4))
			newobj.yspeed = SPITYSPEED
			NewState(newobj, S(&"s_melonseed1"))
		2:
			newobj.x = u16(ob.x + 8 * 16)
			newobj.y = u16(ob.y + 24 * 16)
			newobj.ydir = 1
			newobj.yspeed = -SPITYSPEED
			NewState(newobj, S(&"s_melonseedd1"))

	newobj.active = removable


func ProjectileReact(ob: objtype) -> void:
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)
	if ob.hiteast or ob.hitwest:
		@warning_ignore("integer_division")
		ob.xspeed = s16(-ob.xspeed / 2)

	if ob.hitsouth:
		@warning_ignore("integer_division")
		ob.yspeed = s16(-ob.yspeed / 2)

	var wall: int = u16(ob.hitnorth)
	if wall:
		var speed: int = _floor_bounce(ob)
		if speed < 256 * 16:
			RemoveObj(ob)


# ===================================================================== kd_act2.c: squasher

func SpawnSquasher(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = squashobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_squasherwalk1"))


func SquasherThink(ob: objtype) -> void:
	if absi(s16(ob.y - player.y)) > 3 * TILEGLOBAL:
		if US_RndT() < 8:
			ob.xdir = -ob.xdir    # turn randomly
		return

	var delta: int = s16(player.x - ob.x)

	if ob.xdir == -1:
		if delta < -6 * TILEGLOBAL:
			return
		if delta > 8 * PIXGLOBAL:
			ob.xdir = 1
			return
	else:
		if delta > 6 * TILEGLOBAL:
			return
		if delta < -8 * PIXGLOBAL:
			ob.xdir = 1
			return

	ob.yspeed = -SPDSQUASHLEAPY
	@warning_ignore("integer_division")
	ob.xspeed = delta / 60
	ob.state = S(&"s_squasherjump1")


func SquasherJumpReact(ob: objtype) -> void:
	if ob.hitsouth:
		ob.yspeed = 0

	if ob.hitnorth:
		ChangeState(ob, S(&"s_squasherwait"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act2.c: apel
# temp4 = pole x coordinate

func SpawnApel(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = apelobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_apelwalk1"))


func ApelThink(ob: objtype) -> void:
	if ob.top > player.bottom or ob.bottom < player.top:
		# try to climb a pole to reach player
		var y: int
		if ob.y < player.y:
			y = ob.tilebottom
		else:
			y = ob.tiletop

		@warning_ignore("integer_division")
		var map: int = mapbwidthtable[y] / 2 + ob.tilemidx

		if (tinf[INTILE + mapsegs[1][map]] & 0x7f) == 1:
			ob.xmove = s16((ob.tilemidx << G_T_SHIFT) - ob.x)
			ob.ymove = 0
			ob.temp4 = ob.tilemidx    # for future reference
			ob.needtoclip = false    # can climb through pole holes
			if ob.y < player.y:
				ob.state = S(&"s_apelslide1")
			else:
				ob.state = S(&"s_apelclimb1")
			return

	if US_RndT() > 32:    # don't turn around all the time
		return

	if ob.x < player.x:
		ob.xdir = 1
	else:
		ob.xdir = -1


func ApelClimbThink(ob: objtype) -> void:
	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[ob.tiletop] / 2 + ob.temp4

	if (tinf[INTILE + mapsegs[1][map]] & 0x7f) != 1:
		ob.needtoclip = true
		ob.state = S(&"s_apelfall")


func ApelSlideThink(ob: objtype) -> void:
	@warning_ignore("integer_division")
	var map: int = mapbwidthtable[ob.tilebottom] / 2 + ob.temp4

	if (tinf[INTILE + mapsegs[1][map]] & 0x7f) != 1:
		ob.needtoclip = true
		ob.state = S(&"s_apelfall")


func ApelClimbReact(ob: objtype) -> void:
	if ob.hitsouth:
		ChangeState(ob, S(&"s_apelfall"))
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


func ApelFallReact(ob: objtype) -> void:
	if ob.hitnorth:
		ChangeState(ob, S(&"s_apelwalk1"))
	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act2.c: pea brain

func SpawnPeaBrain(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = peabrainobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16(tiley << G_T_SHIFT)
	NewState(newobj, S(&"s_peabrainwalk1"))


func PeaBrainThink(_ob: objtype) -> void:
	pass


func PeaFlyReact(ob: objtype) -> void:
	if ob.hitnorth:
		ChangeState(ob, S(&"s_peabrainwalk1"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== kd_act2.c: pea pod
# temp1 = number of peas spit

func SpawnPeaPod(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = peapodobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 2 * BLOCKSIZE)
	newobj.xdir = 1
	newobj.ydir = 1
	NewState(newobj, S(&"s_peapodwalk1"))


func SpitPeaBrain(ob: objtype) -> void:
	GetNewObj(true)
	newobj.obclass = peabrainobj
	if ob.xdir == 1:
		newobj.x = u16(ob.x + 8 * 16)
		newobj.y = u16(ob.y + 8 * 16)
	else:
		newobj.x = ob.x
		newobj.y = u16(ob.y + 8 * 16)
	newobj.xdir = ob.xdir
	newobj.ydir = 1
	newobj.xspeed = s16(ob.xdir * PEAXSPEED - (US_RndT() >> 4))
	newobj.yspeed = PEAYSPEED
	NewState(newobj, S(&"s_peabrainfly"))


func PeaPodThink(ob: objtype) -> void:
	if absi(s16(ob.y - player.y)) > 3 * TILEGLOBAL:
		return

	if player.x < ob.x and ob.xdir == 1:
		return

	if player.x > ob.x and ob.xdir == -1:
		return

	if US_RndT() < 8 and ob.temp1 < MAXPEASPIT:
		ob.temp1 += 1
		ob.state = S(&"s_peapodspit1")
		ob.xmove = 0


# ===================================================================== kd_act2.c: boobus tubor
# temp4 = hit points

func SpawnBoobus(tilex: int, tiley: int) -> void:
	GetNewObj(false)

	newobj.obclass = boobusobj
	newobj.x = u16(tilex << G_T_SHIFT)
	newobj.y = u16((tiley << G_T_SHIFT) - 11 * BLOCKSIZE)
	newobj.xdir = -1
	NewState(newobj, S(&"s_boobuswalk1"))
	newobj.temp4 = 12    # hit points


func FragThink(ob: objtype) -> void:
	ob.temp1 += 1
	if ob.temp1 == PREFRAGTHINK:
		ob.state = S(&"s_boobusdie2")
	ob.temp1 += 1
	if ob.temp1 == POSTFRAGTHINK:
		call(RF_RemoveSprite, ob)
		ob.state = S(&"s_boobusdie3")

	SD_PlaySound(BOMBBOOMSND)
	GetNewObj(true)
	newobj.x = u16(ob.x - BLOCKSIZE + 5 * US_RndT())
	newobj.y = u16(ob.y - BLOCKSIZE + 5 * US_RndT())
	newobj.xspeed = 0
	newobj.yspeed = 0
	US_RndT()    # keep rnd from even wrapping
	ChangeState(newobj, S(&"s_deathboom1"))


func FinishThink(_ob: objtype) -> void:
	playstate = victorious
	SD_PlaySound(BOOBUSGONESND)


func BoobusThink(ob: objtype) -> void:
	var to_be_inline: bool = false

	if ob.left > player.right:
		ob.xdir = -1
	elif ob.right < player.left:
		ob.xdir = 1
	else:
		to_be_inline = true

	if player.top < ob.bottom and player.bottom > ob.top:
		pass    # on same level as player, so charge!
	else:
		# above or below player, so get directly in line and jump
		if to_be_inline:
			if ob.y < player.y:
				# drop down
				var move: int = PIXGLOBAL * 8
				ob.tilebottom = u16(ob.tilebottom + 1)
				ob.bottom = u16(ob.bottom + move)
				ob.y = u16(ob.y + move)
				ob.state = S(&"s_boobusjump")
				ob.ymove = 0
				ob.xspeed = 0
				ob.xmove = 0
				ob.yspeed = 0
			else:
				# jump up
				ob.state = S(&"s_boobusjump")
				ob.yspeed = -SPDBOOBUSJUMP
				ob.xspeed = 0


func BoobusGroundReact(ob: objtype) -> void:
	if ob.xdir == 1 and ob.hitwest:
		ob.x = u16(ob.x - ob.xmove)
		ob.xdir = -1
		ob.nothink = US_RndT() >> 5
		ChangeState(ob, ob.state)
	elif ob.xdir == -1 and ob.hiteast:
		ob.x = u16(ob.x - ob.xmove)
		ob.xdir = 1
		ob.nothink = US_RndT() >> 5
		ChangeState(ob, ob.state)
	elif not ob.hitnorth:
		if ob.bottom >= player.bottom:
			# jump over
			ob.x = u16(ob.x - ob.xmove)
			ob.y = u16(ob.y - ob.ymove)
			ob.yspeed = -SPDBOOBUSJUMP
			ob.xspeed = s16(ob.xdir * SPDBOOBUSRUNJUMP)
		else:
			# drop down
			ob.xspeed = 0
			ob.yspeed = 0
		ChangeState(ob, S(&"s_boobusjump"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


func BoobusAirReact(ob: objtype) -> void:
	if ob.hitsouth:
		ob.yspeed = 0

	if ob.hitnorth:
		ChangeState(ob, S(&"s_boobuswalk1"))

	call(RF_PlaceSprite, ob, ob.x, ob.y, ob.shapenum, spritedraw, 0)


# ===================================================================== the shell's cheats (CHEAT-01)

## The cheats this engine has (CheatsModel's keys). No Unlock the map (Tuberia's levels are open).
func shell_cheat_supported() -> Array:
	return ["god", "infinite_ammo", "infinite_lives", "no_clip", "jump", "slow_motion", "reveal_secrets",
		"freeze_enemies", "free_items", "extra_lives", "skip_level", "level_select"]


func shell_in_game() -> bool:
	return ingame


func shell_cheat_get(key: String) -> bool:
	match key:
		"god": return godmode
		"infinite_ammo": return cheat_infiniteAmmo
		"infinite_lives": return cheat_infiniteLives
		"no_clip": return cheat_noClip
		"jump": return jumpcheat
		"slow_motion": return singlestep
		"freeze_enemies": return cheat_freezeEnemies
		"reveal_secrets": return cheat_revealSecrets
	return false


func shell_cheat_set(key: String, on: bool) -> void:
	match key:
		"god": godmode = on
		"infinite_ammo": cheat_infiniteAmmo = on
		"infinite_lives": cheat_infiniteLives = on
		"no_clip": cheat_noClip = on
		"jump": jumpcheat = on
		"slow_motion": singlestep = on
		"freeze_enemies": cheat_freezeEnemies = on
		"reveal_secrets": cheat_revealSecrets = on


## A one-shot applied; what it did, for the help line. Skip this level leaves the panel too (the level
## ends as if Keen walked out: playstate levelcomplete, F10+E's in Keen 4-6).
func shell_cheat_fire(key: String) -> String:
	match key:
		"free_items":
			# F10+I's, without its window and wait
			gamestate.boobusbombs = 99
			gamestate.flowerpowers = 99
			gamestate.keys = 99
			return "99 Flowers, 99 Bombs, 99 Keys"
		"extra_lives":
			var before: int = gamestate.lives
			gamestate.lives = s16(mini(before + CheatsModel.EXTRA_LIVES, CheatsModel.MAX_LIVES))
			return "%d Lives" % gamestate.lives if gamestate.lives != before else "Lives Are Full"
		"skip_level":
			if gamestate.mapon == 0:
				return "Only Inside a Level"
			playstate = levelcomplete
			ResumeGame = true    # the panel closes: the level ends at once
			return "Level Skipped"
	return ""


## Level select's list (CHEAT-04): the release's levels by their names (the original names some by
## number). v1.00 lacks maps 6, 8, 11 and 13: its warp there quits to DOS, so they are not offered.
func shell_levels() -> Array:
	var out: Array = []
	for n: int in range(1, 17):
		if data != null and not data.has_map(n):
			continue
		out.append([n, levelnames[n] if n < levelnames.size() and levelnames[n] != "" else "Level %d" % n])
	return out


## Level select chose a level: entered as F10+W enters it (the panel closes, PlayLoop leaves for it).
## Returns why not, or "".
func shell_warp_to(n: int) -> String:
	if not ingame:
		return "Only During a Game"
	gamestate.mapon = n
	playstate = warptolevel
	ResumeGame = true
	return ""
