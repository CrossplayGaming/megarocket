# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name VortDrawLayout
extends RefCounted
## REND-02 (Keen 1-3): where each part of a refresh's draw list goes on a picture of any size. The ops,
## in drawing order (the map, the sprites, the tiles placed over them, the pictures):
##   {kind: "tile" | "mtile" | "sprite" | "pic", id: the tile, sprite or picture number, x, y: its
##    top-left on the picture, in that picture's pixels, k: what it is in the list (a map cell "m<x>,<y>",
##    a sprite "s<n>"; the same at any size, for the tests)}
## With `snap` the positions are the original's at 1x: the map and the tiles scroll by whole pixels and
## a sprite sits on an even pixel (its four pre-shifted copies move it two at a time). Without it, at
## `scale` (x, y) picture pixels to the original's one (4:3 makes them differ), everything sits where the
## game says it is, to the 256th of a pixel: smoother scrolling and every sprite on its own pixel
## (native resolution). `view_w` (REND-04): the view's width in the original's pixels, wider than 320 for
## the wide view, centred on the game's camera and kept inside the map. The images are the data's own
## (VortData.tiles, sprites, pics), unshifted.

const W: int = 320
const H: int = 200


static func ops(eng: Object, list: Dictionary, scale: Vector2 = Vector2.ONE, snap: bool = true, view_w: int = W) -> Array:
	var out: Array = []
	var anim: PackedInt32Array = eng.tile_anim
	var abase: int = int(list.animtable) * eng.MAXTILES
	var pg: int = eng.PIXGLOBAL
	var wide: int = int(list.get("wide", 0))
	var ox_px: int = int(list.originx) / pg     # the game's view's top-left, in world pixels (whole)
	var oy_px: int = int(list.originy) / pg
	# the game's camera (smooth motion may put it between two refreshes), then the view drawn: as wide as
	# asked (REND-04), centred on the camera and kept inside the map
	var cx: float = float(ox_px) if snap else float(list.get("view_x", float(int(list.originx)) / pg))
	var vy: float = float(oy_px) if snap else float(list.get("view_y", float(int(list.originy)) / pg))
	var vx: float = cx
	# the wide view never shows past what the original's camera can (its border tiles stay hidden:
	# Megarocket 1.0's edge lock); a level narrower than the view sits in its middle, black round it
	var lo: float = float(list.get("xmin", 0))
	var hi: float = float(list.get("xmax", int(list.get("map_w", 0)) * 16))
	var masked: bool = false
	if view_w > W:
		vx = cx - float(view_w - W) / 2.0
		if hi - lo >= float(view_w):
			vx = clampf(vx, lo, hi - float(view_w))
		else:
			vx = (lo + hi - float(view_w)) / 2.0
			masked = true
		if snap:
			vx = floorf(vx)
	var gx: int = (int(list.originx) >> 12) * 16    # the grid's first visible tile, in world pixels
	var gy: int = (int(list.originy) >> 12) * 16
	var grid: PackedInt32Array = list.grid
	var wide_cols: int = eng.PORTTILESWIDE + 2 + 2 * wide    # a tile's margin all round, and the wide view's
	var x0: int = gx - (1 + wide) * 16
	var reveal: Dictionary = {}
	if list.get("reveal", false) and "data" in eng and eng.data != null:
		reveal = SecretsList.cells(str(eng.data.ext), int(list.get("level", -1)))
	for c: Vector2i in reveal:
		# the Reveal secrets cheat: its cells in the grid, drawn over the rest by the view
		var tx: int = c.x - x0 / 16
		var ty: int = c.y - gy / 16 + 1
		if tx >= 0 and tx < wide_cols and ty >= 0 and ty < eng.PORTTILESHIGH + 2:
			out.append({"kind": "reveal", "x": (c.x * 16 - vx) * scale.x, "y": (c.y * 16 - vy) * scale.y,
				"w": 16.0 * scale.x, "h": 16.0 * scale.y, "trap": reveal[c] == "trap"})
	for ty: int in range(eng.PORTTILESHIGH + 2):
		for tx: int in range(wide_cols):
			var tile: int = grid[ty * wide_cols + tx]
			var t: int = (anim[abase + tile] >> 5) if tile < eng.MAXTILES else 0
			out.append({"kind": "tile", "id": t, "x": (x0 + tx * 16 - vx) * scale.x, "y": (gy + (ty - 1) * 16 - vy) * scale.y,
				"k": "m%d,%d" % [x0 / 16 + tx, gy / 16 + ty - 1]})
	for n: int in range(list.world.size()):
		var w: Array = list.world[n]
		if snap and view_w == W and w.size() > 4 and not w[4]:
			continue    # the original at 1x: the sprites its page took, no more
		var x: float = float(w[0]) / pg
		var y: float = float(w[1]) / pg
		if snap:
			# RF_PlaceSprite: x from the grid's tile-aligned start, one of four copies two pixels apart,
			# so the 1x page puts it on the even pixel of that offset; y is whole
			var base: int = ox_px & ~15
			x = float(base + ((int(w[0]) / pg - base) & ~1))
			y = float(int(w[1]) / pg)
		out.append({"kind": "sprite", "id": int(w[2]), "x": (x - vx) * scale.x, "y": (y - vy) * scale.y, "k": "s%d" % n})
	for t: Array in list.tiles:
		# [byte column, page row, tile]: the grid cell it covers
		var tx: int = (int(t[0]) - 4) / 2
		var ty: int = (int(t[1]) - 32) / 16
		var num: int = int(t[2])
		var kind: String = "mtile" if (num & 0x8000) != 0 else "tile"
		var id: int = (num & 0x7FFF) if kind == "mtile" else (anim[abase + num] >> 5)
		out.append({"kind": kind, "id": id, "x": (gx + tx * 16 - vx) * scale.x, "y": (gy + ty * 16 - vy) * scale.y})
	if wide > 0:
		# the wide margins: the original drew no foreground over sprites off its page; the tiles each
		# sprite stands behind, as RF_PlaceSprite chooses them, over it (on the page, the same again)
		var sprites: Array = eng.data.sprites
		var intile: PackedInt32Array = eng.intile
		for w: Array in list.world:
			if int(w[2]) >= sprites.size():
				continue
			var spr: Dictionary = sprites[int(w[2])]
			var sx: int = int(w[0]) / pg
			var sy: int = int(w[1]) / pg
			for cy: int in range((sy - gy) >> 4, ((sy + int(spr.h) - 1 - gy) >> 4) + 1):
				for cxx: int in range((sx - x0) >> 4, ((sx + int(spr.w) - 1 - x0) >> 4) + 1):
					if cxx < 0 or cxx >= wide_cols or cy + 1 < 0 or cy + 1 >= eng.PORTTILESHIGH + 2:
						continue
					var tilenum: int = grid[(cy + 1) * wide_cols + cxx]
					var tiletype: int = int(intile[tilenum]) if tilenum < intile.size() else 0
					if tiletype >= 0:
						continue
					var kind: String = "mtile" if tiletype == -2 else "tile"
					var id: int = tilenum if kind == "mtile" else (anim[abase + tilenum] >> 5)
					out.append({"kind": kind, "id": id, "x": (x0 + cxx * 16 - vx) * scale.x, "y": (gy + cy * 16 - vy) * scale.y})
	for p: Array in list.pics:
		# pictures are placed on the page, not in the world: where the page's window puts them
		out.append({"kind": "pic", "id": int(p[2]),
			"x": (int(p[0]) * 8 - 32 - (ox_px & 15) + ox_px - vx) * scale.x, "y": (int(p[1]) - 32 - (oy_px & 15) + oy_px - vy) * scale.y})
	if masked:
		# black past the level's ends: {kind: "mask", x, w} in the picture's pixels, the view's height
		out.append({"kind": "mask", "x": 0.0, "w": (lo - vx) * scale.x})
		out.append({"kind": "mask", "x": (hi - vx) * scale.x, "w": (vx + view_w - hi) * scale.x})
	out.append({"kind": "view", "x": vx, "y": vy})    # the view's top-left in world pixels (the shell's overlays)
	return out


## REND-03, smooth motion: a picture between two refreshes, `alpha` of the way from `a` to `b` (0 a's
## moment, 1 b's). The view and each sprite one owner placed in both (RF_PlaceSprite's draw_owner) slide
## along the line between their places; a sprite new in b, one without an owner, and anything that moved
## further than JUMP (a teleport, a respawn) is drawn where b has it; the map, the tiles over the
## sprites and the pictures are b's. Nothing here reaches the simulation.
const JUMP: float = 48.0    # pixels between two refreshes; more is a jump, not a move


static func between(eng: Object, a: Dictionary, b: Dictionary, alpha: float, scale: Vector2, view_w: int = W) -> Array:
	var pg: float = eng.PIXGLOBAL
	var mid: Dictionary = b.duplicate()
	var bx: float = float(int(b.originx)) / pg
	var by: float = float(int(b.originy)) / pg
	var ax: float = float(int(a.originx)) / pg
	var ay: float = float(int(a.originy)) / pg
	if absf(bx - ax) <= JUMP and absf(by - ay) <= JUMP:
		mid["view_x"] = lerpf(ax, bx, alpha)
		mid["view_y"] = lerpf(ay, by, alpha)
	var was: Dictionary = {}
	for w: Array in a.world:
		if w.size() > 3 and int(w[3]) >= 0 and not was.has(int(w[3])):
			was[int(w[3])] = w
	var world: Array = []
	for w: Array in b.world:
		var o: int = int(w[3]) if w.size() > 3 else -1
		if o >= 0 and was.has(o):
			var p: Array = was[o]
			if absf(float(int(w[0]) - int(p[0])) / pg) <= JUMP and absf(float(int(w[1]) - int(p[1])) / pg) <= JUMP:
				world.append([lerpf(float(p[0]), float(w[0]), alpha), lerpf(float(p[1]), float(w[1]), alpha), w[2], o])
				continue
		world.append(w)
	mid["world"] = world
	return ops(eng, mid, scale, false, view_w)


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
