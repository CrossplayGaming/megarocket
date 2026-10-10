# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name VortDrawLayout
extends RefCounted
## REND-02 (Keen 1-3): where each part of a refresh's draw list goes on a picture of any size. The ops,
## in drawing order (the map, the sprites, the tiles placed over them, the pictures):
##   {kind: "tile" | "mtile" | "sprite" | "pic", id: the tile, sprite or picture number, x, y: its
##    top-left on the picture, in that picture's pixels}
## With `snap` the positions are the original's at 1x: the map and the tiles scroll by whole pixels and
## a sprite sits on an even pixel (its four pre-shifted copies move it two at a time). Without it, at
## `scale` (x, y) picture pixels to the original's one (4:3 makes them differ), everything sits where the
## game says it is, to the 256th of a pixel: smoother scrolling and every sprite on its own pixel
## (native resolution). The images are the data's own (VortData.tiles, sprites, pics), unshifted.

const W: int = 320
const H: int = 200


static func ops(eng: Object, list: Dictionary, scale: Vector2 = Vector2.ONE, snap: bool = true) -> Array:
	var out: Array = []
	var anim: PackedInt32Array = eng.tile_anim
	var abase: int = int(list.animtable) * eng.MAXTILES
	var pg: int = eng.PIXGLOBAL
	var ox_px: int = int(list.originx) / pg     # the view's top-left, in world pixels (whole)
	var oy_px: int = int(list.originy) / pg
	var vx: float = float(ox_px) if snap else float(int(list.originx)) / pg
	var vy: float = float(oy_px) if snap else float(int(list.originy)) / pg
	var gx: int = (int(list.originx) >> 12) * 16    # the tile grid's first tile, in world pixels
	var gy: int = (int(list.originy) >> 12) * 16
	var grid: PackedInt32Array = list.grid
	var wide: int = eng.PORTTILESWIDE
	for ty: int in range(eng.PORTTILESHIGH):
		for tx: int in range(wide):
			var tile: int = grid[ty * wide + tx]
			var t: int = (anim[abase + tile] >> 5) if tile < eng.MAXTILES else 0
			out.append({"kind": "tile", "id": t, "x": (gx + tx * 16 - vx) * scale.x, "y": (gy + ty * 16 - vy) * scale.y})
	for w: Array in list.world:
		if snap:
			# RF_PlaceSprite: x from the grid's tile-aligned start, one of four copies two pixels apart,
			# so the 1x page puts it on the even pixel of that offset; y is whole
			var sx: int = int(w[0]) / pg
			var base: int = ox_px & ~15
			out.append({"kind": "sprite", "id": int(w[2]), "x": float(base + ((sx - base) & ~1) - ox_px),
				"y": float(int(w[1]) / pg - oy_px)})
		else:
			out.append({"kind": "sprite", "id": int(w[2]), "x": (float(int(w[0])) / pg - vx) * scale.x,
				"y": (float(int(w[1])) / pg - vy) * scale.y})
	for t: Array in list.tiles:
		# [byte column, page row, tile]: the grid cell it covers
		var tx: int = (int(t[0]) - 4) / 2
		var ty: int = (int(t[1]) - 32) / 16
		var num: int = int(t[2])
		var kind: String = "mtile" if (num & 0x8000) != 0 else "tile"
		var id: int = (num & 0x7FFF) if kind == "mtile" else (anim[abase + num] >> 5)
		out.append({"kind": kind, "id": id, "x": (gx + tx * 16 - vx) * scale.x, "y": (gy + ty * 16 - vy) * scale.y})
	for p: Array in list.pics:
		# pictures are placed on the page, not in the world: the window the page shows, scaled
		out.append({"kind": "pic", "id": int(p[2]),
			"x": (int(p[0]) * 8 - 32 - (ox_px & 15)) * scale.x, "y": (int(p[1]) - 32 - (oy_px & 15)) * scale.y})
	return out


## The ops drawn at 1x on a 320x200 picture (palette indices), with the original's rules: tiles and
## pictures replace; a masked tile keeps the picture's bits where the next tile's are set; a sprite's
## mask keeps the picture where it is clear and its colour is merged in (as the planes are ORed).
## For the tests: the layout and the data's unshifted images against the card's picture.
static func compose(eng: Object, layout: Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(W * H)
	var data: Object = eng.data
	var tiles: PackedByteArray = data.tiles
	for op: Dictionary in layout:
		var px: int = int(op.x)
		var py: int = int(op.y)
		match op.kind:
			"tile":
				_rect(out, tiles, int(op.id) * 256, 16, 16, px, py)
			"mtile":
				var src: int = int(op.id) * 256
				var msk: int = src + 256
				if msk + 256 > tiles.size():
					continue
				for r: int in range(16):
					for c: int in range(16):
						var x: int = px + c
						var y: int = py + r
						if x >= 0 and x < W and y >= 0 and y < H:
							var m: int = tiles[msk + r * 16 + c]
							out[y * W + x] = (out[y * W + x] & m) | (tiles[src + r * 16 + c] & ~m & 15)
			"sprite":
				var spr: Dictionary = data.sprites[int(op.id)]
				var w: int = int(spr.w)
				var pix: PackedByteArray = spr.pixels
				var mask: PackedByteArray = spr.mask
				for r: int in range(int(spr.h)):
					var y: int = py + r
					if y < 0 or y >= H:
						continue
					for c: int in range(w):
						var x: int = px + c
						if x < 0 or x >= W:
							continue
						var k: int = r * w + c
						out[y * W + x] = pix[k] if mask[k] != 0 else (out[y * W + x] | pix[k])
			"pic":
				var pic: Dictionary = data.pics[int(op.id)]
				_rect(out, pic.pixels, 0, int(pic.w), int(pic.h), px, py)
	return out


static func _rect(out: PackedByteArray, src: PackedByteArray, at: int, w: int, h: int, px: int, py: int) -> void:
	for r: int in range(h):
		var y: int = py + r
		if y < 0 or y >= H:
			continue
		for c: int in range(w):
			var x: int = px + c
			if x >= 0 and x < W:
				out[y * W + x] = src[at + r * w + c]
