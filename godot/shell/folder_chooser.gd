# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name FolderChooser
extends ColorRect
## SHELL-16: choosing a folder in Megarocket's own look, over the launcher dimmed (the user, 2026-10-11:
## Godot's own file dialog, drawn in the launcher's pixel font, was messy, its folder names cut short and
## run together, with no frame). A framed box: a title; the folder shown, its path on one line (shortened
## in the middle when long, whole on hover); Up a folder and, on Windows, the drives; the folders inside it
## in a scrolling list (a name too long for the box ends in "…" and shows whole on hover); which Keen games
## the launcher would find there (its own scan, the folder and two levels inside it, made off the main
## thread); the choice ("Add this folder") and Cancel; the controls on the last line.
##
## Keyboard: the arrows move, Enter opens the folder picked in the list (or presses a button), Backspace
## goes up a folder, Escape cancels, Tab moves between the parts. Controller: the d-pad moves, A opens or
## presses (the launcher's pad shim makes it Enter), Y goes up, Start chooses the folder shown, B cancels.
## Mouse: a click picks, a double click opens, the buttons press. Android keeps the system's picker (the
## launcher makes no box there).

## The folder shown was chosen.
signal chosen(dir: String)
signal canceled

## The box's title and its choice button's words.
var title_text: String = "Choose a folder with Keen games in it"
var accept_text: String = "Add this folder"
## The folder shown first (the home folder if it can't be opened).
var start_dir: String = ""
## Say which Keen games the launcher would find in the folder shown.
var look_for_games: bool = true
## A file the choice is saved as (the export's ZIP): the box says whether one is already there.
var file_name: String = ""
## A line saying what the choice does, when neither of those is shown.
var note_text: String = ""

## The folder shown.
var current: String = ""
## The folders inside it, in the list's order (the list shows each whole, or ending in "…").
var folders: PackedStringArray = PackedStringArray()
## The games the launcher would find in `current` (GameFinder's results), once looked at.
var games_found: Array = []
## True while the folder shown is being looked at.
var looking: bool = false
## The pixel scale the box is drawn at (MegaTheme's, for the window's size).
var pixel: int = 0

var box: PanelContainer
var title_label: Label
var path_caption: Label
var path_label: Label
var up_button: Button
var nav_row: HFlowContainer
var drive_buttons: Array[Button] = []
var list: ItemList
var note_label: Label
var accept_button: Button
var cancel_button: Button
var hints_label: Label

var _icon: ImageTexture = null
var _margin: MarginContainer
var _column: VBoxContainer
var _buttons: HBoxContainer
var _path_row: HBoxContainer
var _message: String = ""
var _scan_task: int = -1
var _scan_folder: String = ""
var _scan_out: Dictionary = {}


func _ready() -> void:
	name = "FolderChooser"
	color = Color(0, 0, 0, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameFinder.crc32(PackedByteArray())    # its table made here, before a scan thread can ask for it
	_build()
	resized.connect(_on_resized)
	_on_resized()
	if start_dir == "" or not open(start_dir):
		open(home_folder())
	if folders.is_empty():
		accept_button.grab_focus()
	else:
		list.grab_focus()


## Where the box starts when it has nowhere better: the player's home folder.
static func home_folder() -> String:
	for v: String in ["USERPROFILE", "HOME"]:
		var d: String = OS.get_environment(v)
		if d != "" and DirAccess.dir_exists_absolute(d):
			return d.replace("\\", "/")
	return OS.get_user_data_dir()


func _build() -> void:
	box = PanelContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	_margin = MarginContainer.new()
	box.add_child(_margin)
	_column = VBoxContainer.new()
	_margin.add_child(_column)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", MegaTheme.ega(14))
	_column.add_child(title_label)
	# the folder shown: "Folder:" and its path, shortened in the middle to fit (_fit_path)
	var path_row: HBoxContainer = HBoxContainer.new()
	path_row.name = "PathRow"
	_path_row = path_row
	path_caption = Label.new()
	path_caption.name = "PathCaption"
	path_caption.text = "Folder:"
	path_caption.add_theme_color_override("font_color", MegaTheme.ega(7))
	path_row.add_child(path_caption)
	path_label = Label.new()
	path_label.name = "Path"
	path_label.clip_text = true
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.mouse_filter = Control.MOUSE_FILTER_PASS    # its tooltip: the whole path
	path_label.resized.connect(_fit_path)
	path_row.add_child(path_label)
	_column.add_child(path_row)
	# up a folder, and the drives
	nav_row = HFlowContainer.new()
	nav_row.name = "Nav"
	up_button = Button.new()
	up_button.name = "Up"
	up_button.text = "Up a folder"
	up_button.pressed.connect(go_up)
	nav_row.add_child(up_button)
	for i: int in range(DirAccess.get_drive_count() if OS.get_name() == "Windows" else 0):
		var drive: String = DirAccess.get_drive_name(i)
		var b: Button = Button.new()
		b.name = "Drive" + drive.trim_suffix(":")
		b.text = drive
		b.tooltip_text = "Drive " + drive
		b.pressed.connect(func() -> void: open_and_focus(drive + "/"))
		nav_row.add_child(b)
		drive_buttons.append(b)
	_column.add_child(nav_row)
	list = ItemList.new()
	list.name = "Folders"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	list.max_columns = 1
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.item_activated.connect(open_item)
	_column.add_child(list)
	note_label = Label.new()
	note_label.name = "Note"
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(note_label)
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	accept_button = Button.new()
	accept_button.name = "Accept"
	accept_button.text = accept_text
	accept_button.pressed.connect(choose)
	_buttons.add_child(accept_button)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(cancel)
	_buttons.add_child(cancel_button)
	_column.add_child(_buttons)
	hints_label = Label.new()
	hints_label.name = "Hints"
	hints_label.text = "Open: Enter / A / double-click   Up: Backspace / Y   %s: Start   Cancel: Esc / B" % accept_text
	hints_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints_label.add_theme_color_override("font_color", MegaTheme.ega(7))
	_column.add_child(hints_label)
	_link_focus()


## The keys and the pad stay in the box: Up and the drives in a row above the list, the list, then the
## two buttons; Tab goes round them all.
func _link_focus() -> void:
	var top: Array[Button] = [up_button]
	top.append_array(drive_buttons)
	var ring: Array[Control] = []
	for i: int in range(top.size()):
		var b: Button = top[i]
		b.focus_neighbor_left = top[maxi(i - 1, 0)].get_path()
		b.focus_neighbor_right = top[mini(i + 1, top.size() - 1)].get_path()
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = list.get_path()
		ring.append(b)
	list.focus_neighbor_top = up_button.get_path()
	list.focus_neighbor_bottom = accept_button.get_path()
	list.focus_neighbor_left = list.get_path()
	list.focus_neighbor_right = list.get_path()
	ring.append(list)
	for b: Button in [accept_button, cancel_button]:
		b.focus_neighbor_top = list.get_path()
		b.focus_neighbor_bottom = b.get_path()
		ring.append(b)
	accept_button.focus_neighbor_left = accept_button.get_path()
	accept_button.focus_neighbor_right = cancel_button.get_path()
	cancel_button.focus_neighbor_left = accept_button.get_path()
	cancel_button.focus_neighbor_right = cancel_button.get_path()
	for i: int in range(ring.size()):
		ring[i].focus_next = ring[(i + 1) % ring.size()].get_path()
		ring[i].focus_previous = ring[(i - 1 + ring.size()) % ring.size()].get_path()


## The box's sizes at its pixel scale: the frame a little in from the window's edges, the gaps and the
## list's look.
func _on_resized() -> void:
	var s: int = scale_for(size if size.x > 0 else Vector2(1280, 720))
	if s != pixel:
		pixel = s
		theme = theme_for(s)
		_icon = folder_icon(s)
		for side: String in ["left", "right", "top", "bottom"]:
			_margin.add_theme_constant_override("margin_" + side, 4 * s)
		_column.add_theme_constant_override("separation", 4 * s)
		nav_row.add_theme_constant_override("h_separation", 4 * s)
		nav_row.add_theme_constant_override("v_separation", 2 * s)
		_buttons.add_theme_constant_override("separation", 8 * s)
		_path_row.add_theme_constant_override("separation", 3 * s)
		var w: float = 0.0
		for b: Button in [accept_button, cancel_button]:
			b.custom_minimum_size.x = 0
			w = maxf(w, b.get_combined_minimum_size().x)
		for b: Button in [accept_button, cancel_button]:
			b.custom_minimum_size.x = w + 8.0 * s
		for i: int in range(list.item_count):
			if list.get_item_icon(i) != null:
				list.set_item_icon(i, _icon)
	var mx: float = maxf(4.0 * s, roundf(size.x * 0.04))
	var my: float = maxf(4.0 * s, roundf(size.y * 0.03))
	box.offset_left = mx
	box.offset_right = -mx
	box.offset_top = my
	box.offset_bottom = -my
	_fit_path.call_deferred()


## The box's pixel scale for a window: the launcher's (MegaTheme.pixel_scale), but no more than one step
## for every 300 pixels of height, so the list shows a dozen folders or more (at 1920x1080 the launcher's
## 4 left room for four).
static func scale_for(window: Vector2) -> int:
	return clampi(int(window.y / 300.0), 1, MegaTheme.pixel_scale(window))


## The shell's theme at scale `s` with the list's look: framed as the launcher's panels, the picked folder
## on blue with a yellow edge, a scroll bar in the same greys. The font falls back to Godot's own for a
## letter Megarocket's pixel font lacks (a folder's name may have any).
static func theme_for(s: int) -> Theme:
	var t: Theme = MegaTheme.build(s)
	var f: FontVariation = FontVariation.new()
	f.base_font = MegaTheme.font()
	f.fallbacks = [ThemeDB.fallback_font]
	t.default_font = f
	t.set_stylebox("panel", "ItemList", MegaTheme.bevel(MegaTheme.ega(8), s, Color8(0, 0, 12)))
	t.set_stylebox("focus", "ItemList", MegaTheme.bevel(MegaTheme.ega(14), s))
	var picked: StyleBoxFlat = _flat(Color8(0, 0, 120))
	t.set_stylebox("selected", "ItemList", picked)
	var picked_focus: StyleBoxFlat = _flat(MegaTheme.ega(1))
	t.set_stylebox("selected_focus", "ItemList", picked_focus)
	var cursor: StyleBoxFlat = _flat(Color(0, 0, 0, 0))
	cursor.draw_center = false
	cursor.border_color = MegaTheme.ega(14)
	cursor.set_border_width_all(s)
	t.set_stylebox("cursor", "ItemList", cursor)
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("hovered", "ItemList", _flat(Color8(30, 30, 64)))
	t.set_stylebox("hovered_selected", "ItemList", picked)
	t.set_stylebox("hovered_selected_focus", "ItemList", picked_focus)
	t.set_color("font_color", "ItemList", MegaTheme.ega(15))
	t.set_color("font_hovered_color", "ItemList", MegaTheme.ega(15))
	t.set_color("font_selected_color", "ItemList", MegaTheme.ega(14))
	t.set_color("font_hovered_selected_color", "ItemList", MegaTheme.ega(14))
	t.set_constant("v_separation", "ItemList", 3 * s)
	t.set_constant("h_separation", "ItemList", 4 * s)
	t.set_constant("icon_margin", "ItemList", 4 * s)
	t.set_constant("line_separation", "ItemList", 0)
	t.set_color("guide_color", "ItemList", Color8(24, 24, 52))
	var track: StyleBoxFlat = _flat(Color8(20, 20, 44))
	track.set_content_margin_all(s)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	for spec: Array in [["grabber", 7], ["grabber_highlight", 15], ["grabber_pressed", 14]]:
		var g: StyleBoxFlat = _flat(MegaTheme.ega(spec[1]))
		g.content_margin_left = 2 * s
		g.content_margin_right = 2 * s
		t.set_stylebox(spec[0], "VScrollBar", g)
	var tip: StyleBoxFlat = _flat(Color8(0, 0, 12))
	tip.border_color = MegaTheme.ega(7)
	tip.set_border_width_all(s)
	tip.set_content_margin_all(3 * s)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", MegaTheme.ega(15))
	return t


static func _flat(c: Color) -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = c
	return st


## A folder in Megarocket's pixels (yellow, its inside brown), `s` screen pixels to one.
static func folder_icon(s: int) -> ImageTexture:
	var rows: PackedStringArray = PackedStringArray([
		".###.....",
		"#ooo####.",
		"#########",
		"#ooooooo#",
		"#ooooooo#",
		"#ooooooo#",
		"#########"])
	var img: Image = Image.create(rows[0].length() * s, rows.size() * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			var ch: String = rows[y][x]
			if ch != ".":
				img.fill_rect(Rect2i(x * s, y * s, s, s), MegaTheme.ega(14) if ch == "#" else MegaTheme.ega(6))
	return ImageTexture.create_from_image(img)


# ---- the folder shown

## Shows `dir` and the folders inside it. False (and the box says so) if it can't be opened.
func open(dir: String) -> bool:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		_message = ShellMessages.say("Megarocket can't open %s" % dir, "Pick another folder or drive.")
		_update_note()
		return false
	_message = ""
	current = d.get_current_dir().replace("\\", "/")
	# (a name starting with a dot is a program's settings, hidden elsewhere; Windows' hidden ones DirAccess skips)
	var names: Array = Array(d.get_directories()).filter(func(n: String) -> bool: return not n.begins_with("."))
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	folders = PackedStringArray(names)
	list.clear()
	for n: String in folders:
		var i: int = list.add_item(n, _icon)
		list.set_item_tooltip(i, n)
	if folders.is_empty():
		var i: int = list.add_item("(no folders in here)")
		list.set_item_disabled(i, true)
		list.set_item_selectable(i, false)
		list.set_item_tooltip_enabled(i, false)
	else:
		list.select(0)
	list.get_v_scroll_bar().value = 0
	up_button.disabled = parent_of(current) == ""
	path_label.tooltip_text = current
	_fit_path()
	games_found = []
	if look_for_games:
		looking = true
		_look()
	_update_note()
	return true


## Opens `dir`, keeping the keys on the list (or on Add when it holds no folders).
func open_and_focus(dir: String) -> void:
	if open(dir):
		if folders.is_empty():
			accept_button.grab_focus()
		else:
			list.grab_focus()


## The list's item `i` opened (Enter, A, a double click).
func open_item(i: int) -> void:
	if i >= 0 and i < folders.size():
		open_and_focus(current.path_join(folders[i]))


## The folder above `dir`, or "" at a drive's top.
static func parent_of(dir: String) -> String:
	var d: DirAccess = DirAccess.open(dir)
	if d == null or d.change_dir("..") != OK:
		return ""
	var p: String = d.get_current_dir().replace("\\", "/")
	return "" if p == dir or p == "" else p


## Up a folder (Backspace, Y, the Up button), with the folder just left picked in the list.
func go_up() -> void:
	var p: String = parent_of(current)
	if p == "":
		return
	var was: String = current.get_file()
	open_and_focus(p)
	var i: int = folders.find(was)
	if i >= 0:
		list.select(i)
		list.ensure_current_is_visible()


func choose() -> void:
	ShellMessages.note("Folder chosen: %s" % current)
	chosen.emit(current)


func cancel() -> void:
	canceled.emit()


## The path on one line, shortened in the middle to the width it has (its start and its end, the folder's
## own name, kept); whole in its tooltip.
func _fit_path() -> void:
	if path_label == null or path_label.size.x <= 0:
		return
	var font: Font = path_label.get_theme_font("font")
	var fs: int = path_label.get_theme_font_size("font_size")
	path_label.text = elide_middle(current, font, fs, path_label.size.x)


## `text` shortened in the middle with "…" until it is no wider than `width`.
static func elide_middle(text: String, font: Font, font_size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var lo: int = 0
	var hi: int = text.length()
	var best: String = "…"
	while lo <= hi:
		var keep: int = (lo + hi) / 2
		var head: int = keep / 3
		var t: String = text.left(head) + "…" + text.right(keep - head)
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			best = t
			lo = keep + 1
		else:
			hi = keep - 1
	return best


# ---- which games are here (the launcher's own scan, off the main thread)

## Looks at the folder shown on a worker thread; one look at a time (a newer folder is looked at when the
## one under way ends; its answer, for a folder no longer shown, is dropped).
func _look() -> void:
	if _scan_task != -1:
		set_process(true)
		return
	var folder: String = current
	var out: Dictionary = {}
	_scan_folder = folder
	_scan_out = out
	_scan_task = WorkerThreadPool.add_task(func() -> void:
		out["found"] = GameFinder.new().scan_folder(folder, 2))
	set_process(true)


func _process(_delta: float) -> void:
	if _scan_task == -1:
		set_process(false)
		return
	if not WorkerThreadPool.is_task_completed(_scan_task):
		return
	WorkerThreadPool.wait_for_task_completion(_scan_task)
	_scan_task = -1
	if _scan_folder == current:
		games_found = _scan_out.get("found", [])
		looking = false
		_update_note()
	elif look_for_games:
		_look()


func _exit_tree() -> void:
	if _scan_task != -1:
		WorkerThreadPool.wait_for_task_completion(_scan_task)
		_scan_task = -1


## A game's short name ("Keen 4", "Keen Dreams").
static func short_name(id: String) -> String:
	return "Keen Dreams" if id == "kdreams" else "Keen " + id.trim_prefix("keen")


## The line under the list: a folder that would not open; the games found here (or that none are); or
## whether the ZIP is already here; or what the choice does.
func _update_note() -> void:
	var text: String = note_text
	var c: Color = MegaTheme.ega(7)
	if _message != "":
		text = _message
		c = MegaTheme.ega(12)
	elif look_for_games and looking:
		text = "Looking for Keen games in this folder..."
	elif look_for_games:
		var ok: PackedStringArray = PackedStringArray()
		var other: PackedStringArray = PackedStringArray()
		for g: Array in Launcher.GAMES:
			for r: Dictionary in games_found:
				if r.id != g[0]:
					continue
				if r.status == GameFinder.STATUS_OK:
					if not ok.has(short_name(g[0])):
						ok.append(short_name(g[0]))
				elif not other.has(short_name(g[0])):
					other.append(short_name(g[0]))
		for n: String in ok:
			other.erase(n)
		if not ok.is_empty():
			text = "%s found here." % ", ".join(ok)
			c = MegaTheme.ega(10)
			if not other.is_empty():
				text += " Also %s, a release Megarocket can't run." % ", ".join(other)
		elif not other.is_empty():
			text = "%s found here, a release Megarocket can't run (its tile will say what to do)." % ", ".join(other)
			c = MegaTheme.ega(14)
		else:
			text = "No Keen games in this folder or the two levels of folders inside it."
	elif file_name != "":
		if FileAccess.file_exists(current.path_join(file_name)):
			text = "%s is already here: saving replaces it." % file_name
			c = MegaTheme.ega(14)
		else:
			text = "Saved here as %s." % file_name
	note_label.text = text
	note_label.add_theme_color_override("font_color", c)


# ---- keys and buttons the box takes itself

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# (before the launcher's pad shim, which makes Start Enter: here Start chooses, Y goes up)
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	if jb != null and (jb.button_index == JOY_BUTTON_START or jb.button_index == JOY_BUTTON_Y):
		if jb.pressed:
			if jb.button_index == JOY_BUTTON_START:
				choose()
			else:
				go_up()
		get_viewport().set_input_as_handled()
		return
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_BACKSPACE:
		go_up()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
