# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## A helper, not a check: writes the SHELL-10 export of the development
## copies (one folder per game under --game_data) into --out, as the
## launcher's Export for Android would. tools/android_check.py --export uses it.
##
## Options: --game_data=<folder> --out=<folder>

var t: T = T.new()


func _init() -> void:
	var data: String = T.options().get("game_data", "")
	var out: String = T.options().get("out", "")
	if data == "" or out == "":
		t.blocked("needs --game_data and --out")
		t.finish(self)
		return
	var finder: GameFinder = GameFinder.new()
	var found: Array = []
	for id: String in ["keen1", "keen2", "keen3", "keen4", "keen5", "keen6", "kdreams"]:
		found.append_array(finder.scan_folder(data.path_join(id), 1))
	DirAccess.make_dir_recursive_absolute(out)
	var results: Array = GameExporter.new().export_folder(found, out)
	t.ok("exported %d games" % results.size(), results.size() == 7 and results.all(func(r: Dictionary) -> bool: return r.ok))
	t.finish(self)
