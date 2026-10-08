# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-V-02 "every level runs": each level of the given Vorticons episodes
## played for a stretch of game time with scripted running, jumping, pogoing
## and shooting, then the world map, the status and ordering screens and the
## episode's ending, each until a time limit. A level's creatures are reached
## by name at run time, so this is what shows a misspelt routine or a script
## error in an episode's actor code. It does not judge behaviour: that is the
## oracle's job (REPLAY-V1..3).
##
## Options: --game_data=<folder> --games=keen1,keen2,keen3 --seconds=12
##          --shots=<folder>: also save each stage's picture 5 s in, as PNG

var t: T = T.new()
var shots: String = ""

const KEY_CTRL: int = 29
const KEY_ALT: int = 56
const KEY_RIGHT: int = 77
const KEY_LEFT: int = 75
const KEY_UP: int = 72
const KEY_DOWN: int = 80
const KEY_ENTER: int = 28
const KEY_SPACE: int = 57


var only_levels: Array[int] = []

func _init() -> void:
	var opts: Dictionary = T.options()
	var root: String = opts.get("game_data", "")
	var seconds: float = float(opts.get("seconds", "12"))
	for v: String in str(opts.get("levels", "")).split(",", false):    # only these levels (diagnosis)
		only_levels.append(int(v))
	shots = str(opts.get("shots", ""))
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	for game: String in str(opts.get("games", "keen1,keen2,keen3")).split(",", false):
		_episode(root, game, seconds)
	t.finish(self)


func _episode(root: String, game: String, seconds: float) -> void:
	var data: VortData = VortData.new()
	if not data.load_game(root.path_join(game), "CK" + game.substr(4, 1)):
		t.blocked("%s data: %s" % [game, data.error])
		return
	var vm: DosMachine = DosMachine.new()
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = vm
	g.data = data
	g.save_dir = OS.get_temp_dir().path_join("mr_vort_levels_%d" % Time.get_ticks_usec())
	var displays: Array = [0]
	var pictures: Dictionary = {}
	var shot_at: Array = [-1, ""]    # the display to save, and its file name
	vm.on_display = func() -> void:
		displays[0] += 1
		if displays[0] == shot_at[0] and shots != "" and vm.card.video_mode == EgaCard.MODE_EGA:
			var img: Image = Image.create_from_data(320, 200, false, Image.FORMAT_RGB8, vm.card.frame_rgb())
			img.save_png(shots.path_join(shot_at[1]))
		if displays[0] % 8 == 0 and vm.card.video_mode == EgaCard.MODE_EGA:
			pictures[hash(vm.card.frame_pixels)] = true
	vm.on_limit = func() -> void:
		g.exited = true
	var report: Array = []
	g.after_startup = func() -> void:
		var stage: Array = [0]
		var run: Callable = func(label: String, what: Callable) -> void:
			# a fresh stretch of game time, the scripted input timed from its start
			stage[0] += 1
			var mark: String = "stage%d" % stage[0]
			print("  %s stage %d: %s (wall %d ms)" % [game, stage[0], label, Time.get_ticks_msec()])    # where a hang is
			_script_keys(vm, mark, seconds)
			vm.mark(mark)
			vm.time_limit = vm.now + DosMachine.seconds_to_units(seconds)
			vm.limit_fired = false
			g.exited = false
			var d0: int = displays[0]
			var p0: int = pictures.size()
			shot_at[0] = d0 + 350
			shot_at[1] = "%s_%02d_%s.png" % [game, stage[0], label.replace(" ", "_")]
			what.call()
			report.append([label, displays[0] - d0, pictures.size() - p0])
		# the texts the demo loop would have prepared
		g.helptextPtr = g.PrepareText(data.help_text)
		g.storytxtPtr = g.PrepareText(data.story_text)
		g.endtextPtr = g.PrepareText(data.end_text)
		g.previewsPtr = g.PrepareText(data.previews_text)
		g.gamestate.lives = 9
		g.gamestate.gotPogo = true
		for n: int in range(1, 17):
			if not FileAccess.file_exists(data.dir.path_join(("LEVEL%02d." % n) + data.ext)):
				continue
			if only_levels.size() > 0 and not only_levels.has(n):
				continue
			run.call("level %d" % n, func() -> void:
				g.gamestate.ammo = 99
				g.LevelLoop(n))
		run.call("world map", func() -> void:
			g.gamestate.ammo = 99
			g.restoredGame = false
			g.WorldMap())
		run.call("status screen", func() -> void: g.ShowStatusScreen())
		run.call("ordering screen", func() -> void: g.ShowOrderingScreen(true))
		run.call("ending", func() -> void: g.DoFinale())
		if game == "keen2":
			run.call("the Earth explodes", func() -> void: g.TheEarthExplodes())
	g.main()
	for r: Array in report:
		print("  %s %-18s %5d displays %4d pictures" % [game, r[0], r[1], r[2]])
		t.ok("%s %s: ran to its time limit drawing %d displays, %d distinct sampled pictures" % [game, r[0], r[1], r[2]],
			r[1] > 0 and r[2] > 1)
	vm.int8 = Callable()
	vm.int9 = Callable()
	vm.on_display = Callable()
	vm.on_limit = Callable()
	g.after_startup = Callable()
	g.vm = null


## Run right, then left, jumping, pogoing and firing (both buttons) as it
## goes; an Enter and a Space now and then answer the episode's windows.
func _script_keys(vm: DosMachine, mark: String, seconds: float) -> void:
	var half: float = seconds / 2.0
	vm.add_key_after(mark, 0.5, KEY_RIGHT, half - 0.5)
	vm.add_key_after(mark, half, KEY_LEFT, half - 0.5)
	var at: float = 0.7
	var k: int = 0
	while at < seconds - 0.3:
		match k % 4:
			0, 2:
				vm.add_key_after(mark, at, KEY_CTRL, 0.25)
			1:
				vm.add_key_after(mark, at, KEY_ALT, 0.4)
			3:
				vm.add_key_after(mark, at, KEY_CTRL, 0.2)
				vm.add_key_after(mark, at, KEY_ALT, 0.2)
		if k % 5 == 4:
			vm.add_key_after(mark, at + 0.1, KEY_ENTER, 0.1)
		if k % 7 == 6:
			vm.add_key_after(mark, at + 0.15, KEY_DOWN, 0.2)
		at += 0.45
		k += 1
