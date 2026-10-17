# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-05: a door is never left without what opens it. Keen 1: a door placed in a level with no keycard
## of its colour asks for the keycard (the palette's part: a tile whose use is that keycard's), and asks
## nothing once the level has one; an undo asks nothing. Keen 4: a gem holder placed asks for the door it
## opens (a link from its cell); once linked, for its gem (the info plane's 57-60 by colour); with that
## gem already placed, nothing.
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
	if m.open("keen1", root_dir.path_join("keen1")):
		m.new_level()
		var tp: int = m.parts.tile_plane()
		var door: int = m._tile_with_use(2)
		m.begin_stroke()
		m.paint(tp, 10, 10, door)
		m.end_stroke()
		var n: Dictionary = m.next_step()
		var key_ok: bool = n.has("part") and m.parts.props(int(n.part[1])).use == 18
		t.ok("keen1: a yellow door asks for the yellow keycard (%s)" % n.get("say", "nothing"), key_ok)
		t.ok("keen1: asking again with nothing new done asks nothing", m.next_step().is_empty())
		m.begin_stroke()
		m.paint(tp, 14, 10, int(n.part[1]) if key_ok else 0)
		m.end_stroke()
		m.next_step()
		m.begin_stroke()
		m.paint(tp, 18, 10, door)
		m.end_stroke()
		t.ok("keen1: with the keycard in the level, a second door asks nothing", m.next_step().is_empty())
		m.undo()
		t.ok("keen1: an undo asks nothing", m.next_step().is_empty())
	m = MakerModel.new()
	if m.open("keen4", root_dir.path_join("keen4")):
		m.new_level()
		var holder: int = m._tile_with_use(7)
		m.begin_stroke()
		m.paint(1, 10, 20, holder)
		m.end_stroke()
		var n1: Dictionary = m.next_step()
		t.ok("keen4: a red gem holder asks for the door it opens (%s)" % n1.get("say", "nothing"), n1.get("link_from", Vector2i(-1, -1)) == Vector2i(10, 20))
		var door4: int = m._tile_with_use(5) if m._tile_with_use(5) >= 0 else m._tile_with_use(6)
		m.begin_stroke()
		m.paint(1, 16, 18, door4)
		m.end_stroke()
		m.next_step()
		m.link(Vector2i(10, 20), Vector2i(16, 18))
		var n2: Dictionary = m.next_step()
		t.ok("keen4: linked, it asks for the red gem (%s)" % n2.get("say", "nothing"), n2.get("part", []) == [2, 57])
		m.begin_stroke()
		m.paint(2, 12, 24, 57)
		m.end_stroke()
		m.next_step()
		m.begin_stroke()
		m.paint(1, 22, 20, holder)
		m.end_stroke()
		m.next_step()
		m.link(Vector2i(22, 20), Vector2i(16, 18))
		t.ok("keen4: with a red gem in the level, a second holder linked asks for nothing more", m.next_step().is_empty())
	t.finish(self)
