# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name ClosetPage
extends PanelContainer
## V15-06 Keen's Closet, a page of the launcher (the user, 2026-10-11: the suite's pages open from the
## main screen, in the same window, and Back returns there). Per game the player owns: a colour for
## Keen's helmet, its stripe, shirt, pants and shoes (Keen's own, one of the 16 EGA colours, more shades,
## or any colour with the picker), outfits (the id-family homages among them) and a random one, and
## whether he wears it in the game. Keen is previewed running, jumping and pogoing (Dreams: throwing),
## drawn from the player's own files with KeenCloset's rules. The page's own look is the launcher's
## (original art in EGA colours); every control is a button, so the keys, a pad and the mouse all work.
## Classic shows each colour as the nearest EGA colour (J-25 (b)); the preview shows the game's view.

signal closed

## The preview's frames per family: [caption, [names]]
const PREVIEW: Dictionary = {
	"vorticons": [["Running", ["KEENWALKR1SPR", "KEENWALKR2SPR", "KEENWALKR3SPR", "KEENWALKR4SPR"]],
		["Jumping", ["KEENJUMPR1SPR", "KEENJUMPR2SPR", "KEENJUMPR3SPR", "KEENJUMPR4SPR", "KEENJUMPR5SPR", "KEENJUMPR6SPR"]],
		["Pogoing", ["KEENPOGOR1SPR", "KEENPOGOR2SPR"]]],
	"galaxy": [["Running", ["SPR_KEENRUNR1", "SPR_KEENRUNR2", "SPR_KEENRUNR3", "SPR_KEENRUNR4"]],
		["Jumping", ["SPR_KEENJUMPR1", "SPR_KEENJUMPR2", "SPR_KEENJUMPR3"]],
		["Pogoing", ["SPR_KEENPOGOR1", "SPR_KEENPOGOR2"]]],
	"dreams": [["Running", ["KEENRUNR1SPR", "KEENRUNR2SPR", "KEENRUNR3SPR", "KEENRUNR4SPR"]],
		["Jumping", ["KEENJUMPR1SPR", "KEENJUMPR2SPR", "KEENJUMPR3SPR"]],
		["Throwing", ["KEENTHROWR1SPR", "KEENTHROWR2SPR", "KEENTHROWR3SPR"]]],
}

var settings: Settings = null
var found: Dictionary = {}        # game id -> the finder's result, for the games the player owns
var titles: Dictionary = {}       # game id -> its title
var game: String = ""
var pixel: int = 1
var choices: Array[Color] = []    # what ◄ ► step through (after Keen's own)

var title_label: Label
var wear: CheckButton
var outfit_label: Label
var outfit_index: int = 0
var swatches: Dictionary = {}     # part -> ColorRect
var swatch_names: Dictionary = {} # part -> Label
var pickers: Dictionary = {}      # part -> ColorPickerButton
var previews: Array = []          # [TextureRect, [frame imgs], caption]
var report_label: Label
var report_text: RichTextLabel
var view_note: Label
var back_button: Button
var first_button: Button
var _frames: Dictionary = {}      # name -> {w, h, pixels, opaque} (the player's own, unchanged)
var _report: Array = []
var _tick: int = 0
var _timer: Timer


func _init() -> void:
	name = "ClosetPage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i: int in range(16):
		choices.append(KeenCloset.ega_color(i))
	# more shades for Enhanced: twelve hues, each light, bright, deep and dark
	for h: int in range(12):
		for sv: Array in [[0.45, 1.0], [0.85, 1.0], [0.9, 0.7], [0.9, 0.42]]:
			choices.append(Color.from_hsv(float(h) / 12.0, sv[0], sv[1]))


## The page for `settings`, the games found (id -> result), their titles, starting on `first`.
func open(s: Settings, found_games: Dictionary, game_titles: Dictionary, first: String, px: int) -> void:
	settings = s
	found = found_games
	titles = game_titles
	pixel = maxi(px, 1)
	_build()
	_show_game(first if found.has(first) else (found.keys()[0] if not found.is_empty() else ""))
	first_button.grab_focus()


func _build() -> void:
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	add_child(m)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	m.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	# the game
	var top: HBoxContainer = HBoxContainer.new()
	first_button = _button(top, "PrevGame", "<", func() -> void: _step_game(-1))
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_color_override("font_color", MegaTheme.ega(14))
	top.add_child(title_label)
	_button(top, "NextGame", ">", func() -> void: _step_game(1))
	col.add_child(top)
	# the preview
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Preview"
	row.add_theme_constant_override("separation", 24)
	for i: int in range(3):
		var box: VBoxContainer = VBoxContainer.new()
		var tr: TextureRect = TextureRect.new()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(24, 32) * 4 * pixel / 2
		box.add_child(tr)
		var cap: Label = Label.new()
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_color", MegaTheme.ega(7))
		box.add_child(cap)
		row.add_child(box)
		previews.append([tr, [], cap])
	col.add_child(row)
	wear = CheckButton.new()
	wear.name = "Wear"
	wear.text = "Keen wears it in the game"
	wear.toggled.connect(func(on: bool) -> void:
		settings.set_value("closet_on", on, game)
		settings.save())
	col.add_child(wear)
	# outfits
	var orow: HBoxContainer = HBoxContainer.new()
	orow.name = "Outfits"
	var cap2: Label = Label.new()
	cap2.text = "Outfit:"
	orow.add_child(cap2)
	_button(orow, "PrevOutfit", "<", func() -> void: _step_outfit(-1))
	outfit_label = Label.new()
	outfit_label.custom_minimum_size.x = 120 * pixel
	outfit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orow.add_child(outfit_label)
	_button(orow, "NextOutfit", ">", func() -> void: _step_outfit(1))
	_button(orow, "Random", "Random", _random)
	col.add_child(orow)
	# the parts
	for i: int in range(KeenCloset.REGIONS.size()):
		var part: String = KeenCloset.REGIONS[i]
		var pr: HBoxContainer = HBoxContainer.new()
		pr.name = "Part_" + part
		var l: Label = Label.new()
		l.text = KeenCloset.LABELS[i]
		l.custom_minimum_size.x = 80 * pixel
		pr.add_child(l)
		_button(pr, "Prev", "<", func() -> void: _step_color(part, -1))
		var sw: ColorRect = ColorRect.new()
		sw.custom_minimum_size = Vector2(14, 10) * pixel
		pr.add_child(sw)
		swatches[part] = sw
		_button(pr, "Next", ">", func() -> void: _step_color(part, 1))
		var nm: Label = Label.new()
		nm.custom_minimum_size.x = 70 * pixel
		pr.add_child(nm)
		swatch_names[part] = nm
		var pick: ColorPickerButton = ColorPickerButton.new()
		pick.name = "Any"
		pick.text = "Any colour"
		pick.edit_alpha = false
		pick.color_changed.connect(func(c: Color) -> void: _set_color(part, "#" + c.to_html(false)))
		pr.add_child(pick)
		pickers[part] = pick
		_button(pr, "Own", "Keen's own", func() -> void: _set_color(part, ""))
		col.add_child(pr)
	view_note = Label.new()
	view_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_note.add_theme_color_override("font_color", MegaTheme.ega(11))
	col.add_child(view_note)
	var rrow: HBoxContainer = HBoxContainer.new()
	report_label = Label.new()
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(report_label)
	_button(rrow, "ListFrames", "List them", func() -> void: report_text.visible = not report_text.visible)
	col.add_child(rrow)
	report_text = RichTextLabel.new()
	report_text.name = "Report"
	report_text.fit_content = true
	report_text.visible = false
	col.add_child(report_text)
	back_button = _button(col, "Back", "Back", func() -> void: closed.emit())
	_timer = Timer.new()
	_timer.wait_time = 0.15
	_timer.timeout.connect(_animate)
	add_child(_timer)
	_timer.start()


func _button(parent: Control, n: String, text: String, f: Callable) -> Button:
	var b: Button = Button.new()
	b.name = n
	b.text = text
	b.pressed.connect(f)
	parent.add_child(b)
	return b


func _step_game(d: int) -> void:
	var ids: Array = []
	for g: String in titles:
		if found.has(g):
			ids.append(g)
	if ids.is_empty():
		return
	_show_game(ids[(ids.find(game) + d + ids.size()) % ids.size()])


## A game's closet: its frames from the player's files, its colours from the settings.
func _show_game(id: String) -> void:
	game = id
	_frames = {}
	_report = []
	if id == "":
		title_label.text = "Keen's Closet: no game found yet (add your games on the main screen)"
		return
	title_label.text = "Keen's Closet: " + String(titles.get(id, id))
	var d: Object = AssetPacks.load_data(found[id])
	var fam: String = KeenCloset.family_of(id)
	if d != null:
		var st: AssetStage = d.stage
		for e: Array in AssetPacks.sprites_of(d):
			var nm: String = st.name_of(int(e[0]))
			if KeenCloset.is_keen(fam, nm) and not (e[1] as Dictionary).is_empty():
				_frames[nm] = e[1]
				var r: Dictionary = KeenCloset.regions(fam, e[1].pixels, e[1].opaque, int(e[1].w), int(e[1].h))
				if String(r.note) != "":
					_report.append([nm, r.note])
	var lines: PackedStringArray = []
	for e: Array in _report:
		lines.append("%s: %s" % [e[0], e[1]])
	report_label.text = "%d frames of Keen; %d the rules could not settle by colour and place (coloured by colour alone; a hand fix comes with the Asset Studio)." % [_frames.size(), _report.size()]
	report_text.text = "\n".join(lines)
	wear.set_pressed_no_signal(bool(settings.get_value("closet_on", id)))
	var classic: bool = String(settings.get_value("view", id)) == "classic"
	view_note.text = ("Classic shows each colour as the nearest of the 16 EGA colours, as the preview does." if classic
		else "Enhanced shows any colour as chosen; Classic and the 320x200 picture use the nearest of the 16 EGA colours.")
	for i: int in range(3):
		var spec: Array = PREVIEW[fam][i]
		previews[i][2].text = spec[0]
	_refresh()


func _colors() -> Dictionary:
	return settings.get_value("closet", game) if game != "" else {}


func _set_colors(c: Dictionary) -> void:
	if game == "":
		return
	settings.set_value("closet", c, game)
	settings.save()
	_refresh()


func _set_color(part: String, html: String) -> void:
	var c: Dictionary = _colors()
	if html == "":
		c.erase(part)
	else:
		c[part] = html
	_set_colors(c)


func _step_color(part: String, d: int) -> void:
	var c: Dictionary = _colors()
	var classic: bool = String(settings.get_value("view", game)) == "classic"
	var n: int = 16 if classic else choices.size()
	var at: int = -1    # Keen's own
	if c.has(part):
		var now: Color = Color.html(c[part])
		for i: int in range(n):
			if choices[i].to_html(false) == now.to_html(false):
				at = i
	at += d
	if at >= n:
		at = -1
	elif at < -1:
		at = n - 1
	_set_color(part, "" if at < 0 else "#" + choices[at].to_html(false))


func _step_outfit(d: int) -> void:
	outfit_index = (outfit_index + d + KeenCloset.OUTFITS.size()) % KeenCloset.OUTFITS.size()
	_set_colors((KeenCloset.OUTFITS[outfit_index][1] as Dictionary).duplicate())


func _random() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	outfit_index = 0
	_set_colors(KeenCloset.random_outfit(rng))


## The swatches, the outfit's name and the preview's frames for the colours now.
func _refresh() -> void:
	var c: Dictionary = _colors()
	outfit_label.text = String(KeenCloset.OUTFITS[outfit_index][0]) if c == KeenCloset.OUTFITS[outfit_index][1] else "Your own"
	for part: String in KeenCloset.REGIONS:
		var has: bool = c.has(part)
		(swatches[part] as ColorRect).color = Color.html(c[part]) if has else Color(0, 0, 0, 0)
		(swatch_names[part] as Label).text = String(c[part]) if has else "Keen's own"
		(pickers[part] as ColorPickerButton).color = Color.html(c[part]) if has else Color.WHITE
	if game == "":
		return
	var fam: String = KeenCloset.family_of(game)
	var classic: bool = String(settings.get_value("view", game)) == "classic"
	var cl: KeenCloset = KeenCloset.new(game, c)
	for i: int in range(3):
		var frames: Array = []
		for nm: String in PREVIEW[fam][i][1]:
			if _frames.has(nm):
				frames.append(_picture(fam, cl, _frames[nm], classic))
		previews[i][1] = frames
	_animate()


## One frame as the game would show it: the closet's parts in the colours (Classic: the EGA tones; else
## the colour in the native view's shades), the rest in its EGA colours.
static func _picture(fam: String, cl: KeenCloset, f: Dictionary, classic: bool) -> ImageTexture:
	var w: int = int(f.w)
	var h: int = int(f.h)
	var codes: PackedByteArray = KeenCloset.regions(fam, f.pixels, f.opaque, w, h).codes
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for k: int in range(w * h):
		if f.opaque[k] == 0:
			continue
		var col: Color = KeenCloset.ega_color(f.pixels[k])
		var code: int = codes[k]
		if code != 0:
			var slot: int = code / 40
			var part: String = KeenCloset.REGIONS[slot - 1]
			if cl.colors.has(part):
				var tone: int = (code - slot * 40) / 8 - 1
				var s: Color = cl.colors[part]
				if classic:
					col = KeenCloset.ega_color(KeenCloset.ega_tone(KeenCloset.nearest_ega(s), tone))
				else:
					col = s.lerp(Color.WHITE, 0.4) if tone < 0 else s * ([1.0, 0.62, 0.4][tone])
					col.a = 1.0
		img.set_pixel(k % w, k / w, col)
	return ImageTexture.create_from_image(img)


func _animate() -> void:
	_tick += 1
	for p: Array in previews:
		var frames: Array = p[1]
		(p[0] as TextureRect).texture = frames[_tick % frames.size()] if not frames.is_empty() else null
