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
## game. Sound (HOST-02): the AdLib writes and speaker changes the machine
## makes go to HostAudio, which the screen side turns into samples.
## SHELL-06: when the window loses focus the game pauses (the engine thread
## waits in `pace`), the sound stops and every key held is let go; when it
## comes back the clock starts again from there. However long the host
## stalls (a dragged window, a slow frame), the game catches up by one
## refresh at most, and never runs fast to make up the rest.

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
## SHELL-06: paused while the window is out of focus (or by set_paused).
var paused: bool = false
var _held: Dictionary = {}            # scancode -> true while the player holds it
var _paused_label: Label = null
## The most the machine may lag the wall clock before the lag is dropped: one
## refresh, so a stall costs at most one catch-up frame.
const CATCH_UP_USEC: int = 14268      # 1 / 70.086 s
var stalls_dropped: int = 0
var _keys_until: int = 0              # machine time the last keys given are delivered by

## sound: events gathered on the engine thread, handed over in _pace
var audio: HostAudio = null
const AUDIO_LATENCY: float = 0.12
var _opl_local: Array = []
var _audio_pending: Array = []
var _machine_t: float = 0.0
var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _audio_started: bool = false

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

## A pad, until SHELL-04's mapping: the d-pad and left stick are the arrows,
## A jump (Ctrl), B pogo (Alt), X fire (Space), Y Enter, Start Escape.
const PAD_BUTTONS: Dictionary = {
	JOY_BUTTON_DPAD_UP: 0x48, JOY_BUTTON_DPAD_DOWN: 0x50, JOY_BUTTON_DPAD_LEFT: 0x4B, JOY_BUTTON_DPAD_RIGHT: 0x4D,
	JOY_BUTTON_A: 0x1D, JOY_BUTTON_B: 0x38, JOY_BUTTON_X: 0x39, JOY_BUTTON_Y: 0x1C, JOY_BUTTON_START: 0x01,
}
const STICK_DEADZONE: float = 0.5
var _stick: Dictionary = {}    # arrow scan code -> held by the stick

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
				error = ShellMessages.cant_load(_short_title(found), d.error)
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
				error = ShellMessages.cant_load(_short_title(found), d.error)
				return false
			var g: GalGame = load("res://games/galaxy/gal_%s.gd" % game_id).new()
			g.vm = vm
			g.data = d
			g.us_randomSeed = Time.get_ticks_usec() & 0xFF    # the original's time(0) (A11: set from outside)
			vm.set_cycles(20000)
			engine = g
		_:
			error = ShellMessages.not_ready(_short_title(found))
			return false
	vm.on_display = _on_display
	vm.pace = _pace
	vm.record_speaker = true
	if engine is GalGame:
		(engine as GalGame).sd_alOutHook = func(reg: int, value: int) -> void:
			_opl_local.append([vm.seconds(), reg, value])
	audio = HostAudio.new()
	_player = AudioStreamPlayer.new()
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = HostAudio.RATE
	gen.buffer_length = 0.25
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	_start_usec = Time.get_ticks_usec()
	thread = Thread.new()
	thread.start(_run)
	grab_focus()
	return true


## "Commander Keen 4" of "Commander Keen 4: Secret of the Oracle".
static func _short_title(found: Dictionary) -> String:
	return String(found.get("title", found.get("id", "The game"))).split(":")[0]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_paused(false)


## Pause or resume (SHELL-06). Pausing lets go of every held key (as key-ups
## the game reads before it stops) and mutes; resuming restarts the clock
## from the machine's present time, so nothing is made up.
func set_paused(on: bool) -> void:
	if on == paused or thread == null:
		return
	if on:
		for code: int in _held.keys():
			send_key(code, false)
		_stick.clear()
	_mutex.lock()
	paused = on
	_mutex.unlock()
	if _player != null:
		_player.stream_paused = on
	if on:
		if _paused_label == null:
			_paused_label = Label.new()
			_paused_label.name = "Paused"
			_paused_label.text = "Paused"
			_paused_label.add_theme_font_size_override("font_size", 32)
			_paused_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			add_child(_paused_label)
		_paused_label.visible = true
	elif _paused_label != null:
		_paused_label.visible = false


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
	# the sound events so far go to the screen side
	if not _opl_local.is_empty() or not vm.speaker_events.is_empty():
		var batch: Array = _opl_local
		_opl_local = []
		var spk: PackedInt64Array = vm.speaker_events
		vm.speaker_events = PackedInt64Array()
		var unit: float = float(DosMachine.PIT_HZ * DosMachine.UNIT)
		for i: int in range(0, spk.size(), 2):
			batch.append([float(spk[i]) / unit, -1, int(spk[i + 1])])
		_mutex.lock()
		_audio_pending.append_array(batch)
		_machine_t = vm.seconds()
		_mutex.unlock()
	else:
		_machine_t = vm.seconds()
	if stopping:
		if engine is GalGame:
			(engine as GalGame).Quit("")
		else:
			(engine as VortActs).exited = true
		return
	# SHELL-06: paused, the machine waits here; its clock resumes from now
	_mutex.lock()
	var was_paused: bool = paused
	_mutex.unlock()
	if not keys.is_empty():
		_keys_until = vm.now + 2
	if was_paused and vm.now >= _keys_until:    # the key-ups just given go in first
		while true:
			OS.delay_msec(10)
			_mutex.lock()
			var still: bool = paused and not _stop
			_mutex.unlock()
			if not still:
				break
		_start_usec = Time.get_ticks_usec() - int(vm.seconds() * 1000000.0 / speed)
		return
	var due: int = _start_usec + int(vm.seconds() * 1000000.0 / speed)
	var wait: int = due - Time.get_ticks_usec()
	if wait > 2000:
		OS.delay_usec(wait)
	elif wait < -int(CATCH_UP_USEC / speed):
		# behind by more than a refresh (a stall): drop all but one refresh of it
		_start_usec += -wait - int(CATCH_UP_USEC / speed)
		stalls_dropped += 1


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
	var pending: Array = _audio_pending
	_audio_pending = []
	var machine_t: float = _machine_t
	_mutex.unlock()
	_feed_audio(pending, machine_t)
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


## Sound: events into the mixer (in time order), samples to the output.
func _feed_audio(pending: Array, machine_t: float) -> void:
	if audio == null:
		return
	pending.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e: Array in pending:
		if e[1] == -1:
			audio.push_speaker(e[0], e[2])
		else:
			audio.push_opl(e[0], e[1], e[2])
	if not _audio_started:
		if machine_t <= AUDIO_LATENCY:
			return
		audio.t = machine_t - AUDIO_LATENCY
		_audio_started = true
	if _playback == null:
		return
	# fallen behind (the screen side stalled): catch up silently, keeping a
	# quarter second to fill the output with
	if machine_t - AUDIO_LATENCY - audio.t > 0.4:
		audio.skip_to(machine_t - AUDIO_LATENCY - 0.25)
	# never run the audio clock past the machine's (less the latency)
	var room: int = int((machine_t - AUDIO_LATENCY - audio.t) * HostAudio.RATE)
	var n: int = mini(_playback.get_frames_available(), maxi(room, 0))
	if n > 0:
		_playback.push_buffer(audio.render(n))


## Breaks the references between the machine, its handlers and the engine.
func _release() -> void:
	if vm != null:
		vm.pace = Callable()
		vm.on_display = Callable()
		vm.int8 = Callable()
		vm.int9 = Callable()
		vm.on_limit = Callable()
	if audio != null:
		audio.close()
		audio = null
	if _player != null:
		_player.stop()
	if engine is GalGame:
		(engine as GalGame).sd_alOutHook = Callable()
		(engine as GalGame).CK_ReleaseLinks()
		(engine as GalGame).RF_Shutdown()
	elif engine != null:
		engine.set("vm", null)
	engine = null
	vm = null


## The stick on one axis as the two arrows it stands for.
func _stick_axis(v: float, negative: int, positive: int) -> void:
	for pair: Array in [[negative, v <= -STICK_DEADZONE], [positive, v >= STICK_DEADZONE]]:
		var held: bool = _stick.get(pair[0], false)
		if pair[1] != held:
			_stick[pair[0]] = pair[1]
			send_key(pair[0], pair[1])


## A key from the player (or a test): queued for the engine thread.
func send_key(scancode: int, down: bool) -> void:
	_mutex.lock()
	_keys.append([scancode, down])
	_mutex.unlock()
	if down:
		_held[scancode] = true
	else:
		_held.erase(scancode)


func _input(event: InputEvent) -> void:
	if thread == null:
		return
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		var pcode: int = PAD_BUTTONS.get(jb.button_index, 0)
		if pcode != 0:
			send_key(pcode, jb.pressed)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event
		if jm.axis == JOY_AXIS_LEFT_X:
			_stick_axis(jm.axis_value, 0x4B, 0x4D)
		elif jm.axis == JOY_AXIS_LEFT_Y:
			_stick_axis(jm.axis_value, 0x48, 0x50)
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or k.echo:
		return
	var code: int = SCANCODES.get(k.keycode, 0)
	if code == 0:
		return
	send_key(code, k.pressed)
	get_viewport().set_input_as_handled()
