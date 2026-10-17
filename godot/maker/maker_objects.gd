# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerObjects
extends RefCounted
## MAKER-04: the game's whole objects (a house, an archway, a door, a sign, a torch on its stand, a cloud),
## so the maker places and erases them as one thing, never as the pieces the original's tiles split them
## into (the user, 2026-10-17: "the user should not have to think of them in terms of pieces").
##
## Worked out when a game is opened, from the player's own levels; nothing of the games is stored. Two tiles
## are glued when, beside each other one way (left-right or above-below), each is almost always found with
## the other there: of all the places id put the one, at least GLUE of them have the other beside it, and
## the other way round. Glued tiles make groups; a group's object is the arrangement id used most (its
## cells found from each place by following the glue). Groups that are ground or slopes are left to the
## ground brush, and very big ones (a background's repeating forest) to the backdrop brushes.

const GLUE: float = 0.9
## An object no bigger than this, in cells: the foreground's (or Keen 1-3's one plane's), and a
## background's, whose set pieces are bigger (Keen 4's palm groves and forest)
const MAX_SIZE: Vector2i = Vector2i(12, 12)
const MAX_BACK: Vector2i = Vector2i(24, 24)
## A backdrop's repeat, in cells, at most; and the cells a region of it must cover in id's levels
const MAX_REPEAT: int = 16
const BACKDROP_CELLS: int = 64
## The plane value an object is chosen on in the palette and the view (not a level plane)
const PLANE: int = -2

## The objects: {plane, cells: Array of [Vector2i offset, tile] (top-left at 0,0), size: Vector2i, use (the
## tile use most of its cells have), seen: the times id placed it}. In the palette's order (by use, then by
## how often id used it).
var objects: Array = []
## Per plane: the glue, keyed by _key(plane, tile, other tile, across) (across: the other is to the right;
## else below). Kept to find a placed object's cells (cells_at).
var _glue: Dictionary = {}
## Per plane: tile -> the times id put it in the levels (the palette leaves out loose tiles id never used)
var used: Dictionary = {}
## Per plane: the tiles that are nothing there (Keen 4-6 and Dreams' empty foreground; Keen 1-3's sky).
var _empty: Dictionary = {}


static func _key(plane: int, t: int, u: int, across: bool) -> int:
	return (((plane * 65536 + t) * 65536 + u) << 1) | (1 if across else 0)


## Finds the objects of `levels` (KeenLevels of one game) on the planes the engine draws on. `parts` names
## the tiles' uses; `empty` per plane the tiles that are nothing there.
func build(levels: Array, parts: MakerParts, planes: Array, empty: Dictionary) -> void:
	objects = []
	used = {}
	_glue = {}
	_empty = empty
	for plane: int in planes:
		_build_plane(levels, parts, plane)
	_build_stretch(levels, parts, parts.tile_plane())
	for plane: int in planes:
		if plane != parts.tile_plane():
			_build_backdrops(levels, plane)
	var order: Array = MakerParts.ORDER
	objects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia: int = order.find(a.use)
		var ib: int = order.find(b.use)
		if ia != ib:
			return ia < ib
		# the striking ones first: how much of a level id made of it (its cells, times the places)
		return (a.cells as Array).size() * int(a.seen) > (b.cells as Array).size() * int(b.seen))


func _build_plane(levels: Array, parts: MakerParts, plane: int) -> void:
	var nothing: Dictionary = _empty.get(plane, {})
	var count: Dictionary = {}
	var pairs: Dictionary = {}    # _key -> times
	for l: KeenLevel in levels:
		if l == null or plane >= l.planes.size():
			continue
		var p: PackedInt32Array = l.planes[plane]
		var w: int = l.width
		for y: int in range(l.height):
			for x: int in range(w):
				var t: int = p[y * w + x]
				if nothing.has(t):
					continue
				count[t] = int(count.get(t, 0)) + 1
				if x + 1 < w:
					var k: int = _key(plane, t, p[y * w + x + 1], true)
					pairs[k] = int(pairs.get(k, 0)) + 1
				if y + 1 < l.height:
					var k2: int = _key(plane, t, p[(y + 1) * w + x], false)
					pairs[k2] = int(pairs.get(k2, 0)) + 1
	used[plane] = count
	# the glue, and the groups it makes (union-find over tiles)
	var parent: Dictionary = {}
	var glued: Dictionary = {}
	for k: int in pairs:
		var across: bool = (k & 1) == 1
		var u: int = (k >> 1) & 0xFFFF
		var t: int = (k >> 17) & 0xFFFF
		if t == u or nothing.has(u):
			continue
		var n: int = pairs[k]
		if n >= 2 and n >= GLUE * float(count[t]) and n >= GLUE * float(count.get(u, 0)):
			_glue[k] = true
			glued[t] = true
			glued[u] = true
			var a: int = _root(parent, t)
			var b: int = _root(parent, u)
			if a != b:
				parent[a] = b
	# each group's arrangements as id placed them; the most common is its object
	var shapes: Dictionary = {}    # group root -> {shape key: [cells, times]}
	for l: KeenLevel in levels:
		if l == null or plane >= l.planes.size():
			continue
		var p: PackedInt32Array = l.planes[plane]
		var seen: Dictionary = {}
		for i: int in range(p.size()):
			var t: int = p[i]
			if seen.has(i) or not glued.has(t):
				continue
			var cells: Array = _flood(l, plane, Vector2i(i % l.width, i / l.width), seen)
			if cells.size() < 2:
				continue
			var root: int = _root(parent, t)
			var key: String = str(cells)
			if not shapes.has(root):
				shapes[root] = {}
			var s: Dictionary = shapes[root]
			if not s.has(key):
				s[key] = [cells, 0]
			s[key][1] += 1
	for root: int in shapes:
		var best: Array = []
		for key: String in shapes[root]:
			var e: Array = shapes[root][key]
			if best.is_empty() or int(e[1]) > int(best[1]) or (int(e[1]) == int(best[1]) and (e[0] as Array).size() > (best[0] as Array).size()):
				best = e
		var cells: Array = best[0]
		var size: Vector2i = Vector2i.ZERO
		var uses: Dictionary = {}
		for c: Array in cells:
			size = Vector2i(maxi(size.x, c[0].x + 1), maxi(size.y, c[0].y + 1))
			var u: String = parts.use_of(plane, int(c[1])) if plane == parts.tile_plane() else MakerParts.SCENERY
			uses[u] = int(uses.get(u, 0)) + 1
		var most: Vector2i = MAX_BACK if plane != parts.tile_plane() else MAX_SIZE
		if size.x > most.x or size.y > most.y:
			continue
		var use: String = ""
		for u: String in uses:
			if use == "" or int(uses[u]) > int(uses[use]):
				use = u
		if use == MakerParts.GROUND or use == MakerParts.SLOPES:
			continue
		objects.append({"plane": plane, "cells": cells, "size": size, "use": use if use != "" else MakerParts.SCENERY,
			"seen": int(best[1])})


## Stretchable objects: a platform's left end, middle and right end, a pole's top, shaft and foot. In
## id's levels, a row (or column) of tiles of one kind whose middle repeats one tile between two other
## ends, found at least twice and at two lengths or more, is one: {stretch: "h" or "v", ends: [first,
## last], mid, cells (its picture: three long)}. Ground and slopes are the brush's. A glued object made of
## nothing but a stretchable's tiles is a piece of it, and goes.
func _build_stretch(levels: Array, parts: MakerParts, plane: int) -> void:
	var nothing: Dictionary = _empty.get(plane, {})
	var found: Dictionary = {}    # [dir, first, mid, last] -> {lengths, n, use}
	for l: KeenLevel in levels:
		if l == null or plane >= l.planes.size():
			continue
		var p: PackedInt32Array = l.planes[plane]
		for dir: String in ["h", "v"]:
			var outer: int = l.height if dir == "h" else l.width
			var inner: int = l.width if dir == "h" else l.height
			for o: int in range(outer):
				var run: Array = []
				for i: int in range(inner + 1):
					var t: int = -1
					if i < inner:
						t = p[o * l.width + i] if dir == "h" else p[i * l.width + o]
					var u: String = parts.use_of(plane, t) if t >= 0 and not nothing.has(t) else ""
					if not run.is_empty() and (u == "" or u != parts.use_of(plane, run[0])):
						_note_run(run, dir, parts, plane, found)
						run = []
					if u != "":
						run.append(t)
	var kept: Array = []
	var pieces: Dictionary = {}    # tile -> true, of the stretchables
	for key: Array in found:
		var f: Dictionary = found[key]
		if int(f.n) < 2 or (f.lengths as Dictionary).size() < 2:
			continue
		var dir: String = key[0]
		var step: Vector2i = Vector2i(1, 0) if dir == "h" else Vector2i(0, 1)
		var cells: Array = [[Vector2i.ZERO, key[1]], [step, key[2]], [step * 2, key[3]]]
		kept.append({"plane": plane, "stretch": dir, "ends": [key[1], key[3]], "mid": key[2], "cells": cells,
			"size": Vector2i(3, 1) if dir == "h" else Vector2i(1, 3), "use": f.use, "seen": int(f.n)})
		for k: int in [1, 2, 3]:
			pieces[key[k]] = true
	objects = objects.filter(func(o: Dictionary) -> bool:
		if int(o.plane) != plane:
			return true
		for c: Array in o.cells:
			if not pieces.has(int(c[1])):
				return true
		return false)
	objects.append_array(kept)
	_stretch_tiles = {}
	for i: int in range(objects.size()):
		if objects[i].has("stretch"):
			for t: int in [objects[i].ends[0], objects[i].mid, objects[i].ends[1]]:
				_stretch_tiles[t] = true


func _note_run(run: Array, dir: String, parts: MakerParts, plane: int, found: Dictionary) -> void:
	if run.size() < 3:
		return
	var mid: int = run[1]
	for k: int in range(1, run.size() - 1):
		if run[k] != mid:
			return
	var use: String = parts.use_of(plane, mid)
	if run[0] == mid or run[-1] == mid or use == MakerParts.GROUND or use == MakerParts.SLOPES:
		return
	var key: Array = [dir, run[0], mid, run[-1]]
	if not found.has(key):
		found[key] = {"lengths": {}, "n": 0, "use": use}
	found[key].lengths[run.size()] = true
	found[key].n += 1


## Backdrops: a background's repeating pattern (Keen 4's cave walls, 8 tiles repeating every 4 by 2 cells),
## painted as a brush. In id's levels, a glued region of BACKDROP_CELLS or more whose tiles repeat across and
## down within MAX_REPEAT cells is one: {backdrop: true, period, block (the repeat's tiles row by row, as id
## lines them up with the level: a cell's tile is block[(y mod period.y) * period.x + x mod period.x]), cells
## (its picture: the repeat, at least 4 by 4 cells)}.
func _build_backdrops(levels: Array, plane: int) -> void:
	var found: Dictionary = {}    # str(block) -> backdrop
	for l: KeenLevel in levels:
		if l == null or plane >= l.planes.size():
			continue
		var seen: Dictionary = {}
		var p: PackedInt32Array = l.planes[plane]
		for i: int in range(p.size()):
			if seen.has(i):
				continue
			var r: Dictionary = _reach(l, plane, Vector2i(i % l.width, i / l.width))
			for c: Vector2i in r:
				seen[c.y * l.width + c.x] = true
			if r.size() < BACKDROP_CELLS:
				continue
			var per: Vector2i = Vector2i(_repeat(r, Vector2i(1, 0)), _repeat(r, Vector2i(0, 1)))
			if per.x < 1 or per.y < 1:
				continue
			var block: PackedInt32Array = PackedInt32Array()
			block.resize(per.x * per.y)
			block.fill(-1)
			for c: Vector2i in r:
				var k: int = posmod(c.y, per.y) * per.x + posmod(c.x, per.x)
				if block[k] < 0:
					block[k] = r[c]
			if block.has(-1):
				continue
			var key: String = str(per) + str(block)
			if found.has(key):
				found[key].seen += 1
				continue
			var show: Vector2i = Vector2i(maxi(per.x, 4), maxi(per.y, 4))
			var cells: Array = []
			for y: int in range(show.y):
				for x: int in range(show.x):
					cells.append([Vector2i(x, y), block[posmod(y, per.y) * per.x + posmod(x, per.x)]])
			found[key] = {"plane": plane, "backdrop": true, "period": per, "block": block, "cells": cells, "size": show,
				"use": MakerParts.BACKGROUND, "seen": 1}
	var list: Array = found.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seen) > int(b.seen))
	# an object of nothing but one backdrop's tiles is a piece of it, and goes
	var sets: Array = list.map(func(b: Dictionary) -> Dictionary:
		var s: Dictionary = {}
		for tl: int in b.block:
			s[tl] = true
		return s)
	objects = objects.filter(func(o: Dictionary) -> bool:
		if int(o.plane) != plane or o.has("stretch"):
			return true
		for s: Dictionary in sets:
			var inside: bool = true
			for c: Array in o.cells:
				if not s.has(int(c[1])):
					inside = false
					break
			if inside:
				return false
		return true)
	objects.append_array(list)
	_backdrop_tiles = {}
	for i: int in range(objects.size()):
		if objects[i].has("backdrop"):
			var per: Dictionary = _backdrop_tiles.get(int(objects[i].plane), {})
			for tl: int in objects[i].block:
				per[tl] = i
			_backdrop_tiles[int(objects[i].plane)] = per


## A backdrop's tiles: plane -> {tile -> the backdrop} (the eraser takes such a cell alone; the pick picks the backdrop)
var _backdrop_tiles: Dictionary = {}


## The backdrop a glued region of `plane` is painted with (every one of its tiles that backdrop's), -1 for none.
func _backdrop_of(plane: int, r: Dictionary) -> int:
	var tiles: Dictionary = _backdrop_tiles.get(plane, {})
	var b: int = -1
	for c: Vector2i in r:
		var t: int = r[c]
		if not tiles.has(t) or (b >= 0 and int(tiles[t]) != b):
			return -1
		b = int(tiles[t])
	return b


## The smallest repeat of a region along `step` (the same tile `n` cells on, for 97% of the cells that have
## a cell there), -1 for none within MAX_REPEAT.
static func _repeat(r: Dictionary, step: Vector2i) -> int:
	for n: int in range(1, MAX_REPEAT + 1):
		var both: int = 0
		var same: int = 0
		for c: Vector2i in r:
			var d: Vector2i = c + step * n
			if r.has(d):
				both += 1
				if r[d] == r[c]:
					same += 1
		if both >= 20 and same >= both * 0.97:
			return n
	return -1


## A backdrop's tile for the cell at x,y (lined up with the level as id's are).
static func backdrop_tile(o: Dictionary, x: int, y: int) -> int:
	var per: Vector2i = o.period
	return int((o.block as PackedInt32Array)[posmod(y, per.y) * per.x + posmod(x, per.x)])


## The tiles of the stretchables (for the eraser and the pick to walk a placed one)
var _stretch_tiles: Dictionary = {}


## A stretchable laid from `from` to `to` (along its way: the other coordinate is from's): its first end,
## the middle repeated, its last end; one long, just its first end. [[level position, tile]].
func stretch_cells(o: Dictionary, from: Vector2i, to: Vector2i) -> Array:
	var h: bool = o.stretch == "h"
	var a: int = mini(from.x, to.x) if h else mini(from.y, to.y)
	var b: int = maxi(from.x, to.x) if h else maxi(from.y, to.y)
	var out: Array = []
	for i: int in range(a, b + 1):
		var tile: int = int(o.mid)
		if i == a:
			tile = int(o.ends[0])
		elif i == b:
			tile = int(o.ends[1])
		out.append([Vector2i(i, from.y) if h else Vector2i(from.x, i), tile])
	return out


## The placed stretchable through x,y: [object index, its cells] (empty when the cell is in none). It walks
## from the cell to the first end one way and the last end the other, over the stretchable's tiles.
func _stretch_at(l: KeenLevel, plane: int, x: int, y: int) -> Array:
	var t: int = l.get_word(plane, x, y)
	if not _stretch_tiles.has(t):
		return []
	for i: int in range(objects.size()):
		var o: Dictionary = objects[i]
		if not o.has("stretch") or int(o.plane) != plane or not [o.ends[0], o.mid, o.ends[1]].has(t):
			continue
		var step: Vector2i = Vector2i(1, 0) if o.stretch == "h" else Vector2i(0, 1)
		var cells: Array[Vector2i] = [Vector2i(x, y)]
		var ok: bool = true
		for side: int in [-1, 1]:
			var end_tile: int = int(o.ends[0] if side < 0 else o.ends[1])
			var c: Vector2i = Vector2i(x, y)
			var here: int = t
			while here != end_tile:
				c += step * side
				if not l.in_bounds(c.x, c.y):
					ok = false
					break
				here = l.get_word(plane, c.x, c.y)
				if here != int(o.mid) and here != end_tile:
					ok = false
					break
				cells.append(c)
			if not ok:
				break
		if ok and cells.size() >= 2:
			return [i, cells]
	return []


static func _root(parent: Dictionary, t: int) -> int:
	while parent.has(t) and parent[t] != t:
		t = parent[t]
	return t


## The cells of the object at `at` (following the glue from it), top-left first at 0,0: [[offset, tile]],
## sorted; marks them in `seen` (cell index -> true).
func _flood(l: KeenLevel, plane: int, at: Vector2i, seen: Dictionary) -> Array:
	var found: Dictionary = _reach(l, plane, at)
	var lo: Vector2i = at
	for c: Vector2i in found:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		seen[c.y * l.width + c.x] = true
	var cells: Array = []
	for c: Vector2i in found:
		cells.append([c - lo, found[c]])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y or (a[0].y == b[0].y and a[0].x < b[0].x))
	return cells


## The cells glued to `at`, and it: level position -> tile.
func _reach(l: KeenLevel, plane: int, at: Vector2i) -> Dictionary:
	var p: PackedInt32Array = l.planes[plane]
	var found: Dictionary = {}
	var todo: Array[Vector2i] = [at]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if found.has(c):
			continue
		var t: int = p[c.y * l.width + c.x]
		found[c] = t
		for side: Array in [[Vector2i(1, 0), true, false], [Vector2i(-1, 0), true, true], [Vector2i(0, 1), false, false], [Vector2i(0, -1), false, true]]:
			var n: Vector2i = c + (side[0] as Vector2i)
			if n.x < 0 or n.y < 0 or n.x >= l.width or n.y >= l.height or found.has(n):
				continue
			var u: int = p[n.y * l.width + n.x]
			var k: int = _key(plane, u, t, side[1]) if side[2] else _key(plane, t, u, side[1])
			if _glue.has(k):
				todo.append(n)
	return found


## MAKER-04's pick: which object the cell at x,y is part of (as placed, the whole of it), -1 for none.
func object_at(l: KeenLevel, plane: int, x: int, y: int) -> int:
	var s: Array = _stretch_at(l, plane, x, y)
	if not s.is_empty():
		return int(s[0])
	var r: Dictionary = _reach(l, plane, Vector2i(x, y))
	var b: int = _backdrop_of(plane, r)
	if b >= 0:
		return b
	if r.size() > MAX_BACK.x * MAX_BACK.y:
		return -1
	var cells: Array = _flood(l, plane, Vector2i(x, y), {})
	if cells.size() < 2:
		return -1
	var key: String = str(cells)
	for i: int in range(objects.size()):
		if int(objects[i].plane) == plane and str(objects[i].cells) == key:
			return i
	return -1


## The cells (level positions) of the placed object at x,y on `plane`: the glued cells round it; just the
## cell itself when it is glued to nothing.
func cells_at(l: KeenLevel, plane: int, x: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not l.in_bounds(x, y):
		return out
	if _empty.get(plane, {}).has(l.get_word(plane, x, y)):
		out.append(Vector2i(x, y))
		return out
	var s: Array = _stretch_at(l, plane, x, y)
	if not s.is_empty():
		return s[1]
	var r: Dictionary = _reach(l, plane, Vector2i(x, y))
	if r.size() > MAX_BACK.x * MAX_BACK.y or _backdrop_of(plane, r) >= 0:
		out.append(Vector2i(x, y))    # a backdrop's region: the eraser takes the one cell
		return out
	for c: Vector2i in r:
		out.append(c)
	return out
