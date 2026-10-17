# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerTerrain
extends RefCounted
## MAKER-06: the game's ground styles (Keen 4's grassy dirt, its grey rock; Keen 1's red slabs), each a
## brush of its own pieces, so ground is drawn as a shape in one material with its edges and corners
## right, the way Mario Maker's ground is (the user, 2026-10-17). Worked out when a game is opened, from
## the player's own levels; nothing is stored.
##
## A ground piece is a cell's ground tile (Keen 4-6 and Dreams: its background and foreground together,
## MakerParts.brush_key). Pieces are one material when id put them side by side often: for each pair,
## the times they touch are at least FAMILY of the times the rarer of them is used. A material's pieces
## are learned by shape: which of a cell's eight neighbours are ground (a corner only counts where both
## sides beside it are ground, so an inner corner is told from an outer one: the 47 shapes of a blob
## tile set). A shape id never drew in that material takes the nearest one it did.

const FAMILY: float = 0.15
## A material's repeat is at most this many cells each way
const MAX_PERIOD: int = 8
## A material needs this many cells in id's levels to be a style
const MIN_CELLS: int = 60

## The styles, most used first: {pieces (shape -> piece), cells (id's cells of it), picture: [[offset,
## piece]] (a small hill of it, for the palette)}
var styles: Array = []
## piece -> its style (the brush re-pieces a neighbour in its own material)
var style_of: Dictionary = {}
var _parts: MakerParts = null


## A cell's shape: bits 0-3 ground above, right, below, left; 4-7 the corners above-right, below-right,
## below-left, above-left (each only where both sides beside it are ground). Outside the level is ground.
static func shape(l: KeenLevel, x: int, y: int, ground: Callable) -> int:
	var g: Callable = func(cx: int, cy: int) -> bool: return not l.in_bounds(cx, cy) or bool(ground.call(cx, cy))
	var n: bool = g.call(x, y - 1)
	var e: bool = g.call(x + 1, y)
	var s: bool = g.call(x, y + 1)
	var w: bool = g.call(x - 1, y)
	var bits: int = (1 if n else 0) | (2 if e else 0) | (4 if s else 0) | (8 if w else 0)
	if n and e and g.call(x + 1, y - 1):
		bits |= 16
	if s and e and g.call(x + 1, y + 1):
		bits |= 32
	if s and w and g.call(x - 1, y + 1):
		bits |= 64
	if n and w and g.call(x - 1, y - 1):
		bits |= 128
	return bits


func build(levels: Array, parts: MakerParts) -> void:
	_parts = parts
	styles = []
	style_of = {}
	var tp: int = parts.tile_plane()
	var count: Dictionary = {}
	var touch: Dictionary = {}    # a << 32 | b (a < b) -> times
	var ring: Dictionary = {}
	for l: KeenLevel in levels:
		if l == null:
			continue
		for y: int in range(l.height):
			for x: int in [0, l.width - 1]:
				ring[parts.brush_key(l, x, y)] = true
		for x: int in range(l.width):
			for y: int in [0, l.height - 1]:
				ring[parts.brush_key(l, x, y)] = true
	for l: KeenLevel in levels:
		if l == null:
			continue
		for y: int in range(l.height):
			for x: int in range(l.width):
				if not parts.is_ground(l.get_word(tp, x, y)):
					continue
				var k: int = parts.brush_key(l, x, y)
				if ring.has(k):
					continue
				count[k] = int(count.get(k, 0)) + 1
				for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var o: Vector2i = Vector2i(x, y) + d
					if l.in_bounds(o.x, o.y) and parts.is_ground(l.get_word(tp, o.x, o.y)):
						var k2: int = parts.brush_key(l, o.x, o.y)
						if k2 != k and not ring.has(k2):
							var pair: int = (mini(k, k2) << 32) | maxi(k, k2)
							touch[pair] = int(touch.get(pair, 0)) + 1
	# the materials: pieces joined where they touch often (union-find)
	var parent: Dictionary = {}
	for pair: int in touch:
		var a: int = pair >> 32
		var b: int = pair & 0xFFFFFFFF
		if int(touch[pair]) >= 3 and int(touch[pair]) >= FAMILY * float(mini(int(count.get(a, 0)), int(count.get(b, 0)))):
			var ra: int = _root(parent, a)
			var rb: int = _root(parent, b)
			if ra != rb:
				parent[ra] = rb
	# each material's cells: [level, x, y, shape, piece]
	var by_root: Dictionary = {}
	for l: KeenLevel in levels:
		if l == null:
			continue
		var ground: Callable = func(cx: int, cy: int) -> bool: return parts.is_ground(l.get_word(tp, cx, cy))
		for y: int in range(l.height):
			for x: int in range(l.width):
				if not parts.is_ground(l.get_word(tp, x, y)):
					continue
				var k: int = parts.brush_key(l, x, y)
				if not count.has(k):
					continue
				var r: int = _root(parent, k)
				if not by_root.has(r):
					by_root[r] = []
				(by_root[r] as Array).append([l, x, y, shape(l, x, y, ground), k])
	var roots: Array = by_root.keys().filter(func(r: int) -> bool:
		return (by_root[r] as Array).size() >= MIN_CELLS and (by_root[r] as Array).any(func(c: Array) -> bool: return c[3] == 255))
	roots.sort_custom(func(a: int, b: int) -> bool: return (by_root[a] as Array).size() > (by_root[b] as Array).size())
	for r: int in roots:
		var list: Array = by_root[r]
		var per: Vector2i = Vector2i(_period(list, Vector2i(1, 0)), _period(list, Vector2i(0, 1)))
		var by_shape: Dictionary = {}    # shape -> {piece -> times}
		var by_place: Dictionary = {}    # _place_key -> {piece -> times}
		for c: Array in list:
			var s: int = c[3]
			var k: int = c[4]
			if not by_shape.has(s):
				by_shape[s] = {}
			by_shape[s][k] = int(by_shape[s].get(k, 0)) + 1
			var pk: int = _place_key(s, posmod(int(c[1]), per.x), posmod(int(c[2]), per.y))
			if not by_place.has(pk):
				by_place[pk] = {}
			by_place[pk][k] = int(by_place[pk].get(k, 0)) + 1
		var pieces: Dictionary = {}
		for s: int in by_shape:
			pieces[s] = _most(by_shape[s])
		var placed: Dictionary = {}
		for pk: int in by_place:
			placed[pk] = _most(by_place[pk])
		var st: Dictionary = {"pieces": pieces, "placed": placed, "period": per, "cells": list.size()}
		var i: int = styles.size()
		styles.append(st)
		st["picture"] = _picture(i)
		for s: int in by_shape:
			for k: int in by_shape[s]:
				style_of[k] = i


## Where a cell is in its material's repeat, with its shape: one key.
static func _place_key(bits: int, px: int, py: int) -> int:
	return (bits << 16) | (px << 8) | py


## A material's repeat along `step` (1 to MAX_PERIOD cells): the smallest n for which a fill cell (shape
## 255) and the fill cell n on are the same piece at least 75% of the times both are there (id varied his
## patterns by hand here and there); 1 for none.
static func _period(list: Array, step: Vector2i) -> int:
	var fill: Dictionary = {}    # [level id, x, y] -> piece
	for c: Array in list:
		if c[3] == 255:
			fill[[(c[0] as KeenLevel).get_instance_id(), c[1], c[2]]] = c[4]
	for n: int in range(1, MAX_PERIOD + 1):
		var both: int = 0
		var same: int = 0
		for key: Array in fill:
			var o: Array = [key[0], int(key[1]) + step.x * n, int(key[2]) + step.y * n]
			if fill.has(o):
				both += 1
				if fill[o] == fill[key]:
					same += 1
		if both >= 10 and same >= both * 0.75:
			return n
	return 1


## The piece style `i` puts in a cell of `bits` at x,y: the piece id drew there in the material's repeat
## (lined up with the level, as id's are), else the shape's most used piece, else the nearest shape's (the
## most sides in common, then corners).
func piece(i: int, bits: int, x: int = 0, y: int = 0) -> int:
	var st: Dictionary = styles[i]
	var per: Vector2i = st.period
	var placed: Dictionary = st.placed
	var pk: int = _place_key(bits, posmod(x, per.x), posmod(y, per.y))
	if placed.has(pk):
		return placed[pk]
	var pieces: Dictionary = st.pieces
	if pieces.has(bits):
		return pieces[bits]
	var best: int = int(pieces.get(255, -1))
	var score: int = -1
	for s: int in pieces:
		var sides: int = 4 - _ones((s ^ bits) & 15)
		var corners: int = 4 - _ones(((s ^ bits) >> 4) & 15)
		var sc: int = sides * 8 + corners
		if sc > score:
			score = sc
			best = pieces[s]
	return best


## A small hill of the style (6 by 4 cells, a step on its left), for its palette picture: [[offset, piece]].
func _picture(i: int) -> Array:
	var shape_cells: Dictionary = {}
	for y: int in range(4):
		for x: int in range(6):
			if y >= 1 or x >= 2:
				shape_cells[Vector2i(x, y)] = true
	var out: Array = []
	for c: Vector2i in shape_cells:
		var g: Callable = func(cx: int, cy: int) -> bool:
			return shape_cells.has(Vector2i(cx, cy)) or cy >= 4
		out.append([c, piece(i, _shape_of(c, g), c.x, c.y)])
	return out


static func _shape_of(c: Vector2i, g: Callable) -> int:
	var n: bool = g.call(c.x, c.y - 1)
	var e: bool = g.call(c.x + 1, c.y)
	var s: bool = g.call(c.x, c.y + 1)
	var w: bool = g.call(c.x - 1, c.y)
	var bits: int = (1 if n else 0) | (2 if e else 0) | (4 if s else 0) | (8 if w else 0)
	if n and e and g.call(c.x + 1, c.y - 1):
		bits |= 16
	if s and e and g.call(c.x + 1, c.y + 1):
		bits |= 32
	if s and w and g.call(c.x - 1, c.y + 1):
		bits |= 64
	if n and w and g.call(c.x - 1, c.y - 1):
		bits |= 128
	return bits


static func _ones(v: int) -> int:
	var n: int = 0
	while v != 0:
		n += v & 1
		v >>= 1
	return n


static func _most(c: Dictionary) -> int:
	var best: int = -1
	var times: int = -1
	for k: int in c:
		if int(c[k]) > times:
			times = int(c[k])
			best = k
	return best


static func _root(parent: Dictionary, t: int) -> int:
	while parent.has(t) and parent[t] != t:
		t = parent[t]
	return t
