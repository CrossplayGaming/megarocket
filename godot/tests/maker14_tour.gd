# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-11: Keen Maker's first-time tour. The first time the editor opens (a new player), the tour shows:
## six steps, each framing what it is about (the level, the parts, the tools, the recent parts, Play); A
## (the pad) goes on through them all; then it is seen, and opening the editor again shows none. The menu's
## "Show me around" brings it back, and "Skip the tour" ends it at once.
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
	t.ok("the first time the editor opens, the tour shows (step %d)" % (m.tour_step + 1), m.dialog != null and m.dialog.name == "Tour" and m.tour_step == 0)
	var framed: int = 0
	var steps: int = 0
	while m.tour_step >= 0 and steps < 10:
		var frame: ReferenceRect = m.dialog.get_node_or_null("Frame") as ReferenceRect
		if frame != null and frame.size.x > 8 and frame.size.y > 8:
			framed += 1
		steps += 1
		await _pad(JOY_BUTTON_A)
	t.ok("A goes through all six steps, each framing what it is about (%d steps, %d framed)" % [steps, framed], steps == 6 and framed == 6 and m.dialog == null)
	t.ok("then it is seen", bool(Settings.new(Settings.default_path()).get_value("maker_tour_done")))
	m.new_level()
	for i: int in range(30):
		await process_frame
	t.ok("opening the editor again shows no tour", m.dialog == null and m.tour_step < 0)
	m.open_menu()
	await process_frame
	var again: Button = m.dialog.find_child("Ask_Show_me_around", true, false) as Button
	again.pressed.emit()
	await process_frame
	t.ok("the menu's Show me around brings it back", m.dialog != null and m.tour_step == 0)
	var skip: Button = m.dialog.find_child("Ask_Skip_the_tour", true, false) as Button
	skip.pressed.emit()
	await process_frame
	t.ok("Skip the tour ends it at once", m.dialog == null and m.tour_step < 0)
	t.finish(self)


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
		await process_frame
