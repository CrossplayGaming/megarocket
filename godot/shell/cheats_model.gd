# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name CheatsModel
extends RefCounted
## The cheat rows (docs/MENUS.md "The cheat menu"), for the game's own menus to show in their idiom.
##
## The model keeps no state: every cheat is a flag of the running engine, read at one named point
## (the place the original's debug keys read theirs), so the originals' own key combinations and the
## menu agree, and every cheat is off again at every launch. An engine offers:
##   shell_cheat_supported() -> Array    the keys it has so far
##   shell_cheat_get(key) -> bool        a toggle's state
##   shell_cheat_set(key, on)            a toggle changed
##   shell_cheat_fire(key) -> String     a one-shot applied; what it did, in a few words
##   shell_in_game() -> bool             a game in progress (the rows are greyed otherwise)
## Headless runs and the oracle comparisons never attach one, and every flag stays off.

const CHEATS: Array = [
	{"key": "god", "label": "God mode", "kind": "toggle"},
	{"key": "infinite_ammo", "label": "Infinite ammo", "kind": "toggle"},
	{"key": "infinite_lives", "label": "Infinite lives", "kind": "toggle"},
	{"key": "no_clip", "label": "No clipping", "kind": "toggle"},
	{"key": "jump", "label": "Jump cheat", "kind": "toggle"},
	{"key": "slow_motion", "label": "Slow motion", "kind": "toggle"},
	{"key": "reveal_secrets", "label": "Reveal secrets", "kind": "toggle"},
	{"key": "freeze_enemies", "label": "Freeze enemies", "kind": "toggle"},
	{"key": "free_items", "label": "Free items", "kind": "once"},
	{"key": "extra_lives", "label": "Extra lives", "kind": "once"},
	{"key": "skip_level", "label": "Skip this level", "kind": "once"},
	{"key": "level_select", "label": "Level select", "kind": "pick"},
	{"key": "unlock_map", "label": "Unlock the map", "kind": "once"},
]

## The originals' own cheat key combinations, listed so they can be found (CHEAT-05): per engine, the
## keys and what holding them does. They keep working as they always did. Keen 4-6's texts are one
## short line (their card's dialog holds one under its title).
const CODES: Dictionary = {
	"vorticons": [
		["G+O+D", "Hold G, O and D in play: God mode on or off."],
		["C+T+Space", "Hold C, T and Space in play: all the keycards and lots of ammo (and the pogo stick in Keen 1)."],
	],
	"dreams": [
		["F10+G", "God mode on or off"],
		["F10+I", "99 flowers, bombs and keys"],
		["F10+J", "Jump cheat on or off"],
		["F10+S", "Slow motion on or off"],
		["F10+W", "Warp to a level (0-16)"],
	],
	"galaxy": [
		["B+A+T", "Gems, 99 shots, a life"],
		["A+2+Enter", "Turns on the F10 keys"],
		["F10+G", "God mode on or off"],
		["F10+I", "Free items"],
		["F10+J", "Jump cheat on or off"],
		["F10+N", "No clipping on or off"],
		["F10+S", "Slow motion on or off"],
		["F10+W", "Warp to a level"],
		["F10+E", "End the level"],
	],
}

## Lives the Extra lives cheat adds per use, and the most it lets the count reach (two digits on
## every game's status display).
const EXTRA_LIVES: int = 9
const MAX_LIVES: int = 99


## The rows the engine has, in the table's order: {key, label, kind, value (toggles), enabled}.
static func rows(engine: Object, kind: String = "") -> Array:
	var out: Array = []
	if engine == null or not engine.has_method("shell_cheat_supported"):
		return out
	var have: Array = engine.shell_cheat_supported()
	var in_game: bool = engine.shell_in_game()
	for c: Dictionary in CHEATS:
		if not have.has(c.key) or (kind != "" and c.kind != kind):
			continue
		var r: Dictionary = c.duplicate()
		r["value"] = engine.shell_cheat_get(c.key) if c.kind == "toggle" else null
		r["enabled"] = in_game
		out.append(r)
	return out


## A toggle flipped; returns its new state.
static func toggle(engine: Object, key: String) -> bool:
	var on: bool = not engine.shell_cheat_get(key)
	engine.shell_cheat_set(key, on)
	return engine.shell_cheat_get(key)


static func label(key: String) -> String:
	for c: Dictionary in CHEATS:
		if c.key == key:
			return c.label
	return key
