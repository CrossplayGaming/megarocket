# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-16: the launcher's folder chooser (Add a folder; the export's folder and ZIP), Megarocket's own
## framed box in place of Godot's file dialog, worked with real key, controller and mouse events
## (Input.parse_input_event) on a folder tree made for the test:
## - Enter on Add a folder opens it on the folder added last, the list focused; the folders inside in
##   natural order (9 before 10), dot folders left out;
## - keys: Down picks, Enter opens, Backspace goes up with the folder left picked, Escape cancels;
## - controller: the d-pad picks, A opens, Y goes up, B cancels (the focus back on Add a folder, nothing
##   added), Start adds the folder shown;
## - mouse: a click picks, a double click opens, the Up and Cancel buttons press, a click beside the box
##   reaches nothing behind it;
## - the games the launcher would find in the folder shown are named under the list ("Keen 4 found
##   here."), none in the made tree; Start on the development copy's keen4 folder adds it: saved in the
##   settings file and scanned (Keen 4's tile found there);
## - the export's choosers: Export here (no games line, what the choice does), Save the ZIP here (whether
##   the ZIP is already there);
## - its layout at 1280x720 and 1920x1080: the box inside the window, every label's and button's text
##   inside its control (the long path shortened in the middle, whole in its tooltip; a long folder name
##   whole in its tooltip, the list ending it in "…"), the font no smaller than the launcher's at
##   1280x720, ten rows of the list in view or more.
##
## Options: --game_data=<folder>

var t: T = T.new()
var l: Launcher = null
const LONG: String = "Zeta a folder whose name is long enough to run past the edge of the box at every window size tested here, which is quite long"


func _init() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _owner() -> String:
	var f: Control = root.gui_get_focus_owner()
	return str(f.name) if f != null else "none"


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _button(b: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _click(at: Vector2, double: bool = false) -> void:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await _frames(2)
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = down
		e.double_click = double and down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e)
		await _frames(3)


func _picked(fc: FolderChooser) -> String:
	var sel: PackedInt32Array = fc.list.get_selected_items()
	return fc.folders[sel[0]] if not sel.is_empty() and sel[0] < fc.folders.size() else ""


func _norm(p: String) -> String:
	var d: DirAccess = DirAccess.open(p)
	return d.get_current_dir().replace("\\", "/") if d != null else p


func _go() -> void:
	var data: String = T.options().get("game_data", "")
	if data == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var base: String = OS.get_temp_dir().path_join("mr_shell16_%d" % Time.get_ticks_usec())
	var tree: String = base.path_join("tree")
	for sub: String in ["alpha/inner", "beta", "9", "10", ".hidden", LONG + "/one", LONG + "/two"]:
		DirAccess.make_dir_recursive_absolute(tree.path_join(sub))
	tree = _norm(tree)
	root.size = Vector2i(1280, 720)
	l = load("res://shell/main.tscn").instantiate()
	l.make_art = false
	l.lock_path = base.path_join("lock")
	l.settings_path = base.path_join("settings.cfg")
	# the launcher's own scans, with Steam and GOG finding nothing (only the folders added count)
	var finder: GameFinder = GameFinder.new()
	finder.steam_path_reader = func() -> String: return ""
	finder.gog_games_reader = func() -> Array: return []
	l.finder = finder
	root.add_child(l)
	await _frames(5)
	var add: Button = l.find_child("AddFolder", true, false)
	l.extra_folders = PackedStringArray([tree])    # (as if added before: the chooser starts there)

	# ---- keyboard
	add.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	var fc: FolderChooser = l.folder_chooser
	t.ok("Enter on Add a folder opens the chooser", fc != null)
	if fc == null:
		t.finish(self)
		return
	t.eq("it starts on the folder added last", fc.current, tree)
	t.eq("the folders inside, natural order, no dot folders", Array(fc.folders), ["9", "10", "alpha", "beta", LONG])
	t.eq("the list has the keys", _owner(), "Folders")
	t.eq("the first folder picked", _picked(fc), "9")
	t.ok("no Keen games in the made tree, said so", await _wait(func() -> bool: return not fc.looking, 20.0) and fc.note_label.text.begins_with("No Keen games"))
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	t.eq("Down twice picks alpha", _picked(fc), "alpha")
	await _key(KEY_ENTER)
	t.eq("Enter opens it", fc.current, tree.path_join("alpha"))
	t.eq("its folder listed", Array(fc.folders), ["inner"])
	await _key(KEY_BACKSPACE)
	t.eq("Backspace goes up", fc.current, tree)
	t.eq("with the folder left picked", _picked(fc), "alpha")
	t.eq("the keys still on the list", _owner(), "Folders")
	await _key(KEY_ESCAPE)
	t.ok("Escape cancels: the chooser gone", l.folder_chooser == null)
	await _frames(2)
	t.eq("the keys back on Add a folder", _owner(), "AddFolder")

	# ---- controller
	await _button(JOY_BUTTON_A)
	fc = l.folder_chooser
	t.ok("A on Add a folder opens it", fc != null and fc.current == tree)
	if fc == null:
		t.finish(self)
		return
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	t.eq("the d-pad picks beta", _picked(fc), "beta")
	await _button(JOY_BUTTON_A)
	t.eq("A opens it", fc.current, tree.path_join("beta"))
	t.ok("an empty folder: the list says so, the keys on Add this folder (%s)" % _owner(),
		fc.folders.is_empty() and fc.list.item_count == 1 and fc.list.is_item_disabled(0) and _owner() == "Accept")
	await _button(JOY_BUTTON_Y)
	t.ok("Y goes up, beta picked (%s, %s)" % [fc.current, _picked(fc)], fc.current == tree and _picked(fc) == "beta")
	await _button(JOY_BUTTON_DPAD_UP)
	await _button(JOY_BUTTON_DPAD_UP)
	await _button(JOY_BUTTON_DPAD_UP)
	await _button(JOY_BUTTON_DPAD_UP)
	t.ok("the d-pad Up past the first folder reaches Up a folder (%s)" % _owner(), _owner() == "Up")
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	t.eq("the d-pad Down past the last folder reaches Add this folder", _owner(), "Accept")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	t.eq("Right: Cancel", _owner(), "Cancel")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_DPAD_DOWN)
	t.eq("the keys stay in the box", _owner(), "Cancel")
	await _button(JOY_BUTTON_B)
	t.ok("B cancels", l.folder_chooser == null)
	await _frames(2)
	t.eq("back on Add a folder", _owner(), "AddFolder")
	t.ok("nothing was added", (l.settings.get_value("game_folders") as Array).is_empty())

	# ---- mouse
	await _click(add.get_global_rect().get_center())
	fc = l.folder_chooser
	t.ok("a click on Add a folder opens it", fc != null)
	if fc == null:
		t.finish(self)
		return
	await _frames(3)
	var r: Rect2 = fc.list.get_item_rect(2)
	await _click(fc.list.get_global_rect().position + r.get_center())
	t.eq("a click picks alpha", _picked(fc), "alpha")
	await _click(fc.list.get_global_rect().position + r.get_center(), true)
	t.eq("a double click opens it", fc.current, tree.path_join("alpha"))
	await _click(fc.up_button.get_global_rect().get_center())
	t.eq("a click on Up a folder goes up", fc.current, tree)
	var behind: Vector2 = (l.tiles["keen1"] as Control).get_global_rect().position + Vector2(4, 40)
	await _click(behind)
	t.ok("a click beside the box, on a tile behind it, does nothing (%s)" % _owner(), l.folder_chooser == fc and fc.is_ancestor_of(root.gui_get_focus_owner()))
	await _click(fc.cancel_button.get_global_rect().get_center())
	t.ok("a click on Cancel closes it", l.folder_chooser == null)

	# ---- layout at two window sizes (the long folder's path is the longest)
	l.extra_folders = PackedStringArray([tree.path_join(LONG)])
	l._pick_folder()
	fc = l.folder_chooser
	for win: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = win
		await _frames(6)
		_check_layout(fc, win)
	fc.open(tree)
	await _frames(3)
	var li: int = fc.folders.find(LONG)
	t.ok("a long folder name: the list keeps it whole, ends it in … where it doesn't fit, whole in its tooltip",
		li >= 0 and fc.list.get_item_text(li) == LONG and fc.list.get_item_tooltip(li) == LONG and fc.list.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS)
	l.close_chooser()
	root.size = Vector2i(1280, 720)
	await _frames(4)

	# ---- the games here, and Start adds the folder shown: saved and scanned
	l.extra_folders = PackedStringArray([_norm(data)])
	add.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	fc = l.folder_chooser
	t.ok("the development copies' folder: all seven named (%s)" % (fc.note_label.text if fc != null else "no chooser"),
		fc != null and await _wait(func() -> bool: return not fc.looking, 30.0) and fc.note_label.text.contains("Keen 1, Keen 2, Keen 3, Keen 4, Keen 5, Keen 6, Keen Dreams found here"))
	if fc == null:
		t.finish(self)
		return
	var k4: int = fc.folders.find("keen4")
	for i: int in range(k4):
		await _button(JOY_BUTTON_DPAD_DOWN)
	t.eq("the d-pad to keen4", _picked(fc), "keen4")
	await _button(JOY_BUTTON_A)
	var k4_dir: String = _norm(data).path_join("keen4")
	t.eq("A opens it", fc.current, k4_dir)
	t.ok("Keen 4 found here, in green (%s)" % fc.note_label.text, await _wait(func() -> bool: return not fc.looking, 30.0)
		and fc.note_label.text == "Keen 4 found here." and fc.note_label.get_theme_color("font_color") == MegaTheme.ega(10))
	await _button(JOY_BUTTON_START)
	t.ok("Start adds the folder shown: the chooser gone", l.folder_chooser == null)
	var saved: Array = Settings.new(l.settings_path).get_value("game_folders")
	t.eq("saved in the settings file", saved, [k4_dir])
	t.ok("scanned: Keen 4's tile found there", await _wait(func() -> bool: return l.states.get("keen4", "") == "found", 30.0)
		and str(l.found_results["keen4"].folder) == k4_dir)
	t.ok("and no other game (Steam and GOG find nothing here)", l.states.get("keen1", "") == "missing")

	# ---- the export's choosers
	l._pick_export_target(false)
	fc = l.folder_chooser
	t.ok("To a folder: Export here, no games line, what it does (%s)" % (fc.note_label.text if fc != null else ""),
		fc != null and fc.accept_button.text == "Export here" and not fc.look_for_games and fc.note_label.text.contains("goes inside the folder shown"))
	await _button(JOY_BUTTON_B)
	t.ok("B closes it", l.folder_chooser == null)
	l._pick_export_target(true)
	fc = l.folder_chooser
	if fc != null:
		fc.open(tree)
		var said_new: String = fc.note_label.text
		var f: FileAccess = FileAccess.open(tree.path_join(GameExporter.FOLDER + ".zip"), FileAccess.WRITE)
		f.close()
		fc.open(tree)
		t.ok("As a ZIP: Save the ZIP here, says whether the ZIP is already there (%s / %s)" % [said_new, fc.note_label.text],
			fc.accept_button.text == "Save the ZIP here" and said_new == "Saved here as %s.zip." % GameExporter.FOLDER
			and fc.note_label.text.contains("already here"))
		await _key(KEY_ESCAPE)
	t.ok("Escape closes it", l.folder_chooser == null)

	l.queue_free()
	await _frames(2)
	_remove(base)
	t.finish(self)


## Every text in the box inside its control, the box inside the window, the font readable, rows to see.
func _check_layout(fc: FolderChooser, win: Vector2i) -> void:
	var tag: String = "%dx%d" % [win.x, win.y]
	t.ok("%s: the box inside the window" % tag, Rect2(Vector2.ZERO, Vector2(win)).encloses(fc.box.get_global_rect()))
	var bad: PackedStringArray = PackedStringArray()
	for c: Node in fc.find_children("*", "Control", true, false):
		if not (c as Control).is_visible_in_tree():
			continue
		if c is Label:
			var lb: Label = c
			if lb.text == "":
				continue
			if lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
				if lb.get_visible_line_count() < lb.get_line_count() or lb.size.y + 0.5 < lb.get_minimum_size().y:
					bad.append("%s (wrapped, cut)" % lb.name)
			else:
				var w: float = lb.get_theme_font("font").get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x
				if w > lb.size.x + 0.5:
					bad.append("%s (%.0f > %.0f)" % [lb.name, w, lb.size.x])
		elif c is Button:
			var b: Button = c
			var st: StyleBox = b.get_theme_stylebox("normal")
			var w: float = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			if w + st.get_margin(SIDE_LEFT) + st.get_margin(SIDE_RIGHT) > b.size.x + 0.5:
				bad.append("%s (%.0f in %.0f)" % [b.name, w, b.size.x])
	t.ok("%s: no text cut off %s" % [tag, bad], bad.is_empty())
	t.ok("%s: the long path shortened in the middle (%s), whole in its tooltip" % [tag, fc.path_label.text],
		fc.path_label.text.contains("…") and fc.path_label.text.ends_with(LONG.right(8)) and fc.path_label.text.begins_with(fc.current.left(3))
		and fc.path_label.tooltip_text == fc.current)
	t.ok("%s: the font no smaller than the launcher's at 1280x720 (%d)" % [tag, fc.list.get_theme_font_size("font_size")],
		fc.list.get_theme_font_size("font_size") >= MegaTheme.line_size() * 2)
	var row: float = fc.list.get_item_rect(1).position.y - fc.list.get_item_rect(0).position.y    # (a row and its gap)
	var rows: float = (fc.list.size.y - fc.list.get_theme_stylebox("panel").get_minimum_size().y) / maxf(row, 1.0)
	t.ok("%s: ten rows of the list in view or more (%.1f)" % [tag, rows], rows >= 10.0)


func _remove(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	for f: String in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for sub: String in d.get_directories():
		_remove(dir.path_join(sub))
	DirAccess.remove_absolute(dir)
