# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of IDLIBC.C and IDASM.ASM from K1n9_Duk3's Reconstructed Commander
# Keen 1-3 Source Code (Copyright (C) 2021-2026 K1n9_Duk3, after the Hovertank
# 3-D and Catacomb source code, Copyright (C) 1993-2014 Flat Rock Software),
# GPL v2 or later. Function names are the original's so that every routine
# can be read against its source. VERSION is 1.31 (the Steam release); the
# older versions' branches are left out.
class_name VortLib
extends RefCounted
## The Vorticons engine's library layer: the EGA drawing routines (through the
## emulated card), the adaptive tile refresh, the keyboard and joystick, the
## speaker sound played from the timer interrupt, the random generators, the
## text windows and the control-panel file. Nothing here knows Godot's scene
## tree, the wall clock or the window (A8).

# ------------------------------------------------------------- constants

const SCREENWIDTH: int = 48
const PORTTILESWIDE: int = 21
const PORTTILESHIGH: int = 14
const PORTTILECOUNT: int = PORTTILESWIDE * PORTTILESHIGH
const BIGPORTSIZE: int = (PORTTILESHIGH + 1) * (PORTTILESWIDE + 1)
const MAXTILES: int = 700
const LATCH_BASE: int = 0x7000       # segment A700h
const BLANKCHAR: int = 32

# ports and registers
const SC_INDEX: int = 0x3C4
const SC_MAPMASK: int = 2
const CRTC_INDEX: int = 0x3D4
const CRTC_STARTHIGH: int = 12
const CRTC_STARTLOW: int = 13
const CRTC_OFFSET: int = 19
const CRTC_LINECOMPARE: int = 24
const CRTC_OVERFLOW: int = 7
const CRTC_MAXSCANLINE: int = 9
const GC_INDEX: int = 0x3CE
const GC_READMAP: int = 4
const GC_MODE: int = 5
const GC_BITMASK: int = 8
const ATR_INDEX: int = 0x3C0
const ATR_PELPAN: int = 19
const STATUS_REGISTER_1: int = 0x3DA

# dirtype
const north: int = 0
const northeast: int = 1
const east: int = 2
const southeast: int = 3
const south: int = 4
const southwest: int = 5
const west: int = 6
const northwest: int = 7
const nodir: int = 8

# inputtype
const keyboard: int = 0
const mouse: int = 1
const joystick1: int = 2
const joystick2: int = 3
const demo: int = 4

# demoenum
const notdemo: int = 0
const demoplay: int = 1
const recording: int = 2

# cardtype
const EGAcard: int = 3
const VGAcard: int = 5

# BIOSKEY scan codes
const KEY_ESC: int = 1
const KEY_1: int = 2
const KEY_9: int = 10
const KEY_0: int = 11
const KEY_BACKSPACE: int = 14
const KEY_TAB: int = 15
const KEY_Q: int = 16
const KEY_W: int = 17
const KEY_E: int = 18
const KEY_R: int = 19
const KEY_T: int = 20
const KEY_Y: int = 21
const KEY_U: int = 22
const KEY_I: int = 23
const KEY_O: int = 24
const KEY_P: int = 25
const KEY_ENTER: int = 28
const KEY_CTRL: int = 29
const KEY_A: int = 30
const KEY_S: int = 31
const KEY_D: int = 32
const KEY_F: int = 33
const KEY_G: int = 34
const KEY_H: int = 35
const KEY_J: int = 36
const KEY_K: int = 37
const KEY_L: int = 38
const KEY_LSHIFT: int = 42
const KEY_Z: int = 44
const KEY_X: int = 45
const KEY_C: int = 46
const KEY_V: int = 47
const KEY_B: int = 48
const KEY_N: int = 49
const KEY_M: int = 50
const KEY_RSHIFT: int = 54
const KEY_ALT: int = 56
const KEY_SPACE: int = 57
const KEY_F1: int = 59
const KEY_F2: int = 60
const KEY_F3: int = 61
const KEY_F4: int = 62
const KEY_F5: int = 63
const KEY_F6: int = 64
const KEY_F7: int = 65
const KEY_F8: int = 66
const KEY_F9: int = 67
const KEY_F10: int = 68
const KEY_HOME: int = 71
const KEY_UP: int = 72
const KEY_PGUP: int = 73
const KEY_LEFT: int = 75
const KEY_RIGHT: int = 77
const KEY_END: int = 79
const KEY_DOWN: int = 80
const KEY_PGDN: int = 81
const KEY_INS: int = 82
const KEY_DEL: int = 83
const CHAR_ESCAPE: int = 27
const CHAR_ENTER: int = 13

const scanascii: PackedByteArray = [
	0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9, 113,
	119, 101, 114, 116, 121, 117, 105, 111, 112, 91, 93, 13, 0, 97, 115,
	100, 102, 103, 104, 106, 107, 108, 59, 39, 96, 0, 92, 122, 120, 99,
	118, 98, 110, 109, 44, 46, 47, 0, 42, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 1, 1, 1, 45, 1, 1, 1, 43, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

const rndtable: PackedByteArray = [
	0, 8, 109, 220, 222, 241, 149, 107, 75, 248, 254, 140, 16, 66,
	74, 21, 211, 47, 80, 242, 154, 27, 205, 128, 161, 89, 77, 36,
	95, 110, 85, 48, 212, 140, 211, 249, 22, 79, 200, 50, 28, 188,
	52, 140, 202, 120, 68, 145, 62, 70, 184, 190, 91, 197, 152, 224,
	149, 104, 25, 178, 252, 182, 202, 182, 141, 197, 4, 81, 181, 242,
	145, 42, 39, 227, 156, 198, 225, 193, 219, 93, 122, 175, 249, 0,
	175, 143, 70, 239, 46, 246, 163, 53, 163, 109, 168, 135, 2, 235,
	25, 92, 20, 145, 138, 77, 69, 166, 78, 176, 173, 212, 166, 113,
	94, 161, 41, 50, 239, 49, 111, 164, 70, 60, 2, 37, 171, 75,
	136, 156, 11, 56, 42, 146, 138, 229, 73, 146, 77, 61, 98, 196,
	135, 106, 63, 197, 195, 86, 96, 203, 113, 101, 170, 247, 181, 113,
	80, 250, 108, 7, 255, 237, 129, 226, 79, 107, 112, 166, 103, 241,
	24, 223, 239, 120, 198, 58, 60, 82, 128, 3, 184, 66, 143, 224,
	145, 224, 81, 206, 163, 45, 63, 90, 168, 114, 59, 33, 159, 95,
	28, 139, 123, 98, 125, 196, 15, 70, 194, 253, 54, 14, 109, 226,
	71, 17, 161, 93, 186, 87, 244, 138, 20, 52, 123, 251, 26, 36,
	17, 46, 52, 231, 232, 76, 31, 221, 84, 37, 216, 165, 212, 106,
	197, 242, 98, 43, 39, 175, 254, 145, 190, 84, 118, 222, 187, 136,
	120, 163, 236, 249,
]
const baseRndArray: PackedInt32Array = [1, 1, 2, 3, 5, 8, 13, 21, 54, 75, 129, 204, 323, 527, 850, 1377, 2227]

const colors: Array = [
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 3],
	[0, 0, 0, 0, 0, 0, 0, 0, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 3],
	[0, 1, 2, 3, 4, 5, 6, 7, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 3],
]

# ------------------------------------------------------------------ wiring

var vm: DosMachine
var data: VortData
## Where the control panel, scores and saved games are written (never the game folder).
var save_dir: String = ""
## The DOS clock the random generators are seeded from: [hour, minute, second, hundredths].
var dos_time: PackedInt32Array = [0, 0, 0, 0]
## The BIOS tick count the program finds when it reads the DOS clock at start
## (InitRndT/InitRnd seed from it). The oracle sets DOSBox's clock to
## midnight before the game runs, so this is the same every run of a game;
## fitted per game. -1 keeps `dos_time` as given.
var dos_ticks: int = -1


## DOSBox's INT 21h AH=2Ch: the BIOS ticks as hours, minutes, seconds, hundredths.
func _dos_clock() -> PackedInt32Array:
	if dos_ticks < 0:
		return dos_time
	var t: int = int(100.0 / (float(DosMachine.PIT_HZ) / 65536.0) * float(dos_ticks))
	var hh: int = t % 100
	t /= 100
	var s: int = t % 60
	t /= 60
	var m: int = t % 60
	t /= 60
	return PackedInt32Array([t % 24, m, s, hh])
## Where the original spends processor time the port does not, named, in
## clock units; fitted against the oracle's recordings.
var costs: Dictionary = {}


func cost(name: String) -> void:
	vm.cpu_work(int(costs.get(name, 0)))


## Set by Quit (the original exits to DOS); every loop and wait ends.
var exited: bool = false
var exit_message: String = ""
## SCR-01V: the text screen the original leaves as it quits without an error (ENDSCRN's 80x25 character
## and attribute bytes, copied to B800:0000) and where it puts the cursor (column, row); empty otherwise.
## The screen cases compare it (simv01_boot writes it out); nothing in the game reads it.
var exit_textScreen: PackedByteArray = PackedByteArray()
var exit_cursor: Vector2i = Vector2i(0, 0)
## The episode's names: pictures, sprites and sounds by the original's enum
## names (GRAPHCKn.H, SNDSCKn.H), set by the episode class.
var episode: int = 1
var P: Dictionary = {}
var S: Dictionary = {}
var SND: Dictionary = {}

# ---------------------------------------------------------------- IDLIBC.C

var playermode: PackedInt32Array = [0, 0, 0]
var JoyXlow: PackedInt32Array = [0, 0, 0]
var JoyXhigh: PackedInt32Array = [0, 0, 0]
var JoyYlow: PackedInt32Array = [0, 0, 0]
var JoyYhigh: PackedInt32Array = [0, 0, 0]
var MouseSensitivity: int = 0
var key: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0]
var keyB1: int = 0
var keyB2: int = 0
var demobuffer: PackedByteArray = PackedByteArray()
var demoptr: int = 0
var indemo: int = notdemo

var videocard: int = VGAcard
var win_xl: int = 0
var win_yl: int = 0
var win_xh: int = 0
var win_yh: int = 0
var sx: int = 0
var sy: int = 0
var leftedge: int = 0
var screencenterx: int = 19
var screencentery: int = 11
var score: int = 0
var level: int = 0

var spritetable: Array = []     # 4 entries per sprite: {w, h, shape, xl, yl, xh, yh}
var pictable: Array = []        # {w, h, shape}
var image: Dictionary = {}
var numchars: int = 0
var numtiles: int = 0
var numpics: int = 0
var numsprites: int = 0
var charptr: int = 0            # absolute addresses in the card's memory
var tileptr: int = 0
var picptr: int = 0
var egasprites: PackedByteArray = PackedByteArray()   # five planes of sprite data (four colours, then the mask), spriteplanesize each
var spriteplanesize: int = 0

# --------------------------------------------------------------- IDASM.ASM

var drawseg: int = 0            # segments, as the original keeps them
var screenseg: int = 0
var screenofs: int = 0
var screenpan: int = 0
var screenstart: int = 0
var EGApage: int = 0
var animtable: int = 0          # which of the four tile animation tables
var tile_anim: PackedInt32Array = PackedInt32Array()   # four tables of MAXTILES: tile -> byte offset of its image
var ylookup: PackedInt32Array = PackedInt32Array()

var keydown: PackedByteArray = PackedByteArray()
## CTRL-02: the player's keys and pad buttons (ControlsModel.table(): action -> scan codes), read by
## ControlPlayer and the status key in place of the control panel's keys; empty (the tests, the
## recordings) the original's. Fire (with shell_one_fire) holds both buttons, the original's fire.
var shell_controls: Dictionary = {}
## AUDIO-06: called with each sound the speaker starts (after its priority won), for the host's Keen 4-6
## effects; nothing in the game reads it.
var shell_sound_hook: Callable = Callable()
var shell_one_fire: bool = false
## The refresh the play controls were last read on: the host's pad is the controls while they are being
## read, the menus' arrows, Enter and Escape otherwise.
var controls_read_vbl: int = -1000000
## CTRL-03..05: a Controls page catching a key ("keys") or a button ("pad") for an action; the host puts
## the next one pressed in controls_captured (a Godot key or pad button; -1 Escape or Start: cancelled;
## -2 none yet) and the game never sees it.
var controls_capture: String = ""
var controls_captured: int = -2
## SCR-06: the seconds the capture's countdown shows (0 none; for the tests: nothing reads it).
var controls_capture_left: int = 0
## SCR-04/05: the question a player's list or name entry is waiting on ("" none; for the tests), and the
## row the list's caret is on (HARN-09's walker reads it; nothing in the game does).
var shell_asking: String = ""
var shell_asking_row: int = 0
## SCR-08: how many times the map or a level was loaded, and the "Keens Left" window shown (for HARN-09's
## mash walk: a confirm mashed must load a new game's map once, and skip no window; nothing reads them).
var shell_level_loads: int = 0
var shell_level_boxes: int = 0


func shell_held(action: String) -> bool:
	for c: int in shell_controls.get(action, PackedInt32Array()):
		if keydown[c] != 0:
			return true
	return false


## The player's controls through the shared bindings (CTRL-02).
func _shell_control() -> Dictionary:
	var xmove: int = (1 if shell_held("right") else 0) - (1 if shell_held("left") else 0)
	var ymove: int = (1 if shell_held("down") else 0) - (1 if shell_held("up") else 0)
	var fire: bool = shell_one_fire and shell_held("fire")
	return {"dir": _dir_of(xmove, ymove), "button1": shell_held("jump") or fire, "button2": shell_held("pogo") or fire}
var NBKscan: int = 0
var NBKascii: int = 0
var passtobios: bool = true

var timecount: int = 0          # fast timer tics since startup (a 32-bit value)
var SPKactive: int = 0
var soundmode: int = 1
var intcount: int = 0
var SndPtr: int = 0             # 0 = nothing; else (sound << 16) | position in its tone stream
var SndPriority: int = 0
var pausesndptr: int = 0
var pausepriority: int = 0
var pauseintcount: int = 0
var dontplay: int = 0

var rndindex: int = 0
var indexi: int = 0
var indexj: int = 0
var LastRnd: int = 0
var RndArray: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	demobuffer.resize(5002)
	keydown.resize(128)
	RndArray.resize(17)
	ylookup.resize(256)
	for y: int in range(256):
		ylookup[y] = y * SCREENWIDTH
	tile_anim.resize(4 * MAXTILES)
	oldtiles.resize(BIGPORTSIZE)
	oldtiles2.resize(BIGPORTSIZE)
	bigbuffer.resize(0x10000)


# ----------------------------------------------------------- state, hash

## Properties that are wiring or constant tables, not simulation state.
const NOT_STATE: PackedStringArray = ["vm", "data", "save_dir", "dos_time", "dos_ticks", "spawn_scan_per_tile", "level_tc_shift", "map_anim0", "teleport_anim0", "costs", "exit_message", "exit_textScreen", "exit_cursor", "episode", "P", "S", "SND", "classes"]


## Every variable of the program, by name, as plain values: the whole
## simulation state (A7), the machine's included.
func state_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or NOT_STATE.has(prop.name):
			continue
		out[prop.name] = _plain(get(prop.name))
	out["__machine"] = vm.snapshot()
	return out


static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			if v.has_method("to_dict"):
				return v.to_dict()
			return null
		TYPE_ARRAY:
			var a: Array = []
			for e: Variant in v:
				a.append(_plain(e))
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in v:
				d[k] = _plain(v[k])
			return d
		TYPE_STRING_NAME:
			return String(v)
	return v


## A digest of the state: the same program state gives the same hash.
func state_hash() -> String:
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(var_to_bytes(state_snapshot()))
	return h.finish().hex_encode().substr(0, 16)


## Puts a snapshot back. Objects in lists are rebuilt in place.
func state_restore(snap: Dictionary) -> void:
	for prop: Dictionary in get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or NOT_STATE.has(prop.name) or not snap.has(prop.name):
			continue
		var cur: Variant = get(prop.name)
		var val: Variant = snap[prop.name]
		if typeof(cur) == TYPE_OBJECT and cur != null and cur.has_method("from_dict"):
			cur.from_dict(val)
		elif typeof(cur) == TYPE_ARRAY and val is Array and cur.size() > 0 and typeof(cur[0]) == TYPE_OBJECT:
			for i: int in range(mini(cur.size(), val.size())):
				cur[i].from_dict(val[i])
		elif typeof(cur) == TYPE_STRING_NAME:
			set(prop.name, StringName(val))
		else:
			set(prop.name, val)
	vm.restore(snap["__machine"])


# ---------------------------------------------------------------- helpers

static func s16(v: int) -> int:
	v &= 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


static func u16(v: int) -> int:
	return v & 0xFFFF


## The card address of segment:offset in the EGA window (segment A000h = 0).
static func seg_addr(seg: int, off: int) -> int:
	return (((seg - 0xA000) << 4) + off) & 0xFFFF


# --------------------------------------------------- CalibrateJoy / Keys

func CalibrateJoy(joynum: int) -> void:
	var xy: PackedInt32Array
	var xl: int = 0
	var yl: int = 0
	var xh: int = 0
	var yh: int = 0
	ExpWin(28, 9)
	Print("  Joystick Configuration\n\r")
	Print("  ----------------------\n\r")
	Print("Hold the joystick in the\n\r")
	Print("upper left\n\r")
	Print("corner and press button 1:")
	var stage: int = 9
	var ctr: Dictionary
	while true:
		DrawChar(sx, sy * 8, stage)
		WaitVBL(3)
		stage += 1
		if stage == 12:
			stage = 9
		xy = ReadJoystick(joynum)
		xl = xy[0]
		yl = xy[1]
		ctr = ControlJoystick(joynum)
		if keydown[1] != 0 or exited:
			ClearKeys()
			return
		if ctr.button1:
			break
	DrawChar(sx, sy * 8, BLANKCHAR)
	while ControlJoystick(joynum).button1 and not exited:
		vm.poll()
	WaitVBL(2)
	Print("\n\n\rHold the joystick in the\n\r")
	Print("lower right\n\r")
	Print("corner and press button 1:")
	while true:
		DrawChar(sx, sy * 8, stage)
		WaitVBL(3)
		stage += 1
		if stage == 12:
			stage = 9
		xy = ReadJoystick(joynum)
		xh = xy[0]
		yh = xy[1]
		ctr = ControlJoystick(joynum)
		if keydown[1] != 0 or exited:
			ClearKeys()
			return
		if ctr.button1:
			break
	DrawChar(sx, sy * 8, BLANKCHAR)
	while ControlJoystick(joynum).button1 and not exited:
		vm.poll()
	@warning_ignore("integer_division")
	var dx: int = (xh - xl) / 4
	@warning_ignore("integer_division")
	var dy: int = (yh - yl) / 4
	JoyXlow[joynum] = xl + dx
	JoyXhigh[joynum] = xh - dx
	JoyYlow[joynum] = yl + dy
	JoyYhigh[joynum] = yh - dy
	playermode[1] = joystick1
	ClearKeys()


const chartable: String = "??1234567890-+??QWERTYUIOP[]|?ASDFGHJKL;\"???ZXCVBNM,./??????????????????\u000f?-\u00155\u0011+?\u0013"


func printscan(sc: int) -> void:
	sc &= 0x7F
	if sc == 1:
		Print("ESC")
	elif sc == 0xE:
		Print("BKSP")
	elif sc == 0xF:
		Print("TAB")
	elif sc == 0x1D:
		Print("CTRL")
	elif sc == 0x2A:
		Print("LSHIFT")
	elif sc == 0x39:
		Print("SPACE")
	elif sc == 0x3A:
		Print("CAPSLK")
	elif sc >= 0x3B and sc <= 0x44:
		Print("F")
		Print(str(sc - 0x3A))
	elif sc == 0x57:
		Print("F11")
	elif sc == 0x59:
		Print("F12")
	elif sc == 0x46:
		Print("SCRLLK")
	elif sc == 0x1C:
		Print("ENTER")
	elif sc == 0x36:
		Print("RSHIFT")
	elif sc == 0x37:
		Print("PRTSC")
	elif sc == 0x38:
		Print("ALT")
	elif sc == 0x47:
		Print("HOME")
	elif sc == 0x49:
		Print("PGUP")
	elif sc == 0x4F:
		Print("END")
	elif sc == 0x51:
		Print("PGDN")
	elif sc == 0x52:
		Print("INS")
	elif sc == 0x53:
		Print("DEL")
	elif sc == 0x45:
		Print("NUMLK")
	else:
		var c: int = chartable.unicode_at(sc) if sc < chartable.length() else 63
		DrawChar(sx, sy * 8, c)
		sx += 1


func CalibrateKeys() -> void:
	ExpWin(22, 14)
	Print("Keyboard Commands\n")
	Print("-----------------")
	Print("\n0 north    :")
	Print("\n1 northeast:")
	Print("\n2 east     :")
	Print("\n3 southeast:")
	Print("\n4 south    :")
	Print("\n5 southwest:")
	Print("\n6 west     :")
	Print("\n7 northwest:")
	Print("\n8 button1  :")
	Print("\n9 button2  :")
	Print("\nModify which action:")
	var hx: int = sx
	var hy: int = sy
	for i: int in range(8):
		sx = 26
		sy = i + 7
		printscan(key[i])
	sx = 26
	sy = 15
	printscan(keyB1)
	sx = 26
	sy = 16
	printscan(keyB2)
	while true:
		sx = hx
		sy = hy
		var c: int = Get() % 256
		if exited:
			break
		if c < 48 or c > 57:
			# the C's `continue` in a do-while goes to its test, `while (ch >= '0' && ch <= '9')`: any key but a
			# digit leaves the window (a `continue` in this `while true` looped for ever: the window could not be left)
			break
		var select: int = c - 48
		DrawChar(sx, sy * 8, c)
		Print("\n\rPress the new key:")
		ClearKeys()
		var new: int = -1
		while true:
			new += 1
			if keydown[new] != 0 or exited:
				break
			if new == 0x79:
				new = -1
				vm.poll()
			elif new == 0x29:
				new += 1    # skip STUPID left shifts!
		ClearKeys()
		Print("\r                  ")
		if select < 8:
			key[select] = new
		if select == 8:
			keyB1 = new
		if select == 9:
			keyB2 = new
		sy = select + 7
		sx = 26
		Print("        ")
		sx = 26
		printscan(new)
	playermode[1] = keyboard


# ---------------------------------------------------------------- controls

static func _dir_of(xmove: int, ymove: int) -> int:
	match ymove * 3 + xmove:
		-4: return northwest
		-3: return north
		-2: return northeast
		-1: return west
		1: return east
		2: return southwest
		3: return south
		4: return southeast
	return nodir


func ControlKBD() -> Dictionary:
	var xmove: int = 0
	var ymove: int = 0
	if keydown[key[north]]:
		ymove = -1
	if keydown[key[east]]:
		xmove = 1
	if keydown[key[south]]:
		ymove = 1
	if keydown[key[west]]:
		xmove = -1
	if keydown[key[northeast]]:
		ymove = -1
		xmove = 1
	if keydown[key[northwest]]:
		ymove = -1
		xmove = -1
	if keydown[key[southeast]]:
		ymove = 1
		xmove = 1
	if keydown[key[southwest]]:
		ymove = 1
		xmove = -1
	return {"dir": _dir_of(xmove, ymove), "button1": keydown[keyB1] != 0, "button2": keydown[keyB2] != 0}


## No mouse driver: the interrupt returns nothing useful.
func ControlMouse() -> Dictionary:
	return {"dir": nodir, "button1": false, "button2": false}


## The resistance count of the joystick: [x, y]. With none connected the
## bits never fall, so both counts run to 500.
func ReadJoystick(joynum: int) -> PackedInt32Array:
	var xbit: int = 1 if joynum == 1 else 4
	var ybit: int = 2 if joynum == 1 else 8
	var xcount: int = 0
	var ycount: int = 0
	vm.out8(0x201, vm.in8(0x201))
	while true:
		var portval: int = vm.in8(0x201)
		var a1: int = 1 if (portval & xbit) != 0 else 0
		var a2: int = 1 if (portval & ybit) != 0 else 0
		xcount += a1
		ycount += a2
		if not ((a1 + a2 != 0) and xcount < 500 and ycount < 500):
			break
	return PackedInt32Array([xcount, ycount])


func ControlJoystick(joynum: int) -> Dictionary:
	var xy: PackedInt32Array = ReadJoystick(joynum)
	var joyx: int = xy[0]
	var joyy: int = xy[1]
	var xmove: int = 0
	var ymove: int = 0
	if joyx > 500 or joyy > 500:
		joyx = JoyXlow[joynum] + 1
		joyy = JoyYlow[joynum] + 1
	if joyx > JoyXhigh[joynum]:
		xmove = 1
	elif joyx < JoyXlow[joynum]:
		xmove = -1
	if joyy > JoyYhigh[joynum]:
		ymove = 1
	elif joyy < JoyYlow[joynum]:
		ymove = -1
	var buttons: int = vm.in8(0x201)
	var b1: bool
	var b2: bool
	if joynum == 1:
		b1 = (buttons & 0x10) == 0
		b2 = (buttons & 0x20) == 0
	else:
		b1 = (buttons & 0x40) == 0
		b2 = (buttons & 0x80) == 0
	return {"dir": _dir_of(xmove, ymove), "button1": b1, "button2": b2}


func ControlPlayer(player: int) -> Dictionary:
	var ret: Dictionary = {"dir": nodir, "button1": false, "button2": false}
	if indemo == notdemo or indemo == recording:
		controls_read_vbl = vm.vbl_count
		if not shell_controls.is_empty():
			ret = _shell_control()
		else:
			match playermode[player]:
				keyboard: ret = ControlKBD()
				mouse: ret = ControlMouse()
				joystick1: ret = ControlJoystick(1)
				joystick2: ret = ControlJoystick(2)
		if indemo == recording:
			var val: int = (ret.dir << 2) | ((1 if ret.button2 else 0) << 1) | (1 if ret.button1 else 0)
			if demoptr < demobuffer.size():
				demobuffer[demoptr] = val
			demoptr += 1
	else:
		var val: int = demobuffer[demoptr] if demoptr < demobuffer.size() else 0
		demoptr += 1
		ret.button1 = (val & 1) != 0
		ret.button2 = (val & 2) != 0
		ret.dir = (val & (4 + 8 + 16 + 32)) >> 2
	return ret


func RecordDemo() -> void:
	demobuffer[0] = level & 0xFF
	demoptr = 1
	indemo = recording


# ------------------------------------------------------- misc library

func ClearKeys() -> void:
	if trace_frames:
		var st: Array = get_stack()
		print("TRACE clearkeys t=%.6f from %s < %s" % [float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT), st[1].function if st.size() > 1 else "?", st[2].function if st.size() > 2 else "?"])
	NBKscan = 0
	NBKascii = 0
	keydown.fill(0)


## The original's INT 9 handler for v1.31: keydown[] and the pending NBKscan.
func Int9ISR() -> void:
	var al: int = vm.port60
	if trace_frames:
		print("TRACE key t=%.6f code=%d" % [float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT), al])
	if (al & 0x80) != 0:
		keydown[al & 0x7F] = 0
	else:
		NBKscan = (NBKscan & 0xFF00) | al | 0x80
		keydown[al] = 1


## v1.31's NoBiosKey: with parm 0 wait for a key and return scan<<8 | ascii;
## with parm 1 report the pending key (0 if none) without taking it.
func NoBiosKey(parm: int) -> int:
	if parm == 0:
		while true:
			var bl: int = NBKscan & 0xFF
			if (bl & 0x80) == 0:
				if exited:
					return 0
				vm.poll()
				continue
			bl &= 0x7F
			NBKscan = (NBKscan & 0xFF00) | bl
			var al: int = scanascii[bl]
			if al == 0:
				continue
			NBKascii = (NBKascii & 0xFF00) | al
			if trace_frames:
				var st2: Array = get_stack()
				print("TRACE nobioskey t=%.6f scan=%d for %s" % [float(vm.now) / float(DosMachine.PIT_HZ * DosMachine.UNIT), bl, st2[1].function if st2.size() > 1 else "?"])
			return (bl << 8) | al
		return 0
	var bl: int = NBKscan & 0xFF
	if (bl & 0x80) == 0:
		return 0
	bl &= 0x7F
	var al: int = scanascii[bl]
	NBKascii = (NBKascii & 0xFF00) | al
	if al == 0:
		return 0
	return (bl << 8) | al


# ------------------------------------------------------------- graphics

## A latch copy of one byte through the card, the way REP MOVSB from the
## card's own memory to the card does it (write mode 1 is already set).
func _latch(src: int, dst: int) -> void:
	vm.card.mem_read(src)
	vm.card.mem_write(dst, 0)


func EGASplitScreen(linenum: int) -> void:
	WaitVBL(1)
	if videocard == VGAcard:
		linenum *= 2
	vm.out8(CRTC_INDEX, CRTC_LINECOMPARE)
	vm.out8(CRTC_INDEX + 1, linenum % 256)
	vm.out8(CRTC_INDEX, CRTC_OVERFLOW)
	@warning_ignore("integer_division")
	vm.out8(CRTC_INDEX + 1, 1 + 16 * (linenum / 256))
	if videocard == VGAcard:
		vm.out8(CRTC_INDEX, CRTC_MAXSCANLINE)
		vm.out8(CRTC_INDEX + 1, vm.in8(CRTC_INDEX + 1) & (255 - 64))


func CRTCstart(start: int) -> void:
	WaitVBL(1)
	vm.out8(CRTC_INDEX, CRTC_STARTLOW)
	vm.out8(CRTC_INDEX + 1, start & 0xFF)
	vm.out8(CRTC_INDEX, CRTC_STARTHIGH)
	vm.out8(CRTC_INDEX + 1, start >> 8)


## DrawChar: xcoord in bytes, ycoord in pixels; an 8x8 character through the latches.
func DrawChar(xcoord: int, ycoord: int, charnum: int) -> void:
	vm.instructions(50)    # IDASM's DrawChar: 8 rows of movsb/add, set-up and the call
	if draw_capture:
		draw_overlaid = [true, true]    # a window or text on a page: the draw list doesn't hold it
		# where on the picture: DrawChar's page base is the start address floored to a paragraph, the
		# picture starts at the start itself, panned (Megarocket 1.0's lesson)
		var r: Rect2i = Rect2i((xcoord - (screenstart & 15)) * 8 - screenpan, ycoord, 8, 8)
		for p: int in range(2):
			draw_overlay_rect[p] = r if draw_overlay_rect[p].size == Vector2i.ZERO else draw_overlay_rect[p].merge(r)
	var es: int = seg_addr(screenseg, 0)
	var di: int = (xcoord + ylookup[ycoord]) & 0xFFFF
	vm.out16(GC_INDEX, GC_MODE | (1 << 8))
	var si: int = charptr + charnum * 8
	for r: int in range(8):
		_latch(si, (es + di) & 0xFFFF)
		si += 1
		di += SCREENWIDTH


## DrawTile: a 16x16 tile through the latches, or, with the sign bit set, a
## masked tile merged plane by plane (the mask is the tile that follows it).
func DrawTile(xcoord: int, ycoord: int, tilenum: int) -> void:
	# IDASM's DrawTile: 16 rows of two movsb (about 84 with set-up), or the
	# masked path's four planes of 16 eleven-instruction rows
	vm.instructions(84 if (tilenum & 0x8000) == 0 else 782)
	var es: int = seg_addr(screenseg, 0)
	var di: int = (xcoord + ylookup[ycoord]) & 0xFFFF
	if (tilenum & 0x8000) == 0:     # the sign bit of the original's 16-bit number marks a masked tile
		var si: int = tileptr + tile_anim[animtable * MAXTILES + tilenum]
		vm.out16(SC_INDEX, SC_MAPMASK | (15 << 8))
		vm.out16(GC_INDEX, GC_MODE | (1 << 8))
		for r: int in range(16):
			_latch(si, (es + di) & 0xFFFF)
			_latch(si + 1, (es + di + 1) & 0xFFFF)
			si += 2
			di += SCREENWIDTH
		return
	var si: int = tileptr + ((tilenum & 0x7FFF) << 5)
	vm.out16(GC_INDEX, GC_MODE)
	for plane: int in range(4):
		vm.out16(GC_INDEX, GC_READMAP | (plane << 8))
		vm.out16(SC_INDEX, SC_MAPMASK | ((1 << plane) << 8))
		var s: int = si
		var d: int = di
		for r: int in range(16):
			for b: int in range(2):
				var screen: int = vm.card.mem_read((es + d + b) & 0xFFFF)
				var mask: int = vm.card.mem_read(s + 0x20 + b)
				var tile: int = vm.card.mem_read(s + b)
				vm.card.mem_write((es + d + b) & 0xFFFF, (screen & mask) | (tile & ~mask & 0xFF))
			s += 2
			d += SCREENWIDTH
	vm.out16(GC_INDEX, GC_MODE | (1 << 8))
	vm.out16(SC_INDEX, SC_MAPMASK | (15 << 8))


## DrawPic: xcoord in bytes, ycoord in pixels; a picture through the latches.
func DrawPic(xcoord: int, ycoord: int, picnum: int) -> void:
	var p: Dictionary = pictable[picnum]
	vm.instructions(40 + p.h * (7 + p.w))    # IDASM's DrawPic: per line six instructions and a rep movsb
	var es: int = seg_addr(screenseg, 0)
	vm.out8(SC_INDEX, SC_MAPMASK)
	vm.out8(SC_INDEX + 1, 15)
	vm.out8(GC_INDEX, GC_MODE)
	vm.out8(GC_INDEX + 1, 1)
	var si: int = picptr + p.shape
	var y: int = ycoord
	for row: int in range(p.h):
		var di: int = (ylookup[y] + xcoord) & 0xFFFF
		y += 1
		for b: int in range(p.w):
			_latch(si, (es + di) & 0xFFFF)
			si += 1
			di += 1


## DrawSprite: xcoord in bytes, ycoord in pixels; the sprite entry (already
## one of the four shifts) is merged into each plane under its mask.
func DrawSprite(xcoord: int, ycoord: int, spritenum: int) -> void:
	var e: Dictionary = spritetable[spritenum]
	# IDASM's DrawSprite: four planes of EGAone..EGAeight, each row four
	# instructions a word (or odd byte) and three for the loop
	@warning_ignore("integer_division")
	vm.instructions(45 + 4 * (19 + int(e.h) * (4 * ((int(e.w) + 1) / 2) + 3)))
	var blockdest: int = (xcoord + ylookup[ycoord]) & 0xFFFF
	var blockheight: int = e.h
	var blocksource: int = e.shape
	var width: int = e.w
	var es: int = seg_addr(screenseg, 0)
	var maskbase: int = 4 * spriteplanesize
	vm.out16(GC_INDEX, GC_MODE)
	for plane: int in range(4):
		vm.out16(GC_INDEX, GC_READMAP | (plane << 8))
		vm.out16(SC_INDEX, SC_MAPMASK | ((1 << plane) << 8))
		var pbase: int = plane * spriteplanesize
		var di: int = blockdest
		var si: int = blocksource
		for row: int in range(blockheight):
			for b: int in range(width):
				var a: int = (es + di) & 0xFFFF
				var v: int = (vm.card.mem_read(a) & egasprites[maskbase + si]) | egasprites[pbase + si]
				vm.card.mem_write(a, v)
				di += 1
				si += 1
			di += SCREENWIDTH - width
	vm.out16(GC_INDEX, GC_MODE | (1 << 8))
	vm.out16(SC_INDEX, SC_MAPMASK | (15 << 8))


# ---------------------------------------------------- refresh (IDASM)

# These belong to KEENMAIN.C but the assembly refreshes them directly.
var oldtiles: PackedInt32Array = PackedInt32Array()
var oldtiles2: PackedInt32Array = PackedInt32Array()
var spritelist: Array = []      # [x, y, num]
var tilelist: Array = []
var piclist: Array = []
var spritesshown: int = 0
var tilesshown: int = 0
var picsshown: int = 0
var uservect: StringName = &""
var originx: int = 0
var originy: int = 0
var mapbwide: int = 0
var mapwwide: int = 0
var mapwidthextra: int = 0
var mapheight: int = 0
var cyclespeed: int = 0
## The level's planes live in bigbuffer, as the original's do (A12).
var bigbuffer: PackedByteArray = PackedByteArray()
var mapplane: PackedInt32Array = [0, 0, 0, 0]


func GETTILE(x: int, y: int, plane: int) -> int:
	var o: int = (mapplane[plane] + ((y * mapwwide + x) * 2)) & 0xFFFF
	return bigbuffer[o] | (bigbuffer[(o + 1) & 0xFFFF] << 8)


func SETTILE(x: int, y: int, plane: int, value: int) -> void:
	var o: int = (mapplane[plane] + ((y * mapwwide + x) * 2)) & 0xFFFF
	bigbuffer[o] = value & 0xFF
	bigbuffer[(o + 1) & 0xFFFF] = (value >> 8) & 0xFF


func RF_ForceRefresh() -> void:
	for i: int in range(PORTTILECOUNT):
		oldtiles[i] = -1
		oldtiles2[i] = -1
	draw_forced = [true, true]


func VidInitDraw() -> void:
	screenstart = 4
	if (originx & 0x800) != 0:
		screenstart += 1
	screenpan = (originx >> 8) & 7
	EGApage ^= 1
	var cx: int
	if (EGApage & 1) != 0:
		cx = 0xA300
		screenstart += 0x3000
	else:
		cx = 0xA000
	drawseg = cx
	screenstart += ((originy >> 8) & 15) * SCREENWIDTH + SCREENWIDTH * 32
	screenseg = 0xA000 + (screenstart >> 4)


func _draw_page(page1: bool) -> void:
	var es: int = seg_addr(drawseg, 0)
	var abase: int = animtable * MAXTILES
	var bx: int = (mapplane[0] + ((((originy >> 8) & 0xFFFF) >> 4) * mapbwide) + ((((originx >> 8) & 0xFFFF) >> 4) << 1)) & 0xFFFF
	var tileoff: int = 0
	var drawoff: int = 0
	var drawn: int = 0
	for ty: int in range(PORTTILESHIGH):
		for tx: int in range(PORTTILESWIDE):
			var o: int = (bx + tileoff) & 0xFFFF
			var tile: int = bigbuffer[o] | (bigbuffer[(o + 1) & 0xFFFF] << 8)
			var si: int = tile_anim[abase + tile] if tile < MAXTILES else 0
			var idx: int = tileoff >> 1
			var same: bool = (oldtiles[idx] == si) if page1 else (oldtiles2[idx] == si)
			if not same:
				if page1:
					oldtiles[idx] = si
				else:
					oldtiles2[idx] = si
				drawn += 1
				# DrawTile16
				var s: int = tileptr + si
				var di: int = (es + 0x604 + drawoff) & 0xFFFF
				for r: int in range(16):
					_latch(s, di)
					_latch(s + 1, (di + 1) & 0xFFFF)
					s += 2
					di = (di + SCREENWIDTH) & 0xFFFF
			tileoff += 2
			drawoff += 2
		bx += mapwidthextra
		drawoff += 16 * SCREENWIDTH - 2 * PORTTILESWIDE
	# the unwound DrawPage: five instructions to look at a tile, three more
	# and DrawTile16's 53 to copy one, one per row, two to set up and return
	vm.instructions(PORTTILESWIDE * PORTTILESHIGH * 5 + drawn * 56 + PORTTILESHIGH + 3)
	if draw_capture and drawn == PORTTILESWIDE * PORTTILESHIGH:
		draw_overlaid[1 if page1 else 0] = false    # every tile painted again: nothing else is left on it
		draw_overlay_rect[1 if page1 else 0] = Rect2i()
		draw_user_left[1 if page1 else 0] = &""


## Tests only: print each refresh's start and start-address write time (the
## lead analysis of A17); set by the runner.
var trace_frames: bool = false


func VidRefresh() -> void:
	if trace_frames:
		var unit: float = DosMachine.PIT_HZ * DosMachine.UNIT
		print("TRACE start t=%.6f last_vbl=%.6f" % [vm.now / unit, vm.last_vbl / unit])
	VidInitDraw()
	vm.out16(GC_INDEX, GC_MODE | (1 << 8))
	screenofs = 0
	animtable = ((u16(timecount) >> cyclespeed) & 6) >> 1
	if draw_capture:
		_capture_draw_list()
	_draw_page(EGApage != 0)
	var saved: int = screenseg
	screenseg = drawseg
	for i: int in range(spritesshown):
		var s: Array = spritelist[i]
		DrawSprite(s[0], s[1], s[2])
	for i: int in range(tilesshown):
		var t: Array = tilelist[i]
		DrawTile(t[0], t[1], t[2])
	for i: int in range(picsshown):
		var p: Array = piclist[i]
		DrawPic(p[0], p[1], p[2])
	screenseg = saved
	if uservect != &"":
		call(uservect)
	if draw_capture:
		_user_left()
	if trace_frames:
		var unit: float = DosMachine.PIT_HZ * DosMachine.UNIT
		print("TRACE refresh t=%.6f timecount=%d next_tick=%.6f next_vbl=%.6f vbl=%d" % [vm.now / unit, timecount, vm.next_tick / unit, vm.next_vbl / unit, vm.vbl_count])
	# set CRTC start, wait for the end of a retrace, set it again, wait for
	# the next retrace, then the panning
	_set_crtc_start()
	if draw_capture:
		draw_list["written_vbl"] = vm.vbl_count
	vm.wait_retrace_end()
	_set_crtc_start()
	vm.wait_retrace_start()
	vm.in8(STATUS_REGISTER_1)
	vm.out8(ATR_INDEX, ATR_PELPAN | 0x20)
	vm.out8(ATR_INDEX, screenpan & 0xFF)


## REND-01: the refresh's draw list, kept for a renderer when draw_capture is on (the shell and the
## tests set it; the simulation never reads it): the origin, the animation table, the visible map
## tiles, the sprites, tiles and pictures placed, the start address and panning the picture is shown
## with, and the retrace count when the start was written (the picture is shown from the next
## retrace on). The previous refresh's list is kept too: until this one's start is taken, the card
## still shows that one.
var draw_capture: bool = false
var draw_list: Dictionary = {}
var draw_list_prev: Dictionary = {}
## The sprites placed this refresh, [x, y, shape, owner, on the page, gen] in world units (RF_PlaceSprite's
## own arguments, who placed it: an object's slot, or a number of the caller's, -1 for none; whether
## the original's page took it, which the wide view's extra sprites don't; and the slot's draw_gen).
var sprite_world: Array = []
## REND-04: the wide view's extra tiles each side of the original's 20 (the host sets it from the
## window's shape; 0 in Classic, headless and the oracle runs: the original exactly). Read where
## creatures wake and are retired (LevelLoop, RemoveInactive: J-30, they follow the wide view's edges),
## and by the draw list (a wider grid, sprites past the page kept).
var wide_tiles: int = 0

## REND-03: set around a placement by its caller, so smooth motion can follow one thing from refresh
## to refresh. The level's objects are their slots; the others are named here.
var draw_owner: int = -1
## REND-03: a number per object slot, raised each time FindFreeObj hands the slot out, so smooth motion
## never slides a new object from the place of the one whose slot it took. Presentation only.
var draw_gen: PackedInt32Array = PackedInt32Array()
const OWNER_MESSIE: int = 1000
const OWNER_HALO: int = 1001
## Per page: something drawn on it outside the lists (DrawChar's windows and text) and not yet
## painted over; and a forced refresh pending for it, which paints every tile again and so clears it.
var draw_overlaid: Array = [false, false]
## And where, on the picture (the union of what was printed; empty with nothing): the shell draws that
## part of the card's picture over the list's (popups over the wide view, no 4:3 flip)
var draw_overlay_rect: Array = [Rect2i(), Rect2i()]
## The game's play is on the screen (a level, the world map): the only pictures native resolution,
## smooth motion and the wide view draw (the intro, title, high scores and endings are maps too, but
## screens: they keep the original picture, framed)
var shell_on_map: bool = false
var draw_forced: Array = [false, false]
## Per page: the user routine that drew on it in an earlier refresh (the title's pictures, the id screen's,
## the high scores'), its drawing still there until every tile is painted again: the refreshes after it
## (uservect cleared, only the tiles that changed drawn) show it, which their lists don't hold.
var draw_user_left: Array = [&"", &""]


func _capture_draw_list() -> void:
	# the visible grid with a tile all round (REND-03 scrolls a little between refreshes), and the wide
	# view's tiles each side (REND-04)
	var ox0: int = (originx >> 12) - 1 - wide_tiles
	var oy0: int = (originy >> 12) - 1
	var gw: int = PORTTILESWIDE + 2 + 2 * wide_tiles
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(gw * (PORTTILESHIGH + 2))
	for ty: int in range(PORTTILESHIGH + 2):
		for tx: int in range(gw):
			grid[ty * gw + tx] = GETTILE(ox0 + tx, oy0 + ty, 0)
	var page: int = 1 if EGApage != 0 else 0
	if draw_forced[page]:
		draw_forced[page] = false
		draw_overlaid[page] = false
		draw_overlay_rect[page] = Rect2i()
	draw_list_prev = draw_list
	draw_list = {"page": page, "t": vm.seconds(), "wide": wide_tiles, "map_w": mapwwide,
		"play": bool(get("shell_in_level")) or shell_on_map,
		"xmin": int(get("originxmin")) >> 8, "xmax": (int(get("originxmax")) >> 8) + 320,    # the camera's reach, pixels
		"originx": originx, "originy": originy, "animtable": animtable, "grid": grid,
		"sprites": spritelist.slice(0, spritesshown), "world": sprite_world.duplicate(),    # all placed (the wide view keeps more than the page)
		"tiles": tilelist.slice(0, tilesshown),
		"pics": piclist.slice(0, picsshown), "user": uservect,
		"start": screenstart & 0xFFFF, "pan": screenpan, "written_vbl": -1,
		"level": level, "reveal": bool(get("cheat_revealSecrets"))}    # the Reveal secrets cheat (the view's alone)


## REND-01R: a page a user routine drew on keeps that drawing (the next refreshes draw only the tiles
## that change) until every tile is painted again; the list of a refresh drawn over it names the routine
## as its own, so it is shown as the card's picture, not drawn from the list.
func _user_left() -> void:
	var page: int = 1 if EGApage != 0 else 0
	if uservect != &"":
		draw_user_left[page] = uservect
	elif draw_user_left[page] != &"" and str(draw_list.get("user", "")) == "":
		draw_list["user"] = String(draw_user_left[page]) + " (left on the page)"


func _set_crtc_start() -> void:
	vm.out8(CRTC_INDEX, CRTC_STARTHIGH)
	vm.out8(CRTC_INDEX + 1, (screenstart >> 8) & 0xFF)
	vm.out8(CRTC_INDEX, CRTC_STARTLOW)
	vm.out8(CRTC_INDEX + 1, screenstart & 0xFF)


# ---------------------------------------------------------- windows, text

func DrawWindow(xl: int, yl: int, xh: int, yh: int) -> void:
	win_xl = xl
	win_yl = yl
	win_xh = xh
	win_yh = yh
	DrawChar(xl, yl * 8, 1)
	for x: int in range(xl + 1, xh):
		DrawChar(x, yl * 8, 2)
	DrawChar(xh, yl * 8, 3)
	for y: int in range(yl + 1, yh):
		DrawChar(xl, y * 8, 4)
		for x: int in range(xl + 1, xh):
			DrawChar(x, y * 8, BLANKCHAR)
		DrawChar(xh, y * 8, 5)
	DrawChar(xl, yh * 8, 6)
	for x: int in range(xl + 1, xh):
		DrawChar(x, yh * 8, 7)
	DrawChar(xh, yh * 8, 8)
	leftedge = xl + 1
	sx = leftedge
	sy = yl + 1


func CenterWindow(width: int, height: int) -> void:
	@warning_ignore("integer_division")
	var xl: int = screencenterx - width / 2
	@warning_ignore("integer_division")
	var yl: int = screencentery - height / 2
	DrawWindow(xl, yl, xl + width + 1, yl + height + 1)


func CharBar(xl: int, yl: int, xh: int, yh: int, c: int) -> void:
	for y: int in range(yl, yh + 1):
		for x: int in range(xl, xh + 1):
			DrawChar(x, y * 8, c)


func ExpWin(width: int, height: int) -> void:
	if width > 2:
		if height > 2:
			ExpWin(width - 2, height - 2)
		else:
			ExpWinH(width - 2, height)
	elif height > 2:
		ExpWinV(width, height - 2)
	WaitVBL(1)
	CenterWindow(width, height)


func ExpWinH(width: int, height: int) -> void:
	if width > 2:
		ExpWinH(width - 2, height)
	WaitVBL(1)
	CenterWindow(width, height)


func ExpWinV(width: int, height: int) -> void:
	if height > 2:
		ExpWinV(width, height - 2)
	WaitVBL(1)
	CenterWindow(width, height)


func DrawFrame(x1: int, y1: int, x2: int, y2: int, type: int) -> void:
	type = type * 22 + 1
	for x: int in range(x1 + 1, x2):
		DrawChar(x, y1 * 8, type + 1)
		DrawChar(x, y2 * 8, type + 6)
	for y: int in range(y1 + 1, y2):
		DrawChar(x1, y * 8, type + 3)
		DrawChar(x2, y * 8, type + 4)
	DrawChar(x1, y1 * 8, type)
	DrawChar(x2, y1 * 8, type + 2)
	DrawChar(x2, y2 * 8, type + 7)
	DrawChar(x1, y2 * 8, type + 5)


## Flash a cursor at sx,sy and wait for a key.
func Get() -> int:
	var k: int = 0
	while true:
		var cycle: int = 9
		while true:
			k = NoBiosKey(1) & 0xFF
			if k != 0 or cycle >= 13 or exited:
				break
			DrawChar(sx, sy * 8, cycle)
			cycle += 1
			WaitVBL(5)
		if k != 0 or exited:
			break
	DrawChar(sx, sy * 8, 32)
	return NoBiosKey(0)


func Print(text: String) -> void:
	for i: int in range(text.length()):
		var c: int = text.unicode_at(i)
		if c == 10:
			sy += 1
			sx = leftedge
		elif c == 13:
			sx = leftedge
		else:
			DrawChar(sx, sy * 8, c & 0xFF)
			sx += 1


## The later half of the font: red text on grey.
func PrintGrey(text: String) -> void:
	for i: int in range(text.length()):
		var c: int = text.unicode_at(i)
		if c == 10:
			sy += 1
			sx = leftedge
		elif c == 13:
			sx = leftedge
		else:
			DrawChar(sx, sy * 8, (c + 0x80) & 0xFF)
			sx += 1


func PrintInt(val: int) -> void:
	Print(str(val))


func PrintLong(val: int) -> void:
	Print(str(val))


func PrintC(text: String) -> void:
	@warning_ignore("integer_division")
	sx = 1 + screencenterx - text.length() / 2
	Print(text)


## A line of text typed at the cursor; 1 on Enter, 0 on Escape.
func Input(max_len: int) -> Array:
	if get(&"options") != null:
		return _shell_input(max_len)    # SCR-05: with a player at the controls, by the d-pad too
	var out: PackedByteArray = PackedByteArray()
	var k: int = 0
	while true:
		k = Get() & 0xFF
		if exited:
			break
		if k >= 97 and k <= 122:
			k -= 32
		if (k == 127 or k == 8) and out.size() > 0:
			out.resize(out.size() - 1)
			DrawChar(sx, sy * 8, BLANKCHAR)
			sx -= 1
		if k >= 32 and k <= 122 and out.size() < max_len:
			out.append(k)
			DrawChar(sx, sy * 8, k)
			sx += 1
		if k == 27 or k == 13:
			break
	return [1 if k == 13 else 0, out.get_string_from_ascii()]


## SCR-05: the letters the d-pad turns through, in order.
const SHELL_LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .-!?"


## SCR-05: Input with a player at the controls: typing is the original's, and the arrows (the pad's d-pad
## and stick) spell too. Up and down turn the letter under the cursor through SHELL_LETTERS (from A up, or
## from the end down), shown greyed until it is kept; right keeps it and moves on (a space when none is
## shown); left drops the letter shown, else takes back the last one as Backspace does; Enter (the pad's A)
## keeps the letter shown and ends; Escape (B) ends as the original's Escape, with what was kept.
func _shell_input(max_len: int) -> Array:
	var out: PackedByteArray = PackedByteArray()
	var n: int = SHELL_LETTERS.length()
	var pick: int = -1    # the letter shown at the cursor, not kept yet (SHELL_LETTERS' index), -1 none
	var k: int = 0
	shell_asking = "name"
	while true:
		var got: int = _shell_get(SHELL_LETTERS.unicode_at(pick) if pick >= 0 else -1)
		k = got & 0xFF
		if exited:
			break
		var scan: int = (got >> 8) & 0x7F
		if k == 1 and (scan == KEY_UP or scan == KEY_DOWN):
			if out.size() < max_len:
				if scan == KEY_UP:
					pick = (pick + 1) % n
				else:
					pick = n - 1 if pick < 0 else (pick + n - 1) % n
			continue
		if k == 1 and scan == KEY_RIGHT:
			if out.size() < max_len:
				var c: int = SHELL_LETTERS.unicode_at(pick) if pick >= 0 else 32
				out.append(c)
				DrawChar(sx, sy * 8, c)
				sx += 1
			pick = -1
			continue
		if k == 1 and scan == KEY_LEFT:
			if pick >= 0:
				pick = -1
				continue
			k = 8    # as Backspace
		if k == 13 and pick >= 0 and out.size() < max_len:
			out.append(SHELL_LETTERS.unicode_at(pick))
			DrawChar(sx, sy * 8, out[out.size() - 1])
			sx += 1
		pick = -1
		# the original's from here
		if k >= 97 and k <= 122:
			k -= 32
		if (k == 127 or k == 8) and out.size() > 0:
			out.resize(out.size() - 1)
			DrawChar(sx, sy * 8, BLANKCHAR)
			sx -= 1
		if k >= 32 and k <= 122 and out.size() < max_len:
			out.append(k)
			DrawChar(sx, sy * 8, k)
			sx += 1
		if k == 27 or k == 13:
			break
	shell_asking = ""
	return [1 if k == 13 else 0, out.get_string_from_ascii()]


## SCR-05: Get for _shell_input: with a letter shown (`shown` >= 0) it stands at the cursor greyed (the
## font's later half) in place of the flashing cursor; then the same wait and the key taken.
func _shell_get(shown: int) -> int:
	if shown < 0:
		return Get()
	DrawChar(sx, sy * 8, (shown + 0x80) & 0xFF)
	while NoBiosKey(1) == 0 and not exited:
		WaitVBL(1)
	DrawChar(sx, sy * 8, 32)
	return NoBiosKey(0)


# --------------------------------------------------------------- control file

func LoadCtrls() -> void:
	var path: String = save_dir.path_join("CTLPANEL." + data.ext)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if save_dir != "" else PackedByteArray()
	if bytes.size() < 44:
		soundmode = 1
		playermode[1] = keyboard
		playermode[2] = joystick1
		for i: int in [1, 2]:
			JoyXlow[i] = 20
			JoyXhigh[i] = 60
			JoyYlow[i] = 20
			JoyYhigh[i] = 60
		MouseSensitivity = 5
		key[0] = 0x48
		key[1] = 0x49
		key[2] = 0x4d
		key[3] = 0x51
		key[4] = 0x50
		key[5] = 0x4f
		key[6] = 0x4b
		key[7] = 0x47
		keyB1 = 0x1d
		keyB2 = 0x38
		return
	soundmode = s16(bytes[0] | (bytes[1] << 8))
	playermode = _read3(bytes, 2)
	JoyXlow = _read3(bytes, 8)
	JoyYlow = _read3(bytes, 14)
	JoyXhigh = _read3(bytes, 20)
	JoyYhigh = _read3(bytes, 26)
	MouseSensitivity = s16(bytes[32] | (bytes[33] << 8))
	var o: int = 34
	for i: int in range(8):
		key[i] = bytes[o]
		o += 1
	keyB1 = bytes[o]
	keyB2 = bytes[o + 1]


static func _read3(bytes: PackedByteArray, o: int) -> PackedInt32Array:
	return PackedInt32Array([s16(bytes[o] | (bytes[o + 1] << 8)), s16(bytes[o + 2] | (bytes[o + 3] << 8)), s16(bytes[o + 4] | (bytes[o + 5] << 8))])


func SaveCtrls() -> void:
	if save_dir == "":
		return
	var b: PackedByteArray = PackedByteArray()
	b.append(soundmode & 0xFF)
	b.append((soundmode >> 8) & 0xFF)
	for i: int in range(3):
		b.append(playermode[i] & 0xFF)
		b.append((playermode[i] >> 8) & 0xFF)
	for arr: PackedInt32Array in [JoyXlow, JoyYlow, JoyXhigh, JoyYhigh]:
		for i: int in range(3):
			b.append(arr[i] & 0xFF)
			b.append((arr[i] >> 8) & 0xFF)
	b.append(MouseSensitivity & 0xFF)
	b.append((MouseSensitivity >> 8) & 0xFF)
	for i: int in range(8):
		b.append(key[i] & 0xFF)
	b.append(keyB1 & 0xFF)
	b.append(keyB2 & 0xFF)
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f: FileAccess = FileAccess.open(save_dir.path_join("CTLPANEL." + data.ext), FileAccess.WRITE)
	if f != null:
		f.store_buffer(b)
		f.close()


# ------------------------------------------------------------------ fades

## INT 10h AX=1002h under DOSBox (int10_pal.cpp, INT10_SetAllPaletteRegisters):
## one status read (ResetACTL), then 16 index/value write pairs, the border
## pair and the closing index write: 1 read and 35 writes. DOSBox charges
## every port access (iohandler.cpp): CPU_CycleMax / (1024 / 1.0 us) cycles a
## read, CPU_CycleMax / (1024 / 0.75 us) a write, 19 and 14 at 20000 cycles;
## plus the caller's register set-up, the INT, the callback and the IRET.
const PALETTE_BIOS_INSTRUCTIONS: int = 8 + 19 + 35 * 14


func _set_palette(table: Array) -> void:
	vm.card.bios_set_palette(PackedByteArray(table))
	# The time it takes: after FadeIn's last step the level loop's first frame
	# reads timecount within microseconds, and a tic falling inside this call
	# sets the whole level's frame clock (Keen 1 levels 3, 4, 5, 9, 13).
	vm.instructions(PALETTE_BIOS_INSTRUCTIONS)


func FadeIn() -> void:
	WaitVBL(1)
	_set_palette(colors[0])
	WaitVBL(8)
	_set_palette(colors[1])
	WaitVBL(8)
	_set_palette(colors[3])


func FadeOut() -> void:
	WaitVBL(1)
	_set_palette(colors[3])
	WaitVBL(8)
	_set_palette(colors[2])
	WaitVBL(8)
	_set_palette(colors[1])
	WaitVBL(8)
	_set_palette(colors[0])


# ------------------------------------------------------------ LoadGraphics

## Puts the latch file into the card's memory at segment A700h, builds the
## five sprite planes with the four shifted copies of every sprite, and shows
## the "one moment" picture, as the original does while it loads.
func LoadGraphics() -> void:
	numchars = data.num_chars
	numtiles = data.num_tiles
	numpics = data.num_pics
	numsprites = data.num_sprites
	spritetable = []
	for e: Dictionary in data.sprite_entries:
		spritetable.append(e.duplicate())
	pictable = []
	for e: Dictionary in data.pic_entries:
		pictable.append(e.duplicate())
	spriteplanesize = 0
	for e: Dictionary in spritetable:
		spriteplanesize += e.w * e.h
	egasprites = PackedByteArray()
	egasprites.resize(5 * spriteplanesize)

	# start graphics mode
	vm.card.bios_set_video_mode(0x0D)
	vm.mark("mode_0d")    # HARN-06: a screen case's key timetable starts here (KEYFEED.COM sees the BIOS mode)
	screenseg = 0xA000
	for i: int in range(4):
		EGAplane(i)
		vm.card.mem_write(0x2000, 0)
	# set virtual screen width
	vm.out8(CRTC_INDEX, CRTC_OFFSET)
	@warning_ignore("integer_division")
	vm.out8(CRTC_INDEX + 1, SCREENWIDTH / 2)
	# set read/write mode 0
	vm.out16(GC_INDEX, GC_MODE)
	# move EGALATCH data into EGA memory
	var latchsize: int = data.latchsize
	for i: int in range(4):
		vm.out16(SC_INDEX, SC_MAPMASK | ((1 << i) << 8))
		vm.card.mem_write_block(LATCH_BASE, data.latch_planes.slice(latchsize * i, latchsize * (i + 1)))
	@warning_ignore("integer_division")
	charptr = LATCH_BASE + (data.off_chars / 16) * 16
	@warning_ignore("integer_division")
	tileptr = LATCH_BASE + (data.off_tiles / 16) * 16
	@warning_ignore("integer_division")
	picptr = LATCH_BASE + (data.off_pics / 16) * 16
	# set border color to (dark) cyan
	vm.card.bios_set_border(3)
	# display the "ONE MOMENT" pic while the remaining graphics load
	DrawPic(15, 76, onemomen_pic())
	vm.out16(GC_INDEX, GC_MODE)
	cost("loadgraphics")    # the sprite file's expansion and shifting, the sound file

	var spritesize: int = data.spritesize
	var src: PackedByteArray = data.sprite_planes
	var dest: int = 0
	for i: int in range(numsprites):
		var e0: Dictionary = spritetable[i * 4]
		var size: int = e0.w * e0.h
		var srcoff: int = e0.shape
		e0.shape = dest
		for plane: int in range(5):
			var from: int = spritesize * plane + srcoff
			var to: int = plane * spriteplanesize + dest
			for k: int in range(size):
				egasprites[to + k] = src[from + k]
		var prev: int = dest       # where the copy to shift from starts, in each plane
		dest += size
		# three copies shifted two pixels further each time
		for shift: int in range(1, 4):
			var e: Dictionary = spritetable[i * 4 + shift]
			var esrc: Dictionary = spritetable[i * 4 + shift - 1]
			size = e.w * e.h
			e.shape = dest
			var width: int = esrc.w
			var height: int = esrc.h
			for p: int in range(5):
				var extrabits: int = 0xFF if p == 4 else 0
				var pbase: int = p * spriteplanesize
				var si: int = pbase + prev
				var di: int = pbase + dest
				for row: int in range(height):
					var rowstart: int = di
					for k: int in range(width):
						egasprites[di] = egasprites[si]
						di += 1
						si += 1
					var rowlen: int = width
					if shift == 1:
						egasprites[di] = extrabits
						di += 1
						rowlen = width + 1
					# shift the row right one bit twice, the extra bit coming in on the left
					for twice: int in range(2):
						var carry: int = extrabits & 1
						for k: int in range(rowlen):
							var b: int = egasprites[rowstart + k]
							egasprites[rowstart + k] = (carry << 7) | (b >> 1)
							carry = b & 1
			prev = dest
			dest += size


func onemomen_pic() -> int:
	return P.ONEMOMENPIC


# ---------------------------------------------------------------- sound

func StartupSound() -> void:
	if dontplay != 0:
		return
	if SPKactive == 0:
		StopSound()
		intcount = 8
		vm.int8 = Callable(self, "UpdateSPKR")
		vm.out8(0x43, 0x36)
		vm.out8(0x40, 0x00)
		vm.out8(0x40, 0x20)
		SPKactive += 1
	soundmode = 1


func ShutdownSound() -> void:
	if dontplay != 0:
		return
	vm.out8(0x43, 0x36)
	vm.out8(0x40, 0)
	vm.out8(0x40, 0)
	if SPKactive == 0:
		return
	vm.int8 = Callable()
	SPKactive = 0
	vm.out8(0x61, vm.in8(0x61) & 0xFD)


func PlaySound(playnum: int) -> void:
	if dontplay != 0:
		return
	if playnum <= 0 or playnum >= data.sounds.size():
		return
	var s: Dictionary = data.sounds[playnum]
	if s.priority < SndPriority:
		return
	SndPriority = s.priority
	SndPtr = (playnum << 16) | 0
	if shell_sound_hook.is_valid() and soundmode != 0:
		shell_sound_hook.call(playnum)    # AUDIO-06: the host's Keen 4-6 effects (presentation only)


func StopSound() -> void:
	if dontplay != 0:
		return
	SndPtr = 0
	SndPriority = 0
	vm.out8(0x61, vm.in8(0x61) & 0xFD)


func PauseSound() -> void:
	if dontplay != 0:
		return
	pausesndptr = SndPtr
	pausepriority = SndPriority
	pauseintcount = intcount
	StopSound()


func ContinueSound() -> void:
	if dontplay != 0:
		return
	SndPtr = pausesndptr
	SndPriority = pausepriority
	intcount = pauseintcount


func WaitEndSound() -> void:
	if dontplay != 0:
		return
	UpdateSPKR()
	while SndPtr != 0 and not exited:
		vm.poll()


## The timer interrupt: counts tics and feeds the speaker one tone at a time.
func UpdateSPKR() -> void:
	timecount = (timecount + 1) & 0xFFFFFFFF
	intcount -= 1
	if intcount == 0:
		intcount = 8
	if SndPtr == 0:
		vm.out8(0x61, vm.in8(0x61) & 0xFC)
		return
	var snd: int = SndPtr >> 16
	var pos: int = SndPtr & 0xFFFF
	var divisors: PackedInt32Array = data.sounds[snd].divisors
	var bx: int = divisors[pos] if pos < divisors.size() else 0xFFFF
	SndPtr = (snd << 16) | (pos + 1)
	if bx == 0:
		vm.out8(0x61, vm.in8(0x61) & 0xFC)
	elif bx == 0xFFFF:
		StopSound()
	elif (soundmode & 0xFF) == 0:
		vm.out8(0x61, vm.in8(0x61) & 0xFC)
	else:
		vm.out8(0x43, 0xB6)
		vm.out8(0x42, bx & 0xFF)
		vm.out8(0x42, (bx >> 8) & 0xFF)
		vm.out8(0x61, vm.in8(0x61) | 3)


# --------------------------------------------------------------- random

func InitRnd(randomize: bool) -> void:
	for i: int in range(17):
		RndArray[i] = baseRndArray[i]
	LastRnd = 0
	indexi = 17 * 2
	indexj = 5 * 2
	if randomize:
		var clock: PackedInt32Array = _dos_clock()
		var dx: int = ((clock[2] & 0xFF) << 8) | (clock[3] & 0xFF)
		var cx: int = ((clock[0] & 0xFF) << 8) | (clock[1] & 0xFF)
		RndArray[16] = dx
		dx ^= cx
		RndArray[4] = dx
	Rnd(0xFFFF)


## The Merlin GS random macro: a lagged addition with the carry of the
## mask-making shift folded in, masked and halved once if still too big.
func Rnd(maxval: int) -> int:
	var ax: int = maxval & 0xFFFF
	var dx: int = 0xFFFF
	var carry: int = 0
	while true:
		carry = (ax >> 15) & 1
		ax = (ax << 1) & 0xFFFF
		if carry != 0:
			break
		dx >>= 1
		if dx == 0 and ax == 0:
			break
	var bx: int = indexi
	var si: int = indexj
	ax = RndArray[(bx >> 1) - 1]
	ax = (ax + RndArray[(si >> 1) - 1] + carry) & 0xFFFF
	RndArray[(bx >> 1) - 1] = ax
	ax = (ax + LastRnd) & 0xFFFF
	LastRnd = ax
	bx -= 2
	if bx == 0:
		bx = 17 * 2
	si -= 2
	if si == 0:
		si = 17 * 2
	indexi = bx
	indexj = si
	var cx: int = maxval & 0xFFFF
	ax &= dx
	if ax > cx:
		ax >>= 1
	return ax


func InitRndT(randomize: bool) -> void:
	rndindex = (_dos_clock()[3] & 0xFF) if randomize else 0
	if trace_frames:
		print("TRACE InitRndT dos_ticks=%d clock=%s rndindex=%d" % [dos_ticks, _dos_clock(), rndindex])


func RndT() -> int:
	rndindex = (rndindex + 1) & 0xFF
	return rndtable[rndindex]


# ------------------------------------------------------------- misc video

## v1.31's WaitVBL: per refresh, wait out any retrace, wait for the next
## one to begin, then spin `mov bx,100 / dec bx / jnz` (about 200
## instructions, 10 us at DOSBox's speed) before looking again.
func WaitVBL(number: int) -> void:
	if exited:
		return
	for i: int in range(number):
		vm.wait_retrace_end()
		vm.wait_retrace_start()
		vm.instructions(203)


## Read/write mode 0 on one plane.
func EGAplane(plane: int) -> void:
	vm.out16(GC_INDEX, GC_MODE)
	vm.out16(GC_INDEX, GC_READMAP | (plane << 8))
	vm.out16(SC_INDEX, SC_MAPMASK | ((1 << plane) << 8))


## Write mode 1 with all planes selected.
func EGAlatch() -> void:
	vm.out16(GC_INDEX, GC_MODE | (1 << 8))
	vm.out16(SC_INDEX, SC_MAPMASK | (15 << 8))


func VideoID() -> int:
	return VGAcard
