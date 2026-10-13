# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## REND-03: with smooth motion on, Keen riding a Bounder (Keen 4 level 2) or a lift (level 5) is drawn the
## same distance above it in every picture the shell draws, between refreshes too. Keen is put just above
## the first one (again each second until he lands on it); each frame the layout the native view draws is made again from its own
## two lists and moment, and Keen's place on the screen less the ride's is taken while he rides. Before
## the fix his standing action's push down marked him as stepping every other refresh, so he was drawn
## where he stood while the ride slid: he shook by up to 5.5 pixels (2026-10-12).
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
	for ride: Array in [[2, "Bounder", 0x80, 0x300], [5, "AxisPlatform", 0x100, 0x180]]:
		var rel: Array = await _ride(root_dir, ride[0], ride[1], ride[2], ride[3])
		t.ok("Keen 4 level %d, a %s: %d pictures riding, Keen %s to %s pixels above it" % [ride[0], ride[1], rel.size(),
			rel.min() if not rel.is_empty() else "-", rel.max() if not rel.is_empty() else "-"],
			rel.size() >= 300 and rel.max() - rel.min() < 0.01)
	t.finish(self)


## Keen's screen place less the ride's in each picture drawn while he rides (about 10 s).
func _ride(root_dir: String, level: int, kind: String, dx: int, up: int) -> Array:
	var host: GameHost = GameHost.new()
	root.add_child(host)
	host.start({"id": "keen4", "title": "Keen 4", "folder": root_dir.path_join("keen4"), "play_level": level})
	var t0: int = Time.get_ticks_msec()
	var keen: Object = null
	var plat: Object = null
	var rel: Array = []
	var placed: int = 0
	var riding: int = 0
	while Time.get_ticks_msec() - t0 < 30000 and (riding == 0 or Time.get_ticks_msec() - riding < 6000):
		if host.paused:
			host.set_paused(false)
		await process_frame
		var e: Object = host.engine
		if e == null or Time.get_ticks_msec() - t0 < 2500:
			continue
		keen = e.get("ck_keenObj")
		if plat == null or (riding == 0 and e.get("ck_keenState").get("platform") == null and Time.get_ticks_msec() - placed > 1000):
			plat = null
			var o: Object = keen
			while o != null:
				var a: Object = o.get("currentAction")
				if a != null and kind in String(a.get("name")):
					plat = o
					break
				o = o.get("next")
			if plat != null:
				host._mutex.lock()
				keen.set("posX", plat.get("posX") + dx)
				keen.set("posY", plat.get("posY") - up)
				host._mutex.unlock()
				placed = Time.get_ticks_msec()
			continue
		if riding == 0 and e.get("ck_keenState").get("platform") != null:
			riding = Time.get_ticks_msec()
		var nv: Object = host.get("_native")
		if nv == null or not bool(nv.get("smooth")) or riding == 0 or Time.get_ticks_msec() - riding < 500 or e.get("ck_keenState").get("platform") == null:
			continue
		var b: Dictionary = nv.get("_list")
		var a: Dictionary = nv.get("_prev")
		if b.is_empty() or a.is_empty() or keen.get("sde") == null or plat.get("sde") == null:
			continue
		var gap: float = float(b.t) - float(a.t)
		var alpha: float = clampf((float(nv.get("_machine_t")) - float(nv.get("_shown_at"))) / gap, 0.0, 1.0)
		var ky: float = NAN
		var py: float = NAN
		for op: Dictionary in GalDrawLayout.between(e, a, b, alpha, Vector2.ONE, int(nv.get("view_w"))):
			if op.get("k", "") == "s%d" % keen.get("sde").get("index"):
				ky = op.y
			elif op.get("k", "") == "s%d" % plat.get("sde").get("index"):
				py = op.y
		if not is_nan(ky) and not is_nan(py):
			rel.append(py - ky)
	host.stop()
	while host.thread != null:
		await process_frame
	host.queue_free()
	await process_frame
	return rel
