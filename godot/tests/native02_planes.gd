# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## NATIVE-02: the screen-to-card conversion in C (D2Blit.planes) is byte-identical
## to the GDScript reference loop of gal_lib.gd's _write_rows: for several
## offsets and run lengths the four planes it returns (plane-major, 40 bytes a
## row) equal the reference's, and an out-of-range request returns an empty
## array. The test fails when the class is missing.

var t: T = T.new()

const PITCH: int = 336
const ROWS: int = 232
const WIDTH: int = 320


func _init() -> void:
	_go.call_deferred()


## The reference: the b0..b3 loop of _write_rows, one row at a time, the four
## planes as 40-byte rows, plane-major (plane 0's rows first, then 1, 2, 3).
func _reference(src: PackedByteArray, src_off: int, pitch: int, rows: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(4 * rows * (WIDTH / 8))
	for r: int in range(rows):
		var s: int = src_off + r * pitch
		for bx: int in range(WIDTH / 8):
			var b0: int = 0
			var b1: int = 0
			var b2: int = 0
			var b3: int = 0
			for k: int in range(8):
				var c: int = src[s + bx * 8 + k]
				var bit: int = 0x80 >> k
				if (c & 1) != 0:
					b0 |= bit
				if (c & 2) != 0:
					b1 |= bit
				if (c & 4) != 0:
					b2 |= bit
				if (c & 8) != 0:
					b3 |= bit
			out[r * (WIDTH / 8) + bx] = b0
			out[rows * (WIDTH / 8) + r * (WIDTH / 8) + bx] = b1
			out[2 * rows * (WIDTH / 8) + r * (WIDTH / 8) + bx] = b2
			out[3 * rows * (WIDTH / 8) + r * (WIDTH / 8) + bx] = b3
	return out


func _go() -> void:
	t.ok("the D2Blit class is there (NATIVE-02)", ClassDB.class_exists("D2Blit"))
	if not ClassDB.class_exists("D2Blit"):
		t.finish(self)
		return
	var blit: Object = ClassDB.instantiate("D2Blit")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261012
	var src: PackedByteArray = PackedByteArray()
	src.resize(PITCH * ROWS)
	for i: int in range(src.size()):
		src[i] = rng.randi_range(0, 15)
	var cases: Array = [[0, 1], [7, 13], [0, 200], [1, 1], [5, 13], [33, 1], [10, 5]]
	for c: Array in cases:
		var off: int = c[0]
		var rows: int = c[1]
		var got: PackedByteArray = blit.planes(src, off, PITCH, rows)
		var want: PackedByteArray = _reference(src, off, PITCH, rows)
		t.ok("src_off %d, %d row(s): %d bytes, identical to the reference" % [off, rows, got.size()],
			got.size() == want.size() and got == want)
	var oob: PackedByteArray = blit.planes(src, src.size() - 10, PITCH, 1)
	t.ok("out of range: an empty array (%d bytes)" % oob.size(), oob.size() == 0)
	var oob2: PackedByteArray = blit.planes(src, 0, PITCH, ROWS + 1)
	t.ok("one row past the end: an empty array (%d bytes)" % oob2.size(), oob2.size() == 0)
	t.finish(self)
