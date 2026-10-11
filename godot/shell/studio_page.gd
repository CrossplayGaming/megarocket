# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name StudioPage
extends PanelContainer
## V15-05 the Asset Studio, a page of the launcher (opened from the main screen in the same window, as
## Keen's Closet is; Back returns there with the focus on its button). The user's picture of it
## (2026-10-11): "a user interface much like Keen's Closet ... scroll through the assets, perhaps in
## different categories. And when they hit one, they can drag and put in a new asset to replace it with the
## correct file type. Or have a browser open for them to find."
##
## Per game the player owns: the categories down the side (AssetStudio.categories: Keen, the creatures by
## family, items, shots and effects, the rest), the category's sprites in a scrolling grid drawn from the
## player's own files (the picture the game shows now, its name, its size and its frame of the animation),
## and the picked one in the inspector: the original and what the game shows now side by side, the
## animation moving, its size, frame, colours (EGA) and see-through pixels, and which pack replaces it.
## Replace... opens Megarocket's own chooser on PNG pictures (the last folder used, else Pictures, else
## Downloads); a PNG dropped on the window replaces the picked sprite, several dropped replace the sprites
## their names name; each is checked at once (AssetStudio.check: a PNG, the sprite's size or a whole
## multiple, what is see-through) and refused with a plain message, else saved into My pack. Export
## template writes the sprite's PNG into the player's templates folder; Revert takes My pack's picture
## out. Export my pack... writes My pack to share (a folder and a ZIP); Bring in a pack... takes a shared
## ZIP or folder back in. The Asset packs page (on/off, order, every template) stays as it was, a button
## away. Every control is a button: the keys, a pad (the launcher's shim) and the mouse all work; dropping
## files is the mouse's alone, and Replace... does the same by keys and pad.

signal closed
## The Asset packs page asked for (the launcher shows it in place of this page).
signal packs_wanted

## The animation's pace: a frame every this many seconds (the games' walk cycles are near it)
const FRAME_TIME: float = 0.12

var settings: Settings = null
var found: Dictionary = {}
var titles: Dictionary = {}
var game: String = ""
var pixel: int = 1
var studio: AssetStudio = null
var category: int = -1
## The sprite in the inspector ("" for none)
var picked: String = ""
## The chooser's host (the launcher's open_chooser(fc) and close_chooser()); without them the page holds
## the chooser itself.
var open_chooser_fn: Callable = Callable()
var close_chooser_fn: Callable = Callable()
var chooser: FolderChooser = null

var title_label: Label
var first_button: Button
var cat_box: VBoxContainer
var grid: GridContainer
var grid_scroll: ScrollContainer
var tiles: Dictionary = {}          # name -> Button
var name_label: Label
var before_rect: TextureRect
var after_rect: TextureRect
var moving_rect: TextureRect
var info_label: Label
var colours_row: HFlowContainer
var pack_label: Label
var replace_button: Button
var template_button: Button
var revert_button: Button
var message: Label
var back_button: Button
var packs_button: Button
var share_button: Button
var bring_button: Button
var _moving: Array = []             # the picked sprite's animation, textures
var _tick: int = 0
var _timer: Timer


func _init() -> void:
	name = "StudioPage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _enter_tree() -> void:
	if not get_window().files_dropped.is_connected(drop_files):
		get_window().files_dropped.connect(drop_files)


func _exit_tree() -> void:
	if get_window().files_dropped.is_connected(drop_files):
		get_window().files_dropped.disconnect(drop_files)


## The page for `settings`, the games found (id -> result), their titles, starting on `first`.
func open(s: Settings, found_games: Dictionary, game_titles: Dictionary, first: String, px: int) -> void:
	settings = s
	found = found_games
	titles = game_titles
	pixel = maxi(px, 1)
	_build()
	_show_game(first if found.has(first) else (found.keys()[0] if not found.is_empty() else ""))
	first_button.grab_focus()


func _build() -> void:
	var s: int = pixel
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	add_child(m)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 4 * s)
	m.add_child(col)
	# the game
	var top: HBoxContainer = HBoxContainer.new()
	first_button = _button(top, "PrevGame", "<", func() -> void: _step_game(-1))
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_color_override("font_color", MegaTheme.ega(14))
	top.add_child(title_label)
	_button(top, "NextGame", ">", func() -> void: _step_game(1))
	col.add_child(top)
	# the categories, the grid, the inspector
	var mid: HBoxContainer = HBoxContainer.new()
	mid.name = "Middle"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4 * s)
	col.add_child(mid)
	var cat_scroll: ScrollContainer = ScrollContainer.new()
	cat_scroll.name = "CategoryScroll"
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.follow_focus = true
	cat_scroll.custom_minimum_size.x = 96 * s
	mid.add_child(cat_scroll)
	cat_box = VBoxContainer.new()
	cat_box.name = "Categories"
	cat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.add_child(cat_box)
	grid_scroll = ScrollContainer.new()
	grid_scroll.name = "GridScroll"
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.follow_focus = true
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.resized.connect(_fit_columns)
	mid.add_child(grid_scroll)
	grid = GridContainer.new()
	grid.name = "Assets"
	grid.add_theme_constant_override("h_separation", 2 * s)
	grid.add_theme_constant_override("v_separation", 2 * s)
	grid_scroll.add_child(grid)
	mid.add_child(_build_inspector())
	# what happened, and the page's own buttons
	message = Label.new()
	message.name = "Message"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = MegaTheme.line_size() * s * 2
	col.add_child(message)
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "Buttons"
	back_button = _button(row, "Back", "Back", func() -> void: closed.emit())
	packs_button = _button(row, "Packs", "Asset packs", func() -> void: packs_wanted.emit())
	share_button = _button(row, "Share", "Export my pack...", _share_dialog)
	bring_button = _button(row, "Bring", "Bring in a pack...", _bring_dialog)
	col.add_child(row)
	var hints: Label = Label.new()
	hints.name = "Hints"
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.add_theme_color_override("font_color", MegaTheme.ega(7))
	hints.text = "Drop a PNG on the window to replace the picked picture (several named as pictures replace each)."
	col.add_child(hints)
	_timer = Timer.new()
	_timer.wait_time = FRAME_TIME
	_timer.timeout.connect(_animate)
	add_child(_timer)
	_timer.start()


func _build_inspector() -> Control:
	var s: int = pixel
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Inspector"
	box.custom_minimum_size.x = 168 * s
	box.add_theme_constant_override("separation", 2 * s)
	name_label = Label.new()
	name_label.name = "AssetName"
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", MegaTheme.ega(14))
	box.add_child(name_label)
	var pics: HBoxContainer = HBoxContainer.new()
	pics.name = "Pictures"
	pics.add_theme_constant_override("separation", 4 * s)
	var rects: Array[TextureRect] = []
	for cap: String in ["Original", "Now", "Moving"]:
		var v: VBoxContainer = VBoxContainer.new()
		var tr: TextureRect = TextureRect.new()
		tr.name = cap
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(52, 56) * s
		v.add_child(tr)
		var l: Label = Label.new()
		l.text = cap
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", MegaTheme.ega(7))
		v.add_child(l)
		pics.add_child(v)
		rects.append(tr)
	before_rect = rects[0]
	after_rect = rects[1]
	moving_rect = rects[2]
	box.add_child(pics)
	info_label = Label.new()
	info_label.name = "Info"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_label)
	colours_row = HFlowContainer.new()
	colours_row.name = "Colours"
	colours_row.add_theme_constant_override("h_separation", s)
	box.add_child(colours_row)
	pack_label = Label.new()
	pack_label.name = "Pack"
	pack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(pack_label)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.name = "AssetButtons"
	replace_button = _button(buttons, "Replace", "Replace...", _replace_dialog)
	template_button = _button(buttons, "Template", "Export template", _export_template)
	revert_button = _button(buttons, "Revert", "Revert", _revert)
	box.add_child(buttons)
	return box


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


## A game's sprites from the player's files, its categories down the side, the first shown.
func _show_game(id: String) -> void:
	game = id
	studio = null
	picked = ""
	for c: Node in cat_box.get_children():
		cat_box.remove_child(c)
		c.queue_free()
	_clear_grid()
	_show_picked()
	if id == "":
		title_label.text = "Asset Studio: no game found yet (add your games on the main screen)"
		return
	title_label.text = "Asset Studio: " + String(titles.get(id, id))
	studio = AssetStudio.open(found[id])
	if studio == null:
		_say("The game's files could not be read.", 12)
		return
	studio.refresh(settings)
	var creatures_shown: bool = false
	for i: int in range(studio.categories.size()):
		var c: Array = studio.categories[i]
		if c[2] == "creature" and not creatures_shown:
			var head: Label = Label.new()
			head.text = "Creatures"
			head.add_theme_color_override("font_color", MegaTheme.ega(7))
			cat_box.add_child(head)
			creatures_shown = true
		var b: Button = _button(cat_box, "Cat%d" % i, String(c[0]), func() -> void: _enter_category(i))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = "%s: %d pictures" % [c[0], (c[1] as PackedStringArray).size()]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(func() -> void: show_category(i))
	# up and down stay in the list (the grid beside it is to the right)
	var cats: Array[Button] = []
	for c: Node in cat_box.get_children():
		if c is Button:
			cats.append(c)
	for k: int in range(cats.size()):
		cats[k].focus_neighbor_top = (cats[k - 1] if k > 0 else first_button).get_path()
		cats[k].focus_neighbor_bottom = (cats[k + 1] if k + 1 < cats.size() else back_button).get_path()
	_say("%d pictures of %s. Pick one to see it; Replace... or drop a PNG on the window to put in your own." % [
		studio.order.size(), FolderChooser.short_name(id)], 11)
	category = -1
	show_category(0)


## The category's sprites in the grid (the one shown marked in its colour).
func show_category(i: int) -> void:
	if studio == null or i < 0 or i >= studio.categories.size() or i == category:
		return
	category = i
	for c: Node in cat_box.get_children():
		if c is Button:
			(c as Button).add_theme_color_override("font_color", MegaTheme.ega(14) if c.name == "Cat%d" % i else MegaTheme.ega(15))
	_clear_grid()
	for nm: String in studio.categories[i][1]:
		grid.add_child(_tile(nm))
	_fit_columns()
	# Right from the category goes to its first picture, Left from the grid's first column back to it
	var cat: Button = cat_box.get_node("Cat%d" % i)
	if grid.get_child_count() > 0:
		cat.focus_neighbor_right = grid.get_child(0).get_path()
	grid_scroll.scroll_vertical = 0


## A, Enter or a click on a category: the keys go to its first picture.
func _enter_category(i: int) -> void:
	show_category(i)
	if grid.get_child_count() > 0:
		(grid.get_child(0) as Button).grab_focus()


func _clear_grid() -> void:
	tiles = {}
	for c: Node in grid.get_children():
		grid.remove_child(c)
		c.queue_free()


## A grid tile: the picture the game shows now, its name (whole on hover) and its size and frame.
func _tile(nm: String) -> Button:
	var s: int = pixel
	var b: Button = Button.new()
	b.name = nm
	b.custom_minimum_size = Vector2(68, 60) * s
	b.tooltip_text = nm
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 3 * s
	v.offset_right = -3 * s
	v.offset_top = 3 * s
	v.offset_bottom = -3 * s
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var tr: TextureRect = TextureRect.new()
	tr.name = "Picture"
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	for n: String in ["Name", "Size"]:
		var l: Label = Label.new()
		l.name = n
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	b.add_child(v)
	b.focus_entered.connect(func() -> void: pick(nm))
	b.pressed.connect(func() -> void:
		pick(nm)
		replace_button.grab_focus())
	tiles[nm] = b
	_fill_tile(nm)
	return b


func _fill_tile(nm: String) -> void:
	var b: Button = tiles.get(nm)
	if b == null:
		return
	var v: Node = b.get_child(0)
	(v.get_node("Picture") as TextureRect).texture = ImageTexture.create_from_image(studio.shown(nm))
	var nl: Label = v.get_node("Name")
	nl.text = AssetStudio.base(nm)
	nl.add_theme_color_override("font_color", MegaTheme.ega(10) if studio.replaced.has(nm) else MegaTheme.ega(15))
	var spr: Dictionary = studio.sprites[nm]
	var fr: Array = studio.frames_of(nm)
	var count: int = (fr[1] as Array).size()
	(v.get_node("Size") as Label).text = "%dx%d" % [spr.w, spr.h] + (" %d/%d" % [int(fr[0]) + 1, count] if count > 1 else "")
	(v.get_node("Size") as Label).add_theme_color_override("font_color", MegaTheme.ega(7))
	b.tooltip_text = nm + (" (replaced by %s)" % studio.replaced[nm].pack if studio.replaced.has(nm) else "")
	if nm == picked:
		b.add_theme_stylebox_override("normal", MegaTheme.bevel(MegaTheme.ega(11), pixel, Color8(20, 20, 70)))
	else:
		b.remove_theme_stylebox_override("normal")


func _fit_columns() -> void:
	if grid == null:
		return
	var w: float = grid_scroll.size.x - 12.0 * pixel    # (room for the scroll bar)
	grid.columns = maxi(1, int((w + 2 * pixel) / ((68 + 2) * pixel)))
	if category >= 0 and cat_box.has_node("Cat%d" % category):
		var cat: NodePath = cat_box.get_node("Cat%d" % category).get_path()
		for k: int in range(grid.get_child_count()):
			(grid.get_child(k) as Control).focus_neighbor_left = cat if k % grid.columns == 0 else NodePath()


## The sprite `nm` in the inspector.
func pick(nm: String) -> void:
	if studio == null or not studio.sprites.has(nm):
		return
	var was: String = picked
	picked = nm
	if was != "" and tiles.has(was):
		_fill_tile(was)
	_fill_tile(nm)
	_show_picked()


func _show_picked() -> void:
	for c: Node in colours_row.get_children():
		colours_row.remove_child(c)
		c.queue_free()
	_moving = []
	var none: bool = studio == null or picked == ""
	for b: Button in [replace_button, template_button, revert_button]:
		b.disabled = none
	if none:
		name_label.text = "Pick a picture"
		before_rect.texture = null
		after_rect.texture = null
		moving_rect.texture = null
		info_label.text = ""
		pack_label.text = ""
		return
	var spr: Dictionary = studio.sprites[picked]
	name_label.text = picked
	name_label.tooltip_text = picked
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	before_rect.texture = ImageTexture.create_from_image(studio.original(picked))
	after_rect.texture = ImageTexture.create_from_image(studio.shown(picked))
	var fr: Array = studio.frames_of(picked)
	for n: String in fr[1]:
		_moving.append(ImageTexture.create_from_image(studio.shown(n)))
	_animate()
	var cols: Array = studio.colours_used(picked)
	info_label.text = "%dx%d pixels; frame %d of %d. %d colours; %d see-through pixels." % [spr.w, spr.h, int(fr[0]) + 1,
		(fr[1] as Array).size(), cols.size(), studio.clear_pixels(picked)]
	for c: Array in cols:
		var sw: ColorRect = ColorRect.new()
		sw.color = MegaTheme.ega(int(c[0]))
		sw.custom_minimum_size = Vector2(8, 8) * pixel
		sw.tooltip_text = "EGA colour %d: %d pixels" % [c[0], c[1]]
		colours_row.add_child(sw)
	if studio.replaced.has(picked):
		var f: Dictionary = studio.replaced[picked]
		var k: int = int(f.w) / int(spr.w)
		pack_label.text = "Replaced by the pack \"%s\": %dx%d (%s)." % [f.pack, f.w, f.h, "its own size" if k == 1 else "%dx" % k]
		pack_label.add_theme_color_override("font_color", MegaTheme.ega(10))
	else:
		pack_label.text = "The game's own picture." + (" (My pack has one, but My pack is switched off.)" if studio.mine.has(picked) else "")
		pack_label.add_theme_color_override("font_color", MegaTheme.ega(7))
	revert_button.disabled = not studio.mine.has(picked)


func _animate() -> void:
	_tick += 1
	if moving_rect != null:
		moving_rect.texture = _moving[_tick % _moving.size()] if not _moving.is_empty() else null


func _say(text: String, colour: int) -> void:
	message.text = text
	message.add_theme_color_override("font_color", MegaTheme.ega(colour))


# ---- replacing, reverting, the template

## Files dropped on the window (Window.files_dropped): one replaces the picked sprite, several the
## sprites their names name; each checked at once.
func drop_files(paths: PackedStringArray) -> void:
	if studio == null or paths.is_empty() or not is_visible_in_tree():
		return
	replace_with(paths)


func replace_with(paths: PackedStringArray) -> void:
	var r: Array = studio.replace_files(paths, picked, settings)
	var done: PackedStringArray = r[0]
	ShellMessages.note("Asset Studio: " + " | ".join(r[1]))
	_say("\n".join(r[1]), 12 if done.is_empty() else (10 if done.size() == paths.size() else 14))
	_changed(done)


## Tiles and the inspector drawn again after pictures changed.
func _changed(names: PackedStringArray) -> void:
	for nm: String in names:
		_fill_tile(nm)
	for nm: String in tiles:
		if not names.has(nm):
			_fill_tile(nm)
	_show_picked()


## The start of the chooser: the folder a picture was last chosen from, else Pictures, else Downloads.
func _start_folder() -> String:
	var last: String = String(settings.get_value("studio_folder"))
	if last != "" and DirAccess.dir_exists_absolute(last):
		return last
	for d: int in [OS.SYSTEM_DIR_PICTURES, OS.SYSTEM_DIR_DOWNLOADS]:
		var p: String = OS.get_system_dir(d)
		if p != "" and DirAccess.dir_exists_absolute(p):
			return p
	return ""


func _replace_dialog() -> void:
	if studio == null or picked == "":
		return
	var spr: Dictionary = studio.sprites[picked]
	var fc: FolderChooser = FolderChooser.new()
	fc.file_types = PackedStringArray(["png"])
	fc.title_text = "A PNG picture for %s (%dx%d, or 2x, 3x, 4x that)" % [picked, spr.w, spr.h]
	fc.accept_text = "Use this picture"
	fc.start_dir = _start_folder()
	var nm: String = picked
	fc.chosen.connect(func(path: String) -> void:
		settings.set_value("studio_folder", path.get_base_dir())
		settings.save()
		_close_chooser()
		picked = nm
		replace_with(PackedStringArray([path])))
	_open_chooser(fc)


func _export_template() -> void:
	if studio == null or picked == "":
		return
	var path: String = studio.export_template(picked)
	if path == "":
		_say("The template could not be written.", 12)
	else:
		_say("The template for %s is %s: draw over it at this size (or 2x, 3x, 4x), keep its name, and drop it back here or use Replace...." % [
			picked, path], 11)


func _revert() -> void:
	if studio == null or picked == "":
		return
	_say(studio.revert(picked, settings), 11)
	_changed(PackedStringArray([picked]))
	replace_button.grab_focus()


# ---- sharing My pack, bringing a pack in

## The chooser for where a pack goes to be shared (a folder and a ZIP inside the folder shown).
static func share_chooser(game_id: String, pack: String) -> FolderChooser:
	var fc: FolderChooser = FolderChooser.new()
	fc.look_for_games = false
	fc.title_text = "Where to put \"%s\" to share it" % pack
	fc.accept_text = "Share it here"
	fc.note_text = "A folder and a ZIP named \"%s %s\" go inside the folder shown." % [game_id, pack]
	fc.start_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return fc


## The chooser for a shared pack: a ZIP, or the folder it was shared as.
static func bring_chooser(start: String) -> FolderChooser:
	var fc: FolderChooser = FolderChooser.new()
	fc.file_types = PackedStringArray(["zip"])
	fc.allow_folder = true
	fc.title_text = "A shared pack: pick its ZIP, or open its folder"
	fc.accept_text = "Bring in this pack"
	fc.note_text = "With no ZIP picked, the folder shown is brought in."
	fc.start_dir = start
	return fc


func _share_dialog() -> void:
	if studio == null:
		return
	var fc: FolderChooser = share_chooser(game, AssetStudio.MY_PACK)
	fc.chosen.connect(func(dir: String) -> void:
		_close_chooser()
		var r: Dictionary = AssetPacks.export_pack(game, AssetStudio.MY_PACK, dir)
		_say(String(r.message), 10 if r.ok else 12))
	_open_chooser(fc)


func _bring_dialog() -> void:
	var fc: FolderChooser = bring_chooser(_start_folder())
	fc.chosen.connect(func(path: String) -> void:
		_close_chooser()
		bring_in(path))
	_open_chooser(fc)


## A shared pack (a ZIP or a folder) brought in and switched on.
func bring_in(path: String) -> void:
	var r: Dictionary = AssetPacks.import_pack(path, game)
	if r.ok:
		AssetPacks.switch_on(settings, String(r.game), String(r.pack))
		if String(r.game) == game and studio != null:
			studio.refresh(settings)
			_changed(PackedStringArray())
	_say(String(r.message), 10 if r.ok else 12)


func _open_chooser(fc: FolderChooser) -> void:
	chooser = fc
	if open_chooser_fn.is_valid():
		open_chooser_fn.call(fc)
	else:
		fc.canceled.connect(_close_chooser)
		add_child(fc)


func _close_chooser() -> void:
	if chooser == null:
		return
	if close_chooser_fn.is_valid():
		close_chooser_fn.call()
	elif is_instance_valid(chooser):
		chooser.queue_free()
		replace_button.grab_focus()
	chooser = null
