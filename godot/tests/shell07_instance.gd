# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-07: with another copy running (a real second process holding the
## lock), the launcher says so and waits; Enter (ui_accept) starts it
## anyway and it takes the lock; a lock left by a copy that is gone is
## ignored; leaving removes this copy's lock.

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var lock: String = OS.get_temp_dir().path_join("mr_lock_test_%d" % Time.get_ticks_usec())
	# a second process that stays alive for a while
	var other: int = OS.create_process("ping", ["-n", "60", "127.0.0.1"])
	t.ok("a second process runs (pid %d)" % other, other > 0 and OS.is_process_running(other))
	var f: FileAccess = FileAccess.open(lock, FileAccess.WRITE)
	f.store_string(str(other))
	f.close()
	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	l.make_art = false
	l.lock_path = lock
	root.add_child(l)
	await process_frame
	await process_frame
	t.ok("with another copy running, the launcher says so and waits", l.waiting_for_other and l._wait_panel != null)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	l._input(ev)
	await process_frame
	t.ok("Enter starts it anyway and it takes the lock", not l.waiting_for_other and FileAccess.get_file_as_string(lock).strip_edges().to_int() == OS.get_process_id())
	l.queue_free()
	await process_frame
	t.ok("leaving removes this copy's lock", not FileAccess.file_exists(lock))
	OS.kill(other)
	# a stale lock (a process that has ended) is ignored
	f = FileAccess.open(lock, FileAccess.WRITE)
	f.store_string(str(other))
	f.close()
	await create_timer(0.5).timeout
	var l2: Launcher = load("res://shell/main.tscn").instantiate()
	l2.scan_on_ready = false
	l2.make_art = false
	l2.lock_path = lock
	root.add_child(l2)
	await process_frame
	t.ok("a lock left by a copy that is gone is ignored", not l2.waiting_for_other)
	l2.queue_free()
	await process_frame
	t.finish(self)
