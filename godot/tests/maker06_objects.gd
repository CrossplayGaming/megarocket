# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-04: Keen Maker's whole objects. For Keen 1, Keen 4 and Keen Dreams (one game of each engine): the
## objects are found in the game's levels (more than ten), none of them ground or a slope (those are the
## brush's) or bigger than MakerObjects.MAX_SIZE, and the palette opens on them. Every object, placed in a
## new level, is one thing there: from each of its cells the eraser finds all of its cells and no others.
## Placing one and erasing it are one undo step each, and undo puts the level back exactly. Stretchables (a
## platform's ends and middle, a pole's): each game has some; one laid seven long is its first end, five
## middles and its last end; the eraser takes all seven from a middle cell and the pick picks it; no other
## object is made of nothing but a stretchable's pieces.
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
		# (the ground styles are painted, not placed: MAKER-06 checks them)
		var objs: Array = m.kit.objects.filter(func(o: Dictionary) -> bool: return not o.has("terrain"))
		var bad_use: int = 0
		var too_big: int = 0
		for o: Dictionary in objs:
			if o.use == MakerParts.GROUND or o.use == MakerParts.SLOPES:
				bad_use += 1
			var most: Vector2i = MakerObjects.MAX_SIZE if int(o.plane) == m.parts.tile_plane() else MakerObjects.MAX_BACK
			if not o.has("backdrop") and (o.size.x > most.x or o.size.y > most.y):
				too_big += 1
		t.ok("%s: %d objects found, none ground or slope (%d), none too big (%d)" % [id, objs.size(), bad_use, too_big],
			objs.size() > 10 and bad_use == 0 and too_big == 0)
		# the palette by what things are: every object in its category, no piece of one among the loose tiles,
		# and the raw tiles, all of them, in the categories at the end
		var listed: Dictionary = {}
		var pieces: int = 0
		var member: Dictionary = {}
		for o: Dictionary in objs:
			for c: Array in o.cells:
				member[str(o.plane) + ":" + str(c[1])] = true
		var last: String = ""
		for cat: Dictionary in m.parts.categories:
			last = str(cat.name)
			if last == MakerModel.ALL_TILES or last == MakerModel.ALL_BACKGROUND:
				continue
			for v: int in cat.values:
				if v < 0:
					if -1 - v < objs.size():
						listed[-1 - v] = true
				elif int(cat.plane) != m.parts.marker_plane() and member.has(str(cat.plane) + ":" + str(v)):
					pieces += 1
		t.ok("%s: the palette lists every object (%d of %d), no object's piece as a loose tile (%d), the raw tiles last (%s)" % [id,
			listed.size(), objs.size(), pieces, last], listed.size() == objs.size() and pieces == 0
			and (last == MakerModel.ALL_TILES or last == MakerModel.ALL_BACKGROUND))
		# each object placed in a new level is one thing: from every one of its cells, all its cells
		var whole: int = 0
		var first_bad: String = ""
		for i: int in range(objs.size()):
			m.new_level()
			var o: Dictionary = objs[i]
			if o.has("backdrop"):
				whole += 1    # a backdrop is painted, not placed (its checks follow)
				continue
			var at: Vector2i = Vector2i(4, 2)
			if m.level.width < at.x + o.size.x + 2 or m.level.height < at.y + o.size.y + 2:
				continue
			m.place_object(i, at.x, at.y)
			var want: Dictionary = {}
			for c: Array in o.cells:
				want[at + (c[0] as Vector2i)] = true
			var ok: bool = true
			for p: Vector2i in want:
				var got: Array[Vector2i] = m.kit.cells_at(m.level, int(o.plane), p.x, p.y)
				var have: Dictionary = {}
				for g: Vector2i in got:
					have[g] = true
				if have != want:
					ok = false
					break
			if ok:
				whole += 1
			elif first_bad == "":
				first_bad = "object %d (%s %dx%d)" % [i, o.use, o.size.x, o.size.y]
		t.ok("%s: every object placed is one thing to the eraser (%d of %d%s)" % [id, whole, objs.size(),
			", first not: " + first_bad if first_bad != "" else ""], whole == objs.size())
		# stretchables
		var stretch: Array = []
		var stretch_tiles: Dictionary = {}
		for i: int in range(objs.size()):
			if objs[i].has("stretch"):
				stretch.append(i)
				for tl: int in [objs[i].ends[0], objs[i].mid, objs[i].ends[1]]:
					stretch_tiles[tl] = true
		var fragments: int = 0
		for o: Dictionary in objs:
			if o.has("stretch") or int(o.plane) != m.parts.tile_plane():
				continue
			var all_pieces: bool = true
			for c: Array in o.cells:
				if not stretch_tiles.has(int(c[1])):
					all_pieces = false
			if all_pieces:
				fragments += 1
		var laid_ok: int = 0
		for i: int in stretch:
			m.new_level()
			var o: Dictionary = objs[i]
			var from: Vector2i = Vector2i(3, 3)
			var to: Vector2i = from + (Vector2i(6, 0) if o.stretch == "h" else Vector2i(0, 6))
			if not m.level.in_bounds(to.x, to.y):
				continue
			var n7: int = m.place_stretch(i, from, to)
			var want: Array = [int(o.ends[0]), int(o.mid), int(o.mid), int(o.mid), int(o.mid), int(o.mid), int(o.ends[1])]
			var got: Array = []
			var step: Vector2i = Vector2i(1, 0) if o.stretch == "h" else Vector2i(0, 1)
			for k: int in range(7):
				var q: Vector2i = from + step * k
				got.append(m.level.get_word(int(o.plane), q.x, q.y))
			var mid_cell: Vector2i = from + step * 3
			var whole7: bool = m.kit.cells_at(m.level, int(o.plane), mid_cell.x, mid_cell.y).size() == 7
			var picked: bool = m.kit.object_at(m.level, int(o.plane), mid_cell.x, mid_cell.y) == i
			var gone7: int = m.erase_object_at(int(o.plane), mid_cell.x, mid_cell.y)
			if n7 == 7 and got == want and whole7 and gone7 == 7 and m.undo() and picked:
				laid_ok += 1
		t.ok("%s: %d stretchables, each laid 7 long as end, middles, end, erased and picked whole (%d), no fragment of one left as an object (%d)" % [id,
			stretch.size(), laid_ok, fragments], not stretch.is_empty() and laid_ok == stretch.size() and fragments == 0)
		# backdrops (Keen 4-6's repeating backgrounds): painted lined up with the level as id's are, so a box of
		# one over a region id filled with it changes nothing, and painted anywhere each cell is the pattern's
		var backs: Array = []
		for i: int in range(objs.size()):
			if objs[i].has("backdrop"):
				backs.append(i)
		if id == "keen4":
			var seamless: int = 0
			for i: int in backs:
				var o: Dictionary = objs[i]
				# a place id used it: the first original level cell that is the pattern's and has a pattern
				# region round it
				var done: bool = false
				for n: Array in m.level_list():
					var lv: KeenLevel = m.original(int(n[0]))
					if lv == null or done:
						continue
					for y: int in range(2, lv.height - 6):
						if done:
							break
						for x: int in range(2, lv.width - 6):
							var all_pattern: bool = true
							for dy: int in range(4):
								for dx: int in range(4):
									if lv.get_word(int(o.plane), x + dx, y + dy) != MakerObjects.backdrop_tile(o, x + dx, y + dy):
										all_pattern = false
							if all_pattern:
								m.select(int(n[0]))
								var before: String = m.fingerprint()
								m.fill_backdrop(i, Vector2i(x, y), Vector2i(x + 3, y + 3))
								if m.fingerprint() == before:
									seamless += 1
								done = true
								break
			m.new_level()
			var painted_ok: bool = true
			if not backs.is_empty():
				m.fill_backdrop(backs[0], Vector2i(5, 3), Vector2i(14, 8))
				for y: int in range(3, 9):
					for x: int in range(5, 15):
						if m.level.get_word(int(objs[backs[0]].plane), x, y) != MakerObjects.backdrop_tile(objs[backs[0]], x, y):
							painted_ok = false
			var lone: Array[Vector2i] = m.kit.cells_at(m.level, int(objs[backs[0]].plane) if not backs.is_empty() else 0, 9, 5)
			t.ok("keen4: %d backdrops; each lined up as id's (%d seamless over a place id used it); painted, each cell the pattern's (%s); the eraser takes one cell of a big region (%d)" % [backs.size(),
				seamless, painted_ok, lone.size()], backs.size() >= 1 and seamless == backs.size() and painted_ok and lone.size() == 1)
		# one undo step to place, one to erase, and undo puts the level back
		m.new_level()
		var big: int = 0
		for i: int in range(objs.size()):
			if not objs[i].has("backdrop") and (objs[i].cells as Array).size() > (objs[big].cells as Array).size() and objs[i].size.x < m.level.width - 6 and objs[i].size.y < m.level.height - 4:
				big = i
		var before: String = m.fingerprint()
		var n: int = m.place_object(big, 3, 2)
		var placed: String = m.fingerprint()
		var c0: Array = (objs[big].cells as Array)[0]
		var gone: int = m.erase_object_at(int(objs[big].plane), 3 + c0[0].x, 2 + c0[0].y)
		var erased_back: bool = m.undo() and m.fingerprint() == placed
		var placed_back: bool = m.undo() and m.fingerprint() == before
		t.ok("%s: the biggest object (%d cells) placed in one step, erased whole (%d cells), each undone in one" % [id, n, gone],
			n == (objs[big].cells as Array).size() and gone == n and erased_back and placed_back)
	t.finish(self)
