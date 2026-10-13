# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## V15-01 replacement packs, and the suite's pages on the launcher (V15-06, V15-01). Packs made here from
## shapes (no game art), in this run's own player folder (MR_USER_DIR) under mods/keen4/:
## - "Big": SPR_KEENSTANDR at 4x (96x128): the native view's texture is that picture, drawn at the
##   sprite's size (24x32); the card keeps the original;
## - "Same": SPR_KEENJUMPR1 at its own size: its pixels everywhere, the card's too (the expanded chunk),
##   each the nearest EGA colour of the picture's, clear where its alpha is under a half;
## - "Broken": SPR_KEENRUNR1.png not a PNG, SPR_KEENRUNR2.png a PNG of the wrong size: both originals
##   kept, each with a line in the log;
## - every pack switched off: every sprite is the original again (and the check that says so finds the
##   difference with them on: it can fail);
## - the listing keeps the setting's order and adds a new folder, on;
## - the export tool writes the templates into the player's folder (a PNG per sprite at its size, a
##   sheet per set with its list).
## The pages: the launcher's Keen's Closet and Asset packs buttons open their pages in the same window
## (a pad's A), a colour stepped on the closet page is saved for the game and the preview shows Keen's
## frames, a pack switched off on the packs page is saved, and B goes back to the launcher with the
## focus on the button that opened the page.
##
## Options: --game_data=<folder>

var t: T = T.new()


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
	var mods: String = AssetPacks.mods_dir("keen4")
	t.ok("the mods folder is the player's (%s)" % mods, mods.begins_with(Settings.user_dir()))
	for p: String in ["Big", "Same", "Broken"]:
		DirAccess.make_dir_recursive_absolute(mods.path_join(p))
	var plain: GalData = AssetPacks.load_data(found)
	if plain == null:
		t.blocked("Keen 4 could not be read")
		t.finish(self)
		return
	var js: Dictionary = plain.sprite(int(plain.stage.keys["SPR_KEENJUMPR1"]) - int(plain.gfx.offSprites))
	var jw: int = int(js.w)
	var jh: int = int(js.h)
	_shapes(96, 128, Color8(255, 85, 255), Color8(0, 170, 170)).save_png(mods.path_join("Big/SPR_KEENSTANDR.png"))
	var same: Image = _shapes(jw, jh, Color8(250, 250, 90), Color8(10, 10, 160))
	same.save_png(mods.path_join("Same/SPR_KEENJUMPR1.png"))
	var fa: FileAccess = FileAccess.open(mods.path_join("Broken/SPR_KEENRUNR1.png"), FileAccess.WRITE)
	fa.store_string("this is not a picture")
	fa.close()
	_shapes(25, 10, Color.WHITE, Color.BLACK).save_png(mods.path_join("Broken/SPR_KEENRUNR2.png"))
	var settings: Settings = Settings.new(Settings.user_dir().path_join("v15_packs.cfg"))
	settings.set_value("packs", [["Big", true], ["Same", true], ["Broken", true]], "keen4")

	var d: GalData = _with_packs(found, settings)
	if d == null:
		t.blocked("Keen 4 could not be read")
		t.finish(self)
		return
	var stand: int = int(d.stage.keys["SPR_KEENSTANDR"])
	var jump: int = int(d.stage.keys["SPR_KEENJUMPR1"])
	var off: int = int(d.gfx.offSprites)
	# Big: 4x in the native view, the card's original
	var img: Dictionary = GalImages.new(d).sprite(stand)
	var tex: ImageTexture = GalNativeView._image_texture(img, false)
	t.ok("Big's 4x picture is the native view's texture (%dx%d drawn at %dx%d)" % [
		tex.get_image().get_width() if tex != null else 0, tex.get_image().get_height() if tex != null else 0,
		tex.get_width() if tex != null else 0, tex.get_height() if tex != null else 0],
		tex != null and tex.get_image().get_size() == Vector2i(96, 128) and Vector2i(tex.get_width(), tex.get_height()) == Vector2i(24, 32)
		and tex.get_image().get_pixel(48, 64).r > 0.9)
	t.ok("and the card keeps the original SPR_KEENSTANDR", d.chunk(stand) == plain.chunk(stand))
	# Same: its pixels everywhere
	var s: Dictionary = d.sprite(jump - off)
	var bad: int = 0
	for y: int in range(jh):
		for x: int in range(jw):
			var c: Color = same.get_pixel(x, y)
			var want_px: int = KeenCloset.nearest_ega(c) if c.a >= 0.5 else -1
			var clear: bool = s.mask[y * jw + x] != 0
			if (want_px < 0) != clear or (want_px >= 0 and s.pixels[y * jw + x] != want_px):
				bad += 1
	t.eq("Same's own-size picture is SPR_KEENJUMPR1 on the card, by nearest EGA colour, pixels off", bad, 0)
	t.ok("and it differs from the original", d.chunk(jump) != plain.chunk(jump))
	# Broken: originals kept, the log says why
	for nm: String in ["SPR_KEENRUNR1", "SPR_KEENRUNR2"]:
		var k: int = int(d.stage.keys[nm])
		t.ok("%s: a broken file keeps the original" % nm, d.chunk(k) == plain.chunk(k) and d.stage.extras(k).is_empty())
	var notes: String = "\n".join(d.stage.notes)
	t.ok("the log names the file that is not a PNG (%s)" % notes.replace("\n", " | "), notes.contains("Broken/SPR_KEENRUNR1.png: not a PNG"))
	t.ok("and the one of the wrong size", notes.contains("Broken/SPR_KEENRUNR2.png: 25x10 is not "))
	# switched off: all original; the check can fail
	t.ok("the comparison of every sprite finds the packs when they are on (%d differ)" % _differ(plain, d), _differ(plain, d) == 2)
	settings.set_value("packs", [["Big", false], ["Same", false], ["Broken", false]], "keen4")
	var d0: GalData = _with_packs(found, settings)
	t.eq("every pack switched off: every sprite is the original (sprites differing)", _differ(plain, d0), 0)
	t.ok("and nothing for the native view", d0.stage.extras(stand).is_empty())
	# listing
	DirAccess.make_dir_recursive_absolute(mods.path_join("Zed"))
	t.eq("the listing: the setting's order, then a new folder, on", AssetPacks.listing(settings, "keen4"),
		[["Big", false], ["Same", false], ["Broken", false], ["Zed", true]])
	# export
	var where: String = AssetPacks.export_templates(plain.stage, AssetPacks.sprites_of(plain))
	var tpl: Image = Image.load_from_file(where.path_join("sprites/SPR_KEENSTANDR.png"))
	t.ok("the export writes into the player's folder (%s)" % where, where.begins_with(Settings.user_dir()))
	t.ok("a template per sprite at its size, named for a pack", tpl != null and tpl.get_size() == Vector2i(24, 32))
	t.ok("a sheet per set with its list", FileAccess.file_exists(where.path_join("sheets/KEEN.png"))
		and FileAccess.get_file_as_string(where.path_join("sheets/KEEN.txt")).contains("SPR_KEENSTANDR"))
	await _pages(found)
	t.finish(self)


func _with_packs(found: Dictionary, settings: Settings) -> GalData:
	var d: GalData = GalData.new()
	AssetPacks.apply(d.stage, settings, "keen4")
	return d if d.load_game(found.folder, "res://data/omnispeak/keen4") else null


## The sprites whose expanded chunk or native extras differ between two loads.
static func _differ(a: GalData, b: GalData) -> int:
	var n: int = 0
	for i: int in range(a.sprite_table.size()):
		var c: int = int(a.gfx.offSprites) + i
		if a.chunk(c) != b.chunk(c) or not b.stage.extras(c).is_empty():
			n += 1
	return n


func _pages(found: Dictionary) -> void:
	root.size = Vector2i(1280, 720)
	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = Settings.user_dir().path_join("lock_v15")
	l.settings_path = Settings.user_dir().path_join("v15_pages.cfg")
	root.add_child(l)
	await _frames(3)
	l.show_results([found])
	await _frames(3)
	l.closet_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	t.ok("A on Keen's Closet opens its page in the window (focus %s)" % _owner(), l.closet_page != null and not l._page.visible
		and l.closet_page.is_inside_tree() and _owner() == "PrevGame")
	if l.closet_page != null:
		var page: ClosetPage = l.closet_page
		var shown: int = 0
		for p: Array in page.previews:
			if (p[0] as TextureRect).texture != null:
				shown += 1
		t.eq("the preview shows Keen running, jumping and pogoing from the game's files", shown, 3)
		# Simple mode first (the user, 2026-10-13): a helmet look sets the helmet and its stripe together
		t.ok("the page opens in Simple mode, Advanced's rows hidden", page.simple_box.visible and not page.advanced_box.visible)
		(page.find_child("Item_helmet", true, false).get_node("Next") as Button).grab_focus()
		await _frames(2)
		await _pad(JOY_BUTTON_A)
		t.eq("a helmet look stepped with the pad sets the helmet and its stripe", l.settings.get_value("closet", "keen4"),
			{"helmet": "#ff5555", "trim": "#ffffff"})
		t.eq("and the row names it", (page.simple_swatches["helmet"][2] as Label).text, "Red")
		(page.find_child("ModeButton", true, false) as Button).grab_focus()
		await _frames(2)
		await _pad(JOY_BUTTON_A)
		t.ok("the mode button shows Advanced, kept in the settings", page.advanced_box.visible and not page.simple_box.visible
			and String(l.settings.get_value("closet_mode")) == "advanced")
		(page.find_child("Part_shirt", true, false).get_node("Next") as Button).grab_focus()
		await _frames(2)
		await _pad(JOY_BUTTON_A)
		t.eq("a colour stepped with the pad is kept for the game", l.settings.get_value("closet", "keen4"),
			{"helmet": "#ff5555", "trim": "#ffffff", "shirt": "#000000"})
		t.eq("a part changed in Advanced shows in Simple as the player's own", KeenCloset.simple_look("helmet",
			KeenCloset.with_look("helmet", {"helmet": "#123456"}, -1).merged({"helmet": "#123456"})), -2)
		await _pad(JOY_BUTTON_B)
		t.ok("B goes back to the launcher, the focus on Keen's Closet (%s)" % _owner(), l.closet_page == null and l._page.visible
			and _owner() == "Closet")
	l.packs_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	t.ok("A on Asset packs opens its page (focus %s)" % _owner(), l.packs_page != null and not l._page.visible)
	if l.packs_page != null:
		var on: CheckButton = l.packs_page.find_child("On", true, false)
		t.ok("the packs are listed (%s first)" % (on.text if on != null else "none"), on != null and on.text == "Big")
		on.grab_focus()
		await _frames(2)
		await _pad(JOY_BUTTON_A)
		t.eq("switched with the pad, kept", (l.settings.get_value("packs", "keen4") as Array)[0], ["Big", false])
		await _pad(JOY_BUTTON_B)
		t.ok("B goes back, the focus on Asset packs (%s)" % _owner(), l.packs_page == null and l._page.visible and _owner() == "Packs")
	l.queue_free()
	await _frames(2)
