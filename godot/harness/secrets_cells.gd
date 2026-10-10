# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Scratch research (secrets key): print the cells of a rectangle.
##   --game=keen1 --level=15 --rect=x0,y0,x1,y1
## Keen 1-3: tile:walls(hex nesw bits n1 e2 s4 w8):intile. Keen 4-6: fg tile, its flags
## (t top r right b bottom l left, P pole, F drawn over Keen, misc), info value.
## --find=t1,t2 lists every cell holding those (foreground) tiles instead.

var _opts: Dictionary = {}


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var game: String = str(_opts.get("game", "keen1"))
	var n: int = int(_opts.get("level", "1"))
	var r: PackedStringArray = str(_opts.get("rect", "0,0,10,10")).split(",")
	var x0: int = int(r[0])
	var y0: int = int(r[1])
	var x1: int = int(r[2])
	var y1: int = int(r[3])
	var root: String = "F:/Keen Launcher Godot 4 Rework/game_data/"
	if game in ["keen1", "keen2", "keen3"]:
		var d: VortData = VortData.new()
		d.load_game(root + game, "CK" + game.substr(4, 1))
		var tb: Array = SecretFinder.vort_tables(d)
		var lv: Dictionary = d.load_level(n)
		var w: int = lv.width
		var tp: PackedInt32Array = lv.plane[0]
		var sp: PackedInt32Array = lv.plane[1]
		if _opts.has("find"):
			var want: Dictionary = {}
			for s: String in str(_opts.find).split(","):
				want[int(s)] = true
			var hits: PackedStringArray = PackedStringArray()
			for i: int in range(tp.size()):
				if want.has(tp[i]):
					hits.append("%d,%d:t%d" % [i % w, i / w, tp[i]])
			print(" ".join(hits))
			quit(0)
			return
		for y: int in range(y0, y1 + 1):
			var s: String = "%3d|" % y
			for x: int in range(x0, x1 + 1):
				var t: int = tp[y * w + x]
				var wl: int = 0
				var it: int = 0
				if t < tb[1].size():
					wl = (1 if tb[2][t] != 0 else 0) | (2 if tb[3][t] != 0 else 0) | (4 if tb[4][t] != 0 else 0) | (8 if tb[5][t] != 0 else 0)
					it = tb[1][t]
				var spr: String = ("s%d" % sp[y * w + x]) if sp[y * w + x] != 0 else ""
				s += " %3d:%x:%d%s" % [t, wl, it, spr]
			print(s)
	else:
		var d: GalData = GalData.new()
		var od: String = "res://data/omnispeak/" + ("keen6e14" if game == "keen6" else game)
		d.load_game(root + game, od)
		var m: Dictionary = d.load_map(n)
		if m.is_empty():
			quit(0)
			return
		var w: int = m.width
		var fg: PackedInt32Array = m.plane[1]
		var bg: PackedInt32Array = m.plane[0]
		var info: PackedInt32Array = m.plane[2]
		var n16: int = d.gfx.numTiles16
		var n16m: int = d.gfx.numTiles16m
		var ti: PackedByteArray = d.tileinfo
		var fl: Callable = func(t: int, k: int) -> int:
			if t <= 0 or t >= n16m:
				return 0
			return ti[t + n16 * 2 + n16m * k]
		if _opts.has("find"):
			var want: Dictionary = {}
			for s: String in str(_opts.find).split(","):
				want[int(s)] = true
			var hits: PackedStringArray = PackedStringArray()
			for i: int in range(fg.size()):
				if want.has(fg[i]):
					hits.append("%d,%d:f%d" % [i % w, i / w, fg[i]])
			print(" ".join(hits))
			quit(0)
			return
		print("%s %dx%d" % [m.name, m.width, m.height])
		if _opts.has("ascii"):
			# # wall, = one-way top, / slope, | pole, F passable drawn over Keen, + item (info sprite or
			# item tile), d door, . open
			var hdr: String = "    "
			for x: int in range(x0, x1 + 1):
				hdr += str(x / 10 % 10) if x % 10 == 0 else " "
			print(hdr)
			for y: int in range(y0, y1 + 1):
				var s: String = "%3d " % y
				for x: int in range(x0, x1 + 1):
					var i: int = y * w + x
					var f: int = fg[i]
					var c: String = "."
					var misc: int = fl.call(f, 5)
					var top: int = fl.call(f, 0)
					if (misc & 0x7F) == 1:
						c = "|"
					elif top > 1:
						c = "/"
					elif fl.call(f, 1) != 0 or fl.call(f, 2) != 0 or fl.call(f, 3) != 0:
						c = "#"
					elif top == 1:
						c = "="
					elif (misc & 0x80) != 0:
						c = "F"
					if (misc & 0x7F) == 2:
						c = "d"
					if top == 0x39:
						c = "X"
					if (info[i] >= 57 and info[i] <= 69) or ((misc & 0x7F) >= 21 and (misc & 0x7F) <= 28):
						c = "+"
					s += c
				print(s)
			quit(0)
			return
		for y: int in range(y0, y1 + 1):
			var s: String = "%3d|" % y
			for x: int in range(x0, x1 + 1):
				var i: int = y * w + x
				var f: int = fg[i]
				var flags: String = ""
				if f > 0:
					flags += "t" if fl.call(f, 0) == 1 else ("/" if fl.call(f, 0) > 1 else "")
					flags += "r" if fl.call(f, 1) != 0 else ""
					flags += "b" if fl.call(f, 2) != 0 else ""
					flags += "l" if fl.call(f, 3) != 0 else ""
					var misc: int = fl.call(f, 5)
					flags += "F" if (misc & 0x80) != 0 else ""
					if (misc & 0x7F) != 0:
						flags += "m%d" % (misc & 0x7F)
				var inf: String = ("i%d" % info[i]) if info[i] != 0 else ""
				if info[i] > 255:
					inf = "i(%d,%d)" % [info[i] >> 8, info[i] & 0xFF]
				s += " %d/%d%s%s" % [bg[i], f, ("." + flags) if flags != "" else "", ("," + inf) if inf != "" else ""]
			print(s)
	quit(0)
