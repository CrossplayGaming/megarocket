# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name SecretFinder
extends RefCounted
## PROTOTYPE (no player-facing use yet): finds a level's secret areas and passages from its data alone,
## for a future "Reveal secrets" cheat. Validated against a community/official answer key for Keen 3 and
## Keen 4 (docs/notes/secrets_key.md); harness: harness/secret_report.gd.
##
## id never labelled secrets. They built them from tiles that look like one thing and act as another:
## walls Keen walks through (a passable tile drawn exactly like a solid one; in Keen 4 often foreground
## drawn over Keen), poles hidden in rock, places the camera never shows, and the reverse, platforms that
## look like empty sky (Keen 4's "flashes of insight"). So two worlds are built over the same level:
##   real   - what the tile properties do: which sides of a cell block Keen, poles, doors and where they
##            lead, moving platforms' paths, switch-toggled B blocks and bridges (both states count);
##   visual - what the player would believe:
##            * a cell that blocks looks solid on all four sides (Keen 1-3's one-way gates, drawn as
##              themselves, keep their real sides);
##            * a passable cell whose picture is pixel-identical to a wall's looks solid (one-colour
##              pictures left out; in Keen 4 only where the foreground draws most of the cell: walls are
##              foreground there, background rock behind Keen is scenery). A pole cell also when within
##              NEAR_PIXELS of a wall's picture. A pole hidden in a floor counts as seen when it shows on
##              both sides; showing only above, it is seen from above only (a way down, not up), and so
##              is a fall straight on below a pole's end;
##            * cells the camera never shows (Keen 4-6: the two-tile border, and lines a scroll block
##              keeps off screen) look solid, except a way straight across a block's line;
##            * a one-way platform whose picture is identical (or within NEAR_EMPTY_PIXELS) to empty
##              space's, or that draws at most FAINT_PIXELS pixels, is not there.
## Space Keen can reach from his start in the real world but not in the visual one is secret.
##
## Reachability moves Keen's body (1 tile wide, `body_h` tall) a tile at a time; a move into a cell is
## blocked by that cell's side facing him. Two passes, and secret is what either finds: plain
## connectivity (gravity ignored), which finds what walls hide whatever moves Keen has; and with
## gravity, which finds what only hidden platforms or hidden ways in hold up: standing (on something that
## holds him up, a pole, or where a moving platform passes) he may rise up to `jump` tiles and drift up
## to `drift` tiles sideways while airborne; going down he cannot rise again until he lands. Doors (Keen
## 1-3 keycard doors, Keen 4 gem doors) count as open in both worlds. Creatures to ride, ledge grabs and
## the games' pixel-level collision are not modelled.
##
## Region kinds (see _regions): "area" (look-open space reached only through the secret), "shortcut"
## (only passages, joining visible space in two places), "dent" (only passages, one contact: worth
## revealing only when items lie in it), "way up" (a pole or fall seen from above only, climbable from
## below).

const OPEN: int = 0
const SOLID: int = 1

## Sides of a cell that block Keen entering it: from above (he lands on it), from below, from the left
## (moving right), from the right.
const TOP: int = 1
const BOTTOM: int = 2
const LEFT: int = 4
const RIGHT: int = 8
const ALL: int = 15

## A pole cell drawn within this many pixels of a solid cell's picture looks solid.
const NEAR_PIXELS: int = 16

## A platform drawn within this many pixels of empty space looks like empty space.
const NEAR_EMPTY_PIXELS: int = 24

## A one-way platform tile with at most this many opaque pixels counts as invisible.
const FAINT_PIXELS: int = 12
## A Keen 4-6 cell only looks like a wall when its foreground tile draws at least this share of it:
## walls are foreground there, and background rock behind Keen is scenery, not a hiding place.
const FORE_SHARE: float = 0.5

const GAL_ITEMS: Array = ["red gem", "yellow gem", "blue gem", "green gem", "100", "200", "500", "1000", "2000", "5000", "1UP", "ammo"]

## A level's result (both engines): {name, width, height, start: Vector2i, real (1 = blocks on some
## side), lookalike (1 = passable but looks solid), invisible (1 = holds Keen up but looks like empty
## space), reach_real, reach_visual (1 = a cell Keen's body can be in, plain connectivity),
## reach_gravity (the same with gravity, real world), secret (1 = secret cell), regions (see _regions),
## items ([cell, what, "secret" | "open" | "unreached"])}.


# ------------------------------------------------------------------ Keen 4-6

## A Galaxy level. `opts`: body_h (2), jump (6), drift (8), gravity (true), min_area (1),
## fore_opaque (0.0 = off; else the share of a drawn-over-Keen passable foreground tile's pixels that
## must be opaque for it to count as looking solid even when no solid cell has its picture).
static func galaxy(d: GalData, imgs: GalImages, map_index: int, opts: Dictionary = {}) -> Dictionary:
	var m: Dictionary = d.load_map(map_index)
	if m.is_empty():
		return {}
	var w: int = int(m.width)
	var h: int = int(m.height)
	var bg: PackedInt32Array = m.plane[0]
	var fg: PackedInt32Array = m.plane[1]
	var info: PackedInt32Array = m.plane[2]
	var n16: int = int(d.gfx.numTiles16)
	var n16m: int = int(d.gfx.numTiles16m)
	var ti: PackedByteArray = d.tileinfo
	var tinfo: Callable = func(t: int, k: int) -> int:   # k: 0 top, 1 right, 2 bottom, 3 left, 5 misc
		if t <= 0 or t >= n16m:
			return 0
		var i: int = t + n16 * 2 + n16m * k
		return ti[i] if i < ti.size() else 0
	var lv: Dictionary = _blank(w, h)
	var sides: PackedByteArray = lv.sides
	var climb: PackedByteArray = lv.climb
	var shown: PackedByteArray = lv.shown
	var extra: PackedByteArray = lv.extra
	var drawn: PackedByteArray = lv.drawn
	var fore_opaque: float = float(opts.get("fore_opaque", 0.0))
	var opaque_share: Dictionary = {}
	for i: int in range(w * h):
		var f: int = fg[i]
		if f == 0:
			continue
		if not opaque_share.has(f):
			opaque_share[f] = _opaque_share(imgs.mtile(f))
		var share: float = opaque_share[f]
		if share >= FORE_SHARE:
			drawn[i] = 1
		var top: int = tinfo.call(f, 0)
		var misc: int = tinfo.call(f, 5)
		if (misc & 0x7F) == 1:
			climb[i] = 1     # a pole: Keen climbs along it, through any floor it pierces
			continue
		if top > 1:
			sides[i] = ALL   # a slope, taken as solid
		else:
			sides[i] = (TOP if top != 0 else 0) | (RIGHT if tinfo.call(f, 1) != 0 else 0) \
				| (BOTTOM if tinfo.call(f, 2) != 0 else 0) | (LEFT if tinfo.call(f, 3) != 0 else 0)
		# a platform that draws next to nothing (Keen 4's "flash of insight": a glint of a few pixels
		# now and then) is as good as invisible
		if sides[i] == TOP and share * 256.0 <= FAINT_PIXELS:
			lv.faint[i] = 1
		if sides[i] == 0 and (misc & 0x80) != 0 and fore_opaque > 0.0 and share >= fore_opaque:
			extra[i] = 1
	# gem doors: a holder's info value points at the door's top; the door is the run of that tile below
	# it and two more (as CK_KeenPlaceGem and CK_DoorOpen have it)
	for i: int in range(w * h):
		var misc: int = tinfo.call(fg[i], 5) & 0x7F
		if misc >= 7 and misc <= 10 and info[i] != 0:
			var tx: int = info[i] >> 8
			var ty: int = info[i] & 0xFF
			if tx < 0 or tx >= w or ty < 0 or ty >= h:
				continue
			var door_tile: int = fg[ty * w + tx]
			var y: int = ty
			while y < h and fg[y * w + tx] == door_tile:
				y += 1
			for yy: int in range(ty, mini(y + 2, h)):
				shown[yy * w + tx] = 1
				sides[yy * w + tx] = 0
	# pictures: a cell is its background tile with its foreground tile drawn over it
	var pic_key: Dictionary = {}
	var pic: PackedStringArray = lv.pic
	for i: int in range(w * h):
		var k: int = bg[i] * 65536 + fg[i]
		if not pic_key.has(k):
			pic_key[k] = _gal_picture(imgs, bg[i], fg[i])
		pic[i] = pic_key[k]
	opts = opts.duplicate()
	for i: int in range(w * h):
		if info[i] == 1 or info[i] == 2 or info[i] == 3 or info[i] == 42:
			lv.start = Vector2i(i % w, i / w)
			if info[i] == 3 or info[i] == 42:
				opts.body_h = 1          # the world map, seen from above, and swimming: no gravity
				opts.gravity = false
			break
	# doors (misc 2): standing in one, Keen comes out where its info value points (x << 8 | y, the
	# cell his feet are in), as CK_KeenEnterDoor has it
	var body_h: int = int(opts.get("body_h", 2))
	for i: int in range(w * h):
		if (tinfo.call(fg[i], 5) & 0x7F) == 2 and info[i] != 0:
			var tx: int = info[i] >> 8
			var ty: int = (info[i] & 0xFF) - body_h + 1
			if tx >= 0 and tx < w and ty >= 0 and ty < h:
				lv.links[i] = Vector2i(tx, ty)
	lv.drop_through = true     # Keen 4-6 jump down through a one-way platform
	# where the camera never looks (the original's 20 x 13 tile view): it keeps two tiles off every
	# edge, and never straddles a scroll block's row (info 25) or column (info 26) (RF_SetScrollBlock,
	# RF_Reposition's clamps). 2 marks a block's own line, 1 anything else out of view.
	var block_rows: Array = []
	var block_cols: Array = []
	for i: int in range(w * h):
		if info[i] == 25:
			block_rows.append(i / w)
		elif info[i] == 26:
			block_cols.append(i % w)
	var rows_seen: PackedByteArray = _seen_lines(h, 13, block_rows)
	var cols_seen: PackedByteArray = _seen_lines(w, 20, block_cols)
	var unseen: PackedByteArray = lv.unseen
	for i: int in range(w * h):
		var x: int = i % w
		var y: int = i / w
		if rows_seen[y] == 0 or cols_seen[x] == 0:
			unseen[i] = 2 if (y in block_rows or x in block_cols) else 1
	lv.fore_walls = true
	# moving platforms (Keen 4 info 27-30: up, right, down, left; they turn at a B block, info 31) and
	# falling ones (32): wherever one can be, it holds Keen up, seen or not
	var movers: PackedByteArray = lv.movers
	# switches: a platform switch (misc 5, 6) flips the info value it points at between a B block and
	# nothing (CK_KeenPressSwitchThink: value ^ 0x1F), so a B block it points at may be gone; a bridge
	# switch (misc 15) swaps the bridge tiles from where it points for their other frame, so a bridge's
	# tiles hold Keen up in whichever state does. Both states count, in both worlds.
	var flippable: Dictionary = {}
	for i: int in range(w * h):
		var misc: int = tinfo.call(fg[i], 5) & 0x7F
		if (misc == 5 or misc == 6 or misc == 15) and info[i] != 0:
			var tx: int = info[i] >> 8
			var ty: int = info[i] & 0xFF
			if tx >= w or ty >= h:
				continue
			if misc != 15:
				flippable[ty * w + tx] = true
				continue
			for y: int in [ty, ty + 1]:
				if y >= h:
					continue
				for x: int in range(tx - (0 if y == ty else 1), w):
					var t: int = fg[y * w + x]
					var anim: int = tinfo.call(t, 4)
					if anim == 0:
						break
					anim = anim - 256 if anim >= 128 else anim
					# open where either state is open, held up where either holds Keen up
					var alt: int = t + anim
					var alt_sides: int = ALL if tinfo.call(alt, 0) > 1 else ((TOP if tinfo.call(alt, 0) != 0 else 0) 						| (RIGHT if tinfo.call(alt, 1) != 0 else 0) | (BOTTOM if tinfo.call(alt, 2) != 0 else 0) 						| (LEFT if tinfo.call(alt, 3) != 0 else 0))
					var both: int = sides[y * w + x] & alt_sides
					sides[y * w + x] = both if _blocky(both) else 0
					if tinfo.call(alt, 0) != 0 or tinfo.call(t, 0) != 0:
						movers[y * w + x] = 1
	# the platforms themselves: three tiles wide (SPR_PLATFORM's box), turning where their leading edge
	# would enter a B block (CK_AxisPlatform; walls do not stop them)
	var is_b: Callable = func(x: int, y: int) -> bool:
		return x >= 0 and x < w and y >= 0 and y < h and info[y * w + x] == 31 and not flippable.has(y * w + x)
	for i: int in range(w * h):
		var v: int = info[i]
		if v < 27 or v > 32 or v == 31:
			continue
		var x: int = i % w
		var y: int = i / w
		var x0: int = x
		var x1: int = mini(x + 2, w - 1)
		var y0: int = y
		var y1: int = y
		if v == 28 or v == 30:
			while x0 > 0 and not is_b.call(x0 - 1, y):
				x0 -= 1
			while x1 < w - 1 and not is_b.call(x1 + 1, y):
				x1 += 1
		elif v == 27 or v == 29:
			while y0 > 0 and not is_b.call(x, y0 - 1):
				y0 -= 1
			while y1 < h - 1 and not is_b.call(x, y1 + 1):
				y1 += 1
		for yy: int in range(y0, y1 + 1):
			for xx: int in range(x0, x1 + 1):
				movers[yy * w + xx] = 1
	if not opts.has("jump"):
		# the pogo stick: -48 held for 24 tics, then gravity's +4 every other tic: about 6.75 tiles
		opts.jump = 6
	var r: Dictionary = _analyse(w, h, lv, opts)
	r.name = str(m.name)
	# contents: Keen 4 item sprites (info 57-68), lifewater drops and the item tiles on the foreground
	var items: Array = []
	for i: int in range(w * h):
		var v: int = info[i]
		var what: String = ""
		if v >= 57 and v <= 68:
			what = GAL_ITEMS[v - 57]
		else:
			var misc: int = tinfo.call(fg[i], 5) & 0x7F
			if misc == 4:
				what = "drop"
			elif misc >= 21 and misc <= 28:
				what = GAL_ITEMS[misc - 21 + 4]
		if what != "":
			items.append([i, what])
	_fill_contents(r, items)
	return r


static func _gal_picture(imgs: GalImages, b: int, f: int) -> String:
	var px: PackedByteArray = PackedByteArray()
	var bi: Dictionary = imgs.tile(b)
	if bi.is_empty():
		px.resize(256)
	else:
		px = (bi.pixels as PackedByteArray).duplicate()
	if f > 0:
		var fi: Dictionary = imgs.mtile(f)
		if not fi.is_empty():
			var fp: PackedByteArray = fi.pixels
			var fm: PackedByteArray = fi.mask
			for k: int in range(256):
				if fm[k] == 0:
					px[k] = fp[k]
	return _key(px)


static func _opaque_share(img: Dictionary) -> float:
	if img.is_empty():
		return 0.0
	var n: int = 0
	var mask: PackedByteArray = img.mask
	for k: int in range(256):
		if mask[k] == 0:
			n += 1
	return n / 256.0


## A picture's key: its pixels in hex, or "u" and the colour when it is all one colour.
static func _key(px: PackedByteArray) -> String:
	var c: int = px[0]
	for k: int in range(1, px.size()):
		if px[k] != c:
			return px.hex_encode()
	return "u%d" % c


## Which lines (rows or columns) of a map `n` long a view `view` lines long can show, as RF_Reposition
## places it: the start clamped two lines in from either end, then moved off a block line in the view's
## near half (to just past it) or far half (to end just before it). A view part-way between two lines
## shows a sliver of one more.
static func _seen_lines(n: int, view: int, blocks: Array) -> PackedByteArray:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(n)
	var half: int = view / 2
	for t0: int in range(2, maxi(2, n - view - 2) + 1):
		var t: int = t0
		for bl: int in blocks:
			if bl >= t0 and t0 + half >= bl:
				t = bl + 1
				break
			if t0 + half + 1 <= bl and t0 + view >= bl:
				t = bl - view
				break
		var last: int = t + view - 1
		if t == t0 and t0 < n - view - 2 and not (t0 + view in blocks):
			last += 1
		for k: int in range(maxi(t, 0), mini(n, last + 1)):
			seen[k] = 1
	return seen


## Of the pictures `cands`, those that differ from one of `targets` in at most `limit` pixels. A
## 16-colour count first rules most pairs out.
static func _near_pics(cands: Dictionary, targets: Dictionary, limit: int) -> Dictionary:
	var out: Dictionary = {}
	if limit <= 0:
		return out
	var hist: Callable = func(px: PackedByteArray) -> PackedInt32Array:
		var hh: PackedInt32Array = PackedInt32Array()
		hh.resize(16)
		for v: int in px:
			hh[v & 15] += 1
		return hh
	var solids: Array = []
	for k: String in targets:
		if _plain(k):
			continue
		var px: PackedByteArray = k.hex_decode()
		solids.append([px, hist.call(px)])
	for k: String in cands:
		var px: PackedByteArray = k.hex_decode()
		var hc: PackedInt32Array = hist.call(px)
		for s: Array in solids:
			var hs: PackedInt32Array = s[1]
			var dh: int = 0
			for c: int in range(16):
				dh += absi(hs[c] - hc[c])
			if dh > limit * 2:
				continue
			var sp: PackedByteArray = s[0]
			var dd: int = 0
			for q: int in range(256):
				if sp[q] != px[q]:
					dd += 1
					if dd > limit:
						break
			if dd <= limit:
				out[k] = true
				break
	return out


static func _plain(key: String) -> bool:
	return key.begins_with("u")


## Blocks on some side other than its top: a wall, not a one-way platform.
static func _blocky(s: int) -> bool:
	return (s & (BOTTOM | LEFT | RIGHT)) != 0


# ------------------------------------------------------------------ Keen 1-3

## The six tile property tables of a Keen 1-3 game, as vort_main's _load_tileinfo reads them:
## nexttile, intile, northwall, eastwall, southwall, westwall.
static func vort_tables(d: VortData) -> Array:
	var n: int = d.tileinfo.size() / 12
	var tables: Array = []
	for k: int in range(6):
		var t: PackedInt32Array = PackedInt32Array()
		t.resize(n)
		for i: int in range(n):
			var v: int = d.tileinfo[(k * n + i) * 2] | (d.tileinfo[(k * n + i) * 2 + 1] << 8)
			t[i] = v - 65536 if v >= 32768 else v
		tables.append(t)
	return tables


## A Vorticons level by its file number. `opts` as for galaxy (jump 7: the pogo stick).
static func vorticons(d: VortData, number: int, opts: Dictionary = {}) -> Dictionary:
	var lvd: Dictionary = d.load_level(number)
	if lvd.is_empty():
		return {}
	var tables: Array = vort_tables(d)
	var intile: PackedInt32Array = tables[1]
	var north: PackedInt32Array = tables[2]
	var east: PackedInt32Array = tables[3]
	var south: PackedInt32Array = tables[4]
	var west: PackedInt32Array = tables[5]
	var w: int = int(lvd.width)
	var h: int = int(lvd.height)
	var tp: PackedInt32Array = lvd.plane[0]
	var sp: PackedInt32Array = lvd.plane[1] if lvd.plane.size() > 1 else PackedInt32Array()
	var nt: int = intile.size()
	var lv: Dictionary = _blank(w, h)
	var sides: PackedByteArray = lv.sides
	var shown: PackedByteArray = lv.shown
	var extra: PackedByteArray = lv.extra
	var pic: PackedStringArray = lv.pic
	var pics: Dictionary = {}
	var fore_opaque: bool = float(opts.get("fore_opaque", 0.0)) > 0.0
	for i: int in range(w * h):
		var t: int = tp[i]
		if t < 0 or t >= nt or t >= d.num_tiles:
			sides[i] = ALL
			pic[i] = "u0"
			continue
		# moving right Keen meets a tile's west wall, moving left its east wall, landing its north wall
		sides[i] = (TOP if north[t] != 0 else 0) | (BOTTOM if south[t] != 0 else 0) \
			| (LEFT if west[t] != 0 else 0) | (RIGHT if east[t] != 0 else 0)
		if intile[t] >= 2 and intile[t] <= 5:
			shown[i] = 1
			sides[i] = 0
		if not pics.has(t):
			pics[t] = _key(d.tiles.slice(t * 256, t * 256 + 256))
		pic[i] = pics[t]
		if fore_opaque and sides[i] == 0 and intile[t] == -1:
			extra[i] = 1
	for i: int in range(sp.size()):
		if sp[i] == 255:
			lv.start = Vector2i(i % w, i / w)
			break
	lv.edges = true    # Keen 1-3 have one-way walls (a tile blocking only from one side), used as gates
	opts = opts.duplicate()
	if number == 80:
		opts.body_h = 1      # the world map, seen from above
		opts.gravity = false
	if not opts.has("jump"):
		opts.jump = 7
	var r: Dictionary = _analyse(w, h, lv, opts)
	r.name = "LEVEL%02d" % number
	var names: Dictionary = {6: "500", 7: "100", 8: "200", 9: "1000", 10: "5000", 15: "ammo", 16: "pogo",
		18: "yellow card", 19: "red card", 20: "green card", 21: "blue card", 17: "exit", 24: "warp exit",
		27: "ankh", 28: "ammo"}
	var items: Array = []
	for i: int in range(w * h):
		var t: int = tp[i]
		if t >= 0 and t < nt and names.has(intile[t]):
			items.append([i, names[intile[t]]])
	_fill_contents(r, items)
	r.tiles = tp
	return r


# ------------------------------------------------------------------ both

static func _blank(w: int, h: int) -> Dictionary:
	var lv: Dictionary = {"start": Vector2i(-1, -1), "links": {}, "drop_through": false, "fore_walls": false}
	for k: String in ["sides", "climb", "shown", "extra", "movers", "faint", "drawn", "unseen"]:
		var a: PackedByteArray = PackedByteArray()
		a.resize(w * h)
		lv[k] = a
	var p: PackedStringArray = PackedStringArray()
	p.resize(w * h)
	lv.pic = p
	return lv


## `lv`: sides (TOP | BOTTOM | LEFT | RIGHT that block), climb (1 pole), shown (doors: open, seen for
## what they are), extra (1 looks solid whatever its picture), drawn (1 its foreground draws most of
## it; used when fore_walls), faint (1 a platform that draws next to nothing), movers (1 a moving
## platform passes), pic (picture keys), links (cell -> spot a door puts Keen's body), start,
## drop_through, fore_walls.
static func _analyse(w: int, h: int, lv: Dictionary, opts: Dictionary) -> Dictionary:
	var sides: PackedByteArray = lv.sides
	if not bool(opts.get("edges", lv.get("edges", false))):
		# a tile that blocks on any side but its top blocks on all four: the games' tiles only flag the
		# sides Keen can meet, and following single open sides into rock finds ghost routes (tried:
		# Isle of Tar, Pyramid of Shadows, Well of Wishes filled with them, and nothing in the key needed it)
		for i: int in range(w * h):
			if _blocky(sides[i]):
				sides[i] = ALL
	var climb: PackedByteArray = lv.climb
	var shown: PackedByteArray = lv.shown
	var extra: PackedByteArray = lv.extra
	var pic: PackedStringArray = lv.pic
	var real: PackedByteArray = PackedByteArray()
	real.resize(w * h)
	for i: int in range(w * h):
		if _blocky(sides[i]):
			real[i] = SOLID
	# the pictures of everything solid (poles left out: a pole drawn through rock shows), and of open
	# space that holds nothing up
	var solid_pics: Dictionary = {}
	var empty_pics: Dictionary = {}
	for i: int in range(w * h):
		if sides[i] == ALL and climb[i] == 0 and shown[i] == 0 and not _plain(pic[i]):
			solid_pics[pic[i]] = true
		elif sides[i] == 0 and climb[i] == 0 and shown[i] == 0 and lv.movers[i] == 0:
			empty_pics[pic[i]] = true
	# what looks like a wall: a solid cell's picture exactly, or for a pole cell within NEAR_PIXELS of
	# one (the pole hidden in rock with a few pixels of what lies behind showing, as where Keen 4's
	# hidden pole ends in a ceiling). Near matches for other cells were tried and only added noise:
	# items at the fringe of cave walls, decoration.
	var cands: Dictionary = {}
	for i: int in range(w * h):
		if climb[i] != 0 and not _plain(pic[i]) and not solid_pics.has(pic[i]):
			cands[pic[i]] = true
	var near: Dictionary = _near_pics(cands, solid_pics, int(opts.get("near", NEAR_PIXELS)))
	var wall_like: PackedByteArray = PackedByteArray()
	wall_like.resize(w * h)
	for i: int in range(w * h):
		if solid_pics.has(pic[i]) or (climb[i] != 0 and near.has(pic[i])):
			wall_like[i] = 1
	# a pole hidden behind a floor drawn over it is seen for what it is when it shows on both sides of
	# the floor (it runs down through it). Showing only above, it is seen from above: a pole going down
	# a hole invites Keen down it, but from below nothing shows (Keen 4's Pyramid of the Moons hides
	# one so). Hidden all along, it is a secret way.
	var pole_seen: PackedByteArray = PackedByteArray()
	pole_seen.resize(w * h)
	var pole_down: PackedByteArray = PackedByteArray()
	pole_down.resize(w * h)
	for x: int in range(w):
		for y: int in range(h):
			var i: int = y * w + x
			if climb[i] == 0:
				continue
			if wall_like[i] == 0:
				pole_seen[i] = 1
				continue
			if y > 0 and climb[i - w] != 0 and pole_seen[i - w] != 0 and wall_like[i - w] == 0:
				# a hidden stretch starting below a visible bit: seen if the pole shows again below it
				var y1: int = y
				while y1 < h and climb[y1 * w + x] != 0 and wall_like[y1 * w + x] != 0:
					y1 += 1
				for yy: int in range(y, y1):
					if y1 < h and climb[y1 * w + x] != 0:
						pole_seen[yy * w + x] = 1
					else:
						pole_down[yy * w + x] = 1
	# a pole going down a hole: where a seen pole ends and wall-like cells Keen falls through go on
	# below it, he would slide down into them, so they are seen from above as well
	for x: int in range(w):
		for y: int in range(h - 1):
			var i: int = y * w + x
			if climb[i] == 0 or (pole_seen[i] == 0 and pole_down[i] == 0) or climb[i + w] != 0:
				continue
			var yy: int = y + 1
			while yy < h and sides[yy * w + x] == 0 and climb[yy * w + x] == 0 and shown[yy * w + x] == 0 and wall_like[yy * w + x] != 0:
				pole_down[yy * w + x] = 1
				yy += 1
	# platforms drawn within NEAR_EMPTY_PIXELS of empty space look like empty space (Keen 3's dark
	# ledges in the Hidden City differ from the dark rock behind by 17 pixels)
	var plat_pics: Dictionary = {}
	for i: int in range(w * h):
		if sides[i] == TOP and not _plain(pic[i]) and not empty_pics.has(pic[i]):
			plat_pics[pic[i]] = true
	for k: String in _near_pics(plat_pics, empty_pics, int(opts.get("near_empty", NEAR_EMPTY_PIXELS))):
		empty_pics[k] = true
	var vsides: PackedByteArray = sides.duplicate()
	var vclimb: PackedByteArray = climb.duplicate()
	var lookalike: PackedByteArray = PackedByteArray()
	lookalike.resize(w * h)
	var invisible: PackedByteArray = PackedByteArray()
	invisible.resize(w * h)
	# cells the camera never shows: open ones look like nothing at all, except where the way runs
	# straight across a scroll block's line with open space seen on both sides
	var unseen: PackedByteArray = lv.unseen
	var offscreen: PackedByteArray = PackedByteArray()
	offscreen.resize(w * h)
	for i: int in range(w * h):
		if unseen[i] == 0 or _blocky(sides[i]) or shown[i] != 0:
			continue
		var x: int = i % w
		var y: int = i / w
		# a way straight across a block's line, open and in view on both sides, is seen for what it is
		if unseen[i] == 2 and y > 0 and y < h - 1 and not _blocky(sides[i - w]) and not _blocky(sides[i + w]) and unseen[i - w] == 0 and unseen[i + w] == 0:
			continue
		if unseen[i] == 2 and x > 0 and x < w - 1 and not _blocky(sides[i - 1]) and not _blocky(sides[i + 1]) and unseen[i - 1] == 0 and unseen[i + 1] == 0:
			continue
		offscreen[i] = 1
	for i: int in range(w * h):
		if real[i] == SOLID:
			# drawn as a wall: no side of it looks open. A tile drawn as itself (Keen 1-3's one-way
			# gates) shows what it is, and its open side is no secret.
			if sides[i] == ALL or solid_pics.has(pic[i]) or _plain(pic[i]):
				vsides[i] = ALL
		elif offscreen[i] != 0:
			vsides[i] = ALL
			vclimb[i] = 0
			lookalike[i] = 1
		elif sides[i] == 0 and shown[i] == 0 and pole_seen[i] == 0 and (extra[i] != 0 \
				or (wall_like[i] != 0 and (not lv.fore_walls or lv.drawn[i] != 0))):
			vsides[i] = ALL
			vclimb[i] = 0
			lookalike[i] = 1
			if pole_down[i] != 0:
				vsides[i] = BOTTOM | LEFT | RIGHT     # a way in from above only
				vclimb[i] = climb[i]
		elif sides[i] == TOP and (empty_pics.has(pic[i]) or lv.faint[i] != 0):
			vsides[i] = 0
			invisible[i] = 1
	var body_h: int = int(opts.get("body_h", 2))
	var s: Vector2i = _start_spot(w, h, sides, lv.start, body_h)
	var mv: Dictionary = {"w": w, "h": h, "body_h": body_h, "links": lv.links, "drop": lv.drop_through,
		"movers": lv.movers, "gravity": bool(opts.get("gravity", true)), "jump": int(opts.get("jump", 5)),
		"drift": int(opts.get("drift", 8))}
	# two passes: plain connectivity finds what walls hide whatever Keen's moves can do; with gravity,
	# what only hidden platforms hold up. Secret is what either finds.
	var flat: Dictionary = mv.duplicate()
	flat.gravity = false
	var reach_real: PackedByteArray = _reach(flat, sides, climb, s)
	var reach_visual: PackedByteArray = _reach(flat, vsides, vclimb, s)
	var secret: PackedByteArray = PackedByteArray()
	secret.resize(w * h)
	var seen_visual: PackedByteArray = reach_visual.duplicate()
	var g_real: PackedByteArray = PackedByteArray()
	var g_visual: PackedByteArray = PackedByteArray()
	if mv.gravity:
		g_real = _reach(mv, sides, climb, s)
		g_visual = _reach(mv, vsides, vclimb, s)
		for i: int in range(w * h):
			if g_real[i] != 0 and g_visual[i] == 0:
				secret[i] = 1
	for i: int in range(w * h):
		if reach_real[i] != 0 and reach_visual[i] == 0:
			secret[i] = 1
		if secret[i] != 0:
			seen_visual[i] = 0
	var r: Dictionary = {"width": w, "height": h, "start": s, "real": real, "lookalike": lookalike, "offscreen": offscreen,
		"invisible": invisible, "reach_real": reach_real, "reach_visual": reach_visual,
		"reach_gravity": g_real, "reach_gravity_visual": g_visual, "secret": secret}
	# passages: what looks solid, lookalikes and walls Keen gets into through a side left open
	var looks_solid: PackedByteArray = lookalike.duplicate()
	for i: int in range(w * h):
		if real[i] == SOLID:
			looks_solid[i] = 1
	r.regions = _regions(w, h, secret, seen_visual, looks_solid, invisible, int(opts.get("min_area", 1)))
	# a pole seen only from above is a secret way up from below: the set of cells reached is the same,
	# the direction is not, so it is listed on its own
	for x: int in range(w):
		var y: int = 0
		while y < h:
			if pole_down[y * w + x] == 0 or reach_real[y * w + x] == 0:
				y += 1
				continue
			var cells: PackedInt32Array = PackedInt32Array()
			var y1: int = y
			while y1 < h and pole_down[y1 * w + x] != 0:
				cells.append(y1 * w + x)
				y1 += 1
			# only where what lies below is seen and reached without it: not the room it alone leads into
			var below_seen: bool = false
			if y1 < h and reach_real[y1 * w + x] != 0:
				var shut: PackedByteArray = vsides.duplicate()
				for c: int in cells:
					shut[c] = ALL
				below_seen = _reach(flat, shut, vclimb, s)[y1 * w + x] != 0
			if below_seen:
				r.regions.append({"cells": cells, "passages": cells, "areas": PackedInt32Array(),
					"platforms": PackedInt32Array(), "x0": x, "y0": y, "x1": x, "y1": y1 - 1, "contents": [],
					"contacts": 2, "kind": "way up"})
			y = y1
	return r


## Keen's start: the marked cell, else the nearest spot his body fits, searching upward first.
static func _start_spot(w: int, h: int, sides: PackedByteArray, start: Vector2i, body_h: int) -> Vector2i:
	if start.x < 0:
		return start
	for dy: int in [0, -1, 1, -2, 2, -3]:
		var p: Vector2i = start + Vector2i(0, dy)
		var ok: bool = p.y >= 0 and p.y + body_h <= h
		for k: int in range(body_h):
			if ok and _blocky(sides[(p.y + k) * w + p.x]):
				ok = false
		if ok:
			return p
	return start


## The cells Keen's body can be in, from `s`. Without gravity: plain connectivity. With it, a state is
## (spot, rise left, drift left); standing (held up from below, on a pole, or where a moving platform
## passes) refills both.
static func _reach(mv: Dictionary, sides: PackedByteArray, climb: PackedByteArray, s: Vector2i) -> PackedByteArray:
	var w: int = mv.w
	var h: int = mv.h
	var bh: int = mv.body_h
	var links: Dictionary = mv.links
	var movers: PackedByteArray = mv.movers
	var gravity: bool = mv.gravity
	var cover: PackedByteArray = PackedByteArray()
	cover.resize(w * h)
	if s.x < 0:
		return cover
	var jump: int = mv.jump if gravity else 0
	var drift: int = mv.drift if gravity else 0
	var nj: int = jump + 1
	var nd: int = drift + 1
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h * nj * nd)
	var stack: PackedInt32Array = PackedInt32Array()
	var standing: Callable = func(x: int, y: int) -> bool:
		for k: int in range(bh):
			if climb[(y + k) * w + x] != 0:
				return true
		if y + bh >= h:
			return false
		return movers[(y + bh) * w + x] != 0 or (sides[(y + bh) * w + x] & TOP) != 0
	var push: Callable = func(x: int, y: int, r: int, a: int) -> void:
		if x < 0 or x >= w or y < 0 or y + bh > h:
			return
		if gravity and standing.call(x, y):
			r = jump
			a = drift
		var st: int = ((y * w + x) * nj + r) * nd + a
		if seen[st] == 0:
			seen[st] = 1
			stack.append(st)
	push.call(s.x, s.y, jump, drift)
	while not stack.is_empty():
		var st: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var a: int = st % nd
		var r: int = (st / nd) % nj
		var p: int = st / nd / nj
		var x: int = p % w
		var y: int = p / w
		for k: int in range(bh):
			cover[(y + k) * w + x] = 1
			if links.has((y + k) * w + x):
				var t: Vector2i = links[(y + k) * w + x]
				push.call(t.x, t.y, jump, drift)
		var stand: bool = gravity and standing.call(x, y)
		var on_pole: bool = false
		for k: int in range(bh):
			if climb[(y + k) * w + x] != 0:
				on_pole = true
		# sideways: Keen's whole body meets the cells beside it
		if not gravity or stand or a > 0:
			var na: int = drift if stand else maxi(a - 1, 0)
			for dx: int in [1, -1]:
				var nx: int = x + dx
				if nx < 0 or nx >= w:
					continue
				var ok: bool = true
				for k: int in range(bh):
					if (sides[(y + k) * w + nx] & (LEFT if dx > 0 else RIGHT)) != 0:
						ok = false
				if ok:
					push.call(nx, y, r, na)
		# up: a jump, or climbing a pole; the cell above his head meets him from below
		if (not gravity or r > 0 or on_pole) and y > 0 and (sides[(y - 1) * w + x] & BOTTOM) == 0:
			push.call(x, y - 1, r - 1 if r > 0 else 0, a)
		# down: a fall (no rising again until he lands), or climbing down a pole; the cell under his
		# feet meets him from above. One-way platforms: always without gravity (whatever the way in),
		# with it only where the game lets Keen jump down through them.
		if y + bh < h:
			var below: int = sides[(y + bh) * w + x]
			var platform: bool = below == TOP
			if (below & TOP) == 0 or (platform and (not gravity or mv.drop)) or (on_pole and climb[(y + bh) * w + x] != 0):
				push.call(x, y + 1, 0, mini(drift, a + 1))
	return cover


## The secret cells in 4-connected groups: {cells, passages (cells that look solid), platforms (hidden
## platforms right under it or under the visible space it borders), areas (the rest), x0, y0, x1, y1,
## contacts (separate stretches of the visibly reachable space it borders), kind, contents (filled
## later)}. kind: "area" (at least `min_area` look-open cells, or hidden platforms), "shortcut" (only
## passages, joining visible space in two places or more), "dent" (only passages, one contact: a stash
## if items lie in it, else most likely nothing).
static func _regions(w: int, h: int, secret: PackedByteArray, reach_visual: PackedByteArray,
		lookalike: PackedByteArray, invisible: PackedByteArray, min_area: int) -> Array:
	var out: Array = []
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h)
	for i0: int in range(w * h):
		if seen[i0] != 0 or secret[i0] == 0:
			continue
		var cells: PackedInt32Array = PackedInt32Array()
		var stack: PackedInt32Array = PackedInt32Array([i0])
		seen[i0] = 1
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			cells.append(p)
			var x: int = p % w
			var y: int = p / w
			for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + dd.x
				var ny: int = y + dd.y
				if nx < 0 or nx >= w or ny < 0 or ny >= h:
					continue
				var q: int = ny * w + nx
				if seen[q] == 0 and secret[q] != 0:
					seen[q] = 1
					stack.append(q)
		var reg: Dictionary = {"cells": cells, "passages": PackedInt32Array(), "areas": PackedInt32Array(),
			"platforms": PackedInt32Array(), "x0": w, "y0": h, "x1": -1, "y1": -1, "contents": []}
		var border: Dictionary = {}
		var plats: Dictionary = {}
		for p: int in cells:
			var x: int = p % w
			var y: int = p / w
			reg.x0 = mini(reg.x0, x)
			reg.y0 = mini(reg.y0, y)
			reg.x1 = maxi(reg.x1, x)
			reg.y1 = maxi(reg.y1, y)
			if lookalike[p] != 0:
				reg.passages.append(p)
			else:
				reg.areas.append(p)
			if y + 1 < h and invisible[p + w] != 0:
				plats[p + w] = true
			for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + dd.x
				var ny: int = y + dd.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h and reach_visual[ny * w + nx] != 0:
					border[ny * w + nx] = true
		for p: int in border:
			if p + w < w * h and invisible[p + w] != 0:
				plats[p + w] = true
		reg.platforms = PackedInt32Array(plats.keys())
		reg.contacts = _stretches(w, border)
		if reg.areas.size() >= min_area or not plats.is_empty():
			reg.kind = "area"
		else:
			reg.kind = "shortcut" if reg.contacts >= 2 else "dent"
		out.append(reg)
	return out


## How many separate 8-connected stretches a set of cells makes.
static func _stretches(w: int, cells: Dictionary) -> int:
	var seen: Dictionary = {}
	var n: int = 0
	for c: int in cells:
		if seen.has(c):
			continue
		n += 1
		var stack: Array = [c]
		seen[c] = true
		while not stack.is_empty():
			var p: int = stack.pop_back()
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var q: int = p + dy * w + dx
					if cells.has(q) and not seen.has(q) and absi((q % w) - (p % w)) <= 1:
						seen[q] = true
						stack.append(q)
	return n


## Items into the regions they lie in (a Keen 4 item sprite stands in its cell; the cell or the one
## below it counts), each marked "secret", "open" (reachable, plain connectivity) or "unreached".
static func _fill_contents(r: Dictionary, items: Array) -> void:
	var where: Dictionary = {}
	for k: int in range(r.regions.size()):
		for p: int in r.regions[k].cells:
			where[p] = k
	var w: int = int(r.width)
	var n: int = int(r.width) * int(r.height)
	var rr: PackedByteArray = r.reach_real
	for c: Array in items:
		var i: int = c[0]
		var state: String = "unreached"
		for q: int in [i, i + w]:
			if q >= n:
				continue
			if where.has(q):
				r.regions[where[q]].contents.append(c[1])
				state = "secret"
				break
			if rr[q] != 0:
				state = "open"
				break
		c.append(state)
	r.items = items
