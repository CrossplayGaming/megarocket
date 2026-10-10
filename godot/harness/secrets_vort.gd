extends SceneTree
## Scratch research (secrets key, Keen 1-2): tile twins and ASCII maps of each level.
##   --game=keen1 --out=<dir> [--near=N]

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var game: String = str(_opts.get("game", "keen1"))
	var out: String = str(_opts.get("out", "."))
	var near_lim: int = int(_opts.get("near", "40"))
	var d: VortData = VortData.new()
	var ext: String = "CK" + game.substr(4, 1)
	if not d.load_game("F:/Keen Launcher Godot 4 Rework/game_data/" + game, ext):
		print("load failed ", d.error)
		quit(1)
		return
	var tables: Array = SecretFinder.vort_tables(d)
	var intile: PackedInt32Array = tables[1]
	var nw: PackedInt32Array = tables[2]
	var ew: PackedInt32Array = tables[3]
	var sw: PackedInt32Array = tables[4]
	var ww: PackedInt32Array = tables[5]
	var nt: int = mini(intile.size(), d.num_tiles)
	var walls: Callable = func(t: int) -> int:
		if t < 0 or t >= nt:
			return 15
		return (1 if nw[t] != 0 else 0) | (2 if ew[t] != 0 else 0) | (4 if sw[t] != 0 else 0) | (8 if ww[t] != 0 else 0)
	# which tiles the levels use
	var used: Dictionary = {}
	var levels: PackedInt32Array = d.level_numbers()
	for n: int in levels:
		var lv: Dictionary = d.load_level(n)
		if lv.is_empty():
			continue
		for t: int in lv.plane[0]:
			used[t] = true
	var img: Callable = func(t: int) -> PackedByteArray:
		return d.tiles.slice(t * 256, t * 256 + 256)
	var diff: Callable = func(a: PackedByteArray, b: PackedByteArray) -> int:
		var k: int = 0
		for q: int in range(256):
			if a[q] != b[q]:
				k += 1
		return k
	# deceptive tiles: a used tile whose look is (near) another used tile's with different walls
	var deceive: Dictionary = {}     # t -> [kind, twin, pixels differing]
	var ulist: Array = used.keys()
	ulist.sort()
	var report: PackedStringArray = PackedStringArray()
	for a: int in ulist:
		if a < 0 or a >= nt or intile[a] != 0 and intile[a] != -1 and intile[a] != -2:
			continue
		var ia: PackedByteArray = img.call(a)
		var best: int = 999
		var bt: int = -1
		for b: int in ulist:
			if b == a or b < 0 or b >= nt:
				continue
			if walls.call(a) == walls.call(b):
				continue
			var wa: int = walls.call(a)
			var wb: int = walls.call(b)
			# interesting pairs: a passable look-solid (a 0, b solid) or a solid look-empty (a solid, b 0)
			if not ((wa == 0 and wb != 0) or (wa != 0 and wb == 0)) and not _opts.has("any"):
				continue
			var dd: int = diff.call(ia, img.call(b))
			if dd < best:
				best = dd
				bt = b
		if bt >= 0 and best <= near_lim:
			var kind: String = "FAKE" if walls.call(a) == 0 else ("HIDDEN" if walls.call(bt) == 0 else "ODD")
			deceive[a] = [kind, bt, best]
			report.append("tile %d (walls %d intile %d) looks like %d (walls %d intile %d): %d px differ -> %s" % [a, walls.call(a), intile[a], bt, walls.call(bt), intile[bt], best, kind])
	var f: FileAccess = FileAccess.open(out.path_join(game + "_twins.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	print("\n".join(report))
	var item_ch: Dictionary = {6: "*", 7: "*", 8: "*", 9: "*", 10: "$", 15: "a", 16: "p", 17: "E", 18: "k", 19: "k", 20: "k", 21: "k", 24: "W", 27: "A", 28: "a", 1: "^"}
	for n: int in levels:
		var lv: Dictionary = d.load_level(n)
		if lv.is_empty():
			continue
		var w: int = lv.width
		var h: int = lv.height
		var tp: PackedInt32Array = lv.plane[0]
		var sp: PackedInt32Array = lv.plane[1]
		var lines: PackedStringArray = PackedStringArray()
		var hdr: String = "    "
		for x: int in range(w):
			hdr += str(x / 10 % 10) if x % 10 == 0 else " "
		lines.append(hdr)
		var cells: PackedStringArray = PackedStringArray()
		for y: int in range(h):
			var s: String = "%3d " % y
			for x: int in range(w):
				var t: int = tp[y * w + x]
				var c: String = "."
				var wl: int = walls.call(t)
				if wl == 15:
					c = "#"
				elif wl == 1:
					c = "="
				elif wl != 0:
					c = "%x" % wl
				if t >= 0 and t < nt:
					var it: int = intile[t]
					if item_ch.has(it):
						c = item_ch[it]
					elif it >= 2 and it <= 5:
						c = "D"
					elif it < 0 and wl == 0:
						c = ","
				if deceive.has(t):
					c = "F" if deceive[t][0] == "FAKE" else ("o" if deceive[t][0] == "ODD" else ("H" if wl == 15 else "h"))
					cells.append("%d,%d t%d %s(like %d, %dpx)" % [x, y, t, deceive[t][0], deceive[t][1], deceive[t][2]])
				if sp.size() > y * w + x and sp[y * w + x] != 0:
					c = "S" if sp[y * w + x] == 255 else "m"
				s += c
			lines.append(s)
		var g: FileAccess = FileAccess.open(out.path_join("%s_level%02d.txt" % [game, n]), FileAccess.WRITE)
		g.store_string("\n".join(lines) + "\n\n" + "\n".join(cells) + "\n")
		g.close()
		print("level %d: %d deceptive cells" % [n, cells.size()])
	quit(0)
