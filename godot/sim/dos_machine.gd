# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
class_name DosMachine
extends RefCounted
## The rest of the 1990 PC a Keen engine talks to, around the EGA card: a
## clock, the timer chip (channel 0 for the timer interrupt, channel 2 for
## the speaker), the speaker port, the keyboard port, the joystick port and
## the video retrace signal.
##
## Time is virtual. The engines are ports of programs that WAIT: for the
## vertical retrace, for timer tics, for a key. Every such wait advances this
## clock, and the clock delivers what falls due on the way: timer interrupts
## (the engine's handler), key presses from a timed script (the engine's
## keyboard handler), and the start of each displayed frame (whoever
## records pictures). Between waits the processor is taken as infinitely
## fast, which is what a 1990 game running on a 2020s emulator effectively
## has. Nothing here reads the wall clock (A8); a real-time shell paces the
## waits from outside.
##
## Units: one unit is a thousandth of a cycle of the 1193182 Hz timer clock,
## so that both the timer period and the 70.086 Hz refresh period are whole
## numbers (A2).

const PIT_HZ: int = 1193182
const UNIT: int = 1000
## 1193182 * 1000 / 70.086 refreshes a second, the rate DOSBox reports for
## mode 0Dh ("70.086 Hz" in its log).
const VBL_PERIOD: int = 17024567
## The vertical retrace lasts about two scan lines of the 449 in a frame.
const RETRACE_LEN: int = 76000

var card: EgaCard = EgaCard.new()

var now: int = 0
var next_vbl: int = 0
var last_vbl: int = -(1 << 60)
var vbl_count: int = 0
var _display_due: int = RETRACE_LEN     # the start of active display after a retrace

## Timer channel 0: what it counts from (0x10000 = the PC's own 18.2 Hz).
var pit0_reload: int = 0x10000
var next_tick: int = 0x10000 * UNIT
var tick_count: int = 0
var _pit0_low: int = 0
var _pit0_expect_high: bool = false

## Timer channel 2 and the speaker gate (port 61h bits 0-1).
var pit2_count: int = 0
var _pit2_low: int = 0
var _pit2_expect_high: bool = false
var port61: int = 0
## Speaker changes: time, count (0 = off), time, count, ...
var speaker_events: PackedInt64Array = PackedInt64Array()
var record_speaker: bool = false

## The keyboard: a timed script of scancodes (bit 7 set = release), and the
## last code on port 60h.
var key_events: Array = []              # [[time_units, scancode], ...] in time order
var _key_index: int = 0
var port60: int = 0

## Installed handlers: the timer interrupt (INT 8), the keyboard interrupt
## (INT 9), the start of each displayed frame, and the time limit.
var int8: Callable = Callable()
var int9: Callable = Callable()
var on_display: Callable = Callable()
var on_limit: Callable = Callable()
var time_limit: int = -1
var limit_fired: bool = false


static func seconds_to_units(s: float) -> int:
	return int(round(s * PIT_HZ)) * UNIT


func seconds() -> float:
	return float(now) / float(PIT_HZ * UNIT)


## A key pressed at `at` seconds for `hold` seconds.
func add_key(at: float, scancode: int, hold: float = 0.1) -> void:
	key_events.append([seconds_to_units(at), scancode & 0x7F])
	key_events.append([seconds_to_units(at + hold), (scancode & 0x7F) | 0x80])
	key_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


# -------------------------------------------------------------------- ports

func out8(port: int, value: int) -> void:
	value &= 0xFF
	match port:
		0x43:
			# Control word: bits 6-7 pick the channel, low byte then high byte.
			if (value & 0xC0) == 0x00:
				_pit0_expect_high = false
			elif (value & 0xC0) == 0x80:
				_pit2_expect_high = false
		0x40:
			if _pit0_expect_high:
				pit0_reload = _pit0_low | (value << 8)
				if pit0_reload == 0:
					pit0_reload = 0x10000
				_pit0_expect_high = false
				next_tick = now + pit0_reload * UNIT
			else:
				_pit0_low = value
				_pit0_expect_high = true
		0x42:
			if _pit2_expect_high:
				pit2_count = _pit2_low | (value << 8)
				_pit2_expect_high = false
				_note_speaker()
			else:
				_pit2_low = value
				_pit2_expect_high = true
		0x61:
			var was_on: bool = (port61 & 3) == 3
			port61 = value
			if was_on != ((port61 & 3) == 3):
				_note_speaker()
		0x20:
			pass    # end of interrupt
		_:
			card.out8(port, value)


func out16(port: int, value: int) -> void:
	out8(port, value & 0xFF)
	out8(port + 1, (value >> 8) & 0xFF)


func in8(port: int) -> int:
	match port:
		0x60:
			return port60
		0x61:
			return port61
		0x201:
			# No joystick: the axis bits never fall and no button is down.
			return 0xFF
	return card.in8(port)


func _note_speaker() -> void:
	if record_speaker:
		speaker_events.append(now)
		speaker_events.append(pit2_count if (port61 & 3) == 3 else 0)


# --------------------------------------------------------------------- time

## Everything that falls due up to `target`, in time order, then now = target.
func advance_to(target: int) -> void:
	while true:
		var t_key: int = key_events[_key_index][0] if _key_index < key_events.size() else (1 << 62)
		var t: int = mini(mini(next_tick, next_vbl), mini(t_key, _display_due))
		if t > target:
			break
		now = t
		if t == next_vbl:
			last_vbl = t
			vbl_count += 1
			next_vbl = t + VBL_PERIOD
			_display_due = t + RETRACE_LEN
		elif t == _display_due:
			_display_due = 1 << 62
			if on_display.is_valid():
				on_display.call()
		elif t == next_tick:
			tick_count += 1
			next_tick = t + pit0_reload * UNIT
			if int8.is_valid():
				int8.call()
		else:
			port60 = key_events[_key_index][1]
			_key_index += 1
			if int9.is_valid():
				int9.call()
		if time_limit >= 0 and now >= time_limit and not limit_fired:
			limit_fired = true
			if on_limit.is_valid():
				on_limit.call()
	now = target


func in_retrace() -> bool:
	return now >= last_vbl and now - last_vbl < RETRACE_LEN


## Wait for the end of a retrace if one is on (the "test al,8 / jnz" loop).
func wait_retrace_end() -> void:
	if in_retrace():
		advance_to(last_vbl + RETRACE_LEN)


## Wait for the next retrace to begin (the "test al,8 / jz" loop).
func wait_retrace_start() -> void:
	advance_to(next_vbl)


## The library's WaitVBL: `n` times, let any retrace end, then wait for the next.
func wait_vbl(n: int) -> void:
	for i: int in range(n):
		wait_retrace_end()
		wait_retrace_start()


## A busy loop with nothing to wait on but the next thing that happens: the
## next timer tic, refresh or key. Used where the program spins reading keys.
func poll() -> void:
	var t_key: int = key_events[_key_index][0] if _key_index < key_events.size() else (1 << 62)
	advance_to(mini(mini(next_tick, next_vbl), mini(t_key, _display_due)))


# ----------------------------------------------------------------- snapshot

func snapshot() -> Dictionary:
	return {
		"card": card.snapshot(), "now": now, "next_vbl": next_vbl, "last_vbl": last_vbl, "vbl_count": vbl_count,
		"display_due": _display_due, "pit0_reload": pit0_reload, "next_tick": next_tick, "tick_count": tick_count,
		"pit0_low": _pit0_low, "pit0_expect_high": _pit0_expect_high, "pit2_count": pit2_count,
		"pit2_low": _pit2_low, "pit2_expect_high": _pit2_expect_high, "port61": port61,
		"key_index": _key_index, "port60": port60,
	}


func restore(s: Dictionary) -> void:
	card.restore(s.card)
	now = s.now
	next_vbl = s.next_vbl
	last_vbl = s.last_vbl
	vbl_count = s.vbl_count
	_display_due = s.display_due
	pit0_reload = s.pit0_reload
	next_tick = s.next_tick
	tick_count = s.tick_count
	_pit0_low = s.pit0_low
	_pit0_expect_high = s.pit0_expect_high
	pit2_count = s.pit2_count
	_pit2_low = s.pit2_low
	_pit2_expect_high = s.pit2_expect_high
	port61 = s.port61
	_key_index = s.key_index
	port60 = s.port60
