# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-07's sounds: for Keen 1, Keen 4 and Keen Dreams, every building event (place, paint's two steps,
## erase, box, undo, link, ask, pick) has the game's own effect made into sound: audible (its loudest
## sample a fifth of full scale or more) and short (under three seconds). Keen 4's view tells each action's
## kind for its sound: an object placed "place", erased "erase", a big box "box", an undo "undo"; with the
## effects volume at 0 nothing is played.
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
	for id: String in ["keen1", "keen4", "kdreams"]:
		var m: MakerModel = MakerModel.new()
		if not m.open(id, root_dir.path_join(id)):
			t.ok("%s opens (%s)" % [id, m.error], false)
			continue
		var s: MakerSounds = MakerSounds.new()
		root.add_child(s)
		s.use(m.parts, 1.0)
		var table: Dictionary = s._table()
		var bad: Array = []
		var made: int = 0
		for event: String in table:
			for name: Variant in table[event]:
				var wav: AudioStreamWAV = s._sound(name)
				if wav == null:
					bad.append("%s %s: none" % [event, name])
					continue
				var peak: int = 0
				for i: int in range(0, wav.data.size() - 1, 2):
					peak = maxi(peak, absi(wav.data.decode_s16(i)))
				var secs: float = wav.data.size() / 2.0 / wav.mix_rate
				if peak < 6553 or secs >= 3.0:
					bad.append("%s %s: peak %d, %.2f s" % [event, name, peak, secs])
				else:
					made += 1
		t.ok("%s: every building event has the game's own sound, audible and short (%d made%s)" % [id, made,
			"; " + ", ".join(bad) if not bad.is_empty() else ""], bad.is_empty() and made >= 8)
		s.queue_free()
		if id != "keen4":
			continue
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
		var kinds: Array = []
		v.built.connect(func(k: String) -> void: kinds.append(k))
		var obj: int = 0
		while m.kit.objects[obj].has("stretch") or m.kit.objects[obj].has("backdrop") or m.kit.objects[obj].has("terrain"):
			obj += 1
		v.plane = MakerObjects.PLANE
		v.value = obj
		v.tool = "paint"
		v.act_at(Vector2i(6, 4))
		var c0: Array = (m.kit.objects[obj].cells as Array)[0]
		v.tool = "erase"
		v.act_at(Vector2i(6, 4) + (c0[0] as Vector2i))
		var back: int = -1
		for i: int in range(m.kit.objects.size()):
			if m.kit.objects[i].has("backdrop"):
				back = i
				break
		v.tool = "rect"
		v.value = back
		v.act_at(Vector2i(2, 2))
		v.act_at(Vector2i(60, 25))
		m.undo()
		await process_frame
		t.eq("keen4: the view tells each action's kind for its sound", kinds, ["place", "erase", "box", "undo"])
		var quiet: MakerSounds = MakerSounds.new()
		root.add_child(quiet)
		quiet.use(m.parts, 0.0)
		quiet.play("place")
		t.ok("keen4: with the effects volume at 0 nothing plays", not quiet._player.playing and quiet._sounds.is_empty())
		v.queue_free()
		quiet.queue_free()
	t.finish(self)
