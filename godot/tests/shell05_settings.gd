# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SHELL-05: settings persist (written, read back), reset (one value, one
## game's overrides, everything), survive a damaged file value by value (a
## wrong type or range costs only that value; an unreadable file reads as
## defaults and is kept aside), a game's own value wins over the global one,
## and no simulation script reads settings (A15: grep).

var t: T = T.new()


func _init() -> void:
	var dir: String = OS.get_temp_dir().path_join("mr_settings_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var p: String = dir.path_join("settings.cfg")
	var s: Settings = Settings.new(p)
	t.ok("no file: every value is its default", s.get_value("music_volume") == 80 and s.get_value("view") == "classic" and s.get_value("game_folders") == [] and s.error == "")
	t.ok("a value of the wrong type or range is refused", not s.set_value("music_volume", 101) and not s.set_value("view", "wide") and not s.set_value("fullscreen", 1))
	s.set_value("music_volume", 30)
	s.set_value("view", "enhanced")
	s.set_value("view", "custom", "keen4")
	s.set_value("game_folders", ["D:/Games/Keen"])
	t.ok("written", s.save())
	var r: Settings = Settings.new(p)
	t.ok("read back: the global values, and Keen 4's own view wins over the global one for Keen 4 only",
		r.get_value("music_volume") == 30 and r.get_value("view") == "enhanced" and r.get_value("view", "keen4") == "custom" and
		r.get_value("view", "keen5") == "enhanced" and r.get_value("game_folders") == ["D:/Games/Keen"] and r.get_value("music_volume", "keen4") == 30)
	r.reset("view", "keen4")
	var one: bool = r.get_value("view", "keen4") == "enhanced"
	r.set_value("view", "classic", "keen6")
	r.reset("", "keen6")
	var game: bool = r.get_value("view", "keen6") == "enhanced"
	r.reset()
	t.ok("reset: one value (%s), a game's overrides (%s), everything (%s)" % [one, game, r.get_value("music_volume") == 80], one and game and r.get_value("music_volume") == 80)
	# a damaged value costs only itself
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("[global]\nmusic_volume=\"loud\"\neffects_volume=55\nview=\"sideways\"\nfullscreen=true\n")
	f.close()
	var d: Settings = Settings.new(p)
	t.ok("a damaged value reads as its default and the others keep theirs (music %s, effects %s, view %s, fullscreen %s)" %
		[d.get_value("music_volume"), d.get_value("effects_volume"), d.get_value("view"), d.get_value("fullscreen")],
		d.get_value("music_volume") == 80 and d.get_value("effects_volume") == 55 and d.get_value("view") == "classic" and d.get_value("fullscreen") == true)
	# an unreadable file
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("[global\nthis is not a settings file ===\n")
	f.close()
	var u: Settings = Settings.new(p)
	t.ok("an unreadable file reads as defaults, says so, and is kept aside (%s)" % u.error,
		u.get_value("effects_volume") == 80 and u.error != "" and FileAccess.file_exists(p + ".bad"))
	# A15: no simulation script reads settings
	var offenders: PackedStringArray = PackedStringArray()
	for root: String in ["res://games", "res://sim"]:
		_scan(root, offenders)
	t.ok("no simulation script mentions Settings or settings.cfg (%s)" % offenders, offenders.is_empty())
	t.finish(self)


func _scan(dir: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for sub: String in d.get_directories():
		_scan(dir.path_join(sub), out)
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			var text: String = FileAccess.get_file_as_string(dir.path_join(f))
			if text.contains("Settings.") or text.contains("Settings.new") or text.contains("settings.cfg"):
				out.append(f)
