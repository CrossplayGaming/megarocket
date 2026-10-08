# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-02 (part): each found game's tile shows its own title screen, made
## from the player's files (J-12): Keen 1 by running its engine to the title,
## Keen 4 from its PIC_TITLESCREEN; a cached picture is reused. Pictures are
## checked for the title's colours, not just presence.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var root_dir: String = T.options().get("game_data", "")
	for id: String in ["keen1", "keen4"]:
		var f: Dictionary = {"id": id, "version": "test", "folder": root_dir.path_join(id), "status": "ok", "title": id}
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TitleArt.cache_path(f)))
		var t0: int = Time.get_ticks_msec()
		var img: Image = TitleArt.make(f)
		var made_ms: int = Time.get_ticks_msec() - t0
		var colours: Dictionary = {}
		if img != null:
			for y: int in range(0, img.get_height(), 7):
				for x: int in range(0, img.get_width(), 7):
					colours[img.get_pixel(x, y).to_html(false)] = true
		t0 = Time.get_ticks_msec()
		var again: Image = TitleArt.make(f)
		var cached_ms: int = Time.get_ticks_msec() - t0
		t.ok("%s: the title picture is made (%s, %d colours, %d ms) and the cached one reused (%d ms, same picture)" %
			[id, img.get_size() if img != null else "none", colours.size(), made_ms, cached_ms],
			img != null and img.get_width() == 320 and colours.size() >= 6 and again != null and again.get_data() == img.get_data())
	# the launcher shows them on the tiles
	var l: Launcher = load("res://shell/main.tscn").instantiate()
	l.scan_on_ready = false
	root.add_child(l)
	l.show_results([{"id": "keen1", "title": "K1", "version": "test", "status": "ok", "folder": root_dir.path_join("keen1"), "message": "", "exe": ""},
		{"id": "keen4", "title": "K4", "version": "test", "status": "ok", "folder": root_dir.path_join("keen4"), "message": "", "exe": ""}])
	var until: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until and l.art_shown.size() < 2:
		await process_frame
	t.ok("the launcher shows title art on the found tiles (%s) and none on the missing ones" % [l.art_shown.keys()],
		l.art_shown.has("keen1") and l.art_shown.has("keen4") and not l.art_shown.has("keen2"))
	l.queue_free()
	await process_frame
	t.finish(self)
