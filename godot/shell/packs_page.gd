# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name PacksPage
extends PanelContainer
## V15-01 replacement packs, a page of the launcher (opened from the main screen, in the same window;
## Back returns there). Per game the player owns: the packs in its mods folder (AssetPacks.mods_dir),
## each switched on or off and moved up or down (a later pack wins where two replace the same picture),
## kept in the "packs" setting; the folder opened for the player; and the export tool, which writes the
## game's pictures as templates (a PNG per sprite named as a pack wants it, a sheet per set with its
## grid) into the player's own folder. Every control is a button: keys, a pad and the mouse all work.

signal closed

var settings: Settings = null
var found: Dictionary = {}
var titles: Dictionary = {}
var game: String = ""
var title_label: Label
var list_box: VBoxContainer
var status: Label
var first_button: Button
var back_button: Button


func _init() -> void:
	name = "PacksPage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(s: Settings, found_games: Dictionary, game_titles: Dictionary, first: String) -> void:
	settings = s
	found = found_games
	titles = game_titles
	_build()
	_show_game(first if found.has(first) else (found.keys()[0] if not found.is_empty() else ""))
	first_button.grab_focus()


func _build() -> void:
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	first_button = _button(top, "PrevGame", "<", func() -> void: _step_game(-1))
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", MegaTheme.ega(14))
	top.add_child(title_label)
	_button(top, "NextGame", ">", func() -> void: _step_game(1))
	col.add_child(top)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	list_box = VBoxContainer.new()
	list_box.name = "Packs"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	col.add_child(scroll)
	status = Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", MegaTheme.ega(11))
	col.add_child(status)
	var row: HFlowContainer = HFlowContainer.new()
	_button(row, "OpenFolder", "Open the mods folder", func() -> void:
		DirAccess.make_dir_recursive_absolute(AssetPacks.mods_dir(game))
		OS.shell_open(AssetPacks.mods_dir(game)))
	_button(row, "Export", "Export templates", _export)
	back_button = _button(row, "Back", "Back", func() -> void: closed.emit())
	col.add_child(row)


func _button(parent: Control, n: String, text: String, f: Callable) -> Button:
	var b: Button = Button.new()
	b.name = n
	b.text = text
	b.pressed.connect(f)
	parent.add_child(b)
	return b


func _step_game(d: int) -> void:
	var ids: Array = []
	for g: String in titles:
		if found.has(g):
			ids.append(g)
	if not ids.is_empty():
		_show_game(ids[(ids.find(game) + d + ids.size()) % ids.size()])


func _show_game(id: String) -> void:
	game = id
	title_label.text = "Asset packs: " + (String(titles.get(id, id)) if id != "" else "no game found yet")
	status.text = ("Put a pack in %s, a folder of PNG pictures named as the templates are (the same size, or 2x, 3x, 4x " +
		"for more detail in Enhanced). Later packs win.") % AssetPacks.mods_dir(id) if id != "" else ""
	_fill()


## The packs as rows: on/off, the name, up, down.
func _fill() -> void:
	for c: Node in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	if game == "":
		return
	var packs: Array = AssetPacks.listing(settings, game)
	if packs.is_empty():
		var l: Label = Label.new()
		l.text = "No packs yet."
		list_box.add_child(l)
	for i: int in range(packs.size()):
		var e: Array = packs[i]
		var r: HBoxContainer = HBoxContainer.new()
		r.name = "Pack%d" % i
		var on: CheckButton = CheckButton.new()
		on.name = "On"
		on.text = e[0]
		on.button_pressed = e[1]
		on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		on.toggled.connect(func(v: bool) -> void:
			packs[i][1] = v
			_save(packs))
		r.add_child(on)
		_button(r, "Up", "Up", func() -> void: _move(packs, i, -1))
		_button(r, "Down", "Down", func() -> void: _move(packs, i, 1))
		list_box.add_child(r)


func _move(packs: Array, i: int, d: int) -> void:
	var j: int = i + d
	if j < 0 or j >= packs.size():
		return
	var e: Array = packs[i]
	packs[i] = packs[j]
	packs[j] = e
	_save(packs)
	_fill()
	var row: Node = list_box.get_child(j)
	(row.get_node("Up" if d < 0 else "Down") as Button).grab_focus()


func _save(packs: Array) -> void:
	settings.set_value("packs", packs, game)
	settings.save()


## The export tool: the game's pictures, as they are, into the player's templates folder.
func _export() -> void:
	if game == "":
		return
	var d: Object = AssetPacks.load_data(found[game])
	if d == null:
		status.text = "The game's files could not be read."
		return
	var where: String = AssetPacks.export_templates(d.stage, AssetPacks.sprites_of(d))
	status.text = ("Templates written to %s: sprites/ has a picture per sprite, named as a pack wants it; sheets/ a sheet per set with its grid." % where
		if where != "" else "The templates folder could not be written.")
