# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of soft.c (LoadLIBFile, LoadLIBShape) and lzhuf.c (lzhDecompress
# and its adaptive Huffman tree) from id Software's Keen Dreams source as
# carried in ReflectionHLE, GPL v2 or later. The LZHUF algorithm is Haruyasu
# Yoshizaki's, as id's file says.
class_name SoftLib
extends RefCounted
## Keen Dreams v1.93's KDREAMS.CMP: a SoftLib archive (header "SLIB",
## version, file count, a directory of 30-byte entries, then "CUNK" chunks)
## whose title picture is an IFF ILBM compressed with LZH (N 4096, F 30,
## threshold 2). The decoder keeps the original's 16-bit arithmetic.

const ID_SLIB: int = 0x42494C53         # "SLIB" read little-endian
const ID_CHUNK: int = 0x4B4E5543        # "CUNK"
const SOFTLIB_VER: int = 2
const CT_NONE: int = 0
const CT_LZW: int = 1
const CT_LZH: int = 2

const N: int = 4096
const F: int = 30
const THRESHOLD: int = 2
const N_CHAR: int = 256 - THRESHOLD + F
const T: int = N_CHAR * 2 - 1
const R: int = T - 1
const MAX_FREQ: int = 0x8000

const D_CODE: PackedByteArray = [
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
	0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
	0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
	0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
	0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09,
	0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
	0x0C, 0x0C, 0x0C, 0x0C, 0x0D, 0x0D, 0x0D, 0x0D, 0x0E, 0x0E, 0x0E, 0x0E, 0x0F, 0x0F, 0x0F, 0x0F,
	0x10, 0x10, 0x10, 0x10, 0x11, 0x11, 0x11, 0x11, 0x12, 0x12, 0x12, 0x12, 0x13, 0x13, 0x13, 0x13,
	0x14, 0x14, 0x14, 0x14, 0x15, 0x15, 0x15, 0x15, 0x16, 0x16, 0x16, 0x16, 0x17, 0x17, 0x17, 0x17,
	0x18, 0x18, 0x19, 0x19, 0x1A, 0x1A, 0x1B, 0x1B, 0x1C, 0x1C, 0x1D, 0x1D, 0x1E, 0x1E, 0x1F, 0x1F,
	0x20, 0x20, 0x21, 0x21, 0x22, 0x22, 0x23, 0x23, 0x24, 0x24, 0x25, 0x25, 0x26, 0x26, 0x27, 0x27,
	0x28, 0x28, 0x29, 0x29, 0x2A, 0x2A, 0x2B, 0x2B, 0x2C, 0x2C, 0x2D, 0x2D, 0x2E, 0x2E, 0x2F, 0x2F,
	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
]
const D_LEN: PackedByteArray = [
	0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
	0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
	0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
	0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
	0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
	0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
	0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
	0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
	0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
	0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
	0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
	0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
	0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
]

static var error: String = ""

# the decoder's state (one decode at a time, as in the original)
static var _freq: PackedInt32Array
static var _son: PackedInt32Array
static var _prnt: PackedInt32Array
static var _getbuf: int = 0
static var _getlen: int = 0
static var _src: PackedByteArray
static var _pos: int = 0
static var _left: int = 0


static func _u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func _u32(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


static func _be32(b: PackedByteArray, o: int) -> int:
	return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]


static func _be16(b: PackedByteArray, o: int) -> int:
	return (b[o] << 8) | b[o + 1]


## LoadLIBFile: one file of the archive, expanded; empty (and `error` set) if
## it is not there or the archive is damaged.
static func load_lib_file(lib: PackedByteArray, file_name: String) -> PackedByteArray:
	error = ""
	if lib.size() < 8 or _u32(lib, 0) != ID_SLIB:
		error = "not a SoftLib archive"
		return PackedByteArray()
	var version: int = _u16(lib, 4)
	var count: int = _u16(lib, 6)
	if version > SOFTLIB_VER:
		error = "unsupported SoftLib version %d" % version
		return PackedByteArray()
	var pos: int = 8
	var entry: Dictionary = {}
	for i: int in range(count):
		if pos + 30 > lib.size():
			error = "the directory runs past the end of the archive"
			return PackedByteArray()
		var name: String = ""
		for k: int in range(16):
			var c: int = lib[pos + k]
			if c == 0:
				break
			name += char(c)
		if name.to_upper() == file_name.to_upper():
			entry = {"offset": _u32(lib, pos + 16), "chunk_len": _u32(lib, pos + 20), "orig_len": _u32(lib, pos + 24)}
		pos += 30
	if entry.is_empty():
		error = "%s is not in the archive" % file_name
		return PackedByteArray()
	# the offset counts from the end of the directory (the original seeks from there)
	var at: int = pos + int(entry.offset)
	if at + 10 > lib.size() or _u32(lib, at) != ID_CHUNK:
		error = "%s: bad chunk header" % file_name
		return PackedByteArray()
	var comp: int = _u16(lib, at + 8)
	var data_len: int = int(entry.chunk_len) - 10
	var data_at: int = at + 10
	if data_at + data_len > lib.size():
		error = "%s: its data runs past the end of the archive" % file_name
		return PackedByteArray()
	match comp:
		CT_NONE:
			return lib.slice(data_at, data_at + data_len)
		CT_LZH:
			return lzh_decompress(lib, data_at, data_len, int(entry.orig_len))
		_:
			error = "%s: compression type %d is not one Keen Dreams' archive uses" % [file_name, comp]
			return PackedByteArray()


## LoadLIBShape: the ILBM's header fields and its BODY bytes (still packed
## if `comp` says so; UnpackEGAShapeToScreen unpacks them while drawing).
static func load_lib_shape(lib: PackedByteArray, file_name: String) -> Dictionary:
	var iff: PackedByteArray = load_lib_file(lib, file_name)
	if iff.is_empty():
		return {}
	if iff.size() < 12 or iff.slice(0, 4).get_string_from_ascii() != "FORM" or iff.slice(8, 12).get_string_from_ascii() != "ILBM":
		error = "%s is not an ILBM picture" % file_name
		return {}
	var shape: Dictionary = {}
	var p: int = 12
	var file_len: int = _be32(iff, 4) + 4
	while file_len > 0 and p + 8 <= iff.size():
		var tag: String = iff.slice(p, p + 4).get_string_from_ascii()
		var chunk_len: int = (_be32(iff, p + 4) + 1) & 0xFFFFFFFE
		if tag == "BMHD":
			var b: int = p + 8
			shape = {"w": _be16(iff, b), "h": _be16(iff, b + 2), "x": _be16(iff, b + 4), "y": _be16(iff, b + 6),
				"d": iff[b + 8], "trans": iff[b + 9], "comp": iff[b + 10], "pad": iff[b + 11]}
		elif tag == "BODY":
			var size: int = _be32(iff, p + 4)
			shape["bpr"] = (int(shape.get("w", 0)) + 7) >> 3
			shape["data"] = iff.slice(p + 8, p + 8 + size)
			return shape
		p += chunk_len + 8
		file_len -= chunk_len + 8
	error = "%s has no BODY" % file_name
	return {}


# ------------------------------------------------------------------- LZH

static func _start_huff() -> void:
	_freq = PackedInt32Array()
	_freq.resize(T + 1)
	_son = PackedInt32Array()
	_son.resize(T)
	_prnt = PackedInt32Array()
	_prnt.resize(T + N_CHAR)
	for i: int in range(N_CHAR):
		_freq[i] = 1
		_son[i] = i + T
		_prnt[i + T] = i
	var i: int = 0
	var j: int = N_CHAR
	while j <= R:
		_freq[j] = _freq[i] + _freq[i + 1]
		_son[j] = i
		_prnt[i] = j
		_prnt[i + 1] = j
		i += 2
		j += 1
	_freq[T] = 0xFFFF
	_prnt[R] = 0


static func _reconst() -> void:
	# halve the leaves' counts
	var j: int = 0
	for i: int in range(T):
		if _son[i] >= T:
			_freq[j] = (_freq[i] + 1) / 2
			_son[j] = _son[i]
			j += 1
	# rebuild the tree: connect children
	var i: int = 0
	j = N_CHAR
	while j < T:
		var f: int = (_freq[i] + _freq[i + 1]) & 0xFFFF
		_freq[j] = f
		var k: int = j - 1
		while f < _freq[k]:
			k -= 1
		k += 1
		# memmove(&freq[k + 1], &freq[k], (j - k) * 2), and the same for son
		var m: int = j
		while m > k:
			_freq[m] = _freq[m - 1]
			_son[m] = _son[m - 1]
			m -= 1
		_freq[k] = f
		_son[k] = i
		i += 2
		j += 1
	# connect parents
	for n: int in range(T):
		var k: int = _son[n]
		_prnt[k] = n
		if k < T:
			_prnt[k + 1] = n


static func _update(c0: int) -> void:
	if _freq[R] == MAX_FREQ:
		_reconst()
	var c: int = _prnt[c0 + T]
	while true:
		_freq[c] = (_freq[c] + 1) & 0xFFFF
		var k: int = _freq[c]
		var l: int = c + 1
		if k > _freq[l]:
			l += 1
			while k > _freq[l]:
				l += 1
			l -= 1
			_freq[c] = _freq[l]
			_freq[l] = k
			var i: int = _son[c]
			_prnt[i] = l
			if i < T:
				_prnt[i + 1] = l
			var j: int = _son[l]
			_son[l] = i
			_prnt[j] = c
			if j < T:
				_prnt[j + 1] = c
			_son[c] = j
			c = l
		c = _prnt[c]
		if c == 0:
			break


static func _fill() -> void:
	while _getlen <= 8:
		var i: int = 0
		if _left > 0:
			i = _src[_pos] if _pos < _src.size() else 0
			_pos += 1
			_left -= 1
		_getbuf = (_getbuf | (i << (8 - _getlen))) & 0xFFFF
		_getlen += 8


static func _get_bit() -> int:
	_fill()
	var top: int = (_getbuf >> 15) & 1
	_getbuf = (_getbuf << 1) & 0xFFFF
	_getlen -= 1
	return top


static func _get_byte() -> int:
	_fill()
	var i: int = _getbuf
	_getbuf = (_getbuf << 8) & 0xFFFF
	_getlen -= 8
	return i >> 8


static func _decode_char() -> int:
	var c: int = _son[R]
	while c < T:
		c += _get_bit()
		c = _son[c]
	c -= T
	_update(c)
	return c


static func _decode_position() -> int:
	var i: int = _get_byte()
	var c: int = D_CODE[i] << 6
	var j: int = D_LEN[i] - 2
	while j > 0:
		i = ((i << 1) + _get_bit()) & 0xFFFF
		j -= 1
	return c | (i & 0x3F)


## lzhDecompress: `orig_len` bytes from `comp_len` bytes of `src` at `at`.
static func lzh_decompress(src: PackedByteArray, at: int, comp_len: int, orig_len: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	if orig_len <= 0:
		return out
	out.resize(orig_len)
	_src = src
	_pos = at
	_left = comp_len
	_getbuf = 0
	_getlen = 0
	_start_huff()
	var text_buf: PackedByteArray = PackedByteArray()
	text_buf.resize(N)
	for i: int in range(N - F):
		text_buf[i] = 0x20
	var r: int = N - F
	var count: int = 0
	while count < orig_len:
		var c: int = _decode_char()
		if c < 256:
			out[count] = c
			count += 1
			text_buf[r] = c
			r = (r + 1) & (N - 1)
		else:
			var i: int = (r - _decode_position() - 1) & (N - 1)
			var j: int = c - 255 + THRESHOLD
			for k: int in range(j):
				var b: int = text_buf[(i + k) & (N - 1)]
				if count < orig_len:
					out[count] = b
				count += 1
				text_buf[r] = b
				r = (r + 1) & (N - 1)
	return out
