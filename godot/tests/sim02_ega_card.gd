# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-02: the emulated EGA card. Golden pictures derived from the EGA
## specification: every expected pixel below is worked out by hand from the
## register semantics, never from the card. Then two properties: compose()
## against a one-pixel-at-a-time reading of the same memory and registers,
## and the block write against byte-by-byte writes, over random states.

var t: T = T.new()


func card() -> EgaCard:
	var c: EgaCard = EgaCard.new()
	c.bios_set_video_mode(EgaCard.MODE_EGA)
	return c


## The eight pixels of `picture` starting at (x, y).
static func eight(picture: PackedByteArray, x: int, y: int) -> Array:
	var out: Array = []
	for i: int in range(8):
		out.append(picture[y * 320 + x + i])
	return out


func reg(c: EgaCard, index_port: int, index: int, value: int) -> void:
	c.out16(index_port, index | (value << 8))


func _init() -> void:
	_mode_and_palette()
	_write_mode_0()
	_set_reset_and_bit_mask()
	_rotate_and_function()
	_write_mode_1()
	_write_mode_2()
	_write_mode_3()
	_read_modes()
	_panning()
	_start_and_pages()
	_line_width()
	_split_screen()
	_edges()
	_status_and_flipflop()
	_snapshot()
	_compose_property()
	_block_write_property()
	t.finish(self)


func _mode_and_palette() -> void:
	var c: EgaCard = card()
	var pic: PackedByteArray = c.compose()
	t.eq("mode 0Dh: a fresh picture is 64000 pixels", pic.size(), 64000)
	t.ok("mode 0Dh: a fresh picture is all colour 0", pic.count(0) == 64000)
	var pal: PackedByteArray = c.palette_rgb()
	# The BIOS arrangement 0-7, 10h-17h through DOSBox's cga64 table gives
	# the sixteen CGA colours, with brown (not dark yellow) at 6.
	var want: Array = [[0, 0, 0], [0, 0, 170], [0, 170, 0], [0, 170, 170], [170, 0, 0], [170, 0, 170], [170, 85, 0], [170, 170, 170],
		[85, 85, 85], [85, 85, 255], [85, 255, 85], [85, 255, 255], [255, 85, 85], [255, 85, 255], [255, 255, 85], [255, 255, 255]]
	var same: bool = true
	for i: int in range(16):
		for k: int in range(3):
			if pal[i * 3 + k] != want[i][k]:
				same = false
	t.ok("mode 0Dh: the sixteen default colours are the CGA set (brown at 6, bright 8-15)", same)
	# Keen's own palette: 0-7 then 18h-1Fh and border 3. In cga64 bit 4 is
	# intensity and bit 3 is ignored, so 18h-1Fh are the bright eight again.
	c.bios_set_palette(PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 3]))
	pal = c.palette_rgb()
	t.ok("Keen's 17-byte palette through INT 10h gives the same sixteen colours", pal == PackedByteArray(_flat(want)))
	t.ok("the border is cyan", c.border_rgb() == PackedByteArray([0, 170, 170]))
	# A palette register write through the attribute controller: 1Ch is
	# bright red; the flip-flop takes index then data.
	c.in8(EgaCard.STATUS_1)
	c.out8(EgaCard.ATR_INDEX, 3 | 0x20)
	c.out8(EgaCard.ATR_INDEX, 0x1C)
	pal = c.palette_rgb()
	t.ok("attribute register 3 := 1Ch shows bright red", pal[9] == 255 and pal[10] == 85 and pal[11] == 85)
	# 14h (which an EGA would call brown) is bright red too in this mode on a VGA.
	c.bios_set_palette_register(6, 0x14)
	pal = c.palette_rgb()
	t.ok("14h is bright red in mode 0Dh on a VGA (bit 4 intensity, bit 3 ignored)", pal[18] == 255 and pal[19] == 85 and pal[20] == 85)
	# Six-bit to eight-bit scaling: 2Ah -> 170, 15h -> 85, 3Fh -> 255.
	c.out8(EgaCard.DAC_WRITE_INDEX, 7)
	for v: int in [0x2A, 0x15, 0x3F]:
		c.out8(EgaCard.DAC_DATA, v)
	pal = c.palette_rgb()
	t.ok("DAC entry 7 := (2Ah, 15h, 3Fh) reads (170, 85, 255)", pal[21] == 170 and pal[22] == 85 and pal[23] == 255)
	c.bios_set_video_mode(EgaCard.MODE_TEXT)
	t.ok("the text mode composes a blank picture", c.compose().count(0) == 64000)


static func _flat(rows: Array) -> Array:
	var out: Array = []
	for r: Array in rows:
		out.append_array(r)
	return out


func _write_mode_0() -> void:
	var c: EgaCard = card()
	# Map mask 5 (planes 0 and 2): A5h = 1010 0101 lands in both planes, so the
	# set pixels are colour 5 and the rest colour 0.
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 5)
	c.mem_write(0, 0xA5)
	t.eq("write mode 0, map mask 5, A5h at 0", eight(c.compose(), 0, 0), [5, 0, 5, 0, 0, 5, 0, 5])
	# A plain write with all planes on puts the same bits in every plane: colour 15.
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 15)
	c.mem_write(1, 0xC0)
	t.eq("write mode 0, all planes, C0h at 1", eight(c.compose(), 8, 0), [15, 15, 0, 0, 0, 0, 0, 0])
	# A read sets the latches; the bit mask then takes unmasked bits from them.
	c.mem_read(0)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_BITMASK, 0xF0)
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1)
	c.mem_write(0, 0x00)
	# Plane 0 at 0 was A5h; the high nibble is cleared, the low kept: 05h.
	# Plane 2 keeps A5h. Pixels 0-3: plane 2 only where set (colour 4); 4-7: both planes.
	t.eq("bit mask F0h keeps the latched low nibble", eight(c.compose(), 0, 0), [4, 0, 4, 0, 0, 5, 0, 5])


func _set_reset_and_bit_mask() -> void:
	var c: EgaCard = card()
	# Enable set/reset on every plane with colour 9: the written value is ignored.
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_SETRESET, 9)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_ENABLESETRESET, 0x0F)
	c.mem_write(40, 0x37)
	t.eq("set/reset 9 on all planes fills eight pixels with 9", eight(c.compose(), 0, 1), [9, 9, 9, 9, 9, 9, 9, 9])
	# Latch that byte, then write colour 6 through bit mask 0Fh: the right four
	# pixels change, the left four come back from the latches.
	c.mem_read(40)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_SETRESET, 6)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_BITMASK, 0x0F)
	c.mem_write(40, 0)
	t.eq("set/reset 6 through bit mask 0Fh over latched 9", eight(c.compose(), 0, 1), [9, 9, 9, 9, 6, 6, 6, 6])
	# Enable set/reset on planes 0 and 1 only: those take the colour, planes
	# 2 and 3 take the data byte (FFh), so every pixel has bits 2 and 3 set.
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_BITMASK, 0xFF)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_ENABLESETRESET, 0x03)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_SETRESET, 0x02)
	c.mem_write(80, 0xFF)
	t.eq("set/reset on two planes, data on the others", eight(c.compose(), 0, 2), [14, 14, 14, 14, 14, 14, 14, 14])


func _rotate_and_function() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1)
	c.mem_write(120, 0x0F)
	c.mem_read(120)
	# Rotate right by 1 and OR with the latches: 01h -> 80h, OR 0Fh = 8Fh.
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_DATAROTATE, 1 | (2 << 3))
	c.mem_write(120, 0x01)
	t.eq("rotate 1, OR with latch: 01h over 0Fh gives 8Fh", eight(c.compose(), 0, 3), [1, 0, 0, 0, 1, 1, 1, 1])
	# AND: 3Ch & 8Fh = 0Ch.
	c.mem_read(120)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_DATAROTATE, 0 | (1 << 3))
	c.mem_write(120, 0x3C)
	t.eq("AND with latch: 3Ch & 8Fh = 0Ch", eight(c.compose(), 0, 3), [0, 0, 0, 0, 1, 1, 0, 0])
	# XOR: FFh ^ 0Ch = F3h.
	c.mem_read(120)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_DATAROTATE, 0 | (3 << 3))
	c.mem_write(120, 0xFF)
	t.eq("XOR with latch: FFh ^ 0Ch = F3h", eight(c.compose(), 0, 3), [1, 1, 1, 1, 0, 0, 1, 1])


func _write_mode_1() -> void:
	var c: EgaCard = card()
	# Four different bytes in the four planes at 0, copied to row 5 through the
	# latches: the picture there must be the same eight colours.
	for p: int in range(4):
		reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1 << p)
		c.mem_write(0, [0xA5, 0x3C, 0xF0, 0x81][p])
	var top: Array = eight(c.compose(), 0, 0)
	t.eq("four planes merge into the expected colours", top, [13, 4, 7, 6, 2, 3, 0, 9])
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 15)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_MODE, 1)
	c.mem_read(0)
	c.mem_write(200, 0x00)
	t.eq("write mode 1 copies all four latched planes", eight(c.compose(), 0, 5), top)
	# With map mask 1 only plane 0 is written.
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1)
	c.mem_write(240, 0x00)
	t.eq("write mode 1 with map mask 1 copies plane 0 only", eight(c.compose(), 0, 6), [1, 0, 1, 0, 0, 1, 0, 1])


func _write_mode_2() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_MODE, 2)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_BITMASK, 0x3C)
	c.mem_read(280)
	c.mem_write(280, 0x0B)
	t.eq("write mode 2: colour 0Bh through bit mask 3Ch", eight(c.compose(), 0, 7), [0, 0, 11, 11, 11, 11, 0, 0])
	# The latches supply the masked-off pixels: draw colour 4 over them with mask C3h.
	c.mem_read(280)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_BITMASK, 0xC3)
	c.mem_write(280, 0x04)
	t.eq("write mode 2 keeps latched pixels outside the mask", eight(c.compose(), 0, 7), [4, 4, 11, 11, 11, 11, 4, 4])


func _write_mode_3() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_MODE, 3)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_SETRESET, 7)
	c.mem_read(320)
	c.mem_write(320, 0x81)
	t.eq("write mode 3: data 81h selects the pixels that take set/reset 7", eight(c.compose(), 0, 8), [7, 0, 0, 0, 0, 0, 0, 7])


func _read_modes() -> void:
	var c: EgaCard = card()
	for p: int in range(4):
		reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1 << p)
		c.mem_write(0, [0xA5, 0x3C, 0xF0, 0x81][p])
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_READMAP, 2)
	t.eq("read mode 0 selects plane 2", c.mem_read(0), 0xF0)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_READMAP, 1)
	t.eq("read mode 0 selects plane 1", c.mem_read(0), 0x3C)
	# Read mode 1: pixels are 13, 4, 7, 6, 2, 3, 0, 9 (see write mode 1).
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_MODE, 0x08)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_COLORCOMPARE, 6)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_COLORDONTCARE, 0x0F)
	t.eq("read mode 1: pixels equal to colour 6", c.mem_read(0), 0b00010000)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_COLORCOMPARE, 4)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_COLORDONTCARE, 0x04)
	t.eq("read mode 1: only plane 2 compared, bit set -> pixels with bit 2", c.mem_read(0), 0b11110000)
	reg(c, EgaCard.GC_INDEX, EgaCard.GC_COLORDONTCARE, 0x00)
	t.eq("read mode 1: nothing compared -> all ones", c.mem_read(0), 0xFF)


func _panning() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1)
	# Row 10: colour 1 at x = 0 and x = 8; row 11's first byte has pixel 2 set,
	# which panning drags onto row 10's right edge.
	c.mem_write(400, 0x80)
	c.mem_write(401, 0x80)
	c.mem_write(440, 0x20)
	c.in8(EgaCard.STATUS_1)
	c.out8(EgaCard.ATR_INDEX, EgaCard.ATR_PELPAN | 0x20)
	c.out8(EgaCard.ATR_INDEX, 3)
	var pic: PackedByteArray = c.compose()
	t.ok("pel pan 3: the pixel at x = 8 shows at x = 5", pic[10 * 320 + 5] == 1 and pic[10 * 320 + 8] == 0 and pic[10 * 320 + 0] == 0)
	t.ok("pel pan 3: the right edge shows the next row's bytes", pic[10 * 320 + 319] == 1)
	t.ok("pel pan 3: row 9's right edge shows row 10's first pixel at x = 317", pic[9 * 320 + 317] == 1)
	t.ok("pel pan 3: row 11's own pixel at x = 2 is panned off the left edge", pic[11 * 320 + 2] == 0)
	var count: int = 0
	for v: int in pic:
		count += v
	t.eq("pel pan 3: nothing else lit", count, 3)


func _start_and_pages() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 2)
	c.mem_write(80, 0xFF)          # memory row 2
	c.mem_write(0x2000, 0xFF)      # page 1, row 0
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTHIGH, 0)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTLOW, 80)
	t.eq("CRTC start 80 shows memory row 2 as row 0", eight(c.compose(), 0, 0), [2, 2, 2, 2, 2, 2, 2, 2])
	c.bios_set_active_page(1)
	t.eq("BIOS page 1 is start address 2000h", c.start_address(), 0x2000)
	var pic: PackedByteArray = c.compose()
	t.eq("page 1 shows its own memory", eight(pic, 0, 0), [2, 2, 2, 2, 2, 2, 2, 2])
	t.ok("page 1 does not show page 0's row 2", eight(pic, 0, 2) == [0, 0, 0, 0, 0, 0, 0, 0])


func _line_width() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 4)
	c.mem_write(42, 0xFF)
	t.eq("line width 40: byte 42 is row 1, x 16-23", eight(c.compose(), 16, 1), [4, 4, 4, 4, 4, 4, 4, 4])
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_OFFSET, 21)
	t.eq("line width 42 (CRTC offset 21): byte 42 is row 1, x 0-7", eight(c.compose(), 0, 1), [4, 4, 4, 4, 4, 4, 4, 4])
	t.ok("line width 42: x 16-23 of row 1 is clear", eight(c.compose(), 16, 1) == [0, 0, 0, 0, 0, 0, 0, 0])


func _split_screen() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 8)
	c.mem_write(0, 0xFF)           # address 0: what the bottom half shows
	c.mem_write(0x2000, 0xFF)      # page 1 row 0
	c.mem_write(0x2000 + 100 * 40, 0xFF)   # page 1 row 100
	c.bios_set_active_page(1)
	# Line compare for picture row 100: the VGA double-scans, so 200.
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_LINECOMPARE, 200)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_OVERFLOW, 0x01)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_MAXSCANLINE, 0x01)
	var pic: PackedByteArray = c.compose()
	t.eq("split at row 100: row 0 is page 1's row 0", eight(pic, 0, 0), [8, 8, 8, 8, 8, 8, 8, 8])
	t.eq("split at row 100: row 100 is memory row 0 (address 0)", eight(pic, 0, 100), [8, 8, 8, 8, 8, 8, 8, 8])
	t.eq("split at row 100: row 101 is memory row 1", eight(pic, 0, 101), [0, 0, 0, 0, 0, 0, 0, 0])
	t.eq("split row from the registers", c.split_row(), 100)
	# Line compare bits 8 and 9 live in the overflow and max-scan-line registers.
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_LINECOMPARE, 0x90)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_OVERFLOW, 0x11)
	t.eq("line compare 190h (bit 8 in overflow) splits at row 200: no split", c.split_row(), 200)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_LINECOMPARE, 20)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_OVERFLOW, 0x01)
	t.eq("line compare 20 splits at row 10", c.split_row(), 10)
	# Panning below the split: dropped when the compatibility bit is set.
	c.in8(EgaCard.STATUS_1)
	c.out8(EgaCard.ATR_INDEX, EgaCard.ATR_PELPAN | 0x20)
	c.out8(EgaCard.ATR_INDEX, 2)
	pic = c.compose()
	t.ok("below the split the pan still applies with the compatibility bit clear", pic[10 * 320 + 5] == 8 and pic[10 * 320 + 7] == 0)
	c.in8(EgaCard.STATUS_1)
	c.out8(EgaCard.ATR_INDEX, EgaCard.ATR_MODE | 0x20)
	c.out8(EgaCard.ATR_INDEX, 0x21)
	pic = c.compose()
	t.ok("below the split the pan is dropped with the compatibility bit set, above it stays", pic[10 * 320 + 7] == 8 and pic[0] == 8 and pic[6] == 0)


func _edges() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1)
	c.mem_write(0xFFFF, 0xFF)
	c.mem_write(0x10000, 0xFF)
	t.eq("a read past 64 KiB gives FFh", c.mem_read(0x10000), 0xFF)
	t.eq("a write past 64 KiB goes nowhere", c.mem_read(0xFFFF), 0xFF)
	t.eq("address 0 untouched by the write past the end", c.mem_read(0), 0)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTHIGH, 0xFF)
	reg(c, EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTLOW, 0xF8)
	c.mem_write(0, 0xFF)
	var pic: PackedByteArray = c.compose()
	t.ok("the picture wraps round the 64 KiB window", eight(pic, 56, 0) == [1, 1, 1, 1, 1, 1, 1, 1] and eight(pic, 64, 0) == [1, 1, 1, 1, 1, 1, 1, 1])


func _status_and_flipflop() -> void:
	var c: EgaCard = card()
	# A routine waits while retrace is on, then until it is on again.
	var reads: int = 0
	while (c.in8(EgaCard.STATUS_1) & 8) != 0 and reads < 10:
		reads += 1
	while (c.in8(EgaCard.STATUS_1) & 8) == 0 and reads < 10:
		reads += 1
	t.ok("retrace wait loops end", reads < 10)
	# A status read resets the attribute flip-flop: the next write is an index.
	c.out8(EgaCard.ATR_INDEX, 5 | 0x20)
	c.in8(EgaCard.STATUS_1)
	c.out8(EgaCard.ATR_INDEX, 2 | 0x20)
	c.out8(EgaCard.ATR_INDEX, 0x3F)
	t.eq("after a status read the next ATC write is an index", c.atc[2], 0x3F)
	t.eq("the interrupted write did not land", c.atc[5], 5)


func _snapshot() -> void:
	var c: EgaCard = card()
	reg(c, EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 3)
	c.mem_write(0x4000 + 123, 0x5A)
	c.mem_read(0x4000 + 123)
	c.bios_set_active_page(2)
	var before: PackedByteArray = c.compose()
	var s: Dictionary = c.snapshot()
	var d: EgaCard = card()
	d.restore(s)
	c.mem_write(0x4000 + 123, 0xFF)
	t.ok("a restored card composes the snapshot's picture", d.compose() == before and c.compose() != before)
	t.eq("a restored card keeps the latches", d.latch1, 0x5A)
	t.eq("a restored card keeps the start address", d.start_address(), 0x4000)
	t.ok("the restore is a copy, not a view", d.mem_read(0x4000 + 123) == 0x5A and c.mem_read(0x4000 + 123) == 0xFF)


## compose() read one pixel at a time from the registers' meaning.
static func reference_compose(c: EgaCard) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(64000)
	var stride: int = c.crtc[EgaCard.CRTC_OFFSET] * 2
	var pan: int = c.atc[EgaCard.ATR_PELPAN] & 7
	var compare: int = c.crtc[EgaCard.CRTC_LINECOMPARE] | ((c.crtc[EgaCard.CRTC_OVERFLOW] & 0x10) << 4) | ((c.crtc[EgaCard.CRTC_MAXSCANLINE] & 0x40) << 3)
	var split: int = (compare + 1) / 2
	var start: int = (c.crtc[EgaCard.CRTC_STARTHIGH] << 8) | c.crtc[EgaCard.CRTC_STARTLOW]
	for y: int in range(200):
		var row_start: int
		var row_pan: int = pan
		if y >= split:
			row_start = (y - split) * stride
			if c.atc[EgaCard.ATR_MODE] & 0x20:
				row_pan = 0
		else:
			row_start = start + y * stride
		for x: int in range(320):
			var bit: int = x + row_pan
			var a: int = (row_start + (bit >> 3)) & 0xFFFF
			var sh: int = 7 - (bit & 7)
			out[y * 320 + x] = ((c.plane0[a] >> sh) & 1) | (((c.plane1[a] >> sh) & 1) << 1) \
					| (((c.plane2[a] >> sh) & 1) << 2) | (((c.plane3[a] >> sh) & 1) << 3)
	return out


func _compose_property() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261006
	var all_same: bool = true
	var cases: int = 6
	for k: int in range(cases):
		var c: EgaCard = card()
		for p: int in range(4):
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(0x10000)
			for i: int in range(0x10000):
				bytes[i] = rng.randi() & 0xFF
			match p:
				0: c.plane0 = bytes
				1: c.plane1 = bytes
				2: c.plane2 = bytes
				3: c.plane3 = bytes
		var start: int = rng.randi() & 0xFFFF
		c.crtc[EgaCard.CRTC_STARTHIGH] = start >> 8
		c.crtc[EgaCard.CRTC_STARTLOW] = start & 0xFF
		c.crtc[EgaCard.CRTC_OFFSET] = [20, 21, 22, 32][rng.randi() & 3]
		c.atc[EgaCard.ATR_PELPAN] = rng.randi() & 7
		var compare: int = rng.randi() % 1024
		c.crtc[EgaCard.CRTC_LINECOMPARE] = compare & 0xFF
		c.crtc[EgaCard.CRTC_OVERFLOW] = (compare >> 4) & 0x10
		c.crtc[EgaCard.CRTC_MAXSCANLINE] = (compare >> 3) & 0x40
		c.atc[EgaCard.ATR_MODE] = 0x01 | (0x20 if (rng.randi() & 1) else 0)
		if c.compose() != reference_compose(c):
			all_same = false
			print("  compose differs: start %04x stride %d pan %d compare %d mode %02x" %
				[start, c.crtc[EgaCard.CRTC_OFFSET] * 2, c.atc[EgaCard.ATR_PELPAN], compare, c.atc[EgaCard.ATR_MODE]])
	t.ok("compose() equals the one-pixel-at-a-time reading over %d random states" % cases, all_same)


func _block_write_property() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var all_same: bool = true
	for k: int in range(40):
		var a: EgaCard = card()
		var b: EgaCard = card()
		for p: int in range(4):
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(0x10000)
			for i: int in range(0, 0x10000, 97):
				bytes[i] = rng.randi() & 0xFF
			match p:
				0:
					a.plane0 = bytes
					b.plane0 = bytes.duplicate()
				1:
					a.plane1 = bytes
					b.plane1 = bytes.duplicate()
				2:
					a.plane2 = bytes
					b.plane2 = bytes.duplicate()
				3:
					a.plane3 = bytes
					b.plane3 = bytes.duplicate()
		var regs: Array = [
			[EgaCard.SC_INDEX, EgaCard.SC_MAPMASK, 1 << (rng.randi() & 3) if (rng.randi() & 1) else rng.randi() & 15],
			[EgaCard.GC_INDEX, EgaCard.GC_MODE, rng.randi() & 3 if (rng.randi() & 3) != 0 else 0],
			[EgaCard.GC_INDEX, EgaCard.GC_DATAROTATE, rng.randi() & 0x1F if (rng.randi() & 3) == 0 else 0],
			[EgaCard.GC_INDEX, EgaCard.GC_ENABLESETRESET, rng.randi() & 15 if (rng.randi() & 3) == 0 else 0],
			[EgaCard.GC_INDEX, EgaCard.GC_SETRESET, rng.randi() & 15],
			[EgaCard.GC_INDEX, EgaCard.GC_BITMASK, rng.randi() & 0xFF if (rng.randi() & 3) == 0 else 0xFF],
		]
		for r: Array in regs:
			a.out16(r[0], r[1] | (r[2] << 8))
			b.out16(r[0], r[1] | (r[2] << 8))
		var address: int = rng.randi() & 0xFFFF
		var data: PackedByteArray = PackedByteArray()
		for i: int in range(rng.randi() % 300):
			data.append(rng.randi() & 0xFF)
		a.mem_read(address)
		b.mem_read(address)
		a.mem_write_block(address, data)
		for i: int in range(data.size()):
			b.mem_write(address + i, data[i])
		if a.plane0 != b.plane0 or a.plane1 != b.plane1 or a.plane2 != b.plane2 or a.plane3 != b.plane3:
			all_same = false
	t.ok("mem_write_block equals byte-by-byte writes over 40 random register states", all_same)
