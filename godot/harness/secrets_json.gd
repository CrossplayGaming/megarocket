# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Research tool (secrets key -> "Reveal secrets" data): builds godot/data/secrets/<game>.json from a
## spec of selectors, keeping only cells the level data shows are hiding cells or hidden items, and
## prints every cell it rejects or cannot classify. Used once, from specs kept outside the repository: the
## lists were then checked by eye and edited (SECRET-01), so godot/data/secrets/*.json are the source now.
##   --spec=<spec.json> --game=keen5 [--out=<file>] [--fore=0.9] [--check=1 (print the cells' kinds)]
##
## Spec: {"levels": {"<n>": [{"id", "what", "kind", "source", "hidden_by", "contents", "select": [...]}]}}
## Selectors (each adds cells):
##   {"look": [x, y]}          the 4-connected group of look-solid passable cells (fake walls, off-screen
##                             cells) containing (x, y), and the items in it
##   {"region": [x0,y0,x1,y1]} the finder region with exactly these bounds: its passages, hidden platforms
##                             and the items in their cells (not their open area)
##   {"rect": [x0,y0,x1,y1]}   inside the box: look-solid passable cells, hidden platforms, special
##                             hiding tiles (see SPECIAL), and items lying in secret or look-solid cells
##   {"items": [x0,y0,x1,y1]}  every item inside the box (items reached only by the secret)
##   {"passage": [x0,y0,x1,y1]} every non-blocking cell in the box (a hidden way hidden by darkness)
##   {"cells": [[x, y], ...]}  exact cells, each checked and reported (doors, drop-through floors ...)
##   {"exclude": [x0,y0,x1,y1]} drop the cells in the box (applied in order)

const SF = preload("res://maker/secret_finder.gd")

## Tiles that hide something by themselves: Keen 1's dark hidden brick, fall-through bricks and the ice
## crack; Keen 3's cloud bottom that holds Keen up; Keen 5-6's invisible solid block (foreground tile 1020).
const SPECIAL: Dictionary = {
	"keen1": {335: "hidden brick", 278: "fall-through brick", 283: "fall-through brick", 402: "crack"},
	"keen3": {532: "standable cloud"},
	"keen5": {1020: "invisible block"},
	"keen6": {1020: "invisible block"},
}

var _o: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.contains("="):
			_o[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var game: String = str(_o.get("game", "keen5"))
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(_o.spec)))
	var root: String = "F:/Keen Launcher Godot 4 Rework/game_data/"
	var vort: bool = game in ["keen1", "keen2", "keen3"]
	var vd: VortData = null
	var gd: GalData = null
	var imgs: GalImages = null
	if vort:
		vd = VortData.new()
		vd.load_game(root + game, "CK" + game.substr(4, 1))
	else:
		gd = GalData.new()
		gd.load_game(root + game, "res://data/omnispeak/" + ("keen6e14" if game == "keen6" else game))
		imgs = GalImages.new(gd)
	var fore: float = float(_o.get("fore", "0"))
	var out_levels: Dictionary = {}
	var keys: Array = spec.levels.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	var problems: int = 0
	for key: String in keys:
		var n: int = int(key)
		var r: Dictionary
		var fg: PackedInt32Array
		var info: PackedInt32Array = PackedInt32Array()
		var misc_of: Callable
		if vort:
			r = SF.vorticons(vd, n, {})
			fg = r.tiles
		else:
			r = SF.galaxy(gd, imgs, n, {"fore_opaque": fore})
			var m: Dictionary = gd.load_map(n)
			fg = m.plane[1]
			info = m.plane[2]
		var w: int = r.width
		var h: int = r.height
		var item_at: Dictionary = {}
		for c: Array in r.items:
			item_at[c[0]] = c[1]
		var entries: Array = []
		for e: Dictionary in spec.levels[key]:
			var cells: Dictionary = {}   # cell -> why
			for s: Dictionary in e.select:
				var before: int = cells.size()
				if s.has("look"):
					var p0: int = int(s.look[1]) * w + int(s.look[0])
					if r.lookalike[p0] == 0:
						print("  !! %s: look seed %s is not a look-solid cell" % [e.id, s.look])
						problems += 1
						continue
					var st: Array = [p0]
					var seen: Dictionary = {p0: true}
					while not st.is_empty():
						var p: int = st.pop_back()
						cells[p] = "fake wall" if r.offscreen[p] == 0 else "off screen"
						if item_at.has(p):
							cells[p] += " + " + item_at[p]
						for q: int in [p - 1, p + 1, p - w, p + w]:
							if q >= 0 and q < w * h and absi(q % w - p % w) <= 1 and r.lookalike[q] != 0 and not seen.has(q):
								seen[q] = true
								st.append(q)
				elif s.has("region"):
					var b: Array = s.region
					var hit: bool = false
					for reg: Dictionary in r.regions:
						if reg.x0 == int(b[0]) and reg.y0 == int(b[1]) and reg.x1 == int(b[2]) and reg.y1 == int(b[3]):
							hit = true
							for p: int in reg.passages:
								cells[p] = "passage"
							for p: int in reg.platforms:
								cells[p] = "hidden platform"
							for p: int in reg.cells:
								if item_at.has(p):
									cells[p] = cells.get(p, "secret area") + " + " + item_at[p]
					if not hit:
						print("  !! %s: no finder region inside %s" % [e.id, b])
						problems += 1
				elif s.has("passage"):
					# an open stretch of a hidden way that the level hides by darkness alone: every cell in the box
					# that does not block Keen
					var b: Array = s.passage
					for y: int in range(int(b[1]), int(b[3]) + 1):
						for x: int in range(int(b[0]), int(b[2]) + 1):
							var p: int = y * w + x
							if r.real[p] == 0:
								cells[p] = "open passage" + (" + " + item_at[p] if item_at.has(p) else "")
				elif s.has("rect") or s.has("items"):
					var b: Array = s.rect if s.has("rect") else s.items
					for y: int in range(int(b[1]), int(b[3]) + 1):
						for x: int in range(int(b[0]), int(b[2]) + 1):
							var p: int = y * w + x
							if s.has("items"):
								if item_at.has(p):
									cells[p] = "item " + item_at[p]
								continue
							var why: String = _kind(game, r, fg, p)
							if why != "":
								cells[p] = why
							if item_at.has(p) and (why != "" or r.secret[p] != 0):
								cells[p] = (why if why != "" else "secret area") + " + " + item_at[p]
				elif s.has("cells"):
					for c: Array in s.cells:
						var p: int = int(c[1]) * w + int(c[0])
						var why: String = _kind(game, r, fg, p)
						if not vort:
							var t: int = fg[p]
							var n16: int = gd.gfx.numTiles16
							var n16m: int = gd.gfx.numTiles16m
							var misc: int = gd.tileinfo[t + n16 * 2 + n16m * 5] if t > 0 and t < n16m else 0
							var top: int = gd.tileinfo[t + n16 * 2] if t > 0 and t < n16m else 0
							if (misc & 0x7F) == 2:
								why = "door (info %d)" % info[p]
							elif top == 0x39:
								why = "fuse"
							elif top == 1 and why == "":
								why = "one-way floor"
						if item_at.has(p):
							why = (why + " + " if why != "" else "") + item_at[p]
						if why == "":
							why = "UNCLASSIFIED tile %d" % fg[p]
							problems += 1
							print("  !! %s: cell %s is not a hiding cell or item (tile %d)" % [e.id, c, fg[p]])
						cells[p] = why
				elif s.has("exclude"):
					# drop cells another entry owns (two secrets the data joins into one hidden system)
					var b: Array = s.exclude
					for p: int in cells.keys():
						if p % w >= int(b[0]) and p % w <= int(b[2]) and p / w >= int(b[1]) and p / w <= int(b[3]):
							cells.erase(p)
					continue
				if cells.size() == before:
					print("  !! %s: selector %s added nothing" % [e.id, s])
					problems += 1
			if _o.has("check"):
				var kinds: Dictionary = {}
				for p: int in cells:
					kinds[cells[p]] = kinds.get(cells[p], 0) + 1
				print("%s %s: %d cells %s" % [key, e.id, cells.size(), kinds])
			var out: Dictionary = {"id": e.id, "what": e.what, "cells": _rects(cells.keys(), w),
				"kind": e.kind, "source": e.source, "hidden_by": e.hidden_by, "contents": e.contents}
			entries.append(out)
		out_levels[key] = entries
	var path: String = str(_o.get("out", "res://data/secrets/%s.json" % game))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(_json({"game": game, "levels": out_levels}) + "\n")
	f.close()
	print("%s: %d levels, %d entries, %d problems -> %s" % [game, out_levels.size(), _count(out_levels), problems, path])
	quit(0)


func _count(levels: Dictionary) -> int:
	var k: int = 0
	for v: Array in levels.values():
		k += v.size()
	return k


## Why a cell counts as hiding something, or "".
func _kind(game: String, r: Dictionary, fg: PackedInt32Array, p: int) -> String:
	var sp: Dictionary = SPECIAL.get(game, {})
	if sp.has(fg[p]):
		return sp[fg[p]]
	if r.invisible[p] != 0:
		return "hidden platform"
	if r.lookalike[p] != 0:
		return "fake wall" if r.offscreen[p] == 0 else "off screen"
	return ""


## Cells as inclusive rectangles: row runs, then runs stacked with the same span merged downwards.
func _rects(cells: Array, w: int) -> Array:
	var rows: Dictionary = {}
	for p: int in cells:
		var y: int = p / w
		if not rows.has(y):
			rows[y] = []
		rows[y].append(p % w)
	var runs: Array = []   # [x0, x1, y]
	var ys: Array = rows.keys()
	ys.sort()
	for y: int in ys:
		var xs: Array = rows[y]
		xs.sort()
		var a: int = xs[0]
		var b: int = xs[0]
		for k: int in range(1, xs.size()):
			if xs[k] == b + 1:
				b = xs[k]
			else:
				runs.append([a, b, y])
				a = xs[k]
				b = xs[k]
		runs.append([a, b, y])
	var open: Dictionary = {}   # "x0,x1" -> rect being extended
	var out: Array = []
	for run: Array in runs:
		var k: String = "%d,%d" % [run[0], run[1]]
		if open.has(k) and open[k][3] == run[2] - 1:
			open[k][3] = run[2]
		else:
			var rect: Array = [run[0], run[2], run[1], run[2]]
			open[k] = rect
			out.append(rect)
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return out


## Stable, readable JSON: one entry per line block, cells on one line.
func _json(d: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("{")
	lines.append("\t\"game\": %s," % JSON.stringify(d.game))
	lines.append("\t\"levels\": {")
	var keys: Array = d.levels.keys()
	for i: int in range(keys.size()):
		var key: String = keys[i]
		lines.append("\t\t%s: [" % JSON.stringify(key))
		var es: Array = d.levels[key]
		for j: int in range(es.size()):
			var e: Dictionary = es[j]
			var cells: PackedStringArray = PackedStringArray()
			for c: Array in e.cells:
				cells.append("[%d, %d, %d, %d]" % [c[0], c[1], c[2], c[3]])
			lines.append("\t\t\t{")
			lines.append("\t\t\t\t\"id\": %s," % JSON.stringify(e.id))
			lines.append("\t\t\t\t\"what\": %s," % JSON.stringify(e.what))
			lines.append("\t\t\t\t\"cells\": [%s]," % ", ".join(cells))
			lines.append("\t\t\t\t\"kind\": %s," % JSON.stringify(e.kind))
			lines.append("\t\t\t\t\"source\": %s," % JSON.stringify(e.source))
			lines.append("\t\t\t\t\"hidden_by\": %s," % JSON.stringify(e.hidden_by))
			lines.append("\t\t\t\t\"contents\": %s" % JSON.stringify(e.contents))
			lines.append("\t\t\t}" + ("," if j < es.size() - 1 else ""))
		lines.append("\t\t]" + ("," if i < keys.size() - 1 else ""))
	lines.append("\t}")
	lines.append("}")
	return "\n".join(lines)
