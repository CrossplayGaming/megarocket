# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name Settings
extends RefCounted
## The shell's settings (SHELL-05, A15): every added option is one of these
## values, read by the shell, never by a simulation. Each value has a type
## and a default here; the file (user://settings.cfg) holds what the player
## changed, globally and per game ([game.keen4] sections win over [global]).
## A value the file holds in the wrong type, or out of its range, reads as
## its default (only that value is lost, never the file); a file that cannot
## be parsed at all reads as all defaults and is kept aside as .bad.

const PATH: String = "user://settings.cfg"

## name -> [default, kind, extra]: kind "bool", "int" (extra [min, max]),
## "enum" (extra: the allowed strings), "folders" (an array of paths).
const SPEC: Dictionary = {
	"game_folders": [[], "folders", null],
	"music_volume": [80, "int", [0, 100]],
	"effects_volume": [80, "int", [0, 100]],
	"view": ["enhanced", "enum", ["classic", "enhanced", "custom"]],    # Enhanced play by default (J-03)
	"pixel_shape": ["4:3", "enum", ["4:3", "square"]],
	"reduce_flashes": [false, "bool", null],
	"fullscreen": [false, "bool", null],
	"creature_question": [true, "bool", null],    # Keen 6's copy protection asked before a new game
	"native_resolution": [true, "bool", null],    # REND-02: drawn at the window's size (Enhanced)
	"smooth_motion": [true, "bool", null],        # REND-03: pictures between the game's (Enhanced)
	"wide_view": [true, "bool", null],            # REND-04: the screen's own shape, more of the level (Enhanced)
	# the bug-fix toggles (FixesModel), on by default (J-03); the Classic mode turns them off
	"fix_k2_esc_skips": [true, "bool", null],
	"fix_k2_tantalus_fade": [true, "bool", null],
	"fix_k3_messie_double": [true, "bool", null],
	"fix_god_lurch": [true, "bool", null],
	"fix_keen_over_scenery": [true, "bool", null],
	"fix_dreams_keys_kept": [true, "bool", null],
	"fix_dreams_death_box": [true, "bool", null],
}

var path: String = PATH
var _cfg: ConfigFile = ConfigFile.new()
var error: String = ""


func _init(file_path: String = PATH) -> void:
	path = file_path
	load_file()


func load_file() -> void:
	_cfg = ConfigFile.new()
	error = ""
	if not FileAccess.file_exists(path):
		return
	var text: String = FileAccess.get_file_as_string(path)
	var err: int = OK if _looks_like_config(text) else ERR_PARSE_ERROR
	if err == OK:
		err = _cfg.parse(text)
	if err != OK:
		error = ShellMessages.settings_reset(path.get_file(), error_string(err))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bad"))
		_cfg = ConfigFile.new()


## Every line a [section], a key=value, a comment or blank: checked first, so
## a broken file is set aside without the parser's complaints.
static func _looks_like_config(text: String) -> bool:
	var re: RegEx = RegEx.create_from_string(r"^\s*(\[[^\]]+\]|[A-Za-z0-9_./\-]+\s*=.*|;.*|#.*)?\s*$")
	for line: String in text.split("\n"):
		if re.search(line) == null:
			return false
	return true


func save() -> bool:
	return _cfg.save(path) == OK


static func valid(name: String, value: Variant) -> bool:
	var spec: Array = SPEC[name]
	match spec[1]:
		"bool":
			return value is bool
		"int":
			return value is int and int(value) >= int(spec[2][0]) and int(value) <= int(spec[2][1])
		"enum":
			return value is String and (spec[2] as Array).has(value)
		"folders":
			if not value is Array:
				return false
			for p: Variant in value:
				if not p is String:
					return false
			return true
	return false


## The value for a game ("" for the global one): the game's own if set and
## valid, else the global if set and valid, else the default.
func get_value(name: String, game: String = "") -> Variant:
	var spec: Array = SPEC[name]
	if game != "" and _cfg.has_section_key("game." + game, name):
		var v: Variant = _cfg.get_value("game." + game, name)
		if valid(name, v):
			return v
	if _cfg.has_section_key("global", name):
		var g: Variant = _cfg.get_value("global", name)
		if valid(name, g):
			return g
	var d: Variant = spec[0]
	return d.duplicate() if d is Array else d


## False (and nothing changes) for a value of the wrong type or range.
func set_value(name: String, value: Variant, game: String = "") -> bool:
	if not SPEC.has(name) or not valid(name, value):
		return false
	_cfg.set_value("game." + game if game != "" else "global", name, value)
	return true


## Back to the default: one value, a game's overrides, or everything.
func reset(name: String = "", game: String = "") -> void:
	var section: String = "game." + game if game != "" else "global"
	if name == "":
		if game == "":
			_cfg = ConfigFile.new()
		elif _cfg.has_section(section):
			_cfg.erase_section(section)
	elif _cfg.has_section_key(section, name):
		_cfg.erase_section_key(section, name)
