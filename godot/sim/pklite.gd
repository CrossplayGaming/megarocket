# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: ReflectionHLE's depklite.c (NY00123, a derivative of
# OpenTESArena's ExeUnpacker), itself after pklite_specification.md
# sections 4.3.1 and 4.3.2.
class_name PkLite
extends RefCounted
## Unpacks a program compressed with PKLITE 1.05 as Keen Dreams v1.00's
## KDREAMS.EXE is, giving the load image. Only the "duplication" and plain
## modes are needed for that program (no "decryption" mode), as in depklite.

static var error: String = ""

# The two bit trees as flat node arrays: [left, right, value]; 0 = no branch.
# Tree 1 decodes a copy length (bits -> value), tree 2 an offset high byte.
const TREE1: Array = [
	[4, 1, -1], [1, 2, -1], [0, 0, 2], [0, 0, 3],
	[1, 6, -1], [1, 2, -1], [0, 0, 4], [1, 2, -1], [0, 0, 5], [0, 0, 6],
	[1, 6, -1], [1, 2, -1], [0, 0, 7], [1, 2, -1], [0, 0, 8], [0, 0, 9],
	[1, 6, -1], [1, 2, -1], [0, 0, 10], [1, 2, -1], [0, 0, 11], [0, 0, 12],
	[1, 6, -1], [1, 2, -1], [0, 0, 25], [1, 2, -1], [0, 0, 13], [0, 0, 14],
	[1, 6, -1], [1, 2, -1], [0, 0, 15], [1, 2, -1], [0, 0, 16], [0, 0, 17],
	[1, 6, -1], [1, 2, -1], [0, 0, 18], [1, 2, -1], [0, 0, 19], [0, 0, 20],
	[1, 4, -1], [1, 2, -1], [0, 0, 21], [0, 0, 22],
	[1, 2, -1], [0, 0, 23], [0, 0, 24],
]
const TREE2: Array = [
	[2, 1, -1], [0, 0, 0],
	[1, 12, -1], [1, 4, -1], [1, 2, -1], [0, 0, 1], [0, 0, 2], [1, 4, -1], [1, 2, -1], [0, 0, 3], [0, 0, 4],
	[1, 2, -1], [0, 0, 5], [0, 0, 6],
	[1, 18, -1], [1, 8, -1], [1, 4, -1], [1, 2, -1], [0, 0, 7], [0, 0, 8], [1, 2, -1], [0, 0, 9], [0, 0, 10],
	[1, 4, -1], [1, 2, -1], [0, 0, 11], [0, 0, 12], [1, 2, -1], [0, 0, 13], [1, 2, -1], [0, 0, 14], [0, 0, 15],
	[1, 16, -1], [1, 8, -1], [1, 4, -1], [1, 2, -1], [0, 0, 16], [0, 0, 17], [1, 2, -1], [0, 0, 18], [0, 0, 19],
	[1, 4, -1], [1, 2, -1], [0, 0, 20], [0, 0, 21], [1, 2, -1], [0, 0, 22], [0, 0, 23],
	[1, 8, -1], [1, 4, -1], [1, 2, -1], [0, 0, 24], [0, 0, 25], [1, 2, -1], [0, 0, 26], [0, 0, 27],
	[1, 4, -1], [1, 2, -1], [0, 0, 28], [0, 0, 29],
	[1, 2, -1], [0, 0, 30], [0, 0, 31],
]

const DATA_OFFSET: int = 800       # where the compressed stream starts in KDREAMS.EXE

var _src: PackedByteArray
var _pos: int = 0
var _bits: int = 0
var _bits_read: int = 0


func _next_byte() -> int:
	if _pos >= _src.size():
		error = "PKLITE stream ran past the end of the file"
		return 0
	var b: int = _src[_pos]
	_pos += 1
	return b


func _next_bit() -> bool:
	var bit: bool = (_bits & (1 << _bits_read)) != 0
	_bits_read += 1
	if _bits_read == 16:
		_bits_read = 0
		var b1: int = _next_byte()
		var b2: int = _next_byte()
		_bits = b1 | (b2 << 8)
	return bit


func _tree_get(tree: Array) -> int:
	var node: int = 0
	while true:
		var n: Array = tree[node]
		if _next_bit():
			if n[1] == 0:
				error = "PKLITE bit tree has no right branch at node %d" % node
				return -1
			node += n[1]
		else:
			if n[0] == 0:
				error = "PKLITE bit tree has no left branch at node %d" % node
				return -1
			node += n[0]
		var leaf: Array = tree[node]
		if leaf[0] == 0 and leaf[1] == 0:
			return leaf[2]
		if error != "":
			return -1
	return -1


## The unpacked load image of `expected_size` bytes, or empty with `error`.
static func unpack(exe: PackedByteArray, expected_size: int) -> PackedByteArray:
	error = ""
	if exe.size() < DATA_OFFSET + 2:
		error = "PKLITE file is only %d bytes" % exe.size()
		return PackedByteArray()
	var p: PkLite = PkLite.new()
	p._src = exe
	p._pos = DATA_OFFSET
	p._bits = exe[DATA_OFFSET] | (exe[DATA_OFFSET + 1] << 8)
	p._pos = DATA_OFFSET + 2
	p._bits_read = 0
	var out: PackedByteArray = PackedByteArray()
	out.resize(expected_size)
	var o: int = 0
	while true:
		if error != "":
			return PackedByteArray()
		if p._next_bit():
			var copy: int = p._tree_get(TREE1)
			if copy < 0:
				return PackedByteArray()
			var count: int = 0
			if copy == 25:
				var b: int = p._next_byte()
				if b == 0xFE:
					continue
				if b == 0xFF:
					break
				count = b + 25
			else:
				count = copy
			var high: int = 0
			if count != 2:
				high = p._tree_get(TREE2)
				if high < 0:
					return PackedByteArray()
			var low: int = p._next_byte()
			var offset: int = low | (high << 8)
			if o + count > expected_size:
				error = "PKLITE output larger than expected (%d)" % expected_size
				return PackedByteArray()
			if offset > o or offset == 0:
				error = "PKLITE back-reference out of range at byte %d" % o
				return PackedByteArray()
			var from: int = o - offset
			for k: int in range(count):
				out[o] = out[from + k]
				o += 1
		else:
			if o >= expected_size:
				error = "PKLITE output larger than expected (%d)" % expected_size
				return PackedByteArray()
			out[o] = p._next_byte()
			o += 1
	if o != expected_size:
		error = "PKLITE output is %d bytes, expected %d" % [o, expected_size]
		return PackedByteArray()
	return out
