"""
Locate the graphics / map tables id Software embedded in a Keen 4-6
executable, so they can be written out as the .CKx definition files
Omnispeak expects for a given game version.

The tables are self-identifying, which is the whole point: a hit is only
reported if the numbers are internally consistent AND agree with the sizes
of the game's actual data files.  That makes this both a locator and a
correctness check -- if an unpacking step were wrong, nothing would match.

  EGAHEAD  : 3-byte little-endian offsets into EGAGRAPH, one per chunk,
             non-decreasing, with 0xFFFFFF marking absent chunks.  The last
             real offset must equal the EGAGRAPH file size exactly.
  MAPHEAD  : 0xABCD RLEW tag, then int32 offsets into GAMEMAPS.
  AUDIOHHD : int32 offsets into AUDIO, last == the AUDIO file size.

Usage:  python find_keen_tables.py <image> --graph <EGAGRAPH> [--maps <GAMEMAPS>] [--audio <AUDIO>]
"""

import argparse
import os
import struct
import sys


def find_offset_table(img, entry_size, target_end, min_entries=200,
                      absent=None):
    """Find tables of ascending offsets whose last real value == target_end.

    Returns a list of (start, count) hits.
    """
    hits = []
    n = len(img)
    step = entry_size
    i = 0
    while i < n - step * min_entries:
        # cheap gate: the table starts at 0 or a small value and ascends
        vals = []
        p = i
        prev = -1
        ok = True
        while p + step <= n:
            v = int.from_bytes(img[p:p + step], "little")
            if absent is not None and v == absent:
                p += step
                vals.append(v)
                continue
            if v < prev:
                break
            prev = v
            vals.append(v)
            p += step
            if v > target_end:
                ok = False
                break
        real = [v for v in vals if absent is None or v != absent]
        if ok and len(vals) >= min_entries and real and real[-1] == target_end:
            hits.append((i, len(vals)))
            i = p                     # don't re-report overlapping windows
            continue
        i += 1
    return hits


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--graph", required=True)
    ap.add_argument("--maps")
    ap.add_argument("--audio")
    ap.add_argument("--min-entries", type=int, default=200)
    args = ap.parse_args(argv[1:])

    img = open(args.image, "rb").read()
    print(f"{args.image}: {len(img)} bytes")

    gsize = os.path.getsize(args.graph)
    print(f"\nEGAHEAD: looking for 3-byte offsets ending at {gsize} "
          f"({args.graph})")
    for start, count in find_offset_table(img, 3, gsize,
                                          args.min_entries, absent=0xFFFFFF):
        print(f"  HIT at {start:#x}: {count} entries "
              f"({count * 3} bytes) -> chunks 0..{count - 1}")

    if args.maps:
        msize = os.path.getsize(args.maps)
        print(f"\nMAPHEAD: looking for the 0xABCD tag ({args.maps}, {msize} bytes)")
        pos = 0
        while True:
            pos = img.find(b"\xcd\xab", pos)
            if pos < 0:
                break
            offs = struct.unpack_from("<100i", img, pos + 2) \
                if pos + 2 + 400 <= len(img) else ()
            real = [o for o in offs if o > 0]
            if real and max(real) <= msize and real == sorted(real):
                print(f"  HIT at {pos:#x}: {len(real)} level offsets, "
                      f"max {max(real)} (file {msize})")
            pos += 2

    if args.audio:
        asize = os.path.getsize(args.audio)
        print(f"\nAUDIOHHD: looking for int32 offsets ending at {asize} "
              f"({args.audio})")
        for start, count in find_offset_table(img, 4, asize, 50):
            print(f"  HIT at {start:#x}: {count} entries ({count * 4} bytes)")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
