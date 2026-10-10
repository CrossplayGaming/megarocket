# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's input and sound managers (id_in.c, id_sd.c) as carried in ReflectionHLE, (C) 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
class_name DrmIO
extends DrmRF
## id_in.c and id_sd.c: the keyboard, demos, the timer and the PC speaker and AdLib effects.
## The machine is the DOS one the original drove (as gal_io.gd): SD_Startup takes over timer
## interrupt 8 (vm.int8) and programs the PIT to 140 Hz, the handler counts TimeCount and plays
## the sound effects through the speaker ports and the AdLib; IN_Startup takes over keyboard
## interrupt 9 (vm.int9), which reads port 60h. Busy loops run the machine to its next event
## (BE_ST_ShortSleep) and stop when the program quits. The 2015 release's paths, ReflectionHLE's
## alternative controllers and input binds, and the SoundBlaster, Sound Source and music code
## (compiled out: REFKEEN_SD_ENABLE_*) are left out. No mouse driver and no joystick on the
## machine: MousePresent and JoysPresent stay false. The program runs without parameters
## (id0_argc 1), so the parameter loops of IN_Startup and SD_Startup are not entered.


## The static initialisers of id_in.c's tables (Keyboard[], KbdDefs[], JoyDefs[]).
func _init() -> void:
	Keyboard.resize(NumCodes)
	Keyboard.fill(false)
	KbdDefs = []
	for i: int in range(MaxKbds):
		KbdDefs.append(KeyboardDef.new())
	var d: KeyboardDef = KbdDefs[0]
	d.button0 = 0x1d
	d.button1 = 0x38
	d.upleft = 0x47
	d.up = 0x48
	d.upright = 0x49
	d.left = 0x4b
	d.right = 0x4d
	d.downleft = 0x4f
	d.down = 0x50
	d.downright = 0x51
	JoyDefs = []
	for i: int in range(MaxJoys):
		JoyDefs.append(JoystickDef.new())


# ===================================================================== id_in.c

const KeyInt: int = 9    # the keyboard ISR number
# stuff for the mouse
const MReset: int = 0
const MButtons: int = 3
const MDelta: int = 11
const MouseInt: int = 0x33
# stuff for the joystick
const JoyScaleMax: int = 32768
const JoyScaleShift: int = 8
const MaxJoyValue: int = 5000

# internal variables
var IN_Started: bool = false
var CapsLock: bool = false
var CurCode: int = 0
var LastCode: int = 0

## Unshifted ASCII for scan codes.
const ASCIINames: PackedByteArray = [
	0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9,
	113, 119, 101, 114, 116, 121, 117, 105, 111, 112, 91, 93, 13, 0, 97, 115,
	100, 102, 103, 104, 106, 107, 108, 59, 39, 96, 0, 92, 122, 120, 99, 118,
	98, 110, 109, 44, 46, 47, 0, 42, 0, 32, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 55, 56, 57, 45, 52, 53, 54, 43, 49,
	50, 51, 48, 127, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]
## Shifted ASCII for scan codes.
const ShiftNames: PackedByteArray = [
	0, 27, 33, 64, 35, 36, 37, 94, 38, 42, 40, 41, 95, 43, 8, 9,
	81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 123, 125, 13, 0, 65, 83,
	68, 70, 71, 72, 74, 75, 76, 58, 34, 126, 0, 124, 90, 88, 67, 86,
	66, 78, 77, 60, 62, 63, 0, 42, 0, 32, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 55, 56, 57, 45, 52, 53, 54, 43, 49,
	50, 51, 48, 127, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]
## ASCII for 0xe0 prefixed codes.
const SpecialNames: PackedByteArray = [
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 47, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]
## Scan code names with single chars (the arrows are the font's arrow glyphs).
const ScanNames: PackedStringArray = [
	"?", "?", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "+", "?", "?",
	"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "|", "?", "A", "S",
	"D", "F", "G", "H", "J", "K", "L", ";", "\"", "?", "?", "?", "Z", "X", "C", "V",
	"B", "N", "M", ",", ".", "/", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
	"?", "?", "?", "?", "?", "?", "?", "?", "\u000f", "?", "-", "\u0015", "5", "\u0011", "+", "?",
	"\u0013", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
	"?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
	"?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
]
## Scan codes with >1 char names (0-terminated).
const ExtScanCodes: PackedByteArray = [
	1, 0xe, 0xf, 0x1d, 0x2a, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e,
	0x3f, 0x40, 0x41, 0x42, 0x43, 0x44, 0x57, 0x59, 0x46, 0x1c, 0x36,
	0x37, 0x38, 0x47, 0x49, 0x4f, 0x51, 0x52, 0x53, 0x45, 0x48,
	0x50, 0x4b, 0x4d, 0x00,
]
## Names corresponding to ExtScanCodes.
const ExtScanNames: PackedStringArray = [
	"Esc", "BkSp", "Tab", "Ctrl", "LShft", "Space", "CapsLk", "F1", "F2", "F3", "F4",
	"F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "ScrlLk", "Enter", "RShft",
	"PrtSc", "Alt", "Home", "PgUp", "End", "PgDn", "Ins", "Del", "NumLk", "Up",
	"Down", "Left", "Right", "",
]
## Quick lookup for total direction.
const DirTable: PackedInt32Array = [
	dir_NorthWest, dir_North, dir_NorthEast,
	dir_West, dir_None, dir_East,
	dir_SouthWest, dir_South, dir_SouthEast,
]

## The demo buffer (C's byte seg pointer; empty = NULL) and the manager's key for it when
## IN_StartDemoRecord allocated it ("" when it is the caller's buffer).
var DemoBuffer: PackedByteArray = PackedByteArray()
var DemoBufferKey: String = ""
var DemoOffset: int = 0
var DemoSize: int = 0

## The key hook (a method name, &"" for none).
var INL_KeyHook: StringName = &""

const ParmStrings_id_in: PackedStringArray = ["nojoys", "nomouse"]

# statics of functions
var INL_KeyService_special: bool = false
var INL_GetJoyDelta_lasttime: int = 0


## IN_KeyDown (a macro of id_in.h).
func IN_KeyDown(code: int) -> bool:
	return Keyboard[code]


## IN_ClearKey (a macro of id_in.h).
func IN_ClearKey(code: int) -> void:
	Keyboard[code] = false
	if code == LastScan:
		LastScan = sc_None


## The keyboard interrupt: a key up or down from port 60h.
func INL_KeyService() -> void:
	var k: int = vm.in8(0x60)    # get the scan code
	# tell the XT keyboard controller to clear the key
	var temp: int = vm.in8(0x61)
	vm.out8(0x61, temp | 0x80)
	vm.out8(0x61, temp)

	var c: int = 0
	if k == 0xe0:    # special key prefix
		INL_KeyService_special = true
	elif k == 0xe1:    # handle Pause key
		Paused = true
	else:
		if (k & 0x80) != 0:    # break code
			k &= 0x7f
			Keyboard[k] = false
		else:    # make code
			LastCode = CurCode
			CurCode = k
			LastScan = k
			Keyboard[k] = true

			if INL_KeyService_special:
				c = SpecialNames[k]
			else:
				if k == sc_CapsLock:
					CapsLock = not CapsLock
				if Keyboard[sc_LShift] or Keyboard[sc_RShift]:    # if shifted
					c = ShiftNames[k]
					if c >= 65 and c <= 90 and CapsLock:
						c += 32
				else:
					c = ASCIINames[k]
					if c >= 97 and c <= 122 and CapsLock:
						c -= 32
			if c != 0:
				LastASCII = c
		INL_KeyService_special = false

	if INL_KeyHook != &"" and not INL_KeyService_special:
		call(INL_KeyHook)
	vm.out8(0x20, 0x20)


## No mouse driver: no motion. Returns [x, y].
func INL_GetMouseDelta() -> PackedInt32Array:
	return PackedInt32Array([0, 0])


## No mouse driver: no buttons.
func INL_GetMouseButtons() -> int:
	return 0


## The absolute position of a joystick, timed on port 201h. Returns [x, y] (the C's *xp, *yp).
## No joystick on the machine: the axis bits never fall and both counts run out at MaxJoyValue.
func IN_GetJoyAbs(joy: int, _xp: Variant, _yp: Variant) -> PackedInt32Array:
	var xb: int = 1 << (2 if joy != 0 else 0)
	var yb: int = 1 << (3 if joy != 0 else 1)
	var x: int = 0
	var y: int = 0
	# (the write to 201h that starts the one-shots: the machine's port has no one-shots to start)
	var count: int = MaxJoyValue
	while count > 0:
		var v: int = vm.in8(0x201)
		if (v & xb) != 0:
			x += 1
		if (v & yb) != 0:
			y += 1
		if (v & (xb | yb)) == 0:
			break
		count -= 1
	return PackedInt32Array([x, y])


## The relative movement of a joystick (from +/-127, scaled adaptively). Returns [dx, dy].
func INL_GetJoyDelta(joy: int, adaptive: bool) -> PackedInt32Array:
	var dx: int = 0
	var dy: int = 0
	var xy: PackedInt32Array = IN_GetJoyAbs(joy, null, null)
	var x: int = u16(xy[0])
	var y: int = u16(xy[1])
	var def: JoystickDef = JoyDefs[joy]

	if x < def.threshMinX:
		if x < def.joyMinX:
			x = def.joyMinX
		x = u16(-(x - def.threshMinX))
		x = u16(x * def.joyMultXL)
		x >>= JoyScaleShift
		dx = -127 if x > 127 else -x
	elif x > def.threshMaxX:
		if x > def.joyMaxX:
			x = def.joyMaxX
		x = u16(x - def.threshMaxX)
		x = u16(x * def.joyMultXH)
		x >>= JoyScaleShift
		dx = 127 if x > 127 else x
	else:
		dx = 0

	if y < def.threshMinY:
		if y < def.joyMinY:
			y = def.joyMinY
		y = u16(-(y - def.threshMinY))
		y = u16(y * def.joyMultYL)
		y >>= JoyScaleShift
		dy = -127 if y > 127 else -y
	elif y > def.threshMaxY:
		if y > def.joyMaxY:
			y = def.joyMaxY
		y = u16(y - def.threshMaxY)
		y = u16(y * def.joyMultYH)
		y >>= JoyScaleShift
		dy = 127 if y > 127 else y
	else:
		dy = 0

	if adaptive:
		var time: int = u32(SD_GetTimeCount() - INL_GetJoyDelta_lasttime) / 2
		if time != 0:
			if time > 8:
				time = 8
			dx = s16(dx * time)
			dy = s16(dy * time)
	INL_GetJoyDelta_lasttime = SD_GetTimeCount()
	return PackedInt32Array([dx, dy])


## The button status of a joystick, from port 201h (bits 4-5 joystick 0, 6-7 joystick 1, low = down).
func INL_GetJoyButtons(joy: int) -> int:
	var result: int = vm.in8(0x201)
	result >>= 6 if joy != 0 else 4
	result &= 3
	result ^= 3
	return result


## The de-bounced button status of a joystick.
func IN_GetJoyButtonsDB(joy: int) -> int:
	var result1: int = 0
	var result2: int = 0
	while true:
		result1 = INL_GetJoyButtons(joy)
		var lasttime: int = SD_GetTimeCount()
		SD_TimeCountWaitFromSrc(lasttime, 1)
		result2 = INL_GetJoyButtons(joy)
		BE_ST_ShortSleep()
		if result1 == result2 or quitting:
			break
	return result1


## Sets up the keyboard interrupt.
func INL_StartKbd() -> void:
	IN_ClearKeysDown()
	vm.int9 = Callable(self, "INL_KeyService")
	INL_KeyHook = &""    # clear key hook


## Restores keyboard control to the BIOS.
func INL_ShutKbd() -> void:
	vm.int9 = Callable()


## Detects the mouse: no mouse driver on the machine (INT 33h unset).
func INL_StartMouse() -> bool:
	return false


func INL_ShutMouse() -> void:
	pass


## Sets up scaling values for a joystick (only reached with one present).
func INL_SetJoyScale(joy: int) -> void:
	var def: JoystickDef = JoyDefs[joy]
	def.joyMultXL = u16(JoyScaleMax / maxi(1, u16(def.threshMinX - def.joyMinX)))
	def.joyMultXH = u16(JoyScaleMax / maxi(1, u16(def.joyMaxX - def.threshMaxX)))
	def.joyMultYL = u16(JoyScaleMax / maxi(1, u16(def.threshMinY - def.joyMinY)))
	def.joyMultYH = u16(JoyScaleMax / maxi(1, u16(def.joyMaxY - def.threshMaxY)))


## Sets up thresholding values and the scaling values.
func IN_SetupJoy(joy: int, minx: int, maxx: int, miny: int, maxy: int) -> void:
	var def: JoystickDef = JoyDefs[joy]

	def.joyMinX = u16(minx)
	def.joyMaxX = u16(maxx)
	var r: int = u16(maxx - minx)
	var d: int = r / 5
	def.threshMinX = u16(((r / 2) - d) + minx)
	def.threshMaxX = u16(((r / 2) + d) + minx)

	def.joyMinY = u16(miny)
	def.joyMaxY = u16(maxy)
	r = u16(maxy - miny)
	d = r / 5
	def.threshMinY = u16(((r / 2) - d) + miny)
	def.threshMaxY = u16(((r / 2) + d) + miny)

	INL_SetJoyScale(joy)


## Detects and auto-configures a joystick (assumed centered).
func INL_StartJoy(joy: int) -> bool:
	if current_gamever_int == 100:
		var xy: PackedInt32Array = IN_GetJoyAbs(joy, null, null)
		var result: bool = xy[0] < MaxJoyValue - 10
		if result:
			IN_SetupJoy(joy, 0, xy[0] * 2, 0, xy[1] * 2)
		return result
	else:
		var xy: PackedInt32Array = IN_GetJoyAbs(joy, null, null)
		if (xy[0] == 0 or xy[0] > MaxJoyValue - 10) or (xy[1] == 0 or xy[1] > MaxJoyValue - 10):
			return false
		IN_SetupJoy(joy, 0, xy[0] * 2, 0, xy[1] * 2)
		return true


## Starts up the Input Mgr.
func IN_Startup() -> void:
	if IN_Started:
		return
	var checkjoys: bool = true
	var checkmouse: bool = true
	# (the parameters "nojoys", "nomouse": none given)

	INL_StartKbd()
	MousePresent = INL_StartMouse() if checkmouse else false

	for i: int in range(MaxJoys):
		JoysPresent[i] = INL_StartJoy(i) if checkjoys else false

	IN_Started = true


## Sets up default conditions for the Input Mgr.
func IN_Default(gotit: bool, inp: int) -> void:
	if (not gotit) \
			or (inp == ctrl_Joystick1 and not JoysPresent[0]) \
			or (inp == ctrl_Joystick2 and not JoysPresent[1]) \
			or (inp == ctrl_Mouse and not MousePresent):
		inp = ctrl_Keyboard1
	IN_SetControlType(0, inp)


## Shuts down the Input Mgr.
func IN_Shutdown() -> void:
	if not IN_Started:
		return
	INL_ShutMouse()
	INL_ShutKbd()
	IN_Started = false


## The routine INL_KeyService calls on every real make/break code (a method name).
func IN_SetKeyHook(hook: StringName) -> void:
	INL_KeyHook = hook


## Clears the keyboard array.
func IN_ClearKeysDown() -> void:
	LastScan = sc_None
	LastASCII = key_None
	if Keyboard.size() != NumCodes:
		Keyboard.resize(NumCodes)
	for i: int in range(NumCodes):
		Keyboard[i] = false


func INL_AdjustCursor(info: CursorInfo, buttons: int, dx: int, dy: int) -> void:
	if (buttons & (1 << 0)) != 0:
		info.button0 = true
	if (buttons & (1 << 1)) != 0:
		info.button1 = true
	info.x = s16(info.x + dx)
	info.y = s16(info.y + dy)


## Reads the input devices into the cursor info.
func IN_ReadCursor(info: CursorInfo) -> void:
	info.x = 0
	info.y = 0
	info.button0 = false
	info.button1 = false

	if MousePresent:
		var buttons: int = INL_GetMouseButtons()
		var d: PackedInt32Array = INL_GetMouseDelta()
		INL_AdjustCursor(info, buttons, d[0], d[1])

	for i: int in range(MaxJoys):
		if not JoysPresent[i]:
			continue
		var buttons: int = INL_GetJoyButtons(i)
		var d: PackedInt32Array = INL_GetJoyDelta(i, true)
		INL_AdjustCursor(info, buttons, d[0] / 64, d[1] / 64)


## Reads the device of a player (or the demo) into the control info.
func IN_ReadControl(player: int, info: CursorInfo) -> void:
	var realdelta: bool = false
	var dbyte: int = 0
	var buttons: int = 0
	var dx: int = 0
	var dy: int = 0
	var mx: int = motion_None
	var my: int = motion_None

	if DemoMode == demo_Playback:
		dbyte = DemoBuffer[DemoOffset + 1]
		dy = (dbyte & 3) - 1
		dx = ((dbyte >> 2) & 3) - 1
		buttons = (dbyte >> 4) & 3

		var n: int = DemoBuffer[DemoOffset]
		DemoBuffer[DemoOffset] = u8(n - 1)
		if n == 0:
			DemoOffset = u16(DemoOffset + 2)
			if DemoOffset >= DemoSize:
				DemoMode = demo_PlayDone
	elif DemoMode == demo_PlayDone:
		Quit("Demo playback exceeded")
		return
	elif not shell_controls.is_empty():
		controls_read_vbl = vm.vbl_count
		mx = motion_Left if shell_held("left") else (motion_Right if shell_held("right") else motion_None)
		my = motion_Up if shell_held("up") else (motion_Down if shell_held("down") else motion_None)
		if shell_held("jump"):
			buttons += 1 << 0
		if shell_held("fire") or shell_held("pogo"):
			buttons += 1 << 1
	else:
		controls_read_vbl = vm.vbl_count
		var type: int = Controls[player]
		match type:
			ctrl_Keyboard1, ctrl_Keyboard2:
				var def: KeyboardDef = KbdDefs[type - ctrl_Keyboard]

				if Keyboard[def.upleft]:
					mx = motion_Left
					my = motion_Up
				elif Keyboard[def.upright]:
					mx = motion_Right
					my = motion_Up
				elif Keyboard[def.downleft]:
					mx = motion_Left
					my = motion_Down
				elif Keyboard[def.downright]:
					mx = motion_Right
					my = motion_Down

				if Keyboard[def.up]:
					my = motion_Up
				elif Keyboard[def.down]:
					my = motion_Down

				if Keyboard[def.left]:
					mx = motion_Left
				elif Keyboard[def.right]:
					mx = motion_Right

				if Keyboard[def.button0]:
					buttons += 1 << 0
				if Keyboard[def.button1]:
					buttons += 1 << 1
				realdelta = false
			ctrl_Joystick1, ctrl_Joystick2:
				var d: PackedInt32Array = INL_GetJoyDelta(type - ctrl_Joystick, false)
				dx = d[0]
				dy = d[1]
				buttons = INL_GetJoyButtons(type - ctrl_Joystick)
				realdelta = true
			ctrl_Mouse:
				var d: PackedInt32Array = INL_GetMouseDelta()
				dx = d[0]
				dy = d[1]
				buttons = INL_GetMouseButtons()
				realdelta = true

	if realdelta:
		mx = motion_Left if dx < 0 else (motion_Right if dx > 0 else motion_None)
		my = motion_Up if dy < 0 else (motion_Down if dy > 0 else motion_None)
	else:
		dx = mx * 127
		dy = my * 127

	info.x = dx
	info.xaxis = mx
	info.y = dy
	info.yaxis = my
	info.button0 = (buttons & (1 << 0)) != 0
	info.button1 = (buttons & (1 << 1)) != 0
	info.dir = DirTable[((my + 1) * 3) + (mx + 1)]

	if DemoMode == demo_Record:
		# pack the control info into a byte (the C packs dx, dy: +/-127 from the keyboard)
		dbyte = u8((buttons << 4) | ((dx + 1) << 2) | (dy + 1))

		if DemoBuffer[DemoOffset + 1] == dbyte and DemoBuffer[DemoOffset] < 254 and DemoOffset != 0:
			DemoBuffer[DemoOffset] += 1
		else:
			if DemoOffset != 0:
				DemoOffset = u16(DemoOffset + 2)

			if DemoOffset >= DemoSize:
				Quit("Demo buffer overflow")
				return

			DemoBuffer[DemoOffset] = 1
			DemoBuffer[DemoOffset + 1] = dbyte


## Sets the control type of a player.
func IN_SetControlType(player: int, type: int) -> void:
	Controls[player] = type


## Starts recording a demo into a buffer of the given size; false if none.
func IN_StartDemoRecord(bufsize: int) -> bool:
	if bufsize == 0:
		return false

	MM_GetPtr("DemoBuffer", bufsize)
	DemoBuffer = PackedByteArray()
	DemoBuffer.resize(bufsize)
	DemoBufferKey = "DemoBuffer"
	DemoMode = demo_Record
	DemoSize = bufsize & ~1
	DemoOffset = 0

	return true


## Plays back the demo in `buffer` (pairs of a count and a control byte; the counts are counted
## down in place, as the original does).
func IN_StartDemoPlayback(buffer: PackedByteArray, bufsize: int) -> void:
	DemoBuffer = buffer
	DemoBufferKey = ""
	DemoMode = demo_Playback
	DemoSize = bufsize & ~1
	DemoOffset = 0


## Turns off demo mode.
func IN_StopDemo() -> void:
	DemoMode = demo_Off


## Frees the demo buffer, if it's been allocated.
func IN_FreeDemoBuffer() -> void:
	if not DemoBuffer.is_empty():
		if DemoBufferKey != "":
			MM_FreePtr(DemoBufferKey)
		DemoBuffer = PackedByteArray()
		DemoBufferKey = ""


## The name of a scan code.
func IN_GetScanName(scan: int) -> String:
	var i: int = 0
	while ExtScanCodes[i] != 0:
		if ExtScanCodes[i] == scan:
			return ExtScanNames[i]
		i += 1
	return ScanNames[scan & 0x7f] if scan < 0x80 else "?"


## Waits for a scan code, then clears LastScan and returns it.
func IN_WaitForKey() -> int:
	var result: int = LastScan
	while result == 0 and not quitting:
		BE_ST_ShortSleep()
		result = LastScan
	LastScan = 0
	return result


## Waits for an ASCII char, then clears LastASCII and returns it.
func IN_WaitForASCII() -> int:
	var result: int = LastASCII
	while result == 0 and not quitting:
		BE_ST_ShortSleep()
		result = LastASCII
	LastASCII = 0
	return result


## Waits for either an ASCII keypress or a button press.
func IN_AckBack() -> void:
	while LastScan == 0 and not quitting:
		if MousePresent:
			if INL_GetMouseButtons() != 0:
				while INL_GetMouseButtons() != 0 and not quitting:
					BE_ST_ShortSleep()
				return

		for i: int in range(MaxJoys):
			if JoysPresent[i]:
				if IN_GetJoyButtonsDB(i) != 0:
					while IN_GetJoyButtonsDB(i) != 0 and not quitting:
						BE_ST_ShortSleep()
					return
		BE_ST_ShortSleep()

	IN_ClearKey(LastScan)
	LastScan = sc_None


## Clears user input, then IN_AckBack().
func IN_Ack() -> void:
	IN_ClearKey(LastScan)
	LastScan = sc_None

	if MousePresent:
		while INL_GetMouseButtons() != 0 and not quitting:
			BE_ST_ShortSleep()
	for i: int in range(MaxJoys):
		if JoysPresent[i]:
			while IN_GetJoyButtonsDB(i) != 0 and not quitting:
				BE_ST_ShortSleep()
	IN_AckBack()


## True if a key has been pressed or a button is down.
func IN_IsUserInput() -> bool:
	var result: bool = LastScan != 0

	if MousePresent:
		if INL_GetMouseButtons() != 0:
			result = true

	for i: int in range(MaxJoys):
		if JoysPresent[i]:
			if INL_GetJoyButtons(i) != 0:
				result = true

	return result


## Waits `delay` tics or for the user pressing a key or a button; with `clear`, then IN_AckBack().
func IN_UserInput(delay: int, clear: bool) -> bool:
	var lasttime: int = SD_GetTimeCount()
	while true:
		BE_ST_ShortSleep()
		if IN_IsUserInput():
			if clear:
				IN_AckBack()
			return true
		if quitting or u32(SD_GetTimeCount() - lasttime) >= u32(delay):
			break
	return false


# ===================================================================== id_sd.c

## This table maps channel numbers to carrier and modulator op cells.
const carriers: PackedByteArray = [3, 4, 5, 11, 12, 13, 19, 20, 21]
const modifiers: PackedByteArray = [0, 1, 2, 8, 9, 10, 16, 17, 18]

## Global time in ticks (counted by the timer interrupt; read through SD_GetTimeCount).
var TimeCount: int = 0
## SoundTable: the start of the current mode's sounds in audiosegs (C's &audiosegs[tableoffset]).
var SoundTable: int = 0

# internal variables
var SD_Started: bool = false
const ParmStrings_id_sd: PackedStringArray = ["noal", "nosb", "nodr", "noss", "sst", "ss1", "ss2", "ss3"]
var SoundUserHook: StringName = &""
var SoundNumber: int = 0
var SoundPriority: int = 0
const t0CountTable: PackedInt32Array = [2, 2, 2, 2, 10, 10]

# PC sound variables (pcSound: the offset of the next sample in pcSoundData, 0 = NULL)
var pcLastSample: int = 0
var pcSound: int = 0
var pcSoundData: PackedByteArray = PackedByteArray()
var pcLengthLeft: int = 0
var pcSoundLookup: PackedInt32Array = PackedInt32Array()

var sbNoCheck: bool = false
var ssNoCheck: bool = false

# AdLib variables (alSound: the offset of the next sample in alSoundData, 0 = NULL)
var alNoCheck: bool = false
var alSound: int = 0
var alSoundData: PackedByteArray = PackedByteArray()
var alBlock: int = 0
var alLengthLeft: int = 0
var alFXReg: int = 0

# statics of functions
var SDL_t0Service_count: int = 1

## The shell's OPL emulator: called with (register, value) for each AdLib write. Not game state.
var sd_alOutHook: Callable = Callable()


## SDL_SoundFinished (a macro).
func SDL_SoundFinished() -> void:
	SoundNumber = 0
	SoundPriority = 0


## A byte of a sound chunk (0 past its end, where the C reads on into memory).
static func _snd_byte(b: PackedByteArray, o: int) -> int:
	return b[o] if o < b.size() else 0


static func _snd_word(b: PackedByteArray, o: int) -> int:
	return _snd_byte(b, o) | (_snd_byte(b, o + 1) << 8)


static func _snd_long(b: PackedByteArray, o: int) -> int:
	return _snd_word(b, o) | (_snd_word(b, o + 2) << 16)


## Sets system timer 0 to the specified speed.
func SDL_SetTimer0(speed: int) -> void:
	vm.out8(0x43, 0x36)    # change timer 0
	vm.out8(0x40, speed & 0xFF)
	vm.out8(0x40, (speed >> 8) & 0xFF)


## The number of interrupts system timer 0 generates per second.
func SDL_SetIntsPerSec(ints: int) -> void:
	SDL_SetTimer0(u16(1192755 / ints))


# ---- PC sound

## Plays a sound on the PC speaker (the chunk: length 4, priority 2, data).
func SDL_PCPlaySound(sound: PackedByteArray) -> void:
	pcLastSample = 0xFF
	pcLengthLeft = _snd_long(sound, 0)
	pcSoundData = sound
	pcSound = 6


## Stops the sound playing on the PC speaker.
func SDL_PCStopSound() -> void:
	pcSound = 0
	vm.out8(0x61, vm.in8(0x61) & 0xfd)    # turn the speaker off (~2)


## Plays the next sample of a PC sound.
func SDL_PCService() -> void:
	if pcSound != 0:
		var s: int = _snd_byte(pcSoundData, pcSound)
		pcSound += 1
		if s != pcLastSample:
			pcLastSample = s
			if s != 0:    # we have a frequency!
				# (pcSoundLookup has 255 entries; sample 255 reads the word after it)
				var t: int = pcSoundLookup[s] if s < pcSoundLookup.size() else u16(s * 60)
				vm.out8(0x43, 0xb6)    # write to channel 2 (speaker) timer
				vm.out8(0x42, t & 0xFF)    # low byte
				vm.out8(0x42, (t >> 8) & 0xFF)    # high byte
				vm.out8(0x61, vm.in8(0x61) | 3)    # turn the speaker & gate on
			else:    # time for some silence
				vm.out8(0x61, vm.in8(0x61) & 0xfc)    # turn the speaker & gate off (~3)

		pcLengthLeft = u32(pcLengthLeft - 1)
		if pcLengthLeft == 0:
			SDL_PCStopSound()
			SDL_SoundFinished()


## Turns off the PC speaker.
func SDL_ShutPC() -> void:
	vm.out8(0x61, vm.in8(0x61) & 0xfc)    # turn the speaker & gate off (~3)


# ---- AdLib

## Puts b in AdLib card register n (ports 388h/389h: the OPL emulator's hook).
func alOut(n: int, b: int) -> void:
	if sd_alOutHook.is_valid():
		sd_alOutHook.call(n & 0xFF, b & 0xFF)


## Turns off any sound effect playing through the AdLib card.
func SDL_ALStopSound() -> void:
	alSound = 0
	alOut(alFreqH + 0, 0)


## Plays a sound on the AdLib card (the chunk: length 4, priority 2, instrument 16, block 1, data).
func SDL_ALPlaySound(sound: PackedByteArray) -> void:
	SDL_ALStopSound()

	alLengthLeft = _snd_long(sound, 0)
	alSoundData = sound
	alSound = 23
	alBlock = ((_snd_byte(sound, 22) & 7) << 2) | 0x20
	var inst: int = 6

	if (_snd_byte(sound, inst + 6) | _snd_byte(sound, inst + 7)) == 0:    # mSus | cSus
		Quit("SDL_ALPlaySound() - Seriously suspicious instrument")
		return

	var m: int = modifiers[0]
	var c: int = carriers[0]
	alOut(m + alChar, _snd_byte(sound, inst + 0))
	alOut(m + alScale, _snd_byte(sound, inst + 2))
	alOut(m + alAttack, _snd_byte(sound, inst + 4))
	alOut(m + alSus, _snd_byte(sound, inst + 6))
	alOut(m + alWave, _snd_byte(sound, inst + 8))
	alOut(c + alChar, _snd_byte(sound, inst + 1))
	alOut(c + alScale, _snd_byte(sound, inst + 3))
	alOut(c + alAttack, _snd_byte(sound, inst + 5))
	alOut(c + alSus, _snd_byte(sound, inst + 7))
	alOut(c + alWave, _snd_byte(sound, inst + 9))


## Plays the next sample out through the AdLib card.
func SDL_ALSoundService() -> void:
	if alSound != 0:
		var s: int = _snd_byte(alSoundData, alSound)
		alSound += 1
		if s == 0:
			alOut(alFreqH + 0, 0)
		else:
			alOut(alFreqL + 0, s)
			alOut(alFreqH + 0, alBlock)

		alLengthLeft = u32(alLengthLeft - 1)
		if alLengthLeft == 0:
			alSound = 0
			alOut(alFreqH + 0, 0)
			SDL_SoundFinished()


## Shuts down the AdLib card for sound effects.
func SDL_ShutAL() -> void:
	alOut(alEffects, 0)
	alOut(alFreqH + 0, 0)


## Starts up the AdLib card for sound effects.
func SDL_StartAL() -> void:
	alFXReg = 0
	alOut(alEffects, alFXReg)


## Detects an AdLib by its timer: the machine has one (as DOSBox's default), and its status
## reads as the test wants.
func SDL_DetectAdLib() -> bool:
	alOut(4, 0x60)    # reset T1 & T2
	alOut(4, 0x80)    # reset IRQ
	alOut(2, 0xff)    # set timer 1
	alOut(4, 0x21)    # start timer 1
	alOut(4, 0x60)
	alOut(4, 0x80)
	return true


## The timer 0 ISR: the sound effect's next sample every interrupt, TimeCount and the user
## hook every t0CountTable[SoundMode] interrupts (70 Hz).
func SDL_t0Service() -> void:
	match SoundMode:
		sdm_PC:
			SDL_PCService()
		sdm_AdLib:
			SDL_ALSoundService()

	SDL_t0Service_count = u16(SDL_t0Service_count - 1)
	if SDL_t0Service_count == 0:
		SDL_t0Service_count = t0CountTable[SoundMode]
		TimeCount = u32(TimeCount + 1)
		if SoundUserHook != &"":
			call(SoundUserHook)

	vm.out8(0x20, 0x20)    # ack the interrupt


## Turns off whatever device was being used for sound fx.
func SDL_ShutDevice() -> void:
	match SoundMode:
		sdm_PC:
			SDL_ShutPC()
		sdm_AdLib:
			SDL_ShutAL()
	SoundMode = sdm_Off


## Turns on whatever device is to be used for sound fx.
func SDL_StartDevice() -> void:
	match SoundMode:
		sdm_AdLib:
			SDL_StartAL()
	SoundNumber = 0
	SoundPriority = 0


## Sets which sound hardware to use for sound effects; false if it is not there.
func SD_SetSoundMode(mode: int) -> bool:
	var result: bool = false
	var tableoffset: int = 0

	SD_StopSound()

	match mode:
		sdm_Off:
			tableoffset = 0
			result = true
		sdm_PC:
			tableoffset = STARTPCSOUNDS
			result = true
		sdm_AdLib:
			if AdLibPresent:
				tableoffset = STARTADLIBSOUNDS
				result = true
		_:
			result = false

	if result and mode != SoundMode:
		SDL_ShutDevice()
		SoundMode = mode
		SoundTable = tableoffset
		SDL_StartDevice()

	var rate: int = TickBase * t0CountTable[SoundMode]
	SDL_SetIntsPerSec(rate)

	return result


## Sets the device for background music (compiled out in Dreams, REFKEEN_SD_ENABLE_MUSIC 0:
## the original's code, which nothing calls).
func SD_SetMusicMode(mode: int) -> bool:
	var result: bool = false

	SD_FadeOutMusic()
	while SD_MusicPlaying() and not quitting:
		BE_ST_ShortSleep()

	match mode:
		smm_Off:
			NeedsMusic = false
			result = true
		smm_AdLib:
			if AdLibPresent:
				NeedsMusic = true
				result = true
		_:
			result = false

	if result:
		MusicMode = mode

	return result


## Starts up the Sound Mgr: detects the sound hardware and installs the timer ISR.
## The machine's time when SD_Startup took the timer over (US_DOSHundredths reads the DOS
## clock as it stood then). -1 before.
var sd_startupNow: int = -1


func SD_Startup() -> void:
	if SD_Started:
		return

	ssNoCheck = false
	alNoCheck = false
	sbNoCheck = false
	# (the parameters "noal", "nosb", "nodr", "noss", "sst", "ss1".."ss3": none given)

	SoundUserHook = &""

	vm.int8 = Callable(self, "SDL_t0Service")    # set to my timer 0 ISR
	sd_startupNow = vm.now    # the BIOS ticks no more from here: DOS's time of day stands still
	TimeCount = 0

	SD_SetSoundMode(sdm_Off)

	if not ssNoCheck:
		SoundSourcePresent = false

	if not alNoCheck:
		AdLibPresent = SDL_DetectAdLib()
		if AdLibPresent and not sbNoCheck:
			SoundBlasterPresent = true

	pcSoundLookup.resize(255)
	for i: int in range(255):
		pcSoundLookup[i] = i * 60

	SD_Started = true


## The default sound hardware, whether the config file was there or not (music compiled out).
func SD_Default(gotit: bool, sd: int, _sm: int) -> void:
	var gotsd: bool = gotit

	if gotsd:    # make sure requested sound hardware is available
		match sd:
			sdm_AdLib:
				gotsd = AdLibPresent
	if not gotsd:
		if AdLibPresent:
			sd = sdm_AdLib
		else:
			sd = sdm_PC
	if sd != SoundMode:
		SD_SetSoundMode(sd)


## Shuts down the Sound Mgr: the hardware off, the timer back to 18.2 Hz and the BIOS's ISR.
func SD_Shutdown() -> void:
	if not SD_Started:
		return

	SDL_ShutDevice()
	SDL_SetTimer0(0)
	vm.int8 = Callable()    # set back to the old ISR

	SD_Started = false


## The routine the timer ISR calls 70 times a second (a method name).
func SD_SetUserHook(hook: StringName) -> void:
	SoundUserHook = hook


## Plays a sound on the current hardware.
func SD_PlaySound(sound: int) -> void:
	if SoundMode == sdm_Off:
		return

	var s: Variant = audiosegs[SoundTable + sound] if SoundTable + sound < audiosegs.size() else null
	if s == null:
		Quit("SD_PlaySound() - Attempted to play an uncached sound")
		return
	var priority: int = _snd_word(s, 4)
	if priority < SoundPriority:
		return

	match SoundMode:
		sdm_PC:
			SDL_PCPlaySound(s)
		sdm_AdLib:
			SDL_ALPlaySound(s)

	SoundNumber = sound
	SoundPriority = priority


## The number of the sound playing, or 0.
func SD_SoundPlaying() -> int:
	var result: bool = false

	match SoundMode:
		sdm_PC:
			result = pcSound != 0
		sdm_AdLib:
			result = alSound != 0

	if result:
		return SoundNumber
	return 0


## Stops the sound playing, if any.
func SD_StopSound() -> void:
	match SoundMode:
		sdm_PC:
			SDL_PCStopSound()
		sdm_AdLib:
			SDL_ALStopSound()

	SDL_SoundFinished()


## Waits until the current sound is done playing.
func SD_WaitSoundDone() -> void:
	while SD_SoundPlaying() != 0 and not quitting:
		BE_ST_ShortSleep()


## (Music compiled out, REFKEEN_SD_ENABLE_MUSIC 0; the original's code does nothing.)
func SD_StartMusic(_music: Variant) -> void:
	pass


func SD_FadeOutMusic() -> void:
	pass


func SD_MusicPlaying() -> bool:
	return false


## ReflectionHLE's wrappers for the C's direct uses of TimeCount.
func SD_GetTimeCount() -> int:
	return TimeCount


func SD_SetTimeCount(newcount: int) -> void:
	TimeCount = u32(newcount)


func SD_AddToTimeCount(count: int) -> void:
	TimeCount = u32(TimeCount + count)


## The busy loop "while (TimeCount-src < ticks)" (unsigned, as the C's longword compare).
func SD_TimeCountWaitFromSrc(src: int, ticks: int) -> void:
	while u32(SD_GetTimeCount() - src) < u32(ticks) and not quitting:
		BE_ST_ShortSleep()
