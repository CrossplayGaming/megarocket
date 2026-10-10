# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerScreen
extends Control
## MAKER-03: the level maker's first screen, a working preview (its look is the user's to decide: v1.5's
## Keen Maker, original art in the Keen style). The games the player owns (Keen 1-6, found as the
## launcher finds them); a level of the chosen game, shown with the game's own tiles; a palette of the
## plane being edited; Keen's start; undo and redo; Play (straight into the level with the edits, as
## MAKER-02); Save into Megarocket's own folder (user://maker/<game>, never the game's).
## Keys: Ctrl+Z / Ctrl+Y undo and redo, Ctrl+S save, F5 play, the arrows scroll, the wheel zooms; in the
## level the left button paints, the right picks a cell's value, the middle drags.

var model: MakerModel = MakerModel.new()
var tiles: MakerTiles = MakerTiles.new()
var found: Array = []                 # GameFinder results for Keen 1-6
var view: MakerView = null
var palette: MakerPalette = null
var host: GameHost = null
## Extra folders to look in (the launcher's, and --game_data=<folder> on the command line)
var roots: PackedStringArray = PackedStringArray()

var _ui: Control = null
var _games: OptionButton = null
var _levels: OptionButton = null
var _planes: OptionButton = null
var _value: SpinBox = null
var _status: Label = null
var _undo_b: Button = null
var _redo_b: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MegaTheme.build(maxi(1, MegaTheme.pixel_scale(get_viewport_rect().size) - 1))    # a tool: more room for the level
	var bg: ColorRect = ColorRect.new()
	bg.color = MegaTheme.SPACE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_ui = VBoxContainer.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var bar: HBoxContainer = HBoxContainer.new()
	_ui.add_child(bar)
	var title: Label = Label.new()
	title.text = "KEEN MAKER (preview)"
	title.add_theme_color_override("font_color", MegaTheme.ega(14))
	bar.add_child(title)
	_games = OptionButton.new()
	_games.item_selected.connect(_on_game)
	bar.add_child(_games)
	_levels = OptionButton.new()
	_levels.item_selected.connect(_on_level)
	bar.add_child(_levels)
	_planes = OptionButton.new()
	_planes.item_selected.connect(_on_plane)
	bar.add_child(_planes)
	for o: OptionButton in [_games, _levels, _planes]:
		o.focus_mode = Control.FOCUS_NONE
	_levels.clip_text = true    # Keen 4-6's names are long
	_levels.custom_minimum_size = Vector2(get_theme_default_font_size() * 14, 0)
	var tools: HBoxContainer = HBoxContainer.new()
	_ui.add_child(tools)
	_button(tools, "Keen start", _on_start_tool)
	_undo_b = _button(tools, "Undo", func() -> void: _do(model.undo()))
	_redo_b = _button(tools, "Redo", func() -> void: _do(model.redo()))
	_button(tools, "Save", _on_save)
	_button(tools, "Play (F5)", _on_play)
	_button(tools, "Quit", func() -> void: get_tree().quit())
	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ui.add_child(split)
	view = MakerView.new()
	view.model = model
	view.tiles = tiles
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.picked.connect(_on_picked)
	view.hovered.connect(_on_hovered)
	split.add_child(view)
	var side: VBoxContainer = VBoxContainer.new()
	split.add_child(side)
	_value = SpinBox.new()
	_value.min_value = 0
	_value.max_value = 65535
	_value.prefix = "Value"
	_value.value_changed.connect(func(v: float) -> void: _set_value(int(v)))
	side.add_child(_value)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(MakerPalette.COLUMNS * 32 + 16, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	palette = MakerPalette.new()
	palette.chosen.connect(_set_value)
	sc.add_child(palette)
	_status = Label.new()
	_status.text = "Looking for your games..."
	_ui.add_child(_status)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--game_data="):
			roots.append(a.substr(12))
	var s: Settings = Settings.new(Settings.PATH)
	roots.append_array(PackedStringArray(s.get_value("game_folders")))
	var imported: String = OS.get_user_data_dir().path_join("games")    # the launcher's imports (AND-02)
	if DirAccess.dir_exists_absolute(imported):
		roots.append(imported)
	_scan.call_deferred()


func _button(bar: Control, text: String, on: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on)
	bar.add_child(b)
	return b


func _scan() -> void:
	var results: Array = GameFinder.new().scan_all(roots)
	var by_id: Dictionary = {}
	for r: Dictionary in results:
		if r.status == GameFinder.STATUS_OK and MakerModel.ENGINES.has(r.id) and not by_id.has(r.id):
			by_id[r.id] = r
	found = []
	for id: String in ["keen1", "keen2", "keen3", "keen4", "keen5", "keen6"]:
		if by_id.has(id):
			found.append(by_id[id])
	_games.clear()
	for r: Dictionary in found:
		_games.add_item("Keen " + str(r.id).substr(4))
	if found.is_empty():
		_status.text = "No Keen 1-6 found. Add your games in the launcher first."
		return
	_on_game(0)


func _on_game(i: int) -> void:
	var r: Dictionary = found[i]
	var err: String = tiles.open(r.id, r.folder)
	if err != "" or not model.open(r.id, r.folder):
		_status.text = "Could not open %s: %s" % [r.get("title", r.id), err if err != "" else model.error]
		return
	_levels.clear()
	for l: Array in model.level_list():
		_levels.add_item("%d %s" % [l[0], l[1]] if model.engine == KeenLevel.GALAXY else str(l[1]), int(l[0]))
	_planes.clear()
	for n: String in model.plane_names():
		_planes.add_item(n.capitalize())
	# level 1 to start with (the first level after the world map)
	_on_level(maxi(0, _levels.get_item_index(1)))


func _on_level(index: int) -> void:
	_levels.select(index)
	model.select(_levels.get_item_id(index))
	_on_plane(0)
	view.centre_on_start()
	_refresh()


func _on_plane(i: int) -> void:
	_planes.select(i)
	view.plane = i
	var n: int = tiles.count[i] if i < tiles.count.size() else 0
	palette.show_plane(tiles, i, n, 0)
	_set_value(0)
	view.queue_redraw()


func _set_value(v: int) -> void:
	view.value = v
	palette.value = v
	palette.queue_redraw()
	if int(_value.value) != v:
		_value.set_value_no_signal(v)


func _on_picked(v: int) -> void:
	_set_value(v)


func _on_hovered(cell: Vector2i, v: int) -> void:
	_refresh("(%d, %d): %d" % [cell.x, cell.y, v] if v >= 0 else "")


func _on_start_tool() -> void:
	view.tool = "start"
	_status.text = "Click where Keen starts"


func _do(_changed: bool) -> void:
	view.queue_redraw()
	_refresh()


func _on_save() -> void:
	var dir: String = "user://maker".path_join(model.game_id)
	if model.save(dir):
		_status.text = "Saved to %s" % ProjectSettings.globalize_path(dir)
	else:
		_status.text = "Not saved: " + model.error


## Plays the level being edited with the edits (MAKER-02); back here when the level ends.
func _on_play() -> void:
	model.end_stroke()
	var req: Dictionary = model.play_request(_games.get_item_text(_games.selected))
	if req.is_empty():
		_status.text = "Can't play: " + model.error
		return
	host = GameHost.new()
	add_child(host)
	if not host.start(req):
		_status.text = "Can't play: " + host.error
		host.queue_free()
		host = null
		return
	_ui.visible = false
	host.finished.connect(_on_played)


func _on_played(_message: String) -> void:
	host.queue_free()
	host = null
	_ui.visible = true
	view.grab_focus()
	_refresh("Back from playing")


func _refresh(extra: String = "") -> void:
	if model.level == null:
		return
	_undo_b.disabled = not model.can_undo()
	_redo_b.disabled = model._redo.is_empty()
	var s: Vector2i = model.start_at()
	_status.text = "%s  %dx%d  Keen starts at %s%s%s" % [_levels.get_item_text(_levels.selected), model.level.width, model.level.height,
		"(%d, %d)" % [s.x, s.y] if s.x >= 0 else "nowhere", "  unsaved changes" if model.dirty else "", "   " + extra if extra != "" else ""]


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or host != null:
		return
	if k.ctrl_pressed and k.keycode == KEY_Z:
		_do(model.undo())
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		_do(model.redo())
	elif k.ctrl_pressed and k.keycode == KEY_S:
		_on_save()
	elif k.keycode == KEY_F5:
		_on_play()
	else:
		return
	get_viewport().set_input_as_handled()
