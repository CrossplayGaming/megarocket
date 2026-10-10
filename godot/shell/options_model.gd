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
## CTRL-03..05: the player's keys and buttons (shared by every game), for the Controls pages.
var controls: ControlsModel = null
## The Mode presets: the rows each sets (MENUS.md "The Mode row"). The wide view, native resolution, smooth motion and the fixes so far
## (FixesModel): one-button fire, all off in Classic, on in Enhanced; more join
## as they are built.
const PRESETS: Dictionary = {
	"classic": {"quicksave": false, "one_button_fire": false, "wide_view": false, "native_resolution": false, "smooth_motion": false, "fix_k2_esc_skips": false, "fix_k2_tantalus_fade": false, "fix_k3_messie_double": false, "fix_god_lurch": false, "fix_keen_over_scenery": false, "fix_dreams_keys_kept": false, "fix_dreams_death_box": false},
	"enhanced": {"quicksave": true, "one_button_fire": true, "wide_view": true, "native_resolution": true, "smooth_motion": true, "fix_k2_esc_skips": true, "fix_k2_tantalus_fade": true, "fix_k3_messie_double": true, "fix_god_lurch": true, "fix_keen_over_scenery": true, "fix_dreams_keys_kept": true, "fix_dreams_death_box": true},
}
const VOLUME_STEP: int = 10


func _init(p_settings: Settings, p_game: String, p_engine: String) -> void:
	settings = p_settings
	game_id = p_game
	engine = p_engine


## The rows of a page: "options" (the top), "display", "sound", "controls", "keys", "pad", "fixes",
## "bindact:<device>:<action>".
func page(name: String) -> Array:
	if name.begins_with("bindact:"):
		var p: PackedStringArray = name.split(":")
		return bind_rows(p[1], p[2])
	match name:
		"options":
			return [
				_value("mode", "Mode", mode_text()),
			] + ([_value("creature_question", "Creature question", _on_off(get_value("creature_question")))] if game_id == "keen6" else []) + (
				# SAVE-02: Keen 4-6's quicksave (F5) and quickload (F9), and whether they ask first
				[_value("quicksave", "Quicksave F5/F9", _on_off(get_value("quicksave"))),
				_value("quicksave_confirm", "Quicksave asks", _on_off(get_value("quicksave_confirm")))] if engine == "galaxy" else []) + [
				_row("display", "Display...", "page"),
				_row("sound", "Sound...", "page"),
				_row("controls", "Controls...", "page"),
			] + ([_row("fixes", "Fixes...", "page")] if engine == "vorticons" and not FixesModel.for_game(game_id).is_empty() else []) + (
				[_row("cheats", "Cheats...", "page")] if engine == "vorticons" else []) + [
				_row("quit_game", "Quit game", "action"),
				_row("exit", "Exit", "action"),
			]
		"display":
			# the wide view, native resolution and smooth motion: Keen 1-6 (REND-02..04); not Dreams yet
			return ([_value("wide_view", "View", "Wide" if bool(get_value("wide_view")) else "4:3"),
				_value("native_resolution", "Native resolution", _on_off(get_value("native_resolution"))),
				_value("smooth_motion", "Smooth motion", _on_off(get_value("smooth_motion")))] if engine != "dreams" else []) + [
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
			# CTRL-03..05 (the user, 2026-10-10): the same pages in every game, each in its own style; the old
			# control screens (Keen 1-3's Keyboard Commands, 4-6's KEYBOARD cards, Dreams' panel) replaced
			var rows: Array = [_row("keys", "Keyboard...", "page"), _row("pad", "Controller...", "page")]
			if engine == "vorticons":
				# J-06: Fire on its own key (Fire's keys hold both buttons), or the original's two together
				rows.append(_value("one_button_fire", "Fire button", "Own button" if bool(get_value("one_button_fire")) else "Two keys"))
			elif engine == "galaxy":
				# TWO-BUTTON FIRING, the original's option, as this row's Jump + Pogo
				rows.append(_value("two_button_fire", "Fire button", "Jump + Pogo" if bool(get_value("two_button_fire")) else "Own button"))
			if engine == "vorticons":
				# SAVE-02: Keen 1-3's quicksave keys (F5 stays the original's save menu: 1.0's F7 and F9)
				rows.append(_value("quicksave", "Quicksave F7/F9", _on_off(get_value("quicksave"))))
				rows.append(_value("quicksave_confirm", "Quicksave asks", _on_off(get_value("quicksave_confirm"))))
			rows.append(_row("reset_controls", "Reset to defaults", "action"))
			rows.append(_row("exit", "Back", "action"))
			return rows
		"keys", "pad":
			# each action and its keys or buttons; choosing one offers what to do with it
			var rows: Array = []
			if controls != null:
				for r: Dictionary in controls.rows(name, engine):
					rows.append({"key": "bind:%s:%s" % [name, r.key], "label": r.label, "kind": "value", "value": r.value})
			if name == "pad":
				rows.append({"key": "pad_fixed", "label": "Move: d-pad, stick", "kind": "action", "enabled": false})
			rows.append(_row("exit", "Back", "action"))
			return rows
	return []


## An action's page (CTRL-03..05): change its first key or button, add a second, clear, back. "bindact:
## <device>:<action>"; Add second only while it has one.
func bind_rows(device: String, action: String) -> Array:
	var have: Array = controls.keys(action) if device == "keys" else controls.buttons(action)
	var rows: Array = [_row("capture:%s:%s:0" % [device, action], "Change", "action")]
	if have.size() == 1:
		rows.append(_row("capture:%s:%s:1" % [device, action], "Add second", "action"))
	if not have.is_empty():
		rows.append(_row("clear:%s:%s" % [device, action], "Clear", "action"))
	rows.append(_row("exit", "Back", "action"))
	# what the action has now, said under every row (the engines show a row's line where they can)
	for r: Dictionary in rows:
		r["desc"] = "%s: %s" % [_action_label(action), controls.shown(device, action)]
	return rows


## What to say before a capture: "Press a key for Jump".
func capture_prompt(device: String, action: String) -> String:
	return "Press a %s for %s" % ["key" if device == "keys" else "button", _action_label(action)]


## A key or button caught for an action (code < 0: cancelled, or none in time): bound, and what happened
## in a few words ("Jump: Q", "Q was Pogo's, now Jump's", "Escape stays the game's").
func capture_done(device: String, action: String, slot: int, code: int) -> String:
	if code < 0:
		return "Not changed"
	var name: String = ControlsModel.key_name(code) if device == "keys" else ControlsModel.button_name(code)
	var taken: String = controls.bind(device, action, code, slot)
	if applier.is_valid():
		applier.call_deferred("controls")
	if taken == "!":
		return "%s stays the game's own" % name
	if taken != "":
		return "%s was %s's, now %s's" % [name, _action_label(taken), _action_label(action)]
	return "%s: %s" % [_action_label(action), controls.shown(device, action)]


func clear_binding(device: String, action: String) -> void:
	controls.clear(device, action)
	if applier.is_valid():
		applier.call_deferred("controls")


func reset_controls() -> void:
	controls.reset()
	if applier.is_valid():
		applier.call_deferred("controls")


func action_label(action: String) -> String:
	return _action_label(action)


func _action_label(action: String) -> String:
	return "Throw" if engine == "dreams" and action == "fire" else str(ControlsModel.LABELS.get(action, action))


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
		"native_resolution", "smooth_motion", "wide_view", "one_button_fire", "two_button_fire", "quicksave", "quicksave_confirm":
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
	for name: String in ["display", "sound", "controls", "cheats", "fixes", "keys", "pad"]:
		if key == name:
			return "page:" + name
	if key.begins_with("bind:"):
		return "page:bindact:" + key.substr(5)    # the action's own page
	if key.begins_with("capture:") or key.begins_with("clear:"):
		return "action:" + key
	match key:
		"quit_game", "exit", "reset_controls":
			return "action:" + key
		"pad_fixed":
			return ""    # (the fixed movement: nothing to choose)
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
