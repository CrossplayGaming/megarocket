# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: omnispeak's ck_act.c (CK_VAR_ParseVar and friends) and id_str.c
# (STR_GetToken, STR_SkipWhitespace, STR_GetIntegerValue).
class_name VarFile
extends RefCounted
## Reads omnispeak's variable files (EPISODE, STRINGS, GFXCHUNK, ACTION):
##   # comment to end of line
##   %int NAME value            value: decimal, 0x hex, $hex, or @OTHERNAME
##   %string NAME "text" "more" (adjacent strings join; \n escapes)
##   %intarray NAME v, v, v
##   %stringarray NAME "a", "b"
##   %function NAME CFunctionName
##   %action NAME field ...     (kept as its tokens; the Galaxy engine reads them)
##   %action NAME = OTHER
##   %include "file"
## A token is a quoted string, or a run of non-space characters; a comma is
## its own token.

var ints: Dictionary = {}
var strings: Dictionary = {}
var int_arrays: Dictionary = {}
var string_arrays: Dictionary = {}
var functions: Dictionary = {}
var actions: Dictionary = {}          # name -> Array of tokens (Strings), or {"alias": name}
var action_order: Array[String] = []
var error: String = ""

var _text: String = ""
var _pos: int = 0
var _line: int = 1
var _dir: String = ""


func load(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		error = "%s: cannot open (%s)" % [path.get_file(), error_string(FileAccess.get_open_error())]
		return false
	var text: String = f.get_as_text()
	f.close()
	return parse(text, path)


func parse(text: String, path: String = "<text>") -> bool:
	var saved: Array = [_text, _pos, _line, _dir]
	_text = text
	_pos = 0
	_line = 1
	_dir = path.get_base_dir()
	var ok: bool = _parse_all(path.get_file())
	_text = saved[0]
	_pos = saved[1]
	_line = saved[2]
	_dir = saved[3]
	return ok


# ------------------------------------------------------------ tokenizer

func _skip_space() -> void:
	while _pos < _text.length():
		var c: String = _text[_pos]
		if c == "#":
			while _pos < _text.length() and _text[_pos] != "\n":
				_pos += 1
		elif c == " " or c == "\t" or c == "\r" or c == "\n":
			if c == "\n":
				_line += 1
			_pos += 1
		else:
			break


## Returns [kind, value]: kind "eof", "string", "ident".
func _token() -> Array:
	_skip_space()
	if _pos >= _text.length():
		return ["eof", ""]
	if _text[_pos] == "\"":
		_pos += 1
		var out: String = ""
		while _pos < _text.length() and _text[_pos] != "\"":
			var c: String = _text[_pos]
			if c == "\\" and _pos + 1 < _text.length():
				_pos += 1
				c = _text[_pos]
				if c == "n":
					c = "\n"
			if c == "\n":
				_line += 1
			out += c
			_pos += 1
		_pos += 1
		return ["string", out]
	if _text[_pos] == ",":
		_pos += 1
		return ["ident", ","]
	var start: int = _pos
	while _pos < _text.length():
		var c: String = _text[_pos]
		if c == " " or c == "\t" or c == "\r" or c == "\n" or c == ",":
			break
		_pos += 1
	return ["ident", _text.substr(start, _pos - start)]


func _peek() -> Array:
	var p: int = _pos
	var l: int = _line
	var t: Array = _token()
	_pos = p
	_line = l
	return t


func _int_value(tok: String) -> int:
	if tok.begins_with("@"):
		var name: String = tok.substr(1)
		if not ints.has(name):
			error = "line %d: @%s refers to an integer that is not defined" % [_line, name]
			return 0
		return ints[name]
	if tok.begins_with("$"):
		return ("0x" + tok.substr(1)).hex_to_int()
	if tok.begins_with("0x") or tok.begins_with("0X"):
		return tok.hex_to_int()
	if tok.begins_with("-0x"):
		return -tok.substr(1).hex_to_int()
	if tok.is_valid_int():
		return int(tok)
	# strtol stops at the first bad character; a bare name reads as 0 there,
	# but here that is far more likely a mistake worth hearing about
	error = "line %d: '%s' is not a number" % [_line, tok]
	return 0


# --------------------------------------------------------------- parser

func _parse_all(file: String) -> bool:
	while true:
		var t: Array = _token()
		if t[0] == "eof":
			return error == ""
		if t[0] != "ident" or not t[1].begins_with("%"):
			error = "%s line %d: expected a %%directive, got '%s'" % [file, _line, t[1]]
			return false
		match t[1]:
			"%int":
				var name: String = _token()[1]
				ints[name] = _int_value(_token()[1])
			"%string":
				var name: String = _token()[1]
				strings[name] = _joined_string()
			"%intarray":
				var name: String = _token()[1]
				var arr: PackedInt32Array = PackedInt32Array()
				while true:
					arr.append(_int_value(_token()[1]))
					if _peek()[1] != ",":
						break
					_token()
				int_arrays[name] = arr
			"%stringarray":
				var name: String = _token()[1]
				var arr: PackedStringArray = PackedStringArray()
				while true:
					arr.append(_joined_string())
					if _peek()[1] != ",":
						break
					_token()
				string_arrays[name] = arr
			"%function":
				var name: String = _token()[1]
				functions[name] = _token()[1]
			"%action":
				var name: String = _token()[1]
				if _peek()[1] == "=":
					_token()
					actions[name] = {"alias": _token()[1]}
				else:
					# the rest of the line
					var fields: Array = []
					var line_now: int = _line
					while true:
						var n: Array = _peek()
						if n[0] == "eof":
							break
						# a token on a later line belongs to the next directive
						_skip_space()
						if _line != line_now:
							break
						fields.append(_token()[1])
					actions[name] = fields
				action_order.append(name)
			"%include":
				var inc: String = _token()[1]
				var sub: String = _dir.path_join(inc)
				var f: FileAccess = FileAccess.open(sub, FileAccess.READ)
				if f == null:
					error = "%s line %d: cannot include %s" % [file, _line, inc]
					return false
				var text: String = f.get_as_text()
				f.close()
				if not parse(text, sub):
					return false
			_:
				error = "%s line %d: unknown directive %s" % [file, _line, t[1]]
				return false
		if error != "":
			error = file + " " + error
			return false
	return true


func _joined_string() -> String:
	var out: String = ""
	while true:
		var t: Array = _token()
		if t[0] != "string":
			error = "line %d: expected a quoted string, got '%s'" % [_line, t[1]]
			return out
		out += t[1]
		if _peek()[0] != "string":
			break
	return out


func get_int(name: String, default: int = 0) -> int:
	return ints.get(name, default)


func get_string(name: String, default: String = "") -> String:
	return strings.get(name, default)
