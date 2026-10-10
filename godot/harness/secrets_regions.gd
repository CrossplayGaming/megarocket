extends SceneTree
## Scratch research (secrets key): the finder's regions of one level, cell by cell, as row runs.
##   --game=keen5 --level=1 [--all=1] (dents without contents too)

const SF = preload("res://maker/secret_finder.gd")


func _init() -> void:
	var o: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.contains("="):
			o[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var game: String = str(o.get("game", "keen5"))
	var n: int = int(o.get("level", "1"))
	var root: String = "F:/Keen Launcher Godot 4 Rework/game_data/"
	var r: Dictionary
	if game in ["keen1", "keen2", "keen3"]:
		var d: VortData = VortData.new()
		d.load_game(root + game, "CK" + game.substr(4, 1))
		r = SF.vorticons(d, n, {})
	else:
		var d: GalData = GalData.new()
		d.load_game(root + game, "res://data/omnispeak/" + ("keen6e14" if game == "keen6" else game))
		r = SF.galaxy(d, GalImages.new(d), n, {"fore_opaque": float(o.get("fore", "0"))})
	if r.is_empty():
		quit(0)
		return
	var w: int = r.width
	var where: Dictionary = {}
	for c: Array in r.items:
		where[c[0]] = c[1]
	if o.has("look"):
		# every 4-connected group of cells that Keen can pass through but that look solid (or lie
		# off screen), whatever the reachability: with the items in it and the reach state
		var la: PackedByteArray = r.lookalike
		var seen: Dictionary = {}
		var h: int = r.height
		for i0: int in range(w * h):
			if la[i0] == 0 or seen.has(i0):
				continue
			var cells: PackedInt32Array = PackedInt32Array()
			var st: Array = [i0]
			seen[i0] = true
			while not st.is_empty():
				var p: int = st.pop_back()
				cells.append(p)
				for q: int in [p - 1, p + 1, p - w, p + w]:
					if q >= 0 and q < w * h and absi(q % w - p % w) <= 1 and la[q] != 0 and not seen.has(q):
						seen[q] = true
						st.append(q)
			var it: PackedStringArray = PackedStringArray()
			var reached: int = 0
			var off: int = 0
			for p: int in cells:
				if where.has(p):
					it.append("%s@%d,%d" % [where[p], p % w, p / w])
				if r.reach_real[p] != 0:
					reached += 1
				if r.offscreen[p] != 0:
					off += 1
			if cells.size() < int(o.get("min", "1")) and it.is_empty():
				continue
			if it.is_empty() and not o.has("all"):
				continue
			print("look %d cells (reached %d, offscreen %d): %s" % [cells.size(), reached, off, _runs(cells, w)])
			if not it.is_empty():
				print("  items: " + " ".join(it))
		quit(0)
		return
	for reg: Dictionary in r.regions:
		if reg.kind == "dent" and reg.contents.is_empty() and not o.has("all"):
			continue
		print("%s x %d-%d y %d-%d contacts %d: %s" % [reg.kind, reg.x0, reg.x1, reg.y0, reg.y1, reg.contacts, ", ".join(PackedStringArray(reg.contents))])
		print("  passages: " + _runs(reg.passages, w))
		print("  areas: " + _runs(reg.areas, w))
		if not reg.platforms.is_empty():
			print("  platforms: " + _runs(reg.platforms, w))
		var it: PackedStringArray = PackedStringArray()
		for p: int in reg.cells:
			if where.has(p):
				it.append("%s@%d,%d" % [where[p], p % w, p / w])
		if not it.is_empty():
			print("  items: " + " ".join(it))
	quit(0)


func _runs(cells: PackedInt32Array, w: int) -> String:
	var rows: Dictionary = {}
	for p: int in cells:
		var y: int = p / w
		if not rows.has(y):
			rows[y] = []
		rows[y].append(p % w)
	var ys: Array = rows.keys()
	ys.sort()
	var out: PackedStringArray = PackedStringArray()
	for y: int in ys:
		var xs: Array = rows[y]
		xs.sort()
		var parts: PackedStringArray = PackedStringArray()
		var a: int = xs[0]
		var b: int = xs[0]
		for k: int in range(1, xs.size()):
			if xs[k] == b + 1:
				b = xs[k]
			else:
				parts.append(str(a) if a == b else "%d-%d" % [a, b])
				a = xs[k]
				b = xs[k]
		parts.append(str(a) if a == b else "%d-%d" % [a, b])
		out.append("y%d:%s" % [y, ",".join(parts)])
	return " ".join(out)
