# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-06: Keen Maker's ground styles (Keen 1, Keen 4, Keen Dreams). Each game has three or more; each
## style, asked for the piece of every cell id drew in it (by the cell's shape in id's level), gives id's
## own piece for many of them (the agreement printed: a guard, at least 40% over all the game's ground; id
## varied his ground by hand, so it never reaches all: Keen 1 88%, Keen 4 44%, Keen Dreams 55% on 2026-10-17);
## no two styles look the same (the same fill and top edge, as seen). A box of a
## style painted in a new level is that material only (every piece the style's), its shapes' pieces as
## the style says, and the palette lists the styles first under Ground. A cell taken out of the box's top
## edge leaves its neighbours re-pieced for the gap; undo puts the level back.
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
	for id: String in ["keen1", "keen4", "kdreams"]:
		var m: MakerModel = MakerModel.new()
		if not m.open(id, root_dir.path_join(id)):
			t.ok("%s opens (%s)" % [id, m.error], false)
			continue
		var tr: MakerTerrain = m.terrain
		var tp: int = m.parts.tile_plane()
		# agreement with id's own levels
		var same: int = 0
		var all: int = 0
		for l: KeenLevel in m._all_levels:
			if l == null:
				continue
			var ground: Callable = func(cx: int, cy: int) -> bool: return m.parts.is_ground(l.get_word(tp, cx, cy))
			for y: int in range(1, l.height - 1):
				for x: int in range(1, l.width - 1):
					if not ground.call(x, y):
						continue
					var k: int = m.parts.brush_key(l, x, y)
					var st: int = int(tr.style_of.get(k, -1))
					if st < 0:
						continue
					all += 1
					if tr.piece(st, MakerTerrain.shape(l, x, y, ground), x, y) == k:
						same += 1
		var agree: float = 100.0 * same / maxf(1.0, all)
		t.ok("%s: %d ground styles; they give id's own piece for %.1f%% of the %d cells id drew in them" % [id, tr.styles.size(), agree, all],
			tr.styles.size() >= 3 and agree >= 40.0)
		var looks: Dictionary = {}
		var twins: int = 0
		for st: Dictionary in tr.styles:
			var look: Array = [tr._seen(st.pieces.get(255)), tr._seen(st.pieces.get(MakerTerrain.TOP))]
			if looks.has(look):
				twins += 1
			looks[look] = true
		t.ok("%s: no two styles look the same (%d)" % [id, twins], twins == 0)
		# a box of the first style, painted in a new level
		var entry: int = -1
		for i: int in range(m.kit.objects.size()):
			if m.kit.objects[i].has("terrain") and int(m.kit.objects[i].terrain) == 0:
				entry = i
		m.new_level()
		var before: String = m.fingerprint()
		var a: Vector2i = Vector2i(10, 4)
		var b: Vector2i = Vector2i(17, 8)
		m.fill_terrain(entry, a, b)
		var pure: bool = true
		var shaped: bool = true
		var ground2: Callable = func(cx: int, cy: int) -> bool: return m.parts.is_ground(m.level.get_word(tp, cx, cy))
		for y: int in range(a.y, b.y + 1):
			for x: int in range(a.x, b.x + 1):
				var k: int = m.parts.brush_key(m.level, x, y)
				if int(tr.style_of.get(k, -1)) != 0:
					pure = false
				if k != tr.piece(0, MakerTerrain.shape(m.level, x, y, ground2), x, y):
					shaped = false
		var first: bool = false
		for cat: Dictionary in m.parts.categories:
			if cat.name == MakerParts.GROUND and (cat.values as PackedInt32Array).size() > 0:
				first = int(cat.values[0]) == -1 - entry
		t.ok("%s: a box of a style is that material only (%s), each cell its shape's piece (%s), and the styles lead Ground (%s)" % [id, pure, shaped, first],
			pure and shaped and first)
		# a cell out of the top edge: its neighbours re-pieced for the gap
		var hole: Vector2i = Vector2i(13, 4)
		m.begin_stroke()
		m.terrain_at(-1, hole.x, hole.y, false)
		m.end_stroke()
		var refit: bool = not ground2.call(hole.x, hole.y)
		for c: Vector2i in [hole + Vector2i(-1, 0), hole + Vector2i(1, 0), hole + Vector2i(0, 1)]:
			if m.parts.brush_key(m.level, c.x, c.y) != tr.piece(0, MakerTerrain.shape(m.level, c.x, c.y, ground2), c.x, c.y):
				refit = false
		var back: bool = m.undo() and m.undo() and m.fingerprint() == before
		t.ok("%s: a cell taken out of the top edge leaves its neighbours fitted to the gap (%s); undo puts the level back (%s)" % [id, refit, back],
			refit and back)
	t.finish(self)
