# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name MakerSlopes
extends RefCounted
## MAKER-08: Keen 4-6's slopes as one thing to draw (the user, 2026-10-17: no thinking in the original's
## pieces), as Mario Maker's are: a ramp is dragged from one end to the other, and the builder lays its
## slope tiles with the band of ground under them and fills the ground beneath down to what is there.
## Worked out when a game is opened, from the player's own levels; nothing is stored.
##
## For each slope tile (MakerParts' Slopes) id put in a level: the slope tile to its right (the same row,
## one up or one down) and the step it took, and the two ground pieces under it (MakerParts.brush_key's
## form). Slope tiles that lead one into another are a family (a gentle grassy ramp up, a steep one down);
## a family's ramp is laid by starting on the tile id's ramps of it start on most and taking, from each
## tile, the step id took most. A family needs MIN_RUNS ramps in id's levels.

const MIN_RUNS: int = 2
## A ramp's picture is this many cells long
const PICTURE: int = 8

## The families: {start (the tile its ramps start on most), next ({tile: [tile, step]}), over ({tile: the
## foreground tile id put above it, the ramp's top, 0 none}), under ({tile: [piece, piece]}), fill (the ground piece under the band, for what is beneath), rise (rows per cell, + down the
## level, - up), runs (id's ramps of it), picture: [[offset, piece or -1 - slope tile]] (a ramp of it)}
var families: Array = []
var _parts: MakerParts = null


func build(levels: Array, parts: MakerParts) -> void:
	_parts = parts
	families = []
	var tp: int = parts.tile_plane()
	var slope: Callable = func(t: int) -> bool: return parts.use_of(tp, t) == MakerParts.SLOPES
	var next: Dictionary = {}     # tile -> {[tile, step] -> times}
	var under: Dictionary = {}    # tile -> {[piece, piece] -> times}
	var below: Dictionary = {}    # tile -> {piece -> times}: the third cell down (the fill)
	var over: Dictionary = {}     # tile -> {foreground tile -> times}: the cell above (the ramp's top)
	var starts: Dictionary = {}   # tile -> times a ramp starts on it
	var parent: Dictionary = {}
	var run_tiles: Array = []     # each ramp's tiles (for the families' ramp counts)
	for l: KeenLevel in levels:
		if l == null:
			continue
		var seen: Dictionary = {}
		for y: int in range(l.height):
			for x: int in range(l.width):
				var c: Vector2i = Vector2i(x, y)
				if seen.has(c) or not slope.call(l.get_word(tp, x, y)):
					continue
				# only a ramp's first tile starts a walk (nothing sloping just left of it)
				var first: bool = true
				for dy: int in [0, -1, 1]:
					if l.in_bounds(x - 1, y + dy) and slope.call(l.get_word(tp, x - 1, y + dy)):
						first = false
				if not first:
					continue
				var tiles: Array = []
				while true:
					seen[c] = true
					var t: int = l.get_word(tp, c.x, c.y)
					tiles.append(t)
					if c.y >= 1:
						if not over.has(t):
							over[t] = {}
						var ov: int = l.get_word(tp, c.x, c.y - 1)
						if slope.call(ov):
							ov = 0    # a steep ramp's tile above is the ramp itself
						over[t][ov] = int(over[t].get(ov, 0)) + 1
					if c.y + 2 < l.height:
						var u: Array = [parts.brush_key(l, c.x, c.y + 1), parts.brush_key(l, c.x, c.y + 2)]
						if not under.has(t):
							under[t] = {}
						under[t][u] = int(under[t].get(u, 0)) + 1
					if c.y + 3 < l.height:
						if not below.has(t):
							below[t] = {}
						var b: int = parts.brush_key(l, c.x, c.y + 3)
						below[t][b] = int(below[t].get(b, 0)) + 1
					var nxt: Vector2i = Vector2i(-1, -1)
					for dy: int in [0, -1, 1]:
						var o: Vector2i = c + Vector2i(1, dy)
						if l.in_bounds(o.x, o.y) and slope.call(l.get_word(tp, o.x, o.y)) and not seen.has(o):
							nxt = o
							break
					if nxt.x < 0:
						break
					var step: Array = [l.get_word(tp, nxt.x, nxt.y), nxt.y - c.y]
					if not next.has(t):
						next[t] = {}
					next[t][step] = int(next[t].get(step, 0)) + 1
					var ra: int = _root(parent, t)
					var rb: int = _root(parent, int(step[0]))
					if ra != rb:
						parent[ra] = rb
					c = nxt
				if tiles.size() >= 3:
					starts[tiles[0]] = int(starts.get(tiles[0], 0)) + 1
					run_tiles.append(tiles)
	# the families, each its ramps' most common start
	var runs: Dictionary = {}    # root -> ramps
	var start_of: Dictionary = {}
	for tiles: Array in run_tiles:
		var r: int = _root(parent, tiles[0])
		runs[r] = int(runs.get(r, 0)) + 1
		var best: int = start_of.get(r, -1)
		if best < 0 or int(starts.get(tiles[0], 0)) > int(starts.get(best, 0)):
			start_of[r] = tiles[0]
	var roots: Array = runs.keys().filter(func(r: int) -> bool: return int(runs[r]) >= MIN_RUNS)
	roots.sort_custom(func(a: int, b: int) -> bool: return int(runs[a]) > int(runs[b]))
	for r: int in roots:
		var fam: Dictionary = {"start": start_of[r], "next": {}, "under": {}, "over": {}, "fill": -1, "runs": int(runs[r])}
		var fills: Dictionary = {}
		for t: int in next:
			if _root(parent, t) == r:
				fam.next[t] = _most(next[t])
		for t: int in over:
			if _root(parent, t) == r:
				fam.over[t] = _most(over[t])
		for t: int in under:
			if _root(parent, t) == r:
				fam.under[t] = _most(under[t])
				for b: int in below.get(t, {}):
					fills[b] = int(fills.get(b, 0)) + int(below[t][b])
		fam.fill = _most(fills) if not fills.is_empty() else -1
		var walk: Array = lay(fam, Vector2i.ZERO, PICTURE)
		var rise: int = int((walk[walk.size() - 1][0] as Vector2i).y)
		fam["rise"] = float(rise) / float(PICTURE - 1)
		if rise == 0:
			continue    # a flat run of slope tiles is no ramp
		fam["picture"] = _picture(fam, walk)
		families.append(fam)


## The ramp of `fam`, `n` cells long, its first slope tile at `at`: [[cell, slope tile], ...] left to right.
func lay(fam: Dictionary, at: Vector2i, n: int) -> Array:
	var out: Array = []
	var t: int = int(fam.start)
	var c: Vector2i = at
	for i: int in range(n):
		out.append([c, t])
		var step: Variant = (fam.next as Dictionary).get(t)
		if step == null:
			step = (fam.next as Dictionary).get(int(fam.start), [int(fam.start), 0])
		t = int(step[0])
		c = Vector2i(c.x + 1, c.y + int(step[1]))
	return out


## A ramp's picture: its slope tiles (as -1 - tile: a foreground tile alone) and the two ground pieces under
## each, top-left at 0,0.
func _picture(fam: Dictionary, walk: Array) -> Array:
	var cells: Array = []
	var top: int = 0
	for w: Array in walk:
		top = mini(top, (w[0] as Vector2i).y - 1)
	for w: Array in walk:
		var c: Vector2i = (w[0] as Vector2i) - Vector2i(0, top)
		cells.append([c, -1 - int(w[1])])
		var ov: int = int((fam.over as Dictionary).get(int(w[1]), 0))
		if ov != 0:
			cells.append([c + Vector2i(0, -1), -1 - ov])
		var u: Array = (fam.under as Dictionary).get(int(w[1]), [])
		for k: int in range(u.size()):
			cells.append([c + Vector2i(0, k + 1), int(u[k])])
	return cells


static func _most(c: Dictionary) -> Variant:
	var best: Variant = null
	var times: int = -1
	for k: Variant in c:
		if int(c[k]) > times:
			times = int(c[k])
			best = k
	return best


static func _root(parent: Dictionary, t: int) -> int:
	while parent.has(t) and parent[t] != t:
		t = parent[t]
	return t
