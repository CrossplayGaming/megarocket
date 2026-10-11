# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SCR-05: the d-pad's letters (PadTextEntry) on their own. Up from no letter starts at A and Down at Z;
## Up steps on through the digits, a space and the punctuation and round to A; a small letter steps as its
## capital; Up at the line's end adds a letter, under the cursor changes that one; Right moves past it (not
## beyond the end); Left erases the letter under the cursor and steps back, at the end the last letter; a
## line full (its own rule) takes no new letter, and a change of letter is measured without the old one.

var t: T = T.new()


func _init() -> void:
	var any: Callable = func(_s: String) -> bool: return true
	var up: int = PadTextEntry.UP
	var down: int = PadTextEntry.DOWN
	t.eq("Up from none: A", char(PadTextEntry.step(0, 1)), "A")
	t.eq("Down from none: Z", char(PadTextEntry.step(0, -1)), "Z")
	t.eq("Z, Up: 0", char(PadTextEntry.step("Z".unicode_at(0), 1)), "0")
	t.eq("9, Up: a space", char(PadTextEntry.step("9".unicode_at(0), 1)), " ")
	t.eq("the last, Up: round to A", char(PadTextEntry.step(PadTextEntry.LETTERS.unicode_at(PadTextEntry.LETTERS.length() - 1), 1)), "A")
	t.eq("A, Down: round to the last", char(PadTextEntry.step("A".unicode_at(0), -1)), PadTextEntry.LETTERS.right(1))
	t.eq("k steps as K: L", char(PadTextEntry.step("k".unicode_at(0), 1)), "L")
	t.eq("# (not listed) starts at A", char(PadTextEntry.step("#".unicode_at(0), 1)), "A")
	t.eq("Up at the end adds A under the cursor", PadTextEntry.press("KE", 2, up, any), ["KEA", 2])
	t.eq("Up under the cursor changes that letter", PadTextEntry.press("KEA", 2, up, any), ["KEB", 2])
	t.eq("Down under the cursor", PadTextEntry.press("KEB", 2, down, any), ["KEA", 2])
	t.eq("Right moves past it", PadTextEntry.press("KEA", 2, PadTextEntry.RIGHT, any), ["KEA", 3])
	t.eq("Right at the end: nothing", PadTextEntry.press("KEA", 3, PadTextEntry.RIGHT, any), ["KEA", 3])
	t.eq("Left at the end erases the last letter", PadTextEntry.press("KEEN", 4, PadTextEntry.LEFT, any), ["KEE", 3])
	t.eq("Left under the cursor erases it and steps back", PadTextEntry.press("KEEN", 3, PadTextEntry.LEFT, any), ["KEE", 2])
	t.eq("Left on the first letter erases it", PadTextEntry.press("KEEN", 0, PadTextEntry.LEFT, any), ["EEN", 0])
	t.eq("Left on an empty line: nothing", PadTextEntry.press("", 0, PadTextEntry.LEFT, any), ["", 0])
	var four: Callable = func(s: String) -> bool: return s.length() < 4
	t.eq("a full line takes no new letter", PadTextEntry.press("KEEN", 4, up, four), ["KEEN", 4])
	t.eq("but its letters still change (measured without the old one)", PadTextEntry.press("KEEN", 3, up, four), ["KEEO", 3])
	t.ok("only the d-pad's four codes are letters' (not the arrows' 0x48-0x50 or A's 0x62)",
		PadTextEntry.is_pad(0x6D) and PadTextEntry.is_pad(0x70) and not PadTextEntry.is_pad(0x48) and not PadTextEntry.is_pad(0x50)
		and not PadTextEntry.is_pad(0x62) and not PadTextEntry.is_pad(0x71))
	t.eq("the d-pad's codes are the pad's own (ControlsModel.PAD_MOVE)", [PadTextEntry.UP, PadTextEntry.DOWN, PadTextEntry.LEFT, PadTextEntry.RIGHT],
		[ControlsModel.PAD_MOVE.up, ControlsModel.PAD_MOVE.down, ControlsModel.PAD_MOVE.left, ControlsModel.PAD_MOVE.right])
	t.finish(self)
