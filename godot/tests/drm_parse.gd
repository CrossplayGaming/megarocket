# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01: the Dreams port's scripts parse and the declarations instantiate.

var t: T = T.new()


func _init() -> void:
	var d: DrmDecl = DrmDecl.new()
	t.ok("DrmDecl instantiates", d != null)
	t.ok("constants: NUMCHUNKS %d, STARTSPRITES %d, MAXSPRITES %d" % [d.NUMCHUNKS, d.STARTSPRITES, d.MAXSPRITES],
		d.NUMCHUNKS == 3016 and d.STARTSPRITES == 71 and d.MAXSPRITES == 100)
	t.ok("a stub per function (InitGame, RF_NewMap, VW_DrawPic)", d.has_method("InitGame") and d.has_method("RF_NewMap") and d.has_method("VW_DrawPic"))
	t.finish(self)
