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
## An object no bigger than this, in cells (bigger groups are backdrops)
const MAX_SIZE: Vector2i = Vector2i(12, 12)
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
		if size.x > MAX_SIZE.x or size.y > MAX_SIZE.y:
			continue
		var use: String = ""
		for u: String in uses:
			if use == "" or int(uses[u]) > int(uses[use]):
				use = u
		if use == MakerParts.GROUND or use == MakerParts.SLOPES:
			continue
		objects.append({"plane": plane, "cells": cells, "size": size, "use": use if use != "" else MakerParts.SCENERY,
			"seen": int(best[1])})


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
	for c: Vector2i in _reach(l, plane, Vector2i(x, y)):
		out.append(c)
	return out
