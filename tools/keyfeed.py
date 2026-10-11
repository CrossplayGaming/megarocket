# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""HARN-22: KEYFEED.COM, a resident DOS program that types a session's keys into the original game on an
exact timetable, so a recording's input is the script itself and not whenever DOSBox got the host's
key messages (REPLAY-D fitted that latency key by key; with this there is nothing to fit).

The program hooks the real-time clock's periodic interrupt (IRQ 8, INT 70h) at 1024 Hz, which the Keen
games leave alone, and feeds each scan code through the keyboard controller's "write keyboard output
buffer" command (D2h): the byte arrives as from the keyboard, through IRQ 1 and the game's own handler.
It needs DOSBox Staging 0.81 or later (0.80 ignores D2h). Two phases:

  0  until the BIOS video mode (0040:0049) is 0Dh, Enter is tapped every PRE_PERIOD ticks (the start-up
     screens: the piracy screen, "press a key"), as the runner's press_until_picture did;
  1  from the tick the mode is seen, the count starts again at 0 and each scheduled scan code (make or
     break) goes in at its tick. A code waits while the controller still holds an unread byte.

Keys are never repeated (a real keyboard's typematic repeat is not fed): the port's machine runs with
repeat off for these sessions (drm_boot --feed_keys). The schedule is the case's held keys, seconds
after the EGA mode set, at 1024 ticks a second.

    python tools/keyfeed.py kdreams level01 out.com     # write the program for a case
"""
import json
import struct
import sys
from pathlib import Path

TICKS_PER_SECOND = 1024
PRE_PERIOD = 1536          # 1.5 s between the start-up screens' Enter taps
PRE_HOLD = 300             # ticks Enter stays down
SCANCODES = {"esc": 0x01, "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06, "6": 0x07, "7": 0x08, "8": 0x09,
             "9": 0x0A, "0": 0x0B, "w": 0x11, "o": 0x18, "enter": 0x1C, "ctrl": 0x1D, "a": 0x1E, "b": 0x30,
             "alt": 0x38, "space": 0x39, "f10": 0x44, "up": 0x48, "left": 0x4B, "right": 0x4D, "down": 0x50,
             "y": 0x15, "n": 0x31, "m": 0x32}
# HARN-06: the rest of the keyboard (scan code set 1; the arrows and the block above them as the keypad's,
# without the E0h prefix, as the games read them), for the screen cases (tools/screen_case.py)
SCANCODES.update({"minus": 0x0C, "equals": 0x0D, "backspace": 0x0E, "tab": 0x0F, "q": 0x10, "e": 0x12, "r": 0x13,
                  "t": 0x14, "u": 0x16, "i": 0x17, "p": 0x19, "s": 0x1F, "d": 0x20, "f": 0x21, "g": 0x22, "h": 0x23,
                  "j": 0x24, "k": 0x25, "l": 0x26, "lshift": 0x2A, "z": 0x2C, "x": 0x2D, "c": 0x2E, "v": 0x2F,
                  "comma": 0x33, "period": 0x34, "slash": 0x35, "rshift": 0x36, "capslock": 0x3A, "f1": 0x3B,
                  "f2": 0x3C, "f3": 0x3D, "f4": 0x3E, "f5": 0x3F, "f6": 0x40, "f7": 0x41, "f8": 0x42, "f9": 0x43,
                  "numlock": 0x45, "scrolllock": 0x46, "home": 0x47, "pgup": 0x49, "end": 0x4F, "pgdn": 0x51,
                  "ins": 0x52, "del": 0x53, "f11": 0x57, "f12": 0x58})


class Asm:
    """Just enough of an 8086 assembler: raw bytes, labels, and 8/16-bit references to labels."""

    def __init__(self, org=0x100):
        self.org = org
        self.items = []

    def b(self, *bs):
        self.items.append(("b", bytes(bs)))

    def label(self, name):
        self.items.append(("label", name))

    def ref16(self, name, add=0):        # a label's address as an immediate or displacement
        self.items.append(("abs16", name, add))

    def rel8(self, opcode, name):        # jcc/jmp short
        self.items.append(("rel8", opcode, name))

    def rel16(self, opcode, name):       # call/jmp near
        self.items.append(("rel16", opcode, name))

    def data(self, bs):
        self.items.append(("b", bytes(bs)))

    @staticmethod
    def _size(it):
        return {"b": lambda: len(it[1]), "label": lambda: 0, "abs16": lambda: 2, "rel8": lambda: 2,
                "rel16": lambda: 3}[it[0]]()

    def build(self):
        labels, pc = {}, self.org
        for it in self.items:
            if it[0] == "label":
                labels[it[1]] = pc
            pc += self._size(it)
        out, pc = bytearray(), self.org
        for it in self.items:
            kind = it[0]
            if kind == "b":
                out += it[1]
            elif kind == "abs16":
                out += struct.pack("<H", labels[it[1]] + it[2])
            elif kind == "rel8":
                rel = labels[it[2]] - (pc + 2)
                if not -128 <= rel <= 127:
                    raise ValueError(f"short jump to {it[2]} out of range")
                out += bytes([it[1], rel & 0xFF])
            elif kind == "rel16":
                out += bytes([it[1]]) + struct.pack("<h", labels[it[2]] - (pc + 3))
            pc += self._size(it)
        return bytes(out), labels


def schedule(held):
    """[(tick, scan code)] from held keys [[seconds after the mode set, key, hold], ...]: makes and breaks
    in time order (same tick: in script order)."""
    events = []
    for n, (at, key, hold) in enumerate(held):
        code = SCANCODES[key]
        events.append((round(at * TICKS_PER_SECOND), 2 * n, code))
        events.append((round((at + hold) * TICKS_PER_SECOND), 2 * n + 1, code | 0x80))
    events.sort()
    # the program puts one code in a tick: codes due in the same tick go in on the ticks after
    out, last = [], -1
    for t, _, c in events:
        t = max(t, last + 1)
        out.append((t, c))
        last = t
    return out


def feed_pairs(held):
    """The schedule as [(make tick, scan code, break tick)] per key (the port's --feed_keys)."""
    ev = schedule(held)
    pairs, down = [], {}
    for t, c in ev:
        if c & 0x80:
            pairs.append((down.pop(c & 0x7F), c & 0x7F, t))
        else:
            down[c] = t
    return sorted(pairs)


def program(events):
    a = Asm()
    a.rel16(0xE9, "init")                                  # jmp init
    a.label("cnt"); a.data([0, 0])
    a.label("phase"); a.data([0])
    a.label("idx"); a.data([0, 0])
    a.label("pend"); a.data([0xFF, 0xFF])
    # ---- INT 70h: the RTC's periodic interrupt
    a.label("isr")
    a.b(0x50, 0x53, 0x52, 0x1E)                            # push ax, bx, dx, ds
    a.b(0x0E, 0x1F)                                        # push cs / pop ds
    a.b(0xB0, 0x0C, 0xE6, 0x70, 0xE4, 0x71)                # read RTC register C (acknowledge)
    a.b(0xFF, 0x06); a.ref16("cnt")                        # inc word [cnt]
    a.b(0x80, 0x3E); a.ref16("phase"); a.b(0x01)           # cmp byte [phase],1
    a.rel8(0x74, "running")                                # je running
    a.rel8(0x77, "inject")                                 # ja inject (phase 2: the schedule is done)
    a.b(0x06, 0xB8, 0x40, 0x00, 0x8E, 0xC0, 0x26, 0xA0, 0x49, 0x00, 0x07)   # al = BIOS video mode (0040:0049)
    a.b(0x3C, 0x0D)                                        # cmp al,0Dh
    a.rel8(0x75, "pre")                                    # jne pre
    a.b(0xC6, 0x06); a.ref16("phase"); a.b(0x01)           # phase = 1
    a.b(0xC7, 0x06); a.ref16("cnt"); a.b(0x00, 0x00)       # cnt = 0
    a.rel8(0xEB, "inject")
    a.label("pre")
    a.b(0xA1); a.ref16("cnt")                              # mov ax,[cnt]
    a.b(0x3D); a.data(struct.pack("<H", PRE_PERIOD))       # cmp ax,PRE_PERIOD
    a.rel8(0x75, "pre2")
    a.b(0xC7, 0x06); a.ref16("pend"); a.b(0x1C, 0x00)      # pend = Enter make
    a.rel8(0xEB, "inject")
    a.label("pre2")
    a.b(0x3D); a.data(struct.pack("<H", PRE_PERIOD + PRE_HOLD))
    a.rel8(0x75, "inject")
    a.b(0xC7, 0x06); a.ref16("pend"); a.b(0x9C, 0x00)      # pend = Enter break
    a.b(0xC7, 0x06); a.ref16("cnt"); a.b(0x00, 0x00)       # cnt = 0 (the next tap a period on)
    a.rel8(0xEB, "inject")
    a.label("running")
    a.b(0x83, 0x3E); a.ref16("pend"); a.b(0xFF)            # cmp word [pend],-1
    a.rel8(0x75, "inject")                                 # a code still waits: deliver it first
    a.b(0x8B, 0x1E); a.ref16("idx")                        # mov bx,[idx]
    a.b(0x8B, 0x87); a.ref16("sched")                      # mov ax,[bx+sched]
    a.b(0x3D, 0xFF, 0xFF)                                  # cmp ax,0FFFFh
    a.rel8(0x75, "notend")
    a.b(0xC6, 0x06); a.ref16("phase"); a.b(0x02)           # the schedule is done: phase 2
    a.rel8(0xEB, "inject")
    a.label("notend")
    a.b(0x3B, 0x06); a.ref16("cnt")                        # cmp ax,[cnt]
    a.rel8(0x77, "inject")                                 # ja inject (not yet)
    a.b(0x8A, 0x87); a.ref16("sched", 2)                   # mov al,[bx+sched+2]
    a.b(0x32, 0xE4)                                        # xor ah,ah
    a.b(0xA3); a.ref16("pend")                             # mov [pend],ax
    a.b(0x83, 0x06); a.ref16("idx"); a.b(0x03)             # add word [idx],3
    a.label("inject")
    a.b(0x83, 0x3E); a.ref16("pend"); a.b(0xFF)            # cmp word [pend],-1
    a.rel8(0x74, "eoi")
    a.b(0xE4, 0x64, 0xA8, 0x03)                            # in al,64h ; test al,3 (a byte unread or input busy)
    a.rel8(0x75, "eoi")                                    # then the next tick
    a.b(0xB0, 0xD2, 0xE6, 0x64)                            # out 64h,D2h (write keyboard output buffer)
    a.label("w1")
    a.b(0xE4, 0x64, 0xA8, 0x02)
    a.rel8(0x75, "w1")
    a.b(0xA1); a.ref16("pend")
    a.b(0xE6, 0x60)                                        # out 60h,al
    a.b(0xC7, 0x06); a.ref16("pend"); a.b(0xFF, 0xFF)      # pend = none
    a.label("eoi")
    a.b(0xB0, 0x20, 0xE6, 0xA0, 0xE6, 0x20)                # EOI slave and master
    a.b(0x1F, 0x5A, 0x5B, 0x58, 0xCF)                      # pop ds, dx, bx, ax ; iret
    a.label("sched")
    for tick, code in events:
        if not 0 <= tick < 0xFFFF:
            raise ValueError(f"a key at tick {tick} is outside the 64 s the program counts")
        a.data(struct.pack("<HB", tick, code))
    a.data(struct.pack("<HB", 0xFFFF, 0))
    a.label("resident_end")
    # ---- installation
    a.label("init")
    a.b(0xBA); a.ref16("isr")                              # mov dx,isr
    a.b(0xB8, 0x70, 0x25, 0xCD, 0x21)                      # set INT 70h
    a.b(0xFA)                                              # cli
    a.b(0xB0, 0x0A, 0xE6, 0x70, 0xB0, 0x26, 0xE6, 0x71)    # RTC register A: 1024 Hz
    a.b(0xB0, 0x0B, 0xE6, 0x70, 0xE4, 0x71, 0x0C, 0x40, 0x88, 0xC4,
        0xB0, 0x0B, 0xE6, 0x70, 0x88, 0xE0, 0xE6, 0x71)    # register B: periodic interrupt on
    a.b(0xB0, 0x0C, 0xE6, 0x70, 0xE4, 0x71)                # clear register C
    a.b(0xE4, 0xA1, 0x24, 0xFE, 0xE6, 0xA1)                # unmask IRQ 8
    a.b(0xE4, 0x21, 0x24, 0xFB, 0xE6, 0x21)                # unmask the cascade (IRQ 2)
    a.b(0xFB)                                              # sti
    a.b(0xBA); a.ref16("paras")                            # mov dx,paragraphs (patched below)
    a.b(0xB8, 0x00, 0x31, 0xCD, 0x21)                      # stay resident
    a.label("paras")                                       # (placeholder label, replaced)
    code, labels = a.build()
    paras = (labels["resident_end"] - 0x100 + 0x100 + 15) // 16    # the PSP's 256 bytes and the resident part
    # patch "mov dx,paras": the immediate is the 2 bytes after the BA opcode that references "paras"
    at = code.rfind(bytes([0xBA]) + struct.pack("<H", labels["paras"]))
    code = code[:at + 1] + struct.pack("<H", paras) + code[at + 3:]
    return code


def case_program(game, case):
    spec = json.loads((Path(__file__).parent / "cases" / game / f"{case}.json").read_text(encoding="utf-8"))
    return program(schedule(spec["held"]))


if __name__ == "__main__":
    data = case_program(sys.argv[1], sys.argv[2])
    Path(sys.argv[3]).write_bytes(data)
    print(f"{sys.argv[3]}: {len(data)} bytes")
