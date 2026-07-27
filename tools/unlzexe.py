"""
Unpack an LZEXE 0.91-packed DOS executable, far enough to read the data
tables id embedded in it.

!! INCOMPLETE -- DO NOT RELY ON THIS FOR THE DECOMPRESSION !!
The header parsing below is verified correct (it computes the same compressed
-data offset as the reference implementation, 0x20 for KEEN6C.EXE), but the
bitstream loop still has a bug: it terminates on a spurious end-marker after
~286 bytes where the reference produces 266,032.  The tables were extracted
using the canonical unlzexe.c (github.com/mywave82/unlzexe) compiled with
MSVC instead.  Fix this or delete it; don't let it silently mislead.

Why this exists: the user's Keen 6 is v1.0, and Omnispeak ships graphics /
map / audio tables only for v1.4 and v1.5.  The tables for v1.0 are inside
KEEN6C.EXE, which is LZEXE-packed, so they have to be decompressed out.

We deliberately do NOT rebuild a runnable .EXE (no header or relocation
reconstruction) -- we only need the load-module image so we can locate the
tables inside it.  That removes most of the fiddly parts of unlzexe.

Format notes (LZEXE 0.91):
  * "LZ91" sits at 0x1C, where the relocation table would normally be.
  * The decompressor stub lives at (hdr_paras + cs) << 4.  The first eight
    words there are the original ip, cs, sp, ss, the compressed size in
    paragraphs, and the size increase -- so the compressed image ends where
    the stub begins and starts comp_size paragraphs earlier.
  * The stream is bit-driven, 16-bit little-endian words consumed LSB first:
      1              -> literal byte follows
      0 0 b b        -> match, len = bb + 2, 8-bit negative offset follows
      0 1            -> match, two bytes follow: offset low, then flags,
                        len = (flags & 7) + 2; if that is 2 a further byte
                        gives len + 1, or ends the stream (0) or marks a
                        segment change (1)

Usage:  python unlzexe.py <packed.exe> [-o out.img]
"""

import struct
import sys


class NotLZEXE(Exception):
    pass


def read_header(data):
    """Return (hdr_size, cs, ip, tag) from the MZ header."""
    if data[:2] not in (b"MZ", b"ZM"):
        raise NotLZEXE("not an MZ executable")
    hdr_paras = struct.unpack_from("<H", data, 8)[0]
    ip, cs = struct.unpack_from("<HH", data, 20)
    tag = bytes(data[0x1C:0x20])
    if tag not in (b"LZ90", b"LZ91"):
        raise NotLZEXE(f"no LZEXE signature (found {tag!r})")
    return hdr_paras * 16, cs, ip, tag


def unpack(data, verbose=False):
    """Decompress the load module of an LZEXE-packed exe; returns bytes."""
    hdr_size, cs, ip, tag = read_header(data)
    stub = hdr_size + (cs << 4)
    info = struct.unpack_from("<8H", data, stub)
    orig_ip, orig_cs, orig_sp, orig_ss, comp_paras = info[:5]
    comp_start = stub - (comp_paras << 4)

    if verbose:
        print(f"  {tag.decode()}  header {hdr_size}B  stub {stub:#x}")
        print(f"  original entry {orig_cs:#06x}:{orig_ip:#06x}  "
              f"stack {orig_ss:#06x}:{orig_sp:#06x}")
        print(f"  compressed image {comp_start:#x}..{stub:#x} "
              f"({comp_paras} paragraphs = {comp_paras * 16} bytes)")
    if comp_start < hdr_size:
        raise NotLZEXE("compressed image would start before the header")

    out = bytearray()
    pos = comp_start
    bitbuf = 0
    bitcnt = 0

    def getbit():
        nonlocal bitbuf, bitcnt, pos
        if bitcnt == 0:
            bitbuf = data[pos] | (data[pos + 1] << 8)
            pos += 2
            bitcnt = 16
        bit = bitbuf & 1
        bitbuf >>= 1
        bitcnt -= 1
        return bit

    def getbyte():
        nonlocal pos
        b = data[pos]
        pos += 1
        return b

    while True:
        if getbit():
            out.append(getbyte())
            continue
        if not getbit():
            length = ((getbit() << 1) | getbit()) + 2
            span = getbyte() | 0xFF00
        else:
            lo = getbyte()
            flags = getbyte()
            span = lo | ((flags & 0xF8) << 5) | 0xE000
            length = flags & 0x07
            if length == 0:
                nxt = getbyte()
                if nxt == 0:
                    break            # end of compressed load module
                if nxt == 1:
                    continue         # segment change, no output
                length = nxt + 1
            else:
                length += 2
        offset = span - 0x10000      # the span is a negative displacement
        # The reference C implementation copies out of a static (so
        # zero-filled) sliding window, which means a reference reaching
        # back past the start of the output legitimately yields zeros --
        # LZEXE encodes leading zeros that way.  Match that instead of
        # treating it as an error, or the very first match aborts us.
        start = len(out) + offset
        for i in range(length):
            src = start + i
            out.append(out[src] if src >= 0 else 0)

    if verbose:
        print(f"  consumed {pos - comp_start} bytes -> {len(out)} bytes out")
    return bytes(out)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    path = argv[1]
    data = open(path, "rb").read()
    print(f"{path}: {len(data)} bytes")
    img = unpack(data, verbose=True)
    if "-o" in argv:
        out = argv[argv.index("-o") + 1]
        open(out, "wb").write(img)
        print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
