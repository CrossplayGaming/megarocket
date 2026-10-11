# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## V15-05 the Asset Studio, by real input (controller events through Input, files dropped through the
## window's files_dropped signal) on the launcher with Keen 4, pictures made here from shapes (no game
## art), in this run's own player folder (MR_USER_DIR):
## - the launcher keeps its Asset packs button and has an Asset Studio button; A on the Studio opens its
##   page in the window, Keen 4's sprites sorted into categories (Keen, the creatures by family, items,
##   shots and effects, the rest; every sprite in one);
## - the d-pad moves down the categories (the grid shows each), A goes into Items, Right moves along the
##   grid, the picked sprite in the inspector (its size, frame, colours), A on a tile goes to Replace...;
## - a PNG dropped at the sprite's own size is saved in My pack (made, switched on, last) and the stage
##   serves it on the card (each pixel the nearest EGA colour); one at 4x is the native view's picture (the
##   card keeping the original); a wrong size and two files that are not PNG pictures are refused, each
##   with its message, nothing changed; several files named as sprites replace each, an unknown name said;
## - Replace... opens the chooser in file mode on the last folder: only the folders and PNG files listed,
##   the picked picture previewed with its size, A on it replaces the sprite at 2x, the focus back on
##   Replace...; Revert takes it out (the stage's original again); Export template writes the sprite's PNG;
## - Export my pack... (the chooser, Start) writes a folder and a ZIP of My pack's own pictures and its
##   info; Bring in a pack... brings the ZIP, then the folder, back in as new packs, switched on, the same
##   files byte for byte;
## - B goes back to the launcher (the focus on Asset Studio); the Studio's Asset packs button shows the
##   packs page, My pack listed there, which shares a pack (its row's Share...) and brings one in too; B
##   back to the launcher;
## - at 1280x720 and 1920x1080 the page's buttons and lines inside the window, their words whole, five
##   columns of pictures or more.
##
## Options: --game_data=<folder>

var t: T = T.new()
var l: Launcher = null


func _init() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _pad(b: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _owner() -> String:
	var f: Control = root.gui_get_focus_owner()
	return str(f.name) if f != null else "none"


## A picture of shapes: a disc of `a` on a square of `b`, clear corners.
static func _shapes(w: int, h: int, a: Color, b: Color) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		for x: int in range(w):
			var dx: float = (x + 0.5) / w - 0.5
			var dy: float = (y + 0.5) / h - 0.5
			if dx * dx + dy * dy < 0.08:
				img.set_pixel(x, y, a)
			elif absf(dx) < 0.4 and absf(dy) < 0.4:
				img.set_pixel(x, y, b)
	return img


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var found: Dictionary = {"id": "keen4", "title": "Commander Keen 4", "version": "v1.4 EGA", "status": "ok",
		"folder": root_dir.path_join("keen4"), "message": "", "exe": "KEEN4E.EXE"}
	var plain: GalData = AssetPacks.load_data(found)
	if plain == null:
		t.blocked("Keen 4 could not be read")
		t.finish(self)
		return
	var work: String = Settings.user_dir().path_join("studio_work")
	DirAccess.make_dir_recursive_absolute(work.path_join("pics/sub"))
	root.size = Vector2i(1280, 720)
	l = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = Settings.user_dir().path_join("lock_v15_studio")
	l.settings_path = Settings.user_dir().path_join("v15_studio.cfg")
	root.add_child(l)
	await _frames(3)
	l.show_results([found])
	await _frames(3)
	t.ok("the launcher keeps Asset packs and has Asset Studio", l.packs_button != null and l.packs_button.is_visible_in_tree()
		and l.studio_button != null and l.studio_button.is_visible_in_tree())
	l.studio_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	var page: StudioPage = l.studio_page
	t.ok("A on Asset Studio opens its page in the window (focus %s)" % _owner(), page != null and not l._page.visible
		and page.is_inside_tree() and _owner() == "PrevGame")
	if page == null or page.studio == null:
		t.blocked("the Studio did not open on Keen 4")
		t.finish(self)
		return
	var st: AssetStudio = page.studio
	_check_layout(page, "1280x720")
	await _categories(st, page)
	await _grid(st, page, plain, found)
	l.queue_free()
	await _frames(2)
	t.finish(self)


func _categories(st: AssetStudio, page: StudioPage) -> void:
	var labels: PackedStringArray = []
	var total: int = 0
	for c: Array in st.categories:
		labels.append(c[0])
		total += (c[1] as PackedStringArray).size()
	t.ok("Keen 4's categories: Keen first, creatures by family, items, effects, the rest (%s)" % ", ".join(labels),
		labels[0] == "Keen" and labels.has("Dopefish") and labels.has("Lick") and labels.has("Items")
		and labels.has("Shots and effects") and labels[labels.size() - 1] == "Other")
	t.eq("every sprite in one category (sprites, in categories)", [st.order.size(), total], [st.order.size(), st.order.size()])
	t.ok("Keen's frames in Keen, the Dopefish's in its family, gems in items, the stunner's shot in effects",
		(st.categories[0][1] as PackedStringArray).has("SPR_KEENSTANDR")
		and (st.categories[labels.find("Dopefish")][1] as PackedStringArray).has("SPR_DOPEFISHL1")
		and (st.categories[labels.find("Items")][1] as PackedStringArray).has("SPR_GEM_A1")
		and (st.categories[labels.find("Shots and effects")][1] as PackedStringArray).has("SPR_STUN1"))
	t.eq("a run frame's animation", st.frames_of("SPR_KEENRUNR3"), [2, ["SPR_KEENRUNR1", "SPR_KEENRUNR2", "SPR_KEENRUNR3", "SPR_KEENRUNR4"]])
	# the pad down the side
	(page.cat_box.get_node("Cat0") as Button).grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	t.ok("d-pad Down: the next category, the grid shows it (%s, category %d, %d tiles)" % [_owner(), page.category, page.grid.get_child_count()],
		_owner() == "Cat1" and page.category == 1 and page.grid.get_child_count() == (st.categories[1][1] as PackedStringArray).size())
	var items: int = labels.find("Items")
	for i: int in range(60):
		if _owner() == "Cat%d" % items:
			break
		await _pad(JOY_BUTTON_DPAD_DOWN)
	t.eq("down to Items by the d-pad", _owner(), "Cat%d" % items)


func _grid(st: AssetStudio, page: StudioPage, plain: GalData, found: Dictionary) -> void:
	var items: PackedStringArray = []
	for c: Array in st.categories:
		if c[0] == "Items":
			items = c[1]
	await _pad(JOY_BUTTON_A)
	t.ok("A on Items: its first picture has the keys and is in the inspector (%s)" % page.picked, _owner() == items[0] and page.picked == items[0])
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	var nm: String = items[1]
	t.ok("d-pad Right: the next picture picked (%s)" % page.picked, _owner() == nm and page.picked == nm)
	var spr: Dictionary = st.sprites[nm]
	var w: int = int(spr.w)
	var h: int = int(spr.h)
	t.ok("the inspector: name, size, colours (%s | %s)" % [page.name_label.text, page.info_label.text],
		page.name_label.text == nm and page.info_label.text.begins_with("%dx%d pixels" % [w, h])
		and page.colours_row.get_child_count() == st.colours_used(nm).size() and page.colours_row.get_child_count() > 0)
	await _pad(JOY_BUTTON_A)
	t.eq("A on the tile goes to Replace...", _owner(), "Replace")
	var work: String = Settings.user_dir().path_join("studio_work")
	var key: int = int(st.sprites[nm].key)
	var off: int = int(plain.gfx.offSprites)
	var mine: String = st.my_dir().path_join(nm + ".png")

	# own size, dropped
	var one: Image = _shapes(w, h, Color8(250, 250, 90), Color8(10, 10, 160))
	one.save_png(work.path_join("one.png"))
	root.files_dropped.emit(PackedStringArray([work.path_join("one.png")]))
	await _frames(2)
	var packs: Array = l.settings.get_value("packs", "keen4")
	t.ok("a 1x PNG dropped: in My pack, switched on and last (%s)" % [packs], FileAccess.file_exists(mine)
		and not packs.is_empty() and packs[packs.size() - 1] == [AssetStudio.MY_PACK, true])
	t.ok("the message says so (%s)" % page.message.text, page.message.text.contains("replaces %s" % nm) and page.message.text.contains("Saved in My pack"))
	t.ok("the inspector names My pack", page.pack_label.text.contains("My pack"))
	var d: GalData = _with_packs(found)
	var s1: Dictionary = d.sprite(key - off)
	var bad: int = 0
	for y: int in range(h):
		for x: int in range(w):
			var c: Color = one.get_pixel(x, y)
			var want: int = KeenCloset.nearest_ega(c) if c.a >= 0.5 else -1
			var clear: bool = s1.mask[y * w + x] != 0
			if (want < 0) != clear or (want >= 0 and s1.pixels[y * w + x] != want):
				bad += 1
	t.eq("the stage serves it on the card, nearest EGA, pixels off", bad, 0)
	t.ok("and it differs from the original", d.chunk(key) != plain.chunk(key))

	# 4x, dropped
	_shapes(w * 4, h * 4, Color8(255, 85, 255), Color8(0, 170, 170)).save_png(work.path_join("four.png"))
	root.files_dropped.emit(PackedStringArray([work.path_join("four.png")]))
	await _frames(2)
	t.eq("a 4x PNG dropped: My pack's file is 4x", AssetPacks.png_size(mine), Vector2i(w * 4, h * 4))
	d = _with_packs(found)
	var tex: ImageTexture = GalNativeView._image_texture(GalImages.new(d).sprite(key), false)
	t.ok("the native view's picture is the 4x one (%s drawn at %s)" % [tex.get_image().get_size() if tex != null else Vector2i.ZERO,
		Vector2i(tex.get_width(), tex.get_height()) if tex != null else Vector2i.ZERO],
		tex != null and tex.get_image().get_size() == Vector2i(w * 4, h * 4) and Vector2i(tex.get_width(), tex.get_height()) == Vector2i(w, h))
	t.ok("and the card keeps the original", d.chunk(key) == plain.chunk(key))
	t.ok("the Now picture is the 4x one", page.after_rect.texture != null and page.after_rect.texture.get_size() == Vector2(w * 4, h * 4))

	# refused
	var before: PackedByteArray = FileAccess.get_file_as_bytes(mine)
	_shapes(w + 1, h, Color.WHITE, Color.BLACK).save_png(work.path_join("wrong.png"))
	root.files_dropped.emit(PackedStringArray([work.path_join("wrong.png")]))
	await _frames(2)
	t.ok("a wrong size is refused, saying the sizes that fit (%s)" % page.message.text,
		page.message.text.contains("wrong.png is %dx%d" % [w + 1, h]) and page.message.text.contains("needs %dx%d" % [w, h])
		and page.message.text.contains("%dx%d (4x)" % [w * 4, h * 4]) and FileAccess.get_file_as_bytes(mine) == before)
	var fa: FileAccess = FileAccess.open(work.path_join("photo.jpg"), FileAccess.WRITE)
	fa.store_string("not a picture at all")
	fa.close()
	root.files_dropped.emit(PackedStringArray([work.path_join("photo.jpg")]))
	await _frames(2)
	t.ok("a .jpg is refused: not a PNG (%s)" % page.message.text, page.message.text.contains("photo.jpg is not a PNG picture")
		and FileAccess.get_file_as_bytes(mine) == before)
	fa = FileAccess.open(work.path_join("fake.png"), FileAccess.WRITE)
	fa.store_string("this is text named as a picture")
	fa.close()
	root.files_dropped.emit(PackedStringArray([work.path_join("fake.png")]))
	await _frames(2)
	t.ok("a text file named .png is refused (%s)" % page.message.text, page.message.text.contains("fake.png ends in .png but is not a PNG picture")
		and FileAccess.get_file_as_bytes(mine) == before)

	# several, by their names
	var multi: String = work.path_join("multi")
	DirAccess.make_dir_recursive_absolute(multi)
	_shapes(96, 128, Color8(85, 255, 85), Color8(170, 0, 0)).save_png(multi.path_join("SPR_KEENSTANDR.png"))
	var jw: int = int(st.sprites["SPR_KEENJUMPR1"].w)
	var jh: int = int(st.sprites["SPR_KEENJUMPR1"].h)
	_shapes(jw, jh, Color8(255, 255, 255), Color8(0, 0, 170)).save_png(multi.path_join("spr_keenjumpr1.png"))
	_shapes(8, 8, Color.WHITE, Color.BLACK).save_png(multi.path_join("NOTANAME.png"))
	root.files_dropped.emit(PackedStringArray([multi.path_join("SPR_KEENSTANDR.png"), multi.path_join("spr_keenjumpr1.png"),
		multi.path_join("NOTANAME.png")]))
	await _frames(2)
	t.ok("several dropped: each named sprite replaced", AssetPacks.png_size(st.my_dir().path_join("SPR_KEENSTANDR.png")) == Vector2i(96, 128)
		and AssetPacks.png_size(st.my_dir().path_join("SPR_KEENJUMPR1.png")) == Vector2i(jw, jh))
	t.ok("an unknown name is said (%s)" % page.message.text, page.message.text.contains("no picture named NOTANAME"))
	t.eq("the picked sprite kept its picture", FileAccess.get_file_as_bytes(mine), before)

	# Replace... through the chooser, in file mode
	var pics: String = work.path_join("pics")
	_shapes(w * 2, h * 2, Color8(255, 85, 85), Color8(85, 85, 255)).save_png(pics.path_join("hat.png"))
	fa = FileAccess.open(pics.path_join("notes.txt"), FileAccess.WRITE)
	fa.store_string("not listed")
	fa.close()
	l.settings.set_value("studio_folder", pics)
	page.replace_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_A)
	var fc: FolderChooser = l.folder_chooser
	t.ok("A on Replace... opens the chooser in file mode on the last folder", fc != null and fc.file_types == PackedStringArray(["png"])
		and fc.current.ends_with("studio_work/pics"))
	if fc != null:
		t.eq("only the folders and the PNG files listed", [Array(fc.folders), Array(fc.files)], [["sub"], ["hat.png"]])
		await _pad(JOY_BUTTON_DPAD_DOWN)
		t.ok("the picked picture previewed with its size (%s)" % fc.preview_label.text, fc.preview_label.text == "%dx%d" % [w * 2, h * 2]
			and fc.preview.texture != null and fc.preview.texture.get_size() == Vector2(w * 2, h * 2))
		await _pad(JOY_BUTTON_A)
		t.ok("A on it: the chooser closed, the sprite replaced at 2x, the focus on Replace... (%s)" % _owner(),
			l.folder_chooser == null and AssetPacks.png_size(mine) == Vector2i(w * 2, h * 2) and _owner() == "Replace")
	# Revert
	page.revert_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_A)
	d = _with_packs(found)
	t.ok("Revert: My pack's picture gone, the stage's original again (%s)" % page.message.text, not FileAccess.file_exists(mine)
		and d.chunk(key) == plain.chunk(key) and d.stage.extras(key).is_empty() and page.message.text.contains("the game's own again"))
	# the template
	page.template_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_A)
	var tpl: String = AssetPacks.templates_dir("keen4").path_join("sprites/%s.png" % nm)
	t.ok("Export template: the sprite's PNG in the player's folder, said where (%s)" % page.message.text,
		AssetPacks.png_size(tpl) == Vector2i(w, h) and tpl.begins_with(Settings.user_dir()) and page.message.text.contains(tpl))

	# share My pack, bring it back
	var share: String = work.path_join("shared")
	DirAccess.make_dir_recursive_absolute(share)
	page.share_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_A)
	fc = l.folder_chooser
	t.ok("Export my pack... opens the chooser for a folder", fc != null and fc.file_types.is_empty())
	if fc != null:
		fc.open_and_focus(share)
		await _frames(2)
		await _pad(JOY_BUTTON_START)
	var label: String = "keen4 " + AssetStudio.MY_PACK
	var own: PackedStringArray = AssetPacks.pack_pictures("keen4", AssetStudio.MY_PACK)
	t.ok("written: a folder and a ZIP (%s)" % page.message.text, DirAccess.dir_exists_absolute(share.path_join(label))
		and FileAccess.file_exists(share.path_join(label + ".zip")) and own.size() == 2)
	var z: ZIPReader = ZIPReader.new()
	var entries: Array = []
	if z.open(share.path_join(label + ".zip")) == OK:
		entries = Array(z.get_files()).filter(func(f: String) -> bool: return not f.ends_with("/"))    # (not its folder's entry)
		z.close()
	entries.sort()
	var want_entries: Array = [label + "/" + AssetPacks.PACK_INFO]
	for f: String in own:
		want_entries.append(label + "/" + f)
	want_entries.sort()
	t.eq("the ZIP holds My pack's own pictures and its info, nothing else", entries, want_entries)
	page.bring_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_A)
	fc = l.folder_chooser
	if fc != null:
		fc.open_and_focus(share)
		await _frames(2)
		t.eq("Bring in a pack...: the chooser lists ZIPs", Array(fc.files), [label + ".zip"])
		await _pad(JOY_BUTTON_DPAD_DOWN)
		await _pad(JOY_BUTTON_A)
	t.ok("the ZIP brought back in as \"My pack 2\", switched on (%s)" % page.message.text, _same("My pack 2", own) and _is_on("My pack 2"))
	page.bring_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_A)
	fc = l.folder_chooser
	if fc != null:
		fc.open_and_focus(share.path_join(label))
		await _frames(2)
		await _pad(JOY_BUTTON_START)
	t.ok("the folder brought back in as \"My pack 3\", switched on (%s)" % page.message.text, _same("My pack 3", own) and _is_on("My pack 3"))

	# back, and the packs page beside the Studio
	page.replace_button.grab_focus()
	await _frames(2)
	await _pad(JOY_BUTTON_B)
	t.ok("B goes back to the launcher, the focus on Asset Studio (%s)" % _owner(), l.studio_page == null and l._page.visible and _owner() == "Studio")
	await _pad(JOY_BUTTON_A)
	if l.studio_page != null:
		l.studio_page.packs_button.grab_focus()
		await _frames(2)
		await _pad(JOY_BUTTON_A)
	var listed: PackedStringArray = []
	if l.packs_page != null:
		for c: Node in l.packs_page.find_children("On", "CheckButton", true, false):
			listed.append((c as CheckButton).text)
	t.ok("the Studio's Asset packs button shows the packs page, My pack listed (%s)" % ", ".join(listed),
		l.studio_page == null and l.packs_page != null and listed.has(AssetStudio.MY_PACK) and listed.has("My pack 2"))
	if l.packs_page != null:
		var row: Node = null
		for c: Node in l.packs_page.find_children("On", "CheckButton", true, false):
			if (c as CheckButton).text == AssetStudio.MY_PACK:
				row = c.get_parent()
		var share2: String = Settings.user_dir().path_join("studio_work/shared2")
		DirAccess.make_dir_recursive_absolute(share2)
		if row != null:
			(row.get_node("Share") as Button).grab_focus()
			await _frames(2)
			await _pad(JOY_BUTTON_A)
			if l.folder_chooser != null:
				l.folder_chooser.open_and_focus(share2)
				await _frames(2)
				await _pad(JOY_BUTTON_START)
		t.ok("the packs page shares a pack too (its row's Share..., the chooser, Start)", l.folder_chooser == null
			and FileAccess.file_exists(share2.path_join("keen4 My pack.zip")))
		l.packs_page.find_child("Bring", true, false).grab_focus()
		await _frames(2)
		await _pad(JOY_BUTTON_A)
		if l.folder_chooser != null:
			l.folder_chooser.open_and_focus(share2)
			await _frames(2)
			await _pad(JOY_BUTTON_DPAD_DOWN)
			await _pad(JOY_BUTTON_A)
		t.ok("and brings one in (Bring in a pack..., its ZIP): \"My pack 4\" listed and on", _same("My pack 4", AssetPacks.pack_pictures("keen4", AssetStudio.MY_PACK))
			and _is_on("My pack 4") and l.packs_page.find_children("On", "CheckButton", true, false).any(func(c: Node) -> bool: return (c as CheckButton).text == "My pack 4"))
	await _pad(JOY_BUTTON_B)
	t.ok("B from there goes back to the launcher (%s)" % _owner(), l.packs_page == null and l._page.visible and _owner() == "Packs")
	# a larger window
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	l.show_studio()
	await _frames(4)
	if l.studio_page != null:
		_check_layout(l.studio_page, "1920x1080")
		l.close_studio()


## The page inside the window: its own buttons, the inspector's and the lines under the grid on screen
## with their words whole, and five columns of pictures.
func _check_layout(page: StudioPage, tag: String) -> void:
	var win: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	var bad: PackedStringArray = []
	for c: Control in [page.back_button, page.packs_button, page.share_button, page.bring_button, page.replace_button,
			page.template_button, page.revert_button, page.message, page.find_child("Hints", true, false), page.title_label]:
		if not win.encloses(c.get_global_rect()):
			bad.append("%s outside" % c.name)
		if c is Button:
			var b: Button = c
			var st: StyleBox = b.get_theme_stylebox("normal")
			var w: float = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			if w + st.get_margin(SIDE_LEFT) + st.get_margin(SIDE_RIGHT) > b.size.x + 0.5:
				bad.append("%s cut" % b.name)
	t.ok("%s: the page's buttons and lines inside the window, their words whole %s" % [tag, bad], bad.is_empty())
	t.ok("%s: five columns of pictures or more (%d)" % [tag, page.grid.columns], page.grid.columns >= 5)


## A pack holds the same pictures as My pack's `own`, byte for byte.
func _same(pack: String, own: PackedStringArray) -> bool:
	if AssetPacks.pack_pictures("keen4", pack) != own:
		return false
	for f: String in own:
		if FileAccess.get_file_as_bytes(AssetPacks.mods_dir("keen4").path_join(pack).path_join(f)) != \
				FileAccess.get_file_as_bytes(AssetPacks.mods_dir("keen4").path_join(AssetStudio.MY_PACK).path_join(f)):
			return false
	return true


func _is_on(pack: String) -> bool:
	return (l.settings.get_value("packs", "keen4") as Array).has([pack, true])


func _with_packs(found: Dictionary) -> GalData:
	var d: GalData = GalData.new()
	AssetPacks.apply(d.stage, l.settings, "keen4")
	return d if d.load_game(found.folder, "res://data/omnispeak/keen4") else null
