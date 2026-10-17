# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## V15-03, V15-02, V15-04: Keen Maker's screens driven with real input events as the devices send them
## (Input.parse_input_event): the controller alone from the launcher's Keen Maker button through the game
## picker (a game not found says how to add it), the library (New level, the level saved, its row: edit,
## play, rename typed with the d-pad, duplicate, delete asked first), the editor (the d-pad moves the
## cursor, A paints, B erases, X changes the tool, the shoulders the part, the triggers the kind, Start the
## menu, Y plays from the cursor and back with everything where it was and Keen's run kept as the trail),
## and out again to the launcher, its Keen Maker button focused. The keyboard (arrows, Enter, Ctrl+Z,
## Escape) and the mouse (a click paints) in the editor too. The launcher's own window throughout.
##
## Options: --game_data=<folder>

var t: T = T.new()
var l: Launcher = null


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


func _button(b: JoyButton, device: int = 0) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		e.device = device
		Input.parse_input_event(e)
		await _frames(3)


func _trigger(axis: JoyAxis) -> void:
	for v: float in [1.0, 0.0]:
		var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = v
		Input.parse_input_event(e)
		await _frames(3)


func _key(k: Key, ctrl: bool = false) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.ctrl_pressed = ctrl
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _press_until(b: JoyButton, name: String, most: int) -> bool:
	for i: int in range(most):
		if _owner() == name:
			return true
		await _button(b)
	return _owner() == name


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	root.size = Vector2i(1280, 720)
	l = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = OS.get_temp_dir().path_join("mr_lock_maker04_%d" % Time.get_ticks_usec())
	l.settings_path = OS.get_temp_dir().path_join("mr_maker04_%d.cfg" % Time.get_ticks_usec())
	root.add_child(l)
	await _frames(3)
	l.show_results([
		{"id": "keen1", "title": "Commander Keen 1", "version": "v1.31 EGA", "status": "ok", "folder": root_dir.path_join("keen1"), "message": "", "exe": "KEEN1.EXE"},
		{"id": "keen4", "title": "Commander Keen 4", "version": "v1.4 EGA", "status": "ok", "folder": root_dir.path_join("keen4"), "message": "", "exe": "KEEN4E.EXE"}])
	await _frames(3)
	# the way in: the launcher's Keen Maker button, by the controller
	l.maker_button.grab_focus()
	await _frames(2)
	await _button(JOY_BUTTON_A)
	var m: MakerScreen = l.maker
	t.ok("A on Keen Maker opens the maker in the launcher's window (the launcher's page hidden)", m != null and m.get_parent() == l and not l._page.visible)
	if m == null:
		t.finish(self)
		return
	await _frames(3)
	t.ok("the game picker: the first game found focused (%s), %d found" % [_owner(), m.found.size()], m.page == "games" and _owner() == "keen1" and m.found.size() == 2)
	# a game not found: says how to add it
	await _button(JOY_BUTTON_DPAD_DOWN)
	t.eq("the d-pad moves to Keen 2", _owner(), "keen2")
	await _button(JOY_BUTTON_A)
	var q: Label = m.dialog.find_child("Question", true, false) as Label if m.dialog != null else null
	t.ok("Keen 2, not found, says how to add it (%s...)" % (q.text.substr(0, 60) if q != null else "nothing"), q != null and q.text.contains("not found") and q.text.contains("Add a folder"))
	await _button(JOY_BUTTON_A)
	t.ok("A closes it, Keen 2 focused again (%s)" % _owner(), m.dialog == null and _owner() == "keen2")
	await _button(JOY_BUTTON_DPAD_UP)
	await _button(JOY_BUTTON_A)
	t.ok("A on Keen 1 opens its library (%s), New level focused (%s)" % [m.page, _owner()], await _wait(func() -> bool: return m.page == "library", 30.0) and await _wait(func() -> bool: return _owner() == "NewLevel", 2.0))
	# a new level, in the editor
	await _button(JOY_BUTTON_A)
	t.ok("New level: the editor with a new level (%s)" % m.page, m.page == "editor" and m.model.level != null and m.model.origin == "new")
	await _frames(5)
	var v: MakerView = m.view
	var start: Vector2i = m.model.start_at()
	t.eq("the cursor starts on Keen's start", v.cursor, start)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_DPAD_UP)
	var c: Vector2i = start + Vector2i(2, -1)
	t.eq("the d-pad moves the cursor (two right, one up)", v.cursor, c)
	var cat0: int = m.palette.category
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	t.eq("RT: the next kind of part", m.palette.category, cat0 + 1)
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	t.ok("RB twice: the third part of %s (%s)" % [m.palette.current().get("name", ""), m.palette.part_name()], m.palette.index == 2 and m.palette.category == cat0)
	var part: Array = m.palette.part()
	await _button(JOY_BUTTON_A)
	t.ok("A paints the part at the cursor (%s: %d)" % [part, m.model.level.get_word(part[0], c.x, c.y)], m.model.level.get_word(part[0], c.x, c.y) == part[1])
	await _button(JOY_BUTTON_B)
	t.eq("B erases it", m.model.level.get_word(part[0], c.x, c.y), 0 if m.model.engine != KeenLevel.VORTICONS or part[0] != 0 else int(m.model.tile_defaults.background))
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_X)
	t.eq("X: the next tool", v.tool, "brush")
	for i: int in range(6):
		await _button(JOY_BUTTON_X)
	t.eq("X round to paint again", v.tool, "paint")
	# the keyboard: arrows, Enter, Ctrl+Z
	await _key(KEY_RIGHT)
	var k: Vector2i = c + Vector2i(1, 0)
	t.eq("the right arrow moves the cursor", v.cursor, k)
	await _key(KEY_ENTER)
	t.eq("Enter paints", m.model.level.get_word(part[0], k.x, k.y), part[1])
	await _key(KEY_Z, true)
	t.ok("Ctrl+Z undoes it", m.model.level.get_word(part[0], k.x, k.y) != part[1] and m.model.level.get_word(part[0], c.x, c.y) == part[1])
	# the mouse: a click paints the cell under it
	var target: Vector2i = c + Vector2i(-3, 0)
	var at: Vector2 = v.get_global_rect().position + (Vector2(target * 16) - v.scroll) * v.zoom + Vector2(4, 4)
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await _frames(3)
	t.eq("a click paints the cell under the pointer", m.model.level.get_word(part[0], target.x, target.y), part[1])
	# play from the cursor (Y) and back, everything where it was
	var level_before: KeenLevel = m.model.level.copy()
	var zoom: float = v.zoom
	var scroll: Vector2 = v.scroll
	await _button(JOY_BUTTON_Y)
	t.ok("Y plays from the cursor (the game running)", await _wait(func() -> bool: return m.host != null and m.host.thread != null, 20.0))
	t.ok("the maker's screen is hidden while the game plays", not m._body.visible)
	await _wait(func() -> bool: return m.model.trail.size() >= 1, 20.0)
	if m.host != null:
		m.host.stop()
	await _wait(func() -> bool: return m.host == null, 15.0)
	await _frames(3)
	t.ok("back in the editor: the level, the cursor, the zoom and the view as they were (%s %s %s %s / %s %s %s)" % [level_before.plane_difference(m.model.level),
		v.cursor, v.zoom, v.scroll, target, zoom, scroll], m.page == "editor" and m._body.visible
		and level_before.plane_difference(m.model.level) == "" and v.cursor == target and v.zoom == zoom and v.scroll == scroll)
	t.ok("Keen's run kept as the trail, starting where he was set down (%d positions, first %s, the cursor %s)" % [m.model.trail.size(), m.model.trail[0] if not m.model.trail.is_empty() else "none", target],
		not m.model.trail.is_empty() and absf(m.model.trail[0].x - (target.x + 0.5)) < 1.0 and absf(m.model.trail[0].y - (target.y + 1.5)) < 1.0)
	# a rule refused at once with its reason: Keen's start picked up and painted elsewhere
	v.set_cursor(m.model.start_at())
	await _button(JOY_BUTTON_X)
	await _button(JOY_BUTTON_X)
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_A)
	t.ok("Keen's start picked and painted again is refused with a reason (%s)" % m.status.text, m.status.text.begins_with("Can't: Keen starts in one place")
		and m.model.level.get_word(1, v.cursor.x, v.cursor.y) == 0)
	t.ok("the status shows the objects meter (%s)" % m.status.text, m.status.text.contains("objects 0/69"))
	# the menu: Save (Start, then the d-pad)
	await _button(JOY_BUTTON_START)
	t.ok("Start opens the menu (%s)" % _owner(), m.dialog != null and _owner() == "Ask_Back_to_editing")
	t.ok("the d-pad reaches Save", await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Save", 6))
	await _button(JOY_BUTTON_A)
	var saved: Array = MakerLibrary.list("keen1")
	t.ok("A saves it into the library (%s)" % [saved], saved.size() == 1 and not m.model.dirty and m.dialog == null)
	# the level's settings: the slot it plays as
	await _button(JOY_BUTTON_START)
	t.ok("the d-pad reaches Level settings", await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Level_settings", 12))
	await _button(JOY_BUTTON_A)
	t.ok("Level settings: the level slots, level 1 focused (%s)" % _owner(), m.page == "slots" and await _wait(func() -> bool: return _owner() == "Slot_1", 2.0))
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	t.ok("the next slot chosen: back in the editor, playing as level 2, not yet saved", m.page == "editor" and m.model.number == 2 and m.model.dirty)
	await _key(KEY_ESCAPE)
	t.ok("Escape opens the menu too", m.dialog != null)
	t.ok("the d-pad reaches Back to your levels", await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Back_to_your_levels", 12))
	await _button(JOY_BUTTON_A)
	t.ok("leaving saved it without asking (slot %s in the library)" % [MakerLibrary.list("keen1")[0].slot], m.dialog == null and not m.model.dirty
		and int(MakerLibrary.list("keen1")[0].slot) == 2)
	var row: String = "Level_" + str(saved[0].path).get_file().get_basename() if not saved.is_empty() else "?"
	t.ok("back in the library, the level's row focused (%s)" % _owner(), m.page == "library" and await _wait(func() -> bool: return _owner() == row, 2.0))
	# the row: duplicate, rename by the d-pad, delete asked first
	await _button(JOY_BUTTON_A)
	t.ok("A on the row: its choices (%s)" % _owner(), m.dialog != null and _owner() == "Ask_Edit")
	t.ok("the d-pad reaches Duplicate", await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Duplicate", 6))
	await _button(JOY_BUTTON_A)
	t.eq("duplicated: two levels", MakerLibrary.list("keen1").size(), 2)
	m._on_level_button(str(saved[0].path))
	await _frames(2)
	t.ok("the d-pad reaches Share", await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Share", 8))
	await _button(JOY_BUTTON_A)
	t.ok("Share on a level not yet cleared says to finish it first (%s)" % m.status.text, m.status.text.contains("Finish it from Keen's start"))
	m._on_level_button(str(saved[0].path))
	await _frames(2)
	await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Rename", 6)
	await _button(JOY_BUTTON_A)
	t.ok("Rename: the name box (%s)" % _owner(), _owner() == "Name")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_DPAD_UP)
	await _button(JOY_BUTTON_DPAD_UP)
	await _button(JOY_BUTTON_A)
	var names: Array = MakerLibrary.list("keen1").map(func(e: Dictionary) -> String: return e.name)
	t.ok("the d-pad typed a letter on the end, A kept it (%s)" % [names], names.has("My level 1B"))
	m._on_level_button(str(saved[0].path))
	await _frames(2)
	await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Delete", 6)
	await _button(JOY_BUTTON_A)
	t.ok("Delete asks first, Keep it focused (%s)" % _owner(), m.dialog != null and _owner() == "Ask_Keep_it")
	await _button(JOY_BUTTON_B)
	t.eq("B keeps it", MakerLibrary.list("keen1").size(), 2)
	m._on_level_button(str(saved[0].path))
	await _frames(2)
	await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Delete", 6)
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	t.eq("Delete, then Delete: one level left", MakerLibrary.list("keen1").size(), 1)
	# a level shared by someone else, in the inbox, brought in by the button
	var other: MakerModel = MakerModel.new()
	other.open("keen1", root_dir.path_join("keen1"))
	other.new_level("From a friend")
	other.cleared_hash = other.fingerprint()
	DirAccess.make_dir_recursive_absolute(MakerLibrary.inbox_dir())
	var fa: FileAccess = FileAccess.open(MakerLibrary.inbox_dir().path_join("friend.keenlevel"), FileAccess.WRITE)
	fa.store_string(other.share_text())
	fa.close()
	for round: int in range(2):
		(m._page_box.find_child("NewLevel", true, false) as Control).grab_focus()
		await _frames(2)
		await _press_until(JOY_BUTTON_DPAD_RIGHT, "BringIn", 3)
		await _button(JOY_BUTTON_A)
		t.ok("Bring in shared levels opens the launcher's folder chooser at the inbox (%s)" % (m.chooser.current if m.chooser != null else "none"),
			m.chooser != null and m.chooser.current.replace("\\", "/").to_lower().trim_suffix("/") == MakerLibrary.inbox_dir().replace("\\", "/").to_lower().trim_suffix("/"))
		await _button(JOY_BUTTON_START)
		var brought: Array = MakerLibrary.list("keen1").map(func(e: Dictionary) -> String: return e.name)
		t.ok("Start chooses the folder: its shared level brought in, once only (round %d: %s; %s)" % [round + 1, brought, m.status.text.substr(0, 40)],
			m.chooser == null and brought.size() == 2 and brought.has("From a friend"))
	# Share on a cleared level: the folder chooser, then the file written in the folder chosen
	other.doc_name = "Cleared one"
	other.save_doc()
	await _frames(2)
	m.share(other.path)
	await _frames(3)
	t.ok("Share on a cleared level opens the folder chooser (%s)" % (m.chooser.title_text if m.chooser != null else "none"), m.chooser != null)
	await _button(JOY_BUTTON_START)
	var shared: String = MakerLibrary.shared_dir().path_join("keen1_Cleared_one.keenlevel")
	t.ok("Start chooses the folder: the level's file written there (%s)" % m.status.text.substr(0, 60), m.chooser == null and FileAccess.file_exists(shared))
	# play from the library
	var left: String = "Level_" + str(MakerLibrary.list("keen1")[0].path).get_file().get_basename()
	await _press_until(JOY_BUTTON_DPAD_DOWN, left, 4)
	# the level played is the one in focus (two saved in the same second may list either way round)
	if _owner().begins_with("Level_"):
		left = _owner()
	await _button(JOY_BUTTON_A)
	await _press_until(JOY_BUTTON_DPAD_DOWN, "Ask_Play", 3)
	await _button(JOY_BUTTON_A)
	t.ok("Play from the library runs the level", await _wait(func() -> bool: return m.host != null and m.host.thread != null, 20.0))
	if m.host != null:
		m.host.stop()
	await _wait(func() -> bool: return m.host == null, 15.0)
	await _frames(3)
	t.ok("and comes back to the library (%s, want %s)" % [_owner(), left], m.page == "library" and _owner() == left)
	# out: B to the games, B out to the launcher
	await _button(JOY_BUTTON_B)
	t.ok("B: back to the games, Keen 1 focused (%s)" % _owner(), m.page == "games" and _owner() == "keen1")
	await _button(JOY_BUTTON_B)
	await _frames(3)
	t.ok("B again: the launcher, its Keen Maker button focused (%s)" % _owner(), l.maker == null and l._page.visible and _owner() == "KeenMaker")
	l.queue_free()
	await _frames(2)
	# the page sizes (the user, 2026-10-13): never smaller than the launcher's at 720p, a step smaller from 1080p up
	var sizes: Array = [[Vector2(1280, 720), 2, 2], [Vector2(1920, 1080), 4, 3], [Vector2(3840, 2160), 8, 7]]
	for sz: Array in sizes:
		t.ok("at %s: the launcher's scale %d, Keen Maker's %d" % [sz[0], MegaTheme.pixel_scale(sz[0]), MakerScreen.ui_scale(sz[0])],
			MegaTheme.pixel_scale(sz[0]) == sz[1] and MakerScreen.ui_scale(sz[0]) == sz[2])
	t.finish(self)
