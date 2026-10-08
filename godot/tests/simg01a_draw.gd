# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-G-01a: the Galaxy library layer draws what the data says. Every 16x16
## tile (masked and unmasked), every bitmap and masked bitmap, every sprite at
## each of its pixel shifts and a font string, drawn through GalLib onto its
## screen surface, read back pixel for pixel as GalData's own decode of the same
## chunk predicts; VL_Present puts the window at the scroll position onto the
## emulated card, and a fade reaches the card's palette registers.
##
## Options: --game_data=<folder>  --games=keen4,keen5,keen6

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const BG: int = 5     # a background colour no test image is expected to need


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	for game: String in str(opts.get("games", "keen4")).split(",", false):
		_game(t, root, game)
	t.finish(self)


func _game(t: T, root: String, game: String) -> void:
	var d: GalData = GalData.new()
	if not t.ok("%s: files load (%s)" % [game, d.error], d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalLib = GalLib.new()
	g.vm = vm
	g.data = d
	g.CA_Startup()
	g.VL_Startup()
	var gfx: Dictionary = d.gfx
	var scr: GalLib.VL_Surface = g.vl_screen
	t.ok("%s: the screen surface is the RF buffer (%dx%d)" % [game, scr.w, scr.h], scr.w == 336 and scr.h == 224)

	# 16x16 tiles
	var tiles: PackedByteArray = d.tiles16()
	var bad: int = 0
	for i: int in range(gfx.numTiles16):
		if g.ca_graphChunks.size() > gfx.offTiles16 + i and d.chunk_start(gfx.offTiles16 + i) == -1:
			continue
		g.VL_ScreenRect(0, 0, 32, 32, BG)
		g.VH_DrawTile16(16, 8, i)
		for y: int in range(16):
			for x: int in range(16):
				if scr.pixels[(8 + y) * scr.w + 16 + x] != tiles[i * 256 + y * 16 + x]:
					bad += 1
	t.ok("%s: every 16x16 tile draws as decoded (%d pixels differ)" % [game, bad], bad == 0)

	# masked 16x16 tiles over a background
	var tm: Dictionary = d.tiles16m()
	bad = 0
	var drawn: int = 0
	for i: int in range(gfx.numTiles16m):
		if g.ca_graphChunks[gfx.offTiles16m + i] == null:
			g.CA_CacheGrChunk(gfx.offTiles16m + i)
		if g.ca_graphChunks[gfx.offTiles16m + i] == null:
			continue
		drawn += 1
		g.VL_ScreenRect(0, 0, 48, 32, BG)
		g.VH_DrawTile16M(24, 8, i)
		for y: int in range(16):
			for x: int in range(16):
				var k: int = i * 256 + y * 16 + x
				var want: int = tm.pixels[k] if tm.mask[k] == 0 else (BG | tm.pixels[k])
				if scr.pixels[(8 + y) * scr.w + 24 + x] != want:
					bad += 1
	t.ok("%s: every masked 16x16 tile draws over the background as decoded (%d tiles, %d pixels differ)" % [game, drawn, bad], bad == 0 and drawn > 0)

	# bitmaps and masked bitmaps
	bad = 0
	for i: int in range(gfx.numBitmaps):
		var b: Dictionary = d.bitmap(i)
		if b.w > scr.w or b.h > scr.h:
			continue
		g.VH_DrawBitmap(0, 0, gfx.offBitmaps + i)
		for y: int in range(b.h):
			for x: int in range(b.w):
				if scr.pixels[y * scr.w + x] != b.pixels[y * b.w + x]:
					bad += 1
	t.ok("%s: every bitmap draws as decoded (%d bitmaps, %d pixels differ)" % [game, gfx.numBitmaps, bad], bad == 0)
	bad = 0
	for i: int in range(gfx.numMasked):
		var m: Dictionary = d.masked_bitmap(i)
		if m.w > scr.w or m.h > scr.h:
			continue
		g.VL_ScreenRect(0, 0, scr.w, scr.h, BG)
		g.VH_DrawMaskedBitmap(0, 0, gfx.offMasked + i)
		for y: int in range(m.h):
			for x: int in range(m.w):
				var k: int = y * m.w + x
				var want: int = m.pixels[k] if m.mask[k] == 0 else (BG | m.pixels[k])
				if scr.pixels[y * scr.w + x] != want:
					bad += 1
	t.ok("%s: every masked bitmap draws over the background as decoded (%d, %d pixels differ)" % [game, gfx.numMasked, bad], bad == 0)

	# sprites at every pixel offset 0-7: the shift used is (x & 7) / 2 of the
	# sprite's 1, 2 or 4 pre-shifted copies, drawn from x & ~7
	bad = 0
	var tested: int = 0
	for i: int in range(gfx.numSprites):
		var s: Dictionary = d.sprite(i)
		if s.is_empty() or s.w + 8 > scr.w or s.h > scr.h:
			continue
		tested += 1
		for px: int in range(8):
			var shift: int = px / 2
			var offset: int = 0
			match int(s.shifts):
				4:
					offset = shift * 2
				2:
					offset = 4 if shift >= 2 else 0
			g.VL_ScreenRect(0, 0, s.w + 16, s.h, BG)
			g.VH_DrawSprite(px, 0, gfx.offSprites + i)
			for y: int in range(s.h):
				for x: int in range(s.w + 8):
					var sx: int = x - offset
					var want: int = BG
					if sx >= 0 and sx < s.w:
						var k: int = y * s.w + sx
						want = s.pixels[k] if s.mask[k] == 0 else (BG | s.pixels[k])
					if scr.pixels[y * scr.w + x] != want:
						bad += 1
	t.ok("%s: every sprite draws at all eight pixel offsets with its pre-shifted copies (%d sprites, %d pixels differ)" % [game, tested, bad], bad == 0 and tested > 100)

	# a font string, XORed in colour 15 onto black
	var font_chunk: int = d.chunk_names.get_int("FON_MAINFONT")
	var f: Dictionary = d.font(font_chunk)
	var text: String = "Commander Keen 0123!?"
	g.VL_ScreenRect(0, 0, scr.w, 40, 0)
	# the font routines take the font's number; CA_GetGrChunk(font, 3) is its chunk
	g.VH_DrawPropString(text, 4, 6, font_chunk - 3, 15)
	bad = 0
	var pen: int = 4
	for ci: int in range(text.length()):
		var c: int = text.unicode_at(ci)
		var w: int = f.widths[c]
		var glyph: PackedByteArray = f.glyphs[c]
		for y: int in range(f.height):
			for x: int in range(w):
				var want: int = 15 if glyph[y * w + x] != 0 else 0
				if scr.pixels[(6 + y) * scr.w + pen + x] != want:
					bad += 1
		pen += w
	var wh: PackedInt32Array = g.VH_MeasurePropString(text, font_chunk - 3)
	t.ok("%s: a string in the main font draws glyph for glyph and measures %d wide (%d pixels differ)" % [game, wh[0], bad], bad == 0 and wh[0] == pen - 4)

	# present: the window at the scroll position reaches the card
	for y: int in range(scr.h):
		for x: int in range(scr.w):
			scr.pixels[y * scr.w + x] = (x / 7 + y / 5) & 15
	g.VL_SetScrollCoords(9, 13)
	g.VL_Present()
	vm.card.latch_start()
	var pic: PackedByteArray = vm.card.compose()
	bad = 0
	for y: int in range(200):
		for x: int in range(320):
			if pic[y * 320 + x] != scr.pixels[(y + 13) * scr.w + x + 9]:
				bad += 1
	t.ok("%s: VL_Present shows the 320x200 window at the scroll position (9,13) on the card (%d pixels differ)" % [game, bad], bad == 0)

	# a fade to black reaches the palette registers, one step every six refreshes (the present waits for a retrace; the delay's first tic ends it)
	var start: int = vm.vbl_count
	g.VL_FadeToBlack()
	var regs: PackedByteArray = vm.card.atc.slice(0, 16)
	t.ok("%s: VL_FadeToBlack leaves every palette register black after four steps of six refreshes, each present sharing its retrace with the first tic (%s, %d refreshes)" %
		[game, regs, vm.vbl_count - start], regs == PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) and vm.vbl_count - start >= 23 and vm.vbl_count - start <= 25 and g.vl_screenFaded)
	g.VL_FadeFromBlack()
	regs = vm.card.atc.slice(0, 16)
	t.ok("%s: VL_FadeFromBlack ends on the default palette" % game, regs == PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 24, 25, 26, 27, 28, 29, 30, 31]))
	t.ok("%s: no quit (%s)" % [game, g.quit_message], not g.quitting)
