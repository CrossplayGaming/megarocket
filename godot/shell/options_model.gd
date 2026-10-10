# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name OptionsModel
extends RefCounted
## The rows of the in-game Options screens (MENU-01..04, docs/MENUS.md), the same for every engine:
## each engine's own menu system draws them in its own idiom (Keen 1-3's text windows, 4-6's cards,
## Dreams' panel) and hands back the player's presses. The values are shell settings (A15): this model
## reads and writes them for the running game and asks the host to apply a change at once (on the
## main thread); no simulation reads them. Rows join as the features they control are built.
##
## A row: {key, label, kind: "value" | "page" | "action", value: the shown value ("" for others)}.
## step(key, dir) moves a value row; activate(key) returns what the menu should do:
## "page:<name>", "action:<name>" or "" (a value row: nothing more).

## The player's settings (per game: changes made in a game are that game's own).
var settings: Settings = null
var game_id: String = ""
## "vorticons" | "galaxy" | "dreams": decides rows that only some engines have.
var engine: String = ""
## Called (deferred to the main thread) with a setting's name after it changed.
var applier: Callable = Callable()
## The Mode presets: the rows each sets (MENUS.md "The Mode row"). The wide view, native resolution, smooth motion and the fixes so far
## (FixesModel): all off in Classic, on in Enhanced; one-button fire joins
## as they are built.
const PRESETS: Dictionary = {
	"classic": {"wide_view": false, "native_resolution": false, "smooth_motion": false, "fix_k2_esc_skips": false, "fix_k2_tantalus_fade": false, "fix_k3_messie_double": false, "fix_god_lurch": false, "fix_keen_over_scenery": false, "fix_dreams_keys_kept": false, "fix_dreams_death_box": false},
	"enhanced": {"wide_view": true, "native_resolution": true, "smooth_motion": true, "fix_k2_esc_skips": true, "fix_k2_tantalus_fade": true, "fix_k3_messie_double": true, "fix_god_lurch": true, "fix_keen_over_scenery": true, "fix_dreams_keys_kept": true, "fix_dreams_death_box": true},
}
const VOLUME_STEP: int = 10


func _init(p_settings: Settings, p_game: String, p_engine: String) -> void:
	settings = p_settings
	game_id = p_game
	engine = p_engine


## The rows of a page: "options" (the top), "display", "sound", "controls".
func page(name: String) -> Array:
	match name:
		"options":
			return [
				_value("mode", "Mode", mode_text()),
			] + ([_value("creature_question", "Creature question", _on_off(get_value("creature_question")))] if game_id == "keen6" else []) + [
				_row("display", "Display...", "page"),
				_row("sound", "Sound...", "page"),
				_row("controls", "Controls...", "page"),
			] + ([_row("fixes", "Fixes...", "page")] if engine == "vorticons" and not FixesModel.for_game(game_id).is_empty() else []) + (
				[_row("cheats", "Cheats...", "page")] if engine == "vorticons" else []) + [
				_row("quit_game", "Quit game", "action"),
				_row("exit", "Exit", "action"),
			]
		"display":
			# Native resolution: Keen 1-3's so far (REND-02)
			return ([_value("wide_view", "View", "Wide" if bool(get_value("wide_view")) else "4:3"),
				_value("native_resolution", "Native resolution", _on_off(get_value("native_resolution"))),
				_value("smooth_motion", "Smooth motion", _on_off(get_value("smooth_motion")))] if engine == "vorticons" else []) + [
				_value("fullscreen", "Fullscreen", _on_off(get_value("fullscreen"))),
				_value("pixel_shape", "Pixel shape", "4:3" if get_value("pixel_shape") == "4:3" else "Square"),
				_row("exit", "Back", "action"),
			]
		"sound":
			var rows: Array = [_value("effects_volume", "Effects volume", "%d%%" % int(get_value("effects_volume")))]
			if engine == "galaxy":
				rows.append(_value("music_volume", "Music volume", "%d%%" % int(get_value("music_volume"))))
			rows.append(_row("exit", "Back", "action"))
			return rows
		"fixes":
			# each with the line said under it when it is selected (MENUS.md)
			var rows: Array = []
			for f: Dictionary in FixesModel.for_game(game_id):
				var r: Dictionary = _value(FixesModel.setting(f.key), f.label, _on_off(get_value(FixesModel.setting(f.key))))
				r["desc"] = f.desc
				rows.append(r)
			rows.append(_row("exit", "Back", "action"))
			return rows
		"controls":
			var rows: Array = []
			if engine == "vorticons":
				rows.append(_row("keyboard_commands", "Keyboard commands", "action"))
			rows.append(_row("exit", "Back", "action"))
			return rows
	return []


## A value row moved left (dir -1) or right (+1).
func step(key: String, dir: int) -> void:
	match key:
		"mode":
			# Classic and Enhanced in turn; Custom is never chosen, only read (MENUS.md)
			var next: String = "enhanced" if get_value("view") != "enhanced" else "classic"
			_put("view", next)
			for k: String in PRESETS[next]:
				_put(k, PRESETS[next][k])
		"fullscreen":
			_put("fullscreen", not bool(get_value("fullscreen")))
		"creature_question":
			_put("creature_question", not bool(get_value("creature_question")))
		"native_resolution", "smooth_motion", "wide_view":
			_put(key, not bool(get_value(key)))
		"pixel_shape":
			_put("pixel_shape", "square" if get_value("pixel_shape") == "4:3" else "4:3")
		"effects_volume", "music_volume":
			_put(key, clampi(int(get_value(key)) + dir * VOLUME_STEP, 0, 100))
		_:
			if key.begins_with("fix_"):
				_put(key, not bool(get_value(key)))
	_recompute_mode()


## What choosing a row does.
func activate(key: String) -> String:
	# "cheats": the engine builds that page itself from CheatsModel (its rows are the engine's flags)
	for name: String in ["display", "sound", "controls", "cheats", "fixes"]:
		if key == name:
			return "page:" + name
	match key:
		"quit_game", "exit", "keyboard_commands":
			return "action:" + key
	step(key, 1)    # confirm on a value row moves it on, as the engines' own toggles do
	return ""


## "Classic", "Enhanced" or "Custom": Custom once a preset row differs from the mode chosen.
func mode_text() -> String:
	var m: String = str(get_value("view"))
	return {"classic": "Classic", "enhanced": "Enhanced", "custom": "Custom"}.get(m, "Classic")


func get_value(name: String) -> Variant:
	return settings.get_value(name, game_id)


## The running game's fixes, key -> on, for the engine (its `fixes`).
func fixes() -> Dictionary:
	var out: Dictionary = {}
	for f: Dictionary in FixesModel.for_game(game_id):
		out[f.key] = bool(get_value(FixesModel.setting(f.key)))
	return out


func _put(name: String, value: Variant) -> void:
	if settings.set_value(name, value, game_id):
		settings.save()
		if applier.is_valid():
			applier.call_deferred(name)


## Mode reads the preset every preset row matches (the one chosen first), or Custom.
func _recompute_mode() -> void:
	var m: String = str(get_value("view"))
	var order: Array = [m] if PRESETS.has(m) else []
	for p: String in ["enhanced", "classic"]:
		if not order.has(p):
			order.append(p)
	for p: String in order:
		var all: bool = true
		for k: String in PRESETS[p]:
			if get_value(k) != PRESETS[p][k]:
				all = false
				break
		if all:
			if m != p:
				_put("view", p)
			return
	if m != "custom":
		_put("view", "custom")


static func _row(key: String, label: String, kind: String) -> Dictionary:
	return {"key": key, "label": label, "kind": kind, "value": ""}


static func _value(key: String, label: String, value: String) -> Dictionary:
	return {"key": key, "label": label, "kind": "value", "value": value}


static func _on_off(v: Variant) -> String:
	return "On" if bool(v) else "Off"
