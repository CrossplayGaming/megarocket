# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: the released Keen Dreams source as carried in ReflectionHLE:
# id_ca.c (CAL_SetupGrFile, CAL_ExpandGrChunk, CAL_CacheSprite, CA_CacheMap,
# CA_CacheAudioChunk, mapfiletype), id_ca.h (maptype), id_vw.h
# (spritetabletype, pictabletype), graphkdr.h (chunk numbers), audiokdr.h,
# and ReflectionHLE's be_gamedefs_kdreams.h (where the executable keeps its
# dictionaries and headers) with its depklite.
class_name DreamsData
extends RefCounted
## Keen Dreams' files, EGA v1.00 or EGA v1.93 (the release in the
## Definitive Edition's DOS folder): the graphics, maps and sounds files and
## KDREAMS.EXE, whose unpacked image holds the Huffman dictionaries, chunk
## headers, map headers, texts and tile info the engine compiled in; v1.93
## also its title picture in KDREAMS.CMP. v1.93's graphics and sounds are
## v1.00's files renamed; its maps, texts and map headers are its own. Read
## into plain arrays; nothing here touches the engine.

# Per version, ReflectionHLE's be_gamedefs_kdreams.h: the files, how the
# program is packed, and {name: [offset into the unpacked image, size, CRC-32]}.
const VERSIONS: Dictionary = {
	"e100": {
		"name": "EGA v1.00", "graphics": "EGAGRAPH.KDR", "maps": "GAMEMAPS.KDR", "audio": "AUDIO.KDR",
		"packer": "pklite", "image_size": 175424 - 0x1A00,
		"embedded": {
			"AUDIODCT": [0x28984, 1024, 0x8B6116D7], "AUDIOHHD": [0x1F370, 340, 0x499E0CBF],
			"CONTEXT": [0x1F4D0, 4759, 0x5BAE2337], "EGADICT": [0x28188, 1024, 0xA69AF202],
			"EGAHEAD": [0x19610, 12068, 0xB9D789EE], "GAMETEXT": [0x20770, 4686, 0x046C5328],
			"MAPDICT": [0x28588, 1020, 0x8AA7334B], "MAPHEAD": [0x1C540, 11824, 0x4B9C9EBE],
			"PIRACY": [0x14970, 4001, 0x94458DEF], "STORY": [0x219C0, 2487, 0xED0EA5FE],
		},
	},
	"e193": {
		"name": "EGA v1.93", "graphics": "KDREAMS.EGA", "maps": "KDREAMS.MAP", "audio": "KDREAMS.AUD",
		"packer": "lzexe", "image_size": 213200 - 0x1C00,
		"embedded": {
			"AUDIODCT": [0x29FBA, 1024, 0x8B6116D7], "AUDIOHHD": [0x21990, 340, 0x499E0CBF],
			"CONTEXT": [0x21AF0, 1283, 0x5A33439D], "EGADICT": [0x297BE, 1024, 0xA69AF202],
			"EGAHEAD": [0x1BC30, 12068, 0xB9D789EE], "GAMETEXT": [0x22000, 4256, 0xBFE72F94],
			"MAPDICT": [0x29BBE, 1020, 0x6BB0DE32], "MAPHEAD": [0x1EB60, 11824, 0x2B821E29],
			"STORY": [0x230A0, 2526, 0xCAFC1D15],
		},
	},
}
# graphkdr.h
const NUMCHUNKS: int = 3016
const STRUCTPIC: int = 0
const STRUCTPICM: int = 1
const STRUCTSPRITE: int = 2
const STARTFONT: int = 3
const STARTPICS: int = 4
const NUMPICS: int = 65
const STARTPICM: int = 69
const NUMPICM: int = 2
const STARTSPRITES: int = 71
const NUMSPRITES: int = 297
const STARTTILE8: int = 368
const NUMTILE8: int = 72
const STARTTILE8M: int = 369
const NUMTILE8M: int = 36
const STARTTILE16: int = 370
const NUMTILE16: int = 1440
const STARTTILE16M: int = 1810
const NUMTILE16M: int = 1206
const NUM_MAPS: int = 100

var error: String = ""
var dir: String = ""
var image: PackedByteArray = PackedByteArray()        # the unpacked program
var _gr_dict: PackedInt32Array
var _gr_starts: PackedByteArray                        # 4 bytes per chunk, NUMCHUNKS + 1
var _gr_file: PackedByteArray
var _map_dict: PackedInt32Array
var _map_head: PackedByteArray                         # mapfiletype
var _maps_file: PackedByteArray
var _au_dict: PackedInt32Array
var _au_starts: PackedByteArray
var _au_file: PackedByteArray
var rle_tag: int = 0
var pic_table: Array[Dictionary] = []
var picm_table: Array[Dictionary] = []
var sprite_table: Array[Dictionary] = []
## A18 / PREP-01: the asset stage the sprite chunks pass through as they are expanded (identity unless
## filters are set)
var stage: AssetStage = AssetStage.new()
var tileinfo: PackedByteArray = PackedByteArray()
var game_text: PackedByteArray = PackedByteArray()
var context_text: PackedByteArray = PackedByteArray()
var story_text: PackedByteArray = PackedByteArray()
var piracy_screen: PackedByteArray = PackedByteArray()   # v1.00 only
## "e100" or "e193", set by load_game.
var version: String = ""
## v1.93: the title picture (SoftLib.load_lib_shape of TITLESCR.LBM in KDREAMS.CMP).
var title_shape: Dictionary = {}


static func u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func s16(b: PackedByteArray, o: int) -> int:
	var v: int = b[o] | (b[o + 1] << 8)
	return v - 0x10000 if v >= 0x8000 else v


static func u32(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


func _fail(msg: String) -> bool:
	if error == "":
		error = msg
	return false


func _game_path(name: String) -> String:
	var d: DirAccess = DirAccess.open(dir)
	if d != null:
		for f: String in d.get_files():
			if f.to_upper() == name.to_upper():
				return dir.path_join(f)
	return dir.path_join(name)


func _read(name: String) -> PackedByteArray:
	var path: String = _game_path(name)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("%s: cannot open (%s)" % [name, error_string(FileAccess.get_open_error())])
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return data


func _embedded(name: String) -> PackedByteArray:
	var e: Array = VERSIONS[version].embedded[name]
	if e[0] + e[1] > image.size():
		_fail("KDREAMS.EXE: %s lies past the end of the unpacked program" % name)
		return PackedByteArray()
	var bytes: PackedByteArray = image.slice(e[0], e[0] + e[1])
	if GameFinder.crc32(bytes) != e[2]:
		_fail("KDREAMS.EXE: its %s is not Keen Dreams %s's (another version of the program?)" % [name, VERSIONS[version].name])
		return PackedByteArray()
	return bytes


func _dict(name: String) -> PackedInt32Array:
	var raw: PackedByteArray = _embedded(name)
	var d: PackedInt32Array = PackedInt32Array()
	if raw.size() < 1020:
		return d
	d.resize(512)
	for i: int in range(min(512, raw.size() / 2)):
		d[i] = u16(raw, i * 2)
	return d


func load_game(game_dir: String) -> bool:
	dir = game_dir
	error = ""
	# the version by its files: v1.93 names them KDREAMS.EGA/.MAP/.AUD
	version = "e193" if FileAccess.file_exists(_game_path("KDREAMS.EGA")) else "e100"
	var v: Dictionary = VERSIONS[version]
	var exe: PackedByteArray = _read("KDREAMS.EXE")
	if exe.is_empty():
		return false
	if v.packer == "pklite":
		image = PkLite.unpack(exe, v.image_size)
		if image.is_empty():
			return _fail("KDREAMS.EXE: %s (not the %s program?)" % [PkLite.error, v.name])
	else:
		image = LzExe.unpack(exe)
		if image.is_empty():
			return _fail("KDREAMS.EXE: %s (not the %s program?)" % [LzExe.error, v.name])
	_gr_dict = _dict("EGADICT")
	_map_dict = _dict("MAPDICT")
	_au_dict = _dict("AUDIODCT")
	_gr_starts = _embedded("EGAHEAD")
	_map_head = _embedded("MAPHEAD")
	_au_starts = _embedded("AUDIOHHD")
	game_text = _embedded("GAMETEXT")
	context_text = _embedded("CONTEXT")
	story_text = _embedded("STORY")
	piracy_screen = _embedded("PIRACY") if version == "e100" else PackedByteArray()
	if error != "":
		return false
	if _gr_starts.size() != (NUMCHUNKS + 1) * 4:
		return _fail("KDREAMS.EXE: EGAHEAD is %d bytes, want %d" % [_gr_starts.size(), (NUMCHUNKS + 1) * 4])
	_gr_file = _read(v.graphics)
	_maps_file = _read(v.maps)
	_au_file = _read(v.audio)
	if error != "":
		return false
	if version == "e193":
		title_shape = SoftLib.load_lib_shape(_read("KDREAMS.CMP"), "TITLESCR.LBM")
		if error != "":
			return false
		if title_shape.is_empty():
			return _fail("KDREAMS.CMP: " + SoftLib.error)
	var last: int = u32(_gr_starts, NUMCHUNKS * 4)
	if last != _gr_file.size():
		return _fail("%s: %d bytes, but the program's header ends it at %d -- another version of the game" % [v.graphics, _gr_file.size(), last])
	rle_tag = u16(_map_head, 0)
	tileinfo = _map_head.slice(502)
	# every map the header lists must lie inside GAMEMAPS: a map "missing"
	# because the file is short is an error to report, not a map to skip
	for i: int in range(NUM_MAPS):
		var off: int = u32(_map_head, 2 + i * 4)
		if off == 0xFFFFFFFF or off < 8:
			continue
		if off + _map_head[402 + i] > _maps_file.size():
			return _fail("%s: map %d's header at %d lies past the end of the %d-byte file" % [v.maps, i, off, _maps_file.size()])
	# tables: chunks 0, 1, 2 (Huffman, explicit length ignored: sizes are known)
	var pt: PackedByteArray = _table(STRUCTPIC, NUMPICS * 4)
	var pmt: PackedByteArray = _table(STRUCTPICM, NUMPICS * 4)   # the original expands NUMPICS entries here (a vanilla slip)
	var st: PackedByteArray = _table(STRUCTSPRITE, NUMSPRITES * 18)
	if error != "":
		return false
	pic_table = []
	for i: int in range(NUMPICS):
		pic_table.append({"w": u16(pt, i * 4), "h": u16(pt, i * 4 + 2)})
	picm_table = []
	for i: int in range(NUMPICM):
		picm_table.append({"w": u16(pmt, i * 4), "h": u16(pmt, i * 4 + 2)})
	sprite_table = []
	for i: int in range(NUMSPRITES):
		var e: int = i * 18
		sprite_table.append({"w": u16(st, e), "h": u16(st, e + 2), "orgx": s16(st, e + 4), "orgy": s16(st, e + 6),
			"xl": s16(st, e + 8), "yl": s16(st, e + 10), "xh": s16(st, e + 12), "yh": s16(st, e + 14), "shifts": u16(st, e + 16)})
	stage.bind("kdreams", AssetStage.dreams_names(STARTSPRITES, NUMSPRITES))
	return true


func chunk_start(c: int) -> int:
	return u32(_gr_starts, c * 4)


func _table(c: int, size: int) -> PackedByteArray:
	var start: int = chunk_start(c) + 4
	var comp: int = chunk_start(c + 1) - chunk_start(c) - 4
	return GalData.new().huff_expand(_gr_file, start, comp, size, _gr_dict, "EGAGRAPH.KDR chunk %d" % c)


## One graphics chunk, expanded (sprites: the unshifted five planes).
func chunk(c: int) -> PackedByteArray:
	if c < 0 or c >= NUMCHUNKS:
		_fail("EGAGRAPH.KDR: no chunk %d" % c)
		return PackedByteArray()
	var start: int = chunk_start(c)
	if start == 0xFFFFFFFF:
		return PackedByteArray()       # a sparse chunk (an unused tile)
	# the chunk ends where the next PRESENT chunk starts (CAL_GetGrChunkLength
	# reads grstarts[chunk+1], which the data keeps valid for present chunks;
	# the tile tables mark unused tiles with -1, so look past those)
	var n: int = c + 1
	var next: int = chunk_start(n)
	while next == 0xFFFFFFFF and n < NUMCHUNKS:
		n += 1
		next = chunk_start(n)
	if next < start or next > _gr_file.size():
		_fail("EGAGRAPH.KDR: chunk %d (%d..%d) lies past the end of the %d-byte file" % [c, start, next, _gr_file.size()])
		return PackedByteArray()
	if next == start:
		return PackedByteArray()
	var length: int
	var src: int = start
	var comp: int = next - start
	if c >= STARTTILE8:
		if c < STARTTILE8M:
			length = 32 * NUMTILE8
		elif c < STARTTILE16:
			length = 40 * NUMTILE8M
		elif c < STARTTILE16M:
			length = 128
		else:
			length = 160
	else:
		length = u32(_gr_file, start)
		src += 4
		comp -= 4
		if c >= STARTSPRITES and c < STARTSPRITES + NUMSPRITES:
			var s: Dictionary = sprite_table[c - STARTSPRITES]
			length = s.w * s.h * 5
	if length <= 0 or length > 0x100000:
		_fail("EGAGRAPH.KDR: chunk %d claims %d bytes" % [c, length])
		return PackedByteArray()
	var g: GalData = GalData.new()
	var out: PackedByteArray = g.huff_expand(_gr_file, src, comp, length, _gr_dict, "EGAGRAPH.KDR chunk %d" % c)
	if g.error != "":
		_fail(g.error)
	elif c >= STARTSPRITES and c < STARTSPRITES + NUMSPRITES:
		var st: Dictionary = sprite_table[c - STARTSPRITES]
		return stage.planar_masked(c, out, st.w, st.h)
	return out


func pic(i: int) -> Dictionary:
	var t: Dictionary = pic_table[i]
	var data: PackedByteArray = chunk(STARTPICS + i)
	if data.size() < t.w * t.h * 4:
		_fail("EGAGRAPH.KDR: picture %d is %d bytes, needs %d" % [i, data.size(), t.w * t.h * 4])
		return {}
	return {"w": t.w * 8, "h": t.h, "pixels": GalData.unplane(data, 0, t.w, t.h)}


func masked_pic(i: int) -> Dictionary:
	var t: Dictionary = picm_table[i]
	var data: PackedByteArray = chunk(STARTPICM + i)
	if data.size() < t.w * t.h * 5:
		_fail("EGAGRAPH.KDR: masked picture %d is %d bytes, needs %d" % [i, data.size(), t.w * t.h * 5])
		return {}
	var m: Dictionary = GalData.unplane_masked(data, 0, t.w, t.h)
	return {"w": t.w * 8, "h": t.h, "pixels": m.pixels, "mask": m.mask}


func sprite(i: int) -> Dictionary:
	var t: Dictionary = sprite_table[i]
	var data: PackedByteArray = chunk(STARTSPRITES + i)
	if data.size() < t.w * t.h * 5:
		_fail("EGAGRAPH.KDR: sprite %d is %d bytes, needs %d" % [i, data.size(), t.w * t.h * 5])
		return {}
	var m: Dictionary = GalData.unplane_masked(data, 0, t.w, t.h)
	return {"w": t.w * 8, "h": t.h, "pixels": m.pixels, "mask": m.mask, "orgx": t.orgx, "orgy": t.orgy,
		"xl": t.xl, "yl": t.yl, "xh": t.xh, "yh": t.yh, "shifts": t.shifts}


func tiles16() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(NUMTILE16 * 256)
	for i: int in range(NUMTILE16):
		var data: PackedByteArray = chunk(STARTTILE16 + i)
		if data.is_empty():
			continue
		var px: PackedByteArray = GalData.unplane(data, 0, 2, 16)
		for k: int in range(256):
			out[i * 256 + k] = px[k]
	return out


func tiles16m() -> Dictionary:
	var px_all: PackedByteArray = PackedByteArray()
	var mk_all: PackedByteArray = PackedByteArray()
	px_all.resize(NUMTILE16M * 256)
	mk_all.resize(NUMTILE16M * 256)
	for i: int in range(NUMTILE16M):
		var data: PackedByteArray = chunk(STARTTILE16M + i)
		if data.is_empty():
			continue
		var m: Dictionary = GalData.unplane_masked(data, 0, 2, 16)
		for k: int in range(256):
			px_all[i * 256 + k] = m.pixels[k]
			mk_all[i * 256 + k] = m.mask[k]
	return {"pixels": px_all, "mask": mk_all}


func font() -> Dictionary:
	var data: PackedByteArray = chunk(STARTFONT)
	if data.size() < 2 + 512 + 256:
		_fail("EGAGRAPH.KDR: chunk %d is not a font" % STARTFONT)
		return {}
	var height: int = u16(data, 0)
	var glyphs: Array = []
	var widths: PackedByteArray = PackedByteArray()
	for ch: int in range(256):
		var loc: int = u16(data, 2 + ch * 2)
		var w: int = data[2 + 512 + ch]
		widths.append(w)
		var wbytes: int = (w + 7) / 8
		var g: PackedByteArray = PackedByteArray()
		g.resize(w * height)
		for y: int in range(height):
			for x: int in range(w):
				var o: int = loc + y * wbytes + (x >> 3)
				g[y * w + x] = int(o < data.size() and (data[o] & (0x80 >> (x & 7))) != 0)
		glyphs.append(g)
	return {"height": height, "widths": widths, "glyphs": glyphs}


func has_map(i: int) -> bool:
	if i < 0 or i >= NUM_MAPS:
		return false
	var off: int = u32(_map_head, 2 + i * 4)
	return off >= 8 and off != 0xFFFFFFFF


## {width, height, name, plane: [3 PackedInt32Array]}. The 38-byte header
## and each plane are Huffman-packed with the map dictionary; each plane
## then holds its expanded length and an RLEW stream.
func load_map(i: int) -> Dictionary:
	var name: String = "GAMEMAPS.KDR"
	if not has_map(i):
		_fail("%s: map %d does not exist" % [name, i])
		return {}
	var off: int = u32(_map_head, 2 + i * 4)
	var hsize: int = _map_head[402 + i]
	var g: GalData = GalData.new()
	var hdr: PackedByteArray = g.huff_expand(_maps_file, off, hsize, 38, _map_dict, "%s map %d header" % [name, i])
	if g.error != "":
		_fail(g.error)
		return {}
	var width: int = u16(hdr, 18)
	var height: int = u16(hdr, 20)
	if width <= 0 or height <= 0 or width > 512 or height > 512:
		_fail("%s: map %d is %dx%d" % [name, i, width, height])
		return {}
	var plane_bytes: int = width * height * 2
	var planes: Array = []
	for p: int in range(3):
		var poff: int = u32(hdr, p * 4)
		var plen: int = u16(hdr, 12 + p * 2)
		if poff + plen > _maps_file.size() or plen < 2:
			_fail("%s: map %d plane %d (%d bytes at %d) lies past the end" % [name, i, p, plen, poff])
			return {}
		var expanded: int = u16(_maps_file, poff)
		var rlew: PackedByteArray = g.huff_expand(_maps_file, poff + 2, plen - 2, expanded, _map_dict, "%s map %d plane %d" % [name, i, p])
		if g.error != "":
			_fail(g.error)
			return {}
		var data: PackedByteArray = g.rlew_expand(rlew, 2, plane_bytes, rle_tag, "%s map %d plane %d" % [name, i, p])
		if g.error != "":
			_fail(g.error)
			return {}
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(width * height)
		for k: int in range(width * height):
			words[k] = u16(data, k * 2)
		planes.append(words)
	return {"width": width, "height": height, "name": hdr.slice(22, 38).get_string_from_ascii().strip_edges(), "plane": planes}


## A map's planes as the cache reads them: [compressed length, Huffman-expanded length] each
## (the sizes of the blocks CA_CacheMap allocates for them).
func map_plane_sizes(i: int) -> Array:
	var off: int = u32(_map_head, 2 + i * 4)
	var g: GalData = GalData.new()
	var hdr: PackedByteArray = g.huff_expand(_maps_file, off, _map_head[402 + i], 38, _map_dict, "map %d header" % i)
	var out: Array = []
	for p: int in range(3):
		var poff: int = u32(hdr, p * 4)
		out.append([u16(hdr, 12 + p * 2), u16(_maps_file, poff)])
	return out


## MAKER-01 for Keen Dreams: the maker's map set (TedMaps.write: MAPHEAD as the program links it, with its
## tile info, and GAMEMAPS) in place of the program's table and the folder's GAMEMAPS. Only with a player
## at the controls (the maker's play button); the game's own files are never written.
func use_maps(maphead: PackedByteArray, gamemaps: PackedByteArray) -> bool:
	if maphead.size() != _map_head.size() or u16(maphead, 0) != u16(_map_head, 0):
		return _fail("the maker's MAPHEAD is %d bytes, the program's %d" % [maphead.size(), _map_head.size()])
	for i: int in range(NUM_MAPS):
		var off: int = u32(maphead, 2 + i * 4)
		if off != 0xFFFFFFFF and off >= 8 and off + maphead[402 + i] > gamemaps.size():
			return _fail("the maker's GAMEMAPS: map %d lies past its end" % i)
	_map_head = maphead
	_maps_file = gamemaps
	rle_tag = u16(_map_head, 0)
	tileinfo = _map_head.slice(502)
	return true


## The map header as the program links it in (mapfiletype: RLEW tag, offsets, sizes, then the
## tile info id_ca.c's tinf indexes from the start: tinf[SPEED + tile], SPEED = 502).
func map_header() -> PackedByteArray:
	return _map_head


func num_audio_chunks() -> int:
	return _au_starts.size() / 4 - 1


func audio_chunk(c: int) -> PackedByteArray:
	if c < 0 or (c + 1) * 4 + 4 > _au_starts.size():
		_fail("AUDIO.KDR: no chunk %d" % c)
		return PackedByteArray()
	var pos: int = u32(_au_starts, c * 4)
	var comp: int = u32(_au_starts, (c + 1) * 4) - pos
	if comp <= 4:
		return PackedByteArray()
	if pos + 4 > _au_file.size():
		_fail("AUDIO.KDR: chunk %d at %d lies past the end" % [c, pos])
		return PackedByteArray()
	if pos + comp > _au_file.size():
		# the empty digitised-sound and music slots that follow the last
		# AdLib effect carry a start past the end of this file; the original
		# reads what is there (CA_FarRead comes up short and carries on)
		comp = _au_file.size() - pos
	var expanded: int = u32(_au_file, pos)
	if expanded < 0 or expanded > 0x100000:
		_fail("AUDIO.KDR: chunk %d claims %d bytes" % [c, expanded])
		return PackedByteArray()
	var g: GalData = GalData.new()
	var out: PackedByteArray = g.huff_expand(_au_file, pos + 4, comp - 4, expanded, _au_dict, "AUDIO.KDR chunk %d" % c)
	if g.error != "":
		_fail(g.error)
	return out
