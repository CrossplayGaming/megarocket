# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-07: building's animations in Keen Maker's view (Keen 4). An object placed pops in, a pop per cell
## with its tile; erased, it puffs out, a puff per cell with the tile that was there; a big box flashes its
## outline once instead of animating a thousand cells; an undo animates too; all are gone within half a
## second. Presentation only: the level is what the model says.
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
	m.new_level()
	var tiles: MakerTiles = MakerTiles.new()
	tiles.use(m.parts)
	var v: MakerView = MakerView.new()
	v.model = m
	v.parts = m.parts
	v.tiles = tiles
	v.size = Vector2(800, 600)
	root.add_child(v)
	await process_frame
	# the biggest plain object
	var big: int = 0
	for i: int in range(m.kit.objects.size()):
		var o: Dictionary = m.kit.objects[i]
		if not o.has("stretch") and not o.has("backdrop") and not o.has("terrain") and (o.cells as Array).size() > (m.kit.objects[big].cells as Array).size() and (o.cells as Array).size() <= MakerView.FX_MAX and o.size.x < 20 and o.size.y < 14:
			big = i
	var cells: int = (m.kit.objects[big].cells as Array).size()
	v.plane = MakerObjects.PLANE
	v.value = big
	v.tool = "paint"
	v.act_at(Vector2i(4, 2))
	var pops: Array = v._fx.filter(func(f: Array) -> bool: return f[0] == "pop")
	var right: bool = pops.size() == cells
	for f: Array in pops:
		if m.level.get_word(int(f[2]), f[1].x, f[1].y) != int(f[3]):
			right = false
	t.ok("an object placed pops in: a pop a cell, each its tile (%d of %d)" % [pops.size(), cells], right)
	await _wait(0.5)
	t.ok("and they are gone within half a second (%d left)" % v._fx.size(), v._fx.is_empty())
	var c0: Array = (m.kit.objects[big].cells as Array)[0]
	var before: Array = []
	for c: Array in m.kit.objects[big].cells:
		before.append(int(c[1]))
	v.tool = "erase"
	v.plane = MakerObjects.PLANE
	v.act_at(Vector2i(4, 2) + (c0[0] as Vector2i))
	var puffs: Array = v._fx.filter(func(f: Array) -> bool: return f[0] == "puff")
	var puff_tiles: Array = puffs.map(func(f: Array) -> int: return int(f[3]))
	puff_tiles.sort()
	before.sort()
	t.ok("erased, it puffs out: a puff a cell, each the tile that was there (%d)" % puffs.size(), puffs.size() == cells and puff_tiles == before)
	await _wait(0.5)
	# a big box of a backdrop flashes once
	var back: int = -1
	for i: int in range(m.kit.objects.size()):
		if m.kit.objects[i].has("backdrop"):
			back = i
			break
	v.tool = "rect"
	v.plane = MakerObjects.PLANE
	v.value = back
	v.act_at(Vector2i(2, 2))
	v.act_at(Vector2i(60, 25))
	t.ok("a box of %d cells flashes its outline once, not a pop a cell (%d pops, %d flashes)" % [59 * 24, v._fx.size(), v._flash.size()],
		v._fx.is_empty() and v._flash.size() == 1)
	await _wait(0.5)
	m.undo()
	await process_frame
	t.ok("an undo animates too (%d, %d)" % [v._fx.size(), v._flash.size()], v._fx.size() + v._flash.size() > 0)
	v.queue_free()
	t.finish(self)


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
