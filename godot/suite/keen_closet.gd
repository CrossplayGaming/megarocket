# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name KeenCloset
extends RefCounted
## V15-06 Keen's Closet: the colours of Keen's helmet (and its stripe, the "trim"), shirt, pants and
## shoes, on every frame of Keen in the game, as an asset-stage filter (A18). Which pixels are which is
## worked out here at run time from the player's own sprites by rules, colour and place per frame (A12:
## nothing of the art is stored): each family of games draws Keen in a few fixed EGA colours, each
## colour a tone (light, base, shade, deep shade) of one part; a colour two parts share (Keen 1-3's
## light cyan and blue, on the shirt's edge and the pants) goes to the part its neighbours belong to;
## Dreams' pajamas (one colour top and bottom) are split at the waist (42% down them). A frame a rule cannot settle (a
## shared pixel no neighbour decides; the parts out of their top-to-bottom order, as when Keen sits
## with his feet up or climbs; pajamas half again wider than tall, Keen lying down) is listed in report(), with the reason, and coloured by
## the colour rule alone.
##
## The colours: the emulated card (and so Classic) gets each part's colour as the nearest of the 16 EGA
## colours, its tones as the EGA pairs (yellow and brown, light and dark magenta, ...); the native view
## (Enhanced) gets the colour itself, any RGB, its tones as lighter and darker shades of it (J-25 (b),
## decided 2026-10-11). Off by default; the colours are the player's, so the card's Keen changes with
## them (presentation only: no rule of play reads a sprite's pixels).

const REGIONS: PackedStringArray = ["helmet", "trim", "shirt", "pants", "shoes"]    # slot = index + 1
const LABELS: PackedStringArray = ["Helmet", "Helmet stripe", "Shirt", "Pants", "Shoes"]

## Per family: "core" colour -> [part, tone] (tone -1 light, 0 base, 1 shade, 2 deep shade); "shared"
## colour -> {part: tone}, settled by the neighbours; "split": Dreams' pajamas, the shirt's colours below
## the waist (a fraction of the pajamas' height) are the pants'.
const RULES: Dictionary = {
	"vorticons": {
		"core": {14: ["helmet", 0], 2: ["trim", 0], 13: ["shirt", 0], 5: ["shirt", 1], 9: ["pants", 0],
			12: ["shoes", 0], 4: ["shoes", 1]},
		"shared": {11: {"shirt": -1, "pants": -1}, 1: {"shirt": 1, "pants": 1}},
	},
	"galaxy": {
		"core": {14: ["helmet", 0], 2: ["trim", 0], 10: ["trim", -1], 13: ["shirt", 0], 5: ["shirt", 1],
			11: ["pants", 0], 9: ["pants", 1], 1: ["pants", 2], 4: ["shoes", 0]},
		"shared": {},
	},
	"dreams": {
		"core": {14: ["helmet", 0], 2: ["trim", 0], 10: ["trim", -1], 11: ["shirt", 0], 3: ["shirt", 1],
			13: ["shoes", 0], 5: ["shoes", 1]},
		"shared": {},
		"split": 0.42,
	},
}

## Simple mode's looks (the user, 2026-10-13): per item, a few colours that look right with Keen's own shading
## (each part's tones follow its colour, as always). The helmet's looks set its stripe too, a colour that goes
## with it. The EGA colours themselves, so Classic shows them exactly. Item -> [[name, {part: colour}]].
const SIMPLE_ITEMS: PackedStringArray = ["helmet", "shirt", "pants", "shoes"]
const SIMPLE_LABELS: PackedStringArray = ["Helmet", "Shirt", "Pants", "Shoes"]
const SIMPLE_LOOKS: Dictionary = {
	"helmet": [["Red", {"helmet": "#ff5555", "trim": "#ffffff"}], ["Blue", {"helmet": "#5555ff", "trim": "#ffff55"}],
		["Green", {"helmet": "#55ff55", "trim": "#00aa00"}], ["Sky", {"helmet": "#55ffff", "trim": "#0000aa"}],
		["Pink", {"helmet": "#ff55ff", "trim": "#ffffff"}], ["Gold", {"helmet": "#ffff55", "trim": "#aa0000"}],
		["Silver", {"helmet": "#aaaaaa", "trim": "#5555ff"}], ["Black", {"helmet": "#555555", "trim": "#ff5555"}]],
	"shirt": [["Red", {"shirt": "#aa0000"}], ["Blue", {"shirt": "#0000aa"}], ["Green", {"shirt": "#00aa00"}],
		["Teal", {"shirt": "#00aaaa"}], ["Purple", {"shirt": "#aa00aa"}], ["Orange", {"shirt": "#aa5500"}],
		["Grey", {"shirt": "#555555"}], ["White", {"shirt": "#ffffff"}]],
	"pants": [["Blue", {"pants": "#0000aa"}], ["Black", {"pants": "#555555"}], ["Brown", {"pants": "#aa5500"}],
		["Green", {"pants": "#00aa00"}], ["Red", {"pants": "#aa0000"}], ["Teal", {"pants": "#00aaaa"}],
		["Purple", {"pants": "#aa00aa"}], ["White", {"pants": "#aaaaaa"}]],
	"shoes": [["Red", {"shoes": "#aa0000"}], ["Black", {"shoes": "#555555"}], ["Brown", {"shoes": "#aa5500"}],
		["White", {"shoes": "#ffffff"}], ["Blue", {"shoes": "#0000aa"}], ["Green", {"shoes": "#00aa00"}],
		["Yellow", {"shoes": "#ffff55"}], ["Purple", {"shoes": "#aa00aa"}]],
}


## The parts an item's look sets (the helmet's: the helmet and its stripe).
static func simple_parts(item: String) -> PackedStringArray:
	return PackedStringArray(["helmet", "trim"]) if item == "helmet" else PackedStringArray([item])


## Which of an item's looks the colours wear: its index, -1 Keen's own (none of its parts coloured), -2 a
## colouring of the player's own (from Advanced).
static func simple_look(item: String, colors: Dictionary) -> int:
	var parts: PackedStringArray = simple_parts(item)
	var mine: Dictionary = {}
	for p: String in parts:
		if colors.has(p):
			mine[p] = Color.html(colors[p]).to_html(false)
	if mine.is_empty():
		return -1
	var looks: Array = SIMPLE_LOOKS[item]
	for i: int in range(looks.size()):
		var want: Dictionary = {}
		for p: String in looks[i][1]:
			want[p] = Color.html(looks[i][1][p]).to_html(false)
		if want == mine:
			return i
	return -2


## The colours with an item's look changed to look `i` (-1: Keen's own for its parts).
static func with_look(item: String, colors: Dictionary, i: int) -> Dictionary:
	var c: Dictionary = colors.duplicate()
	for p: String in simple_parts(item):
		c.erase(p)
	if i >= 0:
		var look: Dictionary = SIMPLE_LOOKS[item][i][1]
		for p: String in look:
			c[p] = look[p]
	return c


## Outfits: a colour per part ("" keeps Keen's own). The id-family homages are colours on Keen's own
## silhouette (no other game's art): the Doom marine's green armour with a dark visor tone on the
## helmet's stripe, B.J.'s olive and khaki fatigues.
const OUTFITS: Array = [
	["Keen's own", {}],
	["Space marine", {"helmet": "#4e7a27", "trim": "#1c1c1c", "shirt": "#4e7a27", "pants": "#3e6420", "shoes": "#5a3a1e"}],
	["B.J.'s fatigues", {"helmet": "#5d6532", "trim": "#c3b091", "shirt": "#6b7b3a", "pants": "#c3b091", "shoes": "#3d2b1f"}],
	["Fire", {"helmet": "#ff5555", "trim": "#ffff55", "shirt": "#aa0000", "pants": "#aa5500", "shoes": "#ffff55"}],
	["Ocean", {"helmet": "#55ffff", "trim": "#0000aa", "shirt": "#5555ff", "pants": "#00aaaa", "shoes": "#ffffff"}],
	["Midnight", {"helmet": "#555555", "trim": "#aa00aa", "shirt": "#1c1c1c", "pants": "#555555", "shoes": "#aa00aa"}],
	["Royal", {"helmet": "#ffff55", "trim": "#aa00aa", "shirt": "#aa00aa", "pants": "#ffffff", "shoes": "#ffff55"}],
]

const EGA: PackedByteArray = [0, 0, 0, 0, 0, 170, 0, 170, 0, 0, 170, 170, 170, 0, 0, 170, 0, 170, 170, 85, 0,
	170, 170, 170, 85, 85, 85, 85, 85, 255, 85, 255, 85, 85, 255, 255, 255, 85, 85, 255, 85, 255, 255, 255, 85,
	255, 255, 255]
## EGA tones: a colour's shade and light partner
const DARK: Dictionary = {9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 6, 15: 7, 7: 8, 8: 0, 0: 0}
const LIGHT: Dictionary = {1: 9, 2: 10, 3: 11, 4: 12, 5: 13, 6: 14, 7: 15, 8: 7, 0: 8}

var game: String = ""
var family: String = ""
## part -> Color (only the parts the player coloured)
var colors: Dictionary = {}
var _regions: Dictionary = {}    # key -> {codes, note} (the rule's answer for one frame)


func _init(game_id: String, part_colors: Dictionary) -> void:
	game = game_id
	family = family_of(game_id)
	for p: String in part_colors:
		if REGIONS.has(p) and Color.html_is_valid(String(part_colors[p])):
			colors[p] = Color.html(String(part_colors[p]))


static func family_of(game_id: String) -> String:
	if game_id in ["keen1", "keen2", "keen3"]:
		return "vorticons"
	if game_id == "kdreams":
		return "dreams"
	return "galaxy"


## Whether a sprite (by its stable name) is a frame of Keen.
static func is_keen(fam: String, name: String) -> bool:
	match fam:
		"vorticons":
			return (name.begins_with("KEEN") or name.begins_with("MAPKEEN")) and not name.begins_with("KEENSHOT")
		"galaxy":
			return name.begins_with("SPR_KEEN") or name.begins_with("SPR_MAPKEEN")
		"dreams":
			return name.ends_with("SPR") and name.contains("KEEN")
	return false


## The filter: Keen's frames recoloured (pixels for the card; slots for the native view), the rest as they are.
func filter(stage: AssetStage, key: int, name: String, img: Dictionary) -> Dictionary:
	if colors.is_empty() or not is_keen(family, name):
		return img
	var r: Dictionary = regions(family, img.pixels, img.opaque, int(img.w), int(img.h))
	_regions[key] = r
	var codes: PackedByteArray = r.codes
	var pixels: PackedByteArray = img.pixels.duplicate()
	var slots: PackedByteArray = PackedByteArray()
	slots.resize(codes.size())
	var any: bool = false
	for k: int in range(codes.size()):
		var code: int = codes[k]
		if code == 0:
			continue
		var slot: int = code / 40
		var part: String = REGIONS[slot - 1]
		if not colors.has(part):
			continue
		var tone: int = (code - slot * 40) / 8 - 1
		pixels[k] = ega_tone(nearest_ega(colors[part]), tone)
		slots[k] = code
		any = true
	if not any:
		return img
	for i: int in range(REGIONS.size()):
		if colors.has(REGIONS[i]):
			stage.slot_colors[i + 1] = colors[REGIONS[i]]
	var out: Dictionary = img.duplicate()
	out.pixels = pixels
	out.slots = slots
	return out


## The rule's parts for one frame: {codes (a byte a pixel: 0, or slot * 40 + (tone + 1) * 8), note ("" when
## settled, else why not)}.
static func regions(fam: String, pixels: PackedByteArray, opaque: PackedByteArray, w: int, h: int) -> Dictionary:
	var rule: Dictionary = RULES[fam]
	var core: Dictionary = rule.core
	var shared: Dictionary = rule.shared
	var n: int = w * h
	var part: PackedInt32Array = PackedInt32Array()    # slot per pixel (0 none, -1 shared and undecided)
	part.resize(n)
	var tone: PackedInt32Array = PackedInt32Array()
	tone.resize(n)
	var notes: PackedStringArray = []
	for k: int in range(n):
		if opaque[k] == 0:
			continue
		var c: int = pixels[k]
		if core.has(c):
			part[k] = REGIONS.find(core[c][0]) + 1
			tone[k] = core[c][1]
		elif shared.has(c):
			part[k] = -1
	# shared colours: the part most of the 8 neighbours already have, until nothing changes
	var changed: bool = true
	while changed:
		changed = false
		for k: int in range(n):
			if part[k] != -1:
				continue
			var votes: Dictionary = {}
			var x: int = k % w
			var y: int = k / w
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var xx: int = x + dx
					var yy: int = y + dy
					if (dx == 0 and dy == 0) or xx < 0 or yy < 0 or xx >= w or yy >= h:
						continue
					var p: int = part[yy * w + xx]
					if p > 0 and (shared[pixels[k]] as Dictionary).has(REGIONS[p - 1]):
						votes[p] = int(votes.get(p, 0)) + 1
			var best: int = 0
			var tie: bool = false
			for p: int in votes:
				if best == 0 or votes[p] > votes[best]:
					best = p
					tie = false
				elif votes[p] == votes[best]:
					tie = true
			if best > 0 and not tie:
				part[k] = best
				tone[k] = shared[pixels[k]][REGIONS[best - 1]]
				changed = true
	var undecided: int = 0
	for k: int in range(n):
		if part[k] == -1:
			part[k] = 0
			undecided += 1
	if undecided > 0:
		notes.append("%d pixels of a shared colour no neighbour settles" % undecided)
	# Dreams: the pajamas' lower part is the pants
	if rule.has("split"):
		var shirt: int = REGIONS.find("shirt") + 1
		var top: int = h
		var bot: int = -1
		var left: int = w
		var right: int = -1
		for k: int in range(n):
			if part[k] == shirt:
				top = mini(top, k / w)
				bot = maxi(bot, k / w)
				left = mini(left, k % w)
				right = maxi(right, k % w)
		if bot >= 0:
			if 2 * (right - left) > 3 * (bot - top):
				notes.append("pajamas half again wider than tall (lying down): no waist found")
			else:
				var waist: float = float(top) + float(rule.split) * float(bot - top + 1)
				var pants: int = REGIONS.find("pants") + 1
				for k: int in range(n):
					if part[k] == shirt and float(k / w) >= waist:
						part[k] = pants
	# place: the parts' middles from the top down helmet (and stripe), shirt, pants, shoes
	var sum: PackedFloat64Array = PackedFloat64Array([0, 0, 0, 0, 0, 0])
	var cnt: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	for k: int in range(n):
		var p: int = part[k]
		if p > 0:
			var g: int = 1 if p == 2 else p    # the stripe goes with the helmet
			sum[g] += float(k / w)
			cnt[g] += 1
	var last: float = -1.0
	var last_name: String = ""
	for g: int in [1, 3, 4, 5]:
		if cnt[g] == 0:
			continue
		var mid: float = sum[g] / cnt[g]
		if mid < last:
			notes.append("%s above %s (out of the top-to-bottom order)" % [REGIONS[g - 1], last_name])
		last = mid
		last_name = REGIONS[g - 1]
	var codes: PackedByteArray = PackedByteArray()
	codes.resize(n)
	for k: int in range(n):
		if part[k] > 0:
			codes[k] = part[k] * 40 + (tone[k] + 1) * 8
	return {"codes": codes, "note": "; ".join(notes)}


## The frames the rules could not settle, of those seen so far: [[name, why]].
func report(stage: AssetStage) -> Array:
	var out: Array = []
	for key: int in _regions:
		if String(_regions[key].note) != "":
			out.append([stage.name_of(key), _regions[key].note])
	return out


static func nearest_ega(c: Color) -> int:
	var best: int = 0
	var bd: float = INF
	for i: int in range(16):
		var d: float = pow(c.r * 255.0 - EGA[i * 3], 2) + pow(c.g * 255.0 - EGA[i * 3 + 1], 2) + pow(c.b * 255.0 - EGA[i * 3 + 2], 2)
		if d < bd:
			bd = d
			best = i
	return best


static func ega_color(i: int) -> Color:
	return Color8(EGA[i * 3], EGA[i * 3 + 1], EGA[i * 3 + 2])


## An EGA colour's tone: -1 its light partner, 0 itself, 1 its shade, 2 the shade's shade.
static func ega_tone(c: int, tone: int) -> int:
	if tone < 0:
		return LIGHT.get(c, 15)
	for i: int in range(tone):
		c = DARK.get(c, 8)
	return c


## The closet's filter for a game from the settings (null when it is off or colours nothing).
static func from_settings(settings: Settings, game_id: String) -> KeenCloset:
	if not bool(settings.get_value("closet_on", game_id)):
		return null
	var cl: KeenCloset = KeenCloset.new(game_id, settings.get_value("closet", game_id))
	return null if cl.colors.is_empty() else cl


## A random outfit: a colour a part, from the 16 EGA colours (Classic's set; Enhanced shows them as they are).
static func random_outfit(rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	for p: String in REGIONS:
		out[p] = "#" + ega_color(rng.randi_range(1, 15)).to_html(false)
	return out
