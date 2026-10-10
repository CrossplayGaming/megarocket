# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: K1n9_Duk3's reconstructed Keen 1-3 source (GPL v2): IDLIB.H
# (LevelDef), KEENMAIN.C (ReadLevel), IDLIBC.C (RLEWExpand, RLEWCompress).
class_name VortLevels
extends RefCounted
## Keen 1, 2 and 3 level files (LEVELnn.CKn) to KeenLevel and back.
##
## A level file is one word-RLE stream (tag FEFE) with its expanded length in
## front. Expanded, it is a 32-byte header (LevelDef: width, height, planes,
## screenx, screeny, screenw, screenh, planesize; the other 16 bytes unused)
## and then each plane, `planesize` bytes apart: width x height words, the
## plane size rounded up to 16 bytes. ReadLevel uses only width, height,
## planes and planesize. Expanding reuses the game's own VortData.

const HEADER_BYTES: int = VortData.LEVEL_HEADER_BYTES

var error: String = ""


func _fail(msg: String) -> KeenLevel:
	if error == "":
		error = msg
	return null


## The level in `bytes` (a whole LEVELnn file); null with `error` naming
## `label` on any fault.
func read(bytes: PackedByteArray, label: String, number: int = -1) -> KeenLevel:
	var vd: VortData = VortData.new()
	var data: PackedByteArray = vd.rlew_expand(bytes, label)
	if vd.error != "":
		return _fail(vd.error)
	if data.size() < HEADER_BYTES:
		return _fail("%s: expanded to only %d bytes" % [label, data.size()])
	var level: KeenLevel = KeenLevel.new()
	level.engine = KeenLevel.VORTICONS
	level.number = number
	level.width = VortData.s16(data, 0)
	level.height = VortData.s16(data, 2)
	var count: int = VortData.s16(data, 4)
	var planesize: int = VortData.u16(data, 14)
	level.fields = {"screenx": VortData.s16(data, 6), "screeny": VortData.s16(data, 8),
		"screenw": VortData.s16(data, 10), "screenh": VortData.s16(data, 12)}
	if level.width <= 0 or level.height <= 0 or count < 1 or count > 4:
		return _fail("%s: header says %dx%d with %d planes" % [label, level.width, level.height, count])
	var cells: int = level.width * level.height
	if planesize < cells * 2:
		return _fail("%s: plane size %d is less than %dx%d words" % [label, planesize, level.width, level.height])
	if HEADER_BYTES + planesize * count > data.size():
		return _fail("%s: %d planes of %d bytes do not fit in %d expanded bytes" % [label, count, planesize, data.size()])
	# anything after the last plane would be lost on writing: refuse rather than drop it
	if data.size() != HEADER_BYTES + planesize * count:
		return _fail("%s: %d bytes follow the last plane" % [label, data.size() - HEADER_BYTES - planesize * count])
	var tails: Array = []
	for p: int in range(count):
		var base: int = HEADER_BYTES + p * planesize
		level.planes.append(LevelCodec.bytes_to_words(data, base, cells))
		tails.append(data.slice(base + cells * 2, base + planesize))
	level.keep = {"header": data.slice(0, HEADER_BYTES), "plane_tails": tails}
	return level


## Read LEVELnn.<ext> from `dir` (letter case as found there).
func read_file(dir: String, number: int, ext: String) -> KeenLevel:
	var file: String = ("LEVEL%02d." % number) + ext
	var path: String = dir.path_join(file)
	var d: DirAccess = DirAccess.open(dir)
	if d != null:
		for f: String in d.get_files():
			if f.to_upper() == file.to_upper():
				path = dir.path_join(f)
	if not FileAccess.file_exists(path):
		return _fail("%s: not in %s" % [file, dir])
	return read(FileAccess.get_file_as_bytes(path), file, number)


## The level as a LEVELnn file's bytes; empty with `error` on fault.
func write(level: KeenLevel) -> PackedByteArray:
	if level == null or level.engine != KeenLevel.VORTICONS:
		_fail("not a Keen 1-3 level")
		return PackedByteArray()
	var count: int = level.planes.size()
	var cells: int = level.width * level.height
	if level.width <= 0 or level.height <= 0 or count < 1 or count > 4:
		_fail("level %d: %dx%d with %d planes cannot be written" % [level.number, level.width, level.height, count])
		return PackedByteArray()
	for words: PackedInt32Array in level.planes:
		if words.size() != cells:
			_fail("level %d: a plane holds %d words, not %d" % [level.number, words.size(), cells])
			return PackedByteArray()
	# the plane size the original files use, width x height words rounded up to
	# 16 bytes; a kept header of the same size keeps its own (a file made by
	# another tool may round differently)
	var planesize: int = (cells * 2 + 15) / 16 * 16
	var header: PackedByteArray = level.keep.get("header", PackedByteArray())
	if header.size() == HEADER_BYTES and VortData.s16(header, 0) == level.width and VortData.s16(header, 2) == level.height 			and VortData.u16(header, 14) >= cells * 2:
		planesize = VortData.u16(header, 14)
	if planesize > 0xFFFF:
		_fail("level %d: %dx%d is larger than a Keen 1-3 plane can be (%d bytes, at most 65535)" % [level.number, level.width, level.height, planesize])
		return PackedByteArray()
	var data: PackedByteArray = PackedByteArray()
	data.resize(HEADER_BYTES + planesize * count)
	if header.size() == HEADER_BYTES:
		for i: int in range(HEADER_BYTES):
			data[i] = header[i]
	data.encode_s16(0, level.width)
	data.encode_s16(2, level.height)
	data.encode_s16(4, count)
	data.encode_s16(6, level.fields.get("screenx", 0))
	data.encode_s16(8, level.fields.get("screeny", 0))
	data.encode_s16(10, level.fields.get("screenw", 0))
	data.encode_s16(12, level.fields.get("screenh", 0))
	data.encode_u16(14, planesize)
	var tails: Array = level.keep.get("plane_tails", [])
	for p: int in range(count):
		var base: int = HEADER_BYTES + p * planesize
		var words: PackedInt32Array = level.planes[p]
		for i: int in range(cells):
			data.encode_u16(base + i * 2, words[i] & 0xFFFF)
		if p < tails.size() and (tails[p] as PackedByteArray).size() == planesize - cells * 2:
			var tail: PackedByteArray = tails[p]
			for i: int in range(tail.size()):
				data[base + cells * 2 + i] = tail[i]
	var packed: PackedInt32Array = LevelCodec.rlew_compress(LevelCodec.bytes_to_words(data), VortData.RLETAG)
	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, data.size())
	out.append_array(LevelCodec.words_to_bytes(packed))
	return out
