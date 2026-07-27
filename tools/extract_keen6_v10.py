"""
Pull the version-specific tables for Keen 6 v1.0 out of an unpacked
KEEN6C.EXE image, so Omnispeak (which ships tables only for v1.4/v1.5) can
read a v1.0 copy of the game.

Everything here is validated against the game's own data files rather than
trusted: the graphics dictionary is only accepted if it actually decompresses
chunk 0 to the exact length that chunk claims in its own header.  That makes
a wrong guess (or a bad unpack upstream) fail loudly instead of producing
plausible garbage.

  EGAHEAD  3-byte offsets into EGAGRAPH, last == EGAGRAPH size
  EGADICT  Huffman tree, 255 nodes x 2 words; head node is the last one
  MAPHEAD  0xABCD tag + int32 offsets into GAMEMAPS

Usage:
  python extract_keen6_v10.py <unpacked.exe> --game <dir with *.CK6> [--out <dir>]
"""

import argparse
import os
import struct
import sys


# The expander and the dictionary test live in find_egadict.py.  Do not
# re-implement a "decompressed to the right length" check here: the expander
# stops as soon as it has produced that many bytes, so a wrong tree passes
# trivially.  A dictionary is only accepted if it ALSO consumes the
# compressed input exactly, and yields a structurally valid font.
from find_egadict import expand, load_nodes, looks_like_font


def validate_dict(img, off, src, want):
    """True if the table at off decodes src exactly and produces a font."""
    nodes = load_nodes(img, off)
    if nodes is None:
        return None, None
    out, used = expand(src, nodes, want, lsb_first=True)
    if out is None or len(out) != want:
        return None, None
    if used < len(src) - 1 or used > len(src):
        return None, None            # input not consumed -> wrong tree
    return nodes, out


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("image", help="unpacked KEEN6C.EXE")
    ap.add_argument("--game", required=True, help="folder holding the .CK6 data")
    ap.add_argument("--egahead", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--egadict", type=lambda s: int(s, 0), required=True,
                    help="offset of the Huffman table (see find_egadict.py)")
    ap.add_argument("--maphead", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--fontchunk", type=int, default=4,
                    help="chunk to validate against; 4 is the menu font "
                         "(VH_GetFontCharInfo asks for base 1 + index 3)")
    ap.add_argument("--out")
    args = ap.parse_args(argv[1:])

    img = open(args.image, "rb").read()
    graph = open(os.path.join(args.game, "EGAGRAPH.CK6"), "rb").read()
    maps_size = os.path.getsize(os.path.join(args.game, "GAMEMAPS.CK6"))

    # --- EGAHEAD: walk until the offset that equals the graphics file size
    offs = []
    p = args.egahead
    while True:
        v = int.from_bytes(img[p:p + 3], "little")
        offs.append(v)
        p += 3
        if v == len(graph):
            break
        if len(offs) > 8000:
            print("EGAHEAD: never reached the end of EGAGRAPH", file=sys.stderr)
            return 1
    print(f"EGAHEAD at {args.egahead:#x}: {len(offs)} offsets "
          f"({len(offs) * 3} bytes), last = {offs[-1]} == EGAGRAPH size")

    # --- validate the dictionary against a chunk we can recognise
    fc = args.fontchunk
    c_start, c_end = offs[fc], offs[fc + 1]
    expanded = struct.unpack_from("<I", graph, c_start)[0]
    src = graph[c_start + 4:c_end]
    print(f"chunk {fc}: {c_start}..{c_end} ({len(src)} bytes compressed), "
          f"claims {expanded} bytes expanded")

    dict_off = args.egadict
    nodes, out = validate_dict(img, dict_off, src, expanded)
    if nodes is None:
        print(f"EGADICT at {dict_off:#x}: did NOT decode chunk {fc} cleanly",
              file=sys.stderr)
        return 1
    if not looks_like_font(out):
        print(f"EGADICT at {dict_off:#x}: decoded, but chunk {fc} is not a "
              f"valid font -- wrong table or wrong chunk", file=sys.stderr)
        return 1
    height = struct.unpack_from("<H", out, 0)[0]
    print(f"EGADICT at {dict_off:#x}: chunk {fc} decoded to {len(out)} bytes, "
          f"input fully consumed, valid font (height {height})  <-- validated")

    # --- MAPHEAD
    tag = struct.unpack_from("<H", img, args.maphead)[0]
    lvl = struct.unpack_from("<100i", img, args.maphead + 2)
    real = [o for o in lvl if o > 0]
    print(f"MAPHEAD at {args.maphead:#x}: tag {tag:#06x}, {len(real)} levels, "
          f"max {max(real)} (GAMEMAPS is {maps_size})")

    if args.out:
        os.makedirs(args.out, exist_ok=True)
        with open(os.path.join(args.out, "EGAHEAD.CK6"), "wb") as f:
            f.write(img[args.egahead:args.egahead + len(offs) * 3])
        with open(os.path.join(args.out, "EGADICT.CK6"), "wb") as f:
            # 256 nodes on disk (1024 bytes) to match what Omnispeak reads,
            # even though only 255 are used and the head is node 254
            f.write(img[dict_off:dict_off + 256 * 4])
        with open(os.path.join(args.out, "MAPHEAD.CK6"), "wb") as f:
            f.write(img[args.maphead:args.maphead + 2 + 400])
        print(f"\nwrote EGAHEAD.CK6, EGADICT.CK6, MAPHEAD.CK6 to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
