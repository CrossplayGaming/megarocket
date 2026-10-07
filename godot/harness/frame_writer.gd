# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
class_name FrameWriter
extends RefCounted
## Writes the port's pictures in the frame-store format read by tools/frames.py.
##
## A store is a folder holding `frames.bin` (zlib-compressed 320x200 RGB
## pictures back to back) and `frames.json` (offset, size, repeat count and
## SHA-1 of each, plus where each level starts and what kind each picture is).
##
## Kinds: "P" is the finished picture of a game frame, the one on screen while
## the original waits. "I" is an in-between picture the original may show
## briefly, such as the old playfield with a newly drawn score. See
## tools/compare_frames.py for how the two are used.

const WIDTH: int = 320
const HEIGHT: int = 200
const FRAME_BYTES: int = WIDTH * HEIGHT * 3

var error: String = ""

var _folder: String = ""
var _bin: FileAccess = null
var _index: Array = []          # [offset, size, repeats, sha1]
var _kinds: Array = []          # "P" / "I", one per index entry
var _level_starts: Array = []
var _offset: int = 0
var _last_digest: String = ""
var _raw_count: int = 0
var _hasher: HashingContext = HashingContext.new()
var _indexed: bool = false


func open(folder: String) -> bool:
	_folder = folder
	var made: Error = DirAccess.make_dir_recursive_absolute(folder)
	if made != OK:
		error = "could not create %s (%s)" % [folder, error_string(made)]
		return false
	_bin = FileAccess.open(folder.path_join("frames.bin"), FileAccess.WRITE)
	if _bin == null:
		error = "could not write frames.bin (%s)" % error_string(FileAccess.get_open_error())
		return false
	return true


## Call before the first picture of each level.
func start_level() -> void:
	_level_starts.append(_index.size())
	# The first picture of a level is always its own entry, even if it happens
	# to equal the last picture of the level before.
	_last_digest = ""


## Add one picture as palette indices (320x200, one byte per pixel) plus the
## palette (three bytes per colour). The store is then marked "indexed" and
## tools/frames.py expands each picture to RGB when it reads it; doing that
## expansion here would take longer than drawing the picture did.
func add_indexed(indices: PackedByteArray, palette: PackedByteArray, kind: String = "P") -> bool:
	if indices.size() != WIDTH * HEIGHT:
		error = "a picture must be %d pixels, got %d" % [WIDTH * HEIGHT, indices.size()]
		return false
	_indexed = true
	var blob: PackedByteArray = indices.duplicate()
	blob.append_array(palette)
	return _store(blob, kind)


## Add one picture: 320x200, three bytes per pixel, row by row.
## A picture identical to the one before it is merged into it; an in-between
## picture identical to the one before it is dropped.
func add(rgb: PackedByteArray, kind: String = "P") -> bool:
	if rgb.size() != FRAME_BYTES:
		error = "a picture must be %d bytes, got %d" % [FRAME_BYTES, rgb.size()]
		return false
	return _store(rgb, kind)


func _store(rgb: PackedByteArray, kind: String) -> bool:
	_raw_count += 1
	_hasher.start(HashingContext.HASH_SHA1)
	_hasher.update(rgb)
	var digest: String = _hasher.finish().hex_encode()
	if digest == _last_digest:
		if kind == "P":
			var entry: Array = _index[_index.size() - 1]
			entry[2] = int(entry[2]) + 1
			# A finished picture equal to the in-between one before it takes over the entry.
			_kinds[_kinds.size() - 1] = "P"
		return true
	var blob: PackedByteArray = rgb.compress(FileAccess.COMPRESSION_DEFLATE)
	_bin.store_buffer(blob)
	_index.append([_offset, blob.size(), 1, digest])
	_kinds.append(kind)
	_offset += blob.size()
	_last_digest = digest
	return true


func close(meta: Dictionary = {}) -> bool:
	if _bin != null:
		_bin.close()
		_bin = null
	var full_meta: Dictionary = meta.duplicate()
	full_meta["level_starts"] = _level_starts
	full_meta["kinds"] = _kinds
	var doc: Dictionary = {
		"width": WIDTH,
		"height": HEIGHT,
		"raw_frames": _raw_count,
		"format": "indexed" if _indexed else "rgb",
		"frames": _index,
		"meta": full_meta,
	}
	var out: FileAccess = FileAccess.open(_folder.path_join("frames.json"), FileAccess.WRITE)
	if out == null:
		error = "could not write frames.json (%s)" % error_string(FileAccess.get_open_error())
		return false
	out.store_string(JSON.stringify(doc))
	out.close()
	return true
