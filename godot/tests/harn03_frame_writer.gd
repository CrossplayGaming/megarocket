# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
extends SceneTree
## HARN-03a: write a generated test pattern through FrameWriter. tools/regress.py
## regenerates the same pattern in Python and compares what it reads back.
##
## Options: --out=<folder>  --plant=<picture number>  (alters one pixel of that picture)
##
## The pattern, which regress.py mirrors exactly:
##   picture n is filled from a generator x -> (x * 1103515245 + 12345) mod 2^31,
##   seeded with n + 1; each byte is (x >> 16) & 0xFF.
##   The plan lists (seed, kind) and where levels start.

const PLAN: Array = [
	# level 1
	[1, "P"], [2, "P"], [2, "P"], [3, "I"], [4, "P"], [4, "I"], [5, "I"], [5, "P"],
	# level 2 starts on a picture equal to the previous one
	[5, "P"], [6, "P"], [7, "I"], [8, "P"],
]
const LEVEL_STARTS: Array = [0, 8]


static func pattern(seed_value: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(FrameWriter.FRAME_BYTES)
	var x: int = seed_value
	for i: int in range(FrameWriter.FRAME_BYTES):
		x = (x * 1103515245 + 12345) & 0x7FFFFFFF
		out[i] = (x >> 16) & 0xFF
	return out


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var out_dir: String = opts.get("out", "")
	var plant: int = int(opts.get("plant", "-1"))
	if out_dir == "":
		t.blocked("no --out folder given; run through tools/regress.py")
		t.finish(self)
		return
	var writer: FrameWriter = FrameWriter.new()
	if not t.ok("store opens", writer.open(out_dir)):
		print("  ", writer.error)
		t.finish(self)
		return
	for n: int in range(PLAN.size()):
		if LEVEL_STARTS.has(n):
			writer.start_level()
		var step: Array = PLAN[n]
		var seed_value: int = step[0]
		var kind: String = step[1]
		var picture: PackedByteArray = pattern(seed_value)
		if n == plant:
			picture[12345] = (picture[12345] + 1) & 0xFF
		t.ok("picture %d accepted" % n, writer.add(picture, kind))
	t.ok("a picture of the wrong size is refused", not writer.add(PackedByteArray([1, 2, 3])))
	t.ok("store closes", writer.close({"case": "pattern"}))
	t.finish(self)
