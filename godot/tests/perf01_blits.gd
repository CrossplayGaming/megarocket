# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## PERF-01: Keen 4-6's faster drawing routines give byte for byte what the per-pixel ones gave. The present's
## conversion of the screen surface into the card's four planes (_write_rows) and the surface copies
## (VL_SurfaceToSurface, VL_SurfaceToSelf) are run on random surfaces, scroll offsets and rectangles (some
## reaching past the surface's edges, the case the old loops guarded byte by byte) against the old loops,
## kept here as the reference.

var t: T = T.new()


func _init() -> void:
	var g: Object = load("res://games/galaxy/gal_keen4.gd").new()
	g.vm = DosMachine.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261010
	var bad: int = 0
	for trial: int in range(40):
		var w: int = 320 + 16 * rng.randi_range(0, 12)
		var h: int = 200 + 16 * rng.randi_range(0, 6)
		g.vl_screen = g.VL_Surface.new(w, h)
		var px: PackedByteArray = g.vl_screen.pixels
		for i: int in range(px.size()):
			px[i] = rng.randi_range(0, 255)
		g.vl_screen.pixels = px
		g.vl_scrollXpixels = rng.randi_range(0, w - 320 + 8)    # now and then past the right edge
		g.vl_scrollYpixels = rng.randi_range(0, h - 200 + 2)
		var colour: int = -1 if trial % 5 != 4 else rng.randi_range(0, 15)
		var base: int = rng.randi_range(0, 1) * EgaCard.PAGE_SIZE
		var y0: int = rng.randi_range(0, 150)
		var y1: int = rng.randi_range(y0, 200)
		_scramble(g.vm.card, rng)
		var before: Array = _planes(g.vm.card)
		_ref_write_rows(g, base, y0, y1, colour)
		var want: Array = _planes(g.vm.card)
		_set_planes(g.vm.card, before)
		g._write_rows(base, y0, y1, colour)
		if _planes(g.vm.card) != want:
			bad += 1
	t.eq("_write_rows: the four planes as the per-pixel loop made them (40 random screens)", bad, 0)
	bad = 0
	for trial: int in range(60):
		var a: Object = g.VL_Surface.new(rng.randi_range(40, 400), rng.randi_range(20, 260))
		var b: Object = g.VL_Surface.new(rng.randi_range(40, 400), rng.randi_range(20, 260))
		for surf: Object in [a, b]:
			var p: PackedByteArray = surf.pixels
			for i: int in range(p.size()):
				p[i] = rng.randi_range(0, 255)
			surf.pixels = p
		var sw: int = rng.randi_range(1, 120)
		var sh: int = rng.randi_range(1, 60)
		var x: int = rng.randi_range(-20, b.w)
		var y: int = rng.randi_range(-10, b.h)
		var sx: int = rng.randi_range(-20, a.w)
		var sy: int = rng.randi_range(-10, a.h)
		var b_before: PackedByteArray = b.pixels.duplicate()
		_ref_surface_to_surface(a, b, x, y, sx, sy, sw, sh)
		var want: PackedByteArray = b.pixels.duplicate()
		b.pixels = b_before
		g.VL_SurfaceToSurface(a, b, x, y, sx, sy, sw, sh)
		if b.pixels != want:
			bad += 1
		# the same surface, overlapping (the scroll)
		var a_before: PackedByteArray = a.pixels.duplicate()
		var dx: int = rng.randi_range(-24, 24)
		var dy: int = rng.randi_range(-16, 16)
		_ref_surface_to_self(a, sx + dx, sy + dy, sx, sy, sw, sh)
		var want2: PackedByteArray = a.pixels.duplicate()
		a.pixels = a_before
		g.VL_SurfaceToSelf(a, sx + dx, sy + dy, sx, sy, sw, sh)
		if a.pixels != want2:
			bad += 1
	t.eq("surface copies: every byte as the old loops left it (60 random rectangles, to another and to itself)", bad, 0)
	# tiles (unmasked, four planes) and sprites (masked, clipped to the screen): random graphics, random places
	var bad_tiles: int = 0
	var bad_sprites: int = 0
	for trial: int in range(200):
		var w: int = 8 * rng.randi_range(1, 6) + (0 if trial % 7 != 6 else rng.randi_range(1, 7))    # now and then not whole bytes
		var h: int = rng.randi_range(1, 40)
		var so: int = rng.randi_range(0, 30)
		var src: PackedByteArray = PackedByteArray()
		src.resize(so + (w / 8 + 1) * h * 5 + 16)
		for i: int in range(src.size()):
			src[i] = rng.randi_range(0, 255)
		var pitch: int = rng.randi_range(64, 400)
		var dh: int = rng.randi_range(40, 220)
		var x: int = rng.randi_range(-w - 4, pitch + 4)
		var y: int = rng.randi_range(-h - 4, dh + 4)
		var dst: PackedByteArray = PackedByteArray()
		dst.resize(pitch * dh)
		for i: int in range(dst.size()):
			dst[i] = rng.randi_range(0, 255)
		var d1: PackedByteArray = dst.duplicate()
		var d2: PackedByteArray = dst.duplicate()
		if (w & 7) == 0 or trial % 2 == 0:
			_ref_unmasked(src, so, d1, x, y, pitch, w, h)
			g.VL_UnmaskedToPAL8(src, so, d2, x, y, pitch, w, h)
			if d1 != d2:
				bad_tiles += 1
		d1 = dst.duplicate()
		d2 = dst.duplicate()
		_ref_masked_clip(g, src, so, d1, x, y, pitch, w, h, pitch, dh)
		g.VL_MaskedBlitClipToPAL8(src, so, d2, x, y, pitch, w, h, pitch, dh)
		if d1 != d2:
			bad_sprites += 1
	t.eq("tiles: every byte as the per-pixel loop drew it (random tiles, partly off the destination)", bad_tiles, 0)
	t.eq("sprites: every byte as the per-pixel loop drew it (200 random sprites, clipped at every edge)", bad_sprites, 0)
	# the intro's one-bit picture through a plane mask, and the masked fill
	var bad_1bpp: int = 0
	var bad_rect: int = 0
	for trial: int in range(150):
		var w: int = 8 * rng.randi_range(1, 30)
		var h: int = rng.randi_range(1, 6)
		var so: int = rng.randi_range(0, 20)
		var src: PackedByteArray = PackedByteArray()
		src.resize(so + (w / 8) * h + 8)
		for i: int in range(src.size()):
			src[i] = rng.randi_range(0, 255)
		var pitch: int = rng.randi_range(64, 400)
		var dh: int = rng.randi_range(10, 120)
		var dst: PackedByteArray = PackedByteArray()
		dst.resize(pitch * dh)
		for i: int in range(dst.size()):
			dst[i] = rng.randi_range(0, 255)
		var x: int = rng.randi_range(-w - 4, pitch + 4)
		var y: int = rng.randi_range(-h - 2, dh + 2)
		var colour: int = rng.randi_range(0, 255)
		var mm: int = rng.randi_range(0, 15)
		var d1: PackedByteArray = dst.duplicate()
		var d2: PackedByteArray = dst.duplicate()
		_ref_1bpp_pm(src, so, d1, x, y, pitch, w, h, colour, mm)
		g.VL_1bppToPAL8_PM(src, so, d2, x, y, pitch, w, h, colour, mm)
		if d1 != d2:
			bad_1bpp += 1
		var surf: Object = g.VL_Surface.new(pitch, dh)
		surf.pixels = dst.duplicate()
		var rw: int = rng.randi_range(0, 90)
		var rh: int = rng.randi_range(0, 20)
		var rx: int = rng.randi_range(-30, pitch + 10)
		var ry: int = rng.randi_range(-5, dh + 5)
		_ref_rect_pm(surf, rx, ry, rw, rh, colour, mm)
		var want: PackedByteArray = surf.pixels.duplicate()
		surf.pixels = dst.duplicate()
		g.VL_SurfaceRect_PM(surf, rx, ry, rw, rh, colour, mm)
		if surf.pixels != want:
			bad_rect += 1
	t.eq("one-bit pictures through a plane mask: every byte as before (150 random)", bad_1bpp, 0)
	t.eq("masked fills: every byte as before (150 random rectangles)", bad_rect, 0)
	t.finish(self)


func _ref_1bpp_pm(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, colour: int, mapmask: int) -> void:
	mapmask &= 0xF
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var pixel: int = (colour if (src[plane_off] & plane_bit) != 0 else colour & 0xF0) & mapmask
			var i: int = (sy + y) * pitch + (sx + x)
			if i >= 0 and i < dst.size():
				dst[i] = (dst[i] & ~mapmask) | pixel


func _ref_rect_pm(dst: Object, x: int, y: int, w: int, h: int, colour: int, mapmask: int) -> void:
	mapmask &= 0xF
	colour &= mapmask
	for py: int in range(y, y + h):
		for px: int in range(x, x + w):
			var i: int = py * dst.w + px
			if i >= 0 and i < dst.pixels.size():
				dst.pixels[i] = (dst.pixels[i] & ~mapmask) | colour


func _ref_put(dst: PackedByteArray, i: int, v: int) -> void:
	if i >= 0 and i < dst.size():
		dst[i] = v


func _ref_unmasked(src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int) -> void:
	var plane: int = (w / 8) * h
	for sy: int in range(h):
		for sx: int in range(w):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var pixel: int = (8 if (src[plane_off + plane * 3] & plane_bit) != 0 else 0) | 				(4 if (src[plane_off + plane * 2] & plane_bit) != 0 else 0) | 				(2 if (src[plane_off + plane] & plane_bit) != 0 else 0) | 				(1 if (src[plane_off] & plane_bit) != 0 else 0)
			_ref_put(dst, (sy + y) * pitch + (sx + x), pixel)


func _ref_masked_clip(g: Object, src: PackedByteArray, so: int, dst: PackedByteArray, x: int, y: int, pitch: int, w: int, h: int, dw: int, dh: int) -> void:
	var plane: int = (w / 8) * h
	var initialX: int = maxi(-x, 0)
	var initialY: int = maxi(-y, 0)
	var finalW: int = mini(maxi(dw - x, 0), w)
	var finalH: int = mini(maxi(dh - y, 0), h)
	for sy: int in range(initialY, finalH):
		for sx: int in range(initialX, finalW):
			var plane_off: int = so + ((sy * w + sx) >> 3)
			var plane_bit: int = 1 << (7 - ((sy * w + sx) & 7))
			var i: int = (sy + y) * pitch + (sx + x)
			if (src[plane_off] & plane_bit) == 0:
				dst[i] = 0
			var pixel: int = (8 if (src[plane_off + plane * 4] & plane_bit) != 0 else 0) | 				(4 if (src[plane_off + plane * 3] & plane_bit) != 0 else 0) | 				(2 if (src[plane_off + plane * 2] & plane_bit) != 0 else 0) | 				(1 if (src[plane_off + plane] & plane_bit) != 0 else 0)
			dst[i] = dst[i] | pixel


func _scramble(card: EgaCard, rng: RandomNumberGenerator) -> void:
	for i: int in range(4):
		var p: PackedByteArray = card.get("plane%d" % i)
		for k: int in range(0, p.size(), 97):
			p[k] = rng.randi_range(0, 255)
		card.set("plane%d" % i, p)


func _planes(card: EgaCard) -> Array:
	return [card.plane0.duplicate(), card.plane1.duplicate(), card.plane2.duplicate(), card.plane3.duplicate()]


func _set_planes(card: EgaCard, p: Array) -> void:
	card.plane0 = p[0].duplicate()
	card.plane1 = p[1].duplicate()
	card.plane2 = p[2].duplicate()
	card.plane3 = p[3].duplicate()


# ---- the reference: the loops as they were

func _ref_write_rows(g: Object, base: int, y0: int, y1: int, colour: int) -> void:
	var card: EgaCard = g.vm.card
	var src: PackedByteArray = g.vl_screen.pixels
	var pitch: int = g.vl_screen.w
	var p0: PackedByteArray = card.plane0
	var p1: PackedByteArray = card.plane1
	var p2: PackedByteArray = card.plane2
	var p3: PackedByteArray = card.plane3
	for y: int in range(y0, y1):
		var srow: int = (y + g.vl_scrollYpixels) * pitch + g.vl_scrollXpixels
		var drow: int = base + y * 40
		for bx: int in range(40):
			var b0: int = 0
			var b1: int = 0
			var b2: int = 0
			var b3: int = 0
			var s: int = srow + bx * 8
			for k: int in range(8):
				var c: int = colour if colour >= 0 else (src[s + k] if s + k < src.size() else 0)
				var bit: int = 0x80 >> k
				if (c & 1) != 0:
					b0 |= bit
				if (c & 2) != 0:
					b1 |= bit
				if (c & 4) != 0:
					b2 |= bit
				if (c & 8) != 0:
					b3 |= bit
			p0[drow + bx] = b0
			p1[drow + bx] = b1
			p2[drow + bx] = b2
			p3[drow + bx] = b3
	card.plane0 = p0
	card.plane1 = p1
	card.plane2 = p2
	card.plane3 = p3


func _ref_surface_to_surface(src: Object, dst: Object, x: int, y: int, sx: int, sy: int, sw: int, sh: int) -> void:
	for _y: int in range(sy, sy + sh):
		var d: int = (_y - sy + y) * dst.w + x
		var s: int = _y * src.w + sx
		for k: int in range(sw):
			if d + k >= 0 and d + k < dst.pixels.size() and s + k >= 0 and s + k < src.pixels.size():
				dst.pixels[d + k] = src.pixels[s + k]


func _ref_surface_to_self(surf: Object, x: int, y: int, sx: int, sy: int, sw: int, sh: int) -> void:
	var rows: Array = range(sh) if sy > y else range(sh - 1, -1, -1)
	for yi: int in rows:
		var d: int = (yi + y) * surf.w + x
		var s: int = (sy + yi) * surf.w + sx
		var line: PackedByteArray = PackedByteArray()
		line.resize(sw)
		for k: int in range(sw):
			if s + k >= 0 and s + k < surf.pixels.size():
				line[k] = surf.pixels[s + k]
		for k: int in range(sw):
			if d + k >= 0 and d + k < surf.pixels.size():
				surf.pixels[d + k] = line[k]
