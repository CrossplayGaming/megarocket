# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# The machine calls of ReflectionHLE's back end that the Keen Dreams source
# makes (refkeen/src/be_st.h; their implementations in
# backend/video/be_video_emu.c), by NY00123, GPL v2 or later, carried out on
# the emulated machine instead of ReflectionHLE's own.
class_name DrmBE
extends DrmDecl
## BE_ST_*: what the Dreams source asks of the PC, done to DosMachine and its
## EgaCard (A3: the card keeps the planes, latches and registers; ReflectionHLE
## packs the four planes into one array, the port keeps them apart). Offsets
## into video memory wrap at 64 KB, as the card's address does.


# ===================================================================== EGA memory (be_video_emu.c)

func _plane(p: int) -> PackedByteArray:
	match p & 3:
		0: return vm.card.plane0
		1: return vm.card.plane1
		2: return vm.card.plane2
	return vm.card.plane3


func _set_plane(p: int, a: PackedByteArray) -> void:
	match p & 3:
		0: vm.card.plane0 = a
		1: vm.card.plane1 = a
		2: vm.card.plane2 = a
		_: vm.card.plane3 = a


## One byte into one plane.
func BE_ST_EGAUpdateGFXByteInPlane(destOff: int, srcVal: int, planeNum: int) -> void:
	var a: PackedByteArray = _plane(planeNum)
	a[destOff & 0xFFFF] = srcVal & 0xFF
	_set_plane(planeNum, a)


## `num` bytes of `src` (from `srcOff`) into one plane.
func BE_ST_EGAUpdateGFXBufferInPlane(destOff: int, src: PackedByteArray, srcOff: int, num: int, planeNum: int) -> void:
	var a: PackedByteArray = _plane(planeNum)
	for i: int in range(num):
		a[(destOff + i) & 0xFFFF] = src[srcOff + i]
	_set_plane(planeNum, a)


## A byte of every plane copied within video memory (a latch copy).
func BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(destOff: int, srcOff: int) -> void:
	for p: int in range(4):
		var a: PackedByteArray = _plane(p)
		a[destOff & 0xFFFF] = a[srcOff & 0xFFFF]
		_set_plane(p, a)


func BE_ST_EGAUpdateGFXByteInPlaneScrToScr(destOff: int, srcOff: int, planeNum: int) -> void:
	var a: PackedByteArray = _plane(planeNum)
	a[destOff & 0xFFFF] = a[srcOff & 0xFFFF]
	_set_plane(planeNum, a)


## The bits of `bitsMask` of every plane copied within video memory.
func BE_ST_EGAUpdateGFXBitsInAllPlanesScrToScr(destOff: int, srcOff: int, bitsMask: int) -> void:
	for p: int in range(4):
		var a: PackedByteArray = _plane(p)
		var d: int = destOff & 0xFFFF
		a[d] = (a[d] & ~bitsMask & 0xFF) | (a[srcOff & 0xFFFF] & bitsMask)
		_set_plane(p, a)


## `num` bytes of every plane copied within video memory, in order.
func BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(destOff: int, srcOff: int, num: int) -> void:
	for p: int in range(4):
		var a: PackedByteArray = _plane(p)
		for i: int in range(num):
			a[(destOff + i) & 0xFFFF] = a[(srcOff + i) & 0xFFFF]
		_set_plane(p, a)


func BE_ST_EGAFetchGFXByteFromPlane(srcOff: int, planeNum: int) -> int:
	return _plane(planeNum)[srcOff & 0xFFFF]


## `num` bytes of one plane into `dest` from `destOff`.
func BE_ST_EGAFetchGFXBufferFromPlane(dest: PackedByteArray, destOff: int, srcOff: int, num: int, planeNum: int) -> void:
	var a: PackedByteArray = _plane(planeNum)
	for i: int in range(num):
		dest[destOff + i] = a[(srcOff + i) & 0xFFFF]


## The bits of `bitsMask` set to a colour in every plane (write mode 2 through the bit mask).
func BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(destOff: int, color: int, bitsMask: int) -> void:
	color &= 0xF
	var d: int = destOff & 0xFFFF
	for p: int in range(4):
		var a: PackedByteArray = _plane(p)
		var on: int = bitsMask if (color >> p) & 1 else 0
		a[d] = (a[d] & ~bitsMask & 0xFF) | on
		_set_plane(p, a)


## `count` bytes (8 pixels each) set to a colour.
func BE_ST_EGAUpdateGFXBufferFrom4bitsPixel(destOff: int, color: int, count: int) -> void:
	color &= 0xF
	for p: int in range(4):
		var a: PackedByteArray = _plane(p)
		var v: int = 0xFF if (color >> p) & 1 else 0
		for i: int in range(count):
			a[(destOff + i) & 0xFFFF] = v
		_set_plane(p, a)


func BE_ST_EGAUpdateGFXBufferFrom4bitsPixelInPairs(destOff: int, color: int, pairsCount: int) -> void:
	BE_ST_EGAUpdateGFXBufferFrom4bitsPixel(destOff, color, 2 * pairsCount)


# ===================================================================== the CRTC, attribute controller, palette

## The CRTC start address (latched by the card at the next retrace).
func BE_ST_SetScreenStartAddress(crtc: int) -> void:
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTHIGH)
	vm.out8(EgaCard.CRTC_DATA, (crtc >> 8) & 0xFF)
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTLOW)
	vm.out8(EgaCard.CRTC_DATA, crtc & 0xFF)


func BE_ST_SetScreenStartAddressHiPart(crtc_hi: int) -> void:
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_STARTHIGH)
	vm.out8(EgaCard.CRTC_DATA, crtc_hi & 0xFF)


## The attribute controller's horizontal pel panning.
func BE_ST_EGASetPelPanning(panning: int) -> void:
	vm.in8(EgaCard.STATUS_1)    # reset the flip-flop to the index
	vm.out8(EgaCard.ATR_INDEX, EgaCard.ATR_PELPAN | 0x20)
	vm.out8(EgaCard.ATR_INDEX, panning & 0xFF)


## INT 10h AX=1002h: the sixteen palette registers and the border (17 bytes).
func BE_ST_EGASetPaletteAndBorder(palette: PackedByteArray) -> void:
	vm.card.bios_set_palette(palette)


## INT 10h: the video mode (3 text, 0Dh EGA 320x200).
func BE_ST_SetScreenMode(mode: int) -> void:
	vm.card.bios_set_video_mode(mode)


func BE_ST_MarkGfxForUpdate() -> void:
	pass    # the card shows its memory as the beam scans it


## VW_WaitVBL: `number` times out of any retrace, then to the start of the next.
func BE_ST_WaitForNewVerticalRetraces(number: int) -> void:
	vm.wait_vbl(number)


## The busy loops' yield (waiting on the timer or a key): the machine runs to its next event.
func BE_ST_ShortSleep() -> void:
	vm.poll()
