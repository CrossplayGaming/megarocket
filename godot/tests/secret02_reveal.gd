# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SECRET-02: the Reveal secrets cheat. Both engines offer it on their cheat rows, off at launch, and it
## turns on and off. With it on, the layout marks the list's cells of the map on the screen (a "reveal"
## op each, where the cell is, traps marked as traps) and draws Keen 4-6's foreground over them
## see-through ("ghost"); with it off, or on another map, nothing changes. The list here is the test's
## own (SecretsList's cache), so the check does not depend on the shipped lists.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	_galaxy(root)
	_vorticons(root)
	t.finish(self)


func _galaxy(root: String) -> void:
	var d: GalData = GalData.new()
	if not d.load_game(root.path_join("keen5"), "res://data/omnispeak/keen5"):
		t.blocked("keen5: " + d.error)
		return
	var g: Object = load("res://games/galaxy/gal_keen5.gd").new()
	g.data = d
	g.ca_gfxInfoE = d.gfx    # the tile info's sizes (TI_ForeMisc), as CA_Startup sets them
	t.ok("Keen 4-6 offer Reveal secrets", "reveal_secrets" in g.shell_cheat_supported())
	t.ok("Keen 4-6: off at launch", not g.shell_cheat_get("reveal_secrets"))
	g.shell_cheat_set("reveal_secrets", true)
	t.ok("Keen 4-6: turns on", g.shell_cheat_get("reveal_secrets"))
	g.shell_cheat_set("reveal_secrets", false)
	t.ok("Keen 4-6: and off", not g.shell_cheat_get("reveal_secrets"))
	SecretsList._games["keen5"] = {3: {Vector2i(11, 20): "secret", Vector2i(12, 20): "trap"}}
	# a 3x1 strip of map 3 at (10-12, 20), a foreground tile on the middle cell
	var list: Dictionary = {"map": 3, "sx": 160, "sy": 320, "ux": 160 * 16, "uy": 320 * 16, "xmin": -1000, "xmax": 10000,
		"gx": 10, "gy": 20, "gw": 3, "gh": 1, "bg": PackedInt32Array([10, 11, 12]), "fg": PackedInt32Array([0, 5, 0]),
		"sprites": [], "hud": -1, "reveal": true}
	var ops: Array = GalDrawLayout.ops(g, list)
	var marks: Array = _reveals(ops)
	t.eq("on: a mark on each listed cell, where it is on the screen", marks, [[16, 0, false], [32, 0, true]])
	t.eq("on: the foreground over a listed cell drawn see-through", _ghosts(ops), [true])
	list.reveal = false
	ops = GalDrawLayout.ops(g, list)
	t.eq("off: no marks", _reveals(ops), [])
	t.eq("off: the foreground drawn as the original", _ghosts(ops), [false])
	list.reveal = true
	list.map = 4
	t.eq("on, another map: no marks", _reveals(GalDrawLayout.ops(g, list)), [])
	SecretsList._games.erase("keen5")


func _vorticons(root: String) -> void:
	var d: VortData = VortData.new()
	if not d.load_game(root.path_join("keen1"), "CK1"):
		t.blocked("keen1: " + d.error)
		return
	var g: Object = VortKeen1.new()
	g.data = d
	t.ok("Keen 1-3 offer Reveal secrets", "reveal_secrets" in g.shell_cheat_supported())
	t.ok("Keen 1-3: off at launch", not g.shell_cheat_get("reveal_secrets"))
	g.shell_cheat_set("reveal_secrets", true)
	t.ok("Keen 1-3: turns on", g.shell_cheat_get("reveal_secrets"))
	g.shell_cheat_set("reveal_secrets", false)
	var anim: PackedInt32Array = PackedInt32Array()
	anim.resize(g.MAXTILES * 4)
	for i: int in range(anim.size()):
		anim[i] = (i % g.MAXTILES) << 5
	g.tile_anim = anim
	SecretsList._games["keen1"] = {5: {Vector2i(4, 3): "secret"}, 6: {}}
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize((g.PORTTILESWIDE + 2) * (g.PORTTILESHIGH + 2))
	# the camera at tile (2, 0): the cell (4, 3) 32 pixels right of the picture's edge, 48 down
	var list: Dictionary = {"originx": 2 * 16 * g.PIXGLOBAL, "originy": 0, "animtable": 0, "grid": grid, "world": [],
		"tiles": [], "pics": [], "map_w": 100, "xmin": 0, "xmax": 1600, "level": 5, "reveal": true}
	t.eq("on: a mark on the listed cell, where it is on the screen", _reveals(VortDrawLayout.ops(g, list)), [[32, 48, false]])
	list.reveal = false
	t.eq("off: no marks", _reveals(VortDrawLayout.ops(g, list)), [])
	list.reveal = true
	list.level = 6
	t.eq("on, another level: no marks", _reveals(VortDrawLayout.ops(g, list)), [])
	SecretsList._games.erase("keen1")


func _reveals(ops: Array) -> Array:
	var out: Array = []
	for op: Dictionary in ops:
		if op.kind == "reveal":
			out.append([int(op.x), int(op.y), bool(op.trap)])
	return out


func _ghosts(ops: Array) -> Array:
	var out: Array = []
	for op: Dictionary in ops:
		if op.kind == "mtile":
			out.append(bool(op.get("ghost", false)))
	return out
