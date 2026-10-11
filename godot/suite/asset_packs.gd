# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name AssetPacks
extends RefCounted
## V15-01 replacement packs: pictures the player (or a friend) made, in the player's own folder,
## Settings.user_dir()/mods/<game>/<pack>/, one PNG a sprite named by the asset stage's stable name
## (SPR_KEENSTANDR.png for Keen 4-6, KEENWALKR1SPR.png for Keen 1-3, KEENSTANDRSPR.png for Dreams). A
## picture the sprite's own size is drawn everywhere, on the 320x200 card too, each pixel as the nearest of
## the 16 EGA colours (alpha under a half is clear); a whole multiple of the size (2x, 3x, 4x, ...) is
## drawn by the native view at its own detail and colours, the card keeping the original. A file that is
## not a PNG, or whose size is neither, is skipped with a note in the log and the original kept. Packs are
## listed, switched on and off and ordered in the launcher (the "packs" setting, per game: a later pack
## wins). Packs hold only what the player made; the export tool writes the originals as templates to the
## player's folder, never anywhere else.

const PNG_SIG: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

var game: String = ""
## stable name -> {path, pack, w, h} (the winning file per name; its size from the PNG's header)
var files: Dictionary = {}
var _images: Dictionary = {}    # stable name -> Image (decoded on first use)


static func mods_dir(game_id: String) -> String:
	return Settings.user_dir().path_join("mods").path_join(game_id)


static func templates_dir(game_id: String) -> String:
	return Settings.user_dir().path_join("templates").path_join(game_id)


## The packs of a game as the launcher shows them: [[name, on]], the setting's order first, then any
## pack folder the setting does not name yet (on: the player put it there); folders gone are dropped.
static func listing(settings: Settings, game_id: String) -> Array:
	var present: PackedStringArray = []
	var d: DirAccess = DirAccess.open(mods_dir(game_id))
	if d != null:
		for n: String in d.get_directories():
			present.append(n)
	present.sort()
	var out: Array = []
	var seen: Dictionary = {}
	for e: Array in settings.get_value("packs", game_id):
		if present.has(e[0]) and not seen.has(e[0]):
			out.append([e[0], e[1]])
			seen[e[0]] = true
	for n: String in present:
		if not seen.has(n):
			out.append([n, true])
	return out


## The packs switched on for a game, as the stage's first filter (none when no pack is on).
static func apply(stage: AssetStage, settings: Settings, game_id: String) -> AssetPacks:
	var on: PackedStringArray = []
	for e: Array in listing(settings, game_id):
		if e[1]:
			on.append(e[0])
	if on.is_empty():
		return null
	var p: AssetPacks = AssetPacks.new()
	p.load_packs(game_id, on, stage)
	if p.files.is_empty():
		return null
	stage.add_filter(p.filter)
	return p


## Reads the packs' file lists (in order, a later one replacing an earlier's file of the same name).
func load_packs(game_id: String, packs: PackedStringArray, stage: AssetStage) -> void:
	game = game_id
	for pack: String in packs:
		var dir: String = mods_dir(game_id).path_join(pack)
		var d: DirAccess = DirAccess.open(dir)
		if d == null:
			continue
		for f: String in d.get_files():
			if f.get_extension().to_lower() != "png":
				continue
			var path: String = dir.path_join(f)
			var size: Vector2i = png_size(path)
			if size == Vector2i.ZERO:
				_note(stage, "%s/%s: not a PNG picture; the original is kept" % [pack, f])
				continue
			files[f.get_basename().to_upper()] = {"path": path, "pack": pack, "w": size.x, "h": size.y}


## A PNG's width and height from its header (zero when the file is not a PNG).
static func png_size(path: String) -> Vector2i:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null or fa.get_length() < 33:
		return Vector2i.ZERO
	var head: PackedByteArray = fa.get_buffer(24)
	if head.slice(0, 8) != PNG_SIG or head.slice(12, 16).get_string_from_ascii() != "IHDR":
		return Vector2i.ZERO
	var w: int = (head[16] << 24) | (head[17] << 16) | (head[18] << 8) | head[19]
	var h: int = (head[20] << 24) | (head[21] << 16) | (head[22] << 8) | head[23]
	return Vector2i(w, h) if w > 0 and h > 0 and w <= 8192 and h <= 8192 else Vector2i.ZERO


## The filter: a sprite the packs have a picture for, replaced (same size: its pixels; a whole multiple:
## the native view's picture).
func filter(stage: AssetStage, _key: int, name: String, img: Dictionary) -> Dictionary:
	if not files.has(name):
		return img
	var f: Dictionary = files[name]
	var w: int = int(img.w)
	var h: int = int(img.h)
	var k: int = int(f.w) / w if w > 0 else 0
	if k < 1 or int(f.w) != w * k or int(f.h) != h * k:
		_note(stage, "%s/%s.png: %dx%d is not %dx%d or a whole multiple of it; the original is kept" % [
			f.pack, name, f.w, f.h, w, h])
		files.erase(name)
		return img
	if not _images.has(name):
		var im: Image = Image.load_from_file(f.path)
		if im == null or im.is_empty():
			_note(stage, "%s/%s.png: could not be read; the original is kept" % [f.pack, name])
			files.erase(name)
			return img
		im.convert(Image.FORMAT_RGBA8)
		_images[name] = im
	var image: Image = _images[name]
	var out: Dictionary = img.duplicate()
	if k > 1:
		out.image = image
		return out
	var pixels: PackedByteArray = PackedByteArray()
	var opaque: PackedByteArray = PackedByteArray()
	pixels.resize(w * h)
	opaque.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			var c: Color = image.get_pixel(x, y)
			if c.a >= 0.5:
				pixels[y * w + x] = KeenCloset.nearest_ega(c)
				opaque[y * w + x] = 1
	out.pixels = pixels
	out.opaque = opaque
	return out


static func _note(stage: AssetStage, text: String) -> void:
	var line: String = "asset pack: " + text
	stage.notes.append(line)
	print(line)


## The export tool: the game's sprites as they are (through `stage`, whose sprites `images` lists as
## [key, {w, h, pixels, opaque}]) written to the player's templates folder: each sprite as a PNG named for
## a pack (sprites/<NAME>.png), and a sheet per sprite set (sheets/<SET>.png, the set the name's first
## four letters after SPR_), frames in a grid of one-pixel lines with a list of the cells
## (sheets/<SET>.txt). Returns the folder, or "" when it could not be written.
static func export_templates(stage: AssetStage, images: Array) -> String:
	var root: String = templates_dir(stage.game)
	var spr_dir: String = root.path_join("sprites")
	var sheet_dir: String = root.path_join("sheets")
	if DirAccess.make_dir_recursive_absolute(spr_dir) != OK or DirAccess.make_dir_recursive_absolute(sheet_dir) != OK:
		return ""
	var sets: Dictionary = {}
	for e: Array in images:
		var name: String = stage.name_of(int(e[0]))
		var im: Image = to_image(e[1])
		if im == null:
			continue
		im.save_png(spr_dir.path_join(name + ".png"))
		var set_name: String = name.trim_prefix("SPR_").substr(0, 4)
		if not sets.has(set_name):
			sets[set_name] = []
		sets[set_name].append([name, im])
	for s: String in sets:
		var frames: Array = sets[s]
		var cw: int = 1
		var ch: int = 1
		for f: Array in frames:
			cw = maxi(cw, (f[1] as Image).get_width())
			ch = maxi(ch, (f[1] as Image).get_height())
		var cols: int = mini(8, frames.size())
		var rows: int = (frames.size() + cols - 1) / cols
		var sheet: Image = Image.create(cols * (cw + 1) + 1, rows * (ch + 1) + 1, false, Image.FORMAT_RGBA8)
		var grid: Color = KeenCloset.ega_color(8)
		for x: int in range(sheet.get_width()):
			for r: int in range(rows + 1):
				sheet.set_pixel(x, r * (ch + 1), grid)
		for y: int in range(sheet.get_height()):
			for c: int in range(cols + 1):
				sheet.set_pixel(c * (cw + 1), y, grid)
		var listing_text: String = "cell (column, row): name, size; cells %dx%d, a one-pixel grid\n" % [cw, ch]
		for i: int in range(frames.size()):
			var im: Image = frames[i][1]
			var c: int = i % cols
			var r: int = i / cols
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(1 + c * (cw + 1), 1 + r * (ch + 1)))
			listing_text += "(%d, %d): %s, %dx%d\n" % [c, r, frames[i][0], im.get_width(), im.get_height()]
		sheet.save_png(sheet_dir.path_join(s + ".png"))
		var fa: FileAccess = FileAccess.open(sheet_dir.path_join(s + ".txt"), FileAccess.WRITE)
		if fa != null:
			fa.store_string(listing_text)
	return root


## {w, h, pixels, opaque} as an RGBA Image in the EGA colours (clear where it does not draw).
static func to_image(img: Dictionary) -> Image:
	if img.is_empty():
		return null
	var w: int = int(img.w)
	var h: int = int(img.h)
	var data: PackedByteArray = PackedByteArray()
	data.resize(w * h * 4)
	var px: PackedByteArray = img.pixels
	var op: PackedByteArray = img.opaque
	for k: int in range(w * h):
		if op[k] != 0:
			var c: int = px[k]
			data[k * 4] = KeenCloset.EGA[c * 3]
			data[k * 4 + 1] = KeenCloset.EGA[c * 3 + 1]
			data[k * 4 + 2] = KeenCloset.EGA[c * 3 + 2]
			data[k * 4 + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


## Every sprite of a loaded game through its stage, as export_templates takes them: [key, {w, h, pixels, opaque}].
static func sprites_of(data: Object) -> Array:
	var out: Array = []
	if data is VortData:
		var vd: VortData = data
		for i: int in range(vd.sprites.size()):
			var s: Dictionary = vd.sprites[i]
			out.append([i, {"w": s.w, "h": s.h, "pixels": s.pixels, "opaque": s.mask}])
	elif data is GalData:
		var gd: GalData = data
		for i: int in range(gd.sprite_table.size()):
			out.append([int(gd.gfx.offSprites) + i, _opaque(gd.sprite(i))])
	elif data is DreamsData:
		var dd: DreamsData = data
		for i: int in range(dd.sprite_table.size()):
			out.append([DreamsData.STARTSPRITES + i, _opaque(dd.sprite(i))])
	return out


## A found game's files read for the suite's pages (the closet's preview, the export), through a stage
## with `filters`: VortData, GalData or DreamsData, or null when they cannot be read.
static func load_data(found: Dictionary, filters: Array = []) -> Object:
	var id: String = String(found.get("id", ""))
	var folder: String = String(found.get("folder", ""))
	var d: Object = null
	var ok: bool = false
	match id:
		"keen1", "keen2", "keen3":
			d = VortData.new()
		"keen4", "keen5", "keen6":
			d = GalData.new()
		"kdreams":
			d = DreamsData.new()
		_:
			return null
	for f: Callable in filters:
		(d.stage as AssetStage).add_filter(f)
	if d is VortData:
		ok = (d as VortData).load_game(folder, "CK" + id.substr(4, 1))
	elif d is GalData:
		var meta: String = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}[id]
		if id == "keen6" and String(found.get("version", "")).contains("1.5"):
			meta = "keen6e15"
		ok = (d as GalData).load_game(folder, "res://data/omnispeak".path_join(meta))
	else:
		ok = (d as DreamsData).load_game(folder)
	return d if ok else null


static func _opaque(s: Dictionary) -> Dictionary:
	if s.is_empty():
		return {}
	var op: PackedByteArray = (s.mask as PackedByteArray).duplicate()
	for k: int in range(op.size()):
		op[k] = 1 - op[k]
	return {"w": s.w, "h": s.h, "pixels": s.pixels, "opaque": op}


# ---- sharing a pack (V15-05)

## The file a shared pack carries: the game, the pack's name and the pictures it holds.
const PACK_INFO: String = "pack.cfg"


## A pack's own pictures: the PNG files in its folder (by name), nothing else.
static func pack_pictures(game_id: String, pack: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: String = mods_dir(game_id).path_join(pack)
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.get_extension().to_lower() == "png" and png_size(dir.path_join(f)) != Vector2i.ZERO:
			out.append(f)
	out.sort()
	return out


## V15-05: a pack ready to share, written into `dest` as a folder "<game> <pack>" holding the pack's own
## pictures and PACK_INFO, and as "<game> <pack>.zip" beside it (the same files inside a folder of that
## name). Only the player's pictures go in, never the originals. {ok, folder, zip, count, message}.
static func export_pack(game_id: String, pack: String, dest: String) -> Dictionary:
	var pics: PackedStringArray = pack_pictures(game_id, pack)
	if pics.is_empty():
		return {"ok": false, "message": "The pack \"%s\" has no pictures yet: replace a picture first." % pack}
	var label: String = "%s %s" % [game_id, pack]
	var folder: String = dest.path_join(label)
	var zip_path: String = folder + ".zip"
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return {"ok": false, "message": "Megarocket could not make the folder %s." % folder}
	var old: DirAccess = DirAccess.open(folder)
	for f: String in old.get_files():    # a shared copy made before: its pictures and info replaced
		if f.get_extension().to_lower() == "png" or f == PACK_INFO:
			DirAccess.remove_absolute(folder.path_join(f))
	var info: ConfigFile = ConfigFile.new()
	info.set_value("pack", "game", game_id)
	info.set_value("pack", "name", pack)
	var names: PackedStringArray = []
	for f: String in pics:
		names.append(f.get_basename().to_upper())
	info.set_value("pack", "pictures", names)
	info.set_value("pack", "made_with", "Megarocket")
	var info_text: String = info.encode_to_text()
	var src: String = mods_dir(game_id).path_join(pack)
	var z: ZIPPacker = ZIPPacker.new()
	if z.open(zip_path) != OK:
		return {"ok": false, "message": "Megarocket could not write %s." % zip_path}
	for f: String in pics:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(src.path_join(f))
		var fa: FileAccess = FileAccess.open(folder.path_join(f), FileAccess.WRITE)
		if fa == null:
			z.close()
			return {"ok": false, "message": "Megarocket could not write into %s." % folder}
		fa.store_buffer(bytes)
		fa.close()
		z.start_file(label + "/" + f)
		z.write_file(bytes)
		z.close_file()
	var fi: FileAccess = FileAccess.open(folder.path_join(PACK_INFO), FileAccess.WRITE)
	if fi != null:
		fi.store_string(info_text)
		fi.close()
	z.start_file(label + "/" + PACK_INFO)
	z.write_file(info_text.to_utf8_buffer())
	z.close_file()
	z.close()
	return {"ok": true, "folder": folder, "zip": zip_path, "count": pics.size(),
		"message": "\"%s\" (%d pictures) is ready to share: the folder %s and the ZIP %s." % [pack, pics.size(), folder, zip_path]}


## V15-05: a shared pack (a folder, or a ZIP, with PACK_INFO in it or in a folder one level down; or a
## plain folder of PNG pictures) brought in as a pack of its game (the info's, else `fallback_game`), under
## its own name (a number added when a pack of that name is there already), switched on as a new folder
## is. Only PNG pictures are taken (by their own names; no folders inside). {ok, game, pack, count, message}.
static func import_pack(source: String, fallback_game: String) -> Dictionary:
	var entries: Dictionary = {}    # file name -> bytes
	var info_text: String = ""
	var is_zip: bool = source.get_extension().to_lower() == "zip"
	var default_name: String = source.get_file().get_basename() if is_zip else source.trim_suffix("/").get_file()
	if is_zip:
		var z: ZIPReader = ZIPReader.new()
		if z.open(source) != OK:
			return {"ok": false, "message": "%s could not be opened as a ZIP." % source.get_file()}
		var files: PackedStringArray = z.get_files()
		var inside: String = ""
		var depth: int = 99
		for f: String in files:
			if f.get_file() == PACK_INFO and f.count("/") < depth:
				depth = f.count("/")
				inside = f.get_base_dir()
		for f: String in files:
			if f.get_base_dir() != inside:
				continue
			if f.get_file() == PACK_INFO:
				info_text = z.read_file(f).get_string_from_utf8()
			elif f.get_extension().to_lower() == "png":
				entries[f.get_file()] = z.read_file(f)
		z.close()
	else:
		var dir: String = source
		if not FileAccess.file_exists(dir.path_join(PACK_INFO)):
			var d0: DirAccess = DirAccess.open(dir)
			if d0 == null:
				return {"ok": false, "message": "%s could not be opened." % source}
			for sub: String in d0.get_directories():
				if FileAccess.file_exists(dir.path_join(sub).path_join(PACK_INFO)):
					dir = dir.path_join(sub)
					break
		if FileAccess.file_exists(dir.path_join(PACK_INFO)):
			info_text = FileAccess.get_file_as_string(dir.path_join(PACK_INFO))
		var d: DirAccess = DirAccess.open(dir)
		if d != null:
			for f: String in d.get_files():
				if f.get_extension().to_lower() == "png":
					entries[f] = FileAccess.get_file_as_bytes(dir.path_join(f))
	var game_id: String = fallback_game
	var name: String = default_name
	if info_text != "":
		var info: ConfigFile = ConfigFile.new()
		if info.parse(info_text) == OK:
			game_id = String(info.get_value("pack", "game", fallback_game))
			name = String(info.get_value("pack", "name", default_name))
	var known: bool = false
	for g: Array in Launcher.GAMES:
		known = known or g[0] == game_id
	if not known:
		return {"ok": false, "message": "%s is a pack for a game Megarocket does not know (%s)." % [source.get_file(), game_id]}
	var pics: Dictionary = {}
	for f: String in entries:
		var b: PackedByteArray = entries[f]
		if b.size() >= 33 and b.slice(0, 8) == PNG_SIG:
			pics[f] = b
	if pics.is_empty():
		return {"ok": false, "message": "%s has no PNG pictures in it, so there is nothing to bring in." % source.get_file()}
	name = _safe_name(name)
	var pack: String = name
	var n: int = 2
	while DirAccess.dir_exists_absolute(mods_dir(game_id).path_join(pack)):
		pack = "%s %d" % [name, n]
		n += 1
	var dest: String = mods_dir(game_id).path_join(pack)
	if DirAccess.make_dir_recursive_absolute(dest) != OK:
		return {"ok": false, "message": "Megarocket could not make the folder %s." % dest}
	for f: String in pics:
		var fa: FileAccess = FileAccess.open(dest.path_join(f), FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(pics[f])
			fa.close()
	if info_text != "":
		var fi: FileAccess = FileAccess.open(dest.path_join(PACK_INFO), FileAccess.WRITE)
		if fi != null:
			fi.store_string(info_text)
			fi.close()
	var skipped: int = entries.size() - pics.size()
	return {"ok": true, "game": game_id, "pack": pack, "count": pics.size(),
		"message": "The pack \"%s\" is in %s now: %d pictures, switched on.%s" % [pack, FolderChooser.short_name(game_id), pics.size(),
			" %d files that were not PNG pictures were left out." % skipped if skipped > 0 else ""]}


## A pack switched on in the "packs" setting (kept where it is in the order; added last when new), saved.
static func switch_on(settings: Settings, game_id: String, pack: String) -> void:
	var list: Array = listing(settings, game_id)
	var at: int = -1
	for i: int in range(list.size()):
		if list[i][0] == pack:
			at = i
	if at < 0:
		list.append([pack, true])
	else:
		list[at][1] = true
	settings.set_value("packs", list, game_id)
	settings.save()


## A pack's name as a folder's: no characters a folder name can't have, not empty.
static func _safe_name(name: String) -> String:
	var out: String = ""
	for ch: String in name:
		out += "_" if "/\\:*?\"<>|".contains(ch) or ch.unicode_at(0) < 32 else ch
	out = out.strip_edges().trim_prefix(".")
	return out if out != "" else "Shared pack"
