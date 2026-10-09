# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01e: the Dreams actors (DreamsGame, drm_acts.gd): every `statetype s_*` of kd_keen.c,
## kd_act1.c and kd_act2.c built as the C's initialisers give it (read from the reference here),
## linked, with functions that exist and the DOS offsets of statetype_ptr_conversion.c for v1.00
## and v1.93; the pure functions against values worked out by hand from the C; bounceangle's
## over-read against both releases' programs.
##
## Options: --game_data=<folder> (the programs come from its kdreams and kdreams193 folders; the
## over-read check is skipped without them)

var t: T = T.new()
var consts: Dictionary = {}


func _init() -> void:
	var src: String = ProjectSettings.globalize_path("res://").path_join("../refkeen/src/kdreams")
	if not FileAccess.file_exists(src.path_join("kd_keen.c")):
		t.blocked("no reference at %s" % src)
		_release_all()
		t.finish(self)
		return
	var g: DreamsGame = DreamsGame.new()
	_games.append(g)
	var scr: Script = g.get_script()
	while scr != null:
		var m: Dictionary = scr.get_script_constant_map()
		for k: String in m:
			if not consts.has(k):
				consts[k] = m[k]
		scr = scr.get_base_script()

	_states(g, src)
	_dospointers(g, src)
	_physics(g)
	_bounce(g)
	_scorebox(g)
	_objptrs(g)
	_overread(g)
	t.ok("the engine did not quit (%s)" % g.quit_message, not g.quitting)
	_release_all()
	t.finish(self)


func _strip_comments(text: String) -> String:
	var re: RegEx = RegEx.create_from_string("(?s)/\\*.*?\\*/")
	text = re.sub(text, "", true)
	re = RegEx.create_from_string("//[^\\n]*")
	return re.sub(text, "", true)


func _value(tok: String) -> Variant:
	if tok.is_valid_int():
		return int(tok)
	if tok == "true":
		return true
	if tok == "false":
		return false
	if consts.has(tok):
		return consts[tok]
	t.ok("constant %s known" % tok, false)
	return null


## Every state the three C files define, field by field.
func _states(g: DreamsGame, src: String) -> void:
	var re: RegEx = RegEx.create_from_string("(?m)^statetype\\s+(s_\\w+)\\s*=\\s*\\{([^}]*)\\}\\s*;")
	var count: int = 0
	var bad: PackedStringArray = PackedStringArray()
	var fnbad: PackedStringArray = PackedStringArray()
	for file: String in ["kd_keen.c", "kd_act1.c", "kd_act2.c"]:
		var text: String = _strip_comments(FileAccess.get_file_as_string(src.path_join(file)))
		for m: RegExMatch in re.search_all(text):
			count += 1
			var name: String = m.get_string(1)
			var f: PackedStringArray = PackedStringArray()
			for part: String in m.get_string(2).split(","):
				f.append(part.strip_edges())
			var st: DrmDecl.statetype = g.S(StringName(name))
			if st == null:
				bad.append(name + " missing")
				continue
			var want: Array = [_value(f[0]), _value(f[1]), _value(f[2]), _value(f[3]), _value(f[4]),
				_value(f[5]), _value(f[6]), _value(f[7])]
			var got: Array = [st.leftshapenum, st.rightshapenum, st.progress, st.skippable, st.pushtofloor,
				st.tictime, st.xmove, st.ymove]
			if got != want or st.name != StringName(name):
				bad.append("%s %s != %s" % [name, got, want])
			var ptrs: Array = [st.thinkptr, st.contactptr, st.reactptr]
			for k: int in range(3):
				var w: StringName = &"" if f[8 + k] == "NULL" else StringName(f[8 + k])
				if ptrs[k] != w:
					bad.append("%s fn %d %s != %s" % [name, k, ptrs[k], w])
				if w != &"" and not g.has_method(w):
					fnbad.append(String(w))
			if f[11] == "NULL":
				if st.nextstate != null:
					bad.append(name + " nextstate not NULL")
			elif st.nextstate == null or st.nextstate != g.S(StringName(f[11].trim_prefix("&"))):
				bad.append("%s nextstate %s" % [name, f[11]])
	t.eq("states defined in kd_keen.c, kd_act1.c, kd_act2.c (C count %d)" % count, g.states.size(), count)
	t.eq("the C defines 213 states", count, 213)
	t.ok("every state as the C initialises it, nextstate linked: %s" % ", ".join(bad.slice(0, 5)), bad.is_empty())
	t.ok("every think/contact/react is a method: %s" % ", ".join(fnbad), fnbad.is_empty())
	var dangling: int = 0
	for name: StringName in g.states:
		var st: DrmDecl.statetype = g.states[name]
		if st.nextstate != null and not g.states.values().has(st.nextstate):
			dangling += 1
	t.eq("every nextstate is one of the tables", dangling, 0)
	t.ok("DrmIO's _init ran too (Keyboard %d, KbdDefs %d)" % [g.Keyboard.size(), g.KbdDefs.size()], g.Keyboard.size() == g.NumCodes and g.KbdDefs.size() == g.MaxKbds)
	t.ok("bounceangle initialised", g.bounceangle.size() == 8 and g.bounceangle[4] == [3, 2, 1, 0, 15, 14, 13, 12])
	print("  %d states" % count)


## statetype_ptr_conversion.c's offsets, for both releases, and the way back.
func _dospointers(g: DreamsGame, src: String) -> void:
	var text: String = FileAccess.get_file_as_string(src.path_join("statetype_ptr_conversion.c"))
	var re: RegEx = RegEx.create_from_string("(s_\\w+)\\.compatdospointer = (0x[0-9A-Fa-f]+);")
	for ver: Array in [["BE_GAMEVER_KDREAMSE100", DrmDecl.BE_GAMEVER_KDREAMSE100],
			["BE_GAMEVER_KDREAMSE193", DrmDecl.BE_GAMEVER_KDREAMSE193]]:
		var start: int = text.find("case %s:" % ver[0])
		var section: String = text.substr(start, text.find("break;", start) - start)
		g.refkeen_current_gamever = ver[1]
		g.RefKeen_FillObjStatesWithDOSPointers()
		var n: int = 0
		var bad: PackedStringArray = PackedStringArray()
		for m: RegExMatch in re.search_all(section):
			n += 1
			var st: DrmDecl.statetype = g.S(StringName(m.get_string(1)))
			var want: int = m.get_string(2).hex_to_int()
			if st == null or st.compatdospointer != want or g.RefKeen_GetObjStatePtrFromDOSPointer(want) != st:
				bad.append(m.get_string(1))
		t.ok("%s: all %d offsets, and back (%s)" % [ver[0], n, ", ".join(bad.slice(0, 5))], n == 213 and bad.is_empty())
	# a sample, by hand from the file
	g.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE100
	g.RefKeen_FillObjStatesWithDOSPointers()
	t.eq("E100 s_score", g.S(&"s_score").compatdospointer, 0x0CC4)
	t.eq("E100 s_keenstand", g.S(&"s_keenstand").compatdospointer, 0x0FE8)
	t.eq("E100 s_door", g.S(&"s_door").compatdospointer, 0x1842)
	g.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE193
	g.RefKeen_FillObjStatesWithDOSPointers()
	t.eq("E193 s_score", g.S(&"s_score").compatdospointer, 0x0DC8)
	t.eq("E193 s_flowerpower2", g.S(&"s_flowerpower2").compatdospointer, 0x0E04)
	t.ok("no state at offset 0", g.RefKeen_GetObjStatePtrFromDOSPointer(0) == null)
	g.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE100
	g.RefKeen_FillObjStatesWithDOSPointers()


func _ob(xspeed: int, yspeed: int) -> DrmDecl.objtype:
	var ob: DrmDecl.objtype = DrmDecl.objtype.new()
	ob.xspeed = xspeed
	ob.yspeed = yspeed
	return ob


## DoGravity, AccelerateX, FrictionX, CalcSingleGravity, ProjectileThink, VelocityThink: the tic
## loop from lasttimecount-tics, accelerating on odd tics (worked by hand from kd_act1.c).
func _physics(g: DreamsGame) -> void:
	# yspeed -5, tics 7..9: 7 -> -2 (ymove -2), 8 (ymove -4), 9: at the apex, ymove -6, stop
	var ob: DrmDecl.objtype = _ob(0, -5)
	g.lasttimecount = 10
	g.tics = 3
	g.DoGravity(ob)
	t.ok("DoGravity stops at the apex (yspeed %d ymove %d)" % [ob.yspeed, ob.ymove], ob.yspeed == 0 and ob.ymove == -6)
	# yspeed 78, tics 7..10: 80 capped (80), 160, 80 (240), 320
	ob = _ob(0, 78)
	g.lasttimecount = 11
	g.tics = 4
	g.DoGravity(ob)
	t.ok("DoGravity caps at SPDMAXY (yspeed %d ymove %d)" % [ob.yspeed, ob.ymove], ob.yspeed == 80 and ob.ymove == 320)
	# xspeed -1, +2 on tics 3 and 5: 1 (turns: xdir 1), xmove 1, 2, then 3 -> 5
	ob = _ob(-1, 0)
	ob.xdir = -1
	g.lasttimecount = 6
	g.tics = 3
	g.AccelerateX(ob, 2, 24)
	t.ok("AccelerateX turns round (xspeed %d xdir %d xmove %d)" % [ob.xspeed, ob.xdir, ob.xmove],
		ob.xspeed == 3 and ob.xdir == 1 and ob.xmove == 5)
	ob = _ob(23, 0)
	g.lasttimecount = 2
	g.tics = 2
	g.AccelerateX(ob, 2, 24)
	t.ok("AccelerateX caps at max (xspeed %d xmove %d)" % [ob.xspeed, ob.xmove], ob.xspeed == 24 and ob.xmove == 47)
	ob = _ob(-23, 0)
	g.AccelerateX(ob, -2, 24)
	t.ok("AccelerateX caps at -max (xspeed %d xmove %d)" % [ob.xspeed, ob.xmove], ob.xspeed == -24 and ob.xmove == -47)
	# xspeed 2, friction on tics 1 and 3: 1 (xmove 1), 2, 0 (2), 2
	ob = _ob(2, 0)
	g.lasttimecount = 5
	g.tics = 4
	g.FrictionX(ob)
	t.ok("FrictionX slows to a stop (xspeed %d xmove %d)" % [ob.xspeed, ob.xmove], ob.xspeed == 0 and ob.xmove == 2)
	ob = _ob(-1, 0)
	g.lasttimecount = 2
	g.tics = 2
	g.FrictionX(ob)
	t.ok("FrictionX from -1 (xspeed %d xmove %d)" % [ob.xspeed, ob.xmove], ob.xspeed == 0 and ob.xmove == -1)
	# speeds 3 (tic 7), 3, 6 (tic 9): 3+3+6 = 12, halved
	g.lasttimecount = 10
	g.tics = 3
	g.CalcSingleGravity()
	t.eq("CalcSingleGravity", g.singlegravity, 6)
	# yspeed 20 over tics 7..9: 23 (ymove 23), 46, 26 (72); xmove 3 * 10
	ob = _ob(10, 20)
	g.ProjectileThink(ob)
	t.ok("ProjectileThink (xmove %d ymove %d yspeed %d)" % [ob.xmove, ob.ymove, ob.yspeed],
		ob.xmove == 30 and ob.ymove == 72 and ob.yspeed == 26)
	ob = _ob(-7, 5)
	g.tics = 4
	g.VelocityThink(ob)
	t.ok("VelocityThink (xmove %d ymove %d)" % [ob.xmove, ob.ymove], ob.xmove == -28 and ob.ymove == 20)
	ob = _ob(0, 0)
	ob.shapenum = 175
	ob.temp2 = 174
	ob.temp3 = 176
	g.BonusThink(ob)
	t.eq("BonusThink wraps the animation", ob.shapenum, 174)


## The floor bounce of PowerReact and ProjectileReact (worked by hand from kd_keen.c).
func _bounce(g: DreamsGame) -> void:
	# xspeed 40, yspeed 10 on a flat floor: angle 0 then 7 (moving right), speed 40*286 = 11440,
	# halved 5720; bounceangle[1][7] = 0: xspeed 5720/286 = 20, yspeed -10
	var ob: DrmDecl.objtype = _ob(40, 10)
	ob.hitnorth = 1
	var speed: int = g._floor_bounce(ob)
	t.ok("bounce right (speed %d xspeed %d yspeed %d)" % [speed, ob.xspeed, ob.yspeed],
		speed == 5720 and ob.xspeed == 20 and ob.yspeed == -10)
	# xspeed -30, yspeed -5 (cleared): angle 0, speed 8580 -> 4290; bounceangle[1][0] = 7:
	# xspeed -(4290/286) = -15, yspeed -15/2 = -7
	ob = _ob(-30, -5)
	ob.hitnorth = 1
	speed = g._floor_bounce(ob)
	t.ok("bounce left (speed %d xspeed %d yspeed %d)" % [speed, ob.xspeed, ob.yspeed],
		speed == 4290 and ob.xspeed == -15 and ob.yspeed == -7)
	# straight down at 40 on a flat floor: angle 3, speed 40*256 -> 5120; bounceangle[1][3] = 4
	ob = _ob(0, 40)
	ob.hitnorth = 1
	speed = g._floor_bounce(ob)
	t.ok("bounce straight up (speed %d xspeed %d yspeed %d)" % [speed, ob.xspeed, ob.yspeed],
		speed == 5120 and ob.xspeed == 0 and ob.yspeed == -20)
	# past the table: row 8 is s_score's first words (0, 0, think, ...), row 9 starts with
	# ScoreThink's far pointer, then the NULL contact (0, 0) ... and s_flowerpower1's leftshapenum
	t.eq("bounceangle[8][2] reads s_score.progress", g._bounceangle(8, 2), g.think)
	t.eq("bounceangle[9][0] reads a function pointer", g._bounceangle(9, 0), 0xFFFF)
	t.eq("bounceangle[9][2] reads the NULL contact", g._bounceangle(9, 2), 0)
	t.eq("bounceangle[9][7] reads s_flowerpower1.leftshapenum", g._bounceangle(9, 7), g.FLOWERPOWER1SPR)


## MemDrawCharEGA writes into the score box sprite held in grsegs.
func _scorebox(g: DreamsGame) -> void:
	g.grsegs.resize(g.NUMCHUNKS)
	var tiles: PackedByteArray = PackedByteArray()
	tiles.resize(32 * 4)
	for i: int in range(tiles.size()):
		tiles[i] = i
	g.grsegs[g.STARTTILE8] = tiles
	var box: PackedByteArray = PackedByteArray()
	box.resize(512)
	g.grsegs[g.SCOREBOXSPR] = box
	g.MemDrawCharEGA(2, 10, 5, 100)
	var held: PackedByteArray = g.grsegs[g.SCOREBOXSPR]
	var ok: bool = true
	for plane: int in range(4):
		for row: int in range(8):
			if held[10 + plane * 100 + row * 5] != 64 + plane * 8 + row:
				ok = false
	t.ok("MemDrawCharEGA: 4 planes x 8 rows of char 2 into the score box", ok)


## COMPAT_OBJ_CONVERT_*: an object as a 16-bit pointer and back.
func _objptrs(g: DreamsGame) -> void:
	g.objarray = []
	for i: int in range(g.MAXACTORS):
		var o: DrmDecl.objtype = DrmDecl.objtype.new()
		o.index = i
		g.objarray.append(o)
	g.refkeen_compat_kd_play_objoffset = 0x3A8C
	var p: int = g._obj_to_dosptr(g.objarray[5])
	t.eq("object 5 as a DOS pointer", p, 0x3A8C + 5 * 76)
	t.ok("and back", g._dosptr_to_obj(p) == g.objarray[5] and g._dosptr_to_obj(g.s16(p)) == g.objarray[5])
	t.ok("dummyobj comes back as dummyobj, 0 as null", g._dosptr_to_obj(g._obj_to_dosptr(g.dummyobj)) == g.dummyobj
		and g._dosptr_to_obj(0) == null and g._obj_to_dosptr(null) == 0)


## bounceangle's over-read modelled from the state tables, against what each release's program has
## after the table.
func _overread(g: DreamsGame) -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		print("  (no --game_data: the over-read is not checked against the programs)")
		return
	for ver: Array in [["kdreams", DrmDecl.BE_GAMEVER_KDREAMSE100], ["kdreams193", DrmDecl.BE_GAMEVER_KDREAMSE193]]:
		var d: DreamsData = DreamsData.new()
		if not d.load_game(root.path_join(ver[0])):
			print("  (%s does not load: %s)" % [ver[0], d.error])
			continue
		var img: PackedByteArray = d.image
		var at: int = -1
		var p: int = img.find(7)
		while p >= 16 and p + 64 <= img.size():
			var row: bool = true
			for k: int in range(8):
				if img.decode_u16(p + k * 2) != 7 - k or img.decode_u16(p - 16 + k * 2) != 0:
					row = false
					break
			if row:
				at = p - 16
				break
			p = img.find(7, p + 1)
		if not t.ok("%s: bounceangle found in the program" % ver[0], at >= 0):
			continue
		g.refkeen_current_gamever = ver[1]
		g.RefKeen_FillObjStatesWithDOSPointers()
		var bad: PackedStringArray = PackedStringArray()
		for wall: int in range(8, 51):
			for angle: int in range(8):
				var word: int = img.decode_u16(at + 2 * (wall * 8 + angle))
				var model: int = g._bounceangle(wall, angle)
				if (model == 0xFFFF and word < 16) or (model != 0xFFFF and model != word):
					bad.append("[%d][%d] %d/%d" % [wall, angle, model, word])
		t.ok("%s: bounceangle rows 8-50 as the program has them after the table %s" % [ver[0], ", ".join(bad.slice(0, 6))],
			bad.is_empty())
		print("  %s: bounceangle at image offset 0x%x" % [ver[0], at])
	g.refkeen_current_gamever = DrmDecl.BE_GAMEVER_KDREAMSE100
	g.RefKeen_FillObjStatesWithDOSPointers()


## The state tables' nextstate links form loops: break them so the run ends without leaks.
var _games: Array = []


func _release_all() -> void:
	for o: Object in _games:
		o.call("release_links")
	_games.clear()
