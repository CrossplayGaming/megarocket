# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name ShellMessages
extends RefCounted
## Every message the shell shows (SHELL-09): what happened, then a sentence
## saying what to do next. Each is also written to the log (log_path()),
## which the launcher names at the bottom of its screen.

## The first word of every next step: a test checks each message ends in a
## sentence starting with one of these.
const NEXT_VERBS: PackedStringArray = ["Add", "Put", "Check", "Start", "Press", "Choose", "Play", "Set", "Send", "Copy", "Export", "Pick", "Import"]
const LOG_SETTING: String = "debug/file_logging/log_path"


## Where this run's log is written, as the player's system names it.
static func log_path() -> String:
	return ProjectSettings.globalize_path(String(ProjectSettings.get_setting(LOG_SETTING, "user://logs/megarocket.log")))


## "what. next" -- and the pair goes to the log.
static func say(what: String, next: String) -> String:
	var w: String = what.strip_edges()
	if not w.ends_with(".") and not w.ends_with("?") and not w.ends_with("!"):
		w += "."
	var text: String = w + " " + next.strip_edges()
	note(text)
	return text


## A line in the log, with the time.
static func note(text: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), text])


## How the player brings a game in here: Android imports a folder picked with
## the system's picker (AND-02); elsewhere a folder is added and read in place.
static func android() -> bool:
	return OS.has_feature("android")


static func add_step(what: String) -> String:
	return ("Import %s with Import games" if android() else "Add %s with Add a folder") % what


## The message's next step obeys the rule: its last sentence starts with an
## imperative from NEXT_VERBS.
static func has_next_step(text: String) -> bool:
	var ends: Array[RegExMatch] = RegEx.create_from_string(r"[.!?]\s+").search_all(text.strip_edges())
	var last: String = text.strip_edges().substr(ends[-1].get_end()) if not ends.is_empty() else text.strip_edges()
	for v: String in NEXT_VERBS:
		if last.begins_with(v + " "):
			return true
	return false


# ---- the launcher's tiles

static func missing(looks_for: String) -> String:
	return say("Not found. " + looks_for, add_step("its folder") + ", or see How to add games.")


static func not_run(found_what: String, why: String) -> String:
	return say("Found %s, which Megarocket does not run. %s" % [found_what, why],
		("Copy the release named above to the phone and import it with Import games." if android() else
			"Put the release named above where Megarocket looks, or add its folder with Add a folder."))


static func cant_load(title: String, detail: String) -> String:
	return say("%s's files could not be read (%s)" % [title, detail],
		"Check the folder holds the whole release named on the tile, unchanged; the log at %s has the details." % log_path())


static func not_ready(title: String) -> String:
	return say("%s cannot be played in Megarocket yet; its port is still being built" % title,
		"Play one of the other games for now.")


static func game_stopped(title: String, detail: String) -> String:
	if detail.begins_with("not ported yet: "):
		return say("%s stopped: it reached a part of the game Megarocket does not have yet (%s)" % [title, detail.trim_prefix("not ported yet: ")],
			"Start it again from its tile; the log at %s records where it stopped." % log_path())
	return say("%s stopped with the game's own error message: %s" % [title, detail],
		"Start it again from its tile; if it happens again, send the log at %s with a report." % log_path())


# ---- the launcher's other screens

static func already_running() -> String:
	return say("Megarocket is already running in another window", "Press Enter (or A) to start this one anyway.")


static func settings_reset(file_name: String, reason: String) -> String:
	return say("Your settings file %s could not be read (%s), so the settings are back to their defaults; the old file is kept as %s.bad" % [file_name, reason, file_name],
		"Set your options again.")


static func settings_not_saved(file_name: String) -> String:
	return say("Your settings could not be saved to %s" % file_name,
		"Check that the drive has free space and is not read-only.")


# ---- exporting (SHELL-10)

static func nothing_to_export() -> String:
	return say("No supported game has been found yet, so there is nothing to export", add_step("a game's folder") + " first.")


static func cannot_create(path: String) -> String:
	return say("Megarocket cannot create %s" % path, "Choose a folder you can write to.")


static func no_space(destination: String, mb: float) -> String:
	return say("Not enough free space in %s: the export needs %.1f MB" % [destination, mb], "Choose another drive, or free some space and try again.")
