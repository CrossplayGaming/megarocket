# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-10: the parts built with last, a press away. In Keen 4's editor: browsing the palette's kinds adds
## nothing to the recent strip; placing an object, painting a ground style and placing a tile put them at
## its front (newest first, as pictures); choosing the second (its number key, 2) makes it the part being
## built with; no more than six are kept.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var scene: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	for i: int in range(120):
		await process_frame
	scene.call("open_maker")
	for i: int in range(20):
		await process_frame
	var m: MakerScreen = scene.get("maker")
	if not m.open_game("keen4"):
		t.ok("Keen 4 opens in the maker", false)
		t.finish(self)
		return
	for i: int in range(20):
		await process_frame
	m.new_level()
	for i: int in range(30):
		await process_frame
	for k: int in range(4):
		m._category(1)
	t.ok("browsing the kinds adds nothing to the recent strip (%d)" % m._recent.size(), m._recent.is_empty())
	var kit: MakerObjects = m.model.kit
	var obj: int = -1
	var style: int = -1
	for i: int in range(kit.objects.size()):
		var o: Dictionary = kit.objects[i]
		if obj < 0 and not o.has("stretch") and not o.has("slope") and not o.has("terrain") and not o.has("backdrop"):
			obj = i
		if style < 0 and o.has("terrain"):
			style = i
	m.view.tool = "paint"
	m.view.plane = MakerObjects.PLANE
	m.view.value = obj
	m.view.act_at(Vector2i(5, 3))
	m.view.value = style
	m.view.act_at(Vector2i(20, 10))
	m.view.act_end()
	m.view.plane = m.model.parts.tile_plane()
	m.view.value = 5
	m.view.act_at(Vector2i(30, 6))
	m.view.act_end()
	await process_frame
	var want: Array = [[m.model.parts.tile_plane(), 5], [MakerObjects.PLANE, style], [MakerObjects.PLANE, obj]]
	t.eq("an object, a ground style and a tile built with are in front, newest first", m._recent, want)
	await process_frame
	var pics: int = 0
	for b: Node in m._recent_box.get_children():
		if b is TextureButton and (b as TextureButton).texture_normal != null:
			pics += 1
	t.ok("each shown as its picture (%d)" % pics, pics == 3)
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_2
	ev.pressed = true
	m._input(ev)
	t.ok("key 2 chooses the second again (%d, %d)" % [m.view.plane, m.view.value], m.view.plane == MakerObjects.PLANE and m.view.value == style and m._recent[0] == [MakerObjects.PLANE, style])
	for v: int in range(6, 14):
		m.view.plane = m.model.parts.tile_plane()
		m.view.value = v
		m.view.tool = "paint"
		m.view.act_at(Vector2i(40 + v, 6))
		m.view.act_end()
	t.ok("Keen 4's bar has Link", m._tool_buttons.has("link"))
	t.ok("no more than six are kept (%d)" % m._recent.size(), m._recent.size() == MakerScreen.RECENT_MAX)
	t.finish(self)
