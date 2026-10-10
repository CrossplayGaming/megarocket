# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: omnispeak's id_ca.c (CAL_SetupMapFile, CA_CacheMap) and id_ca.h
# (CA_MapHead, CA_MapHeader); the released Keen Dreams source as carried in
# ReflectionHLE: id_ca.c (CA_CacheMap, mapfiletype) and id_ca.h (maptype).
class_name TedMaps
extends RefCounted
## The map files id's TED5 editor wrote for Keen 4, 5, 6 and Keen Dreams: a
## GAMEMAPS file of up to 100 maps and the MAPHEAD table that finds them, read
## into KeenLevels and written back as a whole new pair.
##
## GAMEMAPS starts "TED5v1.0" (and three bytes TED5 left there); then, map by
## map, its three planes, its 38-byte header (plane offsets and lengths,
## width, height, a 16-byte name) and, in Keen 4-6, "!ID!". Each plane is
## its packed length word and then the packed form of an RLEW stream (tag
## ABCD) that itself starts with the plane's byte length. Keen 4-6 pack with
## Carmack compression; Dreams packs the planes and the headers with Huffman
## and the map dictionary its program carries.
##
## MAPHEAD is the RLEW tag and 100 file offsets (0 where no map); Dreams
## adds a byte per map for its packed header's size, then the tile info. The
## games keep MAPHEAD inside the program (omnispeak ships Keen 4-6's as
## files; Keen 6 v1.0's is read from KEEN6C.EXE, Dreams' from KDREAMS.EXE),
## so a written MAPHEAD is a file a port can load, not a patch to a program.
##
## Expanding reuses the games' own GalData decoders.

const NUM_MAPS: int = 100
const HEADER_BYTES: int = 38
const OFFSETS_END: int = 2 + NUM_MAPS * 4       # MAPHEAD: the tag and the offsets
const DREAMS_SIZES_END: int = OFFSETS_END + NUM_MAPS
const SIGNATURE: String = "TED5v1.0"
const MAP_END: String = "!ID!"                   # after each Keen 4-6 map header

var error: String = ""
## KeenLevel.GALAXY (Carmack) or KeenLevel.DREAMS (Huffman).
var engine: String = KeenLevel.GALAXY
var rle_tag: int = 0xABCD
## NUM_MAPS slots, null where there is no map.
var maps: Array[KeenLevel] = []
## The GAMEMAPS bytes before the first map, as read ("TED5v1.0" and TED5's three).
var prelude: PackedByteArray = PackedByteArray()
## MAPHEAD's bytes after the offsets (Dreams: after the header sizes, the tile info).
var head_tail: PackedByteArray = PackedByteArray()
## Dreams: the map Huffman dictionary (512 links).
var dict: PackedInt32Array = PackedInt32Array()
## The files as read, kept for comparing a write against, and where MAPHEAD came from.
var source_head: PackedByteArray = PackedByteArray()
var source_maps: PackedByteArray = PackedByteArray()
var head_from: String = ""
## Per map as read: [start, end) in GAMEMAPS (first plane up to the next map); (0, 0) where none.
var spans: Array[Vector2i] = []
var _codes: Array[PackedByteArray] = []


func _init() -> void:
	maps.resize(NUM_MAPS)
	spans.resize(NUM_MAPS)


func _fail(msg: String) -> bool:
	if error == "":
		error = msg
	return false


## How many maps the set holds.
func map_count() -> int:
	var n: int = 0
	for level: KeenLevel in maps:
		if level != null:
			n += 1
	return n


## The bytes up to the first NUL, as text.
static func ascii_z(bytes: PackedByteArray) -> String:
	var end: int = bytes.find(0)
	return (bytes if end < 0 else bytes.slice(0, end)).get_string_from_ascii()


# --------------------------------------------------------------- reading

## Read a MAPHEAD and GAMEMAPS pair. Dreams needs `dict` set first.
## False with `error` naming `label` on any fault.
func read(maphead: PackedByteArray, gamemaps: PackedByteArray, label: String) -> bool:
	error = ""
	source_head = maphead
	source_maps = gamemaps
	maps.clear()
	maps.resize(NUM_MAPS)
	spans.clear()
	spans.resize(NUM_MAPS)
	var dreams: bool = engine == KeenLevel.DREAMS
	var head_end: int = DREAMS_SIZES_END if dreams else OFFSETS_END
	if maphead.size() < head_end:
		return _fail("%s: MAPHEAD is %d bytes, want at least %d" % [label, maphead.size(), head_end])
	if dreams and dict.size() < 512:
		return _fail("%s: no map dictionary to expand Dreams maps with" % label)
	rle_tag = maphead.decode_u16(0)
	head_tail = maphead.slice(head_end)
	var g: GalData = GalData.new()
	var ends: Dictionary = {}          # map -> where its header ends in the file
	for i: int in range(NUM_MAPS):
		var off: int = maphead.decode_u32(2 + i * 4)
		if off == 0 or off == 0xFFFFFFFF:
			continue
		var hsize: int = maphead[OFFSETS_END + i] if dreams else HEADER_BYTES
		if off + hsize > gamemaps.size():
			return _fail("%s: map %d's header at %d lies past the end of the %d-byte file" % [label, i, off, gamemaps.size()])
		var hdr: PackedByteArray
		if dreams:
			hdr = g.huff_expand(gamemaps, off, hsize, HEADER_BYTES, dict, "%s map %d header" % [label, i])
		else:
			hdr = gamemaps.slice(off, off + HEADER_BYTES)
		if g.error != "":
			return _fail(g.error)
		var level: KeenLevel = KeenLevel.new()
		level.engine = engine
		level.number = i
		level.width = hdr.decode_u16(18)
		level.height = hdr.decode_u16(20)
		level.keep["name_field"] = hdr.slice(22, 38)
		level.name = ascii_z(hdr.slice(22, 38))
		var cells: int = level.width * level.height
		if level.width <= 0 or level.height <= 0 or cells * 2 > 0xFFFF:
			return _fail("%s: map %d is %dx%d" % [label, i, level.width, level.height])
		var start: int = off
		for p: int in range(3):
			var poff: int = hdr.decode_u32(p * 4)
			var plen: int = hdr.decode_u16(12 + p * 2)
			var what: String = "%s map %d plane %d" % [label, i, p]
			if plen < 2 or poff + plen > gamemaps.size():
				return _fail("%s: %d bytes at %d lie past the end" % [what, plen, poff])
			start = mini(start, poff)
			var packed: int = gamemaps.decode_u16(poff)
			var rlew: PackedByteArray
			if dreams:
				rlew = g.huff_expand(gamemaps, poff + 2, plen - 2, packed, dict, what)
			else:
				rlew = g.carmack_expand(gamemaps, poff + 2, packed, what)
			if g.error != "":
				return _fail(g.error)
			var data: PackedByteArray = g.rlew_expand(rlew, 2, cells * 2, rle_tag, what)
			if g.error != "":
				return _fail(g.error)
			level.planes.append(LevelCodec.bytes_to_words(data, 0, cells))
		maps[i] = level
		spans[i] = Vector2i(start, off + hsize)
		ends[i] = off + hsize
	# what lies between one map and the next (Keen 4-6's "!ID!") belongs to the
	# map before it; what lies before the first map is the file's own
	var order: Array = ends.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return spans[a].x < spans[b].x)
	var first: int = gamemaps.size()
	for k: int in range(order.size()):
		var i: int = order[k]
		first = mini(first, spans[i].x)
		var next: int = spans[order[k + 1]].x if k + 1 < order.size() else gamemaps.size()
		maps[i].keep["after"] = gamemaps.slice(ends[i], next) if next > ends[i] else PackedByteArray()
		spans[i] = Vector2i(spans[i].x, maxi(next, ends[i]))
	prelude = gamemaps.slice(0, first)
	return true


## The player's Keen 4, 5 or 6 maps: GAMEMAPS from `game_dir`, MAPHEAD from the
## executable for builds GalData knows (Keen 6 v1.0), else from omnispeak's
## data folder `meta_dir` (keen4, keen5, keen6e14, keen6e15). Check `error`.
static func open_galaxy(game_dir: String, meta_dir: String) -> TedMaps:
	var m: TedMaps = TedMaps.new()
	m.engine = KeenLevel.GALAXY
	var digit: String = meta_dir.get_file().substr(4, 1)
	var maps_name: String = "GAMEMAPS.CK" + digit
	var maphead: PackedByteArray = PackedByteArray()
	# the same choice GalData makes: a build it knows by its hash brings its own table
	for f: String in DirAccess.get_files_at(game_dir):
		var up: String = f.to_upper()
		if up.begins_with("KEEN" + digit) and up.ends_with(".EXE"):
			var exe: PackedByteArray = FileAccess.get_file_as_bytes(game_dir.path_join(f))
			var h: HashingContext = HashingContext.new()
			h.start(HashingContext.HASH_SHA256)
			h.update(exe)
			var k: Dictionary = GalData.KNOWN_EXES.get(h.finish().hex_encode(), {})
			if k.is_empty():
				continue
			var img: PackedByteArray = LzExe.unpack(exe)
			if img.size() == k.image_size:
				maphead = img.slice(k.map_head, k.map_head + OFFSETS_END)
				m.head_from = "the map table in " + f
				break
	if maphead.is_empty():
		var path: String = meta_dir.path_join("MAPHEAD.CK" + digit)
		maphead = FileAccess.get_file_as_bytes(path)
		m.head_from = path
		if maphead.is_empty():
			m._fail("MAPHEAD.CK%s: cannot open %s" % [digit, path])
			return m
	var gamemaps: PackedByteArray = FileAccess.get_file_as_bytes(_find(game_dir, maps_name))
	if gamemaps.is_empty():
		m._fail("%s: cannot open in %s" % [maps_name, game_dir])
		return m
	m.read(maphead, gamemaps, maps_name)
	return m


## The player's Keen Dreams maps (EGA v1.00 or v1.93), with MAPHEAD and the
## map dictionary from the program as DreamsData finds them. Check `error`.
static func open_dreams(game_dir: String) -> TedMaps:
	var m: TedMaps = TedMaps.new()
	m.engine = KeenLevel.DREAMS
	var dd: DreamsData = DreamsData.new()
	if not dd.load_game(game_dir):
		m._fail(dd.error)
		return m
	var v: Dictionary = DreamsData.VERSIONS[dd.version]
	var mh: Array = v.embedded["MAPHEAD"]
	var md: Array = v.embedded["MAPDICT"]
	m.dict = LevelCodec.bytes_to_words(dd.image.slice(md[0], md[0] + md[1]))
	m.dict.resize(512)          # the program keeps 255 nodes; the 256th is never reached
	m.head_from = "the map table in KDREAMS.EXE (%s)" % v.name
	var gamemaps: PackedByteArray = FileAccess.get_file_as_bytes(_find(game_dir, v.maps))
	if gamemaps.is_empty():
		m._fail("%s: cannot open in %s" % [v.maps, game_dir])
		return m
	m.read(dd.image.slice(mh[0], mh[0] + mh[1]), gamemaps, v.maps)
	return m


static func _find(dir: String, name: String) -> String:
	for f: String in DirAccess.get_files_at(dir):
		if f.to_upper() == name.to_upper():
			return dir.path_join(f)
	return dir.path_join(name)


# --------------------------------------------------------------- writing

## The whole set as {"maphead": bytes, "gamemaps": bytes}; empty with `error`
## on fault. Maps are laid out in slot order, as TED5 did.
func write() -> Dictionary:
	error = ""
	var dreams: bool = engine == KeenLevel.DREAMS
	if dreams and _codes.is_empty():
		if dict.size() < 512:
			_fail("no map dictionary to pack Dreams maps with")
			return {}
		_codes = LevelCodec.huff_codes(dict)
	var gm: PackedByteArray = prelude.duplicate() if not prelude.is_empty() else SIGNATURE.to_ascii_buffer()
	var head: PackedByteArray = PackedByteArray()
	head.resize(DREAMS_SIZES_END if dreams else OFFSETS_END)
	head.encode_u16(0, rle_tag)
	for i: int in range(NUM_MAPS):
		var level: KeenLevel = maps[i]
		if level == null:
			continue
		var cells: int = level.width * level.height
		if level.width <= 0 or level.height <= 0 or cells * 2 > 0xFFFF:
			_fail("map %d: %dx%d is larger than a map plane can be (at most 32767 cells)" % [i, level.width, level.height])
			return {}
		if level.planes.size() != 3:
			_fail("map %d: %d planes, not 3" % [i, level.planes.size()])
			return {}
		var hdr: PackedByteArray = PackedByteArray()
		hdr.resize(HEADER_BYTES)
		for p: int in range(3):
			if level.planes[p].size() != cells:
				_fail("map %d plane %d: %d words, not %d" % [i, p, level.planes[p].size(), cells])
				return {}
			var rlew: PackedInt32Array = PackedInt32Array([cells * 2])
			rlew.append_array(LevelCodec.rlew_compress(level.planes[p], rle_tag))
			var rlew_bytes: PackedByteArray = LevelCodec.words_to_bytes(rlew)
			var body: PackedByteArray
			if dreams:
				body = LevelCodec.huff_compress(rlew_bytes, _codes)
				if body.is_empty():
					_fail("map %d plane %d: the map dictionary cannot pack it" % [i, p])
					return {}
			else:
				body = LevelCodec.carmack_compress(rlew)
			# both length words are 16 bits: the RLEW stream's, and the packed plane's in the header
			if rlew_bytes.size() > 0xFFFF or body.size() + 2 > 0xFFFF:
				_fail("map %d plane %d: packs to %d bytes, more than its 16-bit length can say" % [i, p, body.size() + 2])
				return {}
			hdr.encode_u32(p * 4, gm.size())
			hdr.encode_u16(12 + p * 2, body.size() + 2)
			var length: PackedByteArray = PackedByteArray([0, 0])
			length.encode_u16(0, rlew_bytes.size())
			gm.append_array(length)
			gm.append_array(body)
		hdr.encode_u16(18, level.width)
		hdr.encode_u16(20, level.height)
		var name_field: PackedByteArray = _name_field(level)
		for k: int in range(16):
			hdr[22 + k] = name_field[k]
		head.encode_u32(2 + i * 4, gm.size())
		if dreams:
			var packed: PackedByteArray = LevelCodec.huff_compress(hdr, _codes)
			if packed.is_empty() or packed.size() > 255:
				_fail("map %d: its header packs to %d bytes, more than MAPHEAD's byte can say" % [i, packed.size()])
				return {}
			head[OFFSETS_END + i] = packed.size()
			gm.append_array(packed)
		else:
			gm.append_array(hdr)
		gm.append_array(level.keep.get("after", PackedByteArray() if dreams else MAP_END.to_ascii_buffer()))
	head.append_array(head_tail)
	return {"maphead": head, "gamemaps": gm}


## The 16-byte name: as read while the name is unchanged, else the name and NULs.
static func _name_field(level: KeenLevel) -> PackedByteArray:
	var kept: PackedByteArray = level.keep.get("name_field", PackedByteArray())
	if kept.size() == 16 and ascii_z(kept) == level.name:
		return kept
	var out: PackedByteArray = PackedByteArray()
	out.resize(16)
	var text: PackedByteArray = level.name.to_ascii_buffer()
	for k: int in range(mini(text.size(), 16)):
		out[k] = text[k]
	return out
