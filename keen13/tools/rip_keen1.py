#!/usr/bin/env python3
"""Rip build-time data out of the user's KEEN1/2/3.EXE (v1.31).

The GPL reconstruction links pieces of *game data* into the EXE that are
not shipped with the source (they are id Software's data, ripped from the
original executables by the STATIC/rip.bat + ckpatch flow on DOS):

  TILEINFO -> TINFCK{n}.C  (6 x int16[numtiles] tile attribute arrays)
  ENDSCRN  -> ENDSCRN{n}.C (80x25 text-mode exit screen, char+attr)
  ep 2/3   -> LINKED{n}.C  (sounds + help/story/end/preview texts, which
                            those EXEs carry linked-in: TEXTSLINKED /
                            SOUNDSLINKED)

This tool replicates that flow on the modern host:
  1. UNLZEXE the packed EXE (LZEXE 0.91) in memory
  2. dump the regions at the offsets from STATIC/ripck?.pat
  3. generate C files (TILINF2C.C logic ported exactly)

Usage: rip_keen1.py [episode...]   (default: 1)

Output goes to keen13/port/generated/ and is NOT committed - it derives
from copyrighted game data the user supplies.
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "..", "port", "generated")

# STATIC/ripck?.pat (v1.31 blocks): file offsets into the UNLZEXE'd exe
EPISODES = {
    1: {
        "exe": "KEEN1.EXE",
        "gamedata": "gamedata",
        "ENDSCRN": (0x12080, 0xFA8),
        "TILEINFO": (0x130F8, 0x1CA4),
        "fallback": {  # v1.1 offsets
            "ENDSCRN": (0x12180, 0xFA8),
            "TILEINFO": (0x131F8, 0x1CA4),
        },
    },
    2: {
        "exe": "KEEN2.EXE",
        "gamedata": "gamedata2",
        "ENDSCRN": (0x11780, 0xFA8),
        "TILEINFO": (0x17828, 0x204C),
        "linked": {
            "_sounds": (0x12730, 0x310A),
            "endtext": (0x15840, 0x37C),
            "helptext": (0x15BC0, 0x7DE),
            "previews": (0x163A0, 0x715),
            "storytxt": (0x16AC0, 0xC98),
        },
    },
    3: {
        "exe": "KEEN3.EXE",
        "gamedata": "gamedata3",
        "ENDSCRN": (0x12AC0, 0xFA8),
        "TILEINFO": (0x198C8, 0x2184),
        "linked": {
            "_sounds": (0x13A70, 0x3F60),
            "helptext": (0x179D0, 0x7CC),
            "endtext": (0x181A0, 0x33C),
            "previews": (0x184E0, 0x6E4),
            "storytxt": (0x18BD0, 0xC23),
        },
    },
}


def unlzexe(data):
    """Unpack an LZEXE 0.91 executable; returns the unpacked EXE file image
    (0x200-byte MZ header + load module), matching UNLZEXE.EXE output."""
    ihead = struct.unpack_from("<14H", data, 0)
    (sig, partpage, pagecnt, relocnt, hdrsize, minmem, maxmem,
     ss, sp, chksum, ip, cs, relocpos, noverlay) = ihead
    assert data[:2] == b"MZ"
    assert data[0x1C:0x20] == b"LZ91", "not LZEXE 0.91"

    # info table at the start of the packed exe's CS segment
    stub = (cs + hdrsize) << 4
    inf = struct.unpack_from("<8H", data, stub)
    real_ip, real_cs, real_sp, real_ss, compsize, incsize = inf[:6]

    # compressed data sits compsize paragraphs below the stub segment
    src = (cs - compsize + hdrsize) << 4
    out = bytearray()

    # bit reader: 16-bit little-endian words, LSB first
    pos = [src]
    bitbuf = [0]
    bitcnt = [0]

    def getw():
        v = data[pos[0]] | (data[pos[0] + 1] << 8)
        pos[0] += 2
        return v

    def getbyte():
        v = data[pos[0]]
        pos[0] += 1
        return v

    def initbits():
        bitbuf[0] = getw()
        bitcnt[0] = 16

    def getbit():
        b = bitbuf[0] & 1
        bitbuf[0] >>= 1
        bitcnt[0] -= 1
        if bitcnt[0] == 0:
            initbits()
        return b

    initbits()
    while True:
        if getbit():
            out.append(getbyte())
            continue
        if not getbit():
            length = (getbit() << 1) | getbit()
            length += 2
            span = getbyte() | 0xFF00
        else:
            span = getbyte()
            b = getbyte()
            span |= ((b & ~0x07) << 5) | 0xE000
            length = (b & 0x07) + 2
            if length == 2:
                length = getbyte()
                if length == 0:
                    break  # end of compressed data
                if length == 1:
                    continue  # segment change marker
                length += 1
        disp = span - 0x10000  # negative 16-bit displacement
        for _ in range(length):
            out.append(out[disp])

    # rebuild relocation table (LZEXE 0.91 packs it as bit-coded spans)
    relocs = []
    rp = stub + 0x158  # reloc data follows the 0.91 stub code
    rpos = [rp]

    def rgetb():
        v = data[rpos[0]]
        rpos[0] += 1
        return v

    def rgetw():
        v = data[rpos[0]] | (data[rpos[0] + 1] << 8)
        rpos[0] += 2
        return v

    seg = 0
    off = 0
    while True:
        span = rgetb()
        if span == 0:
            span = rgetw()
            if span == 0:
                seg = (seg + 0x0FFF) & 0xFFFF
                continue
            elif span == 1:
                break
        off = (off + span) & 0xFFFF
        seg = (seg + ((off & ~0x0F) >> 4)) & 0xFFFF
        off &= 0x0F
        relocs.append((off, seg))

    # emit UNLZEXE-style file: 0x200-byte header + load module
    newhdr = 0x20  # paragraphs
    imgsize = len(out)
    total = (newhdr << 4) + imgsize
    pages = (total + 511) // 512
    part = total % 512
    hdr = bytearray(0x200)
    struct.pack_into(
        "<14H", hdr, 0,
        0x5A4D, part, pages, len(relocs), newhdr, minmem, maxmem,
        real_ss, real_sp, 0, real_ip, real_cs, 0x1C, 0)
    ro = 0x1C
    for off, seg in relocs:
        struct.pack_into("<HH", hdr, ro, off, seg)
        ro += 4
        if ro > 0x200 - 4:
            # keen's tables fit in the standard header; bail loudly if not
            raise AssertionError("relocation table overflows 0x200 header")
    return bytes(hdr) + bytes(out)


def gen_tinf(tileinfo, outpath):
    """Port of TILINF2C.C: emit int arrays nexttile/intile/N/E/S/W walls."""
    assert len(tileinfo) % 12 == 0, "TILEINFO size must be multiple of 12"
    numtiles = len(tileinfo) // 12
    names = ["nexttile", "intile", "northwall",
             "eastwall", "southwall", "westwall"]
    vals = struct.unpack("<%dh" % (numtiles * 6), tileinfo)
    with open(outpath, "w", newline="\n") as f:
        f.write("//\n// TILE ATTRIBUTE DATA FOR KEEN 1-3 -- created by "
                "rip_keen1.py (TILINF2C port)\n//\n\n")
        for b, name in enumerate(names):
            block = vals[b * numtiles:(b + 1) * numtiles]
            f.write("int %s[%d] =\n{\n" % (name, numtiles))
            for i in range(0, numtiles, 13):
                row = block[i:i + 13]
                f.write("\t" + ",".join("%2d" % v for v in row))
                f.write(",\n" if i + 13 < numtiles else "\n")
            f.write("};\n\n")
    return numtiles


def gen_blob(name, blob, f):
    f.write("char %s[%d] =\n{\n" % (name, len(blob)))
    for i in range(0, len(blob), 16):
        f.write("\t" + ",".join(str(b if b < 128 else b - 256)
                                for b in blob[i:i + 16]) + ",\n")
    f.write("};\n\n")


def gen_endscrn(endscrn, outpath):
    with open(outpath, "w", newline="\n") as f:
        f.write("//\n// DOS exit screen (text mode B800 dump) -- created by "
                "rip_keen1.py\n//\n\n")
        f.write("char endscreen[%d] =\n{\n" % len(endscrn))
        for i in range(0, len(endscrn), 16):
            f.write("\t" + ",".join(str(b if b < 128 else b - 256)
                                    for b in endscrn[i:i + 16]) + ",\n")
        f.write("};\n")


def looks_like_tileinfo(blob):
    """Sanity check: wall blocks should be almost entirely 0/1-ish small
    values and intile classes small non-negative."""
    n = len(blob) // 12
    vals = struct.unpack("<%dh" % (n * 6), blob)
    walls = vals[2 * n:6 * n]
    small = sum(1 for v in walls if 0 <= v <= 8)
    return small / len(walls) > 0.95


def looks_like_endscrn(blob):
    """Text-mode dump: the game blits from byte 7 (movedata ... +7, 4000),
    so chars sit at blob[7::2] with attrs interleaved."""
    chars = blob[7:7 + 4000:2]
    printable = sum(1 for c in chars if c == 0 or 0x20 <= c < 0x7F or c >= 0xB0)
    return printable / len(chars) > 0.9


def rip_episode(ep):
    info = EPISODES[ep]
    gamedata = os.path.join(HERE, "..", info["gamedata"])
    exe = open(os.path.join(gamedata, info["exe"]), "rb").read()
    unpacked = unlzexe(exe)
    print("unpacked %s: %d -> %d bytes" % (info["exe"], len(exe),
                                           len(unpacked)))

    os.makedirs(OUTDIR, exist_ok=True)
    # ckpatch offsets are into the unpacked load module; our file image
    # prepends a 0x200-byte MZ header (verified against the v1.31 data)
    hdr = 0x200

    ripsets = [(info, "v1.31")]
    if "fallback" in info:
        ripsets.append((info["fallback"], "fallback"))
    ok = False
    for ripset, label in ripsets:
        off, size = ripset["TILEINFO"]
        tinf = unpacked[hdr + off:hdr + off + size]
        off2, size2 = ripset["ENDSCRN"]
        escr = unpacked[hdr + off2:hdr + off2 + size2]
        if (len(tinf) == size and looks_like_tileinfo(tinf)
                and looks_like_endscrn(escr)):
            print("rip offsets match %s layout" % label)
            ok = True
            break
    if not ok:
        sys.exit("ERROR: no offset set produced sane data for ep %d" % ep)

    n = gen_tinf(tinf, os.path.join(OUTDIR, "TINFCK%d.C" % ep))
    print("TINFCK%d.C: %d tiles" % (ep, n))
    gen_endscrn(escr, os.path.join(OUTDIR, "ENDSCRN%d.C" % ep))
    print("ENDSCRN%d.C: %d bytes" % (ep, len(escr)))

    if "linked" in info:
        path = os.path.join(OUTDIR, "LINKED%d.C" % ep)
        with open(path, "w", newline="\n") as f:
            f.write("//\n// TEXT + SOUND DATA LINKED INTO KEEN%d.EXE -- "
                    "created by rip_keen1.py\n//\n\n" % ep)
            for sym, (off, size) in info["linked"].items():
                blob = unpacked[hdr + off:hdr + off + size]
                if len(blob) != size:
                    sys.exit("ERROR: short read for %s" % sym)
                gen_blob(sym, blob, f)
                print("LINKED%d.C: %s (%d bytes)" % (ep, sym, size))

    # show the exit screen text as a human check
    text = "".join(chr(c) if 0x20 <= c < 0x7F else " "
                   for c in escr[7:7 + 4000:2])
    for r in range(6):
        print("  |" + text[r * 80:(r + 1) * 80].rstrip())


def main():
    eps = [int(a) for a in sys.argv[1:]] or [1]
    for ep in eps:
        rip_episode(ep)


if __name__ == "__main__":
    main()
