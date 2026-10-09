# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of the Keen Dreams source's memory manager and cache (id_mm.c,
# id_ca.c) as carried in ReflectionHLE, Copyright (C) 2014 Javier M. Chavez,
# (C) 2014-2026 NY00123, GPL v2 or later. The files are decoded by DreamsData
# (Huffman, RLEW); the 2015 release's paths are left out (not supported).
class_name DrmCA
extends DrmBE
## id_mm.c and id_ca.c. Every cached chunk is kept as the bytes the C holds
## (a sprite with its three tables of shifts and its shifted copies, a font
## with its height, locations and widths), so the drawing code reads them at
## the C's offsets. The memory manager keeps the original's block list beside
## them (J-16 (a)): each block is keyed by the pointer variable it belongs to
## ("gr:N" grsegs[N], "aud:N" audiosegs[N], "map:P" mapsegs[P],
## "maphead:N" mapheaderseg[N], and the temporaries by name); a block thrown
## out clears its owner, so the program caches it again (TIME-D).

# ===================================================================== id_mm.c

const MM_LOCKBIT: int = 0x80
const MM_PURGEBITS: int = 3


class MMBlock:
	var start: int = 0
	var length: int = 0
	var attributes: int = 0
	var key: String = ""
	var next: MMBlock = null


var mmstarted: bool = false
var mmhead: MMBlock = null
var mmrover: MMBlock = null
var mmblocks_by_key: Dictionary = {}    # key -> MMBlock


## The DOS memory the original's manager gets, in paragraphs: the near heap (what is left of the
## data segment) and the far heap (DOS's free memory above the program). PROVISIONAL: to be read
## from the original's own memory display (DebugMemory, MM_ShowMemory) under DOSBox, as Keen 4's
## was (HARN-18); the start-up and level loads only depend on the order of what is allocated
## until then.
func mm_layout() -> Dictionary:
	return {"near": [0x2a00, 0x200], "far": [0x3200, 0x6c00]}


func MM_Startup() -> void:
	if mmstarted:
		MM_Shutdown()
	mmstarted = true
	bombonerror = true
	var lay: Dictionary = mm_layout()
	# locked block of unusable low memory, from 0 to the start of the near heap
	mmhead = MMBlock.new()
	mmhead.start = 0
	mmhead.length = lay.near[0]
	mmhead.attributes = MM_LOCKBIT
	var endfree: int = lay.near[0] + lay.near[1]
	mminfo.nearheap = lay.near[1] * 16
	# locked block of unusable near heap memory (the stack), from the end of the near heap to
	# the start of the far heap
	var b: MMBlock = MMBlock.new()
	b.start = endfree
	b.length = lay.far[0] - endfree
	b.attributes = MM_LOCKBIT
	mmhead.next = b
	endfree = lay.far[0] + lay.far[1]
	mminfo.farheap = lay.far[1] * 16
	mminfo.mainmem = mminfo.nearheap + mminfo.farheap
	mminfo.XMSmem = 0
	mminfo.EMSmem = 0
	# cap off the list: locked high memory (video, ROM) from the end of the far heap to 0xffff
	var hi: MMBlock = MMBlock.new()
	hi.start = endfree
	hi.length = 0xffff - endfree
	hi.attributes = MM_LOCKBIT
	b.next = hi
	mmblocks_by_key = {}
	# the misc buffer
	mmrover = mmhead
	MM_GetPtr("bufferseg", BUFFERSIZE)


func MM_Shutdown() -> void:
	if not mmstarted:
		return
	mmstarted = false


## FREEBLOCK: the owner's pointer is cleared.
func _mm_free_block(blk: MMBlock) -> void:
	if blk.key != "":
		mmblocks_by_key.erase(blk.key)
		_mm_cleared(blk.key)


## The C's `*x->useptr = NULL`: the port's copy of the thing goes too.
func _mm_cleared(key: String) -> void:
	var colon: int = key.find(":")
	var kind: String = key.substr(0, colon) if colon >= 0 else key
	var n: int = int(key.substr(colon + 1)) if colon >= 0 else 0
	match kind:
		"gr":
			grsegs[n] = null
		"aud":
			audiosegs[n] = null
		"maphead":
			mapheaderseg[n] = null
		"map":
			mapsegs[n] = PackedInt32Array()


## Allocates an unlocked, unpurgable block.
func MM_GetPtr(key: String, size: int) -> void:
	if not mmstarted:
		return
	if mmblocks_by_key.has(key):
		push_warning("MM_GetPtr: %s allocated twice" % key)
		MM_FreePtr(key)
	@warning_ignore("integer_division")
	var needed: int = (size + 15) / 16
	var mmnew: MMBlock = MMBlock.new()
	mmnew.length = needed
	mmnew.key = key
	for search: int in range(3):
		# first search: right after the rover, then on up; second: from the head up to the
		# rover; third: compress memory, then scan from the start
		if search == 1 and mmrover == mmhead:
			continue
		var lastscan: MMBlock
		var scan: MMBlock
		var endscan: MMBlock = null
		match search:
			0:
				lastscan = mmrover
				scan = mmrover.next
			1:
				lastscan = mmhead
				scan = mmhead.next
				endscan = mmrover
			_:
				MM_SortMem()
				lastscan = mmhead
				scan = mmhead.next
		var startseg: int = lastscan.start + lastscan.length
		while scan != endscan:
			if scan.start - startseg >= needed:
				# enough room between the end of lastscan and the start of scan: throw out
				# anything in the middle and allocate the new block
				var purge: MMBlock = lastscan.next
				lastscan.next = mmnew
				mmnew.start = startseg
				mmnew.next = scan
				while purge != scan:
					var nxt: MMBlock = purge.next
					_mm_free_block(purge)
					purge = nxt
				mmrover = mmnew
				mmblocks_by_key[key] = mmnew
				return
			# a block at purge level zero or locked is skipped past
			if (scan.attributes & MM_LOCKBIT) != 0 or (scan.attributes & MM_PURGEBITS) == 0:
				lastscan = scan
				startseg = lastscan.start + lastscan.length
			scan = scan.next
	Quit("MM_GetPtr: Out of memory!" if current_gamever_int < 110 else "Out of memory!  Please make sure you have enough free memory.")


func MM_FreePtr(key: String) -> void:
	if not mmstarted:
		return
	if mmrover.key == key:    # removed the last allocated block
		mmrover = mmhead
	var last: MMBlock = mmhead
	var scan: MMBlock = last.next
	while scan != null and scan.key != key:
		last = scan
		scan = scan.next
	if scan == null:
		Quit("MM_FreePtr: Block not found!")
		return
	last.next = scan.next
	_mm_free_block(scan)


## The rover moved on to the block (the loops of MM_SetPurge, MM_SetLock, MM_*Attributes).
func _mm_find(key: String, what: String) -> bool:
	var start: MMBlock = mmrover
	while true:
		if mmrover.key == key:
			return true
		mmrover = mmrover.next
		if mmrover == null:
			mmrover = mmhead
		elif mmrover == start:
			Quit("%s: Block not found!" % what)
			return false
	return false


func MM_SetPurge(key: String, purge: int) -> void:
	if not mmstarted or not _mm_find(key, "MM_SetPurge"):
		return
	mmrover.attributes &= ~MM_PURGEBITS
	mmrover.attributes |= purge


func MM_SetLock(key: String, locked: bool) -> void:
	if not mmstarted or not _mm_find(key, "MM_SetLock"):
		return
	mmrover.attributes &= ~MM_LOCKBIT
	mmrover.attributes |= MM_LOCKBIT if locked else 0


func MM_GetAttributes(key: String) -> int:
	if not mmstarted or not _mm_find(key, "MM_SetAttributes"):
		return 0
	return mmrover.attributes


func MM_SetAttributes(key: String, attributes: int) -> void:
	if not mmstarted or not _mm_find(key, "MM_SetAttributes"):
		return
	mmrover.attributes = attributes


## Throws out all purgeable blocks and piles the movable ones down (each moved paragraph costing
## `mmmove`, TIME-D); the border is white meanwhile.
func MM_SortMem() -> void:
	VW_ColorBorder(15)
	BE_ST_ShortSleep()
	if beforesort != &"":
		call(beforesort)
	var moved: int = 0
	var start: int = 0
	var last: MMBlock = null
	var scan: MMBlock = mmhead
	while scan != null:
		if (scan.attributes & MM_LOCKBIT) != 0:
			start = scan.start + scan.length
		elif (scan.attributes & MM_PURGEBITS) != 0:
			var nxt: MMBlock = scan.next
			_mm_free_block(scan)
			last.next = nxt
			scan = nxt
			continue
		else:
			if scan.start != start:
				moved += scan.length
				scan.start = start
			start = scan.start + scan.length
		last = scan
		scan = scan.next
	mmrover = mmhead
	cost_n("mmmove", moved)
	if aftersort != &"":
		call(aftersort)
	VW_ColorBorder(0)


## Free space without purging, in bytes.
func MM_UnusedMemory() -> int:
	var free: int = 0
	var scan: MMBlock = mmhead
	while scan.next != null:
		free += scan.next.start - (scan.start + scan.length)
		scan = scan.next
	return (free & 0xFFFF) * 16


## Free space with purging, in bytes.
func MM_TotalFree() -> int:
	var free: int = 0
	var scan: MMBlock = mmhead
	while scan.next != null:
		if (scan.attributes & MM_PURGEBITS) != 0 and (scan.attributes & MM_LOCKBIT) == 0:
			free += scan.length
		free += scan.next.start - (scan.start + scan.length)
		scan = scan.next
	return (free & 0xFFFF) * 16


# ===================================================================== id_ca.c

var oldsoundmode: int = 0    # sdm_Off


## The header of every graphics chunk in the file, as CA's grstarts (-1 a sparse chunk).
func _grstart(chunk: int) -> int:
	var s: int = data.chunk_start(chunk)
	return -1 if s == 0xFFFFFFFF else s


## The compressed length of a chunk (the next present chunk's start, past sparse tiles).
func _grcompressed(chunk: int) -> int:
	var nxt: int = chunk + 1
	while _grstart(nxt) == -1:
		nxt += 1
	return _grstart(nxt) - _grstart(chunk)


func CA_Startup() -> void:
	CAL_SetupMapFile()
	CAL_SetupGrFile()
	CAL_SetupAudioFile()
	mapon = -1
	ca_levelbit = 1
	ca_levelnum = 0


func CA_Shutdown() -> void:
	pass


## The tile info and the map headers are linked into the program (MAPHEADERLINKED).
func CAL_SetupMapFile() -> void:
	tinf = data.tileinfo
	mapheaderseg.resize(NUMMAPS)
	mapheaderseg.fill(null)


## The graphics headers are linked in (GRHEADERLINKED); the picture and sprite tables are read
## from their chunks, each through a compseg the manager allocates and frees.
func CAL_SetupGrFile() -> void:
	grsegs.resize(NUMCHUNKS)
	grsegs.fill(null)
	grneeded.resize(NUMCHUNKS)
	grneeded.fill(0)
	pictable = []
	for t: Dictionary in data.pic_table:
		var p: pictabletype = pictabletype.new()
		p.width = t.w
		p.height = t.h
		pictable.append(p)
	MM_GetPtr("pictable", NUMPICS * 4)
	MM_GetPtr("compseg", _grcompressed(STRUCTPIC))
	MM_FreePtr("compseg")
	picmtable = []
	for t: Dictionary in data.picm_table:
		var p: pictabletype = pictabletype.new()
		p.width = t.w
		p.height = t.h
		picmtable.append(p)
	MM_GetPtr("picmtable", NUMPICM * 4)
	MM_GetPtr("compseg", _grcompressed(STRUCTPICM))
	MM_FreePtr("compseg")
	spritetable = []
	for t: Dictionary in data.sprite_table:
		var s: spritetabletype = spritetabletype.new()
		s.width = t.w
		s.height = t.h
		s.orgx = t.orgx
		s.orgy = t.orgy
		s.xl = t.xl
		s.yl = t.yl
		s.xh = t.xh
		s.yh = t.yh
		s.shifts = t.shifts
		spritetable.append(s)
	MM_GetPtr("spritetable", NUMSPRITES * 18)
	MM_GetPtr("compseg", _grcompressed(STRUCTSPRITE))
	MM_FreePtr("compseg")


func CAL_SetupAudioFile() -> void:
	audiosegs.resize(NUMSNDCHUNKS)
	audiosegs.fill(null)


func CA_CacheAudioChunk(chunk: int) -> void:
	if audiosegs[chunk] != null:
		MM_SetPurge("aud:%d" % chunk, 0)
		return    # already in memory
	var a: PackedByteArray = data.audio_chunk(chunk)
	var compressed: int = a.size() + 4    # (the expanded length the chunk starts with)
	if compressed > BUFFERSIZE:
		MM_GetPtr("bigbufferseg", compressed)
	MM_GetPtr("aud:%d" % chunk, a.size())
	audiosegs[chunk] = a
	cost_n("audiobyte", a.size())
	if compressed > BUFFERSIZE:
		MM_FreePtr("bigbufferseg")


## Purges all sounds, then loads all new ones (a mode switch).
func CA_LoadAllSounds() -> void:
	var start: int = 0
	var skip_purge: bool = false
	match oldsoundmode:
		sdm_Off:
			skip_purge = true
		sdm_PC:
			start = STARTPCSOUNDS
		sdm_AdLib:
			start = STARTADLIBSOUNDS
		sdm_SoundBlaster, sdm_SoundSource:
			start = STARTDIGISOUNDS
	if not skip_purge:
		for i: int in range(NUMSOUNDS):
			if audiosegs[start + i] != null:
				MM_SetPurge("aud:%d" % (start + i), 3)    # make purgable
	match SoundMode:
		sdm_Off:
			return
		sdm_PC:
			start = STARTPCSOUNDS
		sdm_AdLib:
			start = STARTADLIBSOUNDS
		sdm_SoundBlaster, sdm_SoundSource:
			start = STARTDIGISOUNDS
	for i: int in range(NUMSOUNDS):
		CA_CacheAudioChunk(start + i)
	oldsoundmode = SoundMode


## CAL_ShiftSprite: a shifted (one byte wider) copy of a sprite, `source` at `so` into `dest` at
## `dO` (the C's pointers): the mask (with ones shifted in) then the four planes (zeros).
func _shift_sprite(source: PackedByteArray, so: int, dest: PackedByteArray, dO: int,
		width: int, height: int, pixshift: int) -> void:
	var table: PackedInt32Array = shifttabletable[pixshift]
	var s: int = so
	var d: int = dO
	for i: int in range(height):    # the mask rows
		dest[d] = 0xFF
		for j: int in range(width):
			var val: int = table[source[s] ^ 0xFF] ^ 0xFFFF
			s += 1
			dest[d] &= val & 0xFF
			d += 1
			dest[d] = val >> 8
		d += 1
	for i: int in range(height * 4):    # the four planes
		dest[d] = 0
		for j: int in range(width):
			var val: int = table[source[s]]
			s += 1
			dest[d] |= val & 0xFF
			d += 1
			dest[d] = val >> 8
		d += 1


## The sprite as spritetype_ega: three tables of eight words (sourceoffset, planesize, width),
## then the unshifted image and the shifted copies its `shifts` asks for.
func CAL_CacheSprite(chunk: int, unshifted: PackedByteArray) -> void:
	var spr: spritetabletype = spritetable[chunk - STARTSPRITES]
	var smallplane: int = spr.width * spr.height
	var bigplane: int = (spr.width + 1) * spr.height
	var shiftstarts: PackedInt32Array = PackedInt32Array([MAXSHIFTS_EGA * 6, 0, 0, 0, 0])
	shiftstarts[1] = shiftstarts[0] + smallplane * 5    # 5 planes in a sprite
	shiftstarts[2] = shiftstarts[1] + bigplane * 5
	shiftstarts[3] = shiftstarts[2] + bigplane * 5
	shiftstarts[4] = shiftstarts[3] + bigplane * 5
	if spr.shifts not in [1, 2, 4]:
		Quit("CAL_CacheSprite: Bad shifts number!")
		return
	var expanded: int = shiftstarts[spr.shifts]
	MM_GetPtr("gr:%d" % chunk, expanded)
	var dest: PackedByteArray = PackedByteArray()
	dest.resize(expanded)
	for k: int in range(mini(unshifted.size(), smallplane * 5)):
		dest[shiftstarts[0] + k] = unshifted[k]
	var table: Array = []    # [sourceoffset, planesize, width] per shift
	match spr.shifts:
		1:
			for i: int in range(4):
				table.append([shiftstarts[0], smallplane, spr.width])
		2:
			for i: int in range(2):
				table.append([shiftstarts[0], smallplane, spr.width])
			for i: int in range(2):
				table.append([shiftstarts[1], bigplane, spr.width + 1])
			_shift_sprite(dest, shiftstarts[0], dest, shiftstarts[1], spr.width, spr.height, 4)
		4:
			table.append([shiftstarts[0], smallplane, spr.width])
			table.append([shiftstarts[1], bigplane, spr.width + 1])
			_shift_sprite(dest, shiftstarts[0], dest, shiftstarts[1], spr.width, spr.height, 2)
			table.append([shiftstarts[2], bigplane, spr.width + 1])
			_shift_sprite(dest, shiftstarts[0], dest, shiftstarts[2], spr.width, spr.height, 4)
			table.append([shiftstarts[3], bigplane, spr.width + 1])
			_shift_sprite(dest, shiftstarts[0], dest, shiftstarts[3], spr.width, spr.height, 6)
	for i: int in range(table.size()):
		dest.encode_u16(i * 2, table[i][0])
		dest.encode_u16(16 + i * 2, table[i][1])
		dest.encode_u16(32 + i * 2, table[i][2])
	grsegs[chunk] = dest


## The sprite's tables, as the C's VW_GetSpriteShift* macros read them.
func VW_GetSpriteShiftSourceOffset(block: PackedByteArray, i: int) -> int:
	return block.decode_u16(i * 2)


func VW_GetSpriteShiftPlaneSize(block: PackedByteArray, i: int) -> int:
	return block.decode_u16(16 + i * 2)


func VW_GetSpriteShiftWidth(block: PackedByteArray, i: int) -> int:
	return block.decode_u16(32 + i * 2)


## What is done with a chunk read off disk: sprites are shifted, the rest kept as expanded
## (`_source`: the C's compressed bytes; DreamsData reads them).
func CAL_ExpandGrChunk(chunk: int, _source: Variant) -> void:
	var expanded: PackedByteArray = data.chunk(chunk)
	cost_n("grbyte", _grcompressed(chunk))
	if chunk >= STARTSPRITES and chunk < STARTTILE8:
		CAL_CacheSprite(chunk, expanded)
	else:
		var size: int = expanded.size()
		if chunk >= STARTTILE8:
			# tile chunks have fixed sizes (tile 8s are all in one chunk)
			if chunk < STARTTILE8M:
				size = 32 * NUMTILE8
			elif chunk < STARTTILE16:
				size = 40 * NUMTILE8M
			elif chunk < STARTTILE16M:
				size = 32 * 4
			elif chunk < STARTTILE32:
				size = 40 * 4
			elif chunk < STARTTILE32M:
				size = 32 * 16
			else:
				size = 40 * 16
		MM_GetPtr("gr:%d" % chunk, size)
		grsegs[chunk] = expanded


## The general buffer is enough for a chunk up to BUFFERSIZE; a bigger one gets its own block.
func _read_chunk(chunk: int) -> void:
	var compressed: int = _grcompressed(chunk)
	if compressed > BUFFERSIZE:
		MM_GetPtr("bigbufferseg", compressed)
	CAL_ExpandGrChunk(chunk, null)
	if compressed > BUFFERSIZE:
		MM_FreePtr("bigbufferseg")


func CAL_ReadGrChunk(chunk: int) -> void:
	if _grstart(chunk) < 0:    # a sparse tile
		return
	_read_chunk(chunk)


## Makes sure a chunk is in memory, loading it if needed.
func CA_CacheGrChunk(chunk: int) -> void:
	grneeded[chunk] |= ca_levelbit    # make sure it doesn't get removed
	if grsegs[chunk] != null:
		return
	if _grstart(chunk) < 0:
		return
	_read_chunk(chunk)


func CA_CacheMap(mapnum: int) -> void:
	if mapon > -1 and mapheaderseg[mapon] != null:
		MM_SetPurge("maphead:%d" % mapon, 3)
	for plane: int in range(3):
		if mmblocks_by_key.has("map:%d" % plane):
			MM_FreePtr("map:%d" % plane)
	mapon = mapnum
	var m: Dictionary = {}
	if mapheaderseg[mapnum] == null:
		if not data.has_map(mapnum):
			Quit("CA_CacheMap: Tried to load a non existant map!")
			return
		MM_GetPtr("maphead:%d" % mapnum, 38)
		m = data.load_map(mapnum)
		var h: maptype = maptype.new()
		h.width = m.width
		h.height = m.height
		h.name = m.name
		mapheaderseg[mapnum] = h
	else:
		MM_SetPurge("maphead:%d" % mapnum, 0)
		m = data.load_map(mapnum)
	var hdr: maptype = mapheaderseg[mapnum]
	var size: int = hdr.width * hdr.height * 2
	var sizes: Array = data.map_plane_sizes(mapnum)
	for plane: int in range(3):
		MM_GetPtr("map:%d" % plane, size)
		var compressed: int = sizes[plane][0]
		if compressed > BUFFERSIZE:
			MM_GetPtr("bigbufferseg", compressed)
		MM_GetPtr("buffer2seg", sizes[plane][1])
		mapsegs[plane] = m.plane[plane]
		cost_n("mapword", hdr.width * hdr.height)
		MM_FreePtr("buffer2seg")
		if compressed > BUFFERSIZE:
			MM_FreePtr("bigbufferseg")


## Goes up a bit level in the needed lists and clears it out.
func CA_UpLevel() -> void:
	if ca_levelnum == 7:
		Quit("CA_UpLevel: Up past level 7!")
		return
	ca_levelbit = (ca_levelbit << 1) & 0xFF
	ca_levelnum += 1


## Goes down a bit level and recaches everything from the lower level.
func CA_DownLevel() -> void:
	if ca_levelnum == 0:
		Quit("CA_DownLevel: Down past level 0!")
		return
	ca_levelbit >>= 1
	ca_levelnum -= 1
	CA_CacheMarks(titleptr[ca_levelnum], true)


func CA_ClearMarks() -> void:
	for i: int in range(NUMCHUNKS):
		grneeded[i] &= ~ca_levelbit & 0xFF


func CA_ClearAllMarks() -> void:
	grneeded.fill(0)
	ca_levelbit = 1
	ca_levelnum = 0


const NUMBARS: int = 17 * 8
const BARSTEP: int = 8
const MAXEMPTYREAD: int = 1024


## Caches every chunk marked at this level, with the "Loading" box and its bar when there is a
## title (not when going back down a level, from v1.10 on).
func CA_CacheMarks(title: String, cachedownlevel: bool) -> void:
	var barcolor: int = 14
	titleptr[ca_levelnum] = title
	var dialog: bool = title != ""
	if current_gamever_int >= 110 and cachedownlevel:
		dialog = false
	var homex: int = 0
	var homey: int = 0
	if dialog:
		US_CenterWindow(20, 8)
		homex = PrintX
		homey = PrintY
		US_CPrint("Loading")
		fontcolor = F_SECONDCOLOR
		US_CPrint(title)
		fontcolor = F_BLACK
		VW_UpdateScreen()
	var numcache: int = 0
	for i: int in range(NUMCHUNKS):
		if (grneeded[i] & ca_levelbit) != 0:
			if grsegs[i] != null:
				MM_SetPurge("gr:%d" % i, 0)    # already in memory: make sure it stays
			else:
				numcache += 1
		elif grsegs[i] != null:
			MM_SetPurge("gr:%d" % i, 3)    # not needed: purgeable
	if numcache == 0:
		return
	var thx: int = 0
	var thy: int = 0
	var barx: int = 0
	var lastx: int = 0
	if dialog:
		thx = homex + 8
		thy = homey + 32
		VWB_DrawTile8(thx, thy, 11)
		VWB_DrawTile8(thx, thy + 8, 14)
		VWB_DrawTile8(thx, thy + 16, 17)
		VWB_DrawTile8(thx + 17 * 8, thy, 13)
		VWB_DrawTile8(thx + 17 * 8, thy + 8, 16)
		VWB_DrawTile8(thx + 17 * 8, thy + 16, 19)
		var x: int = thx + 8
		while x < thx + 17 * 8:
			VWB_DrawTile8(x, thy, 12)
			VWB_DrawTile8(x, thy + 8, 15)
			VWB_DrawTile8(x, thy + 16, 18)
			x += 8
		thx += 4    # first line location
		thy += 5
		barx = thx << 16
		lastx = thx
		VW_UpdateScreen()
	@warning_ignore("integer_division")
	var barstep: int = (NUMBARS << 16) / numcache
	for i: int in range(NUMCHUNKS):
		if quitting:
			return
		if (grneeded[i] & ca_levelbit) == 0 or grsegs[i] != null:
			continue
		if dialog:
			barx += barstep
			var xh: int = barx >> 16
			if xh - lastx > BARSTEP:
				for x: int in range(lastx, xh + 1):
					VWB_Vlin(thy, thy + 13, x, barcolor)
				lastx = xh
				VW_UpdateScreen()
				BE_ST_ShortSleep()
		if _grstart(i) < 0:
			continue
		_read_chunk(i)
	if dialog:
		var xh2: int = thx + NUMBARS
		for x: int in range(lastx, xh2 + 1):
			VWB_Vlin(thy, thy + 13, x, barcolor)
		VW_UpdateScreen()
		BE_ST_ShortSleep()
