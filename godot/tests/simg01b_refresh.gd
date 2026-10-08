# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-G-01b: the Galaxy refresh manager. On real maps of each episode: after
## RF_Reposition and while RF_SmoothScroll carries the view right, down, left
## and up across tile boundaries, the picture on the card is exactly the map's
## tiles (background, then the masked foreground over it) at the scroll
## position, two pixels a step in x as EGA Keen scrolls; a sprite placed, moved
## and removed leaves the background exact; animated tiles step (the map plane
## changes) and the picture keeps matching the map.
##
## The tic count is advanced by a stand-in timer until SIM-G-01c's id_sd.
##
## Options: --game_data=<folder>  --games=keen4,keen5,keen6

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const EP: Dictionary = {"keen4": 1, "keen5": 2, "keen6": 3}

var tiles: PackedByteArray
var tm: Dictionary
var empty_bg: Dictionary = {}


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	for game: String in str(opts.get("games", "keen4")).split(",", false):
		_game(t, root, game)
	t.finish(self)


## The colour the map shows at map pixel (mx, my).
func map_pixel(g: GalRF, mx: int, my: int) -> int:
	var tx: int = mx >> 4
	var ty: int = my >> 4
	var k: int = (my & 15) * 16 + (mx & 15)
	var bg: int = g.CA_TileAtPos(tx, ty, 0)
	var fg: int = g.CA_TileAtPos(tx, ty, 1)
	var c: int = tiles[bg * 256 + k]
	if fg != 0:
		var i: int = fg * 256 + k
		c = tm.pixels[i] if tm.mask[i] == 0 else (c | tm.pixels[i])
	return c


## Pixels of the card's picture that differ from the map at the view
## (-1 when the view shows a tile the port leaves undrawn: an empty chunk).
func view_errors(g: GalRF, vm: DosMachine) -> int:
	vm.card.latch_start()
	var pic: PackedByteArray = vm.card.compose()
	var x0: int = GalRF.RF_UnitToTile(g.rf_scrollXUnit) * 16 + GalRF.RF_UnitToPixel(g.rf_scrollXUnit & 0xef)
	var y0: int = GalRF.RF_UnitToTile(g.rf_scrollYUnit) * 16 + GalRF.RF_UnitToPixel(g.rf_scrollYUnit & 0xff)
	var bad: int = 0
	for y: int in range(200):
		for x: int in range(320):
			var bg: int = g.CA_TileAtPos((x0 + x) >> 4, (y0 + y) >> 4, 0)
			if empty_bg.has(bg):
				continue
			if pic[y * 320 + x] != map_pixel(g, x0 + x, y0 + y):
				bad += 1
	return bad


func _game(t: T, root: String, game: String) -> void:
	var d: GalData = GalData.new()
	if not t.ok("%s: files load (%s)" % [game, d.error], d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		return
	tiles = d.tiles16()
	tm = d.tiles16m()
	empty_bg = {}
	for i: int in range(d.gfx.numTiles16):
		if d.chunk_start(d.gfx.offTiles16 + i) == -1:
			empty_bg[i] = true
	var vm: DosMachine = DosMachine.new()
	var g: GalRF = GalRF.new()
	g.vm = vm
	g.data = d
	g.ck_currentEpisode_ep = EP[game]
	vm.int8 = func() -> void:
		g.sd_timeCount += 1    # stand-in for id_sd's timer service
	g.CA_Startup()
	g.VL_Startup()
	g.RF_Startup()
	# the first level map with animated tiles, and the world map (map 0)
	for map_index: int in [0, 1, 2, 3, 4, 5, 6]:
		if not d.has_map(map_index):
			continue
		g.CA_CacheMap(map_index)
		g.RF_NewMap()
		g.RF_MarkTileGraphics()
		g.CA_CacheMarks("")
		var name: String = "%s map %d (%s, %dx%d, %d animations)" % [game, map_index, g.CA_MapHeaders[map_index].name,
			g.rf_mapWidthTiles, g.rf_mapHeightTiles, g.rf_numAnimTileTimers]
		g.RF_Reposition(0x0400, 0x0300)
		g.RF_Refresh()
		var e: int = view_errors(g, vm)
		t.ok("%s: after RF_Reposition the card shows the map at the scroll position (%d pixels differ)" % [name, e], e == 0)
		# smooth scrolling: 8 units a frame (half a pixel, so x moves every other
		# step by 2 pixels) and 32 units, in each direction, crossing tiles
		var worst: int = 0
		var steps: int = 0
		var moved: Dictionary = {}
		for dir: Array in [[24, 0], [0, 24], [-24, 0], [0, -24], [40, 40], [-40, -40]]:
			for k: int in range(30):
				var bx: int = g.rf_scrollXUnit
				var by: int = g.rf_scrollYUnit
				g.RF_SmoothScroll(dir[0], dir[1])
				if g.rf_scrollXUnit != bx or g.rf_scrollYUnit != by:
					moved["%d,%d" % dir] = true
				g.RF_Refresh()
				steps += 1
				e = view_errors(g, vm)
				worst = maxi(worst, e)
		t.ok("%s: smooth scrolling in six directions, %d frames, always shows the map (worst frame %d pixels; moved %s)" %
			[name, steps, worst, moved.keys()], worst == 0 and moved.size() >= 4)
		# a sprite placed, moved and removed
		var spr: int = int(d.gfx.offSprites) + 10
		g.CA_CacheGrChunk(spr)
		var sx: int = g.rf_scrollXUnit + 0x0480
		var sy: int = g.rf_scrollYUnit + 0x0380
		var sde: GalRF.RF_SpriteDrawEntry = g.RF_AddSpriteDraw(null, sx, sy, spr, false, 1)
		g.RF_Refresh()
		var with_sprite: int = view_errors(g, vm)
		sde = g.RF_AddSpriteDraw(sde, sx + 0x0300, sy + 0x0100, spr, false, 1)
		g.RF_Refresh()
		g.RF_Refresh()
		sde = g.RF_RemoveSpriteDraw(sde)
		g.RF_Refresh()
		g.RF_Refresh()
		e = view_errors(g, vm)
		t.ok("%s: a sprite drawn shows (%d pixels over the map), and once moved and removed the map is exact again (%d differ)" %
			[name, with_sprite, e], with_sprite > 0 and e == 0 and sde == null)
		# animated tiles step and the picture follows the map
		if g.rf_numAnimTileTimers > 0:
			var before: PackedInt32Array = (g.CA_mapPlanes[0] as PackedInt32Array).duplicate()
			var before_fg: PackedInt32Array = (g.CA_mapPlanes[1] as PackedInt32Array).duplicate()
			worst = 0
			var changed: bool = false
			var frames: int = 0
			while frames < 300 and not changed:
				g.RF_Refresh()
				frames += 1
				worst = maxi(worst, view_errors(g, vm))
				changed = before != g.CA_mapPlanes[0] or before_fg != g.CA_mapPlanes[1]
			t.ok("%s: animated tiles on screen step (first change after %d frames: %s) and the picture matches the map throughout (worst %d)" %
				[name, frames, changed, worst], worst == 0 and (changed or g.rf_firstOnscreenAnimTile == null))
		t.ok("%s: no quit (%s)" % [name, g.quit_message], not g.quitting)
		if map_index >= 2:
			break
	g.RF_Shutdown()
	vm.int8 = Callable()
