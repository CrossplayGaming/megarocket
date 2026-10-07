# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""Unpack the original game program (compressed with LZEXE 0.91) in memory.

The original source sometimes reads past the end of a table. What it finds
there is whatever the compiler placed next in the program's data, and the
only way to know is to look. This gives the unpacked program image so such
bytes can be looked up; nothing is written into the project.

    python tools/unlzexe.py find 01 02 03 02 03 04 03     show where a byte run occurs
    python tools/unlzexe.py dump <offset> [count]         show bytes at an offset
    python tools/unlzexe.py write <path>                  save the image (outside the project)
"""
import struct
import sys
from pathlib import Path

import common


def unpack(exe: bytes) -> bytes:
    """Return the load image (everything after the EXE header) of an LZEXE 0.91 file."""
    if exe[0x1C:0x20] != b"LZ91":
        raise ValueError("not an LZEXE 0.91 file")
    head = struct.unpack_from("<16H", exe, 0)
    header_paragraphs = head[4]
    cs = head[0x0B]
    info_pos = (cs + header_paragraphs) << 4
    info = struct.unpack_from("<8H", exe, info_pos)
    pos = (cs - info[4] + header_paragraphs) << 4

    out = bytearray()
    bits = struct.unpack_from("<H", exe, pos)[0]
    pos += 2
    count = 16

    def getbit() -> int:
        nonlocal bits, count, pos
        b = bits & 1
        count -= 1
        if count == 0:
            bits = struct.unpack_from("<H", exe, pos)[0]
            pos += 2
            count = 16
        else:
            bits >>= 1
        return b

    while True:
        if getbit():
            out.append(exe[pos])
            pos += 1
            continue
        if not getbit():
            length = getbit() << 1
            length |= getbit()
            length += 2
            span = exe[pos] - 0x100
            pos += 1
        else:
            span = exe[pos]
            length = exe[pos + 1]
            pos += 2
            span = (span | ((length & 0xF8) << 5) | 0xE000) - 0x10000
            length = (length & 0x07) + 2
            if length == 2:
                length = exe[pos]
                pos += 1
                if length == 0:
                    break
                if length == 1:
                    continue
                length += 1
        for _ in range(length):
            out.append(out[len(out) + span])
    return bytes(out)


def image() -> bytes:
    return unpack((Path(config()["duke2_data"]) / "NUKEM2.EXE").read_bytes())


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    data = image()
    command = sys.argv[1]
    if command == "find":
        needle = bytes(int(x, 16) for x in sys.argv[2:])
        start = 0
        found = 0
        while True:
            at = data.find(needle, start)
            if at < 0:
                break
            found += 1
            tail = data[at:at + len(needle) + 24]
            print(f"{at:#08x}: " + " ".join(f"{b:02x}" for b in tail))
            start = at + 1
        print(f"{found} occurrence(s) in {len(data)} bytes")
        return 0
    if command == "dump":
        at = int(sys.argv[2], 0)
        count = int(sys.argv[3], 0) if len(sys.argv) > 3 else 64
        for row in range(at, at + count, 16):
            chunk = data[row:row + 16]
            print(f"{row:#08x}: " + " ".join(f"{b:02x}" for b in chunk)
                  + "  " + "".join(chr(b) if 32 <= b < 127 else "." for b in chunk))
        return 0
    if command == "write":
        target = Path(sys.argv[2]).resolve()
        if Path(__file__).resolve().parents[1] in target.parents:
            print("refusing to write the original program into the project folder")
            return 2
        target.write_bytes(data)
        print(f"{len(data)} bytes written to {target}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
