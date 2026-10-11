# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Scratch research (secrets key, Keen Dreams): what each map holds and what hides it. Per map: its
## items (the info plane's bonuses, 21-32), those the game draws a masked foreground tile over (INTILE's
## top bit, painting at least --cover percent of the cell: hidden), fake walls (a passable foreground
## tile drawn exactly like a wall tile the level uses; a pole drawn like one), the passable cells drawn
## over Keen, and an ASCII map in <out>/<game>_mapNN.txt; --compare says whether the two releases'
## maps are the same.
##   godot --headless --path godot --script res://harness/secrets_dreams.gd -- --game_data=<folder>
##         --out=<dir> [--game=kdreams193] [--levels=1,2] [--cover=75] [--compare=1]
##         [--rect=x0,y0,x1,y1 (one level: bg/fg.flags,info per cell)] [--find=f1,f2 (cells with these
##         foreground tiles)] [--groups=1 (the deceiving cells and hidden items as connected groups, in
##         rectangles, with the items in them)]
## ASCII: # wall, v a pit (no top, walled below: a fall off the map), = top only (one-way), / slope,
## x deadly floor, | pole, F passable drawn over Keen
## (--cover or more), f fake wall (passable, drawn like a wall), p hidden pole, h hidden platform (a
## wall drawn like the open cells around it), x deadly drawn like safe, s safe drawn like deadly, o
## another mix, + item, H hidden item, d door, K start, , passable with some foreground, . open;
## --items=1 lists every item's place.

const INFO_ITEMS: Dictionary = {21: "100", 22: "200", 23: "500", 24: "1000", 25: "2000", 26: "5000",
	27: "1UP", 28: "eyeball", 29: "flower", 30: "superflower", 31: "bomb", 32: "key"}
const T16: int = DreamsData.NUMTILE16
const T16M: int = DreamsData.NUMTILE16M
const NORTH: int = T16 * 2
const EAST: int = NORTH + T16M
const SOUTH: int = EAST + T16M
const WEST: int = SOUTH + T16M
const INTILE: int = WEST + T16M * 2

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var root: String = str(_opts.get("game_data", "F:/Keen Launcher Godot 4 Rework/game_data"))
	var game: String = str(_opts.get("game", "kdreams193"))
	var out: String = str(_opts.get("out", OS.get_temp_dir().path_join("secrets_dreams")))
	DirAccess.make_dir_recursive_absolute(out)
	var d: DreamsData = DreamsData.new()
	if not d.load_game(root.path_join(game)):
		print("load failed: ", d.error)
		quit(1)
		return
	if _opts.has("compare"):
		_compare(d, root.path_join("kdreams" if game == "kdreams193" else "kdreams193"))
	var levels: Array = []
	if _opts.has("levels"):
		for s: String in str(_opts.levels).split(","):
			levels.append(int(s))
	var m16: Dictionary = d.tiles16m()
	var cover: PackedInt32Array = PackedInt32Array()
	var key: PackedStringArray = PackedStringArray()
	cover.resize(T16M)
	key.resize(T16M)
	for t: int in range(T16M):
		var painted: int = 0
		var k: PackedByteArray = PackedByteArray()
		k.resize(256)
		for i: int in range(256):
			var o: int = t * 256 + i
			if m16.mask[o] == 0:
				painted += 1
				k[i] = m16.pixels[o] & 15
			else:
				k[i] = 16
		cover[t] = painted * 100 / 256
		key[t] = k.hex_encode()
	var min_cover: int = int(_opts.get("cover", "75"))
	for i: int in range(DreamsData.NUM_MAPS):
		if not d.has_map(i) or (not levels.is_empty() and not i in levels):
			continue
		var m: Dictionary = d.load_map(i)
		if m.is_empty():
			print("map %d: %s" % [i, d.error])
			d.error = ""
			continue
		if _opts.has("rect"):
			_rect(d, m, i)
			continue
		if _opts.has("find"):
			_find(m, i)
			continue
		_level(d, m, i, cover, key, min_cover, out.path_join("%s_map%02d.txt" % [game, i]))
	quit(0)


func _walls(d: DreamsData, f: int) -> int:
	if f <= 0 or f >= T16M:
		return 0
	return (1 if d.tileinfo[NORTH + f] != 0 else 0) | (2 if d.tileinfo[EAST + f] != 0 else 0) \
		| (4 if d.tileinfo[SOUTH + f] != 0 else 0) | (8 if d.tileinfo[WEST + f] != 0 else 0)


func _intile(d: DreamsData, f: int) -> int:
	if f <= 0 or f >= T16M:
		return 0
	return d.tileinfo[INTILE + f]


## How a foreground tile acts: open, pole, wall (which sides), with "deadly" when its top kills.
func _behaviour(d: DreamsData, f: int) -> String:
	var wl: int = _walls(d, f)
	var deadly: bool = f > 0 and f < T16M and d.tileinfo[NORTH + f] >= 8
	var s: String
	if (_intile(d, f) & 0x7F) == 1:
		s = "pole"
	elif wl == 0:
		s = "open"
	else:
		s = "wall %x" % wl
	return s + (" deadly" if deadly else "")


func _level(d: DreamsData, m: Dictionary, n: int, cover: PackedInt32Array, key: PackedStringArray, min_cover: int, path: String) -> void:
	var w: int = int(m.width)
	var h: int = int(m.height)
	var fg: PackedInt32Array = m.plane[1]
	var info: PackedInt32Array = m.plane[2]
	# the level's foreground tiles by picture: a passable one drawn like a wall is a fake wall
	var groups: Dictionary = {}   # key -> [tiles]
	for p: int in range(w * h):
		var f: int = fg[p]
		if f > 0 and f < T16M:
			if not groups.has(key[f]):
				groups[key[f]] = {}
			groups[key[f]][f] = true
	var used: Dictionary = {}     # tile -> cells
	for p: int in range(w * h):
		used[fg[p]] = used.get(fg[p], 0) + 1
	# tiles drawn alike that act differently: the rarer side is the deceit. Passable cells drawn like
	# the rock around them are fake walls (f), a pole in them p; walls drawn like the water or sky
	# around them hidden platforms (h); a deadly floor drawn like a safe one a trap (x), a safe floor
	# drawn like deadly ones a hidden platform in a hazard (s); other mixes o.
	var fake: Dictionary = {}     # tile -> mark
	var twins: PackedStringArray = PackedStringArray()
	for k: String in groups:
		var tiles: Array = groups[k].keys()
		var by: Dictionary = {}   # behaviour -> cells
		for t: int in tiles:
			var b: String = _behaviour(d, t)
			by[b] = by.get(b, 0) + used[t]
		if by.size() < 2:
			continue
		var major: String = ""
		for b: String in by:
			if major == "" or by[b] > by[major]:
				major = b
		var line: PackedStringArray = PackedStringArray()
		for t: int in tiles:
			var b: String = _behaviour(d, t)
			line.append("%d(%s, %d cells)" % [t, b, used[t]])
			if b == major:
				continue
			var mark: String = "o"
			if b.begins_with("pole"):
				mark = "p"
			elif b == "open" and major.begins_with("wall"):
				mark = "f"
			elif b.begins_with("wall") and not b.ends_with("deadly") and (major == "open" or major.begins_with("pole")):
				mark = "h"
			elif b.ends_with("deadly") and not major.ends_with("deadly"):
				mark = "x"
			elif major.ends_with("deadly") and not b.ends_with("deadly") and b != "open":
				mark = "s"
			fake[t] = mark
		twins.append(" ".join(line))
	var start: Vector2i = Vector2i(-1, -1)
	var items: Dictionary = {}
	var where: PackedStringArray = PackedStringArray()
	var hidden: PackedStringArray = PackedStringArray()
	var fakes: PackedInt32Array = PackedInt32Array()
	var overs: PackedInt32Array = PackedInt32Array()
	var lines: PackedStringArray = PackedStringArray()
	var hdr: String = "    "
	for x: int in range(w):
		hdr += str(x / 10 % 10) if x % 10 == 0 else " "
	lines.append(hdr)
	for y: int in range(h):
		var s: String = "%3d " % y
		for x: int in range(w):
			var p: int = y * w + x
			var f: int = fg[p]
			var v: int = info[p]
			var wl: int = _walls(d, f)
			var it: int = _intile(d, f)
			var over: bool = f > 0 and f < T16M and (it & 0x80) != 0 and cover[f] >= min_cover
			var c: String = "."
			if wl != 0 and f > 0 and f < T16M and d.tileinfo[NORTH + f] >= 8:
				c = "x"
			elif (wl & 1) == 0 and (wl & 4) != 0:
				c = "v"
			elif wl == 15 or (wl & 14) != 0:
				c = "#"
			elif wl == 1:
				c = "=" if d.tileinfo[NORTH + f] == 1 else "/"
			elif (it & 0x7F) == 1:
				c = "|"
			elif over:
				c = "F"
			elif f > 0:
				c = ","
			if f > 0 and f < T16M and d.tileinfo[NORTH + f] > 1 and d.tileinfo[NORTH + f] < 8 and wl != 0:
				c = "/"
			if fake.has(f):
				c = fake[f]
				fakes.append(p)
			elif over and wl == 0:
				overs.append(p)
			if v == 1 or v == 2:
				start = Vector2i(x, y)
				c = "K"
			elif v == 33:
				c = "d"
			elif INFO_ITEMS.has(v):
				items[INFO_ITEMS[v]] = items.get(INFO_ITEMS[v], 0) + 1
				where.append("%s@%d,%d" % [INFO_ITEMS[v], x, y])
				c = "+"
				if f > 0 and f < T16M and (it & 0x80) != 0 and cover[f] >= min_cover:
					c = "H"
					hidden.append("%s@%d,%d(%d%%)" % [INFO_ITEMS[v], x, y, cover[f]])
			s += c
		lines.append(s)
	print("map %d %s %dx%d start %s: items %s" % [n, m.name, w, h, start, items])
	if not hidden.is_empty():
		print("   hidden items (%d): %s" % [hidden.size(), " ".join(hidden)])
	if _opts.has("items"):
		print("   items: " + " ".join(where))
	for tw: String in twins:
		print("   twins: " + tw)
	if _opts.has("groups"):
		# the deceiving cells and hidden items as 4-connected groups, each as rectangles: the raw
		# material of the list's entries
		var deceit: Dictionary = {}
		for p: int in fakes:
			deceit[p] = true
		for s: String in hidden:
			var at: PackedStringArray = s.get_slice("@", 1).get_slice("(", 0).split(",")
			deceit[int(at[1]) * w + int(at[0])] = true
		var seen: Dictionary = {}
		var gi: int = 0
		for p0: int in deceit:
			if seen.has(p0):
				continue
			var cells: Array = []
			var st: Array = [p0]
			seen[p0] = true
			while not st.is_empty():
				var p: int = st.pop_back()
				cells.append(p)
				for q: int in [p - 1, p + 1, p - w, p + w]:
					if q >= 0 and q < w * h and absi(q % w - p % w) <= 1 and deceit.has(q) and not seen.has(q):
						seen[q] = true
						st.append(q)
			gi += 1
			var inside: PackedStringArray = PackedStringArray()
			for s: String in where:
				var at: PackedStringArray = s.get_slice("@", 1).split(",")
				if cells.has(int(at[1]) * w + int(at[0])):
					inside.append(s)
			var rects: PackedStringArray = PackedStringArray()
			for r: Array in _rects(cells, w):
				rects.append("[%d, %d, %d, %d]" % [r[0], r[1], r[2], r[3]])
			print("   group %d (%d cells): %s" % [gi, cells.size(), ", ".join(rects)])
			if not inside.is_empty():
				print("      items: " + " ".join(inside))
	if not fake.is_empty():
		var fl: PackedStringArray = PackedStringArray()
		for t: int in fake:
			fl.append("%d:%s(%s, intile %d%s, %d%%, %d cells)" % [t, fake[t], _behaviour(d, t), _intile(d, t) & 0x7F,
				" over Keen" if (_intile(d, t) & 0x80) != 0 else "", cover[t], used[t]])
		print("   fake tiles: %s" % " ".join(fl))
		print("   fake cells: " + _runs(fakes, w))
	if not overs.is_empty():
		print("   passable drawn over Keen (%d): %s" % [overs.size(), _runs(overs, w)])
	var g: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	g.store_string("\n".join(lines) + "\n")
	g.close()


func _rect(d: DreamsData, m: Dictionary, n: int) -> void:
	var r: PackedStringArray = str(_opts.rect).split(",")
	var w: int = int(m.width)
	print("map %d %s %dx%d" % [n, m.name, w, m.height])
	for y: int in range(int(r[1]), int(r[3]) + 1):
		var s: String = "%3d|" % y
		for x: int in range(int(r[0]), int(r[2]) + 1):
			var p: int = y * w + x
			var f: int = m.plane[1][p]
			var flags: String = ""
			if f > 0 and f < T16M:
				flags += ("t%d" % d.tileinfo[NORTH + f]) if d.tileinfo[NORTH + f] != 0 else ""
				flags += "r" if d.tileinfo[EAST + f] != 0 else ""
				flags += ("b%d" % d.tileinfo[SOUTH + f]) if d.tileinfo[SOUTH + f] != 0 else ""
				flags += "l" if d.tileinfo[WEST + f] != 0 else ""
				var it: int = d.tileinfo[INTILE + f]
				flags += "F" if (it & 0x80) != 0 else ""
				if (it & 0x7F) != 0:
					flags += "m%d" % (it & 0x7F)
			var inf: String = (",i%d" % m.plane[2][p]) if m.plane[2][p] != 0 else ""
			s += " %d/%d%s%s" % [m.plane[0][p], f, ("." + flags) if flags != "" else "", inf]
		print(s)


func _find(m: Dictionary, n: int) -> void:
	var want: Dictionary = {}
	for s: String in str(_opts.find).split(","):
		want[int(s)] = true
	var w: int = int(m.width)
	var hits: PackedStringArray = PackedStringArray()
	for p: int in range(m.plane[1].size()):
		if want.has(m.plane[1][p]):
			hits.append("%d,%d:f%d" % [p % w, p / w, m.plane[1][p]])
	if not hits.is_empty():
		print("map %d: %s" % [n, " ".join(hits)])


## The other release's maps against this one's, plane by plane.
func _compare(d: DreamsData, other_dir: String) -> void:
	var o: DreamsData = DreamsData.new()
	if not o.load_game(other_dir):
		print("compare: load failed: ", o.error)
		return
	var same: int = 0
	var differ: PackedStringArray = PackedStringArray()
	for i: int in range(DreamsData.NUM_MAPS):
		if not d.has_map(i) and not o.has_map(i):
			continue
		if d.has_map(i) != o.has_map(i):
			differ.append("map %d only in one release" % i)
			continue
		var a: Dictionary = d.load_map(i)
		var b: Dictionary = o.load_map(i)
		var why: PackedStringArray = PackedStringArray()
		if a.width != b.width or a.height != b.height:
			why.append("size %dx%d vs %dx%d" % [a.width, a.height, b.width, b.height])
		if a.name != b.name:
			why.append("name '%s' vs '%s'" % [a.name, b.name])
		for p: int in range(3):
			if why.is_empty() and a.plane[p] != b.plane[p]:
				var cells: int = 0
				for k: int in range(a.plane[p].size()):
					cells += 1 if a.plane[p][k] != b.plane[p][k] else 0
				why.append("plane %d differs in %d cells" % [p, cells])
		if why.is_empty():
			same += 1
		else:
			differ.append("map %d %s: %s" % [i, a.name, ", ".join(why)])
	print("compare %s vs %s: %d maps the same, %d differ" % [d.version, o.version, same, differ.size()])
	for s: String in differ:
		print("   " + s)


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
