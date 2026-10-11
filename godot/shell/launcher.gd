# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name Launcher
extends Control
## The launcher screen (SHELL-01): one tile per game, in the series' order,
## each saying whether the game was found (and which release), found but not
## supported (and what to do), or missing (and where to put it). A line
## above the tiles counts them. The look (J-12): Megarocket's own, rebuilt
## fresh (MegaTheme): deep space with stars, the rocket and wordmark, each
## game's tile framed in its accent colour, Megarocket's pixel font, at a
## whole-number pixel scale; the selected game's details on a line below.
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
## A tile's least size in logical pixels (times the pixel scale).
const TILE_LOGICAL: Vector2 = Vector2(112, 104)
var TILE_MIN: Vector2 = Vector2(224, 208)

## Folders the player chose (settings' game_folders); scanned with Steam and GOG.
var extra_folders: PackedStringArray = PackedStringArray()
## The shell's settings (SHELL-05); a test gives its own file.
var settings: Settings = null
var settings_path: String = Settings.default_path()
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
var quit_button: Button
## The quit box over the launcher while it asks (the Quit button, Escape).
var quit_box: Control = null
## SHELL-09: where the log is, so a report can include it.
var log_label: Label
## J-12's look: the backdrop, the mark, the pixel scale it is all drawn at, and the selected game's
## details and the controls on the lines under the tiles.
var starfield: Starfield = null
var brand: BrandHeader = null
var pixel: int = 0
var details: Label = null
var hints: Label = null
var selected: String = ""
## AND-02: where imported games live (the importer's games_root), and the import under way.
var imported_games_root: String = OS.get_user_data_dir().path_join("games")
var import_page: PanelContainer = null
var import_results: Array = []
var _import_thread: Thread = null
var _import_label: Label = null
## SHELL-10: the export button and page, and the export under way.
var export_button: Button = null
var export_page: PanelContainer = null
var export_results: Array = []
var export_progress: Dictionary = {}    # game id -> files written so far (the most seen)
var _export_thread: Thread = null
var _export_label: Label = null
## The how-to page (J-12), over the tiles while open.
var howto: PanelContainer = null
## SHELL-16: the folder chooser while it is up, and the control the keys go back to when it closes.
var folder_chooser: FolderChooser = null
var _chooser_return: Control = null
## The finder the scans use (a new one if null); a test gives one whose Steam and GOG readers find nothing.
var finder: GameFinder = null
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
## V15-03: Keen Maker, opened from its button in this window (the launcher steps aside as for a game), and
## the button the focus goes back to when it closes.
var maker: MakerScreen = null
var maker_button: Button = null


## The UI's scale for a screen: phones and tablets by density (Android's
## 160 dpi is 1), never below 1; desktops 1.
static func scale_for(dpi: int, mobile: bool) -> float:
	if not mobile or dpi <= 0:
		return 1.0
	return maxf(1.0, dpi / 160.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree() and get_window() != null:
		get_window().content_scale_factor = scale_for(DisplayServer.screen_get_dpi(), OS.has_feature("mobile"))
	# the log's first line: what is running where (SHELL-09; AND-01 reads it)
	ShellMessages.note("Megarocket %s on %s (%s), sound chip %s" % [ProjectSettings.get_setting("application/config/version", ""),
		OS.get_name(), RenderingServer.get_current_rendering_method(), "ready" if ClassDB.class_exists("D2Opl") else "missing"])
	settings = Settings.new(settings_path)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST    # the pixel font and the frames stay hard
	starfield = Starfield.new()
	add_child(starfield)
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
	brand = BrandHeader.new()
	brand.name = "Brand"
	var top: HFlowContainer = HFlowContainer.new()    # wraps on a narrow window
	top.add_child(brand)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	howto_button = Button.new()
	howto_button.name = "HowTo"
	howto_button.text = "How to add games"
	howto_button.pressed.connect(show_howto)
	var add: Button = Button.new()
	add.name = "AddFolder"
	add.text = "Import games" if OS.has_feature("android") else "Add a folder"
	add.pressed.connect(_pick_folder)
	top.add_child(add)
	maker_button = Button.new()
	maker_button.name = "KeenMaker"
	maker_button.text = "Keen Maker"
	maker_button.pressed.connect(open_maker)
	top.add_child(maker_button)
	# SHELL-10: the games found here, ready for the Android app (not on Android itself)
	export_button = Button.new()
	export_button.name = "ExportAndroid"
	export_button.text = "Export for Android"
	export_button.disabled = true
	export_button.visible = not OS.has_feature("android")
	export_button.pressed.connect(show_export)
	top.add_child(export_button)
	top.add_child(howto_button)
	# a way out in fullscreen too (Escape on this screen asks the same); Android leaves by Back
	quit_button = Button.new()
	quit_button.name = "Quit"
	quit_button.text = "Quit"
	quit_button.visible = not OS.has_feature("android")
	quit_button.pressed.connect(confirm_quit)
	top.add_child(quit_button)
	column.add_child(top)
	summary = Label.new()
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", MegaTheme.ega(11))
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
	details = Label.new()
	details.name = "Details"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(0, 1)
	column.add_child(details)
	hints = Label.new()
	hints.name = "Hints"
	hints.text = "Move: arrows / stick   Play: Enter / A   Back: Esc / B"
	hints.add_theme_color_override("font_color", MegaTheme.ega(7))
	column.add_child(hints)
	log_label = Label.new()
	log_label.name = "LogPath"
	log_label.text = "Log: " + ShellMessages.log_path()
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_label.clip_text = true
	log_label.add_theme_color_override("font_color", MegaTheme.ega(8))
	column.add_child(log_label)
	for g: Array in GAMES:
		var tile: PanelContainer = _make_tile(g[0], g[1], g[2])
		tiles[g[0]] = tile
		grid.add_child(tile)
	resized.connect(_layout)
	_apply_pixel_scale()
	_layout()
	show_results([])
	(tiles[GAMES[0][0]] as Control).grab_focus.call_deferred()    # keyboard and pad work at once (ui_* moves between tiles)
	if not waiting_for_other:
		take_lock()
		if scan_on_ready:
			call_deferred("_scan")


func _scan() -> void:
	var f: GameFinder = finder if finder != null else GameFinder.new()
	show_results(f.scan_all(scan_roots()))


## The folders scanned besides Steam and GOG: the player's own, and the games
## imported into the app's storage (AND-02) once there are any.
func scan_roots() -> PackedStringArray:
	var roots: PackedStringArray = PackedStringArray(extra_folders)
	if DirAccess.dir_exists_absolute(imported_games_root):
		roots.append(imported_games_root)
	return roots


## J-12's look at the pixel scale this window size takes: the theme, the backdrop, the mark and the
## tiles' frames are made again whenever it changes.
func _apply_pixel_scale() -> void:
	var s: int = MegaTheme.pixel_scale(size if size.x > 0 else Vector2(1280, 720))
	if s == pixel:
		return
	pixel = s
	theme = MegaTheme.build(s)
	TILE_MIN = TILE_LOGICAL * s
	for id: String in tiles:
		(tiles[id].get_child(0).get_node("Art") as Control).custom_minimum_size = Vector2(0, 55 * s)
	if starfield != null:
		starfield.pixel = s
	if brand != null:
		brand.pixel = s
	for id: String in tiles:
		_style_tile(id)


## A tile's frame and name. The selected tile is the one in yellow (the focus colour of every button
## and box in Megarocket), lit; the others keep their game's colour, dimmed (the user, 2026-10-10: with
## every frame its own colour and the selected one only a little brighter, which game was selected was
## not clear). A missing game's tile is grey.
func _style_tile(id: String) -> void:
	var tile: PanelContainer = tiles[id]
	var s: int = maxi(pixel, 1)
	var c: Color = MegaTheme.accent(id)
	var present: bool = states.get(id, "missing") != "missing"
	var on: bool = tile.has_focus()
	var frame: Color = MegaTheme.ega(14) if on else (MegaTheme.dark_of(c).lerp(c, 0.5) if present else MegaTheme.ega(8))
	tile.add_theme_stylebox_override("panel", MegaTheme.bevel(frame, s, Color8(0, 0, 12) if present else MegaTheme.SPACE))
	tile.get_child(0).modulate = Color.WHITE if on else Color(0.62, 0.62, 0.62)
	var n: Label = tile.get_child(0).get_node("Name")
	n.add_theme_color_override("font_color", (MegaTheme.ega(15) if on else c) if present else MegaTheme.ega(7))
	(tile.get_child(0).get_node("Subtitle") as Label).add_theme_color_override("font_color", MegaTheme.ega(7))
	var st: Label = tile.get_child(0).get_node("Status")
	var brief: Label = tile.get_child(0).get_node("Brief")
	var found: bool = states.get(id, "") == "found"
	# a found game's status is one short line; a game stopped by an error shows it whole
	var short: bool = found and st.text.begins_with("Ready")
	st.visible = short or (found and not short)
	st.autowrap_mode = TextServer.AUTOWRAP_OFF if short else TextServer.AUTOWRAP_WORD_SMART
	st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	st.clip_text = short
	st.add_theme_color_override("font_color", MegaTheme.ega(10) if short else MegaTheme.ega(12))
	brief.visible = not found
	brief.text = "Not found" if states.get(id, "missing") == "missing" else "Can't run this release"
	brief.add_theme_color_override("font_color", MegaTheme.ega(7) if states.get(id, "missing") == "missing" else MegaTheme.ega(14))


## The selected game's details under the tiles: its name, then where it was found and which release,
## or what to do to add it.
func _select(id: String) -> void:
	selected = id
	for t: String in tiles:
		_style_tile(t)
	if details == null:
		return
	var r: Variant = found_results.get(id)
	var line: String = _title_of(id)
	if r != null and states.get(id, "") == "found":
		line += " · " + str(r.version) + " · " + str(r.folder)
	else:
		line += " · " + _status_label(tiles[id]).text.replace("\n", " ")
	details.text = line


## Every game on screen at once where it fits. Wide: the grid whose tiles are largest with all seven
## on screen (the user, 2026-10-10: the tiles a bit smaller; at 1600x900 the old layout gave two huge
## tiles in a sideways row), the title art at its 1.6:1 and the three lines under it. Narrow (portrait,
## or too short for even the smallest grid, as a phone held sideways): one row, scrolling sideways,
## following the focused tile (J-12's carousel).
func _layout() -> void:
	if grid == null:
		return
	_apply_pixel_scale()
	var usable: float = max(size.x - 32.0, TILE_MIN.x)
	# the rest of the page: the header row and four lines (the count, the details, the controls, the log)
	var line: float = MegaTheme.line_size() * maxi(pixel, 1)
	var others: float = (brand.get_combined_minimum_size().y if brand != null else line) + 12.0 + 4.0 * (line + 12.0)
	var room_h: float = size.y - 32.0 - others - 16.0
	# a tile's height without its art: the three lines and the frame
	var text_h: float = 3.0 * (line + pixel) + 14.0 * pixel + 12.0
	var best_cols: int = 0
	var best_art: float = 0.0
	if size.y <= size.x:
		for cols: int in range(2, GAMES.size() + 1):
			var rows: int = ceili(GAMES.size() / float(cols))
			var by_w: float = ((usable - 12.0 * (cols - 1)) / cols - 14.0 * pixel) / 1.6
			var by_h: float = (room_h - 12.0 * (rows - 1)) / rows - text_h
			var art: float = minf(by_w, by_h)
			# (a tile no narrower than its smallest, for the name: the art is centred in it)
			var w: float = maxf(TILE_MIN.x, art * 1.6 + 14.0 * pixel)
			if art >= 55.0 * pixel and cols * w + 12.0 * (cols - 1) <= usable and art > best_art + 0.5:
				best_cols = cols
				best_art = art
	carousel = best_cols == 0
	if carousel:
		grid.columns = GAMES.size()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		grid.size_flags_horizontal = Control.SIZE_FILL
		# the tiles fill the height left them, the title art taking what the three lines leave
		var h: float = maxf(TILE_MIN.y, room_h)
		var art_h: float = maxf(55.0 * pixel, h - text_h)
		# a phone held upright: one tile nearly the width; a wide window: a third of it, three tiles and
		# the edge of a fourth in view (the user, 2026-10-10: two huge tiles were too big)
		var share: float = 0.85 if size.y > size.x else 1.0 / 3.2
		var w: float = clampf(minf(usable * share, art_h * 1.6 + 14.0 * pixel), TILE_MIN.x, usable)
		# a tall window (portrait) needs no taller art than the width allows: the tile's height follows
		art_h = minf(art_h, (w - 14.0 * pixel) / 1.6)
		h = maxf(TILE_MIN.y, art_h + text_h)
		for id: String in tiles:
			(tiles[id] as Control).custom_minimum_size = Vector2(w, h)
			(tiles[id].get_child(0).get_node("Art") as Control).custom_minimum_size = Vector2(0, art_h)
	else:
		grid.columns = best_cols
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		# the grid as wide as its tiles, centred (the tiles don't stretch past their art)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var art_h: float = floorf(best_art)
		for id: String in tiles:
			(tiles[id] as Control).custom_minimum_size = Vector2(floorf(maxf(TILE_MIN.x, art_h * 1.6 + 14.0 * pixel)), art_h + text_h)
			(tiles[id].get_child(0).get_node("Art") as Control).custom_minimum_size = Vector2(0, art_h)


func _make_tile(id: String, name_text: String, subtitle: String) -> PanelContainer:
	var tile: PanelContainer = PanelContainer.new()
	tile.name = id
	tile.custom_minimum_size = TILE_MIN
	tile.focus_mode = Control.FOCUS_ALL
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.gui_input.connect(_tile_input.bind(id))
	tile.focus_entered.connect(_select.bind(id))
	tile.focus_exited.connect(_style_tile.bind(id))
	var box: VBoxContainer = VBoxContainer.new()
	tile.add_child(box)
	var art: TextureRect = TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(0, 110)    # (55 logical pixels: _apply_pixel_scale)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR    # a title screen shrunk to a tile reads better smoothed
	art.visible = false
	box.add_child(art)
	var n: Label = Label.new()
	n.name = "Name"
	n.text = name_text
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	box.add_child(n)
	var s: Label = Label.new()
	s.name = "Subtitle"
	s.text = subtitle
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.clip_text = true
	box.add_child(s)
	var st: Label = Label.new()
	st.name = "Status"
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(st)
	# a missing or unrunnable game's tile says so in two words; its full message (Status, kept for
	# the details line and the message rule) shows on the details line when the tile is selected
	var brief: Label = Label.new()
	brief.name = "Brief"
	brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brief.clip_text = true
	brief.visible = false
	box.add_child(brief)
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
			st.text = ShellMessages.missing(_looks_for(id))
		elif (r as Dictionary).status == GameFinder.STATUS_OK:
			states[id] = "found"
			found += 1
			st.text = "Ready · %s" % r.version    # the folder is on the details line when selected
		else:
			states[id] = "unsupported"
			st.text = ShellMessages.not_run(r.version if r.version != "" else r.title, r.message)
	if make_art:
		_queue_art()
	summary.text = "%d of %d games found." % [found, GAMES.size()] if found > 0 else \
		"No games found yet. Each tile says what Megarocket looks for."
	if settings != null and settings.error != "":
		summary.text += "\n" + settings.error
	ShellMessages.note(summary.text)
	if export_button != null:
		export_button.disabled = not GameExporter.can_export(found_results.values())
	for g: Array in GAMES:
		_style_tile(g[0])
	if selected != "":
		_select(selected)


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
## Android runs one copy of an app by itself (and cannot ask about another
## app's process), so there is nothing to check there.
func other_copy_running() -> bool:
	if OS.has_feature("android") or not FileAccess.file_exists(lock_path):
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
	l.text = ShellMessages.already_running()
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

## Add a folder: Megarocket's own folder chooser (SHELL-16), starting at the folder added last (or the
## home folder); Android keeps the system's picker (AND-02).
func _pick_folder() -> void:
	if OS.has_feature("android"):
		var fd: FileDialog = FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.title = "Choose a folder with Keen games in it"
		fd.use_native_dialog = true    # the system's picker (AND-02)
		fd.dir_selected.connect(func(dir: String) -> void:
			ShellMessages.note("Folder chosen: %s" % dir)
			if dir.begins_with("content://") and AndroidSaf.available():
				import_games(GameImporter.SafSource.new(dir))    # Android: read through the picker's grant, copied in
			else:
				add_folder(dir)
			fd.queue_free())
		fd.canceled.connect(fd.queue_free)
		add_child(fd)
		fd.popup_centered_ratio(0.7)
		return
	var fc: FolderChooser = FolderChooser.new()    # (its title and button say Add this folder)
	fc.start_dir = extra_folders[extra_folders.size() - 1] if not extra_folders.is_empty() else ""
	open_chooser(fc)
	fc.chosen.connect(func(dir: String) -> void:
		close_chooser()
		add_folder(dir))


## SHELL-16: Megarocket's folder chooser `fc` (set up, not yet shown) over the launcher or the export page,
## framed in its look; the keys and the pad stay in it while it is up, and come back to the button that
## opened it.
func open_chooser(fc: FolderChooser) -> void:
	close_chooser()
	fc.canceled.connect(close_chooser)
	_chooser_return = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for p: Control in [_page, export_page]:
		if p != null:
			p.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	folder_chooser = fc
	add_child(fc)


func close_chooser() -> void:
	if folder_chooser == null:
		return
	folder_chooser.queue_free()
	folder_chooser = null
	for p: Control in [_page, export_page]:
		if p != null:
			p.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if is_instance_valid(_chooser_return) and _chooser_return.is_visible_in_tree():
		_chooser_return.grab_focus()
	_chooser_return = null


## Remembers a folder (saved at once) and scans again. False if it was known.
func add_folder(dir: String) -> bool:
	var known: Array = settings.get_value("game_folders")
	if known.has(dir):
		return false
	known.append(dir)
	settings.set_value("game_folders", known)
	if not settings.save():
		summary.text = ShellMessages.settings_not_saved(settings.path.get_file())
	extra_folders = PackedStringArray(known)
	if scan_on_ready:
		_scan.call_deferred()
	return true


# ---- importing games into the app's storage (AND-02)

## Copies the games a source holds into the app's storage on a thread, with a
## page showing each file as it comes and then each game's result; Done (or
## Enter, or A) closes it and the tiles are scanned again.
func import_games(source: Object) -> void:
	if _import_thread != null:
		return
	import_results = []
	import_page = PanelContainer.new()
	import_page.name = "ImportPage"
	import_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	import_page.add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	_import_label = Label.new()
	_import_label.name = "Progress"
	_import_label.text = "Looking at the folder..."
	_import_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_import_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_import_label)
	add_child(import_page)
	_page.visible = false
	var importer: GameImporter = GameImporter.new()
	importer.games_root = imported_games_root
	importer.progress = func(what: String, done: int, total: int) -> void:
		_set_import_text.call_deferred("Copying %d of %d: %s" % [done, total, what])
	_import_thread = Thread.new()
	_import_thread.start(func() -> void:
		var results: Array = importer.import_from(source)
		_import_done.call_deferred(results))


func _set_import_text(text: String) -> void:
	if _import_label != null:
		_import_label.text = text


func _import_done(results: Array) -> void:
	if _import_thread != null:
		_import_thread.wait_to_finish()
		_import_thread = null
	import_results = results
	var lines: PackedStringArray = PackedStringArray()
	for r: Dictionary in results:
		lines.append(("Imported: " if r.ok else "Not imported: ") + String(r.message))
		ShellMessages.note(lines[lines.size() - 1])
	_set_import_text("\n\n".join(lines))
	var done: Button = Button.new()
	done.name = "Done"
	done.text = "Done"
	done.pressed.connect(close_import)
	_import_label.get_parent().add_child(done)
	done.grab_focus()


func close_import() -> void:
	if import_page == null or _import_thread != null:
		return
	import_page.queue_free()
	import_page = null
	_import_label = null
	_page.visible = true
	if scan_on_ready:
		_scan.call_deferred()


# ---- export for Android (SHELL-10)

## The export page: where to (a folder, or one ZIP), then each game as it is
## written and its result.
func show_export() -> void:
	if export_page != null or not GameExporter.can_export(found_results.values()):
		return
	export_page = PanelContainer.new()
	export_page.name = "ExportPage"
	export_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	export_page.add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	_export_label = Label.new()
	_export_label.name = "Progress"
	_export_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var n: int = GameExporter.exportable(found_results.values()).size()
	_export_label.text = ("Export the %d game%s found here for Megarocket on Android: their files go into a folder named \"%s\" " +
		"(or one ZIP), with a note saying what to do on the phone. Your games' own folders are only read.") % [n, "" if n == 1 else "s", GameExporter.FOLDER]
	col.add_child(_export_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Choices"
	for spec: Array in [["ToFolder", "To a folder", false], ["AsZip", "As a ZIP", true]]:
		var b: Button = Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.pressed.connect(_pick_export_target.bind(spec[2]))
		row.add_child(b)
	var back: Button = Button.new()
	back.name = "Back"
	back.text = "Back"
	back.pressed.connect(close_export)
	row.add_child(back)
	col.add_child(row)
	add_child(export_page)
	_page.visible = false
	(row.get_child(0) as Button).grab_focus()


## Where the export goes, in Megarocket's folder chooser (SHELL-16): the folder the "Megarocket Games"
## folder goes into, or the one the ZIP is saved in under its own name (the box says when one is already
## there and would be replaced).
func _pick_export_target(as_zip: bool) -> void:
	var zip_name: String = GameExporter.FOLDER + ".zip"
	var fc: FolderChooser = FolderChooser.new()
	fc.look_for_games = false
	if as_zip:
		fc.title_text = "Where to save %s" % zip_name
		fc.accept_text = "Save the ZIP here"
		fc.file_name = zip_name
	else:
		fc.title_text = "Where to put the \"%s\" folder" % GameExporter.FOLDER
		fc.accept_text = "Export here"
		fc.note_text = "The \"%s\" folder goes inside the folder shown." % GameExporter.FOLDER
	fc.start_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	open_chooser(fc)
	fc.chosen.connect(func(dir: String) -> void:
		close_chooser()
		export_games(dir.path_join(zip_name) if as_zip else dir, as_zip))


## Writes the export (into `target`, or as the ZIP `target`) on a thread.
func export_games(target: String, as_zip: bool) -> void:
	if export_page == null:
		show_export()
	if export_page == null or _export_thread != null:
		return
	var choices: Node = export_page.find_child("Choices", true, false)
	if choices != null:
		choices.queue_free()
	export_results = []
	export_progress = {}
	_export_label.text = "Exporting..."
	var games: Array = found_results.values()
	_export_thread = Thread.new()
	_export_thread.start(func() -> void:
		var ex: GameExporter = GameExporter.new()
		var progress: Callable = func(id: String, done: int, total: int) -> void:
			_export_step.call_deferred(id, done, total)
		var results: Array = ex.export_zip(games, target, progress) if as_zip else ex.export_folder(games, target, progress)
		_export_done.call_deferred(results, ex.error, target))


func _export_step(id: String, done: int, total: int) -> void:
	export_progress[id] = maxi(int(export_progress.get(id, 0)), done)
	if _export_label != null:
		_export_label.text = "%s: %d of %d files" % [_title_of(id), done, total]


func _export_done(results: Array, error: String, target: String) -> void:
	if _export_thread != null:
		_export_thread.wait_to_finish()
		_export_thread = null
	export_results = results
	var lines: PackedStringArray = PackedStringArray()
	if error != "":
		lines.append(error)
	for r: Dictionary in results:
		lines.append(("Exported: " if r.ok else "Not exported: ") + String(r.message))
	if error == "" and not results.is_empty():
		lines.append(ShellMessages.say("The export is in %s" % target, "Copy it to the phone, then choose Import games there and pick it."))
	for l: String in lines:
		ShellMessages.note(l)
	_export_label.text = "\n\n".join(lines)
	var done: Button = Button.new()
	done.name = "Done"
	done.text = "Done"
	done.pressed.connect(close_export)
	_export_label.get_parent().add_child(done)
	done.grab_focus()


func close_export() -> void:
	if export_page == null or _export_thread != null:
		return
	export_page.queue_free()
	export_page = null
	_export_label = null
	_page.visible = true
	if export_button != null:
		export_button.grab_focus()


# ---- the how-to page (J-12)

## Where Megarocket looks and what each game needs, in plain words.
static func howto_text() -> String:
	if ShellMessages.android():
		return "\n".join(PackedStringArray([
			"Bringing games to the phone",
			"",
			"Copy a game's folder to the phone (or a Megarocket export made on a computer: its folder or ZIP), then press Import games and pick that folder. Android asks once to let Megarocket read it.",
			"Megarocket copies the game's files into its own storage, checks each one, and says what came in. The copies on the phone are only read.",
			"",
			"What each game needs",
			""]) + _remedies())
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
	lines.append_array(_remedies())
	return "\n".join(lines)


static func _remedies() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for g: Array in GAMES:
		out.append("%s: %s" % [g[1], KnownFiles.REMEDY.get(g[0], "")])
	return out


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
	# SHELL-15 (the user, 2026-10-10: on the launcher only the sticks did anything): Godot 4.7's built-in
	# ui_accept holds Enter and Space only and ui_cancel Escape only (the d-pad and left stick are in
	# ui_left..ui_down, so they moved the focus), so a controller's A and Start press the focused control
	# as Enter does and B goes back as Escape does: the same action events, sent through Input, which
	# delivers them later in the same flush (after this event, never nested in its dispatch). Not in a
	# game (the host takes the controller there) and not where the button is already in the action (no
	# double press under a Godot that adds them; upstream issue godotengine/godot#75225, open since 4.0).
	# (Keen Maker opened from here gets this too; its scene run on its own does the same itself.)
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	if not _in_game() and jb != null:
		var action: String = ""
		if (jb.button_index == JOY_BUTTON_A or jb.button_index == JOY_BUTTON_START) and not jb.is_action("ui_accept"):
			action = "ui_accept"
		elif jb.button_index == JOY_BUTTON_B and not jb.is_action("ui_cancel"):
			action = "ui_cancel"
		if action != "":
			var ac: InputEventAction = InputEventAction.new()
			ac.action = action
			ac.pressed = jb.pressed
			ac.device = jb.device
			Input.parse_input_event(ac)
			get_viewport().set_input_as_handled()
			return
	if waiting_for_other and event.is_action_pressed("ui_accept"):
		start_anyway()
		get_viewport().set_input_as_handled()
	# F11: fullscreen on or off, everywhere (a game's host takes it in a game)
	var k: InputEventKey = event as InputEventKey
	if not _in_game() and k != null and k.pressed and not k.echo and k.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if host == null and maker == null and event.is_action_pressed("ui_cancel"):
		if not close_page() and not OS.has_feature("android"):
			confirm_quit()    # Escape on the launcher itself: the way out, asked first
		get_viewport().set_input_as_handled()


## F11 on the launcher: the window fullscreen or not, kept as the shell's setting.
func toggle_fullscreen() -> void:
	var full: bool = get_window().mode != Window.MODE_FULLSCREEN
	get_window().mode = Window.MODE_FULLSCREEN if full else Window.MODE_WINDOWED
	if settings != null and settings.set_value("fullscreen", full):
		settings.save()


## Quit, asked first (the Quit button, Escape on the launcher): a framed box in Megarocket's own look,
## as the launcher's pages are (the user, 2026-10-10: the system's pop-up had no frame and its text ran
## to its edges), over the launcher dimmed. Stay is chosen first; Escape stays too.
func confirm_quit() -> void:
	if quit_box != null:
		return
	var s: int = maxi(pixel, 1)
	quit_box = ColorRect.new()
	quit_box.name = "QuitBox"
	(quit_box as ColorRect).color = Color(0, 0, 0, 0.6)
	quit_box.mouse_filter = Control.MOUSE_FILTER_STOP
	quit_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_box.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10 * s)
	panel.add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10 * s)
	m.add_child(col)
	var q: Label = Label.new()
	q.name = "Question"
	q.text = "Quit Megarocket?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8 * s)
	col.add_child(row)
	var quit: Button = Button.new()
	quit.name = "Quit"
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	row.add_child(quit)
	var stay: Button = Button.new()
	stay.name = "Stay"
	stay.text = "Stay"
	stay.pressed.connect(close_quit)
	row.add_child(stay)
	# the two buttons the same width, and focus kept between them
	var w: float = maxf(quit.get_combined_minimum_size().x, stay.get_combined_minimum_size().x) + 8.0 * s
	for b: Button in [quit, stay]:
		b.custom_minimum_size.x = w
	add_child(quit_box)
	# the keys and the pad move between Quit and Stay only (the user, 2026-10-10: Left left the box for the
	# tiles behind it, the mouse was needed): each the other's neighbour every way, and nothing behind the
	# box takes the focus while it is up
	for b: Button in [quit, stay]:
		var other: NodePath = (stay if b == quit else quit).get_path()
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()
		b.focus_next = other
		b.focus_previous = other
	quit.focus_neighbor_left = quit.get_path()
	quit.focus_neighbor_right = stay.get_path()
	stay.focus_neighbor_left = quit.get_path()
	stay.focus_neighbor_right = stay.get_path()
	_page.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	stay.grab_focus()


func close_quit() -> void:
	if quit_box == null:
		return
	quit_box.queue_free()
	quit_box = null
	_page.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if quit_button != null and quit_button.visible:
		quit_button.grab_focus()


## AND-04: Android's Back is Escape. In a game it goes to the game as the
## Escape key (which leaves through the game's own menus); on a launcher page
## it closes the page; on the launcher itself the app steps aside (to the
## background, as Android apps do), never quitting outside a quit path.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func back() -> String:
	var did: String = ""
	if host != null:
		host.send_key(0x01, true)
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if host != null:
				host.send_key(0x01, false))
		did = "Escape to the game"
	elif maker != null:
		maker.back()
		did = "Keen Maker: back"
	elif close_page():
		did = "page closed"
	else:
		did = "to the background"
		if OS.has_feature("android") and Engine.has_singleton("AndroidRuntime"):
			Engine.get_singleton("AndroidRuntime").getActivity().moveTaskToBack(true)
	ShellMessages.note("Back: " + did)
	return did


## Closes whichever launcher page is open (the folder chooser, the quit box, how-to, import, export).
## False if none.
func close_page() -> bool:
	if folder_chooser != null:
		close_chooser()
		return true
	if quit_box != null:
		close_quit()
		return true
	if howto != null:
		close_howto()
		return true
	if import_page != null and _import_thread == null:
		close_import()
		return true
	if export_page != null and _export_thread == null:
		close_export()
		return true
	return false


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
	if _import_thread != null:
		_import_thread.wait_to_finish()
		_import_thread = null
	if _export_thread != null:
		_export_thread.wait_to_finish()
		_export_thread = null


## Whether a game is being played (the launcher's or one Keen Maker started): the host has the controller.
func _in_game() -> bool:
	return host != null or (maker != null and maker.host != null)


## V15-03: Keen Maker in this window, with the games found here; the launcher comes back when it closes,
## the Keen Maker button focused.
func open_maker() -> void:
	if maker != null or host != null:
		return
	maker = MakerScreen.new()
	maker.name = "Maker"
	for id: String in found_results:
		if states.get(id, "") == "found" and MakerModel.ENGINES.has(id):
			maker.found[id] = found_results[id]
	maker.closed.connect(close_maker)
	_page.visible = false
	starfield.visible = false
	add_child(maker)
	ShellMessages.note("Keen Maker opened (%d games)" % maker.found.size())


func close_maker() -> void:
	if maker == null:
		return
	maker.queue_free()
	maker = null
	_page.visible = true
	starfield.visible = true
	maker_button.grab_focus()


func _tile_input(event: InputEvent, id: String) -> void:
	var go: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event.is_action_pressed("ui_accept"):
		go = true    # Enter, Space; a controller's A and Start (_input makes them this action)
	if go:
		accept_event()
		launch(id)


## Plays a found game; the launcher returns when it ends. False (and the
## tile's status says why) when it can't start.
func launch(id: String) -> bool:
	if host != null or states.get(id, "") != "found":
		return false
	host = GameHost.new()
	host.settings_path = settings_path
	for g: String in ["keen4", "keen5"]:
		if states.get(g, "") == "found":
			host.galaxy_folders[g] = str(found_results[g].folder)    # AUDIO-06: their effects under Keen 1-3
	add_child(host)
	if not host.start(found_results[id]):
		_status_label(tiles[id]).text = host.error
		host.queue_free()
		host = null
		return false
	_page.visible = false
	starfield.visible = false
	host.finished.connect(_on_game_finished.bind(id))
	ShellMessages.note("Started %s (%s)" % [_title_of(id), found_results[id].get("version", "")])
	return true


func _on_game_finished(message: String, id: String) -> void:
	host.queue_free()
	host = null
	_page.visible = true
	starfield.visible = true
	if message != "":
		_status_label(tiles[id]).text = ShellMessages.game_stopped(_title_of(id), message)
	(tiles[id] as Control).grab_focus()


static func _title_of(id: String) -> String:
	for g: Array in GAMES:
		if g[0] == id:
			return g[1]
	return id


func _status_label(tile: PanelContainer) -> Label:
	return tile.get_child(0).get_node("Status")
