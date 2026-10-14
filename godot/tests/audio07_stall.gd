# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## AUDIO-07 (needs a window and a sound device: run by hand, not headless): Keen 4 playing, the screen's
## side stalled three times for 450 ms; the sound, fed on its own thread, never runs dry (0 skips; 513
## when it was fed from the screen's frame, 2026-10-14).
##   godot --path godot --script res://tests/audio07_stall.gd
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var host: GameHost = GameHost.new()
	root.add_child(host)
	host.start({"id": "keen4", "title": "Keen 4", "folder": ProjectSettings.globalize_path("res://").path_join("../game_data/keen4"), "play_level": 1})
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		if host.paused: host.set_paused(false)
		await process_frame
	var s0: int = host._playback.get_skips()
	for i in 3:
		OS.delay_msec(450)    # the screen's side stalls
		for k in 60: await process_frame
	print("FREEZE skips during three 450 ms screen stalls: ", host._playback.get_skips() - s0)
	host.stop()
	while host.thread != null: await process_frame
	quit()
