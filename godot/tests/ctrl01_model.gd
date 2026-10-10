# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## CTRL-01: the controls model. The defaults; a key given to one action is taken from another; two at
## most; the fixed keys and buttons refused; clear and reset; the bindings kept in the settings file; the
## games' table (keys' scan codes, the pad's codes, the d-pad in the directions); Dreams' rows.

var t: T = T.new()


func _init() -> void:
	var path: String = OS.get_temp_dir().path_join("mr_ctrl01_%d.cfg" % Time.get_ticks_usec())
	var m: ControlsModel = ControlsModel.new(Settings.new(path))
	t.eq("the defaults: Jump is Ctrl and Z", m.keys("jump"), [KEY_CTRL, KEY_Z])
	t.eq("shown as the screens show it", m.shown("keys", "jump"), "Ctrl, Z")
	t.eq("the pad's Fire: X and the right trigger", m.shown("pad", "fire"), "X, RT")
	t.eq("Z first for Jump: Z, then Ctrl", [m.bind("keys", "jump", KEY_Z, 0), m.keys("jump")], ["", [KEY_Z, KEY_CTRL]])
	t.eq("Alt as Jump's second: taken from Pogo", [m.bind("keys", "jump", KEY_ALT, 1), m.keys("jump"), m.keys("pogo")],
		["pogo", [KEY_Z, KEY_ALT], [KEY_X]])
	t.eq("a third key for an action pushes the last out", [m.bind("keys", "jump", KEY_Q, 0), m.keys("jump")], ["", [KEY_Q, KEY_Z]])
	t.eq("Escape and the function keys stay the games' own", [m.bind("keys", "fire", KEY_ESCAPE, 0), m.bind("keys", "fire", KEY_F5, 0), m.keys("fire")],
		["!", "!", [KEY_SPACE, KEY_SHIFT]])
	t.eq("Start and the d-pad stay the pad's own", m.bind("pad", "jump", JOY_BUTTON_START, 0), "!")
	m.clear("keys", "fire")
	t.eq("a cleared action reads none, its keys gone (the pad's X and RT and the touch screen's Fire kept)",
		[m.shown("keys", "fire"), Array(m.table()["fire"])], ["none", [0x62, 0x67, 0x72]])
	var tb: Dictionary = m.table()
	t.ok("the table: Up is the up arrow and the d-pad's up (%s)" % tb["up"], Array(tb["up"]) == [0x48, 0x6B])
	t.ok("Jump: Q and Z, the pad's A, the touch screen's Jump (%s)" % tb["jump"], Array(tb["jump"]) == [0x10, 0x2C, 0x60, 0x70])
	var again: ControlsModel = ControlsModel.new(Settings.new(path))
	t.eq("kept in the settings file", [again.keys("jump"), again.keys("fire"), again.keys("pogo")], [[KEY_Q, KEY_Z], [], [KEY_X]])
	m.bind("pad", "status", JOY_BUTTON_A, 0)
	m.reset("keys")
	t.eq("reset the keyboard: its defaults back, the pad's choice kept", [m.keys("jump"), m.keys("fire"), m.buttons("status"), m.buttons("jump")],
		[[KEY_CTRL, KEY_Z], [KEY_SPACE, KEY_SHIFT], [JOY_BUTTON_A, JOY_BUTTON_Y], []])
	m.reset()
	t.eq("reset both", m.buttons("jump"), [JOY_BUTTON_A])
	var labels: Array = m.rows("keys", "dreams").map(func(r: Dictionary) -> String: return r.label)
	t.eq("Dreams' keyboard rows: no Pogo, Fire is its throw", labels, ["Up", "Down", "Left", "Right", "Jump", "Throw", "Status"])
	t.eq("Keen 4's pad rows", m.rows("pad", "galaxy").map(func(r: Dictionary) -> String: return r.key), ["jump", "pogo", "fire", "status", "quicksave", "quickload"])
	DirAccess.remove_absolute(path)
	t.finish(self)
