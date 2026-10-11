# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name DrmDrawLayout
extends RefCounted
## REND-01D/02 (Keen Dreams): where each part of a refresh's draw list (DrmVW.draw_list) goes on a picture
## of any size, as GalDrawLayout does Keen 4-6's. The ops, in the refresh's drawing order (the map's
## background and foreground tiles, the sprites of priorities 0-2, the masked foreground tiles over them
## (INTILE's high bit), priority 3's sprites, the score box among them):
##   {kind: "tile" (a background tile) | "mtile" (a masked foreground tile) | "sprite", id: the tile or
##    sprite chunk, x, y: its top-left on the picture, in that picture's pixels, k: what it is (a map
##    cell "b<x>,<y>" / "f<x>,<y>", a sprite "s<slot>")}
## With `snap` the positions are the original's at 1x: the map scrolls two pixels at a time across and
## one down, a sprite sits where its shifted copy puts it. Without it, at `scale` (x, y) picture pixels
## to the original's one, everything sits where the game says it is to the 16th of a pixel (native
## resolution). `view_w` (REND-04): the view's width in the original's pixels, wider than 320 for the
## wide view, centred on the game's camera and kept inside what the camera can show (the map's border,
## originxmin to originxmax + 320). The score box stays where it is on the screen: the view's corner,
## not the world.

const W: int = 320
const H: int = 200


static func ops(eng: Object, list: Dictionary, scale: Vector2 = Vector2.ONE, snap: bool = true, view_w: int = W) -> Array:
	var out: Array = []
	# the game's camera (smooth motion may put it between two refreshes): the picture's top-left
	var cx: float = float(int(list.sx)) if snap else float(list.get("view_x", float(int(list.ux)) / 16.0))
	var vy: float = float(int(list.sy)) if snap else float(list.get("view_y", float(int(list.uy)) / 16.0))
	var vx: float = cx
	var lo: float = float(list.get("xmin", 0))
	var hi: float = float(list.get("xmax", 1 << 20))
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
	var gx: int = int(list.gx)
	var gy: int = int(list.gy)
	var gw: int = int(list.gw)
	var gh: int = int(list.gh)
	var bg: PackedInt32Array = list.bg
	var fg: PackedInt32Array = list.fg
	var reveal: Dictionary = reveal_cells(list)
	for ty: int in range(gh):
		for tx: int in range(gw):
			var b: int = bg[ty * gw + tx]
			if b < 0:
				continue    # past the map
			var x: float = ((gx + tx) * 16 - vx) * scale.x
			var y: float = ((gy + ty) * 16 - vy) * scale.y
			out.append({"kind": "tile", "id": b, "x": x, "y": y, "k": "b%d,%d" % [gx + tx, gy + ty]})
			var f: int = fg[ty * gw + tx]
			if f != 0:
				out.append({"kind": "mtile", "id": f, "x": x, "y": y, "k": "f%d,%d" % [gx + tx, gy + ty],
					"ghost": reveal.has(Vector2i(gx + tx, gy + ty))})
	var hud: int = int(list.get("hud", -1))
	var fore_done: bool = false
	for s: Array in list.sprites:
		if int(s[4]) == 3 and not fore_done:
			fore_done = true
			_fore(eng, list, out, vx, vy, scale, reveal)
		var x: float
		var y: float
		if int(s[5]) == hud:
			# on the screen, not in the world: where it is on the original's picture, from the view's corner
			x = float(int(s[0]) - int(list.sx)) if snap else ((float(s[6]) - float(list.ux)) / 16.0)
			y = float(int(s[1]) - int(list.sy)) if snap else ((float(s[7]) - float(list.uy)) / 16.0)
			out.append({"kind": "sprite", "id": int(s[2]), "x": x * scale.x, "y": y * scale.y, "k": "s%d" % int(s[5]), "hud": true})
			continue
		if snap:
			x = float(int(s[0]))
			y = float(int(s[1]))
		else:
			x = float(s[6]) / 16.0    # smooth motion's places are between units
			y = float(s[7]) / 16.0
		out.append({"kind": "sprite", "id": int(s[2]), "x": (x - vx) * scale.x, "y": (y - vy) * scale.y, "k": "s%d" % int(s[5])})
	if not fore_done:
		_fore(eng, list, out, vx, vy, scale, reveal)
	for c: Vector2i in reveal:
		if c.x >= gx and c.x < gx + gw and c.y >= gy and c.y < gy + gh and bg[(c.y - gy) * gw + c.x - gx] >= 0:
			out.append({"kind": "reveal", "x": (c.x * 16 - vx) * scale.x, "y": (c.y * 16 - vy) * scale.y,
				"w": 16.0 * scale.x, "h": 16.0 * scale.y, "trap": reveal[c] == "trap"})
	if masked:
		# black past what the camera can show: {kind: "mask", x, w} in the picture's pixels, the view's height
		out.append({"kind": "mask", "x": 0.0, "w": (lo - vx) * scale.x})
		out.append({"kind": "mask", "x": (hi - vx) * scale.x, "w": (vx + view_w - hi) * scale.x})
	out.append({"kind": "view", "x": vx, "y": vy})    # the view's top-left in world pixels (the shell's overlays)
	return out


## The Reveal secrets cheat (SECRET-02): the cells of the list's map to show (SecretsList, Keen Dreams'
## KDR list), none while it is off.
static func reveal_cells(list: Dictionary) -> Dictionary:
	if not list.get("reveal", false):
		return {}
	return SecretsList.cells("KDR", int(list.get("map", -1)))


## The masked foreground tiles (INTILE's high bit): drawn again over the sprites beneath priority 3.
static func _fore(eng: Object, list: Dictionary, out: Array, vx: float, vy: float, scale: Vector2,
		reveal: Dictionary = {}) -> void:
	var gx: int = int(list.gx)
	var gy: int = int(list.gy)
	var gw: int = int(list.gw)
	var bg: PackedInt32Array = list.bg
	var fg: PackedInt32Array = list.fg
	for i: int in range(fg.size()):
		var f: int = fg[i]
		if f == 0 or bg[i] < 0 or not eng.RF_ForeMasked(f):
			continue
		@warning_ignore("integer_division")
		out.append({"kind": "mtile", "id": f, "x": ((gx + i % gw) * 16 - vx) * scale.x, "y": ((gy + i / gw) * 16 - vy) * scale.y,
			"ghost": reveal.has(Vector2i(gx + i % gw, gy + i / gw))})


## REND-03, smooth motion: a picture between two refreshes, `alpha` of the way from `a` to `b`. The view
## and each sprite whose record (its slot) is in both slide along the line between their places; a sprite
## new in b, anything that moved further than JUMP (a teleport, a respawn), and anything that moved in a
## step (b's "step": a creature whose state moves it all at once as its time runs out, with its next
## picture, so a slide would move the part of it that stands still) is drawn where b has it; the map is
## b's. Nothing here reaches the simulation.
const JUMP: float = 48.0


static func between(eng: Object, a: Dictionary, b: Dictionary, alpha: float, scale: Vector2, view_w: int = W) -> Array:
	var mid: Dictionary = b.duplicate()
	var bx: float = float(int(b.ux)) / 16.0
	var by: float = float(int(b.uy)) / 16.0
	var ax: float = float(int(a.ux)) / 16.0
	var ay: float = float(int(a.uy)) / 16.0
	if absf(bx - ax) <= JUMP and absf(by - ay) <= JUMP:
		mid["view_x"] = lerpf(ax, bx, alpha)
		mid["view_y"] = lerpf(ay, by, alpha)
	var was: Dictionary = {}
	for s: Array in a.sprites:
		was[int(s[5])] = s
	var sprites: Array = []
	var hud: int = int(b.get("hud", -1))
	var step: Array = b.get("step", [])
	for s: Array in b.sprites:
		var slot: int = int(s[5])
		if slot != hud and was.has(slot) and not step.has(slot) and _same_sprite(was[slot], s):
			var p: Array = was[slot]
			if absf(float(int(s[6]) - int(p[6])) / 16.0) <= JUMP and absf(float(int(s[7]) - int(p[7])) / 16.0) <= JUMP:
				var m: Array = s.duplicate()
				m[6] = lerpf(float(p[6]), float(s[6]), alpha)
				m[7] = lerpf(float(p[7]), float(s[7]), alpha)
				sprites.append(m)
				continue
		sprites.append(s)
	mid["sprites"] = sprites
	return ops(eng, mid, scale, false, view_w)


## REND-03: the same sprite in two lists: its entry not handed out again in between (a list made before the
## entries were numbered compares by slot alone).
static func _same_sprite(p: Array, s: Array) -> bool:
	return p.size() < 9 or s.size() < 9 or int(p[8]) == int(s[8])


## The ops drawn at 1x on a 320x200 picture (palette indices), with the original's rules: a background
## tile replaces; a masked tile or sprite clears the picture where its mask is clear and ORs its colour
## in. For the tests: the layout and the data's unshifted images against the card's picture.
static func compose(images: DrmImages, layout: Array, dyn: Dictionary = {}) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(W * H)
	for op: Dictionary in layout:
		var px: int = int(op.x)
		var py: int = int(op.y)
		var img: Dictionary = {}
		match op.kind:
			"tile":
				img = images.tile(int(op.id))
			"mtile":
				img = images.mtile(int(op.id))
			"sprite":
				img = images.sprite(int(op.id), dyn)
			_:
				continue
		if img.is_empty():
			continue
		var w: int = int(img.w)
		var h: int = int(img.h)
		var pix: PackedByteArray = img.pixels
		var mask: PackedByteArray = img.get("mask", PackedByteArray())
		if px >= W or py >= H or px + w <= 0 or py + h <= 0:
			continue
		var c0: int = maxi(0, -px)
		var c1: int = mini(w, W - px)
		for r: int in range(maxi(0, -py), mini(h, H - py)):
			var i: int = (py + r) * W + px
			var k: int = r * w
			if mask.is_empty():
				for c: int in range(c0, c1):
					out[i + c] = pix[k + c]
			else:
				for c: int in range(c0, c1):
					out[i + c] = (out[i + c] if mask[k + c] != 0 else 0) | pix[k + c]
	return out
