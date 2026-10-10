# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name KeenLevel
extends RefCounted
## One level of any Keen engine as an editor works with it: a size, its
## planes of 16-bit words (one word per 16x16 cell, row by row), a name, and
## the header values its format carries. The engine's own reader and writer
## (VortLevels for Keen 1-3, TedMaps for Keen 4-6 and Dreams) turn files into
## these and back.
##
## Planes by engine, in file order:
##   Vorticons: 0 tiles (what is drawn and what is solid), 1 sprites (where
##              Keen, the creatures and the world-map level entries start).
##   Galaxy and Dreams: 0 background, 1 foreground (drawn over the
##              background, with its own tile properties), 2 info (Keen's
##              start, creatures, switch targets, points of interest).

const VORTICONS: String = "vorticons"
const GALAXY: String = "galaxy"
const DREAMS: String = "dreams"

const PLANE_NAMES: Dictionary = {
	VORTICONS: ["tiles", "sprites"],
	GALAXY: ["background", "foreground", "info"],
	DREAMS: ["background", "foreground", "info"],
}

## KeenLevel.VORTICONS, GALAXY or DREAMS.
var engine: String = ""
## Vorticons: the NN of LEVELNN.CKn. Galaxy and Dreams: the map's slot (0-99).
var number: int = -1
## The name the map header carries (Galaxy and Dreams; Vorticons levels have none).
var name: String = ""
var width: int = 0
var height: int = 0
var planes: Array[PackedInt32Array] = []
## Header values the format carries beyond the size and name, by name
## (Vorticons: screenx, screeny, screenw, screenh, left from the map editor
## id used and read by nothing in the game).
var fields: Dictionary = {}
## Bytes a file carried that mean nothing to the game, kept so a level saved
## unchanged is the very file it came from: the editor tools of the day left
## whatever was in memory there. Writers use them only where they still fit
## (same size, same name) and write zeros otherwise. Keys:
##   "header" (Vorticons): the 32-byte expanded header as read.
##   "plane_tails" (Vorticons): per plane, the bytes after width x height
##       words up to the 16-byte-rounded plane size.
##   "name_field" (Galaxy, Dreams): the 16-byte name with what follows its NUL.
##   "after" (Galaxy, Dreams): the bytes between this map's header and the
##       next map (Galaxy's "!ID!").
var keep: Dictionary = {}


## A new, empty level (every word 0) of `w` x `h` cells for `engine_name`.
static func create(engine_name: String, w: int, h: int, level_name: String = "") -> KeenLevel:
	var level: KeenLevel = KeenLevel.new()
	level.engine = engine_name
	level.name = level_name
	level.width = w
	level.height = h
	for p: int in range(PLANE_NAMES.get(engine_name, []).size()):
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(w * h)
		level.planes.append(words)
	return level


func plane_count() -> int:
	return planes.size()


func plane_names() -> Array:
	return PLANE_NAMES.get(engine, [])


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## The word at cell (x, y) of `plane`; -1 outside the level.
func get_word(plane: int, x: int, y: int) -> int:
	if plane < 0 or plane >= planes.size() or not in_bounds(x, y):
		return -1
	return planes[plane][y * width + x]


## Set the word at cell (x, y) of `plane`; false (and nothing changed) outside the level.
func set_word(plane: int, x: int, y: int, value: int) -> bool:
	if plane < 0 or plane >= planes.size() or not in_bounds(x, y):
		return false
	planes[plane][y * width + x] = value & 0xFFFF
	return true


## Change the size, keeping what lies inside both sizes at the same cells and
## filling new cells with 0. Kept bytes tied to the old size are dropped.
func resize(w: int, h: int) -> void:
	for p: int in range(planes.size()):
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(w * h)
		for y: int in range(mini(h, height)):
			for x: int in range(mini(w, width)):
				words[y * w + x] = planes[p][y * width + x]
		planes[p] = words
	width = w
	height = h
	keep.erase("plane_tails")


## A copy that shares nothing with this one.
func copy() -> KeenLevel:
	var level: KeenLevel = KeenLevel.new()
	level.engine = engine
	level.number = number
	level.name = name
	level.width = width
	level.height = height
	for words: PackedInt32Array in planes:
		level.planes.append(words.duplicate())
	level.fields = fields.duplicate(true)
	level.keep = keep.duplicate(true)
	return level


## "" when `other` has the same size and planes, else the first difference.
func plane_difference(other: KeenLevel) -> String:
	if other == null:
		return "no level"
	if other.width != width or other.height != height:
		return "size %dx%d, not %dx%d" % [other.width, other.height, width, height]
	if other.planes.size() != planes.size():
		return "%d planes, not %d" % [other.planes.size(), planes.size()]
	for p: int in range(planes.size()):
		if other.planes[p] != planes[p]:
			for i: int in range(planes[p].size()):
				if other.planes[p][i] != planes[p][i]:
					return "plane %d cell (%d, %d) is %04x, not %04x" % [p, i % width, i / width, other.planes[p][i], planes[p][i]]
	return ""
