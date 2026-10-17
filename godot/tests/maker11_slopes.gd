# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-08: Keen 4's ramps, one thing to draw. The slope families found in Keen 4's levels hold ramps going
## up and going down; laid from each of id's ramps' first tile, a family gives id's own slope tiles for most
## of their cells (printed; a guard at 60%). A ramp laid ten long in a new level follows its family step by
## step (each slope tile and each step the family's), has its top above and its band under each slope
## tile, and the ground beneath reaches down to the ground there; dragged right to left it ends where the
## drag began; one undo step puts the level back. The palette leads Slopes with the ramps.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var m: MakerModel = MakerModel.new()
	if not m.open("keen4", root_dir.path_join("keen4")):
		t.ok("keen4 opens (%s)" % m.error, false)
		t.finish(self)
		return
	var sl: MakerSlopes = m.slopes
	var tp: int = m.parts.tile_plane()
	var ups: int = 0
	var downs: int = 0
	for f: Dictionary in sl.families:
		if float(f.rise) < 0.0:
			ups += 1
		else:
			downs += 1
	# id's ramps, laid again from their first tile
	var same: int = 0
	var all: int = 0
	var slope: Callable = func(tile: int) -> bool: return m.parts.use_of(tp, tile) == MakerParts.SLOPES
	var fam_of: Dictionary = {}
	for i: int in range(sl.families.size()):
		for tile: int in sl.families[i].next:
			fam_of[tile] = i
	for l: KeenLevel in m._all_levels:
		if l == null:
			continue
		for y: int in range(l.height):
			for x: int in range(1, l.width):
				var tile: int = l.get_word(tp, x, y)
				if not slope.call(tile) or not fam_of.has(tile):
					continue
				var first: bool = true
				for dy: int in [0, -1, 1]:
					if l.in_bounds(x - 1, y + dy) and slope.call(l.get_word(tp, x - 1, y + dy)):
						first = false
				if not first:
					continue
				var fam: Dictionary = (sl.families[fam_of[tile]] as Dictionary).duplicate()
				fam["start"] = tile
				var c: Vector2i = Vector2i(x, y)
				for w: Array in sl.lay(fam, c, 12):
					var at: Vector2i = w[0]
					if not l.in_bounds(at.x, at.y) or not slope.call(l.get_word(tp, at.x, at.y)):
						break
					all += 1
					if l.get_word(tp, at.x, at.y) == int(w[1]):
						same += 1
	var agree: float = 100.0 * same / maxf(1.0, all)
	t.ok("keen4: %d ramp families (%d up, %d down); laid from id's ramps' first tiles they give id's slope tiles for %.1f%% of %d cells" % [sl.families.size(), ups, downs, agree, all],
		ups >= 2 and downs >= 2 and agree >= 60.0)
	# a ramp in a new level
	var entry: int = -1
	for i: int in range(m.kit.objects.size()):
		if m.kit.objects[i].has("slope") and int(m.kit.objects[i].slope) == 0:
			entry = i
	m.new_level()
	var before: String = m.fingerprint()
	var from: Vector2i = Vector2i(10, 14)
	var to: Vector2i = Vector2i(19, 14)
	m.place_slope(entry, from, to)
	var fam0: Dictionary = sl.families[0]
	var cells: Array = m.slope_cells(entry, from, to)
	var follows: bool = cells.size() == 10 and (cells[0][0] as Vector2i) == from and int(cells[0][1]) == int(fam0.start)
	var dressed: bool = true
	var reaches: bool = true
	for k: int in range(cells.size()):
		var c: Vector2i = cells[k][0]
		var tile: int = cells[k][1]
		if m.level.get_word(tp, c.x, c.y) != tile:
			follows = false
		if k + 1 < cells.size():
			var step: Array = (fam0.next as Dictionary).get(tile, [])
			if step.is_empty() or int(step[0]) != int(cells[k + 1][1]) or (cells[k + 1][0] as Vector2i).y - c.y != int(step[1]):
				follows = false
		var ov: int = int((fam0.over as Dictionary).get(tile, 0))
		if ov != 0 and m.level.get_word(tp, c.x, c.y - 1) != ov:
			dressed = false
		var u: Array = (fam0.under as Dictionary).get(tile, [])
		for j: int in range(u.size()):
			if m.parts.brush_key(m.level, c.x, c.y + j + 1) != int(u[j]):
				dressed = false
		for y: int in range(c.y + 1, m.level.height):
			if not m.parts.is_ground(m.level.get_word(tp, c.x, y)) and m.parts.brush_key(m.level, c.x, y) != int(u[0] if not u.is_empty() else -2) \
					and m.parts.brush_key(m.level, c.x, y) != int(u[1] if u.size() > 1 else -2):
				reaches = false
				break
	t.ok("keen4: a ramp laid ten long follows its family step by step (%s), wears its top and band (%s), and the ground beneath reaches down (%s)" % [follows, dressed, reaches],
		follows and dressed and reaches)
	var back_ok: bool = m.undo() and m.fingerprint() == before
	var rev: Array = m.slope_cells(entry, to, from)
	t.ok("keen4: dragged right to left it ends where the drag began (%s); one undo puts the level back (%s)" % [rev[rev.size() - 1][0], back_ok],
		(rev[rev.size() - 1][0] as Vector2i) == to and back_ok)
	var lead: bool = false
	for cat: Dictionary in m.parts.categories:
		if cat.name == MakerParts.SLOPES and int(cat.plane) == tp:
			var v0: int = int(cat.values[0])
			lead = v0 < 0 and m.kit.objects[-1 - v0].has("slope")
	t.ok("keen4: the palette leads Slopes with the ramps", lead)
	t.finish(self)
