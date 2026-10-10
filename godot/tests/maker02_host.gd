# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MAKER-02 in the host: GameHost.start with "play_level" and the maker's files opens the game straight in
## that level (no intro, title or menu), Keen where the maker put him; Keen 1 (the maker's LEVEL01) and
## Keen 4 (the maker's map set, the original's /TEDLEVEL).
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	# Keen 1: Keen's start two tiles right
	var level: KeenLevel = VortLevels.new().read_file(root_dir.path_join("keen1"), 1, "CK1")
	var at1: Vector2i = _move(level, 1, [255], 2)
	await _host(root_dir, {"id": "keen1", "title": "Keen 1", "folder": root_dir.path_join("keen1"), "play_level": 1,
		"maker_files": {"LEVEL01.CK1": VortLevels.new().write(level)}}, func(g: Object) -> Variant:
			return Vector2i(g.objlist[0].x >> 12, (g.objlist[0].y - 8 * g.PIXGLOBAL) >> 12) if g.get("shell_in_level") and g.level == 1 else null,
		at1)
	# Keen 4: two tiles left (right is Border Village's exit)
	var maps: TedMaps = TedMaps.open_galaxy(root_dir.path_join("keen4"), "res://data/omnispeak/keen4")
	var at4: Vector2i = _move(maps.maps[1], 2, [1, 2], -2)
	await _host(root_dir, {"id": "keen4", "title": "Keen 4", "folder": root_dir.path_join("keen4"), "play_level": 1,
		"maker_maps": maps.write()}, func(g: Object) -> Variant:
			return Vector2i(g.ck_keenObj.posX >> 8, at4.y) if g.ck_gameState.currentLevel == 1 and g.ck_keenObj != null and g.ck_keenObj.type == g.CT_Player else null,
		at4)
	t.finish(self)


func _move(level: KeenLevel, plane: int, markers: Array, dx: int) -> Vector2i:
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.get_word(plane, x, y) in markers:
				var v: int = level.get_word(plane, x, y)
				level.set_word(plane, x, y, 0)
				level.set_word(plane, x + dx, y, v)
				return Vector2i(x + dx, y)
	return Vector2i(-1, -1)


func _host(_root_dir: String, found: Dictionary, keen_at: Callable, want: Vector2i) -> void:
	var cfg: String = OS.get_temp_dir().path_join("mr_maker02h_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 2.0
	root.add_child(host)
	var ok: bool = host.start(found)
	t.ok("%s starts on the maker's level (%s)" % [found.id, host.error], ok)
	if ok:
		var got: Array = [null]
		var seen: bool = await _wait(func() -> bool:
			if host.paused:
				host.set_paused(false)
			got[0] = keen_at.call(host.engine)
			return got[0] != null, 60.0)
		t.ok("%s: straight into level 1, Keen where the maker put him (%s, the maker's %s)" % [found.id, got[0], want],
			seen and got[0] == want)
		host.stop()
		await _wait(func() -> bool: return host.thread == null, 20.0)
	host.queue_free()
	for i: int in range(5):
		await process_frame    # the host and its textures gone before the run ends
	DirAccess.remove_absolute(cfg)
