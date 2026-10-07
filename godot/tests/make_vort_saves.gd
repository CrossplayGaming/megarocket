# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## Writes, for each level of a Vorticons episode, a saved game (the
## original's 88-byte SAVED?.CKn) of a new game with Keen standing on that
## level's entrance on the world map: the start of a recorded level session
## (Continue Game, 1, then Ctrl on the map). Nothing of the game's files is
## in a save; it is the game state only.
##
## Options: --game_data=<folder> --game=keen1 --out=<folder>  (writes <out>/levelNN/SAVED1.CKn)

var t: T = T.new()


func _init() -> void:
	var opts: Dictionary = T.options()
	var game: String = opts.get("game", "keen1")
	var out: String = opts.get("out", "")
	var data: VortData = VortData.new()
	if not data.load_game(str(opts.get("game_data", "")).path_join(game), "CK" + game.substr(4, 1)):
		t.blocked(data.error)
		t.finish(self)
		return
	var g: VortActs = VortKeen3.new() if game == "keen3" else (VortKeen2.new() if game == "keen2" else VortKeen1.new())
	g.vm = DosMachine.new()
	g.data = data
	g.ReadLevel(g.WORLDMAP)
	g.ScanWorldMap()
	var written: int = 0
	for n: int in range(1, g.NUMLEVELS + 1):
		var e: Array = g.entrances[n - 1]
		if e[0] == 0:
			continue
		var s: VortMain.GameState = VortMain.GameState.new()
		s.lives = 4
		s.ammo = 0 if game == "keen1" else (3 if game == "keen2" else 5)
		s.gotPogo = game != "keen1"
		s.worldx = g.TILE_TO_GLOBAL(e[0])
		s.worldy = g.TILE_TO_GLOBAL(e[1])
		s.worldoriginx = clampi(s.worldx - 9 * g.TILEGLOBAL, g.originxmin, g.originxmax)
		s.worldoriginy = clampi(s.worldy - 3 * g.TILEGLOBAL, g.originymin, g.originymax)
		var dir: String = out.path_join("level%02d" % n)
		DirAccess.make_dir_recursive_absolute(dir)
		var f: FileAccess = FileAccess.open(dir.path_join("SAVED1." + data.ext), FileAccess.WRITE)
		f.store_buffer(s.to_bytes())
		f.close()
		written += 1
		print("  level %d: entrance at tile %d,%d" % [n, e[0], e[1]])
	t.ok("%d saves written" % written, written > 0)
	t.finish(self)
