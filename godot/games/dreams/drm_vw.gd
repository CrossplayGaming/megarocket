# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's video library (id_vw.c, id_vw_a.c, id_vw_ae.c) as carried in ReflectionHLE, (C) 2014 Javier M. Chavez, (C) 2014-2026 NY00123, GPL v2 or later.
class_name DrmVW
extends DrmCA
## id_vw*.c, the EGA paths (docs/DREAMS_PLAN.md): drawing into the emulated card's memory through DrmBE.
## The CGA paths (id_vw_ac.c, the _CGA functions), the 2015 release's (fakecgamode) and the #if 0
## blocks are left out. A memptr is the PackedByteArray grsegs holds (a sprite as spritetype_ega
## bytes, a font as fontstruct bytes); offsets into video memory are ints wrapping at 64 KB.


# ===================================================================== BE_ST_* calls DrmBE lacks (move to drm_be.gd)

# ===================================================================== id_vw.h (inline function and macros)

## Waits for `number` new vertical retraces (WAITFORVBL).
func VW_WaitVBL(number: int) -> void:
	BE_ST_WaitForNewVerticalRetraces(number)


## A masked tile 8 (x in bytes): all of them are in one chunk.
func VW_DrawTile8M(x: int, y: int, t: int) -> void:
	VW_MaskBlock_EGA(grsegs[STARTTILE8M], u16(t * 40), u16(bufferofs + ylookup[y] + x), 1, 8, 8)


## A tile 16 (x in bytes).
func VW_DrawTile16(x: int, y: int, t: int) -> void:
	VW_MemToScreen_EGA(grsegs[STARTTILE16 + t], u16(bufferofs + ylookup[y] + x), 2, 16)


## A masked tile 16 (x in bytes), read at t*160 into the first masked tile's chunk as the original does.
func VW_DrawTile16M(x: int, y: int, t: int) -> void:
	call(VW_MaskBlock, grsegs[STARTTILE16M], u16(t * 160), u16(bufferofs + ylookup[y] + x), 2, 16, 32)


# ===================================================================== id_vw.c

const VIEWWIDTH: int = 40
const PIXTOBLOCK: int = 4    # 16 pixels to an update block

var SCREENXMASK: int = ~7
var SCREENXDIV: int = 8

var bordercolor: int = 0
var cursorvisible: int = 0
var cursornumber: int = 0
var cursorwidth: int = 0
var cursorheight: int = 0
var cursorx: int = 0
var cursory: int = 0
var cursorsave: PackedByteArray = PackedByteArray()
var cursorspot: int = 0

## VW_Startup's ParmStrings (other files have their own: this one carries the file's name).
const ParmStrings_id_vw: PackedStringArray = ["HIDDENCARD", "SWMOUSE"]


## Checks the video card, sets the graphics mode variable and builds the shift tables.
func VW_Startup() -> void:
	videocard = NOcard
	# kd_main.c's command line (id0_argc/id0_argv), read by name until a script declares it
	var argv: Variant = get(&"id0_argv")
	if argv is PackedStringArray:
		for i: int in range(1, argv.size()):
			match US_CheckParm(argv[i], ParmStrings_id_vw):
				0:
					videocard = EGAcard
				1:
					pass    # SWMOUSE: the 2015 release's
	if videocard == NOcard:
		videocard = VW_VideoID()
	if GRMODE == EGAGR:
		grmode = EGAGR
		if videocard != EGAcard and videocard != VGAcard:
			Quit("Improper video card!  If you really have an EGA/VGA card that I am not \n"
				+ "detecting, use the -HIDDENCARD command line parameter!")
	_vw_shifttables()
	cursorvisible = 0


func VW_Shutdown() -> void:
	VW_SetScreenMode(TEXTGR)
	if GRMODE == EGAGR:
		VW_SetLineWidth(80)


## Calls the BIOS to set the text or EGA mode (`mode` is the C's grmode argument).
func VW_SetScreenMode(mode: int) -> void:
	match mode:
		TEXTGR:
			BE_ST_SetScreenMode(3)    # (screenseg: the text memory is the machine's)
		EGAGR:
			BE_ST_SetScreenMode(0xd)
	VW_SetLineWidth(SCREENWIDTH)


# ---- screen fades

var colors: Array = [
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0]),
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0]),
	PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0]),
	PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0]),
	PackedByteArray([0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f]),
	PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
]


func VW_ColorBorder(color: int) -> void:
	BE_ST_SetBorderColor(color)
	bordercolor = color


func VW_SetDefaultColors() -> void:
	if GRMODE != EGAGR:
		return
	var palette: PackedByteArray = colors[3]
	palette[16] = bordercolor & 0xFF
	BE_ST_EGASetPaletteAndBorder(palette)
	screenfaded = false


## Steps the palette through colors[i] for i in `steps`, six retraces each.
func _vw_fade(steps: Array, faded: bool) -> void:
	if GRMODE != EGAGR:
		return
	for i: int in steps:
		var palette: PackedByteArray = colors[i]
		palette[16] = bordercolor & 0xFF
		BE_ST_EGASetPaletteAndBorder(palette)
		VW_WaitVBL(6)
	screenfaded = faded


func VW_FadeOut() -> void:
	_vw_fade([3, 2, 1, 0], true)


func VW_FadeIn() -> void:
	_vw_fade([0, 1, 2, 3], false)


func VW_FadeUp() -> void:
	_vw_fade([3, 4, 5], true)


func VW_FadeDown() -> void:
	_vw_fade([5, 4, 3], false)


## Sets the virtual screen's width in bytes (even) and the line lookup table.
func VW_SetLineWidth(width: int) -> void:
	if GRMODE == EGAGR:
		BE_ST_EGASetLineWidth(width)    # set wide virtual screen
	linewidth = u16(width)
	ylookup.resize(VIRTUALHEIGHT)
	var offset: int = 0
	for i: int in range(VIRTUALHEIGHT):
		ylookup[i] = u16(offset)
		offset = s16(offset + width)


func VW_ClearVideo(color: int) -> void:
	if GRMODE == EGAGR:
		BE_ST_EGAUpdateGFXBufferFrom4bitsPixel(0, color, 0xffff)


## X in bytes, y in pixels, chunknum the picture's chunk.
func VW_DrawPic(x: int, y: int, chunknum: int) -> void:
	var picnum: int = chunknum - STARTPICS
	var source: PackedByteArray = grsegs[chunknum]
	var dest: int = u16(ylookup[y] + x + bufferofs)
	var width: int = pictable[picnum].width
	var height: int = pictable[picnum].height
	call(VW_MemToScreen, source, dest, width, height)


## X in bytes, y in pixels; the size is read from pictable, not picmtable, as the original does.
func VW_DrawMPic(x: int, y: int, chunknum: int) -> void:
	var picnum: int = chunknum - STARTPICM
	var source: PackedByteArray = grsegs[chunknum]
	var dest: int = u16(ylookup[y] + x + bufferofs)
	var width: int = pictable[picnum].width
	var height: int = pictable[picnum].height
	call(VW_MaskBlock, source, 0, dest, width, height, u16(width * height))


## X and Y in pixels, at the closest shift the sprite has (no clipping).
func VW_DrawSprite(x: int, y: int, chunknum: int) -> void:
	var spr: spritetabletype = spritetable[chunknum - STARTSPRITES]
	var block: PackedByteArray = grsegs[chunknum]
	y = s16(y + (spr.orgy >> G_P_SHIFT))
	x = s16(x + (spr.orgx >> G_P_SHIFT))
	@warning_ignore("integer_division")
	var shift: int = (x & 7) / 2
	var dest: int = bufferofs + ylookup[y]
	if x >= 0:
		@warning_ignore("integer_division")
		dest += x / SCREENXDIV
	else:
		@warning_ignore("integer_division")
		dest += (x + 1) / SCREENXDIV
	call(VW_MaskBlock, block, VW_GetSpriteShiftSourceOffset(block, shift), u16(dest),
		VW_GetSpriteShiftWidth(block, shift), spr.height, VW_GetSpriteShiftPlaneSize(block, shift))


var leftmask_ega: PackedByteArray = PackedByteArray([0xff, 0x7f, 0x3f, 0x1f, 0xf, 7, 3, 1])
var rightmask_ega: PackedByteArray = PackedByteArray([0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff])


## A horizontal line from xl to xh (pixels) on line y.
func VW_Hlin_EGA(xl: int, xh: int, y: int, color: int) -> void:
	xl = u16(xl)
	xh = u16(xh)
	var xlb: int = xl >> 3
	var xhb: int = xh >> 3
	var maskleft: int = leftmask_ega[xl & 7]
	var maskright: int = rightmask_ega[xh & 7]
	var mid: int = u16(xhb - xlb - 1)
	var dest: int = u16(bufferofs + ylookup[y] + xlb)
	if xlb == xhb:
		# entire line is in one byte
		maskleft &= maskright
		BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(dest, color, maskleft)
		return
	BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(dest, color, maskleft)    # left side
	dest = u16(dest + 1)
	BE_ST_EGAUpdateGFXBufferFrom4bitsPixel(dest, color, mid)    # middle, no masking
	dest = u16(dest + mid)
	BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(dest, color, maskright)    # right side


## Pixel addressable block fill.
func VW_Bar_EGA(x: int, y: int, width: int, height: int, color: int) -> void:
	x = u16(x)
	var xh: int = u16(x + width - 1)
	var xlb: int = x >> 3
	var xhb: int = xh >> 3
	var maskleft: int = leftmask_ega[x & 7]
	var maskright: int = rightmask_ega[xh & 7]
	var mid: int = u16(xhb - xlb - 1)
	var dest: int = u16(bufferofs + ylookup[y] + xlb)
	height = u16(height)
	if xlb == xhb:
		# entire line is in one byte
		maskleft &= maskright
		while true:
			BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(dest, color, maskleft)
			dest = u16(dest + linewidth)    # down to next line
			height = u16(height - 1)
			if height == 0:
				break
		return
	var bytesToAdd: int = u16(linewidth - mid - 1)
	while true:
		BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(dest, color, maskleft)    # left side
		dest = u16(dest + 1)
		BE_ST_EGAUpdateGFXBufferFrom4bitsPixel(dest, color, mid)    # middle, no masking
		dest = u16(dest + mid)
		BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(dest, color, maskright)    # right side
		dest = u16(dest + bytesToAdd)    # start of next line
		height = u16(height - 1)
		if height == 0:
			break


## The C string's bytes (characters past 0xFF keep their low byte).
func _vw_byte_at(string: String, i: int) -> int:
	return string.unicode_at(i) & 0xFF if i < string.length() else 0


## The string's [width, height] in `font` (a font chunk): up to `optsend` characters (-1: to its end).
func VWL_MeasureString(string: String, optsend: int, _width: Variant, _height: Variant, font: PackedByteArray) -> PackedInt32Array:
	var height: int = font.decode_u16(0)
	var width: int = 0
	var n: int = optsend if optsend >= 0 else string.length()
	for i: int in range(n):
		var ch: int = _vw_byte_at(string, i)
		if optsend < 0 and ch == 0:
			break
		width = u16(width + font[514 + ch])    # proportional width
	return PackedInt32Array([width, height])


## [width, height] of the string in the proportional font (the C's *width, *height).
func VW_MeasurePropString(string: String, optsend: int, width: Variant, height: Variant) -> PackedInt32Array:
	return VWL_MeasureString(string, optsend, width, height, grsegs[STARTFONT])


func VW_MeasureMPropString(string: String, optsend: int, width: Variant, height: Variant) -> PackedInt32Array:
	return VWL_MeasureString(string, optsend, width, height, grsegs[STARTFONTM])


# ---- cursor routines (only in the context of the double buffered update routines)

## Saves the background, then draws the cursor at cursorspot.
func VWL_DrawCursor() -> void:
	@warning_ignore("integer_division")
	cursorspot = u16(bufferofs + ylookup[cursory + pansy] + (cursorx + pansx) / SCREENXDIV)
	call(VW_ScreenToMem, cursorspot, cursorsave, cursorwidth, cursorheight)
	VWB_DrawSprite(cursorx, cursory, cursornumber)


func VWL_EraseCursor() -> void:
	call(VW_MemToScreen, cursorsave, cursorspot, cursorwidth, cursorheight)
	VW_MarkUpdateBlock((cursorx + pansx) & SCREENXMASK, cursory + pansy,
		((cursorx + pansx) & SCREENXMASK) + cursorwidth * SCREENXDIV - 1,
		cursory + pansy + cursorheight - 1)


func VW_ShowCursor() -> void:
	cursorvisible += 1


func VW_HideCursor() -> void:
	cursorvisible -= 1


func VW_MoveCursor(x: int, y: int) -> void:
	cursorx = x
	cursory = y


## Loads a sprite to be used as the cursor and allocates its background save space.
func VW_SetCursor(spritenum: int) -> void:
	if cursornumber:
		MM_SetLock("gr:%d" % cursornumber, false)
		MM_FreePtr("cursorsave")
	cursornumber = spritenum
	CA_CacheGrChunk(spritenum)
	MM_SetLock("gr:%d" % cursornumber, true)
	cursorwidth = spritetable[spritenum - STARTSPRITES].width + 1
	cursorheight = spritetable[spritenum - STARTSPRITES].height
	MM_GetPtr("cursorsave", cursorwidth * cursorheight * 5)
	cursorsave = PackedByteArray()
	cursorsave.resize(cursorwidth * cursorheight * 5)


# ---- double buffer management routines

func VW_InitDoubleBuffer() -> void:
	if GRMODE == EGAGR:
		VW_SetScreen_EGA(u16(displayofs + panadjust), 0)    # no pel pan


## Copies the view page to the buffer page on page flipped refreshes, to avoid a one frame
## shear around pop up windows.
func VW_FixRefreshBuffer() -> void:
	if GRMODE == EGAGR:
		call(VW_ScreenToScreen, displayofs, bufferofs, PORTTILESWIDE * 4 * CHARWIDTH_EGA, PORTTILESHIGH * 16)


func VW_QuitDoubleBuffer() -> void:
	pass


## Marks the update tiles a pixel bounded block covers; 0 if it is entirely off the buffer screen.
func VW_MarkUpdateBlock(x1: int, y1: int, x2: int, y2: int) -> int:
	var xt1: int = s16(x1) >> PIXTOBLOCK
	var yt1: int = s16(y1) >> PIXTOBLOCK
	var xt2: int = s16(x2) >> PIXTOBLOCK
	var yt2: int = s16(y2) >> PIXTOBLOCK
	if xt1 < 0:
		xt1 = 0
	elif xt1 >= UPDATEWIDE - 1:
		return 0
	if yt1 < 0:
		yt1 = 0
	elif yt1 > UPDATEHIGH:
		return 0
	if xt2 < 0:
		return 0
	elif xt2 >= UPDATEWIDE - 1:
		xt2 = UPDATEWIDE - 2
	if yt2 < 0:
		return 0
	elif yt2 >= UPDATEHIGH:
		yt2 = UPDATEHIGH - 1
	# (yt1 may be UPDATEHIGH, one past uwidthtable: then nothing is marked)
	var mark: int = updateptr + (uwidthtable[yt1] if yt1 < uwidthtable.size() else UPDATEWIDE * yt1) + xt1
	var nextline: int = UPDATEWIDE - (xt2 - xt1) - 1
	for y: int in range(yt1, yt2 + 1):
		for x: int in range(xt1, xt2 + 1):
			update[mark] = 1    # this tile will need to be updated
			mark += 1
		mark += nextline
	return 1


## Updates the changed areas of the double buffer and displays the cursor.
func VW_UpdateScreen() -> void:
	if cursorvisible > 0:
		VWL_DrawCursor()
	if GRMODE == EGAGR:
		VWL_UpdateScreenBlocks()
		BE_ST_SetScreenStartAddress(u16(displayofs + panadjust))
	if cursorvisible > 0:
		VWL_EraseCursor()


# ---- mode independant routines: coordinates in pixels, rounded to best screen res, regions marked

func VWB_DrawTile8(x: int, y: int, tile: int) -> void:
	x += pansx
	y += pansy
	if VW_MarkUpdateBlock(x & SCREENXMASK, y, (x & SCREENXMASK) + 7, y + 7):
		@warning_ignore("integer_division")
		call(VW_DrawTile8, x / SCREENXDIV, y, tile)


func VWB_DrawTile8M(x: int, y: int, tile: int) -> void:
	x += pansx
	y += pansy
	@warning_ignore("integer_division")
	var xb: int = x / SCREENXDIV    # use intermediate because VW_DT8M is macro
	if VW_MarkUpdateBlock(x & SCREENXMASK, y, (x & SCREENXMASK) + 7, y + 7):
		VW_DrawTile8M(xb, y, tile)


func VWB_DrawTile16(x: int, y: int, tile: int) -> void:
	x += pansx
	y += pansy
	if VW_MarkUpdateBlock(x & SCREENXMASK, y, (x & SCREENXMASK) + 15, y + 15):
		@warning_ignore("integer_division")
		VW_DrawTile16(x / SCREENXDIV, y, tile)


func VWB_DrawTile16M(x: int, y: int, tile: int) -> void:
	x += pansx
	y += pansy
	@warning_ignore("integer_division")
	var xb: int = x / SCREENXDIV    # use intermediate because VW_DT16M is macro
	if VW_MarkUpdateBlock(x & SCREENXMASK, y, (x & SCREENXMASK) + 15, y + 15):
		VW_DrawTile16M(xb, y, tile)


func VWB_DrawPic(x: int, y: int, chunknum: int) -> void:
	var picnum: int = chunknum - STARTPICS
	x += pansx
	y += pansy
	@warning_ignore("integer_division")
	x /= SCREENXDIV
	var source: PackedByteArray = grsegs[chunknum]
	var dest: int = u16(ylookup[y] + x + bufferofs)
	var width: int = pictable[picnum].width
	var height: int = pictable[picnum].height
	if VW_MarkUpdateBlock(x * SCREENXDIV, y, (x + width) * SCREENXDIV - 1, y + height - 1):
		call(VW_MemToScreen, source, dest, width, height)


func VWB_DrawMPic(x: int, y: int, chunknum: int) -> void:
	var picnum: int = chunknum - STARTPICM
	x += pansx
	y += pansy
	@warning_ignore("integer_division")
	x /= SCREENXDIV
	var source: PackedByteArray = grsegs[chunknum]
	var dest: int = u16(ylookup[y] + x + bufferofs)
	var width: int = picmtable[picnum].width
	var height: int = picmtable[picnum].height
	if VW_MarkUpdateBlock(x * SCREENXDIV, y, (x + width) * SCREENXDIV - 1, y + height - 1):
		call(VW_MaskBlock, source, 0, dest, width, height, u16(width * height))


func VWB_Bar(x: int, y: int, width: int, height: int, color: int) -> void:
	x += pansx
	y += pansy
	if VW_MarkUpdateBlock(x, y, x + width, y + height - 1):
		call(VW_Bar, x, y, width, height, color)


## The string at px/py (up to `optsend` characters, -1 to its end), its area marked.
func VWB_DrawPropString(string: String, optsend: int) -> void:
	var x: int = px + pansx
	var y: int = py + pansy
	call(VW_DrawPropString, string, optsend)
	VW_MarkUpdateBlock(x, y, x + bufferwidth * 8 - 1, y + bufferheight - 1)


func VWB_DrawSprite(x: int, y: int, chunknum: int) -> void:
	x += pansx
	y += pansy
	var spr: spritetabletype = spritetable[chunknum - STARTSPRITES]
	var block: PackedByteArray = grsegs[chunknum]
	y = s16(y + (spr.orgy >> G_P_SHIFT))
	x = s16(x + (spr.orgx >> G_P_SHIFT))
	@warning_ignore("integer_division")
	var shift: int = (x & 7) / 2
	var dest: int = bufferofs + ylookup[y]
	if x >= 0:
		@warning_ignore("integer_division")
		dest += x / SCREENXDIV
	else:
		@warning_ignore("integer_division")
		dest += (x + 1) / SCREENXDIV
	var width: int = VW_GetSpriteShiftWidth(block, shift)
	var height: int = spr.height
	if VW_MarkUpdateBlock(x & SCREENXMASK, y, (x & SCREENXMASK) + width * SCREENXDIV - 1, y + height - 1):
		call(VW_MaskBlock, block, VW_GetSpriteShiftSourceOffset(block, shift), u16(dest),
			width, height, VW_GetSpriteShiftPlaneSize(block, shift))


func VWB_Plot(x: int, y: int, color: int) -> void:
	x += pansx
	y += pansy
	if VW_MarkUpdateBlock(x, y, x, y):
		call(VW_Plot, x, y, color)


func VWB_Hlin(x1: int, x2: int, y: int, color: int) -> void:
	x1 += pansx
	x2 += pansx
	y += pansy
	if VW_MarkUpdateBlock(x1, y, x2, y):
		call(VW_Hlin, x1, x2, y, color)


func VWB_Vlin(y1: int, y2: int, x: int, color: int) -> void:
	x += pansx
	y1 += pansy
	y2 += pansy
	if VW_MarkUpdateBlock(x, y1, x, y2):
		call(VW_Vlin, y1, y2, x, color)


## Sets what depends on the graphics mode (the EGA's): sizes, colours and the line routines.
func RefKeen_Patch_id_vw() -> void:
	SCREENWIDTH = SCREENWIDTH_EGA
	CHARWIDTH = CHARWIDTH_EGA
	TILEWIDTH = TILEWIDTH_EGA
	WHITE = WHITE_EGA
	BLACK = BLACK_EGA
	FIRSTCOLOR = FIRSTCOLOR_EGA
	SECONDCOLOR = SECONDCOLOR_EGA
	F_BLACK = F_BLACK_EGA
	F_FIRSTCOLOR = F_FIRSTCOLOR_EGA
	F_SECONDCOLOR = F_SECONDCOLOR_EGA
	SCREENXMASK = ~7
	SCREENXDIV = 8
	VW_Hlin = &"VW_Hlin_EGA"
	VW_Bar = &"VW_Bar_EGA"


# ===================================================================== id_vw_a.c

## shifttabletable[n][b]: byte b shifted right n pixels across two bytes (the first in the low
## byte, the bits pushed out in the high one), as the source's shiftdata0..7 list them.
func _vw_shifttables() -> void:
	if shifttabletable.size() == 8:
		return
	var tables: Array = []
	for n: int in range(8):
		var table: PackedInt32Array = PackedInt32Array()
		table.resize(256)
		for b: int in range(256):
			table[b] = (b >> n) | (((b << (8 - n)) & 0xFF) << 8)
		tables.append(table)
	shifttabletable = tables


## The video card present (ReflectionHLE: always a VGA).
func VW_VideoID() -> int:
	return VGAcard


# ===================================================================== id_vw_ae.c

const plotpixels: PackedByteArray = [128, 64, 32, 16, 8, 4, 2, 1]


func VW_Plot_EGA(x: int, y: int, color: int) -> void:
	x = u16(x)
	BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(u16(bufferofs + ylookup[y] + (x >> 3)), color, plotpixels[x & 7])


func VW_Vlin_EGA(yl: int, yh: int, x: int, color: int) -> void:
	x = u16(x)
	var egaDestOff: int = u16(bufferofs + ylookup[yl] + (x >> 3))
	var mask: int = plotpixels[x & 7]
	var loopVar: int = u16(yh - yl + 1)
	while loopVar:
		BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(egaDestOff, color, mask)
		loopVar -= 1
		egaDestOff = u16(egaDestOff + linewidth)


var screendest: int = 0


## xcoord in bytes (8 pixels), ycoord in pixels; all tile 8s are in one chunk.
func VW_DrawTile8_EGA(xcoord: int, ycoord: int, tile: int) -> void:
	screendest = u16(bufferofs + xcoord + ylookup[ycoord])
	var tiles: PackedByteArray = grsegs[STARTTILE8]
	var tilePtr: int = u16(tile << 5)
	for currentPlane: int in range(4):
		var egaDestOff: int = screendest
		for loopVar: int in range(8):
			BE_ST_EGAUpdateGFXByteInPlane(egaDestOff, tiles[tilePtr], currentPlane)
			egaDestOff = u16(egaDestOff + linewidth)
			tilePtr += 1


## A masked block (the mask, then four planes of data) at `ofs` in `segm`; bufferofs is NOT
## accounted for.
func VW_MaskBlock_EGA(segm: PackedByteArray, ofs: int, dest: int, wide: int, height: int, planesize: int) -> void:
	planenum = 0
	linedelta = u16(linewidth - wide)    # amount to add after drawing each line
	var dataLoc: int = planesize
	while true:
		var srcPtr: int = ofs    # start back at the top of the mask
		var egaDestOff: int = u16(dest)    # start at same place in all planes
		var linesLeft: int = u16(height)
		while true:    # draw one plane
			var colsLeft: int = u16(wide)
			while true:
				BE_ST_EGAUpdateGFXByteInPlane(egaDestOff,
					(BE_ST_EGAFetchGFXByteFromPlane(egaDestOff, planenum) & segm[srcPtr]) | segm[srcPtr + dataLoc], planenum)
				srcPtr += 1
				egaDestOff = u16(egaDestOff + 1)
				colsLeft = u16(colsLeft - 1)
				if colsLeft == 0:
					break
			egaDestOff = u16(egaDestOff + linedelta)
			linesLeft = u16(linesLeft - 1)
			if linesLeft == 0:
				break
		dataLoc += planesize    # start of mask = start of next plane
		planenum += 1
		if planenum == 4:    # done all four planes
			break


## A block copy within video memory (write mode 1); bufferofs is NOT accounted for.
func VW_ScreenToScreen_EGA(source: int, dest: int, wide: int, height: int) -> void:
	var lineCounter: int = u16(height)
	while lineCounter:
		BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(u16(dest), u16(source), wide)
		lineCounter -= 1
		source = u16(source + linewidth)
		dest = u16(dest + linewidth)


## Draws a block of four planes of width by height data to dest in the virtual screen;
## bufferofs is NOT accounted for.
func VW_MemToScreen_EGA(source: PackedByteArray, dest: int, wide: int, height: int) -> void:
	var srcPtr: int = 0    # block is segment aligned
	for currentPlane: int in range(4):
		var egaDestOff: int = u16(dest)    # start at same place in all planes
		var lineCounter: int = u16(height)    # scan lines to draw
		while true:
			BE_ST_EGAUpdateGFXBufferInPlane(egaDestOff, source, srcPtr, wide, currentPlane)
			srcPtr += wide
			egaDestOff = u16(egaDestOff + linewidth)
			lineCounter = u16(lineCounter - 1)
			if lineCounter == 0:
				break


## Copies a block of video memory to main memory, planes 0-3 in order.
func VW_ScreenToMem_EGA(source: int, dest: PackedByteArray, wide: int, height: int) -> void:
	var destPtr: int = 0
	for planeCounter: int in range(4):
		var egaSrcOff: int = u16(source)    # start at same place in all planes
		var lineCounter: int = u16(height)
		while true:
			BE_ST_EGAFetchGFXBufferFromPlane(dest, destPtr, egaSrcOff, wide, planeCounter)
			egaSrcOff = u16(egaSrcOff + linewidth)
			destPtr += wide
			lineCounter = u16(lineCounter - 1)
			if lineCounter == 0:
				break


## The update array's byte at `i` (0 past its end, where the original reads on).
func _vw_update_at(i: int) -> int:
	return update[i] if i < update.size() else 0


## Copies every tile the update array marks from the buffer page to the displayed one, then
## zeros the update array.
func VWL_UpdateScreenBlocks() -> void:
	var scanPtr: int = updateptr
	var scanEndPtr: int = updateptr + UPDATEWIDE * UPDATEHIGH + 1
	var iterationsToDo: int = 0xFFFF    # definitely scan the entire thing
	while true:
		# scan for a 1 in the update list, meaning a tile needs to be copied from the
		# master screen to the current screen
		while iterationsToDo:
			iterationsToDo -= 1
			var v: int = _vw_update_at(scanPtr)
			scanPtr += 1
			if v == 1:
				break
		if scanPtr >= scanEndPtr:    # all tiles have been scanned
			for i: int in range(UPDATEWIDE * UPDATEHIGH):    # clear out the update matrix
				update[updateptr + i] = 0
			return
		if _vw_update_at(scanPtr) != 1:
			# copy a single tile
			scanPtr += 1    # we know the next tile is nothing
			var tileLoc: int = blockstarts[scanPtr - updateptr - 2]    # start of tile location on screen
			var egaSrcOff: int = u16(tileLoc + bufferofs)
			var egaDestOff: int = u16(tileLoc + displayofs)
			for loopVar: int in range(15):
				BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(egaDestOff, egaSrcOff)
				BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(u16(egaDestOff + 1), u16(egaSrcOff + 1))
				egaSrcOff = u16(egaSrcOff + linewidth)
				egaDestOff = u16(egaDestOff + linewidth)
			BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(egaDestOff, egaSrcOff)
			BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(u16(egaDestOff + 1), u16(egaSrcOff + 1))
			continue
		# more than one tile in a row needs to be updated, so do it as a group
		var rowScanStartPtr: int = scanPtr    # hold starting position + 1
		scanPtr += 1    # we know the next tile also gets updated
		while iterationsToDo:    # see how many more in a row
			iterationsToDo -= 1
			var v: int = _vw_update_at(scanPtr)
			scanPtr += 1
			if v != 1:
				break
		var bytesPerRow: int = u16(2 * (scanPtr - rowScanStartPtr))
		var tileLoc: int = blockstarts[rowScanStartPtr - updateptr - 1]    # start of tile location
		var egaSrcOff: int = u16(tileLoc + bufferofs)
		var egaDestOff: int = u16(tileLoc + displayofs)
		for loopVar: int in range(15):
			BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(egaDestOff, egaSrcOff, bytesPerRow)
			egaSrcOff = u16(egaSrcOff + linewidth)
			egaDestOff = u16(egaDestOff + linewidth)
		BE_ST_EGAUpdateGFXBufferInAllPlanesScrToScr(egaDestOff, egaSrcOff, bytesPerRow)
		iterationsToDo = 0xFFFF    # (the original's counter, run out to 0, wraps back)


## The CRTC start address and the pel panning, then a retrace.
## As the original's assembly (id_vw_ae.asm) does it: wait for the display to begin (out of any
## blanking), set the start address, then wait for a vertical retrace (at once if one is on) and set
## the pel panning in it, so both show together from the next picture. ReflectionHLE sets the panning
## at once and waits for the retrace after (its TODO notes the difference); on a card that pans line
## by line, as this one and the EGA do, that tears a scrolling picture where the beam was (REPLAY-D:
## the v1.00 title's logo moved a refresh before the rest).
func VW_SetScreen_EGA(CRTC: int, pelpan: int) -> void:
	vm.wait_retrace_end()
	BE_ST_SetScreenStartAddress(u16(CRTC))
	vm.wait_in_retrace()
	BE_ST_EGASetPelPanning(pelpan)


# ---- general font drawing routines

const BUFFWIDTH: int = 50
const BUFFHEIGHT: int = 32    # must be twice as high as font for masked fonts

var databuffer: PackedByteArray = _vw_databuffer()


static func _vw_databuffer() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(BUFFWIDTH * BUFFHEIGHT)
	return b


## Draws the buffer to the screen at screenspot, XORed into the planes of fontcolor.
func VWL_XORBuffer(buffer: PackedByteArray) -> void:
	if not bufferwidth:
		return    # nothing to draw
	var srcPtr: int = 0
	var egaDestOff: int = screenspot
	# calculate offsets for end of each line
	screenextra = u16(linewidth - bufferwidth)
	bufferextra = u16(BUFFWIDTH - bufferwidth)
	var linesLeft: int = bufferheight    # lines to copy
	while true:
		var bytesLeft: int = bufferwidth    # bytes to copy
		while true:
			BE_ST_EGAXorGFXByteByPlaneMask(egaDestOff, buffer[srcPtr] if srcPtr < buffer.size() else 0, fontcolor)
			egaDestOff = u16(egaDestOff + 1)
			srcPtr += 1
			bytesLeft = u16(bytesLeft - 1)
			if bytesLeft == 0:
				break
		srcPtr += bufferextra
		egaDestOff = u16(egaDestOff + screenextra)
		linesLeft = u16(linesLeft - 1)
		if linesLeft == 0:
			break


## One character table-shifted into databuffer at bufferbyte/bufferbit, which then move past it.
func ShiftPropChar(charnum: int) -> void:
	var currfont: PackedByteArray = grsegs[STARTFONT]
	var adjustedwidth: int = currfont[514 + charnum]    # width in pixels
	var srcPtr: int = currfont.decode_s16(2 + charnum * 2)    # location of data in the font
	var currshifttable: PackedInt32Array = shifttabletable[bufferbit]
	var destPtr: int = bufferbyte
	# advance position by character width
	var posToSplit: int = bufferbit + adjustedwidth
	bufferbit = posToSplit & 7    # new bit position
	bufferbyte = u16(bufferbyte + (posToSplit >> 3))    # new byte position
	var bytes: int = (adjustedwidth + 7) >> 3
	if bytes < 1 or bytes > 3:
		return
	for loopvar: int in range(currfont.decode_u16(0)):
		for b: int in range(bytes):    # SHIFTNOXOR
			var currshift: int = currshifttable[currfont[srcPtr]]    # table shift into two bytes
			if destPtr < databuffer.size():
				databuffer[destPtr] |= currshift & 0xFF    # or with first byte
			destPtr += 1
			if destPtr < databuffer.size():
				databuffer[destPtr] = currshift >> 8    # replace next byte
			srcPtr += 1
		destPtr += BUFFWIDTH - bytes


## Draws the string at px/py and advances px (up to `optsend` characters, -1 to its end).
func VW_DrawPropString_EGA(string: String, optsend: int) -> void:
	# proportional spacing, which clears the buffer ahead of it, so only clear the first column
	for line: int in range(BUFFHEIGHT):
		databuffer[BUFFWIDTH * line] = 0
	# shift the characters into the buffer
	bufferbit = px & 7
	bufferbyte = 0
	var n: int = optsend if optsend >= 0 else string.length() + 1
	for i: int in range(n):
		var currChAsUnsigned: int = _vw_byte_at(string, i)
		if not currChAsUnsigned:
			break
		ShiftPropChar(currChAsUnsigned)
	# calculate position to draw buffer on screen
	screenspot = u16(ylookup[py] + bufferofs + panadjust + (px >> 3))
	px = s16(px + ((bufferbyte << 3) | bufferbit))    # advance px
	# draw it
	bufferwidth = bufferbyte + 1 if (bufferbit & 7) else bufferbyte
	bufferheight = (grsegs[STARTFONT] as PackedByteArray).decode_u16(0)
	VWL_XORBuffer(databuffer)


## Points the drawing routines at the EGA's.
func RefKeen_Patch_id_vw_ae() -> void:
	if GRMODE == EGAGR:
		VW_MaskBlock = &"VW_MaskBlock_EGA"
		VW_MemToScreen = &"VW_MemToScreen_EGA"
		VW_ScreenToMem = &"VW_ScreenToMem_EGA"
		VW_ScreenToScreen = &"VW_ScreenToScreen_EGA"
		VW_DrawTile8 = &"VW_DrawTile8_EGA"
		VW_DrawPropString = &"VW_DrawPropString_EGA"
		VW_Plot = &"VW_Plot_EGA"
		VW_Vlin = &"VW_Vlin_EGA"
