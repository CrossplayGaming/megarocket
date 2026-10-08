# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GameHost
extends Control
## Plays one game in real time (A11): the engine runs on its own thread,
## exactly as headless, and the host paces it from outside through the
## machine's `pace` hook, called before each machine event: the player's key
## presses go in at that moment, and the thread sleeps until the wall clock
## reaches the machine's time. Each frame the card finishes is shown through
## a palette shader at 4:3. When the program quits (or stop() is called) the
## thread ends and `finished` is emitted; nothing carries over to the next
## game. No sound yet (AUDIO units).

signal finished(message: String)

## How many emulated seconds pass per wall second (tests run faster).
var speed: float = 1.0
var game_id: String = ""
var vm: DosMachine = null
var engine: Object = null
var thread: Thread = null
var frames_shown: int = 0
var frames_made: int = 0
var error: String = ""

var _mutex: Mutex = Mutex.new()
var _keys: Array = []                 # [scancode, down] waiting for the engine thread
var _stop: bool = false
var _start_usec: int = 0
var _frame_indices: PackedByteArray = PackedByteArray()
var _frame_palette: PackedByteArray = PackedByteArray()
var _frame_new: bool = false
var _done: bool = false
var _quit_message: String = ""

var _view: TextureRect
var _index_image: Image
var _index_tex: ImageTexture
var _palette_image: Image
var _palette_tex: ImageTexture

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D palette : filter_nearest;
void fragment() {
	float i = floor(texture(TEXTURE, UV).r * 255.0 + 0.5);
	COLOR = vec4(texture(palette, vec2((i + 0.5) / 16.0, 0.5)).rgb, 1.0);
}
"""

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

const GALAXY_META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var aspect: AspectRatioContainer = AspectRatioContainer.new()
	aspect.ratio = 4.0 / 3.0
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(aspect)
	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	aspect.add_child(_view)
	_index_image = Image.create(320, 200, false, Image.FORMAT_R8)
	_index_tex = ImageTexture.create_from_image(_index_image)
	_palette_image = Image.create(16, 1, false, Image.FORMAT_RGB8)
	_palette_tex = ImageTexture.create_from_image(_palette_image)
	var sh: Shader = Shader.new()
	sh.code = SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("palette", _palette_tex)
	_view.material = mat
	_view.texture = _index_tex
	focus_mode = Control.FOCUS_ALL


## Starts a found game (a GameFinder result). False, with `error`, when its
## engine isn't ready to play or its files don't load.
func start(found: Dictionary) -> bool:
	game_id = found.id
	var folder: String = found.folder
	vm = DosMachine.new()
	match game_id:
		"keen1", "keen2", "keen3":
			var d: VortData = VortData.new()
			if not d.load_game(folder, "CK" + game_id.substr(4, 1)):
				error = d.error
				return false
			var g: VortActs = VortKeen3.new() if game_id == "keen3" else (VortKeen2.new() if game_id == "keen2" else VortKeen1.new())
			g.vm = vm
			g.data = d
			g.save_dir = ProjectSettings.globalize_path("user://saves").path_join(game_id)
			DirAccess.make_dir_recursive_absolute(g.save_dir)
			g.apply_dosbox_timing()
			engine = g
		"keen4", "keen5", "keen6":
			var meta: String = GALAXY_META[game_id]
			if game_id == "keen6" and String(found.get("version", "")).contains("1.5"):
				meta = "keen6e15"
			var d: GalData = GalData.new()
			if not d.load_game(folder, "res://data/omnispeak".path_join(meta)):
				error = d.error
				return false
			var g: GalGame = load("res://games/galaxy/gal_%s.gd" % game_id).new()
			g.vm = vm
			g.data = d
			g.us_randomSeed = Time.get_ticks_usec() & 0xFF    # the original's time(0) (A11: set from outside)
			vm.set_cycles(20000)
			engine = g
		_:
			error = "%s's engine is not ready to play yet" % found.get("title", game_id)
			return false
	vm.on_display = _on_display
	vm.pace = _pace
	_start_usec = Time.get_ticks_usec()
	thread = Thread.new()
	thread.start(_run)
	grab_focus()
	return true


## The player leaves: the program is told to quit at its next machine event.
func stop() -> void:
	_mutex.lock()
	_stop = true
	_mutex.unlock()


func _run() -> void:
	if engine is GalGame:
		(engine as GalGame).CK_Main(PackedStringArray())
		_quit_message = (engine as GalGame).quit_message
	else:
		(engine as VortActs).main()
		_quit_message = (engine as VortActs).exit_message
	_mutex.lock()
	_done = true
	_mutex.unlock()


## On the engine's thread, before each machine event.
func _pace() -> void:
	_mutex.lock()
	var keys: Array = _keys
	_keys = []
	var stopping: bool = _stop
	_mutex.unlock()
	for k: Array in keys:
		if k[1]:
			vm.key_down_now(k[0])
		else:
			vm.key_up_now(k[0])
	if stopping:
		if engine is GalGame:
			(engine as GalGame).Quit("")
		else:
			(engine as VortActs).exited = true
		return
	var due: int = _start_usec + int(vm.seconds() * 1000000.0 / speed)
	var wait: int = due - Time.get_ticks_usec()
	if wait > 2000:
		OS.delay_usec(wait)


## On the engine's thread: the card finished a frame.
func _on_display() -> void:
	var card: EgaCard = vm.card
	if card.video_mode != EgaCard.MODE_EGA:
		return
	_mutex.lock()
	_frame_indices = card.frame_pixels.duplicate()
	_frame_palette = card.frame_palette.duplicate()
	_frame_new = true
	frames_made += 1
	_mutex.unlock()


func _process(_delta: float) -> void:
	_mutex.lock()
	var fresh: bool = _frame_new
	var idx: PackedByteArray = _frame_indices
	var pal: PackedByteArray = _frame_palette
	_frame_new = false
	var done: bool = _done
	_mutex.unlock()
	if fresh and idx.size() == 320 * 200 and pal.size() >= 48:
		_index_image.set_data(320, 200, false, Image.FORMAT_R8, idx)
		_index_tex.update(_index_image)
		_palette_image.set_data(16, 1, false, Image.FORMAT_RGB8, pal.slice(0, 48))
		_palette_tex.update(_palette_image)
		frames_shown += 1
	if done and thread != null:
		thread.wait_to_finish()
		thread = null
		_release()
		finished.emit(_quit_message)


## Breaks the references between the machine, its handlers and the engine.
func _release() -> void:
	if vm != null:
		vm.pace = Callable()
		vm.on_display = Callable()
		vm.int8 = Callable()
		vm.int9 = Callable()
		vm.on_limit = Callable()
	if engine is GalGame:
		(engine as GalGame).CK_ReleaseLinks()
		(engine as GalGame).RF_Shutdown()
	elif engine != null:
		engine.set("vm", null)
	engine = null
	vm = null


## A key from the player (or a test): queued for the engine thread.
func send_key(scancode: int, down: bool) -> void:
	_mutex.lock()
	_keys.append([scancode, down])
	_mutex.unlock()


func _input(event: InputEvent) -> void:
	if thread == null:
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or k.echo:
		return
	var code: int = SCANCODES.get(k.keycode, 0)
	if code == 0:
		return
	send_key(code, k.pressed)
	get_viewport().set_input_as_handled()
