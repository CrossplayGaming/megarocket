# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
class_name T
extends RefCounted
## Minimal test helper for headless test scripts. See tools/gdtest.py.

var failures: int = 0
var checks: int = 0
var could_not_run: String = ""


func ok(label: String, condition: bool) -> bool:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL  ", label)
	return condition


func eq(label: String, got: Variant, want: Variant) -> bool:
	checks += 1
	if typeof(got) != typeof(want) or got != want:
		failures += 1
		print("  FAIL  ", label, ": got ", got, ", want ", want)
		return false
	return true


func blocked(reason: String) -> void:
	could_not_run = reason


## Command-line options given after `--`, as a dictionary: `--name=value`.
static func options() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var cut: int = arg.find("=")
			out[arg.substr(2, cut - 2)] = arg.substr(cut + 1)
	return out


func finish(tree: SceneTree) -> void:
	if could_not_run != "":
		print("RESULT: COULD-NOT-RUN  (", could_not_run, ")")
		tree.quit(2)
	elif failures > 0:
		print(checks, " checks, ", failures, " failed")
		print("RESULT: FAIL")
		tree.quit(1)
	else:
		print(checks, " checks, all passed")
		print("RESULT: PASS")
		tree.quit(0)
