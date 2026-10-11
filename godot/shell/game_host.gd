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
## SHELL-08: if the pad being played with is unplugged, the game pauses the
## same way and says so; plugging it back in, or any key, goes on.
## SHELL-04: Back and Start held together on a pad for three seconds give the
## pad's buttons back their defaults, whatever the game is doing.

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
## Where the player's settings are read from (AUDIO-06's volumes; a test gives its own).
var settings_path: String = Settings.default_path()
## SAVE-06: where the games keep the player's saved games, high scores and their own settings, a folder
## each (<this>/<game>; a test gives its own, so HARN-09's walk never writes the player's).
var saves_dir: String = Settings.user_dir().path_join("saves")

var _mutex: Mutex = Mutex.new()
var _keys: Array = []                 # [scancode, down] waiting for the engine thread
var _stop: bool = false
var _start_usec: int = 0
var _frame_indices: PackedByteArray = PackedByteArray()
var _frame_palette: PackedByteArray = PackedByteArray()
var _frame_new: bool = false
## A text-mode screen's cells (empty: the card's picture is shown)
var _frame_text: PackedByteArray = PackedByteArray()
var _text_view: TextScreenView = null
## REND-02: the draw list of the picture just shown, when native resolution draws it ({} otherwise)
var _frame_list: Dictionary = {}
var _native: VortNativeView = null
var _native_view: VortNativeView = null
var _gal_view: GalNativeView = null
var _drm_view: DrmNativeView = null
## MAKER-02: the level the game goes straight into (-1: the game from its start)
var _play_level: int = -1
## REND-04: the wide view on (Keen 1-3), and the window size it was last fitted to
var _wide: bool = false
var _fitted: Vector2 = Vector2.ZERO
const WIDE_MAX: int = 448    # the widest view, in the original's pixels (four tiles more each side)
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
## SHELL-08: the pad played with (-1 none yet), and paused because it went away.
var pad_device: int = -1
var pad_paused: bool = false
## AND-03: the on-screen controls, on a touch screen while no pad is in use
## (`force_touch` shows them anyway: tests, and a player's choice later).
var overlay: TouchOverlay = null
var force_touch: bool = false
## The pads connected now (Input's; a test gives its own).
var connected_pads: Callable = func() -> Array: return Input.get_connected_joypads()
const PAD_GONE_TEXT: String = "Controller disconnected\nReconnect it, or press any key to go on"

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
var _backdrop: StageBackdrop = null
## MENU-01: the Options rows the game's own menus show (the shell's settings, applied here).
var options: OptionsModel = null
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

## Godot keys -> PC set-1 scan codes (ControlsModel's table).
const SCANCODES: Dictionary = ControlsModel.SCANCODES
## CTRL-02: the pad in a game's menus (while it is not reading its play controls): the d-pad and the
## left stick the arrows, A Enter, B Escape, X Space, Y Enter. In play each button is its own code
## (ControlsModel.PAD_CODES) and the player's bindings say what it does; Start is Escape always.
const PAD_MENU: Dictionary = {
	JOY_BUTTON_DPAD_UP: 0x48, JOY_BUTTON_DPAD_DOWN: 0x50, JOY_BUTTON_DPAD_LEFT: 0x4B, JOY_BUTTON_DPAD_RIGHT: 0x4D,
	JOY_BUTTON_A: 0x1C, JOY_BUTTON_B: 0x01, JOY_BUTTON_X: 0x39, JOY_BUTTON_Y: 0x1C,
}
const ARROWS: Dictionary = {"up": 0x48, "down": 0x50, "left": 0x4B, "right": 0x4D}
const STICK_DEADZONE: float = 0.5
## CTRL-01/02: the player's keys and buttons (shared by every game), and what each pad button, trigger
## and stick direction held down sent (so its release lets go of the same code, whatever has changed)
var controls: ControlsModel = null
## AUDIO-06: Keen 4 and 5's folders (the launcher's finds: {"keen4": folder, ...}) and, loaded from them for
## Keen 1-3, their AdLib effects; the sound names of the game's sound numbers
var galaxy_folders: Dictionary = {}
var galaxy_sounds: GalaxySounds = null
var _sound_names: PackedStringArray = PackedStringArray()
var _music_level: int = -1    # the track playing (its level; 0 the world map, -1 none)
var _pad_sent: Dictionary = {}
## SCR-05: the on-screen d-pad's arrows -> the pad's d-pad codes, sent instead while a line is typed; and what
## each of the overlay's keys held down sent (its release lets go of the same code).
const TOUCH_TYPING: Dictionary = {0x48: 0x6D, 0x50: 0x6E, 0x4B: 0x6F, 0x4D: 0x70}
var _touch_sent: Dictionary = {}
## SHELL-04: how long Back and Start are held together for the reset; each pad's of the two held
## (device -> {button: true}); the pad holding both and since when (-1: none), and whether this hold has
## reset already.
const RESET_HOLD_USEC: int = 3000000
const RESET_TEXT: String = "Controller buttons back to their defaults"
var _chord_held: Dictionary = {}
var _chord_device: int = -1
var _chord_since: int = -1
var _chord_done: bool = false
## A short word on screen (the reset's), and the time it goes.
var _message: Label = null
var _message_until: int = 0

const GALAXY_META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# REND-08: the backdrop and frame round any picture that doesn't fill the window; the pictures are
	# placed by hand (_layout_stage)
	_backdrop = StageBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
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
	# REND-02: native resolution's view, beside the 320x200's (used for Keen 1-3 so far)
	_native_view = VortNativeView.new()
	_native_view.visible = false
	add_child(_native_view)
	_gal_view = GalNativeView.new()    # Keen 4-6's
	_gal_view.visible = false
	add_child(_gal_view)
	_drm_view = DrmNativeView.new()    # Keen Dreams' (SHELL-14)
	_drm_view.visible = false
	add_child(_drm_view)
	_text_view = TextScreenView.new()    # text-mode screens (Keen Dreams' start)
	_text_view.visible = false
	add_child(_text_view)
	focus_mode = Control.FOCUS_ALL


## TIME-D: Keen Dreams' costs (tools/calibrate_dreams.py fits them; drm_boot takes them on its command line)
## into the engine and the machine, as drm_boot applies them.
func _dreams_costs(dg: DreamsGame, release: String) -> void:
	var text: String = FileAccess.get_file_as_string("res://data/dreams_costs.json")
	var doc: Variant = JSON.parse_string(text) if text != "" else null
	if not doc is Dictionary:
		return
	var costs: Dictionary = (doc as Dictionary).get("costs", {})
	for k: String in costs:
		dg.costs[k] = int(costs[k])
	var own: Dictionary = ((doc as Dictionary).get("by_game", {}) as Dictionary).get(release, {})
	for k: String in own:
		dg.costs[k] = int(own[k])
	vm.vga_access_units = int(dg.costs.get("vga", 0))
	if dg.costs.has("pitphase"):
		vm.timer_offset = int(dg.costs["pitphase"])


## Starts a found game (a GameFinder result). False, with `error`, when its
## engine isn't ready to play or its files don't load.
## MAKER-02, the maker's play button: with "play_level" (a level number) the game goes straight into
## that level and is left when the level ends; "maker_files" (Keen 1-3: file name -> bytes, a level
## written by the maker) or "maker_maps" (Keen 4-6: {maphead, gamemaps}) stand in for the folder's.
func start(found: Dictionary) -> bool:
	game_id = found.id
	var folder: String = found.folder
	_play_level = int(found.get("play_level", -1))
	vm = DosMachine.new()
	match game_id:
		"keen1", "keen2", "keen3":
			var d: VortData = VortData.new()
			_stage_filters(d.stage)
			if not d.load_game(folder, "CK" + game_id.substr(4, 1)):
				error = ShellMessages.cant_load(_short_title(found), d.error)
				return false
			var files: Dictionary = found.get("maker_files", {})
			for name: String in files:
				d.overrides[name.to_upper()] = files[name]
			var g: VortActs = VortKeen3.new() if game_id == "keen3" else (VortKeen2.new() if game_id == "keen2" else VortKeen1.new())
			g.vm = vm
			g.data = d
			if _play_level >= 0:
				var n: int = _play_level
				g.after_startup = func() -> void: g.shell_play_level(n)
			g.save_dir = saves_dir.path_join(game_id)
			DirAccess.make_dir_recursive_absolute(g.save_dir)
			g.apply_dosbox_timing()
			engine = g
		"keen4", "keen5", "keen6":
			var meta: String = GALAXY_META[game_id]
			if game_id == "keen6" and String(found.get("version", "")).contains("1.5"):
				meta = "keen6e15"
			var d: GalData = GalData.new()
			_stage_filters(d.stage)
			if not d.load_game(folder, "res://data/omnispeak".path_join(meta)):
				error = ShellMessages.cant_load(_short_title(found), d.error)
				return false
			var maps: Dictionary = found.get("maker_maps", {})
			if not maps.is_empty() and not d.use_maps(maps.maphead, maps.gamemaps):
				error = ShellMessages.cant_load(_short_title(found), d.error)
				return false
			var g: GalGame = load("res://games/galaxy/gal_%s.gd" % game_id).new()
			g.vm = vm
			g.data = d
			# SAVE-06: the settings, high scores and saved games, kept between sessions as Keen 1-3's are
			# (a level played in place from the maker keeps none)
			if _play_level < 0:
				g.user_dir = saves_dir.path_join(game_id)
				g.load_user_files()
			g.us_randomSeed = Time.get_ticks_usec() & 0xFF    # the original's time(0) (A11: set from outside)
			vm.set_cycles(20000)
			engine = g
		"kdreams":
			var dd: DreamsData = DreamsData.new()
			_stage_filters(dd.stage)
			if not dd.load_game(folder):
				error = ShellMessages.cant_load(_short_title(found), dd.error)
				return false
			var dg: DreamsGame = DreamsGame.new()
			dg.vm = vm
			dg.data = dd
			# DOSBox's timing as the recordings were made (drm_boot's)
			vm.set_cycles(20000)
			vm.vbl_period = 17024400
			vm.timer_offset = 0
			# TIME-D: the original's time for its loads and screens, the costs fitted on the recordings
			# (godot/data/dreams_costs.json: the shared ones, then the release's own), and the timer's phase
			_dreams_costs(dg, "kdreams193" if dd.version == "e193" else "kdreams")
			if dd.version == "e193":
				dg.us_files["KDREAMS.CMP"] = dd._read("KDREAMS.CMP")    # v1.93's title archive, from the game
			# J-51: each release its own folder (their saves map objects to their own state tables)
			dg.user_dir = saves_dir.path_join("kdreams193" if dd.version == "e193" else game_id)
			dg.load_user_files()
			if _play_level >= 0:
				dg.kl_warp = _play_level    # straight into the level (HARN-23's way), left when it ends
			engine = dg
		_:
			error = ShellMessages.not_ready(_short_title(found))
			return false
	overlay = TouchOverlay.new(game_id)
	overlay.send = _touch_key
	add_child(overlay)
	_update_overlay()
	vm.on_display = _on_display
	vm.pace = _pace
	vm.record_speaker = true
	if engine is GalGame:
		(engine as GalGame).sd_alOutHook = func(reg: int, value: int) -> void:
			_opl_local.append([vm.seconds(), reg, value])
	elif engine is DreamsGame:
		(engine as DreamsGame).sd_alOutHook = func(reg: int, value: int) -> void:
			_opl_local.append([vm.seconds(), reg, value])
	audio = HostAudio.new()
	var settings: Settings = Settings.new(settings_path)
	audio.configure(float(settings.get_value("music_volume", game_id)) / 100.0,
		float(settings.get_value("effects_volume", game_id)) / 100.0)
	# MENU-01: the Options rows, for the engines whose menus show them so far
	options = OptionsModel.new(settings, game_id, "vorticons" if engine is VortScreens else ("galaxy" if engine is GalGame else "dreams"))
	options.applier = apply_setting
	controls = ControlsModel.new(settings)
	if engine is VortScreens and not galaxy_folders.is_empty():
		galaxy_sounds = GalaxySounds.new()
		galaxy_sounds.load(galaxy_folders)
		options.galaxy_available = galaxy_sounds.available()
		_sound_names = VortNames1.SOUND_NAMES if game_id == "keen1" else (VortNames2.SOUND_NAMES if game_id == "keen2" else VortNames3.SOUND_NAMES)
		var gv: DosMachine = vm
		(engine as VortScreens).shell_sound_hook = func(n: int) -> void:
			_opl_local.append([gv.seconds(), -2, n])
	options.controls = controls
	if "options" in engine:
		engine.set("options", options)
	if "fixes" in engine:
		engine.set("fixes", options.fixes())    # FIX-01: the game's fixes (empty, all off, when headless)
	apply_setting("pixel_shape")
	if engine is VortScreens:
		_native = _native_view
		_native.setup((engine as VortScreens).data)
		_backdrop.setup((engine as VortScreens).data.tiles, StageBackdrop.BACKDROP_TILE.get(game_id, -1))
	elif engine is GalGame:
		_native = _gal_view
		_native.setup((engine as GalGame).data)
		var cells: Array = []
		for y: int in range(4):
			for x: int in range(4):
				cells.append(Vector2i(x, y))
		_backdrop.setup_tile(_gal_view.images.tile(int(StageBackdrop.BACKDROP_TILE[game_id])).get("pixels", PackedByteArray()), cells)
	elif engine is DreamsGame:
		# SHELL-14: Dreams' view, and its backdrop tile in every cell as Keen 4-6's
		_native = _drm_view
		_native.setup((engine as DreamsGame).data)
		var cells: Array = []
		for y: int in range(4):
			for x: int in range(4):
				cells.append(Vector2i(x, y))
		_backdrop.setup_tile(_drm_view.images.tile(int(StageBackdrop.BACKDROP_TILE[game_id])).get("pixels", PackedByteArray()), cells)
	apply_setting("native_resolution")
	apply_setting("smooth_motion")
	apply_setting("wide_view")
	apply_setting("controls")
	apply_setting("touch_layout")
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


## A setting changed in the game's Options (or at the start): applied to the window, the picture or
## the sound at once (main thread).
## V15-01 / V15-06 (A18): the player's packs and Keen's Closet for this game, as the asset stage's filters,
## set before the game's files are read (a later pack wins over an earlier; the closet colours what the
## packs leave). Nothing is set with both off, so the stage stays the identity.
func _stage_filters(stage: AssetStage) -> void:
	var settings: Settings = Settings.new(settings_path)
	AssetPacks.apply(stage, settings, game_id)
	var cl: KeenCloset = KeenCloset.from_settings(settings, game_id)
	if cl != null:
		stage.add_filter(cl.filter)


func apply_setting(name: String) -> void:
	if options == null:
		return
	if name.begins_with("fix_"):
		if engine != null and "fixes" in engine:
			engine.set("fixes", options.fixes())    # read by the engine at each fix's point
		return
	if name in ["controls", "keys", "pad", "one_button_fire", "two_button_fire"]:
		# CTRL-02: the bindings to the game's control reader; the fire button's mode (Keen 1-3: Fire is the
		# player's own key, or only the original's two together; Keen 4-6: TWO-BUTTON FIRING)
		if controls != null and "shell_controls" in engine:
			engine.set("shell_controls", controls.table())
		if "shell_one_fire" in engine:
			var own: bool = bool(options.get_value("one_button_fire")) if engine is VortScreens else not bool(options.get_value("two_button_fire"))
			engine.set("shell_one_fire", own)
			if "ck_twoButtonFiring" in engine:
				engine.set("ck_twoButtonFiring", not own)
		return
	if name == "native_resolution" or name == "smooth_motion" or name == "wide_view":
		if _native != null:
			var native: bool = bool(options.get_value("native_resolution"))
			var wide: bool = bool(options.get_value("wide_view"))
			engine.set("draw_capture", native or wide)
			_native.smooth = bool(options.get_value("smooth_motion"))
			_native.snap = not native
			_wide = wide
			_fit_view()
		return
	if name.begins_with("touch_"):
		# J-54: the Touch page's layout, opacity, size and Show with a pad, to the on-screen controls at once
		if overlay != null:
			overlay.configure(str(options.get_value("touch_layout")), int(options.get_value("touch_opacity")),
				int(options.get_value("touch_size")), bool(options.get_value("touch_with_pad")))
			_update_overlay()
		return
	match name:
		"fullscreen":
			var full: bool = bool(options.get_value("fullscreen"))
			if not OS.has_feature("mobile") and get_window() != null:
				get_window().mode = Window.MODE_FULLSCREEN if full else Window.MODE_WINDOWED
		"pixel_shape":
			# 4:3 is the monitor's shape the games were drawn for; square pixels show 320x200 as 16:10
			_fit_view()
		"music_volume", "effects_volume":
			if audio != null:
				audio.configure(float(options.get_value("music_volume")) / 100.0, float(options.get_value("effects_volume")) / 100.0)


## "Commander Keen 4" of "Commander Keen 4: Secret of the Oracle".
static func _short_title(found: Dictionary) -> String:
	return String(found.get("title", found.get("id", "The game"))).split(":")[0]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not pad_paused:
		set_paused(false)


func _enter_tree() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection):
		Input.joy_connection_changed.connect(_on_joy_connection)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection):
		Input.joy_connection_changed.disconnect(_on_joy_connection)


## SHELL-08: the pad played with goes away (pause, say so) or comes back (go on).
func _on_joy_connection(device: int, connected: bool) -> void:
	if thread == null or device != pad_device:
		return
	if not connected and not pad_paused:
		pad_paused = true
		set_paused(true)
		_paused_label.text = PAD_GONE_TEXT
	elif connected and pad_paused:
		_resume_from_pad()


func _resume_from_pad() -> void:
	pad_paused = false
	set_paused(false)
	if _paused_label != null:
		_paused_label.text = "Paused"


## Pause or resume (SHELL-06). Pausing lets go of every held key (as key-ups
## the game reads before it stops) and mutes; resuming restarts the clock
## from the machine's present time, so nothing is made up.
func set_paused(on: bool) -> void:
	if on == paused or thread == null:
		return
	if on:
		for code: int in _held.keys():
			send_key(code, false)
		_pad_sent.clear()
		_chord_held.clear()
		_chord_device = -1
		_chord_since = -1
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
		# the maker's play button: the original's own launch from its map editor (TED)
		(engine as GalGame).CK_Main(PackedStringArray(["/TEDLEVEL", str(_play_level)]) if _play_level >= 0 else PackedStringArray())
		_quit_message = (engine as GalGame).quit_message
	elif engine is DreamsGame:
		(engine as DreamsGame).kd_main_entry(PackedStringArray())
		_quit_message = (engine as DreamsGame).quit_message
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
		elif engine is DreamsGame:
			(engine as DreamsGame).Quit("")
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
		if engine is DreamsGame:
			# a text-mode screen (Keen Dreams' start screens): the 80x25 cells, drawn by the shell
			_mutex.lock()
			_frame_text = (engine as DreamsGame).textmem.slice(0, TextScreenView.COLS * TextScreenView.ROWS * 2)
			_frame_new = true
			frames_made += 1
			_mutex.unlock()
		return
	_mutex.lock()
	_frame_indices = card.frame_pixels.duplicate()
	_frame_palette = card.frame_palette.duplicate()
	_frame_list = _shown_list() if _native != null else {}
	_frame_new = true
	frames_made += 1
	_mutex.unlock()


## The stage (REND-04, REND-08), every frame: in the wide view's play the list fills the window, as many
## of the original's pixels wide as fit (up to WIDE_MAX); any other picture (4:3 play, the menus, the
## intro, text screens) keeps the original's shape inside the bevelled frame, the backdrop round it
## (Megarocket 1.0: never stretch, never black bars). The engine is told the wide view's extra tiles each
## side (J-30: creatures wake by them) whenever the wide view is on, so play and the view agree.
func _fit_view() -> void:
	_layout_stage(_native != null and _native.visible)


func _layout_stage(native: bool) -> void:
	if options == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# one original pixel's width against its height: 4:3 makes 320 pixels as wide as 266.7 tall ones
	var px_w: float = (4.0 / 3.0 * 200.0 / 320.0) if options.get_value("pixel_shape") == "4:3" else 1.0
	var wide_px: int = clampi(int(roundf(size.x / (size.y / 200.0) / px_w)), 320, WIDE_MAX)
	if engine != null and "wide_tiles" in engine:
		# the tiles the view can reach past the original's picture on one side: all its extra width, as at
		# a map's edge the view keeps inside the map and so stands wholly to one side of the camera
		engine.set("wide_tiles", (wide_px - 320 + 15) / 16 if _wide and wide_px > 320 else 0)
	_fitted = size
	if native and _wide:
		var u: Vector2 = Vector2(size.y / 200.0 * px_w, size.y / 200.0)
		var r: Rect2 = Rect2(Vector2((size.x - wide_px * u.x) / 2.0, 0.0), Vector2(wide_px * u.x, size.y))
		_native.view_w = wide_px
		_place(_native, r)
		_backdrop.place(Rect2(), u)
		return
	# the picture at the original's shape with the frame round it, as big as fits
	var f: float = StageBackdrop.FRAME
	var uh: float = minf(size.y / (200.0 + 2.0 * f), size.x / ((320.0 + 2.0 * f) * px_w))
	var unit: Vector2 = Vector2(uh * px_w, uh)
	var pic: Rect2 = Rect2(((size - Vector2(320.0, 200.0) * unit) / 2.0).round(), (Vector2(320.0, 200.0) * unit).round())
	_place(_view, pic)
	if _text_view != null:
		_place(_text_view, pic)
	if _native != null:
		_native.view_w = 320
		_place(_native, pic)
	_backdrop.place(pic, unit)


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


## On the engine's thread: the draw list of the picture just shown, if the shell's views draw it: the
## newest refresh whose start the card took (REND-01's rule), the game's play (a level, the world map),
## no user routine; a window printed over it comes along as its rectangle; {} otherwise.
func _shown_list() -> Dictionary:
	if engine is GalGame:
		return _shown_list_galaxy()
	if engine is DreamsGame:
		return _shown_list_dreams()
	var g: VortScreens = engine as VortScreens
	if g == null or not g.draw_capture:
		return {}
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return {}
	if vm.card.display_start != int(list.start) or (vm.card.atc[EgaCard.ATR_PELPAN] & 7) != int(list.pan):
		return {}
	if str(list.user) != "" or not list.get("play", false):
		return {}    # the intro, title, high scores, endings: screens, shown as the original's picture
	var shown: Dictionary = list.duplicate()
	if g.draw_overlaid[int(list.page)]:
		shown["overlay"] = g.draw_overlay_rect[int(list.page)]    # a window over the play: drawn from the card
	return shown


## Keen 4-6's: the newest refresh whose start the card took, if nothing else was put on the card since
## (a menu, a window: lists marked "none" or "touched"), a level or the world map (not the high scores),
## no routine drawing over it but the status window's (its strip comes along as the list's overlay).
func _shown_list_galaxy() -> Dictionary:
	var g: GalGame = engine as GalGame
	if not g.draw_capture:
		return {}
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return {}
	if vm.card.display_start != int(list.start) or list.get("none", false) or list.get("touched", false):
		return {}
	if str(list.get("user", "")) != "" or not list.get("play", false):
		return {}
	return list


## Keen Dreams' (SHELL-14): as Keen 4-6's, the card's panning the list's too (the pel panning is set in the
## retrace after the start is taken); a level, not the title map (v1.00's, a screen: framed).
func _shown_list_dreams() -> Dictionary:
	var g: DreamsGame = engine as DreamsGame
	if not g.draw_capture:
		return {}
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return {}
	if vm.card.display_start != int(list.start) or list.get("none", false) or list.get("touched", false):
		return {}
	if (vm.card.atc[EgaCard.ATR_PELPAN] & 7) != int(list.get("pan", 0)):
		return {}
	if str(list.get("user", "")) != "" or not list.get("play", false):
		return {}
	return list


## CTRL-03..05: what a Controls page waiting for a key ("keys") or a button ("pad") catches from an event:
## the Godot key or pad button (a trigger as ControlsModel.PAD_LT / PAD_RT), -1 for Escape or Start (cancel),
## -2 for nothing (a release, the other device, a stick).
func _caught(event: InputEvent, device: String) -> int:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_ESCAPE:
			return -1
		return k.keycode if device == "keys" else -2
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_START:
			return -1
		return jb.button_index if device == "pad" else -2
	var jm: InputEventJoypadMotion = event as InputEventJoypadMotion
	if jm != null and device == "pad" and jm.axis_value > STICK_DEADZONE:
		if jm.axis == JOY_AXIS_TRIGGER_LEFT:
			return ControlsModel.PAD_LT
		if jm.axis == JOY_AXIS_TRIGGER_RIGHT:
			return ControlsModel.PAD_RT
	return -2


## CTRL-02: whether the game is reading its play controls (the last few refreshes): the pad is then the
## player's bindings, otherwise the menus' keys. SCR-03: a question or screen of the menus that reads the
## controls as it waits (a yes/no dialog, the help, Keen 4-6's Paddle War) asks for the menus' keys anyway
## (the engine's shell_menu_keys), so the pad's A is Enter there whatever its buttons are bound to.
func controls_live() -> bool:
	if engine == null or vm == null or not "controls_read_vbl" in engine:
		return false
	if "shell_menu_keys" in engine and bool(engine.get("shell_menu_keys")):
		return false
	return vm.vbl_count - int(engine.get("controls_read_vbl")) <= 6


## SCR-05: a line is being typed in the game's own line input (the engine's shell_text_entry, set only with
## a player at the controls): the d-pad and the stick are sent as the pad's own codes, which the line takes
## as letters (PadTextEntry), the buttons as the menus' keys.
func text_entry() -> bool:
	return engine != null and "shell_text_entry" in engine and bool(engine.get("shell_text_entry"))


## A pad button (or a trigger, as ControlsModel.PAD_LT / PAD_RT) pressed or let go. Its press sends one code
## and its release lets go of that same code: the quicksave or quickload key (SAVE-02, while quicksave is
## on), Escape for Start, the button's own code in play, the menus' key otherwise; while a line is typed
## (SCR-05) the d-pad's own codes and the menus' keys.
func _pad(b: Variant, down: bool) -> void:
	if not down:
		if _pad_sent.has(b):
			send_key(int(_pad_sent[b]), false)
			_pad_sent.erase(b)
		return
	if _pad_sent.has(b):
		return
	var code: int = 0
	var quick: bool = options != null and bool(options.get_value("quicksave"))
	if text_entry():
		if b is String:
			code = int(ControlsModel.PAD_MOVE[b])
		elif b is int and b == JOY_BUTTON_START:
			code = 0x01
		elif b is int and int(b) >= JOY_BUTTON_DPAD_UP and int(b) <= JOY_BUTTON_DPAD_RIGHT:
			code = int(ControlsModel.PAD_CODES[b])
		else:
			code = int(PAD_MENU.get(b, 0))
	elif b is int and quick and controls != null and controls.buttons("quicksave").has(b):
		code = 0x41 if engine is VortScreens else (0x42 if engine is DreamsGame else 0x3F)    # Keen 1-3's F7, Dreams' F8, Keen 4-6's F5
	elif b is int and quick and controls != null and controls.buttons("quickload").has(b):
		code = 0x43    # F9
	elif b is int and b == JOY_BUTTON_START:
		code = 0x01
	elif b is String:
		code = int(ControlsModel.PAD_MOVE[b]) if controls_live() else int(ARROWS[b])
	elif controls_live():
		code = int(ControlsModel.PAD_CODES.get(b, 0))
	else:
		code = int(PAD_MENU.get(b, 0))
	if code != 0:
		_pad_sent[b] = code
		send_key(code, true)


## A key of the on-screen controls pressed or let go (AND-03): sent as it is, but while a line is typed
## (SCR-05) the d-pad's arrows go as the pad's d-pad codes, so a touch screen spells a name as the pad does
## (PadTextEntry); its release lets go of the code its press sent.
func _touch_key(code: int, down: bool) -> void:
	if not down:
		send_key(int(_touch_sent.get(code, code)), false)
		_touch_sent.erase(code)
		return
	var sent: int = int(TOUCH_TYPING.get(code, code)) if text_entry() else code
	_touch_sent[code] = sent
	send_key(sent, true)


## The overlay shows on a touch screen while no pad is in use (J-54: or always, the player's Show with a
## pad); hiding it lets go of whatever its fingers held.
func _update_overlay() -> void:
	if overlay == null:
		return
	var pad_in_use: bool = pad_device >= 0 and (connected_pads.call() as Array).has(pad_device)
	var show: bool = TouchOverlay.wanted(force_touch or DisplayServer.is_touchscreen_available(), pad_in_use, overlay.with_pad)
	if overlay.visible and not show:
		overlay.release_all()
	overlay.visible = show


## SHELL-04: a pad's Back or Start pressed or let go. True for the second of the two going down on the
## same pad: the hold has begun (timed in _process), and the press goes no further.
func _chord(jb: InputEventJoypadButton) -> bool:
	if jb.button_index != JOY_BUTTON_BACK and jb.button_index != JOY_BUTTON_START:
		return false
	var held: Dictionary = _chord_held.get(jb.device, {})
	_chord_held[jb.device] = held
	var other: int = JOY_BUTTON_START if jb.button_index == JOY_BUTTON_BACK else JOY_BUTTON_BACK
	if not jb.pressed:
		held.erase(jb.button_index)
		if jb.device == _chord_device:
			_chord_device = -1
			_chord_since = -1
		return false
	if held.has(jb.button_index):
		return false
	held[jb.button_index] = true
	if not held.has(other):
		return false
	_chord_device = jb.device
	_chord_since = Time.get_ticks_usec()
	_chord_done = false
	return true


## SHELL-04: the pad's buttons back to their defaults (saved), the game reading them at once, and said on
## screen: the way back for a player whose buttons no longer reach the game (Jump cleared, say).
func reset_pad_buttons() -> void:
	if controls == null:
		return
	controls.reset("pad")
	apply_setting("controls")
	show_message(RESET_TEXT)


## A short word over the game for a few seconds (the pad's reset).
func show_message(text: String) -> void:
	if _message == null:
		_message = Label.new()
		_message.name = "Message"
		_message.add_theme_font_size_override("font_size", 24)
		_message.add_theme_color_override("font_outline_color", Color.BLACK)
		_message.add_theme_constant_override("outline_size", 6)
		_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_message.offset_top = -64.0
		_message.offset_bottom = -24.0
		add_child(_message)
	_message.text = text
	_message.visible = true
	_message_until = Time.get_ticks_msec() + 3000
	ShellMessages.note(text)


func _process(_delta: float) -> void:
	_update_overlay()
	if _chord_since >= 0 and not _chord_done and Time.get_ticks_usec() - _chord_since >= RESET_HOLD_USEC:
		_chord_done = true
		reset_pad_buttons()
	if _message != null and _message.visible and Time.get_ticks_msec() >= _message_until:
		_message.visible = false
	_mutex.lock()
	var fresh: bool = _frame_new
	var idx: PackedByteArray = _frame_indices
	var pal: PackedByteArray = _frame_palette
	var list: Dictionary = _frame_list
	var text: PackedByteArray = _frame_text
	_frame_text = PackedByteArray()
	_frame_new = false
	var done: bool = _done
	var pending: Array = _audio_pending
	_audio_pending = []
	var machine_t: float = _machine_t
	_mutex.unlock()
	_feed_audio(pending, machine_t)
	if fresh and not text.is_empty():
		_text_view.show_text(text)
		_text_view.visible = true
		_view.visible = false
		if _native != null:
			_native.visible = false
		frames_shown += 1
		fresh = false
	if fresh and idx.size() == 320 * 200 and pal.size() >= 48:
		_text_view.visible = false
		_index_image.set_data(320, 200, false, Image.FORMAT_R8, idx)
		_index_tex.update(_index_image)
		_palette_image.set_data(16, 1, false, Image.FORMAT_RGB8, pal.slice(0, 48))
		_palette_tex.update(_palette_image)
		frames_shown += 1
		_backdrop.set_palette(pal)
		if _native != null:
			# the shell's views draw the game's play; the 320x200 (framed) everything else
			var native: bool = not list.is_empty()
			if native:
				_native.show_frame(engine, list, pal, machine_t, idx)
			_native.visible = native
			_view.visible = not native
		else:
			_view.visible = true    # (back from a text screen, with no native view: Keen Dreams)
	_layout_stage(_native != null and _native.visible)
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
	var galaxy: bool = galaxy_sounds != null and galaxy_sounds.available() and options != null and bool(options.get_value("galaxy_sfx"))
	# AUDIO-06, the tracks: the world map's or the level's, while the setting is on
	if galaxy_sounds != null and galaxy_sounds.available() and options != null and engine is VortScreens:
		var want: int = -1
		if bool(options.get_value("galaxy_music")):
			if bool(engine.get("shell_on_map")):
				want = 0
			elif bool(engine.get("shell_in_level")):
				want = int(engine.get("shell_level"))
		if want != _music_level:
			_music_level = want
			audio.play_music(machine_t, galaxy_sounds.music_for(game_id, want) if want >= 0 else PackedByteArray())
	for e: Array in pending:
		if e[1] == -1:
			# AUDIO-06: with Keen 4-6's effects on, the speaker is silent (its sequencer runs on)
			audio.push_speaker(e[0], 0 if galaxy else e[2])
		elif e[1] == -2:
			if galaxy and e[2] >= 1 and e[2] <= _sound_names.size():
				audio.play_sfx(e[0], GalaxySounds.writes(galaxy_sounds.sound_for(_sound_names[e[2] - 1]), e[0]))
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
	elif engine is DreamsGame:
		(engine as DreamsGame).sd_alOutHook = Callable()
		(engine as DreamsGame).RF_Shutdown()
		(engine as DreamsGame).release_links()
	elif engine != null:
		engine.set("vm", null)
		if "after_startup" in engine:
			engine.set("after_startup", Callable())    # the play button's call holds the engine itself
	engine = null
	vm = null


## The stick on one axis as the two arrows it stands for.
func _stick_axis(v: float, negative: String, positive: String) -> void:
	for pair: Array in [[negative, v <= -STICK_DEADZONE], [positive, v >= STICK_DEADZONE]]:
		if bool(pair[1]) != _pad_sent.has(pair[0]):
			_pad(pair[0], pair[1])


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
	if pad_paused:
		# any key (or a button on another pad) goes on; the key itself is not played
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed):
			_resume_from_pad()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		pad_device = event.device
	# SHELL-04: Back and Start, watched whatever else takes them; the second of the two down is kept from
	# the game (the first did its own thing already)
	var chord_second: bool = event is InputEventJoypadButton and _chord(event)
	if engine != null and "controls_capture" in engine and str(engine.get("controls_capture")) != "":
		var caught: int = _caught(event, str(engine.get("controls_capture")))
		if caught != -2:
			engine.set("controls_captured", caught)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		if not chord_second:
			_pad(jb.button_index, jb.pressed)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event
		match jm.axis:
			JOY_AXIS_LEFT_X:
				_stick_axis(jm.axis_value, "left", "right")
			JOY_AXIS_LEFT_Y:
				_stick_axis(jm.axis_value, "up", "down")
			JOY_AXIS_TRIGGER_LEFT:
				_pad(ControlsModel.PAD_LT, jm.axis_value > STICK_DEADZONE)
			JOY_AXIS_TRIGGER_RIGHT:
				_pad(ControlsModel.PAD_RT, jm.axis_value > STICK_DEADZONE)
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or k.echo:
		return
	if k.keycode == KEY_F11:
		# F11 is fullscreen everywhere: the game's own Fullscreen row moves (and applies) with it
		if k.pressed:
			if options != null:
				options.step("fullscreen", 1)
			elif get_window() != null:
				get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	var code: int = SCANCODES.get(k.keycode, 0)
	if code == 0:
		return
	send_key(code, k.pressed)
	get_viewport().set_input_as_handled()
