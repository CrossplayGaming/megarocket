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
# Each through the card's own in-place operations (EgaCard's direct plane access: a plane taken
# out and written here would be copied whole on every byte).

## One byte into one plane.
func BE_ST_EGAUpdateGFXByteInPlane(destOff: int, srcVal: int, planeNum: int) -> void:
	vm.card.set_plane_byte(planeNum, destOff, srcVal)


## `num` bytes of `src` (from `srcOff`) into one plane.
func BE_ST_EGAUpdateGFXBufferInPlane(destOff: int, src: PackedByteArray, srcOff: int, num: int, planeNum: int) -> void:
	vm.card.write_plane(planeNum, destOff, src, srcOff, num)


## A byte of every plane copied within video memory (a latch copy).
func BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(destOff: int, srcOff: int) -> void:
	vm.card.copy_planes(destOff, srcOff, 1)


func BE_ST_EGAUpdateGFXByteInPlaneScrToScr(destOff: int, srcOff: int, planeNum: int) -> void:
	vm.card.copy_planes(destOff, srcOff, 1, 1 << (planeNum & 3))


## The bits of `bitsMask` of every plane copied within video memory.
func BE_ST_EGAUpdateGFXBitsInAllPlanesScrToScr(destOff: int, srcOff: int, bitsMask: int) -> void:
	vm.card.copy_plane_bits(destOff, srcOff, bitsMask & 0xFF)


## `num` bytes of every plane copied within video memory, in order.
func BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(destOff: int, srcOff: int, num: int) -> void:
	vm.card.copy_planes(destOff, srcOff, num)


func BE_ST_EGAFetchGFXByteFromPlane(srcOff: int, planeNum: int) -> int:
	return vm.card.plane_byte(planeNum, srcOff)


## `num` bytes of one plane into `dest` from `destOff`.
func BE_ST_EGAFetchGFXBufferFromPlane(dest: PackedByteArray, destOff: int, srcOff: int, num: int, planeNum: int) -> void:
	for i: int in range(num):
		dest[destOff + i] = vm.card.plane_byte(planeNum, srcOff + i)


## The bits of `bitsMask` set to a colour in every plane (write mode 2 through the bit mask).
func BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(destOff: int, color: int, bitsMask: int) -> void:
	vm.card.color_bits(destOff, color & 0xF, bitsMask & 0xFF)


## `count` bytes (8 pixels each) set to a colour.
func BE_ST_EGAUpdateGFXBufferFrom4bitsPixel(destOff: int, color: int, count: int) -> void:
	vm.card.color_fill(destOff, color & 0xF, count)


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


## INT 10h AX=1001h: the overscan (border) colour.
func BE_ST_SetBorderColor(color: int) -> void:
	vm.card.bios_set_border(color & 0xFF)


## The CRTC offset register: `widthInBytes` from one row to the next (in words, so even).
func BE_ST_EGASetLineWidth(widthInBytes: int) -> void:
	vm.out8(EgaCard.CRTC_INDEX, EgaCard.CRTC_OFFSET)
	vm.out8(EgaCard.CRTC_DATA, (widthInBytes & 0xFF) >> 1)


## A byte XORed into the planes of `planeMask` (map mask and the data rotate register's XOR).
func BE_ST_EGAXorGFXByteByPlaneMask(destOff: int, srcVal: int, planeMask: int) -> void:
	vm.card.xor_planes(destOff, srcVal, planeMask)


## INT 10h: the video mode (3 text, 0Dh EGA 320x200).
func BE_ST_SetScreenMode(mode: int) -> void:
	vm.card.bios_set_video_mode(mode)


func BE_ST_MarkGfxForUpdate() -> void:
	pass    # the card shows its memory as the beam scans it


## VW_WaitVBL: `number` times out of any retrace, then to the start of the next.
func BE_ST_WaitForNewVerticalRetraces(number: int) -> void:
	vm.wait_vbl(number)


## The busy loops' yield (waiting on the timer or a key): the machine runs to the next timer tic,
## refresh or key, the only things these loops wait on (ReflectionHLE's sleeps where the original
## does not wait at all are left out where they stand).
func BE_ST_ShortSleep() -> void:
	vm.poll_event()
