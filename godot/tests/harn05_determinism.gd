# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## HARN-05a / SIM-03 for the Vorticons engine: the same inputs twice give the
## same state hash at every displayed frame; a planted fault (one random draw
## skipped at a given frame) is reported at the frame it happens; the hash
## covers every variable of the program (the list is written out for review).
##
## Options: --game_data=<folder> --keys_after_intro=<spec> --seconds=N --plant=<frame>

var t: T = T.new()


func run_once(root: String, keys: String, seconds: float, plant_at: int) -> Dictionary:
	var data: VortData = VortData.new()
	data.load_game(root.path_join("keen1"), "CK1")
	var vm: DosMachine = DosMachine.new()
	var g: VortKeen1 = VortKeen1.new()
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_det_%d" % Time.get_ticks_usec())
	for spec: String in keys.split(",", false):
		var parts: PackedStringArray = spec.split(":")
		vm.add_key_after("intro", float(parts[0]), int(parts[1]), float(parts[2]) if parts.size() > 2 else 0.1)
	var hashes: PackedStringArray = PackedStringArray()
	var frame: Array = [0]
	vm.on_display = func() -> void:
		if vm.card.video_mode == EgaCard.MODE_EGA:
			frame[0] += 1
			if frame[0] == plant_at:
				g.RndT()    # the planted fault: one random number thrown away
			hashes.append(g.state_hash())
	vm.time_limit = DosMachine.seconds_to_units(seconds)
	vm.on_limit = func() -> void: g.exited = true
	g.main()
	var names: PackedStringArray = PackedStringArray(g.state_snapshot().keys())
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.vm = null
	return {"hashes": hashes, "names": names}


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var keys: String = opts.get("keys_after_intro", "1.0:28:0.2,3.0:28:0.2,6.0:77:1.5,7.8:80:0.35,8.5:29:0.2,11.0:77:3.0,12.0:29:0.3")
	var seconds: float = float(opts.get("seconds", "18"))
	var plant: int = int(opts.get("plant", "900"))
	var a: Dictionary = run_once(root, keys, seconds, -1)
	var b: Dictionary = run_once(root, keys, seconds, -1)
	t.ok("two runs of the same inputs give the same number of frames (%d)" % a.hashes.size(), a.hashes.size() == b.hashes.size())
	var first_diff: int = -1
	for i: int in range(mini(a.hashes.size(), b.hashes.size())):
		if a.hashes[i] != b.hashes[i]:
			first_diff = i
			break
	t.ok("and the same state hash at every frame (first difference: %d)" % first_diff, first_diff < 0)
	var c: Dictionary = run_once(root, keys, seconds, plant)
	var diverged: int = -1
	for i: int in range(mini(a.hashes.size(), c.hashes.size())):
		if a.hashes[i] != c.hashes[i]:
			diverged = i
			break
	t.ok("a random draw skipped at frame %d is reported at that frame (diverged at %d)" % [plant, diverged], diverged == plant - 1)
	# the variable list: everything the reference holds should be in it
	var must: PackedStringArray = ["timecount", "lasttimecount", "tics", "originx", "originy", "objlist", "pobjlist", "gamestate",
		"highscores", "bigbuffer", "mapplane", "oldtiles", "oldtiles2", "keydown", "NBKscan", "RndArray", "rndindex", "indexi", "indexj",
		"LastRnd", "SndPtr", "SndPriority", "level", "LevelNumber", "numobj", "pobjcount", "lastdir", "cheatmode", "EGApage",
		"spritelist", "tilelist", "piclist", "coverlist", "worldkeenx", "worldkeeny", "canSave", "restoredGame", "__machine"]
	var missing: PackedStringArray = PackedStringArray()
	for n: String in must:
		if not a.names.has(n):
			missing.append(n)
	t.ok("the hash covers the reference's variables (%d names; missing: %s)" % [a.names.size(), ", ".join(missing)], missing.is_empty())
	print("  state variables: " + ", ".join(a.names))
	t.finish(self)
