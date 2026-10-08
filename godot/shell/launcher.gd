# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name Launcher
extends Control
## The launcher screen (SHELL-01): one tile per game, in the series' order,
## each saying whether the game was found (and which release), found but not
## supported (and what to do), or missing (and where to put it). A line
## above the tiles counts them. The look is a first, plain one; its design
## is the user's call (the ledger's judgment queue).
##
## show_results() takes GameFinder's results; on its own the screen scans
## (Steam, GOG and the folders in `extra_folders`) once it is in the tree.

const GAMES: Array = [
	["keen1", "Commander Keen 1", "Marooned on Mars"],
	["keen2", "Commander Keen 2", "The Earth Explodes"],
	["keen3", "Commander Keen 3", "Keen Must Die!"],
	["keen4", "Commander Keen 4", "Secret of the Oracle"],
	["keen5", "Commander Keen 5", "The Armageddon Machine"],
	["keen6", "Commander Keen 6", "Aliens Ate My Baby Sitter!"],
	["kdreams", "Keen Dreams", ""],
]
const TILE_MIN: Vector2 = Vector2(200, 120)

## Folders the player chose (settings' game_folders); scanned with Steam and GOG.
var extra_folders: PackedStringArray = PackedStringArray()
## The shell's settings (SHELL-05); a test gives its own file.
var settings: Settings = null
var settings_path: String = Settings.PATH
## SHELL-07: one copy at a time. The lock holds the running copy's process id.
var lock_path: String = "user://megarocket.lock"
## Another copy holds the lock: the screen says so and waits for Enter.
var waiting_for_other: bool = false
var _wait_panel: PanelContainer = null
## Set false by a test that supplies results itself.
var scan_on_ready: bool = true
## Make each found game's title art (J-12) on a background thread.
var make_art: bool = true
var _art_thread: Thread = null
var _art_queue: Array = []
var _art_mutex: Mutex = Mutex.new()
## id -> true once the tile shows its title art
var art_shown: Dictionary = {}

var summary: Label
var grid: GridContainer
var scroll: ScrollContainer
var howto_button: Button
## The how-to page (J-12), over the tiles while open.
var howto: PanelContainer = null
## One sideways row (narrow or portrait windows).
var carousel: bool = false
## id -> the tile's PanelContainer
var tiles: Dictionary = {}
## id -> "found" | "unsupported" | "missing"
var states: Dictionary = {}
## id -> the GameFinder result shown on its tile
var found_results: Dictionary = {}
## The game being played, if any (SHELL-02: launched from a tile, back here when it ends).
var host: GameHost = null
var _page: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings = Settings.new(settings_path)
	if other_copy_running():
		_show_wait()
	extra_folders = PackedStringArray(settings.get_value("game_folders"))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page = margin
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "Megarocket"
	title.add_theme_font_size_override("font_size", 28)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_child(title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	howto_button = Button.new()
	howto_button.name = "HowTo"
	howto_button.text = "How to add games"
	howto_button.pressed.connect(show_howto)
	var add: Button = Button.new()
	add.name = "AddFolder"
	add.text = "Add a folder"
	add.pressed.connect(_pick_folder)
	top.add_child(add)
	top.add_child(howto_button)
	column.add_child(top)
	summary = Label.new()
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	grid = GridContainer.new()
	grid.name = "Tiles"
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	column.add_child(scroll)
	for g: Array in GAMES:
		var tile: PanelContainer = _make_tile(g[0], g[1], g[2])
		tiles[g[0]] = tile
		grid.add_child(tile)
	resized.connect(_layout)
	_layout()
	show_results([])
	(tiles[GAMES[0][0]] as Control).grab_focus.call_deferred()    # keyboard and pad work at once (ui_* moves between tiles)
	if not waiting_for_other:
		take_lock()
		if scan_on_ready:
			call_deferred("_scan")


func _scan() -> void:
	var finder: GameFinder = GameFinder.new()
	show_results(finder.scan_all(extra_folders))


## As many columns as fit; one tile per game whatever the width.
## Wide: as many columns as fit, scrolling down. Narrow (portrait, or under
## two tiles across): one row, scrolling sideways, following the focused tile
## (J-12's carousel).
func _layout() -> void:
	if grid == null:
		return
	var usable: float = max(size.x - 32.0, TILE_MIN.x)
	carousel = size.y > size.x or usable < 2.0 * TILE_MIN.x + 12.0
	if carousel:
		grid.columns = GAMES.size()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		grid.size_flags_horizontal = Control.SIZE_FILL
		var w: float = clampf(usable * 0.8, TILE_MIN.x, 360.0)
		for id: String in tiles:
			(tiles[id] as Control).custom_minimum_size = Vector2(w, TILE_MIN.y)
	else:
		grid.columns = clampi(int(usable / (TILE_MIN.x + 12.0)), 1, GAMES.size())
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id: String in tiles:
			(tiles[id] as Control).custom_minimum_size = TILE_MIN


func _make_tile(id: String, name_text: String, subtitle: String) -> PanelContainer:
	var tile: PanelContainer = PanelContainer.new()
	tile.name = id
	tile.custom_minimum_size = TILE_MIN
	tile.focus_mode = Control.FOCUS_ALL
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.gui_input.connect(_tile_input.bind(id))
	var box: VBoxContainer = VBoxContainer.new()
	tile.add_child(box)
	var art: TextureRect = TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(0, 110)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.visible = false
	box.add_child(art)
	var n: Label = Label.new()
	n.name = "Name"
	n.text = name_text
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", 18)
	box.add_child(n)
	var s: Label = Label.new()
	s.name = "Subtitle"
	s.text = subtitle
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(s)
	var st: Label = Label.new()
	st.name = "Status"
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(st)
	return tile


## GameFinder's results -> each tile's state and text. A supported release
## wins over an unsupported one of the same game.
func show_results(results: Array) -> void:
	var best: Dictionary = {}
	for r: Dictionary in results:
		var cur: Variant = best.get(r.id)
		if cur == null or (r.status == GameFinder.STATUS_OK and (cur as Dictionary).status != GameFinder.STATUS_OK):
			best[r.id] = r
	var found: int = 0
	for g: Array in GAMES:
		var id: String = g[0]
		var st: Label = _status_label(tiles[id])
		var r: Variant = best.get(id)
		found_results.erase(id)
		if r != null:
			found_results[id] = r
		if r == null:
			states[id] = "missing"
			st.text = "Not found. " + _looks_for(id)
		elif (r as Dictionary).status == GameFinder.STATUS_OK:
			states[id] = "found"
			found += 1
			st.text = "Found: %s\n%s" % [r.version, r.folder]
		else:
			states[id] = "unsupported"
			st.text = "Found %s, which Megarocket does not run. %s" % [r.version if r.version != "" else r.title, r.message]
	if make_art:
		_queue_art()
	summary.text = "%d of %d games found." % [found, GAMES.size()] if found > 0 else \
		"No games found yet. Each tile says what Megarocket looks for."


## What the finder looks for, short: the releases' executables and versions.
## (KnownFiles.REMEDY has the full advice, for a detail view.)
static func _looks_for(id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for s: Dictionary in KnownFiles.SETS:
		if s.id == id:
			parts.append("%s %s" % [s.exe, s.version])
	return "Looks for " + " or ".join(parts) + "."


# ---- one copy at a time (SHELL-07)

## True when the lock names a process that is still running (not this one).
func other_copy_running() -> bool:
	if not FileAccess.file_exists(lock_path):
		return false
	var pid: int = FileAccess.get_file_as_string(lock_path).strip_edges().to_int()
	return pid > 0 and pid != OS.get_process_id() and OS.is_process_running(pid)


func take_lock() -> void:
	var f: FileAccess = FileAccess.open(lock_path, FileAccess.WRITE)
	if f != null:
		f.store_string(str(OS.get_process_id()))
		f.close()


func _show_wait() -> void:
	waiting_for_other = true
	_wait_panel = PanelContainer.new()
	_wait_panel.name = "AlreadyRunning"
	_wait_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var l: Label = Label.new()
	l.text = "Megarocket is already running in another window.\nPress Enter (or A) to start this one anyway."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wait_panel.add_child(l)
	add_child.call_deferred(_wait_panel)


## Enter: start anyway (this copy takes the lock).
func start_anyway() -> void:
	if not waiting_for_other:
		return
	waiting_for_other = false
	_wait_panel.queue_free()
	_wait_panel = null
	take_lock()
	if scan_on_ready:
		_scan.call_deferred()


# ---- a folder the player chooses (SHELL-05's game_folders)

func _pick_folder() -> void:
	var fd: FileDialog = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.title = "Choose a folder with Keen games in it"
	fd.dir_selected.connect(func(dir: String) -> void:
		add_folder(dir)
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.7)


## Remembers a folder (saved at once) and scans again. False if it was known.
func add_folder(dir: String) -> bool:
	var known: Array = settings.get_value("game_folders")
	if known.has(dir):
		return false
	known.append(dir)
	settings.set_value("game_folders", known)
	settings.save()
	extra_folders = PackedStringArray(known)
	if scan_on_ready:
		_scan.call_deferred()
	return true


# ---- the how-to page (J-12)

## Where Megarocket looks and what each game needs, in plain words.
static func howto_text() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"Where Megarocket looks",
		"",
		"Steam: the Commander Keen pack (Keen 1 to 5) and Keen Dreams (the Definitive Edition's DOS/EGA folder), in every Steam library on every drive.",
		"GOG: the Keen games GOG Galaxy has installed.",
		"A folder you choose with Add a folder, and the folders inside it two levels deep; Megarocket remembers it.",
		"",
		"Megarocket only reads the games' files. It never changes or adds anything in a game's folder.",
		"",
		"What each game needs",
		""])
	for g: Array in GAMES:
		lines.append("%s: %s" % [g[1], KnownFiles.REMEDY.get(g[0], "")])
	return "\n".join(lines)


func show_howto() -> void:
	if howto != null:
		return
	howto = PanelContainer.new()
	howto.name = "HowToPage"
	howto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	howto.add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	var text: RichTextLabel = RichTextLabel.new()
	text.name = "Text"
	text.text = howto_text()
	text.fit_content = false
	text.focus_mode = Control.FOCUS_ALL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(text)
	var back: Button = Button.new()
	back.name = "Back"
	back.text = "Back"
	back.pressed.connect(close_howto)
	col.add_child(back)
	add_child(howto)
	_page.visible = false
	back.grab_focus()


func close_howto() -> void:
	if howto == null:
		return
	howto.queue_free()
	howto = null
	_page.visible = true
	howto_button.grab_focus()


func _input(event: InputEvent) -> void:
	if waiting_for_other and event.is_action_pressed("ui_accept"):
		start_anyway()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if howto != null and event.is_action_pressed("ui_cancel"):
		close_howto()
		get_viewport().set_input_as_handled()


# ---- title art (J-12): made off the main thread, shown as each is ready

func _queue_art() -> void:
	_art_mutex.lock()
	_art_queue = []
	for g: Array in GAMES:
		if states.get(g[0], "") == "found" and not art_shown.has(g[0]):
			_art_queue.append(found_results[g[0]])
	_art_mutex.unlock()
	if _art_thread == null and not _art_queue.is_empty():
		_art_thread = Thread.new()
		_art_thread.start(_art_worker)


func _art_worker() -> void:
	while true:
		_art_mutex.lock()
		var next: Variant = _art_queue.pop_front() if not _art_queue.is_empty() else null
		_art_mutex.unlock()
		if next == null:
			break
		var img: Image = TitleArt.make(next)
		if img != null:
			_show_art.call_deferred(String(next.id), img)
	_art_done.call_deferred()


func _art_done() -> void:
	if _art_thread != null:
		_art_thread.wait_to_finish()
		_art_thread = null
	_art_mutex.lock()
	var more: bool = not _art_queue.is_empty()
	_art_mutex.unlock()
	if more:
		_art_thread = Thread.new()
		_art_thread.start(_art_worker)


func _show_art(id: String, img: Image) -> void:
	var art: TextureRect = tiles[id].get_child(0).get_node("Art")
	art.texture = ImageTexture.create_from_image(img)
	art.visible = true
	art_shown[id] = true


func _exit_tree() -> void:
	# the lock goes with this copy
	if FileAccess.file_exists(lock_path) and FileAccess.get_file_as_string(lock_path).strip_edges().to_int() == OS.get_process_id():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
	_art_mutex.lock()
	_art_queue = []
	_art_mutex.unlock()
	if _art_thread != null:
		_art_thread.wait_to_finish()
		_art_thread = null


func _tile_input(event: InputEvent, id: String) -> void:
	var go: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event.is_action_pressed("ui_accept"):
		go = true    # Enter, Space, a pad's A
	if go:
		accept_event()
		launch(id)


## Plays a found game; the launcher returns when it ends. False (and the
## tile's status says why) when it can't start.
func launch(id: String) -> bool:
	if host != null or states.get(id, "") != "found":
		return false
	host = GameHost.new()
	add_child(host)
	if not host.start(found_results[id]):
		_status_label(tiles[id]).text = "Can't start: " + host.error
		host.queue_free()
		host = null
		return false
	_page.visible = false
	host.finished.connect(_on_game_finished.bind(id))
	return true


func _on_game_finished(message: String, id: String) -> void:
	host.queue_free()
	host = null
	_page.visible = true
	if message != "":
		_status_label(tiles[id]).text = "The game stopped: " + message
	(tiles[id] as Control).grab_focus()


func _status_label(tile: PanelContainer) -> Label:
	return tile.get_child(0).get_node("Status")
