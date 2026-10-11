# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name ListCompare
extends RefCounted
## REND-01 / REND-01R: each picture the card shows held against the draw list of the refresh it is,
## composed at 1x with the data's own images (render/vort_draw_layout.gd, gal_draw_layout.gd,
## drm_draw_layout.gd). One copy of the comparison for the rend01 tests (scripted play, the demos) and
## the session runners' --compare_lists (the recorded sessions). Every picture shown in the EGA mode is
## one of:
##   compared: a refresh's picture; the list composed and held against the card's through the palette
##     (a fade can show different indices in the same colour): "match", else "differ";
##   a window over the play: the list's picture with the window's rectangle (the list's overlay) copied
##     from the card's must be the card's ("windows", "windows_ok"): what the shell shows;
##   set aside ("skipped", each under "why <reason>"): no list is the picture (a page the lists don't
##     make, a picture written onto the page, a draw routine over the play, the high scores, a picture
##     that changed while the beam drew it, nothing shown from a refresh yet).
## The first few pictures that differ are saved as PNGs (the card's left, the list's right) to `out`.
## Reading the lists and the data changes nothing in the game (the lists are presentation only).

const W: int = 320
const H: int = 200

## The counts above ("shown": every EGA picture looked at); the tests keep their own beside them.
var r: Dictionary = {}
## Where the pictures that differ go, and the start of their file names
var out: String = ""
var name: String = ""
## How many of each to save
var keep: int = 6
var keep_windows: int = 3
## GalImages or DrmImages (Keen 4-6, Dreams): the data's unshifted images
var images: RefCounted = null
## The last list composed (its refresh's time) and its picture: a refresh's picture shows for several
## retraces, and a window list is a copy of its refresh's
var _pic_t: float = -1.0
var _pic: PackedByteArray = PackedByteArray()
var _ops: Array = []
## The last verdict, for the same picture shown again: [list's time, window], the card's picture and
## palette, and whether it was right
var _memo_key: Array = []
var _memo_pixels: PackedByteArray = PackedByteArray()
var _memo_palette: PackedByteArray = PackedByteArray()
var _memo_ok: bool = false


func _init(counts: Dictionary, out_dir: String = "", file_name: String = "", imgs: RefCounted = null) -> void:
	r = counts
	for k: String in ["shown", "compared", "match", "differ", "windows", "windows_ok", "skipped", "saved", "win_saved"]:
		if not r.has(k):
			r[k] = 0
	out = out_dir
	name = file_name
	images = imgs


## The counts as one line of JSON (the session runners' lists.json).
func summary() -> String:
	var why: Dictionary = {}
	for k: String in r:
		if k.begins_with("why "):
			why[k.substr(4)] = r[k]
	return JSON.stringify({"shown": r.shown, "compared": r.compared, "match": r.match, "differ": r.differ,
		"windows": r.windows, "windows_ok": r.windows_ok, "windows_part": r.get("windows_part", 0), "window_px": r.get("window_px", 0), "skipped": r.skipped, "why": why})


# ------------------------------------------------------------------ Keen 1-3

## The draw list of the picture on display (the card latched the start of the newest refresh written
## before the last retrace, with its panning), {} when none is (counted as set aside).
func vorticons_list(g: Object, vm: DosMachine) -> Dictionary:
	var card: EgaCard = vm.card
	if card.video_mode != EgaCard.MODE_EGA:
		return {}
	r.shown += 1
	if card.frame_mixed:
		return _aside("changed while drawn")
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return _aside("no refresh shown")
	if card.display_start != int(list.start) or (card.atc[EgaCard.ATR_PELPAN] & 7) != int(list.pan):
		return _aside("a page the lists don't make")
	return list


## Keen 1-3: `list` (on display) composed at 1x against the card's picture; with a window printed over
## the play (DrawChar, until a full repaint) the window check. Returns `list` when it was compared as a
## refresh's picture, {} otherwise.
func vorticons_check(g: Object, list: Dictionary, card: EgaCard) -> Dictionary:
	if str(list.user) != "":
		return _aside("user routine " + str(list.user))
	var pic: PackedByteArray = _composed(list, func() -> Array: return VortDrawLayout.ops(g, list),
		func(ops: Array) -> PackedByteArray: return VortDrawLayout.compose(g, ops))
	if g.draw_overlaid[int(list.page)]:
		_window(card, pic, list, g.draw_overlay_rect[int(list.page)])
		return {}
	_compare(card, pic, list)
	return list


## Keen 1-3, both steps: what a session runner calls at each picture shown.
func vorticons(g: Object, vm: DosMachine) -> Dictionary:
	var list: Dictionary = vorticons_list(g, vm)
	return {} if list.is_empty() else vorticons_check(g, list, vm.card)


# ------------------------------------------------------------------ Keen 4-6, Dreams

## Keen 4-6: the list of the picture on display (taken at the last retrace): the newest whose start was
## written before it, if the card's start is that list's; {} when none is (counted as set aside).
func galaxy_list(g: Object, vm: DosMachine) -> Dictionary:
	return _shown(g, vm, false)


## Keen Dreams: as galaxy_list, the panning the list's too.
func dreams_list(g: Object, vm: DosMachine) -> Dictionary:
	return _shown(g, vm, true)


## Keen 4-6 and Dreams: `list` (on display) composed at 1x against the card's picture: a list that is not
## a refresh's picture is set aside, one with a window over the play (its overlay) has the window check.
## `play_only`: Keen 4-6's high scores (a list, the names written over it) set aside. Returns `list` when
## it was compared as a refresh's picture, {} otherwise.
func galaxy_check(g: Object, list: Dictionary, card: EgaCard, play_only: bool = true) -> Dictionary:
	var why: String = ""
	if list.get("none", false):
		why = "not a refresh"
	elif list.get("touched", false):
		why = "written onto the page"
	elif str(list.get("user", "")) != "":
		why = "draw routine " + str(list.user)
	elif play_only and not list.get("play", true):
		why = "high scores"
	if why != "":
		return _aside(why)
	var pic: PackedByteArray
	if images is GalImages:
		pic = _composed(list, func() -> Array: return GalDrawLayout.ops(g, list),
			func(ops: Array) -> PackedByteArray: return GalDrawLayout.compose(images as GalImages, ops, list.dyn))
	else:
		pic = _composed(list, func() -> Array: return DrmDrawLayout.ops(g, list),
			func(ops: Array) -> PackedByteArray: return DrmDrawLayout.compose(images as DrmImages, ops, list.dyn))
	var over: Rect2i = list.get("overlay", Rect2i())
	if over.size != Vector2i.ZERO:
		_window(card, pic, list, over)
		return {}
	_compare(card, pic, list)
	return list


## Keen 4-6, both steps (a session runner).
func galaxy(g: Object, vm: DosMachine) -> Dictionary:
	var list: Dictionary = galaxy_list(g, vm)
	return {} if list.is_empty() else galaxy_check(g, list, vm.card)


## Keen Dreams, both steps (a session runner): every refresh's picture compared, the title map's too.
func dreams(g: Object, vm: DosMachine) -> Dictionary:
	var list: Dictionary = dreams_list(g, vm)
	return {} if list.is_empty() else galaxy_check(g, list, vm.card, false)


func _shown(g: Object, vm: DosMachine, pan: bool) -> Dictionary:
	var card: EgaCard = vm.card
	if card.video_mode != EgaCard.MODE_EGA:
		return {}
	r.shown += 1
	if card.frame_mixed:
		return _aside("changed while drawn")
	var list: Dictionary = g.draw_list
	if int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		list = g.draw_list_prev
	if list.is_empty() or int(list.get("written_vbl", -1)) < 0 or int(list.written_vbl) >= vm.vbl_count:
		return _aside("no refresh shown")
	if card.display_start != int(list.start):
		return _aside("a page the lists don't make")
	if pan and not list.get("none", false) and (card.atc[EgaCard.ATR_PELPAN] & 7) != int(list.get("pan", 0)):
		return _aside("a page the lists don't make")
	return list


# ------------------------------------------------------------------ the comparison

func _aside(why: String) -> Dictionary:
	r.skipped += 1
	r["why " + why] = r.get("why " + why, 0) + 1
	return {}


## The list composed at 1x (once per refresh: its copies with a window over them are the same picture):
## `ops` makes its layout, `compose` the picture from that.
func _composed(list: Dictionary, ops: Callable, compose: Callable) -> PackedByteArray:
	var t: float = float(list.get("t", -1.0))
	if t < 0.0 or t != _pic_t or _pic.is_empty():
		_ops = ops.call()
		_pic = compose.call(_ops)
		_pic_t = t
	return _pic


## The same verdict as last time: the same list and window, the card's picture and palette unchanged.
func _memo(key: Array, card: EgaCard) -> bool:
	return key == _memo_key and card.frame_pixels == _memo_pixels and card.frame_palette == _memo_palette


func _remember(key: Array, card: EgaCard, ok: bool) -> void:
	_memo_key = key
	_memo_pixels = card.frame_pixels
	_memo_palette = card.frame_palette
	_memo_ok = ok


## A refresh's picture: the list's against the card's.
func _compare(card: EgaCard, pic: PackedByteArray, list: Dictionary) -> void:
	r.compared += 1
	var key: Array = [float(list.get("t", -1.0)), Rect2i()]
	var ok: bool = _memo_ok if _memo(key, card) else (pic == card.frame_pixels or same_colours(pic, card.frame_pixels, card.frame_palette))
	_remember(key, card, ok)
	if ok:
		r.match += 1
		return
	r.differ += 1
	if r.saved < keep and out != "":
		r.saved += 1
		var path: String = out.path_join("%s_differ_%d.png" % [name, r.saved])
		save(card, pic, path)
		_describe(card, pic, list, Rect2i(0, 0, W, H), path.get_basename() + ".txt")


## A window over the play: the list's picture with `rect` (on the picture) copied from the card's is the
## card's: outside the rectangle the two are the same.
func _window(card: EgaCard, pic: PackedByteArray, list: Dictionary, over: Rect2i) -> void:
	var rect: Rect2i = over.intersection(Rect2i(0, 0, W, H))
	r.windows += 1
	if rect.size.x < W or rect.size.y < H:
		r.windows_part = r.get("windows_part", 0) + 1
	r.window_px = r.get("window_px", 0) + rect.get_area()    # under the window: taken from the card, not compared
	var key: Array = [float(list.get("t", -1.0)), rect]
	var ok: bool = _memo_ok
	if not _memo(key, card):
		ok = true
		var px: PackedByteArray = card.frame_pixels
		for y: int in range(H):
			var a: int = y * W
			if y >= rect.position.y and y < rect.end.y:
				# the row's two sides of the window
				if pic.slice(a, a + rect.position.x) != px.slice(a, a + rect.position.x) \
						or pic.slice(a + rect.end.x, a + W) != px.slice(a + rect.end.x, a + W):
					ok = false
					break
			elif pic.slice(a, a + W) != px.slice(a, a + W):
				ok = false
				break
		if not ok:
			ok = same_colours(with_window(pic, px, rect), px, card.frame_palette)
		_remember(key, card, ok)
	if ok:
		r.windows_ok += 1
	elif r.win_saved < keep_windows and out != "":
		r.win_saved += 1
		var path: String = out.path_join("%s_window_differ_%d.png" % [name, r.win_saved])
		var with: PackedByteArray = with_window(pic, card.frame_pixels, rect)
		save(card, with, path)
		_describe(card, with, list, rect, path.get_basename() + ".txt")


## Beside a saved picture, for review: the refresh's time, where the two differ (the card's index, the
## list's), the window's rectangle, and the list's ops over a pixel that differs (a tile's 16 pixels, a
## sprite's or picture's 32 or so: near enough to find the image to look at).
func _describe(card: EgaCard, pic: PackedByteArray, list: Dictionary, rect: Rect2i, path: String) -> void:
	var px: PackedByteArray = card.frame_pixels
	var box: Rect2i = Rect2i()
	var n: int = 0
	var first: Array = []
	var cells: Dictionary = {}    # the 8x8 cells holding a pixel that differs
	for i: int in range(mini(pic.size(), px.size())):
		if pic[i] != px[i]:
			n += 1
			var at: Vector2i = Vector2i(i % W, int(i / float(W)))
			box = Rect2i(at, Vector2i.ONE) if box.size == Vector2i.ZERO else box.merge(Rect2i(at, Vector2i.ONE))
			cells[at / 8] = true
			if first.size() < 12:
				first.append("(%d,%d) card %d list %d" % [at.x, at.y, px[i], pic[i]])
	var lines: PackedStringArray = PackedStringArray([
		"refresh at %.4f s (the list's time); %d pixels differ in %s; window %s" % [float(list.get("t", -1.0)), n, box, rect],
		"  " + ", ".join(first)])
	for op: Dictionary in _ops:
		if not op.has("x") or not op.has("id"):
			continue
		var size: int = 16 if op.kind in ["tile", "mtile"] else 32
		var hit: bool = false
		for cy: int in range(floori(float(op.y) / 8.0), floori((float(op.y) + size - 1) / 8.0) + 1):
			for cx: int in range(floori(float(op.x) / 8.0), floori((float(op.x) + size - 1) / 8.0) + 1):
				hit = hit or cells.has(Vector2i(cx, cy))
		if hit:
			lines.append("  op %s %s at (%s, %s)%s" % [op.kind, op.id, op.x, op.y, "" if not op.has("k") else " " + str(op.k)])
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()


## `pic` with `rect` copied from `card_pixels` (what the shell shows: the window from the card's picture).
static func with_window(pic: PackedByteArray, card_pixels: PackedByteArray, rect: Rect2i) -> PackedByteArray:
	var with: PackedByteArray = pic.duplicate()
	for y: int in range(rect.position.y, rect.end.y):
		var row: int = y * W
		for x: int in range(rect.position.x, rect.end.x):
			with[row + x] = card_pixels[row + x]
	return with


## The two pictures look the same through the palette (every index pair the same colour).
static func same_colours(a: PackedByteArray, b: PackedByteArray, pal: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var same: Dictionary = {}
	for i: int in range(a.size()):
		var x: int = a[i]
		var y: int = b[i]
		if x == y:
			continue
		var key: int = x * 16 + y
		if not same.has(key):
			same[key] = pal[x * 3] == pal[y * 3] and pal[x * 3 + 1] == pal[y * 3 + 1] and pal[x * 3 + 2] == pal[y * 3 + 2]
		if not same[key]:
			return false
	return true


## The card's picture (left) and `pic` (right) side by side through the card's palette, as a PNG.
static func save(card: EgaCard, pic: PackedByteArray, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var pal: PackedByteArray = card.frame_palette
	var rgb: PackedByteArray = PackedByteArray()
	rgb.resize(2 * W * H * 3)
	for y: int in range(H):
		for x: int in range(W):
			for side: int in range(2):
				var c: int = (card.frame_pixels if side == 0 else pic)[y * W + x] * 3
				var o: int = (y * 2 * W + side * W + x) * 3
				rgb[o] = pal[c]
				rgb[o + 1] = pal[c + 1]
				rgb[o + 2] = pal[c + 2]
	Image.create_from_data(2 * W, H, false, Image.FORMAT_RGB8, rgb).save_png(path)
