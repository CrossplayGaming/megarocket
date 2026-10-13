# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## NATIVE-03: the card-to-screen conversion in C (D2Blit.compose) is
## byte-identical to the GDScript reference of ega_card.gd's compose_rows:
## for many panning, split, compatibility, start-address, line-width and
## row-range cases the band it returns equals the reference's, an
## out-of-range request returns an empty array, and a whole frame through
## begin_frame and 50 scan_rows calls gives the same frame_pixels with and
## without the native class. The test fails when the class is missing.

var t: T = T.new()

const WIDTH: int = 320
const HEIGHT: int = 200
const BAND: int = 4


func _init() -> void:
	_go.call_deferred()


## A card in EGA mode with the given registers, its four planes filled with
## the seeded random bytes.
func card(rng: RandomNumberGenerator, display_start: int, offset: int, compare: int,
		pan: int, compat: int) -> EgaCard:
	var c: EgaCard = EgaCard.new()
	c.bios_set_video_mode(EgaCard.MODE_EGA)
	for p: int in range(4):
		var plane: PackedByteArray = PackedByteArray()
		plane.resize(65536)
		for i: int in range(65536):
			plane[i] = rng.randi_range(0, 255)
		if p == 0:
			c.plane0 = plane
		elif p == 1:
			c.plane1 = plane
		elif p == 2:
			c.plane2 = plane
		else:
			c.plane3 = plane
	c.crtc[EgaCard.CRTC_STARTHIGH] = (display_start >> 8) & 0xFF
	c.crtc[EgaCard.CRTC_STARTLOW] = display_start & 0xFF
	c.latch_start()
	c.crtc[EgaCard.CRTC_OFFSET] = offset
	# split_row() reads the line compare as LINECOMPARE | (OVERFLOW & 0x10) << 4
	# | (MAXSCANLINE & 0x40) << 3, so the bits of `compare` go there.
	c.crtc[EgaCard.CRTC_LINECOMPARE] = compare & 0xFF
	c.crtc[EgaCard.CRTC_OVERFLOW] = (compare >> 4) & 0x10
	c.crtc[EgaCard.CRTC_MAXSCANLINE] = (compare >> 3) & 0x40
	c.atc[EgaCard.ATR_PELPAN] = pan
	c.atc[EgaCard.ATR_MODE] = compat
	return c


func _go() -> void:
	t.ok("the D2Blit class is there (NATIVE-03)", ClassDB.class_exists("D2Blit"))
	if not ClassDB.class_exists("D2Blit"):
		t.finish(self)
		return
	var blit: Object = ClassDB.instantiate("D2Blit")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261013
	# (display_start, CRTC offset, line compare, pan, compatibility bit)
	var setups: Array = [
		[0, 20, 0, 0, 0],
		[0, 20, 0, 3, 0],
		[0, 20, 0, 7, 0],
		[0, 21, 0, 5, 0],
		[0, 20, 200, 3, 0],
		[0, 20, 200, 3, 0x20],
		[0, 20, 2, 3, 0],
		[0, 20, 2, 3, 0x20],
		[0, 21, 200, 7, 0x20],
		[0xFFE0, 20, 0, 3, 0],
		[0xFFE0, 21, 200, 5, 0x20],
		[0xFFE0, 20, 2, 7, 0],
	]
	var ranges: Array = [[0, 4], [196, 200], [0, 200], [2, 6], [198, 200]]
	for s: Array in setups:
		var ds: int = s[0]
		var off: int = s[1]
		var cmp: int = s[2]
		var pan: int = s[3]
		var compat: int = s[4]
		for r: Array in ranges:
			var y0: int = r[0]
			var y1: int = r[1]
			var c: EgaCard = card(rng, ds, off, cmp, pan, compat)
			# The reference writes row y at y * WIDTH (it is made for the
			# full-size frame_pixels), and the panning reads one byte past the
			# last row, so the buffer is the whole frame plus eight bytes.
			var want: PackedByteArray = PackedByteArray()
			want.resize(HEIGHT * WIDTH + 8)
			c.compose_rows(want, y0, y1)
			var got: PackedByteArray = blit.compose(c.plane0, c.plane1, c.plane2, c.plane3,
					ds, off * 2, c.split_row(), pan, compat, y0, y1)
			t.ok("start %x, offset %d, compare %d, pan %d, compat %d, rows %d..%d: %d bytes, identical to the reference"
					% [ds, off, cmp, pan, compat, y0, y1, got.size()],
					got.size() == (y1 - y0) * WIDTH and got == want.slice(y0 * WIDTH, y1 * WIDTH))
	# Out-of-range requests give empty arrays.
	var c: EgaCard = card(rng, 0, 20, 0, 3, 0)
	var oob: Array = [
		blit.compose(c.plane0, c.plane1, c.plane2, c.plane3, 0, 40, 200, 0, 0, -1, 4),
		blit.compose(c.plane0, c.plane1, c.plane2, c.plane3, 0, 40, 200, 0, 0, 0, 201),
		blit.compose(c.plane0, c.plane1, c.plane2, c.plane3, 0, 40, 200, 0, 0, 4, 4),
		blit.compose(c.plane0, c.plane1, c.plane2, c.plane3, 0, 40, 200, 0, 0, 4, 0),
	]
	for i: int in range(oob.size()):
		t.ok("out of range %d: an empty array (%d bytes)" % [i, (oob[i] as PackedByteArray).size()],
			(oob[i] as PackedByteArray).size() == 0)
	var small: PackedByteArray = PackedByteArray()
	small.resize(100)
	var oob2: PackedByteArray = blit.compose(small, c.plane1, c.plane2, c.plane3, 0, 40, 200, 0, 0, 0, 4)
	t.ok("a small plane: an empty array (%d bytes)" % oob2.size(), oob2.size() == 0)
	# A whole frame: begin_frame and 50 scan_rows calls give the same
	# frame_pixels with and without the native class.
	var cf: EgaCard = card(rng, 0xFFE0, 21, 200, 5, 0x20)
	cf.begin_frame()
	for b: int in range(50):
		cf.scan_rows(b * BAND, b * BAND + BAND)
	var native_frame: PackedByteArray = cf.frame_pixels.duplicate()
	cf.blit = null
	cf.begin_frame()
	for b: int in range(50):
		cf.scan_rows(b * BAND, b * BAND + BAND)
	t.ok("a whole frame: the same frame_pixels with and without the native class",
			cf.frame_pixels.size() == native_frame.size() and cf.frame_pixels == native_frame)
	t.finish(self)
