# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name VortDrawRenderer
extends RefCounted
## REND-01 (Keen 1-3): a refresh's draw list (VortLib.draw_list) made into the picture, without the
## EGA card: the visible map tiles through the animation table, the sprites under their masks, the
## tiles placed over them and the pictures, on a page laid out as the original's (48 bytes a row, the
## tile grid 32 pixels in on both axes), then the 320x200 the start address and panning show.
## At 1x it must equal the card's picture (tests/rend01_vorticons.gd); the larger sizes and smooth
## motion are later units (REND-02, REND-03), which read the same list.

const PAGE_W: int = 384    # SCREENWIDTH (48 bytes) of pixels
const PAGE_H: int = 288
const GRID: int = 32       # the tile grid's first pixel on the page, both axes
const W: int = 320
const H: int = 200

var _page: PackedByteArray = PackedByteArray()


## The picture of `list` (palette indices, 320x200), drawn with the engine's tables and graphics.
## Empty when the page holds something this renderer doesn't draw (a window or text printed over
## the play, a user routine): the shell shows the card's picture then.
func render(eng: Object, list: Dictionary) -> PackedByteArray:
	if list.is_empty() or str(list.user) != "" or eng.draw_overlaid[int(list.page)]:
		return PackedByteArray()
	_page.resize(PAGE_W * PAGE_H)
	_page.fill(0)
	var data: Object = eng.data
	var tiles: PackedByteArray = data.tiles
	var anim: PackedInt32Array = eng.tile_anim
	var abase: int = int(list.animtable) * eng.MAXTILES
	var grid: PackedInt32Array = list.grid
	# the map's visible tiles (as the refresh saw them), as _draw_page lays them
	for ty: int in range(eng.PORTTILESHIGH):
		for tx: int in range(eng.PORTTILESWIDE):
			var tile: int = grid[ty * eng.PORTTILESWIDE + tx]
			var t: int = (anim[abase + tile] >> 5) if tile < eng.MAXTILES else 0
			_tile(tiles, t, GRID + tx * 16, GRID + ty * 16)
	# the sprites (xcoord in bytes), merged plane by plane under their masks as DrawSprite does
	var sprites: PackedByteArray = eng.egasprites
	var plane: int = eng.spriteplanesize
	for s: Array in list.sprites:
		var e: Dictionary = eng.spritetable[s[2]]
		_sprite(sprites, plane, e, int(s[0]) * 8, int(s[1]))
	# the tiles placed over sprites: plain ones replace, masked ones (the sign bit) take the next
	# tile's bits as their mask, as the original's latch layout gives them
	for t: Array in list.tiles:
		var num: int = int(t[2])
		if (num & 0x8000) == 0:
			_tile(tiles, anim[abase + num] >> 5, int(t[0]) * 8, int(t[1]))
		else:
			_masked_tile(tiles, num & 0x7FFF, int(t[0]) * 8, int(t[1]))
	# the pictures
	for p: Array in list.pics:
		var pic: Dictionary = data.pics[int(p[2])]
		_blit(pic.pixels, int(pic.w), int(pic.h), int(p[0]) * 8, int(p[1]))
	# the window the start address and panning show
	var x0: int = GRID + ((int(list.originx) >> 8) & 15)
	var y0: int = GRID + ((int(list.originy) >> 8) & 15)
	var out: PackedByteArray = PackedByteArray()
	out.resize(W * H)
	for y: int in range(H):
		var row: PackedByteArray = _page.slice((y0 + y) * PAGE_W + x0, (y0 + y) * PAGE_W + x0 + W)
		for x: int in range(W):
			out[y * W + x] = row[x]
	return out


func _tile(tiles: PackedByteArray, t: int, px: int, py: int) -> void:
	var src: int = t * 256
	if src + 256 > tiles.size():
		return
	for r: int in range(16):
		var y: int = py + r
		if y < 0 or y >= PAGE_H:
			continue
		for c: int in range(16):
			var x: int = px + c
			if x >= 0 and x < PAGE_W:
				_page[y * PAGE_W + x] = tiles[src + r * 16 + c]


## A masked tile: per colour plane, the screen's bit where the mask's bit is set, the tile's where not.
func _masked_tile(tiles: PackedByteArray, t: int, px: int, py: int) -> void:
	var src: int = t * 256
	var msk: int = (t + 1) * 256
	if msk + 256 > tiles.size():
		return
	for r: int in range(16):
		var y: int = py + r
		if y < 0 or y >= PAGE_H:
			continue
		for c: int in range(16):
			var x: int = px + c
			if x < 0 or x >= PAGE_W:
				continue
			var m: int = tiles[msk + r * 16 + c]
			var o: int = y * PAGE_W + x
			_page[o] = (_page[o] & m) | (tiles[src + r * 16 + c] & ~m & 15)


## A sprite entry (already one of its four shifts): per plane, (screen & mask) | colour.
func _sprite(data: PackedByteArray, plane: int, e: Dictionary, px: int, py: int) -> void:
	var w: int = int(e.w)
	var si: int = int(e.shape)
	for row: int in range(int(e.h)):
		var y: int = py + row
		for b: int in range(w):
			var m: int = data[4 * plane + si]
			var p0: int = data[si]
			var p1: int = data[plane + si]
			var p2: int = data[2 * plane + si]
			var p3: int = data[3 * plane + si]
			si += 1
			if y < 0 or y >= PAGE_H:
				continue
			for bit: int in range(8):
				var x: int = px + b * 8 + bit
				if x < 0 or x >= PAGE_W:
					continue
				var shift: int = 7 - bit
				var keep: int = (m >> shift) & 1
				var o: int = y * PAGE_W + x
				var scr: int = _page[o]
				var c: int = 0
				c |= ((scr & keep) | ((p0 >> shift) & 1))
				c |= (((scr >> 1) & keep) | ((p1 >> shift) & 1)) << 1
				c |= (((scr >> 2) & keep) | ((p2 >> shift) & 1)) << 2
				c |= (((scr >> 3) & keep) | ((p3 >> shift) & 1)) << 3
				_page[o] = c


func _blit(pixels: PackedByteArray, w: int, h: int, px: int, py: int) -> void:
	for r: int in range(h):
		var y: int = py + r
		if y < 0 or y >= PAGE_H:
			continue
		for c: int in range(w):
			var x: int = px + c
			if x >= 0 and x < PAGE_W:
				_page[y * PAGE_W + x] = pixels[r * w + c]
