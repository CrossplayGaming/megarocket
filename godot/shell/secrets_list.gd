# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name SecretsList
extends RefCounted
## The Reveal secrets cheat's list (docs/MENUS.md "The cheat menu"): each game's secrets, cell by cell,
## from godot/data/secrets/<game>.json (the answer keys in docs/notes/secrets_key*.md: every secret the
## guides document, pinned to the level data, and the hidden stashes only the data shows, each checked
## by eye). Presentation only: the views tint these cells, and lift the foreground off them in Keen 4-6,
## while the cheat is on; nothing here reaches the game.

static var _games: Dictionary = {}    # game -> {level: {Vector2i: "secret" | "trap"}}


## The level's cells to reveal, by the game's data extension ("CK1" ... "CK6") and level (Keen 1-3's
## LEVELnn number, Keen 4-6's map): {Vector2i(x, y): "secret" | "trap"}, empty where there are none.
static func cells(ext: String, level: int) -> Dictionary:
	var game: String = "kdreams" if ext == "KDR" else "keen" + ext.substr(2, 1)    # (Keen Dreams' data extension: SECRET-01D)
	if not _games.has(game):
		_games[game] = _load(game)
	return _games[game].get(level, {})


static func _load(game: String) -> Dictionary:
	var out: Dictionary = {}
	var path: String = "res://data/secrets/%s.json" % game
	if not FileAccess.file_exists(path):
		return out
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(doc) != TYPE_DICTIONARY or typeof(doc.get("levels")) != TYPE_DICTIONARY:
		return out
	for key: String in doc.levels:
		var level: Dictionary = {}
		for e: Dictionary in doc.levels[key]:
			var kind: String = "trap" if str(e.get("kind", "secret")) == "trap" else "secret"
			for c: Array in e.get("cells", []):
				for y: int in range(int(c[1]), int(c[3]) + 1):
					for x: int in range(int(c[0]), int(c[2]) + 1):
						level[Vector2i(x, y)] = kind
		out[int(key)] = level
	return out
