# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## The Galaxy port's scripts all parse and each episode class can be made:
## a parse error anywhere in the chain fails this check with Godot's message
## (file and line) above the result.

const CLASSES: Array = ["res://games/galaxy/gal_ck.gd", "res://games/galaxy/gal_act.gd",
	"res://games/galaxy/gal_play.gd", "res://games/galaxy/gal_game.gd",
	"res://games/galaxy/gal_keen4.gd", "res://games/galaxy/gal_keen5.gd", "res://games/galaxy/gal_keen6.gd"]


func _init() -> void:
	var t: T = T.new()
	for path: String in CLASSES:
		var s: Script = load(path)
		var ok: bool = s != null and s.can_instantiate()
		var inst: Variant = s.new() if ok else null
		t.ok("%s parses and instantiates" % path.get_file(), ok and inst != null)
		if inst != null and inst.has_method("CK_ReleaseLinks"):
			inst.CK_ReleaseLinks()
	t.finish(self)
