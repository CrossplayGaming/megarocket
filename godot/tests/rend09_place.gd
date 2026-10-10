# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-09: where a window from the card's picture is drawn on the view (VortNativeView.overlay_place,
## Keen 1-6). Centred across the wide field wherever the view stands against the camera (in the middle of
## a map, or pushed to one side at its edge); at 320 exactly where the picture has it; its height kept;
## scaled with the view.

var t: T = T.new()


func _init() -> void:
	var r: Rect2i = Rect2i(80, 40, 160, 96)    # a window in the middle of the 320x200 picture
	var one: Vector2 = Vector2.ONE
	# 320: where the picture has it
	t.eq("at 320, the picture's place", VortNativeView.overlay_place(r, Vector2(500, 100), Vector2(500, 100), 320, one), Rect2(80, 40, 160, 96))
	# 416 wide, the view centred on the camera, and pushed to either side at a map's edge: always centred
	for view_x: float in [452.0, 500.0, 404.0]:
		var p: Rect2 = VortNativeView.overlay_place(r, Vector2(500, 100), Vector2(view_x, 100), 416, one)
		t.ok("at 416 with the view at %d, the window centred in the field (%s)" % [view_x, p],
			absf(p.get_center().x - 208.0) < 0.6 and p.position.y == 40.0 and p.size == Vector2(160, 96))
	# scaled with the view (4:3 pixels: x and y differ)
	var s: Rect2 = VortNativeView.overlay_place(r, Vector2(0, 0), Vector2(-48, 0), 416, Vector2(3.0, 3.6))
	t.ok("scaled: %s" % s, s.size == Vector2(480, 346).round() or s.size.is_equal_approx(Vector2(480, 345.6).round()))
	t.ok("scaled, still centred (%s)" % s, absf(s.get_center().x - 208.0 * 3.0) < 2.0)
	t.finish(self)
