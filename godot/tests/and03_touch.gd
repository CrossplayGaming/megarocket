# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## AND-03: the on-screen controls. At a landscape phone, a desktop window and
## a portrait phone every control lies inside the screen and none overlaps
## another (J-54: in each layout, at sizes 50, 100 and 150; the layouts, opacity and size as set; J-50:
## Status has its own code, beside OK). Keen 4's Fire is Space, Keen 1's is Ctrl and Alt together. In the
## host, on Keen 1 in real time, touches reach the game as the keyboard's keys
## (the scan codes the machine delivers through its keyboard interrupt): Jump, the one-button Fire, the d-pad's Right, a slide to
## the up-right diagonal (two arrows) and on to the left (the others let go),
## two fingers at once, Menu (Escape); the overlay hides when a pad is in use
## and lets go of what it held; it is not shown without a touch screen.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _touch(o: TouchOverlay, index: int, at: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = o.get_global_transform_with_canvas() * at
	e.pressed = pressed
	o._input(e)


func _drag(o: TouchOverlay, index: int, at: Vector2) -> void:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = o.get_global_transform_with_canvas() * at
	o._input(e)


func _go() -> void:
	# layout at three screens (J-54: in every layout, at the smallest, the usual and the largest size)
	for sz: Vector2 in [Vector2(851, 393), Vector2(1280, 720), Vector2(393, 851)]:
		for id: String in ["keen1", "keen4", "kdreams"]:
			var bad: Array = []
			for lay: String in ["standard", "swapped", "compact"]:
				for pct: int in [50, 100, 150]:
					var o: TouchOverlay = TouchOverlay.new(id)
					o.size = sz
					o.configure(lay, 50, pct, false)
					var rects: Array = [o.dpad_rect()]
					for n: String in o._buttons:
						rects.append(o.button_rect(n))
					var inside: bool = true
					var apart: bool = true
					for i: int in range(rects.size()):
						if not Rect2(Vector2.ZERO, sz).encloses(rects[i]):
							inside = false
						for j: int in range(i + 1, rects.size()):
							if (rects[i] as Rect2).intersects(rects[j]):
								apart = false
					if not (inside and apart):
						bad.append("%s %d%%" % [lay, pct])
					o.free()
			t.ok("%s at %dx%d: every control inside the screen, none overlapping, in each layout and size %s" % [id, sz.x, sz.y, bad], bad.is_empty())
	# J-50: Status beside Menu and OK, its own code
	var os: TouchOverlay = TouchOverlay.new("keen1")
	os.size = Vector2(851, 393)
	os._place()
	t.ok("Status: the touch screen's own Status code (0x74), at the top beside OK",
		os.codes_at(os.button_rect("Status").get_center()) == [0x74] and os.button_rect("Status").end.x < os.button_rect("OK").position.x
		and os.button_rect("Status").position.y == os.button_rect("OK").position.y)
	os.free()
	# J-54: the layouts' sides, the opacity and the size as configured
	var oc: TouchOverlay = TouchOverlay.new("keen4")
	oc.size = Vector2(851, 393)
	oc.configure("swapped", 100, 150, true)
	t.ok("swapped: the d-pad right, the buttons left; opacity 100 twice the usual alpha; size 150 the buttons 108",
		oc.dpad_rect().position.x > 425 and oc.button_rect("Fire").end.x < 425 and is_equal_approx(oc.shade(0.18), 0.36)
		and is_equal_approx(oc.button_rect("Jump").size.x, 108.0))
	oc.configure("compact", 50, 100, false)
	t.ok("compact: the buttons a block of two columns in the corner",
		oc.button_rect("Fire").position.y == oc.button_rect("Pogo").position.y and oc.button_rect("Jump").position.x == oc.button_rect("Fire").position.x
		and oc.button_rect("Jump").end.y < oc.button_rect("Fire").position.y)
	oc.free()
	t.ok("wanted: hidden with a pad in use unless Show with a pad",
		not TouchOverlay.wanted(true, true) and TouchOverlay.wanted(true, true, true) and TouchOverlay.wanted(true, false) and not TouchOverlay.wanted(false, false, true))
	var o4: TouchOverlay = TouchOverlay.new("keen4")
	o4.size = Vector2(851, 393)
	o4._place()
	var o1: TouchOverlay = TouchOverlay.new("keen1")
	o1.size = Vector2(851, 393)
	o1._place()
	# (CTRL-02: the touch screen's own codes, which the games' readers count as Jump, Pogo and Fire)
	t.ok("Fire is the touch screen's own Fire code in Keen 4 and Keen 1",
		o4.codes_at(o4.button_rect("Fire").get_center()) == [0x73] and o1.codes_at(o1.button_rect("Fire").get_center()) == [0x73])
	o4.free()
	o1.free()
	var od: TouchOverlay = TouchOverlay.new("kdreams")
	od.size = Vector2(851, 393)
	od._place()
	t.ok("Keen Dreams: Jump and Throw (the Fire code), no Pogo",
		od._buttons.has("Throw") and not od._buttons.has("Pogo") and od.codes_at(od.button_rect("Throw").get_center()) == [0x73])
	od.free()

	var data: String = T.options().get("game_data", "")
	if data == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	root.size = Vector2i(851, 393)
	var host: GameHost = GameHost.new()
	host.speed = 1.0
	host.force_touch = true
	root.add_child(host)
	var ok: bool = host.start({"id": "keen1", "title": "Keen 1", "version": "v1.31 EGA", "folder": data.path_join("keen1")})
	await _wait(3.0)
	var o: TouchOverlay = host.overlay
	t.ok("Keen 1 runs with the controls shown", ok and o != null and o.visible)
	var vm: DosMachine = host.vm
	var mark: Array = [vm._key_index]
	# the scan codes the machine has delivered to the game since the last look
	var got: Callable = func() -> Array:
		var out: Array = []
		for e: Array in vm.key_events.slice(mark[0], vm._key_index):
			if not out.has(e[1]):
				out.append(e[1])
		mark[0] = vm._key_index
		return out
	var jump: Vector2 = o.button_rect("Jump").get_center()
	_touch(o, 0, jump, true)
	await _wait(0.3)
	var k: Array = got.call()
	t.ok("Jump: its code pressed (%s)" % str(k), k.has(0x71))
	_touch(o, 0, jump, false)
	await _wait(0.3)
	k = got.call()
	t.ok("lifted: let go (%s)" % str(k), k.has(0xF1))
	var fire: Vector2 = o.button_rect("Fire").get_center()
	_touch(o, 1, fire, true)
	await _wait(0.3)
	k = got.call()
	t.ok("Fire: its code pressed (%s)" % str(k), k.has(0x73))
	_touch(o, 1, fire, false)
	await _wait(0.3)
	k = got.call()
	t.ok("lifted: let go (%s)" % str(k), k.has(0xF3))
	var d: Rect2 = o.dpad_rect()
	var c: Vector2 = d.get_center()
	var cell: float = d.size.x / 3.0
	_touch(o, 2, c + Vector2(cell, 0), true)
	await _wait(0.3)
	k = got.call()
	t.ok("the d-pad's right: Right (%s)" % str(k), k.has(0x4D) and not k.has(0x48))
	_drag(o, 2, c + Vector2(cell, -cell))
	await _wait(0.3)
	k = got.call()
	t.ok("slid to up-right: Up added, Right kept (%s)" % str(k), k.has(0x48) and not k.has(0xCD))
	_drag(o, 2, c + Vector2(-cell, 0))
	await _wait(0.3)
	k = got.call()
	t.ok("slid to the left: Left, the others let go (%s)" % str(k), k.has(0x4B) and k.has(0xCD) and k.has(0xC8))
	_touch(o, 3, jump, true)
	await _wait(0.3)
	k = got.call()
	t.ok("a second finger: Jump too, Left kept (%s)" % str(k), k.has(0x71) and not k.has(0xCB))
	_touch(o, 3, jump, false)
	await _wait(0.3)
	k = got.call()
	t.ok("that finger lifted: Jump let go, Left kept (%s)" % str(k), k.has(0xF1) and not k.has(0xCB))
	# a pad comes into use: hidden, and what the fingers held let go
	host.connected_pads = func() -> Array: return [0]
	host.pad_device = 0
	await _wait(0.3)
	k = got.call()
	t.ok("a pad in use: the controls hide and let go (%s)" % str(k), not o.visible and k.has(0xCB))
	host.connected_pads = func() -> Array: return []
	await _wait(0.2)
	t.ok("the pad gone: shown again", o.visible)
	var menu: Vector2 = o.button_rect("Menu").get_center()
	_touch(o, 4, menu, true)
	await _wait(0.3)
	k = got.call()
	t.ok("Menu: Escape (%s)" % str(k), k.has(0x01))
	_touch(o, 4, menu, false)
	host.force_touch = false
	await _wait(0.2)
	t.ok("no touch screen (this desktop: %s): not shown" % DisplayServer.is_touchscreen_available(),
		DisplayServer.is_touchscreen_available() or not o.visible)
	host.stop()
	await _wait(1.0)
	host.queue_free()
	await process_frame
	t.finish(self)
