# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name TouchOverlay
extends Control
## On-screen controls for a touch screen (AND-03): a d-pad at the bottom left,
## the actions at the bottom right, Menu (Escape) and OK (Enter) at the top
## right. Every control presses the same PC keys the keyboard and a pad do,
## so the game cannot tell them apart. Several fingers at once; a finger
## sliding on the d-pad changes direction (two arrows on a diagonal). Keen 1-3
## get Jump, Pogo and the added one-button Fire (Ctrl and Alt together: J-06,
## J-13); Keen 4-6 Jump, Pogo and Fire (Space); Keen Dreams Jump and Throw (its
## two buttons). Shown on a touch screen while no pad is being used (J-54: or with one too, the
## player's choice). J-50: Status beside Menu and OK, a code of its own, so the status screen opens
## whatever key the keyboard's Status is (OK is Enter, the status key only while it is bound so).
##
## J-54 (the Touch page of every game's Options, OptionsModel's "touch"): the layout (the d-pad left and
## the buttons right; mirrored; or compact, the buttons a block of two columns), the opacity (50: the
## look above) and the size (a percentage of a button's side), applied at once (configure()).

## [name, label, scan codes]
## (CTRL-02: Jump, Pogo and Fire are the touch screen's own codes, ControlsModel.TOUCH_CODES, which the
## games' readers count whatever keys the player has bound)
const VORTICONS: Array = [["Jump", "Jump", [0x71]], ["Pogo", "Pogo", [0x72]], ["Fire", "Fire", [0x73]]]
const GALAXY: Array = [["Jump", "Jump", [0x71]], ["Pogo", "Pogo", [0x72]], ["Fire", "Fire", [0x73]]]
const DREAMS: Array = [["Jump", "Jump", [0x71]], ["Throw", "Throw", [0x73]]]    # (Fire's code: the throw's)
const TOP: Array = [["Menu", "Menu", [0x01]], ["OK", "OK", [0x1C]], ["Status", "Status", [0x74]]]
const TOP_NAMES: Array = ["Menu", "OK", "Status"]
const UP: int = 0x48
const DOWN: int = 0x50
const LEFT: int = 0x4B
const RIGHT: int = 0x4D
const BUTTON: float = 72.0         # a button's side, in the UI's own units (scaled on phones)
const MARGIN: float = 16.0

## (scancode, down): where the keys go (GameHost.send_key).
var send: Callable = Callable()
var _buttons: Dictionary = {}      # name -> [Rect2, codes]
var _dpad: Rect2 = Rect2()
var _touch_keys: Dictionary = {}   # touch index -> the codes it holds
var _held: Dictionary = {}         # code -> how many touches hold it
## J-54: "standard", "swapped" or "compact"; the opacity (10-100, 50 the overlay's own look); the size (a
## percentage); shown while a pad is in use too.
var layout: String = "standard"
var opacity: int = 50
var size_percent: int = 100
var with_pad: bool = false


func _init(game_id: String = "") -> void:
	name = "TouchOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var actions: Array = VORTICONS if game_id in ["keen1", "keen2", "keen3"] else (DREAMS if game_id == "kdreams" else GALAXY)
	for a: Array in actions + TOP:
		_buttons[a[0]] = [Rect2(), a[2], a[1]]
	resized.connect(_place)


## Whether the overlay belongs on this device now (J-54: `show_with_pad`, the player's Show with a pad).
static func wanted(touchscreen: bool, pad_in_use: bool, show_with_pad: bool = false) -> bool:
	return touchscreen and (not pad_in_use or show_with_pad)


## J-54: the player's Touch page, applied at once (the controls placed and drawn again).
func configure(p_layout: String, p_opacity: int, p_size: int, p_with_pad: bool) -> void:
	layout = p_layout
	opacity = p_opacity
	size_percent = p_size
	with_pad = p_with_pad
	_place()


## A part's alpha at the player's opacity: `base` at 50, twice it at 100 (never past opaque).
func shade(base: float) -> float:
	return minf(1.0, base * float(opacity) / 50.0)


func _ready() -> void:
	_place()


func _place() -> void:
	var w: float = size.x
	var h: float = size.y
	var b: float = BUTTON * float(size_percent) / 100.0    # (J-54: the player's size)
	_dpad = Rect2(MARGIN, h - MARGIN - b * 3, b * 3, b * 3)
	var x: float = w - MARGIN - b
	var right: Array = []
	for n: String in _buttons:
		if not TOP_NAMES.has(n):
			right.append(n)
	var row_fits: bool = MARGIN + _dpad.size.x + MARGIN + right.size() * (b + MARGIN) <= w
	# a narrow screen's column starts above the d-pad where the two would meet (large buttons)
	var column_base: float = h - MARGIN - b
	if x < _dpad.end.x + MARGIN:
		column_base = _dpad.position.y - MARGIN - b
	var block_base: float = h - MARGIN - b
	if x - (b + MARGIN / 2.0) < _dpad.end.x + MARGIN:
		block_base = _dpad.position.y - MARGIN - b
	for i: int in range(right.size()):
		var k: int = right.size() - 1 - i
		if layout == "compact":
			# J-54: a block of two columns in the corner, the last one rightmost at the bottom
			_buttons[right[k]][0] = Rect2(x - (i % 2) * (b + MARGIN / 2.0), block_base - floori(i / 2.0) * (b + MARGIN / 2.0), b, b)
		elif row_fits:
			# a row, the last one rightmost, each raised a little in turn
			_buttons[right[k]][0] = Rect2(x - i * (b + MARGIN), h - MARGIN - b - i * b * 0.4, b, b)
		else:
			# a narrow (portrait) screen: a column up the right edge
			_buttons[right[k]][0] = Rect2(x, column_base - i * (b + MARGIN), b, b)
	# Menu in the corner, OK and Status (J-50) beside it
	for i: int in range(TOP_NAMES.size()):
		_buttons[TOP_NAMES[i]][0] = Rect2(w - (i + 1) * (MARGIN + b), MARGIN, b, b * 0.6)
	if layout == "swapped":
		# J-54: the d-pad on the right, everything mirrored
		_dpad.position.x = w - _dpad.end.x
		for n: String in _buttons:
			var r: Rect2 = _buttons[n][0]
			_buttons[n][0] = Rect2(w - r.end.x, r.position.y, r.size.x, r.size.y)
	queue_redraw()


## The keys a point holds: the d-pad's arrows (a diagonal is two), or a button's.
func codes_at(p: Vector2) -> Array:
	if _dpad.has_point(p):
		var c: Vector2 = _dpad.get_center()
		var d: Vector2 = (p - c) / (_dpad.size.x / 2.0)
		var out: Array = []
		if d.x < -0.33:
			out.append(LEFT)
		elif d.x > 0.33:
			out.append(RIGHT)
		if d.y < -0.33:
			out.append(UP)
		elif d.y > 0.33:
			out.append(DOWN)
		return out
	for n: String in _buttons:
		if (_buttons[n][0] as Rect2).has_point(p):
			return (_buttons[n][1] as Array).duplicate()
	return []


func button_rect(button_name: String) -> Rect2:
	return _buttons[button_name][0] if _buttons.has(button_name) else Rect2()


func dpad_rect() -> Rect2:
	return _dpad


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * st.position
		_set_touch(st.index, codes_at(at) if st.pressed else [])
		if _touch_keys.has(st.index) or not st.pressed:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if _touch_keys.has(sd.index):
			var at2: Vector2 = get_global_transform_with_canvas().affine_inverse() * sd.position
			_set_touch(sd.index, codes_at(at2))
			get_viewport().set_input_as_handled()


## One finger now holds `codes`: press what is new, let go what it no longer holds.
func _set_touch(index: int, codes: Array) -> void:
	var before: Array = _touch_keys.get(index, [])
	for c: int in before:
		if not codes.has(c):
			_release(c)
	for c: int in codes:
		if not before.has(c):
			_press(c)
	if codes.is_empty():
		_touch_keys.erase(index)
	else:
		_touch_keys[index] = codes
	queue_redraw()


func _press(code: int) -> void:
	_held[code] = int(_held.get(code, 0)) + 1
	if _held[code] == 1 and send.is_valid():
		send.call(code, true)


func _release(code: int) -> void:
	_held[code] = int(_held.get(code, 0)) - 1
	if _held[code] <= 0:
		_held.erase(code)
		if send.is_valid():
			send.call(code, false)


## Every finger lifted (the overlay hides, the game pauses).
func release_all() -> void:
	for index: int in _touch_keys.keys():
		_set_touch(index, [])


func _draw() -> void:
	var held_codes: Dictionary = _held
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(8, roundi(16.0 * float(size_percent) / 100.0))
	draw_rect(_dpad, Color(1, 1, 1, shade(0.08)))
	var cell: float = _dpad.size.x / 3.0
	for arrow: Array in [[UP, Vector2(1, 0)], [DOWN, Vector2(1, 2)], [LEFT, Vector2(0, 1)], [RIGHT, Vector2(2, 1)]]:
		var r: Rect2 = Rect2(_dpad.position + arrow[1] * cell, Vector2(cell, cell)).grow(-4)
		draw_rect(r, Color(1, 1, 1, shade(0.35 if held_codes.has(arrow[0]) else 0.18)))
	for n: String in _buttons:
		var r2: Rect2 = _buttons[n][0]
		var on: bool = (_buttons[n][1] as Array).all(func(c: int) -> bool: return held_codes.has(c))
		draw_rect(r2, Color(1, 1, 1, shade(0.35 if on else 0.18)))
		draw_string(font, r2.position + Vector2(6, r2.size.y / 2 + font_size * 0.375), _buttons[n][2], HORIZONTAL_ALIGNMENT_LEFT,
			r2.size.x - 12, font_size, Color(1, 1, 1, shade(0.8)))
