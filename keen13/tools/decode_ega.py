#!/usr/bin/env python3
"""Keen 1-3 EGA graphics decoder (Keen Launcher, Phase 4 groundwork).

Parses EGAHEAD/EGALATCH from Keen 1 v1.31 data and renders pics to BMP.
Format knowledge comes from the GPL reconstruction's IDLIBC.C/IDLIB.H
(grheadtype, pictype, bloadinLZW/LZW_Decompress) - this is a faithful
Python port of that loading path, used as a data-format testbed before
the C port lands.
"""
import struct
import sys
import os

EGA_PALETTE = [
    (0x00, 0x00, 0x00), (0x00, 0x00, 0xAA), (0x00, 0xAA, 0x00), (0x00, 0xAA, 0xAA),
    (0xAA, 0x00, 0x00), (0xAA, 0x00, 0xAA), (0xAA, 0x55, 0x00), (0xAA, 0xAA, 0xAA),
    (0x55, 0x55, 0x55), (0x55, 0x55, 0xFF), (0x55, 0xFF, 0x55), (0x55, 0xFF, 0xFF),
    (0xFF, 0x55, 0x55), (0xFF, 0x55, 0xFF), (0xFF, 0xFF, 0x55), (0xFF, 0xFF, 0xFF),
]

RESETCODE, STOPCODE, STARTCODE = 0x100, 0x101, 0x102


def lzw_decompress(data):
    """Port of IDLIBC.C LZW_Decompress/LZW_ReadCode (MSB-first bit packing)."""
    (length,) = struct.unpack_from('<i', data, 0)
    (maxcodelen,) = struct.unpack_from('<H', data, 4)
    pos = 6
    bitbuffer = 0
    bitsavail = 0
    codelen = 9
    maxcode = (1 << codelen) - 1

    codes = {}
    values = {}
    out = bytearray()
    nextcode = STARTCODE
    fresh = True
    prevcode = prevval = 0

    def readcode():
        nonlocal bitbuffer, bitsavail, pos
        while bitsavail <= 24:
            val = data[pos] if pos < len(data) else 0
            pos += 1
            bitbuffer |= val << (24 - bitsavail)
            bitbuffer &= 0xFFFFFFFF
            bitsavail += 8
        code = (bitbuffer >> (32 - codelen)) & ((1 << codelen) - 1)
        bitbuffer = (bitbuffer << codelen) & 0xFFFFFFFF
        bitsavail -= codelen
        return code

    def expand(code, stack):
        while code >= 0x100:
            stack.append(values[code])
            code = codes[code]
        stack.append(code)
        return stack

    while True:
        code = readcode()
        if code == STOPCODE:
            break
        if fresh:
            fresh = False
            prevval = prevcode = code
            out.append(prevcode)
        elif code == RESETCODE:
            fresh = True
            codelen = 9
            nextcode = STARTCODE
            maxcode = (1 << codelen) - 1
            codes.clear()
            values.clear()
        else:
            stack = []
            if code >= nextcode:
                stack.append(prevval)
                expand(prevcode, stack)
            else:
                expand(code, stack)
            prevval = stack[-1]
            out.extend(reversed(stack))
            if nextcode <= maxcode:
                codes[nextcode] = prevcode
                values[nextcode] = prevval
                nextcode += 1
                if nextcode == maxcode and codelen < maxcodelen:
                    codelen += 1
                    maxcode = (1 << codelen) - 1
            prevcode = code
    assert len(out) == length, f"LZW length mismatch: {len(out)} vs {length}"
    return bytes(out)


def parse_head(data):
    """grheadtype for VERSION < VER_132 (v1.31): no field_1C/field_1E."""
    f = {}
    (f['latchsize'], f['spritesize'], f['picinfoStart'], f['sprinfoStart'],
     f['numTile8s'], f['offTile8s'], f['field_16'], f['field_18'],
     f['numTile16s'], f['offTile16s'], f['numPics'], f['offPics'],
     f['numSprites'], f['offSprites'], f['compression']) = struct.unpack_from(
        '<iiiiHiHiHiHihiH', data, 0)
    return f


def parse_pics(data, head):
    pics = []
    off = head['picinfoStart']
    for i in range(head['numPics']):
        w, h, shape, name = struct.unpack_from('<hhI8s', data, off + i * 16)
        pics.append({'w': w, 'h': h, 'shape': shape,
                     'name': name.split(b'\0')[0].decode('ascii', 'replace')})
    return pics


def write_bmp(path, w, h, pixels):
    """pixels: list of palette indices, row-major top-down."""
    rowbytes = (w * 3 + 3) & ~3
    filesize = 54 + rowbytes * h
    with open(path, 'wb') as fp:
        fp.write(b'BM' + struct.pack('<IHHI', filesize, 0, 0, 54))
        fp.write(struct.pack('<IiiHHIIiiII', 40, w, h, 1, 24, 0,
                             rowbytes * h, 2835, 2835, 0, 0))
        for y in range(h - 1, -1, -1):
            row = bytearray()
            for x in range(w):
                r, g, b = EGA_PALETTE[pixels[y * w + x]]
                row += bytes((b, g, r))
            row += b'\0' * (rowbytes - len(row))
            fp.write(row)


def decode_pic(latch, latchsize, head, pic, shape_mode='off16'):
    wbytes, h = pic['w'], pic['h']
    wpx = wbytes * 8
    if shape_mode == 'off16':
        shape = pic['shape'] & 0xFFFF
    else:
        shape = pic['shape']
    base = head['offPics'] + shape
    pixels = [0] * (wpx * h)
    for plane in range(4):
        pdata = latch[plane * latchsize:(plane + 1) * latchsize]
        for y in range(h):
            for xb in range(wbytes):
                byte = pdata[base + y * wbytes + xb]
                for bit in range(8):
                    if byte & (0x80 >> bit):
                        pixels[y * wpx + xb * 8 + bit] |= (1 << plane)
    return wpx, h, pixels


def main():
    gamedir = sys.argv[1] if len(sys.argv) > 1 else '../gamedata'
    outdir = sys.argv[2] if len(sys.argv) > 2 else '.'
    picname = sys.argv[3] if len(sys.argv) > 3 else 'TITLEPIC'

    head_raw = open(os.path.join(gamedir, 'EGAHEAD.CK1'), 'rb').read()
    head = parse_head(head_raw)
    print("EGAHEAD:", {k: v for k, v in head.items() if not k.startswith('field')})

    latch_raw = open(os.path.join(gamedir, 'EGALATCH.CK1'), 'rb').read()
    if head['compression']:
        latch = lzw_decompress(latch_raw)
        print(f"EGALATCH: LZW {len(latch_raw)} -> {len(latch)} bytes")
    else:
        latch = latch_raw
    assert len(latch) >= head['latchsize'] * 4, \
        f"latch too small: {len(latch)} < {head['latchsize'] * 4}"

    pics = parse_pics(head_raw, head)
    for i, p in enumerate(pics[:12]):
        print(f"pic {i:2d}: {p['name']:10s} {p['w']*8:3d}x{p['h']:3d} shape={p['shape']:#010x}")

    # Pic 0 is TITLEPIC per GRAPHCK1.H.
    idx = 0 if picname == 'TITLEPIC' else int(picname)
    wpx, h, pixels = decode_pic(latch, head['latchsize'], head, pics[idx])
    out = os.path.join(outdir, f'pic{idx}_{pics[idx]["name"] or "unnamed"}.bmp')
    write_bmp(out, wpx, h, pixels)
    print("wrote", out, f"{wpx}x{h}")


if __name__ == '__main__':
    main()
