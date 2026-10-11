# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerScreen
extends Control
## Keen Maker (MAKER-03, V15-02, V15-03, V15-04), opened from the launcher's Keen Maker button in the same
## window (the launcher swaps to it as it does to a game, and back), or on its own from maker_main.tscn.
## Its own look is Megarocket's (MegaTheme: original art in the EGA's colours, no game file); a level's
## tiles come from the player's game. Pages:
##   games    - the seven games; the ones found can be picked, the others say how to add them (J-24 (a):
##              one maker for every game the player owns)
##   library  - the player's levels for that game (name, date): open, play, rename, duplicate, delete
##              (asked first); New level; Remix (any of the game's levels as a copy)
##   remix    - the game's levels to remix
##   editor   - the level: tools (paint, pick, erase, fill a rectangle, Keen's start), the parts palette
##              by use, undo and redo, zoom out to the whole level, play from the cursor or from Keen's
##              start and back with everything where it was, Keen's last run as a fading trail; saves into
##              the player's folder (MakerLibrary), never a game's
## Keyboard, controller and mouse all work everywhere (A16). The controller in the editor: the d-pad or
## left stick moves the cursor, A uses the tool (held: paints on), B erases, X the next tool, Y plays from
## the cursor, LB/RB the part before/after, LT/RT the category before/after, Start the menu (play, save,
## undo, redo, whole level, back). The keys: arrows, Enter or Space, Delete, Tab, [ and ], Page Up/Down,
## P (play here), F5 (play from the start), Z (whole level), Ctrl+Z/Y/S, Escape (the menu).

signal closed

const GAMES: Array = [["keen1", "Keen 1"], ["keen2", "Keen 2"], ["keen3", "Keen 3"], ["keen4", "Keen 4"],
	["keen5", "Keen 5"], ["keen6", "Keen 6"], ["kdreams", "Keen Dreams"]]
const TOOL_NAMES: Dictionary = {"paint": "Paint", "pick": "Pick", "erase": "Erase", "rect": "Fill box", "start": "Keen start"}
## The cursor's repeat while a direction is held: first step, then every
const REPEAT_FIRST: float = 0.28
const REPEAT_EVERY: float = 0.06
## Keen's last run: at most this many positions kept
const TRAIL_MAX: int = 6000

## GameFinder results by game id (the launcher gives its own; on its own the screen scans)
var found: Dictionary = {}
## Extra folders to look in when scanning (--game_data=<folder> on the command line)
var roots: PackedStringArray = PackedStringArray()
## Run on its own (maker_main.tscn): the controller's A and B made ui_accept and ui_cancel here, as the
## launcher's _input does for its own scenes (Godot 4.7's ui_accept and ui_cancel hold no pad buttons)
var standalone: bool = false

var model: MakerModel = MakerModel.new()
var tiles: MakerTiles = MakerTiles.new()
var library: MakerLibrary = MakerLibrary.new()
var view: MakerView = null
var palette: MakerPalette = null
var host: GameHost = null
## "games", "library", "remix", "editor"
var page: String = ""
var game: String = ""
## The dialog over the page (a question, the rename box, the editor's menu), or null
var dialog: Control = null
var status: Label = null
var hints: Label = null

var _body: VBoxContainer = null
var _page_box: Control = null
var _part_label: Label = null
var _cat_label: Label = null
var _tool_buttons: Dictionary = {}
var _undo_b: Button = null
var _redo_b: Button = null
var _return_focus: String = ""
var _dialog_return: Control = null
var _held: Vector2i = Vector2i.ZERO
var _held_for: float = 0.0
var _a_down: bool = false
var _b_down: bool = false
var _trig: Dictionary = {}
var _played_from: String = ""
var _rename_edit: LineEdit = null
## A refusal's reason, shown first on the status line for a few seconds
var _notice: String = ""
var _notice_until: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	standalone = get_parent() == get_tree().root
	theme = MegaTheme.build(maxi(1, MegaTheme.pixel_scale(get_viewport_rect().size) - 1))    # a tool: more room for the level
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg: ColorRect = ColorRect.new()
	bg.color = MegaTheme.SPACE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	margin.add_child(_body)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = "KEEN MAKER"
	title.add_theme_color_override("font_color", MegaTheme.ega(14))
	title.add_theme_color_override("font_shadow_color", MegaTheme.ega(4))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_body.add_child(title)
	_page_box = VBoxContainer.new()
	_page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_page_box)
	status = Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", MegaTheme.ega(11))
	_body.add_child(status)
	hints = Label.new()
	hints.name = "Hints"
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.add_theme_color_override("font_color", MegaTheme.ega(7))
	_body.add_child(hints)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--game_data="):
			roots.append(a.substr(12))
	if found.is_empty():
		_scan()
	show_games()


## The games found (when not given by the launcher): Steam, GOG, the player's folders and imports.
func _scan() -> void:
	var s: Settings = Settings.new(Settings.default_path())
	var r: PackedStringArray = PackedStringArray(roots)
	r.append_array(PackedStringArray(s.get_value("game_folders")))
	var imported: String = OS.get_user_data_dir().path_join("games")    # the launcher's imports (AND-02)
	if DirAccess.dir_exists_absolute(imported):
		r.append(imported)
	for res: Dictionary in GameFinder.new().scan_all(r):
		if res.status == GameFinder.STATUS_OK and MakerModel.ENGINES.has(res.id) and not found.has(res.id):
			found[res.id] = res


# ------------------------------------------------------------------ pages

func _clear_page() -> void:
	close_dialog()
	for c: Node in _page_box.get_children():
		_page_box.remove_child(c)
		c.queue_free()
	view = null
	palette = null
	_tool_buttons = {}


func _button(parent: Control, text: String, on: Callable, node_name: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	if node_name != "":
		b.name = node_name
	b.pressed.connect(on)
	parent.add_child(b)
	return b


func _heading(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", MegaTheme.ega(10))
	_page_box.add_child(l)
	return l


func _scroll_list() -> VBoxContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	_page_box.add_child(sc)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return list


## Page 1: the seven games, the ones found first to pick.
func show_games() -> void:
	_clear_page()
	page = "games"
	_heading("Pick the game you are making a level for")
	var list: VBoxContainer = _scroll_list()
	var first: Button = null
	for g: Array in GAMES:
		var id: String = g[0]
		var have: bool = found.has(id)
		var b: Button = _button(list, "%s   %s" % [g[1], str(found[id].get("version", "")) if have else "- not found"],
			_on_game_button.bind(id), id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not have:
			b.add_theme_color_override("font_color", MegaTheme.ega(8))
		if have and first == null:
			first = b
	var back: Button = _button(list, "Back to Megarocket" if not standalone else "Quit", leave, "Leave")
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.text = "%d of your games can be built for." % found.size() if not found.is_empty() \
		else "None of your Keen games were found. Add them on Megarocket's main screen (Add a folder), then come back."
	hints.text = "Move: arrows / d-pad   Pick: Enter / A   Back: Esc / B"
	_focus(_page_box.find_child(_return_focus, true, false) as Control if _return_focus != "" else (first if first != null else back))
	_return_focus = ""


func _on_game_button(id: String) -> void:
	if not found.has(id):
		var how: String = KnownFiles.REMEDY.get(id, "")
		ask("%s was not found.\n\nTo add it: on Megarocket's main screen press Add a folder (Import games on Android) and choose the folder that holds it; How to add games explains where to get it.\n\n%s" % [_title(id), how],
			[["OK", func() -> void: pass]], id)
		return
	open_game(id)


## Opens a game for making levels (its levels, tiles and parts); then its library.
func open_game(id: String) -> bool:
	var r: Dictionary = found.get(id, {})
	if r.is_empty():
		return false
	status.text = "Opening %s..." % _title(id)
	if not model.open(id, str(r.folder), str(r.get("version", ""))):
		status.text = "Could not open %s: %s" % [_title(id), model.error]
		return false
	tiles.use(model.parts)
	game = id
	show_library()
	return true


static func _title(id: String) -> String:
	for g: Array in GAMES:
		if g[0] == id:
			return g[1]
	return id


## Page 2: the player's levels for the game.
func show_library(focus_path: String = "") -> void:
	_clear_page()
	page = "library"
	_heading("%s: your levels" % _title(game))
	var row: HBoxContainer = HBoxContainer.new()
	_page_box.add_child(row)
	var new_b: Button = _button(row, "New level", new_level, "NewLevel")
	_button(row, "Remix a level", show_remix, "Remix")
	_button(row, "Other game", func() -> void:
		_return_focus = game
		show_games(), "OtherGame")
	var list: VBoxContainer = _scroll_list()
	list.name = "Levels"
	var focus: Control = new_b
	var saved: Array = MakerLibrary.list(game)
	for e: Dictionary in saved:
		var when: String = Time.get_datetime_string_from_unix_time(int(e.modified) + _tz(), true).substr(0, 16)
		var b: Button = _button(list, "%s    %s    %s" % [e.name, when, "remix of level %s" % str(e.origin).substr(6) if str(e.origin).begins_with("remix") else "new"],
			_on_level_button.bind(str(e.path)), "Level_%s" % str(e.path).get_file().get_basename())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("path", e.path)
		if focus_path != "" and e.path == focus_path:
			focus = b
	if saved.is_empty():
		var none: Label = Label.new()
		none.text = "No levels yet: make a new one, or remix one of %s's." % _title(game)
		none.add_theme_color_override("font_color", MegaTheme.ega(7))
		list.add_child(none)
	status.text = "%d saved level%s for %s, kept in %s" % [saved.size(), "" if saved.size() == 1 else "s", _title(game), MakerLibrary.dir_for(game)]
	hints.text = "Move: arrows / d-pad   Choose: Enter / A   Back: Esc / B"
	_focus(focus)


static func _tz() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _on_level_button(path: String) -> void:
	var name: String = ""
	for e: Dictionary in MakerLibrary.list(game):
		if e.path == path:
			name = e.name
	ask(name, [["Edit", func() -> void: edit_saved(path)], ["Play", func() -> void: play_saved(path)],
		["Rename", func() -> void: rename_box(path, name)], ["Duplicate", func() -> void: _duplicate(path)],
		["Delete", func() -> void: _confirm_delete(path, name)], ["Cancel", func() -> void: pass]], "")


func _duplicate(path: String) -> void:
	var to: String = library.duplicate_level(path)
	status.text = "Duplicated." if to != "" else "Not duplicated: " + library.error
	show_library(to)
	if to != "":
		status.text = "Duplicated."


func _confirm_delete(path: String, name: String) -> void:
	ask("Delete \"%s\"? It can't be brought back." % name, [["Keep it", func() -> void: show_library(path)],
		["Delete", func() -> void:
			var ok: bool = library.delete(path)
			show_library()
			status.text = ("Deleted \"%s\"." % name) if ok else "Not deleted: " + library.error]], "")


## Page: the game's own levels, any opened as a copy to remix.
func show_remix() -> void:
	_clear_page()
	page = "remix"
	_heading("Remix one of %s's levels (the game's own stays as it is)" % _title(game))
	var list: VBoxContainer = _scroll_list()
	var first: Button = null
	for l: Array in model.level_list():
		var b: Button = _button(list, "%d  %s" % [l[0], l[1]] if model.engine != KeenLevel.VORTICONS else str(l[1]),
			remix.bind(int(l[0])), "Remix_%d" % int(l[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if first == null:
			first = b
	_button(list, "Back", show_library, "Back").alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.text = ""
	hints.text = "Move: arrows / d-pad   Remix: Enter / A   Back: Esc / B"
	_focus(first)


func new_level() -> void:
	if not model.new_level("My level %d" % (MakerLibrary.list(game).size() + 1)):
		status.text = "Can't make a level: " + model.error
		return
	show_editor()


func remix(n: int) -> void:
	if not model.remix(n):
		status.text = "Can't remix: " + model.error
		return
	show_editor()


func edit_saved(path: String) -> void:
	if not model.load_doc(path):
		status.text = "Can't open it: " + model.error
		return
	show_editor()


## Page: the editor.
func show_editor() -> void:
	_clear_page()
	page = "editor"
	var bar: HFlowContainer = HFlowContainer.new()
	bar.name = "Tools"
	_page_box.add_child(bar)
	for t: String in MakerView.TOOLS:
		var b: Button = _button(bar, TOOL_NAMES[t], set_tool.bind(t), "Tool_" + t)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		_tool_buttons[t] = b
	_undo_b = _button(bar, "Undo", func() -> void: _did(model.undo()), "Undo")
	_redo_b = _button(bar, "Redo", func() -> void: _did(model.redo()), "Redo")
	_button(bar, "Whole level", toggle_whole, "Whole")
	_button(bar, "Play here", play_here, "PlayHere")
	_button(bar, "Play", play_start, "Play")
	_button(bar, "Save", save, "Save")
	_button(bar, "Menu", open_menu, "Menu")
	for b: Node in bar.get_children():
		(b as Control).focus_mode = Control.FOCUS_NONE    # the cursor has the keys; the menu reaches them all
	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(split)
	view = MakerView.new()
	view.name = "Level"
	view.model = model
	view.tiles = tiles
	view.parts = model.parts
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.picked.connect(_on_picked)
	view.hovered.connect(func(_c: Vector2i) -> void: _refresh())
	view.changed.connect(_refresh)
	view.refused.connect(func(why: String) -> void:
		_notice = "Can't: " + why
		_notice_until = Time.get_ticks_msec() + 4000
		_refresh())
	split.add_child(view)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(MakerPalette.COLUMNS * 36 + 16, 0)
	split.add_child(side)
	var cats: HBoxContainer = HBoxContainer.new()
	side.add_child(cats)
	var prev: Button = _button(cats, "<", func() -> void: _category(-1), "CatPrev")
	_cat_label = Label.new()
	_cat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cat_label.add_theme_color_override("font_color", MegaTheme.ega(14))
	cats.add_child(_cat_label)
	var next: Button = _button(cats, ">", func() -> void: _category(1), "CatNext")
	prev.focus_mode = Control.FOCUS_NONE
	next.focus_mode = Control.FOCUS_NONE
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	palette = MakerPalette.new()
	palette.name = "Parts"
	palette.chosen.connect(_on_part)
	sc.add_child(palette)
	palette.setup(tiles, model.parts)
	_part_label = Label.new()
	_part_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_part_label)
	hints.text = "Cursor: arrows / d-pad   Use tool: Enter / A   Erase: Del / B   Tool: Tab / X   Part: [ ] / LB RB   Kind: PgUp PgDn / LT RT   Play here: P / Y   Menu: Esc / Start"
	set_tool("paint")
	palette.show_category(0)
	_focus(view)
	_centre.call_deferred()


func _centre() -> void:
	if view != null:
		view.centre_on_start()
		_refresh()


func set_tool(t: String) -> void:
	if view == null:
		return
	view.tool = t
	view.anchor = Vector2i(-1, -1)
	for k: String in _tool_buttons:
		(_tool_buttons[k] as Button).set_pressed_no_signal(k == t)
	view.queue_redraw()
	_refresh()


func next_tool(d: int = 1) -> void:
	var i: int = MakerView.TOOLS.find(view.tool)
	set_tool(MakerView.TOOLS[posmod(i + d, MakerView.TOOLS.size())])


func _category(d: int) -> void:
	palette.show_category(palette.category + d)
	palette.show_chosen()


func _on_part(plane: int, value: int) -> void:
	view.plane = plane
	view.value = value
	if view.tool in ["pick", "erase", "start"]:
		set_tool("paint")
	view.queue_redraw()
	_refresh()


func _on_picked(plane: int, value: int) -> void:
	if not palette.select_value(plane, value):
		view.plane = plane
		view.value = value
	palette.show_chosen()
	set_tool("paint")


func _did(_changed: bool) -> void:
	if view != null:
		view.queue_redraw()
	_refresh()


func toggle_whole() -> void:
	if view.whole_shown() and view.zoom < 1.0:
		view.set_zoom(2.0)
		view.set_cursor(view.cursor)
	else:
		view.zoom_whole()
	_refresh()


func _refresh() -> void:
	if page != "editor" or view == null or model.level == null:
		return
	_undo_b.disabled = not model.can_undo()
	_redo_b.disabled = not model.can_redo()
	var c: Dictionary = palette.current()
	_cat_label.text = "%s (%d)" % [c.get("name", ""), (c.get("values", PackedInt32Array()) as PackedInt32Array).size()]
	_part_label.text = palette.part_name()
	var s: Vector2i = model.start_at()
	var under: String = ""
	if model.level.in_bounds(view.cursor.x, view.cursor.y):
		var mv: int = model.level.get_word(model.parts.marker_plane(), view.cursor.x, view.cursor.y)
		var tv: int = model.level.get_word(model.parts.tile_plane(), view.cursor.x, view.cursor.y)
		under = model.parts.marker_name(mv) if mv != 0 and model.parts.marker_name(mv) != "" else model.parts.use_of(model.parts.tile_plane(), tv)
	var notice: String = _notice + "   " if Time.get_ticks_msec() < _notice_until else ""
	status.text = notice + "%s (%s)   %dx%d   objects %d/%d   %s   cursor %d,%d %s   Keen starts %s%s" % [model.doc_name, _title(game), model.level.width,
		model.level.height, model.objects(), MakerModel.OBJECT_LIMIT[model.engine], TOOL_NAMES[view.tool] + (" - pick the other corner" if view.anchor.x >= 0 else ""),
		view.cursor.x, view.cursor.y, under, "at %d,%d" % [s.x, s.y] if s.x >= 0 else "nowhere yet", "   not saved" if model.dirty else ""]


func save() -> bool:
	if model.save_doc():
		status.text = "Saved \"%s\"." % model.doc_name
		_refresh()
		status.text = "Saved \"%s\" into your levels." % model.doc_name
		return true
	status.text = "Not saved: " + model.error
	return false


## The editor's menu (Start, Escape): everything the bar holds, for the pad and keys.
func open_menu() -> void:
	ask("%s" % model.doc_name, [["Back to editing", func() -> void: pass], ["Play from Keen's start", play_start],
		["Play from the cursor", play_here], ["Save", save], ["Rename", func() -> void: rename_box("", model.doc_name)],
		["Undo", func() -> void: _did(model.undo())], ["Redo", func() -> void: _did(model.redo())],
		["Whole level", toggle_whole], ["Back to your levels", leave_editor]], "")


## Leaves the editor for the library, asking first when there are unsaved changes.
func leave_editor() -> void:
	if not model.dirty:
		show_library(model.path)
		return
	ask("Save \"%s\" before leaving?" % model.doc_name, [["Save", func() -> void:
		if save():
			show_library(model.path)], ["Don't save", func() -> void: show_library(model.path)],
		["Keep editing", func() -> void: pass]], "")


# ------------------------------------------------------------------ dialogs

## A framed box over the page with a message and buttons ([text, callable]); the first focused. Each
## button closes the box, then calls its callable. `focus_back`: the node to focus after (by name).
func ask(text: String, buttons: Array, focus_back: String) -> void:
	close_dialog()
	_dialog_return = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus_back != "":
		_dialog_return = _page_box.find_child(focus_back, true, false) as Control
	dialog = ColorRect.new()
	dialog.name = "Dialog"
	(dialog as ColorRect).color = Color(0, 0, 0, 0.6)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Box"
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)
	if text != "":
		var q: Label = Label.new()
		q.name = "Question"
		q.text = text
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x * 0.6, 640), 0)
		col.add_child(q)
	var first: Button = null
	for spec: Array in buttons:
		var cb: Callable = spec[1]
		var b: Button = _button(col, spec[0], func() -> void:
			close_dialog()
			cb.call(), "Ask_" + str(spec[0]).replace(" ", "_").replace("'", ""))
		if first == null:
			first = b
	add_child(dialog)
	_page_box.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	first.grab_focus()


func close_dialog() -> void:
	if dialog == null:
		return
	dialog.queue_free()
	remove_child(dialog)
	dialog = null
	_rename_edit = null
	_page_box.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if page == "editor" and view != null:
		view.grab_focus()
	elif _dialog_return != null and is_instance_valid(_dialog_return) and _dialog_return.is_inside_tree():
		_dialog_return.grab_focus()
	_dialog_return = null


## The rename box: a line typed with the keys, or with the d-pad (Up and Down step the letter, Right moves
## on, Left erases: PadTextEntry's way); OK keeps it. `path` a library file ("" for the level being made).
func rename_box(path: String, name: String) -> void:
	ask("New name (keys, or the d-pad: up/down change the letter, right adds one, left erases):",
		[["OK", func() -> void: _rename(path)], ["Cancel", func() -> void: pass]], "")
	var box: VBoxContainer = dialog.find_child("Box", true, false)
	_rename_edit = LineEdit.new()
	_rename_edit.name = "Name"
	_rename_edit.text = name
	_rename_edit.max_length = 40
	_rename_edit.custom_minimum_size = Vector2(360, 0)
	_pending_name = name
	_rename_edit.text_changed.connect(func(t: String) -> void: _pending_name = t)
	_rename_edit.text_submitted.connect(func(_t: String) -> void: (box.find_child("Ask_OK", true, false) as Button).pressed.emit())
	box.add_child(_rename_edit)
	box.move_child(_rename_edit, 1)
	_rename_edit.grab_focus()
	_rename_edit.caret_column = name.length()


func _rename(path: String) -> void:
	var name: String = _pending_name.strip_edges()
	if name == "":
		status.text = "A level needs a name."
		return
	if path == "":
		model.doc_name = name
		model.dirty = true
		_refresh()
		return
	var ok: bool = library.rename(path, name)
	show_library(path)
	status.text = ("Renamed \"%s\"." % name) if ok else "Not renamed: " + library.error


var _pending_name: String = ""


## The pad's d-pad typing into the rename box (PadTextEntry's rules).
func _pad_type(dir: JoyButton) -> void:
	var sc: int = {JOY_BUTTON_DPAD_UP: PadTextEntry.UP, JOY_BUTTON_DPAD_DOWN: PadTextEntry.DOWN,
		JOY_BUTTON_DPAD_LEFT: PadTextEntry.LEFT, JOY_BUTTON_DPAD_RIGHT: PadTextEntry.RIGHT}[dir]
	var r: Array = PadTextEntry.press(_rename_edit.text, _rename_edit.caret_column, sc,
		func(t: String) -> bool: return t.length() < _rename_edit.max_length)
	_rename_edit.text = r[0]
	_rename_edit.caret_column = r[1]
	_pending_name = r[0]


# ------------------------------------------------------------------ playing

func play_start() -> void:
	_play(Vector2i(-1, -1))


func play_here() -> void:
	_play(view.cursor if view != null else Vector2i(-1, -1))


func play_saved(path: String) -> void:
	if not model.load_doc(path):
		status.text = "Can't open it: " + model.error
		return
	_played_from = path
	_play(Vector2i(-1, -1))


## Plays the level (MAKER-02's start-anywhere: Keen set down at `at` when it is in the level); back here
## when the level ends, everything where it was, and Keen's run left as the trail.
func _play(at: Vector2i, checked: bool = false) -> void:
	# V15-04: what would spoil the play said first (a door with no key); play anyway, or keep building
	var trouble: Array = model.problems()
	if not checked and not trouble.is_empty() and model.start_at().x >= 0:
		ask("
".join(trouble), [["Keep building", func() -> void: pass], ["Play anyway", func() -> void: _play(at, true)]], "")
		return
	var req: Dictionary = model.play_request(_title(game), at)
	if req.is_empty():
		status.text = "Can't play: " + model.error
		return
	host = GameHost.new()
	host.settings_path = Settings.default_path()
	add_child(host)
	if not host.start(req):
		status.text = "Can't play: " + host.error
		host.queue_free()
		host = null
		return
	_body.visible = false
	model.trail = PackedVector2Array()
	host.finished.connect(_on_played)


func _process(delta: float) -> void:
	if host != null:
		_record_trail()
		return
	if page != "editor" or dialog != null or view == null:
		_held = Vector2i.ZERO
		return
	var d: Vector2i = Vector2i(int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up")))
	if d == Vector2i.ZERO:
		_held = d
		return
	if d != _held:
		_held = d
		_held_for = 0.0
		_step_cursor(d)
		return
	_held_for += delta
	if _held_for >= REPEAT_FIRST:
		_held_for -= REPEAT_EVERY
		_step_cursor(d)


func _step_cursor(d: Vector2i) -> void:
	view.move_cursor(d)
	if _a_down:
		view.act_at(view.cursor, true)
	elif _b_down:
		_erase_at_cursor(true)
	_refresh()


func _record_trail() -> void:
	var e: Object = host.engine
	var p: Vector2 = Vector2(-1, -1)
	if e == null:
		return
	if e is GalGame:
		var o: Object = (e as GalGame).ck_keenObj
		if o != null:
			p = Vector2(int(o.get("posX")), int(o.get("posY"))) / 256.0 + Vector2(0.5, 1.0)
	elif e is DreamsGame:
		var o: Object = (e as DreamsGame).player
		if o != null:
			p = Vector2(int(o.get("x")), int(o.get("y"))) / 256.0 + Vector2(0.5, 1.0)
	elif e is VortScreens and e.get("shell_in_level") and not (e.get("objlist") as Array).is_empty():
		var o: Object = (e.get("objlist") as Array)[0]
		p = Vector2(int(o.get("x")), int(o.get("y"))) / 4096.0 + Vector2(0.5, 1.0)
	# (before Keen is set down his place is the map's corner)
	if p.x < 0 or p == Vector2(0.5, 1.0) or model.level == null or not model.level.in_bounds(int(p.x), int(p.y)):
		return
	if model.trail.is_empty() or model.trail[model.trail.size() - 1].distance_to(p) >= 0.2:
		if model.trail.size() < TRAIL_MAX:
			model.trail.append(p)


func _on_played(_message: String) -> void:
	host.queue_free()
	host = null
	_body.visible = true
	if page == "editor" and view != null:
		view.grab_focus()
		view.queue_redraw()
		_refresh()
		status.text = "Back from playing: Keen's run is the trail. " + status.text
	else:
		show_library(_played_from)
		status.text = "Back from playing."
	_played_from = ""


# ------------------------------------------------------------------ input

func _erase_at_cursor(drag: bool) -> void:
	var t: String = view.tool
	view.tool = "erase"
	view.act_at(view.cursor, drag)
	view.tool = t


## Leaves the maker (to the launcher, or quits when run on its own).
func leave() -> void:
	if standalone:
		get_tree().quit()
	else:
		closed.emit()


## Escape / B / Android's Back on the maker: closes the dialog, or goes back a page; the games page leaves.
func back() -> void:
	if host != null:
		return
	if dialog != null:
		close_dialog()
	elif page == "editor":
		open_menu()
	elif page == "remix":
		show_library()
	elif page == "library":
		_return_focus = game
		show_games()
	else:
		leave()


func _input(event: InputEvent) -> void:
	if host != null:
		return
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	var jm: InputEventJoypadMotion = event as InputEventJoypadMotion
	# the rename box: the d-pad types (PadTextEntry)
	if _rename_edit != null and jb != null and jb.pressed and jb.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		_pad_type(jb.button_index)
		get_viewport().set_input_as_handled()
		return
	if _rename_edit != null and jb != null and jb.button_index == JOY_BUTTON_A:
		if jb.pressed:
			(dialog.find_child("Ask_OK", true, false) as Button).pressed.emit()    # A keeps the name
		get_viewport().set_input_as_handled()
		return
	if page == "editor" and dialog == null and view != null:
		if jb != null:
			_editor_pad(jb)
			get_viewport().set_input_as_handled()
			return
		if jm != null and (jm.axis == JOY_AXIS_TRIGGER_LEFT or jm.axis == JOY_AXIS_TRIGGER_RIGHT):
			var on: bool = jm.axis_value > 0.5
			if on and not _trig.get(jm.axis, false):
				_category(-1 if jm.axis == JOY_AXIS_TRIGGER_LEFT else 1)
			_trig[jm.axis] = on
			get_viewport().set_input_as_handled()
			return
		# the arrows, the d-pad and the stick move the cursor (_process), not the focus
		for a: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			if event.is_action(a):
				get_viewport().set_input_as_handled()
				return
		var k: InputEventKey = event as InputEventKey
		if k != null and k.pressed and _editor_key(k):
			get_viewport().set_input_as_handled()
		return
	# on its own the maker makes the pad's A and Start ui_accept and B ui_cancel (as the launcher does)
	if standalone and jb != null:
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


func _editor_pad(jb: InputEventJoypadButton) -> void:
	match jb.button_index:
		JOY_BUTTON_A:
			_a_down = jb.pressed
			if jb.pressed:
				view.act_at(view.cursor)
			else:
				view.act_end()
		JOY_BUTTON_B:
			_b_down = jb.pressed
			if jb.pressed:
				_erase_at_cursor(false)
			else:
				view.act_end()
		_:
			if not jb.pressed:
				return
			match jb.button_index:
				JOY_BUTTON_X:
					next_tool()
				JOY_BUTTON_Y:
					play_here()
				JOY_BUTTON_LEFT_SHOULDER:
					palette.step(-1)
					palette.show_chosen()
				JOY_BUTTON_RIGHT_SHOULDER:
					palette.step(1)
					palette.show_chosen()
				JOY_BUTTON_START:
					open_menu()
				JOY_BUTTON_BACK:
					toggle_whole()
	_refresh()


func _editor_key(k: InputEventKey) -> bool:
	if k.ctrl_pressed:
		match k.keycode:
			KEY_Z:
				_did(model.undo())
			KEY_Y:
				_did(model.redo())
			KEY_S:
				save()
			_:
				return false
		return true
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not k.echo:
				view.act_at(view.cursor)
				view.act_end()
		KEY_DELETE, KEY_BACKSPACE:
			_erase_at_cursor(false)
			view.act_end()
		KEY_TAB:
			next_tool(-1 if k.shift_pressed else 1)
		KEY_BRACKETLEFT:
			palette.step(-1)
			palette.show_chosen()
		KEY_BRACKETRIGHT:
			palette.step(1)
			palette.show_chosen()
		KEY_PAGEUP:
			_category(-1)
		KEY_PAGEDOWN:
			_category(1)
		KEY_P:
			play_here()
		KEY_F5:
			play_start()
		KEY_Z:
			toggle_whole()
		KEY_ESCAPE:
			open_menu()
		_:
			return false
	_refresh()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if host != null:
		return
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and standalone:
		back()


func _focus(c: Control) -> void:
	if c != null:
		(func() -> void:
			if is_instance_valid(c) and c.is_inside_tree():
				c.grab_focus()).call_deferred()
