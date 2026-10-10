# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CTRL-02: the three engines' control readers with the player's bindings (ControlsModel.table()). Keys
## held in each engine's own key array, read through ControlPlayer (Keen 1-3), IN_ReadControls (Keen 4-6)
## and IN_ReadControl (Dreams): the directions, Jump, Pogo and Fire as the bindings say, the pad's and the
## touch screen's codes counted, a key taken away doing nothing; Keen 4-6's Fire the fire button, or jump
## and pogo with TWO-BUTTON FIRING; Dreams' throw Fire's and Pogo's. With no bindings, the original's keys.

var t: T = T.new()


func _init() -> void:
	var path: String = OS.get_temp_dir().path_join("mr_ctrl02_%d.cfg" % Time.get_ticks_usec())
	var m: ControlsModel = ControlsModel.new(Settings.new(path))
	m.bind("keys", "jump", KEY_Q, 0)
	m.clear("keys", "pogo")
	m.bind("keys", "pogo", KEY_W, 0)
	var table: Dictionary = m.table()
	var sc: Dictionary = ControlsModel.SCANCODES
	var pad: Dictionary = ControlsModel.PAD_CODES

	# Keen 1-3
	var v: VortKeen1 = VortKeen1.new()
	v.vm = DosMachine.new()
	v.keydown.resize(128)
	v.playermode[1] = VortLib.keyboard    # the control panel's defaults: Ctrl and Alt
	v.keyB1 = 0x1D
	v.keyB2 = 0x38
	var vhold: Callable = func(codes: Array) -> Dictionary:
		v.keydown.fill(0)
		for c: int in codes:
			v.keydown[c] = 1
		return v.ControlPlayer(1)
	t.ok("Keen 1, no bindings: Ctrl is the original's button 1", vhold.call([0x1D]).button1)
	v.shell_controls = table
	v.shell_one_fire = true
	t.ok("Keen 1: Q (Jump) is button 1 (%s)" % vhold.call([sc[KEY_Q]]), vhold.call([sc[KEY_Q]]) == {"dir": VortLib.nodir, "button1": true, "button2": false})
	t.ok("Ctrl, still Jump's second key, too", vhold.call([0x1D]).button1)
	t.ok("Alt, taken from Pogo, nothing", not vhold.call([0x38]).button2)
	t.ok("Space (Fire): both buttons", vhold.call([0x39]) == {"dir": VortLib.nodir, "button1": true, "button2": true})
	t.ok("the pad's X (Fire) and the touch screen's Fire: both buttons", vhold.call([pad[JOY_BUTTON_X]]).button2 and vhold.call([0x73]).button1)
	t.ok("up and right together: north-east", vhold.call([0x48, 0x4D]).dir == VortLib.northeast)
	t.ok("the d-pad's left: west", vhold.call([0x6F]).dir == VortLib.west)
	t.ok("the original's PgUp (its north-east key): nothing", vhold.call([0x49]).dir == VortLib.nodir)
	v.shell_one_fire = false
	t.ok("Two keys: Fire's Space fires nothing", not vhold.call([0x39]).button1)

	# Keen 4-6
	var g: GalGame = load("res://games/galaxy/gal_keen4.gd").new()
	g.vm = DosMachine.new()
	g.in_keyStates.resize(256)
	var f: GalIO.IN_ControlFrame = GalIO.IN_ControlFrame.new()
	var ghold: Callable = func(codes: Array) -> Array:
		g.in_keyStates.fill(0)
		for c: int in codes:
			g.in_keyStates[c] = 1
		g.IN_ReadControls(0, f)
		return [f.xDirection, f.yDirection, f.jump, f.pogo, f.button2]
	g.shell_controls = table
	g.ck_twoButtonFiring = false
	t.eq("Keen 4: W (Pogo)", ghold.call([sc[KEY_W]]), [0, 0, false, true, false])
	t.eq("Space (Fire): the fire button", ghold.call([0x39]), [0, 0, false, false, true])
	t.eq("the pad's A and the left arrow: jump, left", ghold.call([pad[JOY_BUTTON_A], 0x4B]), [-1, 0, true, false, false])
	g.ck_twoButtonFiring = true
	t.eq("TWO-BUTTON FIRING: Fire is jump and pogo together", ghold.call([0x39]), [0, 0, true, true, false])
	t.ok("the status key: Enter's (the pad's Y too)", g.shell_held("status") == false and (func() -> bool:
		g.in_keyStates[0x1C] = 1
		return g.shell_held("status")).call())

	# Dreams
	var d: DreamsGame = DreamsGame.new()
	d.vm = DosMachine.new()
	d.Keyboard.resize(128)
	var info: DrmDecl.CursorInfo = DrmDecl.CursorInfo.new()
	var dhold: Callable = func(codes: Array) -> Array:
		d.Keyboard.fill(false)
		for c: int in codes:
			d.Keyboard[c] = true
		d.IN_ReadControl(0, info)
		return [info.xaxis, info.yaxis, info.button0, info.button1]
	d.shell_controls = table
	t.eq("Dreams: Q (Jump) is button 0", dhold.call([sc[KEY_Q]]), [0, 0, true, false])
	t.eq("Space (Fire) throws", dhold.call([0x39]), [0, 0, false, true])
	t.eq("W (Pogo) throws too, as the original's second button", dhold.call([sc[KEY_W]]), [0, 0, false, true])
	t.eq("down and right", dhold.call([0x50, 0x4D]), [1, 1, false, false])
	DirAccess.remove_absolute(path)
	t.finish(self)
