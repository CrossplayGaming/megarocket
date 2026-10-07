# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## HARN-13a, DATA-02 and SHELL-03: detection fixtures built in a temporary
## folder from the development copies (fake Steam libraries with the real
## layout and Steam's mixed-case names, fake GOG registry entries, loose
## folders, a ZIP, planted wrong files, a CGA rename, a read-only tree), and
## the finder's answers over them. The real Steam install, if there is one,
## is scanned as well.
##
## Options: --game_data=<folder>

var t: T = T.new()
var game_root: String = ""
var tmp: String = ""
var finder: GameFinder = GameFinder.new()


func _init() -> void:
	game_root = T.options().get("game_data", "")
	if game_root == "":
		t.blocked("no --game_data folder given")
		t.finish(self)
		return
	tmp = OS.get_temp_dir().path_join("mr_detect_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	_fixtures_and_identification()
	_checksums()
	_steam()
	_gog()
	_folders_and_zip()
	_read_only()
	_real_machine()
	_remove_tree(tmp)
	t.finish(self)


# ---------------------------------------------------------------- helpers

func copy_game(id: String, to: String, rename: Dictionary = {}, skip: PackedStringArray = PackedStringArray()) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var src: String = game_root.path_join(id)
	var d: DirAccess = DirAccess.open(src)
	for f: String in d.get_files():
		if skip.has(f.to_upper()) or f.to_upper() == "6KEEN14.EXE":
			continue
		var name: String = rename.get(f.to_upper(), f)
		d.copy(src.path_join(f), to.path_join(name))


func write_file(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _remove_tree(path: String) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		FileAccess.set_read_only_attribute(path.path_join(f), false)
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in d.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func by_id(found: Array, id: String) -> Dictionary:
	for r: Dictionary in found:
		if r.id == id:
			return r
	return {}


static func ids(found: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Dictionary in found:
		out.append(r.id + ":" + r.status)
	out.sort()
	return out


# --------------------------------------------------- DATA-02: identification

func _fixtures_and_identification() -> void:
	# One folder per game, as the development copies are.
	var all: String = tmp.path_join("all")
	for id: String in ["keen1", "keen2", "keen3", "keen4", "keen5", "keen6", "kdreams"]:
		copy_game(id, all.path_join(id))
	var found: Array = finder.scan_folder(all)
	t.eq("all seven identify in their own folders", ids(found),
		PackedStringArray(["kdreams:ok", "keen1:ok", "keen2:ok", "keen3:ok", "keen4:ok", "keen5:ok", "keen6:ok"]))
	var versions: PackedStringArray = PackedStringArray()
	for id: String in ["keen1", "keen4", "keen6", "kdreams"]:
		versions.append(by_id(found, id).get("version", ""))
	t.eq("versions named", versions, PackedStringArray(["v1.31 EGA (Steam)", "v1.4 EGA (Steam)", "v1.0 EGA", "v1.00 EGA (registered)"]))
	t.ok("the executable is named with its actual name", by_id(found, "keen6").exe == "KEEN6C.EXE" and by_id(found, "keen4").exe.to_upper() == "KEEN4E.EXE")
	# Seven games in one folder together still identify (a dumped tree).
	var mixed: String = tmp.path_join("mixed")
	for id: String in ["keen1", "keen4", "kdreams"]:
		copy_game(id, mixed)
	t.eq("three games sharing one folder identify", ids(finder.identify(mixed)), PackedStringArray(["kdreams:ok", "keen1:ok", "keen4:ok"]))
	# Planted damage (the fixture's self-test): one byte changed in Keen 4's
	# graphics, Keen 1's executable cut in half.
	var wrong4: String = tmp.path_join("wrong4")
	copy_game("keen4", wrong4)
	var g: PackedByteArray = FileAccess.get_file_as_bytes(wrong4.path_join("EGAGRAPH.CK4"))
	g[1000] ^= 0x01
	write_file(wrong4.path_join("EGAGRAPH.CK4"), g)
	var r: Dictionary = by_id(finder.identify(wrong4), "keen4")
	t.ok("a Keen 4 with one byte changed is unrecognised and names the file (%s)" % r.get("message", ""),
		r.get("status", "") == GameFinder.STATUS_UNRECOGNISED and r.message.contains("EGAGRAPH.CK4 differs") and r.message.contains("Megarocket reads"))
	var wrong1: String = tmp.path_join("wrong1")
	copy_game("keen1", wrong1)
	var e: PackedByteArray = FileAccess.get_file_as_bytes(wrong1.path_join("KEEN1.EXE"))
	write_file(wrong1.path_join("KEEN1.EXE"), e.slice(0, e.size() / 2))
	r = by_id(finder.identify(wrong1), "keen1")
	t.ok("a Keen 1 with a truncated executable is unrecognised and names it (%s)" % r.get("message", ""),
		r.get("status", "") == GameFinder.STATUS_UNRECOGNISED and r.message.contains("KEEN1.EXE differs"))
	# A missing file.
	var missing: String = tmp.path_join("missing")
	copy_game("keen5", missing, {}, PackedStringArray(["AUDIO.CK5"]))
	r = by_id(finder.identify(missing), "keen5")
	t.ok("a Keen 5 without its AUDIO is unrecognised and says so (%s)" % r.get("message", ""),
		r.get("status", "") == GameFinder.STATUS_UNRECOGNISED and r.message.contains("AUDIO.CK5 missing"))
	# The CGA release: KEEN5C.EXE with CGAGRAPH.CK5.
	var cga: String = tmp.path_join("cga5")
	copy_game("keen5", cga, {"KEEN5E.EXE": "KEEN5C.EXE", "EGAGRAPH.CK5": "CGAGRAPH.CK5"})
	r = by_id(finder.identify(cga), "keen5")
	t.ok("a CGA Keen 5 is named as the CGA release with the remedy (%s)" % r.get("message", ""),
		r.get("status", "") == GameFinder.STATUS_UNRECOGNISED and r.message.contains("CGA release") and r.message.contains("Megarocket reads"))
	# Keen 6 v1.0's KEEN6C.EXE is EGA and supported: not taken for CGA.
	t.ok("Keen 6's KEEN6C.EXE is not mistaken for a CGA release", by_id(found, "keen6").status == GameFinder.STATUS_OK)
	# A folder with nothing of Keen in it.
	var other: String = tmp.path_join("other")
	write_file(other.path_join("README.TXT"), "hello".to_utf8_buffer())
	write_file(other.path_join("DUKE2.EXE"), PackedByteArray([0x4D, 0x5A, 0, 0]))
	t.ok("a folder without Keen files finds nothing", finder.identify(other).is_empty())
	# Keen Dreams' other releases are recognised by CRC-32 and named as
	# unsupported: the table entry is exercised with a file of known CRC.
	var dreams_other: String = tmp.path_join("dreams_other")
	var fake: PackedByteArray = PackedByteArray()
	for i: int in range(5000):
		fake.append((i * 7) & 0xFF)
	write_file(dreams_other.path_join("KDREAMS.EXE"), fake)
	write_file(dreams_other.path_join("KDREAMS.EGA"), PackedByteArray([1, 2, 3]))
	var f2: GameFinder = GameFinder.new()
	f2.unsupported_table = [["kdreams", "Keen Dreams EGA v9.99 (fixture)", "KDREAMS.EXE", fake.size(), GameFinder.crc32(fake)]]
	r = by_id(f2.identify(dreams_other), "kdreams")
	t.ok("a recognised unsupported Dreams release is named with the remedy (%s)" % r.get("message", ""),
		r.get("status", "") == GameFinder.STATUS_UNSUPPORTED and r.message.contains("v9.99") and r.message.contains("not supported") and r.message.contains("KDREAMS.EXE (77,694 bytes)"))
	r = by_id(finder.identify(dreams_other), "kdreams")
	t.ok("the same folder with the real table is Keen Dreams, unrecognised", r.get("status", "") == GameFinder.STATUS_UNRECOGNISED)


func _checksums() -> void:
	# CRC-32 as ReflectionHLE computes it: its v1.00 values for the four files.
	var want: Dictionary = {"AUDIO.KDR": 0x80AC85E5, "EGAGRAPH.KDR": 0x2DC94687, "GAMEMAPS.KDR": 0x7B517FA0, "KDREAMS.EXE": 0xC73B8CB2}
	var same: bool = true
	for name: String in want:
		var crc: int = GameFinder.crc32(FileAccess.get_file_as_bytes(game_root.path_join("kdreams").path_join(name)))
		if crc != want[name]:
			same = false
			print("  crc32 of %s: %08x, ReflectionHLE says %08x" % [name, crc, want[name]])
	t.ok("CRC-32 of the four Dreams files equals ReflectionHLE's v1.00 table", same)
	t.eq("CRC-32 of 'The quick brown fox jumps over the lazy dog'", GameFinder.crc32("The quick brown fox jumps over the lazy dog".to_utf8_buffer()), 0x414FA339)
	t.eq("SHA-256 of an empty file", GameFinder.sha256(PackedByteArray()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")


# ------------------------------------------------------------ SHELL-03: Steam

func _steam() -> void:
	# A Steam install whose library file names a second library elsewhere; the
	# pack is in the second one, with Steam's cruft and mixed-case names.
	var steam: String = tmp.path_join("steam")
	var lib2: String = tmp.path_join("drive2/SteamLibrary")
	var vdf: String = "\"libraryfolders\"\n{\n\t\"0\"\n\t{\n\t\t\"path\"\t\t\"%s\"\n\t}\n\t\"1\"\n\t{\n\t\t\"path\"\t\t\"%s\"\n\t\t\"label\"\t\t\"\"\n\t}\n}\n" % [
		ProjectSettings.globalize_path(steam).replace("/", "\\\\"), ProjectSettings.globalize_path(lib2).replace("/", "\\\\")]
	write_file(steam.path_join("steamapps/libraryfolders.vdf"), vdf.to_utf8_buffer())
	t.eq("libraryfolders.vdf paths parse with their backslashes unescaped", GameFinder.parse_vdf_paths(vdf).size(), 2)
	var keen: String = lib2.path_join(GameFinder.STEAM_KEEN_FOLDER)
	copy_game("keen1", keen.path_join("base1"))
	copy_game("keen2", keen.path_join("base2"))
	copy_game("keen3", keen.path_join("base3"))
	copy_game("keen4", keen.path_join("base4"), {"EGAGRAPH.CK4": "Egagraph.ck4", "GAMEMAPS.CK4": "Gamemaps.ck4", "AUDIO.CK4": "Audio.ck4", "KEEN4E.EXE": "Keen4e.exe"})
	copy_game("keen5", keen.path_join("base5"), {"EGAGRAPH.CK5": "Egagraph.ck5", "GAMEMAPS.CK5": "Gamemaps.ck5", "AUDIO.CK5": "Audio.ck5", "KEEN5E.EXE": "Keen5e.exe"})
	for sub: String in GameFinder.STEAM_KEEN_SUBFOLDERS:
		write_file(keen.path_join(sub).path_join("dosbox.exe"), PackedByteArray([0x4D, 0x5A]))
		write_file(keen.path_join(sub).path_join("keen.conf"), "[dosbox]".to_utf8_buffer())
	write_file(keen.path_join("base1/CTLPANEL.CK1"), PackedByteArray([0, 0, 0]))
	write_file(keen.path_join("Commander Keen.zip"), PackedByteArray([0x50, 0x4B]))
	var found: Array = finder.scan_steam(steam)
	t.eq("the fake Steam install finds Keen 1-5 through libraryfolders.vdf", ids(found),
		PackedStringArray(["keen1:ok", "keen2:ok", "keen3:ok", "keen4:ok", "keen5:ok"]))
	t.ok("Steam's mixed-case names identify (Egagraph.ck4)", by_id(found, "keen4").exe == "Keen4e.exe")
	t.ok("the found folder is the library's base folder", by_id(found, "keen3").folder.ends_with("base3"))
	# A fake registry reader stands in for Windows.
	var f2: GameFinder = GameFinder.new()
	f2.steam_path_reader = func() -> String: return steam
	t.eq("scan_steam() with the registry reader replaced", ids(f2.scan_steam()).size(), 5)
	f2.steam_path_reader = func() -> String: return ""
	t.ok("no Steam at all finds nothing and does not fail", f2.scan_steam().is_empty())
	var f3: GameFinder = GameFinder.new()
	f3.steam_path_reader = func() -> String: return tmp.path_join("nowhere")
	t.ok("a Steam path without a library file finds nothing", f3.scan_steam().is_empty())


func _gog() -> void:
	var gog: String = tmp.path_join("gog/Commander Keen Pack")
	copy_game("keen6", gog.path_join("keen6"))
	copy_game("kdreams", gog)
	var games: Array = [
		{"name": "Journeyman Project 2", "path": tmp.path_join("gog/Journeyman")},
		{"name": "Commander Keen Pack", "path": gog},
		{"name": "Keen Something Missing", "path": tmp.path_join("gog/missing")},
	]
	var f2: GameFinder = GameFinder.new()
	f2.gog_games_reader = func() -> Array: return games
	t.eq("GOG entries with Keen in the name are scanned one level deep", ids(f2.scan_gog()), PackedStringArray(["kdreams:ok", "keen6:ok"]))
	t.ok("the registry parser handles reg.exe's output shape", GameFinder.read_gog_games_from_registry() is Array)


func _folders_and_zip() -> void:
	# A chosen folder two levels deep: game_root/Games/Keen/keenN.
	var deep: String = tmp.path_join("deep")
	copy_game("keen2", deep.path_join("Games/Keen2"))
	copy_game("keen3", deep.path_join("Games/Keen/keen3"))
	t.eq("a chosen folder is scanned two levels down", ids(finder.scan_folder(deep)), PackedStringArray(["keen2:ok"]))
	t.eq("three levels down is not scanned by default", ids(finder.scan_folder(deep, 3)), PackedStringArray(["keen2:ok", "keen3:ok"]))
	# scan_all over Steam + GOG + folders removes duplicates.
	var f2: GameFinder = GameFinder.new()
	f2.steam_path_reader = func() -> String: return tmp.path_join("steam")
	f2.gog_games_reader = func() -> Array: return [{"name": "Keen", "path": tmp.path_join("gog/Commander Keen Pack")}]
	var all: Array = f2.scan_all(PackedStringArray([tmp.path_join("drive2/SteamLibrary/steamapps/common/Commander Keen"), tmp.path_join("all")]))
	var count: Dictionary = {}
	for r: Dictionary in all:
		count[r.id] = count.get(r.id, 0) + 1
	t.ok("scan_all finds every game and lists a folder once (%s)" % str(count), count.size() == 7 and count.keen1 == 2 and count.keen6 == 2)
	# A ZIP holding a game folder.
	var zip_path: String = tmp.path_join("keen2.zip")
	var z: ZIPPacker = ZIPPacker.new()
	z.open(zip_path)
	var src: String = game_root.path_join("keen2")
	for f: String in DirAccess.open(src).get_files():
		z.start_file("Keen 2/" + f.to_lower())
		z.write_file(FileAccess.get_file_as_bytes(src.path_join(f)))
		z.close_file()
	z.start_file("readme.txt")
	z.write_file("x".to_utf8_buffer())
	z.close_file()
	z.close()
	var found: Array = finder.identify_zip(zip_path)
	t.eq("a ZIP of a game folder identifies without extraction", ids(found), PackedStringArray(["keen2:ok"]))
	t.ok("the ZIP result names the folder inside the archive", by_id(found, "keen2").folder.ends_with("Keen 2"))
	t.ok("a file that is not a ZIP finds nothing", finder.identify_zip(tmp.path_join("all/keen1/KEEN1.EXE")).is_empty())


func _read_only() -> void:
	# Game folders are never written to: a read-only copy scans, and the tree
	# (names, sizes, modification times) is the same before and after.
	var ro: String = tmp.path_join("readonly")
	copy_game("keen4", ro)
	copy_game("kdreams", ro.path_join("dreams"))
	for p: String in [ro, ro.path_join("dreams")]:
		for f: String in DirAccess.open(p).get_files():
			FileAccess.set_read_only_attribute(p.path_join(f), true)
	var before: String = _tree(ro)
	var found: Array = finder.scan_folder(ro)
	var after: String = _tree(ro)
	t.eq("a read-only tree scans", ids(found), PackedStringArray(["kdreams:ok", "keen4:ok"]))
	t.ok("the tree is untouched by scanning", before == after and before.contains("EGAGRAPH.CK4"))
	var f: FileAccess = FileAccess.open(ro.path_join("EGAGRAPH.CK4"), FileAccess.READ_WRITE)
	t.ok("the fixture really is read-only (a write fails)", f == null and FileAccess.get_read_only_attribute(ro.path_join("EGAGRAPH.CK4")))


func _tree(path: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var d: DirAccess = DirAccess.open(path)
	for f: String in d.get_files():
		var p: String = path.path_join(f)
		lines.append("%s %d %d" % [p.substr(tmp.length()), FileAccess.get_file_as_bytes(p).size(), FileAccess.get_modified_time(p)])
	for sub: String in d.get_directories():
		lines.append(_tree(path.path_join(sub)))
	return "\n".join(lines)


func _real_machine() -> void:
	var steam: String = GameFinder.read_steam_path_from_registry()
	if steam == "":
		print("  no Steam install on this machine (registry): real scan skipped")
		return
	var found: Array = finder.scan_steam(steam)
	print("  real Steam at %s: %s" % [steam, ", ".join(ids(found))])
	for r: Dictionary in found:
		print("    %s %s in %s" % [r.id, r.version, r.folder])
	t.ok("the real Steam install's Keen pack identifies (Keen 1-5 v1.31/v1.4)",
		found.is_empty() or (by_id(found, "keen1").get("status", "") == GameFinder.STATUS_OK and by_id(found, "keen5").get("status", "") == GameFinder.STATUS_OK))
