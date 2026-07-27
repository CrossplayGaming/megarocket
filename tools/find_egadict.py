"""
Find the Keen Huffman dictionary (EGADICT) inside an unpacked executable,
using a test that a wrong tree cannot fake.

An earlier version of this check only compared the decompressed SIZE against
the length each chunk declares -- which is nearly worthless, because the
expander stops the moment it has produced that many bytes, so any tree that
doesn't hit an invalid node "passes".  The real signal is that a correct tree
consumes the compressed bytes and finishes the output at the same moment: the
input must be exhausted (bar the final partial bit-byte) exactly when the
output is complete.  On top of that we ask the result to be structurally
sound -- for a font chunk, a sane pixel height and an ascending glyph table.

Usage:
  python find_egadict.py <unpacked.exe> <EGAGRAPH> --egahead 0x22720
                         [--chunk 4] [--near 0x22720]
"""

import argparse
import struct
import sys


def expand(src, nodes, want, lsb_first=True):
    """Huffman-expand, returning (output, bytes_of_input_consumed)."""
    out = bytearray()
    head = 254
    node = head
    for i, byte in enumerate(src):
        bits = range(8) if lsb_first else range(7, -1, -1)
        for bit in bits:
            way = (byte >> bit) & 1
            value = nodes[node][way]
            if value < 256:
                out.append(value)
                node = head
                if len(out) == want:
                    return bytes(out), i + 1
            else:
                node = value - 256
                if node > 254:
                    return None, i + 1
    return bytes(out), len(src)


def load_nodes(img, off):
    nodes = []
    for i in range(255):
        base = off + i * 4
        left, right = struct.unpack_from("<HH", img, base)
        if left > 511 or right > 511:
            return None
        nodes.append((left, right))
    return nodes


def looks_like_font(data):
    if len(data) < 770:
        return False
    height = struct.unpack_from("<H", data, 0)[0]
    locs = struct.unpack_from("<256H", data, 2)
    widths = data[514:770]
    printable = locs[32:127]
    return (6 <= height <= 20
            and list(printable) == sorted(printable)
            and all(0 < widths[c] <= 16 for c in (65, 66, 97, 98)))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("graph")
    ap.add_argument("--egahead", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--chunk", type=int, default=4)
    ap.add_argument("--near", type=lambda s: int(s, 0))
    args = ap.parse_args(argv[1:])

    img = open(args.image, "rb").read()
    graph = open(args.graph, "rb").read()

    def chunk_at(i):
        p = args.egahead + i * 3
        s = int.from_bytes(img[p:p + 3], "little")
        e = int.from_bytes(img[p + 3:p + 6], "little")
        return s, e

    s, e = chunk_at(args.chunk)
    want = struct.unpack_from("<I", graph, s)[0]
    src = graph[s + 4:e]
    print(f"chunk {args.chunk}: {s}..{e}, {len(src)} compressed bytes, "
          f"declares {want} expanded")

    order = range(0, len(img) - 255 * 4)
    if args.near:
        lo, hi = max(0, args.near - 0x8000), min(len(img) - 1020, args.near + 0x8000)
        order = list(range(lo, hi)) + [i for i in range(0, len(img) - 1020)
                                       if not lo <= i < hi]

    best = []
    for off in order:
        nodes = load_nodes(img, off)
        if nodes is None:
            continue
        for lsb in (True, False):
            out, used = expand(src, nodes, want, lsb)
            if out is None or len(out) != want:
                continue
            # a correct tree finishes the output as the input runs out
            if used < len(src) - 1 or used > len(src):
                continue
            font = looks_like_font(out)
            print(f"  CANDIDATE {off:#x} lsb_first={lsb} consumed {used}/{len(src)}"
                  f"  font={font}")
            best.append((off, lsb, font))
    if not best:
        print("  no dictionary both completed the output and consumed the input")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
