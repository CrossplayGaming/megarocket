# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01a (VW): the Dreams port's video library draws what the data says. On the emulated EGA
## card, through DrmVW's EGA routines: every picture, the masked pictures, a sample of tile 16s,
## every tile 8 and masked tile 8, sprites at each of their shifts, the proportional font, the
## lines and bars, the block copies, the update blocks and the cursor, read back from the card's
## planes and compared with DreamsData's own decode; the fades reach the palette registers.
##
## Options: --game_data=<folder>

const BG: int = 5     # a background colour
const LW: int = 64    # the line width the game uses (SCREENWIDTH)

var t: T = T.new()
var g: DreamsGame
var d: DreamsData


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	d = DreamsData.new()
	if not t.ok("files load (%s)" % d.error, d.load_game(root.path_join("kdreams"))):
		t.finish(self)
		return
	g = DreamsGame.new()
	g.vm = DosMachine.new()
	g.data = d
	g.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE100 if d.version == "e100" else DrmDecl.BE_GAMEVER_KDREAMSE193
	g.current_gamever_int = 100 if d.version == "e100" else 193
	g.RefKeen_Patch_id_vw()
	g.RefKeen_Patch_id_vw_ae()
	g.MM_Startup()
	g.VW_Startup()
	g.CA_Startup()
	g.VW_SetScreenMode(DrmDecl.EGAGR)
	g.VW_SetLineWidth(LW)
	t.ok("startup: a VGA in the EGA mode, line width %d on the card, ylookup[10] %d" % [g.vm.card.line_width(), g.ylookup[10]],
		g.videocard == DrmDecl.VGAcard and g.grmode == DrmDecl.EGAGR and g.vm.card.line_width() == LW and g.ylookup[10] == 10 * LW)
	_shift_tables()
	_clear()
	g.displayofs = 0
	g.bufferofs = 0x4000
	_pictures()
	_tiles()
	_sprites()
	_font()
	_lines()
	_blocks()
	_update_screen()
	_fades()
	t.ok("nothing quit (%s)" % g.quit_message, not g.quitting)
	t.finish(self)


## The colour of pixel (x, y) of the virtual screen at `base`.
func pixel(base: int, x: int, y: int) -> int:
	var a: int = (base + y * LW + (x >> 3)) & 0xFFFF
	var m: int = 0x80 >> (x & 7)
	var card: EgaCard = g.vm.card
	return int((card.plane0[a] & m) != 0) | (int((card.plane1[a] & m) != 0) << 1) \
		| (int((card.plane2[a] & m) != 0) << 2) | (int((card.plane3[a] & m) != 0) << 3)


## Pixels of a w x h image (at x0, y0 on the buffer page) that differ from `want`.
func diff(x0: int, y0: int, w: int, h: int, want: Callable) -> int:
	var bad: int = 0
	for y: int in range(h):
		for x: int in range(w):
			if pixel(g.bufferofs, x0 + x, y0 + y) != want.call(x, y):
				bad += 1
	return bad


func _shift_tables() -> void:
	# values as id_vw_a.c lists them in shiftdata0..7
	var want: Array = [[0, 200, 200], [1, 1, 32768], [1, 3, 32769], [2, 3, 49152], [3, 9, 8193],
		[5, 2, 4096], [6, 255, 64515], [7, 255, 65025], [7, 128, 1]]
	var bad: int = 0
	for w: Array in want:
		if g.shifttabletable[w[0]][w[1]] != w[2]:
			bad += 1
	t.ok("shift tables: 8 of 256, %d of %d listed values differ" % [bad, want.size()],
		g.shifttabletable.size() == 8 and (g.shifttabletable[7] as PackedInt32Array).size() == 256 and bad == 0)


func _clear() -> void:
	g.VW_ClearVideo(BG)
	var card: EgaCard = g.vm.card
	t.ok("VW_ClearVideo(%d) fills the planes" % BG, card.plane0[1234] == 0xFF and card.plane1[40000] == 0
		and card.plane2[65534] == 0xFF and card.plane3[0] == 0)
	g.VW_ClearVideo(0)


func _pictures() -> void:
	var bad: int = 0
	var drawn: int = 0
	for i: int in range(DrmDecl.NUMPICS):
		var p: Dictionary = d.pic(i)
		if p.is_empty() or p.w > LW * 8 - 8 or p.h > 290:
			continue
		g.CA_CacheGrChunk(DrmDecl.STARTPICS + i)
		g.VW_DrawPic(1, 2, DrmDecl.STARTPICS + i)
		var pixels: PackedByteArray = p.pixels
		var w: int = p.w
		bad += diff(8, 2, p.w, p.h, func(x: int, y: int) -> int: return pixels[y * w + x])
		g.MM_SetPurge("gr:%d" % (DrmDecl.STARTPICS + i), 3)
		drawn += 1
	t.ok("VW_DrawPic: %d of %d pictures, %d pixels differ" % [drawn, DrmDecl.NUMPICS, bad], drawn == DrmDecl.NUMPICS and bad == 0)

	# the masked pictures, over a background, with their update blocks marked
	_update_arrays()
	bad = 0
	var marks_ok: bool = true
	for i: int in range(DrmDecl.NUMPICM):
		var p: Dictionary = d.masked_pic(i)
		g.CA_CacheGrChunk(DrmDecl.STARTPICM + i)
		g.call(g.VW_Bar, 0, 0, 320, 120, BG)
		_clear_marks()
		g.VWB_DrawMPic(16, 8, DrmDecl.STARTPICM + i)
		var pixels: PackedByteArray = p.pixels
		var mask: PackedByteArray = p.mask
		var w: int = p.w
		bad += diff(16, 8, p.w, p.h, func(x: int, y: int) -> int:
			return (BG if mask[y * w + x] else 0) | pixels[y * w + x])
		marks_ok = marks_ok and _marked_exactly(16, 8, 16 + p.w - 1, 8 + p.h - 1)
	t.ok("VWB_DrawMPic: %d masked pictures over a background, %d pixels differ, update blocks marked %s" % [DrmDecl.NUMPICM, bad, marks_ok],
		bad == 0 and marks_ok)


## The refresh manager's update array and block starts, as RF_Startup sets them for the EGA.
func _update_arrays() -> void:
	g.update.resize(2 * 400)
	g.update.fill(0)
	g.updateptr = 60
	g.uwidthtable.resize(DrmDecl.PORTTILESHIGH)
	for i: int in range(DrmDecl.PORTTILESHIGH):
		g.uwidthtable[i] = DrmDecl.UPDATEWIDE * i
	g.blockstarts.resize(DrmDecl.UPDATEWIDE * DrmDecl.UPDATEHIGH)
	for y: int in range(DrmDecl.UPDATEHIGH):
		for x: int in range(DrmDecl.UPDATEWIDE):
			g.blockstarts[y * DrmDecl.UPDATEWIDE + x] = DrmDecl.SCREENWIDTH_EGA * 16 * y + x * DrmDecl.TILEWIDTH_EGA
	_clear_marks()


func _clear_marks() -> void:
	for i: int in range(DrmDecl.UPDATEWIDE * DrmDecl.UPDATEHIGH):
		g.update[g.updateptr + i] = 0
	g.update[g.updateptr + DrmDecl.UPDATEWIDE * DrmDecl.PORTTILESHIGH] = 1    # UPDATETERMINATE
	g.update[g.updateptr + DrmDecl.UPDATEWIDE * DrmDecl.PORTTILESHIGH + 1] = 3


## The update array marks exactly the 16-pixel blocks the pixel rectangle covers.
func _marked_exactly(x1: int, y1: int, x2: int, y2: int) -> bool:
	for ty: int in range(DrmDecl.UPDATEHIGH):
		for tx: int in range(DrmDecl.UPDATEWIDE - 1):
			var want: int = int(tx >= x1 >> 4 and tx <= x2 >> 4 and ty >= y1 >> 4 and ty <= y2 >> 4)
			if g.update[g.updateptr + ty * DrmDecl.UPDATEWIDE + tx] != want:
				return false
	return true


func _tiles() -> void:
	# tile 16s: a sample (every 7th) of those present
	var tiles: PackedByteArray = d.tiles16()
	var bad: int = 0
	var drawn: int = 0
	for i: int in range(0, DrmDecl.NUMTILE16, 7):
		g.CA_CacheGrChunk(DrmDecl.STARTTILE16 + i)
		if g.grsegs[DrmDecl.STARTTILE16 + i] == null:
			continue    # a sparse tile
		g.VW_DrawTile16(3, 5, i)
		bad += diff(24, 5, 16, 16, func(x: int, y: int) -> int: return tiles[i * 256 + y * 16 + x])
		g.MM_SetPurge("gr:%d" % (DrmDecl.STARTTILE16 + i), 3)
		drawn += 1
	t.ok("VW_DrawTile16: %d tiles, %d pixels differ" % [drawn, bad], drawn > 100 and bad == 0)

	# every tile 8, through the function pointer and through VWB_DrawTile8 at a pixel position
	g.CA_CacheGrChunk(DrmDecl.STARTTILE8)
	var t8: PackedByteArray = d.chunk(DrmDecl.STARTTILE8)
	bad = 0
	for i: int in range(DrmDecl.NUMTILE8):
		g.call(g.VW_DrawTile8, 2, 3, i)
		var px: PackedByteArray = GalData.unplane(t8, i * 32, 1, 8)
		bad += diff(16, 3, 8, 8, func(x: int, y: int) -> int: return px[y * 8 + x])
		g.VWB_DrawTile8(45, 30, i)    # x rounds down to the byte
		bad += diff(40, 30, 8, 8, func(x: int, y: int) -> int: return px[y * 8 + x])
	t.ok("VW_DrawTile8 / VWB_DrawTile8: %d tiles, %d pixels differ" % [DrmDecl.NUMTILE8, bad], bad == 0)

	# every masked tile 8 over a background
	g.CA_CacheGrChunk(DrmDecl.STARTTILE8M)
	var t8m: PackedByteArray = d.chunk(DrmDecl.STARTTILE8M)
	bad = 0
	for i: int in range(DrmDecl.NUMTILE8M):
		g.call(g.VW_Bar, 16, 3, 8, 8, BG)
		g.VW_DrawTile8M(2, 3, i)
		var m: Dictionary = GalData.unplane_masked(t8m, i * 40, 1, 8)
		var px: PackedByteArray = m.pixels
		var mk: PackedByteArray = m.mask
		bad += diff(16, 3, 8, 8, func(x: int, y: int) -> int: return (BG if mk[y * 8 + x] else 0) | px[y * 8 + x])
	t.ok("VW_DrawTile8M: %d masked tiles over a background, %d pixels differ" % [DrmDecl.NUMTILE8M, bad], bad == 0)


func _sprites() -> void:
	var bad: int = 0
	var drawn: int = 0
	var sprites: int = 0
	var shifts_seen: Dictionary = {}
	for i: int in range(0, DrmDecl.NUMSPRITES, 9):
		var s: Dictionary = d.sprite(i)
		if s.is_empty():
			continue
		sprites += 1
		var chunk: int = DrmDecl.STARTSPRITES + i
		g.CA_CacheGrChunk(chunk)
		shifts_seen[s.shifts] = true
		for k: int in range(8):
			var x: int = 120 + k
			var y: int = 60
			var sx: int = x + (s.orgx >> 4)
			var sy: int = y + (s.orgy >> 4)
			var left: int = (sx & ~7) - 8
			var top: int = sy - 1
			var w: int = s.w + 24
			var h: int = s.h + 2
			g.call(g.VW_Bar, left, top, w, h, BG)
			g.VW_DrawSprite(x, y, chunk)
			# where the shift the sprite has puts it
			@warning_ignore("integer_division")
			var shift: int = (sx & 7) / 2
			var pixshift: int = 0
			match int(s.shifts):
				4: pixshift = 2 * shift
				2: pixshift = 0 if shift < 2 else 4
			var ox: int = (sx & ~7) + pixshift - left
			var oy: int = sy - top
			var sw: int = s.w
			var spx: PackedByteArray = s.pixels
			var smk: PackedByteArray = s.mask
			var shh: int = s.h
			bad += diff(left, top, w, h, func(px: int, py: int) -> int:
				var u: int = px - ox
				var v: int = py - oy
				if u < 0 or v < 0 or u >= sw or v >= shh:
					return BG
				return (BG if smk[v * sw + u] else 0) | spx[v * sw + u])
			drawn += 1
		g.MM_SetPurge("gr:%d" % chunk, 3)
	t.ok("VW_DrawSprite: %d draws (%d sprites at 8 x positions, shifts %s), %d pixels differ" % [drawn, sprites, shifts_seen.keys(), bad],
		drawn > 200 and bad == 0)


func _font() -> void:
	g.CA_CacheGrChunk(DrmDecl.STARTFONT)
	var f: Dictionary = d.font()
	var text: String = "Keen Dreams: the Boobus Bomb!"
	var total: int = 0
	for i: int in range(text.length()):
		total += f.widths[text.unicode_at(i)]
	var m: PackedInt32Array = g.VW_MeasurePropString(text, -1, 0, 0)
	t.ok("VW_MeasurePropString: %d x %d (font: %d x %d)" % [m[0], m[1], total, f.height], m[0] == total and m[1] == f.height)
	var part: PackedInt32Array = g.VW_MeasurePropString(text, 4, 0, 0)
	var keen: int = 0
	for i: int in range(4):
		keen += f.widths[text.unicode_at(i)]
	t.ok("VW_MeasurePropString up to optsend: %d (want %d)" % [part[0], keen], part[0] == keen)

	for start_x: int in [21, 64]:
		for colour: int in [15, 9]:
			var top: int = 150
			g.call(g.VW_Bar, 0, top - 2, 320, f.height + 4, BG)
			g.px = start_x
			g.py = top
			g.fontcolor = colour
			_update_arrays()
			g.VWB_DrawPropString(text, -1)
			# what the font says: each glyph's set pixels XORed with the colour
			var want: PackedByteArray = PackedByteArray()
			want.resize(320 * f.height)
			want.fill(BG)
			var cx: int = start_x
			for i: int in range(text.length()):
				var ch: int = text.unicode_at(i)
				var w: int = f.widths[ch]
				var gl: PackedByteArray = f.glyphs[ch]
				for y: int in range(f.height):
					for x: int in range(w):
						if gl[y * w + x]:
							want[y * 320 + cx + x] = BG ^ colour
				cx += w
			var bad: int = diff(0, top, 320, f.height, func(x: int, y: int) -> int: return want[y * 320 + x])
			cx += start_x & 7    # px also moves on by its own bit offset, as the original's (and ax,7 / or ax,[bufferbit])
			var marked: bool = _marked_exactly(start_x, top, start_x + g.bufferwidth * 8 - 1, top + f.height - 1)
			t.ok("VWB_DrawPropString at x %d, colour %d: %d pixels differ, px advanced to %d (want %d), area marked %s"
				% [start_x, colour, bad, g.px, cx, marked], bad == 0 and g.px == cx and marked)
	# optsend: only the first four characters
	g.px = 10
	g.py = 170
	g.call(g.VW_DrawPropString, text, 4)
	t.ok("VW_DrawPropString up to optsend advances px by %d (want %d + 10 & 7)" % [g.px - 10, keen], g.px - 10 == keen + (10 & 7))


func _lines() -> void:
	g.call(g.VW_Bar, 0, 200, 80, 20, 0)
	g.call(g.VW_Plot, 5, 200, 9)
	g.call(g.VW_Hlin, 3, 50, 201, 12)
	g.call(g.VW_Hlin, 17, 21, 202, 4)    # within one byte
	g.call(g.VW_Vlin, 203, 210, 7, 6)
	g.call(g.VW_Bar, 13, 212, 30, 3, 14)
	var ok: bool = pixel(g.bufferofs, 5, 200) == 9 and pixel(g.bufferofs, 4, 200) == 0 and pixel(g.bufferofs, 6, 200) == 0
	for x: int in range(80):
		ok = ok and pixel(g.bufferofs, x, 201) == (12 if x >= 3 and x <= 50 else 0)
		ok = ok and pixel(g.bufferofs, x, 202) == (4 if x >= 17 and x <= 21 else 0)
		for y: int in range(212, 216):
			ok = ok and pixel(g.bufferofs, x, y) == (14 if x >= 13 and x < 43 and y < 215 else 0)
	for y: int in range(202, 212):
		ok = ok and pixel(g.bufferofs, 7, y) == (6 if y >= 203 and y <= 210 else 0)
	t.ok("VW_Plot, VW_Hlin, VW_Vlin, VW_Bar draw their pixels and no others", ok)


func _blocks() -> void:
	# a block to main memory and back elsewhere, and a copy within video memory
	var src: int = (g.bufferofs + g.ylookup[5] + 1) & 0xFFFF    # the last picture drawn
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(6 * 20 * 4)
	g.call(g.VW_ScreenToMem, src, buf, 6, 20)
	var dst: int = (g.bufferofs + g.ylookup[230] + 30) & 0xFFFF
	g.call(g.VW_MemToScreen, buf, dst, 6, 20)
	var dst2: int = (g.bufferofs + g.ylookup[260] + 40) & 0xFFFF
	g.call(g.VW_ScreenToScreen, src, dst2, 6, 20)
	var bad: int = 0
	var nonzero: int = 0
	for y: int in range(20):
		for x: int in range(48):
			var c: int = pixel(g.bufferofs, 8 + x, 5 + y)
			nonzero += int(c != 0)
			bad += int(pixel(g.bufferofs, 240 + x, 230 + y) != c) + int(pixel(g.bufferofs, 320 + x, 260 + y) != c)
	t.ok("VW_ScreenToMem / VW_MemToScreen / VW_ScreenToScreen copy a block (%d pixels differ, %d set)" % [bad, nonzero],
		bad == 0 and nonzero > 0)


func _update_screen() -> void:
	# the display page cleared, three blocks marked on the buffer page, then the update
	g.call(g.VW_Bar, 0, 0, 320, 200, 0)
	var keep: int = g.bufferofs
	g.bufferofs = g.displayofs
	g.call(g.VW_Bar, 0, 0, 336, 224, 0)
	g.bufferofs = keep
	g.call(g.VW_Bar, 0, 0, 336, 224, 3)
	_update_arrays()
	g.VW_MarkUpdateBlock(20, 20, 20, 20)            # a single tile
	g.VW_MarkUpdateBlock(64, 100, 64 + 47, 100)     # three in a row
	g.VW_MarkUpdateBlock(-40, 200, 10, 300)         # clipped to the bottom left
	var marked: PackedByteArray = g.update.slice(g.updateptr, g.updateptr + DrmDecl.UPDATEWIDE * DrmDecl.UPDATEHIGH)
	g.VW_UpdateScreen()
	var bad: int = 0
	var copied: int = 0
	for ty: int in range(DrmDecl.UPDATEHIGH):
		for tx: int in range(DrmDecl.UPDATEWIDE - 1):
			var want: int = 3 if marked[ty * DrmDecl.UPDATEWIDE + tx] else 0
			copied += int(want == 3)
			for y: int in range(0, 16, 5):
				for x: int in range(0, 16, 3):
					bad += int(pixel(g.displayofs, tx * 16 + x, ty * 16 + y) != want)
	var cleared: bool = true
	for i: int in range(DrmDecl.UPDATEWIDE * DrmDecl.UPDATEHIGH):
		cleared = cleared and g.update[g.updateptr + i] == 0
	t.ok("VW_UpdateScreen copies the %d marked tiles to the display page (%d pixels wrong), clears the marks %s, start address %d"
		% [copied, bad, cleared, g.vm.card.start_address()],
		copied == 1 + 3 + 2 and bad == 0 and cleared and g.vm.card.start_address() == g.displayofs + g.panadjust)

	# the cursor: drawn for the update, then taken off the buffer page again
	g.VW_SetCursor(DrmDecl.CURSORARROWSPR)
	g.VW_ShowCursor()
	g.VW_MoveCursor(100, 50)
	_clear_marks()
	g.VW_UpdateScreen()
	var s: Dictionary = d.sprite(DrmDecl.CURSORARROWSPR - DrmDecl.STARTSPRITES)
	var sx: int = 100 + (s.orgx >> 4)
	var sy: int = 50 + (s.orgy >> 4)
	@warning_ignore("integer_division")
	var shift: int = (sx & 7) / 2
	match int(s.shifts):
		4: sx = (sx & ~7) + 2 * shift
		2: sx = (sx & ~7) + (0 if shift < 2 else 4)
		_: sx = sx & ~7
	var on_display: int = 0
	var restored: bool = true
	for y: int in range(s.h):
		for x: int in range(s.w):
			var want: int = (3 if s.mask[y * s.w + x] else 0) | s.pixels[y * s.w + x]
			on_display += int(pixel(g.displayofs, sx + x, sy + y) == want)
			restored = restored and pixel(g.bufferofs, sx + x, sy + y) == 3
	g.VW_HideCursor()
	t.ok("the cursor shows on the display page (%d of %d pixels) and the buffer page is restored %s"
		% [on_display, s.w * s.h, restored], on_display == s.w * s.h and restored)


func _fades() -> void:
	var card: EgaCard = g.vm.card
	g.VW_ColorBorder(3)
	g.VW_SetDefaultColors()
	var ok: bool = card.atc[17] == 3 and not g.screenfaded
	for i: int in range(16):
		ok = ok and card.atc[i] == g.colors[3][i]
	t.ok("VW_ColorBorder / VW_SetDefaultColors set the palette and border", ok)
	var t0: int = g.vm.now
	g.VW_FadeOut()
	ok = g.screenfaded and card.atc[17] == 3
	for i: int in range(16):
		ok = ok and card.atc[i] == 0
	g.VW_FadeIn()
	ok = ok and not g.screenfaded
	for i: int in range(16):
		ok = ok and card.atc[i] == g.colors[3][i]
	t.ok("VW_FadeOut / VW_FadeIn step the palette, waiting on the retrace (time passes %s)" % (g.vm.now > t0), ok and g.vm.now > t0)
