# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name TitleArt
extends RefCounted
## The launcher's tile art (J-12: title-art tiles; the engines render their
## own title screens, no data shipped): each found game's title screen, made
## from the player's own files. Keen 1-3 run their engine headless to the
## title (16 emulated seconds, a few seconds of work); Keen 4-6 decode their
## PIC_TITLESCREEN; Keen Dreams v1.93 its TITLESCR.LBM. A picture is cached
## in user://titles (the player's machine only) by the files' identity.

const CACHE: String = "user://titles"
const EGA: PackedByteArray = [0, 0, 0, 0, 0, 170, 0, 170, 0, 0, 170, 170, 170, 0, 0, 170, 0, 170, 170, 85, 0, 170, 170, 170,
	85, 85, 85, 85, 85, 255, 85, 255, 85, 85, 255, 255, 255, 85, 85, 255, 85, 255, 255, 255, 85, 255, 255, 255]
const META: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const VORTICONS_TITLE_SECONDS: float = 16.0


static func cache_path(found: Dictionary) -> String:
	var key: String = "%s|%s|%s" % [found.id, found.get("version", ""), String(found.get("folder", "")).to_lower()]
	return CACHE.path_join("%s_%s.png" % [found.id, key.sha1_text().left(12)])


## The title screen as an image, from the cache or made now (blocking: call
## it off the main thread). null when the game has none the port can make.
static func make(found: Dictionary) -> Image:
	var path: String = cache_path(found)
	if FileAccess.file_exists(path):
		var cached: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if cached != null:
			return cached
	var img: Image = null
	match String(found.id):
		"keen1", "keen2", "keen3":
			img = _vorticons(found)
		"keen4", "keen5", "keen6":
			img = _galaxy(found)
		"kdreams":
			img = _dreams(found)
	if img != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
		img.save_png(ProjectSettings.globalize_path(path))
	return img


static func _from_indices(w: int, h: int, idx: PackedByteArray) -> Image:
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(w * h * 3)
	for i: int in range(w * h):
		var c: int = (idx[i] & 15) * 3
		rgb[i * 3] = EGA[c]
		rgb[i * 3 + 1] = EGA[c + 1]
		rgb[i * 3 + 2] = EGA[c + 2]
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, rgb)


static func _vorticons(found: Dictionary) -> Image:
	var n: String = String(found.id).substr(4, 1)
	var d: VortData = VortData.new()
	if not d.load_game(found.folder, "CK" + n):
		return null
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen3.new() if n == "3" else (VortKeen2.new() if n == "2" else VortKeen1.new())
	g.vm = vm
	g.data = d
	g.save_dir = OS.get_temp_dir().path_join("megarocket_title_" + String(found.id))
	g.apply_dosbox_timing()
	var shot: Array = [PackedByteArray()]
	vm.on_display = func() -> void:
		if vm.card.video_mode == EgaCard.MODE_EGA and vm.seconds() >= VORTICONS_TITLE_SECONDS and shot[0].is_empty():
			shot[0] = vm.card.frame_rgb()
			g.exited = true
	vm.time_limit = DosMachine.seconds_to_units(VORTICONS_TITLE_SECONDS + 5.0)
	vm.on_limit = func() -> void:
		g.exited = true
	g.main()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	vm.int8 = Callable()
	vm.int9 = Callable()
	g.vm = null
	if shot[0].is_empty():
		return null
	return Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, shot[0])


static func _galaxy(found: Dictionary) -> Image:
	var d: GalData = GalData.new()
	if not d.load_game(found.folder, "res://data/omnispeak".path_join(META[found.id])):
		return null
	var chunk: int = d.chunk_names.get_int("PIC_TITLESCREEN", -1)
	if chunk < 0:
		return null
	var b: Dictionary = d.bitmap(chunk - int(d.gfx.offBitmaps))
	if b.is_empty():
		return null
	return _from_indices(b.w, b.h, b.pixels)


static func _dreams(found: Dictionary) -> Image:
	var d: DreamsData = DreamsData.new()
	if not d.load_game(found.folder) or d.title_shape.is_empty():
		return null
	var s: Dictionary = d.title_shape
	var bpr: int = ((int(s.bpr) + 1) >> 1) << 1
	var data: PackedByteArray = s.data
	var src: int = 0
	var planes: Array = []
	for p: int in range(4):
		var pl: PackedByteArray = PackedByteArray()
		pl.resize(bpr * 200)
		planes.append(pl)
	# ILBM ByteRun1 rows, plane by plane
	for y: int in range(200):
		for p: int in range(4):
			var left: int = bpr
			var at: int = y * bpr
			while left > 0 and src < data.size():
				var n: int = data[src] if s.comp != 0 else left - 1
				if s.comp != 0:
					src += 1
				if n >= 128:
					n -= 256
				if n < 0:
					if n != -128:
						var rep: int = data[src]
						src += 1
						for k: int in range(-n + 1):
							planes[p][at] = rep
							at += 1
						left -= -n + 1
					else:
						left -= 1
				else:
					for k: int in range(n + 1):
						planes[p][at] = data[src]
						at += 1
						src += 1
					left -= n + 1
	var idx: PackedByteArray = PackedByteArray()
	idx.resize(320 * 200)
	for y: int in range(200):
		for x: int in range(320):
			var bit: int = 7 - (x & 7)
			var c: int = 0
			for p: int in range(4):
				c |= (((planes[p] as PackedByteArray)[y * bpr + (x >> 3)] >> bit) & 1) << p
			idx[y * 320 + x] = c
	return _from_indices(320, 200, idx)
