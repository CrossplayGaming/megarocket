# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CHEAT-01/02 (Keen Dreams, v1.93 in the host, real time): the Cheat keycap on Options' row opens the
## cheats as a list in the panel's box; with no game every row is greyed (God mode chosen: a word why).
## In a game: Level select enters The Melon Mines as F10+W would (its carts move from the start: the
## control); God mode and Infinite ammo go on; Free items gives 99 flowers and the throws cost nothing;
## Freeze enemies holds every creature still; Skip this level ends the level and marks it done. Pictures
## to --shots.
##
## Options: --game_data=<folder> [--folder=kdreams193|kdreams] [--shots=<folder>]

var t: T = T.new()
var host: GameHost = null
var shots: String = ""


func _init() -> void:
	_go.call_deferred()


func _wait(cond: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _pause(seconds: float) -> void:
	await _wait(func() -> bool: return false, seconds)


func _key(code: Key, down: bool) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.pressed = down
	host._input(k)


func _tap(code: Key) -> void:
	_key(code, true)
	await _pause(0.12)
	_key(code, false)
	await _pause(0.3)


func _shot(name: String) -> void:
	if shots == "":
		return
	var card: EgaCard = host.vm.card
	var px: PackedByteArray = card.frame_pixels.duplicate()
	var pal: PackedByteArray = card.frame_palette.duplicate()
	if px.size() != 64000 or pal.size() < 48:
		return
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(64000 * 3)
	for i: int in range(64000):
		var c: int = mini(px[i], pal.size() / 3 - 1) * 3
		rgb[i * 3] = pal[c]
		rgb[i * 3 + 1] = pal[c + 1]
		rgb[i * 3 + 2] = pal[c + 2]
	Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, rgb).save_png(shots.path_join(name + ".png"))


## The creatures' places (every object but Keen, the score box and his flowers).
func _creatures(g: Object) -> Array:
	var out: Array = []
	var o: Object = g.get("player")
	while o != null:
		if o != g.get("player") and o != g.get("scoreobj") and int(o.obclass) != int(g.get("powerobj")):
			out.append([o.index, o.x, o.y])
		o = o.next
	return out


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	shots = T.options().get("shots", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var cfg: String = OS.get_temp_dir().path_join("mr_cheat01d_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	# (--folder=kdreams: v1.00; the registered run is v1.93)
	var folder: String = T.options().get("folder", "kdreams193")
	host.start({"id": "kdreams", "title": "Keen Dreams", "version": "v1.00" if folder == "kdreams" else "v1.93", "folder": root_dir.path_join(folder)})
	var g: Object = host.engine
	await _pause(2.0)
	await _tap(KEY_ENTER)    # the text start screen
	await _pause(5.0)
	await _tap(KEY_ENTER)    # the title: the control panel
	await _pause(2.0)
	await _tap(KEY_O)        # Options
	await _pause(0.6)
	await _tap(KEY_C)        # the Cheat keycap
	await _pause(0.8)
	await _shot("cheat01d_title")
	var rows: Array = g._shell_list_rows("cheats")
	var cheat_rows: Array = rows.filter(func(r: Dictionary) -> bool: return str(r.key).begins_with("cheat:") and r.key != "cheat:codes")
	t.ok("with no game every cheat row is greyed (%d rows)" % cheat_rows.size(), cheat_rows.size() == 12
		and cheat_rows.all(func(r: Dictionary) -> bool: return not r.get("enabled", true)))
	# Level select's list: the release's own levels (v1.00 lacks maps 6, 8, 11 and 13; its warp there quits)
	var listed: Array = g.call(&"shell_levels").map(func(l: Array) -> int: return int(l[0]))
	var missing: Array = [6, 8, 11, 13] if folder == "kdreams" else []
	t.ok("Level select lists the release's %d levels (%s)" % [16 - missing.size(), listed], listed.size() == 16 - missing.size()
		and missing.all(func(n: int) -> bool: return not listed.has(n)))
	await _tap(KEY_ENTER)    # God mode: a word why
	await _pause(0.4)
	t.ok("God mode chosen there: nothing changes", not bool(g.get("godmode")))
	await _tap(KEY_ESCAPE)   # out of the list
	await _pause(0.6)
	await _tap(KEY_F5)       # New Game: the difficulty buttons
	await _pause(0.6)
	await _tap(KEY_ENTER)    # Normal
	t.ok("a game started on the world map", await _wait(func() -> bool: return bool(g.get("ingame")) and host.controls_live(), 20.0))
	await _pause(1.5)

	# Level select from the map: The Melon Mines (level 2, the second row)
	await _tap(KEY_ESCAPE)
	await _pause(1.0)
	await _tap(KEY_O)
	await _pause(0.5)
	await _tap(KEY_C)
	await _pause(0.6)
	await _shot("cheat01d_cheats")
	for i: int in range(11):
		await _tap(KEY_DOWN)    # Level select... (the twelfth row)
	await _shot("cheat01d_scrolled")
	await _tap(KEY_ENTER)
	await _pause(0.4)
	await _shot("cheat01d_levels")
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	t.ok("Level select: The Melon Mines entered (mapon %d)" % int(g.gamestate.mapon),
		await _wait(func() -> bool: return int(g.gamestate.mapon) == 2 and host.controls_live(), 20.0))
	await _pause(3.0)
	# a control for Freeze enemies: the mine's carts move on their own
	var first: Array = _creatures(g)
	var moved: bool = false
	for i: int in range(8):
		await _pause(0.25)
		if _creatures(g) != first:
			moved = true
	t.ok("before the cheats the creatures move (%d of them)" % first.size(), moved)

	# in the level: God mode, Infinite ammo, Free items, Freeze enemies
	await _tap(KEY_ESCAPE)
	await _pause(1.0)
	await _tap(KEY_O)
	await _pause(0.5)
	await _tap(KEY_C)
	await _pause(0.6)
	await _tap(KEY_ENTER)    # God mode
	await _pause(0.3)
	t.ok("God mode on", bool(g.get("godmode")))
	await _tap(KEY_DOWN)
	await _tap(KEY_RIGHT)    # Infinite ammo, moved
	await _pause(0.3)
	t.ok("Infinite ammo on (moved with Right)", bool(g.get("cheat_infiniteAmmo")))
	for i: int in range(7):
		await _tap(KEY_DOWN)    # Free items (the ninth row, after Reveal secrets and Freeze enemies)
	await _tap(KEY_ENTER)
	await _pause(0.3)
	t.ok("Free items: 99 flowers (%d)" % int(g.gamestate.flowerpowers), int(g.gamestate.flowerpowers) == 99)
	await _shot("cheat01d_free")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_ESCAPE)   # the list, then the panel: back to play
	await _wait(func() -> bool: return host.controls_live(), 5.0)
	await _pause(0.5)
	_key(KEY_SPACE, true)    # throw flowers
	await _pause(1.2)
	_key(KEY_SPACE, false)
	await _pause(0.3)
	t.ok("the throws cost nothing (%d flowers)" % int(g.gamestate.flowerpowers), int(g.gamestate.flowerpowers) == 99)
	await _tap(KEY_ESCAPE)
	await _pause(1.0)
	await _tap(KEY_O)
	await _pause(0.5)
	await _tap(KEY_C)
	await _pause(0.6)
	for i: int in range(7):
		await _tap(KEY_DOWN)    # Freeze enemies (the eighth row)
	await _tap(KEY_ENTER)
	await _pause(0.3)
	t.ok("Freeze enemies on", bool(g.get("cheat_freezeEnemies")))
	await _tap(KEY_ESCAPE)
	await _tap(KEY_ESCAPE)
	await _wait(func() -> bool: return host.controls_live(), 5.0)
	await _pause(0.5)
	var before: Array = _creatures(g)
	await _pause(1.5)
	var after: Array = _creatures(g)
	t.ok("frozen: %d creatures where they were 1.5 s on" % before.size(), before.size() > 0 and before == after)

	# Skip this level: back on the map with the level done
	await _tap(KEY_ESCAPE)
	await _pause(1.0)
	await _tap(KEY_O)
	await _pause(0.5)
	await _tap(KEY_C)
	await _pause(0.6)
	for i: int in range(10):
		await _tap(KEY_DOWN)    # Skip this level (the eleventh row)
	await _tap(KEY_ENTER)
	t.ok("Skip this level: on the map, The Melon Mines done",
		await _wait(func() -> bool: return int(g.gamestate.mapon) == 0 and bool(g.gamestate.leveldone[2]) and host.controls_live(), 20.0))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
