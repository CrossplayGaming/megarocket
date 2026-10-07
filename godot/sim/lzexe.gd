# Copyright (C) 2026 the Megarocket contributors; the algorithm follows the
# Sidescroller Recomps project's tools/unlzexe.py (GPL v2 or later). See LICENSE.md.
class_name LzExe
extends RefCounted
## Unpacks a program compressed with LZEXE 0.91 (every Keen executable is),
## giving the load image: everything after the EXE header, as DOS would have
## it in memory. Keen 2 and 3 link their sound image into the program, and
## Keen Dreams its graphics, map and audio headers, so the games' own files
## are read through this at run time. Nothing is written anywhere.

static var error: String = ""


static func _u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func is_lzexe(exe: PackedByteArray) -> bool:
	return exe.size() > 0x20 and exe[0x1C] == 0x4C and exe[0x1D] == 0x5A and exe[0x1E] == 0x39 and exe[0x1F] == 0x31


## The unpacked load image, or an empty array with `error` set.
static func unpack(exe: PackedByteArray) -> PackedByteArray:
	error = ""
	if not is_lzexe(exe):
		error = "not an LZEXE 0.91 program"
		return PackedByteArray()
	var header_paragraphs: int = _u16(exe, 8)
	var cs: int = _u16(exe, 0x16)
	var info_pos: int = (cs + header_paragraphs) << 4
	if info_pos + 16 > exe.size():
		error = "LZEXE info block lies past the end of the file"
		return PackedByteArray()
	var info4: int = _u16(exe, info_pos + 8)
	var pos: int = (cs - info4 + header_paragraphs) << 4
	if pos < 0 or pos + 2 > exe.size():
		error = "LZEXE packed data lies past the end of the file"
		return PackedByteArray()

	var out: PackedByteArray = PackedByteArray()
	var n: int = exe.size()
	var bits: int = _u16(exe, pos)
	pos += 2
	var count: int = 16
	# getbit, written out in place for speed: returns through `bit`
	while true:
		if pos > n:
			error = "LZEXE stream ran past the end of the file"
			return PackedByteArray()
		# ---- bit 1
		var bit: int = bits & 1
		count -= 1
		if count == 0:
			if pos + 2 > n:
				error = "LZEXE stream ran past the end of the file"
				return PackedByteArray()
			bits = _u16(exe, pos)
			pos += 2
			count = 16
		else:
			bits >>= 1
		if bit == 1:
			if pos >= n:
				error = "LZEXE stream ran past the end of the file"
				return PackedByteArray()
			out.append(exe[pos])
			pos += 1
			continue
		# ---- bit 2
		bit = bits & 1
		count -= 1
		if count == 0:
			if pos + 2 > n:
				error = "LZEXE stream ran past the end of the file"
				return PackedByteArray()
			bits = _u16(exe, pos)
			pos += 2
			count = 16
		else:
			bits >>= 1
		var length: int
		var span: int
		if bit == 0:
			# two more bits give the length
			var b2: int = bits & 1
			count -= 1
			if count == 0:
				bits = _u16(exe, pos)
				pos += 2
				count = 16
			else:
				bits >>= 1
			var b3: int = bits & 1
			count -= 1
			if count == 0:
				bits = _u16(exe, pos)
				pos += 2
				count = 16
			else:
				bits >>= 1
			length = (b2 << 1) | b3
			length += 2
			span = exe[pos] - 0x100
			pos += 1
		else:
			span = exe[pos]
			length = exe[pos + 1]
			pos += 2
			span = (span | ((length & 0xF8) << 5) | 0xE000) - 0x10000
			length = (length & 0x07) + 2
			if length == 2:
				length = exe[pos]
				pos += 1
				if length == 0:
					break
				if length == 1:
					continue
				length += 1
		var size: int = out.size()
		if size + span < 0:
			error = "LZEXE back-reference before the start of the image at byte %d" % size
			return PackedByteArray()
		for k: int in range(length):
			out.append(out[out.size() + span])
	return out
