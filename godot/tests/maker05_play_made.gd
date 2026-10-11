# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## V15-02, V15-04, MAKER-01/02 for every engine (Keen Dreams too): a level made in the maker plays through
## the game's own loaders in the host. For Keen 1, Keen 4 and Keen Dreams: a new level (MakerModel's
## blank with ground) played from a cursor four cells right of Keen's start, and Keen Dreams' own level 1
## remixed and played from its start (DreamsData taking the maker's MAPHEAD and GAMEMAPS, kl_warp straight
## in). Checks: the game starts on the maker's level, Keen is set down in the cursor's column, and he
## stays on the level (the run goes on, nothing ends it) until the run is stopped.
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


## Keen's column on level `slot` once he is in it, else null.
static func keen_column(g: Object, slot: int) -> Variant:
	if g is GalGame:
		return (g.ck_keenObj.posX >> 8) if g.ck_gameState.currentLevel == slot and g.ck_keenObj != null and g.ck_keenObj.type == g.CT_Player else null
	if g is DreamsGame:
		return (g.player.x >> 8) if g.player != null and g.player.obclass == g.keenobj and g.gamestate.mapon == slot else null
	return (g.objlist[0].x >> 12) if g.get("shell_in_level") and g.level == slot else null


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	for game: String in ["keen1", "keen4", "kdreams"]:
		var m: MakerModel = MakerModel.new()
		if not t.ok("%s opens (%s)" % [game, m.error], m.open(game, root_dir.path_join(game))):
			continue
		m.new_level("Test")
		var at: Vector2i = m.start_at() + Vector2i(4, 0)
		await _play(m, game + " new level from the cursor", at, at.x)
	var d: MakerModel = MakerModel.new()
	if d.open("kdreams", root_dir.path_join("kdreams")):
		d.remix(1)
		await _play(d, "kdreams remix of level 1 from its start", Vector2i(-1, -1), d.start_at().x)
	# V15-04's clear check: a Keen 1 level whose exit is where Keen starts, played from the start in the
	# host, finishes; the level is then cleared, and no longer once a cell is changed; finished from the
	# cursor it is not
	var c: MakerModel = MakerModel.new()
	if c.open("keen1", root_dir.path_join("keen1")):
		c.new_level("Clear")
		var exit: int = -1
		for cat: Dictionary in c.parts.categories:
			if cat.name == MakerParts.EXIT:
				exit = int(cat.values[0])
		var s: Vector2i = c.start_at()
		for y: int in range(s.y, s.y + 2):
			for x: int in range(s.x, s.x + 3):
				c.paint(0, x, y, exit)
		c.end_stroke()
		t.ok("keen1 clear: not cleared before it is played", not c.is_cleared())
		var won: Array = [false]
		await _play(c, "keen1 clear check", Vector2i(-1, -1), s.x, func(e: Object) -> void: won[0] = c.note_play(e, true))
		t.ok("keen1 clear: the game ended with the level finished, and the level is cleared (%s)" % won[0], won[0] and c.is_cleared())
		c.paint(0, s.x + 8, s.y, exit)
		c.end_stroke()
		t.ok("keen1 clear: a cell changed, it is not cleared any more", not c.is_cleared())
		c.undo()
		t.ok("keen1 clear: changed back, it is again", c.is_cleared())
		c.note_play(null, true)
		c.cleared_hash = ""
		await _play(c, "keen1 finished from the cursor", s, s.x, func(e: Object) -> void: won[0] = c.note_play(e, false))
		t.ok("keen1 clear: finished from the cursor does not clear it (%s)" % won[0], won[0] and not c.is_cleared())
	t.finish(self)


func _play(m: MakerModel, label: String, at: Vector2i, column: int, ended: Callable = Callable()) -> void:
	var req: Dictionary = m.play_request(label, at)
	if not t.ok("%s: the play request (%s)" % [label, m.error], not req.is_empty()):
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_maker05_%d.cfg" % Time.get_ticks_usec())
	var host: GameHost = GameHost.new()
	host.settings_path = cfg
	host.speed = 2.0
	root.add_child(host)
	var ok: bool = host.start(req)
	t.ok("%s: the game starts on the maker's level (%s)" % [label, host.error], ok)
	if ok:
		var got: Array = [null]
		var seen: bool = await _wait(func() -> bool:
			if host.paused:
				host.set_paused(false)
			got[0] = keen_column(host.engine, m.number)
			return got[0] != null, 60.0)
		t.ok("%s: straight into level %d, Keen set down in column %d (%s)" % [label, m.number, column, got[0]], seen and got[0] == column)
		if ended.is_valid():
			# the level is meant to end: wait for the game to finish, then ask how (the engine kept: the
			# host lets it go as it finishes)
			var engine: Object = host.engine
			await _wait(func() -> bool:
				if host.paused:
					host.set_paused(false)
				return host.thread == null, 60.0)
			ended.call(engine)
		else:
			var until: int = Time.get_ticks_msec() + 3000
			await _wait(func() -> bool: return Time.get_ticks_msec() >= until or host.thread == null, 10.0)
			t.ok("%s: still on the level a while later (%s)" % [label, keen_column(host.engine, m.number) if host.engine != null else "ended"],
				host.thread != null and keen_column(host.engine, m.number) != null)
		host.stop()
		await _wait(func() -> bool: return host.thread == null, 20.0)
	host.queue_free()
	for i: int in range(5):
		await process_frame
	DirAccess.remove_absolute(cfg)
