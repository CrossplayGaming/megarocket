# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01g: Keen Dreams' story reader in the host, each release. From the title's control panel,
## Extras' third button (Read Story & Game Tips) formats the story and shows its first page; PgDn shows
## another; Escape leaves it for the panel with the game still running.
##
## Options: --game_data=<folder> [--folder=kdreams193|kdreams]

var t: T = T.new()
var host: GameHost = null


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


func _tap(code: Key) -> void:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.pressed = true
	host._input(k)
	await _pause(0.12)
	k = k.duplicate()
	k.pressed = false
	host._input(k)
	await _pause(0.3)


func _picture() -> PackedByteArray:
	return host.vm.card.frame_pixels.duplicate()


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	if root_dir == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var folder: String = T.options().get("folder", "kdreams193")
	var cfg: String = OS.get_temp_dir().path_join("mr_simd01g_%d.cfg" % Time.get_ticks_usec())
	host = GameHost.new()
	host.settings_path = cfg
	host.speed = 1.0
	root.add_child(host)
	var ok: bool = host.start({"id": "kdreams", "title": "Keen Dreams", "version": "v1.00" if folder == "kdreams" else "v1.93",
		"folder": root_dir.path_join(folder)})
	t.ok("%s starts (%s)" % [folder, host.error], ok)
	if not ok:
		t.finish(self)
		return
	var g: Object = host.engine
	await _pause(2.0)
	await _tap(KEY_ENTER)    # the text start screen
	if folder == "kdreams":
		await _pause(3.0)
		await _tap(KEY_ENTER)    # v1.00: a second start screen
	await _pause(5.0)
	await _tap(KEY_ENTER)    # the title: the control panel
	await _pause(2.0)
	await _tap(KEY_E)        # Extras: Help, the Story, High Scores
	await _pause(1.0)
	await _tap(KEY_RIGHT)
	await _pause(0.5)
	await _tap(KEY_RIGHT)    # Read Story & Game Tips
	await _pause(0.5)
	await _tap(KEY_ENTER)
	var shown: bool = await _wait(func() -> bool: return (g.get("LineOffsets") as PackedInt32Array).size() > 0, 10.0)
	await _pause(1.5)
	var lines: int = (g.get("LineOffsets") as PackedInt32Array).size()
	t.ok("the story is formatted and shown (%d lines)" % lines, shown and lines > 20)
	var first: PackedByteArray = _picture()
	await _tap(KEY_PAGEDOWN)
	await _pause(1.0)
	var second: PackedByteArray = _picture()
	t.ok("PgDn shows another page", first.size() == 64000 and second.size() == 64000 and first != second)
	await _tap(KEY_ESCAPE)
	var left: bool = await _wait(func() -> bool: return (g.get("LineOffsets") as PackedInt32Array).is_empty(), 5.0)
	await _pause(1.0)
	t.ok("Escape returns to the panel, the game running", left and host.thread != null and not bool(g.get("quitting")))
	host.stop()
	await _wait(func() -> bool: return host.thread == null, 10.0)
	host.queue_free()
	DirAccess.remove_absolute(cfg)
	t.finish(self)
