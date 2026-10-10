# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: omnispeak's id_ca.c (CAL_HuffExpand, CAL_CarmackExpand,
# CAL_RLEWExpand, CAL_SetupGrFile, CAL_GetGrChunkExpLength, CAL_ExpandGrChunk,
# CAL_CacheSprite, CAL_SetupMapFile, CA_CacheMap, CAL_SetupAudioFile,
# CA_CacheAudioChunk), id_ca.h (ca_gfxinfo, ca_audinfo, CA_MapHead,
# CA_MapHeader), id_vh.h (bitmap, sprite and font table entries), id_vl.c
# (VL_UnmaskedToRGB / VL_MaskedToRGBA plane order).
class_name GalData
extends RefCounted
## The Galaxy engine's files (Keen 4, 5 and 6): the player's EGAGRAPH,
## GAMEMAPS and AUDIO plus omnispeak's engine-own metadata (dictionaries,
## headers, chunk indices, actions, strings, tile info), read into plain
## arrays. Nothing here touches the engine or the screen.
##
## Graphics come out as one byte per pixel (EGA colour 0-15); masked kinds
## also get a mask (1 = opaque). Maps come out as three planes of words.

const NUM_MAPS: int = 100
const NUM_PLANES: int = 3
const CARMACK_NEAR: int = 0xA700
const CARMACK_FAR: int = 0xA800
const MAPHEAD_TAG: int = 0xABCD

# Releases whose EGAHEAD, EGADICT and MAPHEAD omnispeak does not ship. They
# are read from the player's own executable instead (LZEXE unpacked), keyed
# by the SHA-256 of the packed file; the offsets are into the load image.
# Everything else (chunk numbering, actions, strings, tile info, audio) is
# the same as v1.4 for these builds, as Megarocket proved by replaying the
# game's own demo through v1.4's tables. Keen 6 v1.0 differs from v1.4 in
# these three tables and in a few strings ("strings": a name, or name:index
# for an array element, to the offset of v1.0's own text in the image; its
# level sessions show them, keen6_level08_a: "Keen hungily enters").
const KNOWN_EXES: Dictionary = {
	"050dadf0c1902fcf9c7288e2a704057bd5ec2159388d3900a0f13ab326b134a3": {
		"name": "Keen 6 v1.0 EGA (KEEN6C.EXE, 104,938 bytes)",
		"image_size": 254768,
		"graph_head": 0x1FB20, "graph_head_len": 5561 * 3,
		"graph_dict": 0x35D12,
		"map_head": 0x23C50,
		"strings": {"ck_str_levelEntryText:8": 0x1DDA0, "ck6_str_getPasscard": 0x311B6,
			"ck6_str_grabbiterHungry": 0x31BB6, "ck_str_godModeOn": 0x2FD57, "ck_str_godModeOff": 0x2FD4A,
			"ck_str_jumpCheatOn": 0x2FD6F, "ck_str_jumpCheatOff": 0x2FD7D},
		# Keen's climb onto a ledge: v1.0 moves him by the states' own velocities (no think in the
		# first three), collides as Keen always does (CK_KeenColFunc, not the special one) and goes
		# from the fourth straight to standing; v1.4 moves him in CK_KeenPullThink1-3 and stands him
		# for 6 tics (keenPull5). Of v1.4's 329 action records these are the only ones v1.0 differs
		# in (words, functions or next, compared record by record). Each: the record's image
		# offset (its eight words are read from there), the action its `next` names, its collide.
		"actions": {"CK_ACT_keenPull1": [0x30A7A, "CK_ACT_keenPull2", "CK_KeenColFunc"],
			"CK_ACT_keenPull2": [0x30A98, "CK_ACT_keenPull3", "CK_KeenColFunc"],
			"CK_ACT_keenPull3": [0x30AB6, "CK_ACT_keenPull4", "CK_KeenColFunc"],
			"CK_ACT_keenPull4": [0x30AD4, "CK_ACT_keenStanding", "CK_KeenColFunc"]},
		# Code that differs from v1.4's, as episode values the port's shared code reads: v1.0's
		# R_Walk (the walkers' draw function, 089B:16EE) steps a walker that met a ledge back by
		# twice its move (`shl ax,1`), where v1.4's (omnispeak's CK_BasicDrawFunc2) steps it back once.
		# v1.0's Keen jump draw (0A2F:1956) looks for a pole hole above Keen's box when his head hits
		# something and passes him up through it; on the single pole tile it also bumps his head.
		"ints": {"CK_WalkLedgeBackoff": 2, "CK_KeenPoleHoleV10": 1},
	},
}

var error: String = ""
var exe_build: String = ""      # names the executable the tables came from, else ""
var _exe_note: String = ""      # what the folder's executables turned out to be
var _exe_graph_head: PackedByteArray = PackedByteArray()
var _exe_graph_dict: PackedByteArray = PackedByteArray()
var _exe_map_head: PackedByteArray = PackedByteArray()
var _exe_strings: Dictionary = {}    # the build's own strings, by STRINGS name (KNOWN_EXES "strings")
var _exe_actions: Dictionary = {}    # action name -> its eight words, think kept or not, next (KNOWN_EXES "actions")
var _exe_ints: Dictionary = {}    # episode values for the build's own code (KNOWN_EXES "ints")
## The build's own behaviour (its action records and code values) applies when true. Off: every
## Keen 6 plays by v1.4's rules, as omnispeak has them (J-19, decided 2026-10-09: v1.4 always); the
## v1.0 differences found stay here, documented, for a later choice. Set before load_game.
var exe_behaviour: bool = false
var dir: String = ""            # the player's game folder
var meta_dir: String = ""       # omnispeak's data folder for this episode
var ext: String = ""            # "CK4" ...

var episode: VarFile            # EPISODE.CKx
var chunk_names: VarFile        # GFXCHUNK.CKx: names -> chunk numbers
var strings: VarFile            # STRINGS.CKx
var actions: VarFile            # ACTION.CKx

# gfxinfo (ca_gfxinfo)
var gfx: Dictionary = {}
# audinfo (ca_audinfo)
var aud: Dictionary = {}

var _gr_dict: PackedInt32Array = PackedInt32Array()     # 256 nodes x (bit0, bit1)
var _gr_starts: PackedByteArray = PackedByteArray()      # 3 bytes per chunk
var _gr_file: PackedByteArray = PackedByteArray()        # EGAGRAPH, whole
var _au_dict: PackedInt32Array = PackedInt32Array()
var _au_starts: PackedByteArray = PackedByteArray()      # int32 per chunk
var _au_file: PackedByteArray = PackedByteArray()
var _map_head: PackedByteArray = PackedByteArray()
var _maps_file: PackedByteArray = PackedByteArray()
var rle_tag: int = 0

var num_chunks: int = 0
var bitmap_table: Array[Dictionary] = []      # {w (bytes), h}
var masked_table: Array[Dictionary] = []
var sprite_table: Array[Dictionary] = []      # {w (bytes), h, orgx, orgy, xl, yl, xh, yh, shifts}
var tileinfo: PackedByteArray = PackedByteArray()
var map_names: PackedStringArray = PackedStringArray()   # "" where no map


# ------------------------------------------------------------------ bytes

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


func _read(path: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("%s: cannot open (%s)" % [path.get_file(), error_string(FileAccess.get_open_error())])
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return data


## The player's file, found regardless of letter case (Steam ships Egagraph.ck4).
func _game_path(name: String) -> String:
	var d: DirAccess = DirAccess.open(dir)
	if d != null:
		for f: String in d.get_files():
			if f.to_upper() == name.to_upper():
				return dir.path_join(f)
	return dir.path_join(name)


# ------------------------------------------------------------- decoders

## Huffman as CAL_HuffExpand: the dictionary is 256 nodes of (bit0, bit1)
## 16-bit links; values below 256 are bytes, above are nodes minus 256; the
## root is node 254.
func huff_expand(src: PackedByteArray, src_off: int, src_len: int, exp_len: int, dict: PackedInt32Array, name: String) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(exp_len)
	var head: int = 254
	var p: int = src_off
	var end: int = src_off + src_len
	if p >= end or end > src.size():
		_fail("%s: Huffman data of %d bytes at %d lies past the end" % [name, src_len, src_off])
		return PackedByteArray()
	var src_char: int = src[p]
	p += 1
	var src_bit: int = 1
	var n: int = 0
	while n < exp_len:
		if (src_char & src_bit) != 0:
			head = dict[head * 2 + 1]
		else:
			head = dict[head * 2]
		if head > 255:
			head -= 256
		else:
			out[n] = head & 0xFF
			n += 1
			head = 254
			if n == exp_len:
				break
		src_bit <<= 1
		if src_bit == 256:
			if p >= end:
				# omnispeak stops here too (complen > srcLength); what is
				# left of `out` stays zero, as in the original's buffer
				break
			src_char = src[p]
			p += 1
			src_bit = 1
	return out


## Carmack as CAL_CarmackExpand (words; near and far back-references).
func carmack_expand(src: PackedByteArray, src_off: int, exp_bytes: int, name: String) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(exp_bytes)
	var words: int = exp_bytes / 2
	var o: int = 0
	var p: int = src_off
	var n: int = src.size()
	while o < words:
		if p + 2 > n:
			_fail("%s: Carmack data ends early (%d of %d words)" % [name, o, words])
			return PackedByteArray()
		var ch: int = u16(src, p)
		p += 2
		var tag: int = ch & 0xFF00
		if tag == CARMACK_NEAR or tag == CARMACK_FAR:
			var count: int = ch & 0xFF
			if count == 0:
				if p >= n:
					_fail("%s: Carmack escape cut short" % name)
					return PackedByteArray()
				ch = tag | src[p]
				p += 1
				out[o * 2] = ch & 0xFF
				out[o * 2 + 1] = ch >> 8
				o += 1
			else:
				var run: int
				if tag == CARMACK_NEAR:
					if p >= n:
						_fail("%s: Carmack near offset cut short" % name)
						return PackedByteArray()
					run = o - src[p]
					p += 1
				else:
					if p + 2 > n:
						_fail("%s: Carmack far offset cut short" % name)
						return PackedByteArray()
					run = u16(src, p)
					p += 2
				if run < 0 or o + count > words:
					_fail("%s: Carmack back-reference out of range at word %d" % [name, o])
					return PackedByteArray()
				for k: int in range(count):
					out[o * 2] = out[run * 2]
					out[o * 2 + 1] = out[run * 2 + 1]
					o += 1
					run += 1
		else:
			out[o * 2] = ch & 0xFF
			out[o * 2 + 1] = ch >> 8
			o += 1
	return out


## RLEW as CAL_RLEWExpand (no length prefix; the caller knows the size).
func rlew_expand(src: PackedByteArray, src_off: int, exp_bytes: int, tag: int, name: String) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(exp_bytes)
	var o: int = 0
	var p: int = src_off
	var n: int = src.size()
	while o < exp_bytes:
		if p + 2 > n:
			_fail("%s: RLEW data ends early (%d of %d bytes)" % [name, o, exp_bytes])
			return PackedByteArray()
		var value: int = u16(src, p)
		p += 2
		if value != tag:
			out[o] = value & 0xFF
			out[o + 1] = value >> 8
			o += 2
		else:
			if p + 4 > n:
				_fail("%s: RLEW run cut short" % name)
				return PackedByteArray()
			var count: int = u16(src, p)
			value = u16(src, p + 2)
			p += 4
			if o + count * 2 > exp_bytes:
				_fail("%s: RLEW run of %d words overflows at byte %d" % [name, count, o])
				return PackedByteArray()
			for k: int in range(count):
				out[o] = value & 0xFF
				out[o + 1] = value >> 8
				o += 2
	return out


## Planar EGA data (planes B, G, R, I back to back, each wbytes*h) to one byte per pixel.
static func unplane(src: PackedByteArray, base: int, wbytes: int, h: int) -> PackedByteArray:
	var stride: int = wbytes * h
	var out: PackedByteArray = PackedByteArray()
	out.resize(wbytes * 8 * h)
	for i: int in range(stride):
		var b0: int = src[base + i]
		var b1: int = src[base + stride + i]
		var b2: int = src[base + stride * 2 + i]
		var b3: int = src[base + stride * 3 + i]
		for bit: int in range(8):
			var m: int = 0x80 >> bit
			out[i * 8 + bit] = int((b0 & m) != 0) | (int((b1 & m) != 0) << 1) | (int((b2 & m) != 0) << 2) | (int((b3 & m) != 0) << 3)
	return out


## Masked planar data (mask plane first, then B, G, R, I): {pixels, mask}.
static func unplane_masked(src: PackedByteArray, base: int, wbytes: int, h: int) -> Dictionary:
	var stride: int = wbytes * h
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(wbytes * 8 * h)
	for i: int in range(stride):
		var mb: int = src[base + i]
		for bit: int in range(8):
			mask[i * 8 + bit] = int((mb & (0x80 >> bit)) != 0)
	return {"pixels": unplane(src, base + stride, wbytes, h), "mask": mask}


# --------------------------------------------------------------- loading

func _load_vars(name: String) -> VarFile:
	var v: VarFile = VarFile.new()
	if not v.load(meta_dir.path_join(name)):
		_fail(v.error)
		return null
	return v


## `game_dir` holds the player's files; `meta` is omnispeak's data folder
## for this episode (keen4, keen5, keen6e14, keen6e15).
func load_game(game_dir: String, meta: String) -> bool:
	dir = game_dir
	meta_dir = meta
	error = ""
	ext = "CK" + meta.get_file().substr(4, 1)
	episode = _load_vars("EPISODE." + ext)
	if episode == null:
		return false
	chunk_names = _load_vars(episode.get_string("ca_gfxInfoFile", "GFXINFOE." + ext).get_basename().replace("GFXINFOE", "GFXCHUNK") + "." + ext)
	if chunk_names == null:
		return false
	strings = _load_vars("STRINGS." + ext)
	if strings == null:
		return false
	actions = _load_vars("ACTION." + ext)
	if actions == null:
		return false
	_find_exe_tables()
	# (the game reads its strings through EPISODE, which includes STRINGS)
	for vars: VarFile in [strings, episode]:
		for key: String in _exe_strings:
			var parts: PackedStringArray = key.split(":")
			if parts.size() == 2:
				var arr: PackedStringArray = vars.string_arrays.get(parts[0], PackedStringArray())
				if int(parts[1]) < arr.size():
					arr[int(parts[1])] = _exe_strings[key]
					vars.string_arrays[parts[0]] = arr    # (a packed array is a copy)
			elif vars.strings.has(key):
				vars.strings[key] = _exe_strings[key]
	for key: String in (_exe_ints if exe_behaviour else {}):
		episode.ints[key] = _exe_ints[key]
	# the build's own action records: tokens 1..8 the words, 9 the think (NULL where it has none), 12 next
	for key: String in (_exe_actions if exe_behaviour else {}):
		var fields: Variant = episode.actions.get(key)
		if typeof(fields) != TYPE_ARRAY or (fields as Array).size() < 13:
			continue
		var a: Dictionary = _exe_actions[key]
		var f: Array = (fields as Array).duplicate()
		for w: int in range(8):
			f[1 + w] = ["UnscaledOnce", "ScaledOnce", "Frame", "UnscaledFrame", "ScaledFrame"][a.words[w]] 				if w == 2 and a.words[w] >= 0 and a.words[w] <= 4 else str(a.words[w])
		if not a.think:
			f[9] = "NULL"
		f[10] = a.collide
		f[12] = a.next
		episode.actions[key] = f
	if not _setup_graphics():
		return false
	if not _setup_maps():
		return false
	if not _setup_audio():
		return false
	return error == ""


## Every KEENn*.EXE beside the data is hashed. A build in KNOWN_EXES is
## unpacked and its three tables (and its own strings) taken; anything else is only noted, for
## the message given when the data then fails to match omnispeak's headers.
## Never fails the load by itself.
func _find_exe_tables() -> void:
	exe_build = ""
	_exe_note = ""
	_exe_graph_head = PackedByteArray()
	_exe_graph_dict = PackedByteArray()
	_exe_map_head = PackedByteArray()
	_exe_strings = {}
	_exe_actions = {}
	_exe_ints = {}
	var digit: String = ext.substr(2, 1)
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	var notes: PackedStringArray = PackedStringArray()
	for f: String in d.get_files():
		var up: String = f.to_upper()
		if not (up.begins_with("KEEN" + digit) and up.ends_with(".EXE")):
			continue
		var exe: PackedByteArray = FileAccess.get_file_as_bytes(dir.path_join(f))
		var h: HashingContext = HashingContext.new()
		h.start(HashingContext.HASH_SHA256)
		h.update(exe)
		var k: Dictionary = KNOWN_EXES.get(h.finish().hex_encode(), {})
		if k.is_empty():
			notes.append("%s (%d bytes) is not a build whose tables this program reads" % [f, exe.size()])
			continue
		var img: PackedByteArray = LzExe.unpack(exe)
		if img.size() != k.image_size:
			notes.append("%s unpacked to %d bytes, not the %d of %s (%s)" % [f, img.size(), k.image_size, k.name, LzExe.error])
			continue
		_exe_graph_head = img.slice(k.graph_head, k.graph_head + k.graph_head_len)
		_exe_graph_dict = img.slice(k.graph_dict, k.graph_dict + 1024)
		_exe_map_head = img.slice(k.map_head, k.map_head + 2 + NUM_MAPS * 4)
		for key: String in k.get("strings", {}):
			var at: int = k.strings[key]
			var end: int = at
			while end < img.size() and img[end] != 0:
				end += 1
			_exe_strings[key] = img.slice(at, end).get_string_from_ascii()
		_exe_ints = k.get("ints", {}).duplicate()
		for key: String in k.get("actions", {}):
			var at: int = k.actions[key][0]
			var words: Array = []
			for w: int in range(8):
				var v: int = img.decode_u16(at + w * 2)
				words.append(v - 0x10000 if v >= 0x8000 else v)
			_exe_actions[key] = {"words": words, "think": img.decode_u32(at + 16) != 0, "next": k.actions[key][1],
				"collide": k.actions[key][2]}
		exe_build = "%s = %s" % [f, k.name]
		_exe_note = exe_build
		return
	if notes.is_empty():
		notes.append("no KEEN%s*.EXE beside the data" % digit)
	_exe_note = "; ".join(notes)


func _dict_from(raw: PackedByteArray, label: String) -> PackedInt32Array:
	if raw.size() < 1024:
		_fail("%s: a Huffman dictionary is 1024 bytes, this is %d" % [label, raw.size()])
		return PackedInt32Array()
	var d: PackedInt32Array = PackedInt32Array()
	d.resize(512)
	for i: int in range(512):
		d[i] = u16(raw, i * 2)
	return d


func _load_dict(path: String) -> PackedInt32Array:
	return _dict_from(_read(path), path.get_file())


func _setup_graphics() -> bool:
	var headers: String = meta_dir.get_file()
	if exe_build != "":
		headers = exe_build
		_gr_dict = _dict_from(_exe_graph_dict, exe_build)
		_gr_starts = _exe_graph_head
	else:
		_gr_dict = _load_dict(meta_dir.path_join(episode.get_string("ca_graphDict")))
		if _gr_dict.is_empty():
			return false
		_gr_starts = _read(meta_dir.path_join(episode.get_string("ca_graphHead")))
		if _gr_starts.is_empty():
			return false
	num_chunks = _gr_starts.size() / 3
	var info: PackedByteArray = _read(meta_dir.path_join(episode.get_string("ca_gfxInfoFile")))
	if info.size() < 46:
		return _fail("%s: GFXINFOE is %d bytes, want 46" % [episode.get_string("ca_gfxInfoFile"), info.size()])
	var keys: Array = ["numTiles8", "numTiles8m", "numTiles16", "numTiles16m", "numTiles32", "numTiles32m",
		"offTiles8", "offTiles8m", "offTiles16", "offTiles16m", "offTiles32", "offTiles32m",
		"numBitmaps", "numMasked", "numSprites", "offBitmaps", "offMasked", "offSprites",
		"hdrBitmaps", "hdrMasked", "hdrSprites", "numBinaries", "offBinaries"]
	for i: int in range(keys.size()):
		gfx[keys[i]] = u16(info, i * 2)
	_gr_file = _read(_game_path(episode.get_string("ca_graphFile")))
	if _gr_file.is_empty():
		return false
	# The headers describe one exact release of the file. Before anything is
	# expanded (a wrong header makes expansion grind on garbage for minutes):
	# the last chunk must lie inside the file, and the bitmaps must carry
	# sane lengths. The user's Keen 6 v1.0 failed this against the v1.4 data.
	var last: int = 0
	for c: int in range(num_chunks):
		var st: int = chunk_start(c)
		if st > last:
			last = st
	var sane: int = 0
	for c: int in range(gfx.offBitmaps, gfx.offBitmaps + gfx.numBitmaps):
		var st: int = chunk_start(c)
		if st >= 0 and st + 4 <= _gr_file.size():
			var exp_len: int = u32(_gr_file, st)
			if exp_len > 0 and exp_len < 65536:
				sane += 1
	if exe_build != "" and chunk_start(num_chunks - 1) != _gr_file.size():
		return _fail("%s: the graphics table in %s ends at %d but the file is %d bytes -- data from another version" %
			[episode.get_string("ca_graphFile"), exe_build, chunk_start(num_chunks - 1), _gr_file.size()])
	if last > _gr_file.size() or sane < gfx.numBitmaps / 2:
		var remedy: String = ""
		if ext == "CK6" and exe_build == "":
			remedy = " (a Keen 6 v1.0 needs its own KEEN6C.EXE beside the data: %s)" % _exe_note
		return _fail("%s: does not match the %s headers (chunks reach %d in a %d-byte file, %d of %d bitmaps sane) -- another version of the game%s" %
			[episode.get_string("ca_graphFile"), headers, last, _gr_file.size(), sane, gfx.numBitmaps, remedy])
	# the three header tables are chunks of their own
	var bt: PackedByteArray = chunk(gfx.hdrBitmaps)
	var mt: PackedByteArray = chunk(gfx.hdrMasked)
	var st: PackedByteArray = chunk(gfx.hdrSprites)
	if error != "":
		return false
	if bt.size() < gfx.numBitmaps * 4 or mt.size() < gfx.numMasked * 4 or st.size() < gfx.numSprites * 18:
		return _fail("%s: a graphics table is shorter than its count (bitmaps %d/%d, masked %d/%d, sprites %d/%d bytes)" %
			[episode.get_string("ca_graphFile"), bt.size(), gfx.numBitmaps * 4, mt.size(), gfx.numMasked * 4, st.size(), gfx.numSprites * 18])
	bitmap_table = []
	for i: int in range(gfx.numBitmaps):
		bitmap_table.append({"w": u16(bt, i * 4), "h": u16(bt, i * 4 + 2)})
	masked_table = []
	for i: int in range(gfx.numMasked):
		masked_table.append({"w": u16(mt, i * 4), "h": u16(mt, i * 4 + 2)})
	sprite_table = []
	for i: int in range(gfx.numSprites):
		var e: int = i * 18
		sprite_table.append({"w": u16(st, e), "h": u16(st, e + 2), "orgx": s16(st, e + 4), "orgy": s16(st, e + 6),
			"xl": s16(st, e + 8), "yl": s16(st, e + 10), "xh": s16(st, e + 12), "yh": s16(st, e + 14), "shifts": u16(st, e + 16)})
	return true


func chunk_start(c: int) -> int:
	if c < 0 or c * 3 + 2 >= _gr_starts.size():
		return -1
	var v: int = _gr_starts[c * 3] | (_gr_starts[c * 3 + 1] << 8) | (_gr_starts[c * 3 + 2] << 16)
	return -1 if v == 0xFFFFFF else v


func chunk_comp_length(c: int) -> int:
	var next: int = c + 1
	var size_offset: int = 4 if (c < gfx.offTiles8 and c >= gfx.offBinaries) else 0
	if next * 3 >= _gr_starts.size():
		return _gr_file.size() - chunk_start(c) - size_offset
	while chunk_start(next) == -1 and next * 3 < _gr_starts.size():
		next += 1
	if next * 3 >= _gr_starts.size():
		return _gr_file.size() - chunk_start(c) - size_offset
	return chunk_start(next) - chunk_start(c) - size_offset


## The expanded length a tile chunk has by its kind, or 0 for chunks that carry their own.
func chunk_exp_length(c: int) -> int:
	if c >= gfx.offTiles8 and c < gfx.offBinaries:
		if c < gfx.offTiles8m:
			return 32 * gfx.numTiles8
		if c < gfx.offTiles16:
			return 40 * gfx.numTiles8m
		if c < gfx.offTiles16m:
			return 128
		if c < gfx.offTiles32:
			return 160
		if c < gfx.offTiles32m:
			return 512
		return 640
	return 0


## One graphics chunk, expanded (sprites: the unshifted five planes). Empty
## with `error` set on fault; empty with no error for an absent chunk.
func chunk(c: int) -> PackedByteArray:
	var start: int = chunk_start(c)
	if start == -1:
		return PackedByteArray()
	var comp: int = chunk_comp_length(c)
	var length: int = chunk_exp_length(c)
	var src: int = start
	if length == 0:
		if start + 4 > _gr_file.size():
			_fail("EGAGRAPH: chunk %d's length lies past the end of the file" % c)
			return PackedByteArray()
		length = u32(_gr_file, start)
		src += 4
		comp -= 4
	if length < 0 or length > 0x100000:
		_fail("EGAGRAPH: chunk %d claims %d bytes; not a compatible version" % [c, length])
		return PackedByteArray()
	if c >= gfx.offSprites and c < gfx.offSprites + gfx.numSprites:
		var s: Dictionary = sprite_table[c - gfx.offSprites]
		length = s.w * s.h * 5
	return huff_expand(_gr_file, src, comp, length, _gr_dict, "EGAGRAPH chunk %d" % c)


## A bitmap by index: {w, h, pixels}.
func bitmap(i: int) -> Dictionary:
	var t: Dictionary = bitmap_table[i]
	var data: PackedByteArray = chunk(gfx.offBitmaps + i)
	if data.size() < t.w * t.h * 4:
		_fail("EGAGRAPH: bitmap %d is %d bytes, needs %d" % [i, data.size(), t.w * t.h * 4])
		return {}
	return {"w": t.w * 8, "h": t.h, "pixels": unplane(data, 0, t.w, t.h)}


func masked_bitmap(i: int) -> Dictionary:
	var t: Dictionary = masked_table[i]
	var data: PackedByteArray = chunk(gfx.offMasked + i)
	if data.size() < t.w * t.h * 5:
		_fail("EGAGRAPH: masked bitmap %d is %d bytes, needs %d" % [i, data.size(), t.w * t.h * 5])
		return {}
	var m: Dictionary = unplane_masked(data, 0, t.w, t.h)
	return {"w": t.w * 8, "h": t.h, "pixels": m.pixels, "mask": m.mask}


func sprite(i: int) -> Dictionary:
	var t: Dictionary = sprite_table[i]
	var data: PackedByteArray = chunk(gfx.offSprites + i)
	if data.size() < t.w * t.h * 5:
		_fail("EGAGRAPH: sprite %d is %d bytes, needs %d" % [i, data.size(), t.w * t.h * 5])
		return {}
	var m: Dictionary = unplane_masked(data, 0, t.w, t.h)
	return {"w": t.w * 8, "h": t.h, "pixels": m.pixels, "mask": m.mask, "orgx": t.orgx, "orgy": t.orgy,
		"xl": t.xl, "yl": t.yl, "xh": t.xh, "yh": t.yh, "shifts": t.shifts}


## 16x16 tiles: all of them, 256 pixels each, in index order.
func tiles16() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(gfx.numTiles16 * 256)
	for i: int in range(gfx.numTiles16):
		var data: PackedByteArray = chunk(gfx.offTiles16 + i)
		if data.is_empty():
			continue        # a sparse tile: stays colour 0
		var px: PackedByteArray = unplane(data, 0, 2, 16)
		for k: int in range(256):
			out[i * 256 + k] = px[k]
	return out


## 16x16 masked tiles: {pixels, mask} for all, 256 each.
func tiles16m() -> Dictionary:
	var px_all: PackedByteArray = PackedByteArray()
	var mk_all: PackedByteArray = PackedByteArray()
	px_all.resize(gfx.numTiles16m * 256)
	mk_all.resize(gfx.numTiles16m * 256)
	for i: int in range(gfx.numTiles16m):
		var data: PackedByteArray = chunk(gfx.offTiles16m + i)
		if data.is_empty():
			continue
		var m: Dictionary = unplane_masked(data, 0, 2, 16)
		for k: int in range(256):
			px_all[i * 256 + k] = m.pixels[k]
			mk_all[i * 256 + k] = m.mask[k]
	return {"pixels": px_all, "mask": mk_all}


## 8x8 tiles live in ONE chunk each (all unmasked, then all masked).
func tiles8() -> PackedByteArray:
	var data: PackedByteArray = chunk(gfx.offTiles8)
	var out: PackedByteArray = PackedByteArray()
	out.resize(gfx.numTiles8 * 64)
	for i: int in range(gfx.numTiles8):
		var px: PackedByteArray = unplane(data, i * 32, 1, 8)
		for k: int in range(64):
			out[i * 64 + k] = px[k]
	return out


## A font chunk: {height, widths[256], glyphs: Array of PackedByteArray (1 byte per pixel, 0/1)}.
func font(c: int) -> Dictionary:
	var data: PackedByteArray = chunk(c)
	if data.size() < 2 + 512 + 256:
		_fail("EGAGRAPH: chunk %d is not a font" % c)
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


func _setup_maps() -> bool:
	var label: String = episode.get_string("ca_mapHead")
	if exe_build != "":
		label = "the map table in " + exe_build
		_map_head = _exe_map_head
	else:
		_map_head = _read(meta_dir.path_join(label))
	if _map_head.size() < 2 + NUM_MAPS * 4:
		return _fail("%s: MAPHEAD is %d bytes, want %d" % [label, _map_head.size(), 2 + NUM_MAPS * 4])
	rle_tag = u16(_map_head, 0)
	if rle_tag != MAPHEAD_TAG:
		return _fail("%s: the RLEW tag is %04x, not %04x" % [label, rle_tag, MAPHEAD_TAG])
	_maps_file = _read(_game_path(episode.get_string("ca_mapFile")))
	if _maps_file.is_empty():
		return false
	tileinfo = _read(meta_dir.path_join(episode.get_string("ca_tileInfo")))
	if tileinfo.is_empty():
		return false
	return _scan_map_names()


## MAKER-01: a set of maps from the maker (TedMaps.write: a MAPHEAD and its GAMEMAPS) in place of the
## game's, for every map loaded from now on (a level played in place). False with `error` on fault.
func use_maps(maphead: PackedByteArray, gamemaps: PackedByteArray) -> bool:
	if maphead.size() < 2 + NUM_MAPS * 4 or u16(maphead, 0) != MAPHEAD_TAG:
		return _fail("the maker's MAPHEAD is not a map table (%d bytes)" % maphead.size())
	_map_head = maphead
	_maps_file = gamemaps
	rle_tag = MAPHEAD_TAG
	return _scan_map_names()


func _scan_map_names() -> bool:
	map_names = PackedStringArray()
	map_names.resize(NUM_MAPS)
	for i: int in range(NUM_MAPS):
		var off: int = u32(_map_head, 2 + i * 4)
		if off == 0xFFFFFFFF or off == 0:
			map_names[i] = ""
		elif off + 38 > _maps_file.size():
			return _fail("%s: map %d's header at %d lies past the end of the %d-byte file -- another version of the game" %
				[episode.get_string("ca_mapFile"), i, off, _maps_file.size()])
		else:
			map_names[i] = _maps_file.slice(off + 22, off + 38).get_string_from_ascii().strip_edges()
	return true


## Whether MAPHEAD points at a map this GAMEMAPS holds.
func has_map(i: int) -> bool:
	if i < 0 or i >= NUM_MAPS:
		return false
	var off: int = u32(_map_head, 2 + i * 4)
	return off != 0xFFFFFFFF and off != 0 and off + 38 <= _maps_file.size()


## One map: {width, height, name, plane: [3 PackedInt32Array]}. Empty with `error` on fault.
func load_map(i: int) -> Dictionary:
	var name: String = episode.get_string("ca_mapFile")
	var off: int = u32(_map_head, 2 + i * 4)
	if off == 0xFFFFFFFF or off == 0 or off + 38 > _maps_file.size():
		_fail("%s: map %d does not exist" % [name, i])
		return {}
	# CA_MapHeader: planeOffsets[3] (12), planeLengths[3] (6), width, height, name[16], signature[4]
	var width: int = u16(_maps_file, off + 18)
	var height: int = u16(_maps_file, off + 20)
	if width <= 0 or height <= 0 or width > 512 or height > 512:
		_fail("%s: map %d is %dx%d" % [name, i, width, height])
		return {}
	var plane_bytes: int = width * height * 2
	var planes: Array = []
	for p: int in range(NUM_PLANES):
		var poff: int = u32(_maps_file, off + p * 4)
		var plen: int = u16(_maps_file, off + 12 + p * 2)
		if poff + plen > _maps_file.size() or plen < 2:
			_fail("%s: map %d plane %d (%d bytes at %d) lies past the end" % [name, i, p, plen, poff])
			return {}
		var carmack_len: int = u16(_maps_file, poff)
		var rlew: PackedByteArray = carmack_expand(_maps_file, poff + 2, carmack_len, "%s map %d plane %d" % [name, i, p])
		if rlew.is_empty():
			return {}
		# the RLEW stream carries its own expanded length word first
		var data: PackedByteArray = rlew_expand(rlew, 2, plane_bytes, rle_tag, "%s map %d plane %d" % [name, i, p])
		if data.is_empty():
			return {}
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(width * height)
		for k: int in range(width * height):
			words[k] = u16(data, k * 2)
		planes.append(words)
	return {"width": width, "height": height, "name": map_names[i], "plane": planes}


func _setup_audio() -> bool:
	var info: PackedByteArray = _read(meta_dir.path_join(episode.get_string("ca_audioInfoFile")))
	if info.size() < 14:
		return _fail("AUDINFOE is %d bytes, want 14" % info.size())
	var keys: Array = ["numSongs", "numSounds", "numSndChunks", "startPCSounds", "startAdlibSounds", "startDigiSounds", "startMusic"]
	for i: int in range(keys.size()):
		aud[keys[i]] = u16(info, i * 2)
	if episode.get_int("ca_audioUncompressed", 0) != 0:
		return _fail("uncompressed AUDIOT data is not supported")
	_au_dict = _load_dict(meta_dir.path_join(episode.get_string("ca_audioDict")))
	if _au_dict.is_empty():
		return false
	_au_starts = _read(meta_dir.path_join(episode.get_string("ca_audioHead")))
	if _au_starts.is_empty():
		return false
	_au_file = _read(_game_path(episode.get_string("ca_audioFile")))
	return not _au_file.is_empty()


func num_audio_chunks() -> int:
	return _au_starts.size() / 4 - 1


## A map's planes as the original reads them: [bytes in the file, Carmack-expanded bytes] for each.
func map_plane_sizes(i: int) -> Array:
	var out: Array = []
	if i < 0 or 2 + i * 4 + 4 > _map_head.size():
		return out
	var off: int = u32(_map_head, 2 + i * 4)
	if off <= 0 or off + 22 > _maps_file.size():
		return out
	for p: int in range(3):
		var poff: int = u32(_maps_file, off + p * 4)
		var plen: int = u16(_maps_file, off + 12 + p * 2)
		out.append([plen, u16(_maps_file, poff) if poff + 2 <= _maps_file.size() else 0])
	return out


## The bytes an audio chunk takes in the file (the original reads them into its buffer).
func audio_comp_length(c: int) -> int:
	if c < 0 or (c + 1) * 4 + 4 > _au_starts.size():
		return 0
	return u32(_au_starts, (c + 1) * 4) - u32(_au_starts, c * 4)


## One audio chunk (PC speaker, AdLib effect or IMF song), expanded.
func audio_chunk(c: int) -> PackedByteArray:
	if c < 0 or (c + 1) * 4 + 4 > _au_starts.size():
		_fail("AUDIO: no chunk %d" % c)
		return PackedByteArray()
	var pos: int = u32(_au_starts, c * 4)
	var comp: int = u32(_au_starts, (c + 1) * 4) - pos
	if comp <= 4:
		return PackedByteArray()          # an empty slot
	if pos + comp > _au_file.size():
		_fail("AUDIO: chunk %d (%d bytes at %d) lies past the end" % [c, comp, pos])
		return PackedByteArray()
	var expanded: int = u32(_au_file, pos)
	if expanded < 0 or expanded > 0x100000:
		_fail("AUDIO: chunk %d claims %d bytes" % [c, expanded])
		return PackedByteArray()
	return huff_expand(_au_file, pos + 4, comp - 4, expanded, _au_dict, "AUDIO chunk %d" % c)
