# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-04: Keen 4-6's camera edge rules in the wide view (GalDrawLayout), at the widths a window gives
## (356: square pixels; 416; 427: a 16:9 window with 4:3 pixels; 448), snapped and smooth. The view is
## centred on the original's picture while it fits; held inside the camera's limits (xmin to xmax, the
## map's two-tile border never shown); stopped by a scroll block beside the picture as by the map's edge
## (a column the original's camera never crosses); and a region narrower than the view sits in its middle
## with black masks over everything outside it. At 320 the view is the original's picture exactly.

var t: T = T.new()

const WIDTHS: Array = [356, 416, 427, 448]


## A list with the original's picture at x `sx` (pixels), limits lo..hi (xmax is the right edge the camera
## can show: its last left edge + 320) and scroll blocks `hblocks` (tile columns).
func _list(sx: int, lo: int, hi: int, hblocks: Array = []) -> Dictionary:
	return {"map": 1, "sx": sx, "sy": 64, "ux": sx * 16, "uy": 64 * 16, "xmin": lo, "xmax": hi,
		"hblocks": PackedInt32Array(hblocks), "gx": 0, "gy": 4, "gw": 1, "gh": 1,
		"bg": PackedInt32Array([1]), "fg": PackedInt32Array([0]), "sprites": [], "hud": -1}


func _view(list: Dictionary, w: int, snap: bool) -> Dictionary:
	var ops: Array = GalDrawLayout.ops(null, list, Vector2.ONE, snap, w)
	var view: Array = ops.filter(func(op: Dictionary) -> bool: return op.kind == "view")
	var masks: Array = ops.filter(func(op: Dictionary) -> bool: return op.kind == "mask")
	return {"x": float(view[0].x) if view.size() == 1 else NAN, "masks": masks}


func _init() -> void:
	# at 320: the original's picture, whatever the limits
	t.ok("at 320 the view is the original's picture", _view(_list(500, 32, 4000), 320, true).x == 500.0
		and _view(_list(500, 32, 4000), 320, false).x == 500.0)
	for w: int in WIDTHS:
		var half: float = float(w - 320) / 2.0
		for snap: bool in [true, false]:
			var how: String = "%d px %s" % [w, "snapped" if snap else "smooth"]
			var centred: float = 500.0 - half
			if snap:
				centred = floorf(centred)
			# free: centred on the original's picture
			t.ok("%s: in the open, centred on the original's picture" % how, _view(_list(500, 32, 4000), w, snap).x == centred)
			# the left limit: the camera at its first place (xmin), the view from xmin on, never the border
			var at_left: Dictionary = _view(_list(32, 32, 4000), w, snap)
			t.ok("%s: at the left limit the view starts at it (%s)" % [how, at_left.x], at_left.x == 32.0 and at_left.masks.is_empty())
			# the right limit: the picture's right edge at xmax, the view ends there
			var at_right: Dictionary = _view(_list(4000 - 320, 32, 4000), w, snap)
			t.ok("%s: at the right limit the view ends at it (%s)" % [how, at_right.x], at_right.x == 4000.0 - w and at_right.masks.is_empty())
			# a scroll block just left of the picture (column 30: x 480-495, the picture from 496) stops it
			var block_left: Dictionary = _view(_list(496, 32, 4000, [30]), w, snap)
			t.ok("%s: a scroll block left of the picture holds the view's left edge past it (%s)" % [how, block_left.x], block_left.x == 496.0)
			# one just right of the picture (column 51: x 816, the picture to 816)
			var block_right: Dictionary = _view(_list(496, 32, 4000, [51]), w, snap)
			t.ok("%s: a scroll block right of the picture holds the view's right edge before it (%s)" % [how, block_right.x], block_right.x == 816.0 - w)
			# a block far away does nothing
			t.ok("%s: a scroll block far away changes nothing" % how, _view(_list(500, 32, 4000, [200]), w, snap).x == centred)
			# a region narrower than the view: in its middle, black outside it
			var narrow: Dictionary = _view(_list(496, 496, 496 + 336), w, snap)
			var mid: float = (496.0 + 496.0 + 336.0 - w) / 2.0
			var masks_ok: bool = narrow.masks.size() == 2 and is_equal_approx(float(narrow.masks[0].x), 0.0) \
				and is_equal_approx(float(narrow.masks[0].w), 496.0 - narrow.x) \
				and is_equal_approx(float(narrow.masks[1].x), 832.0 - narrow.x) \
				and is_equal_approx(float(narrow.masks[1].x) + float(narrow.masks[1].w), float(w))
			if w > 336:
				t.ok("%s: a region narrower than the view sits in its middle, masked outside (%s, %s)" % [how, narrow.x, narrow.masks],
					absf(narrow.x - mid) <= (1.0 if snap else 0.001) and masks_ok)
	t.finish(self)
