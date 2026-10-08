# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-G-01c (part 1): the Galaxy timer, sound and input layer on the emulated
## machine. SD_Startup programs the timer to 140 Hz and the tic count rises 70
## a second; with AdLib music the timer runs at 560 Hz and the count still
## rises 70 a second. A PC speaker effect reaches the speaker ports note for
## note (frequency byte x 60 as the divisor), one note per 140 Hz interrupt,
## and finishes; an AdLib effect writes its instrument and then one note per
## interrupt. Keys delivered through the keyboard interrupt set the key states,
## the last scan code and the ASCII the tables give (shifted too), and read as
## controls. Every demo of the episode plays back frame for frame as its bytes
## say and ends in the play-done state; controls recorded play back the same.
##
## Options: --game_data=<folder>  --games=keen4,keen5,keen6

const GAMES: Dictionary = {"keen4": "keen4", "keen5": "keen5", "keen6": "keen6e14"}
const EP: Dictionary = {"keen4": 1, "keen5": 2, "keen6": 3}


func _init() -> void:
	var t: T = T.new()
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	for game: String in str(opts.get("games", "keen4")).split(",", false):
		_game(t, root, game)
	t.finish(self)


func run_seconds(vm: DosMachine, s: float) -> void:
	vm.advance_to(vm.now + DosMachine.seconds_to_units(s))


func _game(t: T, root: String, game: String) -> void:
	var d: GalData = GalData.new()
	if not t.ok("%s: files load (%s)" % [game, d.error], d.load_game(root.path_join(game), "res://data/omnispeak".path_join(GAMES[game]))):
		return
	var vm: DosMachine = DosMachine.new()
	var g: GalIO = GalIO.new()
	g.vm = vm
	g.data = d
	g.ck_currentEpisode_ep = EP[game]
	g.CA_Startup()
	g.VL_Startup()
	g.SD_Startup()
	g.IN_Startup()

	# ---- the timer
	t.ok("%s: SD_Startup programs the timer for 140 Hz (divisor %d)" % [game, vm.pit0_reload], vm.pit0_reload == 1192030 / 140)
	var c0: int = g.SD_GetTimeCount()
	var k0: int = vm.tick_count
	run_seconds(vm, 10.0)
	var tics: int = g.SD_GetTimeCount() - c0
	var ints: int = vm.tick_count - k0
	# the machine's clock is 1193182 Hz; the game divides 1192030, so 140.1 Hz
	t.ok("%s: in 10 s the timer interrupts %d times and the tic count rises %d (70 a second)" % [game, ints, tics],
		absi(ints - 10 * DosMachine.PIT_HZ / vm.pit0_reload) <= 1 and absi(tics - 700) <= 1)
	g.SD_SetMusicMode(GalIO.smm_AdLib)
	var fast: int = vm.pit0_reload
	c0 = g.SD_GetTimeCount()
	k0 = vm.tick_count
	run_seconds(vm, 10.0)
	tics = g.SD_GetTimeCount() - c0
	ints = vm.tick_count - k0
	t.ok("%s: with AdLib music the timer runs at 560 Hz (divisor %d, %d interrupts in 10 s) and the count still rises %d" % [game, fast, ints, tics],
		fast == 1192030 / 560 and absi(ints - 10 * DosMachine.PIT_HZ / fast) <= 1 and absi(tics - 700) <= 1)
	g.SD_SetMusicMode(GalIO.smm_Off)
	t.ok("%s: music off puts the timer back to 140 Hz" % game, vm.pit0_reload == 1192030 / 140)

	# ---- a PC speaker effect: the first sound with more than one note
	g.SD_SetSoundMode(GalIO.sdm_PC)
	g.CA_LoadAllSounds()
	var aud: Dictionary = d.aud
	var snd: int = -1
	var chunk: PackedByteArray
	for i: int in range(int(aud.numSounds)):
		var c: Variant = g.CA_audio[int(aud.startPCSounds) + i]
		if c == null:
			continue
		var notes: Dictionary = {}
		for k: int in range(GalData.u32(c, 0)):
			notes[c[6 + k]] = true
		if notes.size() >= 3:
			snd = i
			chunk = c
			break
	if t.ok("%s: a PC speaker sound with several notes is cached (sound %d)" % [game, snd], snd >= 0):
		var length: int = GalData.u32(chunk, 0)
		# what the speaker should do: each change of frequency byte, at its interrupt
		var want: Array = []
		var last: int = 255
		for k: int in range(length):
			var f: int = chunk[6 + k]
			if f != last:
				last = f
				want.append([k, f * 60 if f != 0 else 0])
		if last != 0:
			want.append([length - 1, 0])
		vm.record_speaker = true
		vm.speaker_events = PackedInt64Array()
		# start just after an interrupt, as the game's loop would
		vm.advance_to(vm.next_tick)
		var t_start: int = vm.next_tick
		g.SD_PlaySound(snd)
		var playing: bool = g.SD_SoundPlaying() == snd
		run_seconds(vm, float(length) / 140.0 + 0.1)
		var got: Array = []
		for e: int in range(0, vm.speaker_events.size(), 2):
			var at: int = vm.speaker_events[e]
			var idx: int = int(round(float(at - t_start) / float(vm.pit0_reload * DosMachine.UNIT)))
			var v: int = int(vm.speaker_events[e + 1])
			# loading the divisor while the speaker is off changes nothing audible
			if v == 0 and (got.is_empty() or got[-1][1] == 0):
				continue
			got.append([idx, v])
		# a repeated "off" (the effect's end after a silent last note) leaves no event
		var same: bool = got == want or (got.size() == want.size() - 1 and got == want.slice(0, want.size() - 1))
		t.ok("%s: PC sound %d (%d interrupts) reaches the speaker note for note at 140 Hz (%d changes; first %s, want %s)" %
			[game, snd, length, got.size(), got.slice(0, 4), want.slice(0, 4)], playing and same)
		t.ok("%s: the PC sound finishes (playing now %d)" % [game, g.SD_SoundPlaying()], g.SD_SoundPlaying() == 0 and (vm.port61 & 3) != 3)
		vm.record_speaker = false

	# ---- an AdLib effect
	var regs: Array = []
	g.sd_alOutHook = func(r: int, v: int) -> void:
		regs.append([r, v])
	g.SD_SetSoundMode(GalIO.sdm_AdLib)
	g.CA_LoadAllSounds()
	var al: Variant = g.CA_audio[int(aud.startAdlibSounds) + 1]
	if t.ok("%s: AdLib sound 1 is cached" % game, al != null):
		regs.clear()
		g.SD_PlaySound(1)
		var inst: Array = regs.slice(1, 11)    # after the stop's note-off
		var wl: int = GalData.u32(al, 0)
		run_seconds(vm, float(wl) / 140.0 + 0.1)
		var notes: Array = regs.slice(11)
		var want_inst: Array = [[0x20, al[6]], [0x40, al[8]], [0x60, al[10]], [0x80, al[12]], [0xe0, al[14]],
			[0x23, al[7]], [0x43, al[9]], [0x63, al[11]], [0x83, al[13]], [0xe3, al[15]]]
		var hi: int = ((al[22] & 7) << 2) | 0x20
		var want_notes: Array = []
		for k: int in range(wl):
			var f: int = al[23 + k]
			if f == 0:
				want_notes.append([0xb0, 0])
			else:
				want_notes.append([0xa0, f])
				want_notes.append([0xb0, hi])
		want_notes.append([0xb0, 0])
		t.ok("%s: AdLib sound 1 writes its instrument then %d notes, one per interrupt, and ends (%d writes)" % [game, wl, notes.size()],
			regs[0] == [0xb0, 0] and inst == want_inst and notes == want_notes and g.SD_SoundPlaying() == 0)
	g.SD_SetSoundMode(GalIO.sdm_Off)
	g.sd_alOutHook = Callable()

	# ---- keys through the keyboard interrupt
	var at: float = vm.seconds() + 0.05
	vm.add_key(at, GalIO.IN_SC_LeftArrow, 0.2)
	vm.add_key(at + 0.05, GalIO.IN_SC_Control, 0.1)
	vm.add_key(at + 0.5, GalIO.IN_SC_A, 0.05)
	vm.add_key(at + 0.7, GalIO.IN_SC_LeftShift, 0.2)
	vm.add_key(at + 0.75, GalIO.IN_SC_A, 0.05)
	run_seconds(vm, 0.1 + 0.01)
	var ctl: GalIO.IN_ControlFrame = GalIO.IN_ControlFrame.new()
	g.IN_ReadControls(0, ctl)
	t.ok("%s: Left and Ctrl held read as left and jump (x %d, y %d, jump %s, dir %d), last scan Ctrl" %
		[game, ctl.xDirection, ctl.yDirection, ctl.jump, ctl.dir],
		ctl.xDirection == -1 and ctl.yDirection == 0 and ctl.jump and not ctl.pogo and ctl.dir == GalIO.IN_dir_West and g.IN_GetLastScan() == GalIO.IN_SC_Control)
	run_seconds(vm, 0.2)
	g.IN_ReadControls(0, ctl)
	t.ok("%s: released, the controls are idle" % game, ctl.xDirection == 0 and not ctl.jump and ctl.dir == GalIO.IN_dir_None)
	run_seconds(vm, 0.3)
	var a1: int = g.IN_GetLastASCII()
	run_seconds(vm, 0.25)
	var a2: int = g.IN_GetLastASCII()
	t.ok("%s: A gives ASCII %d, and with Shift held %d" % [game, a1, a2], a1 == 97 and a2 == 65 and not g.IN_GetKeyState(GalIO.IN_SC_A))
	g.IN_ClearKeysDown()
	t.ok("%s: IN_ClearKeysDown forgets the last scan and ASCII" % game, g.IN_GetLastScan() == 0 and g.IN_GetLastASCII() == 0)

	# ---- demos: each plays back as its bytes say, then reports play-done
	var demostart: int = d.chunk_names.get_int("DEMOSTART")
	var played: int = 0
	var bad: int = 0
	for n: int in range(4):
		g.CA_CacheGrChunk(demostart + n)
		var buf: Variant = g.ca_graphChunks[demostart + n]
		if buf == null:
			continue
		var demo: PackedByteArray = (buf as PackedByteArray).duplicate()
		var demo_len: int = GalData.u16(demo, 2)
		var expect: Array = []
		for p: int in range(4, 4 + demo_len, 2):
			for k: int in range(demo[p]):
				expect.append(demo[p + 1])
		g.IN_DemoStartPlaying(demo, 4, demo_len)
		var frames: int = 0
		while g.IN_DemoGetMode() == GalIO.IN_Demo_Playback and frames < 100000:
			g.IN_ReadControls(0, ctl)
			var b: int = expect[frames] if frames < expect.size() else -1
			if b < 0 or ctl.yDirection != (b & 3) - 1 or ctl.xDirection != ((b >> 2) & 3) - 1 or \
					ctl.jump != (((b >> 4) & 1) != 0) or ctl.pogo != (((b >> 5) & 1) != 0):
				bad += 1
			frames += 1
		if frames != expect.size() or g.IN_DemoGetMode() != GalIO.IN_Demo_PlayDone:
			bad += 1
		g.IN_DemoStopPlaying()
		played += 1
	t.ok("%s: %d demos play back frame for frame and end in play-done (%d wrong)" % [game, played, bad], played >= 1 and bad == 0)

	# ---- recording: a scripted run of controls records and plays back the same
	var script: Array = []
	for k: int in range(600):
		script.append([[0, 0], [-1, 0], [1, 0], [0, 1], [0, -1], [-1, 1]][(k / 37) % 6] + [(k / 11) % 3 == 0, (k / 23) % 4 == 1])
	g.IN_DemoStartRecording(4096)
	var keys: Dictionary = g.in_kbdControls
	for s: Array in script:
		g.in_keyStates.fill(0)
		if s[0] == -1: g.in_keyStates[keys.left] = 1
		if s[0] == 1: g.in_keyStates[keys.right] = 1
		if s[1] == -1: g.in_keyStates[keys.up] = 1
		if s[1] == 1: g.in_keyStates[keys.down] = 1
		if s[2]: g.in_keyStates[keys.jump] = 1
		if s[3]: g.in_keyStates[keys.pogo] = 1
		g.IN_ReadControls(0, ctl)
	g.IN_DemoStopPlaying()
	var recorded: int = g.in_demoPtr
	g.in_keyStates.fill(0)
	g.IN_DemoStartPlaying(g.in_demoBuf.duplicate(), 0, recorded)
	bad = 0
	var n_played: int = 0
	while g.IN_DemoGetMode() == GalIO.IN_Demo_Playback and n_played < script.size() + 10:
		g.IN_ReadControls(0, ctl)
		var s: Array = script[n_played] if n_played < script.size() else [9, 9, false, false]
		if ctl.xDirection != s[0] or ctl.yDirection != s[1] or ctl.jump != s[2] or ctl.pogo != s[3]:
			bad += 1
		n_played += 1
	t.ok("%s: 600 recorded control frames (%d bytes) play back the same (%d frames, %d differ)" % [game, recorded, n_played, bad],
		n_played == script.size() and bad == 0)
	g.IN_DemoStopPlaying()

	t.ok("%s: no quit (%s)" % [game, g.quit_message], not g.quitting)
	g.SD_Shutdown()
	vm.int9 = Callable()
