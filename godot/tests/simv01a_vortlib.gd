# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-V-01a: the Vorticons library layer on the emulated machine. Its
## drawing routines, working through the card's latches and planes the way
## the original's assembly does, must put on screen exactly what the loader
## decodes independently (DATA-01V's decoder): characters, tiles, pictures
## and sprites at each of the four pixel shifts, merged under their masks.
## Also the speaker played from the timer interrupt, the keyboard interrupt,
## and the clock's refresh and timer rates.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join("keen1"), "CK1"):
		t.blocked("Keen 1 data: " + data.error)
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var lib: VortLib = VortLib.new()
	lib.vm = vm
	lib.data = data
	lib.LoadGraphics()
	var card: EgaCard = vm.card

	# ONE MOMENT: drawn by LoadGraphics at byte 15, row 76
	var pic: PackedByteArray = card.compose()
	t.ok("the mode is 0Dh with 48-byte rows", card.video_mode == 0x0D and card.line_width() == 48)
	t.ok("LoadGraphics shows the ONE MOMENT picture at (120, 76)", _region_equals(pic, 120, 76, data.pics[14]))
	t.ok("the border is dark cyan", card.border_rgb() == PackedByteArray([0, 170, 170]))

	# DrawChar
	lib.screenseg = 0xA000
	lib.DrawChar(2, 8, 65)
	pic = card.compose()
	t.ok("DrawChar puts character 65 at (16, 8)", _region_equals(pic, 16, 8, {"w": 8, "h": 8, "pixels": data.chars.slice(65 * 64, 66 * 64)}))
	lib.DrawChar(3, 8, 65 + 0x80)
	pic = card.compose()
	t.ok("the later half of the font is the grey one", _region_equals(pic, 24, 8, {"w": 8, "h": 8, "pixels": data.chars.slice((65 + 0x80) * 64, (66 + 0x80) * 64)}))

	# DrawTile, unmasked: through the animation table
	for i: int in range(data.num_tiles):
		for a: int in range(4):
			lib.tile_anim[a * VortLib.MAXTILES + i] = i << 5
	lib.animtable = 0
	lib.DrawTile(4, 32, 100)
	pic = card.compose()
	t.ok("DrawTile puts tile 100 at (32, 32)", _region_equals(pic, 32, 32, {"w": 16, "h": 16, "pixels": data.tiles.slice(100 * 256, 101 * 256)}))
	lib.animtable = 2
	lib.tile_anim[2 * VortLib.MAXTILES + 100] = 101 << 5
	lib.DrawTile(6, 32, 100)
	pic = card.compose()
	t.ok("the animation table redirects a tile to another image", _region_equals(pic, 48, 32, {"w": 16, "h": 16, "pixels": data.tiles.slice(101 * 256, 102 * 256)}))

	# DrawTile, masked: the tile that follows is the mask; over a colour-15 field
	_fill(card, 0, 64, 320, 16, 15)
	lib.DrawTile(0, 64, 200 | 0x8000)
	pic = card.compose()
	var expect: PackedByteArray = PackedByteArray()
	for y: int in range(16):
		for x: int in range(16):
			var m: int = data.tiles[201 * 256 + y * 16 + x]
			var d: int = data.tiles[200 * 256 + y * 16 + x]
			expect.append((15 & m) | (d & ~m & 15))
	t.ok("a masked tile merges plane by plane: screen AND mask OR tile AND NOT mask", _region_equals(pic, 0, 64, {"w": 16, "h": 16, "pixels": expect}))

	# DrawPic: the title picture
	lib.DrawPic(0, 0, 0)
	pic = card.compose()
	t.ok("DrawPic puts the title picture (%dx%d) at (0, 0)" % [data.pics[0].w, data.pics[0].h], _region_equals(pic, 0, 0, data.pics[0]))

	# DrawSprite at the four shifts over a colour-15 field and over black
	var all_ok: bool = true
	var shown: PackedStringArray = PackedStringArray()
	for spr: int in [0, 48, 60, 118]:
		var s: Dictionary = data.sprites[spr]
		for shift: int in range(4):
			for bg: int in [15, 0]:
				_fill(card, 0, 0, 320, 64, bg)
				lib.DrawSprite(10, 20, spr * 4 + shift)
				pic = card.compose()
				var good: bool = true
				for y: int in range(s.h):
					for x: int in range(-2, s.w + 10):
						var px: int = 80 + 2 * shift + x
						var want: int = bg
						if x >= 0 and x < s.w and s.mask[y * s.w + x] == 1:
							want = s.pixels[y * s.w + x]
						if pic[(20 + y) * 320 + px] != want:
							good = false
				if not good:
					all_ok = false
					shown.append("sprite %d shift %d on %d" % [spr, shift, bg])
	t.ok("DrawSprite at each of the four shifts equals the decoded sprite under its mask (%s)" % ", ".join(shown), all_ok)
	t.ok("the four shifted copies of a sprite have widths w, w+1, w+1, w+1",
		lib.spritetable[1].w == lib.spritetable[0].w + 1 and lib.spritetable[3].w == lib.spritetable[0].w + 1)

	# the timer and the refresh
	var displays: Array = [0]
	lib.StartupSound()
	vm.wait_vbl(1)
	vm.on_display = func() -> void: displays[0] += 1
	var before: int = vm.now
	var tics_before: int = lib.timecount
	vm.wait_vbl(70)
	var elapsed: float = float(vm.now - before) / float(DosMachine.PIT_HZ * DosMachine.UNIT)
	t.ok("70 refreshes take 0.999 s (70.086 Hz): %.4f" % elapsed, absf(elapsed - 70.0 / 70.086) < 0.0005)
	var tics: int = lib.timecount - tics_before
	t.ok("the timer interrupt runs at 145.65 Hz: %d tics in that second" % tics, tics == 145 or tics == 146)
	t.eq("one display per refresh", displays[0], 70)

	# the speaker: a sound's tones go out one per tic
	vm.record_speaker = true
	vm.speaker_events = PackedInt64Array()
	lib.PlaySound(6)   # KEENJUMPSND
	var divisors: PackedInt32Array = data.sounds[6].divisors
	while lib.SndPtr != 0:
		vm.poll()
	var heard: PackedInt32Array = PackedInt32Array()
	for i: int in range(1, vm.speaker_events.size(), 2):
		if vm.speaker_events[i] != 0:
			heard.append(vm.speaker_events[i])
	var want_tones: PackedInt32Array = PackedInt32Array()
	for d: int in divisors:
		if d != 0:
			want_tones.append(d)
	t.ok("the speaker is given the sound's tones in order, one per tic (%d tones)" % heard.size(), heard == want_tones)
	t.ok("and is quiet at the end", vm.speaker_events[vm.speaker_events.size() - 1] == 0)
	# priorities: a sound of higher priority holds against a lower one
	var hi: int = 6
	var lo: int = 1
	for i: int in range(1, data.sounds.size()):
		for j: int in range(1, data.sounds.size()):
			if data.sounds[i].priority > data.sounds[j].priority:
				hi = i
				lo = j
	lib.PlaySound(hi)
	lib.PlaySound(lo)
	t.ok("a lower-priority sound (%d) does not interrupt a higher one (%d)" % [lo, hi], lib.SndPtr >> 16 == hi)
	lib.WaitEndSound()
	t.ok("WaitEndSound returns with nothing playing", lib.SndPtr == 0)

	# the keyboard
	vm.int9 = Callable(lib, "Int9ISR")
	var at: float = vm.seconds() + 0.05
	vm.add_key(at, VortLib.KEY_A, 0.1)
	vm.advance_to(DosMachine.seconds_to_units(at + 0.02))
	t.ok("a key press sets keydown and the pending scan code", lib.keydown[VortLib.KEY_A] == 1 and lib.NBKscan == (VortLib.KEY_A | 0x80))
	t.eq("NoBiosKey(1) reports the key without taking it", lib.NoBiosKey(1), (VortLib.KEY_A << 8) | 97)
	t.eq("NoBiosKey(0) takes it", lib.NoBiosKey(0), (VortLib.KEY_A << 8) | 97)
	t.eq("after that nothing is pending", lib.NoBiosKey(1), 0)
	vm.advance_to(DosMachine.seconds_to_units(at + 0.2))
	t.ok("the release clears keydown", lib.keydown[VortLib.KEY_A] == 0)
	lib.LoadCtrls()
	var c: Dictionary = lib.ControlKBD()
	t.ok("no keys: no direction, no buttons", c.dir == VortLib.nodir and not c.button1)
	lib.keydown[0x48] = 1
	lib.keydown[0x4d] = 1
	c = lib.ControlKBD()
	t.ok("up and right together is northeast", c.dir == VortLib.northeast)
	lib.keydown.fill(0)
	# With no joystick the port's bits never fall, both counts stop at 500, and
	# since the original only treats counts OVER 500 as "none", it reads a
	# stick pushed to the lower right. The original does the same.
	t.ok("no joystick: the original's reading is south-east", lib.ControlJoystick(1).dir == VortLib.southeast)

	# the random generators from a fixed seed are repeatable
	lib.InitRnd(false)
	var a: PackedInt32Array = PackedInt32Array()
	for i: int in range(20):
		a.append(lib.Rnd(255))
	lib.InitRnd(false)
	var b: PackedInt32Array = PackedInt32Array()
	for i: int in range(20):
		b.append(lib.Rnd(255))
	t.ok("Rnd is repeatable from InitRnd(false) and within range", a == b and Array(a).max() <= 255)
	lib.InitRndT(false)
	t.eq("RndT walks the table from entry 1", lib.RndT(), 8)
	t.finish(self)


## Fill through the card in write mode 2 (the colour goes to every plane).
func _fill(card: EgaCard, x: int, y: int, w: int, h: int, colour: int) -> void:
	card.out16(EgaCard.SC_INDEX, EgaCard.SC_MAPMASK | (15 << 8))
	card.out16(EgaCard.GC_INDEX, EgaCard.GC_MODE | (2 << 8))
	card.out16(EgaCard.GC_INDEX, EgaCard.GC_BITMASK | (0xFF << 8))
	for row: int in range(y, y + h):
		for b: int in range(x >> 3, (x + w) >> 3):
			card.mem_write(row * 48 + b, colour)
	card.out16(EgaCard.GC_INDEX, EgaCard.GC_MODE | (1 << 8))


func _region_equals(pic: PackedByteArray, x: int, y: int, img: Dictionary) -> bool:
	for yy: int in range(img.h):
		for xx: int in range(img.w):
			if pic[(y + yy) * 320 + x + xx] != img.pixels[yy * img.w + xx]:
				return false
	return true
