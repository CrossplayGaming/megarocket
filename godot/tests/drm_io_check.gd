# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01c: the Dreams input and sound managers (DrmIO) on the emulated machine: the timer
## SD_Startup programs and the TimeCount it counts, keys through the keyboard interrupt,
## IN_ReadControl from the keyboard and from a demo, PC speaker and AdLib sound effects.
##
## Options: --game_data=<folder> (the sounds come from its kdreams folder)

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	var d: DreamsData = DreamsData.new()
	if not d.load_game(root.path_join("kdreams")):
		t.blocked("Keen Dreams does not load: %s" % d.error)
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var g: DreamsGame = DreamsGame.new()
	g.vm = vm
	g.data = d
	g.current_gamever_int = 100

	_timer(g, vm)
	_keys(g, vm)
	_demo(g)
	_sounds(g, vm)
	t.ok("the engine did not quit (%s)" % g.quit_message, not g.quitting)

	g.SD_Shutdown()
	g.IN_Shutdown()
	t.ok("SD_Shutdown gives the timer back (18.2 Hz, no handler)", vm.pit0_reload == 0x10000 and not vm.int8.is_valid())
	t.finish(self)


## SD_Startup: timer 0 at 1192755 / 140 (TickBase * t0CountTable[sdm_Off]); TimeCount counts
## every second interrupt, the first one included (the ISR's count starts at 1).
func _timer(g: DreamsGame, vm: DosMachine) -> void:
	g.SD_Startup()
	t.eq("SD_Startup programs timer 0 to 1192755/140", vm.pit0_reload, 1192755 / 140)
	t.ok("the timer interrupt is installed, the AdLib found", vm.int8.is_valid() and g.AdLibPresent)
	var start: int = vm.now
	var ticks0: int = vm.tick_count
	var end: int = start + DosMachine.seconds_to_units(10.0)
	vm.advance_to(end)
	var ints: int = vm.tick_count - ticks0
	var want_ints: int = (end - start) / (vm.pit0_reload * DosMachine.UNIT)
	t.eq("10 s of machine time: %d timer interrupts" % ints, ints, want_ints)
	t.eq("TimeCount after 10 s (70 Hz)", g.SD_GetTimeCount(), (want_ints + 1) / 2)
	print("  timer: %d interrupts, TimeCount %d in 10 s" % [ints, g.SD_GetTimeCount()])
	var src: int = g.SD_GetTimeCount()
	g.SD_TimeCountWaitFromSrc(src, 5)
	t.eq("SD_TimeCountWaitFromSrc waits 5 tics", g.SD_GetTimeCount() - src, 5)
	g.SD_SetTimeCount(0)
	t.eq("SD_SetTimeCount", g.SD_GetTimeCount(), 0)
	g.SD_AddToTimeCount(-1)
	t.eq("SD_AddToTimeCount wraps as a longword", g.SD_GetTimeCount(), 0xFFFFFFFF)
	g.SD_SetTimeCount(100)


## Keys from the keyboard script reach Keyboard[], LastScan and LastASCII through INT 9;
## IN_ReadControl reads the arrows.
func _keys(g: DreamsGame, vm: DosMachine) -> void:
	g.IN_Startup()
	g.IN_Default(false, g.ctrl_Keyboard1)
	t.ok("IN_Startup: keyboard interrupt in, no mouse or joysticks",
		vm.int9.is_valid() and not g.MousePresent and not g.JoysPresent[0] and not g.JoysPresent[1])
	var info: DrmDecl.CursorInfo = DrmDecl.CursorInfo.new()
	var s: float = vm.seconds()
	vm.add_key(s + 0.05, g.sc_RightArrow, 0.2)
	vm.advance_to(DosMachine.seconds_to_units(s + 0.1))
	t.ok("right arrow down: Keyboard[sc_RightArrow], LastScan", g.Keyboard[g.sc_RightArrow] and g.LastScan == g.sc_RightArrow)
	g.IN_ReadControl(0, info)
	t.ok("IN_ReadControl, right: xaxis %d yaxis %d x %d dir %d" % [info.xaxis, info.yaxis, info.x, info.dir],
		info.xaxis == g.motion_Right and info.yaxis == g.motion_None and info.x == 127 and info.y == 0 and info.dir == g.dir_East
		and not info.button0)
	vm.add_key(s + 0.15, g.sc_UpArrow, 0.05)
	vm.add_key(s + 0.15, g.sc_Control, 0.05)
	vm.advance_to(DosMachine.seconds_to_units(s + 0.17))
	g.IN_ReadControl(0, info)
	t.ok("IN_ReadControl, up+right+Ctrl: xaxis %d yaxis %d dir %d button0 %s" % [info.xaxis, info.yaxis, info.dir, info.button0],
		info.xaxis == g.motion_Right and info.yaxis == g.motion_Up and info.y == -127 and info.dir == g.dir_NorthEast
		and info.button0 and not info.button1)
	vm.advance_to(DosMachine.seconds_to_units(s + 0.4))
	t.ok("keys released", not g.Keyboard[g.sc_RightArrow] and not g.Keyboard[g.sc_UpArrow])
	g.IN_ReadControl(0, info)
	t.ok("IN_ReadControl, nothing: dir_None", info.xaxis == 0 and info.yaxis == 0 and info.dir == g.dir_None)
	# ASCII: a, then shifted A
	vm.add_key(s + 0.45, g.sc_A, 0.05)
	vm.advance_to(DosMachine.seconds_to_units(s + 0.5))
	t.eq("LastASCII of A unshifted", g.LastASCII, 97)
	vm.add_key(s + 0.55, g.sc_LShift, 0.2)
	vm.add_key(s + 0.6, g.sc_A, 0.05)
	vm.advance_to(DosMachine.seconds_to_units(s + 0.8))
	t.eq("LastASCII of A shifted", g.LastASCII, 65)
	t.eq("IN_GetScanName", [g.IN_GetScanName(g.sc_Control), g.IN_GetScanName(g.sc_A)], ["Ctrl", "A"])
	# IN_WaitForKey runs the machine until a key comes
	g.LastScan = 0
	vm.add_key(vm.seconds() + 0.3, g.sc_Space, 0.05)
	var t0: float = vm.seconds()
	var k: int = g.IN_WaitForKey()
	t.ok("IN_WaitForKey returns Space after %.3f s" % (vm.seconds() - t0), k == g.sc_Space and g.LastScan == 0)
	g.IN_ClearKeysDown()


## A hand-made demo: (count, control byte) pairs, each control lasting count + 1 frames (the
## count is tested before it is decremented). The C reads the axes into dx, dy but leaves
## realdelta false (ReflectionHLE initialises it; the original left it unset), so dx = mx * 127
## throws them away: playback gives the buttons, and no motion.
func _demo(g: DreamsGame) -> void:
	# button0 + right (0x19) 3 frames, button1 + up (0x24) 1 frame, nothing (0x05) 2 frames
	var buf: PackedByteArray = PackedByteArray([2, 0x19, 0, 0x24, 1, 0x05])
	g.IN_StartDemoPlayback(buf, buf.size())
	var want: Array = [[true, false], [true, false], [true, false], [false, true], [false, false], [false, false]]
	var got: Array = []
	var motion: bool = false
	var info: DrmDecl.CursorInfo = DrmDecl.CursorInfo.new()
	for i: int in range(want.size()):
		g.IN_ReadControl(0, info)
		got.append([info.button0, info.button1])
		motion = motion or info.xaxis != 0 or info.yaxis != 0 or info.dir != g.dir_None
	t.eq("demo playback frame by frame (buttons)", got, want)
	t.ok("demo playback: no motion (realdelta false, as the C)", not motion)
	t.eq("the demo ends after its last frame", g.DemoMode, g.demo_PlayDone)
	g.IN_StopDemo()


## Sound effects: a PC speaker effect plays one sample per timer interrupt for its length, then
## SD_SoundPlaying goes back to 0; an AdLib effect the same through the OPL hook.
func _sounds(g: DreamsGame, vm: DosMachine) -> void:
	g.MM_Startup()
	g.CAL_SetupAudioFile()
	t.ok("SD_SetSoundMode(sdm_PC)", g.SD_SetSoundMode(g.sdm_PC))
	g.CA_LoadAllSounds()
	t.eq("PC mode: timer still at 140 Hz", vm.pit0_reload, 1192755 / 140)
	var n: int = -1
	for i: int in range(g.NUMSOUNDS):
		var a: Variant = g.audiosegs[g.STARTPCSOUNDS + i]
		if a != null and a.size() > 6 and DreamsData.u32(a, 0) >= 10:
			n = i
			break
	if not t.ok("a PC sound to play", n >= 0):
		return
	var snd: PackedByteArray = g.audiosegs[g.STARTPCSOUNDS + n]
	var length: int = DreamsData.u32(snd, 0)
	vm.record_speaker = true
	vm.speaker_events = PackedInt64Array()
	g.SD_PlaySound(n)
	t.eq("SD_SoundPlaying right after SD_PlaySound(%d)" % n, g.SD_SoundPlaying(), n)
	var ints: int = 0
	while g.SD_SoundPlaying() != 0 and ints < length + 100:
		vm.advance_to(vm.next_tick)
		ints += 1
	t.eq("PC sound %d plays %d interrupts (its length)" % [n, ints], ints, length)
	t.eq("SD_SoundPlaying back to 0", g.SD_SoundPlaying(), 0)
	# the speaker: the first sample's tone (sample * 60) first, off at the end
	var first: int = -1
	for i: int in range(6, 6 + length):
		if snd[i] != 0:
			first = snd[i] * 60
			break
	var ev: PackedInt64Array = vm.speaker_events
	var tone: int = -1
	for i: int in range(1, ev.size(), 2):
		if ev[i] != 0:
			tone = ev[i]
			break
	t.ok("speaker: first tone %d (want %d), %d changes, off at the end" % [tone, first, ev.size() / 2],
		ev.size() >= 4 and tone == first and ev[ev.size() - 1] == 0 and (vm.port61 & 3) != 3)
	vm.record_speaker = false
	# SD_WaitSoundDone runs the machine to the end of the sound
	var tick0: int = vm.tick_count
	g.SD_PlaySound(n)
	g.SD_WaitSoundDone()
	t.eq("SD_WaitSoundDone returns after the sound's length", vm.tick_count - tick0, length)

	# AdLib: through the OPL hook
	var writes: Array = []
	g.sd_alOutHook = func(r: int, v: int) -> void: writes.append([r, v])
	t.ok("SD_SetSoundMode(sdm_AdLib)", g.SD_SetSoundMode(g.sdm_AdLib))
	g.CA_LoadAllSounds()
	var al: PackedByteArray = g.audiosegs[g.STARTADLIBSOUNDS + n] if g.audiosegs[g.STARTADLIBSOUNDS + n] != null else PackedByteArray()
	if not t.ok("an AdLib sound %d to play" % n, al.size() > 23):
		return
	var allen: int = DreamsData.u32(al, 0)
	writes.clear()
	g.SD_PlaySound(n)
	t.ok("AdLib instrument written (%d writes, first %s)" % [writes.size(), str(writes[0]) if writes.size() > 0 else ""],
		writes.size() == 11 and writes[0] == [g.alFreqH, 0] and writes[1] == [g.alChar, al[6]])
	ints = 0
	while g.SD_SoundPlaying() != 0 and ints < allen + 100:
		vm.advance_to(vm.next_tick)
		ints += 1
	t.eq("AdLib sound %d plays %d interrupts (its length)" % [n, ints], ints, allen)
	t.ok("AdLib note off at the end", writes.size() > 11 and writes[writes.size() - 1] == [g.alFreqH, 0])
	g.sd_alOutHook = Callable()
