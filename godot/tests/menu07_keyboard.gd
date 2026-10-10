# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## MENU-07 (Keen 1-3): the original's Keyboard Commands window (CalibrateKeys) can be left. As in the C's
## do-while, a key that is not a digit closes it; a digit, then a key, moves that action first. Before the
## fix the window's loop never ended (the player was stuck in it): this test then never finishes, which the
## runner's time limit reports.
##
## Options: --game_data=<folder>

var t: T = T.new()


func _init() -> void:
	var root: String = T.options().get("game_data", "")
	if root == "":
		t.blocked("need --game_data")
		t.finish(self)
		return
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join("keen1"), "CK1"):
		t.blocked("keen1: " + data.error)
		t.finish(self)
		return
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen1.new()
	g.vm = vm
	g.data = data
	g.apply_dosbox_timing({})
	g.videocard = g.VideoID()
	g._load_tileinfo()
	g.LoadGraphics()
	g.LoadCtrls()
	vm.int9 = Callable(g, "Int9ISR")    # (main() installs the keyboard handler)
	vm.card.bios_set_video_mode(0x0D)
	# Escape at once: the window closes with nothing changed
	var b1: int = g.keyB1
	vm.add_key(vm.seconds() + 0.2, 0x01, 0.1)
	g.CalibrateKeys()
	t.ok("Escape closes Keyboard Commands", true)
	t.eq("nothing changed", g.keyB1, b1)
	# 8 (button1), then Z: button1 is Z; then Escape closes it
	var at: float = vm.seconds()
	vm.add_key(at + 0.2, 0x09, 0.1)     # '8'
	vm.add_key(at + 0.6, 0x2C, 0.1)     # Z
	vm.add_key(at + 1.2, 0x01, 0.1)     # Escape
	g.CalibrateKeys()
	t.eq("8 then Z moves button1 (jump) to Z, and Escape still closes it", g.keyB1, 0x2C)
	t.finish(self)
