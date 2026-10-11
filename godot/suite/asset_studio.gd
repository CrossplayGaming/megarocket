# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name AssetStudio
extends RefCounted
## V15-05 the Asset Studio's model (the page is StudioPage): one game's sprites as the player's own files
## have them, read through the asset stage with no filter (A12: nothing of the art is stored), sorted into
## categories by their stable names (Keen; the creatures by family, the names sharing a beginning; items;
## shots and effects; the rest), each sprite's animation (the names differing only in their last number),
## its colours, and whether a pack replaces it. A replacement is checked at once (a PNG, the sprite's own
## size or a whole multiple of it, what is see-through) and saved into the player's own pack, "My pack"
## (AssetPacks.mods_dir/<game>/My pack, made on first use, switched on and put last so it wins); Revert
## takes it out again. Packs hold only the player's pictures, never the originals.

const MY_PACK: String = "My pack"
## Items: the names (without SPR_ / SPR) beginning so; any name beginning with a digit is a score too.
const ITEMS: PackedStringArray = ["GEM_", "BONUS", "1UP", "STUNNER", "SECURITYCARD", "PASSCARD", "EXTRAKEEN",
	"PEPPERMINT", "COOKIE", "CANDY", "LOLLIPOP", "COTTONCANDY", "SUPERBONUS", "FLOWERPOWERUP", "MAGICKEY",
	"BOOBUSBOMB", "SANDWICH", "HOOK", "SCUBAGEAR"]
## Shots and effects: the names (without SPR_ / SPR and their last number) that are exactly so.
const EFFECTS: PackedStringArray = ["STUN", "STUNHIT", "STARS", "KEENSHOT", "TANKSHOT", "VTANKSHOT", "SHOTSPLASHR",
	"SHOTSPLASHL", "ICESHOT", "ICECHUNK", "SPARK", "LASER", "LASERHIT", "POOF", "FLOWERPOWER", "BOOBUSBOOM",
	"VIVASPLASH", "EARTHCHUNK", "LILCHUNK", "FIREARTH", "SHOOTINGSTAR", "MAPTELESPARK", "FUSEFLASH",
	"STAREXPLODE", "TELEPORTSPARK", "TELEPORTZAP", "MINEBOOM"]
## The rest that is no creature: the screens' parts, doors, platforms, the map's flags and ships.
const OTHER: PackedStringArray = ["PADDLE", "BALL", "DEMOSIGN", "SCOREBOX", "DOOR", "PLATFORM", "MINIPLAT",
	"PURPLEPLAT", "CURSORARROW", "FLAGFLIP", "FLAGFALL", "FLAGFLAP", "SMALLSHIP", "SMALLSHIPR", "SMALLSHIPL",
	"POINT", "MARK", "CHAIN", "LAMESHIP", "GODHALO", "BYEHALO", "HEART", "ROCKET", "ROCKETFLY", "SATELLITE",
	"SIDEJET", "RBOTTOMJET", "LBOTTOMJET"]

var game: String = ""
var family: String = ""
var stage: AssetStage = null
## stable name -> {key, w, h, pixels, opaque} (the player's own files, unchanged)
var sprites: Dictionary = {}
## The names in the game's own order
var order: PackedStringArray = []
## [label, PackedStringArray of names, kind ("keen", "creature", "items", "effects", "other")]
var categories: Array = []
## stable name -> {path, pack, w, h}: the picture that replaces it now (the winning pack switched on)
var replaced: Dictionary = {}
## stable name -> true: the pictures in My pack
var mine: Dictionary = {}
var _anims: Dictionary = {}      # animation key -> [names in frame order]
var _shown: Dictionary = {}      # name -> Image (what the game shows now; cleared on every change)


## A found game's sprites, or null when its files cannot be read.
static func open(found: Dictionary) -> AssetStudio:
	var d: Object = AssetPacks.load_data(found)
	if d == null:
		return null
	var s: AssetStudio = AssetStudio.new()
	s.game = String(found.get("id", ""))
	s.family = KeenCloset.family_of(s.game)
	s.stage = d.stage
	for e: Array in AssetPacks.sprites_of(d):
		var img: Dictionary = e[1]
		if img.is_empty() or int(img.w) <= 0 or int(img.h) <= 0:
			continue
		var nm: String = s.stage.name_of(int(e[0]))
		if s.sprites.has(nm):
			continue
		var rec: Dictionary = img.duplicate()
		rec.key = int(e[0])
		s.sprites[nm] = rec
		s.order.append(nm)
	s.categories = sort_into(s.game, s.order)
	for nm: String in s.order:
		var k: String = anim_key(nm)
		if not s._anims.has(k):
			s._anims[k] = []
		s._anims[k].append(nm)
	return s


## A name without its SPR_ (Keen 4-6) or SPR (Keen 1-3, Dreams).
static func base(name: String) -> String:
	if name.begins_with("SPR_"):
		return name.substr(4)
	if name.ends_with("SPR") and name.length() > 3:
		return name.left(-3)
	return name


## The base without its last number (KEENRUNR1 -> KEENRUNR).
static func stem(name: String) -> String:
	var b: String = base(name)
	var i: int = b.length()
	while i > 0 and b[i - 1] >= "0" and b[i - 1] <= "9":
		i -= 1
	return b.left(i) if i > 0 else b


## The animation a name belongs to: the name with its last number (one or two digits) as "#"
## (SPR_KEENRUNR3 -> SPR_KEENRUNR#, SPR_MAPKEEN_WALK1_W -> SPR_MAPKEEN_WALK#_W); a name with none is its own.
static func anim_key(name: String) -> String:
	var end: int = name.length()
	while end > 0 and not (name[end - 1] >= "0" and name[end - 1] <= "9"):
		end -= 1
	if end == 0:
		return name
	var start: int = end
	while start > 0 and name[start - 1] >= "0" and name[start - 1] <= "9":
		start -= 1
	if end - start > 2:
		return name
	return name.left(start) + "#" + name.substr(end)


## The game's sprites by category: Keen first, the creatures by family (names in a row sharing their first
## three letters or more, named for what they share), then items, shots and effects, the rest.
static func sort_into(game_id: String, names: PackedStringArray) -> Array:
	var fam: String = KeenCloset.family_of(game_id)
	var keen: PackedStringArray = []
	var items: PackedStringArray = []
	var effects: PackedStringArray = []
	var other: PackedStringArray = []
	var creatures: Array = []        # [prefix, Array of names] (Arrays: a packed array in an Array is a copy)
	for n: String in names:
		var b: String = base(n)
		var s: String = stem(n)
		if KeenCloset.is_keen(fam, n) and not b.begins_with("EXTRAKEEN"):
			keen.append(n)
		elif _is_item(b):
			items.append(n)
		elif EFFECTS.has(s):
			effects.append(n)
		elif OTHER.has(s):
			other.append(n)
		else:
			if not creatures.is_empty():
				var last: Array = creatures[creatures.size() - 1]
				var p: String = _common(String(last[0]), s)
				if p.length() >= 3:
					last[0] = p
					(last[1] as Array).append(n)
					continue
			var joined: bool = false
			for c: Array in creatures:    # a family met before (the Dopefish's left frames after its bubbles)
				if String(c[0]).length() >= 4 and s.begins_with(String(c[0])):
					(c[1] as Array).append(n)
					joined = true
					break
			if not joined:
				creatures.append([s, [n]])
	var out: Array = []
	if not keen.is_empty():
		out.append(["Keen", keen, "keen"])
	var by_label: Dictionary = {}    # label -> [names]
	var labels: Array = []
	for c: Array in creatures:
		var label: String = _family_label(String(c[0]))
		if not by_label.has(label):
			by_label[label] = []
			labels.append(label)
		(by_label[label] as Array).append_array(c[1])
	for label: String in labels:
		out.append([label, PackedStringArray(by_label[label]), "creature"])
	for e: Array in [["Items", items, "items"], ["Shots and effects", effects, "effects"], ["Other", other, "other"]]:
		if not (e[1] as PackedStringArray).is_empty():
			out.append(e)
	return out


## A family's name from what its sprites' names share, a pose left at its end taken off (ASPARAGUSRUN ->
## Asparagus; a direction letter stays: MAPGRABBITER's R is its own).
static func _family_label(prefix: String) -> String:
	var p: String = prefix.trim_suffix("_")
	for pose: String in ["RUN", "WALK", "STAND"]:
		if p.ends_with(pose) and p.length() - pose.length() >= 4:
			p = p.left(-pose.length())
	return p.to_lower().capitalize()


static func _is_item(b: String) -> bool:
	if b != "" and b[0] >= "0" and b[0] <= "9":
		return true
	for p: String in ITEMS:
		if b.begins_with(p):
			return true
	return false


static func _common(a: String, b: String) -> String:
	var n: int = mini(a.length(), b.length())
	var i: int = 0
	while i < n and a[i] == b[i]:
		i += 1
	return a.left(i)


## A sprite's animation: [its frame (0-based), the names in frame order].
func frames_of(name: String) -> Array:
	var names: Array = _anims.get(anim_key(name), [name])
	return [maxi(names.find(name), 0), names]


## The EGA colours a sprite draws with: [[index, pixels]], the most used first.
func colours_used(name: String) -> Array:
	var s: Dictionary = sprites.get(name, {})
	if s.is_empty():
		return []
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(16)
	var px: PackedByteArray = s.pixels
	var op: PackedByteArray = s.opaque
	for k: int in range(px.size()):
		if op[k] != 0:
			counts[px[k] & 15] += 1
	var out: Array = []
	for i: int in range(16):
		if counts[i] > 0:
			out.append([i, counts[i]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out


## How many pixels of a sprite are see-through.
func clear_pixels(name: String) -> int:
	var s: Dictionary = sprites.get(name, {})
	if s.is_empty():
		return 0
	return (s.opaque as PackedByteArray).count(0)


# ---- what replaces what

func my_dir() -> String:
	return AssetPacks.mods_dir(game).path_join(MY_PACK)


## The packs' pictures read again (after a change, or the packs page's).
func refresh(settings: Settings) -> void:
	replaced = {}
	mine = {}
	_shown = {}
	var on: PackedStringArray = []
	for e: Array in AssetPacks.listing(settings, game):
		if e[1]:
			on.append(e[0])
	var p: AssetPacks = AssetPacks.new()
	p.load_packs(game, on, AssetStage.new())
	for nm: String in p.files:
		var f: Dictionary = p.files[nm]
		if sprites.has(nm) and _fits(nm, int(f.w), int(f.h)) > 0:
			replaced[nm] = f
	var d: DirAccess = DirAccess.open(my_dir())
	if d != null:
		for f: String in d.get_files():
			if f.get_extension().to_lower() == "png":
				mine[f.get_basename().to_upper()] = true


## The whole multiple a picture's size is of a sprite's (1 its own size), or 0 when it is none.
func _fits(name: String, w: int, h: int) -> int:
	var s: Dictionary = sprites[name]
	var sw: int = int(s.w)
	var sh: int = int(s.h)
	var k: int = w / sw
	return k if k >= 1 and w == sw * k and h == sh * k else 0


## The original as an RGBA picture (EGA colours, clear where it does not draw).
func original(name: String) -> Image:
	return AssetPacks.to_image(sprites.get(name, {}))


## What the game shows for a sprite now: a pack's picture at a whole multiple as it is (the native view's),
## one of the sprite's own size as the card has it (each pixel the nearest EGA colour, clear under half
## alpha), else the original.
func shown(name: String) -> Image:
	if _shown.has(name):
		return _shown[name]
	var im: Image = null
	if replaced.has(name):
		var f: Dictionary = replaced[name]
		var pic: Image = Image.load_from_file(String(f.path))
		if pic != null and not pic.is_empty():
			pic.convert(Image.FORMAT_RGBA8)
			im = as_game_sees(pic) if int(f.w) == int(sprites[name].w) else pic
	if im == null:
		im = original(name)
	_shown[name] = im
	return im


## A picture of a sprite's own size as the card draws it (V15-01's rule).
static func as_game_sees(pic: Image) -> Image:
	var out: Image = Image.create(pic.get_width(), pic.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in range(pic.get_height()):
		for x: int in range(pic.get_width()):
			var c: Color = pic.get_pixel(x, y)
			if c.a >= 0.5:
				out.set_pixel(x, y, KeenCloset.ega_color(KeenCloset.nearest_ega(c)))
	return out


# ---- checking, saving, reverting

## A file checked as a replacement for `name`: {ok, message, scale, image, note}. Refused with a plain
## message when it is not a PNG or its size is neither the sprite's nor a whole multiple of it; a picture
## with nothing see-through where the original has some is taken, with a note saying so.
func check(path: String, name: String) -> Dictionary:
	var file: String = path.get_file()
	var s: Dictionary = sprites.get(name, {})
	if s.is_empty():
		return {"ok": false, "message": "%s: %s has no picture named %s." % [file, title(), name]}
	var sw: int = int(s.w)
	var sh: int = int(s.h)
	var ext: String = path.get_extension().to_lower()
	if ext != "png":
		return {"ok": false, "message": "%s is not a PNG picture (%s). Save it as PNG (.png) in your paint program and try again." % [
			file, "a .%s file" % ext if ext != "" else "it has no .png ending"]}
	var size: Vector2i = AssetPacks.png_size(path)
	if size == Vector2i.ZERO:
		return {"ok": false, "message": "%s ends in .png but is not a PNG picture inside. Save it as PNG again and try again." % file}
	var k: int = _fits(name, size.x, size.y)
	if k == 0:
		return {"ok": false, "message": "%s is %dx%d. %s needs %dx%d, or a whole multiple of that: %dx%d (2x), %dx%d (3x), %dx%d (4x)." % [
			file, size.x, size.y, name, sw, sh, sw * 2, sh * 2, sw * 3, sh * 3, sw * 4, sh * 4]}
	var pic: Image = Image.load_from_file(path)
	if pic == null or pic.is_empty():
		return {"ok": false, "message": "%s could not be read as a picture. Save it as PNG again and try again." % file}
	pic.convert(Image.FORMAT_RGBA8)
	var clear: int = 0
	for y: int in range(pic.get_height()):
		for x: int in range(pic.get_width()):
			if pic.get_pixel(x, y).a < 0.5:
				clear += 1
	var note: String = ""
	if clear == 0 and clear_pixels(name) > 0:
		note = " Nothing in it is see-through, so it draws as a solid box; to see through a part, make it transparent (alpha under half) in your paint program."
	var how: String = ("its own size: drawn in every view, each colour as the nearest of the 16 EGA colours" if k == 1
		else "%dx: drawn at %d times the detail in Enhanced; Classic and the 320x200 picture keep the original" % [k, k])
	return {"ok": true, "scale": k, "image": pic, "note": note,
		"message": "%s (%dx%d) replaces %s, %s.%s" % [file, size.x, size.y, name, how, note]}


## Puts a checked file into My pack as `name` (the file's bytes as they are), My pack switched on and last.
## Returns check()'s answer (ok false: nothing was written).
func replace(path: String, name: String, settings: Settings) -> Dictionary:
	var r: Dictionary = check(path, name)
	if not r.ok:
		return r
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	DirAccess.make_dir_recursive_absolute(my_dir())
	var fa: FileAccess = FileAccess.open(my_dir().path_join(name + ".png"), FileAccess.WRITE)
	if fa == null or bytes.is_empty():
		return {"ok": false, "message": "Megarocket could not write into %s." % my_dir()}
	fa.store_buffer(bytes)
	fa.close()
	put_my_pack_on(settings)
	refresh(settings)
	r.message = String(r.message) + " Saved in My pack; it shows the next time you play."
	return r


## My pack in the "packs" setting switched on and last (a later pack wins), saved; nothing when it is so.
func put_my_pack_on(settings: Settings) -> void:
	var list: Array = AssetPacks.listing(settings, game)
	if not list.is_empty() and list[list.size() - 1] == [MY_PACK, true]:
		if settings.get_value("packs", game) != list:
			settings.set_value("packs", list, game)
			settings.save()
		return
	var out: Array = []
	for e: Array in list:
		if e[0] != MY_PACK:
			out.append(e)
	out.append([MY_PACK, true])
	settings.set_value("packs", out, game)
	settings.save()


## Several files at once (dropped on the window): one file with a sprite picked replaces it; otherwise
## each file replaces the sprite its name names (SPR_KEENSTANDR.png). Returns [names replaced, messages].
func replace_files(paths: PackedStringArray, picked: String, settings: Settings) -> Array:
	var done: PackedStringArray = []
	var lines: PackedStringArray = []
	for p: String in paths:
		var nm: String = picked if paths.size() == 1 and picked != "" else p.get_file().get_basename().to_upper()
		if not sprites.has(nm):
			lines.append("%s: %s has no picture named %s (name the file as the picture it replaces, as %s.png)." % [
				p.get_file(), title(), nm, picked if picked != "" else (categories[0][1][0] if not categories.is_empty() else "SPR_KEENSTANDR")])
			continue
		var r: Dictionary = replace(p, nm, settings)
		lines.append(String(r.message))
		if r.ok:
			done.append(nm)
	return [done, lines]


## My pack's picture of `name` taken out. Returns what it says.
func revert(name: String, settings: Settings) -> String:
	var f: String = my_dir().path_join(name + ".png")
	if not FileAccess.file_exists(f):
		return "%s is not replaced in My pack." % name
	DirAccess.remove_absolute(f)
	refresh(settings)
	if replaced.has(name):
		return "My pack's %s is gone; the pack \"%s\" still replaces it (switch it off on the Asset packs page)." % [name, replaced[name].pack]
	return "%s is the game's own again (from the next time you play)." % name


## The template for one sprite (the original as a PNG named as a pack wants it) in the player's templates
## folder; its path, or "" when it could not be written.
func export_template(name: String) -> String:
	var dir: String = AssetPacks.templates_dir(game).path_join("sprites")
	var im: Image = original(name)
	if im == null or DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var path: String = dir.path_join(name + ".png")
	return path if im.save_png(path) == OK else ""


func title() -> String:
	return FolderChooser.short_name(game) if game != "" else "the game"
