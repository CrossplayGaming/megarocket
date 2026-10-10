# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name ControlsModel
extends RefCounted
## CTRL-01: the player's keys and pad buttons, one set for all seven games (the user, 2026-10-10: shared,
## the old control screens replaced everywhere). Each action has up to two keys and up to two buttons;
## a key or button given to one action is taken from any other. Kept in the settings' global section.
##
## The games read them through table(): action -> the scan codes that hold it down, the keys' own and the
## pad's (each pad button reaches the machine as a code of its own, PAD_CODES, while a game is reading its
## play controls; in its menus the pad is the arrows, Enter and Escape). Keen Dreams' throw is Fire's (and
## Pogo's, its second button as in the original); Dreams has no pogo row.

## The actions, in the order the screens list them.
const KEY_ACTIONS: PackedStringArray = ["up", "down", "left", "right", "jump", "pogo", "fire", "status"]
const PAD_ACTIONS: PackedStringArray = ["jump", "pogo", "fire", "status", "quicksave", "quickload"]
const LABELS: Dictionary = {
	"up": "Up", "down": "Down", "left": "Left", "right": "Right", "jump": "Jump", "pogo": "Pogo",
	"fire": "Fire", "status": "Status", "quicksave": "Quicksave", "quickload": "Quickload",
}
const KEY_DEFAULTS: Dictionary = {
	"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
	"jump": [KEY_CTRL, KEY_Z], "pogo": [KEY_ALT, KEY_X], "fire": [KEY_SPACE, KEY_SHIFT], "status": [KEY_ENTER],
}
## The triggers are axes; they bind as these two button numbers.
const PAD_LT: int = 100
const PAD_RT: int = 101
const PAD_DEFAULTS: Dictionary = {
	"jump": [JOY_BUTTON_A], "pogo": [JOY_BUTTON_B], "fire": [JOY_BUTTON_X, PAD_RT], "status": [JOY_BUTTON_Y, JOY_BUTTON_BACK],
	"quicksave": [JOY_BUTTON_LEFT_SHOULDER], "quickload": [JOY_BUTTON_RIGHT_SHOULDER],
}
## Buttons the pad keeps for itself: Start is the menu, the d-pad (and the left stick) moves.
const PAD_FIXED: Array = [JOY_BUTTON_START, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
## Keys that stay the games' own: Escape (the menu, and the way out of everything), the function keys.
const KEY_FIXED: Array = [KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]

## Godot keys -> PC set-1 scan codes (the keypad's codes for the arrows and
## the block above them, as the originals read them).
const SCANCODES: Dictionary = {
	KEY_ESCAPE: 0x01, KEY_1: 0x02, KEY_2: 0x03, KEY_3: 0x04, KEY_4: 0x05, KEY_5: 0x06, KEY_6: 0x07,
	KEY_7: 0x08, KEY_8: 0x09, KEY_9: 0x0A, KEY_0: 0x0B, KEY_MINUS: 0x0C, KEY_EQUAL: 0x0D,
	KEY_BACKSPACE: 0x0E, KEY_TAB: 0x0F, KEY_Q: 0x10, KEY_W: 0x11, KEY_E: 0x12, KEY_R: 0x13,
	KEY_T: 0x14, KEY_Y: 0x15, KEY_U: 0x16, KEY_I: 0x17, KEY_O: 0x18, KEY_P: 0x19,
	KEY_BRACKETLEFT: 0x1A, KEY_BRACKETRIGHT: 0x1B, KEY_ENTER: 0x1C, KEY_KP_ENTER: 0x1C,
	KEY_CTRL: 0x1D, KEY_A: 0x1E, KEY_S: 0x1F, KEY_D: 0x20, KEY_F: 0x21, KEY_G: 0x22, KEY_H: 0x23,
	KEY_J: 0x24, KEY_K: 0x25, KEY_L: 0x26, KEY_SEMICOLON: 0x27, KEY_APOSTROPHE: 0x28,
	KEY_QUOTELEFT: 0x29, KEY_SHIFT: 0x2A, KEY_BACKSLASH: 0x2B, KEY_Z: 0x2C, KEY_X: 0x2D,
	KEY_C: 0x2E, KEY_V: 0x2F, KEY_B: 0x30, KEY_N: 0x31, KEY_M: 0x32, KEY_COMMA: 0x33,
	KEY_PERIOD: 0x34, KEY_SLASH: 0x35, KEY_KP_MULTIPLY: 0x37, KEY_ALT: 0x38, KEY_SPACE: 0x39,
	KEY_CAPSLOCK: 0x3A, KEY_F1: 0x3B, KEY_F2: 0x3C, KEY_F3: 0x3D, KEY_F4: 0x3E, KEY_F5: 0x3F,
	KEY_F6: 0x40, KEY_F7: 0x41, KEY_F8: 0x42, KEY_F9: 0x43, KEY_F10: 0x44, KEY_NUMLOCK: 0x45,
	KEY_SCROLLLOCK: 0x46, KEY_HOME: 0x47, KEY_UP: 0x48, KEY_PAGEUP: 0x49, KEY_KP_SUBTRACT: 0x4A,
	KEY_LEFT: 0x4B, KEY_RIGHT: 0x4D, KEY_KP_ADD: 0x4E, KEY_END: 0x4F, KEY_DOWN: 0x50,
	KEY_PAGEDOWN: 0x51, KEY_INSERT: 0x52, KEY_DELETE: 0x53, KEY_F11: 0x57, KEY_F12: 0x58,
}
## The pad's own codes into the machine while a game reads its play controls (0x60-0x6E: no PC key's).
const PAD_CODES: Dictionary = {
	JOY_BUTTON_A: 0x60, JOY_BUTTON_B: 0x61, JOY_BUTTON_X: 0x62, JOY_BUTTON_Y: 0x63,
	JOY_BUTTON_LEFT_SHOULDER: 0x64, JOY_BUTTON_RIGHT_SHOULDER: 0x65, PAD_LT: 0x66, PAD_RT: 0x67,
	JOY_BUTTON_BACK: 0x68, JOY_BUTTON_LEFT_STICK: 0x69, JOY_BUTTON_RIGHT_STICK: 0x6A,
	JOY_BUTTON_DPAD_UP: 0x6B, JOY_BUTTON_DPAD_DOWN: 0x6C, JOY_BUTTON_DPAD_LEFT: 0x6D, JOY_BUTTON_DPAD_RIGHT: 0x6E,
}
const PAD_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", PAD_LT: "LT", PAD_RT: "RT",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_LEFT_STICK: "L-stick", JOY_BUTTON_RIGHT_STICK: "R-stick",
	JOY_BUTTON_START: "Start", JOY_BUTTON_DPAD_UP: "D-up", JOY_BUTTON_DPAD_DOWN: "D-down",
	JOY_BUTTON_DPAD_LEFT: "D-left", JOY_BUTTON_DPAD_RIGHT: "D-right",
}
## The d-pad's codes, part of the four directions whatever is bound.
const PAD_MOVE: Dictionary = {"up": 0x6B, "down": 0x6C, "left": 0x6D, "right": 0x6E}
## The touch screen's Jump, Pogo and Fire (TouchOverlay): their own codes, part of those actions always.
const TOUCH_CODES: Dictionary = {"jump": 0x70, "pogo": 0x71, "fire": 0x72}

var settings: Settings = null


func _init(p_settings: Settings) -> void:
	settings = p_settings


## The keys (Godot keycodes) or buttons of an action.
func keys(action: String) -> Array:
	return (_all("keys") as Dictionary).get(action, [])


func buttons(action: String) -> Array:
	return (_all("pad") as Dictionary).get(action, [])


## Gives `code` to the action in `slot` (0: the first, 1: the second), taking it from any other action of
## that device. Returns the action it was taken from ("" for none). A fixed key or button is refused ("!").
func bind(device: String, action: String, code: int, slot: int) -> String:
	if (device == "keys" and (KEY_FIXED.has(code) or not SCANCODES.has(code))) or \
			(device == "pad" and (PAD_FIXED.has(code) or not PAD_CODES.has(code))):
		return "!"
	var all: Dictionary = _all(device)
	var taken: String = ""
	for a: String in all:
		var list: Array = all[a]
		if a != action and list.has(code):
			list.erase(code)
			taken = a
	var mine: Array = (all.get(action, []) as Array).duplicate()
	mine.erase(code)
	if slot <= 0 or mine.is_empty():
		mine.insert(0, code)
	else:
		mine.insert(1, code)
	all[action] = mine.slice(0, 2)
	_save(device, all)
	return taken


func clear(device: String, action: String) -> void:
	var all: Dictionary = _all(device)
	all[action] = []
	_save(device, all)


## Back to the defaults: one device's, or both ("").
func reset(device: String = "") -> void:
	for d: String in (["keys", "pad"] if device == "" else [device]):
		settings.reset(d)
	settings.save()


## "Ctrl, Z", "A", or "none".
func shown(device: String, action: String) -> String:
	var names: PackedStringArray = []
	for c: int in (keys(action) if device == "keys" else buttons(action)):
		names.append(key_name(c) if device == "keys" else button_name(c))
	return ", ".join(names) if not names.is_empty() else "none"


static func key_name(code: int) -> String:
	match code:
		KEY_CTRL:
			return "Ctrl"
		KEY_ALT:
			return "Alt"
		KEY_SHIFT:
			return "Shift"
		KEY_ENTER:
			return "Enter"
		KEY_SPACE:
			return "Space"
	return OS.get_keycode_string(code)


static func button_name(code: int) -> String:
	return PAD_NAMES.get(code, "Button %d" % code)


## The rows a game's Keyboard or Controller page lists: {key: action, label, value}. Dreams: no pogo, and
## Fire is its throw.
func rows(device: String, engine: String) -> Array:
	var out: Array = []
	for a: String in (KEY_ACTIONS if device == "keys" else PAD_ACTIONS):
		if engine == "dreams" and (a == "pogo" or a.begins_with("quick")):
			continue
		var label: String = "Throw" if engine == "dreams" and a == "fire" else LABELS[a]
		out.append({"key": a, "label": label, "value": shown(device, a)})
	return out


## Action -> the scan codes that hold it (its keys', its buttons' pad codes; the four directions the d-pad's
## too). What the games' control readers use in place of their own key settings.
func table() -> Dictionary:
	var out: Dictionary = {}
	var k: Dictionary = _all("keys")
	var p: Dictionary = _all("pad")
	for a: String in LABELS:
		var codes: PackedInt32Array = PackedInt32Array()
		for c: int in k.get(a, []):
			if SCANCODES.has(c):
				codes.append(int(SCANCODES[c]))
		for b: int in p.get(a, []):
			if PAD_CODES.has(b):
				codes.append(int(PAD_CODES[b]))
		if PAD_MOVE.has(a):
			codes.append(int(PAD_MOVE[a]))
		if TOUCH_CODES.has(a):
			codes.append(int(TOUCH_CODES[a]))
		out[a] = codes
	return out


func _all(device: String) -> Dictionary:
	var stored: Dictionary = settings.get_value(device)
	var out: Dictionary = {}
	var defaults: Dictionary = KEY_DEFAULTS if device == "keys" else PAD_DEFAULTS
	for a: String in defaults:
		out[a] = (stored.get(a, defaults[a]) as Array).duplicate()
	return out


func _save(device: String, all: Dictionary) -> void:
	settings.set_value(device, all)
	settings.save()
