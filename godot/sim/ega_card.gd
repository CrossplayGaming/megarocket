# Copyright (C) 2026 the Megarocket contributors; the write-mode, read-mode and
# plane-merging logic is adapted from the Sidescroller Recomps project's
# D2Hardware (Copyright (C) 2026 its contributors). GPL v2 or later. See LICENSE.md.
#
# References: IBM Enhanced Graphics Adapter technical reference (sequencer,
# graphics controller, attribute controller and CRT controller registers);
# DOSBox Staging 0.80.1 int10_modes.cpp for what the BIOS loads for mode 0Dh
# on a VGA (the oracle's machine): the 64-entry "cga64" DAC table, in which
# bit 4 of a palette value is intensity and bits 0-2 the colour, and the
# attribute registers 0-7, 10h-17h.
class_name EgaCard
extends RefCounted
## The one emulated EGA card every engine draws through (ledger A3): four
## 64 KiB planes, the latches, the sequencer's map mask, the graphics
## controller (set/reset, enable set/reset, colour compare, data rotate and
## function select, read map select, mode, colour don't care, bit mask), write
## modes 0-3 and read modes 0-1, the attribute controller's palette and pel
## panning, the CRT controller's start address, line width and line compare,
## and the VGA DAC the BIOS loads for the mode. compose() is the picture on
## the monitor: palette indices, 320x200; palette_rgb() their colours.
##
## Nothing here knows about Godot's renderer, the clock, sound or keys. Those
## are other devices.

const PLANE_SIZE: int = 0x10000
const WIDTH: int = 320
const HEIGHT: int = 200
const PAGE_SIZE: int = 0x2000     # the BIOS's page size for mode 0Dh
const MODE_EGA: int = 0x0D
const MODE_TEXT: int = 0x03

# Port numbers.
const SC_INDEX: int = 0x3C4
const SC_DATA: int = 0x3C5
const GC_INDEX: int = 0x3CE
const GC_DATA: int = 0x3CF
const ATR_INDEX: int = 0x3C0
const ATR_READ: int = 0x3C1
const DAC_WRITE_INDEX: int = 0x3C8
const DAC_DATA: int = 0x3C9
const CRTC_INDEX: int = 0x3D4
const CRTC_DATA: int = 0x3D5
const STATUS_1: int = 0x3DA

# Register numbers the engines use by name.
const SC_MAPMASK: int = 2
const GC_SETRESET: int = 0
const GC_ENABLESETRESET: int = 1
const GC_COLORCOMPARE: int = 2
const GC_DATAROTATE: int = 3
const GC_READMAP: int = 4
const GC_MODE: int = 5
const GC_COLORDONTCARE: int = 7
const GC_BITMASK: int = 8
const ATR_MODE: int = 0x10
const ATR_OVERSCAN: int = 0x11
const ATR_PELPAN: int = 0x13
const CRTC_OVERFLOW: int = 7
const CRTC_MAXSCANLINE: int = 9
const CRTC_STARTHIGH: int = 0x0C
const CRTC_STARTLOW: int = 0x0D
const CRTC_OFFSET: int = 0x13
const CRTC_LINECOMPARE: int = 0x18

var plane0: PackedByteArray = PackedByteArray()
var plane1: PackedByteArray = PackedByteArray()
var plane2: PackedByteArray = PackedByteArray()
var plane3: PackedByteArray = PackedByteArray()
var latch0: int = 0
var latch1: int = 0
var latch2: int = 0
var latch3: int = 0

var seq_index: int = 0
var map_mask: int = 0x0F
var gc_index: int = 0
var gc: PackedByteArray = PackedByteArray()      # graphics controller 0..8
var atc_index: int = 0
var atc_expect_data: bool = false
var atc: PackedByteArray = PackedByteArray()     # attribute controller 0..0x14
var crtc_index: int = 0
var crtc: PackedByteArray = PackedByteArray()    # CRT controller 0..0x18
var dac: PackedByteArray = PackedByteArray()     # 256 entries x 3, six bits each
var dac_write_index: int = 0
var dac_component: int = 0
var video_mode: int = MODE_TEXT
## Every port write and memory access, counted: the machine charges them
## the processor time the original spent on them.
var accesses: int = 0
## Reads of the status register alternate the vertical-retrace bit, so a
## routine that waits for retrace, or for its end, returns on the next read.
var _status_reads: int = 0

# Byte -> the same eight bits spread over eight bytes, most significant bit in
# the lowest byte, so that four planes merge into eight pixel values with
# three shifts.
static var _spread: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	plane0.resize(PLANE_SIZE)
	plane1.resize(PLANE_SIZE)
	plane2.resize(PLANE_SIZE)
	plane3.resize(PLANE_SIZE)
	gc.resize(9)
	atc.resize(0x15)
	crtc.resize(0x19)
	dac.resize(256 * 3)
	if _spread.is_empty():
		_spread.resize(256)
		for value: int in range(256):
			var wide: int = 0
			for i: int in range(8):
				wide |= ((value >> (7 - i)) & 1) << (8 * i)
			_spread[value] = wide
	bios_set_video_mode(MODE_TEXT)


# -- BIOS video services (INT 10h) -------------------------------------------------

## AH = 00h: set video mode. Clears video memory and loads the registers and
## the DAC the way the VGA BIOS does for the mode.
func bios_set_video_mode(mode: int) -> void:
	video_mode = mode & 0x7F
	plane0.fill(0)
	plane1.fill(0)
	plane2.fill(0)
	plane3.fill(0)
	latch0 = 0
	latch1 = 0
	latch2 = 0
	latch3 = 0
	seq_index = 0
	map_mask = 0x0F
	gc_index = 0
	gc.fill(0)
	gc[GC_MODE] = 0
	gc[6] = 0x05
	gc[GC_COLORDONTCARE] = 0x0F
	gc[GC_BITMASK] = 0xFF
	atc_index = 0
	atc_expect_data = false
	atc.fill(0)
	for i: int in range(8):
		atc[i] = i
		atc[i + 8] = i + 0x10
	atc[ATR_MODE] = 0x01
	atc[0x12] = 0x0F
	crtc_index = 0
	crtc.fill(0)
	crtc[CRTC_OFFSET] = 20          # 40 bytes per row
	crtc[CRTC_LINECOMPARE] = 0xFF   # no split: line compare past the picture
	crtc[CRTC_OVERFLOW] = 0x10
	crtc[CRTC_MAXSCANLINE] = 0x40 | 0x01
	_load_cga64()


## AH = 05h: select the active display page.
func bios_set_active_page(page: int) -> void:
	var start: int = (page & 7) * PAGE_SIZE
	crtc[CRTC_STARTHIGH] = (start >> 8) & 0xFF
	crtc[CRTC_STARTLOW] = start & 0xFF


## AH = 10h, AL = 00h: set one palette register.
func bios_set_palette_register(index: int, value: int) -> void:
	atc[index & 0x0F] = value & 0x3F
	palette_serial += 1


## AH = 10h, AL = 01h: set the overscan (border) colour.
func bios_set_border(value: int) -> void:
	atc[ATR_OVERSCAN] = value & 0x3F


## AH = 10h, AL = 02h: set all sixteen palette registers and the border from
## a 17-byte table, the way every Keen engine sets its palette.
func bios_set_palette(table: PackedByteArray) -> void:
	for i: int in range(mini(16, table.size())):
		atc[i] = table[i] & 0x3F
	if table.size() > 16:
		atc[ATR_OVERSCAN] = table[16] & 0x3F
	palette_serial += 1


func _load_cga64() -> void:
	dac.fill(0)
	var dark: Array = [[0, 0, 0], [0, 0, 42], [0, 42, 0], [0, 42, 42], [42, 0, 0], [42, 0, 42], [42, 21, 0], [42, 42, 42]]
	var bright: Array = [[21, 21, 21], [21, 21, 63], [21, 63, 21], [21, 63, 63], [63, 21, 21], [63, 21, 63], [63, 63, 21], [63, 63, 63]]
	for i: int in range(64):
		var rgb: Array = bright[i & 7] if (i & 0x10) != 0 else dark[i & 7]
		for c: int in range(3):
			dac[i * 3 + c] = rgb[c]
	dac_write_index = 0
	dac_component = 0


# -- Port I/O ------------------------------------------------------------------------

func out8(port: int, value: int) -> void:
	value &= 0xFF
	accesses += 1
	match port:
		SC_INDEX:
			seq_index = value
		SC_DATA:
			if seq_index == SC_MAPMASK:
				map_mask = value & 0x0F
		GC_INDEX:
			gc_index = value
		GC_DATA:
			if gc_index < 9:
				gc[gc_index] = value
		ATR_INDEX:
			if atc_expect_data:
				var register: int = atc_index & 0x1F
				if register < 0x15:
					atc[register] = value
					if register < 0x10:
						palette_serial += 1
				atc_expect_data = false
			else:
				atc_index = value
				atc_expect_data = true
		CRTC_INDEX:
			crtc_index = value
		CRTC_DATA:
			if crtc_index < 0x19:
				crtc[crtc_index] = value
		DAC_WRITE_INDEX:
			dac_write_index = value
			dac_component = 0
		DAC_DATA:
			dac[dac_write_index * 3 + dac_component] = value & 0x3F
			palette_serial += 1
			dac_component += 1
			if dac_component == 3:
				dac_component = 0
				dac_write_index = (dac_write_index + 1) & 0xFF
		_:
			pass


## A 16-bit OUT: the low byte to `port`, the high byte to `port + 1` (the
## engines' "mov ax, REG + VALUE*256; out dx, ax").
func out16(port: int, value: int) -> void:
	out8(port, value & 0xFF)
	out8(port + 1, (value >> 8) & 0xFF)


func in8(port: int) -> int:
	match port:
		STATUS_1:
			# Reading input status #1 puts the attribute controller back into
			# "expecting an index" mode. Bit 3 (vertical retrace) alternates.
			atc_expect_data = false
			_status_reads += 1
			return 0x08 if (_status_reads & 1) == 0 else 0x00
		GC_DATA:
			return gc[gc_index] if gc_index < 9 else 0
		SC_DATA:
			return map_mask if seq_index == SC_MAPMASK else 0
		CRTC_DATA:
			return crtc[crtc_index] if crtc_index < 0x19 else 0
		ATR_READ:
			return atc[atc_index & 0x1F] if (atc_index & 0x1F) < 0x15 else 0
	return 0xFF


# -- Video memory (segment A000h) ----------------------------------------------------

## What the processor gets when it reads a byte of video memory.
func mem_read(address: int) -> int:
	accesses += 1
	if address > 0xFFFF or address < 0:
		return 0xFF
	latch0 = plane0[address]
	latch1 = plane1[address]
	latch2 = plane2[address]
	latch3 = plane3[address]
	if (gc[GC_MODE] & 0x08) == 0:
		# Read mode 0: the plane chosen by Read Map Select.
		match gc[GC_READMAP] & 3:
			0: return latch0
			1: return latch1
			2: return latch2
		return latch3
	# Read mode 1: one bit per pixel, set where the pixel matches Colour
	# Compare in every plane that Colour Don't Care leaves switched on.
	var care: int = gc[GC_COLORDONTCARE] & 0x0F
	var compare: int = gc[GC_COLORCOMPARE] & 0x0F
	var result: int = 0xFF
	if care & 1:
		result &= ~(latch0 ^ (0xFF if compare & 1 else 0x00))
	if care & 2:
		result &= ~(latch1 ^ (0xFF if compare & 2 else 0x00))
	if care & 4:
		result &= ~(latch2 ^ (0xFF if compare & 4 else 0x00))
	if care & 8:
		result &= ~(latch3 ^ (0xFF if compare & 8 else 0x00))
	return result & 0xFF


## What happens when the processor writes a byte to video memory.
func mem_write(address: int, value: int) -> void:
	accesses += 1
	if address > 0xFFFF or address < 0:
		return
	value &= 0xFF
	var mode: int = gc[GC_MODE] & 3
	if mode == 1:
		# Write mode 1: the latches are written back unchanged.
		if map_mask & 1:
			plane0[address] = latch0
		if map_mask & 2:
			plane1[address] = latch1
		if map_mask & 4:
			plane2[address] = latch2
		if map_mask & 8:
			plane3[address] = latch3
		return
	var function: int = (gc[GC_DATAROTATE] >> 3) & 3
	var bit_mask: int = gc[GC_BITMASK]
	if mode == 0:
		var rotate: int = gc[GC_DATAROTATE] & 7
		if rotate != 0:
			value = ((value >> rotate) | (value << (8 - rotate))) & 0xFF
		var enable_set_reset: int = gc[GC_ENABLESETRESET] & 0x0F
		var set_reset: int = gc[GC_SETRESET] & 0x0F
		if map_mask & 1:
			plane0[address] = _combine(_source(value, enable_set_reset, set_reset, 1), latch0, function, bit_mask)
		if map_mask & 2:
			plane1[address] = _combine(_source(value, enable_set_reset, set_reset, 2), latch1, function, bit_mask)
		if map_mask & 4:
			plane2[address] = _combine(_source(value, enable_set_reset, set_reset, 4), latch2, function, bit_mask)
		if map_mask & 8:
			plane3[address] = _combine(_source(value, enable_set_reset, set_reset, 8), latch3, function, bit_mask)
	elif mode == 2:
		# Write mode 2: the low four bits of the value are a colour, one bit per plane.
		if map_mask & 1:
			plane0[address] = _combine(0xFF if value & 1 else 0x00, latch0, function, bit_mask)
		if map_mask & 2:
			plane1[address] = _combine(0xFF if value & 2 else 0x00, latch1, function, bit_mask)
		if map_mask & 4:
			plane2[address] = _combine(0xFF if value & 4 else 0x00, latch2, function, bit_mask)
		if map_mask & 8:
			plane3[address] = _combine(0xFF if value & 8 else 0x00, latch3, function, bit_mask)
	else:
		# Write mode 3 (VGA): the rotated value ANDed with Bit Mask selects
		# which bits take the Set/Reset colour.
		var rotate3: int = gc[GC_DATAROTATE] & 7
		if rotate3 != 0:
			value = ((value >> rotate3) | (value << (8 - rotate3))) & 0xFF
		var select: int = value & bit_mask
		var colour: int = gc[GC_SETRESET] & 0x0F
		if map_mask & 1:
			plane0[address] = ((0xFF if colour & 1 else 0x00) & select) | (latch0 & ~select & 0xFF)
		if map_mask & 2:
			plane1[address] = ((0xFF if colour & 2 else 0x00) & select) | (latch1 & ~select & 0xFF)
		if map_mask & 4:
			plane2[address] = ((0xFF if colour & 4 else 0x00) & select) | (latch2 & ~select & 0xFF)
		if map_mask & 8:
			plane3[address] = ((0xFF if colour & 8 else 0x00) & select) | (latch3 & ~select & 0xFF)


static func _source(value: int, enable_set_reset: int, set_reset: int, plane_bit: int) -> int:
	if enable_set_reset & plane_bit:
		return 0xFF if set_reset & plane_bit else 0x00
	return value


static func _combine(data: int, latch: int, function: int, bit_mask: int) -> int:
	match function:
		1: data &= latch
		2: data |= latch
		3: data ^= latch
	return (data & bit_mask) | (latch & ~bit_mask & 0xFF)


## Write a run of bytes to video memory starting at `address`, as a REP MOVSB
## would. The common case (write mode 0, nothing rotated, set/reset off, bit
## mask open, one plane) skips the per-byte work; the result is the same.
func mem_write_block(address: int, data: PackedByteArray) -> void:
	if (gc[GC_MODE] & 3) == 0 and (gc[GC_DATAROTATE] & 0x1F) == 0 and (gc[GC_ENABLESETRESET] & 0x0F) == 0 \
			and gc[GC_BITMASK] == 0xFF and address >= 0 and address + data.size() <= PLANE_SIZE \
			and (map_mask == 1 or map_mask == 2 or map_mask == 4 or map_mask == 8):
		accesses += data.size()
		match map_mask:
			1:
				for i: int in range(data.size()):
					plane0[address + i] = data[i]
			2:
				for i: int in range(data.size()):
					plane1[address + i] = data[i]
			4:
				for i: int in range(data.size()):
					plane2[address + i] = data[i]
			8:
				for i: int in range(data.size()):
					plane3[address + i] = data[i]
		return
	for i: int in range(data.size()):
		mem_write(address + i, data[i])


# -- The picture ---------------------------------------------------------------------

## Where the top of the picture starts in video memory (CRTC start address).
func start_address() -> int:
	return ((crtc[CRTC_STARTHIGH] << 8) | crtc[CRTC_STARTLOW]) & 0xFFFF


## The start address the next picture is scanned from. The CRTC takes the
## start address registers at the beginning of each vertical retrace, so a
## write made during or after the retrace shows one picture later; the pel
## panning is taken at the retrace's end. The machine calls this at every
## retrace start; a program working the card alone calls it itself.
var display_start: int = 0


func latch_start() -> void:
	display_start = start_address()


## Bytes from one row to the next (twice the CRTC offset register).
func line_width() -> int:
	return crtc[CRTC_OFFSET] * 2


## The first picture row that the split screen shows from address 0, or
## HEIGHT when there is no split. Mode 0Dh is double-scanned on a VGA, so the
## line compare counts two scan lines per picture row.
func split_row() -> int:
	var compare: int = crtc[CRTC_LINECOMPARE] | ((crtc[CRTC_OVERFLOW] & 0x10) << 4) | ((crtc[CRTC_MAXSCANLINE] & 0x40) << 3)
	return mini(HEIGHT, (compare + 1) >> 1)


## The picture on the monitor right now: one byte per pixel, row by row, each
## a palette index 0-15. All zero in the text mode.
func compose() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(WIDTH * HEIGHT)
	compose_rows(out, 0, HEIGHT)
	return out


## Rows y0..y1-1 of the picture into `out` (WIDTH bytes a row), from the
## memory and registers as they are now: the beam draws a frame row by row,
## and a row shows what the memory held when the beam reached it.
func compose_rows(out: PackedByteArray, y0: int, y1: int) -> void:
	if video_mode != MODE_EGA:
		for i: int in range(y0 * WIDTH, y1 * WIDTH):
			out[i] = 0
		return
	var stride: int = line_width()
	var split: int = split_row()
	for y: int in range(y0, y1):
		var pan: int = atc[ATR_PELPAN] & 7
		var address: int
		if y >= split:
			# The split screen: the rows below the line compare are shown from
			# address 0, and with the pel-panning-compatibility bit set the
			# panning is dropped for them too.
			address = ((y - split) * stride) & 0xFFFF
			if atc[ATR_MODE] & 0x20:
				pan = 0
		else:
			address = (display_start + y * stride) & 0xFFFF
		var position: int = y * WIDTH
		if pan == 0:
			for i: int in range(40):
				var a: int = (address + i) & 0xFFFF
				out.encode_s64(position, _spread[plane0[a]] | (_spread[plane1[a]] << 1)
						| (_spread[plane2[a]] << 2) | (_spread[plane3[a]] << 3))
				position += 8
		else:
			# Every pixel comes from `pan` bits further along; the card does
			# not stop at the end of a row, so the right edge shows the start
			# of the next row's bytes.
			var drop: int = 8 * pan
			var keep: int = 64 - drop
			for i: int in range(40):
				var a: int = (address + i) & 0xFFFF
				var b: int = (address + i + 1) & 0xFFFF
				out.encode_s64(position,
						((_spread[plane0[a]] >> drop) | (_spread[plane0[b]] << keep))
						| (((_spread[plane1[a]] >> drop) | (_spread[plane1[b]] << keep)) << 1)
						| (((_spread[plane2[a]] >> drop) | (_spread[plane2[b]] << keep)) << 2)
						| (((_spread[plane3[a]] >> drop) | (_spread[plane3[b]] << keep)) << 3))
				position += 8


## The frame the beam is drawing: begun when the first visible line is
## scanned, filled band by band (DosMachine), finished at the last row.
var frame_pixels: PackedByteArray = PackedByteArray()
var frame_palette: PackedByteArray = PackedByteArray()
## A palette change while the beam is drawing a frame shows from the row it
## has reached (DOSBox looks the colours up line by line): the rows above keep
## the old colours. Such a frame is kept as RGB (frame_mixed, frame_rgb()).
var palette_serial: int = 0
var frame_mixed: bool = false
var _frame_serial: int = 0
var _frame_rgb_mixed: PackedByteArray = PackedByteArray()


func begin_frame() -> void:
	if frame_pixels.size() != WIDTH * HEIGHT:
		frame_pixels.resize(WIDTH * HEIGHT)
	frame_palette = palette_rgb()
	_frame_serial = palette_serial
	frame_mixed = false


func scan_rows(y0: int, y1: int) -> void:
	compose_rows(frame_pixels, y0, y1)
	if palette_serial != _frame_serial and not frame_mixed:
		frame_mixed = true
		_frame_rgb_mixed.resize(WIDTH * HEIGHT * 3)
		_rgb_rows(_frame_rgb_mixed, 0, y0, frame_palette)
	if frame_mixed:
		_rgb_rows(_frame_rgb_mixed, y0, y1, palette_rgb())


func _rgb_rows(out: PackedByteArray, y0: int, y1: int, pal: PackedByteArray) -> void:
	var o: int = y0 * WIDTH * 3
	for i: int in range(y0 * WIDTH, y1 * WIDTH):
		var c: int = frame_pixels[i] * 3
		out[o] = pal[c]
		out[o + 1] = pal[c + 1]
		out[o + 2] = pal[c + 2]
		o += 3


## The finished frame as 320x200 RGB.
func frame_rgb() -> PackedByteArray:
	if frame_mixed:
		return _frame_rgb_mixed.duplicate()
	var out: PackedByteArray = PackedByteArray()
	out.resize(WIDTH * HEIGHT * 3)
	var o: int = 0
	for i: int in range(WIDTH * HEIGHT):
		var c: int = frame_pixels[i] * 3
		out[o] = frame_palette[c]
		out[o + 1] = frame_palette[c + 1]
		out[o + 2] = frame_palette[c + 2]
		o += 3
	return out


## The colours compose() refers to: 16 entries of 8-bit red, green, blue,
## through the attribute controller's palette registers and the DAC.
##
## A DAC value has six bits. It is scaled to eight by rounding v * 255 / 63,
## which is what DOSBox Staging does and therefore what recordings of the
## original contain.
func palette_rgb() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(16 * 3)
	for i: int in range(16):
		var entry: int = atc[i] & 0x3F
		for c: int in range(3):
			var six: int = dac[entry * 3 + c]
			@warning_ignore("integer_division")
			out[i * 3 + c] = (six * 255 + 31) / 63
	return out


## The border (overscan) colour as 8-bit red, green, blue.
func border_rgb() -> PackedByteArray:
	var entry: int = atc[ATR_OVERSCAN] & 0x3F
	var out: PackedByteArray = PackedByteArray()
	for c: int in range(3):
		@warning_ignore("integer_division")
		out.append((dac[entry * 3 + c] * 255 + 31) / 63)
	return out


## compose() as 320x200 RGB, the frame store's format.
func picture_rgb() -> PackedByteArray:
	var pixels: PackedByteArray = compose()
	var pal: PackedByteArray = palette_rgb()
	var out: PackedByteArray = PackedByteArray()
	out.resize(WIDTH * HEIGHT * 3)
	var o: int = 0
	for i: int in range(WIDTH * HEIGHT):
		var p: int = pixels[i] * 3
		out[o] = pal[p]
		out[o + 1] = pal[p + 1]
		out[o + 2] = pal[p + 2]
		o += 3
	return out


# -- Snapshots (A7: the whole card is simulation state) ---------------------------------

func snapshot() -> Dictionary:
	return {
		"planes": [plane0.duplicate(), plane1.duplicate(), plane2.duplicate(), plane3.duplicate()],
		"latches": [latch0, latch1, latch2, latch3],
		"seq_index": seq_index, "map_mask": map_mask,
		"gc_index": gc_index, "gc": gc.duplicate(),
		"atc_index": atc_index, "atc_expect_data": atc_expect_data, "atc": atc.duplicate(),
		"crtc_index": crtc_index, "crtc": crtc.duplicate(), "display_start": display_start,
		"dac": dac.duplicate(), "dac_write_index": dac_write_index, "dac_component": dac_component,
		"video_mode": video_mode, "status_reads": _status_reads,
		"frame_pixels": frame_pixels.duplicate(), "frame_palette": frame_palette.duplicate(),
	}


func restore(s: Dictionary) -> void:
	plane0 = s.planes[0].duplicate()
	plane1 = s.planes[1].duplicate()
	plane2 = s.planes[2].duplicate()
	plane3 = s.planes[3].duplicate()
	latch0 = s.latches[0]
	latch1 = s.latches[1]
	latch2 = s.latches[2]
	latch3 = s.latches[3]
	seq_index = s.seq_index
	map_mask = s.map_mask
	gc_index = s.gc_index
	gc = s.gc.duplicate()
	atc_index = s.atc_index
	atc_expect_data = s.atc_expect_data
	atc = s.atc.duplicate()
	crtc_index = s.crtc_index
	crtc = s.crtc.duplicate()
	display_start = s.display_start
	dac = s.dac.duplicate()
	dac_write_index = s.dac_write_index
	dac_component = s.dac_component
	video_mode = s.video_mode
	_status_reads = s.status_reads


# ----------------------------------------------------------------- direct plane access
# For engines that write video memory the way ReflectionHLE's back end does (a byte of a plane,
# a latch copy, a colour through a bit mask), done here so the planes change in place: a plane
# fetched from outside and written would be copied whole (a PackedByteArray is copy-on-write).

func _pl(p: int) -> PackedByteArray:
	match p & 3:
		0: return plane0
		1: return plane1
		2: return plane2
	return plane3


## (The in-place operations below are Keen Dreams' back end's. Each counts the card memory accesses the
## original's instructions make (`accesses`: a read or a write a byte, a latch copy or a read-modify-write
## two), which the machine charges as time when vga_access_units is set: TIME-D.)
func plane_byte(p: int, off: int) -> int:
	accesses += 1
	return _pl(p)[off & 0xFFFF]


func set_plane_byte(p: int, off: int, v: int) -> void:
	accesses += 1
	match p & 3:
		0: plane0[off & 0xFFFF] = v & 0xFF
		1: plane1[off & 0xFFFF] = v & 0xFF
		2: plane2[off & 0xFFFF] = v & 0xFF
		_: plane3[off & 0xFFFF] = v & 0xFF


## `num` bytes of every plane (planes with `mask`'s bits) from `src` to `dst`, in order.
func copy_planes(dst: int, src: int, num: int, mask: int = 0xF) -> void:
	accesses += num * 2
	for i: int in range(num):
		var d: int = (dst + i) & 0xFFFF
		var s: int = (src + i) & 0xFFFF
		if mask & 1: plane0[d] = plane0[s]
		if mask & 2: plane1[d] = plane1[s]
		if mask & 4: plane2[d] = plane2[s]
		if mask & 8: plane3[d] = plane3[s]


## The bits of `bits` in every plane copied from `src` to `dst`.
func copy_plane_bits(dst: int, src: int, bits: int) -> void:
	accesses += 2
	var d: int = dst & 0xFFFF
	var s: int = src & 0xFFFF
	var keep: int = ~bits & 0xFF
	plane0[d] = (plane0[d] & keep) | (plane0[s] & bits)
	plane1[d] = (plane1[d] & keep) | (plane1[s] & bits)
	plane2[d] = (plane2[d] & keep) | (plane2[s] & bits)
	plane3[d] = (plane3[d] & keep) | (plane3[s] & bits)


## The bits of `bits` set to `color` at `off` (write mode 2 through the bit mask).
func color_bits(off: int, color: int, bits: int) -> void:
	accesses += 2
	var d: int = off & 0xFFFF
	var keep: int = ~bits & 0xFF
	plane0[d] = (plane0[d] & keep) | (bits if color & 1 else 0)
	plane1[d] = (plane1[d] & keep) | (bits if color & 2 else 0)
	plane2[d] = (plane2[d] & keep) | (bits if color & 4 else 0)
	plane3[d] = (plane3[d] & keep) | (bits if color & 8 else 0)


## `count` bytes from `off` set to `color` in every plane.
func color_fill(off: int, color: int, count: int) -> void:
	accesses += count
	var v0: int = 0xFF if color & 1 else 0
	var v1: int = 0xFF if color & 2 else 0
	var v2: int = 0xFF if color & 4 else 0
	var v3: int = 0xFF if color & 8 else 0
	for i: int in range(count):
		var d: int = (off + i) & 0xFFFF
		plane0[d] = v0
		plane1[d] = v1
		plane2[d] = v2
		plane3[d] = v3


## `num` bytes of `src` (from `so`) into one plane at `off`.
func write_plane(p: int, off: int, src: PackedByteArray, so: int, num: int) -> void:
	for i: int in range(num):
		set_plane_byte(p, off + i, src[so + i])


## A byte XORed into the planes of `mask`.
func xor_planes(off: int, v: int, mask: int) -> void:
	accesses += 2
	var d: int = off & 0xFFFF
	if mask & 1: plane0[d] ^= v & 0xFF
	if mask & 2: plane1[d] ^= v & 0xFF
	if mask & 4: plane2[d] ^= v & 0xFF
	if mask & 8: plane3[d] ^= v & 0xFF
