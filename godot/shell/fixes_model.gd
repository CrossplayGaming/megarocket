# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name FixesModel
extends RefCounted
## The bug-fix toggles (FIX-01, docs/MENUS.md "The bug-fix list", the first batch decided in J-27 from
## docs/FIX_TRIAGE.md). One table for every engine: the row's title, the line said under it, the games
## it belongs to. Each is a per-game setting "fix_<key>", on by default (J-03); the Classic mode turns
## every one off (OptionsModel.PRESETS), so Classic play is the original bug for bug. An engine reads a
## fix at one named point through its `fixes` (set by the host from these settings; empty, so every fix
## off, in headless runs and the oracle comparisons).
## (Keen 1's chain drop, J-28, is no toggle: it is applied in every mode.)

const FIXES: Array = [
	{"key": "k2_esc_skips", "label": "Esc skips Earth scenes", "games": ["keen2"],
		"desc": "Esc skips the Earth-explodes and flight-home scenes, as the game meant it to."},
	{"key": "k2_tantalus_fade", "label": "Tantalus double fade", "games": ["keen2"],
		"desc": "The \"Oops.\" screen no longer flashes back before the Earth explodes."},
	{"key": "k3_messie_double", "label": "Messie double Keen", "games": ["keen3"],
		"desc": "No picture shows Keen on Messie and on the shore at once."},
	{"key": "god_lurch", "label": "God mode lurch", "games": ["keen1", "keen2", "keen3"],
		"desc": "Turning God mode on or off no longer makes everything jump forward."},
	{"key": "keen_over_scenery", "label": "Keen over scenery", "games": ["keen4", "keen5"],
		"desc": "A platform cutting short a ledge climb no longer leaves Keen in front of the scenery."},
	{"key": "dreams_keys_kept", "label": "Keys kept from last game", "games": ["kdreams"],
		"desc": "A new game starts with no keys."},
	{"key": "dreams_death_box", "label": "Death box skipped", "games": ["kdreams"],
		"desc": "The Try Again box always waits for your choice."},
]


## The fixes of a game, in the table's order.
static func for_game(game: String) -> Array:
	return FIXES.filter(func(f: Dictionary) -> bool: return (f.games as Array).has(game))


## The setting that holds a fix.
static func setting(key: String) -> String:
	return "fix_" + key
