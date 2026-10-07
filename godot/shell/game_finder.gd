# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name GameFinder
extends RefCounted
## Finds the player's games and says what each one is.
##
## identify() looks at one folder (or one ZIP) and names every release it
## holds by checksum against KnownFiles: supported ones as such, recognised
## unsupported ones (CGA, shareware, other Dreams releases) with the remedy,
## and anything else that looks like a Keen game as unrecognised, with the
## files that differ. The scans look where games are installed: every Steam
## library (`libraryfolders.vdf`), every GOG install, a chosen folder and its
## first two levels of subfolders.
##
## Nothing here ever writes to a game folder: files are opened for reading
## only and folders are only listed.

## A found game: see _result().
const STATUS_OK: String = "ok"
const STATUS_UNSUPPORTED: String = "unsupported"
const STATUS_UNRECOGNISED: String = "unrecognised"

## Where Steam keeps the Keen pack inside a library.
const STEAM_KEEN_FOLDER: String = "steamapps/common/Commander Keen"
const STEAM_KEEN_SUBFOLDERS: PackedStringArray = ["base1", "base2", "base3", "base4", "base5"]
const STEAM_DREAMS_FOLDER: String = "steamapps/common/Keen Dreams"
## The Definitive Edition keeps the DOS releases in DOS/EGA (v1.93) and DOS/CGA.
const STEAM_DREAMS_DE_FOLDER: String = "steamapps/common/Commander Keen in Keen Dreams DE/DOS"

## How the registry is read (Windows). Tests replace it with a fake.
## steam_path_reader() -> String; gog_games_reader() -> Array of {name, path}.
var steam_path_reader: Callable = Callable(GameFinder, "read_steam_path_from_registry")
var gog_games_reader: Callable = Callable(GameFinder, "read_gog_games_from_registry")
## The recognised-but-unsupported releases; tests put a fixture entry here.
var unsupported_table: Array = KnownFiles.UNSUPPORTED

static var _crc_table: PackedInt64Array = PackedInt64Array()


# ------------------------------------------------------------------ checksums

static func sha256(bytes: PackedByteArray) -> String:
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		h.update(bytes)
	return h.finish().hex_encode()


## CRC-32 (IEEE, as zlib computes it), for ReflectionHLE's table.
static func crc32(bytes: PackedByteArray) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n: int in range(256):
			var c: int = n
			for k: int in range(8):
				c = (0xEDB88320 ^ (c >> 1)) if (c & 1) else (c >> 1)
			_crc_table[n] = c
	var crc: int = 0xFFFFFFFF
	for b: int in bytes:
		crc = _crc_table[(crc ^ b) & 0xFF] ^ (crc >> 8)
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


# ------------------------------------------------------------- one folder

## The files of `folder` as {UPPER NAME: actual name}.
static func _listing(folder: String) -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(folder)
	if d == null:
		return out
	for f: String in d.get_files():
		out[f.to_upper()] = f
	return out


func _result(id: String, title: String, version: String, status: String, folder: String, message: String, exe: String) -> Dictionary:
	return {"id": id, "title": title, "version": version, "status": status, "folder": folder, "message": message, "exe": exe}


## Every game found in one folder (not its subfolders): see the class comment.
## `read` gives a file's bytes by its actual name; the default reads from disk.
func identify(folder: String, listing: Dictionary = {}, read: Callable = Callable()) -> Array:
	if listing.is_empty():
		listing = _listing(folder)
	if not read.is_valid():
		read = func(name: String) -> PackedByteArray:
			return FileAccess.get_file_as_bytes(folder.path_join(name))
	var found: Array = []
	var claimed: Dictionary = {}     # game id -> true once named
	var hashes: Dictionary = {}      # UPPER name -> sha256 (computed once)
	var sizes: Dictionary = {}
	for s: Dictionary in KnownFiles.SETS:
		var differ: PackedStringArray = PackedStringArray()
		var present: int = 0
		for name: String in s.files:
			if not listing.has(name):
				differ.append(name + " missing")
				continue
			present += 1
			if not hashes.has(name):
				var bytes: PackedByteArray = read.call(listing[name])
				sizes[name] = bytes.size()
				hashes[name] = sha256(bytes)
			var want: Array = s.files[name]
			if sizes[name] != want[0] or hashes[name] != want[1]:
				differ.append(name + " differs")
		if present == 0:
			continue
		if differ.is_empty():
			found.append(_result(s.id, s.title, s.version, STATUS_OK, folder, "%s %s" % [s.title, s.version], listing.get(s.exe, s.exe)))
			claimed[s.id] = true
	# Recognised, unsupported releases (by the one file ReflectionHLE keys on).
	for u: Array in unsupported_table:
		if claimed.has(u[0]) or not listing.has(u[2]):
			continue
		var bytes: PackedByteArray = read.call(listing[u[2]])
		if bytes.size() == u[3] and crc32(bytes) == u[4]:
			found.append(_result(u[0], _title(u[0]), u[1], STATUS_UNSUPPORTED, folder,
				"%s: not supported. %s" % [u[1], KnownFiles.REMEDY[u[0]]], listing[u[2]]))
			claimed[u[0]] = true
	# Anything else that looks like one of the games.
	for s: Dictionary in KnownFiles.SETS:
		if claimed.has(s.id):
			continue
		var looks: bool = false
		var cga: bool = false
		var ext: String = ""
		match s.engine:
			"vorticons", "galaxy":
				var n: String = s.id.substr(4, 1)
				ext = "CK" + n
				for name: String in listing:
					if name.begins_with("KEEN" + n) and name.ends_with(".EXE"):
						looks = true
						if name == "KEEN%sC.EXE" % n and s.engine == "galaxy":
							cga = true
					if name.ends_with("." + ext):
						looks = true
					if name == "CGAGRAPH." + ext:
						cga = true
			"dreams":
				for name: String in listing:
					if name.begins_with("KDREAMS") or name.ends_with(".KDR") or name == "LAST.SHL":
						looks = true
					if name == "CGAGRAPH.KDR" or name == "KDREAMS.CGA":
						cga = true
		if not looks:
			continue
		var differ: PackedStringArray = PackedStringArray()
		for name: String in s.files:
			if not listing.has(name):
				differ.append(name + " missing")
			elif hashes.has(name) and (sizes[name] != s.files[name][0] or hashes[name] != s.files[name][1]):
				differ.append(name + " differs")
		var what: String = "the CGA release" if cga else "a release this program does not know"
		found.append(_result(s.id, s.title, "", STATUS_UNRECOGNISED, folder,
			"%s: %s (%s). %s" % [s.title, what, ", ".join(differ.slice(0, 4)), KnownFiles.REMEDY[s.id]], ""))
		claimed[s.id] = true
	return found


static func _title(id: String) -> String:
	for s: Dictionary in KnownFiles.SETS:
		if s.id == id:
			return s.title
	return id


## Every game found inside a ZIP, with the folder inside the ZIP each sits in.
## Files are read from the archive; nothing is extracted.
func identify_zip(path: String) -> Array:
	var z: ZIPReader = ZIPReader.new()
	if z.open(path) != OK:
		return []
	var by_folder: Dictionary = {}    # folder inside the zip -> {UPPER: entry}
	for entry: String in z.get_files():
		if entry.ends_with("/"):
			continue
		var folder: String = entry.get_base_dir()
		if not by_folder.has(folder):
			by_folder[folder] = {}
		by_folder[folder][entry.get_file().to_upper()] = entry
	var found: Array = []
	for folder: String in by_folder:
		var read: Callable = func(name: String) -> PackedByteArray:
			return z.read_file(name)
		var label: String = path + ("/" + folder if folder != "" else "")
		found.append_array(identify(label, by_folder[folder], read))
	z.close()
	return found


# ------------------------------------------------------------------ scans

## A folder, then its subfolders to `depth` levels (a Steam-style tree with
## base1..base5, or one folder per game, both work).
func scan_folder(folder: String, depth: int = 2) -> Array:
	var found: Array = identify(folder)
	if depth > 0:
		var d: DirAccess = DirAccess.open(folder)
		if d != null:
			for sub: String in d.get_directories():
				found.append_array(scan_folder(folder.path_join(sub), depth - 1))
	return found


## The library roots a Steam install knows: itself and every "path" in its
## steamapps/libraryfolders.vdf.
static func steam_libraries(steam_root: String) -> PackedStringArray:
	var libs: PackedStringArray = PackedStringArray()
	if steam_root == "":
		return libs
	libs.append(steam_root)
	var vdf: String = FileAccess.get_file_as_string(steam_root.path_join("steamapps/libraryfolders.vdf"))
	for p: String in parse_vdf_paths(vdf):
		if not libs.has(p):
			libs.append(p)
	return libs


## The "path" values of a libraryfolders.vdf, backslashes unescaped.
static func parse_vdf_paths(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var re: RegEx = RegEx.new()
	re.compile("\"path\"\\s*\"([^\"]+)\"")
	for m: RegExMatch in re.search_all(text):
		out.append(m.get_string(1).replace("\\\\", "\\").replace("\\", "/"))
	return out


## Every Keen game in every Steam library.
func scan_steam(steam_root: String = "") -> Array:
	if steam_root == "":
		steam_root = str(steam_path_reader.call())
	var found: Array = []
	for lib: String in steam_libraries(steam_root):
		var keen: String = lib.path_join(STEAM_KEEN_FOLDER)
		if DirAccess.dir_exists_absolute(keen):
			for sub: String in STEAM_KEEN_SUBFOLDERS:
				found.append_array(identify(keen.path_join(sub)))
		var dreams: String = lib.path_join(STEAM_DREAMS_FOLDER)
		if DirAccess.dir_exists_absolute(dreams):
			found.append_array(scan_folder(dreams, 1))
		var dreams_de: String = lib.path_join(STEAM_DREAMS_DE_FOLDER)
		if DirAccess.dir_exists_absolute(dreams_de):
			found.append_array(scan_folder(dreams_de, 1))
	return found


## Every Keen game among the GOG installs the registry lists.
func scan_gog(games: Array = []) -> Array:
	if games.is_empty():
		games = gog_games_reader.call()
	var found: Array = []
	for g: Dictionary in games:
		if not str(g.get("name", "")).to_lower().contains("keen"):
			continue
		found.append_array(scan_folder(str(g.get("path", "")), 1))
	return found


## Everything: Steam, GOG and the folders given, without duplicates.
func scan_all(extra_folders: PackedStringArray = PackedStringArray()) -> Array:
	var found: Array = scan_steam()
	found.append_array(scan_gog())
	for f: String in extra_folders:
		found.append_array(scan_folder(f))
	var seen: Dictionary = {}
	var out: Array = []
	for r: Dictionary in found:
		var key: String = r.id + "|" + r.folder.to_lower()
		if not seen.has(key):
			seen[key] = true
			out.append(r)
	return out


# ------------------------------------------------------------ the registry

## HKCU\Software\Valve\Steam\SteamPath on Windows; "" elsewhere or if unset.
static func read_steam_path_from_registry() -> String:
	if OS.get_name() != "Windows":
		return ""
	var output: Array = []
	OS.execute("reg", ["query", "HKCU\\Software\\Valve\\Steam", "/v", "SteamPath"], output, true)
	for line: String in str("".join(output)).split("\n"):
		var at: int = line.find("REG_SZ")
		if line.strip_edges().begins_with("SteamPath") and at >= 0:
			return line.substr(at + 6).strip_edges().replace("\\", "/")
	return ""


## GOG's per-game keys: [{name, path}, ...] on Windows; [] elsewhere.
static func read_gog_games_from_registry() -> Array:
	if OS.get_name() != "Windows":
		return []
	var output: Array = []
	OS.execute("reg", ["query", "HKLM\\SOFTWARE\\WOW6432Node\\GOG.com\\Games", "/s"], output, true)
	var games: Array = []
	var current: Dictionary = {}
	for line: String in str("".join(output)).split("\n"):
		var s: String = line.strip_edges()
		if s.begins_with("HKEY_"):
			if current.has("path"):
				games.append(current)
			current = {}
			continue
		var at: int = s.find("REG_SZ")
		if at < 0:
			continue
		var key: String = s.substr(0, at).strip_edges().to_lower()
		var value: String = s.substr(at + 6).strip_edges()
		if key == "gamename":
			current["name"] = value
		elif key == "path":
			current["path"] = value.replace("\\", "/")
	if current.has("path"):
		games.append(current)
	return games
