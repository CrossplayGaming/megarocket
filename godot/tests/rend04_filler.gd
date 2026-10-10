# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-04 / J-31: map filler (GalDrawLayout.FILLER). On Keen 5's world map the filler tile (850) is drawn
## at 320 exactly as the original has it and left out (black) in the wide view; another tile beside it,
## and the same tile on another map, are drawn at both widths.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join("keen5"), "res://data/omnispeak/keen5"):
		t.blocked("keen5: " + d.error)
		t.finish(self)
		return
	var g: Object = load("res://games/galaxy/gal_keen5.gd").new()
	g.data = d
	# a 3x1 strip: filler, another tile, filler
	var list: Dictionary = {"map": 0, "sx": 0, "sy": 0, "ux": 0, "uy": 0, "xmin": -1000, "xmax": 1000,
		"gx": 0, "gy": 0, "gw": 3, "gh": 1, "bg": PackedInt32Array([850, 849, 850]), "fg": PackedInt32Array([0, 0, 0]),
		"sprites": [], "hud": -1}
	var tiles: Callable = func(ops: Array) -> Array:
		return ops.filter(func(op: Dictionary) -> bool: return op.kind == "tile").map(func(op: Dictionary) -> int: return int(op.id))
	t.eq("at 320, every tile as the original has it", tiles.call(GalDrawLayout.ops(g, list)), [850, 849, 850])
	t.eq("in the wide view, the filler left out (black), the other tile drawn", tiles.call(GalDrawLayout.ops(g, list, Vector2.ONE, true, 416)), [849])
	list.map = 1
	t.eq("on another map, the same tile drawn in the wide view", tiles.call(GalDrawLayout.ops(g, list, Vector2.ONE, true, 416)), [850, 849, 850])
	t.finish(self)
