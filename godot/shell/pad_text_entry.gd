# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name PadTextEntry
extends RefCounted
## SCR-05: a line typed with the d-pad, in the games' own line input (Keen 4-6's and Keen Dreams'
## US_LineInput: a saved game's name, a high score's, Keen 6's creature answer), with a player at the
## controls. While a line is typed the host sends the d-pad (and the left stick) as the pad's own codes
## (ControlsModel.PAD_MOVE), which no key sends: Up and Down step the letter under the cursor through
## LETTERS (a new letter at the line's end), Right moves past it, Left erases it (at the end, the last
## one). A is Enter and accepts, B is Escape, as the original's; the keyboard types as it always did.

## The d-pad's codes (ControlsModel.PAD_MOVE's).
const UP: int = 0x6D
const DOWN: int = 0x6E
const LEFT: int = 0x6F
const RIGHT: int = 0x70
## What Up steps through, in order (Down the other way, round from A to the last): the capitals, the
## digits, a space and a little punctuation.
const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .-!?"


## One of the d-pad's codes (a line is being typed).
static func is_pad(sc: int) -> bool:
	return sc >= UP and sc <= RIGHT


## The letter after `c` in LETTERS (dir 1) or before it (-1); a small letter steps as its capital. No
## letter (0), or one not in the list, starts it: A going up, Z going down.
static func step(c: int, dir: int) -> int:
	var at: int = LETTERS.find(char(c).to_upper()) if c != 0 else -1
	if at < 0:
		return LETTERS.unicode_at(0 if dir > 0 else 25)
	return LETTERS.unicode_at(posmod(at + dir, LETTERS.length()))


## A d-pad press on the line `s`, its cursor at `cursor`: [the line, the cursor]. `fits(t)`: whether a
## letter may go into the line `t` (the line's own rule for a typed one, its length and width), asked of
## the line without the letter a press changes.
static func press(s: String, cursor: int, sc: int, fits: Callable) -> Array:
	match sc:
		UP, DOWN:
			var dir: int = 1 if sc == UP else -1
			if cursor < s.length():
				if fits.call(s.substr(0, cursor) + s.substr(cursor + 1)):
					s = s.substr(0, cursor) + char(step(s.unicode_at(cursor), dir)) + s.substr(cursor + 1)
			elif fits.call(s):
				s += char(step(0, dir))
		RIGHT:
			if cursor < s.length():
				cursor += 1
		LEFT:
			if cursor < s.length():
				s = s.substr(0, cursor) + s.substr(cursor + 1)
				cursor = maxi(cursor - 1, 0)
			elif cursor > 0:
				s = s.substr(0, cursor - 1)
				cursor -= 1
	return [s, cursor]
