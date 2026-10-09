# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01b (first part): the Dreams refresh manager (DrmRF) on a real map of
## Keen Dreams v1.00, without DrmVW's drawing: the tables RF_Startup and
## RF_NewMap derive, the animated tile chains RF_MarkTileGraphics finds, the
## origin math and update arrays of RF_NewPosition, the tiles it draws into
## the master screen (through DrmBE), RFL_UpdateTiles' and
## RFL_MaskForegroundTiles' copies, RF_Scroll's floating of screens and update
## arrays, RFL_AnimateTiles, and the sprite lists of RF_PlaceSprite and
## RF_RemoveSprite. The values are worked out here from the map, as the C does.
##
## Options: --game_data=<folder>

var t: T = T.new()


## DrmRF with the timer stubbed (DrmIO's comes later in the chain).
class Rig extends DrmRF:
	var timecount: int = 0

	func SD_GetTimeCount() -> int:
		return timecount


## A sprite owner (objtype's `sprite` field).
class Owner:
	var sprite: Variant = null


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var d: DreamsData = DreamsData.new()
	if not d.load_game(root.path_join("kdreams")):
		t.blocked("Keen Dreams v1.00 does not load: " + d.error)
		t.finish(self)
		return
	var r: Rig = Rig.new()
	r.data = d
	r.vm = DosMachine.new()
	r.BE_ST_SetScreenMode(0x0D)
	r.refkeen_current_gamever = r.BE_GAMEVER_KDREAMSE100
	r.MM_Startup()
	r.CA_Startup()
	# id_ca.c: tinf is the whole map header (mapfiletype; the tile info at SPEED = 502)
	if r.tinf.size() == d.tileinfo.size():
		print("  (tinf set to the whole map header: DrmCA's CAL_SetupMapFile leaves out its 502 bytes)")
		r.tinf = d._map_head
	# id_vw_a.c's shift tables and id_vw.c's ylookup (DrmVW's, when it has them)
	if r.shifttabletable.size() < 8:
		r.shifttabletable = []
		for s: int in range(8):
			var tab: PackedInt32Array = PackedInt32Array()
			tab.resize(256)
			for v: int in range(256):
				tab[v] = (v >> s) | (((v << (8 - s)) & 0xFF) << 8)
			r.shifttabletable.append(tab)
	if r.ylookup.size() < r.VIRTUALHEIGHT:
		r.ylookup.resize(r.VIRTUALHEIGHT)
		for i: int in range(r.VIRTUALHEIGHT):
			r.ylookup[i] = i * r.SCREENWIDTH_EGA

	_startup(r)
	var mapnum: int = _pick_map(r)
	if mapnum < 0:
		t.blocked("no map with animated tiles")
		t.finish(self)
		return
	_newmap(r, mapnum)
	_marktiles(r)
	# cache what RF_MarkTileGraphics marked (CA_CacheMarks without its dialog)
	for c: int in range(r.NUMCHUNKS):
		if r.grneeded[c] & r.ca_levelbit:
			r.CA_CacheGrChunk(c)
	_origin(r)
	_newposition(r)
	_updatetiles(r)
	_scroll(r)
	_animate(r)
	_sprites(r)
	t.ok("no Quit (%s)" % r.quit_message, not r.quitting)
	t.finish(self)


func _startup(r: Rig) -> void:
	r.RefKeen_Patch_id_rf()
	r.RefKeen_Patch_id_rf_a()
	r.RF_Startup()
	t.ok("RefKeen_Patch_id_rf: the EGA routines", r.RF_NewPosition == &"RF_NewPosition_EGA"
		and r.RF_Scroll == &"RF_Scroll_EGA" and r.RF_PlaceSprite == &"RF_PlaceSprite_EGA"
		and r.RF_RemoveSprite == &"RF_RemoveSprite_EGA" and r.RF_Refresh == &"RF_Refresh_EGA"
		and r.RFL_NewTile == &"RFL_NewTile_EGA")
	t.eq("v1.00's allanims offset", r.refkeen_compat_id_rf_allanims_table_offset, 0xC128)
	var ok: bool = true
	for i: int in range(r.PORTTILESHIGH):
		ok = ok and r.uwidthtable[i] == 22 * i
	for y: int in range(r.UPDATEHIGH):
		for x: int in range(r.UPDATEWIDE):
			ok = ok and r.blockstarts[y * 22 + x] == 64 * 16 * y + 2 * x
	t.ok("RF_Startup: uwidthtable and blockstarts", ok)
	t.ok("RF_Startup: pages (display %d, buffer %d, master %d)" % [r.displayofs, r.bufferofs, r.masterofs],
		r.displayofs == 0 and r.bufferofs == 15360 and r.masterofs == 30720 and r.screenpage == 0 and r.otherpage == 1)
	t.ok("RF_Startup: update pointers (%d, %d, %d)" % [r.baseupdatestart[0], r.baseupdatestart[1], r.updateptr],
		r.update.size() == 812 and r.baseupdatestart[0] == 48 and r.baseupdatestart[1] == 454 and r.updateptr == 454)
	t.ok("RF_Startup: origin minimum, SX_T_SHIFT, xpanmask", r.originxmin == 512 and r.originymin == 512
		and r.SX_T_SHIFT == 1 and r.xpanmask == 6 and not r.compatability)
	r.RF_SetRefreshHook(&"SomeHook")
	t.eq("RF_SetRefreshHook", r.refreshvector, &"SomeHook")
	r.RF_SetRefreshHook(&"")


## The first level-sized map with animated tiles in both planes, or any.
func _pick_map(r: Rig) -> int:
	var fallback: int = -1
	for n: int in range(1, DreamsData.NUM_MAPS):    # the levels (map 0 is the world map)
		if not r.data.has_map(n):
			continue
		var m: Dictionary = r.data.load_map(n)
		if m.is_empty() or m.width < 30 or m.height < 20:
			continue
		var bg: bool = false
		var fg: bool = false
		for v: int in m.plane[0]:
			if v < 0x8000 and r._rf_tinf(r.ANIM + v) != 0:
				bg = true
				break
		for v: int in m.plane[1]:
			if v < 0x8000 and r._rf_tinf(r.MANIM + v) != 0:
				fg = true
				break
		if bg and fg:
			return n
		if (bg or fg) and fallback < 0:
			fallback = n
	return fallback


func _newmap(r: Rig, mapnum: int) -> void:
	r.CA_CacheMap(mapnum)
	r.timecount = 1234
	r.RF_NewMap()
	var w: int = r.mapwidth
	var h: int = r.mapheight
	print("  map %d (%s): %dx%d" % [mapnum, r.mapheaderseg[mapnum].name, w, h])
	t.ok("RF_NewMap: size", w == r.mapheaderseg[mapnum].width and h == r.mapheaderseg[mapnum].height
		and r.mapbyteswide == 2 * w and r.mapwordsextra == w - 21 and r.mapbytesextra == 2 * (w - 21))
	var ok: bool = true
	for i: int in range(h):
		ok = ok and r.mapbwidthtable[i] == i * 2 * w
	t.ok("RF_NewMap: mapbwidthtable", ok)
	ok = true
	for y: int in range(14):
		for x: int in range(22):
			ok = ok and r.updatemapofs[y * 22 + x] == y * 2 * w + 2 * x
	t.ok("RF_NewMap: updatemapofs", ok)
	t.ok("RF_NewMap: origin maximum (%d, %d)" % [r.originxmax, r.originymax],
		r.originxmax == maxi((w - 22) * 256, 512) and r.originymax == maxi((h - 15) * 256, 512))
	t.ok("RF_NewMap: lists cleared, timing", r.animhead == null and r.spritefreeptr == r.spritearray[0]
		and r.prioritystart == [null, null, null, null] and r.lasttimecount == 1234 and r.tics == 1)
	var n: int = 0
	var s: DrmRF.spritelisttype = r.spritefreeptr
	while s != null:
		n += 1
		s = s.nextsprite
	t.eq("RF_NewMap: free sprite list", n, r.MAXSPRITES)


func _marktiles(r: Rig) -> void:
	var w: int = r.mapwidth
	var size: int = w * r.mapheight
	var p0: PackedInt32Array = r.mapsegs[0]
	var p1: PackedInt32Array = r.mapsegs[1]
	var info0: PackedInt32Array = r.mapsegs[2].duplicate()
	# the chains, as the C finds them: background tiles in map order, then foreground ones
	var chains: Array = []
	var speeds: Array = []
	var want_info: PackedInt32Array = info0.duplicate()
	for pos: int in range(size):
		var v: int = p0[pos]
		if v < 0x8000 and r._rf_tinf(r.ANIM + v) != 0:
			if not chains.has(v):
				chains.append(v)
				speeds.append(r._rf_tinf(r.SPEED + v))
			want_info[pos] = 0xC128 + 4 * chains.find(v)
	for pos: int in range(size):
		var v: int = p1[pos]
		if v < 0x8000 and r._rf_tinf(r.MANIM + v) != 0:
			if not chains.has(v | 0x8000):
				chains.append(v | 0x8000)
				speeds.append(r._rf_tinf(r.MSPEED + v))
			want_info[pos] = 0xC128 + 4 * chains.find(v | 0x8000)
	r.CA_ClearAllMarks()
	r.RF_MarkTileGraphics()
	var got: Array = []
	var gotspeeds: Array = []
	for i: int in range(r.numanimchains):
		got.append(r.allanims[i].current)
		gotspeeds.append(r.allanims[i].count)
	print("  %d animation chains" % chains.size())
	t.eq("RF_MarkTileGraphics: the chains", got, chains)
	t.eq("RF_MarkTileGraphics: their counts", gotspeeds, speeds)
	t.ok("RF_MarkTileGraphics: allanims ends after them", r.numanimchains >= r.MAXANIMTYPES
		or r.allanims[r.numanimchains].current == 0)
	t.ok("RF_MarkTileGraphics: the info plane holds the DOS pointers", r.mapsegs[2] == want_info)
	# every tile marked, with every stage of its animation
	var ok: bool = true
	for pos: int in range(size):
		ok = ok and (r.grneeded[r.STARTTILE16 + p0[pos]] & 1) != 0 and (r.grneeded[r.STARTTILE16M + p1[pos]] & 1) != 0
	for c: int in chains:
		var tile: int = c & 0x7FFF
		var base: int = r.STARTTILE16M if c & 0x8000 else r.STARTTILE16
		var anim: int = r.MANIM if c & 0x8000 else r.ANIM
		var nxt: int = tile + DrmDecl.s8(r._rf_tinf(anim + tile))
		while nxt != tile:
			ok = ok and (r.grneeded[base + nxt] & 1) != 0
			nxt += DrmDecl.s8(r._rf_tinf(anim + nxt))
	t.ok("RF_MarkTileGraphics: tiles and animation stages marked", ok)


## RFL_CalcOriginStuff through RF_NewPosition: clamping, tiles, panning.
func _origin(r: Rig) -> void:
	r.RF_NewPosition_EGA(0, 0)
	t.ok("origin (0,0) clamps to the border", r.originxglobal == 512 and r.originyglobal == 512
		and r.originxtile == 2 and r.originytile == 2 and r.originxscreen == 4 and r.originyscreen == 32
		and r.originmap == r.mapbwidthtable[2] + 4 and r.panx == 0 and r.pany == 0 and r.panadjust == 0)
	r.RF_NewPosition_EGA(512 + 0x135, 512 + 0x2A7)
	t.ok("origin (0x335,0x4A7): tiles 3,4, pan 3/10 (panadjust %d)" % r.panadjust,
		r.originxglobal == 0x335 and r.originyglobal == 0x4A7 and r.originxtile == 3 and r.originytile == 4
		and r.originxscreen == 6 and r.originyscreen == 64 and r.panx == 3 and r.pansx == 0
		and r.pany == 10 and r.pansy == 10 and r.panadjust == 640 and r.originmap == r.mapbwidthtable[4] + 6)
	r.RF_NewPosition_EGA(0x8000 + 0x93, 0x8000)
	t.ok("origin past the end clamps to the maximum", r.originxglobal == r.originxmax
		and r.originyglobal == r.originymax and r.originxtile == r.originxmax >> 8)
	r.RF_NewPosition_EGA(512 + 0x1A8, 512)
	t.ok("origin pans to 8 pixels", r.panx == 10 and r.pansx == 8 and r.panadjust == 1)


## The anim tiles of the window at the origin, as "x,y,plane".
func _window_anims(r: Rig) -> Array:
	var out: Array = []
	var w: int = r.mapwidth
	for my: int in range(14):
		for mx: int in range(21):
			var pos: int = (r.originytile + my) * w + r.originxtile + mx
			if r._rf_tinf(r.ANIM + r.mapsegs[0][pos]) != 0:
				out.append("%d,%d,0" % [r.originxtile + mx, r.originytile + my])
			if r._rf_tinf(r.MANIM + r.mapsegs[1][pos]) != 0:
				out.append("%d,%d,1" % [r.originxtile + mx, r.originytile + my])
	out.sort()
	return out


func _anim_list(r: Rig) -> Array:
	var out: Array = []
	var a: DrmRF.animtiletype = r.animhead
	while a != null:
		out.append("%d,%d,%d" % [a.x, a.y, a.mapplane])
		a = a.nexttile
	out.sort()
	return out


## The bytes the master screen should hold for map tile (tx,ty), plane p.
func _tile_bytes(r: Rig, tx: int, ty: int, p: int) -> PackedByteArray:
	var pos: int = ty * r.mapwidth + tx
	var bg: int = r.mapsegs[0][pos]
	var fg: int = r.mapsegs[1][pos]
	var back: PackedByteArray = r._rf_grseg(r.STARTTILE16 + bg)
	var out: PackedByteArray = PackedByteArray()
	if fg == 0:
		return back.slice(p * 32, p * 32 + 32)
	var fore: PackedByteArray = r._rf_grseg(r.STARTTILE16M + fg)
	for i: int in range(32):
		out.append((back[p * 32 + i] & fore[i]) | fore[32 * (p + 1) + i])
	return out


func _screen_bytes(r: Rig, ofs: int, p: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for row: int in range(16):
		out.append(r.BE_ST_EGAFetchGFXByteFromPlane(ofs + row * 64, p))
		out.append(r.BE_ST_EGAFetchGFXByteFromPlane(ofs + row * 64 + 1, p))
	return out


## Every window tile in the master screen (or one column `only`).
func _master_ok(r: Rig, only: int = -1) -> bool:
	for my: int in range(14):
		for mx: int in range(21):
			if only >= 0 and mx != only:
				continue
			var ofs: int = r.masterofs + r.blockstarts[my * 22 + mx]
			for p: int in range(4):
				if _screen_bytes(r, ofs, p) != _tile_bytes(r, r.originxtile + mx, r.originytile + my, p):
					print("    master tile %d,%d plane %d differs" % [mx, my, p])
					return false
	return true


func _page_ok(r: Rig, start: int) -> bool:
	for y: int in range(14):
		for x: int in range(22):
			if r.update[start + y * 22 + x] != (1 if x < 21 else 0):
				return false
	return r.update[start + 308] == 1 and r.update[start + 309] == 3


func _newposition(r: Rig) -> void:
	# a window with a masked foreground tile in it, if the map has one
	var at: Vector2i = Vector2i(8, 5)
	var w: int = r.mapwidth
	for y: int in range(6, r.mapheight - 9):
		for x: int in range(8, w - 14):
			var fg: int = r.mapsegs[1][y * w + x]
			if at == Vector2i(8, 5) and fg != 0 and r._rf_tinf(r.INTILE + fg) & 0x80:
				at = Vector2i(x - 6, y - 4)
	r.RF_NewPosition_EGA(at.x * 256, at.y * 256)
	t.ok("RF_NewPosition: update arrays at their base, all 1s, 0s at row ends, terminated",
		r.updatestart[0] == r.baseupdatestart[0] and r.updatestart[1] == r.baseupdatestart[1]
		and _page_ok(r, r.updatestart[0]) and _page_ok(r, r.updatestart[1]))
	var want: Array = _window_anims(r)
	t.eq("RF_NewPosition: the animating tiles of the window (%d)" % want.size(), _anim_list(r), want)
	t.ok("RF_NewPosition: every tile drawn into the master screen", _master_ok(r))
	# the cache: each plain background tile cached where it was first drawn
	var ok: bool = true
	var seen: Dictionary = {}
	for my: int in range(14):
		for mx: int in range(21):
			var pos: int = (r.originytile + my) * r.mapwidth + r.originxtile + mx
			if r.mapsegs[1][pos] == 0 and not seen.has(r.mapsegs[0][pos]):
				seen[r.mapsegs[0][pos]] = true
				ok = ok and r.tilecache[r.mapsegs[0][pos]] == r.masterofs + r.blockstarts[my * 22 + mx]
	t.ok("RF_NewPosition: tilecache holds each plain tile's first spot (%d tiles)" % seen.size(), ok)


func _updatetiles(r: Rig) -> void:
	r.updateptr = r.updatestart[r.otherpage]
	r.RFL_UpdateTiles()
	var ok: bool = true
	for row: int in range(224):
		for b: int in range(42):
			for p: int in range(4):
				if r.BE_ST_EGAFetchGFXByteFromPlane(r.bufferofs + row * 64 + b, p) \
						!= r.BE_ST_EGAFetchGFXByteFromPlane(r.masterofs + row * 64 + b, p):
					ok = false
	t.ok("RFL_UpdateTiles: the whole port copied from the master screen", ok)
	# a masked foreground tile under a 3
	var spot: int = -1
	for my: int in range(14):
		for mx: int in range(21):
			var pos: int = (r.originytile + my) * r.mapwidth + r.originxtile + mx
			var fg: int = r.mapsegs[1][pos]
			if spot < 0 and fg != 0 and r._rf_tinf(r.INTILE + fg) & 0x80:
				spot = my * 22 + mx
	if spot < 0:
		print("  (no masked foreground tile in the window: RFL_MaskForegroundTiles not checked)")
		return
	var ofs: int = r.bufferofs + r.blockstarts[spot]
	var pos2: int = (r.originytile + spot / 22) * r.mapwidth + r.originxtile + spot % 22
	var fore: PackedByteArray = r._rf_grseg(r.STARTTILE16M + r.mapsegs[1][pos2])
	var want: Array = []
	for p: int in range(4):
		var before: PackedByteArray = _screen_bytes(r, ofs, p)
		var w: PackedByteArray = PackedByteArray()
		for i: int in range(32):
			w.append((before[i] & fore[i]) | fore[32 * (p + 1) + i])
		want.append(w)
	r.update[r.updateptr + spot] = 3
	r.RFL_MaskForegroundTiles()
	ok = r.planenum == 4
	for p: int in range(4):
		ok = ok and _screen_bytes(r, ofs, p) == want[p]
	t.ok("RFL_MaskForegroundTiles: masked tile at %d drawn over the buffer" % spot, ok)
	r.update[r.updateptr + spot] = 1


func _scroll(r: Rig) -> void:
	var x0: int = r.originxglobal
	var ss: PackedInt32Array = r.screenstart.duplicate()
	var us: PackedInt32Array = r.updatestart.duplicate()
	r.RF_Scroll_EGA(16, 0)
	t.ok("RF_Scroll by a pixel: origin moves, nothing floats", r.originxglobal == x0 + 16
		and r.screenstart == ss and r.updatestart == us and r.panx == 1)
	# one tile right
	var oldxt: int = r.originxtile
	var oldcol: Array = []
	for my: int in range(14):
		var pos: int = (r.originytile + my) * r.mapwidth + oldxt
		if r.mapsegs[1][pos] == 0:
			oldcol.append(r.mapsegs[0][pos])
	r.RF_Scroll_EGA(256, 0)
	t.ok("RF_Scroll right: a tile on, screens float 2 bytes", r.originxtile == oldxt + 1
		and r.screenstart[0] == ss[0] + 2 and r.screenstart[1] == ss[1] + 2 and r.screenstart[2] == ss[2] + 2
		and r.bufferofs == r.screenstart[1] and r.displayofs == r.screenstart[0] and r.masterofs == r.screenstart[2])
	t.ok("RF_Scroll right: update arrays float 1", r.updatestart[0] == us[0] + 1 and r.updatestart[1] == us[1] + 1)
	var ok: bool = true
	for page: int in range(2):
		var s: int = r.updatestart[page]
		for y: int in range(14):
			ok = ok and r.update[s + y * 22 + 20] == 1 and r.update[s + y * 22 + 21] == 0
		ok = ok and r.update[s + 307] == 0 and r.update[s + 308] == 1 and r.update[s + 309] == 3
	t.ok("RF_Scroll right: new column marked, rows and array terminated", ok)
	t.ok("RF_Scroll right: new column drawn into the master screen", _master_ok(r, 20))
	t.eq("RF_Scroll right: animating tiles follow the window", _anim_list(r), _window_anims(r))
	ok = true
	for bg: int in oldcol:
		ok = ok and r.tilecache[bg] == 0
	t.ok("RFL_OldRow: the old column's plain tiles uncached", ok)
	# one tile down, left, up: back where it was
	var yt: int = r.originytile
	r.RF_Scroll_EGA(0, 256)
	t.ok("RF_Scroll down: update arrays float a row, screens 16 lines", r.originytile == yt + 1
		and r.updatestart[0] == us[0] + 23 and r.screenstart[2] == ss[2] + 2 + 1024)
	ok = true
	for page: int in range(2):
		var s: int = r.updatestart[page]
		for x: int in range(21):
			ok = ok and r.update[s + 13 * 22 + x] == 1
		ok = ok and r.update[s + 13 * 22 + 21] == 0 and r.update[s + 309] == 3
	t.ok("RF_Scroll down: new row marked", ok and _master_ok(r))
	t.eq("RF_Scroll down: animating tiles follow the window", _anim_list(r), _window_anims(r))
	r.RF_Scroll_EGA(-256, 0)
	r.RF_Scroll_EGA(0, -256)
	t.ok("RF_Scroll left and up: back at the start", r.originxtile == oldxt and r.originytile == yt
		and r.updatestart == us and r.screenstart == ss and _master_ok(r))
	t.eq("RF_Scroll left and up: animating tiles follow the window", _anim_list(r), _window_anims(r))
	r.RF_Scroll_EGA(3 * 256, 0)
	t.ok("RF_Scroll three tiles: a new position (update arrays back at their base)",
		r.originxtile == oldxt + 3 and r.updatestart[0] == r.baseupdatestart[0] and _page_ok(r, r.updatestart[0]))


func _animate(r: Rig) -> void:
	# a background animating tile, with the window around it
	var w: int = r.mapwidth
	var found: Vector2i = Vector2i(-1, -1)
	for y: int in range(4, r.mapheight - 4):
		for x: int in range(4, w - 4):
			var v: int = r.mapsegs[0][y * w + x]
			if found.x < 0 and r._rf_tinf(r.ANIM + v) != 0 and r.mapsegs[1][y * w + x] == 0:
				found = Vector2i(x, y)
	if found.x < 0:
		print("  (no plain animating background tile: RFL_AnimateTiles not checked)")
		return
	r.RF_NewPosition_EGA((found.x - 8) * 256, (found.y - 6) * 256)
	var mx: int = found.x - r.originxtile
	var my: int = found.y - r.originytile
	if mx < 0 or mx >= 21 or my < 0 or my >= 14:
		print("  (the animating tile at %s is outside the window)" % found)
		return
	var tile: int = r.mapsegs[0][found.y * w + found.x]
	var k: int = (r.mapsegs[2][found.y * w + found.x] - 0xC128) / 4
	t.eq("the animating tile's chain", r.allanims[k].current, tile)
	# what every chain becomes after a tic, with this one due
	r.allanims[k].count = 1
	var want: Array = []
	for i: int in range(r.numanimchains):
		var a: DrmRF.tiletype = r.allanims[i]
		var cur: int = a.current
		var cnt: int = a.count - 1
		while cnt < 1:
			var base: int = cur & 0x7FFF
			if cur & 0x8000:
				base += DrmDecl.s8(r._rf_tinf(r.MANIM + base))
				cnt += r._rf_tinf(r.MSPEED + base)
				cur = base | 0x8000
			else:
				base += DrmDecl.s8(r._rf_tinf(r.ANIM + base))
				cnt += r._rf_tinf(r.SPEED + base)
				cur = base
		want.append([cur, cnt])
	for i: int in range(r.update.size()):
		r.update[i] = 0
	r.tics = 1
	r.RFL_AnimateTiles()
	var got: Array = []
	for i: int in range(r.numanimchains):
		got.append([r.allanims[i].current, r.allanims[i].count])
	t.eq("RFL_AnimateTiles: every chain steps", got, want)
	var nt: int = want[k][0]
	t.ok("RFL_AnimateTiles: tile %d -> %d in the map, marked in both pages, drawn" % [tile, nt],
		nt != tile and r.mapsegs[0][found.y * w + found.x] == nt
		and r.update[r.updatestart[0] + my * 22 + mx] == 1 and r.update[r.updatestart[1] + my * 22 + mx] == 1
		and _master_ok(r, mx))


func _sprites(r: Rig) -> void:
	var sn: int = -1
	for i: int in range(r.spritetable.size()):
		if r.spritetable[i].shifts == 4 and r.spritetable[i].width > 1:
			sn = r.STARTSPRITES + i
			break
	if sn < 0:
		t.blocked("no four-shift sprite")
		return
	r.CA_CacheGrChunk(sn)
	var spr: DrmDecl.spritetabletype = r.spritetable[sn - r.STARTSPRITES]
	var block: PackedByteArray = r.grsegs[sn]
	var a: Owner = Owner.new()
	var gx: int = r.originxglobal + 0x234
	var gy: int = r.originyglobal + 0x567
	r.call(r.RF_PlaceSprite, a, gx, gy, sn, r.spritedraw, 1)
	var s: DrmRF.spritelisttype = a.sprite
	var pixx: int = (gx + spr.orgx) >> 4
	var shift: int = (pixx & 7) / 2
	var sx: int = pixx >> 3
	var sy: int = (gy + spr.orgy) >> 4
	var width: int = r.VW_GetSpriteShiftWidth(block, shift)
	t.ok("RF_PlaceSprite: a record from the free list (index %d)" % (s.index if s else -1),
		s == r.spritearray[0] and r.spritefreeptr == r.spritearray[1] and r.prioritystart[1] == s
		and s.prevptr == -2 and s.nextsprite == null)
	t.ok("RF_PlaceSprite: position %d,%d shift %d width %d" % [s.screenx, s.screeny, s.shift, s.width],
		s.screenx == sx and s.screeny == sy and s.shift == shift and s.width == width
		and s.height == spr.height and s.grseg == sn and s.priority == 1 and s.updatecount == 2
		and s.sourceofs == r.VW_GetSpriteShiftSourceOffset(block, shift)
		and s.planesize == r.VW_GetSpriteShiftPlaneSize(block, shift)
		and s.tilex == sx >> 1 and s.tiley == sy >> 4
		and s.tilewide == ((sx + width - 1) >> 1) - (sx >> 1) + 1
		and s.tilehigh == ((sy + spr.height - 1) >> 4) - (sy >> 4) + 1)
	# moved while still due two refreshes: no erase; due one: the shown page; drawn: both
	r.call(r.RF_PlaceSprite, a, gx + 16, gy, sn, r.spritedraw, 1)
	t.ok("RF_PlaceSprite again (updatecount 2): no erase blocks", r.eraselistptr[0] == 0 and r.eraselistptr[1] == 100)
	s.updatecount = 1
	var oldx: int = s.screenx
	r.call(r.RF_PlaceSprite, a, gx + 64, gy, sn, r.spritedraw, 1)
	t.ok("RF_PlaceSprite (updatecount 1): an erase block on the shown page", r.eraselistptr[0] == 1
		and r.eraselistptr[1] == 100 and r.eraselist[0].screenx == oldx and r.eraselist[0].width == s.width)
	s.updatecount = 0
	oldx = s.screenx
	r.call(r.RF_PlaceSprite, a, gx + 128, gy, sn, r.spritedraw, 2)
	t.ok("RF_PlaceSprite (updatecount 0): erase blocks on both pages", r.eraselistptr[0] == 2
		and r.eraselistptr[1] == 101 and r.eraselist[100].screenx == oldx and r.eraselist[1].screenx == oldx
		and r.eraselist[100].screeny == sy and r.eraselist[100].height == spr.height)
	t.ok("RF_PlaceSprite to priority 2: relinked", r.prioritystart[1] == null and r.prioritystart[2] == s
		and s.prevptr == -3 and a.sprite == s)
	var b: Owner = Owner.new()
	r.call(r.RF_PlaceSprite, b, gx, gy, sn, r.maskdraw, 2)
	var s2: DrmRF.spritelisttype = b.sprite
	t.ok("a second sprite at priority 2 heads the list", s2 == r.spritearray[1] and r.prioritystart[2] == s2
		and s2.nextsprite == s and s.prevptr == s2.index and s2.draw == r.maskdraw)
	s.width = 0
	r.RF_RefreshSpriteList()
	t.ok("RF_RefreshSpriteList: widths from the block again", s.width == r.VW_GetSpriteShiftWidth(block, s.shift))
	r.call(r.RF_RemoveSprite, a)
	t.ok("RF_RemoveSprite: unlinked, freed, owner cleared", a.sprite == null and r.prioritystart[2] == s2
		and s2.nextsprite == null and r.spritefreeptr == s and s.nextsprite == r.spritearray[2]
		and r.eraselistptr[0] == 2)
	r.call(r.RF_PlaceSprite, b, gx, gy, 0, r.spritedraw, 2)
	t.ok("RF_PlaceSprite with no sprite number removes it", b.sprite == null and r.prioritystart[2] == null
		and r.spritefreeptr == s2 and s2.nextsprite == s and r.eraselistptr[0] == 2)
	r.call(r.RF_RemoveSprite, b)
	t.ok("RF_RemoveSprite of nothing does nothing", r.spritefreeptr == s2)
	var c: Owner = Owner.new()
	r.call(r.RF_PlaceSprite, c, gx, gy, sn, r.spritedraw, 0)
	t.ok("freed records are reused first", c.sprite == s2 and r.prioritystart[0] == s2)
