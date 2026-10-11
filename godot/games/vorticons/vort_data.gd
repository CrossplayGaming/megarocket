# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: K1n9_Duk3's reconstructed Keen 1-3 source (GPL v2): IDLIBC.C
# (bloadin, bloadinLZW, LZW_Decompress, LoadGraphics, RLEWExpand), IDASM.ASM
# (Expand, DrawPic), IDLIB.H (grheadtype, spritetype, pictype, LevelDef),
# KEENMAIN.C (ReadLevel, DrawPicFile), KEENDEMO.C (text files).
class_name VortData
extends RefCounted
## The Vorticons engine's files (Keen 1, 2 and 3), read from the player's own
## folder into plain arrays. Nothing here touches the engine or the screen.
##
## Graphics come out as one byte per pixel (EGA colour 0-15); sprites also get
## a mask (1 = opaque). Levels come out as their two planes of 16-bit words.
## Every short or inconsistent file stops with `error` naming the file and the
## offset: a silent skip would produce a game that looks complete and is not.

const RLETAG: int = 0xFEFE
const LEVEL_HEADER_BYTES: int = 32      # LevelDef (16 bytes) plus unused space; planes start here

## Data the executables carry inside them (offset, size into the LZEXE-unpacked
## load image), v1.31. TILEINFO is the tile property table every episode
## compiles in; ENDSCRN the text-mode exit screen; Keen 2 and 3 also link
## their texts (TEXTSLINKED) and sounds (SOUNDSLINKED) instead of shipping
## them as files. Offsets per K1n9_Duk3's ckpatch blocks, checked here by the
## terminators the data carries (texts end in 0x1A, the sound image by its
## "SND" header). A game of another version fails these checks by name, which
## is what DATA-02 (version identification) is for.
const LINKED: Dictionary = {
	"CK1": {"tileinfo": [0x130F8, 0x1CA4], "endscrn": [0x12080, 0xFA8]},
	"CK2": {"tileinfo": [0x17828, 0x204C], "endscrn": [0x11780, 0xFA8], "sounds": [0x12730, 0x310A],
		"endtext": [0x15840, 0x37C], "helptext": [0x15BC0, 0x7DE], "previews": [0x163A0, 0x715], "storytxt": [0x16AC0, 0xC98]},
	"CK3": {"tileinfo": [0x198C8, 0x2184], "endscrn": [0x12AC0, 0xFA8], "sounds": [0x13A70, 0x3F60],
		"helptext": [0x179D0, 0x7CC], "endtext": [0x181A0, 0x33C], "previews": [0x184E0, 0x6E4], "storytxt": [0x18BD0, 0xC23]},
}

var error: String = ""
var dir: String = ""
var ext: String = ""                    # "CK1", "CK2", "CK3"

# EGAHEAD
var latchsize: int = 0
var spritesize: int = 0
var num_chars: int = 0
var num_tiles: int = 0
var num_pics: int = 0
var num_sprites: int = 0
var compression: bool = false

# decoded graphics
var chars: PackedByteArray = PackedByteArray()      # num_chars * 64 pixels (8x8)
var tiles: PackedByteArray = PackedByteArray()      # num_tiles * 256 pixels (16x16)
var pics: Array[Dictionary] = []                    # {name, w, h, pixels}
var sprites: Array[Dictionary] = []                 # {name, w, h, pixels, mask, xl, yl, xh, yh}

# sounds: [{name, priority, rate, divisors: PackedInt32Array}]
var sounds: Array[Dictionary] = []

# the same graphics as the engine keeps them: the four EGALATCH planes and
# the five EGASPRIT planes, undecoded, with the header's tables
var latch_planes: PackedByteArray = PackedByteArray()   # 4 x latchsize
var sprite_planes: PackedByteArray = PackedByteArray()  # 5 x spritesize
var off_chars: int = 0
var off_tiles: int = 0
var off_pics: int = 0
var pic_entries: Array[Dictionary] = []        # {w (bytes), h, shape}
var sprite_entries: Array[Dictionary] = []     # 4 per sprite (the shifts): {w (bytes), h, shape, xl, yl, xh, yh}
## A18 / PREP-01: the asset stage the sprites pass through as they are decoded (set its filters before
## load_game; with none, the identity: nothing changes)
var stage: AssetStage = AssetStage.new()

# text files, as loaded (PrepareText is the engine's business)
var help_text: PackedByteArray = PackedByteArray()
var story_text: PackedByteArray = PackedByteArray()
var end_text: PackedByteArray = PackedByteArray()
var previews_text: PackedByteArray = PackedByteArray()

# from inside the executable
var exe_image: PackedByteArray = PackedByteArray()  # the unpacked program, read once
var tileinfo: PackedByteArray = PackedByteArray()   # the tile property table
var endscrn: PackedByteArray = PackedByteArray()    # 80x25 text-mode exit screen (char, attribute)


# ------------------------------------------------------------------ bytes

static func u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func s16(b: PackedByteArray, o: int) -> int:
	var v: int = b[o] | (b[o + 1] << 8)
	return v - 0x10000 if v >= 0x8000 else v


static func u32(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


## A far pointer stored on disk (offset, segment) as a byte offset.
static func farptr(b: PackedByteArray, o: int) -> int:
	return u16(b, o) + u16(b, o + 2) * 16


func _fail(msg: String) -> bool:
	if error == "":
		error = msg
	return false


## MAKER-01: files the shell puts in place of the game folder's (a level from the maker, played in
## place), by name in upper case -> the file's bytes. Empty: the folder's own, always.
var overrides: Dictionary = {}


## Whether the game has this file (the folder's, or one put in its place).
func has_file(name: String) -> bool:
	return overrides.has(name.to_upper()) or FileAccess.file_exists(dir.path_join(name))


func _read(name: String) -> PackedByteArray:
	if overrides.has(name.to_upper()):
		return overrides[name.to_upper()]
	var path: String = dir.path_join(name)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("%s: cannot open (%s)" % [name, error_string(FileAccess.get_open_error())])
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return data


# ------------------------------------------------------------- decoders

## LZW as the engine's bloadinLZW + LZW_Decompress: the file starts with the
## expanded length (4 bytes) and the longest code length (2 bytes).
func lzw_expand(src: PackedByteArray, name: String) -> PackedByteArray:
	if src.size() < 6:
		_fail("%s: LZW file is only %d bytes" % [name, src.size()])
		return PackedByteArray()
	var length: int = u32(src, 0)
	var maxcodelen: int = u16(src, 4)
	var tablesize: int = {14: 18041, 13: 9029, 12: 5021}.get(maxcodelen, 0)
	if tablesize == 0:
		_fail("%s: LZW code length %d is not 12, 13 or 14" % [name, maxcodelen])
		return PackedByteArray()
	var codes: PackedInt32Array = PackedInt32Array()
	codes.resize(tablesize)
	var values: PackedByteArray = PackedByteArray()
	values.resize(tablesize)
	var out: PackedByteArray = PackedByteArray()
	out.resize(length)
	var outpos: int = 0
	var stack: PackedByteArray = PackedByteArray()
	stack.resize(4002)

	var pos: int = 6
	var bitbuffer: int = 0          # the engine's 32-bit buffer, kept to 32 bits
	var bitsavail: int = 0
	var codelen: int = 9
	var maxcode: int = (1 << codelen) - 1
	var nextcode: int = 0x102
	var fresh: bool = true
	var prevcode: int = 0
	var prevval: int = 0
	var n: int = src.size()

	while true:
		# LZW_ReadCode
		while bitsavail <= 24:
			var val: int = src[pos] if pos < n else 0
			pos += 1
			bitbuffer = (bitbuffer | (val << (24 - bitsavail))) & 0xFFFFFFFF
			bitsavail += 8
		var code: int = bitbuffer >> (32 - codelen)
		bitbuffer = (bitbuffer << codelen) & 0xFFFFFFFF
		bitsavail -= codelen
		if pos > n + 4:
			_fail("%s: LZW stream ran past the end of the file at output byte %d of %d" % [name, outpos, length])
			return PackedByteArray()
		if code == 0x101:
			break
		if fresh:
			fresh = false
			prevcode = code
			prevval = code
			if outpos >= length:
				_fail("%s: LZW output longer than its header says (%d)" % [name, length])
				return PackedByteArray()
			out[outpos] = prevcode & 0xFF
			outpos += 1
		elif code == 0x100:
			fresh = true
			codelen = 9
			nextcode = 0x102
			maxcode = (1 << codelen) - 1
		else:
			var sp: int = 0
			var c: int
			if code >= nextcode:
				stack[0] = prevval
				sp = 1
				c = prevcode
			else:
				c = code
			var count: int = 0
			while c > 0xFF:
				if c >= tablesize:
					_fail("%s: LZW code %d outside the table at output byte %d" % [name, c, outpos])
					return PackedByteArray()
				stack[sp] = values[c]
				sp += 1
				c = codes[c]
				count += 1
				if count >= 4000:
					_fail("%s: LZW code chain too long at output byte %d" % [name, outpos])
					return PackedByteArray()
			stack[sp] = c
			prevval = c
			if outpos + sp + 1 > length:
				_fail("%s: LZW output longer than its header says (%d)" % [name, length])
				return PackedByteArray()
			var i: int = sp
			while i >= 0:
				out[outpos] = stack[i]
				outpos += 1
				i -= 1
			if nextcode <= maxcode:
				codes[nextcode] = prevcode
				values[nextcode] = prevval
				nextcode += 1
				if nextcode == maxcode and codelen < maxcodelen:
					codelen += 1
					maxcode = (1 << codelen) - 1
			prevcode = code
	if outpos != length:
		_fail("%s: LZW produced %d bytes, header says %d" % [name, outpos, length])
		return PackedByteArray()
	return out


## Word RLE as the engine's RLEWExpand: 4-byte expanded length, then words;
## RLETAG count value means `count` copies of `value`.
func rlew_expand(src: PackedByteArray, name: String) -> PackedByteArray:
	if src.size() < 4:
		_fail("%s: RLEW file is only %d bytes" % [name, src.size()])
		return PackedByteArray()
	var length: int = u32(src, 0)
	var out: PackedByteArray = PackedByteArray()
	out.resize(length)
	var o: int = 0
	var i: int = 4
	var n: int = src.size()
	while o < length:
		if i + 2 > n:
			_fail("%s: RLEW data ends at byte %d with %d of %d bytes expanded" % [name, i, o, length])
			return PackedByteArray()
		var value: int = u16(src, i)
		i += 2
		if value != RLETAG:
			out[o] = value & 0xFF
			out[o + 1] = value >> 8
			o += 2
		else:
			if i + 4 > n:
				_fail("%s: RLEW run cut short at byte %d" % [name, i])
				return PackedByteArray()
			var count: int = u16(src, i)
			value = u16(src, i + 2)
			i += 4
			for k: int in range(count):
				if o + 1 >= length:
					# the engine writes past `end` for the last run; stop at the length
					break
				out[o] = value & 0xFF
				out[o + 1] = value >> 8
				o += 2
	return out


## Byte RLE as IDASM's Expand (full-screen pictures): 4-byte length, then
## code < 0x80: repeat the next byte code+3 times; code >= 0x80: copy code-0x7F bytes.
func rle_expand(src: PackedByteArray, name: String) -> PackedByteArray:
	if src.size() < 4:
		_fail("%s: RLE file is only %d bytes" % [name, src.size()])
		return PackedByteArray()
	var length: int = u32(src, 0)
	var out: PackedByteArray = PackedByteArray()
	out.resize(length)
	var o: int = 0
	var i: int = 4
	var n: int = src.size()
	while o < length:
		if i >= n:
			_fail("%s: RLE data ends at byte %d with %d of %d bytes expanded" % [name, i, o, length])
			return PackedByteArray()
		var code: int = src[i]
		i += 1
		if code < 0x80:
			if i >= n:
				_fail("%s: RLE repeat cut short at byte %d" % [name, i])
				return PackedByteArray()
			var value: int = src[i]
			i += 1
			for k: int in range(code + 3):
				if o < length:
					out[o] = value
					o += 1
		else:
			var count: int = code - 0x7F
			if i + count > n:
				_fail("%s: RLE copy of %d bytes cut short at byte %d" % [name, count, i])
				return PackedByteArray()
			for k: int in range(count):
				if o < length:
					out[o] = src[i + k]
					o += 1
			i += count
	return out


## Four EGA planes (blue, green, red, intensity) of `wbytes` bytes per row,
## each plane `stride` bytes from the last, into one byte per pixel.
static func unplane(src: PackedByteArray, base: int, stride: int, wbytes: int, h: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(wbytes * 8 * h)
	for y: int in range(h):
		for xb: int in range(wbytes):
			var o: int = base + y * wbytes + xb
			var b0: int = src[o]
			var b1: int = src[o + stride]
			var b2: int = src[o + stride * 2]
			var b3: int = src[o + stride * 3]
			var px: int = (y * wbytes + xb) * 8
			for bit: int in range(8):
				var m: int = 0x80 >> bit
				out[px + bit] = int((b0 & m) != 0) | (int((b1 & m) != 0) << 1) \
					| (int((b2 & m) != 0) << 2) | (int((b3 & m) != 0) << 3)
	return out


# --------------------------------------------------------------- loading

## Load the engine's fixed files for one game. `dir` holds the player's
## files, `ext` is CK1, CK2 or CK3. Returns false with `error` set on any fault.
func load_game(game_dir: String, extension: String) -> bool:
	dir = game_dir
	ext = extension
	error = ""
	if not _load_graphics():
		return false
	if not _load_exe_image():
		return false
	if not _load_sounds():
		return false
	var linked: Dictionary = LINKED.get(ext, {})
	if linked.has("helptext"):
		help_text = _linked("helptext", true)
		story_text = _linked("storytxt", true)
		end_text = _linked("endtext", true)
		previews_text = _linked("previews", true)
	else:
		help_text = _read("HELPTEXT." + ext)
		story_text = _read("STORYTXT." + ext)
		end_text = _read("ENDTEXT." + ext)
		previews_text = _read("PREVIEWS." + ext)
	if error != "":
		return false
	tileinfo = _linked("tileinfo", false)
	endscrn = _linked("endscrn", false)
	return error == ""


func _exe_name() -> String:
	return "KEEN%s.EXE" % ext.substr(2, 1)


func _load_exe_image() -> bool:
	var exe: PackedByteArray = _read(_exe_name())
	if exe.is_empty():
		return false
	exe_image = LzExe.unpack(exe)
	if exe_image.is_empty():
		return _fail("%s: %s" % [_exe_name(), LzExe.error])
	return true


## A block the executable carries, by the LINKED table; texts must end in 0x1A.
func _linked(what: String, is_text: bool) -> PackedByteArray:
	var linked: Dictionary = LINKED.get(ext, {})
	if not linked.has(what):
		_fail("%s: no known offset for %s in this version" % [_exe_name(), what])
		return PackedByteArray()
	var off: int = linked[what][0]
	var size: int = linked[what][1]
	if off + size > exe_image.size():
		_fail("%s: %s at %d (%d bytes) lies past the end of the %d-byte program" % [_exe_name(), what, off, size, exe_image.size()])
		return PackedByteArray()
	var block: PackedByteArray = exe_image.slice(off, off + size)
	if is_text and block[size - 1] != 0x1A:
		_fail("%s: %s at %d does not end in the text terminator; not the expected version" % [_exe_name(), what, off])
		return PackedByteArray()
	return block


func _load_graphics() -> bool:
	var head: PackedByteArray = _read("EGAHEAD." + ext)
	if head.is_empty():
		return false
	# grheadtype, v1.31 layout (no field_1C/field_1E, which came with v1.32)
	if head.size() < 0x2C:
		return _fail("EGAHEAD.%s: header is only %d bytes" % [ext, head.size()])
	latchsize = u32(head, 0)
	spritesize = u32(head, 4)
	var picinfo_start: int = u32(head, 8)
	var sprinfo_start: int = u32(head, 12)
	num_chars = u16(head, 16)
	off_chars = u32(head, 18)
	# field_16 (2) and field_18 (4) at 22..27
	num_tiles = u16(head, 28)
	off_tiles = u32(head, 30)
	num_pics = u16(head, 34)
	off_pics = u32(head, 36)
	num_sprites = s16(head, 40)
	# offSprites at 42..45
	compression = head.size() > 46 and head[46] != 0
	if picinfo_start + num_pics * 16 > head.size():
		return _fail("EGAHEAD.%s: picture table (%d entries at %d) runs past the end (%d)" % [ext, num_pics, picinfo_start, head.size()])
	if sprinfo_start + num_sprites * 4 * 32 > head.size():
		return _fail("EGAHEAD.%s: sprite table (%d entries at %d) runs past the end (%d)" % [ext, num_sprites, sprinfo_start, head.size()])

	# EGALATCH: four planes of latchsize bytes
	var latch_name: String = "EGALATCH." + ext
	var latch: PackedByteArray = _read(latch_name)
	if latch.is_empty():
		return false
	if compression:
		latch = lzw_expand(latch, latch_name)
		if latch.is_empty():
			return false
	if latch.size() < latchsize * 4:
		return _fail("%s: %d bytes, but EGAHEAD says four planes of %d" % [latch_name, latch.size(), latchsize])
	if off_chars + num_chars * 8 > latchsize or off_tiles + num_tiles * 32 > latchsize:
		return _fail("%s: tiles (%d at %d) or chars (%d at %d) run past a plane of %d" % [latch_name, num_tiles, off_tiles, num_chars, off_chars, latchsize])
	latch_planes = latch
	# chars: 8 bytes per plane each, one byte per row
	chars = PackedByteArray()
	chars.resize(num_chars * 64)
	for c: int in range(num_chars):
		var px: PackedByteArray = unplane(latch, off_chars + c * 8, latchsize, 1, 8)
		for k: int in range(64):
			chars[c * 64 + k] = px[k]
	tiles = PackedByteArray()
	tiles.resize(num_tiles * 256)
	for t: int in range(num_tiles):
		var px: PackedByteArray = unplane(latch, off_tiles + t * 32, latchsize, 2, 16)
		for k: int in range(256):
			tiles[t * 256 + k] = px[k]
	pics = []
	pic_entries = []
	for p: int in range(num_pics):
		var e: int = picinfo_start + p * 16
		var w: int = s16(head, e)
		var h: int = s16(head, e + 2)
		var shape: int = farptr(head, e + 4)
		var pname: String = head.slice(e + 8, e + 16).get_string_from_ascii()
		if w <= 0 or h <= 0 or off_pics + shape + w * h > latchsize:
			return _fail("EGAHEAD.%s: picture %d (%s) %dx%d at %d does not fit a plane of %d" % [ext, p, pname, w, h, shape, latchsize])
		pics.append({"name": pname, "w": w * 8, "h": h, "pixels": unplane(latch, off_pics + shape, latchsize, w, h)})
		pic_entries.append({"w": w, "h": h, "shape": shape})

	# EGASPRIT: five planes (four colours and the mask) of spritesize bytes
	var spr_name: String = "EGASPRIT." + ext
	var spr: PackedByteArray = _read(spr_name)
	if spr.is_empty():
		return false
	if compression:
		spr = lzw_expand(spr, spr_name)
		if spr.is_empty():
			return false
	if spr.size() < spritesize * 5:
		return _fail("%s: %d bytes, but EGAHEAD says five planes of %d" % [spr_name, spr.size(), spritesize])
	sprite_planes = spr
	sprites = []
	sprite_entries = []
	for i: int in range(num_sprites * 4):
		var e4: int = sprinfo_start + i * 32
		sprite_entries.append({"w": s16(head, e4), "h": s16(head, e4 + 2), "shape": farptr(head, e4 + 4),
			"xl": s16(head, e4 + 8), "yl": s16(head, e4 + 10), "xh": s16(head, e4 + 12), "yh": s16(head, e4 + 14)})
	for i: int in range(num_sprites):
		var e: int = sprinfo_start + i * 4 * 32       # the unshifted entry of each four
		var w: int = s16(head, e)
		var h: int = s16(head, e + 2)
		var shape: int = farptr(head, e + 4)
		var sname: String = head.slice(e + 16, e + 28).get_string_from_ascii()
		if w <= 0 or h <= 0 or shape + w * h > spritesize:
			return _fail("EGAHEAD.%s: sprite %d (%s) %dx%d at %d does not fit a plane of %d" % [ext, i, sname, w, h, shape, spritesize])
		var pixels: PackedByteArray = unplane(spr, shape, spritesize, w, h)
		var mask: PackedByteArray = PackedByteArray()
		mask.resize(w * 8 * h)
		for y: int in range(h):
			for xb: int in range(w):
				var mb: int = spr[spritesize * 4 + shape + y * w + xb]
				for bit: int in range(8):
					# the mask plane is 1 where the background shows through
					mask[(y * w + xb) * 8 + bit] = 0 if (mb & (0x80 >> bit)) != 0 else 1
		sprites.append({"name": sname, "w": w * 8, "h": h, "pixels": pixels, "mask": mask,
			"xl": s16(head, e + 8), "yl": s16(head, e + 10), "xh": s16(head, e + 12), "yh": s16(head, e + 14)})
	_stage_sprites(sprinfo_start, head)
	return true


## A18: every sprite through the asset stage; one a filter changed is written back both into its decoded
## copy and into the sprite file's planes (which the game's loader copies onto the card), so the card
## and the native view show the same.
func _stage_sprites(sprinfo_start: int, head: PackedByteArray) -> void:
	stage.bind(_game_id(), AssetStage.vorticons_names(_sprite_names()))
	if stage.is_identity():
		return
	for i: int in range(sprites.size()):
		var s: Dictionary = sprites[i]
		var img: Dictionary = {"w": s.w, "h": s.h, "pixels": s.pixels, "opaque": s.mask}
		var out: Dictionary = stage.run(i, img)
		if out == img:
			continue
		s.pixels = out.pixels
		s.mask = out.opaque
		var wb: int = int(s.w) / 8
		var shape: int = farptr(head, sprinfo_start + i * 4 * 32 + 4)
		for y: int in range(int(s.h)):
			for xb: int in range(wb):
				var planes: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
				for bit: int in range(8):
					var p: int = (y * wb + xb) * 8 + bit
					var c: int = out.pixels[p]
					for b: int in range(4):
						if c & (1 << b):
							planes[b] |= 0x80 >> bit
					if out.opaque[p] == 0:
						planes[4] |= 0x80 >> bit
				for pl: int in range(5):
					sprite_planes[spritesize * pl + shape + y * wb + xb] = planes[pl]


func _game_id() -> String:
	return "keen" + ext.substr(2, 1)


func _sprite_names() -> PackedStringArray:
	match ext:
		"CK1":
			return VortNames1.SPRITE_NAMES
		"CK2":
			return VortNames2.SPRITE_NAMES
		"CK3":
			return VortNames3.SPRITE_NAMES
	return PackedStringArray()


## SOUNDS: a 16-byte header {"SND", file size, count, ...} then 16-byte
## entries {start, priority, rate, name[12]} for sounds 1..count (the engine
## indexes the file by sound number times 16, so entry 0 IS the header), then
## the tone streams: 16-bit PIT divisors, 0 = rest, 0xFFFF = end.
## Keen 1 keeps this in SOUNDS.CK1; Keen 2 and 3 link the same image into
## their executables (SOUNDSLINKED), where it is found by its "SND" magic
## after LZEXE unpacking.
func _load_sounds() -> bool:
	var name: String = "SOUNDS." + ext
	var data: PackedByteArray
	if FileAccess.file_exists(dir.path_join(name)):
		data = _read(name)
	else:
		name = _exe_name() + " (linked sounds)"
		data = _linked("sounds", false)
		if data.is_empty():
			return false
	if data.size() < 16:
		return _fail("%s: only %d bytes" % [name, data.size()])
	if data.slice(0, 4) != PackedByteArray([0x53, 0x4E, 0x44, 0x00]):
		return _fail("%s: no SND header" % name)
	var count: int = u16(data, 6)
	if count < 1 or (count + 1) * 16 > data.size():
		return _fail("%s: header says %d sounds, which do not fit in %d bytes" % [name, count, data.size()])
	sounds = [{"name": "", "priority": 0, "rate": 0, "divisors": PackedInt32Array()}]   # entry 0: the header
	for i: int in range(1, count + 1):
		var e: int = i * 16
		var start: int = u16(data, e)
		var divisors: PackedInt32Array = PackedInt32Array()
		var p: int = start
		while true:
			if p + 2 > data.size():
				return _fail("%s: sound %d runs past the end of the file" % [name, i])
			var v: int = u16(data, p)
			p += 2
			if v == 0xFFFF:
				break
			divisors.append(v)
		sounds.append({"name": data.slice(e + 4, e + 16).get_string_from_ascii(), "priority": data[e + 2],
			"rate": data[e + 3], "divisors": divisors})
	return true


## One level: {width, height, planes, screenx, screeny, screenw, screenh,
## planesize, plane: [PackedInt32Array of words...]}. Empty with `error` on fault.
func load_level(number: int) -> Dictionary:
	var name: String = ("LEVEL%02d." % number) + ext
	var raw: PackedByteArray = _read(name)
	if raw.is_empty():
		return {}
	var data: PackedByteArray = rlew_expand(raw, name)
	if data.is_empty():
		return {}
	if data.size() < LEVEL_HEADER_BYTES:
		_fail("%s: expanded to only %d bytes" % [name, data.size()])
		return {}
	var level: Dictionary = {
		"width": s16(data, 0), "height": s16(data, 2), "planes": s16(data, 4),
		"screenx": s16(data, 6), "screeny": s16(data, 8), "screenw": s16(data, 10), "screenh": s16(data, 12),
		"planesize": u16(data, 14), "plane": [],
	}
	if level.width <= 0 or level.height <= 0 or level.planes < 1 or level.planes > 4:
		_fail("%s: header says %dx%d with %d planes" % [name, level.width, level.height, level.planes])
		return {}
	if level.planesize < level.width * level.height * 2:
		_fail("%s: plane size %d is less than %dx%d words" % [name, level.planesize, level.width, level.height])
		return {}
	if LEVEL_HEADER_BYTES + level.planesize * level.planes > data.size():
		_fail("%s: %d planes of %d bytes do not fit in %d expanded bytes" % [name, level.planes, level.planesize, data.size()])
		return {}
	for p: int in range(level.planes):
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(level.width * level.height)
		var base: int = LEVEL_HEADER_BYTES + p * level.planesize
		for i: int in range(level.width * level.height):
			words[i] = u16(data, base + i * 2)
		level.plane.append(words)
	return level


## A full-screen picture file (FINALE, PREVIEWS, PREVIEW2, PREVIEW3): 320x200,
## one byte per pixel. Empty with `error` on fault.
func load_picture_file(name: String) -> PackedByteArray:
	var raw: PackedByteArray = _read(name)
	if raw.is_empty():
		return PackedByteArray()
	var data: PackedByteArray = rle_expand(raw, name)
	if data.is_empty():
		return PackedByteArray()
	# four planes 0x2000 bytes apart (DrawPicFile's 0x200-paragraph segments), 40 bytes a row
	if data.size() < 0x2000 * 3 + 8000:
		_fail("%s: expanded to %d bytes, less than four planes of a 320x200 picture" % [name, data.size()])
		return PackedByteArray()
	return unplane(data, 0, 0x2000, 40, 200)


## Level files present in the folder, in number order.
func level_numbers() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		var up: String = f.to_upper()
		if up.begins_with("LEVEL") and up.ends_with("." + ext) and up.length() == 11:
			var n: String = up.substr(5, 2)
			if n.is_valid_int():
				out.append(int(n))
	out.sort()
	return out
