# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## V15-06 Keen's Closet on the asset stage (A18). For every game: the game read twice, as it is and with
## an outfit on (a colour for each part, each chosen so that every tone of it differs from Keen's own);
## then for every frame of Keen:
## - his shape is unchanged (the mask), and only pixels of the rules' colours change;
## - every pixel of a part's own colour (RULES' "core") changes, to the outfit's colour for that part in
##   that tone (light, as is, shade, deep shade) by the EGA pairs, read from the table here, not from the
##   closet's code; a shared colour's pixel, to a tone of one of its parts; Dreams' pajamas to the shirt's
##   or the pants';
## - the native view's slots mark exactly the changed pixels;
## - Keen 1-3: the sprite file's planes (what the loader copies onto the card) hold the new pixels;
## and every other sprite is unchanged. The frames the rules could not settle are listed with why.
## A planted fault (the filter also changing one pixel of a Keen frame outside the parts) must be caught.
## The game left alone: Keen 4's first demo played with the outfit on ends as it does without (the
## machine's time, Keen's place, the score, the level), its pictures differing (Keen in the outfit).
##
## Options: --game_data=<folder> --games=keen1,...,kdreams193

var t: T = T.new()

const OUTFIT: Dictionary = {"helmet": "#5555ff", "trim": "#ff5555", "shirt": "#55ff55", "pants": "#ffff55", "shoes": "#ffffff"}
const FOLDERS: Array = ["keen1", "keen2", "keen3", "keen4", "keen5", "keen6", "kdreams", "kdreams193"]


func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	for folder: String in str(opts.get("games", ",".join(FOLDERS))).split(",", false):
		var plain: Object = _load(root, folder, null)
		var cl: KeenCloset = KeenCloset.new(_game(folder), OUTFIT)
		var dressed: Object = _load(root, folder, cl)
		if plain == null or dressed == null:
			t.blocked("%s: could not be read" % folder)
			continue
		var r: Dictionary = _check(folder, plain, dressed)
		t.eq("%s: Keen's frames recoloured exactly on the rules' parts (%d frames, %d pixels)" % [folder, r.frames, r.changed],
			r.problems, [])
		t.ok("%s: every other sprite unchanged (%d)" % [folder, r.others], r.others_changed == 0)
		t.ok("%s: Keen has frames and the outfit shows on them" % folder, r.frames > 20 and r.changed > 1000)
		var rep: Array = cl.report(dressed.stage)
		print("  %s: %d Keen frames, %d pixels recoloured; %d frames the rules could not settle%s" % [
			folder, r.frames, r.changed, rep.size(), ":" if not rep.is_empty() else ""])
		for e: Array in rep:
			print("    %s: %s" % [e[0], e[1]])
	# the planted fault
	if str(opts.get("games", "keen4")).contains("keen4"):
		var cl: KeenCloset = KeenCloset.new("keen4", OUTFIT)
		var planted: Callable = func(stage: AssetStage, key: int, name: String, img: Dictionary) -> Dictionary:
			var out: Dictionary = cl.filter(stage, key, name, img)
			if name == "SPR_KEENSTANDR":
				out = out.duplicate()
				var px: PackedByteArray = (out.pixels as PackedByteArray).duplicate()
				for k: int in range(px.size()):
					if out.opaque[k] != 0 and px[k] == 15:    # the face's white, no part's colour
						px[k] = 12
						break
				out.pixels = px
			return out
		var plain: Object = _load(root, "keen4", null)
		var bad: Object = _load(root, "keen4", null, planted)
		var r: Dictionary = _check("keen4", plain, bad)
		t.ok("the planted fault (one face pixel recoloured) is caught (%d problems)" % r.problems.size(), r.problems.size() > 0)
		# the game left alone
		var a: Array = _demo(root, null)
		var b: Array = _demo(root, KeenCloset.new("keen4", OUTFIT))
		t.ok("keen4: demo 0 ends the same with the outfit on (%s / %s)" % [a[0], b[0]], not a[0].is_empty() and a[0] == b[0])
		t.ok("keen4: and its pictures show the outfit (%d of %d sampled pictures differ)" % [_differ(a[1], b[1]), a[1].size()],
			_differ(a[1], b[1]) > 0)
	t.finish(self)


static func _game(folder: String) -> String:
	return "kdreams" if folder.begins_with("kdreams") else folder


func _load(root: String, folder: String, cl: KeenCloset, f: Callable = Callable()) -> Object:
	var d: Object
	match folder:
		"keen1", "keen2", "keen3":
			d = VortData.new()
		"keen4", "keen5", "keen6":
			d = GalData.new()
		_:
			d = DreamsData.new()
	var stage: AssetStage = d.stage
	if cl != null:
		stage.add_filter(cl.filter)
	if f.is_valid():
		stage.add_filter(f)
	var ok: bool
	if d is VortData:
		ok = (d as VortData).load_game(root.path_join(folder), "CK" + folder.substr(4, 1))
	elif d is GalData:
		ok = (d as GalData).load_game(root.path_join(folder), "res://data/omnispeak".path_join(folder if folder != "keen6" else "keen6e14"))
	else:
		ok = (d as DreamsData).load_game(root.path_join(folder))
	return d if ok else null


## The checks on every sprite: {frames, changed, problems, others, others_changed}.
func _check(folder: String, plain: Object, dressed: Object) -> Dictionary:
	var fam: String = KeenCloset.family_of(_game(folder))
	var rule: Dictionary = KeenCloset.RULES[fam]
	var a: Array = AssetPacks.sprites_of(plain)
	var b: Array = AssetPacks.sprites_of(dressed)
	var stage: AssetStage = dressed.stage
	var r: Dictionary = {"frames": 0, "changed": 0, "problems": [], "others": 0, "others_changed": 0}
	for i: int in range(a.size()):
		var key: int = a[i][0]
		var pa: Dictionary = a[i][1]
		var pb: Dictionary = b[i][1]
		var name: String = stage.name_of(key)
		if pa.is_empty():
			continue
		if not KeenCloset.is_keen(fam, name):
			r.others += 1
			if pa.pixels != pb.pixels or pa.opaque != pb.opaque or not stage.extras(key).is_empty():
				r.others_changed += 1
			continue
		r.frames += 1
		if pa.opaque != pb.opaque:
			r.problems.append("%s: the shape changed" % name)
			continue
		var slots: PackedByteArray = stage.extras(key).get("slots", PackedByteArray())
		var bad: int = 0
		for k: int in range(pa.pixels.size()):
			var was: int = pa.pixels[k]
			var now: int = pb.pixels[k]
			var drawn: bool = pa.opaque[k] != 0
			var slot: bool = not slots.is_empty() and slots[k] != 0
			if was != now:
				r.changed += 1
			if not drawn:
				if was != now:
					bad += 1
				continue
			if rule.core.has(was):
				var part: String = rule.core[was][0]
				var tone: int = rule.core[was][1]
				var want: Array = [_tone(part, tone)]
				if rule.has("split") and part == "shirt":
					want.append(_tone("pants", tone))
				if not want.has(now) or not slot:
					bad += 1
			elif rule.shared.has(was):
				var want: Array = []
				for p: String in rule.shared[was]:
					want.append(_tone(p, rule.shared[was][p]))
				if (now != was and not want.has(now)) or (now != was) != slot:
					bad += 1
			elif now != was or slot:
				bad += 1
		if bad > 0:
			r.problems.append("%s: %d pixels off the rules" % [name, bad])
		if dressed is VortData:
			var vd: VortData = dressed
			var e: Dictionary = vd.sprite_entries[key * 4]
			var px: PackedByteArray = VortData.unplane(vd.sprite_planes, int(e.shape), vd.spritesize, int(e.w), int(e.h))
			if px != pb.pixels:
				r.problems.append("%s: the sprite file's planes do not hold the new pixels" % name)
	return r


## The outfit's colour for a part in a tone, by the EGA pairs (the closet's table restated).
static func _tone(part: String, tone: int) -> int:
	var c: int = KeenCloset.nearest_ega(Color.html(OUTFIT[part]))
	if tone < 0:
		return {1: 9, 2: 10, 3: 11, 4: 12, 5: 13, 6: 14, 7: 15, 8: 7, 0: 8}.get(c, 15)
	for i: int in range(tone):
		c = {9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 6, 15: 7, 7: 8, 8: 0, 0: 0}.get(c, 8)
	return c


## Keen 4's demo 0: [[machine time, Keen's x, y, score, level], hashes of every 8th picture].
func _demo(root: String, cl: KeenCloset) -> Array:
	var d: GalData = GalData.new()
	if cl != null:
		d.stage.add_filter(cl.filter)
	if not d.load_game(root.path_join("keen4"), "res://data/omnispeak/keen4"):
		return [[], []]
	var vm: DosMachine = DosMachine.new()
	var g: GalGame = load("res://games/galaxy/gal_keen4.gd").new()
	g.vm = vm
	g.data = d
	var hashes: Array = []
	var n: Array = [0]
	vm.on_display = func() -> void:
		n[0] += 1
		if n[0] % 8 == 0:
			hashes.append(hash(vm.card.compose()))
	vm.time_limit = DosMachine.seconds_to_units(600.0)
	vm.on_limit = func() -> void:
		g.Quit("emulated time limit reached")
	g.CK_Main(PackedStringArray(["/PLAYDEMO", "0"]))
	var end: Array = [vm.now, g.ck_keenObj.posX if g.ck_keenObj != null else -1, g.ck_keenObj.posY if g.ck_keenObj != null else -1,
		g.ck_gameState.keenScore, g.ck_gameState.currentLevel]
	g.CK_ReleaseLinks()
	g.RF_Shutdown()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	return [end, hashes]


static func _differ(a: Array, b: Array) -> int:
	var n: int = 0
	for i: int in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			n += 1
	return n + absi(a.size() - b.size())
