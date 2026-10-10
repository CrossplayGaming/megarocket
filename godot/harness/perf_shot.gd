# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Performance over time: a game in the host, unthrottled (speed 50), no keys (Keen 4-6 and Dreams play their
## title demos, Keen 1-3 their intro and demos), and every --every seconds of wall time how many seconds of the
## machine went by, the frames shown, the stalls dropped and the process's memory. A game that slows as it
## runs shows as a falling rate.
##
##   godot --headless --path godot --script res://harness/perf_shot.gd -- --game_data=<folder> --game=keen4
##         [--minutes=5] [--every=20] [--speed=50] [--native=on] [--level=N (straight in)] [--walk=1]

var _opts: Dictionary = {}
var _host: GameHost = null


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_run.call_deferred()


func _hold(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if _host != null and _host.paused:
			_host.set_paused(false)
		await process_frame


func _run() -> void:
	await process_frame
	var game: String = str(_opts.get("game", "keen4"))
	var cfg: String = OS.get_temp_dir().path_join("mr_perf_shot.cfg")
	var s: Settings = Settings.new(cfg)
	s.set_value("native_resolution", str(_opts.get("native", "on")) == "on", game)
	s.save()
	_host = GameHost.new()
	_host.settings_path = cfg
	_host.speed = float(_opts.get("speed", "50"))
	root.add_child(_host)
	var found: Dictionary = {"id": game, "title": game, "folder": str(_opts.get("game_data", "")).path_join(game)}
	if _opts.has("level"):
		found["play_level"] = int(_opts.level)
	if not _host.start(found):
		print("could not start: ", _host.error)
		quit(1)
		return
	var every: float = float(_opts.get("every", "20"))
	var rounds: int = int(float(_opts.get("minutes", "5")) * 60.0 / every)
	var last_t: float = 0.0
	var last_frames: int = 0
	for i: int in range(rounds):
		if _opts.has("walk"):
			# walk right, then left, a jump now and then (Ctrl), so the screen scrolls and the creatures wake
			_host.send_key(0x4D if i % 2 == 0 else 0x4B, true)
			_host.send_key(0x4B if i % 2 == 0 else 0x4D, false)
		await _hold(every)
		var t: float = _host.vm.seconds() if _host.vm != null else 0.0
		print("%4ds wall: machine %7.1fs (+%5.1f, x%.1f)  frames +%d  stalls %d  mem %.0f MB" % [
			int((i + 1) * every), t, t - last_t, (t - last_t) / every, _host.frames_made - last_frames,
			_host.stalls_dropped, OS.get_static_memory_usage() / 1048576.0])
		var e: Object = _host.engine
		if e != null and "mm_head" in e and e.mm_head != null:
			var n: int = 0
			var used: int = 0
			var keys: Dictionary = {}
			var b: Object = e.mm_head
			while b != null:
				n += 1
				used += int(b.length)
				var k: String = str(b.get("key")) if "key" in b else ""
				var kind: String = k.substr(0, k.find(":")) if k.find(":") >= 0 else k
				keys[kind] = int(keys.get(kind, 0)) + 1
				b = b.next
			print("        mm: %d blocks, %d paragraphs; by kind %s" % [n, used, keys])
		last_t = t
		last_frames = _host.frames_made
	_host.stop()
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(cfg)
	quit()
