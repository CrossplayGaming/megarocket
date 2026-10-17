# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-09: Keen Maker explains itself. In Keen 4's editor, the tip line says what the chosen thing does:
## a ramp or a stretchable is dragged end to end, a ground style and a background pattern are painted, a
## whole object is placed and erased at once, a creature is put where it starts, the eraser takes whole
## objects; and the kinds go by the toy box's names (Ramps, Decorations, Backgrounds), the raw tiles marked
## advanced; Ramps and Ground show no loose piece of a ramp or a ground style.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	# (MAKER-11's first-time tour is its own test's)
	var seen: Settings = Settings.new(Settings.default_path())
	seen.set_value("maker_tour_done", true)
	seen.save()
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
	var kit: MakerObjects = m.model.kit
	var want: Dictionary = {"slope": "Drag from one end", "stretch": "Drag from one end", "terrain": "Paint ground",
		"backdrop": "Paint the background pattern", "object": "Place the whole thing"}
	var got: Dictionary = {}
	for i: int in range(kit.objects.size()):
		var o: Dictionary = kit.objects[i]
		var kind: String = "object"
		for k: String in ["slope", "stretch", "terrain", "backdrop"]:
			if o.has(k):
				kind = k
		if got.has(kind):
			continue
		m.view.tool = "paint"
		m.view.plane = MakerObjects.PLANE
		m.view.value = i
		got[kind] = m.tip()
	var wrong: Array = []
	for k: String in want:
		if not str(got.get(k, "")).begins_with(want[k]):
			wrong.append("%s: %s" % [k, got.get(k, "none")])
	t.ok("each kind of part has its tip (%s)" % (", ".join(wrong) if not wrong.is_empty() else "all right"), wrong.is_empty())
	m.view.plane = m.model.parts.marker_plane()
	m.view.value = 4
	var creature: String = m.tip()
	m.view.tool = "erase"
	var eraser: String = m.tip()
	t.ok("a creature is put where it starts; the eraser takes whole objects (%s / %s)" % [creature, eraser],
		creature.begins_with("Put it where it starts") and eraser.begins_with("Erase takes a whole object"))
	var names: Array = []
	var loose: int = 0
	var tp: int = m.model.parts.tile_plane()
	var pieces: Dictionary = {}
	for f: Dictionary in m.model.slopes.families:
		for tl: int in f.next:
			pieces[tl] = true
	for k: int in m.model.terrain.style_of:
		pieces[k & 0xFFFF] = true
	for cat: Dictionary in m.model.parts.categories:
		names.append(MakerScreen.KIND_NAMES.get(cat.name, cat.name))
		if (cat.name == MakerParts.SLOPES or cat.name == MakerParts.GROUND) and int(cat.plane) == tp:
			for v: int in cat.values:
				if v >= 0 and pieces.has(v):
					loose += 1
	t.ok("the kinds go by the toy box's names (%s)" % ", ".join(names), names.has("Ramps") and names.has("Decorations")
		and names.has("Backgrounds") and names.has("All tiles (advanced)"))
	t.ok("Ramps and Ground show no loose piece of a ramp or a ground style (%d)" % loose, loose == 0)
	t.finish(self)
