# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Writes the EGAHEAD, EGADICT and MAPHEAD tables GalData takes from Keen 6
## v1.0's KEEN6C.EXE into --out (a folder), so omnispeak run on the same data
## (tools/galaxy_verify.py) reads exactly what the port reads.
##
## Options: --game_data=<folder> --out=<folder>


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var d: GalData = GalData.new()
	if not t.ok("keen6 loads (%s)" % d.error, d.load_game(str(opts.get("game_data", "")).path_join("keen6"), "res://data/omnispeak/keen6e14")):
		t.finish(self)
		return
	if t.ok("the tables come from the executable (%s)" % d.exe_build, not d._exe_graph_head.is_empty()):
		var out: String = opts.get("out", "")
		for pair: Array in [["EGAHEAD.CK6", d._exe_graph_head], ["EGADICT.CK6", d._exe_graph_dict], ["MAPHEAD.CK6", d._exe_map_head]]:
			var f: FileAccess = FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
			t.ok("%s written" % pair[0], f != null)
			if f != null:
				f.store_buffer(pair[1])
				f.close()
	t.finish(self)
